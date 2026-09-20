# fishing claim boundary source excerpts

Full source SHA256 85f5437585155faab04c140641710014cf4cb477ea82eb08078aa0ac85f34025

## Declarations

```gdscript
const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const FISH_HABITAT_CAPACITY: int = 32
const SPECIES_PER_HABITAT: int = 3
const FISH_STOCK_CAPACITY: int = FISH_HABITAT_CAPACITY * SPECIES_PER_HABITAT
const FISHING_EFFORT_CLAIM_CAPACITY: int = 512
const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
const BYTES_PER_INT32: int = 4
const BYTES_PER_INT64: int = 8
const BYTES_PER_BYTE_COLUMN: int = 1
const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4
const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
const FIRST_SEASON_DAY: int = 1
const HABITAT_TYPE_DOMAIN: String = Catalog.HABITAT_TYPE_DOMAIN
const HABITAT_COAST: int = Catalog.HABITAT_TYPE["COAST"]
const HABITAT_LAKE: int = Catalog.HABITAT_TYPE["LAKE"]
const HABITAT_RIVER: int = Catalog.HABITAT_TYPE["RIVER"]
const HABITAT_TYPE_COUNT: int = 3
const RIVER_EFFORT_SLOTS: int = 4
const LAKE_EFFORT_SLOTS: int = 6
const COAST_EFFORT_SLOTS: int = 6
const EFFORT_SLOTS_BY_TYPE: Array[int] = [
const GEAR_BOAT: int = 0
const GEAR_HAND_NET: int = 1
const GEAR_ICE_KIT: int = 2
const GEAR_TRAP: int = 3
const GEAR_WEIR: int = 4
const GEAR_COUNT: int = 5
const GEAR_KEYS: Array[StringName] = [&"boat", &"hand_net", &"ice_kit", &"trap", &"weir"]
const BASIC_GEAR_EFFORT_SLOTS: int = 1
const HEAVY_GEAR_EFFORT_SLOTS: int = 2
const GEAR_EFFORT_SLOTS: Array[int] = [
const SPECIES_TROUT: int = 0
const SPECIES_DACE: int = 1
const SPECIES_SALMON: int = 2
const SPECIES_PERCH: int = 3
const SPECIES_CARP: int = 4
const SPECIES_WHITEFISH: int = 5
const SPECIES_HERRING: int = 6
const SPECIES_MACKEREL: int = 7
const SPECIES_MUSSEL: int = 8
const SPECIES_COUNT: int = HABITAT_TYPE_COUNT * SPECIES_PER_HABITAT
const HABITAT_SPECIES_ROWS: Array[int] = [
const SPECIES_HABITAT_TYPE: Array[int] = [
const SPECIES_KEYS: Array[StringName] = [
const SPECIES_CAPACITY_U: Array[int] = [600, 900, 600, 900, 700, 600, 1200, 900, 1000]
const SPECIES_AVAILABILITY_PER_1000: Array[int] = [
const SPECIES_RECOVERY_PER_1000: Array[int] = [80, 120, 100, 100, 80, 90, 120, 100, 60]
const TROUT_CLOSURE_FIRST_DAY: int = 5
const TROUT_CLOSURE_LAST_DAY: int = 7
const SALMON_RUN_FIRST_DAY: int = 1
const SALMON_RUN_LAST_DAY: int = 4
const SALMON_CLOSURE_FIRST_DAY: int = 5
const SALMON_CLOSURE_LAST_DAY: int = 8
const CARP_CLOSURE_FIRST_DAY: int = 8
const CARP_CLOSURE_LAST_DAY: int = 10
const HERRING_RUN_FIRST_DAY: int = 1
const HERRING_RUN_LAST_DAY: int = 4
const HERRING_RUN_PER_1000: int = 1500
const SALMON_AUTUMN_RESTOCK_U: int = 300
const MILLI_PER_UNIT: int = 1000
const INITIAL_STOCK_NUMERATOR: int = 8
const INITIAL_STOCK_DENOMINATOR: int = 10
const RECOVERY_DENOMINATOR: int = 1000
const RECRUITMENT_DIVISOR: int = 200
const DAILY_QUOTA_DIVISOR: int = 40
const MIN_STOCK_PERCENT: int = 30
const HARD_FLOOR_PERCENT: int = 10
const HABITAT_REFUGE_PERCENT: int = 25
const PERCENT_DENOMINATOR: int = 100
const DEPLETION_WARNING_PERCENT: int = 30
const RESTOCK_RECOVERY_PERCENT: int = 40
const CATCH_BASE_TERM: int = 1000
const CATCH_SKILL_TERM: int = 50
const CATCH_DENOMINATOR: int = 1000000000
const ABUNDANCE_SCALE: int = 1000
const ABUNDANCE_MIN: int = 200
const ABUNDANCE_MAX: int = 1000
const SKILL_LEVEL_MIN: int = 0
const SKILL_LEVEL_MAX: int = 10
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3
const JOB_STATE_CANCELLED: int = Catalog.JOB_STATE["CANCELLED"]
const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const REFUSE_NONE: StringName = &""
const REFUSE_HABITAT_NOT_PRESENT: StringName = &"HABITAT_NOT_PRESENT"
const REFUSE_STOCK_NOT_PRESENT: StringName = &"STOCK_NOT_PRESENT"
const REFUSE_INVALID_HABITAT_TYPE: StringName = &"INVALID_HABITAT_TYPE"
const REFUSE_INVALID_ZONE_REF: StringName = &"INVALID_ZONE_REF"
const REFUSE_INVALID_POLLUTION: StringName = &"INVALID_POLLUTION"
const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
const REFUSE_INVALID_PROTECTED_FRACTION: StringName = &"INVALID_PROTECTED_FRACTION"
const REFUSE_SPECIES_SET_SIZE: StringName = &"SPECIES_SET_SIZE"
const REFUSE_INVALID_SPECIES_ID: StringName = &"INVALID_SPECIES_ID"
const REFUSE_DUPLICATE_SPECIES_ID: StringName = &"DUPLICATE_SPECIES_ID"
const REFUSE_INVALID_SPECIES: StringName = &"INVALID_SPECIES"
const REFUSE_INVALID_SPECIES_INDEX: StringName = &"INVALID_SPECIES_INDEX"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_SEASON_DAY: StringName = &"INVALID_SEASON_DAY"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_INVALID_BASE_CATCH: StringName = &"INVALID_BASE_CATCH"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
const REFUSE_SPECIES_CLOSED: StringName = &"SPECIES_CLOSED"
const REFUSE_SPECIES_UNAVAILABLE: StringName = &"SPECIES_UNAVAILABLE"
const REFUSE_RESTOCKING: StringName = &"RESTOCKING"
const REFUSE_BELOW_STOCK_FLOOR: StringName = &"BELOW_STOCK_FLOOR"
const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
const REFUSE_EFFORT_SLOTS_FULL: StringName = &"EFFORT_SLOTS_FULL"
const REFUSE_EFFORT_SLOTS_RESERVED: StringName = &"EFFORT_SLOTS_RESERVED"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_INVALID_GEAR: StringName = &"INVALID_GEAR"
const REFUSE_INVALID_SLOT_COUNT: StringName = &"INVALID_SLOT_COUNT"
const REFUSE_NO_JOB_STORE: StringName = &"NO_JOB_STORE"
const REFUSE_NO_ZONE_STORE: StringName = &"NO_ZONE_STORE"
const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_MEMBER"
const REFUSE_EXPEDITION_NOT_PRESENT: StringName = &"EXPEDITION_NOT_PRESENT"
const REFUSE_EFFORT_CLAIM_PRESENT: StringName = &"EFFORT_CLAIM_ALREADY_PRESENT"
const REFUSE_EFFORT_CLAIM_STALE: StringName = &"EFFORT_CLAIM_STALE"
const REFUSE_NO_EFFORT_CLAIM: StringName = &"NO_EFFORT_CLAIM"
const REFUSE_AGGREGATE_MISMATCH: StringName = &"EFFORT_AGGREGATE_MISMATCH"
const REFUSE_ZONE_NOT_FISH: StringName = &"ZONE_NOT_FISH"
const REFUSE_ZONE_ALREADY_BOUND: StringName = &"ZONE_ALREADY_BOUND"
const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
const REFUSE_NO_HABITAT_FOR_BASIN: StringName = &"NO_HABITAT_FOR_BASIN"
const REFUSE_DUPLICATE_HABITAT_FOR_BASIN: StringName = &"DUPLICATE_HABITAT_FOR_BASIN"
const REFUSE_ESTUARY_PRESENT: StringName = &"ESTUARY_ALREADY_PRESENT"
var _directory: EntityDirectory = null
var _owns_directory: bool = false
var _zones: ForageScript = null
var _jobs: JobsScript = null
var _habitat_present: PackedByteArray = PackedByteArray()
var _habitat_type: PackedInt32Array = PackedInt32Array()
var _habitat_zone_slot: PackedInt32Array = PackedInt32Array()
var _habitat_zone_generation: PackedInt32Array = PackedInt32Array()
var _habitat_effort_slots: PackedInt32Array = PackedInt32Array()
var _habitat_pollution: PackedInt32Array = PackedInt32Array()
var _habitat_danger: PackedInt32Array = PackedInt32Array()
var _habitat_protected_fraction: PackedInt32Array = PackedInt32Array()
var _habitat_capacity_milli: PackedInt64Array = PackedInt64Array()
var _habitat_ref_slot: PackedInt32Array = PackedInt32Array()
var _habitat_ref_generation: PackedInt32Array = PackedInt32Array()
var _habitat_effort_used: PackedInt32Array = PackedInt32Array()
var _habitat_intensive: PackedByteArray = PackedByteArray()
var _live_habitat_slots: PackedInt32Array = PackedInt32Array()
var _live_habitat_count: int = 0
var _stock_present: PackedByteArray = PackedByteArray()
var _stock_habitat_slot: PackedInt32Array = PackedInt32Array()
var _stock_habitat_generation: PackedInt32Array = PackedInt32Array()
var _stock_species_id: PackedInt32Array = PackedInt32Array()
var _stock_population_milli: PackedInt64Array = PackedInt64Array()
var _stock_capacity_milli: PackedInt64Array = PackedInt64Array()
var _stock_harvested_today_milli: PackedInt64Array = PackedInt64Array()
var _stock_closed: PackedByteArray = PackedByteArray()
var _stock_restocking: PackedByteArray = PackedByteArray()
var _effort_claim_active: PackedByteArray = PackedByteArray()
var _effort_claim_expedition_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_habitat_slot: PackedInt32Array = PackedInt32Array()
var _effort_claim_habitat_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_job_slot: PackedInt32Array = PackedInt32Array()
var _effort_claim_job_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_slot_count: PackedInt32Array = PackedInt32Array()
var _effort_claim_count: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _math_b: IntMath.IntResult = IntMath.IntResult.new()
var _math_c: IntMath.IntResult = IntMath.IntResult.new()
var _effort_total_scratch: PackedInt32Array = PackedInt32Array()
var _pending_claim_row: int = -1
var _pending_habitat_slot: int = -1
```

