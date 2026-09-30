extends RefCounted
## What the moles' tunnels do for the farm. Decision 0196. Reads the tunnel network
## (demo/tunnel/underground_graph.gd) through its public columns and never writes to it.
##
## DRAINAGE AND IRRIGATION. A FINISHED segment of the network whose bore passes under a bed drains it --
## farm_sim.gd pulls its moisture toward its crop's low side each farm day. Water let in at a mouth at a
## water edge runs on through the open bores joined to it (decision 0208: the network is one), so a
## segment reached through usable bores from such a mouth carries water instead, and IRRIGATES every bed
## it passes under: moisture is pulled toward the band's middle, up or down. "At a water edge" is `water_edge`, the one water query
## (demo/village_water.gd `edge_query()`, the village's one water adapter: dry ground near the real
## stream's or pond's waterline). "Passes under" is an INTEGER test
## in the network's own units (u, 1/1024 m): some leg of the route comes within UNDER_REACH_U of the
## bed's centre. The beds' centres are imported from the layout once (float is import only).
##
## SPOIL AS SOIL. Each mouth's heap holds the spoil dug out there so far (`heaped_milli`, milli-U, the
## adopted 2 U per cubic metre); a heap is a mouth row of the network. The farm takes spoil from a heap
## -- to raise a bed, bank it, or dig it in as compost -- and the heap is what is LEFT: what has been
## tipped on it (a dig crew's baskets still on the way are not on it yet: underground_graph.gd `haul`,
## decision 0211) minus taken. What was taken is kept here per heap and per mouth generation, so a freed and reused mouth
## row starts a fresh heap.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const WaterScript := preload("res://demo/village_water.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## A bore within this of a bed's centre runs under the bed: the bed's half-width (1.5 m).
const UNDER_REACH_U: int = 1536
const HEAPS: int = Rules.MAX_MOUTHS
const REFUSE_NO_SPOIL: String = "NOT_ENOUGH_SPOIL"
const REFUSE_BAD_HEAP: String = "NO_SUCH_HEAP"

## `(x_u: int, z_u: int) -> bool`: whether a point is at a water edge (see the header).
## A water adapter of its own, held so `water_edge` stays valid until the village hands its query in.
var _own_water: WaterScript = WaterScript.new()
var water_edge: Callable = _own_water.edge_query()

var _bed_x: PackedInt32Array = PackedInt32Array()
var _bed_z: PackedInt32Array = PackedInt32Array()
var _taken: PackedInt64Array = PackedInt64Array()
var _taken_generation: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Import the beds' centres into u, once."""
	_bed_x.resize(Catalog.BED_COUNT)
	_bed_z.resize(Catalog.BED_COUNT)
	for bed: int in Catalog.BED_COUNT:
		var at: Vector2 = Catalog.bed_centre_m(bed)
		_bed_x[bed] = Rules.to_u(at.x)
		_bed_z[bed] = Rules.to_u(at.y)
	_taken.resize(HEAPS)
	_taken_generation.resize(HEAPS)


# --- drainage and irrigation ----------------------------------------------------------------

static func segment_near(px: int, pz: int, ax: int, az: int, bx: int, bz: int, reach: int) -> bool:
	"""Whether the segment A->B comes within `reach` of P, in integer u. The perpendicular case
	compares cross^2 with reach^2 * |AB|^2 only after a coarse bound (|cross| <= reach * (isqrt+1)),
	so no product can leave int64 for any two points of the village."""
	var abx: int = bx - ax
	var abz: int = bz - az
	var apx: int = px - ax
	var apz: int = pz - az
	var length2: int = abx * abx + abz * abz
	var along: int = apx * abx + apz * abz
	if along <= 0 or length2 == 0:
		return apx * apx + apz * apz <= reach * reach
	if along >= length2:
		return (px - bx) * (px - bx) + (pz - bz) * (pz - bz) <= reach * reach
	var cross: int = absi(abx * apz - abz * apx)
	if cross > reach * (Rules.isqrt(length2) + 1):
		return false
	return cross * cross <= reach * reach * length2


