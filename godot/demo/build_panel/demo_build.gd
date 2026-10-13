extends Node
## THE ONE BUILD PANEL AND THE LEVEL BAR IN THE DEMO (DEC-061 Q1; docs/ui_ux_controls.md UI-BUILD-001; decisions 1871
## and 1912). The panel and the bar are game UI (scripts/ui/build_panel.gd, level_bar.gd); this mounts them over the
## village and maps them onto what the demo has.
##
## KEYS (read through demo_command.gd's build hooks: `takes_before_gui`, then `handle_input`):
##   B                  open or close the panel (closing with pending changes asks Keep / Discard).
##   PageUp / PageDown  the level bar, everywhere (level_up / level_down): Surface ... Level 4. Read before the HUD;
##                      never behind a modal.
##   in the panel:      Esc one layer (the stroke, a question, the ledger, the panel); Ctrl+Tab / Ctrl+Shift+Tab the
##                      tabs; Ctrl+Z / Cmd+Z undo; Ctrl+Shift+Z, Ctrl+Y / Cmd+Shift+Z redo; with a room type armed,
##                      left drag paints with the chosen tool, right click cancels the stroke, the arrows move the cell
##                      cursor RELATIVE TO THE CAMERA (Up is the way the camera looks, snapped to the grid: P-B10 (b))
##                      and Enter sets the first corner, Enter again the second.
##
## THE LEVELS (decision 1912; Brendan's ruling on decision 1911 P-C6 (a)). WHILE THE PANEL IS OPEN the bar decides:
## Levels 1-4 are the settlement's ACTUAL underground levels, 5 m apart (demo_build_world.gd draws the World cut at
## the level's floor; the U view draws only that, so the legacy warren is hidden), and painting is armed there;
## Surface and Overview are the surface view with painting off. U pressed meanwhile is read as a choice: off goes to
## the Surface, on goes to Level 1. WITH THE PANEL CLOSED the bar follows the legacy U view as before (decision 1871:
## Level 1 / 2 the legacy warren's; Levels 3 and 4 show nothing). A level with no way in yet is marked "!" on the bar
## and still painted: each cell then says "No way in" on its ghost (BUILD-REQ-013 per cell).
##
## THE CARDS. A room type -- Passage among them -- arms painting on levels 1-4. The old Passage / Burrow home / Root
## cellar tool cards are gone (Brendan's ruling on decision 1911 P-C2 (c)): THE DEMO HAS NO PLAYABLE DIGGING until
## slice C3 makes painted rooms diggable, and the panel says so when it opens. While the panel shows, the HUD's command
## strip (UI-SET-026) and its detail (UI-SET-036), the demo's right column, its map-layer picker and its news strip are
## hidden (their place is the panel's), and given back on close. Opening, painting, Undo, Redo and Discard all touch
## no store, reservation or job. Confirm all is held back while any cell has no way in, which on the actual
## underground is every cell until slice D's entrance (decision 1911 §2.1); the route behind it (demo_build_orders.gd)
## deducts nothing.

const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Paint := preload("res://demo/build_panel/demo_build_paint.gd")
const Orders := preload("res://demo/build_panel/demo_build_orders.gd")
const Ground := preload("res://demo/build_panel/demo_build_ground.gd")
const BuildWorld := preload("res://demo/build_panel/demo_build_world.gd")
const TunnelControl := preload("res://demo/tunnel/tunnel_control.gd")
const ThemeResource: Theme = preload("res://ui/theme/woodland_theme.tres")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")
## The paint label keeps this far inside the window's edges (UI §1.2's safe inset).
const SAFE_INSET: float = 16.0

