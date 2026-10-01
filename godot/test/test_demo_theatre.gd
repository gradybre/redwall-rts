extends "res://test/framework/test_case.gd"
## The construction theatre (decision 0211, the underground revamp's P5): the warren's particle budget and its stress
## test, the dig face's lantern and clods, the crews' baskets and the heap that grows load by load (its spoil located
## exactly: the conservation tests), braces and lanterns put up one at a time, the lanterns' bloom, fixtures rising
## out of their chalk rings, and walls that dry as they were dug. The hazards' warnings and the warren's surface signs
## are test_demo_warnings.gd's.
##
## No scene tree and no staged assets: brains are stepped at a fixed 60 Hz, nodes are built out of the tree and freed
## after each test.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HaulScript := preload("res://demo/tunnel/spoil_haul.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const DigTheatreScript := preload("res://demo/tunnel/dig_theatre.gd")
const HaulViewScript := preload("res://demo/tunnel/haul_view.gd")
const KitScript := preload("res://demo/tunnel/warren_kit.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")
const FixtureKitScript := preload("res://demo/burrow/fixture_kit.gd")
const InstallTaskScript := preload("res://demo/burrow/install_task.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DT: float = 1.0 / 60.0
const WALK_M_S: float = 1.0
const BODY_M: float = 0.25
const SEED: int = 5211

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing. (The suite runs before the tree does, so an emitter set going prints the engine's
	`!is_inside_tree` notice -- not an abort.)"""
	_nodes.append(node)
	return node


# --- fixtures -------------------------------------------------------------------------------------

func _lengths() -> Dictionary:
	"""Every clip the actor stages, 2 s long."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _space() -> CastSpaceScript:
	"""An open field."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	return space


func _open_tunnel(space: CastSpaceScript, points: Array[Vector2i]) -> PackedInt32Array:
	"""A mouth-to-mouth tunnel along these points, dug to the end (digger 0); its segments in dig order."""
	var flat := PackedInt32Array()
	for p in points:
		flat.append_array([p.x, p.y])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(flat, points.size(), 0, ref), "fixture tunnel stored")
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	for slot in chain:
		space.tunnels.start_dig(slot, space.tunnels.generation[slot], 0)
		space.tunnels.advance(slot, space.tunnels.generation[slot], 1000000000)
	return chain


func _brain(space: CastSpaceScript, at: Vector2) -> BrainScript:
	"""A resident at `at` who fits the bores."""
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_fit(brain.index, true)
	return brain


func _carry_motion() -> Dictionary:
	"""A straight carry root motion (test_demo_spoil.gd's): 0.2 m/s over 6.5 s."""
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 1.3 * k / 65.0])
	return {"keys_xz": keys, "mean_speed_m_s": 0.2, "period_s": 6.5}


func _located(network: GraphScript, m: int) -> bool:
	"""THE CONSERVATION: mouth `m`'s spoil is all located -- pile + carried + tipped is what the ledger holds, none of
	them below 0."""
	var haul: HaulScript = network.haul
	var pile := haul.pile_milli(network, m)
	var carried := haul.carried(network, m)
	var tipped := haul.on_heap_milli(network, m)
	return pile >= 0 and carried >= 0 and tipped >= 0 and pile + carried + tipped == network.heaped_milli(m)


static func _home(graph: GraphScript, at: Vector2i) -> int:
	"""A burrow home laid at `at` (u), turned 0, dug; its row."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(RoomsScript.TEMPLATE_HOME, at, 0, 0, ref)
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)
	return ref[0]


# --- the particle budget ----------------------------------------------------------------------------

func test_the_warren_s_particles_fit_their_budget() -> void:
	"""The table (warren_particles.gd): smoke 8 x 16, face clods 3 x 6, mound clods 3 x 4, dust 2 x 8, drips 2 x 6, sand
	2 x 6 -- 198 of 200; the smoke's share is the chimneys' own (fixture_kit.gd); and the pools built hold exactly the
	rest, no emitter more."""
	assert_equal(ParticlesScript.allocated(), 198, "198 allocated")
	assert_true(ParticlesScript.allocated() <= ParticlesScript.TOTAL, "within the 200")
	assert_equal(ParticlesScript.SMOKE_EMITTERS * ParticlesScript.SMOKE_AMOUNT, 128, "the smoke's 128 (P4)")
	assert_equal(ParticlesScript.SMOKE_AMOUNT, (_keep(FixtureKitScript.smoke()) as CPUParticles3D).amount,
		"the chimneys' own amount")
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	assert_equal(ParticlesScript.capacity_under(pools), 70, "the pools: the budget less the smoke")
	assert_equal(ParticlesScript.live_under(pools), 0, "none alive before anything asks")


func test_the_cap_holds_with_eight_homes_smoking_three_faces_a_seep_and_a_strain() -> void:
	"""THE STRESS TEST: eight homes with lit hearths all smoking, three dig faces throwing clods with their mounds
	throwing too, a dust puff, two seeps dripping and two strains trickling -- every warren emitter alive at once --
	holds no more than 200 particles; the tunnel overlay's mounds throw none of their own (they are the pool's)."""
	var graph := GraphScript.new()
	for k in RoomsScript.MAX_ROOMS:
		var r := _home(graph, Vector2i((k % 4) * 12288 - 18432, (k / 4) * 12288 - 6144))
		for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
			if FixturesScript.place_kind(RoomsScript.TEMPLATE_HOME, f) == RoomsScript.FIX_HEARTH:
				graph.fit.phase_of(graph, r, f)
				graph.fit.phase[r * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.fit.revision += 1
	var lights: LanternsScript = _keep(LanternsScript.new())
	lights.configure()
	var view: FixtureViewScript = _keep(FixtureViewScript.new())
	view.configure(graph, PropsScript.new(), lights, DemoClockScript.new())
	view.set_lit(func() -> bool: return true)
	view.refresh(0.1)
	var smoking := 0
	for r in RoomsScript.MAX_ROOMS:
		smoking += 1 if view.smoke(r).emitting else 0
	assert_equal(smoking, 8, "eight homes smoking")
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	for k in ParticlesScript.FACE_SLOTS:
		pools.burst_clods(k, Vector3(float(k), -1.0, 0.0), Vector3.BACK)
		pools.set_mound(k, Vector3(float(k), 0.1, 0.0), true)
	pools.puff(Vector3.ZERO, Layers.UNDERGROUND)
	for k in ParticlesScript.HAZARD_SLOTS:
		pools.set_hazard(k, false, Vector3(0.0, -0.3, float(k)), Vector3.FORWARD, 1.0, true)
		pools.set_hazard(k, true, Vector3(2.0, -0.3, float(k)), Vector3.FORWARD, 1.0, true)
	var live := ParticlesScript.live_under(view) + ParticlesScript.live_under(pools)
	var most := ParticlesScript.capacity_under(view) + ParticlesScript.capacity_under(pools)
	assert_true(live <= ParticlesScript.TOTAL, "alive at most 200 (%d)" % live)
	assert_true(most <= ParticlesScript.TOTAL, "and could never be more (%d)" % most)
	var space := _space()
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(space.tunnels, space)
	_open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	overlay.refresh()
	assert_equal(ParticlesScript.capacity_under(overlay), 0, "the overlay's mounds throw nothing of their own")


func test_the_pools_run_on_the_demo_clock() -> void:
	"""Every emitter takes the clock's speed: paused, a clod hangs where it is; at 4x it flies four times as fast."""
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	pools.set_speed(0.0)
	assert_almost_equal(pools.mound(0).speed_scale, 0.0, "paused: the mound's clods hold")
	assert_almost_equal(pools.hazard(1, true).speed_scale, 0.0, "and the sand")
	pools.set_speed(4.0)
	assert_almost_equal(pools.clods(2).speed_scale, 4.0, "4x")
	assert_almost_equal(pools.dust(1).speed_scale, 4.0, "the dust too")


