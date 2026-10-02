extends VBoxContainer
## The seasonal planner's TENDING tab (review ECO-007, decision 0885; farm_tending.gd): for the field beds and the
## kitchen garden, each group's three standing policies (on or off), its daily work budget, the most it may spend in
## the next day -- shown before anything is spent -- who does the work, and today's exceptions. DEMO UI in the woodland
## skin; every change is the player's press, applied at once to the next farm hour.

const TendingScript := preload("res://demo/farm/farm_tending.gd")
const GardenScript := preload("res://demo/farm/farm_garden.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const NOTE_PX: int = 14
const INTRO: String = "Standing orders for a group of beds. A policy orders the same jobs as the bed's own buttons, only on growing crops, and spends at most the group's budget a day (the work of each job, the walks not counted). Only what it could not do is posted to the news. It never digs a ditch, raises a bed or turns the weir's sluice: those stay your choice."
const POLICY_TIPS: Array[String] = [
	"With a frost due (announced at noon the day before), Cover each growing bed that is not covered or raised",
	"Water each growing bed below its crop's range, once a day (§5.6 tending: 0.25 U of well water)",
	"Open a fitted outlet over a dry tunnel to Drain when a bed is too wet; say which wet beds need a ditch, raising or the sluice",
	"Sow each empty bed with the crop you chose for it, else its rotation's next crop (the bed panel's Rotation ▸), when its season and soil allow",
]
const WORKERS: Array[String] = ["Worked by: whoever is free, the Field crew first (the work board).",
	"Worked by: the cook between meals (Kitchen garden tab), otherwise whoever is free."]

var wide: Array[Label] = []

var _tending: TendingScript = null
var _policy_buttons: Array[Button] = []
var _budget_buttons: Array[Array] = []
var _tomorrow: Array[Label] = []
var _exceptions: Array[Label] = []


func _init() -> void:
	"""Built at once; filled by `refresh` once policies are bound."""
	name = "TendingPage"
	add_theme_constant_override(&"separation", 6)
	_note(INTRO, Palette.UMBER)
	for group: int in TendingScript.GROUP_COUNT:
		_build_group(group)


func _build_group(group: int) -> void:
	"""A group's heading, its policies, its budget row, the next day's most, who works it and its exceptions."""
	add_child(FarmUi.label(TendingScript.GROUP_NAMES[group], FarmUi.BODY_PX, Palette.INK, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 8)
	for policy: int in TendingScript.POLICY_COUNT:
		var made: Button = FarmUi.button(TendingScript.POLICY_NAMES[policy], NOTE_PX)
		made.toggle_mode = true
		made.tooltip_text = POLICY_TIPS[policy]
		made.pressed.connect(toggle.bind(group, policy))
		row.add_child(made)
		_policy_buttons.append(made)
	add_child(row)
	add_child(_budget_row(group))
	_tomorrow.append(_note("", Palette.INK))
	_note(WORKERS[group], Palette.UMBER)
	_exceptions.append(_note("", Palette.CLAY))


func _budget_row(group: int) -> HBoxContainer:
	"""'Budget a day:' and one button a BUDGET_STEPS step, one pressed."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var caption: Label = FarmUi.label("Budget a day:", NOTE_PX, Palette.INK)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var group_buttons: Array[Button] = []
	var buttons := ButtonGroup.new()
	for step: int in TendingScript.BUDGET_STEPS.size():
		var made: Button = FarmUi.button("%d WU" % TendingScript.BUDGET_STEPS[step], NOTE_PX)
		made.toggle_mode = true
		made.button_group = buttons
		made.tooltip_text = "Its policies may order at most %d WU of work a day" % TendingScript.BUDGET_STEPS[step]
		made.pressed.connect(set_budget.bind(group, step))
		row.add_child(made)
		group_buttons.append(made)
	_budget_buttons.append(group_buttons)
	return row


func _note(text: String, colour: Color) -> Label:
	"""A full-width wrapping line (the planner widens it: `wide`)."""
	var line: Label = FarmUi.label(text, NOTE_PX, colour)
	add_child(line)
	wide.append(line)
	return line


func bind(tending: TendingScript) -> void:
	"""Show these policies."""
	_tending = tending
	refresh()


func toggle(group: int, policy: int) -> void:
	"""Turn a policy on or off."""
	if _tending != null:
		_tending.set_policy(group, policy, not _tending.is_on(group, policy))
	refresh()


func set_budget(group: int, step: int) -> void:
	"""A group's daily budget."""
	if _tending != null:
		_tending.set_budget_step(group, step)
	refresh()


func refresh() -> void:
	"""Rewrite every group's policies, budget, next day and exceptions from the policies as they stand."""
	if _tending == null:
		return
	for group: int in TendingScript.GROUP_COUNT:
		for policy: int in TendingScript.POLICY_COUNT:
			_policy_buttons[group * TendingScript.POLICY_COUNT + policy].set_pressed_no_signal(_tending.is_on(group, policy))
		var steps: Array = _budget_buttons[group]
		for step: int in steps.size():
			(steps[step] as Button).set_pressed_no_signal(step == _tending.budget_step[group])
		_tomorrow[group].text = _tending.tomorrow_text(group)
		var lines := PackedStringArray()
		for policy: int in TendingScript.POLICY_COUNT:
			var said: String = _tending.exception_text[group * TendingScript.POLICY_COUNT + policy]
			if not said.is_empty():
				lines.append("Today: " + said)
		_exceptions[group].text = "\n".join(lines)
		_exceptions[group].visible = not lines.is_empty()


func policy_button(group: int, policy: int) -> Button:
	"""A policy's toggle (checks)."""
	return _policy_buttons[group * TendingScript.POLICY_COUNT + policy]


func budget_button(group: int, step: int) -> Button:
	"""A budget step's button (checks)."""
	return _budget_buttons[group][step]


func tomorrow_line(group: int) -> String:
	"""A group's next-day line as shown (checks)."""
	return _tomorrow[group].text


func exceptions_line(group: int) -> String:
	"""A group's exceptions as shown ('' hidden; checks)."""
	return _exceptions[group].text if _exceptions[group].visible else ""
