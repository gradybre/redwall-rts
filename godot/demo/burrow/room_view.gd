extends Node3D
## What the rooms look like: burrow homes and root cellars as cozy dug chambers that belong to the tunnels.
## Decision 0209 (the underground revamp's P3; design docs/design/underground_revamp.md §2 "Living", §5, §6
## "Rooms"), replacing burrow_view.gd's slabs; its layers and when it builds are decision 0206's. Presentation
## only.
##
## BELOW (the underground layers, which only the U view draws), per room:
##   * THE SHELL (room_mesh.gd): the bores' own horseshoe grown to a room -- a round lathe for a home, a barrel
##     vault for a cellar -- in the bores' earth, strata and damp (bore_surface.gdshaderinc), cut clean at the
##     section plane, its packed floor worn down the middle. A home's wall bows out into an ALCOVE round each
##     bed; a cellar is STONE-LINED, cool grey-blue. It opens where its door ramp and every tunnel joined at a
##     socket come in.
##   * STAGED DIGGING: while its body is dug the shell grows in STAGES from the door -- a home's floor a disc
##     tangent at the door, a cellar's vault lengthening from its hatch end -- rebuilt only when a stage is
##     reached; the cap's void mask (underground_cap.gd) opens over each stage.
##   * DRYING (decision 0211: "fresh walls stay dark and damp, then dry to a paler colour over a game day"): each
##     stage remembers the calendar day it was reached, and every point of the shell carries the day of the stage that
##     first took it in, so the walls dry from the door outward as they were dug -- and a shell rebuilt later (a socket
##     broken through) keeps its walls' own days. While the body is dug, the newest stage's walls are FRESH-CUT
##     (COLOR.a, bore_surface.gdshaderinc THE FACE): the room's dig face.
##   * TIMBER: a RING BEAM just inside the wall, under the section plane -- round a home, a rectangle of wall plates
##     in a cellar (room_mesh.gd `build_beam`) -- carried by the library's tunnel_brace (tunnel_marks.gd's frame)
##     framing the door and every socket, as tall as the beam is high: a few clear posts carrying one ring, read
##     from above, not a row of stumps cut off by the section.
##   * ITS LANTERN (underground_rooms.gd WALL_LANTERN): a wall lantern by the door whose light is one of the pooled
##     lights (tunnel_lanterns.gd `set_room_spots`) -- a home's warm, a cellar's cooler. What else stands in a room
##     is its fit-out, the player's (decision 0210: room_fixtures.gd, drawn by fixture_view.gd); a dug room is bare.
##   * Its outline and name, over the cap, while it is laid and being dug.
## ON THE GROUND (the surface layers): while laid and dug, a cream outline and its name; dug, its turfed MOUND --
## the room itself rising 1.5 m over the ground under its turf (underground_rooms.gd HEADROOM), a low round bank
## flaring into a skirt (room_mesh.gd `build_mound`) in the village ground's grass (`set_turf`: the ground's own
## material, its worn paths left off, sampled in world x, z so it is the grass round it). It is CUT where the door
## ramp comes in: a bank of bare earth at the room's wall (`build_face`). A home's ramp is an open cutting down to its
## round front DOOR (tunnel_overlay.gd draws the cutting, tunnel_mouth.gd END_DOOR): since P7 (decision 0371) the
## library's burrow door -- its stone face, timber ring and lintel standing on the cutting's floor, its round LEAF
## split from it (make_demo_derived_props.py `burrow_door_open`) and hung from a hinge that SWINGS IT OPEN when a
## resident comes through and shut behind it (door_swing.gd); unstaged, a wooden leaf in a timber ring on a fieldstone
## sill that swings the same. A cellar has a HATCH against its face, two plank leaves sloping down over the top of its
## steps in a timber frame (a root cellar's bulkhead). The mound and the ramp are obstacles on the ground (cast_space.gd
## `set_mound`) from the moment the room is laid.
##
## BUILT WHEN DUG. A room's nodes are built once per room row; its shell, ribs, fit-out and mound are built when
## its dig reaches a stage or finishes (or its openings change), never when the view switches -- a switch
## touches nothing here. PREWARM: the U view's pieces register with its prewarm (`register`); the ground's --
## the mound in the ground's grass, its earth face, the doors' and hatches' lit rough material -- are sampled for
## two frames under the ground where the camera looks while the opening pause holds (`begin_surface_prewarm`,
## a demo_prewarm.gd frame step), so the first room dug compiles nothing on a running clock.
## `refresh()` checks each room's key when the network or the rooms changed, and each room
## being dug when its percent dug did (a digging dig moves no revision) -- so its shell grows stage by stage and
## its name's "(digging N%)" keeps count; an idle frame costs a comparison a room.
##
## LEVELS (decision 0212). A room is drawn on its level: its shell in that level's earth (bore_view.gd
## `hub_material(level)`), everything below on that level's layer and floor, its ribs cut at that level's section,
## its void stamped into that level's cap, its outline and name on that level's marks layer and floor. A room on
## level 2 has NOTHING on the ground -- no mound, no door or hatch, no obstacle, no surface outline or name (the
## surface's signs are the top level's) -- and its door is a socket, opened where its passage comes in.

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomMeshScript := preload("res://demo/burrow/room_mesh.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const FixtureKitScript := preload("res://demo/burrow/fixture_kit.gd")
const DoorSwingScript := preload("res://demo/burrow/door_swing.gd")

## The shell grows in this many stages while the body is dug.
const STAGES: int = 6
## The newest stage's walls while the room is dug read this fresh-cut (1 - COLOR.a; see DRYING).
const FACE_MARK: float = 0.75
## A bed nook's floor is opened in the cap by this many discs along its axis.
const NOOK_DISCS: int = 5
const OUTLINE_WIDTH_M: float = 0.12
const LIFT_M: float = 0.05
const OUTLINE_SEGMENTS: int = 40
const OUTLINE_BELOW_PRIORITY: int = 4
const LABEL_PX: int = 32
const LABEL_PIXEL: float = 0.0006
const LABEL_BELOW_LIFT_M: float = 1.0
const LABEL_ABOVE_M: float = 2.3
## The mound: the room's crown (1.5 m over the ground) and 0.4 m of turf.
const MOUND_TOP_M: float = 1.9
## The mound's turf reaches this far beyond its obstacle's reach (the skirt, low enough to be walked by).
const MOUND_FLARE_M: float = 0.9
## The cut for the door: its earth face at the room's wall, this far either side of the ramp (m, per template).
const NOTCH_HALF_M: Array[float] = [0.0, 1.0, 0.8]
const FACE_EARTH: Color = Color(0.36, 0.25, 0.16)
const DOOR_RADIUS_M: float = 0.56
const TURF: Color = Color(0.33, 0.43, 0.22)
const DOOR_WOOD: Color = Color(0.42, 0.25, 0.13)
const DOOR_STONE: Color = Color(0.52, 0.5, 0.45)
const KNOB: Color = Color(0.78, 0.63, 0.3)
const HATCH_WOOD: Color = Color(0.46, 0.33, 0.2)
const TIMBER_RING: Color = Color(0.3, 0.19, 0.1)
## A cellar's hatch leaves: this long, leaning this far (rad) back from flat against the face.
const HATCH_RUN_M: float = 1.6
const HATCH_SLOPE_RAD: float = 0.6
## Keys of the shared meshes (`_shared`): a template's mound, face and ring beam, and each door and hatch part.
const SHARED_MOUND: int = 0
const SHARED_FACE: int = 10
const SHARED_BEAM: int = 20
const SHARED_LEAF: int = 30
const SHARED_RING: int = 31
const SHARED_KNOB: int = 32
const SHARED_SILL: int = 33
const SHARED_BOARD: int = 34
const SHARED_RAIL: int = 35
const SHARED_HATCH_SILL: int = 36
## The lanterns' light: a home's warm, a cellar's cooler (grey-blue walls, a paler flame).
const HOME_LIGHT: Color = Color(1.0, 0.7, 0.38)
const CELLAR_LIGHT: Color = Color(0.86, 0.86, 0.9)
const LANTERN_LIFT_M: float = 0.8
const GLOW_IN_CAGE: Vector2 = MarksScript.GLOW_IN_CAGE
## The frames at the door and sockets: FRAME_POST_M posts scaled to stand under the ring beam, whose middle is
## BEAM_Y_M over the floor (its top under the section plane, Layers.CAP_Y_M), BEAM_INSET_M inside the wall.
const RIB_TALL_M: float = 0.86
const BEAM_Y_M: float = 0.93
const BEAM_WIDTH_M: float = 0.16
const BEAM_DEPTH_M: float = 0.14
const BEAM_INSET_M: float = 0.14
const MAX_FRAMES: int = 16
const LANTERN_KEY: StringName = &"wall_lantern"
## The staged burrow door, in parts (see ON THE GROUND): its frame and its leaf, hung by the leaf's left edge (its iron
## straps' end) -- the hinge, seen from the cutting.
const DOOR_KEY: StringName = &"burrow_door_open"
const DOOR_FRAME: String = "frame"
const DOOR_LEAF: String = "leaf"

var _network: GraphScript = null
var _rooms: RoomsScript = null
var _props: PropsScript = null
var _space: CastSpaceScript = null
var _marks: MarksScript = null
var _cap: CapScript = null
## Each level's cap (index 0 unused; see LEVELS), and the one a room's stamps go to while it is stamped.
var _caps: Array[CapScript] = [null, null, null]
var _stamp_cap: CapScript = null
## Each level's rib cutaway (index 0 unused), and the level each room row was last drawn on (-1: never).
var _rib_materials: Array[ShaderMaterial] = [null, null, null]
var _row_level: PackedInt32Array = PackedInt32Array()
var _seen: Vector2i = Vector2i(-1, -1)
var _key: PackedInt64Array = PackedInt64Array()
## Each room's percent dug when it was last looked at (-1: no room).
var _percent: PackedInt32Array = PackedInt32Array()
## The ground's pieces sampled for the boot prewarm (see PREWARM); null when none stand.
var _surface_samples: Node3D = null
## The meshes every room shares, built once (see `_mound_mesh`): keyed SHARED_* (+ template).
static var _shared: Dictionary = {}
var _mound_gen: PackedInt32Array = PackedInt32Array()
## Per room row: its node below, its shell, its ribs, its fit-out and lantern glow; its mound above; outlines and
## names in both views.
var _below: Array[Node3D] = []
var _shells: Array[MeshInstance3D] = []
var _frames: Array[MultiMeshInstance3D] = []
var _beams: Array[MeshInstance3D] = []
var _beam_material: StandardMaterial3D = null
var _furniture: Array[Node3D] = []
var _above: Array[Node3D] = []
var _outlines: Array[MeshInstance3D] = []
var _outlines_below: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _labels_below: Array[Label3D] = []
var _outline_material: StandardMaterial3D = null
var _outline_below_material: StandardMaterial3D = null
var _rib_material: ShaderMaterial = null
var _materials: Dictionary = {}
var _openings: PackedFloat32Array = PackedFloat32Array()
var _alcoves: PackedFloat32Array = PackedFloat32Array()
var _nooks: PackedFloat32Array = PackedFloat32Array()
var _today: Callable = Callable()
var _turf: Material = null
## The homes' front doors swinging (see ON THE GROUND).
var door_swing: DoorSwingScript = DoorSwingScript.new()
## Shell builds so far (tests: a view switch builds none).
var shell_builds: int = 0
## Others' pieces on the ground sampled with the rooms' (`add_ground_sampler`: the construction theatre's).
var _ground_samplers: Array[Callable] = []
## Per room row, per stage: the calendar day it was reached; how far the days are recorded and for which room
## generation (see DRYING).
var _stage_day: PackedFloat32Array = PackedFloat32Array()
var _days_to: PackedInt32Array = PackedInt32Array()
var _days_gen: PackedInt32Array = PackedInt32Array()
## Per room row, per fixture place: the day its bed nook was dug (a nook is dug later than its room; see DRYING).
var _nook_day: PackedFloat32Array = PackedFloat32Array()
var _nooks_seen: PackedInt32Array = PackedInt32Array()


func configure(network: GraphScript, props: PropsScript, space: CastSpaceScript, marks: MarksScript) -> void:
	"""Draw this network's rooms with these props (none staged: boxes), their mounds obstacles in `space`, their
	ribs and lanterns as `marks` draws a tunnel's. Builds every room row's nodes once."""
	name = "RoomView"
	_network = network
	_rooms = network.rooms
	_props = props if props != null else PropsScript.new()
	_space = space
	_marks = marks
	door_swing.configure(RoomsScript.MAX_ROOMS)
	_outline_material = _flat(Palette.CREAM)
	_outline_below_material = _flat(Palette.CREAM)
	_outline_below_material.no_depth_test = true
	_outline_below_material.render_priority = OUTLINE_BELOW_PRIORITY
	_make_rib_materials(marks)
	_beam_material = StandardMaterial3D.new()
	_beam_material.albedo_color = TIMBER_RING
	_beam_material.roughness = 1.0
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_key.resize(RoomsScript.MAX_ROOMS)
	_key.fill(-1)
	_percent.resize(RoomsScript.MAX_ROOMS)
	_percent.fill(-1)
	_mound_gen.resize(RoomsScript.MAX_ROOMS)
	_size_day_columns()
	for r in RoomsScript.MAX_ROOMS:
		_build_row()


func _make_rib_materials(marks: MarksScript) -> void:
	"""Each level's ribs' cutaway, cut just under its section (see LEVELS), and the rows' levels (none drawn yet)."""
	for level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		_rib_materials[level] = MarksScript.cutaway_of(marks.brace_mesh().surface_get_material(0))
		_rib_materials[level].set_shader_parameter(&"cut_y", Layers.cap_y(level) - 0.02)
	_rib_material = _rib_materials[Rules.TOP_LEVEL]
	_row_level.resize(RoomsScript.MAX_ROOMS)
	_row_level.fill(-1)


func _size_day_columns() -> void:
	"""The drying's columns (see DRYING), sized once: each room's stage days, how far they are recorded and for which
	generation, and its nooks' days."""
	_stage_day.resize(RoomsScript.MAX_ROOMS * (STAGES + 1))
	_days_to.resize(RoomsScript.MAX_ROOMS)
	_days_gen.resize(RoomsScript.MAX_ROOMS)
	_days_gen.fill(-1)
	_nook_day.resize(RoomsScript.MAX_ROOMS * RoomsScript.MAX_PLACES)
	_nooks_seen.resize(RoomsScript.MAX_ROOMS)


func _build_row() -> void:
	"""One room row's nodes, hidden: below, above, outlines and names."""
	var below_root := Node3D.new()
	below_root.visible = false
	add_child(below_root)
	_below.append(below_root)
	_shells.append(_child_mesh(below_root, BoreViewScript.hub_material()))
	_frames.append(_rib_node(below_root))
	_beams.append(_child_mesh(below_root, _beam_material))
	var furniture_root := Node3D.new()
	below_root.add_child(furniture_root)
	_furniture.append(furniture_root)
	Layers.set_layers(below_root, Layers.UNDERGROUND)
	var above_root := Node3D.new()
	above_root.visible = false
	add_child(above_root)
	_above.append(above_root)
	_outlines.append(_outline_node(_outline_material, Layers.SURFACE_MARKS))
	_outlines_below.append(_outline_node(_outline_below_material, Layers.UNDERGROUND_MARKS))
	_labels.append(_label(Layers.SURFACE_MARKS))
	_labels_below.append(_label(Layers.UNDERGROUND_MARKS))


func _rib_node(parent: Node3D) -> MultiMeshInstance3D:
	"""A room's ribs under `parent`: up to MAX_FRAMES brace frames, in the ribs' cutaway, none shown yet."""
	var rib_set := MultiMeshInstance3D.new()
	rib_set.multimesh = MultiMesh.new()
	rib_set.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rib_set.multimesh.mesh = _marks.brace_mesh()
	rib_set.multimesh.instance_count = MAX_FRAMES
	rib_set.multimesh.visible_instance_count = 0
	rib_set.material_override = _rib_material
	rib_set.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rib_set)
	return rib_set


