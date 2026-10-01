extends "res://test/framework/test_case.gd"
## The live demo's woods (decision 0196): the village's trees as REAL ResourceNode rows, felled,
## hauled, regrown, blown down and replanted through the store's own verbs; forestry and conservation
## zones and §5.9's retention floor; deadfall; sawing; skills; the one wood stock the tunnels spend;
## the drawings, the pick, the zone tool, the panel's tab and the command layer's hooks. Built over
## the placeholder cast in the real village layout -- no staged assets.

const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const SkillsScript := preload("res://demo/forestry/forest_skills.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const CrewScript := preload("res://demo/forestry/forest_crew.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const YardViewScript := preload("res://demo/forestry/forest_yard_view.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const ZoneToolScript := preload("res://demo/forestry/forest_zone_tool.gd")
const PanelScript := preload("res://demo/forestry/forest_panel.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PartyPanelScript := preload("res://demo/control/demo_party_panel.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const LiftScript := preload("res://demo/forestry/forest_lift.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")

## The compiled `wood` id the catalog boundary resolves (checked below; a fixture passes it).
const WOOD: int = 60
const DT: float = 0.1
const MAX_FRAMES: int = 6000
## The real layout's trees used below (demo_world.gd trees() order).
const WEST_OAK: int = 33
const NORTH_SAPLING: int = 0
const OLD_GROVE_OAK: int = 2
const NORTH_TREES: Array[int] = [32, 122, 141, 145, 154]

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()


# --- fixtures -----------------------------------------------------------------------------------

func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _world() -> DemoWorldScript:
	"""The real village layout (unbuilt: no staged assets)."""
	return _keep(DemoWorldScript.new()) as DemoWorldScript


func _forestry() -> ForestryScript:
	"""The woods over the placeholder cast in the real layout, as demo_village.gd wires them (the cast
	walks round the woods' circles too), with no routine crew unless a test names one."""
	var world := _world()
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	var forestry: ForestryScript = _keep(ForestryScript.new()) as ForestryScript
	forestry.configure(world, cast, null, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	forestry.crew.set_crew(PackedInt32Array())
	return forestry


func _run(forestry: ForestryScript, done: Callable) -> bool:
	"""Step the cast and the woods until `done()` answers true (bounded). True when it did."""
	var cast: DemoCastScript = forestry._cast
	for frame: int in MAX_FRAMES:
		if bool(done.call()):
			return true
		cast.advance(DT)
		forestry.step(cast.clock.frame_usec)
	return bool(done.call())


func _stand_of(placements: Array[Dictionary]) -> StandScript:
	"""A stand bound on day 1 over these placements."""
	var stand := StandScript.new()
	assert_true(stand.bind_into(placements, WOOD, 1, _read), "bound")
	return stand


func _three() -> Array[Dictionary]:
	"""An oak, a beech and a sapling, each on its own tile."""
	return [
		{"key": &"oak_mature", "at": Vector2(-10.0, -24.0), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(0.0, -24.0), "yaw": 0.5, "size": 1.1},
		{"key": &"oak_sapling", "at": Vector2(6.0, -20.0), "yaw": 1.0, "size": 1.0},
	]


func _feed_has(text: String, level: int) -> bool:
	"""Whether the shared feed holds this full text at this level, from the woods."""
	for k: int in _services.notices.count():
		if _services.notices.text(k) == text and _services.notices.level(k) == level \
				and _services.notices.source(k) == NoticesScript.SOURCE_WOODS:
			return true
	return false


# --- the rules ----------------------------------------------------------------------------------

func test_a_demo_point_lands_on_its_gdd_exterior_tile() -> void:
	"""The square's centre is tile (64, 64) = 8256; 2 m tiles, floored per axis after rounding to
	1/1024 m; off the 128 x 128 grid refuses."""
	assert_true(Rules.tile_of_into(Vector2.ZERO, _read), "on the grid")
	assert_equal(_read.value, 8256, "(64, 64)")
	Rules.tile_of_into(Vector2(-0.1, -0.1), _read)
	assert_equal(_read.value, 8127, "(63, 63)")
	Rules.tile_of_into(Vector2(1.999, 0.0), _read)
	assert_equal(_read.value, 8256, "2047 u is still tile 64")
	Rules.tile_of_into(Vector2(2.0, 0.0), _read)
	assert_equal(_read.value, 8257, "2048 u is tile 65")
	assert_false(Rules.tile_of_into(Vector2(130.0, 0.0), _read), "off the grid")
	assert_equal(_read.error, Rules.REFUSE_OFF_GRID, "said so")
	assert_equal(Rules.tile_centre_m(8256), Vector2(1.0, 1.0), "the tile's centre")


func test_skill_levels_and_factors_are_the_gdd_curve() -> void:
	"""§5.3: level = min(10, floor_sqrt(xp / 5000)); skill factor 1000 + 50 x level."""
	var expected: Dictionary = {0: 0, 4999: 0, 5000: 1, 19999: 1, 20000: 2, 45000: 3, 499999: 9, 500000: 10, 900000: 10}
	for xp: int in expected:
		assert_equal(Rules.level_of(xp), expected[xp], "%d XP" % xp)
	assert_equal(Rules.skill_factor_permille(0), 1000, "level 0")
	assert_equal(Rules.skill_factor_permille(3), 1150, "level 3")
	assert_equal(Rules.xp_of_level(3), 45000, "level 3 starts at 45000")


func test_work_time_follows_skill_season_and_storm() -> void:
	"""120 WU at 0.1 s: 12 s; a level-3 feller 10.43 s; winter felling 9.6 s; a storm day 15 s; a
	4-WU planting is held on screen for 2.5 s."""
	assert_equal(Rules.work_usec(120, 0, 1000, 1000), 12000000, "base")
	assert_equal(Rules.work_usec(120, 3, 1000, 1000), 10434782, "skill factor 1150")
	assert_equal(Rules.work_usec(120, 0, Rules.season_permille(WeatherCore.SEASON_WINTER, true), 1000), 9600000, "winter")
	assert_equal(Rules.work_usec(120, 0, 1000, Rules.weather_permille(WeatherCore.EVENT_HEAVY_RAIN)), 15000000, "storm")
	assert_equal(Rules.work_usec(4, 0, 1000, 1000), 2500000, "the minimum")
	assert_equal(Rules.season_permille(WeatherCore.SEASON_WINTER, false), 1000, "only felling is quicker")
	assert_equal(Rules.season_permille(WeatherCore.SEASON_SPRING, true), 1000, "spring")
	assert_equal(Rules.weather_permille(WeatherCore.EVENT_DROUGHT), 1000, "no storm")


func test_the_retention_floor_arithmetic() -> void:
	"""§5.9: 20% of a zone's trees stay mature (10% intensive), rounded up."""
	assert_equal(Rules.floor_mature(6, 20), 2, "6 trees keep 2")
	assert_equal(Rules.floor_mature(10, 20), 2, "10 keep 2")
	assert_equal(Rules.floor_mature(11, 20), 3, "11 keep 3")
	assert_equal(Rules.floor_mature(10, 10), 1, "intensive: 10 keep 1")
	assert_equal(Rules.floor_mature(0, 20), 0, "none")
	assert_true(Rules.retention_allows(2, 6, 20), "200 >= 120")
	assert_false(Rules.retention_allows(1, 6, 20), "100 < 120")
	assert_true(Rules.retention_allows(1, 5, 20), "exactly 20% is kept")
	assert_true(Rules.retention_allows(1, 6, 10), "100 >= 60")
	assert_false(Rules.retention_allows(0, 6, 10), "0 < 60")
	assert_false(Rules.retention_allows(-1, 0, 20), "never below none")
	assert_equal(Rules.deadfall_wu(1000), 20, "20 WU a U")
	assert_equal(Rules.deadfall_wu(1250), 25, "a quarter more")
	assert_equal(Rules.deadfall_wu(1999), 40, "rounded up")


# --- the real store -----------------------------------------------------------------------------

func test_the_village_trees_are_real_resource_node_rows() -> void:
	"""All 173 tree placements bind, each on its own tile, as §4.2 rows of the wood item: a mature one
	full at 12 U with a 48-day period dated day 1, a sapling emptied the same day."""
	var trees: Array[Dictionary] = _world().trees()
	var stand := _stand_of(trees)
	assert_equal(trees.size(), 173, "the village's trees")
	assert_equal(stand.count(), 173, "all bound")
	assert_equal(stand.skipped, 0, "none share a tile")
	assert_equal(stand.nodes.count(), 173, "one row each")
	var slot: int = stand.node_slot[WEST_OAK]
	assert_equal(stand.nodes.resource_id_of(slot).value, WOOD, "the wood item")
	assert_equal(stand.nodes.quantity_milli_of(slot).value, 12000, "12 U")
	assert_equal(stand.nodes.capacity_milli_of(slot).value, 12000, "capacity 12 U")
	assert_equal(stand.nodes.regrow_days_of(slot).value, 48, "48 days")
	assert_equal(stand.nodes.planted_day_of(slot).value, 1, "day 1")
	assert_equal(stand.nodes.tile_of(slot).value, 8372, "its own tile")
	assert_equal(stand.state_of(WEST_OAK), StandScript.STATE_MATURE, "mature")
	assert_equal(stand.state_of(NORTH_SAPLING), StandScript.STATE_YOUNG, "the sapling grows")
	assert_equal(stand.nodes.quantity_milli_of(stand.node_slot[NORTH_SAPLING]).value, 0, "holds no wood")
	assert_true(stand.nodes.is_exhausted(stand.node_slot[NORTH_SAPLING]), "an emptied row")


func test_the_wood_item_is_resolved_through_the_catalog_boundary() -> void:
	"""The id the fixtures use is the one the verified boundary resolves for `wood`."""
	assert_true(ForestryScript.resolve_wood_id_into(_read), "bound")
	assert_equal(_read.value, WOOD, "the compiled wood id")


func test_two_trunks_on_one_tile_bind_once() -> void:
	"""A second tree on a tile already holding one is left unbound, never overwriting the first."""
	var placements: Array[Dictionary] = [
		{"key": &"oak_mature", "at": Vector2(0.2, 0.2), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(1.8, 1.8), "yaw": 0.0, "size": 1.0},
	]
	var stand := _stand_of(placements)
	assert_equal(stand.count(), 1, "one bound")
	assert_equal(stand.skipped, 1, "one skipped")
	assert_equal(stand.look[0], StandScript.LOOK_OAK, "the first stands")


func test_a_negative_wood_id_binds_nothing() -> void:
	"""An unbound wood item refuses; no row is made."""
	var stand := StandScript.new()
	assert_false(stand.bind_into(_three(), -1, 1, _read), "refused")
	assert_equal(_read.error, StandScript.REFUSE_UNBOUND, "said why")
	assert_equal(stand.nodes.count(), 0, "no rows")


func test_felling_debits_the_wood_once_and_dates_the_stump() -> void:
	"""REQ-SET-138: the store's harvest_all takes all 12 U on the felling day, dates the stump, and the
	wood lies as the trunk; a second fell refuses, and so does the store itself."""
	var stand := _stand_of(_three())
	assert_true(stand.fell_into(0, 5, Vector2(0.0, -1.0), false, _read), "felled")
	assert_equal(_read.value, 12000, "12 U debited")
	assert_equal(stand.trunk_milli[0], 12000, "lying as the trunk")
	assert_equal(stand.state_of(0), StandScript.STATE_STUMP, "a stump")
	var slot: int = stand.node_slot[0]
	assert_equal(stand.nodes.quantity_milli_of(slot).value, 0, "the row is empty")
	assert_equal(stand.nodes.planted_day_of(slot).value, 5, "the stump is dated")
	assert_false(stand.fell_into(0, 6, Vector2.UP, false, _read), "no second fell")
	assert_equal(_read.error, StandScript.REFUSE_NOT_MATURE, "not mature")
	assert_false(stand.nodes.harvest_all(slot, 6).ok, "the store refuses a repeat")
	assert_equal(stand.trunk_milli[0], 12000, "still 12 U lying")
	assert_false(stand.fell_into(2, 5, Vector2.UP, false, _read), "a sapling cannot be felled")


func test_a_stump_regrows_after_48_days_unless_its_spot_is_occupied() -> void:
	"""Felled on day 5, the stump is due on day 53: not a day before; an occupied spot holds it back;
	then the store restores it to 12 U."""
	var stand := _stand_of(_three())
	stand.fell_into(0, 5, Vector2.UP, false, _read)
	var matured := PackedInt32Array()
	assert_equal(stand.regrow_due(52, func(_at: Vector2) -> bool: return false, matured), 0, "nothing held")
	assert_equal(matured, PackedInt32Array([2]), "only the sapling (day 49)")
	assert_equal(stand.state_of(0), StandScript.STATE_STUMP, "day 52: the oak is a stump")
	assert_equal(stand.days_left(0, 52), 1, "a day left")
	matured.clear()
	assert_equal(stand.regrow_due(53, func(_at: Vector2) -> bool: return true, matured), 1, "held back")
	assert_equal(stand.state_of(0), StandScript.STATE_STUMP, "still a stump")
	assert_equal(stand.regrow_due(53, func(_at: Vector2) -> bool: return false, matured), 0, "free")
	assert_equal(matured, PackedInt32Array([0]), "the oak")
	assert_equal(stand.state_of(0), StandScript.STATE_MATURE, "mature again")
	assert_equal(stand.nodes.quantity_milli_of(stand.node_slot[0]).value, 12000, "12 U again")
	assert_equal(stand.stump[0], 0, "no stump")


func test_the_demo_sapling_matures_on_day_49() -> void:
	"""A sapling bound on day 1 is the store's empty row dated day 1: it matures on day 49."""
	var stand := _stand_of(_three())
	var matured := PackedInt32Array()
	stand.regrow_due(48, func(_at: Vector2) -> bool: return false, matured)
	assert_equal(stand.state_of(2), StandScript.STATE_YOUNG, "day 48: young")
	stand.regrow_due(49, func(_at: Vector2) -> bool: return false, matured)
	assert_equal(stand.state_of(2), StandScript.STATE_MATURE, "day 49: mature")
	assert_equal(stand.wood_milli_of(2), 12000, "12 U")


func test_a_blow_down_uproots_the_tree_and_the_spot_can_be_replanted() -> void:
	"""A storm debits the wood once (it lies as a trunk) and destroys the row: the tile is free and
	nothing regrows; planting it on day 9 makes a growing row that matures on day 57."""
	var stand := _stand_of(_three())
	var tile: int = stand.tile[1]
	assert_true(stand.blow_down_into(1, 7, Vector2(1.0, 0.0), _read), "blown down")
	assert_equal(_read.value, 12000, "its wood")
	assert_equal(stand.trunk_milli[1], 12000, "lying free")
	assert_equal(stand.state_of(1), StandScript.STATE_CLEARED, "cleared")
	assert_false(stand.nodes.has_node_at_tile(tile), "the tile is free")
	assert_equal(stand.nodes.count(), 2, "one row fewer")
	assert_true(stand.plant_into(1, 9, _read), "planted")
	assert_equal(_read.value, 57, "matures on day 57")
	assert_equal(stand.state_of(1), StandScript.STATE_YOUNG, "young")
	assert_equal(stand.look[1], StandScript.LOOK_OAK, "an oak sapling where the beech stood")
	assert_equal(stand.nodes.quantity_milli_of(stand.node_slot[1]).value, 0, "holds no wood yet")
	assert_false(stand.plant_into(1, 9, _read), "not twice")
	assert_equal(_read.error, StandScript.REFUSE_NOT_CLEARED, "not cleared")


func test_grubbing_out_a_stump_clears_its_spot() -> void:
	"""A stump dug out frees its tile; a second grub and a grub of a mature tree refuse."""
	var stand := _stand_of(_three())
	assert_false(stand.grub_into(0, _read), "no stump yet")
	stand.fell_into(0, 3, Vector2.UP, false, _read)
	assert_true(stand.grub_into(0, _read), "grubbed")
	assert_equal(stand.state_of(0), StandScript.STATE_CLEARED, "cleared")
	assert_false(stand.nodes.has_node_at_tile(stand.tile[0]), "tile free")
	assert_false(stand.grub_into(0, _read), "nothing left")
	assert_equal(_read.error, StandScript.REFUSE_NO_STUMP, "said so")
	assert_equal(stand.trunk_milli[0], 12000, "the trunk still lies there")


func test_the_trunk_is_hauled_away_a_load_at_a_time_and_nothing_is_lost() -> void:
	"""12 U go in loads of 6, then the trunk refuses; the loads add up to the debit."""
	var stand := _stand_of(_three())
	stand.fell_into(0, 3, Vector2.UP, false, _read)
	var hauled: int = 0
	for trip: int in 2:
		assert_true(stand.take_trunk_into(0, Rules.CARRY_LOAD_MILLI, _read), "load %d" % trip)
		hauled += _read.value
	assert_equal(hauled, 12000, "all of it")
	assert_equal(stand.trunk_milli[0], 0, "gone")
	assert_false(stand.take_trunk_into(0, Rules.CARRY_LOAD_MILLI, _read), "nothing left")
	stand.fell_into(1, 3, Vector2.UP, false, _read)
	stand.take_trunk_into(1, 10000, _read)
	assert_true(stand.take_trunk_into(1, Rules.CARRY_LOAD_MILLI, _read), "the last of it")
	assert_equal(_read.value, 2000, "only what was left")


func test_growth_is_read_from_the_rows_date() -> void:
	"""Planted on day 9: halfway at day 33, 10 per mille twelve hours in, 999 the day before."""
	var stand := _stand_of(_three())
	stand.blow_down_into(0, 9, Vector2.UP, _read)
	stand.plant_into(0, 9, _read)
	assert_equal(stand.growth_permille(0, 33, 0), 500, "24 of 48 days")
	assert_equal(stand.growth_permille(0, 9, 12), 10, "12 hours")
	assert_equal(stand.growth_permille(0, 56, 23), 999, "never 1000 until mature")
	assert_equal(stand.growth_permille(1, 9, 0), 1000, "mature")


# --- zones --------------------------------------------------------------------------------------

func test_zones_are_gdd_zone_types_that_never_overlap() -> void:
	"""FORESTRY is ZoneType 5, CONSERVATION 8; a zone under 2 tiles a side, an overlap, a wrong kind and
	a ninth zone all refuse."""
	var zones := ZonesScript.new()
	assert_equal(ZonesScript.KIND_FORESTRY, 5, "GDD §4.3")
	assert_equal(ZonesScript.KIND_CONSERVATION, 8, "GDD §4.3")
	assert_true(zones.add_into(ZonesScript.KIND_FORESTRY, Vector2i(10, 10), Vector2i(5, 5), "A", _read), "marked")
	assert_equal(zones.x0[_read.value], 5, "corners sorted")
	assert_false(zones.add_into(ZonesScript.KIND_CONSERVATION, Vector2i(10, 10), Vector2i(12, 12), "", _read), "overlap")
	assert_equal(_read.error, ZonesScript.REFUSE_OVERLAP, "said so")
	assert_false(zones.add_into(ZonesScript.KIND_FORESTRY, Vector2i(20, 20), Vector2i(20, 25), "", _read), "one wide")
	assert_equal(_read.error, ZonesScript.REFUSE_TOO_SMALL, "too small")
	assert_false(zones.add_into(2, Vector2i(30, 30), Vector2i(35, 35), "", _read), "forage is not a woods zone")
	for k: int in 7:
		assert_true(zones.add_into(ZonesScript.KIND_CONSERVATION, Vector2i(20 + 3 * k, 40), Vector2i(21 + 3 * k, 41), "", _read), "zone %d" % k)
	assert_false(zones.add_into(ZonesScript.KIND_FORESTRY, Vector2i(100, 100), Vector2i(102, 102), "", _read), "the ninth")
	assert_equal(_read.error, ZonesScript.REFUSE_FULL, "full")
	assert_equal(zones.names[1], "Conservation zone 2", "a made-up name")


func test_the_seeded_zones_hold_the_north_stand_and_the_old_grove() -> void:
	"""The North stand: 5 oaks and beeches and the young oak, keeping 2; the Old grove: 5 trees."""
	var forestry := _forestry()
	assert_equal(forestry.zones.names[0], "North stand", "forestry")
	assert_equal(forestry.zones.floor_text(forestry.stand, 0), "5 of 6 trees mature, keeps 2 (20%)", "its floor")
	assert_equal(forestry.zones.floor_text(forestry.stand, 1), "5 trees, never cut", "the grove")
	for t: int in NORTH_TREES:
		assert_true(forestry.zones.zone_at_tile_into(forestry.stand.tile[t], _read) and _read.value == 0, "tree %d north" % t)


func test_the_floor_refuses_the_fell_that_would_breach_it_and_intensive_lowers_it() -> void:
	"""Six trees keep two: three fells go (queued fells count), the fourth refuses with the zone's words;
	the intensive override (10%) lets one more go and then refuses."""
	var forestry := _forestry()
	var crew: CrewScript = forestry.crew
	var none := PackedInt32Array()
	for k: int in 3:
		var said: String = crew.order(JobsScript.KIND_FELL, NORTH_TREES[k], 0, none, JobsScript.ORIGIN_PLAYER)
		assert_equal(said, "Fell queued: the forestry crew will see to it", "fell %d" % k)
	var refused: String = crew.order(JobsScript.KIND_FELL, NORTH_TREES[3], 0, none, JobsScript.ORIGIN_PLAYER)
	assert_equal(refused, "Can't fell: North stand must keep 2 of its 6 trees standing (20%)", "the floor")
	assert_true(forestry.zones.set_intensive(0, true), "intensive")
	assert_equal(crew.order(JobsScript.KIND_FELL, NORTH_TREES[3], 0, none, JobsScript.ORIGIN_PLAYER),
		"Fell queued: the forestry crew will see to it", "10%: one more")
	assert_equal(crew.order(JobsScript.KIND_FELL, NORTH_TREES[4], 0, none, JobsScript.ORIGIN_PLAYER),
		"Can't fell: North stand must keep 1 of its 6 trees standing (10%)", "and no further")
	assert_equal(crew.jobs.live_count(), 4, "four on the board")
	assert_equal(crew.refusal_for(JobsScript.KIND_FELL, NORTH_TREES[2], 0), "", "a queued fell does not count against itself")


func test_a_tree_beyond_the_reach_is_refused() -> void:
	"""Only trees within 30 m of the square are worked."""
	var forestry := _forestry()
	var far: int = -1
	for t: int in forestry.stand.count():
		var at: Vector2 = forestry.stand.at[t]
		if far < 0 and forestry.stand.state_of(t) == StandScript.STATE_MATURE and maxf(absf(at.x), absf(at.y)) > 31.0:
			far = t
	assert_true(far >= 0, "a far tree")
	assert_equal(forestry.crew.order(JobsScript.KIND_FELL, far, 0, PackedInt32Array([0]), JobsScript.ORIGIN_PLAYER),
		"Can't fell: it stands beyond the village's reach (30 m)", "refused")


func test_conservation_trees_are_never_cut_by_order_or_routine() -> void:
	"""A conservation zone refuses every fell and cannot be switched to auto-fell."""
	var forestry := _forestry()
	var said: String = forestry.crew.order(JobsScript.KIND_FELL, OLD_GROVE_OAK, 0, PackedInt32Array(), JobsScript.ORIGIN_PLAYER)
	assert_equal(said, "Can't fell: Old grove is a conservation zone — never cut", "protected")
	assert_false(forestry.zones.set_auto(1, true), "no auto-fell there")
	forestry.zones.set_auto(0, true)
	forestry.crew.raise_routine_jobs()
	for row: int in JobsScript.MAX_JOBS:
		if forestry.crew.jobs.kind[row] == JobsScript.KIND_FELL:
			assert_true(forestry.zones.zone_at_tile_into(forestry.stand.tile[forestry.crew.jobs.target[row]], _read) and _read.value == 0,
				"the routine fell is in the forestry zone")
	assert_equal(forestry.crew.jobs.live_count(), 1, "one routine fell at a time")


func test_an_auto_fell_zone_is_worked_down_to_its_floor_and_no_further() -> void:
	"""With auto-fell on, the routine crew takes the North stand's trees nearest the log stack, one on
	the board at a time, until two of six stand."""
	var forestry := _forestry()
	forestry.zones.set_auto(0, true)
	var felled: int = 0
	for round: int in 6:
		forestry.crew.raise_routine_jobs()
		if not forestry.crew.jobs.find_into(JobsScript.KIND_FELL, _first_fell_target(forestry), _read):
			break
		var t: int = forestry.crew.jobs.target[_read.value]
		forestry.crew.jobs.close(_read.value)
		forestry.stand.fell_into(t, 2, Vector2.UP, false, _read)
		forestry.stand.take_trunk_into(t, 12000, _read)
		felled += 1
	assert_equal(felled, 3, "three of the five mature")
	forestry.crew.raise_routine_jobs()
	assert_equal(forestry.crew.jobs.live_count(), 0, "the floor holds")


func _first_fell_target(forestry: ForestryScript) -> int:
	"""The target of the first fell on the board (-1: none)."""
	for row: int in JobsScript.MAX_JOBS:
		if forestry.crew.jobs.kind[row] == JobsScript.KIND_FELL:
			return forestry.crew.jobs.target[row]
	return -1


# --- deadfall -----------------------------------------------------------------------------------

func test_deadfall_falls_under_trees_seeded_and_is_gathered_once() -> void:
	"""Three piles fall 6..8.5 m from their tree, 1..2 U in quarter steps, the same every run; a pile
	gathered is gone, and its old generation refuses."""
	var a := DeadfallScript.new()
	var b := DeadfallScript.new()
	var sources := PackedVector2Array([Vector2(-22.0, 3.0), Vector2(0.0, -24.0)])
	var anywhere := func(_at: Vector2) -> bool: return true
	assert_equal(a.spawn(3, sources, anywhere), 3, "three")
	b.spawn(3, sources, anywhere)
	for pile: int in 3:
		assert_equal(a.at[pile], b.at[pile], "pile %d where it fell before" % pile)
		assert_true(a.milli[pile] >= 1000 and a.milli[pile] <= 2000 and a.milli[pile] % 250 == 0, "pile %d's wood" % pile)
		var d: float = minf(a.at[pile].distance_to(sources[0]), a.at[pile].distance_to(sources[1]))
		assert_true(d >= 6.0 - 1e-4 and d <= 8.5 + 1e-4, "at a crown's edge")
	var gen: int = a.generation[0]
	var amount: int = a.milli[0]
	assert_true(a.take_into(0, gen, _read), "gathered")
	assert_equal(_read.value, amount, "all of it")
	assert_false(a.take_into(0, gen, _read), "once")
	assert_equal(a.live_count(), 2, "two left")
	a.spawn(1, sources, anywhere)
	assert_equal(a.generation[0], gen + 1, "a new pile in the gathered pile's row")
	assert_false(a.take_into(0, gen, _read), "the old pile's name does not take the new one")
	assert_true(a.take_into(0, gen + 1, _read), "the new one is taken by its own")
	assert_equal(a.spawn(3, sources, func(_at: Vector2) -> bool: return false), 0, "nowhere to fall")
	assert_equal(a.spawn(20, sources, anywhere), 8, "never more than ten lying")


# --- skills -------------------------------------------------------------------------------------

func test_skills_start_with_the_forester_and_the_beaver_and_anyone_learns() -> void:
	"""The forester and the beaver start at felling 3 and sawing 2; a mouse starts at 0, and 500 WU of
	felling (5000 XP) make it level 1. Only the beaver gnaws."""
	var skills := SkillsScript.new()
	skills.setup([&"squirrel_forester", &"mouse_keeper", &"beaver_bridgewright"], PackedStringArray(["squirrel", "mouse", "beaver"]))
	assert_equal(skills.level_of(0, Rules.SKILL_FELLING), 3, "forester fells")
	assert_equal(skills.level_of(0, Rules.SKILL_SAWING), 2, "forester saws")
	assert_equal(skills.level_of(2, Rules.SKILL_FELLING), 3, "the beaver fells")
	assert_equal(skills.level_of(1, Rules.SKILL_FELLING), 0, "the mouse starts at 0")
	assert_false(skills.add_work(1, Rules.SKILL_FELLING, 120), "one tree: no level")
	assert_equal(skills.xp_of(1, Rules.SKILL_FELLING), 1200, "10 XP a WU")
	assert_true(skills.add_work(1, Rules.SKILL_FELLING, 380), "500 WU: level 1")
	assert_equal(skills.line_of(1), "Felling 1 · Sawing 0 · XP 5000/20000", "the panel's line")
	assert_equal(skills.short_of(0), "fell 3/saw 2", "the list's")
	assert_true(skills.gnaws_wood(2) and not skills.gnaws_wood(0) and not skills.gnaws_wood(1), "the beaver gnaws")
	assert_false(skills.add_work(7, Rules.SKILL_FELLING, 10), "no such resident")


# --- the one stock ------------------------------------------------------------------------------

func test_the_demo_stores_take_wood_in_and_saw_planks_out_all_or_nothing() -> void:
	"""Wood in, a sawing draw that is all or nothing, planks in and paid all or nothing; the panels'
	line names all three."""
	var stores := StoresScript.new()
	stores.add_wood(12000)
	assert_equal(stores.wood_milli_u, 52000, "40 U and a tree")
	assert_false(stores.take_wood(60000), "not that much")
	assert_equal(stores.wood_milli_u, 52000, "nothing taken")
	assert_true(stores.take_wood(2000), "a batch")
	stores.add_planks(2000)
	assert_true(stores.can_pay_planks(2000) and not stores.can_pay_planks(2001), "exactly two")
	assert_false(stores.pay_planks(2500), "refused whole")
	assert_true(stores.pay_planks(500), "paid")
	assert_equal(stores.plank_milli_u, 1500, "left")
	assert_equal(stores.stock_line(), "Demo stores: wood 50.0 U · stone 20.0 U · planks 1.5 U", "the line")
	stores.add_wood(-5)
	assert_equal(stores.wood_milli_u, 50000, "a negative intake is nothing")


func test_the_services_hold_one_stores_for_the_woods_and_the_tunnels() -> void:
	"""The woods put their wood where the tunnels' bracing pays from: one object, and a load the woods
	stack is wood the tunnels can spend."""
	var forestry := _forestry()
	assert_true(forestry.crew._stores == _services.stores, "the woods' stores are the services'")
	var command: CommandScript = _keep(CommandScript.new()) as CommandScript
	command.configure(forestry._cast, _keep(Camera3D.new()) as Camera3D, null, _services)
	var works: WorksScript = command.tunnels().ext.works
	assert_true(works.stores == _services.stores, "the tunnel works' stores are the services'")
	_services.stores.add_wood(12000)
	assert_equal(works.stores.wood_milli_u, 52000, "the tunnels see the woods' wood")


func test_the_woods_circles_join_the_cast_without_repeating_the_worlds() -> void:
	"""The woods' extra circles are the ones the world's obstacles leave out -- none reaches the play
	area's report margin -- out to the reach and its margin, plus the yard's six."""
	var world := _world()
	var extra: Array[Vector3] = ForestryScript.extra_obstacles(world)
	assert_equal(extra.size(), 105, "99 woods circles and the yard's 6")
	var reach: float = Rules.REACH_M + Rules.WORK_MARGIN_M + 3.0
	for k: int in extra.size() - 6:
		var c: Vector3 = extra[k]
		assert_false(DemoWorldScript.Layout.circle_reaches_play(DemoWorldScript.layout_circle(c)), "circle %d is new" % k)
		assert_true(absf(c.x) <= reach + c.y and absf(c.z) <= reach + c.y, "circle %d within the reach" % k)


# --- the crew, with the cast --------------------------------------------------------------------

func test_a_resident_fells_the_west_oak_and_hauls_it_all_to_the_stores() -> void:
	"""Right-click order with one resident: it walks to the oak, fells it (12 U debited once, a stump
	dated), turns hauler and carries three loads to the log stack; the stores gain exactly 12 U and it
	learns 1200 XP of felling."""
	var forestry := _forestry()
	var said: String = forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	assert_equal(said, "Fell: Placeholder 0 is on it", "ordered")
	assert_true(_run(forestry, func() -> bool: return forestry.stand.state_of(WEST_OAK) == StandScript.STATE_STUMP), "felled")
	assert_true(forestry.crew.jobs.of_worker_into(0, _read), "still on the job")
	assert_equal(forestry.crew.jobs.kind[_read.value], JobsScript.KIND_HAUL, "now hauling")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "all hauled")
	assert_equal(_services.stores.wood_milli_u, 52000, "40 U + 12 U")
	assert_equal(forestry.stand.trunk_milli[WEST_OAK], 0, "nothing left lying")
	assert_equal(forestry.crew.skills.xp_of(0, Rules.SKILL_FELLING), 1200, "120 WU learned")
	assert_true(_feed_has("Placeholder 0 felled the oak at the woods' edge: 12.0 U of wood lie ready to haul", NoticesScript.LEVEL_NOTE), "posted")
	assert_true(_feed_has("The oak's logs are all stacked: the demo stores hold 52.0 U of wood", NoticesScript.LEVEL_NOTE), "stacked")


func test_the_others_selected_wait_by_the_tree_and_haul_it_with_the_feller() -> void:
	"""Felling with three selected: the nearest fells, two wait (not in the fall) and haul; the stores
	still gain exactly 12 U."""
	var forestry := _forestry()
	var said: String = forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0, 1, 2]))
	assert_true(said.ends_with("; 2 waiting to haul"), "two wait: " + said)
	assert_equal(forestry.crew.jobs.on_target(JobsScript.KIND_HAUL, WEST_OAK), 2, "two hauls")
	assert_true(_run(forestry, func() -> bool: return forestry.stand.state_of(WEST_OAK) == StandScript.STATE_STUMP), "felled")
	assert_equal(forestry.crew.jobs.on_target(JobsScript.KIND_HAUL, WEST_OAK), 3, "the two waited for the fall; the feller joins them")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "done")
	assert_equal(_services.stores.wood_milli_u, 52000, "12 U, once")


