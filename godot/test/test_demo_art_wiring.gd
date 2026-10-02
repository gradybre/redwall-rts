extends "res://test/framework/test_case.gd"
## The art passes wired into the demo (batch 8 integration, decision 0903): icons by key from the manifest's `icons`
## section, the dishes' icons, the orchard's and the forage spots' own models (berries hidden by the tree shader), the
## infirmary's ward and herb patch, the evergreens, the authored bare oak, the tunnel's timber set and rock faces. Every
## check runs without staged assets (CI has none): the models are the world's placeholders, the pictures tiny PNGs
## written under user://, and each "staged" answer a test's own -- so the no-asset path is the same code the demo runs.

const PropsScript := preload("res://demo/props/demo_props.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const OrchardView := preload("res://demo/orchard/orchard_view.gd")
const OrchardModel := preload("res://demo/orchard/orchard_model.gd")
const OrchardRules := preload("res://demo/orchard/orchard_rules.gd")
const ForageView := preload("res://demo/forage/forage_view.gd")
const ForageRules := preload("res://demo/forage/forage_rules.gd")
const HerbPatchView := preload("res://demo/infirmary/herb_patch_view.gd")
const CareRules := preload("res://demo/infirmary/care_rules.gd")
const InfirmaryView := preload("res://demo/infirmary/infirmary_view.gd")
const Evergreens := preload("res://demo/world/evergreens.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const SeasonView := preload("res://demo/seasons/season_view.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const DressingScript := preload("res://demo/tunnel/bore_dressing.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const DIR: String = "user://art_wiring_fixture"

var _nodes: Array[Object] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			(node as Node).free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _png(file: String) -> String:
	"""A tiny picture under DIR; its path."""
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR.path_join(file + ".png")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.7, 0.3, 0.2))
	image.save_png(path)
	return path


static func _staged_all(_key: StringName) -> bool:
	"""A world that has every model staged (its placeholders still draw)."""
	return true


static func _staged_none(_key: StringName) -> bool:
	"""A world with nothing staged."""
	return false


# --- icons by key --------------------------------------------------------------------------------------------------

func test_an_icon_only_row_is_read_by_key_and_a_missing_file_is_not() -> void:
	"""The manifest's `icons` section: a row whose file exists is an icon by its key; one whose file is missing is not
	(its key falls back to the roundel); a row with no `icon` is ignored."""
	var props := PropsScript.new()
	props.load_from({"icons": {"item_apple": {"icon": _png("item_apple")},
		"item_pear": {"icon": DIR.path_join("nowhere.png")}, "item_odd": {}}})
	assert_true(props.has_icon(&"item_apple"), "the apple's icon, by key")
	assert_false(props.has_icon(&"item_pear"), "no file: no icon")
	assert_false(props.has_icon(&"item_odd"), "no path: no icon")
	assert_not_null(props.staged_icon(&"item_apple"), "the staged picture")
	assert_null(props.staged_icon(&"item_pear"), "none staged: null, not a roundel")
	var swatch := Color(0.2, 0.5, 0.3)
	assert_true(props.icon_of(&"item_pear", swatch) == props.roundel(swatch), "the roundel in its place")
	assert_true(props.icon_of(&"item_apple", swatch) != props.roundel(swatch), "the picture, not the roundel")


func test_an_item_is_drawn_by_its_key_first_and_its_model_second() -> void:
	"""farm_goods.gd: `item_<pantry key>` -- never the item's number -- then its model's icon, then its roundel."""
	assert_equal(GoodsScript.icon_key_of(Catalog.ITEM_APPLE), &"item_apple", "the apple by key")
	assert_equal(GoodsScript.icon_key_of(Catalog.ITEM_BERRIES), &"item_berries", "the one berries item by key")
	assert_equal(GoodsScript.icon_key_of(Catalog.ITEM_DRIED_FISH), &"item_dried_fish", "dried fish by key")
	var props := PropsScript.new()
	props.load_from({"icons": {"item_berries": {"icon": _png("item_berries")}}})
	var goods := GoodsScript.new(props)
	assert_true(goods.has_staged_icon(Catalog.ITEM_BERRIES), "berries' own icon (not the strawberry model's)")
	assert_false(goods.has_staged_icon(Catalog.ITEM_APPLE), "the apple: nothing staged")
	assert_true(goods.icon_of(Catalog.ITEM_APPLE) == props.roundel(Catalog.ITEM_SWATCH[Catalog.ITEM_APPLE]), "its roundel")


