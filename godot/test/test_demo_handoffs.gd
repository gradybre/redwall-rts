extends "res://test/framework/test_case.gd"
## The job hand-offs the review's F02-F05, F08, F09 and F15 found broken (decision 0361): each run through the
## real owners in the live process order -- every resident's brain stepped in cast order, then the owners that
## read them (the tunnel works, the spoil crew, the bridge crew) -- never by calling the helper a hand-off should
## have called. What is asserted is where residents end up, who owns the job and what was credited, not that a
## method was called. No scene tree beyond what the owners need; no staged assets.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const SpoilCrewScript := preload("res://demo/spoil/spoil_crew.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const WaterPlayTest := preload("res://test/test_demo_water_play.gd")
const LevelsTest := preload("res://test/test_demo_levels.gd")
const ViewTest := preload("res://test/test_demo_underground_view.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const DemoSpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

const DT: float = 1.0 / 60.0
const USEC: int = 16667
const BODY_M: float = 0.25
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
## A 12 m mouth-to-mouth dig east from the origin: a 4 m ramp, a 4 m bore and a 4 m ramp.
const DIG_ROUTE: PackedInt32Array = [0, 0, 12288, 0]
## A level-2 dig from the stairs' foot of the levels suite's two-level fixture, round and back across the lower bore:
## two segments, split where it crosses (decision 0212).
const LEVEL_2_ROUTE: Array[Vector2i] = [Vector2i(0, -3072), Vector2i(-6144, -3072), Vector2i(-6144, 2048), Vector2i(4096, 2048)]

var _nodes: Array[Node] = []
var _services: ServicesScript = null
## Another suite whose fixtures a test borrows (its after_each frees what they built).
var _borrowed: Array[RefCounted] = []


## A task that runs until told it is over, and can be come back to (the resume suite's fixture, kept here so the
## hand-off tests stand alone).
class SavedJob extends "res://demo/tunnel/tunnel_task.gd":
	var name: String = ""
	var taken_back: int = 0

	func _init(job_name: String) -> void:
		"""A job called `job_name`."""
		name = job_name

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Never over on its own."""
		return true

	func unfinished() -> RefCounted:
		"""Itself, taken back by ordering it again."""
		return UnfinishedScript.new(func(brain: RefCounted) -> bool:
			taken_back += 1
			(brain as BrainScript).order_task(self)
			return true, name)

	func label() -> String:
		"""Its name."""
		return name


## A task whose site is a node underground (a job deep in the network).
class BelowJob extends "res://demo/tunnel/tunnel_task.gd":
	var node: int = -1

	func _init(at_node: int) -> void:
		"""Bound for `at_node`."""
		node = at_node

	func site_node(_brain: RefCounted) -> int:
		"""The node below."""
		return node

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Never over on its own."""
		return true

	func unfinished() -> RefCounted:
		"""Kept to come back to."""
		return UnfinishedScript.new(func(_brain: RefCounted) -> bool: return false, "Below job")


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	for suite in _borrowed:
		suite.call(&"after_each")
	_borrowed.clear()


# --- fixtures -------------------------------------------------------------------------------------

func _lengths() -> Dictionary:
	"""Every clip the actor stages, 2 s long."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _brain(space: CastSpaceScript, at: Vector2, species: String) -> BrainScript:
	"""A resident of `species` standing at `at`, its body recorded (a 1 m mouse, a 0.9 m mole, a 2.55 m badger)."""
	var brain := BrainScript.new()
	brain.configure(space, 1.0, BODY_M, 4242 + space.resident_position.size(), _lengths())
	brain.start_at(at, 0.0, -1, -1)
	var tall := 2611 if species == "Badger" else (922 if species == "Mole" else 1024)
	space.tunnels.set_body(brain.index, tall, 574 if species == "Badger" else 225)
	space.tunnels.set_fit(brain.index, species != "Badger")
	return brain


func _works(space: CastSpaceScript, brains: Array[BrainScript], species: PackedStringArray) -> WorksScript:
	"""The tunnel works over this cast (out of the tree, stepped by hand), on soft ground."""
	var works := WorksScript.new()
	_nodes.append(works)
	works.setup(space, brains, species, BOUNDS_U, func(_t: String) -> void: pass, _services)
	works.ground.cells.fill(0)
	return works


func _actions(works: WorksScript, space: CastSpaceScript, count: int) -> ActionsScript:
	"""The player's tunnel orders over these works (every resident able to dig)."""
	var can_dig := PackedByteArray()
	can_dig.resize(count)
	can_dig.fill(1)
	var names := PackedStringArray()
	for i in count:
		names.append("Resident %d" % i)
	return ActionsScript.new(works, space, can_dig, names, BOUNDS_U)


func _frame(brains: Array[BrainScript], works: WorksScript, substeps: int) -> void:
	"""One live frame: every brain stepped `substeps` times in cast order (demo_cast.gd), then the works."""
	for brain in brains:
		for s in substeps:
			brain.step(DT)
	if works != null:
		works.step(USEC * substeps)


func _dig_all(network: GraphScript, p: int) -> void:
	"""Dig every segment of piece `p` open."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)


# --- F03: the crew follows the dig over a segment boundary, whichever is stepped first -------------

func _crew_cast(lead_first: bool, helper_species: String) -> Dictionary:
	"""A mole and one other resident (`helper_species`) on open ground, the mole first or last in cast order, the
	mole digging DIG_ROUTE and the other put on its crew by the player's crew order (tunnel_actions.gd).
	{space, brains, works, lead, helper, piece}."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var species := PackedStringArray(["Mole", helper_species] if lead_first else [helper_species, "Mole"])
	var lead := 0 if lead_first else 1
	var brains: Array[BrainScript] = []
	for i in 2:
		brains.append(_brain(space, Vector2.ZERO if i == lead else Vector2(-1.0, 1.0), species[i]))
	var works := _works(space, brains, species)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(DIG_ROUTE, 2, lead, ref), "the dig stored")
	brains[lead].order_dig(ref[0], ref[1])
	var joined := _actions(works, space, 2).add_crew(ref[0], PackedInt32Array([1 - lead]), lead)
	assert_equal(joined, 1, "the other joined the crew")
	return {"space": space, "brains": brains, "works": works, "lead": lead, "helper": 1 - lead, "piece": ref[2]}


