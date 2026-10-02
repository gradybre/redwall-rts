extends RefCounted
## WHAT THE CURRENT OBJECTIVE'S CARD SAYS, read live from the village (decision 0481; review F49, P7; GDD REQ-SET-165,
## REQ-SET-167): its teaching, the CAUSE or BLOCKER now (`state`), the NEXT LEGAL ACTION, and the TARGET the world
## marker stands on and "Show me" goes to. Pure: `resolve_into` reads the world and the facts and fills a Status.
##
## NEVER A SOFTLOCK (REQ-SET-167). Every situation resolves to a next action: a lost target is replaced by another
## valid one of the same action (another ripe bed, the soonest-ripening bed, an empty bed to plant, a withered bed to
## clear), and where nothing can be done now the card says why and what to do meanwhile (speed time up, plant, make
## room, the next supper tomorrow). The three ways of objective 4 are offered side by side, each with where it stands,
## so a way that is blocked (no planks for a bridge) leaves the other two.

const WorldScript := preload("res://demo/guide/guide_world.gd")
const FactsScript := preload("res://demo/guide/guide_facts.gd")
const StepsScript := preload("res://demo/guide/guide_steps.gd")
const Text := preload("res://demo/guide/guide_text.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NO_BED: int = -1
## How far ahead the frost forecast looks, in days (a year).
const FORECAST_DAYS: int = 48
const HARVEST_KINDS: PackedInt32Array = [JobsScript.KIND_HARVEST]
const DELIVER_KINDS: PackedInt32Array = [JobsScript.KIND_DELIVER]
## The kitchen's refusals that block a meal (the others say it is cooked enough already).
## The room a ripe bed's harvest needs somewhere before the card calls the store full (farm_crew.gd STORE_ROOM_MILLI).
const STORE_ROOM_MILLI: int = 1000
const MEAL_BLOCKERS: Array[String] = [KitchenScript.NO_FOOD, KitchenScript.NO_WATER, KitchenScript.NO_FUEL,
	KitchenScript.NO_COOK]

## The store-room probe's one reused read (no allocation per resolve).
static var _room: IntMath.IntResult = IntMath.IntResult.new()


## One card's worth: the words and the target (TARGET_* of demo_notices.gd, with its id and where it is).
class Status extends RefCounted:
	var title: String = ""
	var teach: String = ""
	var state: String = ""
	var next: String = ""
	var choices: PackedStringArray = PackedStringArray()
	var target_kind: int = NoticesScript.TARGET_NONE
	var target_id: int = -1
	var target_point: Vector3 = Vector3.INF

	func clear() -> void:
		"""Empty, for the next resolve."""
		title = ""
		teach = ""
		state = ""
		next = ""
		choices.clear()
		target_kind = NoticesScript.TARGET_NONE
		target_id = -1
		target_point = Vector3.INF

	func aim(kind: int, id: int, point: Vector3) -> void:
		"""Point the marker and Show me at a target."""
		target_kind = kind
		target_id = id
		target_point = point


static func resolve_into(step: int, world: WorldScript, facts: FactsScript, out: Status) -> void:
	"""Fill `out` for objective `step` as the village stands now."""
	out.clear()
	if step < 0 or step >= StepsScript.STEP_COUNT:
		return
	out.title = Text.STEP_TITLES[step]
	out.teach = Text.STEP_TEACH[step]
	match step:
		StepsScript.STEP_MEET: _meet(world, out)
		StepsScript.STEP_HARVEST: _harvest(world, out)
		StepsScript.STEP_SUPPER: _supper(world, facts, out)
		StepsScript.STEP_SEASON: _season(world, facts, out)


static func confirm_text(step: int, world: WorldScript, facts: FactsScript) -> String:
	"""What objective `step`'s confirmation says, from the facts that completed it."""
	match step:
		StepsScript.STEP_MEET:
			return Text.STEP_CONFIRM[step] % world.resident_name(facts.met_who)
		StepsScript.STEP_HARVEST:
			var item: String = Catalog.ITEM_LABELS[facts.harvested_item].to_lower() \
				if Catalog.is_item(facts.harvested_item) else "food"
			return Text.STEP_CONFIRM[step] % [FarmText.units_text(facts.harvested_milli), item]
		StepsScript.STEP_SUPPER:
			return Text.STEP_CONFIRM[step] % facts.supper_line
		StepsScript.STEP_SEASON:
			return Text.STEP_CONFIRM[step] % choice_confirm(world, facts)
	return ""


static func choice_confirm(world: WorldScript, facts: FactsScript) -> String:
	"""Objective 4's confirmation for the way that was done first."""
	match facts.choice:
		FactsScript.CHOICE_BRIDGE:
			return Text.CHOICE_CONFIRM[facts.choice] % world.resident_name(facts.bridge_walker)
		FactsScript.CHOICE_TUNNEL:
			return Text.CHOICE_CONFIRM[facts.choice] % world.resident_name(facts.tunnel_walker)
		FactsScript.CHOICE_FIELD:
			return Text.CHOICE_CONFIRM[facts.choice] % [world.bed_label(facts.field_bed), facts.field_how]
	return ""


# --- 1: meet a villager ------------------------------------------------------------------------------

static func _meet(world: WorldScript, out: Status) -> void:
	"""The resident on the surface nearest the camera, or the roster when nobody is up."""
	var who: int = world.nearest_on_surface(world.camera_focus())
	if who < 0:
		out.state = Text.ALL_INDOORS
		out.next = Text.NEXT_SELECT_LIST
		return
	out.state = Text.NOBODY_SELECTED
	out.next = Text.NEXT_SELECT
	out.aim(NoticesScript.TARGET_RESIDENT, who, world.resident_point(who))


# --- 2: bring in a harvest ---------------------------------------------------------------------------

static func _harvest(world: WorldScript, out: Status) -> void:
	"""A load on its way, a ripe bed (or the store full), the soonest-ripening bed, a stalled one, an empty bed to
	plant, or a lost crop to clear -- in that order (see NEVER A SOFTLOCK)."""
	if world.sim == null:
		out.state = Text.NOTHING_GROWING
		out.next = Text.NEXT_WAIT_RIPE
		return
	if _delivery_under_way(world, out) or _ripe(world, out) or _growing(world, out):
		return
	var empty: int = _first_bed(world.sim, [SimScript.STAGE_EMPTY])
	if empty != NO_BED:
		out.state = Text.NOTHING_GROWING
		out.next = Text.NEXT_PLANT % world.the_bed(empty)
		out.aim(NoticesScript.TARGET_BED, empty, WorldScript.bed_point(empty))
		return
	var lost: int = _first_bed(world.sim, [SimScript.STAGE_WITHERED, SimScript.STAGE_BLIGHTED])
	out.state = Text.BEDS_LOST
	out.next = Text.NEXT_CLEAR % world.the_bed(maxi(lost, 0))
	out.aim(NoticesScript.TARGET_BED, maxi(lost, 0), WorldScript.bed_point(maxi(lost, 0)))


static func _delivery_under_way(world: WorldScript, out: Status) -> bool:
	"""A harvest cut and being carried to store (it counts once shelved)."""
	for bed: int in Catalog.BED_COUNT:
		var row: int = world.farm_job_on(bed, DELIVER_KINDS)
		if row < 0 or world.jobs.load_milli[row] <= 0:
			continue
		var item: int = world.jobs.load_item[row]
		out.state = Text.DELIVERY_UNDER_WAY % [world.job_worker(row), FarmText.units_text(world.jobs.load_milli[row]),
			Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "food"]
		out.next = Text.NEXT_WAIT_DELIVERY
		out.aim(NoticesScript.TARGET_BED, bed, WorldScript.bed_point(bed))
		return true
	return false


static func _ripe(world: WorldScript, out: Status) -> bool:
	"""A ripe bed: being harvested, waiting for room, or ready for the order."""
	var bed: int = _first_bed(world.sim, [SimScript.STAGE_RIPE])
	if bed == NO_BED:
		return false
	out.aim(NoticesScript.TARGET_BED, bed, WorldScript.bed_point(bed))
	var row: int = world.farm_job_on(bed, HARVEST_KINDS)
	if world.pantry != null and not world.pantry.location_for_into(STORE_ROOM_MILLI, _room):
		out.state = Text.STORE_FULL
		out.next = Text.NEXT_MAKE_ROOM
	elif row >= 0:
		out.state = Text.HARVEST_UNDER_WAY % [world.job_worker(row), world.bed_label(bed)]
		out.next = Text.NEXT_WAIT_DELIVERY
	else:
		out.state = Text.RIPE_BED % world.bed_label(bed)
		out.next = Text.NEXT_HARVEST
	return true


static func _growing(world: WorldScript, out: Status) -> bool:
	"""The bed that ripens soonest, or -- every growing bed stalled -- the first stalled one and why."""
	var best: int = NO_BED
	var best_h: int = 0
	var stalled: int = NO_BED
	for bed: int in Catalog.BED_COUNT:
		var stage: int = world.sim.stage_of(bed)
		if stage < SimScript.STAGE_SOWN or stage > SimScript.STAGE_GROWING:
			continue
		var hours: int = world.hours_to_ripe(bed)
		if hours < 0:
			stalled = bed if stalled == NO_BED else stalled
		elif best == NO_BED or hours < best_h:
			best = bed
			best_h = hours
	if best != NO_BED:
		out.state = Text.NOT_RIPE_YET % [world.bed_label(best), best_h]
		out.next = Text.NEXT_WAIT_RIPE
		out.aim(NoticesScript.TARGET_BED, best, WorldScript.bed_point(best))
		return true
	if stalled == NO_BED:
		return false
	out.state = Text.STALLED % [world.bed_label(stalled), "it is %s" % SimScript.BAND_NAMES[world.sim.band_of(stalled)]]
	out.next = Text.NEXT_FIX_STALL
	out.aim(NoticesScript.TARGET_BED, stalled, WorldScript.bed_point(stalled))
	return true


static func _first_bed(sim: SimScript, stages: Array[int]) -> int:
	"""The first bed at one of `stages` (NO_BED for none); a kitchen-garden site not laid out is no bed (decision 0883)."""
	for bed: int in Catalog.BED_COUNT:
		if sim.is_laid(bed) and stages.has(sim.stage_of(bed)):
			return bed
	return NO_BED


# --- 3: serve the first supper -----------------------------------------------------------------------

static func _supper(world: WorldScript, facts: FactsScript, out: Status) -> void:
	"""Supper on the table, a blocker in the kitchen's own words, a missed supper, or the plan and its hours."""
	out.aim(NoticesScript.TARGET_NONE, -1, world.cauldron_point())
	var kitchen: KitchenScript = world.kitchen
	if kitchen == null:
		out.state = Text.SUPPER_CANT % "the kitchen is not built"
		out.next = Text.NEXT_SUPPER_WAIT
		return
	if kitchen.serving() >= 0 and posmod(kitchen.serving(), 2) == Rules.MEAL_SUPPER:
		out.state = Text.SUPPER_SERVING
		out.next = Text.NEXT_SUPPER_WAIT
		return
	var d: KitchenScript.Decision = kitchen.decide_meal()
	if MEAL_BLOCKERS.has(d.code):
		out.state = Text.SUPPER_CANT % d.reason
		out.next = Text.NEXT_SUPPER_FIX % d.fix if not d.fix.is_empty() else Text.NEXT_SUPPER_WAIT
		_aim_food(world, d, out)
		return
	out.state = Text.SUPPER_MISSED % facts.supper_missed_day if facts.supper_missed_day > 0 \
		else Text.SUPPER_PLANNED % [Rules.DISH_NAMES[_supper_dish(d.dish)].to_lower(), world.hour()]
	out.next = Text.NEXT_SUPPER_WAIT


static func _supper_dish(dish: int) -> int:
	"""The dish to name for supper: the next meal's when it is a supper dish (decision 0601's recipe book), else the
	soup."""
	return dish if dish >= 0 and Rules.DISH_MEAL[dish] == Rules.MEAL_SUPPER else Rules.DISH_SOUP


static func _aim_food(world: WorldScript, d: KitchenScript.Decision, out: Status) -> void:
	"""With no food for the meal, the marker goes to the bed that would feed it (a ripe one, else the soonest)."""
	if d.code != KitchenScript.NO_FOOD or world.sim == null:
		return
	var scratch := Status.new()
	if _ripe(world, scratch) or _growing(world, scratch):
		out.aim(scratch.target_kind, scratch.target_id, scratch.target_point)


# --- 4: ready the village for the frost --------------------------------------------------------------

static func _season(world: WorldScript, _facts: FactsScript, out: Status) -> void:
	"""The frost ahead, the three ways each with where it stands, and the marker on the way furthest on."""
	out.state = frost_line(world)
	out.next = Text.NEXT_CHOOSE
	out.choices.append("%s: %s" % [Text.CHOICE_TITLES[FactsScript.CHOICE_BRIDGE], bridge_line(world)])
	out.choices.append("%s: %s" % [Text.CHOICE_TITLES[FactsScript.CHOICE_TUNNEL], tunnel_line(world)])
	out.choices.append("%s: %s" % [Text.CHOICE_TITLES[FactsScript.CHOICE_FIELD], field_line(world)])
	if not _aim_bridge(world, out) and not _aim_tunnel(world, out):
		var bed: int = field_target(world)
		if bed != NO_BED:
			out.aim(NoticesScript.TARGET_BED, bed, WorldScript.bed_point(bed))


static func frost_line(world: WorldScript) -> String:
	"""The next frost night and how far off it is, from the farm's own frost calendar (farm_weather.gd)."""
	if world.calendar == null:
		return Text.FROST_NONE
	var now: SimClock.Calendar = world.calendar.now()
	if FarmWeather.frost_due(now.season, now.season_day, now.hour):
		return Text.FROST_TONIGHT
	var day := Vector2i(now.season, now.season_day)
	for ahead: int in range(1, FORECAST_DAYS + 1):
		day = FarmWeather.next_day(day.x, day.y)
		if FarmWeather.is_frost_night(day.x, day.y):
			var hours: int = (ahead - 1) * 24 + (24 - now.hour) + FarmWeather.FROST_FIRST_HOUR
			return Text.FROST_AHEAD % [CalendarScript.day_text(day.x, day.y), hours]
	return Text.FROST_NONE


static func bridge_line(world: WorldScript) -> String:
	"""Where the bridge way stands: open, being built, buildable now, or short of material (its own refusal)."""
	if world.bridges != null:
		for row: int in BridgesScript.MAX_BRIDGES:
			if world.bridges.is_open(row):
				return Text.BRIDGE_OPEN % world.bridges.names[row]
		for row: int in BridgesScript.MAX_BRIDGES:
			if world.bridges.is_planned(row):
				return Text.BRIDGE_BUILDING % [world.bridges.names[row], world.bridges.percent(row)]
	if not world.bridge_refusal.is_valid():
		return Text.BRIDGE_NONE
	var site: String = String(world.site_name.call()) if world.site_name.is_valid() else "the site"
	for kind: int in [SwimRules.KIND_LOG, SwimRules.KIND_PLANK]:
		if String(world.bridge_refusal.call(kind)).is_empty():
			return Text.BRIDGE_READY % [SwimRules.KIND_NAMES[kind], site]
	return Text.BRIDGE_SHORT % String(world.bridge_refusal.call(SwimRules.KIND_PLANK))


static func tunnel_line(world: WorldScript) -> String:
	"""Where the tunnel way stands: open tunnels waiting for a walker, one being dug, or none yet."""
	var open: int = world.open_tunnels()
	if open > 0:
		return Text.TUNNEL_OPEN % open
	var dug: int = world.tunnel_dig_percent()
	if dug >= 0:
		return Text.TUNNEL_DIGGING % dug
	return Text.TUNNEL_NONE


static func field_line(world: WorldScript) -> String:
	"""Where the field way stands: covering open now, a wet bed to drain, or raising and banking."""
	if world.sim == null or world.calendar == null:
		return Text.FIELD_NONE
	var now: SimClock.Calendar = world.calendar.now()
	if FarmWeather.frost_due(now.season, now.season_day, now.hour):
		return Text.FIELD_COVER
	for bed: int in Catalog.BED_COUNT:
		if _has_crop(world.sim, bed) and world.sim.band_of(bed) >= SimScript.BAND_WET:
			return Text.FIELD_WET % world.bed_label(bed)
	return Text.FIELD_NONE


static func field_target(world: WorldScript) -> int:
	"""The bed most worth readying: a wet one with a crop, else the crop nearest ripe (NO_BED: no crop standing)."""
	if world.sim == null:
		return NO_BED
	var best: int = NO_BED
	for bed: int in Catalog.BED_COUNT:
		if not _has_crop(world.sim, bed):
			continue
		if world.sim.band_of(bed) >= SimScript.BAND_WET:
			return bed
		if best == NO_BED or world.sim.growth_permille(bed) > world.sim.growth_permille(best):
			best = bed
	return best


static func _has_crop(sim: SimScript, bed: int) -> bool:
	"""Whether a crop stands in bed `bed` (sown to ripe)."""
	var stage: int = sim.stage_of(bed)
	return stage >= SimScript.STAGE_SOWN and stage <= SimScript.STAGE_RIPE


static func _aim_bridge(world: WorldScript, out: Status) -> bool:
	"""The marker on an open or planned bridge."""
	if world.bridges == null:
		return false
	for row: int in BridgesScript.MAX_BRIDGES:
		if world.bridges.is_open(row) or world.bridges.is_planned(row):
			var mid: Vector2 = (world.bridges.deck_end(row, false) + world.bridges.deck_end(row, true)) * 0.5
			out.aim(NoticesScript.TARGET_BRIDGE, row, Vector3(mid.x, 0.0, mid.y))
			return true
	return false


static func _aim_tunnel(world: WorldScript, out: Status) -> bool:
	"""The marker on an open tunnel's first mouth."""
	if world.network == null:
		return false
	for slot: int in WorldScript.TunnelRules.MAX_SEGMENTS:
		if world.network.is_open(slot) and world.network.is_tunnel(slot):
			var at: Vector2 = world.network.end_at(slot, false)
			out.aim(NoticesScript.TARGET_TUNNEL, slot, Vector3(at.x, 0.0, at.y))
			return true
	return false
