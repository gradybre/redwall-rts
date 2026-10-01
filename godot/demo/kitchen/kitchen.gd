extends RefCounted
## THE KITCHEN: the village's first meal loop -- a harvest becomes breakfast and supper. Decision 0381 (review F21,
## UX-027, and the minimal ECO-029 and SOC-007; Brendan's rulings of 2026-09-30). Presentation only: the settlement
## simulation is never written. Pure logic -- no nodes -- so the suite drives it without a scene; demo_kitchen.gd
## runs it each frame and draws it (kitchen_view.gd).
##
## THE MEALS (meal_rules.gd). The kitchen PLANS the next MAX_SLOTS meals not yet cooked (`_plan`): each a dish (THE
## CHOICE), enough batches for every resident less the portions left from earlier meals, and its food RESERVED in the
## pantry's real lots (ingredient_takes.gd: reserve, consume, return; decision 0222's holds) -- every input of the dish,
## no more of any than whole batches of all make. Food arriving later tops a short meal up.
##
## THE CHOICE (decision 0601; it generalises ruling 1's alternation and decision 0436's fish stew). Of the recipe book's
## dishes for the meal (dish_book.gd `meal`) whose free food makes at least a batch, the cook picks, in order:
##   1. one whose food feeds the whole meal (every portion it wants) -- a favourite made from a little beetroot never
##      leaves the village short while the carrots would feed it;
##   2. the one whose food keeps least long (meal_rules.gd `fresher_first`: fresh fish, then greens, roots, grain) --
##      0436's "fresh fish is cooked while it is fresh", for every dish;
##   3. the one the village likes most: every resident's species' likes less dislikes (dish_favourites.gd), everyone
##      being called to every meal;
##   4. the book's order -- the meal's plain dish (porridge, Togget's soup, the perch-or-trout stew) before a dish that
##      names its own ingredients.
## With no dish of its own meal possible, the best of the other meal's (ruling 1: "the other dish when this one's food
## is wanting"); with none at all, the meal's plain dish, waiting for food. A meal is re-chosen only while it holds no
## food. Deterministic: the same stores, meal and village always give the same dish.
##
## THE COOK (ruling: any resident can cook). The village cook is the keeper (COOK_KEYS; the first resident without
## one), as the bridgewright is the village's bridge specialist; when the cook is not free while a meal is due, the
## nearest free resident STANDS IN; and the player's Cook order makes a selected resident the cook. One cook at a
## time does the ROUND, every step physical:
##   fetch     to a store holding the planned meals' reserved food (the kitchen's pantry, the covered store, a root
##             cellar's hatch), pick it up (1 WU), and carry it to the cauldron and put it down (1 WU) -- both planned
##             meals' food there at once; a second store is a trip of its own;
##   cook      at the cauldron, a batch at a time at §5.2's step rate (80 milli-WU a calendar tick): a batch starts by
##             taking its food from the reserved lots, its water from the butt and its 0.1 U of wood from the village
##             stores, all or nothing, ONCE; its work in progress belongs to the kitchen (REQ-SET-091: a new cook
##             finishes it, nothing is taken again); finished, its 2 portions go into the pot (meal_store.gd);
##   serve     each meal's pot carried to the hall's table as soon as it is cooked, and the portions put out (1 WU);
##   eat       before it sets off to fetch again, the cook eats today's meal waiting at the table.
## Breakfast is cooked from COOK_RISE_HOUR (05:00): the cook is up before the village to have it on the table by
## its call at 07:00 (night_routine.gd's early riser), then fetches the next day's food; supper is cooked from 15:00
## (meal_rules.gd COOK_FROM_HOUR: on the open table a portion ages at the open-pile factor, so a meal is cooked close
## to its call). The hours are decision 0421's.
##
## WATER is drawn by anyone free (the fixture crew's convention: the nearest resident wandering on its own) while
## KEEP WATER DRAWN is on -- the butt by the well kept full, a carry at a time (§5.2's carry capacity, water 1000 g a
## unit), at most MAX_DRAWERS at once -- or by the selected residents on the player's Draw water order. A batch takes
## its water from that stock (ruling 2: drawn "into the stores"), as it takes its wood.
##
## THE DINERS. During a meal (from its call, 07:00 or 17:00), once its food is on its way (in the pot or out), every
## resident not in an emergency, the water or bed is called to the tables -- a drawer too -- its job PARKED on its
## resume queue (decision 0205) as the night's are; whoever comes free during the meal is called too. Seated, it eats the first portion out by §5.7's order (meal_store.gd) -- a 12-WU task, the portion
## consumed at its end (REQ-SET-095) -- and goes back to its job. At the meal's end, a resident still without food
## who is hungry (REQ-SET-013: hunger <= 1500) eats raw-edible food nobody reserved, up to 3000 NP, where it is
## stored; everyone else goes without, and the feed says so.
##
## INTERRUPTION never loses or doubles anything: food in hand stays with the cook (the books never moved), the pot
## with it, a batch in progress at the cauldron, a drawer's water in its hands (stock only once poured); a diner's
## portion goes back on the table. A CANCEL gives the meal's reservation back untouched; a batch in progress when it is
## cancelled is REQ-SET-094's: "yield 50% of food input mass as spoiled_food ... and no finished portions".
##
## SHORTAGES are said exactly, with the way to fix them (action_card.gd's "Can't now: ... / To fix: ..."), from the
## SAME decision the Cook order and its card use (`decide_meal`); a meal called with nothing coming is the incident
## "kitchen:no_meal" ("No supper tonight: ..."), resolved when the village next eats.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const StoreScript := preload("res://demo/kitchen/meal_store.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const FedScript := preload("res://demo/kitchen/nourishment.gd")
const TaskScript := preload("res://demo/kitchen/kitchen_task.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

const ROLE_NONE: int = 0
const ROLE_COOK: int = TaskScript.ROLE_COOK
const ROLE_DRAW: int = TaskScript.ROLE_DRAW
const ROLE_EAT: int = TaskScript.ROLE_EAT
## Steps (kitchen_task.gd): walks below WORK_FIRST, works from it.
const STEP_DONE: int = TaskScript.STEP_DONE
const WALK_STORE: int = TaskScript.WALK_STORE
const WALK_KITCHEN: int = TaskScript.WALK_KITCHEN
const WALK_TABLE: int = TaskScript.WALK_TABLE
const WALK_WELL: int = TaskScript.WALK_WELL
const WALK_BUTT: int = TaskScript.WALK_BUTT
const WALK_SEAT: int = TaskScript.WALK_SEAT
const WALK_RAW: int = TaskScript.WALK_RAW
const WORK_FIRST: int = TaskScript.WORK_FIRST
const WORK_PICK: int = TaskScript.WORK_PICK
const WORK_PUT_DOWN: int = TaskScript.WORK_PUT_DOWN
const WORK_COOK: int = TaskScript.WORK_COOK
const WORK_PUT_OUT: int = TaskScript.WORK_PUT_OUT
const WORK_DRAW: int = TaskScript.WORK_DRAW
const WORK_POUR: int = TaskScript.WORK_POUR
const WORK_WAIT: int = TaskScript.WORK_WAIT
const WORK_EAT: int = TaskScript.WORK_EAT
const WORK_EAT_RAW: int = TaskScript.WORK_EAT_RAW
## Where a resident stands (the place its last walk reached).
const PLACE_NONE: int = 0
const PLACE_KITCHEN: int = 1
const PLACE_TABLE: int = 2
const PLACE_STORE: int = 3
const PLACE_WELL: int = 4
const PLACE_BUTT: int = 5
const PLACE_SEAT: int = 6
const PLACE_RAW: int = 7
const WALK_PLACE: PackedInt32Array = [PLACE_NONE, PLACE_STORE, PLACE_KITCHEN, PLACE_TABLE, PLACE_WELL, PLACE_BUTT,
	PLACE_SEAT, PLACE_RAW]

## Meals planned ahead: two days' (see THE MEALS), so one fetch can bring a day's food ahead of time.
const MAX_SLOTS: int = 4
## The logs kept for the panels and the checks (the latest only: a long session at 4x runs hundreds of days).
const MAX_MEAL_LOG: int = 64
const MAX_BATCH_LOG: int = 256
## `carried_item`'s codes for the pot and water (kitchen_view.gd draws them).
const CARRY_POT: int = -2
const CARRY_WATER: int = -3
const FREE: int = -1
const NOBODY: int = -1
## The village cook's trade (cast_routines.gd: the keeper keeps the hall, the table and the well).
const COOK_KEYS: Array[StringName] = [&"mouse_keeper"]
const MAX_DRAWERS: int = 2
## Hand-outs and a free diner's re-call, at most this often (calendar ticks: 0.5 s at 1x, as the other crews'
## PICKUP_USEC, and the night routine's RESEND_TICKS, 1.27 s -- the real seconds they were before decision 0421 made a
## game hour 25 s).
const PICKUP_TICKS: int = 15
const RESEND_TICKS: int = NightScript.RESEND_TICKS
## A cook stands in (nobody else free being the cook) when a meal is called within this many hours.
const STAND_IN_HOURS: int = 4
## Walks given up in a row before the kitchen gives up on that place for the meal.
const MAX_FAILS: int = 3
const INCIDENT_KEY: String = "kitchen:no_meal"
## sim_clock.gd SEASON_NAMES' winter.
const WINTER: int = 3
## Decision codes (the order's and the card's).
const OK: String = ""
const NO_FOOD: String = "NO_FOOD"
const NO_WATER: String = "NO_WATER"
const NO_FUEL: String = "NO_FUEL"
const NO_COOK: String = "NO_COOK"
const NOTHING_TO_COOK: String = "NOTHING_TO_COOK"
const BUTT_FULL: String = "BUTT_FULL"
const NO_DRAWER: String = "NO_DRAWER"


## What an order would do and why not: the Cook and Draw water orders, their cards and the routine's shortage
## reports all read one of these (decide_meal, decide_cook, decide_draw).
class Decision extends RefCounted:
	var code: String = ""
	var reason: String = ""
	var fix: String = ""
	var meal_key: int = -1
	var dish: int = -1
	var batches: int = 0
	## Each of the dish's inputs (meal_rules.gd INPUT_N), had (reserved for this meal, or free) and needed.
	var input_have: PackedInt64Array = PackedInt64Array()
	var input_need: PackedInt64Array = PackedInt64Array()
	var water_have: int = 0
	var water_need: int = 0
	var wood_have: int = 0
	var wood_need: int = 0
	var worker: int = -1
	var who: String = ""
	var amount: int = 0

	func ok() -> bool:
		"""Whether the order may be given."""
		return code.is_empty()

	func refuse(p_code: String, words: String, how: String) -> Decision:
		"""Refused: the code, the words and the way to put it right. Returns itself."""
		code = p_code
		reason = words
		fix = how
		return self


var pantry: PantryScript = null
var stores: StoresScript = null
var calendar: CalendarScript = null
var places: PlacesScript = null
var store: StoreScript = StoreScript.new()
var takes: TakesScript = TakesScript.new()
var fed: FedScript = FedScript.new()
## Whether water is drawn for the planned meals by anyone free (the Kitchen tab's "Keep water drawn").
var keep_water: bool = true
## The village cook (COOK_KEYS), and who is the cook now (NOBODY between rounds).
var designated: int = NOBODY
var cook: int = NOBODY
## Bumped on every change the panels show.
var revision: int = 0

var _brains: Array[BrainScript] = []
var _names: PackedStringArray = PackedStringArray()
var _notices: NoticesScript = null
var _incidents: IncidentsScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
# per resident
var _role: PackedInt32Array = PackedInt32Array()
var _step: PackedInt32Array = PackedInt32Array()
var _place: PackedInt32Array = PackedInt32Array()
var _issued: PackedByteArray = PackedByteArray()
var _at_work: PackedByteArray = PackedByteArray()
var _mwu: PackedInt64Array = PackedInt64Array()
var _need: PackedInt64Array = PackedInt64Array()
var _credited: PackedInt32Array = PackedInt32Array()
var _target: PackedVector2Array = PackedVector2Array()
var _face: PackedVector2Array = PackedVector2Array()
var _location: PackedInt32Array = PackedInt32Array()
var _seat: PackedInt32Array = PackedInt32Array()
var _portion: PackedInt32Array = PackedInt32Array()
var _meal: PackedInt32Array = PackedInt32Array()
var _raw_take: PackedInt32Array = PackedInt32Array()
var _raw_np: PackedInt32Array = PackedInt32Array()
var _raw_item: PackedInt32Array = PackedInt32Array()
var _water: PackedInt64Array = PackedInt64Array()
var _draw_amount: PackedInt64Array = PackedInt64Array()
var _called: PackedInt32Array = PackedInt32Array()
var _sent_tick: PackedInt32Array = PackedInt32Array()
var _fails: PackedInt32Array = PackedInt32Array()
## Per resident: 1 while a raw meal whose walk was given up waits to set off again (see `called_away`).
var _raw_retry: PackedByteArray = PackedByteArray()
var _tasks: Array[TaskScript] = []
# the planned meals
var _slot_key: PackedInt32Array = PackedInt32Array()
var _slot_dish: PackedInt32Array = PackedInt32Array()
var _slot_wanted: PackedInt32Array = PackedInt32Array()
var _slot_cooked: PackedInt32Array = PackedInt32Array()
var _slot_take: PackedInt32Array = PackedInt32Array()
## The live slots, earliest meal first: re-sorted when a slot is filled or retired (`_resort_slots`), so the per-frame
## readers (`carried_item`, the early riser's poll) never allocate.
var _slot_order: PackedInt32Array = PackedInt32Array()
## Per-frame readers' caches, kept for a calendar tick: the cook's duty (the night routine polls `up_early` every frame)
## and the food item it is drawn carrying (kitchen_view.gd polls `carried_item` every frame), keyed by its step too.
var _duty_tick: int = -1
var _duty: bool = false
var _carried_tick: int = -1
var _carried_step: int = STEP_DONE
var _carried_food: int = Catalog.NO_ITEM
var _next_key: int = 0
## THE LARDER: food the cook has fetched (in hand or at the cauldron) for a meal that was cancelled or whose serving
## ended uncooked -- it stays where it was carried and goes to the next meal of its category (`_top_up`).
var _larder_take: int = 0
## The batch at the cauldron: its meal (FREE: none), dish and work done.
var _wip_key: int = FREE
var _wip_dish: int = Rules.NO_DISH
var _wip_mwu: int = 0
var _pot_in_hand: bool = false
var _cook_now_key: int = FREE
var _queued_draws: int = 0
var _hour_seen: int = 0
var _pickup_tick: int = -PICKUP_TICKS
## The meal being served (its key; FREE between meals) and its tally.
var _serving: int = FREE
## The meal whose call has been said in the news (said when its first diner is called).
var _announced: int = FREE
## Portions eaten and raw meals eaten, by the meal they were eaten for (its key): the tally at its end. A resident
## holding its portion (or raw food) at the end is counted then, as served; one called away after that without eating
## is moved to "went without" (`_served_but_missed`).
var _ate_by_meal: Dictionary = {}
var _raw_by_meal: Dictionary = {}
## The last meal whose serving has ended (FREE before the first).
var _closed_key: int = FREE
## The village's taste for each dish (nourishment.gd `village_taste`), fixed when the kitchen is configured.
var _dish_taste: PackedInt32Array = PackedInt32Array()
## THE READY-FOOD ESTIMATE's scratch (`_estimate`): food by category, and batches by dish -- reused, never reallocated
## once sized.
var _pool: PackedInt64Array = PackedInt64Array()
var _estimated: PackedInt32Array = PackedInt32Array()
## Every milli-U the kitchen has taken or made, for the conservation checks and the ledger.
var consumed_food_milli: int = 0
var consumed_water_milli: int = 0
var consumed_wood_milli: int = 0
var poured_water_milli: int = 0
var cancelled_spoil_milli: int = 0
var batches_cooked: int = 0
## Every batch finished, in order: its meal, its dish (the checks read which dish each meal was) and who cooked it (the
## cook at the cauldron as it finished; the people ledger's "cooked for everyone", decision 0491).
var cooked_keys: PackedInt32Array = PackedInt32Array()
var cooked_dishes: PackedInt32Array = PackedInt32Array()
var cooked_by: PackedInt32Array = PackedInt32Array()
## Every meal's tally at its end, in order: its key, how many ate a portion, ate raw, went without.
var meal_keys: PackedInt32Array = PackedInt32Array()
var meal_ate: PackedInt32Array = PackedInt32Array()
var meal_raw: PackedInt32Array = PackedInt32Array()
var meal_without: PackedInt32Array = PackedInt32Array()
var portions_eaten: int = 0
var raw_eaten_milli: int = 0


func configure(brains: Array[BrainScript], names: PackedStringArray, species: PackedStringArray,
		keys: Array[StringName], p_pantry: PantryScript, p_stores: StoresScript, p_calendar: CalendarScript,
		p_places: PlacesScript) -> void:
	"""The kitchen for these residents (by index: their names, species and cast keys), cooking from this pantry and
	these stores on this calendar, at these places."""
	_brains = brains
	_names = names
	pantry = p_pantry
	stores = p_stores
	calendar = p_calendar
	places = p_places
	fed.configure(species)
	_dish_taste.resize(Rules.DISH_COUNT)
	for dish: int in Rules.DISH_COUNT:
		_dish_taste[dish] = fed.village_taste(dish)
	_size_columns(brains.size())
	designated = _designated_of(keys)
	_hour_seen = calendar.hour_index()
	_larder_take = takes.new_take()
	_next_key = _first_key(_hour_seen)
	_plan(_hour_seen)
	var meal: int = Rules.meal_of_hour(_hour_seen % SimClock.HOURS_PER_DAY)
	if meal >= 0:
		_open_meal(Rules.meal_key(_hour_seen / SimClock.HOURS_PER_DAY, meal))


func bind_news(notices: NoticesScript, incidents: IncidentsScript) -> void:
	"""Say what happens in this feed, and raise "No supper tonight" in these incidents (null: silent)."""
	_notices = notices
	_incidents = incidents


func _size_columns(n: int) -> void:
	"""Every per-resident column sized for `n` residents, and the meal slots."""
	for column: PackedInt32Array in [_role, _step, _place, _credited, _location, _seat, _portion, _meal, _raw_take,
			_raw_np, _raw_item, _called, _sent_tick, _fails]:
		column.resize(n)
	for column: PackedInt64Array in [_mwu, _need, _water, _draw_amount]:
		column.resize(n)
	_issued.resize(n)
	_raw_retry.resize(n)
	_at_work.resize(n)
	_target.resize(n)
	_face.resize(n)
	_step.fill(STEP_DONE)
	_seat.fill(FREE)
	_portion.fill(FREE)
	_called.fill(FREE)
	_sent_tick.fill(-RESEND_TICKS)
	_tasks.resize(n)
	for column: PackedInt32Array in [_slot_key, _slot_dish, _slot_wanted, _slot_cooked, _slot_take]:
		column.resize(MAX_SLOTS)
	_slot_key.fill(FREE)
	_slot_order.clear()


func shut_down() -> void:
	"""The village is going (a Restart): drop the tasks this kitchen holds (each holds it only weakly)."""
	_tasks.fill(null)


func _designated_of(keys: Array[StringName]) -> int:
	"""The village cook: the first resident with a COOK_KEYS trade, else the first resident (NOBODY with none)."""
	for i: int in keys.size():
		if COOK_KEYS.has(keys[i]):
			return i
	return 0 if not keys.is_empty() or not _brains.is_empty() else NOBODY


static func _first_key(hour_index: int) -> int:
	"""The first meal whose serving has not ended at `hour_index`."""
	var day: int = hour_index / SimClock.HOURS_PER_DAY
	var hour: int = hour_index % SimClock.HOURS_PER_DAY
	if hour < Rules.END_HOUR[Rules.MEAL_BREAKFAST]:
		return Rules.meal_key(day, Rules.MEAL_BREAKFAST)
	if hour < Rules.END_HOUR[Rules.MEAL_SUPPER]:
		return Rules.meal_key(day, Rules.MEAL_SUPPER)
	return Rules.meal_key(day + 1, Rules.MEAL_BREAKFAST)


static func _ends_at(key: int) -> int:
	"""The calendar hour index meal `key`'s serving ends at."""
	return (key / 2) * SimClock.HOURS_PER_DAY + Rules.END_HOUR[key % 2]


static func _cook_from(key: int) -> int:
	"""The calendar hour index meal `key` may be cooked from: its COOK_FROM_HOUR of its day (see THE COOK)."""
	return (key / 2) * SimClock.HOURS_PER_DAY + Rules.COOK_FROM_HOUR[key % 2]


# --- per frame -----------------------------------------------------------------------------------------

func update() -> void:
	"""Once a frame, after the calendar has moved: the hours crossed, the work done, the tables, the hand-outs."""
	if _brains.is_empty():
		return
	while _hour_seen < calendar.hour_index():
		_hour_seen += 1
		_on_hour(_hour_seen)
	_credit_work(calendar.tick)
	_watch_tables()
	if calendar.tick - _pickup_tick >= PICKUP_TICKS:
		_pickup_tick = calendar.tick
		_hand_out()


func _on_hour(hour_index: int) -> void:
	"""An hour crossed: the portions age, everyone's hunger falls, reserved food that spoiled is let go; a meal is
	called or closed; the next meals are planned."""
	var season: int = PantryScript.season_of_hour(hour_index)
	store.age_hour(season)
	pantry.spoiled_milli += store.take_spoiled()
	fed.pass_hour(hour_index / SimClock.HOURS_PER_DAY, season == WINTER, hour_index)
	takes.prune(pantry)
	var day: int = hour_index / SimClock.HOURS_PER_DAY
	var hour: int = hour_index % SimClock.HOURS_PER_DAY
	for meal: int in 2:
		if hour == Rules.END_HOUR[meal]:
			_close_meal(Rules.meal_key(day, meal))
		if hour == Rules.CALL_HOUR[meal]:
			_open_meal(Rules.meal_key(day, meal))
	_plan(hour_index)
	revision += 1


# --- planning ----------------------------------------------------------------------------------------

func _plan(hour_index: int) -> void:
	"""Retire meals over or cooked, plan the next ones into free slots, and top short ones up (see THE MEALS)."""
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE and (_slot_done(s) or hour_index >= _ends_at(_slot_key[s])):
			_retire(s)
	for s: int in _slots_by_key():
		_top_up(s, hour_index)
	for s: int in MAX_SLOTS:
		if _slot_key[s] == FREE:
			_fill_slot(s, hour_index)


func _fill_slot(s: int, hour_index: int) -> void:
	"""Plan the next meal into slot `s`: its dish, how many batches, and its food reserved."""
	while hour_index >= _ends_at(_next_key):
		_next_key += 1
	_slot_key[s] = _next_key
	_next_key += 1
	_slot_cooked[s] = 0
	_slot_take[s] = takes.new_take()
	_slot_dish[s] = _choose_dish(s)
	_resort_slots()
	_slot_wanted[s] = _wanted(s)
	_top_up(s, hour_index)


func _choose_dish(s: int) -> int:
	"""THE CHOICE for slot `s`'s meal: the best of its meal's dishes its free food makes a batch of; else the best of the
	other meal's; else the meal's plain dish (no food for any: it waits for some)."""
	var meal: int = _slot_key[s] % 2
	var short: int = _portions_wanted(s)
	var best: int = _best_dish(meal, true, short)
	if best == Rules.NO_DISH:
		best = _best_dish(meal, false, short)
	return best if best != Rules.NO_DISH else Rules.dish_for_meal(meal)


func _best_dish(meal: int, own: bool, portions: int) -> int:
	"""Of the dishes for `meal` (`own`) or for the other meal (not `own`), the first in THE CHOICE's order whose free food
	makes a batch, for a meal of `portions` (Rules.NO_DISH: none)."""
	var best: int = Rules.NO_DISH
	var best_covers: bool = false
	for dish: int in Rules.DISH_COUNT:
		var batches: int = _free_batches(dish) if (Rules.DISH_MEAL[dish] == meal) == own else 0
		if batches == 0:
			continue
		var covers: bool = batches * Rules.PORTIONS_PER_BATCH[dish] >= portions
		if best == Rules.NO_DISH or (covers and not best_covers) or (covers == best_covers and _chosen_before(dish, best)):
			best = dish
			best_covers = covers
	return best


func _chosen_before(a: int, b: int) -> bool:
	"""THE CHOICE's order between two dishes that alike cover the meal or not: the food that keeps less long, then the
	village's taste, then the book's order."""
	var fresher: int = Rules.fresher_first(a, b)
	if fresher != 0:
		return fresher < 0
	if _dish_taste[a] != _dish_taste[b]:
		return _dish_taste[a] > _dish_taste[b]
	return a < b


func taste_of_village(dish: int) -> int:
	"""The village's taste for `dish` (likes less dislikes) the choice weighs."""
	return _dish_taste[dish] if dish >= 0 and dish < _dish_taste.size() else 0


func _free_of(crop: int) -> int:
	"""Selector `crop`'s food no planned meal holds: unreserved in the pantry, and fetched waiting in the larder (see
	THE LARDER)."""
	return takes.free_milli_of_crop(pantry, crop) + takes.fetched_milli_of_crop(pantry, _larder_take, crop)


func _free_batches(dish: int) -> int:
	"""Whole batches of `dish` the free food makes (the least of its inputs'). A dish's inputs never share an item
	(test_demo_dishes.gd checks the book), so no food is counted for two of them."""
	var batches: int = 1 << 30
	for k: int in Rules.INPUT_N[dish]:
		@warning_ignore("integer_division")
		batches = mini(batches, _free_of(Rules.input_selector(dish, k)) / Rules.input_milli(dish, k))
	return batches


func _wanted(s: int) -> int:
	"""Batches of its dish slot `s`'s meal wants (`_portions_wanted`, in whole batches)."""
	@warning_ignore("integer_division")
	return (_portions_wanted(s) + Rules.PORTIONS_PER_BATCH[_slot_dish[s]] - 1) / Rules.PORTIONS_PER_BATCH[_slot_dish[s]]


func _portions_wanted(s: int) -> int:
	"""Portions slot `s`'s meal wants: one each for every resident, less the LEFTOVERS -- portions of meals whose serving
	is over that will still be good at its call (eaten first) -- when it is the earliest planned meal."""
	var key: int = _slot_key[s]
	var call: int = (key / 2) * SimClock.HOURS_PER_DAY + Rules.CALL_HOUR[key % 2]
	var spare: int = store.portions_lasting(_first_key(_hour_seen), maxi(0, call - _hour_seen),
		PantryScript.season_of_hour(_hour_seen)) if key == _earliest_key() else 0
	return maxi(0, _brains.size() - spare)


func _top_up(s: int, hour_index: int) -> void:
	"""Reserve what slot `s` still lacks, every input; with nothing yet reserved or cooked, choose its dish again (THE
	CHOICE: the stores may have changed)."""
	if _slot_cooked[s] == 0 and _wip_key != _slot_key[s] and takes.live_milli(pantry, _slot_take[s]) == 0:
		_slot_dish[s] = _choose_dish(s)
	var dish: int = _slot_dish[s]
	_slot_wanted[s] = maxi(_slot_cooked[s] + _wip_on(s), _wanted(s))
	var wanted: int = _slot_wanted[s] - _slot_cooked[s] - _wip_on(s)
	if wanted - _reserved_batches(s) <= 0:
		return
	for k: int in Rules.INPUT_N[dish]:
		_reserve_input(s, Rules.input_selector(dish, k), Rules.input_milli(dish, k), wanted, hour_index)
	if Rules.INPUT_N[dish] > 1:
		_even_inputs(s, hour_index)


func _reserve_input(s: int, crop: int, per_batch: int, wanted: int, hour_index: int) -> void:
	"""Hold selector `crop`'s food for `wanted` batches of slot `s`'s meal at `per_batch` each: the larder's fetched food
	first, then the pantry's soonest to spoil; trimmed to whole batches."""
	var lacking: int = wanted * per_batch - takes.live_milli(pantry, _slot_take[s], -1, crop)
	if lacking <= 0:
		return
	lacking -= takes.draw_fetched(pantry, _larder_take, _slot_take[s], crop, lacking)
	if lacking > 0:
		takes.reserve_into(pantry, _slot_take[s], crop, lacking, hour_index, _read)
	var odd: int = takes.live_milli(pantry, _slot_take[s], -1, crop) % per_batch
	if odd > 0:
		takes.release_milli(pantry, _slot_take[s], odd, hour_index, crop)


func _even_inputs(s: int, hour_index: int) -> void:
	"""A meal of several inputs holds no more of any than whole batches of all make (the rest stays free)."""
	var dish: int = _slot_dish[s]
	var batches: int = _reserved_batches(s)
	for k: int in Rules.INPUT_N[dish]:
		var crop: int = Rules.input_selector(dish, k)
		var over: int = takes.live_milli(pantry, _slot_take[s], -1, crop) - batches * Rules.input_milli(dish, k)
		if over > 0:
			takes.release_milli(pantry, _slot_take[s], over, hour_index, crop)


func _retire(s: int) -> void:
	"""Slot `s`'s meal is cooked, or its serving is over: food the cook has fetched for it stays fetched, in the larder
	(see THE LARDER); what it reserves still at its store is given back (the food never moved)."""
	takes.keep_fetched(pantry, _slot_take[s], _larder_take)
	takes.release(_slot_take[s])
	_slot_key[s] = FREE
	_resort_slots()
	if _cook_now_key >= 0 and _slot_index_of(_cook_now_key) < 0:
		_cook_now_key = FREE


func _slot_done(s: int) -> bool:
	"""Whether slot `s`'s meal has every batch it wants cooked."""
	return _slot_cooked[s] > 0 and _slot_cooked[s] >= _slot_wanted[s] and _wip_key != _slot_key[s]


func _reserved_batches(s: int) -> int:
	"""Whole batches slot `s`'s live reservation makes (the least of its dish's inputs)."""
	return _batches_held(s, -1)


func _batches_held(s: int, where: int) -> int:
	"""Whole batches slot `s`'s take holds (at `where`, AT_*; -1: anywhere): the least of its dish's inputs."""
	var dish: int = _slot_dish[s]
	var batches: int = 1 << 30
	for k: int in Rules.INPUT_N[dish]:
		@warning_ignore("integer_division")
		batches = mini(batches,
			takes.live_milli(pantry, _slot_take[s], where, Rules.input_selector(dish, k)) / Rules.input_milli(dish, k))
	return batches


func _wip_on(s: int) -> int:
	"""1 when the batch at the cauldron is slot `s`'s."""
	return 1 if _wip_key != FREE and _wip_key == _slot_key[s] else 0


func _earliest_key() -> int:
	"""The earliest planned meal's key (FREE: none)."""
	var best: int = FREE
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE and (best == FREE or _slot_key[s] < best):
			best = _slot_key[s]
	return best


func _slot_index_of(key: int) -> int:
	"""The slot planning meal `key` (FREE: none)."""
	return _slot_key.find(key) if key != FREE else FREE


func _slots_by_key() -> PackedInt32Array:
	"""The planned slots, earliest meal first (kept sorted by `_resort_slots`; no allocation)."""
	return _slot_order


func _resort_slots() -> void:
	"""Rebuild `_slot_order` after a slot was filled or retired: the live slots by key (an insertion sort of four)."""
	_slot_order.clear()
	for s: int in MAX_SLOTS:
		if _slot_key[s] == FREE:
			continue
		var at: int = _slot_order.size()
		while at > 0 and _slot_key[_slot_order[at - 1]] > _slot_key[s]:
			at -= 1
		_slot_order.insert(at, s)


# --- cooking -----------------------------------------------------------------------------------------

func _cookable_slot() -> int:
	"""The earliest planned meal a batch may start for now: its cooking time come (or ordered now) and a batch's food
	at the cauldron (FREE: none)."""
	for s: int in _slots_by_key():
		if _slot_done(s) or not _cook_time_come(s):
			continue
		if _batches_held(s, TakesScript.AT_KITCHEN) > 0:
			return s
	return FREE


func _cook_time_come(s: int) -> bool:
	"""Whether slot `s`'s meal may be cooked now: its COOK_FROM_HOUR come, or ordered cooked now (Cook now)."""
	return _hour_seen >= _cook_from(_slot_key[s]) or _cook_now_key == _slot_key[s]


func can_start_batch() -> bool:
	"""Whether a batch could start now: a meal's food at the cauldron, a batch's water in the butt and its wood in the
	stores, and room for its portions."""
	var s: int = _cookable_slot()
	if s < 0 or not store.has_room():
		return false
	var dish: int = _slot_dish[s]
	return stores.water_milli_u >= Rules.WATER_MILLI[dish] and stores.wood_milli_u >= Rules.WOOD_MILLI_PER_BATCH


func _start_batch() -> bool:
	"""A batch starts: its food, water and wood taken, ONCE, all together (see THE COOK). False, nothing taken, when
	it cannot."""
	if not can_start_batch():
		return false
	var s: int = _cookable_slot()
	var dish: int = _slot_dish[s]
	if not _consume_batch_food(s, dish):
		return false
	var water_taken: bool = stores.take_water(Rules.WATER_MILLI[dish])
	if not (stores.take_wood(Rules.WOOD_MILLI_PER_BATCH) and water_taken):
		push_error("kitchen: a batch's water or wood was gone after can_start_batch found it")
	consumed_food_milli += Rules.batch_food_milli(dish)
	consumed_water_milli += Rules.WATER_MILLI[dish]
	consumed_wood_milli += Rules.WOOD_MILLI_PER_BATCH
	_wip_key = _slot_key[s]
	_wip_dish = dish
	_wip_mwu = 0
	revision += 1
	return true


func _consume_batch_food(s: int, dish: int) -> bool:
	"""Withdraw a batch's food at the kitchen -- every input, all or none: the later inputs are checked there first,
	then each `consume_into` (all or nothing) takes its own, the first input's refusal still taking nothing."""
	for k: int in range(1, Rules.INPUT_N[dish]):
		if takes.live_milli(pantry, _slot_take[s], TakesScript.AT_KITCHEN, Rules.input_selector(dish, k)) \
				< Rules.input_milli(dish, k):
			return false
	for k: int in Rules.INPUT_N[dish]:
		if not takes.consume_into(pantry, _slot_take[s], Rules.input_milli(dish, k), TakesScript.AT_KITCHEN, _hour_seen,
				_read, Rules.input_selector(dish, k)):
			if k == 0:
				return false
			push_error("kitchen: a batch's input was gone between its check and its withdrawal")
	return true


func _cook_work(i: int, ticks: int) -> void:
	"""Cook `ticks` of work at the cauldron: the batch in progress, then the next one if one may start; done with
	nothing more to cook -- or with the meal being served waiting in the pot while the next batch is a later meal's --
	the cook moves on (and takes the pot to the table first)."""
	var left: int = ticks * Rules.MWU_PER_TICK
	while left > 0:
		if _wip_key == FREE and (_pot_due() or not _start_batch()):
			_advance(i)
			return
		var need: int = Rules.WORK_MWU[_wip_dish] - _wip_mwu
		var part: int = mini(left, need)
		_wip_mwu += part
		left -= part
		if _wip_mwu >= Rules.WORK_MWU[_wip_dish]:
			_finish_batch()


func _pot_due() -> bool:
	"""Whether the pot holds portions for the first meal still to be served while the next batch would be a later
	meal's: those go out to the table before more is cooked (a late breakfast is not kept back by supper)."""
	var first: int = _first_key(_hour_seen)
	if store.in_pot(first) == 0:
		return false
	var s: int = _cookable_slot()
	return s >= 0 and _slot_key[s] > first


func _finish_batch() -> void:
	"""The batch is done: its portions go into the pot, for its meal."""
	if store.add(_wip_dish, Rules.PORTIONS_PER_BATCH[_wip_dish], _wip_key) == FREE:
		push_error("kitchen: no lot for a finished batch after can_start_batch found room")
	batches_cooked += 1
	cooked_keys.append(_wip_key)
	cooked_dishes.append(_wip_dish)
	cooked_by.append(cook)
	if cooked_keys.size() > MAX_BATCH_LOG:
		cooked_keys.remove_at(0)
		cooked_dishes.remove_at(0)
		cooked_by.remove_at(0)
	var s: int = _slot_index_of(_wip_key)
	_wip_key = FREE
	revision += 1
	if s < 0:
		return
	_slot_cooked[s] += 1
	if _slot_done(s):
		_say(Words.cooked_line(_slot_key[s], _slot_dish[s], _slot_cooked[s] * Rules.PORTIONS_PER_BATCH[_slot_dish[s]]))
		_retire(s)
		_plan(_hour_seen)


func cancel_meal() -> String:
	"""The player's Cancel: the next meal is not cooked. Its reservation is given back untouched; a batch in progress
	for it is REQ-SET-094's -- half its food's mass spoiled food, no portions. The answer, in words."""
	var s: int = _slot_index_of(_earliest_key())
	if s < 0:
		return Words.NOTHING_PLANNED
	var key: int = _slot_key[s]
	if _wip_key == key:
		var spoil: int = Rules.batch_food_milli(_wip_dish) / 2
		pantry.spoiled_milli += spoil
		cancelled_spoil_milli += spoil
		_wip_key = FREE
	_retire(s)
	_plan(_hour_seen)
	revision += 1
	return Words.cancelled_line(key)


# --- per-resident steps -------------------------------------------------------------------------------

func _start_role(i: int, role: int, cleared: bool = false) -> void:
	"""Hand resident `i` its part (a direct order: what it was doing is parked by its owner, or here, a work spot);
	`cleared`: its old part already ended (a raw meal reserved since)."""
	if not cleared:
		_clear_role(i)
	_raw_retry[i] = 0
	var brain: BrainScript = _brains[i]
	if brain.order == BrainScript.ORDER_WORK and brain.poi >= 0:
		brain.remember_unfinished(UnfinishedScript.new(NightScript.WorkBack.new(brain.poi).take_back,
			"Work at %s" % String(brain.space().poi_names[brain.poi]).replace("_", " ")))
	_role[i] = role
	_place[i] = PLACE_NONE
	_advance(i)
	var task := TaskScript.new(self, i, role)
	_tasks[i] = task
	brain.order_task(task)
	revision += 1


func _clear_role(i: int) -> void:
	"""Resident `i`'s part ends: a diner's portion or raw food goes back (nothing eaten), the step state is reset;
	what a cook or drawer carries stays with it."""
	if (_portion[i] != FREE or _raw_take[i] > 0) and _meal[i] != FREE and _meal[i] <= _closed_key:
		_served_but_missed(i)
	if _portion[i] != FREE:
		store.release_one(_portion[i])
		_portion[i] = FREE
	if _raw_take[i] > 0:
		takes.release(_raw_take[i])
		_raw_take[i] = 0
	_raw_retry[i] = 0
	_seat[i] = FREE
	_reset_part(i)


func _reset_part(i: int) -> void:
	"""Resident `i` has no kitchen part now: its role and step state reset, its task let go."""
	_role[i] = ROLE_NONE
	_step[i] = STEP_DONE
	_issued[i] = 0
	_at_work[i] = 0
	_tasks[i] = null


func _served_but_missed(i: int) -> void:
	"""Resident `i`, counted as served at its meal's end, gives its food back uneaten: it went without after all."""
	var at: int = meal_keys.rfind(_meal[i])
	if at >= 0:
		if _portion[i] != FREE:
			meal_ate[at] -= 1
		else:
			meal_raw[at] -= 1
		meal_without[at] += 1
	fed.missed(i, _meal[i])


func first_site(i: int) -> Vector2:
	"""Where resident `i` walks first under its new task: the first walk's spot (taken as issued), or where it stands
	when it starts at its work."""
	if _step[i] > STEP_DONE and _step[i] < WORK_FIRST:
		_issued[i] = 1
		return _walk_target(i)
	return _brains[i].position


func arrived(i: int) -> void:
	"""Resident `i`'s walk is over: it is at the place, and goes on to its next step."""
	if _role[i] == ROLE_NONE or _step[i] <= STEP_DONE or _step[i] >= WORK_FIRST or _issued[i] == 0:
		return
	_place[i] = WALK_PLACE[_step[i]]
	_fails[i] = 0
	_advance(i)


func drive(i: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of resident `i`'s part (kitchen_task.gd): issue the walk, or stand at the work. False once over."""
	if _role[i] == ROLE_NONE or _step[i] == STEP_DONE:
		return false
	if _step[i] < WORK_FIRST:
		if _issued[i] == 0:
			_issued[i] = 1
			if _carries(i):
				brain.task_carry_to(_walk_target(i))
			else:
				brain.task_walk_to(_walk_target(i))
		return true
	brain.task_face(_face[i], delta)
	brain.task_play(Words.clip_for(_step[i], brain))
	if _at_work[i] == 0:
		_at_work[i] = 1
		_credited[i] = calendar.tick
	return true


func _walk_target(i: int) -> Vector2:
	"""Where resident `i`'s walk goes: a store's or the raw food's spot is found as it sets off (`_store_spot`); after
	a failed walk, a spot near the place clear of everyone standing still."""
	var brain: BrainScript = _brains[i]
	if _step[i] == WALK_STORE or _step[i] == WALK_RAW:
		return _store_spot(i, brain)
	if _fails[i] > 0:
		return PlacesScript.spot_near(brain.space(), brain.space().bounds, _target[i], _target[i], brain.position,
			[brain])
	return _target[i]


func _store_spot(i: int, brain: BrainScript) -> Vector2:
	"""Resident `i`'s spot at the store it walks to: the nearest clear one -- and after a failed walk, clear of everyone
	standing still too (decision 0421: a raw eater now stands at its store real seconds, so a second one can find the
	first eating at its spot; it tries again at a free one). Kept in `_target`."""
	var at: Vector2 = pantry.storage.position_of(_location[i])
	var clear: Array[RefCounted] = []
	if _fails[i] > 0:
		clear.append(brain)
	_target[i] = PlacesScript.spot_near(brain.space(), brain.space().bounds, at, at, brain.position, clear)
	return _target[i]


func _carries(i: int) -> bool:
	"""Whether resident `i` walks loaded: a cook with food or the pot, a drawer with water."""
	if _role[i] == ROLE_COOK:
		return _pot_in_hand or _food_in_hand()
	return _role[i] == ROLE_DRAW and _water[i] > 0


func called_away(i: int, task: TaskScript) -> void:
	"""Resident `i` was taken off its part (see INTERRUPTION); a walk given up counts towards MAX_FAILS."""
	if _tasks[i] != task:
		return
	var walking: bool = _step[i] > STEP_DONE and _step[i] < WORK_FIRST and _issued[i] == 1
	var failed_at: int = _step[i]
	var fails: int = _fails[i] + (1 if walking else 0)
	if walking and _raw_take[i] > 0 and _brains[i].trip_failed() and fails < MAX_FAILS:
		_hold_raw_meal(i, fails)
		return
	_clear_role(i)
	_fails[i] = fails
	if fails >= MAX_FAILS:
		_give_up_walk(i, failed_at)
	revision += 1


func _hold_raw_meal(i: int, fails: int) -> void:
	"""Resident `i`'s walk to its raw meal was given up (blocked, not an order): the meal stays reserved and it sets
	off again once free and RESEND_TICKS have passed (`_retry_raw_meals`), up to MAX_FAILS walks. A raw meal comes
	after the serving's end, when no call repeats it, and since decision 0421 a raw eater stands at its store real
	seconds, so two can block each other's way."""
	_raw_retry[i] = 1
	_sent_tick[i] = calendar.tick
	_fails[i] = fails
	_reset_part(i)
	revision += 1


func _retry_raw_meals() -> void:
	"""Each raw meal held after a failed walk sets off again once its resident is free (an order or a job of its own
	is waited out); one gone to bed, or that may not be taken when free (the water, an emergency), is given up -- it
	went without, its food given back."""
	for i: int in _raw_retry.size():
		if _raw_retry[i] == 1 and _gone_to_bed(i):
			_clear_role(i)
			continue
		if _raw_retry[i] == 0 or _brains[i].order != BrainScript.ORDER_NONE \
				or calendar.tick - _sent_tick[i] < RESEND_TICKS:
			continue
		_raw_retry[i] = 0
		if _raw_take[i] > 0 and _may_take(i):
			_start_role(i, ROLE_EAT, true)
		else:
			_clear_role(i)


func _gone_to_bed(i: int) -> bool:
	"""Whether resident `i` has been taken to bed: resting through the night (the night routine sets it for everyone,
	sleep task or not). A raw meal held from the evening is not eaten in the night, even by the cook up early."""
	return _brains[i].resting


func _give_up_walk(i: int, step: int) -> void:
	"""Resident `i` could not get to its place MAX_FAILS times: the food still waiting at that store is let go for the
	meals (re-reserved at the next hour; what was already fetched stays), a drawer's trip and a diner's seat are
	dropped."""
	_fails[i] = 0
	if step == WALK_STORE:
		for s: int in _slot_order:
			takes.release_at_store(pantry, _slot_take[s], _location[i])
		_say(Words.unreachable_line(_names[i], pantry.storage.label_of(_location[i])))
	elif step == WALK_WELL:
		_draw_amount[i] = 0


func part_over(i: int, task: TaskScript) -> void:
	"""Resident `i`'s part ended on its own."""
	if _tasks[i] == task:
		_clear_role(i)
		if i == cook and not _food_in_hand() and not _pot_in_hand:
			cook = NOBODY
		revision += 1


func unfinished_of(i: int, role: int) -> RefCounted:
	"""What resident `i` comes back to once its other work is done: its cook's round, or its trip with water."""
	if role == ROLE_COOK:
		return UnfinishedScript.new(_take_back_cook, Words.ROUND_LABEL)
	if role == ROLE_DRAW and (_water[i] > 0 or _draw_amount[i] > 0):
		return UnfinishedScript.new(_take_back_draw, Words.DRAW_LABEL)
	return null


func _take_back_cook(brain: RefCounted) -> bool:
	"""Back to the cook's round, if it is still this resident's and there is work in it."""
	var i: int = (brain as BrainScript).index
	if (cook != NOBODY and cook != i) or _holder(ROLE_COOK) >= 0 or not cook_has_work():
		return false
	cook = i
	_start_role(i, ROLE_COOK)
	return true


func _take_back_draw(brain: RefCounted) -> bool:
	"""Back to the trip for water, if it still has some to carry or draw."""
	var i: int = (brain as BrainScript).index
	if _role[i] != ROLE_NONE or (_water[i] == 0 and _draw_amount[i] == 0):
		return false
	if _water[i] == 0:
		_draw_amount[i] = _draw_load(i, water_wanted() - stores.water_milli_u - water_on_the_way())
		if _draw_amount[i] <= 0:
			return false
	_start_role(i, ROLE_DRAW)
	return true


func _advance(i: int) -> void:
	"""Resident `i` finished a step: on to the next one its part needs (see the role's `_next_*`)."""
	_issued[i] = 0
	_at_work[i] = 0
	_mwu[i] = 0
	_need[i] = 0
	match _role[i]:
		ROLE_COOK:
			_cook_next(i)
		ROLE_DRAW:
			_draw_next(i)
		ROLE_EAT:
			_eat_next(i)
		_:
			_step[i] = STEP_DONE
	revision += 1


func _walk(i: int, step: int, target: Vector2) -> void:
	"""Resident `i`'s next step is a walk to `target`."""
	_step[i] = step
	_target[i] = target


func _work(i: int, step: int, need_mwu: int, face: Vector2) -> void:
	"""Resident `i`'s next step is work of `need_mwu` milli-WU facing `face`."""
	_step[i] = step
	_need[i] = need_mwu
	_face[i] = face


func _go_or_work(i: int, place: int, walk: int, at: Vector2, work: int, need_mwu: int, face: Vector2) -> void:
	"""At `place`: the work; elsewhere: the walk there first."""
	if _place[i] == place:
		_work(i, work, need_mwu, face)
	else:
		_walk(i, walk, at)


func must_finish(i: int) -> bool:
	"""Whether the night lets resident `i` finish first (kitchen_task.gd `urgent`): a load being delivered, a portion
	already being eaten (12 WU, a fifth of an hour), or a raw emergency meal under way (REQ-SET-013: the hungry)."""
	if _role[i] == ROLE_EAT and (_raw_take[i] > 0 or (_step[i] == WORK_EAT and _at_work[i] == 1)):
		return true
	return delivering(i)


func delivering(i: int) -> bool:
	"""Whether resident `i` is carrying a load to where it goes: the cook with food or the pot, a drawer with
	water."""
	if _role[i] == ROLE_COOK:
		return _food_in_hand() or _pot_in_hand
	return _role[i] == ROLE_DRAW and _water[i] > 0


func _off_hours(i: int) -> bool:
	"""Whether it is resident `i`'s night (resting and not up early): it only delivers what it carries."""
	return _brains[i].resting and not up_early(i)


func _cook_next(i: int) -> void:
	"""The cook's round, in order: put down food in hand, carry the pot, take the pot up once a meal is cooked, cook
	what may be cooked, eat a meal waiting at the table before setting off, fetch.
	At night (not up early) it only delivers what it carries."""
	if _off_hours(i) and not _food_in_hand() and not _pot_in_hand:
		_step[i] = STEP_DONE
	elif _portion[i] != FREE:
		_work(i, WORK_EAT, Rules.EAT_MWU, _face_of_seat(i))
	elif _food_in_hand():
		_cook_carry_food(i)
	elif _place[i] == PLACE_STORE and _fetch_here(_location[i]):
		_work(i, WORK_PICK, Rules.HANDLE_MWU, pantry.storage.position_of(_location[i]))
	elif _pot_in_hand:
		_go_or_work(i, PLACE_TABLE, WALK_TABLE, places.stand_table, WORK_PUT_OUT, Rules.HANDLE_MWU, places.table)
	elif _wip_key == FREE and store.in_pot() > 0:
		_cook_take_pot(i)
	elif _wip_key != FREE or can_start_batch():
		_go_or_work(i, PLACE_KITCHEN, WALK_KITCHEN, places.stand_cauldron, WORK_COOK, 0, places.cauldron)
	elif _cook_meal_to_eat(i) != FREE:
		_cook_eat(i, _cook_meal_to_eat(i))
	elif _fetch_location() >= 0:
		_cook_fetch(i)
	else:
		_step[i] = STEP_DONE


func _cook_carry_food(i: int) -> void:
	"""Food in hand: more of the meals' food at this store is picked up too; then to the cauldron to put it down (a
	second store is a trip of its own)."""
	if _place[i] == PLACE_STORE and _fetch_here(_location[i]):
		_work(i, WORK_PICK, Rules.HANDLE_MWU, pantry.storage.position_of(_location[i]))
		return
	_go_or_work(i, PLACE_KITCHEN, WALK_KITCHEN, places.stand_cauldron, WORK_PUT_DOWN, Rules.HANDLE_MWU, places.cauldron)


func _cook_take_pot(i: int) -> void:
	"""The pot holds portions and no batch is cooking: at the cauldron the cook takes it up -- each meal goes out to the
	table as soon as it is cooked."""
	if _place[i] != PLACE_KITCHEN:
		_walk(i, WALK_KITCHEN, places.stand_cauldron)
		return
	_pot_in_hand = true
	_walk(i, WALK_TABLE, places.stand_table)


func _cook_fetch(i: int) -> void:
	"""To the store holding the meals' food (or, there already, pick it up)."""
	var at: int = _fetch_location()
	if _place[i] == PLACE_STORE and _location[i] == at:
		_work(i, WORK_PICK, Rules.HANDLE_MWU, pantry.storage.position_of(at))
		return
	_location[i] = at
	_walk(i, WALK_STORE, pantry.storage.position_of(at))


func _fetch_location() -> int:
	"""A store where a planned meal's reserved food still waits (-1: none)."""
	for s: int in _slots_by_key():
		var at: int = takes.store_to_fetch(pantry, _slot_take[s])
		if at >= 0:
			return at
	return FREE


func _fetch_here(location: int) -> bool:
	"""Whether a planned meal's food still waits at `location`."""
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE and takes.store_to_fetch(pantry, _slot_take[s]) == location:
			return true
	return false


func _food_in_hand() -> bool:
	"""Whether the cook carries food (a planned meal's, or the larder's)."""
	if takes.live_milli(pantry, _larder_take, TakesScript.IN_HAND) > 0:
		return true
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE and takes.live_milli(pantry, _slot_take[s], TakesScript.IN_HAND) > 0:
			return true
	return false


func _cook_meal_to_eat(i: int) -> int:
	"""The meal the cook eats now: the one being served; or -- about to set off to fetch while breakfast is being
	served -- today's supper, already cooked and at the table (the cook will be away at supper's call). FREE: none."""
	if _serving != FREE and not fed.had(i, _serving) and store.available(_serving) > 0:
		return _serving
	if _serving == FREE or _serving % 2 != Rules.MEAL_BREAKFAST or _fetch_location() < 0:
		return FREE
	var supper: int = _serving + 1
	return supper if not fed.had(i, supper) and store.out_for(supper) > 0 else FREE


func _cook_eat(i: int, key: int) -> void:
	"""The cook eats meal `key`: its portion reserved now (so diners waiting cannot take it on the way, and it never
	waits at a table), eaten standing at the table where it put the pot down, or at a seat when it is elsewhere."""
	_meal[i] = key
	_portion[i] = store.reserve_one(key, key != _serving)
	if _portion[i] == FREE:
		_step[i] = STEP_DONE
	elif _place[i] == PLACE_TABLE:
		_work(i, WORK_EAT, Rules.EAT_MWU, places.table)
	else:
		_seat[i] = _free_seat() if _seat[i] == FREE else _seat[i]
		_walk(i, WALK_SEAT, places.seats[_seat[i]] if _seat[i] >= 0 else places.stand_table)


func _seat_for(i: int, key: int) -> void:
	"""Resident `i` sits down for meal `key`: to its seat, then waiting for (or taking) a portion."""
	_meal[i] = key
	if _seat[i] == FREE:
		_seat[i] = _free_seat()
	var at: Vector2 = places.seats[_seat[i]] if _seat[i] >= 0 else places.stand_table
	var face: Vector2 = places.seat_face[_seat[i]] if _seat[i] >= 0 else places.table
	_go_or_work(i, PLACE_SEAT, WALK_SEAT, at, WORK_WAIT, 0, face)


func _free_seat() -> int:
	"""A seat nobody else at the meal holds (FREE: none left)."""
	for k: int in places.seats.size():
		if _seat.find(k) < 0:
			return k
	return FREE


func _draw_next(i: int) -> void:
	"""A drawer: to the well and draw, then carry it to the butt and pour."""
	if _water[i] > 0:
		_go_or_work(i, PLACE_BUTT, WALK_BUTT, places.stand_butt, WORK_POUR, Rules.HANDLE_MWU, places.butt)
	elif _draw_amount[i] > 0 and not _off_hours(i):
		_go_or_work(i, PLACE_WELL, WALK_WELL, places.stand_well, WORK_DRAW,
			_draw_amount[i] * Rules.DRAW_MWU_PER_MILLI, places.well)
	else:
		_step[i] = STEP_DONE


func _eat_next(i: int) -> void:
	"""A diner: to its seat and wait, eat the portion it took; or eat raw where the food is; then done."""
	if _portion[i] != FREE:
		_work(i, WORK_EAT, Rules.EAT_MWU, _face_of_seat(i))
	elif _raw_take[i] > 0:
		var at: Vector2 = pantry.storage.position_of(_location[i])
		_go_or_work(i, PLACE_RAW, WALK_RAW, at, WORK_EAT_RAW, Rules.EAT_MWU, at)
	elif fed.had(i, _meal[i]):
		_step[i] = STEP_DONE
	else:
		_seat_for(i, _meal[i])


func _face_of_seat(i: int) -> Vector2:
	"""What resident `i` faces at its seat (or standing at the table): its table."""
	return places.seat_face[_seat[i]] if _seat[i] >= 0 else places.table


# --- work done ----------------------------------------------------------------------------------------

func _credit_work(tick: int) -> void:
	"""Every resident standing at its work is credited the calendar ticks since it was last (see THE WORK RATE)."""
	for i: int in _role.size():
		if _role[i] == ROLE_NONE or _at_work[i] == 0 or _step[i] < WORK_FIRST:
			continue
		var ticks: int = tick - _credited[i]
		_credited[i] = tick
		if ticks <= 0 or _step[i] == WORK_WAIT:
			continue
		if _step[i] == WORK_COOK:
			_cook_work(i, ticks)
			continue
		_mwu[i] += ticks * Rules.MWU_PER_TICK
		if _mwu[i] >= _need[i]:
			_complete(i)


func _complete(i: int) -> void:
	"""Resident `i`'s work is done: its effect, once, then its next step."""
	match _step[i]:
		WORK_PICK:
			for s: int in MAX_SLOTS:
				if _slot_key[s] != FREE:
					takes.pick_up(pantry, _slot_take[s], _location[i])
		WORK_PUT_DOWN:
			takes.put_down(_larder_take)
			for s: int in MAX_SLOTS:
				if _slot_key[s] != FREE:
					takes.put_down(_slot_take[s])
		WORK_PUT_OUT:
			_put_out()
		WORK_DRAW:
			_water[i] = _draw_amount[i]
			_draw_amount[i] = 0
		WORK_POUR:
			poured_water_milli += stores.add_water(_water[i])
			_water[i] = 0
		WORK_EAT:
			_eat_portion(i)
		WORK_EAT_RAW:
			_eat_raw(i)
	_advance(i)


func _put_out() -> void:
	"""The pot at the table: its portions are out."""
	var portions: int = store.carry_out()
	_pot_in_hand = false
	if portions > 0:
		_say(Words.out_line(portions, _serving))


func _eat_portion(i: int) -> void:
	"""Resident `i` finishes its portion (REQ-SET-095: its NP, its history, once)."""
	var dish: int = store.consume_one(_portion[i])
	_portion[i] = FREE
	if dish == Rules.NO_DISH:
		return
	fed.ate_meal(i, _meal[i], dish, _hour_seen)
	portions_eaten += 1
	if _meal[i] > _closed_key:
		_ate_by_meal[_meal[i]] = int(_ate_by_meal.get(_meal[i], 0)) + 1
	_seat[i] = FREE
	if _incidents != null:
		_incidents.resolve(INCIDENT_KEY)


func _eat_raw(i: int) -> void:
	"""Resident `i` finishes its raw emergency meal: the food withdrawn from its lot, its NP."""
	var milli: int = takes.live_milli(pantry, _raw_take[i], TakesScript.AT_STORE)
	if milli > 0 and takes.consume_into(pantry, _raw_take[i], milli, TakesScript.AT_STORE, _hour_seen, _read):
		fed.ate_raw(i, _meal[i], _raw_np[i])
		raw_eaten_milli += milli
		if _meal[i] > _closed_key:
			_raw_by_meal[_meal[i]] = int(_raw_by_meal.get(_meal[i], 0)) + 1
		_say(Words.raw_line(_names[i], milli, _raw_item[i], _meal[i]))
	elif _meal[i] <= _closed_key:
		_served_but_missed(i)
	takes.release(_raw_take[i])
	_raw_take[i] = 0


func _watch_tables() -> void:
	"""Seated diners waiting take a portion as soon as one is out for their meal; with nothing planned to cook for it
	any more, they get up and go."""
	for i: int in _role.size():
		if _step[i] != WORK_WAIT or _at_work[i] == 0 or _portion[i] != FREE:
			continue
		var lot: int = store.reserve_one(_meal[i], _serving == FREE or _meal[i] > _serving)
		if lot != FREE:
			_portion[i] = lot
			_advance(i)
		elif not meal_coming(_meal[i]) and not _coming(_meal[i]):
			_stop_waiting(i)


# --- the meals' calls ---------------------------------------------------------------------------------

func _open_meal(key: int) -> void:
	"""A meal is called (see THE DINERS); with nothing to serve and nothing coming, the incident says why."""
	_serving = key
	_called.fill(FREE)
	if store.available(key) + store.in_pot(key) > 0:
		return
	var said: Decision = decide_meal()
	if said.ok() and _coming(key):
		return
	if _incidents != null and not said.ok():
		_incidents.report(INCIDENT_KEY, NoticesScript.SOURCE_CREW, IncidentsScript.SEVERITY_WARNING,
			Words.no_meal_line(key, said.reason, said.fix), Words.no_meal_short(key))


func _coming(key: int) -> bool:
	"""Whether a planned meal up to `key` has a batch to cook (reserved, in progress or cooked): a diner already
	seated waits for it; with none, it gets up and goes (`_watch_tables`)."""
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE and _slot_key[s] <= key and _reserved_batches(s) + _wip_on(s) > 0:
			return true
	return false


func _close_meal(key: int) -> void:
	"""A meal's serving ends: the hungry without food eat raw if they can, the rest go without -- one who ate a later
	meal early (the cook's supper before it set off) went without this one too; the feed tallies it."""
	if _serving != key:
		return
	_serving = FREE
	var without: int = 0
	for i: int in _role.size():
		if fed.had_exact(i, key) or _portion[i] != FREE:
			continue
		if fed.had(i, key):
			fed.skipped[i] += 1
			without += 1
		elif not _raw_meal(i, key):
			fed.missed(i, key)
			_stop_waiting(i)
			without += 1
	_closed_key = key
	_record_meal(key, without)


func _stop_waiting(i: int) -> void:
	"""Resident `i`, waiting at a table for a meal with nothing for it, gives up its seat and goes."""
	if _step[i] == WORK_WAIT or _step[i] == WALK_SEAT:
		_seat[i] = FREE
		_step[i] = STEP_DONE


func _record_meal(key: int, without: int) -> void:
	"""Meal `key`'s tally at its end: who ate (with those holding their portion or raw food then, as served), who
	went without; said in the news."""
	meal_keys.append(key)
	meal_ate.append(int(_ate_by_meal.get(key, 0)) + _holding(key, false))
	meal_raw.append(int(_raw_by_meal.get(key, 0)) + _holding(key, true))
	_ate_by_meal.erase(key)
	_raw_by_meal.erase(key)
	meal_without.append(without)
	_say(Words.tally_line(key, meal_ate[meal_ate.size() - 1] + meal_raw[meal_raw.size() - 1], without), without > 0)
	if meal_keys.size() > MAX_MEAL_LOG:
		for column: PackedInt32Array in [meal_keys, meal_ate, meal_raw, meal_without]:
			column.remove_at(0)


func _holding(key: int, raw: bool) -> int:
	"""How many residents hold food for meal `key` not yet eaten: raw food with `raw`, else a portion."""
	var n: int = 0
	for i: int in _role.size():
		if _meal[i] == key and ((_raw_take[i] > 0) if raw else (_portion[i] != FREE)):
			n += 1
	return n


func _raw_meal(i: int, key: int) -> bool:
	"""At meal `key`'s end, resident `i` -- hungry, free to be called or at the table, and raw-edible food there --
	goes to eat raw (REQ-SET-013). False when it does not."""
	if fed.hunger[i] > Rules.URGENT_AT or not _may_take(i) or _role[i] == ROLE_DRAW \
			or (_role[i] == ROLE_COOK and delivering(i)):
		return false
	_clear_role(i)
	_meal[i] = key
	if not _reserve_raw(i):
		return false
	_start_role(i, ROLE_EAT, true)
	return true


func _reserve_raw(i: int) -> bool:
	"""Reserve resident `i`'s raw emergency meal (REQ-SET-013): the raw-edible lot nobody reserved that spoils first,
	enough for at most RAW_NP_CAP. False when there is none."""
	var best: int = FREE
	for lot: int in PantryScript.MAX_LOTS:
		var item: int = pantry.lot_item(lot)
		if item == PantryScript.FREE or Rules.raw_np_per_u(item) == 0 or takes.free_milli(pantry, lot) <= 0:
			continue
		if best == FREE or pantry.lot_spoil_hours(lot, _hour_seen) < pantry.lot_spoil_hours(best, _hour_seen):
			best = lot
	if best == FREE:
		return false
	var item: int = pantry.lot_item(best)
	var np_per_u: int = Rules.raw_np_per_u(item)
	_raw_take[i] = takes.new_take()
	var milli: int = takes.reserve_lot(pantry, _raw_take[i], best, Rules.RAW_NP_CAP * Rules.MILLI_PER_U / np_per_u)
	if milli <= 0:
		takes.release(_raw_take[i])
		_raw_take[i] = 0
		return false
	_raw_np[i] = milli * np_per_u / Rules.MILLI_PER_U
	_raw_item[i] = item
	_location[i] = pantry.lot_location(best)
	return true


# --- hand-outs ----------------------------------------------------------------------------------------

func _hand_out() -> void:
	"""Give the round to the cook, call free diners to the meal, and water trips to whoever is free and not due at
	the table."""
	_retry_raw_meals()
	_hand_cook()
	_call_diners()
	_hand_draws()


func cook_has_work() -> bool:
	"""Whether the cook's round has anything in it now (see `_cook_next`)."""
	return _food_in_hand() or _pot_in_hand or _wip_key != FREE or can_start_batch() or store.in_pot() > 0 \
			or _fetch_location() >= 0


func _hand_cook() -> void:
	"""The round to the cook, when it has work and nobody is on it."""
	if _holder(ROLE_COOK) >= 0 or not cook_has_work():
		return
	var who: int = _cook_choice()
	if who >= 0:
		cook = who
		_start_role(who, ROLE_COOK)


func _cook_choice() -> int:
	"""Who does the round now: the cook (or the village cook) when free; with a meal soon and neither free, the
	nearest free resident stands in -- unless the cook has the food or the pot in hand (NOBODY: nobody now)."""
	var mine: int = cook if cook != NOBODY else designated
	if mine != NOBODY and _free_for(mine):
		return mine
	if _food_in_hand() or _pot_in_hand or not _meal_soon():
		return NOBODY
	return _nearest_free(places.cauldron, NOBODY)


func _meal_soon() -> bool:
	"""Whether a meal is being served, or called within STAND_IN_HOURS."""
	var earliest: int = _earliest_key()
	return _serving != FREE or (earliest != FREE and _ends_at(earliest) - _hour_seen
			<= Rules.END_HOUR[earliest % 2] - Rules.CALL_HOUR[earliest % 2] + STAND_IN_HOURS)


func up_early(i: int) -> bool:
	"""Whether resident `i` is up before dawn: the cook, from COOK_RISE_HOUR, with today's meals to get cooked -- work
	in its round, or food at the cauldron waiting for water it may draw itself (the night routine's early riser)."""
	var hour: int = _hour_seen % SimClock.HOURS_PER_DAY
	if hour < Rules.COOK_RISE_HOUR or hour >= NightScript.DAWN_HOUR:
		return false
	return _on_duty(i)


func _free_for(i: int) -> bool:
	"""Whether resident `i` may be handed kitchen work now: on its own, out of the water, not on a crossing, and not
	resting (unless up early)."""
	var brain: BrainScript = _brains[i]
	if brain.order != BrainScript.ORDER_NONE or brain.water_hold or brain.in_water or _role[i] != ROLE_NONE \
			or _raw_retry[i] == 1:
		return false
	return brain.state != BrainScript.State.CROSS and (not brain.resting or up_early(i))


func _nearest_free(to: Vector2, except: int, not_due: bool = false) -> int:
	"""The free resident nearest `to` (NOBODY: none) -- with `not_due`, none due at the table (a meal on its way that
	it has not had)."""
	var best: int = NOBODY
	for i: int in _brains.size():
		if i == except or not _free_for(i) or (not_due and _due_to_eat(i)):
			continue
		if best == NOBODY or _brains[i].surface_point().distance_squared_to(to) \
				< _brains[best].surface_point().distance_squared_to(to):
			best = i
	return best


func _due_to_eat(i: int) -> bool:
	"""Whether resident `i` is due at the table: a meal being served and on its way that it has not had."""
	return _serving != FREE and not fed.had(i, _serving) and meal_coming(_serving)


func kept_for_meals(i: int) -> bool:
	"""Whether resident `i` is kept for the meals now, so the work board claims nothing for it (work_board.gd
	`set_needs_gate`, decision 0411 with 0381): it has a kitchen part (cooking, drawing water, at the table), it is
	due at the table (a meal on its way that it has not had: the kitchen calls it as soon as it is free), or it is
	the cook with a meal still to get to the table (the kitchen hands it the round as soon as it is free), or its
	raw meal is held to set off again (`_hold_raw_meal`)."""
	if i < 0 or i >= _role.size():
		return false
	return _role[i] != ROLE_NONE or _raw_retry[i] == 1 or _due_to_eat(i) or _on_duty(i)


func _holder(role: int) -> int:
	"""Who has `role` now (NOBODY: nobody)."""
	return _role.find(role)


func water_needed() -> int:
	"""Water the planned meals' reserved batches will take (milli-U, at most the butt's size)."""
	var total: int = 0
	for s: int in MAX_SLOTS:
		if _slot_key[s] != FREE:
			total += _reserved_batches(s) * Rules.WATER_MILLI[_slot_dish[s]]
	return mini(total, StoresScript.WATER_CAP_MILLI_U)


func water_wanted() -> int:
	"""What KEEP WATER DRAWN keeps in the butt: full (a maintained stock, REQ-SET-097's MAINTAIN_STOCK) -- or nothing
	when it is off."""
	return StoresScript.WATER_CAP_MILLI_U if keep_water else 0


func water_on_the_way() -> int:
	"""Water being drawn or carried to the butt (milli-U): in hand, and the loads drawers are out for."""
	var total: int = 0
	for i: int in _role.size():
		total += _water[i] + (_draw_amount[i] if _role[i] == ROLE_DRAW else 0)
	return total


func _hand_draws() -> void:
	"""Water trips: a drawer with water in hand goes on with it; while water is wanted (KEEP WATER DRAWN, or the
	player's queued draws) the nearest free resident to the well goes for a carry of it."""
	for i: int in _role.size():
		if _role[i] == ROLE_NONE and _water[i] > 0 and _free_for(i):
			_start_role(i, ROLE_DRAW)
	var short: int = water_wanted() - stores.water_milli_u - water_on_the_way()
	while (short > 0 or _queued_draws > 0) and _count_role(ROLE_DRAW) < MAX_DRAWERS:
		var who: int = _nearest_free(places.well, NOBODY, true)
		var amount: int = _draw_load(who, maxi(short, 1))
		if who < 0 or amount <= 0:
			return
		_draw_amount[who] = amount
		_queued_draws = maxi(0, _queued_draws - 1)
		short -= amount
		_start_role(who, ROLE_DRAW)


func _draw_load(who: int, wanted: int) -> int:
	"""How much resident `who` draws: what is wanted (a queued draw: a full carry), at most its carry and the butt's
	room not already on the way (0: none)."""
	if who < 0:
		return 0
	var carry: int = Rules.CARRY_G[fed.size_class[who]]
	var room: int = stores.water_room() - water_on_the_way()
	return mini(room, carry if _queued_draws > 0 else mini(wanted, carry))


func _count_role(role: int) -> int:
	"""How many residents have `role`."""
	return _role.count(role)


func _call_diners() -> void:
	"""During a meal, once it is on its way (`meal_coming`): call everyone not called yet (parking their work), and
	anyone free who has not eaten."""
	if _serving == FREE or not meal_coming(_serving):
		return
	for i: int in _brains.size():
		if (_role[i] != ROLE_NONE and _role[i] != ROLE_DRAW) or fed.had(i, _serving) or not _may_call(i):
			continue
		var first: bool = _called[i] != _serving
		if first or (_brains[i].order == BrainScript.ORDER_NONE and calendar.tick - _sent_tick[i] >= RESEND_TICKS):
			_called[i] = _serving
			_sent_tick[i] = calendar.tick
			_clear_role(i)
			_meal[i] = _serving
			_start_role(i, ROLE_EAT, true)
			if _announced != _serving:
				_announced = _serving
				_say(Words.call_line(_serving))


func meal_coming(key: int) -> bool:
	"""Whether meal `key`'s food is at the table or on its way there: portions out for it, or in the pot, or a batch
	cooking. Until then nobody is called to sit and wait (the drawers and the village keep working)."""
	return store.available(key) > 0 or store.in_pot(key) > 0 or (_wip_key != FREE and _wip_key <= key)


func _on_duty(i: int) -> bool:
	"""Whether resident `i` is the cook with a meal still to get to the table: work in its round, or food put down at
	the cauldron waiting for water or fuel."""
	if i != (cook if cook != NOBODY else designated):
		return false
	if _duty_tick != calendar.tick:
		_duty_tick = calendar.tick
		_duty = cook_has_work() or _food_at_cauldron()
	return _duty


func _food_at_cauldron() -> bool:
	"""Whether a planned meal whose cooking time has come (or ordered now) has food put down at the cauldron. Food
	fetched ahead for a later meal does not keep the cook on duty: between breakfast and supper's cooking (decision
	0421's hours do not overlap) it is a diner like the rest."""
	for s: int in _slot_order:
		if _cook_time_come(s) and takes.live_milli(pantry, _slot_take[s], TakesScript.AT_KITCHEN) > 0:
			return true
	return false


func _may_call(i: int) -> bool:
	"""Whether resident `i` may be called to the table: `_may_take`, and not the cook while it is on duty."""
	return _may_take(i) and not _on_duty(i)


func _may_take(i: int) -> bool:
	"""Whether resident `i` may be taken off what it does for a meal: not in the water, an emergency or bed, and not
	carrying a load (a harvest, logs: decision 0222's rule, a load in hand is delivered first)."""
	var brain: BrainScript = _brains[i]
	if brain.water_hold or brain.in_water or brain.state == BrainScript.State.CROSS or brain.resting or brain.carrying:
		return false
	return not (brain.task is SleepTaskScript or (brain.task != null and brain.task.urgent()))


# --- orders and their decisions (the cards read the same) ---------------------------------------------

func decide_meal(members: PackedInt32Array = PackedInt32Array()) -> Decision:
	"""The next meal: what it takes and has, and whether it can be cooked -- the Cook order's, its card's and the
	shortage reports' one answer (see SHORTAGES)."""
	var d := Decision.new()
	var s: int = _slot_index_of(_earliest_key())
	if s < 0:
		return d.refuse(NOTHING_TO_COOK, Words.NOTHING_PLANNED, "")
	_fill_needs(d, s)
	if d.batches == 0 and _wip_key == FREE:
		return d.refuse(NOTHING_TO_COOK, Words.enough_reason(d.meal_key), "")
	var short: int = _short_input(d)
	if short == 0 and _wip_key == FREE:
		return d.refuse(NO_FOOD, Words.no_food_reason(d.dish, _free_batches(Rules.other(d.dish)) > 0), Words.FIX_FOOD)
	if short > 0 and _wip_key == FREE:
		return d.refuse(NO_FOOD, Words.no_side_reason(d.dish, short, d.input_have[short]), Words.FIX_FOOD)
	if not keep_water and d.water_have + water_on_the_way() < Rules.WATER_MILLI[d.dish]:
		return d.refuse(NO_WATER, Words.no_water_reason(d.dish, d.water_have, d.water_need), Words.FIX_WATER)
	if d.wood_have < Rules.WOOD_MILLI_PER_BATCH:
		return d.refuse(NO_FUEL, Words.no_fuel_reason(d.wood_have, d.wood_need), Words.FIX_FUEL)
	_pick_cook(d, members)
	if d.worker < 0:
		return d.refuse(NO_COOK, Words.NO_COOK_REASON, Words.FIX_COOK)
	return d


func _fill_needs(d: Decision, s: int) -> void:
	"""Decision `d` for slot `s`'s meal: its dish, the batches left, and the food, water and wood had and needed."""
	d.meal_key = _slot_key[s]
	d.dish = _slot_dish[s]
	d.batches = maxi(0, _slot_wanted[s] - _slot_cooked[s] - _wip_on(s))
	d.input_have.resize(Rules.INPUT_N[d.dish])
	d.input_need.resize(Rules.INPUT_N[d.dish])
	for k: int in Rules.INPUT_N[d.dish]:
		var selector: int = Rules.input_selector(d.dish, k)
		d.input_need[k] = d.batches * Rules.input_milli(d.dish, k)
		d.input_have[k] = takes.live_milli(pantry, _slot_take[s], -1, selector) + _free_of(selector)
	d.water_need = d.batches * Rules.WATER_MILLI[d.dish]
	d.water_have = stores.water_milli_u
	d.wood_need = d.batches * Rules.WOOD_MILLI_PER_BATCH
	d.wood_have = stores.wood_milli_u


func _short_input(d: Decision) -> int:
	"""The first of decision `d`'s inputs short of a batch (-1: none)."""
	for k: int in d.input_have.size():
		if d.input_have[k] < Rules.input_milli(d.dish, k):
			return k
	return -1


func _pick_cook(d: Decision, members: PackedInt32Array) -> void:
	"""Who cooks: the nearest selected resident (a direct order), else the cook already on it, else the cook or the
	village cook (queued: whoever is free first), else a stand-in."""
	var on_it: int = _holder(ROLE_COOK)
	var picked: int = _nearest_of(members, places.cauldron)
	if picked >= 0:
		d.worker = picked
		d.who = Words.assign_selected(_names[picked], members.size())
	elif on_it >= 0:
		d.worker = on_it
		d.who = Words.under_way(_names[on_it])
	else:
		var mine: int = cook if cook != NOBODY else designated
		d.worker = mine if mine != NOBODY else _nearest_free(places.cauldron, NOBODY)
		d.who = Words.queue_cook(_names[d.worker] if d.worker >= 0 else "", d.worker == designated)


func _nearest_of(members: PackedInt32Array, to: Vector2) -> int:
	"""The member standing nearest `to` who is out of the water and not in an emergency (NOBODY: none)."""
	var best: int = NOBODY
	for i: int in members:
		var brain: BrainScript = _brains[i]
		if brain.water_hold or brain.in_water or (brain.task != null and brain.task.urgent()):
			continue
		if best == NOBODY or brain.surface_point().distance_squared_to(to) < _brains[best].surface_point().distance_squared_to(to):
			best = i
	return best


func order_cook(members: PackedInt32Array) -> String:
	"""The player's Cook: the next meal is cooked now, by the nearest selected resident (taken off what it does) or
	the cook. The answer in words (the refusal's, when refused)."""
	var d: Decision = decide_meal(members)
	if not d.ok():
		return Words.cant(d.reason, d.fix)
	_cook_now_key = d.meal_key
	var on_it: int = _holder(ROLE_COOK)
	if _nearest_of(members, places.cauldron) == d.worker and d.worker >= 0 and on_it != d.worker:
		if on_it >= 0:
			_brains[on_it].release()
		cook = d.worker
		_start_role(d.worker, ROLE_COOK)
	revision += 1
	return Words.cook_ordered(d.meal_key, d.dish, d.batches, d.who)


func decide_draw(members: PackedInt32Array) -> Decision:
	"""The Draw water order's (and its card's) answer: how much, by whom, and why not. Queued for whoever is free, it
	is at most the largest carry (the drawer's own carry when it is taken up)."""
	var d := Decision.new()
	d.water_have = stores.water_milli_u
	d.water_need = StoresScript.WATER_CAP_MILLI_U
	var room: int = stores.water_room() - water_on_the_way()
	if room <= 0:
		return d.refuse(BUTT_FULL, Words.butt_full_reason(stores.water_milli_u, water_on_the_way()), "")
	var picked: int = _nearest_of(members, places.well)
	d.worker = picked if picked >= 0 else _nearest_free(places.well, cook)
	if d.worker < 0:
		d.who = Words.QUEUE_DRAW
		d.amount = mini(room, Rules.CARRY_G[Rules.SIZE_LARGE])
		return d
	d.amount = mini(room, Rules.CARRY_G[fed.size_class[d.worker]])
	d.who = Words.assign_selected(_names[picked], members.size()) if picked >= 0 else Words.draw_by(_names[d.worker])
	return d


func order_draw(members: PackedInt32Array) -> String:
	"""The player's Draw water: the nearest selected resident goes for a carry of water (taken off what it does);
	with nobody selected, the next free resident does. The answer in words."""
	var d: Decision = decide_draw(members)
	if not d.ok():
		return Words.cant(d.reason, d.fix)
	var picked: int = _nearest_of(members, places.well)
	if picked >= 0 and _role[picked] == ROLE_NONE:
		_draw_amount[picked] = d.amount
		_start_role(picked, ROLE_DRAW)
	else:
		_queued_draws += 1
	return Words.draw_ordered(d.amount, d.who)


func preview_cook_into(card: CardScript, members: PackedInt32Array) -> void:
	"""The Cook order's action card, from `decide_meal` -- the order's own decision (decision 0332)."""
	var d: Decision = decide_meal(members)
	card.reset("Cook %s now" % Words.meal_words(d.meal_key) if d.meal_key >= 0 else "Cook the next meal now")
	if d.dish >= 0:
		card.result = "%d batches of %s: %d portions of %d NP" % [d.batches, Rules.DISH_NAMES[d.dish].to_lower(),
			d.batches * Rules.PORTIONS_PER_BATCH[d.dish], Rules.NP_PER_PORTION[d.dish]]
		for k: int in d.input_have.size():
			card.add_cost(Words.input_words(d.dish, k).capitalize(), d.input_have[k], d.input_need[k])
		card.add_cost("Water", d.water_have, d.water_need)
		card.add_cost("Wood", d.wood_have, d.wood_need)
		card.work_usec = CalendarScript.usec_for_ticks(d.batches * Rules.batch_ticks(d.dish))
		card.work_note = ", plus fetching and the walk"
	card.who = d.who
	card.worker = d.worker
	card.prerequisites = PackedStringArray(["the food fetched from the stores by the cook",
		"water in the village's butt", "0.1 U of wood a batch"])
	if not d.ok():
		card.refuse(d.code, d.reason, d.fix)


func preview_draw_into(card: CardScript, members: PackedInt32Array) -> void:
	"""The Draw water order's action card, from `decide_draw`."""
	var d: Decision = decide_draw(members)
	card.reset("Draw water at the well")
	card.result = "%s%s into the water butt by the well (it holds %s of %s)" % ["Up to " if d.worker < 0 else "",
		Words.units(d.amount), Words.units(stores.water_milli_u), Words.units(StoresScript.WATER_CAP_MILLI_U)]
	if d.amount > 0:
		card.work_usec = CalendarScript.usec_for_ticks(d.amount * Rules.DRAW_MWU_PER_MILLI / Rules.MWU_PER_TICK)
	card.who = d.who
	card.worker = d.worker
	card.prerequisites = PackedStringArray(["a resident to carry it (a mouse carries 12 U, an otter 16, the badger 24)"])
	if not d.ok():
		card.refuse(d.code, d.reason, d.fix)


func set_keep_water(on: bool) -> void:
	"""The Kitchen tab's Keep water drawn."""
	keep_water = on
	revision += 1


func _say(text: String, warning: bool = false) -> void:
	"""A line for the village news (silent with no feed)."""
	if _notices != null and not text.is_empty():
		_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, text)


# --- readouts -----------------------------------------------------------------------------------------

func role_of(i: int) -> int:
	"""Resident `i`'s part now (ROLE_*)."""
	return _role[i]


func step_of(i: int) -> int:
	"""Resident `i`'s step now (STEP_DONE, WALK_*, WORK_*)."""
	return _step[i]


func water_in_hand(i: int) -> int:
	"""Water resident `i` carries (milli-U)."""
	return _water[i]


func pot_in_hand() -> bool:
	"""Whether the cook carries the pot."""
	return _pot_in_hand


func wip_key() -> int:
	"""The meal the batch at the cauldron is for (FREE: none)."""
	return _wip_key


func wip_dish() -> int:
	"""The dish of the batch at the cauldron (Rules.NO_DISH: none)."""
	return _wip_dish if _wip_key != FREE else Rules.NO_DISH


func wip_progress() -> int:
	"""The batch at the cauldron's work done, milli-WU."""
	return _wip_mwu


func serving() -> int:
	"""The meal being served (FREE: none)."""
	return _serving


func planned_keys() -> PackedInt32Array:
	"""The planned meals' keys, earliest first."""
	var out := PackedInt32Array()
	for s: int in _slots_by_key():
		out.append(_slot_key[s])
	return out


func plan_of(key: int) -> PackedInt32Array:
	"""A planned meal's [dish, batches wanted, cooked, reserved batches, in progress] (empty: not planned)."""
	var s: int = _slot_index_of(key)
	if s < 0:
		return PackedInt32Array()
	return PackedInt32Array([_slot_dish[s], _slot_wanted[s], _slot_cooked[s], _reserved_batches(s), _wip_on(s)])


func take_of(key: int) -> int:
	"""A planned meal's take id (FREE: not planned)."""
	var s: int = _slot_index_of(key)
	return _slot_take[s] if s >= 0 else FREE


func food_in_hand() -> bool:
	"""Whether the cook carries food (see `_food_in_hand`)."""
	return _food_in_hand()


func carried_item(i: int) -> int:
	"""What resident `i` is drawn carrying: a food item (Catalog item), CARRY_POT, CARRY_WATER, or Catalog.NO_ITEM."""
	if _role[i] == ROLE_DRAW and _water[i] > 0:
		return CARRY_WATER
	if _role[i] != ROLE_COOK or _step[i] >= WORK_FIRST or _step[i] <= STEP_DONE:
		return Catalog.NO_ITEM
	if _pot_in_hand:
		return CARRY_POT
	if _carried_tick != calendar.tick or _carried_step != _step[i]:
		_carried_tick = calendar.tick
		_carried_step = _step[i]
		_carried_food = _food_item_in_hand()
	return _carried_food


func _food_item_in_hand() -> int:
	"""The first food item the cook holds: a planned meal's, else the larder's (Catalog.NO_ITEM: none)."""
	for s: int in _slot_order:
		var item: int = takes.first_item(pantry, _slot_take[s], TakesScript.IN_HAND)
		if item != Catalog.NO_ITEM:
			return item
	return takes.first_item(pantry, _larder_take, TakesScript.IN_HAND)


func doing_text(i: int) -> String:
	"""What resident `i` is doing for the kitchen, in the party panel's words."""
	return Words.doing(self, i)


func name_of(i: int) -> String:
	"""Resident `i`'s name."""
	return _names[i] if i >= 0 and i < _names.size() else ""


func meal_of(i: int) -> int:
	"""The meal resident `i` is at the table for."""
	return _meal[i]


func location_of(i: int) -> int:
	"""The store resident `i` walks to or works at."""
	return _location[i]


func raw_item_of(i: int) -> int:
	"""The item of resident `i`'s raw meal."""
	return _raw_item[i]


func hour_index() -> int:
	"""The last calendar hour the kitchen has run."""
	return _hour_seen


# --- the panels' and the HUD's readouts ----------------------------------------------------------

func fed_text(i: int, alone: bool) -> String:
	"""The party panel's line for resident `i` (demo_command.gd `add_skill_text`): alone, its fed state, fullness, NP
	today against its need, its last meal (marked when it was a favourite, decision 0601) and any monotonous memory; in a
	list, the state's word."""
	if i < 0 or i >= fed.count():
		return ""
	var state: int = fed.state_of(i)
	if not alone:
		return Rules.FED_WORDS[state]
	var winter: bool = PantryScript.season_of_hour(_hour_seen) == WINTER
	var line: String = Words.fed_line(state, fed.hunger[i], fed.today_np[i], fed.daily_need(i, winter), _last_meal_text(i))
	if fed.monotony[i] != 0 and fed.last_dish[i] != Rules.NO_DISH:
		line += "\n" + Words.monotony_line(fed.last_dish[i], fed.repeats_of(i, fed.last_dish[i]), fed.monotony[i],
			maxi(0, fed.monotony_until[i] - _hour_seen))
	return line


func _last_meal_text(i: int) -> String:
	"""'breakfast, porridge', 'supper: went without', or '' before any."""
	var key: int = fed.last_meal[i]
	if key < 0:
		return ""
	match fed.last_outcome[i]:
		FedScript.OUTCOME_ATE:
			return "%s, %s%s" % [Words.meal_words(key), Rules.DISH_SHORT[fed.last_dish[i]],
				Words.favourite_mark(fed.last_favourite[i] == 1)]
		FedScript.OUTCOME_RAW:
			return "%s: raw food" % Words.meal_words(key)
	return "%s: went without" % Words.meal_words(key)


func fed_word(i: int) -> String:
	"""Resident `i`'s fed state in a word (the Residents roster)."""
	return Rules.FED_WORDS[fed.state_of(i)] if i >= 0 and i < fed.count() else ""


func cookable_batches() -> int:
	"""Batches the pantry's food would make by THE READY-FOOD ESTIMATE, at most the wood's (water is drawn at the well
	as needed, so it does not limit)."""
	_estimate()
	var total: int = 0
	for dish: int in Rules.DISH_COUNT:
		total += _estimated[dish]
	return total


func cookable_portions() -> int:
	"""The portions `cookable_batches` cook, each dish at its own PORTIONS_PER_BATCH (a stew or a hotpot makes 3)."""
	_estimate()
	var total: int = 0
	for dish: int in Rules.DISH_COUNT:
		total += _estimated[dish] * Rules.PORTIONS_PER_BATCH[dish]
	return total


func _estimate() -> void:
	"""THE READY-FOOD ESTIMATE, into `_estimated` (batches per dish): the plain dishes (meal_rules.gd PLAIN: every input a
	whole category -- a dish naming its own ingredients cooks the same numbers from fewer) share the pantry's food by
	category, those of several inputs first (they cannot use what the others leave: the fish stew's roots before the
	soup's, never counted twice), then the rest, each in the book's order; the wood bounds the total. No allocation."""
	_pool.resize(Rules.CATEGORY_WORDS.size())
	_pool.fill(0)
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		_pool[Catalog.category_of(item)] += pantry.milli_of(item)
	_estimated.resize(Rules.DISH_COUNT)
	_estimated.fill(0)
	@warning_ignore("integer_division")
	var wood: int = stores.wood_milli_u / Rules.WOOD_MILLI_PER_BATCH
	for pass_index: int in 2:
		for dish: int in Rules.DISH_COUNT:
			if Rules.PLAIN[dish] == 1 and (Rules.INPUT_N[dish] > 1) == (pass_index == 0):
				wood -= _estimate_dish(dish, wood)


func _estimate_dish(dish: int, wood: int) -> int:
	"""Batches of plain `dish` the pooled food makes, at most `wood`; takes their food from the pool. Returns them."""
	var batches: int = wood
	for k: int in Rules.INPUT_N[dish]:
		@warning_ignore("integer_division")
		batches = mini(batches, int(_pool[Rules.input_category(dish, k)]) / Rules.input_milli(dish, k))
	batches = maxi(0, batches)
	for k: int in Rules.INPUT_N[dish]:
		_pool[Rules.input_category(dish, k)] -= batches * Rules.input_milli(dish, k)
	_estimated[dish] = batches
	return batches


func _crop_milli(crop: int) -> int:
	"""Every milli-U of crop row `crop` in the pantry, reserved or not."""
	var total: int = 0
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		if Catalog.category_of(item) == crop:
			total += pantry.milli_of(item)
	return total


func daily_portions() -> int:
	"""Portions the village eats a day: a portion a meal, two meals, every resident."""
	return 2 * _brains.size()


func days_of_meals_milli() -> int:
	"""THE HUD's Ready food (decision 0381): portions held (and the batch cooking) plus the portions the stores' food
	would cook (`cookable_portions`: each dish's own PORTIONS_PER_BATCH), over the village's daily portions -- in
	thousandths of a day."""
	var daily: int = daily_portions()
	if daily <= 0:
		return 0
	var portions: int = store.portions() + (Rules.PORTIONS_PER_BATCH[_wip_dish] if _wip_key != FREE else 0)
	return (portions + cookable_portions()) * 1000 / daily


func ledger_lines() -> PackedStringArray:
	"""What is behind the Ready food figure, for the ledger -- one line, as the shell's ledger is a fixed size: the
	portions held and the raw grain and roots ("5 portions · grain 18.0 · roots 12.0 U"; the water, wood and cook are
	the Kitchen tab's)."""
	var grain: String = Words.units(_crop_milli(Rules.INPUT_CROP[Rules.DISH_PORRIDGE]))
	var roots: String = Words.units(_crop_milli(Rules.INPUT_CROP[Rules.DISH_SOUP]))
	var fish: int = _crop_milli(Rules.INPUT_CROP[Rules.DISH_FISH_STEW])
	var line: String = "%d portions · grain %s · roots %s" % [store.portions(), grain.trim_suffix(" U"), roots]
	return PackedStringArray([line if fish == 0 else "%s · fish %s" % [line.trim_suffix(" U"), Words.units(fish)]])


func stock_rows() -> Array[PackedStringArray]:
	"""The Pantry's Stocks rows for the kitchen's own stock (ingredient, in store, incoming, store, next to spoil):
	each dish's portions as ready food, and the water."""
	var rows: Array[PackedStringArray] = []
	for dish: int in Rules.DISH_COUNT:
		var held: int = store.portions_of(dish)
		if held > 0:
			rows.append(PackedStringArray(["%s (ready food)" % Rules.DISH_NAMES[dish], "%d portions" % held, "—",
				"Kitchen (pot and table)", "spoils in %d h" % store.hours_left_of(dish, PantryScript.season_of_hour(_hour_seen))]))
	rows.append(PackedStringArray(["Water", Words.units(stores.water_milli_u), Words.units(water_on_the_way()),
		"Water butt by the well", "never spoils"]))
	return rows


func reserved_text(item: int, location: int) -> String:
	"""'2.0 U for the kitchen' -- what of `item` at `location` the kitchen reserves ('' none)."""
	var held: int = takes.with_cook_milli(pantry, item, location)
	return "%s for the kitchen" % Words.units(held) if held > 0 else ""


func days_text() -> String:
	"""The Ready food figure in words: "4.5 days of meals" (tenths, floored; never "0" for some)."""
	return Words.days_text(days_of_meals_milli())


func cookable_text(item: int) -> String:
	"""The Recipes tab's lines for a pantry item: every cookable dish that takes it, then how the cook picks among them
	("" for an item no dish takes)."""
	var lines := PackedStringArray()
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_input(dish, item):
			lines.append(Words.cookable_line(dish))
	if lines.is_empty():
		return ""
	lines.append(Words.choice_note())
	return "\n".join(lines)


func dish_of_meal(key: int) -> int:
	"""The dish meal `key` was cooked as (its first batch's; Rules.NO_DISH: none cooked)."""
	var k: int = cooked_keys.find(key)
	return cooked_dishes[k] if k >= 0 else Rules.NO_DISH


func last_meals_text(most: int) -> String:
	"""The latest `most` meals' tallies, newest first: "Supper, day 2: togget's vegetable soup — 9 ate"."""
	var lines := PackedStringArray()
	for k: int in range(meal_keys.size() - 1, maxi(-1, meal_keys.size() - 1 - most), -1):
		lines.append(Words.meal_record(meal_keys[k], dish_of_meal(meal_keys[k]), meal_ate[k], meal_raw[k], meal_without[k]))
	return "\n".join(lines)