## Over the demo's panels (layer 0), with the HUD's.
const CANVAS_LAYER: int = 1
const LABEL_OFFSET: Vector2 = Vector2(18.0, 18.0)
const LABEL_PX: int = 16
## The paint label keeps this far above the panel.
const LABEL_GAP: float = 8.0
const ARMED_HINT: String = "Paint %s: drag on the floor, or Enter to set a corner"
const ORDERED: String = "Confirm all: %d ordered, %d kept back"
## Decision 1912 (P-C2 (c)): the panel plans; digging what it plans comes later, and it says so.
const OPENED: String = "Build on %s: plan rooms by painting them; digging painted rooms comes in a later update"
const CLOSED_KEPT: String = "Build panel closed; its pending changes are kept"
## The demo's Build command (UI-SET-027, P-B3 as Brendan approved on 2026-10-12): what it does here.
const BUILD_COMMAND: String = "Open the build panel: plan rooms underground (digging them comes in a later update)"
const ARROW_KEYS: Array[int] = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]

var panel: BuildPanel = null
var bar: LevelBar = null
var batch: Batch = null
var catalog: BuildCatalog = null
var paint: Paint = null
var orders: Orders = null
var ground: Ground = null
var world: BuildWorld = null
var _layer: CanvasLayer = null
var _label_box: PanelContainer = null
var _label: Label = null
var _tunnels: TunnelControl = null
var _shell: UiShell = null
var _camera: Camera3D = null
var _blocked: Callable = Callable()
var _say: Callable = Callable()
var _hide: Array[Node] = []
var _hidden_was: PackedByteArray = PackedByteArray()
var _holding: bool = false
var _special: int = -1
var _special_on: bool = false
## While building: the level the view was last set to (-1: none) and whether the U view was left on.
var _applied_level: int = -1
var _applied_on: bool = false
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _minimap_was: bool = true
var _pointer: Vector2 = Vector2.INF
var _seen_label: int = -1
## Why the panel could not be set up ("": it was): painting stays disarmed (decision 1871, review M4).
var _setup_refusal: StringName = &""
## Why the actual World's level could not be shown ("": it was, or was not asked for).
var world_refusal: StringName = &""


func configure(tunnels: TunnelControl, shell: UiShell, camera: Camera3D, blocked: Callable, say: Callable,
		hide: Array[Node], session: Object) -> void:
	"""Mount over this village: its U view, the HUD shell, the camera that paints, the modal test (`blocked() ->
	bool`), the notice line (`say(text)`), the demo surfaces the panel replaces while open, and the settlement's
	underground session (null: none composed, every order refused)."""
	name = "DemoBuild"
	_tunnels = tunnels
	_shell = shell
	_camera = camera
	_blocked = blocked
	_say = say
	_hide = hide.duplicate()
	catalog = BuildCatalog.new()
	orders = Orders.new()
	orders.bind_session(session, camera)
	batch = Batch.new()
	take_setup(batch.configure(catalog, orders.cell_bounds(), orders.cell_capacity()))
	_configure_ground()
	_configure_world(session)
	_build_layer()
	unlock_build_command()
	place()


func _configure_ground() -> void:
	"""Each level's dug height (the ledger, DEC-054) and floor (the ghosts), and the ground reader bound to the batch
	(only over a composed underground: with none, the batch judges shapes alone and Confirm all says why)."""
	ground = Ground.new()
	ground.configure(orders.datum_u(), orders.cell_bounds())
	ground.bind(orders.terrain_owner(), orders.excavation_sites(), orders.space_owner())
	var floors: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
	for level: int in range(1, LevelBar.LEVEL_DEEPEST + 1):
		catalog.set_level_clear_height(level, orders.dug_height_of(level))
		floors[level] = orders.floor_of(level)
		ground.set_level(level, floors[level], orders.dug_height_of(level))
	if ground.bound():
		batch.bind_ground(ground.ground, ground.revision)
	paint = Paint.new()
	add_child(paint)
	take_setup(paint.configure(batch, _camera, Vector2i(orders.datum_u().x, orders.datum_u().z), orders.cell_bounds(),
		floors))


func _configure_world(session: Object) -> void:
	"""The actual World's level view, built when first shown."""
	world = BuildWorld.new()
	world.configure(session)
	add_child(world)


