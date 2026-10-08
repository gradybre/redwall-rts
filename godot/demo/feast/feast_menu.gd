extends RefCounted
## A CALLED FEAST'S MENU (decision 1701): what a theme's courses and beverage take for E (feast_rules.gd), what the
## pantry is short of, and -- once the feast is held -- its reservations and the beverage's pour. Presentation over
## integer rules; the kitchen's pantry, takes and butt are the only state it touches, through their own APIs.
##
## THE COURSES (REQ-SET-100, REQ-SET-102): each course's inputs, batches x §5.7's milli-U, reserved at confirmation in
## the feast's take (the kitchen cooks both courses from it: kitchen.gd AN OCCASION). A theme's two courses never share
## an input category (the suite checks it), so each input is checked and reserved on its own.
## THE BEVERAGE: the Hearth's warm infusion -- its herb reserved in a take of its own and its water owed, not drawn
## ahead (the butt is kept full by the kitchen), both poured at the supper's end -- or the Harvest and Orchard feasts'
## mead, ceil(E/4) U reserved in that take. Either is consumed "proportionally to attended/E with milli-unit rounding at
## the last attendee" (§5.7): floor(total x attended / E); the rest is given back. Mead is "feast ingredient only; no
## intoxication subsystem".
## THE OTHER DRINK (Brendan's ruling of 2026-10-07 on balance proposal 1731 P3, option (a): "the Harvest and Orchard
## feasts pour mead and cider under the mead rule"; decision 1701): beside their required mead, the Harvest and Orchard
## feasts pour the brewery's cider -- ceil(E/4) U, reserved at confirmation in a take of its own when the pantry holds
## all of it free, poured proportionally to attended/E at the supper's end and the rest given back, as the regatta pours
## its drinks (regatta_menu.gd THE FEAST'S DRINKS). The mead rule (decision 1625): a feast or table drink only, no
## intoxication, no effect on a buff -- and never required. The Hearth feast pours only its infusion (P3).
## THE SUPPER'S OWN FOOD (Brendan's ruling on 1701 P6, 2026-10-07: (b)): a feast called for a supper the kitchen has
## already planned counts the food that supper's ordinary meal holds, since the feast replaces that meal: the kitchen
## lets it go when it adopts the occasion and tops the courses up from it (kitchen.gd `held_for_meal_milli`). The
## reservation itself is unchanged: what the free food lacks at confirmation the kitchen's own top-up takes.
## EVERY COURSE IS REQUIRED for a called feast (REQ-SET-100: "complete ingredient/portion requirements ... before
## accepting the plan"): the plan is refused naming what is short, where the regatta holds its feast with a missing
## course (decision 0682's reading for the once-a-season occasion, kept there).

