extends "res://test/framework/test_case.gd"
## UI-BUILD-005's arithmetic: a painted underground cell costs SET-BUILD-001 §7.2's figures (quoted here, BAL-ROOM-001)
## read from the excavation contract, the words are natural measures (DEC-049), and the ledger never touches a store.
## Decision 1871.

const Ledger := preload("res://scripts/ui/build_ledger.gd")

## SET-BUILD-001 §7.2 / BAL-ROOM-001, quoted: per underground cell at clear height 4096 u.
const CELL_WOOD: int = 1000
const CELL_STONE: int = 1000
const CELL_WORK: int = 16920
const CELL_EARTH: int = 8000

var _tally: PackedInt64Array = PackedInt64Array()


func test_one_cell_costs_the_adopted_figures() -> void:
	"""4 quanta at 4096 u: wood 1000, stone 1000, work 16920 milli-WU, earth 8000 milli-U."""
	assert_equal(Ledger.quanta_per_cell(Ledger.DEFAULT_CLEAR_HEIGHT_U), 4, "four quanta a cell")
	Ledger.per_cell_into(Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(_tally.size(), Ledger.SLOTS, "sized")
	assert_equal(int(_tally[Ledger.WOOD]), CELL_WOOD, "wood")
	assert_equal(int(_tally[Ledger.STONE]), CELL_STONE, "stone")
	assert_equal(int(_tally[Ledger.WORK]), CELL_WORK, "work")
	assert_equal(int(_tally[Ledger.EARTH]), CELL_EARTH, "earth out")


func test_a_two_by_two_passage_patch_is_sixteen_quanta() -> void:
	"""§7.2: a 2 × 2 patch is wood 4000, stone 4000, 67680 milli-WU and earth 32000."""
	Ledger.totals_into(4, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(_tally, PackedInt64Array([4000, 4000, 67680, 32000]), "the patch")


func test_totals_scale_by_cells_and_never_go_negative() -> void:
	"""Boundaries: no cells, a negative count, and a clear height under one quantum."""
	Ledger.totals_into(0, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(_tally, PackedInt64Array([0, 0, 0, 0]), "no cells")
	Ledger.totals_into(-3, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(_tally, PackedInt64Array([0, 0, 0, 0]), "a negative count is none")
	assert_equal(Ledger.quanta_per_cell(1023), 1, "a part quantum is still cut: rounded up (a need)")
	assert_equal(Ledger.quanta_per_cell(4097), 5, "just over four: five")
	assert_equal(Ledger.quanta_per_cell(0), 0, "no height, no quanta")
	assert_equal(Ledger.quanta_per_cell(5120), 5, "a taller level")
	assert_equal(Ledger.quanta_per_cell(-1024), 0, "a negative height")
	Ledger.totals_into(24, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(int(_tally[Ledger.WORK]), 24 * CELL_WORK, "24 cells")


func test_totals_into_reuses_its_array() -> void:
	"""Once sized, a tally is written in place: no allocation per call."""
	Ledger.totals_into(1, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	var before: PackedInt64Array = _tally
	Ledger.totals_into(2, Ledger.DEFAULT_CLEAR_HEIGHT_U, _tally)
	assert_equal(_tally.size(), Ledger.SLOTS, "still four slots")
	assert_equal(int(_tally[Ledger.WOOD]), 2 * CELL_WOOD, "rewritten")
	assert_true(before.size() == Ledger.SLOTS, "the same shape")


func test_work_reads_as_time_rounded_up() -> void:
	"""WU is a game minute: minutes under an hour, tenths of hours after, never understated."""
	assert_equal(Ledger.work_text(0), "about 0 minutes", "no work")
	assert_equal(Ledger.work_text(1), "about 1 minute", "a sliver is a minute")
	assert_equal(Ledger.work_text(CELL_WORK), "about 17 minutes", "one cell: 16.92 minutes up to 17")
	assert_equal(Ledger.work_text(59000), "about 59 minutes", "just under the hour")
	assert_equal(Ledger.work_text(60000), "about 1.0 hours", "the hour")
	assert_equal(Ledger.work_text(60001), "about 1.1 hours", "past the hour rounds up a tenth")
	assert_equal(Ledger.work_text(24 * CELL_WORK), "about 6.8 hours", "24 cells: 6.768 h up to 6.8")
	assert_equal(Ledger.work_text(-5), "about 0 minutes", "negative work is none")


func test_the_summary_puts_needs_beside_what_the_stores_hold() -> void:
	"""“Plan needs …; work …; earth out …; stores hold …” in natural measures."""
	var words: String = Ledger.summary(24, Ledger.DEFAULT_CLEAR_HEIGHT_U, 40000, 20000, _tally)
	assert_true(words.begins_with("Plan needs 24 logs"), words)
	assert_true(words.contains("24 blocks"), "stone in blocks: %s" % words)
	assert_true(words.contains("work about 6.8 hours"), "work: %s" % words)
	assert_true(words.contains("earth out 96 baskets"), "earth: %s" % words)
	assert_true(words.contains("stores hold 40 logs"), "stock: %s" % words)
	assert_true(words.contains("20 blocks"), "stone stock: %s" % words)
	var empty: String = Ledger.summary(0, Ledger.DEFAULT_CLEAR_HEIGHT_U, 40000, 20000, _tally)
	assert_true(empty.begins_with(Ledger.NOTHING_YET), "an empty batch needs nothing: %s" % empty)
	assert_true(empty.contains("stores hold"), "and still shows the stores")


func test_a_ledger_line_names_the_type_and_its_cells() -> void:
	"""“Kitchen (+24 cells)”."""
	assert_equal(Ledger.line("Kitchen", 24), "Kitchen (+24 cells)", "the doc's example")
	assert_equal(Ledger.line("Dormitory", 1), "Dormitory (+1 cells)", "the format is fixed")


func test_cost_and_stock_words_round_needs_up_and_stock_down() -> void:
	"""A need of 1.5 logs reads 2; a stock of 1.5 logs reads 1."""
	var tally: PackedInt64Array = PackedInt64Array([1500, 1000, 1000, 2000])
	assert_true(Ledger.cost_words(tally).begins_with("2 logs"), Ledger.cost_words(tally))
	assert_true(Ledger.stock_words(1500, 0).contains("a log"), Ledger.stock_words(1500, 0))


func test_a_tally_adds_cells_at_each_levels_own_height() -> void:
	"""add_into sums levels at their own clear heights; summary_of words the sum."""
	var tally: PackedInt64Array = PackedInt64Array()
	Ledger.add_into(2, 4096, tally)
	Ledger.add_into(1, 5120, tally)
	assert_equal(int(tally[Ledger.WOOD]), 2 * 1000 + 1250, "8 + 5 quanta of brace wood")
	assert_equal(int(tally[Ledger.EARTH]), 13 * 2000, "13 quanta of earth")
	assert_true(Ledger.summary_of(tally, true, 0, 0).begins_with("Plan needs 4 logs"), Ledger.summary_of(tally, true, 0, 0))
	assert_true(Ledger.summary_of(tally, false, 0, 0).begins_with(Ledger.NOTHING_YET), "nothing")