func _crew_below(lead_first: bool) -> Dictionary:
	"""As `_crew_cast`, on the levels suite's two-level network: the mole digging LEVEL_2_ROUTE from the stairs' foot
	(walked to down the stairs), a badger -- too big for the bores -- its surface hand at the spoil mouth."""
	var graph := LevelsTest.two_levels(self)
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	space.tunnels = graph
	var plan := LevelsTest.plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, plan, LEVEL_2_ROUTE), Rules.REFUSE_NONE, "a level-2 dig laid by the rules")
	var species := PackedStringArray(["Mole", "Badger"] if lead_first else ["Badger", "Mole"])
	var lead := 0 if lead_first else 1
	var brains: Array[BrainScript] = []
	for i in 2:
		brains.append(_brain(space, Vector2(-11.0, -9.0) if i == lead else Vector2(-12.0, -10.0), species[i]))
	var works := _works(space, brains, species)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(lead), ref), "stored")
	graph.start_dig(ref[0], ref[1], lead)
	brains[lead].order_dig(ref[0], ref[1])
	assert_equal(_actions(works, space, 2).add_crew(ref[0], PackedInt32Array([1 - lead]), lead), 1, "joined")
	return {"space": space, "brains": brains, "works": works, "lead": lead, "helper": 1 - lead, "piece": ref[2]}


func _run_crew(c: Dictionary, substeps: int) -> Dictionary:
	"""Run a crew cast in live order until its piece is dug (at most 300 demo seconds): {done, off: frames the
	helper was off the crew or its crew place while the piece was not yet dug, segments: how many segments the
	helper's crew place was on}."""
	var network: GraphScript = (c["space"] as CastSpaceScript).tunnels
	var works: WorksScript = c["works"]
	var helper: BrainScript = (c["brains"] as Array[BrainScript])[c["helper"]]
	var off := 0
	var seen := PackedInt32Array()
	@warning_ignore("integer_division") for f in roundi(300.0 / DT) / substeps:
		_frame(c["brains"], works, substeps)
		if network.piece_done(c["piece"]):
			break
		var site: int = works.crew.member_site[helper.index]
		if site < 0 or not (helper.task is CrewTaskScript):
			off += 1
		elif not seen.has(site):
			seen.append(site)
	return {"done": network.piece_done(c["piece"]), "off": off, "segments": seen.size()}


func _assert_crew_kept(lead_first: bool, helper_species: String, substeps: int) -> void:
	"""The helper stays on the crew, its place following the dig into each segment, until the piece is dug."""
	var how := "%s %s at %dx" % ["lead first" if lead_first else "helper first", helper_species, substeps]
	_assert_followed(_crew_cast(lead_first, helper_species), substeps, 3, how)


func _assert_followed(c: Dictionary, substeps: int, segments: int, how: String) -> void:
	"""Run a crew case in live order: dug, the helper on the crew throughout, its place on each of `segments`."""
	var run := _run_crew(c, substeps)
	assert_true(run["done"], "the piece is dug (%s)" % how)
	assert_equal(run["off"], 0, "the helper never left the crew while it was dug (%s)" % how)
	assert_equal(run["segments"], segments, "its place followed the dig into each segment (%s)" % how)


func test_a_surface_hand_stays_on_the_crew_over_each_boundary_in_either_cast_order() -> void:
	"""F03: the Foremole stepped before its crew opens a segment and starts the next in its own update; the hand
	stepped after it must not read its old segment as the dig being over. Both cast orders, at 1x."""
	_assert_crew_kept(true, "Badger", 1)
	_assert_crew_kept(false, "Badger", 1)


func test_the_crew_stays_on_over_each_boundary_at_four_times() -> void:
	"""F03 at 4x: each actor runs all four of its sub-steps before the next actor's, and the works run once after."""
	_assert_crew_kept(true, "Badger", 4)
	_assert_crew_kept(false, "Badger", 4)


func test_the_crew_follows_a_level_two_dig_over_its_crossing() -> void:
	"""F03 on the second level: a dig from the stairs' foot split where it crosses the lower bore -- the Foremole first in
	cast order, at 1x and 4x."""
	_assert_followed(_crew_below(true), 1, 2, "level 2, lead first, 1x")
	_assert_followed(_crew_below(true), 4, 2, "level 2, lead first, 4x")


