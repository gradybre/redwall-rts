extends "res://test/framework/test_case.gd"
## The Cellar building (decision 0612): GDD §5.9's Cellar row read from the settlement's own tables; placed with the
## placing tool (where it may stand); its materials fetched from the village stores and built by residents through the
## work board (REQ-SET-124/125/126); once built, a CELLAR-class pantry store the haul, the Pantry and the why-note treat
## like any other. On the placeholder cast, stepped at 60 Hz, out of the tree.

const Rules := preload("res://demo/stores/cellar_rules.gd")
const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const BuildersScript := preload("res://demo/stores/cellar_builders.gd")
const PlaceScript := preload("res://demo/stores/cellar_place.gd")
const ViewScript := preload("res://demo/stores/cellar_view.gd")
const BarScript := preload("res://demo/stores/cellar_bar.gd")
const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const StoresWork := preload("res://demo/work/stores_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RowsScript := preload("res://demo/farm/farm_pantry_rows.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const DemoStoresScript := preload("res://demo/stores/demo_stores.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const CARROT: int = 2
const DT: float = 1.0 / 60.0
const USEC: int = 16667
const STORE_AT: Vector2 = Vector2(-3.0, 0.0)
const SITE: Vector2 = Vector2(4.0, 0.0)

var _cast: DemoCastScript = null
var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free what a test built."""
	if _cast != null:
		_cast.free()
		_cast = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- the numbers (cellar_rules.gd) ------------------------------------------------------------------

func test_the_cellar_figures_are_the_gdd_s_read_from_the_settlement_tables() -> void:
	"""GDD §5.9 line 639 and balance §4.1/§4.2: 6 x 6, wood 20 and stone 60, 900 WU, Hauler 2, 1000000 g, at most 4
	builders, unlocked at M1; at the GDD's 500 g a unit (§5.8's fixture) 2000 U; the CELLAR class's 350."""
	assert_equal(Rules.footprint_tiles(), Vector2i(6, 6), "6 x 6 tiles")
	assert_equal(Rules.cost_milli(Rules.MAT_WOOD), 20000, "wood 20")
	assert_equal(Rules.cost_milli(Rules.MAT_STONE), 60000, "stone 60")
	assert_equal(Rules.work_wu(), 900, "900 WU")
	assert_equal(Rules.hauler_slots(), 2, "Hauler 2")
	assert_equal(Rules.max_builders(), 4, "4 builders")
	assert_equal(Rules.defs().base_store_g_of(Rules.type_id()), 1000000, "1000000 g")
	assert_equal(Rules.defs().unlock_of(Rules.type_id()), 1, "M1")
	assert_equal(Rules.capacity_u(), 2000, "2000 U")
	assert_equal(StockAge.STORE_FACTOR[Rules.STORE_CLASS], 350, "the cellar factor")
	assert_equal(Rules.work_usec(), 900 * 150000, "a WU is 0.15 s of one builder's time")


func test_a_carry_is_the_carrier_s_mass_over_five_kilograms_a_unit() -> void:
	"""§5.2's 12000 / 16000 / 24000 g over §5.5's 5000 g of wood or stone: 2.4, 3.2 and 4.8 U."""
	assert_equal(Rules.carry_milli(MealRules.SIZE_SMALL, Rules.MAT_WOOD), 2400, "small")
	assert_equal(Rules.carry_milli(MealRules.SIZE_MEDIUM, Rules.MAT_STONE), 3200, "medium")
	assert_equal(Rules.carry_milli(MealRules.SIZE_LARGE, Rules.MAT_STONE), 4800, "large")


func test_a_cancel_returns_all_before_the_work_and_eighty_percent_floored_after() -> void:
	"""REQ-SET-126: 100% before work begins; after, 80% rounded down to the milli-U."""
	assert_equal(Rules.refund_milli(12345, false), 12345, "all of it")
	assert_equal(Rules.refund_milli(12345, true), 9876, "80% floored")
	assert_equal(Rules.refund_milli(0, true), 0, "nothing")


func test_the_unlock_options_and_their_boundaries() -> void:
	"""UNLOCK_START opens at once; M1 scaled needs day 4, the whole cast and 200 portions; portions-and-day the two."""
	assert_equal(Rules.UNLOCK, Rules.UNLOCK_START, "built: from the start")
	assert_true(Rules.unlocked(Rules.UNLOCK_START, 1, 0, 9, 0), "from the start")
	assert_true(Rules.unlocked(Rules.UNLOCK_M1_SCALED, 4, 9, 9, 200), "M1 met")
	assert_false(Rules.unlocked(Rules.UNLOCK_M1_SCALED, 3, 9, 9, 200), "day 3")
	assert_false(Rules.unlocked(Rules.UNLOCK_M1_SCALED, 4, 8, 9, 200), "a resident short")
	assert_false(Rules.unlocked(Rules.UNLOCK_M1_SCALED, 4, 9, 9, 199), "a portion short")
	assert_true(Rules.unlocked(Rules.UNLOCK_PORTIONS_AND_DAY, 4, 1, 9, 200), "no resident count")
	assert_false(Rules.unlocked(Rules.UNLOCK_PORTIONS_AND_DAY, 3, 9, 9, 500), "day 3")
	assert_equal(Rules.locked_words(Rules.UNLOCK_M1_SCALED, 9), "it opens at M1: day 4, all 9 residents and 200 portions cooked",
		"in words")
	assert_equal(Rules.locked_words(Rules.UNLOCK_START, 9), "", "none")


# --- the cellars (cellar_projects.gd) --------------------------------------------------------------------

