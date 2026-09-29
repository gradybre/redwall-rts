extends Node3D
## What the demo's tunnels look like. Decision 0196. Presentation only.
##
## ON THE GROUND, per tunnel: its route as a ribbon -- solid earth where the bore is dug, a cream
## dashed line where it is still to dig (clay, with a clay ring round the entrance, while the tunnel
## is PAUSED), a faint earth trace once it is open -- the entrance and exit as dark holes in an
## earthen rim, and a spoil heap beside each mouth that grows with the spoil heaped there (DEC-040;
## tunnel_rules.spoil_into). The ribbon stops at a hole's edge, so no square of it shows in the
## hole. While the digger is underground a mound of disturbed earth, throwing clods, moves along
## above it, drawn larger as the camera pulls back so it still reads when zoomed out. The route
## being laid (tunnel_plan.gd) is drawn the same way with a ring at each point and its length beside
## the pointer, on top of everything, so a route laid under a roof stays readable.
##
## UNDERGROUND (U, tunnel_view.gd): each tunnel's dug length also shows as a lit trough at bore
## depth, the bore seen from above with its roof cut away.
##
## BUILT ONCE, REBUILT RARELY. Every node is built once per slot. The ribbon and the trough are
## rebuilt only when the dig face crosses a BORE_STEP_M boundary (or the phase or the view changes)
## -- at most a few times a second while digging, never every tick -- into scratch arrays that are
## grown, never shrunk, with no temporary per quad. Mouths and heaps only move and scale, per tick.
##
## HEAP SIZE is a DEMO value: ECON-002's mass is a haul cost, "not physical soil density", so how
## large a unit of spoil looks is not specified. A heap is drawn as a dome holding
## HEAP_DRAWN_M3_PER_U cubic metres per unit, HEAP_ASPECT times as tall as it is wide. It stands where
## tunnel_heaps.gd placed it when the dig was accepted (clear of obstacles, work spots and holes),
## or -- for a tunnel stored without that -- off to the right of the way out of its mouth.
##
## TIME. The mound's bob and its clods run on the demo clock (demo_clock.gd): paused, they hold.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

const LIFT_M: float = 0.045
const PLAN_WIDTH_M: float = 0.32
const DUG_WIDTH_M: float = 0.55
const TRACE_WIDTH_M: float = 0.4
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
const BORE_SIDES: int = 10
const LABEL_PX: int = 40
const LABEL_PIXEL: float = 0.0006
const HEAP_RINGS: int = 7
const HEAP_SECTORS: int = 28
## In the underground view, things on the surface -- mouths, heaps, the mound -- fade this far.
const SURFACE_FADE: float = 0.55
## A ribbon rebuild's key: phase, then the face's BORE_STEP_M steps, whether ground is broken, and
## the view.
const KEY_PHASE: int = 1000000

const EARTH: Color = Color(0.302, 0.224, 0.165)
const EARTH_LIGHT: Color = Color(0.43, 0.32, 0.22)
const HOLE: Color = Color(0.06, 0.05, 0.04)
const PLAN: Color = Color(Palette.CREAM, 0.6)
const PAUSED_PLAN: Color = Color(Palette.CLAY, 0.8)
const PREVIEW: Color = Color(Palette.CREAM, 0.35)
const TRACE: Color = Color(EARTH, 0.4)
const BORE_DEEP: Color = Color(0.36, 0.2, 0.09)
const BORE_RIM: Color = Palette.EMBER

