#!/usr/bin/env python3
"""Synchronise uniquement les skills projet, sans toucher au catalogue global."""

import argparse
from datetime import datetime, timezone
from pathlib import Path
import shutil
import uuid

SKILLS = ('migration-factory', 'verify-change', 'deploy-serveur')
ROOT = Path(__file__).resolve().parents[2]


def sync(root: Path, check: bool = False) -> bool:
    root = root.resolve()
    pairs = [(root / '.agents/skills' / name / 'SKILL.md',
              root / '.claude/skills' / name / 'SKILL.md') for name in SKILLS]
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
    # Preflight before any write; refuse destination links escaping the repository.
    for source, target in pairs:
        if not source.is_file():
            raise FileNotFoundError(source)
        if not source.resolve().is_relative_to(root):
            raise ValueError('Source de skill hors du depot')
        if not target.resolve().is_relative_to(root):
            raise ValueError('Destination de skill hors du depot')
        backup = root / '.ai-backups' / stamp / target.relative_to(root)
        if not backup.resolve().is_relative_to(root):
            raise ValueError('Sauvegarde de skill hors du depot')
    valid = True
    for source, target in pairs:
        data = source.read_bytes()
        if target.exists() and target.read_bytes() == data:
            continue
        if check:
            print('Skill manquant ou different :', target.relative_to(root))
            valid = False
            continue
        if target.exists():
            backup = root / '.ai-backups' / stamp / target.relative_to(root)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print('Skill synchronise :', target.relative_to(root))
    return valid


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verifier sans ecrire')
    args = parser.parse_args()
    return 0 if sync(ROOT, check=args.check) else 1


if __name__ == '__main__':
    raise SystemExit(main())
