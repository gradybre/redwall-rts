extends "res://test/framework/test_case.gd"
## The Pantry's tabs and its Stocks table (decision 0292, the review's F46): Stocks first and Recipe ideas
## apart, one row per ingredient per store with in store / incoming / store / next to spoil, food about
## to spoil first, the order kept while the Pantry is open, each store as a row (stored, reserved, free),
## the empty pantry's suggestion from the beds and its button, and the pantry's per-store readouts
## behind them (farm_pantry.gd: a hold's item, `incoming_milli`, `first_to_spoil_at_into`, `lot_item`).
##
## No scene tree and no staged assets: the panel is built off-tree; the farm for the button test is the
## placeholder village (as test_demo_farm_ui.gd builds it). Expected spoil hours are §5.7/§5.8 sums named
## at each assertion.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RowsScript := preload("res://demo/farm/farm_pantry_rows.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const RADISH: int = 0
const CARROT: int = 2
const LETTUCE: int = 7
const SPINACH: int = 8
const WHEAT: int = 13
const BARLEY: int = 14
const COVERED: int = 0
const CELLAR: int = 1
const HOUR_USEC: int = 2500000
const BED_CARROTS: int = 2

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _pantry() -> PantryScript:
	"""A pantry with the covered store and a 60 U root cellar (spoilage ×0.35)."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [{"id": &"c", "position": Vector2.ZERO, "capacity_u": 60,
		"spoilage_permille": 350, "label": "Root cellar"}])
	return PantryScript.new(storage)


func _panel(sim: SimScript, pantry: PantryScript) -> PantryPanelScript:
	"""The Pantry over `pantry`, off-tree, with the recipe index."""
	var recipes := RecipesScript.new()
	recipes.load_index()
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, pantry, recipes)
	return panel


func _add(pantry: PantryScript, item: int, milli: int, at: int) -> void:
	"""Store `milli` of `item` at `at` as a fresh lot."""
	assert_true(pantry.add_into(item, milli, at, _read), "stored %d of item %d" % [milli, item])


func _age(pantry: PantryScript, hours: int) -> void:
	"""Age every lot `hours` spring hours."""
	for hour: int in hours:
		pantry.age_hour(0)


func _rows_of(panel: PantryPanelScript) -> Array[PackedStringArray]:
	"""Every stock row as drawn."""
	var out: Array[PackedStringArray] = []
	for row: int in panel.stock_row_count():
		out.append(panel.shown_stock_row(row))
	return out


# --- the tabs --------------------------------------------------------------------------------------

func test_the_pantry_opens_on_stocks_and_recipes_are_their_own_tab() -> void:
	"""Stocks first, and what it opens on; Recipe ideas is its own tab, labelled not cookable."""
	var panel := _panel(SimScript.new(), _pantry())
	assert_equal(panel.tab_button(PantryPanelScript.TAB_STOCKS).text, "Stocks", "Stocks first")
	assert_equal(panel.tab_button(PantryPanelScript.TAB_RECIPES).text, "Recipe ideas (not cookable yet)", "then Recipe ideas")
	assert_true(panel.tab_button(PantryPanelScript.TAB_STOCKS).get_index() < panel.tab_button(PantryPanelScript.TAB_RECIPES).get_index(), "in that order")
	assert_true(panel.toggle(), "open")
	assert_equal(panel.tab, PantryPanelScript.TAB_STOCKS, "opens on Stocks")
	assert_true(panel.page_shown(PantryPanelScript.TAB_STOCKS) and not panel.page_shown(PantryPanelScript.TAB_RECIPES), "Stocks alone")
	assert_true(panel.tab_button(PantryPanelScript.TAB_STOCKS).button_pressed, "its tab pressed")
	panel.tab_button(PantryPanelScript.TAB_RECIPES).pressed.emit()
	assert_true(panel.page_shown(PantryPanelScript.TAB_RECIPES) and not panel.page_shown(PantryPanelScript.TAB_STOCKS), "Recipes alone")
	assert_true(panel.tab_button(PantryPanelScript.TAB_RECIPES).button_pressed, "its tab pressed")
	assert_equal(panel.recipe_heading(), "Recipe ideas — not yet cookable", "labelled not cookable")
	assert_false(panel.toggle(), "closed")
	assert_true(panel.toggle(), "reopened")
	assert_equal(panel.tab, PantryPanelScript.TAB_STOCKS, "back on Stocks")


func test_the_recipe_list_marks_the_picked_ingredient_and_never_reorders() -> void:
	"""Recipe ideas lists every ingredient in catalog order whatever is in store, the picked one pressed."""
	var pantry := _pantry()
	_add(pantry, WHEAT, 2000, COVERED)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	panel.show_tab(PantryPanelScript.TAB_RECIPES)
	panel.item_button(LETTUCE).pressed.emit()
	assert_equal(panel.selected_item, LETTUCE, "picked")
	assert_true(panel.item_button(LETTUCE).button_pressed and not panel.item_button(WHEAT).button_pressed, "pressed alone")
	assert_equal(panel.item_button(WHEAT).text, "Wheat · 2.0 U in store", "its stock")
	assert_equal(panel.item_button(LETTUCE).get_index(), LETTUCE, "catalog order, stock or none")
	assert_equal(panel.item_button(WHEAT).get_index(), WHEAT, "wheat in stock is not moved up")
	assert_true(panel.dish_title().begins_with("Lettuce feeds "), "its dishes")


# --- the stock table ----------------------------------------------------------------------------

func test_a_row_per_ingredient_per_store() -> void:
	"""Carrots in both stores are two rows, each with its own store and its own next lot to spoil."""
	var pantry := _pantry()
	_add(pantry, CARROT, 3000, COVERED)
	_add(pantry, CARROT, 2100, CELLAR)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_equal(_rows_of(panel), [PackedStringArray(["Carrot", "3.0 U", "—", "Covered store", "all in 10d"]),
		PackedStringArray(["Carrot", "2.1 U", "—", "Root cellar", "all in 22d 23h"])] as Array[PackedStringArray],
		"roots 240 h: 240 spring hours in the store; 281 at ×0.35 then 270 at summer's ×0.525 = 551 h in the cellar")


func test_food_about_to_spoil_comes_first_and_says_so() -> void:
	"""Lettuce two days from spoiling goes above fresher food listed earlier in the catalog; the next lot
	to spoil is named by its own amount, 'Soon', in clay."""
	var pantry := _pantry()
	_add(pantry, LETTUCE, 1200, COVERED)
	_age(pantry, 110)
	_add(pantry, LETTUCE, 2500, COVERED)
	_add(pantry, RADISH, 300, COVERED)
	_add(pantry, WHEAT, 8000, COVERED)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	var rows: Array[PackedStringArray] = _rows_of(panel)
	assert_equal(rows[0], PackedStringArray(["Lettuce", "3.7 U", "—", "Covered store", "Soon: 1.2 U in 1d 10h"]),
		"cabbage row 144 h, 110 gone: 34 h left, the older lot of two")
	assert_equal(rows[1][0], "Radish", "then the catalog's order")
	assert_equal(rows[2][0], "Wheat", "and on")
	assert_equal(panel.stock_cell(0, 4).get_theme_color(&"font_color"), Palette.CLAY, "soon in clay")
	assert_equal(panel.stock_cell(1, 4).get_theme_color(&"font_color"), Palette.INK, "the rest in ink")


func test_the_soon_line_is_two_days() -> void:
	"""Exactly SOON_HOURS out is soon; an hour more is not (the row keeps its catalog place)."""
	var pantry := _pantry()
	_add(pantry, RADISH, 1000, COVERED)
	_add(pantry, LETTUCE, 1000, COVERED)
	_age(pantry, 144 - RowsScript.SOON_HOURS - 1)
	var rows := RowsScript.new()
	rows.rebuild(pantry, 0)
	assert_equal(rows.item, PackedInt32Array([RADISH, LETTUCE]), "49 h left: not soon")
	assert_false(rows.is_soon(1), "not soon at 49 h")
	_age(pantry, 1)
	rows.rebuild(pantry, 0)
	assert_equal(rows.item, PackedInt32Array([LETTUCE, RADISH]), "48 h left: first")
	assert_true(rows.is_soon(0), "soon at 48 h")
	assert_equal(rows.spoil_text(pantry, 0), "Soon: all in 2d", "and worded so at 48 h")
	assert_equal(rows.spoil_text(pantry, 1), "all in 6d", "radish: 240 - 96 = 144 h, not soon")


func test_soon_rows_go_soonest_first() -> void:
	"""Two soon rows: the sooner first, whatever the catalog says (carrot comes before wheat in it)."""
	var pantry := _pantry()
	_add(pantry, WHEAT, 1000, COVERED)
	_age(pantry, 485)
	_add(pantry, CARROT, 1000, COVERED)
	_age(pantry, 200)
	var rows := RowsScript.new()
	rows.rebuild(pantry, 0)
	assert_equal(rows.item, PackedInt32Array([WHEAT, CARROT]), "grain 720 h: 35 h left; roots 240 h: 40 h left")


func test_equally_soon_rows_keep_the_catalog_order() -> void:
	"""Lettuce and spinach (the cabbage row's 144 h) both 44 h from spoiling: lettuce first, as listed."""
	var pantry := _pantry()
	_add(pantry, SPINACH, 1000, COVERED)
	_add(pantry, LETTUCE, 1000, COVERED)
	_add(pantry, RADISH, 1000, COVERED)
	_age(pantry, 100)
	var rows := RowsScript.new()
	rows.rebuild(pantry, 0)
	assert_equal(rows.item, PackedInt32Array([LETTUCE, SPINACH, RADISH]), "a tie keeps its order; radish (140 h) after")


func test_incoming_is_not_in_store() -> void:
	"""A harvest on its way (a hold, at the slowest-spoiling store with room: the cellar) is incoming, not
	stock: barley and the cellar's carrots read 0 U in store and their amount incoming; the cellar's row has
	it as reserved, and its free room is less by it."""
	var pantry := _pantry()
	_add(pantry, CARROT, 5100, COVERED)
	assert_true(pantry.reserve_near_into(BARLEY, 4300, Vector2.ZERO, _read), "barley's room reserved")
	assert_true(pantry.reserve_near_into(CARROT, 1000, Vector2.ZERO, _read), "more carrots' room reserved")
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_equal(_rows_of(panel), [PackedStringArray(["Carrot", "5.1 U", "—", "Covered store", "all in 10d"]),
		PackedStringArray(["Carrot", "0 U", "1.0 U", "Root cellar", "—"]),
		PackedStringArray(["Barley", "0 U", "4.3 U", "Root cellar", "—"])] as Array[PackedStringArray], "in store and incoming")
	assert_equal(panel.store_row_cells(COVERED), PackedStringArray(["Covered store", "5.1 U", "0 U", "394.9 U", "400.0 U", "×1.00"]),
		"the store: stock, nothing reserved")
	assert_equal(panel.store_row_cells(CELLAR), PackedStringArray(["Root cellar", "0 U", "5.3 U", "54.7 U", "60.0 U", "×0.35"]),
		"the cellar: 60 less 5.3 reserved")
	assert_true(panel.total_text().begins_with("5.1 U of food in store"), "the total is stock alone")


func test_lots_and_holds_alike_add_up_per_row() -> void:
	"""Two carrot lots of equal age in one store: the row holds both, and names the lower lot row first
	(as `first_to_spoil_into` does on a tie); two carrot holds there add up as incoming."""
	var pantry := PantryScript.new(StorageScript.new())
	_add(pantry, CARROT, 1000, COVERED)
	_add(pantry, CARROT, 2000, COVERED)
	assert_true(pantry.reserve_near_into(CARROT, 500, Vector2.ZERO, _read), "a hold")
	assert_true(pantry.reserve_near_into(CARROT, 700, Vector2.ZERO, _read), "another")
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_equal(_rows_of(panel), [PackedStringArray(["Carrot", "3.0 U", "1.2 U", "Covered store", "1.0 U in 10d"])] as Array[PackedStringArray],
		"one row: 3.0 U in store, 1.2 U incoming, the first lot (1.0 U) next")


func test_a_hold_names_its_item_until_released() -> void:
	"""farm_pantry.gd: a hold's item is counted incoming at its store, follows a resize, and is gone once
	released; another item or store reads none."""
	var pantry := _pantry()
	assert_true(pantry.reserve_near_into(WHEAT, 2000, Vector2.ZERO, _read), "reserved")
	var hold: int = _read.value
	assert_true(pantry.hold_location_into(hold, _read), "placed")
	var at: int = _read.value
	assert_equal(pantry.incoming_milli(WHEAT, at), 2000, "wheat incoming there")
	assert_equal(pantry.incoming_milli(BARLEY, at), 0, "not barley")
	assert_equal(pantry.incoming_milli(WHEAT, 1 - at), 0, "not at the other store")
	assert_true(pantry.resize_hold(hold, 1500), "shrunk")
	assert_equal(pantry.incoming_milli(WHEAT, at), 1500, "follows the hold")
	pantry.release(hold)
	assert_equal(pantry.incoming_milli(WHEAT, at), 0, "released: nothing incoming")
	assert_true(pantry.reserve_near_into(BARLEY, 1000, Vector2.ZERO, _read), "the row reused")
	assert_equal(pantry.incoming_milli(WHEAT, at) + pantry.incoming_milli(BARLEY, at), 1000, "as barley only")


func test_a_store_taken_away_while_open_leaves_its_rows_gone_not_another_s() -> void:
	"""A row keeps its store by id: the cellar taken away (its racks out) while the Pantry is open leaves its
	row reading "(store gone)" and empty -- not the next store's figures, and no error -- and its carrots,
	moved to the covered store, are a new row at the end."""
	var shelves: Array = [{"id": &"a", "position": Vector2.ZERO, "capacity_u": 60, "spoilage_permille": 350,
		"label": "Root cellar A"}, {"id": &"b", "position": Vector2.ZERO, "capacity_u": 60,
		"spoilage_permille": 350, "label": "Root cellar B"}]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return shelves)
	var pantry := PantryScript.new(storage)
	_add(pantry, CARROT, 2000, 1)
	_add(pantry, WHEAT, 3000, 2)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_equal(_names(panel), ["Carrot", "Wheat"] as Array[String], "a row in each cellar")
	shelves.remove_at(0)
	pantry.refresh_locations()
	panel.refresh()
	assert_equal(_rows_of(panel), [PackedStringArray(["Carrot", "0 U", "—", "(store gone)", "—"]),
		PackedStringArray(["Wheat", "3.0 U", "—", "Root cellar B", "all in 79d 18h"]),
		PackedStringArray(["Carrot", "2.0 U", "—", "Covered store", "all in 10d"])] as Array[PackedStringArray],
		"cellar A gone: its row empty; cellar B, now index 1, still its own; the carrots moved, a new row")


