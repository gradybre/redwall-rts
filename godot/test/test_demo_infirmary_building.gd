extends "res://test/framework/test_case.gd"
## The infirmary building (decision 0623): GDD §5.9's Infirmary row read from the settlement's own tables; placed with
## its placing tool (where it may stand); its wood and stone fetched from the village stores and its cloth from the care
## shelf, built by residents through the work board (REQ-SET-124/125/126); built, its 8 patient beds. The cellar
## building's tests (decision 0612) for one building and three materials. On the placeholder cast, stepped at 60 Hz, out
## of the tree.

const Rules := preload("res://demo/infirmary/infirmary_rules.gd")
const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const BuildersScript := preload("res://demo/infirmary/infirmary_builders.gd")
const PlaceScript := preload("res://demo/infirmary/infirmary_place.gd")
const ViewScript := preload("res://demo/infirmary/infirmary_view.gd")
const BuildingScript := preload("res://demo/infirmary/infirmary_building.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")
const CareWork := preload("res://demo/work/care_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const Injury := preload("res://scripts/core/injury.gd")

const DT: float = 1.0 / 60.0
const USEC: int = 16667
const STORE_AT: Vector2 = Vector2(-6.0, 10.0)
const SHELF_AT: Vector2 = Vector2(-6.0, 13.0)
const SITE: Vector2 = Vector2(4.0, 12.0)

var _cast: DemoCastScript = null
var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free what a test built."""
	if _cast != null:
		_cast.free()
		_cast = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- the numbers ---------------------------------------------------------------------------------

func test_the_infirmary_figures_are_the_gdd_s_read_from_the_settlement_tables() -> void:
	"""GDD §5.9 and balance §4.1/§4.2: 8 x 8, wood 40, stone 30, cloth 12, 1000 WU, Healer 2, at most 4 builders, M1 in
	the tables; 8 patient beds; a WU 0.15 s of one builder's time."""
	assert_equal(Rules.footprint_tiles(), Vector2i(8, 8), "8 x 8 tiles")
	assert_equal([Rules.cost_milli(Rules.MAT_WOOD), Rules.cost_milli(Rules.MAT_STONE), Rules.cost_milli(Rules.MAT_CLOTH)],
		[40000, 30000, 12000], "wood 40, stone 30, cloth 12")
	assert_equal(Rules.work_wu(), 1000, "1000 WU")
	assert_equal(Rules.healer_slots(), 2, "Healer 2")
	assert_equal(Rules.max_builders(), 4, "4 builders")
	assert_equal(Rules.defs().unlock_of(Rules.type_id()), 1, "M1 in the tables (the demo: from the start)")
	assert_equal(Rules.PATIENT_BEDS, 8, "8 patient beds")
	assert_equal(Rules.work_usec(), 1000 * 150000, "a WU is 0.15 s")


func test_a_carry_is_the_carrier_s_mass_over_the_material_s() -> void:
	"""§5.2's 12000 / 24000 g over §5.5's 5000 g of wood or stone and 250 g of cloth."""
	assert_equal(Rules.carry_milli(MealRules.SIZE_SMALL, Rules.MAT_WOOD), 2400, "small, wood")
	assert_equal(Rules.carry_milli(MealRules.SIZE_LARGE, Rules.MAT_STONE), 4800, "large, stone")
	assert_equal(Rules.carry_milli(MealRules.SIZE_SMALL, Rules.MAT_CLOTH), 48000, "small, cloth: all 12 U at once")
	assert_equal(Rules.refund_milli(12345, false), 12345, "all before work")
	assert_equal(Rules.refund_milli(12345, true), 9876, "80% floored after")


# --- the books ------------------------------------------------------------------------------------

func _stores(wood_u: int, stone_u: int) -> StoresScript:
	"""Village stores holding this much wood and stone."""
	var stores := StoresScript.new()
	stores.wood_milli_u = wood_u * 1000
	stores.stone_milli_u = stone_u * 1000
	return stores


func _care(stores: StoresScript) -> StateScript:
	"""A care state of 10 residents whose treatments draw on these stores' cloth."""
	var care := StateScript.new()
	var sizes := PackedByteArray()
	sizes.resize(10)
	care.configure(sizes, -1)
	care.use_cloth(stores)
	return care


func _project(wood_u: int, stone_u: int, cloth_u: int) -> ProjectsScript:
	"""An infirmary's books over stores holding this much wood, stone and cloth, for 10 residents."""
	var stores := _stores(wood_u, stone_u)
	stores.cloth_milli_u = cloth_u * 1000
	return ProjectsScript.new(stores, 10)


func _deliver_all(project: ProjectsScript) -> void:
	"""Every material fetched and delivered."""
	for mat: int in Rules.MAT_COUNT:
		var need: int = project.outstanding(mat)
		project.reserve(mat, need)
		project.deliver(mat, project.lift(mat, need))


func test_placing_deducts_nothing_and_one_stands() -> void:
	"""REQ-SET-124: placed, nothing taken; a second refused."""
	var project := _project(40, 30, 24)
	assert_true(project.plan_at(SITE, 0.0), "placed")
	assert_equal(project.state, ProjectsScript.STATE_DELIVERING, "its materials to fetch")
	assert_equal([project.in_stock(Rules.MAT_WOOD), project.in_stock(Rules.MAT_CLOTH)], [40000, 24000], "nothing taken")
	assert_false(project.plan_at(Vector2(-8.0, 0.0), 0.0), "no second")


func test_cloth_comes_from_the_care_shelf_and_goes_back_there() -> void:
	"""Cloth reserved takes nothing; lifted, it leaves the shelf; a load put back and a cancel return it there."""
	var project := _project(0, 0, 24)
	project.plan_at(SITE, 0.0)
	assert_equal(project.next_material(), Rules.MAT_CLOTH, "only cloth to fetch")
	assert_equal(project.reserve(Rules.MAT_CLOTH, 48000), 12000, "never more than it needs")
	assert_equal(project.in_stock(Rules.MAT_CLOTH), 24000, "nothing taken yet")
	var lifted: int = project.lift(Rules.MAT_CLOTH, 12000)
	assert_equal([lifted, project.in_stock(Rules.MAT_CLOTH)], [12000, 12000], "taken from the shelf")
	project.return_load(Rules.MAT_CLOTH, 5000)
	assert_equal(project.in_stock(Rules.MAT_CLOTH), 17000, "back on the shelf")
	assert_true(project.deliver(Rules.MAT_CLOTH, 7000), "the rest delivered")
	assert_equal(project.cancel(), "", "cancelled")
	assert_equal(project.in_stock(Rules.MAT_CLOTH), 24000, "all of it back before the work")


func test_a_material_is_fetched_exactly_and_the_books_always_add_up() -> void:
	"""Only what the source holds unreserved is fetchable; a lift takes what is there; stock, arms and site add up."""
	var project := _project(40, 3, 0)
	project.plan_at(SITE, 0.0)
	assert_equal(project.fetchable(Rules.MAT_STONE), 3000, "only the stone there is")
	project.reserve(Rules.MAT_STONE, 2400)
	assert_equal(project.fetchable(Rules.MAT_STONE), 600, "the rest of it")
	var lifted: int = project.lift(Rules.MAT_STONE, 2400)
	assert_equal(project.outstanding(Rules.MAT_STONE), 27600, "a load in arms is not fetched again")
	project.deliver(Rules.MAT_STONE, lifted)
	assert_equal(project.in_stock(Rules.MAT_STONE) + project.delivered[Rules.MAT_STONE], 3000, "nothing made or lost")
	project.reserve(Rules.MAT_STONE, 600)
	project.in_stock(Rules.MAT_STONE)
	assert_equal(project.lift(Rules.MAT_STONE, 600), 600, "the last of it")
	assert_equal(project.lift(Rules.MAT_WOOD, 0), 0, "nothing reserved: nothing")


func test_all_delivered_starts_the_work_and_the_work_builds_it() -> void:
	"""REQ-SET-125; built, 8 beds, admitting and discharging; progress half delivery and half work."""
	var project := _project(40, 30, 12)
	project.plan_at(SITE, 0.0)
	assert_false(project.add_work(1000000), "no work before delivery")
	assert_equal(project.beds_free(), 0, "no beds before it is built")
	_deliver_all(project)
	assert_equal(project.state, ProjectsScript.STATE_BUILDING, "being built")
	assert_equal(project.percent(), 50, "half")
	assert_false(project.add_work(Rules.work_usec() - 1), "a microsecond short")
	assert_equal(project.percent(), 99, "never 100 before built")
	assert_true(project.add_work(1), "built")
	assert_equal(project.beds_free(), 8, "8 beds")
	for i: int in 8:
		assert_true(project.admit(i), "admitted %d" % i)
	assert_false(project.admit(8), "full")
	assert_false(project.admit(0), "already in")
	project.discharge(3)
	assert_true(project.admit(8), "a bed freed")
	assert_true(project.status_text().begins_with("Infirmary: built — 0 of 8 patient beds free"), project.status_text())
	assert_equal(project.cancel(), ProjectsScript.REFUSE_BUILT, "a built one is not cancelled")


func test_cancel_after_work_began_returns_eighty_percent() -> void:
	"""REQ-SET-126: 80% floored once the work has begun; nothing planned: refused."""
	var project := _project(40, 30, 12)
	assert_equal(project.cancel(), ProjectsScript.REFUSE_NOT_PLANNED, "nothing planned")
	project.plan_at(SITE, 0.0)
	_deliver_all(project)
	assert_true(project.status_text().begins_with("Infirmary: being built; wood 40 logs — enough, stone 30 blocks — enough, cloth 1½ bolts — enough"),
		project.status_text())
	project.add_work(1)
	assert_equal(project.refund_text(), "returns 32 logs, 24 blocks of stone, a bolt of cloth (80%: the work has begun)",
		"in measures")
	project.cancel()
	assert_equal([project.in_stock(Rules.MAT_WOOD), project.in_stock(Rules.MAT_STONE), project.in_stock(Rules.MAT_CLOTH)],
		[32000, 24000, 9600], "80% back")
	assert_equal(project.state, ProjectsScript.STATE_NONE, "gone")


# --- the builders ---------------------------------------------------------------------------------

func _build_cast() -> void:
	"""The placeholder cast in the village's bounds, every one carrying at 2 m/s."""
	_cast = DemoCastScript.new()
	_cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	_cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 13.0 * k / 65.0])
	for i: int in _cast.actor_count():
		_brain(i).set_carry_motion({"keys_xz": keys, "mean_speed_m_s": 2.0, "period_s": 6.5})