func _stores(wood_u: int, stone_u: int) -> StoresScript:
	"""Village stores holding this much wood and stone."""
	var stores := StoresScript.new()
	stores.wood_milli_u = wood_u * 1000
	stores.stone_milli_u = stone_u * 1000
	return stores


func test_placing_deducts_nothing_and_at_most_two_stand() -> void:
	"""REQ-SET-124: a placed cellar takes nothing from the stores; a third is refused."""
	var stores := _stores(40, 20)
	var projects := ProjectsScript.new(stores)
	assert_equal(projects.plan_at(SITE, 0.0), 0, "the first")
	assert_equal(projects.state[0], ProjectsScript.STATE_DELIVERING, "its materials to fetch")
	assert_equal(stores.wood_milli_u, 40000, "nothing taken")
	assert_equal(projects.plan_at(Vector2(-8.0, 0.0), 0.0), 1, "the second")
	assert_equal(projects.plan_at(Vector2(0.0, 9.0), 0.0), ProjectsScript.NONE, "no third")


func test_a_material_is_reserved_lifted_from_the_stores_and_delivered_exactly() -> void:
	"""Reserving takes nothing; lifting takes what was reserved; the stores, a carrier's arms and the site always add up
	to what there was; only what the stores hold unreserved can be fetched."""
	var stores := _stores(40, 3)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	assert_equal(projects.fetchable(0, Rules.MAT_STONE), 3000, "only the stone there is")
	assert_equal(projects.reserve(0, Rules.MAT_STONE, 2400), 2400, "a small carry reserved")
	assert_equal(stores.stone_milli_u, 3000, "nothing taken yet")
	assert_equal(projects.fetchable(0, Rules.MAT_STONE), 600, "the rest of it")
	var lifted: int = projects.lift(0, Rules.MAT_STONE, 2400)
	assert_equal(lifted, 2400, "lifted")
	assert_equal(stores.stone_milli_u, 600, "taken now")
	assert_equal(projects.reserved_milli(0, Rules.MAT_STONE), 0, "the reservation spent")
	assert_equal(projects.outstanding(0, Rules.MAT_STONE), 57600, "the load in arms is not needed again")
	assert_true(projects.deliver(0, Rules.MAT_STONE, lifted), "delivered")
	assert_equal(stores.stone_milli_u + projects.delivered_milli(0, Rules.MAT_STONE), 3000, "nothing made or lost")
	assert_equal(projects.outstanding(0, Rules.MAT_STONE), 57600, "the rest still needed")
	assert_equal(projects.next_material(0), Rules.MAT_WOOD, "wood first while there is stone short")
	stores.stone_milli_u = 100000
	assert_equal(projects.reserve(0, Rules.MAT_STONE, 100000), 57600, "never more than it still needs")
	assert_equal(projects.fetchable(0, Rules.MAT_STONE), 0, "all of it being fetched")
	assert_equal(projects.reserve(0, Rules.MAT_STONE, 1000), 0, "nothing more")


func test_a_load_put_back_returns_to_the_stores_and_a_lift_takes_only_what_is_there() -> void:
	"""A carrier's load not delivered goes back whole; a lift with the stores emptied meanwhile takes what is left."""
	var stores := _stores(10, 0)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	projects.reserve(0, Rules.MAT_WOOD, 2400)
	stores.wood_milli_u = 1000
	assert_equal(projects.lift(0, Rules.MAT_WOOD, 2400), 1000, "what was there")
	assert_equal(projects.in_transit[Rules.MAT_WOOD], 1000, "in transit")
	assert_equal(projects.outstanding(0, Rules.MAT_WOOD), 19000, "in transit counts as on its way")
	projects.return_load(0, Rules.MAT_WOOD, 1000)
	assert_equal(stores.wood_milli_u, 1000, "back whole")
	assert_equal(projects.in_transit[Rules.MAT_WOOD], 0, "no longer in transit")
	stores.wood_milli_u = 0
	projects.reserve(0, Rules.MAT_WOOD, 2400)
	assert_equal(projects.lift(0, Rules.MAT_WOOD, 2400), 0, "nothing to lift")


func _deliver_all(projects: ProjectsScript) -> void:
	"""Every material of cellar 0 fetched and delivered."""
	for mat: int in Rules.MAT_COUNT:
		var need: int = Rules.cost_milli(mat)
		projects.reserve(0, mat, need)
		projects.deliver(0, mat, projects.lift(0, mat, need))


