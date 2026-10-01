extends "res://test/framework/test_case.gd"
## The playtest log (decision 0562): the breadcrumb ring, the header, the folder's rotation, the file's cap and
## scrub, error capture through the logger's own entry points, the mark, freezes, the end of a session and Copy
## report. Each test writes into its own folder under user://, removed after it. The engine-level capture --
## push_error, a script error, a thread's error, F12 on the real node -- runs in its own process
## (test_demo_playtest_live.gd), so its ERROR lines stay out of this log.

const Crumbs := preload("res://demo/playtest/breadcrumbs.gd")
const Writer := preload("res://demo/playtest/log_writer.gd")
const Files := preload("res://demo/playtest/log_files.gd")
const Header := preload("res://demo/playtest/session_header.gd")
const LoggerScript := preload("res://demo/playtest/playtest_logger.gd")
const Watch := preload("res://demo/playtest/freeze_watch.gd")
const Session := preload("res://demo/playtest/playtest_session.gd")
const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const SettingsUi := preload("res://demo/playtest/playtest_settings_ui.gd")
const Toast := preload("res://demo/playtest/mark_toast.gd")
const Access := preload("res://demo/access/demo_access.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const HelpTopics := preload("res://demo/guide/help_topics.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")

const T0: int = 5000000

var _dir: String = ""
var _nodes: Array[Node] = []


func before_each() -> void:
	"""A fresh, empty folder for this test."""
	_dir = "user://playtest_test_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(_dir)


func after_each() -> void:
	"""Remove the folder and free the test's nodes."""
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)
	for node: Node in _nodes:
		node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _touch(file_name: String, text: String = "x") -> void:
	"""A file in the test's folder."""
	var file: FileAccess = FileAccess.open(_dir.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(file_name: String) -> String:
	"""A file's text in the test's folder."""
	return FileAccess.get_file_as_string(_dir.path_join(file_name))


func _session(phase: int = Session.PHASE_RUNNING) -> Session:
	"""A session opened in the test's folder at T0, in `phase`."""
	var session := Session.new(T0)
	assert_true(session.open(_dir, "playtest-2026-10-01_10-00-00-p1.log", PackedStringArray(["started: test"])),
		"the session opens its file")
	session.set_phase(phase)
	return session


# --- the ring ------------------------------------------------------------------------------------------------

func test_the_ring_wraps_and_keeps_the_newest() -> void:
	"""CAPACITY + 10 events: the ring holds the newest CAPACITY, oldest first, and the first ten are gone."""
	var ring := Crumbs.new(0)
	for k: int in Crumbs.CAPACITY + 10:
		ring.record(Crumbs.KIND_ORDER, &"order accepted", k, 0, k * 1000, k)
	assert_equal(ring.total(), Crumbs.CAPACITY + 10, "every event counted")
	assert_equal(ring.size(), Crumbs.CAPACITY, "the ring holds CAPACITY")
	assert_equal(ring.oldest_serial(), 10, "the oldest held is the eleventh")
	assert_equal(ring.line(9), "", "the tenth is gone")
	assert_true(ring.line(10).contains("order accepted, 10 selected"), ring.line(10))
	var lines := PackedStringArray()
	assert_equal(ring.lines_from(0, lines), Crumbs.CAPACITY + 10, "the next serial to read")
	assert_equal(lines.size(), Crumbs.CAPACITY, "a read from 0 starts at the oldest held")
	assert_true(lines[lines.size() - 1].contains("%d selected" % (Crumbs.CAPACITY + 9)), lines[lines.size() - 1])
	assert_equal(ring.kind_of(Crumbs.CAPACITY + 10), -1, "a serial not yet recorded has no kind")


func test_recording_retains_nothing() -> void:
	"""Ten thousand events after a warm-up: no memory kept and no object made (the columns are sized once, the tag is
	a reference). This catches growth; a temporary freed within `record` nets to zero and is a review matter."""
	var ring := Crumbs.new(0)
	for k: int in Crumbs.CAPACITY * 2:
		ring.record_now(Crumbs.KIND_PANEL, &"DemoMenu", 1, k)
	var memory: int = OS.get_static_memory_usage()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 10000:
		ring.record_now(Crumbs.KIND_PANEL, &"DemoMenu", 1, k)
	assert_equal(OS.get_static_memory_usage() - memory, 0, "no memory taken by 10000 records")
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects, 0, "no object made")
	assert_equal(ring.size(), Crumbs.CAPACITY, "still CAPACITY held")


