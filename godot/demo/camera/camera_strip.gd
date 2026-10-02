extends CanvasLayer
## THE CAMERA STRIP: one line saying what the camera is doing when it is not simply the player's (decision 0801) --
## "Following Wenna Tallowby · End or a pan stops", "Orbiting the hall · Esc stops", "Cutaway angle · Shift+U: your
## view back" -- and, for a moment, what a bookmark key did ("View 2 saved · Shift+2 returns here"). DEMO UI.
##
## WHERE (decision 0801, Brendan's ruling on P5): the U view's level indicator's dark strip and words, at the HUD's
## scale, in its OWN ROW at the bottom centre -- just above the command strip, centred on the village news' band
## (demo_news_strip.gd `band_placement`, which follows the commands when the journal moves them) and held between the
## minimap and the right column. The village news stands ON TOP of that row while the strip shows (`reserved_height`,
## read by the news' `lift`), so the news never covers it in the surface view or the U view, at any size. The
## top-centre column (the guide's and incident cards, the pause card, the level indicator, the Map layer picker at
## 1280x720) is left alone. On canvas layer 0, under the HUD's panels; it takes no pointer. A MODE line stays while
## its mode lasts; a FLASH line shows for FLASH_SECONDS of real time, then the mode's line (or nothing) comes back; a
## mode starting replaces a flash still up.

const TunnelView := preload("res://demo/tunnel/tunnel_view.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const NewsStrip := preload("res://demo/ui/demo_news_strip.gd")

const FLASH_SECONDS: float = 2.5
## The gap between the strip and what is under it (the command strip) and over it (the news), logical px.
const STACK_GAP: float = 6.0

## `journal_open() -> bool`: whether the resident journal holds the right column (the commands move left then).
var journal_open: Callable = Callable()

var _box: PanelContainer = null
var _label: Label = null
var _mode_text: String = ""
var _flash_text: String = ""
var _flash_left: float = 0.0
var _layout := UiLayout.new()
var _geometry := UiLayout.Geometry.new()
## What the strip was last placed for: redone only when one of them changes.
var _dirty: bool = true
var _placed_size: Vector2 = Vector2.ZERO
var _placed_journal: bool = false
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
	"""Stand the strip just above the command strip, centred on the news' band and held inside the gap between the
	minimap and the right column, at the HUD's scale (see WHERE). Only redone when the window, the scale, the journal or
	the words changed."""
	var journal: bool = journal_open.is_valid() and bool(journal_open.call())
	if not _dirty and size_px == _placed_size and journal == _placed_journal and DemoUiScale.percent == _placed_percent:
		return
	_dirty = false
	_placed_size = size_px
	_placed_journal = journal
	_placed_percent = DemoUiScale.percent
	var band: Rect2 = NewsStrip.band_placement(int(size_px.x), int(size_px.y), _layout, _geometry, journal)
	var s: float = _geometry.scale
	var low: float = _geometry.minimap.end.x + STACK_GAP
	var high: float = _geometry.detail.position.x - STACK_GAP
	var width: float = _fitted_width(high - low)
	_box.size = Vector2(width, 0.0)
	_box.scale = Vector2(s, s)
	var x: float = row_left(band.get_center().x, width, low, high)
	_box.position = Vector2(x, _geometry.commands.position.y - STACK_GAP - _box.get_combined_minimum_size().y) * s


func _fitted_width(room: float) -> float:
	"""The strip's width: its words' own, or -- wider than `room` (the gap between the minimap and the right column) --
	`room`, the words cut with an ellipsis."""
	_cut(false)
	var natural: float = _box.get_combined_minimum_size().x
	var width: float = width_for(natural, room)
	if width < natural:
		_cut(true)
	return width


static func width_for(natural: float, room: float) -> float:
	"""A strip's width: its words' own `natural` width, or `room` where they are wider (logical px)."""
	return minf(natural, maxf(room, 0.0))


func _cut(on: bool) -> void:
	"""Cut the words with an ellipsis (`on`) or show them whole, and have the strip measure itself again (in the tree:
	off it Godot keeps a control's first measure)."""
	_label.clip_text = on
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if on else TextServer.OVERRUN_NO_TRIMMING
	_label.update_minimum_size()
	_box.update_minimum_size()


static func row_left(centre: float, width: float, low: float, high: float) -> float:
	"""The strip's left edge: centred on `centre`, moved in to stay between `low` and `high` where it fits (logical
	px; a strip wider than the gap starts at `low`)."""
	return maxf(low, minf(centre - width / 2.0, high - width))


func clipped() -> bool:
	"""Whether the words are cut to fit the gap (checks)."""
	return _label.clip_text


func reserved_height() -> float:
	"""How much of the bottom-centre column the strip keeps for itself above the commands (logical px, its gap
	included): its height while shown, 0 while hidden. The village news stands on top of it (`lift`)."""
	return _box.get_combined_minimum_size().y + STACK_GAP if _box.visible else 0.0


func text() -> String:
	"""What the strip says now ("" while hidden)."""
	return _label.text if _box.visible else ""


func shown() -> bool:
	"""Whether the strip is shown."""
	return _box.visible


func rect() -> Rect2:
	"""Where the strip stands on the screen, scaled (checks)."""
	return Rect2(_box.position, _box.size * _box.scale)
