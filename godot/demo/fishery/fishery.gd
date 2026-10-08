extends RefCounted
## WATER PART B: fishing trips that feed the pantry, the gear they use, the boats, ice fishing, the drying rack and the
## mill -- one owner of the village's fishery work. Decision 0431 (live demo; numbers in fishery_rules.gd, decisions
## 0431-0436). Presentation over integer rules; nothing here writes into the settlement simulation.
##
## THE FISHERY IS REAL. A trip fishes through `demo/water/fishing_driver.gd`, which runs `scripts/core/fishing.gd`:
## the stock, the quota, the closures, the restocking latch, the effort slots and the catch formula are the store's.
## A cycle opens (`begin_cycle`: the gear's whole effort requirement, owned by an Expedition and a FISH Job) only when
## the fisher stands at the water, after a recheck; it completes (`complete_cycle`: the store's catch, limited to the
## quota and the floor, debited from the stock) when the work is done; a trip called off before then cancels it
## (`cancel_cycle`: the slots back, nothing taken). The gear's durability claim belongs to the cycle's Job
## (gear_locker.gd, the real gear.gd); the boat's wear is the boat row's (boat_fleet.gd).
##
## THE CATCH FEEDS THE PANTRY. The species is the item (farm_catalog.gd: trout, dace, salmon, perch, carp, whitefish
## -- never a generic "fish"; the coast's three are never caught here, eel and pike never at all). Room is held in a
## store for the expected catch before the cycle opens (decision 0222: a producer reserves first); the catch is carried
## by its fisher and stored only when it is put down at the store (decision 0361); one called away sets it down at the
## landing for the next fisher (REQ-SET-054: "retain cargo there"). The books: everything ever caught is in a store or
## in a hand (`caught_milli == landed_milli + catch_in_hand_milli()`, test_demo_fishery.gd).
##
## WHO. Every job is a work-board task (work/fishery_work.gd, decision 0411): the board hands a waiting job to an idle
## resident who may do it -- skills and fit, never a species lock (LORE-P12); a boat's helm needs FISH >= 1. A trip
## authorised with residents selected is given to them first. A resident doing a job is driven by a thin task
## (fishery_task.gd), so the night, a meal call or an order takes it off cleanly: the job goes back on the board.
##
## THE JETTY RECHECK (decision 0231's bank recheck, at the jetty). What was true when a boat trip was authorised may
## not be when the crew stands at the jetty: a storm come up (REQ-SET-052: "If a boat faces a storm or an unstaffed
## required crew slot, then the system shall prevent departure and preserve its queued order"), a hard freeze
## (REQ-SET-144), ice on the pond, the species closed, the quota taken, the boat worn below a cycle. So the helm checks
## again, standing on the jetty, before anyone boards (`entry_refusal`); refused, nobody boards and the trip waits on
## the board, its reason shown -- and it is checked again each time. The same recheck runs at a bank before a net is
## cast and at the ice's edge before anyone steps out.
##
## THE FISHING REVAMP (#49, decisions 1711-1713). A completed cycle rolls §5.4's hazard and rare-quality rolls on the
## FISHING stream (fishing_rolls.gd): a hazard hurts the trip's first fisher -- a boat's helm -- through the infirmary
## (`hurt`, wired by the village), and a rare success books 25% of the catch EXCELLENT. A BEST CATCH trip (catch_plan.gd,
## §5.4's auto mode) has its species chosen again at the water. A trap's collection follows its policy (when soaked, or
## the morning run). Each water's record and the intensive policy are fishery_stewardship.gd's.

const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const TaskScript := preload("res://demo/fishery/fishery_task.gd")
const LockerScript := preload("res://demo/fishery/gear_locker.gd")
const SkillsScript := preload("res://demo/fishery/fish_skills.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Text := preload("res://demo/fishery/fishery_text.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const RollsScript := preload("res://demo/fishery/fishing_rolls.gd")
const PlanScript := preload("res://demo/fishery/catch_plan.gd")
const StewardScript := preload("res://demo/fishery/fishery_stewardship.gd")

const NONE: int = -1
## A job's steps (see each program below).
const S_TO_LOCKER: int = 0
const S_TO_BANK: int = 1
const S_WORK: int = 2
const S_GEAR_BACK: int = 3
const S_TO_STORE: int = 4
const S_TO_JETTY: int = 5
const S_JETTY: int = 6
const S_BOARD: int = 7
const S_AFLOAT: int = 8
const S_ALIGHT: int = 9
const S_TO_EDGE: int = 10
const S_ICE_OUT: int = 11
const S_ICE_BACK: int = 12
const S_TO_PICKUP: int = 13
const S_TO_STATION: int = 14
const S_STATION: int = 15
const S_TO_WORKBENCH: int = 16
## The walks among them (the brain plans them; the fishery waits for the arrival).
const WALK_STEPS: Array[int] = [S_TO_LOCKER, S_TO_BANK, S_GEAR_BACK, S_TO_STORE, S_TO_JETTY, S_TO_EDGE, S_TO_PICKUP,
	S_TO_STATION, S_TO_WORKBENCH]
## The programs: what each job does, in order.
const PROG_NET: int = 0
const PROG_TRAP_SET: int = 1
const PROG_COLLECT: int = 2
const PROG_ICE: int = 3
const PROG_BOAT: int = 4
const PROG_DRY: int = 5
const PROG_TAKE_DOWN: int = 6
const PROG_MILL: int = 7
const PROG_MAKE: int = 8
const PROG_MEND: int = 9
const PROGRAMS: Array[Array] = [
	[S_TO_LOCKER, S_TO_BANK, S_WORK, S_GEAR_BACK, S_TO_STORE],
	[S_TO_LOCKER, S_TO_BANK, S_WORK],
	[S_TO_BANK, S_WORK, S_GEAR_BACK, S_TO_STORE],
	[S_TO_LOCKER, S_TO_EDGE, S_ICE_OUT, S_WORK, S_ICE_BACK, S_GEAR_BACK, S_TO_STORE],
	[S_TO_JETTY, S_JETTY, S_BOARD, S_AFLOAT, S_ALIGHT, S_TO_STORE],
	[S_TO_PICKUP, S_TO_STATION, S_STATION],
	[S_TO_STATION, S_STATION, S_TO_STORE],
	[S_TO_PICKUP, S_TO_STATION, S_STATION, S_TO_STORE],
	[S_TO_WORKBENCH, S_STATION, S_TO_LOCKER],
	[S_TO_STATION, S_STATION],
]
## Each method's seat program.
const METHOD_PROG: Array[int] = [PROG_NET, PROG_TRAP_SET, PROG_BOAT, PROG_ICE]
## A worker counts as at its place within this (m; the bridge crew's ARRIVE_M, decision 0361).
const ARRIVE_M: float = 0.45
## Walking a deck or the ice (m/s; presentation: a careful walk).
const DECK_WALK_M_S: float = 0.6
## A MEND's slot names a locker index, or a boat from BOAT_SLOT on.
const BOAT_SLOT: int = 100
## The fixed places (m): the locker by the fisher shelter, the rack beside it, the mill's south door on the far bank,
## the workbench's front, and the ice hole off the pond's south bank (demo values; spots are snapped to standable
## ground at configure).
const LOCKER_AT: Vector2 = Vector2(20.2, 8.4)
const RACK_AT: Vector2 = Vector2(19.9, 11.6)
const RACK_FACE: Vector2 = Vector2(20.9, 11.6)
const MILL_AT: Vector2 = Vector2(28.4, -16.2)
const MILL_FACE: Vector2 = Vector2(27.9, -19.5)
const WORKBENCH_AT: Vector2 = Vector2(8.6, 11.6)
const WORKBENCH_FACE: Vector2 = Vector2(8.6, 12.6)
const ICE_HOLE: Vector2 = Vector2(27.4, 34.6)
## Each recipe station's spot name and the point its worker faces (preserve_rules.gd STATION_*): the rack, the
## preserving table (decision 1611), the brewery (decision 1621).
const STATION_SPOTS: Array[StringName] = [&"rack", &"table", &"brewery"]
const STATION_FACES: Array[Vector2] = [RACK_FACE, Recipes.TABLE_FACE, Recipes.BREWERY_FACE]
## Where an ice fisher steps onto the ice: the pond's south bank, a straight 3 m walk from the hole, clear of the
## jetty, the berths and the raft.
const ICE_EDGE: Vector2 = Vector2(27.5, 37.6)
## The fixed places are snapped for the widest resident (the badger's 0.56 m), on rings this far apart (m).
const SPOT_BODY_M: float = 0.56
const SPOT_RING_M: float = 0.3
const SPOT_RINGS: int = 12
## A walk's goal is a free spot within this many rings of this step of its place (`_free_spot`).
const FREE_SPOT_RINGS: int = 4
const FREE_SPOT_STEP_M: float = 0.45
## Where each boat's crew waits at the jetty, by boat and seat (boat x 2 + seat), from its land end (m): four distinct
## spots on the bank top, so two boats' crews never wait on each other's places.
const JETTY_WAIT_M: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-0.4, -0.9), Vector2(-0.8, 0.8), Vector2(-1.1, -0.2)]
## Ice under a walker: the pond's surface is this far below the datum (water_layout.gd LEVEL_DROP_U, 0.18 m) and the
## ice stands a few centimetres proud of it (presentation).
const ICE_Y_M: float = -0.14
## The clips a fisher works with (every creature has them).
const CLIP_NET: StringName = &"pull_radish"
const CLIP_HANDLE: StringName = &"collect_object"
const CLIP_ROW: StringName = &"pull_radish"
const CLIP_WAIT: StringName = &"idle"
const REFUSE_NONE: String = ""

## The village's parts, and the fishery's own.
var tables: Tables = Tables.new(Recipes.SLOT_COUNT)
var locker: LockerScript = LockerScript.new()
var skills: SkillsScript = SkillsScript.new()
var ice: IceScript = IceScript.new()
var fleet: FleetScript = FleetScript.new()
var driver: Driver = null
var pantry: PantryScript = null
var takes: TakesScript = null
var stores: StoresScript = null
## FISH FOR THE RACK (decision 1739): () -> int, the fish the kitchen holds for meals beyond its next one, and
## (milli) -> int, giving that much of it back; unbound, a fish input counts only the free fish.
var spare_fish: Callable = Callable()
var free_spare_fish: Callable = Callable()
var calendar: CalendarScript = null
var weather: DemoWeatherScript = null
var map: WaterMapScript = null
## `say(text, warning)`: the notice feed (the Water source).
var say: Callable = Callable()
## The fishing revamp (see the header): the rolls, each water's record, `hurt(who, kind, severity, loss) -> bool` (the
## infirmary's; unbound: a hazard is said and counted, nobody is hurt), and the policy new traps are authorised with.
var rolls: RollsScript = RollsScript.new()
var steward: StewardScript = StewardScript.new()
var hurt: Callable = Callable()
var collect_policy: int = PlanScript.COLLECT_SOAKED
var _outcome: RollsScript.Outcome = RollsScript.Outcome.new()
## Bumped whenever anything a panel shows changes.
var revision: int = 0
## THE BOOKS (see THE CATCH FEEDS THE PANTRY), milli-U: everything caught, stored, dried and milled.
var caught_milli: int = 0
var landed_milli: int = 0
var dried_in_milli: int = 0
var dried_out_milli: int = 0
var milled_in_milli: int = 0
var milled_out_milli: int = 0
var spoiled_by_cancel_milli: int = 0
## THE STATIONS' RECIPES' BOOKS (decision 1611; preserve_rules.gd rows), milli-U: food a row's batches took, what they
## made, and the preserves (dried fruit, rations) stored. The fish row is booked here and in `dried_in/out_milli` too.
var batch_in_milli: PackedInt64Array = _zeros(Recipes.RECIPE_COUNT)
var batch_out_milli: PackedInt64Array = _zeros(Recipes.RECIPE_COUNT)
var preserves_stored_milli: int = 0
## The decision's answer (`trip_refusal` and the stations'): its code and its fix, for the card.
var refused_code: String = ""
var refused_fix: String = ""

## SOUNDS (decision 0351's event map; sound/sound_taps.gd `_poll_fishery`): a splash where a net or a trap goes into the
## water, a boat pushes off its berth or a hole is cut in the ice -- committed events only, never a per-frame state;
## the oars' knocks are the taps' own, from the boats' rows. At most SOUND_MAX wait between two polls.
const SOUND_MAX: int = 8
var sound_at: PackedVector2Array = PackedVector2Array()

var _cast: DemoCastScript = null
var _spots: Dictionary = {}
var _bank_water: Dictionary = {}
var _jetty_waits: PackedVector2Array = PackedVector2Array()
var _no_spots: PackedVector2Array = PackedVector2Array()
var _hour_seen: int = -1
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _preview: Driver.Preview = Driver.Preview.new()
var _tasks: Array = []


static func _zeros(count: int) -> PackedInt64Array:
	"""A column of `count` zeros (a recipe row's books)."""
	var column := PackedInt64Array()
	column.resize(count)
	return column


func configure(p_cast: DemoCastScript, water_driver: Driver, p_pantry: PantryScript, p_takes: TakesScript,
		p_stores: StoresScript, p_calendar: CalendarScript, p_weather: DemoWeatherScript, water_map: WaterMapScript) -> void:
	"""Wire the fishery into the village: its cast, the fishing driver (none: nobody fishes), the pantry and the
	kitchen's takes, the stores, the calendar, the weather and the water map."""
	_cast = p_cast
	driver = water_driver
	pantry = p_pantry
	takes = p_takes
	stores = p_stores
	calendar = p_calendar
	weather = p_weather
	map = water_map
	if not locker.open():
		push_warning("fishery: the gear locker did not open (%s); no gear" % locker.error)
	var keys: Array[StringName] = []
	for who: int in p_cast.actor_count():
		keys.append((p_cast.actor(who) as DemoActorScript).creature_key)
	skills.setup(keys)
	_tasks.resize(Tables.MAX_JOBS)
	_find_places()
	_hour_seen = calendar.hour_index() if calendar != null else 0


func _find_places() -> void:
	"""Each fixed place, snapped to standable ground the village reaches (cast_orders.gd `spot_ok`)."""
	_spots[&"locker"] = _standable(LOCKER_AT)
	_spots[&"rack"] = _standable(RACK_FACE)
	_spots[&"mill"] = _standable(MILL_AT)
	_spots[&"table"] = _standable(Recipes.TABLE_AT)
	_spots[&"brewery"] = _standable(Recipes.BREWERY_AT)
	_spots[&"workbench"] = _poi_or(&"workbench", WORKBENCH_FACE)
	_spots[&"jetty"] = _standable(Routes.m_of(Routes.JETTY_LAND_U))
	_jetty_waits.clear()
	for k: int in JETTY_WAIT_M.size():
		_jetty_waits.append(_standable(Routes.m_of(Routes.JETTY_LAND_U) + JETTY_WAIT_M[k], _jetty_waits))
	for site: int in Rules.SITE_BANK.size():
		_spots[Rules.SITE_BANK[site]] = _standable(Rules.SITE_BANK_AT[site])
		_bank_water[site] = Rules.SITE_WATER_AT[site]
	_spots[&"ice_edge"] = _standable(ICE_EDGE)


func _poi_or(name: StringName, near: Vector2) -> Vector2:
	"""The village's own point of interest `name` (the workbench's front: world_layout.gd POINTS), else a standable
	spot near `near`."""
	var space: CastSpaceScript = _cast.space() if _cast != null and _cast.actor_count() > 0 else null
	var k: int = space.poi_names.find(name) if space != null else -1
	return space.poi_position[k] if k >= 0 else _standable(near)