func _brain(i: int) -> BrainScript:
	"""Actor i's brain."""
	return (_cast.actor(i) as DemoActorScript).brain


func _builders(project: ProjectsScript) -> BuildersScript:
	"""The placed infirmary's builders on the placeholder cast."""
	_build_cast()
	project.plan_at(SITE, 0.0)
	var builders := BuildersScript.new(project)
	builders.configure(_cast, null, STORE_AT, SHELF_AT)
	return builders


func _books(project: ProjectsScript, builders: BuildersScript, mat: int) -> int:
	"""A material's milli-U in its source, in arms and at the site."""
	return project.in_stock(mat) + builders.in_hand_milli(mat) + project.delivered[mat]


func _step(builders: BuildersScript) -> void:
	"""One frame: every brain, the builders, and the board's claim of a waiting place for residents 1-4."""
	for i: int in _cast.actor_count():
		_brain(i).step(DT)
	builders.update(USEC)
	for row: int in BuildersScript.capacity():
		if builders.waiting(row):
			for who: int in [1, 2, 3, 4]:
				if builders.row_of_worker(who) == BuildersScript.NONE and builders.claim(row, who):
					break


func test_four_residents_fetch_exactly_what_it_costs_and_build_it() -> void:
	"""With more in the stores and on the shelf than it costs: four builders carry wood, stone and cloth -- the books
	adding up every frame -- exactly the cost reaches the site, and it is built; they go back to their routines."""
	var project := _project(60, 50, 24)
	var builders := _builders(project)
	var balanced: bool = true
	var at_switch := PackedInt64Array()
	for f: int in roundi(500.0 / DT):
		_step(builders)
		if at_switch.is_empty() and project.state != ProjectsScript.STATE_DELIVERING:
			at_switch = project.delivered.duplicate()
		balanced = balanced and (project.is_done() or (_books(project, builders, Rules.MAT_WOOD) == 60000
			and _books(project, builders, Rules.MAT_STONE) == 50000 and _books(project, builders, Rules.MAT_CLOTH) == 24000))
		if project.is_done():
			break
	assert_true(balanced, "the books balanced every frame")
	assert_equal(at_switch, PackedInt64Array([40000, 30000, 12000]), "exactly the cost at the site")
	assert_true(project.is_done(), "built")
	assert_equal([project.in_stock(Rules.MAT_WOOD), project.in_stock(Rules.MAT_STONE), project.in_stock(Rules.MAT_CLOTH)],
		[20000, 20000, 12000], "the cost taken, no more")
	assert_equal(builders.builders_on(), 0, "everyone let go")


