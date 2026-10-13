extends RefCounted
## The build panel's ONE PENDING BATCH (DEC-061 Q1; SET-BUILD-001 BUILD-REQ-020/021; ARCH-BUILD-001 "Pending batch"):
## ordered paint operations on any level, one batch-wide Undo/Redo, Discard all, a validity per operation and per cell
## in words, and what the ledger reads. PRESENTATION-SIDE: never saved, never authoritative, and it holds no reference
## to any store, reservation, job or project -- painting, undoing and discarding cannot touch them (UX-BUILD-T04).
##
## BUILT ON THE PLANNER'S DRAFT (Brendan's ruling 2 of 2026-10-12; ADRs 1052 and 1055). Each operation IS a
## `modular_draft.gd` session -- one room of one type on one level, its cells on the 1 m grid (pitch 1024 u) -- so its
## shape rules, canonical cells and own snapshot undo are the planner's. The stroke in progress (build_stroke.gd) is a
## Rectangle, an Oval, or the 2 × 2 Paint or Erase brush (decision 1911 P-C7 (a)).
##
## WHAT A RELEASE DOES (decision 1912, slice C1).
##   Paint   the stroke's cells join the room of its type it overlaps or shares an edge with (BUILD-REQ-004). Touching
##           SEVERAL such pending rooms, it MERGES them into the oldest (the lowest operation; P-B2 (b), OPEN-06's
##           merge applied before confirmation): the others are emptied in the same step. Touching none: a new room.
##   Erase   the stroke's cells leave the pending rooms of the chosen type it covers. A room left in pieces is SPLIT,
##           each 4-connected piece its own room (BUILD-REQ-003): the piece holding the room's first cell stays.
## One release is ONE batch step, however many operations it changed; Undo and Redo replay the step on each of them
## (each changed exactly once). The history holds at most HISTORY_LIMIT = 32 steps (ADR 1055). An emptied operation
## stays while the history can reach it, and is dropped once nothing can.
##
## WHAT A STROKE MAY NOT DO ("X": dropped on release, its words kept, no step): leave the planning area, be narrower
## than 2 cells (BUILD-REQ-002), cover a planned room of another type (BUILD-REQ-005), add nothing, pass a room's most
## cells, cover a cell the crew cannot dig (ECON-003, per cell); Erase: cover no pending cell of its type, or leave a
## room part one cell wide (BUILD-REQ-006's words). What makes an operation "!" Blocked -- kept, holding Confirm all
## back -- is a planner shape refusal, being under SET-BUILD-001 §4's least size, a cell with no way in
## (BUILD-REQ-013, decision 1911 P-C4 (a)), or the "X"/"!" the order route last answered (until it changes).
##
## PER CELL (build_cell_validity.gd): every operation's cells are judged per level -- the ground the crew can dig, the
## 2 × 2 rule, the way in -- and cached until a cell of that level or the ground reader's revision changes.