func unlock_build_command() -> bool:
	"""P-B3, in the demo only: the HUD's Build command (UI-SET-027) is enabled and opens or closes the panel, as B
	does, wearing its own icon, not the lock (decision 1891). The settlement game's shell keeps it locked (ruling 4);
	the shell only lends the icon (`command_icon`). False without a shell."""
	var button: Button = _shell.control_for(UiShell.ID_BUILD) as Button if _shell != null else null
	if button == null:
		return false
	button.disabled = false
	# The shell gave it the lock at creation (UI §2.2: an unwired control wears the lock); enabled, it wears its own
	# icon (decision 1891, correcting 1871 E21).
	button.icon = _shell.command_icon(UiShell.ID_BUILD)
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_BUILD)
	button.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index],
		BUILD_COMMAND, "")
	button.accessibility_description = BUILD_COMMAND
	if not button.pressed.is_connected(toggle_panel):
		button.pressed.connect(toggle_panel)
	return true


func take_setup(code: StringName) -> void:
	"""A setup step's answer: a refusal is kept (painting stays disarmed) and shown as a HUD refusal."""
	if code == &"" or _setup_refusal != &"":
		return
	_setup_refusal = code
	UIManager.push_refusal(code)


func setup_refusal() -> StringName:
	"""Why the panel could not be set up ("" when it was)."""
	return _setup_refusal


func _build_layer() -> void:
	"""The canvas layer, the level bar (always shown), the panel and the size label."""
	_layer = CanvasLayer.new()
	_layer.name = "BuildLayer"
	_layer.layer = CANVAS_LAYER
	add_child(_layer)
	bar = LevelBar.new()
	bar.build()
	for level: int in [3, 4]:
		bar.set_reachable(level, false)
	bar.level_chosen.connect(_on_level_chosen)
	_layer.add_child(bar)
	panel = BuildPanel.new()
	panel.configure(batch, catalog, _stock)
	panel.card_chosen.connect(_on_card_chosen)
	panel.confirm_requested.connect(confirm_all)
	panel.closed.connect(_on_closed)
	_layer.add_child(panel)
	_build_label()


func _build_label() -> void:
	"""UI-BUILD-010's size label beside the pointer: a small framed line, never taking the mouse."""
	_label_box = PanelContainer.new()
	_label_box.name = "PaintLabel"
	_label_box.theme = ThemeResource
	_label_box.theme_type_variation = &"WoodlandPanel"
	_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_box.visible = false
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", LABEL_PX)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_box.add_child(_label)
	_layer.add_child(_label_box)


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(place)
	place()


func place() -> void:
	"""The bar and the panel at the HUD's layout for the window and the interface scale (demo_ui_scale.gd)."""
	if bar == null:
		return
	var size_px: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	if not _layout.compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), DemoUiScale.percent, false, _geometry):
		return
	_minimap_was = minimap_shown()
	bar.place(_geometry, _minimap_was)
	panel.place(_geometry)
	_label_box.scale = Vector2(_geometry.scale, _geometry.scale)


func minimap_shown() -> bool:
	"""Whether the HUD's minimap frame shows (the bar sits above it, or above its restore control)."""
	var frame: Control = _shell.control_for(UiShell.ID_MINIMAP_FRAME) if _shell != null else null
	return frame == null or frame.is_visible_in_tree()


func _stock(good: StringName) -> int:
	"""What the settlement's stores hold, for the ledger (read only; nothing is reserved)."""
	return EconomySystem.stock_milli(good)


# --- opening and closing -------------------------------------------------------------------------------------------

func is_open() -> bool:
	"""Whether the panel is open."""
	return panel.is_open()


