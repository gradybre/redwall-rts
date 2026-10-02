extends RefCounted
## THE FIELD GUIDE: a linked almanac of what this demo really has (decision 0481; review UX-018). Crops and what they
## are for (the three dishes among them), materials and their uses, buildings and stations, residents' skills, water
## safety, and the fish and preserved food water part B brought (decision 0431) -- each entry with its USES, what it REQUIRES, its ALTERNATIVES, where it is AVAILABLE HERE, and links
## to the entries it names. Plain-language search (guide_search.gd).
##
## ONLY WHAT THE DEMO HAS. The entries are BUILT from the demo's own tables, not written beside them: the crops from
## farm_catalog.gd (every farmed item, nothing else), which dish each feeds from meal_rules.gd `is_input`, a dish's
## inputs, water, wood, work and portions from meal_rules.gd, shelf lives from the catalog's §5.7 rows and the stores'
## factors from stock_age.gd, the fit-out's costs from room_fixtures.gd, the bridges' from swim_rules.gd, the woods'
## from forest_rules.gd, the species' swimming from swim_rules.gd; the fish, dried fish and flour from the catalog's
## pantry goods, fishing from fishery_rules.gd, the rack and the mill from its station numbers, the gear from
## gear_locker.gd. A table changing changes its entry; nothing the demo lacks (the GDD's other dishes, hunting, mead,
## ferries) has one. test_demo_guide_pages.gd checks each against its table.
## `bind_pantry` adds a live "In the pantry now" line to a crop.

