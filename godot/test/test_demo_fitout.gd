extends "res://test/framework/test_case.gd"
## The fit-out (decision 0210, the underground revamp's P4): fixtures on a room's places, their costs from the demo
## stores (all or nothing, refused in words), the suggested layout, taking one out, a cellar's capacity as the sum of
## its racks, the cool rule's edges, the comfort formula, and who puts a fixture in. The night -- beds by REQ-SET-132,
## the routine home and back to work -- is test_demo_night.gd.
##
## No scene tree and no staged assets. Rooms are laid straight on the network (underground_graph.gd `add_room`, not
## checked by the room rules) and dug; values are worked by hand from room_fixtures.gd.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const RoomTextScript := preload("res://demo/burrow/room_text.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")

const BOUNDS_U := Rect2i(-40960, -40960, 81920, 81920)
const HOME: int = RoomsScript.TEMPLATE_HOME
const CELLAR: int = RoomsScript.TEMPLATE_CELLAR
const PLANNED: int = FixturesScript.PLANNED
const INSTALLED: int = FixturesScript.INSTALLED


# --- fixtures -------------------------------------------------------------------------------------

func _room(graph: GraphScript, kind: int, at: Vector2i, dug: bool = true) -> int:
	"""A room of `kind` laid at `at` (u), turned 0, dug unless told not to; its row."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(kind, at, 0, 0, ref), "a room laid")
	if dug:
		_dig(graph, ref[2])
	return ref[0]


static func _dig(graph: GraphScript, p: int) -> void:
	"""Dig every segment of piece `p` open, in its order."""
	var chain := PackedInt32Array()
	graph.piece_segments_into(p, chain)
	for slot in chain:
		if not graph.is_open(slot):
			graph.start_dig(slot, graph.generation[slot], 0)
			graph.advance(slot, graph.generation[slot], 1000000000)


static func _stores(planks_u: int, wood_u: int, stone_u: int) -> StoresScript:
	"""Demo stores holding exactly this many whole units."""
	var stores := StoresScript.new()
	stores.wood_milli_u = wood_u * 1000
	stores.stone_milli_u = stone_u * 1000
	stores.plank_milli_u = planks_u * 1000
	return stores


static func _install(graph: GraphScript, r: int, kind: int) -> void:
	"""Put the first empty place of `kind` in room `r` straight in (its order and work skipped)."""
	var template: int = graph.rooms.template[r]
	for f in RoomsScript.fixture_count(template):
		if FixturesScript.place_kind(template, f) == kind and graph.fit.phase_of(graph, r, f) == FixturesScript.EMPTY:
			graph.fit.phase[r * FixturesScript.PLACES + f] = INSTALLED
			graph.fit.revision += 1
			return


static func _held(stores: StoresScript) -> Vector3i:
	"""What the stores hold: (planks, wood, stone) milli-U."""
	return Vector3i(stores.plank_milli_u, stores.wood_milli_u, stores.stone_milli_u)


# --- the places and the palette -------------------------------------------------------------------

func test_a_home_and_a_cellar_have_their_places() -> void:
	"""A home's eight places -- three beds in its alcoves, a hearth, a table and a rug before it, a lantern, hanging
	stores -- and a cellar's five -- two shelves, a rack, a bin, hanging stores; each palette once per kind, in place
	order."""
	assert_equal(RoomsScript.fixture_count(HOME), 8, "a home's places")
	assert_equal(RoomsScript.fixture_count(CELLAR), 5, "a cellar's")
	assert_equal(FixturesScript.palette(HOME), PackedInt32Array([RoomsScript.FIX_BED, RoomsScript.FIX_BIG_BED,
		RoomsScript.FIX_HEARTH, RoomsScript.FIX_TABLE, RoomsScript.FIX_RUG, RoomsScript.FIX_LANTERN, RoomsScript.FIX_HANGING]),
		"a home's palette: the large bed after the bed (decision 0211)")
	assert_equal(FixturesScript.palette(CELLAR), PackedInt32Array([RoomsScript.FIX_SHELF, RoomsScript.FIX_RACK,
		RoomsScript.FIX_BIN, RoomsScript.FIX_HANGING]), "a cellar's")
	assert_false(FixturesScript.allows(CELLAR, RoomsScript.FIX_HEARTH), "no hearth in a cellar")
	assert_true(FixturesScript.allows(HOME, RoomsScript.FIX_HEARTH), "a home has one")
	assert_true(RoomsScript.fixture_count(HOME) <= RoomsScript.MAX_PLACES and RoomsScript.fixture_count(CELLAR) <= RoomsScript.MAX_PLACES,
		"within MAX_PLACES")
	assert_equal(FixturesScript.install_usec(RoomsScript.FIX_HEARTH), 60 * FixturesScript.INSTALL_USEC_PER_WU, "a hearth: 60 WU")


func test_the_costs_are_the_table_s() -> void:
	"""Each kind's cost in words, from the design's table in demo stores (room_fixtures.gd COSTS)."""
	var words: Array[String] = []
	for kind in RoomsScript.FIXTURE_KINDS:
		words.append(FixturesScript.cost_text(kind))
	assert_equal(words, ["2 planks", "6 stone", "2 planks", "2 planks", "1 wood", "2 planks", "2 planks", "1 wood", "1 wood",
		"4 planks"] as Array[String], "bed, hearth, table, shelf, rug, rack, bin, hanging stores, lantern, large bed")
	assert_equal(FixturesScript.amounts_text(0, 0, 0), "nothing", "a free thing")


# --- ordering: all or nothing, refused in words ---------------------------------------------------

func test_a_fixture_is_paid_for_all_or_nothing() -> void:
	"""A bed with a plank short is refused SHORT and nothing is taken; with two planks it is planned in the first bed
	place, the two planks paid, kept for nobody."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(1, 5, 5)
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_SHORT, "a plank short")
	assert_equal(_held(stores), Vector3i(1000, 5000, 5000), "nothing taken")
	stores.add_planks(1000)
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "planned")
	assert_equal(_held(stores), Vector3i(0, 5000, 5000), "two planks paid")
	assert_equal(graph.fit.phase_of(graph, r, 0), PLANNED, "in the first bed place")
	assert_equal(graph.fit.asked[r * FixturesScript.PLACES], -1, "kept for nobody")
	assert_equal(graph.fit.count(graph, r, RoomsScript.FIX_BED, PLANNED), 1, "one bed coming")
	assert_equal(graph.fit.count(graph, r, RoomsScript.FIX_BED, INSTALLED), 0, "none in")