func test_a_puff_takes_the_next_dust_emitter_on_its_layer() -> void:
	"""Puffs go round the dust pool, each on the layer asked (surface at a heap, underground at a brace), restarted."""
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	pools.puff(Vector3(1.0, 0.0, 2.0), Layers.SURFACE)
	pools.puff(Vector3(3.0, -1.0, 4.0), Layers.UNDERGROUND)
	assert_equal([pools.dust(0).layers, pools.dust(1).layers], [Layers.SURFACE, Layers.UNDERGROUND], "each its layer")
	assert_equal(pools.dust(0).position, Vector3(1.0, 0.0, 2.0), "where asked")
	assert_true(pools.dust(0).emitting and pools.dust(1).emitting, "both puffing")
	pools.puff(Vector3(5.0, 0.0, 5.0), Layers.SURFACE)
	assert_equal(pools.dust(0).position, Vector3(5.0, 0.0, 5.0), "round to the first again")
	assert_equal(pools.puffs, 3, "three puffs")


# --- the baskets: the ledger located, exactly -------------------------------------------------------

func test_a_mouth_nobody_hauls_for_draws_all_it_has_received() -> void:
	"""With no hauler, a heap is drawn at everything posted to it -- nothing in a pile, nothing carried -- as before P5,
	and more posted shows at once."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var haul: HaulScript = network.haul
	assert_equal(haul.on_heap_milli(network, 0), network.heaped_milli(0), "all on the heap")
	assert_equal([haul.pile_milli(network, 0), haul.carried(network, 0)], [0, 0], "none on the way")
	network.add_spoil(chain[1], 2400)
	assert_equal(haul.on_heap_milli(network, 0), network.heaped_milli(0), "a re-dig's spoil on it at once")
	assert_true(_located(network, 0), "located")


func test_haulers_locate_every_milli_of_the_spoil() -> void:
	"""THE CONSERVATION: two haulers join; what is cut piles behind the face; a fill takes the whole pile into a basket;
	a tip moves the basket onto the heap; a hauler leaving tips what it carries; the last to leave takes the pile too.
	Pile + carried + tipped equals the ledger at every step, and the ledger never changes for it."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var haul: HaulScript = network.haul
	var ledger := network.heaped_milli(0)
	haul.join(network, 0, 0)
	haul.join(network, 1, 0)
	assert_equal(haul.haulers[0], 2, "two haulers")
	network.add_spoil(chain[1], 2000)
	assert_equal(haul.pile_milli(network, 0), 2000, "a quantum's spoil piles behind the face")
	assert_equal(haul.on_heap_milli(network, 0), ledger, "the heap drawn as it was")
	assert_equal(haul.fill(network, 0), 2000, "a basketful: the whole pile")
	assert_true(_located(network, 0), "located while carried")
	network.add_spoil(chain[1], 1800)
	assert_equal(haul.fill(network, 1), 1800, "the next basket takes what has piled since")
	network.add_spoil(chain[1], 200)
	assert_equal(haul.fill(network, 1), 200, "topped up")
	assert_equal(haul.basket_of(1), 2000, "its basket holds both")
	assert_true(_located(network, 0), "located topped up")
	assert_equal(haul.fill(network, 1), 0, "nothing left to take")
	assert_equal(haul.tip(network, 0), 2000, "tipped")
	assert_equal(haul.on_heap_milli(network, 0), ledger + 2000, "the heap grows by the load")
	assert_true(_located(network, 0), "located after a tip")
	network.add_spoil(chain[1], 2400)
	haul.leave(network, 1)
	assert_equal(haul.on_heap_milli(network, 0), ledger + 4000, "a hauler leaving tips its basket")
	assert_equal(haul.pile_milli(network, 0), 2400, "the pile waits for the one still hauling")
	haul.leave(network, 0)
	assert_equal(haul.on_heap_milli(network, 0), network.heaped_milli(0), "the last to leave takes the pile")
	assert_equal(network.heaped_milli(0), ledger + 6400, "the ledger: every cut, posted at the cut")
	assert_true(_located(network, 0), "located at the end")


