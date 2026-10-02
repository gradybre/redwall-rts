extends "res://test/framework/test_case.gd"
## Tree crowns kept out of the camera's way (demo/camera/canopy_clear.gd, canopy_math.gd, decision 0301,
## review F53): the crown volumes, the eye's clearance (demo_camera.gd CLEARANCE), the choice of crowns to
## thin, the fade materials and the selected residents' silhouette. Placeholder trees -- no staged assets.

const Math := preload("res://demo/camera/canopy_math.gd")
const CanopyScript := preload("res://demo/camera/canopy_clear.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")

const WOOD: int = 60
const EPS: float = 0.001

var _nodes: Array[Object] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func tolerates_outside_tree() -> bool:
	"""Its node fixtures are never inside the scene tree (test_case.gd ENGINE DIAGNOSTICS)."""
	return true


func after_each() -> void:
	"""Free every node a test made."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _one_crown(look: int, at: Vector2, size: float) -> PackedFloat32Array:
	"""A packed array holding one crown."""
	var crowns := PackedFloat32Array()
	crowns.resize(Math.STRIDE)
	Math.set_crown(crowns, 0, look, at, size, 0.0)
	return crowns


func _canopy(trees: Array[Dictionary]) -> Array:
	"""[canopy, rig, stand, view]: these trees drawn (placeholders) and kept out of a fresh rig's way."""
	var stand := StandScript.new()
	assert_true(stand.bind_into(trees, WOOD, 1, _read), "bound")
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var view := _keep(ViewScript.new()) as ViewScript
	view.configure(stand, func(_p: int) -> Node3D: return null, world.make_piece, ServicesScript.new().props)
	view.sync(1, 7)
	var rig := _keep(CameraScript.new()) as CameraScript
	var canopy := _keep(CanopyScript.new()) as CanopyScript
	canopy.configure(rig, stand, view, null, null)
	return [canopy, rig, stand, view]


func _oak_at(at: Vector2, size: float) -> Dictionary:
	"""One mature oak placement."""
	return {"key": &"oak_mature", "at": at, "yaw": 0.0, "size": size}


# --- the crown maths ---------------------------------------------------------------------------------

func test_the_eye_direction_is_the_orbit_rigs_own() -> void:
	"""eye_direction(yaw, pitch) points from the focus to where demo_camera.gd puts the eye."""
	var rig := _keep(CameraScript.new()) as CameraScript
	for k: int in 5:
		rig._target_focus = Vector3(float(k), 0.0, -2.0 * float(k))
		rig._target_yaw = 1.3 * float(k) - 2.0
		rig._target_pitch = deg_to_rad(30.0 + 10.0 * float(k))
		rig._target_distance = 12.0
		rig.snap()
		var eye: Vector3 = (rig.transform * rig.camera().transform).origin
		var expected: Vector3 = Math.eye_direction(rig._yaw, rig._pitch)
		assert_true((eye - rig.focus()).normalized().is_equal_approx(expected), "pose %d" % k)


func test_a_crown_is_an_ellipsoid_cut_at_its_base() -> void:
	"""contains: inside the oak's crown at its widest, outside beyond it, and not below its base even
	inside the ellipsoid; `grow` widens it."""
	var crowns := _one_crown(StandScript.LOOK_OAK, Vector2(10.0, 0.0), 1.0)
	var middle := Vector3(10.0, Math.CROWN_CENTRE_M[0], 0.0)
	assert_true(Math.contains(crowns, 0, middle), "the middle")
	assert_true(Math.contains(crowns, 0, middle + Vector3(Math.CROWN_RADIUS_M[0] - 0.1, 0.0, 0.0)), "just inside the side")
	assert_false(Math.contains(crowns, 0, middle + Vector3(Math.CROWN_RADIUS_M[0] + 0.1, 0.0, 0.0)), "just outside the side")
	assert_false(Math.contains(crowns, 0, Vector3(10.0, Math.CROWN_BASE_M[0] - 0.1, 0.0)), "under the base: the trunk")
	assert_true(Math.contains(crowns, 0, middle + Vector3(Math.CROWN_RADIUS_M[0] + 0.1, 0.0, 0.0), 0.3), "grown")
	var none := _one_crown(StandScript.LOOK_OAK, Vector2(10.0, 0.0), 0.0)
	assert_false(Math.contains(none, 0, Vector3(10.0, 0.0, 0.0)), "no crown drawn: nothing inside")


