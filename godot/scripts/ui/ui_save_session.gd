extends RefCounted
## The player's save controls between the HUD and the slots (ADR 1222 step 11; DEC-055).
##
## Everything a player or the calendar asks of the save goes through here, and nothing here writes
## game state: saves read the world through `settlement_save_slots.gd`, a load replaces it through
## the same module, and a demolition order is placed through `SettlementSystem`.
##
##   F5 (UI §5 `save_quick`): the one quicksave slot, taken at the next quiescent boundary.
##   F9 (UI §5 `load_quick`): `quickload_row()` names the save and its date for the confirmation the
##        browser shows; only `load_slot()` after that confirmation loads.
##   AUTOSAVE (Q4): `poll()` sees each midnight the clock completes and queues the daily slot on the
##        player's cadence and the prewinter slot whatever it is (autosave Off keeps prewinter).
##   BUSY (Q5): a queued save waits for a quiescent boundary for at most 30 ticks, then reports
##        SAVE_BUSY; while the world is paused no tick can pass, so a busy save reports at once.
##   DEMOLITION (Q6): `order_demolition()` saves the pre-demolition slot, then places the order. A
##        busy world holds the order until the save finishes or is dropped; a save that fails for any
##        other reason is reported and the order is placed (the slot is a safety copy, not a gate).
##   RECOVERY (Q10): `recover_at_launch()` runs the slots' recovery once and reports what it did.
##   DEVELOPMENT SAVES (Q8, Q9): every save is a development save; a world holding state with no
##        codec yet refuses SAVE_UNSUPPORTED_STATE, which reaches the player as that code.
##
## The signals are for the HUD only (CLAUDE.md): `ui_save_controls.gd` turns them into notices and
## the error panel. Game logic never listens to them.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

signal save_finished(kind: String, name: String, code: StringName, detail: String)
signal load_finished(kind: String, name: String, code: StringName, detail: String)
signal demolition_placed(building_ref: Vector2i, code: StringName)
## A manual save was renamed (only its browser sidecar changed).
signal slot_renamed(kind: String, name: String, code: StringName)

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_BOUND: StringName = &"SAVE_SESSION_NOT_BOUND"
const REFUSE_DISABLED: StringName = &"SAVE_SESSION_DISABLED"
const REFUSE_CADENCE: StringName = &"SAVE_AUTOSAVE_CADENCE_INVALID"
const REFUSE_NO_QUICKSAVE: StringName = &"SAVE_NO_QUICKSAVE"
## `order_demolition()`'s answer while the pre-demolition save waits for a quiescent boundary.
const ORDER_WAITING_FOR_SAVE: StringName = &"DEMOLITION_WAITING_FOR_SAVE"
## GameManager's BOOT state: the clock has not started, so there is no world to save.
const STATE_BOOT: int = 0
const CADENCES: Array[int] = [Slots.AUTOSAVE_OFF, Slots.AUTOSAVE_DAILY, Slots.AUTOSAVE_EVERY_3_DAYS]

var _settlement: Node = null
var _manager: Node = null
var _scheduler: Slots.Scheduler = Slots.Scheduler.new()
## The absolute day the last poll saw; -1 before the first poll of a bound, started clock.
var _last_day: int = -1
## Demolition orders held behind a pre-demolition save that is still waiting.
var _held_orders: Array[Vector2i] = []
var _last_refusal: StringName = REFUSE_NONE
## Off until the game scene turns it on (`main.gd`); a host that instances the game keeps it off.
var _enabled: bool = false
## The completed tick of the last save or load this session made of the bound world; -1 for none.
## The game menu's Quit warns about unsaved progress against it (UI-SET-092).
var _last_saved_tick: int = -1


func bind(settlement: Node, manager: Node) -> void:
	"""Serve this settlement and clock owner. Queued saves and held orders of another world are dropped."""
	_settlement = settlement
	_manager = manager
	_scheduler = Slots.Scheduler.new()
	_held_orders.clear()
	_last_day = -1
	_last_saved_tick = -1


