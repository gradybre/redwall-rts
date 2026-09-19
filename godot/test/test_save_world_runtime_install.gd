extends "res://test/framework/test_case.gd"
## Adversarial suite for SAVE-W1-R02's clock/RNG install join.
##
## REAL OWNERS ONLY. A real GameManager, a real RNG store and BOTH real codecs: every record
## under test is produced by `encode_block`/`encode_store` and read back by `decode_into`, because
## a helper that installs a hand-built record proves nothing about the bytes a load will hold.
##
## THE TEST THAT MATTERS MOST is the draw-parity one: a restored stream must produce the SAME next
## values as the uninterrupted source. A stream resumed one draw early still yields perfectly
## plausible numbers and diverges silently, which is the failure section 10 exists to prevent.
##
## FAULT INJECTION IS CONFINED TO TEST SUBCLASSES overriding the PUBLIC `seed_world`,
## `restore_stream` and `restore_clock_runtime` APIs. There is no flag in production code, and the
## rollback paths are therefore genuinely executed rather than reasoned about.

const Install := preload("res://scripts/core/save_world_runtime_install.gd")
const WorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const SaveSectionRng := preload("res://scripts/core/save_section_rng.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const WORLD_SEED: int = 20260919
const PRIOR_SEED: int = 771131
const SAVED_TICK: int = 54321
const SAVED_DEBT: int = 2500001
## Six distinct nonzero counters, so no test can pass by copying one field into another.
const COUNTERS: Array[int] = [11, 22, 33, 44, 55, 66]

var _manager: GameManagerScript = null
var _nodes: Array[Node] = []
var _store: RngScript = null
var _source: RngScript = null
var _signals: Array[String] = []


class FaultRng extends RngScript:
	"""Test store that refuses ONE public operation, so a rollback path actually executes."""
	var fail_stream: int = -1
	var seed_calls_before_failure: int = -1
	var stream_calls_before_failure: int = -1

	func restore_stream(stream_id: int, state: int, draw_count: int) -> RngScript.OpResult:
		"""Refuse the first restore of `fail_stream`, then behave exactly like the real store."""
		if stream_calls_before_failure == 0:
			stream_calls_before_failure = -1
			return RngScript.OpResult.new(false, &"TEST_ROLLBACK_STREAM_REFUSED", 0)
		if stream_calls_before_failure > 0:
			stream_calls_before_failure -= 1
		if stream_id == fail_stream:
			fail_stream = -1
			return RngScript.OpResult.new(false, &"TEST_STREAM_REFUSED", 0)
		return super.restore_stream(stream_id, state, draw_count)

	func seed_world(world_seed: int) -> RngScript.OpResult:
		"""Refuse the seeding `seed_calls_before_failure` calls from now, then behave normally."""
		if seed_calls_before_failure == 0:
			seed_calls_before_failure = -1
			return RngScript.OpResult.new(false, &"TEST_SEED_REFUSED", 0)
		if seed_calls_before_failure > 0:
			seed_calls_before_failure -= 1
		return super.seed_world(world_seed)


class FaultManager extends GameManagerScript:
	"""Test manager that refuses ONE clock install, so the clock-side failure path executes."""
	var fail_next_restore: bool = false

	func restore_clock_runtime(completed_tick: int, debt: int, requested_speed: int,
			pause_mask: int, fallback_count: int, diagnostic_pause_count: int,
			acknowledged_catchup_resets: int, acknowledged_ticks_discarded: int,
			subtick_debt_discards: int, day_boundaries_crossed: int) -> bool:
		"""Refuse once without writing, then defer to the real validated assignment boundary."""
		if fail_next_restore:
			fail_next_restore = false
			return false
		return super.restore_clock_runtime(completed_tick, debt, requested_speed, pause_mask,
			fallback_count, diagnostic_pause_count, acknowledged_catchup_resets,
			acknowledged_ticks_discarded, subtick_debt_discards, day_boundaries_crossed)


func before_each() -> void:
	"""Build a source world, a differently seeded target store and an opened manager."""
	_nodes = []
	_signals = []
	_source = _advanced_store(RngScript.new(), WORLD_SEED)
	_store = _advanced_store(RngScript.new(), PRIOR_SEED)
	_manager = _open(GameManagerScript.new())


func after_each() -> void:
	"""Free every Node fixture the test built, including the fault-injecting managers."""
	for node: Node in _nodes:
		node.free()
	_nodes = []
	_manager = null
	_store = null
	_source = null


func _open(manager: GameManagerScript) -> GameManagerScript:
	"""Track a manager for freeing, record its four UI signals, and open its load barrier."""
	_nodes.append(manager)
	manager.state_changed.connect(_on_state)
	manager.speed_changed.connect(_on_speed)
	manager.day_advanced.connect(_on_day)
	manager.clock_diagnostic.connect(_on_diagnostic)
	var submitted: SchedulerEventsScript.SubmitResult = SchedulerEventsScript.SubmitResult.new()
	assert_true(manager.scheduler_events().submit_speed_into(SimClockScript.SPEED_QUADRUPLE,
		submitted), "a real pending command exists before the barrier")
	assert_true(manager.begin_load(), "the load barrier opened")
	return manager


func _advanced_store(store: RngScript, world_seed: int) -> RngScript:
	"""Seed a store and advance each live stream by a DIFFERENT number of draws."""
	assert_true(store.seed_world(world_seed).ok, "fixture seed succeeds")
	for stream_id: int in RngScript.STREAM_COUNT:
		if RngScript.is_retired(stream_id):
			continue
		for _index: int in stream_id + 2:
			assert_true(store.draw(stream_id).ok, "fixture draw succeeds")
	return store


func _world(tick: int, debt: int, speed: int, mask: int, all_counters: int = -1) -> WorldRuntime.Record:
	"""A WorldRuntime record carried through encode_block/decode_into, as a real load would be."""
	var record: WorldRuntime.Record = WorldRuntime.Record.new()
	record.completed_tick = tick
	record.world_seed = WORLD_SEED
	record.rng_seeded = true
	record.requested_speed = speed
	record.pause_mask = mask
	record.debt = debt
	for index: int in WorldRuntime.COUNTER_COUNT:
		record.counters[index] = COUNTERS[index] if all_counters < 0 else all_counters
	var encoded: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	assert_true(WorldRuntime.encode_block(record, encoded), "encode_block: %s" % encoded.detail)
	var back: WorldRuntime.Record = WorldRuntime.Record.new()
	assert_true(WorldRuntime.decode_into(encoded.bytes, 0, back).is_ok(), "the block decodes")
	return back


func _streams(store: RngScript) -> SaveSectionRng.Record:
	"""A section 10 record carried through encode_store/decode_into, as a real load would be."""
	var encoded: SaveSectionRng.EncodeResult = SaveSectionRng.EncodeResult.new()
	assert_true(SaveSectionRng.encode_store(store, encoded), "encode_store: %s" % encoded.detail)
	var back: SaveSectionRng.Record = SaveSectionRng.Record.new()
	assert_true(SaveSectionRng.decode_into(encoded.bytes, 0, back).is_ok(), "section 10 decodes")
	return back


func _install(world: WorldRuntime.Record, streams: SaveSectionRng.Record,
		manager: GameManagerScript, store: RngScript) -> SaveHeader.Refusal:
	"""Run the production install with the header tick taken from the record itself."""
	return Install.install(world, streams, world.completed_tick, manager, store)


func _clock_ten(manager: GameManagerScript) -> Array[int]:
	"""The clock's ten runtime scalars in `restore_runtime()` argument order."""
	var clock: SimClockScript = manager.clock()
	return [clock.completed_tick(), clock.debt(), clock.requested_speed(), clock.pause_mask(),
		clock.fallback_count(), clock.diagnostic_pause_count(),
		clock.acknowledged_catchup_resets(), clock.acknowledged_ticks_discarded(),
		clock.subtick_debt_discards(), clock.day_boundaries_crossed()] as Array[int]


func _rng_image(store: RngScript) -> Array[int]:
	"""Seeded flag plus every stream's state and draw count, for byte-identical comparisons."""
	var image: Array[int] = [1 if store.is_seeded() else 0] as Array[int]
	if not store.is_seeded():
		return image
	var seed_value: IntMathScript.IntResult = store.world_seed_value()
	assert_true(seed_value.ok, "image reads a valid seed")
	image.append(seed_value.value)
	for stream_id: int in RngScript.STREAM_COUNT:
		var state: IntMathScript.IntResult = store.state_of(stream_id)
		var count: IntMathScript.IntResult = store.draw_count_of(stream_id)
		assert_true(state.ok and count.ok, "image reads valid state/count")
		image.append(state.value)
		image.append(count.value)
	return image


func _expected_ten(tick: int, debt: int, speed: int, mask: int) -> Array[int]:
	"""The ten scalars a successful install of these four values must produce."""
	return [tick, debt, speed, mask, COUNTERS[0], COUNTERS[1], COUNTERS[2], COUNTERS[3],
		COUNTERS[4], COUNTERS[5]] as Array[int]


# --- the successful install ------------------------------------------------------------------------

func test_install_restores_every_clock_scalar_and_every_stream() -> void:
	"""Both owners land together: ten clock scalars and nine state/count pairs, all exact."""
	var world: WorldRuntime.Record = _world(SAVED_TICK, SAVED_DEBT,
		SimClockScript.SPEED_DOUBLE, SimClockScript.PLAYER)
	var refusal: SaveHeader.Refusal = _install(world, _streams(_source), _manager, _store)
	assert_true(refusal.is_ok(), "install accepted: %s %s" % [refusal.code, refusal.detail])
	assert_equal(_clock_ten(_manager), _expected_ten(SAVED_TICK, SAVED_DEBT,
		SimClockScript.SPEED_DOUBLE, SimClockScript.PLAYER), "all ten clock scalars are exact")
	assert_equal(_rng_image(_store), _rng_image(_source), "and the whole RNG image matches")


func test_restored_streams_continue_the_sources_sequence() -> void:
	"""The real acceptance: the next draws after a restore equal the uninterrupted ones."""
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store).is_ok(), "install accepted")
	for stream_id: int in RngScript.STREAM_COUNT:
		if RngScript.is_retired(stream_id):
			continue
		for index: int in 8:
			var actual: IntMathScript.IntResult = _store.draw(stream_id)
			var expected: IntMathScript.IntResult = _source.draw(stream_id)
			assert_true(actual.ok and expected.ok, "both continuation draws succeed")
			assert_equal(actual.value, expected.value,
				"stream %d draw %d matches the uninterrupted source" % [stream_id, index])


