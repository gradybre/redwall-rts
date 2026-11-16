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
## PER FAMILY (decision 2021; all drawn at a 2 × 2's north-west corner, going down or rising north, and turned by the
## view): the Burrow mouth's RAMP (a sloped earth floor in its cut), the Hatch's HATCH (a timber frame round a dark
## hole, its lid open, a ladder's top: the Mound hatch's measures, demo_build_mound_parts.gd) and LADDER (rails and
## rungs up from its landing), and the Stair-head's STAIR HEAD on the Surface (a timber frame round the dark way down);
## the Stair-head's own flight is the STAIRS above.

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


static func cut_mesh(paint: Material, depth_m: float) -> ArrayMesh:
	"""The cut a staged stair flight goes down in (decision 1913): its earth sides `depth_m` deep and its dark far end,
	the flight itself drawn by the art."""
	var quads: Quads = Quads.new()
	_cut_sides(quads, -depth_m, 0.0, SIDE_M, Mouth.CUT_DEEP)
	quads.quad(Vector3(0.0, -depth_m, 0.0), Vector3(SIDE_M, -depth_m, 0.0), Vector3(SIDE_M, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0), Vector3.BACK, Mouth.THROAT_END)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func _cut_sides(quads: Quads, low: float, north: float, south: float, colour: Color) -> void:
	"""The earth walls either side of one tread, from the tread up to the dug floor, facing in."""
	for x: float in [0.0, SIDE_M]:
		quads.quad(Vector3(x, low, north), Vector3(x, low, south), Vector3(x, 0.0, south), Vector3(x, 0.0, north),
			Vector3.RIGHT if x == 0.0 else Vector3.LEFT, colour)


# --- per family (decision 2021) --------------------------------------------------------------------------------------

const OAK: Color = Color(0.46, 0.31, 0.17)
const RAIL: Color = Color(0.38, 0.26, 0.15)
## The Mound hatch's measures (demo_build_mound_parts.gd add_hatch): hole, frame, lid, rails and rungs (m).
const HATCH_HOLE_M: float = 1.7
const HATCH_FRAME_M: float = 1.96
const HATCH_BEAM_M: float = 0.16
const LADDER_HALF_M: float = 0.3
const RUNG_EVERY_M: float = 0.33


