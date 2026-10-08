extends "res://test/framework/test_case.gd"
## The orchard's hooks and its readouts (decisions 0671-0677): the pantry items it adds (the library's LEAF keys, §5.7's
## rows), the work board's source, the woods' protected-grove rule, the seasons' fruit kind and other-owners' trees, the
## right column's tab-less panel, the panel and its cards, the drawing's choices, and the village node's selection and
## policy buttons. No staged assets, no scene tree.

const IntMath := preload("res://scripts/core/int_math.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const CardsScript := preload("res://demo/orchard/orchard_cards.gd")
const PanelScript := preload("res://demo/orchard/orchard_panel.gd")
const ViewScript := preload("res://demo/orchard/orchard_view.gd")
const OrchardNode := preload("res://demo/orchard/demo_orchard.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const OrchardWork := preload("res://demo/work/orchard_work.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const JobsForest := preload("res://demo/forestry/forest_jobs.gd")
const ForestCrew := preload("res://demo/forestry/forest_crew.gd")
const ForestStand := preload("res://demo/forestry/forest_stand.gd")
const ForestView := preload("res://demo/forestry/forest_view.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")
const SeasonViewScript := preload("res://demo/seasons/season_view.gd")
const CanopyScript := preload("res://demo/camera/canopy_clear.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")

const WOOD: int = 60

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _materials: Dictionary = {}


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _pantry() -> PantryScript:
	"""A pantry with the covered store and the two stands."""
	var storage := StorageScript.new(Vector2.ZERO)
	storage.add_provider(OrchardNode.stand_provider())
	return PantryScript.new(storage)


func _jobs(model: ModelScript, pantry: PantryScript, day: int) -> JobsScript:
	"""A board over `model` and `pantry` at 06:00 of `day`, with no cast."""
	var calendar := CalendarScript.new()
	calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	var jobs := JobsScript.new()
	jobs.configure(model, null, pantry, _services.stores, calendar, null)
	model.today_hint = day
	return jobs


# --- the pantry's new goods ------------------------------------------------------------------------------------------------

func test_the_fruit_and_the_berries_are_their_gdd_rows() -> void:
	"""Apple and pear, the library's LEAF keys and §5.7 `fruit` (144 h); the hedge's one generic `berries` item, §5.7
	`berries` (48 h), under the foraging lane's key and category; every per-item table runs to PANTRY_ITEM_COUNT."""
	var keys: Array[StringName] = [&"apple", &"pear", &"berries"]
	for k: int in keys.size():
		var item: int = Catalog.ORCHARD_ITEMS[k]
		assert_equal(Catalog.ITEM_KEYS[item], keys[k], "key %d" % k)
		assert_true(Catalog.is_orchard_item(item), "an orchard item")
		assert_equal(Catalog.category_of(item), Catalog.CAT_FRUIT if k < 2 else Catalog.CAT_BERRIES, "its §5.7 row")
		assert_equal(Catalog.shelf_hours_of(item), 144 if k < 2 else 48, "§5.7 shelf hours")
	assert_equal(Catalog.ITEM_KEYS.count(&"berries"), 1, "one berries item, whichever bush")
	for gone: StringName in [&"raspberry", &"blackberry", &"strawberry"]:
		assert_false(Catalog.ITEM_KEYS.has(gone), "%s is not its own item" % gone)
	assert_false(Catalog.is_orchard_item(Catalog.ITEM_FLOUR), "flour is not")
	assert_false(Catalog.is_orchard_item(Catalog.PANTRY_ITEM_COUNT), "past the end")
	assert_false(Catalog.is_orchard_item(-1), "no item")
	for table: Array in [Catalog.ITEM_KEYS, Catalog.ITEM_LABELS, Catalog.ITEM_PROP, Catalog.ITEM_SWATCH]:
		assert_equal(table.size(), Catalog.PANTRY_ITEM_COUNT, "a table per item")
	assert_equal(Catalog.GOODS_CATEGORY.size(), Catalog.PANTRY_ITEM_COUNT - Catalog.ITEM_COUNT, "goods' categories")
	assert_equal(Catalog.item_of_orchard_species(Hive.SPECIES_APPLE), Catalog.ITEM_APPLE, "apple")
	assert_equal(Catalog.item_of_orchard_species(Hive.SPECIES_PEAR), Catalog.ITEM_PEAR, "pear")
	assert_equal(Catalog.item_of_orchard_species(5), Catalog.NO_ITEM, "no species")
	assert_equal(Hive.SPECIES_KEYS, [&"apple", &"pear"] as Array[StringName], "the store's species keys are the items'")
	assert_equal(Catalog.ITEM_BERRIES, Catalog.FIRST_FORAGE + 3, "the foraging lane's berries, the same item")
	assert_equal(Catalog.CAT_BERRIES, 12, "the foraging lane's number for the same item (decision 0903)")
	assert_equal(Catalog.CAT_FRUIT, Catalog.CAT_BERRIES + 1, "fruit past the other lanes' categories")


func test_the_berries_and_fruit_rows_agree_with_the_compiled_catalogue() -> void:
	"""data/item_definitions.json's `berries` and `fruit` rows: their shelf hours, and the kitchen's raw NP a unit."""
	var rows: Dictionary = {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_definitions.json"))
	for row: Variant in data.get("items", []):
		rows[String((row as Dictionary).get("id", ""))] = row
	assert_true(rows.has("berries") and rows.has("fruit"), "both rows")
	assert_equal(int(rows["berries"]["shelf_hours"]), Catalog.shelf_hours_of(Catalog.ITEM_BERRIES), "berries keep 48 h")
	assert_equal(int(rows["fruit"]["shelf_hours"]), Catalog.shelf_hours_of(Catalog.ITEM_APPLE), "fruit keeps 144 h")
	assert_equal(int(rows["berries"]["nutrition_per_u"]), MealRules.raw_np_per_u(Catalog.ITEM_BERRIES), "700 NP raw")
	assert_equal(int(rows["fruit"]["nutrition_per_u"]), MealRules.raw_np_per_u(Catalog.ITEM_PEAR), "900 NP raw")


func test_the_leaves_exist_in_the_library_pantry() -> void:
	"""Apple and pear name game_leaf_inputs LEAFs of docs/redwall-content-library/shared/pantry.json."""
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://") + "../docs/redwall-content-library/shared/pantry.json")
	assert_false(text.is_empty(), "the library pantry read")
	for key: StringName in [&"apple", &"pear"]:
		assert_true(text.contains("\"LEAF_%s\"" % key), "LEAF_%s" % key)


func test_the_field_guide_has_an_entry_for_each_orchard_good() -> void:
	"""The guide's goods (field_guide.gd `_goods`): fruit from the trees, and the berries the forage entry, which names the
	hedge too (decision 0903), each its shelf life and its raw NP."""
	var guide := FieldGuideScript.new()
	for item: int in Catalog.ORCHARD_ITEMS:
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(item)))
		var all: String = entry.uses + entry.requires + entry.alternatives + entry.here
		assert_equal(entry.title, Catalog.ITEM_LABELS[item], "titled")
		assert_true(all.contains("%d game hours" % Catalog.shelf_hours_of(item)), "%s keeps its hours" % entry.title)
		assert_true(all.contains("%d NP a unit" % MealRules.raw_np_per_u(item)), "%s: its raw NP" % entry.title)
		if item == Catalog.ITEM_BERRIES:
			assert_true(entry.here.contains("berry hedge"), "the forage entry names the hedge too: " + entry.here)
		else:
			assert_true(entry.summary.contains("orchard"), entry.summary)


# --- the work board --------------------------------------------------------------------------------------------------------

func test_a_stand_beside_a_harvest_is_never_its_store() -> void:
	"""farm_pantry.gd `_best_location_into` passes a staging store by, even when it is nearer at the same factor."""
	var pantry := _pantry()
	assert_true(pantry.location_near_into(1000, Rules.STAND_AT[0], _read), "a store")
	assert_equal(_read.value, 0, "the covered store, not the stand beside it (both 1000)")


func test_the_orchard_is_the_source_after_foraging() -> void:
	"""SOURCE_ORCHARD 13 (batch 8 integration, decision 0903): after foraging's 12, the walk past every source, the
	names one a source."""
	assert_equal(WorkIds.SOURCE_ORCHARD, WorkIds.SOURCE_FORAGE + 1, "after foraging")
	assert_equal(WorkIds.SOURCE_ORCHARD, 13, "thirteen")
	assert_equal(WorkIds.SOURCE_COUNT, 14, "fourteen sources")
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a queued walk past them")
	assert_equal(WorkIds.SOURCE_NAMES.size(), WorkIds.SOURCE_COUNT, "a name each")
	assert_equal(WorkIds.SOURCE_NAMES[WorkIds.SOURCE_ORCHARD], "Orchard", "named")
	assert_true(WorkIds.is_source(WorkIds.SOURCE_ORCHARD), "a source")


func test_the_adapter_reads_and_commands_the_orchard_board() -> void:
	"""orchard_work.gd: the board's rows, a task's record (verb, target, state, the delivery's refusals), field work and
	hauling as activities, and every command carried to the owner."""
	var model := ModelScript.new()
	var pantry := _pantry()
	var jobs := _jobs(model, pantry, 25)
	var source := OrchardWork.new(jobs)
	assert_equal(source.id, WorkIds.SOURCE_ORCHARD, "its id")
	assert_equal(source.capacity(), JobsScript.MAX_JOBS, "its rows")
	assert_true(jobs.open_into(JobsScript.K_HARVEST, 0, JobsScript.ORIGIN_ROUTINE, _read), "a harvest")
	var j: int = _read.value
	assert_true(source.live(j) and source.waiting(j), "listed and waiting")
	assert_equal(source.key(j), jobs.serial[j], "its serial")
	assert_equal(source.worker(j), -1, "nobody")
	assert_equal(source.activity(j), WorkIds.ACT_FARM, "field work")
	var task := TaskRecord.new()
	source.fill(task, j)
	assert_equal(task.action, "Harvest", "the verb")
	assert_equal(task.target, "the old apple", "the tree")
	assert_equal(task.state, WorkIds.STATE_QUEUED, "queued")
	jobs.load_item[j] = Catalog.ITEM_APPLE
	jobs.load_milli[j] = 5000
	source.fill(task, j)
	assert_equal(task.cancel_refusal, WorkIds.DELIVERY_GOES_ON, "a delivery goes on")
	assert_true(task.carrying, "carrying")
	assert_true(jobs.open_into(JobsScript.K_HAUL, 1, JobsScript.ORIGIN_ROUTINE, _read), "a haul")
	assert_equal(source.activity(_read.value), WorkIds.ACT_HAUL, "the Haulers' work")
	assert_equal(source.pause(_read.value, true), "", "paused through the owner")
	assert_equal(source.cancel(_read.value), "", "cancelled through the owner")
	assert_equal(source.reassign(99, 0), Text.GONE, "reassign through the owner")
	assert_true(source.eligibility(j, 0).is_empty(), "anybeast may")
	assert_false(source.claim(j, 0), "no cast: nobody to hand it to")


func test_the_board_takes_the_orchard_source() -> void:
	"""demo_work.gd `add_orchard`'s board: source 11 is the orchard's; the empty slots 8-10 are skipped."""
	var board := BoardScript.new()
	board.bind([], PackedStringArray(), [])
	var jobs := _jobs(ModelScript.new(), _pantry(), 1)
	board.add_source(OrchardWork.new(jobs))
	assert_not_null(board.source(WorkIds.SOURCE_ORCHARD), "added")
	assert_null(board.source(8), "8 is unused here")
	jobs.open_into(JobsScript.K_TEND, 0, JobsScript.ORIGIN_ROUTINE, _read)
	board.rebuild_index()
	assert_equal(board.index_size(), 1, "the orchard's waiting job indexed")
	assert_equal(board.cancel_all(), 1, "and cancelled by Cancel all")


# --- the woods' rule -----------------------------------------------------------------------------------------------------------

func _forestry() -> ForestryScript:
	"""The woods over the placeholder cast in the real layout, as test_demo_forestry.gd builds them."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	var forestry: ForestryScript = _keep(ForestryScript.new()) as ForestryScript
	forestry.configure(world, cast, null, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	forestry.crew.set_crew(PackedInt32Array())
	return forestry


func test_the_woods_never_fell_a_tree_in_the_protected_grove() -> void:
	"""forest_crew.gd `set_protected` (decision 0675): a fell on a mature tree in the grove is refused in words while it
	is protected, by order and by every routine that asks `_fell_refusal`; lifted, the woods' own rules answer."""
	var forestry := _forestry()
	var node := OrchardNode.new()
	forestry.crew.set_protected(node.grove_protects)
	var inside: int = -1
	var outside: int = -1
	for t: int in forestry.stand.count():
		var at: Vector2 = forestry.stand.at[t]
		if forestry.stand.state_of(t) != ForestStand.STATE_MATURE or absf(at.x) > 30.0 or absf(at.y) > 30.0:
			continue
		if at.distance_to(Rules.GROVE_AT) <= Rules.GROVE_RADIUS_M:
			inside = t
		elif outside < 0:
			outside = t
	assert_true(inside >= 0, "a mature tree in the grove, within reach")
	assert_equal(forestry.crew.refusal_for(JobsForest.KIND_FELL, inside, 0), ForestCrew.REFUSE_GROVE, "refused")
	assert_true(forestry.crew.reason_text(ForestCrew.REFUSE_GROVE, inside).contains("protected grove"), "in words")
	assert_true(forestry.crew.refusal_for(JobsForest.KIND_FELL, outside, 0) != ForestCrew.REFUSE_GROVE, "not outside it")
	node.model.set_grove_protected(0, false)
	assert_true(forestry.crew.refusal_for(JobsForest.KIND_FELL, inside, 0) != ForestCrew.REFUSE_GROVE, "lifted")
	node.free()


# --- the seasons ------------------------------------------------------------------------------------------------------------

func test_a_fruit_tree_blossoms_in_spring_and_stands_bare_in_winter() -> void:
	"""season_look.gd KIND_FRUIT: deciduous, never holding dry leaves, in full blossom in mid-spring, bare in mid-winter."""
	assert_true(LookScript.DECIDUOUS[LookScript.KIND_FRUIT], "deciduous")
	assert_equal(LookScript.MARCESCENT_SHARE[LookScript.KIND_FRUIT], 0.0, "never marcescent")
	assert_equal(LookScript.BLOSSOM_PEAK[LookScript.KIND_FRUIT], 1.0, "full blossom")
	var look := LookScript.new()
	var sample := LookScript.Sample.new()
	look.sample_into(LookScript.KIND_FRUIT, LookScript.tree_hash(Rules.site_centre_m(0)), LookScript.SPRING, 5.0, sample)
	assert_true(sample.blossom > 0.9, "in blossom in mid-spring: %f" % sample.blossom)
	look.sample_into(LookScript.KIND_FRUIT, LookScript.tree_hash(Rules.site_centre_m(0)), LookScript.WINTER, 6.0, sample)
	assert_almost_equal(sample.bare, 1.0, "bare in mid-winter")
	assert_almost_equal(sample.blossom, 0.0, "no blossom")


func _two_triangle_mesh() -> ArrayMesh:
	"""A staged-like model: one mesh, one textured material."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 3, 0), Vector3(1, 3, 0), Vector3(0, 4, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.05, 0.1), Vector2(0.4, 0.1), Vector2(0.05, 0.9)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color(0.27, 0.33, 0.13))
	material.albedo_texture = ImageTexture.create_from_image(image)
	mesh.surface_set_material(0, material)
	return mesh


func _material_for(mesh: MeshInstance3D) -> ShaderMaterial:
	"""The tree material of `mesh`'s model (as canopy_clear.gd `fade_material_for`)."""
	var own: Material = CanopyScript.own_material(mesh)
	if not _materials.has(own):
		_materials[own] = CanopyScript.make_fade_material(own as BaseMaterial3D)
	return _materials[own]


## A stand-in owner of season trees (season_view.gd OTHER OWNERS' TREES).
class Owner:
	var nodes: Array[Node3D] = []
	var revision: int = 0

	func season_tree_count() -> int:
		"""Its trees."""
		return nodes.size()

	func season_tree_node(i: int) -> Node3D:
		"""Tree `i`'s node."""
		return nodes[i]

	func season_tree_kind(_i: int) -> int:
		"""Fruit trees."""
		return LookScript.KIND_FRUIT

	func season_tree_at(i: int) -> Vector2:
		"""Where tree `i` stands."""
		return Vector2(float(i) * 8.0, 30.0)

	func season_trees_revision() -> int:
		"""Bumped on a new node."""
		return revision


func test_other_owners_trees_wear_the_season() -> void:
	"""season_view.gd `add_trees`: an owner's trees dressed with their own kind and hash, written each hour; a new node
	(its revision moved) is dressed afresh."""
	var calendar := CalendarScript.new()
	var stand := ForestStand.new()
	var forest := _keep(ForestView.new()) as ForestView
	forest.configure(stand, func(_p: int) -> Node3D: return null, Callable(), ServicesScript.new().props)
	var view := _keep(SeasonViewScript.new()) as SeasonViewScript
	view.configure(calendar, null, null, stand, forest, null, _material_for)
	var before: int = view.dressed_count()
	var owner := Owner.new()
	for k: int in 2:
		var root := _keep(Node3D.new()) as Node3D
		var mesh := MeshInstance3D.new()
		mesh.mesh = _two_triangle_mesh()
		root.add_child(mesh)
		owner.nodes.append(root)
	view.add_trees(owner)
	assert_equal(view.dressed_count(), before + 2, "dressed")
	assert_equal(view.kind_of(before), LookScript.KIND_FRUIT, "as fruit trees")
	assert_equal(view.hash_of(before + 1), LookScript.tree_hash(Vector2(8.0, 30.0)), "by where they stand")
	var fresh := _keep(Node3D.new()) as Node3D
	var m2 := MeshInstance3D.new()
	m2.mesh = _two_triangle_mesh()
	fresh.add_child(m2)
	owner.nodes.append(fresh)
	owner.revision += 1
	view._process(0.0)
	assert_equal(view.dressed_count(), before + 3, "a new tree dressed on its owner's revision")


# --- the right column -------------------------------------------------------------------------------------------------------

func test_the_orchard_panel_has_the_zone_without_a_tab() -> void:
	"""demo_detail_zone.gd PANEL_ORCHARD: shown by intent, no tab lit, any tab takes the zone back; the strip keeps its
	four tabs; a key past the panels is ignored."""
	var zone := _keep(DetailZone.new()) as DetailZone
	zone.build()
	var panel := _keep(PanelScript.new()) as PanelScript
	panel.build()
	zone.add_panel(DetailZone.PANEL_ORCHARD, panel)
	assert_false(panel.is_shown(), "hidden at first (the farm's is shown)")
	zone.show_panel(DetailZone.PANEL_ORCHARD)
	assert_true(panel.is_shown(), "shown")
	assert_equal(zone.shown, DetailZone.PANEL_ORCHARD, "the zone's")
	for k: int in 4:
		assert_false(zone.tab(k).button_pressed, "tab %d unlit" % k)
	zone.show_panel(DetailZone.PANEL_WOODS)
	assert_false(panel.is_shown(), "a tab takes the zone back")
	zone.show_panel(9)
	assert_equal(zone.shown, DetailZone.PANEL_WOODS, "no such panel: ignored")
	assert_equal(DetailZone.TAB_TEXT.size(), 4, "still four tabs")


func test_the_panel_shows_what_it_is_told() -> void:
	"""orchard_panel.gd: the selection's verbs shown by name, each card its tooltip and its press; the group hides
	without one; every line readable."""
	var panel := _keep(PanelScript.new()) as PanelScript
	panel.build()
	panel.show_status("today", "jobs")
	assert_equal(panel.line(&"status"), "today", "status")
	assert_equal(panel.line(&"jobs"), "jobs", "jobs")
	panel.show_selection("", "", [] as Array[StringName])
	assert_equal(panel.line(&"title"), PanelScript.NOTHING, "nothing selected")
	panel.show_selection("The old apple", "text", [&"tend", &"harvest"] as Array[StringName])
	assert_true(panel.button(&"tend").visible and panel.button(&"harvest").visible, "its verbs")
	assert_false(panel.button(&"pick").visible, "not another thing's")
	panel.set_card(&"harvest", "Harvest\nCan't now: not yet", false)
	assert_true(panel.button(&"harvest").disabled, "refused: disabled")
	assert_equal(panel.button(&"harvest").tooltip_text, "Harvest\nCan't now: not yet", "its card")
	panel.show_group("", "", "", "", "")
	assert_false((panel.get("_group_box") as Control).visible, "no group: hidden")
	panel.show_group("The old orchard", "text", "staggered", "kitchen", "4.0 U")
	assert_true((panel.get("_group_box") as Control).visible, "a group: shown")
	assert_equal(panel.button(&"timing").text, "Timing: staggered", "timing")
	assert_equal(panel.button(&"dest").text, "Share: kitchen", "the fresh-table share")
	assert_equal(panel.button(&"keep").text, "Keep: 4.0 U", "keep")
	panel.show_nursery("The nursery", "plans")
	panel.show_grove("The North hollow", "record", false)
	assert_equal(panel.button(&"protect").text, "Protected: no", "the grove's toggle")
	assert_equal(panel.line(&"nursery"), "plans", "the nursery")
	assert_equal(panel.line(&"grove"), "record", "the grove")


# --- the cards --------------------------------------------------------------------------------------------------------------

func _cards(day: int) -> CardsScript:
	"""Cards over a fresh model and board at 06:00 of `day`."""
	var model := ModelScript.new()
	var cards := CardsScript.new()
	var jobs := _jobs(model, _pantry(), day)
	var compost := func() -> int: return 10000
	jobs.set_compost(compost, func(_milli: int) -> bool: return true)
	cards.configure(model, jobs, null)
	cards.compost_left = compost
	return cards


func test_each_selection_shows_its_verbs_and_its_most_pressing() -> void:
	"""A tree: tend and harvest (harvest pressing in its window, tend in spring); an empty site: plant and plan (drop once
	planned); a bush: pick; the baskets: send on; the grove: observe; the nursery: none."""
	var spring := _cards(1)
	assert_equal(spring.shown_actions(CardsScript.SEL_SITE, 0), [&"tend", &"harvest", &"move"] as Array[StringName], "a tree")
	assert_equal(spring.pressing(CardsScript.SEL_SITE, 0), &"tend", "spring: tend")
	assert_equal(spring.shown_actions(CardsScript.SEL_SITE, 2), [&"plant_apple", &"plant_pear", &"plan_apple", &"plan_pear"]
		as Array[StringName], "an empty site")
	assert_equal(spring.pressing(CardsScript.SEL_SITE, 2), &"plant_apple", "plant a free apple")
	assert_equal(spring.shown_actions(CardsScript.SEL_BUSH, 1), [&"pick"] as Array[StringName], "a bush")
	assert_equal(spring.pressing(CardsScript.SEL_BUSH, 1), &"", "nothing to pick in spring")
	assert_true(spring.nothing_to_do(CardsScript.SEL_BUSH, 1).contains("no berries"), "says why")
	assert_equal(spring.shown_actions(CardsScript.SEL_STAND, 0), [&"haul", &"cart"] as Array[StringName], "the baskets")
	assert_equal(spring.shown_actions(CardsScript.SEL_GROVE, 0), [&"observe"] as Array[StringName], "the grove")
	assert_true(spring.shown_actions(CardsScript.SEL_NURSERY, 0).is_empty(), "the nursery: none")
	assert_true(spring.nothing_to_do(CardsScript.SEL_NURSERY, 0).contains("Nothing"), "nothing to do")
	var autumn := _cards(25)
	assert_equal(autumn.pressing(CardsScript.SEL_SITE, 0), &"harvest", "Autumn 1: the apple")
	autumn._model.add_plan(Rules.PEAR, 3)
	assert_equal(autumn.shown_actions(CardsScript.SEL_SITE, 3), [&"plant_apple", &"plant_pear", &"drop_plan"]
		as Array[StringName], "planned: drop it")
	assert_equal(autumn.refusal(&"drop_plan", CardsScript.SEL_SITE, 3), "", "a waiting plan may be dropped")
	assert_equal(autumn.refusal(&"plan_apple", CardsScript.SEL_SITE, 3), Text.plant_words("SITE_PLANNED"), "one plan")
	assert_equal(autumn.pressing(CardsScript.SEL_SITE, 3), &"", "its sapling is not ready")


func test_the_job_an_action_orders() -> void:
	"""orchard_cards.gd `job_of`: each verb's kind, target and species; a grove's target its own (decision 1721: two); a
	policy orders none."""
	var cards := _cards(1)
	assert_equal(cards.job_of(&"tend", CardsScript.SEL_SITE, 1), Vector3i(Rules.K_TEND, 1, -1), "tend")
	assert_equal(cards.job_of(&"plant_pear", CardsScript.SEL_SITE, 3), Vector3i(Rules.K_PLANT, 3, Rules.PEAR), "plant a pear")
	assert_equal(cards.job_of(&"observe", CardsScript.SEL_GROVE, 1), Vector3i(Rules.K_OBSERVE, 1, -1), "the beech hollow")
	assert_equal(cards.job_of(&"move", CardsScript.SEL_SITE, 2), Vector3i(Rules.K_MOVE, 2, -1), "a move")
	assert_equal(cards.job_of(&"cart", CardsScript.SEL_STAND, 1), Vector3i(Rules.K_CART, 1, -1), "a cart")
	assert_equal(cards.job_of(&"timing", CardsScript.SEL_SITE, 0).x, -1, "a policy: no job")


func test_a_card_says_the_verb_the_refusal_the_cost_and_the_work() -> void:
	"""Decision 0332's card: a planting's sapling and compost have / need, its 40 WU in game time; a refused harvest's
	"Can't now"; the tree's readout and REQ-SET-081's preview on an empty site."""
	var cards := _cards(1)
	var why: String = cards.refusal(&"plant_apple", CardsScript.SEL_SITE, 2)
	assert_equal(why, "", "may be planted")
	var text: String = cards.card_text(&"plant_apple", CardsScript.SEL_SITE, 2, PackedInt32Array(), why)
	assert_true(text.contains("Plant"), text)
	assert_true(text.contains("Apple saplings: have 2.0 U · need 1.0 U"), text)
	assert_true(text.contains("Compost: have 10.0 U · need 4.0 U"), text)
	assert_true(text.contains("Work:"), "its work")
	assert_true(text.contains("Field crew"), "queued for the crew")
	var refused: String = cards.refusal(&"harvest", CardsScript.SEL_SITE, 0)
	assert_true(cards.card_text(&"harvest", CardsScript.SEL_SITE, 0, PackedInt32Array([1, 2]), refused).contains("Can't now"),
		"refused out of its window")
	assert_true(cards.text(CardsScript.SEL_SITE, 0).contains("Next picking: Y1 Autumn 1"), "the tree's next picking")
	assert_true(cards.text(CardsScript.SEL_SITE, 2).contains("An apple planted today: first fruit Y2 Autumn 1, full crops from Y3 Autumn 1"),
		"REQ-SET-081's preview")
	assert_true(cards.text(CardsScript.SEL_BUSH, 0).contains("not fruiting"), "a spring hedge")
	assert_equal(cards.title(CardsScript.SEL_SITE, 1), "The old pear", "titled")
	assert_equal(cards.title(CardsScript.SEL_BUSH, 2), "Strawberry bed", "the bed")
	assert_equal(cards.group_of(CardsScript.SEL_BUSH, 0), Rules.BUSH_GROUP, "the hedge's group")
	assert_equal(cards.group_of(CardsScript.SEL_GROVE, 0), -1, "the grove has none")
	assert_true(cards.status_line().contains("Y1 Spring 1"), cards.status_line())
	assert_true(cards.jobs_line().contains("0"), cards.jobs_line())
	assert_true(cards.nursery_text().contains("2 apple, 2 pear"), "the grant")
	assert_true(cards.grove_text(0).contains("never felled"), "protected")
	assert_true(cards.grove_text(0).contains("leave its nuts a reserve"), cards.grove_text(0))
	assert_true(cards.grove_text(1).contains("leave its mushrooms a reserve"), cards.grove_text(1))
	assert_true(cards.policy_tip(&"timing", 0).contains("As each ripens"), "the timing's card")
	assert_true(cards.policy_tip(&"protect", -1).contains("firewood"), "the grove's card")
	assert_equal(cards.keep_word(0), "4.0 U", "the old orchard keeps one sapling's fruit")
	assert_equal(cards.dest_word(1), "fresh 0%", "the east orchard's fresh-table share")
	assert_equal(cards.timing_word(-1), "", "no group")


# --- the drawing -------------------------------------------------------------------------------------------------------------

func _view(model: ModelScript, day: int) -> ViewScript:
	"""The orchard drawn with the world's placeholders over `model`, on a calendar at 06:00 of `day`."""
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var calendar := CalendarScript.new()
	calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	model.today_hint = day
	var view := _keep(ViewScript.new()) as ViewScript
	view.configure(model, _jobs(model, _pantry(), day), world.make_piece, _services.props, null, null, calendar)
	return view


func test_the_trees_are_drawn_by_age_and_offered_to_the_seasons() -> void:
	"""Each tree a node (the oak's model, its size by age), pegs on the empty sites, the hedge's two bushes; six season
	slots, all fruit trees; a new tree moves the season's revision."""
	var model := ModelScript.new()
	var view := _view(model, 1)
	assert_not_null(view.tree_node(0), "the old apple drawn")
	assert_null(view.tree_node(2), "no tree on an empty site")
	assert_true(view.pegs_shown(2) and not view.pegs_shown(0), "pegs only where no tree stands")
	assert_equal(view.season_tree_count(), Rules.SITE_COUNT + 2, "four sites and two bushes")
	assert_equal(view.season_tree_kind(5), LookScript.KIND_FRUIT, "fruit trees")
	assert_equal(view.season_tree_at(4), Rules.BUSH_AT[0], "the first bush")
	assert_almost_equal(view.tree_size(0), ViewScript.OLD_TREE_SIZE, "an old tree's size")
	var revision: int = view.season_trees_revision()
	model.take_sapling(2, Rules.APPLE, false)
	model.plant(2, Rules.APPLE, 1)
	view.refresh(true)
	assert_not_null(view.tree_node(2), "the new apple drawn")
	assert_true(view.season_trees_revision() > revision, "the seasons are told")
	assert_almost_equal(view.tree_size(2), ViewScript.SAPLING_SIZES.x, "a sapling's size")
	assert_true(view.ring_shown(), "the grove's ring while protected")
	model.set_grove_protected(0, false)
	view.refresh(true)
	assert_false(view.ring_shown(), "no ring when not")


func test_fruit_shows_on_a_bearing_tree_until_it_is_picked() -> void:
	"""orchard_view.gd `fruit_share`: none in spring; swelling in late summer; full in autumn until picked; fewer at low
	health; berries by the hedge's stock above its floor, none when dormant."""
	var model := ModelScript.new()
	var view := _view(model, APPLE_DAY_UI)
	assert_equal(view.fruit_share(0, LookScript.SPRING, 5.0), 0.0, "spring: none")
	assert_true(view.fruit_share(0, LookScript.AUTUMN, 0.5) > 0.0, "autumn: ripe")
	assert_true(view.fruit_share(0, LookScript.AUTUMN, 0.5) < 1.0, "fewer at 35% health")
	assert_true(view.fruit_share(0, LookScript.SUMMER, 11.0) > view.fruit_share(0, LookScript.SUMMER, 6.0), "swelling")
	model.pick_tree(0, APPLE_DAY_UI)
	assert_equal(view.fruit_share(0, LookScript.AUTUMN, 0.5), 0.0, "picked: none")
	assert_equal(view.fruit_share(2, LookScript.AUTUMN, 0.5), 0.0, "no tree")
	assert_equal(view.berry_share(0), 0.0, "a spring hedge")
	assert_almost_equal(view.berry_share(1), 0.75, "summer: 180 of 240 U above the floor")


const APPLE_DAY_UI: int = 25


# --- the village's node ----------------------------------------------------------------------------------------------------

func _node() -> OrchardNode:
	"""The orchard node over a fresh pantry, with no world, cast, command or camera."""
	var node := _keep(OrchardNode.new()) as OrchardNode
	node.configure(null, null, null, null, _services, _pantry())
	return node


func test_the_stands_and_obstacles_it_hands_the_village() -> void:
	"""`stand_provider`: two gathering stores at the covered store's factor; `land_obstacles`: four trunks, two bushes,
	two stands, the nursery, the groves' two stones (decision 1721) and the apiary's skep (decision 1601)."""
	var rows: Array = OrchardNode.stand_provider().call()
	assert_equal(rows.size(), Rules.GROUP_COUNT, "a stand a group")
	for row: Dictionary in rows:
		assert_true(row[StorageScript.KEY_STAGING], "a gathering place")
		assert_equal(row[StorageScript.KEY_PERMILLE], 1000, "§5.8 covered store")
		assert_equal(row[StorageScript.KEY_CAPACITY_U], Rules.STAND_CAPACITY_U, "its capacity")
	assert_equal(OrchardNode.land_obstacles().size(), Rules.SITE_COUNT + 2 + Rules.GROUP_COUNT + 1 + Rules.GROVE_COUNT \
		+ HiveRules.APIARY_COUNT, "twelve circles")


func test_a_click_picks_the_nearest_orchard_thing() -> void:
	"""`pick_at`: a tree within its trunk's reach, a bush, the baskets, the nursery, the grove's stone; the open
	ground and INF pick nothing."""
	var node := _node()
	assert_equal(node.pick_at(Rules.site_centre_m(1) + Vector2(2.2, 0.8)), Vector2i(OrchardNode.SEL_SITE, 1), "the pear's crown")
	assert_equal(node.pick_at(Rules.BUSH_AT[2]), Vector2i(OrchardNode.SEL_BUSH, 2), "the strawberries")
	assert_equal(node.pick_at(Rules.STAND_AT[1]), Vector2i(OrchardNode.SEL_STAND, 1), "the east baskets")
	assert_equal(node.pick_at(Rules.NURSERY_AT), Vector2i(OrchardNode.SEL_NURSERY, 0), "the nursery")
	assert_equal(node.pick_at(Rules.GROVE_AT), Vector2i(OrchardNode.SEL_GROVE, 0), "the grove")
	assert_equal(node.pick_at(Vector2(0.0, 0.0)).x, OrchardNode.SEL_NONE, "the well: nothing of the orchard's")
	assert_equal(node.pick_at(Vector2.INF).x, OrchardNode.SEL_NONE, "off the ground")
	assert_true(node.grove_protects(Rules.GROVE_AT + Vector2(3.0, 0.0)), "in the grove")
	assert_false(node.grove_protects(Rules.GROVE_AT + Vector2(9.0, 0.0)), "outside it")
	assert_equal(node.grove_trees_standing(0), 0, "no woods: none counted")
	assert_equal(node.pick_at(Rules.GROVE_STONES[1]), Vector2i(OrchardNode.SEL_GROVE, 1), "the beech hollow's stone")
	assert_true(node.grove_protects(Rules.GROVE_CENTRES[1]), "in the beech hollow")
	assert_equal(node.grove_reserve_permille(Rules.GROVE_CENTRES[1]), Rules.GROVE_RESERVE_PERMILLE, "its reserve")
	node.model.set_grove_protected(1, false)
	assert_false(node.grove_protects(Rules.GROVE_CENTRES[1]), "lifted: felled as any")
	assert_equal(node.grove_reserve_permille(Rules.GROVE_CENTRES[1]), 0, "lifted: no reserve")
	assert_equal(node.grove_reserve_permille(Vector2.ZERO), 0, "no grove: no reserve")


func test_the_panel_buttons_step_the_policies_and_the_plans() -> void:
	"""`on_action`: timing, destination and the nursery's share stepped for the selection's group; the grove's toggle;
	a plan made and dropped; a selection fills the panel."""
	var node := _node()
	node.select(OrchardNode.SEL_SITE, 0)
	assert_equal(node.panel.line(&"title"), "The old apple", "the selection")
	node.on_action(&"timing")
	assert_equal(node.model.group_timing[0], Rules.TIMING_TOGETHER, "together")
	node.on_action(&"timing")
	assert_equal(node.model.group_timing[0], Rules.TIMING_STAGGERED, "and back")
	node.on_action(&"dest")
	assert_equal(node.model.group_fresh_pct[0], 25, "a quarter to the fresh table")
	for k: int in 3:
		node.on_action(&"dest")
	assert_equal(node.model.group_fresh_pct[0], 100, "all to the kitchen")
	node.on_action(&"dest")
	assert_equal(node.model.group_fresh_pct[0], 0, "and round to none")
	node.on_action(&"keep")
	assert_equal(node.model.group_keep[0], Rules.KEEP_STEPS[2], "8 U kept")
	node.on_action(&"keep")
	assert_equal(node.model.group_keep[0], Rules.KEEP_STEPS[0], "none kept")
	node.on_action(&"protect")
	assert_false(node.model.is_grove_protected(0), "the North hollow's protection lifted (no grove selected)")
	assert_true(node.model.is_grove_protected(1), "the beech hollow's kept")
	node.select(OrchardNode.SEL_GROVE, 1)
	node.on_action(&"protect")
	assert_false(node.model.is_grove_protected(1), "the selected grove's toggled")
	assert_equal(node.panel.line(&"grove_title"), "The beech hollow", "the grove section shows the selected grove")
	node.select(OrchardNode.SEL_SITE, 2)
	node.on_action(&"plan_pear")
	assert_equal(node.model.plan_species[node.model.plan_for_site(2)], Rules.PEAR, "a pear planned")
	node.on_action(&"drop_plan")
	assert_equal(node.model.plan_for_site(2), ModelScript.NONE, "dropped")
	node.on_action(&"tend")
	assert_true(node.jobs.find(Rules.K_TEND, 2) == JobsScript.NONE, "no tree: no tending ordered")
	node.select(OrchardNode.SEL_GROVE, 0)
	node.on_action(&"observe")
	assert_true(node.jobs.find(Rules.K_OBSERVE, 0) >= 0, "the grove's observation ordered")
	node.select(OrchardNode.SEL_NURSERY, 0)
	node.on_action(&"timing")
	assert_equal(node.model.group_timing[0], Rules.TIMING_STAGGERED, "the nursery has no group: nothing stepped")


func test_the_kitchen_never_reserves_food_at_a_stand() -> void:
	"""ingredient_takes.gd: a lot waiting at a basket stand is not offered to the kitchen; a move never lands there."""
	var pantry := _pantry()
	assert_true(pantry.storage.index_of_id_into(Rules.STAND_IDS[0], _read), "the stand")
	var stand: int = _read.value
	assert_true(pantry.add_into(Catalog.ITEM_APPLE, 5000, stand, _read), "apples at the stand")
	var lot: int = _read.value
	var takes := TakesScript.new()
	assert_equal(takes.free_milli_of_crop(pantry, Catalog.CAT_FRUIT), 0, "not the kitchen's to count")
	assert_true(pantry.add_into(Catalog.ITEM_APPLE, 2000, 0, _read), "apples in the store")
	assert_equal(takes.free_milli_of_crop(pantry, Catalog.CAT_FRUIT), 2000, "only the stored")
	var other: int = 2 if stand == 1 else 1
	assert_false(pantry.move_upto_into(_read.value, pantry.lot_serial(_read.value), 1000, other, -1, _read),
		"a move never lands at a stand")
	assert_true(pantry.lot_milli(lot) == 5000, "untouched")
