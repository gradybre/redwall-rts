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
##
## MOUND HOMES (decision 2002, the proof of concept of decision 2001; build_mound.gd). An operation has a STYLE: Built
## (dug underground) or Mound (painted on the Surface, dug into a hill heaped to fit it). A stroke keeps one style: a
## Mound stroke off the Surface is "X" (BUILD-MOUND-028), and a stroke touching a same-type room of the other style is
## "X" (BUILD-MOUND-002); rooms merge only with their own type AND style. On the Surface the way in is a door, not a
## connector: a Mound (its rooms joined cell to cell, pending or confirmed) with no door on an outer edge has every
## pending cell "! No way in: place a door on an outer edge" (BUILD-MOUND-012), and a stroke whose hill -- the rooms
## and their berm (build_mound.gd `footprint_into`) -- would cover water, a tree, an item or a way down that is not
## wholly on one room's floor is "X" in BUILD-MOUND-008's words, as is one that would bury a confirmed door or window
## (BUILD-MOUND-018's review, stood in for). DOORS AND WINDOWS (build_mound_edges.gd) are pending rows of their own
## (`MOUND_TAG`): a click on a free outer edge places one, on a pending one takes it back, on a confirmed one asks for
## its removal -- each one step. Confirm all orders them after the rooms (`submit_edge`).

const Draft := preload("res://demo/burrow/modular_draft.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")

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
## A pending door or window taken back by a click (decision 2002): its row's live flag is turned the other way round.
const VERB_REMOVE: int = 3
const VERBS: Array[String] = ["Paint", "Erase", "Place", "Remove"]
## A step entry at or past ITEM_TAG names a way down (build_items.gd row = entry - ITEM_TAG), not an operation; at or
## past PIECE_TAG, a piece of furniture (build_furniture.gd row = entry - PIECE_TAG; decision 1921).
const ITEM_TAG: int = 1 << 24
const PIECE_TAG: int = 2 << 24
## At or past MOUND_TAG, a Mound's door or window (build_mound_edges.gd row = entry - MOUND_TAG; decision 2002).
const MOUND_TAG: int = 3 << 24
## Decision 2021: a pending removal whose confirmed way is no longer there (a PROPOSAL, decision 2022).
const NO_WAY_THERE: String = "no built way stands there now"
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
## Each operation's style (build_mound.gd STYLE_*: Built or Mound).
var _styles: PackedByteArray = PackedByteArray()
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
var _pieces: Furniture = Furniture.new()
var _host_landings: Callable = Callable()
## Decision 2002: the stroke's style, the pending doors and windows, and the host's Mound readers (`bind_mound_host`).
var _stroke_style: int = Mound.STYLE_BUILT
var _edges: MoundEdges = MoundEdges.new()
var _host_mound_cells: Callable = Callable()
var _host_ways: Callable = Callable()
var _host_surface: Callable = Callable()
var _host_doors: Callable = Callable()
var _host_edges: Callable = Callable()
var _host_listed: Callable = Callable()
## Decision 2021 (slice D1): the host's confirmed ways by shape, its cut-off check and its dug rooms' types
## (`bind_way_host`), and the cut-off words worked out once a revision for the pending removals.
var _host_shapes: Callable = Callable()
var _host_cut_off: Callable = Callable()
var _host_type: Callable = Callable()
var _cut_at: int = -1
var _cut_words: String = ""
## The host's own ground reader, and the cells pending removals take away, worked out once a revision.
var _host_ground: Callable = Callable()
var _removed_at: int = -1
var _removed_cells: Dictionary = {}
## The Surface's Mound cells, their footprint and the hill's refusal, worked out once per layout (`_mound_layout`).
var _mound_seen: int = -1
var _mound_cells: PackedInt32Array = PackedInt32Array()
var _mound_lookup: Dictionary = {}
var _mound_footprint: Dictionary = {}
var _hill_words: Dictionary = {}


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
	_pieces.bind_ways(_way_cells)
	_edges.bind_host(_mound_room_at, _confirmed_edge, _listed_edges)
	_catalog = catalog
	_bounds = bounds
	_capacity = capacity
	discard_all()
	return &""


func configured() -> bool:
	"""Whether a planning area is set."""
	return _catalog != null


func bind_ground(ground: Callable, ground_revision: Callable) -> void:
	"""The host's ground reader for the per-cell judgement (build_cell_validity.gd `bind_ground`), read through
	`_ground_less_removed` (decision 2022, review H3)."""
	_host_ground = ground
	_cells.bind_ground(_ground_less_removed, ground_revision)
	_changed()


func _ground_less_removed(level: int, cell: Vector2i) -> int:
	"""The host's ground, except that a confirmed way's cells below which a pending removal takes away are no longer
	finished space -- never a way in, and "occupied" under a stroke (BUILD-REQ-013 with BUILD-REQ-017's removal)."""
	var code: int = int(_host_ground.call(level, cell))
	if code != Cells.CELL_FINISHED or _items.live_count() == 0:
		return code
	if _removed_at != revision:
		_removed_at = revision
		_removed_cells = _removed_lower_cells()
	return Cells.CELL_OCCUPIED if _removed_cells.has(Vector3i(level, cell.x, cell.y)) else code


func _removed_lower_cells() -> Dictionary:
	"""Every lower cell (level, x, z) of the confirmed ways pending removals name."""
	var out: Dictionary = {}
	for row: int in _items.count():
		if _items.is_live(row) and _items.is_removal(row):
			var cells: PackedInt32Array = _items.lower(row)
			for at: int in range(0, cells.size(), 2):
				out[Vector3i(_items.level_of(row) + 1, cells[at], cells[at + 1])] = true
	return out


func bind_landings(landings: Callable) -> void:
	"""The host's confirmed connector landings per level, `landings(level) -> PackedInt32Array` (decision 2021: built,
	or confirmed and waiting to be dug, P-D1-7 (a)); the batch adds its own pending ways to them for the per-cell way
	in, less those a pending removal takes away."""
	_host_landings = landings
	_changed()


func bind_mound_host(cells: Callable, ways: Callable, surface: Callable, doors: Callable, edges: Callable,
		listed: Callable = Callable()) -> void:
	"""Decision 2002's host readers: `cells() -> PackedInt32Array`, the confirmed Mound room cells on the Surface
	(pairs); `ways(level) -> PackedInt32Array`, the cells confirmed ways down stand on; `surface(cell) -> String`, what
	the hill would cover there ("water", "a tree" ...; "" for nothing); `doors() -> PackedInt32Array`, the first cells
	of the confirmed front doors (pairs); `edges(level, edge) -> Vector4i`, the confirmed door or window on an edge
	(build_mound_edges.gd THE HOST'S READERS); `listed(kind) -> Array`, the first edges of the confirmed doors or
	windows of `kind`."""
	_host_listed = listed
	_host_mound_cells = cells
	_host_ways = ways
	_host_surface = surface
	_host_doors = doors
	_host_edges = edges
	_changed()