var _network: NetworkScript = null
var _space: CastSpaceScript = null
var _clock: DemoClockScript = null
var _ribbons: Array[MeshInstance3D] = []
var _bores: Array[MeshInstance3D] = []
var _holes: Array[Node3D] = []
var _heaps: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _pause_rings: Array[MeshInstance3D] = []
var _mesh_key: PackedInt64Array = PackedInt64Array()
var _mouth_key: PackedInt64Array = PackedInt64Array()
var _plan_ribbon: MeshInstance3D = null
var _plan_rings: Array[MeshInstance3D] = []
var _label: Label3D = null
var _materials: Dictionary = {}
var _poly: PackedVector2Array = PackedVector2Array()
var _verts: PackedVector3Array = PackedVector3Array()
var _vert_count: int = 0
var _bore_verts: PackedVector3Array = PackedVector3Array()
var _bore_colours: PackedColorArray = PackedColorArray()
var _bore_indices: PackedInt32Array = PackedInt32Array()
var _bore_arrays: Array = []
var _spoil: PackedInt64Array = PackedInt64Array()
var _underground_view: bool = false
var _time: float = 0.0
## Trough rebuilds so far (for measurement and the tests).
var bore_builds: int = 0

static var _heap: ArrayMesh = null


func configure(network: NetworkScript, space: CastSpaceScript, clock: DemoClockScript = null) -> void:
	"""Draw this network's tunnels, finding each digger in `space`, on `clock`'s time (none: the
	mound holds still). Builds every node once."""
	name = "TunnelOverlay"
	_network = network
	_space = space
	_clock = clock
	_spoil.resize(2)
	_mesh_key.resize(Rules.MAX_TUNNELS)
	_mesh_key.fill(-1)
	_mouth_key.resize(Rules.MAX_TUNNELS)
	_mouth_key.fill(-1)
	_bore_arrays.resize(Mesh.ARRAY_MAX)
	for slot in Rules.MAX_TUNNELS:
		_build_slot()
	_build_plan_marks()
	_hide_all()


func _build_slot() -> void:
	"""One slot's nodes: ribbon, trough, mound, pause ring, and a hole and heap at each end."""
	_ribbons.append(_mesh_node(ImmediateMesh.new(), null))
	var trough := _unshaded(Color.WHITE, true)
	trough.vertex_color_is_srgb = true
	_bores.append(_mesh_node(ArrayMesh.new(), trough))
	_mounds.append(_make_mound())
	var ring := MarksScript.make_ring(Palette.CLAY)
	ring.scale = Vector3(PAUSE_RING_M, 1.0, PAUSE_RING_M)
	add_child(ring)
	_pause_rings.append(ring)
	for end in 2:
		_holes.append(_make_hole())
		_heaps.append(_mesh_node(heap_mesh(), _spoil_material()))


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


func _make_hole() -> Node3D:
	"""A mouth: a dark disc sunk in a low earthen rim."""
	var hole := Node3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = HOLE_RADIUS_M
	disc.bottom_radius = HOLE_RADIUS_M
	disc.height = 0.02
	var pit := MeshInstance3D.new()
	pit.mesh = disc
	pit.material_override = _earth_material(HOLE)
	pit.position.y = 0.012
	hole.add_child(pit)
	var torus := TorusMesh.new()
	torus.inner_radius = HOLE_RADIUS_M * 0.92
	torus.outer_radius = HOLE_RADIUS_M * Rules.RIM_FACTOR
	var rim := MeshInstance3D.new()
	rim.mesh = torus
	rim.material_override = _earth_material(EARTH)
	rim.scale = Vector3(1.0, 0.45, 1.0)
	hole.add_child(rim)
	hole.visible = false
	add_child(hole)
	return hole


func _make_mound() -> Node3D:
	"""The disturbed earth over a digger underground: a low dome throwing up clods."""
	var mound := Node3D.new()
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = heap_mesh()
	dome.material_override = _spoil_material()
	dome.scale = Vector3(MOUND_RADIUS_M, MOUND_HEIGHT_M, MOUND_RADIUS_M)
	mound.add_child(dome)
	var clods := CPUParticles3D.new()
	clods.amount = 14
	clods.lifetime = 0.7
	clods.mesh = BoxMesh.new()
	(clods.mesh as BoxMesh).size = Vector3(0.06, 0.05, 0.06)
	(clods.mesh as BoxMesh).material = _earth_material(EARTH)
	clods.direction = Vector3.UP
	clods.spread = 40.0
	clods.initial_velocity_min = 1.0
	clods.initial_velocity_max = 1.8
	clods.gravity = Vector3(0.0, -6.0, 0.0)
	clods.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	clods.emission_sphere_radius = MOUND_RADIUS_M * 0.5
	mound.add_child(clods)
	mound.visible = false
	add_child(mound)
	return mound


