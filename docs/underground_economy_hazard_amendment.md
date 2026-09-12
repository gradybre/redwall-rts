# Underground economy and movement hazards — SET-MOVE-ECON-001

Revision1 · 2026-09-12 · `NEW_AUTHOR_ADOPTED_FOR_IMPLEMENTATION`.

Authority: [DEC-040](setting_decisions.md#dec-040--excavation-spoil-and-preventable-movement-hazards)
and [SET-MOVE-001](movement_direction_amendment.md). Brendan requested the numerical
planning package after confirming real haulable/reusable spoil and warned,
preventable hazards with rescue. The constants here are Astra-authored engineering
decisions within that direction, **not a claim Brendan supplied each number**.

This is the owning numerical amendment for the scoped excavation/spoil/hazard
rules below. It explicitly overrides REQ-SET-126 only for modular phases as stated
in ECON-005, and extends the existing care/health integration as stated in HAZ-004.
Other GDD rules remain authoritative. It supersedes statements that these particular
prices or hazard outcomes are still awaiting authoring. Four underground levels
at4m spacing remain a candidate. **It does not close full MOVE-G01 or G02–G05.**

Read [the implementation sequence](planning/underground_economy_hazard_handoff.md)
and [machine-readable values](planning/underground_economy_hazard_values.json).
The values JSON is an authoring/import fixture, not automatically loaded production
content. Runtime activation still requires the matching bindings and tests.

## ECON-001 — priced volume and provenance

All numeric additions below are **NEW_AUTHOR_ADOPTED** engineering balance values
under DEC-040, not measurements or user-supplied constants. They are authorized
implementation targets for this economic subsystem, subject to the explicitly
listed geometry/storage/integration dependencies. The four-level/4m layout is
still a candidate; this package neither chooses depth nor certifies memory.

Price excavation by an axis-aligned **1024u cube (1m³)**, called a cut quantum.
Coordinates lie on the 1024u lattice relative to the map's registered immutable
datum. A 2m by2m by1m cut contains4 quanta; a 2m by2m by3m example contains12.
This is an economic quantization and conservation key, not a requirement that
G02 allocate dense voxel arrays. No partial-volume quantum can be charged or
yield soil twice. Irregular art does not change paid volume. The geometry owner
must publish which quanta actually change from solid to void under its adopted
world bounds and support/clearance rules before production excavation activates.
Geometries finer than this cut lattice need a separately priced/catalogued change;
they cannot be silently rounded into free space.

The same stable physical-quantum ledger serves placed burrows, planned rooms/
tunnels and free excavation. Tool choice does not change prices or reset progress.
Burrow templates expand into the actual cut quanta plus explicit fixtures; they
do not create a free void or double-charge a previously completed cut. Existing
furniture, entrance shells, doors, stairs and service fixtures are paid separately
under their actual recipes. Missing access-geometry/recipe rows remain named
dependencies, not zero-cost entrances. Surface building recipes are unchanged.

## ECON-002 — item and exact operation table

New ItemDefinition key `excavated_earth`: category MATERIAL, mass1000g/U, nutrition0,
shelf_hours0, quality PLAIN, raw_edible=false, seed=false, effect NONE/value0.
Own identity; never alias stone or compost. Default legal destinations are
ground piles and general material stores whose filters explicitly accept it.
No food/fertility/fuel benefit or sale recipe is supplied. Mass is a storage and
haul cost under GDD §5.7, **not physical soil density**. Starting inventory is not
increased. Catalog insertion requires the existing deterministic ID compilation
and explicit catalog/save identity change; never hand-insert a numeric Item ID.
Virgin-cut lot provenance is `EXCAVATION`; re-cut backfill provenance is
`BACKFILL_RECLAIM`; tip output uses `SPOIL_RECLAIM`. Compile these keys into the
owning inventory provenance domain with its versioned ID map; do not use arbitrary
int32 literals or create a second provenance namespace. Each new earth output is
PLAIN, recipe_id=-1, age_milli_hours=0, age_remainder=0. Book site/event origin in
the source ledger; a merged earth lot does not erase that ledger. Refunds retain
their actual input lot metadata rather than relabeling it as fresh excavation.

| Operation | Inputs milli-U | Work milli-WU | Result | Owner/conditions |
|---|---|---:|---|---|
| Brace one virgin/backfilled cut quantum | wood250 + stone250 | 2000 | Installed safety support | BUILD, tool, valid dry work contact |
| Cut that braced solid quantum | virgin source OR embedded earth withdrawal | 4000 | Exactly one2000 excavated_earth output; solid→open | BUILD, tool; reserve2000g output first |
| Finish/support that open quantum | none | 3000 | Finished supported void | BUILD, tool; paid bracing already installed |
| Remove installed support during safe closure | none | 1250 | Salvage entitlement wood125 + stone125, published only with closure | BUILD; coupled backfill for open voids; separate safe closure only for never-cut solid |
| Backfill one already open quantum | excavated_earth2000 | 3000 | Open→solid | BUILD, tool; evacuated topology |
| Prepare one spoil-tip tile | none | 4000 | Available tip footprint | BUILD, tool; existing2m tile |
| Compact earth into a tip | excavated_earth q | ceil(q/4) | Embed q milli-U in tip | KEEP, general tool; q>0 |
| Reclaim embedded tip earth | Lock embedded q; debit at commit | ceil(q/2) | q excavated_earth in reserved inventory | BUILD, tool; q>0 |
| Close an empty tip | none | 4000 | Remove tip obstruction/designation | BUILD, tool; embedded q=0 and no claims |

For the variable-q rows, q is an integer **milli-U**, and the result of each
formula is integer **milli-WU**. Thus2000 milli-U costs500 milli-WU to compact
or1000 milli-WU to reclaim. Splitting orders can increase rounding work, never
lower it. No new job/skill index: BUILD1, KEEP10 and HAUL0 retain existing domains.
All operations unlock at M0 once their dependency-complete catalogs are available;
this does not bypass missing movement/construction capabilities.

Brace+cut+finish costs9000 milli-WU and wood250/stone250 per quantum, yields2kg
earth. This deliberately preserves a material-and-labor cost even when spoil
can stay onsite. One 2m×2m×3m example costs108WU, wood3U, stone3U and yields24U
earth (24kg). Geometry clear height is an example only, not a creature-fit ruling.
Inherited tool wear accumulates1 durability per10 completed WU across all eligible
tasks; no resetting the remainder at quantum, project or worker handoff boundaries.
Each resident owns their own productive contribution/tool remainder. A project
has at most4 builders, with at most1 worker at each quantum's work face; shared
progress is never inflated per party member. Different faces may work in parallel
only where the actual support/contact geometry permits it.

The current Gear API settles a claimed job rather than every phase contributor.
The implementation must add coordinated contribution settlement: accepted WU,
XP and the contributing resident's equipped-tool wear/remainder commit together
exactly once. Job/worker replacement must not rebill old WU or bill only the last
worker. Carry the per-resident remainder across phases/cancellation, and stop new
tool-required work when durability is exhausted. Work acceptance and its tool
claim must be validated before mutation; failed settlement cannot leave one
owner advanced without the other. This is a required owner integration, not a
claim that the existing Gear API already satisfies it.

## ECON-003 — physical lifecycle and atomic boundaries

Keep the existing BuildingState enum; excavation phases are a separate typed
project/physical-site domain, not new meanings for ACTIVE or PAUSED. Required
semantic phases: SOLID, BRACING, BRACED, CUTTING, OPEN_UNFINISHED, FINISHING,
SUPPORTED_VOID, CLOSING, BACKFILLED. Compile their IDs under existing ASCII-domain
rules; any pending phase also has a distinct operational paused/blocked reason.
Job cancellation is not a terrain state. Store the physical key, original/backfill
origin, phase, earned work, funded input state, installed-support state and exactly
which quantity/output has committed. G02 supplies packed widths/capacities/version.

Transition sequence: SOLID/BACKFILLED→BRACING→BRACED→CUTTING→OPEN_UNFINISHED→
FINISHING→SUPPORTED_VOID. Support is installed at completed BRACING. The paid
brace remains in the quantum thereafter, so finish has no second material debit.
An OPEN_UNFINISHED/FINISHING volume is not a public route. Publish navigable
space only when the resulting whole posture/turn envelope is supported and the
shared topology/room/service transaction succeeds. A single cube does not
automatically admit a resident or grant a room.

Every phase validates full inputs and legal work/support contact before WORK;
consume material inputs **once at WORK start**, into project WIP. At completion,
atomically move WIP into its installed/embedded account, post any material output,
advance the physical ledger and publish eligible topology. Do not consume inputs
again at completion. On output/reservation failure, retain earned work/WIP and
phase but do not publish any part of the batch. No production WU while a blocked
phase cannot accept it, beyond the existing capped final contribution semantics.

Work.gd can mark its work job COMPLETE before an output transaction succeeds.
Therefore the site owns an explicit work-ready/commit-pending condition and an
idempotent settlement retry. Retry spends no further WU, XP, inputs or durability;
never call another productive tick on the completed job to force publication.
The same rule applies to ready backfill, salvage, compaction and reclamation.

Reserve local cut-output capacity before starting CUTTING and revalidate at
commit. Capacity is at an actual adjacent reachable ground-pile/material container,
at most one existing2m plan-tile away through an approved work contact. Publishing
the 2-U output there is part of cutting work; it does not authorize remote delivery.
No local capacity/contact means `SPOIL_OUTPUT_BLOCKED`. The ordinary ground-pile
creation order remains N,E,S,W breadth-first; a new pile requires legal terrain,
owner identity and real finite container/lot slots before use. A construction
project container is not an unlimited spoil buffer. Reserve inputs/output as one
transaction with the owning inventory APIs; no capacity credits from future work.

Dry work requires known dry substrate and structurally valid bracing/adjacent
support. Refuse a quantum intersecting water, protected bedrock/resource ownership,
an occupied/reserved space or a protected route/air exit. No silent deletion of
natural resource nodes, flooding model, ore output, unsupported shortcut or soil
type multiplier. Existing safe tool/branch recovery remains available; excavation
itself has no bare-hand fallback. G01/G02 still owe the exact geometric dry-cover,
span/work-reach and support predicates. Do not activate production cutting while
those inputs are fabricated; these rates can be tested on explicitly synthetic sites.

## ECON-004 — hauling, capacity and spoil tips

Inherited HAUL work is2WU load +2WU unload **per actual payload**, plus actual
travel. Combine compatible earth lots when their real provenance/merge rules
allow; do not force one trip per quantum or merge incompatible provenance for
free. Splitting must preserve lot quantities/reservations and charged mass
`ceil(quantity_milli*mass_g_per_U/1000)` per lot. No new blanket haul multiplier.
Equipped gear remains outside satchel under existing GDD rules; committed cargo
still affects passage/profile eligibility. Backfill inputs also require real haul.

A 24-U earth output is two12kg payloads for a small resident if no other cargo,
compatible lots and routes permit it:8WU handling total, not one8WU fee per tile.
At the inherited clear16m one-way reference, each 3277u/s leg is150 ticks and
each round trip300; two payloads require600 travel ticks +100 handling ticks at
F1000. This700-tick illustration excludes material delivery, congestion, turns,
need interruptions and path/profile readiness. It is not a measured labor forecast.
Wood3U+stone3U is30kg input mass in that example, not free delivery.

A spoil tip is a ground-overlay destination, not ordinary ready inventory or an
unlimited delete button. One existing2m×2m tile has **400000g embedded capacity**;
only `excavated_earth` is accepted. Siting requires an empty dry exterior tile,
existing building-placement slope/height rules, no water/resource/field/building,
no occupied footprint and no severed protected route/service. Preparation blocks
through travel on that tile; workers use a declared adjacent safe contact. No
stacking tips on one tile or clearing ecological soil history. Any existing ground
pile must be evacuated first, not overwritten into the tip.

Haul earth to a real adjacent input container, then KEEP compacts actual input
into a per-tip embedded-quantity ledger at the stated work price. Capacity must
reserve the full incoming quantity before WORK. Embedded earth is unavailable
to ordinary recipes until reclaimed by paid BUILD work into reserved reachable
output inventory. Reclamation debits embedded stock and creates exactly the same
quantity of earth; no new virgin-excavation yield. Its provenance is explicitly
`SPOIL_RECLAIM`, PLAIN/shelf0/NP0; compile this source kind through the catalog.
This normalization is limited to earth, never a generic food/quality laundering API.

Reclamation locks embedded stock before work and debits it only on successful
output commit. It is extraction from a world source, not consumption of delivered
inventory ingredients. Cancel releases that lock and leaves all source stock in
the tip: no80% refund and no generated loose lot. Earned work can resume only for
the same source identity/quantity contract after revalidation. Concurrent claims
cannot consume locked source stock or count it as already-freed tip capacity.

Compaction and backfill are inventory sinks into embedded world stock; reclamation
and re-excavation are withdrawals from that stock. There is **no irreversible
discard command** in this revision. Earth can remain indefinitely in ordinary
stores, be compacted or be reused as backfill. Removing/redrawing a tip designation
does not clear embedded stock or restore capacity. Reclaim it, pay the empty-tip
closure cost, then clear the obstruction. No field-fertility reset/bonus results.

## ECON-005 — cancellation, refunds, support salvage and conservation

Pause retains WIP and physical progress, releases workers and only the uncommitted
leases allowed by existing contracts. Cancel stops the project but preserves the
physical-site ledger under its stable key. A later tool rebinds that same site;
new project IDs do not reset excavation or create another earth source.

**Scoped amendment to REQ-SET-126:** for these modular excavation/tip/assistance
projects, refunds apply to each current uncommitted phase's delivered inputs.
Unstarted phases return100%; started material phases return80% per item, floor
in milli-U, and book the remaining20% as cancellation loss. Already installed
support and committed terrain changes are not refunded as loose materials.
Unused deliveries for other unstarted phases return100%, even if another quantum
has begun. Surface-building refund behavior remains unchanged.

After a started phase is cancelled, set its funded-input state empty and retain
earned WU under the site's phase. Resumption requires the **full** phase inputs
again before that retained work can advance/commit; no second refund without new
delivery. Returned lots need legal reachable capacity before cancellation commits.
If capacity is absent, retain the input WIP and show pending cancellation. This
transaction posts returned and lost quantities exactly once. For wood250/stone250,
return200/200 and lose50/50. A material-free CUTTING/FINISHING cancellation refunds
nothing, retains earned WU, and cannot repeat committed outputs.

Removal of installed support from an open void is allowed only as an evacuated
safe closure coupled to backfill. The never-cut solid case below has its own
atomic closure because no void needs filling. Installed brace+finish structural work is5WU/quantum; quarter-work
demolition is1.25WU and half-material salvage is wood125/stone125 milli-U. These
derive the GDD25%-work/50%-material demolition policy from the structural portion,
not from irreversible earth-cutting work. Even a partly finished but installed
brace uses this conservative full removal cost. No unsafe standalone support
removal. Salvage publishes only when backfill commits, never while it would leave
an exposed unsupported void. Reserve salvage output capacity alongside backfill.
Finishing removal WU records only readiness; installed support remains physically
present until the coupled backfill/salvage transaction commits. Cancellation
before that commit leaves support/void unchanged, refunds only eligible phase
inputs, and may restore the prior supported access only via a validated topology
transaction. Preserve earned closure work without publishing salvage early.

Backfill consumes earth2000 milli-U per actually open quantum. Withdraw all
occupants/items/claims and prohibit new entry before CLOSING starts; retain an
accessible work face. A supported/unfinished installed void takes1.25+3=4.25WU
to remove support and backfill. At commit: debit funded earth WIP into embedded
stock, publish125/125 salvage, mark BACKFILLED, remove obsolete service/route
access and bump topology revision atomically. A quantum never opened needs no
earth backfill. After1.25WU, its distinct UNOPENED_SUPPORT_CLOSE transaction
atomically removes installed support and publishes wood125/stone125 salvage,
with terrain remaining in its original SOLID or BACKFILLED state and no earth
debit/output. Validate support dependencies and salvage capacity first; refuse
if this brace still supports another required space or claim. Retry is idempotent.
This is the only exception to coupling support salvage to backfill commit. No
invented spoil output from support removal.

Re-digging BACKFILLED uses exactly the original brace/cut/finish prices and
withdraws2000 milli-U from its actual embedded earth; it is not a new geological
source. CUT commit chooses exactly one branch: virgin terrain increments the
virgin-source ledger by2000; BACKFILLED terrain decrements embedded earth by2000.
Both branches create only one2000 output lot quantity. The latter branch never
increments virgin sources or posts a second output. Uncommitted backfill input
refunded/cancelled never becomes embedded.
Track virgin excavation source separately from reclamation/transfer. The global
identity is: initial earth + virgin sourced = inventory + earth WIP + backfilled
earth + tip earth + declared cancellation loss. Installed support, material WIP,
salvage and losses have their own wood/stone identities. Transaction refusal
changes none of these accounts. Do not conflate game recipe transformation
with physical mass conservation across wood, stone and earth.

## ECON-006 — required arithmetic and transaction fixtures

- One quantum: brace2+cut4+finish3=9WU, wood250/stone250 milli-U, earth2000 milli-U.
  2×2×3m example:12 quanta,108WU, wood3000/stone3000 andearth24000 milli-U.
- With one F1000 worker and no other modifiers, brace25 ticks,cut50 ticks,
  finish38 ticks:113 ticks/quantum or1356 for12 serial quanta. Phase caps discard
  unaccepted final work; do not claim1350 aggregate ticks without carrying work
  into another phase. Shared work carries/XP follow the existing work owner.
- Full400000g pile refuses another2000g cut output. Free2000 accepts;free1999
  refuses. Full tip refuses compaction without removing input or claiming WU.
- Two actual small-resident24kg haul payloads:8WU handling,700 conditional ticks
  for the clear16m round-trip fixture. Mixed lots and added cargo can increase trips.
- Cancel a started brace:250→200 returned+50 lost per material; no installed
  brace appears. Resume with250 new inputs each; previously earned work remains.
- A never-cut braced solid closes after1.25WU/16 base ticks and125/125 salvage,
  without earth debit/output. Missing salvage room or a dependent support claim
  refuses atomically; duplicate closure cannot generate salvage again.
- A supported quantum backfills with2000 earth,4.25WU and125/125 salvage. At
  F1000, staged removal16 ticks + backfill38=54 ticks. Re-dig releases only that
  same embedded2000 earth. Repeated cycles never increase total available+embedded
  earth beyond recorded virgin sources, nor wood/stone beyond input+salvage rules.
- Tip compaction/reclaim of8000 milli-U costs2000/4000 milli-WU;400000 milli-U
  fills a tip exactly. Missing capacity, stale site generation, duplicate commit,
  cancel/redraw, occupied backfill and saved half-finished work all preserve accounts.
- Work-ready output retry changes no WU/XP/durability and commits once. Cancelled
  reclamation retains all embedded source stock and creates no refund lot. WorkerA
  contributes6WU andB4WU: neither incurs wear yet; A's later4WU incurs1 durability
  forA alone, whileB retains4WU. No final-worker attribution or cancellation reset.

## HAZ-001 — authored hazard policy and existing owners

These are new engineering balance values under DEC-040, adopted for implementation
and iteration; they are not user-supplied measurements or a claim of balanced play.
Use integer state and existing GDD InjuryKind: NONE=0, CUT=1, BITE=2, FALL=3,
EXPOSURE=4, EXHAUSTION=5. No new injury-kind enum or combat system is introduced.
The earlier request review incorrectly said the complete kind domain was absent:
GDD §4.3 already lists it. The missing part is the aggregate Injury/care runtime.

No new random disaster or injury rolls are added by this package. Completed dry,
supported tunnels do not randomly collapse, flood or injure travelers. Excavation
requires bracing before cutting; unsupported or water-intersecting cuts refuse.
This retains the GDD's exclusion of additional random disasters. Actual risk in
this package comes from finite air, exhaustion, loss of consciousness and falling
from declared unprotected climbing routes. An ignored warning can still lead to
death through the rules below; prevention is not immunity.

`dangerous` is derived from the action: DIVE, SWIM_SURFACE and unprotected CLIMB
are dangerous; protected CLIMB, supported dry excavation and ordinary completed
ground/ford/tunnel walking add no hazard flag of their own. A dangerous work job
still uses resident dangerous-work consent and existing priority prohibitions.
Routine movement cannot route through a dangerous connection without the same
resident consent; explicit movement does not bypass it. No consent overrides
missing capability, unsafe return, clearance, injury exclusion or PC-04 child rules.
This classifies actions, not species: no profile or training ability is granted here.

New deliberate entry to dangerous travel requires health >=70, hunger >3500,
rest >=4000, no active untreated injury, known complete movement/profile/cargo
contract and the resident's consent. Check again at edge entry, not just job issue.
Retreat and rescue from an already occupied edge are not blocked by the failing
entry test. Ordinary supported travel retains existing health/activity rules.
CHILD hazardous work/excavation stays forbidden; CHILD/ELDER activation awaits
PC-04 and explicit profiles, without adult fallback or an invented elder penalty.

## HAZ-002 — air and dive arithmetic

Every newly enabled budget-limited dive profile binds `air_standard_v1` below
explicitly. This budget is a game rule, not measured animal physiology. It applies
only after the owner separately enables that species/stage/posture's dive profile.
No species is implicitly assigned the mode or an exceptional breath multiplier.

| Parameter | Exact value | Provenance |
|---|---:|---|
| Full air | 1200 air units | NEW |
| Consumption | 1 unit per submerged fixed tick | NEW |
| Recovery | 4 units per fixed tick at a valid breathable location; cap 1200 | NEW |
| Required contingency | 300 ticks beyond complete planned underwater duration | NEW |
| Low-air advisory | remaining air <=450 | NEW |
| Airless additional health drain | 125 health/game-hour | NEW; 1 per 6 ticks in isolation |
| Injury on transition to airless | EXPOSURE, severity 2, immediate health loss 0 | NEW binding to inherited kind/severity |

Available air persists between trips; no refill on assignment, cancellation,
new job, save/load, a camera change or acquiring a different profile. Recovery
requires actual airway access, not merely sharing X/Z with surface water. On a
tick starting submerged, charge exactly one unit, even if the tick ends at air;
recovery begins on the next tick starting at breathable support. At air=1, the
last unit covers that interval. At air=0 at the start of a still-submerged tick,
apply the airless interval rules for that entire interval, including one that ends
at breathable support; recovery starts next interval. Entry begins charging on the first interval
whose starting occupancy is submerged. All path budgets must use this convention.

Admission requires `available_air >= T + 300`, where T is the complete number
of submerged ticks through entry, outbound travel, underwater work if any,
permitted waiting, return and exit. Costs come from the actual profile, geometry
and committed load; zero placeholder durations are invalid. Planned underwater
queue waiting is **0 ticks**: reserve the full conflicting corridor and breathable
landing before entry or wait in air. Emergency delay consumes the contingency.
No input allows infinite/unknown waiting to masquerade as zero.

At every submerged boundary compute a bounded, already-protected return duration
B from current progress, including edge reversal/finish and air access. Trigger
return when `remaining_air <= B + 300`, or when hunger <=3500, rest <=1500,
health <70, injury, cancellation or a future route revision requires it. Equality
triggers return. No new underwater work starts after that trigger. A route with
no validated protected return is inadmissible, not a gambling option. If an
unexpected runtime condition removes that return, retain location/air, mark
DISTRESS and dispatch rescue; do not teleport or restore air.

Warnings show both remaining air and required return+reserve, with an action to
return. At <=450 air show the low-air warning even if already returning. If air
is exhausted, create one EXPOSURE incident for that continuous airless episode;
do not add an injury every tick. Airless damage applies exactly when an interval
starts submerged with air0. Reaching breathable support ends it for the next
interval; the injury remains
until existing treatment completes. A subsequent airless episode is a distinct
incident, not a reset of untreated damage or care history.

Combine the new -125/hour drain with needs, cold and untreated-injury rates in
the single health owner, retaining the existing signed denominator-750 remainder.
Never run separate rounded health clocks. With untreated severity 2 and no other
rates, total drain is 129/hour. At health100/remainder0, 6 airless ticks leave99,
495 leave15 (incapacitated), and582 reach0. Those are conditional arithmetic
fixtures, not a guaranteed rescue window or survival forecast. Existing recovery
is barred by untreated serious injury. Existing cold/exposure remains separate;
submergence alone does not fabricate a cold-weather modifier.

## HAZ-003 — exhaustion, fall protection and declared recovery routes

Any active dangerous crossing requests the protected safe return at rest <=1500,
hunger <=3500, health <70 or new injury. At rest <=500, defer floor sleep until
reachable dry support. Continue only the supported return/recovery, not ordinary
work. Mark DISTRESS if self-return is impossible and create a rescue request.
DISTRESS is movement recovery state, not a fabricated health-based incapacity.

At rest0 while still in water or on a climb, apply one EXHAUSTION severity1
incident with zero immediate health loss and stop self-propelled swimming/climbing.
Re-arm this incident only after rest recovers to4000 at safe support. Conscious
surface floating and protected hanging use their declared hold pose; underwater
distress continues consuming air. On an unprotected climb, rest0 is loss of grip
and triggers the same declared fall as incapacity. The rest1500 return warning
and rest500 distress warning precede this threshold. Ground safe sleep is not
an exhaustion injury. These are new exact recovery rules, not adult needs-rate
substitutions or permission to enable an unprofiled life stage.

A conscious surface swimmer can use only the profile's declared floating/return
posture; that pose is required before enabling SWIM_SURFACE. If incapacitated
while in water without a supporting rescue attachment, transition to submerged
distress and consume retained air using HAZ-002. There is no automatic immunity
or species exception. A surface swim profile therefore needs the same airless
recovery contract even when voluntary DIVE is disabled. This does not grant dive
capability: involuntary submergence is a recovery phase, not a permitted journey.

A CLIMB connection declares one of two recovery cases:

1. **Protected:** a built, fixed assistance sling/line and supported rescue contact
   can retain an unconscious occupant without a fall. Build cost per started
   4096u of authored connection arc length: wood1000, rope2000, cloth1000 milli-U
   and40000 milli-WU BUILD; M0, general tool required. It is installed connection
   equipment, not newly spawned portable harness inventory. Capacity is one
   traveler; validated rescue approach is additional and separately represented.
   Removing it refuses while occupied or while it protects any committed return.
   It has no random breakage or passive durability drain in this revision.
2. **Unprotected:** the catalog provides a generation-checked supported fall
   landing, an integer recovery trajectory and its vertical drop D>0. No landing
   means the connection refuses activation. On incapacity or rest0, stop ordinary
   progress and execute that recovery
   trajectory; no invented physics impulse or snapping to a nearby floor.
   Recovery duration `max(1, ceil(D*30/4096))` ticks. At touchdown apply FALL with
   health loss `min(40, ceil(D*8/1024))`; severity1 for D<=2048, severity2 above.
   Display this exact consequence before entry. Death before touchdown still
   retains the trajectory/body/cargo ownership until the landing is resolved.

Protected recovery needs measured body/cargo/support compatibility and actual
attachment/clip evidence; a boolean alone cannot certify safety. Unprotected
climbing's configured risk is deterministic, not a per-frame/random fall roll.
This package adds no other grip-loss trigger or grip-decay formula. No free-flight,
branch-gap jump, flood simulation or player support-removal exception is added.

At touchdown a surviving conscious resident uses safe support and requests care;
an incapacitated survivor needs carrying rescue. Injury remains even if walking
home is possible. Death uses existing chronicle/grief/burial/cargo behavior.

## HAZ-004 — rescue, treatment and concurrent injury rules

Rescue requests use existing urgency bucket0 and respect eligible-rescuer priority,
consent and route safety. No hidden worker assignment overrides priority0. Show
the existing Enable safe survival jobs action when assignment is prohibited.
One eligible rescuer can carry one patient per REQ-SET-171. Pickup requires
8000 milli-WU HAUL, set-down4000 milli-WU HAUL; these are NEW handling work,
separate from inherited treatment. Rescue approach is normal legal travel;
carrying speed is exactly half the rescuer's eligible profile speed (retain the
rational speed remainder; do not truncate an odd u/s cap). No work accrues in transit.

