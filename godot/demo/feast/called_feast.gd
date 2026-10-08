extends RefCounted
## A CALLED FEAST (decision 1701; feature #9, review SOC-023): the player calls one of GDD §5.7's three feasts for one
## of the next suppers -- its theme, day and keeper (the host) -- sees REQ-SET-100's plan, and holds it, or is told why
## not; it is cooked as the kitchen's occasion, served at the 17:00 supper (Brendan's ruling on Q-D11), tallied, and its
## buff granted when 80% of E ate every course. Numbers in feast_rules.gd, the menu in feast_menu.gd, the buffs in
## feast_buffs.gd. Presentation over integer rules; nothing writes into the settlement simulation.
##
## PLANNING (`refusal`, `hold`): refused, in this order, with a code and the way to fix it -- a feast already planned;
## a day not offered; a host who cooks (the kitchen's cook cooks it; the host keeps it); fewer than 2 cooks + 1 keeper;
## another feast planned (the regatta's: §3 "at most 1 scheduled/active feast") or started within 72 game hours (§5.7);
## any course's or the beverage's input short ("needs X", REQ-SET-099); the service wood; the seats (ceil(E/3)); and
## REQ-SET-101's reserves -- under 3 days of ready food or of fuel after the feast unless the player overrides the
## warning for this feast. Ready food after it leaves out the feast's reservation (kitchen.gd
## `days_of_meals_after_milli`); fuel-days after it are §5.8's -- the wood left after the feast's service and batches
## over the winter's hearths' daily demand plus the kitchen's cooking mean (hearth_fuel.gd), not the kitchen's wood alone
## (the packet's pitfall).
## HELD (REQ-SET-102), state PREPARING: both courses' food and the beverage reserved, the service wood ceil(E/12) set
## aside, the kitchen told (`set_occasion`). CANCELLED before the kitchen starts cooking it (15:00 on its day):
## everything given back untouched; once its batches are under way it is no longer cancelled (the kitchen never undoes
## cooking, and an uncooked remainder would stay with that supper).
## SERVED (REQ-SET-103), state ACTIVE from the supper's call: its wood burns; the kitchen seats the guests in turns at
## the hall's seats; each eats one portion of each course (kitchen.gd AN OCCASION), the incapacitated included.
## TALLIED at the kitchen's MEAL FINALIZED event (decision 0997's reading): who ate the main course, and how many ate
## every course; the beverage poured for those who came; the buff (REQ-SET-104/105); the feast's company (+5 a pair,
## REQ-SET-036); one chronicle line. A feast at least one resident ate is COMPLETED -- it counts for M4's "12 completed
## feasts" and starts THE INTERVAL (the reading of Brendan's 2026-10-07 ruling on "Regatta day", decision 1651).
## NOT BUILT: REQ-SET-106's pause for a critical emergency (decision 1701, P5).

