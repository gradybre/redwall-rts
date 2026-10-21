extends Node3D
## THE MOUND ROOMS' OUTER EDGES WHILE DOORS AND WINDOWS ARE PLACED (decision 2002; the approved mockup's slot markers).
## With the build panel open on the Surface: each pending door or window is a bar on its edges with its words over it
## ("✓ Front door, oak", "X Window: doors and windows go on a room's outer edge"); with the Front door or Window card
## armed, every outer edge of every Mound room (pending or built) shows too -- a free one as a short bar, a built door
## or window in its own colour -- and the edge under the pointer is drawn larger with its judgement in words. Never by
## colour alone: every placed one carries its name and glyph. A bar lies at the ground for a room not heaped yet, and
## at the cut top (the wall's top) over a heaped one not dug. Rebuilt only when something drawn changed; drawn over
## everything on the village's marks layer. Presentation only.

const Mound := preload("res://scripts/ui/build_mound.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Layers := preload("res://demo/demo_layers.gd")

const FREE: Color = Color8(0xb6, 0xe0, 0x7f)
const DOOR: Color = Color8(0xe0, 0x78, 0x2a)
const WINDOW: Color = Color8(0x7f, 0xd3, 0xff)
const REFUSED: Color = Color8(0xd0, 0x45, 0x3a)
## A bar's size along its edge, up and out; the edge under the pointer's grown by HOVER_GROW.
const BAR: Vector3 = Vector3(0.84, 0.06, 0.3)
const HOVER_GROW: float = 1.35
const LIFT_M: float = 0.06
const TAG_PX: int = 32
const TAG_PIXEL: float = 0.0006
const TAG_UP_M: float = 1.0
const NO_EDGE: Vector3i = Vector3i(-1048576, 0, 0)

var _batch: Batch = null
var _mounds: Mounds = null
var _datum_m: Vector2 = Vector2.ZERO
var _mesh: MeshInstance3D = null
var _materials: Dictionary = {}
var _tags: Array[Label3D] = []
## What the last rebuild drew from: shown, armed, the hover's kind, the batch's and the Mounds' revisions; the edge
## under the pointer and its words (compared field by field: no key is made a frame).
var _seen: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1, -1])
var _seen_hover: Vector3i = NO_EDGE
var _seen_words: String = ""
var _edges: Array[Vector3i] = []
## Bars drawn by the last rebuild, free ones among them (checks).
var bars: int = 0
var free_bars: int = 0


func configure(batch: Batch, mounds: Mounds, datum_m: Vector2) -> void:
	"""Mark `batch`'s pending doors and windows and the outer edges of its and `mounds`' rooms, cells from `datum_m`."""
	name = "BuildMoundMarks"
	_batch = batch
	_mounds = mounds
	_datum_m = datum_m
	_mesh = MeshInstance3D.new()
	_mesh.layers = Layers.SURFACE_MARKS
	add_child(_mesh)
	for key: StringName in [&"free", &"door", &"window", &"refused"]:
		var colour: Color = {&"free": FREE, &"door": DOOR, &"window": WINDOW, &"refused": REFUSED}[key]
		var made: StandardMaterial3D = Front.unshaded(colour, 1.0)
		made.no_depth_test = true
		made.render_priority = 3
		_materials[key] = made


func refresh(shown: bool, armed: int, hover: Vector3i, hover_kind: int, hover_words: String) -> void:
	"""Redraw when anything drawn changed: shown (the panel on the Surface), the kind armed (-1: none), the edge under
	the pointer (NO_EDGE: none) with its judgement, the batch or the Mounds."""
	if not _moved(shown, armed, hover, hover_kind, hover_words):
		return
	bars = 0
	free_bars = 0
	visible = shown
	if not shown:
		return
	var kit: MeshKit = MeshKit.new()
	var used: int = _pending(kit, 0)
	if armed >= 0:
		_slots(kit)
		used = _hover(kit, hover, hover_kind, hover_words, used)
	_mesh.mesh = kit.commit()
	for k: int in range(used, _tags.size()):
		_tags[k].visible = false


func _moved(shown: bool, armed: int, hover: Vector3i, hover_kind: int, hover_words: String) -> bool:
	"""Whether anything drawn changed since the last rebuild (and note it if so)."""
	var same: bool = _seen[0] == int(shown) and _seen[1] == armed and _seen[2] == hover_kind \
		and _seen[3] == _batch.revision and _seen[4] == _mounds.revision and hover == _seen_hover \
		and hover_words == _seen_words
	if same:
		return false
	_seen[0] = int(shown)
	_seen[1] = armed
	_seen[2] = hover_kind
	_seen[3] = _batch.revision
	_seen[4] = _mounds.revision
	_seen_hover = hover
	_seen_words = hover_words
	return true


