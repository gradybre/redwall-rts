extends RefCounted
## The playtest log's FOLDER: where the session files live, their names, and rotation (decision 0562). DEMO
## DIAGNOSTICS.
##
## WHERE. `user://logs`, beside Godot's own `godot.log` (debug/file_logging, on for desktop exports by default).
## In the Windows build (config/name.demo_build "Redwall Demo") that is
##   Windows  %APPDATA%\Godot\app_userdata\Redwall Demo\logs
##   macOS    ~/Library/Application Support/Godot/app_userdata/Redwall Demo/logs
## and "Redwall RTS" in place of "Redwall Demo" when the demo runs from the editor or `godot --path godot`.
##
## NAMES. `playtest-YYYY-MM-DD_HH-MM-SS-p<pid>.log`: the local start time sorts them, and the process id keeps
## two sessions started in the same second apart (the live harnesses run in parallel). Godot rotates its own
## `godot*.log` files by their prefix, so the two sets never touch each other.
##
## ROTATION. Before a session opens its file, the oldest playtest files go until KEEP - 1 are left, so the folder
## holds the last KEEP sessions. Only files with this exact prefix and suffix are ever removed.
##
## A CLEAN END. Every session ends its file with END_MARKER. A newest earlier file without it ended in a crash, a
## forced quit or a hang -- or is another copy still running -- and the next session's header says so, naming it,
## so a tester knows which file to send.

const DIR: String = "user://logs"
const PREFIX: String = "playtest-"
const SUFFIX: String = ".log"
const KEEP: int = 10
const END_MARKER: String = "== session end"
## How much of a file's end is read to find END_MARKER.
const END_PROBE_BYTES: int = 4096


static func session_name(local: Dictionary, pid: int) -> String:
	"""The file name for a session started at `local` (Time.get_datetime_dict_from_system()) by process `pid`."""
	return "%s%04d-%02d-%02d_%02d-%02d-%02d-p%d%s" % [PREFIX, int(local.get("year", 0)), int(local.get("month", 0)),
		int(local.get("day", 0)), int(local.get("hour", 0)), int(local.get("minute", 0)), int(local.get("second", 0)),
		pid, SUFFIX]


static func is_session_file(file_name: String) -> bool:
	"""Whether `file_name` is one of ours (rotation touches nothing else)."""
	return file_name.begins_with(PREFIX) and file_name.ends_with(SUFFIX) and file_name.length() > PREFIX.length() \
		+ SUFFIX.length()


static func ensure_dir(dir: String) -> bool:
	"""Create the folder if it is missing. False when it cannot be made."""
	if DirAccess.dir_exists_absolute(dir):
		return true
	return DirAccess.make_dir_recursive_absolute(dir) == OK


static func list(dir: String) -> PackedStringArray:
	"""Our session files in `dir`, oldest first (by name, which is by start time)."""
	var found := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir):
		if is_session_file(file_name):
			found.append(file_name)
	found.sort()
	return found


static func rotate(dir: String, keep: int) -> int:
	"""Remove the oldest session files until `keep - 1` are left (room for the one about to open). Returns how many
	were removed."""
	var files: PackedStringArray = list(dir)
	var removed: int = 0
	for k: int in maxi(0, files.size() - (keep - 1)):
		if DirAccess.remove_absolute(dir.path_join(files[k])) == OK:
			removed += 1
	return removed


static func newest_before(dir: String, own_name: String) -> String:
	"""The newest session file other than `own_name` ('' for none)."""
	var files: PackedStringArray = list(dir)
	for k: int in range(files.size() - 1, -1, -1):
		if files[k] != own_name:
			return files[k]
	return ""


static func ended_cleanly(file_path: String) -> bool:
	"""Whether the file at `file_path` ends its session with END_MARKER (false when it cannot be read)."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var length: int = file.get_length()
	file.seek(maxi(0, length - END_PROBE_BYTES))
	var end: String = file.get_buffer(mini(length, END_PROBE_BYTES)).get_string_from_utf8()
	file.close()
	return end.contains(END_MARKER)


static func folder_text(dir: String) -> String:
	"""The folder as the player's system names it (an absolute path, for the Settings line and Open): with
	backslashes on Windows."""
	var full: String = ProjectSettings.globalize_path(dir)
	return full.replace("/", "\\") if OS.get_name() == "Windows" else full
