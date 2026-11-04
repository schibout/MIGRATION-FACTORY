import importlib.util
from pathlib import Path
from unittest import mock
import unittest


class PostgresLauncherTests(unittest.TestCase):
    def setUp(self):
        p = Path(__file__).resolve().parents[1] / 'scripts/ai/postgres_mcp.py'
        spec = importlib.util.spec_from_file_location('postgres_launcher', p)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_missing_uri_and_administrator_are_rejected(self):
        for uri in ['', 'postgresql://postgres:secret@db/app',
                    'postgresql://other:secret@db/app', 'https://factory_dev_reader@db/app',
                    'postgresql://factory_dev_reader@db/app?user=postgres',
                    'postgresql://factory_dev_reader@db/app?service=admin',
                    'postgresql://factory_dev_reader@db/app?options=-c%20role=postgres',
                    'postgresql://factory_dev_reader@db/app#fragment']:
            with self.subTest(uri=uri), self.assertRaises(ValueError):
                self.module.validate_uri(uri)

    def test_launch_uses_environment_and_restricted_mode(self):
        uri = 'postgresql://factory_dev_reader:secret@localhost/app'
        with mock.patch.dict('os.environ', {'MIGRATION_FACTORY_DEV_DATABASE_URL': uri}), \
                mock.patch.object(self.module.shutil, 'which', return_value='uvx'), \
                mock.patch.object(self.module.subprocess, 'run') as run:
            run.return_value.returncode = 7
            self.assertEqual(self.module.main(), 7)
        args, kwargs = run.call_args
        self.assertNotIn(uri, args[0])
        self.assertIn('--access-mode=restricted', args[0])
        self.assertEqual(kwargs['env']['DATABASE_URI'], uri)
        self.assertIn('postgres-mcp==0.3.0', args[0])

    def test_bad_uri_is_not_printed_or_sent_to_subprocess(self):
        with mock.patch.dict('os.environ', {'MIGRATION_FACTORY_DEV_DATABASE_URL': 'postgresql://postgres:secret@db/app'}), \
                mock.patch('sys.stderr') as stderr, \
                mock.patch.object(self.module.subprocess, 'run') as run:
            self.assertEqual(self.module.main(), 2)
            self.assertNotIn('secret', str(stderr.write.call_args_list))
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
