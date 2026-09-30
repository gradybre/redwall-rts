extends Node3D
## What the demo's tunnels look like. Decision 0196. Presentation only.
##
## ON THE GROUND, per tunnel: its route as a ribbon -- solid earth where the bore is dug, a cream
## dashed line where it is still to dig (clay, with a clay ring round the entrance, while the tunnel
## is PAUSED), a faint earth trace once it is open -- the entrance and exit as MOUTHS (tunnel_mouth.gd,
## decision 0207: a fieldstone-and-timber gateway over the ramp's cutting running down into the dark),
## and a spoil heap beside each mouth that grows with the spoil heaped there (DEC-040;
## tunnel_rules.spoil_into). The ribbon stops at a hole's edge, and the cutting is drawn over it. While the digger is underground a mound of disturbed earth, throwing clods, moves along
## above it, drawn larger as the camera pulls back so it still reads when zoomed out. The route
## being laid (tunnel_plan.gd) is drawn the same way with a ring at each point and its length beside
## the pointer, on top of everything, so a route laid under a roof stays readable.
##
## UNDERGROUND (the U view, tunnel_view.gd; decisions 0206 and 0207): each tunnel's dug length is a
## SWEPT BORE on the UNDERGROUND layer (bore_view.gd: a hand-dug horseshoe tube in the underground's
## earth, stones and roots in its walls) with a face wall where the dig has reached -- wider once widened
## (and as far as a widening has reached, `widen_m`), wet when flooded, dark with rubble through a fallen
## section (tunnel_marks.gd draws the frames, lanterns and their light). It is built as the bore is dug,
## whatever the view, and each dug step is stamped into the cap's void mask (underground_cap.gd) so the
## cap opens over it. It replaced decision 0206's interim trough.
##
## THE ROUTE BEING LAID is drawn twice, a node per view (demo_layers.gd): on the ground, and on the
## level's floor in the U view -- where a click there lands.
##
## A MOUND also follows a mole at a digging job underground (widening, clearing, a chamber):
## `job_digger` names it per tunnel (tunnel_works.gd sets it every frame; -1 for none).
##
## BUILT ONCE, REBUILT RARELY. Every node is built once per slot. The ribbon and the bore are
## rebuilt only when the dig face crosses a BORE_STEP_M boundary (or the phase or the tunnel's state changes)
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
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

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
## A widened tunnel's mouths are drawn this much larger (a badger goes down them).
const WIDE_HOLE_SCALE: float = 1.6
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
const HEAP_RINGS: int = 7
const HEAP_SECTORS: int = 28
## A ribbon rebuild's key: phase, then the face's BORE_STEP_M steps and whether ground is broken.
const KEY_PHASE: int = 1000000

const EARTH: Color = Color(0.302, 0.224, 0.165)
const EARTH_LIGHT: Color = Color(0.43, 0.32, 0.22)
const PLAN: Color = Color(Palette.CREAM, 0.6)
const PAUSED_PLAN: Color = Color(Palette.CLAY, 0.8)
const PREVIEW: Color = Color(Palette.CREAM, 0.35)
const TRACE: Color = Color(EARTH, 0.4)
## A mesh key's tunnel-state part: bore, closed and the widening's step.
const KEY_STATE: int = 100000000
## A mouth's children: its cutting, then its gateway (tunnel_mouth.gd).
const MOUTH_CUTTING: int = 0
const MOUTH_GATEWAY: int = 1

