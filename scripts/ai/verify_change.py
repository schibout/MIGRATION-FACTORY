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
    reason: str = ""


# Only add tests here after verifying that their setup and imports work offline.
BACKEND_TESTS = {
    "backend/services/sql_guard.py": "test_sql_guard.py",
    "backend/services/sql_filters.py": "test_sql_filters.py",
    "backend/services/etl_journal.py": "test_dashboard_synthese.py",
    "backend/services/dashboard_synthese.py": "test_dashboard_synthese.py",
    "backend/api/dashboard.py": "test_dashboard_synthese.py",
}

FINANCE = "backend/api/finance.py"
FINANCE_TESTS = {
    "test_commandes_achat_excel.py": ("export_commandes_achat_excel",),
    "test_finance_articles_filtres.py": ("ART_VUES", "_art_condition", "_art_conditions"),
}


def finance_symbols(source: str) -> dict[str, list[ast.AST]]:
    """Index module-level definitions. Imports and other setup have module-wide scope."""
    symbols: dict[str, list[ast.AST]] = {}
    for node in ast.parse(source).body:
        if isinstance(node, ast.FunctionDef):
            name = node.name
        elif isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
        else:
            name = "<module>"
        symbols.setdefault(name, []).append(node)
    return symbols


def finance_impact(before: str, after: str) -> tuple[set[str], bool]:
    old, new = finance_symbols(before), finance_symbols(after)

    def signature(nodes):
        return [ast.dump(node) for node in nodes]

    changed = {key for key in old.keys() | new.keys()
               if signature(old.get(key, [])) != signature(new.get(key, []))}
    if "<module>" in changed:
        return set(FINANCE_TESTS), True
    selected, covered = set(), set()
    for test, entrypoints in FINANCE_TESTS.items():
        # Include helpers and constants from both versions to catch deletions.
        pending = list(entrypoints)
        seen = set()
        while pending:
            key = pending.pop()
            if key in seen:
                continue
            seen.add(key)
            for node in old.get(key, []) + new.get(key, []):
                pending.extend(ref.id for ref in ast.walk(node)
                               if isinstance(ref, ast.Name) and (ref.id in old or ref.id in new))
        if seen & changed:
            selected.add(test)
        covered.update(seen)
    return selected, bool(changed - covered)


def finance_checks(root: Path) -> tuple[set[str], bool]:
    previous = subprocess.run(["git", "show", "HEAD:" + FINANCE], cwd=root, capture_output=True)
    current = root / FINANCE
    if previous.returncode or not current.is_file():
        return set(FINANCE_TESTS), True
    before = previous.stdout.decode("utf-8-sig").replace("\r\n", "\n")
    after = current.read_text(encoding="utf-8-sig")
    if before == after:
        # An explicit path with no local diff requests the module's audited tests.
        return set(FINANCE_TESTS), False
    try:
        return finance_impact(before, after)
    except SyntaxError:
        return set(FINANCE_TESTS), True  # The syntax check reports the error first.


def frontend_checks(files: list[str], root: Path, full: bool) -> list[Check]:
    paths = [p.removeprefix("frontend/") for p in files if p.startswith("frontend/")]
    if not paths:
        return []
    shared = {"package.json", "package-lock.json", "vite.config.ts", "vitest.config.ts",
              "tsconfig.json", "tsconfig.node.json", ".eslintrc.cjs", "tests/setup.ts", "index.html"}
    source = [p for p in paths if p.startswith(("src/", "tests/"))]
    deleted = [p for p in source if not (root / "frontend" / p).is_file()]
    if full or shared.intersection(paths) or deleted:
        reason = "socle complet" if full else "configuration partagee ou fichier supprime"
        return [Check(kind, command=command, cwd="frontend", reason=reason) for kind, command in (
            ("frontend-lint", ("npm", "run", "lint")),
            ("frontend-tests", ("npm", "test")),
            ("frontend-build", ("npm", "run", "build")),
        )]
    checks = []
    typescript = [p for p in source if p.endswith((".ts", ".tsx"))]
    if typescript:
        checks.append(Check("frontend-lint", command=("npm", "run", "lint:files", "--", *typescript),
                            cwd="frontend", reason="fichiers TypeScript modifies"))
    if source:
        checks.append(Check("frontend-tests", command=("npm", "run", "test:related", "--", *source),
                            cwd="frontend", reason="tests lies par les imports Vitest"))
    assets = tuple(p for p in paths if p.startswith("public/"))
    if assets:
        checks.append(Check("frontend-review", assets, reason="verifier le rendu des ressources publiques modifiees"))
    return checks