func test_events_read_in_words() -> void:
	"""Each kind's line says what happened, in words."""
	assert_equal(Crumbs.describe(Crumbs.KIND_PANEL, &"DemoMenu", 1, 0), "DemoMenu opened", "a panel")
	assert_equal(Crumbs.describe(Crumbs.KIND_PANEL, &"right_column", 3, 0), "right column Water", "the right column")
	assert_equal(Crumbs.describe(Crumbs.KIND_PANEL, &"right_column", -1, 0), "right column collapsed", "collapsed")
	assert_equal(Crumbs.describe(Crumbs.KIND_SPEED, &"speed", 4, 1), "speed 4x", "a speed")
	assert_equal(Crumbs.describe(Crumbs.KIND_SPEED, &"state", 2, 1), "state paused", "a state")
	assert_equal(Crumbs.describe(Crumbs.KIND_NOTICE, &"notice", 1 * 2 + 1, 0), "Tunnels warning", "a notice")
	assert_equal(Crumbs.describe(Crumbs.KIND_ORDER, &"order refused", 3, 0), "order refused, 3 selected", "an order")
	assert_equal(Crumbs.describe(Crumbs.KIND_VIEW, &"underground", 1, 0), "underground on", "a view")
	assert_equal(Crumbs.describe(Crumbs.KIND_SCENE, &"village open", 0, 0), "village open", "a scene")
	assert_equal(Crumbs.describe(Crumbs.KIND_SPEED, &"speed", 9, 0), "speed 9", "an unknown speed is its number")


# --- the header -----------------------------------------------------------------------------------------------

func test_the_header_has_every_field() -> void:
	"""Every KEYS field, in order, each with a value; the version is known."""
	var lines: PackedStringArray = Header.lines(Header.collect())
	assert_equal(lines.size(), Header.KEYS.size(), "one line per field")
	for k: int in Header.KEYS.size():
		assert_true(lines[k].begins_with(Header.KEYS[k] + ": ") and lines[k].length() > Header.KEYS[k].length() + 2,
			lines[k])
	for key: String in ["version", "os", "gpu", "gpu driver", "rendering", "window", "settings", "started"]:
		assert_true(Header.KEYS.has(key), "the header names the %s" % key)
	assert_false(Header.version_text().is_empty(), "a version")
	assert_false(lines[1].contains("unknown (no build info"), "a project run finds its version: " + lines[1])


func test_the_header_names_the_settings_and_presets() -> void:
	"""The scale, the mix and the settings on; a preset fully in effect is named."""
	Access.reset()
	SoundMix.reset()
	assert_true(Header.settings_text().begins_with("scale 100%, sound Balanced, songs on"), Header.settings_text())
	assert_true(Header.settings_text().contains("on: Pause on a critical incident"), Header.settings_text())
	assert_equal(Header.presets_text(), "none", "no preset by default")
	Access.set_flag(Access.SET_MOTION, true)
	assert_equal(Header.presets_text(), "Reduced motion", "Reduced motion in effect")
	Access.reset()


func test_the_header_holds_no_path() -> void:
	"""No user folder or home folder in the header."""
	var text: String = "\n".join(Header.lines(Header.collect()))
	assert_false(text.contains(ProjectSettings.globalize_path("user://")), "no user-data path")
	var home: String = OS.get_environment("HOME")
	assert_true(home.is_empty() or not text.contains(home), "no home path")


