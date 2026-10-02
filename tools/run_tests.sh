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
# It also fails a run whose log is not clean (decision 0501): an `ERROR:` or `WARNING:` line that no test
# declared (the runner reprints declared ones as `EXPECTED ...` and outside-the-tree notices as `TOLERATED ...`,
# so they no longer start the line), or objects/resources the worker never freed. The allowances below are all
# zero; raising one needs a decision record that names what is allowed and why.
#
# Usable locally as well as in CI: ./tools/run_tests.sh
# Optional CI selection: ./tools/run_tests.sh --shard 0/8 --output-dir artifacts/test-shards
set -uo pipefail

readonly MAX_UNEXPECTED_ERRORS=0
readonly MAX_UNEXPECTED_WARNINGS=0
readonly MAX_LEAKED_OBJECTS=0
readonly MAX_LEAKED_RESOURCES=0

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v godot >/dev/null 2>&1; then
    echo "error: godot is not on PATH (see docs/ENVIRONMENT.md)" >&2
    exit 127
fi

# No arguments still use the original complete runner. Only explicit shard mode
# selects its subclass; both paths pass through every guard below unchanged.
godot_script="test/run_tests.gd"
shard_spec=""
shard_output_dir=""
if [[ "$#" -gt 0 ]]; then
    if [[ "$#" -ne 4 || "$1" != --shard || "$3" != --output-dir || -z "$4" ]]; then
        echo "usage: $0 [--shard INDEX/COUNT --output-dir DIR]" >&2
        exit 2
    fi
    shard_spec="$2"
    shard_output_dir="$4"
    REDWALL_TEST_SHARD_SUITES="$(python3 tools/ci_test_shards.py prepare \
        --shard "$shard_spec" --output-dir "$shard_output_dir")" || exit 1
    export REDWALL_TEST_SHARD_SUITES
    shard_index="$((10#${shard_spec%%/*}))"
    rm -f "$shard_output_dir/shard-$shard_index.json" "$shard_output_dir/shard-$shard_index.log"
    godot_script="$repo_root/tools/ci_test_shard_runner.gd"
fi

# Task 09.1: the future-affecting-state registry is enforced, not merely written.
# This fails when a store under godot/scripts/core has no row, a row names a column
# that no longer exists, or a declared width/count stops matching the GDScript.
# It runs first because a registry that no longer describes the code is a build
# failure whether or not the Godot suite is green.
python3 "$repo_root/docs/validation/state_registry_coverage.py" || exit 1

if [[ -n "$shard_spec" ]]; then
    output_file="$shard_output_dir/shard-$shard_index.log"
else
    output_file="$(mktemp)"
    trap 'rm -f "$output_file"' EXIT
fi

report_line() {
    echo "$@"
    if [[ -n "$shard_spec" ]]; then
        echo "$@" >> "$output_file"
    fi
}

shard_started_seconds="$SECONDS"
godot --headless --path godot --script "$godot_script" 2>&1 | tee "$output_file"
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

# Counted from the raw log rather than from the runner's own diagnostics line, so a supervisor that stopped
# classifying (or a leak report from the supervisor process itself) is still caught.
unexpected_errors="$(grep -cE '^(USER )?ERROR:' "$output_file")"
unexpected_warnings="$(grep -cE '^(USER )?WARNING:' "$output_file")"
leaked_objects="$(grep -oE '[0-9]+ ObjectDB instances were leaked' "$output_file" \
    | awk '{ total += $1 } END { print total + 0 }')"
leaked_resources="$(grep -oE '[0-9]+ resources still in use at exit' "$output_file" \
    | awk '{ total += $1 } END { print total + 0 }')"
report_line "log: ${unexpected_errors} unexpected error(s), ${unexpected_warnings} unexpected warning(s);" \
    "leaked at exit: ${leaked_objects} object(s), ${leaked_resources} resource(s)."

dirty=0
check_allowance() {
    if [[ "$2" -gt "$3" ]]; then
        echo "error: ${2} ${1} (allowed: ${3}). See docs/ENVIRONMENT.md, 'Reading the test log'." >&2
        dirty=1
    fi
}
check_allowance "unexpected ERROR line(s)" "$unexpected_errors" "$MAX_UNEXPECTED_ERRORS"
check_allowance "unexpected WARNING line(s)" "$unexpected_warnings" "$MAX_UNEXPECTED_WARNINGS"
check_allowance "leaked ObjectDB instance(s)" "$leaked_objects" "$MAX_LEAKED_OBJECTS"
check_allowance "leaked resource(s)" "$leaked_resources" "$MAX_LEAKED_RESOURCES"
if [[ "$dirty" -ne 0 ]]; then
    exit 1
fi

report_line "ok: ${tests} tests, ${assertions} assertions, 0 failures."
if [[ -n "$shard_spec" ]]; then
    python3 tools/ci_test_shards.py record --shard "$shard_spec" --output-dir "$shard_output_dir" \
        --wall-seconds "$((SECONDS - shard_started_seconds))" || exit 1
fi