func _landing_m(name: StringName, land: bool) -> Vector2:
	"""A named landing's land (or water) point, metres."""
	if map == null or not map.landing_index_into(name, _read):
		return Vector2.ZERO
	return Routes.m_of(map.landing_land(_read.value) if land else map.landing_water(_read.value))


func _standable(target: Vector2, taken: PackedVector2Array = PackedVector2Array()) -> Vector2:
	"""The spot nearest `target` on rings round it that the widest resident may stand at and that is reachable from
	where the first resident stands (the target itself when there is no cast, or no such spot within SPOT_RINGS)."""
	if _cast == null or _cast.actor_count() == 0:
		return target
	var space: CastSpaceScript = _cast.space()
	var from: Vector2 = brain_of(0).surface_point()
	var none := PackedVector3Array()
	for ring: int in SPOT_RINGS:
		for k: int in (1 if ring == 0 else 12):
			var at: Vector2 = target + Vector2.from_angle(TAU * k / 12.0) * SPOT_RING_M * ring
			if CastOrdersScript.spot_ok(space, at, SPOT_BODY_M, _cast.bounds(), none, taken, from):
				return at
	return target


func spot(name: StringName) -> Vector2:
	"""A fixed place (see `_find_places`), metres."""
	return _spots.get(name, Vector2.ZERO)


# --- per frame -------------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance the fishery by `usec` demo microseconds: the boats, the ice's hour, the traps' soak, the rack's curing,
	the retries and the deadlines."""
	_follow_hours()
	steward.follow(driver)
	_row_boats(usec)
	_follow_traps()
	_follow_rack()
	_follow_safety()
	_count_down(usec)


func _follow_hours() -> void:
	"""Each game hour crossed: the ice grows or melts (pond_ice.gd), and the driver learns whether the lake is frozen
	(REQ-SET-051)."""
	if calendar == null or weather == null:
		return
	var hour: int = calendar.hour_index()
	while _hour_seen < hour:
		_hour_seen += 1
		if ice.advance_hour(weather.day_temperature_tenths()):
			_on_ice_changed()


func _on_ice_changed() -> void:
	"""The pond froze, thawed or turned safe: tell the driver, say so once."""
	if driver != null:
		driver.set_lake_frozen(ice.frozen())
	revision += 1
	_note(ice.line(), ice.state() == IceScript.STATE_THIN)


func _count_down(usec: int) -> void:
	"""Jobs waiting to try a walk again count down (RETRY_USEC)."""
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_wait_usec[j] > 0:
			tables.j_wait_usec[j] = maxi(0, tables.j_wait_usec[j] - usec)


func now_tick() -> int:
	"""The calendar tick (0 with no calendar)."""
	return calendar.tick if calendar != null else 0


func _splash(at: Vector2) -> void:
	"""A committed splash for the sound (see SOUNDS)."""
	if sound_at.size() < SOUND_MAX:
		sound_at.append(at)


func clear_sounds() -> void:
	"""The sound has taken this frame's splashes (see SOUNDS)."""
	sound_at.clear()


func _note(text: String, warning: bool) -> void:
	"""Post to the notice feed (Water)."""
	if say.is_valid():
		say.call(text, warning)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name


func cast() -> DemoCastScript:
	"""The cast."""
	return _cast


# --- THE DECISION: may this trip be authorised now? (the card's and the order's own; decision 0332) ---------------

func trip_refusal(method: int, site: int, species: int, members: PackedInt32Array) -> String:
	"""Why a trip of `method` at `site` for its species `species` (0..2 there) may not be authorised now ("" when it
	may), its code and fix in `refused_code` / `refused_fix`. The Authorise button and its card both run this."""
	refused_code = ""
	refused_fix = ""
	species = planned_species(method, site, species, members)
	if species == NONE:
		return _no_fish_refusal(method, site)
	var why: String = _water_refusal(method, site, species)
	if why.is_empty():
		why = _kit_refusal(method)
	if why.is_empty():
		why = _room_refusal(method, site, species, _likely_level(method, members))
	if why.is_empty():
		why = _crew_refusal(method)
	if why.is_empty() and tables.trip_count() >= Tables.MAX_TRIPS:
		why = _refuse("TRIPS", "%d trips are out already" % Tables.MAX_TRIPS, "wait for one to come home")
	if why.is_empty() and tables.MAX_JOBS - tables.job_count() < Rules.METHOD_CREW[method]:
		why = _refuse("JOBS", "the fishery's job list is full", "wait for a job to finish")
	return why


## The refusals that are about one species (BEST CATCH tries the next); any other is the water's or the method's.
const SPECIES_CODES: Array[String] = ["SPECIES_CLOSED", "SPECIES_UNAVAILABLE", "RESTOCKING", "BELOW_STOCK_FLOOR",
	"GEAR_CANNOT_TAKE_SPECIES", "NOT_FOOD", "NO_CATCH"]


func _no_fish_refusal(method: int, site: int) -> String:
	"""BEST CATCH found nothing: the water's or the method's own reason when there is one (ice, the quota, the places,
	the weather), else that no fish there may be fished."""
	var why: String = _water_refusal(method, site, 0)
	if not why.is_empty() and not SPECIES_CODES.has(refused_code):
		return why
	return _refuse("NO_LEGAL_FISH", "no fish there may be fished now (each is closed, out of season or restocking)",
		"◀ ▶ another site or method")


func _refuse(code: String, words: String, fix: String) -> String:
	"""Record a refusal's code and fix; return its words."""
	refused_code = code
	refused_fix = fix
	return words


func _water_refusal(method: int, site: int, species: int) -> String:
	"""The water's half: the method at the site, the ice, the fishery's own rules (closure, quota, latch, slots, the
	gear's species), the whitelist and -- for a boat -- the weather."""
	if driver == null:
		return _refuse("NO_FISHERY", "the fishery did not start (no fish items bound)", "")
	if not Rules.offers_site(method, site) or not driver.gear_offered(site, Rules.METHOD_GEAR[method]):
		return _refuse("SITE", "%s is not used at %s" % [Rules.METHOD_NAMES[method].to_lower(), Rules.SITE_NAMES[site]],
			"◀ ▶ another site or method")
	var iced: String = _ice_refusal(method, site)
	if not iced.is_empty():
		return iced
	var code: StringName = driver.refusal(site, species, Rules.METHOD_GEAR[method])
	if code != Driver.REFUSE_NONE:
		return _refuse(String(code), Text.driver_words(code, driver.species_key_of(site, species)) + _reopens(site, species,
			method, code), _driver_fix(code))
	if Rules.pantry_item_of(driver.species_row_of(site, species)) == Catalog.NO_ITEM:
		return _refuse("NOT_FOOD", "%s is not caught here" % driver.species_key_of(site, species), "")
	if method == Rules.METHOD_BOAT:
		return _weather_refusal()
	return ""


func _reopens(site: int, species: int, method: int, code: StringName) -> String:
	"""REQ-SET-046: a closed or out-of-season species' refusal names its reopening day (' — reopens summer 1')."""
	if code != Fishing.REFUSE_SPECIES_CLOSED and code != Fishing.REFUSE_SPECIES_UNAVAILABLE:
		return ""
	if not driver.preview_into(site, species, Rules.METHOD_GEAR[method], 0, _preview):
		return ""
	if _preview.availability_per_1000 > 0 and driver.days_to_closure(site, species) != 0:
		return " — closed by an event: reopening not known"
	return " — reopens %s" % Text.date_text(_preview.reopen_season, _preview.reopen_day)


func _driver_fix(code: StringName) -> String:
	"""What to do about a fishery refusal."""
	match code:
		Fishing.REFUSE_QUOTA_REACHED:
			return "wait for midnight's new quota, or fish another water"
		Fishing.REFUSE_EFFORT_SLOTS_FULL:
			return "wait for a fisher there to finish"
		Fishing.REFUSE_RESTOCKING, Fishing.REFUSE_BELOW_STOCK_FLOOR:
			return "fish another species: this one is left to recover"
		Driver.REFUSE_GEAR_SPECIES:
			return "◀ ▶ dace, perch or carp for a trap, or another method"
	return "◀ ▶ another species or site"


func _ice_refusal(method: int, site: int) -> String:
	"""The pond's ice (pond_ice.gd): on ice only ice fishing, and only on SAFE ice; ice fishing only on ice."""
	if site != Driver.SITE_POND:
		return ""
	if method != Rules.METHOD_ICE:
		if not ice.frozen():
			return ""
		@warning_ignore("integer_division") return _refuse("ICE_COVERS", "ice covers the pond (%d mm): no boat, net or trap" % ice.millimetres(),
			"Ice fishing, once the ice is safe (%d mm)" % (IceScript.SAFE_UM / 1000))
	if not ice.frozen():
		return _refuse("NO_ICE", "the pond is open water: ice fishing waits for winter ice", "net, trap or boat instead")
	if not ice.safe():
		@warning_ignore("integer_division") return _refuse("THIN_ICE", "the ice is thin (%d mm; safe from %d mm)" % [ice.millimetres(), IceScript.SAFE_UM / 1000],
			_thin_fix())
	return ""


func _thin_fix() -> String:
	"""When thin ice will be safe, at today's cold."""
	var hours: int = IceScript.hours_to_safe(ice.thickness_um, weather.day_temperature_tenths() if weather != null else 0)
	return "keep off: thawing, it won't be safe" if hours < 0 else "wait: safe in about %d game hours of this cold" % hours


func _weather_refusal() -> String:
	"""REQ-SET-052 (a storm prevents a boat's departure) and REQ-SET-144 (a hard freeze prevents unsafe ones)."""
	if weather == null:
		return ""
	match weather.event():
		WeatherScript.EVENT_HEAVY_RAIN:
			return _refuse("STORM", "a storm: no boat leaves the jetty", "wait for the storm to pass (the trip waits)")
		WeatherScript.EVENT_HARD_FREEZE:
			return _refuse("HARD_FREEZE", "a hard freeze: no boat goes out", "wait for the freeze to break")
	return ""


func _kit_refusal(method: int) -> String:
	"""The boat or the gear: a free boat that holds a cycle's wear; a free piece of the method's gear that does; for
	ice, a winter outfit too."""
	if method == Rules.METHOD_BOAT:
		return _boat_refusal()
	var kind: int = GEAR_OF_METHOD[method]
	if not locker.ok:
		return _refuse("NO_LOCKER", "the gear locker did not open", "")
	if not locker.pick_into(kind, _read):
		return _gear_words(kind, String(_read.error))
	if method == Rules.METHOD_ICE and not locker.pick_into(LockerScript.KIND_OUTFIT, _read):
		return _refuse("NO_OUTFIT", "no free winter outfit (tier 2): both are out", "wait for an ice fisher to come back")
	return ""


## The locker kind each method's gear is (a boat is no locker gear).
const GEAR_OF_METHOD: Array[int] = [LockerScript.KIND_NET, LockerScript.KIND_TRAP, -1, LockerScript.KIND_ICE_KIT]


func _gear_words(kind: int, code: String) -> String:
	"""A locker refusal in words, with its fix."""
	var name: String = LockerScript.KIND_NAMES[kind]
	match code:
		"NO_GEAR":
			return _refuse("NO_GEAR", "the locker has no %s" % name, "Make %s at the workbench" % name)
		"GEAR_IN_USE":
			return _refuse("GEAR_IN_USE", "every %s is out on a trip" % name, "wait for one to come back")
	return _refuse("GEAR_WORN", "every free %s is worn below a cycle's %d" % [name, locker.wear_of_kind(kind)],
		"Mend gear (the locker)")


func _boat_refusal() -> String:
	"""A boat for a fishing trip: free (moored, nobody's) and holding a cycle's wear -- one of the boathouse's
	(boat_routes.gd FISHING_BOATS; the ferry boat never fishes, decision 0437)."""
	if _free_boat() >= 0:
		return ""
	for boat: int in Routes.FISHING_BOATS:
		if fleet.is_free(boat):
			return _refuse("BOAT_WORN", "Rowboat %d is worn (%d/1000, below a cycle's %d)" % [boat + 1, fleet.durability[boat],
				FleetScript.WEAR_PER_CYCLE], "Mend boat")
	return _refuse("BOATS_OUT", "both boats are out", "wait for a boat to come back")


func _free_boat() -> int:
	"""The free fishing boat that can fish, the lowest first (-1: none)."""
	for boat: int in Routes.FISHING_BOATS:
		if fleet.is_free(boat) and fleet.can_fish(boat):
			return boat
	return -1


func _room_refusal(method: int, site: int, species: int, level: int) -> String:
	"""The catch's room: the expected catch must be more than nothing, and a store must have room for it (decision
	0222: a producer reserves first)."""
	var expected: int = expected_catch(method, site, species, level)
	if expected <= 0:
		return _refuse("NO_CATCH", "nothing to catch there now (the stock, the season or the quota)", "◀ ▶ another species")
	var item: int = Rules.pantry_item_of(driver.species_row_of(site, species))
	if not pantry.location_for_item_into(item, expected, _read):
		return _refuse("NO_ROOM", "no store has room for %s" % Text.catch_text(expected, item), "Pantry (K): make room")
	return ""


func expected_catch(method: int, site: int, species: int, level: int) -> int:
	"""fishing.gd's own catch for one cycle of `method` at FISH `level` now (REQ-SET-055's expected catch), milli-U."""
	if driver == null or not driver.preview_into(site, species, Rules.METHOD_GEAR[method], level, _preview):
		return 0
	return _preview.expected_catch_milli


func preview_of(method: int, site: int, species: int, level: int) -> Driver.Preview:
	"""REQ-SET-055's figures for the card, for the method's whole crew (reused: read it before the next call); null
	without a fishery."""
	if driver == null or not driver.preview_into(site, species, Rules.METHOD_GEAR[method], level, _preview,
			Rules.METHOD_CREW[method] - 1):
		return null
	return _preview


func planned_species(method: int, site: int, species: int, members: PackedInt32Array) -> int:
	"""The species index a trip's choice fishes: a chosen fish as it is; BEST CATCH (catch_plan.gd PLAN_AUTO) §5.4's
	auto pick at the crew's likely level, NONE when nothing may be fished."""
	if not PlanScript.is_auto(species):
		return species
	return PlanScript.best_species(driver, site, method, _likely_level(method, members), _preview)


func _crew_refusal(method: int) -> String:
	"""Somebody in the village can take each seat: a boat's helm needs FISH >= 1."""
	for seat: int in Rules.METHOD_CREW[method]:
		var anyone: bool = false
		for who: int in _cast.actor_count():
			if seat_eligibility(method, seat, who, false).is_empty():
				anyone = true
				break
		if not anyone:
			return _refuse("NO_CREW", "nobody can take the helm (fishing %d)" % Rules.HELM_MIN_LEVEL if seat == FleetScript.HELM \
				and method == Rules.METHOD_BOAT else "nobody can go", "a fisher learns on a net from the bank")
	return ""


func seat_eligibility(method: int, seat: int, who: int, busy_counts: bool) -> String:
	"""Why `who` may not take seat `seat` of a `method` trip ("" when it may): one fishery job at a time (when
	`busy_counts`), and a boat's helm needs FISH >= HELM_MIN_LEVEL. Never a species (LORE-P12)."""
	if busy_counts and tables.job_of_worker(who) != NONE:
		return "has another fishery job"
	if method == Rules.METHOD_BOAT and seat == FleetScript.HELM and not skills.can_helm(who):
		return "can't take a boat's helm yet (fishing %d; needs %d)" % [skills.level_of(who), Rules.HELM_MIN_LEVEL]
	return ""


