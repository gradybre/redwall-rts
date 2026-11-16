extends "res://test/framework/test_case.gd"
## The demo's Mound host, its surface reader and its builder (decision 2002; demo_build_mound_host.gd,
## demo_build_mound_ground.gd, demo_build_mound_task.gd), off-tree with stand-ins for the village and the cast: Confirm
## all's routes, the batch's readers, what a hill would cover, scenery hidden under it, the residents' circles round it,
## picking and placing an edge, the builder sent and its whole build, and a hatch reached through the door.

const Host := preload("res://demo/build_panel/demo_build_mound_host.gd")
const Ground := preload("res://demo/build_panel/demo_build_mound_ground.gd")
const Task := preload("res://demo/build_panel/demo_build_mound_task.gd")
const Jobs := preload("res://demo/build_panel/demo_build_mound_jobs.gd")
const CastSpace := preload("res://demo/cast/cast_space.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DATUM: Vector2 = Vector2(0.0, 0.0)
const BOUNDS: Rect2i = Rect2i(0, 0, 40, 40)
const KITCHEN: int = 2

var _nodes: Array[Node] = []
var _batch: Batch = null
var _works: Works = null
var _fittings: Fittings = null
var _host: Host = null
var _said: PackedStringArray = PackedStringArray()


class _World extends RefCounted:
	## The village stand-in: a tree at (5.5, 5.5), a rain barrel at (30.5, 5.5), a mossy boulder at (12.5, 7.5).
	var hidden: PackedInt32Array = PackedInt32Array()
	var cover_calls: int = 0

	func placements() -> Array[Dictionary]:
		"""Three placements, none blocking (each counts where it stands)."""
		return [{"key": &"oak_mature", "at": Vector2(5.5, 5.5), "block": false},
			{"key": &"rain_barrel", "at": Vector2(30.5, 5.5), "block": false},
			{"key": &"mossy_boulder", "at": Vector2(12.5, 7.5), "block": false}]

	func hide_placement(k: int) -> bool:
		"""Hidden once."""
		if hidden.has(k):
			return false
		hidden.append(k)
		return true

	func hide_cover(_route: PackedVector2Array, _radius: float, _circles: PackedVector3Array) -> int:
		"""Counted."""
		cover_calls += 1
		return 0


class _Water extends RefCounted:
	## Water west of x = 2.3 m (a cell from 2 m has only its western corners in it).
	func is_water(at: Vector2i) -> bool:
		"""Water by its x in units."""
		return at.x < 2300


class _Space extends RefCounted:
	## The walking space stand-in: the circles it was handed.
	var circles: PackedVector3Array = PackedVector3Array()
	var calls: int = 0

	func set_build_mounds(made: PackedVector3Array) -> void:
		"""Kept."""
		circles = made
		calls += 1


class _Brain extends RefCounted:
	## A brain stand-in: the task it was ordered.
	var task: Object = null

	func order_task(made: Object) -> void:
		"""Taken."""
		task = made


class _Actor extends Node:
	## A resident stand-in.
	var display_name: String = "Wenna"
	var brain: _Brain = _Brain.new()


class _Cast extends Node:
	## The cast stand-in: one resident and the space.
	var one: _Actor = _Actor.new()
	var walking: _Space = _Space.new()

	func actor(_i: int) -> Node:
		"""The one resident."""
		return one

	func space() -> Object:
		"""The walking space."""
		return walking


class _Walker:
	extends "res://demo/cast/resident_brain.gd"
	## A brain stand-in for the builder's trip: going in and out, walking and playing only recorded.
	var walked_to: Vector2 = Vector2.INF
	var played: StringName = &""

	func task_go_indoors(inside: bool, _building: int) -> void:
		"""In or out."""
		indoors = inside

	func task_walk_to(point: Vector2) -> void:
		"""Recorded."""
		walked_to = point

	func task_play(clip_name: StringName) -> void:
		"""Recorded."""
		played = clip_name

	func task_face(_point: Vector2, _delta: float) -> void:
		"""Nothing to turn."""
		pass


func tolerates_outside_tree() -> bool:
	"""The host's drawing is placed off-tree here."""
	return true


func before_each() -> void:
	"""A batch, the works, the store and the host over a 40 × 40 area."""
	_batch = Batch.new()
	_batch.configure(BuildCatalog.new(), BOUNDS, 4096)
	_works = Works.new()
	_works.configure(BOUNDS)
	_fittings = Fittings.new()
	_host = Host.new()
	_nodes.append(_host)
	_host.configure(_batch, _works, _fittings, BOUNDS, DATUM)
	_host.view.threaded = false
	_said.clear()


func after_each() -> void:
	"""Free every node made."""
	for node: Node in _nodes:
		node.free()
	_nodes.clear()


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _say(words: String) -> void:
	"""The notice line."""
	_said.append(words)


func _kitchen() -> void:
	"""A Kitchen at (10, 10)-(15, 13) confirmed, its door north at (12, 10)."""
	assert_true(_host.submit_room(_rect(Vector2i(10, 10), Vector2i(15, 13)), KITCHEN), "a room")
	assert_true(bool(_host.submit_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0, false)["ok"]), "its door")