func test_file_logging_is_on_for_desktop_exports() -> void:
	"""Godot's own godot.log is written on desktop (the .pc override, which a release export keeps)."""
	assert_true(bool(ProjectSettings.get_setting_with_override("debug/file_logging/enable_file_logging")),
		"file logging on (desktop)")
	assert_equal(String(ProjectSettings.get_setting("debug/file_logging/log_path")), "user://logs/godot.log",
		"godot.log beside the playtest logs")


# --- the folder -----------------------------------------------------------------------------------------------

func test_names_sort_by_start_and_keep_processes_apart() -> void:
	"""'playtest-2026-10-01_09-05-07-p42.log'; ours only."""
	var name: String = Files.session_name({"year": 2026, "month": 10, "day": 1, "hour": 9, "minute": 5, "second": 7}, 42)
	assert_equal(name, "playtest-2026-10-01_09-05-07-p42.log", "the name")
	assert_true(Files.is_session_file(name), "ours")
	assert_false(Files.is_session_file("godot.log"), "Godot's is not")
	assert_false(Files.is_session_file("playtest-notes.txt"), "a note is not")
	assert_false(Files.is_session_file("crash-dump-2026-09-01_10-00.log"), "another long .log is not")


func test_rotation_keeps_the_last_sessions_and_nothing_else_is_touched() -> void:
	"""Twelve old sessions and two other files: opening a session leaves the newest nine and the new one -- KEEP --
	and the other files."""
	for k: int in 12:
		_touch("playtest-2026-09-%02d_10-00-00-p1.log" % (k + 1))
	_touch("godot.log")
	_touch("playtest-notes.txt")
	_touch("crash-dump-2026-09-01_10-00.log")
	var session := Session.new(T0)
	assert_true(session.open(_dir, "playtest-2026-10-01_10-00-00-p1.log", PackedStringArray(), 10), "opened")
	session.stop("test", T0)
	var left: PackedStringArray = Files.list(_dir)
	assert_equal(left.size(), 10, "KEEP sessions")
	assert_equal(left[0], "playtest-2026-09-04_10-00-00-p1.log", "the three oldest went")
	assert_equal(left[left.size() - 1], "playtest-2026-10-01_10-00-00-p1.log", "the new one is the newest")
	assert_true(FileAccess.file_exists(_dir.path_join("godot.log")), "godot.log untouched")
	assert_true(FileAccess.file_exists(_dir.path_join("playtest-notes.txt")), "another file untouched")
	assert_true(FileAccess.file_exists(_dir.path_join("crash-dump-2026-09-01_10-00.log")), "another .log untouched")
	assert_equal(Files.newest_before(_dir, left[left.size() - 1]), left[left.size() - 2], "the newest but our own")
	assert_equal(Files.newest_before(_dir, "playtest-2027.log"), left[left.size() - 1], "the newest")
	assert_equal(Files.rotate(_dir, 10), 1, "a second rotation makes room for one more")


func test_the_header_says_whether_the_last_session_ended_cleanly() -> void:
	"""A previous file without the end marker is named as unclean; with it, as clean."""
	_touch("playtest-2026-09-30_10-00-00-p1.log", "== events\n+1.0s scene village open\n")
	var session := _session()
	session.stop("test", T0)
	assert_true(_read(session.file_name()).contains(
		"previous session: playtest-2026-09-30_10-00-00-p1.log DID NOT END CLEANLY"), "unclean named")
	var next := Session.new(T0)
	next.open(_dir, "playtest-2026-10-02_10-00-00-p1.log", PackedStringArray())
	next.stop("test", T0)
	assert_true(_read(next.file_name()).contains("previous session: %s ended cleanly" % session.file_name()), "clean")
	assert_true(Files.ended_cleanly(_dir.path_join(next.file_name())), "the end marker is found")


# --- the file -------------------------------------------------------------------------------------------------