func test_all_delivered_starts_the_work_and_the_work_builds_it_into_a_store() -> void:
	"""REQ-SET-125: delivered in full it is being built; the builders' summed time builds it; built, it is one storage
	entry: its id, door, 2000 U, the CELLAR class and its why."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	assert_false(projects.add_work(0, 1000000), "no work before it is delivered")
	_deliver_all(projects)
	assert_equal(projects.state[0], ProjectsScript.STATE_BUILDING, "being built")
	assert_equal(stores.wood_milli_u + stores.stone_milli_u, 0, "all taken")
	assert_equal(projects.entries().size(), 0, "not a store yet")
	assert_false(projects.add_work(0, Rules.work_usec() - 1), "a microsecond short")
	assert_true(projects.add_work(0, 1), "built")
	assert_true(projects.is_done(0), "done")
	var entry: Dictionary = projects.entries()[0]
	assert_equal(entry[StorageScript.KEY_ID], &"cellar_building:0:1", "its id")
	assert_equal(entry[StorageScript.KEY_CAPACITY_U], 2000, "2000 U")
	assert_equal(entry[StorageScript.KEY_CLASS], StockAge.STORAGE_CELLAR, "a cellar")
	assert_equal(entry[StorageScript.KEY_WHY], Rules.WHY, "its why")
	assert_equal(entry[StorageScript.KEY_POSITION], projects.door_of(0), "at its door")
	assert_equal(projects.status_text(0), "Cellar 1: built — holds 400 baskets of food, food keeps as in a cool cellar",
		"its words: its 2000 U (at 500 g, decision 0612) as baskets of food, no weight")


func test_cancel_refunds_by_req_set_126_and_a_built_cellar_cannot_be_cancelled() -> void:
	"""Before work: everything delivered back; after work began: 80% floored; built: refused; nothing planned: refused."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	_deliver_all(projects)
	assert_equal(projects.refund_text(0), "returns 20 logs and 60 blocks of stone", "before")
	assert_equal(projects.cancel(0), "", "cancelled")
	assert_equal(stores.wood_milli_u, 20000, "all the wood back")
	assert_equal(stores.stone_milli_u, 60000, "all the stone back")
	assert_equal(projects.state[0], ProjectsScript.STATE_NONE, "gone")
	projects.plan_at(SITE, 0.0)
	_deliver_all(projects)
	projects.add_work(0, 1)
	assert_equal(projects.refund_text(0), "returns 16 logs and 48 blocks of stone (80%: the work has begun)", "after")
	projects.cancel(0)
	assert_equal(stores.wood_milli_u, 16000, "80% of the wood")
	assert_equal(stores.stone_milli_u, 48000, "80% of the stone")
	assert_equal(projects.cancel(0), ProjectsScript.REFUSE_NOT_PLANNED, "nothing planned")
	projects.plan_at(SITE, 0.0)
	stores.wood_milli_u = 20000
	stores.stone_milli_u = 60000
	_deliver_all(projects)
	projects.add_work(0, Rules.work_usec())
	assert_equal(projects.cancel(0), ProjectsScript.REFUSE_BUILT, "built")


func test_progress_is_half_delivery_and_half_work() -> void:
	"""Half the materials delivered: 25%; all and half the work: 75%; never 100 until built."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	assert_equal(projects.percent(0), 0, "nothing")
	projects.reserve(0, Rules.MAT_STONE, 40000)
	projects.deliver(0, Rules.MAT_STONE, projects.lift(0, Rules.MAT_STONE, 40000))
	assert_equal(projects.percent(0), 25, "half the materials")
	projects.reserve(0, Rules.MAT_WOOD, 20000)
	projects.deliver(0, Rules.MAT_WOOD, projects.lift(0, Rules.MAT_WOOD, 20000))
	projects.reserve(0, Rules.MAT_STONE, 20000)
	projects.deliver(0, Rules.MAT_STONE, projects.lift(0, Rules.MAT_STONE, 20000))
	@warning_ignore("integer_division")  # half the work by intent
	var half: int = Rules.work_usec() / 2
	projects.add_work(0, half)
	assert_equal(projects.percent(0), 75, "half the work")
	projects.add_work(0, half - 1)
	assert_equal(projects.percent(0), 99, "not done yet")
	assert_true(projects.status_text(0).begins_with("Cellar 1: being built — wood 20 logs — enough, stone 60 blocks — enough"),
		projects.status_text(0))


# --- the store it becomes ------------------------------------------------------------------------------

func test_a_built_cellar_is_a_cellar_store_the_haul_fills_and_the_pantry_explains() -> void:
	"""Through the provider: a CELLAR-class store at 350 per mille holding 2000 U; the why-note's line for it; the haul
	plans the covered store's carrots into it, like any other cooler store."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	_deliver_all(projects)
	projects.add_work(0, Rules.work_usec())
	var storage := StorageScript.new(STORE_AT)
	storage.add_provider(projects.provider())
	var pantry := PantryScript.new(storage)
	assert_equal(storage.count(), 2, "the covered store and the cellar")
	assert_equal(storage.class_of(1), StockAge.STORAGE_CELLAR, "a cellar")
	assert_equal(storage.permille_of(1), 350, "ages food at 350")
	assert_equal(storage.capacity_milli_of(1), 2000000, "2000 U")
	assert_equal(storage.label_of(1), "Cellar 1", "named")
	assert_true(RowsScript.why_text(pantry).contains(
		"Cellar 1 — a large store above ground: food keeps 2.8× as long as in the covered store"), "explained")
	pantry.add_into(CARROT, 5000, 0, _read)
	_build_cast()
	var haul := HaulScript.new()
	haul.configure(_cast, _cast.space().tunnels, pantry, Callable(), func() -> int: return 0)
	assert_equal(haul.plan(), 1, "a move planned")
	assert_equal(haul.destination_of(0), 1, "into the cellar building")


# --- building it (cellar_builders.gd) ---------------------------------------------------------------------

func _build_cast() -> void:
	"""The placeholder cast in the village's bounds, every one carrying at 2 m/s."""
	_cast = DemoCastScript.new()
	_cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	_cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 13.0 * k / 65.0])
	for i: int in _cast.actor_count():
		_brain(i).set_carry_motion({"keys_xz": keys, "mean_speed_m_s": 2.0, "period_s": 6.5})


func _brain(i: int) -> BrainScript:
	"""Actor i's brain."""
	return (_cast.actor(i) as DemoActorScript).brain


func _builders(stores: StoresScript) -> BuildersScript:
	"""A planned cellar at SITE and its builders on the placeholder cast, fetching from STORE_AT."""
	_build_cast()
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	var builders := BuildersScript.new(projects)
	builders.configure(_cast, null, STORE_AT)
	return builders


func _run(builders: BuildersScript, seconds: float, each: Callable = Callable()) -> void:
	"""Step every brain and the builders for `seconds` of demo time."""
	for f: int in roundi(seconds / DT):
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		builders.update(USEC)
		if each.is_valid():
			each.call()