func test_a_right_click_on_a_tree_being_felled_joins_the_haul() -> void:
	"""A second order on a tree someone is felling sends the newcomers to wait and haul it."""
	var forestry := _forestry()
	forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	assert_equal(forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([1])), "Haul logs: 1 on it", "joins the haul")
	assert_equal(forestry.crew.jobs.on_target(JobsScript.KIND_FELL, WEST_OAK), 1, "still one fell")


func test_a_hauler_loads_on_the_log_stacks_side_of_the_trunk() -> void:
	"""The load is taken up on the side facing the log stack -- even by a hauler standing on the far
	side -- so the carry sets off away from the trunk, not through it."""
	var forestry := _forestry()
	forestry.stand.fell_into(WEST_OAK, 1, Vector2(-1.0, 0.0), false, _read)
	var middle: Vector2 = Roots.trunk_middle(forestry.stand, WEST_OAK)
	var actor := forestry._cast.actor(5) as DemoActorScript
	actor.place(middle + Vector2(0.0, -4.0), 0.0, -1, -1)
	forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([5]))
	assert_true(forestry.crew.jobs.issued[0] == 1 or _run(forestry, func() -> bool: return forestry.crew.jobs.issued[0] == 1), "the walk issued")
	var stack: Vector2 = Yard.log_stack_at()
	assert_true(forestry.crew.jobs.goal[0].distance_to(stack) < middle.distance_to(stack) - 1.0, "on the stack's side")


