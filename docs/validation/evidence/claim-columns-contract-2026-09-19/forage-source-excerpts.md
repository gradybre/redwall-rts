# forage claim boundary source excerpts

Full source SHA256 74694b212993599a8ffc0f488f2e45d6c81acdaba1297c4fd723c0860790dbcb

## Declarations

```gdscript
const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Rng := preload("res://scripts/core/rng.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const HARVEST_ZONE_CAPACITY: int = 128
const ZONE_LINK_CAPACITY: int = 16384
const PATCHES_PER_ZONE: int = 5
const FORAGE_PATCH_CAPACITY: int = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE
const FORAGE_CLAIM_CAPACITY: int = 8192
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z
const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
const ZONE_TYPE_RESERVED_1: int = Catalog.ZONE_TYPE["RESERVED_1"]
const ZONE_TYPE_FORAGE: int = Catalog.ZONE_TYPE["FORAGE"]
const ZONE_TYPE_FARM: int = Catalog.ZONE_TYPE["FARM"]
const ZONE_TYPE_ORCHARD: int = Catalog.ZONE_TYPE["ORCHARD"]
const ZONE_TYPE_FORESTRY: int = Catalog.ZONE_TYPE["FORESTRY"]
const ZONE_TYPE_QUARRY: int = Catalog.ZONE_TYPE["QUARRY"]
const ZONE_TYPE_STOCKPILE: int = Catalog.ZONE_TYPE["STOCKPILE"]
const ZONE_TYPE_CONSERVATION: int = Catalog.ZONE_TYPE["CONSERVATION"]
const ZONE_TYPE_COUNT: int = 9
const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4
const PATCH_BERRIES: int = 0
const PATCH_NUTS: int = 1
const PATCH_MUSHROOMS: int = 2
const PATCH_HERB: int = 3
const PATCH_ROOTS: int = 4
const PATCH_KEYS: Array[StringName] = [&"berries", &"nuts", &"mushrooms", &"herb", &"roots"]
const PATCH_CAPACITY_U: Array[int] = [300, 240, 180, 160, 300]
const PATCH_BASE_WORK_WU: Array[int] = [4, 5, 5, 8, 6]
const PATCH_REGROWTH_PER_1000: Array[int] = [120, 60, 100, 80, 70]
const PATCH_AVAILABILITY_PER_1000: Array[int] = [
const MILLI_PER_UNIT: int = 1000
const INITIAL_STOCK_NUMERATOR: int = 8
const INITIAL_STOCK_DENOMINATOR: int = 10
const SUSTAINABLE_FLOOR_PERCENT: int = 20
const INTENSIVE_FLOOR_PERCENT: int = 5
const PERCENT_DENOMINATOR: int = 100
const REGROWTH_DENOMINATOR: int = 1000000
const REGROWTH_MINIMUM_MILLI: int = MILLI_PER_UNIT
const WORK_NUMERATOR_SCALE: int = 1000000
const WORK_BASE_TERM: int = 1000
const WORK_SKILL_TERM: int = 40
const WORK_DANGER_TERM: int = 100
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3
const DANGEROUS_WORK_DANGER: int = 2
const INJURY_ROLL_MIN_DANGER: int = 1
const EXPOSURE_SEGMENT_WU: int = 60
const INJURY_ROLL_DENOMINATOR: int = 10000
const INJURY_DANGER_FACTOR: int = 8
const INJURY_CHANCE_MINIMUM: int = 1
const INJURY_HEALTH_LOSS: int = 10
const INJURY_SEVERITY: int = 1
const QUOTA_MODE_DOMAIN: String = "ForageQuotaMode"
const QUOTA_MODE_KEYS: Array[StringName] = [&"automatic", &"inherit", &"manual"]
const QUOTA_MODE_AUTOMATIC: int = 0
const QUOTA_MODE_INHERIT: int = 1
const QUOTA_MODE_MANUAL: int = 2
const QUOTA_MODE_COUNT: int = 3
const AUTOMATIC_TARGET_PER_1000: int = 800
const AUTOMATIC_TARGET_DENOMINATOR: int = 1000
const AUTOMATIC_ALLOWANCE_DENOMINATOR: int = 1000000
const AUTOMATIC_ALLOWANCE_TERM_MILLI: int = MILLI_PER_UNIT
const MANUAL_QUOTA_MIN_MILLI: int = 0
const MANUAL_QUOTA_MAX_MILLI: int = 1180000
const BYTES_PER_BYTE_COLUMN: int = 1
const BYTES_PER_INT32: int = 4
const BYTES_PER_INT64: int = 8
const NO_LINK: int = -1
const NO_CLAIM: int = -1
const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const REFUSE_NONE: StringName = &""
const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
const REFUSE_INVALID_ZONE_TYPE: StringName = &"INVALID_ZONE_TYPE"
const REFUSE_RESERVED_ZONE_TYPE: StringName = &"RESERVED_ZONE_TYPE"
const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
const REFUSE_INVALID_QUOTA: StringName = &"INVALID_QUOTA"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_TILE_COORDINATE: StringName = &"INVALID_TILE_COORDINATE"
const REFUSE_TILE_ALREADY_LINKED: StringName = &"TILE_ALREADY_LINKED"
const REFUSE_TILE_NOT_LINKED: StringName = &"TILE_NOT_LINKED"
const REFUSE_ZONE_LINK_CAPACITY: StringName = &"CAPACITY_ZONE_LINK"
const REFUSE_INVALID_PATCH_KIND: StringName = &"INVALID_PATCH_KIND"
const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
const REFUSE_PATCH_PRESENT: StringName = &"PATCH_ALREADY_PRESENT"
const REFUSE_PATCH_NOT_PRESENT: StringName = &"PATCH_NOT_PRESENT"
const REFUSE_STOCK_ABOVE_CAPACITY: StringName = &"STOCK_ABOVE_CAPACITY"
const REFUSE_PATCH_SET_SIZE: StringName = &"PATCH_SET_SIZE"
const REFUSE_PATCH_DORMANT: StringName = &"PATCH_DORMANT"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_BELOW_HARVEST_FLOOR: StringName = &"BELOW_HARVEST_FLOOR"
const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
const REFUSE_ZONE_DISABLED: StringName = &"ZONE_DISABLED"
const REFUSE_ZONE_PROTECTED: StringName = &"ZONE_PROTECTED"
const REFUSE_DANGEROUS_WORK_REFUSED: StringName = &"DANGEROUS_WORK_REFUSED"
const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
const REFUSE_BASIN_HAS_OWN_PATCHES: StringName = &"BASIN_HAS_OWN_PATCHES"
const REFUSE_ZONE_IS_BOUND: StringName = &"ZONE_IS_BOUND"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK"
const REFUSE_NO_RNG: StringName = &"NO_RNG"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_INVALID_QUOTA_MODE: StringName = &"INVALID_QUOTA_MODE"
const REFUSE_QUOTA_MODE_NOT_VALID_HERE: StringName = &"QUOTA_MODE_NOT_VALID_HERE"
const REFUSE_NO_JOB_STORE: StringName = &"NO_JOB_STORE"
const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_MEMBER"
const REFUSE_CLAIM_PRESENT: StringName = &"CLAIM_ALREADY_PRESENT"
const REFUSE_CLAIM_NOT_PRESENT: StringName = &"CLAIM_NOT_PRESENT"
const REFUSE_CLAIM_STALE_JOB: StringName = &"CLAIM_STALE_JOB"
const REFUSE_STOCK_RESERVED: StringName = &"STOCK_RESERVED"
const REFUSE_NOT_DAY_BOUNDARY: StringName = &"NOT_DAY_BOUNDARY"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
var _directory: EntityDirectory = null
var _owns_directory: bool = false
var _jobs: JobsScript = null
var _zone_present: PackedByteArray = PackedByteArray()
var _zone_type: PackedInt32Array = PackedInt32Array()
var _zone_danger: PackedInt32Array = PackedInt32Array()
var _zone_quota_milli: PackedInt64Array = PackedInt64Array()
var _zone_protected: PackedByteArray = PackedByteArray()
var _zone_enabled: PackedByteArray = PackedByteArray()
var _zone_ref_slot: PackedInt32Array = PackedInt32Array()
var _zone_ref_generation: PackedInt32Array = PackedInt32Array()
var _zone_basin_slot: PackedInt32Array = PackedInt32Array()
var _zone_basin_generation: PackedInt32Array = PackedInt32Array()
var _zone_harvested_today_milli: PackedInt64Array = PackedInt64Array()
var _zone_quota_reserved_milli: PackedInt64Array = PackedInt64Array()
var _zone_quota_mode: PackedByteArray = PackedByteArray()
var _zone_link_head: PackedInt32Array = PackedInt32Array()
var _zone_tile_count: PackedInt32Array = PackedInt32Array()
var _zone_patch_count: PackedInt32Array = PackedInt32Array()
var _live_zone_slots: PackedInt32Array = PackedInt32Array()
var _live_zone_count: int = 0
var _link_tile: PackedInt32Array = PackedInt32Array()
var _link_zone: PackedInt32Array = PackedInt32Array()
var _link_tile_next: PackedInt32Array = PackedInt32Array()
var _link_zone_next: PackedInt32Array = PackedInt32Array()
var _tile_link_head: PackedInt32Array = PackedInt32Array()
var _link_bump: int = 0
var _link_free_head: int = NO_LINK
var _link_used: int = 0
var _patch_present: PackedByteArray = PackedByteArray()
var _patch_item_id: PackedInt32Array = PackedInt32Array()
var _patch_zone_slot: PackedInt32Array = PackedInt32Array()
var _patch_zone_generation: PackedInt32Array = PackedInt32Array()
var _patch_stock_milli: PackedInt64Array = PackedInt64Array()
var _patch_capacity_milli: PackedInt64Array = PackedInt64Array()
var _patch_harvested_year_milli: PackedInt64Array = PackedInt64Array()
var _claim_active: PackedByteArray = PackedByteArray()
var _claim_job_slot: PackedInt32Array = PackedInt32Array()
var _claim_job_generation: PackedInt32Array = PackedInt32Array()
var _claim_designation_slot: PackedInt32Array = PackedInt32Array()
var _claim_designation_generation: PackedInt32Array = PackedInt32Array()
var _claim_basin_slot: PackedInt32Array = PackedInt32Array()
var _claim_basin_generation: PackedInt32Array = PackedInt32Array()
var _claim_patch_kind: PackedInt32Array = PackedInt32Array()
var _claim_remaining_milli: PackedInt64Array = PackedInt64Array()
var _claim_created_tick: PackedInt64Array = PackedInt64Array()
var _claim_persistent_id: PackedInt64Array = PackedInt64Array()
var _claim_count: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _math_b: IntMath.IntResult = IntMath.IntResult.new()
var _math_c: IntMath.IntResult = IntMath.IntResult.new()
var _pending_designation_slot: int = EntityDirectory.NULL_SLOT
var _pending_basin_slot: int = EntityDirectory.NULL_SLOT
var _pending_patch_row: int = -1
const SECTION_1_OWNER_KEY: String = "forage"
const SECTION_1_OWNER_SCHEMA_VERSION: int = 1
const SECTION_1_PRIMARY_COUNT: int = TILE_COUNT
const COLUMN_REFUSE_NONE: StringName = &""
const COLUMN_REFUSE_SHAPE: StringName = &"S1_FORAGE_COLUMN_SHAPE"
const COLUMN_REFUSE_HEAD_RANGE: StringName = &"S1_FORAGE_HEAD_RANGE"
const COLUMN_REFUSE_UNALLOCATED: StringName = &"S1_FORAGE_LINK_UNALLOCATED"
const COLUMN_REFUSE_WRONG_TILE: StringName = &"S1_FORAGE_LINK_WRONG_TILE"
const COLUMN_REFUSE_CYCLE: StringName = &"S1_FORAGE_LINK_CYCLE"
const COLUMN_REFUSE_DEAD_ZONE: StringName = &"S1_FORAGE_LINK_DEAD_ZONE"
const COLUMN_REFUSE_STALE_IDENTITY: StringName = &"S1_FORAGE_STALE_IDENTITY"
const COLUMN_REFUSE_CHAIN_DISAGREES: StringName = &"S1_FORAGE_CHAINS_DISAGREE"
const COLUMN_REFUSE_UNREACHABLE: StringName = &"S1_FORAGE_LINK_UNREACHABLE"
var _section_1_code: StringName = COLUMN_REFUSE_NONE
var _section_1_detail: String = ""
```