func test_a_hearth_pays_stone_and_a_rug_wood() -> void:
	"""Stone for a hearth, wood for a rug -- each exactly its cost, and a store short of the other thing is enough."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(0, 1, 6)
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_HEARTH, stores), FixturesScript.REFUSE_NONE, "a hearth")
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_RUG, stores), FixturesScript.REFUSE_NONE, "a rug")
	assert_equal(_held(stores), Vector3i.ZERO, "six stone and one wood paid")
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_LANTERN, stores), FixturesScript.REFUSE_SHORT, "no wood left")


func test_refusals_come_before_the_cost_and_in_words() -> void:
	"""An undug room, a kind with no place in the template, and every place of a kind taken are each refused before
	anything is paid, each in its own words."""
	var graph := GraphScript.new()
	var laid := _room(graph, HOME, Vector2i.ZERO, false)
	var cellar := _room(graph, CELLAR, Vector2i(12288, 0))
	var home := _room(graph, HOME, Vector2i(-12288, 0))
	var stores := _stores(20, 20, 20)
	assert_equal(graph.fit.order(graph, laid, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NOT_DUG, "not dug")
	assert_equal(graph.fit.order(graph, cellar, RoomsScript.FIX_HEARTH, stores), FixturesScript.REFUSE_NOT_HERE, "a cellar keeps cool")
	for k in 3:
		assert_equal(graph.fit.order(graph, home, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "bed %d" % k)
	assert_equal(graph.fit.order(graph, home, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_FULL, "a fourth")
	assert_equal(_held(stores), Vector3i(14000, 20000, 20000), "only the three beds paid")
	assert_equal(RoomTextScript.answer(graph, cellar, PackedStringArray(["fit", "add", "1"]), FixturesScript.REFUSE_NOT_HERE,
		stores, Callable()), "Can't: a hearth has no place in a root cellar", "in words")
	assert_equal(RoomTextScript.answer(graph, home, PackedStringArray(["fit", "add", "0"]), FixturesScript.REFUSE_FULL,
		stores, Callable()), "Can't: every place for a bed in Burrow home %d is taken" % (home + 1), "in words")
	var seen: Array[String] = []
	for code in range(1, FixturesScript.REASONS.size()):
		assert_false(seen.has(FixturesScript.REASONS[code]), "code %d: its own words" % code)
		seen.append(FixturesScript.REASONS[code])


func test_the_short_refusal_says_what_is_needed_and_held() -> void:
	"""SHORT names the thing, its cost and what the stores hold."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(1, 2, 3)
	var code := graph.fit.order(graph, r, RoomsScript.FIX_BED, stores)
	assert_equal(RoomTextScript.answer(graph, r, PackedStringArray(["fit", "add", "0"]), code, stores, Callable()),
		"Can't: the demo stores are short: the bed needs 2 planks (they hold 1 planks, 2 wood, 3 stone)", "in words")
	code = graph.fit.suggest(graph, r, stores)
	assert_equal(RoomTextScript.answer(graph, r, PackedStringArray(["fit", "suggest"]), code, stores, Callable()),
		"Can't: the demo stores are short: the suggested layout needs 10 planks, 3 wood, 6 stone (they hold 1 planks, 2 wood, 3 stone)",
		"the layout's")


# --- the suggested layout ---------------------------------------------------------------------------

func test_the_suggested_layout_plans_every_empty_place_or_none() -> void:
	"""A home's layout costs 10 planks (a large bed in its back alcove, two burrow beds and a table: decision 0211), 3 wood
	(a rug, a lantern, hanging stores) and 6 stone (the hearth); a plank short, nothing is planned or paid; with enough,
	all eight places are, paid exactly, the large bed in place 0 with its nook dug; again, NOTHING_TO_ADD. With a bed
	already in (place 0), the large bed goes by the door (place 2), and it costs two planks less."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	assert_equal(graph.fit.missing_cost(graph, r), Vector3i(10000, 3000, 6000), "its cost")
	var stores := _stores(9, 3, 6)
	assert_equal(graph.fit.suggest(graph, r, stores), FixturesScript.REFUSE_SHORT, "a plank short")
	assert_equal(_held(stores), Vector3i(9000, 3000, 6000), "nothing paid")
	assert_equal(graph.fit.count(graph, r, RoomsScript.FIX_BED, PLANNED), 0, "nothing planned")
	stores.add_planks(1000)
	assert_equal(graph.fit.suggest(graph, r, stores), FixturesScript.REFUSE_NONE, "planned")
	assert_equal(_held(stores), Vector3i.ZERO, "paid exactly")
	for f in RoomsScript.fixture_count(HOME):
		assert_equal(graph.fit.phase_of(graph, r, f), PLANNED, "place %d planned" % f)
	assert_equal([graph.fit.kind_at(graph, r, 0), graph.fit.kind_at(graph, r, 1), graph.fit.kind_at(graph, r, 2)],
		[RoomsScript.FIX_BIG_BED, RoomsScript.FIX_BED, RoomsScript.FIX_BED], "a large bed in the back alcove, burrow beds in the rest")
	assert_equal(graph.rooms.nooks[r], 1, "its nook dug")
	assert_equal(graph.fit.suggest(graph, r, stores), FixturesScript.REFUSE_NOTHING_TO_ADD, "fitted out")
	var other := _room(graph, HOME, Vector2i(12288, 0))
	_install(graph, other, RoomsScript.FIX_BED)
	assert_equal(graph.fit.missing_cost(graph, other), Vector3i(8000, 3000, 6000), "a bed in: two planks less")
	var layout := PackedInt32Array()
	graph.fit.layout_into(graph, other, layout)
	assert_equal(layout[2], RoomsScript.FIX_BIG_BED, "the large bed by the door instead")
	var cellar := _room(graph, CELLAR, Vector2i(-12288, 0))
	assert_equal(graph.fit.missing_cost(graph, cellar), Vector3i(8000, 1000, 0), "a cellar's: two shelves, a rack, a bin, hanging stores")
	assert_equal(graph.fit.suggest(graph, _room(graph, HOME, Vector2i(0, 12288), false), stores), FixturesScript.REFUSE_NOT_DUG,
		"not before it is dug")


# --- taking out -------------------------------------------------------------------------------------

func test_taking_one_out_gives_its_cost_back_the_planned_first() -> void:
	"""Two beds, one in and one planned: taking a bed out empties the planned one first and gives its two planks back;
	then the installed one; then there is none to take."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	_install(graph, r, RoomsScript.FIX_BED)
	var stores := _stores(2, 0, 0)
	graph.fit.order(graph, r, RoomsScript.FIX_BED, stores)
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "taken out")
	assert_equal(stores.plank_milli_u, 2000, "its planks back")
	assert_equal([graph.fit.phase_of(graph, r, 0), graph.fit.phase_of(graph, r, 1)], [INSTALLED, FixturesScript.EMPTY],
		"the planned one went")
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "the installed one")
	assert_equal(stores.plank_milli_u, 4000, "its planks back too")
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE_TO_TAKE, "none left")


