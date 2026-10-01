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
	"""Nobody; one resident's name, species and state; a count and one line for EVERY member (review F31: no
	"+ n more")."""
	assert_equal(PanelScript.party_lines([]), PackedStringArray([PanelScript.NOBODY]), "nobody")
	var one: Array[Dictionary] = [{"name": "Otter boatwright", "species": "Otter", "state": "holding"}]
	assert_equal(PanelScript.party_lines(one), PackedStringArray(["Otter boatwright", "Otter", "holding"]), "one")
	var many: Array[Dictionary] = []
	for i in 9:
		many.append({"name": "R%d" % i, "species": "Mouse", "state": "wandering"})
	var lines := PanelScript.party_lines(many)
	assert_equal(lines[0], "9 residents", "a count")
	assert_equal(lines[1], "R0 — wandering", "a line each")
	assert_equal(lines.size(), 10, "every member, no remainder line")
	assert_equal(lines[9], "R8 — wandering", "the ninth too")


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


# --- the notice line is per resident; the orders list (decision 0205) ---------------------------------

const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const AbilitiesScript := preload("res://demo/control/resident_abilities.gd")


func _command() -> Array:
	"""A command layer over the placeholder cast (out of the tree): [command, cast, camera]."""
	var cast := DemoCastScript.new()
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera := Camera3D.new()
	var command := CommandScript.new()
	command.configure(cast, camera)
	command.panel().build()
	return [command, cast, camera]


func _free_all(parts: Array) -> void:
	"""Free a _command() set."""
	for node: Node in parts:
		node.free()


func test_the_notice_line_is_each_resident_s_own() -> void:
	"""The playtest's otter showed the mole's "Resuming the tunnel at 44%": a notice is now kept for whoever
	was selected when it was said, so selecting someone else shows theirs; a group shows its latest;
	nobody selected shows the general line."""
	var parts := _command()
	var command: CommandScript = parts[0]
	command.select(PackedInt32Array([0]))
	command.say("Resuming the tunnel at 44%")
	assert_equal(command.panel().notice(), "Resuming the tunnel at 44%", "the mole's")
	command.select(PackedInt32Array([1]))
	command._refresh_panel()
	assert_equal(command.panel().notice(), "", "the otter has none")
	command.say("1 diving")
	command.select(PackedInt32Array([0]))
	command._refresh_panel()
	assert_equal(command.panel().notice(), "Resuming the tunnel at 44%", "back to the mole: its own")
	command.select(PackedInt32Array([0, 1]))
	assert_equal(command.notice_for_selection(), "1 diving", "a group: the latest said to any of it")
	command.clear_selection()
	assert_equal(command.notice_for_selection(), "", "nobody: the general line, empty")
	command.say("Map overlay: moisture")
	command._refresh_panel()
	assert_equal(command.panel().notice(), "Map overlay: moisture", "said to nobody: shown to nobody")
	command.select(PackedInt32Array([1]))
	assert_equal(command.notice_for_selection(), "1 diving", "not to the otter")
	_free_all(parts)