## claim_forage

```gdscript
func claim_forage(job_ref: Vector2i, designation_ref: Vector2i, kind: int, amount_milli: int,
		season: int, intensive: bool) -> OpResult:
	"""Reserve the COMPLETE intended collection for one Job. Returns its claim row.

	R05-QUOTA-005: quota and stock are preflighted and committed atomically, or every quantity is
	left unchanged. One pending claim per owning Job, naming one basin, one designation and one
	kind, so a second kind needs a second Job; shared work claims through its COORDINATOR, and a
	member Job is refused rather than reserving the same stock twice. Output capacity, consent and
	destination legality are the caller's preflights and are not checked here (header).
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	var request_code: StringName = _check_claim_request(designation_ref, kind, amount_milli,
		season, intensive)
	if request_code != REFUSE_NONE:
		return _refuse(request_code)
	if not _may_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli,
			_math_c):
		return _refuse(StringName(_math_c.error))
	_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli)
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, amount_milli)
	return _succeed(row, job_ref)


```

## _check_claim_owner

```gdscript
func _check_claim_owner(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Job may own a new forage claim on its own row."""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	if _claim_active[job_slot] != 1:
		return REFUSE_NONE
	if _claim_job_slot[job_slot] == job_ref.x and _claim_job_generation[job_slot] == job_ref.y:
		return REFUSE_CLAIM_PRESENT
	return REFUSE_CLAIM_STALE_JOB


```

