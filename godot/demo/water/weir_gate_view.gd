extends Node3D
## The weir's sluice gate and the garden leat's head, drawn from the sluice setting. Decision 0441 (review ECO-006).
## Presentation only; floats. It reads the leat (farm_leat.gd `flow_permille`) and writes nothing back.
##
## THE GATE. The library weir's gate bay (between the two posts under the wheel; weir_fit.gd keeps that middle part
## as made) carries its own baked board. `open_bay` takes that board's faces out of the fitted weir's mesh -- faces
## whose centre lies in BAY_MIN..BAY_MAX, model units -- and `build` hangs a timber board of our own in its place, a
## child of the weir so it shares its fitted scale. The board rises by LIFT_MODEL at Open (half of it at Half),
## winding at LIFT_RATE on the demo clock (it freezes while paused, runs 2x / 4x with the game). Unstaged, the
## placeholder wall has no bay: the board hangs in front of it and still rises.
## THE GUSH. Under a raised board the pool runs through the bay: a patch of broken white water on the tail water below
## the bay, drifting downstream, its strength the board's lift.
## THE LEAT HEAD. The leat runs in a covered culvert from the weir to the garden (not drawn); where it comes up, at
## the north-east corner of Bed 2, a small stone head basin holds its water, drawn with the stream's own water
## material: empty at Closed, half full at Half, brim full at Open. Its footprint is one land obstacle
## (`land_obstacles`), as waterplay's are.
## THE ONE-LEVEL LIMIT. The stream itself has one level (decision 0301: the demo has one level per body), so the
## sluice does not lower the weir pool or raise the tail water; the gate, its gush and the leat head say it instead.

