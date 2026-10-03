extends "res://test/framework/test_case.gd"
## These are editor inputs with an explicit synthetic grid; they authorize no physical cut.

const Draft := preload("res://demo/burrow/modular_draft.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const KITCHEN: int = Catalog.ROOM_TYPE["KITCHEN"]


func _session(holes: bool = false) -> Draft:
	"""Create a bounded synthetic editing session."""
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(KITCHEN, 1, 256, 512, Rect2i(-16, -16, 32, 32), holes), &"", "session configured")
	return draft


func _paint(draft: Draft, from: Vector2i, to: Vector2i, erase: bool = false) -> void:
	"""Drive a complete rectangular gesture through the public editing API."""
	assert_equal(draft.begin_stroke(Draft.RECTANGLE, from, 0, erase), &"", "stroke begins")
	assert_equal(draft.extend_stroke(to), &"", "stroke extends")
	assert_equal(draft.finish_stroke(), &"", "stroke finishes")


func test_stroke_is_preview_until_released_and_snapshot_is_isolated() -> void:
	"""Dragging has neither accepted draft cells nor world orders; snapshots cannot edit the draft."""
	var draft: Draft = _session()
	assert_equal(draft.begin_stroke(Draft.RECTANGLE, Vector2i.ZERO, 0, false), &"", "begin")
	draft.extend_stroke(Vector2i(3, 2))
	assert_true(draft.snapshot().cells.is_empty(), "unreleased stroke is not retained paint")
	assert_equal(draft.visible_cells().size(), 24, "preview shows full twelve-cell shape")
	assert_equal(draft.confirmation_error(), &"FINISH_CURRENT_STROKE", "cannot confirm during drag")
	draft.finish_stroke()
	var copy: Dictionary = draft.snapshot()
	copy.cells[0] = 999
	assert_equal(draft.visible_cells()[0], 0, "snapshot cannot change retained cells")
	assert_equal(draft.confirmation_error(), &"", "retained shape validates")


func test_cancel_is_one_layer_and_preserves_earlier_paint() -> void:
	"""Cancelling the second stroke keeps the first blueprint and its undo history."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i(2, 2))
	var before: Dictionary = draft.snapshot()
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(3, 0), 0, false)
	draft.extend_stroke(Vector2i(5, 2))
	assert_true(draft.cancel_stroke(), "active stroke cancelled")
	assert_false(draft.cancel_stroke(), "second escape belongs to host")
	assert_equal(draft.snapshot(), before, "earlier plan and revision retained")


func test_disconnected_draft_can_be_repaired_before_confirmation() -> void:
	"""A temporary gap stays visible and editable; it never becomes a confirmed room."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i.ONE)
	_paint(draft, Vector2i(4, 0), Vector2i(5, 1))
	assert_equal(draft.confirmation_error(), Footprint.REFUSE_DISCONNECTED, "gap blocks confirmation")
	_paint(draft, Vector2i(2, 0), Vector2i(3, 1))
	assert_equal(draft.confirmation_error(), &"", "bridge repairs room")


func test_out_of_bounds_stroke_is_not_partially_kept() -> void:
	"""The editor never silently clips a large room to its map bounds."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i.ONE)
	var before: Dictionary = draft.snapshot()
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(2, 0), 0, false)
	assert_equal(draft.extend_stroke(Vector2i(16, 2)), &"ROOM_OUTSIDE_PLANNING_BOUNDS", "outside rejected")
	assert_equal(draft.preview_error(), &"ROOM_OUTSIDE_PLANNING_BOUNDS", "visible refusal")
	assert_equal(draft.visible_cells(), before.cells, "refusal retains last accepted draft")
	assert_equal(draft.finish_stroke(), &"ROOM_OUTSIDE_PLANNING_BOUNDS", "whole gesture rejected")
	assert_equal(draft.snapshot(), before, "no partial mutation")


func test_undo_redo_and_new_edit_keep_consistent_geometry() -> void:
	"""Undo/redo changes only the draft and a new edit removes the old redo branch."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i(3, 3))
	var original: PackedInt32Array = draft.visible_cells()
	_paint(draft, Vector2i(2, 2), Vector2i(3, 3), true)
	var concave: PackedInt32Array = draft.visible_cells()
	assert_true(draft.undo(), "undo erase")
	assert_equal(draft.visible_cells(), original, "original restored")
	assert_true(draft.redo(), "redo erase")
	assert_equal(draft.visible_cells(), concave, "concave outline restored")
	draft.undo()
	_paint(draft, Vector2i(4, 0), Vector2i(4, 1))
	assert_false(draft.redo(), "new edit replaces redo branch")


