# 1150 — Prospective ordinary-room approach

Date: 2026-10-04 · Status: independently accepted component at candidate15; no playable or phase permission

## Decision and ownership

Implement the missing cold approach observation for an ordinary confirmed Room
without manufacturing an EntryPlan, Placement, worker, Job, completed floor or
source certificate. This lane owns only `underground_room_bindings.gd`,
`test_underground_room_admission.gd`, new `underground_room_approach.gd` and its
test/UIDs, the additionally granted static final Terrain seam in
`underground_terrain.gd`, this record and
`validation/evidence/underground-room-approach-2026-10-04/`.

The isolated branch starts at fetched origin/master `82d60ba8`, fast-forwards to
reviewed integration `e2f76f54`, then takes these accepted prerequisites:
shared registry `ee4a1596` as `be6101c3`, Geometry's ordinary publication
`54624850` as `d55a2b82`, and root's ordinary RoomOrders/Sites tail `9a8e353f`
as `7e199b76`. The queue conflict during the last cherry-pick was resolved with
exact incoming queue bytes, without a separate queue change. The implementation
diff base is `7e199b7669a5bad5613aaf2881c9a801cc1dda51`.

Root retains RoomOrders, Sites, the shared ledger and runtime host. Geometry
retains Space/Locations/Routes/Authority. No published profile consumer is
edited by this packet. Temporary test registry text is retained in each
invocation and restored byte-for-byte; it is not a permanent registry claim.

## Exact request and pre-candidate observation

`Approach.Request` extends the existing caller-owned `Orders.RoomPlan`. It adds
full access/work Location references, exact travel/work profile IDs and
revisions, profile content revision, a datum-aligned target cube origin, face
and exact yaw. Ordinary RoomPlan inputs remain refused when no exact approach
is supplied. Drawing purpose, level, cells, origin and height are unchanged.
No first-match profile selection, implicit rotation or route is introduced.

RoomBindings binds the real WorldRoutes provider once. Under the original whole
Room cold lease, after the original geometry/history survey has returned and
released its image, the approach calls actual `Routes.profile_path_into` and
the existing `WorkFace.Check` algorithm. Exact fine-cell/vertical intersection
requires the target to belong to the same metre-cube union that RoomCutMap
will enumerate, without allocating another CutMap or footprint. Both
profiles must name the same authored species, life stage, rig, equipment and
cargo range. The actual path requires a travel mode; WorkFace independently
requires the exact BUILD source/contact and complete planar patch.

Every source role remains in the existing WorkFace proof. The travel profile
also proves complete BODY, TURN and STANCE at both actual endpoints, including
a zero-edge path. Negative body residual is not clipped: only actual SUPPORT
intersecting authored STANCE can cover a legal contact, and overlapping VOID
cannot excuse other solid/support penetration.

The witness retains exact descriptors, source hashes, every original role box,
full endpoint payloads and a full-generation edge path. It borrows the existing
protected plain RoomPlan rather than making a fourth Room footprint copy.
All additional caller Request fields are copied separately so RoomPlan.copy_from
cannot erase their identity. No worker or persistent per-Room ledger is added.

## Prepared and publication boundary

WorkFace refuses while Space has a candidate, so its large physical proof runs
before RoomOrders begins staging. That image and its fragment buffers are
explicitly released before any prepared companion allocates. The small Face
packets remain counted for later scratch and original endpoint/source pins.

Only metadata may change: every old physical region column must remain exact,
and newborn rows may only be the original future Room's FLOOR_DATUM or
OBSTACLE/CLAIM_ROOM. Prepared closure rechecks complete source and endpoint
facts, plus fresh concrete Terrain facts for the target, every work role and
every original travel segment. The full local-query count is charged before
the first such fact read. An original prepared RoomContext permits reading
unchanged live endpoint payloads while its own refresh candidate exists;
foreign candidates, changed original payloads and changed source epochs refuse.
The final existing Locations leaf separately verifies all staged rows.

The public hooks used by the accepted root tail are:

