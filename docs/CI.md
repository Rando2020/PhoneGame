# CI coverage

The root `project.godot` is a different project from the Meldlings port in
`godot/`. Keep both: the `compile` job checks root with Godot **4.6.2**;
`port` checks `godot/` with **4.3**, as documented in PORT.md. This is not an
engine upgrade. The existing workflow filename and root check name are retained.

CI imports each project. It also checks every port GDScript explicitly because
import alone need not parse unattached scripts. Port parity, save, resume and
record tests then run with the committed fixtures. Diagnostic errors fail the
check even if Godot exits zero. The job timeout bounds stuck engine/tests.

The web job uses Node 24, rebuilds the bundle, and runs the existing UI, cascade,
round-end, history and save tests from `web/` (some harnesses use relative paths).
It generates parity fixtures twice to check reproducibility even if a web test
fails. Do not compare fixture bytes to the checked-in file across Node/V8
versions: tiny floating-point differences are accepted by the existing Godot
parity test's numeric tolerance. This reproducibility check is not a proof that
committed fixtures cover every current web behavior.

## Reproduce

From the repository root, with the documented engine binaries installed:

```sh
python3 -m unittest discover -s tools/ci -p 'test_*.py'
python3 tools/ci/run_godot.py /path/to/godot-4.6.2 --headless --path . --editor --import
python3 tools/ci/run_godot.py /path/to/godot-4.3 --headless --path godot --editor --import
# Bash: check all port scripts, excluding generated import cache.
while IFS= read -r -d '' script; do
  python3 tools/ci/run_godot.py /path/to/godot-4.3 --headless --path godot --check-only --script "res://${script#godot/}"
done < <(find godot -path godot/.godot -prune -o -type f -name '*.gd' -print0)
for test in parity_test save_test resume_test record_test; do
  python3 tools/ci/run_godot.py /path/to/godot-4.3 --headless --path godot --script "res://tests/${test}.gd"
done
python3 tools/build_web.py
(cd web; status=0; for test in runtest.js cascadecheck.js cribend_check.js record_check.js save_check.js; do node "$test" || status=1; done; exit "$status")
OUT=/tmp/phonegame-parity-first.json node tools/parity/gen_fixtures.js
OUT=/tmp/phonegame-parity-second.json node tools/parity/gen_fixtures.js
cmp /tmp/phonegame-parity-first.json /tmp/phonegame-parity-second.json
```

## Scope and security

Only official GitHub Actions are used, pinned to full commit SHAs (checkout
v4.3.1 and setup-node v4.4.0). No third-party setup-Godot Action is added.
Downloads come from the official Godot releases and are checked against the
same release's SHA-512 manifest before execution. This catches corruption but
is not an independent signature or protection against a compromised release.
The token has `contents: read`, checkout does not persist credentials, and PRs
use `pull_request`, not privileged `pull_request_target`. There is no publish,
merge, deployment, artifact upload, cache, or secret-reading step.

This focused CI is not the full release checklist, graphical/device QA, iOS
export validation, or a claim that all 40+ Godot suites pass. See
RELEASE_CHECKLIST.md and NEXT_SESSION.md for wider verification.