func _all_landings(level: int) -> PackedInt32Array:
	"""Every landing on `level`: the host's built ones and the batch's pending ways down (OPEN-07 (a))."""
	var out: PackedInt32Array = _items.landings(level)
	if _host_landings.is_valid():
		out.append_array(_without(PackedInt32Array(_host_landings.call(level)), _items.removed_landings(level)))
	return out


static func _without(cells: PackedInt32Array, gone: PackedInt32Array) -> PackedInt32Array:
	"""`cells` (pairs) less any of `gone` (pairs)."""
	if gone.is_empty():
		return cells
	var drop: Dictionary = {}
	for at: int in range(0, gone.size(), 2):
		drop[Vector2i(gone[at], gone[at + 1])] = true
	var out: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, cells.size(), 2):
		if not drop.has(Vector2i(cells[at], cells[at + 1])):
			out.append_array(PackedInt32Array([cells[at], cells[at + 1]]))
	return out


func bind_way_host(shapes: Callable, cut_off: Callable, room_type: Callable = Callable()) -> void:
	"""Decision 2021's host readers: `shapes(level) -> PackedInt32Array`, the confirmed ways standing on `level` as
	(x, z, family, turn) quads; `cut_off(ways: PackedInt32Array, doors: Array) -> String`, the names a removal of those
	confirmed ways ((level, x, z) triples) and Mound doors (first edges, Vector3i) would cut off ("" for none:
	BUILD-REQ-017, build_way_graph.gd); `room_type(level, cell) -> int`, the room type dug or ordered there (-1 none)."""
	_host_shapes = shapes
	_host_cut_off = cut_off
	_host_type = room_type
	_changed()


func _way_cells(level: int) -> PackedInt32Array:
	"""The cells pending ways down take on `level`: where they stand, and where they land (decision 1921: furniture
	keeps clear of them)."""
	return _items.taken(level)


func cell_judge() -> Cells:
	"""The per-cell judge (checks)."""
	return _cells


func set_tool(chosen: int) -> bool:
	"""Choose Rectangle, Oval, Paint or Erase (build_stroke.gd TOOL_*); a stroke in progress is cancelled."""
	if not Stroke.valid_tool(chosen):
		return false
	cancel_stroke()
	_tool = chosen
	stroke_revision += 1
	return true


func tool() -> int:
	"""The tool a new stroke draws with."""
	return _tool


# --- the stroke in progress ----------------------------------------------------------------------------------------

func begin_stroke(room_type: int, level: int, cell: Vector2i, style: int = Mound.STYLE_BUILT) -> bool:
	"""Start a stroke of the chosen tool for `room_type` in `style` (build_mound.gd STYLE_*) on `level` at `cell`; false
	when one is already in progress, the batch has no planning area, the style is unknown, or the planner refuses the
	room identity."""
	if _catalog == null or _stroke.active() or not Mound.valid_style(style):
		return false
	if not _stroke.begin(_tool, room_type, level, cell, PITCH_U, _capacity, _bounds):
		return false
	_stroke_style = style
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


func stroke_style() -> int:
	"""The style being painted (build_mound.gd STYLE_*)."""
	return _stroke_style


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
	elif not _style_refusal().is_empty():
		_stroke_reason = _style_refusal()
	elif _stroke.erasing():
		_judge_erase(stamp)
	elif not _cells.all_in_blocks(stamp):
		_stroke_reason = Validity.too_narrow()
	else:
		_judge_paint(stamp)


func _style_refusal() -> String:
	"""Why the stroke's style cannot be painted on its level ("" when it can): a Mound off the Surface
	(BUILD-MOUND-028), a built room on it (slice G)."""
	var surface: bool = _stroke.level == Mound.SURFACE
	if _stroke_style == Mound.STYLE_MOUND and not surface:
		return Mound.TEXT_SURFACE_ONLY
	return Mound.LATER_BUILT_SURFACE if _stroke_style == Mound.STYLE_BUILT and surface else ""


func _set_stroke(kind: int, reason: String) -> void:
	"""The stroke's judgement now."""
	_stroke_kind = kind
	_stroke_reason = reason


func _judge_paint(stamp: PackedInt32Array) -> void:
	"""A drawable paint stroke against its level: another type (or style) under it, a same-type room of the other style
	beside it, the rooms it joins, the room it makes."""
	var other: int = _covered_other(stamp)
	if other >= 0:
		_stroke_reason = Validity.overlaps(BuildCatalog.type_name(_types[other]))
		return
	if _joins_other_style(stamp):
		_stroke_reason = Mound.TEXT_NO_JOIN
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
		_judge_hill(union)


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
	elif _stroke_kind == Validity.KIND_CAN_BUILD and codes.has(Cells.CELL_NO_DOOR):
		_set_stroke(Validity.KIND_BLOCKED, Mound.TEXT_NO_DOOR)


func _judge_with(level: int, made: PackedInt32Array) -> PackedByteArray:
	"""`made` judged per cell on `level` among the pending rooms there the stroke leaves alone."""
	var sets: Array[PackedInt32Array] = []
	var styles: PackedByteArray = PackedByteArray()
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0 and not _targets.has(k):
			sets.append(_drafts[k].visible_cells())
			styles.append(_styles[k])
	sets.append(made)
	styles.append(_stroke_style)
	var judged: Array[PackedByteArray] = _cells.judge_level(level, sets, level != Mound.SURFACE)
	if level == Mound.SURFACE:
		_mark_doorless(sets, styles, judged)
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
		if code == Cells.CELL_OK or code == Cells.CELL_NO_WAY_IN or code == Cells.CELL_NO_DOOR \
				or (dig_only and code == Cells.CELL_TOO_NARROW):
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
		if not kept.ok or not _cells.all_in_blocks(kept.cells):
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
	"""The first pending room of ANOTHER type or style on the stroke's level with a cell under the stamp, or -1."""
	for k: int in _drafts.size():
		var other: bool = _types[k] != _stroke.room_type or _styles[k] != _stroke_style
		if _levels[k] == _stroke.level and other and _counts[k] > 0 \
				and _shares_cell(_drafts[k].visible_cells(), stamp, false):
			return k
	return -1


func _joins_other_style(stamp: PackedInt32Array) -> bool:
	"""Whether the stamp shares an edge with a pending room of its type in the other style (BUILD-MOUND-002)."""
	for k: int in _drafts.size():
		if _levels[k] == _stroke.level and _types[k] == _stroke.room_type and _styles[k] != _stroke_style \
				and _counts[k] > 0 and _shares_cell(_drafts[k].visible_cells(), stamp, true):
			return true
	return false


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
	"""Whether operation `k` is a pending room of the stroke's type and style on its level."""
	return _levels[k] == _stroke.level and _types[k] == _stroke.room_type and _styles[k] == _stroke_style \
		and _counts[k] > 0


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
	var target: int = targets[0] if not targets.is_empty() \
		else _new_operation(_stroke.room_type, _stroke.level, _stroke_style)
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
			var made: int = _new_operation(_types[k], _levels[k], _styles[k])
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


# --- the ways down (decision 1912; per family, decision 2021) -------------------------------------------------------

func items() -> Items:
	"""The pending ways down and removals (read only for hosts: drawing, the ledger, checks)."""
	return _items