func test_a_cellar_keeps_racks_for_the_food_it_holds() -> void:
	"""A cellar with a shelf (20 U) and a rack (30 U) holding 21 U: the rack may not go (20 U left < 21), the shelf may
	(30 U left); holding exactly 30, the rack still may not go below it. A planned rack always may."""
	var graph := GraphScript.new()
	var r := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, r, RoomsScript.FIX_SHELF)
	_install(graph, r, RoomsScript.FIX_RACK)
	var stores := _stores(0, 0, 0)
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_RACK, stores, 21), FixturesScript.REFUSE_HOLDS_FOOD, "the rack holds it")
	assert_equal(graph.fit.capacity_u(graph, r), 50, "nothing taken")
	assert_equal(RoomTextScript.answer(graph, r, PackedStringArray(["fit", "take", "5"]), FixturesScript.REFUSE_HOLDS_FOOD, stores,
		func(_room_row: int) -> int: return 21), "Can't: Root cellar %d holds 21 U of food: its racks cannot drop below that" % (r + 1),
		"in words")
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_SHELF, stores, 30), FixturesScript.REFUSE_NONE, "the shelf may go")
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_RACK, stores, 30), FixturesScript.REFUSE_HOLDS_FOOD, "30 U: not below it")
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_RACK, stores, 0), FixturesScript.REFUSE_NONE, "empty, it may")
	stores.add_planks(2000)
	graph.fit.order(graph, r, RoomsScript.FIX_RACK, stores)
	assert_equal(graph.fit.take_out(graph, r, RoomsScript.FIX_RACK, stores, 99), FixturesScript.REFUSE_NONE, "a planned rack holds nothing")


# --- capacity and the cool rule -------------------------------------------------------------------

func test_a_cellar_s_capacity_is_the_sum_of_its_installed_racks() -> void:
	"""Bare, nothing (and no store); then 20 (a shelf), 50 (a rack), 75 (a bin), 85 (hanging stores), 105 (the other
	shelf) -- a planned one adds nothing -- and the cellar API publishes it."""
	var graph := GraphScript.new()
	var r := _room(graph, CELLAR, Vector2i.ZERO)
	assert_equal(graph.fit.capacity_u(graph, r), 0, "bare")
	assert_equal(graph.rooms.cellars(graph).size(), 0, "no store")
	var stores := _stores(2, 0, 0)
	graph.fit.order(graph, r, RoomsScript.FIX_BIN, stores)
	assert_equal(graph.fit.capacity_u(graph, r), 0, "a planned bin holds nothing")
	var sums: Array[int] = []
	for kind: int in [RoomsScript.FIX_SHELF, RoomsScript.FIX_RACK, RoomsScript.FIX_BIN, RoomsScript.FIX_HANGING, RoomsScript.FIX_SHELF]:
		if kind == RoomsScript.FIX_BIN:
			graph.fit.phase[r * FixturesScript.PLACES + 3] = INSTALLED
		else:
			_install(graph, r, kind)
		sums.append(graph.fit.capacity_u(graph, r))
	assert_equal(sums, [20, 50, 75, 85, 105] as Array[int], "the sums")
	assert_equal(graph.fit.storage_count(graph, r), 5, "five storage fixtures")
	assert_equal(graph.rooms.cellars(graph)[0]["capacity_u"], 105, "published")


func test_the_cool_rule_on_its_facts() -> void:
	"""COOL_DEPTH_U deep exactly is deep, a unit less is shallow; no storage fixture, no store; a hearth near or one
	it opens onto warms it -- each the first reason, in order."""
	assert_equal(FixturesScript.cool_of(1024, 1, false, false), FixturesScript.COOL_YES, "1 m down: cool")
	assert_equal(FixturesScript.cool_of(1023, 1, false, false), FixturesScript.COOL_SHALLOW, "a unit less: shallow")
	assert_equal(FixturesScript.cool_of(1023, 0, true, true), FixturesScript.COOL_SHALLOW, "shallow first")
	assert_equal(FixturesScript.cool_of(1280, 0, true, true), FixturesScript.COOL_NO_RACK, "then no rack")
	assert_equal(FixturesScript.cool_of(1280, 1, true, true), FixturesScript.COOL_HEARTH_NEAR, "then a hearth near")
	assert_equal(FixturesScript.cool_of(1280, 1, false, true), FixturesScript.COOL_HEARTH_OPENS, "then one it opens onto")
	assert_equal(FixturesScript.cool_of(5376, 3, false, false), FixturesScript.COOL_YES, "level 2's floor, racked")
	assert_equal(FixturesScript.COOL_WORDS.size(), 5, "each in words")


func test_a_hearth_within_three_metres_warms_a_cellar() -> void:
	"""A home with a hearth, its void HEAT_REACH_U from a racked cellar's void, leaves it cool (350); a unit nearer, it
	is warm (750) -- and it is the hearth, not the home: without one it is cool again. Void gap = x - 1689 - 2252."""
	var graph := GraphScript.new()
	var cellar := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, cellar, RoomsScript.FIX_RACK)
	var edge := _room(graph, HOME, Vector2i(3941 + FixturesScript.HEAT_REACH_U, 0))
	_install(graph, edge, RoomsScript.FIX_HEARTH)
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_YES, "3 m of earth: cool")
	assert_equal(graph.rooms.cellars(graph)[0]["spoilage_permille"], 350, "the cellar's factor")
	var near := _room(graph, HOME, Vector2i(-3941 - FixturesScript.HEAT_REACH_U + 1, 0))
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_YES, "no hearth in the nearer home yet")
	_install(graph, near, RoomsScript.FIX_HEARTH)
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_HEARTH_NEAR, "a unit nearer: warm")
	assert_equal(graph.rooms.cellars(graph)[0]["spoilage_permille"], 750, "the pantry's factor")
	assert_false(graph.fit.is_cool(graph, cellar), "not cool")


func _joined(opens_u: int) -> GraphScript:
	"""A racked cellar at the origin and a home with a hearth east of it on the same line, a straight passage of
	`opens_u` joining the cellar's east socket to the home's west one, dug."""
	var graph := GraphScript.new()
	var cellar := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, cellar, RoomsScript.FIX_SHELF)
	var home := _room(graph, HOME, Vector2i(1536 + opens_u + 2048, 0))
	_install(graph, home, RoomsScript.FIX_HEARTH)
	var from := graph.rooms.socket_of(cellar, 1)
	var to := graph.rooms.socket_of(home, 2)
	var plan := PlanScript.new()
	assert_equal(plan.try_add_snapped(1536, 0, SpecScript.END_NODE, from, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "from its socket")
	assert_equal(plan.try_add_snapped(1536 + opens_u, 0, SpecScript.END_NODE, to, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "to the home's")
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(0), piece), "the passage laid")
	_dig(graph, piece[2])
	return graph


