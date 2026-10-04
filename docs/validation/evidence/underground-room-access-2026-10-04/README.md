# ADR1154 room access selection — frozen component review

Worktree `redwall-rts-codex-ug-room-access-ui`, branch
`codex/underground-room-access-ui`, diff base
`b5c63281264bd4d4273dc84fc0a3e94ec5ca24f9`. This includes accepted 1150,
the EntryBindings inherited-constant fix, and the accepted 1153 Locations
iterator. No producer overlays remain. Sources are frozen under
`review-v2/source-sha256.json`; independent review is pending.

## Concrete behavior and scope

The host calls `Runtime.configure_access(actual_world_routes, full_anchor)`.
The editor searches actual live Locations and authored BUILD WORK descriptors,
derives a complete datum-aligned source contact face on the exact drawn
boundary, and submits only a proven `Approach.Request`. The player can request
a new suggestion or select a painted boundary in the world. Failure retains
the prior marker and drawing, disables confirmation, and states the refusal.
The preview labels the **first cut / work face**, not an invented finished
lining/opening. All required profile roles and actual existing route polylines
are drawn from the completed observation.

Search advances at most 32 cheap pairs and one complete existing Approach proof
per step. It retains no proof witness, prepared candidate or cold lease across
a frame. Weak owner identities plus original revisions/receipts are checked
around observations; the final epoch read is concrete and callback-free. Actual
RoomOrders repeats its original complete cold/prepared/final admission before
publishing the room. Preview never orders excavation or a passage.

The tests use real Directory, World, Space, Terrain, Profiles, Catalog,
Locations, WorldRoutes, Budget, RoomBindings and RoomOrders. Their authored
profile and physical room fixture is explicitly synthetic. This does not
establish that current published worker sources can reach the first real
Kitchen, or provide a host anchor, installed entry, paid work, handling or
whole-demo activation. The existing full-source WALK→WORK clearance gap is not
waived by a passing UI fixture.

## Independent review correction

Root's review-v1 identified a HIGH configuration lifetime bug: an observer could
free the original Editor, the adapter could skip binding while leaving an empty
refusal, and its refresh tail would dereference the freed Node. The MEDIUM UI
finding was the player-facing implementation-backlog phrase. All 13 original
executable/UID pins are preserved byte-exact under `source-review-1/`, with
locators; original review manifests, candidate 11 and native 2 remain unchanged.

The correction captures the original Editor/Tool/Draft, callbacks, command
snapshot, Room owners and complete WorldRoutes configuration before observers.
Every observation is followed by concrete original-identity checks. A refused
configuration publishes no Access and preserves an existing binding. There is
no synchronous refresh after publication. A successful bind disables Confirm;
the next normal editor frame uses the existing revision sentinel to start
searching the already drawn room, unless a stroke remains in progress.

Four actual-source regressions cover freed Editor/Tool/Camera, replaced owners,
drawing and callback mutation, a newer Access binding, final view callbacks,
and first-bind progress without another input. Player text now reads
“First cut selected · worker clearance and access shown.” Native 3 records it.

The temporary original drawing adds one bounded 131,072-byte image plus 33
scalar bytes in the configuration phase. Its separate conservative peak is
495,301 logical bytes. The temporary strong tuple has 10 object references,
13 Configuration references, two Callables and one Dictionary; these native
costs remain unmeasured. No retained field, bank or authority is added.

## Final validation

`candidate-12/invocation.json`: Access 25/768, Runtime 16/227 and Editor
10/116 pass; unchanged WorldTool retains candidate-11 9/149. Together these
selected suites provide **60 tests / 1,260 assertions / 0 failures**, all strict
and raw diagnostic/leak counts zero. Candidate 12 analyzer **0/6**. All snapshotted source,
HEAD, project, registry, asset presence and import sidecars restored/unchanged.
Official singleton suites are selected from `ci_test_shards.py`; this is not a
no-argument/full-project milestone.

`native-3/`: actual **Metal / Forward+**, three saved **1280×720** PNGs,
**15 assertions / 0 failures**, raw diagnostics/leaks zero and analyzer **0/1**.
All 1,206 source inputs match before/after. View the actual artifacts:

- `native-3/ready.png`: exact first-cut/source clearance and existing route;
- `native-3/choose-boundary.png`: explicit world-reposition instruction;
- `native-3/invalid-boundary.png`: previous marker retained, textual refusal,
  confirmation disabled, identical original drawing.

The native scene uses plain labelled dirt and synthetic physical/source data.
It proves this adapter's rendering and states, not game art or full HUD quality.
The tool's analyzer maps the external evidence script into an editor document
using its supported `--project`/`--editor-project` options; it does not add a
runtime project script or alter a producer.

`review-v2/python-tests.log`: **8 tests pass**. The census mutants detect expanded
pair/route capacity, escaped witness, wrong lease release, hidden cell copies
and missing final epoch validation. Native-oracle tests reject short/failed
reports, wrong backend, missing images and raw diagnostics despite exit zero.

## Performance and lifetime limits

Final native headless timing is diagnostic, never gameplay authority:

