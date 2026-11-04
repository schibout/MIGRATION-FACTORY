#!/usr/bin/env python3
"""Retirer le MCP archive ou enregistrer postgres-dev, avec sauvegarde et simulation."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tomllib
import uuid

from postgres_mcp import validate_uri

ROOT = Path(__file__).resolve().parents[2]


def without_server(text: str, name: str) -> str:
    """Retire une table MCP et ses sous-tables, en conservant le reste du TOML."""
    lines = []
    skip = False
    pattern = re.compile(r'^\[mcp_servers\.(?:' + re.escape(name) + r'|"' + re.escape(name) + r'")(?:\.|\])')
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith('['):
            skip = bool(pattern.match(line.strip()))
        if not skip:
            lines.append(line)
    result = ''.join(lines)
    if name in tomllib.loads(result).get('mcp_servers', {}):
        raise ValueError('Format TOML MCP non gere ; aucune modification appliquee')
    return result


def proposed_changes(home: Path, root: Path, *, retire: bool, enable: bool) -> dict[Path, str]:
    changes = {}
    wrapper = str(root / 'scripts/ai/postgres_mcp.py')
    claude_config = home / '.claude.json'
    if claude_config.exists() or enable:
        original = claude_config.read_text(encoding='utf-8-sig') if claude_config.exists() else '{}'
        data = json.loads(original)
        servers = data.setdefault('mcpServers', {})
        old = servers.get('postgres', {})
        if retire and '@modelcontextprotocol/server-postgres' in old.get('args', []):
            del servers['postgres']
        if enable:
            server = {'type': 'stdio', 'command': sys.executable, 'args': [wrapper]}
            if 'postgres-dev' in servers and servers['postgres-dev'] != server:
                raise ValueError('postgres-dev Claude existe deja avec une autre configuration')
            servers['postgres-dev'] = server
        if data != json.loads(original):
            changes[claude_config] = json.dumps(data, indent=2, ensure_ascii=True) + '\n'

    codex_config = Path(os.environ.get('CODEX_HOME', home / '.codex')) / 'config.toml'
    if codex_config.exists() or enable:
        original = codex_config.read_text(encoding='utf-8-sig') if codex_config.exists() else ''
        text = original
        parsed = tomllib.loads(text)
        old = parsed.get('mcp_servers', {}).get('postgres', {})
        if retire and '@modelcontextprotocol/server-postgres' in old.get('args', []):
            text = without_server(text, 'postgres')
        if enable:
            server = {'command': sys.executable, 'args': [wrapper], 'env_vars': ['MIGRATION_FACTORY_DEV_DATABASE_URL']}
            existing = parsed.get('mcp_servers', {}).get('postgres-dev')
            if existing is not None and existing != server:
                raise ValueError('postgres-dev Codex existe deja avec une autre configuration')
            if existing is None:
                text = text.rstrip() + '\n\n[mcp_servers.postgres-dev]\n'
                for key, value in server.items():
                    text += key + ' = ' + json.dumps(value) + '\n'
        tomllib.loads(text)
        if text != original:
            changes[codex_config] = text

    # Supprimer les permissions memorisant un mot de passe, sans lire de .env.
    for path in [home / '.claude/settings.json', root / '.claude/settings.local.json']:
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        permissions = data.get('permissions', {})
        allowed = permissions.get('allow', [])
        kept = [value for value in allowed if 'PGPASSWORD' not in value.upper()
                and not (value.startswith('Read(') and '.claude/**' in value)]
        if retire and kept != allowed:
            permissions['allow'] = kept
            changes[path] = json.dumps(data, indent=2, ensure_ascii=True) + '\n'
    return changes


def apply_changes(changes: dict[Path, str], home: Path) -> Path | None:
    if not changes:
        return None
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
    backup = home / '.migration-factory/backups' / (stamp + '-postgres')
    backup.mkdir(parents=True, mode=0o700)
    manifest = {}
    for index, (path, text) in enumerate(changes.items()):
        if path.exists():
            target = backup / (str(index) + '-' + path.name)
            shutil.copy2(path, target)
            target.chmod(0o600)
            manifest[target.name] = str(path)
    # Sauvegarder tous les fichiers avant la premiere modification.
    (backup / 'restore.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    for path, text in changes.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8', newline='\n')
        path.chmod(0o600)
    return backup


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--retire-legacy', action='store_true', help='Retirer le serveur archive et les permissions contenant PGPASSWORD')
    parser.add_argument('--enable', action='store_true', help='Enregistrer postgres-dev apres provisionnement manuel du role')
    parser.add_argument('--apply', action='store_true', help='Appliquer ; sinon simulation sans ecriture')
    args = parser.parse_args()
    if not (args.retire_legacy or args.enable):
        parser.error('Choisir --retire-legacy et/ou --enable')
    try:
        if args.enable:
            validate_uri(os.environ.get('MIGRATION_FACTORY_DEV_DATABASE_URL', ''))
        changes = proposed_changes(Path.home(), ROOT, retire=args.retire_legacy, enable=args.enable)
        for path in changes:
            print('Configuration a mettre a jour :', path)
        if args.apply:
            backup = apply_changes(changes, Path.home())
            print('Sauvegarde :', backup or 'aucune modification necessaire')
        else:
            print('Simulation ; ajouter --apply pour appliquer. Aucun acces a la base.')
        return 0
    except (OSError, ValueError) as exc:
        # Ne pas exposer les lignes du fichier ni les URI en cas d'erreur.
        print('Configuration refusee (' + type(exc).__name__ + '). Verifier les fichiers ou la variable requise.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