func open_panel() -> bool:
	"""Open the panel on the level shown (refused behind a modal or the stall banner). True when it is open."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if not panel.is_open():
		_mark_reachable()
		panel.open_on(bar.shown_level(), bar.is_reachable(bar.shown_level()))
		_hold_hud()
		_apply_build_view()
		if is_inside_tree():
			get_viewport().gui_release_focus()
		_say.call(OPENED % LevelBar.level_name(bar.shown_level()))
	return true


func toggle_panel() -> bool:
	"""B or the Build command: open, or ask to close. True when the panel is open afterwards."""
	if panel.is_open():
		panel.request_close()
		return panel.is_open()
	return open_panel()


func _on_closed(kept: bool) -> void:
	"""The panel closed: the HUD's surfaces back, the actual World's level put away (the U view shows its own level
	again), the ghosts' stroke and label hidden."""
	_release_hud()
	_leave_build_view()
	_label_box.visible = false
	paint.refresh(-1, false)
	if kept and batch.pending_count() > 0:
		_say.call(CLOSED_KEPT)


func _mark_reachable() -> void:
	"""The bar's "no way in yet" marks while building: a level has a way in only where something is dug at all
	(no excavation Site exists anywhere: none has; every cell's ghost judges it exactly)."""
	var sites: Object = orders.excavation_sites()
	var any: bool = sites != null and int(sites.get(&"_count")) > 0
	for level: int in range(1, LevelBar.LEVEL_DEEPEST + 1):
		bar.set_reachable(level, any)


# --- per frame -----------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Follow the view (U), the minimap; hold the HUD; redraw the ghosts and label. Integer compares a frame;
	allocation only when something changed."""
	follow_view()
	if minimap_shown() != _minimap_was:
		place()
	var open: bool = panel.is_open()
	if open:
		_hold_hud()
	elif _holding:
		_release_hud()
	paint.refresh(bar.shown_level() if open else -1, open and armed_type() >= 0)
	_sync_label(open)


func follow_view() -> void:
	"""While building, the bar decides and the view follows (U read as a choice); else the bar follows the legacy
	U view (decision 1871)."""
	if panel.is_open():
		_follow_build_view()
		return
	var shown: int = view_level()
	if shown != bar.shown_level():
		bar.set_level(shown)


func _follow_build_view() -> void:
	"""U pressed while building: off goes to the Surface, on goes to Level 1; then the view is kept as the bar says."""
	if _applied_level >= 0 and _tunnels.view.on != _applied_on:
		bar.set_level(LevelBar.LEVEL_SURFACE if not _tunnels.view.on else 1)
		_applied_level = -1
	if bar.shown_level() != panel.building_level():
		batch.cancel_stroke()
		panel.set_level(bar.shown_level(), bar.is_reachable(bar.shown_level()))
	_apply_build_view()


func _apply_build_view() -> void:
	"""Show what the bar's level is while building: an underground level's actual World (the U view on, drawing only
	it), or the surface view. Writes only when the level changed."""
	var level: int = bar.shown_level()
	if level == _applied_level:
		return
	_applied_level = level
	_special = -1
	var underground: bool = Paint.paintable(level)
	if _tunnels.view.on != underground:
		_tunnels.toggle_view()
	_applied_on = _tunnels.view.on
	if not underground:
		world.hide_view()
		return
	world_refusal = world.show_level(level)
	_tunnels.view.set_override_mask(BuildWorld.SHOWN_MASK if world_refusal == &"" else 0)


func _leave_build_view() -> void:
	"""Building ended: the World's level hidden and the U view's own level back (the bar then follows it)."""
	world.hide_view()
	_tunnels.view.set_override_mask(-1)
	_applied_level = -1


func view_level() -> int:
	"""The level shown with the panel closed, in the bar's terms: a level 3/4 or Overview choice while the view is as
	it left it, else the U view's level, or the surface with it off."""
	var on: bool = _tunnels.view.on
	if _special >= 0 and on == _special_on:
		return _special
	if _special >= 0:
		_set_special(-1)
	return _tunnels.view.level if on else LevelBar.LEVEL_SURFACE