func test_confirm_alls_routes_order_rooms_doors_and_removals() -> void:
	"""A Mound room's cells wait for their heap with their type in the works; a door is ordered and removed; off the
	area or the rooms, refused in words."""
	_kitchen()
	assert_equal(_host.mounds.stage_of(Vector2i(15, 13)), Mounds.ORDERED, "waiting")
	assert_equal(_works.type_of(Mound.SURFACE, Vector2i(15, 13)), KITCHEN, "its type")
	assert_false(_host.submit_room(PackedInt32Array([50, 50]), KITCHEN), "off the area")
	var refused: Dictionary = _host.submit_edge(Vector2i(30, 30), 0, Mound.KIND_WINDOW, 0, false)
	assert_equal(refused, {"ok": false, "error": Mound.TEXT_OFF_OUTER}, "no room there")
	assert_true(bool(_host.submit_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0, true)["ok"]), "removed")
	assert_equal(_host.mounds.edge_count(), 0, "gone")


func test_the_batch_reads_the_store_through_the_host() -> void:
	"""Confirmed Mound cells, doors and edges reach the batch: a new room joined on is ✓ by the confirmed door."""
	_kitchen()
	_batch.host_changed()
	assert_true(_batch.is_surface_room(Vector2i(15, 13)), "a confirmed room")
	_batch.begin_stroke(KITCHEN, 0, Vector2i(10, 14), Mound.STYLE_MOUND)
	_batch.extend_stroke(Vector2i(15, 17))
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "served by the built door")
	assert_true(_host.taken(0, Vector3i(13, 10, 0)), "the door's second edge is taken")
	assert_true(_host.taken(0, Vector3i(13, 9, 2)), "named from outside")


func test_the_ground_says_what_a_hill_would_cover() -> void:
	"""BUILD-MOUND-008: water, a tree, a thing in words; scenery is nothing; no village: nothing."""
	var ground: Ground = Ground.new()
	assert_equal(ground.thing_at(Vector2i(5, 5)), "", "no village bound")
	ground.configure(_World.new(), _Water.new(), DATUM)
	assert_equal(ground.thing_at(Vector2i(1, 20)), Ground.WATER, "water")
	assert_equal(ground.thing_at(Vector2i(2, 20)), Ground.WATER, "a corner inset in the water")
	assert_equal(ground.thing_at(Vector2i(3, 20)), "", "dry")
	assert_equal(ground.thing_at(Vector2i(5, 5)), Ground.TREE, "a tree")
	assert_equal(ground.thing_at(Vector2i(30, 5)), "a rain barrel", "a thing in words")
	assert_equal(ground.thing_at(Vector2i(12, 7)), "", "scenery is nothing")
	assert_equal(Ground.thing_name(&"beech_mature"), Ground.TREE, "every placeholder tree")
	assert_equal(Ground.thing_name(&"water_butt"), "a water butt", "underscores read as spaces")


func test_the_reach_of_a_placement() -> void:
	"""A circle reaches a square it overlaps; a standing point only one it stands in."""
	var square: Rect2 = Rect2(10.0, 10.0, 1.0, 1.0)
	assert_true(Ground.reaches(PackedVector3Array([Vector3(9.5, 10.5, 0.6)]), square), "overlapping")
	assert_false(Ground.reaches(PackedVector3Array([Vector3(9.0, 10.5, 0.6)]), square), "short of it")
	assert_true(Ground.reaches(PackedVector3Array([Vector3(10.5, 10.5, 0.0)]), square), "standing in it")
	assert_false(Ground.reaches(PackedVector3Array([Vector3(9.9, 10.5, 0.0)]), square), "standing beside it")


