extends Node3D
## THE FURNITURE, DRAWN (decision 1921; Brendan's Furnish-tab rulings of 2026-10-13). On the level the build panel shows
## (the dug view's layer, demo_build_dug.gd), on the dug pits' floor (demo_build_earth.gd DEPTH_M below the paint plane,
## where the player sees the rooms and where a piece is picked):
##   THE GHOST     the armed piece under the cursor, its footprint drawn as the batch judges it -- ✓ gold, X hatched --
##                 with its glyph and name on a tag ("✓ Hearth", "X Kitchen bench", "✓ Door, north side"); the reason
##                 in words is the label beside the pointer (demo_build.gd) and the notice a refused click gives;
##   PENDING       each piece in the batch the same way, with its name;
##   WAITING       each confirmed piece not fitted yet, its footprint outlined, and one tag "Waiting to be fitted: N
##                 pieces" -- "Fitting" over the one a resident is fitting now;
##   FITTED        the piece itself: the demo's staged model where it has one (PROP_KEYS: the bed, the hearth, the
##                 table and stools, the pantry shelf, the rag rug), turned with the piece and kept inside its
##                 footprint; else (CI, and the kitchen bench, door and partition, which have no model) a plain block
##                 of the footprint with the piece's name on it. Nothing is generated or downloaded;
##   ROOM LINES    over each room's far (north) wall, clear of the pieces in it, its line in words
##                 (demo_build_rooms.gd: "✓ Kitchen ready", "! Kitchen: Needs 1 hearth").
## Tags are drawn over everything, outline under text, and kept off each other by demo_build_tags.gd (`shown_tags`).
## ON THE SURFACE (decision 2002) the same for a Mound room's dug floor, which is the ground: drawn on the village's
## layers, its tags at a constant size over the hill's cut top.
## Rebuilt only when the batch, the works, the furniture, the level or the cursor change. Presentation only.