func test_the_file_is_capped_and_forced_lines_use_the_reserve() -> void:
	"""Past MAX_BYTES ordinary lines are dropped, one capped line says so, and a forced line still lands."""
	var writer := Writer.new()
	assert_true(writer.open(_dir.path_join("cap.log")), "opened")
	var line: String = "x".repeat(1023)
	for k: int in Writer.MAX_KIB + 10:
		writer.write(line)
	assert_true(writer.dropped() >= 10, "lines dropped past the cap (%d)" % writer.dropped())
	assert_true(writer.bytes() <= Writer.MAX_BYTES + 256, "the file stops near the cap (%d)" % writer.bytes())
	assert_true(writer.write("== a forced line", true), "a forced line is written")
	writer.close()
	var text: String = _read("cap.log")
	assert_equal(text.count("== log capped"), 1, "one capped line")
	assert_true(text.ends_with("== a forced line\n"), "the forced line is last")


func test_lines_carry_no_home_or_user_folder() -> void:
	"""Scrubbed folders read as '~' and '<user data>', with either slash."""
	var writer := Writer.new()
	writer.add_scrub("/Users/tester", "~")
	writer.add_scrub("C:/Users/tester/AppData/Roaming/Godot/app_userdata/Redwall Demo", "<user data>")
	writer.add_scrub("", "nothing")
	assert_equal(writer.scrub("open /Users/tester/x.png"), "open ~/x.png", "home")
	assert_equal(writer.scrub("C:\\Users\\tester\\AppData\\Roaming\\Godot\\app_userdata\\Redwall Demo\\logs"),
		"<user data>\\logs", "Windows slashes")
	var windows := Writer.new()
	windows.add_scrub("C:\\Users\\tester", "~")
	assert_equal(windows.scrub("C:/Users/tester/a and C:\\Users\\tester\\b"), "~/a and ~\\b", "a USERPROFILE, either way")
	writer.write("at /Users/tester/game")
	assert_equal(writer.tail(1)[0], "at ~/game", "written scrubbed")


func test_repeats_fold_after_the_limit() -> void:
	"""The same line REPEAT_LIMIT times, then counted; another line is new."""
	var writer := Writer.new()
	var kept: int = 0
	for k: int in Writer.REPEAT_LIMIT + 3:
		if writer.note_repeat("0|boom|here"):
			kept += 1
	assert_equal(kept, Writer.REPEAT_LIMIT, "REPEAT_LIMIT written")
	assert_equal(writer.suppressed(), 3, "the rest counted")
	assert_true(writer.note_repeat("0|other|here"), "another line is new")


func test_the_tail_keeps_the_newest_lines() -> void:
	"""TAIL_LINES + 5 lines: the tail's newest is the last written, and asks for more than it holds return all."""
	var writer := Writer.new()
	for k: int in Writer.TAIL_LINES + 5:
		writer.write("line %d" % k)
	var tail: PackedStringArray = writer.tail(3)
	assert_equal(tail, PackedStringArray(["line %d" % (Writer.TAIL_LINES + 2), "line %d" % (Writer.TAIL_LINES + 3),
		"line %d" % (Writer.TAIL_LINES + 4)]), "the newest three, oldest first")
	assert_equal(writer.tail(10000).size(), Writer.TAIL_LINES, "at most TAIL_LINES")
	assert_false(writer.is_open(), "a writer with no file keeps only its tail")


# --- errors ---------------------------------------------------------------------------------------------------

func _empty_frames() -> Array[ScriptBacktrace]:
	"""No script frames (a release export's push_error)."""
	return []