## reserve_effort_slots

```gdscript
func reserve_effort_slots(expedition_ref: Vector2i, job_ref: Vector2i, habitat_ref: Vector2i,
		slot_count: int) -> OpResult:
	"""Reserve a cycle's WHOLE effort requirement at once. Returns the slots now taken.

	REQ-SET-050: "While a habitat's effort slots are occupied, the system shall queue further
	fishers rather than multiply yield with unbounded workers." This is the half that makes
	queueing necessary; the queue itself is the Job store's `JobState.QUEUED`.

	Ruling §5: the claim and the occupancy change are published TOGETHER, and a request that does
	not fit refuses without taking a single slot -- two single-slot calls without rollback are not
	a safe two-slot admission API. The claim row is the Expedition's typed row and only its
	coordinator Job may own it.
	"""
	var code: StringName = _refuse_effort_reservation(expedition_ref, job_ref, habitat_ref,
		slot_count)
	if code != REFUSE_NONE:
		return _refuse(code)
	var habitat_slot: int = _pending_habitat_slot
	_write_effort_claim(_pending_claim_row, expedition_ref, job_ref, habitat_ref, slot_count)
	_habitat_effort_used[habitat_slot] += slot_count
	return _succeed(_habitat_effort_used[habitat_slot], habitat_ref)


```

