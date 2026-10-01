extends Node3D
## What the demo's tunnels look like. Decisions 0196 and 0208 (the network graph). Presentation only.
##
## ON THE GROUND, per SEGMENT of the network: its route as a ribbon -- solid earth where the bore is dug,
## a cream dashed line where it is still to dig (clay, with a clay ring round where it starts, while it is
## PAUSED); once it is open, nothing here -- its turf seam heals over it (warren_signs.gd, decision 0211). Per MOUTH: its
## ramp's OPEN CUTTING down to where the bore goes under, the ground cut away over it (world/ground_cut.gd), and the tunnel
## ARCH framing the bore there with its lantern (tunnel_mouth.gd, decisions 0207 and 0371) -- or, at a burrow home's door
## (decision 0209), the cutting down to its door, which room_view.gd stands -- and a spoil heap beside it that
## grows with the spoil tipped there (DEC-040; underground_graph.gd SPOIL: a dig crew's baskets tip it load by load,
## spoil_haul.gd, decision 0211). A ribbon stops at a hole's
## edge, and the cutting is drawn over it. While a digger is underground a mound of disturbed earth,
## throwing clods, moves along above it, drawn larger as the camera pulls back so it still reads when
## zoomed out. THE GHOST of the piece being laid (tunnel_plan.gd) is drawn on top of everything: its drawn
## curve (bore_curve.gd's fillets) with a ring at each point, dashed on to the pointer, chalk-cream while it
## may be dug and clay when not, a brass ring where it snaps onto the network, and beside the pointer the
## cost readout or the reason it may not be dug (tunnel_control.gd SNAPPING AND THE GHOST).
##
## UNDERGROUND (the U view, tunnel_view.gd; decisions 0206 to 0208): each segment's dug length is a SWEPT
## BORE on the UNDERGROUND layer (bore_view.gd: a hand-dug horseshoe tube in the underground's earth,
## stones and roots in its walls) with a face wall where the dig has reached -- wider once widened (and as
## far as a widening has reached, `widen_m`), wet when flooded, dark with rubble through a fallen section
## (tunnel_marks.gd draws the frames, lanterns and their light) -- and each junction where three or more
## have broken through a HUB (bore_view.gd HUBS). It is built as the bore is dug, whatever the view, and
## each dug step is stamped into the cap's void mask (underground_cap.gd) so the cap opens over it.
##
## THE ROUTE BEING LAID is drawn twice, a node per view (demo_layers.gd): on the ground, and on the
## level's floor in the U view -- where a click there lands.
##
## A MOUND also follows a mole at a digging job underground (widening, clearing; a room's dig is a piece's):
## `job_digger` names it per tunnel (tunnel_works.gd sets it every frame; -1 for none).
##
## BUILT WHEN FIRST NEEDED, REBUILT RARELY. A segment's nodes are built the first time its slot holds a
## segment (when a piece is laid -- never on a view switch), a mouth's at boot. The ribbon and the bore are
## rebuilt only when the dig face crosses a BORE_STEP_M boundary (or the phase or the segment's state
## changes) -- at most a few times a second while digging, never every tick -- into scratch arrays that are
## grown, never shrunk, with no temporary per quad. Mouths and heaps only move and scale, per tick.
##
## HEAP SIZE is a DEMO value: ECON-002's mass is a haul cost, "not physical soil density", so how
## large a unit of spoil looks is not specified. A heap is drawn as a dome holding
## HEAP_DRAWN_M3_PER_U cubic metres per unit, HEAP_ASPECT times as tall as it is wide. It stands where
## tunnel_heaps.gd placed it when the dig was accepted (clear of obstacles, work spots and holes),
## or -- for a mouth stored without that -- off to the right of the way out of it.
##
## TIME. The mound's bob runs on the demo clock (demo_clock.gd): paused, it holds. Its clods are the warren's pooled
## particles (warren_particles.gd, decision 0211), thrown over it by dig_theatre.gd.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const GroundCutScript := preload("res://demo/world/ground_cut.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

const LIFT_M: float = 0.045
const PLAN_WIDTH_M: float = 0.32
const DUG_WIDTH_M: float = 0.55
const DASH_M: float = 0.55
const GAP_M: float = 0.3
const HOLE_RADIUS_M: float = Rules.HOLE_RADIUS_M
const HEAP_DRAWN_M3_PER_U: float = 0.06
const HEAP_ASPECT: float = 0.5
const HEAP_GAP_M: float = 0.12
const MOUND_RADIUS_M: float = 0.45
const MOUND_HEIGHT_M: float = 0.2
const MOUND_BOB_HZ: float = 1.6
## The mound is drawn at its size up to this camera distance, and scaled with it beyond, to at most
## MOUND_MAX_SCALE.
const MOUND_NEAR_M: float = 22.0
const MOUND_MAX_SCALE: float = 2.5
const RING_RADIUS_M: float = 0.45
const PAUSE_RING_M: float = 0.8
const BORE_STEP_M: float = 0.25
const LABEL_PX: int = 40
const LABEL_PIXEL: float = 0.0006
## The ghost's words start this far right of the pointer (px), so a long readout runs off no edge of it.
const LABEL_OFFSET_PX: Vector2 = Vector2(60.0, 0.0)
const HEAP_RINGS: int = 7
const HEAP_SECTORS: int = 28
## A ribbon rebuild's key: phase, then the face's BORE_STEP_M steps and whether ground is broken.
const KEY_PHASE: int = 1000000

