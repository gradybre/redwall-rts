extends RefCounted
## CAMERA BOOKMARKS: four saved views of the village (decision 0801). Ctrl+Shift+1..4 saves the view the camera is
## going to, Shift+1..4 eases back to it (camera_modes.gd reads the keys). PRESENTATION ONLY: a view is the camera's
## centre on the ground, heading, pitch and distance -- floats, never read by the simulation.
##
## THE SESSION'S, NOT THE SAVE'S. The slots are STATIC columns, as the interface scale's and the accessibility settings'
## are (demo_ui_scale.gd, demo_access.gd): they last the session and through Restart demo (the village is laid out the
## same), and are never written to disk -- the demo saves nothing yet, and UI §5 names no bookmark to save.

const SLOTS: int = 4

static var _saved: PackedByteArray = _zeros()
static var _focus_x: PackedFloat32Array = _floats()
static var _focus_z: PackedFloat32Array = _floats()
static var _yaw: PackedFloat32Array = _floats()
static var _pitch: PackedFloat32Array = _floats()
static var _distance: PackedFloat32Array = _floats()


static func _zeros() -> PackedByteArray:
	"""One empty flag per slot."""
	var out := PackedByteArray()
	out.resize(SLOTS)
	return out


static func _floats() -> PackedFloat32Array:
	"""One zero per slot."""
	var out := PackedFloat32Array()
	out.resize(SLOTS)
	return out


static func is_slot(slot: int) -> bool:
	"""Whether `slot` names a bookmark (1..SLOTS, as its key does)."""
	return slot >= 1 and slot <= SLOTS


static func save(slot: int, focus: Vector3, yaw_deg: float, pitch_deg: float, metres: float) -> bool:
	"""Keep a view in `slot` (1..SLOTS); false for a slot that is not one."""
	if not is_slot(slot):
		return false
	var row: int = slot - 1
	_saved[row] = 1
	_focus_x[row] = focus.x
	_focus_z[row] = focus.z
	_yaw[row] = yaw_deg
	_pitch[row] = pitch_deg
	_distance[row] = metres
	return true


static func has(slot: int) -> bool:
	"""Whether `slot` holds a view."""
	return is_slot(slot) and _saved[slot - 1] == 1


static func focus_of(slot: int) -> Vector3:
	"""The saved view's centre on the ground (INF: no view there)."""
	if not has(slot):
		return Vector3.INF
	return Vector3(_focus_x[slot - 1], 0.0, _focus_z[slot - 1])


static func yaw_of(slot: int) -> float:
	"""The saved view's heading, degrees (0.0: no view there)."""
	return float(_yaw[slot - 1]) if has(slot) else 0.0


static func pitch_of(slot: int) -> float:
	"""The saved view's pitch, degrees (0.0: no view there)."""
	return float(_pitch[slot - 1]) if has(slot) else 0.0


static func distance_of(slot: int) -> float:
	"""The saved view's distance, metres (0.0: no view there)."""
	return float(_distance[slot - 1]) if has(slot) else 0.0


static func count() -> int:
	"""How many slots hold a view."""
	return _saved.count(1)


static func clear() -> void:
	"""Forget every view (the checks; the demo itself never does)."""
	_saved.fill(0)
