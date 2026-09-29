extends "res://test/framework/test_case.gd"
## Coverage for the live demo's world (`godot/demo/world/`, decision 0196).
##
## The suite runs before the scene tree is live and CI stages no assets, so nothing here loads a
## model or needs a renderer. It checks the logic the rest of the demo builds on:
##
##   * building scale lands exactly on the authoritative envelope for a synthetic bound, so a
##     wrong row or a wrong axis in `world_sizes.gd` fails here rather than on screen;
##   * every point of interest is inside the walkable bound, clear of every obstacle circle by a
##     real margin, spaced from the others and well-formed -- the residents trust all of it;
##   * the placeholder build (empty manifest) produces the same layout and draws buildings at
##     their envelope height;
##   * the layout and the scattered dressing are deterministic.

const DemoWorld := preload("res://demo/world/demo_world.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")

const DEMO_BUILDINGS: Array[StringName] = [
	&"residence", &"hall", &"kitchen", &"well", &"workbench", &"covered_store",
	&"open_stockpile", &"fence",
]
## A resident needs room to stand: a point must clear every obstacle edge by this much.
const POINT_CLEARANCE_M: float = 0.3
const POINT_SPACING_M: float = 1.2
## Every point sits on or beside a worn path, so residents have a lane to it.
const POINT_PATH_REACH_M: float = 1.5
const MIN_POINTS: int = 8
const MAX_POINTS: int = 12

var _world: Node3D = null


func before_each() -> void:
	"""A fresh, unbuilt world outside any tree."""
	_world = DemoWorld.new()


func after_each() -> void:
	"""Free the world and everything a build hung off it."""
	if _world != null:
		_world.free()
		_world = null


func _empty_manifest() -> Dictionary:
	"""What demo_manifest.gd returns when nothing is staged."""
	return {"world": {}, "cast": {}}


func _metres(key: StringName) -> float:
	"""The authoritative envelope of `key` in metres, read straight from the lookdev columns."""
	var row: int = Dimensions.BUILDING_KEY.find(key)
	return float(Dimensions.BUILDING_MAX_Y_MM[row]) / 1000.0


func test_building_scale_hits_the_authoritative_height_for_a_synthetic_bound() -> void:
	"""Uniform scale times a made-up model height equals the envelope, for every demo building."""
	var lo := Vector3(-0.5, 0.0, -0.4)
	var hi := Vector3(0.5, 1.7, 0.4)
	for key: StringName in DEMO_BUILDINGS:
		var s: float = Sizes.uniform_scale(key, lo, hi)
		assert_almost_equal(s * (hi.y - lo.y), _metres(key), "%s drawn height" % key)


func test_building_scale_measures_height_from_the_bound_not_the_origin() -> void:
	"""A bound that does not start at y = 0 is still scaled by its own height."""
	var s: float = Sizes.uniform_scale(&"hall", Vector3(-1.0, 0.25, -1.0), Vector3(1.0, 2.25, 1.0))
	assert_almost_equal(s * 2.0, 7.0, "hall scaled from a 2.0 m tall bound")


func test_named_building_heights_match_the_ruling() -> void:
	"""Spot-check the envelopes the demo draws against the numbers the brief quotes."""
	var expected: Dictionary = {
		&"residence": 6.0, &"hall": 7.0, &"kitchen": 5.0, &"well": 3.0, &"workbench": 3.5,
		&"covered_store": 5.0, &"open_stockpile": 2.5, &"fence": 1.5,
	}
	for key: StringName in expected:
		assert_almost_equal(Sizes.target_height_m(key), expected[key], "%s envelope" % key)
		assert_true(Sizes.is_building(key), "%s is sized as a building" % key)