func _build_plan_marks() -> void:
	"""The route being laid: its ribbon, a ring per point and a length label, all drawn on top."""
	_plan_ribbon = _mesh_node(ImmediateMesh.new(), null)
	for k in Rules.MAX_POINTS:
		var ring := MarksScript.make_ring(Palette.CREAM)
		ring.scale = Vector3(RING_RADIUS_M, 1.0, RING_RADIUS_M)
		(ring.material_override as StandardMaterial3D).no_depth_test = true
		(ring.material_override as StandardMaterial3D).render_priority = 3
		add_child(ring)
		_plan_rings.append(ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = LABEL_PIXEL
	_label.font_size = LABEL_PX
	_label.outline_size = 10
	_label.modulate = Palette.CREAM
	_label.outline_modulate = Palette.DEEP_SHADE
	_label.visible = false
	add_child(_label)


func _hide_all() -> void:
	"""Nothing is drawn until there is something to draw."""
	for slot in Rules.MAX_TUNNELS:
		_hide_slot(slot)


func _hide_slot(slot: int) -> void:
	"""Hide everything one slot draws."""
	_ribbons[slot].visible = false
	_bores[slot].visible = false
	_mounds[slot].visible = false
	_pause_rings[slot].visible = false
	for end in 2:
		_holes[2 * slot + end].visible = false
		_heaps[2 * slot + end].visible = false


# --- per frame ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Redraw what changed, every frame, on the demo clock's time."""
	if _clock != null:
		_time += _clock.delta_s()
	refresh()


func refresh() -> void:
	"""Redraw each tunnel whose progress changed; move each mound with its digger."""
	if _network == null:
		return
	for slot in Rules.MAX_TUNNELS:
		_sync_slot(slot)
		_update_mound(slot)


func heap(slot: int, exit: bool) -> MeshInstance3D:
	"""The spoil heap by a tunnel's entrance (or exit)."""
	return _heaps[2 * slot + (1 if exit else 0)]


func hole(slot: int, exit: bool) -> Node3D:
	"""A tunnel's entrance (or exit) hole."""
	return _holes[2 * slot + (1 if exit else 0)]


func mound(slot: int) -> Node3D:
	"""The mound over a tunnel's digger."""
	return _mounds[slot]


func bore(slot: int) -> MeshInstance3D:
	"""A tunnel's underground trough."""
	return _bores[slot]


func pause_ring(slot: int) -> MeshInstance3D:
	"""The clay ring round a paused tunnel's entrance."""
	return _pause_rings[slot]


func ribbon(slot: int) -> MeshInstance3D:
	"""A tunnel's ribbon on the ground."""
	return _ribbons[slot]


func mesh_key(slot: int) -> int:
	"""What a slot's ribbon and trough were last built for (see BUILT ONCE, REBUILT RARELY; -1: hidden)."""
	var phase := _network.phase[slot]
	if phase == NetworkScript.PHASE_FREE:
		return -1
	var dug := _network.length_m(slot) if _network.is_open(slot) else _network.face_m(slot)
	var broken := 2 if _network.done(slot) > 0 else 0
	return int(phase) * KEY_PHASE + floori(dug / BORE_STEP_M) * 4 + broken + (1 if _underground_view else 0)


func _sync_slot(slot: int) -> void:
	"""Rebuild one slot's ribbon and trough when its face crossed a step (or its phase or the view
	changed); move its mouths and heaps when a tick was dug."""
	var key := mesh_key(slot)
	if key != _mesh_key[slot]:
		_mesh_key[slot] = key
		_mouth_key[slot] = -1
		if key < 0:
			_hide_slot(slot)
			return
		_draw_ribbon(slot)
		_bores[slot].visible = _underground_view
		if _underground_view:
			_build_bore(slot)
	var ticks := int(_network.phase[slot]) * KEY_PHASE + _network.done(slot)
	if key >= 0 and ticks != _mouth_key[slot]:
		_mouth_key[slot] = ticks
		_show_mouths(slot)


func _route_poly(slot: int) -> void:
	"""The slot's route points, in metres, into _poly."""
	_poly.resize(_network.point_count[slot])
	for k in _poly.size():
		_poly[k] = _network.point(slot, k)


func _draw_ribbon(slot: int) -> void:
	"""Dug length solid earth, the rest dashed (cream, or clay while paused); an open tunnel as a faint
	trace. Each part stops at the edge of an open hole."""
	_route_poly(slot)
	var mesh := _ribbons[slot].mesh as ImmediateMesh
	mesh.clear_surfaces()
	var length := _network.length_m(slot)
	if _network.is_open(slot):
		_strip_into(HOLE_RADIUS_M, length - HOLE_RADIUS_M, TRACE_WIDTH_M, false)
		_flush(mesh, _flat(TRACE))
	else:
		var dug := _network.face_m(slot)
		var from := HOLE_RADIUS_M if _network.done(slot) > 0 else 0.0
		_strip_into(from, dug, DUG_WIDTH_M, false)
		_flush(mesh, _flat(Color(EARTH, 0.85)))
		_strip_into(maxf(dug, from), length, PLAN_WIDTH_M, true)
		_flush(mesh, _flat(PAUSED_PLAN if _network.phase[slot] == NetworkScript.PHASE_PAUSED else PLAN))
	_ribbons[slot].visible = true


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

func _show_mouths(slot: int) -> void:
	"""The entrance opens as its shaft is dug, the exit when the tunnel opens; heaps beside them; a
	clay ring round a paused tunnel's entrance."""
	var stage := _network.stage(slot)
	var entrance := _holes[2 * slot]
	entrance.visible = _network.done(slot) > 0
	var shaft := clampf(float(_network.done(slot)) / float(Rules.SHAFT_QUANTA * Rules.TICKS_PER_QUANTUM), 0.3, 1.0)
	entrance.scale = Vector3.ONE * (shaft if stage == Rules.STAGE_ENTRANCE else 1.0)
	_put_on_ground(entrance, _network.mouth(slot, false))
	var exit := _holes[2 * slot + 1]
	exit.visible = stage == Rules.STAGE_OPEN
	_put_on_ground(exit, _network.mouth(slot, true))
	_network.spoil_into(slot, _spoil)
	for end in 2:
		_place_heap(slot, end, _spoil[end])
	var ring := _pause_rings[slot]
	ring.visible = _network.phase[slot] == NetworkScript.PHASE_PAUSED
	var at := _network.mouth(slot, false)
	ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)


