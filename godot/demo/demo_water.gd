extends RefCounted
## THE VILLAGE'S WATER, as the demo asks about it: one small adapter. Decision 0196 (live demo).
##
## The farm and the tunnel works each ask the village one kind of question about water, and both now
## ask it HERE -- demo_village.gd builds one of these and hands it to both (the farm gets
## `edge_query()`, the tunnel works the adapter itself):
##   * `at_edge(x_u, z_u)` -- the FARM's irrigation: does a tunnel mouth here open at a water edge?
##   * `near_water(x_u, z_u)` -- the TUNNEL WORKS' ground: is the ground here wet from nearby water?
##   * `spill_centre_u()` / `spill_radius_u()` -- the TUNNEL WORKS' flood event: the disc a flood of
##     the water spills over.
## Every point is in the tunnel network's integer u (1/1024 m); every answer is exact integers.
##
## THE REAL WATER MODULE (feat/demo-water: the stream and the pond, their surface, depth and shore map)
## is not merged. Until it is, each question is answered by that branch's PLACEHOLDER table, and
## nothing else in the demo knows where water is:
##   * the farm's reed pond, farm_water.gd DEMO_EDGES (its disc and obstacle are drawn by
##     farm_water.gd's two PLACEHOLDER functions);
##   * the tunnels' stream reach and flood disc, tunnel_water.gd REACHES / SPILL.
## ON MERGE, the swap is this file: answer the four queries from the real module, drop the two
## placeholder tables' preloads, and delete the placeholders (see farm_water.gd for the pond's two
## drawing call sites). No caller changes. The placeholders are not reconciled with each other here:
## doing so would be inventing water the real module will replace anyway.

const TunnelWaterScript := preload("res://demo/tunnel/tunnel_water.gd")
const FarmWaterScript := preload("res://demo/farm/farm_water.gd")

## PLACEHOLDER: the tunnel works' stream table (a fixture may hand in its own).
var _tunnel_table: TunnelWaterScript = null


func _init(tunnel_table: TunnelWaterScript = null) -> void:
	"""The village's water over the placeholder tables (a test may hand in a stream-table fixture)."""
	_tunnel_table = tunnel_table if tunnel_table != null else TunnelWaterScript.new()


func at_edge(x_u: int, z_u: int) -> bool:
	"""THE FARM'S QUERY: whether (x, z) in u lies at a water edge. PLACEHOLDER: farm_water.gd's pond."""
	return FarmWaterScript.is_demo_edge_u(x_u, z_u)


func near_water(x_u: int, z_u: int) -> bool:
	"""THE TUNNELS' QUERY: whether the ground at (x, z) in u is wet from nearby water. PLACEHOLDER:
	tunnel_water.gd's stream reach."""
	return _tunnel_table.near_water(x_u, z_u)


func spill_centre_u() -> Vector2i:
	"""THE FLOOD'S QUERY: the centre of the disc a flood of the water covers, in u. PLACEHOLDER."""
	return _tunnel_table.spill_centre_u()


func spill_radius_u() -> int:
	"""THE FLOOD'S QUERY: the radius of that disc, in u. PLACEHOLDER."""
	return _tunnel_table.spill_radius_u()


func edge_query() -> Callable:
	"""`at_edge` as the farm's `(x_u: int, z_u: int) -> bool` Callable (farm_tunnels.gd `water_edge`)."""
	return at_edge