func test_a_crew_left_behind_two_segments_moves_on_to_the_one_being_dug() -> void:
	"""F03: a member reading its crew's segment open -- and the next of its piece open too (two opened before the works
	ran) -- finds the segment being dug now and moves the whole crew there."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var brain := _brain(space, Vector2(-2.0, 0.0), "Badger")
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(DIG_ROUTE, 2, 5, ref), "a dig")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for k in 2:
		network.start_dig(chain[k], network.generation[chain[k]], 5)
		network.advance(chain[k], network.generation[chain[k]], 1000000000)
	network.start_dig(chain[2], network.generation[chain[2]], 5)
	var crew := CrewScript.new()
	crew.set_resident(brain.index, "Badger")
	assert_true(crew.join(brain.index, chain[0]), "on the first segment's crew")
	var task := CrewTaskScript.new(crew, network, chain[0], false, Vector2(-2.0, 0.0),
		func(s: int) -> bool: return network.phase[s] == GraphScript.PHASE_DIGGING, func(_s: int) -> float: return 0.0)
	assert_true(task.step(brain, DT), "its place goes on")
	assert_equal([crew.member_site[brain.index], task.slot], [chain[2], chain[2]], "moved on to the segment being dug")


func test_a_member_below_stays_on_the_crew_over_each_boundary() -> void:
	"""F03 for a member who fits the bore and works below: lead first, at 1x and 4x."""
	_assert_crew_kept(true, "Mouse", 1)
	_assert_crew_kept(true, "Mouse", 4)


# --- F04: a finished dig takes the saved job back up ---------------------------------------------

func _dig_over_job(below_end: bool) -> Dictionary:
	"""A mole on a saved job, sent to dig a fresh piece: from a new mouth to a new mouth (ending on the surface), or
	(`below_end`) from a new mouth onto an open tunnel's bore (ending underground). {space, brain, job, piece}."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var brain := _brain(space, Vector2(2.0, 2.0), "Mole")
	var job := SavedJob.new("unfinished lanterns")
	brain.order_task(job)
	var ref := PackedInt32Array([-1, 0, -1])
	if not below_end:
		assert_true(space.tunnels.add_into(PackedInt32Array([4096, 2048, 16384, 2048]), 2, brain.index, ref), "stored")
	else:
		_dig_all(space.tunnels, _stored(space.tunnels, PackedInt32Array([4096, -4096, 16384, -4096])))
		var bore := _segment_at(space.tunnels, Vector2i(10240, -4096))
		var spec := SpecScript.new()
		spec.set_route(PackedInt32Array([10240, 4096, 10240, -4096]), 2)
		spec.end_kind = SpecScript.END_ON_SEGMENT
		spec.end_ref = bore
		spec.digger = brain.index
		assert_true(space.tunnels.add_piece(spec, ref), "a piece onto the bore stored")
		space.tunnels.start_dig(ref[0], ref[1], brain.index)
	brain.order_dig(ref[0], ref[1])
	assert_equal(brain.unfinished_labels(), PackedStringArray(["unfinished lanterns"]), "the job saved")
	return {"space": space, "brain": brain, "job": job, "piece": ref[2]}


func _stored(network: GraphScript, route: PackedInt32Array) -> int:
	"""A mouth-to-mouth piece along `route` stored; its piece row."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(route, 2, 0, ref), "a tunnel stored")
	return ref[2]


func _segment_at(network: GraphScript, at: Vector2i) -> int:
	"""The segment whose route passes nearest `at`."""
	var best := -1
	var best_d := INF
	for slot in Rules.MAX_SEGMENTS:
		if network.phase[slot] != GraphScript.PHASE_FREE:
			var d := network.distance_to_route(slot, Vector2(Rules.to_m(at.x), Rules.to_m(at.y)))
			if d < best_d:
				best_d = d
				best = slot
	return best


func _run_until(brains: Array[BrainScript], cond: Callable, seconds: float) -> bool:
	"""Step `brains` in cast order until `cond()` holds (at most `seconds`)."""
	for f in roundi(seconds / DT):
		if bool(cond.call()):
			return true
		_frame(brains, null, 1)
	return bool(cond.call())


func _assert_resumed(c: Dictionary, how: String) -> void:
	"""The dig is done, the resident stepped clear on the surface, and back on the very job it was called from."""
	var brain: BrainScript = c["brain"]
	var job: SavedJob = c["job"]
	var back := _run_until([brain] as Array[BrainScript], func() -> bool: return brain.task == job, 400.0)
	assert_true((c["space"] as CastSpaceScript).tunnels.piece_done(c["piece"]), "the piece dug (%s)" % how)
	assert_true(back, "back on the saved job by itself (%s)" % how)
	assert_equal([brain.order, job.taken_back, brain.unfinished_labels().size()], [BrainScript.ORDER_TASK, 1, 0],
		"under it, taken back once, nothing more saved (%s)" % how)
	assert_false(brain.underground, "taken up on the surface, never from inside a bore (%s)" % how)


func test_a_dig_ending_on_the_surface_takes_the_saved_job_back_up() -> void:
	"""F04: interrupted by a fresh dig, the job is taken up again once the dig's piece is through and the digger has
	stepped clear of the hole."""
	_assert_resumed(_dig_over_job(false), "ending at a mouth")


func test_a_dig_ending_underground_takes_the_saved_job_back_up() -> void:
	"""F04 for a piece that ends on another tunnel's bore: out by the nearest mouth, clear of it, then the job."""
	_assert_resumed(_dig_over_job(true), "ending below")


func test_a_dig_finished_at_night_keeps_the_job_for_the_morning() -> void:
	"""F04 with the night routine's parking (decision 0210): resting, the saved job is kept, not taken up."""
	var c := _dig_over_job(false)
	var brain: BrainScript = c["brain"]
	brain.resting = true
	var space: CastSpaceScript = c["space"]
	_run_until([brain] as Array[BrainScript], func() -> bool:
		return space.tunnels.piece_done(c["piece"]) and brain.state == BrainScript.State.HOLD, 400.0)
	_run_until([brain] as Array[BrainScript], func() -> bool: return false, 5.0)
	assert_equal([(c["job"] as SavedJob).taken_back, brain.unfinished_labels()], [0, PackedStringArray(["unfinished lanterns"])],
		"kept for the morning")