static func _put_on_ground(node: Node3D, at: Vector2) -> void:
	"""Stand a node on the ground at (x, z)."""
	node.position = Vector3(at.x, 0.0, at.y)


static func heap_radius_m(spoil_milli_u: int) -> float:
	"""The drawn radius of a dome heap holding this much spoil (see HEAP SIZE); 0 for none."""
	var volume := float(spoil_milli_u) / 1000.0 * HEAP_DRAWN_M3_PER_U
	return pow(3.0 * volume / (2.0 * PI * HEAP_ASPECT), 1.0 / 3.0)


static func default_heap_at(mouth: Vector2, outward: Vector2, radius: float) -> Vector2:
	"""Where a heap of `radius` stands with no placement chosen: off to the right of the way out of
	its mouth, clear of the hole."""
	var right := Vector2(-outward.y, outward.x)
	return mouth + right * (HOLE_RADIUS_M * Rules.RIM_FACTOR + HEAP_GAP_M + radius) + outward * (radius * 0.25)


func _place_heap(slot: int, end: int, spoil_milli_u: int) -> void:
	"""A mouth's heap at its current size, where tunnel_heaps.gd placed it (see HEAP SIZE)."""
	var heap_node := _heaps[2 * slot + end]
	heap_node.visible = spoil_milli_u > 0
	if not heap_node.visible:
		return
	var r := heap_radius_m(spoil_milli_u)
	var at := _network.heap_at[2 * slot + end]
	if _network.heap_radius_m[2 * slot + end] <= 0.0:
		var outward := -_network.direction_at(slot, 0.0) if end == 0 else _network.direction_at(slot, _network.length_m(slot))
		at = default_heap_at(_network.mouth(slot, end == 1), outward, r)
	heap_node.position = Vector3(at.x, 0.0, at.y)
	heap_node.scale = Vector3(r, r * HEAP_ASPECT, r)


