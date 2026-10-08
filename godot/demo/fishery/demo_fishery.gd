extends Node3D
## WATER PART B in the village (decision 0431): the fishery (fishery.gd) wired to the cast, the one water, the pantry,
## the kitchen's reservations, the stores, the calendar and weather, the Water panel, the work board, the rescue, the
## map layer, the incidents and the sound. Presentation over integer rules; nothing writes into the simulation.
##
## PLAYER VERBS (the Water panel's Fishing, Boats and rack-and-mill sections; every button's tooltip is its ACTION CARD
## from the order's own decision, decision 0332):
##   Site ▸ / Method ▸ / Fish ▸     choose the trip: the run, the ford or the pond; hand net, trap, boat or ice fishing;
##                                  one of that water's fish (the six the village's water holds; never eel or pike), or
##                                  Best catch: §5.4's auto mode, chosen again at the water (decision 1712)
##   Traps: when soaked / morning   when new traps are collected (decision 1712)
##   Intensive: off / on            the chosen water's intensive harvest; its card shows the 10% floor and the recovery
##                                  time first (REQ-SET-049, decision 1713)
##   Authorise trip                 the trip's seats go on the work board -- to the selected residents first
##   Next trip ▸ / Cancel trip      call a trip off: its cycle, gear claim and held room released at once
##   Make net / trap / ice kit      at the workbench, from the stores' wood and the locker's rope or iron
##   Mend gear                      the most worn free gear (or boat): 200 points, wood 1 + rope 0.25
##   Dry fish                       4 U of the fresh fish that spoils first onto the rack: 3 U dried in 12 h
##   Mill grain                     3 U of grain to the mill: 3 U of flour
##   Dry fruit                      4 U of the fruit that spoils first onto the rack: 3 U dried in 12 h (decision 1611)
##   Pack rations                   flour 2, dried fish 1, nuts 1, water 1 at the preserving table: 3 U of rations
##   Brew mead                      honey 3, water 3 into a vat at the brewery: 4 U of mead after 72 h (decision 1621)
##   Make cordial                   berries 2, honey 0.5, water 2 at the brewery's bench: 4 U of the raspberry cordial
##   Make jam / Make cheese         the preserving table's berry jam and nut cheese (decision 1625, provisional)
##   Brew ale / Make cider          the brewery's ale and cider (decision 1625, provisional)
##   Make vinegar / Make pickles    apple vinegar in a vat, then salt-free pickles in a crock (decision 1625, provisional)
##
## TIME. The fishery runs on this frame's demo time (paused, nothing moves or cures; at 4x everything four times as
## fast); the panel and the incidents follow on real time (they work paused), the panel only while shown.
##
## INCIDENTS (decision 0331). An OVERDUE trip -- out past its estimate by two game hours -- is a WARNING,
## "water:overdue:<trip>", on its first crew member, resolved when the trip is over. THIN ICE on the pond is a WARNING,
## "water:thin_ice", while the pond is frozen but not yet safe to walk on, resolved when it is safe or gone.