func test_a_cellar_that_opens_onto_a_hearth_is_warm() -> void:
	"""Joined by a passage of OPENS_ONTO_U to a home with a hearth (its void well over 3 m away), a cellar is warm; by
	a unit more, it is cool."""
	var opens := _joined(FixturesScript.OPENS_ONTO_U)
	assert_equal(opens.fit.cool(opens, 0), FixturesScript.COOL_HEARTH_OPENS, "6 m of passage: it opens onto the hearth")
	var apart := _joined(FixturesScript.OPENS_ONTO_U + 1)
	assert_equal(apart.fit.cool(apart, 0), FixturesScript.COOL_YES, "a unit more: cool")


# --- comfort ----------------------------------------------------------------------------------------

func test_comfort_is_a_bed_a_hearth_and_capped_decorations() -> void:
	"""The formula on its facts: the floor 2000, a bed 2000 more, a hearth 2000 more, 250 a decoration up to 1000, at
	most 10000; and its words at each floor."""
	assert_equal(FixturesScript.comfort_of(false, false, 0), 2000, "a bare home: the floor")
	assert_equal(FixturesScript.comfort_of(true, false, 0), 4000, "a bed")
	assert_equal(FixturesScript.comfort_of(true, true, 0), 6000, "and a hearth: the dormitory's 6000")
	assert_equal(FixturesScript.comfort_of(false, true, 1), 4250, "a hearth and a rug")
	assert_equal(FixturesScript.comfort_of(true, true, 4), 7000, "four decorations: 1000")
	assert_equal(FixturesScript.comfort_of(true, true, 5), 7000, "a fifth adds nothing past the cap")
	assert_equal([FixturesScript.comfort_word(6500), FixturesScript.comfort_word(6499), FixturesScript.comfort_word(5000),
		FixturesScript.comfort_word(4999), FixturesScript.comfort_word(3000), FixturesScript.comfort_word(2999)],
		["cozy", "snug", "snug", "plain", "plain", "bare"], "its words")


func test_a_home_s_comfort_counts_what_is_installed() -> void:
	"""Planned fixtures add nothing; the suggested layout, once in, reads 7000, cozy; three beds count as one."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	assert_equal(graph.fit.comfort(graph, r), 2000, "bare")
	graph.fit.suggest(graph, r, _stores(8, 3, 6))
	assert_equal(graph.fit.comfort(graph, r), 2000, "planned: still bare")
	for f in RoomsScript.fixture_count(HOME):
		graph.fit.phase[r * FixturesScript.PLACES + f] = INSTALLED
	assert_equal(graph.fit.comfort(graph, r), 7000, "the layout in")
	assert_equal(RoomTextScript.title(graph, r), "Burrow home %d — cozy" % (r + 1), "its heading")


# --- putting it in -----------------------------------------------------------------------------------

func test_work_puts_a_fixture_in_for_the_one_on_it() -> void:
	"""A planned bed claimed by resident 1: another may not claim it, nor work it; resident 1's work counts up to its
	20 WU and then it is in; let go midway, the work is kept, and the place kept for resident 1 until released."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	graph.fit.order(graph, r, RoomsScript.FIX_BED, _stores(2, 0, 0))
	assert_true(graph.fit.claim(graph, r, 0, 1), "claimed")
	assert_false(graph.fit.claim(graph, r, 0, 2), "not twice")
	var need := FixturesScript.install_usec(RoomsScript.FIX_BED)
	assert_false(graph.fit.work(graph, r, 0, 2, need), "another's work does not count")
	assert_false(graph.fit.work(graph, r, 0, 1, need / 2), "half done")
	graph.fit.let_go(r, 0, 1)
	assert_equal(graph.fit.asked[r * FixturesScript.PLACES], 1, "kept for resident 1")
	graph.fit.let_go(r, 0, 2)
	assert_equal(graph.fit.asked[r * FixturesScript.PLACES], 1, "another letting go changes nothing")
	graph.fit.release_keep(r * FixturesScript.PLACES)
	assert_equal(graph.fit.asked[r * FixturesScript.PLACES], -1, "released")
	assert_true(graph.fit.claim(graph, r, 0, 2), "the next takes it on")
	assert_false(graph.fit.work(graph, r, 0, 2, need / 2 - 1), "a microsecond short")
	assert_true(graph.fit.work(graph, r, 0, 2, 1), "in")
	assert_equal(graph.fit.phase_of(graph, r, 0), INSTALLED, "installed")
	assert_equal(graph.fit.worker[r * FixturesScript.PLACES], -1, "nobody on it")
	assert_false(graph.fit.claim(graph, r, 0, 3), "an installed bed is not claimed")


func test_a_room_laid_again_starts_bare() -> void:
	"""A cellar row freed and laid again is a new generation: its places start empty."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(CELLAR, Vector2i.ZERO, 0, 0, ref)
	graph.fit.phase[ref[0] * FixturesScript.PLACES] = PLANNED
	graph.fit.phase_of(graph, ref[0], 0)
	graph.fit.phase[ref[0] * FixturesScript.PLACES] = PLANNED
	graph.start_dig(ref[3], ref[4], 0)
	graph.stop_digging(ref[3], ref[4])
	var again := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(CELLAR, Vector2i.ZERO, 0, 0, again)
	assert_equal(again[0], ref[0], "the same row")
	assert_equal(graph.fit.phase_of(graph, again[0], 0), FixturesScript.EMPTY, "bare again")


func test_a_home_laid_again_forgets_its_large_bed() -> void:
	"""A home row whose place held a large bed, freed and laid again: its bed place is a burrow bed's again, asked
	first of all."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(HOME, Vector2i.ZERO, 0, 0, ref)
	graph.fit.phase_of(graph, ref[0], 0)
	graph.fit.phase[ref[0] * FixturesScript.PLACES] = PLANNED
	graph.fit.held[ref[0] * FixturesScript.PLACES] = RoomsScript.FIX_BIG_BED + 1
	assert_equal(graph.fit.kind_at(graph, ref[0], 0), RoomsScript.FIX_BIG_BED, "a large bed")
	graph.start_dig(ref[3], ref[4], 0)
	graph.stop_digging(ref[3], ref[4])
	var again := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(HOME, Vector2i.ZERO, 0, 0, again)
	assert_equal(again[0], ref[0], "the same row")
	assert_equal(graph.fit.kind_at(graph, again[0], 0), RoomsScript.FIX_BED, "a burrow bed's place again")


