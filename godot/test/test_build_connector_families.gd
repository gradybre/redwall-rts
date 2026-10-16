extends "res://test/framework/test_case.gd"
## The connector families' placeholder shapes and bills (decision 2021; Brendan's ruling P-D1-2 (a), "Use the table,
## marked"): every number recomputed from the sources the table names, the quanta counted a second, independent way,
## the cells for each turn, and decision 1880's "at least 2 × 2 cells" for every family.

const Families := preload("res://scripts/ui/build_connector_families.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")

const ALL: Array[int] = [0, 1, 2, 3, 4]


func test_the_runs_derive_from_their_sources() -> void:
	"""The ramp 1:2.5 plus its eased ends (decision 0212, RAMP_FILLET_U 896); the stair decision 2041's F40 (its top
	landing, 38 more treads of 512 u, the run-out); the stone stair 20 of decision 0212's 256 u risers on 320 u treads;
	one level's 5120 u drop (SET-BUILD-001 §3)."""
	assert_equal(Families.DROP_U, 5120, "one level")
	assert_equal(Families.RUN_U[Families.RAMP] * 2, Families.DROP_U * 5 + 2 * 896, "the ramp's run")
	assert_equal(Families.RUN_U[Families.EARTH_TIMBER], 2560 + 512 * 38 + 1536, "F40: the sill's far edge and run-out")
	assert_equal(Families.STAIR_ROW_DEPTHS.size(), Families.ALONG[Families.EARTH_TIMBER], "one depth a row")
	assert_equal(Families.RUN_U[Families.STONE] * 256, Families.DROP_U * 320, "20 risers on 320 u treads")
	assert_equal(Families.HEADROOM_U, 3 * Families.QUANTUM_U, "the badger's 2611 u in whole quanta")
	assert_true(Families.HEADROOM_U >= 2611 and Families.HEADROOM_U - Families.QUANTUM_U < 2611, "the least that fits")
	for family: int in [Families.EARTH_TIMBER, Families.STONE, Families.RAMP]:
		assert_equal(Families.ALONG[family], Families.ceil_div(Families.RUN_U[family], Families.QUANTUM_U),
			"%s: whole cells along its run" % Families.name_of(family))


func test_the_quanta_are_the_counted_cubes() -> void:
	"""`count_quanta` agrees with the table, and with a brute-force cube-by-cube count; a vertical family cuts its own
	cells all the way down: one quantum between the levels and the landing's 4096 u clear height."""
	for family: int in [Families.STONE, Families.RAMP]:
		var per_width: int = Families.count_quanta(Families.RUN_U[family], Families.HEADROOM_U, Families.DROP_U)
		assert_equal(per_width * Families.ACROSS[family], Families.QUANTA[family], "%s: the table" % Families.name_of(family))
		assert_equal(per_width, _brute_quanta(Families.RUN_U[family]), "%s: counted cube by cube" % Families.name_of(family))
	for family: int in [Families.SPIRAL, Families.LADDER_HATCH]:
		assert_equal(Families.QUANTA[family], Families.ACROSS[family] * Families.ALONG[family] * 5,
			"%s: 1 + 4 quanta a cell" % Families.name_of(family))
	assert_equal(Families.count_quanta(13696, 4096, 5120) * 2, 90, "the ramp at 4 quanta of headroom (decision 2021)")
	var depths: int = 0
	for depth: int in Families.STAIR_ROW_DEPTHS:
		depths += depth
	assert_equal(depths, 71, "decision 2041 §2.4: 71 cubes a column")
	assert_equal(Families.QUANTA[Families.EARTH_TIMBER], 2 * depths, "F40's 142 cubes")


func _brute_quanta(run_u: int) -> int:
	"""Every cube (column c, row q) whose open interior meets the void, tested with integers scaled by the run."""
	var drop: int = Families.DROP_U
	var q_u: int = Families.QUANTUM_U
	var total: int = 0
	for column: int in Families.ceil_div(run_u, q_u):
		var near: int = column * q_u
		var far: int = mini(near + q_u, run_u)
		var lowest: int = -drop * far
		var highest: int = mini(0, Families.HEADROOM_U * run_u - drop * near)
		for row: int in range(-12, 1):
			if row * q_u * run_u < highest and (row + 1) * q_u * run_u > lowest:
				total += 1
	return total