The patient is a generation-checked carried-resident relationship, not an item or
a fake mass in the ordinary satchel. Require the explicit combined rescue envelope
for each connection. Set down the rescuer's own ordinary cargo at a legal reachable
container before pickup; refuse without output capacity. The patient's actual
cargo stays owned by the patient and counts in the combined envelope/load contract;
never destroy it or count it twice. A protected airway during carrying is a
declared rescue-profile property; otherwise underwater air continues to run for
both people. One rescuer cannot pull an unconscious person through a merely
self-swimmable route. Missing rescue-profile compatibility is a real blocker.

Default destination is a reachable bed; if none is available, use a reachable dry
field-care landing, then continue existing treatment there. For an immediately
threatening underwater/hanging state, prefer the least-travel-tick compatible
safe landing before onward bed transport; ties use persistent owner ID then
contact key. Reserve pickup access and set-down capacity together before moving
the patient. The occupied edge must expose a separate safe rescue approach so
rescue cannot deadlock waiting for the patient's own occupancy to disappear.
No route means a persistent blocked rescue, patient location and cargo marker.

For underwater pickups charge pickup work's actual ticks against each person's
air, including all work factors; do not substitute a nominal 100 ticks if the
rescuer is slowed. Planned rescue must fit the rescuer's full protected round
trip budget. The patient's remaining time/rates are shown as conditional urgency,
not a false guarantee. A conscious stranded resident may self-return only through
an eligible supported route; an unconscious last resident cannot self-rescue.

