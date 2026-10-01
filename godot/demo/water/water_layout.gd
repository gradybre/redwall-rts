extends RefCounted
## The demo village's water, authored: a stream down the east edge of the village and the pond it
## feeds in the south-east corner, their landings and fishing sites, and the water-side dressing
## placed from existing library assets. Decision 0196 (live demo), water foundation.
##
## ---------------------------------------------------------------------------------------
## WHERE, AND WHY THERE. Everything wet stays OUTSIDE the ±20 m play square (world_layout.gd's
## PLAY_HALF_EXTENT_M), with the whole bank slope outside it too: nothing that stands in the
## village is moved, residents (who are kept inside the square) never walk into water, and no
## player-dug tunnel (whose points are kept inside the same square, tunnel_rules.in_bounds) can
## reach under it until the tunnel code calls `water_map.segment_crosses_water`. The resident spots
## that serve the water (fishing, the weir, the boat landing) stand just inside the square's edge.
##
##   * THE STREAM enters from the north woods, narrows to its neck at the north-east corner (the
##     narrowest span: phase 2's first bridge), runs 4.3 m wide past the WEIR (GDD §5.4: a weir
##     needs "flow 4-12 m wide"), spreads into a shallow FORD where the east road crosses it, then
##     deepens into a RUN by the FISHER SHELTER before it bends south-east into the pond. The MILL
##     stands on its far bank at the neck, waterwheel to the water.
##   * THE POND lies beyond the square's south-east corner, still water, with the BOATHOUSE on its
##     north shore facing south across it -- towards the camera's usual side.
##
## Positions and depths are integers in u = 1/1024 m, each row commented in metres. Every depth
## and width is a DEMO value: SET-MOVE-001 §4 originates no production depths.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")

## Bank run, water level and ramps (demo values, u).
const BANK_RUN_U: int = 1229          # 1.2 m: bank top to waterline, horizontally
const LEVEL_DROP_U: int = 184         # 0.18 m: the water surface below the ground datum
const STREAM_RAMP_U: int = 1229       # 1.2 m in from the waterline the stream reaches full depth
const POND_RAMP_U: int = 2253         # 2.2 m in from the waterline the pond reaches full depth
const STREAM_FLOW_U_S: int = 410      # 0.4 m/s surface flow
## A landing's land point stands this far beyond its waterline point: the bank run and 0.3 m.
const LANDING_SETBACK_U: int = 1536

const STREAM_NAME: StringName = &"stream"
const POND_NAME: StringName = &"pond"

## (x, z, half_width, bed_depth) in u, upstream first.
const STREAM_VERTICES: Array[int] = [
	29696, -194560, 1946, 870,   # 29.0, -190.0  1.9 m half-width, 0.85 m deep -- far north woods
	27136, -97280, 1946, 870,    # 26.5, -95.0
	24986, -46080, 1894, 922,    # 24.4, -45.0
	23859, -25600, 1741, 973,    # 23.3, -25.0   the neck: 3.4 m wide (narrowest span)
	24371, -14336, 2202, 1126,   # 23.8, -14.0   the weir reach: 4.3 m wide, 1.1 m deep
	25293, -7168, 2662, 614,     # 24.7, -7.0
	25805, -3072, 3277, 215,     # 25.2, -3.0    the ford: 6.4-6.6 m wide, 0.2 m deep
	25702, 1434, 3379, 205,      # 25.1, 1.4     (the east road crosses at z = -0.8)
	25395, 5632, 2867, 563,      # 24.8, 5.5
	24986, 11264, 2458, 1434,    # 24.4, 11.0    the run: 1.4 m deep by the fisher shelter
	28262, 16384, 2355, 1178,    # 27.6, 16.0
	31744, 24576, 2253, 1024,    # 31.0, 24.0    into the pond
]

## (x, z, radius, bed_depth) in u.
const POND_CIRCLES: Array[int] = [
	28467, 28672, 5427, 1946,    # 27.8, 28.0   5.3 m, 1.9 m deep
	24474, 30515, 3174, 1229,    # 23.9, 29.8   3.1 m, 1.2 m deep
	32358, 25600, 3072, 1126,    # 31.6, 25.0   3.0 m, 1.1 m deep
	28160, 33587, 3482, 1434,    # 27.5, 32.8   3.4 m, 1.4 m deep
]

## Bank landings: (name, a point near the waterline). Each snaps to the nearest shore sample.
const LANDING_NAMES: Array[StringName] = [
	&"fisher_shelter", &"ford_west", &"ford_east", &"weir_bank", &"boathouse", &"pond_west",
]
const LANDING_NEAR: Array[Vector2i] = [
	Vector2i(22528, 7475),       # 22.0, 7.3
	Vector2i(22323, -819),       # 21.8, -0.8
	Vector2i(29286, -819),       # 28.6, -0.8
	Vector2i(22118, -14336),     # 21.6, -14.0
	Vector2i(23450, 26624),      # 22.9, 26.0
	Vector2i(21197, 30515),      # 20.7, 29.8
]


static func make_map() -> WaterMapScript:
	"""The village's water as a finalised map. Asserts: the authored data is fixed and tested."""
	var map := WaterMapScript.new(BANK_RUN_U)
	var stream := map.add_stream(STREAM_NAME, PackedInt32Array(STREAM_VERTICES), LEVEL_DROP_U,
		STREAM_RAMP_U, STREAM_FLOW_U_S)
	assert(stream.ok, "stream: %s" % stream.error)
	var pond := map.add_pond(POND_NAME, PackedInt32Array(POND_CIRCLES), LEVEL_DROP_U, POND_RAMP_U)
	assert(pond.ok, "pond: %s" % pond.error)
	for k: int in LANDING_NAMES.size():
		var landing := map.add_landing(LANDING_NAMES[k], LANDING_NEAR[k], LANDING_SETBACK_U)
		assert(landing.ok, "landing %s: %s" % [LANDING_NAMES[k], landing.error])
	var done := map.finalize()
	assert(done.ok, "finalize: %s" % done.error)
	return map


static func water_circles_m(margin_m: float) -> Array[Vector3]:
	"""Circles (x, z, radius) in metres covering every body plus `margin_m`, for the woods and the
	ground cover to keep off: one per pond circle, and along each stream leg every 0.75 m with the
	half-width tapered as the leg tapers. Pure function of the authored data (no map is built)."""
	var out: Array[Vector3] = []
	for k: int in range(1, STREAM_VERTICES.size() / 4):
		var a := Vector2(Rules.to_m(STREAM_VERTICES[k * 4 - 4]), Rules.to_m(STREAM_VERTICES[k * 4 - 3]))
		var b := Vector2(Rules.to_m(STREAM_VERTICES[k * 4]), Rules.to_m(STREAM_VERTICES[k * 4 + 1]))
		var ra: float = Rules.to_m(STREAM_VERTICES[k * 4 - 2])
		var rb: float = Rules.to_m(STREAM_VERTICES[k * 4 + 2])
		var steps: int = maxi(1, ceili(a.distance_to(b) / 0.75))
		for s: int in steps + 1:
			var t: float = float(s) / float(steps)
			var at: Vector2 = a.lerp(b, t)
			out.append(Vector3(at.x, at.y, lerpf(ra, rb, t) + margin_m))
	for k: int in POND_CIRCLES.size() / 4:
		out.append(Vector3(Rules.to_m(POND_CIRCLES[k * 4]), Rules.to_m(POND_CIRCLES[k * 4 + 1]),
			Rules.to_m(POND_CIRCLES[k * 4 + 2]) + margin_m))
	return out