- `room_approach_observation_refusal(plan, candidate, space_token)` performs
  observers and prepared facts under the original candidate/lease.
- `room_approach_final_refusal(plan, candidate, space_token)` closes exact
  original scope, actual source/Terrain and all prepared companion facts after
  every other observer. It allocates no large survey or path.

The accepted ordinary RoomContext/FinalFacts/Space kernels in ADR1151 and
root's accepted ordinary RoomOrders/Sites tail are prerequisites. The actual
sequence is approach observation, Sites/other observations, approach final
leaf, concrete local/Sites leaves, Directory/Buildings identity, Space swap,
then static Locations and WorldRoutes swaps. There is no observer between
identity and these publications. All old endpoints and edges are refreshed;
no future endpoint or route is fabricated. Exact successful publication
receipts bind the companions to this original Room/Space operation.

Cleanup aborts only the original companion tokens and drops every witness,
plan and survey before releasing the original lease. Reentry poisons the
current operation without allowing the nested call to close or replace it.
A substituted equal-sized lease remains owned by its creator.

## Complete logical memory coexistence

Reuse the existing 1,048,960-byte cold lease; no global reserve grows. The
source census in the evidence directory counts the following fixed packets:

| Component | Logical bytes |
| --- | ---: |
| Request extra fields | 84 |
| New witness, request extension, descriptors, endpoint, source/role pins and RoomContext | 1,744 |
| Inherited Face.Check after image/fragments are dropped | 907 |
| All own numeric function frames, conservatively summed | 604 |
| New static Terrain frames plus complete inherited leaf frames, conservatively summed | 384 |
| New witness plus all own/Terrain frames, path-call allowance 512 and expression allowance 512 | 3,756 / 4,096 |
| Retained inherited Face allowance | 2,048 |
| Original full-ref path, at 1,536 edges | 12,288 |
| Existing Room/Sites allowance, counted once | 2,048 |
| Reviewed root/ADR1151 final tail within that existing allowance | 1,984 / 2,048 |

At N=16,384 fine cells the three original Room cell images use 24N bytes.
Sites subsequently holds the fourth input and cut cursor, making its existing
40N+2,048 expression. That expression already includes the original Room/Sites
helper allowance; it is not counted again.

| Sequential stage | Logical peak bytes |
| --- | ---: |
| Original Room survey | 854,016 |
| Pre-candidate WorkFace and retained path/witness | 790,528 |
| Locations snapshot, K=8,192 fragments and retained witness/path | **938,368** |
| WorldRoutes proof with retained witness/path | 791,552 |
| After Sites preparation through final publication | 675,840 |

The admitted maximum is 938,368, leaving 110,592 logical bytes in the existing
cold lease. The larger Locations stage corrects an earlier incomplete draft
that counted only the original 854,016-byte survey. The geometry lane's
moving-source review is retained separately; this packet's source census is
the current one.

RoomBindings' declared retained numeric/packed count is 227 bytes within its
existing 512-byte allowance, up from 226. Two additional handles (weak actual
WorldRoutes and cold Witness) and the reentry boolean are explicit. Approach
has no module-retained numeric/packed state, no banks or save fields. Strong
owner references borrow the existing live/stage banks and do not create a
third image. Reference objects, allocator and other native overhead remain
unmeasured; these logical formulas are not whole-client qualification.

## Verification and limits

The focused tests use actual owner, route, Terrain, immutable profile loader,
RoomOrders, WorkFace and Site stores. Preexisting corridor geometry and
immutable profile numeric values/certificate flags are explicitly synthetic
fixture content. Only the initial corridor registration and unstarted Site
fixture adapter are synthetic; all new Kitchen proof/preparation/publication
hooks run the actual implementations with no successful proof override.

Tests cover genuine path/contact admission before any candidate, disconnected
and zero-edge paths, missing full-volume clearance, exact target membership,
all additional Request fields, actual source replacement, original lease and
candidate identity, full prepared companion closure and reentry. Actual last
Sites observers attempt a profile reload, new well foundation or replacement
lease; the final leaf refuses before Room identity and cleanup preserves the
live geometry and original endpoint/edge stores. A successful confirmation
preserves a 512u fine-grid hole while registering each intersected metre cube
once. Room confirmation pays no materials and creates no productive Job.

