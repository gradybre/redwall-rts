extends CanvasLayer
## The live demo's game menu: UI-SET-019's Menu button, and Esc once nothing else is left to dismiss
## (UI §3's ladder ends in "open game menu"). Decision 0261 (review F29). DEMO UI in the woodland skin.
##
## Before this the Menu button opened UI-SET-103, the New Settlement form, whose Create would discard
## the settlement the demo runs on. The demo has no use for it, so it is not reachable here.
##
## PAGES, one at a time in one carved frame, centred in the HUD's modal rectangle:
##   * the MENU: Resume, Restart demo…, Controls, Settings, Demo Lab, Quit… -- and, always shown, the
##     line that the demo cannot save yet;
##   * CONTROLS: the demo's keys and clicks (DEMO_CONTROLS);
##   * SETTINGS: only what works -- the interface scale (100/125/150 %, UI §8.1's `ui_scale`, each size
##     offered only where the layout fits it) and full screen; sound is marked as not in the demo;
##   * CONFIRM: Restart and Quit both ask first, and say again that the village will be lost. Focus lands
##     on Cancel.
## Esc goes back one page, and from the menu closes it (the input gate calls `back_or_close`).
##
## PAUSE. Opening holds the clock's MENU pause reason (`GameManager.set_menu_pause`), closing releases
## it: the requested speed is kept apart, so the village comes back at the speed it had, and a PLAYER
## pause held before stays held. Drawn above the HUD (LAYER), below the stall banner.
##
## ACTIONS are the host's Callables (`on_restart`, `on_quit`, `on_lab`, `on_scale`, `on_fullscreen`,
## ...), so the menu decides nothing about the scene; demo_village.gd wires them.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const PAGE_MENU: int = 0
const PAGE_CONTROLS: int = 1
const PAGE_SETTINGS: int = 2
const PAGE_CONFIRM: int = 3
const CONFIRM_RESTART: int = 0
const CONFIRM_QUIT: int = 1
## The menu's Restart and Quit buttons (MENU_BUTTONS order).
const BUTTON_RESTART: int = 1
const BUTTON_QUIT: int = 5
## The menu button a page returns focus to, by page (the confirmation: Restart's, or Quit's).
const RETURN_BUTTON: Array[int] = [0, 2, 3, BUTTON_RESTART]
## Above the HUD's CanvasLayer (1), with the Pantry; the stall banner draws at 3, above it.
const LAYER: int = 2
const WIDTH: float = 560.0
## The Controls list scrolls within the modal rectangle less this (title, Back, margins).
const LIST_RESERVE_H: float = 150.0

const TITLE: String = "Game menu"
const PAUSED_LINE: String = "The village is paused while this menu is open."
const NO_SAVE_LINE: String = "The demo can't save yet: quitting or restarting loses this village."
const MENU_BUTTONS: Array[String] = ["Resume", "Restart demo…", "Controls", "Settings", "Demo Lab (F8)", "Quit…"]
const MENU_TIPS: Array[String] = [
	"Close the menu and carry on at the speed you had (Esc)",
	"Start the demo again from its first morning (asks first)",
	"The demo's keys and clicks",
	"Interface scale and full screen",
	"Test triggers -- weather, a tunnel threat, a storm gust, a swimmer's cramp",
	"Leave the demo (asks first)",
]
const CONFIRM_TITLES: Array[String] = ["Restart the demo?", "Quit the demo?"]
const CONFIRM_VERBS: Array[String] = ["Restart demo", "Quit demo"]
const CONFIRM_LINE: String = "The demo can't save yet: this village -- its fields, tunnels, woods and stores -- will be lost."
const SCALE_TITLE: String = "Interface scale"
const SCALE_TOO_SMALL: String = "%d%% needs a larger window"
const SCALES_TOO_SMALL: String = "%s need a larger window"
const FULLSCREEN_TEXT: String = "Full screen (F11): %s"
const SOUND_LINE: String = "Sound: the demo has no sound yet, so there is nothing to set."
const BACK_TEXT: String = "Back"
## The demo's keys and clicks, as the Controls page lists them (README "Commanding the residents").
const DEMO_CONTROLS: Array = [
	["Left click", "Select a resident (Shift: add or take it out); a bed, tunnel, tree or bridge site opens its panel"],
	["Left drag", "Box-select residents (Shift: add to the selection)"],
	["Right click", "Order the selection: move there, or work the spot, bed, tree, heap or water clicked"],
	["R", "Release the selection to its own routine"],
	["Esc", "Close the top pop-up; then clear the selection; then open this menu"],
	["W A S D, arrows", "Pan the camera"],
	["Q / E, middle drag", "Turn the camera (middle drag also tilts it)"],
	["Wheel, Page Up / Down", "Zoom"],
	["Home", "Reset the view"],
	["Space", "Pause or resume"],
	["B or T", "Dig tool: drag a tunnel (Enter digs a piece laid by clicks; Backspace takes a point back)"],
	["H / C in the Dig tool", "Place a burrow home / a root cellar"],
	["U", "Underground view"],
	["V", "Cycle the map overlays"],
	["K", "The Pantry"],
	["N", "Notification history"],
	["F7", "Keyboard focus: world, then the right column, then the left column, then the world"],
	["Tab / Shift+Tab", "Next / previous button where the focus is"],
	["Enter / Space", "Press the focused button"],
	["F8", "Demo Lab"],
	["F11", "Full screen"],
]