func _likely_level(method: int, members: PackedInt32Array) -> int:
	"""The FISH level the preview reckons with: the selected resident's who could go (a boat: the group's), else the
	best in the village (the board offers the job to whoever is free; this is the card's estimate)."""
	var levels := PackedInt32Array()
	for who: int in members:
		if levels.size() < Rules.METHOD_CREW[method] and seat_eligibility(method, levels.size(), who, false).is_empty():
			levels.append(skills.level_of(who))
	if levels.is_empty():
		for who: int in _cast.actor_count():
			levels.append(skills.level_of(who))
		levels.sort()
		return levels[levels.size() - 1] if not levels.is_empty() else 0
	return SkillsScript.group_level(levels)


# --- the orders ----------------------------------------------------------------------------------

func authorise(method: int, site: int, species: int, members: PackedInt32Array) -> String:
	"""Authorise a trip (the Water panel's Authorise; the same decision as its card): its gear or boat set aside, its
	seats put on the work board -- given to the selected residents first. "" when authorised, else why not."""
	var why: String = trip_refusal(method, site, species, members)
	if not why.is_empty():
		return why
	var t: int = tables.open_trip(method, site, planned_species(method, site, species, members))
	tables.t_auto[t] = 1 if PlanScript.is_auto(species) else 0
	tables.t_collect[t] = collect_policy
	tables.t_item[t] = Rules.pantry_item_of(driver.species_row_of(site, tables.t_species[t]))
	tables.t_due[t] = now_tick() + estimate_ticks(method) + Rules.OVERDUE_MARGIN_TICKS
	_set_aside_kit(t)
	for seat: int in Rules.METHOD_CREW[method]:
		var j: int = tables.open_job(Tables.KIND_SEAT, METHOD_PROG[method], t)
		tables.j_seat[j] = seat
		tables.t_seat_job[t * 2 + seat] = j
	_assign_selected(t, members)
	revision += 1
	return ""


func _set_aside_kit(t: int) -> void:
	"""The trip's boat (taken), or its gear and -- for ice -- its outfit (set aside)."""
	var serial: int = tables.t_serial[t]
	if tables.t_method[t] == Rules.METHOD_BOAT:
		var boat: int = _free_boat()
		fleet.set_course(boat, Routes.route(boat), map)
		fleet.take(boat, serial)
		tables.t_boat[t] = boat
		return
	if locker.pick_into(GEAR_OF_METHOD[tables.t_method[t]], _read):
		tables.t_gear[t] = _read.value
		locker.earmark(_read.value, serial)
	if tables.t_method[t] == Rules.METHOD_ICE and locker.pick_into(LockerScript.KIND_OUTFIT, _read):
		tables.t_outfit[t] = _read.value
		locker.earmark(_read.value, serial)


func _assign_selected(t: int, members: PackedInt32Array) -> void:
	"""Give the trip's seats to the selected residents who may take them, in seat order (the helm first)."""
	var used := PackedInt32Array()
	for seat: int in Rules.METHOD_CREW[tables.t_method[t]]:
		var j: int = tables.t_seat_job[t * 2 + seat]
		for who: int in members:
			if not used.has(who) and eligibility(j, who).is_empty() and claim(j, who):
				used.append(who)
				break


func estimate_ticks(method: int) -> int:
	"""Calendar ticks a trip of `method` is reckoned to take from authorising to landing, at FISH 0 (the card's
	"about"; the deadline adds OVERDUE_MARGIN_TICKS): its work, a trap's soak, and a game hour for the walks (DEMO)."""
	@warning_ignore("integer_division") var work: int = Rules.METHOD_WORK_MWU[method] / Rules.METHOD_CREW[method]
	var ticks: int = Rules.work_ticks(work, 0) + SimClock.TICKS_PER_HOUR
	if method == Rules.METHOD_TRAP:
		ticks += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR + Rules.work_ticks(Rules.TRAP_COLLECT_MWU, 0)
	return ticks


func cancel_trip(t: int) -> String:
	"""Call a trip off: "" when it was (its claims released at once, its crew home), else why not -- a catch out of the
	water is always landed (decision 0222)."""
	if not tables.is_trip(t):
		return "that trip is over"
	if tables.t_state[t] == Tables.TRIP_LANDING:
		return "the catch is out of the water — it is landed first"
	if tables.t_called_off[t] == 1:
		return "it is coming back already"
	call_off(t, "called off")
	return ""


func call_off(t: int, why: String) -> void:
	"""End a trip early: the open cycle cancelled (its slots back, nothing taken), the gear's claim released with no
	wear, the room held for the catch given back; then each crew member comes home -- off the water first."""
	_release_cycle(t)
	tables.t_called_off[t] = 1
	if tables.t_state[t] == Tables.TRIP_FISHING or tables.t_state[t] == Tables.TRIP_SOAKING:
		tables.t_state[t] = Tables.TRIP_RETURNING
	if tables.t_boat[t] >= 0:
		fleet.row_back(tables.t_boat[t])
	for seat: int in 2:
		var j: int = tables.t_seat_job[t * 2 + seat]
		if j >= 0 and tables.j_live[j] == 1:
			_send_home(j)
	_end_collect_of(t)
	_note("%s: %s" % [trip_name(t), why], false)
	_try_close_trip(t)
	revision += 1


func _release_cycle(t: int) -> void:
	"""Cancel a trip's open cycle (fishing_driver.gd `cancel_cycle`), its gear claim (gear.gd `cancel_claim`, no wear)
	and its held room."""
	var cycle: Driver.Cycle = tables.t_cycle[t] as Driver.Cycle
	if cycle != null and cycle.ok:
		if tables.t_gear[t] >= 0:
			locker.cancel(tables.t_gear[t], cycle.job)
		driver.cancel_cycle(cycle)
	tables.t_cycle[t] = null
	if tables.t_hold[t] >= 0:
		pantry.release(tables.t_hold[t])
		tables.t_hold[t] = NONE


func _send_home(j: int) -> void:
	"""A called-off trip's job: nobody on it -- closed; on land -- its gear back to the locker, else done; out on the
	water or the ice -- it keeps coming back (the boat rows home; the ice walker walks off)."""
	var step: int = step_of(j)
	if step == S_AFLOAT or step == S_BOARD or step == S_ICE_OUT or step == S_WORK and _on_ice(j):
		if step == S_ICE_OUT or step == S_WORK:
			_jump_to(j, S_ICE_BACK)
		return
	if tables.j_load_milli[j] > 0:
		return
	if tables.j_worker[j] != NONE and tables.j_started[j] == 1 and tables.j_kind[j] <= Tables.KIND_COLLECT:
		_jump_to(j, S_GEAR_BACK)
		return
	_end_job(j)


# --- the jobs: offering, claiming and releasing (work/fishery_work.gd reads these) ---------------

## A refused crew rechecks this often (DEMO): a storm or a closure may pass.
const RECHECK_USEC: int = 5000000
## The job whose `drive` is running: ending it there returns false to the brain instead of releasing it again.
var _driving: int = NONE


func step_of(j: int) -> int:
	"""Job `j`'s current step (S_*), or NONE past its last."""
	var prog: Array = PROGRAMS[tables.j_prog[j]]
	var pos: int = tables.j_pos[j]
	return int(prog[pos]) if pos >= 0 and pos < prog.size() else NONE


func waiting(j: int) -> bool:
	"""Whether job `j` waits for a resident and may be taken now: live, nobody on it, not paused, not waiting to try
	again."""
	return tables.j_live[j] == 1 and tables.j_worker[j] == NONE and tables.j_paused[j] == 0 \
		and tables.j_wait_usec[j] <= 0


func eligibility(j: int, who: int) -> String:
	"""Why `who` may not take job `j` ("" when it may): one fishery job at a time, on land and free of the rescue, and
	a boat's helm needs FISH >= 1. Never a species (LORE-P12)."""
	if tables.job_of_worker(who) != NONE and tables.j_worker[j] != who:
		return "has another fishery job"
	var brain: BrainScript = brain_of(who)
	if brain.water_hold or brain.in_water:
		return "in the water"
	if brain.underground:
		return "is below ground"
	if tables.j_kind[j] == Tables.KIND_SEAT:
		return seat_eligibility(tables.t_method[tables.j_trip[j]], tables.j_seat[j], who, false)
	return ""


func claim(j: int, who: int) -> bool:
	"""Hand waiting job `j` to `who`, who sets off at once (the board's claim, or Authorise with residents selected).
	False when it may not."""
	if not waiting(j) or not eligibility(j, who).is_empty():
		return false
	var task := TaskScript.new(self, j, tables.j_serial[j])
	tables.j_worker[j] = who
	tables.j_issued[j] = 1
	tables.j_at[j] = 0
	_tasks[j] = task
	var brain: BrainScript = brain_of(who)
	brain.order_task(task)
	if brain.task != task:
		tables.j_worker[j] = NONE
		return false
	revision += 1
	return true


func _end_job(j: int) -> void:
	"""Close job `j`: its kitchen take and held store room released, its trip's seat link cleared (a reused row is
	never mistaken for the trip's), its worker free (from outside `drive`, sent back to its routine), and
	its trip closed once nothing of it is left."""
	var who: int = tables.j_worker[j]
	var trip: int = tables.j_trip[j]
	if tables.j_take[j] > 0:
		takes.release(tables.j_take[j])
	if pantry.is_hold(tables.j_hold[j]):
		pantry.release(tables.j_hold[j])
	if trip >= 0:
		for seat: int in 2:
			if tables.t_seat_job[trip * 2 + seat] == j:
				tables.t_seat_job[trip * 2 + seat] = NONE
	tables.close_job(j)
	_tasks[j] = null
	if who != NONE and j != _driving:
		_free_worker(who)
	if trip >= 0:
		_try_close_trip(trip)
	revision += 1


func _free_worker(who: int) -> void:
	"""A worker whose job ended outside its own frame: off the water or the ice, and back to its routine."""
	var brain: BrainScript = brain_of(who)
	brain.water_hold = false
	brain.work_done()


func _let_go(j: int) -> void:
	"""Job `j` loses its worker (released, unreached, called away) but stays on the board: a gear walk not yet begun
	starts again from the locker; a load in hand is set down where it is, for the next to fetch (see CARGO)."""
	var who: int = tables.j_worker[j]
	tables.j_worker[j] = NONE
	tables.j_issued[j] = 0
	tables.j_at[j] = 0
	if tables.j_load_milli[j] > 0 and not tables.j_load_at[j].is_finite() and who != NONE:
		tables.j_load_at[j] = brain_of(who).surface_point()
	if tables.j_kind[j] == Tables.KIND_SEAT and _before_cycle(j):
		tables.j_pos[j] = 0
		tables.j_started[j] = 0
	revision += 1


func _before_cycle(j: int) -> bool:
	"""Whether job `j`'s trip has not begun its cycle yet (nothing taken from the water)."""
	var t: int = tables.j_trip[j]
	return t >= 0 and tables.t_state[t] == Tables.TRIP_QUEUED


func _try_close_trip(t: int) -> void:
	"""A trip whose jobs are all done and whose boat is home is over: its gear, outfit and boat given back, its held
	room released, its row freed."""
	if not tables.is_trip(t) or tables.t_state[t] == Tables.TRIP_SOAKING:
		return
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_trip[j] == t:
			return
	var boat: int = tables.t_boat[t]
	if boat >= 0 and fleet.phase[boat] != FleetScript.PHASE_MOORED:
		return
	_release_cycle(t)
	var serial: int = tables.t_serial[t]
	locker.release(tables.t_gear[t], serial)
	locker.release(tables.t_outfit[t], serial)
	if boat >= 0:
		fleet.give_back(boat, serial)
	tables.close_trip(t)
	revision += 1


# --- the task's callbacks (fishery_task.gd) ------------------------------------------------------

func first_site(j: int, serial: int) -> Vector2:
	"""Where a new worker of job `j` walks first: a free spot at its current step's place (or a set-down load's)."""
	if not tables.is_job(j, serial):
		return Vector2.ZERO
	tables.j_goal[j] = _free_spot(_goal_of(j), tables.j_worker[j])
	return tables.j_goal[j]


func goal_point(j: int) -> Vector2:
	"""Where job `j` is now (the board's distance): its worker's goal, else its current step's place."""
	return tables.j_goal[j] if tables.j_worker[j] != NONE else _goal_of(j)


func _free_spot(target: Vector2, who: int) -> Vector2:
	"""A spot at `target` resident `who` can stand on and reach now -- the target, else the nearest on rings round it
	(FREE_SPOT_RINGS of FREE_SPOT_STEP_M) clear of anyone standing still: a resident idling on a store's spot never
	blocks the delivery (the arrival is still to that spot, decision 0361). Reachable from where it stands, else (the
	reach sweep stops at water it would wade) from the place itself; the target when none is free."""
	if who == NONE or _cast == null:
		return target
	var brain: BrainScript = brain_of(who)
	var space: CastSpaceScript = _cast.space()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(space, members)
	for from: Vector2 in [brain.surface_point(), target]:
		for ring: int in FREE_SPOT_RINGS:
			for k: int in (1 if ring == 0 else 8):
				var at: Vector2 = target + Vector2.from_angle(TAU * k / 8.0) * FREE_SPOT_STEP_M * ring
				if CastOrdersScript.spot_ok(space, at, brain.radius, _cast.bounds(), avoid, _no_spots, from):
					return at
	return target


func arrived(j: int, serial: int, brain: BrainScript) -> void:
	"""The worker reached where it was sent: handled on its next frame (`drive`), never inside the brain's arrival."""
	if tables.is_job(j, serial) and tables.j_worker[j] == brain.index:
		tables.j_issued[j] = 2


