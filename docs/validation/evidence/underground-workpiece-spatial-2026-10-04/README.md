# 1135 spatial component evidence

The final seven production files and three owned tests are frozen in
[source-review-2/source-sha256.json](source-review-2/source-sha256.json).
Root independently accepted these exact ten pins and reproduced the helper
census; see [independent-review.json](source-review-2/independent-review.json).
The current tests use immutable, explicitly
diagnostic 1134 Workpieces/ConnectorWork/Contacts snapshots, not an accepted
production handling source or a complete gameplay qualification.

The final selected checks total **404 tests / 29732 assertions / 0 failures**.
Every selected strict/raw diagnostic and leak footer is zero. The analyzer reports
zero warnings in ten owned files. Source, project, registry and all diagnostic
overlays were restored, as recorded in each invocation and overlay manifest.

| Suite | Tests | Assertions | Packet |
|---|---:|---:|---|
| `test_underground_workpiece_spatial.gd` | 6 | 38 | `spatial-final-1` |
| `test_underground_space_owner.gd` | 113 | 5461 | `spatial-final-1` |
| `test_underground_routes.gd` | 69 | 11132 | `spatial-final-1` |
| `test_underground_world_routes.gd` | 39 | 2437 | `spatial-final-1` |
| `test_underground_connector_placements.gd` | 29 | 4004 | `spatial-final-1` |
| `test_underground_entry_bindings.gd` | 41 | 3245 | `spatial-final-1` |
| `test_underground_locations.gd` | 57 | 1731 | `spatial-final-1` |
| `test_underground_prepared_location_observation.gd` | 13 | 416 | `spatial-final-1` |
| `test_underground_final_facts.gd` | 31 | 1175 | `spatial-final-2` |
| `test_underground_workpiece_spatial_lifecycle.gd` | 6 | 93 | `spatial-adversarial-3` |

## Adversarial coverage

`late-room-probe-1` retains the reproduced HIGH: a successful public Room
copy moved the actual worker into the prepared workpiece after final occupancy;
the old path still paid and published. Its exact rejected test and source pins
are preserved. `late-room-corrected-1` retains a test-only wrong-owner `_tool`
access; corrected later packets do not waive that failed invocation.

The final paid tests prove no public Room observer after final occupancy, normal
source-copy/move refusal with unchanged Inventory/geometry and successful retry,
actual paused refund after worker release, unchanged strict turn authorization,
changed held-tool refusal, protected public/static prepayment Space publication,
and original-token rejection while preserving an unrelated same-size cold lease.
Current complete body/recovery, full refs, payload/source freshness, finite-work
refusal and output preservation have separate bounded real-owner tests.

## Source and memory

`census.py` counts the actual field/control and synchronous numeric-frame paths.
Its frozen result is [helper-census.json](source-review-2/helper-census.json).
The envelope is 1,895 / 2,048 logical bytes, including the 32-byte context/owner
delta and a 576-byte helper allowance reassigned inside existing headroom.
Largest recorded concurrent chain: 572 bytes. No packed bank, capacity or reserve
increases. Cold peaks remain 626,688 / 545,152 / 380,928 bytes under the original
1,048,960-byte shared lease. Native/reference/interpreter overhead is unmeasured.

Reproduce the census from the immutable diagnostic source used by the tests:

```sh
python3 docs/validation/evidence/underground-workpiece-spatial-2026-10-04/census.py \
  --workpieces-source docs/validation/evidence/underground-workpiece-spatial-2026-10-04/diagnostic-workpieces-source-2.gd.txt
```

`run_lifecycle_probe.py` verifies the selected source manifest, installs only
hash-checked diagnostic snapshots, invokes the clean/import/strict/LSP wrapper
with the isolated `Redwall-ug-workpiece-spatial` user directory, and restores every
overlay even on refusal. Exact commands and dependency hashes are in the packets.
The ordinary route benchmark remains a failed performance qualification; these
correctness runs do not claim the 256-resident frame-time or target-hardware gate.

## Preservation and acceptance limits

The two large rejected-witness logs are stored losslessly as `.log.gz`.
[compressed-logs.json](compressed-logs.json) records their original paths, byte
counts and SHA256 values plus compressed hashes. Historical invocation paths
refer to the original uncompressed names; decompression recreates those exact
bytes. No failed evidence was removed.

The independent source acceptance uses diagnostic Workpieces source2, exactly
as recorded by the tests and census. Construction's subsequent distinct-program
source leaf is outside those snapshots and needs paired final census/integration
review. This packet includes no shared registry or integration queue changes.
