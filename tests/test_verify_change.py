"""Behavioral checks for the offline verification workflow."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


verify = load_module("verify_change", "scripts/ai/verify_change.py")
hooks = load_module("install_hooks", "scripts/ai/install_hooks.py")


class VerificationTests(unittest.TestCase):
    def test_backend_tests_are_explicit_and_offline(self):
        plan = verify.build_plan(["backend/tests/test_new_database_test.py"])
        command = next(check.command for check in plan if check.kind == "backend-tests")
        self.assertIn("tests/test_sql_guard.py", command)
        self.assertIn("tests/test_sql_filters.py", command)
        self.assertNotIn("test_new_database_test.py", command)

    def test_mixed_change_selects_frontend_and_backend_once(self):
        plan = verify.build_plan(["backend/services/sql_guard.py", "frontend/src/A.tsx", "frontend/src/B.tsx"])
        kinds = [check.kind for check in plan]
        self.assertEqual(kinds.count("frontend-build"), 1)
        self.assertEqual(kinds.count("backend-tests"), 1)

    def test_frontend_change_runs_lint_tests_and_build_in_order(self):
        plan = verify.build_plan(["frontend/src/Page.tsx", "frontend/tests/Page.test.tsx"])
        frontend = [check for check in plan if check.kind.startswith("frontend-")]
        self.assertEqual([check.command for check in frontend], [
            ("npm", "run", "lint"), ("npm", "test"), ("npm", "run", "build")
        ])
        self.assertTrue(all(check.cwd == "frontend" for check in frontend))

    def test_sql_is_reported_for_review_and_never_executed(self):
        plan = verify.build_plan(["migrations/129_new.sql"])
        self.assertEqual([check.kind for check in plan], ["sql-review"])
        self.assertTrue(all(not check.command for check in plan))

    def test_command_failure_is_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            run = lambda *args, **kwargs: subprocess.CompletedProcess(args[0], 7)
            self.assertEqual(verify.run_checks(Path(directory), verify.build_plan(["frontend/src/Removed.tsx"]), runner=run), 7)

    def test_git_hook_environment_is_not_passed_to_checks(self):
        seen = {}

        def run(command, cwd, env):
            seen.update(env)
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as directory, patch.dict(verify.os.environ, {"GIT_INDEX_FILE": "next-index", "GIT_DIR": ".git"}):
            verify.run_checks(Path(directory), verify.build_plan(["frontend/src/Removed.tsx"]), runner=run)
        self.assertTrue(seen)
        self.assertFalse([key for key in seen if key.startswith("GIT_")])

    def test_deleted_python_file_is_not_parsed(self):
        with tempfile.TemporaryDirectory() as directory:
            plan = verify.build_plan(["scripts/deleted.py"])
            self.assertEqual(verify.run_checks(Path(directory), plan), 0)

    def test_invalid_python_fails_without_importing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bad.py").write_text("raise RuntimeError('never import')\ndef broken(:\n", encoding="utf-8")
            self.assertEqual(verify.run_checks(root, verify.build_plan(["bad.py"])), 1)
            self.assertFalse((root / "__pycache__").exists())

    def test_valid_python_is_parsed_without_executing_module_body(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "safe.py").write_text("raise RuntimeError('must never run')\n", encoding="utf-8")
            self.assertEqual(verify.run_checks(root, verify.build_plan(["safe.py"])), 0)
            self.assertFalse((root / "__pycache__").exists())

    def test_outside_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                verify.run_checks(Path(directory), verify.build_plan(["../outside.py"]))


class GitWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="verify project ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "-q")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True)

    def test_staged_added_file_and_untracked_are_distinguished(self):
        (self.root / "added.py").write_text("x = 1\n")
        (self.root / "untracked.py").write_text("x = 2\n")
        self.git("add", "added.py")
        self.assertEqual(verify.collect_files(self.root, staged=True), ["added.py"])
        self.assertEqual(verify.collect_files(self.root, all_files=True), ["added.py", "untracked.py"])

    def test_partially_staged_file_is_rejected(self):
        file = self.root / "changed.py"
        file.write_text("x = 1\n")
        self.git("add", "changed.py")
        file.write_text("x = 2\n")
        with self.assertRaisesRegex(ValueError, "partiellement"):
            verify.collect_files(self.root, staged=True)

    def test_hook_installation_is_idempotent(self):
        target = hooks.install(self.root)
        self.assertTrue(target.is_file())
        first = target.read_bytes()
        self.assertEqual(hooks.install(self.root).read_bytes(), first)

    def test_existing_custom_hook_is_preserved(self):
        target = self.root / ".git/hooks/pre-commit"
        target.write_text("#!/bin/sh\necho custom\n")
        with self.assertRaisesRegex(ValueError, "existant"):
            hooks.install(self.root)
        self.assertIn("echo custom", target.read_text())

    def test_custom_hooks_path_is_not_reconfigured(self):
        self.git("config", "core.hooksPath", "custom-hooks")
        with self.assertRaisesRegex(ValueError, "core.hooksPath"):
            hooks.install(self.root)
        self.assertEqual(self.git("config", "--get", "core.hooksPath").stdout.strip(), "custom-hooks")


if __name__ == "__main__":
    unittest.main()