## _refuse_effort_reservation

```gdscript
func _refuse_effort_reservation(expedition_ref: Vector2i, job_ref: Vector2i,
		habitat_ref: Vector2i, slot_count: int) -> StringName:
	"""REFUSE_NONE when this cycle may take `slot_count` slots, with nothing written yet.

	Leaves the claim row and the habitat row in `_pending_*` for the commit that follows.
	"""
	var code: StringName = _refuse_effort_owner(expedition_ref, job_ref)
	if code != REFUSE_NONE:
		return code
	if not habitat_slot_of_into(habitat_ref, _math):
		return StringName(_math.error)
	_pending_habitat_slot = _math.value
	if slot_count <= 0:
		return REFUSE_INVALID_SLOT_COUNT
	var free: int = _habitat_effort_slots[_pending_habitat_slot] \
		- _habitat_effort_used[_pending_habitat_slot]
	if slot_count > free:
		return REFUSE_EFFORT_SLOTS_FULL
	return REFUSE_NONE


```

## _refuse_effort_owner

```gdscript
func _refuse_effort_owner(expedition_ref: Vector2i, job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Expedition row is free to claim and this Job may own the claim.

	The Expedition reference is validated THROUGH THE DIRECTORY FIRST and only then against the
	generation stored on its row, which is what distinguishes "this expedition already holds a
	claim" from "a previous expedition left one on the row this one reuses".
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] == 1:
		if _effort_claim_expedition_generation[row] == expedition_ref.y:
			return REFUSE_EFFORT_CLAIM_PRESENT
		return REFUSE_EFFORT_CLAIM_STALE
	_pending_claim_row = row
	return _refuse_effort_claim_job(job_ref)


```

