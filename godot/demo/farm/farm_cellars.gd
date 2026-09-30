extends RefCounted
## The tunnels' root cellars as the pantry's food stores. Decisions 0196 (live demo) and 0209 (rooms as their
## own structures). Presentation only.
##
## The network's rooms (demo/burrow/underground_rooms.gd) publish their dug root cellars through THE CELLAR API
## (`cellars(graph)`: {"id": Vector2i(slot, generation), "position": Vector3, "capacity_u", "spoilage_permille"}
## -- the shape burrow_chambers.gd published, served from rooms now); the pantry takes stores through
## farm_storage.gd's STORAGE-PROVIDER API. The two nearly agree, and this is the small adapter demo_village.gd
## hands the farm (`storage_providers()`). It changes exactly two things and passes the rest through unaltered:
##   * the ID: the provider API takes a StringName, String or int and refuses anything else (a Vector2i id
##     would be dropped and counted, never stored in), so a cellar's (room slot, generation) becomes
##     &"root_cellar:<slot>:<generation>" -- still stable while the cellar stands, and a room row laid again
##     is a new store;
##   * a LABEL, "Root cellar <slot + 1>" -- the room's own name -- for the Pantry view.
## The POSITION a carrier delivers to is the cellar's HATCH (a cellar is its own room now, entered at its own
## hatch; decision 0209), where the rooms put it. The capacity (a demo value, underground_rooms.gd
## CELLAR_CAPACITY_U) and the spoilage (the GDD's cellar store factor 350 per mille) are the rooms' own.
## Harvests are carried to the hatch, so a cellar dug near the beds shortens the haul -- and the pantry sends
## each harvest to the slowest-spoiling store with room, the nearest to its bed on a tie (farm_pantry.gd
## `location_near_into`).

const StorageScript := preload("res://demo/farm/farm_storage.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const ID_FORMAT: String = "root_cellar:%d:%d"
const LABEL_FORMAT: String = "Root cellar %d"


static func entries(network: GraphScript) -> Array:
	"""Every dug root cellar as a storage-provider entry (allocates: the pantry asks hourly)."""
	var out: Array = []
	for cellar: Dictionary in network.rooms.cellars(network):
		var ref: Vector2i = cellar["id"]
		out.append({
			StorageScript.KEY_ID: StringName(ID_FORMAT % [ref.x, ref.y]),
			StorageScript.KEY_POSITION: cellar["position"],
			StorageScript.KEY_CAPACITY_U: cellar["capacity_u"],
			StorageScript.KEY_PERMILLE: cellar["spoilage_permille"],
			StorageScript.KEY_LABEL: LABEL_FORMAT % (ref.x + 1),
		})
	return out


static func provider(network: GraphScript) -> Callable:
	"""The storage provider over this network's root cellars: `() -> Array` of entries."""
	return func() -> Array: return entries(network)