func test_one_resident_s_orders_are_listed_with_the_gated_ones_explained() -> void:
	"""Everybeast moves, farms, clears spoil and works the woods; anybeast who fits a standard bore digs,
	moles as skilled diggers (decision 0208); only otters dive; the badger wades only, breaks rock and
	needs a widened bore; the beaver gnaws; each gate says why. A standard bore fits a body at most 1 m
	wide (2 x radius) and 1 m tall stooped to 85% (tunnel_rules.gd fit_refusal): up to ~1.176 m tall."""
	var mole: PackedStringArray = AbilitiesScript.lines_for("Mole", 0.9, 0.2, true)
	assert_equal(mole[0], AbilitiesScript.HEADING, "a heading")
	assert_true(mole.has(AbilitiesScript.CAN + AbilitiesScript.SKILLED_DIG_LINE), "the mole digs, skilled")
	assert_false(mole.has(AbilitiesScript.CAN + AbilitiesScript.DIG_LINE), "not the unskilled line as well")
	assert_false(mole.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_DIG_LINE), "and is not told it can't")
	assert_true(mole.has(AbilitiesScript.CAN + AbilitiesScript.SWIM_LINE), "and swims")
	var badger: PackedStringArray = AbilitiesScript.lines_for("Badger", 2.55, 0.56, true)
	for line: String in [AbilitiesScript.CANNOT + AbilitiesScript.NO_DIG_LINE, AbilitiesScript.CANNOT + AbilitiesScript.NO_BORE_LINE,
			AbilitiesScript.CAN + AbilitiesScript.ROCK_LINE, AbilitiesScript.CANNOT + AbilitiesScript.NO_SWIM_LINE]:
		assert_true(badger.has(line), "the badger: %s" % line)
	assert_false(badger.has(AbilitiesScript.CAN + AbilitiesScript.DIG_LINE), "the badger is not told it digs")
	var otter: PackedStringArray = AbilitiesScript.lines_for("Otter", 1.49, 0.33, true)
	assert_true(otter.has(AbilitiesScript.CAN + AbilitiesScript.DIVE_LINE), "the otter dives")
	assert_true(otter.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_BORE_LINE), "too tall for a standard bore")
	var mouse: PackedStringArray = AbilitiesScript.lines_for("Mouse", 1.0, 0.22, false)
	assert_true(mouse.has(AbilitiesScript.CAN + AbilitiesScript.BORE_LINE), "a mouse fits a bore")
	assert_true(mouse.has(AbilitiesScript.CAN + AbilitiesScript.DIG_LINE), "so a mouse (1.0 m) digs, unskilled")
	assert_false(mouse.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_DIG_LINE), "and is not told it can't")
	assert_true(otter.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_DIG_LINE), "the otter (1.49 m) cannot dig")
	assert_true(mouse.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_CARRY_LINE), "no carry walk: said")
	var beaver: PackedStringArray = AbilitiesScript.lines_for("Beaver", 1.4, 0.31, true)
	assert_true(beaver.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_DIG_LINE), "the beaver (1.4 m) cannot dig")
	assert_true(beaver.has(AbilitiesScript.CAN + AbilitiesScript.GNAW_LINE), "the beaver gnaws")
	assert_false(beaver.has(AbilitiesScript.CAN + AbilitiesScript.DIVE_LINE), "but does not dive (a fast swimmer)")
	assert_true(beaver.has(AbilitiesScript.CAN + AbilitiesScript.SWIM_LINE), "it swims")
	assert_true(mouse.has(AbilitiesScript.CANNOT + AbilitiesScript.NO_SPOIL_LINE), "no carry walk: no spoil hauling")
	for common: String in [AbilitiesScript.MOVE_LINE, AbilitiesScript.FARM_LINE]:
		assert_true(mouse.has(AbilitiesScript.CAN + common), "everybeast: %s" % common)
	assert_true(mole.has(AbilitiesScript.CAN + AbilitiesScript.SPOIL_LINE), "a carrier hauls spoil")


func test_the_panel_lists_one_resident_s_orders_in_full_and_never_hides() -> void:
	"""Selected alone, a resident's orders are listed IN FULL -- each with what to right-click (review F31: never
	folded away); in a group they are not. However short the column, the frame stays: the summary and actions sit
	above the inspector where they leave it MIN_INSPECTOR_H, else at its top (decision 0391)."""
	var panel := PanelScript.new()
	panel.build()
	var lines := PackedStringArray(["Orders (right-click):", "• Move or work — the ground, a work spot",
		"× Digging: too big for a bore", "• Water: swim, dive — deep water"])
	var one: Array[Dictionary] = [{"name": "Otter fisher", "species": "Otter", "state": "holding",
		"skills": "Felling 0\nSwims fast, dives", "abilities": lines}]
	panel.show_party(one)
	assert_equal(panel.abilities_text(), "\n".join(lines), "listed, every target kept")
	var two: Array[Dictionary] = [one[0].merged({"index": 0}), {"index": 1, "name": "Mole digger", "species": "Mole",
		"state": "holding", "abilities": lines}]
	panel.show_party(two)
	assert_equal(panel.abilities_text(), "", "a group: not listed")
	panel.show_party(one)
	assert_true(panel.fit(2000.0), "a tall column: docked")
	assert_true(panel.docked(), "the summary and actions above the inspector")
	assert_false(panel.fit(1.0), "no room: the summary and actions go to the inspector's top")
	assert_false(panel.docked(), "undocked")
	assert_equal(panel.abilities_text(), "\n".join(lines), "the orders still listed in full")
	assert_true(panel.fit(2000.0), "room again: docked again")
	panel.free()