func test_a_resident_ordered_away_drops_the_job_where_it_had_got_to() -> void:
	"""Called away mid-haul, the load stays with the job; the haul cancelled, it is still not in store
	(decision 0222) -- the hauler, taking the job back, stacks it."""
	var forestry := _forestry()
	forestry.stand.fell_into(WEST_OAK, 1, Vector2(-1.0, 0.0), false, _read)
	forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([1]))
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.load_milli[_haul_row(forestry)] > 0 \
		and forestry.crew.jobs.issued[_haul_row(forestry)] == 1), "loaded and carrying")
	var brain: BrainScript = forestry.crew.brain_of(1)
	brain.order_move(Vector2(0.0, 2.0))
	forestry.step(100000)
	var row: int = _haul_row(forestry)
	assert_equal(forestry.crew.jobs.worker[row], JobsScript.NOBODY, "back on the board")
	assert_equal(forestry.crew.jobs.load_milli[row], 6000, "the load kept")
	forestry.crew.cancel_all()
	assert_equal(_services.stores.wood_milli_u, 40000, "not credited at the cancel")
	assert_equal(forestry.crew.jobs.kind[row], JobsScript.KIND_CARRY_LOGS, "the load's delivery waits")
	brain.work_done()
	assert_equal(forestry.crew.jobs.worker[row], 1, "the hauler took it back")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u, 46000, "the load went into store")
	assert_equal(forestry.stand.trunk_milli[WEST_OAK], 6000, "the rest still lies there")


