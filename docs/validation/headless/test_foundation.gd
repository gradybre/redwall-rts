extends RefCounted
## Boundary and invariant tests for the two independently usable foundation kernels.

const Slots = preload("res://resident_slots.gd")
const Clock = preload("res://fixed_clock.gd")
const World = preload("res://winter_world.gd")
const Checkpoint = preload("res://control_checkpoint.gd")


static func run(check: Callable) -> Dictionary:
	## Report clock/grouping evidence without claiming rendering performance.
	test_identity(check)
	test_exhaustion(check)
	test_clock(check)
	test_overload(check)
	test_economy_fixtures(check)
	return test_grouping(check)


static func test_economy_fixtures(check: Callable) -> void:
	## Reproduce GDD section 7.1 directly in Godot's integer arithmetic.
	var mixed_size: int = 120 * 1000 + 60 * 1200 + 20 * 1600
	check.call(mixed_size * 6000 / 1000 == 1344000, "GDD mixed-cohort baseline NP")
	check.call(mixed_size * 6000 * 1200 / 1000000 == 1612800, "GDD mixed-cohort winter NP")
	var grain_milli: int = 64 * 10000 * (500 + 7000 / 20) / 1000
	check.call(grain_milli == 544000, "GDD grain yield at fertility 7000")
	var replacement_grain: int = (64 * 250) / 4
	check.call((grain_milli - replacement_grain) * 1800 / 1000 == 972000, "GDD seed-replacement edible NP")
	check.call((64 * 4 + 64 * 8 + 64 * 6) == 1152, "GDD field sow/tend/harvest WU")
	var reserve_rations: int = (200 * 6000 * 1200 / 1000 * 12) / 2400 * 115 / 100
	check.call(reserve_rations == 8280, "GDD winter ration reserve")
	check.call(reserve_rations / 3 * 24 == 66240, "GDD winter ration work")
	check.call((reserve_rations * 500 + 999999) / 1000000 == 5, "GDD reserve cellar count")
	check.call(40 + 4 * 4 + 10 + 5000 / 1000 - 2500 * 20 / 10000 == 66, "GDD quality score")
	check.call(3 * 2200 * 1050 / 1000 == 6930, "GDD good fish-stew NP")
	check.call((3 * 6000 + 2 * 7000 + 2 * 5000 + 4000 + 2 * 8000) / 10 + 300 == 6500, "GDD mood example")


static func test_identity(check: Callable) -> void:
	## Verify living cap, lowest free index and stale-reference refusal.
	var pool: RefCounted = Slots.new()
	for index: int in range(256):
		var ref: PackedInt32Array = pool.create()
		check.call(ref == PackedInt32Array([index, 1]), "ascending initial slot %d" % index)
	var next_id: int = pool.next_persistent_id
	check.call(pool.create() == PackedInt32Array([-1, 0]), "257th living resident refused")
	check.call(pool.next_persistent_id == next_id and pool.living_count == 256, "refusal does not consume identity")
	check.call(pool.destroy(5, 1) and pool.destroy(2, 1), "nonadjacent releases")
	var first: PackedInt32Array = pool.create()
	var second: PackedInt32Array = pool.create()
	check.call(first == PackedInt32Array([2, 2]) and second == PackedInt32Array([5, 2]), "lowest released slots reused")
	check.call(not pool.valid(2, 1) and not pool.destroy(2, 1), "stale handle cannot affect replacement")
	check.call(pool.persistent_id[2] == 257 and pool.persistent_id[5] == 258, "persistent IDs never reused")
	check.call(not pool.valid(-1, 0) and not pool.valid(512, 1), "invalid bounds refused")