func passes_under(network: GraphScript, slot: int, bed: int) -> bool:
	"""Whether segment `slot`'s route runs under bed `bed`."""
	var base: int = slot * Rules.MAX_POINTS
	for k: int in range(1, network.point_count[slot]):
		var a: int = 2 * (base + k - 1)
		var b: int = 2 * (base + k)
		if segment_near(_bed_x[bed], _bed_z[bed], network.points_u[a], network.points_u[a + 1],
				network.points_u[b], network.points_u[b + 1], UNDER_REACH_U):
			return true
	return false


func feeds_from_water(network: GraphScript, slot: int) -> bool:
	"""Whether water reaches segment `slot`: some mouth at a water edge leads to it through usable segments
	(it included; see DRAINAGE AND IRRIGATION)."""
	if not network.is_usable(slot):
		return false
	for m: int in Rules.MAX_MOUTHS:
		if not network.is_mouth(m):
			continue
		var at: Vector2i = network.node_at(network.mouth_node[m])
		if bool(water_edge.call(at.x, at.y)) \
				and network.paths.dist_u(network, PathsScript.CLASS_ANY, m, network.node_a[slot]) < PathsScript.UNREACHED:
			return true
	return false


func water_of_into(network: GraphScript, bed: int, out: PackedByteArray) -> void:
	"""Whether finished segments drain (out[0]) or irrigate (out[1]) bed `bed`."""
	out[0] = 0
	out[1] = 0
	for slot: int in Rules.MAX_SEGMENTS:
		if not network.is_open(slot) or not passes_under(network, slot, bed):
			continue
		if feeds_from_water(network, slot):
			out[1] = 1
		else:
			out[0] = 1


# --- spoil ----------------------------------------------------------------------------------

func _sync_heap(network: GraphScript, heap: int) -> void:
	"""Forget what was taken from a heap whose mouth row was freed or reused."""
	if not network.is_mouth(heap) or network.mouth_gen[heap] != _taken_generation[heap]:
		_taken[heap] = 0
		_taken_generation[heap] = network.mouth_gen[heap]


func heaped_milli(network: GraphScript, heap: int) -> int:
	"""All the spoil heap `heap` (a mouth row) has received, milli-U."""
	return network.heaped_milli(heap)


func spoil_left(network: GraphScript, heap: int) -> int:
	"""The spoil still on heap `heap`, milli-U: tipped on it minus taken (see SPOIL AS SOIL)."""
	_sync_heap(network, heap)
	return network.haul.on_heap_milli(network, heap) - _taken[heap]


func taken_milli(network: GraphScript, heap: int) -> int:
	"""How much has been taken from heap `heap`, milli-U."""
	_sync_heap(network, heap)
	return _taken[heap]


func take_spoil_into(network: GraphScript, heap: int, milli: int, out: IntMath.IntResult) -> bool:
	"""Take `milli` of spoil off heap `heap`; refuses a bad heap or one holding less."""
	if heap < 0 or heap >= HEAPS or milli <= 0:
		return out.refuse(REFUSE_BAD_HEAP)
	if spoil_left(network, heap) < milli:
		return out.refuse(REFUSE_NO_SPOIL)
	_taken[heap] += milli
	return out.succeed(spoil_left(network, heap))


func nearest_heap_into(network: GraphScript, from: Vector2, milli: int, out: IntMath.IntResult) -> bool:
	"""The heap holding at least `milli` whose spot is nearest `from` (presentation choice of which
	heap to walk to); refuses NOT_ENOUGH_SPOIL when none does."""
	var found: bool = false
	var best_d: float = INF
	for heap: int in HEAPS:
		if spoil_left(network, heap) < milli:
			continue
		var d: float = network.heap_at[heap].distance_squared_to(from)
		if not found or d < best_d:
			best_d = d
			found = out.succeed(heap)
	if not found:
		return out.refuse(REFUSE_NO_SPOIL)
	return true


func total_spoil(network: GraphScript) -> int:
	"""All the spoil left on every heap, milli-U."""
	var total: int = 0
	for heap: int in HEAPS:
		total += spoil_left(network, heap)
	return total
