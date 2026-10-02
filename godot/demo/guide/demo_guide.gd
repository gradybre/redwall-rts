extends Node
## THE FIRST-VILLAGE GUIDE'S OWNER (decision 0481; review F49, P7, UX-017 to UX-020): the demo-specific objective owner
## the review found missing. Made by demo_village.gd over the village's real models (guide_world.gd); writes nothing into
## them. It holds:
##   * the OUTCOME LEDGER (guide_facts.gd), looked at every frame from the first, shown or not;
##   * the PROGRESS (guide_steps.gd) and the ONE OBJECTIVE CARD (guide_card.gd, UI-SET-072) with its world MARKER
##     (guide_beacon.gd), redrawn a few times a second on real time (paused too: guidance is never lost to a pause,
##     and a pause completes nothing -- a confirmation counts down only unpaused time);
##   * the VILLAGE GUIDE window (guide_window.gd): objectives, projects, field guide, help, practice -- behind the HUD's
##     Objectives command (O, unlocked here as the work board unlocks Jobs), the card's Help, the game menu's guide row
##     and the Demo Lab's "Practice stories";
##   * the PROJECTS (projects.gd), measured on the same real figures;
##   * the VILLAGE GOALS (demo/goals/demo_goals.gd, decision 0781): the GDD's milestones and the village goals, measured on
##     the same figures once a game hour, each said once in Village news when reached;
##   * the CHRONICLE: the guide's completion and each finished project, written into the village news history under the
##     Village source (demo_notices.gd SOURCE_VILLAGE).
## SKIP AND REOPEN (REQ-SET-168) are the card's Hide guide, the menu row's Skip / Reopen and the window's Show / Hide: they
## only show or hide the card. No path here grants a resource, an unlock or a fact.

