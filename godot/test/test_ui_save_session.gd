extends "res://test/framework/test_case.gd"
## `ui_save_session.gd` (ADR 1222 step 11; DEC-055 Q4-Q6, Q9, Q10) and its HUD reports (`ui_save_controls.gd`).
##
## Every file goes under TEST_ROOT, never the player's own saves. A whole save takes about half a
## minute, so the tests that write one are few and each checks several things.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")
const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const UiSaveControls := preload("res://scripts/ui/ui_save_controls.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const UiNotices := preload("res://scripts/ui/ui_notices.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")

const TEST_ROOT: String = "user://test_ui_save_session"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const ERROR_PANEL_ID: int = 85
## 100 ms host frames: three ticks at 1x.
const FRAME_USEC: int = 100000

var _settlement: Node = null
var _manager: Node = null
var _session: UiSaveSession = null
var _saved: Array[Array] = []
var _loaded: Array[Array] = []
var _placed: Array[Array] = []


func before_each() -> void:
	"""A generated settlement on its own started clock, an enabled session and an empty slot root."""
	_remove_tree(TEST_ROOT)
	Slots.root = TEST_ROOT
	_settlement = SettlementSystemScript.new()
	_manager = GameManagerScript.new()
	assert_true(_settlement.create_generated_settlement(_settlement.item_definitions()), "generates")
	assert_true(_manager.start_game(), "the clock runs")
	_session = UiSaveSession.new()
	_session.bind(_settlement, _manager)
	_session.set_enabled(true)
	_session.save_finished.connect(func(k: String, n: String, c: StringName, d: String) -> void: _saved.append([k, n, c, d]))
	_session.load_finished.connect(func(k: String, n: String, c: StringName, d: String) -> void: _loaded.append([k, n, c, d]))
	_session.demolition_placed.connect(func(b: Vector2i, c: StringName) -> void: _placed.append([b, c]))


func after_each() -> void:
	"""Free both nodes, drop the session, restore the slot root and delete the test files."""
	_session = null
	_saved.clear()
	_loaded.clear()
	_placed.clear()
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


func _advance(ticks: int) -> void:
	"""Run the settlement on its own manager for `ticks` more ticks (a multiple of three)."""
	var target: int = _manager.clock().completed_tick() + ticks
	assert_true(_manager.bind_simulation(_settlement.run_tick, _settlement.run_day_boundary), "bind")
	while _manager.clock().completed_tick() < target:
		_manager.advance_host_time(FRAME_USEC)
	_manager.unbind_simulation()


func _a_building() -> Vector2i:
	"""The first live building of the starter colony."""
	var buildings: RefCounted = _settlement.buildings()
	for row: int in 1024:
		var ref: Vector2i = buildings.building_ref_of_row(row)
		if ref.x >= 0:
			return ref
	fail("the starter colony has a building")
	return Vector2i(-1, 0)


# --- switching, cadence and F5 --------------------------------------------------------------------

func test_the_controls_are_off_until_the_game_turns_them_on() -> void:
	"""A fresh session (the demo's) refuses F5 and never polls a save."""
	var session: UiSaveSession = UiSaveSession.new()
	session.bind(_settlement, _manager)
	assert_false(session.request_quicksave(), "F5 refused")
	assert_equal(session.last_refusal(), UiSaveSession.REFUSE_DISABLED, "because the controls are off")
	assert_equal(session.order_demolition(_a_building()), UiSaveSession.REFUSE_DISABLED, "no order either")
	assert_equal(session.poll(), 0, "nothing polled")
	assert_true(Slots.list_slots(Slots.KIND_QUICK).is_empty(), "nothing written")


func test_the_autosave_cadence_takes_the_three_settings_only() -> void:
	"""UI §8: Daily (default), Every 3 days, Off."""
	assert_equal(_session.autosave_cadence(), Slots.AUTOSAVE_DAILY, "Daily by default")
	for days: int in [Slots.AUTOSAVE_OFF, Slots.AUTOSAVE_EVERY_3_DAYS, Slots.AUTOSAVE_DAILY]:
		assert_true(_session.set_autosave_cadence(days), "%d accepted" % days)
	assert_false(_session.set_autosave_cadence(2), "2 refused")
	assert_equal(_session.last_refusal(), UiSaveSession.REFUSE_CADENCE, "with its code")
	assert_equal(_session.autosave_cadence(), Slots.AUTOSAVE_DAILY, "unchanged")


func test_f5_saves_at_the_next_boundary_and_f9_names_it_then_loads_it() -> void:
	"""F5 queues the quicksave, the next poll takes it; F9's row names it and its tick; the confirmed
	load replaces the world and reports itself."""
	assert_equal(_session.quickload_row(), {}, "no quicksave yet")
	assert_equal(_session.last_refusal(), UiSaveSession.REFUSE_NO_QUICKSAVE, "F9 has nothing to name")
	assert_true(_session.request_quicksave(), "F5")
	assert_equal(_session.pending_count(), 1, "queued for the boundary")
	assert_equal(_session.poll(), 1, "taken at the next poll")
	assert_equal(_saved, [[Slots.KIND_QUICK, Slots.QUICK_NAME, SaveHeader.REFUSE_NONE, ""]], "reported")
	var row: Dictionary = _session.quickload_row()
	assert_equal([row.get("name"), int(row.get("tick", -1))], [Slots.QUICK_NAME, 0], "F9 names it and its tick")
	_advance(30)
	var loaded: SaveHeader.Refusal = _session.load_slot(Slots.KIND_QUICK, Slots.QUICK_NAME)
	assert_true(loaded.is_ok(), "load: %s %s" % [loaded.code, loaded.detail])
	assert_equal(_manager.clock().completed_tick(), 0, "the world went back to the quicksave")
	assert_equal(_loaded.size(), 1, "the load reported itself")


# --- autosave timing and the busy wait ------------------------------------------------------------

func test_a_completed_midnight_queues_the_daily_autosave_and_a_busy_world_waits() -> void:
	"""The poll that first sees a new day queues its daily slot; while the stock layer is busy the
	save waits (the world is running), and a load-style day jump queues nothing."""
	assert_equal(_session.poll(), 0, "the first poll only learns the day")
	_advance(SimClockScript.TICKS_PER_DAY - SimClockScript.CALENDAR_OFFSET_TICKS)
	_settlement._stock_retry_pending = true
	assert_equal(_session.poll(), 0, "busy: nothing finished")
	assert_equal(_session.pending_count(), 1, "day 2's autosave waits for a quiescent boundary")
	_session._last_day = _manager.get_absolute_day() + 5
	_session.poll()
	assert_equal(_session.pending_count(), 1, "a jumped day queues nothing more")
	_settlement._stock_retry_pending = false


func test_a_busy_save_while_paused_is_reported_at_once() -> void:
	"""No tick can pass while paused, so a busy F5 is SAVE_BUSY at once, not a wait forever."""
	assert_true(_manager.pause_game(), "paused")
	_settlement._stock_retry_pending = true
	assert_true(_session.request_quicksave(), "F5")
	assert_equal(_session.poll(), 1, "finished at once")
	_settlement._stock_retry_pending = false
	assert_equal(_saved[0][2], Slots.REFUSE_BUSY, "reported busy")
	assert_equal(_session.pending_count(), 0, "and dropped")


# --- the pre-demolition quicksave (Q6) -------------------------------------------------------------

func test_a_demolition_order_takes_its_quicksave_first_and_waits_for_a_busy_world() -> void:
	"""The pre-demolition slot is saved before the order is placed; a busy running world holds the
	order until its save is taken at a quiescent poll."""
	var building: Vector2i = _a_building()
	_settlement._stock_retry_pending = true
	assert_equal(_session.order_demolition(building), UiSaveSession.ORDER_WAITING_FOR_SAVE, "held")
	assert_equal(_session.held_order_count(), 1, "one order waits")
	assert_true(_placed.is_empty(), "nothing placed yet")
	assert_false(_settlement.has_evacuation_intent(building), "and the building is untouched")
	_settlement._stock_retry_pending = false
	assert_equal(_session.poll(), 1, "the save is taken")
	assert_equal(_saved[0].slice(0, 3), [Slots.KIND_DEMOLITION, Slots.DEMOLITION_NAME, SaveHeader.REFUSE_NONE],
		"the pre-demolition slot was saved")
	assert_equal(_placed.size(), 1, "then the order was placed")
	assert_equal(_session.held_order_count(), 0, "none waits")
	assert_true(FileAccess.file_exists(Slots.slot_path(Slots.KIND_DEMOLITION, Slots.DEMOLITION_NAME)), "on disk")


# --- the HUD reports (`ui_save_controls.gd`) -----------------------------------------------------

func _routed() -> Array:
	"""Off-tree save controls over a real HUD, on this test's settlement and manager: [controls, hud]."""
	var hud: HudScript = (load(HUD_SCENE_PATH) as PackedScene).instantiate() as HudScript
	hud._ready()
	var controls: UiSaveControls = UiSaveControls.new()
	controls.bind(_settlement, _manager, hud)
	return [controls, hud]


func _free_routed(routed: Array) -> void:
	"""Free the controls and the HUD."""
	(routed[0] as Node).free()
	(routed[1] as Node).free()


func _top_notice(hud: HudScript) -> UiNotices.Notice:
	"""The notice on the first alert card."""
	var notice: UiNotices.Notice = UiNotices.Notice.new()
	assert_true(hud.shell().card_notice_into(notice), "a notice is shown")
	return notice


func test_a_refused_save_reaches_the_error_panel_with_its_code_reason_and_recovery() -> void:
	"""UI-SET-085: SAVE_UNSUPPORTED_STATE (DEC-055 Q9) is shown as the code, a plain reason and the
	recovery action, and kept as an error notice."""
	var routed: Array = _routed()
	var hud: HudScript = routed[1]
	routed[0]._on_save_finished(Slots.KIND_QUICK, Slots.QUICK_NAME, &"SAVE_UNSUPPORTED_STATE", "owner room_layout")
	var panel: Control = hud.shell().control_for(ERROR_PANEL_ID)
	assert_true(panel.visible, "the error panel is shown")
	for part: String in ["SAVE_UNSUPPORTED_STATE", "cannot write yet", UiSaveSession.SAVE_RECOVERY]:
		assert_true(panel.accessibility_description.contains(part), "the panel carries '%s'" % part)
	var notice: UiNotices.Notice = _top_notice(hud)
	assert_equal([notice.category, notice.code, notice.recovery],
		[UiNotices.CATEGORY_ACTION_REFUSED, "SAVE_UNSUPPORTED_STATE", UiSaveSession.SAVE_RECOVERY], "the notice")
	_free_routed(routed)


func test_a_save_and_a_load_are_announced_and_every_save_says_it_is_a_development_save() -> void:
	"""DEC-055 Q8: a saved notice names the slot and states the development-only status; a refused
	load keeps its file and says so."""
	var routed: Array = _routed()
	var hud: HudScript = routed[1]
	routed[0]._on_save_finished(Slots.KIND_DAILY, "daily_2", SaveHeader.REFUSE_NONE, "")
	var saved: UiNotices.Notice = _top_notice(hud)
	assert_equal(saved.category, UiNotices.CATEGORY_SETTLEMENT_NOTICE, "a settlement notice")
	assert_true(saved.message.begins_with("Daily autosave 3 saved at"), "named: %s" % saved.message)
	assert_true(saved.message.ends_with(UiSaveSession.DEVELOPMENT_NOTE), "and development-only")
	routed[0]._on_load_finished(Slots.KIND_MANUAL, "camp", SaveFile.REFUSE_SECTION_CRC, "section 4")
	var failed: UiNotices.Notice = _top_notice(hud)
	assert_equal([failed.code, failed.recovery], ["SAVE_FILE_SECTION_CRC", UiSaveSession.LOAD_RECOVERY],
		"a refused load keeps its file")
	assert_true(failed.message.contains("damaged"), "with its plain reason")
	_free_routed(routed)


func test_launch_recovery_reports_every_file_it_kept_or_renamed() -> void:
	"""DEC-055 Q10: a damaged save is renamed .corrupt and a rollback is offered, each as a notice;
	the controls are on afterwards."""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [TEST_ROOT, Slots.KIND_MANUAL]))
	for path: String in [Slots.slot_path(Slots.KIND_MANUAL, "bad"),
			Slots.slot_path(Slots.KIND_MANUAL, "crashed") + Slots.ROLLBACK_SUFFIX]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(PackedByteArray([1, 2, 3]))
		file.close()
	var routed: Array = _routed()
	assert_false(routed[0].session().is_enabled(), "off until enabled")
	assert_equal(routed[0].enable(), 2, "two files reported")
	assert_true(routed[0].session().is_enabled(), "and the controls are on")
	var notice: UiNotices.Notice = _top_notice(routed[1])
	assert_true(notice.code.begins_with("SAVE_RECOVERY_"), "a recovery notice: %s" % notice.code)
	assert_true(FileAccess.file_exists(Slots.slot_path(Slots.KIND_MANUAL, "bad") + Slots.CORRUPT_SUFFIX),
		"renamed, never deleted")
	_free_routed(routed)