const SearchScript := preload("res://demo/guide/guide_search.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const KitchenNode := preload("res://demo/kitchen/demo_kitchen.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Fixtures := preload("res://demo/burrow/room_fixtures.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const DigSkills := preload("res://demo/tunnel/dig_skills.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const GearLocker := preload("res://demo/fishery/gear_locker.gd")

const KIND_CROP: int = 0
const KIND_DISH: int = 1
const KIND_MATERIAL: int = 2
const KIND_STATION: int = 3
const KIND_SKILL: int = 4
const KIND_SAFETY: int = 5
## The pantry's other goods (decision 0431): the catch, dried fish and flour.
const KIND_GOODS: int = 6
const KIND_NAMES: Array[String] = ["Crops", "Dishes", "Materials", "Buildings and stations", "Residents' skills",
	"Water safety", "Fish and preserved food"]
## The crop rows' names as the guide says them (farming.gd's rows: roots, cabbage, beans, grain).
const ROW_WORDS: Dictionary = {FarmingScript.CROP_ROOTS: "Root crop", FarmingScript.CROP_CABBAGE: "Leaf crop",
	FarmingScript.CROP_BEANS: "Pulse", FarmingScript.CROP_GRAIN: "Grain"}
const DISH_IDS: Array[StringName] = [&"dish_porridge", &"dish_soup", &"dish_fish_stew"]
## The catch's waters, by item from Catalog.FIRST_CATCH (fishing_driver.gd HABITATS: the stream is the river habitat,
## the pond the lake's).
const CATCH_WATERS: Array[String] = ["the stream", "the stream", "the stream", "the pond", "the pond", "the pond"]


## One entry.
class Entry extends RefCounted:
	var id: StringName = &""
	var kind: int = 0
	var title: String = ""
	var summary: String = ""
	var uses: String = ""
	var requires: String = ""
	var alternatives: String = ""
	var here: String = ""
	var links: Array[StringName] = []
	## A crop's pantry item (Catalog.NO_ITEM otherwise), for the live stock line.
	var item: int = Catalog.NO_ITEM


var _entries: Array[Entry] = []
var _index: Array[SearchScript.Entry] = []
var _by_id: Dictionary = {}
var _pantry: PantryScript = null


func _init() -> void:
	"""Build every entry from the demo's tables (see ONLY WHAT THE DEMO HAS) and index it."""
	for item: int in Catalog.ITEM_COUNT:
		_add(_crop(item))
	for dish: int in Rules.DISH_COUNT:
		_add(_dish(dish))
	for item: int in range(Catalog.ITEM_COUNT, Catalog.PANTRY_ITEM_COUNT):
		_add(_goods(item))
	_add_materials()
	_add_stations()
	_add_skills()
	_add_safety()
	for listed: Entry in _entries:
		_index.append(SearchScript.Entry.new(listed.title, "%s %s" % [KIND_NAMES[listed.kind], listed.summary],
			" ".join([listed.uses, listed.requires, listed.alternatives, listed.here])))


func bind_pantry(pantry: PantryScript) -> void:
	"""Read crops' stock live from this pantry ("In the pantry now")."""
	_pantry = pantry


func _add(filed: Entry) -> void:
	"""File one entry under its id."""
	_by_id[filed.id] = _entries.size()
	_entries.append(filed)


static func make(id: StringName, kind: int, title: String, summary: String, fields: PackedStringArray,
		links: Array[StringName]) -> Entry:
	"""An entry from [uses, requires, alternatives, here]."""
	var made := Entry.new()
	made.id = id
	made.kind = kind
	made.title = title
	made.summary = summary
	made.uses = fields[0]
	made.requires = fields[1]
	made.alternatives = fields[2]
	made.here = fields[3]
	made.links = links
	return made


static func crop_id(item: int) -> StringName:
	"""A crop entry's id."""
	return StringName("crop_%s" % Catalog.ITEM_KEYS[item])


# --- crops and dishes --------------------------------------------------------------------------------

func _crop(item: int) -> Entry:
	"""A farmed item: the dish it feeds (or none), its bed and shelf life, its row-mates, where it grows."""
	var row: int = Catalog.ITEM_CROP[item]
	var links: Array[StringName] = [&"station_beds", &"station_store", &"station_cellar"]
	var uses: String = _crop_uses(item, links)
	var shelf: int = Catalog.CROP_SHELF_HOURS[row]
	@warning_ignore("integer_division") var requires: String = "A crop bed, sown in its planting window (the bed's Plant… says when). Keeps %d game hours in the covered store, about %d in a cool root cellar." % [shelf, shelf * StockAge.STORE_FACTOR[StockAge.STORAGE_COVERED_STORE] / StockAge.STORE_FACTOR[StockAge.STORAGE_CELLAR]]
	var made: Entry = make(crop_id(item), KIND_CROP, Catalog.ITEM_LABELS[item],
		String(ROW_WORDS.get(row, "Crop")),
		PackedStringArray([uses, requires, _row_mates(item), _grown_here(item)]), links)
	made.item = item
	return made


func _crop_uses(item: int, links: Array[StringName]) -> String:
	"""What the item is for: the dish that cooks it, and raw food for the hungry."""
	var parts := PackedStringArray()
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_input(dish, item):
			parts.append("%s (%s): %s makes %d portions" % [Rules.DISH_NAMES[dish], Rules.MEAL_NAMES[meal_of(dish)],
				FarmText.units_text(input_milli(dish, item)), Rules.PORTIONS_PER_BATCH[dish]])
			links.append(DISH_IDS[dish])
	if Rules.raw_np_per_u(item) > 0:
		parts.append("eaten raw by a hungry resident when a meal is missed (%d NP a unit)" % Rules.raw_np_per_u(item))
	if parts.is_empty():
		return "None of the demo's dishes cooks it yet: it is grown and stored."
	var text: String = "; ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


static func _row_mates(item: int) -> String:
	"""The other crops of its row, which do the same job."""
	var mates := PackedStringArray()
	for other: int in Catalog.ITEM_COUNT:
		if other != item and Catalog.ITEM_CROP[other] == Catalog.ITEM_CROP[item]:
			mates.append(Catalog.ITEM_LABELS[other].to_lower())
	return "The same row, grown and used alike: %s." % ", ".join(mates) if not mates.is_empty() else "None."


static func _grown_here(item: int) -> String:
	"""Where it grows in this village: a bed that opens with it, else any bed sown with it."""
	for bed: int in Catalog.BED_COUNT:
		if Catalog.BED_START_ITEM[bed] == item:
			return "Growing in bed %d at the start; any of the six beds can be sown with it." % (bed + 1)
	return "Any of the six crop beds can be sown with it."


static func meal_of(dish: int) -> int:
	"""The meal `dish` is cooked for: porridge at breakfast; the soup, and the fish stew in its place, at supper."""
	return Rules.MEAL_BREAKFAST if dish == Rules.DISH_PORRIDGE else Rules.MEAL_SUPPER


static func input_milli(dish: int, item: int) -> int:
	"""How much of `item`'s category a batch of `dish` takes: its main input's, else its second's."""
	return Rules.INPUT_MILLI[dish] if Catalog.category_of(item) == Rules.INPUT_CROP[dish] else Rules.SIDE_MILLI[dish]


static func item_id(item: int) -> StringName:
	"""The entry a pantry item links to: a crop's, else one of the pantry's other goods'."""
	return crop_id(item) if Catalog.is_item(item) else StringName("goods_%s" % Catalog.ITEM_KEYS[item])


func _dish(dish: int) -> Entry:
	"""One of the kitchen's three dishes: its meal, portions, inputs, work and the other dish."""
	var links: Array[StringName] = [&"station_kitchen", &"material_water", &"material_wood"]
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		if Rules.is_input(dish, item):
			links.append(item_id(item))
	links.append(DISH_IDS[Rules.other(dish)])
	var meal: int = meal_of(dish)
	var uses: String = "%s: each batch is %d portions of %d NP, keeping %d game hours." % [Rules.MEAL_TITLES[meal],
		Rules.PORTIONS_PER_BATCH[dish], Rules.NP_PER_PORTION[dish], Rules.SHELF_HOURS[dish]]
	var food: String = "%s of %s (%s)" % [FarmText.units_text(Rules.INPUT_MILLI[dish]), Rules.INPUT_WORDS[dish],
		Rules.INPUT_CROPS_TEXT[dish]]
	if Rules.SIDE_MILLI[dish] > 0:
		food += " and %s of %s" % [FarmText.units_text(Rules.SIDE_MILLI[dish]), Rules.SIDE_WORDS[dish]]
	@warning_ignore("integer_division") var requires: String = "%s, %s of water and %s of wood a batch; %d WU of cooking at the cauldron." % [food,
		FarmText.units_text(Rules.WATER_MILLI[dish]), FarmText.units_text(Rules.WOOD_MILLI_PER_BATCH),
		Rules.WORK_MWU[dish] / 1000]
	var other: String = "When its food is short the cook makes %s instead." % Rules.DISH_NAMES[Rules.other(dish)]
	if dish == Rules.DISH_FISH_STEW:
		other = "Cooked at supper in the soup's place while the stores hold a batch's fresh fish and roots; otherwise %s." \
			% Rules.DISH_NAMES[Rules.other(dish)]
	return make(DISH_IDS[dish], KIND_DISH, Rules.DISH_NAMES[dish], "Cooked for %s" % Rules.MEAL_NAMES[meal],
		PackedStringArray([uses, requires, other, "Cooked at the cauldron by the keeper, served at the hall's tables."]),
		links)


# --- fish and preserved food -------------------------------------------------------------------------

func _goods(item: int) -> Entry:
	"""One of the pantry's other goods (decision 0431): a fish of the catch, dried fish or flour."""
	var links: Array[StringName] = [&"station_store", &"station_fishing"]
	var shelf: int = Catalog.shelf_hours_of(item)
	var fields: PackedStringArray
	var summary: String
	if item == Catalog.ITEM_DRIED_FISH:
		summary = "Fish smoked at the rack"
		links = [&"station_rack_mill", &"station_store"]
		@warning_ignore("integer_division") fields = PackedStringArray([
			"The village's reserve: eaten raw by a hungry resident when a meal is missed (%d NP a unit)." % Rules.raw_np_per_u(item),
			"Drying fresh fish at the rack: %s of fish makes %s, %d WU and %d hours' curing." % [
				FarmText.units_text(FisheryRules.DRY_IN_MILLI), FarmText.units_text(FisheryRules.DRY_OUT_MILLI),
				FisheryRules.DRY_WORK_MWU / 1000, FisheryRules.DRY_PASSIVE_HOURS],
			"Fresh fish, cooked in the fish stew while it keeps (%d game hours)." % Catalog.shelf_hours_of(Catalog.FIRST_CATCH),
			"Keeps %d game hours in store; the Pantry (K) lists it." % shelf])
	elif item == Catalog.ITEM_FLOUR:
		summary = "Grain ground at the mill"
		links = [&"station_rack_mill", &"station_store", &"crop_oats"]
		@warning_ignore("integer_division") fields = PackedStringArray([
			"Kept as stock for later baking: none of the demo's dishes uses it yet, and it is not eaten raw.",
			"Milling grain: %s of grain makes %s, %d WU." % [FarmText.units_text(FisheryRules.MILL_IN_MILLI),
				FarmText.units_text(FisheryRules.MILL_OUT_MILLI), FisheryRules.MILL_WORK_MWU / 1000],
			"Unground grain cooks as porridge.", "Keeps %d game hours in store; the Pantry (K) lists it." % shelf])
	else:
		var water: String = CATCH_WATERS[item - Catalog.FIRST_CATCH]
		summary = "Fresh fish from %s" % water
		links.append(&"dish_fish_stew")
		links.append(&"goods_dried_fish")
		fields = PackedStringArray([
			"%s (supper): %s of fresh fish with %s of roots makes %d portions; or dried at the rack." % [
				Rules.DISH_NAMES[Rules.DISH_FISH_STEW], FarmText.units_text(Rules.INPUT_MILLI[Rules.DISH_FISH_STEW]),
				FarmText.units_text(Rules.SIDE_MILLI[Rules.DISH_FISH_STEW]), Rules.PORTIONS_PER_BATCH[Rules.DISH_FISH_STEW]],
			"An authorised fishing trip (the Water panel's Fishing) and its gear; keeps only %d game hours, and is never eaten raw." % shelf,
			"The other fish of the catch; dried fish keeps far longer.",
			"Fished in %s." % water])
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], summary, fields, links)
	made.item = item
	return made


