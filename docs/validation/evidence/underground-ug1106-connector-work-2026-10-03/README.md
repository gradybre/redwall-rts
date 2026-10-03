# 1106 — shared funding prerequisite evidence

This packet verifies the connector payment boundary in actual Construction,
Inventory, Reservations, Funding, Jobs, Work and Gear. The purpose's contact
and installation permission in these tests is explicitly synthetic. No actual
Placement adapter, connector geometry, authored installation profile or playable
entry is qualified by this packet.

## Rejected evidence retained

`funding-iteration-1` passed 99 tests / 11,915 assertions, but independent root
review rejected its input ordering. The final owner guard preceded Inventory's
seed-expiry observer, which runs on reserved wood as well as seeds. The later
`rejected-seed-window` regression reproduced the bug: 26 tests / 2,210 assertions
/ 1 failed test, with zero unexpected diagnostics or leaks. The callback returned
false (allow consumption) while invalidating the separate connector contact;
the rejected implementation still paid and began work.

That run printed complete state images in a failed equality assertion. Both
complete logs are retained as lossless gzip files; `compressed-logs.json` records
their original byte counts and SHA256 digests. Subsequent tests use boolean
state-image equality so a real failure does not print megabytes of integers.
`funding-source-sha256.json` is the rejected five-file candidate's pin manifest.

## Corrected evidence

`funding-iteration-2` verifies the new settlement ordering and both reentry
windows: 84 tests / 3,040 assertions / 0 failures. `funding-iteration-3` adds the
refused second real Router and cleared refusal-window assertions: 146 tests /
12,498 assertions / 0 failures. Independent review accepted this source boundary
and requested the final claim-metadata protection described below.

`funding-iteration-4` is the final seven-suite candidate:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| ModularProjects | 29 | 2339 | 0 |
| ModularInventory | 12 | 292 | 0 |
| Reservations | 45 | 467 | 0 |
| ConstructionModular | 12 | 150 | 0 |
| ExcavationSites / Funding | 25 | 3804 | 0 |
| SpoilWork | 10 | 874 | 0 |
| UndergroundFurnitureWork | 15 | 4628 | 0 |
| **Total** | **148** | **12554** | **0** |

Each suite ended with both exact zero-diagnostic/leak summaries:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`funding-analyzer-2.log` reports the preceding corrected seven-file candidate:

```text
0 GDScript warning(s) in 0 of 7 file(s)
```

`funding-corrected-source-sha256.json` pins that candidate.
`funding-final-source-sha256.json` pins the final four production and three test
files, including the narrow claim metadata correction. No source changed during
the final focused run; `funding-analyzer-3.log` also reports
`0 GDScript warning(s) in 0 of 7 file(s)` for these unchanged final pins.

## Method and scope

`run_focused.py` discovers a complete CI shard manifest and selects singleton
shards without changing the test runner or gates. Each iteration moves this
worktree's demo assets aside if present, deletes its Godot cache, runs exactly
`godot --headless --path godot --editor --quit`, then invokes the unchanged
`./tools/run_tests.sh` for the selected shards, restoring assets afterward.
Full manifests, raw import logs, raw shard logs and machine summaries are kept.
This is focused component evidence, not a full-suite or remote-CI claim.

The real late Inventory callback must leave Inventory, claims, WIP, Construction,
Job/worker, XP and tool bytes unchanged on refusal; the same operation then
retries successfully. A Recipe observer with the actual WIP permit cannot enter
Reservations early or recursively consume through Funding. Null/base guards,
foreign Inventory/pool/Router and stale Project/Job refs refuse. Actual ordinary
furniture/tip/refund regressions remain strict. Refund loss is staged before
commit and no bill observer runs after returned goods commit.

The final protection also refuses `renew_claim` and `repurpose_claim` while the
pool's actual bound Inventory has an open transaction. A late observer cannot
leave changed expiry or purpose behind after a debit rollback. A different
Inventory's transaction does not block them. The actual regression compares the
complete paid and claim images after refusal, then successfully retries.

The registry checker rejected an appended module heading, which attributed the
reused vector to another module; changing it into a duplicate standard heading
also correctly failed coverage. The final declaration updates the existing
Funding section instead and counts `_s_totals` only once. The retained
`rejected-registry-heading.log` records that intermediate failure. Corrected
coverage reports `PASS -- 131 modules, 657 rows, 998 packed columns checked`.

Independent root review accepted the settlement ordering, then the final narrow
metadata guards, both regressions and corrected registry. The reviewer did not
author this source. All seven final pins still matched after the analyzer. The
initial HIGH finding and its rejected reproduction remain part of this packet.
