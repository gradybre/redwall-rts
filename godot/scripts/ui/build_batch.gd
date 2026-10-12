extends RefCounted
## The build panel's ONE PENDING BATCH (DEC-061 Q1; SET-BUILD-001 BUILD-REQ-020/021; ARCH-BUILD-001 "Pending batch"):
## ordered paint operations on any level, one batch-wide Undo/Redo, Discard all, a validity per operation in words,
## and what the ledger reads. PRESENTATION-SIDE: never saved, never authoritative, and it holds no reference to any
## store, reservation, job or project -- painting, undoing and discarding cannot touch them (UX-BUILD-T04).
##
## BUILT ON THE PLANNER'S DRAFT (Brendan's ruling 2 of 2026-10-12; ADRs 1052 and 1055). Each operation IS a
## `modular_draft.gd` session -- one room type on one level, its cells on the 1 m grid (pitch 1024 u: the draft
## accepts it, 2048 % 1024 == 0) -- so its shape rules, canonical cells and own snapshot undo are the planner's.
## A rectangle stroke is previewed on a scratch draft; on release it is replayed onto the operation it touches (the
## same type on the same level, overlapping or sharing an edge: BUILD-REQ-004's "grow by repainting"), or onto a new
## operation. The batch's Undo/Redo is a stack of operation indices (at most HISTORY_LIMIT = 32, ADR 1055): undo pops
## one and undoes that operation's draft. An emptied operation stays in place (its history may be redone) and is not
## pending; it is dropped once nothing can reach it.
##
## WHAT A STROKE MAY NOT DO (it is dropped on release, "X", with its reason): be narrower than 2 cells
## (BUILD-REQ-002), leave the planning area (PROPOSAL), overlap a planned room of another type (BUILD-REQ-005), or join
## two planned rooms of its own type (PROPOSAL). What makes an operation "!" Blocked -- kept, but holding Confirm all
## back -- is a fixable shape refusal of the planner's, being under SET-BUILD-001 §4's least size, or the reason the
## planner's order route last refused it with (until it changes).

const Draft := preload("res://demo/burrow/modular_draft.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")

## SET-BUILD-001 §3: one cell is 1 m, 1024 u.
const PITCH_U: int = 1024
## ADR 1055: the planner keeps at most 32 complete edits.
const HISTORY_LIMIT: int = Draft.HISTORY_LIMIT
const REFUSE_NOT_CONFIGURED: StringName = &"BUILD_BATCH_NOT_CONFIGURED"
const SIZE_FORMAT: String = "%d × %d cells (%d m × %d m)"
const PAINT_FORMAT: String = "Paint %s %s; %s"
const NOTHING_TO_UNDO: String = "Nothing to undo"
const NOTHING_TO_REDO: String = "Nothing to redo"
## A refusal that came back without words.
const UNCHECKED: String = "the order could not be checked; review it and try again"
const SHAPE_WORDS: Dictionary = {
	&"FOOTPRINT_DISCONNECTED": "join the painted areas into one room",
	&"FOOTPRINT_PINCHED_BOUNDARY": "widen the corner where two edges touch",
	&"FOOTPRINT_HOLES_NOT_ALLOWED": "fill the enclosed gap or open it to the outside",
	&"FOOTPRINT_CAPACITY": "too large for one room; paint a smaller part",
	&"DRAWING_STROKE_TOO_LONG": "too large for one room; paint a smaller part",
}

## Bumped by every change to the operations, the history or a refusal; readers redraw when it moves.
var revision: int = 0
## Bumped whenever the stroke in progress (or its absence) changes.
var stroke_revision: int = 0

var _catalog: BuildCatalog = null
var _bounds: Rect2i = Rect2i()
var _capacity: int = 0
var _drafts: Array[Draft] = []
var _types: PackedInt32Array = PackedInt32Array()
var _levels: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _refusals: PackedStringArray = PackedStringArray()
var _refused_at: PackedInt32Array = PackedInt32Array()
var _judged_at: PackedInt32Array = PackedInt32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _reasons: PackedStringArray = PackedStringArray()
var _undo: PackedInt32Array = PackedInt32Array()
var _redo: PackedInt32Array = PackedInt32Array()
var _stroke: Draft = null
var _stroke_type: int = -1
var _stroke_level: int = 0
var _stroke_start: Vector2i = Vector2i.ZERO
var _stroke_end: Vector2i = Vector2i.ZERO
var _stroke_kind: int = Validity.KIND_CAN_BUILD
var _stroke_reason: String = ""
var _stroke_target: int = -1
var _last_dropped: String = ""