# --- materials ---------------------------------------------------------------------------------------

func _add_materials() -> void:
	"""Wood, planks, stone, earth, compost and water: what each is for, where it comes from."""
	_add(_material_wood())
	_add(_material_planks())
	_add(_material_stone())
	_add(_material_earth())
	_add(_material_compost())
	_add(_material_water())
	_add(_material_gear())


static func _material_wood() -> Entry:
	"""The material wood entry."""
	return make(&"material_wood", KIND_MATERIAL, "Wood", "Logs from the woods", PackedStringArray([
		"Sawn into planks (%s of wood makes %s of planks); a log bridge's log (%s); a pier (%s each); the kitchen's fire (%s a batch); a lantern, a rag rug or hanging stores (%s each); bracing tunnels." % [
			FarmText.units_text(ForestRules.SAW_BATCH_MILLI), FarmText.units_text(ForestRules.SAW_BATCH_MILLI),
			FarmText.units_text(SwimRules.LOG_WOOD_MILLI), FarmText.units_text(SwimRules.PIER_WOOD_MILLI),
			FarmText.units_text(Rules.WOOD_MILLI_PER_BATCH), FarmText.units_text(Fixtures.COST_WOOD_MILLI[RoomsScript.FIX_RUG])],
		"Felling a mature tree (%s of logs, hauled to the log stack), or gathering deadfall (%s to %s a pile, no felling)." % [
			FarmText.units_text(ForestRules.TREE_WOOD_MILLI), FarmText.units_text(ForestRules.DEADFALL_MIN_MILLI),
			FarmText.units_text(ForestRules.DEADFALL_MAX_MILLI)],
		"Deadfall in protected woods; planks where a bridge or furniture needs them.",
		"The village stores open with %s; the top bar's Wood." % FarmText.units_text(StoresScript.START_WOOD_MILLI_U)]),
		[&"material_planks", &"skill_felling", &"station_sawhorse", &"station_bridges", &"dish_porridge"])