func test_a_mouth_row_freed_starts_its_heap_clean() -> void:
	"""A mouth row freed and laid again (its generation moved on) forgets its haulers and their baskets."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var haul: HaulScript = network.haul
	haul.join(network, 0, 0)
	network.add_spoil(chain[1], 2000)
	haul.fill(network, 0)
	network.mouth_gen[0] += 1
	network.mouth_spoil[0] = 0
	assert_equal([haul.on_heap_milli(network, 0), haul.carried(network, 0), haul.pile_milli(network, 0)], [0, 0, 0], "clean")
	assert_equal([haul.mouth_of[0], haul.basket_of(0), haul.haulers[0]], [-1, 0, 0], "its hauler forgotten")


func test_the_farm_takes_only_what_is_tipped() -> void:
	"""The farm's spoil books (farm_tunnels.gd) read the heap as tipped: a basket on the way is not on it yet, so it may
	not be taken; tipped, it may."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var haul: HaulScript = network.haul
	var books := FarmTunnels.new()
	var tipped := haul.on_heap_milli(network, 0)
	haul.join(network, 0, 0)
	network.add_spoil(chain[1], 2000)
	haul.fill(network, 0)
	assert_equal(books.spoil_left(network, 0), tipped, "the basket's load is not on the heap yet")
	var read := IntMath.IntResult.new()
	assert_false(books.take_spoil_into(network, 0, tipped + 1, read), "no more than is tipped")
	haul.tip(network, 0)
	assert_true(books.take_spoil_into(network, 0, tipped + 1, read), "tipped: it may")
	assert_equal(books.spoil_left(network, 0), 1999, "and the rest is left")


func test_a_crew_member_fills_carries_out_and_tips_a_basket() -> void:
	"""A mouse at its post 2 m behind the Foremole: a quantum's spoil cut, it fills a basket (FILL_S), carries it out
	through the ramp and up to the heap, tips it (TIP_S) -- the heap growing by exactly that load, the spoil located
	every frame -- and walks back down to its post; all the while it counts as at its post, so the dig's rate is as
	before."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	HeapsScript.place(network, space, 0)
	HeapsScript.place(network, space, 1)
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, Vector2(-1.5, 1.0))
	member.set_carry_motion(_carry_motion())
	crew.join(0, chain[1])
	var task := CrewTaskScript.new(crew, network, chain[1], true, Vector2(-1.5, 1.0),
		func(_s: int) -> bool: return true, func(s: int) -> float: return 2.0 if s == chain[1] else 0.0)
	member.order_task(task)
	var haul: HaulScript = network.haul
	member.step(DT)
	assert_equal(crew.member_present[0], 0, "on its first way in: not yet at its post")
	for f in 60 * 30:
		member.step(DT)
		if haul.mouth_of.size() > 0 and haul.mouth_of[0] == 0:
			break
	assert_equal(haul.mouth_of[0], 0, "at its post, hauling for the spoil mouth")
	var before := haul.on_heap_milli(network, 0)
	network.add_spoil(chain[1], 2000)
	var stages := {}
	var present := true
	var located := true
	var laden := 0
	var carrying := 0
	var tipping := 0
	for f in 60 * 60:
		member.step(DT)
		stages[haul.stage_of(0)] = true
		tipping += 1 if haul.stage_of(0) == HaulScript.STAGE_TIPPING else 0
		carrying += 1 if haul.stage_of(0) == HaulScript.STAGE_CARRYING else 0
		laden += 1 if haul.stage_of(0) == HaulScript.STAGE_CARRYING and member.carrying else 0
		present = present and crew.member_present[0] == 1
		located = located and _located(network, 0)
		if haul.on_heap_milli(network, 0) > before and task.haul_stage == CrewTaskScript.HAUL_POST:
			break
	assert_true(tipping >= int(CrewTaskScript.TIP_S * 60.0) - 2, "tipped for TIP_S (%d frames)" % tipping)
	assert_true(laden >= carrying - 1 and laden > 0, "carried loaded all the way (%d of %d frames)" % [laden, carrying])
	member.step(DT)
	assert_false(member.underground, "walks back from the heap, not put straight back below")
	assert_true(stages.has(HaulScript.STAGE_FILLING) and stages.has(HaulScript.STAGE_CARRYING) and stages.has(HaulScript.STAGE_TIPPING),
		"filled, carried, tipped (%s)" % str(stages.keys()))
	assert_equal(haul.on_heap_milli(network, 0), before + 2000, "the heap grew by the load")
	assert_true(located, "the spoil located every frame")
	assert_true(present, "counted at its post throughout the round")
	var walking_back := 0
	for f in 60 * 30:
		member.step(DT)
		walking_back += 1
		present = present and crew.member_present[0] == 1
		if task._entered and member.state == BrainScript.State.TASK:
			break
	assert_true(member.underground and task._entered, "back down at its post (%d frames)" % walking_back)
	assert_true(walking_back > 60, "a real walk back")
	assert_true(present, "counted at its post on the walk back too: the dig's rate is unchanged by hauling")
	assert_equal(crew.member_present[0], 1, "back at its post: present")


func test_one_fills_at_a_time_and_only_a_basketful() -> void:
	"""At its post (spoil cut before anyone hauled is on the heap already): less than a quantum's spoil behind the face,
	nobody fills; a basketful, one member does; a second
	member of the same mouth waits while the first is filling, and fills when it is not."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	crew.set_resident(1, "Mouse")
	var one := _brain(space, Vector2(-1.5, 1.0))
	var two := _brain(space, Vector2(-1.5, 2.0))
	var tasks: Array = []
	for member: BrainScript in [one, two]:
		crew.join(member.index, chain[1])
		tasks.append(CrewTaskScript.new(crew, network, chain[1], true, Vector2(-1.5, 1.0),
			func(_s: int) -> bool: return true, func(_s: int) -> float: return 2.0))
	var haul: HaulScript = network.haul
	assert_false(tasks[0]._at_post(one, 1 << 40) or tasks[1]._at_post(two, 1 << 40), "both joined, nothing behind the face")
	network.add_spoil(chain[1], CrewTaskScript.MIN_LOAD_MILLI / 2)
	assert_false(tasks[0]._at_post(one, CrewTaskScript.MIN_LOAD_MILLI), "half a basket: not yet")
	assert_equal(haul.stage_of(one.index), HaulScript.STAGE_NONE, "not filling")
	network.add_spoil(chain[1], CrewTaskScript.MIN_LOAD_MILLI / 2)
	assert_false(tasks[1]._at_post(two, CrewTaskScript.MIN_LOAD_MILLI + 1), "its own least not reached")
	assert_true(tasks[0]._at_post(one, CrewTaskScript.MIN_LOAD_MILLI), "a basketful: fills")
	assert_equal(haul.stage_of(one.index), HaulScript.STAGE_FILLING, "filling")
	network.add_spoil(chain[1], CrewTaskScript.MIN_LOAD_MILLI)
	assert_false(tasks[1]._at_post(two, CrewTaskScript.MIN_LOAD_MILLI), "the other waits while it fills")
	haul.set_stage(one.index, HaulScript.STAGE_CARRYING, 1000)
	assert_true(tasks[1]._at_post(two, CrewTaskScript.MIN_LOAD_MILLI), "and fills when it is carrying")


