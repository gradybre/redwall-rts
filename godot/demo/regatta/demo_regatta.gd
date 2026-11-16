extends Node3D
## THE REGATTA in the village (decision 0438): regatta.gd wired to the cast, the boat core's fleet and the fishery's
## skills and ice, the kitchen, the stores, the calendar and weather, the people (the winners' deed, the feast's company),
## the village news (the chronicle), the Water panel's Regatta section and the HUD's Feast command. Presentation over
## integer rules; nothing writes into the simulation.
##
## PLAYER VERBS (the Water panel's Regatta section; every button's tooltip is its ACTION CARD from the order's own
## decision, decision 0332):
##   ◀ Day / Day ▶          the regatta's day: its season's days from tomorrow (the first summer's, before it)
##   Host ▸                 the next resident to host it (never its cook or a racer: the preview says why)
##   Hold the regatta       held: the feast's main course reserved, its service wood set aside, the crews named
##   Override reserves      REQ-SET-101's explicit override for this regatta, when its reserves would fall under 3 days
##   Skip this season       no penalty and nothing withheld; a held plan's food and wood given back untouched
## THE FEAST COMMAND (UI-SET-032, the HUD's Feast): unlocked by the demo for the regatta, it brings the Water panel and
## its Regatta section forward -- until the called feasts take it over (demo/feast/demo_feasts.gd, decision 1701): it
## then opens the Feasts panel, whose "The regatta…" button calls `show_section`.
##
## THE MARKS: two barrels afloat at the lanes' turning marks while the crews are called and the race is rowed.

const RegattaScript := preload("res://demo/regatta/regatta.gd")
const Rules := preload("res://demo/regatta/regatta_rules.gd")
const FisheryNodeScript := preload("res://demo/fishery/demo_fishery.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")

const PANEL_REFRESH_S: float = 0.25
const MARK_KEY: StringName = &"barrel"
## A mark's base below the datum, so it floats (presentation).
const MARK_Y_M: float = -0.32
const FEAST_ICON: String = "res://ui/painted/res_food_ready.svg"
const FEAST_TOOLTIP: String = "Plan the season's regatta and its feast (the Water panel's Regatta section)"

var regatta: RegattaScript = RegattaScript.new()
var services: ServicesScript = null
## What the last frame's regatta cost on the main thread, microseconds (the performance check).
var last_usec: int = 0

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _waterplay: WaterplayScript = null
var _card: CardScript = CardScript.new()
var _marks: Array[MeshInstance3D] = []
var _refresh_in: float = 0.0


func configure(cast: DemoCastScript, command: DemoCommandScript, shared: ServicesScript, waterplay: WaterplayScript,
		fishery: FisheryNodeScript, kitchen: KitchenScript) -> void:
	"""Wire the regatta into this village (`command` and `waterplay` may be null in a check)."""
	name = "DemoRegatta"
	_cast = cast
	_command = command
	_waterplay = waterplay
	services = shared
	var f: RefCounted = fishery.fishery
	regatta.configure(cast, f.get(&"fleet"), f.get(&"skills"), f.get(&"ice"), kitchen, shared.stores, shared.calendar,
		shared.weather, f.get(&"map"))
	regatta.post = _chronicle
	regatta.say = func(text: String) -> void: services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text)
	if waterplay != null:
		waterplay.panel.action.connect(on_action)
	if command != null:
		command.add_task_text(task_text)
	_build_marks(shared.props)


func bind_people(record: Callable, share: Callable) -> void:
	"""The people's hooks: the winners' deed (`record(who, subject) -> int`) and the feast's company (`share(who)`)."""
	regatta.record_deed = record
	regatta.share_feast = share


func _build_marks(props: PropsScript) -> void:
	"""A floating barrel at each lane's turning mark, hidden until the crews are called."""
	var table: PropsScript = props if props != null else PropsScript.new()
	for boat: int in RegattaScript.BOATS:
		var mark: MeshInstance3D = table.instance(MARK_KEY)
		mark.name = "RegattaMark%d" % (boat + 1)
		var at: Vector2 = Rules.mark_m(boat)
		mark.transform = Transform3D(Basis.IDENTITY, Vector3(at.x + 0.9, MARK_Y_M, at.y)) * table.fit_of(MARK_KEY)
		mark.visible = false
		add_child(mark)
		_marks.append(mark)


