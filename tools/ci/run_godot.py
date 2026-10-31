"""Fail on Godot diagnostics even when the engine returns exit status zero.

Usage: python3 tools/ci/run_godot.py GODOT [arguments...]
The workflow supplies a job timeout; this wrapper does not suppress any output.
"""
import re
import subprocess
import sys

result = subprocess.run(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print(result.stdout, end='')
errors = re.search(r'^\s*(?:SCRIPT ERROR|ERROR):', result.stdout, re.MULTILINE)
sys.exit(result.returncode or (1 if errors else 0))
