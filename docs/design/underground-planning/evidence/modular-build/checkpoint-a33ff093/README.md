# Full integrated checkpoint at a33ff093

Runtime/source HEAD: `a33ff0931b4971f4938f2d957db5962715a1777c`.
Only the owned integration checkout was tested. The exact CI procedure moved
its demo assets aside if present, deleted its .godot cache, ran the headless
editor import, ran `./tools/run_tests.sh` without arguments, and ran the
zero-warning analyzer. Assets were absent and their original state was restored;
HEAD and all recorded runtime/test/tool source hashes stayed unchanged.

```text
10405 test(s), 958819 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 10405 tests, 958819 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1157 file(s)
```

Import took10.625 seconds; the full suite1297.328 seconds; analyzer233.648 seconds.
See `invocation.json`, `source-sha256.json` and raw logs for the actual evidence.
Reproducer: the existing `checkpoint-499bfd73/reproduce.py`, invoked from this
checkout root with this fresh output directory. Documentation/generated
provenance updates were staged before the run; this is an exact runtime-source
checkpoint, not a claim that those metadata files were already committed in HEAD.

Included increments: reviewed connector Funding final settlement boundary,
prepared traversal/Site snapshots, exact committed WORK selection and source-local
upper-wall motion proof. The new1107 EntryPlan claim adapter was developed and
tested separately during this run and is excluded. This green component suite
does not certify a playable first entrance, full room workflow, save/replay,
native720p end-to-end input/visuals or256-resident qualification.
