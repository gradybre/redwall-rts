extends "res://test/framework/test_case.gd"
## Spoil becomes earth, not compost (decision 0401; Brendan's ruling of 2026-09-30, the adopted `excavated_earth`
## rule: dug earth is never fertiliser). A tunnel's earth is dug, heaped at its mouth, carried -- cleared into the
## village stores, or to a bed -- and then built into a raised or banked bed, or kept (on its heap, or in the stores).
## Every frame of every run here the books balance: what the tunnels heaped = what is on the heaps + in the clearing
## crew's baskets + in the farm's hands + in the stores + built into beds. Raising and banking never add fertility;
## compost never comes from earth; a carry of earth that is cancelled, interrupted or refused at its bed is walked back
## to where it came from (0222's open item). And the action cards say what the orders do.
##
## No scene tree and no staged assets: the placeholder cast in the real village layout, stepped at 60 Hz.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const SpoilCrewScript := preload("res://demo/spoil/spoil_crew.gd")
const DemoSpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const FarmWork := preload("res://demo/work/farm_work.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")

const DT: float = 1.0 / 60.0
const BED_LOAM: int = 0
const BED_CLAY: int = 1
const DOSE: int = JobsScript.EARTH_PER_JOB_MILLI
## A carry is cancelled or interrupted this far (m) from where its earth was dug, so going back is a real walk.
const AWAY_M: float = 3.0

var _nodes: Array[Node] = []
var _notices: PackedStringArray = PackedStringArray()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _cast: DemoCastScript = null
var _network: GraphScript = null
var _sim: SimScript = null
var _tunnels: TunnelsScript = null
var _stores: StoresScript = null
var _crew: CrewScript = null
## The clearing crew, when a test uses one (its baskets are in the books).
var _spoil: SpoilCrewScript = null
## Every frame's books balanced (see the header), and the first frame they did not.
var _balanced: bool = true
var _first_off: String = ""


func before_each() -> void:
	"""The placeholder cast in the real village, a farm crew (placeholder 0 its routine crew) on earth books bound to
	the village stores by the stockpile, as demo_spoil.gd binds them."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	_cast = DemoCastScript.new()
	_nodes.append(_cast)
	_cast.build({}, world.points_of_interest(), world.obstacles())
	_cast.set_bounds(world.bounds())
	for i: int in _cast.actor_count():
		_brain(i).set_carry_motion(_carry_motion())
	_network = _cast.space().tunnels
	_sim = SimScript.new()
	_tunnels = TunnelsScript.new()
	_stores = StoresScript.new()
	_tunnels.bind_store(_stores, DemoSpoilScript.drop_point(_cast))
	_crew = CrewScript.new()
	_crew.configure(_cast, _sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(_cast))), _tunnels,
		DemoFarmScript.well_position(), func(text: String) -> void: _notices.append(text))
	_crew.set_crew(PackedInt32Array([0]))
	_spoil = null
	_balanced = true
	_first_off = ""


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_notices.clear()


# --- fixtures -----------------------------------------------------------------------------------

func _dig_tunnel(from_m: Vector2, to_m: Vector2) -> PackedInt32Array:
	"""A straight mouth-to-mouth tunnel dug to the end, its heaps placed beside its mouths; [entrance, exit] heaps."""
	var route := PackedInt32Array([Rules.to_u(from_m.x), Rules.to_u(from_m.y), Rules.to_u(to_m.x), Rules.to_u(to_m.y)])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(_network.add_into(route, 2, 0, ref), "a tunnel")
	var chain := PackedInt32Array()
	_network.piece_segments_into(ref[2], chain)
	for slot: int in chain:
		_network.start_dig(slot, _network.generation[slot], 0)
		_network.advance(slot, _network.generation[slot], 3600 * Rules.USEC_PER_SECOND)
	assert_true(_network.piece_done(ref[2]), "dug")
	var heaps := PackedInt32Array([_network.mouth_of_end(chain[0], false), _network.mouth_of_end(chain[chain.size() - 1], true)])
	_network.set_heap(heaps[0], from_m + Vector2(0.0, 1.4), 0.7, Vector2(0.0, 1.0))
	_network.set_heap(heaps[1], to_m + Vector2(0.0, 1.4), 0.3, Vector2(0.0, 1.0))
	return heaps


func _heaped() -> int:
	"""All the earth the tunnels have dug out and heaped, milli-U."""
	var total: int = 0
	for m: int in Rules.MAX_MOUTHS:
		total += _network.heaped_milli(m)
	return total


func _in_farm_hands() -> int:
	"""Earth in the farm's jobs (a raise or a bank carrying it, or an earth return), milli-U."""
	var total: int = 0
	for row: int in JobsScript.MAX_JOBS:
		var k: int = _crew.jobs.kind[row]
		if k == JobsScript.KIND_RAISE or k == JobsScript.KIND_BANK or k == JobsScript.KIND_RETURN_EARTH:
			total += _crew.jobs.load_milli[row]
	return total


