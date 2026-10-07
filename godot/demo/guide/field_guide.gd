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
const KitchenWords := preload("res://demo/kitchen/kitchen_text.gd")
const Book := preload("res://demo/kitchen/dish_book.gd")
const Tastes := preload("res://demo/kitchen/dish_favourites.gd")
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
const FerryRules := preload("res://demo/ferry/ferry_rules.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const WinterRules := preload("res://demo/winter/winter_rules.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const ForageRules := preload("res://demo/forage/forage_rules.gd")
const OrchardText := preload("res://demo/orchard/orchard_text.gd")
const HiveText := preload("res://demo/hives/hive_text.gd")
const PreserveText := preload("res://demo/preserve/preserve_text.gd")

const KIND_CROP: int = 0
const KIND_DISH: int = 1
const KIND_MATERIAL: int = 2
const KIND_STATION: int = 3
const KIND_SKILL: int = 4
const KIND_SAFETY: int = 5
## The pantry's other goods (decision 0431): the catch, dried fish and flour; and the woods' forage (decision 0681).
const KIND_GOODS: int = 6
const KIND_NAMES: Array[String] = ["Crops", "Dishes", "Materials", "Buildings and stations", "Residents' skills",
	"Water safety", "Fish, forage and preserved food"]
## The crop rows' names as the guide says them (farming.gd's rows: roots, cabbage, beans, grain).
const ROW_WORDS: Dictionary = {FarmingScript.CROP_ROOTS: "Root crop", FarmingScript.CROP_CABBAGE: "Leaf crop",
	FarmingScript.CROP_BEANS: "Pulse", FarmingScript.CROP_GRAIN: "Grain"}
## Each dish's entry id, `dish_<key>` from the kitchen's recipe book (meal_rules.gd DISH_KEYS; decision 0601), built
## when this script loads.
static var DISH_IDS: Array[StringName] = []
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
	"""What the item is for: the dish that cooks it, the stations' rows that take it, and raw food for the hungry."""
	var parts := PackedStringArray()
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_input(dish, item):
			parts.append("%s (%s): %s makes %d portions" % [Rules.DISH_NAMES[dish], Rules.DISH_MEAL_WORDS[meal_of(dish)],
				FarmText.units_text(input_milli(dish, item)), Rules.PORTIONS_PER_BATCH[dish]])
			links.append(DISH_IDS[dish])
	for recipe: int in PreserveText.Recipes.rows_taking(item):
		parts.append("made into %s at %s" % [PreserveText.good_words(recipe),
			PreserveText.Recipes.STATION_NAMES[PreserveText.Recipes.STATION[recipe]]])
	_link_rows(item, links)
	if Rules.raw_np_per_u(item) > 0:
		parts.append("eaten raw by a hungry resident when a meal is missed (%d NP a unit)" % Rules.raw_np_per_u(item))
	if parts.is_empty():
		return "None of the demo's dishes cooks it yet: it is grown and stored."
	var text: String = "; ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


static func _row_mates(item: int) -> String:
	"""The other crops of its row, which grow and keep alike (their uses may differ: barley alone makes ale)."""
	var mates := PackedStringArray()
	for other: int in Catalog.ITEM_COUNT:
		if other != item and Catalog.ITEM_CROP[other] == Catalog.ITEM_CROP[item]:
			mates.append(Catalog.ITEM_LABELS[other].to_lower())
	return "The same row, grown and kept alike (each one's dishes and rows are under its Uses): %s." % ", ".join(mates) \
		if not mates.is_empty() else "None."


static func _grown_here(item: int) -> String:
	"""Where it grows in this village: a bed that opens with it, else any bed sown with it."""
	for bed: int in Catalog.BED_COUNT:
		if Catalog.BED_START_ITEM[bed] == item:
			return "Growing in bed %d at the start; any field bed whose soil takes it can be sown with it." % (bed + 1)
	return "Any field bed whose soil takes it can be sown with it."


static func _static_init() -> void:
	"""The dish entry ids, one per recipe-book dish."""
	for dish: int in Rules.DISH_COUNT:
		DISH_IDS.append(StringName("dish_%s" % Rules.DISH_KEYS[dish]))


static func meal_of(dish: int) -> int:
	"""The meal `dish` is cooked for (its recipe-book row's)."""
	return Rules.DISH_MEAL[dish]


static func input_milli(dish: int, item: int) -> int:
	"""How much a batch of `dish` takes of the input `item` fills (0: none)."""
	var k: int = Rules.input_of(dish, item)
	return Rules.input_milli(dish, k) if k >= 0 else 0


static func _tastes_text(dish: int) -> String:
	"""Which species like or dislike `dish` (dish_favourites.gd; decision 0601): " A favourite of moles and badgers."."""
	var text: String = ""
	var liked: PackedStringArray = Tastes.species_with(Rules.DISH_KEYS[dish], Tastes.LIKE)
	if not liked.is_empty():
		text += " A favourite of %s." % _plural_list(liked)
	var disliked: PackedStringArray = Tastes.species_with(Rules.DISH_KEYS[dish], Tastes.DISLIKE)
	if not disliked.is_empty():
		text += " Not liked by %s." % _plural_list(disliked)
	return text


static func _plural_list(species: PackedStringArray) -> String:
	"""Species keys as plural words: "moles and badgers", "mice"."""
	var words := PackedStringArray()
	for key: String in species:
		words.append("mice" if key == "mouse" else key + "s")
	if words.size() < 2:
		return "".join(words)
	return "%s and %s" % [", ".join(words.slice(0, words.size() - 1)), words[words.size() - 1]]


static func item_id(item: int) -> StringName:
	"""The entry a pantry item links to: a crop's, else one of the pantry's other goods'."""
	return crop_id(item) if Catalog.is_item(item) else StringName("goods_%s" % Catalog.ITEM_KEYS[item])


func _dish(dish: int) -> Entry:
	"""One of the kitchen's dishes: its meal, portions, inputs, work and how the cook comes to cook it."""
	var links: Array[StringName] = [&"station_kitchen", &"material_water", &"material_wood"]
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		if Rules.is_input(dish, item):
			links.append(item_id(item))
	if Rules.is_meal_dish(dish):
		links.append(DISH_IDS[Rules.other(dish)])
	var meal: int = meal_of(dish)
	var uses: String = "%s: each batch is %d portions of %d NP, keeping %d game hours.%s" % [
		Rules.DISH_MEAL_WORDS[meal].left(1).to_upper() + Rules.DISH_MEAL_WORDS[meal].substr(1),
		Rules.PORTIONS_PER_BATCH[dish], Rules.NP_PER_PORTION[dish],
		Rules.SHELF_HOURS[dish], _tastes_text(dish)]
	var food: String = KitchenWords.inputs_text(dish, 1).replace(" + ", " and ")
	@warning_ignore("integer_division")
	var requires: String = "%s, %s of water and %s of wood a batch; %d WU of cooking at the cauldron.%s" % [food,
		FarmText.units_text(Rules.WATER_MILLI[dish]), FarmText.units_text(Rules.WOOD_MILLI_PER_BATCH),
		Rules.WORK_MWU[dish] / 1000, " Waiting: %s." % Rules.DISH_WAITS[dish] if Rules.waits(dish) else ""]
	var summary: String = "Cooked for %s" % Rules.DISH_MEAL_WORDS[meal] if Rules.is_meal_dish(dish) else (
		"Cooked for a feast" if Rules.is_occasion_dish(dish) else "A drink")
	if Rules.is_occasion_dish(dish) or dish == Rules.DISH_BEAN_HOTPOT:
		links.append(&"occasion_regatta")
	return make(DISH_IDS[dish], KIND_DISH, Rules.DISH_NAMES[dish], summary,
		PackedStringArray([uses, requires, _choice_text(dish), "Cooked at the cauldron by the keeper%s." % (
			", served at the hall's tables" if Rules.is_meal_dish(dish) else "")]), links)


static func _choice_text(dish: int) -> String:
	"""How the cook comes to cook `dish` (a drink: not at meals; an occasion's course: only for a feast)."""
	if Rules.is_occasion_dish(dish):
		return "Only for a feast (the regatta's), at its day's supper: the Hearth feast's second course, one portion for every resident; the cook never chooses it for an everyday meal."
	if not Rules.is_meal_dish(dish):
		return "A drink: the kitchen does not serve it at meals yet."
	var feast: String = " It is also the Hearth feast's main course, cooked for the regatta's supper." \
		if dish == Rules.DISH_BEAN_HOTPOT else ""
	return "The cook picks it when the stores hold its food: a dish that feeds everyone first, then the food that keeps least long, then what the village likes most. When no %s can be made, the cook makes %s.%s" % [
		Rules.DISH_MEAL_WORDS[meal_of(dish)], Rules.DISH_NAMES[Rules.other(dish)], feast]


# --- fish and preserved food -------------------------------------------------------------------------

func _goods(item: int) -> Entry:
	"""One of the pantry's other goods (decision 0431): a fish of the catch, dried fish or flour -- or an ingredient with
	no source yet (decision 0603: potato, honey), the woods' forage (decision 0681) or the orchard's fruit (0671)."""
	var special: Entry = _goods_of_other_lanes(item)
	if special != null:
		return special
	var links: Array[StringName] = [&"station_store", &"station_fishing"]
	var fields: PackedStringArray
	var summary: String
	if item == Catalog.ITEM_DRIED_FISH or item == Catalog.ITEM_FLOUR:
		links = [&"station_rack_mill", &"station_store", &"goods_flour" if item == Catalog.ITEM_DRIED_FISH else &"crop_oats"]
		summary = "Fish smoked at the rack" if item == Catalog.ITEM_DRIED_FISH else "Grain ground at the mill"
		fields = _station_goods_fields(item, links)
	elif item - Catalog.FIRST_CATCH >= 0 and item - Catalog.FIRST_CATCH < Catalog.CATCH_COUNT:
		summary = "Fresh fish from %s" % CATCH_WATERS[item - Catalog.FIRST_CATCH]
		links.append(&"goods_dried_fish")
		fields = _catch_fields(item, links)
	elif Book.PENDING_SOURCES.has(Catalog.ITEM_KEYS[item]):
		summary = "Not yet in the demo"
		links = [&"station_kitchen"]
		fields = PackedStringArray([_dishes_taking(item, links), "Nothing in the village produces it yet: %s." %
			Book.PENDING_SOURCES[Catalog.ITEM_KEYS[item]], _pending_note(item),
			"Keeps %d game hours in store once there is some." % Catalog.shelf_hours_of(item)])
	else:
		push_error("field_guide: no entry for pantry goods %s" % Catalog.ITEM_KEYS[item])
		summary = Catalog.ITEM_LABELS[item]
		fields = PackedStringArray([_dishes_taking(item, links), "", "", ""])
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], summary, fields, links)
	made.item = item
	return made


