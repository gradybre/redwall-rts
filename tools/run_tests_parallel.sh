#!/usr/bin/env bash
# The recommended local full-suite gate (decision 1895): run the complete Godot suite the way CI does, as CI's
# shards, several at once, then CI's own merged verify.
#
#     ./tools/run_tests_parallel.sh                          # CI's shard count, 4 shards at a time
#     ./tools/run_tests_parallel.sh --jobs 5                 # 5 at a time on an otherwise idle machine
#     ./tools/run_tests_parallel.sh --shards 12 --jobs 4 --output-dir /tmp/shards
#
# Every shard is `./tools/run_tests.sh --shard N/COUNT --output-dir DIR`, unchanged: its own private HOME and
# user:// (ADR 1204), the same zero allowances, its own report. When all have finished this prints each shard's
# result lines, then `python3 tools/ci_test_shards.py verify` over the reports, which proves every suite ran exactly
# once, cleanly, across the shards. It exits 0 only when every shard passed AND verify passed.
#
# --shards defaults to the count CI's verify step uses (.github/workflows/tests.yml), so the plan is CI's plan.
# --jobs defaults to 4: about 4 x 1.3 GB of memory and 4 busy cores, safe beside other work on this Mac. With 10
# shards, 4 jobs run in three waves and 5 in two; use 5 when nothing else is running. Live suites are timing
# sensitive: keep the load average below about 35 (docs/handoff/README.md section 3.4).
# --output-dir must be empty or absent; by default a new temporary directory, which is kept and printed so the
# shard logs (shard-N.log, runner-N.out) can be read afterwards.
#
# Import first, as CI does: godot --headless --path godot --editor --quit. As with run_tests.sh, an exit status
# of 0 is not evidence on its own: quote the summary lines this prints.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
self="$repo_root/tools/run_tests_parallel.sh"
workflow="$repo_root/.github/workflows/tests.yml"
readonly DEFAULT_JOBS=4

usage() {
    echo "usage: $0 [--shards COUNT] [--jobs JOBS] [--output-dir DIR]" >&2
    exit 2
}

# One shard, run by xargs (macOS xargs refuses long -I replacement commands, so the shard index is appended to a
# short fixed command instead). Records the shard's exit status beside its report.
if [[ "${1:-}" == --one-shard ]]; then
    [[ "$#" -eq 4 ]] || usage
    count="$2"; reports="$3"; index="$4"
    cd "$repo_root" || exit 2
    ./tools/run_tests.sh --shard "$index/$count" --output-dir "$reports" > "$reports/runner-$index.out" 2>&1
    status="$?"
    echo "$status" > "$reports/status-$index"
    echo "shard $index/$count exit $status at $(date +%H:%M:%S)"
    exit 0
fi

ci_shard_count() {
    sed -nE 's/.*ci_test_shards\.py verify --reports [^ ]+ --count ([0-9]+).*/\1/p' "$workflow" | head -n 1
}

count=""
jobs="$DEFAULT_JOBS"
reports=""
while [[ "$#" -gt 0 ]]; do
    [[ "$#" -ge 2 && -n "$2" ]] || usage
    case "$1" in
        --shards) count="$2" ;;
        --jobs) jobs="$2" ;;
        --output-dir) reports="$2" ;;
        *) usage ;;
    esac
    shift 2
done
if [[ -z "$count" ]]; then
    count="$(ci_shard_count)"
    if [[ -z "$count" ]]; then
        echo "error: could not read CI's shard count from $workflow; pass --shards." >&2
        exit 2
    fi
fi
if ! [[ "$count" =~ ^[1-9][0-9]*$ && "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: --shards and --jobs must be positive integers (got '$count' and '$jobs')." >&2
    exit 2
fi
if [[ -z "$reports" ]]; then
    reports="$(mktemp -d "${TMPDIR:-/tmp}/redwall-shards.XXXXXX")" || exit 2
elif [[ -e "$reports" && -n "$(ls -A "$reports" 2>/dev/null)" ]]; then
    echo "error: $reports is not empty; stale reports would be verified. Use a new directory." >&2
    exit 2
fi
mkdir -p "$reports" || exit 2
reports="$(cd "$reports" && pwd)"
if [[ ! -d "$repo_root/godot/.godot" ]]; then
    echo "error: the project is not imported; run: godot --headless --path godot --editor --quit" >&2
    exit 2
fi

echo "run_tests_parallel: $count shards, $jobs at a time, reports in $reports"
echo "load before: $(uptime | sed -E 's/.*load averages?: //')"
started="$SECONDS"
seq 0 $((count - 1)) | xargs -P "$jobs" -n 1 "$self" --one-shard "$count" "$reports"
wall="$((SECONDS - started))"

failed=0
for index in $(seq 0 $((count - 1))); do
    status="$(cat "$reports/status-$index" 2>/dev/null || echo missing)"
    echo ""
    echo "--- shard $index/$count: exit $status"
    grep -E '^[0-9]+ test\(s\), |^diagnostics: |^log: |^ok: |^error: ' "$reports/runner-$index.out" 2>/dev/null
    [[ "$status" == 0 ]] || failed=1
done

echo ""
echo "--- verify (as CI's 'Godot headless suite' job runs it)"
python3 "$repo_root/tools/ci_test_shards.py" verify --reports "$reports" --count "$count" \
    --output "$reports/verified.json"
verify_status="$?"
echo "wall seconds: $wall; load after: $(uptime | sed -E 's/.*load averages?: //')"
if [[ "$verify_status" -ne 0 || "$failed" -ne 0 ]]; then
    echo "error: the parallel run did not pass (verify exit $verify_status; a shard failed: $failed)." >&2
    echo "       Shard logs: $reports" >&2
    exit 1
fi
echo "ok: every shard passed and verify passed. Reports: $reports"