func _haul_row(forestry: ForestryScript) -> int:
	"""The first haul on the board."""
	for row: int in JobsScript.MAX_JOBS:
		if forestry.crew.jobs.kind[row] == JobsScript.KIND_HAUL:
			return row
	return 0


func test_the_beaver_fells_by_gnawing_with_no_axe() -> void:
	"""The same felling job: a gnawer's tree lies as the gnawed log, and it holds no tool while it
	works; anyone else fells with the axe in hand."""
	var forestry := _forestry()
	forestry.crew.skills.gnaws[0] = 1
	forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	var actor := forestry._cast.actor(0) as DemoActorScript
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.issued[0] == 1 and forestry.crew.jobs.current_step(0) == JobsScript.STEP_WORK), "gnawing")
	assert_false(actor.work_tool_shown(), "no axe")
	assert_equal(actor.brain.clip, CrewScript.CLIP_WORK, "the gnawing clip")
	assert_true(_run(forestry, func() -> bool: return forestry.stand.state_of(WEST_OAK) == StandScript.STATE_STUMP), "down")
	assert_equal(forestry.stand.gnawed[WEST_OAK], 1, "the gnawed look")
	var other := _forestry()
	other.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	var axeman := other._cast.actor(0) as DemoActorScript
	assert_true(_run(other, func() -> bool: return other.crew.jobs.issued[0] == 1 and other.crew.jobs.current_step(0) == JobsScript.STEP_WORK), "chopping")
	assert_true(axeman.work_tool_shown(), "the axe in hand")
	assert_equal(axeman.brain.clip, CrewScript.CLIP_CHOP, "the chopping clip")
	other._feed_chips()
	assert_true(other.view.fx.chipping(WEST_OAK), "chips fly at the oak")


