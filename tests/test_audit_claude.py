"""Controles de l'audit Claude, sans lire la configuration reelle du poste."""

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts/ai"))
import audit_claude  # noqa: E402


class AuditClaudeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)

    def test_secret_is_reported_by_file_name_without_its_value(self):
        (self.base / "MEMORY.md").write_text("- [a.md](a.md)\n", encoding="utf-8")
        (self.base / "a.md").write_text("PGPASSWORD=valeur-privee psql\n", encoding="utf-8")
        warnings = audit_claude.audit_memory(self.base)
        self.assertEqual(len(warnings), 1)
        self.assertIn("a.md", warnings[0])
        self.assertNotIn("valeur-privee", warnings[0])

    def test_oversized_index_and_unindexed_memory_are_reported(self):
        (self.base / "MEMORY.md").write_text("x\n" * 201, encoding="utf-8")
        (self.base / "orpheline.md").write_text("contenu\n", encoding="utf-8")
        warnings = "\n".join(audit_claude.audit_memory(self.base))
        self.assertIn("200 lignes", warnings)
        self.assertIn("orpheline.md", warnings)

    def test_clean_memory_has_no_warning(self):
        (self.base / "MEMORY.md").write_text("- [a.md](a.md)\n", encoding="utf-8")
        (self.base / "a.md").write_text("Fait utile.\n", encoding="utf-8")
        self.assertEqual(audit_claude.audit_memory(self.base), [])

    def test_permissions(self):
        clean = {"permissions": {"deny": ["Read(./.env)", "Read(~/.claude/.credentials.json)"]}}
        self.assertEqual(audit_claude.audit_permissions([clean]), [])
        warnings = "\n".join(audit_claude.audit_permissions(
            [{"permissions": {"allow": ["mcp__postgres__query"] + ["r"] * 50}}]))
        for expected in ("51 regles", ".env", ".credentials", "obsolete"):
            self.assertIn(expected, warnings)

    def test_worktree_with_broken_git_pointer_is_orphan(self):
        worktrees = self.base / ".claude/worktrees"
        (worktrees / "orphelin").mkdir(parents=True)
        (worktrees / "orphelin/.git").write_text(f"gitdir: {self.base / 'absent'}\n", encoding="utf-8")
        (worktrees / "valide").mkdir()
        (worktrees / "valide/.git").write_text(f"gitdir: {self.base}\n", encoding="utf-8")
        warnings = audit_claude.audit_worktrees(self.base)
        self.assertEqual(len(warnings), 1)
        self.assertIn("orphelin", warnings[0])


if __name__ == "__main__":
    unittest.main()
