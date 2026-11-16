extends RefCounted
## THE CALLED FEASTS' WORDS (decision 1701): the plan's preview (REQ-SET-100: attendees, every course's food and
## portions, the seatings, staffing and the reserves after it), the status line and the themes' readiness -- read from
## the feast and its menu, never kept. Static, so the suite reads them without a panel.

const Rules := preload("res://demo/feast/feast_rules.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const FeastScript := preload("res://demo/feast/called_feast.gd")
const MenuScript := preload("res://demo/feast/feast_menu.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")


static func preview_lines(feast: FeastScript, theme: int, day: int, host: int) -> PackedStringArray:
	"""The plan for `theme` on `day` kept by `host`, in lines, from the pantry's real stock."""
	var e: int = feast.residents()
	var lines := PackedStringArray()
	lines.append("%s feast (%s in the full game) for %d — every resident — at %s's %02d:00 supper; kept by %s" % [
		Rules.THEME_NAMES[theme], Rules.THEME_UNLOCKS[theme], e, feast.day_text(day),
		Rules.FEAST_HOUR, feast.name_of(host)])
	var key: int = Rules.feast_key(day)
	lines.append("Main: %s" % course_words(feast.menu, Rules.main_dish(theme), Rules.main_batches(theme, e), key))
	lines.append("Second: %s" % course_words(feast.menu, Rules.second_dish(theme), Rules.second_batches(theme, e), key))
	lines.append(beverage_words(feast.menu, theme, e))
	if MenuScript.pours_extras(theme):
		lines.append(feast.menu.extras_words(theme, e))
	lines.append(service_words(feast, e, host))
	lines.append("After it: ready food %s days, fuel %s days (REQ-SET-101 asks %d of each)" % [
		FeastScript.days_text(feast.food_days_after_milli(theme, e)),
		FeastScript.days_text(feast.fuel_days_after_milli(feast.wood_after_milli(theme, e))), Rules.RESERVE_DAYS])
	lines.append(buff_words(theme, e))
	return lines


static func course_words(menu: MenuScript, dish: int, batches: int, key: int = MenuScript.NO_KEY) -> String:
	"""'feast fish x2 (12 portions), free in the pantry: fresh fish 3 of 8 fish, roots 4 bowls — enough, herbs ...' --
	each input's free food beside its need, in the need's measure, counting what supper `key` already holds
	(`available_of`)."""
	var parts := PackedStringArray()
	for k: int in MealRules.INPUT_N[dish]:
		parts.append("%s %s" % [MenuScript.input_word(dish, k), Measures.have_need(MealRules.input_good(dish, k),
			menu.available_of(MealRules.input_selector(dish, k), key), batches * MealRules.input_milli(dish, k))])
	return "%s x%d (%d portions), free in the pantry: %s" % [MealRules.DISH_SHORT[dish], batches,
		batches * MealRules.PORTIONS_PER_BATCH[dish], ", ".join(parts)]


static func beverage_words(menu: MenuScript, theme: int, e: int) -> String:
	"""The beverage: the warm infusion's water and herb, or the mead, with what is free beside its need: "Mead, free in
	the pantry: 1 of 3 jugs; a feast drink only, no one is made drunk"."""
	var need: int = MenuScript.bev_need_milli(theme, e)
	var free: int = menu.free_of(MenuScript.bev_selector(theme))
	if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION:
		return "Warm infusion: %s, made at the service; herbs, free in the pantry: %s" % [
			Measures.need(&"water", RegattaRules.infusion_water_milli(e)),
			Measures.have_need(MenuScript.bev_good(theme), free, need)]
	return "Mead, free in the pantry: %s; a feast drink only, no one is made drunk" % Measures.have_need(
		MenuScript.bev_good(theme), free, need)


static func service_words(feast: FeastScript, e: int, host: int) -> String:
	"""Seats, seatings, service wood and the staffing (2 cooks + 1 keeper; the demo has no cooking skill to check)."""
	var seats: int = feast.seats_now()
	return "Seats %d (%d needed) · %d seating%s at supper · service wood (%s) set aside now · %s and a helper cook, %s keeps it (no cooking skill to check)" % [
		seats, RegattaRules.seats_needed(e), Rules.waves(e, seats), "" if Rules.waves(e, seats) == 1 else "s",
		Measures.need_cell(&"wood", RegattaRules.service_wood_milli(e)), feast.name_of(feast.cook()), feast.name_of(host)]


static func buff_words(theme: int, e: int) -> String:
	"""What earns the theme's buff, and what every guest has."""
	@warning_ignore("integer_division") var needed: int = (RegattaRules.COVERAGE_PERMILLE * e + 999) / 1000
	return "%s if %d of %d eat every course: %s for %d h; each guest has the meal and the feast's company (+%d friendship a pair)" % [
		Rules.BUFF_NAMES[theme], needed, e, Rules.BUFF_WORDS[theme], Rules.BUFF_HOURS, RegattaRules.FEAST_GAIN]


static func theme_ready_words(feast: FeastScript, theme: int) -> String:
	"""'Harvest: ready' or 'Harvest: needs mead: 0 of 3 jugs free — ...' -- each theme cooks when its food exists."""
	var short: PackedStringArray = feast.menu.shortfalls(theme, feast.residents(), Rules.feast_key(feast.choice_day))
	if short.is_empty():
		return "%s: every course can be made" % Rules.THEME_NAMES[theme]
	return "%s: %s" % [Rules.THEME_NAMES[theme], "; ".join(short)]


static func status_line(feast: FeastScript) -> String:
	"""The feast now: planned (and for when), being served, or none -- with the buffs lasting and the last feast."""
	var now: String = "No feast is called."
	if feast.state != FeastScript.ST_IDLE:
		now = "The %s feast is %s for %s's supper, kept by %s." % [Rules.THEME_NAMES[feast.plan_theme],
			FeastScript.STATE_WORDS[feast.state], feast.day_text(feast.plan_day), feast.name_of(feast.plan_host)]
	var lasting: String = feast.buffs.status_words(feast.now_tick())
	var warm: bool = feast.buffs.active(Rules.HEARTH, feast.now_tick()) and not lasting.contains(Rules.BUFF_NAMES[Rules.HEARTH])
	if warm:
		lasting = ("%s · " % lasting if not lasting.is_empty() else "") + "Shared Warmth (the regatta's)"
	return "%s Feasts completed: %d.%s" % [now, feast.completed, (" Lasting: %s." % lasting) if not lasting.is_empty() else ""]


static func choice_line(feast: FeastScript) -> String:
	"""'Theme: Harvest · Day: Summer 4 · Keeper: Wenna Tallowby · reserves override: off'."""
	return "Theme: %s · Day: %s · Keeper: %s · reserves override: %s" % [Rules.THEME_NAMES[feast.choice_theme],
		feast.day_text(feast.choice_day), feast.name_of(feast.choice_host), "on" if feast.override else "off"]
