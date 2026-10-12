extends "res://test/framework/test_case.gd"
## The one pending batch (BUILD-REQ-019/020/021, UI-BUILD-006..009): strokes, the batch-wide Undo/Redo and its
## 32-step limit, Discard all, validity in words per operation, the ledger's reads, Confirm all through a host route,
## and UX-BUILD-T04: none of it touches a store, a reservation or a job. Decision 1871.

const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")

const KITCHEN: int = 2
const DORMITORY: int = 0
const PANTRY: int = 6
const BOUNDS: Rect2i = Rect2i(0, 0, 128, 128)
const CAPACITY: int = 4096

var _batch: Batch = null
var _submitted: Array = []
var _answers: Array = []


func before_each() -> void:
	"""A configured batch over a 128 × 128-cell area."""
	_batch = Batch.new()
	assert_equal(_batch.configure(BuildCatalog.new(), BOUNDS, CAPACITY), &"", "configured")
	_submitted.clear()
	_answers.clear()


func _paint(room_type: int, level: int, from: Vector2i, to: Vector2i) -> int:
	"""One rectangle stroke, released; its validity kind."""
	assert_true(_batch.begin_stroke(room_type, level, from), "stroke begins")
	_batch.extend_stroke(to)
	return _batch.finish_stroke()


func _submit(draft: Draft, level: int, room_type: int) -> Variant:
	"""A host route: records what it was given and answers from `_answers` (ok when empty)."""
	@warning_ignore("integer_division") var cells: int = draft.snapshot().cells.size() / 2
	_submitted.append([cells, level, room_type])
	return _answers.pop_front() if not _answers.is_empty() else {"ok": true, "error": ""}


func test_the_planners_draft_accepts_the_one_metre_grid() -> void:
	"""Pitch 1024 u divides the 2 m furnishing grid (ADR 1055); 768 does not and is refused."""
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(KITCHEN, 1, Batch.PITCH_U, CAPACITY, BOUNDS, false), &"", "1024 accepted")
	assert_equal(Draft.new().configure(KITCHEN, 1, 768, CAPACITY, BOUNDS, false), &"INVALID_PLANNING_GRID", "768 refused")
	assert_equal(Batch.new().configure(BuildCatalog.new(), Rect2i(0, 0, 0, 0), CAPACITY), &"INVALID_PLANNING_BOUNDS",
		"an empty area is refused as the planner refuses it")
	assert_equal(Batch.new().configure(null, BOUNDS, CAPACITY), Batch.REFUSE_NOT_CONFIGURED, "no catalog")


func test_an_empty_batch_has_nothing_to_undo_redo_or_confirm() -> void:
	"""The boundary: no operations, the disabled words, and Confirm all does nothing."""
	assert_equal(_batch.pending_count(), 0, "no changes")
	assert_false(_batch.can_undo() or _batch.can_redo(), "nothing in the history")
	assert_equal(_batch.undo_label(), "Nothing to undo", "Undo's disabled words")
	assert_equal(_batch.redo_label(), "Nothing to redo", "Redo's disabled words")
	assert_false(_batch.undo() or _batch.redo(), "both do nothing")
	assert_equal(_batch.first_invalid(), -1, "nothing invalid")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "nothing ordered")
	assert_equal(_submitted.size(), 0, "the route was never called")
	assert_equal(_batch.discard_all(), 0, "nothing discarded")


func test_a_stroke_shows_its_size_and_validity_in_words() -> void:
	"""UI-BUILD-010: "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build" (24 cells: the Kitchen's least)."""
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(2, 2)), "begun")
	_batch.extend_stroke(Vector2i(7, 5))
	assert_equal(_batch.stroke_size(), Vector2i(6, 4), "6 × 4")
	assert_equal(_batch.stroke_line(), "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build", "the ghost's words")
	assert_equal(_batch.stroke_cells().size(), 48, "24 cells drawn")
	_batch.extend_stroke(Vector2i(5, 5))
	assert_equal(_batch.stroke_line(),
		"Paint Kitchen 4 × 4 cells (4 m × 4 m); ! Blocked: Too small: Kitchen needs at least 24 cells (has 16)", "too small")
	_batch.extend_stroke(Vector2i(9, 2))
	assert_equal(_batch.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "one cell deep")
	assert_equal(_batch.stroke_reason(), Validity.too_narrow(), "too narrow")
	assert_equal(Batch.size_text(Vector2i(17, 6)), "17 × 6 cells (17 m × 6 m)", "SET-BUILD-001 §3's example")