func configure(catalog: BuildCatalog, bounds: Rect2i, capacity: int) -> StringName:
	"""The planning area in cells (pitch 1024 u) and a room's most cells; refused exactly as the planner's draft
	refuses them. Discards any batch."""
	var probe: Draft = Draft.new()
	var code: StringName = probe.configure(0, 1, PITCH_U, capacity, bounds, false)
	if code != &"" or catalog == null:
		return code if code != &"" else REFUSE_NOT_CONFIGURED
	_catalog = catalog
	_bounds = bounds
	_capacity = capacity
	discard_all()
	return &""


func configured() -> bool:
	"""Whether a planning area is set."""
	return _catalog != null


# --- the stroke in progress ----------------------------------------------------------------------------------------

func begin_stroke(room_type: int, level: int, cell: Vector2i) -> bool:
	"""Start a rectangle of `room_type` on `level` at `cell`; false when one is already in progress, the batch has
	no planning area, or the planner refuses the room identity."""
	if _catalog == null or _stroke != null:
		return false
	var scratch: Draft = Draft.new()
	if scratch.configure(room_type, level, PITCH_U, _capacity, _bounds, false) != &"":
		return false
	_stroke = scratch
	_stroke_type = room_type
	_stroke_level = level
	_stroke_start = cell
	_stroke_end = cell
	_stroke.begin_stroke(Draft.RECTANGLE, cell, 0, false)
	_judge_stroke()
	return true


func extend_stroke(cell: Vector2i) -> void:
	"""Move the rectangle's far corner; the same cell again does nothing."""
	if _stroke == null or cell == _stroke_end:
		return
	_stroke_end = cell
	_stroke.extend_stroke(cell)
	_judge_stroke()


func cancel_stroke() -> bool:
	"""Drop only the stroke in progress (Escape, a right click); earlier paint and its history stay."""
	if _stroke == null:
		return false
	_stroke = null
	stroke_revision += 1
	return true


func finish_stroke() -> int:
	"""Release: a stroke that may be painted joins the batch (one undo step); an "X" stroke is dropped, its words kept
	in `last_dropped`. Returns the stroke's validity kind, or -1 with no stroke."""
	if _stroke == null:
		return -1
	var kind: int = _stroke_kind
	_stroke = null
	stroke_revision += 1
	_last_dropped = Validity.line(kind, _stroke_reason) if kind == Validity.KIND_NOT_POSSIBLE else ""
	if kind == Validity.KIND_NOT_POSSIBLE:
		return kind
	var target: int = _stroke_target if _stroke_target >= 0 else _new_operation(_stroke_type, _stroke_level)
	if target < 0:
		return Validity.KIND_NOT_POSSIBLE
	_paint_rectangle(target)
	_record(target)
	return kind


func stroke_active() -> bool:
	"""Whether a stroke is in progress."""
	return _stroke != null


func stroke_cells() -> PackedInt32Array:
	"""The stroke's rectangle (a copy), or the empty array with none (or one the planner refused to draw)."""
	return _stroke.visible_cells() if _stroke != null and _stroke.preview_error() == &"" else PackedInt32Array()


func stroke_size() -> Vector2i:
	"""The stroke's width and depth in cells (0 × 0 with none)."""
	if _stroke == null:
		return Vector2i.ZERO
	return (_stroke_end - _stroke_start).abs() + Vector2i.ONE


func stroke_kind() -> int:
	"""The stroke's validity kind now (build_validity.gd KIND_*)."""
	return _stroke_kind


func stroke_reason() -> String:
	"""Why the stroke is blocked or not possible ("" when it can be built)."""
	return _stroke_reason


func stroke_type() -> int:
	"""The room type being painted (-1 with no stroke)."""
	return _stroke_type if _stroke != null else -1


func stroke_level() -> int:
	"""The level being painted on."""
	return _stroke_level


static func size_text(size: Vector2i) -> String:
	"""SET-BUILD-001 §3's size label: "17 × 6 cells (17 m × 6 m)"."""
	return SIZE_FORMAT % [size.x, size.y, size.x, size.y]