func test_a_hauler_whose_mouth_is_gone_goes_back_to_its_post() -> void:
	"""On its way to the heap, its mouth row freed: no heap to tip at -- it stops hauling (the basket's spoil went with
	the row, spoil_haul.gd) and goes back to its post, reading no freed row."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, Vector2(-1.5, 1.0))
	crew.join(0, chain[1])
	var task := CrewTaskScript.new(crew, network, chain[1], true, Vector2(-1.5, 1.0),
		func(_s: int) -> bool: return true, func(_s: int) -> float: return 2.0)
	member.order_task(task)
	var free := 0
	while network.is_mouth(free):
		free += 1
	task._mouth = free
	task.haul_stage = CrewTaskScript.HAUL_TIP
	network.haul.set_stage(0, HaulScript.STAGE_TIPPING, 300)
	assert_true(task.step(member, DT), "its place goes on")
	assert_equal(task.haul_stage, CrewTaskScript.HAUL_POST, "back to its post")
	assert_equal(network.haul.stage_of(0), HaulScript.STAGE_NONE, "no basket drawn")


func test_a_hauler_called_away_drops_its_load_on_the_heap() -> void:
	"""A member carrying a basket, called away: its load is tipped at once and its place on the crew ends."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, Vector2(-1.5, 1.0))
	crew.join(0, chain[1])
	var task := CrewTaskScript.new(crew, network, chain[1], true, Vector2(-1.5, 1.0),
		func(_s: int) -> bool: return true, func(_s: int) -> float: return 2.0)
	var haul: HaulScript = network.haul
	haul.join(network, 0, 0)
	network.add_spoil(chain[1], 2000)
	haul.fill(network, 0)
	task.cancel(member)
	assert_equal([haul.basket_of(0), haul.mouth_of[0], crew.member_site[0]], [0, -1, -1], "load tipped, off the crew")
	assert_true(_located(network, 0), "located")


func test_the_last_basket_goes_out_when_the_dig_is_done() -> void:
	"""The Foremole's work over, a member at its post with spoil still behind the face takes it out in one last basket
	and its place ends at the heap; with nothing behind it, its place ends at once."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	HeapsScript.place(network, space, 0)
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, Vector2(-1.5, 1.0))
	crew.join(0, chain[1])
	var active := [true]
	var task := CrewTaskScript.new(crew, network, chain[1], true, Vector2(-1.5, 1.0),
		func(_s: int) -> bool: return active[0], func(_s: int) -> float: return 2.0)
	member.order_task(task)
	var haul: HaulScript = network.haul
	for f in 60 * 30:
		member.step(DT)
		if haul.mouth_of.size() > 0 and haul.mouth_of[0] == 0:
			break
	network.add_spoil(chain[1], 1000)
	active[0] = false
	for f in 60 * 60:
		member.step(DT)
		if member.task == null:
			break
	assert_true(member.task == null, "its place ended")
	assert_equal(haul.pile_milli(network, 0), 0, "nothing left behind the face")
	assert_equal(haul.on_heap_milli(network, 0), network.heaped_milli(0), "all of it on the heap")
	assert_false(member.underground, "it ended at the heap, on the surface")


## A task that only walks to a spot and counts its arrivals.
class SpotTask extends "res://demo/tunnel/tunnel_task.gd":
	var spot: Vector2 = Vector2.ZERO
	var arrivals: int = 0

	func _init(at: Vector2) -> void:
		"""A walk to `at`."""
		spot = at

	func site(_brain: RefCounted) -> Vector2:
		"""The spot."""
		return spot

	func arrived(_brain: RefCounted) -> void:
		"""Count it."""
		arrivals += 1

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Stay."""
		return true


