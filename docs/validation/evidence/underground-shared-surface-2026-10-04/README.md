# Shared natural surface sections

Decision1115 adds actual SurfaceAnchor creation over one shared metadata-only
World floor with independently proved air and footing at each work spot. Dirt
between the spots receives no support or clearance. Existing default calls keep
their behavior. This is a first-prefix construction prerequisite, not a playable
room/entrance or qualified source motion.

Reproduce from the selected checkout with:

```sh
python3 docs/validation/evidence/underground-shared-surface-2026-10-04/reproduce.py --out <fresh-directory>
python3 tools/test_underground_memory_budget.py
```

Candidate1 used the exact clean-assets/cache/editor-import procedure and four
official strict singleton shards, with an isolated Godot user directory. All
127 tests /4071 assertions passed. The individual runner lines are preserved:

```text
31 test(s), 329 assertion(s), 0 failure(s)
55 test(s), 1654 assertion(s), 0 failure(s)
26 test(s), 1711 assertion(s), 0 failure(s)
15 test(s), 377 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Every suite had that same clean diagnostic/leak footer. Source hashes were
unchanged, original project bytes restored, and assets absent/restored. The
94 Python memory tests pass; registry coverage reports138 modules/693 rows/
1032 packed columns. Exact independent Construction review is in review.json;
no high/medium finding. It notes one nonblocking old docstring saying three rows.
The added25 logical bytes fit the same2048 reservation; native memory is not
qualified. Integrated full verification predates this candidate and is tracked
separately, with no claim that these focused tests close that gate.