func _update_mound(slot: int) -> void:
	"""Over a digger underground, a mound follows it, bobbing and throwing clods on the demo clock,
	and grows as the camera pulls back."""
	var mound_node := _mounds[slot]
	var digger := _network.digger[slot]
	var below := _network.phase[slot] == NetworkScript.PHASE_DIGGING and digger >= 0 \
			and digger < _space.resident_underground.size() and _space.resident_underground[digger] == 1
	if mound_node.visible != below:
		mound_node.visible = below
		(mound_node.get_child(1) as CPUParticles3D).emitting = below
	if not below:
		return
	var at := _space.resident_position[digger]
	mound_node.position = Vector3(at.x, 0.0, at.y)
	mound_node.scale = Vector3.ONE * mound_scale(_camera_distance(mound_node.position))
	var bob := 1.0 + 0.25 * sin(TAU * MOUND_BOB_HZ * _time)
	(mound_node.get_child(0) as Node3D).scale.y = MOUND_HEIGHT_M * bob
	(mound_node.get_child(1) as CPUParticles3D).speed_scale = float(_clock.speed) if _clock != null else 1.0


static func mound_scale(camera_distance: float) -> float:
	"""How much larger the mound is drawn at this camera distance (see the header)."""
	return clampf(camera_distance / MOUND_NEAR_M, 1.0, MOUND_MAX_SCALE)


func _camera_distance(at: Vector3) -> float:
	"""The current camera's distance to `at` (0 with no camera: the mound's own size)."""
	if not is_inside_tree() or get_viewport().get_camera_3d() == null:
		return 0.0
	return get_viewport().get_camera_3d().global_position.distance_to(at)


# --- underground ----------------------------------------------------------------------------

func set_underground_view(on: bool) -> void:
	"""Show (or hide) each tunnel's dug trough at bore depth, and fade what lies on the surface."""
	_underground_view = on
	_mesh_key.fill(-1)
	var fade := SURFACE_FADE if on else 0.0
	for heap_node in _heaps:
		heap_node.transparency = fade
	for node in _holes + _mounds:
		for geometry in node.find_children("*", "GeometryInstance3D", true, false):
			(geometry as GeometryInstance3D).transparency = fade


func _build_bore(slot: int) -> void:
	"""The dug length of a tunnel as an open trough on the bore floor: a half-round channel, deep and
	dark at the bottom, glowing ember at its cut rims (never above the ground). Written into the
	slot's own mesh from scratch arrays sized to fit, with no temporaries."""
	var dug := _network.length_m(slot) if _network.is_open(slot) else _network.face_m(slot)
	var steps := maxi(1, ceili(dug / BORE_STEP_M))
	_bore_verts.resize((steps + 1) * (BORE_SIDES + 1))
	_bore_colours.resize(_bore_verts.size())
	for i in steps + 1:
		_bore_ring(slot, dug * float(i) / float(steps), i * (BORE_SIDES + 1))
	_bore_indices.resize(steps * BORE_SIDES * 6)
	var n := 0
	for i in steps:
		for j in BORE_SIDES:
			var a := i * (BORE_SIDES + 1) + j
			var b := a + BORE_SIDES + 1
			_quad_indices(n, a, b)
			n += 6
	_bore_arrays[Mesh.ARRAY_VERTEX] = _bore_verts
	_bore_arrays[Mesh.ARRAY_COLOR] = _bore_colours
	_bore_arrays[Mesh.ARRAY_INDEX] = _bore_indices
	var mesh := _bores[slot].mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _bore_arrays)
	bore_builds += 1


