extends RefCounted
## THE WAYS DOWN, DRAWN AS WAYS (decision 1913; decision 1912's proof of concept). Three small meshes, each built once
## by the view that shows them (demo_build_dug.gd) and shared by every way down, in the earth tones the legacy tunnel
## mouth already uses (tunnel_mouth.gd), lit, coloured by their vertices:
##   MOUTH       an Entrance on the surface: a horseshoe mound of dug earth round a dark hole, open to the south where a
##               trodden tongue of earth leads in (the ground is not cut: the hole is drawn on it). Origin: the
##               Entrance's 2 × 2 middle, on the ground.
##   STAIRS UP   where a way down lands: earth steps rising north out of the dug floor to the earth's top, the top
##               tread dark where the way goes on up into the earth. Origin: the landing's north-west corner, on the
##               dug floor.
##   STAIRS DOWN where a way down stands on a level: steps cut down into the dug floor, going north into the dark (each
##               tread darker), between earth walls. Origin: its north-west corner, on the dug floor.
## The shape tells up from down from a mouth; the tag over each says which in words. Presentation only.

const Quads := preload("res://demo/build_panel/demo_build_quads.gd")
const Mouth := preload("res://demo/tunnel/tunnel_mouth.gd")

## The mound round a mouth (m): the hole's rim, the mound's crest and foot, the crest's height; SEGMENTS round it, and
## the opening to the south half GAP_RAD wide.
const HOLE_M: float = 0.62
const CREST_M: float = 0.86
const FOOT_M: float = 1.28
const CREST_UP_M: float = 0.3
const HOLE_UP_M: float = 0.025
const SEGMENTS: int = 20
const GAP_RAD: float = 0.5
## The trodden tongue into the mouth: its half-width, how far it runs out, its height over the ground.
const TONGUE_HALF_M: float = 0.42
const TONGUE_OUT_M: float = 1.55
const TONGUE_UP_M: float = 0.012
const WORN: Color = Color(0.58, 0.47, 0.34)
## The mound's fresh-dug earth: lighter at its crest than at its foot, so it reads in a tree's shade too.
const CREST: Color = Color(0.6, 0.46, 0.31)
const FOOT: Color = Color(0.44, 0.34, 0.23)
## Stairs: STEPS treads over the 2 m of a way's cells; the stairs up are STAIR_HALF_M either side of the middle and
## rise to the earth's top (`depth_m`); the stairs down drop STEP_DOWN_M a tread.
const STEPS: int = 4
const SIDE_M: float = 2.0
const STAIR_HALF_M: float = 0.72
const STEP_DOWN_M: float = 0.3
const TREAD: Color = Color(0.5, 0.36, 0.22)
const RISER: Color = Color(0.3, 0.22, 0.15)


static func material() -> StandardMaterial3D:
	"""Lit, matte, coloured by the vertices (sRGB, as tunnel_mouth.gd's), both faces drawn (the meshes are open
	shells)."""
	var out: StandardMaterial3D = StandardMaterial3D.new()
	out.vertex_color_use_as_albedo = true
	out.vertex_color_is_srgb = true
	out.roughness = 1.0
	out.cull_mode = BaseMaterial3D.CULL_DISABLED
	return out


static func mouth_mesh(paint: Material) -> ArrayMesh:
	"""The Entrance's burrow mouth (see the header)."""
	var quads: Quads = Quads.new()
	for k: int in SEGMENTS:
		var from: float = TAU * k / SEGMENTS
		var to: float = TAU * (k + 1) / SEGMENTS
		_hole_slice(quads, from, to)
		if absf(wrapf((from + to) / 2.0, -PI, PI)) > GAP_RAD:
			_mound_slice(quads, from, to)
	_tongue(quads)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func _round(angle: float, radius: float, up: float) -> Vector3:
	"""A point `radius` from the mouth's middle at `angle` (0: south, +z), `up` over the ground."""
	return Vector3(sin(angle) * radius, up, cos(angle) * radius)


static func _hole_slice(quads: Quads, from: float, to: float) -> void:
	"""One slice of the dark hole: black at the middle, the dug earth's dark at the rim."""
	var middle: Vector3 = Vector3(0.0, HOLE_UP_M, 0.0)
	quads.shaded(middle, middle, _round(to, HOLE_M, HOLE_UP_M), _round(from, HOLE_M, HOLE_UP_M), Vector3.UP,
		PackedColorArray([Mouth.THROAT_END, Mouth.THROAT_END, Mouth.CUT_DEEP, Mouth.CUT_DEEP]))