func drive(j: int, serial: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of job `j` for its worker: an arrival handled, then the step's frame. False once its part is over."""
	if not tables.is_job(j, serial) or tables.j_worker[j] != brain.index:
		return false
	_driving = j
	if tables.j_issued[j] == 2:
		tables.j_issued[j] = 0
		_on_arrival(j, brain)
	if tables.is_job(j, serial) and tables.j_worker[j] == brain.index:
		_frame(j, brain, delta)
	_driving = NONE
	return tables.is_job(j, serial) and tables.j_worker[j] == brain.index


func called_away(j: int, serial: int, brain: BrainScript) -> void:
	"""The brain gave the task up: a walk it could not finish (unreached), or an order, the night or a release (the
	job goes back on the board; see CARGO)."""
	if not tables.is_job(j, serial) or tables.j_worker[j] != brain.index:
		return
	if brain.trip_failed():
		_unreached(j, brain)
		return
	_let_go(j)


func must_finish(j: int, serial: int) -> bool:
	"""Whether the night must wait: a load in hand, or out on the water or the ice."""
	if not tables.is_job(j, serial):
		return false
	var step: int = step_of(j)
	if step == S_BOARD or step == S_AFLOAT or step == S_ALIGHT or step == S_ICE_OUT or step == S_ICE_BACK:
		return true
	return _on_ice(j) or (tables.j_load_milli[j] > 0 and not tables.j_load_at[j].is_finite())


func _on_ice(j: int) -> bool:
	"""Whether job `j`'s worker stands out on the ice (an ice trip between stepping out and back)."""
	var t: int = tables.j_trip[j]
	if t < 0 or tables.t_method[t] != Rules.METHOD_ICE:
		return false
	var step: int = step_of(j)
	return step == S_ICE_OUT or step == S_WORK or step == S_ICE_BACK


func _unreached(j: int, brain: BrainScript) -> void:
	"""The worker could not get to its place: the job waits RETRY_USEC and tries again (with anyone); after MAX_TRIES
	it is given up -- a trip called off, a station order cancelled -- and the feed says where it could not get."""
	var where: String = place_words(j)
	tables.j_tries[j] += 1
	tables.j_words[j] = "can't reach %s — %s" % [where, brain.route_refusal()]
	_let_go(j)
	tables.j_wait_usec[j] = Rules.RETRY_USEC
	if tables.j_tries[j] < Rules.MAX_TRIES:
		return
	_note("%s could not reach %s: given up" % [name_of(brain.index), where], true)
	if tables.j_trip[j] >= 0:
		call_off(tables.j_trip[j], "nobody could reach %s" % where)
	else:
		cancel_station_job(j)


# --- the steps -----------------------------------------------------------------------------------

func _goal_of(j: int) -> Vector2:
	"""Where job `j`'s current step is (a set-down load first: it must be picked up)."""
	if tables.j_load_milli[j] > 0 and tables.j_load_at[j].is_finite():
		return tables.j_load_at[j]
	var t: int = tables.j_trip[j]
	match step_of(j):
		S_TO_LOCKER, S_GEAR_BACK:
			return spot(&"locker")
		S_TO_BANK, S_WORK:
			return spot(Rules.SITE_BANK[tables.t_site[t]]) if t >= 0 else spot(&"locker")
		S_TO_JETTY, S_JETTY:
			return _jetty_waits[maxi(tables.t_boat[t], 0) * 2 + maxi(tables.j_seat[j], 0)]
		S_TO_EDGE, S_ICE_BACK:
			return spot(&"ice_edge")
		S_TO_STORE:
			return _store_goal(j)
		S_TO_PICKUP:
			return tables.j_goal[j]
		S_TO_WORKBENCH:
			return spot(&"workbench")
	return _station_spot(j)


func _station_spot(j: int) -> Vector2:
	"""A station job's place: the rack, the mill, the workbench, the locker, or the jetty (a boat's mending)."""
	match tables.j_kind[j]:
		Tables.KIND_DRY, Tables.KIND_TAKE_DOWN, Tables.KIND_BATCH:
			return spot(STATION_SPOTS[_station_of_job(j)])
		Tables.KIND_MILL:
			return spot(&"mill")
		Tables.KIND_MAKE:
			return spot(&"workbench")
		Tables.KIND_MEND:
			return spot(&"jetty") if tables.j_slot[j] >= BOAT_SLOT else spot(&"locker")
	return spot(&"locker")


func _station_of_job(j: int) -> int:
	"""The recipe station job `j` works at: its recipe's, or -- a station job with no recipe, a programming error said
	once -- the rack (a negative index would wrap to another station)."""
	var recipe: int = tables.j_recipe[j]
	if Recipes.is_recipe(recipe):
		return Recipes.STATION[recipe]
	push_error("fishery: station job %d has no recipe" % j)
	return Recipes.STATION_RACK


func _store_goal(j: int) -> Vector2:
	"""Where a load goes: its held store's delivery point (a hold made now if it has none; where it stands if no store
	has room)."""
	if not pantry.is_hold(tables.j_hold[j]):
		tables.j_hold[j] = _hold_for(tables.j_load_item[j], tables.j_load_milli[j], tables.j_goal[j])
	if pantry.hold_location_into(tables.j_hold[j], _read):
		return pantry.storage.position_of(_read.value)
	return tables.j_goal[j]


func _hold_for(item: int, milli: int, from: Vector2) -> int:
	"""Room held for `milli` of `item` at the store a carrier from `from` should take it to (NONE: none has room)."""
	return _read.value if pantry.reserve_near_into(item, milli, from, _read) else NONE


func _advance(j: int, brain: BrainScript) -> void:
	"""Job `j` finished its step: on to its next one that applies, or the job is over."""
	tables.j_pos[j] += 1
	while step_of(j) != NONE and _skip(j, step_of(j)):
		tables.j_pos[j] += 1
	if step_of(j) == NONE:
		_end_job(j)
		return
	_begin_step(j, brain)


func _skip(j: int, step: int) -> bool:
	"""A step with nothing to do: a store walk with nothing to carry, a locker walk with no gear in hand."""
	if step == S_TO_STORE:
		return tables.j_load_milli[j] <= 0
	if step == S_GEAR_BACK:
		return tables.j_started[j] == 0
	return false


func _jump_to(j: int, step: int) -> void:
	"""Move job `j` to `step` of its program (when it has it), starting it for its worker."""
	var pos: int = PROGRAMS[tables.j_prog[j]].find(step)
	if pos < 0:
		return
	tables.j_pos[j] = pos
	if tables.j_worker[j] != NONE:
		_begin_step(j, brain_of(tables.j_worker[j]))


func _begin_step(j: int, brain: BrainScript) -> void:
	"""Start job `j`'s current step: a walk is ordered (a load carried), a work step's count starts, a deck or ice walk
	starts from where it stands."""
	var step: int = step_of(j)
	tables.j_at[j] = 0
	if WALK_STEPS.has(step):
		tables.j_goal[j] = _free_spot(_goal_of(j), brain.index)
		tables.j_issued[j] = 1
		if _carries(j):
			brain.task_carry_to(tables.j_goal[j])
		else:
			brain.task_walk_to(tables.j_goal[j])
		return
	tables.j_issued[j] = 0
	tables.j_mwu[j] = 0
	tables.j_num[j] = 0
	tables.j_need[j] = _need_of(j)
	if step == S_JETTY:
		tables.j_at[j] = 1


func _carries(j: int) -> bool:
	"""Whether job `j`'s worker walks LOADED now -- a catch, dried fish, flour or new gear in hand, a batch's food on its
	way to the rack or the mill, or a trip's gear: a loaded resident never swims (decision 0196), so it goes round, wades
	the ford or takes a bridge."""
	if tables.j_load_milli[j] > 0:
		return not tables.j_load_at[j].is_finite()
	if step_of(j) == S_TO_STATION and (tables.j_kind[j] == Tables.KIND_DRY or tables.j_kind[j] == Tables.KIND_MILL
			or tables.j_kind[j] == Tables.KIND_BATCH):
		return true
	return tables.j_started[j] == 1 and tables.j_kind[j] <= Tables.KIND_COLLECT


func _on_arrival(j: int, brain: BrainScript) -> void:
	"""The worker is where it was sent (decision 0361: only if it stands there): a set-down load picked up, a work
	place reached, or the walk step's own arrival."""
	if not brain.arrived_near(tables.j_goal[j], ARRIVE_M):
		_unreached(j, brain)
		return
	tables.j_tries[j] = 0
	tables.j_words[j] = ""
	var step: int = step_of(j)
	if tables.j_load_milli[j] > 0 and tables.j_load_at[j].is_finite():
		tables.j_load_at[j] = Vector2.INF
		if WALK_STEPS.has(step):
			_begin_step(j, brain)
		return
	if not WALK_STEPS.has(step):
		tables.j_at[j] = 1
		return
	_arrived_at(j, brain, step)


func _arrived_at(j: int, brain: BrainScript, step: int) -> void:
	"""A walk step's arrival: what happens at that place."""
	match step:
		S_TO_LOCKER:
			_at_locker(j, brain)
		S_TO_BANK:
			_at_water(j, brain)
		S_TO_EDGE:
			_at_water(j, brain)
		S_GEAR_BACK:
			tables.j_started[j] = 0
			_advance(j, brain)
		S_TO_STORE:
			_deliver(j, brain)
		S_TO_STATION:
			_at_station(j, brain)
		S_TO_WORKBENCH:
			_pay_and_start(j, brain)
		_:
			_advance(j, brain)


func _frame(j: int, brain: BrainScript, delta: float) -> void:
	"""One frame of a step that is not a planner walk (a planner walk re-ordered if it lapsed; a carrier waiting for
	store room stands until its RETRY_USEC is up, then plans once)."""
	match step_of(j):
		S_WORK, S_STATION:
			_work_frame(j, brain, delta)
		S_JETTY:
			_jetty_frame(j, brain, delta)
		S_BOARD:
			_board_frame(j, brain, delta)
		S_AFLOAT:
			_afloat_frame(j, brain, delta)
		S_ALIGHT:
			_alight_frame(j, brain, delta)
		S_ICE_OUT:
			_ice_frame(j, brain, delta, ICE_HOLE)
		S_ICE_BACK:
			_ice_frame(j, brain, delta, spot(&"ice_edge"))
		_:
			if tables.j_issued[j] == 0 and tables.j_wait_usec[j] <= 0:
				_begin_step(j, brain)


# --- at the places ---------------------------------------------------------------------------------

func _at_locker(j: int, brain: BrainScript) -> void:
	"""At the locker: a fisher takes its trip's gear (the set-aside piece; the books never move: gear.gd's claim is the
	cycle's, at the water); a maker puts its new gear in (gear_locker.gd `add_gear`; refused, what it cost is given back
	-- no hidden loss)."""
	if tables.j_kind[j] == Tables.KIND_MAKE:
		var made: int = locker.add_gear(tables.j_slot[j])
		tables.j_load_milli[j] = 0
		tables.j_load_item[j] = NONE
		if made == NONE:
			_refund(j)
		_note("A new %s is in the gear locker" % LockerScript.KIND_NAMES[tables.j_slot[j]] if made != NONE \
			else "The locker refused the new gear (%s): its wood and rope or iron given back" % locker.error, made == NONE)
		_advance(j, brain)
		return
	tables.j_started[j] = 1
	_advance(j, brain)


func _at_water(j: int, brain: BrainScript) -> void:
	"""At a bank or the ice's edge: a seat rechecks and begins the cycle (THE JETTY RECHECK, at the bank); a trap's
	collector just goes to it. Refused, it waits on the board with the reason and is checked again."""
	if tables.j_kind[j] != Tables.KIND_SEAT:
		_advance(j, brain)
		return
	var t: int = tables.j_trip[j]
	var why: String = begin_cycle(t, PackedInt32Array([skills.level_of(brain.index)]))
	if why.is_empty():
		_advance(j, brain)
		return
	_refused_at_water(t, j, why)


func _refused_at_water(t: int, _j: int, why: String) -> void:
	"""The recheck at the water refused: said once (until the reason changes), the crew stood down -- the gear back in
	the locker -- and the trip left on the board to be checked again (REQ-SET-052: the queued order is preserved)."""
	if tables.t_words[t] != why:
		tables.t_words[t] = why
		_note("%s waits: %s" % [trip_name(t), why], false)
	for seat: int in 2:
		var other: int = tables.t_seat_job[t * 2 + seat]
		if other >= 0 and tables.j_live[other] == 1:
			var who: int = tables.j_worker[other]
			_let_go(other)
			tables.j_wait_usec[other] = RECHECK_USEC
			if who != NONE and other != _driving:
				_free_worker(who)
	revision += 1


func _deliver(j: int, brain: BrainScript) -> void:
	"""A load put down at its store (decision 0361: only standing at the drop spot): what fits stored against its hold
	(farm_pantry.gd `store_upto_into`); the rest carried on to another store with room, or held while none has
	(decision 0222: the carrier waits for room until the player acts)."""
	var item: int = tables.j_load_item[j]
	var at: int = _read.value if pantry.hold_location_into(tables.j_hold[j], _read) else NONE
	var stored: int = 0
	if at != NONE and pantry.store_upto_into(item, tables.j_load_milli[j], at, tables.j_hold[j], _read):
		stored = _read.value
	_book_stored(item, stored)
	tables.j_load_milli[j] -= stored
	pantry.release(tables.j_hold[j])
	tables.j_hold[j] = NONE
	if tables.j_load_milli[j] <= 0:
		tables.j_load_item[j] = NONE
		_advance(j, brain)
		return
	tables.j_goal[j] = brain.surface_point()
	tables.j_hold[j] = _hold_for(item, tables.j_load_milli[j], brain.surface_point())
	if tables.j_hold[j] == NONE:
		tables.j_words[j] = "no store has room for %s — make room in the Pantry (K)" % Text.catch_text(tables.j_load_milli[j], item)
		tables.j_wait_usec[j] = Rules.RETRY_USEC
		return
	_begin_step(j, brain)


func _book_stored(item: int, milli: int) -> void:
	"""THE BOOKS: a catch, dried fish or flour put in a store."""
	if milli <= 0:
		return
	match Catalog.category_of(item):
		Catalog.CAT_FISH:
			landed_milli += milli
		Catalog.CAT_DRIED_FISH:
			dried_stored_milli += milli
		Catalog.CAT_FLOUR:
			milled_stored_milli += milli
		Catalog.CAT_DRIED_FRUIT, Catalog.CAT_RATION, Catalog.CAT_JAM, Catalog.CAT_CHEESE, Catalog.CAT_PICKLES:
			preserves_stored_milli += milli
	revision += 1


var dried_stored_milli: int = 0
var milled_stored_milli: int = 0


func _need_of(j: int) -> int:
	"""Milli-WU job `j`'s current work step takes."""
	match tables.j_kind[j]:
		Tables.KIND_SEAT:
			var method: int = tables.t_method[tables.j_trip[j]]
			@warning_ignore("integer_division") return Rules.METHOD_WORK_MWU[method] / Rules.METHOD_CREW[method]
		Tables.KIND_COLLECT:
			return Rules.TRAP_COLLECT_MWU
		Tables.KIND_DRY, Tables.KIND_BATCH:
			return Recipes.WORK_MWU[tables.j_recipe[j]]
		Tables.KIND_MILL:
			return Rules.MILL_WORK_MWU
		Tables.KIND_MAKE:
			return LockerScript.MAKE_MWU[tables.j_slot[j]]
		Tables.KIND_MEND:
			return LockerScript.MEND_MWU
	return Rules.HANDLE_MWU


# --- working ---------------------------------------------------------------------------------------

func _work_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""A worker at its work: standing at its place (decision 0361: rechecked every frame -- off it, it walks back and
	nothing is credited), facing the work, the clip playing. The work itself is credited in `update`."""
	if _on_ice(j):
		brain.water_place(ICE_HOLE, ICE_Y_M, brain.yaw)
	elif not brain.arrived_near(tables.j_goal[j], ARRIVE_M):
		tables.j_at[j] = 0
		tables.j_goal[j] = _free_spot(_goal_of(j), brain.index)
		tables.j_issued[j] = 1
		brain.task_walk_to(tables.j_goal[j])
		return
	tables.j_at[j] = 1
	brain.task_face(_face_of(j), delta)
	brain.task_play(CLIP_NET if tables.j_kind[j] <= Tables.KIND_COLLECT else CLIP_HANDLE)


func _face_of(j: int) -> Vector2:
	"""What a worker faces: the water at a bank, the rack, the mill, the workbench."""
	var t: int = tables.j_trip[j]
	if t >= 0:
		return _bank_water.get(tables.t_site[t], spot(&"locker")) if not _on_ice(j) else ICE_HOLE + Vector2(1.0, 0.0)
	match tables.j_kind[j]:
		Tables.KIND_DRY, Tables.KIND_TAKE_DOWN, Tables.KIND_BATCH:
			return STATION_FACES[_station_of_job(j)]
		Tables.KIND_MILL:
			return MILL_FACE
		Tables.KIND_MAKE:
			return WORKBENCH_FACE
	return spot(&"locker") + Vector2(1.0, 0.0)


func _credit_work(usec: int) -> void:
	"""Every worker standing at its work does §5.2's work for `usec` demo microseconds at its level (FISH for fishing,
	the base rate at the stations); fishing earns FISH XP (§5.3). A boat's crew works the trip's party total."""
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 0 or tables.j_at[j] == 0 or tables.j_worker[j] == NONE:
			continue
		var step: int = step_of(j)
		if step != S_WORK and step != S_STATION and step != S_AFLOAT:
			continue
		var fishing: bool = tables.j_kind[j] <= Tables.KIND_COLLECT
		var who: int = tables.j_worker[j]
		tables.j_num[j] += Rules.mwu_numerator(usec, skills.level_of(who) if fishing else 0)
		@warning_ignore("integer_division") var done: int = tables.j_num[j] / Rules.MWU_DENOMINATOR
		tables.j_num[j] -= done * Rules.MWU_DENOMINATOR
		if fishing:
			skills.add_work(who, done)
		_add_work(j, done)


func _add_work(j: int, mwu: int) -> void:
	"""Work done on job `j` (a boat seat's to its trip's party total); the step completes at its need."""
	if step_of(j) == S_AFLOAT:
		var t: int = tables.j_trip[j]
		tables.t_work_mwu[t] += mwu
		if tables.j_seat[j] == FleetScript.HELM and tables.t_work_mwu[t] >= Rules.METHOD_WORK_MWU[Rules.METHOD_BOAT]:
			_boat_catch(t)
		return
	tables.j_mwu[j] += mwu
	if tables.j_mwu[j] >= tables.j_need[j]:
		tables.j_at[j] = 0
		_work_done(j, brain_of(tables.j_worker[j]))


func _work_done(j: int, brain: BrainScript) -> void:
	"""A work step finished: the cycle completes (a net, the ice, a trap's collection), a trap is left to soak, or a
	station's batch moves on."""
	match tables.j_kind[j]:
		Tables.KIND_SEAT, Tables.KIND_COLLECT:
			_fishing_done(j)
		_:
			_station_done(j)
	if tables.j_live[j] == 1:
		_advance(j, brain)


func _fishing_done(j: int) -> void:
	"""A fishing work step done: a trap set (left to soak TRAP_SOAK_HOURS, its cycle open), else the cycle completed
	and the catch in this fisher's hands."""
	var t: int = tables.j_trip[j]
	if tables.j_kind[j] == Tables.KIND_SEAT and tables.t_method[t] == Rules.METHOD_TRAP:
		tables.t_state[t] = Tables.TRIP_SOAKING
		tables.t_soak_until[t] = now_tick() + Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
		tables.j_started[j] = 0
		_note("%s: the trap is set — collect it after %d hours" % [trip_name(t), Rules.TRAP_SOAK_HOURS], false)
		return
	if tables.j_kind[j] == Tables.KIND_COLLECT:
		tables.j_started[j] = 1
	if tables.t_called_off[t] == 1:
		return
	var level: int = skills.level_of(tables.j_worker[j])
	_take_load(j, tables.t_item[t], complete_cycle(t, PackedInt32Array([level])))


# --- the cycle: begun at the water, completed when the work is done ---------------------------------

func _claim_and_hold(t: int, cycle: Driver.Cycle, level: int) -> String:
	"""The rest of a cycle's opening, all or nothing: the gear's durability claimed by the cycle's Job, and room held for
	the expected catch at crew level `level`; refused, the cycle is cancelled and nothing is left claimed. "" when held."""
	var gear: int = tables.t_gear[t]
	var claimed: String = locker.claim(gear, cycle.job) if gear >= 0 else ""
	if not claimed.is_empty():
		driver.cancel_cycle(cycle)
		return "the gear store refused its claim (%s)" % claimed
	var expected: int = maxi(expected_catch(tables.t_method[t], tables.t_site[t], tables.t_species[t], level), 1)
	var hold: int = _hold_for(tables.t_item[t], expected, _water_point(t))
	if hold == NONE:
		if gear >= 0:
			locker.cancel(gear, cycle.job)
		driver.cancel_cycle(cycle)
		return "no store has room for %s" % Text.catch_text(expected, tables.t_item[t])
	tables.t_hold[t] = hold
	tables.t_expected[t] = expected
	return ""


func _catch_refused(t: int, error: String) -> void:
	"""The driver refused the catch: the cycle released (nothing taken, no wear), and the trip comes home rather than
	fishing again (a boat would otherwise row straight back out)."""
	_note("%s: the catch could not be taken (%s)" % [trip_name(t), error], true)
	_release_cycle(t)
	tables.t_called_off[t] = 1
	tables.t_state[t] = Tables.TRIP_RETURNING
	revision += 1


func entry_refusal(t: int) -> String:
	"""THE JETTY RECHECK (and the bank's, and the ice edge's): why trip `t` may not begin its cycle now, standing at the
	water ("" when it may) -- the water, the ice, the weather for a boat, and its own gear or boat still holding a
	cycle's wear."""
	refused_code = ""
	var method: int = tables.t_method[t]
	var why: String = _water_refusal(method, tables.t_site[t], tables.t_species[t])
	if not why.is_empty():
		return why
	var gear: int = tables.t_gear[t]
	if gear >= 0 and locker.durability_of(gear) < locker.wear_of_kind(locker.kind_of(gear)):
		return _refuse("GEAR_WORN", "its %s is worn below a cycle" % LockerScript.KIND_NAMES[locker.kind_of(gear)], "Mend gear")
	var boat: int = tables.t_boat[t]
	if boat >= 0 and not fleet.can_fish(boat):
		return _refuse("BOAT_WORN", "Rowboat %d is worn below a cycle" % (boat + 1), "Mend boat")
	return ""


func begin_cycle(t: int, levels: PackedInt32Array) -> String:
	"""Open trip `t`'s fishing cycle at the water (REQ-SET-044), after the recheck: the effort slots (fishing_driver.gd
	`begin_cycle`), the gear's durability claimed by the cycle's Job (gear.gd), and room held in a store for the
	expected catch at the crew's FISH (decision 0222). All or nothing: "" when begun, else why not (nothing taken)."""
	_replan(t, levels)
	var why: String = entry_refusal(t)
	if not why.is_empty():
		return why
	var cycle: Driver.Cycle = driver.begin_cycle(tables.t_site[t], tables.t_species[t], Rules.METHOD_GEAR[tables.t_method[t]])
	if not cycle.ok:
		return Text.driver_words(cycle.error, driver.species_key_of(tables.t_site[t], tables.t_species[t]))
	why = _claim_and_hold(t, cycle, SkillsScript.group_level(levels))
	if not why.is_empty():
		return why
	tables.t_cycle[t] = cycle
	_draw(t, cycle.expedition)
	tables.t_state[t] = Tables.TRIP_FISHING
	if tables.t_method[t] != Rules.METHOD_BOAT:
		_splash(ICE_HOLE if tables.t_method[t] == Rules.METHOD_ICE else _bank_water.get(tables.t_site[t], Vector2.ZERO))
	tables.t_words[t] = ""
	revision += 1
	return ""


func _water_point(t: int) -> Vector2:
	"""Where trip `t` lands its catch: the jetty, the ice's edge, or its bank."""
	match tables.t_method[t]:
		Rules.METHOD_BOAT:
			return spot(&"jetty")
		Rules.METHOD_ICE:
			return spot(&"ice_edge")
	return spot(Rules.SITE_BANK[tables.t_site[t]])


func complete_cycle(t: int, levels: PackedInt32Array) -> int:
	"""Complete trip `t`'s open cycle for a crew of these FISH levels (REQ-SET-045): the store's legal catch debited
	(fishing_driver.gd `complete_cycle`), §5.4's wear applied once (gear.gd, or the boat's row), the slots released.
	Returns the catch, milli-U (0: a true zero catch, no open cycle, or a refused one -- then the trip comes home)."""
	var cycle: Driver.Cycle = tables.t_cycle[t] as Driver.Cycle
	if cycle == null or not cycle.ok:
		_catch_refused(t, String(Driver.REFUSE_NOT_A_CYCLE))
		return 0
	var job: Vector2i = cycle.job
	var result: Driver.CatchResult = driver.complete_cycle(cycle, SkillsScript.group_level(levels))
	if not result.ok:
		_catch_refused(t, String(result.error))
		return 0
	if tables.t_gear[t] >= 0:
		locker.complete(tables.t_gear[t], job)
	if tables.t_boat[t] >= 0:
		fleet.wear(tables.t_boat[t])
	tables.t_cycle[t] = null
	tables.t_caught[t] = result.quantity_milli
	caught_milli += result.quantity_milli
	tables.t_state[t] = Tables.TRIP_LANDING
	_note("%s: caught %s" % [trip_name(t), Text.catch_text(result.quantity_milli, tables.t_item[t])], false)
	_roll(t, levels, result.quantity_milli)
	revision += 1
	return result.quantity_milli


func _replan(t: int, levels: PackedInt32Array) -> void:
	"""A BEST CATCH trip at the water: §5.4's auto pick again for this crew (REQ-SET-046's legal fallback), its catch's
	item following; kept as it is when nothing may be fished (the recheck then says why)."""
	if tables.t_auto[t] == 0 or driver == null:
		return
	var s: int = PlanScript.best_species(driver, tables.t_site[t], tables.t_method[t], SkillsScript.group_level(levels),
		_preview)
	if s == NONE or s == tables.t_species[t]:
		return
	tables.t_species[t] = s
	tables.t_item[t] = Rules.pantry_item_of(driver.species_row_of(tables.t_site[t], s))
	_note("%s: the best catch here now" % trip_name(t), false)


func _draw(t: int, expedition: Vector2i) -> void:
	"""The departing cycle's two FISHING draws (fishing_rolls.gd `draw_into`), kept on the trip: spent now, whether it
	completes or is called off (ARCH-RNG-002)."""
	if rolls.draw_into(expedition, _outcome):
		tables.t_hazard_roll[t] = _outcome.hazard_roll
		tables.t_rare_roll[t] = _outcome.rare_roll


func _roll(t: int, levels: PackedInt32Array, milli: int) -> void:
	"""A completed cycle's rolls resolved (fishing_rolls.gd `resolve_into`, on the draws taken at departure): the
	EXCELLENT share booked, the water's record kept, and a hazard said and given to the trip's first fisher -- a boat's
	helm -- through the infirmary."""
	var site: int = tables.t_site[t]
	var gear: int = Rules.METHOD_GEAR[tables.t_method[t]]
	steward.record(site, milli)
	if tables.t_hazard_roll[t] < 0:
		return
	_outcome.hazard_roll = tables.t_hazard_roll[t]
	_outcome.rare_roll = tables.t_rare_roll[t]
	tables.t_hazard_roll[t] = NONE
	rolls.resolve_into(gear, driver.danger_of_site(site), SkillsScript.group_level(levels), maxi(levels.size(), 1), milli,
		_outcome)
	tables.t_excellent[t] += _outcome.excellent_milli
	if _outcome.excellent_milli > 0:
		_note("%s: a fine catch — %s of it excellent" % [trip_name(t), Text.units(_outcome.excellent_milli)], false)
	if not _outcome.hurt:
		return
	_outcome.encounter = RollsScript.encounter_of(driver.habitat_type_of_site(site), SimClock.day_index_at(now_tick()))
	var j: int = tables.t_seat_job[t * 2]
	var who: int = tables.j_worker[j] if j >= 0 and tables.j_live[j] == 1 else NONE
	if who == NONE or not hurt.is_valid() \
			or not bool(hurt.call(who, _outcome.injury_kind, _outcome.injury_severity, _outcome.injury_loss)):
		return
	_note("%s: %s %s" % [trip_name(t), name_of(who),
		RollsScript.hazard_words(gear, _outcome.encounter)], true)


func _take_load(j: int, item: int, milli: int) -> void:
	"""Put `milli` of `item` in job `j`'s worker's hands, with the trip's held room (a second share gets its own)."""
	var t: int = tables.j_trip[j]
	if milli <= 0:
		if t >= 0 and tables.t_hold[t] >= 0:
			pantry.release(tables.t_hold[t])
			tables.t_hold[t] = NONE
		return
	tables.j_load_item[j] = item
	tables.j_load_milli[j] += milli
	if t >= 0 and tables.t_hold[t] >= 0:
		tables.j_hold[j] = tables.t_hold[t]
		tables.t_hold[t] = NONE
		pantry.resize_hold(tables.j_hold[j], milli)
	revision += 1


# --- the boat: the jetty, boarding, afloat, landing --------------------------------------------------

func _jetty_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""At the jetty's land end: wait for the crew (REQ-SET-052: no departure with a seat unstaffed); the helm, with its
	crew there, rechecks and begins the cycle, and both board."""
	brain.task_face(Routes.m_of(Routes.JETTY_END_U), delta)
	brain.task_play(CLIP_WAIT)
	var t: int = tables.j_trip[j]
	if tables.j_seat[j] != FleetScript.HELM or tables.j_wait_usec[j] > 0:
		return
	var mate: int = tables.t_seat_job[t * 2 + 1]
	if mate < 0 or tables.j_worker[mate] == NONE or step_of(mate) != S_JETTY or tables.j_at[mate] == 0:
		return
	if tables.t_called_off[t] == 1:
		return
	var levels := PackedInt32Array([skills.level_of(brain.index), skills.level_of(tables.j_worker[mate])])
	var why: String = begin_cycle(t, levels)
	if not why.is_empty():
		_refused_at_water(t, j, why)
		return
	_advance(mate, brain_of(tables.j_worker[mate]))
	_advance(j, brain)


func _board_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""Down the jetty to the boat's berth step, and into its seat: held on the water from the first plank
	(`water_hold`: the night and the board leave it be; MOVE-REQ-007)."""
	brain.water_hold = true
	var t: int = tables.j_trip[j]
	var boat: int = tables.t_boat[t]
	var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if tables.j_mwu[j] == 0 else fleet.seat_m(boat, tables.j_seat[j])
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M, delta):
		return
	if tables.j_mwu[j] == 0:
		tables.j_mwu[j] = 1
		return
	fleet.seat(boat, tables.j_seat[j], brain.index)
	_advance(j, brain)