const EARTH: Color = Color(0.302, 0.224, 0.165)
const EARTH_LIGHT: Color = Color(0.43, 0.32, 0.22)
const PLAN: Color = Color(Palette.CREAM, 0.6)
const PAUSED_PLAN: Color = Color(Palette.CLAY, 0.8)
const PREVIEW: Color = Color(Palette.CREAM, 0.35)
const REFUSED_GHOST: Color = Color(Palette.CLAY, 0.75)
const SNAP_RING_M: float = 0.7
## The ghost's drawn curve is sampled this often (m).
const GHOST_STEP_M: float = 0.25
## A mesh key's tunnel-state part: bore, closed and the widening's step.
const KEY_STATE: int = 100000000
## A mouth's children: its cutting, its arch (or gateway), the arch's lantern and its glow (tunnel_mouth.gd).
const MOUTH_CUTTING: int = 0
const MOUTH_GATEWAY: int = 1
const MOUTH_LANTERN: int = 2
const MOUTH_GLOW: int = 3

var _network: GraphScript = null
var _space: CastSpaceScript = null
var _clock: DemoClockScript = null
## Per segment (built when first needed; see BUILT WHEN FIRST NEEDED): ribbon, mound, pause ring.
var _ribbons: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _pause_rings: Array[MeshInstance3D] = []
## The swept bores, their stones and roots, and the junctions' hubs (bore_view.gd).
var bores: BoreViewScript = null
## Per mouth row: its gateway and cutting, and its heap.
var _holes: Array[Node3D] = []
var _heaps: Array[MeshInstance3D] = []
var _mesh_key: PackedInt64Array = PackedInt64Array()
var _mouth_key: PackedInt64Array = PackedInt64Array()
## Per mouth row: how far its cutting is open down its ramp (m; 0 while it shows none).
var _open_m: PackedFloat32Array = PackedFloat32Array()
## Per mouth row: how wide either side its cutting's forecourt opens before the arch (m; 0: none).
var _court_m: PackedFloat32Array = PackedFloat32Array()
## The demo's props (the arch and its lantern; null or unstaged: the procedural gateway), and the cut in the ground over
## the cuttings (null: no ground to cut, a test's).
var _props: PropsScript = null
var ground_cut: GroundCutScript = null
var _plan_ribbon: MeshInstance3D = null
var _plan_rings: Array[MeshInstance3D] = []
var _label: Label3D = null
var _snap_ring: MeshInstance3D = null
## The piece being laid as the U view draws it, on the level's floor (a node per view; decision 0206).
var _plan_below: Node3D = null
var _plan_ribbon_below: MeshInstance3D = null
var _plan_rings_below: Array[MeshInstance3D] = []
var _label_below: Label3D = null
var _snap_ring_below: MeshInstance3D = null
var _ghost_curve: BoreCurveScript = BoreCurveScript.new()
var _ghost_points: PackedVector2Array = PackedVector2Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _materials: Dictionary = {}
var _poly: PackedVector2Array = PackedVector2Array()
var _verts: PackedVector3Array = PackedVector3Array()
var _vert_count: int = 0
var _time: float = 0.0
## Per segment: how far a widening has reached (m), and the digger at a digging job there (-1: none).
var widen_m: PackedFloat32Array = PackedFloat32Array()
var job_digger: PackedInt32Array = PackedInt32Array()
## Bore rebuilds so far (for measurement and the tests).
var bore_builds: int = 0

static var _heap: ArrayMesh = null


func configure(network: GraphScript, space: CastSpaceScript, clock: DemoClockScript = null) -> void:
	"""Draw this network, finding each digger in `space`, on `clock`'s time (none: the mound holds still).
	Builds every mouth's nodes and the ghost's once; a segment's when it is first laid."""
	name = "TunnelOverlay"
	_network = network
	_space = space
	_clock = clock
	_mesh_key.resize(Rules.MAX_SEGMENTS)
	_mesh_key.fill(-1)
	widen_m.resize(Rules.MAX_SEGMENTS)
	job_digger.resize(Rules.MAX_SEGMENTS)
	job_digger.fill(-1)
	_mouth_key.resize(Rules.MAX_MOUTHS)
	_mouth_key.fill(-1)
	_open_m.resize(Rules.MAX_MOUTHS)
	_court_m.resize(Rules.MAX_MOUTHS)
	_ribbons.resize(Rules.MAX_SEGMENTS)
	_mounds.resize(Rules.MAX_SEGMENTS)
	_pause_rings.resize(Rules.MAX_SEGMENTS)
	bores = BoreViewScript.new()
	add_child(bores)
	bores.configure(network)
	for m in Rules.MAX_MOUTHS:
		_holes.append(_make_mouth())
		_heaps.append(_mesh_node(heap_mesh(), _spoil_material()))
	_build_plan_marks()


func _ensure_segment(slot: int) -> void:
	"""Build segment `slot`'s nodes the first time it is laid: ribbon, mound and pause ring, hidden."""
	if _ribbons[slot] != null:
		return
	_ribbons[slot] = _mesh_node(ImmediateMesh.new(), null)
	_mounds[slot] = _make_mound()
	var ring := MarksScript.make_ring(Palette.CLAY)
	ring.scale = Vector3(PAUSE_RING_M, 1.0, PAUSE_RING_M)
	ring.visible = false
	add_child(ring)
	_pause_rings[slot] = ring