func _accounted() -> int:
	"""Everywhere earth can be: the heaps, the clearing crew's baskets, the farm's hands, the stores, built in."""
	var baskets: int = _spoil.in_hand_milli() if _spoil != null else 0
	return _tunnels.total_spoil(_network) + baskets + _in_farm_hands() + _stores.earth_milli_u + _tunnels.built_milli


func _check_books(expected: int, frame: int) -> void:
	"""Note the first frame the books do not balance against `expected`."""
	if _balanced and _accounted() != expected:
		_balanced = false
		_first_off = "frame %d: %d accounted against %d" % [frame, _accounted(), expected]


func _run(seconds: float, done: Callable, expected: int) -> bool:
	"""Step the cast, the clearing crew (if any) and the farm crew at 60 Hz until `done()` or `seconds` pass, checking
	the books against `expected` every frame."""
	for frame: int in roundi(seconds / DT):
		_cast.advance(DT)
		if _spoil != null:
			_spoil.update(_cast.clock.frame_usec)
		_crew.update(_cast.clock.frame_usec)
		_check_books(expected, frame)
		if done.call():
			return true
	return false


func _row_of(kind: int, bed: int) -> int:
	"""The board row of `kind` on `bed` (-1: none)."""
	return _read.value if _crew.jobs.job_on_bed_into(kind, bed, _read) else -1


func _carrying(kind: int, bed: int) -> Callable:
	"""Done once the `kind` job on `bed` is on its carry walk to the bed with its earth in hand, under way and
	AWAY_M from where it dug it."""
	return func() -> bool:
		var row: int = _row_of(kind, bed)
		if row < 0 or _crew.jobs.current_step(row) != JobsScript.STEP_CARRY_BED or _crew.jobs.load_milli[row] <= 0 \
				or _crew.jobs.issued[row] != 1 or not _brain(_crew.jobs.worker[row]).carrying:
			return false
		var from: Vector2 = _tunnels.spot_of(_network, _crew.jobs.heap[row])
		return _brain(_crew.jobs.worker[row]).surface_point().distance_to(from) >= AWAY_M


func _idle() -> Callable:
	"""Done once the farm's board is empty."""
	return func() -> bool: return _crew.jobs.live_count() == 0


func _carry_motion() -> Dictionary:
	"""A straight carry root motion, 1.0 m/s over 6.5 s: everyone can carry (clear a heap, walk earth loaded)."""
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 6.5 * k / 65.0])
	return {"keys_xz": keys, "mean_speed_m_s": 1.0, "period_s": 6.5}


func _free_mouth(m: int) -> void:
	"""Mouth row `m` freed and reused as underground_graph.gd `_free_node` leaves it: a new generation, nothing heaped."""
	_network.mouth_gen[m] += 1
	_network.mouth_spoil[m] = 0


func _brain(i: int) -> BrainScript:
	"""Placeholder `i`'s brain."""
	return (_cast.actor(i) as DemoActorScript).brain


# --- no fertility from earth ----------------------------------------------------------------------

func test_raising_and_banking_add_no_fertility_and_spend_no_compost() -> void:
	"""Decision 0401: earth raises and banks a bed -- drainage, warmth, kept moisture -- and nothing else. The flags set,
	fertility and the compost store are untouched."""
	var before_loam: int = _sim.fertility_of(BED_LOAM)
	var before_clay: int = _sim.fertility_of(BED_CLAY)
	assert_true(_sim.raise_bed(BED_LOAM).ok, "raised")
	assert_true(_sim.bank_bed(BED_CLAY).ok, "banked")
	assert_equal(_sim.fertility_of(BED_LOAM), before_loam, "raising adds no fertility")
	assert_equal(_sim.fertility_of(BED_CLAY), before_clay, "banking adds no fertility")
	assert_equal(_sim.compost_milli, SimScript.START_COMPOST_MILLI, "no compost made or spent")