const WaterDressing := preload("res://demo/water/water_dressing.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const LeatScript := preload("res://demo/farm/farm_leat.gd")
const WorldLook := preload("res://demo/world/world_look.gd")

const WEIR_ID: StringName = &"weir"
## The gate bay's baked board, model units (see THE GATE): faces centred in this box are taken out.
const BAY_MIN: Vector3 = Vector3(0.3, 0.25, -0.13)
const BAY_MAX: Vector3 = Vector3(0.44, 0.86, 0.12)
## Our board, model units: across the bay, from near the bed to just under the crossbeam, a little downstream of the
## wall's face; and how far it rises fully open.
const GATE_MIN: Vector3 = Vector3(0.288, 0.3, 0.098)
const GATE_MAX: Vector3 = Vector3(0.452, 0.82, 0.128)
const LIFT_MODEL: float = 0.3
## The board is three planks, model units apart, each a little different in shade.
const PLANKS: int = 3
const PLANK_GAP: float = 0.004
const PLANK_SHADES: PackedFloat32Array = [0.92, 1.0, 0.86]
## Model units a second of demo time the board winds (a full lift in about two seconds at 1x).
const LIFT_RATE: float = 0.22
## The gush, model units: a patch on the tail water from the bay's foot downstream, widening as it goes.
const GUSH_FROM_Z: float = 0.12
const GUSH_OUT_Z: float = 0.78
const GUSH_HALF_X: float = 0.08
## The tail water's level, world metres (water_layout.gd LEVEL_DROP_U: 0.18 m under the ground datum).
const WATER_Y: float = -0.18
## A click whose ray meets the weir's box picks it: the fitted footprint grown by this (m), from the water to the
## crest's height (m).
const PICK_MARGIN_M: float = 0.15
const PICK_BOTTOM_M: float = -0.25
const PICK_TOP_M: float = 0.75

## The leat head basin (see THE LEAT HEAD), world metres: its centre, its inside half-size (x, z), its kerb's width
## and height over the ground, and the water's floor and brim over the ground.
const HEAD_AT: Vector2 = Vector2(-7.45, 7.3)
const HEAD_HALF: Vector2 = Vector2(0.36, 0.24)
const HEAD_KERB: float = 0.1
const HEAD_TOP: float = 0.3
const HEAD_FLOOR: float = 0.06
const HEAD_BRIM: float = 0.26
## The head's obstacle radius (m): its outside half-diagonal.
const HEAD_RADIUS: float = 0.55
## The head's timber sides: courses of planks, the joint between courses (m).
const KERB_COURSES: int = 2
const PLANK_JOINT_M: float = 0.012
const MUD: Color = Color(0.2, 0.16, 0.12)
const GUSH_COLOUR: Color = Color(0.95, 0.97, 0.98, 0.0)
const GUSH_ALPHA: float = 0.95
## The head's water as the water shader reads it: deep enough to take the deep colour (water.gdshader COLOR.r).
const HEAD_WATER_DEPTH: float = 0.22

var lift: float = 0.0

var _leat: LeatScript = null
var _clock: DemoClockScript = null
var _gate: MeshInstance3D = null
var _gush: MeshInstance3D = null
var _gush_material: StandardMaterial3D = null
var _head_water: MeshInstance3D = null
var _gush_scroll: float = 0.0
## Whether the gate has been drawn at least once (a still, closed gate is not redrawn each frame).
var _drawn: bool = false


# --- placement and picking ---------------------------------------------------------------------------

static func weir_placement() -> Dictionary:
	"""The weir's normalised dressing placement (water_dressing.gd)."""
	return Layout.find_placement(WaterDressing.placements(), WEIR_ID)


static func ray_hits_weir(origin: Vector3, direction: Vector3) -> bool:
	"""Whether a pick ray meets the weir's box: the fitted footprint (water_dressing.gd `weir_rect`, in the weir's own
	frame) grown by PICK_MARGIN_M, from PICK_BOTTOM_M to PICK_TOP_M -- the ray turned into that frame."""
	var p: Dictionary = weir_placement()
	var rect: Rect2 = WaterDressing.weir_rect(p).grow(PICK_MARGIN_M)
	var at: Vector2 = p["at"]
	var turn := Basis(Vector3.UP, -float(p["yaw"]))
	var local_origin: Vector3 = turn * (origin - Vector3(at.x, 0.0, at.y))
	var box := AABB(Vector3(rect.position.x, PICK_BOTTOM_M, rect.position.y),
		Vector3(rect.size.x, PICK_TOP_M - PICK_BOTTOM_M, rect.size.y))
	return box.intersects_ray(local_origin, turn * direction) != null


static func land_obstacles() -> Array[Vector3]:
	"""The leat head's footprint as a walking obstacle (x, z, radius), for the cast."""
	return [Vector3(HEAD_AT.x, HEAD_AT.y, HEAD_RADIUS)]


static func target_lift(flow_permille: int) -> float:
	"""How far the board stands raised for a flow (model units): LIFT_MODEL at full flow."""
	return LIFT_MODEL * float(clampi(flow_permille, 0, 1000)) / 1000.0


# --- building ----------------------------------------------------------------------------------------

func build(weir: MeshInstance3D, water_material: Material, leat: LeatScript, clock: DemoClockScript) -> void:
	"""Open the weir's bay, hang the board and the gush on it, and lay the leat head; follow `leat` on `clock`."""
	name = "WeirGateView"
	_leat = leat
	_clock = clock
	if weir != null:
		if weir.mesh is ArrayMesh:
			weir.mesh = open_bay(weir.mesh as ArrayMesh)
		_gate = _board()
		weir.add_child(_gate)
		var drawn: float = weir.transform.basis.get_scale().y
		_gush = _gush_sheet((WATER_Y - weir.position.y) / maxf(drawn, 0.001))
		weir.add_child(_gush)
	_build_head(water_material)
	snap()


static func open_bay(mesh: ArrayMesh) -> ArrayMesh:
	"""`mesh` with its first surface's faces in the gate bay taken out (see THE GATE); every other surface as it was.
	A mesh with nothing in the bay comes back unchanged."""
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = index.size() if not index.is_empty() else vertices.size()
	var kept := PackedInt32Array()
	for k: int in range(0, count - 2, 3):
		var a: int = index[k] if not index.is_empty() else k
		var b: int = index[k + 1] if not index.is_empty() else k + 1
		var c: int = index[k + 2] if not index.is_empty() else k + 2
		if not in_bay((vertices[a] + vertices[b] + vertices[c]) / 3.0):
			kept.append_array([a, b, c])
	if kept.size() == count:
		return mesh
	arrays[Mesh.ARRAY_INDEX] = kept
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mesh.surface_get_material(0))
	for surface: int in range(1, mesh.get_surface_count()):
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), mesh.surface_get_arrays(surface))
		out.surface_set_material(surface, mesh.surface_get_material(surface))
	return out


static func in_bay(centre: Vector3) -> bool:
	"""Whether a face centred at `centre` (model units) is the bay's baked board."""
	return centre.x > BAY_MIN.x and centre.x < BAY_MAX.x and centre.y > BAY_MIN.y and centre.y < BAY_MAX.y \
		and centre.z > BAY_MIN.z and centre.z < BAY_MAX.z