func _deck_walk(brain: BrainScript, target: Vector2, y_m: float, delta: float) -> bool:
	"""A straight walk on a deck or the ice at its height (presentation: the planner never routes over water). True
	once there."""
	var to: Vector2 = target - brain.position
	if to.length() <= 0.05:
		brain.water_place(target, y_m, brain.yaw)
		brain.task_play(CLIP_WAIT)
		return true
	var yaw: float = atan2(to.x, to.y)
	brain.water_place(brain.position + to.normalized() * minf(DECK_WALK_M_S * delta, to.length()), y_m, yaw)
	brain.task_play(BrainScript.CLIP_WALK)
	return false


func _afloat_frame(j: int, brain: BrainScript, _delta: float) -> void:
	"""Aboard: in its seat wherever the boat is; the helm sets off once both are seated (a called-off trip does not);
	rowing, the helm pulls; on station both work the catch (credited in `update`); moored again, both step off."""
	var t: int = tables.j_trip[j]
	var boat: int = tables.t_boat[t]
	var seat: int = tables.j_seat[j]
	brain.water_place(fleet.seat_m(boat, seat), Routes.JETTY_DECK_Y_M - 0.1, fleet.yaw(boat))
	var on_station: bool = fleet.phase[boat] == FleetScript.PHASE_ON_STATION and tables.t_state[t] == Tables.TRIP_FISHING
	tables.j_at[j] = 1 if on_station else 0
	brain.task_play(CLIP_HANDLE if on_station else (CLIP_ROW if fleet.moving(boat) and seat == FleetScript.HELM else CLIP_WAIT))
	if fleet.phase[boat] != FleetScript.PHASE_MOORED:
		return
	if tables.t_state[t] == Tables.TRIP_LANDING or tables.t_called_off[t] == 1:
		tables.j_mwu[j] = 0
		_advance(j, brain)
	elif seat == FleetScript.HELM and _crew_aboard(boat, t) and fleet.set_off(boat):
		_splash(fleet.position_m(boat))