func test_every_dish_has_its_icon_key_by_its_recipe_key() -> void:
	"""meal_rules.gd DISH_ICON_KEYS: `dish_<key>`, a key a dish, in the book's order."""
	assert_equal(MealRules.DISH_ICON_KEYS.size(), MealRules.DISH_COUNT, "one a dish")
	for dish: int in MealRules.DISH_COUNT:
		assert_equal(MealRules.DISH_ICON_KEYS[dish], StringName("dish_" + String(MealRules.DISH_KEYS[dish])), "dish %d" % dish)
	assert_true(MealRules.DISH_ICON_KEYS.has(&"dish_nut_loaf"), "the nut loaf (the food art's dish_nut_loaf)")


# --- the orchard ------------------------------------------------------------------------------------------------------

func _view(staged: Callable) -> OrchardView:
	"""The orchard drawn with the world's placeholders, the given staged answer, at 06:00 of day 1."""
	var model := OrchardModel.new()
	model.today_hint = 1
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var view := _keep(OrchardView.new()) as OrchardView
	view.configure(model, null, world.make_piece, ServicesScript.new().props, null, null, CalendarScript.new(), staged)
	return view


func test_the_orchard_draws_the_food_art_where_it_is_staged() -> void:
	"""With the food art: the apple and pear trees by species at their shares (old 1.11), the canes and the bramble at
	size 1, and the strawberry patch as a third season slot; the berry speckle off."""
	var view := _view(_staged_all)
	assert_equal(view.tree_key(0), &"apple_tree", "the old apple")
	assert_equal(view.tree_key(1), &"pear_tree", "the old pear")
	assert_almost_equal(view.tree_size(0), OrchardView.FRUIT_OLD_SIZE, "an old tree at 1.11")
	assert_equal(view.season_tree_count(), OrchardRules.SITE_COUNT + 3, "four sites, two bushes and the patch")
	for slot: int in 3:
		assert_true(view.bush_is_art(slot), "hedge slot %d is the food art" % slot)
	assert_equal(view.season_tree_kind(OrchardRules.SITE_COUNT + 2), LookScript.KIND_FRUIT, "the patch: a fruit slot")


func test_without_the_food_art_the_orchard_draws_its_stand_ins() -> void:
	"""Nothing staged (CI): the oak and its sapling, the oak-crown bushes, five strawberry plants (no third slot)."""
	var view := _view(_staged_none)
	assert_equal(view.tree_key(0), OrchardView.TREE_KEY, "the oak")
	assert_almost_equal(view.tree_size(0), OrchardView.OLD_TREE_SIZE, "at its old share")
	assert_equal(view.season_tree_count(), OrchardRules.SITE_COUNT + 2, "two bushes")
	assert_false(view.bush_is_art(0), "the oak's crown")
	assert_equal(_view(Callable()).tree_key(1), OrchardView.TREE_KEY, "no answer at all: the stand-in")


func test_a_planted_fruit_tree_grows_through_the_food_arts_shares() -> void:
	"""A new apple: a sapling's share at first, rising; full-grown at 1.0 of its model."""
	var view := _view(_staged_all)
	var model: OrchardModel = view.get("_model")
	model.take_sapling(2, OrchardRules.APPLE, false)
	model.plant(2, OrchardRules.APPLE, 1)
	assert_equal(view.tree_key(2), &"apple_tree", "an apple from the first day")
	assert_almost_equal(view.tree_size(2), OrchardView.FRUIT_SAPLING_SIZES.x, "a sapling's share")


# --- the forage spots ---------------------------------------------------------------------------------------------------

