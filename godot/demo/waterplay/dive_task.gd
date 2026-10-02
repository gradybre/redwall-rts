extends "res://demo/tunnel/tunnel_task.gd"
## A planned dive (MOVE-REQ-009/010, HAZ-002): out to a deep spot, down, a search of the bed, back up
## before the air runs short, and home with whatever was found. Decision 0196 (live demo).
##
## THE PLAN. At the spot, treading, the diver is admitted only with rest >= 4000 (HAZ-001; refused,
## it swims home) and air >= T + 300 ticks, T every submerged tick of the plan -- down to its depth,
## DIVE_SEARCH_TICKS on the bed, and up (swim_rules.gd `dive_ticks`). Short of air it waits at the
## surface, breathing (4 a tick), until the plan is admitted: entry is refused BEFORE submergence.
## Submerged, the air is spent a tick at a time on the demo clock (swim_state.gd, none while paused);
## at every step the ticks back to the surface B are worked out from the depth, and it turns for the
## surface once air <= B + 300 -- early, without a find, if the search is not done. Exhausted below,
## the rescue takes it (rescue.gd). A search done, `on_find` rolls what it brought up; the find is
## handed over once it is up the bank (`on_home`).

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const PHASE_DOWN: int = 0
const PHASE_OUT: int = 1
const PHASE_READY: int = 2
const PHASE_DESCEND: int = 3
const PHASE_SEARCH: int = 4
const PHASE_ASCEND: int = 5
const PHASE_BACK: int = 6
const PHASE_UP: int = 7
const PHASE_DONE: int = 8
const PHASE_WORDS: Array[String] = ["going down to the water", "swimming out to dive", "breathing before the dive",
	"diving", "searching the bed", "surfacing", "swimming home", "climbing out", "done"]

var spot: Vector2 = Vector2.ZERO
var phase: int = PHASE_DOWN
## The dive's depth below the surface, and how far down the diver is now (m).
var target_down_m: float = 0.0
var down_m: float = 0.0
## HAZ-002's T for this plan, ticks.
var planned_ticks: int = 0
## What was found (-1: nothing yet), and why the dive was refused or cut short ("" when it was not).
var find: int = -1
var refusal: StringName = Rules.REFUSE_NONE
var cut_short: bool = false

var _motion: MotionScript = null
var _links: LinksScript = null
var _on_find: Callable = Callable()
var _on_home: Callable = Callable()
var _land: Vector2 = Vector2.ZERO
var _water: Vector2 = Vector2.ZERO
var _search_s: float = 0.0
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(motion: MotionScript, links: LinksScript, target: Vector2, down: float, on_find: Callable,
		on_home: Callable) -> void:
	"""A dive at `target`, `down` metres below the surface; `on_find(brain) -> int` rolls a find when the
	search is done, `on_home(brain, find)` takes it once the diver is up the bank."""
	_motion = motion
	_links = links
	spot = target
	target_down_m = down
	planned_ticks = Rules.dive_ticks(roundi(down * 1000.0))
	_on_find = on_find
	_on_home = on_home
	_pick_connection(target)


func _pick_connection(at: Vector2) -> void:
	"""The connection of `at`'s body nearest it."""
	var body: int = _read.value if _links.body_at_into(at, _read) else 0
	if _links.nearest_connection_into(at, body, _read):
		_land = _links.conn_land[_read.value]
		_water = _links.conn_water[_read.value]


func _pick_way_in(from: Vector2) -> void:
	"""The connection best for going in from `from` towards the spot (water_links.gd)."""
	if _links.connection_for_into(spot, from, _read):
		_land = _links.conn_land[_read.value]
		_water = _links.conn_water[_read.value]


func site(brain: RefCounted) -> Vector2:
	"""Walk first to the land end of the connection best for the way in from where it stands."""
	_pick_way_in(brain.surface_point())
	return _land


