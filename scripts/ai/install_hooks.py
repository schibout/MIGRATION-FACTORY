#!/usr/bin/env python3
"""Install the project pre-commit hook without replacing personal hooks."""
from __future__ import annotations

from pathlib import Path
import subprocess
import sys


MARKER = "# migration-factory managed pre-commit"


def install(root: Path) -> Path:
    custom = subprocess.run(["git", "-C", str(root), "config", "--get", "core.hooksPath"], capture_output=True, text=True)
    if custom.returncode not in (0, 1):
        raise ValueError("Impossible de lire la configuration Git.")
    if custom.stdout.strip():
        raise ValueError("core.hooksPath est deja configure ; integrer scripts/ai/pre_commit manuellement au hook existant.")
    result = subprocess.run(["git", "-C", str(root), "rev-parse", "--git-path", "hooks"], check=True, capture_output=True, text=True)
    folder = Path(result.stdout.strip())
    if not folder.is_absolute():
        folder = root / folder
    target = folder / "pre-commit"
    if target.exists() and MARKER not in target.read_text(encoding="utf-8"):
        raise ValueError("Hook pre-commit existant : aucune modification effectuee.")
    body = "#!/bin/sh\n" + MARKER + '\nexec sh "$(git rev-parse --show-toplevel)/scripts/ai/pre_commit"\n'
    folder.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8", newline="\n")
    target.chmod(target.stat().st_mode | 0o111)
    return target


def main() -> int:
    try:
        print("Hook installe : " + str(install(Path(__file__).resolve().parents[2])))
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("Installation du hook impossible : " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