func test_a_builder_called_away_puts_its_load_back_and_a_cancel_lets_everyone_go() -> void:
	"""Ordered elsewhere carrying: the load goes back whole and the place waits; release_all then cancel returns
	everything."""
	var project := _project(0, 30, 0)
	var builders := _builders(project)
	builders.claim(0, 1)
	for f: int in 12000:
		if builders.carrying(0) and builders.issued[0] == 1:
			break
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		builders.update(USEC)
	assert_true(builders.carrying(0), "carrying")
	_brain(1).order_move(Vector2(-8.0, -8.0))
	builders.update(USEC)
	assert_equal(project.in_stock(Rules.MAT_STONE), 30000, "back whole")
	assert_true(builders.waiting(0), "waits again")
	builders.claim(0, 2)
	builders.claim(1, 3)
	builders.release_all()
	assert_equal(builders.builders_on(), 0, "nobody on it")
	assert_equal(project.cancel(), "", "cancelled")
	assert_equal(project.in_stock(Rules.MAT_STONE), 30000, "every unit back")


func test_a_place_waits_only_while_something_can_be_fetched_or_built() -> void:
	"""Nothing in the stores or on the shelf: no place waits; cloth on the shelf: they wait; the words say what."""
	var project := _project(0, 0, 0)
	var builders := _builders(project)
	assert_false(builders.waiting(0), "nothing to fetch")
	project._stores.cloth_milli_u = 12000
	assert_true(builders.waiting(0), "cloth to fetch")
	builders.claim(0, 1)
	assert_equal(builders.doing_text(1), "Going to fetch cloth for the infirmary", "its words")
	assert_equal(builders.eligibility(1, 1), BuildersScript.OTHER_PLACE, "one place each")