func test_the_logger_writes_errors_warnings_and_printerr() -> void:
	"""Its two engine entry points, called as the engine calls them: each line written with its kind and place,
	counted, a breadcrumb left; plain print is not kept."""
	var session := _session()
	session.logger._log_error("push_error", "core/variant/variant_utility.cpp", 1023, "the pantry overflowed", "",
		false, Logger.ERROR_TYPE_ERROR, _empty_frames())
	session.logger._log_error("_boom", "res://demo/x.gd", 12, "Cannot call method 'call' on a null value.", "",
		false, Logger.ERROR_TYPE_SCRIPT, _empty_frames())
	session.logger._log_error("ERR_FAIL_COND", "scene/main/node.cpp", 40, "p_child == nullptr", "Invalid child.",
		false, Logger.ERROR_TYPE_WARNING, _empty_frames())
	session.logger._log_message("a printerr line\n", true)
	session.logger._log_message("a plain print\n", false)
	session.stop("test", T0)
	var text: String = _read(session.file_name())
	assert_true(text.contains("ERROR  the pantry overflowed  (at core/variant/variant_utility.cpp:1023 in push_error)"),
		"the error and its place")
	assert_true(text.contains("SCRIPT ERROR  Cannot call method 'call' on a null value.  (at res://demo/x.gd:12"), "script")
	assert_true(text.contains("WARNING  Invalid child."), "the engine's message, not its condition")
	assert_true(text.contains("printerr  a printerr line"), "printerr")
	assert_false(text.contains("a plain print"), "print stays in godot.log")
	assert_equal(session.logger.counts, PackedInt32Array([1, 1, 1, 0, 1]), "counted by kind")
	assert_false(text.contains("error script error #1"), "an error's breadcrumb is not written twice")
	var dump: String = session.dump("dump")
	assert_true(dump.contains("error script error #1"), "but a dump lists it")
	assert_true(text.contains("1 errors, 1 warnings, 1 script, 0 shader, 1 printerr"), "the totals at the end")


func test_breadcrumbs_before_an_error_are_written_before_it() -> void:
	"""A panel opened, then an error: the panel's line comes first in the file (time order)."""
	var session := _session()
	session.record(Crumbs.KIND_PANEL, &"DemoLab", 1, 0)
	session.logger.report(Logger.ERROR_TYPE_ERROR, "after the lab", "here", "")
	session.stop("test", T0)
	var text: String = _read(session.file_name())
	assert_true(text.find("panel DemoLab opened") >= 0 and text.find("panel DemoLab opened") < text.find("after the lab"),
		"the breadcrumb first")
	assert_equal(text.count("panel DemoLab opened"), 1, "written once")


func test_an_error_every_frame_is_folded() -> void:
	"""The same error twenty times: REPEAT_LIMIT lines, the rest counted in the totals."""
	var session := _session()
	for k: int in 20:
		session.logger.report(Logger.ERROR_TYPE_ERROR, "every frame", "here", "")
	session.stop("test", T0)
	var text: String = _read(session.file_name())
	assert_equal(text.count("ERROR  every frame"), Writer.REPEAT_LIMIT, "written REPEAT_LIMIT times")
	assert_true(text.contains("20 errors"), "all counted")
	assert_true(text.contains("%d folded" % (20 - Writer.REPEAT_LIMIT)), "the folded count")


func test_script_frames_are_written_under_the_line() -> void:
	"""A frame text is indented under its line."""
	var line: String = LoggerScript.format_line(1500000, Logger.ERROR_TYPE_ERROR, "boom", "f.cpp:1 in x",
		"      [0] _ready (res://a.gd:3)")
	assert_equal(line, "+1.500s ERROR  boom  (at f.cpp:1 in x)\n      [0] _ready (res://a.gd:3)", line)


# --- marks, freezes, the heartbeat, the end ------------------------------------------------------------------

func test_a_mark_is_written_at_once_with_the_last_breadcrumbs() -> void:
	"""Mark: numbered, written with the game's time and the breadcrumbs before it (flushed with it)."""
	var session := _session()
	session.record(Crumbs.KIND_PANEL, &"DemoMenu", 1, 0)
	session.record(Crumbs.KIND_ORDER, &"order accepted", 2, 0)
	assert_equal(session.mark(T0 + 2000000, "Y1 Spring 3, 14:00, 1x"), 1, "the first mark")
	assert_equal(session.mark(T0 + 3000000, "Y1 Spring 3, 14:01, 1x"), 2, "the second")
	var text: String = _read(session.file_name())
	assert_true(text.contains("+2.000s MARK #1  the tester marked a problem here ("), "the mark line")
	assert_true(text.contains("game Y1 Spring 3, 14:00, 1x)"), "with the game's time")
	assert_true(text.contains("     +") and text.contains("DemoMenu opened"), "the breadcrumbs under it")
	assert_true(text.contains("MARK #1: the tester marked a problem here"), "the mark is a breadcrumb too")
	session.stop("test", T0)