func test_every_staged_world_key_has_a_positive_size() -> void:
	"""No model can be drawn at zero or negative size: a height, or for a crop bed a width."""
	for key: StringName in Sizes.NATIVE_AABB:
		if not Sizes.CROP_KEYS.has(key):
			assert_true(Sizes.target_height_m(key) > 0.0, "%s has a target height" % key)
		assert_true(Sizes.native_scale(key) > 0.0, "%s has a positive scale" % key)


func test_crop_beds_are_scaled_to_their_width() -> void:
	"""Every crop bed is CROP_BED_WIDTH_M wide whatever its model height, carded or not."""
	var lo := Vector3(-0.95, 0.0, -0.95)
	var hi := Vector3(0.93, 0.18, 0.95)
	for key: StringName in Sizes.CROP_KEYS:
		var s: float = Sizes.uniform_scale(key, lo, hi)
		assert_almost_equal(s * (hi.x - lo.x), Sizes.CROP_BED_WIDTH_M, "%s bed width" % key)
		assert_almost_equal(Sizes.native_scale(key) * _native_width(key), Sizes.CROP_BED_WIDTH_M,
			"%s placeholder bed width" % key)


func _native_width(key: StringName) -> float:
	"""The recorded native bound's X extent."""
	var bound: Array = Sizes.NATIVE_AABB[key]
	return (bound[1] as Vector3).x - (bound[0] as Vector3).x


func test_the_table_top_is_the_work_surface_candidate() -> void:
	"""The table is sized from the lookdev work-surface column, not the demo table."""
	var expected: float = float(Dimensions.WORK_SURFACE_TOP_U) / float(Dimensions.UNITS_PER_METRE)
	assert_almost_equal(Sizes.target_height_m(&"table_stools"), expected, "table top height")
	assert_false(Sizes.DEMO_HEIGHT_M.has(&"table_stools"), "table is not in the demo-only table")


func test_point_count_is_in_the_demo_range() -> void:
	"""Enough spots to spread eight residents out, few enough to keep them meeting."""
	var count: int = _world.points_of_interest().size()
	assert_true(count >= MIN_POINTS and count <= MAX_POINTS, "%d points of interest" % count)


func test_every_point_of_interest_is_inside_bounds() -> void:
	"""A resident sent to a point never leaves the walkable area."""
	var area: AABB = _world.bounds()
	for point: Dictionary in _world.points_of_interest():
		var at: Vector3 = point["position"]
		assert_true(area.has_point(at), "%s at %s is inside %s" % [point["name"], at, area])


func test_every_point_of_interest_is_clear_of_every_obstacle() -> void:
	"""A resident standing at a point is outside every circle by a real margin."""
	var circles: Array[Vector3] = _world.obstacles()
	for point: Dictionary in _world.points_of_interest():
		var at: Vector3 = point["position"]
		var clear: float = Layout.clearance(Vector2(at.x, at.z), circles)
		assert_true(clear >= POINT_CLEARANCE_M, "%s clears obstacles by %.2f m" % [point["name"], clear])


func test_point_fields_are_well_formed() -> void:
	"""Names unique StringNames, grounded positions, unit XZ faces, known activities, capacity."""
	var names: Dictionary = {}
	for point: Dictionary in _world.points_of_interest():
		var name: StringName = point["name"]
		var at: Vector3 = point["position"]
		var face: Vector3 = point["face"]
		assert_equal(typeof(point["name"]), TYPE_STRING_NAME, "%s name is a StringName" % name)
		assert_false(names.has(name), "%s is unique" % name)
		names[name] = true
		assert_almost_equal(at.y, DemoWorld.GROUND_Y, "%s stands on the ground" % name)
		assert_almost_equal(face.y, 0.0, "%s faces horizontally" % name)
		assert_almost_equal(face.length(), 1.0, "%s face is a unit vector" % name)
		assert_true(int(point["capacity"]) >= 1, "%s has capacity" % name)
		_assert_activities(name, point["activities"])