const Ghost := preload("res://demo/build_panel/demo_build_ghost.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Rooms := preload("res://demo/build_panel/demo_build_rooms.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Earth := preload("res://demo/build_panel/demo_build_earth.gd")
const Props := preload("res://demo/props/demo_props.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Layers := preload("res://demo/demo_layers.gd")
const MoundField := preload("res://demo/build_panel/demo_build_mound_field.gd")
## A surface tag's size at a constant screen size (demo_build_dug.gd SURFACE_TAG_PIXEL).
const SURFACE_TAG_PIXEL: float = 0.0006

const LAYER: int = 256
const UNITS_PER_M: float = 1024.0
const TAG_PX: int = 36
const TAG_PIXEL: float = 0.01
const TAG_PRIORITY: int = 5
## Over the earth's top (m): a room's line, and a waiting or fitted piece's tag over the pit floor.
const ROOM_TAG_M: float = 0.8
const PIECE_TAG_M: float = 1.3
## The staged model each item is drawn with, where the demo has one (demo_props.gd keys).
## Keyed by FurnitureDefinition key (catalog.gd), never by a number written here.
const PROP_KEYS: Dictionary = {"bed": &"bed", "decoration": &"rag_rug", "hearth": &"hearth", "patient_bed": &"bed",
	"seat": &"table_stools", "shelf": &"pantry_shelf"}
## A plain block's height per item type (m): the stand-in where no model is staged.
const BLOCK_M: Dictionary = {"bed": 0.4, "decoration": 0.06, "hearth": 0.9, "interior_door": 0.95,
	"interior_partition": 0.9, "kitchen_bench": 0.8, "patient_bed": 0.4, "seat": 0.5, "shelf": 1.2}
## A block stands this far inside its footprint's sides (m); a door or partition is this thick.
const BLOCK_INSET_M: float = 0.15
const EDGE_THICK_M: float = 0.14
const POST_M: float = 0.16
const WOOD: Color = Color(0.48, 0.33, 0.2)
const STONE: Color = Color(0.5, 0.48, 0.44)
const WAITING: String = "Waiting to be fitted: %d pieces"
const WAITING_ONE: String = "Waiting to be fitted: 1 piece"
const FITTING: String = "Fitting"
const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]
const DOOR: int = Catalog.FURNITURE_DEFINITION["interior_door"]
const PARTITION: int = Catalog.FURNITURE_DEFINITION["interior_partition"]

var rooms: Rooms = Rooms.new()
var _batch: Batch = null
var _works: Works = null
var _fittings: Fittings = null
var _floors: PackedInt32Array = PackedInt32Array()
var _datum: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
var _props: Props = null
## Per level (index): the ghost pool on its pit floor; ghost 0 is the cursor's.
var _ghosts: Array = [[], [], [], [], []]
var _pieces: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _meshes: Dictionary = {}
var _wood: StandardMaterial3D = null
var _stone: StandardMaterial3D = null
var _seen: PackedInt64Array = PackedInt64Array()
var _key: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
## Whether the rooms' lines are drawn (decision 2002: on the Surface only while the Furnish or Decor tab is open, so
## they stand over a Mound's cut top only when furnishing; below, always).
var lines_shown: bool = true
## Rebuilds since configure (checks: nothing is rebuilt on a still frame).
var rebuilds: int = 0


func configure(batch: Batch, works: Works, fittings: Fittings, floors: PackedInt32Array, datum: Vector2i,
		bounds: Rect2i) -> void:
	"""Draw `batch`'s pending pieces and `fittings` over `works` on `floors` (u per level) from `datum` (u) over
	`bounds` (cells)."""
	name = "BuildFurnish"
	_batch = batch
	_works = works
	_fittings = fittings
	_floors = floors
	_datum = datum
	_bounds = bounds
	_wood = _material(WOOD)
	_stone = _material(STONE)


static func _material(colour: Color) -> StandardMaterial3D:
	"""A plain lit material for the stand-in blocks."""
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


func use_props(props: Props) -> void:
	"""Draw the staged models where `props` has them (null: blocks everywhere)."""
	_props = props
	_meshes.clear()
	_seen = PackedInt64Array()


func refresh(level: int, item: int, cursor: Vector2i, turn: int, fitting_row: int) -> void:
	"""Redraw when anything drawn changed: the level shown (-1: none), the armed item (-1: none) at `cursor` turned
	`turn`, the batch, the works, the furniture, or the piece being fitted (-1: none)."""
	if not _moved(level, item, cursor, turn, fitting_row):
		return
	rebuilds += 1
	rooms.refresh(_works, _fittings, level)
	var shown: bool = level >= 0 and level < _ghosts.size()
	var used: int = 0
	if shown:
		used = _draw_cursor(level, item, cursor, turn)
		used = _draw_pending(level, used)
		used = _draw_waiting(level, used)
	_hide_from(level, used)
	_place_pieces(level if shown else -1)
	_place_tags(level if shown else -1, fitting_row)


func _moved(level: int, item: int, cursor: Vector2i, turn: int, fitting_row: int) -> bool:
	"""Whether anything drawn changed since the last rebuild: the nine values written into `_key` in place (no
	allocation on a still frame) and compared with the last ones seen."""
	_key[0] = level
	_key[1] = item
	_key[2] = cursor.x
	_key[3] = cursor.y
	_key[4] = turn
	_key[5] = fitting_row
	_key[6] = _batch.revision
	_key[7] = _works.revision
	_key[8] = _fittings.revision
	_key[9] = 1 if lines_shown else 0
	if _key == _seen:
		return false
	_seen = _key.duplicate()
	return true


func _draw_cursor(level: int, item: int, cursor: Vector2i, turn: int) -> int:
	"""The armed piece's ghost under the cursor, judged by the batch (ghost 0 of the level's pool); 1 when drawn."""
	if item < 0:
		return 0
	var pieces: Furniture = _batch.furniture()
	var anchor: Vector2i = pieces.anchor_for(item, turn, cursor)
	var kind: int = int(pieces.judge(level, anchor, turn, item, -1)[0])
	var words: String = "%s %s" % [Validity.glyph(kind), piece_words(item, turn)]
	return _ghost(level, 0, drawn_cells(pieces, item, turn, anchor), kind, words)


func _draw_pending(level: int, used: int) -> int:
	"""Each pending piece on `level` with its validity and name."""
	var pieces: Furniture = _batch.furniture()
	for row: int in pieces.count():
		if not pieces.is_live(row) or pieces.level_of(row) != level:
			continue
		var item: int = pieces.item_of(row)
		var kind: int = _batch.piece_kind(row)
		var words: String = "%s %s" % [Validity.glyph(kind), piece_words(item, pieces.turn_of(row))]
		used = _ghost(level, used, drawn_cells(pieces, item, pieces.turn_of(row), pieces.anchor_of(row)), kind, words)
	return used


func _draw_waiting(level: int, used: int) -> int:
	"""Each confirmed piece on `level` still waiting for a fitter, outlined (its words are the level's tags)."""
	for row: int in _fittings.count():
		if _fittings.level_of(row) != level or _fittings.state_of(row) != Fittings.ORDERED:
			continue
		var cells: PackedInt32Array = drawn_cells(_fittings.shapes, _fittings.item_of(row), _fittings.turn_of(row),
			_fittings.anchor_of(row))
		used = _ghost(level, used, cells, Validity.KIND_CAN_BUILD, "")
	return used


static func drawn_cells(shapes: Furniture, item: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""The cells a piece's ghost covers: its footprint, or for a door or partition the two cells its edges run along
	on the cursor's side."""
	if not shapes.is_edge(item):
		return shapes.cells_of(item, turn, anchor)
	var along: Vector2i = Vector2i(1, 0) if posmod(turn, 2) == 0 else Vector2i(0, 1)
	return PackedInt32Array([anchor.x, anchor.y, anchor.x + along.x, anchor.y + along.y])


static func piece_words(item: int, turn: int) -> String:
	"""A piece's name and, for a door or partition, its side: "Hearth", "Door, north side"."""
	var edge: bool = item == DOOR or item == PARTITION
	return "%s, %s" % [Furniture.name_of(item), Furniture.turn_words(true, turn)] if edge else Furniture.name_of(item)


func _ghost(level: int, at: int, cells: PackedInt32Array, kind: int, words: String) -> int:
	"""Ghost `at` of `level`'s pool (made when the pool is that short) drawing `cells` as `kind` with `words`; returns
	the next free slot."""
	var pool: Array = _ghosts[level]
	while pool.size() <= at:
		var ghost: Ghost = Ghost.new()
		var datum: Vector3i = Vector3i(_datum.x, floor_u(level), _datum.y)
		if ghost.configure_ghost(datum, _bounds, marks_layer(level), false) != &"":
			ghost.free()
			return at
		add_child(ghost)
		pool.append(ghost)
	var shown: Ghost = pool[at]
	shown.show_cells(cells, kind, words)
	shown.visible = not cells.is_empty()
	return at + 1


func _hide_from(level: int, used: int) -> void:
	"""Every ghost past `used` on the level shown hidden, and every ghost on the other levels."""
	for each: int in _ghosts.size():
		var pool: Array = _ghosts[each]
		for at: int in range(used if each == level else 0, pool.size()):
			(pool[at] as Ghost).visible = false


# --- the fitted pieces ---------------------------------------------------------------------------------------------

func _place_pieces(level: int) -> void:
	"""Each fitted piece on `level` drawn (see FITTED); the pool's rest hidden."""
	var used: int = 0
	for row: int in _fittings.count():
		if _fittings.level_of(row) != level or _fittings.state_of(row) != Fittings.FITTED:
			continue
		if used == _pieces.size():
			var node: MeshInstance3D = MeshInstance3D.new()
			add_child(node)
			_pieces.append(node)
		_pieces[used].layers = LAYER if level >= 1 else Layers.SURFACE
		var item: int = _fittings.item_of(row)
		_pieces[used].mesh = mesh_of(item)
		_pieces[used].transform = placed(row, level)
		_pieces[used].visible = true
		used += 1
	for at: int in range(used, _pieces.size()):
		_pieces[at].visible = false


func staged(item: int) -> bool:
	"""Whether `item` is drawn with a staged model (else a plain block, named by its tag)."""
	return _props != null and PROP_KEYS.has(key_of(item)) and _props.is_staged(PROP_KEYS[key_of(item)])


static func key_of(item: int) -> String:
	"""An item's FurnitureDefinition key ("hearth"), or "" for none."""
	var key: Variant = Catalog.FURNITURE_DEFINITION.find_key(item)
	return String(key) if key != null else ""


static func block_m(item: int) -> float:
	"""A plain block's height for `item` (m)."""
	return float(BLOCK_M.get(key_of(item), 0.5))


func mesh_of(item: int) -> Mesh:
	"""`item`'s mesh, made once: its staged model on the ground and centred, else its block (or a doorway)."""
	if _meshes.has(item):
		return _meshes[item]
	var mesh: Mesh = null
	if staged(item):
		var key: StringName = PROP_KEYS[key_of(item)]
		mesh = Props.transformed(_props.mesh_of(key), _props.fit_of(key))
	elif item == DOOR:
		mesh = _doorway_mesh()
	else:
		mesh = _block_mesh(item)
	_meshes[item] = mesh
	return mesh


func _block_mesh(item: int) -> Mesh:
	"""A plain block one footprint (less its inset) wide and BLOCK_M high, standing on y = 0; a partition is a thin
	wall along x, 2 cells long."""
	var shapes: Furniture = _fittings.shapes
	var size: Vector2i = shapes.size_of(item, 0)
	var box: BoxMesh = BoxMesh.new()
	if shapes.is_edge(item):
		box.size = Vector3(2.0, block_m(item), EDGE_THICK_M)
	else:
		box.size = Vector3(size.x - 2.0 * BLOCK_INSET_M, block_m(item), size.y - 2.0 * BLOCK_INSET_M)
	box.material = _stone if item == HEARTH else _wood
	var tool: SurfaceTool = SurfaceTool.new()
	tool.append_from(box, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, block_m(item) / 2.0, 0.0)))
	tool.set_material(box.material)
	return tool.commit()


