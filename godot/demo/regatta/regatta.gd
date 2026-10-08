extends RefCounted
## THE REGATTA: a once-a-season occasion on the pond -- the player's day and host, a boat race between the boathouse's
## two rowboats and their crews, and the GDD's Hearth feast at the day's supper -- remembered in the chronicle. Decision
## 0438 (review SOC-023, SOC-025, UX-028; water part B lane 3; Brendan's approval of "the regatta feast", group K).
## Numbers and the feast's reading of the GDD in regatta_rules.gd. Presentation over integer rules; nothing here writes
## into the settlement simulation.
##
## PLANNING (`preview`, `hold`, `skip`): the season it is for (the first summer, then each season), the day (that season's
## days from tomorrow), the host (any resident), and the preview -- the feast's numbers as the GDD states them, what the
## village can and cannot serve, the reserves after it, the staffing and seats, the race's crews -- refusing what is
## invalid (a host who races or cooks, fewer than two helms, too few beans or greens-or-roots, too little wood, too few hands,
## the reserves under 3 days without the player's override). Held, the main course's food is RESERVED at once in a take
## the kitchen then cooks from (kitchen.gd AN OCCASION), and the service wood is set aside from the stores; both go back
## untouched if it is skipped before the feast. Held or skipped, the season is done: once a season.
##
## THE DAY. At CREW_CALL_HOUR the crews are called to the boathouse jetty (each to its own wait spot), the two rowboats
## taken (from any fishing trip that has finished with them) and laid on their lanes at their crews' paces; aboard, a
## crew is held on the water (`water_hold`). At RACE_HOUR, both boats crewed, they push off; each turns at its mark and
## rows home; the first moored wins (equal paces: a dead heat). A storm, ice, or a crew not aboard by RACE_GIVE_UP_HOUR
## calls the race off; the feast goes on. The feast is the day's supper, cooked by the kitchen as the occasion's dish;
## its service wood burns at the supper's call; its tally -- who ate the main course -- is taken from the kitchen's
## MEAL FINALIZED event for that supper (decision 0997; Brendan's ruling on review R05): published once every bowl of it
## has been eaten or given back, so a guest served at 18:59 who finishes after 19:00 is counted, and one who gives its
## bowl back is not. A supper the kitchen never served (a season skip over the day) is tallied with nobody.
##
## REMEMBERED (SOC-023: an occasion and its memory). The chronicle -- the village news, Village source, the history --
## keeps the occasion: its day, host, race and feast, and ONE MOMENT, the race's finish (or, with no race, the supper
## song). The winners' deed is recorded in their own histories through the people's ledger (`record_deed`, KIND_REGATTA,
## pinned to the chronicle); every pair who shared the feast gains REQ-SET-036's +5 affinity (`share_feast`).
##
## THE FULL MENU (decision 0682; Brendan's ruling of 2026-10-01: "add nuts & herbs now"): the second course (nut loaf) and
## the warm infusion are regatta_menu.gd's -- reserved with the main course when the pantry holds them, cooked as the
## occasion's second course, poured at the supper -- and with them Shared Warmth when 80% of E eat every course.
##
## ONE FEAST AMONG OTHERS (decision 1701, feasts #9): the village's called feasts (demo/feast/) bind three hooks --
## `feast_clash(day) -> String`, why a feast that day would break "at most 1 scheduled/active feast" (§3) or "at most
## one feast may start in any 72-game-hour interval" (§5.7) ("" when it would not); `food_days_after(E) -> int` and
## `fuel_days_after(wood_after_milli) -> int`, REQ-SET-101's post-feast reserves in thousandths of a day -- the ready
## food without the feast's reservation, and §5.8's fuel-days over the winter's hearths as well as the kitchen. Unbound
## (a check of the regatta alone), the regatta keeps its own figures.
## THE SUPPER'S OWN FOOD (Brendan's ruling on 1701 P6, 2026-10-07): while planning, the food the kitchen's planned
## ordinary supper on the regatta's day already holds counts as free to its feast (`count_supper`), since the feast
## replaces that meal: what the reservation at holding lacks, the kitchen's own top-up takes when it adopts the occasion.

const Rules := preload("res://demo/regatta/regatta_rules.gd")
const RaceTask := preload("res://demo/regatta/race_task.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const SkillsScript := preload("res://demo/fishery/fish_skills.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const MenuScript := preload("res://demo/regatta/regatta_menu.gd")

const NONE: int = -1
## The regatta's state for its season.
const ST_IDLE: int = 0
const ST_PLANNED: int = 1
const ST_CREWING: int = 2
const ST_RACING: int = 3
const ST_RACED: int = 4
const ST_DONE: int = 5
const ST_SKIPPED: int = 6
const STATE_WORDS: Array[String] = ["not planned", "planned", "crews called", "racing", "race over", "held", "skipped"]
## A crew place's step.
const C_NONE: int = 0
const C_WALK: int = 1
const C_WAIT: int = 2
const C_BOARD: int = 3
const C_SEATED: int = 4
const C_ALIGHT: int = 5
## The two race boats are the boathouse's (boat_routes.gd FISHING_BOATS), a helm and a second each.
const BOATS: int = 2
const PLACES: int = 4
## A race's serial on the boats it takes (above every trip's and the ferry's, below the rescue's).
const RACE_SERIAL: int = 900000
## Where each crew place waits by the boathouse jetty, from its land end (m; the fishery's four spots).
const WAIT_M: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-0.4, -0.9), Vector2(-0.8, 0.8), Vector2(-1.1, -0.2)]
const DECK_WALK_M_S: float = 0.6
const SEAT_DROP_M: float = 0.1
const ARRIVE_M: float = 0.6
const SPOT_BODY_M: float = 0.56
const CLIP_ROW: StringName = &"pull_radish"
const CLIP_WAIT: StringName = &"idle"
const CLIP_CHEER: StringName = &"wave_one_hand"

