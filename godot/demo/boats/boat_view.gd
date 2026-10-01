extends Node3D
## THE BOAT CORE's drawing: every boat row as the staged rowboat (its placeholder box unstaged), where boat_fleet.gd
## says it is, bobbing a little on the water. Decision 0432 (live demo). Presentation only: it reads the rows and writes
## nothing. One MeshInstance3D a boat, made once; each frame only their transforms move (no allocation per frame).

const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const BOAT_KEY: StringName = &"boat_rowboat"
## The hull's base below the datum when afloat (water_dressing.gd's measured float: a third up the hull).
const BASE_Y_M: float = -0.48
## A gentle bob (m, rad/s) and a roll under oars (rad): presentation.
const BOB_M: float = 0.025
const BOB_RATE: float = 1.7
const ROLL_RAD: float = 0.03

var _fleet: FleetScript = null
var _props: PropsScript = null
var _boats: Array[MeshInstance3D] = []
var _clock_s: float = 0.0


func configure(fleet: FleetScript, props: PropsScript) -> void:
	"""Draw `fleet`'s boats with `props`' rowboat (a fresh, unstaged table when none)."""
	name = "BoatView"
	_fleet = fleet
	_props = props if props != null else PropsScript.new()
	for boat: int in fleet.count:
		var mesh: MeshInstance3D = _props.instance(BOAT_KEY)
		mesh.name = "Boat%d" % (boat + 1)
		add_child(mesh)
		_boats.append(mesh)
	refresh(0.0)


func refresh(delta_s: float) -> void:
	"""Every boat at its place and heading, `delta_s` demo seconds on (paused, the bob holds too) (the model's +X along the bow: Basis(UP, atan2(-dz, dx)))."""
	_clock_s += delta_s
	for boat: int in _boats.size():
		var at: Vector2 = _fleet.position_m(boat)
		var yaw: float = _fleet.yaw(boat)
		var heading := Vector2(sin(yaw), cos(yaw))
		var bob: float = BOB_M * sin(_clock_s * BOB_RATE + float(boat) * 1.9)
		var roll: float = ROLL_RAD * sin(_clock_s * 3.1) if _fleet.moving(boat) else 0.0
		var basis := Basis(Vector3.UP, atan2(-heading.y, heading.x)) * Basis(Vector3.RIGHT, roll)
		_boats[boat].transform = Transform3D(basis, Vector3(at.x, BASE_Y_M + bob, at.y)) * _props.fit_of(BOAT_KEY)


func boat_node(boat: int) -> MeshInstance3D:
	"""A boat's drawing (tests)."""
	return _boats[boat]
