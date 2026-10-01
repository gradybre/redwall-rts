extends CanvasLayer
## "RUN UNTIL...": the time controls' button and its menu. Decision 0471 (review UX-022). DEMO UI in the woodland skin.
##
## THE BUTTON sits IN the HUD's time cluster (top right, UI §1's time controls): in row 1's free end, right of the
## 4x toggle, at the standard and wide profiles; just left of the cluster at the narrow profile, whose one row has no
## room (`button_rect`). It reads "Run until…" -- or, while a run is under way, "■ " and its target ("■ Dawn"), its
## tooltip saying until what and at which speed. It and G open the MENU. The button is on a layer of its own
## (`button_layer`, which the host adds beside this one: above the HUD, under every modal), so this layer's own
## visibility is the menu's, as the input gate reads a modal.
##
## THE MENU (a modal: demo_input_gate.gd; Esc, G or Close shut it), just under the cluster: the speed to run at (1x /
## 2x / 4x, the game's own requested speed), one button per target with what it would do now -- "Dawn: 06:00, in
## 3 h 20 min (about 50 s at 4x)" -- or, disabled, why it cannot ("Project done: Select a tunnel, room or bridge being
## built first"); "Stop the run" while one is under way; and Close. Choosing a target starts the run and closes the
## menu. The host decides everything (`on_start`, `on_stop`, `on_speed`); the menu only shows run_until.gd.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const RunScript := preload("res://demo/session/run_until.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const LAYER: int = 2
const WIDTH: float = 420.0
const GAP: float = 8.0
## The button: at least this wide inside the cluster (logical px), and this wide outside it.
const MIN_INSIDE_W: float = 92.0
const OUTSIDE_W: float = 128.0
const BUTTON_TEXT: String = "Run until…"
const RUNNING_TEXT: String = "■ %s"
const BUTTON_TIP: String = "Run the village until dawn, dusk, the next meal, a project, a harvest or a warning (G)"
const RUNNING_TIP: String = "Running until %s at %dx. G or this button: the menu, to stop it"
const TITLE: String = "Run until…"
const NOTE: String = "The village runs at the speed below, then pauses and says why. Any pause or critical event cancels the run."
const SPEED_TITLE: String = "Speed"
const STOP_TEXT: String = "Stop the run (until %s)"
const CLOSE_TEXT: String = "Close (G or Esc)"
## The key that opens and closes the menu.
const KEY: Key = KEY_G

## Host actions: `on_start(target) -> bool`, `on_stop()`, `on_speed(speed)`; `speed() -> int` the requested speed;
## `before_open()` (the selected project read now).
var on_start: Callable = Callable()
var on_stop: Callable = Callable()
var on_speed: Callable = Callable()
var speed: Callable = Callable()
var before_open: Callable = Callable()

var _run: RunScript = null
var _button_layer: CanvasLayer = null
var _button: Button = null
var _frame: PanelContainer = null
var _speeds: Array[Button] = []
var _targets: Array[Button] = []
var _stop: Button = null
var _close: Button = null
var _cluster: Callable = Callable()
var _last_speed: Callable = Callable()
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _shown_running: int = -2


func _init() -> void:
	"""The button on its own layer (always shown) and the hidden menu."""
	name = "DemoRunMenu"
	layer = LAYER
	visible = false
	_button_layer = CanvasLayer.new()
	_button_layer.name = "RunButton"
	_button_layer.layer = 1
	_button = FarmUi.button(BUTTON_TEXT, FarmUi.SMALL_PX)
	_button.tooltip_text = BUTTON_TIP
	_button.pressed.connect(toggle)
	_button_layer.add_child(_button)
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true))
	var note: Label = FarmUi.label(NOTE, FarmUi.SMALL_PX, Palette.UMBER)
	note.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	column.add_child(note)
	column.add_child(_build_speeds())
	_build_targets(column)
	_stop = FarmUi.button("", FarmUi.SMALL_PX)
	_stop.pressed.connect(stop)
	column.add_child(_stop)
	_close = FarmUi.button(CLOSE_TEXT, FarmUi.SMALL_PX)
	_close.pressed.connect(close)
	column.add_child(_close)


func _build_targets(column: VBoxContainer) -> void:
	"""One button per target, its line wrapping at the menu's width."""
	for target: int in RunScript.TARGET_COUNT:
		var button: Button = FarmUi.button("", FarmUi.SMALL_PX)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
		button.pressed.connect(choose.bind(target))
		column.add_child(button)
		_targets.append(button)


func _build_speeds() -> HBoxContainer:
	"""'Speed' and the three speeds, lit at the requested one."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var title: Label = FarmUi.label(SPEED_TITLE, FarmUi.SMALL_PX, Palette.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	for value: int in SimClock.SELECTABLE_SPEEDS:
		var button: Button = FarmUi.button("%dx" % value, FarmUi.SMALL_PX)
		button.toggle_mode = true
		button.tooltip_text = "Run at %dx" % value
		button.pressed.connect(choose_speed.bind(value))
		row.add_child(button)
		_speeds.append(button)
	return row


func configure(run: RunScript, cluster: Callable, last_speed: Callable) -> void:
	"""Show this run; `cluster() -> Rect2` and `last_speed() -> Rect2` are the HUD's time cluster and its 4x toggle
	in viewport pixels (where the button goes)."""
	_run = run
	_cluster = cluster
	_last_speed = last_speed


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place.call_deferred()


func button_layer() -> CanvasLayer:
	"""The button's own layer, for the host to add (see the header)."""
	return _button_layer