func _station_goods_fields(item: int, links: Array[StringName]) -> PackedStringArray:
	"""Dried fish's or flour's fields: what cooks it, how it is made, its alternatives, how long it keeps."""
	var shelf: int = Catalog.shelf_hours_of(item)
	if item == Catalog.ITEM_DRIED_FISH:
		@warning_ignore("integer_division")
		return PackedStringArray([
			"The village's reserve: eaten raw by a hungry resident when a meal is missed (%d NP a unit). %s" % [
				Rules.raw_np_per_u(item), _dishes_taking(item, links)],
			"Drying fresh fish at the rack: %s of fish makes %s, %d WU and %d hours' curing." % [
				FarmText.units_text(FisheryRules.DRY_IN_MILLI), FarmText.units_text(FisheryRules.DRY_OUT_MILLI),
				FisheryRules.DRY_WORK_MWU / 1000, FisheryRules.DRY_PASSIVE_HOURS],
			"Fresh fish, cooked in the fish stew while it keeps (%d game hours)." % Catalog.shelf_hours_of(Catalog.FIRST_CATCH),
			"Keeps %d game hours in store; the Pantry (K) lists it." % shelf])
	@warning_ignore("integer_division")
	return PackedStringArray([
		"%s It is not eaten raw." % _dishes_taking(item, links),
		"Milling grain: %s of grain makes %s, %d WU." % [FarmText.units_text(FisheryRules.MILL_IN_MILLI),
			FarmText.units_text(FisheryRules.MILL_OUT_MILLI), FisheryRules.MILL_WORK_MWU / 1000],
		"Unground grain cooks as porridge.", "Keeps %d game hours in store; the Pantry (K) lists it." % shelf])


