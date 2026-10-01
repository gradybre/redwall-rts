extends RefCounted
## What the pointer is on in the woods. Decision 0196 (live demo). Pure picking, no nodes: the
## demo's own capsule proxies (demo/control/demo_pick.gd) -- no physics bodies.
##
## A STANDING tree (mature or young) is a vertical capsule round its trunk and lower crown, so a click
## on the tree itself takes it. Everything that lies on the ground is taken where the ray meets the
## ground: a stump or a cleared spot within its trunk circle and a little more, a lying trunk along
## its length, a deadfall pile, the sawhorse or the plank stack. A standing tree hit first wins.

const DemoPick := preload("res://demo/control/demo_pick.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")

const KIND_NONE: int = 0
const KIND_TREE: int = 1
const KIND_TRUNK: int = 2
const KIND_PILE: int = 3
const KIND_SAW: int = 4
## A standing tree's pick capsule: this share of its height, and at least this wide (m).
const TREE_PICK_SHARE: float = 0.55
const TREE_PICK_MIN_RADIUS_M: float = 1.2
const TREE_PICK_RADIUS_SHARE: float = 1.6
## Ground picks: how near the ground point must be (m).
const SPOT_PICK_EXTRA_M: float = 0.9
const TRUNK_PICK_M: float = 1.3
const PILE_PICK_M: float = 1.3
const YARD_PICK_M: float = 1.4

## What the last pick found (KIND_*) and its index (a tree, a pile; -1 for the yard or nothing).
var kind: int = KIND_NONE
var index: int = -1

var _feet: PackedVector3Array = PackedVector3Array()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _seen: int = -1


func refresh(stand: StandScript) -> void:
	"""Rebuild the standing trees' capsules when the stand changed (a felled tree has none)."""
	if stand.revision == _seen:
		return
	_seen = stand.revision
	_feet.resize(stand.count())
	_heights.resize(stand.count())
	_radii.resize(stand.count())
	for t: int in stand.count():
		var state: int = stand.state_of(t)
		var key: StringName = StandScript.LOOK_KEYS[stand.look[t]] if state == StandScript.STATE_MATURE else StandScript.SAPLING_KEY
		var standing: bool = state == StandScript.STATE_MATURE or state == StandScript.STATE_YOUNG
		_feet[t] = Vector3(stand.at[t].x, 0.0, stand.at[t].y)
		_heights[t] = Sizes.target_height_m(key) * stand.size[t] * TREE_PICK_SHARE if standing else 0.0
		_radii[t] = maxf(stand.radius_m[t] * TREE_PICK_RADIUS_SHARE, TREE_PICK_MIN_RADIUS_M) if standing else 0.0


func pick(origin: Vector3, direction: Vector3, stand: StandScript, deadfall: DeadfallScript) -> int:
	"""What a camera ray is on: KIND_* (and `index`). A standing tree first, then the ground."""
	refresh(stand)
	kind = KIND_NONE
	index = -1
	var hit: int = DemoPick.nearest_hit(origin, direction, _feet, _heights, _radii)
	if hit >= 0:
		return _found(KIND_TREE, hit)
	var t: float = DemoPick.ray_ground(origin, direction, 0.0)
	if t < 0.0:
		return KIND_NONE
	var at: Vector3 = origin + direction * t
	return pick_ground(Vector2(at.x, at.z), stand, deadfall)


func pick_ground(at: Vector2, stand: StandScript, deadfall: DeadfallScript) -> int:
	"""What lies at a ground point: a lying trunk, a deadfall pile, the sawing yard, or a stump or a
	cleared spot (KIND_*, and `index`)."""
	for tree: int in stand.count():
		if stand.trunk_milli[tree] > 0 and _near_trunk(stand, tree, at):
			return _found(KIND_TRUNK, tree)
	for pile: int in Rules.DEADFALL_MAX:
		if deadfall.live[pile] == 1 and deadfall.at[pile].distance_to(at) <= PILE_PICK_M:
			return _found(KIND_PILE, pile)
	if at.distance_to(Yard.at(Yard.SAWHORSE)) <= YARD_PICK_M or at.distance_to(Yard.at(Yard.PLANK_STACK)) <= YARD_PICK_M:
		return _found(KIND_SAW, -1)
	for tree: int in stand.count():
		if stand.at[tree].distance_to(at) <= stand.radius_m[tree] + SPOT_PICK_EXTRA_M:
			return _found(KIND_TREE, tree)
	return KIND_NONE


static func _near_trunk(stand: StandScript, tree: int, at: Vector2) -> bool:
	"""Whether a ground point lies along tree `tree`'s fallen trunk (beyond its mound, forest_roots.gd)."""
	var half: Vector2 = stand.fall_dir[tree] * Roots.TRUNK_LENGTH_M * 0.5
	var middle: Vector2 = Roots.trunk_middle(stand, tree)
	return Geometry2D.get_closest_point_to_segment(at, middle - half, middle + half).distance_to(at) <= TRUNK_PICK_M


func _found(found_kind: int, found_index: int) -> int:
	"""Record a pick and return its kind."""
	kind = found_kind
	index = found_index
	return found_kind
