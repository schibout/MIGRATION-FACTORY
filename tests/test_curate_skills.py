from pathlib import Path
import sys
import tempfile
import unittest


class CurateSkillsTests(unittest.TestCase):
    def test_only_exact_known_duplicates_are_selected(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/ai'))
        try:
            from curate_skills import duplicates
            with tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                base = home / '.agents/skills/engineering'
                for name, same in [('chaos-engineering', True), ('kubernetes-operator', False)]:
                    generic = base / 'skills' / name / 'SKILL.md'
                    dedicated = base / name / 'skills' / name / 'SKILL.md'
                    for p in (generic, dedicated):
                        p.parent.mkdir(parents=True)
                        p.write_text('same')
                    if not same:
                        dedicated.write_text('different')
                result = duplicates(home)
                self.assertEqual(len(result), 1)
                self.assertEqual(result[0].parent.name, 'chaos-engineering')
        finally:
            sys.path.pop(0)


if __name__ == '__main__':
    unittest.main()