## The village's parts.
var fleet: FleetScript = null
var skills: SkillsScript = null
var ice: IceScript = null
var kitchen: KitchenScript = null
var stores: StoresScript = null
var calendar: CalendarScript = null
var weather: DemoWeatherScript = null
var map: WaterMapScript = null
## `post(text, summary)`: a chronicle line to the village news (Village source). `record_deed(who: PackedInt32Array,
## subject: String) -> int`: the people's ledger. `share_feast(attendees: PackedInt32Array) -> void`: REQ-SET-036.
var post: Callable = Callable()
var record_deed: Callable = Callable()
var share_feast: Callable = Callable()
## `say(text)`: a routine line to the village news.
var say: Callable = Callable()
## ONE FEAST AMONG OTHERS's hooks (see the header).
var feast_clash: Callable = Callable()
var food_days_after: Callable = Callable()
var fuel_days_after: Callable = Callable()
var revision: int = 0

## THE CHOICE being made (the panel's): the day (absolute), the host, and the reserve override.
var choice_day: int = NONE
var choice_host: int = 0
var override: bool = false
## THE PLAN, once held: its season, day, host, crews (helm and second, boat by boat), the feast's food (a take), the
## wood set aside, and E.
var state: int = ST_IDLE
var plan_season: int = NONE
var plan_day: int = NONE
var plan_host: int = NONE
var crews: PackedInt32Array = PackedInt32Array([NONE, NONE, NONE, NONE])
var take: int = 0
## The second course, the infusion and Shared Warmth (THE FULL MENU).
var menu: MenuScript = MenuScript.new()
## How many of E ate every course at the feast (THE FULL MENU's coverage).
var every_course: int = 0
## The feast's tally in words: what it served, and its Shared Warmth (or why none).
var warmth_line: String = ""
var _served_text: String = ""
var wood_held_milli: int = 0
var wood_burnt_milli: int = 0
var eligible: int = 0
## Seasons whose regatta is held or skipped (absolute seasons): once a season.
var seasons_done: PackedInt32Array = PackedInt32Array()
## THE RACE: each boat's finish tick (NONE: not home yet), the winners' boat (NONE: none yet; BOATS: a dead heat), why
## it was called off ("" when it was not), and the crews' steps.
var finish_tick: PackedInt32Array = PackedInt32Array([NONE, NONE])
var winner: int = NONE
var race_off: String = ""
var crew_step: PackedInt32Array = PackedInt32Array([C_NONE, C_NONE, C_NONE, C_NONE])
var crew_sub: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## THE FEAST'S TALLY: who ate the main course, and the chronicle's words once written.
var attendees: PackedInt32Array = PackedInt32Array()
var chronicle_line: String = ""
var moment_line: String = ""
var feasts_held: int = 0
## Regatta days whose feast was EATEN: at least one resident ate its main course (`attendees`, read off the kitchen's
## meal-finalized event), so neither a supper lapsed past by a season skip nor one closed with no hotpot eaten counts.
## What the "Regatta day" goal counts (Brendan's rulings of 2026-10-07; decision 1651).
var feasts_served: int = 0
## The last answer `refusal` gave: its code and fix, for the card.
var refused_code: String = ""
var refused_fix: String = ""

var _cast: DemoCastScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _tasks: Array = [null, null, null, null]
var _waits: PackedVector2Array = PackedVector2Array()
var _called_day: int = NONE
## Residents who could not get to the jetty this race (not called again).
var _unreached: PackedInt32Array = PackedInt32Array()
var _served_day: int = NONE
## The kitchen's published meal events already looked through (`kitchen.finals_published`).
var _finals_seen: int = NONE


func configure(cast: DemoCastScript, p_fleet: FleetScript, p_skills: SkillsScript, p_ice: IceScript,
		p_kitchen: KitchenScript, p_stores: StoresScript, p_calendar: CalendarScript, p_weather: DemoWeatherScript,
		water_map: WaterMapScript) -> void:
	"""Wire the regatta into the village: the cast, the boat core's fleet, the fishery's FISH skills and the pond's ice,
	the kitchen, the stores, the calendar, the weather and the water map."""
	_cast = cast
	fleet = p_fleet
	skills = p_skills
	ice = p_ice
	kitchen = p_kitchen
	stores = p_stores
	calendar = p_calendar
	weather = p_weather
	map = water_map
	menu.configure(p_kitchen, p_stores)
	_waits.clear()
	for k: int in PLACES:
		_waits.append(_standable(Routes.m_of(Routes.JETTY_LAND_U) + WAIT_M[k], _waits))
	choice_day = day_choices()[0] if not day_choices().is_empty() else NONE


func _standable(target: Vector2, taken: PackedVector2Array) -> Vector2:
	"""The spot nearest `target` the widest resident may stand at and reach (the fishery's rule)."""
	if _cast == null or _cast.actor_count() == 0:
		return target
	var from: Vector2 = brain_of(0).surface_point()
	for ring: int in 10:
		for k: int in (1 if ring == 0 else 12):
			var at: Vector2 = target + Vector2.from_angle(TAU * k / 12.0) * 0.3 * ring
			if CastOrdersScript.spot_ok(_cast.space(), at, SPOT_BODY_M, _cast.bounds(), PackedVector3Array(), taken, from):
				return at
	return target


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name if who >= 0 and _cast != null else "nobody"


func residents() -> int:
	"""How many residents live in the village (E: every living resident present)."""
	return _cast.actor_count() if _cast != null else 0


# --- the calendar --------------------------------------------------------------------------------------

func today() -> int:
	"""The day now, counted from the first spring morning as 0 (the kitchen's meal days: hour index / 24)."""
	@warning_ignore("integer_division") var day: int = calendar.hour_index() / SimClock.HOURS_PER_DAY if calendar != null else 0
	return day


func hour() -> int:
	"""The hour of the day now."""
	return calendar.now().hour if calendar != null else 0


