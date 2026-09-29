extends Node3D
## What the demo's chambers look like. Decision 0196 (live demo). Presentation only.
##
## ON THE GROUND: a PLANNED chamber is a cream outline of its floor with its name over it; a DONE
## burrow home is a low grassed mound with a round door, a DONE root cellar the library's cellar -- a
## stone door in a turfed mound -- each with its name.
## UNDERGROUND (U): a done chamber is a room at bore depth -- a burrow home warm, with its beds (the
## library's bed) and a basket; a root cellar cold blue, with baskets by the door (the farm stands its
## shelf and jars at the back, filled from the cellar's stock: farm/farm_stock_view.gd). The models
## come from demo/props/demo_props.gd, as boxes when nothing is staged.
##
## Built once per chamber slot; `refresh()` redraws a slot only when the chambers' revision or the
## view changed.

const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const OUTLINE_WIDTH_M: float = 0.12
const LIFT_M: float = 0.05
const MOUND_RADIUS_M: float = 1.35
const MOUND_HEIGHT_M: float = 0.45
const ROOM_FLOOR_Y_M: float = -1.25
const HOME_FLOOR: Color = Color(0.55, 0.37, 0.2)
const CELLAR_FLOOR: Color = Color(0.3, 0.38, 0.45)
const MOUND_COLOUR: Color = Color(0.36, 0.42, 0.25)
const DOOR_COLOUR: Color = Color(0.35, 0.22, 0.12)
const CELLAR_KEY: StringName = &"cellar"
const BED_KEY: StringName = &"bed"
const BASKET_KEY: StringName = &"basket"
## Furniture in a room, in the room's frame (+Z toward the camera's usual side): a home's
## ChambersScript.BEDS_PER_HOME beds along the back wall and a basket by the door; a cellar's
## baskets by its door.
const HOME_BEDS_AT: Array[Vector3] = [Vector3(-0.72, 0.04, -0.62), Vector3(0.72, 0.04, -0.62)]
const HOME_BASKET_AT: Vector3 = Vector3(0.95, 0.04, 0.85)
const CELLAR_BASKETS_AT: Array[Vector3] = [Vector3(-1.0, 0.04, 0.9), Vector3(-0.55, 0.04, 1.05)]
## The cellar model turns its door toward the camera's usual side.
const CELLAR_YAW: float = 0.0
const LABEL_PX: int = 32
const LABEL_PIXEL: float = 0.0006

var _chambers: ChambersScript = null
var _seen: int = -1
var _underground: bool = false
var _outlines: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _rooms: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _cellars: Array[Node3D] = []
var _props: PropsScript = null


func configure(chambers: ChambersScript, props: PropsScript = null) -> void:
	"""Draw these chambers with these props (none: boxes). Builds every node once."""
	name = "BurrowView"
	_chambers = chambers
	_props = props if props != null else PropsScript.new()
	for c in ChambersScript.MAX_CHAMBERS:
		_outlines.append(_outline())
		_mounds.append(_mound())
		_cellars.append(_cellar_door())
		_rooms.append(Node3D.new())
		add_child(_rooms[c])
		_labels.append(_label())


func _outline() -> MeshInstance3D:
	"""A chamber's floor outline: four thin cream strips (a unit square, scaled when placed)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(ChambersScript.CHAMBER_SIDE_Q) * 0.5
	for part: Transform3D in [Transform3D(Basis.from_scale(Vector3(2.0 * half, 0.01, OUTLINE_WIDTH_M)), Vector3(0.0, 0.0, half)),
			Transform3D(Basis.from_scale(Vector3(2.0 * half, 0.01, OUTLINE_WIDTH_M)), Vector3(0.0, 0.0, -half)),
			Transform3D(Basis.from_scale(Vector3(OUTLINE_WIDTH_M, 0.01, 2.0 * half)), Vector3(half, 0.0, 0.0)),
			Transform3D(Basis.from_scale(Vector3(OUTLINE_WIDTH_M, 0.01, 2.0 * half)), Vector3(-half, 0.0, 0.0))]:
		tool.append_from(BoxMesh.new(), 0, part)
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = _flat(Palette.CREAM)
	node.visible = false
	add_child(node)
	return node


func _mound() -> Node3D:
	"""A done chamber on the surface: a low grassed mound with a round door."""
	var mound := Node3D.new()
	var hump := MeshInstance3D.new()
	hump.mesh = OverlayScript.heap_mesh()
	hump.material_override = _rough(MOUND_COLOUR)
	hump.scale = Vector3(MOUND_RADIUS_M, MOUND_HEIGHT_M, MOUND_RADIUS_M)
	mound.add_child(hump)
	var door := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.24
	disc.bottom_radius = 0.24
	disc.height = 0.05
	door.mesh = disc
	door.material_override = _rough(DOOR_COLOUR)
	door.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	door.position = Vector3(0.0, 0.2, MOUND_RADIUS_M * 0.72)
	mound.add_child(door)
	mound.visible = false
	add_child(mound)
	return mound


func _cellar_door() -> Node3D:
	"""A done root cellar on the surface: the library's cellar (hidden until one is dug)."""
	var holder := Node3D.new()
	holder.rotation.y = CELLAR_YAW
	holder.add_child(_props.instance(CELLAR_KEY))
	holder.visible = false
	add_child(holder)
	return holder


