extends RefCounted
## Save slots, autosave timing and startup recovery (ADR 1222 / ADR 1228; DEC-055 Q2, Q4, Q5, Q10).
##
## SLOTS (Q2). `user://saves/<kind>/<name>.rwlsave`, written by `SettlementSave.save_to_path()`
## (temp file, re-read and re-decode, rename), with the browser row in a small JSON sidecar
## `<name>.rwlmeta` outside the canonical bytes, so the browser never opens a whole save. Kinds:
## `manual` (unbounded), `quick` (one slot), `daily` (five rotating slots, REQ-SET-158),
## `prewinter` (one) and `demolition` (the one pre-major-demolition quicksave). A load goes through
## `SettlementSave.load_bytes()` with `<file>.rollback` as its disk checkpoint (ARCH-SAVE-004).
##
## AUTOSAVE (Q4, Q5). `Scheduler.on_midnight()` queues the daily autosave on the cadence the
## player chose (daily, every 3 days, off) and the prewinter save at the first midnight of
## autumn's last week, whatever the cadence. `Scheduler.poll()` saves each queued slot at the first
## quiescent boundary; one that is still SAVE_BUSY after BUSY_WAIT_TICKS, or at once while the
## world is paused, is dropped and reported.
## The calendar has no week of its own (12-day seasons), so "the last week" is the last seven days:
## the prewinter save fires entering autumn day PREWINTER_SEASON_DAY.
##
## RECOVERY (Q10). `recover()` runs at launch over every slot directory: a `.tmp` whose target
## verifies is deleted; any other `.tmp` is kept; a `.rollback` is kept and offered as recovered; a
## save that does not verify is renamed `.corrupt`. Nothing here ever deletes a save.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

const ROOT: String = "user://saves"
## The slot root in use: ROOT, or a test's own directory so a suite never touches the player's saves.
static var root: String = ROOT
const SAVE_EXTENSION: String = ".rwlsave"
const META_EXTENSION: String = ".rwlmeta"
const ROLLBACK_SUFFIX: String = ".rollback"
const CORRUPT_SUFFIX: String = ".corrupt"
const KIND_MANUAL: String = "manual"
const KIND_QUICK: String = "quick"
const KIND_DAILY: String = "daily"
const KIND_PREWINTER: String = "prewinter"
const KIND_DEMOLITION: String = "demolition"
const KINDS: Array[String] = [KIND_MANUAL, KIND_QUICK, KIND_DAILY, KIND_PREWINTER, KIND_DEMOLITION]
const QUICK_NAME: String = "quicksave"
const PREWINTER_NAME: String = "prewinter"
const DEMOLITION_NAME: String = "predemolition"
const DAILY_SLOTS: int = 5
## DEC-055 Q5 engineering choice: one real second at 1x.
const BUSY_WAIT_TICKS: int = 30
## The autosave cadences UI-SET's setting offers, in days; 0 is Off.
const AUTOSAVE_OFF: int = 0
const AUTOSAVE_DAILY: int = 1
const AUTOSAVE_EVERY_3_DAYS: int = 3
const PREWINTER_SEASON_DAY: int = SimClockScript.DAYS_PER_SEASON - 6
const MAX_NAME_LENGTH: int = 64
const REFUSE_SLOT: StringName = &"SAVE_SLOT_INVALID"
const REFUSE_BUSY: StringName = &"SAVE_BUSY"


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


# --- slots ----------------------------------------------------------------------------------------

static func valid_slot(kind: String, name: String) -> bool:
	"""A known kind and a name of 1-64 ASCII letters, digits, `_` and `-`."""
	if not KINDS.has(kind) or name.is_empty() or name.length() > MAX_NAME_LENGTH:
		return false
	for index: int in name.length():
		var code: int = name.unicode_at(index)
		var letter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if not (letter or (code >= 48 and code <= 57) or code == 95 or code == 45):
			return false
	return true


static func slot_path(kind: String, name: String) -> String:
	"""The save file of one slot."""
	return "%s/%s/%s%s" % [root, kind, name, SAVE_EXTENSION]


static func save_slot(settlement: Node, manager: Node, kind: String, name: String,
		label: String = "") -> SaveHeader.Refusal:
	"""Save atomically into one slot, then write its browser sidecar."""
	if not valid_slot(kind, name):
		return _no(REFUSE_SLOT, "'%s/%s' is not a save slot" % [kind, name])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [root, kind]))
	var path: String = slot_path(kind, name)
	var saved: SaveHeader.Refusal = SettlementSave.save_to_path(settlement, manager, path)
	if not saved.is_ok():
		return saved
	var meta: Dictionary = {"kind": kind, "name": name, "label": label,
		"tick": manager.clock().completed_tick(), "saved_unix": int(Time.get_unix_time_from_system()),
		"format_version": SaveHeader.FORMAT_VERSION}
	var file: FileAccess = FileAccess.open(path.get_basename() + META_EXTENSION, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(meta, "", true))
		file.close()
	return _ok()


static func load_slot(settlement: Node, manager: Node, kind: String, name: String,
		content: RefCounted = null) -> SaveHeader.Refusal:
	"""Load one slot into `settlement`, with `<file>.rollback` as the disk checkpoint."""
	if not valid_slot(kind, name):
		return _no(REFUSE_SLOT, "'%s/%s' is not a save slot" % [kind, name])
	var path: String = slot_path(kind, name)
	var bytes: PackedByteArray = PackedByteArray()
	var read: SaveHeader.Refusal = SaveFile.read_file(path, bytes)
	if not read.is_ok():
		return read
	return SettlementSave.load_bytes(settlement, manager, bytes, content, path + ROLLBACK_SUFFIX)


