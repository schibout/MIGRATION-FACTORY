#!/usr/bin/env python3
"""Desactive seulement les entrees SKILL.md exactement dupliquees, avec sauvegarde."""

import argparse
from datetime import datetime, timezone
from pathlib import Path
import shutil
import uuid


NAMES = ('chaos-engineering', 'slo-architect', 'feature-flags-architect', 'kubernetes-operator')


def duplicates(home: Path) -> list[Path]:
    result = []
    for platform in ('.agents', '.claude'):
        base = home / platform / 'skills/engineering'
        for name in NAMES:
            generic = base / 'skills' / name / 'SKILL.md'
            dedicated = base / name / 'skills' / name / 'SKILL.md'
            if (generic.is_file() and dedicated.is_file()
                    and generic.read_bytes() == dedicated.read_bytes()):
                result.append(generic)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Sauvegarder puis retirer les seules entrees dupliquees')
    args = parser.parse_args()
    home = Path.home()
    files = duplicates(home)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
    backup = home / '.migration-factory/backups' / (stamp + '-skills')
    for path in files:
        if not path.resolve().is_relative_to(home.resolve()):
            raise ValueError('Skill hors du repertoire utilisateur')
        print('Doublon exact :', path)
    if args.apply and files:
        backup.mkdir(parents=True, mode=0o700)
        for path in files:
            target = backup / path.relative_to(home)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        # Toutes les copies sont sauvegardees avant de retirer la decouverte.
        for path in files:
            path.unlink()
        print('Sauvegarde :', backup)
    elif not args.apply:
        print('Simulation :', len(files), 'entree(s), aucune suppression. Ajouter --apply.')
    else:
        print('Aucun doublon exact a retirer.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