const FisheryScript := preload("res://demo/fishery/fishery.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Text := preload("res://demo/fishery/fishery_text.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const LockerScript := preload("res://demo/fishery/gear_locker.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const BoatViewScript := preload("res://demo/boats/boat_view.gd")
const BoatRescueScript := preload("res://demo/boats/boat_rescue.gd")
const FisheryViewScript := preload("res://demo/fishery/fishery_view.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const PreserveText := preload("res://demo/preserve/preserve_text.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const RationReserveScript := preload("res://demo/preserve/ration_reserve.gd")
const PlanScript := preload("res://demo/fishery/catch_plan.gd")
const RollsScript := preload("res://demo/fishery/fishing_rolls.gd")
const StewardScript := preload("res://demo/fishery/fishery_stewardship.gd")

const PANEL_REFRESH_S: float = 0.25
const OVERDUE_KEY: String = "water:overdue:%d"
const THIN_ICE_KEY: String = "water:thin_ice"
## The station recipes' buttons (preserve_rules.gd rows: decisions 0434, 1611, 1621, 1625).
const ACTION_RECIPES: Dictionary = {PanelScript.ACTION_DRY: Recipes.R_DRY_FISH, PanelScript.ACTION_DRY_FRUIT: Recipes.R_DRY_FRUIT,
	PanelScript.ACTION_RATIONS: Recipes.R_RATION, PanelScript.ACTION_MEAD: Recipes.R_MEAD,
	PanelScript.ACTION_CORDIAL: Recipes.R_CORDIAL, PanelScript.ACTION_JAM: Recipes.R_JAM,
	PanelScript.ACTION_CHEESE: Recipes.R_CHEESE, PanelScript.ACTION_ALE: Recipes.R_ALE, PanelScript.ACTION_CIDER: Recipes.R_CIDER,
	PanelScript.ACTION_VINEGAR: Recipes.R_VINEGAR, PanelScript.ACTION_PICKLES: Recipes.R_PICKLES}
## The Make buttons' locker kinds.
const MAKE_ACTIONS: Array[StringName] = [PanelScript.ACTION_MAKE_NET, PanelScript.ACTION_MAKE_TRAP,
	PanelScript.ACTION_MAKE_ICE_KIT]

var fishery: FisheryScript = FisheryScript.new()
var boat_rescue: BoatRescueScript = BoatRescueScript.new()
var boat_view: BoatViewScript = null
var view: FisheryViewScript = null
var services: ServicesScript = null
## The trip being chosen in the panel: its site, method and fish (0..2 at the site); the trip Cancel acts on.
var choice_site: int = Driver.SITE_POND
var choice_method: int = Rules.METHOD_BOAT
var choice_species: int = 0
var chosen_trip: int = -1
## What the last frame's fishery, boats and drawing cost on the main thread, microseconds (the performance check).
var last_usec: int = 0

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _waterplay: WaterplayScript = null
var _card: CardScript = CardScript.new()
var _refresh_in: float = 0.0
var _overdue_open: PackedInt32Array = PackedInt32Array()
var _ice_seen: int = -1
var _ice_um_seen: int = -1
var _water: DemoWaterScript = null
## The fishing revamp's panel state: the species shown, worked out once a refresh (SHOWN_UNKNOWN: not now), and the
## water whose Intensive press waits for its second (-1: none; decision 1713).
const SHOWN_UNKNOWN: int = -2
var _shown_cache: int = SHOWN_UNKNOWN
var _intensive_armed: int = -1


func configure(cast: DemoCastScript, command: DemoCommandScript, shared: ServicesScript, waterplay: WaterplayScript,
		water: DemoWaterScript, pantry: PantryScript, takes: TakesScript, map: WaterMapScript) -> void:
	"""Wire the fishery into this village (any of `command`, `waterplay` or `water` may be null in a check; without the
	water's fishing driver nobody fishes)."""
	name = "DemoFishery"
	_cast = cast
	_water = water
	var driver: Driver = water.fishing() if water != null else null
	_command = command
	_waterplay = waterplay
	services = shared
	fishery.configure(cast, driver, pantry, takes, shared.stores, shared.calendar, shared.weather, map)
	fishery.say = _say
	boat_rescue.configure(fishery.fleet, map, fishery.skills.can_helm)
	if waterplay != null:
		waterplay.rescue.boats = boat_rescue
		waterplay.panel.action.connect(on_action)
	_build_views(shared.props)
	_hook_command()


func _build_views(props: PropsScript) -> void:
	"""The boats and the fishery's drawing."""
	boat_view = BoatViewScript.new()
	add_child(boat_view)
	boat_view.configure(fishery.fleet, props)
	view = FisheryViewScript.new()
	add_child(view)
	view.configure(fishery, props)


func _hook_command() -> void:
	"""The fishery's "doing" words and FISH skill line in the party panel."""
	if _command == null:
		return
	_command.add_task_text(task_text)
	_command.add_skill_text(skill_text)


func task_text(who: int) -> String:
	"""What `who` does for the fishery, in words ("" when nothing)."""
	var j: int = fishery.tables.job_of_worker(who)
	return fishery.doing_text(j, fishery.tables.j_serial[j]) if j >= 0 else ""


func skill_text(who: int, _alone: bool) -> String:
	"""The party panel's fishing line."""
	return fishery.skills.line_of(who)


# --- per frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the fishery on this frame's demo time; the views follow; the panel and incidents on real time."""
	if view == null:
		return
	var started: int = Time.get_ticks_usec()
	var usec: int = _cast.clock.frame_usec if _cast != null else 0
	fishery.update(usec)
	boat_view.refresh(float(usec) / 1000000.0)
	view.refresh()
	_follow_ice()
	last_usec = Time.get_ticks_usec() - started
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		sync_incidents()
		if _waterplay != null and _waterplay.panel.is_shown():
			refresh_panel()


func _follow_ice() -> void:
	"""The pond's ice to the swimmers (nobody swims under it) and to the Water range layer (its millimetres too)."""
	if fishery.ice.revision == _ice_seen and fishery.ice.thickness_um == _ice_um_seen:
		return
	_ice_seen = fishery.ice.revision
	_ice_um_seen = fishery.ice.thickness_um
	if _waterplay != null:
		_waterplay.motion.pond_frozen = fishery.ice.frozen()
	if _water != null and _water.overlay() != null:
		_water.overlay().set_ice(fishery.ice.state(), fishery.ice.millimetres())


func _say(text: String, warning: bool) -> void:
	"""Post a line to the one notice feed, from the water."""
	services.notices.post(NoticesScript.SOURCE_WATER, NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, text)


# --- incidents -------------------------------------------------------------------------------------

func sync_incidents() -> void:
	"""OVERDUE trips and THIN ICE as incidents (see the header), raised once and resolved when over."""
	var incidents: IncidentsScript = services.incidents
	for t: int in Tables.MAX_TRIPS:
		var live: bool = fishery.tables.t_live[t] == 1
		var serial: int = fishery.tables.t_serial[t]
		if live and fishery.now_tick() > fishery.tables.t_due[t] and not _overdue_open.has(serial):
			_overdue_open.append(serial)
			incidents.raise(OVERDUE_KEY % serial, NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_WARNING,
				"%s is overdue: %s" % [fishery.trip_name(t), _trip_state_words(t)], _trip_target_kind(t), _trip_target(t))
	for k: int in range(_overdue_open.size() - 1, -1, -1):
		if _trip_of_serial(_overdue_open[k]) < 0:
			incidents.resolve(OVERDUE_KEY % _overdue_open[k])
			_overdue_open.remove_at(k)
	_sync_thin_ice(incidents)


func _sync_thin_ice(incidents: IncidentsScript) -> void:
	"""THIN ICE while the pond is frozen but not safe."""
	if fishery.ice.state() == IceScript.STATE_THIN:
		if not incidents.update(THIN_ICE_KEY, IncidentsScript.STATE_NEEDS_DECISION, fishery.ice.line()):
			incidents.raise(THIN_ICE_KEY, NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_WARNING, fishery.ice.line())
	else:
		incidents.resolve(THIN_ICE_KEY)


func _trip_of_serial(serial: int) -> int:
	"""The live trip with `serial` (-1: over)."""
	for t: int in Tables.MAX_TRIPS:
		if fishery.tables.t_live[t] == 1 and fishery.tables.t_serial[t] == serial:
			return t
	return -1


func _trip_target_kind(t: int) -> int:
	"""Go to: the trip's first crew member, when it has one."""
	return NoticesScript.TARGET_RESIDENT if _trip_target(t) >= 0 else NoticesScript.TARGET_NONE


func _trip_target(t: int) -> int:
	"""The trip's first crew member (-1: none on it)."""
	for seat: int in 2:
		var j: int = fishery.tables.t_seat_job[t * 2 + seat]
		if j >= 0 and fishery.tables.j_live[j] == 1 and fishery.tables.j_worker[j] >= 0:
			return fishery.tables.j_worker[j]
	return -1


func _trip_state_words(t: int) -> String:
	"""A trip's state, and why it waits when it does."""
	var words: String = Tables.TRIP_WORDS[fishery.tables.t_state[t]]
	if not fishery.tables.t_words[t].is_empty():
		words += " — waits: %s" % fishery.tables.t_words[t]
	return words


# --- the orders ------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Water panel button of the fishery's (others are the water's own)."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	_refresh_in = 0.0
	if _on_choice(action_name) or _on_reserve(action_name):
		return
	match action_name:
		PanelScript.ACTION_AUTHORISE:
			_answer(authorise_words(fishery.authorise(choice_method, choice_site, choice_species, members)))
		PanelScript.ACTION_NEXT_TRIP:
			step_trip()
		PanelScript.ACTION_CANCEL_TRIP:
			_answer(_cancel_words())
		PanelScript.ACTION_MAKE_NET, PanelScript.ACTION_MAKE_TRAP, PanelScript.ACTION_MAKE_ICE_KIT:
			var kind: int = MAKE_ACTIONS.find(action_name)
			_answer(_ordered(fishery.order_make(kind, members), "Make a %s: on the work board" % LockerScript.KIND_NAMES[kind]))
		PanelScript.ACTION_MEND:
			_answer(_ordered(fishery.order_mend(fishery.worst_to_mend(), members), "Mend: on the work board"))
		PanelScript.ACTION_MILL:
			_answer(_ordered(fishery.order_mill(members), "Mill grain: on the work board"))
		_:
			if not ACTION_RECIPES.has(action_name):
				return
			var recipe: int = ACTION_RECIPES[action_name]
			_answer(batch_answer(recipe, members))


func _on_choice(action_name: StringName) -> bool:
	"""The trip's choices and the stewardship row (decisions 1712-1713): site, method, fish or Best catch, the traps'
	policy, intensive harvest. False for any other action."""
	match action_name:
		PanelScript.ACTION_FISH_SITE:
			step_site()
		PanelScript.ACTION_FISH_METHOD:
			step_method()
		PanelScript.ACTION_FISH_SPECIES:
			choice_species = (choice_species + 1) % PlanScript.PLAN_CHOICES
		PanelScript.ACTION_FISH_COLLECT:
			fishery.collect_policy = (fishery.collect_policy + 1) % PlanScript.COLLECT_COUNT
		PanelScript.ACTION_FISH_INTENSIVE:
			_answer(toggle_intensive())
		_:
			return false
	return true


func step_site() -> void:
	"""The next site where the chosen method is used (the method changes to one used there when it is not); Best catch
	stays chosen, a chosen fish goes back to the water's first."""
	choice_site = (choice_site + 1) % Driver.SITE_COUNT
	if not Rules.offers_site(choice_method, choice_site):
		choice_method = Rules.METHOD_NET
	if not PlanScript.is_auto(choice_species):
		choice_species = 0
	_intensive_armed = -1


func step_method() -> void:
	"""The next method used at the chosen site."""
	for n: int in Rules.METHOD_COUNT:
		choice_method = (choice_method + 1) % Rules.METHOD_COUNT
		if Rules.offers_site(choice_method, choice_site):
			return


func step_trip() -> void:
	"""The next live trip after the chosen one (-1 when there is none)."""
	for n: int in Tables.MAX_TRIPS:
		chosen_trip = (chosen_trip + 1) % Tables.MAX_TRIPS
		if fishery.tables.t_live[chosen_trip] == 1:
			return
	chosen_trip = -1


func _chosen_live_trip() -> int:
	"""The chosen trip if it is still out, else the first one out (-1: none)."""
	if chosen_trip >= 0 and fishery.tables.t_live[chosen_trip] == 1:
		return chosen_trip
	chosen_trip = fishery.tables.t_live.find(1)
	return chosen_trip


func _cancel_words() -> String:
	"""Cancel trip's answer."""
	var t: int = _chosen_live_trip()
	if t < 0:
		return "No trip is out"
	var trip: String = fishery.trip_name(t)
	var why: String = fishery.cancel_trip(t)
	return "%s: called off" % trip if why.is_empty() else "%s: can't call it off — %s" % [trip, why]


func authorise_words(why: String) -> String:
	"""Authorise's answer."""
	if not why.is_empty():
		return "Can't authorise: %s" % why
	return "%s: authorised — on the work board" % Text.method_title(choice_method, choice_site, _species_key())


func batch_answer(recipe: int, members: PackedInt32Array) -> String:
	"""A preserve's or a drink's order and its answer: done (with the drinks' stock warning when it applies, decision
	1734 -- read before the order, which may change nothing of the stock), or why not."""
	var warning: String = fishery.drink_stock_warning(recipe)
	var done: String = "%s: on the work board" % Recipes.VERB[recipe]
	return _ordered(fishery.order_batch(recipe, members), done if warning.is_empty() else "%s — %s" % [done, warning])


func _ordered(why: String, done: String) -> String:
	"""An order's answer: done, or why not."""
	return done if why.is_empty() else "Can't: %s" % why


func _answer(said: String) -> void:
	"""An order's answer: beside the selection, and the Water panel comes forward (the water's own request: the
	fishery's sections are in its panel)."""
	if _command != null and _command.panel() != null:
		_command.say(said)
	if _waterplay != null:
		_waterplay.panel_wanted.emit()


func _species_key() -> StringName:
	"""The chosen fish's key -- BEST CATCH's pick now (&"fish" without a fishery or a pick)."""
	var shown: int = _shown_species()
	return fishery.driver.species_key_of(choice_site, shown) if fishery.driver != null and shown >= 0 else &"fish"


func _shown_species() -> int:
	"""The species index the preview shows: the chosen fish, or BEST CATCH's pick now (-1: none) -- worked out once
	per panel refresh (`_shown_cache`)."""
	if fishery.driver == null:
		return -1
	if _shown_cache != SHOWN_UNKNOWN:
		return _shown_cache
	return fishery.planned_species(choice_method, choice_site, choice_species, PackedInt32Array())


func toggle_intensive() -> String:
	"""Intensive harvest for the chosen water (REQ-SET-049: the floor and the predicted recovery shown before it is
	accepted): turning it on takes two presses, the first saying the figures; turning it off one. The answer."""
	if fishery.driver == null:
		return "The fishery is not running"
	var water: String = StewardScript.WATER_NAMES[StewardScript.water_of_site(choice_site)]
	if fishery.driver.intensive(choice_site):
		fishery.driver.set_intensive(choice_site, false)
		return "%s: intensive harvest off — the 30%% floor again" % water
	if _intensive_armed != choice_site:
		_intensive_armed = choice_site
		return "%s: %s. Press Intensive again to accept" % [water,
			". ".join(fishery.steward.intensive_lines(fishery.driver, choice_site))]
	_intensive_armed = -1
	fishery.driver.set_intensive(choice_site, true)
	return "%s: intensive harvest ON — down to the 10%% floor" % water


func intensive_card() -> CardScript:
	"""Intensive's card (REQ-SET-049): the 10% floor and each species' predicted recovery from it, before accepting."""
	var water: String = StewardScript.WATER_NAMES[StewardScript.water_of_site(choice_site)]
	var on: bool = fishery.driver != null and fishery.driver.intensive(choice_site)
	_card.reset("%s: intensive harvest %s" % [water, "off" if on else "on"])
	if fishery.driver == null:
		_card.refuse("NO_FISHERY", "the fishery did not start", "")
		return _card
	_card.result = "; ".join(fishery.steward.intensive_lines(fishery.driver, choice_site)) if not on \
		else "Back to the 30% floor; species already below it stay closed until they recover above 40%"
	return _card


# --- the ration reserve (decision 1742) ----------------------------------------------------------------

## THE RESERVE'S CONTROLS (Brendan's R5, 2026-10-08), in the Preserves section beside Pack rations: the line says
## what the reserve keeps and holds; Keep fewer / Keep more step its target (UI-SET-099, a batch a press, up to
## RationReserve's TARGET_CAP_MILLI); Release food reserves is the GDD's 5.10 emergency action -- never taken by
## itself, its card saying what it frees before it is pressed -- and, pressed again, keeps them again.
const RESERVE_NONE: String = "Ration reserve: none. Keep more ▶ holds one batch's food (flour or grain, dried " \
	+ "fish, nuts) back from the kitchen and the hungry until it is packed"
const RELEASE_CAPTION: String = "Release food reserves"
const KEEP_AGAIN_CAPTION: String = "Keep food reserves again"
const RELEASED_NOTHING: String = "Food reserves released: nothing was held; nothing will be held back until you keep " \
	+ "them again"
const RELEASE_NOTHING_NOW: String = "Nothing is held now; nothing will be held back until you keep them again"
const KEEP_AGAIN_RESERVE: String = "One batch of rations' food held back again from the kitchen and the hungry while " \
	+ "rations are short"
const KEEP_AGAIN_KEEP: String = "No reserve is kept; the dried fish a batch of rations needs is kept from raw eating " \
	+ "again while it waits on that alone (1740)"


func _on_reserve(action_name: StringName) -> bool:
	"""The reserve's row: the target stepped, or §5.10's release. False for any other action."""
	match action_name:
		PanelScript.ACTION_RESERVE_FEWER:
			_answer(step_reserve(-1))
		PanelScript.ACTION_RESERVE_MORE:
			_answer(step_reserve(1))
		PanelScript.ACTION_RESERVE_RELEASE:
			_answer(toggle_release())
		_:
			return false
	return true


func step_reserve(steps: int) -> String:
	"""UI-SET-099's stepper: the target moved by `steps` batches (3 U each), within its range. The answer -- saying,
	while released, that nothing is held until the reserves are kept again (the review of 72817b34)."""
	@warning_ignore("integer_division")
	var most: int = RationReserveScript.TARGET_CAP_MILLI / RationReserveScript.TARGET_STEP_MILLI
	var target: int = fishery.set_ration_reserve_target(fishery.ration_reserve.target_milli
		+ clampi(steps, -most, most) * RationReserveScript.TARGET_STEP_MILLI)
	var said: String = "Ration reserve: none — nothing is held back for rations" if target == 0 \
		else "Ration reserve: keep %s of rations" % Text.units(target)
	return "%s (released: nothing is held until you keep them again)" % said if fishery.ration_reserve.released \
		else said


func toggle_release() -> String:
	"""The GDD's 5.10 emergency action (never taken by itself): free what the reserve and 1740's keep withhold -- its
	card said what -- or, released, keep the reserves again. The answer."""
	if fishery.ration_reserve.released:
		fishery.release_ration_reserve(false)
		var held: String = held_words()
		return "Food reserves kept again: holding %s" % (held if not held.is_empty() else "nothing yet")
	var freed: String = held_words()
	fishery.release_ration_reserve(true)
	if freed.is_empty():
		return RELEASED_NOTHING
	return "Food reserves released: %s free for the kitchen and the hungry" % freed


func held_words() -> String:
	"""What is withheld from the kitchen and the hungry, in words: what the reserve holds ("1.0 U dried fish, 1.0 U nuts,
	2.0 U flour") and the dried fish 1740's keep keeps from raw eating ("1.0 U dried fish kept from raw eating"); ""
	when nothing."""
	var parts := PackedStringArray()
	for category: int in RationReserveScript.HELD:
		var milli: int = fishery.ration_reserve.held_milli(category)
		if milli > 0:
			parts.append("%s %s" % [Text.units(milli), Recipes.category_words(category)])
	var kept: int = mini(fishery.ration_keep_milli(Catalog.CAT_DRIED_FISH),
		fishery.takes.free_milli_of_crop(fishery.pantry, Catalog.CAT_DRIED_FISH)) if fishery.takes != null else 0
	if kept > 0:
		parts.append("%s dried fish kept from raw eating" % Text.units(kept))
	return ", ".join(parts)


func reserve_text() -> String:
	"""The reserve's line, two lines: what it keeps and what the village owns; then released, what it holds, or nothing."""
	var reserve: RationReserveScript = fishery.ration_reserve
	var head: String = RESERVE_NONE if reserve.target_milli == 0 else "Ration reserve: keep %s (%s owned)" \
		% [Text.units(reserve.target_milli), Text.units(fishery.rations_owned_milli())]
	if reserve.released:
		return "%s\nReleased: nothing held until kept again" % head
	var held: String = held_words()
	if reserve.target_milli == 0 and held.is_empty():
		return head
	return "%s\nHolding %s" % [head, held] if not held.is_empty() else "%s\nHolding nothing now" % head


func release_card() -> CardScript:
	"""Release food reserves' card: what it frees, or that nothing is held now and nothing will be until they are kept
	again -- refused only with no reserve and no dried fish kept (the review of 72817b34); released, keeping them
	again."""
	if fishery.ration_reserve.released:
		_card.reset(KEEP_AGAIN_CAPTION)
		_card.result = KEEP_AGAIN_RESERVE if fishery.ration_reserve.target_milli > 0 else KEEP_AGAIN_KEEP
		return _card
	_card.reset("%s (an emergency action)" % RELEASE_CAPTION)
	var held: String = held_words()
	if fishery.ration_reserve.target_milli == 0 and held.is_empty():
		_card.refuse("NO_RESERVE", "no reserve is kept and no food is held back", "Keep more ▶ sets a reserve")
		return _card
	_card.result = RELEASE_NOTHING_NOW if held.is_empty() else ("Frees %s at once, for the kitchen and the hungry; "
		+ "nothing is held back until you keep them again") % held
	return _card


func _dress_reserve(panel: PanelScript) -> void:
	"""The reserve's row: the stepper's ends, and Release's caption and card."""
	var target: int = fishery.ration_reserve.target_milli
	panel.button(PanelScript.ACTION_RESERVE_FEWER).disabled = target <= 0
	panel.button(PanelScript.ACTION_RESERVE_MORE).disabled = target >= RationReserveScript.TARGET_CAP_MILLI
	var card: CardScript = release_card()
	panel.set_card(PanelScript.ACTION_RESERVE_RELEASE, card.text(), card.is_ok())
	panel.button(PanelScript.ACTION_RESERVE_RELEASE).text = KEEP_AGAIN_CAPTION if fishery.ration_reserve.released \
		else RELEASE_CAPTION


# --- the panel ---------------------------------------------------------------------------------------

func refresh_panel() -> void:
	"""Fill the Fishing, Boats and rack-and-mill sections and set every button's card (only while shown)."""
	var panel: PanelScript = _waterplay.panel
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	_shown_cache = _shown_species()
	panel.show_fishery(panel_lines())
	var card: CardScript = trip_card(members)
	panel.set_card(PanelScript.ACTION_AUTHORISE, card.text(), card.is_ok())
	card = cancel_card()
	panel.set_card(PanelScript.ACTION_CANCEL_TRIP, card.text(), card.is_ok())
	for kind: int in MAKE_ACTIONS.size():
		card = make_card(kind, members)
		panel.set_card(MAKE_ACTIONS[kind], card.text(), card.is_ok())
	card = mend_card(members)
	panel.set_card(PanelScript.ACTION_MEND, card.text(), card.is_ok())
	_dress_steward(panel)
	_dress_reserve(panel)
	card = mill_card(members)
	panel.set_card(PanelScript.ACTION_MILL, card.text(), card.is_ok())
	for action: StringName in ACTION_RECIPES:
		card = dry_card(members) if action == PanelScript.ACTION_DRY else batch_card(ACTION_RECIPES[action], members)
		panel.set_card(action, card.text(), card.is_ok())
	_shown_cache = SHOWN_UNKNOWN


func _dress_steward(panel: PanelScript) -> void:
	"""The stewardship row: Intensive's card, and the captions of the traps' policy and the chosen water's intensive
	state."""
	var card: CardScript = intensive_card()
	panel.set_card(PanelScript.ACTION_FISH_INTENSIVE, card.text(), card.is_ok())
	panel.button(PanelScript.ACTION_FISH_COLLECT).text = "Traps: %s" % PlanScript.COLLECT_WORDS[fishery.collect_policy]
	var on: bool = fishery.driver != null and fishery.driver.intensive(choice_site)
	panel.button(PanelScript.ACTION_FISH_INTENSIVE).text = "Intensive: %s" % ("on" if on else
		("press to accept" if _intensive_armed == choice_site else "off"))


func panel_lines() -> Dictionary:
	"""The sections' text (water_panel.gd FISHERY_LINES)."""
	return {&"fish_choice": choice_line(), &"fish_preview": preview_text(), &"fish_trips": trips_text(),
		&"fish_gear": gear_text(), &"boats": boats_text(), &"stations": stations_text(), &"preserves": preserves_text(),
		&"reserve": reserve_text(), &"brewing": brewing_text(), &"fish_record": record_text()}


func record_text() -> String:
	"""Each water's stewardship record (fishery_stewardship.gd; review ECO-025)."""
	if fishery.driver == null:
		return ""
	var lines := PackedStringArray()
	for water: int in StewardScript.WATER_COUNT:
		lines.append(fishery.steward.record_line(fishery.driver, water, Callable(Text, &"units")))
	return "\n".join(lines)


func choice_line() -> String:
	"""'The pond · Boat · perch — on the pond: the biggest planned catch, rowed by a crew of two' (Best catch: 'best
	catch (perch now)')."""
	var fish: String = Text.species_label(_species_key())
	if PlanScript.is_auto(choice_species):
		fish = "best catch (%s now)" % fish if _shown_species() >= 0 else "best catch (nothing now)"
	return "%s · %s · %s — %s" % [Rules.SITE_NAMES[choice_site].capitalize(), Rules.METHOD_NAMES[choice_method],
		fish, Rules.METHOD_ROLES[choice_method]]


func preview_text() -> String:
	"""REQ-SET-055 before authorising: the stock and quota, the closure, the expected catch, the gear, the risk."""
	var level: int = fishery.skills.level_of(_likely_crew())
	var shown: int = _shown_species()
	if fishery.driver != null and shown < 0:
		return "Best catch: no fish there may be fished now (closed, out of season, restocking or the quota)"
	var p: Driver.Preview = fishery.preview_of(choice_method, choice_site, shown, level)
	if p == null:
		return "The fishery is not running"
	var lines := PackedStringArray([Text.stock_line(p)])
	var closure: String = Text.closure_line(p)
	if not closure.is_empty():
		lines.append(closure)
	lines.append("Expected catch: %s a cycle (base %s; fishing %d)" % [Text.units(p.expected_catch_milli),
		Text.units(p.base_catch_milli), level])
	lines.append(_gear_condition())
	lines.append("Risk of injury: %s" % Text.risk_text(p.injury_per_10000))
	lines.append("Rare catch: %d in 10000 a cycle makes a quarter of it excellent" % RollsScript.rare_chance(level))
	return "\n".join(lines)


func _likely_crew() -> int:
	"""The resident the preview reckons with: the most skilled fisher (the board offers the job to whoever is free)."""
	var best: int = 0
	for who: int in _cast.actor_count():
		if fishery.skills.level_of(who) > fishery.skills.level_of(best):
			best = who
	return best


func _gear_condition() -> String:
	"""REQ-SET-055's gear condition for the chosen method: its best free piece, or the free boat's hull."""
	if choice_method == Rules.METHOD_BOAT:
		for boat: int in Routes.FISHING_BOATS:
			if fishery.fleet.is_free(boat):
				@warning_ignore("integer_division") return "Boat: Rowboat %d %d/1000 (%d trips left)" % [boat + 1, fishery.fleet.durability[boat],
					fishery.fleet.durability[boat] / FleetScript.WEAR_PER_CYCLE]
		return "Boat: both are out"
	var kind: int = FisheryScript.GEAR_OF_METHOD[choice_method]
	var read := IntMath.IntResult.new()
	if not fishery.locker.pick_into(kind, read):
		return "Gear: no free %s that holds a cycle" % LockerScript.KIND_NAMES[kind]
	return Text.gear_line(LockerScript.KIND_NAMES[kind], fishery.locker.durability_of(read.value), fishery.locker.cycles_left(read.value))


func trips_text() -> String:
	"""Every trip out, the chosen one marked: 'The pond boat trip (perch): fishing — Otter fisher, Otter boatwright'."""
	var lines := PackedStringArray()
	var chosen: int = _chosen_live_trip()
	for t: int in Tables.MAX_TRIPS:
		if fishery.tables.t_live[t] == 0:
			continue
		lines.append("%s%s: %s%s" % ["▸ " if t == chosen else "", fishery.trip_name(t), _trip_state_words(t), _crew_words(t)])
	if lines.is_empty():
		return "No trips out. Caught so far: %s; landed in the stores: %s" % [Text.units(fishery.caught_milli),
			Text.units(fishery.landed_milli)]
	lines.append("Caught so far: %s; landed: %s; excellent: %s" % [Text.units(fishery.caught_milli),
		Text.units(fishery.landed_milli), Text.units(fishery.rolls.excellent_milli)])
	return "\n".join(lines)


func _crew_words(t: int) -> String:
	"""' — Otter fisher, Otter boatwright' (' — waiting for a crew' with nobody on it yet)."""
	var names := PackedStringArray()
	for seat: int in 2:
		var j: int = fishery.tables.t_seat_job[t * 2 + seat]
		if j >= 0 and fishery.tables.j_live[j] == 1 and fishery.tables.j_worker[j] >= 0:
			names.append(fishery.name_of(fishery.tables.j_worker[j]))
	return " — %s" % ", ".join(names) if not names.is_empty() else (" — waiting for a crew" if fishery.tables.t_state[t] == Tables.TRIP_QUEUED else "")


func gear_text() -> String:
	"""The locker: each piece's wear (cycles left), and its rope and iron."""
	var locker: LockerScript = fishery.locker
	if not locker.ok:
		return "Gear locker: did not open"
	var parts := PackedStringArray()
	for k: int in locker.count():
		var kind: int = locker.kind_of(k)
		var out: String = " (out)" if not locker.is_free(k) else ""
		if kind == LockerScript.KIND_OUTFIT:
			parts.append("%s%s" % [LockerScript.KIND_NAMES[kind], out])
		else:
			parts.append("%s %d/1000, %d left%s" % [LockerScript.KIND_NAMES[kind], locker.durability_of(k), locker.cycles_left(k), out])
	return "Gear locker: %s. Rope %s, iron %s" % ["; ".join(parts), Text.units(locker.material_milli(LockerScript.MAT_ROPE)),
		Text.units(locker.material_milli(LockerScript.MAT_IRON))]


func boats_text() -> String:
	"""Each boat (where, its wear, its crew), the jetty, and the pond's ice."""
	var lines := PackedStringArray()
	for boat: int in fishery.fleet.count:
		var crew := PackedStringArray()
		for seat: int in FleetScript.SEATS:
			if fishery.fleet.crew_of(boat, seat) >= 0:
				crew.append(fishery.name_of(fishery.fleet.crew_of(boat, seat)))
		lines.append(fishery.fleet.line_of(boat) + (" — " + ", ".join(crew) if not crew.is_empty() else ""))
	lines.append("Kept at the boathouse, launched from %s (west bank)" % Routes.JETTY_NAME)
	lines.append(fishery.ice.line())
	return "\n".join(lines)


func stations_text() -> String:
	"""The rack's slots, the mill, and the pantry's fish, dried fish and flour."""
	var states := PackedInt32Array([0, 0, 0, 0, 0])
	for slot: int in Rules.RACK_SLOTS:
		states[fishery.tables.s_state[slot]] += 1
	var rack: String = "Rack (smoked and dried): %d curing, %d cured, %d loading, %d empty" % [states[Tables.SLOT_CURING],
		states[Tables.SLOT_READY] + states[Tables.SLOT_TAKING], states[Tables.SLOT_LOADING], states[Tables.SLOT_EMPTY]]
	var mill: String = "Mill: %s" % ("grinding" if fishery.grinding() else "idle")
	return "%s\n%s\nIn the pantry: fresh fish %s · dried fish %s · flour %s" % [rack, mill, Text.units(_fresh_fish()),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_DRIED_FISH)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_FLOUR))]