Aggregate injury keeps maximum active severity. If equal-severity incoming kinds
conflict, retain the lower InjuryKind ID deterministically. Untreated damage is
1/hour for severity1 or4/hour for severity2, not one copy per incident. A new
incident does not erase untreated elapsed time, remainders or already paid care
work. Genuine one-shot health events still apply once each; deduplicate by incident
identity/event ordinal. Severity escalation immediately selects the new future
rate. Existing treatment consumes herb1000 + cloth500 milli-U and60000 milli-WU
HEAL, clears the aggregate injury and restores10 health (cap100). Conscious
last-resident self-treatment is120000 milli-WU. No treatment work in active water,
on an unsupported climb, during falling or while being carried.

Derive exposure episode transitions from the interval's starting state, then
accrue rates once. Health0 commits death immediately before any later action.
Resolve movement/touchdown and other declared one-shot hazard events for the
remaining living actors; again commit any resulting death immediately. Only
a still-living patient may receive permitted completed care. Finish the remaining
lifecycle bookkeeping once. A dead body's physical recovery trajectory may
continue, but later care or damage calls cannot resurrect or kill it again.
Calls into needs must not let ordinary need recovery run in addition to a
separately integrated hazard/care health loop. G02/task08 must bind this sequence
to current scheduler phases and save every future-affecting incident/claim field.

