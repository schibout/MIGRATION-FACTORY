#!/usr/bin/env python3
"""Controle en lecture seule de l'installation Claude Code du poste.

Ne modifie rien et n'affiche jamais une valeur secrete : seulement des noms de
fichiers et des compteurs. Code de sortie 1 si au moins un point est a traiter.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

MEMORY_MAX_LINES = 200  # Au-dela, Claude Code ne charge pas la fin de MEMORY.md.
MEMORY_MAX_BYTES = 25_000
MAX_ALLOW_RULES = 50
MAX_PERSONAL_SKILLS = 30
SECRET = re.compile(
    r"PGPASSWORD=\S|(?:password|passwd|mot de passe)\s*[:=]\s*\S{4}"
    r"|nvapi-\w|sk-[\w-]{10}|ghp_\w|://[^/\s:]+:[^@\s]+@",
    re.IGNORECASE,
)


def audit_memory(memory: Path) -> list[str]:
    index = memory / "MEMORY.md"
    if not index.is_file():
        return []
    text = index.read_text(encoding="utf-8", errors="replace")
    warnings = []
    if len(text.splitlines()) > MEMORY_MAX_LINES or len(text.encode()) > MEMORY_MAX_BYTES:
        warnings.append(f"MEMORY.md depasse {MEMORY_MAX_LINES} lignes ou {MEMORY_MAX_BYTES} o : la fin n'est pas chargee.")
    for path in sorted(memory.glob("*.md")):
        if SECRET.search(path.read_text(encoding="utf-8", errors="replace")):
            warnings.append(f"Secret probable en clair dans la memoire : {path.name}")
        if path != index and path.name not in text:
            warnings.append(f"Memoire absente de l'index MEMORY.md : {path.name}")
    return warnings


def load_settings(*paths: Path) -> list[dict]:
    settings = []
    for path in paths:
        if path.is_file():
            try:
                settings.append(json.loads(path.read_text(encoding="utf-8")))
            except ValueError:
                print(f"AVERTISSEMENT  JSON invalide, fichier ignore : {path}")
    return settings


def audit_permissions(settings: list[dict]) -> list[str]:
    rules = [s.get("permissions", {}) for s in settings]
    allow = [rule for r in rules for rule in r.get("allow", [])]
    deny = [rule for r in rules for rule in r.get("deny", [])]
    warnings = []
    if len(allow) > MAX_ALLOW_RULES:
        warnings.append(f"{len(allow)} regles allow : purger les autorisations ponctuelles accumulees.")
    if not any(".env" in rule for rule in deny):
        warnings.append("Aucune regle deny sur .env : la lecture des secrets n'est pas bloquee.")
    if not any(".credentials" in rule for rule in deny):
        warnings.append("Aucune regle deny sur .credentials.json.")
    if "mcp__postgres__query" in allow:
        warnings.append("Regle mcp__postgres__query obsolete : le MCP PostgreSQL a ete retire.")
    return warnings


def audit_worktrees(root: Path) -> list[str]:
    warnings = []
    for worktree in sorted((root / ".claude/worktrees").glob("*")):
        link = worktree / ".git"
        if link.is_file():
            target = link.read_text(encoding="utf-8").removeprefix("gitdir:").strip()
            if not Path(target).exists():
                warnings.append(f"Worktree orphelin (pointeur git casse) : {worktree.name}")
    return warnings


def audit_cli() -> list[str]:
    found = {Path(p).parent for p in filter(None, (
        shutil.which("claude", path=d) for d in os.environ.get("PATH", "").split(os.pathsep) if d))}
    if len(found) > 1:
        return ["Plusieurs CLI claude dans le PATH : " + ", ".join(sorted(map(str, found)))]
    return []


def audit_credentials(config: Path) -> list[str]:
    path = config / ".credentials.json"
    if os.name != "nt" or not path.is_file():
        return []
    acl = subprocess.run(["icacls", str(path)], capture_output=True, text=True, errors="replace").stdout
    if "Sandbox" in acl:
        return [".credentials.json lisible par un groupe bac a sable (voir icacls)."]
    return []


def audit(root: Path, config: Path) -> list[str]:
    # Meme encodage de dossier que Claude Code ; NTFS ignore la casse du lecteur.
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(root))
    warnings = audit_memory(config / "projects" / slug / "memory")
    warnings += audit_permissions(load_settings(
        config / "settings.json",
        root / ".claude/settings.json",
        root / ".claude/settings.local.json",
    ))
    warnings += audit_worktrees(root)
    warnings += audit_cli()
    warnings += audit_credentials(config)
    skills = sum(1 for _ in (config / "skills").rglob("SKILL.md"))
    if skills > MAX_PERSONAL_SKILLS:
        warnings.append(f"{skills} skills personnels : leurs descriptions saturent le budget de listing.")
    hook = root / ".git/hooks/pre-commit"
    if not hook.is_file() or "migration-factory managed" not in hook.read_text(encoding="utf-8", errors="replace"):
        warnings.append("Hook pre-commit du projet absent : python scripts/ai/install_hooks.py")
    return warnings


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    config = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
    warnings = audit(root, config)
    for warning in warnings:
        print("A TRAITER  " + warning)
    print(f"{len(warnings)} point(s) a traiter." if warnings else "Aucun point a traiter.")
    return 1 if warnings else 0


if __name__ == "__main__":
    sys.exit(main())