func preserves_text() -> String:
	"""The preserves (decisions 1611, 1625): what the rack's slots dry, the preserving table and its crocks, and the
	pantry's fruit, dried fruit, rations, jam, cheese, vinegar and pickles."""
	var fruit: int = 0
	for slot: int in Rules.RACK_SLOTS:
		var drying: bool = fishery.tables.s_state[slot] != Tables.SLOT_EMPTY
		fruit += 1 if drying and fishery.tables.s_recipe[slot] == Recipes.R_DRY_FRUIT else 0
	return "Fruit drying on the rack: %d slot%s · the preserving table: %s · crocks in use: %d\nIn the pantry: fruit %s · dried fruit %s · rations %s · jam %s · cheese %s · vinegar %s · pickles %s" % [
		fruit, "" if fruit == 1 else "s", "in use" if fishery.packing() else "free",
		fishery.slots_in_use(Recipes.STATION_TABLE),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_APPLE) + fishery.pantry.milli_of(Catalog.ITEM_PEAR)),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_DRIED_FRUIT)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_RATION)),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_JAM)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_CHEESE)),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_VINEGAR)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_PICKLES))]


func brewing_text() -> String:
	"""The brewery (decisions 1621, 1625): its vats (vinegar sours in one too), and the pantry's honey and its drinks."""
	return "Brewery: %d of %d vats in use\nIn the pantry: honey %s · mead %s · cordial %s · ale %s · cider %s" % [
		fishery.brewing(), Recipes.VAT_SLOTS, Text.units(fishery.pantry.milli_of(Catalog.ITEM_HONEY)),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_MEAD)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_CORDIAL)),
		Text.units(fishery.pantry.milli_of(Catalog.ITEM_ALE)), Text.units(fishery.pantry.milli_of(Catalog.ITEM_CIDER))]


