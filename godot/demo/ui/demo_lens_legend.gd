extends VBoxContainer
## One map layer's LEGEND in the Map layer picker (decision 0581): what the colours mean, with units and thresholds.
## DEMO UI in the woodland skin; built once per layer, re-texted when the layer's scale changes (a subject's own
## depths), never rebuilt.
##
##   * the CAPTION -- what the ramp measures, with its units ("Points of moisture from the crop's good range");
##   * the RAMP -- the layer's ordered swatches (map_lenses.gd `ramp_from`, `ramp_count`) as ONE continuous colour bar,
##     each segment with its word under it and its threshold under that ("swim / ≤1.00 m") -- a classic map scale, two
##     text lines high so the picker stays short at 1280x720 (the guide card must still fit above it, decision 0481).
##     The segments flow: where the card is too narrow for all of them (125 %, or long thresholds) the bar continues on
##     a second line rather than widening the card;
##   * the KEYS -- every other swatch as a chip with its word (a clear swatch is words only), flowing in rows.
## OUTLINED (the compared layer's legend): compact -- every entry a chip, no caption or thresholds (the readout gives
## the compared layer's exact value) -- each swatch a hollow square in its colour round an ink core, as the compare
## outlines draw it on the map (demo/lenses/lens_contours.gd).
##
## Swatches are drawn opaque, as the outlines are; on the map an area is that colour at its own alpha. Text is at UI
## §2's 14 px floor.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const LensPalette := preload("res://demo/lenses/lens_palette.gd")
const LensesScript := preload("res://demo/map_lenses.gd")

const NOTE_PX: int = 14
const SWATCH_KEY: float = 14.0
const OUTLINE_PX: int = 3
## The bar's colour strip height and a segment's side padding.
const BAR_H: float = 8.0
const SEGMENT_PAD: int = 5

var lens: int = 0
var outlined: bool = false

var _lenses: LensesScript = null
var _caption: Label = null
var _ticks: Array[Label] = []
## Each swatch's word label, in swatch order.
var _word_labels: Array[Label] = []
var _seen_revision: int = -1
## The swatches, words and ramp it was built for (rebuilt when they change: a layer given its scale later).
var _built_shape: int = -1


func build(lenses: LensesScript, for_lens: int, as_outline: bool) -> void:
	"""Build `for_lens`'s legend from the lenses' rows, filled or outlined."""
	_lenses = lenses
	lens = for_lens
	outlined = as_outline
	add_theme_constant_override(&"separation", 1)
	_fill()
	retext()


func _shape() -> int:
	"""A number for what the legend's nodes depend on: its swatch count and its ramp."""
	return (_lenses.ramp_from_of(lens) * 1000 + _lenses.ramp_count_of(lens)) * 1000 + _lenses.words_of(lens).size()


func _fill() -> void:
	"""The caption, the ramp's rows and the keys' chips."""
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_ticks.clear()
	_built_shape = _shape()
	_seen_revision = -1
	_caption = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_caption)
	var all_words: PackedStringArray = _lenses.words_of(lens)
	_word_labels.resize(all_words.size())
	_add_ramp()
	var keys := HFlowContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override(&"h_separation", 10)
	keys.add_theme_constant_override(&"v_separation", 2)
	add_child(keys)
	for k: int in all_words.size():
		if not _in_ramp(k):
			keys.add_child(_key_chip(k))
	keys.visible = keys.get_child_count() > 0


func _add_ramp() -> void:
	"""The ramp as one bar of segments, flowing onto a second line where the card is too narrow."""
	var bar := HFlowContainer.new()
	bar.name = "Ramp"
	bar.add_theme_constant_override(&"h_separation", 0)
	bar.add_theme_constant_override(&"v_separation", 4)
	for k: int in _lenses.words_of(lens).size():
		if _in_ramp(k):
			bar.add_child(_segment(k))
	if bar.get_child_count() == 0:
		bar.free()
		return
	add_child(bar)