func target_season() -> int:
	"""The season the next regatta is for: the first summer until then; else this season, or -- held or skipped -- the
	next."""
	var season: int = Rules.season_of_day(today())
	if season < Rules.FIRST_SEASON:
		return Rules.FIRST_SEASON
	return season + 1 if seasons_done.has(season) else season


func day_choices() -> PackedInt32Array:
	"""The days the next regatta may be held: its season's, from tomorrow on."""
	var out := PackedInt32Array()
	var first: int = Rules.first_day_of_season(target_season())
	for day: int in range(maxi(first, today() + 1), first + SimClock.DAYS_PER_SEASON):
		out.append(day)
	return out


func day_text(day: int) -> String:
	"""'Summer 3' for an absolute day ('—' none)."""
	if day < 0 or calendar == null:
		return "—"
	var at: SimClock.Calendar = calendar.calendar_at(Rules.race_tick(day, Rules.RACE_HOUR))
	return CalendarScript.day_text(at.season, at.season_day)


func step_day(by: int) -> void:
	"""The previous or next day the regatta may be held on (it stays inside the choices)."""
	var choices: PackedInt32Array = day_choices()
	if choices.is_empty():
		choice_day = NONE
		return
	var at: int = maxi(choices.find(choice_day), 0)
	choice_day = choices[clampi(at + by, 0, choices.size() - 1)]
	revision += 1


func keep_choice_current() -> void:
	"""A chosen day that has passed (or a new season's) moves to the first day still offered."""
	var choices: PackedInt32Array = day_choices()
	if not choices.has(choice_day):
		choice_day = choices[0] if not choices.is_empty() else NONE


func step_host() -> void:
	"""The next resident as host."""
	choice_host = (choice_host + 1) % maxi(residents(), 1)
	revision += 1


# --- the crews -----------------------------------------------------------------------------------------

func crews_for(host: int) -> PackedInt32Array:
	"""The race's crews for a host (helm and second, boat by boat; NONE where nobody can): the two best helms (FISH >= 1),
	then the two best others as seconds -- never the host or the village cook (they keep and cook the feast); ties to
	the lower resident."""
	var out := PackedInt32Array([NONE, NONE, NONE, NONE])
	var used := PackedInt32Array([host, kitchen.designated if kitchen != null else NONE])
	for boat: int in BOATS:
		out[boat * 2] = _best(used, true)
		used.append(out[boat * 2])
	for boat: int in BOATS:
		out[boat * 2 + 1] = _best(used, false)
		used.append(out[boat * 2 + 1])
	return out


func _best(used: PackedInt32Array, helm: bool) -> int:
	"""The resident with the most fishing not in `used` (a helm: FISH >= 1); NONE when none is left."""
	var best: int = NONE
	for who: int in residents():
		if used.has(who) or (helm and not skills.can_helm(who)):
			continue
		if best == NONE or skills.level_of(who) > skills.level_of(best):
			best = who
	return best


func pace_of(boat: int, crew: PackedInt32Array) -> int:
	"""Boat `boat`'s race pace with `crew` (regatta_rules.gd THE RACE)."""
	var helm: int = crew[boat * 2]
	var second: int = crew[boat * 2 + 1]
	return Rules.pace_permille(skills.level_of(helm) if helm >= 0 else 0, skills.level_of(second) if second >= 0 else 0)


# --- the preview and the decision (the card's and the order's own; decision 0332) -------------------------

func count_supper(day: int) -> void:
	"""THE SUPPER'S OWN FOOD (Brendan's ruling on decision 1701 P6, 2026-10-07): while planning, the food the planned
	ordinary supper of `day` holds counts as free to the feast that replaces it -- the kitchen lets it go when it adopts
	the occasion and tops the courses up from it. Held, nothing more is counted."""
	menu.supper_key = Rules.feast_key(day) if state == ST_IDLE and day >= 0 and kitchen != null else -1


static func main_beans() -> int:
	"""The main course's first input as the recipe book's bean hotpot takes it: beans."""
	return MealRules.input_selector(MealRules.DISH_BEAN_HOTPOT, 0)


static func main_greens() -> int:
	"""Its second, greens or roots through one cross-category selector (decision 1735), never retyped here."""
	return MealRules.input_selector(MealRules.DISH_BEAN_HOTPOT, 1)


static func main_greens_words() -> String:
	"""What a recipe calls the second input: "greens or roots"."""
	return MealRules.IN_WORDS[MealRules.INPUT_FIRST[MealRules.DISH_BEAN_HOTPOT] + 1]


func free_beans() -> int:
	"""Beans in the pantry nobody has set aside, milli-U (with the planned supper's own: `count_supper`)."""
	return _free_with_supper(main_beans())


func free_greens() -> int:
	"""The hotpot's second input -- greens or roots (decision 1735) -- nobody has set aside, milli-U (with the planned
	supper's own)."""
	return _free_with_supper(main_greens())


func _free_with_supper(crop: int) -> int:
	"""Selector `crop`'s free food, and what the supper `count_supper` named holds of it."""
	var held: int = kitchen.held_for_meal_milli(menu.supper_key, crop) if menu.supper_key >= 0 else 0
	return kitchen.takes.free_milli_of_crop(kitchen.pantry, crop) + held


func main_food_milli(eligible_now: int) -> int:
	"""Beans (and, the same, greens or roots) the main course takes: ceil(E/3) batches of bean_hotpot."""
	return Rules.main_batches(eligible_now) * MealRules.INPUT_MILLI[MealRules.DISH_BEAN_HOTPOT]


func daily_wood_milli() -> int:
	"""The kitchen's wood a day: its daily portions in batches of two, 0.1 U a batch."""
	var portions: int = kitchen.daily_portions() if kitchen != null else residents() * 2
	return maxi(Rules.ceil_div(portions, 2) * MealRules.WOOD_MILLI_PER_BATCH, 1)