static func ramp_mesh(paint: Material, depth_m: float, down: bool) -> ArrayMesh:
	"""A ramp's earth floor over a 2 × 2: rising north from the dug floor to `depth_m` up (`down` false), or falling
	north `depth_m` into its cut (`down` true), between earth sides."""
	var quads: Quads = Quads.new()
	var south_y: float = 0.0
	var north_y: float = -depth_m if down else depth_m
	quads.shaded(Vector3(0.0, north_y, 0.0), Vector3(SIDE_M, north_y, 0.0), Vector3(SIDE_M, south_y, SIDE_M),
		Vector3(0.0, south_y, SIDE_M), Vector3(0.0, SIDE_M, depth_m * (1.0 if down else -1.0)).normalized(),
		PackedColorArray([Mouth.THROAT_END if down else WORN, Mouth.THROAT_END if down else WORN, WORN, WORN]))
	if down:
		_cut_sides(quads, -depth_m, 0.0, SIDE_M, Mouth.CUT_DEEP)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func hatch_mesh(paint: Material) -> ArrayMesh:
	"""A hatch over a 2 × 2: the dark hole, a timber frame, the lid standing open to the north, a ladder's top."""
	var quads: Quads = Quads.new()
	var middle: Vector3 = Vector3(SIDE_M / 2.0, 0.0, SIDE_M / 2.0)
	var hole: float = HATCH_HOLE_M / 2.0
	quads.quad(middle + Vector3(-hole, 0.02, -hole), middle + Vector3(hole, 0.02, -hole), middle + Vector3(hole, 0.02, hole),
		middle + Vector3(-hole, 0.02, hole), Vector3.UP, Mouth.THROAT_END)
	var half: float = HATCH_FRAME_M / 2.0 - HATCH_BEAM_M / 2.0
	for side: Vector3 in [Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, half)]:
		box(quads, middle + side + Vector3(0.0, 0.06, 0.0), Vector3(HATCH_FRAME_M, 0.12, HATCH_BEAM_M), OAK)
	for side: Vector3 in [Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0)]:
		box(quads, middle + side + Vector3(0.0, 0.06, 0.0), Vector3(HATCH_BEAM_M, 0.12, HATCH_FRAME_M), OAK)
	box(quads, middle + Vector3(0.0, HATCH_HOLE_M / 2.0, -half - 0.05), Vector3(HATCH_HOLE_M, HATCH_HOLE_M, 0.07), OAK)
	_ladder(quads, middle + Vector3(0.0, 0.0, 0.3), 0.0, 1.0)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func ladder_mesh(paint: Material, height_m: float) -> ArrayMesh:
	"""A ladder standing on a landing's 2 × 2, from the dug floor up `height_m` into the hatch above."""
	var quads: Quads = Quads.new()
	_ladder(quads, Vector3(SIDE_M / 2.0, 0.0, SIDE_M / 2.0 + 0.3), 0.0, height_m)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func stair_head_mesh(paint: Material) -> ArrayMesh:
	"""A stair-head on the Surface over a 2 × 2: a dark way down framed by two timber posts and a lintel, on a sill."""
	var quads: Quads = Quads.new()
	quads.quad(Vector3(0.1, 0.02, 0.1), Vector3(SIDE_M - 0.1, 0.02, 0.1), Vector3(SIDE_M - 0.1, 0.02, SIDE_M - 0.1),
		Vector3(0.1, 0.02, SIDE_M - 0.1), Vector3.UP, Mouth.THROAT_END)
	box(quads, Vector3(SIDE_M / 2.0, 0.06, SIDE_M - 0.08), Vector3(SIDE_M, 0.12, HATCH_BEAM_M), OAK)
	for x: float in [0.15, SIDE_M - 0.15]:
		box(quads, Vector3(x, 0.7, 0.2), Vector3(HATCH_BEAM_M, 1.4, HATCH_BEAM_M), OAK)
	box(quads, Vector3(SIDE_M / 2.0, 1.45, 0.2), Vector3(SIDE_M, HATCH_BEAM_M, HATCH_BEAM_M), OAK)
	var mesh: ArrayMesh = ArrayMesh.new()
	quads.commit(mesh, paint)
	return mesh


static func _ladder(quads: Quads, foot: Vector3, from_m: float, to_m: float) -> void:
	"""Two rails and rungs every RUNG_EVERY_M from `from_m` to `to_m` above `foot`."""
	var length: float = to_m - from_m
	for rail: float in [-LADDER_HALF_M, LADDER_HALF_M]:
		box(quads, foot + Vector3(rail, from_m + length / 2.0, 0.0), Vector3(0.07, length, 0.07), RAIL)
	var rung: float = from_m + RUNG_EVERY_M
	while rung < to_m:
		box(quads, foot + Vector3(0.0, rung, 0.0), Vector3(LADDER_HALF_M * 2.0, 0.05, 0.05), RAIL)
		rung += RUNG_EVERY_M


static func box(quads: Quads, centre: Vector3, size: Vector3, colour: Color) -> void:
	"""An axis-aligned box's four sides and top (its bottom is never seen)."""
	var h: Vector3 = size / 2.0
	var c: Vector3 = centre
	quads.quad(c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z),
		c + Vector3(-h.x, h.y, h.z), Vector3.UP, colour)
	for sign_x: float in [-1.0, 1.0]:
		var x: float = h.x * sign_x
		quads.quad(c + Vector3(x, -h.y, -h.z), c + Vector3(x, -h.y, h.z), c + Vector3(x, h.y, h.z),
			c + Vector3(x, h.y, -h.z), Vector3(sign_x, 0.0, 0.0), colour.darkened(0.15))
	for sign_z: float in [-1.0, 1.0]:
		var z: float = h.z * sign_z
		quads.quad(c + Vector3(-h.x, -h.y, z), c + Vector3(h.x, -h.y, z), c + Vector3(h.x, h.y, z),
			c + Vector3(-h.x, h.y, z), Vector3(0.0, 0.0, sign_z), colour.darkened(0.25))