func test_a_stroke_past_the_planning_area_is_not_possible_and_never_clipped() -> void:
	"""The planner refuses an out-of-area stroke whole; it shows X and joins nothing."""
	assert_equal(_paint(KITCHEN, 1, Vector2i(124, 124), Vector2i(130, 127)), Validity.KIND_NOT_POSSIBLE, "outside")
	assert_equal(_batch.pending_count(), 0, "nothing joined")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.outside()), "said why")


func test_strokes_join_the_room_they_touch_and_start_a_new_one_apart() -> void:
	"""BUILD-REQ-004: same type, same level, touching -> one operation; apart -> two; another level -> another."""
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(3, 2)), Validity.KIND_CAN_BUILD, "12 cells")
	assert_equal(_paint(DORMITORY, 1, Vector2i(4, 0), Vector2i(5, 2)), Validity.KIND_CAN_BUILD, "shares an edge")
	assert_equal(_batch.pending_count(), 1, "one room")
	assert_equal(_batch.operation_cell_count(0), 18, "18 cells")
	assert_equal(_paint(DORMITORY, 1, Vector2i(10, 10), Vector2i(13, 12)), Validity.KIND_CAN_BUILD, "apart")
	assert_equal(_paint(DORMITORY, 2, Vector2i(0, 0), Vector2i(3, 2)), Validity.KIND_CAN_BUILD, "on level 2")
	assert_equal(_batch.pending_count(), 3, "three rooms")
	assert_equal(_batch.operation_level(2), 2, "the third is on level 2")


func test_a_stroke_over_another_room_type_is_not_possible() -> void:
	"""BUILD-REQ-005, in the table's words."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	assert_equal(_paint(PANTRY, 1, Vector2i(4, 2), Vector2i(8, 6)), Validity.KIND_NOT_POSSIBLE, "overlap")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.overlaps("Kitchen")), "words")
	assert_equal(_paint(PANTRY, 1, Vector2i(6, 0), Vector2i(9, 3)), Validity.KIND_CAN_BUILD, "beside it is fine")
	assert_equal(_paint(PANTRY, 2, Vector2i(0, 0), Vector2i(3, 3)), Validity.KIND_CAN_BUILD, "under it, a level down")


func test_a_stroke_joining_two_planned_rooms_is_refused() -> void:
	"""The batch never merges two operations (a PROPOSAL in decision 1871)."""
	_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(3, 2))
	_paint(DORMITORY, 1, Vector2i(6, 0), Vector2i(9, 2))
	assert_equal(_paint(DORMITORY, 1, Vector2i(4, 0), Vector2i(5, 2)), Validity.KIND_NOT_POSSIBLE, "a bridge")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.joins_two()), "words")
	assert_equal(_batch.pending_count(), 2, "both kept apart")


func test_too_small_operations_stay_but_block_confirm_all_naming_the_first() -> void:
	"""BUILD-REQ-021: a "!" operation stays in the batch; Confirm all names it and orders nothing."""
	assert_equal(_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(3, 3)), Validity.KIND_BLOCKED, "16 of 24")
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(11, 1))
	assert_equal(_batch.pending_count(), 2, "both kept")
	assert_equal(_batch.first_invalid(), 0, "the Kitchen first")
	assert_equal(_batch.invalid_count(), 2, "and the 4-cell Pantry")
	assert_equal(_batch.operation_line(0), "Kitchen (+16 cells): ! Blocked: Too small: Kitchen needs at least 24 cells (has 16)",
		"the operation in words")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "nothing ordered while invalid")
	assert_equal(_submitted.size(), 0, "the route is not called")
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(3, 5))
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "grown to 24")
	assert_equal(_batch.first_invalid(), 1, "the Pantry now")


func test_undo_and_redo_step_through_the_batch() -> void:
	"""One batch-wide history: undo the last stroke, whichever room it painted; redo it; a new stroke clears Redo."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(5, 5))
	assert_equal(_batch.undo_label(), "Undo Paint Kitchen", "the last step")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.operation_cell_count(0), 24, "the Kitchen's second stroke undone")
	assert_equal(_batch.redo_label(), "Redo Paint Kitchen", "redo names it")
	assert_true(_batch.undo(), "undone again")
	assert_equal(_batch.pending_count(), 1, "the Pantry undone: one change left")
	assert_true(_batch.redo(), "redone")
	assert_equal(_batch.pending_count(), 2, "the Pantry is back")
	_paint(DORMITORY, 1, Vector2i(30, 30), Vector2i(33, 32))
	assert_false(_batch.can_redo(), "a new stroke clears Redo")
	assert_equal(_batch.redo_label(), "Nothing to redo", "and says so")


