extends RefCounted
## The water as the walkers meet it: the band of circles that keeps walkers out of water too deep to
## wade, the swimmers' LINKS across it, and every validated bank CONNECTION. Decision 0196 (live
## demo). Built once from the finalised water map (water/water_map.gd); read-only after `build`.
##
## ---------------------------------------------------------------------------------------
## THE BAND. The demo's walkers plan round obstacle circles (cast/cast_nav.gd), so the water a walker
## may not enter is given to them as circles: along every stream primitive, every BAND_STEP_M, and
## round every pond circle, circles of radius BAND_R_M whose outer edge lies on the contour where the
## water is deeper than a 1.0 m mouse wades (water_rules.gd WADE_MAX_PERMILLE: 256 u). Circles wholly
## inside the band are dropped: the boundary alone keeps a walker out. ONE contour serves every body:
## the planner has one set of circles, so a taller body that could wade deeper is planned
## conservatively -- it still wades where a mouse would (the ford) and is drawn in its own zone. The
## ford's bed (0.20-0.22 m) is under the contour, so it is open ground: everyone wades it.
## The band runs BAND_BEYOND_M past the planning AREA (cast_nav.gd THE PLANNING AREA), so a walker
## can never walk round its far end.
##
## LINKS are the swimmers' crossings (MOVE-REQ-001, TRV-W02: entry and exit only at validated bank
## connections): across the stream every LINK_STRIDE-th measured span (water_map.gd `station_*`,
## every 0.5 m, so every 3 m), skipping wadeable ones (the ford is walked), and across the pond along
## four chords through its first circle's centre. Each has a dry LAND end LAND_SETBACK_M beyond each
## waterline -- off the carved bank -- and a WATER end just inside it. A link whose land end stands in
## or near an obstacle (the weir, the mill, the boathouse, a tree) or whose bank walk would pass
## through one is not published. Each link records the flow at its middle, split along and across it.
##
## CONNECTIONS are every link end and every authored landing whose land point is clear (`landing_ok`):
## where a swimmer may enter or leave the water. `nearest_connection_into` finds the one nearest a point in a body (to swim ashore, or to set
## off from towards a spot in the water).
##
## Floats here are presentation (the cast walks in float metres); every input is the map's integers.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The planning area: the woods' obstacle reach (forestry's 30 m reach, its 11 m walking margin and
## the 3 m the woods' blockers are listed beyond both; demo_forestry.gd `extra_obstacles`).
const AREA_HALF_M: float = 44.0
const BAND_R_M: float = 1.0
const BAND_STEP_M: float = 1.0
const BAND_BEYOND_M: float = 6.0
const BAND_INTERIOR_EPS_M: float = 0.05
const LINK_STRIDE: int = 6
const LAND_SETBACK_M: float = 1.3
const WATER_INSET_M: float = 0.05
const LAND_CLEAR_M: float = 0.5
## An authored landing's land point needs only a mouse's body clear (the landings stand by the shelter
## and the boathouse on purpose).
const LANDING_CLEAR_M: float = 0.25
const CHORDS: int = 4
const DRY_STEP_M: float = 0.1
const DRY_STEPS: int = 200
## Choosing where to go in for a spot, a metre of swimming weighs this many of walking (demo).
const SWIM_WEIGHT: float = 2.0
const KIND_ACROSS: int = 0
const KIND_CHORD: int = 1

var area: Rect2 = Rect2(-AREA_HALF_M, -AREA_HALF_M, 2.0 * AREA_HALF_M, 2.0 * AREA_HALF_M)
## The band, as the cast's obstacle circles Vector3(x, radius, z).
var band: Array[Vector3] = []
var link_count: int = 0
var link_land_a: PackedVector2Array = PackedVector2Array()
var link_water_a: PackedVector2Array = PackedVector2Array()
var link_water_b: PackedVector2Array = PackedVector2Array()
var link_land_b: PackedVector2Array = PackedVector2Array()
var link_body: PackedInt32Array = PackedInt32Array()
var link_kind: PackedByteArray = PackedByteArray()
## The flow at a link's middle, mm/s, along it (a -> b) and across it (either sign).
var link_flow_along: PackedInt32Array = PackedInt32Array()
var link_flow_across: PackedInt32Array = PackedInt32Array()
## Per authored landing (water_map.gd): whether its land point is clear to stand on.
var landing_ok: PackedByteArray = PackedByteArray()
var conn_land: PackedVector2Array = PackedVector2Array()
var conn_water: PackedVector2Array = PackedVector2Array()
var conn_body: PackedInt32Array = PackedInt32Array()