static func _material_planks() -> Entry:
	"""The material planks entry."""
	return make(&"material_planks", KIND_MATERIAL, "Planks", "Sawn wood", PackedStringArray([
		"A plank footbridge (%s a metre of deck); beds (%s), a large bed (%s), shelves, racks, root bins and a table." % [
			FarmText.units_text(SwimRules.PLANK_MILLI_PER_M), FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BED]),
			FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BIG_BED])],
		"Sawing logs at the sawhorse (%d WU a batch)." % ForestRules.SAW_WU,
		"A log bridge needs a log, not planks.", "The plank stack by the workbench; the top bar's Planks (in Fuel's slot)."]),
		[&"material_wood", &"station_sawhorse", &"station_bridges", &"station_burrow"])


static func _material_stone() -> Entry:
	"""The material stone entry."""
	return make(&"material_stone", KIND_MATERIAL, "Stone", "Quarried stone", PackedStringArray([
		"A hearth (%s); bracing tunnels against floods and collapses." % FarmText.units_text(Fixtures.COST_STONE_MILLI[RoomsScript.FIX_HEARTH]),
		"The village's opening stock; a diver's find adds a little.", "None in this demo.",
		"The village stores open with %s; the top bar's Stone." % FarmText.units_text(StoresScript.START_STONE_MILLI_U)]),
		[&"station_tunnels", &"station_burrow"])


static func _material_earth() -> Entry:
	"""The material earth entry."""
	return make(&"material_earth", KIND_MATERIAL, "Earth", "Dug out of tunnels", PackedStringArray([
		"Raising a bed (drains it, warmer at night) or banking one (keeps half of a dry day's loss): 2 U each. Earth is never compost.",
		"Digging tunnels and rooms: it piles on the spoil heaps; Clear hauls a heap to the stores.",
		"Drain a wet bed with a ditch instead (no earth needed).", "The spoil heaps by every tunnel mouth, and the stores."]),
		[&"station_tunnels", &"station_beds", &"skill_digging"])