func test_a_long_frame_is_a_freeze_written_when_it_ends() -> void:
	"""Running: a frame over FREEZE_RUNNING_USEC is written with its length and the breadcrumbs; loading, the same
	frame is not; a slow frame is counted."""
	var session := _session(Session.PHASE_LOADING)
	session.record(Crumbs.KIND_SCENE, &"village built", 0, 0)
	session.frame(T0 + 16000)
	session.frame(T0 + 16000 + 5000000)
	assert_equal(session.freezes, 0, "loading: five seconds is not a freeze")
	session.set_phase(Session.PHASE_RUNNING)
	session.frame(T0 + 16000 + 5000000 + 200000)
	session.frame(T0 + 16000 + 5000000 + 200000 + 4000000)
	assert_equal(session.freezes, 1, "running: four seconds is")
	var text: String = _read(session.file_name())
	assert_true(text.contains("FREEZE ENDED  no frame for 4.0 s while running"), "written with its length")
	assert_true(text.contains("village built"), "with the breadcrumbs")
	assert_true(session.heartbeat_line(T0 + 10000000).contains("slow 3 of 4"), session.heartbeat_line(T0 + 10000000))
	session.stop("test", T0)


func test_the_watch_reports_a_freeze_once_while_it_lasts() -> void:
	"""`check`: nothing under the threshold, the stall once past it, nothing again until a new beat."""
	var watch := Watch.new()
	watch.set_threshold_usec(1000000)
	watch.beat(T0)
	assert_equal(watch.check(T0 + 500000), 0, "under the threshold")
	assert_equal(watch.check(T0 + 1500000), 1500000, "past it: the stall")
	assert_equal(watch.check(T0 + 2500000), 0, "once per stall")
	watch.beat(T0 + 3000000)
	assert_equal(watch.check(T0 + 4500000), 1500000, "a new stall after a beat")
	assert_equal(watch.reports(), 2, "two reported")


func test_the_watch_thread_writes_a_freeze_still_going() -> void:
	"""Started as the process starts it (`start_watch`) and running: with no frame for longer than the running
	threshold, the thread writes the freeze before any recovery."""
	var session := _session(Session.PHASE_LOADING)
	session.running_freeze_usec = 100000
	assert_true(session.start_watch(), "the thread starts")
	session.set_phase(Session.PHASE_RUNNING)
	session.record(Crumbs.KIND_ORDER, &"order accepted", 1, 0)
	OS.delay_msec(Watch.POLL_MSEC * 3)
	session.stop("test", Time.get_ticks_usec())
	assert_false(session.watch.running(), "stop joins the thread")
	var text: String = _read(session.file_name())
	assert_true(text.contains("FREEZE  no frame for"), "the ongoing freeze written")
	assert_true(text.contains("still waiting"), "saying it may never recover")


func test_each_frame_beats_the_watch_at_the_phase_threshold() -> void:
	"""`frame` beats the watch, and the watch's threshold follows the phase: loading's, then running's."""
	var session := _session(Session.PHASE_LOADING)
	var at: int = T0 + 50000
	session.frame(at)
	assert_equal(session.watch.check(at + Session.FREEZE_RUNNING_USEC), 0, "loading: running's threshold is no freeze")
	assert_true(session.watch.check(at + Session.FREEZE_LOADING_USEC) > 0, "loading's is")
	session.set_phase(Session.PHASE_RUNNING)
	at += 100000
	session.frame(at)
	assert_equal(session.watch.check(at + Session.FREEZE_RUNNING_USEC - 1), 0, "running: just under the threshold")
	assert_true(session.watch.check(at + Session.FREEZE_RUNNING_USEC) > 0, "running: at it")
	session.stop("test", T0)


