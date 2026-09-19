extends RefCounted
## Derived family stage/size/season rate table (FAMILY-RULES-R01 v1).
##
## Publishes two private flat 18-value int64 tables of hunger decay rate and daily nutrition
## demand, built once from checked IntMath arithmetic in _init(). This helper owns no
## authoritative world state: it neither activates family gameplay nor is consumed by
## Needs/Residents yet. Only int_math.gd is preloaded, to avoid a future preload cycle with
## the eventual Needs/Residents consumers.
##
## Index mapping: index = life_stage*6 + size_class*2 + (1 if winter else 0), for
## life_stage in 0..2 (ADULT=0, CHILD=1, ELDER=2) and size_class in 0..2
## (SMALL=0, MEDIUM=1, LARGE=2). These IDs are local and protected; equality with
## Residents/Needs identities is asserted independently by tests, not by this helper.

const IntMath := preload("res://scripts/core/int_math.gd")

const TABLE_COUNT: int = 18

const STAGE_MULT: Array[int] = [1000, 750, 1000]
const SIZE_MULT: Array[int] = [1000, 1200, 1600]
const SEASON_MULT: Array[int] = [1000, 1200]

const HUNGER_BASE: int = 250000
const DEMAND_BASE: int = 6000
const DENOM: int = 1000000000

const REFUSE_TABLE_UNAVAILABLE: String = "FAMILY_STAGE_RULES_UNAVAILABLE"
const REFUSE_STAGE_INVALID: String = "FAMILY_STAGE_INVALID"
const REFUSE_SIZE_INVALID: String = "FAMILY_SIZE_INVALID"

var _hunger_rates_milli: PackedInt64Array
var _daily_demand_np: PackedInt64Array
var _ready: bool = false


func _init() -> void:
	"""Build both 18-row derived tables via checked arithmetic; leave _ready false on any failure."""
	_hunger_rates_milli = PackedInt64Array()
	_hunger_rates_milli.resize(TABLE_COUNT)
	_daily_demand_np = PackedInt64Array()
	_daily_demand_np.resize(TABLE_COUNT)
	_ready = _build_tables()


func _build_tables() -> bool:
	"""Fill both tables for every stage/size/winter combination; return false on the first refusal."""
	for stage: int in range(3):
		for size: int in range(3):
			for winter_i: int in range(2):
				var index: int = stage * 6 + size * 2 + winter_i
				var hunger_result: IntMath.IntResult = IntMath.IntResult.new()
				if not _compute_value_into(HUNGER_BASE, STAGE_MULT[stage], SIZE_MULT[size], SEASON_MULT[winter_i], hunger_result):
					return false
				_hunger_rates_milli[index] = hunger_result.value
				var demand_result: IntMath.IntResult = IntMath.IntResult.new()
				if not _compute_value_into(DEMAND_BASE, STAGE_MULT[stage], SIZE_MULT[size], SEASON_MULT[winter_i], demand_result):
					return false
				_daily_demand_np[index] = demand_result.value
	return true


func _compute_value_into(base: int, stage_mult: int, size_mult: int, season_mult: int, out: IntMath.IntResult) -> bool:
	"""Compute floor(base*stage_mult*size_mult*season_mult / DENOM) via checked steps into out.

	Each checked_mul_into result is copied into a local before the next call reuses `out` as
	scratch, matching int_math.gd's own aliasing discipline. Returns out.ok.
	"""
	if not IntMath.checked_mul_into(base, stage_mult, out):
		return false
	var step1: int = out.value
	if not IntMath.checked_mul_into(step1, size_mult, out):
		return false
	var step2: int = out.value
	if not IntMath.checked_mul_into(step2, season_mult, out):
		return false
	var product: int = out.value
	return IntMath.floor_div_into(product, DENOM, out)


func is_ready() -> bool:
	"""True only once both 18-row tables were built and checked without refusal in _init()."""
	return _ready


func hunger_rate_milli_into(life_stage: int, size_class: int, winter: bool, out: IntMath.IntResult) -> bool:
	"""Write the positive hunger decay rate (milli-points/hour) for the given inputs into out.

	Refuses in precedence order: table unavailable, then invalid life_stage, then invalid
	size_class. Never indexes or multiplies life_stage/size_class before both are validated.
	Returns out.ok.
	"""
	if not _ready:
		return out.refuse(REFUSE_TABLE_UNAVAILABLE)
	if life_stage < 0 or life_stage > 2:
		return out.refuse(REFUSE_STAGE_INVALID)
	if size_class < 0 or size_class > 2:
		return out.refuse(REFUSE_SIZE_INVALID)
	var index: int = life_stage * 6 + size_class * 2 + (1 if winter else 0)
	return out.succeed(_hunger_rates_milli[index])


func daily_demand_np_into(life_stage: int, size_class: int, winter: bool, out: IntMath.IntResult) -> bool:
	"""Write the integer nutrition points/day for one resident of the given inputs into out.

	Refuses in the same precedence order as hunger_rate_milli_into: table unavailable, then
	invalid life_stage, then invalid size_class. Returns out.ok.
	"""
	if not _ready:
		return out.refuse(REFUSE_TABLE_UNAVAILABLE)
	if life_stage < 0 or life_stage > 2:
		return out.refuse(REFUSE_STAGE_INVALID)
	if size_class < 0 or size_class > 2:
		return out.refuse(REFUSE_SIZE_INVALID)
	var index: int = life_stage * 6 + size_class * 2 + (1 if winter else 0)
	return out.succeed(_daily_demand_np[index])
