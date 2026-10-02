extends RefCounted
## The water foundation's one query module: where the water is, how deep, which zone, which way it
## flows, where its banks and landings are, where it can be crossed, and whether a tunnel leg would
## pass under it. Decision 0196 (live demo), water foundation. Integer maths throughout (u).
##
## ---------------------------------------------------------------------------------------
## SHAPE. Every body is a union of TAPERED CAPSULE primitives: an axis segment a->b whose radius
## and bed depth vary linearly from (ra, da) at a to (rb, db) at b. A stream is a chain of them
## (`add_stream`: shared vertices, so the joints are round and the channel is continuous); a pond
## is a cluster of circles (`add_pond`: a == b). At a point p each primitive gives the closest
## axis point c(t), the lateral distance d = |p - c|, the radius r(t) and the inside margin
## e = r(t) - d (> 0 in the water). A body's margin is the largest of its primitives', and the
## whole map's the largest of all -- a union. The shoreline is where the margin is 0.
##
## DEPTH is a trapezoid across the channel: 0 at the waterline, rising linearly over the body's
## `ramp_u` to the primitive's bed depth D(t), flat beyond. `ceil` is used, so every point with a
## positive margin has a depth of at least 1 u: `is_water(p) == (depth_at(p) > 0)` exactly.
##
## GROUND. The bank falls linearly from the ground datum (0) at `bank_run_u` outside the waterline
## to the water surface at the waterline, `level_drop_u` below the datum; under water the bed is
## the surface minus the depth. `ground_height_at` is that height, in u (<= 0). The terrain mesh
## and phase 2's walkers read it; the surface itself is `level_drop_u` below the datum.
##
## FLOW. A stream flows from its first vertex to its last, along the axis of the primitive whose
## margin wins at the point, at the body's speed; a pond is still. `flow_at` returns u/s.
##
## BANKS AND LANDINGS. `finalize()` samples the union's shoreline once: points on every
## primitive's surface that lie inside no other primitive (to SHORE_TOLERANCE_U). The samples are
## the published water edge (`shore_point`), `nearest_bank` scans them, and each authored landing
## (`add_landing`) snaps to its nearest sample, with a dry land point `setback` beyond it along the
## outward normal -- TRV-W02's "Enter/exit only at validated bank connections" needs exactly such
## endpoints, and REQ-SET-054's rescue happens at "the expedition's bank landing point".
##
## CROSSINGS. `finalize()` also walks every stream in CROSSING_STEP_U stations, measures the span
## bank to bank perpendicular to the flow and its deepest point, and publishes candidates: FORDS
## (the narrowest station of each run whose depth a mouse still wades, TRV-W01) and BRIDGES (the
## narrowest stations overall, at least CROSSING_GAP_U apart along the stream) -- where phase 2's
## beaver would build first.
##
## TUNNELS. `segment_crosses_water(a, b, clearance_u)` is true when the segment comes within
## `clearance_u` of any primitive's widest radius -- conservative for a taper, exact for a circle.
## No tunnel may pass under water; the tunnel code calls this with half a bore of clearance.
##
## ALLOCATION. Every packed column is sized once in `_init`; queries allocate nothing (results go
## into caller-owned `Bank` / `IntMath.IntResult` objects). Refusals are StringName codes on
## IntResult, never a sentinel value.