const Draft := preload("res://demo/burrow/modular_draft.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Items := preload("res://scripts/ui/build_items.gd")

## SET-BUILD-001 §3: one cell is 1 m, 1024 u.
const PITCH_U: int = 1024
## ADR 1055: the planner keeps at most 32 complete edits.
const HISTORY_LIMIT: int = Draft.HISTORY_LIMIT
const REFUSE_NOT_CONFIGURED: StringName = &"BUILD_BATCH_NOT_CONFIGURED"
const SIZE_FORMAT: String = "%d × %d cells (%d m × %d m)"
const STROKE_FORMAT: String = "%s %s %s; %s"
const ERASE_OK: String = "✓ Takes out the planned cells under it"
const NOTHING_TO_UNDO: String = "Nothing to undo"
const NOTHING_TO_REDO: String = "Nothing to redo"
## A step's verb, stored as its first entry.
const VERB_PAINT: int = 0
const VERB_ERASE: int = 1
const VERB_PLACE: int = 2
const VERBS: Array[String] = ["Paint", "Erase", "Place"]
## A step entry at or past ITEM_TAG names a way down (build_items.gd row = entry - ITEM_TAG), not an operation.
const ITEM_TAG: int = 1 << 24
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
var _tool: int = Stroke.TOOL_RECTANGLE
var _cells: Cells = Cells.new()
var _drafts: Array[Draft] = []
var _types: PackedInt32Array = PackedInt32Array()
var _levels: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _refusals: PackedStringArray = PackedStringArray()
var _refused_at: PackedInt32Array = PackedInt32Array()
## The kept refusal's kind: ! (the route may take it later: retried, never holding Confirm all back) or X.
var _refused_kind: PackedInt32Array = PackedInt32Array()
var _judged_at: PackedInt32Array = PackedInt32Array()
var _judged_layout: PackedInt32Array = PackedInt32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _reasons: PackedStringArray = PackedStringArray()
## Each operation's per-cell codes (build_cell_validity.gd CELL_*), aligned with its cells.
var _codes: Array[PackedByteArray] = []
## Bumped whenever any operation's cells change (Undo, Redo, a release, an order, Discard all).
var _layout: int = 0
## Per level: the layout and ground revisions its cells were last judged at.
var _level_judged: Dictionary = {}
var _seen_ground: int = 0
## Steps: [verb, operation, operation, ...].
var _undo: Array[PackedInt32Array] = []
var _redo: Array[PackedInt32Array] = []
var _stroke: Stroke = Stroke.new()
var _stroke_kind: int = Validity.KIND_CAN_BUILD
var _stroke_reason: String = ""
var _targets: PackedInt32Array = PackedInt32Array()
var _stroke_codes: PackedByteArray = PackedByteArray()
var _last_dropped: String = ""
var _items: Items = Items.new()
var _host_landings: Callable = Callable()


func configure(catalog: BuildCatalog, bounds: Rect2i, capacity: int) -> StringName:
	"""The planning area in cells (pitch 1024 u) and a room's most cells; refused exactly as the planner's draft
	refuses them. Discards any batch."""
	var probe: Draft = Draft.new()
	var code: StringName = probe.configure(0, 1, PITCH_U, capacity, bounds, false)
	if code != &"" or catalog == null:
		return code if code != &"" else REFUSE_NOT_CONFIGURED
	code = _cells.configure(bounds)
	if code != &"":
		return code
	_cells.bind_landings(_all_landings)
	_catalog = catalog
	_bounds = bounds
	_capacity = capacity
	discard_all()
	return &""


func configured() -> bool:
	"""Whether a planning area is set."""
	return _catalog != null


func bind_ground(ground: Callable, ground_revision: Callable) -> void:
	"""The host's ground reader for the per-cell judgement (build_cell_validity.gd `bind_ground`)."""
	_cells.bind_ground(ground, ground_revision)
	revision += 1


func bind_landings(landings: Callable) -> void:
	"""The host's built connector landings per level, `landings(level) -> PackedInt32Array` (slice D's); the batch adds
	its own pending ways down to them for the per-cell way in."""
	_host_landings = landings
	revision += 1


func _all_landings(level: int) -> PackedInt32Array:
	"""Every landing on `level`: the host's built ones and the batch's pending ways down (OPEN-07 (a))."""
	var out: PackedInt32Array = _items.landings(level)
	if _host_landings.is_valid():
		out.append_array(PackedInt32Array(_host_landings.call(level)))
	return out


func cell_judge() -> Cells:
	"""The per-cell judge (checks)."""
	return _cells


func set_tool(tool: int) -> bool:
	"""Choose Rectangle, Oval, Paint or Erase (build_stroke.gd TOOL_*); a stroke in progress is cancelled."""
	if not Stroke.valid_tool(tool):
		return false
	cancel_stroke()
	_tool = tool
	stroke_revision += 1
	return true


func tool() -> int:
	"""The tool a new stroke draws with."""
	return _tool


# --- the stroke in progress ----------------------------------------------------------------------------------------

func begin_stroke(room_type: int, level: int, cell: Vector2i) -> bool:
	"""Start a stroke of the chosen tool for `room_type` on `level` at `cell`; false when one is already in progress,
	the batch has no planning area, or the planner refuses the room identity."""
	if _catalog == null or _stroke.active():
		return false
	if not _stroke.begin(_tool, room_type, level, cell, PITCH_U, _capacity, _bounds):
		return false
	_judge_stroke()
	return true


func extend_stroke(cell: Vector2i) -> void:
	"""Move the stroke's far corner or brush; the same cell again does nothing."""
	if _stroke.extend(cell):
		_judge_stroke()


func cancel_stroke() -> bool:
	"""Drop only the stroke in progress (Escape, a right click); earlier paint and its history stay."""
	if not _stroke.active():
		return false
	_stroke.clear()
	stroke_revision += 1
	return true


func finish_stroke() -> int:
	"""Release: a stroke that may be applied joins the batch (one undo step); an "X" stroke is dropped, its words kept
	in `last_dropped`. Returns the stroke's validity kind, or -1 with no stroke."""
	if not _stroke.active():
		return -1
	var kind: int = _stroke_kind
	var stamp: PackedInt32Array = _stroke.cells()
	var erase: bool = _stroke.erasing()
	_stroke.clear()
	stroke_revision += 1
	_last_dropped = Validity.line(kind, _stroke_reason) if kind == Validity.KIND_NOT_POSSIBLE else ""
	if kind == Validity.KIND_NOT_POSSIBLE:
		return kind
	if erase:
		_apply_erase(stamp)
		return kind
	return _apply_paint(stamp, kind)


func _drop(reason: String) -> int:
	"""A stroke the planner would not take after all: dropped as "X", its words kept, no history step."""
	_last_dropped = Validity.line(Validity.KIND_NOT_POSSIBLE, reason)
	revision += 1
	return Validity.KIND_NOT_POSSIBLE


func stroke_active() -> bool:
	"""Whether a stroke is in progress."""
	return _stroke.active()


func stroke_erasing() -> bool:
	"""Whether the stroke in progress takes cells away."""
	return _stroke.active() and _stroke.erasing()


func stroke_cells() -> PackedInt32Array:
	"""The stroke's cells (a copy), or the empty array with none (or one the planner refused to draw)."""
	return _stroke.cells()


func stroke_cell_codes() -> PackedByteArray:
	"""The stroke's per-cell codes (build_cell_validity.gd CELL_*), aligned with `stroke_cells`."""
	return _stroke_codes


func stroke_size() -> Vector2i:
	"""The stroke's width and depth in cells (0 × 0 with none)."""
	return _stroke.size()


func stroke_kind() -> int:
	"""The stroke's validity kind now (build_validity.gd KIND_*)."""
	return _stroke_kind


func stroke_reason() -> String:
	"""Why the stroke is blocked or not possible ("" when it can be built)."""
	return _stroke_reason


func stroke_type() -> int:
	"""The room type being painted (-1 with no stroke)."""
	return _stroke.room_type if _stroke.active() else -1


func stroke_level() -> int:
	"""The level being painted on."""
	return _stroke.level


static func size_text(size: Vector2i) -> String:
	"""SET-BUILD-001 §3's size label: "17 × 6 cells (17 m × 6 m)"."""
	return SIZE_FORMAT % [size.x, size.y, size.x, size.y]


func stroke_line() -> String:
	"""UI-BUILD-010's words: "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build" ("" with no stroke)."""
	if not _stroke.active():
		return ""
	var verb: String = VERBS[VERB_ERASE if _stroke.erasing() else VERB_PAINT]
	var result: String = ERASE_OK if _stroke.erasing() and _stroke_kind == Validity.KIND_CAN_BUILD \
		else Validity.line(_stroke_kind, _stroke_reason)
	return STROKE_FORMAT % [verb, BuildCatalog.type_name(_stroke.room_type), size_text(stroke_size()), result]


func last_dropped() -> String:
	"""The words of the last stroke dropped on release as not possible ("" if the last one joined the batch)."""
	return _last_dropped


# --- judging the stroke --------------------------------------------------------------------------------------------

func _judge_stroke() -> void:
	"""The stroke's validity, the operations it would change, and its per-cell codes (see WHAT A STROKE MAY NOT DO)."""
	_sync_ground()
	stroke_revision += 1
	_targets.clear()
	_stroke_codes = PackedByteArray()
	_set_stroke(Validity.KIND_NOT_POSSIBLE, "")
	var error: StringName = _stroke.error()
	var stamp: PackedInt32Array = _stroke.cells()
	if error == &"ROOM_OUTSIDE_PLANNING_BOUNDS":
		_stroke_reason = Validity.outside()
	elif error != &"" or stamp.is_empty():
		_stroke_reason = Validity.shape(shape_words(error))
	elif _stroke.erasing():
		_judge_erase(stamp)
	elif not two_by_two(stamp):
		_stroke_reason = Validity.too_narrow()
	else:
		_judge_paint(stamp)


func _set_stroke(kind: int, reason: String) -> void:
	"""The stroke's judgement now."""
	_stroke_kind = kind
	_stroke_reason = reason


func _judge_paint(stamp: PackedInt32Array) -> void:
	"""A drawable paint stroke against its level: another type under it, the rooms it joins, the room it makes."""
	var other: int = _covered_other(stamp)
	if other >= 0:
		_stroke_reason = Validity.overlaps(BuildCatalog.type_name(_types[other]))
		return
	_targets = _touching_same(stamp)
	var union: PackedInt32Array = _union_with_targets(stamp)
	var before: int = 0
	for k: int in _targets:
		before += _counts[k]
	@warning_ignore("integer_division") var cells: int = union.size() / 2
	if cells == before:
		_stroke_reason = Validity.nothing_new()
	elif cells > _capacity or union.is_empty():
		_stroke_reason = Validity.shape(shape_words(&"FOOTPRINT_CAPACITY"))
	else:
		_set_size_kind(_stroke.room_type, cells)
		_judge_union(union, stamp)


func _union_with_targets(stamp: PackedInt32Array) -> PackedInt32Array:
	"""The room the stroke would make: its cells with every room it joins (empty past a room's most cells)."""
	var union: PackedInt32Array = stamp
	for k: int in _targets:
		var combined: Dictionary = Footprint.combine(union, _drafts[k].visible_cells(), false, _capacity)
		if not combined.ok:
			return PackedInt32Array()
		union = combined.cells
	return union


func _judge_union(union: PackedInt32Array, stamp: PackedInt32Array) -> void:
	"""The made room's shape as the planner judges it (a hole or pinch is "! Blocked", never ✓), then its cells: a
	stroke cell the crew cannot dig makes the stroke "X"; a room cell with no way in, "!". Cold: once per moved cell."""
	var error: StringName = Footprint.validation_error(union, _capacity, false)
	if error != &"" and _stroke_kind == Validity.KIND_CAN_BUILD:
		_set_stroke(Validity.KIND_BLOCKED, Validity.shape(shape_words(error)))
	var codes: PackedByteArray = _judge_with(_stroke.level, union)
	_stroke_codes = _codes_of(stamp, union, codes)
	var dug: int = _first_code(_stroke_codes, true)
	if dug >= 0:
		_set_stroke(Validity.KIND_NOT_POSSIBLE, Cells.words_of(_stroke_codes[dug]))
	elif _stroke_kind == Validity.KIND_CAN_BUILD and codes.has(Cells.CELL_NO_WAY_IN):
		_set_stroke(Validity.KIND_BLOCKED, Validity.no_way_in())


func _judge_with(level: int, made: PackedInt32Array) -> PackedByteArray:
	"""`made` judged per cell on `level` among the pending rooms there the stroke leaves alone."""
	var sets: Array[PackedInt32Array] = []
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0 and not _targets.has(k):
			sets.append(_drafts[k].visible_cells())
	sets.append(made)
	var judged: Array[PackedByteArray] = _cells.judge_level(level, sets)
	return judged[judged.size() - 1]


static func _codes_of(stamp: PackedInt32Array, union: PackedInt32Array, codes: PackedByteArray) -> PackedByteArray:
	"""The codes of `stamp`'s cells, read from `union`'s (both canonical; every stamp cell is in the union)."""
	var out: PackedByteArray = PackedByteArray()
	@warning_ignore("integer_division") var count: int = stamp.size() / 2
	out.resize(count)
	var at: int = 0
	for slot: int in count:
		while at < codes.size() and (union[at * 2] != stamp[slot * 2] or union[at * 2 + 1] != stamp[slot * 2 + 1]):
			at += 1
		out[slot] = codes[at] if at < codes.size() else Cells.CELL_OK
	return out


static func _first_code(codes: PackedByteArray, dig_only: bool) -> int:
	"""The first "X" cell's slot (only ground refusals with `dig_only`), or -1."""
	for slot: int in codes.size():
		var code: int = codes[slot]
		if code == Cells.CELL_OK or code == Cells.CELL_NO_WAY_IN or (dig_only and code == Cells.CELL_TOO_NARROW):
			continue
		return slot
	return -1


func _judge_erase(stamp: PackedInt32Array) -> void:
	"""An Erase stroke: the pending rooms of its type it covers, and what each would keep (never a one-cell strip)."""
	_targets = _covered_same(stamp)
	var name: String = BuildCatalog.type_name(_stroke.room_type)
	if _targets.is_empty():
		_stroke_reason = Validity.nothing_to_erase(name)
		return
	for k: int in _targets:
		var kept: Dictionary = Footprint.combine(_drafts[k].visible_cells(), stamp, true, _capacity)
		if not kept.ok or not two_by_two(kept.cells):
			_stroke_reason = Validity.narrow_removal(name)
			return
	_set_stroke(Validity.KIND_CAN_BUILD, "")


func _set_size_kind(room_type: int, cells: int) -> void:
	"""✓ or SET-BUILD-001 §4's "! Too small" for `cells` painted cells of `room_type`."""
	var least: int = _catalog.minimum_cells(room_type)
	_set_stroke(Validity.KIND_CAN_BUILD, "")
	if cells < least:
		_set_stroke(Validity.KIND_BLOCKED, Validity.too_small(BuildCatalog.type_name(room_type), least, cells))


func _covered_other(stamp: PackedInt32Array) -> int:
	"""The first pending room of ANOTHER type on the stroke's level with a cell under the stamp, or -1."""
	for k: int in _drafts.size():
		if _levels[k] == _stroke.level and _types[k] != _stroke.room_type and _counts[k] > 0 \
				and _shares_cell(_drafts[k].visible_cells(), stamp, false):
			return k
	return -1


func _touching_same(stamp: PackedInt32Array) -> PackedInt32Array:
	"""The pending rooms of the stroke's type on its level that the stamp overlaps or shares an edge with, oldest
	first."""
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in _drafts.size():
		if _same_room_kind(k) and _shares_cell(_drafts[k].visible_cells(), stamp, true):
			out.append(k)
	return out


func _covered_same(stamp: PackedInt32Array) -> PackedInt32Array:
	"""The pending rooms of the stroke's type on its level with a cell under the stamp, oldest first."""
	var out: PackedInt32Array = PackedInt32Array()
	for k: int in _drafts.size():
		if _same_room_kind(k) and _shares_cell(_drafts[k].visible_cells(), stamp, false):
			out.append(k)
	return out


func _same_room_kind(k: int) -> bool:
	"""Whether operation `k` is a pending room of the stroke's type on its level."""
	return _levels[k] == _stroke.level and _types[k] == _stroke.room_type and _counts[k] > 0


static func _shares_cell(cells: PackedInt32Array, stamp: PackedInt32Array, or_side: bool) -> bool:
	"""Whether a stamp cell is in `cells` (or, with `or_side`, beside one); quick reject on the two boxes first."""
	var box: Rect2i = Stroke.box_of(cells).grow(1 if or_side else 0)
	if not box.intersects(Stroke.box_of(stamp)):
		return false
	for at: int in range(0, stamp.size(), 2):
		var x: int = stamp[at]
		var z: int = stamp[at + 1]
		if Footprint.contains_cell(cells, x, z):
			return true
		if or_side and (Footprint.contains_cell(cells, x + 1, z) or Footprint.contains_cell(cells, x - 1, z) \
				or Footprint.contains_cell(cells, x, z + 1) or Footprint.contains_cell(cells, x, z - 1)):
			return true
	return false


static func shape_words(error: StringName) -> String:
	"""The planner's shape refusal in a player's words (the codes `modular_draft.gd` returns)."""
	return SHAPE_WORDS.get(error, "this shape cannot be drawn; adjust the stroke")


# --- applying a release --------------------------------------------------------------------------------------------

func _apply_paint(stamp: PackedInt32Array, kind: int) -> int:
	"""Paint: the stamp and every other joined room into the oldest joined room (or a new one), the others emptied;
	one step. Returns `kind`, or "X" when the planner refused after all (nothing changed)."""
	var targets: PackedInt32Array = _targets.duplicate()
	var target: int = targets[0] if not targets.is_empty() else _new_operation(_stroke.room_type, _stroke.level)
	if target < 0:
		return _drop(Validity.shape(shape_words(&"")))
	var paint: PackedInt32Array = stamp
	for k: int in targets.slice(1):
		paint = Footprint.combine(paint, _drafts[k].visible_cells(), false, _capacity).cells
	var before: int = _drafts[target].revision
	var error: StringName = _drafts[target].apply_cells(paint, false)
	_recount(target)
	if error != &"" or _drafts[target].revision == before:
		_prune()
		return _drop(Validity.shape(shape_words(error)) if error != &"" else Validity.nothing_new())
	var step: PackedInt32Array = PackedInt32Array([VERB_PAINT, target])
	for k: int in targets.slice(1):
		_drafts[k].apply_cells(_drafts[k].visible_cells(), true)
		_recount(k)
		step.append(k)
	_record(step)
	return kind


func _apply_erase(stamp: PackedInt32Array) -> void:
	"""Erase: the stamp out of each covered room; a room left in pieces keeps the piece with its first cell and each
	other piece becomes a new room; one step."""
	var step: PackedInt32Array = PackedInt32Array([VERB_ERASE])
	for k: int in _targets.duplicate():
		var kept: PackedInt32Array = Footprint.combine(_drafts[k].visible_cells(), stamp, true, _capacity).cells
		var pieces: Array[PackedInt32Array] = components(kept)
		var keep: PackedInt32Array = pieces[0] if not pieces.is_empty() else PackedInt32Array()
		var gone: PackedInt32Array = Footprint.combine(_drafts[k].visible_cells(), keep, true, _capacity).cells
		_drafts[k].apply_cells(gone, true)
		_recount(k)
		step.append(k)
		for piece: PackedInt32Array in pieces.slice(1):
			var made: int = _new_operation(_types[k], _levels[k])
			_drafts[made].apply_cells(piece, false)
			_recount(made)
			step.append(made)
	_record(step)


static func components(cells: PackedInt32Array) -> Array[PackedInt32Array]:
	"""The 4-connected pieces of canonical `cells`, each canonical, the piece holding the first cell first."""
	var out: Array[PackedInt32Array] = []
	var seen: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		var start: Vector2i = Vector2i(cells[at], cells[at + 1])
		if seen.has(start):
			continue
		out.append(_piece_from(cells, start, seen))
	return out


static func _piece_from(cells: PackedInt32Array, start: Vector2i, seen: Dictionary) -> PackedInt32Array:
	"""The piece of `cells` 4-connected to `start` (marking each in `seen`), canonical."""
	var piece: PackedInt32Array = PackedInt32Array()
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		piece.append_array(PackedInt32Array([cell.x, cell.y]))
		for side: Vector2i in Cells.SIDES:
			var next: Vector2i = cell + side
			if not seen.has(next) and Footprint.contains_cell(cells, next.x, next.y):
				seen[next] = true
				queue.append(next)
	return Footprint.combine(PackedInt32Array(), piece, false, Footprint.MAX_OPERATION_CELLS).cells


# --- the ways down (decision 1912) ----------------------------------------------------------------------------------

func items() -> Items:
	"""The pending ways down (read only for hosts: drawing, the ledger, checks)."""
	return _items


func place_item(level: int, cell: Vector2i) -> int:
	"""Place a way down on `level` at `cell` (its north-west cell): one step; an "X" one is dropped with its words in
	`last_dropped`. Returns its validity kind, or -1 with a stroke in progress or no planning area."""
	if _catalog == null or _stroke.active():
		return -1
	var judged: Array = judge_item(level, cell, -1)
	if int(judged[0]) == Validity.KIND_NOT_POSSIBLE:
		_last_dropped = Validity.line(Validity.KIND_NOT_POSSIBLE, String(judged[1]))
		revision += 1
		return Validity.KIND_NOT_POSSIBLE
	_last_dropped = ""
	_record(PackedInt32Array([VERB_PLACE, ITEM_TAG + _items.add(level, cell)]))
	return int(judged[0])


func judge_item(level: int, cell: Vector2i, own_row: int) -> Array:
	"""[kind, reason] for a way down on `level` at `cell` (`own_row`: its own pending row, -1 for a new one): it needs a
	level below, room for itself, on levels 1-3 a planned or dug passage or room under it, and diggable ground where it
	lands. Cold: on placement and once per judgement of the batch."""
	var name: String = Items.name_of(level)
	if level < 0 or level > Items.DEEPEST_TOP:
		return [Validity.KIND_NOT_POSSIBLE, Validity.no_level_below()]
	var cells: PackedInt32Array = Items.footprint(cell)
	for at: int in range(0, cells.size(), 2):
		if not _bounds.has_point(Vector2i(cells[at], cells[at + 1])):
			return [Validity.KIND_NOT_POSSIBLE, Validity.outside()]
	var clash: int = _items.clashes(level, cell)
	if clash >= 0 and clash != own_row:
		return [Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down(Items.name_of(level))]
	var landing: String = _landing_refusal(level + 1, cells)
	if not landing.is_empty():
		return [Validity.KIND_NOT_POSSIBLE, landing]
	if level > 0 and not _stands_on_rooms(level, cells):
		return [Validity.KIND_BLOCKED, Validity.needs_floor(name)]
	return [Validity.KIND_CAN_BUILD, ""]


func _landing_refusal(level: int, cells: PackedInt32Array) -> String:
	"""Why the cells a way down lands on cannot be dug ("" when they can, or are dug already)."""
	if not _cells.ground_bound():
		return ""
	for at: int in range(0, cells.size(), 2):
		var code: int = _cells.ground_of(level, Vector2i(cells[at], cells[at + 1]))
		if code != Cells.CELL_OK and code != Cells.CELL_FINISHED:
			return Cells.words_of(code)
	return ""


func _stands_on_rooms(level: int, cells: PackedInt32Array) -> bool:
	"""Whether every cell lies in a pending room on `level` or in dug (or ordered) space."""
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		if not _in_any_operation(level, cell) and _cells.ground_of(level, cell) != Cells.CELL_FINISHED:
			return false
	return true


func _in_any_operation(level: int, cell: Vector2i) -> bool:
	"""Whether a pending room on `level` holds `cell`."""
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0 and Footprint.contains_cell(_drafts[k].visible_cells(), cell.x, cell.y):
			return true
	return false


func item_kind(row: int) -> int:
	"""Pending way down `row`'s validity kind now."""
	return int(judge_item(_items.level_of(row), _items.cell_of(row), row)[0])


func item_reason(row: int) -> String:
	"""Why pending way down `row` is blocked or not possible ("" when it can be built)."""
	return String(judge_item(_items.level_of(row), _items.cell_of(row), row)[1])


func first_invalid_item() -> int:
	"""The first pending way down that holds Confirm all back; -1 when none."""
	for row: int in _items.count():
		if _items.is_live(row) and item_kind(row) != Validity.KIND_CAN_BUILD:
			return row
	return -1


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
	_refused_kind.append(Validity.KIND_BLOCKED)
	_judged_at.append(-1)
	_judged_layout.append(-1)
	_kinds.append(Validity.KIND_CAN_BUILD)
	_reasons.append("")
	_codes.append(PackedByteArray())
	return _drafts.size() - 1


func _record(step: PackedInt32Array) -> void:
	"""One batch step (its verb, then each operation it changed once): onto Undo, oldest dropped past HISTORY_LIMIT;
	Redo is cleared. A step that changed no operation keeps nothing."""
	if step.size() < 2:
		_prune()
		return
	if _undo.size() >= HISTORY_LIMIT:
		_undo.remove_at(0)
	_undo.append(step)
	_redo.clear()
	_changed()
	_prune()


func _changed() -> void:
	"""Some operation's cells (or the ground) changed: every level is judged again when read."""
	_layout += 1
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
	var step: PackedInt32Array = _undo.pop_back()
	for at: int in range(1, step.size()):
		_replay(step[at], false)
	_redo.append(step)
	_changed()
	return true


func redo() -> bool:
	"""Redo the last undone batch step; false when there is none (any new stroke clears them)."""
	if _redo.is_empty() or _stroke.active():
		return false
	var step: PackedInt32Array = _redo.pop_back()
	for at: int in range(1, step.size()):
		_replay(step[at], true)
	_undo.append(step)
	_changed()
	return true


func _replay(entry: int, forward: bool) -> void:
	"""One step entry undone (`forward` false) or redone: an operation's draft, or a way down's placement."""
	if entry >= ITEM_TAG:
		_items.set_live(entry - ITEM_TAG, forward)
		return
	if forward:
		_drafts[entry].redo()
	else:
		_drafts[entry].undo()
	_recount(entry)


func can_undo() -> bool:
	"""Whether Undo would change something (a stroke in progress, or a batch step)."""
	return _stroke.active() or not _undo.is_empty()


func can_redo() -> bool:
	"""Whether Redo would change something."""
	return not _stroke.active() and not _redo.is_empty()


func undo_label() -> String:
	"""UI-BUILD-006's words: "Undo Paint Kitchen", or "Nothing to undo"."""
	if _stroke.active():
		return "Undo the stroke in progress"
	return "Undo %s" % _step_words(_undo[_undo.size() - 1]) if not _undo.is_empty() else NOTHING_TO_UNDO


func redo_label() -> String:
	"""UI-BUILD-007's words: "Redo Paint Kitchen", or "Nothing to redo"."""
	return "Redo %s" % _step_words(_redo[_redo.size() - 1]) if can_redo() else NOTHING_TO_REDO


func _step_words(step: PackedInt32Array) -> String:
	"""A step in words: its verb and its first operation's room type ("Paint Kitchen"), or the way down ("Place
	Entrance")."""
	if step[1] >= ITEM_TAG:
		return "%s %s" % [VERBS[step[0]], Items.name_of(_items.level_of(step[1] - ITEM_TAG))]
	return "%s %s" % [VERBS[step[0]], BuildCatalog.type_name(_types[step[1]])]


func history_size() -> int:
	"""How many batch steps Undo and Redo hold together (never more than HISTORY_LIMIT)."""
	return _undo.size() + _redo.size()


func discard_all() -> int:
	"""Drop every operation, the stroke and the history; returns how many pending changes were dropped."""
	var dropped: int = pending_count()
	_stroke.clear()
	_types.clear()
	_levels.clear()
	_counts.clear()
	_refusals.clear()
	_refused_at.clear()
	_refused_kind.clear()
	_judged_at.clear()
	_judged_layout.clear()
	_kinds.clear()
	_reasons.clear()
	_drafts.clear()
	_codes.clear()
	_items.clear()
	_undo.clear()
	_redo.clear()
	_level_judged.clear()
	_last_dropped = ""
	stroke_revision += 1
	_changed()
	return dropped


func _prune() -> void:
	"""Drop emptied operations no step can reach, renumbering the history (cold: once per step)."""
	var reached: Dictionary = _reached_operations()
	var keep: PackedInt32Array = PackedInt32Array()
	var map: PackedInt32Array = PackedInt32Array()
	map.resize(_drafts.size())
	for k: int in _drafts.size():
		map[k] = -1
		if _counts[k] > 0 or reached.has(k):
			map[k] = keep.size()
			keep.append(k)
	if keep.size() == _drafts.size():
		return
	_keep_only(keep)
	_renumber(_undo, map)
	_renumber(_redo, map)


func _reached_operations() -> Dictionary:
	"""Every operation some Undo or Redo step names."""
	var out: Dictionary = {}
	for history: Array[PackedInt32Array] in [_undo, _redo]:
		for step: PackedInt32Array in history:
			for at: int in range(1, step.size()):
				if step[at] < ITEM_TAG:
					out[step[at]] = true
	return out


static func _renumber(history: Array[PackedInt32Array], map: PackedInt32Array) -> void:
	"""Each step's operations through `map` (old index → new); ways down keep their rows."""
	for step: PackedInt32Array in history:
		for at: int in range(1, step.size()):
			if step[at] < ITEM_TAG:
				step[at] = map[step[at]]


func _keep_only(keep: PackedInt32Array) -> void:
	"""Keep the operations listed in `keep`, in order."""
	var drafts: Array[Draft] = []
	var codes: Array[PackedByteArray] = []
	for k: int in keep:
		drafts.append(_drafts[k])
		codes.append(_codes[k])
	_drafts = drafts
	_codes = codes
	_types = _picked(_types, keep)
	_levels = _picked(_levels, keep)
	_counts = _picked(_counts, keep)
	_refused_at = _picked(_refused_at, keep)
	_refused_kind = _picked(_refused_kind, keep)
	_judged_at = _picked(_judged_at, keep)
	_judged_layout = _picked(_judged_layout, keep)
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
	"""How many changes would be ordered: rooms with at least one cell, and pending ways down."""
	var count: int = _items.live_count()
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
	"""Operation `k`'s painted cells (0: emptied by Undo, a merge or an order; not pending)."""
	return _counts[k]


func operation_cells(k: int) -> PackedInt32Array:
	"""Operation `k`'s cells, canonical `[x, z]` pairs (a copy)."""
	return _drafts[k].visible_cells()


func operation_cell_codes(k: int) -> PackedByteArray:
	"""Operation `k`'s per-cell codes (build_cell_validity.gd CELL_*), aligned with `operation_cells(k)`."""
	_judge(k)
	return _codes[k]


func operation_draft(k: int) -> Draft:
	"""Operation `k`'s planner draft, for the order route (which reads its snapshot)."""
	return _drafts[k]


func operation_kind(k: int) -> int:
	"""Operation `k`'s validity kind (cached per draft and level revision)."""
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
	"""The first pending operation, in batch order, that holds Confirm all back (not "✓ Can build" and not only
	refused by the route last time, which Confirm all retries); -1 when none."""
	for k: int in _drafts.size():
		if _holds_back(k):
			return k
	return -1


func invalid_count() -> int:
	"""How many pending changes hold Confirm all back (BUILD-REQ-021; see `first_invalid`), ways down included."""
	var count: int = 0
	for row: int in _items.count():
		if _items.is_live(row) and item_kind(row) != Validity.KIND_CAN_BUILD:
			count += 1
	for k: int in _drafts.size():
		if _holds_back(k):
			count += 1
	return count


func _holds_back(k: int) -> bool:
	"""Whether pending operation `k` disables Confirm all: any judgement but ✓, except a "!" refusal of the route."""
	return _counts[k] > 0 and operation_kind(k) != Validity.KIND_CAN_BUILD and not retryable(k)


func retryable(k: int) -> bool:
	"""Whether operation `k`'s only problem is the order route's "!" refusal last time: it stays "! Blocked" in words
	and Confirm all tries it again (decision 1871, the coordinator's resolution of review H3)."""
	return operation_kind(k) == Validity.KIND_BLOCKED and _refused_at[k] == _drafts[k].revision \
		and _reasons[k] == _refusals[k]


func first_refused() -> int:
	"""The first pending operation the route refused last time and Confirm all will retry; -1 when none."""
	for k: int in _drafts.size():
		if _counts[k] > 0 and retryable(k):
			return k
	return -1


func _judge(k: int) -> void:
	"""Re-judge operation `k` when its draft, its level's cells, the ground or its refusal changed: an "X" cell
	(ground, then 2 × 2), a planner shape refusal, too small, a cell with no way in, the route's kept refusal, or ✓."""
	_judge_level(_levels[k])
	var draft: Draft = _drafts[k]
	if _judged_at[k] == draft.revision and _judged_layout[k] == _layout:
		return
	_judged_at[k] = draft.revision
	_judged_layout[k] = _layout
	_set_judgement(k, Validity.KIND_CAN_BUILD, "")
	if _counts[k] == 0:
		return
	var least: int = _catalog.minimum_cells(_types[k])
	var dug: int = _first_code(_codes[k], true)
	var narrow: int = _first_code(_codes[k], false)
	if dug >= 0 or narrow >= 0:
		_set_judgement(k, Validity.KIND_NOT_POSSIBLE, Cells.words_of(_codes[k][dug if dug >= 0 else narrow]))
	elif draft.confirmation_error() != &"":
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.shape(shape_words(draft.confirmation_error())))
	elif _counts[k] < least:
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.too_small(BuildCatalog.type_name(_types[k]), least, _counts[k]))
	elif _codes[k].has(Cells.CELL_NO_WAY_IN):
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.no_way_in())
	elif _refused_at[k] == draft.revision and not _refusals[k].is_empty():
		_set_judgement(k, _refused_kind[k], _refusals[k])