func _fresh_fish() -> int:
	"""Every fresh fish species in the pantry, milli-U."""
	var total: int = 0
	for k: int in Catalog.CATCH_COUNT:
		total += fishery.pantry.milli_of(Catalog.FIRST_CATCH + k)
	return total


# --- the cards (decision 0332: each from its order's own decision) -------------------------------------

func trip_card(members: PackedInt32Array) -> CardScript:
	"""Authorise trip's card: `fishery.trip_refusal`, REQ-SET-055's figures, the work, who and what it stops."""
	_card.reset(Text.method_title(choice_method, choice_site, _species_key()))
	var why: String = fishery.trip_refusal(choice_method, choice_site, choice_species, members)
	_card.prerequisites.append(_needs_words())
	var preview: String = preview_text()
	_card.result = preview.replace("\n", "; ")
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	var level: int = fishery.skills.level_of(_likely_crew())
	_card.work_usec = CalendarScript.usec_for_ticks(fishery.estimate_ticks(choice_method) - SimClock.TICKS_PER_HOUR) \
		if level >= 0 else CardScript.NO_WORK
	_who_for(members, func(who: int) -> bool: return fishery.seat_eligibility(choice_method, 0, who, true).is_empty(),
		"a fisher" if choice_method != Rules.METHOD_BOAT else "a crew of two (the helm: fishing 1)")
	return _card


