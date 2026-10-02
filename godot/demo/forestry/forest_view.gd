extends Node3D
## The woods drawn from the real ResourceNode rows. Decision 0196 (live demo). Presentation only.
##
## Every bound tree (forest_stand.gd) is drawn by what its row says:
##   MATURE   its tree: the world's own node for a tree the world placed, else one made the same way
##            (demo_world.gd `make_piece`) -- a regrown sapling, a replanted oak.
##   felled   the model is cut at its felling cut (forest_split.gd, forest_roots.gd): the root mound and
##            the stub stay, and the trunk and crown above TOPPLE about the cut, away from the feller,
##            quicker as they go (FALL_S of demo time), land with a burst of leaves and dust
##            (forest_fx.gd), lie a moment (LIE_S) and give way to the trunk -- the felled trunk, or
##            the beaver's gnawed log -- lying on the ground beyond the mound the way it fell, shorter
##            as the haulers take it away. (A placeholder tree, with nothing to cut, falls whole.)
##   STUMP    the mound and stub, capped by a fresh-cut oak stump for a season, then a mossy one; from
##            the mound a shoot grows as the row's 48 days run, and at the end the tree stands again.
##   YOUNG    the sapling (the demo's, or a planted one), growing from a third of its size.
## GROWING (decision 0301, review F52): a stump's shoot and a sapling grow on ONE height ramp over the
## row's 48 days, from GROW_FROM of the sapling to the mature tree's own height. While the ramp is below
## the sapling's full size (GROW_TO of it) the sapling or shoot is drawn; past it the tree's own MATURE
## model is drawn scaled down to the ramp's height -- about a third at the swap, where the two heights
## are equal -- let down by the same share of its sink, at the tree's centre, and the stump, stub and
## shoot are hidden. At the midnight it matures it stands at full size: the swap is seamless. The
## model's unscaled transform is kept (`_tree_rest`) and restored when mature, because a fall reads it.
## A spot the woods call occupied (`set_occupied`) keeps its shoot: the stump cannot regrow there.
##   CLEARED  nothing: uprooted by a storm or grubbed out -- until someone plants it.
## A storm's blow-down topples the same way, and its mound goes with it.
##
## `sync()` redraws only what the stand's revision says changed (and each growing tree when the
## calendar's hour turns); `advance()` runs the falls on the demo clock, so a paused game holds a tree
## in mid-fall and 4x brings it down four times as fast. Nothing here allocates per frame.

