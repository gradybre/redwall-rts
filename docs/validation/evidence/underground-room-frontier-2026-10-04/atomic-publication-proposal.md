# Proposed atomic publication of a paid Room's next work contact

Date: 2026-10-04. Read-only design trace at construction branch `2ac43b6c`.
This proposal is outside the frozen1157 source-review-1 manifest. It implements
nothing and grants no source, movement, work, geometry or allocation permission.

## Smallest useful transaction

Publish **one new WORK Location and two directed, source-qualified ground edges
against unchanged, already-paid live Space**. The new station must be entirely
supported by existing natural or paid geometry; the target cube may still be
solid. Keep every old endpoint, edge, path vertex, certificate bit and occupied
or queued actor unchanged. Do not start a paid operation or edit a Site.

This can be smaller than another Space transaction. Existing
`Locations.begin_prepare(cold, 0)` copies its admitted inactive bank while
requiring no prepared Space. `WorldRoutes.begin_prepare(cold, 0, location_token)`
already prepares Routes and its certificate bank against that sealed Location
candidate and the same live Space revision. No new Space/source row, source
revision, section, Placement bank swap or PhaseContext is necessary when only
metadata and graph edges are added. PhaseContext remains reserved for the actual
Sites operation; RoomContext remains reserved for a new Room admission.

The missing atomic tail is real. Normal `Locations.publish` may swap first;
normal `WorldRoutes.publish` subsequently performs binding/source/endpoint
observers and may refuse. They cannot be chained and called atomic.

This first transaction must be restricted to paths whose complete interior
points lie in an existing exact FLOOR_DATUM section. It may join an old endpoint
with a different endpoint section only where the actual existing containment
rules allow the boundary. `Routes._read_motion_containment` uses the authored
span section until arrival, and `WorldRoutes._transit_region_into` refuses
interior points outside that section. A route crossing two section interiors
needs a real boundary endpoint and split spans; two long edges are not an honest
substitute. If the first Kitchen contact requires this, the first transaction
must refuse with that precise missing publication requirement.

## Existing methods and their limits

| Owner and source location | Reusable operation | Limit that must stay intact |
| --- | --- | --- |
| Locations909–942,1475–1551 | `begin_prepare`, `stage_add`, `seal` on live Space | Whole envelope and independent support coverage, actual Room/Site/section and exclusions; original cold token |
| Locations1611–1631 | Normal `publish` | Contains observers; unsuitable as the first irreversible half of a combined commit |
| WorkFace124–201,430–449 | Complete actual source/target/body/contact proof | Both initial and final endpoint reads require a **live** Location; cannot currently prove the new staged endpoint |
| Routes764–808,924–953 | `begin_prepare`, `stage_add` | Exact generation/payload, fixed vertex limits, copied path before certificate observation |
| WorldRoutes647–723,725–819,921–963 | Real proof, per-profile masks and seal | Full body/support/terrain sweep; a mask containing some profile is not proof for the requested forward or retreat profile |
| Routes1393–1415 | `_retained_paths_refusal` | Reusable add-only comparison pattern: every old field, length and vertex preserved |
| WorldRoutes466–553 | Existing retained-mask/final-mask patterns | Keep every previously admitted bit; each new edge must contain the exact selected directed profile |
| Routes1492–1506; WorldRoutes629–644 | Static bank/certificate kernels | Only usable through a new exact preflighted owner boundary, never as caller-accessible permission |
| FinalFacts24–50 | Final current source/claim/actor proof | Current public entry deliberately refuses active Location/Route candidates; needs a distinct exact-context branch |
| Placements1666–1909 | Ordinary paid-phase refresh and static tail | Refresh-only, requires the actual retained Sites/Project/action and sealed Space token; cannot stand in for this publication |
| SpaceOwner1694–1717 | `section_for_paid_cube_into` | Metadata lookup only. Actual coverage, footing and whole source remain separate proofs |

The 1156 diagnostic successor keeps this producer pattern and adds explicit
backward-heading policy. The current +X source pair is forward5, WORK24,
backward9, content2/revision1. These are exact source inputs to the first
diagnostic consumer, not general constants for this coordinator. Production
use still needs the independently accepted1156/current-consumer publication.

## Required narrow seams

Names below are proposed, not existing callable APIs.