func food_days_milli() -> int:
	"""Ready food (the HUD's days of meals, thousandths): the feast's beans and greens are outside it, so it is the
	figure the feast leaves; the feasts' figure when bound (ONE FEAST AMONG OTHERS)."""
	if food_days_after.is_valid():
		return int(food_days_after.call(residents()))
	return kitchen.days_of_meals_milli() if kitchen != null else 0


func fuel_days_milli(eligible_now: int) -> int:
	"""Days of wood left after the feast's service and its batches (thousandths): the kitchen's alone, or -- the feasts'
	hook bound (ONE FEAST AMONG OTHERS) -- §5.8's over the hearths and the kitchen."""
	var batches: int = Rules.main_batches(eligible_now) + menu.second_batches_now(eligible_now)
	var after: int = stores.wood_milli_u - Rules.service_wood_milli(eligible_now) - batches * MealRules.WOOD_MILLI_PER_BATCH
	if fuel_days_after.is_valid():
		return int(fuel_days_after.call(after))
	@warning_ignore("integer_division") var days: int = maxi(after, 0) * 1000 / daily_wood_milli()
	return days


func refusal(day: int, host: int, with_override: bool) -> String:
	"""Why a regatta on `day` hosted by `host` may not be held now ("" when it may), its code and fix in `refused_code`
	/ `refused_fix`. The Hold button and its card both run this."""
	refused_code = ""
	refused_fix = ""
	count_supper(day)
	var why: String = _plan_refusal(day, host)
	if why.is_empty():
		why = _feast_refusal(with_override, day)
	return why


func _refuse(code: String, words: String, fix: String) -> String:
	"""Record a refusal's code and fix; return its words."""
	refused_code = code
	refused_fix = fix
	return words


func _plan_refusal(day: int, host: int) -> String:
	"""The occasion's half: a season left, a day, a host who neither races nor cooks, two crews and hands to cook."""
	if state != ST_IDLE:
		return _refuse("PLANNED", "the regatta is %s already" % STATE_WORDS[state], "Skip this season to call it off")
	if day < 0 or not day_choices().has(day):
		return _refuse("NO_DAY", "no day is left this season", "next season's regatta")
	if host < 0 or host >= residents():
		return _refuse("NO_HOST", "choose a host", "Host ▸")
	if kitchen != null and host == kitchen.designated:
		return _refuse("HOST_COOKS", "%s cooks the feast: the host keeps it" % name_of(host), "Host ▸ another resident")
	var crew: PackedInt32Array = crews_for(host)
	if crew.has(NONE):
		return _refuse("NO_CREW", "the race needs two helms (fishing %d) and two seconds besides the host and the cook" %
			FisheryRules.HELM_MIN_LEVEL, "a fisher learns on a net from the bank")
	if residents() < Rules.COOKS + Rules.KEEPERS:
		return _refuse("STAFF", "the feast needs %d cooks and a keeper" % Rules.COOKS, "")
	return ""


func _feast_refusal(with_override: bool, day: int = NONE) -> String:
	"""The feast's half: no other feast planned or started within 72 h of `day` (ONE FEAST AMONG OTHERS), the main
	course's beans and greens or roots free, the service wood, the seats, and REQ-SET-101's reserves -- refused under 3 days
	unless overridden."""
	var e: int = residents()
	var clash: String = String(feast_clash.call(day)) if feast_clash.is_valid() else ""
	if not clash.is_empty():
		return _refuse("FEAST_CLASH", clash, "Cancel the called feast, or choose a later day")
	var need: int = main_food_milli(e)
	if free_beans() < need:
		return _refuse("NO_BEANS", "the main course (bean hotpot x%d) needs %s of beans; the pantry has %s free" % [
			Rules.main_batches(e), _units(need), _units(free_beans())], "plant peas or broad beans")
	if free_greens() < need:
		return _refuse("NO_GREENS", "the main course needs %s of %s; the pantry has %s free" % [_units(need), main_greens_words(),
			_units(free_greens())], "plant cabbage, lettuce, spinach, leek or celery, or any root")
	if stores.wood_milli_u < Rules.service_wood_milli(e):
		return _refuse("NO_WOOD", "the feast's service needs %s of wood" % _units(Rules.service_wood_milli(e)), "Woods ▸")
	if kitchen != null and kitchen.places.seats.size() < Rules.seats_needed(e):
		return _refuse("NO_SEATS", "the hall seats %d; the feast needs %d" % [kitchen.places.seats.size(),
			Rules.seats_needed(e)], "")
	var short: bool = food_days_milli() < Rules.RESERVE_DAYS * 1000 or fuel_days_milli(e) < Rules.RESERVE_DAYS * 1000
	if short and not with_override:
		return _refuse("RESERVES", "it would leave %s days of ready food and %s days of fuel (%d of each asked)" % [
			_days(food_days_milli()), _days(fuel_days_milli(e)), Rules.RESERVE_DAYS], "Override reserves, or wait for a harvest")
	return ""


static func _units(milli: int) -> String:
	"""'6.0 U' (the woods' own words)."""
	return ForestRules.units_text(milli)


static func _days(milli: int) -> String:
	"""'4.2' days (tenths, floored)."""
	@warning_ignore("integer_division") var tenths: int = milli / 100
	@warning_ignore("integer_division") return "%d.%d" % [tenths / 10, tenths % 10]