func _child_mesh(parent: Node3D, material: Material) -> MeshInstance3D:
	"""A shadowless mesh node under `parent` drawing an empty ArrayMesh in `material`."""
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _outline_node(material: Material, layer: int) -> MeshInstance3D:
	"""A room's outline on `layer`: an ImmediateMesh, hidden until drawn."""
	var node := MeshInstance3D.new()
	node.mesh = ImmediateMesh.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = layer
	node.visible = false
	add_child(node)
	return node


func _label(layer: int) -> Label3D:
	"""A room's name on `layer`, hidden until drawn."""
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = LABEL_PIXEL
	tag.font_size = LABEL_PX
	tag.outline_size = 8
	tag.modulate = Palette.CREAM
	tag.outline_modulate = Palette.DEEP_SHADE
	tag.no_depth_test = true
	tag.layers = layer
	tag.visible = false
	add_child(tag)
	return tag


static func _flat(colour: Color) -> StandardMaterial3D:
	"""An unshaded material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


func _rough(colour: Color) -> StandardMaterial3D:
	"""A lit rough material, one per colour, shared."""
	if not _materials.has(colour):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 1.0
		_materials[colour] = material
	return _materials[colour]


func set_cap(cap: CapScript, deep_cap: CapScript = null) -> void:
	"""The underground view's caps (level 1's; level 2's when given): every room dug opens its level's (those dug
	before too)."""
	_cap = cap
	_caps[Rules.TOP_LEVEL] = cap
	_caps[Rules.LEVEL_2] = deep_cap
	_key.fill(-1)
	_seen = Vector2i(-1, -1)


func register(prewarm: PrewarmScript) -> void:
	"""What the rooms and their marks draw in the U view, for its prewarm (decision 0206): a sample shell in the
	hubs' material, the ribs' cutaway, the fit-out's props, the glow, the outline and the name."""
	var sample := ArrayMesh.new()
	RoomMeshScript.build_round(sample, Vector3.ZERO, 1.0, 1.0, PackedFloat32Array(), PackedFloat32Array(), 0.0, 1.0, 0.0)
	for level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		prewarm.add_mesh(sample, BoreViewScript.hub_material(level))
		prewarm.add_multimesh(_marks.brace_mesh(), _rib_materials[level])
	prewarm.add_mesh(_beam_mesh(RoomsScript.TEMPLATE_HOME), _beam_material)
	prewarm.add_mesh(_props.mesh_of(LANTERN_KEY))
	prewarm.add_mesh(_marks.glow_mesh())
	prewarm.add_mesh(OverlayScript.immediate_sample(), _outline_below_material)
	prewarm.add_label(_labels_below[0])


