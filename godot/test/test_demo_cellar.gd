extends "res://test/framework/test_case.gd"
## The cool cellar (decision 0611): food stores declare their §5.8 storage class and why (farm_storage.gd STORAGE
## CLASS); the pantry moves a lot between stores keeping its age (farm_pantry.gd MOVING FOOD BETWEEN STORES); the haul
## (demo/stores/cellar_haul.gd) plans surplus food into a cooler store and a carrier moves it there through the work
## board's claim (demo/work/stores_work.gd); the Pantry says why food keeps longer where it is (farm_pantry_rows.gd).
##
## On the placeholder cast, stepped at 60 Hz, out of the tree; the stores are fixture entries on the surface (a cellar
## room's carry-below is the farm's own, tested in test_demo_rooms.gd).

const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RowsScript := preload("res://demo/farm/farm_pantry_rows.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const StoresWork := preload("res://demo/work/stores_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const CARROT: int = 2
const LETTUCE: int = 7
const WHEAT: int = 13
const TROUT: int = 16
const COVERED: int = 0
const CELLAR: int = 1
## A mouse's height in u (test_demo_night.gd's), registered with the network so a load can go below.
const MOUSE_U: int = 1024
const DT: float = 1.0 / 60.0
const USEC: int = 16667

var _cast: DemoCastScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _free: Dictionary = {}


func after_each() -> void:
	"""Free the cast a test built."""
	if _cast != null:
		_cast.free()
		_cast = null
	_free.clear()


func _entry(id: Variant, capacity_u: int, extra: Dictionary) -> Dictionary:
	"""A provider entry at (4, 0) holding `capacity_u`, with `extra`'s keys."""
	var row: Dictionary = {"id": id, "position": Vector2(4.0, 0.0), "capacity_u": capacity_u, "label": "Root cellar"}
	row.merge(extra, true)
	return row


func _pantry(cellar_u: int = 60, cellar_permille: int = 350) -> PantryScript:
	"""The covered store at (-4, 0) and one cellar at (4, 0)."""
	var storage := StorageScript.new(Vector2(-4.0, 0.0))
	storage.add_provider(func() -> Array: return [_entry(&"c", cellar_u, {"spoilage_permille": cellar_permille})])
	return PantryScript.new(storage)


func _add(pantry: PantryScript, item: int, milli: int, at: int) -> int:
	"""Store `milli` of `item` at `at`; its lot row."""
	assert_true(pantry.add_into(item, milli, at, _read), "stored %d of item %d" % [milli, item])
	return _read.value


# --- storage class (farm_storage.gd STORAGE CLASS) -----------------------------------------------

func test_a_store_takes_its_class_from_its_permille_or_its_permille_from_its_class() -> void:
	"""The permille alone names its class (750 a pantry); the class alone takes §5.8's factor (CELLAR 350); both agreeing
	are kept; a permille that is none of the four keeps its rate, UNDECLARED; the covered store is COVERED."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"p", 5, {"spoilage_permille": 750}),
		_entry(&"c", 5, {"storage_class": StockAge.STORAGE_CELLAR}),
		_entry(&"o", 5, {"storage_class": StockAge.STORAGE_OPEN_PILE, "spoilage_permille": 1500}),
		_entry(&"x", 5, {"spoilage_permille": 500})])
	assert_equal(storage.count(), 5, "every entry kept")
	assert_equal(storage.class_of(0), StockAge.STORAGE_COVERED_STORE, "the covered store")
	assert_equal(storage.class_of(1), StockAge.STORAGE_PANTRY, "750 is a pantry")
	assert_equal(storage.permille_of(2), 350, "a cellar's factor")
	assert_equal(storage.class_of(2), StockAge.STORAGE_CELLAR, "the cellar")
	assert_equal(storage.class_of(3), StockAge.STORAGE_OPEN_PILE, "a ground pile (§5.9's 1500)")
	assert_equal(storage.permille_of(4), 500, "its own rate")
	assert_equal(storage.class_of(4), StockAge.STORAGE_UNDECLARED, "none of the four")


func test_a_store_whose_class_and_permille_disagree_is_refused() -> void:
	"""A class with another class's permille, an unknown class, a class of the wrong type, and an entry with neither are
	refused and counted."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"a", 5, {"storage_class": StockAge.STORAGE_CELLAR,
		"spoilage_permille": 750}), _entry(&"b", 5, {"storage_class": 5}), _entry(&"c", 5, {"storage_class": 0}),
		_entry(&"d", 5, {"storage_class": "cellar"}), _entry(&"e", 5, {})])
	assert_equal(storage.count(), 1, "only the covered store")
	assert_equal(storage.refused_entries(), 5, "all five refused")
	assert_equal(StorageScript.class_and_permille_of({"storage_class": 4, "spoilage_permille": 350}), Vector2i(4, 350),
		"agreeing")
	assert_equal(StorageScript.class_and_permille_of({"spoilage_permille": 10001}).x, -1, "out of range")


func test_a_store_says_why_in_its_own_words_or_its_classes() -> void:
	"""`why` is the entry's own words, else its class's; the covered store says it ages food at the base rate."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"a", 5, {"storage_class": 4, "why": "cool: deep"}),
		_entry(&"b", 5, {"storage_class": 3}), _entry(&"c", 5, {"storage_class": 1, "why": ""})])
	assert_equal(storage.why_of(0), StorageScript.CLASS_WHY[StockAge.STORAGE_COVERED_STORE], "the covered store")
	assert_equal(storage.why_of(1), "cool: deep", "its own")
	assert_equal(storage.why_of(2), StorageScript.CLASS_WHY[StockAge.STORAGE_PANTRY], "the class's")
	assert_equal(storage.why_of(3), StorageScript.CLASS_WHY[StockAge.STORAGE_OPEN_PILE], "empty words: the class's")
	assert_equal(StorageScript.class_of_permille(350), StockAge.STORAGE_CELLAR, "350")
	assert_equal(StorageScript.class_of_permille(1), StockAge.STORAGE_UNDECLARED, "1")


func test_a_cellar_is_the_cellar_class_while_cool_and_a_pantry_when_warm() -> void:
	"""The cool rule's verdict names the class: COOL_YES a cellar, any warm reason a pantry (its 750)."""
	assert_equal(FarmCellars.class_of_cool(FixturesScript.COOL_YES), StockAge.STORAGE_CELLAR, "cool")
	for warm: int in [FixturesScript.COOL_SHALLOW, FixturesScript.COOL_HEARTH_NEAR, FixturesScript.COOL_HEARTH_OPENS]:
		assert_equal(FarmCellars.class_of_cool(warm), StockAge.STORAGE_PANTRY, "warm reason %d" % warm)
	assert_equal(StockAge.STORE_FACTOR[FarmCellars.class_of_cool(FixturesScript.COOL_SHALLOW)], 750, "the pantry's 750")