func test_the_hunting_tombstone_survives_canonical_and_undrawn() -> void:
	"""SET-AMEND-001 §3: the retired slot keeps its seed rule and zero count across the install."""
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store).is_ok(), "install accepted")
	assert_true(_store.tombstone_is_intact(), "HUNTING is still canonical for the NEW seed")
	assert_equal(_store.draw_count_of(RngScript.STREAM_HUNTING).value, 0, "and undrawn")


func test_a_different_prior_seed_is_legal_and_is_replaced() -> void:
	"""Loading another save replaces the world seed; seed equality is not world identity."""
	assert_equal(_store.world_seed_value().value, PRIOR_SEED, "the target held another seed")
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store).is_ok(), "which is accepted, not refused")
	assert_equal(_store.world_seed_value().value, WORLD_SEED, "and replaced by section 1's")


func test_a_previously_unseeded_target_is_installed_too() -> void:
	"""An unseeded store has a canonical clear state and needs no prior section 10 image."""
	var fresh: RngScript = RngScript.new()
	assert_false(fresh.is_seeded(), "the target starts unseeded")
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, fresh).is_ok(), "install accepted")
	assert_equal(_rng_image(fresh), _rng_image(_source), "and the whole image matches")


func test_every_named_debt_speed_and_mask_installs_exactly() -> void:
	"""The ruling's debt values, all three speeds and a composite mask, each unscaled."""
	var debts: Array[int] = [1, 999999, 1000000, 2500001] as Array[int]
	var masks: Array[int] = [0, SimClockScript.PLAYER,
		SimClockScript.MENU | SimClockScript.CRITICAL,
		SimClockScript.PLAYER | SimClockScript.VICTORY] as Array[int]
	for index: int in debts.size():
		var speed: int = SimClockScript.SELECTABLE_SPEEDS[index % 3]
		var manager: GameManagerScript = _open(GameManagerScript.new())
		var target: RngScript = _advanced_store(RngScript.new(), PRIOR_SEED)
		assert_true(_install(_world(SAVED_TICK + index, debts[index], speed, masks[index]),
			_streams(_source), manager, target).is_ok(), "install %d accepted" % index)
		assert_equal(_clock_ten(manager), _expected_ten(SAVED_TICK + index, debts[index],
			speed, masks[index]), "debt %d, speed %d, mask %d are exact"
				% [debts[index], speed, masks[index]])


