extends RefCounted
## A PRESENTATION-OWNED STAND-IN FOR THE POSES THE SIMULATION DOES NOT YET HOLD, and the file to
## delete the day it does.
##
## ---------------------------------------------------------------------------------------
## THE BLOCKER, NAMED RATHER THAN PAPERED OVER (AGENTS.md: "do not invent a constant").
##
##   1. NO RESIDENT IN THE RUNNING GAME HAS A POSITION. `settlement_system.gd` composes fourteen
##      core stores and `transforms.gd` is not among them: `grep -rn "transforms\.gd" godot/scripts`
##      finds only `movement.gd`'s preload and two prose mentions. ARCH-SYS-001 storage exists and
##      is tested; nothing in the boot path ever calls `place()`.
##   2. GDD 5.1 AUTHORS NO RESIDENT SPAWN COORDINATES. It authors the twelve-resident cohort, the
##      starting inventory and (5.9) seven building footprints, and says only that "initial room
##      assignments follow resident ID ascending and bed ID ascending". Beds live in a Furniture
##      store that does not exist -- `world_init.gd`'s own header records the starter buildings,
##      beds and containers as BLOCKED. So the position each resident SHOULD hold is not merely
##      unimplemented, it is unauthored.
##
## Those two together mean a renderer bound to the real settlement draws nothing. This object is
## the smallest honest thing that makes the crowd visible without pretending either gap is closed.
##
## ---------------------------------------------------------------------------------------
## WHAT KEEPS IT FROM BECOMING A LIE.
##
##   * THE STORE IS PRIVATE TO PRESENTATION. The `transforms.gd` instance below is created HERE
##     and handed only to the renderer. `settlement_system.gd` does not own it, no tick stage
##     reads it, no command writes it, and it is in no save section -- so no gameplay outcome can
##     depend on a tile chosen here. When movement composes the real ARCH-SYS-001 store, the
##     renderer's `bind_stores()` takes THAT one and this file is deleted whole.
##   * THE GEOMETRY IS 5.1's, ONLY THE ASSIGNMENT IS NOT. Every number below is read from
##     `world_init.gd`: the hall footprint's authored origin and extent, the 2048-unit tile pitch,
##     the 1024-unit tile centre, and the land elevation. What is NOT authored anywhere, and is
##     therefore this file's own choice, is WHICH cleared tile a given resident stands on. That
##     one unauthored decision is confined to `muster_tile_x/z()` and marked there.
##   * IT WRITES POSES ONCE AND NEVER MOVES ANYBODY. There is no per-tick call here. Residents
##     stand still because nothing in this repository may decide that they walk; `place()` sets
##     previous = current, so the renderer interpolates between two identical committed poses and
##     draws them exactly where they are.
##   * YAW IS ZERO BECAUSE ZERO IS THE COLUMN'S OWN EMPTY VALUE, not a facing. `transforms.gd`
##     names the yaw zero-reference and handedness as a MOVE-G01/G04 blocker; the renderer
##     discards yaw for that reason, so no facing is asserted by writing it.

const IntMath := preload("res://scripts/core/int_math.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")

## The muster block starts one tile SOUTH of GDD 5.9's authored refuge-hall footprint -- the first
## row of 5.1's one-tile apron, which 5.1 clears before any resource node is placed. Its width is
## the hall's own, so the twelve-resident cohort of 5.1 occupies exactly one row.
const MUSTER_FIRST_X: int = WorldInit.HALL_ORIGIN_X
const MUSTER_FIRST_Z: int = WorldInit.HALL_ORIGIN_Z + WorldInit.HALL_SIZE_Z
const MUSTER_ROW_TILES: int = WorldInit.HALL_SIZE_X

const REFUSE_NONE: StringName = &""
const REFUSE_NO_RESIDENTS: StringName = &"SCAFFOLD_NO_RESIDENT_STORE"
const REFUSE_UNWALKABLE_TILE: StringName = &"SCAFFOLD_MUSTER_TILE_UNWALKABLE"
const REFUSE_PLACE_REFUSED: StringName = &"SCAFFOLD_TRANSFORM_REFUSED"

var _residents: ResidentsScript = null
var _transforms: TransformsScript = null
var _placed_count: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init(residents: ResidentsScript) -> void:
	"""Build the presentation-private Transform store over the settlement's own directory.

	The directory is SHARED, because a Transform row is derived from `(kind, typed_row)` and a
	private directory would derive rows for entities that do not exist. Only the pose columns
	are private.
	"""
	_residents = residents
	if _residents != null:
		_transforms = TransformsScript.new(_residents.directory())


func transforms() -> TransformsScript:
	"""The pose store the renderer reads. Null when no resident store was supplied."""
	return _transforms


func is_ready() -> bool:
	"""True when a resident store was supplied and the pose store exists."""
	return _residents != null and _transforms != null


static func muster_tile_x(index: int) -> int:
	"""THE UNAUTHORED CHOICE, first of two: which column of the muster block `index` stands in."""
	return MUSTER_FIRST_X + index % MUSTER_ROW_TILES


static func muster_tile_z(index: int) -> int:
	"""THE UNAUTHORED CHOICE, second of two: which row of the muster block `index` stands in.

	Rows fill southward, so 5.1's twelve fit one row and a larger settlement grows away from the
	hall rather than into it.
	"""
	return MUSTER_FIRST_Z + index / MUSTER_ROW_TILES


func place_all() -> bool:
	"""Stand every living resident on its muster tile, in ascending slot order. Writes no store
	but the private one. Refuses whole rather than leaving half a cohort placed."""
	if not is_ready():
		return _refuse(REFUSE_NO_RESIDENTS)
	var index: int = 0
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if not _residents.is_alive(slot):
			continue
		if not _place_one(_residents.ref_of(slot), index):
			return false
		index += 1
	_placed_count = index
	_last_refusal = REFUSE_NONE
	return true


func _place_one(ref: Vector2i, index: int) -> bool:
	"""Place one resident at the centre of its muster tile, at 5.1's land elevation."""
	var tile_x: int = muster_tile_x(index)
	var tile_z: int = muster_tile_z(index)
	if not WorldInit.is_walkable(tile_x, tile_z):
		return _refuse(REFUSE_UNWALKABLE_TILE)
	if not _transforms.place(ref, WorldInit.tile_center_x_units(tile_x),
			WorldInit.elevation_y_units_of(tile_x, tile_z),
			WorldInit.tile_center_z_units(tile_z), 0):
		return _refuse(REFUSE_PLACE_REFUSED)
	return true


func placed_count() -> int:
	"""Residents the most recent successful `place_all()` placed. Zero before the first."""
	return _placed_count


func last_refusal() -> StringName:
	"""Reason the most recent refused call refused; empty after a successful one."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
