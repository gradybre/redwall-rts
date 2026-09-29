extends Node3D
## What the demo's chambers look like. Decision 0196 (live demo). Presentation only.
##
## ON THE GROUND: a PLANNED chamber is a cream outline of its floor with its name over it; a DONE one
## is a low grassed mound with a round door and its name -- "Burrow home" or "Root cellar".
## UNDERGROUND (U): a done chamber is a room at bore depth -- a burrow home warm, with its beds; a
## root cellar cold blue, with its crates and bins.
##
## Built once per chamber slot; `refresh()` redraws a slot only when the chambers' revision or the
## view changed.

const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const OUTLINE_WIDTH_M: float = 0.12
const LIFT_M: float = 0.05
const MOUND_RADIUS_M: float = 1.35
const MOUND_HEIGHT_M: float = 0.45
const ROOM_FLOOR_Y_M: float = -1.25
const HOME_FLOOR: Color = Color(0.55, 0.37, 0.2)
const CELLAR_FLOOR: Color = Color(0.3, 0.38, 0.45)
const MOUND_COLOUR: Color = Color(0.36, 0.42, 0.25)
const DOOR_COLOUR: Color = Color(0.35, 0.22, 0.12)
const BED_COLOUR: Color = Color(0.86, 0.8, 0.66)
const CRATE_COLOUR: Color = Color(0.5, 0.36, 0.22)
const LABEL_PX: int = 32
const LABEL_PIXEL: float = 0.0006

var _chambers: ChambersScript = null
var _seen: int = -1
var _underground: bool = false
var _outlines: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _rooms: Array[Node3D] = []
var _labels: Array[Label3D] = []


func configure(chambers: ChambersScript) -> void:
	"""Draw these chambers. Builds every node once."""
	name = "BurrowView"
	_chambers = chambers
	for c in ChambersScript.MAX_CHAMBERS:
		_outlines.append(_outline())
		_mounds.append(_mound())
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
	_mounds[c].visible = done and not _underground
	_mounds[c].position = Vector3(at.x, 0.0, at.y)
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
	for k in (ChambersScript.BEDS_PER_HOME if home else 3):
		var offset := Vector3(-0.8 + 1.6 * float(k) / maxf(1.0, float((ChambersScript.BEDS_PER_HOME if home else 3) - 1)), 0.12, 0.6)
		var size := Vector3(0.6, 0.16, 1.1) if home else Vector3(0.5, 0.45, 0.5)
		_box(room, size, offset, _rough(BED_COLOUR if home else CRATE_COLOUR))


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