func test_compost_on_a_bed_is_refused_with_heaps_full_of_earth() -> void:
	"""The compost store empty and 18 U of earth on a heap: Compost is refused (the card and the order alike), no
	heap is touched, no fertility rises -- earth is never compost."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	_sim.compost_milli = 0
	var fertility: int = _sim.fertility_of(BED_LOAM)
	var card := CardScript.new()
	_crew.preview_into(card, JobsScript.KIND_COMPOST, BED_LOAM, PackedInt32Array([1]))
	assert_equal(card.code, String(SimScript.REFUSE_NO_COMPOST), "refused for compost")
	assert_equal(Array(card.cost_names), [FarmCard.COMPOST_STORE], "only the compost store is a cost")
	assert_equal(_crew.order(JobsScript.KIND_COMPOST, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER),
		"Can't compost: " + card.reason, "the order refuses with the card's words")
	assert_false(_run(30.0, func() -> bool: return _sim.fertility_of(BED_LOAM) != fertility, _heaped()), "no fertility")
	assert_equal(_tunnels.spoil_left(_network, heaps[0]), 18000, "the heap untouched")
	assert_equal(_crew.jobs.live_count(), 0, "nothing queued")


func test_compost_comes_only_from_plant_waste() -> void:
	"""The compost store fills from a cleared crop (REQ-SET-085's 0.5 U) and spoiled food (§5.7's 4 : 2), never from
	earth: a whole cleared heap goes into the stores' earth and the compost store does not move."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	_sim.infect_for_test(5)
	assert_true(_sim.clear(5).ok, "a blighted crop cleared")
	assert_equal(_sim.compost_milli, SimScript.START_COMPOST_MILLI + 500, "+0.5 U of plant waste")
	var compost: int = _sim.compost_milli
	_spoil = SpoilCrewScript.new()
	_spoil.configure(_cast, _network, _tunnels, null, _stores.add_earth, DemoSpoilScript.drop_point(_cast))
	var said: String = _spoil.order(heaps[1], PackedInt32Array([3]))
	assert_true(said.begins_with("Clearing the spoil heap"), said)
	var cleared := func() -> bool: return _tunnels.spoil_left(_network, heaps[1]) == 0 and _spoil.in_hand_milli() == 0
	assert_true(_run(90.0, cleared, _heaped()), "the exit heap cleared")
	assert_true(_balanced, _first_off)
	assert_equal(_stores.earth_milli_u, 2000, "its 2 U kept as earth in the stores")
	assert_equal(_sim.compost_milli, compost, "the compost store did not move")


# --- earth conserved: dig, heap, carry, use --------------------------------------------------------

func test_earth_is_conserved_from_the_dig_through_clearing_to_beds_built() -> void:
	"""A dug tunnel heaps 20 U (18 at the entrance, 2 at the exit). The exit heap is cleared into the stores; then a
	raise and a bank fetch 2 U each and build it in. Every frame the books balance; at the end 4 U is built in, the
	rest still on the heap or in the stores, and neither bed gained fertility."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var dug: int = _heaped()
	assert_equal(dug, 20000, "20 U dug and heaped")
	_spoil = SpoilCrewScript.new()
	_spoil.configure(_cast, _network, _tunnels, null, _stores.add_earth, DemoSpoilScript.drop_point(_cast))
	_spoil.order(heaps[1], PackedInt32Array([3]))
	var cleared := func() -> bool: return _tunnels.spoil_left(_network, heaps[1]) == 0 and _spoil.in_hand_milli() == 0
	assert_true(_run(90.0, cleared, dug), "the exit heap cleared into the stores")
	var fertility := PackedInt32Array([_sim.fertility_of(BED_LOAM), _sim.fertility_of(BED_CLAY)])
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	_crew.order(JobsScript.KIND_BANK, BED_CLAY, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	var built := func() -> bool: return _sim.is_raised(BED_LOAM) and _sim.is_banked(BED_CLAY) and _crew.jobs.live_count() == 0
	assert_true(_run(240.0, built, dug), "raised and banked")
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.built_milli, 2 * DOSE, "4 U built into the beds")
	assert_equal(_tunnels.total_spoil(_network) + _stores.earth_milli_u, dug - 2 * DOSE, "the rest kept")
	assert_equal(PackedInt32Array([_sim.fertility_of(BED_LOAM), _sim.fertility_of(BED_CLAY)]), fertility, "no fertility")


func test_raise_fetches_earth_from_the_stores_when_no_heap_has_any() -> void:
	"""No tunnel; 4 U of earth kept in the stores. The card's have is the stores', the worker walks to the stockpile
	for it (the party panel says so), and the order spends exactly the card's need."""
	_stores.add_earth(4000)
	var card := CardScript.new()
	_crew.preview_into(card, JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]))
	assert_true(card.is_ok(), card.text())
	assert_equal([Array(card.cost_names), int(card.cost_have[0]), int(card.cost_need[0])], [[FarmCard.EARTH], 4000, DOSE],
		"earth: have the stores' 4 U, need 2 U")
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var row: int = _row_of(JobsScript.KIND_RAISE, BED_LOAM)
	assert_true(_run(10.0, func() -> bool: return _crew.jobs.issued[row] == 1, 4000), "on its way")
	assert_equal(_crew.jobs.heap[row], TunnelsScript.STORE, "to the stores")
	assert_true(_crew.task_text(1).ends_with("to the stores for earth"), _crew.task_text(1))
	assert_true(_run(240.0, _idle(), 4000), "raised")
	assert_true(_balanced, _first_off)
	assert_true(_sim.is_raised(BED_LOAM), "raised")
	assert_equal(4000 - _stores.earth_milli_u, int(card.cost_need[0]), "spent what the card said")
	assert_equal(_tunnels.built_milli, DOSE, "built in")