func test_the_cells_on_each_level_derive_from_the_void() -> void:
	"""A column is standing (open to its level) where the void reaches its level's floor, and lower where it reaches the
	clear height below the one quantum between the levels."""
	for family: int in [Families.STONE, Families.RAMP]:
		var run: int = Families.RUN_U[family]
		var open: int = 0
		var low_from: int = -1
		for column: int in Families.ALONG[family]:
			var near: int = column * Families.QUANTUM_U
			var far: int = mini(near + Families.QUANTUM_U, run)
			if Families.HEADROOM_U * run - Families.DROP_U * near >= 0:
				open += 1
			if low_from < 0 and Families.DROP_U * far > Families.QUANTUM_U * run:
				low_from = column
		assert_equal(Families.TOP_OPEN[family], open, "%s: standing columns" % Families.name_of(family))
		assert_equal(Families.LOW_FROM[family], low_from, "%s: first lower column" % Families.name_of(family))


func test_the_stairs_cells_follow_its_row_depths() -> void:
	"""Decision 2041 §2.4: every row an open slot to the land (all 23 standing); a row reaches level 1's clear height
	once it is 2 cubes deep."""
	assert_equal(Families.TOP_OPEN[Families.EARTH_TIMBER], Families.STAIR_ROW_DEPTHS.size(), "all open to the land")
	assert_equal(Families.LOW_FROM[Families.EARTH_TIMBER], Families.STAIR_ROW_DEPTHS.find(2), "below from row 5")
	assert_equal(Families.box(Families.EARTH_TIMBER, 0, Vector2i(0, 0)), Rect2i(0, 0, 2, 23), "2 × 23 (P-DF-2 (a))")


func test_the_stair_head_turns_only_to_zero() -> void:
	"""Decision 2041 P-DF-6 (a): rotation 0 only, for the Stair-head; the others turn freely."""
	assert_equal(Families.turn_refusal(Families.EARTH_TIMBER, 0), "", "turn 0")
	for turn: int in [1, 2, 3, 4 + 1]:
		assert_equal(Families.turn_refusal(Families.EARTH_TIMBER, turn), "No qualified stair for this direction yet",
			"turn %d" % turn)
	assert_equal(Families.turn_refusal(Families.EARTH_TIMBER, 4), "", "four turns are none")
	assert_equal(Families.turn_refusal(Families.RAMP, 1) + Families.turn_refusal(Families.LADDER_HATCH, 3), "", "others")


func test_every_family_is_at_least_two_by_two() -> void:
	"""Decision 1880's [NEW constraint]: the item bound holds while every item covers at least 2 × 2 cells."""
	for family: int in ALL:
		assert_true(Families.ACROSS[family] >= 2 and Families.TOP_OPEN[family] >= 2,
			"%s stands on at least 2 × 2" % Families.name_of(family))


func test_the_fixture_bills_are_l0_and_treads() -> void:
	"""ADR 1202's L0, T0 at its own bill and ADR 1209 D3's tread at DEC-059's work: the hatch L0 + 5 treads, the stair
	L0 + T0 + 38 treads (decision 2041 §2.5), the ramp none; stone and spiral not proposed."""
	assert_equal(Families.fixture_wood(Families.LADDER_HATCH), 9000, "hatch wood")
	assert_equal(Families.fixture_work(Families.LADDER_HATCH), 60200, "hatch work")
	assert_equal(Families.fixture_wood(Families.EARTH_TIMBER), 43000, "stair wood (2041 §2.5)")
	assert_equal(Families.fixture_work(Families.EARTH_TIMBER), 258320, "stair work (2041 §2.5)")
	var stair: PackedInt64Array = PackedInt64Array()
	Families.bill_into(Families.EARTH_TIMBER, stair)
	assert_equal(stair, PackedInt64Array([78500, 35500, 858980, 284000]), "F40's whole bill, 2041 §2.5")
	assert_equal(Families.fixture_wood(Families.RAMP) + Families.fixture_work(Families.RAMP), 0, "the ramp: none")
	assert_false(Families.fixtures_priced(Families.STONE) or Families.fixtures_priced(Families.SPIRAL), "not proposed")
	assert_equal(Families.fixture_wood(Families.STONE), 0, "nothing shown")
	assert_equal(Families.fixture_work(-1), 0, "no family")
	assert_equal(Families.FIXTURE_TREADS[Families.LADDER_HATCH] * Families.QUANTUM_U, Families.DROP_U, "one per metre")


