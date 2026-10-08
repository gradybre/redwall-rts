extends "res://test/framework/test_case.gd"
## Review group Y's orchard remainders (decision 1721; Brendan's ruling on Q-D7, 2026-10-07: "Both, agent proposes
## numbers"): a sapling moved once and settling (ECO-009), a group's handcart and its fresh-table share (ECO-010), and the
## second grove (ECO-015). The numbers against their stated reasoning, the model's move and settling, and whole jobs on
## real brains walking the real layout -- a move lifted, carried and replanted; a cart built; hauls by cart and by share --
## with nothing lost: every unit is at a stand, in a store or in a hand. Built as test_demo_orchard.gd builds its rig.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const CardsScript := preload("res://demo/orchard/orchard_cards.gd")
const ViewScript := preload("res://demo/orchard/orchard_view.gd")
const OrchardNode := preload("res://demo/orchard/demo_orchard.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const KitchenNode := preload("res://demo/kitchen/demo_kitchen.gd")
const ForageRules := preload("res://demo/forage/forage_rules.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 8000
const APPLE_DAY: int = 25
## The rig's stores (test_demo_orchard.gd's order): the kitchen pantry 1, the cellar 4.
const KITCHEN_AT: int = 1
const CELLAR_AT: int = 4

## The rig: the placeholder cast on the village's water, a pantry with the stands, the orchard's model and board.
class Rig:
	var cast: DemoCastScript = null
	var pantry: PantryScript = null
	var calendar: CalendarScript = null
	var model: ModelScript = null
	var jobs: JobsScript = null
	var compost: int = 40000
	var day_seen: int = 1
	var said: PackedStringArray = PackedStringArray()

	func compost_left() -> int:
		"""The rig's compost store."""
		return compost

	func take_compost(milli: int) -> bool:
		"""All or none."""
		if compost < milli:
			return false
		compost -= milli
		return true

	func say(text: String, _warning: bool) -> void:
		"""The village news, kept."""
		said.append(text)

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water, built once."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _rig(day: int = 1) -> Rig:
	"""test_demo_orchard.gd's rig: the cast on the real layout, a pantry with the kitchen's store, the stands and a cellar,
	the calendar at 06:00 of `day`, mild weather, and the orchard, its news kept."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	circles.append_array(OrchardNode.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var storage := StorageScript.new(DemoFarmScript.store_position(rig.cast))
	storage.add_provider(KitchenNode.pantry_provider())
	storage.add_provider(OrchardNode.stand_provider())
	storage.add_provider(_cellar)
	rig.pantry = PantryScript.new(storage)
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	var weather := DemoWeatherScript.new()
	weather.observe(0, 1, 8, 120, 0, WeatherCore.EVENT_NONE)
	rig.model = ModelScript.new()
	rig.model.today_hint = day
	rig.day_seen = day
	rig.jobs = JobsScript.new()
	rig.jobs.configure(rig.model, rig.cast, rig.pantry, _services.stores, rig.calendar, weather)
	rig.jobs.set_compost(rig.compost_left, rig.take_compost)
	rig.jobs.say = rig.say
	return rig


static func _cellar() -> Array:
	"""A root cellar by the hall (§5.8's 350): the store that keeps food longest."""
	return [{StorageScript.KEY_ID: &"test_cellar", StorageScript.KEY_POSITION: Vector2(-3.0, -10.0),
		StorageScript.KEY_CAPACITY_U: 100, StorageScript.KEY_PERMILLE: 350, StorageScript.KEY_LABEL: "Cellar"}]


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast, the calendar (its midnights closing the orchard's days) and the board, handing each waiting job to
	the first idle resident who may take it, until `done()`."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		var day: int = rig.calendar.now().absolute_day
		while rig.day_seen < day:
			rig.model.close_day(rig.day_seen, 120)
			rig.day_seen += 1
		rig.jobs.update(usec)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part: each waiting job to the first idle resident who may take it."""
	for j: int in JobsScript.MAX_JOBS:
		if not rig.jobs.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = rig.jobs.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and rig.jobs.eligibility(j, who).is_empty() and rig.jobs.claim(j, who):
				break


func _stand(rig: Rig, group: int) -> int:
	"""Group `group`'s stand's pantry location."""
	assert_true(rig.pantry.storage.index_of_id_into(Rules.STAND_IDS[group], _read), "the stand is a store")
	return _read.value


func _sapling(model: ModelScript, site: int, day: int, age: int) -> void:
	"""A free apple sapling planted on `site` on `day`, aged `age` days."""
	assert_true(model.take_sapling(site, Rules.APPLE, false), "a free sapling")
	assert_true(model.plant(site, Rules.APPLE, day), "planted")
	assert_true(model.store.restore_orchard_state(model.site_ref[site], age, Hive.HEALTH_MAX, 0, false, false).ok, "aged")


# --- the numbers (decision 1721's proposals, against their stated reasoning) ---------------------------------------------

func test_the_numbers_are_their_reasoning() -> void:
	"""The settling delay is one season (and §5.6's nursery wait); lifting is half BAL-CAT-010's planting, replanting the
	whole with §5.6's compost; a cart is four baskets, wood 4 U and 60 WU; the share steps; the grove reserve a tenth."""
	assert_equal(Rules.MOVE_SETTLE_DAYS, SimClock.DAYS_PER_SEASON, "one season")
	assert_equal(Rules.MOVE_SETTLE_DAYS, Hive.NURSERY_WAIT_DAYS, "the nursery's own wait")
	assert_equal(Rules.MOVE_LIFT_MWU, 20000, "half a planting")
	assert_equal(Rules.MOVE_REPLANT_MWU, 40000, "BAL-CAT-010's planting")
	assert_equal(Rules.MOVE_COMPOST_MILLI, 4000, "§5.6's planting compost")
	assert_equal(Rules.CART_LOAD_MILLI, 4 * Rules.HAUL_LOAD_MILLI, "four baskets")
	assert_true(Rules.CART_LOAD_MILLI * 250 / 1000 <= 16000, "10 kg at 250 g a unit: within a medium carrier's 16 kg")
	assert_equal([Rules.CART_WOOD_MILLI, Rules.CART_BUILD_MWU], [4000, 60000], "the cart's cost")
	assert_equal(Rules.FRESH_STEPS, PackedInt32Array([0, 25, 50, 75, 100]), "the share's steps")
	assert_equal(Rules.GROVE_RESERVE_PERMILLE, 100, "a tenth of the capacity")
	assert_equal(Rules.KIND_COUNT, 12, "two kinds added")
	assert_equal(JobsScript.program_length(Rules.K_MOVE), 4, "lift, carry, replant")
	assert_equal(JobsScript.program_length(Rules.K_CART), 2, "walk and build")


func test_a_sapling_is_movable_until_its_half_year() -> void:
	"""`is_movable_age`: day 0 to day 23 (HALF_YEAR_DAYS 24 is a young tree); never a negative age."""
	assert_true(Rules.is_movable_age(0), "just planted")
	assert_true(Rules.is_movable_age(Rules.HALF_YEAR_DAYS - 1), "its last sapling day")
	assert_false(Rules.is_movable_age(Rules.HALF_YEAR_DAYS), "a young tree")
	assert_false(Rules.is_movable_age(-1), "no age")


func test_the_share_goes_where_it_is_furthest_behind() -> void:
	"""`to_kitchen`: 0% never, 100% always; 50% alternates on equal loads; the boundary is strict."""
	assert_false(Rules.to_kitchen(0, 0, 0, 10000), "none to the kitchen")
	assert_true(Rules.to_kitchen(100, 50000, 50000, 10000), "all to the kitchen")
	assert_true(Rules.to_kitchen(50, 0, 0, 10000), "the first half")
	assert_false(Rules.to_kitchen(50, 10000, 10000, 10000), "exactly half: the other place")
	assert_true(Rules.to_kitchen(50, 10000, 20000, 10000), "behind again")
	assert_false(Rules.to_kitchen(25, 0, 0, 0), "nothing to send")
	assert_true(Rules.to_kitchen(25, 9999, 40000, 0), "a hair under a quarter")
	assert_false(Rules.to_kitchen(25, 10000, 40000, 0), "a quarter exactly")


func test_the_groves_are_circles() -> void:
	"""`grove_of`: each grove by its centre and radius, the edge inside; the foraging spots inside their groves."""
	assert_equal(Rules.GROVE_COUNT, 2, "two groves")
	assert_equal(Rules.grove_of(Rules.GROVE_CENTRES[1] + Vector2(6.0, 0.0)), 1, "the beech hollow's edge")
	assert_equal(Rules.grove_of(Rules.GROVE_CENTRES[1] + Vector2(6.01, 0.0)), Rules.NONE, "just outside")
	assert_equal(Rules.grove_of(Rules.GROVE_AT + Vector2(0.0, 6.5)), 0, "the North hollow's edge")
	assert_equal(Rules.grove_of(ForageRules.SPOT_AT[0]), 0, "the hazel brake in the North hollow")
	assert_equal(Rules.grove_of(ForageRules.SPOT_AT[1]), 1, "the beech hollow's mushrooms")
	assert_equal(Rules.grove_of(ForageRules.SPOT_AT[2]), Rules.NONE, "the herb bank in neither")
	assert_true(Rules.is_grove(1) and not Rules.is_grove(2) and not Rules.is_grove(-1), "the groves' ids")
	for grove: int in Rules.GROVE_COUNT:
		assert_true(Rules.GROVE_STONES[grove].distance_to(Rules.GROVE_CENTRES[grove]) < Rules.GROVE_RADII_M[grove],
			"grove %d's stone in it" % grove)


# --- the model's move (ECO-009) ------------------------------------------------------------------------------------------

func test_move_refusals_say_why() -> void:
	"""`move_refusal`: no tree; an old tree or one past its half-year is no sapling; a site taken, the same site or one
	promised to a plan; once moved, never again."""
	var model := ModelScript.new()
	assert_equal(model.move_refusal(2, 3), ModelScript.REFUSE_NOT_ELIGIBLE, "no tree")
	assert_equal(model.move_refusal(0, 2), ModelScript.REFUSE_NOT_A_SAPLING, "the old apple")
	_sapling(model, 2, 1, Rules.HALF_YEAR_DAYS)
	assert_equal(model.move_refusal(2, 3), ModelScript.REFUSE_NOT_A_SAPLING, "a young tree")
	model.store.restore_orchard_state(model.site_ref[2], Rules.HALF_YEAR_DAYS - 1, Hive.HEALTH_MAX, 0, false, false)
	assert_equal(model.move_refusal(2, 3), "", "a sapling to a free site")
	assert_equal(model.move_refusal(2, 2), ModelScript.REFUSE_NO_MOVE_SITE, "not onto itself")
	assert_equal(model.move_refusal(2, 0), ModelScript.REFUSE_NO_MOVE_SITE, "not onto a tree")
	assert_equal(model.move_refusal(2, Rules.SITE_COUNT), ModelScript.REFUSE_NO_MOVE_SITE, "not off the sites")
	assert_equal(model.add_plan(Rules.PEAR, 3), "", "a plan for site 3")
	assert_equal(model.move_refusal(2, 3), ModelScript.REFUSE_NO_MOVE_SITE, "a promised site")
	assert_equal(model.move_options(2), ModelScript.NONE, "nowhere else free")
	model.drop_plan(model.plan_for_site(3))
	assert_equal(model.move_options(2), 3, "free again")
	model.moved[2] = 1
	assert_equal(model.move_refusal(2, 3), ModelScript.REFUSE_MOVED_ONCE, "moved once")
	for code: String in [ModelScript.REFUSE_NOT_A_SAPLING, ModelScript.REFUSE_MOVED_ONCE, ModelScript.REFUSE_NO_MOVE_SITE]:
		assert_false(Text.move_words(code).is_empty(), "%s in words" % code)
	assert_equal(Text.move_words(""), "", "none")


func test_a_move_speaks_for_its_site() -> void:
	"""`reserve_move`: the destination is spoken for -- no planting and no plan there -- until the move is over."""
	var model := ModelScript.new()
	_sapling(model, 2, 1, 3)
	assert_true(model.reserve_move(2, 3), "reserved")
	assert_true(model.is_move_dest(3), "spoken for")
	assert_equal(model.plant_refusal(3, Rules.PEAR, 1, false), ModelScript.REFUSE_MOVE_DEST, "no planting")
	assert_equal(model.add_plan(Rules.PEAR, 3), ModelScript.REFUSE_MOVE_DEST, "no plan")
	assert_equal(Text.plant_words(ModelScript.REFUSE_MOVE_DEST), "a sapling is being moved to this site", "in words")
	assert_false(model.reserve_move(0, 3), "the old apple is no sapling")
	model.set_lifted(2, true)
	model.cancel_move(2)
	assert_false(model.is_move_dest(3), "freed")
	assert_equal(model.lifted[2], 0, "set back in its hole")
	var revision: int = model.revision
	model.cancel_move(2)
	assert_equal(model.revision, revision, "nothing to cancel: nothing changes")


func test_a_moved_tree_keeps_its_state_and_settles() -> void:
	"""`move_tree`: the row moved with its age, health, chill and flags; moved once; MOVE_SETTLE_DAYS without growing,
	health still §5.6's (untended spring days -100); then it grows again."""
	var model := ModelScript.new()
	_sapling(model, 2, 1, 5)
	model.store.restore_orchard_state(model.site_ref[2], 5, 9000, 0, true, false)
	assert_true(model.reserve_move(2, 3), "reserved")
	assert_true(model.move_tree(2, 6), "moved")
	assert_false(model.has_tree(2), "the old site empty")
	assert_equal([model.species_of(3), model.age_of(3), model.health_of(3)], [Rules.APPLE, 5, 9000], "its state")
	assert_true(model.tended_today(3), "today's care carried")
	assert_equal([model.moved[3], model.settle_days[3], model.planted_day[3]], [1, Rules.MOVE_SETTLE_DAYS, 1], "settling")
	assert_equal([model.moved[2], model.settle_days[2], model.move_dest[2]], [0, 0, ModelScript.NONE], "the old site cleared")
	assert_equal(model.store.orchard_count(), 3, "one row moved, none added")
	for day: int in range(6, 6 + Rules.MOVE_SETTLE_DAYS):
		model.close_day(day, 120)
	assert_equal([model.age_of(3), model.settle_days[3]], [5, 0], "no growth while it settles")
	assert_equal(model.health_of(3), 9000 + 50 - 100 * (Rules.MOVE_SETTLE_DAYS - 1), "§5.6's days still applied")
	model.close_day(6 + Rules.MOVE_SETTLE_DAYS, 120)
	assert_equal(model.age_of(3), 6, "it grows again")
	assert_false(model.move_tree(3, 20), "no move without a destination")


func test_the_next_picking_counts_the_settling() -> void:
	"""`next_harvest_day` of a tree settling 12 days is a tree 12 days younger's."""
	var settling := ModelScript.new()
	_sapling(settling, 2, 1, 20)
	settling.reserve_move(2, 3)
	settling.move_tree(2, 1)
	var younger := ModelScript.new()
	_sapling(younger, 3, 1, 20 - Rules.MOVE_SETTLE_DAYS)
	var plain := ModelScript.new()
	_sapling(plain, 3, 1, 20)
	var day: int = 1
	assert_equal(settling.next_harvest_day(3, day), younger.next_harvest_day(3, day), "12 days later")
	assert_true(settling.next_harvest_day(3, day) > plain.next_harvest_day(3, day), "later than unmoved")


# --- a move on real brains -----------------------------------------------------------------------------------------------

func test_a_sapling_is_lifted_carried_and_replanted() -> void:
	"""ECO-009 end to end: ordered with a resident selected, the sapling is lifted (20 WU), carried in arms to its new
	site, replanted (40 WU) with compost 4 U taken at the end; the news says when it fruits."""
	var rig := _rig(3)
	_sapling(rig.model, 2, 3, 2)
	assert_equal(rig.jobs.move_target(2), 3, "to the free site")
	assert_equal(rig.jobs.order_move(2, PackedInt32Array([3])), "", "ordered")
	assert_true(rig.model.is_move_dest(3), "spoken for")
	var j: int = rig.jobs.find(JobsScript.K_MOVE, 2)
	assert_true(j >= 0 and rig.jobs.worker[j] == 3, "to the selected resident")
	var carried: Array[bool] = [false]
	assert_true(_run(rig, func() -> bool:
		carried[0] = carried[0] or rig.jobs.holds_sapling(j)
		return rig.model.has_tree(3)), "replanted")
	assert_true(carried[0], "carried in arms")
	assert_false(rig.model.has_tree(2), "its old block empty")
	assert_equal(rig.compost, 36000, "4 U of compost")
	assert_equal(rig.model.moved[3], 1, "moved once")
	assert_equal(rig.jobs.count_of(JobsScript.K_MOVE, JobsScript.NONE), 0, "the job over")
	assert_false(rig.model.is_move_dest(3), "nothing spoken for")
	assert_true(rig.said[rig.said.size() - 1].contains("was moved to east site 2"), rig.said[rig.said.size() - 1])
	assert_equal(rig.jobs.order_move(3, PackedInt32Array([3])), Text.move_words(ModelScript.REFUSE_MOVED_ONCE),
		"never twice")


func test_a_move_let_go_sets_the_sapling_back() -> void:
	"""Paused while it carries the sapling: it is set back in its hole and the move starts again (its site still spoken
	for); cancelled: the site is freed and the tree stays."""
	var rig := _rig(3)
	_sapling(rig.model, 2, 3, 2)
	assert_equal(rig.jobs.order_move(2, PackedInt32Array([3])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_MOVE, 2)
	assert_true(_run(rig, func() -> bool: return rig.model.lifted[2] == 1), "lifted")
	assert_equal(rig.jobs.step_of(j), JobsScript.S_CARRY, "carrying it")
	assert_false(rig.jobs.carrying(j), "a sapling is no food load: it may be called off")
	assert_true(Text.tend_refusal(rig.model, 2, 0, false, null).contains("out of the ground"), "not tended in arms")
	assert_equal(rig.jobs.pause(j, true), "", "paused")
	assert_equal([rig.model.lifted[2], rig.jobs.pos[j], rig.jobs.done_mwu[j]], [0, 0, 0], "set back, to start again")
	assert_true(rig.model.is_move_dest(3), "still spoken for")
	assert_equal(rig.jobs.cancel(j), "", "cancelled")
	assert_false(rig.model.is_move_dest(3), "freed")
	assert_true(rig.model.has_tree(2), "the tree where it was")
	assert_equal(rig.compost, 40000, "nothing taken")


func test_a_move_with_no_compost_left_is_set_back() -> void:
	"""The compost gone while it is carried: the replanting refuses, the sapling goes back to its block, the site freed."""
	var rig := _rig(3)
	_sapling(rig.model, 2, 3, 2)
	assert_equal(rig.jobs.order_move(2, PackedInt32Array([3])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return rig.model.lifted[2] == 1), "lifted")
	rig.compost = 0
	assert_true(_run(rig, func() -> bool: return rig.jobs.count_of(JobsScript.K_MOVE, JobsScript.NONE) == 0), "over")
	assert_true(rig.model.has_tree(2) and not rig.model.has_tree(3), "it stays")
	assert_equal([rig.model.lifted[2], rig.model.moved[2]], [0, 0], "in its hole, never moved")
	assert_false(rig.model.is_move_dest(3), "freed")
	assert_true(rig.said[rig.said.size() - 1].contains("compost"), rig.said[rig.said.size() - 1])


func test_move_orders_are_refused_in_words() -> void:
	"""`order_move`: an old tree, no compost, no free site -- each refused before anything is spoken for."""
	var rig := _rig(3)
	assert_true(rig.jobs.order_move(0, PackedInt32Array()).contains("only a sapling"), "the old apple")
	assert_true(rig.jobs.order_move(-1, PackedInt32Array()).contains("no tree"), "no site")
	_sapling(rig.model, 2, 3, 2)
	rig.compost = 0
	assert_true(rig.jobs.order_move(2, PackedInt32Array()).contains("compost"), "no compost")
	assert_false(rig.model.is_move_dest(3), "nothing spoken for")
	rig.compost = 40000
	assert_equal(rig.model.add_plan(Rules.PEAR, 3), "", "the last site promised")
	assert_true(rig.jobs.order_move(2, PackedInt32Array()).contains("no free site"), "nowhere to go")
	rig.model.drop_plan(rig.model.plan_for_site(3))
	assert_equal(rig.jobs.order_move(2, PackedInt32Array()), "", "queued for the board")
	assert_equal(rig.jobs.order_move(2, PackedInt32Array()), "", "a second order is the first")
	assert_equal(rig.jobs.count_of(JobsScript.K_MOVE, JobsScript.NONE), 1, "one move")


# --- carts and shares on real brains (ECO-010) ---------------------------------------------------------------------------

func test_a_cart_is_built_for_its_wood() -> void:
	"""A cart: refused without 4 U of wood; built at the baskets in 60 WU with the wood taken at the end; one a group."""
	var rig := _rig(3)
	_services.stores.wood_milli_u = 3999
	assert_true(rig.jobs.order(JobsScript.K_CART, 1, -1, PackedInt32Array()).contains("of wood"), "short of wood")
	_services.stores.wood_milli_u = 10000
	assert_equal(rig.jobs.order(JobsScript.K_CART, 1, -1, PackedInt32Array([2])), "", "ordered")
	assert_equal(_services.stores.wood_milli_u, 10000, "nothing taken at the order")
	assert_true(_run(rig, func() -> bool: return rig.model.has_cart(1)), "built")
	assert_equal(_services.stores.wood_milli_u, 6000, "4 U of wood")
	assert_false(rig.model.has_cart(0), "the other group has none")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_CART, 1, -1), Text.HAS_CART, "one a group")
	assert_equal(rig.jobs.cart_refusal(Rules.GROUP_COUNT), Text.GONE, "no such group")
	assert_true(rig.said[rig.said.size() - 1].contains("handcart"), rig.said[rig.said.size() - 1])


func test_a_cart_hauls_four_baskets_at_once() -> void:
	"""With the old orchard's cart, one haul carries 40 U on to the cellar (a basket's 10 U without); the rest waits."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	assert_true(rig.model.add_cart(0), "a cart")
	assert_false(rig.model.add_cart(0), "only one")
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 45000, stand, _read), "apples at the baskets")
	assert_equal(rig.jobs.order(JobsScript.K_HAUL, 0, -1, PackedInt32Array([2])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HAUL, 0)
	var out: Array[int] = [JobsScript.NONE]
	assert_true(_run(rig, func() -> bool:
		out[0] = maxi(out[0], rig.jobs.cart_out(0))
		return rig.pantry.milli_at(Catalog.ITEM_APPLE, CELLAR_AT) > 0), "hauled")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, CELLAR_AT), 40000, "a cart's load")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), 5000, "the rest at the baskets")
	assert_equal(out[0], 2, "pushed by its hauler")
	assert_false(rig.jobs.is_live(j), "one trip")
	assert_equal(rig.jobs.cart_out(0), JobsScript.NONE, "back at the baskets")
	assert_equal(rig.pantry.stored_total_milli(Catalog.ITEM_APPLE), 45000, "the ledger counts it once")


func test_a_cart_short_of_room_takes_a_basket() -> void:
	"""Every store with only 15 U of room: the cart's 40 U finds no room, so the haul holds a basket's 10 U."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	rig.model.add_cart(0)
	for at: int in rig.pantry.storage.count():
		if not rig.pantry.storage.is_staging(at):
			assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, rig.pantry.room_milli_of(at) - 15000, at, _read), "filled")
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 45000, stand, _read), "apples at the baskets")
	assert_equal(rig.jobs.order(JobsScript.K_HAUL, 0, -1, PackedInt32Array([2])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HAUL, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.carrying(j)), "loaded")
	assert_equal(rig.jobs.load_milli[j], Rules.HAUL_LOAD_MILLI, "a basket's load")


