extends RefCounted
## A burrow home's round front door SWINGS OPEN when a resident comes through it and closes behind it. Decision 0371
## (the underground revamp's P7: the generated burrow door's leaf split from its frame, make_demo_derived_props.py
## `burrow_door_open`). Presentation only: the door stops nobody.
##
## Per room row a door is a HINGE node (room_view.gd builds it: the leaf hung from it, its axis up through the leaf's
## hinged edge) at a point in x, z. A door is wanted open while a resident BELOW -- in the door's cutting, its doorway
## or the room behind it -- stands within REACH_M of that point; it then swings toward OPEN_RAD (inward, away from the
## cutting) and, once nobody is, back to shut, at full swing in SWING_S of demo time either way: paused, it holds.
## The residents below are gathered once a step, so the cost is doors x residents BELOW (none on the surface: a pass
## over a byte array). Nothing is allocated a frame once warm; a row with no door costs a comparison.

## How far open a door swings (rad, inward), how near a resident opens it (m) and how long a full swing takes (s).
const OPEN_RAD: float = 1.45
const REACH_M: float = 1.6
const SWING_S: float = 0.45

var _hinges: Array[Node3D] = []
var _at: PackedVector2Array = PackedVector2Array()
var _angle: PackedFloat32Array = PackedFloat32Array()
## The residents below this step (reused): the doors test only them.
var _below_at: PackedVector2Array = PackedVector2Array()
var _below_count: int = 0


func configure(rows: int) -> void:
	"""Room `rows` rows, none with a door."""
	_hinges.resize(rows)
	_at.resize(rows)
	_angle.resize(rows)


func set_door(row: int, at: Vector2, hinge: Node3D) -> void:
	"""Row `row`'s door: `hinge` (its leaf hung from it) at `at` (x, z), shut."""
	_hinges[row] = hinge
	_at[row] = at
	_angle[row] = 0.0
	hinge.rotation.y = 0.0


func clear(row: int) -> void:
	"""Row `row` has no door (its room was freed or rebuilt)."""
	_hinges[row] = null


func step(positions: PackedVector2Array, below: PackedByteArray, delta_s: float) -> void:
	"""Every door toward open while a resident below (`below[i] == 1`) stands within REACH_M of it, else toward shut,
	by `delta_s` of demo time."""
	var step_rad := OPEN_RAD * delta_s / SWING_S
	_gather(positions, below)
	for row in _hinges.size():
		var hinge := _hinges[row]
		if hinge == null or not is_instance_valid(hinge):
			continue
		var target := OPEN_RAD if _near(_at[row]) else 0.0
		if _angle[row] == target:
			continue
		_angle[row] = move_toward(_angle[row], target, step_rad)
		hinge.rotation.y = _angle[row]


func _gather(positions: PackedVector2Array, below: PackedByteArray) -> void:
	"""Where the residents below stand, the first `_below_count` of `_below_at` (kept: it only ever grows)."""
	_below_count = 0
	if not below.has(1):
		return
	var count := mini(positions.size(), below.size())
	if _below_at.size() < count:
		_below_at.resize(count)
	for i in count:
		if below[i] == 1:
			_below_at[_below_count] = positions[i]
			_below_count += 1


func _near(at: Vector2) -> bool:
	"""Whether a resident gathered below stands within REACH_M of a door at `at`."""
	for k in _below_count:
		if _below_at[k].distance_squared_to(at) <= REACH_M * REACH_M:
			return true
	return false


static func wanted_open(at: Vector2, positions: PackedVector2Array, below: PackedByteArray) -> bool:
	"""Whether a resident below stands within REACH_M of a door at `at`."""
	for i in mini(positions.size(), below.size()):
		if below[i] == 1 and positions[i].distance_squared_to(at) <= REACH_M * REACH_M:
			return true
	return false


func angle(row: int) -> float:
	"""How far row `row`'s door stands open (rad; checks)."""
	return _angle[row]


func has_door(row: int) -> bool:
	"""Whether row `row` has a door (checks)."""
	return _hinges[row] != null and is_instance_valid(_hinges[row])