func preview_lines(day: int, host: int) -> PackedStringArray:
	"""The preview (REQ-SET-100: attendees, the courses and their food, staffing, seats, reserves), in lines."""
	count_supper(day)
	var e: int = residents()
	var lines := PackedStringArray()
	lines.append("%s: the %s feast for %d (every resident), at the day's supper; hosted by %s" % [day_text(day),
		Rules.THEME_NAME, e, name_of(host)])
	lines.append("Main: bean hotpot x%d (%d portions): beans %s (free %s), %s %s (free %s), water %s" % [
		Rules.main_batches(e), Rules.main_batches(e) * MealRules.PORTIONS_PER_BATCH[MealRules.DISH_BEAN_HOTPOT],
		_units(main_food_milli(e)), _units(free_beans()), main_greens_words(), _units(main_food_milli(e)), _units(free_greens()),
		_units(Rules.main_batches(e) * MealRules.WATER_MILLI[MealRules.DISH_BEAN_HOTPOT])])
	lines.append_array(menu.preview_lines(e))
	lines.append("Seats %d of %d needed · service wood %s set aside now · staffing: %s" % [
		kitchen.places.seats.size() if kitchen != null else 0, Rules.seats_needed(e), _units(Rules.service_wood_milli(e)),
		staffing_words(host)])
	lines.append("After it: ready food %s days, wood %s days (REQ-SET-101 asks 3)" % [_days(food_days_milli()),
		_days(fuel_days_milli(e))])
	lines.append(race_words(crews_for(host)))
	return lines


func staffing_words(host: int) -> String:
	"""The GDD's 2 cooks + 1 keeper, named (the demo has no cooking skill to check the GDD's skill 2 against): the village
	cook, a second who is not racing where one is free (the race is over by 16:00, before supper, so a racer may help),
	and the host."""
	var cook: int = kitchen.designated if kitchen != null else NONE
	var crew: PackedInt32Array = crews_for(host)
	var helper: int = NONE
	for who: int in residents():
		if who != host and who != cook and (helper == NONE or crew.has(helper)):
			helper = who if helper == NONE or not crew.has(who) else helper
	return "%s and %s cook, %s keeps it (no cooking skill to check)" % [name_of(cook), name_of(helper), name_of(host)]


func race_words(crew: PackedInt32Array) -> String:
	"""'Race: Rowboat 1 Corra Netley + Jory Whitethorn (pace 116%) v Rowboat 2 ...'."""
	if crew.has(NONE):
		return "Race: no crews"
	var parts := PackedStringArray()
	for boat: int in BOATS:
		@warning_ignore("integer_division") parts.append("%s %s + %s (pace %d%%)" % [Routes.boat_name(boat), name_of(crew[boat * 2]), name_of(crew[boat * 2 + 1]),
			pace_of(boat, crew) / 10])
	return "Race at %02d:00: %s" % [Rules.RACE_HOUR, " v ".join(parts)]


# --- holding, skipping ---------------------------------------------------------------------------------

func hold(day: int, host: int, with_override: bool) -> String:
	"""Hold the regatta (the panel's Hold, the same decision as its card): its main course's food reserved, its service
	wood set aside, the kitchen told; "" when held, else why not."""
	var why: String = refusal(day, host, with_override)
	if not why.is_empty():
		return why
	eligible = residents()
	take = kitchen.takes.new_take()
	var need: int = main_food_milli(eligible)
	var at_hour: int = calendar.hour_index() if calendar != null else 0
	kitchen.takes.reserve_into(kitchen.pantry, take, main_beans(), need, at_hour, _read)
	kitchen.takes.reserve_into(kitchen.pantry, take, main_greens(), need, at_hour, _read)
	menu.reserve(take, eligible, at_hour)
	menu.supper_key = -1
	wood_held_milli = Rules.service_wood_milli(eligible)
	stores.take_wood(wood_held_milli)
	kitchen.set_occasion(Rules.feast_key(day), MealRules.DISH_BEAN_HOTPOT, Rules.main_batches(eligible), take,
		menu.second_dish(), Rules.second_batches(eligible) if menu.second_planned else 0)
	state = ST_PLANNED
	plan_season = Rules.season_of_day(day)
	plan_day = day
	plan_host = host
	crews = crews_for(host)
	seasons_done.append(plan_season)
	_say("The regatta is set for %s, hosted by %s: the feast's food is set aside" % [day_text(day), name_of(host)])
	revision += 1
	return ""


func skip_refusal() -> String:
	"""Why this season's regatta may not be skipped now ("" when it may): once its race has begun, or a batch of its
	feast's supper is at the cauldron or cooked (Cook now can start it before the race: its batches would not all come
	back, and the table drink would take the supper for an ordinary one -- decision 1733's fix), it is held."""
	if state == ST_CREWING or state == ST_RACING or state == ST_RACED:
		return "the regatta is under way"
	if state == ST_PLANNED and kitchen.meal_under_way(Rules.feast_key(plan_day)):
		return "the kitchen is cooking its feast"
	if state == ST_DONE or state == ST_SKIPPED:
		return "this season's regatta is %s" % STATE_WORDS[state]
	return ""


func skip() -> String:
	"""Skip the season's regatta (no penalty, nothing withheld): a held plan's food and wood given back untouched.
	"" when skipped."""
	var why: String = skip_refusal()
	if not why.is_empty():
		return why
	if state == ST_PLANNED:
		_release_plan()
	else:
		plan_season = target_season()
		seasons_done.append(plan_season)
	state = ST_SKIPPED
	_say("This season's regatta is skipped: no harm done, the next season's is the village's to plan")
	revision += 1
	return ""


func _release_plan() -> void:
	"""Give back what a held plan set aside: the food (unless the kitchen already cooks from it), the wood."""
	if not kitchen.occasion_adopted():
		kitchen.takes.release(take)
	kitchen.clear_occasion()
	stores.add_wood(wood_held_milli)
	wood_held_milli = 0
	take = 0
	menu.release()


# --- the day -------------------------------------------------------------------------------------------

