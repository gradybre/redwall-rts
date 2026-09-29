extends "res://test/framework/test_case.gd"
## The live demo's select-and-command layer (decision 0196): picking, box selection, formations,
## move / work / release orders, and the demo party panel's text, placement and contrast.
##
## No scene tree and no assets: picking and box membership are pure math (demo_pick.gd), orders
## run on brains stepped at a fixed 60 Hz, the real village comes from DemoWorld's pure queries,
## and the panel is checked through its static layout and text functions.

const PickScript := preload("res://demo/control/demo_pick.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Contrast := preload("res://demo/ui/woodland_contrast.gd")

const DT: float = 1.0 / 60.0
const SEED: int = 777
const BODY_M: float = 0.25
const OPEN := Rect2(-50.0, -50.0, 100.0, 100.0)


# --- fixtures -------------------------------------------------------------------------------

func _poi(name: StringName, at: Vector3, face: Vector3, capacity: int) -> Dictionary:
	"""One POI in the world's shape, with one activity."""
	return {"name": name, "position": at, "face": face, "activities": [&"collect_object"], "capacity": capacity}


func _space(points: Array[Dictionary], circles: Array[Vector3]) -> CastSpaceScript:
	"""A CastSpace over these POIs and circles."""
	var space := CastSpaceScript.new()
	space.setup(points, circles)
	return space


func _brains(space: CastSpaceScript, spots: Array[Vector2], radius: float) -> Array[BrainScript]:
	"""A resident standing at each spot (holding no slot)."""
	var out: Array[BrainScript] = []
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	for i in spots.size():
		var brain := BrainScript.new()
		brain.configure(space, 0.8, radius, SEED + i, lengths)
		brain.start_at(spots[i], 0.0, -1, -1)
		out.append(brain)
	return out


func _step_all(brains: Array[BrainScript], seconds: float) -> void:
	"""Step every brain for `seconds`."""
	for f in int(seconds / DT):
		for brain in brains:
			brain.step(DT)


func _bits_match(space: CastSpaceScript, brains: Array[BrainScript]) -> bool:
	"""Whether poi_used holds exactly the slots these brains hold."""
	var expected := PackedInt32Array()
	expected.resize(space.poi_used.size())
	for brain in brains:
		if brain.poi >= 0:
			expected[brain.poi] = expected[brain.poi] | (1 << brain.slot)
	return expected == space.poi_used


# --- picking --------------------------------------------------------------------------------

func test_a_ray_down_onto_a_capsule_hits_its_top() -> void:
	"""Straight down from 10 m onto a 1.5 m capsule enters at its top, 8.5 m along."""
	var t := PickScript.ray_capsule(Vector3(0.0, 10.0, 0.0), Vector3.DOWN, Vector3.ZERO, 1.5, 0.3)
	assert_almost_equal(t, 8.5, "enters the top cap")


func test_a_level_ray_hits_the_side_and_a_near_miss_misses() -> void:
	"""A level ray at mid-height enters the side at radius; 1 cm outside the radius it misses."""
	var hit := PickScript.ray_capsule(Vector3(-5.0, 0.75, 0.0), Vector3.RIGHT, Vector3.ZERO, 1.5, 0.3)
	assert_almost_equal(hit, 4.7, "the side, at 5 - 0.3")
	var miss := PickScript.ray_capsule(Vector3(-5.0, 0.75, 0.31), Vector3.RIGHT, Vector3.ZERO, 1.5, 0.3)
	assert_equal(miss, -1.0, "a ray passing 1 cm outside misses")
	var behind := PickScript.ray_capsule(Vector3(-5.0, 0.75, 0.0), Vector3.LEFT, Vector3.ZERO, 1.5, 0.3)
	assert_equal(behind, -1.0, "a capsule behind the ray is not hit")
	var over := PickScript.ray_capsule(Vector3(-5.0, 1.6, 0.0), Vector3.RIGHT, Vector3.ZERO, 1.5, 0.3)
	assert_equal(over, -1.0, "a ray over its head misses")


func test_the_nearest_capsule_on_the_ray_wins() -> void:
	"""Two residents on one ray: the nearer is picked; one off the ray is ignored."""
	var feet := PackedVector3Array([Vector3(6.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(3.0, 0.0, 5.0)])
	var heights := PackedFloat32Array([1.0, 1.0, 2.5])
	var radii := PackedFloat32Array([0.25, 0.25, 0.56])
	assert_equal(PickScript.nearest_hit(Vector3(0.0, 0.5, 0.0), Vector3.RIGHT, feet, heights, radii), 1, "the nearer one")
	assert_equal(PickScript.nearest_hit(Vector3(0.0, 0.5, 9.0), Vector3.RIGHT, feet, heights, radii), -1, "nobody on this ray")


func test_the_ground_ray_meets_the_plane() -> void:
	"""A ray down to the ground plane; a level ray never meets it."""
	var t := PickScript.ray_ground(Vector3(0.0, 10.0, 0.0), Vector3(0.0, -1.0, 1.0).normalized(), 0.0)
	assert_almost_equal(t, 10.0 * sqrt(2.0), "10 m down along a 45 degree ray")
	assert_equal(PickScript.ray_ground(Vector3(0.0, 10.0, 0.0), Vector3.RIGHT, 0.0), -1.0, "level: never")
	assert_equal(PickScript.ray_ground(Vector3(0.0, -1.0, 0.0), Vector3.UP, 0.0), -1.0, "from below, looking up: never")


func test_box_membership_is_by_screen_position() -> void:
	"""Points inside the box (either corner order) are members; off-screen points never are."""
	var screen := PackedVector2Array([Vector2(100, 100), Vector2(300, 250), Vector2(50, 400), Vector2(200, 200)])
	var on := PackedByteArray([1, 1, 1, 0])
	var out := PackedInt32Array()
	out.resize(screen.size())
	var count := PickScript.box_members(screen, on, Vector2(350, 300), Vector2(80, 80), out)
	assert_equal(count, 2, "two inside")
	assert_equal(out.slice(0, count), PackedInt32Array([0, 1]), "the first two, not the off-screen one")
	assert_false(PickScript.is_drag(Vector2(10, 10), Vector2(13, 14)), "5 px is a click")
	assert_true(PickScript.is_drag(Vector2(10, 10), Vector2(16, 10)), "6 px is a drag")


# --- formations and orders ------------------------------------------------------------------

func _village() -> CastSpaceScript:
	"""CastSpace over the real village."""
	var world: Node3D = DemoWorldScript.new()
	var space := _space(world.points_of_interest(), world.obstacles())
	world.free()
	return space


func test_formations_are_distinct_clear_and_inside_for_one_to_eight() -> void:
	"""On the real village, at two points, formations of 1..8 badger-sized bodies are distinct by a
	spacing, clear of every obstacle by the body, inside the bounds, and reachable."""
	var space := _village()
	var bounds := Rect2(-20.0, -20.0, 40.0, 40.0)
	var bad := 0
	for center: Vector2 in [Vector2(-3.0, 3.5), Vector2(6.0, -6.0)]:
		for count in range(1, 9):
			var spots := PackedVector2Array()
			var ok := CastOrdersScript.formation_slots(space, center, count, 0.56, bounds, PackedVector3Array(), Vector2(0.0, 5.0), spots)
			bad += 0 if ok and _formation_ok(space, spots, 0.56, bounds) else 1
	assert_equal(bad, 0, "every formation well formed")


func _formation_ok(space: CastSpaceScript, spots: PackedVector2Array, body: float, bounds: Rect2) -> bool:
	"""Distinct by the spacing, clear of obstacles, inside the bounds."""
	for i in spots.size():
		if space.obstacle_clearance(spots[i]) < body or not bounds.has_point(spots[i]):
			return false
		for j in range(i + 1, spots.size()):
			if spots[i].distance_to(spots[j]) < CastOrdersScript.spacing_for(body) - 1e-3:
				return false
	return true


func test_a_spot_closer_than_the_spacing_to_one_taken_is_refused() -> void:
	"""spot_ok refuses a spot within spacing_for(body) of a spot already taken, and accepts it once
	that neighbour is a spacing away (the spiral happens to space its rings that far apart anyway;
	this is the rule itself, for whatever candidate order a caller uses)."""
	var space := _space([], [])
	var spacing := CastOrdersScript.spacing_for(BODY_M)
	var near := PackedVector2Array([Vector2(spacing - 0.01, 0.0)])
	var far := PackedVector2Array([Vector2(spacing + 0.01, 0.0)])
	assert_false(CastOrdersScript.spot_ok(space, Vector2.ZERO, BODY_M, OPEN, PackedVector3Array(), near, Vector2(0.0, 3.0)), "too close")
	assert_true(CastOrdersScript.spot_ok(space, Vector2.ZERO, BODY_M, OPEN, PackedVector3Array(), far, Vector2(0.0, 3.0)), "a spacing away")


func test_a_move_order_releases_held_slots_and_holds_without_wandering() -> void:
	"""Two residents holding POI slots are ordered away: both slots are released at once, the books
	stay exact, and after two minutes they hold where sent, never wandering."""
	var points: Array[Dictionary] = [_poi(&"a", Vector3(-4, 0, 0), Vector3.FORWARD, 1), _poi(&"b", Vector3(4, 0, 0), Vector3.FORWARD, 1)]
	var space := _space(points, [])
	var brains := _brains(space, [Vector2(-4, 0), Vector2(4, 0)] as Array[Vector2], BODY_M)
	for i in 2:
		space.reserve(i, 0)
		brains[i].start_at(space.slot_position(i, 0), 0.0, i, 0)
	var spots := CastOrdersScript.order_move(space, brains, Vector2(0.0, 6.0), OPEN)
	assert_equal(space.poi_used, PackedInt32Array([0, 0]), "both slots given back at the order")
	assert_true(_bits_match(space, brains), "books exact")
	_step_all(brains, 20.0)
	var arrived := [brains[0].position, brains[1].position]
	_step_all(brains, 100.0)
	for i in 2:
		assert_equal(brains[i].state, BrainScript.State.HOLD, "resident %d holds" % i)
		assert_true(brains[i].position.distance_to(arrived[i]) < 1e-4, "and has not moved since")
		assert_true(spots.has(brains[i].position.snapped(Vector2(1e-3, 1e-3))) or brains[i].position.distance_to(spots[0]) < 3.0, "near the order")
	assert_true(_bits_match(space, brains), "books still exact")


func test_release_hands_a_holder_back_to_wandering() -> void:
	"""After release, a holder idles a moment and then sets off for a POI again."""
	var points: Array[Dictionary] = [_poi(&"a", Vector3(-4, 0, 0), Vector3.FORWARD, 1), _poi(&"b", Vector3(4, 0, 6), Vector3.FORWARD, 1)]
	var space := _space(points, [])
	var brains := _brains(space, [Vector2(0, 0)] as Array[Vector2], BODY_M)
	CastOrdersScript.order_move(space, brains, Vector2(0.0, 2.0), OPEN)
	_step_all(brains, 10.0)
	assert_equal(brains[0].activity(), BrainScript.ACTIVITY_HOLDING, "holding")
	CastOrdersScript.release(brains)
	assert_equal(brains[0].order, BrainScript.ORDER_NONE, "released")
	var wandered := false
	for f in 60 * 10:
		brains[0].step(DT)
		wandered = wandered or (brains[0].poi >= 0 and brains[0].state == BrainScript.State.WALK)
	assert_true(wandered, "off to a POI again within 10 s")


func test_a_work_order_fills_the_free_slots_and_the_rest_queue_facing_it() -> void:
	"""Three residents to a one-slot POI: the nearest works there, the other two hold behind it,
	facing it; the books are exact throughout."""
	var points: Array[Dictionary] = [_poi(&"bench", Vector3(0, 0, 0), Vector3(0, 0, 1), 1)]
	var space := _space(points, [Vector3(0.0, 0.5, 1.2)])
	var brains := _brains(space, [Vector2(0, -3), Vector2(-3, -5), Vector2(3, -6)] as Array[Vector2], BODY_M)
	var placed := CastOrdersScript.order_work(space, brains, 0, OPEN)
	assert_equal(placed, 1, "one slot, one worker")
	assert_true(_bits_match(space, brains), "books exact at the order")
	_step_all(brains, 30.0)
	assert_equal(brains[0].poi, 0, "the nearest works the slot")
	assert_equal(brains[0].activity(), BrainScript.ACTIVITY_WORKING, "and is working")
	for i in [1, 2]:
		var b := brains[i]
		assert_equal(b.activity(), BrainScript.ACTIVITY_HOLDING, "resident %d queues" % i)
		assert_true(b.position.distance_to(Vector2.ZERO) < 4.5, "near the POI (%.2f m)" % b.position.distance_to(Vector2.ZERO))
		var facing := absf(angle_difference(b.yaw, BrainScript.yaw_of(Vector2.ZERO - b.position)))
		assert_true(facing < 0.1, "facing it (%.2f rad off)" % facing)
	assert_true(_bits_match(space, brains), "books exact after")


func test_unreachable_orders_snap_and_hopeless_ones_are_refused() -> void:
	"""A click inside a circle snaps the formation outside it; so does one inside a closed ring
	(nothing in there is reachable). A click with no reachable spot within FORMATION_MAX_M -- far
	outside the bounds -- is refused, and nobody's order changes."""
	var ring: Array[Vector3] = [Vector3(8.0, 1.5, 0.0)]
	for k in 16:
		var angle := TAU * float(k) / 16.0
		ring.append(Vector3(cos(angle) * 3.0 - 10.0, 0.8, sin(angle) * 3.0))
	var space := _space([], ring)
	var brains := _brains(space, [Vector2(0, 0), Vector2(0, 2)] as Array[Vector2], BODY_M)
	var spots := CastOrdersScript.order_move(space, brains, Vector2(8.0, 0.0), OPEN)
	assert_equal(spots.size(), 2, "snapped rather than refused")
	assert_true(spots[0].distance_to(Vector2(8.0, 0.0)) >= 1.5 + BODY_M, "outside the building")
	for brain in brains:
		brain.release()
	var inside := CastOrdersScript.order_move(space, brains, Vector2(-10.0, 0.0), OPEN)
	var outside_ring := true
	for spot in inside:
		outside_ring = outside_ring and spot.distance_to(Vector2(-10.0, 0.0)) > 3.0
	assert_true(inside.size() == 2 and outside_ring, "inside a closed ring: snapped to reachable ground outside it")
	for brain in brains:
		brain.release()
	var bounds := Rect2(-20.0, -20.0, 40.0, 40.0)
	var refused := CastOrdersScript.order_move(space, brains, Vector2(40.0, 40.0), bounds)
	assert_true(refused.is_empty(), "far outside the bounds: refused")
	assert_equal(brains[0].order, BrainScript.ORDER_NONE, "and nobody was ordered")


func test_a_click_near_a_poi_is_a_work_order_there() -> void:
	"""poi_at finds a POI from its own point or a slot within reach, and nothing far away."""
	var space := _space([_poi(&"bench", Vector3(5, 0, 0), Vector3(0, 0, 1), 2)], [])
	assert_equal(CastOrdersScript.poi_at(space, Vector2(5.3, 0.2)), 0, "at the POI")
	assert_equal(CastOrdersScript.poi_at(space, space.slot_position(0, 1) + Vector2(0.5, 0.0)), 0, "by a slot")
	assert_equal(CastOrdersScript.poi_at(space, Vector2(9.0, 0.0)), -1, "far away")


func test_matching_pairs_the_nearest_first() -> void:
	"""Two walkers and two spots: each gets the spot on its own side."""
	var pairing := CastOrdersScript.match_nearest(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0)]),
		PackedVector2Array([Vector2(4, 1), Vector2(-4, 1)]))
	assert_equal(pairing, PackedInt32Array([1, 0]), "no crossing")


