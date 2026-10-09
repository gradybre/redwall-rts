# Paid multilevel output evidence — decision1079

Own worktree: `redwall-rts-codex-ug-orders`, branch
`codex/underground-orders`, parent `61c3e12a`. The root integration owner
independently reviewed the five pinned sources and tests with no remaining
high/medium correctness blocker. All pins stayed unchanged through the final
checks. This is focused accounting/endpoint evidence, not a full-suite,
actual-world support, active hauling, save/load or hardware qualification.

The final clean setup checked `godot/demo/assets` (absent), deleted this own
worktree's `godot/.godot`, and ran:

```sh
godot --headless --path godot --editor --quit
```

The import exited0 and produced zero error/warning lines. Six singleton shards
used unchanged `./tools/run_tests.sh --shard i/N --output-dir /tmp/ug1079-final`.
The actual `tools/ci_test_shards.py` discovery and `make_plan(N)` selected each
target's i/N; no alternative runner or diagnostic allowance was introduced.
Each retained suite log includes its exact shard and strict discovery/coverage
checks. The selected suites ran once each.

| Suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| test_modular_spatial_outputs | 8 | 415 | 0 |
| test_excavation_physical | 43 | 23193 | 0 |
| test_modular_inventory | 11 | 268 | 0 |
| test_excavation_sites | 25 | 3804 | 0 |
| test_modular_projects | 19 | 1816 | 0 |
| test_inventory_spatial | 18 | 274 | 0 |
| Total | 124 | 29770 | 0 |

Every final suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The actual editor-language-server analyzer over the five files in
`source-sha256.json`, with `--max 0 --port 6156`, reports
`0 GDScript warning(s) in 0 of 5 file(s)`. Its complete output and JSON are
included. All functions in the three changed production files remain at most
30 nonblank/noncomment/docstring lines. `state_registry_coverage.py` reports
`PASS -- 104 modules, 490 rows, 833 packed columns checked`; no new persistent
or component scratch fields require a new declaration. Global capacity and
memory reconciliation remains the root1072 packet.

The eight new modular tests run plain actual Work, the actual shared Router,
Construction, Funding, Inventory, Reservations, Gear and resident owners.
Only location/support and physical source permission are labeled fixtures.
The five new physical tests additionally run actual paid1m³ cuts and their
conservation owner. They cover surface-alias refusal, stacked endpoints,
first-pile promotion, already-published piles, old revision refusal before
productivity, a support change after actual lot creation, byte-exact rollback
and retry, positive metadata-preserving refunds, no-material cancellation,
independent actual output reservations and unrelated source claims.

Cancellation may safely freeze/release workers or unconsumed claims before
an ensuing material refusal; it is retryable, not an all-owner transaction.
Byte-equality assertions cover the specific promised atomic material owners,
and full-owner equality is used for start/commit refusals where applicable.

The two initial failure logs are retained. They caught fixture setup omissions:
the required tool gate on a real Site Job, and accepted worker registration
before canceling an unstarted cut. Only fixture setup was fixed; no guard,
expectation or diagnostic was relaxed.

The physical suite also runs the existing synthetic-contact timing probes:
256 workers mean10488us/max10689us, generic Work baseline2411us. This own
branch predates the root's separately reviewed Gear reverse index. Those are
diagnostics, not a target-hardware or complete simulation tick budget pass.
