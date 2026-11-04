import importlib.util
import json
import os
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest import mock
import sys


class PostgresSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ai setup ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/ai'))
        self.addCleanup(sys.path.pop, 0)
        import setup_postgres
        self.module = setup_postgres

    def test_retirement_preserves_other_config_and_is_idempotent(self):
        home = self.root
        claude = home / '.claude.json'
        claude.write_text(json.dumps({'mcpServers': {'postgres': {'args': ['@modelcontextprotocol/server-postgres', 'secret']}, 'other': {'url': 'https://example.org'}}, 'theme': 'dark'}))
        codex = home / '.codex/config.toml'
        codex.parent.mkdir()
        codex.write_text('model = "user-model"\n[mcp_servers.postgres]\nargs = ["@modelcontextprotocol/server-postgres", "secret"]\n[mcp_servers.other]\nurl = "https://example.org"\n')
        with mock.patch.dict(os.environ, {'CODEX_HOME': str(codex.parent)}):
            changes = self.module.proposed_changes(home, self.root, retire=True, enable=False)
            self.assertIn('secret', claude.read_text())  # simulation writes nothing
            backup = self.module.apply_changes(changes, home)
            self.assertIn('secret', (backup / '0-.claude.json').read_text())
            self.assertNotIn('postgres', json.loads(claude.read_text())['mcpServers'])
            data = tomllib.loads(codex.read_text())
            self.assertEqual(data['model'], 'user-model')
            self.assertEqual(data['mcp_servers']['other']['url'], 'https://example.org')
            self.assertEqual(self.module.proposed_changes(home, self.root, retire=True, enable=False), {})

    def test_enable_does_not_persist_database_password(self):
        with mock.patch.dict(os.environ, {'CODEX_HOME': str(self.root / '.codex')}):
            changes = self.module.proposed_changes(self.root, self.root, retire=False, enable=True)
        self.assertEqual(len(changes), 2)
        for text in changes.values():
            self.assertNotIn('postgresql://', text)
            self.assertIn('postgres-dev', text)

    def test_password_permissions_removed_without_touching_other_permissions(self):
        p = self.root / '.claude/settings.local.json'
        p.parent.mkdir(parents=True)
        p.write_text(json.dumps({'permissions': {'allow': ['Bash(git status)', 'PowerShell($env:PGPASSWORD = secret)']}}))
        with mock.patch.dict(os.environ, {'CODEX_HOME': str(self.root / '.codex')}):
            changes = self.module.proposed_changes(self.root, self.root, retire=True, enable=False)
        self.assertEqual(json.loads(changes[p])['permissions']['allow'], ['Bash(git status)'])


if __name__ == '__main__':
    unittest.main()