func test_no_earth_anywhere_refuses_raise_on_the_card_and_the_order() -> void:
	"""1 U in the stores and no heap: Raise is refused NO_EARTH, the card's words and the order's the same, its fix
	pointing at a dig; nothing leaves the stores."""
	_stores.add_earth(1000)
	var card := CardScript.new()
	_crew.preview_into(card, JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]))
	assert_equal(card.code, JobsScript.REFUSE_NO_EARTH, "no earth")
	assert_equal(card.reason, "no spoil heap or store holds 2.0 U of earth", "the words")
	assert_equal(card.fix, "Dig tunnel (B): its earth heaps up at the mouth", "the fix")
	assert_equal(_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER),
		"Can't raise: " + card.reason, "the order's words")
	assert_equal(_stores.earth_milli_u, 1000, "nothing taken")


# --- a carry of earth is never lost ---------------------------------------------------------------

func test_a_raise_cancelled_mid_carry_walks_its_earth_back_to_the_heap() -> void:
	"""0222's open item, fixed: cancelling a raise with 2 U in hand does not drop it. The job becomes an earth return,
	its carrier walks it back and tips it on the heap it came from: the heap is whole again, nothing built, the bed not
	raised, and a new Raise can be ordered there meanwhile."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var dug: int = _heaped()
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var dig_off := PackedFloat32Array([INF])
	var carrying := _carrying(JobsScript.KIND_RAISE, BED_LOAM)
	var digging := func() -> bool:
		var r: int = _row_of(JobsScript.KIND_RAISE, BED_LOAM)
		if r >= 0 and _crew.jobs.current_step(r) == JobsScript.STEP_WORK + JobsScript.WORK_DIG:
			dig_off[0] = _brain(1).surface_point().distance_to(_network.heap_at[_crew.jobs.heap[r]])
		return carrying.call()
	assert_true(_run(120.0, digging, dug), "carrying the earth")
	var source: int = _crew.jobs.heap[_row_of(JobsScript.KIND_RAISE, BED_LOAM)]
	var near: float = _tunnels.rim_m(_network, source) + CrewScript.HEAP_STAND_M + CrewScript.ARRIVE_M
	assert_true(dig_off[0] <= near, "dug standing at its heap (%.2f m from it, within %.2f)" % [dig_off[0], near])
	assert_equal(_tunnels.spoil_left(_network, source), _tunnels.heaped_milli(_network, source) - DOSE, "2 U off it")
	assert_equal(_crew.cancel_bed(BED_LOAM), 1, "the raise cancelled")
	assert_equal(_row_of(JobsScript.KIND_RAISE, BED_LOAM), -1, "no raise stands on the bed")
	var back: int = _row_of(JobsScript.KIND_RETURN_EARTH, BED_LOAM)
	assert_true(back >= 0 and _crew.jobs.load_milli[back] == DOSE, "an earth return with the 2 U")
	assert_equal(_crew.jobs.worker[back], 1, "the same carrier")
	assert_equal(_crew.cancel_bed(BED_LOAM), 0, "a return is not production: nothing more to cancel")
	assert_equal(_crew.task_text(1), "Carrying 2.0 U of earth back to the spoil heap", "the party panel")
	assert_equal(_notices[-1], "Raise cancelled: Placeholder 1 carries the 2.0 U of earth back to the spoil heap", "said")
	var seen := {"loaded": false, "tip_off": INF}
	var watch := func() -> bool:
		var r: int = _row_of(JobsScript.KIND_RETURN_EARTH, BED_LOAM)
		if r >= 0 and _crew.jobs.current_step(r) == JobsScript.STEP_CARRY_HEAP and _brain(1).carrying:
			seen["loaded"] = true
		if r >= 0 and _crew.jobs.current_step(r) == JobsScript.STEP_WORK + JobsScript.WORK_DROP:
			seen["tip_off"] = _brain(1).surface_point().distance_to(_network.heap_at[source])
		return _crew.jobs.live_count() == 0
	assert_true(_run(120.0, watch, dug), "carried back")
	assert_true(bool(seen["loaded"]), "walked back loaded (the carry walk)")
	var reach: float = _tunnels.rim_m(_network, source) + CrewScript.HEAP_STAND_M + CrewScript.ARRIVE_M
	assert_true(float(seen["tip_off"]) <= reach, "tipped standing at its heap (%.2f m from it, within %.2f)" % [
		float(seen["tip_off"]), reach])
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.spoil_left(_network, source), _tunnels.heaped_milli(_network, source), "the heap whole again")
	assert_equal(_tunnels.built_milli, 0, "nothing built")
	assert_false(_sim.is_raised(BED_LOAM), "not raised")
	assert_true(_notices[_notices.size() - 1].contains("tipped 2.0 U of earth back to the spoil heap"), _notices[-1])
	assert_equal(heaps.size(), 2, "two heaps")


func test_the_work_board_shows_an_earth_return_as_a_delivery_it_never_redirects() -> void:
	"""M's work board over L's earth (decision 0411 with 0401): a raise with earth in hand is not paused or handed over
	from afar; cancelled, its "Carry earth back" row is a delivery -- HAULING, carrying -- that Pause, Cancel and
	Reassign all refuse, and it is walked back with the books whole."""
	_dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var dug: int = _heaped()
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(120.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), dug), "carrying the earth")
	var raise: int = _row_of(JobsScript.KIND_RAISE, BED_LOAM)
	var source := FarmWork.new(_crew)
	assert_equal(source.activity(raise), WorkIds.ACT_FARM, "the raise itself is farm work")
	assert_true(_crew.holds_earth(raise), "earth in hand")
	assert_true(_crew.pause(raise, true).begins_with("Placeholder 1 is carrying"), "a raise with earth is not paused")
	assert_false(_crew.reassign(raise, 2).is_empty(), "nor handed over from afar")
	assert_equal(_crew.cancel_bed(BED_LOAM), 1, "the raise cancelled")
	var back: int = _row_of(JobsScript.KIND_RETURN_EARTH, BED_LOAM)
	assert_true(back >= 0, "an earth return")
	var task := TaskRecord.new()
	source.fill(task, back)
	assert_equal([task.action, task.activity, task.carrying], ["Carry earth back", WorkIds.ACT_HAUL, true],
		"a delivery on the Work screen: hauling, carrying")
	assert_equal(task.cancel_refusal, WorkIds.EARTH_GOES_BACK, "Cancel refused")
	assert_false(task.pause_refusal.is_empty() or task.reassign_refusal.is_empty(), "Pause and Reassign refused")
	assert_equal(_crew.cancel_row(back), WorkIds.EARTH_GOES_BACK, "and the crew's own cancel says so")
	assert_false(_crew.pause(back, true).is_empty(), "the crew's pause refuses")
	assert_false(_crew.reassign(back, 2).is_empty(), "the crew's reassign refuses")
	assert_equal([_crew.jobs.kind[back], _crew.jobs.worker[back]], [JobsScript.KIND_RETURN_EARTH, 1], "nothing changed")
	assert_true(_run(120.0, _idle(), dug), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.total_spoil(_network), dug, "every heap whole again")


func test_a_bank_cancelled_while_working_the_bed_carries_its_earth_back() -> void:
	"""Cancelled during the banking work itself (earth still in hand, not yet built in): the earth goes back too."""
	var dug: int = 0
	_dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	dug = _heaped()
	_crew.order(JobsScript.KIND_BANK, BED_CLAY, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	var working := func() -> bool:
		var row: int = _row_of(JobsScript.KIND_BANK, BED_CLAY)
		return row >= 0 and _crew.jobs.current_step(row) == JobsScript.STEP_WORK + JobsScript.WORK_BANK \
			and _crew.jobs.elapsed_usec[row] > 0
	assert_true(_run(180.0, working, dug), "banking")
	assert_equal(_crew.cancel_bed(BED_CLAY), 1, "cancelled")
	assert_true(_run(120.0, _idle(), dug), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.total_spoil(_network), dug, "every heap whole again")
	assert_false(_sim.is_banked(BED_CLAY), "not banked")


func test_earth_fetched_from_the_stores_goes_back_to_the_stores() -> void:
	"""A raise carrying the stores' earth, cancelled: the 2 U goes back into the stores, not onto any heap."""
	_stores.add_earth(2000)
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(180.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), 2000), "carrying")
	assert_equal(_stores.earth_milli_u, 0, "taken from the stores")
	_crew.cancel_bed(BED_LOAM)
	assert_equal(_crew.task_text(1), "Carrying 2.0 U of earth back to the stores", "the party panel")
	assert_true(_run(180.0, _idle(), 2000), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_stores.earth_milli_u, 2000, "back in the stores")