var _network: NetworkScript = null
var _space: CastSpaceScript = null
var _clock: DemoClockScript = null
var _ribbons: Array[MeshInstance3D] = []
## The swept bores, their stones and roots (bore_view.gd).
var bores: BoreViewScript = null
var _holes: Array[Node3D] = []
var _heaps: Array[MeshInstance3D] = []
var _mounds: Array[Node3D] = []
var _pause_rings: Array[MeshInstance3D] = []
var _mesh_key: PackedInt64Array = PackedInt64Array()
var _mouth_key: PackedInt64Array = PackedInt64Array()
var _plan_ribbon: MeshInstance3D = null
var _plan_rings: Array[MeshInstance3D] = []
var _label: Label3D = null
## The route being laid as the U view draws it, on the level's floor (a node per view; decision 0206).
var _plan_below: Node3D = null
var _plan_ribbon_below: MeshInstance3D = null
var _plan_rings_below: Array[MeshInstance3D] = []
var _label_below: Label3D = null
var _materials: Dictionary = {}
var _poly: PackedVector2Array = PackedVector2Array()
var _verts: PackedVector3Array = PackedVector3Array()
var _vert_count: int = 0
var _spoil: PackedInt64Array = PackedInt64Array()
var _time: float = 0.0
## Per tunnel: how far a widening has reached (m), and the mole at a digging job there (-1: none).
var widen_m: PackedFloat32Array = PackedFloat32Array()
var job_digger: PackedInt32Array = PackedInt32Array()
## Bore rebuilds so far (for measurement and the tests).
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
	widen_m.resize(Rules.MAX_TUNNELS)
	job_digger.resize(Rules.MAX_TUNNELS)
	job_digger.fill(-1)
	_mouth_key.resize(Rules.MAX_TUNNELS)
	_mouth_key.fill(-1)
	bores = BoreViewScript.new()
	add_child(bores)
	bores.configure(network)
	for slot in Rules.MAX_TUNNELS:
		_build_slot()
	_build_plan_marks()
	_hide_all()


func _build_slot() -> void:
	"""One slot's nodes: ribbon, mound, pause ring, and a mouth and heap at each end (its bore is
	bore_view.gd's)."""
	_ribbons.append(_mesh_node(ImmediateMesh.new(), null))
	_mounds.append(_make_mound())
	var ring := MarksScript.make_ring(Palette.CLAY)
	ring.scale = Vector3(PAUSE_RING_M, 1.0, PAUSE_RING_M)
	add_child(ring)
	_pause_rings.append(ring)
	for end in 2:
		_holes.append(_make_mouth())
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


func _make_mouth() -> Node3D:
	"""A mouth (tunnel_mouth.gd): the ramp's cutting and the gateway over its top, on the surface,
	hidden. +Z runs down the ramp."""
	var mouth := Node3D.new()
	for mesh: Mesh in [MouthScript.cutting_mesh(), MouthScript.gateway_mesh()]:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		mouth.add_child(part)
	mouth.visible = false
	add_child(mouth)
	return mouth


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
	"""The route being laid, a set per view (see THE ROUTE BEING LAID): its ribbon, a ring per point and
	a length label, all drawn on top -- on the ground, and on the level's floor, sharing one ribbon mesh."""
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


static func _plan_ring(parent: Node3D, layer: int) -> MeshInstance3D:
	"""A ring for a laid point, drawn on top, on `layer`, under `parent`, hidden."""
	var ring := MarksScript.make_ring(Palette.CREAM)
	ring.scale = Vector3(RING_RADIUS_M, 1.0, RING_RADIUS_M)
	(ring.material_override as StandardMaterial3D).no_depth_test = true
	(ring.material_override as StandardMaterial3D).render_priority = 3
	ring.layers = layer
	parent.add_child(ring)
	return ring


static func _plan_label(parent: Node3D, layer: int) -> Label3D:
	"""The route's length label, drawn on top, on `layer`, under `parent`, hidden."""
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL
	label.font_size = LABEL_PX
	label.outline_size = 10
	label.modulate = Palette.CREAM
	label.outline_modulate = Palette.DEEP_SHADE
	label.layers = layer
	label.visible = false
	parent.add_child(label)
	return label


func _hide_all() -> void:
	"""Nothing is drawn until there is something to draw."""
	for slot in Rules.MAX_TUNNELS:
		_hide_slot(slot)