const WorldScript := preload("res://demo/guide/guide_world.gd")
const FactsScript := preload("res://demo/guide/guide_facts.gd")
const StepsScript := preload("res://demo/guide/guide_steps.gd")
const StatusScript := preload("res://demo/guide/guide_status.gd")
const CardScript := preload("res://demo/guide/guide_card.gd")
const BeaconScript := preload("res://demo/guide/guide_beacon.gd")
const WindowScript := preload("res://demo/guide/guide_window.gd")
const ProjectsScript := preload("res://demo/guide/projects.gd")
const GoalsScript := preload("res://demo/goals/demo_goals.gd")
const TopicsScript := preload("res://demo/guide/help_topics.gd")
const Text := preload("res://demo/guide/guide_text.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const LabScript := preload("res://demo/ui/demo_lab.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## The card and the projects are looked at this often (real seconds).
const REFRESH_S: float = 0.25
## Show me centres the camera this share of its distance BEYOND the target (along the view, on the ground), so the
## target stands below the screen's middle -- clear of the card, which sits top centre (UI-SET-072).
const SHOW_ME_SHIFT: float = 0.22
const OBJECTIVES_ICON: String = "res://ui/painted/cmd_goals.svg"
## The help query each objective's Help opens on.
const STEP_HELP: Array[String] = ["select resident", "harvest", "kitchen supper", "frost bridge tunnel"]
const MARK_DONE: String = "✓ %d. %s -- %s"
const MARK_NOW: String = "▸ %d. %s -- %s"
const MARK_AHEAD: String = "· %d. %s"

var world: WorldScript = null
var facts: FactsScript = FactsScript.new()
var steps: StepsScript = StepsScript.new()
var projects: ProjectsScript = ProjectsScript.new()
var goals: GoalsScript = GoalsScript.new()
var card: CardScript = CardScript.new()
var beacon: BeaconScript = BeaconScript.new()
var window: WindowScript = WindowScript.new()
## The host's commands a help topic links to (TopicsScript.ACTION_* -> Callable).
var actions: Dictionary = {}

var _status: StatusScript.Status = StatusScript.Status.new()
var _notices: NoticesScript = null
var _jump: JumpScript = null
## The camera rig (demo_camera.gd: `centre_on`, `camera`, `distance`).
var _rig: Node3D = null
var _paused: Callable = Callable()
var _menu: MenuScript = null
var _menu_line: Label = null
var _menu_skip: Button = null
var _refresh_in: float = 0.0
var _drawn: Vector3i = Vector3i(-1, -1, -1)
## The target the marker was last aimed at (kind, id, x, z): re-aimed only when it changes.
var _aimed: Vector4 = Vector4(-1, -1, 0, 0)


func configure(p_world: WorldScript, notices: NoticesScript, jump: JumpScript, rig: Node3D,
		manager: GameManagerScript) -> void:
	"""Read the village through `p_world`; chronicle into `notices`; Show me and Go to through `jump` and the camera
	`rig`; the window's pause and the confirmations' unpaused time from `manager`."""
	name = "DemoGuide"
	world = p_world
	_notices = notices
	_jump = jump
	_rig = rig
	_paused = manager.is_paused if manager != null else Callable()
	window.bind(manager)
	projects.post = _chronicle
	goals.post = func(text: String) -> void: _chronicle(text, NoticesScript.TARGET_NONE, -1)
	goals.guide_done = steps.is_complete
	goals.configure(world, world.record)
	add_child(beacon)
	add_child(card)
	add_child(window)
	_wire_card()
	_wire_window()
	window.practice.stories.water_map = world.water_map


func _wire_card() -> void:
	"""The card's verbs."""
	card.show_me_pressed.connect(show_me)
	card.help_pressed.connect(open_help_for_step)
	card.hide_pressed.connect(skip)
	card.next_pressed.connect(func() -> void: steps.next(); _redraw())
	card.close_pressed.connect(skip)


func _wire_window() -> void:
	"""The window's objectives, projects and help links."""
	window.objective_lines = objective_lines
	window.guide_hidden = func() -> bool: return steps.hidden
	window.toggle_guide = toggle_guide
	window.projects.projects = projects
	window.projects.world = world
	window.projects.facts = facts
	window.projects.places_into = world.places_into
	window.projects.go_to = go_to
	window.goals.book = goals.book
	window.field_guide.guide.bind_pantry(world.pantry)
	window.help.action_requested.connect(run_action)


func attach(menu: MenuScript, lab: LabScript, gate: GateScript, shell: UiShell) -> void:
	"""The game menu's guide row and Help links, the Lab's Practice stories, the gate's modal and region, and the HUD's
	Objectives command."""
	_menu = menu
	if menu != null:
		menu.add_extra(_menu_row(menu.text_width()))
		menu.help.action_requested.connect(func(action: StringName) -> void:
			if menu.close():
				run_action(action))
		menu.visibility_changed.connect(_refresh_menu_row)
	if lab != null:
		lab.add_trigger(Text.PRACTICE_TEXT, "Short practice situations, kept apart from the village", "Village guide",
			func() -> void:
				lab.close()
				open_window(WindowScript.TAB_PRACTICE))
	if gate != null:
		gate.watch_modal(window, window.frame(), window.close, [&"open_objectives"] as Array[StringName])
		gate.set_modal_close(window, window.close_button())
		gate.add_region("guide card", [card.frame()] as Array[Node])
	unlock_objectives(shell)


func _menu_row(width: float) -> VBoxContainer:
	"""The game menu's guide line and its Skip / Reopen, Village guide and Practice stories."""
	var row := VBoxContainer.new()
	_menu_line = GuideUi.line("", FarmUi.SMALL_PX, Palette.UMBER, width)
	row.add_child(_menu_line)
	var verbs: HFlowContainer = GuideUi.row(6)
	row.add_child(verbs)
	_menu_skip = FarmUi.button(Text.SKIP_TEXT, FarmUi.SMALL_PX)
	_menu_skip.pressed.connect(func() -> void: toggle_guide(); _refresh_menu_row())
	verbs.add_child(_menu_skip)
	for pair: Array in [[Text.WINDOW_TEXT, WindowScript.TAB_OBJECTIVES], [Text.PRACTICE_TEXT, WindowScript.TAB_PRACTICE]]:
		var open_it: Button = FarmUi.button(String(pair[0]), FarmUi.SMALL_PX)
		open_it.pressed.connect(func() -> void:
			if _menu.close():
				open_window(int(pair[1])))
		verbs.add_child(open_it)
	_refresh_menu_row()
	return row


func _refresh_menu_row() -> void:
	"""Where the guide stands, and Skip or Reopen."""
	if _menu_line == null:
		return
	var where: String = Text.MENU_DONE
	if steps.is_complete():
		where = Text.MENU_DONE
	elif steps.hidden:
		where = Text.MENU_HIDDEN % [steps.current + 1, StepsScript.STEP_COUNT]
	else:
		where = Text.MENU_STEP % [steps.current + 1, StepsScript.STEP_COUNT, Text.STEP_TITLES[steps.current]]
	_menu_line.text = Text.MENU_ROW % where
	_menu_skip.text = Text.REOPEN_TEXT if steps.hidden else Text.SKIP_TEXT


func unlock_objectives(shell: UiShell) -> bool:
	"""THE OBJECTIVES COMMAND (UI-SET-033, O): drawn locked by the game's shell (its Charter panel is not built), so the
	guide unlocks the button for the village guide -- enabled, its painted icon, its tooltip in the command strip's
	form, and pressed (or O, which the shell presses on an enabled command) it opens or closes the window."""
	if shell == null:
		return false
	var button := shell.control_for(UiShell.ID_OBJECTIVES) as Button
	if button == null:
		return false
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_OBJECTIVES)
	button.disabled = false
	button.icon = load(OBJECTIVES_ICON) as Texture2D
	button.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index],
		Text.OBJECTIVES_TOOLTIP, "")
	button.accessibility_description = Text.OBJECTIVES_TOOLTIP
	button.pressed.connect(window.toggle)
	return true