const Rules := preload("res://demo/feast/feast_rules.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const MenuScript := preload("res://demo/feast/feast_menu.gd")
const BuffsScript := preload("res://demo/feast/feast_buffs.gd")
const RegattaScript := preload("res://demo/regatta/regatta.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1
const ST_IDLE: int = 0
const ST_PREPARING: int = 1
const ST_ACTIVE: int = 2
const STATE_WORDS: Array[String] = ["none planned", "preparing", "being served"]

var kitchen: KitchenScript = null
var stores: StoresScript = null
var calendar: CalendarScript = null
## The winter's hearths (§5.8's fuel-days; null: the kitchen's wood alone), and the regatta (null: none).
var fuel: FuelScript = null
var regatta: RegattaScript = null
var names: PackedStringArray = PackedStringArray()
var menu: MenuScript = MenuScript.new()
var buffs: BuffsScript = BuffsScript.new()
## Hooks: `seats() -> int` (the hall's gathering seats; unbound: the kitchen's), `post(text, summary)` (the chronicle),
## `say(text)` (the village news), `share_feast(attendees)` (REQ-SET-036).
var seats: Callable = Callable()
var post: Callable = Callable()
var say: Callable = Callable()
var share_feast: Callable = Callable()
var revision: int = 0

## THE CHOICE being made (the panel's), and REQ-SET-101's override for it.
var choice_theme: int = Rules.HEARTH
var choice_day: int = NONE
var choice_host: int = NONE
var override: bool = false
## THE PLAN, once held.
var state: int = ST_IDLE
var plan_theme: int = NONE
var plan_day: int = NONE
var plan_host: int = NONE
var eligible: int = 0
var take: int = 0
var wood_held_milli: int = 0
var wood_burnt_milli: int = 0
## THE TALLY of the last feast, and every feast that STARTED (latched start ticks: the called feasts eaten, the
## regatta's served) for THE INTERVAL; how many called feasts were completed.
var attendees: PackedInt32Array = PackedInt32Array()
var every_course: int = 0
var last_line: String = ""
var starts: PackedInt64Array = PackedInt64Array()
var completed: int = 0
var refused_code: String = ""
var refused_fix: String = ""

var _finals_seen: int = NONE
var _regatta_served_seen: int = 0
var _aside: PackedInt64Array = PackedInt64Array()


func configure(p_kitchen: KitchenScript, p_stores: StoresScript, p_calendar: CalendarScript,
		p_names: PackedStringArray) -> void:
	"""The kitchen (its pantry, takes and occasion), the stores (wood and water), the calendar and the residents."""
	kitchen = p_kitchen
	stores = p_stores
	calendar = p_calendar
	names = p_names
	menu.configure(p_kitchen, p_stores)
	choice_host = first_host()
	keep_choice_current()


func bind_regatta(p_regatta: RegattaScript) -> void:
	"""The regatta: one feast among others (its hooks bound to this feast's rules), its Shared Warmth the Hearth's."""
	regatta = p_regatta
	buffs.regatta_menu = p_regatta.menu if p_regatta != null else null
	if p_regatta == null:
		return
	_regatta_served_seen = p_regatta.feasts_served
	p_regatta.feast_clash = clash_for_regatta
	p_regatta.food_days_after = regatta_food_days
	p_regatta.fuel_days_after = fuel_days_after_milli


func residents() -> int:
	"""E: every living resident present (the demo's cast)."""
	return names.size()


func name_of(who: int) -> String:
	"""Resident `who`'s name ("nobody")."""
	return names[who] if who >= 0 and who < names.size() else "nobody"


func cook() -> int:
	"""The village's cook, who cooks the feast (NONE: none)."""
	return kitchen.designated if kitchen != null else NONE


func first_host() -> int:
	"""The first resident who is not the cook (NONE: none)."""
	for who: int in residents():
		if who != cook():
			return who
	return NONE


# --- the calendar and the choice ----------------------------------------------------------------------------------

func today() -> int:
	"""The day now, from the first spring morning as 0 (the kitchen's meal days)."""
	@warning_ignore("integer_division") var day: int = calendar.hour_index() / SimClock.HOURS_PER_DAY if calendar != null else 0
	return day


func hour() -> int:
	"""The hour of the day now."""
	return calendar.now().hour if calendar != null else 0


func now_tick() -> int:
	"""The calendar tick now."""
	return calendar.tick if calendar != null else 0


func day_choices() -> PackedInt32Array:
	"""THE DAY: the next DAY_CHOICES suppers the kitchen can still cook for."""
	var out := PackedInt32Array()
	var first: int = Rules.first_day(today(), hour())
	for k: int in Rules.DAY_CHOICES:
		out.append(first + k)
	return out


func day_text(day: int) -> String:
	"""'Summer 3' ('—' none)."""
	if day < 0 or calendar == null:
		return "—"
	var at: SimClock.Calendar = calendar.calendar_at(Rules.start_tick(day))
	return CalendarScript.day_text(at.season, at.season_day)


func keep_choice_current() -> void:
	"""A chosen day no longer offered moves to the first that is; a host who became the cook moves on."""
	var choices: PackedInt32Array = day_choices()
	if not choices.has(choice_day):
		choice_day = choices[0]
	if choice_host == cook() or choice_host < 0 or choice_host >= residents():
		choice_host = first_host()


func step_theme(by: int) -> void:
	"""The previous or next theme (wrapping); REQ-SET-101's override is for one feast, so it is off again."""
	choice_theme = posmod(choice_theme + by, Rules.THEME_COUNT)
	override = false
	revision += 1


func step_day(by: int) -> void:
	"""The previous or next day offered (it stays inside the choices); the override off again."""
	var choices: PackedInt32Array = day_choices()
	var at: int = maxi(choices.find(choice_day), 0)
	choice_day = choices[clampi(at + by, 0, choices.size() - 1)]
	override = false
	revision += 1


func step_host() -> void:
	"""The next resident as keeper (never the cook)."""
	for _k: int in residents():
		choice_host = (choice_host + 1) % maxi(residents(), 1)
		if choice_host != cook():
			break
	revision += 1


func toggle_override() -> void:
	"""REQ-SET-101's explicit override, for this feast only."""
	override = not override
	revision += 1


# --- the interval ------------------------------------------------------------------------------------------------

func regatta_planned() -> bool:
	"""Whether the regatta's feast is planned and not yet tallied."""
	return regatta != null and regatta.state >= RegattaScript.ST_PLANNED and regatta.state <= RegattaScript.ST_RACED


func started_near(day: int) -> int:
	"""A latched feast start within 72 game hours of a feast on `day` (NONE: none)."""
	var at: int = Rules.start_tick(day)
	for start: int in starts:
		if Rules.too_close(start, at):
			return start
	return NONE


func clash(day: int) -> String:
	"""Why a called feast on `day` would break THE INTERVAL ("" when it would not)."""
	if regatta_planned():
		return "the regatta's feast is planned for %s: one feast is prepared at a time" % regatta.day_text(regatta.plan_day)
	return _near_words(day)


func clash_for_regatta(day: int) -> String:
	"""The regatta's hook: why its feast on `day` would break THE INTERVAL ("" when it would not)."""
	if state != ST_IDLE:
		return "the %s feast is planned for %s: one feast is prepared at a time" % [Rules.THEME_NAMES[plan_theme],
			day_text(plan_day)]
	return _near_words(day)


func _near_words(day: int) -> String:
	"""'a feast began on Summer 2: at most one in any 72 game hours' ("" none)."""
	var near: int = started_near(day)
	if near == NONE:
		return ""
	var at: SimClock.Calendar = calendar.calendar_at(near) if calendar != null else null
	var when: String = CalendarScript.day_text(at.season, at.season_day) if at != null else "lately"
	return "a feast began on %s: at most one feast in any %d game hours" % [when, Rules.INTERVAL_HOURS]


func observe_regatta() -> void:
	"""A regatta feast that was eaten since the last look starts THE INTERVAL at its supper."""
	if regatta == null or regatta.feasts_served == _regatta_served_seen:
		return
	_regatta_served_seen = regatta.feasts_served
	if regatta.plan_day >= 0:
		starts.append(Rules.start_tick(regatta.plan_day))
		revision += 1


# --- REQ-SET-101's reserves ----------------------------------------------------------------------------------------

func food_days_after_milli(theme: int, e: int) -> int:
	"""Ready food after the feast: the HUD's figure without the feast's reservation (thousandths of a day)."""
	if kitchen == null:
		return 0
	menu.set_aside(theme, e, _aside)
	return kitchen.days_of_meals_after_milli(_aside)


func regatta_food_days(e: int) -> int:
	"""The regatta's hook: ready food after its Hearth feast -- the hotpot, and the nut loaf and the infusion's herb when
	its menu can make them."""
	if kitchen == null or regatta == null:
		return 0
	_aside.resize(MealRules.CATEGORY_COUNT)
	_aside.fill(0)
	menu.add_course_drawn(_aside, MealRules.DISH_BEAN_HOTPOT, RegattaRules.main_batches(e))
	menu.add_course_drawn(_aside, MealRules.DISH_NUT_LOAF, regatta.menu.second_batches_now(e))
	if regatta.menu.infusion_short(e).is_empty():
		_aside[MenuScript.bev_selector(Rules.HEARTH)] += RegattaRules.infusion_herb_milli(e)
	return kitchen.days_of_meals_after_milli(_aside)


func fuel_days_after_milli(wood_left_milli: int) -> int:
	"""§5.8's fuel-days with `wood_left_milli` left (thousandths): over the hearths' heating demand today plus the
	kitchen's cooking mean (before a whole day is kept: its portions' batches at 0.1 U each)."""
	var heating: int = fuel.heating_day_milli() if fuel != null else 0
	var cooking: int = fuel.cook_mean_milli() if fuel != null else 0
	if cooking <= 0:
		var portions: int = kitchen.daily_portions() if kitchen != null else 2 * residents()
		cooking = RegattaRules.ceil_div(portions, 2) * MealRules.WOOD_MILLI_PER_BATCH
	@warning_ignore("integer_division") var days: int = maxi(wood_left_milli, 0) * 1000 / maxi(heating + cooking, 1)
	return days


func wood_after_milli(theme: int, e: int) -> int:
	"""The stores' wood after the feast's service wood and both courses' batches (0.1 U each) -- for a held feast, its
	service wood already set aside counted back first, so it is not taken twice."""
	var batches: int = Rules.main_batches(theme, e) + Rules.second_batches(theme, e)
	var wood: int = (stores.wood_milli_u if stores != null else 0) + wood_held_milli
	return wood - RegattaRules.service_wood_milli(e) - batches * MealRules.WOOD_MILLI_PER_BATCH


func seats_now() -> int:
	"""The hall's gathering seats (unbound: the kitchen's seats at the hall's tables)."""
	if seats.is_valid():
		return int(seats.call())
	return kitchen.places.seats.size() if kitchen != null and kitchen.places != null else 0


# --- the decision ---------------------------------------------------------------------------------------------------

func refusal(theme: int, day: int, host: int, with_override: bool) -> String:
	"""Why this feast may not be held now ("" when it may), its code and fix in `refused_code` / `refused_fix`. The
	Call button and its card both run this."""
	refused_code = ""
	refused_fix = ""
	var why: String = _plan_refusal(theme, day, host)
	if why.is_empty():
		why = _supply_refusal(theme, day, with_override)
	return why


func _refuse(code: String, words: String, fix: String) -> String:
	"""Record a refusal's code and fix; return its words."""
	refused_code = code
	refused_fix = fix
	return words


func _plan_refusal(theme: int, day: int, host: int) -> String:
	"""The occasion's half: nothing else planned, a theme, a day offered, a keeper who does not cook, 2 cooks + 1
	keeper, THE INTERVAL."""
	if state != ST_IDLE:
		return _refuse("PLANNED", "the %s feast is %s already" % [Rules.THEME_NAMES[plan_theme], STATE_WORDS[state]],
			"Cancel the feast first")
	if not Rules.valid_theme(theme):
		return _refuse("NO_THEME", "choose a theme", "Theme ▸")
	if not day_choices().has(day):
		return _refuse("NO_DAY", "that supper is past or too far ahead", "Day ▸")
	if host < 0 or host >= residents() or host == cook():
		return _refuse("HOST_COOKS", "the keeper must be a resident who does not cook it", "Keeper ▸ another resident")
	if residents() < RegattaRules.COOKS + RegattaRules.KEEPERS:
		return _refuse("STAFF", "the feast needs %d cooks and a keeper" % RegattaRules.COOKS, "")
	var why: String = clash(day)
	if why.is_empty():
		return ""
	return _refuse("INTERVAL", why, "skip this season's regatta (The regatta…), or call the feast after it" if regatta_planned()
		else "a day at least %d game hours after it" % Rules.INTERVAL_HOURS)


func _supply_refusal(theme: int, day: int, with_override: bool) -> String:
	"""The feast's half: every input (REQ-SET-099; its supper's own food counted), the service wood, the seats,
	REQ-SET-101's reserves."""
	var e: int = residents()
	var short: PackedStringArray = menu.shortfalls(theme, e, Rules.feast_key(day))
	if not short.is_empty():
		var more: String = " (and %d more: see The themes)" % (short.size() - 1) if short.size() > 1 else ""
		return _refuse("NEEDS", short[0] + more, "")
	if stores.wood_milli_u < RegattaRules.service_wood_milli(e):
		return _refuse("NO_WOOD", "the service needs %s of wood" % MenuScript.units(RegattaRules.service_wood_milli(e)),
			"Woods ▸")
	if seats_now() < RegattaRules.seats_needed(e):
		return _refuse("NO_SEATS", "the hall seats %d; the feast needs %d" % [seats_now(), RegattaRules.seats_needed(e)], "")
	var food: int = food_days_after_milli(theme, e)
	var fuel_days: int = fuel_days_after_milli(wood_after_milli(theme, e))
	var low: bool = food < Rules.RESERVE_DAYS * 1000 or fuel_days < Rules.RESERVE_DAYS * 1000
	if low and not with_override:
		return _refuse("RESERVES", "it would leave %s days of ready food and %s days of fuel (%d of each asked)" % [
			days_text(food), days_text(fuel_days), Rules.RESERVE_DAYS], "Override reserves, or wait for a harvest")
	return ""


static func days_text(milli: int) -> String:
	"""'4.2' days (tenths, floored)."""
	@warning_ignore("integer_division") var tenths: int = maxi(milli, 0) / 100
	@warning_ignore("integer_division") return "%d.%d" % [tenths / 10, tenths % 10]


# --- holding, cancelling --------------------------------------------------------------------------------------------

func hold(theme: int, day: int, host: int, with_override: bool) -> String:
	"""Hold the feast (REQ-SET-102): its food and beverage reserved, its service wood set aside, the kitchen told; ""
	when held, else why not."""
	var why: String = refusal(theme, day, host, with_override)
	if not why.is_empty():
		return why
	eligible = residents()
	take = kitchen.takes.new_take()
	menu.reserve(theme, eligible, take, calendar.hour_index() if calendar != null else 0)
	wood_held_milli = RegattaRules.service_wood_milli(eligible)
	stores.take_wood(wood_held_milli)
	kitchen.set_occasion(Rules.feast_key(day), Rules.main_dish(theme), Rules.main_batches(theme, eligible), take,
		Rules.second_dish(theme), Rules.second_batches(theme, eligible))
	state = ST_PREPARING
	plan_theme = theme
	plan_day = day
	plan_host = host
	override = false
	_say("The %s feast is called for %s's supper, kept by %s: its food is set aside" % [Rules.THEME_NAMES[theme],
		day_text(day), name_of(host)])
	revision += 1
	return ""


func cancel_refusal() -> String:
	"""Why the feast may not be cancelled now ("" when it may): only before the kitchen starts cooking its supper (15:00
	on its day) -- after that its batches are under way and would not all come back (REQ-SET-102's "untouched")."""
	if state == ST_IDLE:
		return "no feast is planned"
	if state == ST_ACTIVE:
		return "the feast is being served"
	if today() > plan_day or (today() == plan_day and hour() >= MealRules.COOK_FROM_HOUR[Rules.FEAST_MEAL]):
		return "the kitchen is cooking it"
	return ""


func cancel() -> String:
	"""REQ-SET-102: a feast cancelled before serving gives back everything it set aside, untouched. "" when done."""
	var why: String = cancel_refusal()
	if not why.is_empty():
		return why
	_let_go()
	stores.add_wood(wood_held_milli)
	wood_held_milli = 0
	_say("The %s feast is cancelled: its food and wood are back in store" % Rules.THEME_NAMES[plan_theme])
	_clear_plan()
	return ""


func _let_go() -> void:
	"""The kitchen's occasion cleared and the feast's food let go (unless the kitchen already cooks from it)."""
	if kitchen.occasion_key == Rules.feast_key(plan_day):
		if not kitchen.occasion_adopted():
			kitchen.takes.release(take)
		kitchen.clear_occasion()
	elif take != 0:
		kitchen.takes.release(take)
	take = 0
	menu.release()


func _clear_plan() -> void:
	"""Back to no feast planned."""
	state = ST_IDLE
	plan_theme = NONE
	plan_day = NONE
	plan_host = NONE
	keep_choice_current()
	revision += 1


# --- the day --------------------------------------------------------------------------------------------------------

func update() -> void:
	"""Once a frame: the regatta's served feasts latched; the buffs' tick; on the feast's day its supper served from the
	call, and tallied once the kitchen finalizes it."""
	observe_regatta()
	buffs.now_tick = now_tick()
	if state == ST_IDLE:
		return
	var day: int = today()
	if day >= plan_day and _settle():
		return
	if state == ST_PREPARING and day == plan_day and hour() >= MealRules.CALL_HOUR[Rules.FEAST_MEAL]:
		state = ST_ACTIVE
		wood_burnt_milli += wood_held_milli
		wood_held_milli = 0
		_say("The %s feast is served at the hall" % Rules.THEME_NAMES[plan_theme])
		revision += 1


func _settle() -> bool:
	"""Whether the feast's supper is settled, and if so tallied now: its MEAL FINALIZED event published, or the kitchen
	ran past it without serving it (tallied with nobody)."""
	var key: int = Rules.feast_key(plan_day)
	if kitchen.finals_published != _finals_seen:
		_finals_seen = kitchen.finals_published
		var final: KitchenScript.MealFinal = kitchen.final_of(key)
		if final != null:
			_tally(final)
			return true
	if kitchen.meal_lapsed(key):
		_tally(null)
		return true
	return false


func _tally(final: KitchenScript.MealFinal) -> void:
	"""The supper is settled: who came, the beverage poured, the buff, the company, the chronicle; the plan over."""
	_count(final)
	var at_hour: int = calendar.hour_index() if calendar != null else 0
	var poured: bool = menu.pour(plan_theme, eligible, attendees.size(), at_hour)
	_let_go()
	if wood_held_milli > 0:
		stores.add_wood(wood_held_milli)
		wood_held_milli = 0
	var buff: String = _buff_words(poured)
	if not attendees.is_empty():
		starts.append(Rules.start_tick(plan_day))
		completed += 1
		if share_feast.is_valid() and attendees.size() > 1:
			share_feast.call(attendees)
	last_line = "The %s feast (%s), kept by %s: %d of %d shared it (%s); %s" % [Rules.THEME_NAMES[plan_theme],
		day_text(plan_day), name_of(plan_host), attendees.size(), eligible, served_words(plan_theme), buff]
	if post.is_valid():
		post.call("Chronicle: %s" % last_line, "Chronicle")
	_clear_plan()


func _count(final: KitchenScript.MealFinal) -> void:
	"""Of the supper's committed diners, those who ate the main course, and how many ate both courses."""
	attendees.clear()
	every_course = 0
	if final == null or kitchen.occasion_key != Rules.feast_key(plan_day):
		return
	var both: int = KitchenScript.COURSE_MAIN | KitchenScript.COURSE_SECOND
	for who: int in final.diners:
		var ate: int = kitchen.occasion_courses(who)
		if who < residents() and ate & KitchenScript.COURSE_MAIN != 0:
			attendees.append(who)
			every_course += 1 if ate & both == both else 0
	attendees.sort()


func _buff_words(poured: bool) -> String:
	"""REQ-SET-104/105: the theme's buff when 80% of E ate every course and the beverage was poured; else why not."""
	var buff: String = Rules.BUFF_NAMES[plan_theme]
	if attendees.is_empty():
		return "nobody came, so no %s" % buff
	if not Rules.covered(every_course, eligible):
		return "no %s (%d of %d ate every course; 80%% are asked)" % [buff, every_course, eligible]
	if not poured:
		return "no %s (its %s was not all there to pour)" % [buff, MenuScript.bev_words(plan_theme)]
	return buffs.grant(plan_theme, now_tick())


static func served_words(theme: int) -> String:
	"""'bean hotpot, nut loaf and the warm infusion' -- the theme's menu in words."""
	var bev: String = "the warm infusion" if Rules.BEVERAGE[theme] == Rules.BEV_INFUSION else "mead"
	return "%s, %s and %s" % [MealRules.DISH_SHORT[Rules.main_dish(theme)], MealRules.DISH_SHORT[Rules.second_dish(theme)],
		bev]


func _say(text: String) -> void:
	"""A routine line to the village news."""
	if say.is_valid():
		say.call(text)
