extends RefCounted
## ARCH-SYS-012 Movement: integer ground progression along a stored route, at the inherited
## per-size speed caps, with the 30 Hz displacement remainder retained rather than truncated away.
##
## ---------------------------------------------------------------------------------------
## THE REMAINDER IS THE POINT.
##
## SET-MOVE-001 5 states the rule: "for inherited ground caps 3277/4096/3072 u/second by size,
## propose `a=remainder+speed; distance=floor(a/30); remainder=a mod 30`. Do not round to integer
## u/tick and lose speed." A small resident at 3277 u/s truncated to 109 u/tick walks 3270 u/s --
## 0.2% slow, forever, differently for each size, and invisible in any single-tick test.
##
## This module uses that rule with one uniform denominator, `30 * 14 = 420`, instead of 30. A
## diagonal lattice step is 14/10 of an orthogonal one under ARCH-PATH-002's cost model, so a
## diagonal segment adds `speed * 10` per axis per tick while an orthogonal segment adds
## `speed * 14`. Over 30 ticks an orthogonal run covers exactly `speed` units, and both segment
## kinds share ONE remainder scale, so the retained fraction survives a corner instead of being
## rescaled or dropped at every direction change.
##
## The two remainders are `ResidentMotion.displacement_remainder_x` and `_z` from ARCH-MEM-008. An
## axis that is not moving on the current segment does not accumulate, so no budget is wasted and
## none is banked from a direction the body never travelled.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS SLICE DELIBERATELY DOES NOT DO, AND WHO OWNS IT.
##
##   * NO `RESERVED -> TRAVEL -> WORK` WIRING, AND NO JOB STATE IS WRITTEN. READY_07 1.2 puts that
##     after real services and work-unit context. `begin_travel()` takes a route request and a work
##     contact, not a job, and arriving sets a MOTION phase and nothing else. The starter profiles
##     below are one of its three preconditions; the other two are still absent.
##   * NO CONTACT RESERVATION, no 30-tick lease renewal, no 300/900-tick retry rules. Those belong
##     with real contacts (`crossing_claims.gd`, task 05.4).
##   * NO SEPARATION. `correction_x`/`correction_z` stay zero; bounded soft separation needs the
##     domain-local Jacobi pass and body radii that the MOVE-G01 parameter pack has not supplied.
##   * NO FACING. Yaw's zero reference and handedness are unstated; `desired_yaw`/`next_yaw` stay
##     zero and `transforms.advance()` carries yaw through untouched rather than guessing it.
##   * `radius_u` stays zero for the same reason `clearance` is a caller input in
##     `spatial_world.gd`: production body and gear clearances are a profile decision.
##
## ---------------------------------------------------------------------------------------
## MEMORY. The sixteen motion columns ARE 2.3's "Resident motion/separation scratch", 512 x 64
## bytes. The `ResidentRouteCursor` is new, because ARCH-MEM-008's ResidentMotion has no field
## naming which route a body is following or how far along it is. Decision 0053 records it at three
## columns, 6144 bytes; decision 0066 adds the fourth, `_cursor_owner_id`, for **8192** bytes.
##
## LEDGER GAP, NAMED NOT INVENTED: that fourth column costs **+2048** bytes, which
## `systems_architecture.md` §2.3's ResidentRouteCursor row and
## `docs/validation/ready07_arithmetic.py`'s `DECISION_0053_ADDED` still state as 6144. Both files
## are owned elsewhere and are byte-unchanged by this work, so the ledger reads 2048 low until
## their owner applies it. Decision 0066 carries the arithmetic.
##
## Decision 0083 adds two more tables for the starter profile increment, and the same gap applies:
##
##   * `ResidentTravelAdmission[512]` -- `_cursor_profile_id`, `_cursor_profile_revision`,
##     `_cursor_mode`, `_cursor_load_g`, `_cursor_destination_revision`: 5 x 4 x 512 = **10240** B.
##   * `StarterGroundProfile[4]` -- `_profile_species_id`, `_profile_size_class`,
##     `_profile_speed_u_per_s`, `_profile_carry_g`, `_profile_mode_mask`, `_profile_revision`:
##     6 x 4 x 4 = **96** B.
##
## Running total still owed to `systems_architecture.md` §2.3 and `ready07_arithmetic.py` by their
## owner: 2048 + 10240 + 96 = **12384** bytes. Both files are byte-unchanged by this work.
##
## ---------------------------------------------------------------------------------------
## THE CURSOR NAMES ITS OWNER, NOT MERELY ITS ROW.
##
## A motion row is a TYPED ROW, and typed rows are reused. Resident A travels in row 7, is
## despawned -- and `residents.despawn()` does not, and is not required to, call `stop()` -- and
## resident B is created into row 7. `_residents.ref_of(7)` then answers with B's perfectly live
## reference while `_movement_phase[7]` still reads TRAVELLING and the cursor still names A's
## route, so B would walk A's route and the travelling count would be a resident too high for the
## whole interval. `_cursor_owner_id[row]` closes that: the owner's persistent id is stamped at
## `_attach_route()` and must still match at every `_advance_row()`, or the row settles ROUTE_LOST.
##
## IT IS THE PERSISTENT ID AND NOT A GENERATION, for the reason `transforms.gd`'s header gives at
## length: a generation belongs to a directory SLOT, every slot's first use carries generation 1,
## and slots and typed rows come from separate free heaps, so a generation stamp matches across
## two different entities routinely. Persistent ids are never reused.
##
## ---------------------------------------------------------------------------------------
## THE STARTER GROUND PROFILES -- WHAT THEY BIND, AND WHAT THEY REFUSE TO BIND.
##
## The 2026-09-11 movement ruling permits one independent increment while full MOVE-G01 stays open:
## **starter ground profiles only; this closes no MOVE gate.** Four profiles exist, one per actual
## starter species in GDD 5.1's cohort sentence "12 adults (6 mice, 2 moles, 2 otters, 2
## squirrels)", in that sentence's order. No synthetic species is added.
##
## Every numeric field is READ from `residents.gd` at `_init()` rather than copied as a literal, so
## a profile cannot drift away from GDD 5.2's size class, speed cap and carry capacity. The audit
## this increment owes is therefore executed on every construction, not written down once.
##
## WHAT A PROFILE DOES NOT CARRY, NAMED RATHER THAN GUESSED:
##
##   * NO CLEARANCE CLASS. Body, posture and gear envelopes are unstated everywhere: the asset
##     package's own species heights say they "do NOT set navigation clearance, service reach, step
##     height or movement capability", and the ruling adds that battle separation radii cannot
##     determine them either. `profile_clearance_class_into()` therefore REFUSES rather than
##     returning a number, and travel admission does not silently choose one. A caller-supplied
##     synthetic clearance on a reference route is still fine and is still not a species policy.
##   * NO LIFE STAGE BUT ADULT. `residents.gd` has no life-stage column at all; the cohort is
##     twelve adults. `LIFE_STAGE_ADULT` is the only profiled stage and any other refuses.
##   * NO MODE BUT GROUND AND FORD WALKING. Swimming, diving, climbing/canopy and tunnel travel
##     stay in first-release scope under SET-MOVE-001 1 and are enumerated below so they cannot be
##     lost by omission -- they are UNPROFILED IN THIS INCREMENT and refuse explicitly. That is an
##     incremental capability boundary, not a narrowing of the adopted scope.
##   * NO EQUIPMENT ELIGIBILITY RULE. The committed load is checked against GDD 5.2's carry
##     capacity, which is specified. Which tool or gear blocks which passage is not, anywhere.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SpatialWorld := preload("res://scripts/core/spatial_world.gd")
const Navigation := preload("res://scripts/core/navigation.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

## systems_architecture.md 2.3 sizes the motion scratch at 512 rows, one per resident slot.
const MOTION_CAPACITY: int = ResidentsScript.RESIDENT_CAPACITY

## GDD 5.1: 30 fixed ticks per second at 1x.
const TICKS_PER_SECOND: int = 30

## The shared remainder denominator; see the header. 30 ticks x the diagonal cost 14.
const REMAINDER_DENOMINATOR: int = TICKS_PER_SECOND * Navigation.COST_DIAGONAL

## Per-tick numerators: an orthogonal segment advances one axis at full speed, a diagonal segment
## advances both axes at the 10/14 the octile cost model already charges for them.
const ORTHOGONAL_NUMERATOR_FACTOR: int = Navigation.COST_DIAGONAL
const DIAGONAL_NUMERATOR_FACTOR: int = Navigation.COST_ORTHOGONAL

## A per-tick step is at most 4096/30 = 136 units and a cell is 512, so one tick can cross at most
## one cell boundary. The loop bound is generous rather than tight, and is a guard, not a budget.
const MAX_SEGMENTS_PER_TICK: int = 8

const MOTION_IDLE: int = 0
const MOTION_TRAVELLING: int = 1
const MOTION_ARRIVED: int = 2
const MOTION_ROUTE_LOST: int = 3
const MOTION_PROFILE_STALE: int = 4
const MOTION_CONTACT_STALE: int = 5
const MOTION_PHASE_COUNT: int = 6

const MOTION_PHASE_NAMES: Array[StringName] = [
	&"IDLE", &"TRAVELLING", &"ARRIVED", &"ROUTE_LOST", &"PROFILE_STALE", &"CONTACT_STALE",
]

# --- starter ground profiles, 2026-09-11 ruling item 1 -------------------------------------------

## GDD 5.1's cohort sentence order: "6 mice, 2 moles, 2 otters, 2 squirrels". These four keys are
## the ONLY starter species; `residents.gd` compiles twelve more that this increment does not
## profile, and a request for any of them refuses rather than borrowing a neighbour's row.
const PROFILE_SPECIES_KEYS: Array[StringName] = [&"mouse", &"mole", &"otter", &"squirrel"]

## Stable ASCII profile keys. `starter` names the increment, `ground` the domain, `adult` the life
## stage and the last token the species, so a later life stage or domain extends the namespace
## instead of overloading one of these.
const PROFILE_KEYS: Array[StringName] = [
	&"starter.ground.adult.mouse",
	&"starter.ground.adult.mole",
	&"starter.ground.adult.otter",
	&"starter.ground.adult.squirrel",
]
const PROFILE_COUNT: int = 4

## Published revision of a profile on first construction. A revision is an identity artifact the
## ruling asks for, not a balance value; `revise_profile()` advances one so a route admitted under
## an older revision can be made to invalidate.
const PROFILE_FIRST_REVISION: int = 1

## `residents.gd` carries no life-stage column, and GDD 5.1's cohort is twelve adults. This is the
## only profiled stage; juveniles and elders are unprofiled, not absent from the release.
const LIFE_STAGE_ADULT: int = 0
const LIFE_STAGE_COUNT: int = 1

# --- traversal modes, SET-MOVE-001 1 -------------------------------------------------------------
#
# All six are ENUMERATED so the adopted scope cannot be narrowed by omission. Only the first two are
# profiled in this increment; the rest refuse MODE_NOT_PROFILED, with their costs, speeds, entry and
# exit durations, air budgets and grip rules still owed by MOVE-G01.

const MODE_GROUND_WALK: int = 0
const MODE_FORD_WALK: int = 1
const MODE_SWIM_SURFACE: int = 2
const MODE_DIVE: int = 3
const MODE_CLIMB: int = 4
const MODE_TUNNEL_WALK: int = 5
const MODE_COUNT: int = 6

const MODE_NAMES: Array[StringName] = [
	&"GROUND_WALK", &"FORD_WALK", &"SWIM_SURFACE", &"DIVE", &"CLIMB", &"TUNNEL_WALK",
]

## The two modes this increment profiles, as a bit mask over the enum above.
const PROFILED_MODE_MASK: int = (1 << MODE_GROUND_WALK) | (1 << MODE_FORD_WALK)

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_RESIDENT: StringName = &"REF_IS_NOT_A_LIVING_RESIDENT"
const REFUSE_NOT_PLACED: StringName = &"RESIDENT_TRANSFORM_NOT_PLACED"
const REFUSE_ROUTE_NOT_READY: StringName = &"ROUTE_REQUEST_NOT_READY"
const REFUSE_ROUTE_START: StringName = &"RESIDENT_NOT_ON_ROUTE_START"
const REFUSE_SIZE_CLASS: StringName = &"RESIDENT_SIZE_CLASS_INVALID"
const REFUSE_NOT_TRAVELLING: StringName = &"RESIDENT_IS_NOT_TRAVELLING"
const REFUSE_PROFILE_ID: StringName = &"PROFILE_NOT_PUBLISHED"
const REFUSE_PROFILE_SPECIES: StringName = &"PROFILE_SPECIES_MISMATCH"
const REFUSE_PROFILE_REVISION: StringName = &"PROFILE_REVISION_STALE"
const REFUSE_PROFILE_CLEARANCE: StringName = &"PROFILE_CLEARANCE_UNSPECIFIED"
const REFUSE_MODE_RANGE: StringName = &"MODE_NOT_IN_ENUM"
const REFUSE_MODE_UNPROFILED: StringName = &"MODE_NOT_PROFILED"
const REFUSE_LIFE_STAGE: StringName = &"LIFE_STAGE_NOT_PROFILED"
const REFUSE_LOAD_NEGATIVE: StringName = &"COMMITTED_LOAD_NEGATIVE"
const REFUSE_LOAD_CAPACITY: StringName = &"LOAD_EXCEEDS_CARRY_CAPACITY"
const REFUSE_CONTACT_UNBOUND: StringName = &"CONTACT_NOT_BOUND"
const REFUSE_CONTACT_OWNER: StringName = &"CONTACT_OWNER_REF_STALE"
const REFUSE_CONTACT_LOCATION: StringName = &"CONTACT_LOCATION_NOT_CURRENT"
const REFUSE_CONTACT_REVISION: StringName = &"CONTACT_DESTINATION_REVISION_STALE"
const REFUSE_ROUTE_CONTACT: StringName = &"ROUTE_DOES_NOT_END_AT_CONTACT_APPROACH"

const NO_REQUEST: int = -1

## `entity_directory.gd` issues persistent ids from 1 and never reuses one, and answers 0 for a
## stale reference, so 0 is "this cursor belongs to nobody" and can never collide with an owner.
const NO_OWNER_ID: int = 0

## Internal absence markers for the admission columns. Neither crosses a public boundary as a
## failure code: every public refusal is an explicit `false` plus a StringName.
const NO_PROFILE: int = -1
const NO_MODE: int = -1

class Admission:
	extends RefCounted
	## One travel admission's caller-supplied terms: which profile, which mode, what is carried.
	##
	## Caller-owned and reused, so admitting travel allocates nothing. Everything here is checked
	## together before any motion row is written -- the ruling's "documented atomic boundary before
	## travel". A refused admission leaves the resident exactly as it was.

	var profile_id: int = -1
	var life_stage: int = -1
	var mode: int = -1
	var committed_load_g: int = 0

	func clear() -> void:
		"""Return this record to the unusable state, so a stale reuse refuses rather than travels."""
		profile_id = -1
		life_stage = -1
		mode = -1
		committed_load_g = 0

	func set_terms(profile: int, stage: int, travel_mode: int, load_g: int) -> void:
		"""Fill all four terms in one call, so a partially-updated reuse is harder to write."""
		profile_id = profile
		life_stage = stage
		mode = travel_mode
		committed_load_g = load_g


var _directory: EntityDirectory = null
var _world: SpatialWorld = null
var _navigation: Navigation = null
var _transforms: Transforms = null
var _residents: ResidentsScript = null

# --- StarterGroundProfile, PROFILE_COUNT rows ----------------------------------------------------

var _profile_species_id: PackedInt32Array = PackedInt32Array()
var _profile_size_class: PackedInt32Array = PackedInt32Array()
var _profile_speed_u_per_s: PackedInt32Array = PackedInt32Array()
var _profile_carry_g: PackedInt32Array = PackedInt32Array()
var _profile_mode_mask: PackedInt32Array = PackedInt32Array()
var _profile_revision: PackedInt32Array = PackedInt32Array()

# --- ResidentMotion, ARCH-MEM-008's sixteen i32 columns ------------------------------------------

var _vx: PackedInt32Array = PackedInt32Array()
var _vz: PackedInt32Array = PackedInt32Array()
var _remainder_x: PackedInt32Array = PackedInt32Array()
var _remainder_z: PackedInt32Array = PackedInt32Array()
var _next_x: PackedInt32Array = PackedInt32Array()
var _next_z: PackedInt32Array = PackedInt32Array()
var _correction_x: PackedInt32Array = PackedInt32Array()
var _correction_z: PackedInt32Array = PackedInt32Array()
var _grid_next: PackedInt32Array = PackedInt32Array()
var _grid_cell: PackedInt32Array = PackedInt32Array()
var _radius_u: PackedInt32Array = PackedInt32Array()
var _speed_u_per_s: PackedInt32Array = PackedInt32Array()
var _desired_yaw: PackedInt32Array = PackedInt32Array()
var _next_yaw: PackedInt32Array = PackedInt32Array()
var _movement_phase: PackedInt32Array = PackedInt32Array()
var _blocked_ticks: PackedInt32Array = PackedInt32Array()

# --- ResidentRouteCursor, this slice's addition ---------------------------------------------------

var _cursor_request: PackedInt32Array = PackedInt32Array()
var _cursor_route_generation: PackedInt32Array = PackedInt32Array()
var _cursor_index: PackedInt32Array = PackedInt32Array()
var _cursor_owner_id: PackedInt32Array = PackedInt32Array()

# --- ResidentTravelAdmission, the terms this row's journey was admitted under ----------------------

var _cursor_profile_id: PackedInt32Array = PackedInt32Array()
var _cursor_profile_revision: PackedInt32Array = PackedInt32Array()
var _cursor_mode: PackedInt32Array = PackedInt32Array()
var _cursor_load_g: PackedInt32Array = PackedInt32Array()
var _cursor_destination_revision: PackedInt32Array = PackedInt32Array()

var _scratch: IntMath.IntResult = IntMath.IntResult.new()
var _pose: Transforms.Pose = Transforms.Pose.new()
var _travelling_count: int = 0
var _last_refusal: StringName = REFUSE_NONE

# --- per-tick scalar scratch, so the hot path constructs nothing ---------------------------------
#
# CLAUDE.md bans object creation in a hot loop, and `_advance_row()` runs once per travelling
# resident per tick -- 256 residents x 30 Hz x 4x. `_consume_into()` and `_spend_budget()` each
# have two outputs and one caller apiece, so their results are written here instead of into a
# returned pair. Every value is copied into a local or consumed before the next call that writes
# it, exactly as `sim_clock.gd`'s `_math` scratch is used.

var _step_position: int = 0
var _step_budget: int = 0
var _here_x: int = 0
var _here_z: int = 0


func _init(
	directory: EntityDirectory, world: SpatialWorld, navigation: Navigation,
	transforms: Transforms, residents: ResidentsScript
) -> void:
	"""Bind every collaborator and allocate the motion and cursor columns once to 512 rows."""
	_directory = directory
	_world = world
	_navigation = navigation
	_transforms = transforms
	_residents = residents
	_allocate_motion()
	_allocate_cursors()
	_allocate_profiles()
	_build_starter_profiles()


func _allocate_motion() -> void:
	"""Allocate ARCH-MEM-008's sixteen ResidentMotion columns, each by name (packed arrays copy)."""
	_vx.resize(MOTION_CAPACITY)
	_vz.resize(MOTION_CAPACITY)
	_remainder_x.resize(MOTION_CAPACITY)
	_remainder_z.resize(MOTION_CAPACITY)
	_next_x.resize(MOTION_CAPACITY)
	_next_z.resize(MOTION_CAPACITY)
	_correction_x.resize(MOTION_CAPACITY)
	_correction_z.resize(MOTION_CAPACITY)
	_grid_next.resize(MOTION_CAPACITY)
	_grid_cell.resize(MOTION_CAPACITY)
	_radius_u.resize(MOTION_CAPACITY)
	_speed_u_per_s.resize(MOTION_CAPACITY)
	_desired_yaw.resize(MOTION_CAPACITY)
	_next_yaw.resize(MOTION_CAPACITY)
	_movement_phase.resize(MOTION_CAPACITY)
	_blocked_ticks.resize(MOTION_CAPACITY)


func _allocate_cursors() -> void:
	"""Allocate the route cursor columns and mark every row as following no route and owned by none.

	Writing `NO_OWNER_ID` is redundant today -- `resize()` zero-fills and that constant is 0 -- so a
	mutation removing it survives and is equivalent, recorded in decision 0066. It is written
	because the column's null value is part of its contract, not a property of the allocator.
	"""
	_cursor_request.resize(MOTION_CAPACITY)
	_cursor_route_generation.resize(MOTION_CAPACITY)
	_cursor_index.resize(MOTION_CAPACITY)
	_cursor_owner_id.resize(MOTION_CAPACITY)
	_cursor_profile_id.resize(MOTION_CAPACITY)
	_cursor_profile_revision.resize(MOTION_CAPACITY)
	_cursor_mode.resize(MOTION_CAPACITY)
	_cursor_load_g.resize(MOTION_CAPACITY)
	_cursor_destination_revision.resize(MOTION_CAPACITY)
	for row: int in MOTION_CAPACITY:
		_cursor_request[row] = NO_REQUEST
		_cursor_owner_id[row] = NO_OWNER_ID
		_cursor_profile_id[row] = NO_PROFILE
		_cursor_mode[row] = NO_MODE
		_grid_cell[row] = NO_REQUEST
		_grid_next[row] = NO_REQUEST


func _allocate_profiles() -> void:
	"""Allocate the six starter-profile columns once to PROFILE_COUNT rows."""
	_profile_species_id.resize(PROFILE_COUNT)
	_profile_size_class.resize(PROFILE_COUNT)
	_profile_speed_u_per_s.resize(PROFILE_COUNT)
	_profile_carry_g.resize(PROFILE_COUNT)
	_profile_mode_mask.resize(PROFILE_COUNT)
	_profile_revision.resize(PROFILE_COUNT)


func _build_starter_profiles() -> void:
	"""Derive every starter profile from `residents.gd`, refusing rather than defaulting a species.

	THE AUDIT IS THIS FUNCTION. Nothing here is a literal: the compiled species id, the size class,
	the speed cap and the carry capacity are all read back out of the resident store, which holds
	GDD 5.2's table including its deliberate large-is-slower anomaly. A species the store does not
	compile leaves its profile row unpublished -- `_profile_revision` stays 0 -- rather than
	inheriting a neighbour's numbers.
	"""
	for profile: int in PROFILE_COUNT:
		_profile_revision[profile] = 0
		var species: IntMath.IntResult = _residents.species_id(PROFILE_SPECIES_KEYS[profile])
		var size: IntMath.IntResult = _residents.species_size_class(PROFILE_SPECIES_KEYS[profile])
		if not species.ok or not size.ok:
			continue
		var speed: IntMath.IntResult = _residents.size_movement_u_per_s(size.value)
		var carry: IntMath.IntResult = _residents.size_carry_g(size.value)
		if not speed.ok or not carry.ok:
			continue
		_profile_species_id[profile] = species.value
		_profile_size_class[profile] = size.value
		_profile_speed_u_per_s[profile] = speed.value
		_profile_carry_g[profile] = carry.value
		_profile_mode_mask[profile] = PROFILED_MODE_MASK
		_profile_revision[profile] = PROFILE_FIRST_REVISION


# --- the published starter profile manifest ---------------------------------------------------------

func is_profile(profile_id: int) -> bool:
	"""True when `profile_id` names a published starter profile. A predicate, not an error channel."""
	return profile_id >= 0 and profile_id < PROFILE_COUNT \
		and _profile_revision[profile_id] >= PROFILE_FIRST_REVISION


func profile_key_of(profile_id: int) -> StringName:
	"""The stable ASCII key of a published profile, or the empty name when none is published."""
	return PROFILE_KEYS[profile_id] if is_profile(profile_id) else &""


func profile_for_species_into(species_key: StringName, out: IntMath.IntResult) -> bool:
	"""The profile id covering a species key, or an explicit refusal for an unprofiled species.

	Twelve of `residents.gd`'s sixteen release-1 species have no starter profile. They refuse here
	rather than resolving to a size-class neighbour, because a size class is not a traversal
	profile and treating it as one is how an unreviewed species reaches production travel.
	"""
	var profile: int = PROFILE_SPECIES_KEYS.find(species_key)
	if profile < 0 or not is_profile(profile):
		_last_refusal = REFUSE_PROFILE_SPECIES
		return out.refuse(REFUSE_PROFILE_SPECIES)
	_last_refusal = REFUSE_NONE
	return out.succeed(profile)


func profile_revision_of(profile_id: int) -> int:
	"""The current revision of a published profile, or 0 when nothing is published at that id."""
	return _profile_revision[profile_id] if is_profile(profile_id) else 0


func profile_speed_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""GDD 5.2's per-size movement cap for a profile in u/second, or an explicit refusal."""
	return _profile_field_into(_profile_speed_u_per_s, profile_id, out)


func profile_carry_capacity_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""GDD 5.2's per-size carry capacity for a profile in grams, or an explicit refusal."""
	return _profile_field_into(_profile_carry_g, profile_id, out)


func profile_size_class_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""The inherited size class a profile's species falls in, or an explicit refusal."""
	return _profile_field_into(_profile_size_class, profile_id, out)


func profile_species_id_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""The compiled `residents.gd` species id a profile covers, or an explicit refusal."""
	return _profile_field_into(_profile_species_id, profile_id, out)


func _profile_field_into(
	column: PackedInt32Array, profile_id: int, out: IntMath.IntResult
) -> bool:
	"""One published profile column, or REFUSE_PROFILE_ID. Shared so each reader is two lines."""
	if not is_profile(profile_id):
		_last_refusal = REFUSE_PROFILE_ID
		return out.refuse(REFUSE_PROFILE_ID)
	_last_refusal = REFUSE_NONE
	return out.succeed(column[profile_id])


func profile_clearance_class_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""ALWAYS REFUSES: no starter profile carries a body-plus-gear clearance class.

	This function exists so the gap is a refusal a caller must handle rather than a field nobody
	notices is missing. The asset package states its species heights "do NOT set navigation
	clearance, service reach, step height or movement capability", and the 2026-09-11 movement
	ruling adds that battle separation radii cannot determine these dimensions either. Nothing else
	in `docs/` states a horizontal body, posture, gear or load envelope for a resident. Until the
	movement and asset owners author those envelopes and derive a class against
	`spatial_world.gd`'s anchored passable-square convention, this refuses -- for every profile,
	including one whose id is perfectly valid.
	"""
	if not is_profile(profile_id):
		_last_refusal = REFUSE_PROFILE_ID
		return out.refuse(REFUSE_PROFILE_ID)
	_last_refusal = REFUSE_PROFILE_CLEARANCE
	return out.refuse(REFUSE_PROFILE_CLEARANCE)


func profile_permits_mode(profile_id: int, mode: int) -> bool:
	"""True when a published profile admits a traversal mode in THIS increment."""
	if not is_profile(profile_id) or mode < 0 or mode >= MODE_COUNT:
		return false
	return (_profile_mode_mask[profile_id] & (1 << mode)) != 0


func revise_profile(profile_id: int) -> bool:
	"""Advance one published profile's revision, or refuse explicitly.

	Routes already admitted under the old revision do not silently continue: `_advance_row()` sees
	the mismatch and settles the body MOTION_PROFILE_STALE, which is SET-MOVE-001 MOVE-REQ-006's
	"revalidate affected future route segments before entry" at this increment's granularity.
	"""
	if not is_profile(profile_id):
		_last_refusal = REFUSE_PROFILE_ID
		return false
	_profile_revision[profile_id] += 1
	_last_refusal = REFUSE_NONE
	return true


# --- starting and stopping -------------------------------------------------------------------------

func begin_travel(
	resident: Vector2i, request_row: int, admission: Admission, contact: SpatialWorld.Contact
) -> bool:
	"""Admit one resident to travel a ready route to a work contact, or refuse explicitly.

	EVERY CHECK RUNS BEFORE ANY COLUMN IS WRITTEN. That is the ruling's atomic admission boundary:
	a refused admission leaves the resident's motion row exactly as it was, so a caller cannot
	half-start a journey and discover the incompatibility one tick later.

	The resident must already stand on the route's first cell, and the route must END on the
	contact's approach cell. There is no teleport-to-start, no "close enough" tolerance and no
	nearest-contact fallback: a body that is not on the route it was handed has not been given its
	route, and a route that stops somewhere near the destination has not reached it.
	"""
	var row: int = _motion_row(resident)
	if row < 0:
		return false
	var refusal: StringName = _refuse_admission(resident, request_row, admission, contact)
	if refusal != REFUSE_NONE:
		_last_refusal = refusal
		return false
	if not _navigation.route_cell_into(request_row, 0, _scratch):
		_last_refusal = REFUSE_ROUTE_NOT_READY
		return false
	return _attach_route(resident, row, request_row, _scratch.value, admission, contact)


func _refuse_admission(
	resident: Vector2i, request_row: int, admission: Admission, contact: SpatialWorld.Contact
) -> StringName:
	"""Every precondition for admitting travel, as the refusal it produces or REFUSE_NONE."""
	var profile_refusal: StringName = _refuse_profile_terms(resident, admission)
	if profile_refusal != REFUSE_NONE:
		return profile_refusal
	var contact_refusal: StringName = _refuse_contact_terms(contact)
	if contact_refusal != REFUSE_NONE:
		return contact_refusal
	if not _navigation.is_ready(request_row):
		return REFUSE_ROUTE_NOT_READY
	if not _route_ends_at(request_row, contact.approach.cell):
		return REFUSE_ROUTE_CONTACT
	return _refuse_route_start(resident, request_row)


func _refuse_profile_terms(resident: Vector2i, admission: Admission) -> StringName:
	"""The profile, life stage, mode and committed-load half of admission."""
	if not is_profile(admission.profile_id):
		return REFUSE_PROFILE_ID
	if admission.life_stage != LIFE_STAGE_ADULT:
		return REFUSE_LIFE_STAGE
	if admission.mode < 0 or admission.mode >= MODE_COUNT:
		return REFUSE_MODE_RANGE
	if not profile_permits_mode(admission.profile_id, admission.mode):
		return REFUSE_MODE_UNPROFILED
	var species: IntMath.IntResult = _residents.species_of(_directory.get_typed_row(resident))
	if not species.ok or species.value != _profile_species_id[admission.profile_id]:
		return REFUSE_PROFILE_SPECIES
	if admission.committed_load_g < 0:
		return REFUSE_LOAD_NEGATIVE
	if admission.committed_load_g > _profile_carry_g[admission.profile_id]:
		return REFUSE_LOAD_CAPACITY
	return REFUSE_NONE


func _refuse_contact_terms(contact: SpatialWorld.Contact) -> StringName:
	"""The destination half of admission: bound, owned by something live, and current."""
	if not contact.is_bound():
		return REFUSE_CONTACT_UNBOUND
	if not _directory.is_valid(contact.owner_ref()):
		return REFUSE_CONTACT_OWNER
	if not _world.contact_is_current(contact):
		return REFUSE_CONTACT_LOCATION
	return REFUSE_NONE


func _refuse_route_start(resident: Vector2i, request_row: int) -> StringName:
	"""The resident must be placed, and standing on the route's own first cell."""
	if not _transforms.read_into(resident, _pose):
		return REFUSE_NOT_PLACED
	if not _world.cell_of_position_into(_pose.x, _pose.z, _scratch):
		return REFUSE_ROUTE_START
	var here: int = _scratch.value
	if not _navigation.route_cell_into(request_row, 0, _scratch):
		return REFUSE_ROUTE_NOT_READY
	return REFUSE_NONE if _scratch.value == here else REFUSE_ROUTE_START


func _route_ends_at(request_row: int, cell: int) -> bool:
	"""True when the route's LAST cell is `cell` -- arrival must be the exact contact approach."""
	if not _navigation.route_length_into(request_row, _scratch):
		return false
	var last_index: int = _scratch.value - 1
	if last_index < 0 or not _navigation.route_cell_into(request_row, last_index, _scratch):
		return false
	return _scratch.value == cell


func _attach_route(
	resident: Vector2i, row: int, request_row: int, here: int, admission: Admission,
	contact: SpatialWorld.Contact
) -> bool:
	"""Initialize one resident's motion and cursor state on a route it already stands at the start of."""
	var speed: int = _speed_of(resident)
	if speed <= 0:
		_last_refusal = REFUSE_SIZE_CLASS
		return false
	_reset_motion(row)
	_speed_u_per_s[row] = speed
	_grid_cell[row] = here
	_cursor_request[row] = request_row
	_cursor_route_generation[row] = _navigation.route_generation_of(
		_navigation.request_route_id(request_row))
	_cursor_index[row] = 0
	_cursor_owner_id[row] = _directory.get_persistent_id(resident)
	_cursor_profile_id[row] = admission.profile_id
	_cursor_profile_revision[row] = _profile_revision[admission.profile_id]
	_cursor_mode[row] = admission.mode
	_cursor_load_g[row] = admission.committed_load_g
	_cursor_destination_revision[row] = contact.destination_revision
	_movement_phase[row] = MOTION_TRAVELLING
	_travelling_count += 1
	_advance_cursor_target(row)
	_last_refusal = REFUSE_NONE
	return true


func _reset_motion(row: int) -> void:
	"""Clear one motion row, including both retained remainders, before a new route starts."""
	_vx[row] = 0
	_vz[row] = 0
	_remainder_x[row] = 0
	_remainder_z[row] = 0
	_next_x[row] = 0
	_next_z[row] = 0
	_correction_x[row] = 0
	_correction_z[row] = 0
	_grid_next[row] = NO_REQUEST
	_radius_u[row] = 0
	_desired_yaw[row] = 0
	_next_yaw[row] = 0
	_blocked_ticks[row] = 0


func stop(resident: Vector2i) -> bool:
	"""Detach a resident from its route and return it to MOTION_IDLE, or refuse explicitly."""
	var row: int = _motion_row(resident)
	if row < 0:
		return false
	if _movement_phase[row] == MOTION_TRAVELLING:
		_travelling_count -= 1
	_reset_motion(row)
	_cursor_request[row] = NO_REQUEST
	_cursor_route_generation[row] = 0
	_cursor_index[row] = 0
	_cursor_owner_id[row] = NO_OWNER_ID
	_cursor_profile_id[row] = NO_PROFILE
	_cursor_profile_revision[row] = 0
	_cursor_mode[row] = NO_MODE
	_cursor_load_g[row] = 0
	_cursor_destination_revision[row] = 0
	_movement_phase[row] = MOTION_IDLE
	_last_refusal = REFUSE_NONE
	return true


func revalidate_destination(resident: Vector2i, destination_revision: int) -> bool:
	"""Re-present a travelling resident's destination revision; settle it CONTACT_STALE on mismatch.

	THE CONTACT OWNER CALLS THIS, BECAUSE ONLY IT KNOWS WHEN ITS DESTINATION CHANGED. Movement
	holds the number the journey was admitted under and compares; it cannot detect an emptied store
	or a withdrawn service on its own, and does not pretend to by polling anything.

	OPEN, NAMED NOT INVENTED: nothing yet calls this every tick, because no building, room or
	service store publishes a destination revision. That producer is the contact owner's piece of
	the ruling's item 4 and is not written here. Returns false when the reference is not a
	travelling resident; a settled row is a true return, since the revalidation did happen.
	"""
	var row: int = _motion_row(resident)
	if row < 0:
		return false
	if _movement_phase[row] != MOTION_TRAVELLING:
		_last_refusal = REFUSE_NOT_TRAVELLING
		return false
	if _cursor_destination_revision[row] != destination_revision:
		_settle(row, MOTION_CONTACT_STALE)
	_last_refusal = REFUSE_NONE
	return true


func _motion_row(resident: Vector2i) -> int:
	"""The motion row of a live resident reference, or -1 with the refusal already recorded."""
	if not _directory.is_valid_of_kind(resident, EntityDirectory.KIND_RESIDENT):
		_last_refusal = REFUSE_NOT_RESIDENT
		return -1
	return _directory.get_typed_row(resident)


func _speed_of(resident: Vector2i) -> int:
	"""GDD 5.2's inherited per-size movement cap in u/second, or 0 when the size is unreadable.

	The cap is READ from `residents.gd`, which copies GDD 5.2 including its deliberate anomaly that
	large is slower than medium. No speed number is defined in this module.
	"""
	var slot: int = _directory.get_typed_row(resident)
	var size_class: IntMath.IntResult = _residents.size_class_of(slot)
	if not size_class.ok:
		return 0
	var capped: IntMath.IntResult = _residents.size_movement_u_per_s(size_class.value)
	return capped.value if capped.ok else 0


# --- the per-tick integration ---------------------------------------------------------------------

func advance_tick(_tick: int) -> int:
	"""Advance every travelling resident by one 30 Hz tick and return how many moved.

	Iterates the 512 motion rows, not a live-entity list: at 512 rows with an early phase test this
	is a linear scan of one packed column and allocates nothing. The tick number is accepted for
	call-order symmetry with the rest of the pipeline and deliberately decides nothing: movement at
	1x, 2x and 4x differs only in how many times this is called.
	"""
	var moved: int = 0
	for row: int in MOTION_CAPACITY:
		if _movement_phase[row] != MOTION_TRAVELLING:
			continue
		if _advance_row(row):
			moved += 1
	return moved


func _advance_row(row: int) -> bool:
	"""Advance one travelling resident, settling it if its route or its owner no longer holds."""
	var resident: Vector2i = _resident_ref_of(row)
	if resident.x < 0 or not _cursor_owner_matches(row, resident) or not _route_still_valid(row):
		_settle(row, MOTION_ROUTE_LOST)
		return false
	if not _admitted_profile_still_current(row):
		_settle(row, MOTION_PROFILE_STALE)
		return false
	if not _transforms.read_into(resident, _pose):
		_settle(row, MOTION_ROUTE_LOST)
		return false
	var budget_x: int = _integrate_axis(row, true)
	var budget_z: int = _integrate_axis(row, false)
	_spend_budget(row, _pose.x, _pose.z, budget_x, budget_z)
	var here_x: int = _here_x
	var here_z: int = _here_z
	if not _height_at_into(here_x, here_z, _scratch):
		_settle(row, MOTION_ROUTE_LOST)
		return false
	var height: int = _scratch.value
	_vx[row] = here_x - _pose.x
	_vz[row] = here_z - _pose.z
	if not _transforms.advance(resident, here_x, height, here_z):
		_settle(row, MOTION_ROUTE_LOST)
		return false
	return true


func _cursor_owner_matches(row: int, resident: Vector2i) -> bool:
	"""True when the entity now holding this typed row is the one the cursor was attached for.

	A typed row outlives its occupant; a route must not. See the header: the stamp is the owner's
	never-reused persistent id, so a successor spawned into a despawned traveller's row cannot
	inherit its route.
	"""
	return _cursor_owner_id[row] == _directory.get_persistent_id(resident)


func _admitted_profile_still_current(row: int) -> bool:
	"""True while the profile this journey was admitted under is still published at that revision.

	SET-MOVE-001 MOVE-REQ-006 revalidates a route when a profile revision changes. This increment
	revalidates the WHOLE remaining journey rather than the next segment, because segment-level
	eligibility needs the clearance, posture, grip and load envelopes MOVE-G01 still owes; settling
	the body is the conservative outcome and never lets it continue under withdrawn terms.
	"""
	var profile: int = _cursor_profile_id[row]
	if not is_profile(profile):
		return false
	return _profile_revision[profile] == _cursor_profile_revision[row]


func _spend_budget(row: int, from_x: int, from_z: int, budget_x: int, budget_z: int) -> void:
	"""Walk this tick's released displacement along the route into `_here_x`/`_here_z`.

	CARRYING THE LEFTOVER IS THE WHOLE REASON THIS LOOPS. Clamping at each cell centre and dropping
	whatever budget remained silently loses part of every tick that happens to land on a boundary --
	a small resident measured 3072 u/s against its 3277 u/s cap that way, which looks exactly like
	the large-size cap and would have read as correct.

	KNOWN LIMITATION, NAMED NOT HIDDEN: budget left over on an axis the NEXT segment does not use
	(a turn inside one tick) is dropped rather than banked, bounded by one tick's step. Turn and
	segment entry/exit costs are MOVE-G01 parameter-pack outputs; inventing one here to absorb it
	would be inventing a production movement constant.
	"""
	var position_x: int = from_x
	var position_z: int = from_z
	var remaining_x: int = budget_x
	var remaining_z: int = budget_z
	for _pass: int in MAX_SEGMENTS_PER_TICK:
		_consume_into(position_x, _next_x[row], remaining_x)
		position_x = _step_position
		remaining_x = _step_budget
		_consume_into(position_z, _next_z[row], remaining_z)
		position_z = _step_position
		remaining_z = _step_budget
		if position_x != _next_x[row] or position_z != _next_z[row]:
			break
		_arrive_at_target(row)
		if _movement_phase[row] != MOTION_TRAVELLING or remaining_x + remaining_z <= 0:
			break
	_here_x = position_x
	_here_z = position_z


func _consume_into(current: int, target: int, budget: int) -> void:
	"""Move `current` toward `target` by at most `budget`, into `_step_position`/`_step_budget`."""
	if budget <= 0 or current == target:
		_step_position = current
		_step_budget = budget
		return
	var delta: int = target - current
	var distance: int = delta if delta > 0 else -delta
	if budget >= distance:
		_step_position = target
		_step_budget = budget - distance
		return
	_step_position = current + (budget if delta > 0 else -budget)
	_step_budget = 0


func _integrate_axis(row: int, is_x: bool) -> int:
	"""SET-MOVE-001 5's retained-remainder integration for one axis of the current segment.

	An axis with no displacement on this segment neither accumulates nor releases, so its retained
	fraction is exactly what it was when it last moved.
	"""
	var delta: int = _segment_delta(row, is_x)
	if delta == 0:
		return 0
	var factor: int = DIAGONAL_NUMERATOR_FACTOR if _segment_is_diagonal(row) \
		else ORTHOGONAL_NUMERATOR_FACTOR
	var accumulated: int = _speed_u_per_s[row] * factor
	accumulated += _remainder_x[row] if is_x else _remainder_z[row]
	var released: int = accumulated / REMAINDER_DENOMINATOR
	var remainder: int = accumulated % REMAINDER_DENOMINATOR
	if is_x:
		_remainder_x[row] = remainder
	else:
		_remainder_z[row] = remainder
	return released


func _segment_delta(row: int, is_x: bool) -> int:
	"""The signed remaining displacement on the current segment for one axis."""
	if is_x:
		return _next_x[row] - _pose.x
	return _next_z[row] - _pose.z


func _segment_is_diagonal(row: int) -> bool:
	"""True when the current route step moves in both X and Z, and so costs 14 rather than 10."""
	var from_cell: int = _grid_cell[row]
	var to_cell: int = _grid_next[row]
	if from_cell < 0 or to_cell < 0:
		return false
	var dx: int = SpatialWorld.cell_x_of(to_cell) - SpatialWorld.cell_x_of(from_cell)
	var dz: int = SpatialWorld.cell_z_of(to_cell) - SpatialWorld.cell_z_of(from_cell)
	return dx != 0 and dz != 0


func _height_at_into(x_units: int, z_units: int, out: IntMath.IntResult) -> bool:
	"""The authored surface height under a position, or an explicit refusal. Never a sentinel.

	THIS REFUSES BECAUSE 0 IS A REAL HEIGHT. `world_init.gd`'s `WATER_SURFACE_Y_UNITS` is 0, so a
	returned 0 for "the lookup failed" is indistinguishable from "standing on open water" -- and the
	value is written straight into `transforms.advance()`, which is authoritative state. A body
	whose position has left the map has no authored height, and the caller settles it ROUTE_LOST
	rather than committing a fabricated one. On the ordinary path the authored value is read and
	not assumed, which is how GDD 5.1's ford at -128 is travelled through rather than skimmed.

	THE SECOND REFUSAL IS UNREACHABLE AND KEPT ANYWAY. `cell_of_position_into()` only succeeds on an
	in-range cell, which is exactly what `height_units_into()` then checks, so no caller can reach
	its refusal through this function. A mutation that ignores that return value therefore survives
	and is equivalent, recorded as such in decision 0066 rather than removed: the guard costs one
	branch and stops the pair drifting apart if either module's bounds ever change.
	"""
	if not _world.cell_of_position_into(x_units, z_units, out):
		return false
	var cell: int = out.value
	return _world.height_units_into(cell, out)


func _arrive_at_target(row: int) -> void:
	"""The body reached the current route cell: step the cursor, or settle as arrived."""
	_grid_cell[row] = _grid_next[row]
	_cursor_index[row] += 1
	_advance_cursor_target(row)


func _advance_cursor_target(row: int) -> void:
	"""Point the motion row at the next route cell's centre, or settle when the route is spent."""
	var request_row: int = _cursor_request[row]
	var next_index: int = _cursor_index[row] + 1
	if not _navigation.route_cell_into(request_row, next_index, _scratch):
		_settle(row, MOTION_ARRIVED)
		return
	var cell: int = _scratch.value
	_grid_next[row] = cell
	_next_x[row] = SpatialWorld.cell_centre_x_units(cell)
	_next_z[row] = SpatialWorld.cell_centre_z_units(cell)


func _settle(row: int, phase: int) -> void:
	"""Leave travel for a terminal motion phase, retaining the remainders for inspection."""
	if _movement_phase[row] == MOTION_TRAVELLING:
		_travelling_count -= 1
	_movement_phase[row] = phase
	_vx[row] = 0
	_vz[row] = 0
	_grid_next[row] = NO_REQUEST


func _route_still_valid(row: int) -> bool:
	"""True while the attached request is still READY on the same route descriptor generation."""
	var request_row: int = _cursor_request[row]
	if request_row == NO_REQUEST or not _navigation.is_ready(request_row):
		return false
	var route: int = _navigation.request_route_id(request_row)
	return _navigation.route_generation_of(route) == _cursor_route_generation[row]


func _resident_ref_of(row: int) -> Vector2i:
	"""The owning resident's reference, or the null reference when that row holds no live resident.

	`residents.gd` already stores both halves of the reference per row, so the generation is read
	rather than reconstructed. A row whose resident has been despawned reads back NULL_REF, and the
	caller settles the motion instead of moving a body that no longer exists.
	"""
	return _residents.ref_of(row)


# --- observation -------------------------------------------------------------------------------------

func motion_phase(resident: Vector2i) -> int:
	"""The motion phase of a live resident, or MOTION_IDLE when the reference does not resolve."""
	var row: int = _motion_row(resident)
	if row < 0:
		return MOTION_IDLE
	return _movement_phase[row]


func motion_phase_name(resident: Vector2i) -> StringName:
	"""The motion phase of a live resident as its diagnostic StringName."""
	return MOTION_PHASE_NAMES[motion_phase(resident)]


func remainder_x_of(resident: Vector2i) -> int:
	"""The retained X displacement remainder, in `REMAINDER_DENOMINATOR`ths of a unit."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _remainder_x[row]


func remainder_z_of(resident: Vector2i) -> int:
	"""The retained Z displacement remainder, in `REMAINDER_DENOMINATOR`ths of a unit."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _remainder_z[row]


func speed_of(resident: Vector2i) -> int:
	"""The per-size movement cap this resident is travelling at, in u/second."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _speed_u_per_s[row]


func route_index_of(resident: Vector2i) -> int:
	"""How many route cells this resident has already reached."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _cursor_index[row]


func route_owner_id_of(resident: Vector2i) -> int:
	"""The persistent id this row's cursor was attached for, or NO_OWNER_ID when it follows none."""
	var row: int = _motion_row(resident)
	return NO_OWNER_ID if row < 0 else _cursor_owner_id[row]


func admitted_profile_of(resident: Vector2i) -> int:
	"""The profile id this resident's journey was admitted under, or NO_PROFILE when it follows none."""
	var row: int = _motion_row(resident)
	return NO_PROFILE if row < 0 else _cursor_profile_id[row]


func admitted_profile_revision_of(resident: Vector2i) -> int:
	"""The profile revision captured at admission, or 0 when this resident follows no route."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _cursor_profile_revision[row]


func admitted_mode_of(resident: Vector2i) -> int:
	"""The traversal mode this resident was admitted in, or NO_MODE when it follows no route."""
	var row: int = _motion_row(resident)
	return NO_MODE if row < 0 else _cursor_mode[row]


func admitted_load_g_of(resident: Vector2i) -> int:
	"""The committed load in grams this resident was admitted carrying."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _cursor_load_g[row]


func admitted_destination_revision_of(resident: Vector2i) -> int:
	"""The destination revision captured at admission, or 0 when this resident follows no route."""
	var row: int = _motion_row(resident)
	return 0 if row < 0 else _cursor_destination_revision[row]


func travelling_count() -> int:
	"""How many residents are currently mid-route."""
	return _travelling_count


func last_refusal() -> StringName:
	"""The refusal code from the most recent refusing call, or REFUSE_NONE after a success."""
	return _last_refusal