var _map: WaterMapScript = null
var _obstacles: Array[Vector3] = []
var _wade_m: float = 0.0
var _read: IntMath.IntResult = IntMath.IntResult.new()


func build(map: WaterMapScript, obstacles: Array[Vector3]) -> void:
	"""Lay the band, the links and the connections for `map` among the walkers' `obstacles`
	(Vector3(x, radius, z) circles)."""
	_map = map
	_obstacles = obstacles
	_wade_m = Rules.to_m(Rules.wade_max_u(Rules.MOUSE_HEIGHT_U))
	band.clear()
	for body: int in map.body_count():
		_band_body(body)
	_drop_interior()
	_add_stream_links()
	_add_pond_chords()
	_add_landings()


# --- the band ------------------------------------------------------------------------------------

func _band_body(body: int) -> void:
	"""The band circles of one body's primitives."""
	var range_i: Vector2i = _map.body_segment_range(body)
	var ramp_m: float = Rules.to_m(_map.body_ramp_u(body))
	for i: int in range(range_i.x, range_i.x + range_i.y):
		var seg: PackedInt32Array = _map.segment(i)
		if seg[0] == seg[2] and seg[1] == seg[3]:
			_band_circle(seg, ramp_m)
		else:
			_band_capsule(seg, ramp_m)


func blocked_width_m(radius_m: float, depth_m: float, ramp_m: float) -> float:
	"""How far from a primitive's axis the water is deeper than a mouse wades: its radius less the
	ramp it takes the depth to pass the wade depth (0 when it never does)."""
	if depth_m <= _wade_m:
		return 0.0
	return maxf(radius_m - _wade_m * ramp_m / depth_m, 0.0)


func _band_capsule(seg: PackedInt32Array, ramp_m: float) -> void:
	"""Circles along a stream leg, every BAND_STEP_M, their outer edges on the contour either side."""
	var a := Vector2(Rules.to_m(seg[0]), Rules.to_m(seg[1]))
	var b := Vector2(Rules.to_m(seg[2]), Rules.to_m(seg[3]))
	var length: float = a.distance_to(b)
	var normal: Vector2 = (b - a).orthogonal() / length
	var steps: int = maxi(1, ceili(length / BAND_STEP_M))
	for k: int in steps + 1:
		var t: float = float(k) / float(steps)
		var w: float = blocked_width_m(lerpf(Rules.to_m(seg[4]), Rules.to_m(seg[5]), t),
			lerpf(Rules.to_m(seg[6]), Rules.to_m(seg[7]), t), ramp_m)
		_band_across(a.lerp(b, t), normal, w)


func _band_across(centre: Vector2, normal: Vector2, w: float) -> void:
	"""One station's circles: one on the axis when the blocked width is narrow, else two, each with its
	outer edge at the contour."""
	if w <= BAND_INTERIOR_EPS_M:
		return
	var r: float = minf(BAND_R_M, w)
	var off: float = w - r
	if off < BAND_INTERIOR_EPS_M:
		_add_band(centre, r)
		return
	_add_band(centre + normal * off, r)
	_add_band(centre - normal * off, r)


func _band_circle(seg: PackedInt32Array, ramp_m: float) -> void:
	"""Circles round a pond circle's contour, BAND_STEP_M apart."""
	var centre := Vector2(Rules.to_m(seg[0]), Rules.to_m(seg[1]))
	var w: float = blocked_width_m(Rules.to_m(seg[4]), Rules.to_m(seg[6]), ramp_m)
	if w <= BAND_R_M + BAND_INTERIOR_EPS_M:
		if w > BAND_INTERIOR_EPS_M:
			_add_band(centre, w)
		return
	var ring: float = w - BAND_R_M
	var points: int = maxi(6, ceili(TAU * ring / BAND_STEP_M))
	for k: int in points:
		_add_band(centre + Vector2.from_angle(TAU * float(k) / float(points)) * ring, BAND_R_M)


func _add_band(at: Vector2, radius: float) -> void:
	"""Keep a band circle whose centre lies within the area grown by BAND_BEYOND_M."""
	if area.grow(BAND_BEYOND_M).has_point(at):
		band.append(Vector3(at.x, radius, at.y))