func test_undo_first_drops_the_stroke_in_progress() -> void:
	"""UI §5 tool_undo: "Undo the current stroke, else the last pending build operation"."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.begin_stroke(KITCHEN, 1, Vector2i(0, 4))
	assert_equal(_batch.undo_label(), "Undo the stroke in progress", "the stroke first")
	assert_false(_batch.can_redo(), "no redo during a stroke")
	assert_true(_batch.undo(), "the stroke dropped")
	assert_false(_batch.stroke_active(), "no stroke")
	assert_equal(_batch.pending_count(), 1, "the Kitchen stays")
	assert_true(_batch.undo(), "then the Kitchen")
	assert_equal(_batch.pending_count(), 0, "empty")


func test_the_history_keeps_at_most_32_steps() -> void:
	"""ADR 1055's limit, batch-wide: 33 strokes keep 32 undo steps; undoing all 32 leaves the first stroke."""
	for k: int in 33:
		_paint(DORMITORY, 1, Vector2i(0, 2 * k), Vector2i(5, 2 * k + 1))
	assert_equal(_batch.history_size(), Batch.HISTORY_LIMIT, "32 steps")
	var undone: int = 0
	while _batch.undo():
		undone += 1
	assert_equal(undone, Batch.HISTORY_LIMIT, "32 undos")
	assert_equal(_batch.pending_count(), 1, "the first stroke is past the limit and stays")
	assert_equal(_batch.operation_cell_count(0), 12, "as it was painted")
	for k: int in Batch.HISTORY_LIMIT:
		assert_true(_batch.redo(), "redo %d" % k)
	assert_false(_batch.redo(), "and no more")
	assert_equal(_batch.operation_cell_count(0), 33 * 12, "every stroke back")


func test_discard_all_drops_everything_and_says_how_many() -> void:
	"""UI-BUILD-009: the pending changes and the history go; nothing else does."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 2, Vector2i(0, 0), Vector2i(3, 3))
	assert_equal(_batch.discard_all(), 2, "two dropped")
	assert_equal(_batch.pending_count(), 0, "none left")
	assert_equal(_batch.operation_count(), 0, "no operations")
	assert_false(_batch.can_undo(), "no history")


func test_the_ledger_reads_cells_per_type_in_order() -> void:
	"""One line per room type, in order of first appearance, summed over levels."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_paint(KITCHEN, 2, Vector2i(0, 0), Vector2i(5, 3))
	var types: PackedInt32Array = PackedInt32Array()
	var cells: PackedInt32Array = PackedInt32Array()
	_batch.type_cells_into(types, cells)
	assert_equal(types, PackedInt32Array([KITCHEN, PANTRY]), "Kitchen then Pantry")
	assert_equal(cells, PackedInt32Array([48, 16]), "two Kitchens' cells together")
	assert_equal(_batch.total_cells(), 64, "64 cells")