func place_item(level: int, cell: Vector2i, family: int = Items.DEFAULT_FAMILY, turn: int = 0) -> int:
	"""Place a way of `family` turned `turn` standing on `level` at `cell` (its north-west cell): one step; an "X" one
	is dropped with its words in `last_dropped`. Returns its validity kind, or -1 with a stroke in progress or no
	planning area."""
	if _catalog == null or _stroke.active():
		return -1
	var judged: Array = judge_item(level, cell, -1, family, turn)
	if int(judged[0]) == Validity.KIND_NOT_POSSIBLE:
		_last_dropped = Validity.line(Validity.KIND_NOT_POSSIBLE, String(judged[1]))
		revision += 1
		return Validity.KIND_NOT_POSSIBLE
	_last_dropped = ""
	_record(PackedInt32Array([VERB_PLACE, ITEM_TAG + _items.add(level, cell, family, turn)]))
	return int(judged[0])


func judge_item(level: int, cell: Vector2i, own_row: int, family: int = Items.DEFAULT_FAMILY, turn: int = 0) -> Array:
	"""[kind, reason] for a way of `family` turned `turn` standing on `level` at `cell` (`own_row`: its own pending row,
	-1 for a new one): a level on each side, its cells inside the area and clear of other ways and furniture, ground
	below that can be dug (a run through solid earth), off a Mound's hill or wholly on one Mound room's floor, and below
	the Surface a passage under it (P-D1-5 (a)). Cold: on placement and once per judgement of the batch."""
	var name: String = Families.name_of(family)
	var fixed: String = _fixed_refusal(level, cell, family, turn)
	if not fixed.is_empty():
		return [Validity.KIND_NOT_POSSIBLE, fixed]
	var clash: int = _items.clashes(level, cell, own_row, family, turn)
	if clash >= 0:
		return [Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down(_items.name_of_row(clash))]
	var built: int = _confirmed_clash(level, cell, family, turn)
	if built >= 0:
		return [Validity.KIND_NOT_POSSIBLE, Validity.overlaps_way_down(Families.name_of(built))]
	var below: String = _below_refusal(level + 1, family, turn, cell)
	if below.is_empty():
		below = _piece_refusal(level, family, turn, cell)
	if below.is_empty() and level == Mound.SURFACE:
		below = _surface_refusal(family, turn, cell)
	if not below.is_empty():
		return [Validity.KIND_NOT_POSSIBLE, below]
	if level > 0 and not _on_passage(level, Families.standing_cells(family, turn, cell)):
		return [Validity.KIND_BLOCKED, Validity.needs_passage(name)]
	return [Validity.KIND_CAN_BUILD, ""]


func _confirmed_clash(level: int, cell: Vector2i, family: int, turn: int) -> int:
	"""The family of the first confirmed way (the host's, standing on the level above, this one or the one below) whose
	cells clash with this way's as two pending ways' would (build_items.gd `meets`), unless a pending removal takes it
	away; -1 when none."""
	var mine: Array = Items.taken_sets(level, family, turn, cell)
	for top: int in [level - 1, level, level + 1]:
		var shapes: PackedInt32Array = _shapes_on(top)
		for at: int in range(0, shapes.size(), 4):
			var anchor: Vector2i = Vector2i(shapes[at], shapes[at + 1])
			if _items.removal_row(top, anchor) < 0 \
					and Items.meets(mine, Items.taken_sets(top, shapes[at + 2], shapes[at + 3], anchor)):
				return shapes[at + 2]
	return -1


func _fixed_refusal(level: int, cell: Vector2i, family: int, turn: int) -> String:
	"""What makes a way impossible whatever else is planned: no level above or below, a family not offered yet or not
	at this turn (decision 2041 P-DF-6 (a)), or a cell outside the planning area ("" when none)."""
	if level < 0:
		return Validity.no_level_above()
	if level > Items.DEEPEST_TOP:
		return Validity.no_level_below()
	if not Families.offered(family):
		return Validity.not_yet(Families.LATER)
	var turned: String = Families.turn_refusal(family, turn)
	if not turned.is_empty():
		return turned
	for cells: PackedInt32Array in [Families.standing_cells(family, turn, cell), Families.lower_cells(family, turn, cell)]:
		for at: int in range(0, cells.size(), 2):
			if not _bounds.has_point(Vector2i(cells[at], cells[at + 1])):
				return Validity.outside()
	return ""


func _below_refusal(level: int, family: int, turn: int, cell: Vector2i) -> String:
	"""Why a way cannot come down onto `level` ("" when it can): its landing on ground that cannot be dug (dug already
	is fine), or its run through anything but untouched earth -- a planned or dug room is "occupied"."""
	var landing: PackedInt32Array = Families.landing_cells(family, turn, cell)
	for at: int in range(0, landing.size(), 2):
		var code: int = _ground_code(level, Vector2i(landing[at], landing[at + 1]))
		if code != Cells.CELL_OK and code != Cells.CELL_FINISHED:
			return Cells.words_of(code)
	var run: PackedInt32Array = Families.run_cells(family, turn, cell)
	for at: int in range(0, run.size(), 2):
		var at_cell: Vector2i = Vector2i(run[at], run[at + 1])
		var code: int = _ground_code(level, at_cell)
		if code == Cells.CELL_FINISHED or _in_any_operation(level, at_cell):
			return Validity.cannot_dig(Cells.DIG_WORDS[Cells.CELL_FINISHED])
		if code != Cells.CELL_OK:
			return Cells.words_of(code)
	return ""


func _ground_code(level: int, cell: Vector2i) -> int:
	"""The host's ground reading for a cell (CELL_OK with no ground reader: nothing is claimed)."""
	return _cells.ground_of(level, cell) if _cells.ground_bound() else Cells.CELL_OK


func _piece_refusal(level: int, family: int, turn: int, cell: Vector2i) -> String:
	"""A piece of furniture, pending or confirmed, on any cell the way takes, on either level ("" when none)."""
	var piece: int = maxi(_pieces.floor_taken(level, Families.standing_cells(family, turn, cell)),
		_pieces.floor_taken(level + 1, Families.lower_cells(family, turn, cell)))
	return Validity.piece_overlaps(Furniture.name_of(piece)) if piece >= 0 else ""


func _surface_refusal(family: int, turn: int, cell: Vector2i) -> String:
	"""On the Surface: a way partly on a Mound room's floor does not fit it (BUILD-MOUND-021); one on a Mound's hill is
	refused in BUILD-MOUND-008's words; one off the Mounds over water or a placed thing cannot be dug ("" when none)."""
	_mound_cache()
	var cells: PackedInt32Array = Families.standing_cells(family, turn, cell)
	var hill: String = _way_clear_of(cells, _mound_lookup, _mound_footprint)
	if hill == Mound.TEXT_SPLIT_WAY:
		return Validity.not_in_room(Families.name_of(family), Families.ACROSS[family], Families.TOP_OPEN[family])
	if not hill.is_empty() or _mound_lookup.has(Vector2i(cells[0], cells[1])):
		return hill
	return _ground_covered(cells)


