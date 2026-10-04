# 1140 actual spatial connector delivery — review packet

Status: candidate source is frozen for independent root review. This is a tested
component, not playable entrance/Kitchen acceptance or production motion-source
qualification.

## Current candidate

`candidate-11/source-sha256.json` pins the three production and three test files.
`final-source-sha256.json` additionally pins the two new UIDs. No shared physical,
Inventory, Reservations, profile-source or registry file is part of this source
packet. The accepted 1141 prerequisite is source commit
`064f0c0d1b5e71059215b23755a249ea3a066c65`, consumed here as `f1602e0f` after
restoring all earlier diagnostic overlays.

| Exact candidate-11 suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Connector Delivery | 13 | 4,370 | 0 |
| HaulPlanner | 34 | 185 | 0 |
| Work | 77 | 9,283 | 0 |
| Total | **124** | **13,838** | **0** |

All three strict and raw-log unexpected error/warning and object/resource leak
counts are zero. The clean import passed and the analyzer reports zero warnings
in all six files. The invocation records unchanged source and complete original
project/assets/registry restoration. Tests use isolated userdata
`Redwall-ug-connector-delivery` and analyzer port 6165. The temporarily appended
registry text and its digest are retained per run; it is not a shared registry
change or memory-gate relaxation.

The actual positive test completes four L0 cubes through the real phase owners,
then performs two independent capacity-limited 2,400/1,600 milli wood shipments.
Each uses actual source arrival, 2,000 milli-WU loading, guarded satchel transfer,
CARRY travel, destination arrival and 2,000 milli-WU HAUL_OUTPUT unloading. The
first arrival leaves only 3,900 milli locally, and the unchanged 4,000 bill
refuses installation without payment. The second produces 5,500 actual stock;
the original BUILD Job pays exactly 4,000 and publishes one actual raised,
non-supporting workpiece, leaving 1,500. No route or accepted claim represents
goods movement by itself. The retained candidate-10 first positive has 9 tests /
3,843 assertions / 0 failures, all strict/raw/leak counts zero and analyzer 0/6.

Cancellation preserves carried goods. A new full Job can admit and REPOST part
of the same actual satchel without a second loading phase, travel to the exact
store and unload part while preserving the remaining live satchel. Real
Inventory observers test admission/loading/unloading refusal and exact retry
without extra WU/XP. A bound Clock test rejects expiry equal to the current tick
inside the pre-increment callback, even before the ordinary claim sweep.

## Rejected evidence and corrections

- `late-terrain-rejected`: a real Terrain helper armed only during Inventory
  attestation moved the worker after the initial pose proof; the original LOAD
  committed. This 3-test/878-assertion run has one failure and zero diagnostics or
  leaks. Final Terrain/Location reads are now direct packed-store leaves;
  concrete reused implementations are pinned. Ordinary observation seams remain
  available before the last proof. Its two very large packed-state failure logs
  are losslessly gzip-compressed; `lossless-log-archive.json` records original
  byte counts and SHA-256 values, plus compressed hashes.
- `live-claim-rejected`: real claim release inside an ordinary Terrain observer
  still earned Work/XP under the old source (10/4,086/1, all diagnostics/leaks
  zero). The new direct leaf rechecks the original current claim, Planner
  receipt, live reserved goods and expiry before crediting Work.
- `return-factor-rejected-2`: four exact failed cases (13/4,663/4, all diagnostics
  and leaks zero). Actual Pool and Planner wrappers called their real super
  operations, then reassigned the worker; Delivery accepted the late result and
  the Pool case published HAUL_OUTPUT to the old queued Job. Cold/final/cleanup
  composition now pins exact Pool and Planner scripts. The fourth witness is a
  harmless public factor read for another registered resident: it changed the
  original prepared remainder from 0 to -32,000. Work now publishes its factor
  from existing party scratch cell 14. The same run retains the live-claim
  failure. `return-factor-rejected` preserves the first version, whose Pool
  witness also contained a redundant turn/begin call; rejected-2 removes those
  incidental setup assertions without altering the adversarial source.

Full rejected sources are retained beside these runs. Their manifests are
verified by `rejected-source-validation.json`. Earlier diagnostic/candidate
folders preserve parse/setup failures and every intermediate passing result;
they do not supersede candidate-11.

## Source-derived declarations

Run `python3 docs/validation/evidence/underground-connector-delivery-2026-10-04/census.py`
to reproduce `census.json`. Delivery retains 753 logical numeric/packed bytes;
Work adds one boolean plus a fixed Script and weak actual Delivery binding. The
longest conservative coupled numeric chain is 817 bytes within the reserved
1,024 helper bytes, including the existing foreign-reader 512 allowance and
Work's live numeric stack. With the 2,048 provisional native allowance, the
packet accounts for 3,826 bytes within its explicit new 4,096-byte reservation.
No per-Job quantity/destination/claim/receipt bank exists. The borrowed 216-byte
Transfer and lower 115-byte callback prefix are counted once in the separate
1141 reservation, not again here. There is no measured native-memory or tick-time
claim; root owns joint memory/registry reconciliation.

## Reproduction and remaining activation gates

From this worktree, invoke `reproduce.py --out <new-directory>` with repeated
`--suite test_underground_connector_delivery.gd`, `--suite test_haul_planner.gd`
and `--suite test_work.gd`. The runner uses fresh assets/cache/import and official
strict singleton shards, then the six-file analyzer and restoration checks.

Every additional HAUL/handling/CARRY profile in these tests is explicitly
synthetic. Source-qualified no-tool handling and loaded motion remain required
for production activation, as does the integration caller that drives actual
Job admission, movement, Work and transfer commands. This packet replaces the
1134 test-only second-WORK hauling bridge for the exercised real-owner path; it
does not grant production motion flags, invent a stair route, or complete the
playable entrance/Kitchen milestone.