static func _material_compost() -> Entry:
	"""The material compost entry."""
	return make(&"material_compost", KIND_MATERIAL, "Compost", "Plant waste", PackedStringArray([
		"Composting a bed (raises its fertility); planting a sapling (0.25 U).",
		"A cleared crop (0.5 U), and spoiled food at 4 : 2 (the Pantry's compost button).",
		"Resting a bed fallow raises fertility without compost.", "The farm's compost store."]),
		[&"station_beds", &"station_store"])


static func _material_water() -> Entry:
	"""The material water entry."""
	return make(&"material_water", KIND_MATERIAL, "Water", "Drawn at the well", PackedStringArray([
		"Cooking: %s for a batch of porridge, %s for soup, %s for the fish stew." % [
			FarmText.units_text(Rules.WATER_MILLI[Rules.DISH_PORRIDGE]), FarmText.units_text(Rules.WATER_MILLI[Rules.DISH_SOUP]),
			FarmText.units_text(Rules.WATER_MILLI[Rules.DISH_FISH_STEW])],
		"Anyone free draws it into the butt (Keep water drawn, in the Kitchen tab).", "None: the dishes need it.",
		"The butt by the well holds %s." % FarmText.units_text(StoresScript.WATER_CAP_MILLI_U)]),
		[&"station_kitchen", &"dish_porridge", &"dish_soup", &"dish_fish_stew"])


static func _material_gear() -> Entry:
	"""Fishing gear, from gear_locker.gd: what each piece is made of, and mending."""
	var parts := PackedStringArray()
	for kind: int in [GearLocker.KIND_NET, GearLocker.KIND_TRAP, GearLocker.KIND_ICE_KIT]:
		@warning_ignore("integer_division") parts.append("a %s (%s of wood, %s of %s, %d WU)" % [GearLocker.KIND_NAMES[kind],
			FarmText.units_text(GearLocker.MAKE_WOOD_MILLI[kind]), FarmText.units_text(GearLocker.MAKE_MATERIAL_MILLI[kind]),
			GearLocker.MAT_NAMES[GearLocker.MAKE_MATERIAL[kind]], GearLocker.MAKE_MWU[kind] / 1000])
	@warning_ignore("integer_division") return make(&"material_gear", KIND_MATERIAL, "Fishing gear", "Nets, traps and ice kits", PackedStringArray([
		"A trip takes its method's gear: a hand net, a trap, the boat, or an ice kit with a winter outfit; each wears with use.",
		"Made at the gear locker: %s." % "; ".join(parts),
		"Mend gear instead of making it again (%s of wood and %s of rope, %d WU)." % [FarmText.units_text(GearLocker.MEND_WOOD_MILLI),
			FarmText.units_text(GearLocker.MEND_ROPE_MILLI), GearLocker.MEND_MWU / 1000],
		"The gear locker; the Water panel's Fishing lists each piece's wear."]), [&"station_fishing", &"material_wood"])


# --- buildings and stations --------------------------------------------------------------------------

func _add_stations() -> void:
	"""The beds, the stores, the kitchen, the sawhorse, homes, cellars, tunnels and bridges."""
	_add(_station_beds())
	_add(_station_store())
	_add(_station_kitchen())
	_add(_station_sawhorse())
	_add(_station_burrow())
	_add(_station_cellar())
	_add(_station_tunnels())
	_add(_station_bridges())
	_add(_station_fishing())
	_add(_station_rack_mill())


static func _station_beds() -> Entry:
	"""The station beds entry."""
	return make(&"station_beds", KIND_STATION, "Crop beds", "Six beds by the square", PackedStringArray([
		"Growing the village's food: sow, water, drain, cover, raise, harvest, clear, compost.",
		"A crop in its planting window; moisture in the crop's band; no frost on an uncovered crop.",
		"None: food grows only in the beds here.", "Six beds; click one for its panel."]), [&"crop_carrot", &"material_earth", &"material_compost"])


static func _station_store() -> Entry:
	"""The station store entry."""
	return make(&"station_store", KIND_STATION, StorageScript.STORE_LABEL, "Where harvests go", PackedStringArray([
		"Keeping food (%d U); spoils at the GDD's covered-store rate (%d per mille)." % [StorageScript.STORE_CAPACITY_U,
			StockAge.STORE_FACTOR[StockAge.STORAGE_COVERED_STORE]],
		"Room for the harvest (a harvest reserves its room before it is cut).",
		"A cool root cellar keeps food about three times as long; the kitchen pantry slows it a little.",
		"By the square; the Pantry (K) lists it."]), [&"station_cellar", &"station_kitchen"])