func _crew_aboard(boat: int, t: int) -> bool:
	"""Whether every seat of trip `t` is sat in."""
	for seat: int in Rules.METHOD_CREW[tables.t_method[t]]:
		if fleet.crew_of(boat, seat) == FleetScript.NOBODY:
			return false
	return true


func _alight_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""Out of the seat to the berth step, up the jetty to its land end; off the water there."""
	var t: int = tables.j_trip[j]
	var boat: int = tables.t_boat[t]
	if tables.j_mwu[j] == 0:
		fleet.seat(boat, tables.j_seat[j], FleetScript.NOBODY)
		tables.j_mwu[j] = 1
	var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if tables.j_mwu[j] == 1 else spot(&"jetty")
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M if tables.j_mwu[j] == 1 else 0.0, delta):
		return
	if tables.j_mwu[j] == 1:
		tables.j_mwu[j] = 2
		return
	brain.water_hold = false
	tables.j_goal[j] = spot(&"jetty")
	_advance(j, brain)


func _boat_catch(t: int) -> void:
	"""The boat's 120 party-WU are done on station: the cycle completes at the crew's group skill (§5.4: "floor(mean
	crew FISH levels)"), the catch is shared between the two to carry, and the boat turns for home."""
	var levels := PackedInt32Array()
	for seat: int in 2:
		var j: int = tables.t_seat_job[t * 2 + seat]
		if j >= 0 and tables.j_live[j] == 1 and tables.j_worker[j] != NONE:
			levels.append(skills.level_of(tables.j_worker[j]))
	var milli: int = complete_cycle(t, levels)
	@warning_ignore("integer_division") var first: int = (milli + 1) / 2
	_take_load(tables.t_seat_job[t * 2], tables.t_item[t], first)
	var second: int = tables.t_seat_job[t * 2 + 1]
	if second >= 0 and tables.j_live[second] == 1 and milli - first > 0:
		tables.j_load_item[second] = tables.t_item[t]
		tables.j_load_milli[second] = milli - first
		tables.j_hold[second] = _hold_for(tables.t_item[t], milli - first, spot(&"jetty"))
	var boat: int = tables.t_boat[t]
	fleet.cargo_item[boat] = tables.t_item[t]
	fleet.cargo_milli[boat] = milli
	fleet.row_back(boat)


func _row_boats(usec: int) -> void:
	"""The boats row on the demo clock; the crews' work on station is credited with everyone else's."""
	var arrived_mask: int = fleet.step(usec)
	_credit_work(usec)
	if arrived_mask != 0:
		revision += 1
	for boat: int in fleet.count:
		if arrived_mask & (1 << boat) and fleet.phase[boat] == FleetScript.PHASE_MOORED:
			fleet.cargo_item[boat] = FleetScript.NO_ITEM
			fleet.cargo_milli[boat] = 0


# --- the ice ---------------------------------------------------------------------------------------

func _ice_frame(j: int, brain: BrainScript, delta: float, target: Vector2) -> void:
	"""Out over the ice to the hole, or back to the edge, at the ice's height; held on the water while out (no swim,
	no rescue rank -- it walks). Thin ice under a walker calls the trip off at once (it walks straight back)."""
	brain.water_hold = true
	var back: bool = step_of(j) == S_ICE_BACK
	if not _deck_walk(brain, target, ICE_Y_M if not back or brain.position.distance_to(target) > 1.2 else 0.0, delta):
		return
	if back:
		brain.water_hold = false
		tables.j_goal[j] = spot(&"ice_edge")
	else:
		tables.j_goal[j] = ICE_HOLE
	_advance(j, brain)


# --- traps and the rack: what waits on the clock -----------------------------------------------------

func _follow_traps() -> void:
	"""A trap whose soak is done is put on the board to be collected (one collection per trap)."""
	for t: int in Tables.MAX_TRIPS:
		if tables.t_live[t] == 0 or tables.t_state[t] != Tables.TRIP_SOAKING or now_tick() < tables.t_soak_until[t]:
			continue
		if tables.t_collect_at[t] < 0:
			tables.t_collect_at[t] = _collect_tick(t)
		if now_tick() < tables.t_collect_at[t]:
			continue
		if _collect_of(t) == NONE:
			var j: int = tables.open_job(Tables.KIND_COLLECT, PROG_COLLECT, t)
			if j != NONE:
				tables.j_seat[j] = 0
				tables.t_seat_job[t * 2] = j
				revision += 1


func _collect_tick(t: int) -> int:
	"""When a trap that has just soaked is collected, worked out once (catch_plan.gd COLLECTION): now, or under the
	morning run the next 06:00 -- now when it is the morning already or its fish closes tomorrow."""
	var now: int = now_tick()
	if tables.t_collect[t] == PlanScript.COLLECT_SOAKED or driver == null:
		return now
	if PlanScript.in_morning(posmod(CalendarScript.hour_index_at(now), SimClock.HOURS_PER_DAY)):
		return now
	if PlanScript.closes_soon(driver.days_to_closure(tables.t_site[t], tables.t_species[t])):
		return now
	return PlanScript.next_morning_tick(now)


func _collect_of(t: int) -> int:
	"""Trip `t`'s collection job (NONE: none)."""
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_trip[j] == t and tables.j_kind[j] == Tables.KIND_COLLECT:
			return j
	return NONE


func _end_collect_of(t: int) -> void:
	"""A called-off trap: its collection nobody has taken, or whose collector has not yet lifted it, is closed (the trap
	lifted back to the locker); one carrying the lifted trap carries it back."""
	var j: int = _collect_of(t)
	if j == NONE:
		return
	if tables.j_worker[j] == NONE or tables.j_started[j] == 0:
		_end_job(j)
	else:
		_jump_to(j, S_GEAR_BACK)


func _follow_rack() -> void:
	"""A batch whose 12 h are up is cured (REQ-SET-093: its slot was taken, its worker long free): put on the board to
	be taken down -- a READY batch with every job row taken is put on as soon as a row is free."""
	for slot: int in tables.s_state.size():
		if tables.s_state[slot] == Tables.SLOT_CURING and now_tick() >= tables.s_ready_tick[slot]:
			tables.s_state[slot] = Tables.SLOT_READY
			revision += 1
		if tables.s_state[slot] != Tables.SLOT_READY:
			continue
		var j: int = tables.open_job(Tables.KIND_TAKE_DOWN, PROG_TAKE_DOWN, NONE)
		if j != NONE:
			tables.j_slot[j] = slot
			tables.j_recipe[j] = tables.s_recipe[slot]
			tables.s_state[slot] = Tables.SLOT_TAKING
			revision += 1


func _follow_safety() -> void:
	"""Ice gone thin under an ice trip still fishing calls it off (its walker comes straight back; one already landing
	its catch is ashore); ice forming on the pond calls off a boat, net or trap fishing or soaking there (the boat rows
	home; a soaking trap is lifted)."""
	for t: int in Tables.MAX_TRIPS:
		var out: bool = tables.t_state[t] == Tables.TRIP_FISHING or tables.t_state[t] == Tables.TRIP_SOAKING
		if tables.t_live[t] == 0 or tables.t_called_off[t] == 1 or not out:
			continue
		if tables.t_method[t] == Rules.METHOD_ICE and not ice.safe():
			call_off(t, "the ice is thinning — back to the bank")
		elif tables.t_method[t] != Rules.METHOD_ICE and tables.t_site[t] == Driver.SITE_POND and ice.frozen():
			call_off(t, "ice is forming on the pond — in to the bank")


# --- the stations: the rack, the mill, the workbench ----------------------------------------------------

func dry_refusal() -> String:
	"""Why a rack batch of fish may not be ordered now (`batch_refusal` of §5.7's `dry_fish`)."""
	return batch_refusal(Recipes.R_DRY_FISH)


func batch_refusal(recipe: int) -> String:
	"""Why a batch of `recipe` (preserve_rules.gd) may not be ordered now ("" when it may): a free rack slot for a passive
	row, each input's food nobody has reserved, the butt's water, room for what it makes (REQ-SET-112), a free job row."""
	refused_code = ""
	refused_fix = ""
	if not Recipes.is_recipe(recipe):
		return _refuse("NO_RECIPE", "there is no such recipe", "")
	if Recipes.is_passive(recipe) and free_slot(Recipes.STATION[recipe]) < 0:
		return _slots_full(Recipes.STATION[recipe])
	var short: String = _inputs_refusal(recipe)
	if not short.is_empty():
		return short
	var water: int = Recipes.WATER_MILLI[recipe]
	if water > 0 and (stores == null or stores.water_milli_u - water_held_milli() < water):
		return _refuse("NO_WATER", _water_words(water), "Pantry (K) ▸ Kitchen: Draw water")
	var item: int = Recipes.OUT_ITEM[recipe]
	if not pantry.location_for_item_into(item, Recipes.OUT_MILLI[recipe], _read):
		return _refuse("NO_ROOM", "no store has room for %s of %s" % [Text.units(Recipes.OUT_MILLI[recipe]),
			Catalog.ITEM_LABELS[item].to_lower()], "Pantry (K): make room")
	return _job_room_refusal()


func drink_stock_warning(recipe: int) -> String:
	"""THE DRINKS' STOCK WARNING (preserve_rules.gd DRINK_STOCK_WARN_MILLI, decision 1734): words when `recipe` makes a
	drink the stores already hold two feasts' worth of; "" otherwise. A warning only: the order is never refused."""
	if not Recipes.is_drink(recipe) or pantry == null:
		return ""
	var item: int = Recipes.OUT_ITEM[recipe]
	var held: int = pantry.milli_of(item)
	if held < Recipes.DRINK_STOCK_WARN_MILLI:
		return ""
	return "the stores already hold %s of %s, two feasts' worth (%s): more will wait for a feast to pour it" % [
		Text.units(held), Catalog.ITEM_LABELS[item].to_lower(), Text.units(Recipes.DRINK_STOCK_WARN_MILLI)]


func water_held_milli() -> int:
	"""THE BATCHES' WATER (decision 1737): what the butt holds for batches ordered but not yet started -- each live rack
	or station job's recipe water, until the work starts and takes it (or the job is cancelled). Computed from the jobs,
	so nothing can drift. Only the fishery's own orders see it: the kitchen and the feast draw on the butt by their own
	rules (the butt is the digging lane's tunnel_stores.gd, which keeps no reservations)."""
	var held: int = 0
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_started[j] == 0 and Recipes.is_recipe(tables.j_recipe[j]) \
				and (tables.j_kind[j] == Tables.KIND_DRY or tables.j_kind[j] == Tables.KIND_BATCH):
			held += Recipes.WATER_MILLI[tables.j_recipe[j]]
	return held


func _water_words(water: int) -> String:
	"""A batch's water refusal: what it needs, and what is set aside for batches already ordered."""
	var held: int = water_held_milli()
	if held <= 0:
		return "it needs %s of water in the butt" % Text.units(water)
	return "it needs %s of water in the butt, and %s of it is set aside for batches already ordered" % [
		Text.units(water), Text.units(held)]


func free_slot(station: int) -> int:
	"""The first empty passive slot of `station` (the rack's, the brewery's vats or the preserving table's crocks), NONE
	when every one is taken."""
	var first: int = Recipes.STATION_FIRST_SLOT[station]
	for slot: int in range(first, first + Recipes.STATION_SLOTS[station]):
		if tables.s_state[slot] == Tables.SLOT_EMPTY:
			return slot
	return NONE


func _slots_full(station: int) -> String:
	"""Every passive slot of `station` taken, in words."""
	if station == Recipes.STATION_BREWERY:
		return _refuse("VATS_FULL", "all %d vats are brewing" % Recipes.VAT_SLOTS, "wait for a batch to be drawn off")
	if station == Recipes.STATION_TABLE:
		return _refuse("CROCKS_FULL", "all %d crocks are in use" % Recipes.CROCK_SLOTS, "wait for one to be emptied")
	return _refuse("RACK_FULL", "all %d rack slots are taken" % Rules.RACK_SLOTS, "wait for a batch to cure")


func bind_spare_fish(spare: Callable, give: Callable) -> void:
	"""The kitchen's fish beyond its next meal, and its giving back (kitchen.gd FISH FOR THE RACK, decision 1739)."""
	spare_fish = spare
	free_spare_fish = give


func input_available_milli(input: int) -> int:
	"""What a batch may take of recipe input `input`: the food nobody has set aside, and for fish also what the kitchen
	holds for meals beyond its next one (decision 1739)."""
	var category: int = Recipes.IN_CATEGORY[input]
	var free: int = takes.free_milli_of_crop(pantry, category)
	return free + (int(spare_fish.call()) if category == Catalog.CAT_FISH and spare_fish.is_valid() else 0)


func _take_spare_fish(recipe: int) -> bool:
	"""Before a batch sets its food aside: the fish it lacks beyond the free fish, given back by the kitchen's meals
	beyond the next (decision 1739). False -- and the batch refused NO_FISH -- when the fish is still short after."""
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		if Recipes.IN_CATEGORY[input] != Catalog.CAT_FISH or not free_spare_fish.is_valid():
			continue
		var short: int = Recipes.IN_MILLI[input] - takes.free_milli_of_crop(pantry, Catalog.CAT_FISH)
		if short > 0:
			free_spare_fish.call(short)
		if takes.free_milli_of_crop(pantry, Catalog.CAT_FISH) < Recipes.IN_MILLI[input]:
			_refuse(Recipes.IN_CODE[input], "the kitchen could not give the fish it held beyond its next meal",
				Recipes.IN_FIX[input])
			return false
	return true


func _inputs_refusal(recipe: int) -> String:
	"""The first of `recipe`'s inputs the stores lack, nobody's reservation counted -- for fish, the kitchen's beyond its
	next meal counted as there (decision 1739) -- ("" when all are there)."""
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		var free: int = input_available_milli(input)
		if free < Recipes.IN_MILLI[input]:
			var whose: String = " or the kitchen holds beyond its next meal" if Recipes.IN_CATEGORY[input] == Catalog.CAT_FISH \
				and spare_fish.is_valid() else ""
			return _refuse(Recipes.IN_CODE[input], "the stores hold %s of %s nobody has set aside%s; a batch takes %s" % [
				Text.units(free), Recipes.category_words(Recipes.IN_CATEGORY[input]), whose,
				Text.units(Recipes.IN_MILLI[input])], Recipes.IN_FIX[input])
	return ""


func _job_room_refusal() -> String:
	"""A free job row."""
	if tables.job_count() >= Tables.MAX_JOBS:
		return _refuse("JOBS", "the fishery's job list is full", "wait for a job to finish")
	return ""