const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const SplitScript := preload("res://demo/forestry/forest_split.gd")
const FxScript := preload("res://demo/forestry/forest_fx.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const FieldScript := preload("res://demo/forestry/forest_root_field.gd")

const FALL_S: float = 2.4
const LIE_S: float = 1.4
## The trunk comes to rest this far over (its crown props it a little off the ground).
const FALL_ANGLE: float = 1.45
## A stump is fresh-cut for a season (12 days), then mossy.
const STUMP_FRESH_DAYS: int = 12
const FRESH_STUMP_KEY: StringName = &"oak_stump_fresh"
const MOSSY_STUMP_KEY: StringName = &"stump_mossy"
## The stump models' own radius at size 1 (measured from the staged L0s, ~0.95 m).
const STUMP_MODEL_RADIUS_M: float = 0.95
## A stump's cut face stands this share of its height above the tree's cut, covering the stub's top.
const STUMP_ABOVE_CUT: float = 0.4
const TRUNK_KEYS: Array[StringName] = [&"felled_trunk", &"gnawed_log"]
## The trunk is never drawn shorter than this share of itself.
const TRUNK_MIN_SHARE: float = 0.3
## A shoot or sapling is drawn from this share of the sapling's size up to the last (then the tree).
const GROW_FROM: float = 0.3
const GROW_TO: float = 1.35
## A shoot grows on the mound this far beyond the cut's rim (m).
const SHOOT_OUT_M: float = 0.5
## The crown's centre sits at this share of the tree's height (for the leaves' burst).
const CROWN_SHARE: float = 0.62

var fx: FxScript = null
## Whether the trees are the staged models (their mounds are real; the walkers are lifted onto them).
var staged: bool = false

var _stand: StandScript = null
var _props: PropsScript = null
var _world_node: Callable = Callable()
var _make: Callable = Callable()
var _split: SplitScript = SplitScript.new()
var _parts: Array = []
var _shown: PackedByteArray = PackedByteArray()
var _falling_s: PackedFloat32Array = PackedFloat32Array()
var _landed: PackedByteArray = PackedByteArray()
var _falls: PackedInt32Array = PackedInt32Array()
var _tree_nodes: Array[Node3D] = []
var _tree_look: PackedInt32Array = PackedInt32Array()
var _lower_nodes: Array[MeshInstance3D] = []
var _upper_nodes: Array[MeshInstance3D] = []
var _young_nodes: Array[Node3D] = []
var _young_base: PackedFloat32Array = PackedFloat32Array()
var _stump_nodes: Array[Node3D] = []
var _stump_keys: Array[StringName] = []
var _trunk_nodes: Array[Node3D] = []
var _rest: Array[Transform3D] = []
## Each tree node's own full-size standing transform (see GROWING): `_rest` is the falling part's.
var _tree_rest: Array[Transform3D] = []
## The size the sapling node is drawn at (a world sapling's placement size; 1 for one made here).
var _young_size: PackedFloat32Array = PackedFloat32Array()
## The share of its mature model a young tree is drawn at now (0: sapling or shoot, or none).
var _young_share: PackedFloat32Array = PackedFloat32Array()
## Per StandScript.LOOK_*: the model's root field (forest_root_field.gd; null before it is baked).
var _fields: Array[FieldScript] = []
var _occupied: Callable = Callable()
var _seen: int = -1
var _day: int = 1
var _hour: int = 0


func configure(stand: StandScript, world_node: Callable, make: Callable, props: PropsScript) -> void:
	"""Draw these trees: `world_node(placement) -> Node3D` is the world's node for a placed tree (or
	null), `make(key, at, yaw, size) -> Node3D` makes one more world model; props draw the trunks."""
	name = "ForestView"
	_stand = stand
	_world_node = world_node
	_make = make
	_props = props
	fx = FxScript.new()
	add_child(fx)
	fx.build()
	var n: int = StandScript.MAX_TREES
	for column: PackedByteArray in [_shown, _landed]:
		column.resize(n)
	_falling_s.resize(n)
	_falling_s.fill(-1.0)
	_tree_look.resize(n)
	_tree_look.fill(-1)
	_young_base.resize(n)
	_young_size.resize(n)
	_young_size.fill(1.0)
	_young_share.resize(n)
	_tree_rest.resize(n)
	_fields.resize(StandScript.LOOK_KEYS.size())
	for list: Array in [_tree_nodes, _lower_nodes, _upper_nodes, _young_nodes, _stump_nodes, _trunk_nodes]:
		list.resize(n)
	_stump_keys.resize(n)
	_rest.resize(n)
	for t: int in stand.count():
		_shown[t] = 255
		_adopt_world_node(t)


func _adopt_world_node(t: int) -> void:
	"""The world's node for tree `t` plays its first role: the mature tree, or (a sapling) the young one."""
	var node: Node3D = _world_node.call(_stand.placement[t]) as Node3D if _world_node.is_valid() else null
	if node == null:
		return
	if _stand.state_of(t) == StandScript.STATE_YOUNG:
		_young_nodes[t] = node
		_young_base[t] = node.transform.basis.get_scale().x
		_young_size[t] = _stand.size[t]
		return
	_tree_nodes[t] = node
	_tree_look[t] = _stand.look[t]
	_rest[t] = node.transform
	_tree_rest[t] = node.transform
	staged = staged or not String(node.name).begins_with("Placeholder")


func sync(day: int, hour: int) -> void:
	"""Redraw every tree whose row changed since the last sync, and every growing one when the hour
	turns (the calendar's day and hour)."""
	var hour_turned: bool = day != _day or hour != _hour
	_day = day
	_hour = hour
	if _stand.revision == _seen and not hour_turned:
		return
	var changed: bool = _stand.revision != _seen
	_seen = _stand.revision
	for t: int in _stand.count():
		var state: int = _stand.state_of(t)
		if changed or state == StandScript.STATE_STUMP or state == StandScript.STATE_YOUNG:
			_apply(t, state)


func _apply(t: int, state: int) -> void:
	"""Draw tree `t` in `state`; a mature tree that has just gone down starts to fall."""
	if _shown[t] == StandScript.STATE_MATURE and state != StandScript.STATE_MATURE and _stand.trunk_milli[t] > 0:
		_start_fall(t)
	_shown[t] = state
	_draw_young(t, state)
	_draw_tree(t, state)
	_draw_stump(t, state)
	_draw_trunk(t)


func _draw_tree(t: int, state: int) -> void:
	"""The whole tree while it stands (at full size) or grows past its sapling (scaled, see GROWING);
	its mound and stub while it is a stump (or falling from one); nothing once cleared (the upper part
	is the fall's)."""
	var standing: bool = state == StandScript.STATE_MATURE
	var young: bool = _young_share[t] > 0.0
	if (standing or young) and _tree_look[t] != _stand.look[t]:
		_replace_tree_node(t)
	var whole_falls: bool = _falling_s[t] >= 0.0 and _upper_nodes[t] == null
	if _tree_nodes[t] != null:
		_tree_nodes[t].visible = standing or whole_falls or young
		if standing and not whole_falls:
			_tree_nodes[t].transform = _tree_rest[t]
		elif young:
			_tree_nodes[t].transform = young_transform(_tree_rest[t], _young_share[t])
	if _lower_nodes[t] != null:
		_lower_nodes[t].visible = state == StandScript.STATE_STUMP and not young
	if _upper_nodes[t] != null:
		_upper_nodes[t].visible = _falling_s[t] >= 0.0


static func young_transform(rest: Transform3D, share: float) -> Transform3D:
	"""A tree's full-size standing transform drawn at `share` of its size about its foot: the basis
	scaled, and the sink (its let-down below the ground) scaled by the same share."""
	return Transform3D(rest.basis.scaled(Vector3.ONE * share), Vector3(rest.origin.x, rest.origin.y * share, rest.origin.z))


func _replace_tree_node(t: int) -> void:
	"""A mature tree of the stand's look, made the world's way: the old one is freed if this view made
	it, only hidden if it is the world's (review F18: a replaced tree leaves nothing of its own behind)."""
	var old: Node3D = _tree_nodes[t] if is_instance_valid(_tree_nodes[t]) else null
	if old != null and old.get_parent() == self:
		old.queue_free()
	elif old != null:
		old.visible = false
	var node: Node3D = _make.call(StandScript.LOOK_KEYS[_stand.look[t]], _stand.at[t], _stand.yaw[t], _stand.size[t]) as Node3D
	add_child(node)
	_tree_nodes[t] = node
	_tree_look[t] = _stand.look[t]
	_rest[t] = node.transform
	_tree_rest[t] = node.transform
	_forget_parts(t)


func _forget_parts(t: int) -> void:
	"""Drop tree `t`'s cut parts (a new tree node is cut afresh when it falls)."""
	for list: Array in [_lower_nodes, _upper_nodes]:
		if list[t] != null:
			(list[t] as Node).queue_free()
			list[t] = null


func _draw_young(t: int, state: int) -> void:
	"""A sapling growing on its own, or a shoot on a stump's mound, on the growth ramp (see GROWING);
	neither once the ramp has passed the sapling and the young tree is drawn instead."""
	var growing: bool = state == StandScript.STATE_YOUNG or state == StandScript.STATE_STUMP
	_young_share[t] = young_share(t) if growing else 0.0
	if not growing or _young_share[t] > 0.0:
		if _young_nodes[t] != null:
			_young_nodes[t].visible = false
		return
	var at: Vector2 = _stand.at[t]
	var y: float = 0.0
	if state == StandScript.STATE_STUMP:
		var out: float = Roots.cut_radius_m(_stand.look[t], _stand.size[t]) + SHOOT_OUT_M
		at += Vector2.from_angle(_stand.yaw[t]) * out
		y = root_height(t, at, 1.0)
	var node: Node3D = _young_node(t)
	var share: float = minf(_ramp_height(t) / _sapling_height(t), GROW_TO)
	var base: Basis = Basis(Vector3.UP, _stand.yaw[t]).scaled(Vector3.ONE * _young_base[t] * share)
	node.transform = Transform3D(base, Vector3(at.x, y, at.y))
	node.visible = true


func young_share(t: int) -> float:
	"""The share of its mature model tree `t` is drawn at on the growth ramp: 0 while the ramp is below
	the sapling's full size (or the spot is occupied: the shoot waits), else ramp height / mature height."""
	var swap: float = GROW_TO * _sapling_height(t)
	var height: float = _ramp_height(t)
	var mature: float = _mature_height(t)
	if height < swap or mature <= swap:
		return 0.0
	if _occupied.is_valid() and bool(_occupied.call(_stand.at[t])):
		return 0.0
	return minf(height / mature, 1.0)


func _ramp_height(t: int) -> float:
	"""Tree `t`'s drawn height on its growth ramp: GROW_FROM of the sapling to the mature tree's height
	over the row's growth (see GROWING)."""
	var p: float = float(_stand.growth_permille(t, _day, _hour)) / 1000.0
	return lerpf(GROW_FROM * _sapling_height(t), _mature_height(t), p)


func _sapling_height(t: int) -> float:
	"""The sapling's drawn height at its own size (m)."""
	return Sizes.target_height_m(StandScript.SAPLING_KEY) * _young_size[t]


func _mature_height(t: int) -> float:
	"""The mature tree's drawn height (m)."""
	return Sizes.target_height_m(StandScript.LOOK_KEYS[_stand.look[t]]) * _stand.size[t]


func set_occupied(occupied: Callable) -> void:
	"""`occupied(at: Vector2) -> bool`: whether something stands on a spot, so its stump cannot regrow
	(demo_forestry.gd's §5.9 test) -- its shoot is kept rather than a young tree drawn over it."""
	_occupied = occupied


func _young_node(t: int) -> Node3D:
	"""Tree `t`'s sapling node, made the first time it is wanted."""
	if _young_nodes[t] == null:
		_young_nodes[t] = _make.call(StandScript.SAPLING_KEY, _stand.at[t], _stand.yaw[t], 1.0) as Node3D
		_young_base[t] = _young_nodes[t].transform.basis.get_scale().x
		add_child(_young_nodes[t])
	return _young_nodes[t]


# --- the roots (decision 0301, review F40) --------------------------------------------------------

func root_field(look: int) -> FieldScript:
	"""The look's root field (forest_root_field.gd), baked from its first full-size model the first time
	it is wanted; null while the trees are placeholders (they have no roots) or none of that look stands."""
	if _fields[look] != null or not staged:
		return _fields[look]
	var key: StringName = StandScript.LOOK_KEYS[look]
	for t: int in _stand.count():
		if _tree_look[t] == look and _tree_nodes[t] != null:
			_fields[look] = FieldScript.baked(_tree_nodes[t], _tree_rest[t], _stand.yaw[t], _stand.size[t],
				Roots.reach_m(look, 1.0), float(Layout.TRUNK_RADIUS_M[key]))
			break
	return _fields[look]


func root_fields() -> Array[FieldScript]:
	"""Every look's root field (see `root_field`), for forest_lift.gd."""
	for look: int in StandScript.LOOK_KEYS.size():
		root_field(look)
	return _fields


func root_height(t: int, at: Vector2, share: float) -> float:
	"""The height of tree `t`'s roots (m above the ground) at `at`, its model drawn at `share` of its size."""
	var field: FieldScript = root_field(_stand.look[t])
	if field == null:
		return 0.0
	return field.height_at(at, _stand.at[t], _stand.yaw[t], _stand.size[t] * share)


func mound_scale(t: int) -> float:
	"""How large tree `t`'s roots are drawn now, for the walkers' lift: 1 standing or a stump's mound, the
	young tree's share while one grows, 0 for a sapling and a cleared spot."""
	var state: int = _stand.state_of(t)
	if state == StandScript.STATE_MATURE:
		return 1.0
	if state == StandScript.STATE_STUMP:
		return _young_share[t] if _young_share[t] > 0.0 else 1.0
	return _young_share[t] if state == StandScript.STATE_YOUNG else 0.0


func _draw_stump(t: int, state: int) -> void:
	"""A fresh stump for a season, then a mossy one, capping the cut; none unless the row is a stump
	still showing its shoot (a young tree stands in its place, see GROWING)."""
	if state != StandScript.STATE_STUMP or _young_share[t] > 0.0:
		if _stump_nodes[t] != null:
			_stump_nodes[t].visible = false
		return
	var key: StringName = FRESH_STUMP_KEY if _stand.stump_age_days(t, _day) < STUMP_FRESH_DAYS else MOSSY_STUMP_KEY
	if _stump_nodes[t] == null or _stump_keys[t] != key:
		if _stump_nodes[t] != null:
			_stump_nodes[t].queue_free()
		_stump_nodes[t] = _make.call(key, _stand.at[t], _stand.yaw[t], _stump_size(t)) as Node3D
		_stump_keys[t] = key
		add_child(_stump_nodes[t])
		_stump_nodes[t].position.y = _stump_lift(t, key)
	_stump_nodes[t].visible = true


func _stump_size(t: int) -> float:
	"""The stump model's size: the trunk's width at the cut (the tree's own size on a placeholder)."""
	if _lower_nodes[t] == null:
		return _stand.size[t]
	return Roots.cut_radius_m(_stand.look[t], _stand.size[t]) / STUMP_MODEL_RADIUS_M


func _stump_lift(t: int, key: StringName) -> float:
	"""How high the stump model stands: its face just above the cut on a split tree (the cut above the
	ground, after the tree's sink), else the ground."""
	if _lower_nodes[t] == null:
		return 0.0
	var height: float = Sizes.target_height_m(key) * _stump_size(t)
	return Roots.cut_m(_stand.look[t], _stand.size[t]) - height * (1.0 - STUMP_ABOVE_CUT)


func _draw_trunk(t: int) -> void:
	"""The trunk lies on the ground beyond the mound, along the fall, once the tree is down; shorter as
	its wood is hauled."""
	var lying: bool = _stand.trunk_milli[t] > 0 and _falling_s[t] < 0.0
	if not lying:
		if _trunk_nodes[t] != null:
			_trunk_nodes[t].visible = false
		return
	var key: StringName = TRUNK_KEYS[_stand.gnawed[t]]
	if _trunk_nodes[t] == null or _trunk_nodes[t].get_child(0).name != String(key):
		_make_trunk(t, key)
	var share: float = maxf(TRUNK_MIN_SHARE, float(_stand.trunk_milli[t]) / float(Rules.TREE_WOOD_MILLI))
	var length: float = _props.drawn_bound(key).size.x * share
	var dir: Vector2 = _stand.fall_dir[t]
	var centre: Vector2 = _stand.at[t] + dir * (Roots.trunk_start_m(_stand.look[t], _stand.size[t]) + length * 0.5)
	var turn := Basis(Vector3.UP, atan2(-dir.y, dir.x)) * Basis.from_scale(Vector3(share, 1.0, 1.0))
	_trunk_nodes[t].transform = Transform3D(turn, Vector3(centre.x, 0.0, centre.y))
	_trunk_nodes[t].visible = true


func _make_trunk(t: int, key: StringName) -> void:
	"""Tree `t`'s trunk node: a pivot holding the trunk model, its length along the pivot's X."""
	if _trunk_nodes[t] != null:
		_trunk_nodes[t].queue_free()
	var pivot := Node3D.new()
	pivot.add_child(_props.instance(key))
	add_child(pivot)
	_trunk_nodes[t] = pivot


func prewarm() -> int:
	"""Load now what the woods would first load mid-game (demo_prewarm.gd, decision 0205): the stump and
	sapling models (made once and let go; the world keeps their scenes) and each tree kind's split for
	its fall (forest_split.gd keeps one per kind). Returns how many were loaded."""
	var loaded: int = 0
	for key: StringName in [FRESH_STUMP_KEY, MOSSY_STUMP_KEY, StandScript.SAPLING_KEY]:
		var node: Node3D = _make.call(key, Vector2.ZERO, 0.0, 1.0) as Node3D if _make.is_valid() else null
		if node != null:
			node.free()
			loaded += 1
	for t: int in _stand.count():
		loaded += _prewarm_split(t)
	return loaded


func _prewarm_split(t: int) -> int:
	"""Split tree `t`'s kind as its fall would, if no tree of that kind has been split yet (1: split)."""
	var node: Node3D = _tree_nodes[t]
	if node == null:
		return 0
	var key: StringName = StandScript.LOOK_KEYS[_stand.look[t]]
	if _split.has_parts(key):
		return 0
	var scale_y: float = maxf(node.transform.basis.get_scale().y, 0.0001)
	return 1 if _split.parts_into(key, node, Roots.model_cut_m(_stand.look[t], _stand.size[t]) / scale_y, _parts) else 0


# --- falling -----------------------------------------------------------------------------------

func _start_fall(t: int) -> void:
	"""Tree `t` begins to topple: cut in two where it can be (the upper part turns about the cut), or
	-- a placeholder -- whole, about its foot."""
	var node: Node3D = _tree_nodes[t]
	if node == null or _falling_s[t] >= 0.0:
		return
	_rest[t] = node.transform
	var key: StringName = StandScript.LOOK_KEYS[_stand.look[t]]
	var scale_y: float = maxf(node.transform.basis.get_scale().y, 0.0001)
	if _split.parts_into(key, node, Roots.model_cut_m(_stand.look[t], _stand.size[t]) / scale_y, _parts):
		var xform: Transform3D = node.transform * (_parts[2] as Transform3D)
		_lower_nodes[t] = _part_node(_lower_nodes[t], _parts[0], xform)
		_upper_nodes[t] = _part_node(_upper_nodes[t], _parts[1], xform)
		_rest[t] = xform
	_falling_s[t] = 0.0
	_landed[t] = 0
	_falls.append(t)


func _part_node(part: MeshInstance3D, mesh: Mesh, xform: Transform3D) -> MeshInstance3D:
	"""A node drawing one cut part where the tree stood: the tree's own from its last fall, set back
	in place, or -- its first fall, or its first since its look changed -- a new one (review F18:
	felled, regrown and felled again, a tree keeps two part nodes, not two more each time)."""
	if part == null:
		part = MeshInstance3D.new()
		add_child(part)
	part.mesh = mesh
	part.transform = xform
	return part


func advance(delta_s: float) -> void:
	"""Run every fall by `delta_s` demo seconds (0 while paused)."""
	if _falls.is_empty() or delta_s <= 0.0:
		return
	for k: int in range(_falls.size() - 1, -1, -1):
		var t: int = _falls[k]
		_falling_s[t] += delta_s
		_pose_fall(t)
		if _falling_s[t] >= FALL_S + LIE_S:
			_end_fall(t)
			_falls.remove_at(k)


func _pose_fall(t: int) -> void:
	"""The falling part turned about the cut (or the foot) away from the feller, quicker as it goes;
	the landing bursts."""
	var p: float = clampf(_falling_s[t] / FALL_S, 0.0, 1.0)
	var dir: Vector2 = _stand.fall_dir[t]
	var axis: Vector3 = Vector3.UP.cross(Vector3(dir.x, 0.0, dir.y)).normalized()
	var pivot := Vector3(_stand.at[t].x, _cut_height(t), _stand.at[t].y)
	var turn := Transform3D(Basis(axis, FALL_ANGLE * p * p), Vector3.ZERO)
	var falling: Node3D = _upper_nodes[t] if _upper_nodes[t] != null else _tree_nodes[t]
	falling.transform = Transform3D(Basis.IDENTITY, pivot) * turn * Transform3D(Basis.IDENTITY, -pivot) * _rest[t]
	if p >= 1.0 and _landed[t] == 0:
		_landed[t] = 1
		var landing: Vector2 = Roots.trunk_middle(_stand, t)
		fx.burst(_crown_at(t), Vector3(landing.x, 0.0, landing.y))


func _cut_height(t: int) -> float:
	"""Where the tree turns, above the ground: its cut when it was split (the sunk tree's, forest_roots.gd),
	its foot when it falls whole (a placeholder, never sunk)."""
	return Roots.cut_m(_stand.look[t], _stand.size[t]) if _upper_nodes[t] != null else 0.0


func _crown_at(t: int) -> Vector3:
	"""Where the fallen crown lies: CROWN_SHARE of the tree's height out along the fall."""
	var height: float = Sizes.target_height_m(StandScript.LOOK_KEYS[_stand.look[t]]) * _stand.size[t]
	var dir: Vector2 = _stand.fall_dir[t] * height * CROWN_SHARE
	return Vector3(_stand.at[t].x + dir.x, 1.2, _stand.at[t].y + dir.y)


func _end_fall(t: int) -> void:
	"""The fallen part gives way to the trunk; a whole tree that fell stands up again, hidden, for its
	regrowth."""
	_falling_s[t] = -1.0
	if _upper_nodes[t] == null and _tree_nodes[t] != null:
		_tree_nodes[t].transform = _rest[t]
	_draw_tree(t, _stand.state_of(t))
	_draw_trunk(t)


func is_falling(t: int) -> bool:
	"""Whether tree `t` is coming down now."""
	return _falling_s[t] >= 0.0


func has_landed(t: int) -> bool:
	"""Whether tree `t`'s fall has hit the ground (checks and the scripted run)."""
	return _landed[t] == 1


func falls_live() -> int:
	"""How many trees are coming down (checks)."""
	return _falls.size()


func tree_visible(t: int) -> bool:
	"""Whether tree `t`'s mature tree is drawn (checks)."""
	return _tree_nodes[t] != null and _tree_nodes[t].visible


func stump_key(t: int) -> StringName:
	"""Which stump is drawn at tree `t` (&"" when none; checks)."""
	return _stump_keys[t] if _stump_nodes[t] != null and _stump_nodes[t].visible else &""


func trunk_visible(t: int) -> bool:
	"""Whether tree `t`'s trunk is drawn (checks)."""
	return _trunk_nodes[t] != null and _trunk_nodes[t].visible


func young_visible(t: int) -> bool:
	"""Whether tree `t`'s sapling or shoot is drawn (checks)."""
	return _young_nodes[t] != null and _young_nodes[t].visible


func young_node(t: int) -> Node3D:
	"""Tree `t`'s sapling node (null before it was wanted; checks)."""
	return _young_nodes[t]


func tree_node(t: int) -> Node3D:
	"""The node drawing tree `t`'s whole tree (standing, or young and scaled; null before one is made)."""
	return _tree_nodes[t]


func upper_part(t: int) -> MeshInstance3D:
	"""The node drawing tree `t`'s cut-off upper part -- trunk and crown -- while it falls (null before its first
	fall; the seasons dress its leaves, demo/seasons/season_view.gd)."""
	return _upper_nodes[t]


func crown_scale(t: int) -> float:
	"""How large tree `t`'s crown is drawn now (demo/camera/canopy_clear.gd): 1 standing, the young tree's
	share while one grows, 0 for a sapling, a shoot, a stump or a spot (and while it falls)."""
	if _falling_s[t] >= 0.0:
		return 0.0
	if _stand.state_of(t) == StandScript.STATE_MATURE:
		return 1.0
	return _young_share[t]