static func _station_kitchen() -> Entry:
	"""The station kitchen entry."""
	return make(&"station_kitchen", KIND_STATION, "The kitchen", "Cauldron, kitchen pantry and hall tables", PackedStringArray([
		"Cooking breakfast and supper; the %s keeps %d U at %d per mille." % [KitchenNode.PANTRY_LABEL.to_lower(),
			KitchenNode.PANTRY_CAPACITY_U, StockAge.STORE_FACTOR[StockAge.STORAGE_PANTRY]],
		"A cook (the keeper, or anyone free), food, water in the butt and wood.", "Raw food for the hungry when a meal is missed.",
		"The cauldron east of the square; the hall's tables; the Pantry's Kitchen tab."]),
		[&"dish_porridge", &"dish_soup", &"dish_fish_stew", &"material_water", &"skill_cooking"])


static func _station_sawhorse() -> Entry:
	"""The station sawhorse entry."""
	return make(&"station_sawhorse", KIND_STATION, "Sawhorse and yard", "Logs into planks", PackedStringArray([
		"Sawing logs into planks; the log stack and plank stack keep them.", "Logs in the stores.", "None.",
		"By the workbench; right-click it with residents selected."]), [&"material_wood", &"material_planks", &"skill_felling"])


static func _station_burrow() -> Entry:
	"""The station burrow entry."""
	return make(&"station_burrow", KIND_STATION, "Burrow home", "A dug home with beds", PackedStringArray([
		"Beds for the night (a bed %s, a large bed %s), a hearth, table, rug, lantern: comfort." % [
			FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BED]),
			FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BIG_BED])],
		"Dug by a digger from the Dig tool (H); fitted out from the stores.", "Without a bed a resident sleeps on the hall's floor.",
		"Wherever you dig one."]), [&"skill_digging", &"material_planks", &"station_tunnels"])


static func _station_cellar() -> Entry:
	"""The station cellar entry."""
	return make(&"station_cellar", KIND_STATION, "Root cellar", "A cool store below ground", PackedStringArray([
		"Keeping food at the GDD's cellar rate (%d per mille) while it is 1 m down, racked, and no hearth is near." % StockAge.STORE_FACTOR[StockAge.STORAGE_CELLAR],
		"Dug from the Dig tool (C), then racked: a shelf %d U, a pantry rack %d U, a root bin %d U." % [
			Fixtures.CAPACITY_U[RoomsScript.FIX_SHELF], Fixtures.CAPACITY_U[RoomsScript.FIX_RACK], Fixtures.CAPACITY_U[RoomsScript.FIX_BIN]],
		"The covered store (faster spoiling).", "Wherever you dig one; harvests go there first."]),
		[&"station_store", &"skill_digging", &"material_planks"])


static func _station_tunnels() -> Entry:
	"""The station tunnels entry."""
	return make(&"station_tunnels", KIND_STATION, "Tunnels", "Dug ways below", PackedStringArray([
		"Routes in any weather (rain and snow do not slow walkers below); draining the beds above; reaching homes and cellars.",
		"A digger who fits the bore (mice, moles, squirrels); 8 m at least, mouth to mouth.",
		"A bridge or the ford over the stream.", "Wherever you dig them (B); they cannot pass under water."]),
		[&"skill_digging", &"material_earth", &"station_bridges"])


static func _station_bridges() -> Entry:
	"""The station bridges entry."""
	@warning_ignore("integer_division") return make(&"station_bridges", KIND_STATION, "Bridges", "Dry ways over the stream", PackedStringArray([
		"Crossing the stream dry, carrying or not, the badger too.",
		"A plank footbridge: %s a metre of deck (and a pier per 2.5 m over 3.5 m). A log bridge: one %s log, at most 5.5 m of deck." % [
			FarmText.units_text(SwimRules.PLANK_MILLI_PER_M), FarmText.units_text(SwimRules.LOG_WOOD_MILLI)],
		"The ford (wading at %d%% pace); swimming, unladen." % (SwimRules.WADE_PERMILLE / 10),
		"Three sites on the stream, or any two banks (the Water panel)."]),
		[&"material_planks", &"material_wood", &"skill_bridges", &"safety_wading"])