func _catch_fields(item: int, links: Array[StringName]) -> PackedStringArray:
	"""A fish of the catch's fields: the dishes that cook it (the stews, the baked fish), or dried at the rack."""
	return PackedStringArray([
		"%s Or dried at the rack." % _dishes_taking(item, links),
		"An authorised fishing trip (the Water panel's Fishing) and its gear; keeps only %d game hours, and is never eaten raw." % Catalog.shelf_hours_of(item),
		"The other fish of the catch; dried fish keeps far longer.",
		"Fished in %s." % CATCH_WATERS[item - Catalog.FIRST_CATCH]])


static func _pending_note(item: int) -> String:
	"""Whether the dishes taking a pending `item` wait for it, or cook without it (a dish taking any roots)."""
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_input(dish, item) and not Rules.waits(dish):
			return "Dishes that take it among others cook without it; the rest wait for it."
	return "Its dishes wait for it."


static func _dishes_taking(item: int, links: Array[StringName]) -> String:
	"""The dishes that take `item`, cookable or waiting ("Cooked in: hardtack, vegetable pasty (waiting)."), then the
	stations' rows that take it ("Made into: jam at the preserving table."); each linked."""
	var names := PackedStringArray()
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_input(dish, item):
			names.append(Rules.DISH_NAMES[dish] + (" (waiting)" if Rules.waits(dish) else ""))
			links.append(DISH_IDS[dish])
	var made_into: String = _made_into(item, links)
	if names.is_empty():
		return made_into if not made_into.is_empty() else "No dish of the demo cooks it yet."
	return "Cooked in: %s.%s" % ["; ".join(names), "" if made_into.is_empty() else " " + made_into]