func test_keeps_text_is_floored_to_the_tenth() -> void:
	"""1000 over 350 is 2.857: '2.8×'; over 750 '1.3×'; the same '1.0×'; slower than the base '0.6×'."""
	assert_equal(Text.keeps_text(1000, 350), "2.8×", "a cool cellar")
	assert_equal(Text.keeps_text(1000, 750), "1.3×", "a pantry")
	assert_equal(Text.keeps_text(1000, 1000), "1.0×", "the same")
	assert_equal(Text.keeps_text(1000, 1500), "0.6×", "an open pile")
	assert_equal(Text.keeps_text(750, 350), "2.1×", "a warm cellar to a cool one")


# --- moving a lot (farm_pantry.gd MOVING FOOD BETWEEN STORES) ------------------------------------

func test_a_whole_lot_moves_with_its_age_and_the_ledger_is_untouched() -> void:
	"""Carried whole, set down in the cellar: the same row, its age kept, the item's count and the ledger unchanged, the
	hold spent; aged on, it ages at the cellar's 350."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	for h: int in 10:
		pantry.age_hour(0)
	var serial: int = pantry.lot_serial(lot)
	assert_true(pantry.reserve_at_into(CARROT, 5000, CELLAR, _read), "room held")
	var hold: int = _read.value
	assert_true(pantry.begin_carry_into(lot, serial, 5000, _read), "in hand")
	assert_equal(_read.value, lot, "the whole row")
	assert_true(pantry.lot_carried(lot), "carried")
	assert_equal(pantry.lot_location(lot), COVERED, "still booked at its store")
	assert_true(pantry.set_down_into(lot, serial, hold, _read), "set down")
	assert_equal(_read.value, 5000, "all of it")
	assert_equal(pantry.lot_location(lot), CELLAR, "in the cellar")
	assert_equal(pantry.lot_age(lot), 10000, "its age kept: 10 hours")
	assert_false(pantry.lot_carried(lot), "no longer carried")
	assert_false(pantry.is_hold(hold), "the hold spent")
	assert_equal(pantry.milli_of(CARROT), 5000, "the count")
	assert_equal(pantry.stored_total_milli(CARROT), 5000, "nothing came in")
	assert_equal(pantry.withdrawn_total_milli(CARROT), 0, "nothing went out")
	assert_equal(pantry.moved_milli, 5000, "moved")
	pantry.age_hour(0)
	assert_equal(pantry.lot_age(lot), 10350, "ages at 350 now")


func test_part_of_a_lot_is_split_exactly_and_keeps_its_age() -> void:
	"""Carrying 2.0 U of a 5.0 U lot splits it into a new row with a new serial and the same age and remainder; the rest
	stays; nothing is cloned."""
	var pantry := _pantry(60, 350)
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	pantry.age_hour(1)
	var serial: int = pantry.lot_serial(lot)
	assert_true(pantry.begin_carry_into(lot, serial, 2000, _read), "a split")
	var part: int = _read.value
	assert_true(part != lot, "a new row")
	assert_true(pantry.lot_serial(part) != serial, "a new serial")
	assert_equal(pantry.lot_milli(part) + pantry.lot_milli(lot), 5000, "exact: 2000 + 3000")
	assert_equal(pantry.lot_milli(part), 2000, "the part")
	assert_equal(pantry.lot_age(part), pantry.lot_age(lot), "the same age")
	assert_equal(pantry.lot_count(), 2, "two rows")
	assert_equal(pantry.milli_of(CARROT), 5000, "the count unchanged")
	assert_equal(pantry.carried_milli_at(CARROT, COVERED), 2000, "in hand, booked at the store")
	assert_false(pantry.lot_carried(lot), "the rest is not carried")


func test_a_carried_lot_cannot_be_withdrawn_merged_into_or_reserved_by_the_kitchen() -> void:
	"""Withdrawing from a carried lot is refused; the kitchen counts none of it free; a delivery into a full lot table
	never merges into it; a second carry of it is refused."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 3000, COVERED)
	var serial: int = pantry.lot_serial(lot)
	var takes := TakesScript.new()
	assert_equal(takes.free_milli(pantry, lot), 3000, "free before")
	pantry.begin_carry_into(lot, serial, 3000, _read)
	assert_false(pantry.withdraw_into(lot, serial, 1000, _read), "refused")
	assert_equal(_read.error, PantryScript.REFUSE_IN_HAND, "in hand")
	assert_equal(takes.free_milli(pantry, lot), 0, "the kitchen counts none of it")
	assert_equal(takes.free_milli_of_crop(pantry, Catalog.category_of(CARROT)), 0, "nor in its crop row's sum")
	assert_false(pantry.begin_carry_into(lot, serial, 1000, _read), "not carried twice")
	for k: int in PantryScript.MAX_LOTS - 1:
		_add(pantry, WHEAT, 10, COVERED)
	assert_false(pantry.add_into(CARROT, 1000, COVERED, _read), "a full table: no carrot lot to merge into but the carried")
	assert_equal(pantry.lot_milli(lot), 3000, "the carried lot untouched")


