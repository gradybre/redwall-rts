extends RefCounted
## The tunnels' root cellars as the pantry's food stores. Decision 0196 (live demo). Presentation only.
##
## burrow_chambers.gd publishes its finished root cellars through THE CELLAR API (`cellars()`:
## {"id": Vector2i(slot, generation), "position": Vector3, "capacity_u", "spoilage_permille"}); the
## pantry takes stores through farm_storage.gd's STORAGE-PROVIDER API. The two nearly agree, and this
## is the small adapter demo_village.gd hands the farm (`storage_providers()`). It changes exactly three
## things and passes the rest through unaltered:
##   * the ID: the provider API takes a StringName, String or int and refuses anything else (a
##     Vector2i id would be dropped and counted, never stored in), so a cellar's (slot, generation)
##     becomes &"root_cellar:<slot>:<generation>" -- still stable while the cellar exists, and a dug-
##     over slot's new cellar is a new store;
##   * a LABEL, "Root cellar <slot + 1>", for the Pantry view;
##   * the POSITION a carrier delivers to: the cellar's DOOR -- the network's mouth nearest the chamber
##     by the walk through the tunnels (a cellar is a room off a bore; the way in is down the tunnels;
##     decision 0208) -- rather than the chamber's centre, which can lie under a bed or between beds where
##     nobody can stand. A cellar whose bore is not open, or leads to no mouth, is reached where it lies.
## The capacity (a demo value, burrow_chambers CELLAR_CAPACITY_U) and the spoilage (the GDD's cellar
## store factor 350 per mille) are the chambers' own. Harvests are carried to the door, so a cellar
## dug near the beds shortens the haul -- and the pantry sends each harvest to the slowest-spoiling
## store with room, the nearest to its bed on a tie (farm_pantry.gd `location_near_into`).

const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")

const ID_FORMAT: String = "root_cellar:%d:%d"
const LABEL_FORMAT: String = "Root cellar %d"


static func entries(chambers: ChambersScript, network: GraphScript) -> Array:
	"""Every finished root cellar as a storage-provider entry (allocates: the pantry asks hourly)."""
	var out: Array = []
	for cellar: Dictionary in chambers.cellars():
		var ref: Vector2i = cellar["id"]
		out.append({
			StorageScript.KEY_ID: StringName(ID_FORMAT % [ref.x, ref.y]),
			StorageScript.KEY_POSITION: door_of(chambers, network, ref.x, cellar["position"]),
			StorageScript.KEY_CAPACITY_U: cellar["capacity_u"],
			StorageScript.KEY_PERMILLE: cellar["spoilage_permille"],
			StorageScript.KEY_LABEL: LABEL_FORMAT % (ref.x + 1),
		})
	return out


static func door_of(chambers: ChambersScript, network: GraphScript, c: int, centre: Vector3) -> Vector3:
	"""Where chamber `c` is entered: the mouth nearest it by the walk through the network, on the ground;
	`centre` when its bore is not open or no mouth is reached from it."""
	var slot: int = chambers.tunnel[c]
	if network == null or slot < 0 or slot >= network.phase.size() or not network.is_open(slot):
		return centre
	var best := -1
	var best_cost := PathsScript.UNREACHED
	for end in 2:
		var node: int = network.end_node(slot, end == 1)
		var run: int = network.length_u[slot] - chambers.along_u[c] if end == 1 else chambers.along_u[c]
		var m: int = network.paths.nearest_mouth(network, node, PathsScript.CLASS_ANY)
		var cost: int = run + network.paths.dist_u(network, PathsScript.CLASS_ANY, m, node) if m >= 0 else PathsScript.UNREACHED
		if cost < best_cost:
			best_cost = cost
			best = m
	if best < 0:
		return centre
	var at: Vector2 = network.mouth_at(best)
	return Vector3(at.x, 0.0, at.y)


static func provider(chambers: ChambersScript, network: GraphScript) -> Callable:
	"""The storage provider over these chambers and their tunnels: `() -> Array` of entries."""
	return func() -> Array: return entries(chambers, network)