func _hide_slot(slot: int) -> void:
	"""Hide everything one slot draws."""
	_ribbons[slot].visible = false
	bores.hide_slot(slot)
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
	bores.tick()


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
	"""A tunnel's swept bore (its first chunk; bore_view.gd has them all)."""
	return bores.chunk(slot, 0)


func pause_ring(slot: int) -> MeshInstance3D:
	"""The clay ring round a paused tunnel's entrance."""
	return _pause_rings[slot]


func ribbon(slot: int) -> MeshInstance3D:
	"""A tunnel's ribbon on the ground."""
	return _ribbons[slot]


func mesh_key(slot: int) -> int:
	"""What a slot's ribbon and bore were last built for (see BUILT ONCE, REBUILT RARELY; -1: hidden).
	Nothing about the view: a view switch rebuilds nothing (decision 0206)."""
	var phase := _network.phase[slot]
	if phase == NetworkScript.PHASE_FREE:
		return -1
	var broken := 2 if _network.done(slot) > 0 else 0
	var base := int(phase) * KEY_PHASE + floori(dug_m(slot) / BORE_STEP_M) * 4 + broken
	return base + _state_key(slot) * KEY_STATE


func dug_m(slot: int) -> float:
	"""How much of tunnel `slot`'s bore is dug (all of it once open), m."""
	return _network.length_m(slot) if _network.is_open(slot) else _network.face_m(slot)


func _state_key(slot: int) -> int:
	"""What a tunnel's state adds to its mesh key: bore class, closed and the widening (lanterns and
	braces are tunnel_marks.gd's, and light the bore as it is)."""
	var bits := int(_network.bore[slot]) + 4 * int(_network.closed[slot])
	return bits + 32 * floori(widen_m[slot] / BORE_STEP_M)


func _sync_slot(slot: int) -> void:
	"""Rebuild one slot's ribbon and bore when its face crossed a step (or its phase or state
	changed); move its mouths and heaps when a tick was dug."""
	var key := mesh_key(slot)
	if key != _mesh_key[slot]:
		_mesh_key[slot] = key
		_mouth_key[slot] = -1
		if key < 0:
			_hide_slot(slot)
			return
		_draw_ribbon(slot)
		if _network.done(slot) > 0:
			bores.build(slot, dug_m(slot), widen_m[slot])
			bore_builds += 1
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
		var wide := 2.0 if _network.bore[slot] == Rules.BORE_WIDE else 1.0
		_strip_into(HOLE_RADIUS_M * wide, length - HOLE_RADIUS_M * wide, TRACE_WIDTH_M * wide, false)
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
	var shaft := clampf(float(_network.done(slot)) / float(Rules.SHAFT_QUANTA * Rules.TICKS_PER_QUANTUM), 0.3, 1.0)
	_holes[2 * slot].visible = _network.done(slot) > 0
	_place_mouth(slot, false, shaft if stage == Rules.STAGE_ENTRANCE else 1.0)
	_holes[2 * slot + 1].visible = stage == Rules.STAGE_OPEN
	_place_mouth(slot, true, 1.0)
	_network.spoil_into(slot, _spoil)
	for end in 2:
		_place_heap(slot, end, _spoil[end])
	var ring := _pause_rings[slot]
	ring.visible = _network.phase[slot] == NetworkScript.PHASE_PAUSED
	var at := _network.mouth(slot, false)
	ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)


