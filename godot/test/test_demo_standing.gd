extends "res://test/framework/test_case.gd"
## The standing orders (decision 0711): goals the village keeps by queueing its own work. The book's latch and its
## hysteresis, the committed output it counts, the jobs it opens through the owners' own boards (sawing, deadfall and
## felling, harvests), the priority and the food/fuel bucket it writes on the work board, the blocked notice (and no
## other), the game-hour driver, the winter's Firewood as a built-in order, the Work screen's section, and no allocation
## per keep. The real woods, farm and kitchen on the placeholder cast in the village layout. No staged assets.

const Kinds := preload("res://demo/orders/standing_kinds.gd")
const BookScript := preload("res://demo/orders/standing_orders.gd")
const GoalScript := preload("res://demo/orders/order_goal.gd")
const CropGoal := preload("res://demo/orders/goal_crop.gd")
const MealsGoal := preload("res://demo/orders/goal_meals.gd")
const StandingScript := preload("res://demo/orders/demo_standing.gd")
const ViewScript := preload("res://demo/orders/standing_view.gd")
const RowScript := preload("res://demo/orders/standing_row.gd")
const Text := preload("res://demo/orders/standing_text.gd")
const ScreenScript := preload("res://demo/work/work_screen.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const FarmWork := preload("res://demo/work/farm_work.gd")
const WoodsWork := preload("res://demo/work/woods_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WinterTest := preload("res://test/test_demo_winter.gd")
const SkipScript := preload("res://demo/winter/season_skip.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const WOOD: int = 60
const BED_CARROTS: int = 2
const CARROT: int = 2
const WHEAT: int = 13
const PEA: int = 11

var _nodes: Array[Object] = []


## A fake goal: the good is `have`, a job is a number on no board, live while in `live_keys`.
class FakeGoal extends GoalScript:
	var have: int = 0
	var each: int = 1000
	var refuse: String = ""
	var is_urgent: bool = false
	var next_key: int = 0
	var live_keys: PackedInt64Array = PackedInt64Array()
	## A built-in's own rule: always wanted.
	var own: bool = false

	func _init() -> void:
		"""A planks-kind goal on no board."""
		kind = Kinds.KIND_PLANKS
		source = WorkIds.SOURCE_WOODS

	func measure(_item: int) -> int:
		"""The good."""
		return have

	func urgent(_item: int) -> bool:
		"""As set."""
		return is_urgent

	func own_rule() -> bool:
		"""As set."""
		return own

	func wanted(_item: int) -> bool:
		"""Always, with its own rule."""
		return true

	func key_of(row: int) -> int:
		"""The row is the key."""
		return row

	func live(_row: int, job_key: int) -> bool:
		"""While its key is live."""
		return live_keys.has(job_key)

	func output_of(_row: int, _item: int) -> int:
		"""Each job brings `each`."""
		return each

	func raise_into(_item: int, _tracked: Callable, out: IntMath.IntResult) -> String:
		"""A new job, or the refusal."""
		if not refuse.is_empty():
			return refuse
		next_key += 1
		live_keys.append(next_key)
		out.succeed(next_key)
		return ""


## The village: the woods, the farm (the carrot bed ripe), the kitchen, the board and the standing orders over them.
class Rig extends RefCounted:
	var services: ServicesScript = null
	var cast: DemoCastScript = null
	var forestry: ForestryScript = null
	var sim: SimScript = null
	var pantry: PantryScript = null
	var farm: FarmCrewScript = null
	var kitchen: KitchenScript = KitchenScript.new()
	var board: BoardScript = BoardScript.new()
	var standing: StandingScript = null
	var fuel_short: bool = false


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


func _rig() -> Rig:
	"""The village (see Rig), the standing orders configured as demo_village.gd does."""
	var rig := Rig.new()
	rig.services = ServicesScript.new()
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles)
	rig.cast.set_bounds(world.bounds())
	rig.forestry = _keep(ForestryScript.new()) as ForestryScript
	rig.forestry.configure(world, rig.cast, null, null, rig.services, IntMath.IntResult.new(true, WOOD, ""))
	_farm_of(rig)
	_board_of(rig)
	rig.standing = _keep(StandingScript.new()) as StandingScript
	rig.standing.configure(rig.services, rig.board, rig.forestry, rig.farm, rig.sim, rig.pantry, rig.kitchen,
		func() -> bool: return rig.fuel_short)
	return rig


func _farm_of(rig: Rig) -> void:
	"""The farm a day on (the carrot bed ripe) and the kitchen over its pantry."""
	rig.sim = SimScript.new()
	rig.sim.advance_usec(24 * HOUR_USEC)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.farm = FarmCrewScript.new()
	rig.farm.configure(rig.cast, rig.sim, rig.pantry, TunnelsScript.new(), DemoFarmScript.well_position(),
		func(_text: String) -> void: pass)
	var places := PlacesScript.new()
	places.set_points(Vector2(0, 0), Vector2(2, 0), Vector2(4, 0), Vector2(4, 1))
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var species := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in rig.cast.actor_count():
		var actor := rig.cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		species.append("mouse")
		keys.append(actor.creature_key)
	rig.kitchen.configure(brains, names, species, keys, rig.pantry, rig.services.stores, rig.services.calendar, places)


func _board_of(rig: Rig) -> void:
	"""The board over the farm and the woods, their hand-outs stood down."""
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in rig.cast.actor_count():
		var actor := rig.cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		keys.append(actor.creature_key)
	rig.board.bind(brains, names, keys)
	rig.board.add_source(FarmWork.new(rig.farm))
	rig.board.add_source(WoodsWork.new(rig.forestry.crew))
	rig.farm.set_claimer(rig.board.queue_words)
	rig.forestry.crew.set_claimer(rig.board.queue_words)


func _fake_book() -> Array:
	"""A book over a FakeGoal: [book, goal]."""
	var book := BookScript.new()
	var goal := FakeGoal.new()
	book.set_goal(goal)
	return [book, goal]


# --- the kinds, read from data -------------------------------------------------------------------------

func test_the_goods_are_read_from_the_catalog() -> void:
	"""Planks, wood, meals, then every crop of the farm's catalog, in its order; the Firewood is never offered."""
	var kinds := PackedInt32Array()
	var items := PackedInt32Array()
	assert_equal(Kinds.goods_into(kinds, items), 3 + Catalog.ITEM_COUNT, "three goods and every crop")
	assert_equal([kinds[0], kinds[1], kinds[2]], [Kinds.KIND_PLANKS, Kinds.KIND_WOOD, Kinds.KIND_MEALS], "first")
	assert_equal(items[3 + CARROT], CARROT, "the catalog's own order")
	assert_equal(Kinds.good_name(Kinds.KIND_CROP, CARROT), "carrot", "its label")
	assert_false(kinds.has(Kinds.KIND_FIREWOOD), "the winter's own")
	assert_false(Kinds.addable(Kinds.KIND_FIREWOOD), "not addable")
	assert_equal(Kinds.title(Kinds.KIND_PLANKS, -1, 20000), "Keep 20 planks", "the brief's example")
	assert_equal(Kinds.title(Kinds.KIND_MEALS, -1, 3000), "Keep 3.0 days of meals", "the brief's example")
	assert_equal(Kinds.title(Kinds.KIND_WOOD, -1, 40000), "Keep 40 logs", "wood in logs (decision 1801)")
	assert_equal(Kinds.title(Kinds.KIND_CROP, 2, 10000), "Keep 2 baskets of carrots", "a crop in its own measure")
	assert_equal(Kinds.target_text(Kinds.KIND_CROP, Kinds.STEP[Kinds.KIND_CROP], 2), "5 bunches of carrots", "its step")
	assert_equal(Kinds.target_text(Kinds.KIND_CROP, 5000, 6), "3 cabbages", "a cabbage is 2 U: 5 U is a need, raised")
	assert_equal(Kinds.target_text(Kinds.KIND_CROP, 10000, 6), "5 cabbages", "10 U: exact")
	assert_equal(Kinds.target_text(Kinds.KIND_CROP, 15000, 10), "8 heads of celery", "7.5 heads: 8")
	assert_equal(Kinds.amount_text(Kinds.KIND_PLANKS, 0), "no planks", "none in store")
	assert_equal(Kinds.amount_text(Kinds.KIND_WOOD, 2999), "2 logs", "what is there, rounded down")
	assert_true(CropGoal.is_meal_crop(CARROT) and CropGoal.is_meal_crop(WHEAT), "roots and grain feed a dish")
	assert_true(CropGoal.is_meal_crop(PEA), "peas feed the bean hotpot, an everyday supper dish (decision 0601)")
	assert_false(CropGoal.is_meal_crop(Catalog.ITEM_FLOUR), "flour is no crop")


func test_adding_refuses_with_words() -> void:
	"""A bad kind, the Firewood, a second order for one good, an amount out of bounds, a full book, a missing goal."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	assert_equal(book.add(Kinds.KIND_FIREWOOD, -1, 1000), BookScript.REFUSE_KIND, "the winter's")
	assert_equal(book.add(Kinds.KIND_CROP, -1, 1000), BookScript.REFUSE_KIND, "a crop needs its item")
	assert_equal(book.add(Kinds.KIND_WOOD, -1, 1000), BookScript.REFUSE_NO_GOAL % "wood", "no woods here")
	assert_equal(book.add(Kinds.KIND_PLANKS, -1, 0), BookScript.REFUSE_AMOUNT % "200 planks", "zero")
	assert_equal(book.add(Kinds.KIND_PLANKS, -1, 200001), BookScript.REFUSE_AMOUNT % "200 planks", "past the most")
	assert_equal(book.add(Kinds.KIND_PLANKS, -1, 200000), "", "the most")
	assert_equal(book.add(Kinds.KIND_PLANKS, -1, 5000), BookScript.REFUSE_SAME % "planks", "one per good")
	assert_equal(book.count(), 1, "one")


func test_the_book_holds_twelve() -> void:
	"""Twelve orders; the thirteenth is refused."""
	var book := BookScript.new()
	book.set_goal(CropGoal.new(FarmCrewScript.new(), SimScript.new(), PantryScript.new(StorageScript.new(Vector2.ZERO))))
	for item: int in BookScript.MAX_ORDERS:
		assert_equal(book.add(Kinds.KIND_CROP, item, 1000), "", "order %d" % item)
	assert_equal(book.add(Kinds.KIND_CROP, BookScript.MAX_ORDERS, 1000), BookScript.REFUSE_FULL, "full")
	assert_equal(book.remove(0), "", "removed")
	assert_equal(book.add(Kinds.KIND_CROP, BookScript.MAX_ORDERS, 1000), "", "room again")
	assert_equal(book.remove(-1), BookScript.REFUSE_NO_ORDER, "nothing there")


# --- the latch, the committed output, the jobs --------------------------------------------------------

func test_the_latch_starts_below_the_amount_and_stops_at_the_band() -> void:
	"""Planks 20 U, band 2 U: working below 20, satisfied from 22; between them it keeps what it was (no flapping)."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	var goal: FakeGoal = pair[1]
	goal.each = 0
	goal.have = 21000
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	assert_equal(book.state[0], BookScript.STATE_SATISFIED, "21 of 20: satisfied")
	goal.have = 19999
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "under 20: working")
	goal.have = 21000
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "21 while working: still working")
	goal.have = 22000
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_SATISFIED, "22: satisfied")
	goal.have = 20000
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_SATISFIED, "exactly 20: not below")


