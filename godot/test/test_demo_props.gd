extends "res://test/framework/test_case.gd"
## The live demo's asset pass (decision 0196): the staged props table and its placeholders and icons,
## the farm's goods (models, icons, hand fit), harvests carried as themselves, the stores' shelves,
## finds lying where they were dug and on the tunnel panel, the tunnel's brace, lantern and rubble
## swaps, and the rooms' furniture. Nothing here needs staged assets: CI has none, so every model
## is its placeholder box and every icon a roundel -- the same code the staged demo runs.

const PropsScript := preload("res://demo/props/demo_props.gd")
const ShelfScript := preload("res://demo/props/store_shelf.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const CarryViewScript := preload("res://demo/farm/farm_carry_view.gd")
const StockViewScript := preload("res://demo/farm/farm_stock_view.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const FindPropsScript := preload("res://demo/tunnel/tunnel_find_props.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const PanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const AssetsScript := preload("res://demo/farm/farm_assets.gd")
const BedVisualScript := preload("res://demo/farm/farm_bed_visual.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = 2500000
const CARROT: int = 2
const PARSNIP: int = 4
const BED_CARROTS: int = 2

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


# --- the props table ----------------------------------------------------------------------------

func test_every_prop_has_a_positive_demo_size_and_a_rule() -> void:
	"""Every sized key measures its height or its longest side, at a size above zero; the two
	buildings are drawn at their authoritative envelope (cellar 2.0 m, composter 1.25 m)."""
	for key: StringName in PropsScript.SIZES:
		assert_true(PropsScript.drawn_size_m(key) > 0.0, "%s has a size" % key)
		assert_true(PropsScript.rule_of(key) in [PropsScript.RULE_HEIGHT, PropsScript.RULE_LONGEST], "%s has a rule" % key)
	assert_almost_equal(PropsScript.drawn_size_m(&"cellar"), 2.0, "the cellar's envelope")
	assert_almost_equal(PropsScript.drawn_size_m(&"composter"), 1.25, "the composter's envelope")
	assert_true(PropsScript.is_known(&"cellar") and not PropsScript.is_known(&"dragon"), "known keys only")


func test_scale_measures_height_or_the_longest_side_by_rule() -> void:
	"""A lantern (by height) 1.9 units tall draws 0.36 m; a trout (by length) 1.9 long and 0.5 tall
	draws 0.45 m long; a flat bound refuses to scale (1.0)."""
	var tall := PropsScript.scale_for(&"wall_lantern", Vector3(-0.3, 0.0, -0.3), Vector3(0.3, 1.9, 0.3))
	assert_almost_equal(tall * 1.9, 0.36, "lantern height")
	var fish := PropsScript.scale_for(&"item_trout", Vector3(-0.95, 0.0, -0.2), Vector3(0.95, 0.5, 0.2))
	assert_almost_equal(fish * 1.9, 0.45, "trout length")
	assert_almost_equal(PropsScript.scale_for(&"item_trout", Vector3.ZERO, Vector3.ZERO), 1.0, "flat: refused")


func test_an_unstaged_prop_is_a_box_of_its_size_standing_on_the_ground() -> void:
	"""Nothing staged: a standing prop is a box its drawn height tall; a lying one its drawn length
	long; either stands on y = 0, centred."""
	var props := PropsScript.new()
	props.load_from({"world": {}})
	assert_false(props.is_staged(&"wall_lantern"), "not staged")
	var lantern: AABB = props.drawn_bound(&"wall_lantern")
	assert_almost_equal(lantern.size.y, 0.36, "lantern box height")
	assert_almost_equal(lantern.position.y, 0.0, "on the ground")
	var boat: AABB = props.drawn_bound(&"boat_rowboat")
	assert_almost_equal(boat.size.x, 3.2, "rowboat box length")
	assert_almost_equal(boat.get_center().x, 0.0, "centred")
	assert_true(props.mesh_of(&"boat_rowboat") == props.mesh_of(&"boat_rowboat"), "one mesh shared per key")


func test_a_row_whose_model_is_missing_is_not_staged() -> void:
	"""A manifest row pointing at no file stays a placeholder (a fresh clone with an old manifest)."""
	var props := PropsScript.new()
	props.load_from({"world": {"item_carrot": {"path": "res://demo/assets/props/nowhere.glb",
		"aabb_min": [0, 0, 0], "aabb_max": [1, 1, 1], "icon": "res://demo/assets/icons/nowhere.png"}}})
	assert_false(props.is_staged(&"item_carrot"), "not staged")
	assert_false(props.has_icon(&"item_carrot"), "no icon")


func test_a_missing_icon_is_a_roundel_in_the_swatch_ringed_in_brass() -> void:
	"""The fallback icon: the swatch at the disc's middle (lit), brass at its rim, clear at the corner;
	one texture per colour."""
	var props := PropsScript.new()
	var swatch := Color(0.2, 0.4, 0.22)
	var image: Image = PropsScript.roundel_image(swatch)
	var middle: Color = image.get_pixel(PropsScript.ROUNDEL_PX / 2, PropsScript.ROUNDEL_PX / 2)
	assert_less_than(absf(middle.g - swatch.g), 0.08, "the swatch at the middle")
	var rim: Color = image.get_pixel(PropsScript.ROUNDEL_PX / 2, 1)
	assert_less_than(absf(rim.r - Palette.BRASS.r) + absf(rim.g - Palette.BRASS.g) + absf(rim.b - Palette.BRASS.b), 0.02,
		"brass at the rim")
	assert_almost_equal(image.get_pixel(0, 0).a, 0.0, "clear at the corner")
	assert_true(props.icon_of(&"item_carrot", swatch) == props.roundel(swatch), "unstaged: the roundel, shared")


# --- the farm's goods ---------------------------------------------------------------------------

func test_eleven_items_have_their_own_model_and_five_a_roundel() -> void:
	"""ITEM_PROP names a library item for eleven farmed items; parsnip, cabbage, spinach, broad bean and
	wheat have none, and every named key is a sized prop."""
	var goods := GoodsScript.new()
	var without: PackedStringArray = PackedStringArray()
	for item: int in Catalog.ITEM_COUNT:
		if goods.has_model(item):
			assert_true(PropsScript.is_known(Catalog.ITEM_PROP[item]), "%s is sized" % Catalog.ITEM_PROP[item])
			assert_true(String(Catalog.ITEM_PROP[item]).begins_with("item_"), "an item model")
		else:
			without.append(String(Catalog.ITEM_KEYS[item]))
	assert_equal(without, PackedStringArray(["parsnip", "cabbage", "spinach", "broad_bean", "wheat"]), "five without")
	assert_false(goods.has_model(Catalog.NO_ITEM), "no item: no model")
	assert_false(goods.has_staged_icon(CARROT), "nothing staged")
	assert_true(goods.icon_of(PARSNIP) == goods.props.roundel(Catalog.ITEM_SWATCH[PARSNIP]), "parsnip's roundel")


func test_a_held_item_is_centred_on_the_hands() -> void:
	"""hand_fit puts the item's drawn bound's centre at the origin (the hands' midpoint)."""
	var goods := GoodsScript.new()
	var bound: AABB = goods.hand_fit(CARROT) * goods.props.mesh_of(&"item_carrot").get_aabb()
	assert_true(bound.get_center().is_equal_approx(Vector3.ZERO), "centred")
	assert_almost_equal(bound.size.x, 0.42, "at its carried size")


# --- every crop its own plant --------------------------------------------------------------------

func test_eleven_crops_grow_their_own_plant_and_five_borrow() -> void:
	"""Each item with a library plant draws that plant (pea from plant_peas); wheat its grain cards,
	parsnip the roots bed's carrots, cabbage and spinach its turnips (and heads when ripe), broad bean
	the pea."""
	var own: int = 0
	for item: int in Catalog.ITEM_COUNT:
		var kind: int = Catalog.ITEM_VISUAL[item]
		assert_true(kind >= 0 and kind < Catalog.VIS_COUNT, "%s has a kind" % Catalog.ITEM_KEYS[item])
		if Catalog.is_plant_kind(kind) and String(Catalog.plant_key_of(kind)).begins_with("plant_" + String(Catalog.ITEM_KEYS[item])):
			own += 1
	assert_equal(own, 11, "eleven on their own plant")
	assert_equal(Catalog.ITEM_VISUAL[Catalog.ITEM_KEYS.find(&"wheat")], Catalog.VIS_WHEAT, "wheat: grain cards")
	assert_equal(Catalog.ITEM_VISUAL[PARSNIP], Catalog.VIS_CARROT, "parsnip: the roots bed's carrots")
	for leaf: StringName in [&"cabbage", &"spinach"]:
		var item: int = Catalog.ITEM_KEYS.find(leaf)
		assert_true(Catalog.ITEM_VISUAL[item] == Catalog.VIS_TURNIP and Catalog.ITEM_RIPE_HEADS[item], "%s: turnip cards, heads" % leaf)
	assert_equal(Catalog.plant_key_of(Catalog.ITEM_VISUAL[Catalog.ITEM_KEYS.find(&"broad_bean")]), &"plant_peas", "broad bean: the pea")
	assert_equal(Catalog.VIS_COUNT, Catalog.VIS_PLANT_FIRST + Catalog.PLANT_KEYS.size(), "one kind per plant")
	for column: Array in [Catalog.PLANT_HEIGHT_M, Catalog.PLANT_SPACING, Catalog.PLANT_TOP_LIFT, Catalog.PLANT_TOP_SCALE]:
		assert_equal(column.size(), Catalog.PLANT_KEYS.size(), "a value per plant")


func test_each_stage_shows_its_subset_of_the_plant_cells() -> void:
	"""Sprout: sparse; young: sparse and thinned; filling out: thinned; nearly grown: all three views;
	ripe: the full plant from front and side; withered: thinned and sparse; blighted: the full plant."""
	assert_equal(Look.stage_cells(SimScript.STAGE_SPROUTING, 50), [Look.CELL_SPARSE], "sprout")
	assert_equal(Look.stage_cells(SimScript.STAGE_GROWING, 349), [Look.CELL_SPARSE, Look.CELL_THINNED], "young")
	assert_equal(Look.stage_cells(SimScript.STAGE_GROWING, 350), [Look.CELL_THINNED], "filling from 350")
	assert_equal(Look.stage_cells(SimScript.STAGE_GROWING, 699), [Look.CELL_THINNED], "filling to 699")
	assert_equal(Look.stage_cells(SimScript.STAGE_GROWING, 700), [Look.CELL_FULL, Look.CELL_SIDE, Look.CELL_THINNED], "full from 700")
	assert_equal(Look.stage_cells(SimScript.STAGE_RIPE, 1000), [Look.CELL_FULL, Look.CELL_SIDE], "ripe")
	assert_equal(Look.stage_cells(SimScript.STAGE_WITHERED, 1000), [Look.CELL_THINNED, Look.CELL_SPARSE], "withered")
	assert_equal(Look.stage_cells(SimScript.STAGE_BLIGHTED, 400), [Look.CELL_FULL, Look.CELL_SIDE, Look.CELL_THINNED], "blighted")


func test_withered_and_blighted_read_apart() -> void:
	"""Withered: slumped, drooping, bleached to straw, unspotted. Blighted: standing, unslumped,
	barely bleached, spotted. Their tints differ, and neither is a healthy stage's."""
	assert_almost_equal(Look.limp(SimScript.STAGE_WITHERED), 0.72, "withered slumps")
	assert_almost_equal(Look.limp(SimScript.STAGE_BLIGHTED), 1.0, "blighted stands")
	assert_true(Look.droop(SimScript.STAGE_WITHERED) > 0.0 and Look.droop(SimScript.STAGE_BLIGHTED) == 0.0, "only withered droops")
	assert_true(Look.bleach(SimScript.STAGE_WITHERED) > Look.bleach(SimScript.STAGE_BLIGHTED), "withered bleaches more")
	assert_almost_equal(Look.spots(SimScript.STAGE_BLIGHTED), 1.0, "blight spots")
	assert_almost_equal(Look.spots(SimScript.STAGE_WITHERED), 0.0, "withered has no spots")
	assert_almost_equal(Look.bleach(SimScript.STAGE_RIPE) + Look.spots(SimScript.STAGE_RIPE), 0.0, "a ripe bed neither")
	assert_true(Look.plant_tint(SimScript.STAGE_WITHERED, CARROT, 1000) != Look.plant_tint(SimScript.STAGE_BLIGHTED, CARROT, 1000),
		"tints differ")


func test_a_bed_shows_the_stage_cells_and_a_withered_bed_slumps() -> void:
	"""A radish bed: sprouting, every plant shows the sparse cell; ripe, only full and side; withered,
	each plant keeps 0.72 of its height against its width."""
	var visual: BedVisualScript = _keep(BedVisualScript.new())
	visual.build(0, AssetsScript.new())
	visual.show_state(SimScript.STAGE_SPROUTING, 0, 100, SimScript.BAND_GOOD, 0, "Radish", "sprout")
	assert_true(Catalog.is_plant_kind(visual.visual_kind()), "a plant kind")
	for i: int in visual.plant_count():
		assert_equal(visual.cell_shown(i), Look.CELL_SPARSE, "sprout %d sparse" % i)
	visual.show_state(SimScript.STAGE_RIPE, 0, 1000, SimScript.BAND_GOOD, 0, "Radish", "ripe")
	var seen := {}
	for i: int in visual.plant_count():
		seen[visual.cell_shown(i)] = true
	assert_equal(seen.keys().size(), 2, "ripe: two cells")
	assert_true(seen.has(Look.CELL_FULL) and seen.has(Look.CELL_SIDE), "full and side")
	var slumped: Transform3D = visual.plant_transform(0, 0.72, 0.0, Look.limp(SimScript.STAGE_WITHERED))
	assert_almost_equal(slumped.basis.get_scale().y / slumped.basis.get_scale().x, 0.72, "slumped")


func test_plant_cards_are_sized_to_the_plant_and_planted_by_its_width() -> void:
	"""A plant card 1.2 source units tall in a bed drawn 1.5 m a unit, the radish 0.38 m tall: 0.38 /
	1.8 bed units per source unit. A grid over a 0.86 half-width bed of plants 0.3 wide at 0.62 of
	their width: floor(1.56 / 0.186) = 8 a side; never under 3 or over 14."""
	assert_almost_equal(AssetsScript.plant_units(Catalog.VIS_PLANT_FIRST, 1.2, 1.5), 0.38 / 1.8, "units")
	assert_equal(AssetsScript.plant_grid(0.3, 0.86, 0.62), Vector2i(8, 8), "8 x 8")
	assert_equal(AssetsScript.plant_grid(5.0, 0.86, 0.62), Vector2i(3, 3), "at least 3")
	assert_equal(AssetsScript.plant_grid(0.01, 0.86, 0.62), Vector2i(14, 14), "at most 14")


func test_a_staged_plant_takes_its_cards() -> void:
	"""A manifest plant row whose atlas loads: the kind has its cards, four variants, cells in bed
	units, a grid by its spacing; a plant not staged stays a placeholder."""
	var path := "user://test_demo_props_plant.png"
	var image := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.6, 0.3, 1.0))
	image.save_png(path)
	var assets := AssetsScript.new()
	assets.load_from({"world": {"plant_turnip": {"cards": {"texture": path, "variants": 4, "cell_m": [1.9, 1.1]}}}})
	var kind: int = Catalog.VIS_PLANT_FIRST + 1
	assert_true(assets.has_cards(kind), "turnip staged")
	assert_false(assets.has_cards(Catalog.VIS_PLANT_FIRST), "radish not")
	assert_null(assets.card_texture[kind], "its atlas not read until a bed shows it")
	assets.ensure_loaded(kind)
	assert_not_null(assets.card_texture[kind], "read on first use")
	assert_equal(assets.variants[kind], 4, "four cells")
	var to_bed: float = AssetsScript.plant_units(kind, 1.1, assets.bed_scale)
	assert_true(assets.card_cell[kind].is_equal_approx(Vector2(1.9, 1.1) * to_bed), "cells in bed units")
	assert_equal(assets.grid[kind], AssetsScript.plant_grid(1.9 * to_bed, assets.inner_half, Catalog.PLANT_SPACING[1]), "its grid")
	var barley := AssetsScript.new()
	barley.load_from({"world": {"plant_barley": {"cards": {"texture": path, "variants": 4, "cell_m": [1.9, 1.8]}}}})
	var grain: int = Catalog.VIS_PLANT_FIRST + 9
	var width: float = 1.9 * AssetsScript.plant_units(grain, 1.8, barley.bed_scale)
	assert_equal(barley.grid[grain], AssetsScript.plant_grid(width, barley.inner_half, 0.34), "barley planted at its own 0.34")
	assert_true(barley.grid[grain].x > AssetsScript.plant_grid(width, barley.inner_half, 0.62).x, "closer than a rosette")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


const LETTUCE_PNG: String = "user://test_demo_props_lettuce.png"
const LETTUCE_TSCN: String = "user://test_demo_props_lettuce.tscn"


func _staged_lettuce() -> AssetsScript:
	"""Farm assets with a lettuce staged: an atlas, and a scene holding a box as its close-up mesh."""
	var image := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.8, 0.4, 1.0))
	image.save_png(LETTUCE_PNG)
	var holder := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = StandardMaterial3D.new()
	holder.mesh = box
	var scene := PackedScene.new()
	scene.pack(holder)
	holder.free()
	ResourceSaver.save(scene, LETTUCE_TSCN)
	var assets := AssetsScript.new()
	assets.load_from({"world": {"plant_lettuce": {"path": LETTUCE_TSCN,
		"cards": {"texture": LETTUCE_PNG, "variants": 4, "cell_m": [1.9, 0.9]}}}})
	return assets


