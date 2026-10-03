# Integrated checkpoint bb557d1b

Exact tested source: `bb557d1b6bc3a97fe8bd566dbc114a8dbf0965fc`.
The own integration worktree was frozen throughout the run. Assets were moved
aside when present, `.godot` deleted, the headless editor imported cleanly,
and the complete no-argument `./tools/run_tests.sh` ran. The supervisor restored
assets in its `finally` block. Elapsed test/import time: 1191.7 seconds.

```text
9304 test(s), 620633 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1048 file(s)
```

The analyzer used a separate editor on port6148. These results cover the exact
source above, including UG18 and the ReservationPurpose and canonical-declaration
fixes. They do not cover later UG08 geometry, UG06 WIP, UG19 world drawing or
the memory-ledger documentation/validator fix. They do not establish a playable
underground lifecycle, production movement qualification or save composition.
The previous failed checkpoint remains preserved without relabeling.