func test_a_new_order_while_stepping_clear_is_obeyed_not_overridden() -> void:
	"""F04 keeps the player's word: ordered elsewhere while it steps clear of the finished hole, the digger goes there
	and holds; the saved job waits (it is not taken up over the order)."""
	var c := _dig_over_job(false)
	var brain: BrainScript = c["brain"]
	var space: CastSpaceScript = c["space"]
	var stepping := _run_until([brain] as Array[BrainScript], func() -> bool:
		return space.tunnels.piece_done(c["piece"]) and brain.order == BrainScript.ORDER_MOVE \
			and (brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK), 400.0)
	assert_true(stepping, "stepping clear of the hole")
	brain.order_move(Vector2(-3.0, 6.0))
	_run_until([brain] as Array[BrainScript], func() -> bool: return false, 30.0)
	assert_true(brain.arrived_near(Vector2(-3.0, 6.0), 0.2), "where it was ordered")
	assert_equal([(c["job"] as SavedJob).taken_back, brain.order], [0, BrainScript.ORDER_MOVE], "holding there; the job waits")


func test_an_order_while_walking_out_below_is_obeyed_not_overridden() -> void:
	"""F04 keeps the player's word when the piece ended underground too: ordered elsewhere while it walks out of the
	network to step clear, the digger comes up and goes where it was ordered; it neither steps clear nor takes the saved
	job up over the order."""
	var c := _dig_over_job(true)
	var brain: BrainScript = c["brain"]
	var space: CastSpaceScript = c["space"]
	var walking_out := _run_until([brain] as Array[BrainScript], func() -> bool:
		return space.tunnels.piece_done(c["piece"]) and brain.state == BrainScript.State.TUNNEL, 400.0)
	assert_true(walking_out, "walking out of the network")
	brain.order_move(Vector2(-3.0, 6.0))
	_run_until([brain] as Array[BrainScript], func() -> bool: return false, 60.0)
	assert_true(brain.arrived_near(Vector2(-3.0, 6.0), 0.2), "where it was ordered: %s" % brain.position)
	assert_equal([(c["job"] as SavedJob).taken_back, brain.order], [0, BrainScript.ORDER_MOVE], "holding there; the job waits")


func test_the_players_release_mid_dig_still_forgets_the_saved_jobs() -> void:
	"""F04 keeps R: released while digging, the resident forgets every saved job and goes back to its own routine."""
	var c := _dig_over_job(false)
	var brain: BrainScript = c["brain"]
	_run_until([brain] as Array[BrainScript], func() -> bool: return brain.state == BrainScript.State.DIG, 60.0)
	brain.release()
	_run_until([brain] as Array[BrainScript], func() -> bool: return false, 30.0)
	assert_equal([(c["job"] as SavedJob).taken_back, brain.unfinished_labels().size(), brain.order],
		[0, 0, BrainScript.ORDER_NONE], "forgotten; back to its routine")


# --- F02: a route that no longer exists is refused, never walked -------------------------------------

func test_a_node_cut_off_before_the_mouth_is_reached_is_refused_with_a_reason() -> void:
	"""F02: a resident in a tunnel, sent to a node the closures have cut off, walks out at the nearest mouth still
	bound for the node; up there no route is found -- an empty one. It must not walk it: the job is suspended (kept
	to come back to), the resident holds where it came up, and it says why."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(DIG_ROUTE, 2, 0, ref), "a tunnel")
	_dig_all(space.tunnels, ref[2])
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	var brain := _brain(space, Vector2(-3.0, 0.0), "Mouse")
	brain.task_stand_in_bore(chain[2], 2.0, true)
	space.tunnels.close(chain[0], 1, 0, 4096)
	space.tunnels.close(chain[1], 1, 0, 4096)
	brain.order_task(BelowJob.new(space.tunnels.node_a[chain[1]]))
	var walked_empty := [false]
	_run_until([brain] as Array[BrainScript], func() -> bool:
		walked_empty[0] = walked_empty[0] or (brain.path.is_empty() and brain.state == BrainScript.State.WALK)
		return false, 30.0)
	assert_false(walked_empty[0], "never walking an empty route")
	assert_equal([brain.state, brain.underground, brain.order, brain.task], [BrainScript.State.HOLD, false,
		BrainScript.ORDER_MOVE, null], "holding where it came up, off the job")
	assert_equal(brain.unfinished_labels(), PackedStringArray(["Below job"]), "the job kept to come back to")


# --- F05: a failed walk is never taken for arrival -----------------------------------------------

func _wall_round(space: CastSpaceScript, at: Vector2, first_room: int) -> void:
	"""Twelve 0.45 m circles 1 m round `at`, overlapping: nobody gets in (three rooms' mounds' worth of circles,
	added as a mound is -- the obstacles and the navigation rebuilt)."""
	for r in 3:
		var circles := PackedVector3Array()
		for k in 4:
			var angle := TAU * float(r * 4 + k) / 12.0
			circles.append(Vector3(at.x + cos(angle), 0.45, at.y + sin(angle)))
		space.set_mound(first_room + r, circles)


func _spoil_cast() -> DemoCastScript:
	"""The placeholder cast, able to carry, in the village's bounds (the spoil suite's fixture)."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 1.3 * k / 65.0])
	for i: int in cast.actor_count():
		(cast.actor(i) as DemoActorScript).brain.set_carry_motion({"keys_xz": keys, "mean_speed_m_s": 0.2, "period_s": 6.5})
	return cast


func _spoil_site(cast: DemoCastScript) -> int:
	"""A dug 12 m tunnel east of the middle with its entrance heap placed; that heap (a mouth row)."""
	var network: GraphScript = cast.space().tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([4096, 6144, 16384, 6144]), 2, 0, ref), "a tunnel")
	_dig_all(network, ref[2])
	var heap: int = network.mouth_of_end(ref[0], false)
	HeapsScript.place(network, cast.space(), heap)
	return heap