func test_a_carrier_called_away_keeps_the_earth_on_the_board_and_a_cancel_then_returns_it() -> void:
	"""Called away mid-carry, the raise waits on the board with its 2 U (nothing dropped); cancelled while it waits,
	it becomes an earth return that the field crew -- or the carrier coming back to it -- walks back."""
	var dug: int = 0
	_dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	dug = _heaped()
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(120.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), dug), "carrying")
	var row: int = _row_of(JobsScript.KIND_RAISE, BED_LOAM)
	_brain(1).order_move(Vector2(-6.0, -6.0))
	assert_true(_run(2.0, func() -> bool: return _crew.jobs.worker[row] == JobsScript.NOBODY, dug), "on the board")
	assert_equal(_crew.jobs.load_milli[row], DOSE, "with its earth")
	_check_books(dug, -1)
	assert_equal(_crew.cancel_bed(BED_LOAM), 1, "cancelled while it waits")
	assert_equal(_notices[-1], "Raise cancelled: the field crew carries the 2.0 U of earth back to the spoil heap", "said")
	assert_true(_run(240.0, _idle(), dug), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.total_spoil(_network), dug, "every heap whole again")


func test_a_raise_refused_at_its_bed_carries_its_earth_back() -> void:
	"""The bed is raised by other means while the earth is on its way: the work is refused at the bed, and the 2 U goes
	back to its heap -- not built in, not lost."""
	var dug: int = 0
	_dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	dug = _heaped()
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(120.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), dug), "carrying")
	assert_true(_sim.raise_bed(BED_LOAM).ok, "raised meanwhile")
	var returning := func() -> bool: return _row_of(JobsScript.KIND_RETURN_EARTH, BED_LOAM) >= 0
	assert_true(_run(120.0, returning, dug), "refused at the bed: an earth return")
	assert_true(_notices[_notices.size() - 1].begins_with("Can't raise: it is done on this bed already: "), _notices[-1])
	assert_true(_run(120.0, _idle(), dug), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_tunnels.built_milli, 0, "nothing built")
	assert_equal(_tunnels.total_spoil(_network), dug, "every heap whole again")


