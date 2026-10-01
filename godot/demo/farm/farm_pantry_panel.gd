extends CanvasLayer
## The Pantry: the Food command's view (UI-SET-030 opens UI-SET-060, "Recipes and production"),
## breaking the HUD's one Food figure out ingredient by ingredient. Decisions 0196 and 0292. DEMO UI in
## the woodland skin, in the HUD's modal rectangle, above the HUD's layer (see LAYER).
##
## TWO TABS (decision 0292, the review's F46: usable stock before recipe prose).
##   Stocks (first, and what the Pantry opens on): a table, one row per ingredient per store
##     (farm_pantry_rows.gd) -- the ingredient, how much is IN STORE, how much is INCOMING (a harvest on
##     its way there, its room reserved: decision 0222's holds), the STORE, and the NEXT TO SPOIL there
##     (the first lot: its amount and the calendar hours until it spoils, at that store's rate and each
##     season's -- farm_pantry.gd THE FORECAST). Food that spoils within two game days comes first and
##     says "Soon" in clay; the order is set when the tab opens and kept while it is open (nothing moves
##     under the pointer). Under it, each store as a row: stored, reserved for harvests, free, capacity
##     and how fast it ages food. Spoiled food can be sent to compost at §5.7's 4 : 2. An empty pantry
##     names a real source from the beds -- a ripe bed to harvest, else the next to ripen, else one to
##     plant -- with a button that opens that bed.
##   Recipe ideas (not cookable yet): the content library's dishes each ingredient feeds
##     (farm_recipes.gd), plainly labelled as candidates for a kitchen that does not exist.
## There is no Orders tab: nothing in the demo cooks, processes or orders food yet (decision 0292).
## Every quantity is the farm's one units form (farm_text.gd UNITS).
##
## LAYER. It is the Food command's pop-up and is drawn ABOVE the HUD (LAYER), as UI §3 draws a modal
## workspace over the permanent HUD. Below it, at 1280x720 the HUD's time cluster (top right, which
## takes the mouse) lay over the header's "×" and ate every click on it (playtest 2026-09-29: "Close
## button does nothing"), and the resource counters and command strip covered its corners too. While
## it is open K, Esc and its "×" close it; the stall banner is drawn above it still.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RowsScript := preload("res://demo/farm/farm_pantry_rows.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")

signal compost_requested
signal close_requested
## The empty pantry's suggestion button: open this bed.
signal bed_requested(bed: int)

const TITLE: String = "Pantry"
const TAB_STOCKS: int = 0
const TAB_RECIPES: int = 1
const TAB_NAMES: Array[String] = ["Stocks", "Recipe ideas (not cookable yet)"]
const RECIPE_HEADING: String = "Recipe ideas — not yet cookable"
const RECIPE_NOTE: String = "There is no kitchen yet, so nothing here can be cooked. These are dishes from the Redwall content library that use the ingredient."
## What the spoil times mean (the review's F27: say the assumption).
const FORECAST_NOTE: String = "Next to spoil: the first lot in that store, in game hours from now at the store's rate and the season's (a coming season change included). Soon = within 2 days."
const STOCK_HEADINGS: Array[String] = ["Ingredient", "In store", "Incoming", "Store", "Next to spoil"]
const STORE_HEADINGS: Array[String] = ["Store", "Stored", "Reserved for harvests", "Free", "Capacity", "Ages food"]
const EMPTY_TEXT: String = "The pantry is empty, and no harvest is on its way."
## Notes and table headings: UI §2's 14 px floor (the farm's SMALL_PX is below it).
const NOTE_PX: int = 14
## UI §2's interactive floor: the tabs, the ingredient list and "Open bed" at least this tall.
const TARGET_PX: float = 32.0
const LIST_WIDTH: float = 300.0
const STOCK_COLUMN_W: PackedFloat32Array = [210.0, 96.0, 96.0, 170.0, 0.0]
const MIN_BODY_H: float = 160.0
## The panel's height that is not a tab's page: header, tab strip, gaps and margins.
const BODY_RESERVE_H: float = 110.0
## `_scrolls[STOCK_SCROLL]` is the stock table's; the rest are the Recipes tab's.
const STOCK_SCROLL: int = 0
## Above the HUD's CanvasLayer (scenes/ui/hud.tscn, layer 1); the stall banner draws at 3, above this.
const LAYER: int = 2

