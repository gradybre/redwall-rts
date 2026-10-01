extends Node
## Tree crowns kept out of the player's way. Decision 0301 (review F53). Presentation only.
##
## The review found the orbit camera could sit inside an oak's crown (the NW oak: focus (-19.5, 0, -19),
## yaw 90, 11 m, pitch 30 -- a screen of leaves) and a selected worker under a crown, or behind a roof,
## could not be seen at all. Three answers, each scoped to what is in the way:
##   * THE EYE (`allowed_distance`, the camera rig's clearance, demo_camera.gd CLEARANCE): an eye that would
##     sit inside a crown (crowns grown by EYE_INFLATE_M for the lens) is moved along its own line, out past
##     the crown's far side (at most MAX_PUSH_M farther), EYE_MARGIN_M clear: the crown it left is then
##     between the eye and the focus, and is thinned. Only where that is too far does it come in short of
##     the crown's near side instead (never nearer the focus than EYE_FLOOR_M) -- in close under a crown
##     the eye would face the trunk. An eye in the open is never moved.
##   * THE SIGHT LINES (`_process`): only the crowns the line from the eye to the focus, or to a selected
##     resident's chest, passes through -- and any crown within NEAR_FADE_M of the eye -- are thinned (canopy_fade.gdshader: an opaque-pass dither above the
##     crown's base, the trunk untouched, the shadow whole), at most MAX_FADED at a time, easing in and out
##     at FADE_RATE. Nothing else in the woods changes.
##   * THE SELECTED (`selected_xray.gdshader`): a selected resident's body wears an overlay drawn only where
##     something nearer the camera covers it, so it shows as a brass silhouette through foliage and roofs.
## Both materials are built and drawn once at boot (`begin_prewarm`/`end_prewarm`, the demo prewarm's
## frame step, decisions 0205/0206), so the first fade costs no pipeline compile.
##
## Crowns are packed (canopy_math.gd) and refreshed only when the stand's revision or the view's growth
## moves (REFRESH_S at most); trees are bucketed once in a grid (their spots never move). A frame tests the
## few cells along each sight line and allocates nothing; materials are swapped only when a fade starts or
## ends. In the underground view (decision 0206) nothing here draws.