func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	"""A shadowless mesh node under this overlay, hidden until drawn."""
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


func _unshaded(colour: Color, vertex_colours: bool) -> StandardMaterial3D:
	"""A flat, see-through, double-sided material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = colour
	material.vertex_color_use_as_albedo = vertex_colours
	return material


func _flat(colour: Color) -> StandardMaterial3D:
	"""The shared unshaded material for a ground-overlay colour."""
	if not _materials.has(colour):
		_materials[colour] = _unshaded(colour, false)
		(_materials[colour] as StandardMaterial3D).render_priority = 1
	return _materials[colour]


func _on_top(colour: Color) -> StandardMaterial3D:
	"""The shared material for the route being laid: drawn over everything, roofs included."""
	var key := Color(colour.r, colour.g, colour.b, -colour.a)
	if not _materials.has(key):
		var material := _unshaded(colour, false)
		material.no_depth_test = true
		material.render_priority = 2
		_materials[key] = material
	return _materials[key]


func _earth_material(colour: Color) -> StandardMaterial3D:
	"""Lit, rough earth."""
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


func _spoil_material() -> StandardMaterial3D:
	"""Loose earth: a grainy blend of the two earth tones, projected from above so any heap takes it."""
	if _materials.has(&"spoil"):
		return _materials[&"spoil"]
	var noise := FastNoiseLite.new()
	noise.seed = 196
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, EARTH.darkened(0.25))
	ramp.set_color(1, EARTH_LIGHT)
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	var material := _earth_material(Color.WHITE)
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 1.6
	_materials[&"spoil"] = material
	return material


static func heap_mesh() -> ArrayMesh:
	"""A unit spoil heap (radius 1, height 1): a rounded cone whose rim and flanks are lumpy, so a
	pile of loose earth reads as one from above. Built once and shared."""
	if _heap != null:
		return _heap
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.add_vertex(Vector3(0.0, 1.0, 0.0))
	for ring in range(1, HEAP_RINGS + 1):
		var t := float(ring) / float(HEAP_RINGS)
		for k in HEAP_SECTORS:
			var angle := TAU * float(k) / float(HEAP_SECTORS)
			var lump := 1.0 + 0.13 * sin(3.0 * angle + 1.3) + 0.07 * sin(7.0 * angle + 0.4 + 2.0 * t)
			var height := (1.0 - pow(t, 1.6)) * (1.0 + 0.12 * sin(5.0 * angle + 3.0 * t))
			tool.add_vertex(Vector3(cos(angle) * t * lump, maxf(height, 0.0), sin(angle) * t * lump))
	_heap_indices(tool)
	tool.generate_normals()
	_heap = tool.commit()
	return _heap


static func _heap_indices(tool: SurfaceTool) -> void:
	"""Triangles of the heap: a fan round the peak, then quads ring to ring, wound clockwise seen from
	above -- Godot's front face -- so the heap faces up and out."""
	for k in HEAP_SECTORS:
		var next := (k + 1) % HEAP_SECTORS
		tool.add_index(0)
		tool.add_index(1 + k)
		tool.add_index(1 + next)
	for ring in range(1, HEAP_RINGS):
		var inner := 1 + (ring - 1) * HEAP_SECTORS
		var outer := inner + HEAP_SECTORS
		for k in HEAP_SECTORS:
			var next := (k + 1) % HEAP_SECTORS
			for i in [inner + k, outer + k, outer + next, inner + k, outer + next, inner + next]:
				tool.add_index(i)


func _make_mouth() -> Node3D:
	"""A mouth (tunnel_mouth.gd): its cutting, its arch or gateway, the arch's lantern and glow, on the surface, hidden.
	+Z runs down the ramp."""
	var mouth := Node3D.new()
	for k in 4:
		var part := MeshInstance3D.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k == MOUTH_GATEWAY \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mouth.add_child(part)
	mouth.visible = false
	add_child(mouth)
	return mouth


func set_props(props: PropsScript) -> void:
	"""The demo's props: the staged arch and its lantern stand at the mouths (none staged: the procedural gateway)."""
	_props = props
	_mouth_key.fill(-1)


func set_ground(ground: MeshInstance3D) -> void:
	"""The village ground to cut open over the cuttings (world/ground_cut.gd)."""
	if ground_cut == null:
		ground_cut = GroundCutScript.new()
	ground_cut.set_ground(ground)
	_mouth_key.fill(-1)


func _make_mound() -> Node3D:
	"""The disturbed earth over a digger underground: a low dome (its clods are the warren's pooled particles,
	warren_particles.gd, thrown over it by dig_theatre.gd)."""
	var mound_root := Node3D.new()
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = heap_mesh()
	dome.material_override = _spoil_material()
	dome.scale = Vector3(MOUND_RADIUS_M, MOUND_HEIGHT_M, MOUND_RADIUS_M)
	mound_root.add_child(dome)
	mound_root.visible = false
	add_child(mound_root)
	return mound_root


func set_plan_level(level: int) -> void:
	"""The ghost's U-view set on `level`'s floor and marks layer (decision 0212: the Dig tool lays on the level the U
	view shows)."""
	_plan_below.position.y = Layers.floor_y(level)
	for node: VisualInstance3D in [_plan_ribbon_below, _label_below, _snap_ring_below]:
		node.layers = Layers.marks(level)
	for ring: MeshInstance3D in _plan_rings_below:
		ring.layers = Layers.marks(level)