Strict official singleton suites, raw diagnostic/leak checks, a zero-warning
five-file analyzer, ten source-census checks/mutants and independent source review
are recorded in the evidence README. Rejected import, fixture, analyzer and
assertion runs stay historical. Missing prerequisites are never replaced by
success flags, warning exemptions or a fake EntryPlan/Placement.

Ordinary purpose5 BRACE/CUT/FINISH phase composition, Jobs/material/spoil
handling, paid full descent, runtime source-phase travel, default renderer
qualification and the empty Kitchen walkthrough remain separate. Existing
recipes, permanent Room purpose and furniture service rules are unchanged.
A Room admission receipt is not a finished shell, service grant or playable
acceptance.

## Candidate13 independent review correction

Geometry independently matched all nine source pins and reproduced the
census/tests. One medium was found in that candidate: the final own source tail and transitive
Terrain leaf still dispatch overridable World/Room/terrain subreaders after
physical observation. Candidate13 is retained as rejected boundary evidence.
The correction must use concrete/static stored facts under the original
tokens, with final-only real mutation regressions. Shared Terrain changes
require a separately authorized owner seam; no source permission or limit
may be weakened. See the evidence `source-review-1/review.md`.

## Authorized final-reader correction

Root granted the existing `underground_terrain.gd` seam solely for a new static prepared-local validator. Earlier observed readers retain their behavior. The new path reads the actual World, resource, Building, Directory and geometry columns, preserving full mirrored identities, original sealed Space/cold tokens, local tile limits and role/vertical semantics without dispatching their overridable methods. Approach will likewise compare original endpoint and published World columns directly. No fields, arrays, policy or capacity are added. The complete numeric helper chain is charged against the existing Approach 4,096-byte cold allowance before final review.

Candidate14 reproduces five final-reader side effects under actual prepared admission. World-publication and Room-identity callbacks leave a successful final result after adding a real well; three terrain/node/building tile cases are later refused as stale candidates but have already mutated actual state. These tests require zero final observation calls and independently verify that an actual foundation mutation is still refused. They do not imply every historical mutation bypassed the complete identity tail. Original source and test bytes are retained under `source-review-1/final-reader-repro-source/`.

The correction is frozen at `source-review-2/source-sha256.json`. Direct
static Terrain reads preserve every existing role, vertical boundary,
resource lifecycle, rotated Building footprint, complete Directory mirror
and original prepared/cold identity check. Final endpoint/source checks now
also use stored columns. Nine new regression/parity cases pass; all four
selected suites total 96 tests and 3,251 assertions with zero failures,
strict/raw diagnostics or leaks. The analyzer reports zero warnings over
five files. Ten source/lifetime/census checks pass. The full conservative
helper charge is 3,756/4,096 and the composed peak remains 938,368 bytes.
Independent Geometry re-review accepted all ten exact source pins, independently
replayed the ten Python tests and exact census, and inspected the raw runtime
evidence without another engine run. It found no remaining high/medium issue
in the reviewed scope. The exact acceptance is retained in
`source-review-2/acceptance.md`; no limit or playable acceptance scope expands.

## Whole-project inheritance correction

The integration's full analyzer across 1,231 files reported one duplicate member:
`underground_entry_bindings.gd` already declared the same `WorldRoutes` preload
now provided by its `RoomBindings` parent. The focused five-file analyzer did
not include this derived script. Preserve that full rejected result under the
host checkpoint's `approach-integrated-1/all-analyzer.*` evidence.

Remove only the identical child preload and inherit the parent's exact script.
There is no field, geometry, guard, type-identity or allocation change. Geometry
independently reviewed the one-line diff after explicitly returning the narrow
EntryBindings lease. The memory artifact records the changed source hash;
strict entry and ordinary-room regressions plus targeted analyzer verification
are recorded separately in `entry-inheritance-1`. No earlier failed analyzer
result is relabeled as a pass.