const Rules := preload("res://demo/water/water_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const KIND_STREAM: int = 0
const KIND_POND: int = 1

const MAX_BODIES: int = 8
const MAX_SEGMENTS: int = 64
const MAX_SHORE: int = 8192
const MAX_STATIONS: int = 2048
const MAX_CROSSINGS: int = 16
const MAX_LANDINGS: int = 16
const MAX_BRIDGES: int = 4

## Shoreline sampling: spacing along a straight edge, and how far inside ANOTHER primitive a
## surface sample may sit and still count as shore (integer rounding at the joins).
const SHORE_STEP_U: int = 384
const SHORE_TOLERANCE_U: int = 16
## Crossing stations every half metre; chosen bridges at least 6 m apart along the stream.
const CROSSING_STEP_U: int = 512
const CROSSING_GAP_U: int = 6144
## A span end or a landing is walked outward in these steps until it is dry.
const PUSH_STEP_U: int = 64
const PUSH_STEPS: int = 64
## No water within this distance is reported as exactly this far (a clamp, not a failure).
const FAR_U: int = 65536

const CROSSING_FORD: int = 0
const CROSSING_BRIDGE: int = 1

const REFUSE_FINALIZED: StringName = &"WATER_MAP_FINALIZED"
const REFUSE_NOT_FINALIZED: StringName = &"WATER_MAP_NOT_FINALIZED"
const REFUSE_BODY_CAPACITY: StringName = &"WATER_BODY_CAPACITY"
const REFUSE_SEGMENT_CAPACITY: StringName = &"WATER_SEGMENT_CAPACITY"
const REFUSE_LANDING_CAPACITY: StringName = &"WATER_LANDING_CAPACITY"
const REFUSE_SHAPE: StringName = &"WATER_SHAPE"
const REFUSE_VALUE: StringName = &"WATER_VALUE"
const REFUSE_EMPTY: StringName = &"WATER_EMPTY"
const REFUSE_DRY: StringName = &"WATER_DRY"
const REFUSE_BODY_HEIGHT: StringName = &"WATER_BODY_HEIGHT"
const REFUSE_NO_SHORE: StringName = &"WATER_NO_SHORE"
const REFUSE_UNKNOWN_LANDING: StringName = &"WATER_UNKNOWN_LANDING"
const REFUSE_LANDING_UNRESOLVED: StringName = &"WATER_LANDING_UNRESOLVED"


class Sample:
	"""A caller-owned answer to `sample_into`: everything the field says about one point at once."""
	var margin_u: int = 0
	var depth_u: int = 0
	var body: int = 0
	var ground_u: int = 0
	var flow: Vector2i = Vector2i.ZERO


class Bank:
	"""A caller-owned answer to `nearest_bank`: a waterline point, its body and the distance to it."""
	var x: int = 0
	var z: int = 0
	var body: int = 0
	var distance_u: int = 0

	func point() -> Vector2i:
		"""The bank point as (x, z) in u."""
		return Vector2i(x, z)


var _bank_run_u: int = 0
var _finalized: bool = false

var _body_count: int = 0
var _body_kind: PackedInt32Array = PackedInt32Array()
var _body_drop: PackedInt32Array = PackedInt32Array()
var _body_ramp: PackedInt32Array = PackedInt32Array()
var _body_speed: PackedInt32Array = PackedInt32Array()
var _body_first: PackedInt32Array = PackedInt32Array()
var _body_segments: PackedInt32Array = PackedInt32Array()
var _body_name: Array[StringName] = []

var _seg_count: int = 0
var _seg_body: PackedInt32Array = PackedInt32Array()
var _ax: PackedInt32Array = PackedInt32Array()
var _az: PackedInt32Array = PackedInt32Array()
var _bx: PackedInt32Array = PackedInt32Array()
var _bz: PackedInt32Array = PackedInt32Array()
var _ra: PackedInt32Array = PackedInt32Array()
var _rb: PackedInt32Array = PackedInt32Array()
var _da: PackedInt32Array = PackedInt32Array()
var _db: PackedInt32Array = PackedInt32Array()
## Each primitive's bounds grown by its widest radius and the bank run: outside all of them the
## ground is flat and dry (`is_near_water`).
var _near_min_x: PackedInt32Array = PackedInt32Array()
var _near_max_x: PackedInt32Array = PackedInt32Array()
var _near_min_z: PackedInt32Array = PackedInt32Array()
var _near_max_z: PackedInt32Array = PackedInt32Array()

var _shore_count: int = 0
var _shore_x: PackedInt32Array = PackedInt32Array()
var _shore_z: PackedInt32Array = PackedInt32Array()
var _shore_body: PackedInt32Array = PackedInt32Array()

var _station_count: int = 0
var _st_ax: PackedInt32Array = PackedInt32Array()
var _st_az: PackedInt32Array = PackedInt32Array()
var _st_bx: PackedInt32Array = PackedInt32Array()
var _st_bz: PackedInt32Array = PackedInt32Array()
var _st_width: PackedInt32Array = PackedInt32Array()
var _st_depth: PackedInt32Array = PackedInt32Array()
var _st_along: PackedInt32Array = PackedInt32Array()
var _st_body: PackedInt32Array = PackedInt32Array()
var _st_taken: PackedByteArray = PackedByteArray()

var _crossing_count: int = 0
var _cr_station: PackedInt32Array = PackedInt32Array()
var _cr_kind: PackedInt32Array = PackedInt32Array()

var _landing_count: int = 0
var _landing_name: Array[StringName] = []
var _landing_near_x: PackedInt32Array = PackedInt32Array()
var _landing_near_z: PackedInt32Array = PackedInt32Array()
var _landing_setback: PackedInt32Array = PackedInt32Array()
var _landing_water_x: PackedInt32Array = PackedInt32Array()
var _landing_water_z: PackedInt32Array = PackedInt32Array()
var _landing_land_x: PackedInt32Array = PackedInt32Array()
var _landing_land_z: PackedInt32Array = PackedInt32Array()
var _landing_body: PackedInt32Array = PackedInt32Array()
var _landing_resolved: PackedByteArray = PackedByteArray()

## Scratch of the last single-primitive evaluation (`_eval_segment`).
var _ev_e: int = 0
var _ev_depth: int = 0
var _ev_cx: int = 0
var _ev_cz: int = 0
## Scratch of the last whole-map evaluation (`_field`): the winning margin, its primitive and
## closest axis point, and the deepest water of any primitive.
var _f_e: int = 0
var _f_seg: int = 0
var _f_cx: int = 0
var _f_cz: int = 0
var _f_depth: int = 0
var _bank_scratch: Bank = Bank.new()
var _pick: IntMath.IntResult = IntMath.IntResult.new()
var _walk_x: int = 0
var _walk_z: int = 0


func _init(run_u: int) -> void:
	"""Allocate every column once. `run_u` (> 0) is how far outside the waterline the bank
	starts to fall towards the water."""
	assert(run_u > 0, "the bank needs a positive run")
	_bank_run_u = run_u
	_allocate_bodies()
	_allocate_stations()
	_allocate_landings()


func _allocate_bodies() -> void:
	"""Size the body, primitive and shore columns once. (Packed arrays are values: each member is
	resized by name, never through a loop variable, which would resize a copy.)"""
	_body_kind.resize(MAX_BODIES)
	_body_drop.resize(MAX_BODIES)
	_body_ramp.resize(MAX_BODIES)
	_body_speed.resize(MAX_BODIES)
	_body_first.resize(MAX_BODIES)
	_body_segments.resize(MAX_BODIES)
	_body_name.resize(MAX_BODIES)
	_seg_body.resize(MAX_SEGMENTS)
	_ax.resize(MAX_SEGMENTS)
	_az.resize(MAX_SEGMENTS)
	_bx.resize(MAX_SEGMENTS)
	_bz.resize(MAX_SEGMENTS)
	_ra.resize(MAX_SEGMENTS)
	_rb.resize(MAX_SEGMENTS)
	_da.resize(MAX_SEGMENTS)
	_db.resize(MAX_SEGMENTS)
	_near_min_x.resize(MAX_SEGMENTS)
	_near_max_x.resize(MAX_SEGMENTS)
	_near_min_z.resize(MAX_SEGMENTS)
	_near_max_z.resize(MAX_SEGMENTS)
	_shore_x.resize(MAX_SHORE)
	_shore_z.resize(MAX_SHORE)
	_shore_body.resize(MAX_SHORE)


func _allocate_stations() -> void:
	"""Size the crossing-station and crossing columns once."""
	_st_ax.resize(MAX_STATIONS)
	_st_az.resize(MAX_STATIONS)
	_st_bx.resize(MAX_STATIONS)
	_st_bz.resize(MAX_STATIONS)
	_st_width.resize(MAX_STATIONS)
	_st_depth.resize(MAX_STATIONS)
	_st_along.resize(MAX_STATIONS)
	_st_body.resize(MAX_STATIONS)
	_st_taken.resize(MAX_STATIONS)
	_cr_station.resize(MAX_CROSSINGS)
	_cr_kind.resize(MAX_CROSSINGS)


func _allocate_landings() -> void:
	"""Size the landing columns once."""
	_landing_name.resize(MAX_LANDINGS)
	_landing_near_x.resize(MAX_LANDINGS)
	_landing_near_z.resize(MAX_LANDINGS)
	_landing_setback.resize(MAX_LANDINGS)
	_landing_water_x.resize(MAX_LANDINGS)
	_landing_water_z.resize(MAX_LANDINGS)
	_landing_land_x.resize(MAX_LANDINGS)
	_landing_land_z.resize(MAX_LANDINGS)
	_landing_body.resize(MAX_LANDINGS)
	_landing_resolved.resize(MAX_LANDINGS)


# --- authoring ---------------------------------------------------------------------------------

func add_stream(name: StringName, vertices: PackedInt32Array, level_drop_u: int, ramp_u: int,
		flow_speed_u_s: int) -> IntMath.IntResult:
	"""Add a stream: `vertices` are (x, z, half_width, bed_depth) quads in u, upstream first, at
	least two. Returns the body index, or refuses (nothing is added) on a bad shape or value."""
	var out := IntMath.IntResult.new()
	var code: StringName = _refuse_body(vertices, level_drop_u, ramp_u, flow_speed_u_s)
	if code == &"" and vertices.size() < 8:
		code = REFUSE_SHAPE
	@warning_ignore("integer_division") if code == &"" and _seg_count + vertices.size() / 4 - 1 > MAX_SEGMENTS:
		code = REFUSE_SEGMENT_CAPACITY
	if code == &"" and not _stream_legs_ok(vertices):
		code = REFUSE_SHAPE
	if code != &"":
		out.refuse(String(code))
		return out
	var body: int = _open_body(name, KIND_STREAM, level_drop_u, ramp_u, flow_speed_u_s)
	@warning_ignore("integer_division") for k: int in range(1, vertices.size() / 4):
		var a: int = (k - 1) * 4
		var b: int = k * 4
		_append_segment(body, vertices[a], vertices[a + 1], vertices[b], vertices[b + 1],
			vertices[a + 2], vertices[b + 2], vertices[a + 3], vertices[b + 3])
	out.succeed(body)
	return out


func add_pond(name: StringName, circles: PackedInt32Array, level_drop_u: int,
		ramp_u: int) -> IntMath.IntResult:
	"""Add a still pond: `circles` are (x, z, radius, bed_depth) quads in u, at least one. Returns
	the body index, or refuses (nothing is added) on a bad shape or value."""
	var out := IntMath.IntResult.new()
	var code: StringName = _refuse_body(circles, level_drop_u, ramp_u, 0)
	if code == &"" and circles.size() < 4:
		code = REFUSE_SHAPE
	@warning_ignore("integer_division") if code == &"" and _seg_count + circles.size() / 4 > MAX_SEGMENTS:
		code = REFUSE_SEGMENT_CAPACITY
	if code != &"":
		out.refuse(String(code))
		return out
	var body: int = _open_body(name, KIND_POND, level_drop_u, ramp_u, 0)
	@warning_ignore("integer_division") for k: int in circles.size() / 4:
		var c: int = k * 4
		_append_segment(body, circles[c], circles[c + 1], circles[c], circles[c + 1],
			circles[c + 2], circles[c + 2], circles[c + 3], circles[c + 3])
	out.succeed(body)
	return out


func _refuse_body(quads: PackedInt32Array, level_drop_u: int, ramp_u: int,
		flow_speed_u_s: int) -> StringName:
	"""The code blocking a new body, or &"" when it may be added."""
	if _finalized:
		return REFUSE_FINALIZED
	if _body_count >= MAX_BODIES:
		return REFUSE_BODY_CAPACITY
	if quads.size() % 4 != 0:
		return REFUSE_SHAPE
	if level_drop_u < 0 or ramp_u <= 0 or flow_speed_u_s < 0:
		return REFUSE_VALUE
	@warning_ignore("integer_division") for k: int in quads.size() / 4:
		if quads[k * 4 + 2] <= 0 or quads[k * 4 + 3] <= 0:
			return REFUSE_VALUE
	return &""


func _stream_legs_ok(vertices: PackedInt32Array) -> bool:
	"""Every leg of a stream has a length: no two consecutive vertices coincide."""
	@warning_ignore("integer_division") for k: int in range(1, vertices.size() / 4):
		if vertices[k * 4] == vertices[k * 4 - 4] and vertices[k * 4 + 1] == vertices[k * 4 - 3]:
			return false
	return true


func _open_body(name: StringName, kind: int, level_drop_u: int, ramp_u: int,
		flow_speed_u_s: int) -> int:
	"""Write a validated body's columns and return its index."""
	var body: int = _body_count
	_body_kind[body] = kind
	_body_drop[body] = level_drop_u
	_body_ramp[body] = ramp_u
	_body_speed[body] = flow_speed_u_s
	_body_first[body] = _seg_count
	_body_segments[body] = 0
	_body_name[body] = name
	_body_count += 1
	return body


func _append_segment(body: int, ax: int, az: int, bx: int, bz: int, ra: int, rb: int, da: int,
		db: int) -> void:
	"""Write one validated primitive's columns."""
	var i: int = _seg_count
	_seg_body[i] = body
	_ax[i] = ax
	_az[i] = az
	_bx[i] = bx
	_bz[i] = bz
	_ra[i] = ra
	_rb[i] = rb
	_da[i] = da
	_db[i] = db
	var reach: int = maxi(ra, rb) + _bank_run_u
	_near_min_x[i] = mini(ax, bx) - reach
	_near_max_x[i] = maxi(ax, bx) + reach
	_near_min_z[i] = mini(az, bz) - reach
	_near_max_z[i] = maxi(az, bz) + reach
	_body_segments[body] += 1
	_seg_count += 1


func add_landing(name: StringName, near: Vector2i, setback_u: int) -> IntMath.IntResult:
	"""Author a bank landing near `near`: at `finalize()` it snaps to the nearest shore sample, with
	a dry land point `setback_u` (> 0) beyond it. Returns the landing index, or refuses."""
	var out := IntMath.IntResult.new()
	if _finalized:
		out.refuse(String(REFUSE_FINALIZED))
	elif _landing_count >= MAX_LANDINGS:
		out.refuse(String(REFUSE_LANDING_CAPACITY))
	elif setback_u <= 0 or _has_landing(name):
		out.refuse(String(REFUSE_VALUE))
	else:
		var k: int = _landing_count
		_landing_name[k] = name
		_landing_near_x[k] = near.x
		_landing_near_z[k] = near.y
		_landing_setback[k] = setback_u
		_landing_count += 1
		out.succeed(k)
	return out


func _has_landing(name: StringName) -> bool:
	"""Whether a landing called `name` was already authored."""
	for k: int in _landing_count:
		if _landing_name[k] == name:
			return true
	return false


func finalize() -> IntMath.IntResult:
	"""Sample the shoreline, measure the crossings and resolve the landings, once. Returns how many
	shore samples were taken; refuses when already finalised, when there is no water, and when a
	landing's land point finds no dry ground (an authoring error: the map is then not finalised)."""
	var out := IntMath.IntResult.new()
	if _finalized:
		out.refuse(String(REFUSE_FINALIZED))
		return out
	if _seg_count == 0:
		out.refuse(String(REFUSE_EMPTY))
		return out
	_sample_shore()
	if _shore_count == 0:
		out.refuse(String(REFUSE_NO_SHORE))
		return out
	_measure_stations()
	_choose_crossings()
	_resolve_landings()
	for k: int in _landing_count:
		if _landing_resolved[k] != 1:
			out.refuse(String(REFUSE_LANDING_UNRESOLVED))
			return out
	_finalized = true
	out.succeed(_shore_count)
	return out


func is_finalized() -> bool:
	"""Whether `finalize()` has run: shore, crossings and landings are published."""
	return _finalized


# --- bodies ------------------------------------------------------------------------------------

func body_count() -> int:
	"""How many water bodies the map holds."""
	return _body_count


func body_kind(body: int) -> int:
	"""KIND_STREAM or KIND_POND for a valid body index."""
	return _body_kind[body]


func body_name(body: int) -> StringName:
	"""The authored name of a valid body index."""
	return _body_name[body]


func body_level_drop_u(body: int) -> int:
	"""How far below the ground datum a valid body's surface lies, in u."""
	return _body_drop[body]


func body_flow_speed_u_s(body: int) -> int:
	"""A valid body's flow speed in u/s (0 for a pond)."""
	return _body_speed[body]


func body_ramp_u(body: int) -> int:
	"""How far in from its waterline a valid body reaches its full bed depth, in u."""
	return _body_ramp[body]


func body_segment_range(body: int) -> Vector2i:
	"""(first primitive, primitive count) of a valid body."""
	return Vector2i(_body_first[body], _body_segments[body])


func segment_count() -> int:
	"""How many capsule primitives the map holds."""
	return _seg_count


func segment(i: int) -> PackedInt32Array:
	"""Primitive `i` as (ax, az, bx, bz, ra, rb, da, db) -- a fresh array, for drawing only."""
	return PackedInt32Array([_ax[i], _az[i], _bx[i], _bz[i], _ra[i], _rb[i], _da[i], _db[i]])


func bank_run_u() -> int:
	"""How far outside the waterline the bank starts to fall, in u."""
	return _bank_run_u


# --- the field ---------------------------------------------------------------------------------

func _eval_segment(i: int, px: int, pz: int) -> void:
	"""Primitive `i` at (px, pz): its closest axis point, inside margin and trapezoid depth."""
	var dx: int = _bx[i] - _ax[i]
	var dz: int = _bz[i] - _az[i]
	var den: int = dx * dx + dz * dz
	var num: int = 0
	if den > 0:
		num = clampi((px - _ax[i]) * dx + (pz - _az[i]) * dz, 0, den)
	else:
		den = 1
	@warning_ignore("integer_division") _ev_cx = _ax[i] + dx * num / den
	@warning_ignore("integer_division") _ev_cz = _az[i] + dz * num / den
	var ex: int = px - _ev_cx
	var ez: int = pz - _ev_cz
	@warning_ignore("integer_division") var radius: int = _ra[i] + (_rb[i] - _ra[i]) * num / den
	_ev_e = radius - Rules.isqrt(ex * ex + ez * ez)
	_ev_depth = 0
	if _ev_e > 0:
		@warning_ignore("integer_division") var full: int = _da[i] + (_db[i] - _da[i]) * num / den
		var ramp: int = _body_ramp[_seg_body[i]]
		_ev_depth = Rules.ceil_div(full * mini(_ev_e, ramp), ramp)


func _field(px: int, pz: int) -> void:
	"""The whole map at (px, pz): the winning margin (lowest primitive index on a tie), its closest
	axis point, and the deepest water any primitive gives. Requires at least one primitive."""
	_f_depth = 0
	for i: int in _seg_count:
		_eval_segment(i, px, pz)
		if i == 0 or _ev_e > _f_e:
			_f_e = _ev_e
			_f_seg = i
			_f_cx = _ev_cx
			_f_cz = _ev_cz
		_f_depth = maxi(_f_depth, _ev_depth)


func inside_margin_u(p: Vector2i) -> int:
	"""How far inside the water `p` is (> 0), or how far outside (< 0), clamped to +-FAR_U."""
	if _seg_count == 0:
		return -FAR_U
	_field(p.x, p.y)
	return clampi(_f_e, -FAR_U, FAR_U)


func depth_at(p: Vector2i) -> int:
	"""Water depth at `p` in u, surface to bed; 0 on dry land (a true answer, not a failure)."""
	if _seg_count == 0:
		return 0
	_field(p.x, p.y)
	return _f_depth


func is_water(p: Vector2i) -> bool:
	"""Whether `p` is in any water body (exactly: depth_at(p) > 0)."""
	return depth_at(p) > 0


func zone_at(p: Vector2i) -> int:
	"""Rules.ZONE_* at `p` for the 1.0 m mouse anchor (water_rules.gd's demo thresholds)."""
	return Rules.zone_for_depth(depth_at(p), Rules.MOUSE_HEIGHT_U)


func zone_for_body_into(p: Vector2i, body_height_u: int, out: IntMath.IntResult) -> bool:
	"""Rules.ZONE_* at `p` for a body `body_height_u` tall; refuses a height that is not positive."""
	if body_height_u <= 0:
		return out.refuse(String(REFUSE_BODY_HEIGHT))
	return out.succeed(Rules.zone_for_depth(depth_at(p), body_height_u))


func body_at_into(p: Vector2i, out: IntMath.IntResult) -> bool:
	"""The body whose water `p` is in (the one with the greatest margin); refuses on dry land."""
	if _seg_count == 0:
		return out.refuse(String(REFUSE_DRY))
	_field(p.x, p.y)
	if _f_e <= 0:
		return out.refuse(String(REFUSE_DRY))
	return out.succeed(_seg_body[_f_seg])


func ground_height_at(p: Vector2i) -> int:
	"""Ground (or bed) height at `p` relative to the ground datum, in u (<= 0): flat beyond the bank,
	a linear bank down to the surface at the waterline, the bed below the surface in the water."""
	if not is_near_water(p):
		return 0
	_field(p.x, p.y)
	return _ground_from_field()


func flow_at(p: Vector2i) -> Vector2i:
	"""Surface flow at `p` in u/s: along the winning stream primitive's axis, downstream, at its
	body's speed. Zero on dry land and on a pond (still water) -- both true answers."""
	if _seg_count == 0:
		return Vector2i.ZERO
	_field(p.x, p.y)
	return _flow_from_field()


func is_near_water(p: Vector2i) -> bool:
	"""Whether `p` lies within some primitive's widest radius plus the bank run of its axis bounds.
	False means flat, dry ground for certain; true means "evaluate the field"."""
	for i: int in _seg_count:
		if p.x >= _near_min_x[i] and p.x <= _near_max_x[i] \
				and p.y >= _near_min_z[i] and p.y <= _near_max_z[i]:
			return true
	return false


func sample_into(p: Vector2i, out: Sample) -> bool:
	"""Margin, depth, winning body, ground height and flow at `p`, from ONE field evaluation, into
	`out`; false (nothing written) on a map with no water."""
	if _seg_count == 0:
		return false
	_field(p.x, p.y)
	out.margin_u = clampi(_f_e, -FAR_U, FAR_U)
	out.depth_u = _f_depth
	out.body = _seg_body[_f_seg]
	out.ground_u = _ground_from_field()
	out.flow = _flow_from_field()
	return true


func _ground_from_field() -> int:
	"""`ground_height_at` for the point `_field` last evaluated."""
	var drop: int = _body_drop[_seg_body[_f_seg]]
	if _f_e > 0:
		return -(drop + _f_depth)
	if _f_e > -_bank_run_u:
		@warning_ignore("integer_division") return -(drop * (_bank_run_u + _f_e) / _bank_run_u)
	return 0


func _flow_from_field() -> Vector2i:
	"""`flow_at` for the point `_field` last evaluated."""
	var body: int = _seg_body[_f_seg]
	if _f_e <= 0 or _body_kind[body] != KIND_STREAM:
		return Vector2i.ZERO
	var dx: int = _bx[_f_seg] - _ax[_f_seg]
	var dz: int = _bz[_f_seg] - _az[_f_seg]
	var length: int = Rules.isqrt(dx * dx + dz * dz)
	var speed: int = _body_speed[body]
	@warning_ignore("integer_division") return Vector2i(dx * speed / length, dz * speed / length)


# --- banks and edges ---------------------------------------------------------------------------

func nearest_bank(p: Vector2i, out: Bank) -> bool:
	"""The shore sample nearest `p` (the lowest index on a tie) into `out`; false before finalize."""
	if _shore_count == 0:
		return false
	var best: int = 0
	var best_sq: int = 0
	for k: int in _shore_count:
		var dx: int = _shore_x[k] - p.x
		var dz: int = _shore_z[k] - p.y
		var sq: int = dx * dx + dz * dz
		if k == 0 or sq < best_sq:
			best = k
			best_sq = sq
	out.x = _shore_x[best]
	out.z = _shore_z[best]
	out.body = _shore_body[best]
	out.distance_u = Rules.isqrt(best_sq)
	return true


func shore_count() -> int:
	"""How many waterline samples the map published (0 before finalize)."""
	return _shore_count


func shore_point(k: int) -> Vector2i:
	"""Waterline sample `k` as (x, z) in u."""
	return Vector2i(_shore_x[k], _shore_z[k])


func shore_body(k: int) -> int:
	"""The body waterline sample `k` belongs to."""
	return _shore_body[k]


func _sample_shore() -> void:
	"""Take every primitive's surface samples that lie inside no other primitive."""
	_shore_count = 0
	for i: int in _seg_count:
		if _ax[i] == _bx[i] and _az[i] == _bz[i]:
			_sample_cap(i, _ax[i], _az[i], _ra[i], 0, 0)
			continue
		_sample_edges(i)
		_sample_cap(i, _ax[i], _az[i], _ra[i], _ax[i] - _bx[i], _az[i] - _bz[i])
		_sample_cap(i, _bx[i], _bz[i], _rb[i], _bx[i] - _ax[i], _bz[i] - _az[i])


func _sample_edges(i: int) -> void:
	"""Samples along both lateral edges of primitive `i`, SHORE_STEP_U apart."""
	var dx: int = _bx[i] - _ax[i]
	var dz: int = _bz[i] - _az[i]
	var length: int = Rules.isqrt(dx * dx + dz * dz)
	var steps: int = maxi(1, Rules.ceil_div(length, SHORE_STEP_U))
	for k: int in steps + 1:
		@warning_ignore("integer_division") var cx: int = _ax[i] + dx * k / steps
		@warning_ignore("integer_division") var cz: int = _az[i] + dz * k / steps
		@warning_ignore("integer_division") var radius: int = _ra[i] + (_rb[i] - _ra[i]) * k / steps
		@warning_ignore("integer_division") var ox: int = -dz * radius / length
		@warning_ignore("integer_division") var oz: int = dx * radius / length
		_try_shore(cx + ox, cz + oz, _seg_body[i])
		_try_shore(cx - ox, cz - oz, _seg_body[i])


func _sample_cap(i: int, cx: int, cz: int, radius: int, away_x: int, away_z: int) -> void:
	"""Samples round an end cap of primitive `i`, on the side facing (away_x, away_z) -- or the
	whole circle when that direction is zero."""
	for k: int in Rules.DIRECTION_COUNT:
		var ux: int = Rules.DIRECTIONS_1024[k * 2]
		var uz: int = Rules.DIRECTIONS_1024[k * 2 + 1]
		if ux * away_x + uz * away_z < 0:
			continue
		@warning_ignore("integer_division") _try_shore(cx + ux * radius / Rules.DIRECTION_SCALE,
			cz + uz * radius / Rules.DIRECTION_SCALE, _seg_body[i])


func _try_shore(x: int, z: int, body: int) -> void:
	"""Keep (x, z) as a shore sample of `body` unless another primitive contains it."""
	if _shore_count >= MAX_SHORE:
		return
	for j: int in _seg_count:
		_eval_segment(j, x, z)
		if _ev_e > SHORE_TOLERANCE_U:
			return
	_shore_x[_shore_count] = x
	_shore_z[_shore_count] = z
	_shore_body[_shore_count] = body
	_shore_count += 1


# --- crossings ---------------------------------------------------------------------------------

func _measure_stations() -> void:
	"""Measure every stream's span, bank to bank, every CROSSING_STEP_U along its axis."""
	_station_count = 0
	for body: int in _body_count:
		if _body_kind[body] != KIND_STREAM:
			continue
		var along: int = 0
		for i: int in range(_body_first[body], _body_first[body] + _body_segments[body]):
			var dx: int = _bx[i] - _ax[i]
			var dz: int = _bz[i] - _az[i]
			var length: int = Rules.isqrt(dx * dx + dz * dz)
			var steps: int = maxi(1, Rules.ceil_div(length, CROSSING_STEP_U))
			for k: int in steps:
				@warning_ignore("integer_division") _measure_station(body, i, dx * k / steps, dz * k / steps, length,
					along + length * k / steps)
			along += length


func _measure_station(body: int, i: int, off_x: int, off_z: int, length: int, along: int) -> void:
	"""One span across primitive `i` at axis offset (off_x, off_z), both ends walked out until dry;
	a span whose ends never reach dry land (inside a pond) is not a crossing and is dropped."""
	if _station_count >= MAX_STATIONS:
		return
	var cx: int = _ax[i] + off_x
	var cz: int = _az[i] + off_z
	var nx: int = -(_bz[i] - _az[i])
	var nz: int = _bx[i] - _ax[i]
	if not _walk_dry(cx, cz, nx, nz, length):
		return
	var a := Vector2i(_walk_x, _walk_z)
	if not _walk_dry(cx, cz, -nx, -nz, length):
		return
	var b := Vector2i(_walk_x, _walk_z)
	var s: int = _station_count
	_st_ax[s] = a.x
	_st_az[s] = a.y
	_st_bx[s] = b.x
	_st_bz[s] = b.y
	_st_width[s] = Rules.isqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
	_st_depth[s] = depth_at(Vector2i(cx, cz))
	_st_along[s] = along
	_st_body[s] = body
	_st_taken[s] = 0
	_station_count += 1


func _walk_dry(cx: int, cz: int, nx: int, nz: int, length: int) -> bool:
	"""Walk from (cx, cz) along (nx, nz)/length in PUSH_STEP_U steps to the first dry point, then
	bisect back to within 1 u of the waterline; the dry point is left in (_walk_x, _walk_z). False
	when no dry point is found within PUSH_STEPS steps. (cx, cz) itself counts."""
	for k: int in PUSH_STEPS + 1:
		if _dry_at_distance(cx, cz, nx, nz, length, k * PUSH_STEP_U):
			if k > 0:
				_bisect_dry(cx, cz, nx, nz, length, (k - 1) * PUSH_STEP_U, k * PUSH_STEP_U)
			return true
	return false


func _bisect_dry(cx: int, cz: int, nx: int, nz: int, length: int, wet_t: int, dry_t: int) -> void:
	"""Narrow a wet/dry bracket along the walk to 1 u and leave its dry end in (_walk_x, _walk_z)."""
	var lo: int = wet_t
	var hi: int = dry_t
	while hi - lo > 1:
		@warning_ignore("integer_division") var mid: int = (lo + hi) / 2
		if _dry_at_distance(cx, cz, nx, nz, length, mid):
			hi = mid
		else:
			lo = mid
	_dry_at_distance(cx, cz, nx, nz, length, hi)


func _dry_at_distance(cx: int, cz: int, nx: int, nz: int, length: int, t: int) -> bool:
	"""Whether the point `t` u from (cx, cz) along (nx, nz)/length is dry; it is left in
	(_walk_x, _walk_z)."""
	@warning_ignore("integer_division") _walk_x = cx + nx * t / length
	@warning_ignore("integer_division") _walk_z = cz + nz * t / length
	_field(_walk_x, _walk_z)
	return _f_e <= 0


func _choose_crossings() -> void:
	"""Fords first -- the narrowest station of each wadeable run -- then up to MAX_BRIDGES of the
	narrowest stations overall, each at least CROSSING_GAP_U along the stream from the others."""
	_crossing_count = 0
	var wade: int = Rules.wade_max_u(Rules.MOUSE_HEIGHT_U)
	var run_best: int = -1
	for s: int in _station_count:
		var wadeable: bool = _st_depth[s] <= wade
		var same_run: bool = s > 0 and _st_body[s] == _st_body[s - 1] and _st_depth[s - 1] <= wade
		if run_best >= 0 and not (wadeable and same_run):
			_publish_crossing(run_best, CROSSING_FORD)
			run_best = -1
		if wadeable and (run_best < 0 or _st_width[s] < _st_width[run_best]):
			run_best = s
	if run_best >= 0:
		_publish_crossing(run_best, CROSSING_FORD)
	for pick: int in MAX_BRIDGES:
		if not _narrowest_free_station_into(_pick):
			return
		_publish_crossing(_pick.value, CROSSING_BRIDGE)


func _narrowest_free_station_into(out: IntMath.IntResult) -> bool:
	"""The narrowest station no crossing has claimed and no bridge lies within CROSSING_GAP_U of
	(the earliest on a tie); refuses when every station is claimed or too close to a bridge."""
	var found: bool = false
	var best: int = 0
	for s: int in _station_count:
		if _st_taken[s] == 1 or _near_a_bridge(s):
			continue
		if not found or _st_width[s] < _st_width[best]:
			best = s
			found = true
	if not found:
		return out.refuse(String(REFUSE_EMPTY))
	return out.succeed(best)


func _near_a_bridge(s: int) -> bool:
	"""Whether station `s` is within CROSSING_GAP_U, on the same body, of a chosen bridge."""
	for c: int in _crossing_count:
		var t: int = _cr_station[c]
		if _cr_kind[c] == CROSSING_BRIDGE and _st_body[t] == _st_body[s] \
				and absi(_st_along[t] - _st_along[s]) < CROSSING_GAP_U:
			return true
	return false


func _publish_crossing(s: int, kind: int) -> void:
	"""Record station `s` as a crossing candidate of `kind`."""
	if _crossing_count >= MAX_CROSSINGS:
		return
	_cr_station[_crossing_count] = s
	_cr_kind[_crossing_count] = kind
	_st_taken[s] = 1
	_crossing_count += 1


func stream_width_at_into(p: Vector2i, out: IntMath.IntResult) -> bool:
	"""The bank-to-bank width of the measured station whose span midpoint is nearest `p`, in u --
	e.g. whether a weir there meets GDD §5.4's "flow 4-12 m wide". Refuses when no stream was
	measured (before finalize, or a map without streams)."""
	if _station_count == 0:
		return out.refuse(String(REFUSE_EMPTY))
	var best: int = 0
	var best_sq: int = 0
	for s: int in _station_count:
		@warning_ignore("integer_division") var dx: int = (_st_ax[s] + _st_bx[s]) / 2 - p.x
		@warning_ignore("integer_division") var dz: int = (_st_az[s] + _st_bz[s]) / 2 - p.y
		var sq: int = dx * dx + dz * dz
		if s == 0 or sq < best_sq:
			best = s
			best_sq = sq
	return out.succeed(_st_width[best])


func crossing_count() -> int:
	"""How many crossing candidates were published: fords first, then bridges narrowest first."""
	return _crossing_count


func crossing_kind(c: int) -> int:
	"""CROSSING_FORD or CROSSING_BRIDGE."""
	return _cr_kind[c]


func crossing_a(c: int) -> Vector2i:
	"""One dry bank end of crossing `c`, in u."""
	return Vector2i(_st_ax[_cr_station[c]], _st_az[_cr_station[c]])


func crossing_b(c: int) -> Vector2i:
	"""The other dry bank end of crossing `c`, in u."""
	return Vector2i(_st_bx[_cr_station[c]], _st_bz[_cr_station[c]])


func crossing_width_u(c: int) -> int:
	"""Bank-to-bank length of crossing `c`, in u."""
	return _st_width[_cr_station[c]]


func crossing_depth_u(c: int) -> int:
	"""The water depth on the axis of crossing `c` (the deepest point of a trapezoid), in u."""
	return _st_depth[_cr_station[c]]


func crossing_body(c: int) -> int:
	"""The stream crossing `c` spans."""
	return _st_body[_cr_station[c]]


func crossing_along_u(c: int) -> int:
	"""How far downstream from its stream's first vertex crossing `c` lies, in u."""
	return _st_along[_cr_station[c]]


func station_count() -> int:
	"""How many spans were measured across the streams (every CROSSING_STEP_U; 0 before finalize)."""
	return _station_count


func station_a(s: int) -> Vector2i:
	"""One dry bank end of measured span `s`, in u (1 u past the waterline)."""
	return Vector2i(_st_ax[s], _st_az[s])


func station_b(s: int) -> Vector2i:
	"""The other dry bank end of measured span `s`, in u."""
	return Vector2i(_st_bx[s], _st_bz[s])


func station_depth_u(s: int) -> int:
	"""The water depth on the axis of measured span `s`, in u."""
	return _st_depth[s]


func station_body(s: int) -> int:
	"""The stream measured span `s` crosses."""
	return _st_body[s]


# --- landings ----------------------------------------------------------------------------------

func _resolve_landings() -> void:
	"""Snap every authored landing to its nearest shore sample and set its dry land point."""
	for k: int in _landing_count:
		nearest_bank(Vector2i(_landing_near_x[k], _landing_near_z[k]), _bank_scratch)
		_landing_water_x[k] = _bank_scratch.x
		_landing_water_z[k] = _bank_scratch.z
		_landing_body[k] = _bank_scratch.body
		_field(_bank_scratch.x, _bank_scratch.z)
		var nx: int = _bank_scratch.x - _f_cx
		var nz: int = _bank_scratch.z - _f_cz
		var length: int = maxi(1, Rules.isqrt(nx * nx + nz * nz))
		@warning_ignore("integer_division") var land_x: int = _bank_scratch.x + nx * _landing_setback[k] / length
		@warning_ignore("integer_division") var land_z: int = _bank_scratch.z + nz * _landing_setback[k] / length
		_landing_resolved[k] = 1 if _walk_dry(land_x, land_z, nx, nz, length) else 0
		_landing_land_x[k] = _walk_x
		_landing_land_z[k] = _walk_z


func landing_count() -> int:
	"""How many landings were authored."""
	return _landing_count


func landing_index_into(name: StringName, out: IntMath.IntResult) -> bool:
	"""The index of the landing called `name`; refuses an unknown name."""
	for k: int in _landing_count:
		if _landing_name[k] == name:
			return out.succeed(k)
	return out.refuse(String(REFUSE_UNKNOWN_LANDING))


func landing_name(k: int) -> StringName:
	"""The authored name of landing `k`."""
	return _landing_name[k]


func landing_water(k: int) -> Vector2i:
	"""Landing `k`'s waterline point (a shore sample), in u. Valid after finalize."""
	return Vector2i(_landing_water_x[k], _landing_water_z[k])


func landing_land(k: int) -> Vector2i:
	"""Landing `k`'s dry land point, beyond the bank, in u. Valid after finalize."""
	return Vector2i(_landing_land_x[k], _landing_land_z[k])


func landing_body(k: int) -> int:
	"""The body landing `k` gives onto. Valid after finalize."""
	return _landing_body[k]


# --- tunnels -----------------------------------------------------------------------------------

func segment_crosses_water(a: Vector2i, b: Vector2i, clearance_u: int) -> bool:
	"""Whether the segment a->b comes within `clearance_u` (>= 0) of any water: the distance from it
	to some primitive's axis is at most that primitive's WIDEST radius plus the clearance. Exact for
	a pond circle, conservative along a taper; within 1 u of integer rounding either way."""
	for i: int in _seg_count:
		var reach: int = maxi(_ra[i], _rb[i]) + maxi(clearance_u, 0)
		var q1 := Vector2i(_ax[i], _az[i])
		var q2 := Vector2i(_bx[i], _bz[i])
		if segment_distance_u(a, b, q1, q2) <= reach:
			return true
	return false


static func segment_distance_u(p1: Vector2i, p2: Vector2i, q1: Vector2i, q2: Vector2i) -> int:
	"""The distance between segments p1-p2 and q1-q2 in u (floor): 0 when they meet, else the
	least of the four end-to-segment distances. Either segment may be a single point."""
	if _segments_meet(p1, p2, q1, q2):
		return 0
	var best: int = point_segment_distance_u(p1, q1, q2)
	best = mini(best, point_segment_distance_u(p2, q1, q2))
	best = mini(best, point_segment_distance_u(q1, p1, p2))
	return mini(best, point_segment_distance_u(q2, p1, p2))


static func point_segment_distance_u(p: Vector2i, a: Vector2i, b: Vector2i) -> int:
	"""The distance from `p` to the segment a-b in u (floor), through its integer closest point."""
	var dx: int = b.x - a.x
	var dz: int = b.y - a.y
	var den: int = dx * dx + dz * dz
	var num: int = 0
	if den > 0:
		num = clampi((p.x - a.x) * dx + (p.y - a.y) * dz, 0, den)
	else:
		den = 1
	@warning_ignore("integer_division") var ex: int = p.x - (a.x + dx * num / den)
	@warning_ignore("integer_division") var ez: int = p.y - (a.y + dz * num / den)
	return Rules.isqrt(ex * ex + ez * ez)


static func _orientation(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	"""Sign of the cross product (b - a) x (c - a): 1 left turn, -1 right turn, 0 collinear."""
	return signi((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))


static func _on_segment(a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	"""Whether collinear point `c` lies within the bounding box of a-b."""
	return mini(a.x, b.x) <= c.x and c.x <= maxi(a.x, b.x) \
		and mini(a.y, b.y) <= c.y and c.y <= maxi(a.y, b.y)


static func _segments_meet(p1: Vector2i, p2: Vector2i, q1: Vector2i, q2: Vector2i) -> bool:
	"""Whether two closed segments share a point (proper crossing, touching or collinear overlap)."""
	var o1: int = _orientation(p1, p2, q1)
	var o2: int = _orientation(p1, p2, q2)
	var o3: int = _orientation(q1, q2, p1)
	var o4: int = _orientation(q1, q2, p2)
	if o1 != o2 and o3 != o4:
		return true
	if o1 == 0 and _on_segment(p1, p2, q1):
		return true
	if o2 == 0 and _on_segment(p1, p2, q2):
		return true
	if o3 == 0 and _on_segment(q1, q2, p1):
		return true
	return o4 == 0 and _on_segment(q1, q2, p2)