func _needs_words() -> String:
	"""What the chosen method needs (the card's Needs line)."""
	match choice_method:
		Rules.METHOD_BOAT:
			return "a free boat that holds a cycle's wear, a helm with fishing 1 and a second crew, open water, no storm"
		Rules.METHOD_ICE:
			return "safe ice (60 mm), a free ice kit and a winter outfit"
		Rules.METHOD_TRAP:
			return "a free trap; it soaks 6 h, then someone collects it"
	return "a free hand net that holds a cycle's wear"


func _who_for(members: PackedInt32Array, can: Callable, crew_words: String) -> void:
	"""The card's Who: the first selected resident who may go, else the work board's queue; and what it stops."""
	var going: int = -1
	var able: int = 0
	for who: int in members:
		if bool(can.call(who)):
			able += 1
			if going < 0:
				going = who
	if going >= 0:
		_card.worker = going
		_card.who = CardScript.assign_selected(fishery.name_of(going), able, members.size())
		if _command != null:
			_card.interrupts = _command.interrupt_text(going)
		return
	_card.who = "Queue on the work board (J) for %s: whoever is free and may go" % crew_words


func cancel_card() -> CardScript:
	"""Cancel trip's card: `fishery.cancel_trip`'s refusal, read without calling the trip off."""
	_card.reset("Call a trip off")
	var t: int = _chosen_live_trip()
	if t < 0:
		_card.refuse("NO_TRIP", "no trip is out", "Authorise trip")
		return _card
	_card.result = "%s ends: its fishing place, its gear and the room held for its catch are released at once; " % fishery.trip_name(t) \
		+ "a boat rows home first"
	if fishery.tables.t_state[t] == Tables.TRIP_LANDING:
		_card.refuse("LANDING", "the catch is out of the water — it is landed first", "")
	elif fishery.tables.t_called_off[t] == 1:
		_card.refuse("COMING_BACK", "it is coming back already", "")
	return _card