func test_a_player_pause_with_sub_tick_debt_does_not_zero_it() -> void:
	"""The whole reason this is not `set_pause()`: that path drops sub-tick debt and counts it."""
	assert_true(_install(_world(SAVED_TICK, 999999, SimClockScript.SPEED_NORMAL,
		SimClockScript.PLAYER), _streams(_source), _manager, _store).is_ok(), "install accepted")
	assert_equal(_manager.clock().debt(), 999999, "the saved sub-tick debt survived")
	assert_equal(_manager.clock().subtick_debt_discards(), COUNTERS[4],
		"and the discard counter is the saved one, not one higher")


func test_the_terminal_representable_tick_and_debt_install() -> void:
	"""The calendar ceiling and the whole int64 debt domain are representable, not refused."""
	var tick: int = WorldRuntime.COMPLETED_TICK_MAX
	assert_true(_install(_world(tick, WorldRuntime.DEBT_MAX, SimClockScript.SPEED_QUADRUPLE,
		WorldRuntime.KNOWN_PAUSE_BITS, WorldRuntime.DEBT_MAX), _streams(_source), _manager, _store).is_ok(),
		"the terminal record installs")
	assert_equal(_manager.clock().completed_tick(), tick, "at the calendar ceiling exactly")
	assert_equal(_manager.clock().debt(), WorldRuntime.DEBT_MAX, "with the largest legal debt")
	for value: int in _clock_ten(_manager).slice(4):
		assert_equal(value, WorldRuntime.DEBT_MAX, "every terminal counter remains exact")


