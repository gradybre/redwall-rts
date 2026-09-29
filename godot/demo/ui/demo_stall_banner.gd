extends CanvasLayer
## "The simulation paused after a stall -- Resume": the player's way out of the REQ-SET-008 diagnostic
## pause. Decision 0196 (the Windows demo build). DEMO UI.
##
## WHY. When the computer stalls long enough that the clock falls a quarter second behind at 1x (a
## shader compile on a first run, a hitch), the clock does not skip the owed time: it holds a CRITICAL
## pause with a diagnostic (REQ-SET-008, ARCH-CLOCK-001). Recovery is the PLAYER's, never automatic,
## and it is `GameManager.acknowledge_overload()` -- the HUD's pause button releases only the PLAYER
## reason, and nothing in the game's HUD offers the acknowledgement yet, so the demo stayed frozen.
##
## WHAT. While the clock holds CRITICAL, a banner at the top centre, just under the HUD's alert zone,
## says what happened and offers Resume; it is drawn above the HUD and takes the mouse. Resume -- the
## button, or Enter or Space while the banner shows -- calls `acknowledge_overload()` once. That drops
## the owed ticks explicitly (the clock counts every acknowledgement) and clears CRITICAL only; a PLAYER
## pause the player set stays set. It NEVER resumes on its own: it only watches, a few times a second.
##
## Geometry is the HUD's own (`scripts/ui/ui_layout.gd`, read, never modified), in logical pixels at the
## HUD's scale, as the news strip's.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")

const TITLE: String = "The simulation paused after a stall"
const BODY: String = "The computer fell behind, so the village stopped rather than skip time. Nothing is lost."
const RESUME: String = "Resume  (Enter)"
const LAYER: int = 2
const WIDTH: float = 460.0
const GAP: float = 10.0
const TITLE_PX: int = 17
const BODY_PX: int = 14
const REFRESH_S: float = 0.1
const MARGINS: PackedFloat32Array = [18.0, 12.0, 18.0, 14.0]

var _manager: GameManagerScript = null
var _frame: PanelContainer = null
var _button: Button = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _refresh_in: float = 0.0
## How many times the player resumed through this banner (checks).
var resumes: int = 0


func bind(manager: GameManagerScript) -> void:
	"""Watch this game clock, and build."""
	_manager = manager
	build()


func _ready() -> void:
	"""Keep watching while anything pauses, place, and follow the viewport's size."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden frame: title, body and the Resume button (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "DemoStallBanner"
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_label(TITLE, TITLE_PX, Palette.CLAY, Styles.heading_font()))
	column.add_child(_label(BODY, BODY_PX, Palette.INK, null))
	_button = FarmUi.button(RESUME, BODY_PX + 1)
	_button.focus_mode = Control.FOCUS_ALL
	_button.add_theme_stylebox_override(&"focus", Styles.clear(MARGINS))
	_button.pressed.connect(resume)
	column.add_child(_button)


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped line of the banner."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - MARGINS[0] - MARGINS[2]
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	return label


func _process(delta: float) -> void:
	"""Look at the clock a few times a second (real time); show or hide to match. Never resumes."""
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


func refresh() -> bool:
	"""Show the banner exactly while CRITICAL is held; returns whether it is shown."""
	var held: bool = is_held()
	if _frame != null and _frame.visible != held:
		_frame.visible = held
		if held:
			_place()
			if _button.is_inside_tree():
				_button.grab_focus()
	return held


func is_held() -> bool:
	"""Whether the game clock holds the REQ-SET-008 diagnostic (CRITICAL) pause."""
	return _manager != null and _manager.clock().has_pause_reason(SimClockScript.CRITICAL)


func is_shown() -> bool:
	"""Whether the banner is drawn."""
	return _frame != null and _frame.visible


func _input(event: InputEvent) -> void:
	"""Enter or Space resumes while the banner shows (the HUD's Space would only toggle PLAYER)."""
	if not is_shown():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
		resume()
		get_viewport().set_input_as_handled()


func resume() -> int:
	"""The player's acknowledgement: clear CRITICAL through `acknowledge_overload()`. Returns the owed
	ticks it dropped (0, and nothing done, when CRITICAL is not held)."""
	if not is_held():
		return 0
	var dropped: int = _manager.acknowledge_overload()
	resumes += 1
	refresh()
	return dropped


func _place() -> void:
	"""Top centre, just under the HUD's alert zone, at the HUD's scale."""
	if not is_inside_tree() or _frame == null:
		return
	var size_px: Vector2 = get_viewport().get_visible_rect().size
	if not _layout.compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), UiLayout.USER_SCALE_100, false, _geometry):
		_geometry.scale = 1.0
	var alerts: Rect2 = _geometry.alerts
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.size = Vector2(WIDTH, 0.0)
	var x: float = alerts.position.x + (alerts.size.x - WIDTH) / 2.0
	_frame.position = Vector2(x, alerts.end.y + GAP) * _geometry.scale