func test_a_ripe_lettuce_bed_draws_heads_not_cards() -> void:
	"""A staged lettuce (its cards and its close-up mesh): young, cards; filled out (700) and ripe, the
	head mesh at the plant's height in bed units, the cards hidden; withered, cards again. Only the
	lettuce is a head plant."""
	var assets: AssetsScript = _staged_lettuce()
	var kind: int = Catalog.VIS_PLANT_FIRST + 6
	assert_not_null(assets.head_mesh[kind], "the lettuce's head mesh")
	assert_null(assets.head_mesh[Catalog.VIS_PLANT_FIRST], "the radish has none")
	assert_equal(Catalog.PLANT_HEAD_MESH.count(true), 1, "one head plant")
	assert_true(Catalog.PLANT_HEAD_MESH[Catalog.PLANT_KEYS.find(&"plant_lettuce")], "the lettuce")
	assert_almost_equal(assets.head_fit[kind].basis.get_scale().x, AssetsScript.plant_units(kind, 0.9, assets.bed_scale), "sized as its cards")
	var lettuce: int = Catalog.ITEM_KEYS.find(&"lettuce")
	var visual: BedVisualScript = _keep(BedVisualScript.new())
	visual.build(0, assets)
	visual.show_state(SimScript.STAGE_GROWING, lettuce, 400, SimScript.BAND_GOOD, 0, "Lettuce", "young")
	assert_false(visual.showing_head_meshes(), "young: cards")
	assert_true(visual.showing_cards(), "the cards shown")
	assert_not_null(assets.card_texture[kind], "the bed read the lettuce's atlas when it first showed it")
	visual.show_state(SimScript.STAGE_GROWING, lettuce, 700, SimScript.BAND_GOOD, 0, "Lettuce", "filled")
	assert_true(visual.showing_head_meshes(), "filled out: heads")
	assert_false(visual.showing_cards(), "and the cards hidden")
	visual.show_state(SimScript.STAGE_RIPE, lettuce, 1000, SimScript.BAND_GOOD, 0, "Lettuce", "ripe")
	assert_true(visual.showing_head_meshes(), "ripe: heads")
	visual.show_state(SimScript.STAGE_WITHERED, lettuce, 1000, SimScript.BAND_GOOD, 0, "Lettuce", "withered")
	assert_false(visual.showing_head_meshes(), "withered: cards")
	for path: String in [LETTUCE_PNG, LETTUCE_TSCN]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- carrying and shelving ----------------------------------------------------------------------