func test_committed_output_counts_against_the_target() -> void:
	"""REQ-SET-098: jobs open only while the good plus what they will bring is short of amount plus band, up to the
	kind's most."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	var goal: FakeGoal = pair[1]
	goal.have = 19000
	goal.each = 2000
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	assert_equal(book.jobs_of(0), 2, "19 + 2 + 2 >= 22: two")
	assert_equal(book.committed[0], 4000, "counted")
	goal.each = 5000
	goal.live_keys.clear()
	book.keep(0)
	assert_equal(book.jobs_of(0), 1, "finished jobs let go; one of 5 U is enough")
	goal.each = 100
	book.keep(0)
	assert_equal(book.jobs_of(0), Kinds.MAX_JOBS[Kinds.KIND_PLANKS], "never more than the kind's most")


func test_off_queues_nothing_and_remove_leaves_the_work() -> void:
	"""Switched off: OFF, nothing opened; on again: working. Removed: its jobs are not touched."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	var goal: FakeGoal = pair[1]
	goal.each = 0
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	assert_equal(book.set_enabled(0, false), "", "off")
	assert_equal(book.state[0], BookScript.STATE_OFF, "OFF")
	var keys: int = goal.next_key
	book.keep(0)
	assert_equal(goal.next_key, keys, "nothing opened while off")
	book.set_enabled(0, true)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "on: working")
	assert_equal(book.remove(0), "", "removed")
	assert_false(book.is_live(0), "gone")
	assert_equal(goal.live_keys.size(), goal.next_key, "its jobs left as they were")


