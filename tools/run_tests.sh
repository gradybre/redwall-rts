#!/usr/bin/env bash
# Run the headless Godot suite and fail unless it demonstrably ran.
#
# WHY THIS SCRIPT EXISTS INSTEAD OF A BARE `godot ... --script` LINE:
# `godot` invoked without a correct `--path` finds no project.godot, silently
# opens the project manager, imports nothing, and EXITS 0 -- documented in
# docs/ENVIRONMENT.md, where it is recorded as having already caused one wrong
# conclusion. An exit status of 0 is therefore NOT evidence that any test ran.
#
# So this asserts on the runner's own summary line: it must be present, it must
# report zero failures, and it must report a non-zero test count. A run that
# executes nothing fails here rather than reporting success.
#
# Usable locally as well as in CI: ./tools/run_tests.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v godot >/dev/null 2>&1; then
    echo "error: godot is not on PATH (see docs/ENVIRONMENT.md)" >&2
    exit 127
fi

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

godot --headless --path godot --script test/run_tests.gd 2>&1 | tee "$output_file"
godot_status="${PIPESTATUS[0]}"

summary="$(grep -E '^[0-9]+ test\(s\), [0-9]+ assertion\(s\), [0-9]+ failure\(s\)$' \
    "$output_file" | tail -n 1)"

if [[ -z "$summary" ]]; then
    echo "error: no test summary line was printed -- the suite did not run." >&2
    echo "       godot exited ${godot_status}, which on its own proves nothing." >&2
    exit 1
fi

read -r tests _ assertions _ failures _ <<<"$summary"

if [[ "$tests" -le 0 ]]; then
    echo "error: the runner reported ${tests} tests. Nothing was executed." >&2
    exit 1
fi

if [[ "$failures" -ne 0 ]]; then
    echo "error: ${failures} failing test(s)." >&2
    exit 1
fi

if [[ "$godot_status" -ne 0 ]]; then
    echo "error: the suite reported no failures but godot exited ${godot_status}." >&2
    exit "$godot_status"
fi

echo "ok: ${tests} tests, ${assertions} assertions, 0 failures."