func test_install_emits_no_signal_and_changes_no_queue_state() -> void:
	"""Restore is not a command: no tick, day, state or speed event, and no queue admission."""
	var admitted: int = _manager.scheduler_events().admitted_count()
	var pending: int = _manager.scheduler_events().pending_count()
	var pumps: int = _manager.scheduler_events().pump_count()
	assert_true(pending > 0, "queue preservation has a nonempty positive control")
	var queue_before: PackedByteArray = _queue_image(_manager)
	assert_true(_install(_world(SimClockScript.FIRST_MIDNIGHT_TICK, 0,
		SimClockScript.SPEED_DOUBLE, 0), _streams(_source), _manager, _store).is_ok(), "accepted")
	assert_equal(_signals, [] as Array[String], "no signal was published at all")
	assert_equal(_manager.scheduler_events().admitted_count(), admitted, "nothing was admitted")
	assert_equal(_manager.scheduler_events().pending_count(), pending, "nothing was queued")
	assert_equal(_manager.scheduler_events().pump_count(), pumps, "and nothing was pumped")
	assert_true(_queue_image(_manager) == queue_before, "all queue/control bytes remain exact")


func test_install_leaves_the_load_open_unpublished_and_barred() -> void:
	"""Publication and release belong to the coordinator; this helper touches neither."""
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store).is_ok(), "install accepted")
	assert_true(_manager.is_loading(), "the load is still open")
	assert_true(_manager.is_load_barrier_held(), "the clock barrier is still held")
	assert_false(_manager.is_load_published(), "nothing was published")
	assert_false(_manager.clock().set_speed(SimClockScript.SPEED_DOUBLE),
		"so a raw command is still barred")