func _process(_delta: float) -> void:
	"""Keep the button's words on the run (only rewritten when the run changed). Runs while the menu is hidden: a
	hidden CanvasLayer still processes."""
	var running: int = _run.target if _run != null else RunScript.NO_TARGET
	if running != _shown_running:
		_shown_running = running
		_paint_button()
		_place.call_deferred()


func _paint_button() -> void:
	"""'Run until…', or '■ Dawn' with until what and at what speed."""
	if _run == null or not _run.is_running():
		_button.text = BUTTON_TEXT
		_button.tooltip_text = BUTTON_TIP
		return
	_button.text = RUNNING_TEXT % RunScript.TARGET_TITLES[_run.target]
	_button.tooltip_text = RUNNING_TIP % [_run.words(_run.target), _speed_now()]


func _speed_now() -> int:
	"""The requested speed (1 unbound)."""
	return int(speed.call()) if speed.is_valid() else 1


# --- the menu -------------------------------------------------------------------------------------------------

func open() -> void:
	"""Show the menu with every target's line read now."""
	if visible:
		return
	if before_open.is_valid():
		before_open.call()
	refresh()
	visible = true
	_place.call_deferred()


func close() -> void:
	"""Hide the menu."""
	visible = false


func toggle() -> void:
	"""G, or the button: open, or close."""
	if visible:
		close()
	else:
		open()


func is_open() -> bool:
	"""Whether the menu is shown."""
	return visible


func refresh() -> void:
	"""The speeds lit, each target's line and state, Stop shown while a run is under way."""
	var now: int = _speed_now()
	for k: int in _speeds.size():
		_speeds[k].set_pressed_no_signal(SimClock.SELECTABLE_SPEEDS[k] == now)
	for target: int in _targets.size():
		var why: String = _run.refusal(target) if _run != null else "No run"
		_targets[target].text = _run.preview(target, now) if _run != null else ""
		FarmUi.set_enabled(_targets[target], why.is_empty(), why)
	var running: bool = _run != null and _run.is_running()
	_stop.visible = running
	if running:
		_stop.text = STOP_TEXT % _run.words(_run.target)
	_paint_button()


func choose(target: int) -> void:
	"""Start running until `target` (the host's), and close."""
	if on_start.is_valid() and bool(on_start.call(target)):
		close()
	else:
		refresh()


func choose_speed(value: int) -> void:
	"""Set the speed the run goes at (the game's requested speed)."""
	if on_speed.is_valid():
		on_speed.call(value)
	refresh()


func stop() -> void:
	"""Stop the run under way (the host's), and close."""
	if on_stop.is_valid():
		on_stop.call()
	close()


# --- checks ---------------------------------------------------------------------------------------------------

func frame() -> PanelContainer:
	"""The menu's frame (the gate's focus trap root)."""
	return _frame


func button() -> Button:
	"""The time controls' "Run until…" button."""
	return _button


func target_button(target: int) -> Button:
	"""Target `target`'s button (RunScript.TARGET_*)."""
	return _targets[target]


func speed_button(k: int) -> Button:
	"""The speed toggle for SimClock.SELECTABLE_SPEEDS[k]."""
	return _speeds[k]


func stop_button() -> Button:
	"""Stop the run."""
	return _stop


func close_button() -> Button:
	"""The menu's Close."""
	return _close


# --- placement ------------------------------------------------------------------------------------------------

static func button_rect(cluster: Rect2, last_speed: Rect2, scale: float) -> Rect2:
	"""The button's rectangle, viewport px: row 1's free end of the cluster, right of the 4x toggle, when it has
	MIN_INSIDE_W; else OUTSIDE_W wide just left of the cluster, level with the 4x toggle."""
	var gap: float = GAP * scale
	var left: float = last_speed.end.x + gap
	var right: float = cluster.end.x - gap
	if right - left >= MIN_INSIDE_W * scale:
		return Rect2(left, last_speed.position.y, right - left, last_speed.size.y)
	var width: float = OUTSIDE_W * scale
	return Rect2(cluster.position.x - gap - width, last_speed.position.y, width, last_speed.size.y)


func _place() -> void:
	"""The button on the cluster; the menu just under the cluster, its right edge on the cluster's."""
	if not is_inside_tree() or not _cluster.is_valid():
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var scale: float = _geometry.scale
	var cluster: Rect2 = _cluster.call()
	var rect: Rect2 = button_rect(cluster, _last_speed.call(), scale)
	_button.scale = Vector2(scale, scale)
	_button.position = rect.position
	_button.custom_minimum_size = Vector2(rect.size.x / scale, rect.size.y / scale)
	_button.size = _button.custom_minimum_size
	var logical_right: float = cluster.end.x / scale
	var width: float = minf(WIDTH, _geometry.logical_width - 2.0 * FarmUi.FRAME_EXPAND)
	var x: float = clampf(logical_right - width, FarmUi.FRAME_EXPAND, _geometry.logical_width - width)
	FarmUi.place(_frame, Rect2(x, cluster.end.y / scale + GAP + FarmUi.FRAME_EXPAND, width, 0.0), scale)