func test_a_ray_spans_a_crown_between_its_entry_and_exit() -> void:
	"""ray_span along +X through the crown's middle: in at the near side, out at the far side; a ray
	rising from under the base enters at the base plane; a ray that misses spans nothing."""
	var crowns := _one_crown(StandScript.LOOK_OAK, Vector2(0.0, 0.0), 1.0)
	var r: float = Math.CROWN_RADIUS_M[0]
	var mid_y: float = Math.CROWN_CENTRE_M[0]
	var span: Vector2 = Math.ray_span(crowns, 0, Vector3(-20.0, mid_y, 0.0), Vector3.RIGHT)
	assert_almost_equal(span.x, 20.0 - r, "in at the near side")
	assert_almost_equal(span.y, 20.0 + r, "out at the far side")
	var up: Vector2 = Math.ray_span(crowns, 0, Vector3(1.0, 0.0, 0.0), Vector3.UP)
	assert_almost_equal(up.x, Math.CROWN_BASE_M[0], "rising: in at the base")
	assert_almost_equal(Math.ray_enters(crowns, 0, Vector3(1.0, mid_y, 0.0), Vector3.UP), 0.0, "starting inside: 0")
	assert_equal(Math.ray_enters(crowns, 0, Vector3(-20.0, 30.0, 0.0), Vector3.RIGHT), Math.MISS, "above it: a miss")
	assert_equal(Math.ray_enters(crowns, 0, Vector3(-20.0, 1.0, 0.0), Vector3.RIGHT), Math.MISS, "under the base: a miss")


func test_a_falling_ray_leaves_at_the_base() -> void:
	"""ray_span on a ray falling through the crown's middle: out where it crosses the base plane, not the
	ellipsoid's bottom."""
	var crowns := _one_crown(StandScript.LOOK_OAK, Vector2(0.0, 0.0), 1.0)
	var span: Vector2 = Math.ray_span(crowns, 0, Vector3(0.0, 20.0, 0.0), Vector3.DOWN)
	assert_almost_equal(span.y, 20.0 - Math.CROWN_BASE_M[0], "out at the base")
	assert_almost_equal(span.x, 20.0 - Math.CROWN_CENTRE_M[0] - Math.CROWN_HALF_HEIGHT_M[0], "in at the top")


func test_a_sight_line_crosses_only_what_it_reaches() -> void:
	"""segment_crosses: through the crown yes; stopping short of it, or passing under its base, no."""
	var crowns := _one_crown(StandScript.LOOK_BEECH, Vector2(0.0, 0.0), 1.0)
	var y: float = Math.CROWN_CENTRE_M[1]
	assert_true(Math.segment_crosses(crowns, 0, Vector3(-10.0, y, 0.0), Vector3(10.0, y, 0.0)), "through")
	assert_false(Math.segment_crosses(crowns, 0, Vector3(-10.0, y, 0.0), Vector3(-6.0, y, 0.0)), "short of it")
	assert_false(Math.segment_crosses(crowns, 0, Vector3(-10.0, 1.0, 0.0), Vector3(10.0, 1.0, 0.0)), "under its base")


# --- the eye ---------------------------------------------------------------------------------------

func test_an_eye_in_the_open_is_left_alone() -> void:
	"""No crown holds the eye: the asked distance, whatever crowns the line passes through."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	assert_almost_equal(canopy.allowed_distance(Vector3(0.0, 0.0, 0.0), 0.0, deg_to_rad(60.0), 30.0), 30.0, "over the crown")
	assert_almost_equal(canopy.allowed_distance(Vector3(40.0, 0.0, 0.0), 0.0, deg_to_rad(30.0), 11.0), 11.0, "far from it")


func test_an_eye_inside_a_crown_moves_out_past_its_far_side() -> void:
	"""The review's case in miniature: focus at an oak's foot, pitch 30, 7 m -- the eye would sit in the
	crown. It is moved out along its own line beyond the crown's far side, EYE_MARGIN_M clear."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var focus := Vector3.ZERO
	var pitch: float = deg_to_rad(30.0)
	var direction: Vector3 = Math.eye_direction(PI / 2.0, pitch)
	assert_true(canopy.crown_holding(focus + direction * 7.0) >= 0, "7 m in: inside the crown")
	var allowed: float = canopy.allowed_distance(focus, PI / 2.0, pitch, 7.0)
	var exit: float = Math.ray_span(canopy._eye_crowns, 0, focus, direction).y
	assert_almost_equal(allowed, exit + CanopyScript.EYE_MARGIN_M, "past the far side")
	assert_true(canopy.crown_holding(focus + direction * allowed) < 0, "and outside every crown")


