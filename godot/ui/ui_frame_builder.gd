extends Control
## Dresses one container panel in its eight-piece frame. One call, and it keeps following.
##
## This script is BOTH the entry point and the holder node it creates: `apply()` is static and
## instantiates this script as a child of the panel, so the shell owner writes one line and
## never touches geometry:
##
##     UiFrameBuilder.apply(panel, UiFrameBuilder.FRAME_RESOURCE_TRAY)
##
## `ui_frame_geometry.gd` owns where the pieces go and why; read its header for the meaning of
## the declared insets and corner extents.
##
## ---------------------------------------------------------------------------------------
## WHY THIS PLACES PIECES EXPLICITLY INSTEAD OF USING ANCHORS OR LAYOUT PRESETS.
##
## Two measured facts about Godot 4.7.2 make the obvious anchor-based version silently wrong
## in exactly the configuration this project builds UI in:
##
##  1. `Control.get_parent_anchorable_rect()` returns an EMPTY rect while the control is not
##     inside a SceneTree, so anchors resolve against a zero-sized parent. The shell is built
##     off-tree on purpose (`test_ui_shell.gd` says so), and the headless runner executes every
##     suite inside `SceneTree._initialize()`, where even `root.add_child()` leaves
##     `is_inside_tree()` false. An anchored frame measures zero in both. Probed, not assumed.
##  2. `set_anchors_and_offsets_preset(..., PRESET_MODE_MINSIZE)` sizes from `get_minimum_size()`
##     and NOT from `get_combined_minimum_size()`, so `custom_minimum_size` is invisible to it.
##     Every offset it writes is then 0, the piece becomes a zero-sized rect pinned exactly ON
##     its anchor line, and Control's later minimum-size enforcement inflates it outward along
##     `grow_horizontal`/`grow_vertical` (both GROW_DIRECTION_END by default). That is what puts
##     the right and bottom corners wholly OUTSIDE the panel and leaves the strips invisible.
##
## So every piece here has default anchors and an explicit `position`/`size` taken from
## `ui_frame_geometry.gd`. Nothing depends on a layout pass, a tree, or a frame boundary, which
## is also what lets the suite assert the built rectangles synchronously.
##
## The holder follows the panel through `Control.resized`, so a panel re-laid-out for another
## responsive profile keeps a correct frame without a second `apply()`. One caveat, measured:
## `Control.set_size()` only runs `_size_changed()` while the control is inside a tree, so
## `resized` does NOT fire off-tree and therefore never fires under `--script` at all. The
## suite drives the same chain by issuing `NOTIFICATION_RESIZED` itself, which is what the
## engine does in a live tree, and `refresh()` is the explicit door for any caller that
## resizes a panel off-tree and wants the frame brought up to date there and then.
##
## ART-UI-07/08: holder and pieces take MOUSE_FILTER_IGNORE, FOCUS_NONE and an empty
## accessibility name, so ornament can never take a click, a tab stop or an announcement.

const Geometry := preload("res://ui/ui_frame_geometry.gd")

## Loaded at runtime rather than preloaded: a script cannot `preload` itself without a cyclic
## reference, and `apply()` is static so it has no instance to clone.
const BUILDER_PATH: String = "res://ui/ui_frame_builder.gd"

## The holder's node name. `panel.get_node_or_null(HOLDER_NAME)` finds an applied frame.
const HOLDER_NAME: String = "FrameArt"

const FRAME_RESOURCE_TRAY: int = 0
const FRAME_TIME_GROUP: int = 1
const FRAME_MAP_FOLIO: int = 2
const FRAME_JOURNAL: int = 3
const FRAME_COMMAND_DOCK: int = 4

const REFUSE_NULL_PANEL: StringName = &"UI_FRAME_NULL_PANEL"
const REFUSE_UNREADABLE_PIECE: StringName = &"UI_FRAME_UNREADABLE_PIECE"

var _frame: int = 0
var _rects: Array[Rect2] = []


