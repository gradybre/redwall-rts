# Directory batch increment A evidence

Decision1086, own branch `codex/underground-identity-batches`.
`source-sha256.json` pins the exact production source and 21-test suite accepted
by independent parent review. All pins were rechecked before copying evidence.
No full-game or actual furniture-layout integration pass is claimed.

## Final commands and results

Demo assets were absent in the isolated worktree. Its Godot import cache was
deleted, then `godot --headless --path godot --editor --quit` completed with zero
error/warning lines (`clean-import.log`). The three manifests select singleton
suites through the existing CI shard planner and unchanged strict runner:

- Batch: 21 tests / 7971 assertions / 0 failures.
- Single candidate: 11 tests / 358 assertions / 0 failures.
- Existing Directory: 61 tests / 638 assertions / 0 failures.
- Total: 93 tests / 8967 assertions / 0 failures.

Every strict diagnostics/footer and independent raw-log footer reports zero
unexpected errors, warnings, leaked objects and leaked resources; expected and
tolerated diagnostics are also zero. Logs and per-shard result JSONs are retained.

`python3 tools/gdscript_warnings.py godot/scripts/core/entity_directory.gd godot/test/test_entity_directory_batch.gd --max 0 --port 6156 --json <output>`
reports `0 GDScript warning(s) in 0 of 2 file(s)` for these unchanged pins.

## Review and measurement limits

Parent independently read the exact source/tests and accepted heap-frontier
ordering/bounds, all-tuple preflight, lifetime/capacity guards, raw-byte refusal
and the 24K+76 packed +16 logical numeric control envelope. It did not rerun
these engine checks. The mutable packet requires separate consuming-owner pins
and actual cold admission; no geometry, billing or service authority is granted.

Final local K2048 sample: peek5998us, validation6134us, commit14050us including
its final validation. Packet49228 packed bytes. No timing threshold is asserted;
this is cold-component debug evidence, not target hardware or whole-layout UI
qualification. The history retains the initial18-test pass and the expanded
21-test pass (6122/6044/14228us), both with zero diagnostic/leak footers.