# --- each frame --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Look at the village (every frame), move the guide on by the unpaused time, redraw a few times a second."""
	facts.observe(world)
	var paused: bool = _paused.is_valid() and bool(_paused.call())
	steps.update(facts, 0.0 if paused else delta)
	if steps.take_completion():
		_chronicle(Text.CHRONICLE_COMPLETE % _choice_words(), NoticesScript.TARGET_NONE, -1)
	goals.update()
	_refresh_in -= delta
	if _refresh_in > 0.0 and Vector3i(steps.revision, facts.revision, int(steps.hidden)) == _drawn:
		return
	_refresh_in = REFRESH_S
	projects.update(world, facts)
	if window.visible and window.tab() == WindowScript.TAB_PROJECTS:
		window.projects.refresh()
	_redraw()


func _redraw() -> void:
	"""The card and the marker as the guide stands now."""
	_drawn = Vector3i(steps.revision, facts.revision, int(steps.hidden))
	card.set_wanted(not steps.hidden)
	if steps.hidden or steps.is_complete():
		beacon.clear()
		if steps.is_complete():
			card.show_complete()
		return
	if steps.phase == StepsScript.PHASE_CONFIRM:
		beacon.clear()
		card.show_confirming(steps.current, Text.STEP_TITLES[steps.current],
			StatusScript.confirm_text(steps.current, world, facts), steps.already)
		return
	StatusScript.resolve_into(steps.current, world, facts, _status)
	card.show_trying(steps.current, _status)
	_aim_beacon()


func _aim_beacon() -> void:
	"""The marker on the status's target, following it (a resident walks)."""
	if _status.target_point == Vector3.INF:
		beacon.clear()
		return
	var kind: int = _status.target_kind
	var id: int = _status.target_id
	var fixed: Vector3 = _status.target_point
	var aimed := Vector4(kind, id, fixed.x, fixed.z)
	if aimed == _aimed and beacon.visible:
		return
	_aimed = aimed
	if kind == NoticesScript.TARGET_RESIDENT:
		beacon.aim(world.resident_point.bind(id), false)
	else:
		beacon.aim(func() -> Vector3: return fixed, true)


# --- the verbs ---------------------------------------------------------------------------------------