## HAZ-005 — interruption matrix, UI and save obligations

| Trigger | Ground/ford/completed tunnel | Surface swim/dive | Protected climb | Unprotected climb |
|---|---|---|---|---|
| Cancel, meal/rest diversion | Stop at valid supported boundary; keep position | Commit safe return, consume air as occupied | Finish/retreat to protected landing | Follow declared supported retreat, never step off |
| Rest<=500, conscious | Safe floor sleep only at valid dry support | DISTRESS if no self-return; no water sleep | Protected hold/return; rescue if needed | Declared retreat/hold; rescue if no self-return |
| Incapacity | Retain body, rescue | Supported airway or submerged distress+air rules | Hold in installed support; rescue | Declared recovery fall, then rescue if alive |
| Death | Chronicle/body/cargo once | Body/cargo remain at actual domain/contact | Retain supported body until recovery | Finish declared body trajectory; no resurrection |
| Profile/load revision | Revalidate before next edge | Frozen committed recovery semantics; reject new edges | Same; no mid-edge gear swap | Same; preserve declared landing |
| Player topology deletion | Refuse occupied/last-exit removal | Protect full return and air landing | Protect sling, route and rescue access | Protect landing/return; no crushing edit |
| Unexpected lost destination | Wait/replan at support | DISTRESS; preserve air and occupancy | Hold+rescue | Use declared recovery; never invent a landing |