func order_dry(members: PackedInt32Array) -> String:
	"""Hang a batch of fresh fish on the rack (§5.7 `dry_fish`: `order_batch`)."""
	return order_batch(Recipes.R_DRY_FISH, members)


func order_batch(recipe: int, members: PackedInt32Array) -> String:
	"""A batch of `recipe`: each input's food that spoils first set aside in the pantry (the kitchen's takes, so nobody
	else counts it), room held for what it makes; a passive row takes a rack slot (its room held by the slot); the job on
	the board, the selected first. "" when ordered."""
	var why: String = batch_refusal(recipe)
	if not why.is_empty():
		return why
	if not _take_spare_fish(recipe):
		return "the kitchen could not give the fish it held beyond its next meal"
	var passive: bool = Recipes.is_passive(recipe)
	var j: int = tables.open_job(Tables.KIND_DRY if passive else Tables.KIND_BATCH, PROG_DRY if passive else PROG_MILL,
		NONE)
	tables.j_recipe[j] = recipe
	tables.j_goal[j] = _pickup_point(Recipes.IN_CATEGORY[Recipes.IN_FIRST[recipe]])
	tables.j_take[j] = takes.new_take()
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		takes.reserve_into(pantry, tables.j_take[j], Recipes.IN_CATEGORY[input], Recipes.IN_MILLI[input], _hour_seen, _read)
	var hold: int = _hold_for(Recipes.OUT_ITEM[recipe], Recipes.OUT_MILLI[recipe], _station_spot(j))
	if passive:
		var slot: int = free_slot(Recipes.STATION[recipe])
		tables.j_slot[j] = slot
		tables.s_state[slot] = Tables.SLOT_LOADING
		tables.s_hold[slot] = hold
		tables.s_recipe[slot] = recipe
	else:
		tables.j_hold[j] = hold
	_assign_station(j, members)
	revision += 1
	return ""


func _pickup_point(category: int) -> Vector2:
	"""Where the unreserved food of selector `category` (a category, or an item mask) that spoils first is kept (the store
	a fetch walks to)."""
	var best: int = NONE
	for lot: int in PantryScript.MAX_LOTS:
		var item: int = pantry.lot_item(lot)
		if item == PantryScript.FREE or not TakesScript.matches(category, item) or takes.free_milli(pantry, lot) <= 0:
			continue
		if best == NONE or pantry.lot_spoil_hours(lot, _hour_seen) < pantry.lot_spoil_hours(best, _hour_seen):
			best = lot
	return pantry.storage.position_of(pantry.lot_location(best)) if best != NONE else spot(&"locker")


func mill_refusal() -> String:
	"""Why a mill batch may not be ordered now ("" when it may): a free mill slot (§5.9: 2), 3 U of grain nobody has
	reserved (the kitchen's porridge reserves its own), room for the 3 U of flour, a free job row."""
	refused_code = ""
	refused_fix = ""
	if _jobs_of_kind(Tables.KIND_MILL) >= Rules.MILL_SLOTS:
		return _refuse("MILL_BUSY", "both mill slots are grinding", "wait for a batch to finish")
	var grain: int = takes.free_milli_of_crop(pantry, FarmingScript.CROP_GRAIN)
	if grain < Rules.MILL_IN_MILLI:
		return _refuse("NO_GRAIN", "the stores hold %s of grain nobody has set aside; a batch takes %s" % [Text.units(grain),
			Text.units(Rules.MILL_IN_MILLI)], "Farm ▸ Harvest wheat, barley or oats")
	if not pantry.location_for_item_into(Catalog.ITEM_FLOUR, Rules.MILL_OUT_MILLI, _read):
		return _refuse("NO_ROOM", "no store has room for %s of flour" % Text.units(Rules.MILL_OUT_MILLI), "Pantry (K): make room")
	return _job_room_refusal()


func order_mill(members: PackedInt32Array) -> String:
	"""Grind a batch of grain at the mill (§5.7 `flour`: grain 3 -> flour 3, 12 WU): the grain that spoils first set
	aside, room held for the flour (REQ-SET-112, as the rack's), the job on the board. "" when ordered."""
	var why: String = mill_refusal()
	if not why.is_empty():
		return why
	var j: int = tables.open_job(Tables.KIND_MILL, PROG_MILL, NONE)
	tables.j_goal[j] = _pickup_point(FarmingScript.CROP_GRAIN)
	tables.j_take[j] = takes.new_take()
	takes.reserve_into(pantry, tables.j_take[j], FarmingScript.CROP_GRAIN, Rules.MILL_IN_MILLI, _hour_seen, _read)
	tables.j_hold[j] = _hold_for(Catalog.ITEM_FLOUR, Rules.MILL_OUT_MILLI, spot(&"mill"))
	_assign_station(j, members)
	revision += 1
	return ""


func _jobs_of_kind(kind: int) -> int:
	"""Live jobs of `kind`."""
	var n: int = 0
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_kind[j] == kind:
			n += 1
	return n


func make_refusal(kind: int) -> String:
	"""Why a piece of gear may not be made now ("" when it may): its wood in the stores and its rope or iron in the
	locker (gear_locker.gd's recipes), a free job row."""
	refused_code = ""
	refused_fix = ""
	if kind < 0 or kind >= LockerScript.KIND_OUTFIT:
		return _refuse("NOT_MADE_HERE", "winter outfits are made from cloth at a workshop", "")
	var wood: int = LockerScript.MAKE_WOOD_MILLI[kind]
	if stores == null or stores.wood_milli_u < wood:
		return _refuse("NO_WOOD", "it needs %s wood; the stores hold %s" % [Text.units(wood), Text.units(stores.wood_milli_u if stores != null else 0)],
			"Woods ▸ Haul logs")
	var mat: int = LockerScript.MAKE_MATERIAL[kind]
	if locker.material_milli(mat) < LockerScript.MAKE_MATERIAL_MILLI[kind]:
		return _refuse("NO_" + LockerScript.MAT_KEYS[mat].to_upper(), "it needs %s %s; the locker holds %s (the village makes none)" % [
			Text.units(LockerScript.MAKE_MATERIAL_MILLI[kind]), LockerScript.MAT_NAMES[mat], Text.units(locker.material_milli(mat))], "")
	return _job_room_refusal()


func order_make(kind: int, members: PackedInt32Array) -> String:
	"""Make a piece of gear at the workbench, paid when the work starts there. "" when ordered."""
	var why: String = make_refusal(kind)
	if not why.is_empty():
		return why
	var j: int = tables.open_job(Tables.KIND_MAKE, PROG_MAKE, NONE)
	tables.j_slot[j] = kind
	_assign_station(j, members)
	revision += 1
	return ""


func mend_refusal(target: int) -> String:
	"""Why gear (a locker index) or a boat (BOAT_SLOT + boat) may not be mended now: worn, free, and wood 1 + rope 0.25
	to hand (gear.gd's repair recipe)."""
	refused_code = ""
	refused_fix = ""
	if target < 0:
		return _refuse("NOTHING_WORN", "nothing is worn", "")
	if target >= BOAT_SLOT and not fleet.is_free(target - BOAT_SLOT):
		return _refuse("BOAT_OUT", "that boat is out", "wait for it to come back")
	if target < BOAT_SLOT and not locker.is_free(target):
		return _refuse("GEAR_OUT", "that gear is out on a trip", "wait for it to come back")
	if stores == null or stores.wood_milli_u < LockerScript.MEND_WOOD_MILLI:
		return _refuse("NO_WOOD", "mending takes %s wood" % Text.units(LockerScript.MEND_WOOD_MILLI), "Woods ▸ Haul logs")
	if locker.material_milli(LockerScript.MAT_ROPE) < LockerScript.MEND_ROPE_MILLI:
		return _refuse("NO_ROPE", "mending takes %s rope; the locker holds %s" % [Text.units(LockerScript.MEND_ROPE_MILLI),
			Text.units(locker.material_milli(LockerScript.MAT_ROPE))], "")
	return _job_room_refusal()


func worst_to_mend() -> int:
	"""What Mend would mend: a free boat too worn to set out first (its BOAT_WORN refusal says "Mend"), else the most worn
	free gear, else the most worn free boat (BOAT_SLOT + boat); -1: nothing."""
	for boat: int in fleet.count:
		if fleet.is_free(boat) and not fleet.can_fish(boat):
			return BOAT_SLOT + boat
	if locker.most_worn_into(_read):
		return _read.value
	var best: int = -1
	for boat: int in fleet.count:
		if fleet.is_free(boat) and fleet.durability[boat] < FleetScript.DURABILITY_CAP \
				and (best < 0 or fleet.durability[boat] < fleet.durability[best - BOAT_SLOT]):
			best = BOAT_SLOT + boat
	return best


func order_mend(target: int, members: PackedInt32Array) -> String:
	"""Mend `target` (see `worst_to_mend`): 200 points per 30 WU, paid when the work starts. "" when ordered."""
	var why: String = mend_refusal(target)
	if not why.is_empty():
		return why
	var j: int = tables.open_job(Tables.KIND_MEND, PROG_MEND, NONE)
	tables.j_slot[j] = target
	if target < BOAT_SLOT:
		locker.earmark(target, tables.j_serial[j])
	else:
		fleet.take(target - BOAT_SLOT, tables.j_serial[j])
	_assign_station(j, members)
	revision += 1
	return ""


func _assign_station(j: int, members: PackedInt32Array) -> void:
	"""Give a station job to the first selected resident who may take it."""
	for who: int in members:
		if eligibility(j, who).is_empty() and claim(j, who):
			return


## A made piece of gear in hand (its load item: not a pantry item).
const GEAR_LOAD: int = -2


func _at_station(j: int, brain: BrainScript) -> void:
	"""At the rack or the mill a batch starts (REQ-SET-118: its inputs leave the pantry now, all or nothing, from the
	lots set aside); at the locker or the jetty a mending is paid; a take-down just starts."""
	match tables.j_kind[j]:
		Tables.KIND_DRY, Tables.KIND_BATCH:
			_start_recipe(j, brain)
		Tables.KIND_MILL:
			_start_batch(j, brain, Rules.MILL_IN_MILLI)
		Tables.KIND_MEND:
			_pay_and_start(j, brain)
		_:
			_advance(j, brain)


func _start_batch(j: int, brain: BrainScript, milli: int) -> void:
	"""Withdraw a batch's food from its take (ingredient_takes.gd `consume_into`): the books move into the batch. Short
	(a lot spoiled while it was set aside), the batch is given up and says so."""
	if not takes.consume_into(pantry, tables.j_take[j], milli, TakesScript.AT_STORE, _hour_seen, _read):
		_note("The %s set aside spoiled before it reached the %s: the batch is given up" % [
			"fish" if tables.j_kind[j] == Tables.KIND_DRY else "grain", "rack" if tables.j_kind[j] == Tables.KIND_DRY else "mill"], true)
		cancel_station_job(j)
		return
	takes.release(tables.j_take[j])
	tables.j_take[j] = 0
	tables.j_started[j] = 1
	if tables.j_kind[j] == Tables.KIND_DRY:
		dried_in_milli += milli
	else:
		milled_in_milli += milli
	_advance(j, brain)


func _start_recipe(j: int, brain: BrainScript) -> void:
	"""A recipe's batch starts at its station (REQ-SET-118): every input withdrawn from the job's take, all or nothing,
	and its water from the butt. Short (a lot spoiled while set aside, the butt drawn down), it is given up and says so."""
	var recipe: int = tables.j_recipe[j]
	var water: int = Recipes.WATER_MILLI[recipe]
	if not _take_holds_inputs(j, recipe) or (water > 0 and (stores == null or stores.water_milli_u < water)):
		_note("The food or water set aside for %s ran short before the work began: the batch is given up" %
			Recipes.JOB_WORDS[recipe].to_lower(), true)
		cancel_station_job(j)
		return
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		if not takes.consume_into(pantry, tables.j_take[j], Recipes.IN_MILLI[input], TakesScript.AT_STORE, _hour_seen,
				_read, Recipes.IN_CATEGORY[input]):
			push_error("fishery: %s's %s was checked and then refused" % [Recipes.GDD_ROW[recipe], input])
	if water > 0:
		stores.take_water(water)
	takes.release(tables.j_take[j])
	tables.j_take[j] = 0
	tables.j_started[j] = 1
	batch_in_milli[recipe] += Recipes.food_in_milli(recipe)
	if recipe == Recipes.R_DRY_FISH:
		dried_in_milli += Recipes.food_in_milli(recipe)
	_advance(j, brain)


func _take_holds_inputs(j: int, recipe: int) -> bool:
	"""Whether job `j`'s take still holds every input of `recipe`: its entries first trimmed to what their lots still hold
	(a lot that spoiled, or was drawn down by anything outside the takes, counts only what is left), so the withdrawal
	that follows can take every input, all or nothing (kitchen.gd's own check before a batch)."""
	takes.trim_to_lots(pantry, tables.j_take[j], TakesScript.AT_STORE)
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		if takes.live_milli(pantry, tables.j_take[j], TakesScript.AT_STORE, Recipes.IN_CATEGORY[input]) < Recipes.IN_MILLI[input]:
			return false
	return true


func _pay_and_start(j: int, brain: BrainScript) -> void:
	"""Make or mend: its wood from the stores and its rope or iron from the locker, all or nothing, as the work starts
	(the card checked them; the stores may have changed). Short, the job is given up and says so."""
	var wood: int = LockerScript.MEND_WOOD_MILLI
	var mat: int = LockerScript.MAT_ROPE
	var mat_milli: int = LockerScript.MEND_ROPE_MILLI
	if tables.j_kind[j] == Tables.KIND_MAKE:
		wood = LockerScript.MAKE_WOOD_MILLI[tables.j_slot[j]]
		mat = LockerScript.MAKE_MATERIAL[tables.j_slot[j]]
		mat_milli = LockerScript.MAKE_MATERIAL_MILLI[tables.j_slot[j]]
	if stores.wood_milli_u < wood or locker.material_milli(mat) < mat_milli:
		_note("%s: the wood or %s ran short — given up" % [KIND_LABELS[tables.j_kind[j]], LockerScript.MAT_NAMES[mat]], true)
		cancel_station_job(j)
		return
	stores.take_wood(wood)
	locker.take_material(mat, mat_milli)
	tables.j_started[j] = 1
	_advance(j, brain)


const KIND_LABELS: Array[String] = ["Fishing", "Collecting the trap", "Drying fish", "Taking down dried fish",
	"Milling", "Making gear", "Mending", "Packing rations"]


func _station_done(j: int) -> void:
	"""A station's work done: a rack batch hung to cure 12 h; a cured batch, flour or new gear in hand; gear or a boat
	mended."""
	match tables.j_kind[j]:
		Tables.KIND_DRY:
			var slot: int = tables.j_slot[j]
			tables.s_state[slot] = Tables.SLOT_CURING
			tables.s_ready_tick[slot] = now_tick() + Recipes.PASSIVE_HOURS[tables.j_recipe[j]] * SimClock.TICKS_PER_HOUR
			tables.j_started[j] = 0
		Tables.KIND_BATCH:
			_batch_made(j)
		Tables.KIND_TAKE_DOWN:
			_take_down(j)
		Tables.KIND_MILL:
			milled_out_milli += Rules.MILL_OUT_MILLI
			tables.j_load_item[j] = Catalog.ITEM_FLOUR
			tables.j_load_milli[j] = Rules.MILL_OUT_MILLI
			tables.j_started[j] = 0
		Tables.KIND_MAKE:
			tables.j_load_item[j] = GEAR_LOAD
			tables.j_load_milli[j] = LockerScript.LOT_MILLI
			tables.j_started[j] = 0
		Tables.KIND_MEND:
			_mended(j)
	revision += 1