func test_the_first_lot_to_spoil_at_one_store() -> void:
	"""farm_pantry.gd `first_to_spoil_at_into` keeps to its store; `lot_item` names a lot's item."""
	var pantry := _pantry()
	_add(pantry, CARROT, 1000, CELLAR)
	_age(pantry, 50)
	_add(pantry, CARROT, 1000, COVERED)
	assert_true(pantry.first_to_spoil_at_into(CARROT, COVERED, 0, _read), "the store's lot")
	assert_equal(pantry.lot_location(_read.value), COVERED, "in the store, though the cellar's is older")
	assert_equal(pantry.lot_item(_read.value), CARROT, "a carrot lot")
	assert_true(pantry.first_to_spoil_at_into(CARROT, CELLAR, 0, _read), "the cellar's lot")
	assert_equal(pantry.lot_location(_read.value), CELLAR, "in the cellar")
	assert_false(pantry.first_to_spoil_at_into(WHEAT, COVERED, 0, _read), "no wheat")
	assert_equal(_read.error, PantryScript.REFUSE_NO_STOCK, "NO_STOCK")
	assert_equal(pantry.lot_item(PantryScript.MAX_LOTS - 1), PantryScript.FREE, "a free row")


func test_the_order_is_kept_while_the_pantry_is_open() -> void:
	"""Open: a new row goes at the end even when it spoils sooner; a row whose stock has gone stays in its
	place reading 0 U; figures change in place. Reopened, the order is made afresh."""
	var pantry := _pantry()
	_add(pantry, WHEAT, 8000, COVERED)
	_add(pantry, LETTUCE, 1000, COVERED)
	_age(pantry, 100)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_equal(_names(panel), ["Lettuce", "Wheat"] as Array[String], "lettuce 44 h left: first")
	_add(pantry, RADISH, 500, COVERED)
	_age(pantry, 50)
	panel.refresh()
	assert_equal(_names(panel), ["Lettuce", "Wheat", "Radish"] as Array[String], "radish new: at the end; nothing moved")
	assert_equal(panel.shown_stock_row(0), PackedStringArray(["Lettuce", "0 U", "—", "Covered store", "—"]), "spoiled: kept, 0 U")
	panel.toggle()
	panel.toggle()
	assert_equal(_names(panel), ["Radish", "Wheat"] as Array[String], "reopened: made afresh, the spoiled row gone")
	for column: int in range(1, 5):
		assert_false(panel.stock_cell(2, column).visible, "the pooled third row's cell %d is hidden" % column)
	assert_false(panel.stock_cell(2, 0).get_parent().visible, "and its name cell")
	assert_true(panel.stock_cell(1, 4).visible and panel.stock_cell(1, 0).get_parent().visible, "the second row shows")