static func _mound_slice(quads: Quads, from: float, to: float) -> void:
	"""One slice of the mound: its inner face down into the hole, its outer slope down to the ground."""
	var mid: float = (from + to) / 2.0
	var inward: Vector3 = Vector3(-sin(mid), 0.9, -cos(mid)).normalized()
	var outward: Vector3 = Vector3(sin(mid), 1.4, cos(mid)).normalized()
	quads.shaded(_round(from, HOLE_M, HOLE_UP_M), _round(to, HOLE_M, HOLE_UP_M), _round(to, CREST_M, CREST_UP_M),
		_round(from, CREST_M, CREST_UP_M), inward,
		PackedColorArray([Mouth.CUT_DEEP, Mouth.CUT_DEEP, Mouth.CUT_TOP, Mouth.CUT_TOP]))
	quads.shaded(_round(from, CREST_M, CREST_UP_M), _round(to, CREST_M, CREST_UP_M), _round(to, FOOT_M, 0.0),
		_round(from, FOOT_M, 0.0), outward, PackedColorArray([CREST, CREST, FOOT, FOOT]))


static func _tongue(quads: Quads) -> void:
	"""The trodden earth leading in from the south, darkening into the hole."""
	var near: float = HOLE_M * 0.6
	quads.shaded(Vector3(-TONGUE_HALF_M, TONGUE_UP_M, near), Vector3(TONGUE_HALF_M, TONGUE_UP_M, near),
		Vector3(TONGUE_HALF_M, TONGUE_UP_M, TONGUE_OUT_M), Vector3(-TONGUE_HALF_M, TONGUE_UP_M, TONGUE_OUT_M), Vector3.UP,
		PackedColorArray([Mouth.CUT_DEEP, Mouth.CUT_DEEP, WORN, WORN]))


static func stairs_up_mesh(paint: Material, depth_m: float) -> ArrayMesh:
	"""Steps rising north from the dug floor to the earth's top `depth_m` up (see the header)."""
	var quads: Quads = Quads.new()
	var run: float = SIDE_M / STEPS
	var west: float = SIDE_M / 2.0 - STAIR_HALF_M
	var east: float = SIDE_M / 2.0 + STAIR_HALF_M
	for k: int in STEPS:
		var low: float = depth_m * k / STEPS
		var high: float = depth_m * (k + 1) / STEPS
		var south: float = SIDE_M - run * k
		var north: float = 0.0 if k == STEPS - 1 else south - run
		var top: Color = Mouth.THROAT_END if k == STEPS - 1 else TREAD
		quads.quad(Vector3(west, high, north), Vector3(east, high, north), Vector3(east, high, south),
			Vector3(west, high, south), Vector3.UP, top)
		quads.quad(Vector3(west, low, south), Vector3(east, low, south), Vector3(east, high, south),
			Vector3(west, high, south), Vector3.BACK, RISER)
		for x: float in [west, east]:
			quads.quad(Vector3(x, 0.0, north), Vector3(x, 0.0, south), Vector3(x, high, south), Vector3(x, high, north),
				Vector3.LEFT if x == west else Vector3.RIGHT, Mouth.CUT_TOP)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func stairs_down_mesh(paint: Material) -> ArrayMesh:
	"""Steps cut down into the dug floor, going north into the dark (see the header)."""
	var quads: Quads = Quads.new()
	var run: float = SIDE_M / STEPS
	for k: int in STEPS:
		var high: float = -STEP_DOWN_M * k
		var low: float = -STEP_DOWN_M * (k + 1)
		var south: float = SIDE_M - run * k
		var north: float = south - run
		var dark: float = float(k + 1) / STEPS
		quads.quad(Vector3(0.0, low, north), Vector3(SIDE_M, low, north), Vector3(SIDE_M, low, south),
			Vector3(0.0, low, south), Vector3.UP, TREAD.lerp(Mouth.THROAT_END, dark))
		quads.quad(Vector3(0.0, low, south), Vector3(SIDE_M, low, south), Vector3(SIDE_M, high, south),
			Vector3(0.0, high, south), Vector3.BACK, RISER.lerp(Mouth.THROAT_END, dark))
		_cut_sides(quads, low, north, south, Mouth.CUT_DEEP.lerp(Mouth.THROAT_END, dark))
	var bottom: float = -STEP_DOWN_M * STEPS
	quads.quad(Vector3(0.0, bottom, 0.0), Vector3(SIDE_M, bottom, 0.0), Vector3(SIDE_M, 0.0, 0.0), Vector3(0.0, 0.0, 0.0),
		Vector3.BACK, Mouth.THROAT_END)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func _cut_sides(quads: Quads, low: float, north: float, south: float, colour: Color) -> void:
	"""The earth walls either side of one tread, from the tread up to the dug floor, facing in."""
	for x: float in [0.0, SIDE_M]:
		quads.quad(Vector3(x, low, north), Vector3(x, low, south), Vector3(x, 0.0, south), Vector3(x, 0.0, north),
			Vector3.RIGHT if x == 0.0 else Vector3.LEFT, colour)