func _ground_covered(cells: PackedInt32Array) -> String:
	"""Off a Mound room's floor: water or a placed thing on any standing cell ("Cannot dig here: water", "... a tree":
	the host's reader, decision 2002's; decision 2022) -- "" when the ground is open or there is no reader."""
	if not _host_surface.is_valid():
		return ""
	for at: int in range(0, cells.size(), 2):
		var thing: String = String(_host_surface.call(Vector2i(cells[at], cells[at + 1])))
		if not thing.is_empty():
			return Validity.cannot_dig(thing)
	return ""


func _on_passage(level: int, cells: PackedInt32Array) -> bool:
	"""Whether every cell lies in a pending Passage on `level` or in dug (or ordered) passage space (P-D1-5 (a); with no
	host type reader, dug space of any kind: a host that knows no types claims nothing about them)."""
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		if _in_any_operation(level, cell, BuildCatalog.CORRIDOR):
			continue
		if _cells.ground_of(level, cell) != Cells.CELL_FINISHED:
			return false
		if _host_type.is_valid() and int(_host_type.call(level, cell)) != BuildCatalog.CORRIDOR:
			return false
	return true


func _in_any_operation(level: int, cell: Vector2i, room_type: int = -1) -> bool:
	"""Whether a pending room on `level` (of `room_type`, or of any type for -1) holds `cell`."""
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0 and (room_type < 0 or _types[k] == room_type) \
				and Footprint.contains_cell(_drafts[k].visible_cells(), cell.x, cell.y):
			return true
	return false


func item_judgement(row: int) -> Array:
	"""[kind, reason] for pending row `row` now: a placement where it stands, or a removal (`_removal_judgement`)."""
	if _items.is_removal(row):
		return _removal_judgement(row)
	return judge_item(_items.level_of(row), _items.cell_of(row), row, _items.family_of(row), _items.turn_of(row))


func item_kind(row: int) -> int:
	"""Pending way `row`'s validity kind now."""
	return int(item_judgement(row)[0])


func item_reason(row: int) -> String:
	"""Why pending way `row` is blocked or not possible ("" when it can be built)."""
	return String(item_judgement(row)[1])


func first_invalid_item() -> int:
	"""The first pending way or removal that holds Confirm all back; -1 when none."""
	for row: int in _items.count():
		if _items.is_live(row) and item_kind(row) != Validity.KIND_CAN_BUILD:
			return row
	return -1


# --- removing a confirmed way (decision 2021: BUILD-REQ-017, Brendan's "Real check now") ---------------------------

func toggle_way_removal(level: int, cell: Vector2i) -> int:
	"""A click, with a way's card armed, on `cell` of a confirmed way on `level` (where it stands, or where it comes
	down from the level above): its removal is asked for, or a pending one withdrawn (one step each). A removal that
	would cut something off is dropped with "Would cut off ...: build another way in first" in `last_dropped`. Returns
	the validity kind; -1 when no confirmed way is there (or a stroke is in progress, or no planning area)."""
	if _catalog == null or _stroke.active():
		return -1
	var way: PackedInt32Array = confirmed_way_at(level, cell)
	if way.is_empty():
		return -1
	_last_dropped = ""
	var row: int = _items.removal_row(way[0], Vector2i(way[1], way[2]))
	if row >= 0:
		_items.set_live(row, false)
		_record(PackedInt32Array([VERB_REMOVE, ITEM_TAG + row]))
		return Validity.KIND_CAN_BUILD
	var names: String = _cut_off_text(way.slice(0, 3), [])
	if not names.is_empty():
		_last_dropped = Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.cut_off(names))
		revision += 1
		return Validity.KIND_NOT_POSSIBLE
	_record(PackedInt32Array([VERB_PLACE, ITEM_TAG + _items.add(way[0], Vector2i(way[1], way[2]), way[3], way[4], true)]))
	return Validity.KIND_CAN_BUILD


func confirmed_way_at(level: int, cell: Vector2i) -> PackedInt32Array:
	"""The confirmed way taking `cell` on `level` -- standing there, or coming down onto it from the level above -- as
	(level it stands on, x, z, family, turn); empty for none."""
	for top: int in [level, level - 1]:
		var shapes: PackedInt32Array = _shapes_on(top)
		for at: int in range(0, shapes.size(), 4):
			var anchor: Vector2i = Vector2i(shapes[at], shapes[at + 1])
			var cells: PackedInt32Array = Families.standing_cells(shapes[at + 2], shapes[at + 3], anchor) if top == level \
				else Families.lower_cells(shapes[at + 2], shapes[at + 3], anchor)
			if Footprint.contains_cell(cells, cell.x, cell.y):
				return PackedInt32Array([top, anchor.x, anchor.y, shapes[at + 2], shapes[at + 3]])
	return PackedInt32Array()


func _shapes_on(level: int) -> PackedInt32Array:
	"""The host's confirmed ways standing on `level` (quads; empty with no host or off the levels)."""
	if not _host_shapes.is_valid() or level < 0:
		return PackedInt32Array()
	return PackedInt32Array(_host_shapes.call(level))


func _removal_judgement(row: int) -> Array:
	"""A pending removal: "X" when its way is gone or the pending removals together would cut something off."""
	if _way_still_there(row).is_empty():
		return [Validity.KIND_NOT_POSSIBLE, NO_WAY_THERE]
	var names: String = _cut_off_now()
	return [Validity.KIND_NOT_POSSIBLE, Validity.cut_off(names)] if not names.is_empty() else [Validity.KIND_CAN_BUILD, ""]


func _way_still_there(row: int) -> PackedInt32Array:
	"""The confirmed way removal row `row` names, if the host still has it (else empty)."""
	var shapes: PackedInt32Array = _shapes_on(_items.level_of(row))
	for at: int in range(0, shapes.size(), 4):
		if Vector2i(shapes[at], shapes[at + 1]) == _items.cell_of(row):
			return shapes.slice(at, at + 4)
	return PackedInt32Array()


func _cut_off_now() -> String:
	"""What the pending removals together would cut off, worked out once a revision ("" for nothing)."""
	if _cut_at != revision:
		_cut_at = revision
		_cut_words = _cut_off_text(PackedInt32Array(), [])
	return _cut_words


func _cut_off_text(extra_ways: PackedInt32Array, extra_doors: Array) -> String:
	"""The host's names for what the pending removals of ways and Mound doors, plus `extra_ways` ((level, x, z)
	triples) and `extra_doors` (first edges), would cut off ("" for nothing, or with no host check)."""
	if not _host_cut_off.is_valid():
		return ""
	var ways: PackedInt32Array = PackedInt32Array()
	_items.removals_into(ways)
	ways.append_array(extra_ways)
	var doors: Array = _removed_doors()
	doors.append_array(extra_doors)
	if ways.is_empty() and doors.is_empty():
		return ""
	return String(_host_cut_off.call(ways, doors))