const Math := preload("res://demo/camera/canopy_math.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const FADE_SHADER := preload("res://demo/camera/canopy_fade.gdshader")
const XRAY_SHADER := preload("res://demo/camera/selected_xray.gdshader")

const EYE_MARGIN_M: float = 0.8
const EYE_FLOOR_M: float = 3.0
const EYE_INFLATE_M: float = 0.6
## The eye is moved past at most this many overlapping crowns.
const MAX_PULLS: int = 4
## The eye is moved out past a crown at most this much farther than asked (else it comes in).
const MAX_PUSH_M: float = 25.0
## A crown within this of the eye is thinned too, wherever the sight lines run: leaves at the lens.
const NEAR_FADE_M: float = 4.0
## Crowns rise no higher than this (m): a sight line above it meets none.
const CANOPY_TOP_M: float = 22.0
const FADE_RATE: float = 5.0
const MAX_FADED: int = 8
## The focus and a resident are looked at this far above their feet (m; a resident: half its height).
const FOCUS_LIFT_M: float = 0.5
const REFRESH_S: float = 0.5
const CELL_M: float = 8.0
const GRID_HALF: int = 12
const GRID_SIDE: int = 2 * GRID_HALF
const PER_CELL: int = 24
## A crown reaches this far beyond its tree's cell (m): the largest crown at the largest size, inflated.
const CELL_REACH_M: float = 10.0
const XRAY_ALPHA: float = 0.85
## Prewarm samples stand this far below the focus: in the view, behind the ground.
const PREWARM_DEPTH_M: float = 25.0
const PARAM_FADE: StringName = &"fade"
const PARAM_BASE: StringName = &"crown_base_y"
const PARAM_EYE: StringName = &"eye_position"

var _rig: DemoCameraScript = null
var _stand: StandScript = null
var _view: ViewScript = null
var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _eye_crowns: PackedFloat32Array = PackedFloat32Array()
var _sight_crowns: PackedFloat32Array = PackedFloat32Array()
var _cell_trees: PackedInt32Array = PackedInt32Array()
var _cell_count: PackedInt32Array = PackedInt32Array()
var _fade: PackedFloat32Array = PackedFloat32Array()
var _want: PackedByteArray = PackedByteArray()
var _active: PackedInt32Array = PackedInt32Array()
var _active_count: int = 0
## The trees wanted this frame (`_want` set), at most MAX_FADED.
var _wanted_list: PackedInt32Array = PackedInt32Array()
var _wanted: int = 0
var _faded_mesh: Array[MeshInstance3D] = []
## Source material -> its fade material; and the same fade materials as a list (no per-frame Array).
var _materials: Dictionary[Material, ShaderMaterial] = {}
var _material_list: Array[ShaderMaterial] = []
var _xray: ShaderMaterial = null
var _xray_on: PackedByteArray = PackedByteArray()
var _seen_revision: int = -1
## Sight-line targets this frame (the selected residents' chests), and how many.
var _targets: PackedVector3Array = PackedVector3Array()
var _target_count: int = 0
var _refresh_in: float = 0.0
var _samples: Array[Node3D] = []


func configure(rig: DemoCameraScript, stand: StandScript, view: ViewScript, cast: DemoCastScript,
		command: DemoCommandScript) -> void:
	"""Keep these trees' crowns out of this rig's way, and these residents visible when selected."""
	name = "CanopyClear"
	_rig = rig
	_stand = stand
	_view = view
	_cast = cast
	_command = command
	var n: int = StandScript.MAX_TREES
	_eye_crowns.resize(n * Math.STRIDE)
	_sight_crowns.resize(n * Math.STRIDE)
	_fade.resize(n)
	_want.resize(n)
	_faded_mesh.resize(n)
	_active.resize(MAX_FADED * 2)
	_wanted_list.resize(MAX_FADED)
	_xray_on.resize(cast.actor_count() if cast != null else 0)
	_targets.resize(maxi(_xray_on.size(), MAX_FADED))
	_xray = _xray_material()
	_bucket_trees()
	refresh_crowns()
	if _rig != null:
		_rig.set_clearance(allowed_distance)


func _bucket_trees() -> void:
	"""Each tree in the grid cell of its spot (spots never move)."""
	_cell_trees.resize(GRID_SIDE * GRID_SIDE * PER_CELL)
	_cell_count.resize(GRID_SIDE * GRID_SIDE)
	_cell_count.fill(0)
	for t: int in _stand.count():
		var cell: int = _cell_of(floori(_stand.at[t].x / CELL_M), floori(_stand.at[t].y / CELL_M))
		if cell >= 0 and _cell_count[cell] < PER_CELL:
			_cell_trees[cell * PER_CELL + _cell_count[cell]] = t
			_cell_count[cell] += 1


static func _cell_of(cx: int, cz: int) -> int:
	"""The grid cell at cell coordinates (cx, cz) (-1 off the grid)."""
	var x: int = cx + GRID_HALF
	var z: int = cz + GRID_HALF
	if x < 0 or z < 0 or x >= GRID_SIDE or z >= GRID_SIDE:
		return -1
	return z * GRID_SIDE + x


func refresh_crowns() -> void:
	"""Every tree's crown as drawn now (canopy_math.gd), for the eye (inflated) and the sight lines."""
	_seen_revision = _stand.revision
	for t: int in _stand.count():
		var size: float = _stand.size[t] * (_view.crown_scale(t) if _view != null else 1.0)
		Math.set_crown(_eye_crowns, t, _stand.look[t], _stand.at[t], size, EYE_INFLATE_M)
		Math.set_crown(_sight_crowns, t, _stand.look[t], _stand.at[t], size, 0.0)


# --- the eye ---------------------------------------------------------------------------------------

func allowed_distance(focus: Vector3, yaw: float, pitch: float, distance: float) -> float:
	"""Where the orbit camera's eye may sit from `focus` along its yaw and pitch, given the asked `distance`:
	that, unless it lies inside a crown -- then out past the far side of the crown(s) it is in (at most
	MAX_PUSH_M farther), or failing that in short of their near side (never nearer than EYE_FLOOR_M), each
	EYE_MARGIN_M clear. Crowns the line merely passes through are the fade's (see THE EYE)."""
	var direction: Vector3 = Math.eye_direction(yaw, pitch)
	var outward: float = _pulled(focus, direction, distance, 1.0)
	if outward - distance <= MAX_PUSH_M:
		return outward
	return _pulled(focus, direction, distance, -1.0)


func _pulled(focus: Vector3, direction: Vector3, distance: float, way: float) -> float:
	"""The eye moved along its line (`way` -1: toward the focus, +1: away) past each crown it is in, until
	it is in none (MAX_PULLS crowns at most; toward the focus, never nearer than EYE_FLOOR_M)."""
	var t: float = distance
	for pull: int in MAX_PULLS:
		var k: int = crown_holding(focus + direction * t)
		if k < 0:
			return t
		var span: Vector2 = Math.ray_span(_eye_crowns, k, focus, direction)
		t = span.x - EYE_MARGIN_M if way < 0.0 else span.y + EYE_MARGIN_M
		if way < 0.0 and t <= EYE_FLOOR_M:
			return minf(EYE_FLOOR_M, distance)
	if crown_holding(focus + direction * t) < 0:
		return t
	return minf(EYE_FLOOR_M, distance) if way < 0.0 else INF


func crown_holding(p: Vector3) -> int:
	"""The first tree whose crown (grown for the eye) holds point `p` (-1: none)."""
	if p.y > CANOPY_TOP_M:
		return -1
	var cx: int = floori(p.x / CELL_M)
	var cz: int = floori(p.z / CELL_M)
	var reach: int = ceili(CELL_REACH_M / CELL_M)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: int = _cell_of(cx + dx, cz + dz)
			if cell < 0:
				continue
			for k: int in _cell_count[cell]:
				var t: int = _cell_trees[cell * PER_CELL + k]
				if Math.contains(_eye_crowns, t, p):
					return t
	return -1


# --- the sight lines -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""This frame's eye, focus and selected residents: mark the crowns in the way, ease every fade, and keep
	the selected residents' silhouettes."""
	if _stand == null or _rig == null:
		return
	var below: bool = _command != null and _command.underground_view()
	_target_count = 0
	if not below:
		_aim_at_selected()
	update(eye_of(_rig), _rig.focus(), delta, below)
	_keep_xray(below)


func update(eye: Vector3, focus: Vector3, delta: float, below: bool = false) -> void:
	"""One step from an eye at `eye` looking at `focus` (and at the `_targets` set this frame): refresh the
	crowns when due, want a fade on every crown in the way (none `below`, in the underground view), and
	ease every live fade by `delta` real seconds."""
	_refresh_in -= delta
	if _stand.revision != _seen_revision or _refresh_in <= 0.0:
		_refresh_in = REFRESH_S
		refresh_crowns()
	for k: int in _wanted:
		_want[_wanted_list[k]] = 0
	_wanted = 0
	if not below:
		_want_crowns_between(eye, focus + Vector3.UP * FOCUS_LIFT_M)
		_want_crowns_between(eye, eye)
		for k: int in _target_count:
			_want_crowns_between(eye, _targets[k])
	_ease_fades(eye, delta)


func _aim_at_selected() -> void:
	"""This frame's targets: each selected resident's chest (half its height above its feet)."""
	if _cast == null or _command == null:
		return
	for i: int in mini(_cast.actor_count(), _targets.size()):
		if _command.is_selected(i):
			var actor := _cast.actor(i) as DemoActorScript
			_targets[_target_count] = placed_at(actor) + Vector3.UP * actor.height_m * 0.5
			_target_count += 1


static func eye_of(rig: DemoCameraScript) -> Vector3:
	"""Where the rig's camera is: its world position in the tree, else through the rig's own transform (the
	rig stands at the village's origin)."""
	var camera: Camera3D = rig.camera()
	return camera.global_position if camera.is_inside_tree() else rig.transform * camera.position


static func placed_at(node: Node3D) -> Vector3:
	"""A node's world position in the tree, else its own (the cast stands at the village's origin)."""
	return node.global_position if node.is_inside_tree() else node.position


func set_targets(points: PackedVector3Array) -> void:
	"""The next `update`'s sight-line targets besides the focus (checks; a frame sets them from the
	selection itself)."""
	_target_count = mini(points.size(), _targets.size())
	for k: int in _target_count:
		_targets[k] = points[k]


func _want_crowns_between(eye: Vector3, target: Vector3) -> void:
	"""Want a fade on every crown the sight line from `eye` to `target` passes through (MAX_FADED at most)."""
	var x0: int = floori((minf(eye.x, target.x) - CELL_REACH_M) / CELL_M)
	var x1: int = floori((maxf(eye.x, target.x) + CELL_REACH_M) / CELL_M)
	var z0: int = floori((minf(eye.z, target.z) - CELL_REACH_M) / CELL_M)
	var z1: int = floori((maxf(eye.z, target.z) + CELL_REACH_M) / CELL_M)
	for cz: int in range(z0, z1 + 1):
		for cx: int in range(x0, x1 + 1):
			var cell: int = _cell_of(cx, cz)
			if cell < 0 or _wanted >= MAX_FADED:
				continue
			for k: int in _cell_count[cell]:
				var t: int = _cell_trees[cell * PER_CELL + k]
				if _want[t] == 0 and _wanted < MAX_FADED and _in_the_way(t, eye, target):
					_want[t] = 1
					_wanted_list[_wanted] = t
					_wanted += 1
					_activate(t)


func _in_the_way(t: int, eye: Vector3, target: Vector3) -> bool:
	"""Whether crown `t` stands on the sight line, or (a line of no length: the eye itself) at the lens."""
	if eye.is_equal_approx(target):
		return Math.contains(_sight_crowns, t, eye, NEAR_FADE_M)
	return Math.segment_crosses(_sight_crowns, t, eye, target)


# --- fading ------------------------------------------------------------------------------------------

func _activate(t: int) -> void:
	"""Start fading tree `t` (its mesh drawn with its look's fade material), if it is not already."""
	if is_instance_valid(_faded_mesh[t]) or _active_count >= _active.size():
		return
	_drop_stale(t)
	var node: Node3D = _view.tree_node(t) if _view != null else null
	var mesh: MeshInstance3D = _first_mesh(node)
	if mesh == null or not shown(mesh):
		return
	mesh.material_override = fade_material_for(mesh)
	var size: float = _stand.size[t] * _view.crown_scale(t)
	mesh.set_instance_shader_parameter(PARAM_BASE, Math.CROWN_BASE_M[_stand.look[t]] * size)
	_faded_mesh[t] = mesh
	_fade[t] = 0.0
	_active[_active_count] = t
	_active_count += 1


func _drop_stale(t: int) -> void:
	"""Forget tree `t`'s live fade whose mesh was freed (its node replaced), before it is faded afresh."""
	for k: int in _active_count:
		if _active[k] == t:
			_deactivate(k)
			return


func _ease_fades(eye: Vector3, delta: float) -> void:
	"""Move each live fade toward wanted (1) or not (0); a fade back at 0 gives the tree its own material."""
	if _active_count > 0:
		for material: ShaderMaterial in _material_list:
			material.set_shader_parameter(PARAM_EYE, eye)
	var k: int = 0
	while k < _active_count:
		var t: int = _active[k]
		var mesh: MeshInstance3D = _faded_mesh[t]
		var wanted: float = 1.0 if _want[t] == 1 else 0.0
		_fade[t] = move_toward(_fade[t], wanted, FADE_RATE * delta)
		if not is_instance_valid(mesh) or not shown(mesh) or (_fade[t] <= 0.0 and wanted == 0.0):
			_deactivate(k)
			continue
		mesh.set_instance_shader_parameter(PARAM_FADE, _fade[t])
		k += 1


func _deactivate(k: int) -> void:
	"""Give active tree `k` (its index in the active list) back its own material."""
	var t: int = _active[k]
	if is_instance_valid(_faded_mesh[t]):
		_faded_mesh[t].material_override = null
	_faded_mesh[t] = null
	_fade[t] = 0.0
	_active_count -= 1
	_active[k] = _active[_active_count]


static func shown(node: Node) -> bool:
	"""Whether `node` and every Node3D above it are visible (in the tree or not)."""
	var at: Node = node
	while at != null:
		var spatial := at as Node3D
		if spatial != null and not spatial.visible:
			return false
		at = at.get_parent()
	return true


static func _first_mesh(node: Node) -> MeshInstance3D:
	"""The first MeshInstance3D at or under `node` (null: none)."""
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func fade_material_for(mesh: MeshInstance3D) -> ShaderMaterial:
	"""The fade material standing in for `mesh`'s own (one per source material, made once)."""
	var source: Material = mesh.get_active_material(0)
	if not _materials.has(source):
		var made: ShaderMaterial = make_fade_material(source as BaseMaterial3D)
		_materials[source] = made
		_material_list.append(made)
	return _materials[source]


static func make_fade_material(source: BaseMaterial3D) -> ShaderMaterial:
	"""canopy_fade.gdshader carrying `source`'s albedo, metallic-roughness and normal maps (a plain white
	opaque look without one)."""
	var material := ShaderMaterial.new()
	material.shader = FADE_SHADER
	if source == null:
		return material
	material.set_shader_parameter(&"albedo_color", source.albedo_color)
	material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	material.set_shader_parameter(&"metallic", source.metallic)
	material.set_shader_parameter(&"roughness", source.roughness)
	material.set_shader_parameter(&"metallic_texture", source.metallic_texture)
	material.set_shader_parameter(&"roughness_texture", source.roughness_texture)
	material.set_shader_parameter(&"metallic_channel", _channel(source.metallic_texture_channel))
	material.set_shader_parameter(&"roughness_channel", _channel(source.roughness_texture_channel))
	if source.normal_enabled:
		material.set_shader_parameter(&"normal_texture", source.normal_texture)
		material.set_shader_parameter(&"normal_scale", source.normal_scale)
	return material


static func _channel(channel: BaseMaterial3D.TextureChannel) -> Vector4:
	"""A texture channel as the shader's dot-product mask."""
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return Vector4(1.0, 0.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0.0, 0.0, 0.0, 1.0)
	return Vector4(0.25, 0.25, 0.25, 0.25)


# --- the selected ------------------------------------------------------------------------------------

static func _xray_material() -> ShaderMaterial:
	"""The selected residents' see-through silhouette (selected_xray.gdshader), in the selection's brass."""
	var material := ShaderMaterial.new()
	material.shader = XRAY_SHADER
	material.set_shader_parameter(&"colour", Color(Palette.BRASS, XRAY_ALPHA))
	return material


func _keep_xray(below: bool) -> void:
	"""Each selected resident (not in the underground view) wears the silhouette; nobody else does."""
	if _cast == null or _command == null:
		return
	for i: int in mini(_cast.actor_count(), _xray_on.size()):
		var on: int = 1 if not below and _command.is_selected(i) else 0
		if on != _xray_on[i]:
			_xray_on[i] = on
			set_xray(_cast.actor(i), _xray if on == 1 else null)


static func set_xray(actor: Node, overlay: Material) -> int:
	"""Put `overlay` (null: none) on a resident's body meshes -- its skinned ones, or every mesh of a
	placeholder that has none. Returns how many meshes took it."""
	var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
	var skinned: bool = false
	for node: Node in meshes:
		skinned = skinned or (node as MeshInstance3D).skin != null
	var count: int = 0
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.skin != null or not skinned:
			mesh.material_overlay = overlay
			count += 1
	return count


# --- prewarm (demo_prewarm.gd add_frame_step) --------------------------------------------------------

func begin_prewarm() -> void:
	"""Build each look's fade material from its model and draw one sample of each -- below the focus, in the
	view but behind the ground -- with every resident wearing the silhouette, for the prewarm's frames."""
	var below: Vector3 = _rig.focus() + Vector3.DOWN * PREWARM_DEPTH_M
	for look: int in StandScript.LOOK_KEYS.size():
		var mesh: MeshInstance3D = _first_mesh(_look_node(look))
		if mesh == null:
			continue
		var sample := MeshInstance3D.new()
		sample.mesh = mesh.mesh
		sample.material_override = fade_material_for(mesh)
		add_child(sample)
		sample.global_position = below + Vector3.RIGHT * float(look)
		sample.set_instance_shader_parameter(PARAM_FADE, 0.5)
		sample.set_instance_shader_parameter(PARAM_BASE, below.y)
		_samples.append(sample)
	for i: int in (_cast.actor_count() if _cast != null else 0):
		set_xray(_cast.actor(i), _xray)


func end_prewarm() -> void:
	"""Free the samples and take the silhouette off again (but from the selected)."""
	for sample: Node3D in _samples:
		sample.queue_free()
	_samples.clear()
	for i: int in (_cast.actor_count() if _cast != null else 0):
		if i >= _xray_on.size() or _xray_on[i] == 0:
			set_xray(_cast.actor(i), null)


func _look_node(look: int) -> Node3D:
	"""A visible tree node of `look` (null: none)."""
	for t: int in _stand.count():
		if _stand.look[t] == look and _view != null and _view.tree_visible(t):
			return _view.tree_node(t)
	return null


# --- read-back (checks) ------------------------------------------------------------------------------

func fade_of(t: int) -> float:
	"""How far tree `t`'s crown is thinned now (0..1)."""
	return _fade[t]


func faded_count() -> int:
	"""How many trees are fading in or out now."""
	return _active_count


func material_count() -> int:
	"""How many fade materials have been made (one per tree model)."""
	return _materials.size()


func xray_on(actor_index: int) -> bool:
	"""Whether a resident wears the silhouette."""
	return actor_index < _xray_on.size() and _xray_on[actor_index] == 1