func test_scenery_under_a_risen_hill_is_hidden_once() -> void:
	"""The boulder under the berm is hidden as the hill is heaped, once; the tree is never touched."""
	var world: _World = _World.new()
	_host.bind_village(world, _Water.new(), func() -> bool: return true)
	_kitchen()
	_host.tick(0.1, false, -1)
	assert_true(world.hidden.is_empty(), "not heaped yet")
	_host.mounds.advance(Vector2i(12, 10), Mounds.HEAPED)
	_host.tick(0.1, false, -1)
	assert_equal(world.hidden, PackedInt32Array([2]), "the boulder")
	assert_equal(world.cover_calls, 1, "the ground cover too")
	_host.mounds.advance(Vector2i(13, 10), Mounds.HEAPED)
	_host.tick(0.1, false, -1)
	assert_equal([world.hidden.size(), _host.ground.hidden], [1, 1], "once")
	var ground: Ground = Ground.new()
	assert_equal(ground.hide_covered({Vector2i(1, 1): true}), 0, "no village: nothing")


func test_residents_walk_round_the_hill_and_in_at_the_yard() -> void:
	"""Circles over the rooms and their first cells out, the yard left open; handed to the space when they change."""
	_kitchen()
	var cast: _Cast = _Cast.new()
	_nodes.append(cast)
	_nodes.append(cast.one)
	_host.bind_cast(cast, func() -> int: return -1, _say)
	_host.mounds.advance(Vector2i(12, 10), Mounds.HEAPED)
	_host.tick(0.1, false, -1)
	assert_equal(cast.walking.calls, 1, "handed once")
	var circles: PackedVector3Array = _host.hill_circles()
	assert_equal(cast.walking.circles, circles, "the circles")
	for cell: Vector2i in [Vector2i(9, 10), Vector2i(16, 13), Vector2i(13, 14), Vector2i(12, 12)]:
		var middle: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
		var covered: bool = false
		for circle: Vector3 in circles:
			covered = covered or Vector2(circle.x, circle.z).distance_to(middle) < circle.y
		assert_true(covered, "covered %s" % cell)
	for circle: Vector3 in circles:
		assert_false(Rect2(12.0, 8.0, 2.0, 2.0).has_point(Vector2(circle.x, circle.z)), "no circle in the door's path")
	_host.tick(0.1, false, -1)
	assert_equal(cast.walking.calls, 1, "unchanged: not again")


func test_the_builder_is_sent_when_work_waits_and_nobody_is_said_once() -> void:
	"""No work or no cast: nobody sent; nobody to pick: said once; a resident picked: sent, its trip ordered."""
	assert_false(_host.send_worker(), "no cast")
	var cast: _Cast = _Cast.new()
	_nodes.append(cast)
	_nodes.append(cast.one)
	var picked: Array[int] = [-1]
	_host.bind_cast(cast, func() -> int: return picked[0], _say)
	assert_false(_host.send_worker(), "no work")
	_kitchen()
	assert_false(_host.send_worker(), "nobody to pick")
	assert_false(_host.send_worker(), "again")
	assert_equal(_said, PackedStringArray([Host.NOBODY]), "said once")
	picked[0] = 0
	assert_true(_host.send_worker(), "sent")
	assert_equal(_said[_said.size() - 1], Host.SENT % "Wenna", "said who")
	assert_true(_host.working() and _host.works_with(0) and not _host.works_with(1), "at work")
	assert_true(cast.one.brain.task == _host.worker, "its trip ordered")
	assert_false(_host.send_worker(), "one at a time")