func test_only_what_fits_is_set_down_and_the_rest_goes_back() -> void:
	"""The cellar shrank to 2 U under a 3 U carry: 2.0 U is set down (a split, its age kept), 1.0 U stays in hand and is
	put back in its own store; nothing lost."""
	var capacity: Array[int] = [10]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"c", capacity[0], {"storage_class": 4})])
	var pantry := PantryScript.new(storage)
	var lot: int = _add(pantry, CARROT, 3000, COVERED)
	var serial: int = pantry.lot_serial(lot)
	pantry.reserve_at_into(CARROT, 3000, CELLAR, _read)
	var hold: int = _read.value
	pantry.begin_carry_into(lot, serial, 3000, _read)
	capacity[0] = 2
	pantry.refresh_locations()
	assert_true(pantry.set_down_into(lot, serial, hold, _read), "set down")
	assert_equal(_read.value, 2000, "what fits")
	assert_equal(pantry.milli_at(CARROT, CELLAR), 2000, "in the cellar")
	assert_true(pantry.lot_carried(lot), "the rest still in hand")
	assert_true(pantry.put_back(lot, serial), "put back")
	assert_equal(pantry.milli_at(CARROT, COVERED), 1000, "back in its store")
	assert_equal(pantry.milli_of(CARROT), 3000, "nothing lost")
	assert_false(pantry.put_back(lot, serial), "not carried any more")


func test_set_down_refuses_a_stale_lot_and_a_gone_store() -> void:
	"""A lot not carried, a stale serial, and a hold whose store has gone are refused; the load can still be put back."""
	var present: Array[bool] = [true]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"c", 10, {"storage_class": 4})] if present[0] else [])
	var pantry := PantryScript.new(storage)
	var lot: int = _add(pantry, CARROT, 1000, COVERED)
	var serial: int = pantry.lot_serial(lot)
	pantry.reserve_at_into(CARROT, 1000, CELLAR, _read)
	var hold: int = _read.value
	assert_false(pantry.set_down_into(lot, serial, hold, _read), "not carried")
	pantry.begin_carry_into(lot, serial, 1000, _read)
	assert_false(pantry.set_down_into(lot, serial + 1, hold, _read), "a stale serial")
	present[0] = false
	pantry.refresh_locations()
	assert_false(pantry.set_down_into(lot, serial, hold, _read), "the cellar has gone")
	assert_equal(_read.error, PantryScript.REFUSE_GONE, "said so")
	assert_true(pantry.put_back(lot, serial), "put back")
	assert_equal(pantry.milli_at(CARROT, COVERED), 1000, "in its store")


func test_reserve_at_refuses_without_room_and_a_carried_lot_that_spoils_frees_its_row() -> void:
	"""A hold for more than the room is refused; a carried lot reaching its shelf life spoils like any other, and its
	serial no longer answers."""
	var pantry := _pantry(2, 350)
	assert_false(pantry.reserve_at_into(CARROT, 3000, CELLAR, _read), "2 U of room")
	assert_equal(_read.error, PantryScript.REFUSE_NO_ROOM, "no room")
	assert_false(pantry.reserve_at_into(CARROT, 0, CELLAR, _read), "nothing")
	var lot: int = _add(pantry, TROUT, 1000, COVERED)
	var serial: int = pantry.lot_serial(lot)
	pantry.begin_carry_into(lot, serial, 1000, _read)
	for h: int in 48:
		pantry.age_hour(0)
	assert_false(pantry.is_lot(lot, serial), "spoiled")
	assert_false(pantry.lot_carried(lot), "not carried")
	assert_equal(pantry.spoiled_milli, 1000, "spoiled food")


# --- the planner (cellar_haul.gd WHAT MOVES) ------------------------------------------------------

func _haul(pantry: PantryScript, hour: int = 0) -> HaulScript:
	"""A haul over `pantry` on the placeholder cast, the kitchen's free food `_free` (lot -> milli; missing: all)."""
	_cast = DemoCastScript.new()
	_cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	_cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	for i: int in _cast.actor_count():
		(_cast.actor(i) as DemoActorScript).brain.set_carry_motion(_carry_motion())
	var haul := HaulScript.new()
	var free: Dictionary = _free
	haul.configure(_cast, _cast.space().tunnels, pantry,
		func(lot: int) -> int: return int(free.get(lot, pantry.lot_milli(lot))), func() -> int: return hour)
	return haul


func _carry_motion() -> Dictionary:
	"""A straight carry root motion, 0.2 m/s over 6.5 s (test_demo_spoil.gd's)."""
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 1.3 * k / 65.0])
	return {"keys_xz": keys, "mean_speed_m_s": 0.2, "period_s": 6.5}


func test_the_food_that_spoils_soonest_moves_first_to_the_coolest_store() -> void:
	"""Carrot (240 h left) and lettuce (144 h) in the covered store: the lettuce is planned first, to the cellar; then the
	carrot; wheat already in the cellar stays."""
	var pantry := _pantry()
	var carrot: int = _add(pantry, CARROT, 5000, COVERED)
	var lettuce: int = _add(pantry, LETTUCE, 4000, COVERED)
	_add(pantry, WHEAT, 4000, CELLAR)
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 2, "two moves")
	assert_equal(haul.lot[0], lettuce, "the lettuce first")
	assert_equal(haul.lot[1], carrot, "then the carrot")
	assert_equal(haul.destination_of(0), CELLAR, "to the cellar")
	assert_equal(haul.milli[0], 4000, "all of it")
	assert_equal(haul.plan(), 0, "nothing more: the wheat is in the coolest store already")
	assert_equal(haul.live_count(), 2, "two stand")


func test_food_about_to_spoil_stays_put() -> void:
	"""MIN_HOURS_LEFT: lettuce with 5 hours left where it is is not moved; with 6 it is."""
	var pantry := _pantry()
	var lettuce: int = _add(pantry, LETTUCE, 1000, COVERED)
	for h: int in 144 - HaulScript.MIN_HOURS_LEFT + 1:
		pantry.age_hour(0)
	assert_equal(pantry.lot_spoil_hours(lettuce, 0), HaulScript.MIN_HOURS_LEFT - 1, "5 hours left")
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 0, "too soon to be worth the walk")
	var fresh := _pantry()
	var other: int = _add(fresh, LETTUCE, 1000, COVERED)
	for h: int in 144 - HaulScript.MIN_HOURS_LEFT:
		fresh.age_hour(0)
	assert_equal(fresh.lot_spoil_hours(other, 0), HaulScript.MIN_HOURS_LEFT, "6 hours left")
	_cast.free()
	assert_equal(_haul(fresh).plan(), 1, "moved")