var selected_item: int = 0
var tab: int = TAB_STOCKS

var _sim: SimScript = null
var _pantry: PantryScript = null
var _recipes: RecipesScript = null
var _rows: RowsScript = RowsScript.new()
var _frame: PanelContainer = null
var _total: Label = null
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _stock_grid: GridContainer = null
var _stock_cells: Array[Label] = []
var _stock_icons: Array[TextureRect] = []
var _store_grid: GridContainer = null
var _store_cells: Array[Label] = []
var _empty: VBoxContainer = null
var _suggestion: Label = null
var _open_bed: Button = null
var _item_buttons: Array[Button] = []
var _recipe_heading: Label = null
var _dish_title: Label = null
var _dishes: Label = null
var _spoiled: Label = null
var _compost: Button = null
var _scrolls: Array[ScrollContainer] = []
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _goods: GoodsScript = null
var _close: Button = null


func configure(sim: SimScript, pantry: PantryScript, recipes: RecipesScript) -> void:
	"""Show this pantry; build hidden."""
	_sim = sim
	_pantry = pantry
	_recipes = recipes
	layer = LAYER
	name = "FarmPantryPanel"
	_build()
	visible = false


func set_goods(goods: GoodsScript) -> void:
	"""Show each ingredient's icon from these goods."""
	_goods = goods
	for item: int in Catalog.ITEM_COUNT:
		FarmUi.set_icon(_item_buttons[item], goods.icon_of(item))


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Header, the tab strip, and the two tabs' pages."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_header())
	column.add_child(_build_tabs())
	_pages.append(_build_stocks())
	_pages.append(_build_recipes())
	for page: Control in _pages:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(page)
	_show_page()


func _header() -> HBoxContainer:
	"""Title, the total and the close button."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var title: Label = FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_total = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_total)
	_close = FarmUi.button("×")
	_close.tooltip_text = "Close the pantry (K or Esc)"
	_close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close)
	return row


func _build_tabs() -> HBoxContainer:
	"""Stocks and Recipe ideas, one pressed at a time."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var group := ButtonGroup.new()
	for k: int in TAB_NAMES.size():
		var made: Button = FarmUi.button(TAB_NAMES[k])
		made.custom_minimum_size.y = TARGET_PX
		made.toggle_mode = true
		made.button_group = group
		made.button_pressed = k == tab
		made.pressed.connect(show_tab.bind(k))
		row.add_child(made)
		_tabs.append(made)
	return row


# --- the Stocks tab ---------------------------------------------------------------------------

func _build_stocks() -> VBoxContainer:
	"""The stock table (scrolling), the empty state, the stores table and the spoiled row."""
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 6)
	page.add_child(FarmUi.label(FORECAST_NOTE, NOTE_PX, Palette.UMBER))
	var scroll := _scroll()
	page.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_stock_grid = _grid(STOCK_HEADINGS)
	inner.add_child(_stock_grid)
	inner.add_child(_build_empty())
	_store_grid = _grid(STORE_HEADINGS)
	page.add_child(_store_grid)
	page.add_child(_build_spoiled())
	return page


func _scroll() -> ScrollContainer:
	"""A vertical scroll that takes the body's height (`_place`)."""
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = MIN_BODY_H
	_scrolls.append(scroll)
	return scroll


func _grid(headings: Array[String]) -> GridContainer:
	"""A table with its column headings as the first row."""
	var grid := GridContainer.new()
	grid.columns = headings.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 4)
	for heading: String in headings:
		var cell: Label = FarmUi.label(heading, NOTE_PX, Palette.UMBER, true)
		cell.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(cell)
	return grid