## Host actions (see ACTIONS). `scale_fits(percent) -> bool`; `is_fullscreen() -> bool`.
var on_restart: Callable = Callable()
var on_quit: Callable = Callable()
var on_lab: Callable = Callable()
var on_scale: Callable = Callable()
var scale_fits: Callable = Callable()
var on_fullscreen: Callable = Callable()
var is_fullscreen: Callable = Callable()
var scale_percent: int = UiLayout.USER_SCALE_100

var _manager: GameManagerScript = null
var _holding: bool = false
var _page: int = PAGE_MENU
var _confirming: int = CONFIRM_RESTART
var _frame: PanelContainer = null
var _pages: Array[VBoxContainer] = []
var _menu_buttons: Array[Button] = []
var _scale_buttons: Array[Button] = []
var _scale_note: Label = null
var _fullscreen: Button = null
var _controls_scroll: ScrollContainer = null
var _confirm_title: Label = null
var _confirm_cancel: Button = null
var _confirm_ok: Button = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "DemoMenu"
	layer = LAYER
	visible = false
	_build()


func bind(manager: GameManagerScript) -> void:
	"""The clock whose MENU pause reason the menu holds while open."""
	_manager = manager


func _ready() -> void:
	"""Follow the viewport's size, and the frame's content: a page's minimum size settles only after the
	containers sort, so the frame is placed again when it changes (a shorter page shrinks it)."""
	get_viewport().size_changed.connect(_place)
	_frame.minimum_size_changed.connect(_place, CONNECT_DEFERRED)
	_place()


func _build() -> void:
	"""The frame and its four pages."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var stack := VBoxContainer.new()
	_frame.add_child(stack)
	for page: VBoxContainer in [_build_menu(), _build_controls(), _build_settings(), _build_confirm()]:
		page.add_theme_constant_override(&"separation", 8)
		stack.add_child(page)
		_pages.append(page)
	_show_page(PAGE_MENU)


func _build_menu() -> VBoxContainer:
	"""Title, the pause and save lines, and the six buttons."""
	var page := VBoxContainer.new()
	page.add_child(FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true))
	page.add_child(_line(PAUSED_LINE, FarmUi.BODY_PX, Palette.UMBER))
	page.add_child(_line(NO_SAVE_LINE, FarmUi.BODY_PX, Palette.CLAY))
	var actions: Array[Callable] = [close, confirm.bind(CONFIRM_RESTART), _show_page.bind(PAGE_CONTROLS),
		_show_page.bind(PAGE_SETTINGS), open_lab, confirm.bind(CONFIRM_QUIT)]
	for k: int in MENU_BUTTONS.size():
		var button: Button = FarmUi.button(MENU_BUTTONS[k])
		button.tooltip_text = MENU_TIPS[k]
		button.pressed.connect(actions[k])
		page.add_child(button)
		_menu_buttons.append(button)
	return page


func _build_controls() -> VBoxContainer:
	"""The demo's keys, two columns in a scroll, and Back."""
	var page := VBoxContainer.new()
	page.add_child(FarmUi.label("Controls", FarmUi.TITLE_PX, Palette.INK, true))
	_controls_scroll = ScrollContainer.new()
	_controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_controls_scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 4)
	_controls_scroll.add_child(grid)
	for row: Array in DEMO_CONTROLS:
		var key: Label = FarmUi.label(String(row[0]), FarmUi.BODY_PX, Palette.INK, true)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(key)
		var does: Label = FarmUi.label(String(row[1]), FarmUi.BODY_PX, Palette.INK)
		does.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(does)
	page.add_child(_back_button())
	return page