func _spoil_frames(cast: DemoCastScript, crew: SpoilCrewScript, seconds: float, each: Callable) -> void:
	"""Every brain in cast order, then the crew, for `seconds`."""
	for f: int in roundi(seconds / DT):
		for i: int in cast.actor_count():
			(cast.actor(i) as DemoActorScript).brain.step(DT)
		crew.update(USEC)
		each.call()


func test_a_spoil_worker_walled_off_from_the_heap_digs_nothing_from_afar() -> void:
	"""F05: the walk to the heap fails (its spot walled round after the walk was given): the brain gives the trip up
	and holds where it is, saying why. The crew must not take that for arrival: the row pauses, and no spoil comes off
	the heap and nothing is delivered but by a worker standing at its spot (a retry may find another spot)."""
	var cast := _spoil_cast()
	var delivered := PackedInt64Array([0])
	var crew := SpoilCrewScript.new()
	crew.configure(cast, cast.space().tunnels, FarmTunnels.new(), null, func(milli: int) -> void: delivered[0] += milli, Vector2.ZERO)
	var heap := _spoil_site(cast)
	var heaped := crew.spoil_left(heap)
	assert_true(crew.order(heap, PackedInt32Array([1])).begins_with("Clearing"), "ordered")
	crew.update(USEC)
	var row := crew.row_of(1)
	_wall_round(cast.space(), crew.goal[row], 0)
	var brain := (cast.actor(1) as DemoActorScript).brain
	var seen := {"said": "", "paused": false, "remote": false, "left": crew.spoil_left(heap), "delivered": 0}
	_spoil_frames(cast, crew, 60.0, func() -> void:
		if brain.trip_failed() and seen["said"] == "":
			seen["said"] = brain.route_refusal()
		seen["paused"] = seen["paused"] or crew.blocked[row] == 1
		var changed: bool = crew.spoil_left(heap) != seen["left"] or delivered[0] != seen["delivered"]
		seen["remote"] = seen["remote"] or (changed and brain.position.distance_to(crew.goal[row]) > SpoilCrewScript.ARRIVE_M)
		seen["left"] = crew.spoil_left(heap)
		seen["delivered"] = delivered[0])
	assert_false(seen["said"] == "", "the walk was given up, saying why")
	assert_true(seen["paused"], "the row paused rather than taking the failure for arrival")
	assert_false(seen["remote"], "nothing dug or delivered but at the worker's own spot")
	assert_true(crew.spoil_left(heap) < heaped, "tried again, and worked the heap from a spot it reached")


func test_a_paused_spoil_worker_says_it_cannot_reach_it() -> void:
	"""F05 feedback: while a row waits to try again, the party panel's words for the worker say it can't reach it."""
	var cast := _spoil_cast()
	var crew := SpoilCrewScript.new()
	crew.configure(cast, cast.space().tunnels, FarmTunnels.new(), null, func(_m: int) -> void: pass, Vector2.ZERO)
	crew.order(_spoil_site(cast), PackedInt32Array([1]))
	crew.update(USEC)
	var row := crew.row_of(1)
	_wall_round(cast.space(), crew.goal[row], 0)
	var spoil := DemoSpoilScript.new()
	_nodes.append(spoil)
	spoil.crew = crew
	var said := [""]
	_spoil_frames(cast, crew, 30.0, func() -> void:
		if crew.blocked[row] == 1 and said[0] == "":
			said[0] = spoil.task_text(1))
	assert_equal(said[0], DemoSpoilScript.BLOCKED_TEXT % DemoSpoilScript.CLEARING_TEXT, "in words")


func _walled_drop() -> Array:
	"""A worker clearing a heap whose drop spot is walled round. [cast, crew, heap, heaped, delivered]."""
	var cast := _spoil_cast()
	var delivered := PackedInt64Array([0])
	var crew := SpoilCrewScript.new()
	crew.configure(cast, cast.space().tunnels, FarmTunnels.new(), null, func(milli: int) -> void: delivered[0] += milli, Vector2.ZERO)
	var heap := _spoil_site(cast)
	_wall_round(cast.space(), Vector2.ZERO, 0)
	var heaped := crew.spoil_left(heap)
	crew.order(heap, PackedInt32Array([1]))
	var kept := false
	for f in roundi(90.0 / DT):
		_spoil_frames(cast, crew, DT, func() -> void: pass)
		if crew.row_of(1) >= 0 and crew.blocked[crew.row_of(1)] == 1:
			kept = true
			break
	assert_true(kept, "waiting to try again")
	return [cast, crew, heap, heaped, delivered]


func test_a_basket_with_nowhere_reachable_to_tip_is_kept_then_put_back() -> void:
	"""F05 on the way back: the drop spot walled round, a worker with a basket finds nowhere to tip it. The basket is
	kept in hand -- never delivered from where it stands -- while the row tries again; after MAX_TRIES the row ends and
	the basket goes back on its heap: nothing delivered, nothing lost."""
	var w := _walled_drop()
	var crew: SpoilCrewScript = w[1]
	var delivered: PackedInt64Array = w[4]
	assert_equal([int(delivered[0]), crew.spoil_left(w[2]) + crew.in_hand_milli()], [0, w[3]], "kept in hand")
	assert_true(crew.in_hand_milli() > 0, "a basketful in hand")
	_spoil_frames(w[0], crew, 60.0, func() -> void: pass)
	assert_equal([crew.row_of(1), int(delivered[0]), crew.in_hand_milli(), crew.spoil_left(w[2])], [-1, 0, 0, w[3]],
		"given up: the basket back on the heap")