func _removed_doors() -> Array:
	"""The first edges of the confirmed front doors pending removals take away."""
	var out: Array = []
	for row: int in _edges.count():
		if _edges.is_live(row) and _edges.is_removal(row) and _edges.kind_of(row) == Mound.KIND_DOOR:
			out.append(_edges.edges_of(row)[0])
	return out


# --- the furniture (decision 1921) -----------------------------------------------------------------------------------

func furniture() -> Furniture:
	"""The pending pieces of furniture (read only for hosts: drawing, the ledger, checks)."""
	return _pieces


func bind_furniture_host(room_at: Callable, occupant: Callable, edge_occupant: Callable,
		piece_at: Callable = Callable()) -> void:
	"""The host's readers for judging furniture (build_furniture.gd THE HOST'S READERS)."""
	_pieces.bind_host(room_at, occupant, edge_occupant, piece_at)
	revision += 1


func place_piece(level: int, anchor: Vector2i, turn: int, item: int) -> int:
	"""Place `item` on `level` at `anchor` (its north-west cell; an edge item's cursor cell) turned `turn` quarter
	turns: one step; an "X" one is dropped with its words in `last_dropped`. Returns its validity kind, or -1 with a
	stroke in progress or no planning area."""
	if _catalog == null or _stroke.active():
		return -1
	var judged: Array = _pieces.judge(level, anchor, turn, item, -1)
	if int(judged[0]) != Validity.KIND_CAN_BUILD:
		_last_dropped = Validity.line(int(judged[0]), String(judged[1]))
		revision += 1
		return int(judged[0])
	_last_dropped = ""
	_record(PackedInt32Array([VERB_PLACE, PIECE_TAG + _pieces.add(level, anchor, turn, item)]))
	return Validity.KIND_CAN_BUILD


func piece_kind(row: int) -> int:
	"""Pending piece `row`'s validity kind now."""
	return int(_pieces.row_judgement(row)[0])


func piece_reason(row: int) -> String:
	"""Why pending piece `row` cannot be built ("" when it can)."""
	return String(_pieces.row_judgement(row)[1])


func first_invalid_piece() -> int:
	"""The first pending piece that holds Confirm all back; -1 when none."""
	for row: int in _pieces.count():
		if _pieces.is_live(row) and piece_kind(row) != Validity.KIND_CAN_BUILD:
			return row
	return -1


# --- Mound homes (decision 2002) -------------------------------------------------------------------------------------

func _is_mound_op(k: int) -> bool:
	"""Whether operation `k` is a pending Mound room on the Surface."""
	return _styles[k] == Mound.STYLE_MOUND and _levels[k] == Mound.SURFACE and _counts[k] > 0


func operation_style(k: int) -> int:
	"""Operation `k`'s style (build_mound.gd STYLE_*)."""
	return _styles[k]


func _host_cells() -> PackedInt32Array:
	"""The host's confirmed Mound room cells (pairs; none with no host)."""
	return PackedInt32Array(_host_mound_cells.call()) if _host_mound_cells.is_valid() else PackedInt32Array()


func _mound_cache() -> void:
	"""The Surface's Mound room cells (pending and confirmed), their lookup, the hill's footprint and each Mound's
	refusal by cell, worked out once per layout."""
	_sync_ground()
	if _mound_seen == _layout:
		return
	_mound_seen = _layout
	_mound_cells = _host_cells()
	for k: int in _drafts.size():
		if _is_mound_op(k):
			_mound_cells.append_array(_drafts[k].visible_cells())
	_mound_lookup = Mound.set_of(_mound_cells)
	Mound.footprint_into(_mound_cells, _mound_footprint)
	_hill_words.clear()
	for group: PackedInt32Array in Mound.components(_mound_cells):
		var words: String = _hill_refusal(group)
		for at: int in range(0, group.size(), 2):
			_hill_words[Vector2i(group[at], group[at + 1])] = words


func mound_cells() -> PackedInt32Array:
	"""Every Mound room cell on the Surface, pending and confirmed (pairs; read only)."""
	_mound_cache()
	return _mound_cells


func is_mound_room(level: int, cell: Vector2i) -> bool:
	"""Whether `cell` on `level` is a Mound room's, pending or confirmed."""
	return _mound_room_at(level, cell)


func is_surface_room(cell: Vector2i) -> bool:
	"""Whether `cell` on the Surface is a Mound room's, pending or confirmed (an `is_room` reader, build_mound.gd)."""
	return _mound_room_at(Mound.SURFACE, cell)


func _mound_room_at(level: int, cell: Vector2i) -> bool:
	"""build_mound_edges.gd's room reader: whether `cell` is a Mound room's, pending or confirmed."""
	if level != Mound.SURFACE:
		return false
	_mound_cache()
	return _mound_lookup.has(cell)


func _listed_edges(kind: int) -> Array:
	"""build_mound_edges.gd's list reader: the host's confirmed doors or windows (first edges)."""
	return _host_listed.call(kind) if _host_listed.is_valid() else []


func _confirmed_edge(level: int, edge: Vector3i) -> Vector4i:
	"""build_mound_edges.gd's confirmed reader, through the host (none with no host)."""
	return Vector4i(_host_edges.call(level, edge)) if _host_edges.is_valid() else MoundEdges.NONE


func _hill_refusal(rooms: PackedInt32Array) -> String:
	"""Why one Mound's hill -- `rooms` and its berm -- cannot stand where it is (BUILD-MOUND-008; "" when it can)."""
	var lookup: Dictionary = Mound.set_of(rooms)
	var footprint: Dictionary = {}
	Mound.footprint_into(rooms, footprint)
	for cell: Vector2i in lookup.keys() + footprint.keys():
		var thing: String = String(_host_surface.call(cell)) if _host_surface.is_valid() else ""
		if not thing.is_empty():
			return Mound.hill_covers(thing)
	for cells: PackedInt32Array in _way_footprints(Mound.SURFACE):
		if not _way_clear_of(cells, lookup, footprint).is_empty():
			return Mound.hill_covers("an %s" % Items.name_of(Mound.SURFACE))
	return ""


static func _way_clear_of(cells: PackedInt32Array, rooms: Dictionary, footprint: Dictionary) -> String:
	"""Why a way down on `cells` cannot stand with a hill of `rooms` and `footprint` ("" when it stands wholly on the
	rooms' floor or wholly off the hill): across a room's edge, or on the hill."""
	var on_rooms: int = 0
	var on_hill: int = 0
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		on_rooms += 1 if rooms.has(cell) else 0
		on_hill += 1 if footprint.has(cell) else 0
	if on_rooms > 0 and on_rooms * 2 < cells.size():
		return Mound.TEXT_SPLIT_WAY
	return Mound.TEXT_ON_HILL if on_hill > 0 else ""


