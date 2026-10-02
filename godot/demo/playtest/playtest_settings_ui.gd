extends VBoxContainer
## The game menu's PLAYTEST LOG section (demo_menu.gd's Settings page, last): where the logs are, Open log folder,
## Copy report and Mark a problem here (F12). Decision 0562. DEMO UI in the woodland skin.
##
## Every button goes to the process's playtest log (playtest_log.gd), so nothing needs wiring by a host; with no
## session (the test worker, a copy that could not write its folder) the status line says so. The folder line is
## the full path on this machine -- shown here, never put in a report.

const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const TITLE: String = "Playtest log"
const NOTE: String = "Found a bug, a crash or a freeze? Press F12 (Fn+F12 on a Mac) the moment you see it, or Mark below. Then send Brendan the newest playtest log file from the log folder, or paste Copy report into your message."
const FOLDER_TEXT: String = "Log folder: %s"
const OPEN_TEXT: String = "Open log folder"
const COPY_TEXT: String = "Copy report"
const MARK_TEXT: String = "Mark a problem here (F12)"
const OPEN_TIP: String = "Show the folder of playtest logs (the newest is last by name), with Godot's own godot.log"
const COPY_TIP: String = "Copy this machine's details and the last lines of this session's log, to paste into a message"
const MARK_TIP: String = "Write 'something went wrong here' into the log with the time and what you did last"
const OPENED: String = "Opened the log folder."
const NOT_OPENED: String = "Could not open the folder: it is %s"
const COPIED: String = "Copied the report (%d lines): paste it into your message."
const MARKED: String = "Marked #%d in the log."
const NO_LOG: String = "The playtest log is not running in this copy."

var _folder: Label = null
var _status: Label = null
var _open: Button = null
var _copy: Button = null
var _mark: Button = null


func _init() -> void:
	"""Built at once; the folder line fills in on `refresh`."""
	name = "PlaytestSettings"
	add_theme_constant_override(&"separation", 4)
	add_child(FarmUi.label(TITLE, FarmUi.BODY_PX, Palette.INK, true))
	add_child(_wrapped(NOTE, Palette.UMBER))
	_folder = _wrapped("", Palette.UMBER)
	_folder.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	add_child(_folder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	_open = _button(OPEN_TEXT, OPEN_TIP, open_folder, row)
	_copy = _button(COPY_TEXT, COPY_TIP, copy_report, row)
	_mark = _button(MARK_TEXT, MARK_TIP, mark, self)
	_status = _wrapped("", Palette.INK)
	_status.visible = false
	add_child(_status)
	refresh()


func _wrapped(text: String, colour: Color) -> Label:
	"""A small wrapping line."""
	var line: Label = FarmUi.label(text, FarmUi.SMALL_PX, colour)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _button(text: String, tip: String, action: Callable, parent: Node) -> Button:
	"""A button with its tooltip, pressing `action`."""
	var button: Button = FarmUi.button(text)
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func refresh() -> void:
	"""The folder line as it stands (the menu calls this when Settings opens)."""
	_folder.text = FOLDER_TEXT % PlaytestLog.folder()


func open_folder() -> bool:
	"""Open log folder."""
	var opened: bool = PlaytestLog.open_folder()
	_say(OPENED if opened else NOT_OPENED % PlaytestLog.folder())
	return opened


func copy_report() -> int:
	"""Copy report: the line count copied (0 with no session)."""
	var lines: int = PlaytestLog.copy_report()
	_say(COPIED % lines if lines > 0 else NO_LOG)
	return lines


func mark() -> int:
	"""Mark a problem here: the mark's number (0 with no session)."""
	var number: int = PlaytestLog.mark()
	_say(MARKED % number if number > 0 else NO_LOG)
	return number


func status_text() -> String:
	"""The status line (checks)."""
	return _status.text


func action_button(k: int) -> Button:
	"""Open (0), Copy (1), Mark (2) (checks)."""
	return [_open, _copy, _mark][k]


func _say(text: String) -> void:
	"""Show the status line."""
	_status.text = text
	_status.visible = true