func _build_plan_marks() -> void:
	"""The ghost, a set per view (see THE GHOST): its ribbon, a ring per point, the snap ring and the words,
	all drawn on top -- on the ground, and on the level's floor, sharing one ribbon mesh."""
	_plan_ribbon = _mesh_node(ImmediateMesh.new(), null)
	_plan_ribbon.layers = Layers.SURFACE_MARKS
	_label = _plan_label(self, Layers.SURFACE_MARKS)
	_plan_below = Node3D.new()
	_plan_below.name = "PlanBelow"
	_plan_below.position.y = Layers.FLOOR_Y_M
	add_child(_plan_below)
	_plan_ribbon_below = MeshInstance3D.new()
	_plan_ribbon_below.mesh = _plan_ribbon.mesh
	_plan_ribbon_below.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plan_ribbon_below.layers = Layers.UNDERGROUND_MARKS
	_plan_ribbon_below.visible = false
	_plan_below.add_child(_plan_ribbon_below)
	_label_below = _plan_label(_plan_below, Layers.UNDERGROUND_MARKS)
	for k in Rules.MAX_POINTS:
		_plan_rings.append(_plan_ring(self, Layers.SURFACE_MARKS))
		_plan_rings_below.append(_plan_ring(_plan_below, Layers.UNDERGROUND_MARKS))
	_snap_ring = _plan_ring(self, Layers.SURFACE_MARKS)
	_snap_ring_below = _plan_ring(_plan_below, Layers.UNDERGROUND_MARKS)
	for ring: MeshInstance3D in [_snap_ring, _snap_ring_below]:
		ring.scale = Vector3(SNAP_RING_M, 1.0, SNAP_RING_M)


static func _plan_ring(parent: Node3D, layer: int) -> MeshInstance3D:
	"""A ring for a laid point, drawn on top, on `layer`, under `parent`, hidden."""
	var ring := MarksScript.make_ring(Palette.CREAM)
	ring.scale = Vector3(RING_RADIUS_M, 1.0, RING_RADIUS_M)
	(ring.material_override as StandardMaterial3D).no_depth_test = true
	(ring.material_override as StandardMaterial3D).render_priority = 3
	ring.layers = layer
	ring.visible = false
	parent.add_child(ring)
	return ring


static func _plan_label(parent: Node3D, layer: int) -> Label3D:
	"""The ghost's words, drawn on top, on `layer`, under `parent`, hidden."""
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL
	label.font_size = LABEL_PX
	label.outline_size = 10
	label.modulate = Palette.CREAM
	label.outline_modulate = Palette.DEEP_SHADE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.offset = LABEL_OFFSET_PX
	label.layers = layer
	label.visible = false
	parent.add_child(label)
	return label


func _hide_slot(slot: int) -> void:
	"""Hide everything one segment draws."""
	if _ribbons[slot] == null:
		return
	_ribbons[slot].visible = false
	bores.hide_slot(slot)
	_mounds[slot].visible = false
	_pause_rings[slot].visible = false


# --- per frame ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Redraw what changed, every frame, on the demo clock's time."""
	if _clock != null:
		_time += _clock.delta_s()
	refresh()
	bores.tick()


func refresh() -> void:
	"""Redraw each segment whose progress changed and move each mound with its digger; show each mouth as its
	hole opens and its heap grows; redraw the hubs when the network changed."""
	if _network == null:
		return
	for slot in Rules.MAX_SEGMENTS:
		if _network.phase[slot] == GraphScript.PHASE_FREE and _ribbons[slot] == null:
			continue
		_sync_slot(slot)
		_update_mound(slot)
	for m in Rules.MAX_MOUTHS:
		_sync_mouth(m)
	if ground_cut != null:
		ground_cut.apply()
	bores.refresh_hubs()


func heap(m: int) -> MeshInstance3D:
	"""The spoil heap by mouth row `m`."""
	return _heaps[m]


func hole(m: int) -> Node3D:
	"""Mouth row `m`'s gateway and cutting."""
	return _holes[m]


func mound(slot: int) -> Node3D:
	"""The mound over segment `slot`'s digger (null until the segment is first laid)."""
	return _mounds[slot]


func bore(slot: int) -> MeshInstance3D:
	"""A segment's swept bore (its first chunk; bore_view.gd has them all)."""
	return bores.chunk(slot, 0)


func pause_ring(slot: int) -> MeshInstance3D:
	"""The clay ring round where a paused segment starts."""
	return _pause_rings[slot]


func ribbon(slot: int) -> MeshInstance3D:
	"""A segment's ribbon on the ground."""
	return _ribbons[slot]


func mesh_key(slot: int) -> int:
	"""What a segment's ribbon and bore were last built for (see BUILT WHEN FIRST NEEDED; -1: hidden -- a room's
	own segments too: room_view.gd draws the room). Nothing about the view: a view switch rebuilds nothing
	(decision 0206)."""
	var phase := _network.phase[slot]
	if phase == GraphScript.PHASE_FREE or _network.seg_kind[slot] == GraphScript.SEG_ROOM:
		return -1
	var broken := 2 if _network.done(slot) > 0 else 0
	var base := int(phase) * KEY_PHASE + floori(dug_m(slot) / BORE_STEP_M) * 4 + broken
	return base + _state_key(slot) * KEY_STATE


func dug_m(slot: int) -> float:
	"""How much of segment `slot`'s bore is dug (all of it once open), m."""
	return _network.length_m(slot) if _network.is_open(slot) else _network.face_m(slot)