func test_waiting_fixtures_are_listed_in_place_order() -> void:
	"""Planned places nobody is on, in dug rooms, room by room and place by place; a claimed one is not waiting."""
	var graph := GraphScript.new()
	var a := _room(graph, HOME, Vector2i.ZERO)
	var b := _room(graph, CELLAR, Vector2i(12288, 0))
	var stores := _stores(20, 20, 20)
	graph.fit.order(graph, b, RoomsScript.FIX_BIN, stores)
	graph.fit.order(graph, a, RoomsScript.FIX_TABLE, stores)
	graph.fit.order(graph, a, RoomsScript.FIX_BED, stores)
	var out := PackedInt32Array()
	assert_equal(graph.fit.waiting_into(graph, out), 3, "three waiting")
	assert_equal(out, PackedInt32Array([a * 8 + 0, a * 8 + 4, b * 8 + 3]), "in order")
	graph.fit.claim(graph, a, 4, 0)
	assert_equal(graph.fit.waiting_into(graph, out), 2, "the claimed table is not")


# --- the drawing (fixture_view.gd) -------------------------------------------------------------------

const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Layers := preload("res://demo/demo_layers.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free the nodes a test made."""
	for node in _nodes:
		node.free()
	_nodes.clear()


func _view(graph: GraphScript, lit: Array[bool]) -> FixtureViewScript:
	"""A fixture view over `graph` with its own light pool, lit while lit[0]."""
	var lights := LanternsScript.new()
	lights.configure()
	var view := FixtureViewScript.new()
	view.configure(graph, PropsScript.new(), lights, null)
	view.set_lit(func(_r: int) -> bool: return lit[0])
	_nodes.append_array([lights, view])
	return view


func test_a_place_is_drawn_as_it_stands_and_only_when_it_changes() -> void:
	"""Empty, nothing; planned, a chalk ring; installed, the fixture -- all below; a refresh with nothing changed
	builds nothing; a room not yet dug shows nothing."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var lit: Array[bool] = [false]
	var view := _view(graph, lit)
	view.refresh(0.0)
	assert_null(view.piece(r, 0), "an empty place: nothing")
	graph.fit.order(graph, r, RoomsScript.FIX_BED, _stores(2, 0, 0))
	view.refresh(0.0)
	assert_true(view.piece(r, 0) != null and view.piece(r, 0).get_child_count() == 1, "planned: one piece")
	assert_true((view.piece(r, 0).get_child(0) as MeshInstance3D).mesh is TorusMesh, "the chalk ring")
	var built := view.builds
	view.refresh(0.0)
	assert_equal(view.builds, built, "nothing changed: nothing built")
	graph.fit.phase[r * FixturesScript.PLACES] = INSTALLED
	view.refresh(0.0)
	assert_equal(view.builds, built + 1, "installed: built once more")
	assert_equal(view.piece(r, 0).get_child(0).name, "bed", "the bed")
	for node: Node in view.piece(r, 0).find_children("*", "VisualInstance3D", true, false):
		assert_equal((node as VisualInstance3D).layers, Layers.UNDERGROUND, "%s below" % node.name)
	var laid := _room(graph, HOME, Vector2i(12288, 0), false)
	view.refresh(0.0)
	assert_false(view._below[laid].visible, "not dug: not shown")


func test_a_lit_hearth_glows_and_smokes_and_a_cold_one_does_not() -> void:
	"""A hearth in: its chimney stands on the mound; lit, its embers show, its smoke rises and one light burns over it;
	cold, none of them."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var lit: Array[bool] = [true]
	var view := _view(graph, lit)
	view.refresh(0.0)
	assert_false(view.chimney(r).visible or view.smoke(r).emitting, "no hearth: no chimney, no smoke")
	_install(graph, r, RoomsScript.FIX_HEARTH)
	view.refresh(0.0)
	assert_true(view.chimney(r).visible, "a chimney on the mound")
	assert_true(view.chimney(r).position.y > 0.5, "up on the mound")
	assert_true(view.smoke(r).emitting, "smoking")
	assert_equal(view._lights.spot_count(), 1, "one light over the fire")
	for node: Node in view.chimney(r).find_children("*", "VisualInstance3D", true, false):
		assert_equal((node as VisualInstance3D).layers, Layers.SURFACE, "%s on the ground" % node.name)
	assert_true(view._embers[r].visible, "its embers glow")
	lit[0] = false
	view.refresh(0.0)
	assert_false(view.smoke(r).emitting, "cold: no smoke")
	assert_false(view._embers[r].visible, "nor embers")
	assert_equal(view._lights.spot_count(), 0, "no light")
	_install(graph, r, RoomsScript.FIX_LANTERN)
	view.refresh(0.0)
	assert_equal(view._lights.spot_count(), 1, "a hung lantern lights, day or night")


func test_a_cellar_s_racks_fill_in_place_as_its_stock_rises() -> void:
	"""A cellar with two shelves, a rack, a bin and hanging stores has 2 + 2 + 6 + 1 + 4 = 15 slots: empty none show;
	half full, eight; full, all fifteen, the bin heaped to its top -- read from the pantry's fill."""
	var graph := GraphScript.new()
	var r := _room(graph, CELLAR, Vector2i.ZERO)
	for f in RoomsScript.fixture_count(CELLAR):
		graph.fit.phase_of(graph, r, f)
		graph.fit.phase[r * FixturesScript.PLACES + f] = INSTALLED
	var lit: Array[bool] = [false]
	var view := _view(graph, lit)
	var fill: Array[int] = [0]
	view.set_fill(func(_room_row: int) -> int: return fill[0])
	view.refresh(1.0)
	assert_equal(view.shown_slots(r), 0, "empty")
	fill[0] = 500
	view.refresh(1.0)
	assert_equal(view.shown_slots(r), 8, "half full: eight of fifteen")
	fill[0] = 1000
	view.refresh(1.0)
	assert_equal(view.shown_slots(r), 15, "full")
	var heap: Node3D = view._slots[r * FixturesScript.PLACES + 3][0]
	assert_almost_equal(heap.scale.y, 2.0, "the bin heaped to its top (0.5 m over a 0.25 m half-height)")
	fill[0] = 1
	view.refresh(0.1)
	assert_equal(view.shown_slots(r), 15, "read a few times a second, not every frame")


func test_a_passage_not_yet_dug_does_not_open_onto_a_hearth() -> void:
	"""Joined by a passage only planned, the cellar does not open onto the home's hearth."""
	var graph := GraphScript.new()
	var cellar := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, cellar, RoomsScript.FIX_SHELF)
	var home := _room(graph, HOME, Vector2i(1536 + 4096 + 2048, 0))
	_install(graph, home, RoomsScript.FIX_HEARTH)
	var plan := PlanScript.new()
	plan.try_add_snapped(1536, 0, SpecScript.END_NODE, graph.rooms.socket_of(cellar, 1), BOUNDS_U, PackedInt32Array())
	plan.try_add_snapped(1536 + 4096, 0, SpecScript.END_NODE, graph.rooms.socket_of(home, 2), BOUNDS_U, PackedInt32Array())
	assert_true(graph.add_piece(plan.spec_of(0), PackedInt32Array([-1, 0, -1])), "a passage planned")
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_YES, "not dug: cool")