static func _made_into(item: int, links: Array[StringName]) -> String:
	"""The stations' rows that take `item` (preserve_text.gd made_into_text), each output linked."""
	_link_rows(item, links)
	return PreserveText.made_into_text(item)


static func _link_rows(item: int, links: Array[StringName]) -> void:
	"""Link the output of every station row that takes `item` (preserve_rules.gd rows_taking), each once."""
	for recipe: int in PreserveText.Recipes.rows_taking(item):
		var id: StringName = item_id(PreserveText.Recipes.OUT_ITEM[recipe])
		if not links.has(id):
			links.append(id)


func _forage_goods(item: int) -> Entry:
	"""One of the woods' forage (decision 0681): nuts, mushrooms, herbs or berries, gathered on a foraging trip."""
	var k: int = item - Catalog.FIRST_FORAGE
	var raw: int = Rules.raw_np_per_u(item)
	var links: Array[StringName] = [&"station_foraging", &"station_store"]
	var uses: String = _forage_use(item, links) + "."
	if raw > 0:
		uses += " Eaten raw by a hungry resident when a meal is missed (%d NP a unit)." % raw
	if item == Catalog.ITEM_NUTS or item == Catalog.ITEM_HERB:
		links.append(&"occasion_regatta")
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], "Gathered in the woods",
		PackedStringArray([uses,
		"A foraging trip (the Woods panel's Foraging) while they are in season; the woods' daily quota and their stock above its floor bound it.",
		"The other kinds of the woods; the fields for everyday food.",
		"Gathered at %s%s; keeps %d game hours in store." % [ForageRules.SPOT_NAMES[k],
			" and picked at the east orchard's berry hedge" if item == Catalog.ITEM_BERRIES else "",
			Catalog.shelf_hours_of(item)]]), links)
	made.item = item
	return made