func make_card(kind: int, members: PackedInt32Array) -> CardScript:
	"""A Make button's card: `fishery.make_refusal`, its costs (the stores' wood, the locker's rope or iron)."""
	_card.reset("Make a %s at the workbench" % LockerScript.KIND_NAMES[kind])
	var why: String = fishery.make_refusal(kind)
	_card.add_cost("Wood", fishery.stores.wood_milli_u, LockerScript.MAKE_WOOD_MILLI[kind])
	var mat: int = LockerScript.MAKE_MATERIAL[kind]
	_card.add_cost(LockerScript.MAT_NAMES[mat].capitalize(), fishery.locker.material_milli(mat), LockerScript.MAKE_MATERIAL_MILLI[kind])
	_card.result = "A new %s in the gear locker (1000/1000)" % LockerScript.KIND_NAMES[kind]
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	_card.work_usec = Rules.work_usec(LockerScript.MAKE_MWU[kind], 0)
	_who_for(members, func(who: int) -> bool: return fishery.tables.job_of_worker(who) < 0, "anyone")
	return _card


func mend_card(members: PackedInt32Array) -> CardScript:
	"""Mend gear's card: the most worn free gear or boat, `fishery.mend_refusal`, wood 1 + rope 0.25."""
	var target: int = fishery.worst_to_mend()
	_card.reset("Mend %s" % _mend_name(target))
	var why: String = fishery.mend_refusal(target)
	_card.add_cost("Wood", fishery.stores.wood_milli_u, LockerScript.MEND_WOOD_MILLI)
	_card.add_cost("Rope", fishery.locker.material_milli(LockerScript.MAT_ROPE), LockerScript.MEND_ROPE_MILLI)
	_card.result = "+%d durability (to at most 1000)" % LockerScript.MEND_POINTS
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	_card.work_usec = Rules.work_usec(LockerScript.MEND_MWU, 0)
	_who_for(members, func(who: int) -> bool: return fishery.tables.job_of_worker(who) < 0, "anyone")
	return _card


