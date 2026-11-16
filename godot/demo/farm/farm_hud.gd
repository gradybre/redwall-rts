extends RefCounted
## Where the farm meets the game's HUD, through the UI layer only. Decision 0196.
##
## THE FOOD FIGURE. The top bar's Ready food cell shows the pantry's total, painted -- with every other cell --
## by the demo's HUD read model (demo/ui/demo_hud_model.gd, demo_hud_counters.gd; decision 0251). The cell and the
## Pantry's headline word the same total, summed in milli-U, in baskets of food through goods_measures.gd (decisions
## 1011 and 1801; decision 0222's rounding kept).
##
## THE FOOD COMMAND. UI-SET-030 ("Manage recipes and food orders", K) has no page built in the game
## yet, so the shell draws it locked. The demo unlocks the button, gives it its own painted food
## icon, and connects it -- and K, `open_food` -- to the Pantry.
##
## NO ALERTS go to the HUD's alert cards: the farm's warnings go to the demo's one notice feed
## (demo_notices.gd), which explains why.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")

const FOOD_ICON: String = "res://ui/painted/res_food_ready.svg"
## What the unlocked Food command does. Its tooltip is "Food (K) — " and this, in the command strip's
## one form (demo_command_tips.gd), the key read from the input map's `open_food`, never written here.
const FOOD_TOOLTIP: String = "Pantry: the farm's ingredients in store, and the dishes they feed"

var _shell: UiShell = null


func bind(shell: UiShell) -> void:
	"""Work on this HUD shell (null: nothing to do)."""
	_shell = shell


func unlock_food_command(open_pantry: Callable) -> bool:
	"""Enable the Food command and point it at the Pantry. False when there is no such button."""
	if _shell == null:
		return false
	var food := _shell.control_for(UiShell.ID_FOOD_ORDERS) as Button
	if food == null:
		return false
	food.disabled = false
	food.icon = load(FOOD_ICON) as Texture2D
	food.tooltip_text = food_tooltip()
	food.accessibility_description = FOOD_TOOLTIP
	food.pressed.connect(open_pantry)
	return true


static func food_tooltip() -> String:
	"""The unlocked Food command's tooltip: "Food (K) — Pantry: ...", the key from the input map."""
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_FOOD_ORDERS)
	return CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index], FOOD_TOOLTIP, "")