func test_an_earth_return_that_cannot_get_through_puts_its_earth_back_where_it_came_from() -> void:
	"""A return whose carrier can find no way back (0361's rule for an undelivered basket): the earth goes back on its
	source from where it stands, the job closes, the worker is free -- nothing lost, nothing built."""
	_stores.add_earth(2000)
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(180.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), 2000), "carrying")
	_tunnels.bind_store(_stores, Vector2(500.0, 500.0))
	var incidents := IncidentsScript.new()
	_crew.set_incidents(incidents)
	_crew.cancel_bed(BED_LOAM)
	assert_true(_run(30.0, _idle(), 2000), "given up")
	assert_equal(incidents.serial_of("farm:stuck:%d:%d" % [BED_LOAM, JobsScript.KIND_RETURN_EARTH]), IncidentsScript.NO_SERIAL,
		"a carry home is not a stuck farm job: no incident")
	assert_equal(incidents.revision, 0, "nothing raised at all")
	assert_true(_balanced, _first_off)
	assert_equal(_stores.earth_milli_u, 2000, "put back in the stores")
	assert_true(_notices[_notices.size() - 1].contains("the 2.0 U of earth was put back to the stores"), _notices[-1])
	assert_equal(_brain(1).order, BrainScript.ORDER_NONE, "the worker free")