func _books(stores: StoresScript, builders: BuildersScript, mat: int) -> int:
	"""A material's milli-U in the stores, in arms and at the site."""
	var at_site: int = builders.projects.delivered_milli(0, mat)
	return (stores.wood_milli_u if mat == Rules.MAT_WOOD else stores.stone_milli_u) + builders.in_hand_milli(mat) + at_site


func _claim_as_the_board(builders: BuildersScript) -> void:
	"""What the work board does each pass: a waiting place of cellar 0 to the first of residents 1-4 who is free."""
	for row: int in 4:
		if builders.waiting(row):
			for who: int in [1, 2, 3, 4]:
				if builders.row_of_worker(who) == BuildersScript.NONE and builders.claim(row, who):
					break


func test_four_residents_fetch_everything_and_build_it_with_nothing_made_or_lost() -> void:
	"""Four places claimed: they carry the wood and stone from the stores to the site -- the stores, their arms and the
	site adding up to what there was every frame -- then build it; built, they go back to their routines."""
	var stores := _stores(20, 60)
	var builders := _builders(stores)
	for row: int in 4:
		assert_true(builders.waiting(row), "place %d waits" % row)
		assert_true(builders.claim(row, row + 1), "claimed by %d" % (row + 1))
	assert_false(builders.waiting(4), "the second cellar's places are not wanted")
	var balanced: Array[bool] = [true]
	_run(builders, 400.0, func() -> void:
		balanced[0] = balanced[0] and (builders.projects.is_done(0) or (_books(stores, builders, Rules.MAT_WOOD) == 20000
			and _books(stores, builders, Rules.MAT_STONE) == 60000))
		_claim_as_the_board(builders))
	assert_true(balanced[0], "the books balanced every frame")
	assert_true(builders.projects.is_done(0), "built")
	assert_equal(stores.wood_milli_u + stores.stone_milli_u, 0, "every unit built in")
	for who: int in [1, 2, 3, 4]:
		assert_equal(builders.row_of_worker(who), BuildersScript.NONE, "resident %d done" % who)
		assert_equal(_brain(who).order, BrainScript.ORDER_NONE, "resident %d back to its routine" % who)


func test_a_builder_called_away_with_a_load_puts_it_back_and_the_place_waits() -> void:
	"""Ordered elsewhere carrying stone: the stone goes back into the stores whole (never delivered from afar), and the
	place waits for a resident again."""
	var stores := _stores(0, 60)
	var builders := _builders(stores)
	builders.claim(0, 1)
	for f: int in 12000:
		if builders.carrying(0) and builders.issued[0] == 1:
			break
		_run(builders, DT)
	assert_true(builders.carrying(0), "carrying")
	assert_equal(stores.stone_milli_u, 60000 - builders.load_milli[0], "lifted from the stores")
	_brain(1).order_move(Vector2(-8.0, -8.0))
	builders.update(USEC)
	assert_equal(stores.stone_milli_u, 60000, "back whole")
	assert_equal(builders.projects.delivered_milli(0, Rules.MAT_STONE), 0, "nothing delivered")
	assert_equal(builders.projects.reserved_milli(0, Rules.MAT_STONE), 0, "nothing reserved")
	assert_true(builders.waiting(0), "waits again")


func test_a_place_waits_only_while_there_is_something_to_fetch_or_build() -> void:
	"""No stone and no wood in the stores: nothing to fetch, so no place waits; stone arrives: they wait; the cellar
	cancelled: none."""
	var stores := _stores(0, 0)
	var builders := _builders(stores)
	assert_false(builders.waiting(0), "nothing to fetch")
	assert_false(builders.is_live(0), "not on the board")
	stores.stone_milli_u = 5000
	assert_true(builders.waiting(0), "stone to fetch")
	builders.projects.cancel(0)
	assert_false(builders.waiting(0), "cancelled")


func test_a_resident_who_cannot_carry_is_refused_and_one_place_each() -> void:
	"""No carry walk: refused in words; a resident on one place cannot take another."""
	var builders := _builders(_stores(20, 60))
	_brain(0)._carry_velocity.clear()
	assert_equal(builders.eligibility(0, 0), BuildersScript.CANT_CARRY, "can't carry")
	assert_false(builders.claim(0, 0), "not claimed")
	builders.claim(0, 1)
	assert_equal(builders.eligibility(1, 1), BuildersScript.OTHER_PLACE, "one place each")
	assert_equal(builders.eligibility(0, 1), "", "its own")


func test_pause_and_reassign_before_a_load_and_refused_with_one() -> void:
	"""Paused, the resident is let go and the place does not wait; resumed it does; reassigned before a load, the new
	resident takes it; with a load in arms both are refused."""
	var stores := _stores(0, 60)
	var builders := _builders(stores)
	builders.claim(0, 1)
	assert_equal(builders.pause(0, true), "", "paused")
	assert_false(builders.waiting(0), "not claimed while paused")
	assert_true(builders.is_live(0), "still on the board")
	assert_equal(builders.projects.reserved_milli(0, Rules.MAT_STONE), 0, "its reservation given up")
	assert_equal(builders.pause(0, false), "", "resumed")
	builders.claim(0, 1)
	assert_equal(builders.reassign(0, 2), "", "handed over")
	assert_equal(builders.worker[0], 2, "to 2")
	for f: int in 12000:
		if builders.carrying(0):
			break
		_run(builders, DT)
	assert_equal(builders.pause(0, true), BuildersScript.IN_HAND, "pause refused")
	assert_equal(builders.reassign(0, 3), BuildersScript.IN_HAND, "reassign refused")


