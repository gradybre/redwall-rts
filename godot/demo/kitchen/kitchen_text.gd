extends RefCounted
## The kitchen's words: what a resident is doing for it, its news lines, its refusals and their fixes, and the panels'
## lines. Decision 0381. Presentation only; every quantity in its good's natural measure (scripts/ui/goods_measures.gd,
## decisions 1011 and 1801), and the command grammar is the action cards' (demo/ui/action_card.gd, decision 0332).

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const NOTHING_PLANNED: String = "No meal is planned yet"
## The content library's book keys (CONTENT-LIB-001 §2) as the player reads them.
const BOOK_TITLES: Dictionary = {"redwall": "Redwall", "mossflower": "Mossflower", "salamandastron": "Salamandastron",
	"martin_warrior": "Martin the Warrior", "outcast": "The Outcast of Redwall", "pearls_lutra": "Pearls of Lutra",
	"long_patrol": "The Long Patrol", "marlfox": "Marlfox", "lord_brocktree": "Lord Brocktree",
	"taggerung": "The Taggerung", "triss": "Triss", "rakkety_tam": "Rakkety Tam"}
## THE CHOICE in words (kitchen.gd): the Recipes tab says how the cook picks among the cookable dishes.
const CHOICE_NOTE: String = "The cook picks each meal's dish from the food in store: one that feeds everyone first, then the food that keeps least long, then what the village likes most, then the plainest dish."
## The Kitchen tab's note: its hours are filled from meal_rules.gd's own (`tab_note`), so they cannot drift.
const TAB_NOTE: String = "Breakfast is called at %02d:00 and supper at %02d:00. The cook is up at %02d:00 to cook breakfast, and cooks supper from %02d:00; each pot goes to the hall's table as it is cooked, and between meals the cook fetches the next day's food from the stores. The village is called once a meal is on its way. A portion is 1800 NP; a small resident needs 6000 a day."
const ROUND_LABEL: String = "Cooking the village's meals"
const DRAW_LABEL: String = "Drawing water for the kitchen"
const NO_COOK_REASON: String = "nobody is free to cook"
const QUEUE_DRAW: String = "Queue for anyone free: whoever is nearest the well, when someone is"
const FIX_FOOD: String = "Farm ▸ Harvest a ripe grain or roots bed (or Plant… one)"
const FIX_WATER: String = "Pantry (K) ▸ Kitchen ▸ Draw water"
const FIX_FUEL: String = "Woods ▸ Gather deadfall or Haul logs"
const FIX_COOK: String = "select a resident and press Cook"
const SIT_CLIP: StringName = &"chair_sit_idle"
const EAT_CLIP: StringName = &"stand_and_drink"
const WORK_CLIP: StringName = &"collect_object"
const DRAW_CLIP: StringName = &"pull_radish"
const IDLE_CLIP: StringName = &"idle"
const Steps := preload("res://demo/kitchen/kitchen_task.gd")
## kitchen_task.gd's steps, as local constants for `match`.
const WALK_STORE: int = Steps.WALK_STORE
const WALK_KITCHEN: int = Steps.WALK_KITCHEN
const WALK_TABLE: int = Steps.WALK_TABLE
const WALK_WELL: int = Steps.WALK_WELL
const WALK_BUTT: int = Steps.WALK_BUTT
const WALK_SEAT: int = Steps.WALK_SEAT
const WALK_RAW: int = Steps.WALK_RAW
const WORK_PICK: int = Steps.WORK_PICK
const WORK_PUT_DOWN: int = Steps.WORK_PUT_DOWN
const WORK_COOK: int = Steps.WORK_COOK
const WORK_PUT_OUT: int = Steps.WORK_PUT_OUT
const WORK_DRAW: int = Steps.WORK_DRAW
const WORK_POUR: int = Steps.WORK_POUR
const WORK_WAIT: int = Steps.WORK_WAIT
const WORK_EAT: int = Steps.WORK_EAT
const WORK_EAT_RAW: int = Steps.WORK_EAT_RAW

static func tab_note() -> String:
	"""TAB_NOTE with the meals' hours (meal_rules.gd CALL_HOUR, COOK_RISE_HOUR, COOK_FROM_HOUR)."""
	return TAB_NOTE % [Rules.CALL_HOUR[Rules.MEAL_BREAKFAST], Rules.CALL_HOUR[Rules.MEAL_SUPPER], Rules.COOK_RISE_HOUR,
		Rules.COOK_FROM_HOUR[Rules.MEAL_SUPPER]]


