extends RefCounted
## THE SCALE TEST'S IN-CODE TIMERS (decision 0561). Off by default: an owner holds a `probe` member that is null, and
## only a measuring run (tools/scale_test/scale_test.gd) sets one. With none set the owner runs its ordinary path and
## pays one null check a frame.
##
## A probe adds whole microseconds to named sections over a frame; the harness reads `usec_of` and calls `clear` once
## a frame. Section names are fixed StringNames (no string building in the hot path) and the columns grow only when a
## new section is first seen.

var _index: Dictionary = {}
var _usec: PackedInt64Array = PackedInt64Array()
var _names: Array[StringName] = []


func add(section: StringName, usec: int) -> void:
	"""Add `usec` microseconds to `section` for this frame."""
	var at: int = _index.get(section, -1)
	if at < 0:
		at = _names.size()
		_index[section] = at
		_names.append(section)
		_usec.append(0)
	_usec[at] += usec


func usec_of(section: StringName) -> int:
	"""This frame's microseconds in `section` (0 when it never ran)."""
	var at: int = _index.get(section, -1)
	return _usec[at] if at >= 0 else 0


func sections() -> Array[StringName]:
	"""Every section seen so far, in first-seen order."""
	return _names.duplicate()


func clear() -> void:
	"""Start a new frame: every section back to 0."""
	_usec.fill(0)