static func _station_fishing() -> Entry:
	"""Fishing trips, the boats and the jetty, from fishery_rules.gd."""
	var parts := PackedStringArray()
	for method: int in FisheryRules.METHOD_COUNT:
		parts.append("%s: %s" % [FisheryRules.METHOD_NAMES[method], FisheryRules.METHOD_ROLES[method]])
	return make(&"station_fishing", KIND_STATION, "Fishing, boats and the jetty", "Trips that feed the pantry",
		PackedStringArray([
		"Catching fish for the pantry: %s." % "; ".join(parts),
		"A trip authorised in the Water panel (its site, method and fish, with the stock, quota, expected catch and risk shown first), its gear, and fishers free; the boat's crew is %d." % FisheryRules.METHOD_CREW[FisheryRules.METHOD_BOAT],
		"The crops and the porridge and soup feed the village without fish.",
		"Banks at %s; the boats at the pond's jetty; the Water panel's Fishing and Boats." % ", ".join(FisheryRules.SITE_NAMES)]),
		[&"material_gear", &"goods_trout", &"goods_perch", &"safety_rescue"])


static func _station_rack_mill() -> Entry:
	"""The drying rack and the mill, from fishery_rules.gd."""
	return make(&"station_rack_mill", KIND_STATION, "Drying rack and mill", "Fish kept, grain ground", PackedStringArray([
		"Drying fish into the village's reserve (%d slots); grinding grain into flour (%d at a time)." % [
			FisheryRules.RACK_SLOTS, FisheryRules.MILL_SLOTS],
		"Fresh fish for the rack (%s a batch); grain for the mill (%s a batch); a resident to work each batch." % [
			FarmText.units_text(FisheryRules.DRY_IN_MILLI), FarmText.units_text(FisheryRules.MILL_IN_MILLI)],
		"Cook fresh fish in the stew instead of drying it.", "The Water panel's Drying rack and mill: Dry fish, Mill grain."]),
		[&"goods_dried_fish", &"goods_flour", &"station_store"])


# --- residents' skills -------------------------------------------------------------------------------

func _add_skills() -> void:
	"""What residents can learn and do, and who starts able."""
	_add(_skill_digging())
	_add(_skill_felling())
	_add(_skill_bridges())
	_add(_skill_swimming())
	_add(_skill_cooking())


static func _skill_digging() -> Entry:
	"""The digging skill entry."""
	return make(&"skill_digging", KIND_SKILL, DigSkills.NAME, "Tunnels and rooms", PackedStringArray([
		"Digging tunnels, burrow homes and root cellars; widening a tunnel so otters and the badger fit.",
		"A body that fits the bore: mice, moles and squirrels. Everyone learns as they dig; the skill speeds the crew.",
		"The badger cannot fit a bore but breaks rock for a dig crew.",
		"The moles start at %s %d." % [DigSkills.NAME, DigSkills.SKILLED_LEVEL]]), [&"station_tunnels", &"material_earth"])


static func _skill_felling() -> Entry:
	"""The felling and sawing skill entry."""
	return make(&"skill_felling", KIND_SKILL, "Felling and sawing", "The woods' work", PackedStringArray([
		"Felling trees, gathering deadfall, sawing planks; the beaver gnaws instead of using an axe.",
		"Anybody learns by working (10 XP a WU); work time falls as the level rises.",
		"Deadfall needs no felling skill at all.", "The squirrel forester and the beaver start at felling 3."]),
		[&"material_wood", &"material_planks", &"station_sawhorse"])


static func _skill_bridges() -> Entry:
	"""The bridge-building skill entry."""
	@warning_ignore("integer_division") var level: int = int(sqrt(float(SwimRules.BRIDGEWRIGHT_XP / 5000)))
	return make(&"skill_bridges", KIND_SKILL, "Bridge building", "Piers, beams, deck", PackedStringArray([
		"Building a bridge: fetching its material, then piers, beams and deck.",
		"Anybody can build one, at the woods' work rate and their skill.",
		"Selecting nobody leaves a bridge to the bridgewright.", "The beaver bridgewright starts at level %d." % level]),
		[&"station_bridges", &"material_planks"])


static func _skill_swimming() -> Entry:
	"""Swimming and diving by species, from swim_rules.gd."""
	var parts := PackedStringArray()
	for k: int in SwimRules.SPECIES.size():
		parts.append("%s %s" % [SwimRules.SPECIES[k], SwimRules.SWIM_WORDS[k]])
	return make(&"skill_swimming", KIND_SKILL, "Swimming and diving", "Who can go in the water", PackedStringArray([
		"Crossing deep water unladen, rescuing a swimmer in difficulty; diving for finds (otters only).",
		"By species: %s." % "; ".join(parts), "A bridge or the ford for anyone carrying, and for the badger.",
		"The stream and the pond; the Water range map layer (V) shows who can wade, swim or dive where."]),
		[&"safety_swimming", &"safety_wading", &"safety_rescue"])