func _doorway_mesh() -> Mesh:
	"""A doorway 2 cells wide along x: two posts and a lintel, open between them."""
	var height: float = block_m(DOOR)
	var tool: SurfaceTool = SurfaceTool.new()
	var post: BoxMesh = BoxMesh.new()
	post.size = Vector3(POST_M, height, EDGE_THICK_M)
	for x: float in [-1.0 + POST_M / 2.0, 1.0 - POST_M / 2.0]:
		tool.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(x, height / 2.0, 0.0)))
	var lintel: BoxMesh = BoxMesh.new()
	lintel.size = Vector3(2.0, POST_M, EDGE_THICK_M)
	tool.append_from(lintel, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, height - POST_M / 2.0, 0.0)))
	tool.set_material(_wood)
	return tool.commit()


func placed(row: int, level: int) -> Transform3D:
	"""Where fitted piece `row` stands: turned with the piece about its footprint's middle on the pit floor, a staged
	model laid along the footprint's long side and shrunk (never grown) to stay inside it."""
	var item: int = _fittings.item_of(row)
	var turn: int = _fittings.turn_of(row)
	var floor_m: float = floor_u(level) / UNITS_PER_M
	if _fittings.shapes.is_edge(item):
		return _edge_placed(row, floor_m)
	var size: Vector2i = _fittings.shapes.size_of(item, turn)
	var middle: Vector3 = _corner(_fittings.anchor_of(row), floor_m) + Vector3(size.x, 0.0, size.y) / 2.0
	var facing: Basis = Basis(Vector3.UP, -PI / 2.0 * turn)
	if staged(item):
		facing = _fitted_basis(mesh_of(item).get_aabb(), _fittings.shapes.size_of(item, 0), turn)
	return Transform3D(facing, middle)


