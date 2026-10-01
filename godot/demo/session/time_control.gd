extends Node
## THE DEMO'S TIME CONTROLS, frame by frame: the pause types, the one Resume, and "Run until...". Decision 0471
## (review UX-022). Presentation over the game's clock: it pauses and resumes only through GameManager's own controls
## (pause_ledger.gd), and its run reads the village's systems (run_until.gd).
##
## EACH FRAME, after the village has advanced (`process_priority` PRIORITY, later than every system it reads):
##   1. the warning count moves on by the notice feed's new WARNING rows (a folded repeat is the same warning said
##      again, as for the warning chime) -- with the incidents' own count, what "the next warning" watches;
##   2. the PLANNING surfaces (`add_planning`: the Pantry, the Work screen, the village news, the Residents list, the
##      object list, the Dig tool) are asked whether any is open, and the ledger holds or lets go the planning pause;
##   3. a RUN under way is checked: arrived -> the PLAYER pause with the arrival as its note; its project removed ->
##      the same pause, saying so (never left running unattended at the run's speed); any pause before that -> the run
##      is cancelled, saying which; otherwise the demo clock's next frame is capped so a calendar target lands
##      exactly (demo_clock.gd `limit_usec`);
##   4. the HUD's own pause label (UI-SET-086) is kept hidden: the pause card (demo_pause_card.gd) stands in for it.
## A CRITICAL INCIDENT raised or come back (demo_incidents.gd `incident_cue`) pauses through the ledger (setting on)
## and cancels a run -- unless the run was waiting for exactly that ("the next warning or incident").
##
## KEYS (read in `_unhandled_input`, before the game's own handler under it): SPACE (`time_pause`) is the ledger's
## toggle -- paused, it is THE Resume (your pause, a planning pause, a critical pause), running, it pauses; G opens
## the "Run until..." menu (demo_run_menu.gd). The HUD's own pause button toggles only PLAYER (ui_shell.gd), so after
## its press the rest of Resume follows (`_on_shell_action`): pressed while paused, it resumes as Space does.