func blocked_margin_m(p: Vector2) -> float:
	"""How far inside the band `p` lies (> 0), or outside it (< 0): the best of every primitive's
	blocked width at its closest axis point less the distance to that point."""
	var best: float = -INF
	for body: int in _map.body_count():
		var range_i: Vector2i = _map.body_segment_range(body)
		var ramp_m: float = Rules.to_m(_map.body_ramp_u(body))
		for i: int in range(range_i.x, range_i.x + range_i.y):
			best = maxf(best, _primitive_margin(_map.segment(i), ramp_m, p))
	return best


func _primitive_margin(seg: PackedInt32Array, ramp_m: float, p: Vector2) -> float:
	"""One primitive's blocked width at the axis point closest to `p`, less the distance to it."""
	var a := Vector2(Rules.to_m(seg[0]), Rules.to_m(seg[1]))
	var b := Vector2(Rules.to_m(seg[2]), Rules.to_m(seg[3]))
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-9 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var w: float = blocked_width_m(lerpf(Rules.to_m(seg[4]), Rules.to_m(seg[5]), t),
		lerpf(Rules.to_m(seg[6]), Rules.to_m(seg[7]), t), ramp_m)
	return w - p.distance_to(a + ab * t)


func _drop_interior() -> void:
	"""Drop every band circle lying wholly inside the band: the boundary alone keeps walkers out."""
	var kept: Array[Vector3] = []
	for circle: Vector3 in band:
		if blocked_margin_m(Vector2(circle.x, circle.z)) < circle.y + BAND_INTERIOR_EPS_M:
			kept.append(circle)
	band = kept


# --- links ---------------------------------------------------------------------------------------

func _add_stream_links() -> void:
	"""A link across every LINK_STRIDE-th measured span too deep to wade."""
	var wade_u: int = Rules.wade_max_u(Rules.MOUSE_HEIGHT_U)
	for s: int in range(0, _map.station_count(), LINK_STRIDE):
		if _map.station_depth_u(s) <= wade_u:
			continue
		var a := Vector2(Rules.to_m(_map.station_a(s).x), Rules.to_m(_map.station_a(s).y))
		var b := Vector2(Rules.to_m(_map.station_b(s).x), Rules.to_m(_map.station_b(s).y))
		if area.has_point((a + b) * 0.5):
			_try_link(a, b, _map.station_body(s), KIND_ACROSS)


func _add_pond_chords() -> void:
	"""Links across each pond along CHORDS chords through its first circle's centre."""
	for body: int in _map.body_count():
		if _map.body_kind(body) != WaterMapScript.KIND_POND:
			continue
		var seg: PackedInt32Array = _map.segment(_map.body_segment_range(body).x)
		var centre := Vector2(Rules.to_m(seg[0]), Rules.to_m(seg[1]))
		for k: int in CHORDS:
			var dir: Vector2 = Vector2.from_angle(PI * float(k) / float(CHORDS))
			var a: Vector2 = _walk_to_dry(centre, dir)
			var b: Vector2 = _walk_to_dry(centre, -dir)
			if a.is_finite() and b.is_finite():
				_try_link(a, b, body, KIND_CHORD)


func _walk_to_dry(from: Vector2, dir: Vector2) -> Vector2:
	"""The first dry point walking from `from` along `dir` in DRY_STEP_M steps (INF: none)."""
	for k: int in DRY_STEPS:
		var at: Vector2 = from + dir * (DRY_STEP_M * float(k))
		if not _map.is_water(_u(at)):
			return at
	return Vector2.INF


func _try_link(a: Vector2, b: Vector2, body: int, kind: int) -> void:
	"""Publish the link a -> b (dry waterline points) when both land ends are clear."""
	var n: Vector2 = (a - b).normalized()
	var land_a: Vector2 = a + n * LAND_SETBACK_M
	var land_b: Vector2 = b - n * LAND_SETBACK_M
	if not land_clear(land_a, a) or not land_clear(land_b, b):
		return
	link_land_a.append(land_a)
	link_water_a.append(a - n * WATER_INSET_M)
	link_water_b.append(b + n * WATER_INSET_M)
	link_land_b.append(land_b)
	link_body.append(body)
	link_kind.append(kind)
	var flow: Vector2i = _map.flow_at(_u((a + b) * 0.5))
	var along: float = (Vector2(flow) * 1000.0 / float(Rules.UNITS_PER_M)).dot(-n)
	var across: float = (Vector2(flow) * 1000.0 / float(Rules.UNITS_PER_M)).dot(n.orthogonal())
	link_flow_along.append(roundi(along))
	link_flow_across.append(roundi(across))
	_add_connection(land_a, a - n * WATER_INSET_M, body)
	_add_connection(land_b, b + n * WATER_INSET_M, body)
	link_count += 1


