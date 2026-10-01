extends RefCounted
## ONE PLAYTEST SESSION: the file, the breadcrumbs, the error logger, the freeze watch and the heartbeat, from the
## first frame to the quit (decision 0562). DEMO DIAGNOSTICS. The node (playtest_log.gd) owns one per process and
## feeds it the frame times; everything here takes its times as arguments, so the tests drive it without a tree.
##
## THE FILE, in order: the header (session_header.gd) and a note on the previous session if it ended uncleanly;
## then, as they come, breadcrumbs (flushed in a batch at most once per FLUSH_USEC), captured errors (at once),
## slow frames and freezes, the tester's marks and a heartbeat every HEARTBEAT_USEC; and last END_MARKER with the
## session's totals.
##
## PER FRAME (`frame`): one subtraction and comparison for the frame's length, the watch's beat, two time checks.
## Text is made only when something is due: a freeze, a batch of breadcrumbs, a heartbeat.
##
## FREEZES. A frame longer than SLOW_FRAME_USEC counts as slow (the heartbeat says how many). One longer than the
## phase's freeze threshold -- FREEZE_RUNNING_USEC once the village runs, FREEZE_LOADING_USEC while it loads -- is
## written when the game recovers, with the last DUMP_CRUMBS breadcrumbs. The watch thread writes the same freeze
## while it is still going, so a hang the tester kills is in the file too.

const WriterScript := preload("res://demo/playtest/log_writer.gd")
const BreadcrumbsScript := preload("res://demo/playtest/breadcrumbs.gd")
const LoggerScript := preload("res://demo/playtest/playtest_logger.gd")
const WatchScript := preload("res://demo/playtest/freeze_watch.gd")
const Files := preload("res://demo/playtest/log_files.gd")
const Header := preload("res://demo/playtest/session_header.gd")

const PHASE_LOADING: int = 0
const PHASE_RUNNING: int = 1
const PHASE_NAMES: Array[String] = ["loading", "running"]
const FLUSH_USEC: int = 1000000
const HEARTBEAT_USEC: int = 30000000
const SLOW_FRAME_USEC: int = 100000
const FREEZE_RUNNING_USEC: int = 3000000
const FREEZE_LOADING_USEC: int = 20000000
const DUMP_CRUMBS: int = 24
const TITLE: String = "== Redwall demo playtest log"

## `() -> String`: the game's time and speed for the heartbeat ('Y1 Spring 3, 14:00, 1x'); unset: none.
var game_time: Callable = Callable()
## `() -> int`: the game tick for the breadcrumbs; unset: 0.
var game_tick: Callable = Callable()

var writer: WriterScript = WriterScript.new()
var crumbs: BreadcrumbsScript = null
var logger: LoggerScript = null
var watch: WatchScript = WatchScript.new()
var phase: int = PHASE_LOADING
var marks: int = 0
var freezes: int = 0
var _origin_usec: int = 0
var _file_name: String = ""
var _dir: String = ""
var _last_frame_usec: int = 0
var _next_flush_usec: int = 0
var _next_heartbeat_usec: int = 0
var _frames: int = 0
var _slow: int = 0
var _worst_usec: int = 0
var _stopped: bool = false


func _init(origin_usec: int) -> void:
	"""A session whose times count from `origin_usec` (Time.get_ticks_usec() at the start)."""
	_origin_usec = origin_usec
	crumbs = BreadcrumbsScript.new(origin_usec)
	logger = LoggerScript.new(writer, crumbs, origin_usec)
	_last_frame_usec = origin_usec
	_next_flush_usec = origin_usec + FLUSH_USEC
	_next_heartbeat_usec = origin_usec + HEARTBEAT_USEC