func test_the_share_sends_hauls_to_both_places() -> void:
	"""A half share (a spring day: no harvest of the routine's own joins the baskets): the first 10 U to the kitchen
	pantry, the next to the cellar; the tallies say 50%; a year's turn clears them."""
	var rig := _rig(3)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	rig.model.group_fresh_pct[0] = 50
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 20000, stand, _read), "apples at the baskets")
	rig.jobs.plan_work()
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) == 0 \
		and rig.jobs.count_of(JobsScript.K_HAUL, JobsScript.NONE) == 0), "hauled")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, KITCHEN_AT), 10000, "half to the kitchen")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, CELLAR_AT), 10000, "half to the cellar")
	assert_equal([rig.model.group_hauled_milli[0], rig.model.group_kitchen_milli[0]], [20000, 10000], "the tallies")
	assert_equal(rig.model.kitchen_share_pct(0), 50, "50%")
	rig.model.close_day(Hive.first_day_of_year(2) - 1, 120)
	assert_equal([rig.model.group_hauled_milli[0], rig.model.kitchen_share_pct(0)], [0, 0], "a new year: cleared")


func test_a_full_kitchen_sends_the_fresh_share_to_the_cellar() -> void:
	"""All to the fresh table, but the kitchen pantry full: the haul goes to the cellar (a wish, not a promise)."""
	var rig := _rig(3)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	rig.model.group_fresh_pct[0] = 100
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, rig.pantry.room_milli_of(KITCHEN_AT), KITCHEN_AT, _read), "full")
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 6000, stand, _read), "apples at the baskets")
	rig.jobs.plan_work()
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) == 0 \
		and rig.jobs.count_of(JobsScript.K_HAUL, JobsScript.NONE) == 0), "hauled")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, KITCHEN_AT), 0, "not the full kitchen")
	assert_equal(rig.model.kitchen_share_pct(0), 0, "none to the kitchen this year")
	assert_equal(rig.model.group_hauled_milli[0], 6000, "but hauled")