def git_names(root: Path, *args: str) -> list[str]:
    result = subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
    return [os.fsdecode(name) for name in result.stdout.split(b"\0") if name]


def collect_files(root: Path, *, staged: bool = False, all_files: bool = False) -> list[str]:
    if all_files:
        return sorted(set(git_names(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z")))
    staged_files = git_names(root, "diff", "--cached", "--no-renames", "--name-only", "-z")
    working_files = git_names(root, "diff", "--no-renames", "--name-only", "-z")
    if staged:
        partial = set(staged_files) & set(working_files)
        if partial:
            raise ValueError("Fichiers partiellement indexes : indexer ou remiser les changements restants avant le controle : " + ", ".join(sorted(partial)))
        return sorted(set(staged_files))
    untracked = git_names(root, "ls-files", "--others", "--exclude-standard", "-z")
    return sorted(set(staged_files + working_files + untracked))


def build_plan(files: list[str], *, full: bool = False, root: Path = Path(__file__).resolve().parents[2]) -> list[Check]:
    files = sorted({Path(path.replace("\\", "/")).as_posix() for path in files})
    checks: list[Check] = []
    for kind, suffixes in [("python-syntax", (".py",)), ("json-syntax", (".json",)), ("bash-syntax", (".sh", ".bash"))]:
        paths = tuple(path for path in files if path.endswith(suffixes))
        if paths:
            checks.append(Check(kind, paths))
    audited = set(BACKEND_TESTS.values()) | set(FINANCE_TESTS)
    by_path = {**BACKEND_TESTS, **{"backend/tests/" + name: name for name in audited}}
    selected = {by_path[p] for p in files if p in by_path}
    finance_review = False
    if FINANCE in files and not full:
        affected, finance_review = finance_checks(root)
        selected.update(affected)
    if full or "backend/conftest.py" in files:
        selected = audited
    if selected:
        checks.append(Check("backend-tests", command=(sys.executable, "-m", "pytest", "-q",
                            *("tests/" + name for name in sorted(selected))), cwd="backend",
                            reason="tests hors ligne associes aux fichiers"))
    unmapped = tuple(p for p in files if p.startswith("backend/") and p.endswith(".py")
                     and p not in by_path and p not in (FINANCE, "backend/conftest.py"))
    if finance_review:
        unmapped += (FINANCE,)
    if unmapped and not full:
        checks.append(Check("backend-review", unmapped, reason="aucun test hors ligne associe ; verifier le comportement modifie"))
    if any(path.startswith(("scripts/ai/", "tests/")) for path in files):
        tooling = {p for p in files if p.startswith(("scripts/ai/", "tests/"))}
        pattern = "test_verify_change.py" if not full and tooling <= {
            "scripts/ai/verify_change.py", "scripts/ai/install_hooks.py", "tests/test_verify_change.py"
        } else "test_*.py"
        checks.append(Check("tooling-tests", command=(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", pattern)))
    if any(path.startswith((".agents/skills/", ".claude/skills/")) or path == "scripts/ai/sync_skills.py" for path in files):
        checks.append(Check("skill-sync", command=(sys.executable, "scripts/ai/sync_skills.py", "--check")))
    checks.extend(frontend_checks(files, root, full))
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
    # Un hook Git exporte GIT_INDEX_FILE et GIT_DIR : transmis aux controles, les
    # tests qui creent un depot temporaire agiraient sur l'index du vrai depot.
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
    for check in checks:
        print("Controle : " + check.kind + (" - " + check.reason if check.reason else ""), flush=True)
        if check.kind in ("backend-review", "frontend-review"):
            print(", ".join(check.paths))
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
        checks = build_plan(files, full=args.all_files, root=root)
        if args.plan:
            for check in checks:
                detail = shlex.join(check.command) if check.command else f"{len(check.paths)} fichier(s)"
                if check.kind in ("backend-review", "frontend-review"):
                    detail = ", ".join(check.paths)
                print(check.kind + (" - " + check.reason if check.reason else "") + " : " + detail)
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