func test_the_bill_is_the_quanta_at_the_contracts_prices_plus_fittings() -> void:
	"""`bill_into` adds the quanta through build_ledger.gd and the fittings' wood and work."""
	var tally: PackedInt64Array = PackedInt64Array()
	Families.bill_into(Families.LADDER_HATCH, tally)
	assert_equal(tally, PackedInt64Array([20 * 250 + 9000, 20 * 250, 20 * 4230 + 60200, 20 * 2000]), "the hatch")
	var quanta: PackedInt64Array = PackedInt64Array()
	Ledger.add_quanta_into(84, quanta)
	tally.fill(0)
	Families.bill_into(Families.RAMP, tally)
	assert_equal(tally, quanta, "the ramp: its quanta only")
	Families.bill_into(-1, tally)
	assert_equal(tally, quanta, "no family adds nothing")


func test_a_hatch_is_the_proof_of_concepts_two_by_two() -> void:
	"""Turned or not, a hatch takes the 2 × 2 at its anchor on both levels and lands on all of it; no run."""
	for turn: int in 4:
		var cells: PackedInt32Array = Families.standing_cells(Families.LADDER_HATCH, turn, Vector2i(3, 4))
		assert_equal(cells, PackedInt32Array([3, 4, 4, 4, 3, 5, 4, 5]), "turn %d: canonical 2 × 2" % turn)
		assert_equal(Families.lower_cells(Families.LADDER_HATCH, turn, Vector2i(3, 4)), cells, "the same below")
		assert_equal(Families.landing_cells(Families.LADDER_HATCH, turn, Vector2i(3, 4)), cells, "lands on all")
	assert_true(Families.run_cells(Families.LADDER_HATCH, 0, Vector2i(3, 4)).is_empty(), "no run")


func test_a_ramp_descends_north_at_turn_zero_and_turns_clockwise() -> void:
	"""Turn 0: its top at the south end, its foot north; turn 1 descends east; the box swaps for odd turns."""
	var anchor: Vector2i = Vector2i(10, 20)
	assert_equal(Families.box(Families.RAMP, 0, anchor), Rect2i(anchor, Vector2i(2, 14)), "turn 0's box")
	assert_equal(Families.box(Families.RAMP, 1, anchor), Rect2i(anchor, Vector2i(14, 2)), "turn 1's box")
	assert_equal(Families.cell_at(Families.RAMP, 0, anchor, 0, 0), Vector2i(10, 33), "turn 0: top at the south")
	assert_equal(Families.cell_at(Families.RAMP, 0, anchor, 13, 0), Vector2i(10, 20), "foot at the north")
	assert_equal(Families.cell_at(Families.RAMP, 1, anchor, 0, 0), Vector2i(10, 20), "turn 1: top at the west")
	assert_equal(Families.cell_at(Families.RAMP, 1, anchor, 13, 1), Vector2i(23, 21), "turn 1: foot at the east")
	assert_equal(Families.cell_at(Families.RAMP, 2, anchor, 13, 0), Vector2i(11, 33), "turn 2: foot at the south")
	assert_equal(Families.cell_at(Families.RAMP, 3, anchor, 13, 1), Vector2i(10, 20), "turn 3: foot at the west")
	assert_equal(Families.cell_at(Families.RAMP, 2, anchor, 0, 1), Vector2i(10, 20), "turn 2: top at the north")
	assert_equal(Families.cell_at(Families.RAMP, 3, anchor, 0, 0), Vector2i(23, 21), "turn 3: top at the east")
	for turn: int in 4:
		assert_equal(Families.descent(turn), Families.DESCENT[turn], "descent %d" % turn)
	assert_equal(Families.descent(-1), Vector2i(-1, 0), "turns wrap")