func test_amount_steps_within_bounds() -> void:
	"""− and + move by the kind's step, never under one step nor past the most."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	(pair[1] as FakeGoal).have = 999999
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	book.step_amount(0, 1)
	assert_equal(book.amount[0], 25000, "+5")
	book.step_amount(0, -100)
	assert_equal(book.amount[0], Kinds.STEP[Kinds.KIND_PLANKS], "at least a step")
	book.step_amount(0, 1000)
	assert_equal(book.amount[0], Kinds.MAX_AMOUNT[Kinds.KIND_PLANKS], "at most the most")
	assert_equal(book.set_priority(0, 0), BookScript.REFUSE_PRIORITY, "0 is forbidden, not a priority")
	assert_equal(book.set_priority(0, 5), BookScript.REFUSE_PRIORITY, "past low")


# --- the blocked notice, and no other ----------------------------------------------------------------

func test_only_a_blocked_order_raises_a_notice_and_once() -> void:
	"""Blocked with no job: one notice with its reason; kept again: no second; unblocked: its watch says resolved;
	working and satisfied raise nothing."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	var goal: FakeGoal = pair[1]
	var said: Array[String] = []
	var watches: Array[Callable] = []
	book.set_reporter(func(_key: String, text: String, watch: Callable) -> void:
		said.append(text)
		watches.append(watch))
	goal.have = 30000
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	goal.have = 0
	goal.each = 0
	book.keep(0)
	assert_equal(said.size(), 0, "working: no notice")
	goal.live_keys.clear()
	goal.refuse = "no wood"
	book.keep(0)
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_BLOCKED, "blocked")
	assert_equal(said, [BookScript.NOTICE % ["Keep 20 planks", "no wood"]] as Array[String], "once, why")
	assert_equal(int(watches[0].call()), BookScript.INCIDENT_OPEN, "open")
	goal.refuse = ""
	book.keep(0)
	assert_equal(int(watches[0].call()), BookScript.INCIDENT_RESOLVED, "resolved")