static func _skill_cooking() -> Entry:
	"""The cooking entry."""
	return make(&"skill_cooking", KIND_SKILL, "Cooking", "The kitchen's work", PackedStringArray([
		"Fetching the meal's food, cooking it at the cauldron, carrying the pot to the tables.",
		"Any resident can cook; the keeper is the village cook and rises at 05:00 to make breakfast.",
		"A free resident stands in when the cook is busy; the Cook order makes a selected resident cook.",
		"The kitchen (the Pantry's Kitchen tab)."]), [&"station_kitchen", &"dish_porridge", &"dish_soup"])


# --- water safety ------------------------------------------------------------------------------------

func _add_safety() -> void:
	"""Wading, swimming and stamina, diving, rescue."""
	_add(_safety_wading())
	_add(_safety_swimming())
	_add(_safety_diving())
	_add(_safety_rescue())


static func _safety_wading() -> Entry:
	"""The wading entry."""
	@warning_ignore("integer_division") return make(&"safety_wading", KIND_SAFETY, "Wading and the ford", "Shallow water", PackedStringArray([
		"Crossing shallow water on foot, carrying or not.",
		"Water shallower than the resident's own wading depth; they walk at %d%% pace there." % (SwimRules.WADE_PERMILLE / 10),
		"A bridge (full pace, dry).", "The ford where the east road meets the stream."]),
		[&"station_bridges", &"safety_swimming"])


static func _safety_swimming() -> Entry:
	"""Swimming stamina, cold water and the loaded rule, from swim_rules.gd."""
	@warning_ignore("integer_division") return make(&"safety_swimming", KIND_SAFETY, "Swimming and stamina", "Deep water", PackedStringArray([
		"Crossing deep water by the swim links, quicker than a long way round.",
		"No routine swim under %d%% stamina; a swimmer turns for the bank at %d%%; cold water (below %d °C) drains stamina %d times as fast. A loaded resident never swims." % [
			SwimRules.REST_ENTRY_MIN / 100, SwimRules.REST_RETURN / 100, SwimRules.COLD_WATER_TENTHS / 10, SwimRules.COLD_FACTOR],
		"The ford or a bridge, always for a carrier.", "The stream and the pond; Swim shortcuts (Water panel) turns it off."]),
		[&"skill_swimming", &"safety_rescue", &"safety_wading"])


static func _safety_diving() -> Entry:
	"""Diving air, from swim_rules.gd."""
	return make(&"safety_diving", KIND_SAFETY, "Diving", "Under the water", PackedStringArray([
		"Searching the bed for finds: stones, hooks, a relic.",
		"An otter, and air for the way down, the search, the way up and a reserve (%d of %d air)." % [
			SwimRules.AIR_CONTINGENCY_TICKS, SwimRules.AIR_FULL],
		"None.", "Deep water in the stream and the pond (the Water range layer's dive colour)."]),
		[&"skill_swimming", &"safety_rescue"])


static func _safety_rescue() -> Entry:
	"""Rescue, from the water's rules."""
	return make(&"safety_rescue", KIND_SAFETY, "Rescue", "A swimmer in difficulty", PackedStringArray([
		"Bringing a resident in difficulty ashore: a diver for one held below, a swimmer to tow one at the surface.",
		"A free rescuer: with no swimmer, anyone takes a line (%d m) to the nearest landing." % int(SwimRules.LINE_REACH_M),
		"Nobody drowns: with nobody coming, they wash ashore at a landing.",
		"The Water panel pins every resident in difficulty at its top."]), [&"safety_swimming", &"skill_swimming"])


# --- reading ------------------------------------------------------------------------------------------

func count() -> int:
	"""How many entries."""
	return _entries.size()


func entry(k: int) -> Entry:
	"""Entry `k`."""
	return _entries[k]


func index_of(id: StringName) -> int:
	"""The entry with this id (-1 for none)."""
	return int(_by_id.get(id, -1))


func search(query: String) -> PackedInt32Array:
	"""The entries matching `query`, best first; all, in order, for an empty one."""
	return SearchScript.search(_index, query)


func of_kind(kind: int) -> PackedInt32Array:
	"""The entries of one kind, in order."""
	var out := PackedInt32Array()
	for k: int in _entries.size():
		if _entries[k].kind == kind:
			out.append(k)
	return out


func live_line(k: int) -> String:
	"""A pantry item's stock now -- a crop's, a fish's, dried fish's or flour's ('' for other entries, or with no
	pantry bound)."""
	var item: int = _entries[k].item
	if _pantry == null or not Catalog.is_pantry_item(item):
		return ""
	return "In the pantry now: %s." % FarmText.units_text(_pantry.milli_of(item))