func _way_footprints(level: int) -> Array[PackedInt32Array]:
	"""The standing cells of every way standing on `level`, pending and confirmed, one set each (decision 2021: by
	family; a host with no shape reader gives its ways' north-west cells, each a 2 × 2 as decision 2002 had them)."""
	var out: Array[PackedInt32Array] = []
	for row: int in _items.count():
		if _items.is_live(row) and not _items.is_removal(row) and _items.level_of(row) == level:
			out.append(_items.standing(row))
	if _host_shapes.is_valid():
		var shapes: PackedInt32Array = _shapes_on(level)
		for at: int in range(0, shapes.size(), 4):
			out.append(Families.standing_cells(shapes[at + 2], shapes[at + 3], Vector2i(shapes[at], shapes[at + 1])))
	elif _host_ways.is_valid():
		var tops: PackedInt32Array = PackedInt32Array(_host_ways.call(level))
		for at: int in range(0, tops.size(), 2):
			out.append(Items.footprint(Vector2i(tops[at], tops[at + 1])))
	return out


func _judge_hill(union: PackedInt32Array) -> void:
	"""A Mound stroke's hill (BUILD-MOUND-008) and the doors and windows it would bury (BUILD-MOUND-018): "X"."""
	if _stroke_style != Mound.STYLE_MOUND or _stroke_kind == Validity.KIND_NOT_POSSIBLE:
		return
	var refusal: String = _beside_edge_items(union)
	if refusal.is_empty():
		refusal = _hill_refusal(_joined_mound(union))
	if not refusal.is_empty():
		_set_stroke(Validity.KIND_NOT_POSSIBLE, refusal)


func _joined_mound(union: PackedInt32Array) -> PackedInt32Array:
	"""The Mound the stroke's room would stand in: the union and every Mound room it joins cell to cell."""
	var rooms: PackedInt32Array = union.duplicate()
	rooms.append_array(_host_cells())
	for k: int in _drafts.size():
		if _is_mound_op(k) and not _targets.has(k):
			rooms.append_array(_drafts[k].visible_cells())
	var mine: Dictionary = Mound.set_of(union)
	var out: PackedInt32Array = PackedInt32Array()
	for group: PackedInt32Array in Mound.components(rooms):
		if _group_has(group, mine):
			out.append_array(group)
	return out


func _beside_edge_items(cells: PackedInt32Array) -> String:
	"""Why Mound room `cells` cannot stand by the doors and windows ("" when they can): over a confirmed one's slope
	(BUILD-MOUND-018's stand-in), or in or beside the yard of a door that will stand (its walls would open onto it)."""
	var buried: String = _buried_edge_item(cells)
	if not buried.is_empty():
		return buried
	var mine: Dictionary = Mound.set_of(cells)
	for door: Vector3i in _edges.placed(Mound.SURFACE, Mound.KIND_DOOR, -1):
		if _group_has(Mound.yard_keep(Mound.cell_of(door), door.z), mine):
			return Mound.TEXT_IN_YARD
	return ""


func _buried_edge_item(union: PackedInt32Array) -> String:
	"""The words for a confirmed door or window whose outer edge the stroke would make an inner one ("" for none)."""
	for at: int in range(0, union.size(), 2):
		var cell: Vector2i = Vector2i(union[at], union[at + 1])
		for side: int in Mound.SIDES:
			var beside: Vector2i = cell + Mound.step_of(side)
			var there: Vector4i = _edges.confirmed_at(Mound.SURFACE, Vector3i(beside.x, beside.y, posmod(side + 2, 4)))
			if there.x >= 0:
				return Mound.covers_edge_item(there.x)
	return ""


func _mark_doorless(sets: Array[PackedInt32Array], styles: PackedByteArray, judged: Array[PackedByteArray]) -> void:
	"""BUILD-MOUND-012: every cell CELL_OK of a Mound set whose Mound (its rooms joined cell to cell, with the confirmed
	ones) has no door that can be built becomes CELL_NO_DOOR."""
	var rooms: PackedInt32Array = _host_cells()
	for at: int in sets.size():
		if styles[at] == Mound.STYLE_MOUND:
			rooms.append_array(sets[at])
	var doors: Dictionary = _door_cells()
	var doorless: Dictionary = {}
	for group: PackedInt32Array in Mound.components(rooms):
		if not _group_has(group, doors):
			for at: int in range(0, group.size(), 2):
				doorless[Vector2i(group[at], group[at + 1])] = true
	for at: int in sets.size():
		if styles[at] == Mound.STYLE_MOUND:
			_mark_cells(sets[at], judged[at], doorless)


static func _mark_cells(cells: PackedInt32Array, codes: PackedByteArray, doorless: Dictionary) -> void:
	"""Each CELL_OK cell of `cells` in `doorless` marked CELL_NO_DOOR."""
	for at: int in range(0, cells.size(), 2):
		@warning_ignore("integer_division") var slot: int = at / 2
		if codes[slot] == Cells.CELL_OK and doorless.has(Vector2i(cells[at], cells[at + 1])):
			codes[slot] = Cells.CELL_NO_DOOR


static func _group_has(group: PackedInt32Array, cells: Dictionary) -> bool:
	"""Whether a cell of `group` (pairs) is in `cells`."""
	for at: int in range(0, group.size(), 2):
		if cells.has(Vector2i(group[at], group[at + 1])):
			return true
	return false


func _door_cells() -> Dictionary:
	"""The first cells of the doors a Mound will have: the pending ones that can be built, and the confirmed ones no
	pending removal takes away."""
	var out: Dictionary = {}
	var pending: PackedInt32Array = PackedInt32Array()
	_edges.doors_into(Mound.SURFACE, pending)
	for at: int in range(0, pending.size(), 2):
		out[Vector2i(pending[at], pending[at + 1])] = true
	var confirmed: Array = _host_doors.call() if _host_doors.is_valid() else []
	for edge: Vector3i in confirmed:
		if not _edges.removed(Mound.SURFACE, edge):
			out[Vector2i(edge.x, edge.y)] = true
	return out


func host_changed() -> void:
	"""The host's confirmed Mounds, doors or windows changed: every level is judged again when read."""
	_changed()


func mound_edges() -> MoundEdges:
	"""The pending doors and windows (read only for hosts: drawing, the ledger, checks)."""
	return _edges


func toggle_mound_edge(level: int, cell: Vector2i, side: int, kind: int, colour: int) -> int:
	"""A click with a door or window armed on `cell`'s `side` (one step each): a pending door or window there is taken
	back, a pending removal there is withdrawn, a confirmed one there is marked for removal, else `kind` is placed (an
	"X" one dropped with its words in `last_dropped`). Returns the validity kind, or -1 with a stroke in progress or no
	planning area."""
	if _catalog == null or _stroke.active():
		return -1
	var edge: Vector3i = Vector3i(cell.x, cell.y, posmod(side, Mound.SIDES))
	_last_dropped = ""
	for removals: bool in [false, true]:
		var row: int = _edges.row_at(level, edge, removals)
		if row >= 0:
			_edges.set_live(row, false)
			_record(PackedInt32Array([VERB_REMOVE, MOUND_TAG + row]))
			return Validity.KIND_CAN_BUILD
	var there: Vector4i = _edges.confirmed_at(level, edge)
	if there.x >= 0 and _door_cuts_off(there):
		return Validity.KIND_NOT_POSSIBLE
	if there.x >= 0:
		var removal: int = _edges.add(level, Vector2i(there.y, there.z), there.w, there.x, Mound.COLOUR_OAK, true)
		_record(PackedInt32Array([VERB_PLACE, MOUND_TAG + removal]))
		return Validity.KIND_CAN_BUILD
	return _place_mound_edge(level, cell, side, kind, colour)


