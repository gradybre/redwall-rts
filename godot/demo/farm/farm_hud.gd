extends RefCounted
## Where the farm meets the game's HUD, through the UI layer only. Decision 0196.
##
## THE FOOD FIGURE. The HUD's top-left Food cell (UI-SET-002) is fed by UIManager with
## EconomySystem's ready-food days -- the SETTLEMENT's inventory, which the demo farm must not write
## into. So the demo shows its pantry total in that cell THROUGH THE SHELL'S OWN PUBLIC ENTRY POINT,
## `set_counter_display(ID_FOOD, "34 U")`, and nothing else: UIManager, EconomySystem and the
## simulation are untouched. UIManager repaints the cell whenever stocks change or a day passes;
## `sync()` notices its own text was replaced (the cell no longer reads what it painted) and paints
## the pantry total back. The ledger line (UI-SET-009) still carries the settlement's figures -- a
## known, stated difference, since that line is the game's exact record.
##
## THE FOOD COMMAND. UI-SET-030 ("Manage recipes and food orders", K) has no page built in the game
## yet, so the shell draws it locked. The demo unlocks the button, gives it its own painted food
## icon, and connects it -- and K, `open_food` -- to the Pantry.
##
## NO ALERTS go to the HUD's alert cards: the farm's warnings go to the demo's one notice feed
## (demo_notices.gd), which explains why.

const UiShell := preload("res://scripts/ui/ui_shell.gd")

const FOOD_ICON: String = "res://ui/painted/res_food_ready.svg"
const FOOD_TOOLTIP: String = "Pantry: the farm's ingredients in store, and the dishes they feed (K)"

var _shell: UiShell = null
var _painted_units: int = -1
var _painted_label: String = ""
var _warned: bool = false


func bind(shell: UiShell) -> void:
	"""Work on this HUD shell (null: nothing to do)."""
	_shell = shell


static func food_text(units: int) -> String:
	"""The Food cell's value for the pantry total."""
	return "%d U" % units


func sync(units: int) -> bool:
	"""Show `units` in the Food cell, repainting it only when the total changed or UIManager wrote
	over it (an integer and a string reference compared per frame; no formatting). True when it
	painted this call."""
	if _shell == null or not is_instance_valid(_shell):
		return false
	var label: Label = _shell.counter_value_label(UiShell.ID_FOOD)
	if label == null or (units == _painted_units and label.text == _painted_label):
		return false
	if not _shell.set_counter_display(UiShell.ID_FOOD, food_text(units)):
		if not _warned:
			push_warning("demo farm: the Food cell refused the pantry total (%s)" % _shell.last_refusal())
			_warned = true
		return false
	_painted_units = units
	_painted_label = label.text
	return true


func unlock_food_command(open_pantry: Callable) -> bool:
	"""Enable the Food command and point it at the Pantry. False when there is no such button."""
	if _shell == null:
		return false
	var food := _shell.control_for(UiShell.ID_FOOD_ORDERS) as Button
	if food == null:
		return false
	food.disabled = false
	food.icon = load(FOOD_ICON) as Texture2D
	food.tooltip_text = FOOD_TOOLTIP
	food.accessibility_description = FOOD_TOOLTIP
	food.pressed.connect(open_pantry)
	return true