static func apply(panel: Control, frame: int) -> bool:
	"""Dress `panel` in silhouette `frame`. Returns false, having built nothing, on refusal.

	Refuses an unknown frame, a null panel, a panel too small for its own corners and a piece
	whose source will not load. `Geometry.refusal_for()` names the first two cases for a caller
	that wants to report them; the last is pushed as an error because the art registry's own
	suite already guarantees every source exists.
	"""
	if panel == null:
		push_error("ui_frame_builder: %s" % REFUSE_NULL_PANEL)
		return false
	var refusal: StringName = Geometry.refusal_for(frame, panel.size)
	if refusal != Geometry.REFUSE_NONE:
		push_error("ui_frame_builder: %s for frame %d at %v" % [refusal, frame, panel.size])
		return false
	_clear_existing(panel)
	var holder: Control = (load(BUILDER_PATH) as GDScript).new() as Control
	holder.name = HOLDER_NAME
	_make_decorative(holder)
	panel.add_child(holder)
	if not holder.call("_build", frame):
		panel.remove_child(holder)
		holder.free()
		return false
	panel.resized.connect(Callable(holder, "_follow_panel"))
	return true


static func has_frame(panel: Control) -> bool:
	"""True when this panel already carries an applied frame."""
	return panel != null and panel.get_node_or_null(NodePath(HOLDER_NAME)) != null


static func refresh(panel: Control) -> bool:
	"""Re-place an applied frame against the panel's current size. False when none is applied.

	Only needed off-tree, where `Control.resized` never fires. A panel inside a live tree is
	followed automatically and does not need this.
	"""
	if not has_frame(panel):
		return false
	panel.get_node(NodePath(HOLDER_NAME)).call("_follow_panel")
	return true


static func _clear_existing(panel: Control) -> void:
	"""Drop a previously applied frame so `apply()` is idempotent rather than cumulative."""
	var existing: Node = panel.get_node_or_null(NodePath(HOLDER_NAME))
	if existing == null:
		return
	panel.remove_child(existing)
	existing.free()


static func _make_decorative(control: Control) -> void:
	"""ART-UI-07/08: no click, no focus, no accessibility node, for holder and piece alike."""
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
	control.accessibility_name = ""


func _build(frame: int) -> bool:
	"""Create the eight pieces once. Returns false if any source will not load."""
	_frame = frame
	_rects.resize(Geometry.PIECE_COUNT)
	size = _panel_size()
	for piece: int in Geometry.PIECE_COUNT:
		var texture: Texture2D = load(Geometry.source_path_of(frame, piece)) as Texture2D
		if texture == null:
			push_error("ui_frame_builder: %s %s"
				% [REFUSE_UNREADABLE_PIECE, Geometry.source_path_of(frame, piece)])
			return false
		var piece_rect: TextureRect = TextureRect.new()
		piece_rect.name = Geometry.PIECE_NAMES[piece]
		piece_rect.texture = texture
		piece_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_make_decorative(piece_rect)
		add_child(piece_rect)
	_place()
	return true


func _panel_size() -> Vector2:
	"""The owning panel's current size, or this holder's own when it has no Control parent."""
	var panel: Control = get_parent() as Control
	if panel == null:
		return size
	return panel.size


func _follow_panel() -> void:
	"""Track the panel through a responsive relayout. Bound to the panel's `resized` signal."""
	size = _panel_size()
	_place()


func _notification(what: int) -> void:
	"""Re-place the pieces whenever this holder's own rectangle changes."""
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	"""Write every piece's rectangle, or hide the whole frame when the panel got too small.

	Hiding rather than clamping keeps ART-UI-07 true at every size: a clamped frame would put
	the left and right corners on top of one another and still report itself as applied.
	"""
	if get_child_count() < Geometry.PIECE_COUNT:
		return
	if not Geometry.rects_into(_frame, size, _rects):
		visible = false
		return
	visible = true
	for piece: int in Geometry.PIECE_COUNT:
		var piece_rect: Control = get_child(piece) as Control
		piece_rect.position = _rects[piece].position
		piece_rect.size = _rects[piece].size