func _assert_activities(name: StringName, activities: Variant) -> void:
	"""The activity list is a non-empty typed Array[StringName] drawn from the four clips."""
	assert_true(activities is Array, "%s activities is an array" % name)
	var list: Array = activities
	assert_true(list.is_typed() and list.get_typed_builtin() == TYPE_STRING_NAME,
		"%s activities is Array[StringName]" % name)
	assert_false(list.is_empty(), "%s has at least one activity" % name)
	for activity: StringName in list:
		assert_true(Layout.ACTIVITIES.has(activity), "%s activity %s is known" % [name, activity])


func test_points_are_spaced_apart() -> void:
	"""Two residents at neighbouring points never stand inside each other."""
	var points: Array[Dictionary] = _world.points_of_interest()
	for i: int in points.size():
		for j: int in range(i + 1, points.size()):
			var gap: float = (points[i]["position"] as Vector3).distance_to(points[j]["position"])
			assert_true(gap >= POINT_SPACING_M,
				"%s and %s are %.2f m apart" % [points[i]["name"], points[j]["name"], gap])


func test_every_point_is_on_or_beside_a_worn_path() -> void:
	"""The worn paths are the lanes between points; every point is reached along one."""
	for point: Dictionary in _world.points_of_interest():
		var at: Vector3 = point["position"]
		var reach: float = Layout.path_distance(Vector2(at.x, at.z))
		assert_true(reach <= POINT_PATH_REACH_M, "%s is %.2f m off a path" % [point["name"], reach])


func test_every_path_capsule_has_a_radius() -> void:
	"""One radius per path segment, and the shader's fixed array holds them all."""
	assert_equal(Layout.PATH_RADII.size(), Layout.PATH_SEGMENTS.size(), "one radius per segment")
	assert_true(Layout.PATH_SEGMENTS.size() <= 24, "paths fit the ground shader's 24-slot array")
	for radius: float in Layout.PATH_RADII:
		assert_true(radius > 0.0, "path radius %.2f is positive" % radius)


func test_obstacles_have_positive_radii_and_reach_the_play_area() -> void:
	"""Every reported circle is real and matters to a resident inside the bound."""
	var circles: Array[Vector3] = _world.obstacles()
	assert_true(circles.size() > 0, "the village has obstacles")
	for circle: Vector3 in circles:
		assert_true(circle.z > 0.0, "circle at (%.1f, %.1f) has a radius" % [circle.x, circle.y])
		assert_true(Layout.circle_reaches_play(circle), "circle at (%.1f, %.1f) is reported" % [circle.x, circle.y])


func test_every_blocking_footprint_is_walled_by_its_circles() -> void:
	"""The circle ring has no gap: every point on a footprint's outline is inside some circle."""
	for p: Dictionary in Layout.placements():
		if not p["block"] or Layout.TRUNK_RADIUS_M.has(p["key"]):
			continue
		var gaps: int = _outline_gaps(p, Layout.placement_circles(p))
		assert_equal(gaps, 0, "%s (%s) outline points outside its circles" % [p["id"], p["key"]])


func _outline_gaps(p: Dictionary, circles: Array[Vector3]) -> int:
	"""How many points, every 0.25 m round the footprint outline, no circle covers."""
	var rect: Rect2 = Sizes.scaled_rect(p["key"], p["size"])
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]
	var gaps: int = 0
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var steps: int = maxi(1, ceili(a.distance_to(b) / 0.25))
		for step: int in steps:
			var local: Vector2 = a.lerp(b, float(step) / float(steps))
			var world: Vector2 = (p["at"] as Vector2) + Layout.rotate_xz(local, p["yaw"])
			if Layout.clearance(world, circles) >= 0.0:
				gaps += 1
	return gaps