func begin_surface_prewarm() -> void:
	"""Stand one of each kind of the rooms' pieces on the ground -- the mound in the ground's grass, its earth
	face, a board in the doors' timber, a chimney and a puff of its smoke (decision 0210) -- 3 m under the ground
	where the camera looks, so
	their pipelines compile while the opening pause holds (see PREWARM)."""
	end_surface_prewarm()
	_surface_samples = Node3D.new()
	_surface_samples.name = "RoomSurfacePrewarm"
	add_child(_surface_samples)
	var pairs: Array = [[_mound_mesh(RoomsScript.TEMPLATE_HOME), _turf_material()],
		[_face_mesh(RoomsScript.TEMPLATE_HOME), _rough(FACE_EARTH)], [BoxMesh.new(), _rough(DOOR_WOOD)]]
	for pair: Array in pairs:
		var sample := MeshInstance3D.new()
		sample.mesh = pair[0]
		sample.material_override = pair[1]
		_surface_samples.add_child(sample)
	FixtureKitScript.register_ground(_surface_samples, _props)
	for sampler in _ground_samplers:
		sampler.call(_surface_samples)
	Layers.set_layers(_surface_samples, Layers.SURFACE)
	_surface_samples.position = _under_the_view()


func add_ground_sampler(sampler: Callable) -> void:
	"""`sampler(parent: Node3D)` stands one of each of its pieces on the ground under `parent` with the rooms' (see
	PREWARM): the construction theatre's seams, vents, baskets and particles (decision 0211)."""
	_ground_samplers.append(sampler)


func end_surface_prewarm() -> void:
	"""Take the prewarm's samples away (see PREWARM)."""
	if _surface_samples != null:
		_surface_samples.queue_free()
		_surface_samples = null


func surface_samples() -> Node3D:
	"""The prewarm's samples while they stand (null: none; for the checks)."""
	return _surface_samples


func _under_the_view() -> Vector3:
	"""Where the prewarm's samples stand: under the view of the camera (the origin's, without one)."""
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return under_view(camera.global_transform if camera != null else Transform3D.IDENTITY)


static func under_view(camera: Transform3D) -> Vector3:
	"""A point 3 m under the ground 12 m ahead of a camera placed so."""
	var ahead := camera.origin - camera.basis.z * 12.0
	return Vector3(ahead.x, -3.0, ahead.z)


# --- redrawing --------------------------------------------------------------------------------

func refresh() -> void:
	"""Redraw each room whose key changed: every room when the network or the rooms did, else the rooms whose
	percent dug did (see BUILT WHEN DUG)."""
	var seen := Vector2i(_network.revision, _rooms.revision)
	var all := seen != _seen
	_seen = seen
	for r in RoomsScript.MAX_ROOMS:
		var percent := percent_dug(r)
		if not all and percent == _percent[r]:
			continue
		_percent[r] = percent
		var key := room_key(r)
		if key != _key[r]:
			_key[r] = key
			_draw(r, key >= 0)
		_draw_names(r)


func percent_dug(r: int) -> int:
	"""Whole percent of room `r`'s piece dug (its ramp and body; its walks are not dug), floored; -1: no room."""
	if not _rooms.is_room(r):
		return -1
	var ramp := _rooms.ramp[r]
	var body := _rooms.body[r]
	var total := _network.total_ticks(body) + (_network.total_ticks(ramp) if ramp >= 0 else 0)
	@warning_ignore("integer_division") return (_network.done(body) + (_network.done(ramp) if ramp >= 0 else 0)) * 100 / maxi(total, 1)


func room_key(r: int) -> int:
	"""Everything room `r`'s drawing depends on, as one number (-1: no room): its generation, template, turns,
	dig stage, whether it is paused, which sockets have a tunnel broken through, and its bed nooks."""
	if not _rooms.is_room(r):
		return -1
	var paused := 1 if _network.phase[_rooms.body[r]] == GraphScript.PHASE_PAUSED \
			or _network.phase[_rooms.first_segment(r)] == GraphScript.PHASE_PAUSED else 0
	var key := (_rooms.generation[r] % 65536) * 4 + int(_rooms.turns[r])
	key = ((key * 4 + int(_rooms.template[r])) * (STAGES + 1) + stage(r)) * 2 + paused
	return (key * 16 + _joined_mask(r)) * 256 + _rooms.nooks[r]