func test_cancelling_a_cellar_lets_its_builders_go_and_returns_their_loads() -> void:
	"""release_cellar then cancel: every builder let go, loads and reservations back, delivered stone refunded whole."""
	var stores := _stores(0, 60)
	var builders := _builders(stores)
	builders.claim(0, 1)
	builders.claim(1, 2)
	_run(builders, 30.0)
	builders.release_cellar(0)
	assert_equal(builders.builders_on(0), 0, "nobody on it")
	assert_equal(builders.projects.cancel(0), "", "cancelled")
	assert_equal(stores.stone_milli_u, 60000, "every unit back")
	assert_equal(builders.doing_text(1), "", "1 is doing nothing for it")


func test_a_builder_s_words_say_what_and_where() -> void:
	"""The party panel's words: fetching which material for which cellar."""
	var builders := _builders(_stores(0, 60))
	builders.claim(0, 1)
	assert_equal(builders.doing_text(1), "Going to the stockpile for stone for the cellar 1", "fetching")
	assert_equal(builders.doing_text(2), "", "not a builder")


func test_a_place_that_gave_up_rests_before_it_waits_again() -> void:
	"""The stockpile stands off the village: the walk cannot be given, the builder is let go, and the place does not
	wait again until RETRY_USEC has passed."""
	var stores := _stores(0, 60)
	_build_cast()
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	var builders := BuildersScript.new(projects)
	builders.configure(_cast, null, Vector2(80.0, 0.0))
	builders.claim(0, 1)
	builders.update(USEC)
	assert_equal(builders.worker[0], BuildersScript.NOBODY, "let go")
	assert_equal(projects.reserved_milli(0, Rules.MAT_STONE), 0, "its reservation given up")
	assert_false(builders.waiting(0), "resting")
	builders.update(BuildersScript.RETRY_USEC - USEC)
	assert_false(builders.waiting(0), "a microsecond before")
	builders.update(USEC)
	assert_true(builders.waiting(0), "waits again")


func test_a_builder_holding_away_from_its_spot_has_not_arrived() -> void:
	"""A walk that ended holding 5 m off is a failed try, never an arrival; a builder found off its spot at the lift
	goes back to the walk, nothing lifted (decision 0361)."""
	var stores := _stores(0, 60)
	var builders := _builders(stores)
	builders.claim(0, 1)
	builders.update(USEC)
	assert_equal(builders.issued[0], 1, "the walk issued")
	var brain := _brain(1)
	brain.state = BrainScript.State.HOLD
	brain.position = builders.goal[0] + Vector2(5.0, 0.0)
	builders.update(USEC)
	assert_equal(builders.step[0], BuildersScript.STEP_TO_STORE, "not arrived")
	assert_equal(builders.tries[0], 1, "a failed try")
	for f: int in 12000:
		if builders.step[0] == BuildersScript.STEP_LIFT:
			break
		_run(builders, DT)
	brain.position = builders.goal[0] + Vector2(5.0, 0.0)
	builders.update(USEC)
	assert_equal(builders.step[0], BuildersScript.STEP_TO_STORE, "back to the walk")
	assert_equal(stores.stone_milli_u, 60000, "nothing lifted")


func test_the_frame_a_cellar_is_built_every_builder_on_it_is_let_go() -> void:
	"""Two builders at work: the frame the work completes, both are done -- not one frame later."""
	var stores := _stores(20, 60)
	var builders := _builders(stores)
	_deliver_all(builders.projects)
	builders.claim(0, 1)
	builders.claim(1, 2)
	for f: int in 60000:
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		builders.update(USEC)
		if builders.projects.is_done(0):
			break
	assert_true(builders.projects.is_done(0), "built")
	assert_equal(builders.builders_on(0), 0, "both let go that frame")


func test_a_cellar_cancelled_under_its_builders_lets_them_go_next_frame() -> void:
	"""Cancelled straight through the cellars (no release first): the next frame lets the builder go, its reservation
	given up and its load back."""
	var stores := _stores(0, 60)
	var builders := _builders(stores)
	builders.claim(0, 1)
	builders.update(USEC)
	builders.projects.cancel(0)
	builders.update(USEC)
	assert_equal(builders.worker[0], BuildersScript.NOBODY, "let go")
	assert_equal(_brain(1).order, BrainScript.ORDER_NONE, "back to its routine")


func test_with_more_in_the_stores_the_builders_fetch_exactly_what_it_costs() -> void:
	"""Stores holding 100 wood and 200 stone, four builders: at the switch to building exactly 20 wood and 60 stone are
	at the site, and when built exactly that much has left the stores -- a load in arms is never fetched again, and a
	load lifted for a cellar that stopped taking deliveries goes back (the review's H1)."""
	var stores := _stores(100, 200)
	var builders := _builders(stores)
	for row: int in 4:
		builders.claim(row, row + 1)
	var at_switch := Vector2i(-1, -1)
	var balanced: Array[bool] = [true]
	for f: int in roundi(400.0 / DT):
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		builders.update(USEC)
		_claim_as_the_board(builders)
		var site: int = builders.projects.delivered_milli(0, Rules.MAT_WOOD) + builders.projects.delivered_milli(0, Rules.MAT_STONE)
		if at_switch.x < 0 and builders.projects.state[0] != ProjectsScript.STATE_DELIVERING:
			at_switch = Vector2i(builders.projects.delivered_milli(0, Rules.MAT_WOOD), builders.projects.delivered_milli(0, Rules.MAT_STONE))
		balanced[0] = balanced[0] and (builders.projects.is_done(0) or site + builders.in_hand_milli(Rules.MAT_WOOD)
			+ builders.in_hand_milli(Rules.MAT_STONE) + stores.wood_milli_u + stores.stone_milli_u == 300000)
		if builders.projects.is_done(0):
			break
	assert_equal(at_switch, Vector2i(20000, 60000), "exactly the cost at the site")
	assert_true(builders.projects.is_done(0), "built")
	assert_true(balanced[0], "every milli-U accounted for every frame")
	assert_equal(stores.wood_milli_u, 80000, "20 wood used")
	assert_equal(stores.stone_milli_u, 140000, "60 stone used")