func arrived(_brain: RefCounted) -> void:
	"""On the bank."""
	phase = PHASE_DOWN


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of the dive; false once it is over."""
	match phase:
		PHASE_DOWN:
			_step_down(brain, delta)
		PHASE_OUT:
			if _motion.swim(brain, spot, delta):
				phase = PHASE_READY
		PHASE_READY:
			_ready_to_dive(brain, delta)
		PHASE_DESCEND, PHASE_SEARCH, PHASE_ASCEND:
			_step_under(brain, delta)
		PHASE_BACK:
			if _motion.swim(brain, _water, delta):
				phase = PHASE_UP
		PHASE_UP:
			_step_up(brain, delta)
	return phase != PHASE_DONE


func _step_down(brain: RefCounted, delta: float) -> void:
	"""Down the bank; at the water, in -- checked again there like any swim (HAZ-001's edge entry: an injury since the
	order, say; decision 1045): refused, back up the bank, the reason kept."""
	if not _motion.walk_bank(brain, _water, delta):
		return
	refusal = _motion.state.swim_refusal(brain.index, false)
	if refusal != Rules.REFUSE_NONE:
		phase = PHASE_UP
		return
	brain.water_in()
	phase = PHASE_OUT


func _ready_to_dive(brain: RefCounted, delta: float) -> void:
	"""Tread at the spot until the plan is admitted (MOVE-REQ-009), or head home refused: hurt or under health 70
	(HAZ-001/002, decision 1045), or tired."""
	var state: StateScript = _motion.state
	_motion.tread(brain, spot, delta)
	if not state.fit(brain.index):
		refusal = Rules.REFUSE_HURT
		phase = PHASE_BACK
		return
	if not Rules.admits_swim(state.rest[brain.index]):
		refusal = Rules.REFUSE_TIRED
		phase = PHASE_BACK
		return
	if Rules.admits_dive(state.air[brain.index], planned_ticks):
		refusal = Rules.REFUSE_NONE
		phase = PHASE_DESCEND
		state.set_mode(brain.index, StateScript.MODE_DIVE)
		return
	refusal = Rules.REFUSE_AIR


func _step_under(brain: RefCounted, delta: float) -> void:
	"""Down, search, up -- turning for the surface as soon as the air says so (HAZ-002)."""
	var who: int = brain.index
	var state: StateScript = _motion.state
	var vertical: float = float(Rules.DIVE_VERTICAL_MM_S) / 1000.0 * delta
	if phase != PHASE_ASCEND and Rules.must_return(state.air[who], back_ticks()):
		cut_short = phase != PHASE_SEARCH or _search_s < float(Rules.DIVE_SEARCH_TICKS) / float(Rules.TICKS_PER_SECOND)
		phase = PHASE_ASCEND
	match phase:
		PHASE_DESCEND:
			down_m = minf(down_m + vertical, target_down_m)
			phase = PHASE_SEARCH if down_m >= target_down_m else phase
		PHASE_SEARCH:
			_search_s += delta
			if _search_s * float(Rules.TICKS_PER_SECOND) >= float(Rules.DIVE_SEARCH_TICKS):
				find = int(_on_find.call(brain)) if _on_find.is_valid() else -1
				phase = PHASE_ASCEND
		PHASE_ASCEND:
			down_m = maxf(down_m - vertical, 0.0)
	state.set_mode(who, StateScript.MODE_DIVE)
	_motion.dive_to(brain, spot, down_m)
	if phase == PHASE_ASCEND and down_m <= 0.0:
		state.set_mode(who, StateScript.MODE_SWIM)
		phase = PHASE_BACK


func back_ticks() -> int:
	"""HAZ-002's B: the ticks from here back up to air."""
	return WaterRules.ceil_div(roundi(down_m * 1000.0) * Rules.TICKS_PER_SECOND, Rules.DIVE_VERTICAL_MM_S)


func _step_up(brain: RefCounted, delta: float) -> void:
	"""Up the bank; home, hand the find over."""
	if not _motion.walk_bank(brain, _land, delta):
		return
	brain.water_out()
	_motion.state.set_mode(brain.index, StateScript.MODE_LAND)
	if _on_home.is_valid():
		_on_home.call(brain, find)
	phase = PHASE_DONE


func is_submerged() -> bool:
	"""Whether the diver is below the surface now."""
	return phase == PHASE_DESCEND or phase == PHASE_SEARCH or (phase == PHASE_ASCEND and down_m > 0.0)


func tire(brain: RefCounted) -> void:
	"""HAZ-003's return request: surface now if below, and swim home."""
	if phase == PHASE_DESCEND or phase == PHASE_SEARCH:
		cut_short = true
		phase = PHASE_ASCEND
	elif phase == PHASE_OUT or phase == PHASE_READY:
		_pick_connection(brain.position)
		phase = PHASE_BACK


func finish(brain: RefCounted) -> void:
	"""Over on its own: nothing is left in the water."""
	brain.water_out()


func label() -> String:
	"""What the diver is doing, in words (with the air left, below)."""
	if phase == PHASE_READY and refusal == Rules.REFUSE_AIR:
		return "breathing: the dive needs %d air" % (planned_ticks + Rules.AIR_CONTINGENCY_TICKS)
	return PHASE_WORDS[phase]
