extends Node
## The save controls in the running game: one `ui_save_session.gd`, its frame poll and its HUD reports
## (ADR 1222 step 11).
##
## `main.gd` adds this node only when it IS the game scene (a host that instances the game, such as
## the live demo, keeps saves off). It polls the session every frame, also while paused, so F5 and the
## autosaves are taken at the first quiescent boundary between ticks. Its signal handlers only paint the
## HUD (CLAUDE.md: signals for UI updates): a saved or loaded notice, or UI-SET-085's code, plain reason
## and recovery action kept as an error notice. It writes no game state; the session reads and loads the
## world through the save slots.
##
## The notices use the HUD's existing authored categories -- "Settlement notice" for a save, a load
## and a recovery report, "Action refused" for a refused save or load -- with the save's own wording in
## the message, so no notice title or severity table changes for this.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const UiNotices := preload("res://scripts/ui/ui_notices.gd")

const SOURCE: String = "Settlement save"
const REFUSE_NONE: StringName = &""

var _session: UiSaveSession = UiSaveSession.new()
var _hud: HudScript = null
var _manager: Node = null


func _ready() -> void:
	"""Keep polling while the world is paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(settlement: Node, manager: Node, hud: HudScript) -> void:
	"""Serve this settlement and clock owner, and report to this HUD (null: no reports)."""
	_manager = manager
	_hud = hud
	_session.bind(settlement, manager)
	if not _session.save_finished.is_connected(_on_save_finished):
		_session.save_finished.connect(_on_save_finished)
		_session.load_finished.connect(_on_load_finished)
		_session.demolition_placed.connect(_on_demolition_placed)


func enable() -> int:
	"""Turn the controls on and run DEC-055 Q10's launch recovery once. Returns the files reported."""
	_session.set_enabled(true)
	var rows: Array[Dictionary] = _session.recover_at_launch()
	for row: Dictionary in rows:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, UiSaveSession.recovery_line(row),
			"SAVE_RECOVERY_%s" % String(row["action"]).to_upper(), "")
	return rows.size()


func session() -> UiSaveSession:
	"""The save session these controls drive."""
	return _session


func request_quicksave() -> bool:
	"""UI §5 `save_quick` (F5): the quicksave at the next quiescent boundary."""
	return _session.request_quicksave()


func _process(_delta: float) -> void:
	"""Between ticks, every frame: take the queued saves."""
	_session.poll()


func _has_hud() -> bool:
	"""A bound HUD that has not been freed."""
	return _hud != null and is_instance_valid(_hud)


func _notice(category: int, message: String, code: String, recovery: String) -> void:
	"""Raise one notice on the HUD, when one is bound."""
	if _has_hud():
		_hud.shell().raise_notice(category, message, SOURCE, code, recovery)


func _on_save_finished(kind: String, slot: String, code: StringName, detail: String) -> void:
	"""A save finished: a notice naming the slot and its development status, or the refusal in full."""
	var title: String = UiSaveSession.slot_title(kind, slot)
	if code == REFUSE_NONE:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "%s saved at %s. %s" % [title,
			_manager.get_calendar_text(), UiSaveSession.DEVELOPMENT_NOTE], "", "")
		return
	_report(title, code, detail, false)


func _on_load_finished(kind: String, slot: String, code: StringName, detail: String) -> void:
	"""A load finished: a notice naming the slot, or the refusal in full."""
	var title: String = UiSaveSession.slot_title(kind, slot)
	if code == REFUSE_NONE:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "%s loaded at %s." % [title,
			_manager.get_calendar_text()], "", "")
		return
	_report(title, code, detail, true)


func _report(title: String, code: StringName, detail: String, loading: bool) -> void:
	"""UI-SET-085: the code, the plain reason and the recovery action, kept as an error notice."""
	var reason: String = "%s: %s %s" % [title, UiSaveSession.reason_for(code, loading), detail]
	var recovery: String = UiSaveSession.recovery_for(code, loading)
	if _has_hud():
		_hud.show_refusal("%s %s %s" % [String(code), reason, recovery])
	_notice(UiNotices.CATEGORY_ACTION_REFUSED, reason, String(code), recovery)


func _on_demolition_placed(_building_ref: Vector2i, code: StringName) -> void:
	"""A demolition order placed behind its pre-demolition save was refused: show why."""
	if code == REFUSE_NONE:
		return
	var reason: String = "The demolition order placed after its pre-demolition quicksave was refused."
	if _has_hud():
		_hud.show_refusal("%s %s" % [String(code), reason])
	_notice(UiNotices.CATEGORY_ACTION_REFUSED, reason, String(code), "")
