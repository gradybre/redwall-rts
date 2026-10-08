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

var kitchen: KitchenScript = null
var stores: StoresScript = null
## The held menu's beverage: its take (the infusion's herb, or the mead), the infusion's water owed, and what the
## service used of each.
var bev_take: int = 0
var water_held_milli: int = 0
var bev_planned_milli: int = 0
var bev_used_milli: int = 0
var water_used_milli: int = 0

var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(p_kitchen: KitchenScript, p_stores: StoresScript) -> void:
	"""The kitchen (its pantry and takes) and the stores (the butt's water) the menu draws on."""
	kitchen = p_kitchen
	stores = p_stores


func free_of(selector: int) -> int:
	"""Selector `selector`'s food in the pantry nobody has set aside, milli-U."""
	return kitchen.takes.free_milli_of_crop(kitchen.pantry, selector) if kitchen != null else 0


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

func shortfalls(theme: int, eligible: int) -> PackedStringArray:
	"""Every input the theme for E is short of now, as "needs X: n (m free) — from where" (REQ-SET-099: the specific
	reason and the missing quantity); empty when the whole menu can be made."""
	var out := PackedStringArray()
	for course: int in 2:
		var dish: int = course_dish(theme, course == 1)
		var batches: int = course_batches(theme, course == 1, eligible)
		for k: int in MealRules.INPUT_N[dish]:
			var need: int = batches * MealRules.input_milli(dish, k)
			var free: int = free_of(MealRules.input_selector(dish, k))
			if free < need:
				out.append(_needs(input_word(dish, k), need, free, MealRules.input_category(dish, k)))
	var bev: int = bev_need_milli(theme, eligible)
	if free_of(bev_selector(theme)) < bev:
		out.append(_needs(bev_words(theme), bev, free_of(bev_selector(theme)), bev_selector(theme)))
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


func release() -> void:
	"""Give back the beverage's reservation; nothing owed any more (the courses' food is in the feast's take)."""
	if bev_take != 0 and kitchen != null:
		kitchen.takes.release(bev_take)
	bev_take = 0
	bev_planned_milli = 0
	water_held_milli = 0


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


static func units(milli: int) -> String:
	"""'6.0 U', or to the hundredth when a tenth would hide a part ('0.25 U': the infusion's herb)."""
	if milli % 100 == 0:
		return StoresScript.units_text(milli)
	@warning_ignore("integer_division") var whole: int = milli / 1000
	@warning_ignore("integer_division") var hundredths: int = (milli % 1000) / 10
	return "%d.%02d U" % [whole, hundredths]