static func test_exhaustion(check: Callable) -> void:
	## Generation retirement and global ID exhaustion cannot wrap into old identities.
	var pool: RefCounted = Slots.new()
	pool.generation[0] = 2147483646
	var ref: PackedInt32Array = pool.create()
	check.call(ref == PackedInt32Array([0, 2147483647]), "last generation usable once")
	check.call(pool.destroy(ref[0], ref[1]), "last generation destroyed")
	check.call(pool.create()[0] == 1 and pool.free_count == 510, "exhausted slot retired permanently")
	pool = Slots.new()
	pool.next_persistent_id = 2147483647
	ref = pool.create()
	check.call(pool.persistent_id[ref[0]] == 2147483647, "last persistent ID issued")
	check.call(pool.create()[0] == -1 and pool.living_count == 1, "persistent ID exhaustion refuses without wrap")


static func test_clock(check: Callable) -> void:
	## Clock frequency is independent of host frame partitioning and uses the initial offset.
	for speed: int in [1, 2, 4]:
		var clock: RefCounted = Clock.new()
		check.call(clock.advance(1000000) == 0, "initial pause accrues no ticks")
		clock.set_pause(Clock.PLAYER, false)
		clock.set_speed(speed)
		for frame: int in range(100):
			clock.advance(10000)
		check.call(clock.completed_tick == 30 * speed and clock.debt == 0, "exact one-second tick rate %dx" % speed)
	var clock: RefCounted = Clock.new()
	check.call(not clock.set_speed(3) and clock.requested_speed == 1, "3x speed rejected")
	check.call(clock.calendar() == PackedInt32Array([1, 1, 0, 1, 6]), "initial 06:00 calendar")
	clock.completed_tick = 13499
	check.call(clock.calendar()[0] == 1 and clock.calendar()[4] == 23, "tick before first midnight")
	clock.completed_tick += 1
	check.call(clock.calendar() == PackedInt32Array([2, 1, 0, 2, 0]), "first midnight at tick 13500")
	clock.set_pause(Clock.MENU, true)
	clock.set_pause(Clock.PLAYER, false)
	check.call(clock.advance(1000000) == 0, "menu pause remains after player unpause")


static func test_overload(check: Callable) -> void:
	## Debt is retained during fallback/pause and exactly-on-boundary backlog is allowed.
	var clock: RefCounted = Clock.new()
	clock.set_pause(Clock.PLAYER, false)
	clock.debt = 15500000
	clock.advance(0)
	check.call(clock.debt == 7500000 and clock.pause_mask == 0, "exact quarter-second backlog allowed")
	clock = Clock.new()
	clock.set_pause(Clock.PLAYER, false)
	clock.set_speed(4)
	check.call(clock.advance(1000000) == 8, "catch-up limited to eight ticks")
	check.call(clock.debt == 112000000 and clock.requested_speed == 2, "4x fallback retains debt")
	clock.advance(0)
	check.call(clock.debt == 104000000 and clock.requested_speed == 1, "2x fallback retains debt")
	clock.advance(0)
	check.call(clock.debt == 96000000 and clock.pause_mask == Clock.CRITICAL, "1x overload pauses")
	check.call(clock.advance(1000000) == 0 and clock.debt == 96000000, "paused debt is retained")
	clock.acknowledge_without_catchup()
	check.call(clock.completed_tick == 24 and clock.debt == 0, "explicit catch-up reset changes no gameplay tick")


static func test_grouping(check: Callable) -> Dictionary:
	## Same completed tick must have identical control state at 1x, 2x and 4x.
	var hashes: Dictionary = {}
	for speed: int in [1, 2, 4]:
		var clock: RefCounted = Clock.new()
		var world: RefCounted = World.new(true)
		clock.set_pause(Clock.PLAYER, false)
		clock.set_speed(speed)
		while clock.completed_tick < 18000:
			clock.advance(10000, Callable(world, &"step"))
		check.call(clock.completed_tick == 18000 and world.tick == 18000, "world/clock tick alignment %dx" % speed)
		hashes[str(speed)] = Checkpoint.digest(world)
	check.call(hashes["1"] == hashes["2"] and hashes["2"] == hashes["4"], "1x/2x/4x completed-tick state parity")
	return {"through_tick": 18000, "same_state_across_speeds": hashes["1"] == hashes["2"] and hashes["2"] == hashes["4"], "hashes": hashes}