# --- the real owners ----------------------------------------------------------------------------------

func test_keep_planks_queues_sawing_on_the_woods_board() -> void:
	"""Keep 20 U of planks with none and 60 U of wood: two Saw planks jobs on the woods' board, listed by the work
	board, at the order's priority; satisfied once 22 U are in store."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var book: BookScript = rig.standing.book
	assert_equal(book.add(Kinds.KIND_PLANKS, -1, 20000, WorkIds.PRIORITY_HIGH), "", "added")
	assert_equal(book.state[0], BookScript.STATE_WORKING, "working")
	assert_equal(book.jobs_of(0), 2, "two saw batches")
	var row: int = book.job_row[0]
	assert_equal(rig.forestry.crew.jobs.kind[row], ForestJobs.KIND_SAW, "sawing")
	assert_true(rig.board.source(WorkIds.SOURCE_WOODS).waiting(row), "on the board, waiting to be claimed")
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_WOODS, row), WorkIds.PRIORITY_HIGH, "the order's priority")
	book.set_priority(0, WorkIds.PRIORITY_LOW)
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_WOODS, row), WorkIds.PRIORITY_LOW, "moved with it")
	rig.services.stores.add_planks(22000)
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_SATISFIED, "satisfied")


func test_keep_planks_is_blocked_without_wood_and_says_it_in_the_incidents() -> void:
	"""No wood to saw: blocked, saying so, a Village warning incident raised once; wood in: resolved."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 500
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	assert_equal(book.state[0], BookScript.STATE_BLOCKED, "blocked")
	assert_true(book.reason[0].begins_with("not enough wood to saw"), book.reason[0])
	var serial: int = rig.services.incidents.serial_of(BookScript.KEY_BLOCKED % book.serial[0])
	assert_true(serial != IncidentsScript.NO_SERIAL and rig.services.incidents.is_unresolved(serial), "raised")
	book.keep(0)
	assert_equal(rig.services.incidents.count_of(serial), 1, "not raised again")
	rig.services.stores.wood_milli_u = 60000
	book.keep(0)
	rig.services.incidents.sweep()
	assert_false(rig.services.incidents.is_unresolved(serial), "resolved")