# --- the panel ------------------------------------------------------------------------------

func test_panel_text_for_nobody_one_and_several() -> void:
	"""Nobody; one resident's name, species and state; a count and one line each (capped)."""
	assert_equal(PanelScript.party_lines([]), PackedStringArray([PanelScript.NOBODY]), "nobody")
	var one: Array[Dictionary] = [{"name": "Otter boatwright", "species": "Otter", "state": "holding"}]
	assert_equal(PanelScript.party_lines(one), PackedStringArray(["Otter boatwright", "Otter", "holding"]), "one")
	var many: Array[Dictionary] = []
	for i in 8:
		many.append({"name": "R%d" % i, "species": "Mouse", "state": "wandering"})
	var lines := PanelScript.party_lines(many)
	assert_equal(lines[0], "8 residents", "a count")
	assert_equal(lines[1], "R0 — wandering", "a line each")
	assert_equal(lines.size(), 1 + PanelScript.MAX_ROWS + 1, "capped, with a remainder line")
	assert_equal(lines[lines.size() - 1], "+ 2 more", "the remainder")


func test_state_words() -> void:
	"""wandering / walking to X / working: activity / working at X / holding."""
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WANDERING, &"walk", ""), "wandering", "wandering")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WALKING, &"walk", ""), "walking to marker", "to a marker")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WALKING, &"walk", "hall steps"), "walking to hall steps", "to a POI")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WORKING, &"collect_object", "stockpile"), "working: collect object", "working")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WORKING, &"idle", "stockpile"), "working at stockpile", "between bouts")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_HOLDING, &"idle", ""), "holding", "holding")


