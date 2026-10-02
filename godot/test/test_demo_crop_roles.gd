extends "res://test/framework/test_case.gd"
## Crop roles (review ECO-001, decision 0881; demo/farm/farm_crop_roles.gd): every farmed ingredient's role is its
## GDD §5.6 row's, its two differences are worded from the rows' own constants, its uses are read from the kitchen's
## and the mill's tables, and the crop picker shows the role line. Expected values are the GDD's (§5.6/§5.7) literals.

const Roles := preload("res://demo/farm/farm_crop_roles.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")

const RADISH: int = 0
const PARSNIP: int = 4
const CABBAGE: int = 6
const LETTUCE: int = 7
const PEA: int = 11
const BROAD_BEAN: int = 12
const WHEAT: int = 13
const OATS: int = 15
const TROUT: int = 16

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_each_row_has_its_role_and_every_sibling_shares_it() -> void:
	"""Roots keep, cabbage is fresh, beans restore, grain is flour; a radish and a parsnip are the same role."""
	assert_equal(Roles.role_of(RADISH), Roles.ROLE_KEEPING_ROOT, "radish: a keeping root")
	assert_equal(Roles.role_of(PARSNIP), Roles.ROLE_KEEPING_ROOT, "parsnip: the same role (siblings stay equal)")
	assert_equal(Roles.role_of(LETTUCE), Roles.ROLE_FRESH_GREENS, "lettuce: fresh greens")
	assert_equal(Roles.role_of(PEA), Roles.ROLE_SOIL_RESTORER, "pea: the soil restorer")
	assert_equal(Roles.role_of(WHEAT), Roles.ROLE_FLOUR_CROP, "wheat: the flour crop")
	assert_equal(Roles.ROLE_OF_CROP[FarmingScript.CROP_FLAX], Roles.ROLE_FIBRE_CROP, "flax: the fibre crop")
	for item: int in Catalog.ITEM_COUNT:
		assert_equal(Roles.role_of(item), Roles.ROLE_OF_CROP[Catalog.crop_of(item)], "%s by its row" % Catalog.ITEM_LABELS[item])
		assert_equal(Roles.traits_text(item), Roles.traits_text(Catalog.ITEM_CROP.find(Catalog.crop_of(item))),
			"%s: the row's traits" % Catalog.ITEM_LABELS[item])
	assert_equal(Roles.role_of(TROUT), -1, "a fish is no crop")
	assert_equal(Roles.role_of(-1), -1, "nor nothing")
	assert_equal(Roles.role_name(TROUT), "", "no name")
	assert_equal(Roles.role_line(TROUT), "", "no line")
	assert_equal(Roles.traits_text(TROUT), "", "no traits")


func test_the_two_differences_are_the_rows_own_numbers() -> void:
	"""§5.7 shelf 240/144/480 h; §5.6 growth 120/192 h, windows, the legume's -800 and grain's 10 U."""
	assert_equal(Roles.traits_text(RADISH), "keeps 10 days · ripens in 5 days", "roots: 240 h, 120 h")
	assert_equal(Roles.traits_text(LETTUCE), "sown in summer and autumn · keeps 6 days", "cabbage row: windows, 144 h")
	assert_equal(Roles.traits_text(BROAD_BEAN), "gives the soil 800 fertility · keeps 20 days", "beans: -800, 480 h")
	assert_equal(Roles.traits_text(OATS), "10 U a bed · ripens in 8 days", "grain: 10 U, 192 h")
	assert_equal(Roles.trait_text(FarmingScript.CROP_FLAX, Roles.TRAIT_SOWN), "sown in spring", "flax: spring 1-6")
	assert_equal(Roles.trait_text(FarmingScript.CROP_FLAX, Roles.TRAIT_YIELD), "5 U a bed", "flax: 5 U")
	assert_equal(Roles.trait_text(FarmingScript.CROP_ROOTS, 99), "", "an unknown trait says nothing")
	assert_equal(Roles.ROLE_TRAITS.size(), Roles.ROLE_COUNT * 2, "two differences a role, no more")