func test_keep_wood_gathers_deadfall_first_and_takes_the_fuel_bucket() -> void:
	"""Keep 40 U of wood with 5 U: a gather of deadfall (the winter's own rule), not the Firewood's origin; its jobs
	urgent while fuel-days are short, and not once they are not."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 5000
	rig.fuel_short = true
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_WOOD, -1, 40000)
	var row: int = book.job_row[0]
	assert_equal(rig.forestry.crew.jobs.kind[row], ForestJobs.KIND_GATHER, "deadfall first")
	assert_equal(rig.forestry.crew.jobs.origin[row], ForestJobs.ORIGIN_PLAYER, "the player's order, not the winter's")
	assert_true(rig.board.is_urgent(WorkIds.SOURCE_WOODS, row), "fuel short: bucket 2")
	assert_true(book.committed[0] > 0, "the pile counted")
	rig.fuel_short = false
	book.keep(0)
	assert_false(rig.board.is_urgent(WorkIds.SOURCE_WOODS, row), "fuel enough: ordinary")


func test_keep_a_crop_adopts_the_ripe_bed_s_harvest() -> void:
	"""Keep 10 U of carrot with none: the ripe carrot bed's harvest, counted at its expected yield; wheat growing but
	not ripe and peas not growing are blocked, each saying why."""
	var rig: Rig = _rig()
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_CROP, CARROT, 10000)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "working")
	var row: int = book.job_row[0]
	assert_equal(rig.farm.jobs.kind[row], FarmJobs.KIND_HARVEST, "a harvest")
	assert_equal(rig.farm.jobs.bed[row], BED_CARROTS, "the carrot bed")
	assert_true(book.committed[0] > 0, "its yield counted")
	assert_equal(book.jobs_of(0), 1, "one ripe carrot bed")
	book.add(Kinds.KIND_CROP, WHEAT, 10000)
	assert_true(book.reason[1].begins_with("no wheat bed is ripe yet"), book.reason[1])
	book.add(Kinds.KIND_CROP, PEA, 10000)
	assert_equal(book.reason[2], CropGoal.NONE_GROWING % "pea", "nothing growing")


func test_keep_meals_harvests_food_and_is_urgent_under_two_food_days() -> void:
	"""Keep 3 days of meals with no food: the ripe carrots (roots: soup) harvested, urgent (REQ-SET-113); no wood for
	the fire: blocked, saying so."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 10000
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_MEALS, -1, 3000)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "working")
	var row: int = book.job_row[0]
	assert_equal(rig.farm.jobs.bed[row], BED_CARROTS, "the carrots")
	assert_true(rig.board.is_urgent(WorkIds.SOURCE_FARM, row), "food short: bucket 2")
	assert_true(book.committed[0] > 0, "the soup it makes, in days")
	rig.services.stores.wood_milli_u = 0
	rig.farm.cancel_bed(BED_CARROTS)
	book.keep(0)
	assert_true(book.reason[0].begins_with("the kitchen's fire has no wood"), book.reason[0])


func test_the_driver_keeps_once_per_hour_moved() -> void:
	"""The node keeps the book when the calendar's hour moves -- once for a skip of many -- and not otherwise."""
	var rig: Rig = _rig()
	assert_false(rig.standing.tick(), "no hour yet")
	rig.services.calendar.tick += SimClock.TICKS_PER_HOUR
	assert_true(rig.standing.tick(), "an hour")
	rig.services.calendar.tick += 30 * SimClock.TICKS_PER_HOUR
	assert_true(rig.standing.tick(), "a skip")
	assert_false(rig.standing.tick(), "nothing more")
	assert_equal(rig.standing.hours_kept, 2, "kept twice")


func test_keeping_allocates_nothing() -> void:
	"""A thousand keeps and observes of working and satisfied orders retain no objects."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	book.add(Kinds.KIND_WOOD, -1, 10000)
	book.add(Kinds.KIND_CROP, CARROT, 10000)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 1000:
		book.on_hour()
		book.observe(k % 3)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "nothing kept")


# --- the winter's Firewood, built in --------------------------------------------------------------------

func test_the_firewood_is_a_built_in_order_that_can_be_switched_off() -> void:
	"""The winter's Firewood is the book's built-in order: listed, never edited or removed; switched off, the winter
	raises none; on, it raises it again at its next hour."""
	var suite := WinterTest.new()
	var v: RefCounted = suite._village(SkipScript.tick_of_hour(WinterTest.WINTER_HOUR))
	var winter: Node = v.get(&"winter")
	(v.get(&"services") as ServicesScript).stores.wood_milli_u = 5000
	winter.call(&"catch_up")
	var orders: BookScript = winter.get(&"_orders")
	var o: int = winter.call(&"firewood_order")
	assert_equal(orders.built_in[o], 1, "built in")
	assert_equal(orders.title_of(o), "Firewood for the winter", "its title")
	assert_equal(orders.remove(o), BookScript.REFUSE_BUILT_IN, "not removed")
	assert_equal(orders.set_amount(o, 1000), BookScript.REFUSE_BUILT_IN, "not edited")
	var row: int = winter.call(&"firewood_row")
	assert_true(row >= 0 and orders.jobs_of(o) == 1, "its one job held")
	(v.get(&"forestry") as ForestryScript).crew.cancel_row(row)
	orders.set_enabled(o, false)
	(v.get(&"services") as ServicesScript).calendar.tick += SimClock.TICKS_PER_HOUR
	winter.call(&"catch_up")
	assert_equal(int(winter.call(&"firewood_row")), -1, "off: none raised")
	orders.set_enabled(o, true)
	assert_true(int(winter.call(&"firewood_row")) >= 0, "on: raised again")
	suite.after_each()


# --- the Work screen's section --------------------------------------------------------------------------

func _screen_of(rig: Rig) -> ScreenScript:
	"""A Work screen over the rig's board with the Standing orders view, open on it."""
	var screen := ScreenScript.new()
	_keep(screen)
	screen.configure(rig.board, func(_who: int) -> String: return "", func() -> bool: return false)
	screen.set_standing(rig.standing.make_view())
	screen.toggle()
	screen.tab_button(ScreenScript.VIEW_ORDERS).pressed.emit()
	return screen


