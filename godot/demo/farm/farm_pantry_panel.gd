extends CanvasLayer
## The Pantry: the Food command's view (UI-SET-030 opens UI-SET-060, "Recipes and production"),
## breaking the HUD's one Food figure out ingredient by ingredient. Decision 0196. DEMO UI in the
## woodland skin, in the HUD's modal rectangle, below the HUD's layer.
##
## Left: every farmed ingredient -- its icon (farm_goods.gd: a render of its own model, else a roundel
## in its colour) -- with its whole units in store, how fresh its oldest lot is and how
## many hours before it spoils (§5.8), in stock first. Right: for the ingredient picked, the content
## library's dishes it feeds (farm_recipes.gd) -- candidates for a kitchen that does not exist yet.
## Above: each storage place, its load and how fast it spoils food (the cellar providers' permille);
## below: spoiled food, which can be sent to compost at §5.7's 4 : 2.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")

signal compost_requested
signal close_requested

const TITLE: String = "Pantry"
const RECIPE_NOTE: String = "Dishes from the Redwall content library that use it — candidates for the kitchen (no cooking yet)."
const LIST_WIDTH: float = 400.0
const MIN_BODY_H: float = 200.0
## The panel's height that is not the two lists: header, stores line, spoiled row, margins.
const BODY_RESERVE_H: float = 150.0

var selected_item: int = 0

var _sim: SimScript = null
var _pantry: PantryScript = null
var _recipes: RecipesScript = null
var _frame: PanelContainer = null
var _total: Label = null
var _stores: Label = null
var _rows: VBoxContainer = null
var _item_buttons: Array[Button] = []
var _dish_title: Label = null
var _dishes: Label = null
var _spoiled: Label = null
var _compost: Button = null
var _body: HBoxContainer = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _goods: GoodsScript = null


func configure(sim: SimScript, pantry: PantryScript, recipes: RecipesScript) -> void:
	"""Show this pantry; build hidden."""
	_sim = sim
	_pantry = pantry
	_recipes = recipes
	layer = 0
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
	"""Header, stores, the item list beside the dishes, and the spoiled line."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_header())
	_stores = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_stores)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override(&"separation", 14)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_body.add_child(_build_list())
	_body.add_child(_build_dishes())
	column.add_child(_build_spoiled())


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
	var close := FarmUi.button("×")
	close.tooltip_text = "Close the pantry (K)"
	close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close)
	return row


func _build_list() -> ScrollContainer:
	"""One button per ingredient (reordered on refresh: in stock first)."""
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, MIN_BODY_H)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 3)
	scroll.add_child(_rows)
	for item: int in Catalog.ITEM_COUNT:
		var row: Button = FarmUi.button("", FarmUi.BODY_PX)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(func() -> void: select_item(item))
		_rows.add_child(row)
		_item_buttons.append(row)
	return scroll


func _build_dishes() -> ScrollContainer:
	"""The picked ingredient's dishes."""
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = MIN_BODY_H
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_dish_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	box.add_child(_dish_title)
	box.add_child(FarmUi.label(RECIPE_NOTE, FarmUi.SMALL_PX, Palette.UMBER))
	_dishes = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	box.add_child(_dishes)
	return scroll


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


# --- what it shows ------------------------------------------------------------------------------

func toggle() -> bool:
	"""Open or close; returns whether it is now open."""
	visible = not visible
	if visible:
		refresh()
	return visible


func select_item(item: int) -> void:
	"""Show one ingredient's dishes."""
	selected_item = item
	refresh()


func refresh() -> void:
	"""Rewrite the totals, the stores, every row and the picked ingredient's dishes."""
	if _pantry == null or not visible:
		return
	_total.text = "%d U of food in store · %s" % [_pantry.total_units(), Text.clock_line(_sim)]
	_stores.text = stores_text()
	var order: int = 0
	for in_stock: bool in [true, false]:
		for item: int in Catalog.ITEM_COUNT:
			if (_pantry.milli_of(item) > 0) == in_stock:
				_rows.move_child(_item_buttons[item], order)
				_item_buttons[item].text = item_row_text(item)
				order += 1
	_fill_dishes()
	_spoiled.text = "Spoiled food: %d.%d U" % [_pantry.spoiled_milli / 1000, (_pantry.spoiled_milli % 1000) / 100]
	FarmUi.set_enabled(_compost, _pantry.spoiled_milli >= 2, "nothing has spoiled")
	_place.call_deferred()


func item_row_text(item: int) -> String:
	"""'Carrot — 5 U · 80% fresh, spoils in 190 h' or 'Carrot — none'."""
	var units: int = _pantry.units_of(item)
	if _pantry.milli_of(item) <= 0:
		return "%s — none" % Catalog.ITEM_LABELS[item]
	var fresh: int = _read.value / 10 if _pantry.freshness_permille_into(item, _read) else 0
	var hours: int = _read.value if _pantry.hours_left_into(item, _read) else 0
	return "%s — %d U · %d%% fresh, spoils in %d h" % [Catalog.ITEM_LABELS[item], units, fresh, hours]


func stores_text() -> String:
	"""Each storage place, its load against its capacity and its spoilage rate."""
	var parts := PackedStringArray()
	var storage := _pantry.storage
	for location: int in storage.count():
		parts.append("%s %d/%d U (ages ×%d.%02d)" % [storage.label_of(location), _pantry.used_milli_of(location) / 1000,
			storage.capacity_milli_of(location) / 1000, storage.permille_of(location) / 1000,
			(storage.permille_of(location) % 1000) / 10])
	return "Stores: " + " · ".join(parts)


func _fill_dishes() -> void:
	"""The picked ingredient's dish list."""
	var label: String = Catalog.ITEM_LABELS[selected_item]
	if _recipes == null or not _recipes.is_loaded():
		_dish_title.text = label
		_dishes.text = "(the recipe index is missing)"
		return
	_dish_title.text = "%s feeds %d dishes (and %d more through prepared parts)" % [label,
		_recipes.direct_count(selected_item), _recipes.component_count(selected_item)]
	_dishes.text = "\n".join(_recipes.dishes_of(selected_item))


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
	"""An ingredient's row button (tests and the scripted check)."""
	return _item_buttons[item]


# --- placement --------------------------------------------------------------------------------

func _place() -> void:
	"""In the HUD's modal rectangle, at the HUD's scale; the lists take the height left."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var rect := Rect2(zone.position + Vector2(FarmUi.FRAME_EXPAND, FarmUi.FRAME_EXPAND),
		zone.size - Vector2(2.0, 2.0) * FarmUi.FRAME_EXPAND)
	for child: Node in _body.get_children():
		(child as Control).custom_minimum_size.y = maxf(MIN_BODY_H, rect.size.y - BODY_RESERVE_H)
	FarmUi.place(_frame, rect, _geometry.scale)
