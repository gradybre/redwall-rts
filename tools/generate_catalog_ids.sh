#!/usr/bin/env bash
# Generate (or --check) godot/data/catalog_ids.json and fail unless it demonstrably ran.
#
# WHY THIS SCRIPT EXISTS INSTEAD OF A BARE `godot ... --script` LINE: `godot` invoked without a
# correct `--path` finds no project.godot, silently opens the project manager, imports nothing,
# and EXITS 0 (docs/ENVIRONMENT.md, where it is recorded as having already caused one wrong
# conclusion). An exit status of 0 is therefore NOT evidence that the generator ran. This
# asserts on the generator's own marker line instead.
#
#   ./tools/generate_catalog_ids.sh            # write the artifact
#   ./tools/generate_catalog_ids.sh --check    # verify it, write nothing (CI)
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v godot >/dev/null 2>&1; then
    echo "error: godot is not on PATH (see docs/ENVIRONMENT.md)" >&2
    exit 127
fi

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

godot --headless --path godot --script "$repo_root/tools/generate_catalog_ids.gd" \
    -- "$@" 2>&1 | tee "$output_file"
godot_status="${PIPESTATUS[0]}"

marker="$(grep -E '^##CATALOG_IDS## action=[a-z]+ bytes=[0-9]+ sha256=[0-9a-f]{64} domains=[0-9]+ rows=[0-9]+ path=' \
    "$output_file" | tail -n 1)"

if [[ -z "$marker" ]]; then
    echo "error: the generator printed no result line -- it did not run to completion." >&2
    echo "       godot exited ${godot_status}, which on its own proves nothing." >&2
    exit 1
fi

if [[ "$godot_status" -ne 0 ]]; then
    echo "error: the generator reported a result but godot exited ${godot_status}." >&2
    exit "$godot_status"
fi

echo "ok: ${marker#\#\#CATALOG_IDS\#\# }"