## _refuse_effort_claim_job

```gdscript
func _refuse_effort_claim_job(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when `job_ref` is a live Job that may own a claim (decision 0017's coordinator).

	A MEMBER Job is refused: its coordinator owns the cycle, which is exactly what stops
	cancelling one party member from releasing the whole cycle's effort slots.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	return REFUSE_NONE


```

## _write_effort_claim

```gdscript
func _write_effort_claim(row: int, expedition_ref: Vector2i, job_ref: Vector2i,
		habitat_ref: Vector2i, slot_count: int) -> void:
	"""Write every column of one claim row and publish `active` last."""
	_effort_claim_expedition_generation[row] = expedition_ref.y
	_effort_claim_habitat_slot[row] = habitat_ref.x
	_effort_claim_habitat_generation[row] = habitat_ref.y
	_effort_claim_job_slot[row] = job_ref.x
	_effort_claim_job_generation[row] = job_ref.y
	_effort_claim_slot_count[row] = slot_count
	_effort_claim_active[row] = 1
	_effort_claim_count += 1


```

## _clear_effort_claim_row

```gdscript
func _clear_effort_claim_row(row: int) -> void:
	"""Return one claim row to the null/zero state unused rows carry."""
	_effort_claim_active[row] = 0
	_effort_claim_expedition_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_habitat_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_habitat_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_slot_count[row] = 0
	_effort_claim_count -= 1


```

## release_effort_slots

```gdscript
func release_effort_slots(expedition_ref: Vector2i) -> OpResult:
	"""Give back exactly this cycle's slots, exactly once. Returns the slots still taken.

	A second release finds no active claim and refuses, and a reference whose stored generation
	disagrees refuses too, so neither a double nor a stale call can free somebody else's slots.
	"""
	if not effort_claim_row_into(expedition_ref, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	var habitat_ref: Vector2i = effort_claim_habitat_ref_of(row)
	_release_effort_claim_row(row)
	if not habitat_slot_of_into(habitat_ref, _math):
		return _succeed(0, NULL_REF)
	return _succeed(_habitat_effort_used[_math.value], habitat_ref)


```