# --- placing it -------------------------------------------------------------------------------------

func _site() -> RoomsScript.Site:
	"""A 40 m village with a tree at (10, 10) and water along x = 18."""
	var site := RoomsScript.Site.new()
	site.bounds_u = Rect2i(-20480, -20480, 40960, 40960)
	site.circles_u = PackedInt32Array([10240, 1024, 10240])
	site.spots_u = PackedInt32Array([-10240, 512, 10240])
	site.under_u = PackedInt32Array([10240, 2048, -10240])
	site.beds_u = PackedInt32Array([-10240, 1536, -10240])
	site.water = func(a: Vector2i, _b: Vector2i, clearance: int) -> bool: return a.x + clearance > 18432
	return site


func test_it_may_stand_only_clear_of_everything_and_once() -> void:
	"""In the open: allowed; off, on a tree, by the water, over a tunnel: refused in words; planned already: refused."""
	var project := _project(0, 0, 0)
	var network := GraphScript.new()
	var site := _site()
	assert_equal(PlaceScript.refusal_at(Vector2.ZERO, site, network, project), "", "in the open")
	assert_equal(PlaceScript.refusal_at(Vector2(19.0, 0.0), site, network, project), PlaceScript.REFUSE_OFF, "off")
	assert_equal(PlaceScript.refusal_at(Vector2(10.0, 12.0), site, network, project), PlaceScript.REFUSE_BLOCKED, "tree")
	assert_equal(PlaceScript.refusal_at(Vector2(16.0, -5.0), site, network, project), PlaceScript.REFUSE_WATER, "water")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([-4096, -8192, 4096, -8192]), 2, 0, ref), "a tunnel")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -7.0), site, network, project), PlaceScript.REFUSE_TUNNEL, "tunnel")
	project.plan_at(Vector2(-8.0, 8.0), 0.0)
	assert_equal(PlaceScript.refusal_at(Vector2.ZERO, site, network, project), ProjectsScript.REFUSE_EXISTS, "one only")