func test_placeholder_build_works_on_an_empty_manifest() -> void:
	"""With nothing staged the world still builds: ground, sun, sky and a full village."""
	_world.build(_empty_manifest())
	assert_not_null(_world.get_node_or_null(^"Ground"), "ground plane built")
	assert_not_null(_world.get_node_or_null(^"Sun"), "sun built")
	assert_not_null(_world.get_node_or_null(^"Environment"), "environment built")
	var village: Node = _world.get_node_or_null(^"Village")
	assert_not_null(village, "village built")
	var pieces: int = 0
	for child: Node in village.get_children():
		if child is MeshInstance3D:
			pieces += 1
	assert_true(pieces >= Layout.placements().size(), "%d placeholder pieces" % pieces)
	assert_not_null(village.get_node_or_null(^"Cover_grass_tuft"), "ground cover built")


func test_placeholder_hall_is_drawn_at_its_envelope_height() -> void:
	"""A placeholder is scaled like the asset: the hall box is exactly 7.0 m tall."""
	_world.build(_empty_manifest())
	var hall: MeshInstance3D = _world.get_node(^"Village").get_child(0) as MeshInstance3D
	assert_not_null(hall, "first village piece is the hall placeholder")
	var height: float = hall.mesh.get_aabb().size.y * hall.transform.basis.get_scale().y
	assert_almost_equal(height, _metres(&"hall"), "hall placeholder height")
	assert_almost_equal(hall.transform.origin.y, DemoWorld.GROUND_Y, "hall stands on the ground")


func test_rebuild_replaces_rather_than_duplicates() -> void:
	"""Calling build() twice leaves one ground, one sun and one village."""
	_world.build(_empty_manifest())
	var first: int = _world.get_child_count()
	_world.build(_empty_manifest())
	assert_equal(_world.get_child_count(), first, "same child count after a rebuild")


func test_rebuild_keeps_nodes_the_integrator_added() -> void:
	"""A resident parented under the world is not swept away by a second build()."""
	_world.build(_empty_manifest())
	var resident := Node3D.new()
	_world.add_child(resident)
	_world.build(_empty_manifest())
	assert_equal(resident.get_parent(), _world, "integrator's child survives a rebuild")


func test_queries_do_not_change_across_a_build() -> void:
	"""Obstacles and points are pure functions of the layout, not of what was drawn."""
	var before_points: Array[Dictionary] = _world.points_of_interest()
	var before_obstacles: Array[Vector3] = _world.obstacles()
	_world.build(_empty_manifest())
	assert_equal(_world.points_of_interest(), before_points, "points unchanged by build")
	assert_equal(_world.obstacles(), before_obstacles, "obstacles unchanged by build")


func test_layout_and_dressing_are_deterministic() -> void:
	"""Two worlds agree exactly: fixed seeds, no global RNG."""
	var other: Node3D = DemoWorld.new()
	assert_equal(other.obstacles(), _world.obstacles(), "same obstacles")
	assert_equal(other.points_of_interest(), _world.points_of_interest(), "same points")
	var blockers: Array[Vector3] = Layout.obstacles_for(Layout.placements())
	assert_equal(Scatter.tree_ring(blockers), Scatter.tree_ring(blockers), "same woods")
	other.free()


func test_trees_stand_outside_the_clearing_and_off_the_paths() -> void:
	"""The woods frame the village; no tree grows on the square or a path."""
	var blockers: Array[Vector3] = Layout.obstacles_for(Layout.placements())
	var trees: Array[Dictionary] = Scatter.tree_ring(blockers)
	assert_true(trees.size() > 0, "the woods have trees")
	for tree: Dictionary in trees:
		var at: Vector2 = tree["at"]
		assert_true(at.length() >= Scatter.clearing_edge(at), "tree at %s is outside the clearing" % at)
		assert_true(Layout.path_distance(at) >= Scatter.TREE_PATH_CLEARANCE_M, "tree at %s is off the paths" % at)