func _state_key(slot: int) -> int:
	"""What a segment's state adds to its mesh key: bore class, closed, the widening, its generation, its
	route's length (a split changes both ends' routes) and whether a hub stands at either end (a branch
	breaking ground at a junction makes one, and the bores meeting there must drop what lies inside it) and whether it
	ends blind (bore_view.gd `hub_bits`);
	lanterns and braces are tunnel_marks.gd's."""
	var bits := int(_network.bore[slot]) + 4 * int(_network.closed[slot])
	return bits + 32 * floori(widen_m[slot] / BORE_STEP_M) + 32768 * (_network.generation[slot] % 256) \
			+ 8388608 * (_network.length_u[slot] % 64) + 536870912 * bores.hub_bits(slot)


func _sync_slot(slot: int) -> void:
	"""Rebuild one segment's ribbon and bore when its face crossed a step (or its phase or state changed)."""
	var key := mesh_key(slot)
	if key == _mesh_key[slot]:
		return
	_mesh_key[slot] = key
	if key < 0:
		_hide_slot(slot)
		return
	_ensure_segment(slot)
	_draw_ribbon(slot)
	_show_pause_ring(slot)
	if _network.done(slot) > 0:
		bores.build(slot, dug_m(slot), widen_m[slot])
		bore_builds += 1


func _route_poly(slot: int) -> void:
	"""The segment's route points, in metres, into _poly."""
	_poly.resize(_network.point_count[slot])
	for k in _poly.size():
		_poly[k] = _network.point(slot, k)


func _draw_ribbon(slot: int) -> void:
	"""Dug length solid earth, the rest dashed (cream, or clay while paused); an open segment none (its seam is
	warren_signs.gd's). Each part stops at the edge of an open hole (only a mouth has one)."""
	var mesh := _ribbons[slot].mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _network.is_open(slot):
		_ribbons[slot].visible = false
		return
	_route_poly(slot)
	var start_hole := HOLE_RADIUS_M if _network.mouth_of_end(slot, false) >= 0 else 0.0
	var dug := _network.face_m(slot)
	var from := start_hole if _network.done(slot) > 0 else 0.0
	_strip_into(from, dug, DUG_WIDTH_M, false)
	_flush(mesh, _flat(Color(EARTH, 0.85)))
	_strip_into(maxf(dug, from), _network.length_m(slot), PLAN_WIDTH_M, true)
	_flush(mesh, _flat(PAUSED_PLAN if _network.phase[slot] == GraphScript.PHASE_PAUSED else PLAN))
	_ribbons[slot].visible = true


func _show_pause_ring(slot: int) -> void:
	"""A clay ring round where a paused segment starts."""
	var ring := _pause_rings[slot]
	ring.visible = _network.phase[slot] == GraphScript.PHASE_PAUSED
	var at := _network.end_at(slot, false)
	ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)


func _strip_into(from_m: float, to_m: float, width: float, dashed: bool) -> void:
	"""Append quads covering distances from_m..to_m along _poly (dashed on a fixed rhythm)."""
	var walked := 0.0
	for k in range(1, _poly.size()):
		var a := _poly[k - 1]
		var b := _poly[k]
		var seg := a.distance_to(b)
		var lo := maxf(from_m - walked, 0.0)
		var hi := minf(to_m - walked, seg)
		if hi > lo and seg > 1e-5:
			if dashed:
				_add_dashes(a, b, seg, lo, hi, walked, width)
			else:
				_add_quad(a.lerp(b, lo / seg), a.lerp(b, hi / seg), width)
		walked += seg


func _add_dashes(a: Vector2, b: Vector2, seg: float, lo: float, hi: float, walked: float, width: float) -> void:
	"""Dashes along a-b between lo and hi, in step with the dash rhythm of the whole route."""
	var period := DASH_M + GAP_M
	var s := lo
	while s < hi:
		var phase := fposmod(walked + s, period)
		var run := DASH_M - phase if phase < DASH_M else period - phase
		var end := minf(hi, s + maxf(run, 1e-3))
		if phase < DASH_M:
			_add_quad(a.lerp(b, s / seg), a.lerp(b, end / seg), width)
		s = end


func _add_quad(a: Vector2, b: Vector2, width: float) -> void:
	"""One flat quad from a to b, `width` wide, just above the ground: two triangles written straight
	into the scratch vertices."""
	var along := (b - a).normalized()
	var sx := -along.y * width * 0.5
	var sz := along.x * width * 0.5
	var a0 := Vector3(a.x - sx, LIFT_M, a.y - sz)
	var a1 := Vector3(a.x + sx, LIFT_M, a.y + sz)
	var b1 := Vector3(b.x + sx, LIFT_M, b.y + sz)
	var b0 := Vector3(b.x - sx, LIFT_M, b.y - sz)
	_put(a0)
	_put(a1)
	_put(b1)
	_put(a0)
	_put(b1)
	_put(b0)


func _put(v: Vector3) -> void:
	"""Append one vertex to the scratch array, growing it (never shrinking) when full."""
	if _vert_count == _verts.size():
		_verts.resize(maxi(96, _verts.size() * 2))
	_verts[_vert_count] = v
	_vert_count += 1