func test_a_load_for_a_cellar_no_longer_taking_deliveries_goes_back() -> void:
	"""Lift refused and deliver refused outside DELIVERING: the carrier's load returns whole."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	projects.reserve(0, Rules.MAT_WOOD, 2000)
	var lifted: int = projects.lift(0, Rules.MAT_WOOD, 2000)
	_deliver_rest(projects)
	assert_equal(projects.state[0], ProjectsScript.STATE_DELIVERING, "2 wood still out")
	projects.cancel(0)
	assert_false(projects.deliver(0, Rules.MAT_WOOD, lifted), "not delivered to a cancelled cellar")
	projects.return_load(0, Rules.MAT_WOOD, lifted)
	assert_equal(stores.wood_milli_u + stores.stone_milli_u, 80000, "everything back")
	stores.stone_milli_u += 5000
	projects.plan_at(SITE, 0.0)
	_deliver_all(projects)
	assert_equal(projects.lift(0, Rules.MAT_STONE, 1000), 0, "no lift for a cellar being built")
	assert_equal(stores.stone_milli_u, 5000, "nothing taken")


func _deliver_rest(projects: ProjectsScript) -> void:
	"""Everything of cellar 0 still outstanding fetched and delivered."""
	for mat: int in Rules.MAT_COUNT:
		var need: int = projects.outstanding(0, mat)
		projects.reserve(0, mat, need)
		projects.deliver(0, mat, projects.lift(0, mat, need))


func test_a_place_keeps_its_board_key_through_claims_and_a_new_cellar_gets_a_new_one() -> void:
	"""The key is the cellar's life and the slot: the same before and after a claim and a call-away; a cellar placed
	again in the row is a new task (the review's H3)."""
	var stores := _stores(20, 60)
	var builders := _builders(stores)
	var source := StoresWork.new(HaulScript.new(), PantryScript.new(StorageScript.new()), [] as Array[BrainScript],
		builders)
	var row: int = HaulScript.MAX_ROWS + 1
	var before: int = source.key(row)
	builders.claim(1, 2)
	assert_equal(source.key(row), before, "the same once claimed")
	builders.let_go(1)
	builders.claim(1, 3)
	assert_equal(source.key(row), before, "the same after a call-away")
	assert_true(source.key(row) != source.key(row + 1), "each slot its own")
	builders.release_cellar(0)
	builders.projects.cancel(0)
	builders.projects.plan_at(SITE, 0.0)
	assert_true(source.key(row) != before, "a new cellar, a new task")


# --- placing it (cellar_place.gd) ------------------------------------------------------------------------

func _site() -> RoomsScript.Site:
	"""A 40 m village with a tree at (10, 10), a work spot at (-10, 10), a building at (10, -10), a bed at (-10, -10)
	and water along x = 18."""
	var site := RoomsScript.Site.new()
	site.bounds_u = Rect2i(-20480, -20480, 40960, 40960)
	site.circles_u = PackedInt32Array([10240, 1024, 10240])
	site.spots_u = PackedInt32Array([-10240, 512, 10240])
	site.under_u = PackedInt32Array([10240, 2048, -10240])
	site.beds_u = PackedInt32Array([-10240, 1536, -10240])
	site.water = func(a: Vector2i, _b: Vector2i, clearance: int) -> bool: return a.x + clearance > 18432
	return site


func test_a_cellar_may_stand_only_clear_of_everything() -> void:
	"""Off the village, on an obstacle, a work spot, a building, a bed, by the water, over a tunnel, over a dug room or
	by another cellar: refused in words; in the open: allowed."""
	var projects := ProjectsScript.new(_stores(0, 0))
	var network := GraphScript.new()
	var site := _site()
	assert_equal(PlaceScript.refusal_at(Vector2.ZERO, site, network, projects), "", "in the open")
	assert_equal(PlaceScript.refusal_at(Vector2(19.0, -2.0), site, network, projects), PlaceScript.REFUSE_OFF, "off")
	assert_equal(PlaceScript.refusal_at(Vector2(10.0, 12.0), site, network, projects), PlaceScript.REFUSE_BLOCKED, "tree")
	assert_equal(PlaceScript.refusal_at(Vector2(-10.0, 12.0), site, network, projects), PlaceScript.REFUSE_SPOT, "spot")
	assert_equal(PlaceScript.refusal_at(Vector2(10.0, -13.0), site, network, projects), PlaceScript.REFUSE_BUILDING,
		"building")
	assert_equal(PlaceScript.refusal_at(Vector2(-10.0, -13.0), site, network, projects), PlaceScript.REFUSE_BED, "bed")
	assert_equal(PlaceScript.refusal_at(Vector2(16.5, 0.0), site, network, projects), PlaceScript.REFUSE_WATER, "water")
	projects.plan_at(Vector2(0.0, 5.0), 0.0)
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, 0.0), site, network, projects), PlaceScript.REFUSE_CELLAR, "cellar")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -5.0), site, network, projects), "", "far enough from it")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([-4096, -8192, 4096, -8192]), 2, 0, ref), "a tunnel")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -7.0), site, network, projects), PlaceScript.REFUSE_TUNNEL, "tunnel")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -5.0), site, network, projects), PlaceScript.REFUSE_TUNNEL,
		"3 m off: inside its reach and a pillar of earth")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -4.5), site, network, projects), "", "3.5 m off: clear")
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-12288, 0), 0, 0, room)
	assert_equal(PlaceScript.refusal_at(Vector2(-12.0, -3.5), site, network, projects), PlaceScript.REFUSE_TUNNEL,
		"a dug room: its body is the network's too")