func test_reserved_food_stays_and_only_the_surplus_moves() -> void:
	"""The kitchen holds 3.0 U of a 5.0 U lot: the move plans 2.0 U; a lot it holds whole is not moved."""
	var pantry := _pantry()
	var carrot: int = _add(pantry, CARROT, 5000, COVERED)
	var wheat: int = _add(pantry, WHEAT, 2000, COVERED)
	_free[carrot] = 2000
	_free[wheat] = 0
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 1, "one move")
	assert_equal(haul.lot[0], carrot, "the carrot")
	assert_equal(haul.milli[0], 2000, "its surplus")


func test_a_move_is_at_most_one_small_carry_and_the_room_there() -> void:
	"""LOAD_MILLI is §5.2's 12000 g of 250 g raw food: 48 U; a 60 U lot plans 48 U; a 10 U cellar plans 10 U."""
	assert_equal(HaulScript.LOAD_MILLI, 48000, "48 U")
	var pantry := _pantry(100, 350)
	_add(pantry, CARROT, 60000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	assert_equal(haul.milli[0], 48000, "one carry")
	var small := _pantry(10, 350)
	_add(small, CARROT, 60000, COVERED)
	_cast.free()
	var other := _haul(small)
	assert_equal(other.plan(), 1, "one move fills it")
	assert_equal(other.milli[0], 10000, "the room there")


func test_nothing_moves_to_a_store_that_is_not_cooler_or_has_no_room() -> void:
	"""Food in a cellar no cooler than the covered store, or a full cellar, plans nothing; a warm cellar's food moves to a
	cool one."""
	var same := _pantry(60, 1000)
	_add(same, CARROT, 1000, COVERED)
	assert_equal(_haul(same).plan(), 0, "the same rate")
	_cast.free()
	var full := _pantry(1, 350)
	_add(full, CARROT, 1000, CELLAR)
	_add(full, CARROT, 1000, COVERED)
	assert_equal(_haul(full).plan(), 0, "no room")
	_cast.free()
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"warm", 10, {"storage_class": 3}),
		_entry(&"cool", 10, {"storage_class": 4})])
	var two := PantryScript.new(storage)
	_add(two, CARROT, 1000, 1)
	var haul := _haul(two)
	assert_equal(haul.plan(), 1, "the warm cellar's carrot")
	assert_equal(haul.destination_of(0), 2, "to the cool one")


func test_of_two_cool_stores_the_nearer_one_is_chosen() -> void:
	"""Two cellars at 350: the one nearer the lot's store (the covered store at -4, 0) takes it."""
	var storage := StorageScript.new(Vector2(-4.0, 0.0))
	var far: Dictionary = _entry(&"far", 10, {"storage_class": 4})
	var near: Dictionary = _entry(&"near", 10, {"storage_class": 4})
	near["position"] = Vector2(-2.0, 0.0)
	storage.add_provider(func() -> Array: return [far, near])
	var pantry := PantryScript.new(storage)
	_add(pantry, CARROT, 1000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	assert_equal(haul.destination_of(0), 2, "the nearer")


func test_waiting_moves_count_against_the_room_they_will_take() -> void:
	"""A 5 U cellar and two 4 U lots: the first move plans 4 U, the second only the 1 U left."""
	var pantry := _pantry(5, 350)
	_add(pantry, LETTUCE, 4000, COVERED)
	_add(pantry, CARROT, 4000, COVERED)
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 2, "two moves")
	assert_equal(haul.milli[0] + haul.milli[1], 5000, "no more than the room")


# --- carrying it (cellar_haul.gd WHO MOVES IT) ------------------------------------------------------

func _brain(i: int) -> BrainScript:
	"""Actor i's brain."""
	return (_cast.actor(i) as DemoActorScript).brain


func _run(haul: HaulScript, seconds: float, each: Callable = Callable()) -> void:
	"""Step every brain and the haul for `seconds` of demo time."""
	for f: int in roundi(seconds / DT):
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		haul.update(USEC)
		if each.is_valid():
			each.call()


