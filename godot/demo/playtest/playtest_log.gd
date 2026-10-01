extends Node
## THE PLAYTEST LOG: one per process, under the scene tree's root, so it outlives Restart demo (decision 0562).
## DEMO DIAGNOSTICS. It owns the session (playtest_session.gd), installs its error logger, feeds it the frame times,
## polls the village's probes for breadcrumbs, takes F12 (the tester's mark) and shows the mark's toast.
##
## STARTING. `ensure(tree)` (demo_village.gd, first thing in `_ready`) opens the session at once -- so the
## logger catches the rest of the boot -- and adds this node to the root deferred. A second call (a restart) finds
## it and does nothing. Everything else is STATIC (`crumb`, `mark`, `open_folder`, `report_text` ...), and each is
## a no-op with no session, which is the case in the test worker and in any scene but the demo.
##
## THE VILLAGE'S PROBES (`add_probe`, playtest_taps.gd): each is an `() -> int` read once a frame; a change of value
## is one breadcrumb. They are the village's and are dropped when the village leaves the tree (a restart binds
## the new village's).
##
## F12 marks, in `_input`. This node is moved to the root's last child whenever a village binds (a reloaded scene
## is re-added after it), so its `_input` runs before the demo's input gate, which swallows keys under a modal.
## On a Mac keyboard F12 may need Fn; the game menu's Settings has the same Mark button.
##
## STOPPING. `_exit_tree` (the tree is torn down at quit) writes the end of the session, joins the freeze watch
## and removes the logger. A crash skips it: the file is flushed as it goes, and the next session's header says
## this one did not end cleanly.

const SessionScript := preload("res://demo/playtest/playtest_session.gd")
const BreadcrumbsScript := preload("res://demo/playtest/breadcrumbs.gd")
const Files := preload("res://demo/playtest/log_files.gd")
const Header := preload("res://demo/playtest/session_header.gd")
const ToastScript := preload("res://demo/playtest/mark_toast.gd")

const NODE_NAME: StringName = &"PlaytestLog"
const MARK_KEY: Key = KEY_F12
## Lines of the session Copy report carries under the header.
const REPORT_TAIL: int = 120

static var _instance: Node = null
static var _session: SessionScript = null

var _probe_kinds: PackedByteArray = PackedByteArray()
var _probe_tags: Array[StringName] = []
var _probe_values: PackedInt64Array = PackedInt64Array()
var _probe_getters: Array[Callable] = []
var _probe_details: Array[Callable] = []
var _layer_probe: Callable = Callable()
var _layer_id: int = 0
var _layer_name: StringName = &""
var _toast: ToastScript = ToastScript.new()


static func ensure(tree: SceneTree, dir: String = Files.DIR) -> Node:
	"""The process's playtest log: started (session and logger) and added under the root on the first call."""
	if is_instance_valid(_instance):
		return _instance
	if _session == null or _session.is_stopped():
		start_session(dir)
	var node: Node = (load("res://demo/playtest/playtest_log.gd") as GDScript).new()
	node.name = NODE_NAME
	_instance = node
	tree.root.add_child.call_deferred(node)
	return node


static func start_session(dir: String) -> SessionScript:
	"""Open a session in `dir` and install its logger (the node's `ensure` does this; the live check calls it)."""
	var now: int = Time.get_ticks_usec()
	var started := SessionScript.new(now)
	var file_name: String = Files.session_name(Time.get_datetime_dict_from_system(), OS.get_process_id())
	if not started.open(dir, file_name, Header.lines(Header.collect())):
		push_warning("the playtest log could not open %s/%s; this session is not logged" % [dir, file_name])
		return null
	OS.add_logger(started.logger)
	started.start_watch()
	_session = started
	return started