func test_a_cellar_whose_door_or_site_would_be_blocked_is_refused() -> void:
	"""The centre is clear but a post stands where its door would be (2.9 m toward the square): refused; moved so the
	door is clear: allowed."""
	var site := _site()
	site.circles_u = PackedInt32Array([11878, 307, 0])
	var projects := ProjectsScript.new(_stores(0, 0))
	assert_equal(ProjectsScript.door_point(Vector2(14.5, 0.0), PlaceScript.face_of(Vector2(14.5, 0.0))).round(),
		Vector2(12.0, 0.0), "its door toward the square")
	assert_equal(PlaceScript.refusal_at(Vector2(14.5, 0.0), site, null, projects), PlaceScript.REFUSE_DOOR, "blocked")
	assert_equal(PlaceScript.refusal_at(Vector2(14.5, 4.0), site, null, projects), "", "clear")


func _tool() -> PlaceScript:
	"""The placing tool over a fresh pair of cellars and `_site()`, out of the tree, with no camera."""
	var tool := PlaceScript.new()
	_nodes.append(tool)
	var said: Array[String] = [""]
	tool.set_meta(&"said", said)
	tool.configure(ProjectsScript.new(_stores(0, 0)), _site, Callable(), GraphScript.new(), null, null,
		func(text: String) -> void: said[0] = text)
	return tool


func test_the_tool_places_where_allowed_says_why_where_not_and_is_put_away() -> void:
	"""Armed, a clear spot places cellar 1 (and the tool is put away); a refused spot says why; Esc and a right click
	put it away; the cellar faces the square."""
	var tool := _tool()
	var said: Array[String] = tool.get_meta(&"said")
	tool.arm()
	assert_equal(said[0], PlaceScript.PROMPT, "the prompt")
	tool.move_to(Vector2(10.0, 12.0))
	assert_false(tool.place(), "refused")
	assert_equal(said[0], PlaceScript.REFUSED % PlaceScript.REFUSE_BLOCKED, "why")
	tool.move_to(Vector2(0.0, 6.0))
	assert_true(tool.place(), "placed")
	assert_false(tool.armed, "put away")
	assert_equal(said[0], "Cellar 1 planned: 20 logs and 60 blocks of stone to fetch, then 900 WU of building", "said")
	assert_almost_equal(absf(angle_difference(PlaceScript.face_of(Vector2(0.0, 6.0)), PI)), 0.0, "faces the square")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tool.arm()
	assert_true(tool.handle_input(esc), "Esc taken")
	assert_false(tool.armed, "put away")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_false(tool.handle_input(right), "nothing taken while not armed")
	tool.arm()
	assert_true(tool.handle_input(right), "right click taken")
	assert_false(tool.armed, "put away")


# --- drawn, in the Pantry, and on the board ------------------------------------------------------------

func test_the_cellar_is_drawn_flat_then_rising_then_whole_and_its_piles_grow() -> void:
	"""Placed: pressed flat; delivered and half built: half-risen; built: whole, its piles gone; a pile with something
	delivered at least PILE_MIN."""
	var stores := _stores(20, 60)
	var projects := ProjectsScript.new(stores)
	projects.plan_at(SITE, 0.0)
	assert_equal(ViewScript.body_scale(projects, 0), ViewScript.MARKED_SCALE, "flat")
	assert_equal(ViewScript.pile_scale(projects, 0, Rules.MAT_WOOD), 0.0, "no pile yet")
	projects.reserve(0, Rules.MAT_WOOD, 1000)
	projects.deliver(0, Rules.MAT_WOOD, projects.lift(0, Rules.MAT_WOOD, 1000))
	assert_true(ViewScript.pile_scale(projects, 0, Rules.MAT_WOOD) >= ViewScript.PILE_MIN, "a small pile")
	_deliver_all(projects)
	@warning_ignore("integer_division")  # half the work by intent
	var half: int = Rules.work_usec() / 2
	projects.add_work(0, half)
	assert_almost_equal(ViewScript.body_scale(projects, 0), lerpf(ViewScript.BEGUN_SCALE, 1.0, 0.5), "half-risen")
	assert_equal(ViewScript.label_text(projects, 0), "Cellar 1 · 75%", "its words")
	projects.add_work(0, half)
	assert_equal(ViewScript.body_scale(projects, 0), 1.0, "whole")
	assert_equal(ViewScript.pile_scale(projects, 0, Rules.MAT_STONE), 0.0, "built in")
	assert_equal(ViewScript.label_text(projects, 0), "Cellar 1", "named")
	var view := ViewScript.new()
	_nodes.append(view)
	view.configure(projects, null)
	assert_true(view.body_of(0).visible, "drawn")
	assert_false(view.body_of(1).visible, "the free row is not")