static func meal_words(key: int) -> String:
	"""A meal by its key: "breakfast", "supper"."""
	return Rules.MEAL_NAMES[posmod(key, 2)] if key >= 0 else "the next meal"


static func meal_title(key: int) -> String:
	"""A meal by its key with its day: "Breakfast, day 3"."""
	@warning_ignore("integer_division") return "%s, day %d" % [Rules.MEAL_TITLES[posmod(key, 2)], key / 2 + 1] if key >= 0 else "The next meal"


static func clip_for(step: int, brain: RefCounted) -> StringName:
	"""The clip for a work step: stirring and handling the work clip, drawing a heave, a seated diner
	`chair_sit_idle` when staged (else idle while waiting and a simple eat pose, `stand_and_drink`, eating)."""
	match step:
		WORK_DRAW:
			return DRAW_CLIP
		WORK_WAIT:
			return SIT_CLIP if bool(brain.call(&"has_clip", SIT_CLIP)) else IDLE_CLIP
		WORK_EAT:
			return SIT_CLIP if bool(brain.call(&"has_clip", SIT_CLIP)) else EAT_CLIP
		WORK_EAT_RAW:
			return EAT_CLIP
	return WORK_CLIP


static func doing(kitchen: RefCounted, i: int) -> String:
	"""What resident `i` is doing for the kitchen, in the party panel's words."""
	var step: int = int(kitchen.call(&"step_of", i))
	var meal: String = meal_words(int(kitchen.call(&"meal_of", i)))
	match step:
		WALK_STORE, WORK_PICK:
			return "Fetching food for the kitchen from the %s" % _store_name(kitchen, i)
		WALK_KITCHEN:
			return "Carrying food to the kitchen" if bool(kitchen.call(&"food_in_hand")) else "Going to the kitchen"
		WORK_PUT_DOWN:
			return "Putting the food down at the kitchen"
		WORK_COOK:
			return _cooking_text(kitchen)
		WALK_TABLE, WORK_PUT_OUT:
			return "Carrying the pot to the table"
		WALK_WELL:
			return "Going to the well for water"
		WORK_DRAW:
			return "Drawing water at the well"
		WALK_BUTT, WORK_POUR:
			return "Pouring water into the butt by the well"
		WALK_SEAT:
			return "Going to the table for %s" % meal
		WORK_WAIT:
			return "At the table, waiting for %s" % meal
		WORK_EAT:
			return "Eating %s" % meal
		WALK_RAW, WORK_EAT_RAW:
			return "No %s: eating raw %s (hungry)" % [meal, _item_word(int(kitchen.call(&"raw_item_of", i)))]
	return "Helping in the kitchen"


static func _store_name(kitchen: RefCounted, i: int) -> String:
	"""The store resident `i` fetches from, lower case ("covered store")."""
	var pantry: RefCounted = kitchen.get(&"pantry")
	return String(pantry.get(&"storage").call(&"label_of", int(kitchen.call(&"location_of", i)))).to_lower()


static func _cooking_text(kitchen: RefCounted) -> String:
	"""'Cooking wild oat porridge for breakfast'."""
	var key: int = int(kitchen.call(&"wip_key"))
	var store: RefCounted = kitchen.get(&"store")
	var dish: int = int(kitchen.call(&"wip_dish"))
	if key < 0 or dish < 0:
		return "At the cauldron"
	return "Cooking %s for %s (%d portions in the pot)" % [Rules.DISH_NAMES[dish].to_lower(), meal_words(key),
		int(store.call(&"in_pot"))]


static func _item_word(item: int) -> String:
	"""A pantry item in lower case."""
	return Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_pantry_item(item) else "food"


static func _item_good(item: int) -> StringName:
	"""A pantry item's good (goods_measures.gd's key); mixed food for anything else."""
	return Catalog.ITEM_KEYS[item] if Catalog.is_pantry_item(item) else &"food"


# --- news ---------------------------------------------------------------------------------------------

static func call_line(key: int) -> String:
	"""A meal is called."""
	return "%s: the village comes to the tables" % meal_title(key)


static func cooked_line(key: int, dish: int, portions: int) -> String:
	"""A meal's batches are all cooked."""
	return "%s is cooked: %d portions of %s" % [meal_title(key), portions, Rules.DISH_NAMES[dish].to_lower()]