func test_a_full_file_still_ends_cleanly() -> void:
	"""Past the cap and the reserve both, the end marker is still written: a full log never reads as a crash."""
	var session := _session()
	var line: String = "y".repeat(1023)
	for k: int in Writer.MAX_KIB + 80:
		session.writer.write(line, true)
	session.stop("quit", T0)
	assert_true(session.writer.dropped() > 0, "lines were dropped")
	assert_true(Files.ended_cleanly(_dir.path_join(session.file_name())), "the end is written")


func test_the_heartbeat_says_time_rate_memory_and_errors() -> void:
	"""Due every HEARTBEAT_USEC: the game's time, the rate, the memory and the error totals."""
	var session := _session()
	session.game_time = func() -> String: return "Y1 Spring 1, 06:12, 1x"
	session.frame(T0 + Session.HEARTBEAT_USEC)
	var text: String = _read(session.file_name())
	assert_true(text.contains("heartbeat  game Y1 Spring 1, 06:12, 1x | fps "), "the game's time")
	assert_true(text.contains("memory ") and text.contains(" MiB, video ") and text.contains("errors 0 errors"),
		"memory and errors")
	session.stop("test", T0)


func test_breadcrumbs_are_flushed_once_a_second_not_each_frame() -> void:
	"""Two breadcrumbs, frames under a second: not written; the next frame past a second writes both at once."""
	var session := _session()
	session.record(Crumbs.KIND_VIEW, &"underground", 1, 0)
	session.record(Crumbs.KIND_VIEW, &"map layer", 2, 0)
	session.frame(T0 + 500000)
	assert_false(_read(session.file_name()).contains("underground on"), "not yet")
	session.frame(T0 + Session.FLUSH_USEC + 1)
	var text: String = _read(session.file_name())
	assert_true(text.contains("view underground on") and text.contains("view map layer 2"), "both written")
	assert_equal(session.flush_crumbs(), 0, "nothing left to write")
	session.stop("test", T0)


func test_a_session_ends_with_its_totals_once() -> void:
	"""Stop writes the end marker with the totals, once; the file then reads as ended cleanly."""
	var session := _session()
	session.stop("quit", T0 + 61000000)
	session.stop("quit again", T0 + 62000000)
	assert_false("\n".join(session.writer.tail(5)).contains("quit again"), "a second stop writes nothing")
	var text: String = _read(session.file_name())
	assert_equal(text.count(Files.END_MARKER), 1, "one end")
	assert_true(text.contains("== session end (quit) after 61.0 s: 0 marks, 0 freezes"), "with its totals")
	assert_true(Files.ended_cleanly(_dir.path_join(session.file_name())), "ended cleanly")


func test_ending_the_session_lets_go_of_it() -> void:
	"""The process's session, started and stopped: its logger removed and the session freed at once -- a script
	Logger still held at exit aborts the process (decision 0562)."""
	var started: Session = PlaytestLog.start_session(_dir)
	assert_not_null(started, "a session starts")
	assert_true(PlaytestLog.session() == started, "it is the process's session")
	var gone: WeakRef = weakref(started)
	var logger: WeakRef = weakref(started.logger)
	var file_name: String = started.file_name()
	started = null
	PlaytestLog.stop_session("test")
	assert_null(PlaytestLog.session(), "no session after the stop")
	assert_null(gone.get_ref(), "the session is freed")
	assert_null(logger.get_ref(), "and its logger")
	assert_true(Files.ended_cleanly(_dir.path_join(file_name)), "after writing its end")


func test_a_second_session_ends_the_first() -> void:
	"""Starting a session while one runs ends the first (its end written, its watch joined, its logger released)."""
	var first: Session = PlaytestLog.start_session(_dir)
	var first_ref: WeakRef = weakref(first)
	var first_name: String = first.file_name()
	var watch: Watch = first.watch
	first = null
	OS.delay_msec(1100)
	var second: Session = PlaytestLog.start_session(_dir)
	assert_not_null(second, "the second starts")
	assert_null(first_ref.get_ref(), "the first is let go")
	assert_false(watch.running(), "its watch joined")
	assert_true(Files.ended_cleanly(_dir.path_join(first_name)), "its end written")
	second = null
	PlaytestLog.stop_session("test")


