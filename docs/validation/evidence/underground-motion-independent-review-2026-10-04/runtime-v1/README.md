# Independent ADR1143 runtime review — candidate 4

Review scope: the eight frozen source/UID/tool pins in `source-sha256.json`, at
the candidate worktree's base `4e0d2811bec3d19f864edae8edf3e1d7d284a135`.
All eight pins matched before and after the independent checks. Source snapshots
are retained as `.txt`; no candidate project, source, cache or engine state was
modified. This directory is the reviewer's only write destination.

## Finding requiring correction

**MEDIUM — the loader understates simultaneous decode payload by 4,096 bytes.**
At frozen `underground_motion_catalog.gd` lines 237–249, the previous loop-local
`bytes` remains alive while the next `_read` creates its replacement. The first
column has consecutive full 4,096-byte reads, so two such allocations coexist.
The promised single-window peak and `configure(..., 232436)` admission therefore
do not cover the complete loading lifetime: the candidate needs at least
236,532 bytes with this implementation. The overall 262,144 ceiling is not the
issue; the exact admitted amount and declared decode lifetime are incorrect.

This follows directly from the pinned installed-engine source, without an
additional engine run. The compiler evaluates a variable initializer before
assigning its result, and clears loop locals after the loop rather than before
each iteration. See [the exact GDScript compiler](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/modules/gdscript/gdscript_compiler.cpp#L2120),
including the variable-initializer branch at line 2213. Each
[`FileAccess.get_buffer` call](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/io/file_access.cpp#L548)
constructs and sizes a fresh vector. Complete source bytes and hashes are
retained in `engine-source.json` and the `.cpp.txt` files.

Requested correction: release all references to the consumed payload before
another read, or account for both allocations. The exact bytecode generator's
`clear_temporaries` only clears object-capable temporaries, so reassigning one
local alone must not assume every packed return temporary also died. Geometry
accepted the finding and selected a per-chunk helper returning only StringName;
its complete frame ends before the next read. A source/census lifetime regression
will enforce that boundary. Candidate 4 remains historical; acceptance awaits
the narrowly corrected frozen packet.

**LOW — reproducer raw-import diagnostic guard.** `reproduce.py` checks the
clean-import process exit code but does not independently reject its raw error,
warning or leak lines. Godot can exit zero while emitting a diagnostic. The
actual candidate-4 import log is clean, so this does not invalidate the saved
run. Future reproductions should apply the existing strict raw diagnostic
check before reporting success.

## Completed independent checks

- Read the complete reader, GDScript tests, packer/tests, census and reproducer;
  checked the relevant concrete Profile, Level, Catalog and Directory binding
  contracts.
- Ran all 11 Python packer tests successfully using `-B`, with temporary files
  confined to this directory.
- Rebuilt the actual 70,936-byte wire and source manifest into a fresh owned
  output directory. Both are byte-identical to candidate 2. Recomputed census
  JSON is also byte-identical; the finding above concerns a lifetime omitted by
  that census, not an arithmetic reproduction failure.
- Read retained four-suite evidence: 58 tests / 14,678 assertions / 0 failures,
  all strict/raw diagnostic and leak counts zero, changed-file analyzer 0/2.
  No engine run was duplicated.
- Found no further blocking defect in fixed-size decoding, exact source hash,
  inactive-bank publication/refusal, source-once loading, actual owner drift,
  World generation/PID checks, output isolation, all 630 interval mappings,
  stationary phases, signed local ceil before orientation, terminal source
  frames or unconditional activation refusal.

`independent-results.json` records the exact test, packer and census commands.
`pin-check-before.json` records the frozen source identity. The correction does
not authorize a rate or runtime route. ADR1145's separate Natural timing choice
does not alter this source-only reader's zero rate fields. Renderer, actual paid
support/Placement/Profile binding, shared World admission and native memory
qualification remain outside this review.