func test_deadfall_is_gathered_into_the_stores_without_felling() -> void:
	"""A pile gathered: its wood goes into the stores, no tree is touched."""
	var forestry := _forestry()
	var pile: int = 0
	var amount: int = forestry.deadfall.milli[pile]
	var said: String = forestry.order_on(PickScript.KIND_PILE, pile, PackedInt32Array([2]))
	assert_equal(said, "Gather deadfall: Placeholder 2 is on it", "ordered")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "done")
	assert_equal(_services.stores.wood_milli_u, 40000 + amount, "its wood")
	assert_equal(forestry.deadfall.live_count(), 2, "one pile fewer")
	assert_equal(forestry.stand.nodes.count(), 173, "no tree touched")


func test_sawing_turns_two_units_of_logs_into_planks() -> void:
	"""Logs from the stock to the sawhorse, sawn, the planks to the stack: wood 38 U, planks 2 U, and
	400 XP of sawing."""
	var forestry := _forestry()
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "sawn")
	assert_equal(_services.stores.wood_milli_u, 38000, "2 U of logs")
	assert_equal(_services.stores.plank_milli_u, 2000, "2 U of planks")
	assert_equal(forestry.crew.skills.xp_of(3, Rules.SKILL_SAWING), 400, "40 WU learned")
	_services.stores.wood_milli_u = 1999
	assert_equal(forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3])),
		"Can't saw planks: the demo stores hold under 2.0 U of wood", "not enough")


func test_a_sawing_called_off_carries_its_load_away_as_what_it_is() -> void:
	"""Decision 0222 (the review's F24): cancelled while carrying the logs, they are carried back to the
	log stack as wood; cancelled while carrying the planks, they are carried on to the plank stack. The
	stores are credited on arrival, never at the cancel; nothing is lost either way."""
	var forestry := _forestry()
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.load_milli[0] > 0), "logs in hand")
	forestry.crew.cancel_all()
	assert_equal(_services.stores.wood_milli_u, 38000, "not back yet")
	assert_equal(forestry.crew.jobs.kind[0], JobsScript.KIND_CARRY_LOGS, "carried back")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u, 40000, "the logs went back")
	assert_equal(_services.stores.plank_milli_u, 0, "no planks")
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.current_step(0) == JobsScript.STEP_CARRY_PLANKS), "planks in hand")
	forestry.crew.cancel_all()
	assert_equal(_services.stores.plank_milli_u, 0, "not stacked yet")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u, 38000, "the logs were sawn")
	assert_equal(_services.stores.plank_milli_u, 2000, "the planks went into store")


func test_a_storm_blows_a_tree_down_and_the_crew_clears_it() -> void:
	"""A gust uproots one mature tree within reach (seeded), posts a warning, drops deadfall, and the
	routine crew hauls the free wood into the stores."""
	var forestry := _forestry()
	var piles: int = forestry.deadfall.live_count()
	var t: int = forestry.storm("A test gust")
	assert_true(t >= 0, "a tree fell")
	assert_equal(forestry.stand.state_of(t), StandScript.STATE_CLEARED, "uprooted")
	assert_equal(forestry.stand.trunk_milli[t], 12000, "its wood lies free")
	assert_equal(forestry.deadfall.live_count(), piles + 3, "deadfall down")
	var warned: bool = false
	for k: int in _services.notices.count():
		warned = warned or (_services.notices.level(k) == NoticesScript.LEVEL_WARNING and _services.notices.text(k).begins_with("A test gust blew down"))
	assert_true(warned, "a warning in the feed")
	assert_equal(forestry.crew.jobs.on_target(JobsScript.KIND_HAUL, t), 1, "a clearing job")
	forestry.crew.set_crew(PackedInt32Array([4]))
	assert_true(_run(forestry, func() -> bool: return forestry.stand.trunk_milli[t] == 0 and forestry.crew.jobs.live_count() == 0), "cleared")
	assert_equal(_services.stores.wood_milli_u, 52000, "free wood in")