func _goods_of_other_lanes(item: int) -> Entry:
	"""A good another lane describes (null: none): the orchard's fruit, the apiary's honey (decision 1601), the stations'
	preserves and drinks (decisions 1611, 1621), the woods' forage."""
	if Catalog.category_of(item) == Catalog.CAT_FRUIT:
		return _orchard_goods(item)
	if item == Catalog.ITEM_HONEY:
		return _hive_goods(item)
	if PreserveText.is_station_good(item):
		return _preserve_goods(item)
	if item >= Catalog.FIRST_FORAGE:
		return _forage_goods(item)
	return null


func _hive_goods(item: int) -> Entry:
	"""The apiary's honey (decision 1601): the dishes that take it, and the apiary's own words for the rest."""
	var links: Array[StringName] = [&"station_store", &"station_kitchen"]
	var fields: PackedStringArray = HiveText.guide_fields(_dishes_taking(item, links), Rules.raw_np_per_u(item),
		Catalog.shelf_hours_of(item))
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], HiveText.GUIDE_SUMMARY, fields, links)
	made.item = item
	return made


func _preserve_goods(item: int) -> Entry:
	"""Dried fruit, rations (decision 1611), mead or the cordial (decision 1621): the stations' own words."""
	var at_rack: bool = item == Catalog.ITEM_DRIED_FRUIT
	var links: Array[StringName] = [&"station_rack_mill" if at_rack else &"station_kitchen", &"station_store"]
	_link_rows(item, links)
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], PreserveText.summary(item),
		PreserveText.guide_fields(item, Rules.raw_np_per_u(item)), links)
	made.item = item
	return made


func _orchard_goods(item: int) -> Entry:
	"""The orchard's apple or pear (decision 0671): its summary and fields are the orchard's own text."""
	var links: Array[StringName] = [&"station_store"]
	var orchard: Array = OrchardText.guide_fields(item, _dishes_taking(item, links))
	var made: Entry = make(item_id(item), KIND_GOODS, Catalog.ITEM_LABELS[item], orchard[0], orchard[1], links)
	made.item = item
	return made


static func _forage_use(item: int, links: Array[StringName]) -> String:
	"""What a forage item is for in the demo: the dishes that take it (each linked; the nuts' include the feast's nut
	loaf), or, for herbs, the feast's warm infusion and the infirmary's treatments."""
	if item == Catalog.ITEM_HERB:
		return "The feast's warm infusion: %s of herb for every twelve guests; and the infirmary's treatments, 1 U each, from the care shelf it is carried to" % FarmText.units_text(RegattaRules.INFUSION_HERB_MILLI)
	return _dishes_taking(item, links).trim_suffix(".")


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
		"Heating: every lit hearth burns %s a day in winter (the great hall's %s); sawn into planks (%s of wood makes %s of planks); a log bridge's log (%s); a pier (%s each); the kitchen's fire (%s a batch); a lantern, a rag rug or hanging stores (%s each); bracing tunnels." % [
			FarmText.units_text(WinterRules.WINTER_DAY_MILLI), FarmText.units_text(_great_hall_winter_milli()),
			FarmText.units_text(ForestRules.SAW_BATCH_MILLI), FarmText.units_text(ForestRules.SAW_BATCH_MILLI),
			FarmText.units_text(SwimRules.LOG_WOOD_MILLI), FarmText.units_text(SwimRules.PIER_WOOD_MILLI),
			FarmText.units_text(Rules.WOOD_MILLI_PER_BATCH), FarmText.units_text(Fixtures.COST_WOOD_MILLI[RoomsScript.FIX_RUG])],
		"Felling a mature tree (%s of logs, hauled to the log stack), or gathering deadfall (%s to %s a pile, no felling)." % [
			FarmText.units_text(ForestRules.TREE_WOOD_MILLI), FarmText.units_text(ForestRules.DEADFALL_MIN_MILLI),
			FarmText.units_text(ForestRules.DEADFALL_MAX_MILLI)],
		"Deadfall in protected woods; planks where a bridge or furniture needs them.",
		"The village stores open with %s; the top bar's Wood." % FarmText.units_text(StoresScript.START_WOOD_MILLI_U)]),
		[&"material_planks", &"skill_felling", &"station_sawhorse", &"station_bridges", &"dish_porridge", &"station_hearths"])