const LedgerScript := preload("res://demo/session/pause_ledger.gd")
const RunScript := preload("res://demo/session/run_until.gd")
const ClockScript := preload("res://demo/demo_clock.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const RunMenuScript := preload("res://demo/ui/demo_run_menu.gd")

## After every system the run reads (the farm 0, the village 1, the farm view 20).
const PRIORITY: int = 50
const PAUSED_WORDS: String = "paused (%s)"
const CRITICAL_CANCEL: String = "a critical incident: %s"
const STOPPED_WORDS: String = "you stopped it"
const CANNOT_RUN: String = "Cannot run: %s"

var ledger: LedgerScript = LedgerScript.new()
var run: RunScript = RunScript.new()
## Whether the village has opened (the boot's own pause released): the card says nothing before.
var opened: bool = false
## The run menu (G), when the host gave one.
var run_menu: RunMenuScript = null

var _manager: GameManagerScript = null
var _clock: ClockScript = null
var _notices: NoticesScript = null
var _incidents: IncidentsScript = null
var _shell: UiShell = null
var _planning_names: PackedStringArray = PackedStringArray()
var _planning_open: Array[Callable] = []
var _rows_seen: int = 0
var _warning_rows: int = 0
var _outcome_live: bool = false
var _reasons: PackedStringArray = PackedStringArray()


func _init() -> void:
	"""Late in the frame; reading while anything pauses."""
	name = "TimeControl"
	process_priority = PRIORITY
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(manager: GameManagerScript, clock: ClockScript, notices: NoticesScript,
		incidents: IncidentsScript) -> void:
	"""The game's clock, the demo clock the run caps, the notice feed and the incidents."""
	_manager = manager
	_clock = clock
	_notices = notices
	_incidents = incidents
	ledger.bind(manager)
	run.warnings = warnings_seen
	_rows_seen = notices.rows_posted if notices != null else 0
	if incidents != null and not incidents.incident_cue.is_connected(_on_incident_cue):
		incidents.incident_cue.connect(_on_incident_cue)


func bind_shell(shell: UiShell) -> void:
	"""The HUD whose pause button joins Resume and whose own pause label the card stands in for."""
	_shell = shell
	if shell != null and not shell.shell_action.is_connected(_on_shell_action):
		shell.shell_action.connect(_on_shell_action)


func add_planning(surface: String, is_open: Callable) -> void:
	"""A planning surface: its name in the pause's words ("the Pantry") and `is_open() -> bool`."""
	_planning_names.append(surface)
	_planning_open.append(is_open)


func _exit_tree() -> void:
	"""The scene is going (Restart, Quit): let every demo hold go, so the next village does not open paused."""
	ledger.release_all()
	if _clock != null:
		_clock.limit_usec = -1


# --- each frame ---------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Steps 1-4 of the header."""
	if _manager == null:
		return
	_count_warnings()
	_follow_planning()
	_follow_run()
	ledger.sync()
	if not _manager.is_paused():
		_outcome_live = false
	_hide_shell_label()


func _count_warnings() -> void:
	"""The feed's new rows since the last frame, counted when they are warnings. Read by entry id (decision 0591: a
	grouped repeat moves its row to the newest place without writing a new one)."""
	if _notices == null or _notices.rows_posted == _rows_seen:
		return
	for k: int in _notices.count():
		if _notices.is_new_since(k, _rows_seen) and _notices.level(k) == NoticesScript.LEVEL_WARNING:
			_warning_rows += 1
	_rows_seen = _notices.rows_posted


func warnings_seen() -> int:
	"""Warnings posted and incidents raised so far (only counts up): what "the next warning" watches. The feed's
	newest rows are counted first, so a run starting mid-frame takes every warning already said as its baseline."""
	_count_warnings()
	return _warning_rows + (_incidents.occurrences if _incidents != null else 0)


func _follow_planning() -> void:
	"""Hold or release the planning pause by whether any planning surface is open (the first one names it)."""
	for k: int in _planning_open.size():
		if _planning_open[k].is_valid() and bool(_planning_open[k].call()):
			ledger.set_planning(true, _planning_names[k])
			return
	ledger.set_planning(false, "")


func _follow_run() -> void:
	"""Arrived: pause with the arrival; paused before it: cancel; running: cap the next frame (step 3)."""
	if run.is_running():
		if run.check():
			ledger.pause_player(run.end_text)
		elif run.is_running() and _manager.is_paused():
			ledger.reasons_into(_reasons)
			for k: int in _reasons.size():
				_reasons[k] = _reasons[k].substr(0, 1).to_lower() + _reasons[k].substr(1)
			run.cancel(RunScript.END_PAUSED, PAUSED_WORDS % "; ".join(_reasons))
			_outcome_live = true
		elif not run.is_running():
			ledger.pause_player(run.end_text)
	if _clock != null:
		_clock.limit_usec = run.usec_limit()


func _hide_shell_label() -> void:
	"""Keep UI-SET-086 hidden (UIManager shows it on a state change; the card says the same, with Resume)."""
	if _shell == null:
		return
	var label: Control = _shell.control_for(UiShell.ID_PAUSE_LABEL)
	if label != null and label.visible:
		label.visible = false


# --- the player's verbs ---------------------------------------------------------------------------------------

func resume() -> int:
	"""THE Resume (the card's button, Space while paused): the kinds it cleared."""
	return ledger.resume()


func start_run(target: int) -> bool:
	"""Run until `target`: refused, nothing changed, when the target is not available now; else resume first if the
	village is paused (refused, saying why, when Resume cannot clear the pause -- the menu, a stall), then start."""
	if _manager == null or not run.refusal(target).is_empty():
		return false
	if _manager.is_paused():
		ledger.resume()
	if _manager.is_paused():
		run.end_text = CANNOT_RUN % ledger.resume_refusal()
		return false
	if not run.start(target):
		return false
	if _clock != null:
		_clock.limit_usec = run.usec_limit()
	return true


func stop_run() -> void:
	"""The player's Stop."""
	run.cancel(RunScript.END_STOPPED, STOPPED_WORDS)
	if _clock != null:
		_clock.limit_usec = -1


func run_note() -> String:
	"""The pause card's line about a run cancelled at this pause ("" otherwise)."""
	return run.end_text if _outcome_live and run.ended != RunScript.END_REACHED else ""


func _on_incident_cue(cue: int, serial: int, _severity: int) -> void:
	"""A critical incident raised or come back: pause (setting on), and cancel a run not waiting for one."""
	if cue != IncidentsScript.CUE_CRITICAL_RAISED or _incidents == null:
		return
	var title: String = _incidents.text_of(serial)
	if run.is_running() and run.target != RunScript.TARGET_WARNING:
		run.cancel(RunScript.END_CRITICAL, CRITICAL_CANCEL % title)
		_outcome_live = true
		if _clock != null:
			_clock.limit_usec = -1
	ledger.raise_critical(title)


func _on_shell_action(element_id: int) -> void:
	"""The HUD's pause button toggled PLAYER: pressed while paused it was a Resume, so the rest of Resume follows
	whenever another kind still stands (PLAYER itself the toggle already set or cleared); pressed while running it was
	the player's pause, which stands alone."""
	if element_id != UiShell.ID_PAUSE:
		return
	if ledger.kinds() & ~LedgerScript.KIND_PLAYER != 0:
		ledger.resume()


func _unhandled_input(event: InputEvent) -> void:
	"""Space: pause, or (paused) Resume; G: the run menu."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.is_action_pressed(&"time_pause"):
		ledger.toggle()
	elif run_menu != null and key.keycode == RunMenuScript.KEY and not (key.ctrl_pressed or key.alt_pressed
			or key.meta_pressed or key.shift_pressed):
		run_menu.toggle()
	else:
		return
	get_viewport().set_input_as_handled()