func stroke_line() -> String:
	"""UI-BUILD-010's words: "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build" ("" with no stroke)."""
	if _stroke == null:
		return ""
	return PAINT_FORMAT % [BuildCatalog.type_name(_stroke_type), size_text(stroke_size()),
		Validity.line(_stroke_kind, _stroke_reason)]


func last_dropped() -> String:
	"""The words of the last stroke dropped on release as not possible ("" if the last one joined the batch)."""
	return _last_dropped


func _judge_stroke() -> void:
	"""The stroke's validity and the operation it would extend (see WHAT A STROKE MAY NOT DO)."""
	stroke_revision += 1
	_stroke_target = -1
	_stroke_kind = Validity.KIND_NOT_POSSIBLE
	var error: StringName = _stroke.preview_error()
	var size: Vector2i = stroke_size()
	if error == &"ROOM_OUTSIDE_PLANNING_BOUNDS":
		_stroke_reason = Validity.outside()
	elif error != &"":
		_stroke_reason = Validity.shape(shape_words(error))
	elif size.x < 2 or size.y < 2:
		_stroke_reason = Validity.too_narrow()
	else:
		_judge_against_batch()


func _judge_against_batch() -> void:
	"""A drawable rectangle against the planned rooms on its level: overlap, joining, and the size it makes."""
	var rect: Rect2i = Rect2i(_stroke_start.min(_stroke_end), stroke_size())
	var other: int = _overlapped_other(rect)
	if other >= 0:
		_stroke_reason = Validity.overlaps(BuildCatalog.type_name(_types[other]))
		return
	var touching: PackedInt32Array = _touching_same(rect)
	if touching.size() > 1:
		_stroke_reason = Validity.joins_two()
		return
	_stroke_target = touching[0] if touching.size() == 1 else -1
	var cells: int = rect.get_area()
	if _stroke_target >= 0:
		cells += _counts[_stroke_target] - _inside_count(_drafts[_stroke_target].visible_cells(), rect)
	_set_size_kind(_stroke_type, cells)


func _set_size_kind(room_type: int, cells: int) -> void:
	"""✓ or SET-BUILD-001 §4's "! Too small" for `cells` painted cells of `room_type`."""
	var least: int = _catalog.minimum_cells(room_type)
	_stroke_kind = Validity.KIND_CAN_BUILD
	_stroke_reason = ""
	if cells < least:
		_stroke_kind = Validity.KIND_BLOCKED
		_stroke_reason = Validity.too_small(BuildCatalog.type_name(room_type), least, cells)


func _overlapped_other(rect: Rect2i) -> int:
	"""The first planned room of ANOTHER type on the stroke's level with a cell inside `rect`, or -1."""
	for k: int in _drafts.size():
		if _levels[k] == _stroke_level and _types[k] != _stroke_type and _counts[k] > 0 \
				and _inside_count(_drafts[k].visible_cells(), rect) > 0:
			return k
	return -1


func _touching_same(rect: Rect2i) -> PackedInt32Array:
	"""The planned rooms of the stroke's type on its level that overlap `rect` or share an edge with it."""
	var out: PackedInt32Array = PackedInt32Array()
	var across: Rect2i = rect.grow_individual(1, 0, 1, 0)
	var along: Rect2i = rect.grow_individual(0, 1, 0, 1)
	for k: int in _drafts.size():
		if _levels[k] != _stroke_level or _types[k] != _stroke_type or _counts[k] == 0:
			continue
		var cells: PackedInt32Array = _drafts[k].visible_cells()
		if _inside_count(cells, across) > 0 or _inside_count(cells, along) > 0:
			out.append(k)
	return out


static func _inside_count(cells: PackedInt32Array, rect: Rect2i) -> int:
	"""How many of the `[x, z]` pairs lie inside `rect`."""
	var count: int = 0
	for at: int in range(0, cells.size(), 2):
		if rect.has_point(Vector2i(cells[at], cells[at + 1])):
			count += 1
	return count


static func shape_words(error: StringName) -> String:
	"""The planner's shape refusal in a player's words (the codes `modular_draft.gd` returns)."""
	return SHAPE_WORDS.get(error, "this shape cannot be drawn; adjust the stroke")


# --- the operations ------------------------------------------------------------------------------------------------

