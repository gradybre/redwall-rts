extends "res://test/framework/test_case.gd"
## The underground revamp's P1, "bore look and traversal" (decision 0207; docs/design/underground_revamp.md
## §8 P1): the swept horseshoe bore and its build time, the drawn centreline, the ramps and their refusal,
## the stoop rule and the stoop modifier, walking a ramp along its slope, the cap's void field, the
## lanterns' pooled lights, the mouths, the dressing, the drying hook and the U view's environment. All
## over placeholders and skeletons built in code: nothing here needs staged assets.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const DressingScript := preload("res://demo/tunnel/bore_dressing.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const StoopScript := preload("res://demo/cast/stoop_modifier.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DT: float = 1.0 / 60.0
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
## The build budget of a 32 m bore (design §8 P1), and how many builds its median is taken over.
const BUILD_BUDGET_USEC: int = 2000
const BUILD_TRIALS: int = 7

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


static func _open_network(points: PackedInt32Array) -> GraphScript:
	"""A network with one open mouth-to-mouth tunnel along these (x, z) u points: on an empty graph its
	entry ramp is segment 0 (mouth row 0 at node A), its bore segment 1 and its exit ramp segment 2 (mouth
	row 1 at node B) -- or, at exactly 8 m, two ramps (0 and 1) sharing a foot."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	@warning_ignore("integer_division") network.add_into(points, points.size() / 2, 0, ref)
	_dig_piece(network, ref[2])
	return network


static func _open_space(points: PackedInt32Array) -> CastSpaceScript:
	"""A cast space whose graph holds one open tunnel along these points (segments as `_open_network`)."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var ref := PackedInt32Array([-1, 0, -1])
	@warning_ignore("integer_division") space.tunnels.add_into(points, points.size() / 2, 0, ref)
	_dig_piece(space.tunnels, ref[2])
	return space


static func _dig_piece(network: GraphScript, piece: int) -> void:
	"""Dig every segment of piece `piece` open, in dig order (start_dig turns each PLANNED one to DIGGING)."""
	var chain := PackedInt32Array()
	network.piece_segments_into(piece, chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)


# --- the profile ------------------------------------------------------------------------------

func test_the_profile_is_a_sixteen_point_horseshoe() -> void:
	"""16 points: a flat 1 m floor, walls bowing to 1.1 m at the springline, an arch to the 1.0 m crown;
	the widened bore 2 m across and 1.1 m up."""
	var standard := BoreMeshScript.profile(Rules.BORE_STANDARD)
	assert_equal(standard.size(), 16, "sixteen points")
	assert_equal(BoreMeshScript.PROFILE_VERTS, 16, "the profile's count")
	var lo := INF
	var hi := -INF
	var top := 0.0
	for p: Vector3 in standard:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		top = maxf(top, p.y)
	assert_almost_equal(hi - lo, 1.1, "1.1 m at its widest")
	assert_almost_equal(top, 1.0, "the crown 1.0 m over the floor")
	assert_almost_equal(standard[2].x - standard[14].x, 1.0, "a 1 m floor")
	var wide := BoreMeshScript.profile(Rules.BORE_WIDE)
	assert_almost_equal(wide[2].x - wide[14].x, 2.0, "the widened floor 2 m")
	assert_almost_equal(wide[8].y, Rules.crown_m(Rules.BORE_WIDE), "and its crown")
	assert_almost_equal(BoreMeshScript.width_share(0.0), 1.0, "the floor's half-width")
	assert_almost_equal(BoreMeshScript.width_share(BoreMeshScript.SPRING_SHARE), BoreMeshScript.BULGE, "widest at the springline")
	assert_almost_equal(BoreMeshScript.width_share(1.0), 0.0, "closed at the crown")
	assert_true(BoreMeshScript.width_share(1.01) < 0.0 and BoreMeshScript.width_share(-0.01) < 0.0, "nothing above or below")


func test_the_profile_s_normals_face_inward() -> void:
	"""Every normal points into the bore (toward its middle, half a crown up); the floor's straight up."""
	var points := BoreMeshScript.profile(Rules.BORE_STANDARD)
	var normals := BoreMeshScript.profile_normals(points)
	for k in points.size():
		var inward := Vector3(0.0, 0.5, 0.0) - points[k]
		assert_true(normals[k].dot(inward) > 0.0, "point %d faces in" % k)
	for k: int in [0, 1, 15]:
		assert_true(normals[k].is_equal_approx(Vector3.UP), "floor point %d faces up" % k)


func _straight_bore(metres: float, face: bool) -> ArrayMesh:
	"""A bore swept `metres` along +X, closed by a face wall when `face`."""
	var builder := BoreMeshScript.new()
	var curve := BoreCurveScript.new()
	var sample := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	curve.set_route(PackedVector2Array([Vector2.ZERO, Vector2(metres, 0.0)]), 0.6)
	builder.begin()
	var rings := roundi(metres / BoreMeshScript.RING_STEP_M) + 1
	for ring in rings:
		curve.sample(float(ring) * BoreMeshScript.RING_STEP_M, sample)
		builder.add_ring(ring, Vector3(sample[0].x, -1.25, sample[0].y), sample[1], Rules.BORE_STANDARD, BoreMeshScript.PLAIN, 0.0)
	if face:
		builder.add_face(Vector3(sample[0].x, -1.25, sample[0].y), sample[1], Rules.BORE_STANDARD)
	var mesh := ArrayMesh.new()
	builder.commit(mesh)
	return mesh