func _names(panel: PantryPanelScript) -> Array[String]:
	"""The stock table's ingredient column."""
	var out: Array[String] = []
	for row: int in panel.stock_row_count():
		out.append(panel.shown_stock_row(row)[0])
	return out


func test_spoil_times_read_as_days_and_hours() -> void:
	"""'20h', '2d', '7d 22h'."""
	assert_equal(RowsScript.until_text(0), "0h", "none")
	assert_equal(RowsScript.until_text(23), "23h", "under a day")
	assert_equal(RowsScript.until_text(24), "1d", "a day")
	assert_equal(RowsScript.until_text(48), "2d", "two")
	assert_equal(RowsScript.until_text(190), "7d 22h", "the review's 190 h")


# --- empty ------------------------------------------------------------------------------------

func test_an_empty_pantry_suggests_the_bed_that_ripens_first() -> void:
	"""Nothing stored or incoming: no table, the empty state, and the beds' real next source -- at the
	opening the carrots (bed 3) ripen in 24 h; once ripe, harvest them."""
	var sim := SimScript.new()
	var panel := _panel(sim, _pantry())
	panel.toggle()
	assert_true(panel.empty_shown(), "the empty state, no table")
	assert_equal(panel.stock_row_count(), 0, "no rows")
	assert_equal(panel.suggestion_text(), "Nothing is ripe yet: bed 3's carrot ripens in about 1d. Harvest it then.",
		"the carrots sown 96 h before the opening ripen at 120 h")
	assert_equal(panel.open_bed_button().text, "Open bed 3", "its button")
	sim.advance_usec(24 * HOUR_USEC)
	panel.refresh()
	assert_equal(panel.suggestion_text(), "Bed 3's carrot is ripe: harvest it to fill the pantry.", "ripe: harvest")