func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new())
	var cast: DemoCastScript = _keep(DemoCastScript.new())
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	return cast


func _run(cast: DemoCastScript, crew: CrewScript, carry: CarryViewScript, seconds: float, done: Callable) -> bool:
	"""Step the cast, the crew and the carry view at 60 Hz until `done()` or `seconds` pass."""
	for frame: int in roundi(seconds / DT):
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
		carry.refresh()
		if done.call():
			return true
	return false


func test_a_harvest_is_carried_as_its_own_model_and_put_down_at_the_store() -> void:
	"""Ripe carrots hauled with the carry walk: the carrier holds the carrot model, not the log, all
	the way to the store; delivered, its hands are empty and the carrots are on the store's shelf."""
	var cast := _cast()
	var sim := SimScript.new()
	var pantry := PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast)))
	var crew := CrewScript.new()
	crew.configure(cast, sim, pantry, TunnelsScript.new(), DemoFarmScript.well_position(), func(_t: String) -> void: pass)
	crew.set_crew(PackedInt32Array([0]))
	var goods := GoodsScript.new()
	var carry := CarryViewScript.new()
	carry.configure(cast, crew.jobs, goods)
	var carrier := cast.actor(3) as DemoActorScript
	carrier.brain.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.2]], "mean_speed_m_s": 0.2, "period_s": 1.0})
	sim.advance_usec(24 * HOUR_USEC)
	crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var hauling := func() -> bool: return crew.jobs.current_step(0) == JobsScript.STEP_CARRY_STORE and carrier.brain.carrying
	assert_true(_run(cast, crew, carry, 120.0, hauling), "hauling")
	assert_equal(carry.held_item(3), CARROT, "holding the carrots")
	assert_true(carrier.holding() and carrier.held_mesh() == goods.props.mesh_of(&"item_carrot"), "the carrot model")
	cast.advance(DT)
	var held := carrier.find_child("Held", false, false) as MeshInstance3D
	assert_true(held != null and held.visible, "shown on the carry walk")
	assert_true(_run(cast, crew, carry, 180.0, func() -> bool: return pantry.total_units() > 0), "delivered")
	assert_false(carrier.holding(), "hands empty at the store")
	var stock: StockViewScript = _keep(StockViewScript.new())
	stock.configure(pantry, goods)
	stock.refresh()
	assert_equal(stock.shelf(0).good_key(0), &"item_carrot", "on the store's shelf")