func _flush(mesh: ImmediateMesh, material: Material) -> void:
	"""Write the scratch vertices as one surface of `mesh` (none when empty) and empty them."""
	if _vert_count == 0:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	mesh.surface_set_normal(Vector3.UP)
	for i in _vert_count:
		mesh.surface_add_vertex(_verts[i])
	mesh.surface_end()
	_vert_count = 0


# --- mouths, heaps and mound ----------------------------------------------------------------

func _sync_mouth(m: int) -> void:
	"""Show mouth row `m` as it stands: its hole open (as its entry shaft is dug, or once its ramp breaks out
	at it), its cutting and arch, and its heap at its size; hidden when the row is free."""
	if not _network.is_mouth(m):
		if _mouth_key[m] != -1:
			_mouth_key[m] = -1
			_holes[m].visible = false
			_heaps[m].visible = false
			_open_m[m] = 0.0
			_cut_hole(m, false)
		return
	var ramp := _network.mouth_ramp(m)
	var tipped := _network.haul.on_heap_milli(_network, m)
	var key := int(_network.phase[ramp]) * KEY_PHASE + _network.done(ramp) + 7 * tipped \
			+ 13 * _network.mouth_gen[m] + 101 * int(_network.bore[ramp]) + 3 * (1 if door_built(m) else 0)
	if key == _mouth_key[m]:
		return
	_mouth_key[m] = key
	_show_mouth(m, ramp)
	_place_heap(m, tipped)


func _show_mouth(m: int, ramp: int) -> void:
	"""A mouth on the ground, facing down its ramp (see the header): its cutting as long as the ramp is open to where
	the bore goes under, `opened` of that while its entry shaft is dug, ending at the earth face there; dug, at the
	portal, under its arch -- or, a burrow home's door, all the way down to the door. A cellar's hatch covers its ramp
	(room_view.gd): nothing is drawn or cut. The ground is cut open over the cutting."""
	var node := _holes[m]
	var bore_kind := int(_network.bore[ramp])
	var home_door := MouthScript.door_template(_network, m) == RoomsScript.TEMPLATE_HOME
	var run := MouthScript.cutting_run_m(_network, m)
	node.visible = _network.mouth_opened(m) and run > 0.0
	var opened := 1.0
	if not _network.mouth_end_at_b(ramp) and _network.stage(ramp) == Rules.STAGE_ENTRANCE:
		opened = MouthScript.opened_share(clampf(float(_network.done(ramp)) / float(Rules.SHAFT_QUANTA * Rules.TICKS_PER_QUANTUM),
			0.3, 1.0))
	var at := _network.mouth_at(m)
	var into := _network.mouth_inward(m)
	node.position = Vector3(at.x, 0.0, at.y)
	node.rotation = Vector3(0.0, atan2(into.x, into.y), 0.0)
	_open_m[m] = run * opened if node.visible else 0.0
	var end := MouthScript.END_DOOR if home_door else (MouthScript.END_THROAT if opened >= 1.0 else MouthScript.END_FACE)
	_court_m[m] = MouthScript.court_half_m(_props, bore_kind) if end == MouthScript.END_THROAT else 0.0
	(node.get_child(MOUTH_CUTTING) as MeshInstance3D).mesh = MouthScript.cutting_mesh(bore_kind, run * opened, end, _court_m[m])
	_stand_gateway(node, bore_kind, _open_m[m], opened >= 1.0 and not home_door)
	_cut_hole(m, node.visible)


func _stand_gateway(node: Node3D, bore_kind: int, portal: float, standing: bool) -> void:
	"""Mouth `node`'s arch -- the staged one with its lantern and glow, else the procedural gateway -- at the portal,
	`standing` once its cutting is open there."""
	var gateway := node.get_child(MOUTH_GATEWAY) as MeshInstance3D
	var lantern := node.get_child(MOUTH_LANTERN) as MeshInstance3D
	var glow := node.get_child(MOUTH_GLOW) as MeshInstance3D
	var staged := _props != null and _props.is_staged(MouthScript.ARCH_KEY)
	gateway.visible = standing
	lantern.visible = standing and staged
	glow.visible = standing and staged
	if not standing:
		return
	if not staged:
		gateway.mesh = MouthScript.gateway_mesh()
		gateway.transform = MouthScript.gateway_at(bore_kind, portal)
		return
	gateway.mesh = _props.fitted(MouthScript.ARCH_KEY)
	gateway.transform = MouthScript.arch_at(_props, bore_kind, portal)
	lantern.mesh = _props.fitted(MouthScript.LANTERN_KEY)
	lantern.transform = MouthScript.lantern_on_arch(_props, bore_kind, portal)
	glow.mesh = MouthScript.glow_mesh()
	glow.position = MouthScript.glow_at(_props, bore_kind, portal)


func _cut_hole(m: int, open: bool) -> void:
	"""Mouth `m`'s holes in the ground over its cutting and its forecourt (world/ground_cut.gd: holes 2m and 2m + 1),
	or none."""
	if ground_cut == null:
		return
	if not open:
		ground_cut.set_hole(2 * m, PackedVector2Array())
		ground_cut.set_hole(2 * m + 1, PackedVector2Array())
		return
	var ramp := _network.mouth_ramp(m)
	var at := _network.mouth_at(m)
	var into := _network.mouth_inward(m)
	ground_cut.set_hole(2 * m, MouthScript.footprint(at, into, int(_network.bore[ramp]), _open_m[m]))
	ground_cut.set_hole(2 * m + 1, MouthScript.court_footprint(at, into, _court_m[m], _open_m[m]) if _court_m[m] > 0.0
		else PackedVector2Array())