func test_a_state_splits_into_its_command_and_its_progress() -> void:
	""""Digging tunnel — 43%" is the command "Digging tunnel" and the progress "43%" -- separate rows (F31)."""
	assert_equal(PanelScript.command_of("Digging tunnel — 43%"), "Digging tunnel", "the command")
	assert_equal(PanelScript.step_of("Digging tunnel — 43%"), "43%", "the progress")
	assert_equal(PanelScript.command_of("holding"), "holding", "no progress: all command")
	assert_equal(PanelScript.step_of("holding"), "", "and no progress")
	var one: Array[Dictionary] = [{"name": "Mole digger", "species": "Mole", "state": "Watering bed 1 — to the well"}]
	assert_equal(PanelScript.party_lines(one), PackedStringArray(["Mole digger", "Mole", "Watering bed 1",
		PanelScript.PROGRESS % "to the well"]), "a row each")


func test_a_refusal_step_reads_as_why_not_progress() -> void:
	"""A's refusals (decision 0361) in F's rows (0391): "holding — can't find a way there" is the command "holding" and
	the reason in its own words, not "Progress: ..."; a real step keeps its label."""
	var held: Array[Dictionary] = [{"name": "Mole digger", "species": "Mole",
		"state": PanelScript.HOLDING_REFUSED % BrainScript.REFUSED_NO_ROUTE}]
	assert_equal(PanelScript.party_lines(held), PackedStringArray(["Mole digger", "Mole", "holding",
		BrainScript.REFUSED_NO_ROUTE]), "the reason, unlabelled")
	assert_equal(PanelScript.step_line(BrainScript.REFUSED_BLOCKED), BrainScript.REFUSED_BLOCKED, "gave up")
	assert_equal(PanelScript.step_line("can't reach it, trying again"), "can't reach it, trying again", "spoil's wait")
	assert_equal(PanelScript.step_line("43%"), PanelScript.PROGRESS % "43%", "progress keeps its label")


func test_a_group_summary_tallies_its_activities_most_first() -> void:
	"""The group's common activity: each command and how many, most first, ties in selection order; one resident's
	summary is its name and state; nobody's says so; the count reads "n selected"."""
	var group: Array[Dictionary] = [{"name": "A", "state": "walking to well"}, {"name": "B", "state": "holding"},
		{"name": "C", "state": "holding"}, {"name": "D", "state": "Digging tunnel — 10%"},
		{"name": "E", "state": "Digging tunnel — 80%"}, {"name": "F", "state": "holding"}]
	assert_equal(PanelScript.summary_text(group), "Holding ×3 · Digging tunnel ×2 · Walking to well ×1", "tallied")
	assert_equal(PanelScript.summary_text([group[0]] as Array[Dictionary]), "A — walking to well", "one")
	assert_equal(PanelScript.summary_text([] as Array[Dictionary]), PanelScript.NOBODY, "nobody")
	assert_equal(PanelScript.count_text(6), "6 selected", "the count")
	assert_equal(PanelScript.count_text(0), "", "no count for nobody")