func _build_empty() -> VBoxContainer:
	"""The empty pantry: what to do about it, and the button that opens the bed it names."""
	_empty = VBoxContainer.new()
	_empty.add_theme_constant_override(&"separation", 6)
	_empty.add_child(FarmUi.label(EMPTY_TEXT, FarmUi.BODY_PX, Palette.INK, true))
	_suggestion = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	_empty.add_child(_suggestion)
	_open_bed = FarmUi.button("")
	_open_bed.custom_minimum_size.y = TARGET_PX
	_open_bed.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_open_bed.pressed.connect(func() -> void: bed_requested.emit(_rows.suggested_bed))
	_empty.add_child(_open_bed)
	_empty.visible = false
	return _empty


func _build_spoiled() -> HBoxContainer:
	"""Spoiled food and its compost button."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	_spoiled = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	_spoiled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_spoiled)
	_compost = FarmUi.button("Compost it (4 → 2)")
	_compost.pressed.connect(func() -> void: compost_requested.emit())
	row.add_child(_compost)
	return row


func _ensure_stock_rows(rows: int) -> void:
	"""Grow the stock table's row pool to `rows` (rows are made once and reused, never freed)."""
	while _stock_icons.size() < rows:
		var name_cell := HBoxContainer.new()
		name_cell.add_theme_constant_override(&"separation", 6)
		name_cell.custom_minimum_size.x = STOCK_COLUMN_W[0]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(FarmUi.ICON_PX, FarmUi.ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		name_cell.add_child(icon)
		_stock_icons.append(icon)
		_stock_grid.add_child(name_cell)
		for column: int in STOCK_HEADINGS.size():
			var cell: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
			cell.autowrap_mode = TextServer.AUTOWRAP_OFF
			if column == 0:
				name_cell.add_child(cell)
			else:
				cell.custom_minimum_size.x = STOCK_COLUMN_W[column]
				_stock_grid.add_child(cell)
			_stock_cells.append(cell)


func _ensure_store_rows(stores: int) -> void:
	"""Grow the stores table's row pool to `stores`."""
	while _store_cells.size() < stores * STORE_HEADINGS.size():
		var cell: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
		cell.autowrap_mode = TextServer.AUTOWRAP_OFF
		_store_grid.add_child(cell)
		_store_cells.append(cell)


# --- the Recipes tab --------------------------------------------------------------------------

func _build_recipes() -> HBoxContainer:
	"""Every ingredient (catalog order, never reordered) beside the picked one's dishes."""
	var page := HBoxContainer.new()
	page.add_theme_constant_override(&"separation", 14)
	var list := _scroll()
	list.size_flags_horizontal = Control.SIZE_FILL
	list.custom_minimum_size.x = LIST_WIDTH
	page.add_child(list)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 3)
	list.add_child(rows)
	for item: int in Catalog.ITEM_COUNT:
		var row: Button = FarmUi.button("", FarmUi.BODY_PX)
		row.custom_minimum_size.y = TARGET_PX
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.pressed.connect(select_item.bind(item))
		rows.add_child(row)
		_item_buttons.append(row)
	page.add_child(_build_dishes())
	return page


func _build_dishes() -> ScrollContainer:
	"""The not-cookable heading, the note, and the picked ingredient's dishes."""
	var scroll := _scroll()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_recipe_heading = FarmUi.label(RECIPE_HEADING, FarmUi.TITLE_PX, Palette.INK, true)
	box.add_child(_recipe_heading)
	box.add_child(FarmUi.label(RECIPE_NOTE, NOTE_PX, Palette.UMBER))
	_dish_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	box.add_child(_dish_title)
	_dishes = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	box.add_child(_dishes)
	return scroll


# --- what it shows ------------------------------------------------------------------------------

func toggle() -> bool:
	"""Open or close; returns whether it is now open. It opens on Stocks, its rows freshly ordered."""
	visible = not visible
	if visible:
		show_tab(TAB_STOCKS)
	return visible


