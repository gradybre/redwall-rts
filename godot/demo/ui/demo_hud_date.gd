extends RefCounted
## The HUD's date shows the demo calendar. Decision 0196 (live demo). Presentation only.
##
## UI-SET-101, the date trigger in the top-right time cluster, is printed by UIManager from the
## SETTLEMENT's clock (GameManager), which runs at 30 ticks a second -- 25 real seconds a game hour --
## while the demo's farm, weather and notices run on the demo's ONE calendar (demo_calendar.gd; since
## decision 0421 also 25 s a game hour, but its own counter, started and paused with the demo's). Two dates
## on one screen was wrong. So the demo prints its calendar's DAY there, THROUGH
## THE SHELL'S OWN PUBLIC DISPLAY ENTRY POINT, `set_status_line()`, and nothing else: GameManager,
## UIManager, the simulation and ui_shell.gd are untouched, and nothing is written into sim state.
##
## WHAT FITS. The trigger is 120 logical px with a 24 px calendar icon: 88 px of text. UIManager's own
## "Playing  x1  Y1 spring 1" never fitted (it has always read "Playing x"), and no date with an hour
## fits at the HUD's 18 px. So the trigger shows the day the way the farm panel and every notice name
## it -- "Summer 12", at most 83 px at TEXT_PX (measured in the woodland skin's font) -- and its tooltip
## carries the whole line: the full date and hour, the state and the speed. The pause and speed
## toggles beside it already show the state and the speed. The farm panel's clock line
## ("Y1 Summer 12, 14:00 · 22 °C") and the notices' stamps begin with the same calendar's date.
##
## UIManager repaints the line on a state change, a speed change and a settlement day; `sync()` notices
## its own text was replaced and paints the demo's back. Per frame it compares three integers and one
## string; it formats anew only when the demo hour, the state or the speed changed.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

## The trigger's type size: the largest at which every season's day 12 fits its 88 px (demo skin).
const TEXT_PX: int = 15

var _shell: UiShell = null
var _calendar: CalendarScript = null
var _time: GameManagerScript = null
var _built: bool = false
var _hour: int = 0
var _state: int = 0
var _speed: int = 0
var _wanted: String = ""
var _tooltip: String = ""


func bind(shell: UiShell, calendar: CalendarScript, time_source: GameManagerScript) -> void:
	"""Print `calendar`'s day on `shell`'s date trigger, with `time_source`'s state and requested speed
	in its tooltip."""
	_shell = shell
	_calendar = calendar
	_time = time_source
	_built = false
	if _shell != null:
		_shell.status_label().add_theme_font_size_override(&"font_size", TEXT_PX)


static func tooltip_text(date: String, state_name: String, speed: int) -> String:
	"""The trigger's tooltip: 'Y1 Spring 3, 14:00 (demo calendar) · Playing x1'."""
	return "%s (demo calendar) · %s x%d" % [date, state_name.capitalize(), speed]


func wanted() -> String:
	"""The text the date trigger should read now ("" before the first sync)."""
	return _wanted


func sync() -> bool:
	"""Keep the date trigger on the demo calendar; true when it painted this call."""
	if _shell == null or not is_instance_valid(_shell) or _calendar == null or _time == null:
		return false
	var hour: int = _calendar.hour_index()
	var state: int = _time.get_state()
	var speed: int = _time.get_speed()
	if not _built or hour != _hour or state != _state or speed != _speed:
		_built = true
		_hour = hour
		_state = state
		_speed = speed
		var at := _calendar.now()
		_wanted = CalendarScript.day_text(at.season, at.season_day)
		_tooltip = tooltip_text(_calendar.date_text(), _time.get_state_name(), speed)
	var trigger: Button = _shell.status_label()
	if trigger.text == _wanted and trigger.tooltip_text == _tooltip:
		return false
	_shell.set_status_line(_wanted)
	trigger.tooltip_text = _tooltip
	return true
