#!/usr/bin/env bash
# Regenerate the committed test checkpoints (decision 1240):
#     ./tools/regenerate_test_checkpoints.sh                 # every recipe
#     ./tools/regenerate_test_checkpoints.sh underground_entry
#
# Each recipe (godot/test/fixtures/checkpoint_recipes.gd) replays its settlement from tick 0 and
# writes godot/test/fixtures/checkpoints/<name>.json plus one <name>-<point>.rwlsave.gz per point.
# Commit them with the source change that made them stale. Like run_tests.sh, success is the
# generator's own report, not godot's exit status (docs/ENVIRONMENT.md), and user:// is private
# (ADR 1204).
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v godot >/dev/null 2>&1; then
    echo "error: godot is not on PATH (see docs/ENVIRONMENT.md)" >&2
    exit 127
fi

test_home="$(mktemp -d)"
output_file="$(mktemp)"
trap 'rm -f "$output_file"; rm -rf "$test_home"' EXIT

HOME="$test_home" XDG_DATA_HOME="$test_home/.local/share" \
    godot --headless --path godot --script test/generate_checkpoints.gd -- "$@" 2>&1 | tee "$output_file"
godot_status="${PIPESTATUS[0]}"

written="$(grep -c '^CHECKPOINT-OK ' "$output_file")"
failed="$(grep -c '^CHECKPOINT-FAIL ' "$output_file")"
if [[ "$written" -eq 0 || "$failed" -ne 0 || "$godot_status" -ne 0 ]]; then
    echo "error: ${written} checkpoint(s) written, ${failed} failed, godot exited ${godot_status}." >&2
    exit 1
fi
if grep -qE '^(USER )?(SCRIPT )?ERROR:' "$output_file"; then
    echo "error: the generator printed an engine error; the checkpoints are not trusted." >&2
    exit 1
fi
echo "ok: ${written} checkpoint(s) written to godot/test/fixtures/checkpoints/."
