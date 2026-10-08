extends "res://test/framework/test_case.gd"
## Save slots, autosave timing and startup recovery (ADR 1228; DEC-055 Q2, Q4, Q5, Q10). Every
## file goes under TEST_ROOT, never the player's own saves.

const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")

const TEST_ROOT: String = "user://test_settlement_save_slots"

var _settlement: Node = null
var _manager: Node = null


func before_each() -> void:
	"""A generated settlement, its own manager and an empty test slot root."""
	_remove_tree(TEST_ROOT)
	Slots.root = TEST_ROOT
	_settlement = SettlementSystemScript.new()
	_manager = GameManagerScript.new()
	assert_true(_settlement.create_generated_settlement(_settlement.item_definitions()), "generates")


func after_each() -> void:
	"""Free both nodes, restore the slot root and delete the test files."""
	_settlement.free()
	_manager.free()
	Slots.root = Slots.ROOT
	_remove_tree(TEST_ROOT)


func _remove_tree(directory: String) -> void:
	"""Delete every file one level under each kind directory, then the directories."""
	var absolute: String = ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for kind: String in DirAccess.get_directories_at(directory):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [directory, kind]):
			DirAccess.remove_absolute("%s/%s/%s" % [absolute, kind, file_name])
		DirAccess.remove_absolute("%s/%s" % [absolute, kind])
	DirAccess.remove_absolute(absolute)


func test_slot_names_are_checked() -> void:
	"""Known kinds and 1-64 safe characters only; a bad slot refuses before any write."""
	assert_true(Slots.valid_slot(Slots.KIND_MANUAL, "Spring_camp-2"), "a manual name")
	assert_false(Slots.valid_slot("cloud", "a"), "an unknown kind")
	assert_false(Slots.valid_slot(Slots.KIND_MANUAL, ""), "an empty name")
	assert_false(Slots.valid_slot(Slots.KIND_MANUAL, "../escape"), "a path")
	assert_false(Slots.valid_slot(Slots.KIND_MANUAL, "x".repeat(65)), "too long")
	assert_equal(Slots.save_slot(_settlement, _manager, Slots.KIND_MANUAL, "a/b").code, Slots.REFUSE_SLOT,
		"refused")
	assert_true(Slots.list_slots(Slots.KIND_MANUAL).is_empty(), "nothing written")


func test_a_slot_saves_lists_and_loads_back_into_a_fresh_settlement() -> void:
	"""Save to a manual slot with its sidecar, list it, load it into a new settlement; the rollback
	checkpoint is gone after the success and the restored world saves identically."""
	var saved: SaveHeader.Refusal = Slots.save_slot(_settlement, _manager, Slots.KIND_MANUAL, "camp", "Camp")
	assert_true(saved.is_ok(), "save: %s %s" % [saved.code, saved.detail])
	var rows: Array[Dictionary] = Slots.list_slots(Slots.KIND_MANUAL)
	assert_equal(rows.size(), 1, "one slot")
	assert_equal([rows[0]["name"], rows[0]["label"], int(rows[0]["format_version"])],
		["camp", "Camp", SaveHeader.FORMAT_VERSION], "the sidecar row")
	var target: Node = SettlementSystemScript.new()
	var manager: Node = GameManagerScript.new()
	var loaded: SaveHeader.Refusal = Slots.load_slot(target, manager, Slots.KIND_MANUAL, "camp")
	assert_true(loaded.is_ok(), "load: %s %s" % [loaded.code, loaded.detail])
	var path: String = Slots.slot_path(Slots.KIND_MANUAL, "camp")
	assert_false(FileAccess.file_exists(path + Slots.ROLLBACK_SUFFIX), "no checkpoint left behind")
	var again: PackedByteArray = PackedByteArray()
	assert_true(SaveFile.read_file(path, again).is_ok(), "the slot reads")
	var resaved: PackedByteArray = PackedByteArray()
	assert_true(Slots.SettlementSave.save_bytes(target, manager, resaved).is_ok(), "the target saves")
	assert_true(resaved == again, "the loaded world saves identically to its slot")
	target.free()
	manager.free()


func test_a_populated_target_is_checkpointed_before_it_is_retired() -> void:
	"""Loading over a populated settlement writes its checkpoint first; a checkpoint that cannot be
	written refuses before the target is touched."""
	assert_true(Slots.save_slot(_settlement, _manager, Slots.KIND_QUICK, Slots.QUICK_NAME).is_ok(), "save")
	var target: Node = SettlementSystemScript.new()
	assert_true(target.create_generated_settlement(target.item_definitions()), "a populated target")
	var manager: Node = GameManagerScript.new()
	var bytes: PackedByteArray = PackedByteArray()
	assert_true(SaveFile.read_file(Slots.slot_path(Slots.KIND_QUICK, Slots.QUICK_NAME), bytes).is_ok(), "read")
	var population: int = target.residents().population()
	var under_a_file: String = Slots.slot_path(Slots.KIND_QUICK, Slots.QUICK_NAME) + "/x.rollback"
	var refused: SaveHeader.Refusal = Slots.SettlementSave.load_bytes(target, manager, bytes, null,
		under_a_file)
	assert_false(refused.is_ok(), "an unwritable checkpoint refuses")
	assert_equal(target.residents().population(), population, "the target was not touched")
	assert_false(manager.is_loading(), "no load was opened")
	target.free()
	manager.free()