func show_tab(which: int) -> void:
	"""Show tab `which` (TAB_*); Stocks re-orders its rows (soonest to spoil first) as it opens."""
	tab = which if which == TAB_RECIPES else TAB_STOCKS
	if tab == TAB_STOCKS and _pantry != null:
		_rows.rebuild(_pantry, _sim.calendar.hour_index())
	_show_page()
	refresh()


func _show_page() -> void:
	"""Only the current tab's page, its button pressed."""
	for k: int in _pages.size():
		_pages[k].visible = k == tab
		_tabs[k].set_pressed_no_signal(k == tab)


func select_item(item: int) -> void:
	"""Show one ingredient's dishes."""
	selected_item = item
	refresh()


func refresh() -> void:
	"""Rewrite the total and the current tab, in place."""
	if _pantry == null or not visible:
		return
	_total.text = "%s of food in store · %s" % [Text.units_text(_pantry.total_milli()), Text.clock_line(_sim)]
	if tab == TAB_STOCKS:
		_fill_stocks()
	else:
		_fill_recipes()
	_place.call_deferred()


func _fill_stocks() -> void:
	"""The stock rows (refigured in place, new ones at the end), the empty state, the stores and the
	spoiled row."""
	_rows.update(_pantry, _sim.calendar.hour_index())
	_ensure_stock_rows(_rows.count())
	for row: int in _stock_icons.size():
		_fill_stock_row(row)
	var empty: bool = _rows.count() == 0
	_empty.visible = empty
	_stock_grid.visible = not empty
	if empty:
		_fill_empty()
	_fill_stores()
	_spoiled.text = "Spoiled food: %s" % Text.units_text(_pantry.spoiled_milli)
	FarmUi.set_enabled(_compost, _pantry.spoiled_milli >= 2, "nothing has spoiled")


func _fill_stock_row(row: int) -> void:
	"""One stock row's cells (a pooled row past the table's end is hidden)."""
	var shown: bool = row < _rows.count()
	var base: int = row * STOCK_HEADINGS.size()
	_stock_icons[row].get_parent().visible = shown
	for column: int in range(1, STOCK_HEADINGS.size()):
		_stock_cells[base + column].visible = shown
	if not shown:
		return
	var cells: PackedStringArray = stock_row_cells(row)
	for column: int in cells.size():
		_stock_cells[base + column].text = cells[column]
	var soon: bool = _rows.is_soon(row)
	_stock_cells[base + 4].add_theme_color_override(&"font_color", Palette.CLAY if soon else Palette.INK)
	if _goods != null:
		_stock_icons[row].texture = _goods.icon_of(_rows.item[row])


func _fill_empty() -> void:
	"""The suggestion from the beds, and its bed's button."""
	var named: bool = _rows.suggest(_sim)
	_suggestion.text = _rows.suggestion
	_open_bed.visible = named
	_open_bed.text = "Open bed %d" % (_rows.suggested_bed + 1)


func _fill_stores() -> void:
	"""Each store as a row."""
	var stores: int = _pantry.storage.count()
	_ensure_store_rows(stores)
	for k: int in _store_cells.size():
		_store_cells[k].visible = k < stores * STORE_HEADINGS.size()
	for at: int in stores:
		var cells: PackedStringArray = RowsScript.store_cells(_pantry, at)
		for column: int in cells.size():
			_store_cells[at * STORE_HEADINGS.size() + column].text = cells[column]


func _fill_recipes() -> void:
	"""Each ingredient's stock on its button, and the picked one's dish list."""
	for item: int in Catalog.ITEM_COUNT:
		var held: int = _pantry.milli_of(item)
		_item_buttons[item].set_pressed_no_signal(item == selected_item)
		_item_buttons[item].text = "%s · %s" % [Catalog.ITEM_LABELS[item],
			"%s in store" % Text.units_text(held) if held > 0 else "none in store"]
	var label: String = Catalog.ITEM_LABELS[selected_item]
	if _recipes == null or not _recipes.is_loaded():
		_dish_title.text = label
		_dishes.text = "(the recipe index is missing)"
		return
	_dish_title.text = "%s feeds %d dishes (and %d more through prepared parts)" % [label,
		_recipes.direct_count(selected_item), _recipes.component_count(selected_item)]
	_dishes.text = "\n".join(_recipes.dishes_of(selected_item))


