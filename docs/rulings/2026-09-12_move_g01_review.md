# MOVE-G01 request — Astra review and remaining authoring decisions

2026-09-12. Status: **REVIEWED; MOVE-G01 remains OPEN**.
This is a response to the [executor request digest](requests/2026-09-12_move_g01_request.md),
not adoption of every assertion in it. No runtime constants, species permissions,
hazard penalties or gate completion are enacted here.

## 1. Findings that change the next step

The missing production profiles, excavation accounting and interruption rules
are real blockers. The request nevertheless contains four material overstatements:

1. The clearance **domain already exists**. `spatial_world.gd` declares classes
   1–512, measured in 512-unit (half-metre) cells. Its passable square is anchored
   at the north-west cell, rather than centered on the resident. The missing
   deliverable is the profile-to-envelope assignment and placement proof.
2. Settlement health loss already exists in both the GDD and runtime interface.
   `needs.apply_health_event(slot, signed_points)` applies instantaneous health
   changes; `set_injury_state()` binds injury presence. The missing aggregate
   Injury owner, hazard integration and exact new hazard rules are separate.
   Absence of settlement combat does not imply absence of health loss.
3. Building lifecycle and general material/refund rules already exist. Underground
   construction needs explicit extensions and a project implementation, rather
   than an unrelated second building or inventory system.
4. Q1/Q2 do not alone make surface swimming or climbing implementable. Speeds,
   durations, equipment/posture, supported exit/landing and interruption rules
   apply on the surface too. Full 05.1b includes G02 binding after G01; the
   existing task text does not say that G01 alone completes it.

The request cites DEC-039 and a squirrel height of 1178u. Neither the main
repository nor the supplied scratch checkout's `setting_decisions.md` contains
that decision at this audit. The scratch asset table still has the earlier
1024u squirrel comparison candidate. Treat the new approval as **executor-reported,
source not located**, not as disproven. Obtain the actual decision artifact from
the executor's owning worktree and reconcile its versions. Do not revert heights,
replace them with older candidates, or manufacture a user-approval record.

The scratch checkout also contains decisions 0095 and 0101, which are absent
from the inspected main checkout. This review reads those newer records but does
not merge their code or assert they are integrated in the main tree. They record
real stage-column/admission work; their separate persistence/registry limitations
must remain visible. Main-tree absence is not proof that the executor did no work.

## 2. Q1 — retain the existing class domain; finish the envelope contract

Use the existing ground clearance classes, not new species-size enum values.
Class k requires an all-passable k by k square of half-metre cells at the route
anchor. Class zero is not an admissible resident profile. This is a horizontal
ground predicate, not tunnel height clearance or proof of turning-room fit.

For each enabled `(species, life_stage, posture, equipment/load variant)`, the
asset/movement handoff must publish integer local min/max X/Y/Z, the root/origin,
anchor-to-root offset, swept envelopes over entry/travel/turn/exit poses, an
explicit margin (including zero if intended), and source/proportion/rig revisions.
The square must contain the complete horizontal envelope **at that offset**.
`ceil(max(width, depth)/512)` supplies a size lower bound; it does not prove
placement. Current ground cell centers use a 256u offset, which cannot silently
be treated as the center of every larger square. Any changed placement convention
must update transforms, contacts, picking and save semantics together under G02.

Openings also require swept vertical clearance, supported posture and load/grip
checks. Prove bends, diagonal corners, both directions and loaded/stowed variants.
Approved total height, body-size class and battle separation radius do not supply
these measurements. Preserve MOVE-DEP-R01's measured-envelope requirement.

**Answer:** the numeric class domain is settled; assigning a class to mouse,
mole, squirrel or otter remains blocked on actual envelope/placement evidence.
Synthetic fit fixtures may proceed, clearly labeled. Do not use a guessed body
width to turn `PROFILE_CLEARANCE_UNSPECIFIED` into an apparent production pass.

## 3. Q2 — capability, implementation and situational refusal are separate

Keep all six declared modes. For each profile/mode, the catalog must distinguish:

- `UNPROFILED`: required data or implementation is missing; this is a development
  boundary and may not masquerade as an animal's inherent inability.
- `DISABLED`: an authored, identified policy/profile restriction applies, with
  a reason and the exact circumstance in which it can change, if any.
- `ENABLED`: a complete cost/eligibility row exists; actual entry still checks
  body, gear, load, health/stage, endpoints, topology and protected return access.

These are semantic states for the next catalog contract, not newly assigned
binary enum values. A known capability lacking current equipment is not the
same case as missing implementation or a permanent species prohibition.

