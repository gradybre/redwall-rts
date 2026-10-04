# UG05 — Native modular shell evidence

Recorded 2026-10-02. This is a fitted geometry/material study, not a playable
village capture or final-art approval. Decision
[1057](../../../../../decisions/1057-canonical-room-shells.md) defines the API
and integration boundaries. [provenance.json](provenance.json) pins source,
reference and image SHA-256 values and contains the benchmark reproducer.

## Captures inspected

All three images are unedited native Godot frames at **1280×720**, opened
and inspected individually. The parent independently reviewed the source
and gallery before commit.

- [Cutaway gallery](01-gallery-cutaway.png): rectangle, concave chamber,
  stepped rounded burrow, bent tunnel, changed heights, and adjacent
  FINISHED/CUT/SOLID regions. Planned solid cells remain outlined and uncut.
- [Ceilings and aperture](02-ceilings-and-aperture.png): ceiling coverage
  follows the same footprint; the kitchen specimen has one explicit
  cell-sized aperture. The ceiling is one two-sided plane, not two
  coplanar triangles duplicated for visibility.
- [Height join close-up](03-height-join-close.png): the raised floor has a
  real riser, and the lowered ceiling has the corresponding wall step.

The warm procedural earth, timber and stone are original shader work. No
paid generation, external texture asset or staged furniture was used.
DEC-038's approved world-art image and the book-qualified Brockhall records
listed in the provenance were inspected for material direction. The rounded
and tunnel specimens use explicit **synthetic** quarter-metre cells; that
choice does not adopt production paint resolution or map to paid 1 m³ cuts.

## Checks

Own-worktree preparation followed the CI workflow: `godot/demo/assets` was
absent, the own `godot/.godot` cache was deleted, and
`godot --headless --path godot --editor --quit` completed with no diagnostic
lines. The strict runner's exact one-suite shard was calculated using
`tools/ci_test_shards.py` (163/300 for this source state):

```text
./tools/run_tests.sh --shard 163/300 --output-dir /tmp/redwall-ug-shell-final
state_registry_coverage: PASS -- 93 modules, 438 rows, 747 packed columns checked
19 test(s), 298 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 19 tests, 298 assertions, 0 failures.
```

This is focused evidence, not an assertion that the full integration suite
ran in this lane. The parent owns the complete frozen-candidate suite.
Assertions cover exact area and retained holes, triangle winding, removed
internal walls, height interval differences, actual wall/floor/ceiling
openings, stage masks, UV anchoring, exact float presentation conversion,
explicit headroom/refusals, revision misuse and material/geometry isolation.

The analyzer used the four changed GDScript files (`modular_shell.gd`,
`modular_materials.gd`, `test_modular_shell.gd`, `modular_shell_live.gd`):

```text
python3 tools/gdscript_warnings.py <the four files above> --max 0
0 GDScript warning(s) in 0 of 4 file(s)
```

Native execution compiled the material shader on Godot 4.7.2,
Metal 4.0 Forward+, Apple M5 Pro (Apple9):

```text
godot --path godot --script res://test/live/modular_shell_live.gd -- --capture <absolute evidence directory>
SHELL-LIVE-SUMMARY 33 0
```

The native log was separately scanned: **0 error lines, 0 warning lines,
0 leak lines**. Its 33 checks verify builds, material assignment, cache
reuse, fixed viewport dimensions and saved captures; geometry correctness
is additionally tested by the strict suite, not inferred from exit status.

## Measured cold rebuild cost

Five headless debug samples per square footprint, all FINISHED, explicit
1024-unit pitch, 2048-unit ceiling and supplied 1024-unit minimum headroom.
Timing includes full validation and mesh creation; a subsequent call with
the same revision/spec measures cache access. The exact bounded GDScript
reproducer is preserved in `provenance.json` under `benchmark` and can be
written to a temporary file and run with
`godot --headless --path godot --script <temporary benchmark.gd>`.

| Cells | Cold median ms | Cold max ms | Cached median µs |
|---:|---:|---:|---:|
| 64 | 0.850 | 0.908 | 1 |
| 256 | 3.090 | 3.118 | 1 |
| 1,024 | 11.692 | 11.808 | 2 |
| 4,096 | 46.630 | 47.679 | 4 |
| 16,384 | 181.636 | 184.219 | 9 |

These are CPU microbenchmarks on this machine, not native frame-time or
256-resident qualification. A 16,384-cell helper guard is an engineering
allocation bound, not an adopted room-size limit. Large changed revisions
must be batched/budgeted or incrementally published by the integrating view;
revision caching alone does not remove the cold input stall.

## Remaining integration and visual work

The study proves fitted cell coverage and stable physical material scale.
It does not establish final immersive visual quality: stepped round walls,
curved vertical profiles, material close-ups and authored props remain
UG09/UG17 work. Stairs, shoring, structural roofs, cross-level support,
room defaults/compatibility, physical cut/finish pricing, construction jobs,
saves and services are owned by the integrating systems. There is no
Windows or actual-village/256-resident qualification here.

Returned ArrayMesh resources are borrowed cached presentation resources.
Callers may attach them and assign materials, but must not clear or change
the mesh surfaces; copying the result dictionary does not isolate a mesh
resource mutation. Metadata is copied and revision misuse fails visibly.
