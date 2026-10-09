extends RefCounted
## Pure room-drawing session. No graph, inventory, project, or resident references live here.
## Grid pitch and bounds are explicit inputs, never an excavation price or a paid-cut mapping.
## A stroke previews against its original cells, then changes the draft once on release.

const Footprint := preload("res://scripts/core/room_footprint.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const RECTANGLE: int = 0
const ROUNDED: int = 1
const ELLIPSE: int = 2
const BRUSH: int = 3
const TUNNEL: int = 4
const TOOL_COUNT: int = 5
const HISTORY_LIMIT: int = 32
const I32_MAX: int = 2147483647

var revision: int = 0
var visual_revision: int = 0
var topology_checks: int = 0
var _configured: bool = false
var _room_type: int = -1
var _level: int = 0
var _pitch_u: int = 0
var _capacity: int = 0
var _bounds: Rect2i = Rect2i()
var _allow_holes: bool = false
var _cells: PackedInt32Array = PackedInt32Array()
var _preview: PackedInt32Array = PackedInt32Array()
var _path: PackedInt32Array = PackedInt32Array()
var _undo: Array[PackedInt32Array] = []
var _redo: Array[PackedInt32Array] = []
var _drawing: bool = false
var _tool: int = RECTANGLE
var _radius: int = 0
var _erase: bool = false
var _start: Vector2i = Vector2i.ZERO
var _last: Vector2i = Vector2i.ZERO
var _preview_error: StringName = &""
var _checked_revision: int = -1
var _topology_error: StringName = &""


func configure(room_type: int, level: int, pitch_u: int, capacity: int,
		bounds: Rect2i, allow_holes: bool) -> StringName:
	"""Start an empty session; retained work cannot silently change purpose, level or grid."""
	if _drawing or not _cells.is_empty() or not _undo.is_empty() or not _redo.is_empty():
		return &"DISCARD_EXISTING_DRAFT_FIRST"
	if room_type < 0 or room_type >= Catalog.ROOM_TYPE.size() or level < 0 or level > I32_MAX:
		return &"INVALID_ROOM_IDENTITY"
	if pitch_u < 1 or pitch_u > 2048 or 2048 % pitch_u != 0:
		return &"INVALID_PLANNING_GRID"
	if capacity < 1 or capacity > Footprint.MAX_OPERATION_CELLS or not _bounds_fit(bounds, pitch_u):
		return &"INVALID_PLANNING_BOUNDS"
	_room_type = room_type
	_level = level
	_pitch_u = pitch_u
	_capacity = capacity
	_bounds = bounds
	_allow_holes = allow_holes
	_configured = true
	_changed()
	return &""


func begin_stroke(tool: int, at: Vector2i, radius: int, erase: bool) -> StringName:
	"""Start a transient stamp; even a refused stroke never mutates the accepted draft."""
	if not _configured or _drawing:
		return &"DRAWING_SESSION_NOT_READY"
	if tool < 0 or tool >= TOOL_COUNT or radius < 0 or radius > (Footprint.MAX_SHAPE_SPAN >> 1):
		return &"INVALID_DRAWING_TOOL"
	_tool = tool
	_radius = radius
	_erase = erase
	_start = at
	_last = at
	_path = PackedInt32Array([at.x, at.y])
	_drawing = true
	return _update_preview(at)


func extend_stroke(at: Vector2i) -> StringName:
	"""Repeated pointer samples are free; only cell changes regenerate the transient stamp."""
	if not _drawing:
		return &"NO_ACTIVE_STROKE"
	if at == _last:
		return _preview_error
	_last = at
	if _tool == BRUSH or _tool == TUNNEL:
		if _path.size() >= _capacity * 2:
			visual_revision += 1
			_preview_error = &"DRAWING_STROKE_TOO_LONG"
			return _preview_error
		_path.append_array(PackedInt32Array([at.x, at.y]))
	return _update_preview(at)


func finish_stroke() -> StringName:
	"""Commit the whole stroke once; disconnected drafts remain editable but cannot confirm."""
	if not _drawing:
		return &"NO_ACTIVE_STROKE"
	var error: StringName = _preview_error
	_drawing = false
	if error == &"" and _cells != _preview:
		_push(_undo, _cells)
		_redo.clear()
		_cells = _preview.duplicate()
		_changed()
	_preview.clear()
	_path.clear()
	_preview_error = &""
	visual_revision += 1
	return error


func cancel_stroke() -> bool:
	"""Cancel just the current drag, preserving earlier paint and its undo history."""
	if not _drawing:
		return false
	_drawing = false
	_preview.clear()
	_path.clear()
	_preview_error = &""
	visual_revision += 1
	return true


func undo() -> bool:
	"""Undo a completed edit only; an active stroke must first be finished or cancelled."""
	if _drawing or _undo.is_empty():
		return false
	_push(_redo, _cells)
	_cells = _undo.pop_back()
	_changed()
	return true


func redo() -> bool:
	"""Restore a prior completed edit without changing the world's paid work."""
	if _drawing or _redo.is_empty():
		return false
	_push(_undo, _cells)
	_cells = _redo.pop_back()
	_changed()
	return true


func discard() -> void:
	"""Explicitly discard this new-room draft and its history; no authoritative order exists."""
	cancel_stroke()
	_cells.clear()
	_undo.clear()
	_redo.clear()
	_changed()


func confirmation_error() -> StringName:
	"""Cache expensive whole-plan topology per revision; the world owner must still revalidate."""
	if not _configured:
		return &"DRAWING_SESSION_NOT_READY"
	if _drawing:
		return &"FINISH_CURRENT_STROKE"
	if _checked_revision != revision:
		_topology_error = Footprint.validation_error(_cells, _capacity, _allow_holes)
		_checked_revision = revision
		topology_checks += 1
	return _topology_error


func snapshot() -> Dictionary:
	"""Return an isolated preview request, never a claim that excavation or access is authorized."""
	return {"revision": revision, "room_type": _room_type, "level": _level,
		"pitch_u": _pitch_u, "cells": _cells.duplicate(), "allow_holes": _allow_holes}


func grid_domain() -> Dictionary:
	"""Read the exact input domain without copying a growing room footprint on every pointer event."""
	return {"configured": _configured, "level": _level, "pitch_u": _pitch_u, "bounds": _bounds}


func visible_cells() -> PackedInt32Array:
	"""Read the valid transient shape or the retained draft after a refused stroke."""
	return (_preview if _drawing and _preview_error == &"" else _cells).duplicate()


func drawing() -> bool:
	"""Whether a drag is active, including one whose current preview is refused."""
	return _drawing


func preview_error() -> StringName:
	"""Expose a refusal without silently clipping paint to fit the world or capacity."""
	return _preview_error


func _update_preview(at: Vector2i) -> StringName:
	"""Rasterize and combine against the stroke's unchanged starting draft."""
	visual_revision += 1
	var stamp: Dictionary = _stamp(at)
	if not stamp.ok:
		_preview_error = stamp.error
		return _preview_error
	var combined: Dictionary = Footprint.combine(_cells, stamp.cells, _erase, _capacity)
	_preview_error = combined.error
	if combined.ok:
		_preview_error = _inside_bounds(combined.cells)
		if _preview_error == &"":
			_preview = combined.cells
	return _preview_error


func _stamp(at: Vector2i) -> Dictionary:
	"""All tools use the same canonical integer helper, including the connected tunnel path."""
	if _tool == BRUSH or _tool == TUNNEL:
		return Footprint.tunnel_path(_path, _radius, _capacity)
	var x: int = mini(_start.x, at.x)
	var z: int = mini(_start.y, at.y)
	var width: int = absi(int(_start.x) - int(at.x)) + 1
	var depth: int = absi(int(_start.y) - int(at.y)) + 1
	if _tool == ELLIPSE:
		return Footprint.ellipse(x, z, width, depth, _capacity)
	if _tool == ROUNDED:
		@warning_ignore("integer_division") var radius: int = mini(_radius, mini(width, depth) / 2)
		return Footprint.rounded_rectangle(x, z, width, depth, radius, _capacity)
	return Footprint.rectangle(x, z, width, depth, _capacity)


func _inside_bounds(cells: PackedInt32Array) -> StringName:
	"""An out-of-map cell refuses the entire stroke, never trims the requested boundary."""
	for index: int in range(0, cells.size(), 2):
		if not _bounds.has_point(Vector2i(cells[index], cells[index + 1])):
			return &"ROOM_OUTSIDE_PLANNING_BOUNDS"
	return &""


func _changed() -> void:
	"""Invalidate only the changed UI geometry; no frame loop owns this model."""
	revision += 1
	visual_revision += 1
	_checked_revision = -1


static func _push(history: Array[PackedInt32Array], cells: PackedInt32Array) -> void:
	"""Bound one active editor's undo storage independently from simulation room capacities."""
	if history.size() == HISTORY_LIMIT:
		history.pop_front()
	history.append(cells.duplicate())


static func _bounds_fit(bounds: Rect2i, pitch: int) -> bool:
	"""Prove far corners fit int32 world coordinates before Rect2i arithmetic can wrap."""
	if bounds.size.x < 1 or bounds.size.y < 1:
		return false
	var far_x: int = int(bounds.position.x) + int(bounds.size.x)
	var far_z: int = int(bounds.position.y) + int(bounds.size.y)
	if far_x > I32_MAX or far_z > I32_MAX:
		return false
	var corners: PackedInt32Array = PackedInt32Array([bounds.position.x, bounds.position.y, far_x, far_z])
	return Footprint.to_world_corners(corners, pitch, 0, 0).ok