func test_a_harvest_in_hand_is_read_from_the_job_board() -> void:
	"""No job: refused NOT_ON_A_JOB; a harvest job with no load yet: NO_HARVEST_IN_HAND; with its load:
	the item."""
	var jobs := JobsScript.new()
	assert_false(CarryViewScript.harvest_in_hand_into(jobs, 0, _read), "no job")
	assert_equal(_read.error, CarryViewScript.REFUSE_NO_JOB, "said so")
	assert_true(jobs.open_into(JobsScript.KIND_HARVEST, BED_CARROTS, JobsScript.ORIGIN_PLAYER, 0, _read), "opened")
	var row: int = _read.value
	jobs.assign(row, 0)
	assert_false(CarryViewScript.harvest_in_hand_into(jobs, 0, _read), "nothing cut yet")
	assert_equal(_read.error, CarryViewScript.REFUSE_NO_LOAD, "said so")
	jobs.load_item[row] = CARROT
	jobs.load_milli[row] = 5100
	assert_true(CarryViewScript.harvest_in_hand_into(jobs, 0, _read), "carrying")
	assert_equal(_read.value, CARROT, "the carrots")
	jobs.load_milli[row] = 0
	assert_false(CarryViewScript.harvest_in_hand_into(jobs, 0, _read), "delivered: the item named, nothing in hand")
	jobs.load_milli[row] = 5100
	jobs.kind[row] = JobsScript.KIND_BANK
	assert_false(CarryViewScript.harvest_in_hand_into(jobs, 0, _read), "spoil is not a harvest")