func test_shares_and_tallies_refuse_nonsense() -> void:
	"""`note_hauled` ignores no group and nothing; `kitchen_share_pct` is 0 before any haul."""
	var model := ModelScript.new()
	model.note_hauled(-1, 5000, true)
	model.note_hauled(0, 0, true)
	assert_equal(model.group_hauled_milli, PackedInt64Array([0, 0]), "nothing booked")
	assert_equal(model.kitchen_share_pct(0), 0, "none")
	model.note_hauled(1, 3000, false)
	assert_equal([model.group_hauled_milli[1], model.group_kitchen_milli[1]], [3000, 0], "to a keeping store")
	assert_equal(model.haul_load_milli(1), Rules.HAUL_LOAD_MILLI, "a basket without a cart")
	assert_false(model.has_cart(Rules.GROUP_COUNT) or model.add_cart(-1), "no such group")


# --- the cards and the view ----------------------------------------------------------------------------------------------

func _cards(model: ModelScript, day: int) -> CardsScript:
	"""Cards over `model` and a board at 06:00 of `day` with 10 U of compost and no cast."""
	var storage := StorageScript.new(Vector2.ZERO)
	storage.add_provider(OrchardNode.stand_provider())
	var calendar := CalendarScript.new()
	calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	var jobs := JobsScript.new()
	jobs.configure(model, null, PantryScript.new(storage), _services.stores, calendar, null)
	model.today_hint = day
	var compost := func() -> int: return 10000
	jobs.set_compost(compost, func(_milli: int) -> bool: return true)
	var cards := CardsScript.new()
	cards.configure(model, jobs, null)
	cards.compost_left = compost
	return cards