func test_confirm_all_orders_valid_operations_and_keeps_a_refused_one_with_its_reason() -> void:
	"""BUILD-REQ-019: each operation through the route in order; ordered ones leave and Undo cannot reach them."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_answers = [{"ok": true, "error": ""}, {"ok": false, "error": "Connect a completed passage first."}]
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([1, 1]), "one ordered, one refused")
	assert_equal(_submitted, [[24, 1, KITCHEN], [16, 1, PANTRY]], "in batch order, with level and type")
	assert_equal(_batch.pending_count(), 1, "the Pantry stays")
	assert_equal(_batch.operation_type(0), PANTRY, "and only it")
	assert_equal(_batch.operation_reason(0), "Connect a completed passage first.", "with the route's words")
	assert_equal(_batch.operation_kind(0), Validity.KIND_BLOCKED, "as ! Blocked")
	assert_true(_batch.undo(), "undo reaches the Pantry")
	assert_false(_batch.undo(), "but never the ordered Kitchen")


func test_a_kept_refusal_clears_when_the_operation_changes() -> void:
	"""The route's reason holds until the player repaints the room."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(3, 3))
	_answers = [{"ok": false, "error": ""}]
	_batch.confirm_all(_submit)
	assert_equal(_batch.operation_reason(0), Batch.UNCHECKED, "a wordless refusal still says something")
	_paint(PANTRY, 1, Vector2i(4, 0), Vector2i(5, 3))
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "repainted: judged again")
	_answers = ["not a dictionary"]
	_batch.confirm_all(_submit)
	assert_equal(_batch.operation_reason(0), Batch.UNCHECKED, "a malformed answer is a refusal")


func test_two_by_two_is_build_req_002() -> void:
	"""Every cell inside some 2 × 2 block: an L of 2-wide arms passes, a 1-wide tail fails."""
	assert_true(Batch.two_by_two(PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])), "a 2 × 2 block")
	assert_false(Batch.two_by_two(PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 1, 1])), "a 1-wide tail")
	assert_true(Batch.two_by_two(PackedInt32Array()), "nothing to fail")


func test_the_batch_holds_no_owner_reference() -> void:
	"""UX-BUILD-T04's structural half: the batch references no Node and no owner at all (the actual owners' bytes,
	reservations and jobs are checked unchanged across painting, Undo, Discard and Confirm all in
	test_demo_build_orders.gd)."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.undo()
	_batch.redo()
	_batch.discard_all()
	for property: Dictionary in _batch.get_property_list():
		var value: Variant = _batch.get(property.name)
		assert_false(value is Node, "%s is no Node" % property.name)


func test_shape_words_are_the_planners_in_plain_words() -> void:
	"""Every code modular_draft.gd returns has words; an unknown one still says something."""
	for code: StringName in Batch.SHAPE_WORDS:
		assert_false(Batch.shape_words(code).is_empty(), String(code))
	assert_false(Batch.shape_words(&"SOMETHING_NEW").is_empty(), "unknown")


func test_one_cell_wide_either_way_is_too_narrow() -> void:
	"""BUILD-REQ-002 in both axes: 1 × 6 and 6 × 1 are not possible; 2 × 6 is."""
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(0, 5)), Validity.KIND_NOT_POSSIBLE, "one wide in x")
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(5, 0)), Validity.KIND_NOT_POSSIBLE, "one deep in z")
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(1, 5)), Validity.KIND_CAN_BUILD, "two wide")


func test_a_stroke_over_its_own_room_counts_the_union_once() -> void:
	"""Growing a Pantry of 8 cells with a 12-cell stroke over those 8: 12 cells, still under the 16 it needs."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(1, 3))
	assert_true(_batch.begin_stroke(PANTRY, 1, Vector2i(0, 0)), "begun")
	_batch.extend_stroke(Vector2i(2, 3))
	assert_equal(_batch.stroke_reason(), Validity.too_small("Pantry", 16, 12), "the union, not the sum")
	assert_equal(_batch.finish_stroke(), Validity.KIND_BLOCKED, "kept, blocked")
	assert_equal(_batch.operation_cell_count(0), 12, "one room of 12 cells")