func test_copy_report_is_a_fresh_header_and_the_tail_without_paths() -> void:
	"""The report: its header lines, the session's last lines, and no user folder."""
	var session := _session()
	session.writer.write("an error at %s" % ProjectSettings.globalize_path("user://logs/x"))
	var report: String = session.report_text(Header.lines(Header.collect()), 50)
	assert_true(report.begins_with("== Redwall demo playtest log (report)\nsession: "), report.substr(0, 80))
	assert_true(report.contains("\ngpu: ") and report.contains("\nsettings: "), "the header")
	assert_true(report.contains("== last 50 lines of the session") and report.contains("an error at <user data>/logs/x"),
		"the tail, scrubbed")
	assert_false(report.contains(ProjectSettings.globalize_path("user://")), "no user-data path")
	session.stop("test", T0)


# --- with no session (the test worker, another scene) -------------------------------------------------------------

func test_without_a_session_everything_is_a_quiet_no_op() -> void:
	"""No session in this process: a breadcrumb, a mark and a report do nothing; Settings says so."""
	assert_null(PlaytestLog.session(), "no session in the worker")
	PlaytestLog.crumb(Crumbs.KIND_MARK, &"mark", 1)
	assert_equal(PlaytestLog.mark(), 0, "no mark")
	assert_equal(PlaytestLog.report_text(), "", "no report")
	var ui: SettingsUi = _keep(SettingsUi.new())
	assert_equal(ui.mark(), 0, "Settings' Mark")
	assert_equal(ui.status_text(), SettingsUi.NO_LOG, "says the log is not running")
	assert_equal(ui.copy_report(), 0, "Copy report copies nothing")
	assert_true(PlaytestLog.folder().ends_with(Files.DIR.get_file().path_join(PlaytestLog.HEADLESS_SUBDIR)), "headless, the folder line names the headless folder")


func test_settings_shows_the_section_and_help_says_where_the_logs_are() -> void:
	"""The menu's Settings page carries the section; Help has the topic, its command and F12."""
	var menu: MenuScript = _keep(MenuScript.new())
	var settings: String = menu.page_text(MenuScript.PAGE_SETTINGS)
	for words: String in [SettingsUi.TITLE, SettingsUi.OPEN_TEXT, SettingsUi.COPY_TEXT, SettingsUi.MARK_TEXT]:
		assert_true(settings.contains(words), "Settings: %s" % words)
	var topics := HelpTopics.new()
	var found: PackedInt32Array = topics.search("crash")
	assert_false(found.is_empty(), "'crash' finds a topic")
	var k: int = found[0]
	assert_equal(topics.title_of(k), "Something went wrong? Report it", "the report topic first")
	assert_true(topics.body_of(k).contains("%APPDATA%\\Godot\\app_userdata\\Redwall Demo\\logs"), "the Windows folder")
	assert_true(topics.body_of(k).contains("~/Library/Application Support/Godot/app_userdata/Redwall Demo/logs"), "Mac")
	assert_equal(topics.action_of(k), HelpTopics.ACTION_LOGS, "it opens the folder")
	var keys := PackedStringArray()
	for j: int in topics.count():
		keys.append(topics.keys_of(j))
	assert_true(keys.has("F12"), "F12 is listed")


func test_the_toast_says_the_mark_and_hides_after_its_time() -> void:
	"""Shown with the mark's number; hidden once SHOW_USEC has passed."""
	var toast: Toast = _keep(Toast.new())
	toast.show_mark(3, T0)
	assert_true(toast.visible and toast.text().begins_with("Marked #3 in the playtest log"), toast.text())
	toast.tick(T0 + Toast.SHOW_USEC - 1)
	assert_true(toast.visible, "still shown")
	toast.tick(T0 + Toast.SHOW_USEC)
	assert_false(toast.visible, "hidden")