func open(folder: String, session_file: String, header: PackedStringArray, keep: int = Files.KEEP) -> bool:
	"""Rotate `folder` to `keep` sessions, open `session_file` there and write the header, with a note when the previous
	session did not end cleanly. False (nothing written) when the folder or file cannot be made."""
	if not Files.ensure_dir(folder):
		return false
	Files.rotate(folder, keep)
	var previous: String = Files.newest_before(folder, session_file)
	_dir = folder
	_file_name = session_file
	if not writer.open(folder.path_join(session_file)):
		return false
	writer.add_scrub(ProjectSettings.globalize_path("user://").trim_suffix("/"), "<user data>")
	writer.add_scrub(OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME"), "~")
	writer.write("\n".join(PackedStringArray([TITLE, "session: %s" % session_file]) + header))
	writer.write(previous_note(previous, Files.ended_cleanly(folder.path_join(previous)) if not previous.is_empty() else true))
	writer.write("== events (times are seconds since the start; tick is the game's)")
	return true


static func previous_note(previous: String, clean: bool) -> String:
	"""The header's line about the session before this one."""
	if previous.is_empty():
		return "previous session: none in this folder"
	if clean:
		return "previous session: %s ended cleanly" % previous
	return "previous session: %s DID NOT END CLEANLY (a crash, a forced quit or a hang -- or it is still running)" \
		% previous


func seconds(now_usec: int) -> float:
	"""Seconds since the session started (every line's time)."""
	return float(now_usec - _origin_usec) / 1000000.0


func file_name() -> String:
	"""This session's file name."""
	return _file_name


func dir() -> String:
	"""The folder it is in."""
	return _dir


func start_watch() -> bool:
	"""Start the freeze watch thread at the phase's threshold."""
	watch.on_freeze = _on_watch_freeze
	return watch.start(freeze_threshold_usec())


func set_phase(next: int) -> void:
	"""Loading or running (PHASE_*): the freeze threshold follows."""
	phase = next
	watch.set_threshold_usec(freeze_threshold_usec())


func freeze_threshold_usec() -> int:
	"""The current phase's freeze threshold."""
	return FREEZE_RUNNING_USEC if phase == PHASE_RUNNING else FREEZE_LOADING_USEC


func record(kind: int, tag: StringName, a: int, b: int) -> void:
	"""One breadcrumb now (written with the next batch)."""
	crumbs.record_now(kind, tag, a, b)


func frame(now_usec: int) -> void:
	"""One drawn frame at `now_usec`: its length, the watch's beat, and whatever is due."""
	var length: int = now_usec - _last_frame_usec
	_last_frame_usec = now_usec
	_frames += 1
	if length > SLOW_FRAME_USEC:
		_slow += 1
	_worst_usec = maxi(_worst_usec, length)
	watch.beat(now_usec)
	if game_tick.is_valid():
		crumbs.now_tick = int(game_tick.call())
	if length >= freeze_threshold_usec():
		_freeze_ended(now_usec, length)
	if now_usec >= _next_flush_usec:
		_next_flush_usec = now_usec + FLUSH_USEC
		flush_crumbs()
	if now_usec >= _next_heartbeat_usec:
		_next_heartbeat_usec = now_usec + HEARTBEAT_USEC
		write_now(heartbeat_line(now_usec))
		_frames = 0
		_slow = 0
		_worst_usec = 0


func flush_crumbs() -> int:
	"""Write every breadcrumb not yet written (crumbs.drain_into), as one write. Returns how many."""
	var lines := PackedStringArray()
	if crumbs.drain_into(lines) == 0:
		return 0
	writer.write("\n".join(lines))
	return lines.size()


func write_now(text: String, forced: bool = false) -> void:
	"""The breadcrumbs so far, then `text`: the file stays in time order."""
	flush_crumbs()
	writer.write(text, forced)


func heartbeat_line(now_usec: int) -> String:
	"""'+30.0s heartbeat  game Y1 Spring 1, 06:12, 1x | fps 60, worst 41 ms, slow 0 of 1800 | ...'."""
	@warning_ignore("integer_division") var worst_ms: int = _worst_usec / 1000
	return "+%.1fs heartbeat  game %s | fps %d, worst frame %d ms, slow %d of %d | memory %d MiB, video %d MiB, objects %d, nodes %d, orphans %d | errors %s, folded %d, dropped %d" % [
		seconds(now_usec), String(game_time.call()) if game_time.is_valid() else "-",
		roundi(Engine.get_frames_per_second()), worst_ms, _slow, _frames, _mib(Performance.MEMORY_STATIC),
		_mib(Performance.RENDER_VIDEO_MEM_USED), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), counts_text(), writer.suppressed(),
		writer.dropped()]