func test_the_words_for_days_and_seasons() -> void:
	"""Whole days plainly, a remainder in hours; a row's seasons once each, in calendar order."""
	assert_equal(Roles.days_text(24), "1 day", "one")
	assert_equal(Roles.days_text(240), "10 days", "ten")
	assert_equal(Roles.days_text(148), "6 days 4 h", "and hours")
	assert_equal(Roles.seasons_text(FarmingScript.CROP_ROOTS), "spring and summer", "roots: spring 1-8, summer 1-4")
	assert_equal(Roles.seasons_text(FarmingScript.CROP_GRAIN), "spring", "grain: one window")


func test_uses_are_read_from_the_kitchen_and_the_mill() -> void:
	"""Carrots: the soup and the fish stew, raw in a pinch; wheat: porridge and the mill; lettuce the dishes that take
	greens, then raw; peas the bean hotpot -- each from meal_rules.gd's own tables, so a dish added there shows here (the
	recipe book's twenty since the batch 7 integration, decision 0902)."""
	var radish: PackedStringArray = Roles.uses_of(RADISH)
	assert_true(radish.has(MealRules.DISH_NAMES[MealRules.DISH_SOUP]), "radish feeds the soup")
	assert_true(radish.has(MealRules.DISH_NAMES[MealRules.DISH_FISH_STEW]), "and the fish stew")
	assert_true(radish.has(Roles.RAW_USE), "and the hungry, raw")
	assert_false(radish.has(Roles.MILL_USE), "never the mill")
	var wheat: PackedStringArray = Roles.uses_of(WHEAT)
	assert_true(wheat.has(MealRules.DISH_NAMES[MealRules.DISH_PORRIDGE]), "wheat: porridge")
	assert_true(wheat.has(Roles.MILL_USE), "and the mill")
	assert_false(wheat.has(Roles.RAW_USE), "never raw (§5.7: grain is not raw-edible)")
	var lettuce: PackedStringArray = Roles.uses_of(LETTUCE)
	assert_true(lettuce.has(MealRules.DISH_NAMES[MealRules.DISH_SALAD]) and lettuce[lettuce.size() - 1] == Roles.RAW_USE,
		"lettuce: the salad and the other greens' dishes, then raw: %s" % ", ".join(lettuce))
	assert_equal(Roles.uses_of(CABBAGE), lettuce, "cabbage the same")
	assert_equal(Roles.uses_of(PEA), PackedStringArray([MealRules.DISH_NAMES[MealRules.DISH_BEAN_HOTPOT]]),
		"peas: the bean hotpot alone")
	assert_equal(Roles.uses_text(PEA), "Uses: " + MealRules.DISH_NAMES[MealRules.DISH_BEAN_HOTPOT], "said so")
	assert_true(Roles.uses_of(TROUT).is_empty(), "not a crop")
	for dish: int in MealRules.DISH_COUNT:
		var any: bool = false
		var fed: bool = false
		for item: int in Catalog.ITEM_COUNT:
			any = any or Roles.uses_of(item).has(MealRules.DISH_NAMES[dish])
			fed = fed or MealRules.is_input(dish, item)
		assert_equal(any, fed, "%s is listed where a crop feeds it" % MealRules.DISH_NAMES[dish])


func test_the_role_line() -> void:
	"""'Keeping root — keeps 10 days · ripens in 5 days. Uses: ...'."""
	assert_equal(Roles.role_line(RADISH), "Keeping root — keeps 10 days · ripens in 5 days. %s" % Roles.uses_text(RADISH),
		"the radish's line")
	assert_true(Roles.role_line(PEA).begins_with("Soil restorer — gives the soil 800 fertility"), "the pea's")


func test_the_picker_shows_each_crop_s_role() -> void:
	"""The bed panel's crop picker has the role line under each crop's button."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	var sim := SimScript.new()
	var crew := CrewScript.new()
	crew.configure(cast, sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast))), TunnelsScript.new(),
		DemoFarmScript.well_position(), func(_text: String) -> void: pass)
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, crew)
	panel.show_bed(0)
	panel.open_picker()
	for item: int in Catalog.ITEM_COUNT:
		assert_equal(panel.picker_role(item), Roles.role_line(item), "%s's role" % Catalog.ITEM_LABELS[item])