func stage(r: int) -> int:
	"""How far room `r`'s shell has grown: 0 before its body breaks ground, STAGES once dug, and in between the
	stages its body's dig has reached (at least the first once any of it is dug)."""
	if _rooms.is_done(_network, r):
		return STAGES
	var dug := _rooms.dug_permille(_network, r)
	@warning_ignore("integer_division") return 0 if dug <= 0 else clampi(dug * STAGES / Rules.PERMILLE, 1, STAGES - 1)


func _joined_mask(r: int) -> int:
	"""Which of room `r`'s sockets a tunnel has broken through (one bit a socket)."""
	var mask := 0
	for k in RoomsScript.socket_count(_rooms.template[r]):
		if joined_at(r, k) >= 0:
			mask |= 1 << k
	return mask


func joined_at(r: int, k: int) -> int:
	"""The tunnel segment broken through into room `r` at socket `k` (-1: none): the other segment at its socket,
	once it is open."""
	var node := _rooms.socket_of(r, k)
	if node < 0 or not _network.is_node(node):
		return -1
	for j in GraphScript.DEGREE:
		var slot := _network.node_segment(node, j)
		if slot >= 0 and _network.seg_room[slot] != r and _network.is_open(slot):
			return slot
	return -1


func _draw(r: int, shown: bool) -> void:
	"""Room row `r` as it stands (see BELOW and ON THE GROUND)."""
	var grown := stage(r) if shown else 0
	var done := grown == STAGES
	var top := not shown or _rooms.level[r] == Rules.TOP_LEVEL
	_put_on_level(r)
	_draw_marks(r, shown and not done)
	_below[r].visible = grown > 0
	if grown > 0:
		_record_days(r, grown)
		_build_shell(r, grown)
		_restamp(r, grown)
		_stamp(r, grown)
	_frames[r].visible = done
	_beams[r].visible = done
	_clear(_furniture[r])
	_above[r].visible = done and top
	_clear(_above[r])
	door_swing.clear(r)
	if done:
		_fit_out(r)
	if done and top:
		_build_mound(r)
	_marks.lights.set_room_spots(r, _lantern_spots(r) if done else PackedVector3Array(),
		HOME_LIGHT if shown and _rooms.template[r] == RoomsScript.TEMPLATE_HOME else CELLAR_LIGHT)
	_place_mound(r, shown and top)


func _put_on_level(r: int) -> void:
	"""Room row `r`'s nodes on its room's level (see LEVELS), rewritten only when the row's level changed: the shell's
	earth, the layers below, the ribs' cutaway, and its outline and name's marks layer."""
	var level: int = _rooms.level[r] if _rooms.is_room(r) else Rules.TOP_LEVEL
	if level == _row_level[r]:
		return
	_row_level[r] = level
	_shells[r].material_override = BoreViewScript.hub_material(level)
	_frames[r].material_override = _rib_materials[level]
	Layers.set_layers(_below[r], Layers.below(level))
	_outlines_below[r].layers = Layers.marks(level)
	_labels_below[r].layers = Layers.marks(level)


func _floor_y(r: int) -> float:
	"""Room `r`'s floor height (m): its level's."""
	return Layers.floor_y(_rooms.level[r])


func _place_mound(r: int, shown: bool) -> void:
	"""Room `r`'s mound and door ramp stand as obstacles from the moment it is laid -- the heaps are placed off them
	and nobody walks over the dig -- and go with it; the navigation is rebuilt only when that changes."""
	var stands := _rooms.generation[r] + 1 if shown else 0
	if stands == _mound_gen[r]:
		return
	_mound_gen[r] = stands
	_space.set_mound(r, mound_circles(r) if shown else PackedVector3Array())


static func _clear(holder: Node3D) -> void:
	"""Free every child of `holder` (a room's fit-out or mound, rebuilt)."""
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


# --- names and outlines -----------------------------------------------------------------------

func _draw_marks(r: int, shown: bool) -> void:
	"""Room `r`'s outline in both views while it is laid and dug."""
	var top := _rooms.level[r] == Rules.TOP_LEVEL
	_outlines[r].visible = shown and top
	_outlines_below[r].visible = shown
	if shown:
		outline_into(_outlines[r].mesh as ImmediateMesh, _outline_material, _rooms.template[r], _rooms.centre_m(r),
			_rooms.turns[r], LIFT_M, top)
		_outlines_below[r].mesh = _outlines[r].mesh
		_outlines_below[r].position.y = _floor_y(r)


func _draw_names(r: int) -> void:
	"""Room `r`'s name and state in both views -- over its outline while it is dug, over its mound once dug."""
	var live := _rooms.is_room(r)
	var at := _rooms.centre_m(r) if live else Vector2.ZERO
	var text := status_text(r) if live else ""
	var high := LABEL_ABOVE_M if live and _rooms.is_done(_network, r) else 0.6
	var floor_y := _floor_y(r) if live else Layers.FLOOR_Y_M
	_name(_labels[r], text, live and _rooms.level[r] == Rules.TOP_LEVEL, Vector3(at.x, high, at.y))
	_name(_labels_below[r], text, live, Vector3(at.x, floor_y + LABEL_BELOW_LIFT_M, at.y))


func status_text(r: int) -> String:
	"""Room `r`'s name and its state: "Burrow home 1 (planned)", "Root cellar 2 (digging 40%)"."""
	var name_text := "%s %d" % [RoomsScript.NAMES[_rooms.template[r]], r + 1]
	if _rooms.is_done(_network, r):
		return name_text
	var percent := percent_dug(r)
	if percent <= 0 and _network.phase[_rooms.first_segment(r)] != GraphScript.PHASE_DIGGING:
		return name_text + " (planned)"
	return "%s (digging %d%%)" % [name_text, percent]


static func _name(tag: Label3D, text: String, is_shown: bool, at: Vector3) -> void:
	"""A room's name at `at`, shown while its row holds a room (written only when it changed)."""
	tag.visible = is_shown
	tag.position = at
	if tag.text != text:
		tag.text = text


static func outline_into(mesh: ImmediateMesh, material: Material, kind: int, centre: Vector2, turns: int, lift: float,
		with_ramp: bool = true) -> void:
	"""A room's outline on the ground plane (y = `lift` in the mesh's own frame): its void's edge -- a circle, or a
	vault's box -- its door ramp's two sides out to its mouth (`with_ramp`; a level-2 room's door is a socket, ticked
	as one), and a short tick at each socket. Also the room tool's ghost (room_tool.gd)."""
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	mesh.surface_set_normal(Vector3.UP)
	var points := void_outline(kind, centre, turns)
	for k in points.size():
		_strip(mesh, points[k], points[(k + 1) % points.size()], lift)
	var door := _m(RoomsScript.door_at(kind, _u(centre), turns))
	var hole := _m(RoomsScript.mouth_at(kind, _u(centre), turns))
	var side := (hole - door).normalized().orthogonal() * float(RoomsScript.HOOD_HALF_U) / float(Rules.UNITS_PER_M)
	if with_ramp:
		for edge: float in [-1.0, 1.0]:
			_strip(mesh, door + side * edge, hole + side * edge, lift)
		_strip(mesh, hole - side, hole + side, lift)
	else:
		_strip(mesh, door, door + (door - centre).normalized() * 0.45, lift)
	for k in RoomsScript.socket_count(kind):
		var socket := _m(RoomsScript.socket_at(kind, _u(centre), turns, k))
		var out := (socket - centre).normalized()
		_strip(mesh, socket, socket + out * 0.45, lift)
	mesh.surface_end()


static func void_outline(kind: int, centre: Vector2, turns: int) -> PackedVector2Array:
	"""A room's void's edge on the ground (m): a circle of OUTLINE_SEGMENTS points, or a vault's four corners."""
	var half := RoomsScript.void_half(kind)
	var out := PackedVector2Array()
	if RoomsScript.SHAPE[kind] == RoomsScript.SHAPE_ROUND:
		for k in OUTLINE_SEGMENTS:
			var angle := TAU * float(k) / float(OUTLINE_SEGMENTS)
			out.append(centre + Vector2(cos(angle), sin(angle)) * Rules.to_m(half.x))
		return out
	for corner: Vector2i in [half, Vector2i(-half.x, half.y), -half, Vector2i(half.x, -half.y)]:
		out.append(centre + _m(RoomsScript.rotate_u(corner, turns)))
	return out


