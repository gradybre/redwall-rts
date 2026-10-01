extends CanvasLayer
## THE CAMERA STRIP: one line saying what the camera is doing when it is not simply the player's (decision 0801) --
## "Following Wenna Tallowby · End or a pan stops", "Orbiting the hall · Esc stops", "Cutaway angle · Shift+U: your
## view back" -- and, for a moment, what a bookmark key did ("View 2 saved · Shift+2 returns here"). DEMO UI.
##
## It is the U view's level indicator's twin (tunnel_view.gd THE LEVELS): the same dark strip and words, in the
## top-centre column under the HUD's alert zone, pause label and error panel at the HUD's scale, on the same canvas
## layer under the HUD's (so the open history or a grown error panel covers it, never the other way) -- and under
## whatever else stands in that column now (`below`: the level indicator, the guide's or an incident's card, the pause
## card), so it is never drawn behind them. It takes no pointer. A MODE line stays while its mode lasts; a
## FLASH line shows for FLASH_SECONDS of real time, then the mode's line (or nothing) comes back; a mode starting
## replaces a flash still up.

const TunnelView := preload("res://demo/tunnel/tunnel_view.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

const FLASH_SECONDS: float = 2.5
## The gap between the level indicator and this strip, logical px.
const STACK_GAP: float = 6.0

## `below() -> Rect2`: the lowest thing already shown in the column (the level indicator, a top card, the pause card),
## in viewport pixels; empty when nothing is.
var below: Callable = Callable()

var _box: PanelContainer = null
var _label: Label = null
var _mode_text: String = ""
var _flash_text: String = ""
var _flash_left: float = 0.0
var _layout := UiLayout.new()
var _geometry := UiLayout.Geometry.new()
var _gap: float = TunnelView.indicator_gap_px()
## What the strip was last placed for: redone only when one of them changes.
var _dirty: bool = true
var _placed_size: Vector2 = Vector2.ZERO
var _placed_above: float = -1.0
var _placed_percent: int = -1


func _init() -> void:
	"""The strip, hidden until there is something to say."""
	name = "CameraStrip"
	layer = TunnelView.INDICATOR_LAYER
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = TunnelView.INDICATOR_BACK
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	_box.add_theme_stylebox_override(&"panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", TunnelView.INDICATOR_FONT_PX)
	_label.add_theme_color_override(&"font_color", TunnelView.INDICATOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)
	add_child(_box)
	_box.visible = false


func set_mode_text(words: String) -> void:
	"""The line a mode keeps up while it lasts ("" when no mode is on). A mode starting takes the strip from a flash
	still up (a mode ending leaves the flash that says so)."""
	if words == _mode_text:
		return
	_mode_text = words
	if not words.is_empty():
		_flash_text = ""
		_flash_left = 0.0
	_show()


func flash(words: String) -> void:
	"""Say `words` for FLASH_SECONDS, over the mode's line."""
	_flash_text = words
	_flash_left = FLASH_SECONDS
	_show()


func _process(delta: float) -> void:
	"""Count the flash down (real time), and keep the strip placed."""
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_text = ""
			_show()
	if _box.visible and is_inside_tree():
		place_for(get_viewport().get_visible_rect().size)


func _show() -> void:
	"""The flash if one is up, else the mode's line; hidden when both are empty."""
	var words: String = _flash_text if not _flash_text.is_empty() else _mode_text
	_box.visible = not words.is_empty()
	if _label.text != words:
		_label.text = words
		_dirty = true


func place_for(size_px: Vector2) -> void:
	"""Centre the strip under the alert zone (and under the level indicator while it shows), at the HUD's scale.
	Only redone when the window, the scale or the strip above changed."""
	var above: Rect2 = below.call() if below.is_valid() else Rect2()
	var above_end: float = above.end.y if above.has_area() else 0.0
	if not _dirty and size_px == _placed_size and above_end == _placed_above and DemoUiScale.percent == _placed_percent:
		return
	_dirty = false
	_placed_size = size_px
	_placed_above = above_end
	_placed_percent = DemoUiScale.percent
	if not _layout.compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), DemoUiScale.percent, false, _geometry):
		_geometry.scale = 1.0
	var s: float = _geometry.scale
	var width: float = _box.get_combined_minimum_size().x
	_box.size = Vector2(width, 0.0)
	_box.scale = Vector2(s, s)
	var alerts: Rect2 = _geometry.alerts
	var top: float = (alerts.end.y + _gap) * s
	if above_end > 0.0:
		top = maxf(top, above_end + STACK_GAP * s)
	_box.position = Vector2((alerts.position.x + (alerts.size.x - width) / 2.0) * s, top)


func text() -> String:
	"""What the strip says now ("" while hidden)."""
	return _label.text if _box.visible else ""


func shown() -> bool:
	"""Whether the strip is shown."""
	return _box.visible


func rect() -> Rect2:
	"""Where the strip stands on the screen, scaled (checks)."""
	return Rect2(_box.position, _box.size * _box.scale)