func test_install_retains_no_alias_of_either_input_record() -> void:
	"""Mutating the decoded records afterwards must not reach the installed world."""
	var world: WorldRuntime.Record = _world(SAVED_TICK, SAVED_DEBT,
		SimClockScript.SPEED_DOUBLE, SimClockScript.MENU)
	var streams: SaveSectionRng.Record = _streams(_source)
	var world_before: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	var streams_before: SaveSectionRng.EncodeResult = SaveSectionRng.EncodeResult.new()
	assert_true(WorldRuntime.encode_block(world, world_before), "snapshot input world")
	assert_true(SaveSectionRng.encode_record(streams, streams_before), "snapshot input streams")
	assert_true(_install(world, streams, _manager, _store).is_ok(), "install accepted")
	var world_after: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	var streams_after: SaveSectionRng.EncodeResult = SaveSectionRng.EncodeResult.new()
	assert_true(WorldRuntime.encode_block(world, world_after), "read input world after install")
	assert_true(SaveSectionRng.encode_record(streams, streams_after), "read input streams after install")
	assert_true(world_before.bytes == world_after.bytes, "every world input byte is unchanged")
	assert_true(streams_before.bytes == streams_after.bytes, "every stream input byte is unchanged")
	var image: Array[int] = _rng_image(_store)
	world.debt = 7
	world.counters[0] = 7
	streams.draw_counts[RngScript.STREAM_MAP] = 7
	assert_equal(_manager.clock().debt(), SAVED_DEBT, "the clock kept the installed debt")
	assert_equal(_manager.clock().fallback_count(), COUNTERS[0], "and the installed counter")
	assert_equal(_rng_image(_store), image, "and the store kept the installed image")


# --- refusals, each proving nothing moved -------------------------------------------------------------

func _assert_refused(refusal: SaveHeader.Refusal, code: StringName, clock: Array[int],
		image: Array[int], message: String) -> void:
	"""Assert a named refusal and that neither owner moved a single field."""
	assert_equal(refusal.code, code, message)
	assert_equal(_clock_ten(_manager), clock, "%s: the clock is byte-identical" % message)
	assert_equal(_rng_image(_store), image, "%s: the RNG is byte-identical" % message)


func test_null_inputs_are_refused_by_name() -> void:
	"""Four required objects, each refused as a null rather than crashing on a field read."""
	var world: WorldRuntime.Record = _world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0)
	var streams: SaveSectionRng.Record = _streams(_source)
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	_assert_refused(Install.install(null, streams, SAVED_TICK, _manager, _store),
		Install.REFUSE_NULL_INPUT, clock, image, "a null world refuses")
	_assert_refused(Install.install(world, null, SAVED_TICK, _manager, _store),
		Install.REFUSE_NULL_INPUT, clock, image, "a null stream record refuses")
	_assert_refused(Install.install(world, streams, SAVED_TICK, null, _store),
		Install.REFUSE_NULL_INPUT, clock, image, "a null manager refuses")
	_assert_refused(Install.install(world, streams, SAVED_TICK, _manager, null),
		Install.REFUSE_NULL_INPUT, clock, image, "a null store refuses")