func _hold_hud() -> void:
	"""Hide the surfaces the panel replaces (recorded once per opening, re-hidden each frame: their owners may show
	them again)."""
	if not _holding:
		_holding = true
		_hidden_was.resize(_hide.size())
		for k: int in _hide.size():
			_hidden_was[k] = 1 if is_instance_valid(_hide[k]) and bool(_hide[k].get(&"visible")) else 0
	for node: Node in _hide:
		if is_instance_valid(node):
			node.set(&"visible", false)


func _release_hud() -> void:
	"""Give the hidden surfaces back as they were."""
	if not _holding:
		return
	_holding = false
	for k: int in mini(_hide.size(), _hidden_was.size()):
		if is_instance_valid(_hide[k]):
			_hide[k].set(&"visible", _hidden_was[k] == 1)


func _sync_label(open: bool) -> void:
	"""The paint label beside the pointer (or the cursor cell): the stroke's size and validity, or how to begin."""
	var type: int = armed_type() if open else -1
	_label_box.visible = type >= 0
	if type < 0:
		return
	if batch.stroke_revision != _seen_label:
		_seen_label = batch.stroke_revision
		_label.text = batch.stroke_line().replace("; ", "\n") if batch.stroke_active() \
			else ARMED_HINT % BuildCatalog.type_name(type)
		_label_box.accessibility_name = batch.stroke_line() if batch.stroke_active() else _label.text
		_label_box.reset_size()
	var at: Vector2 = _pointer if _pointer.is_finite() else paint.screen_of(paint.cursor(), bar.shown_level())
	if at.is_finite():
		var view: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
		_label_box.position = label_position(at + LABEL_OFFSET, _label_box.size * _label_box.scale, view,
			panel.screen_rect())


static func label_position(wanted: Vector2, drawn: Vector2, view: Vector2, avoid: Rect2) -> Vector2:
	"""Where the paint label stands: at `wanted`, kept 16 px inside the window, and lifted above the panel (`avoid`)
	rather than drawn over it."""
	var inset: Vector2 = Vector2(SAFE_INSET, SAFE_INSET)
	var at: Vector2 = wanted.clamp(inset, (view - drawn - inset).max(inset))
	if Rect2(at, drawn).intersects(avoid):
		at.y = maxf(avoid.position.y - drawn.y - LABEL_GAP, SAFE_INSET)
	return at


func label_text() -> String:
	"""What the paint label says (checks)."""
	return _label.text if _label_box.visible else ""


# --- the levels ----------------------------------------------------------------------------------------------------

func step_level(by: int) -> bool:
	"""PageDown (+1) or PageUp (-1): the bar's next level, or the canonical words at an end."""
	if bar.step(by):
		return true
	_say.call(Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.no_level_above() if by < 0 else Validity.no_level_below()))
	return false


func _on_level_chosen(level: int) -> void:
	"""The bar's choice: while building, the view follows it (`_apply_build_view`); else it is mapped onto the legacy
	U view as decision 1871 did (Levels 1/2 its levels, 3/4 nothing, Overview the surface)."""
	if panel.is_open():
		_follow_build_view()
		return
	_set_special(-1)
	match level:
		LevelBar.LEVEL_SURFACE, LevelBar.LEVEL_OVERVIEW:
			if _tunnels.view.on:
				_tunnels.toggle_view()
		_:
			if not _tunnels.view.on:
				_tunnels.toggle_view()
			if level <= 2:
				_tunnels.show_level(level)
	if (level == 3 or level == 4) and _tunnels.view.on:
		_set_special(level)
	elif level == LevelBar.LEVEL_OVERVIEW and not _tunnels.view.on:
		_set_special(level)
	follow_view()


func _set_special(level: int) -> void:
	"""Hold a level the legacy view cannot name itself (3, 4 or Overview) until the view changes under it."""
	_special = level
	_special_on = _tunnels.view.on
	_tunnels.view.set_unreached(level == 3 or level == 4)