func test_two_sent_to_one_spot_both_reach_it() -> void:
	"""Two of a crew sent to one mouth at once, from either side: they crowd each other on the spot, and the one stuck
	within CROWDED_SITE_M of it has arrived (and goes in, off the spot: here, moved away), so the other reaches it too
	-- neither gives its task up after its replans."""
	var space := _space()
	var first := _brain(space, Vector2(3.0, 0.2))
	var second := _brain(space, Vector2(-3.0, -0.2))
	var spot := Vector2.ZERO
	var one := SpotTask.new(spot)
	var two := SpotTask.new(spot)
	first.order_task(one)
	second.order_task(two)
	var gone := [false, false]
	for f in 60 * 40:
		first.step(DT)
		second.step(DT)
		for pair: Array in [[first, one, 0], [second, two, 1]]:
			if (pair[1] as SpotTask).arrivals > 0 and not gone[pair[2]]:
				gone[pair[2]] = true
				(pair[0] as BrainScript).start_at(Vector2(0.0, 8.0 + 2.0 * float(pair[2])), 0.0, -1, -1)
		if gone[0] and gone[1]:
			break
	assert_equal([one.arrivals, two.arrivals], [1, 1], "both reached it")


## A task whose site is a node below.
class NodeTask extends "res://demo/tunnel/tunnel_task.gd":
	var node: int = -1

	func _init(at_node: int) -> void:
		"""A walk to `at_node`."""
		node = at_node

	func site_node(_brain: RefCounted) -> int:
		"""The node."""
		return node

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Stay."""
		return true


func test_a_replan_that_finds_no_way_gives_the_trip_up() -> void:
	"""On its way to a node below, the way there closed (flooded): the replan finds no route at all, and the trip is
	given up -- not walked along a route with no legs."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	var walker := _brain(space, Vector2(-3.0, 0.0))
	var task := NodeTask.new(network.node_b[chain[0]])
	walker.order_task(task)
	assert_true(walker.path.size() > 0, "on its way")
	for slot in chain:
		network.close(slot, GraphScript.CLOSED_FLOODED, 0, network.length_u[slot])
	walker._replan_or_abandon()
	assert_true(walker.task != task, "given up")