func _new_operation(room_type: int, level: int) -> int:
	"""Append an empty operation (its own planner draft); its index, or -1 if the planner refuses it."""
	var draft: Draft = Draft.new()
	if draft.configure(room_type, level, PITCH_U, _capacity, _bounds, false) != &"":
		return -1
	_drafts.append(draft)
	_types.append(room_type)
	_levels.append(level)
	_counts.append(0)
	_refusals.append("")
	_refused_at.append(-1)
	_judged_at.append(-1)
	_kinds.append(Validity.KIND_CAN_BUILD)
	_reasons.append("")
	return _drafts.size() - 1


func _paint_rectangle(k: int) -> void:
	"""Replay the stroke's rectangle onto operation `k`'s draft: one completed edit in its own history."""
	var draft: Draft = _drafts[k]
	draft.begin_stroke(Draft.RECTANGLE, _stroke_start, 0, false)
	draft.extend_stroke(_stroke_end)
	draft.finish_stroke()
	_recount(k)


func _record(k: int) -> void:
	"""One batch step on operation `k`: onto Undo (oldest dropped past HISTORY_LIMIT); Redo is cleared."""
	if _undo.size() >= HISTORY_LIMIT:
		_undo.remove_at(0)
	_undo.append(k)
	_redo.clear()
	_prune()
	revision += 1


func _recount(k: int) -> void:
	"""Operation `k`'s cell count after a change."""
	@warning_ignore("integer_division") var count: int = _drafts[k].visible_cells().size() / 2
	_counts[k] = count


func undo() -> bool:
	"""Undo the stroke in progress, else the last batch step; false when there is nothing to undo."""
	if cancel_stroke():
		return true
	if _undo.is_empty():
		return false
	var k: int = _undo[_undo.size() - 1]
	_undo.remove_at(_undo.size() - 1)
	_drafts[k].undo()
	_recount(k)
	_redo.append(k)
	revision += 1
	return true


func redo() -> bool:
	"""Redo the last undone batch step; false when there is none (any new stroke clears them)."""
	if _redo.is_empty() or _stroke != null:
		return false
	var k: int = _redo[_redo.size() - 1]
	_redo.remove_at(_redo.size() - 1)
	_drafts[k].redo()
	_recount(k)
	_undo.append(k)
	revision += 1
	return true


func can_undo() -> bool:
	"""Whether Undo would change something (a stroke in progress, or a batch step)."""
	return _stroke != null or not _undo.is_empty()


func can_redo() -> bool:
	"""Whether Redo would change something."""
	return _stroke == null and not _redo.is_empty()


func undo_label() -> String:
	"""UI-BUILD-006's words: "Undo Paint Kitchen", or "Nothing to undo"."""
	if _stroke != null:
		return "Undo the stroke in progress"
	return "Undo Paint %s" % BuildCatalog.type_name(_types[_undo[_undo.size() - 1]]) if not _undo.is_empty() \
		else NOTHING_TO_UNDO


func redo_label() -> String:
	"""UI-BUILD-007's words: "Redo Paint Kitchen", or "Nothing to redo"."""
	return "Redo Paint %s" % BuildCatalog.type_name(_types[_redo[_redo.size() - 1]]) if can_redo() else NOTHING_TO_REDO


func history_size() -> int:
	"""How many batch steps Undo and Redo hold together (never more than HISTORY_LIMIT)."""
	return _undo.size() + _redo.size()


func discard_all() -> int:
	"""Drop every operation, the stroke and the history; returns how many pending changes were dropped."""
	var dropped: int = pending_count()
	_stroke = null
	_drafts.clear()
	_types.clear()
	_levels.clear()
	_counts.clear()
	_refusals.clear()
	_refused_at.clear()
	_judged_at.clear()
	_kinds.clear()
	_reasons.clear()
	_undo.clear()
	_redo.clear()
	_last_dropped = ""
	stroke_revision += 1
	revision += 1
	return dropped


func _prune() -> void:
	"""Drop emptied operations nothing in Undo or Redo can reach, renumbering the history (cold: once per step)."""
	var keep: PackedInt32Array = PackedInt32Array()
	var map: PackedInt32Array = PackedInt32Array()
	map.resize(_drafts.size())
	for k: int in _drafts.size():
		map[k] = -1
		if _counts[k] > 0 or _undo.has(k) or _redo.has(k):
			map[k] = keep.size()
			keep.append(k)
	if keep.size() == _drafts.size():
		return
	_keep_only(keep)
	for at: int in _undo.size():
		_undo[at] = map[_undo[at]]
	for at: int in _redo.size():
		_redo[at] = map[_redo[at]]