func test_every_member_is_a_row_that_picks_it() -> void:
	"""Nine selected: nine member rows (no "+ n more"), each at least 32 px tall, cut with an ellipsis and whole in
	its tooltip; pressing one emits its cast index (F20, F31). Release (R) shows for any selection."""
	var panel := PanelScript.new()
	panel.build()
	var nine: Array[Dictionary] = []
	for i: int in 9:
		nine.append({"index": 10 + i, "name": "Resident %d with a long name" % i, "state": "wandering", "skills": "fell 0 · saw 0"})
	panel.show_party(nine)
	assert_equal(panel.member_row_count(), 9, "a row for every member")
	var picked: Array[int] = []
	panel.member_picked.connect(func(i: int) -> void: picked.append(i))
	panel.member_row(8).pressed.emit()
	assert_equal(picked, [18] as Array[int], "the row's cast index")
	var row: Button = panel.member_row(3)
	assert_true(row.custom_minimum_size.y >= 32.0, "a 32 px target")
	assert_equal(row.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "cut with an ellipsis")
	assert_equal(row.tooltip_text, row.text, "whole in its tooltip")
	assert_equal(panel.count_shown(), "9 selected", "the count")
	assert_true(panel.release_button().visible, "Release (R) for any selection")
	panel.show_party([] as Array[Dictionary])
	assert_equal(panel.member_row_count(), 0, "nobody: no rows")
	assert_false(panel.release_button().visible, "and nothing to release")
	panel.free()


func test_the_ledger_never_hides_the_panel() -> void:
	"""Below an open ledger the column shrinks; where that leaves less than the fixed part, the column stays as it
	was (the ledger draws over it until it closes) -- the frame is never hidden (F20)."""
	var column := Rect2(26.0, 162.0, 320.0, 284.0)
	var below: Rect2 = PanelScript.below_ledger(column, 200.0, 120.0)
	assert_equal(below.position.y, 200.0 + PanelScript.LEDGER_GAP + PanelScript.FRAME_EXPAND, "moved below it")
	assert_equal(below.end.y, column.end.y, "to the same foot")
	assert_equal(PanelScript.below_ledger(column, 380.0, 120.0), column, "too little room: kept where it was")


func test_the_panel_says_what_a_resident_will_go_back_to() -> void:
	"""One resident with unfinished jobs: "Then back to:" and a row per job, latest first (F31: a list, not one
	joined line)."""
	var one: Array[Dictionary] = [{"name": "Mole digger", "species": "Mole", "state": "raising bed 3",
		"then": PackedStringArray(["Hang lanterns, tunnel 1", "Brace tunnel 2"])}]
	var lines: PackedStringArray = PanelScript.party_lines(one)
	assert_equal(lines[3], PanelScript.THEN_HEAD, "the heading")
	assert_equal(lines[4], PanelScript.BULLET + "Hang lanterns, tunnel 1", "the latest first")
	assert_equal(lines[5], PanelScript.BULLET + "Brace tunnel 2", "a row each")


func test_the_dig_button_says_what_it_does_and_its_key() -> void:
	"""The party panel's one action button has a hover tip naming its key (decision 0205)."""
	var panel := PanelScript.new()
	panel.build()
	assert_equal(panel.dig_button().tooltip_text, PanelScript.DIG_TIP, "the tip")
	assert_true(PanelScript.DIG_TIP.begins_with("Dig tunnel (B)"), "names the key (B opens the Dig tool)")
	assert_equal(panel.dig_button().text, PanelScript.DIG_BUTTON, "the button's words")
	assert_equal(PanelScript.DIG_BUTTON, "Dig tunnel (B)", "with the key")
	panel.free()


func test_a_tunnel_s_own_news_is_kept_for_its_mole() -> void:
	"""Review M3 (decision 0205): a tunnel opening or pausing on its own is kept for its mole, whoever is
	selected then -- the otter selected does not get the mole's "Tunnel paused at 44%"."""
	var parts := _command()
	var command: CommandScript = parts[0]
	command.select(PackedInt32Array([1]))
	command.say_about("Tunnel paused at 44%", 0)
	assert_equal(command.notice_for_selection(), "", "the otter selected: nothing of the mole's")
	command.select(PackedInt32Array([0]))
	assert_equal(command.notice_for_selection(), "Tunnel paused at 44%", "the mole's own")
	command.say_about("ignored", 99)
	assert_equal(command.notice_for_selection(), "Tunnel paused at 44%", "nobody by that index: nothing kept")
	_free_all(parts)