const Rules := preload("res://demo/feast/feast_rules.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const RegattaMenuScript := preload("res://demo/regatta/regatta_menu.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## Where each missing input comes from, by category (the "needs X" words' fix).
const SOURCES: Dictionary = {
	Catalog.CAT_FISH: "a fishing trip (Water ▸ Fishing)",
	Catalog.CAT_FLOUR: "the mill (Water ▸ Drying rack and mill)",
	Catalog.CAT_HONEY: "the apiary's honey (the old orchard's hives)",
	Catalog.CAT_NUTS: "a foraging trip (Woods ▸ Foraging)",
	Catalog.CAT_HERB: "a foraging trip for herbs (Woods ▸ Foraging)",
	Catalog.CAT_BERRIES: "the hedge, or a foraging trip (Woods ▸ Foraging)",
	Catalog.CAT_FRUIT: "the orchard's apples and pears",
	Catalog.CAT_MEAD: "the brewery's mead (honey and water, 72 h in a vat)",
}
const SOURCE_FIELDS: String = "the fields (Farm ▸ the planner)"
## No supper named: only the free food counts (`available_of`).
const NO_KEY: int = -1
## THE OTHER DRINK(S), and their names: cider, by Brendan's ruling (a list, so a later ruling is a row).
const EXTRA_DRINKS: PackedInt32Array = [Catalog.ITEM_CIDER]
const EXTRA_NAMES: Array[String] = ["cider"]

var kitchen: KitchenScript = null
var stores: StoresScript = null
## The held menu's beverage: its take (the infusion's herb, or the mead), the infusion's water owed, and what the
## service used of each.
var bev_take: int = 0
var water_held_milli: int = 0
var bev_planned_milli: int = 0
var bev_used_milli: int = 0
var water_used_milli: int = 0
## THE OTHER DRINK held: its take, what is reserved of each (0: not poured this feast), and all ever poured.
var extra_take: int = 0
var extras_planned: PackedInt64Array = PackedInt64Array([0])
var extras_poured_milli: PackedInt64Array = PackedInt64Array([0])

var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(p_kitchen: KitchenScript, p_stores: StoresScript) -> void:
	"""The kitchen (its pantry and takes) and the stores (the butt's water) the menu draws on."""
	kitchen = p_kitchen
	stores = p_stores


func free_of(selector: int) -> int:
	"""Selector `selector`'s food in the pantry nobody has set aside, milli-U."""
	return kitchen.takes.free_milli_of_crop(kitchen.pantry, selector) if kitchen != null else 0


func available_of(selector: int, key: int) -> int:
	"""Selector `selector`'s food a feast at supper `key` may count: what nobody has set aside, and what that supper's
	own ordinary meal holds, which the feast replaces (kitchen.gd `held_for_meal_milli`; Brendan's ruling on 1701 P6).
	`key` NO_KEY: the free food alone."""
	var held: int = kitchen.held_for_meal_milli(key, selector) if kitchen != null and key != NO_KEY else 0
	return free_of(selector) + held


static func course_dish(theme: int, second: bool) -> int:
	"""The theme's main course, or (`second`) its second course."""
	return Rules.second_dish(theme) if second else Rules.main_dish(theme)


static func course_batches(theme: int, second: bool, eligible: int) -> int:
	"""The batches of the theme's main or second course for E."""
	return Rules.second_batches(theme, eligible) if second else Rules.main_batches(theme, eligible)


static func bev_need_milli(theme: int, eligible: int) -> int:
	"""The beverage's reserved quantity: the infusion's herb, or the mead."""
	if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION:
		return RegattaRules.infusion_herb_milli(eligible)
	return Rules.mead_milli(eligible)


static func bev_selector(theme: int) -> int:
	"""What the beverage reserves: herb for the infusion, else mead (pantry categories)."""
	return Catalog.CAT_HERB if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION else Catalog.CAT_MEAD


static func bev_words(theme: int) -> String:
	"""'herbs' or 'mead'."""
	return "herbs" if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION else "mead"


static func input_word(dish: int, k: int) -> String:
	"""What a recipe calls `dish`'s input `k` ("fresh fish", "herbs")."""
	return MealRules.IN_WORDS[MealRules.INPUT_FIRST[dish] + k]


static func source_of(category: int) -> String:
	"""Where food of `category` comes from (the fields for a crop)."""
	return String(SOURCES.get(category, SOURCE_FIELDS))


# --- what is short ------------------------------------------------------------------------------------------------

func shortfalls(theme: int, eligible: int, key: int = NO_KEY) -> PackedStringArray:
	"""Every input the theme for E at supper `key` is short of now, as "needs X: n (m free) — from where" (REQ-SET-099:
	the specific reason and the missing quantity), counting what that supper already holds (`available_of`); empty
	when the whole menu can be made."""
	var out := PackedStringArray()
	for course: int in 2:
		var dish: int = course_dish(theme, course == 1)
		var batches: int = course_batches(theme, course == 1, eligible)
		for k: int in MealRules.INPUT_N[dish]:
			var need: int = batches * MealRules.input_milli(dish, k)
			var free: int = available_of(MealRules.input_selector(dish, k), key)
			if free < need:
				out.append(_needs(input_word(dish, k), need, free, MealRules.input_category(dish, k)))
	var bev: int = bev_need_milli(theme, eligible)
	var bev_free: int = available_of(bev_selector(theme), key)
	if bev_free < bev:
		out.append(_needs(bev_words(theme), bev, bev_free, bev_selector(theme)))
	var water: int = RegattaRules.infusion_water_milli(eligible) if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION else 0
	var butt: int = stores.water_milli_u if stores != null else 0
	if butt < water:
		out.append("needs water in the butt: %s (%s there) — Draw water (Pantry ▸ Kitchen)" % [units(water), units(butt)])
	return out


static func _needs(word: String, need: int, free: int, category: int) -> String:
	"""'needs mead: 3.0 U (0.0 U free) — the brewery's mead'."""
	return "needs %s: %s (%s free) — %s" % [word, units(need), units(free), source_of(category)]


func set_aside(theme: int, eligible: int, out: PackedInt64Array) -> void:
	"""The theme's reservation for E by category, into `out` (sized to the kitchen's categories; filled 0 first): what
	the post-feast ready food leaves out (REQ-SET-101)."""
	out.resize(MealRules.CATEGORY_COUNT)
	out.fill(0)
	for course: int in 2:
		add_course(out, course_dish(theme, course == 1), course_batches(theme, course == 1, eligible))
	out[bev_selector(theme)] += bev_need_milli(theme, eligible)


static func add_course(out: PackedInt64Array, dish: int, batches: int) -> void:
	"""`batches` of `dish`'s inputs added to `out` by category (sized to the kitchen's categories)."""
	for k: int in MealRules.INPUT_N[dish]:
		out[MealRules.input_category(dish, k)] += batches * MealRules.input_milli(dish, k)


# --- holding, giving back, pouring --------------------------------------------------------------------------------

func reserve(theme: int, eligible: int, take: int, hour_index: int) -> void:
	"""At confirmation (every input there: `shortfalls` empty): both courses' food into the feast's `take`, the
	beverage into its own take, the infusion's water owed."""
	release()
	for course: int in 2:
		var dish: int = course_dish(theme, course == 1)
		var batches: int = course_batches(theme, course == 1, eligible)
		for k: int in MealRules.INPUT_N[dish]:
			kitchen.takes.reserve_into(kitchen.pantry, take, MealRules.input_selector(dish, k),
				batches * MealRules.input_milli(dish, k), hour_index, _read)
	bev_take = kitchen.takes.new_take()
	bev_planned_milli = bev_need_milli(theme, eligible)
	kitchen.takes.reserve_into(kitchen.pantry, bev_take, bev_selector(theme), bev_planned_milli, hour_index, _read)
	water_held_milli = RegattaRules.infusion_water_milli(eligible) if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION else 0
	if pours_extras(theme):
		_reserve_extras(eligible, hour_index)


func release() -> void:
	"""Give back the beverage's reservation; nothing owed any more (the courses' food is in the feast's take)."""
	if bev_take != 0 and kitchen != null:
		kitchen.takes.release(bev_take)
	bev_take = 0
	bev_planned_milli = 0
	water_held_milli = 0
	if extra_take != 0 and kitchen != null:
		kitchen.takes.release(extra_take)
	extra_take = 0
	extras_planned.fill(0)


func pour(theme: int, eligible: int, attended: int, hour_index: int) -> bool:
	"""The supper is over: the beverage consumed for `attended` of E (floor: §5.7's rounding at the last attendee) --
	the herb or mead from its take (no more than is still there), the infusion's water drawn through the kitchen's
	ledger -- the rest given back. Whether everyone who came was poured their share."""
	var guests: int = clampi(attended, 0, maxi(eligible, 0))
	@warning_ignore("integer_division") var share: int = bev_planned_milli * guests / maxi(eligible, 1)
	@warning_ignore("integer_division") var water: int = water_held_milli * guests / maxi(eligible, 1)
	var poured: int = _pour_take(theme, share, hour_index)
	var drawn: int = kitchen.draw_service_water(water) if water > 0 and kitchen != null else 0
	bev_used_milli += poured
	water_used_milli += drawn
	_pour_extras(eligible, guests, hour_index)
	release()
	return guests > 0 and poured == share and drawn == water


func _pour_take(theme: int, share: int, hour_index: int) -> int:
	"""Up to `share` of the beverage withdrawn from its take (a reservation partly spoiled since is trimmed first)."""
	if share <= 0 or bev_take == 0 or kitchen == null:
		return 0
	kitchen.takes.trim_to_lots(kitchen.pantry, bev_take, TakesScript.AT_STORE)
	var there: int = kitchen.takes.live_milli(kitchen.pantry, bev_take, TakesScript.AT_STORE, bev_selector(theme))
	var amount: int = mini(share, there)
	if amount <= 0:
		return 0
	var ok: bool = kitchen.takes.consume_into(kitchen.pantry, bev_take, amount, TakesScript.AT_STORE, hour_index, _read,
		bev_selector(theme))
	return amount if ok else 0


# --- the other drinks -----------------------------------------------------------------------------------------------

static func pours_extras(theme: int) -> bool:
	"""Whether the theme pours THE OTHER DRINK: the feasts whose beverage is mead (Harvest, Orchard)."""
	return Rules.valid_theme(theme) and Rules.BEVERAGE[theme] == Rules.BEV_MEAD


static func extra_selector(k: int) -> int:
	"""Other drink `k`'s pantry category."""
	return Catalog.category_of(EXTRA_DRINKS[k])


func _reserve_extras(eligible: int, hour_index: int) -> void:
	"""Each other drink the pantry holds all of, ceil(E/4) U, reserved in their own take."""
	var need: int = RegattaMenuScript.drink_need_milli(eligible)
	for k: int in EXTRA_DRINKS.size():
		if need <= 0 or free_of(extra_selector(k)) < need:
			continue
		if extra_take == 0:
			extra_take = kitchen.takes.new_take()
		kitchen.takes.reserve_into(kitchen.pantry, extra_take, extra_selector(k), need, hour_index, _read)
		extras_planned[k] = need


func _pour_extras(eligible: int, guests: int, hour_index: int) -> void:
	"""Each other drink reserved, poured for `guests` of E (floor), no more than is still there."""
	if extra_take == 0 or kitchen == null:
		return
	kitchen.takes.trim_to_lots(kitchen.pantry, extra_take, TakesScript.AT_STORE)
	for k: int in EXTRA_DRINKS.size():
		@warning_ignore("integer_division") var pour_milli: int = extras_planned[k] * guests / maxi(eligible, 1)
		pour_milli = mini(pour_milli, kitchen.takes.live_milli(kitchen.pantry, extra_take, TakesScript.AT_STORE, extra_selector(k)))
		if pour_milli > 0 and kitchen.takes.consume_into(kitchen.pantry, extra_take, pour_milli, TakesScript.AT_STORE,
				hour_index, _read, extra_selector(k)):
			extras_poured_milli[k] += pour_milli


func extras_words(theme: int, eligible: int) -> String:
	"""'Also poured, if there: cider 2.0 U (free 0.0 U) — not poured: the brewery has not made enough; no one is made
	drunk' ("" for a theme that pours none)."""
	if not pours_extras(theme):
		return ""
	var need: int = RegattaMenuScript.drink_need_milli(eligible)
	var parts := PackedStringArray()
	for k: int in EXTRA_DRINKS.size():
		var free: int = free_of(extra_selector(k))
		parts.append("%s %s (free %s)%s" % [EXTRA_NAMES[k], units(need), units(free),
			"" if free >= need else " — not poured: the brewery has not made enough"])
	return "Also poured, if there: %s; no one is made drunk" % ", ".join(parts)


static func units(milli: int) -> String:
	"""'6.0 U', or to the hundredth when a tenth would hide a part ('0.25 U': the infusion's herb)."""
	if milli % 100 == 0:
		return StoresScript.units_text(milli)
	@warning_ignore("integer_division") var whole: int = milli / 1000
	@warning_ignore("integer_division") var hundredths: int = (milli % 1000) / 10
	return "%d.%02d U" % [whole, hundredths]