func test_a_storm_day_on_the_one_weather_blows_one_tree_down() -> void:
	"""The first hour the weather reads a heavy rain/storm day, one tree comes down -- once that day."""
	var forestry := _forestry()
	_services.weather.observe(0, 3, 12, 90, 3200, WeatherCore.EVENT_HEAVY_RAIN)
	var mature_before: int = _mature(forestry)
	forestry._hour_index = -1
	forestry.step(0)
	assert_equal(_mature(forestry), mature_before - 1, "one down")
	forestry._hour_index = -1
	forestry.step(0)
	assert_equal(_mature(forestry), mature_before - 1, "not twice in a day")


func _mature(forestry: ForestryScript) -> int:
	"""How many trees are mature."""
	var counts := PackedInt32Array()
	forestry.stand.counts_into(counts)
	return counts[StandScript.STATE_MATURE]


func test_replanting_a_cleared_spot_spends_the_farms_compost() -> void:
	"""Planting takes 0.25 U of compost as it starts and makes a young oak maturing on day 49; with no
	compost the order refuses."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	forestry.stand.take_trunk_into(WEST_OAK, 12000, _read)
	assert_equal(forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0])),
		"Can't plant a sapling: no compost to plant with (0.25 U needed)", "no compost wired")
	var compost := PackedInt64Array([1000])
	forestry.crew.set_compost(func() -> int: return compost[0],
		func(milli: int) -> bool:
			if compost[0] < milli:
				return false
			compost[0] -= milli
			return true)
	assert_equal(forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0])), "Plant a sapling: Placeholder 0 is on it", "ordered")
	assert_true(_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "planted")
	assert_equal(compost[0], 750, "0.25 U spent")
	assert_equal(forestry.stand.state_of(WEST_OAK), StandScript.STATE_YOUNG, "a young oak")
	assert_equal(forestry.stand.days_left(WEST_OAK, 1), 48, "matures on day 49")


func test_the_woods_regrow_on_the_calendars_midnights() -> void:
	"""The calendar's day sweep: a stump felled on day 1 regrows at the midnight that starts day 49,
	with a note in the feed."""
	var forestry := _forestry()
	forestry.stand.fell_into(WEST_OAK, 1, Vector2.UP, false, _read)
	forestry.daily(48)
	assert_equal(forestry.stand.state_of(WEST_OAK), StandScript.STATE_STUMP, "day 48")
	forestry.daily(49)
	assert_equal(forestry.stand.state_of(WEST_OAK), StandScript.STATE_MATURE, "day 49")
	assert_true(_feed_has("4 trees have grown to maturity: their 48 days are up", NoticesScript.LEVEL_NOTE), "the oak and the three saplings")


func test_the_woods_follow_the_calendar_they_do_not_run_it() -> void:
	"""Days crossed on the one calendar each get their sweep, in order; the woods never move it."""
	var forestry := _forestry()
	var tick: int = _services.calendar.tick
	forestry.step(10000000)
	assert_equal(_services.calendar.tick, tick, "the calendar did not move")
	assert_equal(forestry.day(), 1, "day 1")
	_services.calendar.tick = 3 * 18000
	forestry.step(0)
	assert_equal(forestry.day(), 4, "three midnights crossed")
	assert_equal(forestry.deadfall.live_count(), 6, "three opening piles and one a day")


# --- drawings -----------------------------------------------------------------------------------

func test_a_felled_tree_topples_then_lies_as_its_trunk_by_a_fresh_stump() -> void:
	"""After the fell the tree falls for 2.4 s (demo time) and lies 1.4 s; then the trunk shows, the
	tree hides and a fresh stump stands, mossy after a season."""
	var forestry := _forestry()
	var view: ViewScript = forestry.view
	forestry.stand.fell_into(WEST_OAK, 1, Vector2(-1.0, 0.0), false, _read)
	view.sync(1, 7)
	assert_true(view.is_falling(WEST_OAK), "falling")
	assert_equal(view.stump_key(WEST_OAK), &"oak_stump_fresh", "a fresh stump")
	assert_false(view.trunk_visible(WEST_OAK), "no trunk mid-fall")
	view.advance(2.0)
	assert_true(view.is_falling(WEST_OAK), "still falling")
	view.advance(0.6)
	assert_true(view.has_landed(WEST_OAK) and view.is_falling(WEST_OAK), "landed, lying a moment")
	assert_false(view.trunk_visible(WEST_OAK), "not yet the trunk")
	view.advance(1.3)
	assert_false(view.is_falling(WEST_OAK), "down")
	assert_true(view.trunk_visible(WEST_OAK), "the trunk lies there")
	assert_false(view.tree_visible(WEST_OAK), "the tree is gone")
	view.sync(12, 7)
	assert_equal(view.stump_key(WEST_OAK), &"oak_stump_fresh", "fresh for eleven days")
	view.sync(13, 7)
	assert_equal(view.stump_key(WEST_OAK), &"stump_mossy", "mossy after twelve days")
	assert_equal(view.fx.bursts(), 1, "one burst of leaves where it landed")
	assert_true(view.young_visible(WEST_OAK), "a shoot grows beside it")


func test_a_paused_clock_holds_a_tree_in_mid_fall() -> void:
	"""No demo time, no fall."""
	var forestry := _forestry()
	forestry.stand.fell_into(WEST_OAK, 1, Vector2(-1.0, 0.0), false, _read)
	forestry.view.sync(1, 7)
	forestry.view.advance(0.0)
	forestry.view.advance(0.0)
	assert_true(forestry.view.is_falling(WEST_OAK), "held")
	assert_equal(forestry.view.falls_live(), 1, "one fall")


func test_the_yard_shows_the_stock_logs_and_the_plank_stack_by_the_stores() -> void:
	"""40 U: the woodpile half its height; no planks, no stack; 4 U of planks: a fifth of its height;
	80 U: the woodpile full."""
	var forestry := _forestry()
	forestry.yard_view.refresh()
	assert_almost_equal(forestry.yard_view.log_pile_share(), 0.5, "40 of 80 U")
	assert_equal(forestry.yard_view.plank_stack_share(), 0.0, "no planks")
	_services.stores.add_planks(4000)
	_services.stores.add_wood(40000)
	forestry.yard_view.refresh()
	assert_almost_equal(forestry.yard_view.plank_stack_share(), 0.2, "4 of 20 U")
	assert_almost_equal(forestry.yard_view.log_pile_share(), 1.0, "full at 80 U")
	_services.stores.take_wood(79000)
	forestry.yard_view.refresh()
	assert_almost_equal(forestry.yard_view.log_pile_share(), 0.12, "a sliver at 1 U")
	assert_equal(forestry.yard_view.piles_visible(), 3, "the opening deadfall")


func test_the_yard_stands_clear_of_the_village() -> void:
	"""Every yard piece keeps clear of the world's obstacles and off the worn paths."""
	var world := _world()
	var circles: Array[Vector3] = world.obstacles()
	for piece: int in Yard.PIECES.size():
		var at: Vector2 = Yard.at(piece)
		var r: float = float((Yard.PIECES[piece] as Array)[3])
		for c: Vector3 in circles:
			assert_true(Vector2(c.x, c.z).distance_to(at) >= c.y + r - 0.05, "%s clear of (%.1f, %.1f)" % [Yard.key(piece), c.x, c.z])
		assert_true(DemoWorldScript.Layout.path_distance(at) >= r - 0.3, "%s off the paths" % Yard.key(piece))


func test_the_pick_finds_trunks_piles_the_sawhorse_and_spots() -> void:
	"""On the ground: a lying trunk along its fall, a pile, the sawhorse, a stump's spot; nothing on
	bare ground."""
	var forestry := _forestry()
	var picker := PickScript.new()
	forestry.stand.fell_into(WEST_OAK, 1, Vector2(-1.0, 0.0), false, _read)
	var at: Vector2 = forestry.stand.at[WEST_OAK]
	assert_equal(picker.pick_ground(at + Vector2(-7.0, 0.5), forestry.stand, forestry.deadfall), PickScript.KIND_TRUNK, "the trunk beyond the mound")
	assert_equal(picker.index, WEST_OAK, "its tree")
	assert_equal(picker.pick_ground(forestry.deadfall.at[1], forestry.stand, forestry.deadfall), PickScript.KIND_PILE, "a pile")
	assert_equal(picker.index, 1, "that pile")
	assert_equal(picker.pick_ground(Yard.at(Yard.SAWHORSE), forestry.stand, forestry.deadfall), PickScript.KIND_SAW, "the sawhorse")
	assert_equal(picker.pick_ground(forestry.stand.at[NORTH_SAPLING], forestry.stand, forestry.deadfall), PickScript.KIND_TREE, "a spot")
	assert_equal(picker.pick_ground(Vector2(0.0, 4.0), forestry.stand, forestry.deadfall), PickScript.KIND_NONE, "the square")


