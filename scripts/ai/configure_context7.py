"""Add Context7 to Codex without starting an interactive OAuth flow.

Append a stanza instead of serializing the TOML document, preserving existing
comments, formatting, credentials and all unrelated settings. The installer
backs up the user configuration before calling this helper.
"""

import argparse
import os
from pathlib import Path
import stat
import sys
import tempfile
import tomllib


CONTEXT7_URL = "https://mcp.context7.com/mcp"
STANZA = f'[mcp_servers.context7]\nurl = "{CONTEXT7_URL}"\n'.encode("utf-8")


def configure(*, dry_run=False):
    directory = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
    # Preserve an existing config symlink rather than replacing the link.
    path = (directory / "config.toml").resolve()
    original = path.read_bytes() if path.exists() else b""
    try:
        parsed = tomllib.loads(original.decode("utf-8-sig"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError):
        raise ValueError("config.toml invalide ; aucun changement effectue.") from None
    servers = parsed.get("mcp_servers", {})
    if not isinstance(servers, dict):
        raise ValueError("Configuration MCP incompatible ; aucun changement effectue.")
    if "context7" in servers:
        server = servers["context7"]
        if not isinstance(server, dict) or server.get("url") != CONTEXT7_URL:
            raise ValueError("Un serveur context7 different existe deja ; aucun changement effectue.")
        print("Context7 deja configure ; parametres existants conserves.")
        return

    separator = b"\n\n" if original else b""
    candidate = original + separator + STANZA
    try:
        tomllib.loads(candidate.decode("utf-8-sig"))
    except tomllib.TOMLDecodeError:
        # For example, TOML prohibits extending a sealed inline mcp_servers
        # table. Never rewrite that table and risk losing custom settings.
        raise ValueError("Impossible d'ajouter une section MCP a ce format TOML ; aucun changement effectue.") from None
    if dry_run:
        print("Simulation : ajouter Context7 a la configuration Codex.")
        return

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".context7-", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(candidate)
        temporary.chmod(mode)
        if path.exists() and path.read_bytes() != original:
            raise ValueError("Configuration modifiee simultanement ; relancer l'installation.")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
    print("Context7 configure sans connexion OAuth.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        configure(dry_run=args.dry_run)
    except (ValueError, OSError) as exc:
        # Error text from OSError can include private paths; never dump config.
        message = str(exc) if isinstance(exc, ValueError) else "Impossible d'acceder a la configuration Codex."
        print(f"Erreur : {message}", file=sys.stderr)
        return 1
    print("Si une authentification est necessaire, lancer manuellement : codex mcp login context7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