static func stop_session(reason: String) -> void:
	"""End the session: its last lines, the watch joined, the logger removed -- and let go of it here, while the
	scripting language is still up. A script Logger still held by this static at exit is freed after GDScript
	shuts down, and the process then aborts ("recursive_mutex lock failed", measured on 4.7.2)."""
	if _session == null:
		return
	OS.remove_logger(_session.logger)
	_session.stop(reason, Time.get_ticks_usec())
	_session = null


static func session() -> SessionScript:
	"""The running session, or null (not the demo, or the file could not be opened)."""
	return _session if _session != null and not _session.is_stopped() else null


static func crumb(kind: int, tag: StringName, a: int = 0, b: int = 0) -> void:
	"""One breadcrumb (BreadcrumbsScript.KIND_*); nothing without a session."""
	if session() != null:
		_session.record(kind, tag, a, b)


static func set_phase(phase: int) -> void:
	"""Loading or running (SessionScript.PHASE_*): the freeze threshold follows."""
	if session() != null:
		_session.set_phase(phase)


static func mark() -> int:
	"""The tester's mark: written at once with the last breadcrumbs, and a toast says so. 0 without a session."""
	if session() == null:
		return 0
	var number: int = _session.mark(Time.get_ticks_usec(), String(_session.game_time.call())
		if _session.game_time.is_valid() else "-")
	if is_instance_valid(_instance):
		(_instance as Node).call(&"_show_toast", number)
	return number


static func folder() -> String:
	"""The log folder as the system names it ('' without a session)."""
	return Files.folder_text(_session.dir()) if session() != null else Files.folder_text(Files.DIR)


static func open_folder() -> bool:
	"""Open the log folder in Explorer or Finder. False when it could not be opened."""
	var dir: String = _session.dir() if session() != null else Files.DIR
	if not Files.ensure_dir(dir):
		return false
	var full: String = ProjectSettings.globalize_path(dir)
	if OS.shell_show_in_file_manager(full, true) == OK:
		return true
	return OS.shell_open(full) == OK


static func report_text() -> String:
	"""Copy report's text: a fresh header and the session's last REPORT_TAIL lines ('' without a session)."""
	return _session.report_text(Header.lines(Header.collect()), REPORT_TAIL) if session() != null else ""


static func copy_report() -> int:
	"""Put the report on the clipboard. Returns its line count (0 without a session)."""
	var text: String = report_text()
	if text.is_empty():
		return 0
	DisplayServer.clipboard_set(text)
	return text.count("\n") + 1


static func bind_time(game_time: Callable, game_tick: Callable) -> void:
	"""The heartbeat's game time and the breadcrumbs' tick (the village's; see SessionScript)."""
	if session() != null:
		_session.game_time = game_time
		_session.game_tick = game_tick


static func probe(kind: int, tag: StringName, getter: Callable, detail: Callable = Callable()) -> void:
	"""A village probe (see THE VILLAGE'S PROBES): a breadcrumb of `kind` and `tag` whenever `getter()` changes,
	its `a` the new value -- or `detail()` when given -- and its `b` the old value."""
	if is_instance_valid(_instance):
		_instance.call(&"add_probe", kind, tag, getter, detail)


static func probe_layer(top_layer: Callable) -> void:
	"""`top_layer() -> CanvasLayer`: the modal on top (the input gate's); a change is a panel breadcrumb with its
	name."""
	if is_instance_valid(_instance):
		_instance.call(&"set_layer_probe", top_layer)


static func clear_probes() -> void:
	"""Drop every village probe and the game-time binds (the village left the tree)."""
	bind_time(Callable(), Callable())
	if is_instance_valid(_instance):
		_instance.call(&"remove_probes")


# --- the node -----------------------------------------------------------------------------------------------