func test_an_eye_that_cannot_get_out_comes_in_under_the_crown() -> void:
	"""A low line through a long row of overlapping crowns: getting out the far side would take more than
	MAX_PULLS crowns (or MAX_PUSH_M), so the eye comes in short of the first crown's near side instead,
	never nearer the focus than EYE_FLOOR_M."""
	var trees: Array[Dictionary] = []
	for k: int in 8:
		trees.append(_oak_at(Vector2(8.0 * float(k + 1), 0.0), 1.0))
	var made: Array = _canopy(trees)
	var canopy: CanopyScript = made[0]
	var focus := Vector3.ZERO
	var pitch: float = deg_to_rad(12.0)
	var direction: Vector3 = Math.eye_direction(PI / 2.0, pitch)
	assert_true(canopy.crown_holding(focus + direction * 10.0) >= 0, "10 m out: inside the first crown")
	var allowed: float = canopy.allowed_distance(focus, PI / 2.0, pitch, 10.0)
	var entry: float = Math.ray_span(canopy._eye_crowns, 0, focus, direction).x
	assert_almost_equal(allowed, maxf(entry - CanopyScript.EYE_MARGIN_M, CanopyScript.EYE_FLOOR_M), "short of the near side")
	assert_true(allowed < 10.0 and allowed >= CanopyScript.EYE_FLOOR_M, "in, not past the floor (%.2f)" % allowed)
	assert_true(canopy.crown_holding(focus + direction * allowed) < 0, "and outside every crown")


func test_the_eye_never_comes_nearer_than_the_floor() -> void:
	"""A row of crowns too deep to get out of (more than MAX_PULLS of them along the line), whose near side
	is closer than EYE_FLOOR_M: pulled in, to the floor."""
	var trees: Array[Dictionary] = []
	for k: int in 16:
		trees.append(_oak_at(Vector2(0.8 * float(k) + 3.0, 0.0), 1.0))
	var made: Array = _canopy(trees)
	var canopy: CanopyScript = made[0]
	var pitch: float = deg_to_rad(40.0)
	var direction: Vector3 = Math.eye_direction(PI / 2.0, pitch)
	assert_true(Math.ray_span(canopy._eye_crowns, 0, Vector3.ZERO, direction).x - CanopyScript.EYE_MARGIN_M < CanopyScript.EYE_FLOOR_M, "the near side is inside the floor")
	assert_true(canopy.crown_holding(direction * 9.0) >= 0, "9 m out: in a crown")
	assert_almost_equal(canopy.allowed_distance(Vector3.ZERO, PI / 2.0, pitch, 9.0), CanopyScript.EYE_FLOOR_M, "the floor")


