extends Node3D
## What the demo's chambers look like. Decision 0196 (live demo); its layers and when its rooms are built,
## decision 0206 (the underground revamp's P0). Presentation only.
##
## ON THE GROUND (the surface layers): a PLANNED chamber is a cream outline of its floor with its name
## over it; a DONE burrow home is a low grassed mound with a round door, a DONE root cellar the library's
## cellar -- a stone door in a turfed mound -- each with its name.
## BELOW (the underground layers, which only the U view draws): a done chamber is a room at bore depth --
## a burrow home warm, with its beds (the library's bed) and a basket; a root cellar cold blue, with
## baskets by the door (the farm stands its shelf and jars at the back, filled from the cellar's stock:
## farm/farm_stock_view.gd) -- lit floors, and its floor stamped into the cap's void mask
## (underground_cap.gd) so the cap opens over it. The outline and the name are drawn again on the level's
## floor for the U view (a node per view). The models come from demo/props/demo_props.gd, as boxes when
## nothing is staged.
##
## BUILT WHEN DUG. Every node is built once per chamber slot; a room's furniture is built when its chamber
## is done (or its slot reused), never when the view switches -- a switch touches nothing here. `refresh()`
## redraws only when the chambers' revision changed.

const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")

const OUTLINE_WIDTH_M: float = 0.12
const LIFT_M: float = 0.05
const MOUND_RADIUS_M: float = 1.35
const MOUND_HEIGHT_M: float = 0.45
const ROOM_FLOOR_Y_M: float = -1.25
const HOME_FLOOR: Color = Color(0.46, 0.33, 0.21)
const CELLAR_FLOOR: Color = Color(0.34, 0.37, 0.4)
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
## The U view's name floats this far above the room's floor.
const LABEL_BELOW_LIFT_M: float = 1.0
const ROOM_FLOOR_THICK_M: float = 0.08
## The U view's outline is drawn over the cap (it marks ground not yet dug).
const OUTLINE_BELOW_PRIORITY: int = 4

var _chambers: ChambersScript = null
var _seen: int = -1
var _outlines: Array[MeshInstance3D] = []
var _outlines_below: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _rooms: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _labels_below: Array[Label3D] = []
var _cellars: Array[Node3D] = []
var _props: PropsScript = null
var _cap: CapScript = null
## Per slot, what its room was built for (generation * 4 + kind, -1: no room).
var _room_key: PackedInt32Array = PackedInt32Array()
## One floor mesh and material per kind, and the outline's materials (the U view's drawn through the
## cap), shared by every slot.
var _floor_mesh: BoxMesh = null
var _floors: Array[StandardMaterial3D] = []
var _outline_material: StandardMaterial3D = null
var _outline_below_material: StandardMaterial3D = null
## Room builds so far (tests: a view switch builds none).
var room_builds: int = 0


func configure(chambers: ChambersScript, props: PropsScript = null) -> void:
	"""Draw these chambers with these props (none: boxes). Builds every node once."""
	name = "BurrowView"
	_chambers = chambers
	_props = props if props != null else PropsScript.new()
	_floor_mesh = BoxMesh.new()
	_floor_mesh.size = Vector3(ChambersScript.CHAMBER_SIDE_Q, ROOM_FLOOR_THICK_M, ChambersScript.CHAMBER_SIDE_Q)
	_floors = [_rough(HOME_FLOOR), _rough(CELLAR_FLOOR)]
	_outline_material = _flat(Palette.CREAM)
	_outline_below_material = _flat(Palette.CREAM)
	_outline_below_material.no_depth_test = true
	_outline_below_material.render_priority = OUTLINE_BELOW_PRIORITY
	_room_key.resize(ChambersScript.MAX_CHAMBERS)
	_room_key.fill(-1)
	var outline_mesh: Mesh = _outline_mesh()
	for c in ChambersScript.MAX_CHAMBERS:
		_outlines.append(_outline(outline_mesh, _outline_material, Layers.SURFACE_MARKS))
		_outlines_below.append(_outline(outline_mesh, _outline_below_material, Layers.UNDERGROUND_MARKS))
		_mounds.append(_mound())
		_cellars.append(_cellar_door())
		_rooms.append(Node3D.new())
		add_child(_rooms[c])
		_labels.append(_label(Layers.SURFACE_MARKS))
		_labels_below.append(_label(Layers.UNDERGROUND_MARKS))


func set_cap(cap: CapScript) -> void:
	"""The underground view's cap: every room dug opens it (those dug before too)."""
	_cap = cap
	for c in ChambersScript.MAX_CHAMBERS:
		if _room_key[c] >= 0:
			_open_cap(c)


func register(prewarm: PrewarmScript) -> void:
	"""What the rooms and the U view's marks draw, for its prewarm (decision 0206)."""
	for material: StandardMaterial3D in _floors:
		prewarm.add_mesh(_floor_mesh, material)
	for key: StringName in [BED_KEY, BASKET_KEY]:
		prewarm.add_mesh(_props.mesh_of(key))
	prewarm.add_mesh(_outlines_below[0].mesh, _outline_below_material)
	prewarm.add_label(_labels_below[0])