func test_a_shelf_shows_a_jar_per_started_third_and_its_goods_in_order() -> void:
	"""Empty: no jars; 1 per mille: one; 334: two; 1000: three. Goods fill the slots in the order given,
	a good with no model skipped, the rest of the slots emptied."""
	assert_equal(ShelfScript.jars_for(0), 0, "empty")
	assert_equal(ShelfScript.jars_for(1), 1, "a first jar")
	assert_equal(ShelfScript.jars_for(333), 1, "a third")
	assert_equal(ShelfScript.jars_for(334), 2, "past a third")
	assert_equal(ShelfScript.jars_for(1000), 3, "full")
	var shelf: ShelfScript = _keep(ShelfScript.new())
	shelf.build(PropsScript.new())
	var keys: Array[StringName] = [&"item_leek", &"", &"item_onion"]
	shelf.show_stock(500, keys)
	assert_equal(shelf.shown_jars(), 2, "half full")
	assert_equal(shelf.shown_goods(), 2, "two goods")
	assert_equal([shelf.good_key(0), shelf.good_key(1), shelf.good_key(2)], [&"item_leek", &"item_onion", &""], "in order")
	var fewer: Array[StringName] = [&"item_peas"]
	shelf.show_stock(0, fewer)
	assert_equal(shelf.shown_goods(), 1, "the slot emptied")
	assert_equal(shelf.shown_jars(), 0, "no jars")