## _release_effort_claim_row

```gdscript
func _release_effort_claim_row(row: int) -> void:
	"""Debit the claimed habitat's occupancy and clear the row, in that order.

	The habitat is checked because a cleared store can leave a claim naming a row that is gone;
	destroy_habitat() refuses while any slot is reserved, so no ordinary path reaches that.
	"""
	if habitat_slot_of_into(effort_claim_habitat_ref_of(row), _math_b):
		_habitat_effort_used[_math_b.value] -= _effort_claim_slot_count[row]
	_clear_effort_claim_row(row)


```

## effort_claim_row_into

```gdscript
func effort_claim_row_into(expedition_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating effort_claim_row_of(): validate through the directory, then the row.

	Ruling §5's two-step ownership test. The directory settles that the Expedition reference is
	live; the stored generation then settles that THIS expedition wrote the claim, and not a
	previous one whose typed row it now occupies.
	"""
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return out.refuse(String(REFUSE_EXPEDITION_NOT_PRESENT))
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] != 1:
		return out.refuse(String(REFUSE_NO_EFFORT_CLAIM))
	if _effort_claim_expedition_generation[row] != expedition_ref.y:
		return out.refuse(String(REFUSE_EFFORT_CLAIM_STALE))
	return out.succeed(row)


```

## effort_claim_expedition_ref_of

```gdscript
func effort_claim_expedition_ref_of(row: int) -> Vector2i:
	"""The Expedition owning a live claim, rebuilt from the directory's reverse map.

	The claim slice stores only the generation (ruling §5's six I32 columns); the slot comes back
	from EntityDirectory.owner_slot_of_typed_row(), which reads a column that already exists.
	"""
	if not is_effort_claim_active(row):
		return NULL_REF
	var slot: int = _directory.owner_slot_of_typed_row(EntityDirectory.KIND_EXPEDITION, row)
	if slot == EntityDirectory.NULL_SLOT:
		return NULL_REF
	return Vector2i(slot, _effort_claim_expedition_generation[row])


```

## restore_effort_claim

```gdscript
func restore_effort_claim(expedition_ref: Vector2i, job_ref: Vector2i, habitat_ref: Vector2i,
		slot_count: int) -> OpResult:
	"""Write one saved claim WITHOUT touching the derived occupancy column. Returns its row.

	The load half of ruling §5. A loader restores authoritative claim records and then calls
	rebuild_effort_aggregates() before any cycle resumes, which is why this deliberately leaves
	`effort_used` alone: a stored total cannot prove ownership, so it is recomputed rather than
	trusted. Every reference and the slot count ARE validated, because a save that fails them
	must be refused rather than loaded.
	"""
	var code: StringName = _refuse_effort_owner(expedition_ref, job_ref)
	if code != REFUSE_NONE:
		return _refuse(code)
	if not habitat_slot_of_into(habitat_ref, _math):
		return _refuse(StringName(_math.error))
	if slot_count <= 0 or slot_count > _habitat_effort_slots[_math.value]:
		return _refuse(REFUSE_INVALID_SLOT_COUNT)
	_write_effort_claim(_pending_claim_row, expedition_ref, job_ref, habitat_ref, slot_count)
	return _succeed(_pending_claim_row, habitat_ref)


```

## rebuild_effort_aggregates

```gdscript
func rebuild_effort_aggregates() -> OpResult:
	"""Recompute every habitat's occupancy from the live claims. Returns the claims counted.

	Ruling §5: "Rebuild/validate the aggregate against live claims on load; a stored total alone
	cannot prove ownership." Every claim is validated and every habitat total is accumulated into
	scratch BEFORE the authoritative column is touched, so a save carrying a mismatched owner
	generation or an over-capacity total is refused with the column unchanged.
	"""
	var code: StringName = _accumulate_effort_totals()
	if code != REFUSE_NONE:
		return _refuse(code)
	for slot: int in FISH_HABITAT_CAPACITY:
		_habitat_effort_used[slot] = _effort_total_scratch[slot]
	return _succeed(_effort_claim_count, NULL_REF)


```