# --- painting ------------------------------------------------------------------------------------------------------

func armed_type() -> int:
	"""The room type a stroke paints now, or -1: the panel open with a type chosen, on an underground level. (With no
	underground composed in the run the World cannot be drawn, `world_refusal` says why, and painting still works:
	Confirm all then says nothing can be ordered.)"""
	if _setup_refusal != &"" or not panel.is_open():
		return -1
	return panel.paint_type() if Paint.paintable(bar.shown_level()) else -1


func _begin_at(cell: Vector2i) -> bool:
	"""Start a stroke of the armed type at `cell` on the level shown."""
	var type: int = armed_type()
	if type < 0:
		return false
	paint.set_cursor(cell, bar.shown_level(), type)
	return batch.begin_stroke(type, bar.shown_level(), cell)


func _finish() -> void:
	"""End the stroke: it joins the batch, or is dropped saying why."""
	var kind: int = batch.finish_stroke()
	if kind == Validity.KIND_NOT_POSSIBLE:
		_say.call(batch.last_dropped())
	elif kind >= 0:
		_say.call(panel.confirm_blocked() if not panel.confirm_blocked().is_empty() else Validity.line(kind, ""))


func confirm_all() -> void:
	"""Confirm all: every valid operation through the planner's route, in order; nothing is deducted."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return
	var result: PackedInt32Array = batch.confirm_all(orders.submit)
	var first: int = batch.first_invalid()
	if first < 0:
		first = batch.first_refused()
	var words: String = ORDERED % [result[0], result[1]]
	if first >= 0:
		words += " -- %s: %s" % [BuildCatalog.type_name(batch.operation_type(first)), batch.operation_reason(first)]
	panel.refresh(true)
	_say.call(words)


# --- input ---------------------------------------------------------------------------------------------------------

func takes_before_gui(event: InputEvent) -> bool:
	"""Before the HUD: the level keys (everywhere), and a stroke's motion and release (so a drag ending over the HUD
	still ends here) and the keyboard's Enter in the world. True when taken."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if _level_key(event):
		return true
	if not panel.is_open():
		return false
	if batch.stroke_active() and _stroke_pointer(event):
		return true
	return _world_enter(event)


func _level_key(event: InputEvent) -> bool:
	"""PageUp / PageDown (`level_up` / `level_down`, exactly: Alt+PageUp is the pitch); a held key's repeats are taken
	and do nothing."""
	var up: bool = event.is_action_pressed(&"level_up", true, true)
	if not up and not event.is_action_pressed(&"level_down", true, true):
		return false
	if not event.is_echo():
		step_level(-1 if up else 1)
	return true


func _stroke_pointer(event: InputEvent) -> bool:
	"""The stroke follows the pointer and ends on the left release, wherever it is."""
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		var hit: Paint.WorldTool.Pick = paint.pick(_pointer, bar.shown_level())
		if hit.ok:
			paint.set_cursor(hit.cell, bar.shown_level(), armed_type())
			batch.extend_stroke(hit.cell)
		return true
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish()
		return true
	return false