func test_panel_placement_keeps_clear_of_the_hud_at_every_size() -> void:
	"""At 1280x720, 1920x1080, 2560x1440 and a HiDPI 3456x2160, the panel (with its carved frame)
	misses every HUD zone and the ordinary workspace, and stays on screen."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3456, 2160)]:
		var rect := PanelScript.placement(size.x, size.y, layout, geometry).grow(PanelScript.FRAME_EXPAND)
		var zones: Array[Rect2] = [geometry.resources, geometry.time, geometry.alerts, geometry.minimap,
			geometry.detail, geometry.commands, UiLayout.workspace_rect(geometry, UiLayout.WORKSPACE_MAX_HEIGHT)]
		var hits := 0
		for zone in zones:
			hits += 1 if rect.intersects(zone) else 0
		assert_equal(hits, 0, "%s: no HUD zone overlapped" % size)
		assert_true(Rect2(0, 0, geometry.logical_width, geometry.logical_height).encloses(rect), "%s: on screen" % size)
		assert_true(rect.size.y >= 250.0, "%s: room for a full party (%.0f px)" % [size, rect.size.y])


func test_panel_text_contrast_on_parchment() -> void:
	"""Ink (names) and umber (states, hint) both clear 4.5:1 on the parchment's darkest and lightest."""
	var parchment := PackedColorArray([Palette.face_dark(Palette.SURFACE_PARCHMENT), Palette.face_light(Palette.SURFACE_PARCHMENT)])
	assert_true(Contrast.worst_ratio(Palette.INK, parchment) >= Contrast.BODY_MINIMUM, "ink %.2f" % Contrast.worst_ratio(Palette.INK, parchment))
	assert_true(Contrast.worst_ratio(Palette.UMBER, parchment) >= Contrast.BODY_MINIMUM, "umber %.2f" % Contrast.worst_ratio(Palette.UMBER, parchment))


func test_friendly_names() -> void:
	"""Manifest keys read as names."""
	assert_equal(DemoActorScript.friendly_name(&"otter_boatwright"), "Otter boatwright", "a creature")
	assert_equal(DemoActorScript.friendly_name(&"placeholder_3"), "Placeholder 3", "a placeholder")
