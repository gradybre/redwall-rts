extends Control
## The bed panel's moisture meter: a banded bar under "Soil moisture: Good · 66%". Decision 0251 (review group E,
## finding F34). Presentation only.
##
## THE BAR is the 0..100% moisture scale, split where the farm's bands change (farm_sim.gd `band_of`): dry, low,
## good -- the crop's suitable range, drawn full height -- wet and waterlogged, each its own colour; a tick and a
## label (14 px, UI §2.1's floor) at each end of the suitable range; an ink marker at the reading. The words beside
## it (the band's name, the percentage and the range) carry the meaning: colour only repeats it (MOVE-REQ-018's
## rule, text before colour).
##
## Drawn only when the reading or its range changed (`show_reading`); nothing is made per frame.

const Palette := preload("res://demo/ui/woodland_palette.gd")

const BAR_PX: float = 10.0
const LABEL_PX: int = 14
const HEIGHT_PX: float = 30.0
const MARKER_PX: float = 3.0
const SCALE: int = 10000
## The five bands' colours, dry to waterlogged (farm_sim.gd BAND_*).
const BAND_COLOURS: Array[Color] = [Palette.CLAY, Palette.EMBER, Palette.LEAF, Palette.SAGE, Color("#4F6E8F")]

var moisture: int = 0
var band_min: int = 0
var band_max: int = SCALE
var margin: int = 0


func _init() -> void:
	"""A full-width strip of the panel's column."""
	custom_minimum_size = Vector2(0.0, HEIGHT_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_reading(reading: int, low: int, high: int, near_margin: int) -> bool:
	"""Show `reading` against the range `low`..`high` (0..10000) with bands `near_margin` either side; redraws
	only on a change. True when it changed."""
	if reading == moisture and low == band_min and high == band_max and near_margin == margin:
		return false
	moisture = reading
	band_min = low
	band_max = high
	margin = near_margin
	queue_redraw()
	return true


static func band_edges(low: int, high: int, near_margin: int) -> PackedInt32Array:
	"""The six edges of the five bands on the 0..10000 scale, each held inside it: 0, dry|low, low|good,
	good|wet, wet|waterlogged, 10000."""
	return PackedInt32Array([0, clampi(low - near_margin, 0, SCALE), clampi(low, 0, SCALE), clampi(high, 0, SCALE),
		clampi(high + near_margin, 0, SCALE), SCALE])


static func x_of(value: int, width: float) -> float:
	"""Where a 0..10000 value sits along a bar `width` px wide."""
	return float(clampi(value, 0, SCALE)) / float(SCALE) * width


func _draw() -> void:
	"""The bands, the range's ticks and labels, and the marker (see THE BAR)."""
	var edges: PackedInt32Array = band_edges(band_min, band_max, margin)
	for k: int in BAND_COLOURS.size():
		var left: float = x_of(edges[k], size.x)
		var inset: float = 0.0 if k == 2 else BAR_PX * 0.25
		draw_rect(Rect2(left, inset, x_of(edges[k + 1], size.x) - left, BAR_PX - 2.0 * inset), BAND_COLOURS[k])
	var font: Font = get_theme_default_font()
	for edge: int in [band_min, band_max]:
		var x: float = x_of(edge, size.x)
		draw_line(Vector2(x, 0.0), Vector2(x, BAR_PX + 3.0), Palette.INK, 1.0)
		var words: String = "%d%%" % (edge / 100)
		var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_PX).x
		var at_x: float = clampf(x - width * 0.5, 0.0, maxf(size.x - width, 0.0))
		draw_string(font, Vector2(at_x, HEIGHT_PX - 2.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_PX, Palette.UMBER)
	var mark: float = x_of(moisture, size.x)
	draw_rect(Rect2(mark - MARKER_PX * 0.5, -2.0, MARKER_PX, BAR_PX + 4.0), Palette.INK)
