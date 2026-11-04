"""Exercise the installers with fake CLIs; never download or change user config."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = (
    "C:/Program Files/Git/bin/bash.exe"
    if os.name == "nt" and Path("C:/Program Files/Git/bin/bash.exe").exists()
    else shutil.which("bash")
)


@unittest.skipUnless(BASH, "Bash is required for installer tests")
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ai setup ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project = self.base / "project with spaces"
        self.bin = self.base / "fake bin"
        self.home = self.base / "user home"
        for path in (self.project / "scripts/ai", self.bin, self.home):
            path.mkdir(parents=True)
        for name in ("install_claude.sh", "install_codex.sh"):
            source = ROOT / name
            if source.exists():
                shutil.copyfile(source, self.project / name)
        for name in ("install_common.sh", "configure_context7.py"):
            source = ROOT / "scripts/ai" / name
            if source.exists():
                shutil.copyfile(source, self.project / "scripts/ai" / name)
        (self.project / "scripts/ai/sync_skills.py").write_text("# fixture\n")
        self.log = self.base / "commands.log"
        for command in ("claude", "codex", "python3", "python", "node", "npm", "git", "code", "curl"):
            self.mock(command)
        self.env = dict(os.environ)
        self.env.update(
            HOME=str(self.home),
            USERPROFILE=str(self.home),
            PATH=str(self.bin) + os.pathsep + self.env.get("PATH", ""),
            MOCK_LOG=str(self.log),
            CLAUDE_CONFIG_DIR=str(self.home / ".claude"),
            CODEX_HOME=str(self.home / ".codex"),
        )

    def mock(self, name):
        # Lists return empty JSON and help checks succeed; installs can fail.
        script = self.bin / name
        body = (
            "#!/usr/bin/env bash\n"
            f"printf '%s\\n' '{name}:'\"$*\" >> \"$MOCK_LOG\"\n"
            "if [[ \"$*\" == *--help* ]]; then exit \"${MOCK_HELP_FAIL:-0}\"; fi\n"
            "if [[ \"$*\" == *'plugin install'* || \"$*\" == *'plugin add '* ]]; then\n"
            "  if [[ ${MOCK_PLUGIN_FAIL:-0} == 1 ]]; then exit 23; fi\n"
            "fi\n"
            "if [[ \"$*\" == *'marketplace list'* && ${MOCK_MARKETPLACE_PRESENT:-0} == 1 ]]; then\n"
            "  printf '[{\"name\":\"claude-plugins-official\"}]\\n'; exit 0\n"
            "fi\n"
            "if [[ \"$*\" == *list* ]]; then printf '[]\\n'; fi\n"
            "exit 0\n"
        )
        if name in ("python3", "python"):
            body = (
                "#!/usr/bin/env bash\n"
                f"printf '%s\\n' '{name}:'\"$*\" >> \"$MOCK_LOG\"\n"
                f"exec {shlex.quote(Path(sys.executable).as_posix())} \"$@\"\n"
            )
        script.write_text(
            body,
            encoding="utf-8",
            newline="\n",
        )
        script.chmod(0o755)

    def run_installer(self, name, *args, **extra_env):
        env = dict(self.env, **extra_env)
        return subprocess.run(
            [BASH, (self.project / f"install_{name}.sh").as_posix(), *args],
            cwd=self.base,
            env=env,
            text=True,
            capture_output=True,
            timeout=30,
        )

    def commands(self):
        return self.log.read_text(encoding="utf-8").splitlines() if self.log.exists() else []

    def test_dry_run_has_no_external_commands_or_writes(self):
        for name in ("claude", "codex"):
            with self.subTest(name=name):
                before = sorted(str(p.relative_to(self.base)) for p in self.base.rglob("*"))
                result = self.run_installer(name, "--dry-run", "--vscode", "--design")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.commands(), [])
                after = sorted(str(p.relative_to(self.base)) for p in self.base.rglob("*"))
                self.assertEqual(before, after)

    def test_configure_only_syncs_skills_without_cli_install(self):
        result = self.run_installer("claude", "--configure-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any("sync_skills.py" in line for line in self.commands()))
        self.assertFalse(any(line.startswith(("claude:", "codex:", "npm:", "curl:")) for line in self.commands()))

    def test_reuses_cli_and_supports_repeat_execution_with_spaces(self):
        for name in ("claude", "codex"):
            with self.subTest(name=name):
                for _ in range(2):
                    result = self.run_installer(name, "--skip-cli")
                    self.assertEqual(result.returncode, 0, result.stderr)
                commands = self.commands()
                self.assertFalse(any("install -g" in line or line.startswith("curl:") for line in commands))
                self.assertTrue(any("sync_skills.py" in line for line in commands))

    def test_plugin_failure_is_not_reported_as_success(self):
        for name in ("claude", "codex"):
            with self.subTest(name=name):
                result = self.run_installer(name, "--skip-cli", MOCK_PLUGIN_FAIL="1")
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Installation terminee", result.stdout)

    def test_unknown_flag_fails_before_external_commands(self):
        result = self.run_installer("codex", "--wrong")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_conflicting_cli_options_fail_before_external_commands(self):
        result = self.run_installer("codex", "--skip-cli", "--update-cli")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_vscode_extensions_are_optional_and_official(self):
        result = self.run_installer("codex", "--skip-cli", "--vscode")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        for extension in ("ms-python.python", "ms-python.vscode-pylance", "ms-python.debugpy", "esbenp.prettier-vscode", "openai.chatgpt"):
            self.assertTrue(any(f"code:--install-extension {extension}" in line for line in commands), extension)

    def test_existing_marketplace_is_not_readded(self):
        for name in ("claude", "codex"):
            with self.subTest(name=name):
                if self.log.exists():
                    self.log.unlink()
                result = self.run_installer(name, "--skip-cli", MOCK_MARKETPLACE_PRESENT="1")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any("marketplace add" in line for line in self.commands()))

    def test_preexisting_config_is_preserved_and_backed_up(self):
        config = self.home / ".codex/config.toml"
        config.parent.mkdir()
        original = 'custom = "do-not-print-this-secret"\n'
        config.write_text(original)
        result = self.run_installer("codex", "--skip-cli")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(config.read_text().startswith(original))
        self.assertEqual(
            tomllib.loads(config.read_text())["mcp_servers"]["context7"]["url"],
            "https://mcp.context7.com/mcp",
        )
        copies = list((self.home / ".migration-factory/backups").rglob("config.toml"))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_text(), original)
        self.assertNotIn("do-not-print-this-secret", result.stdout + result.stderr)

    def test_incompatible_cli_stops_before_plugin_install(self):
        result = self.run_installer("codex", "--skip-cli", MOCK_HELP_FAIL="2")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("plugin add" in line and "--help" not in line for line in self.commands()))

    def test_context7_configuration_never_starts_oauth(self):
        result = self.run_installer("codex", "--skip-cli")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(line.startswith("codex:mcp") for line in self.commands()))
        self.assertIn("codex mcp login context7", result.stdout)


class Context7ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="context7 config ")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "custom codex home"
        self.config = self.directory / "config.toml"
        self.env = dict(os.environ, CODEX_HOME=str(self.directory))

    def configure(self, *args):
        return subprocess.run(
            [sys.executable, str(ROOT / "scripts/ai/configure_context7.py"), *args],
            env=self.env,
            text=True,
            capture_output=True,
            timeout=10,
        )

    def test_creates_missing_config_in_codex_home(self):
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        parsed = tomllib.loads(self.config.read_text())
        self.assertEqual(parsed["mcp_servers"]["context7"]["url"], "https://mcp.context7.com/mcp")

    def test_relaunch_retains_comments_and_has_one_stanza(self):
        self.directory.mkdir()
        original = '# commentaire a conserver\nmodel = "mon-modele" # choix personnel\n'
        self.config.write_text(original)
        self.assertEqual(self.configure().returncode, 0)
        after_first = self.config.read_bytes()
        self.assertEqual(self.configure().returncode, 0)
        self.assertEqual(self.config.read_bytes(), after_first)
        self.assertTrue(self.config.read_text().startswith(original))
        self.assertEqual(self.config.read_text().count("[mcp_servers.context7]"), 1)

    def test_same_url_keeps_auth_and_other_settings_byte_for_byte(self):
        self.directory.mkdir()
        original = (
            '# settings\n[mcp_servers.context7]\nurl = "https://mcp.context7.com/mcp"\n'
            'bearer_token_env_var = "PRIVATE_CONTEXT7_TOKEN" # do not change\n'
            'startup_timeout_sec = 20\n[mcp_servers.context7.http_headers]\n'
            '"X-Custom" = "private-value-not-to-print"\n'
        )
        self.config.write_text(original)
        before = self.config.read_bytes()
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.read_bytes(), before)
        self.assertNotIn("private-value-not-to-print", result.stdout + result.stderr)

    def test_conflicting_url_fails_without_rewriting_or_printing_config(self):
        self.directory.mkdir()
        self.config.write_text('[mcp_servers.context7]\nurl = "https://private.example/mcp"\n')
        before = self.config.read_bytes()
        result = self.configure()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_bytes(), before)
        self.assertNotIn("private.example", result.stdout + result.stderr)

    def test_invalid_toml_fails_without_rewriting(self):
        self.directory.mkdir()
        self.config.write_text('not = [valid\n')
        before = self.config.read_bytes()
        result = self.configure()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_bytes(), before)

    def test_dry_run_does_not_create_directory_or_modify_existing_config(self):
        result = self.configure("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.directory.exists())
        self.directory.mkdir()
        self.config.write_text('# mon choix\nmodel = "custom"\n')
        before = self.config.read_bytes()
        result = self.configure("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
