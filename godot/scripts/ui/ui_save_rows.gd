extends RefCounted
## The save browser's rows (UI-SET-077) for its three tabs (UI-SET-076), built from the slots.
##
## DEC-055 (2026-10-08, Brendan): the quicksave and the pre-demolition quicksave live in the
## AUTOSAVE tab beside the five daily autosaves; MANUAL holds the player's saves (auto-named
## `save_NNN`, optionally renamed); PREWINTER holds the prewinter autosave. A kept rollback
## checkpoint (Q10) is a row marked "Recovered" in the tab of the slot whose load it guarded.
##
## §4.3 gives a row "Settlement+year/season/day+real time time stamp+version+validity". The
## in-game date is the file's own completed tick (its header, read without opening the save);
## the real time stamp is the sidecar's (a recovered file's modification time); validity is the
## header, table and identity check `Slots.row_validity()` runs against this build. The game has
## no settlement-name owner yet, so the row is titled by its save's own name.
##
## Presentation only: nothing here writes a file or reads a store.

const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

const TAB_MANUAL: int = 0
const TAB_AUTOSAVE: int = 1
const TAB_PREWINTER: int = 2
const TAB_COUNT: int = 3
const TAB_NAMES: Array[String] = ["Manual", "Autosave", "Prewinter"]
## The slot kinds each tab lists, in display order.
const TAB_KINDS: Array = [
	[Slots.KIND_MANUAL],
	[Slots.KIND_QUICK, Slots.KIND_DAILY, Slots.KIND_DEMOLITION],
	[Slots.KIND_PREWINTER],
]
const RECOVERED_MARK: String = "Recovered"
const VALID_TEXT: String = "Loads in this build"
const OTHER_BUILD_TEXT: String = "Made by another build; this build cannot load it"
const DAMAGED_TEXT: String = "Cannot be loaded"
const SECONDS_PER_MINUTE: int = 60


class Row:
	"""One UI-SET-077 instance: what it names and what the player reads."""
	var kind: String = ""
	var name: String = ""
	var file: String = ""
	var label: String = ""
	var recovered: bool = false
	var tick: int = -1
	var saved_unix: int = 0
	var valid: bool = false
	var validity_code: StringName = &""
	var title: String = ""
	var when_text: String = ""
	var saved_text: String = ""
	var version_text: String = ""
	var validity_text: String = ""

	func detail_text() -> String:
		"""The row's second line: in-game date, real time, version and validity."""
		return "%s  ·  %s  ·  %s  ·  %s" % [when_text, saved_text, version_text, validity_text]

	func accessible_text() -> String:
		"""Everything the row shows, in reading order, for a screen reader."""
		return "%s. %s. Saved %s. %s. %s." % [title, when_text, saved_text, version_text,
			validity_text]


static func tab_of_kind(kind: String) -> int:
	"""The tab a slot kind is listed in."""
	for tab: int in TAB_COUNT:
		if (TAB_KINDS[tab] as Array).has(kind):
			return tab
	return TAB_MANUAL


static func rows_for_tab(tab: int) -> Array[Row]:
	"""Every row of one tab, newest first; recovered rows carry their mark."""
	var rows: Array[Row] = []
	if tab < 0 or tab >= TAB_COUNT:
		return rows
	for kind: String in TAB_KINDS[tab]:
		for meta: Dictionary in Slots.list_slots(kind):
			rows.append(_slot_row(kind, meta))
		for meta: Dictionary in Slots.list_recovered(kind):
			rows.append(_recovered_row(kind, meta))
	rows.sort_custom(_newer_first)
	return rows


static func _newer_first(a: Row, b: Row) -> bool:
	"""Newest first; within one second, the later name (save_012 before save_011)."""
	if a.saved_unix != b.saved_unix:
		return a.saved_unix > b.saved_unix
	return a.file > b.file


static func find_row(rows: Array[Row], kind: String, name: String) -> int:
	"""The index of the ordinary (not recovered) row of `kind/name`, or -1."""
	for index: int in rows.size():
		if rows[index].kind == kind and rows[index].name == name and not rows[index].recovered:
			return index
	return -1


static func _slot_row(kind: String, meta: Dictionary) -> Row:
	"""An ordinary save's row from its sidecar and its header."""
	var row: Row = Row.new()
	row.kind = kind
	row.name = String(meta.get("name", ""))
	row.file = row.name + Slots.SAVE_EXTENSION
	row.label = String(meta.get("label", ""))
	row.saved_unix = int(meta.get("saved_unix", 0))
	row.title = title_of(kind, row.name, row.label)
	_fill_common(row)
	return row


static func _recovered_row(kind: String, meta: Dictionary) -> Row:
	"""A kept rollback checkpoint's row: the world as it stood before a load that did not finish."""
	var row: Row = Row.new()
	row.kind = kind
	row.name = String(meta["name"])
	row.file = String(meta["file"])
	row.recovered = true
	row.saved_unix = int(meta.get("saved_unix", 0))
	row.title = "%s: the settlement before loading %s" % [RECOVERED_MARK,
		title_of(kind, row.name, "")]
	_fill_common(row)
	return row


static func _fill_common(row: Row) -> void:
	"""Validity from the header, then the date, time stamp and version lines."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	header.completed_tick = -1
	var refusal: SaveHeader.Refusal = Slots.row_validity(row.kind, row.file, header)
	row.valid = refusal.is_ok()
	row.validity_code = refusal.code
	row.tick = header.completed_tick
	row.validity_text = validity_text_of(refusal.code)
	row.when_text = calendar_text_of(row.tick)
	row.saved_text = real_time_text_of(row.saved_unix)
	row.version_text = "Save format %d, development save" % SaveHeader.FORMAT_VERSION


static func title_of(kind: String, name: String, label: String) -> String:
	"""A save's title: the player's name for a manual save, else the slot's own title."""
	match kind:
		Slots.KIND_QUICK:
			return "Quicksave"
		Slots.KIND_DAILY:
			return "Daily autosave %d" % (int(name.trim_prefix("daily_")) + 1)
		Slots.KIND_PREWINTER:
			return "Prewinter autosave"
		Slots.KIND_DEMOLITION:
			return "Pre-demolition quicksave"
	return label if label != "" else name


static func validity_text_of(code: StringName) -> String:
	"""What the validity column says for a header check's code."""
	if code == SaveHeader.REFUSE_NONE:
		return VALID_TEXT
	var text: String = String(code)
	if (text.begins_with("SAVE_IDENTITY_") and text.ends_with("_MISMATCH")) \
			or code == SaveHeader.REFUSE_FUTURE_FORMAT_VERSION or code == SaveHeader.REFUSE_FORMAT_VERSION:
		return "%s (%s)" % [OTHER_BUILD_TEXT, text]
	return "%s (%s)" % [DAMAGED_TEXT, String(code)]


static func calendar_text_of(tick: int) -> String:
	"""The in-game instant of a completed tick: `Y1 Spring 3, 06:15`; unknown when negative."""
	if tick < 0:
		return "Date unknown"
	var moment: SimClockScript.Calendar = SimClockScript.calendar_at(tick)
	return "Y%d %s %d, %s" % [moment.year, moment.season_name().capitalize(), moment.season_day,
		moment.clock_text()]


static func real_time_text_of(unix: int) -> String:
	"""A real-world time stamp in the player's local time: `2026-10-08 14:03`."""
	if unix <= 0:
		return "time unknown"
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var stamp: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias * SECONDS_PER_MINUTE)
	return "%04d-%02d-%02d %02d:%02d" % [stamp["year"], stamp["month"], stamp["day"],
		stamp["hour"], stamp["minute"]]