# --- readouts (tests and the scripted check) ---------------------------------------------------------

func stock_row_cells(row: int) -> PackedStringArray:
	"""Stock row `row` as its five cells, as last figured: ingredient, in store, incoming, store, next to
	spoil."""
	return PackedStringArray([Catalog.ITEM_LABELS[_rows.item[row]], _rows.available_text(row),
		_rows.incoming_text(row), _rows.store_text(_pantry, row), _rows.spoil_text(_pantry, row)])


func stock_row_count() -> int:
	"""How many rows the stock table shows."""
	return _rows.count()


func shown_stock_row(row: int) -> PackedStringArray:
	"""Stock row `row` as drawn (its labels' text)."""
	var base: int = row * STOCK_HEADINGS.size()
	var out := PackedStringArray()
	for column: int in STOCK_HEADINGS.size():
		out.append(_stock_cells[base + column].text)
	return out


func stock_cell(row: int, column: int) -> Label:
	"""Stock row `row`'s cell in `column` (its colour: tests)."""
	return _stock_cells[row * STOCK_HEADINGS.size() + column]


func store_row_cells(at: int) -> PackedStringArray:
	"""Store `at`'s row as drawn."""
	var out := PackedStringArray()
	for column: int in STORE_HEADINGS.size():
		out.append(_store_cells[at * STORE_HEADINGS.size() + column].text)
	return out


func empty_shown() -> bool:
	"""Whether the empty state shows (and the table does not)."""
	return _empty.visible and not _stock_grid.visible


func suggestion_text() -> String:
	"""The empty state's suggestion as shown."""
	return _suggestion.text


func open_bed_button() -> Button:
	"""The empty state's "Open bed N" button."""
	return _open_bed


func tab_button(which: int) -> Button:
	"""Tab `which`'s button."""
	return _tabs[which]


func page_shown(which: int) -> bool:
	"""Whether tab `which`'s page shows."""
	return _pages[which].visible


func recipe_heading() -> String:
	"""The Recipe ideas tab's heading as drawn."""
	return _recipe_heading.text


func dishes_text() -> String:
	"""The dish list as shown (tests)."""
	return _dishes.text


func dish_title() -> String:
	"""The dish heading as shown (tests)."""
	return _dish_title.text


func total_text() -> String:
	"""The header's total line (tests)."""
	return _total.text


func item_button(item: int) -> Button:
	"""An ingredient's button on the Recipes tab (tests and the scripted check)."""
	return _item_buttons[item]


func close_button() -> Button:
	"""The header's "×" (tests and the scripted check)."""
	return _close


# --- placement --------------------------------------------------------------------------------

func _place() -> void:
	"""In the HUD's modal rectangle, at the HUD's scale; the scrolling bodies take the height left."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var rect := Rect2(zone.position + Vector2(FarmUi.FRAME_EXPAND, FarmUi.FRAME_EXPAND),
		zone.size - Vector2(2.0, 2.0) * FarmUi.FRAME_EXPAND)
	var body: float = rect.size.y - BODY_RESERVE_H
	for k: int in _scrolls.size():
		var extra: float = _stocks_extra_h() if k == STOCK_SCROLL else 0.0
		_scrolls[k].custom_minimum_size.y = maxf(MIN_BODY_H, body - extra)
	FarmUi.place(_frame, rect, _geometry.scale)


func _stocks_extra_h() -> float:
	"""What the Stocks page shows besides its scrolling table: the note, the stores and the spoiled row,
	and the gaps between them."""
	var page := _pages[TAB_STOCKS] as VBoxContainer
	var extra: float = 0.0
	for child: Node in page.get_children():
		if child != _scrolls[STOCK_SCROLL]:
			extra += (child as Control).get_combined_minimum_size().y
	return extra + float(page.get_theme_constant(&"separation") * (page.get_child_count() - 1))
