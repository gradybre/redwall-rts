extends RefCounted
## Residents walk over the trees' root mounds, not through them. Decision 0196 (live demo).
## Presentation only: it raises a surface resident's drawn feet (the brain's `ground_y_m`, which only
## the tunnels otherwise set) onto the mound of any mature tree or felled stump it stands on
## (forest_roots.gd), and lets it down again beyond. Only while the trees are the staged models: a
## placeholder tree has no mound.
##
## Per frame it looks at each resident against the trees in its own and the eight neighbouring cells
## of a bucket grid built once over the trees' fixed positions -- a handful of distance checks each,
## allocating nothing.

const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")

const CELL_M: float = 10.0
const GRID_HALF_CELLS: int = 8
const GRID_SIDE: int = 2 * GRID_HALF_CELLS
## A cell holds at most this many trees (saplings stand 2.5 m apart at the densest).
const PER_CELL: int = 12

var enabled: bool = false

var _stand: StandScript = null
var _cast: DemoCastScript = null
var _cell_trees: PackedInt32Array = PackedInt32Array()
var _cell_count: PackedInt32Array = PackedInt32Array()
var _lifted: PackedByteArray = PackedByteArray()


func configure(stand: StandScript, cast: DemoCastScript) -> void:
	"""Bucket the trees once (their spots never move)."""
	_stand = stand
	_cast = cast
	_cell_trees.resize(GRID_SIDE * GRID_SIDE * PER_CELL)
	_cell_count.resize(GRID_SIDE * GRID_SIDE)
	_cell_count.fill(0)
	for t: int in stand.count():
		var cell: int = _cell_of(stand.at[t])
		if cell >= 0 and _cell_count[cell] < PER_CELL:
			_cell_trees[cell * PER_CELL + _cell_count[cell]] = t
			_cell_count[cell] += 1
	_lifted.resize(cast.actor_count() if cast != null else 0)


static func _cell_of(at: Vector2) -> int:
	"""The grid cell holding `at` (-1 off the grid)."""
	var cx: int = floori(at.x / CELL_M) + GRID_HALF_CELLS
	var cz: int = floori(at.y / CELL_M) + GRID_HALF_CELLS
	if cx < 0 or cz < 0 or cx >= GRID_SIDE or cz >= GRID_SIDE:
		return -1
	return cz * GRID_SIDE + cx


func height_at(at: Vector2) -> float:
	"""The highest mound under a point (0 on open ground)."""
	var best: float = 0.0
	var cx: int = floori(at.x / CELL_M) + GRID_HALF_CELLS
	var cz: int = floori(at.y / CELL_M) + GRID_HALF_CELLS
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var x: int = cx + dx
			var z: int = cz + dz
			if x < 0 or z < 0 or x >= GRID_SIDE or z >= GRID_SIDE:
				continue
			best = maxf(best, _cell_height(z * GRID_SIDE + x, at))
	return best


func _cell_height(cell: int, at: Vector2) -> float:
	"""The highest mound of one cell's trees under `at`."""
	var best: float = 0.0
	for k: int in _cell_count[cell]:
		var t: int = _cell_trees[cell * PER_CELL + k]
		var state: int = _stand.state_of(t)
		if state != StandScript.STATE_MATURE and state != StandScript.STATE_STUMP:
			continue
		best = maxf(best, Roots.height_at(_stand.look[t], _stand.size[t], _stand.at[t].distance_to(at)))
	return best


func apply() -> void:
	"""Lift every resident on the surface onto the mound under it, or let it down onto the ground there
	(the carved bank's height, demo/waterplay/); a resident in a tunnel or in the water is left alone."""
	if not enabled or _cast == null:
		return
	for i: int in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		if actor.brain.underground or actor.brain.in_water:
			_lifted[i] = 0
			continue
		var y: float = height_at(actor.brain.position)
		if y <= 0.0 and _lifted[i] == 0:
			continue
		_lifted[i] = 1 if y > 0.0 else 0
		if y <= 0.0:
			y = _cast.space().crossings.ground_y_m(actor.brain.position)
		actor.brain.ground_y_m = y
		actor.position.y = y