func _keep_only(keep: PackedInt32Array) -> void:
	"""Keep the operations listed in `keep`, in order."""
	var drafts: Array[Draft] = []
	for k: int in keep:
		drafts.append(_drafts[k])
	_drafts = drafts
	_types = _picked(_types, keep)
	_levels = _picked(_levels, keep)
	_counts = _picked(_counts, keep)
	_refused_at = _picked(_refused_at, keep)
	_judged_at = _picked(_judged_at, keep)
	_kinds = _picked(_kinds, keep)
	_refusals = _picked_words(_refusals, keep)
	_reasons = _picked_words(_reasons, keep)


static func _picked(column: PackedInt32Array, keep: PackedInt32Array) -> PackedInt32Array:
	"""The entries of `column` at the indices in `keep`, in order (a new array)."""
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in keep:
		out.append(column[k])
	return out


static func _picked_words(column: PackedStringArray, keep: PackedInt32Array) -> PackedStringArray:
	"""The entries of `column` at the indices in `keep`, in order (a new array)."""
	var out: PackedStringArray = PackedStringArray()
	for k: int in keep:
		out.append(column[k])
	return out


# --- reading the operations ----------------------------------------------------------------------------------------

func operation_count() -> int:
	"""How many operations the batch holds, emptied ones included (see `operation_cells`)."""
	return _drafts.size()


func pending_count() -> int:
	"""How many operations would be ordered: those with at least one cell."""
	var count: int = 0
	for cells: int in _counts:
		if cells > 0:
			count += 1
	return count


func operation_type(k: int) -> int:
	"""Operation `k`'s room type."""
	return _types[k]


func operation_level(k: int) -> int:
	"""Operation `k`'s level."""
	return _levels[k]


func operation_cell_count(k: int) -> int:
	"""Operation `k`'s painted cells (0: emptied by Undo, not pending)."""
	return _counts[k]


func operation_cells(k: int) -> PackedInt32Array:
	"""Operation `k`'s cells, canonical `[x, z]` pairs (a copy)."""
	return _drafts[k].visible_cells()


func operation_draft(k: int) -> Draft:
	"""Operation `k`'s planner draft, for the order route (which reads its snapshot)."""
	return _drafts[k]


func operation_kind(k: int) -> int:
	"""Operation `k`'s validity kind (cached per draft revision)."""
	_judge(k)
	return _kinds[k]


func operation_reason(k: int) -> String:
	"""Why operation `k` is blocked or not possible ("" when it can be built)."""
	_judge(k)
	return _reasons[k]


func operation_line(k: int) -> String:
	"""Operation `k` in words: "Dormitory (+24 cells): ✓ Can build"."""
	return "%s (+%d cells): %s" % [BuildCatalog.type_name(_types[k]), _counts[k], Validity.line(operation_kind(k), operation_reason(k))]


func first_invalid() -> int:
	"""The first pending operation, in batch order, that is not "✓ Can build"; -1 when none."""
	for k: int in _drafts.size():
		if _counts[k] > 0 and operation_kind(k) != Validity.KIND_CAN_BUILD:
			return k
	return -1


func invalid_count() -> int:
	"""How many pending operations are not "✓ Can build" (BUILD-REQ-021)."""
	var count: int = 0
	for k: int in _drafts.size():
		if _counts[k] > 0 and operation_kind(k) != Validity.KIND_CAN_BUILD:
			count += 1
	return count


func _judge(k: int) -> void:
	"""Re-judge operation `k` when its draft or its refusal changed (see WHAT A STROKE MAY NOT DO): too narrow, a
	planner shape refusal, too small, the order route's kept refusal, or ✓."""
	var draft: Draft = _drafts[k]
	if _judged_at[k] == draft.revision:
		return
	_judged_at[k] = draft.revision
	_kinds[k] = Validity.KIND_CAN_BUILD
	_reasons[k] = ""
	var cells: PackedInt32Array = draft.visible_cells()
	var least: int = _catalog.minimum_cells(_types[k])
	if cells.is_empty():
		return
	if not two_by_two(cells):
		_set_judgement(k, Validity.KIND_NOT_POSSIBLE, Validity.too_narrow())
	elif draft.confirmation_error() != &"":
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.shape(shape_words(draft.confirmation_error())))
	elif _counts[k] < least:
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.too_small(BuildCatalog.type_name(_types[k]), least, _counts[k]))
	elif _refused_at[k] == draft.revision and not _refusals[k].is_empty():
		_set_judgement(k, Validity.KIND_BLOCKED, _refusals[k])


