# PC-04 bounded state and load contract

FAMILY-STATE-R01 · version1 draft · 2026-09-19 · Astra

Companion to family_execution_package.md. Proposed, not active registry state.
Do not implement or mark the family package complete before independent review
of this table, the gameplay rules and their cross-owner transaction boundary.

## Household owner

`core/households.gd` is a fixed child store; household identifiers are local to
this owner and never passed as EntityRefs or resident IDs. Maximum256 live rows,
8 members each. Runtime references are `(row,generation)` with null(-1,0).
A household persistent ID is positive1..2147483647. `next_household_id` is i64,
initial1, terminal2147483648; refusal on exhaustion never resets it. Lowest free
row whose retained generation<I32_MAX allocates with generation+1. Retiring a
household keeps its generation and clears all other row content. GenerationMAX
can be used live once and becomes permanently unavailable after retirement.
All members must be living residents, uniquely listed in persistent-ID order.

| Column | Storage/wire | Capacity | Bytes | Canonical unused |
|---|---|---:|---:|---|
| present | B8/u8 | 256 | 256 | 0 |
| generation | I32/u32 | 256 | 1024 | retained0..I32_MAX |
| persistent_id | I32/u32 | 256 | 1024 | 0 |
| member_count | I32/u32 | 256 | 1024 | 0 |
| member_slot | I32/i32 | 2048 | 8192 | -1 |
| member_generation | I32/u32 | 2048 | 8192 | 0 |
| next_household_id | scalar i64/u64 | 1 | 8 | initial1 |

Household packed/scalar payload=19720 bytes. Membership index=row*8+ordinal.
Unused member tail is canonical null. Present rows have1..8 members, valid
nonzero generation and ID<next_household_id; IDs are unique. Historical retired
IDs remain only in chronicle; no old ID is recycled. Row/member_count values must
agree with the per-resident household reference below. No standalone mutator
may change one side without prevalidating and committing the other.

## Per-resident dependent and provider state

Exactly512 rows indexed by resident typed row, bound to that resident's directory
generation. `present` follows resident presence, not stage; stage stays solely
in Residents. Live children hold care state, live ADULT/ELDER rows hold provider
state. All stages may have household refs. Initial preferred caregivers are
explicit persistent resident IDs,0meansnone; two entries ascending with0onlyatend.
They are not replaced with live slots in history. On death/departure remove them
from the live preference pair after committing the historical event; other live
preferences survive, and community fallback does not need a preference row.

| Column | Storage/wire | Capacity | Bytes | Unused/nonapplicable |
|---|---|---:|---:|---|
| present, care_eligible, warning_bits, willing | four B8/u8 | 512 each | 2048 | all0 |
| resident_generation | I32/u32 | 512 | 2048 | 0 |
| household_row, household_generation | two I32/i32,u32 | 512 each | 4096 | -1,0 |
| preferred_caregiver_id_0, preferred_caregiver_id_1 | two I32/u32 | 512 each | 4096 | 0,0 |
| care | I32/i32 | 512 | 2048 | 0 |
| care_remainder | I64/i64 | 512 | 4096 | 0 |
| provider_slot, provider_generation | two I32/i32,u32 | 512 each | 4096 | -1,0 |
| service_paired_ticks | I32/u32 | 512 | 2048 | 0 |
| provider_served_ticks_today | I32/u32 | 512 | 2048 | 0 |
| served_day | scalar i64/u64 | 1 | 8 | current absolute world day |

Dependent/provider payload=26632bytes; combined owner payload=46352bytes.
Care remainder magnitude<750000; at a bound the outward remainder is0.
Warning bits0=low/1=critical, other bits0; critical implies low. Hysteresis
latches permit low to remain untilcare>4000 and criticaluntilcare>2000.
Provider-served ticks range0..18000; one provider serves at most one child/tick.
Service paired ticks range0..750; reaching750 retires the assignment in the same
committed tick, so a stable saved active assignment holds0..749. Unassigned rows
hold0. A child may have one assigned provider, ADULT/ELDER never a patient in this
store. Medical patients belong to Injury, not this personal care owner.

