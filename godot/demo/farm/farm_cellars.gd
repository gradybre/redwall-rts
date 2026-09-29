extends RefCounted
## The tunnels' root cellars as the pantry's food stores. Decision 0196 (live demo). Presentation only.
##
## burrow_chambers.gd publishes its finished root cellars through THE CELLAR API (`cellars()`:
## {"id": Vector2i(slot, generation), "position": Vector3, "capacity_u", "spoilage_permille"}); the
## pantry takes stores through farm_storage.gd's STORAGE-PROVIDER API. The two nearly agree, and this
## is the small adapter demo_village.gd hands the farm (`storage_providers()`). It changes exactly two
## things and passes the rest through unaltered:
##   * the ID: the provider API takes a StringName, String or int and refuses anything else (a
##     Vector2i id would be dropped and counted, never stored in), so a cellar's (slot, generation)
##     becomes &"root_cellar:<slot>:<generation>" -- still stable while the cellar exists, and a dug-
##     over slot's new cellar is a new store;
##   * a LABEL, "Root cellar <slot + 1>", for the Pantry view.
## The capacity (a demo value, burrow_chambers CELLAR_CAPACITY_U) and the spoilage (the GDD's cellar
## store factor 350 per mille) are the chambers' own. The position is the cellar's centre on the
## ground: harvests are carried there, so a cellar dug near the beds shortens the haul -- and the
## pantry sends each harvest to the slowest-spoiling store with room, the nearest to its bed on a tie
## (farm_pantry.gd `location_near_into`).

const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")

const ID_FORMAT: String = "root_cellar:%d:%d"
const LABEL_FORMAT: String = "Root cellar %d"


static func entries(chambers: ChambersScript) -> Array:
	"""Every finished root cellar as a storage-provider entry (allocates: the pantry asks hourly)."""
	var out: Array = []
	for cellar: Dictionary in chambers.cellars():
		var ref: Vector2i = cellar["id"]
		out.append({
			StorageScript.KEY_ID: StringName(ID_FORMAT % [ref.x, ref.y]),
			StorageScript.KEY_POSITION: cellar["position"],
			StorageScript.KEY_CAPACITY_U: cellar["capacity_u"],
			StorageScript.KEY_PERMILLE: cellar["spoilage_permille"],
			StorageScript.KEY_LABEL: LABEL_FORMAT % (ref.x + 1),
		})
	return out


static func provider(chambers: ChambersScript) -> Callable:
	"""The storage provider over these chambers: `() -> Array` of entries (see the header)."""
	return func() -> Array: return entries(chambers)