func _take_down(j: int) -> void:
	"""A cured batch off the rack: its row's output (§5.7: 3 U of dried fish or of dried fruit) in hand, with the room
	held for it when it was hung."""
	var slot: int = tables.j_slot[j]
	var recipe: int = tables.s_recipe[slot]
	_made(j, recipe)
	tables.j_hold[j] = tables.s_hold[slot]
	tables.s_hold[slot] = NONE
	tables.s_state[slot] = Tables.SLOT_EMPTY
	_note("A batch of %s is done at %s: %s" % [Catalog.ITEM_LABELS[Recipes.OUT_ITEM[recipe]].to_lower(),
		Recipes.STATION_NAMES[Recipes.STATION[recipe]], Text.units(Recipes.OUT_MILLI[recipe])], false)


func _batch_made(j: int) -> void:
	"""A batch without a passive wait done at its station: its output in hand, to the room held at the order."""
	_made(j, tables.j_recipe[j])
	tables.j_started[j] = 0


func _made(j: int, recipe: int) -> void:
	"""`recipe`'s output in job `j`'s worker's hands, booked."""
	tables.j_load_item[j] = Recipes.OUT_ITEM[recipe]
	tables.j_load_milli[j] = Recipes.OUT_MILLI[recipe]
	batch_out_milli[recipe] += Recipes.OUT_MILLI[recipe]
	if recipe == Recipes.R_DRY_FISH:
		dried_out_milli += Recipes.OUT_MILLI[recipe]


func _mended(j: int) -> void:
	"""Gear or a boat mended by 200 points (clamped at the cap), and given back."""
	var target: int = tables.j_slot[j]
	tables.j_started[j] = 0
	if target >= BOAT_SLOT:
		fleet.mend(target - BOAT_SLOT, LockerScript.MEND_POINTS)
		fleet.give_back(target - BOAT_SLOT, tables.j_serial[j])
		return
	locker.mend(target)
	locker.release(target, tables.j_serial[j])


func cancel_station_job(j: int) -> String:
	"""Cancel a station job: "" when cancelled, else why not. A load in hand is delivered (decision 0222); a batch
	whose food was withdrawn yields half of it as spoiled food (REQ-SET-094); materials paid for gear not yet made go
	back (no hidden loss); a cured batch is always taken down."""
	if tables.j_load_milli[j] > 0:
		return "it is carrying the load — it finishes the delivery first"
	if tables.j_kind[j] == Tables.KIND_TAKE_DOWN:
		return "a cured batch is always taken down"
	_unwind_station(j)
	_end_job(j)
	return ""


func _unwind_station(j: int) -> void:
	"""What a cancelled station job gives back: its take, its slot and held room, half a started batch as spoiled food,
	paid materials, a set-aside piece or boat."""
	var kind: int = tables.j_kind[j]
	if kind == Tables.KIND_DRY:
		var slot: int = tables.j_slot[j]
		tables.s_state[slot] = Tables.SLOT_EMPTY
		pantry.release(tables.s_hold[slot])
		tables.s_hold[slot] = NONE
	if (kind == Tables.KIND_DRY or kind == Tables.KIND_MILL or kind == Tables.KIND_BATCH) and tables.j_started[j] == 1:
		var food: int = Rules.MILL_IN_MILLI if kind == Tables.KIND_MILL else Recipes.food_in_milli(tables.j_recipe[j])
		@warning_ignore("integer_division") var spoil: int = food * Rules.CANCEL_SPOIL_PERMILLE / 1000
		pantry.spoiled_milli += spoil
		spoiled_by_cancel_milli += spoil
	if (kind == Tables.KIND_MAKE or kind == Tables.KIND_MEND) and tables.j_started[j] == 1:
		_refund(j)
	if kind == Tables.KIND_MEND:
		var target: int = tables.j_slot[j]
		if target >= BOAT_SLOT:
			fleet.give_back(target - BOAT_SLOT, tables.j_serial[j])
		else:
			locker.release(target, tables.j_serial[j])


func _refund(j: int) -> void:
	"""Give back the wood and rope or iron paid for gear not made or mended."""
	if tables.j_kind[j] == Tables.KIND_MAKE:
		stores.add_wood(LockerScript.MAKE_WOOD_MILLI[tables.j_slot[j]])
		locker.add_material(LockerScript.MAKE_MATERIAL[tables.j_slot[j]], LockerScript.MAKE_MATERIAL_MILLI[tables.j_slot[j]])
		return
	stores.add_wood(LockerScript.MEND_WOOD_MILLI)
	locker.add_material(LockerScript.MAT_ROPE, LockerScript.MEND_ROPE_MILLI)


# --- words ---------------------------------------------------------------------------------------

func trip_name(t: int) -> String:
	"""'The pond boat trip (perch)'."""
	var species: StringName = driver.species_key_of(tables.t_site[t], tables.t_species[t]) if driver != null else &"fish"
	return "The %s %s trip (%s)" % [Rules.SITE_NAMES[tables.t_site[t]].trim_prefix("the "),
		Rules.METHOD_SHORT[tables.t_method[t]], Text.species_label(species)]


func place_words(j: int) -> String:
	"""Where job `j`'s current step is, in words."""
	match step_of(j):
		S_TO_LOCKER, S_GEAR_BACK:
			return "the gear locker"
		S_TO_BANK, S_WORK:
			return "the bank at %s" % Rules.SITE_NAMES[tables.t_site[tables.j_trip[j]]] if tables.j_trip[j] >= 0 else "its work"
		S_TO_JETTY, S_JETTY:
			return Routes.JETTY_NAME
		S_TO_EDGE, S_ICE_BACK:
			return "the pond's edge"
		S_TO_STORE:
			return "the stores"
		S_TO_PICKUP:
			return "the food set aside"
		S_TO_WORKBENCH:
			return "the workbench"
	if Recipes.is_recipe(tables.j_recipe[j]):
		return Recipes.STATION_NAMES[Recipes.STATION[tables.j_recipe[j]]]
	return ["", "", "the rack", "the rack", "the mill", "the workbench", "the gear locker"][tables.j_kind[j]]


func doing_text(j: int, serial: int) -> String:
	"""What the worker of job `j` is doing, for the party panel and the roster."""
	if not tables.is_job(j, serial):
		return ""
	var step: int = step_of(j)
	match step:
		S_WORK:
			return "%s at %s" % [job_label(j), place_words(j)]
		S_STATION:
			return "%s at %s" % [job_label(j), place_words(j)]
		S_JETTY:
			return "waiting at the jetty for the crew"
		S_BOARD:
			return "boarding the boat"
		S_AFLOAT:
			return "out in the boat: %s" % FleetScript.PHASE_WORDS[fleet.phase[tables.t_boat[tables.j_trip[j]]]]
		S_ALIGHT:
			return "landing the boat"
		S_ICE_OUT, S_ICE_BACK:
			return "walking on the ice"
		S_TO_STORE:
			return "carrying %s to the stores" % Text.catch_text(tables.j_load_milli[j], tables.j_load_item[j])
	return "%s: going to %s" % [job_label(j), place_words(j)]


func job_label(j: int) -> String:
	"""What job `j`'s worker is doing, in words: a recipe row's own ("Drying fruit"), else its kind's."""
	var recipe: int = tables.j_recipe[j]
	if not Recipes.is_recipe(recipe):
		return KIND_LABELS[tables.j_kind[j]]
	return Recipes.TAKE_DOWN_DOING[recipe] if tables.j_kind[j] == Tables.KIND_TAKE_DOWN else Recipes.DOING_WORDS[recipe]


func job_words(j: int) -> String:
	"""Job `j` on the Work screen: a recipe row's own ("Dry fruit"), else its kind's (fishery_tables.gd KIND_WORDS)."""
	var recipe: int = tables.j_recipe[j]
	if not Recipes.is_recipe(recipe):
		return Tables.KIND_WORDS[tables.j_kind[j]]
	return Recipes.TAKE_DOWN_WORDS[recipe] if tables.j_kind[j] == Tables.KIND_TAKE_DOWN else Recipes.JOB_WORDS[recipe]


# --- the board's commands (work/fishery_work.gd) ----------------------------------------------------

func hold_refusal(j: int) -> String:
	"""Why job `j`'s worker may not be stopped or swapped now ("" when it may): a load in hand is delivered (decision
	0222), and one out on the water or the ice comes back first (MOVE-REQ-007)."""
	var who: int = tables.j_worker[j]
	if who == NONE:
		return ""
	if tables.j_load_milli[j] > 0 and not tables.j_load_at[j].is_finite():
		return "%s is carrying the load — it finishes the delivery first" % name_of(who)
	if brain_of(who).water_hold:
		return "%s is out on the water — it comes back first" % name_of(who)
	return ""


func pause_job(j: int, on: bool) -> String:
	"""Pause job `j` (its worker stood down, the job kept) or resume it: "" when done, else why not."""
	if not on:
		tables.j_paused[j] = 0
		revision += 1
		return ""
	if tables.j_paused[j] == 1:
		return "it is paused already"
	var why: String = hold_refusal(j)
	if not why.is_empty():
		return why
	var who: int = tables.j_worker[j]
	_let_go(j)
	tables.j_paused[j] = 1
	if who != NONE:
		_free_worker(who)
	return ""


func reassign_job(j: int, who: int) -> String:
	"""Give job `j` to `who` instead: "" when done, else why not."""
	var why: String = hold_refusal(j)
	if why.is_empty():
		why = eligibility(j, who)
	if not why.is_empty():
		return why
	var was: int = tables.j_worker[j]
	if was != NONE:
		_let_go(j)
		_free_worker(was)
	tables.j_paused[j] = 0
	tables.j_wait_usec[j] = 0
	return "" if claim(j, who) else "it could not be handed over"


func cancel_job(j: int) -> String:
	"""Cancel job `j`: its trip called off, or its station order cancelled. "" when done, else why not."""
	if tables.j_trip[j] >= 0:
		return cancel_trip(tables.j_trip[j])
	return cancel_station_job(j)


func remaining_usec(j: int) -> int:
	"""Demo microseconds of work job `j`'s current work step has left at its worker's level (-1: not working)."""
	var step: int = step_of(j)
	if step != S_WORK and step != S_STATION:
		return -1
	var level: int = skills.level_of(tables.j_worker[j]) if tables.j_worker[j] != NONE else 0
	return Rules.work_usec(maxi(tables.j_need[j] - tables.j_mwu[j], 0), level)


func is_walking(j: int) -> bool:
	"""Whether job `j`'s worker is on a planner walk."""
	return WALK_STEPS.has(step_of(j))


# --- what the view draws (fishery_view.gd; read-only) -------------------------------------------------

const GEAR_PROPS: Array[StringName] = [&"fishing_net", &"eel_trap", &"fishing_rod", &""]


func held_key_of(who: int) -> StringName:
	"""The model `who` carries for the fishery (&"": nothing): its load (a basket of fish, a sack of flour, new gear),
	its trip's gear on the way to or from the water, or a batch's food on the way to the rack or the mill."""
	var j: int = tables.job_of_worker(who)
	return held_key_of_job(j) if j != NONE else &""


func held_key_of_job(j: int) -> StringName:
	"""The model job `j`'s worker carries (`held_key_of`, by job: the view walks the job rows once a frame)."""
	if tables.j_load_milli[j] > 0 and not tables.j_load_at[j].is_finite():
		if tables.j_load_item[j] == GEAR_LOAD:
			return GEAR_PROPS[tables.j_slot[j]]
		return &"sack_pile" if tables.j_load_item[j] == Catalog.ITEM_FLOUR else &"basket"
	var step: int = step_of(j)
	if tables.j_started[j] == 1 and tables.j_kind[j] <= Tables.KIND_COLLECT and step != S_WORK:
		var t: int = tables.j_trip[j]
		return GEAR_PROPS[GEAR_OF_METHOD[tables.t_method[t]]] if t >= 0 and tables.t_gear[t] >= 0 else &""
	if step == S_TO_STATION and (tables.j_kind[j] == Tables.KIND_DRY or tables.j_kind[j] == Tables.KIND_MILL
			or tables.j_kind[j] == Tables.KIND_BATCH):
		return &"sack_pile" if tables.j_kind[j] == Tables.KIND_MILL else &"basket"
	return &""


func gear_in_water_at(site: int) -> StringName:
	"""The gear lying in the water at a site's bank (&"": none): a net being worked, a trap soaking or being lifted."""
	for t: int in Tables.MAX_TRIPS:
		if tables.t_live[t] == 0 or tables.t_site[t] != site:
			continue
		var method: int = tables.t_method[t]
		if method == Rules.METHOD_TRAP and tables.t_state[t] == Tables.TRIP_SOAKING:
			return GEAR_PROPS[LockerScript.KIND_TRAP]
		if method == Rules.METHOD_NET and tables.t_state[t] == Tables.TRIP_FISHING:
			return GEAR_PROPS[LockerScript.KIND_NET]
	return &""


func boat_net_at(boat: int) -> Vector2:
	"""Where a boat's net lies in the water while its crew works the catch on station (INF: no net out)."""
	if fleet.phase[boat] != FleetScript.PHASE_ON_STATION:
		return Vector2.INF
	for t: int in Tables.MAX_TRIPS:
		if tables.t_live[t] == 1 and tables.t_boat[t] == boat and tables.t_state[t] == Tables.TRIP_FISHING:
			var y: float = fleet.yaw(boat)
			return fleet.position_m(boat) + Vector2(cos(y), -sin(y)) * 1.1
	return Vector2.INF


func bank_water(site: int) -> Vector2:
	"""A site's bank landing's water point (m)."""
	return _bank_water.get(site, Vector2.ZERO)


func ice_trip_out() -> bool:
	"""Whether an ice trip has its cycle open (its hole cut)."""
	for t: int in Tables.MAX_TRIPS:
		if tables.t_live[t] == 1 and tables.t_method[t] == Rules.METHOD_ICE and tables.t_state[t] == Tables.TRIP_FISHING:
			return true
	return false


func brewing() -> int:
	"""How many of the brewery's vats hold a batch (loading, brewing or ready to draw off)."""
	return slots_in_use(Recipes.STATION_BREWERY)


func slots_in_use(station: int) -> int:
	"""How many of `station`'s passive slots hold a batch (loading, waiting or ready to take down)."""
	var n: int = 0
	var first: int = Recipes.STATION_FIRST_SLOT[station]
	for slot: int in range(first, first + Recipes.STATION_SLOTS[station]):
		n += 0 if tables.s_state[slot] == Tables.SLOT_EMPTY else 1
	return n


func packing() -> bool:
	"""Whether a batch is being worked at the preserving table now (its worker at the table: rations, jam, a cheese, pickles)."""
	for j: int in Tables.MAX_JOBS:
		var batch: bool = tables.j_kind[j] == Tables.KIND_BATCH or tables.j_kind[j] == Tables.KIND_DRY
		if tables.j_live[j] == 1 and batch and tables.j_at[j] == 1 and _station_of_job(j) == Recipes.STATION_TABLE:
			return true
	return false


func grinding() -> bool:
	"""Whether a mill batch is being ground now (its worker at the stones)."""
	for j: int in Tables.MAX_JOBS:
		if tables.j_live[j] == 1 and tables.j_kind[j] == Tables.KIND_MILL and tables.j_at[j] == 1:
			return true
	return false