func test_picking_an_edge_and_placing_a_door_or_window() -> void:
	"""The nearest outer edge to the pointer, from inside a room or from the cell beside it; a door runs on from it or
	back when only that fits; a click places, a click on it takes it back; the hover's words."""
	_batch.begin_stroke(KITCHEN, 0, Vector2i(10, 10), Mound.STYLE_MOUND)
	_batch.extend_stroke(Vector2i(15, 13))
	_batch.finish_stroke()
	assert_equal(_host.edge_near(Vector2(12.5, 10.2)), Vector3i(12, 10, 0), "inside, by the north wall")
	assert_equal(_host.edge_near(Vector2(12.5, 9.7)), Vector3i(12, 10, 0), "outside it, the room's own edge")
	assert_equal(_host.edge_near(Vector2(12.5, 11.5)), Host.NO_EDGE, "mid-room: no outer edge")
	assert_equal(_host.anchor_for(Vector3i(15, 10, 0), Mound.KIND_DOOR, Vector2(15.7, 10.1)), Vector3i(14, 10, 0),
		"at the corner a door runs back")
	assert_equal(_host.anchor_for(Vector3i(12, 10, 0), Mound.KIND_DOOR, Vector2(12.7, 10.1)), Vector3i(12, 10, 0), "on")
	assert_equal(_host.anchor_for(Vector3i(12, 10, 0), Mound.KIND_DOOR, Vector2(12.2, 10.1)), Vector3i(11, 10, 0),
		"its near half: back")
	assert_equal(_host.anchor_for(Vector3i(12, 10, 0), Mound.KIND_WINDOW, Vector2(12.2, 10.1)), Vector3i(12, 10, 0),
		"a window where it is")
	_host.set_hover(0, Vector3i(12, 10, 0), Mound.KIND_DOOR, 1, Vector2(12.7, 10.1))
	assert_equal(_host.hover_words, "Place Front door, green, north side\n✓ Can build", "the hover's words")
	assert_equal(_host.place(0, Vector3i(12, 10, 0), Mound.KIND_DOOR, 1, Vector2(12.7, 10.1)), Validity.KIND_CAN_BUILD, "placed")
	_host.set_hover(0, Vector3i(13, 10, 0), Mound.KIND_DOOR, 1, Vector2(13.5, 10.1))
	assert_equal(_host.hover_words, "Click to remove it", "on it")
	assert_equal(_host.place(0, Vector3i(13, 10, 0), Mound.KIND_WINDOW, 0, Vector2(13.5, 10.1)), Validity.KIND_CAN_BUILD,
		"a click on it")
	assert_equal(_batch.mound_edges().live_count(), 0, "taken back")
	assert_equal(_host.place(0, Host.NO_EDGE, Mound.KIND_DOOR, 0, Vector2.ZERO), Validity.KIND_NOT_POSSIBLE, "no edge")
	_host.set_hover(0, Host.NO_EDGE, Mound.KIND_DOOR, 0, Vector2.ZERO)
	assert_equal([_host.hover, _host.hover_words], [Host.NO_EDGE, ""], "nothing hovered")


func test_a_hatch_is_reached_through_the_door_once_fitted() -> void:
	"""A way down on a Mound's floor: reachable once its cell is dug and the door fitted; walked to at the door's yard;
	off the Mounds always, at the way itself."""
	_kitchen()
	assert_true(_host.hatch_ready(Vector2i(30, 30)) and _host.hatch_site(Vector2i(30, 30)) == Vector2.INF, "off them")
	assert_false(_host.hatch_ready(Vector2i(11, 11)), "not dug")
	for stage: int in range(Mounds.HEAPED, Mounds.DUG + 1):
		_host.mounds.advance(Vector2i(11, 11), stage)
	assert_false(_host.hatch_ready(Vector2i(11, 11)), "the door not fitted")
	_host.mounds.fit_edge(0)
	assert_true(_host.hatch_ready(Vector2i(11, 11)), "ready")
	assert_equal(_host.hatch_site(Vector2i(11, 11)), Front.station_of(Vector3i(12, 10, 0), DATUM), "the door's yard")