func _set_judgement(k: int, kind: int, reason: String) -> void:
	"""Operation `k`'s cached validity."""
	_kinds[k] = kind
	_reasons[k] = reason


static func two_by_two(cells: PackedInt32Array) -> bool:
	"""BUILD-REQ-002: every cell lies inside at least one 2 × 2 block of the set (canonical pairs)."""
	for at: int in range(0, cells.size(), 2):
		if not _in_a_block(cells, cells[at], cells[at + 1]):
			return false
	return true


static func _in_a_block(cells: PackedInt32Array, x: int, z: int) -> bool:
	"""Whether cell (x, z) is a corner of some 2 × 2 block wholly inside `cells`."""
	for dx: int in [-1, 0]:
		for dz: int in [-1, 0]:
			if Footprint.contains_cell(cells, x + dx, z + dz) and Footprint.contains_cell(cells, x + dx + 1, z + dz) \
					and Footprint.contains_cell(cells, x + dx, z + dz + 1) \
					and Footprint.contains_cell(cells, x + dx + 1, z + dz + 1):
				return true
	return false


# --- the ledger's reads ----------------------------------------------------------------------------------------------

func total_cells() -> int:
	"""Every pending cell in the batch."""
	var total: int = 0
	for cells: int in _counts:
		total += cells
	return total


func type_cells_into(types_out: PackedInt32Array, cells_out: PackedInt32Array) -> void:
	"""The expanded ledger's lines: each room type in order of first appearance, with its pending cells."""
	types_out.clear()
	cells_out.clear()
	for k: int in _drafts.size():
		if _counts[k] == 0:
			continue
		var at: int = types_out.find(_types[k])
		if at < 0:
			types_out.append(_types[k])
			cells_out.append(_counts[k])
		else:
			cells_out[at] += _counts[k]


# --- Confirm all ------------------------------------------------------------------------------------------------------

func confirm_all(submit: Callable) -> PackedInt32Array:
	"""BUILD-REQ-019 through the host's order route: `submit(draft, level, room_type) -> Dictionary` with `ok` and
	`error` (words) is called for each pending "✓" operation in batch order. An ordered operation leaves the batch,
	out of Undo's reach; a refused one stays with its reason. Nothing is deducted here. Returns [ordered, refused];
	[0, 0] while a stroke is in progress or any operation is invalid (Confirm all is disabled then)."""
	var ordered: PackedInt32Array = PackedInt32Array()
	var refused: int = 0
	if _stroke != null or invalid_count() > 0:
		return PackedInt32Array([0, 0])
	for k: int in _drafts.size():
		if _counts[k] == 0:
			continue
		var answer: Variant = submit.call(_drafts[k], _levels[k], _types[k])
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			ordered.append(k)
		else:
			refused += 1
			_keep_refusal(k, answer)
	_forget(ordered)
	revision += 1
	return PackedInt32Array([ordered.size(), refused])


func _keep_refusal(k: int, answer: Variant) -> void:
	"""Operation `k` stays in the batch, "! Blocked" with the route's own words until it changes."""
	var words: String = String((answer as Dictionary).get("error", "")) if answer is Dictionary else ""
	_refusals[k] = words if not words.is_empty() else UNCHECKED
	_refused_at[k] = _drafts[k].revision
	_judged_at[k] = -1


func _forget(ordered: PackedInt32Array) -> void:
	"""Ordered operations are confirmed projects now: they leave the batch and Undo/Redo never reach them
	(BUILD-REQ-020)."""
	if ordered.is_empty():
		return
	for k: int in ordered:
		_drafts[k].discard()
		_counts[k] = 0
	_undo = _without(_undo, ordered)
	_redo = _without(_redo, ordered)
	_prune()


static func _without(history: PackedInt32Array, gone: PackedInt32Array) -> PackedInt32Array:
	"""`history` with every step on an operation in `gone` removed."""
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in history:
		if not gone.has(k):
			out.append(k)
	return out
