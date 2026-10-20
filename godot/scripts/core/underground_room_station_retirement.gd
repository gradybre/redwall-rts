extends RefCounted
## Decision 1942: retiring a finished column's station chain (decision 1934 §2, ADR 1213's cold route budget).
## Stateless and synchronous. A chain is the finished column's WORK station and the TRANSIT stations that lead to it
## alone: walking back from the WORK station, each station whose only other neighbour is the next one towards the
## gateway. The walk stops at the gateway, at a junction (a station another chain also leaves from, ADR 1215's
## gateway reuse), at any endpoint another builder still holds, and at anything that is not a station. Retirement is
## two real publications under one cold lease, as `underground_entry_stair_path.gd` retracts a stop: WorldRoutes
## removes every edge incident to the chain, then Locations removes the now-disconnected stations. Both owners keep
## their own guards (an occupied or queued edge, an endpoint an actor or a container still holds).

const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Publication := preload("res://scripts/core/underground_room_frontier_publication.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## The longest chain one walk removes: one publication's stations, plus as many again that an earlier chain's junction
## left behind once that chain was retired (ADR 1213: a chain starts at most one existing TRANSIT station deep).
const MAX_CHAIN: int = 2 * Publication.MAX_STATIONS
## Decision 1942, measured at master 8a7d045d on claw rooms (content 12) under the game's ground-pace catalog (its 26
## paced rows): a phase commit's sealed route proof spends about MEASURED_BASE_CHECKS plus MEASURED_CHECKS_PER_EDGE
## for each live route edge (rooms of 16 to 96 cubes, 20 to 100 edges; the budget runs out near 100 edges).
## Finished chains are retired once the live graph holds the edges that would spend half of the cold budget,
## Space.MAX_CHECKS: 35 edges, about 520,000 checks. Below it a room digs exactly as before.
const MEASURED_BASE_CHECKS: int = 237561
const MEASURED_CHECKS_PER_EDGE: int = 8059
@warning_ignore("integer_division")
const RETIRE_FROM_EDGES: int = (Space.MAX_CHECKS / 2 - MEASURED_BASE_CHECKS) / MEASURED_CHECKS_PER_EDGE
const REFUSE_EMPTY: StringName = &"ROOM_STATION_RETIREMENT_EMPTY"
const REFUSE_OWNER: StringName = &"ROOM_STATION_RETIREMENT_OWNER"
const REFUSE_RETAINED: StringName = &"ROOM_STATION_RETIREMENT_RETAINED"
const REFUSE_LOCATIONS: StringName = &"ROOM_STATION_RETIREMENT_LOCATIONS"


static func due(routes: Routes) -> bool:
	"""Retirement runs only once the live graph holds RETIRE_FROM_EDGES edges, so a room that never gets near the
	cold route budget digs exactly as before (decision 1942)."""
	return routes._live.edge_count >= RETIRE_FROM_EDGES


static func retire_finished(foremen: Array[Foreman], owners: Builder.Owners) -> int:
	"""Once `due`, offer at most one chain a tick: the first idle builder (in dig and crew order) whose last column is
	done offers the chain walked back from the WORK station it last worked from, keeping every endpoint any dig's
	builders still hold. On success every idle builder that named a retired station forgets it. Returns the chains
	retired (0 or 1). A refusal never stops a dig: the same chain is offered again on a later tick, and a refusal
	changes nothing (the checks before either publication foresee every refusal of the second). Nothing is allocated
	unless some builder offers a chain."""
	if owners == null or foremen.is_empty() or not due(owners.routes): return 0
	for foreman: Foreman in foremen:
		for builder: Builder in foreman.builders():
			var work: Vector2i = foreman.retirable_station(builder)
			if work != NULL_REF: return 1 if _retire_one(foremen, owners, work) == &"" else 0
	return 0


static func _retire_one(foremen: Array[Foreman], owners: Builder.Owners, work: Vector2i) -> StringName:
	"""Walk the chain back from `work`, keeping what any dig's builders hold, retire it, and let every idle builder
	that named it forget it."""
	var locations: Locations = owners.locations if owners.locations != null \
		else owners.binding._locations_ref.get_ref() as Locations
	if locations == null: return REFUSE_OWNER
	var chain: PackedInt32Array = PackedInt32Array()
	chain_into(locations, owners.routes, work, owners.provider._ordinary_retreat, foremen, chain)
	var code: StringName = retire(owners.binding, owners.routes, locations, owners.budget, chain)
	if code != &"": return code
	for foreman: Foreman in foremen:
		for builder: Builder in foreman.builders():
			builder.forget_retired(chain)
	return &""


static func chain_into(locations: Locations, routes: Routes, work: Vector2i, gateway: Vector2i,
		foremen: Array[Foreman], out: PackedInt32Array) -> int:
	"""The retirable chain ending at the WORK station `work`, as (slot, generation) pairs from the WORK station back
	towards the gateway, written into `out`; returns how many stations. No walk takes an endpoint any of `foremen`'s
	builders still holds. Nothing is written for a WORK station another chain or builder still uses."""
	out.clear()
	if work == gateway or not _station(locations, work, Locations.ROLE_WORK) or _held(foremen, work): return 0
	var neighbours: PackedInt32Array = PackedInt32Array()
	var previous: Vector2i = NULL_REF
	var at: Vector2i = work
	while true:
		var degree: int = _neighbours_into(routes, at, neighbours)
		if degree > (1 if at == work else 2): break # A junction: another chain still leaves from it.
		if out.size() >= 2 * MAX_CHAIN: # Longer than any chain the planner builds: leave it whole, take none of it.
			out.clear()
			break
		out.append(at.x); out.append(at.y)
		var next: Vector2i = _other(neighbours, degree, previous)
		if next == NULL_REF or next == gateway or _held(foremen, next) \
				or not _station(locations, next, Locations.ROLE_TRANSIT): break
		previous = at
		at = next
	return out.size() >> 1


static func _station(locations: Locations, ref: Vector2i, role: int) -> bool:
	"""A live endpoint of the given role."""
	return locations._live_ref(locations._live, ref) \
		and locations._live.i32[Locations.ROLE * locations._capacity + ref.x] == role


static func _held(foremen: Array[Foreman], ref: Vector2i) -> bool:
	"""Some dig's builder still holds the endpoint."""
	for foreman: Foreman in foremen:
		if foreman.holds(ref): return true
	return false


static func _neighbours_into(routes: Routes, at: Vector2i, out: PackedInt32Array) -> int:
	"""The distinct endpoints a live edge joins to `at` in either direction, as pairs in `out` (at most three are
	kept: a third already makes a junction); returns how many were kept."""
	out.resize(6)
	var count: int = 0
	var bank: Routes.EdgeBank = routes._live
	for row: int in routes._edge_capacity:
		if bank.present[row] != 1: continue
		var from: Vector2i = routes._edge_pair(bank, Routes.E_FROM_SLOT, row)
		var to: Vector2i = routes._edge_pair(bank, Routes.E_TO_SLOT, row)
		var other: Vector2i = to if from == at else from if to == at else NULL_REF
		if other == NULL_REF or _listed(out, count, other): continue
		out[2 * count] = other.x; out[2 * count + 1] = other.y
		count += 1
		if count == 3: break
	return count


static func _listed(pairs: PackedInt32Array, count: int, ref: Vector2i) -> bool:
	"""`ref` is one of the first `count` pairs."""
	for at: int in count:
		if pairs[2 * at] == ref.x and pairs[2 * at + 1] == ref.y: return true
	return false


static func _other(neighbours: PackedInt32Array, count: int, previous: Vector2i) -> Vector2i:
	"""The one neighbour that is not where the walk came from, or null."""
	for at: int in count:
		var ref: Vector2i = Vector2i(neighbours[2 * at], neighbours[2 * at + 1])
		if ref != previous: return ref
	return NULL_REF


static func retained(routes: Routes, locations: Locations, chain: PackedInt32Array) -> bool:
	"""Some chain station is where a route actor stands, or holds a container: Locations would refuse to remove it,
	so the graph is not touched either (no station is ever left disconnected by a refusal this can foresee)."""
	for at: int in range(0, chain.size(), 2):
		var ref: Vector2i = Vector2i(chain[at], chain[at + 1])
		for row: int in Routes.RESIDENT_CAPACITY:
			if routes._resident_pair(Routes.R_LOCATION_SLOT, row) == ref: return true
		if locations._inventory != null and locations._inventory.has_spatial_location(ref,
				locations._get64(locations._live, Locations.PAYLOAD_REVISION, ref.x)): return true
	return false


static func retire(binding: WorldRoutes, routes: Routes, locations: Locations, budget: Budget,
		chain: PackedInt32Array) -> StringName:
	"""Publish the removal of every edge incident to the chain, then of the chain's stations, under one cold lease.
	`Budget.REFUSE_BUSY` means another cold operation holds the lease: nothing changed, try again later."""
	if binding == null or routes == null or locations == null or budget == null: return REFUSE_OWNER
	if chain.is_empty(): return REFUSE_EMPTY
	if retained(routes, locations, chain): return REFUSE_RETAINED
	if locations._contact_retirement != null: return Budget.REFUSE_BUSY # The entry's own retirement bracket is open.
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return Budget.REFUSE_BUSY
	var code: StringName = _locations_ready(locations, lease) # Foresee the second publication before the first.
	if code == &"": code = _publish_graph(binding, routes, lease, chain)
	if code == &"": code = _publish_locations(locations, lease, chain)
	budget.release(lease)
	return code


static func _locations_ready(locations: Locations, lease: int) -> StringName:
	"""A Locations preparation can begin under this lease now (no other preparation, Frontier window, open Space
	preparation, exhausted token or short lease); the trial preparation is aborted at once."""
	var begun: Locations.Result = locations.begin_prepare(lease)
	if begun.error != &"": return begun.error
	locations.abort(begun.token)
	return &""


static func _publish_graph(binding: WorldRoutes, routes: Routes, lease: int, chain: PackedInt32Array) -> StringName:
	"""First publication: every live edge that starts or ends at a chain station leaves the graph."""
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	if code == &"": code = _stage_incident(routes, begun.token, chain)
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	if code != &"" and begun.token != 0: binding.abort(begun.token)
	return code


static func _stage_incident(routes: Routes, token: int, chain: PackedInt32Array) -> StringName:
	"""Stage the removal of each live edge incident to the chain (Routes refuses one an actor holds)."""
	var bank: Routes.EdgeBank = routes._live
	var count: int = chain.size() >> 1
	for row: int in routes._edge_capacity:
		if bank.present[row] != 1: continue
		if not _listed(chain, count, routes._edge_pair(bank, Routes.E_FROM_SLOT, row)) \
				and not _listed(chain, count, routes._edge_pair(bank, Routes.E_TO_SLOT, row)): continue
		var code: StringName = routes.stage_remove(token, Vector2i(row, bank.fields[Routes.E_GENERATION * routes._edge_capacity + row]))
		if code != &"": return code
	return &""


static func _publish_locations(locations: Locations, lease: int, chain: PackedInt32Array) -> StringName:
	"""Second publication: the now-disconnected stations leave the Locations bank (Locations refuses one an actor or
	a container still holds). Refused, the stations stay live and disconnected, with nothing else changed."""
	var begun: Locations.Result = locations.begin_prepare(lease)
	var code: StringName = begun.error
	for at: int in range(0, chain.size(), 2):
		if code == &"": code = locations.stage_remove(begun.token, Vector2i(chain[at], chain[at + 1]))
	if code == &"": code = locations.seal(begun.token)
	if code == &"" and not locations.publish(begun.token): code = REFUSE_LOCATIONS
	if code != &"" and begun.token != 0: locations.abort(begun.token)
	return code
