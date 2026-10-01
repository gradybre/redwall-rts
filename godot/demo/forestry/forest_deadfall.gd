extends RefCounted
## Deadfall: windfall branches lying in the woods. Decision 0196 (live demo). Presentation only.
##
## No document specifies deadfall (the GDD's forage table has no wood row), so everything here is a
## DEMO VALUE, named in forest_rules.gd: a pile of 1.0..2.0 U falls under a tree each day, three more
## after a storm, never more than DEADFALL_MAX lying; gathering one is slow (20 WU a U) and yields
## little -- wood without felling, for the early game and for protected woods, whose trees are never
## cut but whose fallen branches may be picked up.
##
## Piles are rows reused with a GENERATION (like an EntityRef): a job holds (pile, generation), so a
## pile gathered by someone else and a new one fallen in its row are never confused. Where a pile
## falls is drawn from this module's own seeded generator -- the same sequence on every run.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")

const SEED: int = 19870
## A pile falls this far from the trunk it came from (m, demo): at the crown's edge, where it can be
## seen from above and reached round the root mound.
const FALL_MIN_M: float = 6.0
const FALL_MAX_M: float = 8.5
const ATTEMPTS_PER_PILE: int = 8
const REFUSE_NO_PILE: String = "NO_DEADFALL_HERE"

var live: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var at: PackedVector2Array = PackedVector2Array()
var yaw: PackedFloat32Array = PackedFloat32Array()
var milli: PackedInt64Array = PackedInt64Array()
var revision: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	"""Size the rows once; nothing lying; the generator seeded."""
	live.resize(Rules.DEADFALL_MAX)
	generation.resize(Rules.DEADFALL_MAX)
	at.resize(Rules.DEADFALL_MAX)
	yaw.resize(Rules.DEADFALL_MAX)
	milli.resize(Rules.DEADFALL_MAX)
	_rng.seed = SEED


func is_live(pile: int, gen: int) -> bool:
	"""Whether (pile, gen) still names a pile lying there."""
	return pile >= 0 and pile < Rules.DEADFALL_MAX and live[pile] == 1 and generation[pile] == gen


func live_count() -> int:
	"""How many piles are lying."""
	return live.count(1)


func total_milli() -> int:
	"""All the deadfall's wood, milli-U."""
	var sum: int = 0
	for pile: int in Rules.DEADFALL_MAX:
		sum += milli[pile] if live[pile] == 1 else 0
	return sum


func spawn(wanted: int, sources: PackedVector2Array, standable: Callable) -> int:
	"""Let up to `wanted` piles fall under trees at `sources`, where `standable(at: Vector2) -> bool`
	allows (clear of obstacles, within reach). Returns how many fell."""
	var fallen: int = 0
	if sources.is_empty():
		return 0
	for n: int in wanted:
		var row: int = live.find(0)
		if row < 0:
			break
		if _fall_into_row(row, sources, standable):
			fallen += 1
	if fallen > 0:
		revision += 1
	return fallen


func _fall_into_row(row: int, sources: PackedVector2Array, standable: Callable) -> bool:
	"""Draw a spot under a source tree for pile `row`; false when no attempt landed somewhere standable."""
	for attempt: int in ATTEMPTS_PER_PILE:
		var source: Vector2 = sources[_rng.randi_range(0, sources.size() - 1)]
		var spot: Vector2 = source + Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(FALL_MIN_M, FALL_MAX_M)
		var steps: int = (Rules.DEADFALL_MAX_MILLI - Rules.DEADFALL_MIN_MILLI) / Rules.DEADFALL_STEP_MILLI
		var amount: int = Rules.DEADFALL_MIN_MILLI + _rng.randi_range(0, steps) * Rules.DEADFALL_STEP_MILLI
		var turn: float = _rng.randf_range(-PI, PI)
		if not bool(standable.call(spot)):
			continue
		live[row] = 1
		generation[row] += 1
		at[row] = spot
		yaw[row] = turn
		milli[row] = amount
		return true
	return false


func take_into(pile: int, gen: int, out: IntMath.IntResult) -> bool:
	"""Gather a whole pile: `out.value` is its wood; the row is freed. Refuses a pile no longer there."""
	if not is_live(pile, gen):
		return out.refuse(REFUSE_NO_PILE)
	live[pile] = 0
	var amount: int = milli[pile]
	milli[pile] = 0
	revision += 1
	return out.succeed(amount)


func nearest_into(point: Vector2, reach_m: float, out: IntMath.IntResult) -> bool:
	"""The lying pile nearest `point` within `reach_m`, into `out`."""
	var best: float = reach_m * reach_m
	var found: bool = false
	for pile: int in Rules.DEADFALL_MAX:
		if live[pile] == 1 and at[pile].distance_squared_to(point) <= best:
			best = at[pile].distance_squared_to(point)
			found = out.succeed(pile)
	return found or out.refuse(REFUSE_NO_PILE)