func test_autosave_timing_follows_the_cadence_and_autumns_last_week() -> void:
	"""Daily autosaves rotate five slots on the chosen cadence; prewinter fires once a year at the
	first midnight of autumn's last week, even with autosave off."""
	assert_equal([Slots.daily_name(1), Slots.daily_name(5), Slots.daily_name(6)],
		["daily_0", "daily_4", "daily_0"], "five rotating slots")
	assert_false(Slots.daily_due(1, Slots.AUTOSAVE_DAILY), "never the opening day")
	assert_true(Slots.daily_due(2, Slots.AUTOSAVE_DAILY), "every day")
	assert_equal([Slots.daily_due(3, 3), Slots.daily_due(4, 3)], [false, true], "every third day")
	assert_false(Slots.daily_due(2, Slots.AUTOSAVE_OFF), "off")
	var autumn_last_week: int = 1 + 2 * 12 + (Slots.PREWINTER_SEASON_DAY - 1)
	assert_true(Slots.prewinter_due(autumn_last_week), "autumn day %d" % Slots.PREWINTER_SEASON_DAY)
	assert_false(Slots.prewinter_due(autumn_last_week - 1), "the day before")
	assert_true(Slots.prewinter_due(autumn_last_week + 48), "the next year")
	var scheduler: Slots.Scheduler = Slots.Scheduler.new()
	scheduler.cadence = Slots.AUTOSAVE_OFF
	scheduler.on_midnight(autumn_last_week, 0)
	assert_equal(scheduler.pending_count(), 1, "prewinter queued with autosave off")


func test_the_scheduler_waits_for_quiescence_then_reports_busy_after_thirty_ticks() -> void:
	"""A queued save is taken at the first quiescent poll; one still busy after 30 ticks is dropped."""
	var scheduler: Slots.Scheduler = Slots.Scheduler.new()
	scheduler.request(Slots.KIND_DAILY, "daily_1", 0)
	_settlement._stock_retry_pending = true
	assert_true(scheduler.poll(_settlement, _manager).is_empty(), "busy: still waiting")
	assert_equal(scheduler.pending_count(), 1, "kept")
	_settlement._stock_retry_pending = false
	var done: Array[Dictionary] = scheduler.poll(_settlement, _manager)
	assert_equal([done.size(), done[0]["code"]], [1, SaveHeader.REFUSE_NONE], "saved once quiescent")
	assert_equal(Slots.list_slots(Slots.KIND_DAILY).size(), 1, "the daily slot exists")
	scheduler.request(Slots.KIND_DAILY, "daily_2", -Slots.BUSY_WAIT_TICKS)
	_settlement._stock_retry_pending = true
	done = scheduler.poll(_settlement, _manager)
	_settlement._stock_retry_pending = false
	assert_equal([done.size(), done[0]["code"], scheduler.pending_count()], [1, Slots.REFUSE_BUSY, 0],
		"dropped and reported after 30 ticks")


func test_startup_recovery_keeps_every_save() -> void:
	"""A verified target's .tmp is removed, an orphan .tmp is kept, a .rollback is offered as
	recovered and a save that does not verify is renamed .corrupt."""
	assert_true(Slots.save_slot(_settlement, _manager, Slots.KIND_MANUAL, "good").is_ok(), "a good save")
	var good: String = Slots.slot_path(Slots.KIND_MANUAL, "good")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(good)
	_write(good + SaveFile.TEMP_SUFFIX, bytes)
	_write(Slots.slot_path(Slots.KIND_MANUAL, "orphan") + SaveFile.TEMP_SUFFIX, bytes)
	_write(Slots.slot_path(Slots.KIND_MANUAL, "crashed") + Slots.ROLLBACK_SUFFIX, bytes)
	var damaged: PackedByteArray = bytes.duplicate()
	damaged[damaged.size() - 40] ^= 0x01
	_write(Slots.slot_path(Slots.KIND_MANUAL, "bad"), damaged)
	var actions: Dictionary = {}
	for row: Dictionary in Slots.recover():
		actions[row["file"]] = row["action"]
	assert_equal(actions, {"good.rwlsave.tmp": "tmp_removed", "orphan.rwlsave.tmp": "tmp_kept",
		"crashed.rwlsave.rollback": "recovered", "bad.rwlsave": "corrupt"}, "the recovery actions")
	assert_true(FileAccess.file_exists(good), "the good save is untouched")
	assert_true(FileAccess.file_exists(Slots.slot_path(Slots.KIND_MANUAL, "bad") + Slots.CORRUPT_SUFFIX),
		"renamed, not deleted")


func _write(path: String, bytes: PackedByteArray) -> void:
	"""Write one file whole."""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