static func _material_planks() -> Entry:
	"""The material planks entry."""
	return make(&"material_planks", KIND_MATERIAL, "Planks", "Sawn wood", PackedStringArray([
		"A plank footbridge (%s a metre of deck); beds (%s), a large bed (%s), shelves, racks, root bins and a table." % [
			FarmText.units_text(SwimRules.PLANK_MILLI_PER_M), FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BED]),
			FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BIG_BED])],
		"Sawing logs at the sawhorse (%d WU a batch)." % ForestRules.SAW_WU,
		"A log bridge needs a log, not planks.", "The plank stack by the workbench; the top bar's ledger and the Wood cell's tooltip."]),
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
	_add(_station_ferry())
	_add(_station_foraging())
	_add(_occasion_regatta())
	_add(_station_hearths())


static func _great_hall_winter_milli() -> int:
	"""A tier-2 (great hall) hearth's winter day, x0.75 (decision 1652)."""
	return WinterRules.day_demand_milli(WeatherScript.SEASON_WINTER, 0, WinterRules.TIER2_FUEL_PERMILLE)


static func _station_hearths() -> Entry:
	"""The hearths and their fuel (decision 0571), from winter_rules.gd's own figures."""
	return make(&"station_hearths", KIND_STATION, "Hearths and heating fuel", "Warmth for the homes and the hall",
		PackedStringArray([
		"A lit hearth holds its room at %s (the great hall's at %s, burning %s a winter day): anyone inside warms up (%d exposure-hours an hour), and a home's hearth adds to its comfort while it burns." % [
			FarmText.degrees_text(WinterRules.HEATED_TENTHS) + " °C", FarmText.degrees_text(WinterRules.HEATED_TIER2_TENTHS) + " °C",
			FarmText.units_text(_great_hall_winter_milli()), WinterRules.div(WinterRules.CLEAR_MILLI_PER_HOUR, 1000)],
		"Wood from the stores: %s a day in winter, %s on a spring or autumn day under %s °C, none in summer (1 U heats a hearth %d hours). A burrow home's hearth costs %s of stone." % [
			FarmText.units_text(WinterRules.WINTER_DAY_MILLI), FarmText.units_text(WinterRules.SHOULDER_DAY_MILLI),
			FarmText.degrees_text(WinterRules.SHOULDER_BELOW_TENTHS), WinterRules.HEARTH_HOURS_PER_U,
			FarmText.units_text(Fixtures.COST_STONE_MILLI[RoomsScript.FIX_HEARTH])],
		"Without wood a hearth goes out and its room cools halfway to the outside air each hour; below 0 °C residents build up exposure and after %d hours are Chilled (working at %d%%) until warmed through." % [
			WinterRules.div(WinterRules.CHILLED_AT_MILLI, 1000), WinterRules.div(WinterRules.CHILLED_WORK_PERMILLE, 10)],
		"The hall's hearth, and one in each burrow home fitted with one; the top bar's Heating fuel."]),
		[&"material_wood", &"station_burrow", &"skill_felling"])


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
		"Routes in any weather (rain and snow do not slow walkers below); draining or watering a bed above through an outlet fitted to it; reaching homes and cellars.",
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
		"Drying fish or fruit into the village's reserve (%d slots, shared); grinding grain into flour (%d at a time)." % [
			FisheryRules.RACK_SLOTS, FisheryRules.MILL_SLOTS],
		"Fresh fish or fruit for the rack (%s a batch); grain for the mill (%s a batch); a resident to work each batch." % [
			FarmText.units_text(FisheryRules.DRY_IN_MILLI), FarmText.units_text(FisheryRules.MILL_IN_MILLI)],
		"Cook fresh fish in the stew instead of drying it.",
		"The Water panel's Drying rack and mill: Dry fish, Mill grain; its Preserves: Dry fruit (decision 1611)."]),
		[&"goods_dried_fish", &"goods_flour", &"station_store"])


