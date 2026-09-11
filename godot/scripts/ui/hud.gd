extends CanvasLayer
## The HUD layer: hosts the §4 shell and renders the values UIManager hands it.
##
## Only UIManager talks to this script; it renders what it is given and owns no game state
## beyond the values currently on screen.
##
## The top-left zone shows the UI §1.1 counter set. A counter nobody has supplied a value for
## renders as UNPOPULATED rather than as a zero or an invented figure: `Fuel-days` has no
## heating-demand divisor in any implemented system, and `Beds` has no Building, Furniture or
## Room store at all. `Food-days` IS supplied now that task 2.10 gave GDD §5.8 its divisor,
## alongside its numerator `Ready NP`.
##
## This script renders; it does not derive. `set_counter_text()` prints the caller's string byte
## for byte and `set_counter()` prints the caller's integer unaltered, so a figure on screen is
## always the one the simulation produced. Reformatting a value here -- rounding "5.48" to
## "5.5", or turning the "--" marker into "0.00" -- would fabricate a reading that the player
## cannot tell apart from a computed one, which is why test_hud.gd asserts the rendered label
## text and not just the call.
##
## ---------------------------------------------------------------------------------------
## WHAT CHANGED WITH THE §4 SHELL, AND WHAT DELIBERATELY DID NOT. The six anchored placeholder
## panels this scene used to hold are gone; `ui_shell.gd` now builds the real registry elements
## at §1.2's rectangles, and this script routes into them. Every rendering CONTRACT above is
## unchanged and still asserted by the same tests:
##   * the joined counter line goes to UI-SET-009's ledger line, verbatim;
##   * each counter's own cell (UI-SET-002..007) additionally shows that counter's own value,
##     EXCEPT where the element is rendered unavailable, which the shell refuses to overwrite;
##   * the state/speed/date line goes to UI-SET-101's date trigger, verbatim;
##   * a transient alert goes to UI-SET-011's card.
## `Ready NP` has no cell of its own: §4 binds it inside UI-SET-002's value, whose accessible
## name is "Ready food: "+food_days+" days; "+ready_NP+" nutrition". It is in the ledger line.

const ShellScript := preload("res://scripts/ui/ui_shell.gd")

const ALERT_HOLD_SECONDS: float = 4.0

## Displayed for a counter with no supplied value. Never replaced by a placeholder number.
const UNPOPULATED: String = "--"

## Top-left counters in display order (UI §1.1: Food, Fuel, Wood, Stone, Residents, Beds).
const COUNTER_ORDER: Array[StringName] = [
	&"Food-days", &"Ready NP", &"Fuel-days", &"Wood", &"Stone", &"Residents", &"Beds",
]

## Which §4 counter cell each key is printed into. `Ready NP` has no cell of its own: §4 binds
## it inside UI-SET-002's value, so it appears in the ledger line and not as a seventh cell.
const COUNTER_ELEMENT: Dictionary = {
	&"Food-days": ShellScript.ID_FOOD,
	&"Fuel-days": ShellScript.ID_FUEL,
	&"Wood": ShellScript.ID_WOOD,
	&"Stone": ShellScript.ID_STONE,
	&"Residents": ShellScript.ID_POPULATION,
	&"Beds": ShellScript.ID_BEDS,
}

const GROUP_SIZE: int = 3

@onready var _shell: ShellScript = $Root/Shell as ShellScript

var _counters: Dictionary = {}
var _alert_seconds_left: float = 0.0


func _ready() -> void:
	"""Build the §4 shell, start with an empty alert zone, and keep ticking while paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _shell != null and not _shell.is_built():
		_shell.build()
	_render_counters()
	show_alert("")


func _process(delta: float) -> void:
	"""Expire the current alert once its hold time has elapsed."""
	if _alert_seconds_left <= 0.0:
		return
	_alert_seconds_left -= delta
	if _alert_seconds_left <= 0.0:
		show_alert("")


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
	"""Repaint the top-right readout: game state, selected speed, and the offset-calendar date."""
	if _shell == null:
		return
	_shell.set_status_line("%s  x%d  %s" % [state_name.capitalize(), speed, calendar_text])
	_shell.set_speed_selected(speed)


func set_pause(paused: bool, reasons: String) -> void:
	"""Show UI-SET-086's pause label and UI-SET-014's selected state from the clock's reasons."""
	if _shell == null:
		return
	_shell.set_pause_display(paused, reasons)


func show_alert(text: String) -> void:
	"""Display a transient message in the top-centre zone, or clear it when empty."""
	if _shell == null:
		return
	_shell.set_alert_display(text)
	_alert_seconds_left = ALERT_HOLD_SECONDS if text != "" else 0.0


func show_refusal(text: String) -> void:
	"""Display an exact refusal code and its plain reading in UI-SET-085's error panel."""
	if _shell == null:
		return
	_shell.set_refusal_display(text)


func shell() -> ShellScript:
	"""The §4 shell this layer hosts, for UIManager and for the suite."""
	return _shell


func _render_counters() -> void:
	"""Repaint the ledger line and every counter cell, marking unsupplied counters unpopulated."""
	if _shell == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for label: StringName in COUNTER_ORDER:
		var text: String = _counters.get(label, UNPOPULATED)
		parts.append("%s %s" % [label, text])
		_render_cell(label, text)
	_shell.set_ledger_display("   ".join(parts))


func _render_cell(label: StringName, text: String) -> void:
	"""Print one counter into its own §4 cell, leaving an unavailable cell's reason intact.

	`set_counter_display()` REFUSES for a cell whose owning store does not exist, and that
	refusal is honoured rather than worked around: printing "--" into the Bed counter would
	replace a named missing owner with a marker that reads like a measured absence.
	"""
	if not COUNTER_ELEMENT.has(label):
		return
	_shell.set_counter_display(COUNTER_ELEMENT[label], text)


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