## _check_claim_request

```gdscript
func _check_claim_request(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when the designation, kind, season and amount are claimable.

	Leaves the resolved designation row, basin row and patch row in `_pending_*` for the commit
	that immediately follows. Nothing between the two calls can re-enter this store.
	"""
	var zone_code: StringName = _check_harvest_zone(designation_ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if not zone_slot_of_into(designation_ref, _math_c):
		return StringName(_math_c.error)
	_pending_designation_slot = _math_c.value
	if not patch_row_for_zone_into(designation_ref, kind, _math_c):
		return StringName(_math_c.error)
	_pending_patch_row = _math_c.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if not availability_per_1000_into(kind, season, _math_c):
		return StringName(_math_c.error)
	if _math_c.value == 0:
		return REFUSE_PATCH_DORMANT
	return _check_claim_limits(designation_ref, kind, amount_milli, season, intensive)


```

## _check_claim_limits

```gdscript
func _check_claim_limits(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""`admissible <= min(available_quota, stock_available)`, with the floor reported separately."""
	if not available_quota_milli_into(designation_ref, season, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_QUOTA_REACHED
	if not harvest_floor_milli_into(_pending_patch_row, intensive, _math_c):
		return StringName(_math_c.error)
	if _patch_stock_milli[_pending_patch_row] - amount_milli < _math_c.value:
		return REFUSE_BELOW_HARVEST_FLOOR
	if not stock_available_milli_into(_pending_basin_slot, kind, intensive, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_STOCK_RESERVED
	return REFUSE_NONE


```