func test_a_manager_with_no_open_load_is_refused() -> void:
	"""Both halves are required, and an outsider's raw grant is not this manager's load."""
	var closed: GameManagerScript = GameManagerScript.new()
	_nodes.append(closed)
	var outsider: SimClockScript.LoadBarrierGrant = closed.clock().acquire_load_barrier()
	assert_true(outsider.is_ok(), "someone else holds the raw clock barrier")
	assert_true(closed.is_load_barrier_held(), "so the clock reports a barrier")
	assert_false(closed.is_loading(), "while the manager holds no load of its own")
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), closed, _store)
	assert_equal(refusal.code, Install.REFUSE_NOT_LOADING, "the install refuses")
	assert_equal(closed.clock().completed_tick(), 0, "and that clock is untouched")
	assert_true(outsider.token.release(), "the outsider still owns the only route down")


func test_a_published_load_is_refused() -> void:
	"""Once a world is published this helper may not write over it."""
	assert_true(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store).is_ok(), "the first install is accepted")
	assert_true(_manager.publish_restored_world(), "and the coordinator publishes")
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	_assert_refused(_install(_world(9, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store), Install.REFUSE_ALREADY_PUBLISHED, clock, image,
		"a second install refuses")


func test_a_false_seeded_flag_is_refused() -> void:
	"""A release save carries all fifteen sections; section 10 has no valid unseeded shape."""
	var world: WorldRuntime.Record = _world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0)
	world.rng_seeded = false
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	_assert_refused(_install(world, _streams(_source), _manager, _store),
		Install.REFUSE_RNG_NOT_SEEDED, clock, image,
		"an unseeded section 1 refuses")


func test_a_header_tick_mismatch_is_refused() -> void:
	"""G3: the header's completed tick and section 1's must agree before anything is installed."""
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	var refusal: SaveHeader.Refusal = Install.install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), SAVED_TICK + 1, _manager, _store)
	_assert_refused(refusal, WorldRuntime.REFUSE_HEADER_TICK_MISMATCH, clock, image,
		"one tick apart refuses with the codec's own code")


func test_invalid_world_fields_are_refused_with_the_codecs_own_codes() -> void:
	"""Tick, speed, mask, debt and a counter, each refused before the first mutation."""
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	var cases: Array[StringName] = [WorldRuntime.REFUSE_NEGATIVE_TICK, WorldRuntime.REFUSE_SPEED,
		WorldRuntime.REFUSE_PAUSE_MASK, WorldRuntime.REFUSE_NEGATIVE_DEBT,
		WorldRuntime.REFUSE_NEGATIVE_COUNTER] as Array[StringName]
	for index: int in cases.size():
		var world: WorldRuntime.Record = _world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0)
		if index == 0:
			world.completed_tick = -1
		elif index == 1:
			world.requested_speed = 3
		elif index == 2:
			world.pause_mask = WorldRuntime.KNOWN_PAUSE_BITS + 1
		elif index == 3:
			world.debt = -1
		else:
			world.counters[5] = -1
		_assert_refused(Install.install(world, _streams(_source), world.completed_tick,
			_manager, _store), cases[index], clock, image, "case %d refuses" % index)


func test_invalid_stream_records_are_refused() -> void:
	"""Shape, the forbidden zero state, a negative count and both halves of the tombstone rule."""
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	var world: WorldRuntime.Record = _world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0)
	var zeroed: SaveSectionRng.Record = _streams(_source)
	zeroed.states[RngScript.STREAM_FORAGE] = 0
	_assert_refused(_install(world, zeroed, _manager, _store), SaveSectionRng.REFUSE_ZERO_STATE,
		clock, image, "a zero state refuses")
	var negative: SaveSectionRng.Record = _streams(_source)
	negative.draw_counts[RngScript.STREAM_MAP] = -1
	_assert_refused(_install(world, negative, _manager, _store),
		SaveSectionRng.REFUSE_NEGATIVE_DRAW_COUNT, clock, image, "a negative count refuses")
	var drawn: SaveSectionRng.Record = _streams(_source)
	drawn.draw_counts[RngScript.STREAM_HUNTING] = 1
	_assert_refused(_install(world, drawn, _manager, _store),
		SaveSectionRng.REFUSE_TOMBSTONE_DRAWN, clock, image, "a drawn tombstone refuses")
	_assert_refused(_install(world, _streams(_store), _manager, _store),
		SaveSectionRng.REFUSE_TOMBSTONE_STATE, clock, image,
		"and a section 10 from another seed refuses against section 1's")