func _place_mouth(slot: int, exit: bool, opened: float) -> void:
	"""A mouth on the ground, facing down its ramp: its cutting as long as the ramp is open (to where the
	bore goes under, on the first or last leg), `opened` of that while the shaft is dug, and its gateway
	once it is (see tunnel_mouth.gd); larger for a widened bore."""
	var node := _holes[2 * slot + (1 if exit else 0)]
	var at := _network.mouth(slot, exit)
	var into := -_network.direction_at(slot, _network.length_m(slot)) if exit else _network.direction_at(slot, 0.0)
	node.position = Vector3(at.x, 0.0, at.y)
	node.rotation = Vector3(0.0, atan2(into.x, into.y), 0.0)
	var wide := WIDE_HOLE_SCALE if _network.bore[slot] == Rules.BORE_WIDE else 1.0
	var leg := _network.point(slot, 1).distance_to(at) if not exit else _network.point(slot, _network.point_count[slot] - 2).distance_to(at)
	var open_m := minf(Rules.portal_m(int(_network.bore[slot])), leg) * opened
	(node.get_child(MOUTH_CUTTING) as Node3D).scale = Vector3(wide, 1.0, open_m)
	var gateway := node.get_child(MOUTH_GATEWAY) as Node3D
	gateway.visible = opened >= 1.0
	gateway.scale = Vector3.ONE * wide


func mouth_open_m(slot: int, exit: bool) -> float:
	"""How far a mouth's cutting runs down its ramp (m; checks)."""
	return (_holes[2 * slot + (1 if exit else 0)].get_child(MOUTH_CUTTING) as Node3D).scale.z


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
	var digger := _network.digger[slot] if _network.phase[slot] == NetworkScript.PHASE_DIGGING else job_digger[slot]
	var below := digger >= 0 and digger < _space.resident_underground.size() and _space.resident_underground[digger] == 1
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

func set_view(cap: CapScript, prewarm: PrewarmScript) -> void:
	"""The underground view's cap (whose void mask the dug bores open) and its prewarm registry, which
	learns everything this overlay draws in the U view (decision 0206)."""
	_mesh_key.fill(-1)
	bores.set_view(cap, prewarm)
	for colour: Color in [PLAN, PREVIEW]:
		prewarm.add_mesh(immediate_sample(), _on_top(colour))
	for ring: MeshInstance3D in _plan_rings_below:
		prewarm.add_mesh(ring.mesh, ring.material_override)
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
	_plan_ribbon_below.visible = true
	for k in _plan_rings.size():
		_show_plan_ring(_plan_rings[k], plan, k)
		_show_plan_ring(_plan_rings_below[k], plan, k)
	_show_plan_label(_label, plan, cursor, has_cursor)
	_show_plan_label(_label_below, plan, cursor, has_cursor)


static func _show_plan_ring(ring: MeshInstance3D, plan: PlanScript, k: int) -> void:
	"""The ring on laid point `k` (brass entrance, ember latest), or hidden past the last."""
	ring.visible = k < plan.count
	if not ring.visible:
		return
	var at := plan.point_m(k)
	ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)
	var colour := Palette.BRASS if k == 0 else (Palette.EMBER if k == plan.count - 1 else Palette.CREAM)
	MarksScript.set_alpha(ring, colour, 1.0)


static func _show_plan_label(label: Label3D, plan: PlanScript, cursor: Vector2, has_cursor: bool) -> void:
	"""The route's length (to the pointer, while it is over the plane) beside its end."""
	label.visible = plan.count > 0
	if not label.visible:
		return
	var at := cursor if has_cursor else plan.point_m(plan.count - 1)
	var length := plan.length_to_u(Rules.to_u(at.x), Rules.to_u(at.y)) if has_cursor else plan.length_u()
	label.text = PlanScript.length_text(length)
	label.position = Vector3(at.x, 0.6, at.y)


func plan_label() -> Label3D:
	"""The length label beside the route being laid."""
	return _label


func plan_ribbon() -> MeshInstance3D:
	"""The route being laid."""
	return _plan_ribbon


func plan_below() -> Node3D:
	"""The route being laid as the U view draws it, on the level's floor (its ribbon, rings and label)."""
	return _plan_below


func hide_plan() -> void:
	"""Stop drawing the route being laid, in both views."""
	_plan_ribbon.visible = false
	_plan_ribbon_below.visible = false
	_label.visible = false
	_label_below.visible = false
	for k in _plan_rings.size():
		_plan_rings[k].visible = false
		_plan_rings_below[k].visible = false