static func out_line(portions: int, serving: int) -> String:
	"""The pot is at the table."""
	var when: String = "" if serving < 0 else " for %s" % meal_words(serving)
	return "The cook put %d portions out on the hall's table%s" % [portions, when]


static func tally_line(key: int, ate: int, without: int) -> String:
	"""A meal's tally at its end."""
	if without == 0:
		return "%s: everyone ate (%d)" % [meal_title(key), ate]
	return "%s: %d ate, %d went without" % [meal_title(key), ate, without]


static func raw_line(name: String, milli: int, item: int, key: int) -> String:
	"""A raw emergency meal (REQ-SET-013): "..., ate 2 bunches of radishes raw"."""
	return "%s, hungry with no %s, ate %s raw" % [name, meal_words(key), Measures.amount(_item_good(item), milli)]


static func no_meal_line(key: int, reason: String, fix: String) -> String:
	"""The incident's line: "No supper tonight: <reason>. To fix: <fix>"."""
	var head: String = "No supper tonight" if posmod(key, 2) == Rules.MEAL_SUPPER else "No breakfast this morning"
	return "%s: %s%s" % [head, reason, (". To fix: " + fix) if not fix.is_empty() else ""]


static func no_meal_short(key: int) -> String:
	"""The incident's card title."""
	return "No supper tonight" if posmod(key, 2) == Rules.MEAL_SUPPER else "No breakfast this morning"


static func unreachable_line(name: String, store: String) -> String:
	"""The cook could not get to a store."""
	return "%s couldn't get to the %s for the kitchen's food" % [name, store.to_lower()]


static func enough_reason(key: int) -> String:
	"""Nothing left to cook for the next meal."""
	return "%s has all it needs: its portions are cooked or left over" % meal_title(key).to_lower()


static func cancelled_line(key: int) -> String:
	"""The player's cancel."""
	return "%s is cancelled: its food is not cooked (what was fetched stays at the kitchen for the next meal)" % meal_title(key)


# --- refusals ------------------------------------------------------------------------------------------

static func no_food_reason(dish: int, other_has: bool) -> String:
	"""No food for a batch of `dish`'s first input (nor for the other meal's first dish, unless `other_has`)."""
	var other: int = Rules.other(dish)
	var line: String = "the pantry has no %s for %s (%s a batch: %s)" % [input_words(dish, 0),
		Rules.DISH_NAMES[dish].to_lower(), Measures.exact_cell(Rules.input_good(dish, 0), Rules.input_milli(dish, 0)),
		Rules.items_text(Rules.input_selector(dish, 0))]
	if not other_has:
		line += ", nor %s for %s" % [input_words(other, 0), Rules.DISH_NAMES[other].to_lower()]
	return line


static func no_side_reason(dish: int, k: int, have: int) -> String:
	"""Not a batch's input `k` (one past the first: the fish stew's roots, the hotpot's greens): "the pantry is short
	of roots for fish stew: 1 of 2 bowls a batch"."""
	return "the pantry is short of %s for %s: %s a batch" % [input_words(dish, k), Rules.DISH_NAMES[dish].to_lower(),
		Measures.have_need(Rules.input_good(dish, k), have, Rules.input_milli(dish, k))]


static func input_words(dish: int, k: int) -> String:
	"""What `dish`'s input `k` is called: its category's word ("roots", "greens", "fresh fish"), or its own items when
	another lane defines them ("hazelnut")."""
	return Rules.IN_WORDS[Rules.INPUT_FIRST[dish] + k]


static func inputs_text(dish: int, batches: int) -> String:
	"""All of `dish`'s food for `batches` batches: "2 fish (dace) + 2 bowls of roots (radish, ... or onion)" -- one
	batch as the recipe states it (`exact`), several as a requirement (`need`)."""
	var parts := PackedStringArray()
	for k: int in Rules.INPUT_N[dish]:
		var words: String = input_words(dish, k)
		var items: String = Rules.IN_ITEMS_TEXT[Rules.INPUT_FIRST[dish] + k]
		var good: StringName = Rules.input_good(dish, k)
		var milli: int = Rules.input_milli(dish, k) * batches
		var amount: String = Measures.exact(good, milli) if batches == 1 else Measures.need(good, milli)
		amount = _named(amount, good, words)
		parts.append(amount if words == items else "%s (%s)" % [amount, items])
	return " + ".join(parts)


