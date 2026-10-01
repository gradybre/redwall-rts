extends CanvasLayer
## The map layer's HOVER READOUT (decision 0581): the exact value under the pointer for the shown layer -- "Soil
## moisture 62% · good" with the bed's own thresholds, "Water 0.42 m deep · swim" with the painted body's -- and, while
## a second layer is compared, what that one says there too. DEMO UI in the woodland skin; it shows words and nothing
## else. Its words come from the layers' probes (demo/lenses/), chosen and throttled by demo/lenses/demo_lens_kit.gd.
##
## WHERE. Beside the pointer (OFFSET_PX below and right of it), kept inside the window: flipped to the pointer's left
## or above it near an edge. It takes no input (UI §3: a tooltip-like layer that ignores the mouse) and is hidden while
## the pointer is over any panel, so it never covers a control the player is using. It draws on the parchment of the
## demo's tooltips (woodland_styles.gd PIECE_MAP, the theme's TooltipPanel), ink on parchment, at the HUD's scale.
##
## MOTION (UI §2.2 OVERLAY profile, UI §2.1 REQ-UX-008). It fades in over FADE_S (80 ms), and out as fast -- or, with
## reduced motion on (demo_access.gd SET_MOTION), appears and goes at once. Following the pointer is the player's own
## movement, not an animation. Text is set only when the kit hands new words; placing it allocates nothing.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Access := preload("res://demo/access/demo_access.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

## From the pointer to the readout's corner, logical px; its text sizes (UI §2: 14 px floor).
const OFFSET_PX: Vector2 = Vector2(18.0, 20.0)
const MAIN_PX: int = 15
const SECOND_PX: int = 14
const MARGINS: PackedFloat32Array = [12.0, 8.0, 12.0, 9.0]
## UI §2.2 OVERLAY: an 80 ms fade unless reduced motion.
const FADE_S: float = 0.08

var _panel: PanelContainer = null
var _main: Label = null
var _second: Label = null
var _target: float = 0.0


func _init() -> void:
	"""The parchment card and its two lines, hidden."""
	name = "DemoLensReadout"
	layer = 0
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_MAP, MARGINS))
	_panel.visible = false
	_panel.modulate.a = 0.0
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 3)
	_panel.add_child(column)
	_main = _line(MAIN_PX, Palette.INK)
	column.add_child(_main)
	_second = _line(SECOND_PX, Palette.UMBER)
	column.add_child(_second)


static func _line(px: int, colour: Color) -> Label:
	"""One of the readout's text blocks: unwrapped lines (the words carry their own breaks)."""
	var line: Label = FarmUi.label("", px, colour)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	return line


func set_words(main: String, second: String) -> void:
	"""What the shown layer says under the pointer, and the compared one's ('' for none). Re-texted only on a change."""
	if _main.text != main:
		_main.text = main
	if _second.text != second:
		_second.text = second
	_main.visible = not main.is_empty()
	_second.visible = not second.is_empty()
	_panel.reset_size()
	show_again()


func show_again() -> void:
	"""Show the words it has (the pointer is back over the same thing)."""
	_target = 1.0
	_panel.visible = true


func hide_readout() -> void:
	"""Nothing to say here: fade out (at once with reduced motion)."""
	_target = 0.0


func place(pointer: Vector2, viewport_size: Vector2) -> void:
	"""Beside the pointer, inside the window, at the HUD's scale."""
	var s: float = DemoUiScale.effective_scale(viewport_size)
	_panel.scale = Vector2(s, s)
	var extent: Vector2 = _panel.size * s
	var at: Vector2 = pointer + OFFSET_PX * s
	if at.x + extent.x > viewport_size.x:
		at.x = pointer.x - OFFSET_PX.x * s - extent.x
	if at.y + extent.y > viewport_size.y:
		at.y = pointer.y - OFFSET_PX.y * s - extent.y
	_panel.position = Vector2(maxf(at.x, 0.0), maxf(at.y, 0.0))


func _process(delta: float) -> void:
	"""The fade toward shown or hidden (instant with reduced motion)."""
	var alpha: float = _panel.modulate.a
	if is_equal_approx(alpha, _target):
		return
	alpha = _target if Access.is_on(Access.SET_MOTION) else move_toward(alpha, _target, delta / FADE_S)
	_panel.modulate.a = alpha
	_panel.visible = alpha > 0.0


# --- readouts (tests and the scripted check) ----------------------------------------------------------

func shown() -> bool:
	"""Whether the readout is meant to show (it may still be fading in)."""
	return _target > 0.0


func main_text() -> String:
	"""The shown layer's words ('' when none)."""
	return _main.text if _main.visible else ""


func second_text() -> String:
	"""The compared layer's words ('' when none)."""
	return _second.text if _second.visible else ""


func second_line_shown() -> bool:
	"""Whether the compared layer's line takes room."""
	return _second.visible


func panel_rect() -> Rect2:
	"""The card on screen, viewport px."""
	return Rect2(_panel.position, _panel.size * _panel.scale)


func opacity() -> float:
	"""The card's alpha now."""
	return _panel.modulate.a
