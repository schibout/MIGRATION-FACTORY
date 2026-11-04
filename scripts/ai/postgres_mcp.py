#!/usr/bin/env python3
"""Lance le MCP PostgreSQL optionnel avec un role de developpement dedie."""

import os
import shutil
import subprocess
import sys
from urllib.parse import urlsplit


def validate_uri(uri: str) -> None:
    try:
        parsed = urlsplit(uri)
        if (parsed.scheme not in ('postgres', 'postgresql') or not parsed.hostname
                or parsed.query or parsed.fragment
                or parsed.username != 'factory_dev_reader' or not parsed.path.strip('/')):
            raise ValueError
    except ValueError:
        raise ValueError(
            'Definir MIGRATION_FACTORY_DEV_DATABASE_URL avec le role factory_dev_reader '
            'et une base explicite, sans query string ni fragment ; aucun compte administrateur accepte.'
        ) from None


def main() -> int:
    uri = os.environ.get('MIGRATION_FACTORY_DEV_DATABASE_URL', '')
    try:
        validate_uri(uri)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    uvx = shutil.which('uvx')
    if not uvx:
        print('uvx absent : installer uv avant d\'activer postgres-dev (voir README).', file=sys.stderr)
        return 2
    env = dict(os.environ, DATABASE_URI=uri)
    # uv isole le MCP (Python 3.12) de Python 3.11 utilise par le backend.
    result = subprocess.run(
        [uvx, '--python', '3.12', '--from', 'postgres-mcp==0.3.0',
         'postgres-mcp', '--access-mode=restricted'],
        env=env, check=False,
    )
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