static func _strip(mesh: ImmediateMesh, a: Vector2, b: Vector2, lift: float) -> void:
	"""One flat line from a to b, OUTLINE_WIDTH_M wide, at height `lift`."""
	var side := (b - a).normalized().orthogonal() * OUTLINE_WIDTH_M * 0.5
	for p: Vector2 in [a - side, a + side, b + side, a - side, b + side, b - side]:
		mesh.surface_add_vertex(Vector3(p.x, lift, p.y))


static func _m(at: Vector2i) -> Vector2:
	"""A point in u, in metres."""
	return Vector2(Rules.to_m(at.x), Rules.to_m(at.y))


static func _u(at: Vector2) -> Vector2i:
	"""A point in metres, in u (the import boundary)."""
	return Vector2i(Rules.to_u(at.x), Rules.to_u(at.y))


# --- the shell ------------------------------------------------------------------------------

func set_turf(turf: Material) -> void:
	"""The village ground's material, which the mounds wear (none: a plain turf green). The ground's own shader
	is kept -- a copy with its worn paths left off, so a mound is grass even over a path."""
	_turf = turf
	var ground := turf as ShaderMaterial
	if ground != null:
		_turf = ground.duplicate() as ShaderMaterial
		(_turf as ShaderMaterial).set_shader_parameter(&"path_count", 0)


func _turf_material() -> Material:
	"""What a mound is drawn in: the ground's grass, else plain turf."""
	return _turf if _turf != null else _rough(TURF)


func set_today(today: Callable) -> void:
	"""`today() -> float`: the calendar's day, which a stage's walls are dug on (their damp; bore_view.gd)."""
	_today = today


func _build_shell(r: int, grown: int) -> void:
	"""Room `r`'s shell at stage `grown` (see STAGED DIGGING), opened at its door and, dug, at every socket a
	tunnel has broken through."""
	var share := float(grown) / float(STAGES)
	var mesh := _shells[r].mesh as ArrayMesh
	if RoomsScript.SHAPE[_rooms.template[r]] == RoomsScript.SHAPE_ROUND:
		_build_round(r, mesh, share)
	else:
		_build_vault(r, mesh, share)
	shell_builds += 1


func _record_days(r: int, grown: int) -> void:
	"""The stages room `r` has newly reached, up to `grown`, were reached today (see DRYING); a room row laid again
	starts afresh."""
	if _days_gen[r] != _rooms.generation[r]:
		_days_gen[r] = _rooms.generation[r]
		_days_to[r] = 0
		_nooks_seen[r] = 0
	for s in range(_days_to[r] + 1, grown + 1):
		_stage_day[r * (STAGES + 1) + s] = _day()
	_days_to[r] = maxi(_days_to[r], grown)
	for f in RoomsScript.MAX_PLACES:
		if _rooms.has_nook(r, f) and _nooks_seen[r] & (1 << f) == 0:
			_nook_day[r * RoomsScript.MAX_PLACES + f] = _day()
	_nooks_seen[r] = _rooms.nooks[r]


func stage_day(r: int, s: int) -> float:
	"""The calendar day room `r` reached stage `s` (checks)."""
	return _stage_day[r * (STAGES + 1) + s]


func _restamp(r: int, grown: int) -> void:
	"""Room `r`'s shell, built at stage `grown`: each vertex its stage's dig day, and the newest stage fresh-cut while
	the room is dug (see DRYING)."""
	var mesh := _shells[r].mesh as ArrayMesh
	if mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in verts.size():
		var at := Vector2(verts[i].x, verts[i].z)
		var s := stage_at(r, at, grown)
		var nook := nook_at(r, at) if grown == STAGES else -1
		uv2[i].x = _nook_day[r * RoomsScript.MAX_PLACES + nook] if nook >= 0 else _stage_day[r * (STAGES + 1) + s]
		colours[i].a = 1.0 - FACE_MARK if s == grown and grown < STAGES else 1.0
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = colours
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, BoreMeshScript.HUB_FORMAT)


func stage_at(r: int, at: Vector2, grown: int) -> int:
	"""The first stage (1..`grown`) of room `r`'s shell that takes in the point `at` (x, z m): a home's disc of that
	stage (walls bowed), a cellar's vault as far as it had lengthened; `grown` for a point none takes in (an alcove)."""
	for s in range(1, grown):
		var share := float(s) / float(STAGES)
		var middle := grown_middle(r, share)
		if RoomsScript.SHAPE[_rooms.template[r]] == RoomsScript.SHAPE_ROUND:
			var radius := Rules.to_m(RoomsScript.HALF_X_U[_rooms.template[r]]) * sqrt(share) * BoreMeshScript.BULGE
			if at.distance_to(middle) <= radius + 0.05:
				return s
		else:
			var door := _m(_rooms.door_u(r))
			var along := (_rooms.centre_m(r) - door).normalized()
			if (at - door).dot(along) <= Rules.to_m(RoomsScript.HALF_Z_U[_rooms.template[r]]) * 2.0 * share + 0.05:
				return s
	return grown


func nook_at(r: int, at: Vector2) -> int:
	"""The bed nook of room `r` whose lobe the point `at` (x, z m) lies in, past the room's bowed wall (-1: none)."""
	var centre := _rooms.centre_m(r)
	if at.distance_to(centre) <= Rules.to_m(RoomsScript.HALF_X_U[_rooms.template[r]]) * BoreMeshScript.BULGE + 0.05:
		return -1
	for f in RoomsScript.MAX_PLACES:
		if _rooms.has_nook(r, f):
			var axis := _m(_rooms.nook_b(r, f)) - centre
			var off := absf(angle_difference(atan2(at.y - centre.y, at.x - centre.x), atan2(axis.y, axis.x)))
			if off < RoomsScript.NOOK_FLAT_RAD + RoomsScript.NOOK_EASE_RAD:
				return f
	return -1


func grown_middle(r: int, share: float) -> Vector2:
	"""Where room `r`'s shell is centred with `share` of it dug (m): a home's disc tangent at its door, a
	cellar's vault lengthening from its hatch end."""
	var door := _m(_rooms.door_u(r))
	var centre := _rooms.centre_m(r)
	if RoomsScript.SHAPE[_rooms.template[r]] == RoomsScript.SHAPE_ROUND:
		return door.lerp(centre, sqrt(share))
	return door.lerp(centre, share)


func _build_round(r: int, mesh: ArrayMesh, share: float) -> void:
	"""A home's lathe at `share` dug: a disc tangent at its door, its alcoves bowed out once it is dug."""
	var kind := _rooms.template[r]
	var middle := grown_middle(r, share)
	var radius := Rules.to_m(RoomsScript.HALF_X_U[kind]) * sqrt(share)
	_collect_openings(r, middle, share >= 1.0)
	_collect_bays(r, middle, share >= 1.0)
	var alcove := float(RoomsScript.ALCOVE_U) / float(RoomsScript.HALF_X_U[kind])
	var nook := float(RoomsScript.NOOK_REACH_U) / float(RoomsScript.HALF_X_U[kind]) - 1.0
	RoomMeshScript.build_round(mesh, Vector3(middle.x, _floor_y(r), middle.y), radius, Rules.crown_m(Rules.BORE_ROOM),
		_openings, _alcoves, alcove, 0.0, _day(), _nooks, nook)