func test_the_hearth_lights_in_its_own_colour() -> void:
	"""The pool gives a lit hearth's light the hearth's deep orange."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	_install(graph, r, RoomsScript.FIX_HEARTH)
	var lit: Array[bool] = [true]
	var view := _view(graph, lit)
	view.refresh(0.0)
	view._lights.update(Vector3.ZERO)
	assert_equal(view._lights.light(0).light_color, LanternsScript.HEARTH_COLOUR, "deep orange")


func test_a_cellar_id_names_its_room_and_its_rack() -> void:
	"""farm_cellars.gd: a cellar's pantry id gives back (room, generation); any other store none; a carrier faces the
	cellar's first installed storage fixture, or its middle when it has none."""
	assert_equal(FarmCellars.room_of(&"root_cellar:3:7"), Vector2i(3, 7), "the cellar's")
	assert_equal(FarmCellars.room_of(&"covered_store"), Vector2i(-1, 0), "not a cellar")
	assert_equal(FarmCellars.room_of(12), Vector2i(-1, 0), "an int id")
	var graph := GraphScript.new()
	var r := _room(graph, CELLAR, Vector2i.ZERO)
	assert_equal(FarmCellars.rack_at(graph, r), Vector2.ZERO, "none: its middle")
	_install(graph, r, RoomsScript.FIX_RACK)
	assert_equal(FarmCellars.rack_at(graph, r), Vector2(Rules.to_m(1000), Rules.to_m(-1300)), "its rack")


func test_the_last_planned_is_taken_out_first() -> void:
	"""Three beds planned: taking one out empties the third place, then the second."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(6, 0, 0)
	for k in 3:
		graph.fit.order(graph, r, RoomsScript.FIX_BED, stores)
	graph.fit.take_out(graph, r, RoomsScript.FIX_BED, stores)
	assert_equal([graph.fit.phase_of(graph, r, 0), graph.fit.phase_of(graph, r, 1), graph.fit.phase_of(graph, r, 2)],
		[PLANNED, PLANNED, FixturesScript.EMPTY], "the third went")
	graph.fit.take_out(graph, r, RoomsScript.FIX_BED, stores)
	assert_equal(graph.fit.phase_of(graph, r, 1), FixturesScript.EMPTY, "then the second")


func test_a_rack_only_planned_is_no_store_and_keeps_nothing_cool() -> void:
	"""A cellar whose only rack is planned counts no storage fixture: it is no store, and not cool (no rack)."""
	var graph := GraphScript.new()
	var r := _room(graph, CELLAR, Vector2i.ZERO)
	graph.fit.order(graph, r, RoomsScript.FIX_RACK, _stores(2, 0, 0))
	assert_equal(graph.fit.storage_count(graph, r), 0, "none installed")
	assert_equal(graph.fit.cool(graph, r), FixturesScript.COOL_NO_RACK, "no rack yet")


func test_a_cellar_does_not_open_onto_a_hearth_through_another_room() -> void:
	"""Cellar -- 1 m -- a home without a hearth, across it (4 m) -- 1 m -- a home with one: 6 m of walking, but through a
	room, so the cellar does not open onto the hearth (their voids are far over 3 m apart)."""
	var graph := GraphScript.new()
	var cellar := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, cellar, RoomsScript.FIX_SHELF)
	var between := _room(graph, HOME, Vector2i(1536 + 1024 + 2048, 0))
	var hearth := _room(graph, HOME, Vector2i(1536 + 1024 + 4096 + 1024 + 2048, 0))
	_install(graph, hearth, RoomsScript.FIX_HEARTH)
	_pass(graph, graph.rooms.socket_of(cellar, 1), 1536, graph.rooms.socket_of(between, 2), 1536 + 1024)
	_pass(graph, graph.rooms.socket_of(between, 0), 1536 + 1024 + 4096, graph.rooms.socket_of(hearth, 2), 1536 + 2048 + 4096)
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_YES, "through a room: cool")


func _pass(graph: GraphScript, from: int, from_x: int, to: int, to_x: int) -> void:
	"""A straight passage along z = 0 from socket node `from` (at from_x) to socket node `to` (at to_x), dug."""
	var plan := PlanScript.new()
	plan.try_add_snapped(from_x, 0, SpecScript.END_NODE, from, BOUNDS_U, PackedInt32Array())
	plan.try_add_snapped(to_x, 0, SpecScript.END_NODE, to, BOUNDS_U, PackedInt32Array())
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(0), piece), "a passage laid")
	_dig(graph, piece[2])


func test_a_hearth_on_another_level_does_not_warm_a_cellar() -> void:
	"""A home with a hearth right beside a cellar in plan but on another level (P6's second) leaves it cool."""
	var graph := GraphScript.new()
	var cellar := _room(graph, CELLAR, Vector2i.ZERO)
	_install(graph, cellar, RoomsScript.FIX_RACK)
	var home := _room(graph, HOME, Vector2i(3941 + 1024, 0))
	_install(graph, home, RoomsScript.FIX_HEARTH)
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_HEARTH_NEAR, "on its level: warm")
	graph.rooms.level[home] = 2
	assert_equal(graph.fit.cool(graph, cellar), FixturesScript.COOL_YES, "on the level below: cool")


func test_the_smoke_follows_the_clock() -> void:
	"""Paused, the smoke stands still (speed 0); at 4x it rises four times as fast."""
	var graph := GraphScript.new()
	_room(graph, HOME, Vector2i.ZERO)
	var clock := DemoClockScript.new()
	var lights := LanternsScript.new()
	lights.configure()
	var view := FixtureViewScript.new()
	view.configure(graph, PropsScript.new(), lights, clock)
	_nodes.append_array([lights, view])
	clock.speed = 0
	view.refresh(0.0)
	assert_almost_equal(view.smoke(0).speed_scale, 0.0, "paused")
	clock.speed = 4
	view.refresh(0.0)
	assert_almost_equal(view.smoke(0).speed_scale, 4.0, "4x")


func test_the_housing_count_is_the_beds_put_in() -> void:
	"""A dug home with one bed in and one planned counts one bed; with none, none."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	assert_equal(graph.rooms.beds(graph), 0, "bare")
	_install(graph, r, RoomsScript.FIX_BED)
	graph.fit.order(graph, r, RoomsScript.FIX_BED, _stores(2, 0, 0))
	assert_equal(graph.rooms.beds(graph), 1, "one in")


func test_a_hearth_taken_out_gives_its_stone_back() -> void:
	"""Six stone back into the stores."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(0, 0, 6)
	graph.fit.order(graph, r, RoomsScript.FIX_HEARTH, stores)
	assert_equal(stores.stone_milli_u, 0, "paid")
	graph.fit.take_out(graph, r, RoomsScript.FIX_HEARTH, stores)
	assert_equal(_held(stores), Vector3i(0, 0, 6000), "given back")