func set_enabled(enabled: bool) -> void:
	"""Turn the controls on or off. Off: nothing is queued, polled, saved or loaded."""
	_enabled = enabled


func is_enabled() -> bool:
	"""Whether the controls are on."""
	return _enabled


func is_bound() -> bool:
	"""Whether the controls are on and a settlement and a clock owner are bound."""
	return _enabled and _settlement != null and _manager != null


func _unavailable() -> StringName:
	"""Why the controls cannot act: switched off, or nothing bound."""
	return REFUSE_DISABLED if not _enabled else REFUSE_NOT_BOUND


func set_autosave_cadence(days: int) -> bool:
	"""UI §8's autosave setting: 0 Off, 1 Daily, 3 Every 3 days. Prewinter is kept under every value."""
	if not CADENCES.has(days):
		return _refuse(REFUSE_CADENCE)
	_scheduler.cadence = days
	return _accept()


func autosave_cadence() -> int:
	"""The cadence in days; 0 is Off."""
	return _scheduler.cadence


func pending_count() -> int:
	"""How many slot saves are queued."""
	return _scheduler.pending_count()


func held_order_count() -> int:
	"""How many demolition orders wait for their pre-demolition save."""
	return _held_orders.size()


func request_quicksave() -> bool:
	"""F5: queue the quicksave for the next quiescent boundary (allowed while paused)."""
	if not is_bound():
		return _refuse(_unavailable())
	_scheduler.request(Slots.KIND_QUICK, Slots.QUICK_NAME, _manager.clock().completed_tick())
	return _accept()


func quickload_row() -> Dictionary:
	"""F9's confirmation: the quicksave's browser row (name, tick, real time), or {} when none exists."""
	for row: Dictionary in Slots.list_slots(Slots.KIND_QUICK):
		if row.get("name", "") == Slots.QUICK_NAME:
			return row
	_last_refusal = REFUSE_NO_QUICKSAVE
	return {}


func save_slot(kind: String, name: String, label: String = "") -> SaveHeader.Refusal:
	"""Save one slot now and report it."""
	if not is_bound():
		return SaveHeader.Refusal.new(_unavailable(), "the save controls are off or unbound")
	var refusal: SaveHeader.Refusal = Slots.save_slot(_settlement, _manager, kind, name, label)
	_note_saved(refusal)
	save_finished.emit(kind, name, refusal.code, refusal.detail)
	return refusal


func save_new_manual() -> SaveHeader.Refusal:
	"""The browser's Save: a new manual save, auto-named `save_NNN` (DEC-055, 2026-10-08)."""
	return save_slot(Slots.KIND_MANUAL, Slots.next_manual_name())


func overwrite_manual(name: String) -> SaveHeader.Refusal:
	"""Save over an existing manual save after the browser's explicit confirmation, keeping the
	player's name for it."""
	var label: String = ""
	for row: Dictionary in Slots.list_slots(Slots.KIND_MANUAL):
		if row.get("name", "") == name:
			label = String(row.get("label", ""))
	return save_slot(Slots.KIND_MANUAL, name, label)


func rename_manual(name: String, label: String) -> SaveHeader.Refusal:
	"""The browser's optional rename of a manual save: its sidecar label, never its bytes."""
	if not is_bound():
		return SaveHeader.Refusal.new(_unavailable(), "the save controls are off or unbound")
	var refusal: SaveHeader.Refusal = Slots.rename_slot(Slots.KIND_MANUAL, name, label)
	slot_renamed.emit(Slots.KIND_MANUAL, name, refusal.code)
	return refusal


func has_unsaved_progress() -> bool:
	"""Whether the bound world has moved since this session last saved or loaded it."""
	return is_bound() and _manager.clock().completed_tick() != _last_saved_tick


func _note_saved(refusal: SaveHeader.Refusal) -> void:
	"""Remember the tick a successful save or load left the world at."""
	if refusal.is_ok():
		_last_saved_tick = _manager.clock().completed_tick()