static func _fitted_basis(bound: AABB, size: Vector2i, turn: int) -> Basis:
	"""A staged model's turn: its long side along the unturned footprint's, then the piece's quarter turns, shrunk to
	fit inside the footprint less its inset."""
	var long_on_z: bool = bound.size.z > bound.size.x
	var lay: float = PI / 2.0 if size.x != size.y and long_on_z != (size.y > size.x) else 0.0
	var facing: Basis = Basis(Vector3.UP, lay - PI / 2.0 * turn)
	var turned: AABB = Transform3D(facing, Vector3.ZERO) * bound
	var room: Vector2 = Vector2(size.x, size.y) if posmod(turn, 2) == 0 else Vector2(size.y, size.x)
	room -= Vector2(2.0 * BLOCK_INSET_M, 2.0 * BLOCK_INSET_M)
	var shrink: float = minf(1.0, minf(room.x / maxf(turned.size.x, 0.01), room.y / maxf(turned.size.z, 0.01)))
	return facing.scaled(Vector3(shrink, shrink, shrink))


func _edge_placed(row: int, floor_m: float) -> Transform3D:
	"""A door or partition stood on the middle of its two cell edges, along x or along z."""
	var edges: Array[Vector3i] = _fittings.edges_of(row)
	var middle: Vector3 = Vector3.ZERO
	for edge: Vector3i in edges:
		var along: Vector3 = Vector3(0.5, 0.0, 0.0) if edge.x == Furniture.EDGE_ACROSS else Vector3(0.0, 0.0, 0.5)
		middle += _corner(Vector2i(edge.y, edge.z), floor_m) + along
	middle /= float(edges.size())
	var facing: Basis = Basis.IDENTITY if edges[0].x == Furniture.EDGE_ACROSS else Basis(Vector3.UP, PI / 2.0)
	return Transform3D(facing, middle)


func _corner(cell: Vector2i, y: float) -> Vector3:
	"""A cell corner in metres at height `y`."""
	return Vector3(_datum.x / UNITS_PER_M + cell.x, y, _datum.y / UNITS_PER_M + cell.y)


# --- the tags ------------------------------------------------------------------------------------------------------

