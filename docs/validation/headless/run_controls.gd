extends SceneTree
## Standalone Mac/Windows engine comparison runner. Invoked with --script.

const WinterWorld = preload("res://winter_world.gd")
const Checkpoint = preload("res://control_checkpoint.gd")
const Foundation = preload("res://test_foundation.gd")
var failures: Array[String] = []
var checks: int = 0
var output_path: String = ""
var foundation: Dictionary = {}
var checkpoint_input: String = ""


func _initialize() -> void:
	## Defer execution until SceneTree initialization is complete.
	call_deferred(&"run")


func check(condition: bool, label: String) -> void:
	## Collect failures and exit nonzero instead of silently accepting a broken run.
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func run() -> void:
	## Execute fixed fixtures, both winters and exact next-tick checkpoint comparison.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not (args.size() == 2 or args.size() == 4) or args[0] != "--output":
		printerr("Expected -- --output ABSOLUTE_REPORT_PATH [--checkpoint-input ABSOLUTE_PATH]")
		quit(2)
		return
	output_path = args[1]
	if args.size() == 4:
		if args[2] != "--checkpoint-input":
			quit(2)
			return
		checkpoint_input = args[3]
	check(Engine.get_version_info()["string"] == "4.7.2-stable (official)", "pinned engine display version")
	test_boundaries()
	foundation = Foundation.run(Callable(self, &"check"))
	var results: Array[Dictionary] = []
	for enabled: bool in [false, true]:
		var world: RefCounted = WinterWorld.new(enabled)
		while world.tick < 12 * WinterWorld.DAY and world.living() > 0:
			world.step()
		results.append(world.result())
		print("WINTER ", enabled, " complete at tick ", world.tick)
	var replay: Dictionary = test_checkpoint()
	write_report(results, replay)
	quit(0 if failures.is_empty() else 1)


func test_boundaries() -> void:
	## Verify independently derived thresholds before comparing complete controls.
	var world: RefCounted = WinterWorld.new(false)
	check(world.ready() == 267840 and world.daily_demand() == 89280, "three exact ready food-days")
	check(Checkpoint.audit_field_coverage(world), "every mutable field included in checkpoint")
	world.need[&"hunger"][0] = 3000 * WinterWorld.DEN
	check(world.start_eat(0), "start meal")
	for index: int in range(149):
		world.step()
	check(world.consumed_np == 0, "149 intervals do not consume a meal")
	world.step()
	check(world.consumed_np == 2400 and world.counters[&"eat"][0] == 150, "150 complete meal intervals")
	check(world.need[&"hunger"][0] == 5340 * WinterWorld.DEN, "meal need arithmetic")
	check(WinterWorld.integer_sqrt(319999 / 5000) == 7, "below skill eight boundary")
	check(WinterWorld.integer_sqrt(320000 / 5000) == 8, "skill eight boundary")
	check(WinterWorld.integer_sqrt(9223372036854775807) == 3037000499, "int64 square root boundary")
	test_schedule()


func test_schedule() -> void:
	## Sleep interruption and social cutoff cannot wait until the next day.
	var world: RefCounted = WinterWorld.new(false)
	world.need[&"hunger"][0] = 1500 * WinterWorld.DEN
	world.need[&"rest"][0] = 5000 * WinterWorld.DEN
	world.state[0] = 2
	world.step()
	check(world.state[0] == 1 and world.until_tick[0] == 151, "urgent food interrupts sleep")
	world = WinterWorld.new(false)
	world.tick = 20 * WinterWorld.HOUR - 1
	world.state[0] = 3
	world.step()
	check(world.state[0] != 3, "social window ends at 20:00 boundary")


func test_checkpoint() -> Dictionary:
	## Compare every tick 3001–18000 against an uninterrupted control after disk reload.
	var original: RefCounted = WinterWorld.new(true)
	while original.tick < 3000:
		original.step()
	var data: PackedByteArray = Checkpoint.encode(original)
	if not checkpoint_input.is_empty():
		data = FileAccess.get_file_as_bytes(checkpoint_input)
	var checkpoint_path: String = output_path.get_base_dir().path_join("winter.control")
	var file: FileAccess = FileAccess.open(checkpoint_path, FileAccess.WRITE)
	check(file != null, "checkpoint disk open")
	if file == null:
		return {"status": "FAIL"}
	file.store_buffer(data)
	file.close()
	var restored: RefCounted = WinterWorld.new(true)
	check(Checkpoint.restore(restored, FileAccess.get_file_as_bytes(checkpoint_path)), "checkpoint disk restore")
	check(Checkpoint.digest(original) == Checkpoint.digest(restored), "saved boundary state equality")
	var report: Dictionary = compare_continuation(original, restored)
	test_corruption(restored, data)
	check(Checkpoint.restore(restored, data), "valid older checkpoint replaces advanced state")
	check(restored.tick == 3000, "older checkpoint restores original tick")
	return report


func compare_continuation(original: RefCounted, restored: RefCounted) -> Dictionary:
	## Report the first exact divergence; all comparisons use completed integer ticks.
	var compared: int = 0
	var hash_path: String = output_path.get_base_dir().path_join("checkpoint_hashes.csv")
	var hash_file: FileAccess = FileAccess.open(hash_path, FileAccess.WRITE)
	check(hash_file != null, "replay hash log open")
	if hash_file == null:
		return {"status": "FAIL"}
	hash_file.store_line("tick,state_sha256")
	hash_file.store_line("%d,%s" % [original.tick, Checkpoint.digest(original)])
	while original.tick < 18000:
		original.step()
		restored.step()
		var state_hash: String = Checkpoint.digest(original)
		if state_hash != Checkpoint.digest(restored):
			check(false, "checkpoint divergence at tick %d" % original.tick)
			hash_file.close()
			return {"status": "FAIL", "first_divergence_tick": original.tick}
		hash_file.store_line("%d,%s" % [original.tick, state_hash])
		compared += 1
	hash_file.close()
	check(compared == 15000, "15000 next-tick state comparisons")
	return {"status": "PASS", "saved_tick": 3000, "through_tick": 18000,
		"compared_ticks": compared, "final_sha256": Checkpoint.digest(original)}


func test_corruption(world: RefCounted, valid_data: PackedByteArray) -> void:
	## A truncated or tampered checkpoint must leave existing state untouched.
	var before: String = Checkpoint.digest(world)
	var corrupt: PackedByteArray = valid_data.duplicate()
	corrupt[-1] ^= 1
	check(not Checkpoint.restore(world, corrupt), "corrupt payload rejected")
	check(Checkpoint.digest(world) == before, "corruption preserves current world")
	check(not Checkpoint.restore(world, valid_data.slice(0, 20)), "truncated header rejected")
	check(Checkpoint.digest(world) == before, "truncation preserves current world")


func write_report(results: Array[Dictionary], replay: Dictionary) -> void:
	## Save engine identity and factual scope with every result.
	var report: Dictionary = {"status": "PASS_ISOLATED_GODOT_CONTROL" if failures.is_empty() else "FAIL",
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "checks": checks, "failures": failures,
		"results": results, "checkpoint_parity": replay,
		"foundation": foundation,
		"checkpoint_source": "local_control" if checkpoint_input.is_empty() else "supplied_file",
		"scope": "Isolated winter model only; no three-year or renderer qualification. Reference checkpoint is not the release save format."}
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		check(false, "report output could not be opened")
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("CONTROL CHECKS: ", checks, " FAILURES: ", failures.size())
