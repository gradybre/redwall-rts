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
## hatch; decision 0209), where the rooms put it. The capacity (its racks', room_fixtures.gd) and the spoilage (the
## GDD's cellar store factor 350 per mille while it is cool, the pantry's 750 when not) are the rooms' own.
## CARRIED IN (decision 0210): a carrier who can take its load down (resident_brain.gd `can_haul_below`) walks it in at
## the hatch to the cellar's middle, faces its racks and shelves it (farm_crew.gd; `room_of`, `rack_at`); one who cannot
## leaves it at the hatch as before. The capacity is now the cellar's racks' and the spoilage the cool rule's
## (room_fixtures.gd).
## ITS CLASS AND ITS WHY (decision 0611): a cool cellar is §5.8's CELLAR class, a warm one keeps like a PANTRY (the cool
## rule's 750), and its WHY is the cool rule's own words for it ("cool: deep, racked and away from any hearth", "warm: a
## hearth within 3 m of it warms it"), so the Pantry can say why food lasts longer there (farm_storage.gd STORAGE CLASS).
## Harvests are carried to the hatch, so a cellar dug near the beds shortens the haul -- and the pantry sends
## each harvest to the slowest-spoiling store with room, the nearest to its bed on a tie (farm_pantry.gd
## `location_near_into`).

const StorageScript := preload("res://demo/farm/farm_storage.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")

const ID_FORMAT: String = "root_cellar:%d:%d"
const ID_PREFIX: String = "root_cellar:"
const LABEL_FORMAT: String = "Root cellar %d"


static func entries(network: GraphScript) -> Array:
	"""Every dug root cellar as a storage-provider entry (allocates: the pantry asks hourly)."""
	var out: Array = []
	for cellar: Dictionary in network.rooms.cellars(network):
		var ref: Vector2i = cellar["id"]
		var cool: int = network.fit.cool(network, ref.x)
		out.append({
			StorageScript.KEY_ID: StringName(ID_FORMAT % [ref.x, ref.y]),
			StorageScript.KEY_POSITION: cellar["position"],
			StorageScript.KEY_CAPACITY_U: cellar["capacity_u"],
			StorageScript.KEY_PERMILLE: cellar["spoilage_permille"],
			StorageScript.KEY_LABEL: LABEL_FORMAT % (ref.x + 1),
			StorageScript.KEY_CLASS: class_of_cool(cool),
			StorageScript.KEY_WHY: FixturesScript.COOL_WORDS[cool],
		})
	return out


static func class_of_cool(cool: int) -> int:
	"""A cellar's storage class under the cool rule (room_fixtures.gd COOL_*): CELLAR while it is cool, else PANTRY."""
	return StockAge.STORAGE_CELLAR if cool == FixturesScript.COOL_YES else StockAge.STORAGE_PANTRY


static func room_of(id: Variant) -> Vector2i:
	"""The (room row, generation) a root cellar's storage id names ("root_cellar:<slot>:<generation>"); (-1, 0) for any
	other store."""
	var text := String(id) if id is StringName or id is String else ""
	if not text.begins_with(ID_PREFIX):
		return Vector2i(-1, 0)
	var parts := text.trim_prefix(ID_PREFIX).split(":")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i(-1, 0)


static func rack_at(network: GraphScript, r: int) -> Vector2:
	"""Where cellar `r`'s first installed storage fixture stands (m), the way a carrier faces to shelve; its middle
	when it has none."""
	var fit: FixturesScript = network.fit
	var template: int = network.rooms.template[r]
	for f in RoomsScript.fixture_count(template):
		if fit.phase_of(network, r, f) == FixturesScript.INSTALLED and FixturesScript.is_storage(FixturesScript.place_kind(template, f)):
			var at := network.rooms.to_world_u(r, FixturesScript.place_u(template, f))
			return Vector2(Rules.to_m(at.x), Rules.to_m(at.y))
	return network.rooms.centre_m(r)


static func provider(network: GraphScript) -> Callable:
	"""The storage provider over this network's root cellars: `() -> Array` of entries."""
	return func() -> Array: return entries(network)