func test_a_malformed_cellar_id_names_no_room() -> void:
	"""Another store's id with two parts, or a cellar id with one, is no cellar."""
	assert_equal(FarmCellars.room_of(&"barn:2"), Vector2i(-1, 0), "not a cellar's")
	assert_equal(FarmCellars.room_of(&"root_cellar:3"), Vector2i(-1, 0), "one part")


func test_the_palette_says_what_is_in_coming_and_can_be_done() -> void:
	"""A home with one bed in and one coming: its bed row says so, may add (a place is empty) and take; a hearth row
	with none may add, not take; every place taken, the layout's button says so until all are in."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	_install(graph, r, RoomsScript.FIX_BED)
	graph.fit.order(graph, r, RoomsScript.FIX_BED, _stores(2, 0, 0))
	var rows := RoomTextScript.palette_rows(graph, r)
	assert_equal(rows[0]["text"], "Bed: 1 of 3 in, 1 coming · 2 planks", "the bed row")
	assert_equal([rows[0]["add"], rows[0]["take"]], [true, true], "add and take")
	assert_equal([rows[1]["text"], rows[1]["add"], rows[1]["take"]], ["Large bed: 0 of 3 in · 4 planks", true, false],
		"the large bed row: the same alcoves")
	assert_equal([rows[2]["text"], rows[2]["add"], rows[2]["take"]], ["Hearth: 0 of 1 in · 6 stone", true, false], "the hearth row")
	graph.fit.suggest(graph, r, _stores(20, 20, 20))
	rows = RoomTextScript.palette_rows(graph, r)
	assert_false(rows[0]["add"], "every bed place taken")
	assert_equal(RoomTextScript.suggest_text(graph, r), "Everything ordered: being put in", "all ordered")
	for f in RoomsScript.fixture_count(HOME):
		graph.fit.phase[r * FixturesScript.PLACES + f] = INSTALLED
	assert_equal(RoomTextScript.suggest_text(graph, r), "Fitted out", "all in")


# --- large beds (decision 0211) -----------------------------------------------------------------------

const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const BIG_BED: int = RoomsScript.FIX_BIG_BED


func _nook_axis_u(graph: GraphScript, r: int, f: int, reach_u: int) -> Vector2i:
	"""The point `reach_u` out from room `r`'s middle along place `f`'s axis (world u)."""
	return graph.rooms.to_world_u(r, RoomsScript.along_place_u(graph.rooms.template[r], f, reach_u))


func test_a_large_bed_digs_its_alcove_into_a_nook_and_costs_four_planks() -> void:
	"""The first large bed goes in the back alcove (place 0), its nook dug, 4 planks paid; the second by the door
	(place 2); a third is refused -- its alcoves taken, in words -- and costs nothing; a burrow bed still takes the
	alcove between; a cellar takes none."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var cellar := _room(graph, CELLAR, Vector2i(0, 12288))
	var stores := _stores(12, 0, 0)
	assert_equal(graph.fit.order(graph, r, BIG_BED, stores), FixturesScript.REFUSE_NONE, "the first")
	assert_equal([graph.fit.kind_at(graph, r, 0), graph.fit.phase_of(graph, r, 0)], [BIG_BED, PLANNED], "in the back alcove")
	assert_true(graph.rooms.has_nook(r, 0) and not graph.rooms.has_nook(r, 2), "its nook dug, only its")
	assert_equal(_held(stores), Vector3i(8000, 0, 0), "4 planks")
	assert_equal(graph.fit.order(graph, r, BIG_BED, stores), FixturesScript.REFUSE_NONE, "the second")
	assert_equal(graph.fit.kind_at(graph, r, 2), BIG_BED, "by the door")
	var code := graph.fit.order(graph, r, BIG_BED, stores)
	assert_equal(code, FixturesScript.REFUSE_NO_NOOK, "a third: no alcove left for a nook")
	assert_equal(graph.fit.nook_refused, FixturesScript.NOOK_TAKEN, "they are taken")
	assert_equal(RoomTextScript.answer(graph, r, PackedStringArray(["fit", "add", str(BIG_BED)]), code, stores, Callable()),
		"Can't: Burrow home %d has no alcove where a large bed's nook can be dug: the alcoves a nook can open from (the back and by the door) are taken" % (r + 1),
		"in words")
	assert_equal(_held(stores), Vector3i(4000, 0, 0), "the third paid nothing")
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "a burrow bed")
	assert_equal(graph.fit.kind_at(graph, r, 1), RoomsScript.FIX_BED, "in the alcove between")
	assert_equal(graph.fit.order(graph, cellar, BIG_BED, stores), FixturesScript.REFUSE_NOT_HERE, "not in a cellar")


func test_a_nook_is_refused_where_it_may_not_go() -> void:
	"""Place 0's nook, refused past the village's edge, under water or under a building; everywhere so, the large bed
	is refused with the first reason and costs nothing. A nook already dug is always fine."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var site := RoomsScript.Site.new()
	graph.fit.nook_site = site
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_OK, "open ground: fine")
	site.bounds_u = Rect2i(-4096, -4096, 8192, 8192)
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_OUT_OF_BOUNDS, "past the edge")
	site.bounds_u = Rect2i(-65536, -65536, 131072, 131072)
	var tip := _nook_axis_u(graph, r, 0, RoomsScript.NOOK_B_U)
	site.under_u = PackedInt32Array([tip.x, 512, tip.y])
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_UNDER_BUILDING, "under a building")
	assert_equal(graph.fit.nook_reason(graph, r, 2), RoomsScript.NOOK_OK, "the other alcove is clear of it")
	site.under_u = PackedInt32Array()
	site.water = func(_a: Vector2i, _b: Vector2i, _reach: int) -> bool: return true
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_UNDER_WATER, "under the water")
	var stores := _stores(4, 0, 0)
	var code := graph.fit.order(graph, r, BIG_BED, stores)
	assert_equal([code, graph.fit.nook_refused], [FixturesScript.REFUSE_NO_NOOK, RoomsScript.NOOK_UNDER_WATER], "refused, why")
	assert_true(RoomTextScript.answer(graph, r, PackedStringArray(["fit", "add", str(BIG_BED)]), code, stores, Callable())
		.ends_with(RoomsScript.NOOK_REASONS[RoomsScript.NOOK_UNDER_WATER]), "said")
	assert_equal(_held(stores), Vector3i(4000, 0, 0), "nothing paid")
	graph.rooms.dig_nook(r, 0)
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_OK, "dug: fine")


func test_a_refused_large_bed_names_its_first_alcove_s_reason() -> void:
	"""The back alcove refused under a building, the door's past the village's edge: the words give the first."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var site := RoomsScript.Site.new()
	graph.fit.nook_site = site
	var tip := _nook_axis_u(graph, r, 0, RoomsScript.NOOK_B_U)
	site.under_u = PackedInt32Array([tip.x, 512, tip.y])
	site.bounds_u = Rect2i(-4096, -4096, 70000, 70000)
	assert_equal(graph.fit.nook_reason(graph, r, 2), RoomsScript.NOOK_OUT_OF_BOUNDS, "the door's alcove: past the edge")
	assert_equal(graph.fit.order(graph, r, BIG_BED, _stores(4, 0, 0)), FixturesScript.REFUSE_NO_NOOK, "refused")
	assert_equal(graph.fit.nook_refused, RoomsScript.NOOK_UNDER_BUILDING, "the back alcove's reason")