func test_an_empty_pantry_with_nothing_growing_says_plant_then_clear() -> void:
	"""No crop growing: plant the first empty bed; with every bed lost, clear the first."""
	var sim := SimScript.new()
	_wither_growing(sim)
	var rows := RowsScript.new()
	assert_true(rows.suggest(sim), "a suggestion")
	assert_equal(rows.suggestion, "Nothing is growing: plant bed 1 (open it, then Plant…).", "plant")
	assert_equal(rows.suggested_bed, 0, "bed 1")
	for bed: int in Catalog.BED_COUNT:
		if sim.stage_of(bed) == SimScript.STAGE_EMPTY:
			sim.choose(bed, WHEAT)
			assert_true(sim.sow_start(bed).ok and sim.sow_finish(bed).ok, "wheat sown in bed %d" % (bed + 1))
	_wither_growing(sim)
	assert_true(rows.suggest(sim), "a suggestion")
	assert_equal(rows.suggestion, "Bed 1's crop is lost: clear it and plant again.", "clear")
	assert_equal(rows.suggested_bed, 0, "bed 1")


func _wither_growing(sim: SimScript) -> void:
	"""Every bed with a crop withers."""
	for bed: int in Catalog.BED_COUNT:
		if sim.stage_of(bed) != SimScript.STAGE_EMPTY:
			sim.farming().apply_health_loss(sim.slot_of(bed), 10000)
			assert_equal(sim.stage_of(bed), SimScript.STAGE_WITHERED, "bed %d withered" % (bed + 1))