func test_the_baskets_are_drawn_as_the_hauling_stands() -> void:
	"""A filler's basket stands before it, its spoil rising with the fill; a carrier holds the loaded basket (and lets it
	go after); a tipper's basket leans toward the heap, emptying; tipped, a puff."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var network := space.tunnels
	HeapsScript.place(network, space, 0)
	var cast := _keep(_one_mouse_cast()) as DemoCastScript
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var view: HaulViewScript = _keep(HaulViewScript.new())
	view.configure(network, cast, pools)
	var haul: HaulScript = network.haul
	haul.join(network, 0, 0)
	haul.set_stage(0, HaulScript.STAGE_FILLING, 500)
	view.refresh()
	assert_true(view.basket(0).visible, "the basket stands before the filler")
	var half: float = (view.basket(0).get_child(1) as Node3D).scale.y
	haul.set_stage(0, HaulScript.STAGE_FILLING, 1000)
	view.refresh()
	assert_true((view.basket(0).get_child(1) as Node3D).scale.y > half, "its spoil rises")
	haul.set_stage(0, HaulScript.STAGE_CARRYING, 1000)
	view.refresh()
	var actor := cast.actor(0) as DemoActorScript
	assert_true(actor.holding() and actor.held_mesh() == KitScript.loaded_basket(), "carried in the hands")
	assert_false(view.basket(0).visible, "none on the floor")
	haul.set_stage(0, HaulScript.STAGE_TIPPING, 200)
	view.refresh()
	assert_false(actor.holding(), "let go to tip")
	var toward := (network.heap_at[0] - actor.brain.position).normalized()
	var at := Vector2(view.basket(0).position.x, view.basket(0).position.z) - actor.brain.position
	assert_true(at.normalized().dot(toward) > 0.99, "tipped toward the heap")
	haul.set_stage(0, HaulScript.STAGE_NONE, 0)
	view.refresh()
	assert_equal(pools.puffs, 1, "a puff where it tipped")
	assert_false(view.basket(0).visible, "put away")


func _one_mouse_cast() -> DemoCastScript:
	"""The placeholder cast (no staged assets), its first resident at (-2, 1)."""
	var cast := DemoCastScript.new()
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	(cast.actor(0) as DemoActorScript).brain.start_at(Vector2(-2.0, 1.0), 0.0, -1, -1)
	return cast


# --- the dig face ------------------------------------------------------------------------------------

func test_a_face_gets_its_lantern_light_and_clods() -> void:
	"""A digger standing in a segment being dug is a face: it gets the first face slot -- the hand lantern set down on
	the floor behind and beside it, one of the pooled lights over it -- and a burst of clods with each new cut; the digger
	gone, the slot is let go, the lantern put away and the light out."""
	var space := _space()
	var network := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	network.start_dig(chain[0], network.generation[chain[0]], 0)
	network.advance(chain[0], network.generation[chain[0]], 1000000000)
	var slot := chain[1]
	var digger := _brain(space, Vector2.ZERO)
	network.start_dig(slot, network.generation[slot], digger.index)
	network.advance(slot, network.generation[slot], 150 * 1000000 / Rules.TICKS_PER_SECOND)
	digger.task_stand_in_bore(slot, network.face_m(slot), true)
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	var lights: LanternsScript = _keep(LanternsScript.new())
	lights.configure()
	var theatre: DigTheatreScript = _keep(DigTheatreScript.new())
	theatre.configure(network, space, pools, lights, Callable())
	theatre.refresh()
	assert_equal(theatre.slot_of(0), slot, "the face has the first slot")
	assert_true(theatre.lantern(0).visible, "its lantern set down")
	assert_equal(theatre.lantern(0).layers, Layers.UNDERGROUND, "below")
	var face := theatre.face_at(0)
	var lantern := theatre.lantern(0).position
	assert_true(lantern.x < face.x - 0.3, "behind the digger (%s, face %s)" % [lantern, face])
	assert_true(absf(lantern.z - face.z) > 0.2, "and beside it")
	assert_equal(lights.spot_count(), 1, "a light over it")
	assert_equal(pools.bursts, 0, "no clods before a cut")
	network.advance(slot, network.generation[slot], 5 * 1000000)
	theatre.refresh()
	assert_equal(pools.bursts, 1, "a burst of clods for the new cut")
	assert_true(pools.clods(0).emitting, "flying")
	digger.task_stand_in_bore(chain[0], 1.0, true)
	theatre.refresh()
	assert_equal(theatre.slot_of(0), -1, "its digger in another bore: no face")
	digger.task_stand_in_bore(slot, network.face_m(slot), true)
	theatre.refresh()
	assert_equal(theatre.slot_of(0), slot, "back at it")
	digger.task_surface_at(network.node_a[chain[0]])
	theatre.refresh()
	assert_equal(theatre.slot_of(0), -1, "the digger gone: let go")
	assert_false(theatre.lantern(0).visible, "the lantern put away")
	assert_equal(lights.spot_count(), 0, "the light out")


func test_the_dig_face_is_a_rough_concave_fresh_cut() -> void:
	"""bore_mesh.gd THE FACE: its middle FACE_DEPTH_M into the earth ahead of the last ring and wholly fresh-cut
	(COLOR.a 0); its rings between, rough, hollowed further in toward the middle; the rim as the last ring and only
	partly fresh."""
	var builder := BoreMeshScript.new()
	builder.begin()
	for ring in 3:
		builder.add_ring(ring, Vector3(0.0, 0.0, float(ring) * BoreMeshScript.RING_STEP_M), Vector2(0.0, 1.0), Rules.BORE_STANDARD,
			BoreMeshScript.PLAIN, 0.0)
	var face_z := 2.0 * BoreMeshScript.RING_STEP_M
	builder.add_face(Vector3(0.0, 0.0, face_z), Vector2(0.0, 1.0), Rules.BORE_STANDARD)
	var mesh := ArrayMesh.new()
	builder.commit(mesh)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var middle: Vector3 = points[points.size() - 1]
	assert_almost_equal(middle.z, face_z + BoreMeshScript.FACE_DEPTH_M, "its middle hollowed in")
	assert_almost_equal(colours[colours.size() - 1].a, 0.0, "wholly fresh-cut")
	var rim := 3 * BoreMeshScript.PROFILE_VERTS
	assert_almost_equal(points[rim].z, face_z, "the rim is the last ring")
	assert_true(absf(colours[rim].a - (1.0 - BoreMeshScript.FACE_RIM_MARK)) < 0.01, "only partly fresh (8-bit colour)")
	var inner := rim + (BoreMeshScript.FACE_RINGS - 1) * BoreMeshScript.PROFILE_VERTS
	var deeper := 0
	for k in BoreMeshScript.PROFILE_VERTS:
		deeper += 1 if points[inner + k].z > face_z + 0.05 else 0
	assert_equal(deeper, BoreMeshScript.PROFILE_VERTS, "the inner ring hollowed further in")
	var z_of := PackedFloat32Array()
	for k in BoreMeshScript.PROFILE_VERTS:
		z_of.append(points[rim + BoreMeshScript.PROFILE_VERTS + k].z)
	assert_true(z_of[0] != z_of[5] or z_of[3] != z_of[9], "rough: not a smooth bowl")


# --- braces and lanterns put up one at a time ---------------------------------------------------------

func _marks_site(length_u: int = 12288) -> Array:
	"""A tunnel this long (12 m) open, its marks, jobs and pools: [network, marks, jobs, pools, bore segment]."""
	var space := _space()
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(length_u, 0)])
	var network := space.tunnels
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(network, HazardsScript.new(network), PropsScript.new(), DemoClockScript.new())
	var jobs := JobsScript.new(network, StoresScript.new())
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	marks.set_theatre(jobs, pools)
	return [network, marks, jobs, pools, chain[1]]


func test_braces_go_up_one_at_a_time_each_with_a_puff() -> void:
	"""While a BRACE job works, a frame stands for each metre the work has reached, the newest rising from the floor
	with a puff of dust; nothing before it is paid for; braced, every frame stands."""
	var site := _marks_site()
	var network: GraphScript = site[0]
	var marks: MarksScript = site[1]
	var jobs: JobsScript = site[2]
	var pools: ParticlesScript = site[3]
	var slot: int = site[4]
	jobs.post(slot, JobsScript.JOB_BRACE, 0, 0, network.length_u[slot])
	jobs.work_usec[slot] = jobs.total[slot] * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND * 2 / 3
	marks.refresh()
	assert_equal(marks.frames_up(slot), 0, "posted, not paid: none, however far the work")
	jobs.work_usec[slot] = 0
	jobs.paid[slot] = 1
	jobs.work_usec[slot] = jobs.total[slot] * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND / 3
	marks.refresh()
	var early := marks.frames_up(slot)
	assert_true(early >= 1, "a third done: some frames (%d)" % early)
	assert_equal(pools.puffs, 1, "a puff for the newest")
	assert_equal(marks._rise_kind[slot], MarksScript.RISE_FRAME, "it rises")
	jobs.work_usec[slot] = jobs.total[slot] * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND * 2 / 3
	marks.refresh()
	assert_true(marks.frames_up(slot) > early, "more as the work goes on")
	assert_equal(pools.puffs, 2, "a puff each time")
	jobs.finish(slot)
	marks.refresh()
	assert_equal(marks.frames(slot).multimesh.visible_instance_count, marks.frames_up(slot), "braced: all of them")
	assert_true(marks.frames_up(slot) > early, "all the frames")


func test_lanterns_hang_one_at_a_time_their_glow_swelling() -> void:
	"""While a LANTERNS job works, the lanterns hang as far as the work has reached, the newest's glow swelling on; each
	hung lantern is a light spot."""
	var site := _marks_site(30720)
	var network: GraphScript = site[0]
	var marks: MarksScript = site[1]
	var jobs: JobsScript = site[2]
	var slot: int = site[4]
	jobs.post(slot, JobsScript.JOB_LANTERNS, 0, 0, network.length_u[slot])
	jobs.paid[slot] = 1
	jobs.work_usec[slot] = jobs.total[slot] * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND * 3 / 5
	marks.refresh()
	var early := marks.lanterns_up(slot)
	assert_true(early >= 1 and early < marks._lantern_count(slot), "three fifths done: some, not all (%d of %d)" % [early, marks._lantern_count(slot)])
	jobs.work_usec[slot] = jobs.total[slot] * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND
	marks.refresh()
	assert_true(marks.lanterns_up(slot) > early, "hung as the work reached them")
	assert_equal(marks._rise_kind[slot], MarksScript.RISE_GLOW, "the newest's glow swells")
	assert_equal(marks.lights.spot_count(), marks.lanterns_up(slot), "each a light spot")


func test_a_frame_rises_and_a_glow_swells_to_whole() -> void:
	"""rise_share starts at nothing and ends whole; swell_share starts at nothing, swells past whole and settles."""
	assert_almost_equal(MarksScript.rise_share(0.0), 0.0, "nothing at first")
	assert_almost_equal(MarksScript.rise_share(1.0), 1.0, "whole at the end")
	assert_true(MarksScript.rise_share(0.5) > 0.5, "mostly up by half time")
	assert_almost_equal(MarksScript.swell_share(0.0), 0.0, "no glow at first")
	assert_almost_equal(MarksScript.swell_share(1.0), 1.0, "whole at the end")
	assert_true(MarksScript.swell_share(0.6) > 1.0, "past whole on the way")


# --- the lanterns' bloom -------------------------------------------------------------------------------

func test_a_light_blooms_on_and_settles() -> void:
	"""bloom: nothing before its spot was hung, swelling to BLOOM_PEAK at BLOOM_S, settling to whole by twice that."""
	assert_almost_equal(LanternsScript.bloom(0.0), 0.0, "hung this moment: dark")
	assert_almost_equal(LanternsScript.bloom(-1.0), 0.0, "before")
	assert_almost_equal(LanternsScript.bloom(LanternsScript.BLOOM_S), LanternsScript.BLOOM_PEAK, "the peak")
	assert_almost_equal(LanternsScript.bloom(LanternsScript.BLOOM_S * 2.0), 1.0, "settled")
	assert_almost_equal(LanternsScript.bloom(60.0), 1.0, "and stays")
	assert_almost_equal(LanternsScript.bloom(LanternsScript.BLOOM_S * 0.5), LanternsScript.BLOOM_PEAK * 0.5, "half the peak half way")


func test_a_spot_keeps_its_age_when_handed_in_again() -> void:
	"""births: a spot already in the row keeps when it was hung; a new one is hung now."""
	var old := PackedVector3Array([Vector3.ZERO, Vector3(4.0, 0.0, 0.0)])
	var ages := PackedFloat32Array([1.0, 2.0])
	var born := LanternsScript.births(old, ages, PackedVector3Array([Vector3(4.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)]), 9.0)
	assert_equal(born, PackedFloat32Array([2.0, 9.0]), "the kept one's age, the new one now")
	var lights: LanternsScript = _keep(LanternsScript.new())
	lights.configure()
	lights._time = 5.0
	lights.set_spots(0, PackedVector3Array([Vector3.ZERO]))
	lights.flicker()
	assert_almost_equal(lights.light(0).light_energy, 0.0, "just hung: dark")
	lights._time = 7.0
	lights.flicker()
	assert_true(lights.light(0).light_energy > LanternsScript.ENERGY * 0.8, "bloomed")


func test_a_face_spot_moves_without_blooming_again() -> void:
	"""A dig face's hand lantern is a row of its own: set, moved a little (the same spot, its age kept), and put out."""
	var lights: LanternsScript = _keep(LanternsScript.new())
	lights.configure()
	lights._time = 3.0
	lights.set_face_spot(1, Vector3(1.0, -1.0, 0.0), true)
	assert_equal(lights.spot_count(), 1, "lit")
	var assigned := lights.assignments
	lights.set_face_spot(1, Vector3(1.0, -1.0, 0.01), true)
	assert_equal(lights.assignments, assigned, "a hair's move changes nothing")
	lights.set_face_spot(1, Vector3.ZERO, false)
	assert_equal(lights.spot_count(), 0, "out")