func _ready() -> void:
	"""Run while the game is paused too, draw the toast, and hear the clock's speed, state and diagnostics."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast)
	var manager: Node = get_tree().root.get_node_or_null(^"GameManager")
	if manager != null and manager.has_signal(&"speed_changed"):
		manager.connect(&"speed_changed", _on_speed)
		manager.connect(&"state_changed", _on_state)
		manager.connect(&"clock_diagnostic", _on_clock_diagnostic)


func move_last() -> void:
	"""Become the root's last child again, so `_input` (F12) runs before the reloaded scene's."""
	if is_inside_tree():
		get_parent().move_child(self, -1)


func _process(_delta: float) -> void:
	"""The frame's time to the session, then the probes."""
	if session() == null:
		return
	var now: int = Time.get_ticks_usec()
	_session.frame(now)
	_poll_probes()
	_toast.tick(now)


func _poll_probes() -> void:
	"""Read every probe; a change is a breadcrumb. No allocation unless one changed."""
	for k: int in _probe_getters.size():
		var value: int = int(_probe_getters[k].call())
		if value != _probe_values[k]:
			var a: int = int(_probe_details[k].call()) if _probe_details[k].is_valid() else value
			_session.record(_probe_kinds[k], _probe_tags[k], a, int(_probe_values[k]))
			_probe_values[k] = value
	if not _layer_probe.is_valid():
		return
	var layer: CanvasLayer = _layer_probe.call()
	var id: int = layer.get_instance_id() if layer != null else 0
	if id != _layer_id:
		if _layer_id != 0:
			_session.record(BreadcrumbsScript.KIND_PANEL, _layer_name, 0, 0)
		_layer_id = id
		_layer_name = layer.name if layer != null else &""
		if layer != null:
			_session.record(BreadcrumbsScript.KIND_PANEL, _layer_name, 1, 0)


func add_probe(kind: int, tag: StringName, getter: Callable, detail: Callable) -> void:
	"""See `probe`. Its first value is read now, so binding is not a change."""
	_probe_kinds.append(kind)
	_probe_tags.append(tag)
	_probe_getters.append(getter)
	_probe_details.append(detail)
	_probe_values.append(int(getter.call()))


func set_layer_probe(top_layer: Callable) -> void:
	"""See `probe_layer`."""
	_layer_probe = top_layer
	_layer_id = 0


func remove_probes() -> void:
	"""See `clear_probes`."""
	_probe_kinds.clear()
	_probe_tags.clear()
	_probe_getters.clear()
	_probe_details.clear()
	_probe_values.clear()
	_layer_probe = Callable()
	_layer_id = 0


func probe_count() -> int:
	"""How many village probes are bound (checks)."""
	return _probe_getters.size()


func _input(event: InputEvent) -> void:
	"""F12 (pressed, not echoed): the tester's mark."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != MARK_KEY:
		return
	mark()
	get_viewport().set_input_as_handled()


func _show_toast(number: int) -> void:
	"""'Marked #2 in the playtest log' for a few seconds."""
	_toast.show_mark(number, Time.get_ticks_usec())


func _on_speed(speed: int) -> void:
	"""The clock's speed changed (GameManager)."""
	crumb(BreadcrumbsScript.KIND_SPEED, &"speed", speed)


func _on_state(state: int) -> void:
	"""The game's state changed (GameManager)."""
	crumb(BreadcrumbsScript.KIND_SPEED, &"state", state)


func _on_clock_diagnostic(message: String) -> void:
	"""The clock paused itself (an overload, REQ-SET-008): a breadcrumb and its words."""
	crumb(BreadcrumbsScript.KIND_CLOCK, &"diagnostic")
	if session() != null:
		_session.write_now("+%.3fs clock  %s" % [_session.seconds(Time.get_ticks_usec()), message])


func _notification(what: int) -> void:
	"""The crash handler's last word, when it gets one (desktop, debug): the breadcrumbs, written at once."""
	if what == NOTIFICATION_CRASH and session() != null:
		_session.writer.write(_session.dump("CRASH  the engine's crash handler fired"), true)


func _exit_tree() -> void:
	"""The tree is going (the quit): end the session. A node freed any other way does the same."""
	if _instance == self:
		_instance = null
		stop_session("quit")