func test_a_claimed_move_carries_the_food_into_the_cellar_with_its_age() -> void:
	"""Claimed by resident 1: room held at the cellar (Incoming there), the carrier walks to the covered store, picks the
	lot up, carries it to the cellar and shelves it -- the count never changing, the lot in the cellar with its age, the
	carrier back to its routine."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	assert_true(haul.waiting(0), "waits for a carrier")
	assert_equal(haul.task_text(1), "", "nothing yet")
	assert_true(haul.claim(0, 1), "claimed")
	assert_equal(haul.task_text(1), "Fetching carrot from the covered store", "its words")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 5000, "incoming at the cellar")
	var steady: Array[bool] = [true]
	_run(haul, 120.0, func() -> void: steady[0] = steady[0] and pantry.milli_of(CARROT) == 5000)
	assert_true(steady[0], "the count never changed")
	assert_equal(haul.moves_done, 1, "moved")
	assert_equal(pantry.milli_at(CARROT, CELLAR), 5000, "in the cellar")
	assert_equal(pantry.lot_location(lot), CELLAR, "the same lot")
	assert_true(pantry.lot_age(lot) == 0, "its age kept (no hour passed)")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 0, "nothing incoming")
	assert_false(haul.is_live(0), "the move closed")
	assert_equal(_brain(1).order, BrainScript.ORDER_NONE, "back to its routine")


func test_a_carrier_called_away_puts_the_food_back_and_the_move_waits_again() -> void:
	"""Ordered elsewhere with the food in hand: it is in its store again (never credited from afar), the room freed, and
	the move waits for a carrier from the start."""
	var pantry := _pantry()
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.claim(0, 1)
	for f: int in 12000:
		if haul.is_carrying(0) and haul.issued[0] == 1:
			break
		_run(haul, DT)
	assert_true(haul.is_carrying(0), "in hand")
	assert_equal(haul.task_text(1), "Carrying carrot to the root cellar", "its words on the way")
	assert_equal(pantry.carried_milli_at(CARROT, COVERED), 5000, "booked at the store, in hand")
	_brain(1).order_move(Vector2(-8.0, -8.0))
	haul.update(USEC)
	assert_false(haul.is_carrying(0), "put back")
	assert_equal(pantry.carried_milli_at(CARROT, COVERED), 0, "nobody has it")
	assert_equal(pantry.milli_at(CARROT, COVERED), 5000, "in its store")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 0, "the room freed")
	assert_true(haul.waiting(0), "waits again")
	assert_equal(haul.worker[0], HaulScript.NOBODY, "no carrier")


func test_commands_refuse_a_load_in_hand_and_carriers_need_a_carry_walk() -> void:
	"""Pause, cancel and reassign are refused while the food is in hand; before that, pause lets the carrier go and
	cancel closes the move; one who cannot carry is refused in words; one move each."""
	var pantry := _pantry()
	_add(pantry, CARROT, 5000, COVERED)
	_add(pantry, LETTUCE, 1000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	_brain(0)._carry_velocity.clear()
	assert_equal(haul.eligibility(0, 0), HaulScript.CANT_CARRY, "no carry walk")
	assert_false(haul.claim(0, 0), "not claimed")
	assert_true(haul.claim(0, 1), "claimed by 1")
	assert_equal(haul.eligibility(1, 1), HaulScript.OTHER_MOVE, "one move each")
	assert_equal(haul.eligibility(0, 1), "", "its own move")
	assert_equal(haul.pause(0, true), "", "paused before pick-up")
	assert_false(haul.waiting(0), "a paused move is not claimed")
	assert_equal(haul.worker[0], HaulScript.NOBODY, "let go")
	assert_equal(haul.pause(0, false), "", "resumed")
	haul.claim(0, 1)
	for f: int in 12000:
		if haul.is_carrying(0):
			break
		_run(haul, DT)
	assert_equal(haul.cancel(0), HaulScript.IN_HAND_WORDS, "cancel refused")
	assert_equal(haul.pause(0, true), HaulScript.IN_HAND_WORDS, "pause refused")
	assert_equal(haul.reassign(0, 2), HaulScript.IN_HAND_WORDS, "reassign refused")
	assert_equal(haul.cancel(1), "", "the other move cancelled")
	assert_false(haul.is_live(1), "closed")
	assert_equal(haul.cancel(1), HaulScript.GONE_WORDS, "gone")


func test_a_claim_whose_room_has_gone_closes_the_move() -> void:
	"""The cellar filled before the move was claimed: the claim refuses and closes it."""
	var pantry := _pantry(5, 350)
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	_add(pantry, WHEAT, 5000, CELLAR)
	assert_false(haul.claim(0, 1), "no room")
	assert_false(haul.is_live(0), "closed")


func test_food_that_spoils_or_is_eaten_on_the_way_ends_the_move() -> void:
	"""The planned lot eaten before pick-up: the move ends and its carrier goes back to its routine."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 1000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.claim(0, 1)
	haul.update(USEC)
	assert_equal(haul.issued[0], 1, "on its way")
	pantry.withdraw_into(lot, pantry.lot_serial(lot), 1000, _read)
	haul.update(USEC)
	assert_false(haul.is_live(0), "ended at once, not at the store")
	assert_equal(_brain(1).order, BrainScript.ORDER_NONE, "the carrier let go")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 0, "its room freed")


func _until(haul: HaulScript, check: Callable, seconds: float = 120.0) -> bool:
	"""Step the brains and the haul until `check()` holds, at most `seconds`; whether it did."""
	for f: int in roundi(seconds / DT):
		if bool(check.call()):
			return true
		_run(haul, DT)
	return bool(check.call())


func test_a_part_too_small_or_a_split_with_every_lot_row_taken_is_not_planned() -> void:
	"""With all 128 lot rows taken, a 60 U lot (more than one 48 U carry) is not planned -- its split would be refused
	(the review's H1) -- while a whole 2 U lot still is; a part under MIN_PART_MILLI never is."""
	var pantry := _pantry(200, 350)
	var big: int = _add(pantry, CARROT, 60000, COVERED)
	for k: int in PantryScript.MAX_LOTS - 2:
		_add(pantry, WHEAT, 10, CELLAR)
	var small: int = _add(pantry, LETTUCE, 2000, COVERED)
	assert_equal(pantry.lot_count(), PantryScript.MAX_LOTS, "every row taken")
	assert_equal(HaulScript.part_of(pantry, big, 48000, 200000), 0, "no split to be had")
	assert_equal(HaulScript.part_of(pantry, small, 48000, 200000), 2000, "the whole lot")
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 1, "only the whole lot")
	assert_equal(haul.lot[0], small, "the lettuce")
	var roomy := _pantry()
	var lot: int = _add(roomy, CARROT, 5000, COVERED)
	assert_equal(HaulScript.part_of(roomy, lot, 999, 60000), 0, "a part under one unit")
	assert_equal(HaulScript.part_of(roomy, lot, 1000, 60000), 1000, "one unit")
	assert_equal(HaulScript.part_of(roomy, lot, 9000, 60000), 5000, "never more than the lot")
	assert_equal(HaulScript.part_of(roomy, lot, 9000, 0), 0, "no room")


func test_a_pick_up_the_pantry_refuses_gives_up_and_backs_off_its_store() -> void:
	"""A 3 U part of a 5 U lot is claimed; every lot row is taken before the pick-up, so the split is refused: the move
	gives up (its room freed, the carrier let go) and the store is left alone, not claimed again and again."""
	var pantry := _pantry(3, 350)
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	assert_equal(haul.milli[0], 3000, "a part: the cellar's room")
	assert_true(haul.claim(0, 1), "claimed")
	for k: int in PantryScript.MAX_LOTS - 1:
		_add(pantry, WHEAT, 10, COVERED)
	assert_true(_until(haul, func() -> bool: return not haul.is_live(0)), "the move ended")
	assert_equal(haul.moves_done, 0, "nothing moved")
	assert_equal(pantry.lot_milli(lot), 5000, "the lot whole")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 0, "its room freed")
	assert_equal(_brain(1).order, BrainScript.ORDER_NONE, "the carrier let go")
	assert_equal(haul.plan(), 0, "the store is backed off")
	haul.update(HaulScript.BACKOFF_USEC)
	assert_false(haul.lot.has(lot), "lapsed, the carrot is still not planned: its split is still impossible")
	assert_true(haul.live_count() > 0, "the whole small lots are")