func counts_text() -> String:
	"""'2 errors, 5 warnings, 0 script, 0 shader, 0 printerr'."""
	var c: PackedInt32Array = logger.counts
	return "%d errors, %d warnings, %d script, %d shader, %d printerr" % [c[0], c[1], c[2], c[3], c[4]]


static func _mib(monitor: Performance.Monitor) -> int:
	"""A memory monitor in MiB."""
	@warning_ignore("integer_division") var mib: int = int(Performance.get_monitor(monitor)) / (1024 * 1024)
	return mib


func mark(now_usec: int, game_text: String) -> int:
	"""The tester's 'something went wrong here': a MARK breadcrumb, then the mark, the game's time and the last
	breadcrumbs written at once. Returns the mark's number (1 for the first)."""
	marks += 1
	crumbs.record(BreadcrumbsScript.KIND_MARK, &"mark", marks, 0, now_usec, crumbs.now_tick)
	flush_crumbs()
	writer.write(dump("+%.3fs MARK #%d  the tester marked a problem here (%s, game %s)" % [
		seconds(now_usec), marks, Time.get_datetime_string_from_system(false, true),
		game_text]), true)
	return marks


func dump(title: String) -> String:
	"""`title`, then the last DUMP_CRUMBS breadcrumbs indented under it."""
	var lines := PackedStringArray([title, "   last %d breadcrumbs:" % mini(DUMP_CRUMBS, crumbs.size())])
	var recent := PackedStringArray()
	crumbs.last_lines(DUMP_CRUMBS, recent)
	for text: String in recent:
		lines.append("     " + text)
	return "\n".join(lines)


func _freeze_ended(now_usec: int, length: int) -> void:
	"""A frame longer than the freeze threshold has just ended: write it with the breadcrumbs before it."""
	freezes += 1
	@warning_ignore("integer_division") var ms: int = length / 1000
	crumbs.record(BreadcrumbsScript.KIND_FREEZE, &"ended", ms, 0, now_usec, crumbs.now_tick)
	flush_crumbs()
	writer.write(dump("+%.3fs FREEZE ENDED  no frame for %.1f s while %s; the game recovered" % [
		seconds(now_usec), float(length) / 1000000.0, PHASE_NAMES[phase]]), true)


func _on_watch_freeze(stalled_usec: int) -> void:
	"""From the watch thread: still no frame. Written at once, with the breadcrumbs, in case it never recovers."""
	@warning_ignore("integer_division") var ms: int = stalled_usec / 1000
	crumbs.record_now(BreadcrumbsScript.KIND_FREEZE, &"ongoing", ms, 0)
	writer.write(dump("+%.3fs FREEZE  no frame for %.1f s while %s (still waiting; if nothing follows, it never recovered)" % [
		seconds(Time.get_ticks_usec()), float(stalled_usec) / 1000000.0,
		PHASE_NAMES[phase]]), true)


func stop(reason: String, now_usec: int) -> void:
	"""Join the watch, write the last breadcrumbs and END_MARKER with the totals, and close (once)."""
	if _stopped:
		return
	_stopped = true
	watch.stop()
	flush_crumbs()
	writer.write("%s (%s) after %.1f s: %d marks, %d freezes, %s, %d folded, %d dropped" % [Files.END_MARKER, reason,
		seconds(now_usec), marks, freezes, counts_text(), writer.suppressed(),
		writer.dropped()], true)
	writer.close()


func is_stopped() -> bool:
	"""Whether `stop` has run."""
	return _stopped


func report_text(header: PackedStringArray, tail_lines: int) -> String:
	"""Copy report: a fresh header and the last `tail_lines` lines written (no path, no account name)."""
	flush_crumbs()
	var lines := PackedStringArray([TITLE + " (report)", "session: %s" % _file_name]) + header
	lines.append("== last %d lines of the session" % tail_lines)
	lines.append_array(writer.tail(tail_lines))
	return writer.scrub("\n".join(lines))