func load_slot(kind: String, name: String) -> SaveHeader.Refusal:
	"""Load one slot after the player confirmed it, and report it. Queued saves of the replaced world
	are dropped; the next poll resynchronises the calendar instead of taking a missed autosave."""
	if not is_bound():
		return SaveHeader.Refusal.new(_unavailable(), "the save controls are off or unbound")
	return _finish_load(kind, name, Slots.load_slot(_settlement, _manager, kind, name))


func load_recovered(kind: String, file_name: String) -> SaveHeader.Refusal:
	"""Load a recovered rollback checkpoint (DEC-055 Q10) after the player confirmed it; the file
	itself is kept."""
	if not is_bound():
		return SaveHeader.Refusal.new(_unavailable(), "the save controls are off or unbound")
	return _finish_load(kind, file_name,
		Slots.load_recovered(_settlement, _manager, kind, file_name))


func _finish_load(kind: String, name: String, refusal: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""After a load: drop the replaced world's queued saves and held orders, then report it."""
	if refusal.is_ok():
		_scheduler = _rescheduled()
		_held_orders.clear()
		_last_day = -1
		_note_saved(refusal)
	load_finished.emit(kind, name, refusal.code, refusal.detail)
	return refusal


func _rescheduled() -> Slots.Scheduler:
	"""An empty scheduler keeping the player's cadence."""
	var fresh: Slots.Scheduler = Slots.Scheduler.new()
	fresh.cadence = _scheduler.cadence
	return fresh


# --- what a player reads (UI-SET-085: code + plain reason + recovery action) ----------------------

## DEC-055 Q8/Q9: no save is a release save yet. Every saved notice says so.
const DEVELOPMENT_NOTE: String = "Development save: it loads only in this exact build of the game."
## Plain reasons for the codes a player can meet; any other code falls back to the generic line.
const REASONS: Dictionary = {
	&"SAVE_BUSY": "The settlement did not reach a safe point to save in time.",
	&"SAVE_UNSUPPORTED_STATE": "The settlement holds state the development save cannot write yet.",
	&"SAVE_SLOT_INVALID": "That is not a save slot.",
	&"SAVE_NO_QUICKSAVE": "There is no quicksave yet.",
	&"SAVE_FILE_SECTION_CRC": "The save file is damaged.",
	&"SAVE_LOAD_ROLLBACK_FAILED": "The load failed and the previous settlement could not be restored.",
}
const SAVE_REASON: String = "The save was refused."
const LOAD_REASON: String = "The save could not be loaded."
const SAVE_RECOVERY: String = "Nothing was written; earlier saves are unchanged. Try again shortly."
const LOAD_RECOVERY: String = "The file is kept unchanged and the settlement was not replaced. Choose another save."
## A rollback failure leaves the world empty under a held LOAD (ARCH-SAVE-004): both files are kept.
const ROLLBACK_RECOVERY: String = "Both files are kept. Load another save or start a new settlement."


static func reason_for(code: StringName, loading: bool) -> String:
	"""The plain reason for a refusal code."""
	return REASONS.get(code, LOAD_REASON if loading else SAVE_REASON)


static func recovery_for(code: StringName, loading: bool) -> String:
	"""The recovery action for a refusal code."""
	if code == &"SAVE_LOAD_ROLLBACK_FAILED":
		return ROLLBACK_RECOVERY
	return LOAD_RECOVERY if loading else SAVE_RECOVERY


static func slot_title(kind: String, name: String) -> String:
	"""How a slot is named to the player."""
	match kind:
		Slots.KIND_QUICK:
			return "Quicksave"
		Slots.KIND_DAILY:
			return "Daily autosave %d" % (int(name.trim_prefix("daily_")) + 1)
		Slots.KIND_PREWINTER:
			return "Prewinter autosave"
		Slots.KIND_DEMOLITION:
			return "Pre-demolition quicksave"
	return "Save '%s'" % name


static func recovery_line(row: Dictionary) -> String:
	"""Q10's launch report for one file: what was found and what was done with it."""
	match String(row.get("action", "")):
		"recovered":
			return "%s/%s was kept from an interrupted load and is offered as a recovered save." \
				% [row["kind"], row["file"]]
		"corrupt":
			return "%s/%s did not verify and was renamed .corrupt; it was not deleted." % [row["kind"], row["file"]]
		"tmp_kept":
			return "%s/%s is an unfinished write whose save did not verify; it was kept." % [row["kind"], row["file"]]
	return "%s/%s: an unfinished write was removed; its save verified." % [row["kind"], row["file"]]


# --- demolition (Q6) ------------------------------------------------------------------------------

func order_demolition(building_ref: Vector2i) -> StringName:
	"""Q6: take the pre-demolition quicksave, then place "evacuate, then demolish" on the building.
	Returns the order's code, or ORDER_WAITING_FOR_SAVE while a busy world holds the save."""
	if not is_bound():
		return _refuse_code(_unavailable())
	if not _held_orders.is_empty():
		_held_orders.append(building_ref)
		return ORDER_WAITING_FOR_SAVE
	var saved: SaveHeader.Refusal = Slots.save_slot(_settlement, _manager, Slots.KIND_DEMOLITION,
		Slots.DEMOLITION_NAME)
	if saved.code == Slots.REFUSE_BUSY and not _manager.is_paused():
		_scheduler.request(Slots.KIND_DEMOLITION, Slots.DEMOLITION_NAME, _manager.clock().completed_tick())
		_held_orders.append(building_ref)
		return ORDER_WAITING_FOR_SAVE
	save_finished.emit(Slots.KIND_DEMOLITION, Slots.DEMOLITION_NAME, saved.code, saved.detail)
	return _place_order(building_ref)


func _place_order(building_ref: Vector2i) -> StringName:
	"""Place the order and report it; an evacuation order waiting on goods counts as placed."""
	var report: RefCounted = _settlement.order_evacuate_then_demolish(building_ref)
	var code: StringName = REFUSE_NONE if report.ok or report.evacuation_ordered else report.error
	demolition_placed.emit(building_ref, code)
	return code


func _release_held_orders() -> void:
	"""The pre-demolition save finished (saved or dropped): place every order it held, in order."""
	var orders: Array[Vector2i] = _held_orders.duplicate()
	_held_orders.clear()
	for building_ref: Vector2i in orders:
		_place_order(building_ref)


# --- the frame poll -------------------------------------------------------------------------------

func poll() -> int:
	"""Once per host frame, between ticks: queue the midnight autosaves, then try every queued save.
	Returns how many saves finished (saved or refused) this call."""
	if not is_bound() or _manager.is_loading() or _manager.get_state() == STATE_BOOT:
		return 0
	_queue_midnights()
	if _scheduler.pending_count() == 0:
		return 0
	var finished: Array[Dictionary] = _scheduler.poll(_settlement, _manager)
	for row: Dictionary in finished:
		if row["code"] == REFUSE_NONE:
			_last_saved_tick = _manager.clock().completed_tick()
		save_finished.emit(row["kind"], row["name"], row["code"], row["detail"])
		if row["kind"] == Slots.KIND_DEMOLITION:
			_release_held_orders()
	return finished.size()


func _queue_midnights() -> void:
	"""Queue the autosaves of a midnight the clock just completed. A day that moved by anything but
	one (the first poll, or a load) only resynchronises: a missed day is never saved late."""
	var day: int = _manager.get_absolute_day()
	if _last_day >= 0 and day == _last_day + 1:
		_scheduler.on_midnight(day, _manager.clock().completed_tick())
	_last_day = day


# --- launch recovery (Q10) ------------------------------------------------------------------------

func recover_at_launch() -> Array[Dictionary]:
	"""Q10 over every slot directory, once at launch: one {kind, file, action} row per file acted on."""
	return Slots.recover()


func last_refusal() -> StringName:
	"""The most recent refusal code, or empty after a success."""
	return _last_refusal


func _accept() -> bool:
	"""Clear the refusal and return true."""
	_last_refusal = REFUSE_NONE
	return true


func _refuse(code: StringName) -> bool:
	"""Record a refusal and return false."""
	_last_refusal = code
	return false


func _refuse_code(code: StringName) -> StringName:
	"""Record a refusal and return its code."""
	_last_refusal = code
	return code
