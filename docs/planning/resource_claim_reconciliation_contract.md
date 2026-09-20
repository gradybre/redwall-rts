# Read-only resource claim reconciliation

SAVE-CLAIM-CHECK-R01 · version2 · Astra · 2026-09-19. Accepted after independent review disposition.
Follows SAVE-CLAIMS-R01v2 and FISH-ID-R01v2. Does not provide complete saves.

## Scope and input boundary

Implement a pure checker in `godot/scripts/core/save_resource_claims_reconcile.gd`.
It compares exact section7 claim blocks with caller-owned immutable projections of
saved section4 and a section3 Directory record plus section1 next-PID cursor.
These new projection classes are a deliberately bounded NEW interface, not a claim
that the absent section4 codec or a world coordinator already exposes them.

The checker must be independently implementable before that codec. A separate
SAVE-CLAIM-WORLD-BINDING task owns production projection from the complete decoded
file, actual descriptor version checks, file/world identity, and coordinator
invocation before publication. Full activation depends on that task, section4,
owner capture/apply and normal gameplay cleanup integration. A made-up binding
token does not prove common provenance and is not part of the checker API.

The caller supplies the same validated file's records and must prevent mutation
throughout the synchronous call. No await, callback, dispatch, live store access,
rebind, persistence I/O, tick, allocator admission or borrowed binding is involved.
The checker proves consistency of the values supplied, not their file origin.

Exact API:

`static func validate(directory: SaveSectionDirectory.Record, next_persistent_id: int,
 fishing: SaveSectionInventories.OwnerRecord, forage: SaveSectionInventories.OwnerRecord,
 components: Components) -> Result`

Components has typed members `fish:FishComponents`, `forage:ForageComponents`,
`jobs:JobComponents`; its constructor creates all three. It holds three caller-owned records. Every array has its full compiled
extent; no variable-size admission, Dictionary or Object.get property access in the
checker. Constructors allocate cold buffers once and set present/amount/generation
zero and ref slots−1. No per-entity object exists.

- FishComponents: habitat_present:u8[32], habitat_ref_slot/ref_generation:i32[32],
  habitat_effort_slots/habitat_effort_used:i32[32]. Bytes544.
- ForageComponents: zone_present:u8[128], zone_ref_slot/ref_generation and
  zone_basin_slot/basin_generation:i32[128], zone_quota_reserved_milli:i64[128];
  patch_present:u8[640], patch_zone_slot/zone_generation:i32[640]. Bytes8960.
- JobComponents: job_present:u8[8192], job_ref_slot/ref_generation:i32[8192],
  created_tick:i64[8192]. Bytes139264.
- Total projection value payload148768 bytes, caller-owned cold scratch. The
  omitted section4/5 fields remain the full owner's structural/semantic validator's
  responsibility. Do not pretend this projection validates complete owner records.

Result has `code:StringName`, `detail:String`, `owner:StringName`,
`row_space:StringName`, `row:int`,
`fishing_count:int`, `forage_count:int`, `stale_fishing_expeditions:int`,
`stale_fishing_jobs:int`, `stale_forage_jobs:int`, and `is_ok()->bool`.
On refusal counts are zero and owner/row identify the first offending claim or
component row; a preflight error uses owner/row_space empty and row−1. On success
code=SaveHeader.REFUSE_NONE (the existing empty StringName), detail empty,
owner/row_space empty and row−1, and all counts are computed. Never publish partial
counts on refusal. Result is new per call, not stored on any owner.

## Mandatory preflights and identity

Deterministic gate order: null inputs including three component subrecords; every
component array extent; section7 block identity/shape for Fishing then Forage;
Directory structure/cursor; section7 codec domains for Fishing then Forage; all component local domains and live
mirrors; active Fishing rows ascending; active Forage rows ascending; all Fishing
aggregate rows ascending; all Forage aggregate rows ascending.

Use exact existing owner shapes (fishing index0/schema2/eight fields/512,
forage index1/schema1/eleven fields/8192). Refuse wrong owner/primary/child shapes
before any mapping, reusing the existing resource adapter
`fishing_block_shape_refusal`/`forage_block_shape_refusal` statics. Preloading their
scripts and immutable constants is allowed; instantiating a live store or calling
its mutators is not. There is no duplicate shape gate or helper move in this lane.
Use named codec owner constants (currently0/1). OwnerRecord itself has no wire
schema scalar: actual descriptor/wrapper versions must have passed decode and
WORLD-BINDING owns that precondition. Reuse codec.owner_refusal but never apply/capture or call the
legacy validators/rebuilders. Enforce the stronger existing exact owner quantity
bounds: Fishing1..6, Forage1..1180000, derived from current constants. Counts in
the caller's live stores are not inputs and cannot be rewritten.