func show_me() -> void:
	"""The camera to the marker (the target below the card, SHOW_ME_SHIFT); a bed, tunnel or bridge is also selected and
	its panel brought (as Go to does). A resident is only centred: selecting it is the player's own step."""
	var kind: int = _status.target_kind
	if kind != NoticesScript.TARGET_RESIDENT and kind != NoticesScript.TARGET_NONE and _jump != null \
			and _jump.can_jump(kind, _status.target_id):
		_jump.jump(kind, _status.target_id)
	var at: Vector3 = world.resident_point(_status.target_id) if kind == NoticesScript.TARGET_RESIDENT \
		else _status.target_point
	if at.is_finite() and _rig != null:
		_rig.call(&"centre_on", at + shift_for(_rig.call(&"camera") as Camera3D, float(_rig.call(&"distance"))))


static func shift_for(camera: Camera3D, distance_m: float) -> Vector3:
	"""How far beyond a target, along the view on the ground, to centre the camera so the target stands below the
	screen's middle (zero with no camera, or one looking straight down)."""
	if camera == null:
		return Vector3.ZERO
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	return forward.normalized() * distance_m * SHOW_ME_SHIFT


func skip() -> void:
	"""Hide the card (nothing else changes)."""
	steps.hide_guide()
	_redraw()
	_refresh_menu_row()


func reopen() -> void:
	"""Show the card again where the guide stands."""
	steps.reopen()
	_redraw()
	_refresh_menu_row()


func toggle_guide() -> void:
	"""Skip, or reopen (the card's own state decides, complete or not)."""
	if steps.hidden:
		steps.reopen()
	else:
		steps.hide_guide()
	_redraw()
	window.refresh()


func open_window(tab: int) -> void:
	"""The village guide on `tab`."""
	window.open(tab)


func open_help_for_step() -> void:
	"""The village guide's Help on this objective's topic."""
	window.help.set_query(STEP_HELP[clampi(steps.current, 0, STEP_HELP.size() - 1)])
	window.open(WindowScript.TAB_HELP)


func go_to(kind: int, id: int) -> void:
	"""A project's place: the news's own Go to (closing the window so the place is seen)."""
	if _jump != null and _jump.can_jump(kind, id):
		window.close()
		_jump.jump(kind, id)


func run_action(action: StringName) -> void:
	"""A help topic's command: the guide's own tabs and card here, the rest the host's (closing the window first)."""
	match action:
		TopicsScript.ACTION_FIELD_GUIDE: window.open(WindowScript.TAB_FIELD_GUIDE)
		TopicsScript.ACTION_PROJECTS: window.open(WindowScript.TAB_PROJECTS)
		TopicsScript.ACTION_PRACTICE: window.open(WindowScript.TAB_PRACTICE)
		TopicsScript.ACTION_GUIDE:
			window.close()
			reopen()
		_:
			window.close()
			if actions.has(action) and (actions[action] as Callable).is_valid():
				(actions[action] as Callable).call()


func open_practice() -> void:
	"""The Demo Lab's Practice stories."""
	window.open(WindowScript.TAB_PRACTICE)


# --- words -------------------------------------------------------------------------------------------

func objective_lines() -> PackedStringArray:
	"""The window's four objective lines: done (with what happened), current (with its cause or blocker), ahead."""
	var lines := PackedStringArray()
	var status := StatusScript.Status.new()
	for step: int in StepsScript.STEP_COUNT:
		if StepsScript.is_done(step, facts):
			lines.append(MARK_DONE % [step + 1, Text.STEP_TITLES[step], StatusScript.confirm_text(step, world, facts)])
		elif step == steps.current:
			StatusScript.resolve_into(step, world, facts, status)
			lines.append(MARK_NOW % [step + 1, Text.STEP_TITLES[step], status.state])
		else:
			lines.append(MARK_AHEAD % [step + 1, Text.STEP_TITLES[step]])
	return lines


func _choice_words() -> String:
	"""How the village was readied, for the chronicle ('with a bridge')."""
	if facts.choice < 0:
		return "its own way"
	return "with %s" % Text.CHOICE_TITLES[facts.choice].to_lower()


func _chronicle(text: String, kind: int, id: int) -> void:
	"""A line in the village news history under the Village source."""
	if _notices != null:
		_notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text, "", kind, id)