func _segment(k: int) -> VBoxContainer:
	"""A bar segment: its colour (touching its neighbours'), its word under it, its threshold under that."""
	var segment := VBoxContainer.new()
	segment.add_theme_constant_override(&"separation", 0)
	var strip: Control = _swatch(k, Vector2(0.0, BAR_H))
	strip.size_flags_horizontal = Control.SIZE_FILL
	segment.add_child(strip)
	var word: Label = _word(k)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	segment.add_child(_padded(word))
	var tick: Label = FarmUi.label(_tick_text(_ticks.size()), NOTE_PX, Palette.UMBER)
	tick.autowrap_mode = TextServer.AUTOWRAP_OFF
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	segment.add_child(_padded(tick))
	_ticks.append(tick)
	return segment


static func _padded(label: Label) -> MarginContainer:
	"""`label` with SEGMENT_PAD either side, so neighbouring words keep apart."""
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", SEGMENT_PAD)
	margin.add_theme_constant_override(&"margin_right", SEGMENT_PAD)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	return margin


func _tick_text(k: int) -> String:
	"""The layer's threshold for ramp entry `k` ('' past its ticks)."""
	var lines: PackedStringArray = _lenses.ticks_of(lens)
	return lines[k] if k < lines.size() else ""


func _in_ramp(k: int) -> bool:
	"""Whether swatch `k` is drawn on the layer's ramp (never in the compact outlined legend)."""
	if outlined:
		return false
	var from: int = _lenses.ramp_from_of(lens)
	return k >= from and k < from + _lenses.ramp_count_of(lens)


func _key_chip(k: int) -> HBoxContainer:
	"""A key: its swatch (none for a clear one) and its word."""
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override(&"separation", 4)
	if _lenses.swatches_of(lens)[k].a > 0.0:
		var swatch: Control = _swatch(k, Vector2(SWATCH_KEY, SWATCH_KEY))
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(swatch)
	chip.add_child(_word(k))
	return chip


func _word(k: int) -> Label:
	"""Swatch `k`'s word, one line."""
	var word: Label = FarmUi.label(_lenses.words_of(lens)[k], NOTE_PX, Palette.INK)
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	_word_labels[k] = word
	return word


func _swatch(k: int, at_least: Vector2) -> Control:
	"""Swatch `k` at full strength: filled, or a hollow square round an ink core when outlined."""
	var colour := Color(_lenses.swatches_of(lens)[k], 1.0)
	var box := StyleBoxFlat.new()
	box.bg_color = LensPalette.OUTLINE_INK if outlined else colour
	if outlined:
		box.set_border_width_all(OUTLINE_PX)
		box.border_color = colour
	var swatch := Panel.new()
	swatch.add_theme_stylebox_override(&"panel", box)
	swatch.custom_minimum_size = at_least
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return swatch


func retext() -> void:
	"""The caption and the thresholds, from the layer's scale as it is now (only when the lenses changed)."""
	if _lenses.revision == _seen_revision:
		return
	if _shape() != _built_shape:
		_fill()
	_seen_revision = _lenses.revision
	var caption: String = "" if outlined else _lenses.caption_of(lens)
	if _caption.text != caption:
		_caption.text = caption
	_caption.visible = not caption.is_empty()
	var lines: PackedStringArray = _lenses.ticks_of(lens)
	for k: int in _ticks.size():
		var line: String = lines[k] if k < lines.size() else ""
		if _ticks[k].text != line:
			_ticks[k].text = line


# --- readouts ------------------------------------------------------------------------------------------

func words() -> PackedStringArray:
	"""The legend's words as drawn, in swatch order."""
	var out := PackedStringArray()
	for word: Label in _word_labels:
		out.append(word.text)
	return out


func ticks() -> PackedStringArray:
	"""The ramp's threshold lines as drawn."""
	var out := PackedStringArray()
	for tick: Label in _ticks:
		out.append(tick.text)
	return out


func caption_text() -> String:
	"""The caption as drawn ('' when hidden)."""
	return _caption.text if _caption.visible else ""


func ramp_rows() -> int:
	"""How many entries the ramp's bar draws."""
	return _ticks.size()


func is_bar() -> bool:
	"""Whether the layer has a ramp bar."""
	return has_node(^"Ramp")