# --- fixtures rise out of their chalk rings --------------------------------------------------------------

func test_a_fixture_rises_from_its_ring_as_it_is_put_in_then_puffs() -> void:
	"""A planned bed with work on it rises out of the floor through its ring, higher as the work goes on; in, the
	rising piece is gone (the fixture stands) and a puff marks it."""
	var graph := GraphScript.new()
	var r := _home(graph, Vector2i.ZERO)
	var stores := StoresScript.new()
	stores.add_planks(2000)
	graph.fit.order(graph, r, RoomsScript.FIX_BED, stores)
	var lights: LanternsScript = _keep(LanternsScript.new())
	lights.configure()
	var view: FixtureViewScript = _keep(FixtureViewScript.new())
	view.configure(graph, PropsScript.new(), lights, DemoClockScript.new())
	var pools: ParticlesScript = _keep(ParticlesScript.new())
	pools.configure()
	view.set_particles(pools)
	view.refresh(0.0)
	assert_null(view.rising(r, 0), "planned, not worked: only the ring")
	assert_true(graph.fit.claim(graph, r, 0, 3), "claimed")
	graph.fit.work(graph, r, 0, 3, FixturesScript.install_usec(RoomsScript.FIX_BED) / 4)
	view.refresh(0.0)
	var rising := view.rising(r, 0)
	assert_not_null(rising, "worked: rising")
	var low := rising.position.y
	assert_true(low < 0.0, "under the floor still (%.3f)" % low)
	graph.fit.work(graph, r, 0, 3, FixturesScript.install_usec(RoomsScript.FIX_BED) / 2)
	view.refresh(0.0)
	assert_true(view.rising(r, 0).position.y > low, "higher as the work goes on")
	graph.fit.work(graph, r, 0, 3, FixturesScript.install_usec(RoomsScript.FIX_BED))
	view.refresh(0.0)
	assert_null(view.rising(r, 0), "in: it stands")
	assert_equal(pools.puffs, 1, "a puff")