static func _board() -> MeshInstance3D:
	"""The gate board: PLANKS upright timber planks across the bay, in the world's timber, each its own shade, as one
	mesh (its vertex colours shade the planks)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var width: float = (GATE_MAX.x - GATE_MIN.x - PLANK_GAP * float(PLANKS - 1)) / float(PLANKS)
	var centre: Vector3 = (GATE_MIN + GATE_MAX) * 0.5
	for k: int in PLANKS:
		var x0: float = GATE_MIN.x + float(k) * (width + PLANK_GAP) - centre.x
		var lo := Vector3(x0, GATE_MIN.y - centre.y, GATE_MIN.z - centre.z)
		var hi := Vector3(x0 + width, GATE_MAX.y - centre.y, GATE_MAX.z - centre.z)
		_add_box(tool, lo, hi, Color(PLANK_SHADES[k], PLANK_SHADES[k], PLANK_SHADES[k]))
	tool.generate_normals()
	var board := MeshInstance3D.new()
	board.name = "SluiceGate"
	board.mesh = tool.commit()
	var timber := StandardMaterial3D.new()
	timber.albedo_color = WorldLook.TIMBER.darkened(0.42)
	timber.vertex_color_use_as_albedo = true
	timber.roughness = 0.9
	board.material_override = timber
	board.position = centre
	return board


static func _add_box(tool: SurfaceTool, lo: Vector3, hi: Vector3, colour: Color) -> void:
	"""A box from `lo` to `hi` into `tool`, every corner `colour`, its faces wound clockwise seen from outside (Godot's
	front face); flat faces: generate_normals shares nothing between them."""
	var c: Array[Vector3] = [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z)]
	var faces: Array[PackedInt32Array] = [PackedInt32Array([4, 5, 6, 7]), PackedInt32Array([1, 0, 3, 2]),
		PackedInt32Array([5, 1, 2, 6]), PackedInt32Array([0, 4, 7, 3]), PackedInt32Array([7, 6, 2, 3]),
		PackedInt32Array([0, 1, 5, 4])]
	tool.set_color(colour)
	for f: PackedInt32Array in faces:
		for corner: int in [0, 2, 1, 0, 3, 2]:
			tool.add_vertex(c[f[corner]])


func _gush_sheet(water_model_y: float) -> MeshInstance3D:
	"""The white water under a raised board (see THE GUSH): a patch just over the tail water (`water_model_y`, model
	units), its alpha the lift."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var y: float = water_model_y + 0.012
	var x: float = (GATE_MIN.x + GATE_MAX.x) * 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(x - GUSH_HALF_X, y, GUSH_FROM_Z), Vector3(x + GUSH_HALF_X, y, GUSH_FROM_Z),
		Vector3(x + GUSH_HALF_X * 2.6, y, GUSH_OUT_Z), Vector3(x - GUSH_HALF_X * 2.6, y, GUSH_OUT_Z)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_gush_material = gush_material()
	var sheet := MeshInstance3D.new()
	sheet.name = "SluiceGush"
	sheet.mesh = mesh
	sheet.material_override = _gush_material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.visible = false
	return sheet


static func gush_material() -> StandardMaterial3D:
	"""The gush's broken white water: unshaded white whose alpha is a seamless noise (a ramp from clear to white), so
	it reads as froth, not a sheet; its overall alpha is set from the lift."""
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = GUSH_COLOUR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 64
	noise.height = 128
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.08
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	noise.color_ramp = ramp
	material.albedo_texture = noise
	material.uv1_scale = Vector3(1.0, 2.0, 1.0)
	return material


func _build_head(water_material: Material) -> void:
	"""The leat head basin: four stone kerbs round a mud floor, and its water (see THE LEAT HEAD)."""
	var holder := Node3D.new()
	holder.name = "LeatHead"
	holder.position = Vector3(HEAD_AT.x, Layout.GROUND_Y, HEAD_AT.y)
	add_child(holder)
	var timber := StandardMaterial3D.new()
	timber.albedo_color = WorldLook.TIMBER.darkened(0.35)
	timber.vertex_color_use_as_albedo = true
	timber.roughness = 0.92
	var kerb := MeshInstance3D.new()
	kerb.name = "LeatHeadSides"
	kerb.mesh = kerb_mesh()
	kerb.material_override = timber
	holder.add_child(kerb)
	var mud := StandardMaterial3D.new()
	mud.albedo_color = MUD
	mud.roughness = 1.0
	holder.add_child(_box(Vector3(HEAD_HALF.x * 2.0, HEAD_FLOOR, HEAD_HALF.y * 2.0), Vector3(0.0, HEAD_FLOOR * 0.5, 0.0), mud))
	_head_water = MeshInstance3D.new()
	_head_water.name = "LeatHeadWater"
	_head_water.mesh = _water_quad(HEAD_HALF)
	if water_material != null:
		_head_water.material_override = water_material
	_head_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_head_water)


