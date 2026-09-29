extends RefCounted
## PLACEHOLDER: the tunnel works' stream table, answered THROUGH demo/demo_water.gd (the village's one
## water adapter) and asked by nothing else. Decision 0196 (live demo). Presentation only.
##
## The village's real water -- a stream and a pond, with a surface and a depth and shore map -- is
## built on another branch (feat/demo-water). Until it is merged, this tiny demo table answers the
## adapter's two tunnel-side questions:
##   * `near_water(x_u, z_u)`: whether ground at a point is wet from nearby water. The ground map
##     (tunnel_ground.gd) asks it once per cell; tunnel hazards and the planning tint read the result.
##   * `spill_centre_u()` / `spill_radius_u()`: the disc a flood of the stream covers (the demo's
##     flood event, demo/events/).
## On merge, demo_water.gd answers them from the real water module and this file is deleted.
##
## THE DEMO TABLE: REACHES, stretches of water as capsules -- (ax, az, bx, bz, radius) in u, ground
## within `radius` of the segment A-B being wet -- here the reed-bed stream edge along the west of the
## village; and SPILL, the disc (cx, cz, radius) in u its flood covers. Both are demo values. A test
## may hand in its own table (a fixture).

## (ax, az, bx, bz, radius) per reach, in u.
const REACHES: Array[int] = [-19968, 3072, -19968, 17408, 4608]
const REACH_WIDTH: int = 5
## (cx, cz, radius) of the flood's disc, in u.
const SPILL: Array[int] = [-14131, 10445, 8397]

var reaches: PackedInt32Array = PackedInt32Array()
var spill: PackedInt32Array = PackedInt32Array()


func _init(reach_table: PackedInt32Array = PackedInt32Array(REACHES), spill_disc: PackedInt32Array = PackedInt32Array(SPILL)) -> void:
	"""The demo table, or a fixture's."""
	reaches = reach_table
	spill = spill_disc


func reach_count() -> int:
	"""How many stretches of water the table has."""
	return reaches.size() / REACH_WIDTH


func near_water(x_u: int, z_u: int) -> bool:
	"""Whether the ground at (x_u, z_u) lies within a reach's radius of its segment (exact integers)."""
	for r in reach_count():
		if _within(r, x_u, z_u):
			return true
	return false


func _within(r: int, x_u: int, z_u: int) -> bool:
	"""Whether (x_u, z_u) lies within reach `r`'s radius of its segment."""
	var i := r * REACH_WIDTH
	var abx := reaches[i + 2] - reaches[i]
	var abz := reaches[i + 3] - reaches[i + 1]
	var length_sq := maxi(abx * abx + abz * abz, 1)
	var along := clampi(abx * (x_u - reaches[i]) + abz * (z_u - reaches[i + 1]), 0, length_sq)
	var dx := x_u - (reaches[i] + abx * along / length_sq)
	var dz := z_u - (reaches[i + 1] + abz * along / length_sq)
	return dx * dx + dz * dz < reaches[i + 4] * reaches[i + 4]


func spill_centre_u() -> Vector2i:
	"""The centre of the disc a flood of the water covers, in u."""
	return Vector2i(spill[0], spill[1])


func spill_radius_u() -> int:
	"""The radius of the disc a flood of the water covers, in u."""
	return spill[2]