func test_a_ramps_cells_on_each_level_its_landing_and_run() -> void:
	"""9 rows standing, 12 below, the last row its landing, the 11 before it its run; access pairs at each end."""
	var anchor: Vector2i = Vector2i(10, 20)
	var standing: PackedInt32Array = Families.standing_cells(Families.RAMP, 0, anchor)
	assert_equal(standing.size(), 2 * 2 * 9, "2 × 9 standing")
	assert_equal(Vector2i(standing[0], standing[1]), Vector2i(10, 25), "from row z 25 (the top 9 rows)")
	assert_equal(Families.lower_cells(Families.RAMP, 0, anchor).size(), 2 * 2 * 12, "2 × 12 below")
	assert_equal(Families.landing_cells(Families.RAMP, 0, anchor), PackedInt32Array([10, 20, 11, 20]), "the foot row")
	assert_equal(Families.run_cells(Families.RAMP, 0, anchor).size(), 2 * 2 * 11, "the run")
	assert_equal(Families.access_pair(Families.RAMP, 0, anchor, false), PackedInt32Array([10, 34, 11, 34]), "top pair")
	assert_equal(Families.access_pair(Families.RAMP, 0, anchor, true), PackedInt32Array([10, 19, 11, 19]), "foot pair")
	assert_equal(Families.access_pair(Families.SPIRAL, 0, anchor, false), PackedInt32Array([11, 24, 12, 24]),
		"a 4-wide family's pair is centred")
	assert_true(Families.access_pair(-1, 0, anchor, false).is_empty() and Families.standing_cells(9, 0, anchor).is_empty(),
		"no family, no cells")


func test_top_and_foot_corners_and_the_walkers_pairing() -> void:
	"""Where it is drawn and walked: the top 2 × 2 and the foot 2 × 2; a top cell leads to the landing cell the same way
	across (a hatch: the same cell)."""
	var anchor: Vector2i = Vector2i(10, 20)
	assert_equal(Families.top_corner(Families.RAMP, 0, anchor), Vector2i(10, 32), "top 2 × 2")
	assert_equal(Families.foot_corner(Families.RAMP, 0, anchor), Vector2i(10, 20), "foot 2 × 2")
	assert_equal(Families.top_corner(Families.LADDER_HATCH, 2, anchor), anchor, "a hatch's own")
	assert_equal(Families.paired_landing(Families.RAMP, 0, anchor, Vector2i(11, 32)), Vector2i(11, 20), "across 1")
	assert_equal(Families.paired_landing(Families.RAMP, 0, anchor, Vector2i(10, 33)), Vector2i(10, 20), "row 0 too")
	assert_equal(Families.paired_landing(Families.LADDER_HATCH, 1, anchor, Vector2i(11, 21)), Vector2i(11, 21), "same")
	assert_equal(Families.paired_landing(Families.RAMP, 0, anchor, Vector2i(10, 26)), Vector2i(10, 26), "not a top cell")
	assert_equal(Families.paired_landing(-1, 0, anchor, Vector2i(1, 1)), Vector2i(1, 1), "no family")


func test_names_offers_and_the_card_words() -> void:
	"""P-D1-1 (a): three offered, two locked; P-D1-12 (a)'s words."""
	assert_equal(Families.CARD_ORDER, [Families.RAMP, Families.LADDER_HATCH, Families.EARTH_TIMBER, Families.STONE,
		Families.SPIRAL], "the cards' order")
	assert_true(Families.offered(Families.RAMP) and Families.offered(Families.LADDER_HATCH)
		and Families.offered(Families.EARTH_TIMBER), "three offered")
	assert_false(Families.offered(Families.STONE) or Families.offered(Families.SPIRAL) or Families.offered(5), "locked")
	assert_equal(Families.name_of(Families.RAMP), "Burrow mouth", "the ramp's name")
	assert_equal(Families.name_of(-1), "", "none")
	assert_true(Families.sloped(Families.RAMP) and not Families.sloped(Families.LADDER_HATCH), "sloped or not")
	assert_equal(Families.PLACEHOLDER, "Placeholder: sizes and costs await review", "P-D1-12")
	assert_equal(Families.CLIMBERS_ONLY, "Climbers only: loads need a stair or ramp", "P-D1-12")