func _mend_name(target: int) -> String:
	"""What Mend would mend, in words."""
	if target < 0:
		return "gear"
	if target >= FisheryScript.BOAT_SLOT:
		return "Rowboat %d (%d/1000)" % [target - FisheryScript.BOAT_SLOT + 1, fishery.fleet.durability[target - FisheryScript.BOAT_SLOT]]
	return "the %s (%d/1000)" % [LockerScript.KIND_NAMES[fishery.locker.kind_of(target)], fishery.locker.durability_of(target)]


func dry_card(members: PackedInt32Array) -> CardScript:
	"""Dry fish's card: `fishery.dry_refusal`, §5.7's dry_fish (fish 4 -> dried fish 3, 24 WU + 12 h)."""
	_card.reset("Dry fish on the smoking rack")
	var why: String = fishery.dry_refusal()
	_card.add_cost("Fresh fish", fishery.input_available_milli(Recipes.IN_FIRST[Recipes.R_DRY_FISH]), Rules.DRY_IN_MILLI)
	_card.result = "%s of dried fish (keeps 720 h; eaten as it is) after 12 game hours on the rack" % Text.units(Rules.DRY_OUT_MILLI)
	_card.prerequisites.append("a free rack slot (4); the fish that spoils first is taken")
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	_card.work_usec = Rules.work_usec(Rules.DRY_WORK_MWU, 0)
	_card.work_note = " to hang it, then 12 h curing, plus the walks"
	_who_for(members, func(who: int) -> bool: return fishery.tables.job_of_worker(who) < 0, "anyone")
	return _card


