extends Node3D
## The live demo's kitchen in the village: the meal loop (kitchen.gd) run each frame on the one calendar, drawn
## (kitchen_view.gd), and wired to the Pantry's Kitchen tab, the party panel's fed line, the roster, the top bar and the
## night's early riser. Decision 0381. Presentation only: it writes nothing into the settlement simulation.
##
## THE KITCHEN PANTRY. The kitchen keeps a store of its own at its door: a pantry location (farm_storage.gd's
## provider API, `pantry_provider`) at GDD §5.8's PANTRY factor (750 per mille), PANTRY_CAPACITY_U (a demo value).
## Harvests go to the slowest-spoiling store with room (farm_pantry.gd): a cool root cellar first, then this pantry,
## then the covered store. The covered store is 9 m from the cauldron: on the demo calendar since decision 0421 (25 s a
## game hour) the cook's round to it and back is under a game hour, but each meal's fetch is a trip; a pantry at the
## kitchen's door keeps the round short (it was made when a metre of walking cost 0.4 game hours and that round took
## most of a day); a cellar dug near the kitchen keeps the food longer for the same walk.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const ViewScript := preload("res://demo/kitchen/kitchen_view.gd")
const TabScript := preload("res://demo/kitchen/kitchen_tab.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")

const PANTRY_ID: StringName = &"kitchen_pantry"
const PANTRY_LABEL: String = "Kitchen pantry"
const PANTRY_CAPACITY_U: int = 120
const PANTRY_PERMILLE: int = StockAge.STORE_FACTOR[StockAge.STORAGE_PANTRY]
## The pantry's door, where it is delivered to and fetched from: the end of the path to the kitchen, between the
## kitchen and the cauldron -- the open ground there (the kitchen's walls, the cauldron and the crates leave under
## half a metre's clearance nearer the door; measured on the cast's obstacles, 2026-10-01). A demo value.
const PANTRY_AT: Vector2 = Vector2(10.5, -2.6)
## The layout's pieces the kitchen works at (world_layout.gd).
const CAULDRON_ID: StringName = &"cauldron"
const TABLE_E_ID: StringName = &"table_e"
const TABLE_W_ID: StringName = &"table_w"
const WELL_ID: StringName = &"well"
const BUTT_ID: StringName = &"bucket"
## The world's own work spots at the cauldron and the well (world_layout.gd POINTS).
const CAULDRON_POI: StringName = &"cauldron"
const WELL_POI: StringName = &"well_drink"

var kitchen: KitchenScript = KitchenScript.new()
var places: PlacesScript = PlacesScript.new()
var view: ViewScript = ViewScript.new()
var tab: TabScript = TabScript.new()

var _cast: DemoCastScript = null


func configure(cast: DemoCastScript, pantry: PantryScript, services: ServicesScript, goods: GoodsScript,
		night: NightScript) -> void:
	"""The kitchen for this cast, cooking from this pantry and the village's stores on its calendar, saying so in its
	news; the cook the night's early riser."""
	name = "DemoKitchen"
	_cast = cast
	_build_places(cast)
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var species := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		species.append(actor.species)
		keys.append(actor.creature_key)
	kitchen.bind_news(services.notices, services.incidents)
	kitchen.configure(brains, names, species, keys, pantry, services.stores, services.calendar, places)
	if night != null:
		night.set_early_riser(kitchen.up_early)
	add_child(view)
	view.configure(kitchen, cast, cast.clock, goods)


func _build_places(cast: DemoCastScript) -> void:
	"""The cauldron, the hall's east table (seats round both tables), the well and the butt beside it, from the
	layout; every standing spot moved clear on the cast's own ground."""
	places.set_points(_at(Layout.PROPS, CAULDRON_ID), _at(Layout.PROPS, TABLE_E_ID), _at(Layout.BUILDINGS, WELL_ID),
		_at(Layout.PROPS, BUTT_ID))
	places.add_table_seats(_at(Layout.PROPS, TABLE_E_ID), PlacesScript.SEATS_PER_TABLE)
	places.add_table_seats(_at(Layout.PROPS, TABLE_W_ID), PlacesScript.SEATS_PER_TABLE)
	if cast.space() != null:
		places.find_spots(cast.space(), cast.bounds(), CAULDRON_POI, WELL_POI)


static func _at(entries: Array[Dictionary], id: StringName) -> Vector2:
	"""A layout entry's position (the layout's own constants: a missing one is a programming error)."""
	for entry: Dictionary in entries:
		if entry["id"] == id:
			return entry["at"]
	assert(false, "the kitchen needs the layout's %s" % id)
	return Vector2.ZERO


static func pantry_at() -> Vector2:
	"""Where the kitchen pantry is delivered to and fetched from (see PANTRY_AT)."""
	return PANTRY_AT


static func pantry_entries() -> Array:
	"""The kitchen pantry as a storage-provider entry (farm_storage.gd)."""
	return [{StorageScript.KEY_ID: PANTRY_ID, StorageScript.KEY_POSITION: pantry_at(),
		StorageScript.KEY_CAPACITY_U: PANTRY_CAPACITY_U, StorageScript.KEY_PERMILLE: PANTRY_PERMILLE,
		StorageScript.KEY_LABEL: PANTRY_LABEL}]


static func pantry_provider() -> Callable:
	"""The storage provider for the kitchen pantry (demo_village.gd `storage_providers`)."""
	return func() -> Array: return pantry_entries()


func build_tab(members: Callable, interrupt: Callable) -> TabScript:
	"""The Pantry's Kitchen tab over this kitchen (the selection and the cards' interrupt line given)."""
	tab.configure(kitchen, members, interrupt)
	return tab


func _exit_tree() -> void:
	"""Leaving the scene (a Restart): the Kitchen tab, if no Pantry ever took it, is freed with this node, and the
	kitchen lets its residents go (their tasks hold it only weakly; this ends them so nothing outlives the village)."""
	if tab != null and tab.get_parent() == null:
		tab.free()
	if view != null and view.get_parent() == null:
		view.free()
	kitchen.shut_down()


func _process(_delta: float) -> void:
	"""Run the kitchen on this frame's calendar (the farm has advanced it: it is added before this)."""
	kitchen.update()