func test_a_worker_called_away_with_an_undelivered_basket_puts_it_back() -> void:
	"""F05 (the review's second look): called away while its basket waits for a drop spot, the worker does not deliver it
	from where it stands -- the load goes back on its heap and the job is kept to come back to."""
	var w := _walled_drop()
	var crew: SpoilCrewScript = w[1]
	var brain := ((w[0] as DemoCastScript).actor(1) as DemoActorScript).brain
	brain.order_move(brain.position + Vector2(-2.0, 0.0))
	crew.update(USEC)
	assert_equal([crew.row_of(1), int((w[4] as PackedInt64Array)[0]), crew.spoil_left(w[2])], [-1, 0, w[3]], "back on the heap")
	assert_equal(brain.unfinished_labels(), PackedStringArray(["Clear spoil heap"]), "kept to come back to")


func test_a_spoil_worker_pushed_off_its_spot_stops_digging() -> void:
	"""F05, rechecked while working: a worker digging at the heap who is no longer at its spot stops crediting work
	there and walks back first."""
	var cast := _spoil_cast()
	var crew := SpoilCrewScript.new()
	crew.configure(cast, cast.space().tunnels, FarmTunnels.new(), null, func(_m: int) -> void: pass, Vector2.ZERO)
	var heap := _spoil_site(cast)
	crew.order(heap, PackedInt32Array([1]))
	var row := crew.row_of(1)
	var brain := (cast.actor(1) as DemoActorScript).brain
	for f in roundi(60.0 / DT):
		if crew.step[row] == SpoilCrewScript.STEP_DIG:
			break
		_spoil_frames(cast, crew, DT, func() -> void: pass)
	assert_equal(crew.step[row], SpoilCrewScript.STEP_DIG, "digging at the heap")
	var heaped := crew.spoil_left(heap)
	brain.position += Vector2(3.0, 0.0)
	cast.space().move_resident(brain.index, brain.position)
	crew.update(SpoilCrewScript.DIG_USEC)
	assert_equal([crew.spoil_left(heap), crew.in_hand_milli()], [heaped, 0], "no load dug from three metres off")
	assert_equal(crew.step[row], SpoilCrewScript.STEP_GO, "walking back to its spot first")


func test_a_basket_whose_walk_out_failed_goes_back_to_the_pile() -> void:
	"""F05 for P5's basket hauling (decision 0211): a member whose walk out with its basket was given up returns the
	basket to the pile behind the face -- nothing is tipped on the heap from afar; one merely called away tips it there,
	as before. Three haulers on the mouth, so the heap is drawn at what was tipped."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(DIG_ROUTE, 2, 9, ref), "a dig")
	var m: int = network.spoil_mouth[ref[0]]
	var brains: Array[BrainScript] = []
	var crew := CrewScript.new()
	for i in 3:
		brains.append(_brain(space, Vector2(-2.0, float(i)), "Mouse"))
		crew.set_resident(i, "Mouse")
		network.haul.join(network, i, m)
	network.add_spoil(ref[0], 4000)
	var heap_before := network.haul.on_heap_milli(network, m)
	var took := network.haul.fill(network, 0)
	assert_true(took > 0, "a basketful: %d" % took)
	_cancel_hauler(crew, network, brains[0], true)
	assert_equal([network.haul.on_heap_milli(network, m), network.haul.pile_milli(network, m), network.haul.carried(network, m)],
		[heap_before, took, 0], "back on the pile, the heap as it was")
	var again := network.haul.fill(network, 1)
	assert_equal(again, took, "the pile filled again")
	_cancel_hauler(crew, network, brains[1], false)
	assert_equal(network.haul.on_heap_milli(network, m), heap_before + again, "called away: tipped on the heap")


func test_a_basket_is_tipped_only_at_its_tip_spot() -> void:
	"""F05 for P5's basket hauling: a member carrying its basket out that stands anywhere but its tip spot when its task
	runs again -- here put up at the mouth, its trip marked arrived -- walks on to the spot; nothing is tipped there."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(DIG_ROUTE, 2, 9, ref), "a dig")
	network.advance(ref[0], ref[1], 3000000)
	var member := _brain(space, network.mouth_at(network.spoil_mouth[ref[0]]) + Vector2(-1.0, 1.0), "Mouse")
	member.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 1.3]], "mean_speed_m_s": 0.2, "period_s": 6.5})
	var crew := CrewScript.new()
	crew.set_resident(member.index, "Mouse")
	crew.join(member.index, ref[0])
	var task := CrewTaskScript.new(crew, network, ref[0], true, network.point_at(ref[0], 0.5),
		func(_s: int) -> bool: return true, func(_s: int) -> float: return 1.5)
	member.order_task(task)
	var m: int = network.spoil_mouth[ref[0]]
	assert_true(_run_until([member] as Array[BrainScript], func() -> bool: return network.haul.mouth_of.size() > member.index \
		and network.haul.mouth_of[member.index] == m, 60.0), "at its post below")
	network.add_spoil(ref[0], 2000)
	assert_true(_run_until([member] as Array[BrainScript], func() -> bool: return task.haul_stage == CrewTaskScript.HAUL_OUT, 30.0),
		"carrying a basket out")
	member.task_surface_at(network.mouth_node[m])
	member.state = BrainScript.State.TASK
	member.trip_outcome = BrainScript.TRIP_ARRIVED
	var dumped := network.haul.on_heap_milli(network, m)
	task.step(member, DT)
	assert_equal([task.haul_stage, network.haul.on_heap_milli(network, m)], [CrewTaskScript.HAUL_OUT, dumped], "not tipped at the mouth")
	assert_true(member.state != BrainScript.State.TASK, "walking on to its tip spot: %d" % member.state)