static func _station_ferry() -> Entry:
	"""The ferry and the far copse (decision 0437), from ferry_rules.gd."""
	return make(&"station_ferry", KIND_STATION, "The ferry", "The far copse's wood across the run", PackedStringArray([
		"Carrying the far copse's windfall from the far stage to the ferry stage, %s a crossing; a passenger may ride in its second seat when the boat is the quicker way." %
			FarmText.units_text(FerryRules.BOAT_CARGO_MILLI),
		"A helm (fishing %d), open water -- no storm, hard freeze, flood or pond ice -- and its boat free; it departs %02d:00-%02d:00 every %d game hours when anything waits, or at once at %s on the far stage." % [
			FisheryRules.HELM_MIN_LEVEL, FerryRules.FIRST_DEPARTURE_HOUR, FerryRules.LAST_DEPARTURE_HOUR, FerryRules.EVERY_HOURS,
			FarmText.units_text(FerryRules.THRESHOLD_MILLI)],
		"Carry the wood round by the ford, or build a bridge.",
		"The ferry stage on the run below the fisher shelter; the far stage at the stream's mouth; the Water panel's Ferry."]),
		[&"material_wood", &"station_fishing", &"station_bridges", &"occasion_regatta"])


static func _station_foraging() -> Entry:
	"""Foraging trips (decision 0681), from forage_rules.gd."""
	return make(&"station_foraging", KIND_STATION, "Foraging trips", "Nuts, mushrooms, herbs and berries from the woods",
		PackedStringArray([
		"Sending %d to %d foragers into the woods for one kind; they come back hours later with up to %s each." % [
			ForageRules.PARTY_MIN, ForageRules.PARTY_MAX, FarmText.units_text(ForageRules.BASKET_MILLI)],
		"The kind in season (nuts summer to winter, mushrooms spring to autumn, herbs all year, berries summer and autumn); the woods' daily quota and their stock above the sustainable floor; room in a store.",
		"The fields and the water feed the village; the woods add the feast's nuts and herbs.",
		"%s; the Woods panel's Foraging." % ", ".join(ForageRules.SPOT_NAMES)]),
		[&"goods_nuts", &"goods_mushrooms", &"goods_herb", &"goods_berries", &"occasion_regatta"])


static func _occasion_regatta() -> Entry:
	"""The regatta and its feast (decision 0438), from regatta_rules.gd."""
	return make(&"occasion_regatta", KIND_STATION, "The regatta", "A race and a feast, once a season", PackedStringArray([
		"Once a season, the first in summer: a race between the two rowboats and the %s feast at the day's supper, remembered in the chronicle." % RegattaRules.THEME_NAME,
		"A day and a host; two helms; the main course's beans and cabbage (bean hotpot), the nut loaf's flour and nuts and the infusion's herb for all three courses (and %s); %s of wood for its service; 3 days of food and wood after it, or your override." % [
			RegattaRules.BUFF_NAME, FarmText.units_text(RegattaRules.service_wood_milli(9))],
		"Skip the season: no penalty, nothing withheld.",
		"The pond and the boathouse jetty; the hall's tables; the Water panel's Regatta, or the Feast command."]),
		[&"dish_bean_hotpot", &"dish_nut_loaf", &"station_fishing", &"station_kitchen", &"station_foraging"])


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
