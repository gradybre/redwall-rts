extends "res://test/framework/test_case.gd"
## ARCH-SAVE-006 (ADR 1222 step 12): next-tick parity across a save and load.
##
## The generated settlement runs to tick 3000 with a command still pending, and is saved. The
## uninterrupted run then continues to tick 18000, recording a fingerprint of every canonical
## member (`fixtures/save_parity_fingerprint.gd`) after every tick. The save is loaded into a fresh
## settlement, which runs 3001-18000 with the same pending command; its fingerprint must equal the
## uninterrupted run's at EVERY tick, and its save at 18000 must be byte-identical.
##
## The same run supplies ARCH-SAVE-006's coverage cases at the first host boundary where each holds,
## saves there, loads into a fresh settlement and compares tick for tick for EDGE_WINDOW ticks, then
## byte for byte:
##   * an exact midnight (completed tick 13500: the calendar starts 4500 ticks into day 1);
##   * a dying resident: one resident's hunger is emptied at the fork, so the starvation clock that
##     drives REQ-SET's starvation death (`needs._starving_ticks`, the registry's named case) runs.
## The other named cases are watched for on every boundary and are NOT reached by the generated
## settlement today: no job scan continues across a tick boundary (an active passive batch), no
## reservation lease expires inside a window, and the surface composes no navigation, so no A* heap is
## ever partial. `REACHED_CASES` states that; a change that makes one reachable fails here and must add
## it. Their columns are still in every tick's fingerprint.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const UiCommandBridge := preload("res://scripts/ui/ui_command_bridge.gd")
const Fingerprint := preload("res://test/fixtures/save_parity_fingerprint.gd")

## ARCH-SAVE-006's fork and horizon.
const START_TICK: int = 3000
const END_TICK: int = 18000
## The first midnight after the fork: the calendar starts 4500 ticks into day 1.
const MIDNIGHT_TICK: int = SimClockScript.TICKS_PER_DAY - SimClockScript.CALENDAR_OFFSET_TICKS
## Two game hours compared tick for tick after each coverage case's save.
const EDGE_WINDOW: int = 1500
## 100 ms host frames: exactly three ticks at 1x.
const FRAME_USEC: int = 100000
const EDGE_MIDNIGHT: String = "exact midnight"
const EDGE_BATCH: String = "active passive batch"
const EDGE_LEASE: String = "lease expiring in the window"
const EDGE_DYING: String = "dying resident"
## The coverage cases the generated settlement reaches (see the header).
const REACHED_CASES: Array[String] = [EDGE_MIDNIGHT, EDGE_DYING]
## Owners with no live instance in an unmounted settlement; every other declared field is covered.
const UNMOUNTED_OWNERS: Array[String] = ["underground_space_owner", "excavation_inventory",
	"excavation_sites", "inventory", "modular_projects", "room_layout", "room_projects", "spoil_tips",
	"underground_connector_contacts", "underground_connector_placements",
	"underground_connector_workpieces", "underground_entry_progress", "underground_locations",
	"underground_mount", "underground_routes", "underground_world_routes"]

var _nodes: Array[Node] = []
var _fingerprint: Fingerprint = Fingerprint.new()
var _running: Node = null
## The uninterrupted run's fingerprint after tick START_TICK + 1 + i, at index i.
var _expected: PackedInt64Array = PackedInt64Array()
var _recording: bool = true
var _first_mismatch: int = -1
## Save bytes by completed tick, and the edge case found at each save tick.
var _saves: Dictionary = {}
var _edges: Dictionary = {}


func after_each() -> void:
	"""Free every settlement; leave the autoload as the other suites expect it."""
	for node: Node in _nodes:
		node.free()
	_nodes.clear()
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _settlement() -> Node:
	"""A tracked, empty settlement."""
	var node: Node = SettlementSystemScript.new()
	_nodes.append(node)
	return node