func test_the_forage_spots_draw_their_models_only_where_staged() -> void:
	"""forage_view.gd THE SPOTS: every piece beside its spot when staged; none without; the hazels and the bramble are
	season slots, the ground cover is not; the bramble's berries are hidden by the share given."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var none := _keep(ForageView.new()) as ForageView
	assert_equal(none.place_spots(world.make_piece, _staged_none, PackedVector2Array(ForageRules.SPOT_AT)), 0, "none")
	var view := _keep(ForageView.new()) as ForageView
	var drawn: int = view.place_spots(world.make_piece, _staged_all, PackedVector2Array(ForageRules.SPOT_AT))
	assert_equal(drawn, ForageView.PIECE_KEY.size(), "every piece")
	var bushes: int = 0
	for i: int in view.season_tree_count():
		bushes += 1 if view.season_tree_node(i) != null else 0
	assert_equal(bushes, 5, "three hazels and two brambles")
	for i: int in view.season_tree_count():
		var at: Vector2 = view.season_tree_at(i)
		var spot: Vector2 = ForageRules.SPOT_AT[ForageView.PIECE_KIND[i]]
		assert_less_than(at.distance_to(spot), 3.0, "piece %d beside its spot" % i)
	view.show_berries(0.25)


func test_the_bramble_edge_is_clear_of_the_orchards_blocks() -> void:
	"""Reconciled (decision 0903): no forage spot lies in an orchard planting block."""
	for k: int in ForageRules.SPOT_AT.size():
		for site: int in OrchardRules.SITE_COUNT:
			assert_false(OrchardRules.site_rect_m(site).grow(1.0).has_point(ForageRules.SPOT_AT[k]),
				"%s clear of %s" % [ForageRules.SPOT_NAMES[k], OrchardRules.SITE_NAMES[site]])


# --- the infirmary ------------------------------------------------------------------------------------------------------

func test_the_herb_patch_model_stands_for_its_clumps() -> void:
	"""herb_patch_view.gd: the model in place of the clumps, scaled with the stock and gone when empty; the clump count
	it stands for is unchanged."""
	var patch := _keep(HerbPatchView.new()) as HerbPatchView
	patch.build(Vector2.ZERO, 0.0)
	patch.show_stock(CareRules.HERB_CAPACITY_MILLI)
	var model := Node3D.new()
	patch.use_model(model)
	assert_true(patch.has_model(), "drawn")
	assert_equal(patch.shown_clumps(), HerbPatchView.CLUMPS, "full: every clump's worth")
	assert_almost_equal(model.transform.basis.get_scale().x, 1.0, "full size")
	@warning_ignore("integer_division") var one_clump: int = CareRules.HERB_CAPACITY_MILLI / HerbPatchView.CLUMPS
	patch.show_stock(one_clump)
	assert_almost_equal(model.transform.basis.get_scale().x, HerbPatchView.MODEL_LEAST, "one clump's worth: the least")
	patch.show_stock(0)
	assert_false(model.visible, "empty: gone")
	patch.use_model(null)
	assert_true(patch.has_model(), "a null model changes nothing")


func test_the_infirmary_body_falls_back_to_its_stand_in() -> void:
	"""infirmary_view.gd: the ward's row when staged, else the residence's, else none (CI: the box)."""
	var row: Dictionary = InfirmaryView.body_row()
	var staged: bool = ResourceLoader.exists("res://demo/assets/world/infirmary_ward.glb")
	if staged:
		assert_equal(String(row["path"]), "res://demo/assets/world/infirmary_ward.glb", "the ward")
	else:
		assert_true(row.is_empty() or String(row["path"]).ends_with("residence.glb"), "the stand-in or nothing")
	assert_equal(InfirmaryView.BODY_KEY, "infirmary_ward", "the food art's ward")


# --- the evergreens and the seasons ---------------------------------------------------------------------------------------

func test_the_evergreens_stand_in_the_woods_the_same_every_run() -> void:
	"""evergreens.gd: deterministic; pines and yews in the woods past the clearing, off the paths, clear of the spots,
	each trunk an obstacle; none drawn without their models."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	world.build({"world": {}, "cast": {}})
	var first: Array[Dictionary] = Evergreens.placements(world.trees())
	assert_equal(first, Evergreens.placements(world.trees()), "the same twice")
	assert_true(first.size() >= 8, "a few of them (%d)" % first.size())
	var keys: Dictionary = {}
	for p: Dictionary in first:
		var at: Vector2 = p["at"]
		keys[p["key"]] = true
		assert_true(at.length() >= Scatter.clearing_edge(at), "in the woods")
		assert_true(Layout.path_distance(at) >= Evergreens.PATH_CLEARANCE_M, "off the paths")
		for spot: Vector2 in Evergreens.KEEP_CLEAR:
			assert_true(at.distance_to(spot) >= Evergreens.SPOT_CLEARANCE_M, "clear of the spots")
	assert_true(keys.has(Evergreens.PINE_KEY) and keys.has(Evergreens.YEW_KEY), "pines and yews")
	assert_equal(Evergreens.land_obstacles(world.trees()).size(), first.size(), "a trunk each")
	var ever := _keep(Evergreens.new()) as Evergreens
	assert_equal(ever.build(world.make_piece, _staged_none, world.trees()), 0, "nothing staged: none drawn")
	assert_equal(ever.season_tree_kind(0), LookScript.KIND_EVERGREEN, "evergreen")