func _build_settings() -> VBoxContainer:
	"""Interface scale, full screen, the sound line, and Back."""
	var page := VBoxContainer.new()
	page.add_child(FarmUi.label("Settings", FarmUi.TITLE_PX, Palette.INK, true))
	page.add_child(FarmUi.label(SCALE_TITLE, FarmUi.BODY_PX, Palette.INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	page.add_child(row)
	for percent: int in UiLayout.USER_SCALES:
		var button: Button = FarmUi.button("%d%%" % percent)
		button.toggle_mode = true
		button.pressed.connect(choose_scale.bind(percent))
		row.add_child(button)
		_scale_buttons.append(button)
	_scale_note = _line("", FarmUi.SMALL_PX, Palette.UMBER)
	page.add_child(_scale_note)
	_fullscreen = FarmUi.button("")
	_fullscreen.pressed.connect(toggle_fullscreen)
	page.add_child(_fullscreen)
	page.add_child(_line(SOUND_LINE, FarmUi.BODY_PX, Palette.UMBER))
	page.add_child(_back_button())
	return page


func _build_confirm() -> VBoxContainer:
	"""The question, the lost-village line, Cancel and the verb."""
	var page := VBoxContainer.new()
	_confirm_title = FarmUi.label("", FarmUi.TITLE_PX, Palette.INK, true)
	page.add_child(_confirm_title)
	page.add_child(_line(CONFIRM_LINE, FarmUi.BODY_PX, Palette.CLAY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	page.add_child(row)
	_confirm_cancel = FarmUi.button("Cancel")
	_confirm_cancel.pressed.connect(_show_page.bind(PAGE_MENU))
	row.add_child(_confirm_cancel)
	_confirm_ok = FarmUi.button("")
	_confirm_ok.pressed.connect(_confirmed)
	row.add_child(_confirm_ok)
	return page


func _line(text: String, px: int, colour: Color) -> Label:
	"""A line wrapping at the frame's inner width from the start, so the frame is as tall as its lines (a
	wrapping label with no width yet asks for a line per word)."""
	var line: Label = FarmUi.label(text, px, colour)
	line.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	return line


func _back_button() -> Button:
	"""A page's Back (to the menu; Esc does the same)."""
	var back: Button = FarmUi.button(BACK_TEXT)
	back.tooltip_text = "Back to the menu (Esc)"
	back.pressed.connect(_show_page.bind(PAGE_MENU))
	return back


# --- opening, closing, pages ------------------------------------------------------------------------

func open() -> void:
	"""Show the menu on its first page and hold the MENU pause reason."""
	if visible:
		return
	_show_page(PAGE_MENU)
	_hold(true)
	visible = true
	_place.call_deferred()


func close() -> bool:
	"""Release the MENU pause reason (the speed comes back as it was) and hide the menu. If the clock
	refuses the release (a load holds its barrier) the menu stays open, so a pause is never left behind
	with no menu to explain it. Returns whether it closed."""
	if not visible:
		return true
	_hold(false)
	if _holding:
		push_warning("the clock refused to release the menu's pause (%s); the menu stays open" % _manager.last_refusal())
		return false
	visible = false
	return true


func toggle() -> void:
	"""Open, or close."""
	if visible:
		close()
	else:
		open()


func back_or_close() -> void:
	"""Esc: a page back to the menu, or, on the menu, close."""
	if _page != PAGE_MENU:
		_show_page(PAGE_MENU)
	else:
		close()


func page() -> int:
	"""The page shown (PAGE_*)."""
	return _page


func is_holding_pause() -> bool:
	"""Whether the menu holds the MENU pause reason now."""
	return _holding


func _hold(held: bool) -> void:
	"""Hold or release MENU once (a refused request leaves the menu's record unchanged)."""
	if held == _holding or _manager == null:
		return
	if _manager.set_menu_pause(held):
		_holding = held


func _show_page(index: int) -> void:
	"""Show one page; with the menu open, focus its first button -- or, back on the menu, the button that
	opened the page -- the keyboard's way when the keyboard turned the page, a click's way otherwise."""
	var keyboard: bool = _keyboard_focus()
	var from: int = _page
	_page = index
	for k: int in _pages.size():
		_pages[k].visible = k == index
	if index == PAGE_SETTINGS:
		_refresh_settings()
	_place.call_deferred()
	if not visible or not is_inside_tree():
		return
	var target: Button = _first_button(index)
	if index == PAGE_MENU and from != PAGE_MENU:
		target = _menu_buttons[RETURN_BUTTON[from] if from != PAGE_CONFIRM or _confirming == CONFIRM_RESTART else BUTTON_QUIT]
	target.grab_focus(not keyboard)


func _keyboard_focus() -> bool:
	"""Whether the keyboard holds the focus now (a drawn focus, not a click's)."""
	if not is_inside_tree():
		return false
	var owner: Control = get_viewport().gui_get_focus_owner()
	return owner != null and owner.has_focus(true)


func _first_button(index: int) -> Button:
	"""The page's first focus: the menu's Resume, a page's Back, the confirmation's Cancel."""
	match index:
		PAGE_CONTROLS:
			return _pages[PAGE_CONTROLS].get_child(_pages[PAGE_CONTROLS].get_child_count() - 1) as Button
		PAGE_SETTINGS:
			return _scale_buttons[0]
		PAGE_CONFIRM:
			return _confirm_cancel
	return _menu_buttons[0]


func confirm(kind: int) -> void:
	"""Ask before Restart or Quit (CONFIRM_*), saying the village will be lost."""
	_confirming = kind
	_confirm_title.text = CONFIRM_TITLES[kind]
	_confirm_ok.text = CONFIRM_VERBS[kind]
	_show_page(PAGE_CONFIRM)


func _confirmed() -> void:
	"""The confirmation's verb: release the pause and hand the host its restart or quit."""
	var action: Callable = on_restart if _confirming == CONFIRM_RESTART else on_quit
	if not close() and _confirming == CONFIRM_RESTART:
		return
	if action.is_valid():
		action.call()


func open_lab() -> void:
	"""Close the menu (its pause with it) and open the Demo Lab."""
	if not close():
		return
	if on_lab.is_valid():
		on_lab.call()


# --- settings ---------------------------------------------------------------------------------------

func choose_scale(percent: int) -> void:
	"""Apply an interface scale through the host (refused sizes do nothing), then repaint the choices."""
	if scale_fits.is_valid() and not bool(scale_fits.call(percent)):
		_refresh_settings()
		return
	scale_percent = percent
	if on_scale.is_valid():
		on_scale.call(percent)
	_refresh_settings()
	_place.call_deferred()


func toggle_fullscreen() -> void:
	"""Full screen on or off (the same as F11)."""
	if on_fullscreen.is_valid():
		on_fullscreen.call()
	_refresh_settings()


func _refresh_settings() -> void:
	"""The chosen scale in brass, sizes the window cannot fit disabled with the reason, full screen's
	state."""
	var refused: PackedStringArray = PackedStringArray()
	for k: int in _scale_buttons.size():
		var percent: int = UiLayout.USER_SCALES[k]
		var fits: bool = not scale_fits.is_valid() or bool(scale_fits.call(percent))
		FarmUi.set_enabled(_scale_buttons[k], fits, SCALE_TOO_SMALL % percent)
		_scale_buttons[k].set_pressed_no_signal(percent == scale_percent)
		if not fits:
			refused.append("%d%%" % percent)
	_scale_note.text = refused_note(refused)
	_scale_note.visible = not refused.is_empty()
	var full: bool = is_fullscreen.is_valid() and bool(is_fullscreen.call())
	_fullscreen.text = FULLSCREEN_TEXT % ("on" if full else "off")


static func refused_note(refused: PackedStringArray) -> String:
	"""'125% needs a larger window', '125% and 150% need a larger window', or '' for none."""
	if refused.is_empty():
		return ""
	if refused.size() == 1:
		return "%s needs a larger window" % refused[0]
	return SCALES_TOO_SMALL % " and ".join(refused)


# --- checks -----------------------------------------------------------------------------------------

func frame() -> PanelContainer:
	"""The carved frame (the gate's focus trap root)."""
	return _frame


func menu_button(k: int) -> Button:
	"""The menu page's button `k` (MENU_BUTTONS order)."""
	return _menu_buttons[k]


func scale_button(k: int) -> Button:
	"""The interface-scale button for UiLayout.USER_SCALES[k]."""
	return _scale_buttons[k]


func confirm_button() -> Button:
	"""The confirmation's verb."""
	return _confirm_ok


func cancel_button() -> Button:
	"""The confirmation's Cancel."""
	return _confirm_cancel


func fullscreen_button() -> Button:
	"""Settings' full-screen toggle."""
	return _fullscreen


func page_text(index: int) -> String:
	"""Every label's text on a page, one per line (checks)."""
	var lines := PackedStringArray()
	_texts(_pages[index], lines)
	return "\n".join(lines)


static func _texts(node: Node, lines: PackedStringArray) -> void:
	"""Depth-first: every Label's and Button's text."""
	for child: Node in node.get_children():
		if child is Label:
			lines.append((child as Label).text)
		elif child is Button:
			lines.append((child as Button).text)
		_texts(child, lines)


# --- placement --------------------------------------------------------------------------------------

func _place() -> void:
	"""Centred in the HUD's modal rectangle at the HUD's scale; the Controls list scrolls in what is left."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(WIDTH, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	_controls_scroll.custom_minimum_size = Vector2(0.0, maxf(120.0, zone.size.y - LIST_RESERVE_H))
	_frame.reset_size()
	var height: float = minf(_frame.get_combined_minimum_size().y, zone.size.y - 2.0 * FarmUi.FRAME_EXPAND)
	var rect := Rect2(zone.position + Vector2((zone.size.x - width) / 2.0, (zone.size.y - height) / 2.0),
		Vector2(width, height))
	FarmUi.place(_frame, rect, _geometry.scale)