func unlock_feast_command(shell: UiShell) -> bool:
	"""THE FEAST COMMAND (UI-SET-032): the shell draws it locked (no feast planner is built); the demo unlocks it for the
	regatta -- enabled, an icon, its tooltip in the command strip's form, and pressed it brings the Regatta section."""
	if shell == null:
		return false
	var feast := shell.control_for(UiShell.ID_FEAST) as Button
	if feast == null:
		return false
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_FEAST)
	feast.disabled = false
	feast.icon = load(FEAST_ICON) as Texture2D
	feast.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index], FEAST_TOOLTIP, "")
	feast.accessibility_description = FEAST_TOOLTIP
	feast.pressed.connect(show_section)
	return true


func show_section() -> void:
	"""The Water panel forward, its Regatta section filled."""
	if _waterplay == null:
		return
	_waterplay.panel_wanted.emit()
	_refresh_in = 0.0
	refresh_panel()
	_waterplay.panel.scroll_to_line(&"regatta_title")


func task_text(who: int) -> String:
	"""What `who` does for the regatta (a crew place), in words ("" when nothing)."""
	var place: int = regatta.crews.find(who) if regatta.state >= RegattaScript.ST_CREWING and regatta.state <= RegattaScript.ST_RACED else -1
	return regatta.crew_text(place) if place >= 0 and regatta.crew_step[place] != RegattaScript.C_NONE else ""


# --- per frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Follow the regatta's day on the calendar; the marks; the panel on real time while shown."""
	var started: int = Time.get_ticks_usec()
	regatta.update()
	var marked: bool = regatta.state == RegattaScript.ST_CREWING or regatta.state == RegattaScript.ST_RACING
	for mark: MeshInstance3D in _marks:
		mark.visible = marked
	last_usec = Time.get_ticks_usec() - started
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		if _waterplay != null and _waterplay.panel.is_shown():
			refresh_panel()


func _chronicle(text: String, summary: String) -> void:
	"""The occasion's chronicle line in the village news (Village: the history's chronicle)."""
	services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text, summary)


# --- the orders ------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Water panel button of the regatta's (others are the water's and the ferry's own)."""
	match action_name:
		PanelScript.ACTION_REGATTA_PREV_DAY:
			regatta.step_day(-1)
		PanelScript.ACTION_REGATTA_NEXT_DAY:
			regatta.step_day(1)
		PanelScript.ACTION_REGATTA_HOST:
			regatta.step_host()
		PanelScript.ACTION_REGATTA_OVERRIDE:
			regatta.override = not regatta.override
		PanelScript.ACTION_REGATTA_HOLD:
			_answer(_ordered(regatta.hold(regatta.choice_day, regatta.choice_host, regatta.override),
				"The regatta is held: %s" % regatta.day_text(regatta.choice_day)))
		PanelScript.ACTION_REGATTA_SKIP:
			_answer(_ordered(regatta.skip(), "This season's regatta is skipped — no penalty"))
		_:
			return
	_refresh_in = 0.0


func _ordered(why: String, done: String) -> String:
	"""An order's answer: done, or why not."""
	return done if why.is_empty() else "Can't: %s" % why


func _answer(said: String) -> void:
	"""An order's answer beside the selection; the Water panel comes forward."""
	if _command != null and _command.panel() != null:
		_command.say(said)
	if _waterplay != null:
		_waterplay.panel_wanted.emit()


# --- the panel ---------------------------------------------------------------------------------------

func refresh_panel() -> void:
	"""Fill the Regatta section and set its buttons' cards (only while shown)."""
	var panel: PanelScript = _waterplay.panel
	regatta.keep_choice_current()
	panel.show_regatta(panel_lines())
	var card: CardScript = hold_card()
	panel.set_card(PanelScript.ACTION_REGATTA_HOLD, card.text(), card.is_ok())
	card = override_card()
	panel.set_card(PanelScript.ACTION_REGATTA_OVERRIDE, card.text(), card.is_ok())
	card = skip_card()
	panel.set_card(PanelScript.ACTION_REGATTA_SKIP, card.text(), card.is_ok())
	var planning: bool = regatta.state == RegattaScript.ST_IDLE
	for action: StringName in PanelScript.REGATTA_CHOICE_ACTIONS:
		panel.set_card(action, PanelScript.BUTTON_TIPS.get(action, ""), planning)


func panel_lines() -> Dictionary:
	"""The section's text (water_panel.gd REGATTA_LINES)."""
	return {&"regatta_status": regatta.status_line(), &"regatta_choice": choice_line(), &"regatta_preview": preview_text()}


