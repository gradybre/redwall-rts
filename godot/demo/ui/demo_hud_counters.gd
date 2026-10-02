extends RefCounted
## THE DEMO'S TOP BAR: the six counter cells and the ledger they open, painted from the demo's read model
## (demo_hud_model.gd). Decision 0251 (review group E, F10); it replaces decision 0211's "Sim beds" relabel and
## the farm's Food-cell painter. Presentation only: nothing here writes into the simulation, UIManager or the
## shell's contracts -- it paints the shell's cells, as the demo's other HUD adapters do.
##
## HOW EACH CELL IS PAINTED.
##   * Food, Wood, Stone, Residents -- counters the shell WIRES -- go through the shell's own public entry point,
##     `set_counter_display()`, which measures the value and draws "See ledger" when it cannot fit (UI-C3-R01 §2).
##   * Heating fuel and Beds are counters the shell does NOT wire in the game: there, no store exists, and the shell
##     refuses a value by contract. In the demo the owners DO exist -- the winter's fuel-days (decision 0571; it restores
##     UI-SET-003 over decision 0251's Planks), the homes' installed beds -- so the demo paints those two cells itself:
##     caption, a line glyph in place of
##     the lock, the value in the shell's own value role (or "See ledger" when it does not measure inside the
##     cell, the shell's own rule), the cell enabled so it opens the ledger like the others. The shell's table
##     (ui_availability.gd) is untouched: the game's claim stays true for the game.
##   * Heating fuel's no-demand STATE ("No demand") is words, not a figure: drawn in the 16 px disclosure role, as
##     "Unavailable" is, so it fits the narrow cell (decision 0571).
##   * Heating fuel's WARNING state (demo_hud_model.gd `is_warning`: under 2 days) draws its value in clay with the
##     shell's warning glyph in place of the fuel one (UI §7's fuel warning).
##   * A figure whose owner is absent (demo_hud_model.gd UNAVAILABLE IS NOT ZERO) is drawn "Unavailable" in the
##     shell's 16 px disclosure role, as the shell draws its own unavailable cells -- never as a 0.
##   * Every cell's tooltip and accessible description is the model's: the figure and where it is.
##   * The ledger (UI-SET-009, opened by any cell) is the model's: the same six figures, each saying whose it is.
##
## REPAINTING. UIManager repaints the wired cells and the ledger with the settlement's figures whenever the
## simulation's stock changes, and the shell repaints every cell on a relayout. `sync()` paints a cell again when
## its figure changed or when its drawn caption or value is no longer what the demo drew; the ledger likewise.
## Per frame: six integer reads and compares, the model's stamp (the planks and the fuel's breakdown, decision 0571) and
## thirteen short string compares; formatting only on a change.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const ModelScript := preload("res://demo/ui/demo_hud_model.gd")

## The line glyphs the demo's own two cells wear (the shell's authored set; none generated here).
const FUEL_ICON: Texture2D = preload("res://ui/icons/fuel.svg")
const WARNING_ICON: Texture2D = preload("res://ui/icons/warning.svg")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const BEDS_ICON: Texture2D = preload("res://ui/icons/beds.svg")
const LEDGER_LINE: NodePath = ^"Line"

var model: ModelScript = ModelScript.new()
var _shell: UiShell = null
var _figures: PackedInt64Array = PackedInt64Array()
var _shown: PackedInt64Array = PackedInt64Array()
var _captions: PackedStringArray = PackedStringArray()
var _values: PackedStringArray = PackedStringArray()
var _descriptions: PackedStringArray = PackedStringArray()
## The ledger's text line, looked up once (no node lookup per frame).
var _ledger_line: Label = null
var _ledger: String = ""
var _primed: bool = false
## The model's `stamp` at the last paint: the planks and the fuel's breakdown, which no cell's figure carries.
var _stamp: int = 0


func _init() -> void:
	"""Size the columns once."""
	_figures.resize(ModelScript.CELL_COUNT)
	_shown.resize(ModelScript.CELL_COUNT)
	_captions.resize(ModelScript.CELL_COUNT)
	_values.resize(ModelScript.CELL_COUNT)
	_descriptions.resize(ModelScript.CELL_COUNT)


func bind(shell: UiShell) -> void:
	"""Paint this HUD shell's cells (null: nothing to do); the next sync paints all of them."""
	_shell = shell
	_primed = false
	_ledger_line = null
	if shell != null:
		var ledger: Control = shell.control_for(UiShell.ID_LEDGER)
		_ledger_line = ledger.get_node_or_null(LEDGER_LINE) as Label if ledger != null else null