func _world_enter(event: InputEvent) -> bool:
	"""Enter with a type armed and no control focused: the first corner, then the second (the keyboard's paint)."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or armed_type() < 0 or _focused():
		return false
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return false
	if not batch.stroke_active():
		_pointer = Vector2.INF
		_begin_at(paint.cursor())
	else:
		_finish()
	return true


func _focused() -> bool:
	"""Whether a control holds the focus (Enter is then its own)."""
	return is_inside_tree() and get_viewport().gui_get_focus_owner() != null


func handle_input(event: InputEvent) -> bool:
	"""After the HUD: B, and the panel's keys and world clicks (see KEYS). True when taken."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if event.is_action_pressed(&"open_build", false, true):
		toggle_panel()
		return true
	if not panel.is_open():
		return false
	if event is InputEventKey:
		return _panel_key(event as InputEventKey)
	if event is InputEventMouseButton:
		return _panel_click(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
	return false


func _panel_key(key: InputEventKey) -> bool:
	"""Escape, the tab cycle, Undo / Redo, and the arrows' cell cursor."""
	if not key.pressed:
		return false
	if key.keycode == KEY_ESCAPE and not key.echo:
		return panel.escape()
	if key.is_action_pressed(&"ui_tab_next", false, true) or key.is_action_pressed(&"ui_tab_previous", false, true):
		panel.cycle_tab(not key.shift_pressed)
		return true
	if key.is_action_pressed(&"tool_redo", true, true):
		if not batch.stroke_active():
			batch.redo()
		return true
	if key.is_action_pressed(&"tool_undo", true, true):
		batch.undo()
		return true
	return _arrow(key)


func _arrow(key: InputEventKey) -> bool:
	"""With a type armed, an arrow moves the cell cursor one cell relative to the camera and drags a keyboard stroke
	with it."""
	if armed_type() < 0 or not ARROW_KEYS.has(key.keycode) or key.shift_pressed or key.ctrl_pressed or key.alt_pressed:
		return false
	_pointer = Vector2.INF
	var forward: Vector3 = -_camera.global_transform.basis.z if is_instance_valid(_camera) else Vector3.FORWARD
	var cell: Vector2i = paint.cursor() + arrow_step(key.keycode, forward)
	paint.set_cursor(cell, bar.shown_level(), armed_type())
	batch.extend_stroke(cell)
	return true


static func arrow_step(keycode: int, forward: Vector3) -> Vector2i:
	"""P-B10 (b): Up moves one cell the way the camera looks, snapped to the grid's nearer axis (a tie goes to z);
	Right a quarter turn clockwise from it seen from above; Down and Left the opposites. Vector2i(0, 0) for another key."""
	var up: Vector2i = Vector2i(1 if forward.x > 0.0 else -1, 0) if absf(forward.x) > absf(forward.z) \
		else Vector2i(0, -1 if forward.z <= 0.0 else 1)
	var right: Vector2i = Vector2i(-up.y, up.x)
	match keycode:
		KEY_UP:
			return up
		KEY_DOWN:
			return -up
		KEY_RIGHT:
			return right
		KEY_LEFT:
			return -right
	return Vector2i.ZERO


func _panel_click(button: InputEventMouseButton) -> bool:
	"""A left press on the floor begins a stroke; a right press cancels one in progress."""
	if not button.pressed:
		return false
	if button.button_index == MOUSE_BUTTON_RIGHT:
		return batch.cancel_stroke()
	if button.button_index != MOUSE_BUTTON_LEFT or armed_type() < 0:
		return false
	var hit: Paint.WorldTool.Pick = paint.pick(button.position, bar.shown_level())
	_pointer = button.position
	return hit.ok and _begin_at(hit.cell)


func _hover(at: Vector2) -> void:
	"""The cursor cell follows the pointer over the floor (not taken: the hover ring still follows too)."""
	_pointer = at
	if armed_type() < 0:
		return
	var hit: Paint.WorldTool.Pick = paint.pick(at, bar.shown_level())
	if hit.ok:
		paint.set_cursor(hit.cell, bar.shown_level(), armed_type())


func centre_cursor() -> void:
	"""Put the cell cursor under the middle of the screen (the keyboard's start)."""
	if not is_inside_tree():
		return
	var hit: Paint.WorldTool.Pick = paint.pick(get_viewport().get_visible_rect().size / 2.0, bar.shown_level())
	if hit.ok:
		paint.set_cursor(hit.cell, bar.shown_level(), armed_type())
	_pointer = Vector2.INF


# --- the cards -----------------------------------------------------------------------------------------------------

func _on_card_chosen(card: BuildCatalog.Card) -> void:
	"""A room type arms painting (the cursor to the screen's middle); a locked card is only shown."""
	if card.kind == BuildCatalog.CARD_ROOM and card.usable():
		centre_cursor()