static func _named(amount: String, good: StringName, words: String) -> String:
	"""An amount that names its good after its measure ("2 bowls of roots") named as the recipe calls the input instead
	("2 bowls of greens or roots", "40 g of greens or roots"); a counted amount ("2 fish") is left as it is."""
	var suffix: String = " of " + Measures.noun(good)
	return amount.trim_suffix(suffix) + " of " + words if amount.ends_with(suffix) and words != Measures.noun(good) \
		else amount


static func waiting_line(dish: int) -> String:
	"""A dish waiting for an ingredient, and why: "Vegetable pasty — needs hazelnut: gathered by foragers"."""
	return "%s — %s" % [Rules.DISH_NAMES[dish], Rules.DISH_WAITS[dish]]


static func no_water_reason(dish: int, have: int, need: int) -> String:
	"""Not a batch's water in the butt: "the water butt holds 3 of 6 jugs for the meal (porridge takes 2 jugs a
	batch)"."""
	return "the water butt holds %s for the meal (%s takes %s a batch)" % [Measures.have_need(&"water", have, need),
		Rules.DISH_NAMES[dish].to_lower(), Measures.exact_cell(&"water", Rules.WATER_MILLI[dish])]


static func no_fuel_reason(have: int, need: int) -> String:
	"""Not a batch's wood in the stores: "the stores hold 3 of 9 bundles of kindling for the meal (a bundle of kindling
	a batch)"."""
	return "the stores hold %s for the meal (%s a batch)" % [Measures.have_need(&"wood", have, need), batch_wood()]


static func batch_wood() -> String:
	"""A batch's wood (BAL-SUPPLY-004, meal_rules.gd WOOD_MILLI_PER_BATCH) in words: "a bundle of kindling"."""
	return Measures.exact(&"wood", Rules.WOOD_MILLI_PER_BATCH)


static func butt_full_reason(have: int, coming: int) -> String:
	"""The butt is full, or will be."""
	if coming > 0:
		return "the butt will be full: it holds %s, with %s on its way" % [Measures.amount_cell(&"water", have),
			Measures.amount_cell(&"water", coming)]
	return "the butt is full (%s)" % Measures.amount_cell(&"water", have)


static func cant(reason: String, fix: String) -> String:
	"""An order refused, in the cards' words."""
	return CardScript.CANT + reason + (("\n" + CardScript.FIX + fix) if not fix.is_empty() else "")


static func assign_selected(name: String, selected: int) -> String:
	"""The cards' grammar for a selected resident sent."""
	return CardScript.assign_selected(name, selected, selected)


static func under_way(name: String) -> String:
	"""The cook is already at it."""
	return CardScript.under_way(name)


static func queue_cook(name: String, village_cook: bool) -> String:
	"""Queued for the cook: "Queue for the cook: Mouse keeper (the village cook)"."""
	if name.is_empty():
		return "Queue for the cook: nobody is free — select residents to do it"
	return "Queue for the cook: %s (%s)" % [name, "the village cook" if village_cook else "standing in"]


static func draw_by(name: String) -> String:
	"""Queued for the nearest free resident."""
	return "Queue for anyone free: %s (nearest the well)" % name


static func cook_ordered(key: int, dish: int, batches: int, who: String) -> String:
	"""The Cook order's answer."""
	return "Cook %s now: %d batches of %s · %s" % [meal_words(key), batches, Rules.DISH_NAMES[dish].to_lower(), who]


static func draw_ordered(amount: int, who: String) -> String:
	"""The Draw water order's answer."""
	return "Draw %s for the kitchen · %s" % [Measures.amount(&"water", amount), who]


# --- the resident panel and the roster ---------------------------------------------------------------

static func fed_line(state: int, hunger: int, today: int, need: int, last: String) -> String:
	"""The resident panel's lines, short enough for its width: "Fed · 72% full · 1800/6000 NP today", then "Last
	meal: breakfast, porridge" (" — a favourite" when it was one: `favourite_mark`)."""
	@warning_ignore("integer_division") var line: String = "%s · %d%% full · %d/%d NP today" % [Rules.FED_WORDS[state].capitalize(),
		hunger * 100 / Rules.NEED_MAX, today, need]
	return line + ("\nLast meal: " + last if not last.is_empty() else "")