func test_the_work_screen_adds_and_shows_an_order() -> void:
	"""The Standing orders tab: the Add row offers planks first; Add order adds it; its row shows its target, state
	and the work it queued; its buttons edit it."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var screen: ScreenScript = _screen_of(rig)
	assert_true(screen.tab_button(ScreenScript.VIEW_ORDERS).visible, "the tab")
	var view := screen.standing_view() as ViewScript
	assert_true(view.visible, "shown")
	assert_equal(view.offered(), Vector3i(Kinds.KIND_PLANKS, -1, 20000), "planks first, 20 U")
	assert_equal(view.add_order(), ViewScript.ADDED % "Keep 20 planks", "added")
	var rows: Array[RowScript] = view.rows_shown()
	assert_equal(rows.size(), 1, "its row")
	var lines: PackedStringArray = rows[0].texts()
	assert_equal(lines[0], "Keep 20 planks · priority Normal · On", "the target")
	assert_true(lines[1].begins_with("Working: no planks in store, 4 planks coming — by sawing"), lines[1])
	assert_true(lines[2].begins_with("· Saw planks"), lines[2])
	rows[0].button(&"more").pressed.emit()
	assert_equal(rig.standing.book.amount[0], 25000, "+ Amount")
	assert_true(view.add_button().disabled, "one order per good: Add disabled")
	rows[0].button(&"remove").pressed.emit()
	assert_true(view.answer().begins_with("Removed: Keep 25 planks"), view.answer())
	assert_equal(view.rows_shown().size(), 0, "gone")


func test_a_built_in_row_can_only_be_switched() -> void:
	"""A built-in row: Remove and the amount disabled saying why; the switch works."""
	var rig: Rig = _rig()
	var goal := FakeGoal.new()
	goal.kind = Kinds.KIND_FIREWOOD
	var o: int = rig.standing.book.add_builtin(goal)
	var view := _screen_of(rig).standing_view() as ViewScript
	view.refresh()
	var row: RowScript = view.rows_shown()[0]
	assert_true(row.button(&"remove").disabled and row.button(&"less").disabled, "disabled")
	assert_equal(row.button(&"remove").tooltip_text, RowScript.BUILT_IN_WHY, "why")
	row.button(&"toggle").pressed.emit()
	assert_equal(rig.standing.book.enabled[o], 0, "switched off")
	assert_true(Text.title_line(rig.standing.book, o).ends_with(Text.BUILT_IN), "says built in")


# --- the edges the mutation run found unguarded ---------------------------------------------------------

func test_a_player_s_urgent_mark_holds_until_the_reserve_changes() -> void:
	"""The order writes Urgent only when the reserve's state changes: a mark the player clears holds through later
	keeps at the same state, and is written again once the state flips."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 5000
	rig.fuel_short = true
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_WOOD, -1, 40000)
	var row: int = book.job_row[0]
	rig.board.set_urgent(WorkIds.SOURCE_WOODS, row, false)
	book.keep(0)
	assert_false(rig.board.is_urgent(WorkIds.SOURCE_WOODS, row), "the player's mark holds")
	rig.fuel_short = false
	book.keep(0)
	rig.fuel_short = true
	book.keep(0)
	assert_true(rig.board.is_urgent(WorkIds.SOURCE_WOODS, row), "written again on a change")


func test_the_hour_never_keeps_a_built_in_order() -> void:
	"""`on_hour` keeps the player's orders; a built-in order is its owner's to keep (it opens nothing on the hour)."""
	var book := BookScript.new()
	var goal := FakeGoal.new()
	goal.kind = Kinds.KIND_FIREWOOD
	goal.own = true
	var o: int = book.add_builtin(goal)
	book.on_hour()
	assert_equal(goal.next_key, 0, "nothing opened on the hour")
	book.keep(o)
	assert_true(goal.next_key > 0, "its owner's keep opens it")