func test_a_store_nobody_can_reach_gives_up_after_its_walks_and_backs_off() -> void:
	"""The covered store stands off the village: no spot by it can be stood on, so the move gives up at once and the
	store is backed off for BACKOFF_USEC; after it, the move is planned again."""
	var storage := StorageScript.new(Vector2(60.0, 0.0))
	storage.add_provider(func() -> Array: return [_entry(&"c", 60, {"storage_class": 4})])
	var pantry := PantryScript.new(storage)
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.claim(0, 1)
	haul.update(USEC)
	assert_false(haul.is_live(0), "given up")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 0, "its room freed")
	assert_equal(haul.plan(), 0, "backed off")
	haul.update(HaulScript.BACKOFF_USEC - USEC)
	assert_equal(haul.live_count(), 0, "a microsecond before it lapses")
	haul.update(HaulScript.PLAN_USEC)
	assert_equal(haul.live_count(), 1, "planned again once it lapsed")


func test_food_the_kitchen_reserves_before_the_pick_up_stays_and_is_cooked_exactly() -> void:
	"""The kitchen reserves 3.0 U of a 5.0 U lot after the move was claimed: only the 2.0 U surplus is carried, and the
	kitchen's batch then withdraws exactly its 3.0 U (the review's H2)."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var takes := TakesScript.new()
	var haul := _haul(pantry)
	haul.configure(_cast, _cast.space().tunnels, pantry, func(at: int) -> int: return takes.free_milli(pantry, at),
		func() -> int: return 0)
	haul.plan()
	assert_true(haul.claim(0, 1), "claimed for all 5.0 U")
	var take: int = takes.new_take()
	assert_equal(takes.reserve_lot(pantry, take, lot, 3000), 3000, "the kitchen reserves 3.0 U")
	assert_true(_until(haul, func() -> bool: return haul.is_carrying(0)), "picked up")
	assert_equal(pantry.carried_milli_at(CARROT, COVERED), 2000, "only the surplus in hand")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 2000, "the room held shrinks to it")
	assert_true(takes.consume_into(pantry, take, 3000, TakesScript.AT_STORE, 0, _read), "the batch takes its food")
	assert_equal(pantry.milli_of(CARROT), 2000, "exactly 3.0 U withdrawn")
	assert_equal(pantry.withdrawn_total_milli(CARROT), 3000, "on the ledger")


func test_the_kitchen_never_counts_food_on_a_carried_row_as_cooked() -> void:
	"""A reservation sitting on a row that is carried (a carry taking reserved food, which the haul never does) is
	trimmed to nothing: the batch is refused short and nothing is withdrawn or counted."""
	var pantry := _pantry()
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var takes := TakesScript.new()
	var take: int = takes.new_take()
	takes.reserve_lot(pantry, take, lot, 3000)
	assert_true(pantry.begin_carry_into(lot, pantry.lot_serial(lot), 5000, _read), "the whole row in hand")
	assert_false(takes.consume_into(pantry, take, 3000, TakesScript.AT_STORE, 0, _read), "refused")
	assert_equal(_read.error, TakesScript.REFUSE_SHORT, "short")
	assert_equal(pantry.milli_of(CARROT), 5000, "nothing withdrawn")
	assert_equal(takes.live_milli(pantry, take), 0, "nothing still reserved on the carried row")


func test_a_carrier_that_holds_away_from_its_spot_has_not_arrived() -> void:
	"""A walk that ended holding 5 m from its spot is a failed try, never an arrival (decision 0361); a carrier found off
	its spot at the pick-up goes back to the walk, nothing picked up."""
	var pantry := _pantry()
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.claim(0, 1)
	haul.update(USEC)
	assert_equal(haul.issued[0], 1, "the walk issued")
	var brain := _brain(1)
	brain.state = BrainScript.State.HOLD
	brain.position = haul.goal[0] + Vector2(5.0, 0.0)
	haul.update(USEC)
	assert_equal(haul.step[0], HaulScript.STEP_GO, "not arrived")
	assert_equal(haul.tries[0], 1, "a failed try")
	assert_true(_until(haul, func() -> bool: return haul.step[0] == HaulScript.STEP_PICK), "arrived for real")
	brain.position = haul.goal[0] + Vector2(5.0, 0.0)
	haul.update(USEC)
	assert_equal(haul.step[0], HaulScript.STEP_GO, "back to the walk")
	assert_false(haul.is_carrying(0), "nothing picked up")


func test_a_destination_no_longer_cooler_closes_the_move() -> void:
	"""Planned warm (750) to cool (350); a hearth swaps them before the claim: the claim refuses and closes the move
	(the review's M1)."""
	var cool: Array[int] = [4, 3]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"a", 10, {"storage_class": cool[1]}),
		_entry(&"b", 10, {"storage_class": cool[0]})])
	var pantry := PantryScript.new(storage)
	_add(pantry, CARROT, 2000, 1)
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 1, "planned")
	assert_equal(haul.destination_of(0), 2, "to the cool one")
	cool[0] = 3
	cool[1] = 4
	pantry.refresh_locations()
	assert_false(haul.claim(0, 1), "refused")
	assert_false(haul.is_live(0), "closed")
	cool[0] = 4
	cool[1] = 3
	pantry.refresh_locations()
	assert_equal(haul.plan(), 1, "planned again")
	cool[1] = 4
	pantry.refresh_locations()
	assert_false(haul.claim(0, 1), "equally cool is not cooler")