func _place_tags(level: int, fitting_row: int) -> void:
	"""The room lines, the fitting and waiting words, and the plain blocks' names, on the level shown."""
	var used: int = 0
	if level >= 0:
		var top: float = _floors[level] / UNITS_PER_M if level >= 1 else MoundField.ROOM_TOP_M
		for room: int in (rooms.count() if lines_shown else 0):
			var box: Rect2i = rooms.box_of(room)
			var north: Vector3 = _corner(Vector2i(box.position.x, box.position.y), top)
			north.x += box.size.x / 2.0
			used = _tag(used, rooms.line_of(room), north + Vector3(0.0, ROOM_TAG_M, 0.0), level)
		used = _piece_tags(level, used, fitting_row)
	for at: int in range(used, _tags.size()):
		_tags[at].visible = false


func _piece_tags(level: int, used: int, fitting_row: int) -> int:
	""""Fitting" over the piece being fitted, "Waiting to be fitted: N pieces" over the first other one waiting, and
	each plain block's name."""
	var waiting: int = 0
	var first: int = -1
	for row: int in _fittings.count():
		if _fittings.level_of(row) != level:
			continue
		var ordered: bool = _fittings.state_of(row) == Fittings.ORDERED
		if row == fitting_row and ordered:
			used = _tag(used, FITTING, _over(row, level), level)
		elif ordered:
			waiting += 1
			first = row if first < 0 else first
		elif not staged(_fittings.item_of(row)):
			used = _tag(used, Furniture.name_of(_fittings.item_of(row)), _over(row, level), level)
	if waiting > 0:
		used = _tag(used, WAITING_ONE if waiting == 1 else WAITING % waiting, _over(first, level), level)
	return used


func _over(row: int, level: int) -> Vector3:
	"""Over piece `row`'s middle, PIECE_TAG_M above the pit floor."""
	var cells: PackedInt32Array = drawn_cells(_fittings.shapes, _fittings.item_of(row), _fittings.turn_of(row),
		_fittings.anchor_of(row))
	var low: Vector2i = Vector2i(cells[0], cells[1])
	var high: Vector2i = Vector2i(cells[cells.size() - 2], cells[cells.size() - 1]) + Vector2i.ONE
	var y: float = floor_u(level) / UNITS_PER_M + PIECE_TAG_M
	return (_corner(low, y) + _corner(high, y)) / 2.0


func floor_u(level: int) -> int:
	"""Where a piece stands on `level` (u): the dug pits' floor below the paint plane, or on the Surface the ground."""
	return _floors[level] - (Earth.DEPTH_U if level >= 1 else 0)


static func marks_layer(level: int) -> int:
	"""The layer `level`'s ghosts and tags are drawn on: the dug view's, or the village's marks on the Surface."""
	return LAYER if level >= 1 else Layers.SURFACE_MARKS


func _tag(used: int, words: String, at: Vector3, level: int) -> int:
	"""Tag `used` (made when the pool is that short) shows `words` at `at` on `level`'s layer (a constant size on the
	Surface); returns the next free one."""
	if used == _tags.size():
		var tag: Label3D = Label3D.new()
		tag.layers = LAYER
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = TAG_PX
		tag.pixel_size = TAG_PIXEL
		tag.outline_size = 8
		tag.render_priority = TAG_PRIORITY
		tag.outline_render_priority = TAG_PRIORITY - 1
		add_child(tag)
		_tags.append(tag)
	var label: Label3D = _tags[used]
	label.text = words
	label.offset = Vector2.ZERO
	label.position = at
	label.layers = marks_layer(level)
	label.fixed_size = level < 1
	label.pixel_size = SURFACE_TAG_PIXEL if level < 1 else TAG_PIXEL
	label.visible = true
	return used + 1


func shown_tags(out: Array[Label3D]) -> void:
	"""Append the shown tags to `out` (demo_build_tags.gd keeps them off each other)."""
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag)


func tags() -> PackedStringArray:
	"""The words shown on the level (checks)."""
	var out: PackedStringArray = PackedStringArray()
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag.text)
	return out


func pieces_shown() -> int:
	"""Fitted pieces drawn (checks)."""
	var shown: int = 0
	for node: MeshInstance3D in _pieces:
		shown += 1 if node.visible else 0
	return shown


func ghost_words(level: int) -> PackedStringArray:
	"""The shown ghosts' tags on `level` (checks): the cursor's first."""
	var out: PackedStringArray = PackedStringArray()
	for ghost: Ghost in _ghosts[level]:
		if ghost.visible:
			out.append(ghost.tag_text())
	return out