func test_a_home_with_a_large_bed_is_not_suggested_another() -> void:
	"""A large bed planned: the layout fills the other alcoves with burrow beds."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	graph.fit.order(graph, r, BIG_BED, _stores(4, 0, 0))
	var layout := PackedInt32Array()
	graph.fit.layout_into(graph, r, layout)
	assert_equal([layout[0], layout[1], layout[2]], [-1, RoomsScript.FIX_BED, RoomsScript.FIX_BED], "burrow beds in the rest")


func test_a_place_emptied_of_a_large_bed_is_a_burrow_bed_s_again() -> void:
	"""A large bed taken out and a burrow bed put in its place: it is a burrow bed, listed small, in its place."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(4, 0, 0)
	graph.fit.order(graph, r, BIG_BED, stores)
	graph.fit.take_out(graph, r, BIG_BED, stores)
	_install(graph, r, RoomsScript.FIX_BED)
	assert_equal(graph.fit.kind_at(graph, r, 0), RoomsScript.FIX_BED, "a burrow bed")
	var out := PackedInt32Array()
	graph.fit.beds_into(graph, out)
	assert_equal(out[3], AllocationScript.SIZE_SMALL, "listed small")


func test_a_tunnel_by_the_back_alcove_sends_the_large_bed_by_the_door() -> void:
	"""A tunnel passing a pillar's reach from where place 0's nook would go refuses it; the large bed goes by the door."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(PackedInt32Array([5120, -16384, 5120, 16384]), 2, 0, ref), "a tunnel east of the home")
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_NEAR_TUNNEL, "near the back alcove")
	assert_equal(graph.fit.nook_reason(graph, r, 2), RoomsScript.NOOK_OK, "not the door's")
	assert_equal(graph.fit.order(graph, r, BIG_BED, _stores(4, 0, 0)), FixturesScript.REFUSE_NONE, "placed")
	assert_equal(graph.fit.kind_at(graph, r, 2), BIG_BED, "by the door")
	assert_equal(graph.fit.kind_at(graph, r, 0), RoomsScript.FIX_BED, "the back alcove still a burrow bed's")


func test_another_room_by_the_alcove_refuses_its_nook() -> void:
	"""A second home laid clear of the first but within a pillar of where place 0's nook would go -- its ramp leading
	away, north -- refuses it as a room."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i(5632, 5632), 2, 0, ref), "the second home laid")
	var near := ref[0]
	assert_true(graph.rooms.leg_gap_of(near, _nook_axis_u(graph, r, 0, RoomsScript.NOOK_A_U),
		_nook_axis_u(graph, r, 0, RoomsScript.NOOK_B_U)) < Rules.PILLAR_U + RoomsScript.NOOK_HALF_U, "within a pillar")
	assert_equal(graph.fit.nook_reason(graph, r, 0), RoomsScript.NOOK_NEAR_ROOM, "refused")


func test_a_nook_is_part_of_its_room_s_void() -> void:
	"""Dug, a nook brings the room's void out along its alcove: a point past the alcove is nearer the void, for the
	pillar every other dig keeps."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var past := _nook_axis_u(graph, r, 0, RoomsScript.NOOK_B_U + RoomsScript.NOOK_HALF_U + 1024)
	var before := graph.rooms.gap_of(r, past)
	graph.rooms.dig_nook(r, 0)
	var after := graph.rooms.gap_of(r, past)
	assert_true(after < before, "nearer (%d, was %d)" % [after, before])
	assert_true(absi(after - 1024) <= 1, "a metre past the capsule's end (%d)" % after)
	assert_true(graph.rooms.leg_gap_of(r, past, past + Vector2i(0, 1)) <= after, "a leg there too")


func test_a_large_bed_taken_out_gives_its_planks_back_and_its_nook_stays() -> void:
	"""Taken out, 4 planks back; the place a burrow bed's again; the nook dug stays."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	var stores := _stores(4, 0, 0)
	graph.fit.order(graph, r, BIG_BED, stores)
	assert_equal(graph.fit.take_out(graph, r, BIG_BED, stores), FixturesScript.REFUSE_NONE, "taken out")
	assert_equal(_held(stores), Vector3i(4000, 0, 0), "4 planks back")
	assert_equal([graph.fit.phase_of(graph, r, 0), graph.fit.kind_at(graph, r, 0)], [FixturesScript.EMPTY, RoomsScript.FIX_BED],
		"empty, a burrow bed's place")
	assert_true(graph.rooms.has_nook(r, 0), "the nook stays")


func test_a_large_bed_is_a_big_bed_lying_out_in_its_nook() -> void:
	"""Installed, a large bed is listed SIZE_BIG with its middle out along its alcove's axis at LARGE_BED_MIDDLE_U, a
	burrow bed SIZE_SMALL at its place; both count as beds, for the housing and the comfort."""
	var graph := GraphScript.new()
	var r := _room(graph, HOME, Vector2i.ZERO)
	graph.fit.order(graph, r, BIG_BED, _stores(4, 0, 0))
	graph.fit.phase[r * FixturesScript.PLACES] = INSTALLED
	_install(graph, r, RoomsScript.FIX_BED)
	var out := PackedInt32Array()
	assert_equal(graph.fit.beds_into(graph, out), 2, "two beds")
	var middle := _nook_axis_u(graph, r, 0, RoomsScript.LARGE_BED_MIDDLE_U)
	var place := graph.rooms.to_world_u(r, FixturesScript.place_u(HOME, 1))
	assert_equal(out, PackedInt32Array([r * FixturesScript.PLACES, middle.x, middle.y, AllocationScript.SIZE_BIG,
		r * FixturesScript.PLACES + 1, place.x, place.y, AllocationScript.SIZE_SMALL]), "sized, placed")
	assert_equal(graph.fit.bed_middle_u(graph, r, 0), middle, "out in its nook")
	assert_equal(graph.fit.installed_beds(graph), 2, "housing")
	assert_equal(graph.fit.comfort(graph, r), FixturesScript.FLOOR_COMFORT + FixturesScript.BED_COMFORT, "a bed's comfort")