func update() -> void:
	"""Once a frame: on the regatta's day, the crews' call, the start, the turn and finish, the feast's service and
	tally; a new season opens the next choice."""
	if state != ST_CREWING and state != ST_RACING:
		_give_boats_back()
	if state == ST_DONE or state == ST_SKIPPED:
		if Rules.season_of_day(today()) > plan_season:
			_open_next_season()
		return
	if state == ST_IDLE or plan_day < 0:
		return
	var day: int = today()
	var h: int = hour()
	if day >= plan_day and _settle_feast():
		return
	if day != plan_day or h >= MealRules.END_HOUR[Rules.FEAST_MEAL]:
		return
	_follow_race(h)
	if h >= MealRules.CALL_HOUR[Rules.FEAST_MEAL] and _served_day != day:
		_served_day = day
		wood_burnt_milli += wood_held_milli
		wood_held_milli = 0
		_say("The regatta's feast is served at the hall: %s for everyone" % served_words())


func _open_next_season() -> void:
	"""A new season after a held or skipped one: the next regatta's choice opens."""
	state = ST_IDLE
	plan_day = NONE
	race_off = ""
	winner = NONE
	moment_line = ""
	attendees.clear()
	finish_tick = PackedInt32Array([NONE, NONE])
	crew_step = PackedInt32Array([C_NONE, C_NONE, C_NONE, C_NONE])
	choice_day = day_choices()[0] if not day_choices().is_empty() else NONE
	revision += 1


func _follow_race(h: int) -> void:
	"""The race's hours: crews called, the start once crewed, the turn and the finish, or called off."""
	if state == ST_PLANNED and h >= Rules.CREW_CALL_HOUR:
		_call_crews()
	if state == ST_CREWING and h >= Rules.RACE_HOUR and race_off.is_empty():
		var why: String = _start_refusal()
		if why.is_empty() and _all_seated():
			_start()
		elif not why.is_empty() or h >= Rules.RACE_GIVE_UP_HOUR:
			_call_off(why if not why.is_empty() else "a crew was not aboard by %02d:00" % Rules.RACE_GIVE_UP_HOUR)
	if state == ST_RACING:
		_follow_boats()


func _start_refusal() -> String:
	"""Why the race may not start now ("" when it may): REQ-SET-052's storm, the pond's ice."""
	if weather != null and weather.event() == WeatherScript.EVENT_HEAVY_RAIN:
		return "a storm"
	if ice != null and ice.frozen():
		return "ice on the pond"
	return ""


func _call_crews() -> void:
	"""Each crew member to its wait by the boathouse jetty (its work parked: the brain's resuming)."""
	state = ST_CREWING
	_called_day = plan_day
	_unreached.clear()
	for place: int in PLACES:
		_order_place(place)
	_say("The regatta's crews are called to %s" % Routes.JETTY_NAME)
	revision += 1


func _order_place(place: int) -> void:
	"""Crew place `place`'s resident called to its wait by the jetty (its work parked), unless the water holds it."""
	var brain: BrainScript = brain_of(crews[place])
	if brain.water_hold or brain.in_water or brain.underground:
		return
	var task := RaceTask.new(self, place)
	_tasks[place] = task
	crew_step[place] = C_WALK
	brain.order_task(task)


func _all_seated() -> bool:
	"""Whether every crew member sits in its boat, both boats taken for the race."""
	for place: int in PLACES:
		if crew_step[place] != C_SEATED:
			return false
	for boat: int in BOATS:
		if fleet.owner[boat] != RACE_SERIAL:
			return false
	return true


func _start() -> void:
	"""Both boats push off down their lanes."""
	for boat: int in BOATS:
		fleet.set_off(boat)
	state = ST_RACING
	_say("The regatta's race is off!")
	revision += 1


func _follow_boats() -> void:
	"""Each boat at its mark turns for home; each moored is home (its tick kept); both home, the winner is decided."""
	for boat: int in BOATS:
		if fleet.phase[boat] == FleetScript.PHASE_ON_STATION:
			fleet.row_back(boat)
		elif fleet.phase[boat] == FleetScript.PHASE_MOORED and finish_tick[boat] == NONE:
			finish_tick[boat] = calendar.tick if calendar != null else 0
			revision += 1
	if finish_tick[0] != NONE and finish_tick[1] != NONE:
		_decide()


func _decide() -> void:
	"""The first home wins (the same tick: a dead heat); the crews step ashore."""
	if finish_tick[0] == finish_tick[1]:
		winner = BOATS
	else:
		winner = 0 if finish_tick[0] < finish_tick[1] else 1
	state = ST_RACED
	moment_line = moment_words()
	_say(moment_line)
	for place: int in PLACES:
		if crew_step[place] == C_SEATED:
			crew_step[place] = C_ALIGHT
			crew_sub[place] = 0
	revision += 1


func moment_words() -> String:
	"""THE MOMENT: the race's finish, in words."""
	if winner == BOATS:
		return "A dead heat! Both crews cross the line together"
	if winner < 0:
		return ""
	return "%s and %s bring %s home first" % [name_of(crews[winner * 2]), name_of(crews[winner * 2 + 1]),
		Routes.boat_name(winner).to_lower()]


func _call_off(why: String) -> void:
	"""No race today: the boats given back, the crews sent ashore (or back to their routine)."""
	race_off = why
	state = ST_RACED
	for place: int in PLACES:
		if crew_step[place] == C_SEATED or crew_step[place] == C_BOARD:
			crew_step[place] = C_ALIGHT
			crew_sub[place] = 0
		elif crew_step[place] != C_NONE:
			crew_step[place] = C_NONE
	_give_boats_back()
	_say("The regatta's race is called off: %s — the feast goes on" % why)
	revision += 1


func _give_boats_back() -> void:
	"""Each race boat moored again is the boathouse's (its race pace back to ordinary)."""
	for boat: int in BOATS:
		if fleet.owner[boat] == RACE_SERIAL and fleet.phase[boat] == FleetScript.PHASE_MOORED:
			fleet.give_back(boat, RACE_SERIAL)


# --- the crews' places (race_task.gd) -----------------------------------------------------------------

func crew_site(place: int) -> Vector2:
	"""Where crew place `place` waits by the boathouse jetty."""
	return _waits[place] if _waits.size() > place else Routes.m_of(Routes.JETTY_LAND_U)