func _door_cuts_off(there: Vector4i) -> bool:
	"""Whether removing the confirmed door `there` (kind, x, z, side), with the pending removals, would cut something
	off (BUILD-REQ-017): then the click is dropped with the names in `last_dropped`. A window cuts nothing off."""
	if there.x != Mound.KIND_DOOR:
		return false
	var names: String = _cut_off_text(PackedInt32Array(), [Vector3i(there.y, there.z, there.w)])
	if names.is_empty():
		return false
	_last_dropped = Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.cut_off(names))
	revision += 1
	return true


func _place_mound_edge(level: int, cell: Vector2i, side: int, kind: int, colour: int) -> int:
	"""Place a new door or window: one step, or "X" dropped with its words kept."""
	var judged: Array = _edges.judge(level, cell, side, kind, -1)
	if int(judged[0]) != Validity.KIND_CAN_BUILD:
		_last_dropped = Validity.line(int(judged[0]), String(judged[1]))
		revision += 1
		return int(judged[0])
	_record(PackedInt32Array([VERB_PLACE, MOUND_TAG + _edges.add(level, cell, side, kind, colour, false)]))
	return Validity.KIND_CAN_BUILD


func edge_kind(row: int) -> int:
	"""Pending door or window `row`'s validity kind now."""
	return int(_edge_judgement(row)[0])


func edge_reason(row: int) -> String:
	"""Why pending door or window `row` cannot be built ("" when it can)."""
	return String(_edge_judgement(row)[1])


func _edge_judgement(row: int) -> Array:
	"""build_mound_edges.gd's judgement, and for a front door's removal BUILD-REQ-017's: "X" while the pending removals
	together would cut something off (decision 2021, P-D1-6 (a))."""
	var judged: Array = _edges.row_judgement(row)
	if int(judged[0]) != Validity.KIND_CAN_BUILD or not _edges.is_removal(row) or _edges.kind_of(row) != Mound.KIND_DOOR:
		return judged
	var names: String = _cut_off_now()
	return [Validity.KIND_NOT_POSSIBLE, Validity.cut_off(names)] if not names.is_empty() else judged


func first_invalid_edge() -> int:
	"""The first pending door or window that holds Confirm all back; -1 when none."""
	for row: int in _edges.count():
		if _edges.is_live(row) and edge_kind(row) != Validity.KIND_CAN_BUILD:
			return row
	return -1


func last_step_words() -> String:
	"""The newest step in words ("Place Front door", "Remove Window"; "" with none)."""
	return _step_words(_undo[_undo.size() - 1]) if not _undo.is_empty() else ""


# --- the operations ------------------------------------------------------------------------------------------------

func _new_operation(room_type: int, level: int, style: int = Mound.STYLE_BUILT) -> int:
	"""Append an empty operation (its own planner draft) of `style`; its index, or -1 if the planner refuses it."""
	var draft: Draft = Draft.new()
	if draft.configure(room_type, level, PITCH_U, _capacity, _bounds, false) != &"":
		return -1
	_drafts.append(draft)
	_types.append(room_type)
	_styles.append(style)
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
		_replay(step[at], step[0] == VERB_REMOVE)
	_redo.append(step)
	_changed()
	return true


func redo() -> bool:
	"""Redo the last undone batch step; false when there is none (any new stroke clears them)."""
	if _redo.is_empty() or _stroke.active():
		return false
	var step: PackedInt32Array = _redo.pop_back()
	for at: int in range(1, step.size()):
		_replay(step[at], step[0] != VERB_REMOVE)
	_undo.append(step)
	_changed()
	return true


func _replay(entry: int, forward: bool) -> void:
	"""One step entry undone (`forward` false) or redone: an operation's draft, a way down's, a piece's or a door's or
	window's placement (`forward`: live; a taken-back door's step passes it the other way round)."""
	if entry >= MOUND_TAG:
		_edges.set_live(entry - MOUND_TAG, forward)
		return
	if entry >= PIECE_TAG:
		_pieces.set_live(entry - PIECE_TAG, forward)
		return
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
	"""A step in words: its verb and its first operation's room type ("Paint Kitchen"), the way down ("Place
	Entrance"), the piece ("Place Hearth") or the door or window ("Place Front door", "Remove Window")."""
	if step[1] >= MOUND_TAG:
		var row: int = step[1] - MOUND_TAG
		var verb: int = VERB_REMOVE if _edges.is_removal(row) else step[0]
		return "%s %s" % [VERBS[verb], Mound.kind_name(_edges.kind_of(row))]
	if step[1] >= PIECE_TAG:
		return "%s %s" % [VERBS[step[0]], Furniture.name_of(_pieces.item_of(step[1] - PIECE_TAG))]
	if step[1] >= ITEM_TAG:
		var item: int = step[1] - ITEM_TAG
		if _items.is_removal(item):
			return "%s %s" % ["Keep" if step[0] == VERB_REMOVE else VERBS[VERB_REMOVE], _items.name_of_row(item)]
		return "%s %s" % [VERBS[step[0]], _items.name_of_row(item)]
	return "%s %s" % [VERBS[step[0]], BuildCatalog.type_name(_types[step[1]])]


func history_size() -> int:
	"""How many batch steps Undo and Redo hold together (never more than HISTORY_LIMIT)."""
	return _undo.size() + _redo.size()


func discard_all() -> int:
	"""Drop every operation, the stroke and the history; returns how many pending changes were dropped."""
	var dropped: int = pending_count()
	_stroke.clear()
	_types.clear()
	_styles.clear()
	_edges.clear()
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
	_pieces.clear()
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
	_styles = _picked_bytes(_styles, keep)
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


static func _picked_bytes(column: PackedByteArray, keep: PackedInt32Array) -> PackedByteArray:
	"""The entries of `column` at the indices in `keep`, in order (a new array)."""
	var out: PackedByteArray = PackedByteArray()
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
	"""How many changes would be ordered: rooms with at least one cell, pending ways down, pieces, doors and
	windows."""
	var count: int = _items.live_count() + _pieces.live_count() + _edges.live_count()
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
	"""How many pending changes hold Confirm all back (BUILD-REQ-021; see `first_invalid`), ways down and pieces
	included."""
	var count: int = 0
	for row: int in _edges.count():
		if _edges.is_live(row) and edge_kind(row) != Validity.KIND_CAN_BUILD:
			count += 1
	for row: int in _pieces.count():
		if _pieces.is_live(row) and piece_kind(row) != Validity.KIND_CAN_BUILD:
			count += 1
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
	var hill: String = _op_hill(k)
	if dug >= 0 or narrow >= 0:
		_set_judgement(k, Validity.KIND_NOT_POSSIBLE, Cells.words_of(_codes[k][dug if dug >= 0 else narrow]))
	elif not hill.is_empty():
		_set_judgement(k, Validity.KIND_NOT_POSSIBLE, hill)
	elif draft.confirmation_error() != &"":
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.shape(shape_words(draft.confirmation_error())))
	elif _counts[k] < least:
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.too_small(BuildCatalog.type_name(_types[k]), least, _counts[k]))
	elif _codes[k].has(Cells.CELL_NO_WAY_IN):
		_set_judgement(k, Validity.KIND_BLOCKED, Validity.no_way_in())
	elif _codes[k].has(Cells.CELL_NO_DOOR):
		_set_judgement(k, Validity.KIND_BLOCKED, Mound.TEXT_NO_DOOR)
	elif _refused_at[k] == draft.revision and not _refusals[k].is_empty():
		_set_judgement(k, _refused_kind[k], _refusals[k])


