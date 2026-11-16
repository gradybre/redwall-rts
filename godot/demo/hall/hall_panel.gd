extends CanvasLayer
## THE HALL'S PANEL (decision 0771): opened by clicking the hall. DEMO UI in the woodland skin (farm_ui.gd's frame,
## type and wood buttons), laid out in the HUD's logical pixels and drawn at its scale.
##
## WHAT, top to bottom: the hall's name at its stage ("Community hall", "Great hall") with The tapestry and x; its
## stage ("Stage 1 of 2"); WHAT IT GIVES -- dining and gathering seats and the feast they serve (seats >= ceil(E / 3)),
## floor sleep for the bedless (and who sleeps there tonight), the common room's comfort target, a hearth's fuel; the
## STAGE 2 section -- REQ-SET-136's package, the unlock (Brendan's ruling), the project's state and its builders, Plan and
## Cancel (Cancel says REQ-SET-126's terms before it is pressed); the BANNERS -- hung, being hung, Hang a banner and
## Cancel; the stores the projects draw on; and the last answer. Every figure is the hall model's (hall_projects.gd)
## or its crew's, read here and never kept.
##
## WHERE: top centre under the HUD's alert zone, as the village news is, down to just above the command strip; its
## body scrolls (demo_scroll.gd). Not modal: the world beside it still takes clicks. Esc or x closes it.
## Rewritten only when something it shows changed, a few times a second at most.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const CrewScript := preload("res://demo/hall/hall_crew.gd")
const TapestryScript := preload("res://demo/hall/tapestry.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const LAYER: int = 1
const MAX_W: float = 560.0
const MAX_H: float = 640.0
const GAP: float = 10.0
const SECTION_PX: int = 16
const REFRESH_S: float = 0.25
## The costs' lines, worded from hall_rules.gd's package by goods_measures.gd (decision 1801): "40 blocks of stone · 20
## logs · a bolt of cloth · 1200 WU. ...", "Each: a log · 12 WU — ...".
const UPGRADE_COST: String = "%s · %s · %s · %d WU. Warmer: a hearth here burns fuel ×0.75 and the " \
	+ "comfort target rises 1000. No new floor or beds; it is the hall's one upgrade (GDD §5.9)."
const BANNER_COST: String = "Each: %s · %d WU — a decoration, +250 comfort, at most +1000 (four banners)."
const CANCEL_BEFORE: String = "Cancel: all the materials delivered so far come back to the stores (no work " \
	+ "begun)"
const CANCEL_AFTER: String = "Cancel: 80% of what was delivered comes back, rounded down — work has begun (REQ-SET-126)"

var _projects: ProjectsScript = null
var _crew: CrewScript = null
var _stores: StoresScript = null
var _tapestry: TapestryScript = null
## `() -> String`: who sleeps on the hall's floor tonight ("" nobody).
var _bedless: Callable = Callable()
## `() -> String`: the hall hearth's state in words ("" none bound), and `() -> int`, a stamp that changes when it may
## have (the winter's: decision 0571; bound at the batch 7 integration, decision 0902).
var _hearth: Callable = Callable()
var _hearth_stamp: Callable = Callable()
var _actions: Dictionary = {}
var _frame: PanelContainer = null
var _title: Label = null
var _stage: Label = null
var _gives: Label = null
var _upgrade: Label = null
var _banners: Label = null
var _stock: Label = null
var _message: Label = null
var _buttons: Dictionary = {}
var _drawn: PackedInt64Array = PackedInt64Array([-1, -1, -1, -1, -1, -1])
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(projects: ProjectsScript, crew: CrewScript, stores: StoresScript, tapestry: TapestryScript) -> void:
	"""Show these projects, their crew, the stores they draw on and the tapestry's size."""
	_projects = projects
	_crew = crew
	_stores = stores
	_tapestry = tapestry
	build()


func set_actions(actions: Dictionary) -> void:
	"""What the buttons do: Callables under &"plan_upgrade", &"cancel_upgrade", &"plan_banner", &"cancel_banner" (each
	`() -> String`, the answer shown) and &"tapestry" (`() -> void`)."""
	_actions = actions


func set_bedless(names: Callable) -> void:
	"""`names() -> String`: who sleeps on the hall's floor tonight ("" nobody)."""
	_bedless = names


func set_hearth(words: Callable, stamp: Callable) -> void:
	"""`words() -> String`: the hall's hearth now, in the winter's words (fuelled and demanded, out of fuel, not needed
	today...); `stamp() -> int` changes whenever it may have."""
	_hearth = words
	_hearth_stamp = stamp


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden window (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "HallPanel"
	_frame = FarmUi.frame()
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	_build_header(column)
	var scroll := DemoScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 6)
	scroll.add_child(body)
	_build_body(body)


func _build_header(column: VBoxContainer) -> void:
	"""The hall's name, The tapestry and the close."""
	var row := HBoxContainer.new()
	column.add_child(row)
	_title = FarmUi.label("", FarmUi.TITLE_PX, Palette.UMBER, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	row.add_child(_button(&"tapestry", "The tapestry", "The village's history, woven in the hall"))
	var close: Button = FarmUi.button("×", FarmUi.BODY_PX + 2)
	close.name = "Close"
	close.tooltip_text = "Close the hall (Esc)"
	close.pressed.connect(close_window)
	row.add_child(close)
	_stage = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_stage)


func _build_body(body: VBoxContainer) -> void:
	"""What the hall gives, the upgrade, the banners, the stores and the answer line."""
	body.add_child(FarmUi.label("What the hall gives", SECTION_PX, Palette.UMBER, true))
	_gives = _line(body, Palette.INK)
	body.add_child(FarmUi.label("Stage 2: the great hall", SECTION_PX, Palette.UMBER, true))
	body.add_child(FarmUi.label(upgrade_cost_text(), FarmUi.SMALL_PX, Palette.UMBER))
	_upgrade = _line(body, Palette.INK)
	_add_row(body, [_button(&"plan_upgrade", "Plan the upgrade", ""), _button(&"cancel_upgrade", "Cancel it", "")])
	body.add_child(FarmUi.label("Banners", SECTION_PX, Palette.UMBER, true))
	body.add_child(FarmUi.label(banner_cost_text(), FarmUi.SMALL_PX, Palette.UMBER))
	_banners = _line(body, Palette.INK)
	_add_row(body, [_button(&"plan_banner", "Hang a banner", ""), _button(&"cancel_banner", "Cancel a banner", "")])
	_stock = _line(body, Palette.UMBER)
	_message = _line(body, Palette.LEAF)


func _line(body: VBoxContainer, colour: Color) -> Label:
	"""A wrapping line of the body."""
	var line: Label = FarmUi.label("", FarmUi.BODY_PX, colour)
	body.add_child(line)
	return line


func _add_row(body: VBoxContainer, buttons: Array) -> void:
	"""A row of buttons."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	for each: Button in buttons:
		row.add_child(each)
	body.add_child(row)


func _button(action: StringName, words: String, tip: String) -> Button:
	"""A wood button that runs `action` (see `set_actions`)."""
	var made: Button = FarmUi.button(words)
	made.name = String(action)
	made.tooltip_text = tip
	made.pressed.connect(press.bind(action))
	_buttons[action] = made
	return made


# --- opening, pressing ----------------------------------------------------------------------------------------------

func open() -> void:
	"""Show the panel, current."""
	build()
	_frame.visible = true
	_drawn.fill(-1)
	refresh()
	_place.call_deferred()


func close_window() -> void:
	"""Hide the panel."""
	if _frame != null:
		_frame.visible = false


func is_open() -> bool:
	"""Whether the panel is shown."""
	return _frame != null and _frame.visible


func press(action: StringName) -> String:
	"""Press a button (a click, or a check): its action's answer, shown on the answer line."""
	var act: Callable = _actions.get(action, Callable())
	if not act.is_valid():
		return ""
	var said: Variant = act.call()
	var words: String = said if said is String else ""
	if not words.is_empty():
		_message.text = words
	_drawn.fill(-1)
	refresh()
	return words


func _input(event: InputEvent) -> void:
	"""Esc closes the open panel before any world handler reads it (the top of UI §5's dismissal ladder)."""
	if is_open() and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_window()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	"""Refresh a few times a second while open."""
	if not is_open():
		return
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


# --- drawing --------------------------------------------------------------------------------------------------------

func refresh() -> bool:
	"""Rewrite what changed since the last drawing. Whether anything was rewritten."""
	if _projects == null or _frame == null:
		return false
	if not _stamp_changed():
		return false
	_title.text = Rules.STAGE_NAMES[_projects.tier]
	_stage.text = "Stage %d of %d" % [_projects.tier, Rules.STAGE_COUNT]
	_gives.text = gives_text(_projects, String(_bedless.call()) if _bedless.is_valid() else "",
		String(_hearth.call()) if _hearth.is_valid() else "")
	_upgrade.text = upgrade_text(_projects, _crew)
	_banners.text = banner_text(_projects, _crew)
	_stock.text = stock_text(_projects, _stores)
	(_buttons[&"tapestry"] as Button).text = "The tapestry (%d)" % (_tapestry.count() if _tapestry != null else 0)
	_draw_buttons()
	return true


func _stamp_changed() -> bool:
	"""Whether anything the panel shows changed since it was drawn: each figure compared with its kept stamp, which is
	updated in place (no array made)."""
	var changed: bool = _restamp(0, _projects.revision)
	changed = _restamp(1, _crew.revision) or changed
	changed = _restamp(2, _stores.revision if _stores != null else 0) or changed
	changed = _restamp(3, _tapestry.revision if _tapestry != null else 0) or changed
	changed = _restamp(5, int(_hearth_stamp.call()) if _hearth_stamp.is_valid() else 0) or changed
	return _restamp(4, _bedless_hash()) or changed


func _restamp(k: int, value: int) -> bool:
	"""Keep `value` as stamp `k`; whether it differed."""
	if _drawn[k] == value:
		return false
	_drawn[k] = value
	return true


func _bedless_hash() -> int:
	"""A cheap stamp of tonight's floor sleepers (their names' hash), so a change redraws."""
	return String(_bedless.call()).hash() if _bedless.is_valid() else 0


func _draw_buttons() -> void:
	"""Each button enabled when its action can be taken, else dimmed with why."""
	var why: String = _projects.upgrade_refusal()
	FarmUi.set_enabled(_buttons[&"plan_upgrade"], why.is_empty(), why)
	var upgrade_on: bool = _projects.is_active(Rules.PROJECT_UPGRADE)
	FarmUi.set_enabled(_buttons[&"cancel_upgrade"], upgrade_on, "No upgrade is under way")
	if upgrade_on:
		(_buttons[&"cancel_upgrade"] as Button).tooltip_text = cancel_terms(_projects, Rules.PROJECT_UPGRADE)
	FarmUi.set_enabled(_buttons[&"plan_banner"], _projects.free_banner() >= 0, ProjectsScript.REFUSE_BANNERS_FULL)
	var last: int = _projects.last_planned_banner()
	FarmUi.set_enabled(_buttons[&"cancel_banner"], last >= 0, "No banner is waiting to be hung")
	if last >= 0:
		(_buttons[&"cancel_banner"] as Button).tooltip_text = cancel_terms(_projects, last)


# --- the words (static, for the checks) -----------------------------------------------------------------------------

func gives_line() -> String:
	"""What the panel's "what it gives" section says now (checks)."""
	return _gives.text if _gives != null else ""


static func gives_text(projects: ProjectsScript, bedless: String, hearth: String = "") -> String:
	"""What the hall gives at its stage, from the adopted rules (see hall_rules.gd WHAT THE HALL GIVES), and its hearth
	now (`hearth`, the winter's words; "" none)."""
	var seats: int = Rules.SEATS
	var lines := PackedStringArray()
	lines.append("Dining and gathering: %d seats for meals, songs and feasts; a feast seats up to %d residents (a seat "
		% [seats, Rules.gathering_capacity(seats)] + "for every three)")
	var tonight: String = " Without a bed now: %s." % bedless if not bedless.is_empty() else ""
	lines.append("Sleeping: whoever has no bed sleeps on its floor.%s" % tonight)
	lines.append("Comfort: the common room's target is %d" % projects.comfort_target())
	var now: String = "its hearth is %s; " % hearth if not hearth.is_empty() else ""
	lines.append("Heat: %sa hearth here burns fuel ×%s" % [now, permille_text(projects.fuel_permille())])
	return "\n".join(lines)


static func permille_text(permille: int) -> String:
	"""A per-mille factor as a multiplier: 750 -> "0.75", 1000 -> "1.00"."""
	@warning_ignore("integer_division")
	var whole: int = permille / 1000
	@warning_ignore("integer_division")
	var hundredths: int = (permille % 1000) / 10
	return "%d.%02d" % [whole, hundredths]


static func upgrade_text(projects: ProjectsScript, crew: CrewScript) -> String:
	"""The upgrade's state in words: raised, locked, ready, being carried in, being built."""
	var p: int = Rules.PROJECT_UPGRADE
	if projects.tier >= Rules.TIER_GREAT:
		return "Raised: the great hall. It has had its one upgrade — there is no stage 3."
	match projects.phase[p]:
		ProjectsScript.PHASE_DELIVERING:
			return "Carrying in: %s.%s" % [delivery_text(projects, p), _builders(crew, p)]
		ProjectsScript.PHASE_BUILDING:
			return "Building: %d of %d WU.%s" % [projects.work_done_wu(p), Rules.UPGRADE_WU, _builders(crew, p)]
	if not projects.unlocked:
		return "Opens %s." % Rules.UNLOCK_WORDS[Rules.UNLOCK_CONDITION]
	return "Ready to plan. Residents selected when you plan it go at once; otherwise the work board sends builders."


static func upgrade_cost_text() -> String:
	"""The upgrade's package (REQ-SET-136) in its measures: "40 blocks of stone · 20 logs · a bolt of cloth · 1200 WU.
	…"."""
	return UPGRADE_COST % [Measures.exact(&"stone", Rules.UPGRADE_MILLI[Rules.MAT_STONE]),
		Measures.exact(&"wood", Rules.UPGRADE_MILLI[Rules.MAT_WOOD]),
		Measures.exact(&"cloth", Rules.UPGRADE_MILLI[Rules.MAT_CLOTH]), Rules.UPGRADE_WU]


static func package_words() -> String:
	"""The upgrade's package in a sentence, for the news and the tapestry: "40 blocks of stone, 20 logs and a bolt of
	cloth"."""
	return "%s, %s and %s" % [Measures.exact(&"stone", Rules.UPGRADE_MILLI[Rules.MAT_STONE]),
		Measures.exact(&"wood", Rules.UPGRADE_MILLI[Rules.MAT_WOOD]),
		Measures.exact(&"cloth", Rules.UPGRADE_MILLI[Rules.MAT_CLOTH])]


static func banner_cost_text() -> String:
	"""A banner's cost: "Each: a log · 12 WU — …"."""
	return BANNER_COST % [Measures.exact(&"wood", Rules.BANNER_MILLI[Rules.MAT_WOOD]), Rules.BANNER_WU]


static func delivery_text(projects: ProjectsScript, project: int) -> String:
	"""What of each material is at the hall, against its need: "wood 12 of 20 logs · stone 4 of 40 blocks"
	(goods_measures.gd have_need; decision 1801)."""
	var parts := PackedStringArray()
	for mat: int in Rules.MAT_COUNT:
		var need: int = Rules.need_milli(project, mat)
		if need > 0:
			parts.append("%s %s" % [Rules.MAT_NAMES[mat], Measures.have_need(StringName(Rules.MAT_NAMES[mat]),
				projects.delivered[projects.cell(project, mat)], need)])
	return " · ".join(parts)


static func _builders(crew: CrewScript, project: int) -> String:
	"""" Builders: A, B." -- or that it waits for some."""
	var names: String = crew.names_on(project) if crew != null else ""
	return " Builders: %s." % names if not names.is_empty() else " Waiting for builders (the work board sends them)."


static func banner_text(projects: ProjectsScript, crew: CrewScript) -> String:
	"""The banners: how many hung, the comfort they add, and the one being hung."""
	var hung: int = projects.banners_hung()
	var line: String = "%d of %d hung (comfort +%d)" % [hung, Rules.BANNERS_MAX,
		mini(hung * Rules.DECORATION_COMFORT, Rules.DECORATION_CAP)]
	var p: int = projects.last_planned_banner()
	if p >= 0:
		line += " · banner %d: %s, %d%%.%s" % [p - Rules.PROJECT_BANNER_FIRST + 1,
			ProjectsScript.PHASE_WORDS[projects.phase[p]], projects.percent(p), _builders(crew, p)]
	return line


static func stock_text(projects: ProjectsScript, stores: StoresScript) -> String:
	"""What the projects draw on: the stores' wood and stone, and the village's cloth: "Stores by the stockpile: 6 logs ·
	3 blocks of stone · 3 bolts of cloth"."""
	var wood: int = stores.wood_milli_u if stores != null else 0
	var stone: int = stores.stone_milli_u if stores != null else 0
	return "Stores by the stockpile: %s · %s · %s" % [Measures.amount(&"wood", wood), Measures.amount(&"stone", stone),
		Measures.amount(&"cloth", projects.cloth_milli)]


static func cancel_terms(projects: ProjectsScript, project: int) -> String:
	"""REQ-SET-126's terms for cancelling `project` now, before it is pressed."""
	return CANCEL_AFTER if projects.work_usec[project] > 0 else CANCEL_BEFORE


# --- placing --------------------------------------------------------------------------------------------------------

func _place() -> void:
	"""Top centre under the alert zone, as wide as MAX_W allows, down to just above the command strip."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var width: float = minf(MAX_W, _geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(_geometry.alerts.get_center().x - width / 2.0, GAP, _geometry.logical_width - GAP - width)
	var top: float = _geometry.alerts.end.y + GAP
	var height: float = minf(MAX_H, _geometry.commands.position.y - GAP - top)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = Vector2(x, top) * _geometry.scale
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func message_text() -> String:
	"""The answer line (checks)."""
	return _message.text if _message != null else ""


func button(action: StringName) -> Button:
	"""The button for `action` (checks)."""
	return _buttons.get(action, null) as Button


func title_text() -> String:
	"""The title (checks)."""
	return _title.text if _title != null else ""