func test_the_tool_places_says_why_and_is_put_away() -> void:
	"""Armed, a refused spot says why; a clear one places it and the tool is put away; Esc puts it away."""
	var tool := PlaceScript.new()
	_nodes.append(tool)
	var said: Array[String] = [""]
	var project := _project(0, 0, 0)
	tool.configure(project, _site, Callable(), GraphScript.new(), null, null, func(text: String) -> void: said[0] = text)
	tool.arm()
	assert_equal(said[0], PlaceScript.PROMPT, "the prompt")
	tool.move_to(Vector2(10.0, 12.0))
	assert_false(tool.place(), "refused")
	assert_equal(said[0], PlaceScript.REFUSED % PlaceScript.REFUSE_BLOCKED, "why")
	tool.move_to(Vector2(0.0, 6.0))
	assert_true(tool.place(), "placed")
	assert_false(tool.armed, "put away")
	assert_equal(said[0], "Infirmary planned: 40 logs, 30 blocks of stone and 1½ bolts of cloth to fetch, then 1000 WU of building",
		"said")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tool.arm()
	assert_true(tool.handle_input(esc), "Esc taken")
	assert_false(tool.armed, "put away")


# --- drawn, on the board, as an obstacle -------------------------------------------------------------------

func test_it_is_drawn_flat_then_rising_then_whole_and_its_piles_grow() -> void:
	"""Placed: flat; delivered and half built: half risen; built: whole, piles gone."""
	var project := _project(40, 30, 12)
	project.plan_at(SITE, 0.0)
	assert_equal(ViewScript.body_scale(project), ViewScript.MARKED_SCALE, "flat")
	assert_equal(ViewScript.pile_scale(project, Rules.MAT_CLOTH), 0.0, "no pile yet")
	_deliver_all(project)
	assert_equal(ViewScript.pile_scale(project, Rules.MAT_CLOTH), 1.0, "a full pile")
	@warning_ignore("integer_division")  # half the work by intent
	var half: int = Rules.work_usec() / 2
	project.add_work(half)
	assert_almost_equal(ViewScript.body_scale(project), lerpf(ViewScript.BEGUN_SCALE, 1.0, 0.5), "half risen")
	project.add_work(half)
	assert_equal(ViewScript.body_scale(project), 1.0, "whole")
	assert_equal(ViewScript.pile_scale(project, Rules.MAT_WOOD), 0.0, "piles gone")
	assert_equal(ViewScript.label_text(project), "Infirmary", "its name")
	var view := ViewScript.new()
	_nodes.append(view)
	view.configure(project, null)
	assert_true(view.body().visible, "drawn")


func test_the_board_lists_its_places_on_the_infirmary_source() -> void:
	"""SOURCE_CARE: a place's key holds through claims; fetching is HAULING, building BUILDING; cancel is refused alone."""
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a queued walk is past every source")
	assert_equal(WorkIds.SOURCE_NAMES[WorkIds.SOURCE_CARE], "Infirmary", "named")
	var project := _project(40, 30, 12)
	var builders := _builders(project)
	var source := CareWork.new(builders, [] as Array[BrainScript])
	assert_equal(source.id, WorkIds.SOURCE_CARE, "its source")
	var before: int = source.key(1)
	builders.claim(1, 2)
	assert_equal(source.key(1), before, "the same once claimed")
	assert_equal(source.activity(1), WorkIds.ACT_HAUL, "fetching")
	assert_equal(source.cancel(1), CareWork.BY_ITS_BUILDING, "cancelled with the building")
	assert_true(source.live(1), "on the board")
	var task := TaskScript.new()
	source.fill(task, 0)
	assert_equal(task.target, "infirmary", "its target")


func test_the_building_node_stands_as_an_obstacle_and_cancels() -> void:
	"""Placed through the node: an obstacle circle in the last structure slot; cancelled: none; a second placing is
	refused in words."""
	_build_cast()
	var building := BuildingScript.new()
	_nodes.append(building)
	building.configure(_cast, _stores(40, 30), _care(StoresScript.new()), null, STORE_AT, SHELF_AT)
	assert_true(building.project.plan_at(SITE, 0.0), "placed")
	building.sync_footprint()
	assert_equal(_cast.space().structure_circles().size(), 1, "an obstacle")
	assert_equal(BuildingScript.STRUCTURE, CastSpaceScript.STRUCTURES - 1, "the last slot")
	assert_equal(building.start_placing(), ProjectsScript.REFUSE_EXISTS, "one only")
	assert_equal(building.cancel(), "", "cancelled")
	building.sync_footprint()
	assert_equal(_cast.space().structure_circles().size(), 0, "gone")


