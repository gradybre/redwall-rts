extends "res://test/framework/test_case.gd"
## UI-BUILD-001 "Validity in words": every result is a glyph and a word, and every canonical reason reads exactly as
## docs/ui_ux_controls.md's table (quoted here independently of build_validity.gd), with the table's glyph
## (UX-BUILD-T03). Decision 1871.

const Validity := preload("res://scripts/ui/build_validity.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")

## [reason text as the table writes it, its glyph], one row per canonical reason, built with the same arguments.
const TABLE: Array = [
	["Too narrow: rooms need at least 2 × 2 cells", "X"],
	["Too small: Kitchen needs at least 24 cells (has 20)", "!"],
	["Needs 1 hearth", "!"],
	["No way in: connect to a finished Passage or entrance", "!"],
	["Overlaps Kitchen: remove these cells first; a room's purpose cannot change", "X"],
	["Cannot dig here: water", "X"],
	["Too steep: slope over 8°", "X"],
	["Uneven ground: over 0.5 m height difference", "X"],
	["Wrong room: Bed belongs in Dormitory or Bedroom", "X"],
	["Needs a wall behind it", "X"],
	["Access blocked: keep one access tile free", "!"],
	["Locked: needs Milestone 1", "!"],
	["No level above the surface", "X"],
	["No level below level 4", "X"],
	["Would cut off Kitchen: build another way in first", "X"],
]


func _built() -> PackedStringArray:
	"""Each canonical builder with the TABLE's arguments, in the table's order."""
	return PackedStringArray([Validity.too_narrow(), Validity.too_small("Kitchen", 24, 20), Validity.needs("1 hearth"),
		Validity.no_way_in(), Validity.overlaps("Kitchen"), Validity.cannot_dig("water"), Validity.too_steep(),
		Validity.uneven(), Validity.wrong_room("Bed", "Dormitory or Bedroom"), Validity.needs_wall(),
		Validity.access_blocked(), Validity.locked("Milestone 1"), Validity.no_level_above(), Validity.no_level_below(),
		Validity.cut_off("Kitchen")])


func test_every_canonical_reason_reads_as_the_table_writes_it() -> void:
	"""The fifteen reasons, word for word."""
	var built: PackedStringArray = _built()
	assert_equal(built.size(), TABLE.size(), "one builder per table row")
	for at: int in TABLE.size():
		assert_equal(built[at], String(TABLE[at][0]), "row %d" % at)


func test_every_canonical_reason_carries_the_tables_glyph() -> void:
	"""REASON_KINDS for ids 1..15 are the table's glyph column."""
	for at: int in TABLE.size():
		var kind: int = Validity.kind_of(at + 1)
		assert_equal(Validity.glyph(kind), String(TABLE[at][1]), "reason %d's glyph" % (at + 1))


func test_a_line_is_glyph_word_and_reason() -> void:
	"""✓ Can build; ! Blocked: reason; X Not possible: reason -- never colour alone."""
	assert_equal(Validity.line(Validity.KIND_CAN_BUILD, ""), "✓ Can build", "can build")
	assert_equal(Validity.line(Validity.KIND_CAN_BUILD, "ignored"), "✓ Can build", "a reason never follows ✓")
	assert_equal(Validity.line(Validity.KIND_BLOCKED, Validity.no_way_in()),
		"! Blocked: No way in: connect to a finished Passage or entrance", "blocked")
	assert_equal(Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.too_narrow()),
		"X Not possible: Too narrow: rooms need at least 2 × 2 cells", "not possible")
	assert_equal(Validity.line(Validity.KIND_BLOCKED, ""), "! Blocked", "a kind with no reason still says its word")
	assert_equal(Validity.line(7, "x"), "", "an unknown kind says nothing rather than guessing")


func test_each_kind_has_its_own_glyph_word_and_token() -> void:
	"""GOLD, WARNING and DANGER (§2.1), and three different glyphs and words."""
	assert_equal(Validity.token(Validity.KIND_CAN_BUILD), UiTheme.TOKEN_GOLD, "✓ is GOLD")
	assert_equal(Validity.token(Validity.KIND_BLOCKED), UiTheme.TOKEN_WARNING, "! is WARNING")
	assert_equal(Validity.token(Validity.KIND_NOT_POSSIBLE), UiTheme.TOKEN_DANGER, "X is DANGER")
	assert_equal(Validity.token(-1), UiTheme.TOKEN_MUTED, "an unknown kind is muted")
	assert_equal(Validity.word(Validity.KIND_BLOCKED), "Blocked", "word")
	assert_equal(Validity.glyph(3), "", "no glyph past the kinds")
	assert_equal(Validity.word(-1), "", "no word before them")
	assert_true(Validity.is_kind(0) and Validity.is_kind(2) and not Validity.is_kind(3), "three kinds")


func test_the_proposed_reasons_carry_their_recorded_glyphs() -> void:
	"""Decision 1871's proposals: outside and joining two are X; a shape refusal, not-yet and a route refusal are !."""
	assert_equal(Validity.kind_of(Validity.REASON_OUTSIDE), Validity.KIND_NOT_POSSIBLE, "outside: X")
	assert_equal(Validity.kind_of(Validity.REASON_JOINS_TWO), Validity.KIND_NOT_POSSIBLE, "joins two: X")
	assert_equal(Validity.kind_of(Validity.REASON_SHAPE), Validity.KIND_BLOCKED, "shape: !")
	assert_equal(Validity.kind_of(Validity.REASON_NOT_YET), Validity.KIND_BLOCKED, "not yet: !")
	assert_equal(Validity.kind_of(Validity.REASON_REFUSED), Validity.KIND_BLOCKED, "route refusal: !")
	assert_equal(Validity.kind_of(Validity.REASON_NONE), Validity.KIND_CAN_BUILD, "none: ✓")
	assert_equal(Validity.kind_of(Validity.REASON_COUNT), Validity.KIND_CAN_BUILD, "past the table: ✓, never a guess")
	assert_equal(Validity.kind_of(-1), Validity.KIND_CAN_BUILD, "before the table")
	assert_equal(Validity.REASON_KINDS.size(), Validity.REASON_COUNT, "one glyph per reason id")
	assert_equal(Validity.outside(), "Outside the planning area: keep the whole room inside it", "outside")
	assert_equal(Validity.shape("join them"), "Shape: join them", "shape")
	assert_equal(Validity.joins_two(), "Joins two planned rooms: undo one of them first", "joins two")
	assert_equal(Validity.not_yet("furnishing comes in a later update"),
		"Not yet: furnishing comes in a later update", "not yet")


func test_nothing_to_add_is_a_dropped_stroke() -> void:
	"""Decision 1871's proposal for a stroke wholly inside its own room: X, in words."""
	assert_equal(Validity.kind_of(Validity.REASON_NOTHING_NEW), Validity.KIND_NOT_POSSIBLE, "X")
	assert_equal(Validity.nothing_new(), "Nothing to add: these cells are already planned for this room", "words")