func test_a_camera_ray_through_a_standing_tree_picks_it() -> void:
	"""A ray from above-south through an oak's trunk takes the oak before the ground behind it."""
	var forestry := _forestry()
	var picker := PickScript.new()
	var at: Vector2 = forestry.stand.at[WEST_OAK]
	var origin := Vector3(at.x, 12.0, at.y + 14.0)
	var direction: Vector3 = (Vector3(at.x, 3.0, at.y) - origin).normalized()
	assert_equal(picker.pick(origin, direction, forestry.stand, forestry.deadfall), PickScript.KIND_TREE, "the tree")
	assert_equal(picker.index, WEST_OAK, "that oak")


func test_the_zone_tool_marks_a_dragged_rectangle_in_whole_tiles() -> void:
	"""Armed, pressed, dragged and released: a forestry zone over the tiles swept; over the North stand
	it is refused; pressed again, the tool disarms."""
	var zones := ZonesScript.new()
	var tool := ZoneToolScript.new()
	assert_true(tool.arm(ZonesScript.KIND_FORESTRY), "armed")
	assert_true(tool.press(Vector2(-27.0, 10.0)), "pressed")
	assert_true(tool.move(Vector2(-21.5, 20.5)), "dragged")
	assert_true(tool.would_mark(zones), "it would take")
	assert_equal(tool.rect_m(), Rect2(Vector2(-28.0, 10.0), Vector2(8.0, 12.0)), "whole tiles")
	assert_true(tool.release(zones, "", _read), "marked")
	assert_equal(Vector4i(zones.x0[0], zones.z0[0], zones.x1[0], zones.z1[0]), Vector4i(50, 69, 53, 74), "tiles")
	assert_false(tool.is_armed(), "put away")
	tool.arm(ZonesScript.KIND_CONSERVATION)
	tool.press(Vector2(-25.0, 12.0))
	tool.move(Vector2(-10.0, 14.5))
	assert_false(tool.would_mark(zones), "overlapping")
	assert_false(tool.release(zones, "", _read), "refused")
	assert_equal(_read.error, ZonesScript.REFUSE_OVERLAP, "the overlap")
	assert_true(tool.arm(ZonesScript.KIND_FORESTRY), "armed again")
	assert_false(tool.arm(ZonesScript.KIND_FORESTRY), "pressed twice: off")


func test_the_marks_draw_zones_the_overlay_discs_and_the_ring() -> void:
	"""The overlay shows a disc per tree; a tree selected is ringed; the drag preview shows and hides."""
	var forestry := _forestry()
	forestry.marks.refresh()
	assert_equal(forestry.marks.discs_shown(), 0, "overlay off")
	forestry.set_overlay(true)
	assert_equal(forestry.marks.discs_shown(), 173, "a disc per tree")
	forestry.select_tree(WEST_OAK)
	assert_true(forestry.marks.ring_shown(), "ringed")
	forestry.select_tree(-1)
	assert_false(forestry.marks.ring_shown(), "let go")
	forestry.marks.show_preview(Rect2(0, 0, 4, 4), true)
	assert_true(forestry.marks.preview_shown(), "preview")
	forestry.disarm_tool()
	assert_false(forestry.marks.preview_shown(), "gone")


# --- panel, tab and command layer ---------------------------------------------------------------

func test_the_woods_panel_says_what_the_selected_tree_can_take() -> void:
	"""The west oak: mature, 12 U, outside any zone, Fell enabled; the Old grove's oak: Fell disabled
	with the reason; the counts and the stock read the real numbers."""
	var forestry := _forestry()
	forestry.select_tree(WEST_OAK)
	forestry.refresh_panel()
	var panel: PanelScript = forestry.panel
	assert_equal(panel.line(&"tree_title"), "Oak — mature, 12.0 U", "the title")
	assert_equal(panel.line(&"tree"), "Outside any zone: fell freely", "its zone")
	assert_false(panel.button(PanelScript.ACTION_FELL).disabled, "fell")
	assert_true(panel.button(PanelScript.ACTION_PLANT).disabled, "no planting")
	assert_equal(panel.line(&"counts"), "Standing: 170 mature · 3 young\nFelled: 0 stumps · 0 cleared · trunks 0.0 U\nDeadfall: 3 piles, %s" % Rules.units_text(forestry.deadfall.total_milli()), "counts")
	assert_true(panel.line(&"stores").begins_with("Demo stores: wood 40.0 U · planks 0.0 U"), "the stock")
	forestry.select_tree(OLD_GROVE_OAK)
	forestry.refresh_panel()
	assert_true(panel.button(PanelScript.ACTION_FELL).disabled, "protected")
	assert_true(panel.line(&"tree").ends_with("Can't fell: Old grove is a conservation zone — never cut"), "and why")


func test_the_right_column_has_a_woods_tab() -> void:
	"""Four tabs since the water's (decision 0196, water part A): Farm, Tunnels & burrows, Woods, Water;
	showing the woods hides the other three."""
	var zone: DetailZoneScript = _keep(DetailZoneScript.new()) as DetailZoneScript
	zone.build()
	var panels: Array[PanelScript] = []
	for k: int in 4:
		var panel: PanelScript = _keep(PanelScript.new()) as PanelScript
		panel.build()
		zone.add_panel(k, panel)
		panels.append(panel)
	assert_equal(DetailZoneScript.TAB_TEXT, ["Farm", "Tunnels", "Woods", "Water"] as Array[String], "four tabs")
	zone.show_panel(DetailZoneScript.PANEL_WOODS)
	assert_true(panels[2].is_shown() and not panels[0].is_shown() and not panels[1].is_shown()
		and not panels[3].is_shown(), "the woods alone")
	assert_true(zone.tab(DetailZoneScript.PANEL_WOODS).button_pressed, "its tab in brass")


func test_the_command_layer_asks_every_ground_handler_in_turn() -> void:
	"""The farm's handler first, the woods' second: a click the first declines reaches the second; the
	"doing" words and the skills come through too."""
	var world := _world()
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var command: CommandScript = _keep(CommandScript.new()) as CommandScript
	var camera: Camera3D = _keep(Camera3D.new()) as Camera3D
	command.configure(cast, camera, null, _services)
	var asked: Array[String] = []
	command.set_ground_handlers(func(_at: Vector2) -> bool: asked.append("farm"); return false,
		func(_at: Vector2) -> bool: return false)
	command.add_ground_handlers(func(_at: Vector2) -> bool: asked.append("woods"); return true,
		func(_at: Vector2) -> bool: return false)
	command.add_task_text(func(who: int) -> String: return "Felling the oak" if who == 1 else "")
	command.set_skill_text(func(who: int, alone: bool) -> String: return "Felling 3" if alone else "fell 3")
	command.select(PackedInt32Array([1]))
	assert_true(command._ground_clicked(Vector2.ZERO), "taken by the woods")
	assert_equal(asked, ["farm", "woods"] as Array[String], "in turn")
	var entries: Array[Dictionary] = command.party_entries()
	assert_equal(entries[0]["state"], "Felling the oak", "the woods' words")
	assert_equal(PartyPanelScript.party_lines(entries), PackedStringArray(["Placeholder 1", "Placeholder", "Felling the oak", "Felling 3"]), "the skills line")


func test_a_zone_tool_hook_takes_input_before_selection() -> void:
	"""While armed, the hook takes the left press, the release and Esc; unarmed, nothing."""
	var forestry := _forestry()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	assert_false(forestry.handle_tool_input(press), "unarmed: not taken")
	forestry.on_action(PanelScript.ACTION_FORESTRY_ZONE)
	assert_true(forestry.tool.is_armed(), "armed from the panel")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	assert_true(forestry.handle_tool_input(escape), "Esc taken")
	assert_false(forestry.tool.is_armed(), "and put away")


# --- trees let into the ground (playtest 2026-09-29 item 15) -----------------------------------

## Model-unit height of the fake staged tree's column, and how many horizontal bands it is cut into
## (so a split lands within one band of the cut).
const FAKE_TREE_HEIGHT: float = 1.9
const FAKE_TREE_BANDS: int = 95


func _fake_tree_scene(key: StringName) -> PackedScene:
	"""A stand-in staged tree: one banded column mesh standing on the model's base, as a packed scene."""
	var box := BoxMesh.new()
	box.size = Vector3(1.0, FAKE_TREE_HEIGHT, 1.0)
	box.subdivide_height = FAKE_TREE_BANDS
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i].y += FAKE_TREE_HEIGHT * 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var root := Node3D.new()
	root.name = "Staged_%s" % key
	var column := MeshInstance3D.new()
	column.mesh = mesh
	root.add_child(column)
	column.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _staged_world() -> DemoWorldScript:
	"""A world whose oak and beech are 'staged' (the fake column, with the manifest's bound)."""
	var world := _world()
	for key: StringName in StandScript.LOOK_KEYS:
		world._scenes[key] = _fake_tree_scene(key)
		world._world_rows[String(key)] = {"path": "", "aabb_min": [0.0, 0.0, 0.0], "aabb_max": [1.0, FAKE_TREE_HEIGHT, 1.0]}
	return world


