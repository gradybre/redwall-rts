extends RefCounted
## The guide's few widgets in the woodland skin (decision 0481), beside farm_ui.gd's frame, label and button: a text
## field (the help and field-guide search, a project's name), a wrapped line of a fixed width, a section heading and
## a scrolling column. DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const FIELD_MARGINS: PackedFloat32Array = [10.0, 6.0, 10.0, 6.0]


static func field(placeholder: String, max_chars: int = 0) -> LineEdit:
	"""A text field on the parchment's field piece, ink text, with the HUD's focus ring."""
	var made := LineEdit.new()
	made.placeholder_text = placeholder
	made.max_length = max_chars
	made.custom_minimum_size.y = FarmUi.BUTTON_H
	made.clear_button_enabled = true
	Styles.focusable(made, FIELD_MARGINS)
	made.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_FIELD, FIELD_MARGINS))
	made.add_theme_stylebox_override(&"read_only", Styles.box(Styles.PIECE_FIELD, FIELD_MARGINS))
	made.add_theme_font_size_override(&"font_size", FarmUi.BODY_PX)
	made.add_theme_color_override(&"font_color", Palette.INK)
	made.add_theme_color_override(&"font_placeholder_color", Palette.UMBER)
	made.add_theme_color_override(&"caret_color", Palette.INK)
	return made


static func line(text: String, px: int, colour: Color, width: float, heading: bool = false) -> Label:
	"""A line wrapping at `width` from the start, so its container is as tall as its lines (a wrapping label with no
	width yet asks for a line per word)."""
	var made: Label = FarmUi.label(text, px, colour, heading)
	made.custom_minimum_size.x = width
	return made


static func scroll_column(separation: int = 6) -> Array:
	"""A vertical scroll (no sideways scroll) and the column inside it: [ScrollContainer, VBoxContainer]."""
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", separation)
	scroll.add_child(column)
	return [scroll, column]


static func clear(container: Node) -> void:
	"""Free every child of `container` now (a list redrawn)."""
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func row(separation: int = 8) -> HFlowContainer:
	"""A row of buttons that wraps to the next line rather than overflowing its frame."""
	var made := HFlowContainer.new()
	made.add_theme_constant_override(&"h_separation", separation)
	made.add_theme_constant_override(&"v_separation", 6)
	return made


static func focus_later(control: Control) -> void:
	"""Give `control` the focus once the frame's layout has settled -- if it is still there and in the tree by then
	(held weakly: a page freed meanwhile is simply skipped)."""
	var held: WeakRef = weakref(control)
	var take: Callable = func() -> void:
		var target := held.get_ref() as Control
		if target != null and target.is_inside_tree() and target.is_visible_in_tree():
			target.grab_focus()
	take.call_deferred()