func crew_arrived(place: int, brain: BrainScript) -> void:
	"""At its wait: it waits for its boat (unreached: replaced, see `_replace`); arriving after the race was called
	off (or once it is over), its part is over."""
	if state != ST_CREWING or not race_off.is_empty():
		crew_step[place] = C_NONE
		_tasks[place] = null
		return
	if brain.arrived_near(crew_site(place), ARRIVE_M):
		crew_step[place] = C_WAIT
	else:
		_replace(place, brain.index)


func crew_called_away(place: int, brain: BrainScript) -> void:
	"""Taken off before boarding (aboard it is held): a walk it could not finish is replaced (`_replace`); an order
	or the like leaves its boat uncrewed."""
	if crew_step[place] == C_SEATED or crew_step[place] == C_ALIGHT:
		return
	if brain.trip_failed() and state == ST_CREWING:
		_replace(place, brain.index)
		return
	crew_step[place] = C_NONE
	_tasks[place] = null


func _replace(place: int, failed: int) -> void:
	"""A crew member who could not get to the jetty gives its place to the next best still free -- a helm for a helm's
	place, never the host or the cook; with none, its boat is not crewed (the race is called off at RACE_GIVE_UP_HOUR)."""
	crew_step[place] = C_NONE
	_tasks[place] = null
	_unreached.append(failed)
	if state != ST_CREWING:
		return
	var used := PackedInt32Array([plan_host, kitchen.designated if kitchen != null else NONE])
	used.append_array(crews)
	used.append_array(_unreached)
	var who: int = _best(used, place % 2 == 0)
	if who == NONE:
		return
	crews[place] = who
	_say("%s could not get to %s: %s takes the place" % [name_of(failed), Routes.JETTY_NAME, name_of(who)])
	_order_place(place)


func crew_drive(place: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of a crew place: wait, board when its boat is the race's, sit and row, step ashore. False once over."""
	match crew_step[place]:
		C_WAIT:
			_crew_wait(place, brain, delta)
		C_BOARD:
			_crew_board(place, brain, delta)
		C_SEATED:
			_crew_sit(place, brain)
		C_ALIGHT:
			return _crew_alight(place, brain, delta)
		C_NONE:
			return false
	return true


func _crew_wait(place: int, brain: BrainScript, delta: float) -> void:
	"""Waiting by the jetty: its boat taken for the race (once free of any fishing trip) and laid on its lane, it boards."""
	brain.task_face(Routes.m_of(Routes.JETTY_END_U), delta)
	brain.task_play(CLIP_WAIT)
	@warning_ignore("integer_division") var boat: int = place / 2
	if state != ST_CREWING or not race_off.is_empty():
		crew_step[place] = C_NONE
		_tasks[place] = null
		return
	if fleet.owner[boat] != RACE_SERIAL:
		if not fleet.is_free(boat):
			return
		fleet.set_course(boat, Rules.lane(boat), map)
		fleet.take(boat, RACE_SERIAL)
		fleet.pace_permille[boat] = pace_of(boat, crews)
	crew_step[place] = C_BOARD
	crew_sub[place] = 0


func _crew_board(place: int, brain: BrainScript, delta: float) -> void:
	"""Down the jetty to its boat's berth step, and into its seat (held on the water from the first plank)."""
	@warning_ignore("integer_division") var boat: int = place / 2
	brain.water_hold = true
	var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if crew_sub[place] == 0 else fleet.seat_m(boat, place % 2)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M, delta):
		return
	if crew_sub[place] == 0:
		crew_sub[place] = 1
		return
	fleet.seat(boat, place % 2, brain.index)
	crew_step[place] = C_SEATED


func _crew_sit(place: int, brain: BrainScript) -> void:
	"""In its seat wherever the boat is; the helm pulls while it rows; at the finish the winners wave."""
	@warning_ignore("integer_division") var boat: int = place / 2
	brain.water_place(fleet.seat_m(boat, place % 2), Routes.JETTY_DECK_Y_M - SEAT_DROP_M, fleet.yaw(boat))
	var under_oars: bool = fleet.moving(boat)
	brain.task_play(CLIP_ROW if under_oars else (CLIP_CHEER if boat == winner or winner == BOATS else CLIP_WAIT))


func _crew_alight(place: int, brain: BrainScript, delta: float) -> bool:
	"""Out of the seat, up the jetty to its land end; off the water there; the boat given back once its crew is ashore."""
	@warning_ignore("integer_division") var boat: int = place / 2
	if crew_sub[place] == 0:
		if fleet.crew_of(boat, place % 2) == brain.index:
			fleet.seat(boat, place % 2, FleetScript.NOBODY)
		crew_sub[place] = 1
	var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if crew_sub[place] == 1 else crew_site(place)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M if crew_sub[place] == 1 else 0.0, delta):
		return true
	if crew_sub[place] == 1:
		crew_sub[place] = 2
		return true
	brain.water_hold = false
	crew_step[place] = C_NONE
	_tasks[place] = null
	if fleet.crew_of(boat, 0) == FleetScript.NOBODY and fleet.crew_of(boat, 1) == FleetScript.NOBODY:
		_give_boats_back()
	return false


func rowing(who: int) -> bool:
	"""Whether `who` is in a race boat under oars now (the songs read it as work: decision 0438)."""
	if state != ST_RACING:
		return false
	var place: int = crews.find(who)
	@warning_ignore("integer_division") var boat: int = place / 2
	return place >= 0 and crew_step[place] == C_SEATED and fleet.moving(boat)


func crew_text(place: int) -> String:
	"""What a crew member is doing, in words."""
	match crew_step[place]:
		C_WALK:
			return "going to the regatta's start at %s" % Routes.JETTY_NAME
		C_WAIT:
			return "waiting for the regatta's boat"
		C_BOARD:
			return "boarding for the regatta"
		C_SEATED:
			return "racing in the regatta" if state == ST_RACING else "in the regatta's boat"
		C_ALIGHT:
			return "stepping ashore after the regatta"
	return "the regatta"