func test_the_store_shelf_lists_its_goods_most_first_and_cellars_wait_for_their_room() -> void:
	"""Onions 3 U and carrots 7 U in the covered store: carrots, then onions; fill 25 per mille of
	400 U. A cellar location with no rooms to find it in shows no shelf."""
	var storage := StorageScript.new(Vector2.ZERO)
	storage.add_provider(func() -> Array: return [{"id": &"root_cellar:0:1", "position": Vector2(1, 1),
		"capacity_u": 60, "spoilage_permille": 350}])
	var pantry := PantryScript.new(storage)
	assert_true(pantry.add_into(Catalog.ITEM_KEYS.find(&"onion"), 3000, 0, _read), "onions in")
	assert_true(pantry.add_into(CARROT, 7000, 0, _read), "carrots in")
	var stock: StockViewScript = _keep(StockViewScript.new())
	stock.configure(pantry, GoodsScript.new())
	stock.refresh()
	assert_equal(stock.fill_permille(0), 25, "10 of 400 U")
	assert_equal([stock.shelf(0).good_key(0), stock.shelf(0).good_key(1)], [&"item_carrot", &"item_onion"], "most first")
	assert_true(stock.shelf(0).visible, "the store's shelf shows")
	assert_false(stock.shelf(1).visible, "the cellar's waits for its room")


# --- finds ---------------------------------------------------------------------------------------

func test_finds_and_relics_have_their_models() -> void:
	"""A flint, clay and a root store show as their models; relics by story: the bell first, then four
	without a model, the key and the banner, cycling."""
	assert_equal(FindsScript.model_of(FindsScript.FIND_FLINT, 0), &"find_flint", "flint")
	assert_equal(FindsScript.model_of(FindsScript.FIND_CLAY, 0), &"find_clay", "clay")
	assert_equal(FindsScript.model_of(FindsScript.FIND_ROOT_STORE, 0), &"basket", "an old basket")
	assert_equal(FindsScript.model_of(FindsScript.FIND_RELIC, 1), &"relic_bell", "the bell story")
	assert_equal(FindsScript.model_of(FindsScript.FIND_RELIC, 2), &"", "the spoon has no model")
	assert_equal(FindsScript.model_of(FindsScript.FIND_RELIC, 6), &"relic_key", "the key")
	assert_equal(FindsScript.model_of(FindsScript.FIND_RELIC, 7), &"relic_banner", "the banner")
	assert_equal(FindsScript.model_of(FindsScript.FIND_RELIC, 8), &"relic_bell", "cycling")
	assert_equal(FindsScript.RELIC_MODEL.size(), FindsScript.RELIC_STORIES.size(), "one model slot per story")
	for kind: int in [FindsScript.FIND_FLINT, FindsScript.FIND_CLAY, FindsScript.FIND_ROOT_STORE]:
		assert_true(PropsScript.is_known(FindsScript.FIND_MODEL[kind]), "a sized prop")


func _works_with_finds() -> WorksScript:
	"""Tunnel works over a placeholder cast with two finds recorded: a flint and the first relic."""
	var cast := _cast()
	var works: WorksScript = _keep(WorksScript.new())
	var brains: Array[BrainScript] = []
	works.setup(cast.space(), brains, PackedStringArray(), Rect2i(-20480, -20480, 40960, 40960), Callable())
	works.stores.add_find(FindsScript.FIND_FLINT)
	works._record_find(-1, Vector2i(2048, 1024), FindsScript.FIND_FLINT)
	works.stores.add_find(FindsScript.FIND_RELIC)
	works._record_find(-1, Vector2i(4096, 1024), FindsScript.FIND_RELIC)
	return works