func _op_hill(k: int) -> String:
	"""A pending Mound room's refusal by its doors and windows (`_beside_edge_items`: a door placed or a removal
	withdrawn since it was painted) or by its hill (BUILD-MOUND-008); "" for none, or for a Built room."""
	if not _is_mound_op(k):
		return ""
	_mound_cache()
	var cells: PackedInt32Array = _drafts[k].visible_cells()
	var beside: String = _beside_edge_items(cells)
	return beside if not beside.is_empty() else String(_hill_words.get(Vector2i(cells[0], cells[1]), ""))


func _judge_level(level: int) -> void:
	"""Every pending operation's cells on `level` judged per cell, once per layout (and ground) revision."""
	_sync_ground()
	if _level_judged.get(level, -1) == _layout:
		return
	_level_judged[level] = _layout
	var ops: PackedInt32Array = PackedInt32Array()
	var sets: Array[PackedInt32Array] = []
	var styles: PackedByteArray = PackedByteArray()
	for k: int in _drafts.size():
		if _levels[k] == level and _counts[k] > 0:
			ops.append(k)
			sets.append(_drafts[k].visible_cells())
			styles.append(_styles[k])
	var judged: Array[PackedByteArray] = _cells.judge_level(level, sets, level != Mound.SURFACE)
	if level == Mound.SURFACE:
		_mark_doorless(sets, styles, judged)
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

func confirm_all(submit: Callable, submit_item: Callable = Callable(), submit_piece: Callable = Callable(),
		submit_edge: Callable = Callable()) -> PackedInt32Array:
	"""BUILD-REQ-019 through the host's order route: first each pending way down or removal (`submit_item(level, cell,
	family, turn, removal) -> Dictionary`; the ways in come first, SET-BUILD-001 §10), then `submit(draft, level, room_type) -> Dictionary` with
	`ok` and `error` (words) for each pending "✓" room in batch order. Ordered changes leave the batch, out of Undo's
	reach; a refused room stays with its reason. Nothing is deducted here. Returns [ordered, refused]; [0, 0] while a
	stroke is in progress or any change is invalid (Confirm all is disabled then). Then each pending piece of
	furniture through `submit_piece(level, anchor, turn, item) -> Dictionary` (decision 1921); last each door, window
	and removal through `submit_edge(level, cell, side, kind, colour, removal) -> Dictionary` (decision 2002)."""
	_cut_at = -1
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
	gone.append_array(_confirm_pieces(submit_piece))
	refused += _pieces.live_count()
	gone.append_array(_confirm_edges(submit_edge))
	refused += _edges.live_count()
	_forget(ordered, gone)
	revision += 1
	return PackedInt32Array([ordered.size() + gone.size(), refused])


func _confirm_items(submit_item: Callable) -> PackedInt32Array:
	"""Each pending removal, then each pending way, through `submit_item` (review H2: a way placed where a removed one
	stood is ordered after the removal); the step entries of those it ordered (no longer pending)."""
	var gone: PackedInt32Array = PackedInt32Array()
	for removals: bool in [true, false]:
		gone.append_array(_confirm_rows(submit_item, removals))
	return gone


func _confirm_rows(submit_item: Callable, removals: bool) -> PackedInt32Array:
	"""The pending removals (or ways) through `submit_item`; the step entries of those it ordered."""
	var gone: PackedInt32Array = PackedInt32Array()
	for row: int in _items.count():
		if not _items.is_live(row) or _items.is_removal(row) != removals or not submit_item.is_valid():
			continue
		var answer: Variant = submit_item.call(_items.level_of(row), _items.cell_of(row), _items.family_of(row),
			_items.turn_of(row), _items.is_removal(row))
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			_items.set_live(row, false)
			gone.append(ITEM_TAG + row)
	return gone


func _confirm_pieces(submit_piece: Callable) -> PackedInt32Array:
	"""Each pending piece through `submit_piece`; the step entries of those it ordered (no longer pending)."""
	var gone: PackedInt32Array = PackedInt32Array()
	for row: int in _pieces.count():
		if not _pieces.is_live(row) or not submit_piece.is_valid():
			continue
		var answer: Variant = submit_piece.call(_pieces.level_of(row), _pieces.anchor_of(row), _pieces.turn_of(row),
			_pieces.item_of(row))
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			_pieces.set_live(row, false)
			gone.append(PIECE_TAG + row)
	return gone


func _confirm_edges(submit_edge: Callable) -> PackedInt32Array:
	"""Each pending door, window and removal through `submit_edge`; the step entries of those it ordered."""
	var gone: PackedInt32Array = PackedInt32Array()
	for row: int in _edges.count():
		if not _edges.is_live(row) or not submit_edge.is_valid():
			continue
		var answer: Variant = submit_edge.call(_edges.level_of(row), _edges.cell_of(row), _edges.side_of(row),
			_edges.kind_of(row), _edges.colour_of(row), _edges.is_removal(row))
		if answer is Dictionary and bool((answer as Dictionary).get("ok", false)):
			_edges.set_live(row, false)
			gone.append(MOUND_TAG + row)
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
	"""Ordered changes are confirmed now: they leave the batch; every step naming one, and every step older than the
	newest such, leaves the history, and Redo is cleared, so Undo/Redo never reach them and never fall out of step
	(BUILD-REQ-020; review H1)."""
	if ordered.is_empty() and items_gone.is_empty():
		return
	for k: int in ordered:
		_drafts[k].discard()
		_counts[k] = 0
	var gone: PackedInt32Array = ordered.duplicate()
	gone.append_array(items_gone)
	_undo = _after_newest(_undo, gone)
	_redo.clear()
	_changed()
	_prune()


static func _after_newest(history: Array[PackedInt32Array], gone: PackedInt32Array) -> Array[PackedInt32Array]:
	"""`history` from just after its newest step naming an ordered change (review H1: a step naming an ordered room may
	also name a kept one, whose own draft history would then fall out of step with the batch's, so nothing older is
	kept either); the whole history when no step names one."""
	var newest: int = -1
	for at: int in history.size():
		if _names_any(history[at], gone):
			newest = at
	return history.slice(newest + 1) if newest >= 0 else history


static func _names_any(step: PackedInt32Array, gone: PackedInt32Array) -> bool:
	"""Whether `step` names an entry in `gone`."""
	for at: int in range(1, step.size()):
		if gone.has(step[at]):
			return true
	return false
