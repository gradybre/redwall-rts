# Read-only resource claim reconciliation

SAVE-CLAIM-CHECK-R01 · draft1 · Astra · 2026-09-19. Not accepted for implementation.
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

Exact proposed API (subject to independent contract review):

`static func validate(directory: SaveSectionDirectory.Record, next_persistent_id: int,
 fishing: SaveSectionInventories.OwnerRecord, forage: SaveSectionInventories.OwnerRecord,
 components: Components) -> Result`

Components holds three typed caller-owned records. Every array has its full compiled
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

Result has `code:StringName`, `detail:String`, `owner:StringName`, `row:int`,
`fishing_count:int`, `forage_count:int`, `stale_fishing_expeditions:int`,
`stale_fishing_jobs:int`, `stale_forage_jobs:int`, and `is_ok()->bool`.
On refusal counts are zero and owner/row identify the first offending claim or
component row; a preflight error uses owner empty/row−1. On success code empty,
detail empty, owner empty/row−1, and all counts are computed. Never publish partial
counts on refusal. Result is new per call, not stored on any owner.

## Mandatory preflights and identity

Deterministic gate order: null inputs including three component subrecords; every
component array extent; Directory structure/cursor; section7 block identity/shape
and codec domains for fishing then forage; all component local domains and live
mirrors; active Fishing rows ascending; active Forage rows ascending; all Fishing
aggregate rows ascending; all Forage aggregate rows ascending.

Use exact existing owner shapes (fishing index0/schema2/eight fields/512,
forage index1/schema1/eleven fields/8192). Refuse wrong owner/primary/child shapes
before any mapping. Reuse codec.owner_refusal but never apply/capture or call the
legacy validators/rebuilders. Enforce the stronger existing exact owner quantity
bounds: Fishing1..6, Forage1..1180000, derived from current constants. Counts in
the caller's live stores are not inputs and cannot be rewritten.

Privately allocate one SaveSectionDirectory.Derived and invoke its existing
rebuild_into on the supplied record; do not mutate or borrow a caller Derived.
Validate next-PID using the existing identity contract:1..2147483648, strictly
above every live persistent ID; the terminal value means exhausted. Preserve
underlying Directory refusal codes; add checker codes for its cursor failures.
Do not install that Directory into any live store. Its rebuilt reverse map is the
same ARCH-ID-003 predicate used for every live reference: bounds, active,
generation, expected kind, typed range and reverse owner, without reconstructing
an owner reference from a claim's typed row.

Local component gates: occupancy0/1; active identity full-pair mirrors the Directory
of the proper kind and exact typed row. Also walk every live Directory entry of
Habitat/HarvestZone/Job kind to ensure the matching component row is present and
mirrors it. This is a bijection, not only a forward check. Inactive row refslots−1 and generations0. Inactive Job tick and zone reserved
are zero; inactive Fish used is zero, but effort_slots may retain its prior valid
capacity after ordinary destroy_habitat. Accept0..6 there, without normalizing it.
Present Fish effort capacity1..6, used0..capacity; present zone reserved>=0;
present Job created_tick>=0.
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
against saved habitat_effort_used and physical habitat_effort_slots. Free rows
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
quantity, then checked accumulation; applicable earlier gates win.

Every supplied byte and all caller/live state remain unchanged on success AND
refusal. No use of old Fishing validate/rebuild_effort_aggregates or Forage
rebuild_reservation_aggregates: they mutate count, scratch or canonical data.
One private Directory Derived costs1409816 packed bytes; int64 totals32+128 cost1280.
Private packed scratch ceiling1411096, plus the caller projection148768 and already
owned input records; native object overhead is separately unmeasured. No clone of
whole Directory or claim arrays, no second mutable world or new resident budget.
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
Each must fail a meaningful assertion with executable sources exactly restored.
Full suite,15static,editor,independent review and exact-head CI before checker merge.

Queue split must retain a blocked SAVE-CLAIM-WORLD-BINDING dependency on section4,
complete owner validation/capture/apply and coordinator. Its producer maps EXACT
field ordinals from accepted registry and versions; it must not take live values
from another world. The pure checker alone may never mark release_save_ready,
SAVE-CAPTURE, SAVE-ORCHESTRATOR or first-playable acceptance complete.