func _outline_mesh() -> Mesh:
	"""A chamber's floor outline: four thin cream strips (a unit square, scaled when placed)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(ChambersScript.CHAMBER_SIDE_Q) * 0.5
	for part: Transform3D in [Transform3D(Basis.from_scale(Vector3(2.0 * half, 0.01, OUTLINE_WIDTH_M)), Vector3(0.0, 0.0, half)),
			Transform3D(Basis.from_scale(Vector3(2.0 * half, 0.01, OUTLINE_WIDTH_M)), Vector3(0.0, 0.0, -half)),
			Transform3D(Basis.from_scale(Vector3(OUTLINE_WIDTH_M, 0.01, 2.0 * half)), Vector3(half, 0.0, 0.0)),
			Transform3D(Basis.from_scale(Vector3(OUTLINE_WIDTH_M, 0.01, 2.0 * half)), Vector3(-half, 0.0, 0.0))]:
		tool.append_from(BoxMesh.new(), 0, part)
	return tool.commit()


func _outline(mesh: Mesh, material: Material, layer: int) -> MeshInstance3D:
	"""A planned chamber's outline on `layer`, hidden until placed."""
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.layers = layer
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


func _label(layer: int) -> Label3D:
	"""A chamber's name on `layer`, over it."""
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL
	label.font_size = LABEL_PX
	label.outline_size = 8
	label.modulate = Palette.CREAM
	label.outline_modulate = Palette.DEEP_SHADE
	label.no_depth_test = true
	label.layers = layer
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


func refresh() -> void:
	"""Redraw when the chambers changed (never for the view: see BUILT WHEN DUG)."""
	if _chambers.revision == _seen:
		return
	_seen = _chambers.revision
	for c in ChambersScript.MAX_CHAMBERS:
		_draw(c)


func _draw(c: int) -> void:
	"""One chamber slot, from its phase and kind: its surface nodes, its names and outlines in both views,
	and its room (built only when that changed)."""
	var phase := _chambers.phase[c]
	var at := _chambers.centre_m(c)
	var done := phase == ChambersScript.PHASE_DONE
	var cellar := _chambers.kind[c] == ChambersScript.KIND_CELLAR
	_outlines[c].visible = phase == ChambersScript.PHASE_PLANNED
	_outlines[c].position = Vector3(at.x, LIFT_M, at.y)
	_outlines_below[c].visible = _outlines[c].visible
	_outlines_below[c].position = Vector3(at.x, ROOM_FLOOR_Y_M + LIFT_M, at.y)
	_mounds[c].visible = done and not cellar
	_mounds[c].position = Vector3(at.x, 0.0, at.y)
	_cellars[c].visible = done and cellar
	_cellars[c].position = Vector3(at.x, 0.0, at.y)
	var text: String = ChambersScript.KIND_NAMES[_chambers.kind[c]] + ("" if done else " (digging)")
	_name(_labels[c], text, phase, Vector3(at.x, 1.3 if done else 0.6, at.y))
	_name(_labels_below[c], text, phase, Vector3(at.x, ROOM_FLOOR_Y_M + LABEL_BELOW_LIFT_M, at.y))
	var key: int = _chambers.generation[c] * 4 + _chambers.kind[c] if done else -1
	if key != _room_key[c]:
		_room_key[c] = key
		_build_room(c, done, at)


static func _name(label: Label3D, text: String, phase: int, at: Vector3) -> void:
	"""A chamber's name at `at`, shown while the slot holds a chamber."""
	label.visible = phase != ChambersScript.PHASE_FREE
	label.position = at
	label.text = text


func _build_room(c: int, show: bool, at: Vector2) -> void:
	"""The room below, built when its chamber is done: its floor and, for a home, its beds, for a cellar,
	its baskets -- all on the underground layer, the cap opened over it (see BUILT WHEN DUG)."""
	var room := _rooms[c]
	for child in room.get_children():
		room.remove_child(child)
		child.queue_free()
	room.visible = show
	if not show:
		return
	room.position = Vector3(at.x, ROOM_FLOOR_Y_M, at.y)
	var home := _chambers.kind[c] == ChambersScript.KIND_HOME
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = _floor_mesh
	floor_node.material_override = _floors[0 if home else 1]
	room.add_child(floor_node)
	if home:
		for spot: Vector3 in HOME_BEDS_AT:
			_furnish(room, BED_KEY, spot)
		_furnish(room, BASKET_KEY, HOME_BASKET_AT)
	else:
		for spot: Vector3 in CELLAR_BASKETS_AT:
			_furnish(room, BASKET_KEY, spot)
	Layers.set_layers(room, Layers.UNDERGROUND)
	room_builds += 1
	_open_cap(c)


func _open_cap(c: int) -> void:
	"""Stamp chamber `c`'s floor into the cap's void mask (see the header)."""
	if _cap == null:
		return
	_cap.stamp_rect(_chambers.centre_m(c), float(ChambersScript.CHAMBER_SIDE_Q) * 0.5)
	_cap.commit_void()


func _furnish(room: Node3D, key: StringName, at: Vector3) -> void:
	"""One piece of furniture in a room (built only when the room is)."""
	var piece: MeshInstance3D = _props.instance(key)
	piece.position += at
	room.add_child(piece)


func label(c: int) -> Label3D:
	"""Chamber `c`'s name label on the surface (for checks)."""
	return _labels[c]


func label_below(c: int) -> Label3D:
	"""Chamber `c`'s name as the U view draws it (for checks)."""
	return _labels_below[c]


func room(c: int) -> Node3D:
	"""Chamber `c`'s room below (for checks)."""
	return _rooms[c]


func cellar_door(c: int) -> Node3D:
	"""Chamber `c`'s cellar on the surface (for checks)."""
	return _cellars[c]