func test_finds_lie_where_they_were_cut_in_the_underground_view() -> void:
	"""Two finds recorded: both drawn at their cuts on the bore floor, the relic as the bell -- on the
	underground layer, which only the U view draws (decision 0206)."""
	var works := _works_with_finds()
	assert_equal(works.found_count, 2, "two recorded")
	assert_equal(works.found_relic[1], 1, "the first relic")
	var view: FindPropsScript = _keep(FindPropsScript.new())
	view.configure(works, works._network, PropsScript.new())
	view.refresh()
	assert_equal(view.shown_count(), 2, "both below")
	var bell := view.get_child(1) as MeshInstance3D
	assert_equal(bell.layers, Layers.UNDERGROUND, "on the underground layer")
	assert_true(bell.mesh is BoxMesh, "the bell's placeholder")
	assert_almost_equal(bell.position.x, 4.0, "at its cut (x)")
	assert_almost_equal(bell.position.y, -Rules.BORE_FLOOR_DEPTH_M + PropsScript.placeholder_size(&"relic_bell").y * 0.5,
		"on the bore floor (a box's centre half its height up)")


func test_the_ring_keeps_the_latest_finds() -> void:
	"""FOUND_RING + 1 finds: the first entry is overwritten by the last."""
	var works := _works_with_finds()
	for k: int in WorksScript.FOUND_RING - 1:
		works._record_find(-1, Vector2i(k * 1024, 0), FindsScript.FIND_CLAY)
	assert_equal(works.found_count, WorksScript.FOUND_RING + 1, "counted")
	assert_equal(works.found_kind[0], FindsScript.FIND_CLAY, "the oldest overwritten")
	assert_equal(works.found_kind[1], FindsScript.FIND_RELIC, "the next kept")


func test_the_panel_shows_a_finds_shelf() -> void:
	"""Three icons with counts: 2, 1, and a relic with no number; the rest hidden."""
	var panel: PanelScript = _keep(PanelScript.new())
	panel.build()
	var props := PropsScript.new()
	var icons: Array[Texture2D] = [props.roundel(Color.RED), props.roundel(Color.BLUE), props.roundel(Color.GREEN)]
	panel.show_finds(icons, PackedInt32Array([2, 1, 0]))
	assert_equal(panel.finds_shown(), 3, "three shown")
	icons.resize(1)
	panel.show_finds(icons, PackedInt32Array([4]))
	assert_equal(panel.finds_shown(), 1, "one left")


# --- the tunnel's brace, lanterns and rubble ------------------------------------------------------