## _write_claim

```gdscript
func _write_claim(row: int, job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		amount_milli: int) -> void:
	"""Write one claim row and cache §4.5's release-order key from the owning Job.

	`created_tick` and the persistent ID are read from the Job exactly once here. Neither can
	change while that Job row lives, and both are rebuilt on load, so this is a cache of the
	Job's own fields and NOT a separate claim creation timestamp.
	"""
	var basin_ref: Vector2i = Vector2i(_zone_ref_slot[_pending_basin_slot],
		_zone_ref_generation[_pending_basin_slot])
	_claim_active[row] = 1
	_claim_job_slot[row] = job_ref.x
	_claim_job_generation[row] = job_ref.y
	_claim_designation_slot[row] = designation_ref.x
	_claim_designation_generation[row] = designation_ref.y
	_claim_basin_slot[row] = basin_ref.x
	_claim_basin_generation[row] = basin_ref.y
	_claim_patch_kind[row] = kind
	_claim_remaining_milli[row] = amount_milli
	_claim_created_tick[row] = _jobs.created_tick_of(row).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)
	_claim_count += 1


```

## _apply_collection

```gdscript
func _apply_collection(row: int, amount_milli: int) -> void:
	"""Ruling §4.2's collection transaction, in its stated order and with its `z == b` rule.

	Reserved falls and collected rises by the same amount on the basin, and again on the
	designation ONLY when it is a different row; stock falls and the annual counter rises once.
	A claim collected to zero closes, so its Job must reacquire before collecting again.
	"""
	var designation_slot: int = _pending_designation_slot
	var basin_slot: int = _pending_basin_slot
	_claim_remaining_milli[row] -= amount_milli
	_zone_quota_reserved_milli[basin_slot] -= amount_milli
	_zone_harvested_today_milli[basin_slot] += amount_milli
	if designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] -= amount_milli
		_zone_harvested_today_milli[designation_slot] += amount_milli
	_patch_stock_milli[_pending_patch_row] -= amount_milli
	_patch_harvested_year_milli[_pending_patch_row] += amount_milli
	if _claim_remaining_milli[row] == 0:
		_clear_claim_row(row)
		_claim_count -= 1


```