func choice_line() -> String:
	"""'Day: Summer 3 · Host: Wenna Tallowby · reserves override: off'."""
	if regatta.state != RegattaScript.ST_IDLE:
		return "Day: %s · Host: %s" % [regatta.day_text(regatta.plan_day), regatta.name_of(regatta.plan_host)]
	return "Day: %s · Host: %s · reserves override: %s" % [regatta.day_text(regatta.choice_day),
		regatta.name_of(regatta.choice_host), "on" if regatta.override else "off"]


func preview_text() -> String:
	"""The feast's preview (regatta.gd `preview_lines`) with the decision's answer first; after the day, its tally."""
	if regatta.state == RegattaScript.ST_DONE:
		return "%d of %d shared the feast. The moment: %s" % [regatta.attendees.size(), regatta.eligible, regatta.moment_line]
	var day: int = regatta.choice_day if regatta.state == RegattaScript.ST_IDLE else regatta.plan_day
	var host: int = regatta.choice_host if regatta.state == RegattaScript.ST_IDLE else regatta.plan_host
	var lines: PackedStringArray = regatta.preview_lines(day, host)
	if regatta.state == RegattaScript.ST_IDLE:
		var why: String = regatta.refusal(day, host, regatta.override)
		lines.insert(0, "Can't hold it: %s — to fix: %s" % [why, regatta.refused_fix] if not why.is_empty() else "Ready to hold")
	return "\n".join(lines)


# --- the cards (decision 0332: each from its order's own decision) -------------------------------------

func hold_card() -> CardScript:
	"""Hold the regatta's card: `regatta.refusal`, the feast's food and wood, the day and its host."""
	_card.reset("Hold the %s regatta" % regatta.day_text(regatta.choice_day))
	regatta.count_supper(regatta.choice_day)
	var e: int = regatta.residents()
	_card.add_cost("Beans", &"beans", regatta.free_beans(), regatta.main_food_milli(e))
	_card.add_cost(_sentence_case(RegattaScript.main_greens_words()), RegattaScript.main_greens_good(), regatta.free_greens(), regatta.main_food_milli(e))
	_card.add_cost("Wood", &"wood", services.stores.wood_milli_u, Rules.service_wood_milli(e))
	_card.result = "The race at %02d:00, the %s feast at supper for %d; remembered in the chronicle" % [Rules.RACE_HOUR,
		Rules.THEME_NAME, e]
	_card.prerequisites.append("a host who neither races nor cooks; two helms (fishing 1); the main course's food free")
	_card.prerequisites.append("for every course and %s: the nut loaf's flour and nuts, the infusion's herb (%s)" % [
		Rules.BUFF_NAME, regatta.served_words() if regatta.state != RegattaScript.ST_IDLE else _menu_now(e)])
	var why: String = regatta.refusal(regatta.choice_day, regatta.choice_host, regatta.override)
	if not why.is_empty():
		_card.refuse(regatta.refused_code, why, regatta.refused_fix)
		return _card
	_card.who = "Host: %s; %s" % [regatta.name_of(regatta.choice_host), regatta.race_words(regatta.crews_for(regatta.choice_host))]
	return _card


static func _sentence_case(words: String) -> String:
	"""'greens or roots' -> 'Greens or roots' (a card's cost name)."""
	return words.substr(0, 1).to_upper() + words.substr(1)


func _menu_now(e: int) -> String:
	"""What a regatta held now would serve beside its main course, from the pantry's real stock."""
	var short := PackedStringArray()
	for why: String in [regatta.menu.second_short(e), regatta.menu.infusion_short(e)]:
		if not why.is_empty():
			short.append(why)
	return "all there now" if short.is_empty() else "short now: %s" % "; ".join(short)


func override_card() -> CardScript:
	"""Override reserves' card: REQ-SET-101's explicit override, for this regatta only."""
	_card.reset("Override the reserve warning for this regatta: %s" % ("on" if regatta.override else "off"))
	_card.result = "REQ-SET-101: hold it even when it leaves under %d days of ready food or wood (this regatta only)" % Rules.RESERVE_DAYS
	if regatta.state != RegattaScript.ST_IDLE:
		_card.refuse("PLANNED", "the regatta is %s" % RegattaScript.STATE_WORDS[regatta.state], "")
	return _card


func skip_card() -> CardScript:
	"""Skip this season's card: `regatta.skip_refusal`; nothing is lost."""
	_card.reset("Skip this season's regatta")
	_card.result = "No penalty and nothing withheld; a held plan's food and wood go back untouched; the next season's is yours to plan"
	var why: String = regatta.skip_refusal()
	if not why.is_empty():
		_card.refuse("UNDER_WAY", why, "")
	return _card