While in occupied recovery, ordinary reservation expiry/cancel does not erase
the physical occupant. After death, logical jobs/leases release once as GDD
requires; a body/debris topology occupancy record protects the remaining geometry
until physically recovered. Releasing a job is not removal of a body.

Use the existing route/alert/detail surfaces. Show Planning, Waiting, Incompatible,
Returning to safety, Rescue needed and Rescue blocked with reason text. Do not
invent numeric controls/geometry in this package; G03 still owns final UI registry.
UI-SET-049 must show deterministic thresholds/consequences for these actions,
not a fabricated “chance per10000 cycles.” Preserve that probability wording for
existing probabilistic fishing/forage work. First incapacity uses existing critical
auto-pause settings; this package adds no new auto-pause trigger. Warnings remain
visible when acknowledged while the underlying condition persists.

Air values are fixed ticks/units. UI can express duration at1x and the current
requested speed, clearly labeled;1200 ticks is40 seconds at1x,10 at4x and1.6 game
hours. Paused time is frozen. Save air, incident identity/latches, committed recovery
trajectory/progress, profile/revision, rescue relationships, cargo/claims, injury
severity/care progress and all shared remainders. Every-tick replay must agree.

## HAZ-006 — required independent fixtures

- Air admission: available1200,T900 accepts; T901 refuses. Available1199,T900 refuses.
  Remaining600,B300 requests return at equality.1200 submersion ticks consume full
  air without an airless interval; the following still-submerged tick begins it.
  From air0,300 breathable ticks restore1200; from1199 one tick caps at1200.
  A tick starting submerged/air0 but ending at air still takes the full airless
  interval drain; its next interval recovers air and takes no airless drain.