func test_a_waiting_move_whose_food_has_gone_is_closed_and_frees_its_room() -> void:
	"""A paused move's lot is eaten: the next plan closes it, and the room it would have taken goes to the next lot (the
	review's M2)."""
	var pantry := _pantry(5, 350)
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.pause(0, true)
	pantry.withdraw_into(lot, pantry.lot_serial(lot), 5000, _read)
	var lettuce: int = _add(pantry, LETTUCE, 3000, COVERED)
	assert_equal(haul.plan(), 1, "the lettuce planned")
	assert_false(haul.lot.has(lot) and haul.lot_serial[haul.lot.find(lot)] != pantry.lot_serial(lettuce), "the old move closed")
	assert_equal(haul.live_count(), 1, "one move")
	assert_equal(haul.item[haul.lot.find(lettuce)], LETTUCE, "the lettuce's")


func test_a_claim_takes_only_the_room_left() -> void:
	"""Planned for 5.0 U; 2.0 U of the cellar is filled before the claim: the claim holds 3.0 U."""
	var pantry := _pantry(5, 350)
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	_add(pantry, WHEAT, 2000, CELLAR)
	assert_true(haul.claim(0, 1), "claimed")
	assert_equal(haul.milli[0], 3000, "the room left")
	assert_equal(pantry.incoming_milli(CARROT, CELLAR), 3000, "held")


