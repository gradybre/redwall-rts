extends RefCounted
## WHERE THE WILDLIFE IS. Decision 1631 (feature #11). Presentation only: authored spots, measured once against the
## village's real water map (demo/water/water_map.gd) when the wildlife is configured -- never per frame.
##
##   * ROBINS hop and peck on open ground: the lawn by the hall, the square's edges, the beds' paths, the workbench yard,
##     the fence corner -- places a garden robin works, clear of every building (layout positions, metres).
##   * BUTTERFLIES flutter over the crop beds, the reeds and the square's verges (each spot the centre of a loop).
##   * FROGS sit on the pond's bank, just above its waterline: each pond circle's ring at FROG_SETBACK_M beyond its edge,
##     kept where that point is dry land and clear of the landings' jetties and boats, at the bank's own height
##     (`ground_height_at`).
##   * TROUT leap where the water is at least TROUT_DEPTH_M deep: the pond's circles and the stream's run by the fisher
##     shelter -- each spot a point on the surface and a heading (y = the surface: water_layout.gd LEVEL_DROP_U).

const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")

## Robin ground spots (x, z), metres: open ground a resident's path may cross, clear of every placed obstacle
## (test_demo_wildlife.gd pins it). Butterflies fly over the beds, so their centres need not be.
const ROBIN_SPOTS: PackedVector2Array = [
	Vector2(-3.0, -9.0), Vector2(2.4, -8.6), Vector2(-6.2, 2.8), Vector2(5.6, 2.2), Vector2(-7.6, 11.4),
	Vector2(-7.2, 16.8), Vector2(6.4, 10.4), Vector2(-6.0, 6.0), Vector2(2.2, 15.6), Vector2(-2.6, -16.8),
]
## Butterfly loop centres (x, z), metres.
const BUTTERFLY_SPOTS: PackedVector2Array = [
	Vector2(-11.0, 9.2), Vector2(-11.0, 12.8), Vector2(-11.0, 16.4), Vector2(-17.6, 9.4), Vector2(-5.6, 0.4),
	Vector2(4.8, -4.6),
]
## The stream's run (x, z), metres, and its heading downstream (water_layout.gd STREAM_VERTICES: 24.4, 11.0).
const RUN_AT: Vector2 = Vector2(24.4, 11.0)
const RUN_HEADING: Vector2 = Vector2(0.5524, 0.8336)
## A frog sits this far beyond a pond circle's edge (demo value: on the wet bank, out of the water).
const FROG_SETBACK_M: float = 0.18
## A frog sits this far from any landing (its jetty and boat; m) and from another frog.
const LANDING_CLEAR_M: float = 3.5
const FROG_SPACING_M: float = 1.5
## Ring samples tried per pond circle, and how many frog spots are kept at most.
const RING_SAMPLES: int = 24
const MAX_FROG_SPOTS: int = 12
## A trout leaps only where the water is at least this deep (demo value).
const TROUT_DEPTH_M: float = 0.6
## Trout spots: within this share of each pond circle's radius from its centre.
const TROUT_REACH: float = 0.5


static func surface_y() -> float:
	"""The water surface's height, metres (below the ground datum)."""
	return -WaterRules.to_m(WaterLayout.LEVEL_DROP_U)


static func robin_spots() -> PackedVector3Array:
	"""Every robin spot on the ground (y = 0)."""
	var out := PackedVector3Array()
	for p: Vector2 in ROBIN_SPOTS:
		out.append(Vector3(p.x, 0.0, p.y))
	return out


static func butterfly_spots() -> PackedVector3Array:
	"""Every butterfly loop centre on the ground (its height is the flight's)."""
	var out := PackedVector3Array()
	for p: Vector2 in BUTTERFLY_SPOTS:
		out.append(Vector3(p.x, 0.0, p.y))
	return out


static func frog_spots(map: WaterMapScript) -> PackedVector3Array:
	"""Dry bank points just beyond each pond circle's edge, at the bank's height (see the header): at least
	LANDING_CLEAR_M from every landing (its jetty, its boat) and FROG_SPACING_M from each other, at most MAX_FROG_SPOTS."""
	var out := PackedVector3Array()
	var circles: Array[int] = WaterLayout.POND_CIRCLES
	for c: int in range(0, circles.size(), 4):
		var centre := Vector2(WaterRules.to_m(circles[c]), WaterRules.to_m(circles[c + 1]))
		var radius: float = WaterRules.to_m(circles[c + 2]) + FROG_SETBACK_M
		for k: int in RING_SAMPLES:
			var p: Vector2 = centre + Vector2.from_angle(TAU * float(k) / float(RING_SAMPLES)) * radius
			var at := Vector2i(WaterRules.to_u(p.x), WaterRules.to_u(p.y))
			if out.size() < MAX_FROG_SPOTS and not map.is_water(at) and _frog_room(p, out):
				out.append(Vector3(p.x, WaterRules.to_m(map.ground_height_at(at)), p.y))
	return out


static func _frog_room(p: Vector2, taken: PackedVector3Array) -> bool:
	"""Whether a frog may sit at `p`: clear of every landing and of the frogs already placed."""
	for near: Vector2i in WaterLayout.LANDING_NEAR:
		if p.distance_to(Vector2(WaterRules.to_m(near.x), WaterRules.to_m(near.y))) < LANDING_CLEAR_M:
			return false
	for q: Vector3 in taken:
		if p.distance_to(Vector2(q.x, q.z)) < FROG_SPACING_M:
			return false
	return true


static func trout_spots(map: WaterMapScript) -> PackedVector3Array:
	"""Surface points over deep enough water (see the header): the stream's run, then the pond circles' middles."""
	var out := PackedVector3Array()
	var y: float = surface_y()
	if deep_enough(map, RUN_AT):
		out.append(Vector3(RUN_AT.x, y, RUN_AT.y))
	var circles: Array[int] = WaterLayout.POND_CIRCLES
	for c: int in range(0, circles.size(), 4):
		var centre := Vector2(WaterRules.to_m(circles[c]), WaterRules.to_m(circles[c + 1]))
		var off := Vector2.from_angle(float(c)) * WaterRules.to_m(circles[c + 2]) * TROUT_REACH
		if deep_enough(map, centre + off):
			out.append(Vector3(centre.x + off.x, y, centre.y + off.y))
	return out


static func deep_enough(map: WaterMapScript, p: Vector2) -> bool:
	"""Whether the water at `p` is at least TROUT_DEPTH_M deep."""
	return map.depth_at(Vector2i(WaterRules.to_u(p.x), WaterRules.to_u(p.y))) >= WaterRules.to_u(TROUT_DEPTH_M)


static func heading_at(spot: Vector3) -> Vector2:
	"""A trout's leap heading at a spot: down the run in the stream, else round the pond (tangent to its middle)."""
	if Vector2(spot.x, spot.z).distance_to(RUN_AT) < 0.5:
		return RUN_HEADING.normalized()
	var c := Vector2(WaterRules.to_m(WaterLayout.POND_CIRCLES[0]), WaterRules.to_m(WaterLayout.POND_CIRCLES[1]))
	var radial := Vector2(spot.x, spot.z) - c
	return Vector2(-radial.y, radial.x).normalized() if radial.length() > 0.01 else Vector2.RIGHT


static func pond_middle() -> Vector3:
	"""The pond's middle on its surface (its first and largest circle's centre): what a frog on its bank faces."""
	return Vector3(WaterRules.to_m(WaterLayout.POND_CIRCLES[0]), surface_y(), WaterRules.to_m(WaterLayout.POND_CIRCLES[1]))