func test_earth_whose_heap_has_gone_goes_to_the_stores_or_waits_in_hand() -> void:
	"""The heap a return is bound for no longer takes it back (its mouth row freed and reused, as `_free_node` does it:
	the generation moves on and its heaped earth goes with the old row): the earth goes into the stores instead. With
	no stores bound either, the return waits on the board still holding it -- never dropped. The books balance every
	frame against what is heaped now plus the 2 U in hand."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var dug: int = _heaped()
	_crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(120.0, _carrying(JobsScript.KIND_RAISE, BED_LOAM), dug), "carrying")
	var source: int = _crew.jobs.heap[_row_of(JobsScript.KIND_RAISE, BED_LOAM)]
	_crew.cancel_bed(BED_LOAM)
	_free_mouth(source)
	var now: int = _heaped() + DOSE
	assert_equal(_accounted(), now, "the heap gone with its row; the 2 U still in hand")
	assert_true(_run(120.0, _idle(), now), "carried back")
	assert_true(_balanced, _first_off)
	assert_equal(_stores.earth_milli_u, DOSE, "into the stores: exactly the 2 U")
	assert_equal(heaps.size(), 2, "two heaps")
	var unbound := TunnelsScript.new()
	var crew := CrewScript.new()
	crew.configure(_cast, _sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(_cast))), unbound,
		DemoFarmScript.well_position(), func(text: String) -> void: _notices.append(text))
	crew.set_crew(PackedInt32Array())
	crew.order(JobsScript.KIND_BANK, BED_CLAY, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	var held := func() -> bool:
		return crew.jobs.job_on_bed_into(JobsScript.KIND_BANK, BED_CLAY, _read) \
			and crew.jobs.current_step(_read.value) == JobsScript.STEP_CARRY_BED and crew.jobs.load_milli[_read.value] > 0
	var in_hand := func() -> int:
		var total: int = 0
		for row: int in JobsScript.MAX_JOBS:
			total += crew.jobs.load_milli[row] if crew.jobs.is_live(row) else 0
		return total
	## These books see no stores: what is heaped now is on the heaps or in this crew's hands.
	var books := PackedInt64Array([_heaped(), 1])
	var stepped := func(seconds: float, done: Callable) -> bool:
		for frame: int in roundi(seconds / DT):
			_cast.advance(DT)
			crew.update(_cast.clock.frame_usec)
			if unbound.total_spoil(_network) + int(in_hand.call()) != books[0]:
				books[1] = 0
			if done.call():
				return true
		return false
	assert_true(stepped.call(120.0, held), "carrying, books with no stores")
	var from: int = crew.jobs.heap[_read.value]
	crew.cancel_bed(BED_CLAY)
	_free_mouth(from)
	books[0] = _heaped() + DOSE
	var waiting := func() -> bool:
		return crew.jobs.job_on_bed_into(JobsScript.KIND_RETURN_EARTH, BED_CLAY, _read) \
			and crew.jobs.worker[_read.value] == JobsScript.NOBODY
	assert_true(stepped.call(120.0, waiting), "nowhere to put it: it waits on the board")
	assert_equal(crew.jobs.load_milli[_read.value], DOSE, "still holding the 2 U")
	assert_equal(crew.jobs.blocked[_read.value], JobsScript.BLOCK_WAY, "waiting for the next hour")
	assert_equal(_notices[-1], "The 2.0 U of earth has nowhere to go back to: it waits on the board", "said")
	assert_equal(books[1], 1, "the books balanced every frame, with no stores")


# --- the books ------------------------------------------------------------------------------------

func test_a_clearing_basket_whose_heap_has_gone_goes_into_the_stores() -> void:
	"""A clearing worker called away with a basket puts it back on its heap (0361) -- unless the heap's mouth row was
	freed meanwhile and will not take it: then the basket goes into the stores, not lost (decision 0401)."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	_spoil = SpoilCrewScript.new()
	_spoil.configure(_cast, _network, _tunnels, null, _stores.add_earth, DemoSpoilScript.drop_point(_cast))
	_spoil.order(heaps[0], PackedInt32Array([3]))
	var carrying := func() -> bool:
		var r: int = _spoil.row_of(3)
		return r >= 0 and _spoil.load_milli[r] > 0 and _spoil.issued[r] == 1 and _brain(3).carrying
	assert_true(_run(60.0, carrying, _heaped()), "a basket on its way")
	var basket: int = _spoil.in_hand_milli()
	_free_mouth(heaps[0])
	var now: int = _heaped() + basket
	_brain(3).order_move(Vector2(-6.0, -6.0))
	assert_true(_run(2.0, func() -> bool: return _spoil.row_of(3) < 0, now), "called away")
	assert_true(_balanced, _first_off)
	assert_equal(_spoil.in_hand_milli(), 0, "the basket is settled")
	assert_equal(_stores.earth_milli_u, basket, "into the stores, all of it")


func test_the_stores_keep_earth_all_or_nothing() -> void:
	"""add_earth ignores nothing-or-less; take_earth takes all it is asked or none; the stores line names the earth."""
	var before: int = _stores.revision
	_stores.add_earth(0)
	_stores.add_earth(-5)
	assert_equal(_stores.earth_milli_u, 0, "nothing added")
	assert_equal(_stores.revision, before, "and nothing seen to change")
	_stores.add_earth(2500)
	assert_true(_stores.revision > before, "a change is seen")
	assert_false(_stores.take_earth(2501), "not more than is kept")
	assert_false(_stores.take_earth(0), "nothing is not a take")
	assert_equal(_stores.earth_milli_u, 2500, "untouched")
	before = _stores.revision
	assert_true(_stores.take_earth(2500), "all of it")
	assert_true(_stores.revision > before, "a take is seen")
	assert_equal(_stores.earth_milli_u, 0, "none left")
	_stores.add_earth(1500)
	assert_true(_stores.stock_line().ends_with(" · earth 1.5 U"), _stores.stock_line())