func _cancel_hauler(crew: CrewScript, network: GraphScript, brain: BrainScript, walk_failed: bool) -> void:
	"""A crew place carrying its basket out, cancelled -- its walk given up, or called away."""
	var task := CrewTaskScript.new(crew, network, 0, true, Vector2.ZERO, func(_s: int) -> bool: return true,
		func(_s: int) -> float: return 0.0)
	task.haul_stage = CrewTaskScript.HAUL_OUT
	brain.trip_outcome = BrainScript.TRIP_FAILED if walk_failed else BrainScript.TRIP_UNDERWAY
	task.cancel(brain)


func _water_rig() -> Array:
	"""The water suite's rig (the placeholder cast on the village water, the water gameplay over it), with planks in
	the stores for a footbridge. [suite, rig]."""
	var suite: RefCounted = WaterPlayTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var rig: RefCounted = suite.call(&"_rig")
	(suite.get(&"_services") as ServicesScript).stores.add_planks(6000)
	return [suite, rig]


func _water_frames(rig: RefCounted, frames: int, each: Callable) -> void:
	"""The cast (each brain in cast order) and then the water, as demo_village.gd runs them."""
	var cast: DemoCastScript = rig.get(&"cast")
	for f in frames:
		cast.advance(0.1)
		rig.get(&"play").call(&"step", cast.clock.frame_usec)
		each.call()


func test_a_bridge_builder_walled_off_from_the_material_loads_nothing_and_says_so() -> void:
	"""F05 for the bridge crew: the walk to the plank stack fails (its spot walled round): the builder never starts
	loading from afar, no work is credited, the bridge waits for a builder again and the feed names who could not get
	there."""
	var pair := _water_rig()
	var rig: RefCounted = pair[1]
	var play: Node = rig.get(&"play")
	play.call(&"select_candidate", 0)
	play.call(&"build", SwimRules.KIND_PLANK, PackedInt32Array([3]))
	var crew: BridgeCrewScript = play.get(&"crew")
	_water_frames(rig, 1, func() -> void: pass)
	assert_equal([crew.builder[0], crew.issued[0]], [3, 1], "Placeholder 3 sent for the planks")
	var cast: DemoCastScript = rig.get(&"cast")
	_wall_round(cast.space(), crew.goal[0], 0)
	var brain := (cast.actor(3) as DemoActorScript).brain
	var remote := [false]
	_water_frames(rig, 600, func() -> void:
		remote[0] = remote[0] or (crew.builder[0] == 3 and crew.step[0] >= BridgeCrewScript.STEP_LOAD \
			and brain.position.distance_to(crew.goal[0]) > BridgeCrewScript.ARRIVE_M))
	assert_false(remote[0], "never loading from afar")
	assert_equal(play.get(&"bridges").percent(0), 0, "no work credited")
	assert_true(_water_feed_has(pair[0], "Placeholder 3 can't get to the material"), "the feed says who and why")
	assert_equal([crew.builder[0], brain.order], [BridgeCrewScript.NOBODY, BrainScript.ORDER_NONE], "the builder let go")


func test_a_bridge_refused_its_spot_names_the_builder_it_was_given_to() -> void:
	"""F15: with nowhere to stand by the material, the bridge is dropped and the feed names its builder --
	Placeholder 0, not the last of the cast (an index of -1 read as the last)."""
	var pair := _water_rig()
	var rig: RefCounted = pair[1]
	var play: Node = rig.get(&"play")
	play.call(&"select_candidate", 0)
	var said: String = play.call(&"build", SwimRules.KIND_PLANK, PackedInt32Array([0]))
	assert_true(said.contains("Placeholder 0 goes for"), said)
	var crew: BridgeCrewScript = play.get(&"crew")
	var source: Vector2 = crew.source_at[0]
	(rig.get(&"cast") as DemoCastScript).space().set_mound(0, PackedVector3Array([Vector3(source.x, 3.2, source.y)]))
	_water_frames(rig, 2, func() -> void: pass)
	assert_true(_water_feed_has(pair[0], "Placeholder 0 can't get to the material"), "named its own builder")
	assert_false(_water_feed_has(pair[0], "Placeholder 5 can't get to"), "not the cast's last")
	assert_equal(crew.builder[0], BridgeCrewScript.NOBODY, "the bridge waits for a builder")
	crew.set_crew(PackedInt32Array([0]))
	var revision := crew.revision
	_water_frames(rig, 30, func() -> void: pass)
	assert_equal([crew.builder[0], crew.revision], [BridgeCrewScript.NOBODY, revision],
		"the routine crew does not take it straight back up (UNREACHED_WAIT_USEC)")


func test_a_resident_index_that_names_nobody_is_refused() -> void:
	"""F15 at the boundaries: -1 (NOBODY) or one past the cast is no actor and names nobody -- never the cast's last."""
	expect_diagnostic("demo cast: no actor")
	expect_diagnostic("bridge crew: no resident")
	var pair := _water_rig()
	var rig: RefCounted = pair[1]
	var cast: DemoCastScript = rig.get(&"cast")
	assert_null(cast.actor(-1), "no actor -1")
	assert_null(cast.actor(cast.actor_count()), "none past the end")
	var crew: BridgeCrewScript = (rig.get(&"play") as Node).get(&"crew")
	assert_equal([crew.name_of(BridgeCrewScript.NOBODY), crew.name_of(0)], [BridgeCrewScript.UNNAMED, "Placeholder 0"], "named")


func _water_feed_has(suite: RefCounted, words: String) -> bool:
	"""Whether the water suite's feed holds a line containing `words`."""
	var notices: NoticesScript = (suite.get(&"_services") as ServicesScript).notices
	for k: int in notices.count():
		if notices.text(k).contains(words):
			return true
	return false


# --- F08: the Dig tool opens whenever some piece could fit --------------------------------------------