The required mode row includes speed u/s; entry/exit ticks; posture/grip and
equipment rules; committed load bound; turn/transition treatment; need/work
effects; and interruption/return behavior. Dive rows also include air capacity,
consumption, recovery and contingency. A mode bit alone is not a usable row.
Distinguish supported built stairs/ladders from natural trunk/branch climbing.
Walking in a completed tunnel is independent of ability to excavate it.

Do not infer a universal “moles cannot swim” or “only squirrels may climb” table.
The content atlas explicitly records training, assistance, equipment and access
beyond species identity. Nor may that direction silently add a training system:
if learned capability is chosen, its owner, acquisition, storage and save contract
must be supplied. No new species-mode permission table is approved by this review.

**Answer:** write the full profile/mode matrix, including explicit disabled
cases, before enabling each new mode. Q5 safe interruption is also a predecessor
for swimming/climbing, even when underground construction is not involved.

## 4. Q3 — finite underground extent, with a concrete candidate to evaluate

Recommended starting proposal: **four underground floor levels at 4m spacing**,
floors at -4096, -8192, -12288 and -16384u relative to one registered immutable
ground datum for the map. Retain the surface 128 by 128 two-metre tile footprint.
These are **new, unratified engineering candidates**, not inherited dimensions
and not an approval to allocate four copies of the surface world.

This gives 65536 possible underground tile-level addresses, or 1048576
half-metre horizontal cell-level addresses if fully expanded. Neither number
is a packed-store capacity. G02 must derive sparse/dense representation, actual
excavation/connection/contact limits, scratch and save/load peak memory within
the existing budget before adoption. Full arrays at the inherited surface row
width alone would consume 14680064 bytes, excluding all those other owners.

The binding proposal must additionally define usable ceiling/structural thickness,
floor boundary inclusivity, shafts and interlevel stair/ramp geometry, natural
cavities and water intersection. No implicit transfer between coincident X/Z.
One datum must be shared by placed burrows, planned tunnels and free excavation;
independent local datums must not make adjoining projects disagree about space.
Variable surface terrain needs an explicit datum/cover rule, not a local-height
subtraction that creates mismatched levels. Water depth and canopy elevation
bounds are also needed for full G01, even though Q3 asks only about underground.

**Answer:** the old one-floor bounds and building above-datum envelopes cannot
answer Q3. The four-level proposal is ready for geometry/memory review; it is
not a production constant or proof that all expanded space fits the budget.

## 5. Q4 — extend existing construction; decide spoil explicitly

Inherit REQ-SET-124–128 and 137: delivery before work, consumption when work
begins, 100% delivered-material refund before work, 80% after work (milli-U floor),
and evacuation before demolition. Finished building demolition costs 25% of
declared construction work and returns 50% original materials. These rules do
not by themselves define how an excavated void is cancelled or backfilled.

The new underground project state table must map onto the existing BuildingState
owner and name physical milestones separately: unexcavated, excavation in progress,
excavated but unavailable, support/fit-out in progress, completed/published, and
backfill/removal in progress. These are required distinguishable conditions,
not new numeric enum assignments. Pause and blocked reasons should not erase
physical progress. Do not publish unfinished space as a shortcut.

For each of the three tools, author per-unit excavation volume, milli-WU, crew/tool
rules, support/lining inputs in milli-U, output quantities, completion transaction,
cancel/refund/backfill behavior and reuse of previously excavated space. Published
spaces enter one room/service/topology system and remain after builders leave.

**Recommended spoil policy, awaiting Brendan's answer:** a real earth/spoil item,
with legal onsite piles, hauling and explicitly authored reuse. Give it its own
catalog key, category, mass per U, yield per excavation unit, shelf/filter rules,
storage destinations and deterministic disposal/backfill sinks. Do not rename
stone or compost into spoil; no such earth item currently exists. Do not infer
real material density from the stylized game units.

Inventory admission must use real destination capacity and the existing mass
rounding rule `ceil(quantity_milli * mass_g_per_U / 1000)` per lot. A ground pile
has 400000g capacity, not infinite space. Before committing an excavation output,
reserve its legal destination along with required transaction resources; otherwise
wait without losing work, deleting soil or creating partially published terrain.
Whether immediate adjacent placement avoids a haul is an explicit rule, not an
automatic consequence of making spoil an item.

Cancellation cannot rewind excavation, create original earth a second time,
refund generated spoil as purchased material or fill a void containing people,
items or protected exits. Repeated dig/cancel/backfill cycles need conservation
fixtures. Conversely, abstract spoil would not make digging free: work and tool
wear remain. Exact excavation and disposal costs remain to author after the
spoil policy; surface building costs are not valid substitutes.

## 6. Q5 — use settlement injury/care, with complete interruption outcomes