# --- boundaries (mutation testing) -------------------------------------------------------------------------------

func test_a_lift_takes_only_what_is_left_and_nothing_is_delivered_after_a_cancel() -> void:
	"""Reserved 2.4 wood but the stores fell to 1 U: the lift takes 1 U; cancelled, a delivery is refused; a material a
	half-unit short keeps it fetching."""
	var project := _project(10, 30, 12)
	project.plan_at(SITE, 0.0)
	project.reserve(Rules.MAT_WOOD, 2400)
	project._stores.wood_milli_u = 1000
	assert_equal(project.lift(Rules.MAT_WOOD, 2400), 1000, "what was there")
	project.cancel()
	assert_false(project.deliver(Rules.MAT_WOOD, 1000), "not delivered to a cancelled infirmary")
	var short := _project(40, 30, 12)
	short.plan_at(SITE, 0.0)
	for mat: int in Rules.MAT_COUNT:
		var need: int = Rules.cost_milli(mat) - (500 if mat == Rules.MAT_CLOTH else 0)
		short.reserve(mat, need)
		short.deliver(mat, short.lift(mat, need))
	assert_equal(short.state, ProjectsScript.STATE_DELIVERING, "0.5 U of cloth short: still fetching")


func test_a_resident_is_admitted_once() -> void:
	"""Admitted, the same resident is not given a second bed."""
	var project := _project(40, 30, 12)
	project.plan_at(SITE, 0.0)
	project.state = ProjectsScript.STATE_DONE
	assert_true(project.admit(2), "admitted")
	assert_false(project.admit(2), "not twice")
	assert_equal(project.beds_free(), 7, "one bed taken")


func test_a_place_waits_to_build_and_one_that_gave_up_rests() -> void:
	"""Everything delivered: the places wait to build; the stockpile off the village: the walk is given up, the place
	rests RETRY_USEC, its reservation given back."""
	var project := _project(40, 30, 12)
	var builders := _builders(project)
	_deliver_all(project)
	assert_true(builders.waiting(0), "waits to build")
	builders.claim(0, 1)
	assert_equal(builders.doing_text(1), "Going to build the infirmary", "its words")
	var far := _project(0, 30, 0)
	far.plan_at(SITE, 0.0)
	var lost := BuildersScript.new(far)
	lost.configure(_cast, null, Vector2(80.0, 0.0), SHELF_AT)
	lost.claim(0, 2)
	lost.update(USEC)
	assert_equal(far.reserved[Rules.MAT_STONE], 0, "its reservation given back")
	assert_false(lost.waiting(0), "resting")
	lost.update(BuildersScript.RETRY_USEC)
	assert_true(lost.waiting(0), "waits again")


func test_cloth_is_fetched_from_the_shelf_and_a_pause_gives_back_the_reservation() -> void:
	"""A builder fetching cloth walks to the care shelf; paused before it lifts, its reservation is given back."""
	var project := _project(0, 0, 24)
	var builders := _builders(project)
	builders.claim(0, 1)
	builders.update(USEC)
	assert_true(builders.goal[0].distance_to(SHELF_AT) < 2.5, "to the shelf: %s" % builders.goal[0])
	assert_equal(project.reserved[Rules.MAT_CLOTH], 12000, "reserved")
	assert_equal(builders.pause(0, true), "", "paused")
	assert_equal(project.reserved[Rules.MAT_CLOTH], 0, "given back")


func test_the_tool_refuses_when_one_was_planned_meanwhile() -> void:
	"""The ghost over a clear spot, then an infirmary planned elsewhere: the click is refused."""
	var tool := PlaceScript.new()
	_nodes.append(tool)
	var project := _project(0, 0, 0)
	tool.configure(project, _site, Callable(), GraphScript.new(), null, null, Callable())
	tool.arm()
	tool.move_to(Vector2(0.0, 6.0))
	project.plan_at(Vector2(-8.0, -8.0), 0.0)
	assert_false(tool.place(), "refused")
	assert_equal(project.at, Vector2(-8.0, -8.0), "the first stands")