func test_topology_is_cached_and_not_recomputed_for_pointer_motion() -> void:
	"""Expensive whole-room topology runs once per completed revision, never per HUD refresh."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i(5, 5))
	for query: int in 100:
		assert_equal(draft.confirmation_error(), &"", "cached valid shape")
	assert_equal(draft.topology_checks, 1, "one topology computation")
	draft.begin_stroke(Draft.BRUSH, Vector2i(6, 0), 1, false)
	var rev: int = draft.revision
	var visual: int = draft.visual_revision
	for sample: int in 20:
		draft.extend_stroke(Vector2i(6, 0))
		draft.confirmation_error()
	assert_equal(draft.revision, rev, "pointer samples create no committed revisions")
	assert_equal(draft.visual_revision, visual, "identical pointer does not invalidate rendered shape")
	assert_equal(draft.topology_checks, 1, "active stroke does not flood topology")
	draft.finish_stroke()
	draft.confirmation_error()
	assert_equal(draft.topology_checks, 2, "new completed revision invalidates cache once")


func test_preview_has_its_own_revision_for_cached_world_renderers() -> void:
	"""A moving stroke invalidates its overlay without pretending committed geometry changed."""
	var draft: Draft = _session()
	draft.begin_stroke(Draft.RECTANGLE, Vector2i.ZERO, 0, false)
	var committed: int = draft.revision
	var visual: int = draft.visual_revision
	draft.extend_stroke(Vector2i(4, 3))
	assert_equal(draft.revision, committed, "authoring revision stays unchanged during gesture")
	assert_true(draft.visual_revision > visual, "world overlay receives a new revision")
	visual = draft.visual_revision
	draft.cancel_stroke()
	assert_true(draft.visual_revision > visual, "cancel redraws retained cells")


func test_organic_tools_and_bent_tunnel_share_one_retained_plan() -> void:
	"""Long ovals, rounded rectangles and routes are not fixed circle templates."""
	for tool: int in [Draft.ROUNDED, Draft.ELLIPSE]:
		var draft: Draft = _session()
		draft.begin_stroke(tool, Vector2i.ZERO, 2, false)
		draft.extend_stroke(Vector2i(9, 3))
		assert_equal(draft.finish_stroke(), &"", "organic shape retained")
		assert_equal(draft.confirmation_error(), &"", "organic shape connected")
		assert_true(draft.visible_cells().size() < 80, "corners round inside rectangular extent")
	var tunnel: Draft = _session()
	tunnel.begin_stroke(Draft.TUNNEL, Vector2i.ZERO, 1, false)
	tunnel.extend_stroke(Vector2i(5, 0))
	tunnel.extend_stroke(Vector2i(5, 5))
	assert_equal(tunnel.finish_stroke(), &"", "bent tunnel retained")
	assert_true(Footprint.contains_cell(tunnel.visible_cells(), 5, 4), "route reaches its second leg")
	assert_false(Footprint.contains_cell(tunnel.visible_cells(), 0, 5), "route does not fill bounding box")


func test_holes_are_explicit_and_erasing_everything_never_confirms() -> void:
	"""The caller's geometry policy controls solid islands; an empty shell is not zero area."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i(4, 4))
	_paint(draft, Vector2i(2, 2), Vector2i(2, 2), true)
	assert_equal(draft.confirmation_error(), Footprint.REFUSE_HOLES, "island blocked by explicit policy")
	draft.discard()
	assert_equal(draft.confirmation_error(), Footprint.REFUSE_EMPTY, "discard leaves no orderable room")
	assert_false(draft.undo(), "explicit discard clears history")


func test_reconfigure_cannot_relabel_retained_room_or_level() -> void:
	"""Room purpose/grid cannot change beneath an existing blueprint."""
	var draft: Draft = _session()
	_paint(draft, Vector2i.ZERO, Vector2i.ONE)
	var before: Dictionary = draft.snapshot()
	assert_equal(draft.configure(0, 2, 512, 512, Rect2i(-16, -16, 32, 32), false),
		&"DISCARD_EXISTING_DRAFT_FIRST", "existing blueprint retained")
	assert_equal(draft.snapshot(), before, "identity and geometry unchanged")
	draft.discard()
	assert_equal(draft.configure(0, 2, 512, 512, Rect2i(-16, -16, 32, 32), false), &"", "new draft allowed")


func test_bad_grid_bounds_tool_and_capacity_fail_closed() -> void:
	"""Scalar and world-coordinate errors do not turn into clipped or wrapped rooms."""
	var draft: Draft = Draft.new()
	assert_equal(draft.confirmation_error(), &"DRAWING_SESSION_NOT_READY", "unconfigured")
	assert_equal(draft.configure(KITCHEN, 1, 255, 512, Rect2i(0, 0, 8, 8), false), &"INVALID_PLANNING_GRID", "catalog grid exact")
	assert_equal(draft.configure(KITCHEN, 1, 256, 512, Rect2i(2147483640, 0, 32, 32), false),
		&"INVALID_PLANNING_BOUNDS", "far corner cannot wrap")
	draft = _session()
	assert_equal(draft.begin_stroke(99, Vector2i.ZERO, 0, false), &"INVALID_DRAWING_TOOL", "unknown tool")
	assert_false(draft.drawing(), "invalid tool starts no stroke")
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(-16, -16), 0, false)
	assert_equal(draft.extend_stroke(Vector2i(15, 15)), Footprint.REFUSE_CAPACITY, "oversize refused")
	assert_equal(draft.finish_stroke(), Footprint.REFUSE_CAPACITY, "no partial paint")
	assert_true(draft.visible_cells().is_empty(), "draft stays empty")
