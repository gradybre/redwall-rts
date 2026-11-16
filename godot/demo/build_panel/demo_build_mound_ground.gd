extends RefCounted
## WHAT A MOUND'S HILL WOULD COVER ON THE SURFACE (decision 2002; BUILD-MOUND-008, P-2001-13 item 4): the build panel's
## surface reader in the demo, over the village as it is drawn -- read only, never written.
##   water            the village's water map at a cell's middle or any point 0.2 m inside its corners: "water";
##   a tree           a resource node (every tree the village shows is one, demo/forestry/forest_stand.gd): "a tree";
##   a building       one of the village's buildings: "a building";
##   any other thing  an item or outdoor item standing in the open -- a well, a crate, a workbench, crops: "a well" ...;
##   SCENERY          the woods' debris (world_scatter.gd DEBRIS_KEYS: rocks, a boulder, a fallen log, a mossy stump)
##                    is none of item 4's things: the hill is heaped over it, and it is drawn hidden while covered
##                    (`hide_covered`), as the ground cover is (a PROPOSAL, decision 2002).
## A placement counts where its blocking circles reach into a cell's square, or, with none, where it stands. Codes are
## cached a cell. With no village bound (the off-tree suites), nothing is covered.

const Layout := preload("res://demo/world/world_layout.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const DemoWorld := preload("res://demo/world/demo_world.gd")

const UNITS_PER_M: float = 1024.0
const WATER: String = "water"
const TREE: String = "a tree"
const BUILDING: String = "a building"

var _world: Object = null
var _water: Object = null
var _datum_m: Vector2 = Vector2.ZERO
## Each placement's circles (x, z, radius; a standing point as radius 0), what it is, and whether it is scenery.
var _circles: Array[PackedVector3Array] = []
var _at: PackedVector2Array = PackedVector2Array()
var _things: PackedStringArray = PackedStringArray()
var _scenery: PackedByteArray = PackedByteArray()
var _cache: Dictionary = {}
## Placements hidden under a hill so far (checks).
var hidden: int = 0


func configure(world: Object, water: Object, datum_m: Vector2) -> void:
	"""Read the village's placements once (`world`: demo_world.gd) and its water map (`water`: water_map.gd)."""
	_world = world
	_water = water
	_datum_m = datum_m
	_circles.clear()
	_at.clear()
	_things.clear()
	_scenery.clear()
	_cache.clear()
	if world == null:
		return
	for p: Dictionary in world.call(&"placements"):
		var circles: PackedVector3Array = PackedVector3Array(Layout.placement_circles(p))
		if circles.is_empty():
			circles.append(Vector3(Vector2(p["at"]).x, Vector2(p["at"]).y, 0.0))
		_circles.append(circles)
		_at.append(Vector2(p["at"]))
		_things.append(thing_name(StringName(p["key"])))
		_scenery.append(1 if Scatter.DEBRIS_KEYS.has(StringName(p["key"])) else 0)


static func thing_name(key: StringName) -> String:
	"""What a placement is, in the refusal's words: "a tree", "a building", or "a " and its key in words."""
	if DemoWorld.PLACEHOLDER_TREES.has(key):
		return TREE
	for building: Dictionary in Layout.BUILDINGS:
		if building["key"] == key:
			return BUILDING
	return "a %s" % String(key).replace("_", " ")


func thing_at(cell: Vector2i) -> String:
	"""What the hill would cover at `cell` ("" for nothing; scenery is nothing), cached."""
	if not _cache.has(cell):
		_cache[cell] = _read(cell)
	return _cache[cell]


func _read(cell: Vector2i) -> String:
	"""`thing_at` uncached: water first, then the first placement reaching the cell that is not scenery."""
	var low: Vector2 = _datum_m + Vector2(cell)
	if _water != null:
		for corner: Vector2 in [Vector2(0.5, 0.5), Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.8), Vector2(0.8, 0.8)]:
			var at: Vector2 = (low + corner) * UNITS_PER_M
			if bool(_water.call(&"is_water", Vector2i(roundi(at.x), roundi(at.y)))):
				return WATER
	for k: int in _circles.size():
		if _scenery[k] == 0 and reaches(_circles[k], Rect2(low, Vector2.ONE)):
			return _things[k]
	return ""


static func reaches(circles: PackedVector3Array, square: Rect2) -> bool:
	"""Whether any circle (x, z, radius; radius 0 a point) reaches into `square` (world m)."""
	for circle: Vector3 in circles:
		var near: Vector2 = Vector2(clampf(circle.x, square.position.x, square.end.x),
			clampf(circle.y, square.position.y, square.end.y))
		if near.distance_to(Vector2(circle.x, circle.y)) <= circle.z and (circle.z > 0.0 or square.has_point(near)):
			return true
	return false


func hide_covered(cells: Dictionary) -> int:
	"""Hide the scenery and the ground cover standing on `cells` (keys: cells under a hill, its yards included);
	returns how many placements were newly hidden. Once a hill grows, never per frame."""
	if _world == null:
		return 0
	var made: int = 0
	var circles: PackedVector3Array = PackedVector3Array()
	for cell: Vector2i in cells:
		var middle: Vector2 = _datum_m + Vector2(cell) + Vector2(0.5, 0.5)
		circles.append(Vector3(middle.x, 0.75, middle.y))
	for k: int in _circles.size():
		if _scenery[k] == 1 and _on_cells(_at[k], cells):
			made += 1 if bool(_world.call(&"hide_placement", k)) else 0
	_world.call(&"hide_cover", PackedVector2Array(), 0.0, circles)
	hidden += made
	return made


func _on_cells(at: Vector2, cells: Dictionary) -> bool:
	"""Whether a placement standing at `at` (world m) stands on one of `cells`."""
	var local: Vector2 = at - _datum_m
	return cells.has(Vector2i(floori(local.x), floori(local.y)))