static func kerb_mesh() -> ArrayMesh:
	"""The head's sides: KERB_COURSES courses of timber planks round its inside (HEAD_HALF), HEAD_KERB thick and
	HEAD_TOP high in all -- the garden beds' own timber edging -- each plank's shade varied by a fixed rule (the same
	every run)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var course_h: float = HEAD_TOP / float(KERB_COURSES)
	var n: int = 0
	for side: int in 4:
		var along_x: bool = side < 2
		var sign_v: float = -1.0 if side % 2 == 0 else 1.0
		var half: float = HEAD_HALF.x + HEAD_KERB if along_x else HEAD_HALF.y
		for course: int in KERB_COURSES:
			var y0: float = float(course) * course_h
			var y1: float = y0 + course_h - PLANK_JOINT_M
			var shade: float = PLANK_SHADES[n % PLANK_SHADES.size()]
			var inner: float = sign_v * (HEAD_HALF.y if along_x else HEAD_HALF.x)
			var outer: float = sign_v * ((HEAD_HALF.y if along_x else HEAD_HALF.x) + HEAD_KERB)
			var lo := Vector3(-half, y0, minf(inner, outer)) if along_x else Vector3(minf(inner, outer), y0, -half)
			var hi := Vector3(half, y1, maxf(inner, outer)) if along_x else Vector3(maxf(inner, outer), y1, half)
			_add_box(tool, lo, hi, Color(shade, shade, shade))
			n += 1
	tool.generate_normals()
	return tool.commit()


static func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	"""One box piece."""
	var box := BoxMesh.new()
	box.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = box
	piece.material_override = material
	piece.position = at
	return piece


static func _water_quad(half: Vector2) -> ArrayMesh:
	"""A flat quad of `half` size, carrying the water shader's vertex inputs (water.gdshader: shallow, well inside
	the bank, a slow drift)."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y),
		Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var shallow := Color(HEAD_WATER_DEPTH, 1.0, 0.0, 1.0)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([shallow, shallow, shallow, shallow])
	var drift := Vector2(0.0, 0.12)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([drift, drift, drift, drift])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- following the sluice -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Wind the board toward the setting on the demo clock, and draw the gush and the head's water from it."""
	if _leat == null:
		return
	var usec: int = _clock.frame_usec if _clock != null else 0
	step(float(usec) / 1000000.0)


func step(seconds: float) -> void:
	"""Advance the board by `seconds` of demo time and redraw (checks call it directly)."""
	var target: float = target_lift(_leat.flow_permille())
	if lift == target and (lift == 0.0 or seconds == 0.0) and _drawn:
		return
	lift = move_toward(lift, target, LIFT_RATE * seconds)
	_gush_scroll = fmod(_gush_scroll + seconds * 1.6, 1.0)
	_draw()


func snap() -> void:
	"""Stand the board where the setting puts it at once (the build; checks)."""
	if _leat != null:
		lift = target_lift(_leat.flow_permille())
	_draw()


func _draw() -> void:
	"""Place the board, the gush and the head's water from `lift`."""
	_drawn = true
	var share: float = lift / LIFT_MODEL
	if _gate != null:
		_gate.position.y = (GATE_MIN.y + GATE_MAX.y) * 0.5 + lift
	if _gush != null:
		_gush.visible = share > 0.02
		_gush_material.albedo_color.a = GUSH_ALPHA * share
		_gush_material.uv1_offset = Vector3(0.0, -_gush_scroll, 0.0)
	if _head_water != null:
		_head_water.visible = share > 0.02
		_head_water.position.y = lerpf(HEAD_FLOOR, HEAD_BRIM, share)


func gate() -> MeshInstance3D:
	"""The board (checks)."""
	return _gate


func head_water() -> MeshInstance3D:
	"""The leat head's water (checks)."""
	return _head_water