- Shared health integration: health100/remainder0, untreated severity2 and airless,
  no other rates: after6/495/582 intervals health99/15/0. At health15,88 intervals
  at129/hour reach0. Test nonzero initial remainder, cold addition, and no recovery
  while seriously injured. No claim these values describe every rescue scenario.
  Lethal interval or touchdown damage before same-tick care leaves the resident
  dead and produces exactly one death; a completed treatment cannot undo it.
- Falls: D1024 =>8 health, severity1,8 ticks; D2048 =>16, severity1,15 ticks;
  D4096 =>32, severity2,30 ticks; D8192 =>40, severity2,60 ticks. Check one-shot
  delivery at touchdown and death during falling. Protected incapacity does not fall.
  Rest1500 requests return;rest500 requests supported recovery;rest0 unprotected
  climb falls, protected climb holds, and water enters the declared distress pose.
- Assistance equipment: arc4096 costs wood1/rope2/cloth1 U and40WU;4097 costs
  wood2/rope4/cloth2 U and80WU. This modular cap is a build-cost rule, not depth adoption.
- Rescue: pickup100 and set-down50 ticks at F1000 (0.08WU/tick), excluding travel.
  Odd3277u/s at half speed travels3277u in60 ticks. Changing helpers retains WIP;
  cargo has one owner; missing combined envelope, full landing or stale patient refuses.