func _judge_level(level: int) -> void:
	"""Every pending operation's cells on `level` judged per cell, once per layout (and ground) revision."""
	_sync_ground()
	if _level_judged.get(level, -1) == _layout:
		return
	_level_judged[level] = _layout
	var ops: PackedInt32Array = PackedInt32Array()
	var sets: Array[PackedInt32Array] = []
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0:
			ops.append(k)
			sets.append(_drafts[k].visible_cells())
	var judged: Array[PackedByteArray] = _cells.judge_level(level, sets)
	for at: int in ops.size():
		_codes[ops[at]] = judged[at]


func _sync_ground() -> void:
	"""The ground reader moved on: every level and operation is judged again (and the ghosts redrawn)."""
	var ground: int = _cells.ground_revision()
	if ground != _seen_ground:
		_seen_ground = ground
		_changed()


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

func confirm_all(submit: Callable, submit_item: Callable = Callable()) -> PackedInt32Array:
	"""BUILD-REQ-019 through the host's order route: first each pending way down (`submit_item(level, cell) ->
	Dictionary`; the ways in come first, SET-BUILD-001 §10), then `submit(draft, level, room_type) -> Dictionary` with
	`ok` and `error` (words) for each pending "✓" room in batch order. Ordered changes leave the batch, out of Undo's
	reach; a refused room stays with its reason. Nothing is deducted here. Returns [ordered, refused]; [0, 0] while a
	stroke is in progress or any change is invalid (Confirm all is disabled then)."""
	if _stroke.active() or invalid_count() > 0:
		return PackedInt32Array([0, 0])
	var gone: PackedInt32Array = _confirm_items(submit_item)
	var ordered: PackedInt32Array = PackedInt32Array()
	var refused: int = _items.live_count()
	for k: int in _drafts.size():
		if _counts[k] == 0:
			continue
		var answer: Variant = submit.call(_drafts[k], _levels[k], _types[k])
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			ordered.append(k)
		else:
			refused += 1
			_keep_refusal(k, answer)
	_forget(ordered, gone)
	revision += 1
	return PackedInt32Array([ordered.size() + gone.size(), refused])


