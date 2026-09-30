extends RefCounted
## The drawn centreline of a swept bore (decision 0207; design docs/design/underground_revamp.md §6
## "Bores"). Presentation only.
##
## A tunnel's route is a polyline (tunnel_network.gd). A tube swept round a sharp corner would fold its
## inner wall over itself, so the DRAWN centreline rounds each corner with a symmetric quadratic fillet.
## Such a fillet is tightest at its middle, where its radius of curvature is r * cos(turn / 2) for a
## tangent length r * tan(turn / 2); so r is chosen as `bend_radius` / cos(turn / 2), which keeps the
## tightest radius at the bore's widest reach (jitter included) and the inner wall unfolded. A fillet
## never takes more than FILLET_LEG_SHARE of either leg: a corner too sharp for its short legs is rounded
## as far as they allow, and may still fold (P2's curve rules own bend radii).
##
## ONE CURVE PER TUNNEL (`of`): the bore's rings, its stones and roots, the walkers in it, its braces and
## lanterns all stand on the same drawn centreline, so nobody walks in a wall at a corner. It is cached per
## network and slot, rebuilt when the tunnel's generation, class or route changes.
##
## `along` is the ROUTE's distance (the one walkers, dig faces and lanterns are placed by), so ring k of
## a bore sits at the same `along` as a walker there. Sampling keeps a cursor on the legs: forward samples
## walk it on, and a sample behind it starts it again from the entrance.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")

## A fillet never takes more than this share of a leg, so two corners' fillets never overlap.
const FILLET_LEG_SHARE: float = 0.45
## Clearance past the bore's widest jittered reach at the fillet's tightest point.
const BEND_MARGIN_M: float = 0.05
## Curves kept per network (a slot each).
const SLOTS: int = Rules.MAX_TUNNELS

static var _shared: Dictionary = {}

var _points: PackedVector2Array = PackedVector2Array()
## Route distance of each point (m), and each interior point's fillet tangent length (m).
var _at: PackedFloat32Array = PackedFloat32Array()
var _tangent: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 1
## What the curve was built for (see ONE CURVE PER TUNNEL): generation, class, points, length.
var _stamp: PackedInt64Array = PackedInt64Array([-1, -1, -1, -1])


static func bend_radius(bore: int) -> float:
	"""The tightest a fillet may bend a bore of class `bore` (m): its widest jittered half-width and a
	margin (bore_mesh.gd)."""
	var widest := BoreMeshScript.FLOOR_HALF_M[bore] * BoreMeshScript.BULGE * (1.0 + BoreMeshScript.RING_WIDTH_JITTER)
	return widest + BoreMeshScript.WALL_JITTER_M + BEND_MARGIN_M


static func of(network: RefCounted, slot: int) -> RefCounted:
	"""The drawn centreline of tunnel `slot` in `network` (tunnel_network.gd), shared and kept up to date
	(see ONE CURVE PER TUNNEL)."""
	var key := network.get_instance_id() * SLOTS + slot
	var curve: RefCounted = _shared.get(key)
	if curve == null:
		if _shared.size() > 4 * SLOTS:
			_shared.clear()
		curve = (load("res://demo/tunnel/bore_curve.gd") as GDScript).new()
		_shared[key] = curve
	curve.follow(network, slot)
	return curve


func follow(network: RefCounted, slot: int) -> void:
	"""Rebuild from tunnel `slot`'s route when it changed since the last build (see ONE CURVE PER TUNNEL)."""
	var generation: int = network.generation[slot]
	var bore: int = network.bore[slot]
	var count: int = network.point_count[slot]
	var length: int = network.length_u[slot]
	if _stamp[0] == generation and _stamp[1] == bore and _stamp[2] == count and _stamp[3] == length:
		return
	_stamp[0] = generation
	_stamp[1] = bore
	_stamp[2] = count
	_stamp[3] = length
	var points := PackedVector2Array()
	points.resize(count)
	for k in count:
		points[k] = network.point(slot, k)
	set_route(points, bend_radius(bore))


func set_route(points: PackedVector2Array, radius: float) -> void:
	"""Draw along these route points (m), no fillet bending tighter than `radius` (m)."""
	_points = points
	var count := points.size()
	_at.resize(count)
	_tangent.resize(count)
	_tangent.fill(0.0)
	if count == 0:
		return
	_at[0] = 0.0
	for k in range(1, count):
		_at[k] = _at[k - 1] + points[k - 1].distance_to(points[k])
	for k in range(1, count - 1):
		_tangent[k] = _fillet_tangent(k, radius)
	_cursor = 1


func _fillet_tangent(k: int, radius: float) -> float:
	"""How far either side of corner `k` its fillet starts (m): see the header."""
	var into := (_points[k] - _points[k - 1]).normalized()
	var out := (_points[k + 1] - _points[k]).normalized()
	var turn := acos(clampf(into.dot(out), -1.0, 1.0))
	var legs := minf(_at[k] - _at[k - 1], _at[k + 1] - _at[k]) * FILLET_LEG_SHARE
	var half := minf(turn * 0.5, 1.5)
	return minf(radius * tan(half) / cos(half), legs)


func length_m() -> float:
	"""The route's length (m)."""
	return _at[_at.size() - 1] if not _at.is_empty() else 0.0


func rewind() -> void:
	"""Start the next samples from the entrance again."""
	_cursor = 1


func sample(along: float, out: PackedVector2Array) -> void:
	"""The drawn centreline `along` route metres in: out[0] its point (x, z), out[1] its unit heading."""
	var count := _points.size()
	if count < 2:
		out[0] = _points[0] if count == 1 else Vector2.ZERO
		out[1] = Vector2(1.0, 0.0)
		return
	var a := clampf(along, 0.0, length_m())
	if _cursor > 1 and a < _at[_cursor - 1] - _tangent[_cursor - 1]:
		_cursor = 1
	while _cursor < count - 1 and a > _at[_cursor] + _tangent[_cursor]:
		_cursor += 1
	var k := _cursor
	if k > 1 and a < _at[k - 1] + _tangent[k - 1]:
		_fillet(k - 1, a, out)
	elif k < count - 1 and a > _at[k] - _tangent[k]:
		_fillet(k, a, out)
	else:
		var leg := _points[k] - _points[k - 1]
		var span := maxf(_at[k] - _at[k - 1], 1e-6)
		out[0] = _points[k - 1] + leg * ((a - _at[k - 1]) / span)
		out[1] = leg / span


func _fillet(k: int, a: float, out: PackedVector2Array) -> void:
	"""A point on corner `k`'s fillet: a quadratic Bezier from its tangent point on the leg in, through
	the corner as control point, to the one on the leg out."""
	var t := _tangent[k]
	var into := (_points[k] - _points[k - 1]).normalized()
	var onward := (_points[k + 1] - _points[k]).normalized()
	var p0 := _points[k] - into * t
	var p2 := _points[k] + onward * t
	var u := clampf((a - (_at[k] - t)) / (2.0 * t), 0.0, 1.0)
	out[0] = p0 * ((1.0 - u) * (1.0 - u)) + _points[k] * (2.0 * u * (1.0 - u)) + p2 * (u * u)
	var slope := (_points[k] - p0) * (2.0 * (1.0 - u)) + (p2 - _points[k]) * (2.0 * u)
	out[1] = slope.normalized() if slope.length_squared() > 1e-12 else into
