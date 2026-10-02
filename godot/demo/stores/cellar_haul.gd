extends RefCounted
## THE COOL CELLAR'S HAULING (decision 0611): surplus food carried from a warmer store into a cooler one -- the covered
## store's or a warm cellar's harvest down into a cool root cellar, where §5.8 ages it at 350 per mille instead of 1000.
## Presentation over the farm's pantry (farm_pantry.gd MOVING FOOD BETWEEN STORES): nothing here feeds the simulation.
##
## WHAT MOVES (the planner, every PLAN_USEC of cast time). A MOVE is one lot's food from its store into a store that ages
## it more slowly (a lower `spoilage_permille`, farm_storage.gd STORAGE CLASS) with room for it. Only SURPLUS moves: the
## food nobody has reserved (`free_of(lot)`: the kitchen's takes, ingredient_takes.gd `free_milli`), never a lot already
## carried or already planned. Of every such lot the one that spoils SOONEST where it is goes first (the very forecast
## the Pantry prints, `lot_spoil_hours`) -- the food most at risk -- unless it spoils within MIN_HOURS_LEFT, too soon
## for the walk to be worth it. Its destination is the slowest-spoiling store with room, the nearest to the lot's store
## on a tie. A move takes at most LOAD_MILLI: GDD §5.2's smallest carry (12000 g) of raw food at §5.5's 250 g a unit,
## so every resident who can carry may take it (REQ-SET-111). At most MAX_ROWS moves stand at once. A move of PART of a
## lot splits it into a new lot row, so a part is never smaller than MIN_PART_MILLI, and with every lot row taken only
## whole lots move (a split would be refused; the review's H1). One pass over the lots a plan, the moves taken from it
## soonest first. A planned move whose lot has gone or whose store has gone is closed at the next plan; a claim or a
## pick-up whose destination no longer keeps the food longer (a hearth lit near a cellar) closes the move too.
##
## WHO MOVES IT (the work board, decision 0411). A planned move WAITS on the board (work/stores_work.gd) as HAULING; the
## board claims it for an idle resident who can carry. The claim RESERVES the room at the destination (a pantry hold:
## the Pantry shows it as Incoming there) -- or, the room gone meanwhile, closes the move. Then: GO to the lot's store,
## PICK it up (`begin_carry_into`: the lot, or an exact split of it, is in hand and nobody else may take from it), CARRY
## it -- down to a cellar's middle facing its racks when the carrier can take a load below (farm_cellars.gd CARRIED IN),
## else to its hatch -- and SHELVE it (`set_down_into`: the lot changes stores with its age; §5.8 "changing stores never
## resets age"). Pick-up and shelving are the farm's put-down work (farm_jobs.gd WORK_DROP, 1 WU each).
##
## NOTHING CREDITED FROM AFAR (decisions 0222, 0361). The lot stays booked at its source until it is shelved. A carrier
## called away (another order, the night routine), a walk given up MAX_TRIES times, a cancelled move or a store gone
## puts the load back (`put_back`: it never left the books) and frees the room held; the move then waits again (called
## away) or closes (given up). A move given up -- a walk that failed MAX_TRIES times, a pick-up the pantry refused, a
## shelving with no room -- backs off the store that failed it (the lot's store, or the destination) for BACKOFF_USEC,
## so the same move is not claimed and refused over and over. Only the shelving moves food.