func test_the_rig_moves_the_drawn_eye_at_once_and_keeps_the_zoom() -> void:
	"""demo_camera.gd CLEARANCE: the clearance moves the DRAWN distance the same frame; the zoom target is
	the player's, untouched; with the crown gone the eye eases back to it."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var rig: CameraScript = made[1]
	var stand: StandScript = made[2]
	rig._target_focus = Vector3.ZERO
	rig._target_yaw = PI / 2.0
	rig._target_pitch = deg_to_rad(30.0)
	rig._target_distance = 7.0
	rig.snap()
	assert_true(rig.distance() > 7.0 and canopy.crown_holding(rig.focus() + Math.eye_direction(rig._yaw, rig._pitch) * rig.distance()) < 0, "snapped clear (%.2f)" % rig.distance())
	assert_almost_equal(rig.target_distance(), 7.0, "the zoom target kept")
	assert_true(stand.grub_into(0, _read) or stand.fell_into(0, 1, Vector2.RIGHT, false, _read), "the tree is gone")
	(made[3] as ViewScript).sync(1, 9)
	canopy.refresh_crowns()
	for frame: int in 120:
		rig.step(1.0 / 60.0)
	assert_true(absf(rig.distance() - 7.0) < 0.01, "eased back to the zoom (%.3f)" % rig.distance())


# --- the sight lines and the fades -----------------------------------------------------------------

func test_only_the_crowns_in_the_way_are_thinned() -> void:
	"""Three oaks: one between the eye and the focus, one beside the line, one far off. Only the first is
	wanted; after enough frames it is fully thinned with the fade material; nothing else changes."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 10.0), 1.0), _oak_at(Vector2(15.0, 10.0), 1.0),
		_oak_at(Vector2(-40.0, -40.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var view: ViewScript = made[3]
	var eye := Vector3(0.0, 6.0, 25.0)
	for frame: int in 30:
		canopy.update(eye, Vector3.ZERO, 1.0 / 30.0)
	assert_almost_equal(canopy.fade_of(0), 1.0, "the crown in the way")
	assert_almost_equal(canopy.fade_of(1), 0.0, "beside the line")
	assert_almost_equal(canopy.fade_of(2), 0.0, "far off")
	var mesh: MeshInstance3D = CanopyScript._first_mesh(view.tree_node(0))
	assert_true(mesh.material_override is ShaderMaterial, "drawn with the fade material")
	assert_null(CanopyScript._first_mesh(view.tree_node(1)).material_override, "the others keep their own")


func test_a_fade_eases_in_and_out_and_hands_back_the_material() -> void:
	"""FADE_RATE per second each way; back at 0 the tree has its own material again, and its `fade` back at 0 (the
	seasons draw every tree in the same shader, decision 0551: a stale fade would leave a dither)."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var view: ViewScript = made[3]
	var eye := Vector3(0.0, 6.0, 25.0)
	canopy.update(eye, Vector3.ZERO, 0.1)
	assert_almost_equal(canopy.fade_of(0), CanopyScript.FADE_RATE * 0.1, "a tenth of a second in")
	for frame: int in 10:
		canopy.update(eye, Vector3.ZERO, 0.1)
	var away := Vector3(60.0, 6.0, 25.0)
	canopy.update(away, Vector3(60.0, 0.0, 0.0), 0.1)
	assert_almost_equal(canopy.fade_of(0), 1.0 - CanopyScript.FADE_RATE * 0.1, "easing out")
	for frame: int in 10:
		canopy.update(away, Vector3(60.0, 0.0, 0.0), 0.1)
	assert_equal(canopy.faded_count(), 0, "no fade live")
	assert_null(CanopyScript._first_mesh(view.tree_node(0)).material_override, "its own material back")
	assert_equal(float(CanopyScript._first_mesh(view.tree_node(0)).get_instance_shader_parameter(CanopyScript.PARAM_FADE)),
		0.0, "its fade back at 0")


func test_the_selected_residents_sight_lines_thin_their_crowns() -> void:
	"""A crown between the eye and a selected resident is thinned though the focus is clear of it."""
	var made: Array = _canopy([_oak_at(Vector2(20.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var eye := Vector3(20.0, 6.0, 25.0)
	canopy.set_targets(PackedVector3Array([Vector3(20.0, 0.5, 0.0)]))
	for frame: int in 10:
		canopy.update(eye, Vector3(-30.0, 0.0, 0.0), 0.1)
	assert_almost_equal(canopy.fade_of(0), 1.0, "the resident's crown")


func test_a_crown_at_the_lens_is_thinned() -> void:
	"""A crown within NEAR_FADE_M of the eye, off every sight line, is thinned too."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var side: float = Math.CROWN_RADIUS_M[0] + CanopyScript.NEAR_FADE_M * 0.5
	for frame: int in 10:
		canopy.update(Vector3(side, Math.CROWN_CENTRE_M[0], 0.0), Vector3(side + 20.0, 0.0, 0.0), 0.1)
	assert_almost_equal(canopy.fade_of(0), 1.0, "thinned at the lens")


func test_no_more_than_max_faded_crowns_are_thinned() -> void:
	"""A long sight line through a row of crowns thins MAX_FADED of them at most."""
	var trees: Array[Dictionary] = []
	for k: int in 14:
		trees.append(_oak_at(Vector2(0.0, -6.0 * float(k)), 1.0))
	var made: Array = _canopy(trees)
	var canopy: CanopyScript = made[0]
	for frame: int in 3:
		canopy.update(Vector3(0.0, 6.0, 10.0), Vector3(0.0, 6.0, -90.0), 0.1)
	assert_equal(canopy.faded_count(), CanopyScript.MAX_FADED, "bounded")


func test_nothing_fades_in_the_underground_view() -> void:
	"""Below (decision 0206's U view) no crown is wanted, and a live fade eases out."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	for frame: int in 10:
		canopy.update(Vector3(0.0, 6.0, 25.0), Vector3.ZERO, 0.1, true)
	assert_almost_equal(canopy.fade_of(0), 0.0, "nothing thinned")


func test_one_fade_material_per_tree_model_carrying_its_maps() -> void:
	"""fade_material_for: the same fade material for every tree drawn with the same material; it carries
	the source's albedo colour and maps (make_fade_material)."""
	var made: Array = _canopy([_oak_at(Vector2(0.0, 10.0), 1.0), _oak_at(Vector2(30.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var view: ViewScript = made[3]
	var a: ShaderMaterial = canopy.fade_material_for(CanopyScript._first_mesh(view.tree_node(0)))
	var b: ShaderMaterial = canopy.fade_material_for(CanopyScript._first_mesh(view.tree_node(1)))
	assert_true(a == b, "shared")
	assert_equal(canopy.material_count(), 1, "one made")
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.2, 0.4, 0.1)
	source.albedo_texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	source.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	var fade: ShaderMaterial = CanopyScript.make_fade_material(source)
	assert_true((fade.get_shader_parameter(&"albedo_color") as Color).is_equal_approx(source.albedo_color), "the colour")
	assert_true(fade.get_shader_parameter(&"albedo_texture") == source.albedo_texture, "the albedo map")
	assert_true((fade.get_shader_parameter(&"roughness_channel") as Vector4).is_equal_approx(Vector4(0, 1, 0, 0)), "the roughness channel")


func test_the_silhouette_goes_on_the_body_only() -> void:
	"""set_xray: a creature's skinned meshes take the overlay (not a carried prop); a placeholder's meshes
	all do; null takes it off."""
	var actor := _keep(Node3D.new()) as Node3D
	var body := MeshInstance3D.new()
	body.skin = Skin.new()
	var prop := MeshInstance3D.new()
	actor.add_child(body)
	actor.add_child(prop)
	var overlay := ShaderMaterial.new()
	assert_equal(CanopyScript.set_xray(actor, overlay), 1, "one body mesh")
	assert_true(body.material_overlay == overlay and prop.material_overlay == null, "the body only")
	CanopyScript.set_xray(actor, null)
	assert_null(body.material_overlay, "taken off")
	var placeholder := _keep(Node3D.new()) as Node3D
	var capsule := MeshInstance3D.new()
	placeholder.add_child(capsule)
	assert_equal(CanopyScript.set_xray(placeholder, overlay), 1, "a placeholder's mesh")


# --- the live frame (the game's own path: _process, the selection, the U view, the prewarm) ---------

func _live(trees: Array[Dictionary]) -> Array:
	"""[canopy, rig, stand, view, cast, command]: _canopy's trees, a placeholder cast and a real command
	layer (outside the tree, the frame reads the rig's and the actors' own transforms)."""
	var made: Array = _canopy(trees)
	var world := _keep(DemoWorldScript.new()) as DemoWorldScript
	var cast := _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var command := _keep(CommandScript.new()) as CommandScript
	command.configure(cast, _keep(Camera3D.new()) as Camera3D, null, ServicesScript.new())
	(made[0] as CanopyScript).configure(made[1], made[2], made[3], cast, command)
	return [made[0], made[1], made[2], made[3], cast, command]


static func _pose(rig: CameraScript, focus: Vector3, yaw_deg: float, pitch_deg: float, distance: float) -> void:
	"""Snap the rig to a pose."""
	rig._target_focus = focus
	rig._target_yaw = deg_to_rad(yaw_deg)
	rig._target_pitch = deg_to_rad(pitch_deg)
	rig._target_distance = distance
	rig.snap()


func test_the_frame_thins_a_crown_over_a_selected_resident() -> void:
	"""_process aims a sight line at each selected resident's chest: an oak between the eye and a selected
	mouse thins though the line to the focus passes clear of it; unselected, it does not."""
	var made: Array = _live([_oak_at(Vector2(20.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var cast: DemoCastScript = made[4]
	var command: CommandScript = made[5]
	_pose(made[1], Vector3(50.0, 0.0, -5.0), -45.0, 10.4, 43.1)
	cast.actor(0).position = Vector3(20.0, 0.0, 0.0)
	for frame: int in 10:
		canopy._process(0.1)
	assert_almost_equal(canopy.fade_of(0), 0.0, "nobody selected: the focus's line is clear of it")
	command.select(PackedInt32Array([0]))
	for frame: int in 10:
		canopy._process(0.1)
	assert_equal(canopy._target_count, 1, "one resident aimed at")
	assert_almost_equal(canopy.fade_of(0), 1.0, "the crown over the selected mouse")


func test_the_silhouette_follows_the_selection_and_the_underground_view() -> void:
	"""A selected resident wears the silhouette; in the underground view nobody does; out of it, again."""
	var made: Array = _live([_oak_at(Vector2(60.0, 60.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var cast: DemoCastScript = made[4]
	var command: CommandScript = made[5]
	command.select(PackedInt32Array([1]))
	canopy._process(0.1)
	assert_true(canopy.xray_on(1) and not canopy.xray_on(0), "the selected one")
	assert_not_null(CanopyScript._first_mesh(cast.actor(1)).material_overlay, "wearing it")
	command.tunnels().view.on = true
	canopy._process(0.1)
	assert_false(canopy.xray_on(1), "none in the underground view")
	assert_null(CanopyScript._first_mesh(cast.actor(1)).material_overlay, "taken off")
	command.tunnels().view.on = false
	canopy._process(0.1)
	assert_true(canopy.xray_on(1), "back on the surface")


func test_the_prewarm_leaves_only_the_selected_wearing_the_silhouette() -> void:
	"""begin_prewarm puts the silhouette on every resident; end_prewarm takes it off all but the selected."""
	var made: Array = _live([_oak_at(Vector2(0.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var cast: DemoCastScript = made[4]
	var command: CommandScript = made[5]
	command.select(PackedInt32Array([1]))
	canopy._process(0.1)
	canopy.begin_prewarm()
	for i: int in cast.actor_count():
		assert_not_null(CanopyScript._first_mesh(cast.actor(i)).material_overlay, "resident %d drawn with it" % i)
	canopy.end_prewarm()
	for i: int in cast.actor_count():
		var overlay: Material = CanopyScript._first_mesh(cast.actor(i)).material_overlay
		assert_true((overlay != null) == (i == 1), "resident %d %s" % [i, "keeps it" if i == 1 else "has none"])


func test_a_hidden_faded_tree_is_handed_back() -> void:
	"""A faded tree hidden (felled, replaced) gives its mesh its own material back the next frame."""
	var made: Array = _live([_oak_at(Vector2(0.0, 10.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var view: ViewScript = made[3]
	for frame: int in 5:
		canopy.update(Vector3(0.0, 6.0, 25.0), Vector3.ZERO, 0.1)
	assert_equal(canopy.faded_count(), 1, "fading")
	view.tree_node(0).visible = false
	canopy.update(Vector3(0.0, 6.0, 25.0), Vector3.ZERO, 0.1)
	assert_equal(canopy.faded_count(), 0, "released")
	assert_null(CanopyScript._first_mesh(view.tree_node(0)).material_override, "its own material")


func test_a_felled_tree_leaves_the_crowns_on_the_next_frame() -> void:
	"""The stand's revision moving is enough: the next update reads the crowns afresh (a felled oak's crown
	holds nothing), without waiting for the periodic refresh."""
	var made: Array = _live([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var stand: StandScript = made[2]
	var inside := Vector3(0.0, Math.CROWN_CENTRE_M[0], 0.0)
	canopy.update(Vector3(30.0, 6.0, 30.0), Vector3(30.0, 0.0, 0.0), 0.01)
	assert_true(canopy.crown_holding(inside) == 0, "standing: its crown")
	assert_true(stand.fell_into(0, 1, Vector2.RIGHT, false, _read), "felled")
	canopy.update(Vector3(30.0, 6.0, 30.0), Vector3(30.0, 0.0, 0.0), 0.01)
	assert_equal(canopy.crown_holding(inside), -1, "gone")


func test_the_rigs_own_frame_keeps_the_eye_out_of_a_crown() -> void:
	"""demo_camera.gd step(): the clearance applies every frame, not only on a snap."""
	var made: Array = _live([_oak_at(Vector2(0.0, 0.0), 1.0)])
	var canopy: CanopyScript = made[0]
	var rig: CameraScript = made[1]
	rig._target_focus = Vector3.ZERO
	rig._focus = Vector3.ZERO
	for value: Array in [[&"_target_yaw", PI / 2.0], [&"_yaw", PI / 2.0], [&"_target_pitch", deg_to_rad(30.0)],
			[&"_pitch", deg_to_rad(30.0)], [&"_target_distance", 7.0], [&"_distance", 7.0]]:
		rig.set(value[0], value[1])
	assert_true(canopy.crown_holding(Math.eye_direction(PI / 2.0, deg_to_rad(30.0)) * 7.0) >= 0, "7 m: inside")
	rig.step(1.0 / 60.0)
	var eye: Vector3 = Math.eye_direction(rig._yaw, rig._pitch) * rig.distance()
	assert_true(rig.distance() > 7.0 and canopy.crown_holding(eye) < 0, "the frame cleared it (%.2f)" % rig.distance())