func test_the_board_key_changes_with_a_new_building_and_building_is_building() -> void:
	"""A cancelled and replanted infirmary is a new task; its places are BUILDING once everything is delivered."""
	var project := _project(40, 30, 12)
	var builders := _builders(project)
	var source := CareWork.new(builders, [] as Array[BrainScript])
	var before: int = source.key(0)
	project.cancel()
	project.plan_at(SITE, 0.0)
	assert_true(source.key(0) != before, "a new task")
	_deliver_all(project)
	assert_equal(source.activity(0), WorkIds.ACT_BUILD, "building")



# --- the review's cases (decision 0623) ------------------------------------------------------------------------

func test_every_placing_refusal_and_the_care_places_kept_clear() -> void:
	"""A work spot, a building, a crop bed, a blocked door, and the care desk's own places: refused in words."""
	var project := _project(0, 0, 0)
	var site := _site()
	assert_equal(PlaceScript.refusal_at(Vector2(-10.0, 12.0), site, null, project), PlaceScript.REFUSE_SPOT, "spot")
	assert_equal(PlaceScript.refusal_at(Vector2(10.0, -13.5), site, null, project), PlaceScript.REFUSE_BUILDING, "building")
	assert_equal(PlaceScript.refusal_at(Vector2(-10.0, -13.5), site, null, project), PlaceScript.REFUSE_BED, "bed")
	var keep := PackedInt32Array([0, 512, 6144])
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, 4.0), site, null, project, keep), PlaceScript.REFUSE_KEEP, "the shelf")
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -4.0), site, null, project, keep), "", "clear of it")
	site.circles_u = PackedInt32Array([0, 307, -3482])
	assert_equal(PlaceScript.refusal_at(Vector2(0.0, -7.0), site, null, project), PlaceScript.REFUSE_DOOR, "door blocked")


func test_cloth_kept_for_treatments_is_not_fetched_for_the_building() -> void:
	"""One store (decision 0993): cloth a treatment has reserved is kept back from the building's fetch, and cloth the
	building has reserved is kept back from a second treatment."""
	var project := _project(0, 0, 12)
	var care := _care(project._stores)
	project.plan_at(SITE, 0.0)
	care.hurt(0, Injury.KIND_BITE, Injury.SEVERITY_MINOR, 10)
	care.hurt(1, Injury.KIND_BITE, Injury.SEVERITY_MINOR, 10)
	assert_true(care.claim_cloth(0), "a treatment reserves its half unit")
	assert_equal(project.fetchable(Rules.MAT_CLOTH), 11500, "half a unit kept for the treatment")
	assert_equal(project.reserve(Rules.MAT_CLOTH, 12000), 11500, "the building reserves the rest")
	assert_equal(project._stores.cloth_claim(StoresScript.CLOTH_INFIRMARY), 11500, "under the infirmary's claim")
	assert_false(care.claim_cloth(1), "no second treatment on the building's cloth")
	assert_equal(care.treatment_refusal(1), StateScript.REFUSE_NO_CLOTH, "and it says why")
	assert_equal(care.treatment_refusal(0), StateScript.REFUSE_NONE, "the first holds its own")
	project.unreserve(Rules.MAT_CLOTH, 11500)
	assert_true(care.claim_cloth(1), "given back, the second may")


func test_the_building_node_arms_after_putting_the_dig_tool_away() -> void:
	"""`before_placing` runs before the tool is armed; with no camera a hover does nothing."""
	_build_cast()
	var building := BuildingScript.new()
	_nodes.append(building)
	building.configure(_cast, _stores(40, 30), _care(StoresScript.new()), null, STORE_AT, SHELF_AT)
	building.configure_place(_site, Callable(), GraphScript.new(), null, null, Callable(), PackedVector2Array())
	var ran: Array[bool] = [false]
	building.before_placing = func() -> void: ran[0] = true
	assert_equal(building.start_placing(), "", "armed")
	assert_true(ran[0], "the Dig tool put away first")
	building.place.hover(Vector2(10.0, 10.0))
	assert_true(building.place.armed, "a hover without a camera changes nothing")
	building.project.plan_at(SITE, 0.0)
	building.sync_footprint()
	building.project.cancel()
	building.project.plan_at(Vector2(-4.0, -4.0), 0.0)
	building.sync_footprint()
	var circles: PackedVector3Array = _cast.space().structure_circles()
	assert_equal(Vector2(circles[0].x, circles[0].z), Vector2(-4.0, -4.0), "moved with a re-placing between frames")
