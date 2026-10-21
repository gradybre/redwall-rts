extends Panel
## UI-BUILD-015, THE CONFIRMED ROOM'S CARD (docs/ui_ux_controls.md; decision 1991, Brendan's rulings P-1990-4 (a) and
## P-1990-5 (a)): opened by a click on a confirmed room with no card armed. It names the room and its level, says how
## far it is dug and who digs it, and offers UI-BUILD-016 "Stop digging" -- the crew walks out, what is dug stays dug,
## and the cells still waiting go back to the plan as pending cells -- and Close. While the demo digs with decision
## 1912's mole it also says so ("Proof of concept: free ...").
##
##   +--------------------------------------+
##   | Kitchen, Underground level 1         |
##   | 10 of 24 cells dug                   |
##   | Crew: Bramble, Teasel                |   (scrolls when the words outgrow it: never cut short)
##   | Proof of concept: free ...           |
##   | [ Stop digging             ] [Close] |
##   +--------------------------------------+
##
## Placed by build_layout.gd `connector_rect`, the connector card's place (the two are never open together).
## Game UI: it only says what was pressed (`stop_pressed`, `close_pressed`); the host acts.

const PAD: float = 8.0
const ROW: float = 32.0
const CLOSE_WIDTH: float = 84.0
const TITLE_PX: int = 16
const TEXT_PX: int = 14
const STOP: String = "Stop digging"
const NOTHING_TO_STOP: String = "Nothing left to dig: every cell of this room is dug"
## Decision 1991: what the room is doing, and the button's words and reason for each.
const STATE_DIGGING: int = 0
const STATE_STOPPED: int = 1
const STATE_DUG: int = 2
const BUTTON_WORDS: Array[String] = ["Stop digging", "Stopped", "Dug"]
const STOPPED_REASON: String = "Stopped: what is left is back in the plan; Confirm all orders it again"
const ACCESSIBLE: String = "Room card: %s; %s"
const STOP_ACCESSIBLE: String = "Stop digging %s: the crew walks out, dug cells stay, the rest goes back to the plan"

signal stop_pressed
signal close_pressed

var _title: Label = null
var _scroll: ScrollContainer = null
var _words: Label = null
var _stop: Button = null
var _close: Button = null


func _init() -> void:
	"""Named and hidden until a confirmed room is clicked."""
	name = "UI-BUILD-015"
	visible = false
	theme_type_variation = &"WoodlandPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	"""Every control (also off-tree, for checks)."""
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", TITLE_PX)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_theme_font_size_override(&"font_size", TEXT_PX)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_words)
	_stop = _new_button(STOP, stop_pressed.emit)
	_stop.name = "UI-BUILD-016"
	_close = _new_button("Close", close_pressed.emit)


func _new_button(text: String, pressed: Callable) -> Button:
	"""A focusable WoodlandButton on the card, its text at the 14 px floor."""
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = &"WoodlandButton"
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override(&"font_size", TEXT_PX)
	button.pressed.connect(pressed)
	add_child(button)
	return button


func place_in(rect: Rect2) -> void:
	"""Lay the card out in `rect` (logical px, the panel's frame of reference)."""
	position = rect.position
	size = rect.size
	var inner: float = rect.size.x - 2.0 * PAD
	_title.position = Vector2(PAD, PAD)
	_title.size = Vector2(inner, ROW)
	var foot: float = rect.size.y - PAD - ROW
	_scroll.position = Vector2(PAD, PAD + ROW + 4.0)
	_scroll.size = Vector2(inner, maxf(foot - 4.0 - _scroll.position.y, 0.0))
	_words.custom_minimum_size.x = inner - 12.0
	_stop.position = Vector2(PAD, foot)
	_stop.size = Vector2(inner - CLOSE_WIDTH - 4.0, ROW)
	_close.position = Vector2(rect.size.x - PAD - CLOSE_WIDTH, foot)
	_close.size = Vector2(CLOSE_WIDTH, ROW)


func show_room(room_name: String, text: String, state: int) -> void:
	"""Show a confirmed room: its name and level, its words (dug so far, the crew, the proof of concept's note), and
	UI-BUILD-016: "Stop digging" while cells of it still wait (STATE_DIGGING); disabled, saying "Stopped" or "Dug" with
	its reason, otherwise."""
	_title.text = room_name
	_words.text = text
	var can_stop: bool = state == STATE_DIGGING
	_stop.disabled = not can_stop
	_stop.text = BUTTON_WORDS[clampi(state, 0, BUTTON_WORDS.size() - 1)]
	_stop.tooltip_text = STOP_ACCESSIBLE % room_name if can_stop \
		else (STOPPED_REASON if state == STATE_STOPPED else NOTHING_TO_STOP)
	_stop.accessibility_name = _stop.tooltip_text
	accessibility_name = ACCESSIBLE % [room_name, text.get_slice("\n", 0)]
	visible = true


func words() -> String:
	"""What the card says under its title (checks)."""
	return _words.text


func title() -> String:
	"""The room named (checks)."""
	return _title.text


func stop_button() -> Button:
	"""UI-BUILD-016, Stop digging."""
	return _stop


func close_button() -> Button:
	"""Close."""
	return _close