func test_the_stores_are_a_source_beside_the_heaps() -> void:
	"""Unbound, the store is no source; bound, it is taken from and returned to through the same books, chosen when it
	is nearest with enough, and counted by most_earth. A heap is never handed more back than was taken from it."""
	var tunnels := TunnelsScript.new()
	assert_false(tunnels.has_store(), "unbound")
	assert_false(tunnels.take_spoil_into(_network, TunnelsScript.STORE, 1000, _read), "no store to take from")
	assert_false(tunnels.return_spoil_into(_network, TunnelsScript.STORE, 1000, _read), "nor to return to")
	assert_equal(tunnels.most_earth(_network), 0, "no earth")
	var stores := StoresScript.new()
	stores.add_earth(3000)
	tunnels.bind_store(stores, Vector2(12.0, -15.0))
	assert_true(tunnels.has_store(), "bound")
	assert_equal(tunnels.most_earth(_network), 3000, "the stores' earth counted")
	assert_equal(tunnels.spot_of(_network, TunnelsScript.STORE), Vector2(12.0, -15.0), "fetched at the stockpile")
	assert_equal(tunnels.rim_m(_network, TunnelsScript.STORE), 0.0, "a point")
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	assert_almost_equal(tunnels.rim_m(_network, heaps[0]), 0.7, "a heap's rim")
	assert_true(tunnels.nearest_earth_into(_network, Vector2(12.0, -14.0), 3000, _read), "3 U near the stockpile")
	assert_equal(_read.value, TunnelsScript.STORE, "the stores")
	assert_true(tunnels.nearest_earth_into(_network, Vector2(12.0, -14.0), 3001, _read), "3.001 U")
	assert_equal(_read.value, heaps[0], "only the entrance heap has it")
	assert_true(tunnels.take_spoil_into(_network, TunnelsScript.STORE, 3000, _read), "all the stores' earth")
	assert_equal(stores.earth_milli_u, 0, "taken from the stores")
	assert_false(tunnels.take_spoil_into(_network, TunnelsScript.STORE, 1, _read), "none left")
	assert_equal(_read.error, TunnelsScript.REFUSE_NO_SPOIL, "says so")
	assert_true(tunnels.return_spoil_into(_network, TunnelsScript.STORE, 3000, _read), "returned")
	assert_equal(stores.earth_milli_u, 3000, "back")
	assert_false(tunnels.return_spoil_into(_network, heaps[1], 1, _read), "nothing was taken from the exit heap")
	assert_false(tunnels.take_spoil_into(_network, TunnelsScript.SOURCES, 1, _read), "past the sources")
	assert_equal(_read.error, TunnelsScript.REFUSE_BAD_HEAP, "no such source")
	assert_false(tunnels.take_spoil_into(_network, -1, 1, _read), "before them")
	assert_equal(_read.error, TunnelsScript.REFUSE_BAD_HEAP, "no such source either")
	assert_false(tunnels.return_spoil_into(_network, -1, 1, _read), "nor returned to")
	assert_equal(_read.error, TunnelsScript.REFUSE_BAD_HEAP, "says so")
	tunnels.build_with(0)
	tunnels.build_with(-1)
	assert_equal(tunnels.built_milli, 0, "nothing built of nothing")


func test_the_village_wiring_keeps_cleared_earth_in_the_stores() -> void:
	"""demo_spoil.gd `configure` (demo_village.gd passes the village stores): the farm's books are bound to the stores
	at the stockpile, and a heap's cleared earth is delivered into them."""
	var heaps := _dig_tunnel(Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var tunnels := TunnelsScript.new()
	var stores := StoresScript.new()
	var camera := Camera3D.new()
	var command := CommandScript.new()
	command.configure(_cast, camera)
	var spoil := DemoSpoilScript.new()
	spoil.configure(_cast, command, camera, _network, tunnels, null, stores)
	assert_true(tunnels.has_store(), "bound to the stores")
	assert_equal(tunnels.spot_of(_network, TunnelsScript.STORE), DemoSpoilScript.drop_point(_cast), "at the drop spot")
	spoil.crew.order(heaps[1], PackedInt32Array([3]))
	for frame: int in roundi(90.0 / DT):
		_cast.advance(DT)
		spoil.crew.update(_cast.clock.frame_usec)
		if tunnels.spoil_left(_network, heaps[1]) == 0 and spoil.crew.in_hand_milli() == 0:
			break
	assert_equal(stores.earth_milli_u, 2000, "the exit heap's 2 U kept in the stores")
	assert_equal(spoil.task_text(3), "", "done")
	assert_true(DemoSpoilScript.SELECTED_TEXT.contains("U of earth"), "the heap is earth")
	assert_true(DemoSpoilScript.HAULING_TEXT == "Hauling earth to the stores", "and goes to the stores")
	for node: Node in [spoil, command, camera]:
		node.free()