func test_a_split_keeps_the_remainder_of_its_age() -> void:
	"""A lot in a store aging at 333 per mille through a summer hour carries a 500 milli-hour remainder; its split ages
	exactly as the rest of it does next hour."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"odd", 10, {"spoilage_permille": 333})])
	var pantry := PantryScript.new(storage)
	var lot: int = _add(pantry, CARROT, 4000, 1)
	pantry.age_hour(1)
	assert_equal(pantry.lot_age(lot), 499, "333 x 1500: 499 and 500 kept")
	pantry.begin_carry_into(lot, pantry.lot_serial(lot), 1000, _read)
	var part: int = _read.value
	pantry.age_hour(1)
	assert_equal(pantry.lot_age(lot), 999, "499 + 500 + 500 carried over")
	assert_equal(pantry.lot_age(part), pantry.lot_age(lot), "the split kept the remainder")


func test_the_coolest_store_with_room_is_chosen_past_a_full_or_warmer_one() -> void:
	"""From the covered store: a pantry (750) and two cool cellars (350), the nearer full -- the farther cool cellar
	takes it."""
	var storage := StorageScript.new(Vector2(-4.0, 0.0))
	var near: Dictionary = _entry(&"near", 1, {"storage_class": 4})
	near["position"] = Vector2(-3.0, 0.0)
	storage.add_provider(func() -> Array: return [_entry(&"pantry", 10, {"storage_class": 3}), near,
		_entry(&"far", 10, {"storage_class": 4})])
	var pantry := PantryScript.new(storage)
	_add(pantry, WHEAT, 1000, 2)
	_add(pantry, CARROT, 2000, COVERED)
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 1, "one move")
	assert_equal(haul.destination_of(0), 3, "the farther cool cellar, not the full one or the pantry")


func test_a_move_planned_earlier_still_counts_against_the_room() -> void:
	"""A 5 U cellar: a 4 U move waits from an earlier plan; a later plan gives the next lot only the 1 U left."""
	var pantry := _pantry(5, 350)
	_add(pantry, CARROT, 4000, COVERED)
	var haul := _haul(pantry)
	assert_equal(haul.plan(), 1, "the carrot")
	_add(pantry, LETTUCE, 3000, COVERED)
	assert_equal(haul.plan(), 1, "the lettuce")
	assert_equal(haul.milli[1], 1000, "only the room left")


func test_a_shelving_with_no_room_gives_up_and_backs_off_the_cellar() -> void:
	"""The cellar shrinks to 1 U under a 3 U carry and every lot row is taken: no part can be set down, so the move
	gives up, the food goes back, and the cellar is left alone as a destination for BACKOFF_USEC."""
	var capacity: Array[int] = [3]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"c", capacity[0], {"storage_class": 4})])
	var pantry := PantryScript.new(storage)
	var lot: int = _add(pantry, CARROT, 3000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	haul.claim(0, 1)
	assert_true(_until(haul, func() -> bool: return haul.is_carrying(0)), "in hand")
	for k: int in PantryScript.MAX_LOTS - 1:
		_add(pantry, LETTUCE, 10, COVERED)
	capacity[0] = 1
	pantry.refresh_locations()
	assert_true(_until(haul, func() -> bool: return not haul.is_live(0)), "ended")
	assert_equal(haul.moves_done, 0, "nothing shelved")
	assert_equal(pantry.milli_at(CARROT, COVERED), 3000, "back in its store")
	assert_false(pantry.lot_carried(lot), "not in hand")
	capacity[0] = 60
	pantry.refresh_locations()
	assert_equal(haul.plan(), 0, "the cellar is backed off")
	haul.update(HaulScript.BACKOFF_USEC)
	assert_true(haul.live_count() > 0, "lapsed: moves planned to it again")


func test_set_down_with_no_room_moves_nothing_and_makes_no_row() -> void:
	"""The cellar shrank under its own hold to leave no room at all: nothing is set down, no row is made, the lot is
	still whole in hand."""
	var capacity: Array[int] = [2]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"c", capacity[0], {"storage_class": 4})])
	var pantry := PantryScript.new(storage)
	_add(pantry, WHEAT, 1000, CELLAR)
	var lot: int = _add(pantry, CARROT, 3000, COVERED)
	pantry.reserve_at_into(CARROT, 1000, CELLAR, _read)
	var hold: int = _read.value
	pantry.begin_carry_into(lot, pantry.lot_serial(lot), 3000, _read)
	capacity[0] = 1
	pantry.refresh_locations()
	var rows: int = pantry.lot_count()
	assert_true(pantry.set_down_into(lot, pantry.lot_serial(lot), hold, _read), "answered")
	assert_equal(_read.value, 0, "nothing")
	assert_equal(pantry.lot_count(), rows, "no row made")
	assert_equal(pantry.lot_milli(lot), 3000, "whole, in hand")
	assert_equal(pantry.milli_of(CARROT), 3000, "nothing lost")


func _dig_cellar(network: GraphScript, at_u: Vector2i) -> int:
	"""A root cellar room dug open at `at_u` and racked out (test_demo_integration.gd's helpers); its room row."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(network.add_room(RoomsScript.TEMPLATE_CELLAR, at_u, 0, 0, ref), "a cellar laid")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot: int in chain:
		if not network.is_open(slot):
			network.start_dig(slot, network.generation[slot], 0)
			network.advance(slot, network.generation[slot], 3600 * Rules.USEC_PER_SECOND)
	for f: int in RoomsScript.fixture_count(RoomsScript.TEMPLATE_CELLAR):
		network.fit.phase_of(network, ref[0], f)
		network.fit.phase[ref[0] * RoomsScript.MAX_PLACES + f] = 2
	network.fit.revision += 1
	return ref[0]


func test_a_dug_racked_cellar_is_the_cellar_class_and_its_harvest_is_carried_down_into_it() -> void:
	"""A real root cellar (decisions 0209, 0210) through farm_cellars.gd: the CELLAR class, the cool rule's words; the
	covered store's carrots are moved into it by the haul -- down its hatch when the carrier can take a load below, else
	at the hatch -- with their age, nothing lost."""
	var pantry := _pantry()
	var haul := _haul(pantry)
	var network: GraphScript = _cast.space().tunnels
	var storage := StorageScript.new(Vector2(-4.0, 0.0))
	var r: int = _dig_cellar(network, Vector2i(6144, 6144))
	network.set_body(1, MOUSE_U, 256)
	assert_true(_brain(1).can_haul_below(network.rooms.middle[r]), "a mouse can take a load down")
	storage.add_provider(FarmCellars.provider(network))
	var real := PantryScript.new(storage)
	haul.configure(_cast, network, real, Callable(), func() -> int: return 0)
	assert_equal(storage.count(), 2, "the cellar is a store")
	assert_equal(storage.class_of(1), StockAge.STORAGE_CELLAR, "cool: the cellar class")
	assert_equal(storage.why_of(1), FixturesScript.COOL_WORDS[FixturesScript.COOL_YES], "the cool rule's words")
	var lot: int = _add(real, CARROT, 5000, COVERED)
	real.age_hour(0)
	assert_equal(haul.plan(), 1, "planned")
	assert_true(haul.claim(0, 1), "claimed")
	var steady: Array[bool] = [true, false]
	_run(haul, 180.0, func() -> void:
		steady[0] = steady[0] and real.milli_of(CARROT) == 5000
		steady[1] = steady[1] or (haul.is_live(0) and haul.below[0] == 1 and _brain(1).underground))
	assert_true(steady[0], "nothing lost on the way")
	assert_true(steady[1], "carried down into the cellar")
	assert_equal(real.lot_location(lot), 1, "in the cellar")
	assert_equal(real.lot_age(lot), 1000, "its hour of age kept")
	assert_equal(haul.moves_done, 1, "one move")


# --- the board and the Pantry ------------------------------------------------------------------------

func test_the_work_board_lists_a_move_as_hauling_in_words() -> void:
	"""The stores source: HAULING, waiting, its words saying what goes where and how much longer it keeps; claimed
	through the source."""
	var pantry := _pantry()
	_add(pantry, CARROT, 5000, COVERED)
	var haul := _haul(pantry)
	haul.plan()
	var brains: Array[BrainScript] = []
	for i: int in _cast.actor_count():
		brains.append(_brain(i))
	var source := StoresWork.new(haul, pantry, brains)
	assert_equal(source.id, WorkIds.SOURCE_STORES, "its id")
	assert_equal(WorkIds.SOURCE_NAMES[WorkIds.SOURCE_STORES], "Food stores", "named")
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a walk past every source")
	assert_true(source.live(0) and source.waiting(0), "waiting")
	var task := TaskScript.new()
	source.fill(task, 0)
	assert_equal(task.action, StoresWork.ACTION, "the verb")
	assert_equal(task.target, "5 bunches of carrots: Covered store → Root cellar (keeps 2.8× as long)", "the words")
	assert_equal(task.activity, WorkIds.ACT_HAUL, "hauling")
	assert_equal(task.state, WorkIds.STATE_QUEUED, "queued")
	assert_equal(source.point(0), Vector2(-4.0, 0.0), "at the covered store")
	assert_true(source.claim(0, 2), "claimed through the source")
	assert_equal(source.worker(0), 2, "by 2")
	assert_true(_until(haul, func() -> bool: return haul.is_carrying(0)), "in hand")
	source.fill(task, 0)
	assert_true(task.carrying, "carrying")
	assert_equal(task.state, WorkIds.STATE_HAULING, "hauling")
	assert_equal(task.cancel_refusal, HaulScript.IN_HAND_WORDS, "cancel refused in words")
	assert_equal(task.pause_refusal, HaulScript.IN_HAND_WORDS, "pause refused in words")
	assert_equal(task.reassign_refusal, HaulScript.IN_HAND_WORDS, "reassign refused in words")
	assert_equal(source.point(0), Vector2(4.0, 0.0), "at the cellar now")


func test_the_pantry_says_why_and_what_is_being_moved() -> void:
	"""`why_text` heads the reasons and gives each store's words and how many times as long food keeps; a row with food
	in hand says so."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_entry(&"c", 60, {"storage_class": 4,
		"why": "cool: deep, racked and away from any hearth"})])
	var pantry := PantryScript.new(storage)
	assert_equal(RowsScript.why_text(pantry), "\n".join(PackedStringArray([RowsScript.WHY_HEADING,
		"Covered store — under cover: food ages at the base rate",
		"Root cellar — cool: deep, racked and away from any hearth: food keeps 2.8× as long as in the covered store"])),
		"the reasons")
	var lot: int = _add(pantry, CARROT, 5000, COVERED)
	var rows := RowsScript.new()
	rows.rebuild(pantry, 0)
	assert_equal(rows.moving_text(pantry, 0), "", "nothing moving")
	pantry.begin_carry_into(lot, pantry.lot_serial(lot), 2000, _read)
	rows.update(pantry, 0)
	assert_equal(rows.moving_text(pantry, 0), "2.0 U being moved to a cooler store", "in hand")