## _release_claim_row

```gdscript
func _release_claim_row(row: int) -> void:
	"""Return one claim's uncollected quantity to both allowances and empty its row.

	A zone that no longer exists is skipped rather than written to: destroy_zone() already zeroed
	its totals, and the basin it drew from keeps its own usage either way.
	"""
	var amount: int = _claim_remaining_milli[row]
	var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
	var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
	if basin_slot != EntityDirectory.NULL_SLOT:
		_zone_quota_reserved_milli[basin_slot] -= amount
	if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] -= amount
	_clear_claim_row(row)
	_claim_count -= 1


```

## _clear_claim_row

```gdscript
func _clear_claim_row(row: int) -> void:
	"""Return one claim row to exactly the state _clear_claim_columns() produces."""
	_claim_active[row] = 0
	_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_designation_slot[row] = EntityDirectory.NULL_SLOT
	_claim_designation_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_basin_slot[row] = EntityDirectory.NULL_SLOT
	_claim_basin_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_patch_kind[row] = -1
	_claim_remaining_milli[row] = 0
	_claim_created_tick[row] = 0
	_claim_persistent_id[row] = 0


```

## restore_claim

```gdscript
func restore_claim(job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		remaining_milli: int) -> OpResult:
	"""Write one saved claim record WITHOUT touching the derived reservation totals.

	R05-QUOTA-022's load half. A loader restores authoritative claim records and then calls
	rebuild_reservation_aggregates() before any admission or collection resumes; that is why this
	deliberately leaves `quota_reserved_milli` alone rather than maintaining it. It performs NO
	quota or stock preflight either: the world being restored already committed those. References,
	the patch kind and a positive quantity ARE validated, because a save that fails them must be
	refused rather than loaded.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if remaining_milli <= 0 or remaining_milli > MANUAL_QUOTA_MAX_MILLI:
		return _refuse(REFUSE_INVALID_AMOUNT)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	if not is_patch_kind(kind):
		return _refuse(REFUSE_INVALID_PATCH_KIND)
	if not zone_slot_of_into(designation_ref, _math):
		return _refuse(StringName(_math.error))
	_pending_designation_slot = _math.value
	if not patch_row_for_zone_into(designation_ref, kind, _math):
		return _refuse(StringName(_math.error))
	_pending_patch_row = _math.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, remaining_milli)
	return _succeed(row, job_ref)


```

## rebuild_reservation_aggregates

```gdscript
func rebuild_reservation_aggregates() -> OpResult:
	"""Rebuild every derived quota total from the claim table. Returns the claims counted.

	Ruling §4.7: "For each zone, reconstruct its outstanding total by summing active claims for
	which it is the basin or designation, COUNTING A CLAIM ONCE when those references are
	identical." Every zone total is zeroed first, so a stale cache cannot survive as an addend,
	and the release-order keys are re-read from the owning Jobs at the same time.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	_zone_quota_reserved_milli.fill(0)
	var counted: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		counted += 1
		_refresh_claim_order_key(row)
		var amount: int = _claim_remaining_milli[row]
		var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
		var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
		if basin_slot != EntityDirectory.NULL_SLOT:
			_zone_quota_reserved_milli[basin_slot] += amount
		if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
			_zone_quota_reserved_milli[designation_slot] += amount
	_claim_count = counted
	return _succeed(counted, NULL_REF)


```

## _refresh_claim_order_key

```gdscript
func _refresh_claim_order_key(row: int) -> void:
	"""Re-read §4.5's release-order key from the owning Job, leaving it alone when the Job is gone."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return
	var job_slot: int = _directory.get_typed_row(job_ref)
	_claim_created_tick[row] = _jobs.created_tick_of(job_slot).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)


```

## claim_row_of_into