func _collect_bays(r: int, middle: Vector2, done: bool) -> void:
	"""Room `r`'s bed alcoves and bed nooks (their angles from `middle`), once it is dug: a bed place with a nook is a
	nook (decision 0211), the others alcoves."""
	_alcoves.clear()
	_nooks.clear()
	if not done:
		return
	var kind := _rooms.template[r]
	for f in RoomsScript.fixture_count(kind):
		if RoomsScript.fixture_field(kind, f, 0) != RoomsScript.FIX_BED:
			continue
		var bed := _m(_rooms.to_world_u(r, Vector2i(RoomsScript.fixture_field(kind, f, 1), RoomsScript.fixture_field(kind, f, 2)))) - middle
		if _rooms.has_nook(r, f):
			_nooks.append(atan2(bed.y, bed.x))
		else:
			_alcoves.append(atan2(bed.y, bed.x))


func _build_vault(r: int, mesh: ArrayMesh, share: float) -> void:
	"""A cellar's vault at `share` dug, lengthening from its hatch end, stone-lined."""
	var kind := _rooms.template[r]
	var along := _dir(RoomsScript.rotate_u(Vector2i(0, Rules.QUANTUM_U), _rooms.turns[r]))
	var across := _dir(RoomsScript.rotate_u(Vector2i(Rules.QUANTUM_U, 0), _rooms.turns[r]))
	var middle := grown_middle(r, share)
	var half := Vector2(Rules.to_m(RoomsScript.HALF_X_U[kind]), Rules.to_m(RoomsScript.HALF_Z_U[kind]) * share)
	_collect_openings(r, middle, share >= 1.0)
	RoomMeshScript.build_vault(mesh, Vector3(middle.x, _floor_y(r), middle.y), across, along, half,
		Rules.crown_m(Rules.BORE_ROOM), _openings, 1.0, _day())


func _collect_openings(r: int, middle: Vector2, done: bool) -> void:
	"""Where room `r`'s shell (centred at `middle`) opens: its door always, and -- dug -- every socket a tunnel
	has broken through, each as (angle from the middle, floor half-width, crown)."""
	_openings.clear()
	_add_opening(middle, _m(_rooms.door_u(r)), Rules.BORE_WIDE if _rooms.level[r] == Rules.TOP_LEVEL else Rules.BORE_STANDARD)
	if not done:
		return
	for k in RoomsScript.socket_count(_rooms.template[r]):
		var slot := joined_at(r, k)
		if slot >= 0:
			_add_opening(middle, _m(_rooms.socket_u(r, k)), int(_network.bore[slot]))


func _add_opening(middle: Vector2, at: Vector2, bore: int) -> void:
	"""One opening toward `at` for a bore of class `bore`."""
	var out := at - middle
	_openings.append_array([atan2(out.y, out.x), BoreMeshScript.FLOOR_HALF_M[bore], Rules.crown_m(bore)])


func _day() -> float:
	"""The calendar's day now (0 with none)."""
	return float(_today.call()) if _today.is_valid() else 0.0


static func _dir(v: Vector2i) -> Vector2:
	"""A direction in u as a unit Vector2."""
	return Vector2(v.x, v.y).normalized()


func _stamp(r: int, grown: int) -> void:
	"""Open the cap over room `r`'s shell at stage `grown`: a home's disc (and its alcoves, dug), a cellar's
	floor box and discs along its axis."""
	_stamp_cap = _caps[_rooms.level[r]]
	if _stamp_cap == null:
		return
	var share := float(grown) / float(STAGES)
	var kind := _rooms.template[r]
	var middle := grown_middle(r, share)
	var crown := Rules.crown_m(Rules.BORE_ROOM)
	if RoomsScript.SHAPE[kind] == RoomsScript.SHAPE_ROUND:
		var radius := Rules.to_m(RoomsScript.HALF_X_U[kind])
		_stamp_cap.stamp_disc(middle, radius * sqrt(share), Vector2.ZERO, 0.0, crown)
		for angle in _alcoves:
			_stamp_cap.stamp_disc(middle + Vector2(cos(angle), sin(angle)) * radius, Rules.to_m(RoomsScript.ALCOVE_U) * 1.6,
				Vector2.ZERO, 0.0, crown)
		for angle in _nooks:
			_stamp_nook(middle, Vector2(cos(angle), sin(angle)), crown)
	else:
		_stamp_vault(r, middle, share, crown)
	_stamp_cap.commit_void()


func _stamp_nook(middle: Vector2, out: Vector2, crown: float) -> void:
	"""Open the cap over a bed nook (decision 0211) leaving `middle` along `out`: discs along its axis as wide as its
	lobe is there."""
	var reach := Rules.to_m(RoomsScript.NOOK_REACH_U)
	for k in NOOK_DISCS:
		var along := lerpf(Rules.to_m(RoomsScript.HALF_X_U[RoomsScript.TEMPLATE_HOME]), reach, float(k) / float(NOOK_DISCS - 1))
		_stamp_cap.stamp_disc(middle + out * along, along * sin(RoomsScript.NOOK_FLAT_RAD) + 0.2, Vector2.ZERO, 0.0, crown)


func _stamp_vault(r: int, middle: Vector2, share: float, crown: float) -> void:
	"""A cellar's floor box on the world's axes, and discs of its half-width along its axis (its walls rise)."""
	var kind := _rooms.template[r]
	var along := _dir(RoomsScript.rotate_u(Vector2i(0, Rules.QUANTUM_U), _rooms.turns[r]))
	var hx := Rules.to_m(RoomsScript.HALF_X_U[kind])
	var hz := Rules.to_m(RoomsScript.HALF_Z_U[kind]) * share
	_stamp_cap.stamp_box(middle, Vector2(absf(along.y) * hx + absf(along.x) * hz, absf(along.x) * hx + absf(along.y) * hz))
	var reach := maxf(hz - hx, 0.0)
	var t := -reach
	while t <= reach + 0.001:
		_stamp_cap.stamp_disc(middle + along * t, minf(hx, hz), Vector2.ZERO, 0.0, crown)
		t += 0.5


# --- the fit-out ----------------------------------------------------------------------------

func _fit_out(r: int) -> void:
	"""Room `r`'s own lantern by its door (see ITS LANTERN) and its glow, and its ribs."""
	var lantern := lantern_transform(r)
	_furniture[r].add_child(_piece(LANTERN_KEY, lantern))
	var glow := MeshInstance3D.new()
	glow.mesh = _marks.glow_mesh()
	glow.position = _glow_at(lantern)
	_furniture[r].add_child(glow)
	Layers.set_layers(_furniture[r], Layers.below(_rooms.level[r]))
	_place_ribs(r)


func _piece(key: StringName, at: Transform3D) -> MeshInstance3D:
	"""A prop of `key` placed at `at` (its fit kept)."""
	var piece: MeshInstance3D = _props.instance(key)
	piece.transform = at * piece.transform
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


func wall_lantern_transform(r: int) -> Transform3D:
	"""Where room `r`'s own lantern's place is on its floor, turned to face into the room (WALL_LANTERN)."""
	var place: Array = RoomsScript.WALL_LANTERN[_rooms.template[r]]
	var at := _m(_rooms.to_world_u(r, Vector2i(place[0], place[1])))
	var face := _dir(RoomsScript.rotate_u(Vector2i(place[2], place[3]), _rooms.turns[r]))
	return Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)), Vector3(at.x, _floor_y(r) + 0.02, at.y))


func lantern_transform(r: int) -> Transform3D:
	"""Room `r`'s wall lantern: its bracket on the wall at its place, its cage out over the room, LANTERN_LIFT_M
	up (the library's wall_lantern has its wall plate at +X, turned to the wall; tunnel_marks.gd)."""
	var placed := wall_lantern_transform(r)
	var inward := Vector2(placed.basis.z.x, placed.basis.z.z).normalized()
	var reach: float = _props.drawn_bound(LANTERN_KEY).size.x * 0.5
	var origin := Vector2(placed.origin.x, placed.origin.z) + inward * reach
	return Transform3D(Basis(Vector3.UP, atan2(inward.y, -inward.x)), Vector3(origin.x, _floor_y(r) + LANTERN_LIFT_M, origin.y))