func _full_of_mouths(network: GraphScript) -> void:
	"""Twelve dug mouth-to-mouth tunnels, 3 m apart, in the village's west: every mouth row taken, segment rows to
	spare."""
	@warning_ignore("integer_division") for k in Rules.MAX_MOUTHS / 2:
		_dig_all(network, _stored(network, PackedInt32Array([-18432, 3072 * k - 18432, -8192, 3072 * k - 18432])))
	assert_equal(network.mouth_node.count(-1), 0, "every mouth row taken")
	assert_true(network.phase.count(GraphScript.PHASE_FREE) > 0, "segment rows to spare")


func _tool_full_of_mouths() -> ControlScript:
	"""The village as demo_village.gd wires it (the underground view suite's), every mouth row taken."""
	var suite: RefCounted = ViewTest.new()
	_borrowed.append(suite)
	var v: Dictionary = suite.call(&"_village")
	var tool: ControlScript = v["tool"]
	_full_of_mouths(tool.network)
	return tool


func test_a_connection_between_bores_is_dug_with_every_mouth_taken() -> void:
	"""F08: every mouth row taken, the Dig tool still opens -- a connection between two bores needs no mouth -- and
	the connection is laid and dug."""
	var tool := _tool_full_of_mouths()
	assert_true(tool.begin_plan(), "the tool opens: %s" % tool.notice())
	var x := Rules.to_m(-13432)
	assert_true(tool.lay_ground(Vector2(x, Rules.to_m(9216))), "on the tenth tunnel's bore: %s" % tool.notice())
	assert_true(tool.lay_ground(Vector2(x, Rules.to_m(12288))), "on the eleventh's: %s" % tool.notice())
	var pieces := tool.network.piece_live.count(1)
	assert_true(tool.confirm(), "the connection dug: %s" % tool.notice())
	assert_equal(tool.network.piece_live.count(1), pieces + 1, "stored")


func test_a_piece_needing_a_mouth_is_refused_naming_the_mouths() -> void:
	"""F08: the final piece is what is refused, for the capacity it would exhaust: a new mouth with every mouth row
	taken is refused in words that name the mouths -- not the whole network as full."""
	var graph := GraphScript.new()
	_full_of_mouths(graph)
	var plan := LevelsTest.plan_of(Rules.TOP_LEVEL, Rules.LINK_NONE)
	var reason := LevelsTest.lay(graph, plan, [Vector2i(4096, 0), Vector2i(16384, 0)] as Array[Vector2i])
	assert_equal(reason, Rules.REFUSE_NO_MOUTH_ROWS, "refused for its mouths")
	assert_true(Rules.link_text(reason, "").contains("24 mouths"), Rules.link_text(reason, ""))


func test_the_dig_tool_refuses_only_when_no_piece_could_fit_naming_what_ran_out() -> void:
	"""F08: with no segment row left nothing can be laid at all: the tool refuses to open, naming the bores."""
	var tool := _tool_full_of_mouths()
	for slot in Rules.MAX_SEGMENTS:
		if tool.network.phase[slot] == GraphScript.PHASE_FREE:
			tool.network.phase[slot] = GraphScript.PHASE_PLANNED
	assert_false(tool.begin_plan(), "nothing could fit")
	assert_true(tool.notice().contains(Rules.link_text(Rules.REFUSE_NO_SEGMENT_ROWS, "")), "naming the bores: %s" % tool.notice())


# --- integration with review batch 2 (decision 0332's action cards) ------------------------------------

func test_the_dig_tools_card_refuses_as_the_tool_does() -> void:
	"""F08 on the card: every mouth taken, the card allows the tool (a connection still fits); no segment row left, it
	refuses in `begin_plan`'s own words."""
	var tool := _tool_full_of_mouths()
	var card := CardScript.new()
	tool.tool_card_into(card, "Dig tunnel (B)", "the Dig tool")
	assert_true(card.is_ok(), "a connection still fits: %s" % card.text())
	for slot in Rules.MAX_SEGMENTS:
		if tool.network.phase[slot] == GraphScript.PHASE_FREE:
			tool.network.phase[slot] = GraphScript.PHASE_PLANNED
	tool.tool_card_into(card, "Dig tunnel (B)", "the Dig tool")
	assert_equal([card.code, card.reason], [ControlScript.TOOL_FULL_CODE, Rules.link_text(Rules.REFUSE_NO_SEGMENT_ROWS, "")],
		card.text())
	assert_false(tool.begin_plan(), "and the tool refuses")
	assert_true(tool.notice().contains(card.reason), "in the same words: %s" % tool.notice())


func test_an_unreached_bridge_says_so_while_the_crew_leaves_it() -> void:
	"""F05 on the Water panel: a bridge its builder could not get to reads "can't reach it" with the crew's wait, then
	waiting for a builder once the wait is over."""
	var pair := _water_rig()
	var rig: RefCounted = pair[1]
	var play: Node = rig.get(&"play")
	play.call(&"select_candidate", 0)
	play.call(&"build", SwimRules.KIND_PLANK, PackedInt32Array([0]))
	var crew: BridgeCrewScript = play.get(&"crew")
	var source: Vector2 = crew.source_at[0]
	(rig.get(&"cast") as DemoCastScript).space().set_mound(0, PackedVector3Array([Vector3(source.x, 3.2, source.y)]))
	_water_frames(rig, 2, func() -> void: pass)
	assert_equal(crew.builder[0], BridgeCrewScript.NOBODY, "let go")
	assert_equal(crew.job_text(0), BridgeCrewScript.UNREACHED_WAITING % 10, crew.job_text(0))
	crew.unreached_usec[0] = 0
	assert_equal(crew.job_text(0), BridgeCrewScript.STEP_WORDS[BridgeCrewScript.STEP_WAITING], "waiting again")