| Actual finite fixture | Candidate 10 | Candidate 11 | Candidate 12 |
|---|---:|---:|---:|
| small successful candidate | 2,989 µs | 2,932 µs | 2,951 µs |
| sparse 128-Location scan step, no full proof | 650 µs | 682 µs | 698 µs |
| 16,384 painted cells, allocated R6,144/O2,048 | 2,963 µs | 2,821 µs | 3,173 µs |
| populated 1,024 Locations / 1,536 edges / 4,096 vertices, 16,384 paint | 68,858 µs | 70,021 µs | 69,176 µs |

The last fixture publishes every endpoint and edge through actual public
Location/WorldRoutes APIs, uses a 768-edge shortest path, and has no positive
provider override. It is one populated finite graph, not a bound over every
source/graph arrangement. R/O are allocated capacities; all 2,048 source rows
are not populated adversarially. The steady 1.5 ms UI target remains **failed**;
the full demo's 0.25-second overload bound is **unqualified**. Existing Approach
proof is synchronous over actual live owners. Safe resumable proof or isolated
dispatch requires a separately reviewed lifetime design; this packet does not
introduce unsafe asynchronous access or skip exact checks.

`review-v2/census.json` derives every added numeric field, transitive packet,
array bound and conservative frame sum from actual source. Added retained view
payload is **361,875 logical bytes**. Its conservative command/copy plus the
entire existing cold reservation is **1,937,477 logical bytes**. Some alternative
and already-cold caller images are deliberately counted twice. Existing cold
capacity **1,048,960**, required preview Approach **395,264**, and ordinary
1150 maximum **938,368** are unchanged. No authoritative field/bank/save column
is added and no existing Draft/Overlay/Session budget is reclaimed.

Native references, String/Variant/Dictionary/Callable overhead, packed capacity
slack, render-server copies and deferred GPU lifetimes are not measured by that
logical census. Two raw mesh position images are an explicitly conservative
payload comparison, not a measured maximum native lifetime. The simulation
ledger is not claimed as whole-client proof.

## Reproduction

Run in a fresh own worktree with local LFS objects materialized and all accepted
prerequisites present. Every output path must be new. These commands may only
write their own worktree; the wrappers set and restore a unique Godot user dir.

```sh
python3 -B docs/validation/evidence/underground-room-access-2026-10-04/test_evidence.py
python3 -B docs/validation/evidence/underground-room-access-2026-10-04/census.py
python3 -B docs/validation/evidence/underground-room-access-2026-10-04/reproduce.py --out /tmp/ug1154-review-new --port 6337
python3 -B docs/validation/evidence/underground-room-access-2026-10-04/run_capture.py /tmp/ug1154-native-new --port 6339
```

The native command intentionally checks the actual Metal/Forward+ backend of
this machine. A different backend is not silently accepted as the same witness.
Review does not require another engine run; all raw outputs/pins are retained.

## Retained rejected and superseded evidence

- Candidate 1 refused missing LFS import assets. Only this own worktree's cached
  LFS objects were checked out; no paid/network generation or main mutation.
- Candidate 2 refused missing accepted registry metadata before tests.
- Candidates 4/6 caught nested-fixture preload/name errors; 5 caught actual
  Location/Routes capacity mismatch. Source guards were preserved.
- Candidate 3 had two analyzer warnings, later corrected. Candidate 7's passing
  pre-optimization maximum-paint step was **52,075 µs**; exact boundary-cell
  indexing removed the unrelated paint scan without filling holes or clipping.
- Candidates 8/9 correctly refused missing real paid Site keys in the full
  graph fixture. Candidate 10 adds the genuine second-row keys before public
  endpoint admission; no success stub was introduced.
- Candidate 11 adds the late successful-liveness observer regression and pure
  epoch checks. Its production/test source is the historical candidate, superseded by candidate 12.
- Native 1 passed its assertions but its diagnostic panel put ink text on an
  ink background. The exact executed capture is retained as `.gd.txt` and the
  rejected images remain. Native 2 uses the editor's intended light paper.
- `census-rejected-1/` retains the initial incorrect typed-Array parser
  expectation (one positive-census error). `census-rejected-2/` retains the
  subsequent hidden-copy mutant failure caused by substring matching. The
  final census checks the exact assignment line and all eight current tests (seven in the historical review-v1 run) pass.

Historical invocation/log bytes remain untouched. Early WIP source closures
were recorded as hashes; only retained `.txt` snapshots are claimed as available
historical source bytes. No later source is represented as the source of an
earlier run.

## Independent review acceptance

Root independently accepted review-v2 on 2026-10-04. All 13 source, 46 output
and 277 history pins matched. The reviewer replayed eight Python tests and the
census, read the complete lifecycle correction and real regressions, and opened
native-3/ready.png (the other states were already reviewed). Both review-v1
findings are closed. No engine suite was duplicated. Acceptance remains this
UI/adapter component only; performance and whole-demo limits above remain open.

The final documentation wording correction identifies candidate 11 and the
seven-test run as historical. No executable source changed after acceptance;
`acceptance-v2/frozen-document-locators.json` preserves the exact review-v2
README and decision bytes without rewriting their immutable manifests.