func test_a_swept_bore_holds_its_rings_and_faces_in() -> void:
	"""2 m at 4 rings a metre: 9 rings of 16 points, 8 bands of quads; the dig face (decision 0211) adds FACE_RINGS
	rings drawn in, their bands and a fan of 16 to its middle; every triangle is wound to face the way its normals do --
	inward."""
	var mesh := _straight_bore(2.0, true)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var face_rings := BoreMeshScript.FACE_RINGS
	assert_equal(points.size(), 9 * 16 + face_rings * 16 + 1, "9 rings, and the dig face's rings and middle (decision 0211)")
	assert_equal(indices.size(), 8 * 16 * 6 + (face_rings - 1) * 16 * 6 + 16 * 3, "8 bands, the face's bands and its fan")
	assert_equal((arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size(), points.size(), "a dig day a point")
	var wrong := 0
	@warning_ignore("integer_division") for t in indices.size() / 3:
		var a := points[indices[3 * t]]
		var face := (points[indices[3 * t + 1]] - a).cross(points[indices[3 * t + 2]] - a)
		if face.length_squared() > 1e-12 and face.dot(normals[indices[3 * t]]) >= 0.0:
			wrong += 1
	assert_equal(wrong, 0, "every triangle clockwise seen from inside: Godot's front face")


func test_the_rough_walls_are_rough_but_the_floor_is_flat() -> void:
	"""The jitter moves walls up to WALL_JITTER_M and every ring's width a little, but the floor's middle
	stays on the floor, so feet meet it."""
	var arrays := _straight_bore(4.0, false).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var profile := BoreMeshScript.profile(Rules.BORE_STANDARD)
	var moved := 0.0
	for ring in 17:
		assert_true(absf(points[ring * 16].y + 1.25) <= BoreMeshScript.FLOOR_JITTER_M + 1e-5, "ring %d's floor middle on the floor" % ring)
		moved = maxf(moved, absf(points[ring * 16 + 5].z - profile[5].x * BoreMeshScript.width_jitter(ring)))
	assert_true(moved > 0.01, "the walls are not a clean tube (%.3f m)" % moved)
	assert_true(BoreMeshScript.variant_of(3) != BoreMeshScript.variant_of(4), "neighbouring rings differ")


func test_a_32_m_bore_builds_in_under_2_ms() -> void:
	"""The design's budget: a 32 m bore -- 129 rings, 2,064 points -- swept, sampled and committed in under
	2 ms (the median of BUILD_TRIALS builds, headless)."""
	_straight_bore(1.0, false)
	var times := PackedInt64Array()
	var mesh: ArrayMesh = null
	for trial in BUILD_TRIALS:
		var start := Time.get_ticks_usec()
		mesh = _straight_bore(32.0, false)
		times.append(Time.get_ticks_usec() - start)
	times.sort()
	assert_equal(mesh.surface_get_array_len(0), 129 * 16, "129 rings of 16")
	@warning_ignore("integer_division") assert_less_than(float(times[BUILD_TRIALS / 2]), float(BUILD_BUDGET_USEC), "median build %d us" % times[BUILD_TRIALS / 2])


# --- the drawn centreline -------------------------------------------------------------------------

func test_the_centreline_follows_the_route_and_rounds_its_corners() -> void:
	"""Along a leg the drawn centreline is the route; round a right-angled corner it bends through a
	fillet -- inside the corner, its heading turning smoothly, never folding -- and comes back onto the
	next leg."""
	var curve := BoreCurveScript.new()
	curve.set_route(PackedVector2Array([Vector2.ZERO, Vector2(4.0, 0.0), Vector2(4.0, 4.0)]), 0.6)
	var out := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	curve.sample(1.0, out)
	assert_true(out[0].is_equal_approx(Vector2(1.0, 0.0)) and out[1].is_equal_approx(Vector2(1.0, 0.0)), "on the first leg")
	curve.sample(4.0, out)
	assert_true(out[0].distance_to(Vector2(4.0, 0.0)) > 0.1 and out[0].x < 4.0 and out[0].y > 0.0, "inside the corner (%s)" % out[0])
	assert_true(out[1].dot(Vector2(1.0, 1.0).normalized()) > 0.99, "heading half way round")
	var last := Vector2(1.0, 0.0)
	var along := 3.0
	while along <= 5.0:
		curve.sample(along, out)
		assert_true(out[1].dot(last) > 0.9, "no kink at %.2f m" % along)
		last = out[1]
		along += 0.05
	curve.sample(7.0, out)
	assert_true(out[0].is_equal_approx(Vector2(4.0, 3.0)), "back on the second leg")
	curve.rewind()
	curve.sample(0.5, out)
	assert_true(out[0].is_equal_approx(Vector2(0.5, 0.0)), "rewound")


# --- ramps -----------------------------------------------------------------------------------------

func test_a_ramp_is_never_steeper_than_one_in_two_and_a_half() -> void:
	"""Down 1.25 m over 4 m, eased at each end, nowhere steeper than 1:2.5, and the constants say so."""
	assert_equal(Rules.RAMP_RUN_U, 4096, "a 4 m ramp")
	assert_true(Rules.ramp_grade_ok(Rules.BORE_FLOOR_DEPTH_U, Rules.RAMP_RUN_U, Rules.RAMP_FILLET_U), "its straight at 1:2.5")
	assert_false(Rules.ramp_grade_ok(Rules.BORE_FLOOR_DEPTH_U, Rules.RAMP_RUN_U - 1, Rules.RAMP_FILLET_U), "a hair shorter is steeper")
	assert_almost_equal(Rules.BORE_FLOOR_DEPTH_M, Rules.to_m(Rules.BORE_FLOOR_DEPTH_U), "the depth in both units")
	var steepest := 0.0
	var mismatch := 0.0
	var at := 0.0
	while at <= 4.0:
		var measured := (Rules.ramp_depth_m(at + 0.001) - Rules.ramp_depth_m(at)) / 0.001
		steepest = maxf(steepest, measured)
		mismatch = maxf(mismatch, absf(Rules.ramp_slope(at + 0.0005) - measured))
		at += 0.01
	assert_true(mismatch < 1e-3, "the slope is the depth's own (%.5f)" % mismatch)
	assert_true(steepest <= 0.4 + 1e-4, "never steeper than 1:2.5 (%.4f)" % steepest)
	assert_true(steepest > 0.399, "and 1:2.5 on the straight")
	assert_almost_equal(Rules.ramp_depth_m(4.0), 1.25, "at the tunnels' depth")
	assert_almost_equal(Rules.ramp_slope(0.0), 0.0, "level at the mouth")
	assert_almost_equal(Rules.ramp_slope(4.0), 0.0, "and at the bottom")
	assert_almost_equal(Rules.floor_grade(1.0, 10.0), -Rules.ramp_slope(1.0), "going down from the entrance")
	assert_almost_equal(Rules.floor_grade(9.0, 10.0), Rules.ramp_slope(1.0), "coming up to the exit")
	assert_almost_equal(Rules.portal_m(Rules.BORE_STANDARD), 2.9375, "the bore goes under where the ramp is a crown deep")


func test_a_route_too_short_for_its_ramps_is_refused_with_words() -> void:
	"""A route under 8 m would need its ramps steeper than 1:2.5: refused, and the reason says so; 8 m is
	dug; a route under the water says that first."""
	assert_equal(Rules.ramp_refusal(8191), Rules.REFUSE_RAMP_TOO_STEEP, "7.999 m")
	assert_equal(Rules.ramp_refusal(8192), Rules.REFUSE_NONE, "8 m")
	assert_true(Rules.reason_text(Rules.REFUSE_RAMP_TOO_STEEP).contains("1:2.5"), "the grade in the words")
	var plan := PlanScript.new()
	assert_equal(plan.try_add(0, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "entrance")
	assert_equal(plan.try_add(7000, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "a 6.8 m leg laid")
	assert_equal(plan.route_reason(BOUNDS_U, PackedInt32Array()), Rules.REFUSE_RAMP_TOO_STEEP, "refused on confirming")
	assert_true(plan.undo(), "taken back")
	assert_equal(plan.try_add(8192, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "an 8 m leg")
	assert_equal(plan.route_reason(BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "accepted")
	var wet := PlanScript.new()
	wet.water_crossing = func(_a: Vector2i, _b: Vector2i, _clear: int) -> bool: return true
	wet.points_u = PackedInt32Array([0, 0, 3000, 0])
	wet.count = 2
	assert_equal(wet.route_reason(BOUNDS_U, PackedInt32Array()), Rules.REFUSE_UNDER_WATER, "the water first")


# --- the stoop -------------------------------------------------------------------------------------

func test_each_species_stoops_by_its_height_in_a_standard_bore() -> void:
	"""Head 0.1 m under the 1.0 m crown: the mole (0.9 m) upright; a mouse (1.0 m) 0.1 m; a squirrel (1.15 m)
	0.25 m; the otter, beaver and badger as far as a body goes, 35% of their height."""
	var crown: int = Rules.BORE_CROWNS_U[Rules.BORE_STANDARD]
	var mole := Rules.stoop_drop_u(Rules.to_u(0.9), crown)
	var mouse := Rules.stoop_drop_u(Rules.to_u(1.0), crown)
	var squirrel := Rules.stoop_drop_u(Rules.to_u(1.15), crown)
	assert_equal(mole, 0, "the mole walks upright")
	assert_equal(mouse, 102, "a mouse stoops a little (0.1 m)")
	assert_equal(squirrel, 256, "a squirrel more (0.25 m)")
	for height: float in [1.49, 1.4, 2.55]:
		var drop := Rules.stoop_drop_u(Rules.to_u(height), crown)
		@warning_ignore("integer_division") assert_equal(drop, Rules.to_u(height) * Rules.STOOP_MAX_PERMILLE / 1000, "%.2f m stoops as far as it can" % height)
		assert_true(drop > squirrel, "more than a squirrel")
	@warning_ignore("integer_division") assert_equal(Rules.stoop_drop_u(Rules.to_u(2.55), Rules.BORE_CROWNS_U[Rules.BORE_WIDE]), Rules.to_u(2.55) * 350 / 1000,
		"the badger stoops hard even widened: the level's cover holds the crown down")
	assert_equal(Rules.stoop_drop_u(Rules.to_u(1.0), Rules.BORE_CROWNS_U[Rules.BORE_WIDE]), 0, "a mouse upright in a widened bore")


static func _rig() -> Skeleton3D:
	"""A 1 m, mouse-shaped rig with Meshy's bone names: hips, two legs to the feet, the spine (Spine02 at
	the hips up to Spine), neck, head and its top -- facing +Z, feet on y = 0."""
	var rig := Skeleton3D.new()
	var bones: Array = [["Hips", "", Vector3(0.0, 0.47, 0.0)], ["LeftUpLeg", "Hips", Vector3(0.09, -0.02, 0.0)],
		["LeftLeg", "LeftUpLeg", Vector3(0.0, -0.2, 0.03)], ["LeftFoot", "LeftLeg", Vector3(0.0, -0.2, -0.03)],
		["RightUpLeg", "Hips", Vector3(-0.09, -0.02, 0.0)], ["RightLeg", "RightUpLeg", Vector3(0.0, -0.2, 0.03)],
		["RightFoot", "RightLeg", Vector3(0.0, -0.2, -0.03)], ["Spine02", "Hips", Vector3(0.0, 0.07, 0.0)],
		["Spine01", "Spine02", Vector3(0.0, 0.06, 0.0)], ["Spine", "Spine01", Vector3(0.0, 0.07, 0.0)],
		["neck", "Spine", Vector3(0.0, 0.05, 0.0)], ["Head", "neck", Vector3(0.0, 0.04, 0.0)],
		["head_end", "Head", Vector3(0.0, 0.22, 0.02)]]
	for bone: Array in bones:
		var index := rig.add_bone(bone[0])
		if bone[1] != "":
			rig.set_bone_parent(index, rig.find_bone(bone[1]))
		rig.set_bone_rest(index, Transform3D(Basis.IDENTITY, bone[2]))
	rig.reset_bone_poses()
	return rig


func _stooped_rig() -> Array:
	"""A rig built in code with its stoop: [rig, stoop, rest head top, rest feet, rest left knee]. (Poses are
	read composed up the chain: a skeleton's cached global poses are not refreshed outside the main loop.)"""
	var rig: Skeleton3D = _keep(_rig())
	var stoop := StoopScript.new()
	rig.add_child(stoop)
	assert_true(stoop.setup(rig, Basis.IDENTITY, 1.0), "the rig's bones found")
	var feet: Array[Transform3D] = [StoopScript.global_pose(rig, rig.find_bone("LeftFoot")), StoopScript.global_pose(rig, rig.find_bone("RightFoot"))]
	return [rig, stoop, StoopScript.global_pose(rig, rig.find_bone("head_end")).origin, feet,
		StoopScript.global_pose(rig, rig.find_bone("LeftLeg")).origin]


func _check_feet(rig: Skeleton3D, feet: Array[Transform3D]) -> void:
	"""Each foot where it was, turned as it was, to a millimetre."""
	for side in 2:
		var now := StoopScript.global_pose(rig, rig.find_bone(["LeftFoot", "RightFoot"][side]))
		assert_true(now.origin.distance_to(feet[side].origin) < 0.001, "foot %d kept its place (%.5f)" % [side, now.origin.distance_to(feet[side].origin)])
		assert_true(now.basis.is_equal_approx(feet[side].basis), "and its turn")


func test_the_stoop_lowers_the_head_and_keeps_the_feet() -> void:
	"""A 0.1 m stoop brings the head's top down 0.1 m (the hips 0.03 of it, the spine the rest), bent
	forward, the knees forward and the neck taking half the bend back; each foot keeps its place and turn.
	No pose switches the modifier off."""
	var made := _stooped_rig()
	var rig: Skeleton3D = made[0]
	var stoop: StoopScript = made[1]
	var top: Vector3 = made[2]
	var head := rig.find_bone("head_end")
	stoop.set_pose(0.1, 0.0)
	assert_true(stoop.active, "switched on with a pose")
	stoop.apply(rig)
	var lowered := StoopScript.global_pose(rig, head).origin
	assert_true(absf(top.y - lowered.y - 0.1) < 0.0015, "the head 0.1 m down (%.4f)" % (top.y - lowered.y))
	assert_true(lowered.z > top.z, "bent forward, not back")
	assert_true(StoopScript.global_pose(rig, rig.find_bone("LeftLeg")).origin.z > (made[4] as Vector3).z, "the knee bends forward")
	var bend := stoop.bend_for(0.1 - stoop.hip_drop(0.1))
	var tilt := StoopScript.global_pose(rig, rig.find_bone("Head")).basis.y.normalized().angle_to(Vector3.UP)
	assert_true(tilt > bend * 0.3 and tilt < bend * 0.7, "the neck takes half the bend back (%.3f of %.3f)" % [tilt, bend])
	assert_almost_equal(stoop.hip_drop(0.1), 0.03, "the hips take 30%")
	_check_feet(rig, made[3])
	stoop.set_pose(0.0, 0.0)
	assert_false(stoop.active, "switched off with none")


func test_a_lean_tilts_the_spine_alone() -> void:
	"""A lean with no stoop switches the modifier on and turns the spine only: leaning back (negative)
	takes the head back, the hips and feet stay put; a rig without the bones is never switched on."""
	var made := _stooped_rig()
	var rig: Skeleton3D = made[0]
	var stoop: StoopScript = made[1]
	var top: Vector3 = made[2]
	var hips := StoopScript.global_pose(rig, rig.find_bone("Hips")).origin
	stoop.set_pose(0.0, -0.2)
	assert_true(stoop.active, "a lean alone is a pose")
	stoop.apply(rig)
	var head := StoopScript.global_pose(rig, rig.find_bone("head_end")).origin
	assert_true(head.z < top.z - 0.05, "leaning back takes the head back (%.3f)" % (head.z - top.z))
	assert_true(StoopScript.global_pose(rig, rig.find_bone("Hips")).origin.is_equal_approx(hips), "the hips stay")
	_check_feet(rig, made[3])
	var bare := Skeleton3D.new()
	bare.add_bone("Root")
	var none := StoopScript.new()
	assert_false(none.setup(bare, Basis.IDENTITY, 1.0), "no spine: refused")
	none.set_pose(0.1, 0.2)
	assert_false(none.active, "and never switched on")
	none.free()
	bare.free()


func test_a_resident_on_a_ramp_leans_its_spine_back_by_half_its_pitch() -> void:
	"""The actor hands its stoop half the ramp's pitch back: going down the entry ramp (segment 0; 2 m from
	its mouth is on its 1:2.5 straight), nose down, a lean back."""
	var space := _open_space(PackedInt32Array([0, 0, 10240, 0]))
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor.setup_placeholder(0, space, 3)
	actor.brain._start_travel(0, 2.0, 4.0)
	var rig: Skeleton3D = _keep(_rig())
	var stoop := StoopScript.new()
	rig.add_child(stoop)
	stoop.setup(rig, Basis.IDENTITY, 1.0)
	actor._stoop = stoop
	actor.ease_stoop(0.3)
	assert_almost_equal(stoop.lean_rad, -atan(0.4) * DemoActorScript.LEAN_BACK_SHARE, "half the pitch, back")
	assert_true(stoop.drop_m > 0.0 and stoop.active, "and stooping")


func test_a_deeper_stoop_bends_further_and_is_capped() -> void:
	"""The table's bend grows with the drop, and stops at MAX_BEND_RAD; the hips' share stops at 7% of the
	body's height."""
	var rig: Skeleton3D = _keep(_rig())
	var stoop := StoopScript.new()
	rig.add_child(stoop)
	stoop.setup(rig, Basis.IDENTITY, 1.0)
	assert_almost_equal(stoop.bend_for(0.0), 0.0, "none for none")
	assert_true(stoop.bend_for(0.05) < stoop.bend_for(0.15), "deeper, further")
	assert_almost_equal(stoop.bend_for(5.0), StoopScript.MAX_BEND_RAD, "capped")
	var between := (stoop._drops[10] + stoop._drops[11]) * 0.5
	var step := StoopScript.MAX_BEND_RAD / float(StoopScript.TABLE)
	assert_true(absf(stoop.bend_for(between) - step * 10.5) < step * 0.1, "read between the table's rows")
	assert_almost_equal(stoop.hip_drop(1.0), 0.07, "the hips at most 7% of 1 m")


func test_a_resident_below_eases_into_its_stoop_on_the_demo_clock() -> void:
	"""A 1 m resident walking a bore (segment 1, the level bore between the ramps' feet) eases to its 0.1 m
	stoop over 0.3 s of demo time, holds it while no time passes, and straightens on the surface."""
	var space := _open_space(PackedInt32Array([0, 0, 10240, 0]))
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor.setup_placeholder(0, space, 7)
	actor.brain._start_travel(1, 0.5, 1.5)
	assert_almost_equal(actor.stoop_target_m(), Rules.to_m(102), "a mouse's drop below")
	actor.ease_stoop(0.15)
	assert_true(actor.stoop_now_m() > 0.0 and actor.stoop_now_m() < actor.stoop_target_m(), "half way through the ease")
	var held := actor.stoop_now_m()
	actor.ease_stoop(0.0)
	assert_almost_equal(actor.stoop_now_m(), held, "paused: held")
	actor.ease_stoop(0.2)
	assert_almost_equal(actor.stoop_now_m(), actor.stoop_target_m(), "fully stooped after 0.3 s")
	actor.brain._set_underground(false)
	assert_almost_equal(actor.stoop_target_m(), 0.0, "upright on the surface")
	actor.ease_stoop(0.15)
	assert_true(actor.stoop_now_m() > 0.0, "straightening, not snapped up")
	actor.ease_stoop(0.3)
	assert_almost_equal(actor.stoop_now_m(), 0.0, "and straightened")


# --- walking a ramp ------------------------------------------------------------------------------

func test_a_ramp_is_walked_along_its_slope_and_the_body_tilts_with_it() -> void:
	"""On the 1:2.5 straight the flat step is walk speed times the slope's cosine (so the 3D pace is the
	walk's and the clip's stride matches it) and the body pitches nose down going down, nose up coming
	up; on the level neither. A 10 m tunnel: the entry ramp (0) falls from its mouth at node A, the bore
	(1) is flat, the exit ramp (2) rises to its mouth at node B -- walked forward (A to B), it goes up."""
	var actor := _walker_in(_open_space(PackedInt32Array([0, 0, 10240, 0])))
	var brain := actor.brain
	brain._start_travel(0, 2.0, 4.0)
	assert_almost_equal(brain.slope_share(), 1.0 / sqrt(1.16), "the cosine of 1:2.5")
	assert_almost_equal(brain.pitch, atan(0.4), "nose down going down")
	actor._apply_transform()
	assert_almost_equal(actor.rotation.x, brain.pitch, "the body tilts with it")
	var from := brain.bore_along_m()
	brain.step(0.1)
	assert_true(absf(brain.bore_along_m() - from - 0.1 * brain.walk_speed / sqrt(1.16)) < 1e-4, "0.1 s at walk speed along the slope")
	brain._start_travel(1, 1.0, 0.0)
	assert_almost_equal(brain.slope_share(), 1.0, "level in the bore")
	assert_almost_equal(brain.pitch, 0.0, "upright")
	brain._start_travel(0, 2.0, 0.0)
	assert_almost_equal(brain.pitch, -atan(0.4), "nose up coming back up the entry ramp")
	brain._start_travel(2, 2.0, 4.0)
	assert_almost_equal(brain.slope_share(), 1.0 / sqrt(1.16), "the exit ramp's straight, 2 m from its mouth")
	assert_almost_equal(brain.pitch, -atan(0.4), "nose up walking the exit ramp forward, to its mouth at B")
	brain._set_underground(false)
	assert_almost_equal(brain.pitch, 0.0, "level again on the surface")


func _walker_in(space: CastSpaceScript) -> DemoActorScript:
	"""A placeholder resident of `space` who fits a bore, standing at the origin."""
	var actor: DemoActorScript = _keep(DemoActorScript.new())
	actor.setup_placeholder(0, space, 3)
	space.tunnels.set_fit(actor.brain.index, true)
	actor.brain.start_at(Vector2.ZERO, 0.0, -1, -1)
	return actor


# --- the cap's void field ------------------------------------------------------------------------

func test_the_void_keeps_the_nearest_bore_its_rise_and_crown() -> void:
	"""A disc's distance field reaches 1.5 floor half-widths; a nearer disc wins, with its rise and crown;
	`is_dug` is the level's floor only, so a ramp's disc high up is not."""
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	cap.stamp_disc(Vector2(0.0, 0.0), 0.5, Vector2.ZERO, 0.0, 1.0)
	assert_true(cap.void_at(Vector2(0.06, 0.06), CapScript.VOID_RHO) > 0.85, "the middle")
	assert_true(absf(cap.void_at(Vector2(0.69, 0.06), CapScript.VOID_RHO) - (1.0 - 0.69 / 0.5 / 2.0)) < 0.03, "0.69 m out")
	assert_almost_equal(cap.void_at(Vector2(0.81, 0.06), CapScript.VOID_RHO), 0.0, "past the reach")
	assert_true(absf(cap.void_at(Vector2(0.06, 0.06), CapScript.VOID_CROWN) - 0.5) < 0.01, "a 1 m crown")
	cap.stamp_disc(Vector2(3.0, 0.0), 0.5, Vector2.ZERO, 1.0, 1.0)
	assert_true(absf(cap.void_at(Vector2(3.06, 0.06), CapScript.VOID_RISE) - 0.8) < 0.01, "a ramp's floor 1 m up")
	assert_false(cap.is_dug(Vector2(3.06, 0.06)), "not the level's floor")
	assert_true(cap.is_dug(Vector2(0.06, 0.06)), "the level's floor")
	cap.stamp_disc(Vector2(3.5, 0.0), 0.5, Vector2.ZERO, 0.0, 1.0)
	assert_true(cap.void_at(Vector2(3.31, 0.06), CapScript.VOID_RISE) < 0.01, "the nearer disc's rise wins")
	cap.stamp_disc(Vector2(3.5, 0.0), 1.0, Vector2.ZERO, 0.0, 1.1)
	assert_true(cap.void_at(Vector2(4.31, 0.06), CapScript.VOID_RHO) > 0.5, "a wider disc reaches further")


func test_a_dug_tunnel_is_stamped_down_its_ramps_too() -> void:
	"""An open 10 m tunnel, each of its three segments built: the level bore (segment 1, 4..6 m) is the
	level's floor; the ramps are stamped with their floor's rise (the cap's walk down the view ray opens
	them where they pass under it) -- the entry ramp's falling from its mouth at node A, the exit ramp's
	from its mouth at node B."""
	var network := _open_network(PackedInt32Array([0, 0, 10240, 0]))
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	bores.set_view(cap, PrewarmScript.new())
	for slot in 3:
		bores.build(slot, network.length_m(slot), 0.0)
	assert_true(cap.is_dug(Vector2(5.0, 0.0)), "the middle")
	assert_false(cap.is_dug(Vector2(1.0, 0.0)), "not 1 m down the entry ramp: it is higher")
	assert_false(cap.is_dug(Vector2(9.0, 0.0)), "nor 1 m down the exit ramp")
	for probe: Array in [[0, 1.0, 1.0], [2, 3.0, 9.0]]:
		var rise := cap.void_at(Vector2(probe[2], 0.0), CapScript.VOID_RISE) * CapScript.RISE_RANGE_M
		var floor_rise: float = Rules.BORE_FLOOR_DEPTH_M + network.floor_y_at(probe[0], probe[1])
		assert_true(absf(rise - floor_rise) < 0.05, "x = %.0f m stamped with its rise (%.3f m of %.3f)" % [probe[2], rise, floor_rise])
	assert_almost_equal(network.floor_y_at(2, 3.0), -Rules.ramp_depth_m(1.0), "the exit ramp 1 m from its mouth")


# --- the bore view: chunks and the drying hook ----------------------------------------------------

func test_only_the_chunk_at_the_face_is_rebuilt() -> void:
	"""A 36 m bore (the middle segment of a 44 m tunnel, between its two 4 m ramps) dug a step at a time:
	each rebuild sweeps the chunk the face is in (and, once, the one it left), never the whole bore; a
	change of state sweeps every chunk. Its chunks are made only when it is first built."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 45056, 0]), 2, 0, ref)
	assert_almost_equal(network.length_m(1), 36.0, "segment 1: the bore, 44 m less two 4 m ramps")
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	assert_null(bores.chunk(1, 0), "no chunk before it is first dug")
	bores.build(1, 20.0, 0.0)
	assert_equal(bores.chunk_builds, 2, "20 m: two chunks built")
	bores.build(1, 20.25, 0.0)
	assert_equal(bores.chunk_builds, 3, "a step: only the face's chunk")
	bores.build(1, 32.5, 0.0)
	assert_equal(bores.chunk_builds, 5, "into the third chunk: the second (its face gone) and the third")
	assert_true(bores.chunk(1, 2).visible and not bores.chunk(1, 3).visible, "three chunks drawn")
	assert_null(bores.chunk(0, 0), "the ramps, never built, have none")
	network.close(1, GraphScript.CLOSED_FLOODED, 0, 4096)
	bores.build(1, 32.5, 0.0)
	assert_equal(bores.chunk_builds, 8, "flooded: all three again")
	assert_equal(BoreViewScript.ring_count(2.0), 9, "2 m: 9 rings on the lattice")
	assert_equal(BoreViewScript.ring_count(2.1), 10, "and one at a face off it")
	assert_equal(BoreViewScript.last_chunk(66), 1, "65 lattice rings and a face: two chunks")


func test_each_ring_carries_the_day_it_was_dug() -> void:
	"""The drying hook: steps dug on day 0 carry day 0, steps dug a day later carry day 1, and the earth
	is told the calendar's day. (Segment 0, a 10 m tunnel's 4 m entry ramp, dug to 2 m and then to its
	foot.)"""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([0, 0, 10240, 0]), 2, 0, ref)
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var calendar := CalendarScript.new()
	bores.set_calendar(calendar)
	bores.build(0, 2.0, 0.0)
	calendar.tick = 18000
	bores.tick()
	bores.build(0, 4.0, 0.0)
	assert_almost_equal(bores.dug_day(0, 4), 0.0, "1 m in: day 0")
	assert_almost_equal(bores.dug_day(0, 12), 1.0, "3 m in: day 1")
	assert_almost_equal(float(BoreViewScript.earth_material().get_shader_parameter(&"now_days")), 1.0, "the earth told")
	var uv2: PackedVector2Array = (bores.chunk(0, 0).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_almost_equal(uv2[4 * 16].x, 0.0, "ring 4's points: day 0")
	assert_almost_equal(uv2[12 * 16].x, 1.0, "ring 12's: day 1")


# --- dressing --------------------------------------------------------------------------------------

func test_stones_bed_in_the_walls_and_roots_come_only_near_trees() -> void:
	"""A 16 m tunnel's level bore (segment 1, 4..12 m along +X): stones along its walls, the same on a
	rebuild; no roots with no tree; a mature oak beside its middle puts roots in the bore near its trunk.
	A segment is dressed in its own MultiMeshes, made when it is first dressed."""
	var network := _open_network(PackedInt32Array([0, 0, 16384, 0]))
	var dressing: DressingScript = _keep(DressingScript.new())
	dressing.configure()
	assert_null(dressing.stones(1), "nothing made before it is dressed")
	dressing.place(1, network, 0.0, 8.0, 0.0)
	var stones := dressing.stones(1).multimesh.visible_instance_count
	assert_true(stones > 3, "stones in the walls (%d)" % stones)
	assert_equal(dressing.roots(1).multimesh.visible_instance_count, 0, "no tree, no roots")
	assert_null(dressing.stones(0), "the ramps, not dressed, have none")
	dressing.place(1, network, 0.0, 8.0, 0.0)
	assert_equal(dressing.stones(1).multimesh.visible_instance_count, stones, "the same stones again")
	assert_equal(dressing.set_trees([{"key": &"oak_mature", "at": Vector2(8.0, 1.5), "size": 1.0}] as Array[Dictionary]), 1, "an oak")
	dressing.place(1, network, 0.0, 8.0, 0.0)
	assert_true(dressing.roots(1).multimesh.visible_instance_count > 0, "roots near it")
	assert_true(dressing.root_chance(Vector2(8.0, 1.5)) > 0.99 and dressing.root_chance(Vector2(-30.0, 0.0)) == 0.0, "likeliest at the trunk")
	assert_equal(dressing.stones(1).layers, Layers.UNDERGROUND, "below")


# --- lanterns --------------------------------------------------------------------------------------

func test_the_lanterns_light_the_nearest_spots_up_to_the_cap() -> void:
	"""More lantern spots than lights: MAX_LIGHTS light the ones nearest the focus, the rest stay dark;
	a far move of the focus hands them on; the lights light only the underground."""
	var lanterns: LanternsScript = _keep(LanternsScript.new())
	lanterns.configure()
	for slot in 3:
		var spots := PackedVector3Array()
		for k in 16:
			spots.append(Vector3(float(slot) * 30.0 + float(k), -0.8, 0.0))
		lanterns.set_spots(slot, spots)
	assert_equal(lanterns.spot_count(), 48, "48 lanterns hang")
	lanterns.update(Vector3(0.0, -1.25, 0.0))
	assert_equal(lanterns.lit_count(), LanternsScript.MAX_LIGHTS, "only MAX_LIGHTS lit")
	assert_equal(lanterns.find_nearest(Vector3.ZERO), LanternsScript.MAX_LIGHTS, "and only as many spots kept")
	for k in range(1, LanternsScript.MAX_LIGHTS):
		assert_true(lanterns.nearest(k).length() >= lanterns.nearest(k - 1).length(), "nearest first (%d)" % k)
	assert_true(lanterns.nearest(LanternsScript.MAX_LIGHTS - 1).x < 46.0, "the 32 nearest of 48: the first two tunnels'")
	lanterns.set_spots(3, PackedVector3Array([Vector3(200.0, -0.8, 0.0)]))
	assert_equal(lanterns.find_nearest(Vector3.ZERO), LanternsScript.MAX_LIGHTS, "an odd count too")
	lanterns.set_spots(3, PackedVector3Array())
	assert_true(lanterns.light(0).position.x < 1.0, "the nearest first")
	lanterns.update(Vector3(75.0, -1.25, 0.0))
	assert_true(lanterns.light(0).position.x > 70.0, "handed on to the far lanterns")
	var count := lanterns.assignments
	lanterns.update(Vector3(75.5, -1.25, 0.0))
	assert_equal(lanterns.assignments, count, "a small move hands nothing on")
	assert_equal(lanterns.light(0).light_cull_mask, Layers.UNDERGROUND, "lighting only below")
	assert_false(lanterns.light(0).shadow_enabled, "shadowless")


func test_the_lanterns_flicker_gently_and_hold_while_paused() -> void:
	"""Each light wavers within 8% of its energy on the demo clock, lights out of step; no time, no change. (Its spots
	hung long before, so their bloom is over: decision 0211.)"""
	var lanterns: LanternsScript = _keep(LanternsScript.new())
	lanterns.configure(DemoClockScript.new())
	lanterns._time = -10.0
	lanterns.set_spots(0, PackedVector3Array([Vector3.ZERO, Vector3(2.0, 0.0, 0.0)]))
	var t := 0.0
	while t < 3.0:
		for k in 2:
			assert_true(absf(LanternsScript.wave(t, k)) <= 1.0, "within the waver at %.2f" % t)
		t += 0.07
	assert_true(LanternsScript.wave(0.4, 0) != LanternsScript.wave(0.4, 1), "out of step")
	var widest := 0.0
	for step in 60:
		lanterns._time = float(step) * 0.05
		lanterns.flicker()
		widest = maxf(widest, absf(lanterns.light(0).light_energy / LanternsScript.ENERGY - 1.0))
	assert_true(widest <= LanternsScript.FLICKER + 1e-6 and widest > LanternsScript.FLICKER * 0.5, "a gentle waver, up to 8%% (%.3f)" % widest)
	lanterns.flicker()
	var energy := lanterns.light(0).light_energy
	assert_true(absf(energy / LanternsScript.ENERGY - 1.0) <= LanternsScript.FLICKER + 1e-6, "within 8%")
	lanterns._process(DT)
	assert_almost_equal(lanterns.light(0).light_energy, energy, "a paused clock: held")


func test_a_lit_tunnel_hangs_its_lanterns_under_the_ground_and_lights_them() -> void:
	"""A lit 12 m tunnel is three 4 m segments (entry ramp 0, bore 1, exit ramp 2), each lit and hung on
	its own: one lantern per started LANTERN_SPACING_M (4 m) of each, so three, each past its ramp's
	portal (the entry ramp's from its mouth at A, the exit ramp's from its mouth at B; the bore's all under
	the ground), each a light spot; braces are drawn with the cutaway, which cuts under their cap beam."""
	var network := _open_network(PackedInt32Array([0, 0, 12288, 0]))
	for slot in 3:
		network.set_lit(slot)
		network.set_braced(slot)
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, null)
	marks.refresh()
	_check_one_lantern_a_segment(marks)
	assert_equal(marks.lights.spot_count(), 3, "three lights to give")
	assert_equal(marks.lights.lit_count(), 3, "and lit")
	var cut: ShaderMaterial = marks.frames(0).material_override
	assert_almost_equal(float(cut.get_shader_parameter(&"cut_y")), Layers.FLOOR_Y_M + MarksScript.BRACE_CUT_M, "cut over the floor")
	assert_true(MarksScript.BRACE_CUT_M < Rules.crown_m(Rules.BORE_STANDARD) * MarksScript.FRAME_CROWN_SHARE, "under the cap beam")
	for slot in 3:
		network.lit[slot] = 0
	network.revision += 1
	marks.refresh()
	assert_equal(marks.lights.lit_count(), 0, "unlit: dark")


func _check_one_lantern_a_segment(marks: MarksScript) -> void:
	"""Each 4 m segment of a lit 12 m tunnel hangs one lantern: the entry ramp's mid-way from its portal to
	its foot, the bore's at its middle, the exit ramp's mid-way from its foot to its portal -- both ramps'
	past their portals, under the ground."""
	var portal := Rules.portal_m(Rules.BORE_STANDARD)
	for slot in 3:
		assert_equal(marks.lanterns(slot).multimesh.visible_instance_count, 1, "segment %d: one lantern" % slot)
	var entry := marks.lantern_along(0, 0, 1)
	assert_almost_equal(entry, portal + 0.5 * (4.0 - portal), "the entry ramp's")
	assert_almost_equal(marks.lantern_along(1, 0, 1), 2.0, "the bore's")
	var exit := marks.lantern_along(2, 0, 1)
	assert_almost_equal(exit, 0.5 * (4.0 - portal), "the exit ramp's")
	assert_true(entry > portal and 4.0 - exit > portal, "both ramps' lanterns under the ground")


# --- mouths ----------------------------------------------------------------------------------------

func test_a_mouth_is_a_gateway_over_its_ramp_s_cutting() -> void:
	"""A mouth (per mouth row: the entrance row 0, the exit row 1): a cutting down its ramp as far as it is
	open (to the portal) and the gateway over it, on the surface, facing down the ramp; while the entry
	shaft is dug, only part of the cutting and no gateway. The exit mouth opens only when its ramp breaks
	out at it, facing back into the tunnel."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 0, 10240]), 2, 0, ref)
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(space.tunnels, space)
	space.tunnels.advance(ref[0], ref[1], 1500000)
	overlay.refresh()
	var mouth := overlay.hole(0)
	assert_true(mouth.visible, "opening")
	assert_false((mouth.get_child(OverlayScript.MOUTH_GATEWAY) as Node3D).visible, "no gateway while the shaft is dug")
	assert_true(overlay.mouth_open_m(0) < Rules.portal_m(Rules.BORE_STANDARD), "part of the cutting")
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	overlay.refresh()
	assert_false(overlay.hole(1).visible, "the entry ramp open, the exit not yet broken out")
	_dig_piece(space.tunnels, ref[2])
	overlay.refresh()
	_check_open_mouths(overlay)
	assert_true(MouthScript.GATE_HEIGHT_M > 1.15 + 0.1, "a squirrel walks under the lintel")


func _check_open_mouths(overlay: OverlayScript) -> void:
	"""A tunnel dug along +Z, all open: its entrance (row 0) cut down to the portal under its gateway,
	facing down the route; its exit (row 1) broken out and facing back into it; both on the surface."""
	var mouth := overlay.hole(0)
	assert_almost_equal(overlay.mouth_open_m(0), Rules.portal_m(Rules.BORE_STANDARD), "down to the portal")
	assert_true((mouth.get_child(OverlayScript.MOUTH_GATEWAY) as Node3D).visible, "the gateway up")
	assert_almost_equal(mouth.rotation.y, 0.0, "facing +Z, down the route")
	assert_true(overlay.hole(1).visible, "broken out at the exit")
	assert_almost_equal(absf(overlay.hole(1).rotation.y), PI, "the exit faces back into it")
	for part: Node in mouth.get_children() + overlay.hole(1).get_children():
		assert_equal((part as VisualInstance3D).layers, Layers.SURFACE, "%s on the surface" % part.name)


# --- the U view's environment and the prewarm ------------------------------------------------------

func test_the_u_view_has_its_own_environment_and_the_surface_keeps_its() -> void:
	"""U sets the underground environment on the camera -- dark, lit only by its low ambient, with SSAO,
	glow and a haze -- and leaving it gives the camera none (the WorldEnvironment again); the prewarm draws
	in it."""
	var camera: Camera3D = _keep(Camera3D.new())
	var view: ViewScript = _keep(ViewScript.new())
	view.configure(camera, GroundScript.new(), WaterScript.new())
	assert_null(camera.environment, "surface: the world's")
	view.set_on(true)
	assert_equal(camera.environment, view.environment, "below: its own")
	var env := view.environment
	assert_true(env.ssao_enabled and env.glow_enabled and env.fog_enabled, "SSAO, glow, haze")
	assert_equal(env.background_mode, Environment.BG_COLOR, "dark earth behind, no sky")
	assert_true(env.ambient_light_energy < 0.6 and env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "a low ambient of its own")
	view.set_on(false)
	assert_null(camera.environment, "back to the world's")
	view.begin_prewarm()
	assert_equal(camera.environment, view.environment, "the prewarm draws in it")
	view.end_prewarm()
	assert_null(camera.environment, "and gives it back")


func test_every_new_underground_material_is_registered_for_the_prewarm() -> void:
	"""The bores' earth, the hubs' earth, the stone and root, the brace's cutaway with its mesh, the lantern
	and its glow: all in the registry once the overlay and the marks are handed the view."""
	var network := _open_network(PackedInt32Array([0, 0, 12288, 0]))
	var space := CastSpaceScript.new()
	space.setup([], [])
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(network, space)
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, null)
	var cap: CapScript = _keep(CapScript.new())
	cap.configure(GroundScript.new(), WaterScript.new())
	var prewarm := PrewarmScript.new()
	overlay.set_view(cap, prewarm)
	marks.register(prewarm)
	assert_true(prewarm.has_material(BoreViewScript.earth_material()), "the earth")
	assert_true(prewarm.has_material(BoreViewScript.hub_material()), "the hubs' earth")
	assert_true(prewarm.has_material(DressingScript.stone_mesh().surface_get_material(0)), "the stone")
	assert_true(prewarm.has_material(DressingScript.root_mesh().surface_get_material(0)), "the root")
	assert_true(prewarm.has_material(marks.frames(0).material_override), "the brace's cutaway")
	overlay.refresh()
	for node: GeometryInstance3D in [overlay.bore(0), overlay.bores.dressing.stones(0), marks.frames(0), marks.lanterns(0), marks.glows(0)]:
		assert_true(prewarm.covers(node), "%s covered" % node.name)


# --- mutation-driven edges -------------------------------------------------------------------------

func test_each_ring_is_jittered_along_its_normals() -> void:
	"""A ring's walls stray from the profile by up to WALL_JITTER_M along their normals (at least a
	centimetre somewhere), its floor by at most FLOOR_JITTER_M; one ring alone draws nothing."""
	var builder := BoreMeshScript.new()
	builder.begin()
	builder.add_ring(3, Vector3.ZERO, Vector2(1.0, 0.0), Rules.BORE_STANDARD, BoreMeshScript.PLAIN, 0.0)
	var mesh := ArrayMesh.new()
	assert_equal(builder.commit(mesh), 0, "one ring: nothing")
	assert_equal(mesh.get_surface_count(), 0, "no surface")
	builder.add_ring(4, Vector3(0.25, 0.0, 0.0), Vector2(1.0, 0.0), Rules.BORE_STANDARD, BoreMeshScript.PLAIN, 0.0)
	builder.commit(mesh)
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var base := BoreMeshScript.profile(Rules.BORE_STANDARD)
	var widest := 0.0
	for k in 16:
		var off := Vector2(points[k].z - base[k].x * BoreMeshScript.width_jitter(3), points[k].y - base[k].y)
		var limit := BoreMeshScript.FLOOR_JITTER_M if base[k].y < 1e-6 else BoreMeshScript.WALL_JITTER_M
		assert_true(off.length() <= limit + 1e-5, "point %d within its jitter (%.4f)" % [k, off.length()])
		widest = maxf(widest, off.length())
	assert_true(widest > 0.01, "rough (%.4f)" % widest)


func test_a_fillet_never_takes_more_than_its_share_of_a_short_leg() -> void:
	"""A corner after a 1 m leg rounds over at most 0.45 m of it, and a fillet's middle is the quadratic's
	(a quarter of the way from the chord to the corner)."""
	var curve := BoreCurveScript.new()
	var out := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	curve.set_route(PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0), Vector2(1.0, 10.0)]), 3.0)
	curve.sample(0.5, out)
	assert_true(out[0].is_equal_approx(Vector2(0.5, 0.0)), "still on the short leg (%s)" % out[0])
	curve.set_route(PackedVector2Array([Vector2.ZERO, Vector2(4.0, 0.0), Vector2(4.0, 4.0)]), 0.6)
	curve.sample(4.0, out)
	var t := 0.6 * tan(PI / 4.0) / cos(PI / 4.0)
	assert_true(out[0].distance_to(Vector2(4.0 - t * 0.25, t * 0.25)) < 1e-4, "the fillet's middle (%s)" % out[0])