Privately allocate one SaveSectionDirectory.Derived and call
`SaveSectionDirectory.rebuild_into(directory, private_derived)`; do not mutate or borrow a caller Derived.
Validate next-PID using the existing identity contract:1..2147483648, strictly
above every live persistent ID; the terminal value means exhausted. Preserve
underlying Directory refusal codes; add checker codes for its cursor failures.
Do not install that Directory into any live store. Its rebuilt reverse map is the
same ARCH-ID-003 predicate used for every live reference: bounds, active,
generation, expected kind, typed range and reverse owner, without reconstructing
an owner reference from a claim's typed row.

Local component gates: occupancy0/1; active SELF identity full-pair mirrors the Directory
of the proper kind and exact typed row. Also walk every live Directory entry of
Habitat/HarvestZone/Job kind to ensure the matching component row is present and
mirrors it. This is a bijection for those THREE kinds, not only a forward check; no Expedition
component exists or is invented. This does not require every zone to own patches. Inactive row refslots−1 and generations0. Inactive Job tick and zone reserved
are zero; inactive Fish used is zero, but effort_slots may retain its prior valid
capacity after ordinary destroy_habitat. Accept0..6 there, without normalizing it.
Present Fish effort capacity1..6, used0..capacity; present zone reserved>=0;
present Job created_tick>=0.
A present zone
basin pair has a bounded Directory slot and positive generation but need NOT
resolve if the zone has no active claim: ordinary basin deletion leaves surviving
designations with stale basin refs. Claimed zones have the stronger rules below.
A present Forage patch must have a present owning zone at row/5 and its saved zone
pair must exactly mirror that owner. Empty patch refs−1/0. A zone may have one
patch or any subset; never require all five patches. Global owner-specific domain
rules omitted by these projections remain separate validation prerequisites.

For mandatory ECOLOGICAL refs on active claims, require a fully live correctly
kinded/mirrored habitat/zone. A missing ecology ref refuses even when another saved
aggregate is zero. Ordinary destroy_zone releases claims naming it as EITHER
basin or designation before deleting it; destroy_habitat refuses held effort.

For an active claim's owning Job/Expedition pair, distinguish exact live ownership
from dead historical ownership. Structurally out-of-range/zero generation is already
refused. If claim generation exceeds that Directory slot's saved generation, refuse
impossible future provenance. Otherwise an inactive slot or an older generation
is stale, preserved and counted; current slot kind is irrelevant to an older pair.
If the pair is fully live, wrong kind or typed-row association refuses. Valid live
Job identity must also have the matching component present. Directory generations
increment on allocation/reuse, never on destroy; inactive same-generation is a
legitimate dead owner, including the terminal retired generation.

## Claim rules and totals

Every active Fishing row has one exact Expedition pair, one Job pair and one
habitat pair. Its LIVE Expedition must have Directory typed_row equal to the claim
row. A stale Expedition and/or Job is permitted and contributes its full saved
amount to the habitat total; increment the two stale counts independently. A live
Job need not be a coordinator or non-member now: public membership can change after
admission. No live Job state restriction; cancellation may precede normal release.
Use checked int64 addition for private per-habitat totals, then compare all32 rows
with total == saved habitat_effort_used AND total <= habitat_effort_slots. Free rows
must have zero; no claim may name them. No canonical total or scratch is repaired.

Every active Forage row has a Job pair; if live, its typed_row must equal the claim
row. Saved created_tick must equal that live Job's created_tick, and saved PID must
equal the Directory PID. The public writer takes claim row directly from the Job
row; these are valid provenance checks, not a rewrite. Even a dead owner retains
a formerly positive signed-i32 PID less than the same world's next-PID cursor.
Reject saved PID0, >2147483647 or >=next-PID for ANY active claim. Dead Job tick
cannot be re-derived: preserve its nonnegative value; do not guess it from a reused
row. Do not impose created_tick<=world_tick because this checker lacks that input
and no such admission bound has been established by this lane.

Resolve both saved ecological refs to present zones. The designation's saved basin
pair must equal the claim's saved basin pair. That basin must be self-bound. The
particular patch at basin_row*5+saved_patch_kind must be present and mirror the
basin. Public admission needs that patch, basin rebind refuses any owned patch,
and deletion releases claims before removing patches. Do not require all kinds.