func test_the_installer_heaves_the_big_pieces_and_hangs_the_light_ones() -> void:
	"""The heavy pull for a bed, a large bed, a hearth, a table, a shelf, a rack or a bin; the hand clip for a lantern,
	the hanging stores or a rug."""
	for kind: int in [RoomsScript.FIX_BED, RoomsScript.FIX_BIG_BED, RoomsScript.FIX_HEARTH, RoomsScript.FIX_TABLE,
			RoomsScript.FIX_SHELF, RoomsScript.FIX_RACK, RoomsScript.FIX_BIN]:
		assert_equal(InstallTaskScript.clip_for(kind), InstallTaskScript.HEAVY_CLIP, "%s: heaved" % RoomsScript.FIXTURE_NAMES[kind])
	for kind: int in [RoomsScript.FIX_LANTERN, RoomsScript.FIX_HANGING, RoomsScript.FIX_RUG]:
		assert_equal(InstallTaskScript.clip_for(kind), InstallTaskScript.WORK_CLIP, "%s: hung or laid" % RoomsScript.FIXTURE_NAMES[kind])


# --- drying ----------------------------------------------------------------------------------------------

func test_a_room_dries_from_the_door_outward_as_it_was_dug() -> void:
	"""Each stage of a home's dig remembers its day; the walls take the day of the stage that first took them in -- the
	door's end dug first -- and a rebuild later (a socket broken through) keeps them; the newest stage is fresh-cut
	while it is dug."""
	var space := _space()
	var graph := space.tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, 0, ref)
	var r := ref[0]
	var marks: MarksScript = _keep(MarksScript.new())
	marks.configure(graph, HazardsScript.new(graph))
	var view: RoomViewScript = _keep(RoomViewScript.new())
	view.configure(graph, PropsScript.new(), space, marks)
	var day := [0.0]
	view.set_today(func() -> float: return day[0])
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		if graph.is_room_body(slot):
			graph.start_dig(slot, graph.generation[slot], 0)
			graph.advance(slot, graph.generation[slot], graph.total_ticks(slot) * 1000000 / Rules.TICKS_PER_SECOND / 4)
		else:
			graph.start_dig(slot, graph.generation[slot], 0)
			graph.advance(slot, graph.generation[slot], 1000000000)
	view.refresh()
	var early := view.stage(r)
	assert_true(early >= 1 and early < RoomViewScript.STAGES, "part dug (stage %d)" % early)
	day[0] = 0.5
	for slot in chain:
		if graph.is_room_body(slot):
			graph.advance(slot, graph.generation[slot], 1000000000)
	view.refresh()
	assert_almost_equal(view.stage_day(r, 1), 0.0, "the first stage was dug on day 0")
	assert_almost_equal(view.stage_day(r, RoomViewScript.STAGES), 0.5, "the last on day 0.5")
	var door := graph.rooms.door_u(r)
	assert_equal(view.stage_at(r, Vector2(Rules.to_m(door.x), Rules.to_m(door.y)), RoomViewScript.STAGES), 1, "by the door: stage 1")
	assert_equal(view.stage_at(r, Vector2(0.0, 1.9), RoomViewScript.STAGES), RoomViewScript.STAGES, "the far wall: the last")


func test_a_hub_keeps_the_day_it_broke_ground() -> void:
	"""A junction's hub rebuilt later keeps the dig day it was first drawn with -- a branch opening into it does not
	wet it again."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref)
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var calendar := CalendarScript.new()
	bores.set_calendar(calendar)
	bores._hub_gen[0] = network.node_gen[0]
	bores._hub_day[0] = 0.25
	calendar.tick = 18000 * 3
	bores._draw_hub(0, true)
	var arrays := (bores.hub(0).mesh as ArrayMesh).surface_get_arrays(0)
	assert_almost_equal((arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[0].x, 0.25, "its first day, not today")


func test_a_widening_re_cuts_the_walls_it_passes() -> void:
	"""The steps a widening has passed carry the day it passed them (fresh-cut again), the rest their dig day."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref)
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(network)
	var calendar := CalendarScript.new()
	bores.set_calendar(calendar)
	bores.build(1, network.length_m(1), 0.0)
	calendar.tick = 18000 * 2
	bores.build(1, network.length_m(1), 3.0)
	assert_almost_equal(bores.dug_day(1, 4), 2.0, "1 m in: widened on day 2")
	assert_almost_equal(bores.dug_day(1, 20), 0.0, "5 m in: still day 0")