func test_seed_range_and_column_shape_refuse_without_mutation() -> void:
	"""In-memory records must obey the same seed width and column lengths as wire records."""
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	var world: WorldRuntime.Record = _world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0)
	for seed_value: int in [2147483648, -2147483649]:
		world.world_seed = seed_value
		_assert_refused(_install(world, _streams(_source), _manager, _store),
			Install.REFUSE_SEED_NOT_INT32, clock, image, "out-of-i32 seed")
	world.world_seed = WORLD_SEED
	var streams: SaveSectionRng.Record = _streams(_source)
	streams.states.resize(1)
	var refusal: SaveHeader.Refusal = _install(world, streams, _manager, _store)
	assert_false(refusal.is_ok(), "truncated stream column refuses")
	assert_equal(_clock_ten(_manager), clock, "clock unchanged")
	assert_equal(_rng_image(_store), image, "including RNG seed and all stream positions")


func test_released_manager_barrier_refuses_without_mutation() -> void:
	"""A load that has ended cannot be reused as installation authority."""
	assert_true(_manager.rollback_load(), "the caller closes its load")
	var clock: Array[int] = _clock_ten(_manager)
	var image: Array[int] = _rng_image(_store)
	_assert_refused(_install(_world(SAVED_TICK, 0, SimClockScript.SPEED_NORMAL, 0),
		_streams(_source), _manager, _store), Install.REFUSE_NOT_LOADING, clock, image,
		"released manager")


# --- fault injection: the rollback paths actually run ---------------------------------------------

func test_a_failed_stream_restore_rolls_the_seeded_store_back() -> void:
	"""A refusal partway through the nine pairs leaves the target byte-identical."""
	var target: FaultRng = _advanced_store(FaultRng.new(), PRIOR_SEED) as FaultRng
	var image: Array[int] = _rng_image(target)
	var clock: Array[int] = _clock_ten(_manager)
	target.fail_stream = RngScript.STREAM_SOCIAL
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), _manager, target)
	assert_false(refusal.is_ok(), "the install refuses")
	assert_equal(refusal.code, SaveSectionRng.REFUSE_STORE_REFUSED, "with the codec's own code")
	assert_equal(_rng_image(target), image, "and the whole RNG image is back to its prior state")
	assert_equal(_clock_ten(_manager), clock, "while the clock was never written")


func test_a_failed_clock_install_rolls_the_seeded_store_back() -> void:
	"""RNG goes in first, so a clock refusal must undo it rather than leave a mixed world."""
	var manager: FaultManager = _open(FaultManager.new()) as FaultManager
	var image: Array[int] = _rng_image(_store)
	var clock: Array[int] = _clock_ten(manager)
	manager.fail_next_restore = true
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, SAVED_DEBT,
		SimClockScript.SPEED_DOUBLE, 0), _streams(_source), manager, _store)
	assert_equal(refusal.code, Install.REFUSE_CLOCK_INSTALL_FAILED, "the install refuses")
	assert_equal(_rng_image(_store), image, "the RNG is back to its prior state")
	assert_equal(_clock_ten(manager), clock, "and the clock is byte-identical")
	assert_true(manager.is_loading(), "with the load still open")


func test_a_failed_clock_install_clears_a_previously_unseeded_store() -> void:
	"""The other recovery branch: an unseeded store's canonical prior state is cleared."""
	var manager: FaultManager = _open(FaultManager.new()) as FaultManager
	var fresh: RngScript = RngScript.new()
	manager.fail_next_restore = true
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), manager, fresh)
	assert_equal(refusal.code, Install.REFUSE_CLOCK_INSTALL_FAILED, "the install refuses")
	assert_false(fresh.is_seeded(), "and the store is unseeded again")
	assert_false(fresh.state_of(0).ok, "an unseeded owner refuses state reads")