static func monotony_line(dish: int, repeats: int, value: int, hours: int) -> String:
	"""§5.7's monotonous memory, shown (as short as the panel is narrow): "Monotony -200 (6 h): porridge 3 of last 6" --
	counted by §5.7 recipe, so it names the recipe ("root stew"), whichever of its dishes was eaten."""
	var what: String = Rules.GDD_ROWS[dish].replace("_", " ")
	return "Monotony %d (%d h): %s %d of last %d" % [value, hours, what, repeats, Rules.HISTORY]


static func favourite_mark(favourite: bool) -> String:
	"""What the last meal line adds when it was a favourite."""
	return " — a favourite" if favourite else ""


static func day_hour(hour_index: int) -> String:
	"""A calendar hour as "day 3, 14:00"."""
	@warning_ignore("integer_division") return "day %d, %02d:00" % [hour_index / SimClock.HOURS_PER_DAY + 1, hour_index % SimClock.HOURS_PER_DAY]


static func days_value(milli_days: int) -> String:
	"""Thousandths of a day in tenths, floored -- "4.5 days", "<0.1 days", "0 days" (the top bar's cell too)."""
	if milli_days <= 0:
		return "0 days"
	if milli_days < 100:
		return "<0.1 days"
	@warning_ignore("integer_division") return "%d.%d days" % [milli_days / 1000, (milli_days % 1000) / 100]


static func days_text(milli_days: int) -> String:
	"""Days of meals: "4.5 days of meals"."""
	return days_value(milli_days) + " of meals"


static func cookable_line(dish: int) -> String:
	"""The Recipes tab's mark for one dish: "Cookable (active): Wild oat porridge — cooked as the GDD's porridge: 2 scoops
	of grain (wheat, barley or oats) + 2 jugs of water → 2 portions of 1800 NP, 12 WU, keeps 24 h; for breakfast." -- or
	"Waiting (needs hazelnut: gathered by foragers): ..." for a dish an ingredient keeps waiting, and "a recipe
	from The Outcast of Redwall" for a row confirmed outside the GDD (DEC-045, decision 0603: player text names the book,
	never the ruling)."""
	@warning_ignore("integer_division")
	return "%s: %s — cooked as %s: %s + %s → %d portions of %d NP, %d WU, keeps %d h; %s." % [
		"Waiting (%s)" % Rules.DISH_WAITS[dish] if Rules.waits(dish) else "Cookable (active)", Rules.DISH_NAMES[dish],
		"the GDD's %s" % Rules.GDD_ROWS[dish] if Rules.ROW_ADOPTED[dish] == 1 else _book_recipe(dish),
		inputs_text(dish, 1),
		Measures.exact(&"water", Rules.WATER_MILLI[dish]), Rules.PORTIONS_PER_BATCH[dish], Rules.NP_PER_PORTION[dish],
		Rules.WORK_MWU[dish] / 1000, Rules.SHELF_HOURS[dish], _for_meal(dish)]


static func _book_recipe(dish: int) -> String:
	"""A non-GDD row in player words: "a recipe from Rakkety Tam" -- the book its library dish is from."""
	var book: String = Rules.LIBRARY_IDS[dish].get_slice("::", 0)
	return "a recipe from %s" % BOOK_TITLES.get(book, "the Redwall books")


static func _for_meal(dish: int) -> String:
	"""Which meal a dish is for: "for supper", or "a drink"."""
	var meal: int = Rules.DISH_MEAL[dish]
	return "for " + Rules.DISH_MEAL_WORDS[meal] if Rules.is_meal_dish(dish) else Rules.DISH_MEAL_WORDS[meal]


static func choice_note() -> String:
	"""How the cook picks a dish, for the Recipes tab (kitchen.gd THE CHOICE)."""
	return CHOICE_NOTE


static func meal_record(key: int, dish: int, ate: int, raw: int, without: int) -> String:
	"""One meal's line: "Supper, day 2: togget's vegetable soup — 8 ate, 1 went without"."""
	var what: String = Rules.DISH_NAMES[dish].to_lower() if dish >= 0 else "nothing cooked"
	var tally: String = "%d ate" % ate
	if raw > 0:
		tally += ", %d ate raw" % raw
	if without > 0:
		tally += ", %d went without" % without
	return "%s: %s — %s" % [meal_title(key), what, tally]
