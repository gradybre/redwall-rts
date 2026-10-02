extends "res://test/framework/test_case.gd"
## The winter's fuel and warmth loop (decision 0571; Brendan's rulings of 2026-10-01): the hearths' burn by season and
## by hour boundary, the milli-U accumulator with no drift, a room's convergence when the fuel is out, cold exposure's
## gain and clearing, Chilled's entry and exit and the work rate it sets, the HUD's Heating fuel text and warning states,
## the twelve-day projection, the Firewood order going urgent, the season skip's exact and deterministic landing, and no
## allocation per hour. No scene tree and no staged assets: the placeholder cast in the real village layout where a
## village is needed.

const Rules := preload("res://demo/winter/winter_rules.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const ColdScript := preload("res://demo/winter/cold_exposure.gd")
const Text := preload("res://demo/winter/winter_text.gd")
const WinterScript := preload("res://demo/winter/demo_winter.gd")
const SkipScript := preload("res://demo/winter/season_skip.gd")
const WarmUpScript := preload("res://demo/winter/warm_up_task.gd")
const ModelScript := preload("res://demo/ui/demo_hud_model.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const WoodsWork := preload("res://demo/work/woods_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const FarmSim := preload("res://demo/farm/farm_sim.gd")
const SeasonScript := preload("res://demo/farm/farm_season.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const Needs := preload("res://scripts/core/needs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const HelpTopics := preload("res://demo/guide/help_topics.gd")
const FieldGuide := preload("res://demo/guide/field_guide.gd")

const WOOD: int = 60
const SPRING: int = WeatherScript.SEASON_SPRING
const SUMMER: int = WeatherScript.SEASON_SUMMER
const AUTUMN: int = WeatherScript.SEASON_AUTUMN
const WINTER: int = WeatherScript.SEASON_WINTER
const HALL: int = FuelScript.HALL
## Winter's day 1, 06:00 (the first winter): an hour index and its tick.
const WINTER_HOUR: int = 36 * 24 + 6

var _nodes: Array[Object] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _fuel(wood_milli: int) -> FuelScript:
	"""Hearth fuel over fresh stores holding `wood_milli`, the hall's hearth in."""
	var stores := StoresScript.new()
	stores.wood_milli_u = wood_milli
	var fuel := FuelScript.new()
	fuel.bind_stores(stores)
	fuel.set_hearth(HALL, true)
	return fuel


# --- the burn rates ---------------------------------------------------------------------------------------

func test_the_burn_rate_follows_the_season_and_the_ten_degree_line() -> void:
	"""§5.8: 4 U a day in winter whatever the mean; 2 U a spring or autumn day under 10 °C, none at 10 °C; none in summer
	even below freezing; tier 2's x0.75."""
	assert_equal(Rules.WINTER_DAY_MILLI, 4000, "24 h at 6 h a unit")
	assert_equal(Rules.day_demand_milli(WINTER, 120), 4000, "winter, even mild")
	assert_equal(Rules.day_demand_milli(WINTER, -120), 4000, "winter, hard freeze")
	assert_equal(Rules.day_demand_milli(SPRING, 99), 2000, "spring under 10 °C")
	assert_equal(Rules.day_demand_milli(SPRING, 100), 0, "spring at 10 °C: not below")
	assert_equal(Rules.day_demand_milli(AUTUMN, 100), 0, "autumn's baseline 10 °C: no demand")
	assert_equal(Rules.day_demand_milli(AUTUMN, -30), 2000, "autumn's early frost")
	assert_equal(Rules.day_demand_milli(SUMMER, -50), 0, "summer: nothing")
	assert_equal(Rules.day_demand_milli(WINTER, 0, Rules.TIER2_FUEL_PERMILLE), 3000, "tier 2 x0.75")


func test_a_hearth_burns_on_the_hour_boundaries_of_its_day() -> void:
	"""The day's demand is read at each hour: an autumn day at 10 °C burns nothing, the next hour of an early-frost day
	burns; a summer hour none; a banked hearth none; a home without a hearth is NONE."""
	var fuel: FuelScript = _fuel(100000)
	fuel.pass_hour(10, AUTUMN, 100, 100)
	assert_equal(fuel.state[HALL], FuelScript.STATE_IDLE, "no demand at 10 °C")
	assert_equal(fuel.wood_milli(), 100000, "nothing taken")
	fuel.pass_hour(11, AUTUMN, -30, -30)
	assert_equal(fuel.state[HALL], FuelScript.STATE_HEATED, "the frost's hour burns")
	assert_equal(fuel.wood_milli(), 100000 - 83, "2 U a day: 83 milli this hour")
	fuel.pass_hour(12, SUMMER, 220, 220)
	assert_equal(fuel.state[HALL], FuelScript.STATE_IDLE, "summer: idle")
	fuel.set_banked(HALL, true)
	fuel.pass_hour(13, WINTER, -50, -50)
	assert_equal(fuel.state[HALL], FuelScript.STATE_BANKED, "let go out")
	assert_equal(fuel.state[0], FuelScript.STATE_NONE, "home 0 has no hearth")
	assert_false(fuel.hearth_lit(HALL), "a banked hearth does not glow")
	assert_true(fuel.hearth_cold(HALL), "and gives no comfort")


func test_the_accumulator_takes_exactly_the_day_with_no_drift() -> void:
	"""Thirty winter days take exactly 30 x 4 U, each hour 166 or 167 milli, the accumulator back to 0 at each day's end;
	a spring cold day's 83/84 likewise exactly 2 U."""
	var fuel: FuelScript = _fuel(1000000)
	var low: int = 1000000
	var high: int = 0
	for h: int in 30 * 24:
		var before: int = fuel.wood_milli()
		fuel.pass_hour(h, WINTER, -50, -50)
		low = mini(low, before - fuel.wood_milli())
		high = maxi(high, before - fuel.wood_milli())
		if h % 24 == 23:
			assert_equal(fuel.burn_acc[HALL], 0, "day %d: nothing owed" % Rules.day_of_hour(h))
	assert_equal(fuel.burned_milli, 30 * 4000, "exactly 120 U")
	assert_equal(fuel.wood_milli(), 1000000 - 120000, "out of the stores")
	assert_equal([low, high], [166, 167], "a sixth of a unit an hour, the rest kept")
	var spring: FuelScript = _fuel(10000)
	for h: int in 24:
		spring.pass_hour(h, SPRING, 90, 90)
	assert_equal(spring.burned_milli, 2000, "a cold spring day: 2 U")
	assert_equal(spring.heated_hours, 24, "every hour heated")


func test_out_of_fuel_converges_the_room_and_wood_relights_it() -> void:
	"""REQ-SET-131: with less than an hour's wood the hearth is OUT, nothing is taken, and the room moves halfway to the
	air each hour (18 -> 6.5 -> 0.7 -> -2.2 °C at -5 °C, the odd tenth toward the air); the hour's share goes back to the accumulator. Wood in: the
	next hour it burns again and the room is 18 °C."""
	var fuel: FuelScript = _fuel(300)
	fuel.pass_hour(0, WINTER, -50, -50)
	assert_true(fuel.is_heated(HALL), "the first hour's 166 milli")
	assert_equal(fuel.temperature_of(HALL), Rules.HEATED_TENTHS, "18 °C")
	fuel.pass_hour(1, WINTER, -50, -50)
	assert_true(fuel.is_out(HALL), "167 wanted, 134 held: out")
	assert_equal(fuel.wood_milli(), 134, "nothing taken")
	assert_equal(fuel.out_since[HALL], 1, "out since hour 1")
	assert_equal(fuel.burn_acc[HALL], 4000 - 166 * 24, "the hour's share given back")
	assert_equal(fuel.temperature_of(HALL), 65, "halfway to -5")
	fuel.pass_hour(2, WINTER, -50, -50)
	assert_equal(fuel.temperature_of(HALL), 7, "halfway again, the odd tenth toward the air")
	fuel.pass_hour(3, WINTER, -50, -50)
	assert_equal(fuel.temperature_of(HALL), -22, "below freezing")
	assert_equal(fuel.cold_hours, 3, "three hours out")
	fuel._stores.add_wood(5000)
	fuel.pass_hour(4, WINTER, -50, -50)
	assert_true(fuel.is_heated(HALL), "relit")
	assert_equal(fuel.temperature_of(HALL), Rules.HEATED_TENTHS, "18 °C again")


func test_warm_beds_and_comfort_follow_the_fuel() -> void:
	"""A home is warm while heated or when no heat is demanded; out of fuel it is cold, and its hearth gives no
	comfort; with no hearth in winter it is cold."""
	var fuel: FuelScript = _fuel(0)
	fuel.set_hearth(0, true)
	fuel.pass_hour(0, SPRING, 120, 120)
	assert_true(fuel.is_warm(0) and fuel.is_warm(1), "no demand: every bed warm, hearth or not")
	assert_false(fuel.hearth_cold(0), "an idle hearth still counts")
	fuel.pass_hour(1, WINTER, -50, -50)
	assert_false(fuel.is_warm(0), "out of fuel: cold")
	assert_true(fuel.hearth_cold(0), "no comfort from it")
	assert_false(fuel.is_warm(1), "no hearth in winter: cold")
	assert_equal(FixturesScript.comfort_of(true, false, 0), 4000, "a bed, no warm hearth")


func test_fuel_days_and_the_last_heated_hour() -> void:
	"""§5.8: wood over the day's heating plus the three-day cooking mean, in hundredths, floored; no heating demand is
	NO_DEMAND, never a division; the last heated hour the wood's hours on from now."""
	assert_equal(Rules.fuel_days_hundredths(10000, 0, 1000), Rules.NO_DEMAND, "no heating: no demand")
	assert_equal(Rules.fuel_days_hundredths(10000, 4000, 1000), 200, "10 U over 5 U a day")
	assert_equal(Rules.fuel_days_hundredths(7999, 4000, 0), 199, "floored")
	assert_equal(Rules.hours_of_fuel(10000, 4000, 1000), 48, "two days")
	var fuel: FuelScript = _fuel(6000)
	fuel.pass_hour(100, WINTER, -50, -50)
	assert_equal(fuel.fuel_days_hundredths(), 145, "5834 milli over 4 U a day")
	assert_equal(fuel.last_heated_hour(), 100 + 35, "35 more hours")


func test_m4_fuel_counts_winter_days_whatever_the_season() -> void:
	"""M4's "fuel >= 18 winter days" (decision 0902): the wood over every burning hearth at 4 U plus the cooking mean, in
	thousandths of a day -- in summer too, when today's fuel-days are NO_DEMAND; 0 with no hearth to heat."""
	var winter: WinterScript = _keep(WinterScript.new()) as WinterScript
	winter.fuel = _fuel(72000)
	winter.fuel.pass_hour(10, SUMMER, 180, 180)
	assert_equal(winter.fuel.fuel_days_hundredths(), Rules.NO_DEMAND, "summer: no demand today")
	assert_equal(winter.fuel_winter_days_milli(), 18000, "72 U over the hall's 4 U a winter day: 18 days")
	winter.fuel.set_hearth(0, true)
	assert_equal(winter.fuel_winter_days_milli(), 9000, "two hearths: 9 days")
	winter.fuel.set_banked(0, true)
	winter.fuel.set_banked(HALL, true)
	assert_equal(winter.fuel_winter_days_milli(), 0, "none burning: nothing to measure")


func test_the_cooking_mean_is_the_last_three_whole_days() -> void:
	"""The kitchen's running total read hourly: each new day closes the last; the mean over at most three days."""
	var fuel: FuelScript = _fuel(0)
	fuel.note_cooking(0, 0)
	assert_equal(fuel.cook_mean_milli(), 0, "no whole day yet")
	fuel.note_cooking(1000, 1)
	assert_equal(fuel.cook_mean_milli(), 1000, "day 0: 1 U")
	fuel.note_cooking(2500, 2)
	assert_equal(fuel.cook_mean_milli(), 1250, "1 and 1.5 U")
	fuel.note_cooking(2500, 3)
	fuel.note_cooking(5500, 4)
	assert_equal(fuel.cook_mean_milli(), 1500, "days 1-3: 1.5, 0, 3 U")


func test_the_twelve_day_projection() -> void:
	"""REQ-SET-114 / ruling 6: twelve winter days of every burning hearth at 4 U plus the cooking mean; progress per
	mille, capped."""
	assert_equal(Rules.projection_milli(2, 1000), 12 * 9000, "two hearths and 1 U of cooking")
	assert_equal(Rules.projection_milli(0, 0), 0, "nothing burns: nothing wanted")
	assert_equal(Rules.permille_of(40000, 60000), 666, "two thirds")
	assert_equal(Rules.permille_of(90000, 60000), 1000, "capped")
	var fuel: FuelScript = _fuel(40000)
	fuel.set_hearth(1, true)
	fuel.note_cooking(0, 0)
	fuel.note_cooking(1000, 1)
	assert_equal(fuel.projection_milli(), 12 * 9000, "the hall and home 1, 1 U cooking")
	assert_true(Text.projection_line(fuel).contains("108.0 U") and Text.projection_line(fuel).contains("37%"),
		Text.projection_line(fuel))


# --- exposure and Chilled -------------------------------------------------------------------------------

func test_exposure_constants_are_the_needs_store_s() -> void:
	"""The rules read needs.gd, never retype it; Chilled borrows the storm's 80%."""
	assert_equal(Rules.GAIN_MILLI_PER_HOUR, Needs.COLD_GAIN_TIER1_MILLI_PER_HOUR, "gain")
	assert_equal(Rules.GAIN_HARD_FREEZE_MILLI_PER_HOUR, Needs.COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR, "hard freeze")
	assert_equal(Rules.CLEAR_MILLI_PER_HOUR, Needs.COLD_CLEAR_SHELTER_MILLI_PER_HOUR, "clear")
	assert_equal(Rules.CHILLED_AT_MILLI, Needs.COLD_DAMAGE_HOURS * 1000, "4 exposure-hours")
	assert_equal(Rules.CHILLED_WORK_PERMILLE, 800, "the storm's outdoor work factor")
	assert_equal(WinterScript.WARM_UP_HOURS * Rules.CLEAR_MILLI_PER_HOUR, Rules.CHILLED_AT_MILLI, "a break's fire: 2 hours")
	assert_equal(Rules.env_for(false, -1), Rules.ENV_EXPOSED, "below freezing")
	assert_equal(Rules.env_for(false, 0), Rules.ENV_NEUTRAL, "at freezing: not below")
	assert_equal(Rules.env_for(true, -100), Rules.ENV_HEATED, "a heated room")
	assert_equal(Rules.exposure_rate(Rules.ENV_EXPOSED, true), 2000, "hard freeze x2")
	assert_equal(Rules.exposure_rate(Rules.ENV_HEATED, true), -2000, "clearing is 2000 always")


func test_exposure_integrates_exactly_however_the_ticks_are_cut() -> void:
	"""750 ticks at 1000 an hour are exactly 1000 milli-hours whether in one stretch or in uneven ones; clearing floors
	at 0; the cap holds."""
	var cold := ColdScript.new()
	cold.configure(2)
	cold.integrate(0, 1000, 750)
	for ticks: int in [1, 2, 3, 7, 11, 13, 200, 513]:
		cold.integrate(1, 1000, ticks)
	assert_equal(cold.cold_milli[0], 1000, "one stretch")
	assert_equal(cold.cold_milli[1], 1000, "eight uneven stretches, no drift")
	cold.integrate(1, -2000, 750)
	assert_equal(cold.cold_milli[1], 0, "cleared, floored at 0")
	cold.integrate(0, 2000, 750 * 10)
	assert_equal(cold.cold_milli[0], Rules.COLD_CAP_MILLI, "capped at 8 exposure-hours")


func test_chilled_enters_at_four_hours_and_leaves_warmed_through() -> void:
	"""Not Chilled at 3.999 h; Chilled at 4; still Chilled at 1 h while clearing; well again at 0 -- each change listed
	once, and the work rate follows."""
	var cold := ColdScript.new()
	cold.configure(1)
	cold.integrate(0, 1000, 2999)
	assert_false(cold.is_chilled(0), "3.998 exposure-hours")
	assert_equal(cold.work_permille(0), 1000, "full pace")
	cold.integrate(0, 1000, 1)
	assert_true(cold.is_chilled(0), "4 exposure-hours")
	assert_equal(cold.work_permille(0), 800, "80%")
	cold.integrate(0, -2000, 1125)
	assert_true(cold.is_chilled(0), "1 h left: still Chilled")
	cold.integrate(0, -2000, 375)
	assert_false(cold.is_chilled(0), "warmed through")
	var entered := PackedInt32Array()
	var warmed := PackedInt32Array()
	cold.take_changes_into(entered, warmed)
	assert_equal([entered, warmed], [PackedInt32Array([0]), PackedInt32Array([0])], "one each")
	assert_equal(cold.chilled_count, 1, "counted once")


func test_the_work_rate_slows_the_credit_exactly() -> void:
	"""resident_brain.gd `work_credit`: at 800 per mille, 7 frames of 16 667 usec credit 93 335 usec, the remainder kept;
	at full pace the usec as they are."""
	var brain := BrainScript.new()
	var total: int = 0
	brain.work_permille = 800
	for k: int in 7:
		total += brain.work_credit(16667)
	assert_equal(total, Rules.div(7 * 16667 * 800, 1000), "exact over frames")
	brain.work_permille = 1000
	assert_equal(brain.work_credit(16667), 16667, "full pace")


# --- the HUD -------------------------------------------------------------------------------------------

func test_the_heating_fuel_cell_s_words_and_warning() -> void:
	"""UI-SET-003: "Heating fuel: 1.6 days" (floored tenth) or "No current heat demand"; the warning under 2 days only
	while heat is demanded."""
	assert_equal(Text.days_value(169), "1.6 days", "floored")
	assert_equal(Text.days_value(1234), "12.3 days", "twelve")
	assert_equal(Text.hud_line(Rules.NO_DEMAND), "Heating fuel: No current heat demand", "no demand")
	assert_equal(Text.cell_value(Rules.NO_DEMAND), Text.NO_DEMAND_SHORT, "the cell's short words")
	assert_true(Text.is_warning(199), "under 2 days")
	assert_false(Text.is_warning(200), "2 days: no warning")
	assert_false(Text.is_warning(Rules.NO_DEMAND), "no demand: no warning")
	assert_true(Text.is_warning(0), "out of fuel")


func test_the_hud_model_reads_the_winter_and_keeps_planks_in_the_ledger() -> void:
	"""The Fuel slot is Heating fuel from the winter; Planks move to a ledger line after Wood and the Wood tooltip."""
	var model := ModelScript.new()
	var stores := StoresScript.new()
	stores.plank_milli_u = 2500
	model.stores = stores
	var figure: Array[int] = [Rules.NO_DEMAND]
	model.fuel = func() -> int: return figure[0]
	model.fuel_detail = func() -> PackedStringArray: return PackedStringArray(["Burning 5.0 U a day"])
	var figures := PackedInt64Array()
	figures.resize(ModelScript.CELL_COUNT)
	model.read_into(figures)
	assert_equal(ModelScript.CAPTIONS[ModelScript.CELL_FUEL], "Heating fuel", "the caption")
	assert_equal(model.value_text(ModelScript.CELL_FUEL, figures[ModelScript.CELL_FUEL]), Text.NO_DEMAND_SHORT, "no demand")
	assert_false(model.is_warning(ModelScript.CELL_FUEL, figures[ModelScript.CELL_FUEL]), "no warning")
	figure[0] = 150
	model.read_into(figures)
	assert_equal(model.value_text(ModelScript.CELL_FUEL, figures[ModelScript.CELL_FUEL]), "1.5 days", "days")
	assert_true(model.is_warning(ModelScript.CELL_FUEL, 150), "warning")
	assert_true(model.tooltip(ModelScript.CELL_FUEL, 150).begins_with("Heating fuel: 1.5 days. Burning"), "its tooltip")
	assert_true(model.tooltip(ModelScript.CELL_WOOD, 40000).contains("(planks: 2.5 U)"), "planks in Wood's tooltip")
	var ledger: String = model.ledger_text(figures)
	assert_true(ledger.contains("Wood: 40.0 U · planks 2.5 U in store"), ledger)
	assert_true(ledger.contains("\nHeating fuel: 1.5 days\n"), "the fuel's one ledger line: " + ledger)


# --- the village: warm beds, the firewood order, the warm-up, the skip --------------------------------

class Village extends RefCounted:
	var services: ServicesScript = null
	var cast: DemoCastScript = null
	var forestry: ForestryScript = null
	var night: NightScript = NightScript.new()
	var winter: WinterScript = null
	var board: BoardScript = BoardScript.new()


func _village(tick: int, row: WeatherScript = null) -> Village:
	"""The placeholder cast in the real layout with the woods, the night, the work board and the winter, the calendar at
	`tick` (the winter's first hour is the one it is in)."""
	var v := Village.new()
	v.services = ServicesScript.new()
	v.services.calendar.tick = tick
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	v.cast = _keep(DemoCastScript.new()) as DemoCastScript
	v.cast.build({}, world.points_of_interest(), circles)
	v.cast.set_bounds(world.bounds())
	v.forestry = _keep(ForestryScript.new()) as ForestryScript
	v.forestry.configure(world, v.cast, null, null, v.services, IntMath.IntResult.new(true, WOOD, ""))
	v.forestry.crew.set_crew(PackedInt32Array())
	_night_of(v)
	v.winter = _keep(WinterScript.new()) as WinterScript
	v.winter.configure(v.services, v.cast, v.cast.space().tunnels, v.night, row if row != null else WeatherScript.new())
	v.winter.bind_work(v.forestry.crew, v.board)
	return v


func _night_of(v: Village) -> void:
	"""The night over the village's residents, and the work board over the woods."""
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var heights := PackedInt32Array()
	var keys: Array[StringName] = []
	for i: int in v.cast.actor_count():
		var actor := v.cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		heights.append(int(actor.height_m * 1024.0))
		keys.append(actor.creature_key)
	v.night.configure(v.cast.space().tunnels, brains, names, heights, v.services.calendar, v.services.notices)
	v.board.bind(brains, names, keys)
	v.board.add_source(WoodsWork.new(v.forestry.crew))


func _winter_tick() -> int:
	"""Winter day 1, 06:00."""
	return SkipScript.tick_of_hour(WINTER_HOUR)


func test_the_firewood_order_stands_and_goes_urgent_under_two_days() -> void:
	"""Winter with 5 U in store and the hall's hearth: a Firewood order is raised on the woods' board (deadfall first),
	listed under Woods and marked URGENT; with wood in, it stays but is no longer urgent."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 5000
	v.winter.catch_up()
	var row: int = v.winter.firewood_row()
	assert_true(row >= 0, "a Firewood order")
	assert_equal(v.forestry.crew.jobs.origin[row], ForestJobs.ORIGIN_FIREWOOD, "the winter's")
	assert_equal(v.forestry.crew.jobs.kind[row], ForestJobs.KIND_GATHER, "deadfall first")
	assert_equal(v.board.source(WorkIds.SOURCE_WOODS).activity(row), WorkIds.ACT_WOODS, "under the woods activity")
	assert_true(v.board.is_urgent(WorkIds.SOURCE_WOODS, row), "urgent: about a day of fuel")
	v.forestry.crew.cancel_row(row)
	v.services.calendar.tick += SimClock.TICKS_PER_HOUR
	v.winter.catch_up()
	var again: int = v.winter.firewood_row()
	assert_true(again >= 0 and v.board.is_urgent(WorkIds.SOURCE_WOODS, again), "cancelled: a new order, urgent too")
	row = again
	v.services.stores.add_wood(200000)
	v.services.calendar.tick += SimClock.TICKS_PER_HOUR
	v.winter.catch_up()
	assert_equal(v.winter.firewood_row(), row, "the same order stands")
	assert_false(v.board.is_urgent(WorkIds.SOURCE_WOODS, row), "no longer urgent")
	assert_false(v.winter.firewood_wanted(), "nothing more wanted: 200 U against the projection")


func test_out_of_fuel_raises_its_incident_and_the_low_fuel_warning() -> void:
	"""No wood in winter: the hall's hearth is out (the incident), and REQ-SET-147's warning stands -- the forecast is
	below freezing; with wood both resolve."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 0
	v.winter.catch_up()
	assert_true(v.winter.fuel.is_out(HALL), "out")
	var out: int = v.services.incidents.serial_of(WinterScript.KEY_OUT)
	var low: int = v.services.incidents.serial_of(WinterScript.KEY_LOW)
	assert_true(out != -1 and v.services.incidents.is_unresolved(out), "out of fuel")
	assert_true(low != -1 and v.services.incidents.is_unresolved(low), "the fuel warning")
	assert_true(v.services.incidents.text_of(low).contains("the last heated hour is about"), v.services.incidents.text_of(low))
	v.services.stores.add_wood(200000)
	v.services.calendar.tick += SimClock.TICKS_PER_HOUR
	v.winter.catch_up()
	v.services.incidents.sweep()
	assert_false(v.services.incidents.is_unresolved(out), "relit: resolved")
	assert_false(v.services.incidents.is_unresolved(low), "two days and more: resolved")


func test_a_resident_outdoors_in_winter_is_chilled_and_goes_to_warm_up() -> void:
	"""Winter, the hall heated: a resident outdoors gains 1000 an hour; at 4 it is Chilled, slowed to 80%, said so in the
	news, and sent to warm up in the hall; there it clears 2000 an hour and comes back warmed through."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 100000
	v.winter.catch_up()
	for k: int in 4 * 30:
		v.services.calendar.tick += 25
		v.winter.follow_exposure()
	assert_true(v.winter.cold.is_chilled(0), "four hours out: Chilled")
	assert_equal(v.cast.actor(0).brain.work_permille, 800, "works at 80%")
	assert_true(v.winter.status_text(0, true).begins_with("Chilled — 4.0 exposure-hours, last outdoors at -5 °C"),
		v.winter.status_text(0, true))
	assert_equal(v.winter.warm_place_for(0), HALL, "no home: the hall")
	v.winter.send_warm_ups()
	assert_true(v.cast.actor(0).brain.task is WarmUpScript, "sent to warm up")
	v.cast.actor(0).brain.task_go_indoors(true)
	for k: int in 2 * 30:
		v.services.calendar.tick += 25
		v.winter.follow_exposure()
	assert_false(v.winter.cold.is_chilled(0), "warmed through in the heated hall")
	assert_equal(v.cast.actor(0).brain.work_permille, 1000, "back to full pace")


func _dug_home(v: Village, at: Vector2i, places: int) -> int:
	"""A burrow home laid at `at` (u) on the village's network, dug at once, its first `places` places installed (the
	night test's way). Its room row."""
	var graph: RefCounted = v.cast.space().tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.call(&"add_room", 1, at, 0, 0, ref), "a home laid")
	var chain := PackedInt32Array()
	graph.call(&"piece_segments_into", ref[2], chain)
	for slot: int in chain:
		graph.call(&"start_dig", slot, graph.get("generation")[slot], 0)
		graph.call(&"advance", slot, graph.get("generation")[slot], 1000000000)
	for f: int in places:
		graph.get("fit").call(&"phase_of", graph, ref[0], f)
		graph.get("fit").get("phase")[ref[0] * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.get("fit").set("revision", int(graph.get("fit").get("revision")) + 1)
	return ref[0]


func test_a_fitted_hearth_heats_its_home_and_its_comfort_follows_the_fuel() -> void:
	"""A dug home with its beds and hearth is a hearth source; one with beds only is not. Out of wood its hearth gives no
	comfort (a bed: 4000); with wood it is heated, lit, and its hearth counts again (6000)."""
	var v: Village = _village(_winter_tick())
	assert_equal(WinterScript.hearth_place(), 3, "a home's hearth place")
	var fitted: int = _dug_home(v, Vector2i(0, 8192), 4)
	var bare: int = _dug_home(v, Vector2i(12288, 8192), 3)
	var graph: RefCounted = v.cast.space().tunnels
	v.services.stores.wood_milli_u = 0
	v.winter.catch_up()
	assert_equal(v.winter.fuel.hearth[fitted], 1, "the fitted home's hearth is a source")
	assert_equal(v.winter.fuel.hearth[bare], 0, "beds alone are no hearth")
	assert_true(v.winter.fuel.is_out(fitted), "no wood: out")
	assert_equal(int(graph.get("fit").call(&"comfort", graph, fitted)), 4000, "no comfort from a cold hearth")
	v.services.stores.wood_milli_u = 100000
	v.services.calendar.tick += SimClock.TICKS_PER_HOUR
	v.winter.catch_up()
	assert_true(v.winter.fuel.hearth_lit(fitted), "wood: lit")
	assert_equal(int(graph.get("fit").call(&"comfort", graph, fitted)), 6000, "its hearth counts again")


func test_a_frost_night_s_day_demands_heat_so_its_sleepers_warm() -> void:
	"""Review H1: spring 11's frost night (02:00-05:59 at -3 °C) makes its day's mean 9.5 °C -- under 10 -- so the hall's
	hearth burns that day and holds 18 °C through the frost; the next day, 12 °C, demands nothing. Lived hour by hour, a
	resident in the hall gains no exposure and no cold-home warning is raised; on a spring day without a frost no warning
	either."""
	assert_equal(WinterScript.day_mean_tenths(120, SPRING, 11), 95, "(20 x 12 + 4 x -3) / 24 °C")
	assert_equal(WinterScript.day_mean_tenths(120, SPRING, 10), 120, "no frost: the day's own")
	assert_equal(WinterScript.day_mean_tenths(-50, WINTER, 3), -50, "winter: no frost night, already colder")
	var v: Village = _village(SkipScript.tick_of_hour(10 * 24))
	v.services.stores.wood_milli_u = 100000
	v.winter.catch_up()
	v.cast.actor(0).brain.task_go_indoors(true)
	for k: int in 30 * 30:
		v.services.calendar.tick += 25
		v.winter.catch_up()
		v.winter.follow_exposure()
		if Rules.hour_of_day(v.services.calendar.hour_index()) == 4 and Rules.hour_season_day(v.services.calendar.hour_index()) == 11:
			assert_true(v.winter.fuel.is_heated(HALL), "the frost night's hall is heated")
	assert_equal(v.winter.cold.cold_milli[0], 0, "the hall's sleeper never cold")
	assert_equal(v.services.incidents.serial_of(WinterScript.KEY_COLD % HALL), -1, "no cold-home warning")
	assert_true(v.winter.fuel.burned_milli >= 2000 - 84, "a cold spring day's wood: 2 U")
	assert_equal(v.winter.fuel.state[HALL], FuelScript.STATE_IDLE, "spring 12, 12 °C: idle again")


func test_consolidate_packs_sleepers_into_the_fewest_homes_and_lets_the_rest_go_out() -> void:
	"""Two fitted homes of three beds and three sleepers split between them (one in A, two in B): Consolidate keeps one
	home -- the lower row on a tie -- moves the two from B into A's free beds, and lets B's hearth go out."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 100000
	var a: int = _dug_home(v, Vector2i(0, 8192), 4)
	var b: int = _dug_home(v, Vector2i(12288, 8192), 4)
	v.winter.catch_up()
	v.night.allocate()
	for i: int in v.night.bed_of.size():
		v.night.permitted[i] = AllocationScript.SIZE_SMALL if i < 3 else AllocationScript.SIZE_NONE
	v.night.bed_of.fill(AllocationScript.NO_BED)
	v.night.bed_of[0] = a * FixturesScript.PLACES
	v.night.bed_of[1] = b * FixturesScript.PLACES
	v.night.bed_of[2] = b * FixturesScript.PLACES + 1
	assert_equal([v.night.beds_in(a), v.night.beds_in(b)], [3, 3], "three beds each")
	var done: PackedInt32Array = v.winter.consolidate()
	assert_equal(done, PackedInt32Array([2, 1]), "two moved, one hearth let go out")
	for i: int in 3:
		assert_equal(Rules.div(v.night.bed_of[i], FixturesScript.PLACES), a, "resident %d sleeps in home A" % i)
	assert_equal(v.winter.fuel.banked[b], 1, "home B's hearth let go out")
	assert_equal(v.winter.fuel.banked[a], 0, "home A's kept")


func test_a_cold_home_warning_needs_a_hearth_that_wood_would_light() -> void:
	"""Review L2: a winter home with sleepers but no hearth cools below freezing without a cold-home warning (wood would
	not help); a fitted home out of wood does warn."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 0
	var bare: int = _dug_home(v, Vector2i(0, 8192), 3)
	var fitted: int = _dug_home(v, Vector2i(12288, 8192), 4)
	v.night.allocate()
	v.night.bed_of[0] = bare * FixturesScript.PLACES
	v.night.bed_of[1] = fitted * FixturesScript.PLACES
	for k: int in 8:
		v.services.calendar.tick += SimClock.TICKS_PER_HOUR
		v.winter.catch_up()
	assert_true(v.winter.fuel.temperature_of(bare) < 0 and v.winter.fuel.temperature_of(fitted) < 0, "both below freezing")
	assert_equal(v.services.incidents.serial_of(WinterScript.KEY_COLD % bare), -1, "no hearth: no warning")
	assert_true(v.services.incidents.serial_of(WinterScript.KEY_COLD % fitted) != -1, "a hearth out of wood: warned")


func test_a_resident_in_a_home_s_void_is_in_that_home() -> void:
	"""`home_at`: below, inside a dug home's void on its level, a resident is in that home; elsewhere below, BELOW."""
	var v: Village = _village(_winter_tick())
	var a: int = _dug_home(v, Vector2i(0, 8192), 4)
	var brain: BrainScript = v.cast.actor(0).brain
	brain.position = Vector2(0.0, 8.0)
	brain.ground_y_m = -1.25
	assert_equal(v.winter.home_at(brain), a, "in its void")
	brain.position = Vector2(30.0, -30.0)
	assert_equal(v.winter.home_at(brain), ColdScript.BELOW, "elsewhere below")


func test_the_skip_does_not_count_its_days_as_days_without_cooking() -> void:
	"""Review M2: `rebase_cooking` starts the count again without pushing the skipped days in as zeros."""
	var fuel: FuelScript = _fuel(0)
	fuel.note_cooking(0, 0)
	fuel.note_cooking(1500, 1)
	assert_equal(fuel.cook_mean_milli(), 1500, "a day of 1.5 U")
	fuel.rebase_cooking(1500, 13)
	assert_equal(fuel.cook_mean_milli(), 1500, "the skip's twelve days are not zeros")
	fuel.note_cooking(2500, 14)
	assert_equal(fuel.cook_mean_milli(), 1250, "then the next day counts")


func test_the_skip_can_forgive_the_settlement_clock() -> void:
	"""Review M3: the field the skip re-bases exists on GameManager (a rename fails here)."""
	var manager: Node = preload("res://scripts/systems/game_manager.gd").new()
	assert_true(preload("res://demo/demo_village.gd").HOST_USEC_FIELD in manager, "GameManager has the host clock field")
	manager.free()


func test_no_break_while_carrying_or_to_a_fire_about_to_go_out() -> void:
	"""A Chilled resident with a load in hand delivers first; and a heated hall the stores cannot keep lit WARM_UP_HOURS
	is no place for a break."""
	var v: Village = _village(_winter_tick())
	v.services.stores.wood_milli_u = 100000
	v.winter.catch_up()
	v.winter.cold.integrate(0, 1000, 4 * 750)
	var brain: BrainScript = v.cast.actor(0).brain
	brain.carrying = true
	v.winter.send_warm_ups()
	assert_false(brain.task is WarmUpScript, "carrying: not sent")
	brain.carrying = false
	v.services.stores.wood_milli_u = 300
	assert_true(v.winter.fuel.is_heated(HALL), "the hall still lit this hour")
	assert_equal(v.winter.warm_place_for(0), ColdScript.OUTDOORS, "under two hours of wood: nowhere to send")
	v.services.stores.wood_milli_u = 100000
	assert_equal(v.winter.warm_place_for(0), HALL, "with wood: the hall")


func test_a_skip_is_not_lived() -> void:
	"""A frame bringing more than an hour of calendar (a skip) adds no exposure."""
	var v: Village = _village(_winter_tick())
	v.winter.catch_up()
	v.services.calendar.tick += 25
	v.winter.follow_exposure()
	assert_true(v.winter.cold.cold_milli[0] > 0, "a lived frame outdoors at -5 °C: some exposure")
	var lived: int = v.winter.cold.cold_milli[0]
	v.services.calendar.tick += SimClock.TICKS_PER_HOUR * 10
	v.winter.follow_exposure()
	assert_equal(v.winter.cold.cold_milli[0], lived, "ten hours jumped: none of it lived")


func test_beds_go_to_warm_homes_first() -> void:
	"""bed_allocation.gd `allocate_warm_first`: a resident in a cold home's bed moves to a free warm one; with every bed
	warm the allocation is REQ-SET-132's exactly."""
	var S: int = AllocationScript.SIZE_SMALL
	var beds := PackedInt32Array([3, 0, 0, S, 11, 10240, 0, S])
	var out := PackedInt32Array()
	AllocationScript.allocate_warm_first(PackedInt32Array([3, -1]), PackedInt32Array([0, 0, 0, 0]),
		PackedByteArray([S, S]), beds, PackedByteArray([0, 1]), out)
	assert_equal(out, PackedInt32Array([11, 3]), "the cold bed's sleeper takes the warm one; the other the cold")
	var plain := PackedInt32Array()
	AllocationScript.allocate(PackedInt32Array([3, -1]), PackedInt32Array([0, 0, 0, 0]), PackedByteArray([S, S]), beds, plain)
	AllocationScript.allocate_warm_first(PackedInt32Array([3, -1]), PackedInt32Array([0, 0, 0, 0]),
		PackedByteArray([S, S]), beds, PackedByteArray([1, 1]), out)
	assert_equal(out, plain, "all warm: REQ-SET-132's own")


func test_the_skip_lands_exactly_and_deterministically() -> void:
	"""From a mid-hour, mid-remainder spring moment, the skip lands on summer day 1, 06:00:00 exactly; twice from the same
	start gives the same village -- calendar, stores, the hearths' burn, the farm's hours."""
	var a: PackedInt64Array = _skip_once()
	var b: PackedInt64Array = _skip_once()
	assert_equal(a, b, "deterministic")
	assert_equal(a[0], SkipScript.tick_of_hour(Rules.next_season_start_hour(0, 6)), "summer 1, 06:00:00")
	assert_equal(a[4], 12 * 24 + 6 - 9, "one step an hour crossing, 09:00 to summer's 06:00: never a short step")


func _skip_once() -> PackedInt64Array:
	"""One skip from a fresh farm and village, read back."""
	var sim := FarmSim.new()
	var v: Village = _village(0, sim.crop_weather().weather())
	sim.share_calendar(v.services.calendar)
	sim.advance_usec(CalendarScript.HOUR_USEC * 3 + 50000)
	v.winter.catch_up()
	var hours: int = v.winter.skip_to_next_season(sim.advance_usec)
	var cal: SimClock.Calendar = v.services.calendar.now()
	assert_equal([cal.season, cal.season_day, cal.hour, cal.minute], [SUMMER, 1, 6, 0], "summer 1, 06:00")
	return PackedInt64Array([v.services.calendar.tick, v.services.stores.wood_milli_u, v.winter.fuel.burned_milli, sim.hours_run,
		hours, v.services.calendar.remainder()])


func test_three_skips_reach_winter_with_its_hearth_burning_and_the_summary() -> void:
	"""Spring to winter in three skips: the hall's hearth burned winter day 1's hours to dawn in lockstep with the
	calendar (at least seven hours' wood), it is heated at dawn, and REQ-SET-149's summary waits on the card."""
	var sim := FarmSim.new()
	var v: Village = _village(0, sim.crop_weather().weather())
	sim.share_calendar(v.services.calendar)
	v.services.stores.wood_milli_u = 1000000
	for k: int in 3:
		v.winter.skip_to_next_season(sim.advance_usec)
	assert_equal(v.services.calendar.now().season, WINTER, "winter")
	assert_true(v.winter.fuel.burned_milli >= 7 * 166, "at least winter day 1's seven hours to dawn burned")
	assert_true(v.winter.fuel.state[HALL] == FuelScript.STATE_HEATED, "winter's first hour heated")
	var serial: int = v.services.incidents.serial_of(WinterScript.KEY_SUMMARY)
	assert_true(serial != -1, "the preparation summary")
	assert_true(v.services.incidents.text_of(serial).begins_with("Winter has come. Ready food"), v.services.incidents.text_of(serial))


func test_no_objects_are_kept_per_hour() -> void:
	"""A season of hours through the fuel and a thousand stretches of exposure retain no objects."""
	var fuel: FuelScript = _fuel(10000000)
	var cold := ColdScript.new()
	cold.configure(9)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for h: int in 288:
		fuel.pass_hour(h, WINTER, -50, -50)
		fuel.note_cooking(h * 40, Rules.day_of_hour(h))
	for k: int in 1000:
		cold.integrate(k % 9, 1000, 3)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_equal(after - before, 0, "nothing kept")


# --- the planner, the guide ---------------------------------------------------------------------------

func test_the_planner_s_fuel_lane() -> void:
	"""The Fuel lane: the season's rule, and today's demand -- none in spring's opening, or the heated-until estimate."""
	var sim := FarmSim.new()
	var season := SeasonScript.new()
	season.fuel = _fuel(10000)
	season.fuel.pass_hour(6, SPRING, 120, 120)
	season.build(sim, null, null, 0)
	var lanes: Array[int] = []
	for k: int in season.count():
		if season.lane[k] == SeasonScript.LANE_FUEL:
			lanes.append(season.knowing[k])
	assert_equal(lanes, [SeasonScript.SCHEDULED, SeasonScript.NOW], "the rule, and no demand today")
	season.fuel.pass_hour(7, SPRING, 90, 90)
	season.build(sim, null, null, 0)
	var estimate: bool = false
	for k: int in season.count():
		estimate = estimate or (season.lane[k] == SeasonScript.LANE_FUEL and season.knowing[k] == SeasonScript.ESTIMATE)
	assert_true(estimate, "a cold spring day: heated until")


func test_the_guide_has_a_heating_topic_and_entry() -> void:
	"""A help topic answering "winter firewood", with the Heating fuel button; the field guide's hearths entry."""
	var topics := HelpTopics.new()
	var found: PackedInt32Array = topics.search("winter firewood")
	assert_true(found.size() > 0, "found")
	assert_equal(topics.action_of(found[0]), HelpTopics.ACTION_FUEL, "it opens Heating fuel")
	var guide := FieldGuide.new()
	var hit: bool = false
	for k: int in guide.count():
		hit = hit or guide.entry(k).id == &"station_hearths"
	assert_true(hit, "the hearths entry")