func _staged_view(stand: StandScript) -> ViewScript:
	"""The woods' drawing over `stand`, its trees made the staged world's way (sunk)."""
	var world := _staged_world()
	var view: ViewScript = _keep(ViewScript.new()) as ViewScript
	view.configure(stand, func(_placement: int) -> Node3D: return null, world.make_piece, _services.props)
	view.staged = true
	view.sync(1, 7)
	return view


static func _world_y_range(part: MeshInstance3D) -> Vector2:
	"""The lowest and highest world y of the vertices `part` draws (its index list only)."""
	var arrays: Array = part.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := Vector2(INF, -INF)
	for k: int in index:
		var y: float = (part.transform * verts[k]).y
		out = Vector2(minf(out.x, y), maxf(out.y, y))
	return out


func test_the_mound_heights_are_above_the_ground_after_the_sink() -> void:
	"""What stands of a mound once the tree is let down by its sink: the profile less the sink, never
	below the ground, scaled by the size."""
	assert_almost_equal(Roots.height_at(StandScript.LOOK_OAK, 1.0, 2.0), 1.4 - 1.2, "the oak's flare at 2 m")
	assert_almost_equal(Roots.height_at(StandScript.LOOK_OAK, 1.0, 3.0), 0.0, "the oak's mound is buried at 3 m")
	assert_almost_equal(Roots.height_at(StandScript.LOOK_OAK, 0.95, 1.9), (1.4 - 1.2) * 0.95, "scaled by the size")
	assert_almost_equal(Roots.height_at(StandScript.LOOK_BEECH, 1.0, 1.0), 0.61 - 0.5, "the beech's flare at 1 m")
	assert_almost_equal(Roots.height_at(StandScript.LOOK_BEECH, 1.1, 2.75), 0.0, "the beech's mound is buried")
	for look: int in StandScript.LOOK_KEYS.size():
		for step: int in 60:
			assert_true(Roots.height_at(look, 1.0, float(step) * 0.1) >= 0.0, "never below the ground")


func test_the_sink_is_the_worlds_and_the_cut_is_measured_from_the_ground() -> void:
	"""forest_roots takes each look's sink from world_sizes.gd, and the cut above the ground is the
	cut in the model less the sink."""
	for look: int in StandScript.LOOK_KEYS.size():
		var key: StringName = StandScript.LOOK_KEYS[look]
		assert_almost_equal(Roots.sink_m(look, 1.1), Sizes.sink_m(key, 1.1), "%s: the world's sink" % key)
		assert_almost_equal(Roots.model_cut_m(look, 1.1), Roots.CUT_M[look] * 1.1, "%s: the cut in the model" % key)
		assert_almost_equal(Roots.cut_m(look, 1.1) + Roots.sink_m(look, 1.1), Roots.model_cut_m(look, 1.1), "%s: the cut above the ground" % key)
	assert_almost_equal(Roots.cut_m(StandScript.LOOK_OAK, 1.0), 2.3 - 1.2, "the oak is cut 1.1 m up")
	assert_almost_equal(Roots.cut_m(StandScript.LOOK_BEECH, 1.0), 0.95 - 0.5, "the beech 0.45 m up")


func test_the_walkers_are_lifted_only_onto_what_stands_of_the_mound() -> void:
	"""forest_lift.gd reads the sunk mound: onto the oak's flare near the trunk, the bare ground at 3 m
	where the mound used to lift a walker 1.07 m."""
	var stand := _stand_of(_three())
	var lift := LiftScript.new()
	lift.configure(stand, null)
	var oak: Vector2 = stand.at[0]
	assert_almost_equal(lift.height_at(oak + Vector2(2.0, 0.0)), 1.4 - 1.2, "on the flare")
	assert_almost_equal(lift.height_at(oak + Vector2(0.0, 3.0)), 0.0, "on the ground over the buried mound")


func test_a_staged_tree_is_drawn_let_down_by_its_sink() -> void:
	"""The view's mature trees come from the world's make_piece: let down by the look's sink."""
	var stand := _stand_of(_three())
	var view := _staged_view(stand)
	for t: int in 2:
		assert_true(view.tree_visible(t), "tree %d stands" % t)
		assert_almost_equal(view._tree_nodes[t].transform.origin.y, -Roots.sink_m(stand.look[t], stand.size[t]), "tree %d let down" % t)


func test_a_sunk_tree_is_split_and_turned_at_its_cut_above_the_ground() -> void:
	"""Felled, the model is split at the cut in the MODEL (where the flare ends), which the sink puts
	at the cut above the ground; the fall turns about that height and the stump caps it there."""
	var stand := _stand_of(_three())
	var view := _staged_view(stand)
	## One band of the column at the tallest drawn tree here (the beech at 1.1).
	var band: float = Sizes.target_height_m(&"beech_mature") * 1.1 / float(FAKE_TREE_BANDS)
	for t: int in 2:
		assert_true(stand.fell_into(t, 1, Vector2(1.0, 0.0), false, _read), "felled %d" % t)
	view.sync(1, 8)
	for t: int in 2:
		var cut: float = Roots.cut_m(stand.look[t], stand.size[t])
		assert_true(view._upper_nodes[t] != null and view._lower_nodes[t] != null, "tree %d split" % t)
		assert_almost_equal(view._cut_height(t), cut, "tree %d turns at its cut" % t)
		assert_true(absf(_world_y_range(view._upper_nodes[t]).x - cut) <= band, "tree %d: the upper part starts at the cut (%.3f)" % [t, _world_y_range(view._upper_nodes[t]).x])
		assert_true(absf(_world_y_range(view._lower_nodes[t]).x + Roots.sink_m(stand.look[t], stand.size[t])) < 0.001, "tree %d: the stub's foot is under the ground" % t)
		var key: StringName = view.stump_key(t)
		var height: float = Sizes.target_height_m(key) * view._stump_size(t)
		assert_almost_equal(view._stump_nodes[t].position.y, cut - height * (1.0 - ViewScript.STUMP_ABOVE_CUT), "tree %d: the stump caps the cut" % t)


func test_a_woods_job_called_away_is_taken_back_when_the_other_work_is_done() -> void:
	"""Decision 0205 (resident_brain.gd RESUMING): a feller ordered away mid-walk leaves the fell on the
	board and keeps it; its next work done gives the same job back to it."""
	var forestry := _forestry()
	var tree: int = NORTH_TREES[0]
	assert_true(forestry.crew.order(JobsScript.KIND_FELL, tree, 0, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
		.contains("Placeholder 1"), "given to the resident")
	var brain := (forestry._cast.actor(1) as DemoActorScript).brain
	assert_true(_run(forestry, func() -> bool: return brain.order == BrainScript.ORDER_MOVE), "walking to the tree")
	brain.order_move(Vector2(-6.0, -6.0))
	assert_true(_run(forestry, func() -> bool: return not brain.unfinished_labels().is_empty()), "the crew saw it go")
	assert_equal(brain.unfinished_labels(), PackedStringArray(["Fell (woods)"]), "kept")
	var row: int = forestry.crew.jobs.on_target(JobsScript.KIND_FELL, tree)
	assert_true(forestry.crew.jobs.find_into(JobsScript.KIND_FELL, tree, _read), "still on the board")
	assert_equal(forestry.crew.jobs.worker[_read.value], JobsScript.NOBODY, "nobody on it")
	forestry.crew.jobs.assign(_read.value, 2)
	brain.work_done()
	assert_equal(forestry.crew.jobs.worker[_read.value], 2, "someone else has it: not taken back")
	forestry.crew.jobs.unassign(_read.value)
	brain.remember_unfinished(UnfinishedScript.new(forestry.crew.take_back.bind(_read.value,
		forestry.crew.jobs.serial[_read.value]), "Fell (woods)"))
	brain.work_done()
	assert_equal(forestry.crew.jobs.worker[_read.value], 1, "given back to it")
	assert_true(row > 0, "one fell on that tree")
	var resumed: Array[int] = [0]
	brain.remember_unfinished(UnfinishedScript.new(func(_b: RefCounted) -> bool:
		resumed[0] += 1
		return true, "lanterns"))
	forestry.crew.finish(_read.value, "")
	assert_equal(resumed[0], 1, "the woods ending its job sends it back to what the woods took it from")