func test_a_reserved_only_pantry_is_not_empty() -> void:
	"""A harvest on its way: rows, not the empty state."""
	var pantry := _pantry()
	pantry.reserve_near_into(WHEAT, 1000, Vector2.ZERO, _read)
	var panel := _panel(SimScript.new(), pantry)
	panel.toggle()
	assert_false(panel.empty_shown(), "not empty")
	assert_equal(panel.shown_stock_row(0)[2], "1.0 U", "incoming")


func test_the_suggestion_button_opens_its_bed() -> void:
	"""The farm: the empty Pantry's "Open bed 3" closes the Pantry and opens bed 3's panel."""
	var farm := _farm()
	farm.toggle_pantry()
	assert_true(farm.pantry_panel.empty_shown(), "empty")
	farm.pantry_panel.open_bed_button().pressed.emit()
	assert_false(farm.pantry_panel.visible, "the Pantry closed")
	assert_equal(farm.selected_bed, BED_CARROTS, "bed 3 open")


func _farm() -> DemoFarmScript:
	"""The farm over the placeholder village, off-tree, with a command layer and no HUD."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var services := ServicesScript.new()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null, services)
	var farm := DemoFarmScript.new()
	_nodes.append(farm)
	var providers: Array[Callable] = []
	farm.configure({}, null, cast, command, camera, null, providers, services)
	return farm
