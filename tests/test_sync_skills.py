import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/ai/sync_skills.py'


class SyncSkillsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ai skills ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        spec = importlib.util.spec_from_file_location('sync_skills', SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        for name in self.module.SKILLS:
            p = self.root / '.agents/skills' / name / 'SKILL.md'
            p.parent.mkdir(parents=True)
            p.write_text('name: ' + name + '\n', encoding='utf-8')

    def test_check_does_not_create_files_and_detects_missing_copy(self):
        self.assertFalse(self.module.sync(self.root, check=True))
        self.assertFalse((self.root / '.claude').exists())

    def test_sync_is_idempotent_and_preserves_unmanaged_skills(self):
        other = self.root / '.claude/skills/personal/SKILL.md'
        other.parent.mkdir(parents=True)
        other.write_text('keep')
        self.assertTrue(self.module.sync(self.root))
        self.assertTrue(self.module.sync(self.root, check=True))
        self.assertTrue(self.module.sync(self.root))
        self.assertEqual(other.read_text(), 'keep')
        self.assertFalse((self.root / '.ai-backups').exists())

    def test_changed_copy_is_backed_up_before_replacement(self):
        self.module.sync(self.root)
        p = self.root / '.claude/skills/migration-factory/SKILL.md'
        p.write_text('ancienne version')
        self.assertFalse(self.module.sync(self.root, check=True))
        self.module.sync(self.root)
        backups = list((self.root / '.ai-backups').rglob('SKILL.md'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'ancienne version')

    def test_source_missing_fails_without_creating_partial_copies(self):
        (self.root / '.agents/skills/verify-change/SKILL.md').unlink()
        with self.assertRaises(FileNotFoundError):
            self.module.sync(self.root)
        self.assertFalse((self.root / '.claude').exists())

    def test_external_source_and_backup_links_are_rejected_before_writes(self):
        with tempfile.TemporaryDirectory(prefix='external skill ') as outside:
            external = Path(outside)
            source = self.root / '.agents/skills/migration-factory/SKILL.md'
            secret = external / 'private.md'
            secret.write_text('do not copy')
            source.unlink()
            try:
                source.symlink_to(secret)
            except OSError:
                self.skipTest('Creation de liens indisponible sur ce poste')
            with self.assertRaises(ValueError):
                self.module.sync(self.root)
            self.assertFalse((self.root / '.claude').exists())
            source.unlink()
            source.write_text('safe')
            (self.root / '.ai-backups').symlink_to(external, target_is_directory=True)
            with self.assertRaises(ValueError):
                self.module.sync(self.root)
            self.assertFalse((self.root / '.claude').exists())
            self.assertEqual(list(external.iterdir()), [secret])


if __name__ == '__main__':
    unittest.main()