1. **One synchronous actual coordinator**, preferably a new ordinary-frontier
   publisher, receives the actual1152 provider, full Room and target Site/key,
   existing access/retreat endpoints, exact source profile pairs and finite
   authored station/path inputs. A1157 Candidate is an input to revalidate,
   never a permit. The publisher rederives the source-local contact translation,
   actual section and complete stance/air bounds. It privately pins all inputs
   before observers, admits the whole cold lifetime, and returns only the final
   three full handles. Every refusal leaves output and live state unchanged.
2. **Locations prospective endpoint scope and add-only leaf.** Begin a guarded
   ordinary-frontier preparation on live Space, then add exactly one row.
   Preserve every old row/generation/payload, retirement flag and geometry
   revision. Counts/free rows may change only for this one actual allocation.
   New scratch must not alias an authoritative packed array. A concrete fixed
   reader exposes this one sealed row to WorkFace under the original tuple;
   it does not make the endpoint live or grant worker permission. Do not widen
   the graph-only1130 observation contract with a caller-success flag.
3. **WorkFace prospective endpoint entry.** Reuse the same complete Check/
   FinishCheck geometry and source proof, with a narrowly typed endpoint reader
   for that exact sealed Location candidate. It must compare the copied record
   again after observers and still validate live Space, target Site history,
   floor residuals, whole body/tool/recovery/stance and contact patch. The old
   live-only APIs and default DRY_SOLID rule remain unchanged. A copied caller
   Record by itself is insufficient. Dispose its large proof before route
   compilation.
4. **Routes/WorldRoutes coupled final leaf and static commit.** Stage the two
   actual edges normally and compile each through WorldRoutes. Seal all
   candidates. The final leaf verifies exactly one new Location, exactly two
   new directed edges, their full endpoints/section/path/source masks, and
   unchanged old payloads/masks. Then a single concrete kernel swaps Locations,
   graph and certificates with no observer, allocation, search or fallible
   source read between swaps. Refactor the existing static swap kernels if
   useful; do not invoke normal public publish methods in that tail.
5. **FinalFacts exact frontier-candidate branch.** The ordinary live guard must
   continue rejecting busy producers. The new branch accepts only the original
   concrete sealed Location/Route/WorldRoutes tuple with Space still live and
   unchanged. It reuses current direct source/claim/full actor and pose proofs;
   it does not borrow a future Room admission or paid phase identity.

All public generic publication doors must reject the owned frontier candidates
throughout preparation, observers, discard and final commit. An observer that
knows a token must not publish a half-transaction. The coordinator's independent
original tokens must survive mutation of any borrowed context until the exact
owned candidates are discarded. A new cold context/binding pointer is real
state: its retained/native cost and any new guard fields require the joint
census before implementation; they are not free because the transaction is
synchronous. Use no per-Site, per-Room or per-worker registry.

## Exact order

1. Require idle producers and the original actual Budget. Revalidate full
   ordinary Room, target Site/key/history, no competing or paused Project,
   selected source rows/digests, access/retreat payloads and source revisions.
   Require all actual bindings and implementation boundaries before allocation.
2. Derive the proposed station from the selected full source contact and exact
   target face. Resolve its real root Site and FLOOR_DATUM. Root Site and target
   Site are different facts: the root must have real completed support/air;
   the next paid target must retain its own current phase/history. Never widen
   void, raise a floor or omit held-tool overhang to make the station fit.
3. Under one cold lease, open the Location candidate on unchanged Space, add
   and seal the single complete endpoint. Prove the prospective WorkFace and
   dispose its large image. Recheck the entire original tuple.
4. Open WorldRoutes against that sealed Location token with Space token zero.
   Add access→new work and new work→retreat, using actual source policies.
   Reuse one bounded Edge packet sequentially: stage_add already copies the
   path. Compile both exact requested masks, then seal graph and certificates.
   Refuse stale old certificates instead of silently deleting an old route.
5. Finish all ordinary source, Terrain, retention and geometry observations.
   Close current local exclusions after those observers and then the concrete
   full source/claim/actor leaf. Verify the original lease, unchanged live
   Space and exact bank identities/receipts again. Recheck private inputs,
   source digests, candidate error/remaining state and every seal.
6. Static final validation must complete **before the first swap**. The only
   remaining tail is Location bank swap, graph bank swap, mask bank swap,
   original receipt publication and direct cleanup. No rollback journal is
   needed because no observable failure remains after the first swap.
