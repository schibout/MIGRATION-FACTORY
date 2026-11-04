#!/usr/bin/env python3
"""Select deterministic checks without importing the application or contacting its DB."""
from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


@dataclass(frozen=True)
class Check:
    kind: str
    paths: tuple[str, ...] = ()
    command: tuple[str, ...] = ()
    cwd: str = "."


def git_names(root: Path, *args: str) -> list[str]:
    result = subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
    return [os.fsdecode(name) for name in result.stdout.split(b"\0") if name]


def collect_files(root: Path, *, staged: bool = False, all_files: bool = False) -> list[str]:
    if all_files:
        return sorted(set(git_names(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z")))
    staged_files = git_names(root, "diff", "--cached", "--name-only", "-z")
    working_files = git_names(root, "diff", "--name-only", "-z")
    if staged:
        partial = set(staged_files) & set(working_files)
        if partial:
            raise ValueError("Fichiers partiellement indexes : indexer ou remiser les changements restants avant le controle : " + ", ".join(sorted(partial)))
        return sorted(set(staged_files))
    untracked = git_names(root, "ls-files", "--others", "--exclude-standard", "-z")
    return sorted(set(staged_files + working_files + untracked))


def build_plan(files: list[str]) -> list[Check]:
    files = sorted(set(path.replace("\\", "/") for path in files))
    checks: list[Check] = []
    for kind, suffixes in [("python-syntax", (".py",)), ("json-syntax", (".json",)), ("bash-syntax", (".sh", ".bash"))]:
        paths = tuple(path for path in files if path.endswith(suffixes))
        if paths:
            checks.append(Check(kind, paths))
    if any(path.startswith("backend/") for path in files):
        # Deliberately explicit: discovery would include integration tests using the real DB.
        checks.append(Check("backend-tests", command=(sys.executable, "-m", "pytest", "tests/test_sql_guard.py", "tests/test_sql_filters.py", "-q"), cwd="backend"))
    if any(path.startswith(("scripts/ai/", "tests/")) for path in files):
        checks.append(Check("tooling-tests", command=(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py")))
    if any(path.startswith((".agents/skills/", ".claude/skills/")) or path == "scripts/ai/sync_skills.py" for path in files):
        checks.append(Check("skill-sync", command=(sys.executable, "scripts/ai/sync_skills.py", "--check")))
    if any(path.startswith("frontend/") for path in files):
        checks.append(Check("frontend-lint", command=("npm", "run", "lint"), cwd="frontend"))
        checks.append(Check("frontend-tests", command=("npm", "test"), cwd="frontend"))
        checks.append(Check("frontend-build", command=("npm", "run", "build"), cwd="frontend"))
    sql = tuple(path for path in files if path.endswith(".sql"))
    if sql:
        checks.append(Check("sql-review", sql))
    return checks


def bash_executable() -> str:
    if os.name == "nt":
        for prefix in [os.environ.get("ProgramFiles", "C:/Program Files"), os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")]:
            candidate = Path(prefix) / "Git/bin/bash.exe"
            if candidate.is_file():
                return str(candidate)
    result = shutil.which("bash")
    if not result:
        raise ValueError("Bash absent : installer Git Bash sur Windows ou Bash dans cet environnement.")
    return result


def contained_path(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Chemin hors du depot : " + name)
    return path


def run_checks(root: Path, checks: list[Check], *, runner=subprocess.run) -> int:
    environment = os.environ.copy()
    environment["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
    for check in checks:
        print("Controle : " + check.kind, flush=True)
        for name in check.paths:
            path = contained_path(root, name)
            if not path.is_file():
                continue  # A deleted file still selects the relevant regression checks.
            try:
                if check.kind == "python-syntax":
                    ast.parse(path.read_text(encoding="utf-8-sig"), filename=name)
                elif check.kind == "json-syntax":
                    json.loads(path.read_text(encoding="utf-8-sig"))
                elif check.kind == "bash-syntax":
                    result = runner([bash_executable(), "-n", name], cwd=root, env=environment)
                    if result.returncode:
                        return result.returncode
            except (SyntaxError, UnicodeError, json.JSONDecodeError) as exc:
                # Never include source lines: they could contain a local secret.
                print(f"Syntaxe invalide : {name} ({type(exc).__name__}, ligne {getattr(exc, 'lineno', '?')})", file=sys.stderr)
                return 1
        if check.kind == "sql-review":
            print(f"Revue SQL manuelle requise ({len(check.paths)} fichier(s)) : aucune requete executee, semantique non validee.", flush=True)
        if check.command:
            command = list(check.command)
            if command[0] == "npm" and os.name == "nt":
                command[0] = shutil.which("npm.cmd") or "npm.cmd"
            result = runner(command, cwd=root / check.cwd, env=environment)
            if result.returncode:
                return result.returncode
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="Verifier les fichiers indexes ; refuser l'indexation partielle.")
    mode.add_argument("--all", action="store_true", dest="all_files", help="Verifier les fichiers suivis et non ignores du depot.")
    parser.add_argument("--plan", action="store_true", help="Afficher les controles sans les executer.")
    parser.add_argument("files", nargs="*", help="Fichiers relatifs explicites, sinon modifications Git.")
    args = parser.parse_args(argv)
    if args.files and (args.staged or args.all_files):
        parser.error("Utiliser des fichiers explicites OU --staged/--all.")
    root = Path(__file__).resolve().parents[2]
    try:
        files = args.files or collect_files(root, staged=args.staged, all_files=args.all_files)
        for name in files:
            path = contained_path(root, name)
            if path.name in {".env", "secrets.json", "settings.local.json"} or (path.name.startswith(".env.") and path.name != ".env.example") or path.suffix in {".pem", ".key"}:
                raise ValueError("Fichier de secrets exclu du workflow : " + name)
        checks = build_plan(files)
        if args.plan:
            for check in checks:
                print(check.kind + (" : " + shlex.join(check.command) if check.command else f" : {len(check.paths)} fichier(s)"))
            return 0
        if not checks:
            print("Aucun controle executable selectionne pour ces modifications.")
        status = run_checks(root, checks)
        if status == 0:
            print("Controles selectionnes termines. Les tests de base distante ne sont jamais lances ici.")
        return status
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("Verification impossible : " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