Checked-add remaining_milli to private basin total; also add to designation total
if its RESOLVED ROW differs. Count exactly once when equal. Compare ALL128 saved
zone_quota_reserved_milli values, including zones with no matching claim, to totals.
Do not test current seasonal quota, enabled/protected state, stock/floor, membership
or cancellation as save refusals: normal deferred gameplay reconciliation owns
those conditions. No amount trimming, key refresh, quota reconciliation or purge.

Stale classification is diagnostic. The exact retained claim is already the state
normal purge/release methods scan; no new persistent deferral list or flag is needed.
Those methods currently lack a composed runtime caller. SAVE-CLAIM-WORLD-BINDING
and normal gameplay integration must ensure cleanup resumes in the same ordinary
stage as an uninterrupted world. The checker must never call cleanup on load.

## Failure and allocation contract

New checker-specific codes: CLAIM_CHECK_NULL, CLAIM_CHECK_SHAPE,
CLAIM_CHECK_CURSOR, CLAIM_CHECK_COMPONENT, CLAIM_CHECK_IDENTITY,
CLAIM_CHECK_FUTURE_REF, CLAIM_CHECK_ECOLOGY, CLAIM_CHECK_PROVENANCE,
CLAIM_CHECK_QUANTITY, CLAIM_CHECK_OVERFLOW, CLAIM_CHECK_TOTAL.
Underlying Directory and section7 codec refusals retain their exact code. New
failures have nonempty deterministic detail; owner/row localizes the first failure.
Within a claim inspect owner pair, Job pair, ecological pair(s), provenance,
quantity, then checked accumulation; applicable earlier gates win. For Forage the
owner pair IS the Job pair and is checked once. Stronger checker quantities run
after codec domains; e.g. Fishing zero quantity is the codec refusal, while Fishing7 or
Forage1180001 produces CLAIM_CHECK_QUANTITY if earlier gates are valid.

Every supplied byte and all caller/live state remain unchanged on success AND
refusal. No use of old Fishing validate/rebuild_effort_aggregates or Forage
rebuild_reservation_aggregates: they mutate count, scratch or canonical data.
One private Directory Derived costs1409816 packed bytes; int64 totals32+128 cost1280.
The existing validator also duplicates generation and persistent_id for sorting,
each1409672. They are sequential locals, but conservatively charge BOTH in this
call allocation bound:1409816+1280+2*1409672=4230440 packed bytes, plus caller
projection148768 and already owned input records. This is a conservative bound,
not measured RSS. Native objects/Array[int] wrappers/Refusal/detail strings are
separately unmeasured. No clone of the entire Directory record or claim arrays,
no second mutable world or new resident budget. The validator's two permitted
single-column copies must not be confused with the prohibited full-record clone.
Max sums3072 and9666560000 cannot overflow i64 under admitted domains; checked math
is nevertheless required. Do not manufacture a public overflow witness.

## Required evidence and dispatch gates

Astra owns independent literal mapping tests, public lifecycle witnesses and metadata;
Claude authors bounded implementation and independent source/contract review.
Tests must cover healthy live and stale states, both identity-reuse cases, wrong
kind/typed row, future generation, every ecological relation above, live tick/PID
mismatch, PID0 and upper/cursor bounds for live/dead owners, all-shape/null refusals,
zero-claim nonzero totals, missing expected totals, designation==basin once, all
maxima, both stale counts, unchanged inputs on every refusal and success, and normal
cleanup matching uninterrupted continuation. Public lifecycle fixtures already
prove7tests/95assertions; they do not validate this unimplemented checker.

Mutants: skip live provenance comparison; skip zero-claim aggregate rows; count
equal designation/basin twice; reinterpret stale owner through reverse mapping.
Add a fifth mutant omitting the reverse Directory-to-component walk. Each must
fail a meaningful assertion with executable sources exactly restored.
Full suite,15static,editor,independent review and exact-head CI before checker merge.

Queue split must retain a blocked SAVE-CLAIM-WORLD-BINDING dependency on section4,
complete owner validation/capture/apply and coordinator. Its producer maps EXACT
field ordinals from accepted registry and versions; it must not take live values
from another world. The pure checker alone may never mark release_save_ready,
SAVE-CAPTURE, SAVE-ORCHESTRATOR or first-playable acceptance complete.

## Exact diagnostics and remaining test details