func test_the_evergreens_are_drawn_at_brendans_sizes() -> void:
	"""world_sizes.gd: pine 16 m, yew 10 m (DEC-047); the season knows both as evergreens."""
	assert_almost_equal(Sizes.target_height_m(&"pine_scots"), 16.0, "the pine")
	assert_almost_equal(Sizes.target_height_m(&"yew_ancient"), 10.0, "the yew")
	assert_equal(SeasonView.KIND_OF_KEY[&"pine_scots"], LookScript.KIND_EVERGREEN, "the pine keeps its needles")
	assert_equal(SeasonView.KIND_OF_KEY[&"yew_ancient"], LookScript.KIND_EVERGREEN, "the yew too")


func test_the_authored_bare_oak_is_used_only_when_both_load() -> void:
	"""season_view.gd `use_authored_bare`: false for a missing model or bare model (the cut stays)."""
	var view := _keep(SeasonView.new()) as SeasonView
	assert_false(view.use_authored_bare("", ""), "nothing given")
	assert_false(view.use_authored_bare("res://demo/assets/world/nowhere.glb", "res://demo/assets/world/none.glb"),
		"nothing there")


# --- the tunnel ---------------------------------------------------------------------------------------------------------

func test_the_brace_is_the_timber_set_when_staged_else_the_old_brace() -> void:
	"""tunnel_marks.gd `brace_key`: the old brace while the timber set is not staged."""
	var props := PropsScript.new()
	assert_equal(MarksScript.brace_key(props), MarksScript.OLD_BRACE_KEY, "nothing staged: the old brace")
	assert_equal(MarksScript.BRACE_KEY, &"tunnel_set", "the timber set's key")
	assert_true(PropsScript.is_known(&"tunnel_set"), "sized")


static func _all_rock(_x_u: int, _z_u: int, _level: int) -> int:
	"""Ground that is rock everywhere."""
	return GroundScript.ROCK


static func _all_loam(_x_u: int, _z_u: int, _level: int) -> int:
	"""Ground that is loam everywhere."""
	return GroundScript.LOAM


func test_rock_faces_stand_where_the_ground_is_rock() -> void:
	"""bore_dressing.gd ROCK FACES: a rock step dresses its walls (every ROCK_EVERY rings); loam none; no model none."""
	var dressing := _keep(DressingScript.new()) as DressingScript
	dressing.configure()
	dressing.set_rock(BoxMesh.new(), Transform3D.IDENTITY, _all_rock)
	dressing.call(&"_ensure", 0)
	dressing.call(&"_dress_rock", 0, 12345, Vector3(1.0, -1.5, 2.0), Vector2(1.0, 0.0), TunnelRules.BORE_STANDARD)
	assert_true(dressing.rocks(0).multimesh.visible_instance_count >= 1, "rock: a face against a wall")
	var loam := _keep(DressingScript.new()) as DressingScript
	loam.configure()
	loam.set_rock(BoxMesh.new(), Transform3D.IDENTITY, _all_loam)
	loam.call(&"_ensure", 0)
	loam.call(&"_dress_rock", 0, 12345, Vector3(1.0, -1.5, 2.0), Vector2(1.0, 0.0), TunnelRules.BORE_STANDARD)
	assert_equal(loam.rocks(0).multimesh.visible_instance_count, 0, "loam: none")
	var bare := _keep(DressingScript.new()) as DressingScript
	bare.configure()
	bare.call(&"_ensure", 0)
	assert_null(bare.rocks(0), "no rock face staged: no rock MultiMesh")