- Interruption matrix at speeds0/1/2/4, save/load at every phase, and actual low-health
  player-warning scenarios. Synthetic coordinates establish algorithms, not measured
  creature clearance or completed movement/visual/performance gates.

## Completion and remaining dependencies

This package supplies the previously missing excavation/spoil accounting values,
scoped cancellation/refund rules, air/exhaustion/fall consequences, rescue handling
prices and warning thresholds. It also corrects the earlier InjuryKind-domain
audit error without hiding that history. It establishes specification targets and
independent arithmetic/account fixtures, not measured game behavior.

Still required before full connected production: actual species/stage/body/gear
profiles and mode costs; adopted world/depth/water/canopy bounds; structural/dry
cover/work-contact geometry; actual entrance/stair/template recipes; G02 capacities,
all scratch and save/load peaks; source/lot/tool/work transaction integration;
aggregate Injury/care runtime and PC-04; G03 registered UI; G04 recovery clips and
measured attachment envelopes; G05 runtime/replay/performance evidence. An economic
cube or a recovery formula is not a measured body fit or a completed save schema.

No existing tests may be marked passing solely because this document exists.
Run `python3 docs/validation/validate_underground_economy_hazards.py` from the
repository root for the independent arithmetic/account checks. Read its actual
[result](validation/underground_economy_hazard_results.json). The oracle deliberately
does not assert Godot state, full save parity, survival trajectories or hardware
qualification. These must be tested by the implementation lanes below.