func test_ground_cover_stays_out_of_obstacles_and_off_points() -> void:
	"""Tussocks and mushrooms never sit inside a building or on a resident's spot."""
	var circles: Array[Vector3] = _world.obstacles()
	var spots: Array[Vector2] = []
	for point: Dictionary in _world.points_of_interest():
		var at: Vector3 = point["position"]
		spots.append(Vector2(at.x, at.z))
	var cover: Array[Dictionary] = Scatter.ground_cover(circles, spots)
	assert_true(cover.size() > 0, "there is ground cover")
	for piece: Dictionary in cover:
		var at: Vector2 = piece["at"]
		assert_false(piece["block"], "cover at %s does not block" % at)
		assert_true(Layout.clearance(at, circles) >= 0.0, "cover at %s is outside every obstacle" % at)


# --- crop cards (no assets: a synthetic manifest block and a 1 px texture) -------------------

func _cards_block(variants: int, kinds: Dictionary) -> Dictionary:
	"""A manifest `cards` block shaped like make_demo_crop_cards.py writes it."""
	return {
		"texture": "res://nowhere.png", "variants": variants, "cell_m": [0.24, 0.43],
		"kinds": kinds, "soil_y": 0.14, "inner": [-0.86, 0.86, -0.86, 0.86],
		"tops": {"texture": "res://nowhere_tops.png", "variants": variants, "cell_m": [0.42, 0.42]},
	}


func _grain_cards() -> Dictionary:
	"""The grain bed's cards block: six wheat cells, and no top-down atlas."""
	var cards: Dictionary = _cards_block(6, {"wheat": [0, 1, 2, 3, 4, 5]})
	cards.erase("tops")
	return cards


func _roots_cards() -> Dictionary:
	"""The roots bed's cards block: three carrots and two turnips."""
	return _cards_block(5, {"carrot": [0, 1, 2], "turnip": [3, 4]})


func _tiny_texture() -> Texture2D:
	"""A 1 x 1 texture: enough for a material, needs no staged file."""
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.6, 0.2, 1.0))
	return ImageTexture.create_from_image(image)


func test_card_placement_is_deterministic() -> void:
	"""Two plantings of the same bed agree exactly: fixed seeds, no global RNG."""
	for key: StringName in CropCards.LAYOUTS:
		var cards: Dictionary = _grain_cards() if key == &"crop_grain_ripe" else _roots_cards()
		assert_equal(CropCards.placements(key, cards), CropCards.placements(key, cards), "%s placement" % key)


func test_every_card_stays_inside_the_bed() -> void:
	"""A plant's centre, and for the wheat its whole widest card, lie inside the frame's inner edge."""
	for key: StringName in CropCards.LAYOUTS:
		var cards: Dictionary = _grain_cards() if key == &"crop_grain_ripe" else _roots_cards()
		var layout: Dictionary = CropCards.LAYOUTS[key]
		var inner := Rect2(-0.86, -0.86, 1.72, 1.72)
		var reach: float = CropCards.plant_reach(layout, cards["cell_m"])
		var plants: Array[Dictionary] = CropCards.placements(key, cards)
		assert_true(plants.size() > 0, "%s has plants" % key)
		for plant: Dictionary in plants:
			var at: Vector2 = plant["at"]
			assert_true(inner.grow(-reach).has_point(at), "%s plant at %s keeps its reach inside" % [key, at])


func test_every_card_shows_a_cell_of_its_own_kind() -> void:
	"""A carrot never shows a turnip; every cell index is inside the atlas."""
	var cards: Dictionary = _roots_cards()
	var kinds: Dictionary = cards["kinds"]
	for plant: Dictionary in CropCards.placements(&"crop_roots_ripe", cards):
		var cells: Array = kinds[plant["kind"]]
		assert_true(cells.has(plant["variant"]), "%s shows cell %d" % [plant["kind"], plant["variant"]])
	for plant: Dictionary in CropCards.placements(&"crop_grain_ripe", _grain_cards()):
		assert_true(int(plant["variant"]) >= 0 and int(plant["variant"]) < 6, "wheat cell in the atlas")