func test_chunks_hold_whole_bands_and_the_widened_and_flooded_rings_show() -> void:
	"""65 lattice rings are one chunk's 64 bands; a widening draws its reach twice as wide; a flooded
	bore's rings carry the flood in their colour. (The 10 m level bore of an 18 m tunnel, segment 1,
	along +X: a ring's floor edge, profile point 2, lies across it in z.)"""
	assert_equal(BoreViewScript.last_chunk(65), 0, "64 bands: one chunk")
	assert_equal(BoreViewScript.last_chunk(2), 0, "one band")
	var network := _open_network(PackedInt32Array([0, 0, 18432, 0]))
	assert_almost_equal(network.length_m(1), 10.0, "a 10 m bore")
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	bores.build(1, 10.0, 3.0)
	var points: PackedVector3Array = (bores.chunk(1, 0).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_true(absf(points[4 * 16 + 2].z) > 0.9, "1 m in, widened: a 2 m floor (%.3f)" % points[4 * 16 + 2].z)
	assert_true(absf(points[20 * 16 + 2].z) < 0.6, "5 m in, not yet: a 1 m floor")
	network.close(1, GraphScript.CLOSED_FLOODED, 0, 10240)
	bores.build(1, 10.0, 3.0)
	var colours: PackedColorArray = (bores.chunk(1, 0).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_equal(colours[20 * 16].r, 1.0, "flooded")


func test_stones_bed_only_where_the_bore_is_under_the_ground() -> void:
	"""No stone sits on a mouth's ramp where the bore is an open cutting. An 8 m tunnel is two 4 m ramps
	sharing a foot (segments 0 and 1): each is deep enough only near that foot -- the entry ramp at its
	far end from its mouth (node A), the exit ramp at its near end (its mouth is node B) -- so each holds at
	most two stones a step there, far fewer than its 17 steps would give. (Instance transforms do not read
	back headless; the count does.)"""
	var network := _open_network(PackedInt32Array([0, 0, 8192, 0]))
	var dressing: DressingScript = _keep(DressingScript.new())
	dressing.configure()
	var deep_steps := 0
	for slot in 2:
		dressing.place(slot, network, 0.0, 4.0, 0.0)
		var deep := PackedInt32Array()
		for step in 17:
			if DressingScript.dressed_at(network.floor_y_at(slot, float(step) * 0.25), Rules.BORE_STANDARD):
				deep.append(step)
		assert_true(deep.size() > 0 and deep.size() < 9, "ramp %d: only its deep half is (%d steps)" % [slot, deep.size()])
		assert_equal(deep.has(16), slot == 0, "ramp %d: its node B end deep only when that is the foot" % slot)
		assert_equal(deep.has(0), slot == 1, "ramp %d: its node A end deep only when that is the foot" % slot)
		var expected := 0
		for step: int in deep:
			for salt: int in [0, 2]:
				expected += 1 if DressingScript.unit(network.generation[slot] * 7919 + step, salt) < DressingScript.STONE_CHANCE else 0
		assert_equal(dressing.stones(slot).multimesh.visible_instance_count, expected, "ramp %d: the dice of those steps only" % slot)
		deep_steps += deep.size()
	var long := _open_network(PackedInt32Array([0, 0, 32768, 0]))
	assert_equal(long.seg_kind[1], GraphScript.SEG_BORE, "a 32 m tunnel's segment 1: a 24 m level bore")
	dressing.place(1, long, 0.0, long.length_m(1), 0.0)
	assert_true(dressing.stones(1).multimesh.visible_instance_count > 2 * deep_steps, "a long bore holds more")


func test_an_instanced_sample_is_drawn_with_its_override() -> void:
	"""A MultiMesh registered with an override (the braces' cutaway) is sampled with that override."""
	var prewarm := PrewarmScript.new()
	var box := BoxMesh.new()
	var cut := ShaderMaterial.new()
	prewarm.add_multimesh(box, cut)
	prewarm.add_multimesh(box, cut)
	assert_equal(prewarm.mesh_count(), 1, "once")
	var parent: Node3D = _keep(Node3D.new())
	prewarm.build_samples(parent, Vector3.ZERO)
	var samples := parent.find_children("*", "MultiMeshInstance3D", false, false)
	assert_equal(samples.size(), 1, "one instanced sample")
	assert_equal((samples[0] as MultiMeshInstance3D).material_override, cut, "with its override")


func _turned_floor_triangles(network: GraphScript, slot: int) -> Vector2i:
	"""Sweep segment `slot` of `network` and count its level floor's triangles, and those turned over
	(facing down: culled away)."""
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	bores.build(slot, network.length_m(slot), 0.0)
	var arrays := (bores.chunk(slot, 0).mesh as ArrayMesh).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var counts := Vector2i.ZERO
	@warning_ignore("integer_division") for t in indices.size() / 3:
		var a := points[indices[3 * t]]
		var b := points[indices[3 * t + 1]]
		var c := points[indices[3 * t + 2]]
		var face := (b - a).cross(c - a)
		if a.y < -1.2 and b.y < -1.2 and c.y < -1.2 and face.length_squared() > 1e-10:
			counts.x += 1
			counts.y += 1 if face.y >= 0.0 else 0
	return counts


func test_a_right_angled_corner_folds_nothing_and_walkers_follow_the_bore() -> void:
	"""An L tunnel, (0, 0) to (8, 0) to (8, 8): its level bore (segment 1, from the entry ramp's foot at
	(4, 0) round the corner to the exit ramp's foot at (8, 4), 8 m with the corner 4 m in), standard and
	widened: every triangle of the swept level floor keeps its winding round the corner (none turned over,
	so none culled away), and a walker and a lantern at the corner stand on the bore's own drawn centreline
	-- the lantern as far out from it as on a leg."""
	for bore: int in [Rules.BORE_STANDARD, Rules.BORE_WIDE]:
		var network := _open_network(PackedInt32Array([0, 0, 8192, 0, 8192, 8192]))
		assert_equal(network.point_count[1], 3, "class %d: the corner lies in the bore" % bore)
		network.set_bore(1, bore)
		var counts := _turned_floor_triangles(network, 1)
		assert_true(counts.x > 100, "class %d: the level floor's triangles (%d)" % [bore, counts.x])
		assert_equal(counts.y, 0, "class %d: no floor triangle turned over" % bore)
		var out := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		var curve := BoreCurveScript.of(network, 1)
		curve.sample(4.0, out)
		var space := CastSpaceScript.new()
		space.setup([], [])
		space.tunnels = network
		var brain := BrainScript.new()
		brain.configure(space, 1.0, 0.25, 3, {&"walk": 2.0})
		brain.stand_in_bore(1, 4.0, true)
		assert_true(brain.position.is_equal_approx(out[0]), "class %d: the walker on the drawn centreline" % bore)
		assert_true(out[0].distance_to(Vector2(8.0, 0.0)) > 0.1, "which cuts inside the corner")
		_check_lantern_on_curve(network, curve, bore)


func _check_lantern_on_curve(network: GraphScript, curve: BoreCurveScript, bore: int) -> void:
	"""A lantern at the bore's corner (4 m in) hangs as far out from the drawn centre as one on a straight
	leg (7 m in: past the widest fillet, which reaches 1.74 m either side of the corner)."""
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, null)
	var out := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	var straight := marks.lantern_transform(1, 7.0, true).origin
	curve.sample(7.0, out)
	var on_leg := Vector2(straight.x, straight.z).distance_to(out[0])
	var hung := marks.lantern_transform(1, 4.0, true).origin
	curve.sample(4.0, out)
	var across := Vector2(hung.x, hung.z).distance_to(out[0])
	assert_true(absf(across - on_leg) < 0.01, "class %d: the lantern as far out as on a leg (%.3f, %.3f)" % [bore, across, on_leg])


func test_the_shared_curve_follows_its_tunnel_and_samples_back_and_forth() -> void:
	"""One curve a segment: the L tunnel's bore (segment 1, from (4, 0) round (8, 0) to (8, 4)) sampled
	forward then back without a rewind still finds the right leg, and a widening rebuilds it with the wider
	bend (its fillet's middle 0.25 x its tangent x sqrt 2 from the corner: 0.5 m standard, 0.61 m wide)."""
	var network := _open_network(PackedInt32Array([0, 0, 8192, 0, 8192, 8192]))
	var curve := BoreCurveScript.of(network, 1)
	var out := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	curve.sample(7.0, out)
	curve.sample(1.0, out)
	assert_true(out[0].is_equal_approx(Vector2(5.0, 0.0)), "back on the first leg (%s)" % out[0])
	curve.sample(4.0, out)
	var standard := out[0]
	network.set_bore(1, Rules.BORE_WIDE)
	BoreCurveScript.of(network, 1).sample(4.0, out)
	assert_true(out[0].distance_to(Vector2(8.0, 0.0)) > standard.distance_to(Vector2(8.0, 0.0)) + 0.1, "widened: a wider bend")
	assert_equal(BoreCurveScript.of(network, 1), curve, "the same curve, kept")
	assert_true(BoreCurveScript.of(network, 0) != curve, "each segment its own")


func test_only_steps_whose_roots_stay_under_the_cut_are_dressed() -> void:
	"""At the level's floor both classes are dressed; a step 0.25 m up a ramp is not (its highest root would
	stand through the section plane)."""
	assert_true(DressingScript.dressed_at(Layers.FLOOR_Y_M, Rules.BORE_STANDARD), "standard, level")
	assert_true(DressingScript.dressed_at(Layers.FLOOR_Y_M, Rules.BORE_WIDE), "widened, level")
	assert_false(DressingScript.dressed_at(Layers.FLOOR_Y_M + 0.25, Rules.BORE_STANDARD), "up the ramp")
	assert_false(DressingScript.dressed_at(Layers.FLOOR_Y_M + 0.01, Rules.BORE_WIDE), "the widened crown leaves no room")


func test_a_build_holds_at_most_max_rings() -> void:
	"""Past MAX_RINGS a build takes no more rings."""
	expect_diagnostic("bore_mesh: more than")
	var builder := BoreMeshScript.new()
	builder.begin()
	for ring in BoreMeshScript.MAX_RINGS + 3:
		builder.add_ring(ring, Vector3(float(ring) * 0.25, 0.0, 0.0), Vector2(1.0, 0.0), Rules.BORE_STANDARD, BoreMeshScript.PLAIN, 0.0)
	assert_equal(builder.ring_count(), BoreMeshScript.MAX_RINGS, "capped")


func test_the_u_view_s_focus_is_where_the_camera_looks_on_the_floor() -> void:
	"""A camera 10 m up looking 45 degrees down at the origin: the U view's focus (where the lanterns are
	handed out) is where its ray meets the level's floor, 1.25 m past the ground point; looking up, the
	origin below."""
	var forward := Vector3(0.0, -1.0, -1.0).normalized()
	var focus := ViewScript.floor_focus(Vector3(0.0, 10.0, 10.0), forward)
	assert_almost_equal(focus.y, Layers.FLOOR_Y_M, "on the floor")
	assert_true(absf(focus.z + Rules.BORE_FLOOR_DEPTH_M) < 1e-3, "past the ground point by the floor's depth (%.3f)" % focus.z)
	assert_true(ViewScript.floor_focus(Vector3(0.0, 10.0, 10.0), Vector3.UP).is_equal_approx(Vector3(0.0, Layers.FLOOR_Y_M, 0.0)), "looking up")


func test_the_hub_cuts_a_bore_s_floor_however_its_jitter_falls() -> void:
	"""A bore's floor is jittered up to FLOOR_JITTER_M either side of the level's floor, and a hub must drop
	every bit of it inside its circle, or patches of the bore's floor (in another dig day's shade) show
	through the hub's. The shared surface counts a point down to FLOOR_SLACK_M below the floor as on it; that
	slack must cover the jitter."""
	var source := FileAccess.get_file_as_string("res://demo/tunnel/bore_surface.gdshaderinc")
	var at := source.find("const float FLOOR_SLACK_M = ")
	assert_true(at >= 0, "the slack is named")
	var slack := source.substr(at + "const float FLOOR_SLACK_M = ".length(), 8).to_float()
	assert_true(slack >= BoreMeshScript.FLOOR_JITTER_M, "slack %.3f m covers the floor's %.3f m jitter" % [slack, BoreMeshScript.FLOOR_JITTER_M])
	assert_true(slack < 0.1 * Rules.crown_m(Rules.BORE_STANDARD), "and stays a sliver of the crown")
	assert_true(source.find("if (up < 0.0 && up > -FLOOR_SLACK_M)") >= 0, "in_hub lifts a point that little below onto the floor")


func test_a_branch_breaking_ground_cuts_the_bores_it_joins() -> void:
	"""Drawn while it is dug (a frame at a time, as in the demo): the host's halves were split and drawn before
	the branch broke ground, with no hub at the junction. The moment the branch digs its first tick a hub
	stands there, and both halves are rebuilt to drop what lies inside it -- else their floors show through
	the hub's in patches."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var network: GraphScript = space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for s in chain:
		network.start_dig(s, network.generation[s], 0)
		network.advance(s, network.generation[s], 1000000000)
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(network, space)
	overlay.refresh()
	var spec := SpecScript.new()
	spec.set_route(PackedInt32Array([6144, 0, 6144, 8192]), 2)
	spec.start_kind = SpecScript.END_ON_SEGMENT
	spec.start_ref = 1
	assert_true(network.add_piece(spec, ref), "a branch off the bore's middle")
	overlay.refresh()
	assert_equal(_hub_radius(overlay, 1, 1), 0.0, "split, but no hub yet: nothing has broken ground there")
	network.start_dig(ref[0], ref[1], 0)
	network.advance(ref[0], ref[1], 1000000)
	overlay.refresh()
	var radius := BoreMeshScript.FLOOR_HALF_M[Rules.BORE_STANDARD] * BoreMeshScript.HUB_SCALE
	assert_almost_equal(_hub_radius(overlay, 1, 1), radius, "the first half cut at its node B, the junction")
	assert_almost_equal(_hub_radius(overlay, 3, 0), radius, "the far half at its node A")


func _hub_radius(overlay: OverlayScript, slot: int, end: int) -> float:
	"""The hub radius segment `slot`'s drawn bore is cut at, at its node A (end 0) or B (1): its first vertex's
	CUSTOM0 or CUSTOM1 z."""
	var arrays := (overlay.bores.chunk(slot, 0).mesh as ArrayMesh).surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_CUSTOM0 + end] as PackedFloat32Array)[2]


func test_a_hub_is_rebuilt_only_when_what_it_depends_on_changes() -> void:
	"""Review C4: the hubs are checked every frame, on a key folded from integers. A hundred frames with
	nothing new build nothing; a fourth bore breaking ground at the junction rebuilds the hub once, with a
	fourth opening."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var network: GraphScript = space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for s in chain:
		network.start_dig(s, network.generation[s], 0)
		network.advance(s, network.generation[s], 1000000000)
	var branch := SpecScript.new()
	branch.set_route(PackedInt32Array([6144, 0, 6144, 8192]), 2)
	branch.start_kind = SpecScript.END_ON_SEGMENT
	branch.start_ref = 1
	network.add_piece(branch, ref)
	network.start_dig(ref[0], ref[1], 0)
	network.advance(ref[0], ref[1], 1000000)
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(network, space)
	overlay.refresh()
	var builds := overlay.bores.hub_builds
	assert_equal(builds, 1, "the tee's hub")
	for f in 100:
		overlay.bores.refresh_hubs()
	assert_equal(overlay.bores.hub_builds, builds, "nothing new: nothing rebuilt")
	var j := network.node_b[1]
	var cross := SpecScript.new()
	cross.set_route(PackedInt32Array([6144, -8192, 6144, 0]), 2)
	cross.end_kind = SpecScript.END_NODE
	cross.end_ref = j
	network.add_piece(cross, ref)
	overlay.bores.refresh_hubs()
	assert_equal(overlay.bores.hub_builds, builds, "laid but not dug to it: still three openings")
	var four := PackedInt32Array()
	network.piece_segments_into(ref[2], four)
	for s in four:
		network.start_dig(s, network.generation[s], 0)
		network.advance(s, network.generation[s], 1000000000)
	overlay.bores.refresh_hubs()
	assert_equal(overlay.bores.hub_builds, builds + 1, "broken through: rebuilt once")
	var custom := (overlay.bores.hub(j).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_CUSTOM2] as PackedFloat32Array
	assert_true(custom[3] > 0.0, "with a fourth opening")
	network.set_bore(1, Rules.BORE_WIDE)
	overlay.bores.refresh_hubs()
	assert_equal(overlay.bores.hub_builds, builds + 2, "a bore there widened: rebuilt, wider")
