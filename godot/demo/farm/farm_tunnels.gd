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
## EARTH (decision 0401, which retires 0196's "spoil as soil"). What a tunnel digs out is EARTH (the adopted
## `excavated_earth`: a plain material -- never compost, never fertility). Each mouth's spoil heap holds the earth dug
## out there (`heaped_milli`, milli-U, the adopted 2 U per cubic metre); a heap is a mouth row of the network. The heap
## is what is LEFT: what has been tipped on it (a dig crew's baskets still on the way are not on it yet:
## underground_graph.gd `haul`, decision 0211) minus taken. What was taken is kept here per heap and per mouth
## generation, so a freed and reused mouth row starts a fresh heap. Earth taken off a heap is carried somewhere and is
## then (1) KEPT in the village stores by the stockpile (a cleared heap: demo/spoil/spoil_crew.gd), (2) BUILT into a
## bed by Raise or Bank (`build_with`, counted in `built_milli`), or (3) put back where it came from
## (`return_spoil_into`: a carry that never arrived, decision 0361). Nothing else makes or ends earth.
##
## SOURCES. Raise and Bank fetch their earth from a heap or, once a heap has been cleared there, from the stores
## (`bind_store`): source STORE, after the HEAPS heap rows. `spoil_left`, `take_spoil_into`, `return_spoil_into`,
## `spot_of` and `rim_m` take either; `nearest_earth_into` and `most_earth` look at both.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const WaterScript := preload("res://demo/village_water.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

## A bore within this of a bed's centre runs under the bed: the bed's half-width (1.5 m).
const UNDER_REACH_U: int = 1536
const HEAPS: int = Rules.MAX_MOUTHS
## The village stores' earth as a source (see SOURCES): the row after the heaps.
const STORE: int = HEAPS
const SOURCES: int = HEAPS + 1
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
## Earth built into beds by Raise and Bank, milli-U (see EARTH).
var built_milli: int = 0
## Where earth is kept (see SOURCES); null: no store, only heaps.
var _stores: StoresScript = null
var _store_at: Vector2 = Vector2.ZERO


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


# --- earth ---------------------------------------------------------------------------------

func bind_store(stores: StoresScript, at: Vector2) -> void:
	"""Earth is kept in `stores`, fetched from `at` (the stockpile's spot, metres x z; see SOURCES)."""
	_stores = stores
	_store_at = at


func has_store() -> bool:
	"""Whether earth can be kept in (and fetched from) the stores."""
	return _stores != null


func _sync_heap(network: GraphScript, heap: int) -> void:
	"""Forget what was taken from a heap whose mouth row was freed or reused."""
	if not network.is_mouth(heap) or network.mouth_gen[heap] != _taken_generation[heap]:
		_taken[heap] = 0
		_taken_generation[heap] = network.mouth_gen[heap]


func heaped_milli(network: GraphScript, heap: int) -> int:
	"""All the earth heap `heap` (a mouth row) has received, milli-U."""
	return network.heaped_milli(heap)


func spoil_left(network: GraphScript, source: int) -> int:
	"""The earth still at `source`, milli-U: on a heap, tipped on it minus taken (see EARTH); the stores' (STORE)."""
	if source == STORE:
		return _stores.earth_milli_u if _stores != null else 0
	_sync_heap(network, source)
	return network.haul.on_heap_milli(network, source) - _taken[source]


func taken_milli(network: GraphScript, heap: int) -> int:
	"""How much has been taken from heap `heap`, milli-U."""
	_sync_heap(network, heap)
	return _taken[heap]


func _is_source(source: int) -> bool:
	"""Whether `source` names a heap row, or the stores when they are bound."""
	return (source >= 0 and source < HEAPS) or (source == STORE and _stores != null)


func take_spoil_into(network: GraphScript, source: int, milli: int, out: IntMath.IntResult) -> bool:
	"""Take `milli` of earth from `source` (a heap or STORE); refuses a bad source or one holding less."""
	if not _is_source(source) or milli <= 0:
		return out.refuse(REFUSE_BAD_HEAP)
	if spoil_left(network, source) < milli:
		return out.refuse(REFUSE_NO_SPOIL)
	if source == STORE:
		_stores.take_earth(milli)
	else:
		_taken[source] += milli
	return out.succeed(spoil_left(network, source))


func return_spoil_into(network: GraphScript, source: int, milli: int, out: IntMath.IntResult) -> bool:
	"""Put `milli` of earth taken from `source` back -- a load carried off and never delivered (decision 0361: nothing
	is credited from afar); refuses a bad source, or more than was taken from a heap."""
	if not _is_source(source) or milli <= 0:
		return out.refuse(REFUSE_BAD_HEAP)
	if source == STORE:
		_stores.add_earth(milli)
		return out.succeed(spoil_left(network, source))
	_sync_heap(network, source)
	if _taken[source] < milli:
		return out.refuse(REFUSE_NO_SPOIL)
	_taken[source] -= milli
	return out.succeed(spoil_left(network, source))


func build_with(milli: int) -> void:
	"""`milli` of earth carried to a bed is built into it (Raise, Bank; see EARTH)."""
	if milli > 0:
		built_milli += milli


func spot_of(network: GraphScript, source: int) -> Vector2:
	"""Where earth is fetched from `source` (metres x z): its heap's spot, or the stockpile's."""
	return _store_at if source == STORE else network.heap_at[source]


func rim_m(network: GraphScript, source: int) -> float:
	"""How far `source` reaches from `spot_of` (m): its heap's placed radius; the stockpile's spot is a point (0)."""
	return 0.0 if source == STORE else network.heap_radius_m[source]


func nearest_earth_into(network: GraphScript, from: Vector2, milli: int, out: IntMath.IntResult) -> bool:
	"""The source holding at least `milli` -- a heap, or the stores -- whose spot is nearest `from` (presentation
	choice of where to walk); refuses NOT_ENOUGH_SPOIL when none does."""
	var found: bool = false
	var best_d: float = INF
	for source: int in SOURCES:
		if not _is_source(source) or spoil_left(network, source) < milli:
			continue
		var d: float = spot_of(network, source).distance_squared_to(from)
		if not found or d < best_d:
			best_d = d
			found = out.succeed(source)
	if not found:
		return out.refuse(REFUSE_NO_SPOIL)
	return true


func most_earth(network: GraphScript) -> int:
	"""The most earth any one source -- a heap or the stores -- holds, milli-U (what Raise and Bank compare)."""
	var most: int = 0
	for source: int in SOURCES:
		if _is_source(source):
			most = maxi(most, spoil_left(network, source))
	return most


func total_spoil(network: GraphScript) -> int:
	"""All the earth left on every heap, milli-U (the stores' not counted)."""
	var total: int = 0
	for heap: int in HEAPS:
		total += spoil_left(network, heap)
	return total