func _step(tick: int) -> bool:
	"""The bound simulation step: run the tick, then record or compare its fingerprint."""
	var ok: bool = _running.run_tick(tick)
	var value: int = _fingerprint.fingerprint()
	if _recording:
		_expected.append(value)
	elif _first_mismatch < 0 and _expected[tick - START_TICK - 1] != value:
		_first_mismatch = tick
	return ok


func _day(absolute_day: int, season: int) -> bool:
	"""The bound day boundary of the running settlement."""
	return _running.run_day_boundary(absolute_day, season)


func _saved(settlement: Node) -> PackedByteArray:
	"""One complete save, asserting it succeeds."""
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(settlement, GameManager, bytes)
	assert_true(refusal.is_ok(), "save: %s %s" % [refusal.code, refusal.detail])
	return bytes


func _advance_plain(settlement: Node, tick: int) -> void:
	"""Run `settlement` to `tick` without fingerprints."""
	assert_true(GameManager.bind_simulation(settlement.run_tick, settlement.run_day_boundary), "bind")
	while GameManager.clock().completed_tick() < tick:
		GameManager.advance_host_time(FRAME_USEC)
	GameManager.unbind_simulation()


func _queue_pending_command(settlement: Node) -> void:
	"""ARCH-SAVE-006's "same pending commands": a NAME_RESIDENT queued at the save boundary."""
	var bridge: UiCommandBridge = UiCommandBridge.new(settlement.commands())
	var residents: RefCounted = settlement.residents()
	var slot: int = 0
	while not residents.is_present(slot):
		slot += 1
	assert_true(bridge.name_resident(residents.ref_of(slot), "Rowan"), "a command is queued")
	assert_equal(bridge.pending_count(), 1, "and still pending at the save")


func _starve_one(settlement: Node) -> void:
	"""The dying-resident case: empty one resident's hunger at the fork so its starvation clock runs."""
	var residents: RefCounted = settlement.residents()
	var slot: int = 0
	while not residents.is_present(slot):
		slot += 1
	var needs: RefCounted = settlement.needs()
	needs._need_value[slot * needs.NEED_COUNT + needs.NEED_HUNGER] = needs.HUNGER_STARVING_VALUE


# --- the uninterrupted run ------------------------------------------------------------------------

func _edge_at(world: SaveWorld.World, tick: int) -> String:
	"""The first coverage case not yet saved that holds at this boundary, or ""."""
	if tick == MIDNIGHT_TICK:
		return EDGE_MIDNIGHT
	if tick + EDGE_WINDOW > END_TICK:
		return ""
	if not _edges.values().has(EDGE_BATCH) and _any_nonzero32(world.jobs._job_scan_cursor):
		return EDGE_BATCH
	if not _edges.values().has(EDGE_LEASE) and _lease_expires_within(world, tick):
		return EDGE_LEASE
	if not _edges.values().has(EDGE_DYING) and _any_nonzero64(world.needs._starving_ticks):
		return EDGE_DYING
	return ""


func _any_nonzero32(column: PackedInt32Array) -> bool:
	"""Whether any entry is set."""
	for value: int in column:
		if value != 0:
			return true
	return false


func _any_nonzero64(column: PackedInt64Array) -> bool:
	"""Whether any entry is set."""
	for value: int in column:
		if value != 0:
			return true
	return false


func _lease_expires_within(world: SaveWorld.World, tick: int) -> bool:
	"""Whether a live reservation's lease runs out inside the coming window."""
	var reservations: RefCounted = world.reservations
	for row: int in reservations._occupied.size():
		var expiry: int = reservations._r_expiry[row]
		if reservations._occupied[row] == 1 and expiry > tick and expiry <= tick + EDGE_WINDOW:
			return true
	return false


