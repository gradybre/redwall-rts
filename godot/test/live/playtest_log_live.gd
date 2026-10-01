extends SceneTree
## The playtest log's ENGINE-LEVEL checks (decision 0562), in their own process: the real node and its real
## logger installed through `OS.add_logger`, then a push_error, a push_warning, a printerr, a GDScript runtime
## error and an error from another thread raised for real, F12 pushed through the Viewport, and the session
## stopped -- and the file read back. Not discovered by the runner; test/test_demo_playtest_live.gd runs it, so the
## ERROR lines it provokes on purpose stay in this child's output.
##
##     godot --headless --path godot --script res://test/live/playtest_log_live.gd
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any
## failure. It writes into its own folder under user:// and removes it.

const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const Files := preload("res://demo/playtest/log_files.gd")
const Toast := preload("res://demo/playtest/mark_toast.gd")

const PROBE: String = "playtest-live-probe"

var _dir: String = ""
var _frames: int = 0
var _checks: int = 0
var _failures: int = 0
var _node: Node = null
var _file: String = ""


func _initialize() -> void:
	"""The folder; the session starts on the first frame, with the root in the tree."""
	_dir = "user://playtest_live_%d" % OS.get_process_id()


func _process(_delta: float) -> bool:
	"""One step a frame: start, raise, mark, stop and read."""
	_frames += 1
	match _frames:
		1:
			_node = PlaytestLog.ensure(self, _dir)
			_file = PlaytestLog.session().file_name() if PlaytestLog.session() != null else ""
			_check("the session started", not _file.is_empty(), _file)
		3:
			_raise()
		4:
			_press_f12()
		5:
			_check_toast()
			PlaytestLog.stop_session("live check")
			_read_back()
			_clean()
			print("LIVE-SUMMARY %d %d" % [_checks, _failures])
			quit(1 if _failures > 0 else 0)
	return false


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _null_call(target: Object) -> void:
	"""A GDScript runtime error: a method called on null."""
	target.call(&"anything")


func _thread_error() -> void:
	"""An error raised on another thread."""
	push_error("%s from a thread" % PROBE)


func _raise() -> void:
	"""Every kind of line the logger should see, raised for real."""
	_check("the node is under the root", _node != null and _node.get_parent() == root)
	push_error("%s error" % PROBE)
	push_error("%s paths %s and %s" % [PROBE, ProjectSettings.globalize_path("user://x"), _home()])
	push_warning("%s warning" % PROBE)
	printerr("%s printerr" % PROBE)
	_null_call(null)
	var thread := Thread.new()
	thread.start(_thread_error)
	thread.wait_to_finish()


func _press_f12() -> void:
	"""F12 down and up through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_F12
		event.physical_keycode = KEY_F12
		event.pressed = down
		root.push_input(event)


func _check_toast() -> void:
	"""F12 showed the mark's toast."""
	var toast: Toast = _node.get_node_or_null(^"PlaytestMarkToast") as Toast
	_check("F12 shows the toast", toast != null and toast.visible and toast.text().begins_with("Marked #1"),
		toast.text() if toast != null else "no toast")


func _read_back() -> void:
	"""The file holds each line, the mark and a clean end."""
	var text: String = FileAccess.get_file_as_string(_dir.path_join(_file))
	_check("push_error is captured", text.contains("ERROR  %s error" % PROBE))
	_check("with its script frame", text.contains("_raise (res://test/live/playtest_log_live.gd:"))
	_check("push_warning is captured", text.contains("WARNING  %s warning" % PROBE))
	_check("printerr is captured", text.contains("printerr  %s printerr" % PROBE))
	_check("a script error is captured", text.contains("SCRIPT ERROR  Cannot call method 'call' on a null value."))
	_check("an error from another thread is captured", text.contains("ERROR  %s from a thread" % PROBE))
	_check("F12 marked the log", text.contains("MARK #1  the tester marked a problem here"))
	_check("the session ended cleanly", Files.ended_cleanly(_dir.path_join(_file)))
	_check("the header came first", text.begins_with("== Redwall demo playtest log\nsession: %s\nstarted: " % _file))
	_check("no user-data path in it", not text.contains(ProjectSettings.globalize_path("user://")))
	_check("no home path in it", not text.contains(_home()), _home())
	_check("both read as their stand-ins", text.contains("%s paths <user data>/x and ~" % PROBE))


func _home() -> String:
	"""The home folder, as the session scrubs it."""
	return OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")


func _clean() -> void:
	"""Remove the folder."""
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)