func sync() -> bool:
	"""Keep every cell and the ledger the model's (see REPAINTING); true when anything was painted this call."""
	if _shell == null or not is_instance_valid(_shell):
		return false
	model.read_into(_figures)
	var stamp: int = model.stamp()
	var restamped: bool = stamp != _stamp
	_stamp = stamp
	var painted: bool = false
	for cell: int in ModelScript.CELL_COUNT:
		if not _primed or _figures[cell] != _shown[cell] or _overwritten(cell) or (restamped and (cell == ModelScript.CELL_FUEL or cell == ModelScript.CELL_WOOD)):
			_paint(cell)
			painted = true
	_primed = true
	var line: Label = _ledger_line
	if line != null and (painted or restamped or line.text != _ledger):
		_shell.set_ledger_display(model.ledger_text(_figures))
		_ledger = line.text
		painted = true
	return painted


func _overwritten(cell: int) -> bool:
	"""Whether the shell or UIManager has drawn over what the demo painted in this cell: its caption, its value, or
	its accessible description (a relayout rewrites that alone; two figures too wide both draw See ledger)."""
	var id: int = UiShell.COUNTER_IDS[cell]
	return _shell.counter_caption_label(id).text != _captions[cell] or _shell.counter_value_label(id).text != _values[cell] \
		or _shell.control_for(id).accessibility_description != _descriptions[cell]


func _paint(cell: int) -> void:
	"""Paint one cell from the model (see HOW EACH CELL IS PAINTED) and remember what it drew."""
	var id: int = UiShell.COUNTER_IDS[cell]
	var value: String = model.value_text(cell, _figures[cell])
	if not model.known(cell) or model.is_state(cell, _figures[cell]):
		_paint_own(cell, id, value, UiShell.DISCLOSURE_VARIATION)
	elif not _shell.set_counter_display(id, value):
		_paint_own(cell, id, value, UiShell.VALUE_VARIATION)
	var control := _shell.control_for(id) as Control
	control.tooltip_text = model.tooltip(cell, _figures[cell])
	control.accessibility_description = control.tooltip_text
	_shown[cell] = _figures[cell]
	_captions[cell] = _shell.counter_caption_label(id).text
	_values[cell] = _shell.counter_value_label(id).text
	_descriptions[cell] = control.accessibility_description


func _paint_own(cell: int, id: int, value: String, role: StringName) -> void:
	"""A cell the demo paints itself: Heating fuel and Beds, which the shell does not wire, and any cell whose figure
	is unknown ("Unavailable" in the shell's 16 px disclosure role, as the shell draws it). Its caption and glyph for the
	demo's own two (Heating fuel's warning glyph and clay value in its warning state), the value in `role` -- or, when it
	does not fit, See ledger in the disclosure role, the shell's own rule -- and enabled."""
	var warning: bool = model.is_warning(cell, _figures[cell])
	if cell == ModelScript.CELL_FUEL or cell == ModelScript.CELL_BEDS:
		_shell.counter_caption_label(id).text = ModelScript.CAPTIONS[cell]
		_shell.counter_icon(id).texture = BEDS_ICON if cell == ModelScript.CELL_BEDS else (WARNING_ICON if warning else FUEL_ICON)
	var label: Label = _shell.counter_value_label(id)
	if warning:
		label.add_theme_color_override(&"font_color", Palette.CLAY)
	elif label.has_theme_color_override(&"font_color") and cell == ModelScript.CELL_FUEL:
		label.remove_theme_color_override(&"font_color")
	var cell_button := _shell.control_for(id) as Button
	var shown: bool = fits(role_font(role), role_px(role), value, cell_button.size.x)
	var drawn_role: StringName = role if shown else UiShell.DISCLOSURE_VARIATION
	if role_font(drawn_role) != null:
		label.add_theme_font_override(&"font", role_font(drawn_role))
	label.add_theme_font_size_override(&"font_size", role_px(drawn_role))
	label.text = value if shown else UiShell.SEE_LEDGER
	cell_button.disabled = false
	cell_button.accessibility_name = "%s counter" % ModelScript.CAPTIONS[cell]


static func fits(font: Font, px: int, text: String, cell_width: float) -> bool:
	"""The shell's own rule (UI-C3-R01 §2): a value fits when it measures inside `cell_width-8` in the value
	face. A cell not laid out yet (width 0) or no face to measure with judges nothing, as the shell does."""
	if cell_width <= 0.0 or font == null:
		return true
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x <= UiLayout.resource_value_width(cell_width)


func role_font(role: StringName) -> Font:
	"""The face of one of the shell's §2.2 roles (its Theme resource's variation), or null with no theme."""
	var shell_theme: Theme = _shell.theme
	return shell_theme.get_font(&"font", role) if shell_theme != null else null


func role_px(role: StringName) -> int:
	"""The size of one of the shell's §2.2 roles, read from its Theme resource (18 with no theme)."""
	var shell_theme: Theme = _shell.theme
	return shell_theme.get_font_size(&"font_size", role) if shell_theme != null else 18


func ledger_label() -> Label:
	"""The ledger's text line (UI-SET-009's "Line", found at `bind`), or null when the shell has none."""
	return _ledger_line