func _confirm_items(submit_item: Callable) -> PackedInt32Array:
	"""Each pending way down through `submit_item`; the step entries of those it ordered (no longer pending)."""
	var gone: PackedInt32Array = PackedInt32Array()
	for row: int in _items.count():
		if not _items.is_live(row) or not submit_item.is_valid():
			continue
		var answer: Variant = submit_item.call(_items.level_of(row), _items.cell_of(row))
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			_items.set_live(row, false)
			gone.append(ITEM_TAG + row)
	return gone


func _keep_refusal(k: int, answer: Variant) -> void:
	"""Operation `k` stays in the batch with the route's words until it changes: "! Blocked" (retried by the next
	Confirm all), or "X Not possible" when the answer's `kind` says it can never succeed there."""
	var words: String = String((answer as Dictionary).get("error", "")) if answer is Dictionary else ""
	var kind: int = int((answer as Dictionary).get("kind", Validity.KIND_BLOCKED)) if answer is Dictionary \
		else Validity.KIND_BLOCKED
	_refused_kind[k] = Validity.KIND_NOT_POSSIBLE if kind == Validity.KIND_NOT_POSSIBLE else Validity.KIND_BLOCKED
	_refusals[k] = words if not words.is_empty() else UNCHECKED
	_refused_at[k] = _drafts[k].revision
	_judged_at[k] = -1


func _forget(ordered: PackedInt32Array, items_gone: PackedInt32Array = PackedInt32Array()) -> void:
	"""Ordered changes are confirmed now: they leave the batch, and every step naming one leaves the history whole,
	so Undo/Redo never reach them (BUILD-REQ-020)."""
	if ordered.is_empty() and items_gone.is_empty():
		return
	for k: int in ordered:
		_drafts[k].discard()
		_counts[k] = 0
	var gone: PackedInt32Array = ordered.duplicate()
	gone.append_array(items_gone)
	_undo = _without(_undo, gone)
	_redo = _without(_redo, gone)
	_changed()
	_prune()


static func _without(history: Array[PackedInt32Array], gone: PackedInt32Array) -> Array[PackedInt32Array]:
	"""`history` without every step that names an operation in `gone`."""
	var out: Array[PackedInt32Array] = []
	for step: PackedInt32Array in history:
		var names_gone: bool = false
		for at: int in range(1, step.size()):
			names_gone = names_gone or gone.has(step[at])
		if not names_gone:
			out.append(step)
	return out