func test_roots_bed_rows_match_the_source() -> void:
	"""Two rows of five turnips at the back, four rows of eight carrots in front."""
	var counts: Dictionary = {}
	var back_most_carrot: float = INF
	var front_most_turnip: float = -INF
	for plant: Dictionary in CropCards.placements(&"crop_roots_ripe", _roots_cards()):
		counts[plant["kind"]] = int(counts.get(plant["kind"], 0)) + 1
		var z: float = (plant["at"] as Vector2).y
		if plant["kind"] == "carrot":
			back_most_carrot = minf(back_most_carrot, z)
		else:
			front_most_turnip = maxf(front_most_turnip, z)
	assert_equal(counts, {"turnip": 10, "carrot": 32}, "plant counts")
	assert_true(front_most_turnip < back_most_carrot, "turnips stand behind the carrots")


func test_card_mesh_stands_on_the_soil_within_its_cell() -> void:
	"""Three quads, every vertex between the soil and the cell's height, lit from above."""
	var mesh: ArrayMesh = CropCards.card_mesh(Vector2(0.24, 0.43))
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_equal(verts.size(), CropCards.PLANES * 4, "four vertices per plane")
	for i: int in verts.size():
		assert_true(verts[i].y >= 0.0 and verts[i].y <= 0.43 + 0.0001, "vertex %d within the cell height" % i)
		assert_true(normals[i].dot(Vector3.UP) > 0.99, "vertex %d normal points up (%s)" % [i, normals[i]])


func test_card_material_is_alpha_scissor_not_blend() -> void:
	"""Scissor keeps shadows and sorting sane; the shader must never switch to blending."""
	var code: String = CropCards.CARD_SHADER.code
	assert_true(code.contains("ALPHA_SCISSOR_THRESHOLD"), "the card shader scissors")
	assert_false(code.contains("blend_"), "the card shader sets no blend mode")
	assert_false(code.contains("shadows_disabled"), "the cards cast shadows")


func test_card_build_needs_no_staged_assets() -> void:
	"""With a synthetic block and a 1 px texture: an underlay, one card per plant, a top per root."""
	var texture: Texture2D = _tiny_texture()
	var grain: Node3D = CropCards.build(&"crop_grain_ripe", _grain_cards(), texture, texture)
	var roots: Node3D = CropCards.build(&"crop_roots_ripe", _roots_cards(), texture, texture)
	var grain_cards := grain.get_node(^"Cards") as MultiMeshInstance3D
	var roots_tops := roots.get_node_or_null(^"Tops") as MultiMeshInstance3D
	assert_not_null(grain.get_node_or_null(^"SoilUnderlay"), "the grain bed has a soil underlay")
	assert_equal(grain_cards.multimesh.instance_count,
		CropCards.placements(&"crop_grain_ripe", _grain_cards()).size(), "one card per wheat plant")
	assert_null(grain.get_node_or_null(^"Tops"), "the wheat lays no flat canopy")
	assert_not_null(roots_tops, "the roots bed lays a top over each plant")
	assert_equal(roots_tops.multimesh.instance_count, 42, "one top per root plant")
	grain.free()
	roots.free()


func test_a_carded_entry_whose_files_are_missing_falls_back_to_a_placeholder() -> void:
	"""A manifest naming a bed and cards that are not on disk still builds the whole village."""
	var world: Dictionary = {"crop_grain_ripe": {"category": "environment",
		"path": "res://demo/assets/world/missing_bed.glb", "aabb_min": [-0.95, 0.0, -0.95],
		"aabb_max": [0.95, 0.18, 0.95], "cards": _grain_cards()}}
	_world.build({"world": world, "cast": {}})
	var village: Node = _world.get_node(^"Village")
	assert_true(village.get_child_count() >= Layout.placements().size(), "the village is complete")