Willing defaults1forADULT/ELDER,0forCHILD; legal0/1valuesonly. A child must retain
willing0 and provider_served_ticks_today0. Adult/elder must retain care0,
care_remainder0, care_eligible0, warning_bits0, preferred caregiverIDs0 and
providerrefnull. Live child's initial care6500, remainder0, eligible0, warnings0.
No resident slot reuse may inherit the previous row's household, care or provider
fairness. On restore, resident generation must match the directory and Residents.

No inverse provider->child array is authoritative: it is derived by bounded scan
of the512 dependent rows. Duplicate provider refs refuse load/assignment. Every
provider ref identifies a living eligible ADULT/ELDER; exact instantaneous route
validity is rechecked on resume before granting service. Runtime unsafe contacts
interrupt; they do not erase received care or past provider time.

## Bounded scratch and transactional APIs

One owner reserves scratch:256I64 sorted child keys(2048B),256I32 provider rows
(1024B),512B provider occupancy(512B). Total3584B; no per-child object, dictionary
or unbounded queue. Combined permanent payload including scratch49936B before
engine allocator/object overhead. All buffers allocate once, no per-tickresize.

A single candidate `Columns` snapshot requires46352B. Read/validate/copy APIs take
caller-owned columns. Runtime never retains a second complete world. If a loader
holds decoded family columns while the live store exists, the exact loader-wide
snapshot plan must be recomputed with all owners, not inferred from one store.
For this owner alone live+scratch+onefullsnapshot=96288B, before object overhead;
no claim is made for the world-level ARCH-MEM-006 limit. Do not allocate a second
staging snapshot inside restore after a caller already supplied one.

Required APIs, all typed and outcome/refusal explicit:
- `copy_columns_into(out)` leaves out unchanged on shape refusal.
- `columns_refusal(candidate,directory,residents,world_day)` is pure and validates
  complete lengths, domains, unused values, uniqueIDs, membership reciprocity,
  stage restrictions, provider uniqueness and all reference associations.
- `restore_columns(candidate,directory,residents,clock)` requires actual held
  load barrier, validates all beforewrites and copies into existing buffers;
  it neither releases the barrier nor publishes the world.
- `create_household_into(member_refs,preferred_ids,...)` preflights every
  participant and both sides, then commits without any fallible postwrite step.
- `retire_member_into(...)` writes the existing historical event through the
  lifecycle transaction first, then removes only this member and invalid service
  edges; it cannot drop surviving members or reuse IDs.
- `select_care_into(...)` uses prepared same-tick eligibility/contact facts from
  the service planner; snapshot generation and clock bind those facts. Missing
  facts refuse, notfalse-zero availability. Selection itself grants no care.
- `advance_care_tick(...)` consumes validated contact and interference facts;
  stages rates/partner needs inputs before the sole CareHealth integration.

API parameter records and wire signatures still need the independent review's
repair pass before dispatch. In particular multi-owner admission and lifecycle
must not be represented by a series of individually atomic calls with a gap
between them. They require the existing job/bed/inventory/world transaction plan.

## Save, commands and versions

New canonical owner `households` schema1. Parent household columns, resident
binding/care/provider columns and scalars live in §4; member_slot/generation child
arena lives in §5. §4/§5 are validated and installed together in one owner call.
Their future section codecs must declare the exact family records and outer
schema versions rather than silently accepting pre-family files. Registry entries,
owner ID, ordinal numbers and declaration hashes are finalized in the implementation
packet together with current compiler output; this draft allocates no active ID.

Restore order: directory and residents first; family/§4+§5 before care planner
publication; relationship history and names bind independently by persistent ID.
One command cannot change life stage. New caregiving willingness/preference UI
requires a versioned SET_POLICY payload or named new command protocol; it must not
reuse opaque bytes in an existing policy ID. Command wire design remains a blocker.
Existing household admission must be an atomic-unit variant of ACCEPT_CANDIDATES,
not a loop that silently accepts some individual rows. The replay records that
unit identity and its checked selection; it never rerolls household composition.

## Required independent checks

Literal payload arithmetic, generation and ID exhaustion, lowest-rowallocation,
full256households/512bindings capacity refusals, duplicate/residentcrosslinks,
caregiver-stage domains, hostile absent rows, stale provider, swapped-worldinputs,
warninghysteresis boundaries, capturewithoutmutation, malformed restore immutability,
§4/§5 joint validation, no second stagingcopy, and create/retire fault boundaries.