func _glow_at(lantern: Transform3D) -> Vector3:
	"""Where a lantern hung at `lantern` glows: in its cage."""
	var size: Vector3 = _props.drawn_bound(LANTERN_KEY).size
	return lantern * Vector3(size.x * GLOW_IN_CAGE.x, size.y * GLOW_IN_CAGE.y, 0.0)


func _lantern_spots(r: int) -> PackedVector3Array:
	"""Room `r`'s lantern light spots for the pool (its one lantern's glow)."""
	return PackedVector3Array([_glow_at(lantern_transform(r))])


func _place_ribs(r: int) -> void:
	"""Room `r`'s timber: a frame at its door and at every socket, and its ring beam over them (see BELOW)."""
	var node := _frames[r]
	var kind := _rooms.template[r]
	var centre := _rooms.centre_m(r)
	var count := 0
	var floor_y := _floor_y(r)
	var door_bore := Rules.BORE_WIDE if _rooms.level[r] == Rules.TOP_LEVEL else Rules.BORE_STANDARD
	node.multimesh.set_instance_transform(count, _frame_at(_m(_rooms.door_u(r)), _m(_rooms.door_u(r)) - centre,
		BoreMeshScript.FLOOR_HALF_M[door_bore] * 2.0, floor_y))
	count += 1
	for k in RoomsScript.socket_count(kind):
		var socket := _m(_rooms.socket_u(r, k))
		node.multimesh.set_instance_transform(count, _frame_at(socket, socket - centre, BoreMeshScript.FLOOR_HALF_M[Rules.BORE_STANDARD] * 2.0,
			floor_y))
		count += 1
	node.multimesh.visible_instance_count = count
	_beams[r].mesh = _beam_mesh(kind)
	var frame := _mound_frame(r)
	_beams[r].transform = Transform3D(frame.basis, frame.origin + Vector3(0.0, floor_y, 0.0))


static func _beam_mesh(kind: int) -> ArrayMesh:
	"""Template `kind`'s ring beam (room_mesh.gd `build_beam`), built once and shared: a circle BEAM_INSET_M inside
	a home's wall, a rectangle inside a cellar's."""
	var key := SHARED_BEAM + kind
	if not _shared.has(key):
		var wall := _m(RoomsScript.void_half(kind))
		var loop := RoomMeshScript.ring_loop(wall.x - BEAM_INSET_M, 48) if RoomsScript.SHAPE[kind] == RoomsScript.SHAPE_ROUND \
				else RoomMeshScript.box_loop(wall - Vector2(BEAM_INSET_M, BEAM_INSET_M))
		_shared[key] = RoomMeshScript.build_beam(loop, BEAM_Y_M, BEAM_WIDTH_M, BEAM_DEPTH_M)
	return _shared[key]


func _frame_at(at: Vector2, facing: Vector2, width: float, floor_y: float) -> Transform3D:
	"""A brace frame standing on the room's floor (at `floor_y`) at `at`, `width` wide and RIB_TALL_M tall, its face
	turned along `facing` (so it spans across it), in the brace model's fit."""
	var yaw := atan2(facing.x, facing.y)
	var shape := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width, RIB_TALL_M / MarksScript.FRAME_POST_M, 1.0))
	return Transform3D(shape, Vector3(at.x, floor_y, at.y)) * _marks.frame_mesh_fit()


# --- the mound ------------------------------------------------------------------------------

func _build_mound(r: int) -> void:
	"""Room `r` on the ground (see ON THE GROUND): its turfed mound cut for its door, the earth face there, and
	its round door or its plank door and hatch."""
	var kind := _rooms.template[r]
	var frame := _mound_frame(r)
	for part: Array in [[_mound_mesh(kind), _turf_material()], [_face_mesh(kind), _rough(FACE_EARTH)]]:
		var node := MeshInstance3D.new()
		node.mesh = part[0]
		node.material_override = part[1]
		node.transform = frame
		_above[r].add_child(node)
	if kind == RoomsScript.TEMPLATE_HOME:
		_above[r].add_child(_door(frame, r))
	else:
		_above[r].add_child(_hatch(frame))
	Layers.set_layers(_above[r], Layers.SURFACE)


static func mound_half(kind: int, turns: int) -> Vector2:
	"""A room's mound's half extents on the world's axes (m): its void and SKIRT_U of turf."""
	var half := RoomsScript.void_half(kind) + Vector2i(RoomsScript.SKIRT_U, RoomsScript.SKIRT_U)
	var turned := half if posmod(turns, 2) == 0 else Vector2i(half.y, half.x)
	return _m(turned)


static func mound_reach(kind: int) -> Vector2:
	"""How far a room's drawn mound reaches across and along its door's axis (m): its void, SKIRT_U of turf and
	MOUND_FLARE_M of skirt."""
	return _m(RoomsScript.void_half(kind) + Vector2i(RoomsScript.SKIRT_U, RoomsScript.SKIRT_U)) \
			+ Vector2(MOUND_FLARE_M, MOUND_FLARE_M)


static func face_m(kind: int) -> float:
	"""How far in front of a room's middle its wall -- the mound's earth face, where its door stands -- is (m)."""
	return _m(-RoomsScript.DOOR_LOCAL[kind]).y


func _mound_frame(r: int) -> Transform3D:
	"""Room `r`'s frame on the ground: at its middle, its door's way (-Z) toward its door."""
	var centre := _rooms.centre_m(r)
	var toward := _m(_rooms.door_u(r)) - centre
	return Transform3D(Basis.looking_at(Vector3(toward.x, 0.0, toward.y)), Vector3(centre.x, 0.0, centre.y))


static func _mound_mesh(kind: int) -> ArrayMesh:
	"""Template `kind`'s mound (room_mesh.gd `build_mound`), built once and shared."""
	var key := SHARED_MOUND + kind
	if not _shared.has(key):
		_shared[key] = RoomMeshScript.build_mound(mound_reach(kind), MOUND_TOP_M, face_m(kind), NOTCH_HALF_M[kind])
	return _shared[key]


static func _face_mesh(kind: int) -> ArrayMesh:
	"""Template `kind`'s earth face (room_mesh.gd `build_face`), built once and shared."""
	var key := SHARED_FACE + kind
	if not _shared.has(key):
		_shared[key] = RoomMeshScript.build_face(mound_reach(kind), MOUND_TOP_M, face_m(kind), NOTCH_HALF_M[kind])
	return _shared[key]


func _door(frame: Transform3D, r: int) -> Node3D:
	"""A home's round front door at the foot of its cutting, in its mound's face (`frame`: the room's, see `_mound_frame`),
	facing out, its leaf on a hinge `door_swing` swings (see ON THE GROUND)."""
	var door := Node3D.new()
	door.transform = frame * Transform3D(Basis.IDENTITY, Vector3(0.0, Layers.floor_y(_rooms.level[r]),
		-face_m(RoomsScript.TEMPLATE_HOME)))
	var hinge := _staged_door(door)
	if hinge == null:
		hinge = _stand_in_door(door)
	var at := (frame * Vector3(0.0, 0.0, -face_m(RoomsScript.TEMPLATE_HOME)))
	door_swing.set_door(r, Vector2(at.x, at.z), hinge)
	return door