7. On refusal, discard only the original Route/certificate and Location
   candidates. Never release a replacement lease. Drop all cold packets before
   releasing the original lease. The host then obtains fresh productive phase
   permission through1152; this publication does not authorize START or Work.

Adding metadata cannot move or evict any occupant. The add-only proof must keep
all current actor and queued path references valid and retain each existing
certificate bit. New station/path physical validation remains necessary. A
transiently occupied station may conservatively refuse; it must never gain an
occupant exception. Final full identity/profile/pose validation must not treat
an unregistered living resident as empty. Static route existence is not an
unoccupied route reservation; existing actual tick movement/occupancy gates
continue to arbitrate the eventual walk.

## Memory/work and test gate

The new transaction is sequential after the completed paid phase. Its caller
Candidate and all proof/output packets must be destroyed before the next
1,048,912-byte phase lifetime. It must not coexist with that near-full peak.
No new bank, source image, permission map or increase to100MB is proposed.

Source-counting starting points: the existing caller Candidate is99B, WorkFace
Request68B, one fully sized Location Record116B, one two-point Edge144B. The
original owner/token/source tuple, private input copies, returned handles,
helper frames and reference/native allowance are **additional**, not absorbed
into1157's already accounted1,966/2,048. The frozen1157 query is not retained
inside the new publisher. Reuse one Edge sequentially, and drop the WorkFace
large image before WorldRoutes creates its proof. Admission must cover the max
of the actual Locations `cold_peak_bytes()`, full WorkFace and WorldRoutes
proof plus the complete coexisting controller/caller payload. All must fit the
existing1,048,960-byte lease. The available cold space is not permission for
unmeasured persistent fields; root's joint retained/native census remains
required. Every loop uses existing or explicitly precharged finite work; no
counter reset or larger limit is proposed.

Required real-owner positive: finish the first actual cube, physically recover/
retreat, derive one truly reachable next station, publish all three handles,
walk the exact forward source to it, pay its BRACE/CUT/FINISH, recover and use
the exact retreat. Compare all old handles/masks and no free Space/support,
Project/goods/WU changes at publication. This positive is still open.

Required refusal/retry cases: insufficient completed support; full tool/air
overhang obstruction; wrong section interior; unavailable forward or backward
profile; missing safe exit; paused/changed target; replacement full Room/Site;
late Terrain/node/furniture/worker change; new living unregistered occupant;
source reload at equal geometry; original lease replacement; observer attempts
generic/static partial publication; caller/private packet drift; exhausted
capacity/work; and failure after first candidate seal. Assert byte-identical
live banks, actor/path state and output, then a valid retry. Changing nothing
but a copied refusal code or source certificate flag is not a positive test.

## Suggested ownership for a later lease

New publisher/test/decision/evidence; narrow producer changes in Locations,
Routes, WorldRoutes; narrow prospective WorkFace and FinalFacts adaptations.
SpaceOwner and Placements can remain read-only in this same-geometry version.
Root retains host scheduling and joint census/registry/fingerprint renewal.
The existing1152 provider, frozen1157 and all paid owners need no speculative
edit to outline this transaction. Any extra boundary endpoint/section or
physical geometry requirement must be reported as a separate concrete scope
change, not hidden in this one-endpoint/two-edge contract.

## Exact inspected source hashes

```text
Locations 55dc0bdb2f50ba53629c81c6c93ebbb8dfc6079508c02d9cf1096dc5cb33f929
Routes 4792c1d37160cb737c5e1220e1a63bd633c84c8aefbe33cb0b72524c34b4b2f0
WorldRoutes 7de9ae26375baff235c90f7d2b5703f9ca638fa1c7276ddf4c86e46c6a85434c
Placements 9f34160f99949eca875bcc6d9f663324e7250193a5217dc83288f05015340aae
SpaceOwner 6e7390a07d80d9ad24a754d82db5db6b4ee045ca4bc1b739858203bcb6d20158
WorkFace fefccffb1a1f6ea79204f129a96a1bac687eb555a32b298f1d61267c31f0a295
FinalFacts c4aed2a5b75571822cba6f40cffd8efe9bd3863b12a5bead6db22daed8e9e93a
1156 diagnostic Routes c5b414aaf5c1679fc232ddccdbafa1491625c12b2dc41613063605f6a44934f4
1156 diagnostic WorldRoutes 7e2bc9f7d7f00f034f408be374f939664d98a3bd64e430283e3b300420991d1f
```
