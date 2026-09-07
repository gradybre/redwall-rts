extends CanvasLayer
## Placeholder HUD holding the anchored screen zones defined in CLAUDE.md and UI §1.1.
##
## Only UIManager talks to this script; it renders what it is given and owns no
## game state beyond the values currently on screen.
##
## The top-left zone shows the UI §1.1 counter set. A counter nobody has supplied a value for
## renders as UNPOPULATED rather than as a zero or an invented figure: `Fuel-days` has no
## heating-demand divisor in any implemented system, and `Residents`/`Beds` have no model at
## all. `Food-days` IS supplied now that task 2.10 gave GDD §5.8 its divisor, alongside its
## numerator `Ready NP`.
##
## This script renders; it does not derive. `set_counter_text()` prints the caller's string
## byte for byte and `set_counter()` prints the caller's integer unaltered, so a figure on
## screen is always the one the simulation produced. Reformatting a value here -- rounding
## "5.48" to "5.5", or turning the "--" marker into "0.00" -- would fabricate a reading that
## the player cannot tell apart from a computed one, which is why test_hud.gd asserts the
## rendered label text and not just the call.

const ALERT_HOLD_SECONDS: float = 4.0

## Displayed for a counter with no supplied value. Never replaced by a placeholder number.
const UNPOPULATED: String = "--"

## Top-left counters in display order (UI §1.1: Food, Fuel, Wood, Stone, Residents, Beds).
const COUNTER_ORDER: Array[StringName] = [
	&"Food-days", &"Ready NP", &"Fuel-days", &"Wood", &"Stone", &"Residents", &"Beds",
]

const GROUP_SIZE: int = 3

@onready var _resource_label: Label = $Root/ResourceZone/ResourceLabel
@onready var _alert_label: Label = $Root/AlertZone/AlertLabel
@onready var _status_label: Label = $Root/StatusZone/StatusLabel

var _counters: Dictionary = {}
var _alert_seconds_left: float = 0.0


func _ready() -> void:
	"""Start with an empty alert zone and keep ticking while the game is paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	_alert_label.text = ""
	_render_counters()


func _process(delta: float) -> void:
	"""Expire the current alert once its hold time has elapsed."""
	if _alert_seconds_left <= 0.0:
		return
	_alert_seconds_left -= delta
	if _alert_seconds_left <= 0.0:
		_alert_label.text = ""


func set_counter(label: StringName, value: int, unit: String) -> void:
	"""Record one top-left counter as a comma-grouped integer with its unit, and repaint."""
	var text: String = _group_digits(value)
	if unit != "":
		text = "%s %s" % [text, unit]
	_counters[label] = text
	_render_counters()


func set_counter_text(label: StringName, text: String) -> void:
	"""Render a counter whose value is not a plain integer, such as a two-decimal
	food-days figure or the unpopulated marker. The caller supplies the exact
	string so this never formats, rounds, or substitutes a number of its own."""
	_counters[label] = text
	_render_counters()


func clear_counters() -> void:
	"""Drop every recorded counter value so the zone returns to unpopulated."""
	_counters.clear()
	_render_counters()


func set_status(state_name: String, speed: int, calendar_text: String) -> void:
	"""Repaint the top-right zone: game state, selected speed, and the offset-calendar date."""
	_status_label.text = "%s  x%d  %s" % [state_name.capitalize(), speed, calendar_text]


func show_alert(text: String) -> void:
	"""Display a transient message in the top-centre zone."""
	_alert_label.text = text
	_alert_seconds_left = ALERT_HOLD_SECONDS


func _render_counters() -> void:
	"""Rebuild the top-left counter line, marking every unsupplied counter as unpopulated."""
	var parts: PackedStringArray = PackedStringArray()
	for label: StringName in COUNTER_ORDER:
		var text: String = _counters.get(label, UNPOPULATED)
		parts.append("%s %s" % [label, text])
	_resource_label.text = "   ".join(parts)


func _group_digits(value: int) -> String:
	"""Render an integer with comma thousands separators (UI §2.2)."""
	var digits: String = str(absi(value))
	var grouped: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % GROUP_SIZE == 0:
			grouped += ","
		grouped += digits[index]
	if value < 0:
		return "-%s" % grouped
	return grouped