func test_the_builder_builds_the_whole_mound_and_comes_out() -> void:
	"""The trip: heap from the yard at work, in at the door to dig and frame (its figure shown on the village's layer),
	out to top, the door fitted, then out and done; each job counted."""
	_kitchen()
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: Task = Task.new(_host.mounds, _works, _fittings, figure, DATUM, "Wenna")
	var walker: _Walker = _Walker.new()
	assert_equal(trip.site(walker), Front.station_of(Vector3i(12, 10, 0), DATUM), "the door's yard")
	assert_equal(trip.label(), "Going to the Mound to build it", "on the way")
	trip.arrived(walker)
	trip.step(walker, 0.1)
	assert_equal([walker.played, trip.label()], [Task.WORK_CLIP, "Building the Mound: heaping the hill"], "heaping")
	var went_in: bool = false
	for frame: int in 4000:
		if not trip.step(walker, 0.25):
			break
		if trip.inside():
			went_in = true
			assert_true(walker.indoors and figure.visible, "in at the door, drawn")
	assert_true(went_in, "went in to dig")
	assert_equal(_host.mounds.count(Mounds.TOPPED), 24, "every cell topped")
	assert_true(_host.mounds.edge_fitted(0), "the door fitted")
	assert_equal(trip.done, 24 * 4 + 1, "every job")
	assert_equal(_works.state(Mound.SURFACE, Vector2i(15, 13)), Works.OPEN, "open in the works")
	assert_false(walker.indoors or figure.visible or trip.inside(), "out")
	assert_false(trip.holds_when_lost(), "lost: back to its routine")
	assert_equal(trip.world_of(Vector2i(3, 4)), Vector3(3.5, 0.0, 4.5), "a cell's middle")
	assert_equal(figure.get(&"_body").get(&"layers"), Layers.SURFACE, "the figure on the village's layer")


func test_a_cancelled_trip_comes_out_and_apply_skips_a_gone_job() -> void:
	"""Called away: out at once; a job whose cell moved on already changes nothing."""
	_kitchen()
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: Task = Task.new(_host.mounds, _works, _fittings, figure, DATUM, "Wenna")
	var walker: _Walker = _Walker.new()
	walker.indoors = true
	trip.cancel(walker)
	assert_false(walker.indoors or trip.inside(), "out")
	var job: Dictionary = {"kind": Mounds.JOB_HEAP, "cell": Vector2i(12, 10), "row": -1}
	assert_true(trip.apply(job), "heaped")
	assert_false(trip.apply(job), "not twice")
	assert_equal(trip.at(), Vector2i.ZERO, "never inside")
	walker.indoors = true
	trip.finish(walker)
	assert_false(walker.indoors, "finished: out")


func test_the_hosts_figure_and_tags() -> void:
	"""The builder's figure hidden unless inside and cut away; the tags gathered in their order."""
	_kitchen()
	_host.tick(0.1, true, -1)
	var shown: Array[Label3D] = []
	_host.shown_tags(shown)
	assert_equal(shown.size(), 1, "the Mound's state only")
	assert_equal(shown[0].text, "Heaping the hill: 24 cells to go", "its words")
	_host.use_props(null)


func test_a_fitting_job_finds_its_window_again_after_a_removal() -> void:
	"""Review M2: rows shift when a door or window is removed, so a job holds its first edge and finds it again: the
	window is fitted, not the row that took its place; a job whose window is gone changes nothing."""
	_kitchen()
	_host.submit_edge(Vector2i(15, 11), 1, Mound.KIND_WINDOW, 0, false)
	var job: Dictionary = {"kind": Mounds.JOB_FIT_EDGE, "cell": Vector2i(15, 11), "row": 1, "edge": Vector3i(15, 11, 1)}
	assert_equal(Jobs.words(job, _host.mounds), "Fitting the window", "its words")
	_host.submit_edge(Vector2i(12, 10), 0, Mound.KIND_DOOR, 0, true)
	var figure: Figure = Figure.new()
	_nodes.append(figure)
	var trip: Task = Task.new(_host.mounds, _works, _fittings, figure, DATUM, "Wenna")
	assert_true(trip.apply(job), "fitted")
	assert_true(_host.mounds.edge_fitted(0) and _host.mounds.edge_kind(0) == Mound.KIND_WINDOW, "the window, now row 0")
	_host.submit_edge(Vector2i(15, 11), 1, Mound.KIND_WINDOW, 0, true)
	assert_false(trip.apply(job), "gone: nothing")
	assert_equal(Jobs.words(job, _host.mounds), "", "no words")


func test_the_live_loops_mound_stands_within_the_spaces_circles() -> void:
	"""Review M3: the live harness's grown Mound (96 cells) stands as fewer circles than the walking space keeps, so
	none is dropped and nobody walks onto the hill."""
	_host.submit_room(_rect(Vector2i(2, 22), Vector2i(17, 25)), KITCHEN)
	_host.submit_room(_rect(Vector2i(6, 26), Vector2i(9, 33)), KITCHEN)
	var circles: int = _host.hill_circles().size()
	assert_true(circles > 0 and circles * 2 <= CastSpace.BUILD_MOUND_CIRCLES, "%d circles" % circles)