func _quad_indices(n: int, a: int, b: int) -> void:
	"""The trough quad between ring vertices a, a + 1 (this ring) and b, b + 1 (the next), at n."""
	_bore_indices[n] = a
	_bore_indices[n + 1] = b
	_bore_indices[n + 2] = a + 1
	_bore_indices[n + 3] = a + 1
	_bore_indices[n + 4] = b
	_bore_indices[n + 5] = b + 1


func _bore_ring(slot: int, along: float, first: int) -> void:
	"""One cross-section of the trough, from vertex `first`: the lower half-circle of the bore, rim to
	rim."""
	var radius := Rules.to_m(Rules.BORE_WIDTH_U) * 0.5
	var centre := _network.point_at(slot, along)
	var ahead := _network.direction_at(slot, along)
	var side := Vector2(-ahead.y, ahead.x)
	var floor_y := _network.floor_y_at(slot, along)
	for j in BORE_SIDES + 1:
		var angle := PI + PI * float(j) / float(BORE_SIDES)
		var across := centre + side * (cos(angle) * radius)
		_bore_verts[first + j] = Vector3(across.x, minf(floor_y + radius + sin(angle) * radius, -0.02), across.y)
		_bore_colours[first + j] = BORE_DEEP.lerp(BORE_RIM, absf(cos(angle)))


# --- the route being laid -------------------------------------------------------------------

func show_plan(plan: PlanScript, cursor: Vector2, has_cursor: bool) -> void:
	"""Draw the route being laid, on top of everything: rings at its points (brass entrance, ember
	latest), the laid route, a dashed preview to the pointer and the length there."""
	_poly.resize(plan.count)
	for k in plan.count:
		_poly[k] = plan.point_m(k)
	var mesh := _plan_ribbon.mesh as ImmediateMesh
	mesh.clear_surfaces()
	_strip_into(0.0, INF, PLAN_WIDTH_M, false)
	_flush(mesh, _on_top(PLAN))
	if has_cursor and plan.count > 0:
		_poly.resize(2)
		_poly[0] = plan.point_m(plan.count - 1)
		_poly[1] = cursor
		_strip_into(0.0, INF, PLAN_WIDTH_M, true)
		_flush(mesh, _on_top(PREVIEW))
	_plan_ribbon.visible = true
	_show_plan_rings(plan)
	_show_plan_label(plan, cursor, has_cursor)


func _show_plan_rings(plan: PlanScript) -> void:
	"""A ring on each laid point."""
	for k in _plan_rings.size():
		var ring := _plan_rings[k]
		ring.visible = k < plan.count
		if not ring.visible:
			continue
		var at := plan.point_m(k)
		ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)
		var colour := Palette.BRASS if k == 0 else (Palette.EMBER if k == plan.count - 1 else Palette.CREAM)
		MarksScript.set_alpha(ring, colour, 1.0)


func _show_plan_label(plan: PlanScript, cursor: Vector2, has_cursor: bool) -> void:
	"""The route's length (to the pointer, while it is over the ground) beside its end."""
	_label.visible = plan.count > 0
	if not _label.visible:
		return
	var at := cursor if has_cursor else plan.point_m(plan.count - 1)
	var length := plan.length_to_u(Rules.to_u(at.x), Rules.to_u(at.y)) if has_cursor else plan.length_u()
	_label.text = PlanScript.length_text(length)
	_label.position = Vector3(at.x, 0.6, at.y)


func plan_label() -> Label3D:
	"""The length label beside the route being laid."""
	return _label


func plan_ribbon() -> MeshInstance3D:
	"""The route being laid."""
	return _plan_ribbon


func hide_plan() -> void:
	"""Stop drawing the route being laid."""
	_plan_ribbon.visible = false
	_label.visible = false
	for ring in _plan_rings:
		ring.visible = false
