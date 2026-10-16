extends RefCounted
## WHAT A REMOVAL WOULD CUT OFF, IN THE DEMO (decision 2021; BUILD-REQ-017, Brendan's ruling P-D1-6 (a), "Real check
## now"). The batch's cut-off reader (build_batch.gd `bind_way_host`): it describes the proof of concept's space to
## build_way_graph.gd and asks it what a set of removals would leave with no way out.
##   cells     every ordered or dug cell on levels 1-4 but a run's (a run is part of its way: decision 2021 E4), and
##             every Mound room cell on the Surface, joined to their neighbours
##   ways      each standing way: an entrance off the Mounds joins the outside to its landing; a way below the Surface
##             or on a Mound room's floor joins its top cells to its foot (the works' own links)
##   doors     each confirmed front door joins the outside to its Mound's room behind it
##   targets   each room by type and level ("Kitchen (level 1)", "Bedroom (surface)"), and each resident below by name
## Stored lots and reservations: the proof of concept has none (decision 1912 ruling 2, "Free for now"), so none are
## named. Cold: built on each ask, which the batch makes once per revision.

const Graph := preload("res://scripts/ui/build_way_graph.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

## A door's tag in the graph (a way's is its row).
const DOOR_TAG: int = 1 << 20
const ROOM_NAME: String = "%s (%s)"

var _works: Works = null
var _mounds: Mounds = null
var _below: Callable = Callable()
## Graphs built (checks).
var builds: int = 0


func configure(works: Works, mounds: Mounds, below: Callable) -> void:
	"""Read `works` and `mounds`; `below() -> Array` lists the residents below as [name, Vector3i (level, x, z)]."""
	_works = works
	_mounds = mounds
	_below = below


func cut_off(ways: PackedInt32Array, doors: Array) -> String:
	"""The batch's reader: what removing the confirmed ways `ways` ((level, x, z) triples) and front doors `doors`
	(first edges) would cut off, as "Kitchen (level 1), Basil" ("" for nothing)."""
	var removed: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, ways.size(), 3):
		var row: int = _works.way_row_at(ways[at], Vector2i(ways[at + 1], ways[at + 2]))
		if row >= 0:
			removed.append(row)
	for door: Variant in doors:
		var row: int = _mounds.row_at(door as Vector3i) if _mounds != null else -1
		if row >= 0:
			removed.append(DOOR_TAG + row)
	if removed.is_empty():
		return ""
	return Graph.names_text(graph().cut_off(removed))


func graph() -> Graph:
	"""The proof of concept's space as a graph (see the header)."""
	builds += 1
	var out: Graph = Graph.new()
	_add_levels(out)
	_add_mounds(out)
	_add_ways(out)
	if _below.is_valid():
		for resident: Array in _below.call():
			out.add_target(resident[1] as Vector3i, String(resident[0]))
	return out


func _add_levels(out: Graph) -> void:
	"""Levels 1-4's ordered and dug cells but runs, each room cell a target named by its type and level."""
	var cells: PackedInt32Array = PackedInt32Array()
	for level: int in range(1, Works.LEVELS):
		for wanted: int in [Works.ORDERED, Works.OPEN]:
			_works.cells_into(level, wanted, cells)
			for at: int in range(0, cells.size(), 2):
				_add_cell(out, level, Vector2i(cells[at], cells[at + 1]))


func _add_cell(out: Graph, level: int, cell: Vector2i) -> void:
	"""One cell walkable (a run's is not), and a target when it is a room's."""
	var type: int = _works.type_of(level, cell)
	if type == Works.TYPE_WAY:
		return
	out.add_cells(level, PackedInt32Array([cell.x, cell.y]))
	if type != Works.TYPE_NONE:
		out.add_target(Vector3i(level, cell.x, cell.y), ROOM_NAME % [BuildCatalog.type_name(type),
			LevelBar.SHORT_NAMES[level].to_lower()])


func _add_mounds(out: Graph) -> void:
	"""The Mound room cells on the Surface, and each confirmed front door joining the outside to the room behind it."""
	if _mounds == null:
		return
	var cells: PackedInt32Array = _mounds.all_cells()
	for at: int in range(0, cells.size(), 2):
		_add_cell(out, Mound.SURFACE, Vector2i(cells[at], cells[at + 1]))
	for row: int in _mounds.edge_count():
		if _mounds.edge_kind(row) == Mound.KIND_DOOR:
			var cell: Vector2i = _mounds.edge_cell(row)
			out.add_link(Graph.OUTSIDE, Vector3i(Mound.SURFACE, cell.x, cell.y), DOOR_TAG + row)


func _add_ways(out: Graph) -> void:
	"""Each standing way's links, tagged with its row."""
	for row: int in _works.way_count():
		if not _works.way_live(row):
			continue
		var family: int = _works.way_family(row)
		var turn: int = _works.way_turn(row)
		var anchor: Vector2i = _works.way_anchor(row)
		var top: int = _works.way_level(row)
		var foot: PackedInt32Array = Families.landing_cells(family, turn, anchor)
		if top == Mound.SURFACE and not _on_mound(family, turn, anchor):
			for at: int in range(0, foot.size(), 2):
				out.add_link(Graph.OUTSIDE, Vector3i(1, foot[at], foot[at + 1]), row)
			continue
		var standing: PackedInt32Array = Families.standing_cells(family, turn, anchor)
		for at: int in range(0, standing.size(), 2):
			var from: Vector2i = Vector2i(standing[at], standing[at + 1])
			var to: Vector2i = Families.paired_landing(family, turn, anchor, from)
			if to != from or not Families.sloped(family):
				out.add_link(Vector3i(top, from.x, from.y), Vector3i(top + 1, to.x, to.y), row)


func _on_mound(family: int, turn: int, anchor: Vector2i) -> bool:
	"""Whether a Surface way stands on a Mound room's floor (its top cell is a Mound's)."""
	return _mounds != null and _mounds.stage_of(Families.top_corner(family, turn, anchor)) != Mounds.NONE