const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const SpotScript := preload("res://demo/stores/stand_spot.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MAX_ROWS: int = 4
## GDD §5.2's smallest carry limit and §5.5's raw-food unit mass: 48 U of raw food a trip.
const SMALL_CARRY_G: int = 12000
const RAW_FOOD_G_PER_U: int = 250
@warning_ignore("integer_division")  # whole milli-U by intent: 12000 * 1000 / 250 is exact
const LOAD_MILLI: int = SMALL_CARRY_G * 1000 / RAW_FOOD_G_PER_U
## Food that spoils within this many game hours where it is stays put (demo value; Brendan's ruling, decision 0611 P2).
const MIN_HOURS_LEFT: int = 6
## The smallest PART of a lot a move takes (a whole lot of any size may move): a split row for less is not worth its
## walk or its lot row (demo value: one unit).
const MIN_PART_MILLI: int = 1000
## How often the planner looks (cast time), and how long it leaves a store alone after a move from it was given up.
const PLAN_USEC: int = 2000000
const BACKOFF_USEC: int = 60000000
## Pick-up and shelving: the farm's put-down work at its demo rate.
const PICK_USEC: int = FarmJobs.WORK_WU[FarmJobs.WORK_DROP] * FarmJobs.DEMO_USEC_PER_WU
const SHELVE_USEC: int = PICK_USEC
const STEP_GO: int = 0
const STEP_PICK: int = 1
const STEP_CARRY: int = 2
const STEP_SHELVE: int = 3
## What a carrier is doing, in the party panel's words (`task_text`): the item, then the store.
const STEP_WORDS: Array[String] = ["Fetching %s from the %s", "Picking up %s at the %s", "Carrying %s to the %s",
	"Shelving %s in the %s"]
const NOBODY: int = -1
const NONE: int = -1
const ARRIVE_M: float = 0.4
const RING_GAP_M: float = 0.45
const MAX_TRIES: int = 3
const WORK_CLIP: StringName = &"collect_object"
const CANT_CARRY: String = "can't carry a load"
const OTHER_MOVE: String = "has another move"
const GONE_WORDS: String = "that move is no longer on the board"
const IN_HAND_WORDS: String = "the load is in hand — it is shelved first"

## The moves, one a row: the source lot (row and serial), what and how much is planned, where it goes (a store id, and
## the hold once claimed), who has it and how far it has got. `serial` is the move's own identity (a reused row is a
## different move); `carried` / `carried_serial` the lot row in hand once picked up.
var lot: PackedInt32Array = PackedInt32Array()
var lot_serial: PackedInt32Array = PackedInt32Array()
var item: PackedInt32Array = PackedInt32Array()
var milli: PackedInt64Array = PackedInt64Array()
var hold: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var step: PackedInt32Array = PackedInt32Array()
var serial: PackedInt32Array = PackedInt32Array()
var carried: PackedInt32Array = PackedInt32Array()
var carried_serial: PackedInt32Array = PackedInt32Array()
var paused: PackedByteArray = PackedByteArray()
var issued: PackedByteArray = PackedByteArray()
var below: PackedByteArray = PackedByteArray()
var tries: PackedInt32Array = PackedInt32Array()
var work_usec: PackedInt64Array = PackedInt64Array()
var goal: PackedVector2Array = PackedVector2Array()
## Each move's destination store id (followed by id, as lots and holds are).
var to_id: Array = []
## Moves shelved whole or in part, and milli-U shelved (checks and the README's figures).
var moves_done: int = 0
var shelved_milli: int = 0
var revision: int = 0

var _cast: DemoCastScript = null
var _network: GraphScript = null
var _pantry: PantryScript = null
var _goods: GoodsScript = null
var _free_of: Callable = Callable()
var _hour_of: Callable = Callable()
var _plan_usec: int = 0
var _next_serial: int = 1
## The stores backed off (see NOTHING CREDITED FROM AFAR): one a move's source failed at, one a destination; and how
## much longer each is left alone.
var _backoff_from_id: Variant = null
var _backoff_from_usec: int = 0
var _backoff_to_id: Variant = null
var _backoff_to_usec: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()
## The planner's per-store scratch, figured once a pass: each store's room less what planned moves will take there, and
## the store each one's food would move to (NONE: none).
var _room: PackedInt64Array = PackedInt64Array()
var _cooler: PackedInt32Array = PackedInt32Array()
## The plan's candidates (one pass over the lots), sized once: lot row (NONE once taken), spoil hours and free milli-U.
var _cand_lot: PackedInt32Array = PackedInt32Array()
var _cand_hours: PackedInt32Array = PackedInt32Array()
var _cand_free: PackedInt64Array = PackedInt64Array()
var _cand_count: int = 0
var _found: Vector2 = Vector2.ZERO
var _spot: PackedVector2Array = PackedVector2Array([Vector2.ZERO])


func _init() -> void:
	"""An empty board of MAX_ROWS moves (packed columns are values: each is sized by name)."""
	lot.resize(MAX_ROWS)
	lot_serial.resize(MAX_ROWS)
	item.resize(MAX_ROWS)
	hold.resize(MAX_ROWS)
	worker.resize(MAX_ROWS)
	step.resize(MAX_ROWS)
	serial.resize(MAX_ROWS)
	carried.resize(MAX_ROWS)
	carried_serial.resize(MAX_ROWS)
	tries.resize(MAX_ROWS)
	milli.resize(MAX_ROWS)
	work_usec.resize(MAX_ROWS)
	paused.resize(MAX_ROWS)
	issued.resize(MAX_ROWS)
	below.resize(MAX_ROWS)
	goal.resize(MAX_ROWS)
	to_id.resize(MAX_ROWS)
	_cand_lot.resize(PantryScript.MAX_LOTS)
	_cand_hours.resize(PantryScript.MAX_LOTS)
	_cand_free.resize(PantryScript.MAX_LOTS)
	lot.fill(NONE)
	worker.fill(NOBODY)
	hold.fill(NONE)
	carried.fill(NONE)


func configure(cast: DemoCastScript, network: GraphScript, pantry: PantryScript, free_of: Callable, hour_of: Callable,
		goods: GoodsScript = null) -> void:
	"""Move food in this pantry with this cast, into this network's cellars: `free_of(lot) -> int` is how much of a lot
	nobody has reserved (the kitchen's takes; an invalid Callable: all of it), `hour_of() -> int` the demo calendar's
	hour index, and `goods` draws the load in hand (null: nothing drawn)."""
	_cast = cast
	_network = network
	_pantry = pantry
	_free_of = free_of
	_hour_of = hour_of
	_goods = goods


# --- the board ------------------------------------------------------------------------------------

func is_live(row: int) -> bool:
	"""Whether `row` holds a move."""
	return lot[row] != NONE


func waiting(row: int) -> bool:
	"""Whether move `row` waits for a carrier and may be claimed now."""
	return is_live(row) and worker[row] == NOBODY and paused[row] == 0


func is_carrying(row: int) -> bool:
	"""Whether move `row`'s food is in its carrier's hands."""
	return is_live(row) and carried[row] != NONE


func live_count() -> int:
	"""How many moves stand."""
	return MAX_ROWS - lot.count(NONE)


func row_of_worker(who: int) -> int:
	"""The move resident `who` has, or NONE."""
	return worker.find(who) if who >= 0 else NONE


func source_of(row: int) -> int:
	"""The store move `row`'s food is booked at now (its lot's location), or NONE once the lot has gone."""
	var at: int = carried[row] if carried[row] != NONE else lot[row]
	var at_serial: int = carried_serial[row] if carried[row] != NONE else lot_serial[row]
	return _pantry.lot_location(at) if _pantry.is_lot(at, at_serial) else NONE


func destination_of(row: int) -> int:
	"""The store move `row` goes to (its index now), or NONE once it has gone."""
	return _read.value if _pantry.storage.index_of_id_into(to_id[row], _read) else NONE


func eligibility(row: int, who: int) -> String:
	"""Why resident `who` could not take move `row` ("" when it could): it must be able to carry (LORE-P12: no species
	lock), and one move a resident."""
	if who < 0 or who >= _cast.actor_count() or not _brain(who).can_carry():
		return CANT_CARRY
	var had: int = row_of_worker(who)
	return OTHER_MOVE if had != NONE and had != row else ""


func claim(row: int, who: int) -> bool:
	"""Hand waiting move `row` to `who`, reserving its room at the destination (see WHO MOVES IT); a move whose lot,
	surplus or room has gone is closed instead. False when it was not taken."""
	if not waiting(row) or not eligibility(row, who).is_empty():
		return false
	var to: int = destination_of(row)
	var amount: int = 0
	if _pantry.is_lot(lot[row], lot_serial[row]) and _still_cooler(row):
		amount = part_of(_pantry, lot[row], mini(milli[row], _free(lot[row])), _pantry.room_milli_of(to))
	if amount <= 0 or not _pantry.reserve_at_into(item[row], amount, to, _read):
		_close(row)
		return false
	hold[row] = _read.value
	milli[row] = _pantry.hold_milli(hold[row])
	worker[row] = who
	_restart(row, STEP_GO)
	return true


func pause(row: int, on: bool) -> String:
	"""Pause move `row` (its carrier let go, its room given up) or let it wait again: "" when done, else why not."""
	if not is_live(row):
		return GONE_WORDS
	if is_carrying(row):
		return IN_HAND_WORDS
	if on:
		_let_go(row)
	paused[row] = 1 if on else 0
	revision += 1
	return ""


func cancel(row: int) -> String:
	"""Take move `row` off the board: "" when done, else why not (a load in hand is shelved first)."""
	if not is_live(row):
		return GONE_WORDS
	if is_carrying(row):
		return IN_HAND_WORDS
	_let_go(row)
	_close(row)
	return ""


func reassign(row: int, who: int) -> String:
	"""Give move `row` to `who` instead: "" when done, else why not (nothing changed)."""
	var why: String = eligibility(row, who)
	if why.is_empty():
		why = pause(row, false)
	if not why.is_empty():
		return why
	_let_go(row)
	return "" if claim(row, who) else "that move can't be made now"


func task_text(who: int) -> String:
	"""What resident `who` is doing for the stores, in the party panel's words ("" for nothing): 'Carrying carrot to
	the root cellar 1' (demo_command.gd `add_task_text`)."""
	var row: int = row_of_worker(who)
	if row == NONE:
		return ""
	var at: int = destination_of(row) if step[row] >= STEP_CARRY else source_of(row)
	var store: String = _pantry.storage.label_of(at).to_lower() if at != NONE else "store"
	return STEP_WORDS[step[row]] % [Catalog.ITEM_LABELS[item[row]].to_lower(), store]


# --- the planner (see WHAT MOVES) -----------------------------------------------------------------

func plan() -> int:
	"""Plan moves into every free row while surplus food could keep longer elsewhere (see WHAT MOVES): stale waiting
	moves closed, the stores ranked and the lots scanned once, then the soonest-spoiling candidates taken. How many were
	planned."""
	_close_stale()
	_rank_stores()
	_scan(int(_hour_of.call()) if _hour_of.is_valid() else 0)
	var planned: int = 0
	var row: int = lot.find(NONE)
	while row != NONE and _plan_next(row):
		planned += 1
		row = lot.find(NONE)
	return planned


func _close_stale() -> void:
	"""Close every move nobody carries whose lot or destination has gone (the review's M2): a paused move whose food was
	eaten no longer holds the room it planned to take."""
	for row: int in MAX_ROWS:
		if is_live(row) and worker[row] == NOBODY:
			if not _pantry.is_lot(lot[row], lot_serial[row]) or destination_of(row) == NONE:
				_close(row)


func _rank_stores() -> void:
	"""Figure `_room` (each store's room, less what waiting moves will take there; none at a backed-off destination) and
	`_cooler` (where each store's food would go: `cooler_store`) once for this pass."""
	var stores: int = _pantry.storage.count()
	_room.resize(stores)
	_cooler.resize(stores)
	for to: int in stores:
		var off: bool = _backoff_to_usec > 0 and _pantry.storage.id_of(to) == _backoff_to_id
		_room[to] = 0 if off else _pantry.room_milli_of(to)
	for row: int in MAX_ROWS:
		if is_live(row) and hold[row] == NONE and destination_of(row) != NONE:
			_room[destination_of(row)] -= milli[row]
	for from: int in stores:
		_cooler[from] = cooler_store(_pantry.storage, _room, from)


func _scan(hour: int) -> void:
	"""Every movable lot (see `_movable`) with at least MIN_HOURS_LEFT where it is, its hours and its surplus, into the
	candidates (one pass; each lot's surplus asked once)."""
	_cand_count = 0
	for at: int in PantryScript.MAX_LOTS:
		if not _movable(at):
			continue
		var spare: int = _free(at)
		var hours: int = _pantry.lot_spoil_hours(at, hour) if spare > 0 else 0
		if spare <= 0 or hours < MIN_HOURS_LEFT:
			continue
		_cand_lot[_cand_count] = at
		_cand_hours[_cand_count] = hours
		_cand_free[_cand_count] = spare
		_cand_count += 1


func _plan_next(row: int) -> bool:
	"""Take the soonest-spoiling candidate that can still move (a destination with room for a lawful part: `part_of`)
	into free row `row`, the lowest lot row on a tie. False when none can."""
	while true:
		var k: int = _soonest_candidate()
		if k == NONE:
			return false
		var at: int = _cand_lot[k]
		_cand_lot[k] = NONE
		var to: int = cooler_store(_pantry.storage, _room, _pantry.lot_location(at))
		var amount: int = part_of(_pantry, at, mini(_cand_free[k], LOAD_MILLI), _room[to]) if to != NONE else 0
		if amount > 0:
			_open(row, at, to, amount)
			return true
	return false


func _soonest_candidate() -> int:
	"""The candidate not yet taken with the fewest hours left (the first on a tie), or NONE."""
	var best: int = NONE
	for k: int in _cand_count:
		if _cand_lot[k] != NONE and (best == NONE or _cand_hours[k] < _cand_hours[best]):
			best = k
	return best


static func part_of(pantry: PantryScript, at: int, wanted: int, room: int) -> int:
	"""How much of lot row `at` a move may take, given `wanted` (its surplus, capped) and `room` at the destination: the
	least of them -- the whole lot, or a part no smaller than MIN_PART_MILLI and only with a lot row free to split into
	(see WHAT MOVES); 0 when none may move."""
	var amount: int = mini(wanted, room)
	if amount <= 0:
		return 0
	if amount >= pantry.lot_milli(at):
		return pantry.lot_milli(at)
	if amount < MIN_PART_MILLI or pantry.lot_count() >= PantryScript.MAX_LOTS:
		return 0
	return amount


func _movable(at: int) -> bool:
	"""Whether lot row `at` could move now (see WHAT MOVES): live, uncarried, unplanned, in a store not backed off whose
	food has somewhere cooler to go."""
	if _pantry.lot_item(at) == PantryScript.FREE or _pantry.lot_carried(at) or _planned(at):
		return false
	var from: int = _pantry.lot_location(at)
	if _backoff_from_usec > 0 and _pantry.storage.id_of(from) == _backoff_from_id:
		return false
	return _cooler[from] != NONE


static func cooler_store(storage: StorageScript, room: PackedInt64Array, from: int) -> int:
	"""The store that ages food slowest with room (`room[to]` > 0), slower than store `from` -- the nearest to `from` on
	a tie -- or NONE."""
	var best: int = NONE
	for to: int in storage.count():
		if storage.permille_of(to) >= storage.permille_of(from) or room[to] <= 0:
			continue
		if best == NONE or storage.permille_of(to) < storage.permille_of(best):
			best = to
		elif storage.permille_of(to) == storage.permille_of(best) and _gap2(storage, to, from) < _gap2(storage, best, from):
			best = to
	return best


static func _gap2(storage: StorageScript, a: int, b: int) -> int:
	"""Squared distance between two stores' delivery points, in integer u (farm_pantry.gd U_PER_M)."""
	var dx: int = roundi((storage.position_of(a).x - storage.position_of(b).x) * PantryScript.U_PER_M)
	var dz: int = roundi((storage.position_of(a).y - storage.position_of(b).y) * PantryScript.U_PER_M)
	return dx * dx + dz * dz


func _planned(at: int) -> bool:
	"""Whether a standing move already takes from lot row `at` (as it is now)."""
	for row: int in MAX_ROWS:
		if lot[row] == at and lot_serial[row] == _pantry.lot_serial(at):
			return true
	return false


func _open(row: int, at: int, to: int, amount: int) -> void:
	"""A planned move of `amount` of lot row `at` to store `to`, waiting for a carrier; the room it will take there is
	counted taken for the rest of this pass."""
	lot[row] = at
	lot_serial[row] = _pantry.lot_serial(at)
	item[row] = _pantry.lot_item(at)
	milli[row] = amount
	_room[to] -= amount
	to_id[row] = _pantry.storage.id_of(to)
	serial[row] = _next_serial
	_next_serial += 1
	worker[row] = NOBODY
	paused[row] = 0
	carried[row] = NONE
	hold[row] = NONE
	revision += 1


func _free(at: int) -> int:
	"""How much of lot row `at` nobody has reserved (`free_of`; all of it without one)."""
	if _pantry.lot_carried(at):
		return 0
	return int(_free_of.call(at)) if _free_of.is_valid() else _pantry.lot_milli(at)


# --- the work (see WHO MOVES IT) --------------------------------------------------------------------

func update(usec: int) -> void:
	"""One frame of the moves, `usec` microseconds of demo time (0 while paused): plan every PLAN_USEC, then step every
	move with a carrier."""
	_backoff_from_usec = maxi(0, _backoff_from_usec - usec)
	_backoff_to_usec = maxi(0, _backoff_to_usec - usec)
	_plan_usec -= usec
	if _plan_usec <= 0 and usec > 0:
		_plan_usec = PLAN_USEC
		plan()
	for row: int in MAX_ROWS:
		if is_live(row) and worker[row] != NOBODY:
			_step(row, usec)


func _step(row: int, usec: int) -> void:
	"""Run one frame of move `row`: its lot gone (spoiled, eaten) ends it; else its walk or its work."""
	if not _lot_still_there(row):
		_end(row)
		return
	if step[row] == STEP_GO or step[row] == STEP_CARRY:
		_step_walk(row)
	else:
		_step_work(row, usec)


func _lot_still_there(row: int) -> bool:
	"""Whether the food move `row` is about is still there: its source lot before pick-up, the lot in hand after."""
	if carried[row] != NONE:
		return _pantry.is_lot(carried[row], carried_serial[row])
	return _pantry.is_lot(lot[row], lot_serial[row])


func _step_walk(row: int) -> void:
	"""Issue the walk, then wait for the carrier to ARRIVE (decision 0361); called away, the move waits again; a walk
	given up is tried again, MAX_TRIES times, then the move closes."""
	var brain: BrainScript = _brain(worker[row])
	if issued[row] == 0:
		_issue_walk(row, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != goal[row]:
		_called_away(row)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if _arrived(row, brain):
		step[row] += 1
		issued[row] = 0
		work_usec[row] = 0
		tries[row] = 0
		return
	tries[row] += 1
	issued[row] = 0
	if tries[row] >= MAX_TRIES:
		_give_up(row, step[row] == STEP_CARRY)


func _issue_walk(row: int, brain: BrainScript) -> void:
	"""Send the carrier to the lot's store, or with the load to the destination -- into a cellar when it can take a load
	down (see WHO MOVES IT)."""
	var carry: bool = step[row] == STEP_CARRY
	var at: int = destination_of(row) if carry else source_of(row)
	if at == NONE:
		_end(row)
		return
	below[row] = 0
	if carry and _carry_below(row, brain, at):
		return
	var target: Vector2 = _pantry.storage.position_of(at)
	if not _spot_near(target, RING_GAP_M * tries[row], brain):
		_give_up(row, carry)
		return
	goal[row] = _found
	issued[row] = 1
	if carry:
		brain.order_carry(_found, target)
	else:
		brain.order_move(_found, target)


func _carry_below(row: int, brain: BrainScript, at: int) -> bool:
	"""Carry the load down to cellar `at`'s middle, facing its racks (farm_cellars.gd CARRIED IN). False when `at` is
	not a dug cellar or the carrier cannot take a load below."""
	var ref := FarmCellars.room_of(_pantry.storage.id_of(at))
	if _network == null or not _network.rooms.is_ref(ref.x, ref.y):
		return false
	var node: int = _network.rooms.middle[ref.x]
	if not brain.can_haul_below(node):
		return false
	goal[row] = _network.node_m(node)
	issued[row] = 1
	below[row] = 1
	brain.order_carry_below(node, FarmCellars.rack_at(_network, ref.x))
	return true


func _arrived(row: int, brain: BrainScript) -> bool:
	"""ARRIVAL (decision 0361): the trip ARRIVED within ARRIVE_M of its spot -- on the surface, or below in a cellar."""
	if below[row] == 1:
		return brain.underground and brain.trip_outcome == BrainScript.TRIP_ARRIVED \
			and brain.position.distance_to(goal[row]) <= ARRIVE_M
	return brain.arrived_near(goal[row], ARRIVE_M)


func _step_work(row: int, usec: int) -> void:
	"""Pick up or shelve, the carrier still ARRIVED at its spot (else back to the walk, nothing done)."""
	var brain: BrainScript = _brain(worker[row])
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_called_away(row)
		return
	if not _arrived(row, brain):
		step[row] -= 1
		issued[row] = 0
		work_usec[row] = 0
		return
	brain.play_in_place(WORK_CLIP if brain.has_clip(WORK_CLIP) else BrainScript.CLIP_IDLE)
	work_usec[row] += usec
	if step[row] == STEP_PICK and work_usec[row] >= PICK_USEC:
		_pick_up(row)
	elif step[row] == STEP_SHELVE and work_usec[row] >= SHELVE_USEC:
		_shelve(row)


func _pick_up(row: int) -> void:
	"""Take the move's food in hand (an exact split when it is less than the lot) and set off with it. With nothing to
	take now (reserved, eaten) or nowhere cooler to take it, the move ends; a carry the pantry refuses (no lot row free
	for the split) gives up and backs off the store."""
	if not _still_cooler(row):
		_end(row)
		return
	var amount: int = mini(mini(milli[row], _free(lot[row])), _pantry.hold_milli(hold[row]))
	if amount <= 0:
		_end(row)
		return
	if not _pantry.begin_carry_into(lot[row], lot_serial[row], amount, _read):
		_give_up(row, false)
		return
	carried[row] = _read.value
	carried_serial[row] = _pantry.lot_serial(_read.value)
	milli[row] = amount
	_pantry.resize_hold(hold[row], amount)
	_hold_load(worker[row], item[row])
	_restart(row, STEP_CARRY)


func _shelve(row: int) -> void:
	"""Set the load down in the destination's store (what fits; the rest goes back to its own store) and end the move;
	nothing set down at all (no room, no lot row for a split) gives up and backs off the destination."""
	var stored: int = 0
	if _pantry.set_down_into(carried[row], carried_serial[row], hold[row], _read):
		hold[row] = NONE
		stored = _read.value
	if stored <= 0:
		_give_up(row, true)
		return
	moves_done += 1
	shelved_milli += stored
	_end(row)


func _still_cooler(row: int) -> bool:
	"""Whether move `row`'s destination still keeps food longer than the store its food is in (the review's M1)."""
	var from: int = source_of(row)
	var to: int = destination_of(row)
	return from != NONE and to != NONE and _pantry.storage.permille_of(to) < _pantry.storage.permille_of(from)


# --- ending ---------------------------------------------------------------------------------------

func _called_away(row: int) -> void:
	"""The carrier was ordered away: the load goes back (it never left the books), the room is given up, and the move
	waits on the board again from the start."""
	_unassign(row)
	revision += 1


func _give_up(row: int, at_destination: bool) -> void:
	"""The move cannot be made: it closes (the load back, the room freed, the carrier sent back to its routine) and the
	planner leaves the store that failed it -- the destination, or the lot's own store -- alone for BACKOFF_USEC (see
	NOTHING CREDITED FROM AFAR)."""
	var at: int = destination_of(row) if at_destination else source_of(row)
	var id: Variant = _pantry.storage.id_of(at) if at != NONE else null
	if at_destination:
		_backoff_to_id = id
		_backoff_to_usec = BACKOFF_USEC
	else:
		_backoff_from_id = id
		_backoff_from_usec = BACKOFF_USEC
	_end(row)


func _end(row: int) -> void:
	"""The move is over: its carrier back to its routine (or its next unfinished job), the row freed."""
	_let_go(row)
	_close(row)


func _let_go(row: int) -> void:
	"""Take move `row`'s carrier off it (`_unassign`) and send it back to its routine or its next unfinished job."""
	var who: int = worker[row]
	_unassign(row)
	if who != NOBODY:
		var brain: BrainScript = _brain(who)
		brain.play_in_place(BrainScript.CLIP_IDLE)
		brain.work_done()


func _unassign(row: int) -> void:
	"""No carrier: any load put back, the room held given up, the walk forgotten (the carrier is not touched)."""
	if carried[row] != NONE:
		_pantry.put_back(carried[row], carried_serial[row])
		carried[row] = NONE
	if hold[row] != NONE:
		_pantry.release(hold[row])
		hold[row] = NONE
	if worker[row] != NOBODY:
		_hold_load(worker[row], Catalog.NO_ITEM)
	worker[row] = NOBODY
	_restart(row, STEP_GO)


func _restart(row: int, at_step: int) -> void:
	"""Start step `at_step` afresh."""
	step[row] = at_step
	issued[row] = 0
	below[row] = 0
	tries[row] = 0
	work_usec[row] = 0
	revision += 1


func _close(row: int) -> void:
	"""Free the row."""
	lot[row] = NONE
	worker[row] = NOBODY
	paused[row] = 0
	to_id[row] = null
	revision += 1


# --- helpers ----------------------------------------------------------------------------------------

func _brain(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _hold_load(who: int, it: int) -> void:
	"""The load's own model in the carrier's hands (farm_goods.gd), or none (Catalog.NO_ITEM)."""
	var actor := _cast.actor(who) as DemoActorScript
	if it == Catalog.NO_ITEM or _goods == null or not _goods.has_model(it):
		if actor.holding():
			actor.drop_held()
		return
	actor.hold(_goods.props.mesh_of(Catalog.ITEM_PROP[it]), _goods.hand_fit(it))


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript) -> bool:
	"""The spot to stand at round `target` (stand_spot.gd), into `_found`. False when there is none."""
	if not SpotScript.find_into(_cast, target, first_ring, brain, _spot):
		return false
	_found = _spot[0]
	return true
