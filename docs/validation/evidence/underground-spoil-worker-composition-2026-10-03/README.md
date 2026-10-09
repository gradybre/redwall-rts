# Actual paid spoil worker composition — 2026-10-03

Decision [1078](../../../decisions/1078-actual-paid-spoil-worker-composition.md)
connects the actual Tips ledger to the shared Construction, Inventory,
Reservations, Items, Jobs, Work, Gear and Sites Funding owners. These focused
checks establish the economic and worker composition. The contact fixture
explicitly supplies synthetic terrain, route and worker-contact permission.
It is not evidence of real-world siting, clearance, hauling or demo activation.

The accepted run is `corrected/`. Its `source-sha256.json` identifies the four
reviewed source and test files. The independently reviewed Router B3 source is
also present in this checkout; its own evidence is retained in the shared-router
bundle. The owning checkout was based on the integration branch and these
reviewed component commits, not on an uncommitted copy of another lane.

## Reproduction

From this checkout, run:

```sh
python3 docs/validation/evidence/underground-spoil-worker-composition-2026-10-03/reproduce.py NEW_OUTPUT_DIRECTORY
```

The script refuses an existing output directory, moves this checkout's demo
assets aside when present, deletes this checkout's `godot/.godot`, runs
`godot --headless --path godot --editor --quit`, then uses the unchanged strict
test wrapper with one discovered suite per shard. It runs the language-server
analyzer on port 6157 with `--max 0`, verifies that the source hashes did not
change during the run, and restores the assets in `finally`. The raw per-shard
manifests and logs remain alongside the wrapper logs.

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| `test_spoil_work.gd` | 10 | 874 | 0 |
| `test_spoil_tips.gd` | 19 | 806 | 0 |
| `test_modular_projects.gd` | 19 | 1,816 | 0 |
| `test_modular_inventory.gd` | 11 | 268 | 0 |
| `test_excavation_physical.gd` | 38 | 22,446 | 0 |
| Sum of these focused runs | 97 | 26,210 | 0 |

Each of the five strict wrapper logs ends with:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports:

```text
0 GDScript warning(s) in 0 of 4 file(s)
```

These totals are the sum of the five named runs, not a full no-argument suite.
No timing, native memory, save/load or production movement qualification is
claimed by this bundle.

## Retained rejected run

`initial/` is the first clean attempt. Six new composition tests failed because
their helper attempted delivery to an already READY no-input project and tried
to claim a bill from only the first lot after cancellation split the inventory.
The corrected helper uses actual phase and available-lot observations, skips
delivery when there are no inputs, and claims across the actual remaining lots.
It neither adds stock nor bypasses payment. The failed evidence and its exact
source pins remain unchanged.

## Independent source review

The furnishing agent independently reviewed the four accepted source hashes
and the actual payment, source, cancellation, retry and publication lifetimes.
No remaining high or medium blocker was identified. In particular, CLOSE
captures its exact physical identity before Tips retires the row, and the
terrain provider must stage every fallible operation before payment and publish
synchronously without failure. Actual world contact implementation remains a
separate dependency; the typed unbound provider refuses authorization.