func test_the_cards_say_the_move_and_the_cart() -> void:
	"""The tree's readout says whether it may move; the move's and the cart's cards their result and costs; the stand
	says its share and its cart; the refusals are the orders' own."""
	var model := ModelScript.new()
	var cards := _cards(model, 3)
	assert_true(cards.tree_text(0).contains("Too big to move"), "the old apple")
	assert_true(cards.refusal(&"move", CardsScript.SEL_SITE, 0).contains("only a sapling"), "its refusal")
	_sapling(model, 2, 3, 2)
	assert_true(cards.tree_text(2).contains("may be moved once"), cards.tree_text(2))
	assert_equal(cards.refusal(&"move", CardsScript.SEL_SITE, 2), "", "a sapling may move")
	var card: String = cards.card_text(&"move", CardsScript.SEL_SITE, 2, PackedInt32Array(), "")
	assert_true(card.contains("east site 2") and card.contains("settles 12 days") and card.contains("Compost"), card)
	model.reserve_move(2, 3)
	model.move_tree(2, 3)
	assert_true(cards.tree_text(3).contains("settling, 12 days"), cards.tree_text(3))
	model.settle_days[3] = 0
	assert_true(cards.tree_text(3).contains("Moved once already"), cards.tree_text(3))
	assert_true(cards.stand_text(0).contains("no cart") and cards.stand_text(0).contains("0% wanted"), cards.stand_text(0))
	card = cards.card_text(&"cart", CardsScript.SEL_STAND, 0, PackedInt32Array(), "")
	assert_true(card.contains("40.0 U") and card.contains("Wood"), card)
	model.add_cart(0)
	model.group_fresh_pct[0] = 75
	assert_true(cards.stand_text(0).contains("a handcart") and cards.stand_text(0).contains("75% wanted"), cards.stand_text(0))
	assert_true(cards.group_text(0).contains("a handcart"), cards.group_text(0))
	assert_true(cards.refusal(&"cart", CardsScript.SEL_STAND, 0).contains("cart already"), "one a group")
	assert_true(cards.policy_tip(&"dest", 0).contains("75%"), cards.policy_tip(&"dest", 0))
	assert_true(cards.card_text(&"haul", CardsScript.SEL_STAND, 0, PackedInt32Array(), "").contains("by handcart"), "a cart haul")