| Gate | Code | owner / row_space / row |
|---|---|---|
| Any null participant/subrecord | CLAIM_CHECK_NULL | empty / empty / −1 |
| Component extent | CLAIM_CHECK_SHAPE | empty / empty / −1 |
| Claim block shape | existing SAVE_CLAIMS_BLOCK_SHAPE | empty / empty / −1 |
| Directory rebuild | original SAVE_DIR_* code/detail | empty / empty / −1 |
| Cursor domain or <= any live PID | CLAIM_CHECK_CURSOR | empty / empty / −1 |
| Codec owner domains | original SAVE_INV_* code/detail | empty / empty / −1 |
| Component occupancy/value/inactive blank | CLAIM_CHECK_COMPONENT | fishing/forage/jobs / habitat/zone/patch/job / row |
| Component self-reference not exact live proper-kind row | CLAIM_CHECK_IDENTITY | owner / component space / row |
| Directory reverse walk lacks matching component | CLAIM_CHECK_IDENTITY | owner / directory_slot / Directory slot |
| Owning Job/Expedition generation exceeds Directory generation | CLAIM_CHECK_FUTURE_REF | fishing/forage / claim / row |
| Fully live claim owner wrong kind/typed row or component | CLAIM_CHECK_IDENTITY | fishing/forage / claim / row |
| Claim ecological ref, basin association, specific patch mismatch | CLAIM_CHECK_ECOLOGY | fishing/forage / claim / row |
| Forage PID domain/cursor or live tick/PID mismatch | CLAIM_CHECK_PROVENANCE | forage / claim / row |
| Stronger residual claim quantity | CLAIM_CHECK_QUANTITY | fishing/forage / claim / row |
| Checked sum fails | CLAIM_CHECK_OVERFLOW | fishing/forage / claim / row |
| Saved aggregate != total or total > habitat capacity | CLAIM_CHECK_TOTAL | fishing/forage / habitat/zone / row |

Component domain order is Fish rows, Forage zones, Forage patches, Jobs, then
reverse Directory slots ascending; inspect occupancy, self-ref shape/identity,
then values in each row. Claim-independent present patch/zone mirror mismatch
is CLAIM_CHECK_COMPONENT at that patch row. Within each relevant pair, impossible
future generation precedes exact-live wrong-kind classification; stale ownership
is allowed as specified, never a reason to skip ecology or quantity checks.
Forage PID lower/upper/cursor bounds precede live PID then live tick comparison.
The existing source constants—not guessed quota math—own quantity bounds: Fishing
EFFORT_SLOTS_BY_TYPE=[6,6,4] in COAST/LAKE/RIVER order, max6; exact Forage owner validator already enforces
MANUAL_QUOTA_MAX_MILLI1180000 under accepted SAVE-CLAIMS-R01v2. This checker must
match that accepted owner contract; it is not reopening admission balance.

Private static `_checked_total_into(current:int, amount:int, out:IntMath.IntResult)
->bool` delegates to IntMath.checked_add_into. Unit-test it directly with synthetic
INT64_MAX+1 and a distinct ordinary sum, labeling those arithmetic-unit tests.
Every accumulation calls it and maps false to CLAIM_CHECK_OVERFLOW. This guarded
code is unreachable through admitted full-table quantities; neither the helper
test nor forged input is a public overflow reproduction. Existing IntMath mutation
coverage remains relevant; do not weaken quantity bounds to reach the guard.

Tests must explicitly cover absent component for live Directory Habitat/Zone/Job
(reverse walk), an unrelated Directory refusal passed through unchanged, inactive
habitat retained effort capacity after public destruction, and present claim-free
zone with stale basin pair after public basin destruction. No timestamp/identity
writer is changed to satisfy this checker. This contract proves its listed local,
live-provenance, stale-domain and aggregate predicates; reconstructing the historical
owner behind a dead pair from a history that was never stored is not claimed.

Exact new field spellings (no stored underscore prefix):
FishComponents=`habitat_present,habitat_ref_slot,habitat_ref_generation,habitat_effort_slots,habitat_effort_used`;
ForageComponents=`zone_present,zone_ref_slot,zone_ref_generation,zone_basin_slot,zone_basin_generation,zone_quota_reserved_milli,patch_present,patch_zone_slot,patch_zone_generation`;
JobComponents=`job_present,job_ref_slot,job_ref_generation,created_tick`.

WORLD-BINDING depends on the implemented coordinator and section4. To avoid a
circular graph, SAVE-CAPTURE/final activation depends on WORLD-BINDING; coordinator
implementation may precede binding but must keep external-file publication gated
until it is integrated. Implementing a coordinator does not itself close this gate.

Forage zero amount, unlike Fishing zero slots, is admitted by the existing codec
and refused by the checker's stronger CLAIM_CHECK_QUANTITY gate. This distinction
is explicitly tested; no codec schema/domain change is made.