static func list_slots(kind: String) -> Array[Dictionary]:
	"""Every slot of `kind` that has a save file, by name, with its sidecar row (or just its name)."""
	var rows: Array[Dictionary] = []
	var directory: String = "%s/%s" % [root, kind]
	if not KINDS.has(kind) or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return rows
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(SAVE_EXTENSION):
			rows.append(_meta_row(kind, file_name.trim_suffix(SAVE_EXTENSION)))
	return rows


static func _meta_row(kind: String, name: String) -> Dictionary:
	"""The sidecar's row, or the bare kind and name when it is missing or unreadable."""
	var text: String = FileAccess.get_file_as_string("%s/%s/%s%s" % [root, kind, name, META_EXTENSION])
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("name", "") == name:
		return parsed
	return {"kind": kind, "name": name}


# --- autosave timing ------------------------------------------------------------------------------

static func daily_name(day: int) -> String:
	"""The rotating daily slot an absolute day writes."""
	return "daily_%d" % ((day - OrchardHiveScript.MIN_CALENDAR_DAY) % DAILY_SLOTS)


static func daily_due(day: int, cadence: int) -> bool:
	"""Whether the midnight that begins `day` takes the daily autosave (never the opening day)."""
	return cadence > 0 and day > OrchardHiveScript.MIN_CALENDAR_DAY \
		and (day - OrchardHiveScript.MIN_CALENDAR_DAY) % cadence == 0


static func prewinter_due(day: int) -> bool:
	"""Whether the midnight that begins `day` is the first of autumn's last week."""
	return day >= OrchardHiveScript.MIN_CALENDAR_DAY \
		and OrchardHiveScript.season_of_day(day) == int(Catalog.SEASON["AUTUMN"]) \
		and OrchardHiveScript.season_day_of_day(day) == PREWINTER_SEASON_DAY


class Scheduler:
	"""Queued slot saves, each taken at the first quiescent boundary or dropped after BUSY_WAIT_TICKS."""
	const Slots := preload("res://scripts/core/settlement_save_slots.gd")
	var cadence: int = AUTOSAVE_DAILY
	var _pending: Array[Dictionary] = []

	func request(kind: String, name: String, tick: int) -> void:
		"""Queue one slot save; a slot already queued keeps its first request tick."""
		for row: Dictionary in _pending:
			if row["kind"] == kind and row["name"] == name:
				return
		_pending.append({"kind": kind, "name": name, "tick": tick})

	func on_midnight(day: int, tick: int) -> void:
		"""The midnight that begins `day`: the daily autosave on the cadence, and prewinter always."""
		if Slots.daily_due(day, cadence):
			request(KIND_DAILY, Slots.daily_name(day), tick)
		if Slots.prewinter_due(day):
			request(KIND_PREWINTER, PREWINTER_NAME, tick)

	func pending_count() -> int:
		"""How many slot saves are queued."""
		return _pending.size()

	func poll(settlement: Node, manager: Node) -> Array[Dictionary]:
		"""Try every queued save now; return one {kind, name, code, detail} row per finished one. The
		wait is counted in completed ticks, so while the world is paused (no tick can pass) a busy
		save is reported at once instead of waiting for a boundary that cannot come."""
		var finished: Array[Dictionary] = []
		var waiting: Array[Dictionary] = []
		for row: Dictionary in _pending:
			var refusal: SaveHeader.Refusal = Slots.save_slot(settlement, manager, row["kind"], row["name"])
			var waited: int = manager.clock().completed_tick() - int(row["tick"])
			if refusal.code == REFUSE_BUSY and waited < BUSY_WAIT_TICKS and not manager.is_paused():
				waiting.append(row)
				continue
			finished.append({"kind": row["kind"], "name": row["name"], "code": refusal.code,
				"detail": refusal.detail})
		_pending = waiting
		return finished


# --- startup recovery -----------------------------------------------------------------------------

static func recover() -> Array[Dictionary]:
	"""Q10 over every slot directory; one {kind, file, action} row per file it acted on or kept."""
	var report: Array[Dictionary] = []
	for kind: String in KINDS:
		var directory: String = "%s/%s" % [root, kind]
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
			continue
		for file_name: String in DirAccess.get_files_at(directory):
			var action: String = _recover_file("%s/%s" % [directory, file_name])
			if action != "":
				report.append({"kind": kind, "file": file_name, "action": action})
	return report


static func _recover_file(path: String) -> String:
	"""The action for one file: tmp_removed, tmp_kept, recovered, corrupt, or "" for a good save."""
	if path.ends_with(SAVE_EXTENSION + SaveFile.TEMP_SUFFIX):
		if _verifies(path.trim_suffix(SaveFile.TEMP_SUFFIX)):
			SaveFile.remove_file(path)
			return "tmp_removed"
		return "tmp_kept"
	if path.ends_with(SAVE_EXTENSION + ROLLBACK_SUFFIX):
		return "recovered"
	if path.ends_with(SAVE_EXTENSION) and not _verifies(path):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(path + CORRUPT_SUFFIX))
		return "corrupt"
	return ""


static func _verifies(path: String) -> bool:
	"""Whether `path` reads and decodes as a whole save file (header, table, CRCs, body hash)."""
	var bytes: PackedByteArray = PackedByteArray()
	if not FileAccess.file_exists(path) or not SaveFile.read_file(path, bytes).is_ok():
		return false
	return SaveFile.decode_file(bytes, SaveFile.Body.new(), null).is_ok()