```gdscript
func claim_row_of_into(job_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating claim_row_of(): validate the Job reference AND its generation into `out`.

	R05-QUOTA-023: a retired or reused Job row must not leave a prior generation's claim usable.
	The claim stores the reference it was created with, so a row whose Job has been destroyed and
	replaced refuses with CLAIM_STALE_JOB instead of acting for the newcomer.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	var row: int = _directory.get_typed_row(job_ref)
	if row < 0 or row >= FORAGE_CLAIM_CAPACITY:
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	if _claim_active[row] != 1:
		return out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
	if _claim_job_slot[row] != job_ref.x or _claim_job_generation[row] != job_ref.y:
		return out.refuse(String(REFUSE_CLAIM_STALE_JOB))
	return out.succeed(row)


```

## _stock_reserved_milli

```gdscript
func _stock_reserved_milli(basin_slot: int, kind: int) -> int:
	"""Sum `remaining_milli` over active claims naming this basin and kind.

	A STRAIGHT SCAN of the 8192 claim rows, deliberately: the ruling budgets any acceleration
	index separately and excludes it from §4.7's total, so none is added here. See the header's
	unmeasured-cost note.
	"""
	var basin_ref: Vector2i = Vector2i(_zone_ref_slot[basin_slot], _zone_ref_generation[basin_slot])
	var total: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or _claim_patch_kind[row] != kind:
			continue
		if _claim_basin_slot[row] != basin_ref.x or _claim_basin_generation[row] != basin_ref.y:
			continue
		total += _claim_remaining_milli[row]
	return total


```

## _newest_over_claim

```gdscript
func _newest_over_claim(season: int) -> int:
	"""The newest active claim whose basin or designation is over its allowance, or NO_CLAIM."""
	var best: int = NO_CLAIM
	var best_tick: int = 0
	var best_id: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or not _claim_is_over_allowance(row, season):
			continue
		var tick: int = _claim_created_tick[row]
		var persistent_id: int = _claim_persistent_id[row]
		if best != NO_CLAIM and not _key_is_newer(tick, persistent_id, best_tick, best_id):
			continue
		best = row
		best_tick = tick
		best_id = persistent_id
	return best


```

## _key_is_newer

```gdscript
func _key_is_newer(tick: int, persistent_id: int, other_tick: int, other_id: int) -> bool:
	"""True when `(tick, persistent_id)` sorts strictly after `(other_tick, other_id)`."""
	if tick != other_tick:
		return tick > other_tick
	return persistent_id > other_id


```

## reconcile_claims

```gdscript
func reconcile_claims(season: int) -> OpResult:
	"""Release whole claims, newest first, until every applicable limit is satisfied.

	Ruling §4.5: `maximum_outstanding_claims = max(0, Q - H)`, and excess is removed by releasing
	WHOLE claims in `(job.created_tick, job.persistent_id)` DESCENDING order -- a job's promised
	collection is never silently shrunk. One global order serves every zone at once, so a claim
	over on either of its two applicable limits is released exactly once. Returns the count.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	var released: int = 0
	while true:
		var row: int = _newest_over_claim(season)
		if row == NO_CLAIM:
			break
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


```

## run_midnight

```gdscript
func run_midnight(tick: int, season: int) -> OpResult:
	"""Apply the ruled quota order at one offset-calendar midnight. Returns claims released.

	The order is exactly §4.4's: reset collected totals, PRESERVE outstanding claims and their
	reservation totals, apply seasonal and automatic quota changes, release closure-invalidated
	claims and reconcile the excess -- and only then may a caller admit or collect again.

	`tick` must be a real crossing of `(tick + 4500) mod 18000`, taken from SimClock and never
	re-derived: tick 0 is 06:00 and the first midnight is tick 13500, so `tick % 18000 == 0` names
	06:00 of the next day and is refused here. Annual patch counters are NOT reset (that is
	reset_harvested_year(), at the year boundary), and no Job lease is renewed or extended.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	if not SimClock.is_day_boundary(tick):
		return _refuse(REFUSE_NOT_DAY_BOUNDARY)
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	_zone_harvested_today_milli.fill(0)
	var closed: int = _release_closed_claims(season)
	var reconciled: OpResult = reconcile_claims(season)
	if not reconciled.ok:
		return reconciled
	return _succeed(closed + reconciled.value, NULL_REF)


```

## _clear_claim_columns

```gdscript
func _clear_claim_columns() -> void:
	"""Refill every ForageClaim column with its empty value and drop the live count."""
	_claim_active.fill(0)
	_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_designation_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_designation_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_basin_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_basin_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_patch_kind.fill(-1)
	_claim_remaining_milli.fill(0)
	_claim_created_tick.fill(0)
	_claim_persistent_id.fill(0)
	_claim_count = 0


```
