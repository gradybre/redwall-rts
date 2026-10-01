extends RefCounted
## Residents walk over the trees' roots, not through them. Decision 0196 (live demo); decision 0301
## (review F40) for the roots themselves. Presentation only: it raises a surface resident's drawn feet
## (the brain's `ground_y_m`, which only the tunnels otherwise set) onto the roots of any mature tree,
## felled stump or young tree it stands on, and lets it down again beyond. Only while the trees are
## the staged models: a placeholder tree has no roots.
##
## THE ROOTS are each model's own support heightfield (forest_root_field.gd), baked from its mesh and
## read in the tree's local space -- its position, its YAW and its size -- so a walker stands on a
## root where one is drawn and on the ground between two. A young tree's field is read at its drawn
## scale (`use_fields`' `mound_scale`: the view's), so a young oak lifts a walker a third as high.
##
## Per frame it looks at each resident against the trees in its own and the eight neighbouring cells
## of a bucket grid built once over the trees' fixed positions -- a reach test, then (inside it) a
## rotation and four reads of the field -- allocating nothing.

const StandScript := preload("res://demo/forestry/forest_stand.gd")
const FieldScript := preload("res://demo/forestry/forest_root_field.gd")
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
## Per StandScript.LOOK_*: the model's root field (null: that look has none -- nothing lifts).
var _fields: Array[FieldScript] = []
## `mound_scale(t) -> float`: how large tree `t`'s roots are drawn now (0: none).
var _mound_scale: Callable = Callable()


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
	"""The highest root under a point (0 on open ground)."""
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


func use_fields(fields: Array[FieldScript], mound_scale: Callable) -> void:
	"""Stand walkers on these root fields (per look), each tree's read at `mound_scale(t)` of its size."""
	_fields = fields
	_mound_scale = mound_scale


func _cell_height(cell: int, at: Vector2) -> float:
	"""The highest root of one cell's trees under `at`."""
	var best: float = 0.0
	for k: int in _cell_count[cell]:
		var t: int = _cell_trees[cell * PER_CELL + k]
		var field: FieldScript = _fields[_stand.look[t]] if _stand.look[t] < _fields.size() else null
		if field == null:
			continue
		var size: float = _stand.size[t] * float(_mound_scale.call(t))
		var reach: float = field.reach_m * size * 1.5
		if size <= 0.0 or at.distance_squared_to(_stand.at[t]) > reach * reach:
			continue
		best = maxf(best, field.height_at(at, _stand.at[t], _stand.yaw[t], size))
	return best


func apply() -> void:
	"""Lift every resident on the surface onto the roots under it, or let it down onto the ground there
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