func test_a_stroke_inside_its_own_room_adds_nothing_and_no_undo_step() -> void:
	"""Review H1: Kitchen 6×4, Dormitory 6×6, a 3×2 Kitchen stroke inside the Kitchen: dropped, words, no step; the
	first Undo then removes the Dormitory, never the Kitchen."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(DORMITORY, 1, Vector2i(10, 0), Vector2i(15, 5))
	var steps: int = _batch.history_size()
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(1, 1)), "begun")
	_batch.extend_stroke(Vector2i(3, 2))
	assert_equal(_batch.stroke_reason(), Validity.nothing_new(), "nothing to add, before release")
	assert_equal(_batch.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "never ✓")
	assert_equal(_batch.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.nothing_new()), "said why")
	assert_equal(_batch.history_size(), steps, "no phantom step")
	assert_true(_batch.undo(), "Undo")
	assert_equal(_batch.operation_cell_count(0), 24, "the Kitchen is untouched")
	assert_equal(_batch.pending_count(), 1, "the Dormitory went")


func test_a_room_past_the_capacity_is_not_possible_and_records_nothing() -> void:
	"""Review H1: a stroke whose room would pass a room's most cells is X before release and joins nothing."""
	var small: Batch = Batch.new()
	assert_equal(small.configure(BuildCatalog.new(), BOUNDS, 40), &"", "a 40-cell capacity")
	small.begin_stroke(KITCHEN, 1, Vector2i(0, 0))
	small.extend_stroke(Vector2i(5, 3))
	assert_equal(small.finish_stroke(), Validity.KIND_CAN_BUILD, "24 cells")
	small.begin_stroke(KITCHEN, 1, Vector2i(0, 4))
	small.extend_stroke(Vector2i(5, 7))
	assert_equal(small.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "48 > 40")
	assert_equal(small.stroke_reason(), Validity.shape(Batch.shape_words(&"FOOTPRINT_CAPACITY")), "in words")
	assert_equal(small.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(small.history_size(), 1, "one step only")
	assert_equal(small.operation_cell_count(0), 24, "unchanged")
	small.begin_stroke(KITCHEN, 1, Vector2i(20, 20))
	small.extend_stroke(Vector2i(27, 25))
	assert_equal(small.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "a new room past it too")


func test_redo_never_names_a_confirmed_room() -> void:
	"""Review M2 / BUILD-REQ-020: undone, then confirmed, a room leaves Redo too."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(5, 5))
	_batch.undo()
	assert_true(_batch.can_redo(), "a redo step on the Kitchen")
	_batch.confirm_all(_submit)
	assert_false(_batch.can_redo(), "the confirmed Kitchen is out of Redo's reach")
	assert_equal(_batch.redo_label(), "Nothing to redo", "and Redo says so")


func test_a_ring_with_a_hole_is_blocked_while_drawn_and_after() -> void:
	"""Review M2: four rectangles round a gap make FOOTPRINT_HOLES_NOT_ALLOWED -- never ✓."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(5, 1))
	_paint(PANTRY, 1, Vector2i(0, 2), Vector2i(1, 5))
	_paint(PANTRY, 1, Vector2i(4, 2), Vector2i(5, 5))
	assert_true(_batch.begin_stroke(PANTRY, 1, Vector2i(2, 4)), "the closing stroke")
	_batch.extend_stroke(Vector2i(3, 5))
	assert_equal(_batch.stroke_kind(), Validity.KIND_BLOCKED, "never ✓ while drawn")
	assert_equal(_batch.stroke_reason(), Validity.shape(Batch.shape_words(&"FOOTPRINT_HOLES_NOT_ALLOWED")), "a hole, in words")
	assert_equal(_batch.finish_stroke(), Validity.KIND_BLOCKED, "kept, blocked")
	assert_equal(_batch.operation_kind(0), Validity.KIND_BLOCKED, "the ring is blocked")
	assert_equal(_batch.operation_reason(0), Validity.shape(Batch.shape_words(&"FOOTPRINT_HOLES_NOT_ALLOWED")), "in words")
	assert_equal(_batch.first_invalid(), 0, "and holds Confirm all back")


func test_confirm_all_and_redo_wait_for_the_stroke_in_progress() -> void:
	"""Review M2: no order and no redo while a stroke is drawn."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_batch.undo()
	assert_equal(_batch.pending_count(), 1, "the Kitchen pending, the Pantry undone")
	_batch.begin_stroke(PANTRY, 1, Vector2i(20, 20))
	assert_false(_batch.redo(), "no redo mid-stroke")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "no order mid-stroke")
	assert_equal(_submitted.size(), 0, "the route untouched")


func test_a_route_refusal_is_retried_and_never_holds_confirm_all_back() -> void:
	"""Review H3 (the coordinator's resolution): a "!" route refusal stays in words, is retried by the next Confirm
	all and does not disable it; an "X" one holds it back."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_answers = [{"ok": false, "error": "No way in", "kind": Validity.KIND_BLOCKED},
		{"ok": false, "error": "Cannot dig here: water", "kind": Validity.KIND_NOT_POSSIBLE}]
	_batch.confirm_all(_submit)
	assert_true(_batch.retryable(0), "the Kitchen is retried")
	assert_equal(_batch.operation_line(0), "Kitchen (+24 cells): ! Blocked: No way in", "in words")
	assert_equal(_batch.first_refused(), 0, "the first refused")
	assert_equal(_batch.operation_kind(1), Validity.KIND_NOT_POSSIBLE, "the Pantry: X")
	assert_equal(_batch.first_invalid(), 1, "only the X holds Confirm all back")
	_batch.undo()
	assert_equal(_batch.first_invalid(), -1, "the Pantry undone: nothing holds it back")
	_submitted.clear()
	_answers = [{"ok": true, "error": ""}]
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([1, 0]), "retried and ordered")
	assert_equal(_submitted.size(), 1, "the Kitchen went again")