func door_built(m: int) -> bool:
	"""Whether mouth row `m` is a room's door or hatch whose room is dug: room_view.gd draws its door (or hatch)
	there, not a tunnel's gateway (decision 0209). While the room is dug its ramp opens as a tunnel's does."""
	var r: int = _network.node_room[_network.mouth_node[m]]
	return _network.mouth_kind[m] != GraphScript.MOUTH_TUNNEL and r >= 0 and _network.rooms.is_done(_network, r)


func mouth_open_m(m: int) -> float:
	"""How far mouth row `m`'s cutting runs down its ramp (m; checks)."""
	return _open_m[m]


static func heap_radius_m(spoil_milli_u: int) -> float:
	"""The drawn radius of a dome heap holding this much spoil (see HEAP SIZE); 0 for none."""
	var volume := float(spoil_milli_u) / 1000.0 * HEAP_DRAWN_M3_PER_U
	return pow(3.0 * volume / (2.0 * PI * HEAP_ASPECT), 1.0 / 3.0)


static func default_heap_at(mouth: Vector2, outward: Vector2, radius: float) -> Vector2:
	"""Where a heap of `radius` stands with no placement chosen: off to the right of the way out of
	its mouth, clear of the hole."""
	var right := Vector2(-outward.y, outward.x)
	return mouth + right * (HOLE_RADIUS_M * Rules.RIM_FACTOR + HEAP_GAP_M + radius) + outward * (radius * 0.25)


func _place_heap(m: int, spoil_milli_u: int) -> void:
	"""Mouth `m`'s heap at its current size, where tunnel_heaps.gd placed it (see HEAP SIZE)."""
	var heap_node := _heaps[m]
	heap_node.visible = spoil_milli_u > 0
	if not heap_node.visible:
		return
	var r := heap_radius_m(spoil_milli_u)
	var at := _network.heap_at[m]
	if _network.heap_radius_m[m] <= 0.0:
		at = default_heap_at(_network.mouth_at(m), -_network.mouth_inward(m), r)
	heap_node.position = Vector3(at.x, 0.0, at.y)
	heap_node.scale = Vector3(r, r * HEAP_ASPECT, r)


func _update_mound(slot: int) -> void:
	"""Over a digger underground on level 1, a mound follows it, bobbing on the demo clock (its clods: dig_theatre.gd),
	and grows as the camera pulls back (a digger on level 2 or on a link down to it is too deep to heave the turf:
	decision 0212, the surface's signs are the top level's)."""
	var mound_node := _mounds[slot]
	if mound_node == null:
		return
	var digger := _network.digger[slot] if _network.phase[slot] == GraphScript.PHASE_DIGGING else job_digger[slot]
	var below := digger >= 0 and digger < _space.resident_underground.size() and _space.resident_underground[digger] == 1 \
			and _network.seg_level[slot] == Rules.TOP_LEVEL and _network.seg_kind[slot] != GraphScript.SEG_LINK
	mound_node.visible = below
	if not below:
		return
	var at := _space.resident_position[digger]
	mound_node.position = Vector3(at.x, 0.0, at.y)
	mound_node.scale = Vector3.ONE * mound_scale(_camera_distance(mound_node.position))
	var bob := 1.0 + 0.25 * sin(TAU * MOUND_BOB_HZ * _time)
	(mound_node.get_child(0) as Node3D).scale.y = MOUND_HEIGHT_M * bob


static func mound_scale(camera_distance: float) -> float:
	"""How much larger the mound is drawn at this camera distance (see the header)."""
	return clampf(camera_distance / MOUND_NEAR_M, 1.0, MOUND_MAX_SCALE)


func _camera_distance(at: Vector3) -> float:
	"""The current camera's distance to `at` (0 with no camera: the mound's own size)."""
	if not is_inside_tree() or get_viewport().get_camera_3d() == null:
		return 0.0
	return get_viewport().get_camera_3d().global_position.distance_to(at)


# --- underground ----------------------------------------------------------------------------

func set_view(cap: CapScript, prewarm: PrewarmScript, deep_cap: CapScript = null) -> void:
	"""The underground view's caps (whose void masks the dug bores open: level 1's, and level 2's when given) and its
	prewarm registry, which learns everything this overlay draws in the U view (decisions 0206, 0212)."""
	_mesh_key.fill(-1)
	bores.set_view(cap, prewarm, deep_cap)
	for colour: Color in [PLAN, PREVIEW, REFUSED_GHOST]:
		prewarm.add_mesh(immediate_sample(), _on_top(colour))
	for ring: MeshInstance3D in _plan_rings_below:
		prewarm.add_mesh(ring.mesh, ring.material_override)
	prewarm.add_mesh(_snap_ring_below.mesh, _snap_ring_below.material_override)
	prewarm.add_label(_label_below)


func set_calendar(calendar: CalendarScript) -> void:
	"""The demo calendar the bores' dig days and drying are read from (bore_view.gd)."""
	bores.set_calendar(calendar)


static func immediate_sample() -> ImmediateMesh:
	"""One upward triangle in the plan ribbon's vertex format (position and normal)."""
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_set_normal(Vector3.UP)
	for v: Vector3 in [Vector3.ZERO, Vector3(0.1, 0.0, 0.0), Vector3(0.0, 0.0, 0.1)]:
		mesh.surface_add_vertex(v)
	mesh.surface_end()
	return mesh