func _record_uninterrupted(source: Node) -> void:
	"""Run 3000 -> 18000 recording every tick; save at each coverage case and at each window end."""
	var world: SaveWorld.World = SaveWorld.bind(source, GameManager)
	_running = source
	_fingerprint.bind(world)
	_recording = true
	var window_ends: Array[int] = [END_TICK]
	assert_true(GameManager.bind_simulation(_step, _day), "bind the recording step")
	while GameManager.clock().completed_tick() < END_TICK:
		GameManager.advance_host_time(FRAME_USEC)
		var tick: int = GameManager.clock().completed_tick()
		var edge: String = _edge_at(world, tick)
		if edge != "" or window_ends.has(tick):
			GameManager.unbind_simulation()
			_saves[tick] = _saved(source)
			if edge != "":
				_edges[tick] = edge
				window_ends.append(tick + EDGE_WINDOW)
			assert_true(GameManager.bind_simulation(_step, _day), "rebind")
	GameManager.unbind_simulation()
	assert_equal(_expected.size(), END_TICK - START_TICK, "one fingerprint per tick 3001-18000")


# --- the reloaded runs ----------------------------------------------------------------------------

func _replay(from_tick: int, to_tick: int) -> void:
	"""Load the save taken at `from_tick` into a fresh settlement, run it to `to_tick` comparing every
	tick's fingerprint with the uninterrupted run's, then compare the two saves at `to_tick`."""
	var target: Node = _settlement()
	var loaded: SaveHeader.Refusal = SettlementSave.load_bytes(target, GameManager, _saves[from_tick])
	assert_true(loaded.is_ok(), "load at %d: %s %s" % [from_tick, loaded.code, loaded.detail])
	if not loaded.is_ok():
		return
	assert_equal(GameManager.clock().completed_tick(), from_tick, "the clock is back at the save")
	_running = target
	_fingerprint.bind(SaveWorld.bind(target, GameManager))
	_recording = false
	_first_mismatch = -1
	assert_true(GameManager.bind_simulation(_step, _day), "bind the comparing step")
	while GameManager.clock().completed_tick() < to_tick:
		GameManager.advance_host_time(FRAME_USEC)
	GameManager.unbind_simulation()
	assert_equal(_first_mismatch, -1, "%d -> %d: every tick matches (first difference at %d)"
		% [from_tick, to_tick, _first_mismatch])
	assert_true(_saved(target) == _saves[to_tick], "%d -> %d: the saves at %d are byte-identical"
		% [from_tick, to_tick, to_tick])


func test_a_save_at_3000_continues_tick_for_tick_to_18000_with_its_coverage_cases() -> void:
	"""ARCH-SAVE-006: the fork at 3000 with a pending command, every tick to 18000, and each
	coverage case found on the way, each compared tick for tick over its own window."""
	assert_true(GameManager.start_game(), "a fresh clock")
	var source: Node = _settlement()
	assert_true(source.create_generated_settlement(source.item_definitions()), "generates")
	_advance_plain(source, START_TICK)
	_queue_pending_command(source)
	_starve_one(source)
	_saves[START_TICK] = _saved(source)
	_record_uninterrupted(source)
	assert_equal(_fingerprint.resolved_count() + _unmounted_fields(), _fingerprint.declared_count(),
		"every declared field is fingerprinted except the unmounted underground owners'")
	print("SAVE-PARITY coverage cases: %s" % [_edges])
	_replay(START_TICK, END_TICK)
	for tick: int in _edges:
		_replay(tick, tick + EDGE_WINDOW)
	for edge: String in [EDGE_MIDNIGHT, EDGE_BATCH, EDGE_LEASE, EDGE_DYING]:
		assert_equal(_edges.values().has(edge), REACHED_CASES.has(edge), "the %s case reached" % edge)


func _unmounted_fields() -> int:
	"""How many declared fields belong to owners an unmounted settlement has no instance of."""
	var total: int = 0
	var unresolved: Dictionary = _fingerprint.unresolved_owners()
	for key: String in unresolved:
		assert_true(UNMOUNTED_OWNERS.has(key), "%s has a live instance and must be covered" % key)
		total += int(unresolved[key])
	return total