func test_the_pantry_bar_lists_cellars_and_refuses_a_third() -> void:
	"""A line a cellar with its Cancel while planned; the Build button refused with two planned, or while locked."""
	var projects := ProjectsScript.new(_stores(0, 0))
	var locked: Array[String] = [""]
	var bar := BarScript.new()
	_nodes.append(bar)
	bar.configure(projects, func() -> String: return locked[0])
	assert_true(bar.build_refusal().is_empty(), "open")
	assert_equal((bar.get_child(0) as Label).text,
		"Cellar buildings — each holds 400 baskets of food, kept 2.8× as long as in the covered store", "its heading")
	projects.plan_at(SITE, 0.0)
	bar.refresh()
	assert_true(bar.line_text(0).begins_with("Cellar 1: materials being fetched"), "its line")
	assert_true(bar.cancel_button(0).visible, "its Cancel")
	assert_true(bar.cancel_button(0).tooltip_text.contains("returns no wood and no stone"), "what it returns")
	projects.plan_at(Vector2(-8.0, 0.0), 0.0)
	bar.refresh()
	assert_equal(bar.build_refusal(), ProjectsScript.REFUSE_FULL, "two planned")
	assert_true(bar.build_button().disabled, "disabled")
	projects.cancel(1)
	locked[0] = "not yet"
	assert_equal(bar.build_refusal(), "not yet", "locked")


func test_the_board_lists_a_cellar_s_places_after_the_moves() -> void:
	"""The Food stores source: its rows past the moves are the cellar's places -- fetching (HAULING), then building
	(BUILDING); claimed through the source; cancelled only with the cellar."""
	var stores := _stores(20, 60)
	var builders := _builders(stores)
	var brains: Array[BrainScript] = []
	for i: int in _cast.actor_count():
		brains.append(_brain(i))
	var pantry := PantryScript.new(StorageScript.new())
	var source := StoresWork.new(HaulScript.new(), pantry, brains, builders)
	var row: int = HaulScript.MAX_ROWS
	assert_equal(source.capacity(), HaulScript.MAX_ROWS + BuildersScript.capacity(), "moves then places")
	assert_true(source.live(row) and source.waiting(row), "the first place waits")
	assert_equal(source.activity(row), WorkIds.ACT_HAUL, "fetching is hauling")
	var task := TaskScript.new()
	source.fill(task, row)
	assert_equal(task.action, "Fetch materials for", "the verb")
	assert_equal(task.target, "cellar 1", "the cellar")
	assert_equal(source.cancel(row), StoresWork.BY_ITS_CELLAR, "cancelled with its cellar")
	assert_true(source.claim(row, 1), "claimed")
	assert_equal(source.worker(row), 1, "by 1")
	_deliver_all(builders.projects)
	assert_equal(source.activity(row), WorkIds.ACT_BUILD, "building")
	source.fill(task, row)
	assert_equal(task.action, "Build", "the verb")


func test_a_placed_cellar_stands_as_an_obstacle_until_cancelled() -> void:
	"""cast_space.gd `set_structure`: the circle is an obstacle; radius 0 takes it away."""
	_build_cast()
	var space := _cast.space()
	var before: int = space.obstacles.size()
	space.set_structure(0, Vector3(4.0, ProjectsScript.RADIUS_M, 0.0))
	assert_equal(space.obstacles.size(), before + 1, "an obstacle")
	assert_true(space.obstacles.has(Vector3(4.0, ProjectsScript.RADIUS_M, 0.0)), "its circle")
	space.set_structure(0, Vector3.ZERO)
	assert_equal(space.obstacles.size(), before, "gone")


func test_the_village_stores_node_places_stands_cancels_and_stores_a_cellar() -> void:
	"""demo_stores.gd end to end: Build arms the tool; Esc puts it away; placed, the cellar is an obstacle at the next
	frame; cancelled, it is gone and its materials are back; built, the pantry lists it at once; two planned, Build is
	refused."""
	_build_cast()
	var stores := _stores(20, 60)
	var pantry := PantryScript.new(StorageScript.new(STORE_AT))
	var node := DemoStoresScript.new()
	_nodes.append(node)
	# The Pantry's cellar bar is the village's to parent (farm_pantry_panel.gd `add_store_control`), so freeing the
	# node alone would leave it orphaned and leaked at exit (decision 0501's gate; batch 7 integration).
	_nodes.append(node.bar)
	node.configure(_cast, _cast.space().tunnels, pantry, Callable(), func() -> int: return 0, null)
	node.configure_cellars(stores, null, STORE_AT, _site, Callable(), GraphScript.new(), null, Callable())
	assert_true(node.start_placing(), "armed")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(node.handle_input(esc), "Esc taken while armed")
	assert_false(node.handle_input(esc), "and not after")
	node.start_placing()
	node.place.move_to(Vector2(0.0, 6.0))
	assert_true(node.place.place(), "placed")
	var before: int = _cast.space().obstacles.size()
	node._process(0.0)
	assert_true(_cast.space().obstacles.has(Vector3(0.0, ProjectsScript.RADIUS_M, 6.0)), "an obstacle")
	_deliver_all(node.projects)
	assert_equal(node.cancel(0), "", "cancelled")
	assert_equal(stores.wood_milli_u + stores.stone_milli_u, 80000, "everything back")
	node._process(0.0)
	assert_equal(_cast.space().obstacles.size(), before, "no longer an obstacle")
	node.projects.plan_at(Vector2(0.0, 6.0), 0.0)
	_deliver_all(node.projects)
	node.projects.add_work(0, Rules.work_usec())
	node._process(0.0)
	assert_equal(pantry.storage.count(), 2, "the pantry lists it at once")
	assert_equal(pantry.storage.label_of(1), "Cellar 1", "as Cellar 1")
	node.projects.plan_at(Vector2(-8.0, -4.0), 0.0)
	assert_false(node.start_placing(), "two stand: refused")
	assert_equal(node.doing_text(1), "", "nobody busy")