func _staged_door(door: Node3D) -> Node3D:
	"""The library's burrow door under `door`, turned to face out (the model faces +Z): its frame, and its leaf hung from
	a hinge up through the leaf's left edge (seen from the cutting), opening inward. Returns the hinge (null: not staged
	in its two parts, so the stand-in is drawn)."""
	var frame := _props.part_instance(DOOR_KEY, DOOR_FRAME) if _props.has_parts(DOOR_KEY) else null
	var leaf := _props.part_instance(DOOR_KEY, DOOR_LEAF) if frame != null else null
	if leaf == null:
		if frame != null:
			frame.free()
		return null
	var turned := Node3D.new()
	turned.rotation.y = PI
	door.add_child(turned)
	turned.add_child(frame)
	var bound: AABB = leaf.transform * leaf.mesh.get_aabb()
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(bound.position.x, 0.0, bound.get_center().z)
	turned.add_child(hinge)
	leaf.transform = Transform3D(Basis.IDENTITY, -hinge.position) * leaf.transform
	hinge.add_child(leaf)
	return hinge


func _stand_in_door(door: Node3D) -> Node3D:
	"""The stand-in door under `door`: a wooden leaf with a brass knob on a hinge at its left edge (seen from the
	cutting), in a timber ring on a fieldstone sill, facing out. Returns the hinge."""
	var upright := Basis(Vector3.RIGHT, PI * 0.5)
	var middle := DOOR_RADIUS_M + 0.08
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(DOOR_RADIUS_M, 0.0, -0.03)
	hinge.rotation.y = 0.0
	door.add_child(hinge)
	hinge.add_child(_part(_door_mesh(SHARED_LEAF), DOOR_WOOD, Transform3D(upright, Vector3(-DOOR_RADIUS_M, middle, 0.0))))
	hinge.add_child(_part(_door_mesh(SHARED_KNOB), KNOB, Transform3D(Basis.IDENTITY, Vector3(-DOOR_RADIUS_M * 1.55, middle, -0.07))))
	door.add_child(_part(_door_mesh(SHARED_RING), TIMBER_RING, Transform3D(upright, Vector3(0.0, middle, -0.06))))
	door.add_child(_part(_door_mesh(SHARED_SILL), DOOR_STONE, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, -0.25))))
	return hinge


func swing_doors(delta_s: float) -> void:
	"""Every home's door toward open while a resident comes through it, else shut (door_swing.gd), by `delta_s` of
	demo time."""
	door_swing.step(_space.resident_position, _space.resident_underground, delta_s)


static func _door_mesh(key: int) -> Mesh:
	"""A door or hatch part's mesh (SHARED_LEAF and on), built once and shared."""
	if not _shared.has(key):
		_shared[key] = _make_door_mesh(key)
	return _shared[key]


static func _make_door_mesh(key: int) -> Mesh:
	"""Build door or hatch part `key` (see `_door_mesh`)."""
	match key:
		SHARED_LEAF:
			var leaf := CylinderMesh.new()
			leaf.top_radius = DOOR_RADIUS_M
			leaf.bottom_radius = DOOR_RADIUS_M
			leaf.height = 0.08
			return leaf
		SHARED_RING:
			var ring := TorusMesh.new()
			ring.inner_radius = DOOR_RADIUS_M - 0.02
			ring.outer_radius = DOOR_RADIUS_M + 0.16
			return ring
		SHARED_KNOB:
			var knob := SphereMesh.new()
			knob.radius = 0.04
			knob.height = 0.08
			knob.radial_segments = 12
			knob.rings = 6
			return knob
		SHARED_SILL:
			return _box(Vector3(1.5, 0.12, 0.5))
		SHARED_BOARD:
			return _box(Vector3(0.56, 0.06, HATCH_RUN_M))
		SHARED_RAIL:
			return _box(Vector3(0.1, 0.12, HATCH_RUN_M))
	return _box(Vector3(1.4, 0.1, 0.4))


func _part(mesh: Mesh, colour: Color, place: Transform3D) -> MeshInstance3D:
	"""One piece of a door: `mesh` in the lit rough `colour`, placed so."""
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _rough(colour)
	node.transform = place
	return node


static func _box(size: Vector3) -> BoxMesh:
	"""A box of `size` (m)."""
	var box := BoxMesh.new()
	box.size = size
	return box


func _hatch(frame: Transform3D) -> Node3D:
	"""A cellar's hatch against its mound's earth face (`frame`: the room's): two plank leaves sloping from the
	face down over the top of its steps, in a timber frame on a fieldstone sill -- a root cellar's bulkhead."""
	var hatch := Node3D.new()
	hatch.transform = frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -face_m(RoomsScript.TEMPLATE_CELLAR)))
	var slope := Basis(Vector3.RIGHT, -HATCH_SLOPE_RAD)
	var middle := Vector3(0.0, HATCH_RUN_M * 0.5 * sin(HATCH_SLOPE_RAD), -HATCH_RUN_M * 0.5 * cos(HATCH_SLOPE_RAD))
	for side: float in [-0.3, 0.3]:
		hatch.add_child(_part(_door_mesh(SHARED_BOARD), HATCH_WOOD, Transform3D(slope, middle + Vector3(side, 0.06, 0.0))))
	for side: float in [-0.64, 0.64]:
		hatch.add_child(_part(_door_mesh(SHARED_RAIL), TIMBER_RING, Transform3D(slope, middle + Vector3(side, 0.04, 0.0))))
	hatch.add_child(_part(_door_mesh(SHARED_HATCH_SILL), DOOR_STONE,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, -HATCH_RUN_M * cos(HATCH_SLOPE_RAD) - 0.1))))
	return hatch


func mound_circles(r: int) -> PackedVector3Array:
	"""Room `r`'s mound and door ramp as obstacle circles (x, radius, z) for the ground (cast_space.gd
	`set_mound`): the mound (a cellar's as two along its length) and one over the ramp's cutting, clear of where
	it comes up."""
	var kind := _rooms.template[r]
	var centre := _rooms.centre_m(r)
	var half := mound_half(kind, _rooms.turns[r])
	var out := PackedVector3Array()
	if RoomsScript.SHAPE[kind] == RoomsScript.SHAPE_ROUND:
		out.append(Vector3(centre.x, half.x, centre.y))
	else:
		var along := Vector2(1.0, 0.0) if half.x > half.y else Vector2(0.0, 1.0)
		var reach := absf(half.x - half.y)
		var radius := minf(half.x, half.y)
		for end: float in [-1.0, 1.0]:
			var at := centre + along * reach * end
			out.append(Vector3(at.x, radius, at.y))
	var door := _m(_rooms.door_u(r))
	var cutting := door + (_m(_rooms.mouth_u(r)) - door).normalized() * 2.0
	out.append(Vector3(cutting.x, 1.0, cutting.y))
	return out


# --- checks ---------------------------------------------------------------------------------

func shell(r: int) -> MeshInstance3D:
	"""Room `r`'s shell (for checks)."""
	return _shells[r]


func below(r: int) -> Node3D:
	"""Room `r`'s node below (for checks)."""
	return _below[r]


func above(r: int) -> Node3D:
	"""Room `r`'s mound, earth face and door or hatch above (for checks)."""
	return _above[r]


func furniture(r: int) -> Node3D:
	"""Room `r`'s fit-out (for checks)."""
	return _furniture[r]


func frames(r: int) -> MultiMeshInstance3D:
	"""Room `r`'s frames at its door and sockets (for checks)."""
	return _frames[r]


func beam(r: int) -> MeshInstance3D:
	"""Room `r`'s ring beam (for checks)."""
	return _beams[r]


func label(r: int) -> Label3D:
	"""Room `r`'s name on the surface (for checks)."""
	return _labels[r]


func label_below(r: int) -> Label3D:
	"""Room `r`'s name as the U view draws it (for checks)."""
	return _labels_below[r]


func outline_below(r: int) -> MeshInstance3D:
	"""Room `r`'s outline as the U view draws it (for checks)."""
	return _outlines_below[r]


func outline(r: int) -> MeshInstance3D:
	"""Room `r`'s outline on the ground, as the surface view draws it (for checks)."""
	return _outlines[r]