# --- the ghost ------------------------------------------------------------------------------

func show_ghost(plan: PlanScript, cursor: Vector2, has_cursor: bool, snap: int, refused: bool, words: String) -> void:
	"""Draw the ghost of the piece being laid, on top of everything (see THE GHOST): its drawn curve through
	its points and on to the pointer (dashed from the last point), chalk-cream -- clay when `refused` -- rings
	at its points (brass start, ember latest), a brass ring where the pointer snaps onto the network (`snap`,
	piece_spec.gd END_*), and `words` beside the pointer (else the piece's length)."""
	var mesh := _plan_ribbon.mesh as ImmediateMesh
	mesh.clear_surfaces()
	_ghost_route(plan, cursor, false)
	_strip_into(0.0, INF, PLAN_WIDTH_M, false)
	_flush(mesh, _on_top(REFUSED_GHOST if refused and not has_cursor else PLAN))
	if has_cursor and plan.count > 0:
		_ghost_route(plan, cursor, true)
		var laid := _laid_length(plan)
		_strip_into(laid, INF, PLAN_WIDTH_M, true)
		_flush(mesh, _on_top(REFUSED_GHOST if refused else PREVIEW))
	_plan_ribbon.visible = true
	_plan_ribbon_below.visible = true
	for k in _plan_rings.size():
		_show_plan_ring(_plan_rings[k], plan, k)
		_show_plan_ring(_plan_rings_below[k], plan, k)
	_show_snap_ring(_snap_ring, has_cursor and snap != SpecScript.END_NEW_MOUTH, cursor)
	_show_snap_ring(_snap_ring_below, has_cursor and snap != SpecScript.END_NEW_MOUTH, cursor)
	_show_plan_label(_label, plan, cursor, has_cursor, words, refused)
	_show_plan_label(_label_below, plan, cursor, has_cursor, words, refused)


static func _show_snap_ring(ring: MeshInstance3D, shown: bool, cursor: Vector2) -> void:
	"""The brass ring round a snap target (one view's), at the pointer."""
	ring.visible = shown
	ring.position = Vector3(cursor.x, MarksScript.LIFT_M, cursor.y)
	MarksScript.set_alpha(ring, Palette.BRASS, 1.0)


func _ghost_route(plan: PlanScript, cursor: Vector2, with_cursor: bool) -> void:
	"""The ghost's drawn curve (bore_curve.gd's fillets, as the bore will be drawn) through the points laid --
	and on to the pointer -- sampled every GHOST_STEP_M into _poly."""
	_ghost_points.resize(plan.count)
	for k in plan.count:
		_ghost_points[k] = plan.point_m(k)
	if with_cursor:
		_ghost_points.append(cursor)
	_poly.clear()
	if _ghost_points.size() < 2:
		_poly.append_array(_ghost_points)
		return
	_ghost_curve.set_route(_ghost_points, BoreCurveScript.bend_radius(Rules.BORE_STANDARD))
	var length := _ghost_curve.length_m()
	var along := 0.0
	while true:
		_ghost_curve.sample(minf(along, length), _sample)
		_poly.append(_sample[0])
		if along >= length:
			return
		along += GHOST_STEP_M


static func _laid_length(plan: PlanScript) -> float:
	"""How long the points laid run (m, along their legs)."""
	return Rules.to_m(plan.length_u())


static func _show_plan_ring(ring: MeshInstance3D, plan: PlanScript, k: int) -> void:
	"""The ring on laid point `k` (brass start, ember latest), or hidden past the last."""
	ring.visible = k < plan.count
	if not ring.visible:
		return
	var at := plan.point_m(k)
	ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)
	var colour := Palette.BRASS if k == 0 else (Palette.EMBER if k == plan.count - 1 else Palette.CREAM)
	MarksScript.set_alpha(ring, colour, 1.0)


static func _show_plan_label(label: Label3D, plan: PlanScript, cursor: Vector2, has_cursor: bool, words: String,
		refused: bool) -> void:
	"""The ghost's words beside the pointer (clay when refused): the readout or the reason, else the length."""
	label.visible = plan.count > 0
	if not label.visible:
		return
	var at := cursor if has_cursor else plan.point_m(plan.count - 1)
	var length := plan.length_to_u(Rules.to_u(at.x), Rules.to_u(at.y)) if has_cursor else plan.length_u()
	label.text = words if not words.is_empty() else PlanScript.length_text(length)
	label.modulate = Palette.CLAY if refused else Palette.CREAM
	label.position = Vector3(at.x, 0.6, at.y)


func plan_label() -> Label3D:
	"""The words beside the ghost."""
	return _label


func plan_ribbon() -> MeshInstance3D:
	"""The ghost's ribbon."""
	return _plan_ribbon


func plan_below() -> Node3D:
	"""The ghost as the U view draws it, on the level's floor (its ribbon, rings, snap ring and words)."""
	return _plan_below


func snap_ring() -> MeshInstance3D:
	"""The brass ring where the pointer snaps onto the network."""
	return _snap_ring


func hide_plan() -> void:
	"""Stop drawing the ghost, in both views."""
	_plan_ribbon.visible = false
	_plan_ribbon_below.visible = false
	_label.visible = false
	_label_below.visible = false
	_snap_ring.visible = false
	_snap_ring_below.visible = false
	for k in _plan_rings.size():
		_plan_rings[k].visible = false
		_plan_rings_below[k].visible = false
