import pathlib
import subprocess
import sys
import unittest

RUNNER = pathlib.Path(__file__).with_name('run_godot.py')


class GodotGateTests(unittest.TestCase):
    def run_command(self, code):
        return subprocess.run([sys.executable, str(RUNNER), sys.executable, '-c', code],
                              capture_output=True, text=True)

    def test_clean_success(self):
        self.assertEqual(self.run_command("print('checks: 100, failures: 0')").returncode, 0)

    def test_nonzero_exit_fails(self):
        self.assertNotEqual(self.run_command('raise SystemExit(7)').returncode, 0)

    def test_script_error_on_zero_exit_fails(self):
        result = self.run_command("print('SCRIPT ERROR: Parse Error: unexpected token')")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SCRIPT ERROR:', result.stdout)

    def test_stderr_error_on_zero_exit_fails(self):
        self.assertNotEqual(self.run_command("import sys; print('ERROR: Failed loading resource', file=sys.stderr)").returncode, 0)


if __name__ == '__main__':
    unittest.main()