func batch_card(recipe: int, members: PackedInt32Array) -> CardScript:
	"""A preserve's card (decision 1611): `fishery.batch_refusal`, its §5.7 row's inputs, output, work and wait."""
	var item: int = Recipes.OUT_ITEM[recipe]
	_card.reset("%s at %s" % [Recipes.VERB[recipe], Recipes.STATION_NAMES[Recipes.STATION[recipe]]])
	var why: String = fishery.batch_refusal(recipe)
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		_card.add_cost(Recipes.cap(Recipes.category_words(Recipes.IN_CATEGORY[input])), fishery.input_available_milli(input),
			Recipes.IN_MILLI[input])
	if Recipes.WATER_MILLI[recipe] > 0:
		_card.add_cost("Water", maxi(0, fishery.stores.water_milli_u - fishery.water_held_milli()) if fishery.stores != null \
			else 0, Recipes.WATER_MILLI[recipe])
	_card.result = "%s of %s (keeps %d h; %s)%s" % [Text.units(Recipes.OUT_MILLI[recipe]),
		Catalog.ITEM_LABELS[item].to_lower(), Catalog.shelf_hours_of(item),
		PreserveText.card_use(recipe), " after %d game hours at %s" % [Recipes.PASSIVE_HOURS[recipe],
		Recipes.STATION_NAMES[Recipes.STATION[recipe]]] if Recipes.is_passive(recipe) else ""]
	var warning: String = fishery.drink_stock_warning(recipe)
	if not warning.is_empty():
		_card.result += ". Note: " + warning
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	_card.work_usec = Rules.work_usec(Recipes.WORK_MWU[recipe], 0)
	_card.work_note = ", plus the walks"
	_who_for(members, func(who: int) -> bool: return fishery.tables.job_of_worker(who) < 0, "anyone")
	return _card


func mill_card(members: PackedInt32Array) -> CardScript:
	"""Mill grain's card: `fishery.mill_refusal`, §5.7's flour (grain 3 -> flour 3, 12 WU)."""
	_card.reset("Mill grain at the watermill")
	var why: String = fishery.mill_refusal()
	_card.add_cost("Grain", fishery.grain_available_milli(), Rules.MILL_IN_MILLI)
	_card.result = "%s of flour in the pantry (keeps 240 h). No dish here uses it yet: it is kept for later" % Text.units(Rules.MILL_OUT_MILLI)
	if not why.is_empty():
		_card.refuse(fishery.refused_code, why, fishery.refused_fix)
		return _card
	_card.work_usec = Rules.work_usec(Rules.MILL_WORK_MWU, 0)
	_card.work_note = ", plus the walk to the mill over the stream"
	_who_for(members, func(who: int) -> bool: return fishery.tables.job_of_worker(who) < 0, "anyone")
	return _card