func _pending(kit: MeshKit, used: int) -> int:
	"""Each pending door or window on its edges, with its words; returns the tags used."""
	var edges: MoundEdges = _batch.mound_edges()
	for row: int in edges.count():
		if not edges.is_live(row) or edges.level_of(row) != Mound.SURFACE:
			continue
		var kind: int = _batch.edge_kind(row)
		var material: StringName = &"refused" if kind != Validity.KIND_CAN_BUILD \
			else (&"door" if edges.kind_of(row) == Mound.KIND_DOOR else &"window")
		for edge: Vector3i in edges.edges_of(row):
			_bar(kit, edge, material, 1.0)
		var words: String = "%s %s" % [Validity.glyph(kind), pending_words(edges, row)]
		used = _tag(used, words, _bar_at(edges.edges_of(row)[0]) + Vector3.UP * TAG_UP_M)
	return used


static func pending_words(edges: MoundEdges, row: int) -> String:
	"""A pending row's name: "Front door, oak", "Window", "Remove Front door"."""
	var named: String = Mound.kind_name(edges.kind_of(row))
	if edges.is_removal(row):
		return "Remove %s" % named
	if edges.kind_of(row) == Mound.KIND_DOOR:
		return "%s, %s" % [named, Mound.colour_name(edges.colour_of(row)).to_lower()]
	return named


func _slots(kit: MeshKit) -> void:
	"""Every outer edge of every Mound room: built doors and windows in their colour, the rest as free bars."""
	Mound.outer_edges_into(_batch.mound_cells(), _batch.is_surface_room, _edges)
	for edge: Vector3i in _edges:
		if _batch.mound_edges().row_at(Mound.SURFACE, edge, false) >= 0:
			continue
		var row: int = _mounds.row_at(edge)
		if row >= 0:
			_bar(kit, edge, &"door" if _mounds.edge_kind(row) == Mound.KIND_DOOR else &"window", 1.0)
		else:
			_bar(kit, edge, &"free", 0.7)
			free_bars += 1


func _hover(kit: MeshKit, edge: Vector3i, kind: int, words: String, used: int) -> int:
	"""The edge under the pointer, grown, with the judgement in words; returns the tags used."""
	if edge == NO_EDGE:
		return used
	_bar(kit, edge, &"free" if kind == Validity.KIND_CAN_BUILD else &"refused", HOVER_GROW)
	return _tag(used, words, _bar_at(edge) + Vector3.UP * (TAG_UP_M + 0.6))


func _bar(kit: MeshKit, edge: Vector3i, material: StringName, grow: float) -> void:
	"""One bar on `edge`, just outside its wall, along it."""
	var along: Vector2 = Vector2(Mound.along(edge.z))
	var turned: Basis = Basis.IDENTITY if along.x != 0.0 else Basis(Vector3.UP, PI / 2.0)
	kit.add_box(_materials[material], BAR * grow, Transform3D(turned, _bar_at(edge)))
	bars += 1


func _bar_at(edge: Vector3i) -> Vector3:
	"""Where an edge's bar lies: on the edge's middle, a little out, at the ground or the cut top."""
	var middle: Vector2 = _datum_m + Field.edge_middle(edge) + Vector2(Mound.step_of(edge.z)) * 0.12
	var stage: int = _mounds.stage_of(Mound.cell_of(edge))
	var up: float = Field.ROOM_TOP_M if stage == Mounds.HEAPED else 0.0
	return Vector3(middle.x, up + LIFT_M, middle.y)


func _tag(used: int, words: String, at: Vector3) -> int:
	"""Tag `used` (made when the pool is that short) shows `words` at `at`; returns the next free one."""
	if used == _tags.size():
		var tag: Label3D = Label3D.new()
		tag.layers = Layers.SURFACE_MARKS
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = true
		tag.pixel_size = TAG_PIXEL
		tag.font_size = TAG_PX
		tag.outline_size = 8
		tag.render_priority = 5
		tag.outline_render_priority = 4
		add_child(tag)
		_tags.append(tag)
	_tags[used].text = words
	_tags[used].position = at
	_tags[used].visible = true
	return used + 1


func shown_tags(out: Array[Label3D]) -> void:
	"""Append the shown tags to `out` (demo_build_tags.gd keeps them off each other)."""
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag)


func tags() -> PackedStringArray:
	"""The words shown (checks)."""
	var out: PackedStringArray = PackedStringArray()
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag.text)
	return out
