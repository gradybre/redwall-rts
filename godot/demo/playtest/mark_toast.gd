extends CanvasLayer
## The mark's TOAST: "Marked #2 in the playtest log" for SHOW_USEC after F12 or Settings' Mark, so the tester
## knows it took (decision 0562). DEMO UI in the woodland skin, above the stall banner (LAYER). It takes no input.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const LAYER: int = 4
const SHOW_USEC: int = 3000000
const TEXT: String = "Marked #%d in the playtest log -- thank you. Carry on, or describe it when you send the log."
## The toast's top edge, as a share of the viewport's height (under the top-centre cards).
const TOP_SHARE: float = 0.16

var _frame: PanelContainer = null
var _label: Label = null
var _hide_at_usec: int = 0


func _init() -> void:
	"""Built hidden."""
	name = "PlaytestMarkToast"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_label)


func show_mark(number: int, now_usec: int) -> void:
	"""Show mark `number` until SHOW_USEC after `now_usec`."""
	_label.text = TEXT % number
	_hide_at_usec = now_usec + SHOW_USEC
	visible = true
	_place.call_deferred()


func tick(now_usec: int) -> void:
	"""Hide once its time is up (an int comparison a frame)."""
	if visible and now_usec >= _hide_at_usec:
		visible = false


func text() -> String:
	"""What it says (checks)."""
	return _label.text


func _place() -> void:
	"""Centred across the viewport at TOP_SHARE of its height."""
	if not is_inside_tree():
		return
	_frame.reset_size()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var size_px: Vector2 = _frame.get_combined_minimum_size()
	_frame.position = Vector2(maxf(0.0, (view.x - size_px.x) / 2.0), view.y * TOP_SHARE)