func _deck_walk(brain: BrainScript, target: Vector2, y_m: float, delta: float) -> bool:
	"""A straight walk on the jetty's deck at its height (presentation). True once there."""
	var to: Vector2 = target - brain.position
	if to.length() <= 0.05:
		brain.water_place(target, y_m, brain.yaw)
		brain.task_play(CLIP_WAIT)
		return true
	brain.water_place(brain.position + to.normalized() * minf(DECK_WALK_M_S * delta, to.length()), y_m, atan2(to.x, to.y))
	brain.task_play(BrainScript.CLIP_WALK)
	return false


# --- the feast's tally and the chronicle -------------------------------------------------------------------

func _settle_feast() -> bool:
	"""Whether the feast's supper is settled, and if so tallied now: the kitchen has published its MEAL FINALIZED event
	(every bowl eaten or given back), or the kitchen ran past it without serving it (`meal_lapsed`: tallied with nobody).
	False while a guest still holds a bowl of it, or before it."""
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
	"""The supper is settled (`final`: its event; null: never served): who ate the main course, the chronicle, the
	winners' deed, the feast's company; the kitchen's occasion cleared; the season held."""
	var key: int = Rules.feast_key(plan_day)
	_count_attendees(key, final)
	_served_text = served_words()
	warmth_line = menu.settle(eligible, attendees.size(), every_course, calendar.tick if calendar != null else 0,
		calendar.hour_index() if calendar != null else 0)
	if kitchen.occasion_key == key:
		if not kitchen.occasion_adopted():
			kitchen.takes.release(take)
		kitchen.clear_occasion()
	take = 0
	if wood_held_milli > 0:
		stores.add_wood(wood_held_milli)
		wood_held_milli = 0
	if winner == NONE and race_off.is_empty():
		_call_off("the race never started")
	state = ST_DONE
	feasts_held += 1
	feasts_served += 1 if not attendees.is_empty() else 0
	_remember()
	revision += 1


func _count_attendees(key: int, final: KitchenScript.MealFinal) -> void:
	"""Who shared the feast -- of the supper's committed diners (`final`'s), those who ate its main course -- and how
	many ate every course served; residents in order."""
	attendees.clear()
	every_course = 0
	if final == null or kitchen.occasion_key != key:
		return
	var all_courses: int = KitchenScript.COURSE_MAIN | (KitchenScript.COURSE_SECOND if menu.second_planned else 0)
	for who: int in final.diners:
		var ate: int = kitchen.occasion_courses(who)
		if who < residents() and ate & KitchenScript.COURSE_MAIN != 0:
			attendees.append(who)
			every_course += 1 if ate & all_courses == all_courses else 0
	attendees.sort()


func served_words() -> String:
	"""'bean hotpot, nut loaf and the warm infusion' -- what the held feast serves."""
	var parts := PackedStringArray(["bean hotpot"])
	if menu.second_planned:
		parts.append(Rules.SECOND_COURSE)
	if menu.infusion_planned:
		parts.append("the warm infusion")
	if parts.size() == 1:
		return parts[0]
	return "%s and %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1]]


func _remember() -> void:
	"""THE CHRONICLE: the occasion's line and its one moment; the winners' deed; the feast's company."""
	if moment_line.is_empty():
		moment_line = "the supper song round the hall's tables" if not attendees.is_empty() else "the boats at rest on the pond"
	var race: String = moment_words() if race_off.is_empty() else "no race (%s)" % race_off
	chronicle_line = "The %s regatta (%s), hosted by %s: %s; %d of %d shared the feast (%s; %s)" % [
		_season_name(), day_text(plan_day), name_of(plan_host), race, attendees.size(), eligible, _served_text, warmth_line]
	if post.is_valid():
		post.call("Chronicle: %s. The moment: %s" % [chronicle_line, moment_line], "Chronicle")
	if winner >= 0 and winner < BOATS and record_deed.is_valid():
		record_deed.call(PackedInt32Array([crews[winner * 2], crews[winner * 2 + 1]]), "%s regatta's race" % _season_name())
	if share_feast.is_valid() and attendees.size() > 1:
		share_feast.call(attendees)


func warmth_status() -> String:
	"""' · Shared Warmth: 31 h left' while it lasts ('' otherwise)."""
	var now: int = calendar.tick if calendar != null else 0
	return " · %s: %d h left" % [Rules.BUFF_NAME, menu.warmth_hours_left(now)] if menu.warmth_active(now) else ""


func _season_name() -> String:
	"""'summer' for the plan's season."""
	return CalendarScript.SEASON_TITLES[posmod(plan_season, Rules.SEASONS_PER_YEAR)].to_lower()


func _say(text: String) -> void:
	"""A routine line to the village news."""
	if say.is_valid():
		say.call(text)


func status_line() -> String:
	"""'Regatta (summer): held on Summer 3 — ...' / 'planned for ...' / 'first in summer'."""
	var season: String = CalendarScript.SEASON_TITLES[posmod(target_season(), Rules.SEASONS_PER_YEAR)].to_lower()
	match state:
		ST_IDLE:
			return "Regatta (%s): not planned — once a season, the first in summer; skipping costs nothing" % season
		ST_SKIPPED:
			return "Regatta: this season's is skipped (no penalty); the next season's opens when it begins"
		ST_DONE:
			return "Regatta: held. %s%s" % [chronicle_line, warmth_status()]
	var at: String = day_text(plan_day)
	var race: String = moment_line if not moment_line.is_empty() else (("off: " + race_off) if not race_off.is_empty() else "")
	return "Regatta: %s for %s, hosted by %s%s" % [STATE_WORDS[state], at, name_of(plan_host), (" — " + race) if not race.is_empty() else ""]
