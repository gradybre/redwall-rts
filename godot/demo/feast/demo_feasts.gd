extends Node
## THE CALLED FEASTS in the village (decision 1701; feature #9): called_feast.gd wired to the cast's names, the kitchen,
## the stores, the calendar, the winter's hearths and cold, the hall's gathering seats, the regatta, the people (the
## feast's company), the village news (the chronicle), the work pace and the HUD's Feast command. Presentation over
## integer rules; nothing writes into the settlement simulation.
##
## THE FEAST COMMAND (UI-SET-032): the regatta unlocked it for its own section (decision 0438); it now opens the Feasts
## panel, whose "The regatta…" button brings the Water panel's Regatta section as the command did.
## EACH FRAME: the feast follows its day; Shared Warmth's cold exposure is set on the winter's cold (cold_exposure.gd
## `gain_permille`); Abundant Tables' work factor is read from the work pace (`add_factor`, once).

const FeastScript := preload("res://demo/feast/called_feast.gd")
const PanelScript := preload("res://demo/feast/feast_panel.gd")
const Rules := preload("res://demo/feast/feast_rules.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const RegattaNodeScript := preload("res://demo/regatta/demo_regatta.gd")
const WinterScript := preload("res://demo/winter/demo_winter.gd")
const ColdScript := preload("res://demo/winter/cold_exposure.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")

## The work pace's factor name for Abundant Tables ("work at 105% (feast 105%)").
const PACE_FACTOR: String = "feast"
const FEAST_TOOLTIP: String = "Call a feast — Hearth, Harvest or Orchard — for one of the next suppers"

var feast: FeastScript = FeastScript.new()
var panel: PanelScript = PanelScript.new()
var services: ServicesScript = null
## What the last frame's feast cost on the main thread, microseconds (the performance check).
var last_usec: int = 0

var _regatta: RegattaNodeScript = null
var _cold: ColdScript = null


func wire(shared: ServicesScript, cast: DemoCastScript, kitchen: KitchenScript, regatta: RegattaNodeScript,
		winter: WinterScript, seats: Callable) -> void:
	"""THE VILLAGE'S HOOK (demo_village.gd), once this node is in the tree (`regatta` and `winter` may be null)."""
	name = "DemoFeasts"
	services = shared
	_regatta = regatta
	var names := PackedStringArray()
	for i: int in cast.actor_count():
		names.append((cast.actor(i) as DemoActorScript).display_name)
	feast.configure(kitchen, shared.stores, shared.calendar, names)
	feast.seats = seats
	feast.post = _chronicle
	feast.say = func(text: String) -> void: services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text)
	if regatta != null:
		feast.bind_regatta(regatta.regatta)
	if winter != null:
		feast.fuel = winter.fuel
		_cold = winter.cold
	shared.work_pace.add_factor(PACE_FACTOR, feast.buffs.work_permille)
	panel.configure(feast)
	panel.set_actions(actions())
	add_child(panel)


func bind_people(share: Callable) -> void:
	"""The people's hook: the feast's company (`share(attendees)`, REQ-SET-036)."""
	feast.share_feast = share


func actions() -> Dictionary:
	"""The panel's buttons, each `() -> String`."""
	return {
		&"theme_prev": _step.bind(&"theme", -1),
		&"theme_next": _step.bind(&"theme", 1),
		&"day_prev": _step.bind(&"day", -1),
		&"day_next": _step.bind(&"day", 1),
		&"host": _step.bind(&"host", 1),
		&"override": _step.bind(&"override", 1),
		&"call": call_feast,
		&"cancel": cancel_feast,
		&"regatta": show_regatta,
	}


func _step(what: StringName, by: int) -> String:
	"""A choice stepped: the theme or day by `by`, the next keeper, the override toggled (no answer line)."""
	match what:
		&"theme":
			feast.step_theme(by)
		&"day":
			feast.step_day(by)
		&"host":
			feast.step_host()
		&"override":
			feast.toggle_override()
	return ""


func call_feast() -> String:
	"""Call the feast as chosen: done, or why not."""
	var why: String = feast.hold(feast.choice_theme, feast.choice_day, feast.choice_host, feast.override)
	return "The %s feast is called for %s" % [Rules.THEME_NAMES[feast.plan_theme], feast.day_text(feast.plan_day)] \
		if why.is_empty() else "Can't: %s" % why


func cancel_feast() -> String:
	"""Cancel the called feast: done, or why not."""
	var why: String = feast.cancel()
	return "The feast is cancelled: everything set aside is back" if why.is_empty() else "Can't: %s" % why


func show_regatta() -> String:
	"""The Water panel's Regatta section, as the Feast command brought before (the regatta's own planning)."""
	if _regatta == null:
		return "No regatta in this village"
	panel.close_window()
	_regatta.show_section()
	return ""


func take_feast_command(shell: UiShell) -> bool:
	"""THE FEAST COMMAND: opened on the Feasts panel (the regatta's own connection replaced). False without one."""
	var command := shell.control_for(UiShell.ID_FEAST) as Button if shell != null else null
	if command == null:
		return false
	if _regatta != null and command.pressed.is_connected(_regatta.show_section):
		command.pressed.disconnect(_regatta.show_section)
	command.disabled = false
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_FEAST)
	command.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index], FEAST_TOOLTIP, "")
	command.accessibility_description = FEAST_TOOLTIP
	command.pressed.connect(panel.open)
	return true


func feasts_completed() -> int:
	"""M4's "12 completed feasts": the called feasts at least one resident ate, and the regatta's served."""
	return feast.completed + (_regatta.regatta.feasts_served if _regatta != null else 0)


func _process(_delta: float) -> void:
	"""The feast follows its day; Shared Warmth reaches the winter's cold."""
	var started: int = Time.get_ticks_usec()
	feast.update()
	if _cold != null:
		_cold.gain_permille = feast.buffs.cold_permille(feast.now_tick())
	last_usec = Time.get_ticks_usec() - started


func _chronicle(text: String, summary: String) -> void:
	"""The feast's chronicle line in the village news (Village: the history's chronicle)."""
	services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text, summary)


func _exit_tree() -> void:
	"""Drop the hooks that hold this node (the regatta's are bound to the feast; the feast's lambdas hold it), and leave
	the winter's cold at its full rate. The work pace's "feast" factor is a method Callable on the buffs, which outlive
	this node with the feast it owns."""
	feast.say = Callable()
	feast.post = Callable()
	feast.share_feast = Callable()
	panel.set_actions({})
	if _cold != null:
		_cold.gain_permille = ColdScript.FULL_GAIN_PERMILLE
	if _regatta != null:
		_regatta.regatta.feast_clash = Callable()
		_regatta.regatta.food_days_after = Callable()
		_regatta.regatta.fuel_days_after = Callable()