func _view(model: ModelScript) -> ViewScript:
	"""The orchard drawn with the world's placeholders over `model` (no cast)."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var calendar := CalendarScript.new()
	var storage := StorageScript.new(Vector2.ZERO)
	var jobs := JobsScript.new()
	jobs.configure(model, null, PantryScript.new(storage), _services.stores, calendar, null)
	var view := _keep(ViewScript.new()) as ViewScript
	view.configure(model, jobs, world.make_piece, _services.props, null, null, calendar)
	return view


func test_the_view_draws_carts_rings_and_a_lifted_sapling() -> void:
	"""A cart drawn at its baskets once built (hidden before); each grove its ring while protected; a lifted sapling's
	block shows no tree; nobody holds anything with no worker."""
	var model := ModelScript.new()
	var view := _view(model)
	assert_not_null(view.cart_node(0), "a cart node made")
	view.follow_carts()
	assert_false(view.cart_node(0).visible, "no cart yet")
	model.add_cart(0)
	view.follow_carts()
	assert_true(view.cart_node(0).visible, "drawn once built")
	assert_almost_equal(view.cart_node(0).position.x, Rules.CART_PARK_AT[0].x, "at its park")
	assert_true(view.ring_of(1).visible, "the beech hollow's ring")
	model.set_grove_protected(1, false)
	view.refresh(true)
	assert_false(view.ring_of(1).visible, "no ring when not protected")
	assert_true(view.ring_of(0).visible, "the North hollow's kept")
	_sapling(model, 2, 1, 2)
	view.refresh(true)
	assert_true(view.tree_node(2).visible, "the sapling drawn")
	model.set_lifted(2, true)
	view.refresh(false)
	assert_false(view.tree_node(2).visible, "lifted: its block empty")
	for j: int in JobsScript.MAX_JOBS:
		assert_equal(view.held_key(j), &"", "nothing held without a worker")


func test_the_node_orders_a_move_and_steps_the_share() -> void:
	"""demo_orchard.gd `on_action`: Move sapling orders the move (queued without a selection); the share cycles."""
	var node := _keep(OrchardNode.new()) as OrchardNode
	var storage := StorageScript.new(Vector2.ZERO)
	storage.add_provider(OrchardNode.stand_provider())
	node.configure(null, null, null, null, _services, PantryScript.new(storage))
	node.set_compost(func() -> int: return 10000, func(_milli: int) -> bool: return true)
	_sapling(node.model, 2, 1, 2)
	node.select(OrchardNode.SEL_SITE, 2)
	node.on_action(&"move")
	assert_true(node.jobs.find(JobsScript.K_MOVE, 2) >= 0, "ordered")
	assert_true(node.model.is_move_dest(3), "to east site 2")
	node.select(OrchardNode.SEL_STAND, 1)
	node.on_action(&"dest")
	assert_equal(node.model.group_fresh_pct[1], 25, "a quarter")
	assert_equal(node.panel.button(&"dest").text, "Share: fresh 25%", "on its button")