func test_only_a_food_crop_is_urgent_and_only_under_two_food_days() -> void:
	"""REQ-SET-113: a crop an everyday dish takes is urgent below 2.000 food-days, not at it; what is no crop never is."""
	var days: Array[int] = [1999]
	var goal := CropGoal.new(FarmCrewScript.new(), SimScript.new(), PantryScript.new(StorageScript.new(Vector2.ZERO)),
		func() -> int: return days[0])
	assert_true(goal.urgent(CARROT), "roots under two days")
	assert_true(goal.urgent(PEA), "peas too: the hotpot's")
	assert_false(goal.urgent(Catalog.ITEM_FLOUR), "no crop: never")
	days[0] = 2000
	assert_false(goal.urgent(CARROT), "two days exactly: ordinary")


func test_a_reused_board_row_is_another_job() -> void:
	"""A job's row reused by a new job is not the order's job any more: it is let go, not counted."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	var row: int = book.job_row[0]
	var held: int = book.job_key[0]
	rig.forestry.crew.cancel_row(row)
	var read := IntMath.IntResult.new()
	assert_true(rig.forestry.crew.jobs.open_into(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, ForestJobs.ORIGIN_PLAYER,
		read) and read.value == row, "the row reused")
	book.observe(0)
	assert_false(book.tracked(WorkIds.SOURCE_WOODS, held), "the old job let go")
	assert_false(book.tracked(WorkIds.SOURCE_WOODS, rig.forestry.crew.jobs.serial[row]), "the new one not adopted")


func test_the_firewood_raises_nothing_when_wood_is_plenty() -> void:
	"""Winter with 200 U of wood: the built-in order wants nothing, so a cancelled Firewood job is not raised again."""
	var suite := WinterTest.new()
	var v: RefCounted = suite._village(SkipScript.tick_of_hour(WinterTest.WINTER_HOUR))
	var winter: Node = v.get(&"winter")
	var services: ServicesScript = v.get(&"services")
	services.stores.wood_milli_u = 5000
	winter.call(&"catch_up")
	(v.get(&"forestry") as ForestryScript).crew.cancel_row(int(winter.call(&"firewood_row")))
	services.stores.wood_milli_u = 200000
	services.calendar.tick += SimClock.TICKS_PER_HOUR
	winter.call(&"catch_up")
	assert_equal(int(winter.call(&"firewood_row")), -1, "nothing raised")
	var orders: BookScript = winter.get(&"_orders")
	assert_equal(orders.state[int(winter.call(&"firewood_order"))], BookScript.STATE_SATISFIED, "satisfied")
	suite.after_each()


# --- the review's findings (H1, H2, M1-M3) ---------------------------------------------------------------

func test_adopting_a_harvest_keeps_the_player_s_marks() -> void:
	"""The farm's routine harvest the player marked URGENT and HIGHEST keeps both when a Normal order adopts it; the
	order's own priority change does not override the player's either."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 10000
	var stocked := IntMath.IntResult.new()
	rig.pantry.add_into(WHEAT, 60000, 0, stocked)
	assert_false(CropGoal.new(rig.farm, rig.sim, rig.pantry, rig.kitchen.days_of_meals_milli).food_short(),
		"food enough: the order has no urgency of its own to write")
	rig.farm.raise_routine_jobs()
	var read := IntMath.IntResult.new()
	assert_true(rig.farm.jobs.job_on_bed_into(FarmJobs.KIND_HARVEST, BED_CARROTS, read), "the routine harvest")
	rig.board.set_urgent(WorkIds.SOURCE_FARM, read.value, true)
	rig.board.set_task_priority(WorkIds.SOURCE_FARM, read.value, WorkIds.PRIORITY_HIGHEST)
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_CROP, CARROT, 1000)
	assert_equal(book.job_row[0], read.value, "adopted, not a second")
	assert_true(rig.board.is_urgent(WorkIds.SOURCE_FARM, read.value), "still urgent")
	book.set_priority(0, WorkIds.PRIORITY_LOW)
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_FARM, read.value), WorkIds.PRIORITY_HIGHEST, "still highest")


func test_the_driver_keeps_the_player_s_orders_on_the_hour_and_not_the_built_in() -> void:
	"""An order satisfied, its good then gone: nothing changes until the hour moves; then the driver keeps it and it
	works. A built-in order is not kept by the driver."""
	var rig: Rig = _rig()
	var book: BookScript = rig.standing.book
	var goal := FakeGoal.new()
	goal.have = 30000
	book.set_goal(goal)
	var built := FakeGoal.new()
	built.kind = Kinds.KIND_FIREWOOD
	built.own = true
	book.add_builtin(built)
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	var o: int = book.last_added
	goal.have = 0
	rig.standing.tick()
	assert_equal(book.state[o], BookScript.STATE_SATISFIED, "the same hour: not kept")
	rig.services.calendar.tick += SimClock.TICKS_PER_HOUR
	rig.standing.tick()
	assert_equal(book.state[o], BookScript.STATE_WORKING, "the next hour: kept, working")
	assert_equal(built.next_key, 0, "the built-in order not kept by the driver")