func _dug_network() -> GraphScript:
	"""A network with one finished 16 m tunnel along +X from (0, 0), every segment dug: its entry ramp is
	segment 0 (0..4 m), its 8 m standard level bore segment 1 (from (4, 0) to (12, 0)), its exit ramp
	segment 2 (12..16 m)."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	return network


func test_lanterns_hang_on_alternate_walls_facing_into_the_bore() -> void:
	"""A lantern hung on the left wall of the level bore stands left of the centre line with its +X (its
	bracket's wall plate) turned to that wall, LANTERN_LIFT_M above the floor; the next one is on the right
	wall."""
	var network := _dug_network()
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, null, PropsScript.new())
	var left: Transform3D = marks.lantern_transform(1, 4.0, true)
	var right: Transform3D = marks.lantern_transform(1, 4.0, false)
	assert_true(left.origin.z > 0.0 and right.origin.z < 0.0, "opposite walls (bore along +X)")
	assert_true(left.basis.x.dot(Vector3(0.0, 0.0, 1.0)) > 0.99, "the left one's bracket to the left wall")
	assert_true(right.basis.x.dot(Vector3(0.0, 0.0, -1.0)) > 0.99, "the right one's to the right wall")
	assert_almost_equal(left.origin.x, 8.0, "4 m into the bore, which starts at the entry ramp's foot (4, 0)")
	assert_almost_equal(left.origin.y, network.floor_y_at(1, 4.0) + MarksScript.LANTERN_LIFT_M, "hung up the wall")
	assert_true(marks.frame_mesh_fit().is_equal_approx(Transform3D.IDENTITY), "unstaged: the box frame as it was")


func test_a_lit_braced_tunnel_shows_frames_lanterns_and_glows_below() -> void:
	"""Braced and lit, per segment: the 8 m level bore a frame a metre (1 to 8 m: eight, all under the
	ground; the one at its start, the entry ramp's foot, is the ramp's), two lanterns (one per started 4 m)
	and their two glows, on the underground layer (the U view draws them; decision 0206), their light
	lighting only that layer. Each 4 m ramp is framed only where it is wholly under the ground -- past its
	portal, 2.94 m from its mouth: the entry ramp at 3 and 4 m from its node A mouth, the exit ramp at 1 m
	from its node A foot (the bore frames the foot) -- and hangs one lantern."""
	var network := _dug_network()
	for slot in 3:
		network.set_braced(slot)
		network.set_lit(slot)
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, null, PropsScript.new())
	marks.refresh()
	for node: VisualInstance3D in [marks.frames(1), marks.lanterns(1), marks.glows(1)]:
		assert_equal(node.layers, Layers.UNDERGROUND, "%s below" % node.name)
	assert_equal(marks.lanterns(1).multimesh.visible_instance_count, 2, "two lanterns")
	assert_equal(marks.glows(1).multimesh.visible_instance_count, 2, "two glows")
	assert_true(marks.glows(1).visible and marks.lanterns(1).visible, "shown")
	assert_equal(marks.frames(1).multimesh.visible_instance_count, 8, "a frame a metre, none doubled at the foot")
	assert_equal(marks.frames(0).multimesh.visible_instance_count, 2, "the entry ramp: framed past its portal only")
	assert_equal(marks.frames(2).multimesh.visible_instance_count, 1, "the exit ramp: past its foot, short of its portal")
	for ramp: int in [0, 2]:
		assert_equal(marks.lanterns(ramp).multimesh.visible_instance_count, 1, "ramp %d: one lantern" % ramp)
	assert_equal(marks.lights.spot_count(), 4, "four lights to give: two in the bore, one a ramp")


# --- the water's props ---------------------------------------------------------------------------

func test_boats_float_and_the_jetty_deck_stands_above_the_water() -> void:
	"""Every boat's base lies below the water's surface and its top above it; each stands on water
	in the map; the jetty's deck (66% up the model) is 0.22 m above the surface. No bridge is placed."""
	var props := PropsScript.new()
	var map: WaterMapScript = WaterLayout.make_map()
	var surface: float = -float(WaterLayout.LEVEL_DROP_U) / 1024.0
	for p: Dictionary in WaterDressing.PROP_PLACEMENTS:
		var key: StringName = p["key"]
		assert_true(PropsScript.is_known(key), "%s is sized" % key)
		assert_false(String(key).begins_with("bridge_"), "no bridge placed")
		if String(key).begins_with("boat_"):
			var piece: MeshInstance3D = _keep(WaterDressing.prop_piece(props, p))
			var bound: AABB = piece.transform * piece.mesh.get_aabb()
			assert_true(bound.position.y < surface and bound.end.y > surface, "%s floats" % key)
			var at: Vector2 = p["at"]
			assert_true(map.is_water(Vector2i(roundi(at.x * 1024.0), roundi(at.y * 1024.0))), "%s on water" % key)
	var jetty: Dictionary = WaterDressing.PROP_PLACEMENTS[0]
	assert_equal(jetty["key"], &"jetty", "the jetty first")
	var deck: float = float(jetty["base_y"]) + PropsScript.drawn_size_m(&"jetty") * (1.1289 / 1.8956) * 0.657
	assert_near_value(deck - surface, 0.22, 0.02, "the deck a hand above the water")


func assert_near_value(actual: float, expected: float, tolerance: float, message: String) -> void:
	"""`actual` within `tolerance` of `expected`."""
	assert_true(absf(actual - expected) <= tolerance, "%s (expected %.3f +- %.3f, got %.3f)" % [message, expected, tolerance, actual])


func test_a_digger_holds_its_pick_only_while_digging() -> void:
	"""Tunnel works arm every digger with the pick: shown in the DIG state, hidden walking or idle;
	a resident who is not a digger holds none."""
	var cast := _cast()
	var mole: int = -1
	for i: int in cast.actor_count():
		if Rules.is_digger((cast.actor(i) as DemoActorScript).species):
			mole = i
	var actor := cast.actor(0) as DemoActorScript
	actor.set_tool(PropsScript.new().mesh_of(&"mole_pick"), Transform3D.IDENTITY)
	actor.brain.state = BrainScript.State.DIG
	cast.advance(DT)
	assert_true(actor.tool_shown(), "digging: the pick shows")
	actor.brain.state = BrainScript.State.IDLE
	cast.advance(DT)
	assert_false(actor.tool_shown(), "idle: put away")
	assert_equal(mole, -1, "the placeholder cast has no digger species")
	var other := cast.actor(1) as DemoActorScript
	other.brain.state = BrainScript.State.DIG
	cast.advance(DT)
	assert_false(other.tool_shown(), "a resident never armed holds nothing")


func test_the_beaver_bridgewright_works_the_water_and_the_timber() -> void:
	"""Its three homes -- the weir, the boat landing, the log stack -- are all spots in the village
	with its water."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new())
	var names: Array[StringName] = []
	for point: Dictionary in world.points_of_interest() + WaterDressing.points_of_interest():
		names.append(point["name"])
	var homes: PackedInt32Array = CastRoutinesScript.homes_for(&"beaver_bridgewright", names)
	assert_equal(homes.size(), 3, "three homes found")
	assert_equal(names[homes[0]], &"weir_work", "the weir first")
