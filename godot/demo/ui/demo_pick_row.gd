extends RefCounted
## A LIST ROW THAT SELECTS ITS SUBJECT: one resident (or anything else a panel lists) as a flat, full-width row
## button -- a colour chip, one line of text cut with an ellipsis where the column is too narrow, the whole text
## in its tooltip -- that the panel connects to "select it and centre the camera on it". Decision 0391 (review
## group F: F20's member list, F12's "All residents"). DEMO UI.
##
## Rows are at least ROW_H logical px tall (UI §2.3's 32x32 interactive floor, UX-T03) and their text is at least
## UI §2.1's 14 px. They take keyboard focus with the HUD's ring (decision 0261), so F7 and Tab reach them.

const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## UI §2.3 / UX-T03: every interactive control at least 32 x 32 logical px.
const ROW_H: float = 32.0
const CHIP_PX: float = 12.0
## Room on the left for the chip (its width and a gap), then the text.
const MARGINS: PackedFloat32Array = [26.0, 4.0, 8.0, 4.0]
const CHIP_X: float = 8.0
const HOVER_ALPHA: float = 0.10
const PRESSED_ALPHA: float = 0.18


static func make(text: String, chip: Color, px: int, colour: Color) -> Button:
	"""A row reading `text` (ellipsis-cut, whole in its tooltip) with a `chip` swatch (none when transparent)."""
	var row := Button.new()
	row.text = text
	row.tooltip_text = text
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.custom_minimum_size.y = ROW_H
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_font_size_override(&"font_size", px)
	Styles.focusable(row, MARGINS)
	row.add_theme_stylebox_override(&"normal", Styles.clear(MARGINS))
	row.add_theme_stylebox_override(&"hover", Styles.wash(HOVER_ALPHA, MARGINS))
	row.add_theme_stylebox_override(&"pressed", Styles.wash(PRESSED_ALPHA, MARGINS))
	row.add_theme_stylebox_override(&"hover_pressed", Styles.wash(PRESSED_ALPHA, MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
			&"font_hover_pressed_color"]:
		row.add_theme_color_override(item, colour)
	if chip.a > 0.0:
		row.add_child(_chip(chip))
	return row


static func _chip(colour: Color) -> ColorRect:
	"""The row's swatch, centred on its left margin; it never takes the mouse."""
	var swatch := ColorRect.new()
	swatch.name = "Chip"
	swatch.color = colour
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.size = Vector2(CHIP_PX, CHIP_PX)
	swatch.anchor_top = 0.5
	swatch.anchor_bottom = 0.5
	swatch.offset_left = CHIP_X
	swatch.offset_right = CHIP_X + CHIP_PX
	swatch.offset_top = -CHIP_PX / 2.0
	swatch.offset_bottom = CHIP_PX / 2.0
	return swatch


static func set_chip(row: Button, colour: Color) -> void:
	"""Re-colour a row's chip (a row made without one has none to colour)."""
	var swatch := row.get_node_or_null(^"Chip") as ColorRect
	if swatch != null and swatch.color != colour:
		swatch.color = colour


static func set_text(row: Button, text: String) -> void:
	"""Re-word a row (and its tooltip) only when the words changed, so a tooltip showing is left alone."""
	if row.text != text:
		row.text = text
		row.tooltip_text = text