**Recommended feel, awaiting Brendan's answer:** visible warnings, preventable
danger and rescue with existing injury/care consequences, rather than surprise
instant-death rolls. This does not choose immunity, oxygen duration, damage amount,
injury kinds or a new combat layer. Numerical hazard contracts remain open.

Correct the request's premise: GDD §5.4/5.5 already assigns fishing/foraging health
loss and injury severity; REQ-SET-172 assigns untreated damage of 1/4 health per
hour for severity 1/2; REQ-SET-173 owns treatment. `apply_health_event` exists.
The aggregate Injury kind/severity/care store and its integration are still owed.
Fishing's bite/cut/exposure descriptions are not a complete compiled InjuryKind
domain that movement can silently extend or assume is implemented.

Required matrix: every enabled mode crossed with cancel, need diversion,
exhaustion, incapacity, death, profile/load change, topology change, and forced
hazard. Each cell defines supported hold/finish/retreat/rescue, retained progress,
protected landing/return claim, cargo disposition and exact publication order.
No floor sleep in water, instant snap to shore, deleted occupied transition or
inventory loss as a fallback. Voluntary cancellation preserves committed travel
until its specified safe stopping point. Future edges revalidate before entry.

Dive planning must account for the whole submerged route, entry/exit, permitted
waiting and contingency against current available air. Reserve a valid air
endpoint before entry. Every submerged fixed tick consumes the authored amount,
including waits; pause consumes none. Specify return trigger, recovery, exact
expiry consequences and how incapacity/rescue can occur before any runtime dive
is enabled. Safe planned admission alone is not a policy for later incapacity.
Canopy work likewise needs a supported descent and compatible cargo recovery.

Construction must specify support and water rules plus whether collapse/flooding
can occur, their trigger/cadence and outcome. Deletion refusal protects against
player edits; it is not a complete answer for involuntary world hazards. Never
borrow a fishing roll or generic severity merely because its numeric value exists.

## 7. Coverage and life stage — answer settled by current scope

Four adults-only profiles are a legitimate **starter increment**. They are not
the complete release catalog. All 16 admitted species need explicit ground and
applicable connected-mode profiles for release; badger height approval alone
does not make a badger profile. Full G01 coverage includes the supported life
stages and their dependencies, not necessarily every theoretically imaginable
body/gear combination (unsupported combinations require explicit refusals).

CHILD/ELDER immobility is **not** an approved release design. DEC-032 requires
visible dependent residents and active elders. Existing `LIFE_STAGE_NOT_PROFILED`
is a temporary implementation refusal pending PC-04 needs/care/schedule/work/
hazard/profile contracts. Do not remove that validation by substituting adult
coefficients; do not interpret it as permission to ship immobile family members.
The stored stage remains authoritative as decisions 0095/0101 require.

## 8. Exact handoff and acceptance boundary

1. Preserve this request and review; locate DEC-039 in the executor's actual
   owner worktree and synchronize that decision without overwriting newer work.
2. Asset/movement lane produces four starter swept-envelope/anchor fit manifests.
   Independent reviewer checks the anchored-square convention and contact roots.
3. Astra completes the numerical G01 catalog: species/stage/mode rows; underground,
   water and canopy bounds; construction recipes/spoil; full interruption/hazard
   matrix. Resolve the two pending player preferences before adopting their
   dependent rules. PC-04 runs in parallel; do not send these choices back to the
   coder as a request to invent missing values.
4. Architecture lane binds the adopted catalog into finite stores, topology
   transactions and versioned saves. Synthetic graphs and refusal/conservation
   tests may proceed now; unspecified production modes remain disabled as gaps.
5. Re-run fit/load boundaries, all construction-method interoperability,
   dig/cancel/backfill conservation, safe-exit deletion, mid-traversal interruption,
   pause/air accounting, stage/identity reuse and every-tick save continuation.
   Actual results, not a specification table, determine runtime acceptance.

**What this review establishes:** corrected dependencies and existing owners,
the clearance-domain answer, full-release species/stage scope, an explicit finite
depth candidate, and reviewable spoil/hazard preferences. **What it does not
establish:** assigned physical envelopes, new movement coefficients, complete
G01, G02–G05, integrated code, runtime tests, performance or save parity.

Sources: [movement amendment](../movement_direction_amendment.md),
[current dependency ruling](2026-09-12_movement_dependency_rulings.md),
[task 05](../tasks/05_movement_first_playable.md),
[GDD](../game_gdd.md), [balance](../gameplay_balance.md),
[source movement atlas](../redwall-content-library/shared/locations_and_movement.md).
Bounded source retrieval also checked `lord_brocktree::LB-PLACE-low-sea-exit-tunnel`,
blocks 1550–1673: relevant passage/access context, no numerical movement authority.
Audit provenance and mechanical checks are in
[review validation](2026-09-12_move_g01_review_validation.json).