## validate_effort_aggregates

```gdscript
func validate_effort_aggregates() -> OpResult:
	"""Check the stored occupancy against the live claims, changing nothing. Returns the claims.

	The read-only half of the same contract: a loader that wants to know whether a snapshot is
	self-consistent asks this, and a total that no claim accounts for refuses.
	"""
	var code: StringName = _accumulate_effort_totals()
	if code != REFUSE_NONE:
		return _refuse(code)
	for slot: int in FISH_HABITAT_CAPACITY:
		if _habitat_effort_used[slot] != _effort_total_scratch[slot]:
			return _refuse(REFUSE_AGGREGATE_MISMATCH)
	return _succeed(_effort_claim_count, NULL_REF)


```

## _accumulate_effort_totals

```gdscript
func _accumulate_effort_totals() -> StringName:
	"""Total every live claim into `_effort_total_scratch`, validating each one on the way.

	REFUSE_NONE leaves a complete per-habitat occupancy in the scratch column and the live claim
	count in `_effort_claim_count`; any refusal leaves both meaningless and the caller applies
	neither.
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	_effort_total_scratch.fill(0)
	var counted: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var code: StringName = _refuse_stored_effort_claim(row)
		if code != REFUSE_NONE:
			return code
		counted += 1
		var slot: int = _math_b.value
		_effort_total_scratch[slot] += _effort_claim_slot_count[row]
		if _effort_total_scratch[slot] > _habitat_effort_slots[slot]:
			return REFUSE_AGGREGATE_MISMATCH
	_effort_claim_count = counted
	return REFUSE_NONE


```

## _refuse_stored_effort_claim

```gdscript
func _refuse_stored_effort_claim(row: int) -> StringName:
	"""REFUSE_NONE when one stored claim's owners are all live and agree. Leaves its habitat row
	in `_math_b` for the accumulation that follows."""
	var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	if _directory.get_typed_row(expedition_ref) != row:
		return REFUSE_EFFORT_CLAIM_STALE
	var code: StringName = _refuse_effort_claim_job(effort_claim_job_ref_of(row))
	if code != REFUSE_NONE:
		return code
	if not habitat_slot_of_into(effort_claim_habitat_ref_of(row), _math_b):
		return StringName(_math_b.error)
	if _effort_claim_slot_count[row] <= 0:
		return REFUSE_INVALID_SLOT_COUNT
	return REFUSE_NONE


```

## purge_stale_effort_claims

```gdscript
func purge_stale_effort_claims() -> OpResult:
	"""Release every claim whose Expedition is gone. Returns how many were released.

	A destroyed expedition cannot call release_effort_slots() for itself, so without this sweep
	its slots would stay taken forever. Nothing else releases a claim on somebody's behalf.
	"""
	var released: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
		if _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION) \
				and _directory.get_typed_row(expedition_ref) == row:
			continue
		_release_effort_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


```

## _effort_claim_is_cancelled

```gdscript
func _effort_claim_is_cancelled(row: int) -> bool:
	"""True when the coordinator Job behind one live claim is gone or in JobState.CANCELLED."""
	var job_ref: Vector2i = effort_claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return true
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return true
	return _jobs.state_of(job_slot).value == JOB_STATE_CANCELLED


```

## _clear_effort_claim_columns

```gdscript
func _clear_effort_claim_columns() -> void:
	"""Null and zero every claim row (ruling §5: "Null/zero unused rows")."""
	_effort_claim_active.fill(0)
	_effort_claim_expedition_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_habitat_slot.fill(EntityDirectory.NULL_SLOT)
	_effort_claim_habitat_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
	_effort_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_slot_count.fill(0)
	_effort_total_scratch.fill(0)
	_effort_claim_count = 0
	_pending_claim_row = -1
	_pending_habitat_slot = -1


```
