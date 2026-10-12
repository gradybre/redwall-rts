extends Node
## THE ONE BUILD PANEL AND THE LEVEL BAR IN THE DEMO (DEC-061 Q1; docs/ui_ux_controls.md UI-BUILD-001; decision 1871).
## The panel and the bar are game UI (scripts/ui/build_panel.gd, level_bar.gd); this mounts them over the village and
## maps them onto what the demo has: the legacy warren's U view, its dig and room tools, and the settlement's planner
## route (Brendan's rulings 2-4 of 2026-10-12).
##
## KEYS (read through demo_command.gd's build hooks: `takes_before_gui`, then `handle_input` before the Dig tool's):
##   B                  open or close the panel (closing with pending changes asks Keep / Discard). In the Dig tool
##                      B stays the tool's: it closes it, and the panel comes back.
##   PageUp / PageDown  the level bar, everywhere (level_up / level_down): Surface ... Level 4. Read before the HUD, as
##                      the U view's level keys were; never behind a modal.
##   in the panel:      Esc one layer (the stroke, a question, the ledger, the panel); Ctrl+Tab / Ctrl+Shift+Tab the
##                      tabs; Ctrl+Z / Cmd+Z undo; Ctrl+Shift+Z, Ctrl+Y / Cmd+Shift+Z redo; with a room type armed,
##                      left drag paints a rectangle, right click cancels the stroke, the arrows move the cell cursor
##                      (north is -Z) and Enter sets the first corner, Enter again the second.
##
## THE LEVELS. Surface = the U view off. Level 1 / Level 2 = the U view on that level of the legacy warren (its 4 m
## spacing is the demo's; DEC-061's 5 m is slices C/D's). Levels 3 and 4: no way in yet in the demo -- selected, the
## U view shows nothing (tunnel_view.gd `set_unreached`) and nothing can be painted. Overview = the surface view with
## painting off (the demo has no all-levels view: a PROPOSAL). U still toggles the view; the bar follows it.
##
## THE CARDS. A room type arms painting on levels 1-2 (on the surface the room cards are locked); Passage opens the
## Dig tool and Burrow home / Root cellar its room tool (their own confirm), the panel hidden until the tool closes.
## While the panel shows, the HUD's command strip (UI-SET-026) and its detail (UI-SET-036), the demo's right column,
## its map-layer picker and its news strip are hidden (their place is the panel's), and given back on close.
## Opening, painting, Undo, Redo and Discard all touch no store, reservation or job; Confirm all orders each valid
## operation through the planner's route (demo_build_orders.gd) and deducts nothing.

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
const TunnelControl := preload("res://demo/tunnel/tunnel_control.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const ThemeResource: Theme = preload("res://ui/theme/woodland_theme.tres")
const CardScript := preload("res://demo/ui/action_card.gd")
## The paint label keeps this far inside the window's edges (UI §1.2's safe inset).
const SAFE_INSET: float = 16.0

## Over the demo's panels (layer 0), with the HUD's.
const CANVAS_LAYER: int = 1
const LABEL_OFFSET: Vector2 = Vector2(18.0, 18.0)
const LABEL_PX: int = 16
## The paint label keeps this far above the panel.
const LABEL_GAP: float = 8.0
const ARMED_HINT: String = "Paint %s: drag on the floor, or Enter to set a corner"
const NO_WAY_IN_HERE: String = "Paint %s: %s"
const ORDERED: String = "Confirm all: %d ordered, %d kept back"
const OPENED: String = "Build on %s: choose a room type to paint"
const CLOSED_KEPT: String = "Build panel closed; its pending changes are kept"
const ARROWS: Dictionary = {KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_UP: Vector2i(0, -1),
	KEY_DOWN: Vector2i(0, 1)}

var panel: BuildPanel = null
var bar: LevelBar = null
var batch: Batch = null
var catalog: BuildCatalog = null
var paint: Paint = null
var orders: Orders = null
var _layer: CanvasLayer = null
var _label_box: PanelContainer = null
var _label: Label = null
var _tunnels: TunnelControl = null
var _shell: UiShell = null
var _blocked: Callable = Callable()
var _say: Callable = Callable()
var _hide: Array[Node] = []
var _hidden_was: PackedByteArray = PackedByteArray()
var _holding: bool = false
var _special: int = -1
var _special_on: bool = false
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _minimap_was: bool = true
var _pointer: Vector2 = Vector2.INF
var _seen_label: int = -1
## Why the panel could not be set up ("": it was): painting stays disarmed (decision 1871, review M4).
var _setup_refusal: StringName = &""
## `interrupts(actor_index) -> String`: what an order would stop (demo_command.gd `interrupt_text`), for the old tools'
## cards' notes (review M8). Unset: no such line.
var _interrupts: Callable = Callable()
var _card_data: CardScript = CardScript.new()


func configure(tunnels: TunnelControl, shell: UiShell, camera: Camera3D, blocked: Callable, say: Callable,
		hide: Array[Node], session: Object) -> void:
	"""Mount over this village: its Dig tool and U view, the HUD shell, the camera that paints, the modal test
	(`blocked() -> bool`), the notice line (`say(text)`), the demo surfaces the panel replaces while open, and the
	settlement's underground session (null: none composed, every order refused)."""
	name = "DemoBuild"
	_tunnels = tunnels
	_shell = shell
	_blocked = blocked
	_say = say
	_hide = hide.duplicate()
	catalog = BuildCatalog.new()
	orders = Orders.new()
	orders.bind_session(session, camera)
	for level: int in range(1, LevelBar.LEVEL_DEEPEST + 1):
		catalog.set_level_clear_height(level, orders.clear_height_of(level))
	batch = Batch.new()
	paint = Paint.new()
	add_child(paint)
	take_setup(batch.configure(catalog, orders.cell_bounds(), orders.cell_capacity()))
	take_setup(paint.configure(batch, camera, Vector2i(orders.datum_u().x, orders.datum_u().z), orders.cell_bounds()))
	_build_layer()
	panel.card_note = _card_note
	place()


func take_setup(code: StringName) -> void:
	"""A setup step's answer: a refusal is kept (painting stays disarmed) and shown as a HUD refusal."""
	if code == &"" or _setup_refusal != &"":
		return
	_setup_refusal = code
	UIManager.push_refusal(code)


func setup_refusal() -> StringName:
	"""Why the panel could not be set up ("" when it was)."""
	return _setup_refusal


func set_interrupts(interrupts: Callable) -> void:
	"""`interrupts(actor_index) -> String`: what an order to that resident would stop (the old tools' card notes)."""
	_interrupts = interrupts


func _card_note(card: BuildCatalog.Card) -> String:
	"""The old tools' action card on their cards (review M8): who would dig and what they would stop."""
	if card.kind != BuildCatalog.CARD_LEGACY:
		return ""
	_tunnels.tool_card_into(_card_data, card.name, card.purpose)
	if _card_data.worker >= 0 and _interrupts.is_valid():
		_card_data.interrupts = String(_interrupts.call(_card_data.worker))
	return _card_data.text()


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
	"""Whether the panel is open (suspended behind an old tool or not)."""
	return panel.is_open()


func open_panel() -> bool:
	"""Open the panel on the level shown (refused behind a modal or the stall banner). True when it is open."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if not panel.is_open():
		panel.open_on(bar.shown_level(), bar.is_reachable(bar.shown_level()))
		_hold_hud()
		if is_inside_tree():
			get_viewport().gui_release_focus()
		_say.call(OPENED % LevelBar.level_name(bar.shown_level()))
	return true


func toggle_panel() -> bool:
	"""B: open, or ask to close. True when the panel is open afterwards."""
	if panel.is_open():
		panel.request_close()
		return panel.is_open()
	return open_panel()


func _on_closed(kept: bool) -> void:
	"""The panel closed: the HUD's surfaces back, the ghosts' stroke and label hidden."""
	_release_hud()
	_label_box.visible = false
	paint.refresh(bar.shown_level(), false)
	if kept and batch.pending_count() > 0:
		_say.call(CLOSED_KEPT)


# --- per frame -----------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Follow the view (U, the Dig tool), the old tools' end, the minimap; hold the HUD; redraw the ghosts and label.
	Integer compares a frame; allocation only when something changed."""
	follow_view()
	if panel.suspended() and not _tunnels.planning:
		panel.suspend(false)
	if minimap_shown() != _minimap_was:
		place()
	var open: bool = panel.is_open() and not panel.suspended()
	if open:
		_hold_hud()
	elif _holding:
		_release_hud()
	paint.refresh(bar.shown_level(), open and armed_type() >= 0)
	_sync_label(open)


func follow_view() -> void:
	"""The bar (and the panel) show the level the view shows: the U key and the Dig tool move it too."""
	var shown: int = view_level()
	if shown != bar.shown_level():
		bar.set_level(shown)
	if shown != panel.building_level():
		batch.cancel_stroke()
		panel.set_level(shown, bar.is_reachable(shown))


func view_level() -> int:
	"""The level shown, in the bar's terms: a level 3/4 or Overview choice while the view is as it left it, else the
	U view's level, or the surface with it off."""
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
	"""Map the bar's level onto the demo's view (see THE LEVELS); the bar then follows what the view really shows
	(a room tool holding a draft on another level refuses to move, and says so)."""
	_set_special(-1)
	var view_on: bool = _tunnels.view.on
	match level:
		LevelBar.LEVEL_SURFACE, LevelBar.LEVEL_OVERVIEW:
			if view_on:
				_tunnels.toggle_view()
		1, 2:
			if not view_on:
				_tunnels.toggle_view()
			_tunnels.show_level(level)
		_:
			if not view_on:
				_tunnels.toggle_view()
	if (level == 3 or level == 4) and _tunnels.view.on:
		_set_special(level)
	elif level == LevelBar.LEVEL_OVERVIEW and not _tunnels.view.on:
		_set_special(level)
	follow_view()


func _set_special(level: int) -> void:
	"""Hold a level the view cannot name itself (3, 4 or Overview) until the view changes under it."""
	_special = level
	_special_on = _tunnels.view.on
	_tunnels.view.set_unreached(level == 3 or level == 4)


# --- painting ------------------------------------------------------------------------------------------------------

func armed_type() -> int:
	"""The room type a stroke paints now, or -1: the panel open with a type chosen, on a level 1-2 view."""
	if _setup_refusal != &"" or not panel.is_open() or panel.suspended() or _special >= 0 or not _tunnels.view.on:
		return -1
	var level: int = bar.shown_level()
	return panel.paint_type() if Paint.paintable(level) and bar.is_reachable(level) else -1


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
	if not panel.is_open() or panel.suspended():
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
	"""After the HUD, before the Dig tool: B, and the panel's keys and world clicks (see KEYS). True when taken."""
	if (_blocked.is_valid() and bool(_blocked.call())) or _tunnels.planning:
		return false
	if event.is_action_pressed(&"open_build", false, true):
		toggle_panel()
		return true
	if not panel.is_open() or panel.suspended():
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
	"""With a type armed, an arrow moves the cell cursor one cell (north is -Z) and drags a keyboard stroke with it."""
	if armed_type() < 0 or not ARROWS.has(key.keycode) or key.shift_pressed or key.ctrl_pressed or key.alt_pressed:
		return false
	_pointer = Vector2.INF
	var cell: Vector2i = paint.cursor() + ARROWS[key.keycode]
	paint.set_cursor(cell, bar.shown_level(), armed_type())
	batch.extend_stroke(cell)
	return true


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
	"""A room type arms painting (the cursor to the screen's middle); Passage, Burrow home and Root cellar open their
	old tool, the panel hidden until it closes; a locked card is only shown."""
	if card.kind == BuildCatalog.CARD_ROOM and card.usable():
		centre_cursor()
		return
	if card.kind != BuildCatalog.CARD_LEGACY:
		return
	batch.cancel_stroke()
	panel.suspend(true)
	_release_hud()
	if not _open_legacy(card.legacy):
		panel.suspend(false)


func _open_legacy(legacy: int) -> bool:
	"""Open the old tool for a legacy card; false when it refused (it says why in the notice line)."""
	match legacy:
		BuildCatalog.LEGACY_PASSAGE:
			return _tunnels.planning or _tunnels.begin_plan()
		BuildCatalog.LEGACY_HOME:
			return _tunnels.begin_room(RoomsScript.TEMPLATE_HOME)
		BuildCatalog.LEGACY_CELLAR:
			return _tunnels.begin_room(RoomsScript.TEMPLATE_CELLAR)
	return false