func test_an_order_whose_every_job_is_blocked_on_the_board_is_blocked() -> void:
	"""Both saw jobs waiting for a way: the order is Blocked with the board's words, and the view's observe keeps the
	reason."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	rig.forestry.crew.jobs.blocked[book.job_row[0]] = 1
	book.observe(0)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "one job still free to go")
	rig.forestry.crew.jobs.blocked[book.job_row[1]] = 1
	book.observe(0)
	assert_equal(book.state[0], BookScript.STATE_BLOCKED, "every job blocked")
	assert_equal(book.reason[0], WoodsWork.BLOCKED_WAY, "the board's words")
	book.observe(0)
	assert_equal(book.reason[0], WoodsWork.BLOCKED_WAY, "kept by observe")


func test_switching_resets_the_latch() -> void:
	"""Working at 21 U of a 20 U order: switched off and on again at 21 U it is satisfied (it starts below the amount)."""
	var pair: Array = _fake_book()
	var book: BookScript = pair[0]
	var goal: FakeGoal = pair[1]
	goal.each = 0
	goal.have = 0
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	goal.have = 21000
	book.keep(0)
	assert_equal(book.state[0], BookScript.STATE_WORKING, "working through the band")
	book.set_enabled(0, false)
	book.set_enabled(0, true)
	assert_equal(book.state[0], BookScript.STATE_SATISFIED, "the latch reset")


func test_a_full_woods_board_blocks_with_its_own_words() -> void:
	"""The woods' board full: planks and wood orders are blocked saying so (not "no wood")."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var read := IntMath.IntResult.new()
	while rig.forestry.crew.jobs.open_into(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, ForestJobs.ORIGIN_PLAYER, read):
		pass
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	book.add(Kinds.KIND_WOOD, -1, 100000)
	var full: String = "the woods' job board is full (%d jobs) — cancel some there first" % ForestJobs.MAX_JOBS
	assert_equal(book.reason[0], full, "planks")
	assert_equal(book.reason[1], full, "wood")


func test_a_built_in_order_s_priority_is_its_owner_s() -> void:
	"""The Firewood keeps decision 0571's priority: the book refuses to change it."""
	var book := BookScript.new()
	var goal := FakeGoal.new()
	goal.kind = Kinds.KIND_FIREWOOD
	var o: int = book.add_builtin(goal)
	assert_equal(book.set_priority(o, WorkIds.PRIORITY_HIGH), BookScript.REFUSE_BUILT_IN, "refused")
	assert_equal(book.priority[o], WorkIds.PRIORITY_NORMAL, "unchanged")


func test_a_priority_change_never_lands_on_a_reused_row() -> void:
	"""The order's job gone and its row reused by another job: changing the order's priority leaves that job alone."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 60000
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	var row: int = book.job_row[0]
	rig.forestry.crew.cancel_row(row)
	var read := IntMath.IntResult.new()
	rig.forestry.crew.jobs.open_into(ForestJobs.KIND_GRUB, 0, 0, ForestJobs.ORIGIN_PLAYER, read)
	assert_equal(read.value, row, "the row reused")
	book.set_priority(0, WorkIds.PRIORITY_LOW)
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_WOODS, row), WorkIds.PRIORITY_NORMAL, "the other job untouched")


func test_observe_keeps_a_refusal_s_reason() -> void:
	"""Blocked for want of wood with no job: the view's observe keeps it Blocked, saying why."""
	var rig: Rig = _rig()
	rig.services.stores.wood_milli_u = 0
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_PLANKS, -1, 20000)
	var why: String = book.reason[0]
	book.observe(0)
	assert_equal(book.state[0], BookScript.STATE_BLOCKED, "still blocked")
	assert_equal(book.reason[0], why, "still saying why")


func test_a_reused_farm_row_is_another_job() -> void:
	"""The carrot harvest's row reused by another farm job: let go, not counted."""
	var rig: Rig = _rig()
	var book: BookScript = rig.standing.book
	book.add(Kinds.KIND_CROP, CARROT, 10000)
	var row: int = book.job_row[0]
	rig.farm.cancel_bed(BED_CARROTS)
	var read := IntMath.IntResult.new()
	assert_true(rig.farm.jobs.open_into(FarmJobs.KIND_WATER, 0, FarmJobs.ORIGIN_PLAYER, read) and read.value == row,
		"the row reused")
	book.observe(0)
	assert_equal(book.jobs_of(0), 0, "let go")
	assert_equal(book.committed[0], 0, "not counted")