func test_a_refusal_goes_stale_once_its_room_changes() -> void:
	"""Review H3: a refused room that changes is judged afresh; "too small" again holds Confirm all back, never
	retried as the old refusal."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(3, 3))
	_paint(KITCHEN, 1, Vector2i(4, 0), Vector2i(5, 3))
	_answers = [{"ok": false, "error": "No way in", "kind": Validity.KIND_BLOCKED}]
	_batch.confirm_all(_submit)
	assert_true(_batch.retryable(0), "refused: retried")
	assert_true(_batch.undo(), "the second stroke undone: 16 cells")
	assert_false(_batch.retryable(0), "the old refusal no longer stands")
	assert_equal(_batch.first_invalid(), 0, "too small holds Confirm all back")
	assert_equal(_batch.first_refused(), -1, "nothing to retry")


func test_cells_the_draft_already_holds_are_nothing_to_add() -> void:
	"""Review H1: a stroke over cells the room's draft already holds -- even cells added underneath the batch -- is
	judged against the draft itself and dropped as "Nothing to add", with no Undo step."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	var draft: Draft = _batch.operation_draft(0)
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(6, 0), 0, false)
	draft.extend_stroke(Vector2i(7, 3))
	assert_equal(draft.finish_stroke(), &"", "the draft grown underneath")
	var steps: int = _batch.history_size()
	assert_equal(_paint(KITCHEN, 1, Vector2i(6, 0), Vector2i(7, 3)), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.nothing_new()), "in words")
	assert_equal(_batch.history_size(), steps, "no Undo step")


func test_a_stroke_the_draft_refuses_is_dropped_with_its_words() -> void:
	"""Review H1: the planner's own refusal on finish (here its capacity, smaller than the batch was told) drops the
	stroke as "X" with the planner's words, and records nothing."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch._capacity = CAPACITY * 4
	var steps: int = _batch.history_size()
	assert_equal(_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(127, 127)), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_true(_batch.last_dropped().begins_with("X Not possible: Shape: "), _batch.last_dropped())
	assert_equal(_batch.history_size(), steps, "no Undo step")
	assert_equal(_batch.operation_cell_count(0), 24, "the room unchanged")