func land_clear(land: Vector2, shore: Vector2, clear_m: float = LAND_CLEAR_M) -> bool:
	"""Whether a link's (or a landing's) land end is dry, inside the area, clear of every obstacle by
	`clear_m`, and its walk down to the shore passes through none."""
	if not area.has_point(land) or _map.is_water(_u(land)):
		return false
	for o: Vector3 in _obstacles:
		var centre := Vector2(o.x, o.z)
		if centre.distance_to(land) < o.y + clear_m:
			return false
		if _segment_distance(centre, land, shore) < o.y + clear_m * 0.5:
			return false
	return true


func _add_landings() -> void:
	"""Every authored landing whose land point is clear is a connection too (`landing_ok`); one standing
	in a building's footprint (the boathouse's, on the widened ground) is not walked to."""
	landing_ok.resize(_map.landing_count())
	for k: int in _map.landing_count():
		var water: Vector2i = _map.landing_water(k)
		var land: Vector2i = _map.landing_land(k)
		var land_m := Vector2(Rules.to_m(land.x), Rules.to_m(land.y))
		var water_m := Vector2(Rules.to_m(water.x), Rules.to_m(water.y))
		landing_ok[k] = 1 if land_clear(land_m, water_m, LANDING_CLEAR_M) else 0
		if landing_ok[k] == 1:
			_add_connection(land_m, water_m + (water_m - land_m).normalized() * WATER_INSET_M, _map.landing_body(k))


func _add_connection(land: Vector2, water: Vector2, body: int) -> void:
	"""One place a swimmer may enter or leave `body`."""
	conn_land.append(land)
	conn_water.append(water)
	conn_body.append(body)


func nearest_connection_into(at: Vector2, body: int, out: IntMath.IntResult) -> bool:
	"""The connection of `body` whose water end is nearest `at`; refuses when the body has none."""
	var best: int = -1
	var best_d: float = INF
	for k: int in conn_land.size():
		if conn_body[k] == body and conn_water[k].distance_to(at) < best_d:
			best_d = conn_water[k].distance_to(at)
			best = k
	if best < 0:
		return out.refuse("NO_CONNECTION")
	return out.succeed(best)


func connection_for_into(spot: Vector2, from: Vector2, out: IntMath.IntResult) -> bool:
	"""The connection of `spot`'s body best for a resident on land at `from` to reach `spot` by: the
	least straight walk from `from` to its land end plus SWIM_WEIGHT times the straight swim from its
	water end to `spot` (a swim is slower than a walk). Refuses when `spot` is not in the water."""
	if not body_at_into(spot, out):
		return false
	var body: int = out.value
	var best: int = -1
	var best_cost: float = INF
	for k: int in conn_land.size():
		if conn_body[k] != body:
			continue
		var cost: float = from.distance_to(conn_land[k]) + SWIM_WEIGHT * conn_water[k].distance_to(spot)
		if cost < best_cost:
			best_cost = cost
			best = k
	if best < 0:
		return out.refuse("NO_CONNECTION")
	return out.succeed(best)


func body_at_into(at: Vector2, out: IntMath.IntResult) -> bool:
	"""The water body at `at` (the map's); refuses on dry land."""
	return _map.body_at_into(_u(at), out)


func link_length_m(k: int) -> float:
	"""The water part of link `k`, metres."""
	return link_water_a[k].distance_to(link_water_b[k])


func link_bank_m(k: int) -> float:
	"""The bank walks of link `k`, down and up, metres."""
	return link_land_a[k].distance_to(link_water_a[k]) + link_water_b[k].distance_to(link_land_b[k])


static func _u(at: Vector2) -> Vector2i:
	"""A metre point as integer u (the import boundary)."""
	return Vector2i(Rules.to_u(at.x), Rules.to_u(at.y))


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from `p` to the segment a-b."""
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-9 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
