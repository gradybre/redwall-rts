extends "res://demo/tunnel/tunnel_task.gd"
## A player's swim: out to a spot in the water, and tread water there until ordered on. Decision 0196
## (live demo). Presentation over integer rules. The resident walks (on land, by the planner) to the
## body's validated bank connection nearest the spot (TRV-W02; water_links.gd), goes down the bank and
## in -- refused there, and walked back up, when it may not swim now (HAZ-001: capability, consent,
## rest >= 4000) -- swims out, and treads the spot against the flow. Tiring there (HAZ-003's return
## at rest <= 1500: `tire`) it swims back to the nearest connection and climbs out; exhausted first,
## the rescue takes it (rescue.gd). Another order swims it ashore first (resident_brain.gd, the
## crossing hook's `swim_ashore`).

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const PHASE_DOWN: int = 0
const PHASE_OUT: int = 1
const PHASE_TREAD: int = 2
const PHASE_BACK: int = 3
const PHASE_UP: int = 4
const PHASE_DONE: int = 5
const PHASE_WORDS: Array[String] = ["going down to the water", "swimming out", "treading water",
	"swimming back, tired", "climbing out", "done"]

var spot: Vector2 = Vector2.ZERO
var phase: int = PHASE_DOWN
## Why the swim was refused at the water ("" when it was not).
var refusal: StringName = Rules.REFUSE_NONE

var _motion: MotionScript = null
var _links: LinksScript = null
var _land: Vector2 = Vector2.ZERO
var _water: Vector2 = Vector2.ZERO
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(motion: MotionScript, links: LinksScript, target: Vector2) -> void:
	"""A swim out to `target` (a point in the water) through `links`' nearest connection."""
	_motion = motion
	_links = links
	spot = target
	_pick_connection(target)


func _pick_connection(at: Vector2) -> void:
	"""The connection of `at`'s body nearest it, into `_land` / `_water`."""
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
	"""On the bank: go down to the water."""
	phase = PHASE_DOWN


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of the swim; false once it is over."""
	match phase:
		PHASE_DOWN:
			if _motion.walk_bank(brain, _water, delta):
				_enter(brain)
		PHASE_OUT:
			if _motion.swim(brain, spot, delta):
				phase = PHASE_TREAD
		PHASE_TREAD:
			_motion.tread(brain, spot, delta)
		PHASE_BACK:
			if _motion.swim(brain, _water, delta):
				phase = PHASE_UP
		PHASE_UP:
			if _motion.walk_bank(brain, _land, delta):
				_out(brain)
	return phase != PHASE_DONE


func _enter(brain: RefCounted) -> void:
	"""At the waterline: in, when it may swim now; else back up the bank, the reason kept (HAZ-001:
	an explicit order does not bypass consent either)."""
	refusal = _motion.state.swim_refusal(brain.index, false)
	if refusal != Rules.REFUSE_NONE:
		phase = PHASE_UP
		return
	brain.water_in()
	phase = PHASE_OUT


func _out(brain: RefCounted) -> void:
	"""Up on the bank: out of the water, the swim over."""
	brain.water_out()
	_motion.state.set_mode(brain.index, StateScript.MODE_LAND)
	phase = PHASE_DONE


func tire(brain: RefCounted) -> void:
	"""HAZ-003's return: swim to the nearest connection and climb out."""
	if phase != PHASE_OUT and phase != PHASE_TREAD:
		return
	_pick_connection(brain.position)
	phase = PHASE_BACK


func finish(brain: RefCounted) -> void:
	"""Over on its own: nothing is left in the water."""
	brain.water_out()


func label() -> String:
	"""What the swimmer is doing, in words."""
	return PHASE_WORDS[phase]