func _label() -> Label3D:
	"""A chamber's name, over it."""
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL
	label.font_size = LABEL_PX
	label.outline_size = 8
	label.modulate = Palette.CREAM
	label.outline_modulate = Palette.DEEP_SHADE
	label.no_depth_test = true
	label.visible = false
	add_child(label)
	return label


static func _flat(colour: Color) -> StandardMaterial3D:
	"""An unshaded material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


static func _rough(colour: Color) -> StandardMaterial3D:
	"""A lit rough material."""
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


func set_underground_view(on: bool) -> void:
	"""Rooms show in the underground view; mounds and outlines above it."""
	_underground = on
	_seen = -1


func refresh() -> void:
	"""Redraw when the chambers or the view changed."""
	var key := _chambers.revision * 2 + (1 if _underground else 0)
	if key == _seen:
		return
	_seen = key
	for c in ChambersScript.MAX_CHAMBERS:
		_draw(c)


func _draw(c: int) -> void:
	"""One chamber slot, from its phase and kind."""
	var phase := _chambers.phase[c]
	var at := _chambers.centre_m(c)
	var done := phase == ChambersScript.PHASE_DONE
	_outlines[c].visible = phase == ChambersScript.PHASE_PLANNED and not _underground
	_outlines[c].position = Vector3(at.x, LIFT_M, at.y)
	var cellar := _chambers.kind[c] == ChambersScript.KIND_CELLAR
	_mounds[c].visible = done and not _underground and not cellar
	_mounds[c].position = Vector3(at.x, 0.0, at.y)
	_cellars[c].visible = done and not _underground and cellar
	_cellars[c].position = Vector3(at.x, 0.0, at.y)
	_labels[c].visible = phase != ChambersScript.PHASE_FREE
	_labels[c].position = Vector3(at.x, 1.3 if done else 0.6, at.y)
	_labels[c].text = ChambersScript.KIND_NAMES[_chambers.kind[c]] + ("" if done else " (digging)")
	_build_room(c, done and _underground, at)


func _build_room(c: int, show: bool, at: Vector2) -> void:
	"""The room below: its floor and, for a home, its beds, for a cellar, its crates."""
	var room := _rooms[c]
	for child in room.get_children():
		room.remove_child(child)
		child.queue_free()
	room.visible = show
	if not show:
		return
	room.position = Vector3(at.x, ROOM_FLOOR_Y_M, at.y)
	var side := float(ChambersScript.CHAMBER_SIDE_Q)
	var home := _chambers.kind[c] == ChambersScript.KIND_HOME
	_box(room, Vector3(side, 0.08, side), Vector3.ZERO, _flat(HOME_FLOOR if home else CELLAR_FLOOR))
	if home:
		for spot: Vector3 in HOME_BEDS_AT:
			_furnish(room, BED_KEY, spot)
		_furnish(room, BASKET_KEY, HOME_BASKET_AT)
	else:
		for spot: Vector3 in CELLAR_BASKETS_AT:
			_furnish(room, BASKET_KEY, spot)


func _furnish(room: Node3D, key: StringName, at: Vector3) -> void:
	"""One piece of furniture in a room (built only when the room is redrawn)."""
	var piece: MeshInstance3D = _props.instance(key)
	piece.position += at
	room.add_child(piece)


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	"""A box in a room (built only when the room is redrawn)."""
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = material
	node.position = at
	parent.add_child(node)


func label(c: int) -> Label3D:
	"""Chamber `c`'s name label (for checks)."""
	return _labels[c]


func room(c: int) -> Node3D:
	"""Chamber `c`'s room below (for checks)."""
	return _rooms[c]


func cellar_door(c: int) -> Node3D:
	"""Chamber `c`'s cellar on the surface (for checks)."""
	return _cellars[c]