func test_a_failed_rollback_is_reported_explicitly_and_keeps_the_barrier() -> void:
	"""No byte-identical recovery is claimed, and the world is not released to anyone."""
	var manager: FaultManager = _open(FaultManager.new()) as FaultManager
	var target: FaultRng = _advanced_store(FaultRng.new(), PRIOR_SEED) as FaultRng
	manager.fail_next_restore = true
	target.seed_calls_before_failure = 1
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), manager, target)
	assert_equal(refusal.code, Install.REFUSE_ROLLBACK_FAILED, "the state is explicitly uncertain")
	assert_true(refusal.detail.contains("TEST_SEED_REFUSED"),
		"and the failing operation is named: %s" % refusal.detail)
	assert_true(manager.is_loading(), "the load is still open")
	assert_true(manager.is_load_barrier_held(), "the barrier is still held")
	assert_false(manager.is_load_published(), "and nothing was published")


func test_a_failed_initial_seed_recovers_the_prior_rng() -> void:
	"""Even a refused first write passes through checked recovery to the original seed/image."""
	var target: FaultRng = _advanced_store(FaultRng.new(), PRIOR_SEED) as FaultRng
	var image: Array[int] = _rng_image(target)
	var clock: Array[int] = _clock_ten(_manager)
	target.seed_calls_before_failure = 0
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), _manager, target)
	assert_equal(refusal.code, Install.REFUSE_RNG_SEED_FAILED, "seed failure stays explicit")
	assert_equal(_rng_image(target), image, "the entire prior RNG remains exact")
	assert_equal(_clock_ten(_manager), clock, "clock was never installed")
	assert_true(_manager.is_load_barrier_held(), "caller still owns its barrier")


func test_a_failed_recovery_stream_write_is_not_reported_as_recovered() -> void:
	"""The forward nine writes succeed; a clock refusal then exposes the first recovery write."""
	var manager: FaultManager = _open(FaultManager.new()) as FaultManager
	var target: FaultRng = _advanced_store(FaultRng.new(), PRIOR_SEED) as FaultRng
	target.stream_calls_before_failure = RngScript.STREAM_COUNT
	manager.fail_next_restore = true
	var refusal: SaveHeader.Refusal = _install(_world(SAVED_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), _streams(_source), manager, target)
	assert_equal(refusal.code, Install.REFUSE_ROLLBACK_FAILED, "partial recovery is uncertain")
	assert_true(refusal.detail.contains("restore_stream(0)"), "the failed write is identified")
	assert_true(refusal.detail.contains("TEST_ROLLBACK_STREAM_REFUSED"), "owner reason retained")
	assert_true(manager.is_load_barrier_held(), "the barrier remains held")
	assert_false(manager.is_load_published(), "caller has not published")


func test_the_adapter_declares_no_float_path() -> void:
	"""ARCH-AUTH-002: keep authoritative restore fields in integer representation."""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/save_world_runtime_install.gd")
	assert_true(source.length() > 0, "source read")
	assert_false(source.contains(": float"), "no float declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")


func _queue_image(manager: GameManagerScript) -> PackedByteArray:
	"""Serialize the actual pending queue and control header without draining it."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(manager.scheduler_events().extension_byte_length())
	assert_true(manager.scheduler_events().encode_extension_into(bytes, 0), "queue snapshot succeeds")
	return bytes


# --- signal recorders ------------------------------------------------------------------------------

func _on_state(new_state: int) -> void:
	"""Record a coarse state transition, which an install must never cause."""
	_signals.append("state:%d" % new_state)


func _on_speed(speed: int) -> void:
	"""Record a speed publication, which an install must never cause."""
	_signals.append("speed:%d" % speed)


func _on_day(absolute_day: int) -> void:
	"""Record a day boundary, which an install must never replay."""
	_signals.append("day:%d" % absolute_day)


func _on_diagnostic(message: String) -> void:
	"""Record a scheduler diagnostic, which an install must never raise."""
	_signals.append("diagnostic:%s" % message)
