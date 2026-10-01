extends "res://test/framework/test_case.gd"
## Clearing spoil heaps (demo/spoil/, decision 0205): a finished tunnel's heap is dug out a basketful
## at a time and hauled into the farm's compost store, through the farm's own spoil books, every milli-U
## accounted for; the emptied heap stops being an obstacle; a worker called away puts its basket back and keeps the heap to come
## back to. On the placeholder cast, stepped at 60 Hz, out of the tree.

const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CrewScript := preload("res://demo/spoil/spoil_crew.gd")
const SpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const DT: float = 1.0 / 60.0
const USEC: int = 16667

var _cast: DemoCastScript = null
var _delivered: PackedInt64Array = PackedInt64Array([0])


func before_each() -> void:
	"""The placeholder cast, every one able to carry, in the village's bounds."""
	_cast = DemoCastScript.new()
	_cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	_cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	for i: int in _cast.actor_count():
		_brain(i).set_carry_motion(_carry_motion())
	_delivered[0] = 0


func after_each() -> void:
	"""Free the cast."""
	_cast.free()
	_cast = null


func _brain(i: int) -> BrainScript:
	"""Actor i's brain."""
	return (_cast.actor(i) as DemoActorScript).brain


func _carry_motion() -> Dictionary:
	"""A straight carry root motion, 0.2 m/s over 6.5 s."""
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, 1.3 * k / 65.0])
	return {"keys_xz": keys, "mean_speed_m_s": 0.2, "period_s": 6.5}


func _open_tunnel(dig_all: bool) -> PackedInt32Array:
	"""A 12 m mouth-to-mouth tunnel east of the square's middle (x 4 -> 16 m along z 6 m), both mouths'
	heaps placed; every segment of it dug to the end, or only its first started. Returns [entrance heap,
	exit heap, first segment]: a heap is a mouth row (farm_tunnels.gd HEAPS = MAX_MOUTHS). A 12 m piece is
	a 4 m ramp + a 4 m bore + a 4 m ramp; its cuts heap at the mouth it starts at, only the exit shaft at
	the far mouth."""
	var network: GraphScript = _cast.space().tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([4096, 6144, 16384, 6144]), 2, 0, ref), "a tunnel")
	var entry: int = network.mouth_of_end(ref[0], false)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	var exit: int = network.mouth_of_end(chain[chain.size() - 1], true)
	HeapsScript.place(network, _cast.space(), entry)
	HeapsScript.place(network, _cast.space(), exit)
	if not dig_all:
		network.advance(ref[0], ref[1], 3000000)
		return PackedInt32Array([entry, exit, ref[0]])
	for s: int in chain:
		network.start_dig(s, network.generation[s], 0)
		network.advance(s, network.generation[s], 1000000000)
	return PackedInt32Array([entry, exit, ref[0]])


func _crew(tunnels: FarmTunnels) -> CrewScript:
	"""A spoil crew on the cast, delivering into `_delivered`, tipping at the square's middle."""
	var crew := CrewScript.new()
	crew.configure(_cast, _cast.space().tunnels, tunnels, null, func(milli: int) -> void: _delivered[0] += milli,
		Vector2(0.0, 0.0))
	return crew


func _run(crew: CrewScript, seconds: float, each: Callable = Callable()) -> void:
	"""Step every brain and the crew for `seconds` of demo time."""
	for f: int in roundi(seconds / DT):
		for i: int in _cast.actor_count():
			_brain(i).step(DT)
		crew.update(USEC)
		if each.is_valid():
			each.call()


func test_a_heap_is_refused_while_its_tunnel_is_dug_or_when_empty() -> void:
	"""Only a finished tunnel's heaps with spoil on them are cleared; the refusals say why."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	assert_equal(crew.refusal(0), "there is no spoil there", "no tunnel yet")
	var site: PackedInt32Array = _open_tunnel(false)
	assert_true(crew.spoil_left(site[0]) > 0, "spoil heaped so far")
	assert_equal(crew.refusal(site[0]), "its tunnel is still being dug", "a heap still growing")
	assert_equal(crew.order(site[0], PackedInt32Array([1])), "Can't clear the spoil: its tunnel is still being dug",
		"refused in words")
	assert_equal(crew.refusal(-1), "there is no spoil there", "no heap")


func test_a_heap_is_cleared_into_the_compost_store_with_nothing_lost() -> void:
	"""Two residents dig the entrance heap out a basketful (2 U) at a time and tip it at the drop spot; at
	every frame what is left, in baskets and delivered add up to what was heaped; at the end the heap is
	empty, all of it delivered, the heap no longer an obstacle, and both residents back to their routine."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	var heap: int = site[0]
	var heaped: int = crew.spoil_left(heap)
	# 13 cuts heap at the entrance (its shaft, 4 ramp + 4 bore + 4 ramp metres) x 2000; the exit shaft's
	# one cut at the far mouth.
	assert_equal(heaped, 13 * 2000, "the entrance heap")
	assert_equal(crew.spoil_left(site[1]), 2000, "the exit heap")
	assert_true(heaped > CrewScript.LOAD_MILLI, "more than one basket: %d" % heaped)
	var said: String = crew.order(heap, PackedInt32Array([1, 2]))
	assert_true(said.begins_with("Clearing the spoil heap"), said)
	assert_equal(crew.workers_on(heap), 2, "two on it")
	var balanced: Array[bool] = [true]
	_run(crew, 240.0, func() -> void:
		balanced[0] = balanced[0] and crew.spoil_left(heap) + crew.in_hand_milli() + _delivered[0] == heaped)
	assert_true(balanced[0], "the books balanced every frame")
	assert_equal(crew.spoil_left(heap), 0, "empty")
	assert_equal(int(_delivered[0]), heaped, "all of it delivered")
	assert_equal(crew.delivered_milli, heaped, "counted")
	assert_equal(tunnels.taken_milli(_cast.space().tunnels, heap), heaped, "through the farm's books")
	assert_equal(crew.retired_heaps, 1, "retired once")
	assert_equal(crew.workers_on(heap), 0, "nobody left on it")
	assert_false(_has_circle_at(_cast.space().tunnels.heap_at[heap]), "no longer an obstacle")
	assert_true(_has_circle_at(_cast.space().tunnels.heap_at[site[1]]), "the exit heap still is")
	for who: int in [1, 2]:
		assert_equal(_brain(who).order, BrainScript.ORDER_NONE, "resident %d back to its routine" % who)


func _has_circle_at(at: Vector2) -> bool:
	"""Whether the cast's obstacles hold a circle centred at `at`."""
	for circle: Vector3 in _cast.space().obstacles:
		if Vector2(circle.x, circle.z).distance_to(at) < 0.001 and circle.y > 0.0:
			return true
	return false


func test_a_worker_called_away_puts_its_basket_back_and_comes_back() -> void:
	"""Ordered elsewhere with a basket, the worker's load goes back on its heap (nothing lost, and nothing delivered from
	where it stands: decision 0361), its row ends and it keeps the heap; its next work done sends it back to the heap."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	var heap: int = site[0]
	var heaped: int = crew.spoil_left(heap)
	crew.order(heap, PackedInt32Array([1]))
	var row: int = crew.row_of(1)
	_run(crew, 60.0)
	for f: int in 6000:
		# On its way with the basket: the carry walk issued (on the frame the load is dug the walk is
		# not issued yet, and the crew's next update would issue it over the player's order).
		if crew.step[row] == CrewScript.STEP_CARRY and crew.load_milli[row] > 0 and crew.issued[row] == 1:
			break
		_run(crew, DT)
	assert_true(crew.load_milli[row] > 0, "carrying a basket")
	var delivered_before: int = int(_delivered[0])
	_brain(1).order_move(Vector2(-6.0, -6.0))
	crew.update(USEC)
	assert_equal(crew.row_of(1), -1, "the row ended")
	assert_equal(int(_delivered[0]), delivered_before, "nothing delivered from where it stood")
	assert_equal(crew.spoil_left(heap) + int(_delivered[0]), heaped, "the basket went back on the heap")
	assert_equal(_brain(1).unfinished_labels(), PackedStringArray(["Clear spoil heap"]), "kept")
	_brain(1).work_done()
	assert_equal(crew.row_of(1) >= 0, true, "back on the heap")


func test_only_carriers_are_sent_and_at_most_four_a_heap() -> void:
	"""A resident with no carry walk is not sent; a fifth is not sent to one heap."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	_brain(0)._carry_velocity.clear()
	assert_false(_brain(0).can_carry(), "no carry walk")
	assert_equal(crew.order(site[0], PackedInt32Array([0])), "Can't clear the spoil: nobody selected can carry it",
		"refused")
	crew.order(site[0], PackedInt32Array([0, 1, 2, 3, 4, 5]))
	assert_equal(crew.workers_on(site[0]), CrewScript.MAX_PER_HEAP, "four at most")
	assert_equal(crew.row_of(0), -1, "not the one who cannot carry")


func test_a_heap_is_picked_under_the_pointer_and_selected() -> void:
	"""A ground point within a heap's drawn rim (plus a little) picks it; the heap with nothing on it is
	not picked; selecting it says how much spoil it holds."""
	var tunnels := FarmTunnels.new()
	var site: PackedInt32Array = _open_tunnel(true)
	var camera := Camera3D.new()
	var command := CommandScript.new()
	command.configure(_cast, camera)
	var spoil := SpoilScript.new()
	spoil.configure(_cast, command, camera, _cast.space().tunnels, tunnels, null, func(_m: int) -> void: pass)
	var at: Vector2 = _cast.space().tunnels.heap_at[site[0]]
	var rim: float = SpoilScript.drawn_radius_m(spoil.crew.spoil_left(site[0]))
	assert_equal(spoil.heap_at_point(at), site[0], "on it")
	assert_equal(spoil.heap_at_point(at + Vector2(rim + SpoilScript.PICK_SLACK_M - 0.01, 0.0)), site[0], "at the rim")
	assert_equal(spoil.heap_at_point(at + Vector2(rim + SpoilScript.PICK_SLACK_M + 0.05, 0.0)), SpoilScript.NOTHING,
		"beyond it")
	spoil.select(site[0])
	assert_true(command.panel().notice().begins_with("Spoil heap: "), command.panel().notice())
	spoil.select(SpoilScript.NOTHING)
	assert_equal(spoil.selected_heap, SpoilScript.NOTHING, "let go")
	assert_equal(spoil.task_text(1), "", "not clearing: no words")
	spoil.crew.order(site[0], PackedInt32Array([1]))
	assert_equal(spoil.task_text(1), SpoilScript.CLEARING_TEXT, "clearing")
	spoil.crew.step[spoil.crew.row_of(1)] = CrewScript.STEP_CARRY
	assert_equal(spoil.task_text(1), SpoilScript.HAULING_TEXT, "hauling")
	assert_equal(command.doing_text(1), SpoilScript.HAULING_TEXT, "the party panel says so")
	for node: Node in [spoil, command, camera]:
		node.free()


func test_the_last_basket_takes_what_is_left() -> void:
	"""A heap holding less than a basket (1.0 U here) is cleared all the same: the last load is what
	is left."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	var heap: int = site[0]
	var network: GraphScript = _cast.space().tunnels
	var left: int = crew.spoil_left(heap)
	assert_true(tunnels.take_spoil_into(network, heap, left - 1000, IntMath.IntResult.new()), "down to 1.0 U")
	crew.order(heap, PackedInt32Array([1]))
	_run(crew, 120.0)
	assert_equal(crew.spoil_left(heap), 0, "cleared")
	assert_equal(int(_delivered[0]), 1000, "the last 1.0 U delivered")


func test_a_cleared_heap_that_takes_spoil_again_is_an_obstacle_again() -> void:
	"""Review M4: a fall cleared or a chamber dug off a finished tunnel heaps spoil at its entrance again;
	a heap retired as empty then stands as an obstacle again."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	var heap: int = site[0]
	var network: GraphScript = _cast.space().tunnels
	assert_true(tunnels.take_spoil_into(network, heap, crew.spoil_left(heap), IntMath.IntResult.new()), "emptied")
	crew._retire(heap)
	assert_false(_has_circle_at(network.heap_at[heap]), "retired")
	network.add_spoil(site[2], 2000)
	crew.update(USEC)
	assert_true(_has_circle_at(network.heap_at[heap]), "an obstacle again")


func test_moving_a_worker_to_another_heap_takes_up_nothing_else() -> void:
	"""Review M2: ordered from one heap to another, the worker's old row closes quietly -- it does not
	take up an older job as if its work were done."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	var resumed: Array[int] = [0]
	_brain(1).remember_unfinished(UnfinishedScript.new(func(_b: RefCounted) -> bool:
		resumed[0] += 1
		return true, "lanterns"))
	crew.order(site[0], PackedInt32Array([1]))
	crew.order(site[1], PackedInt32Array([1]))
	assert_equal(resumed[0], 0, "nothing else taken up")
	assert_equal(crew.heap[crew.row_of(1)], site[1], "on the other heap")


func test_a_worker_released_by_the_player_keeps_no_heap() -> void:
	"""Review H2: R releases a worker; the crew notices a frame later and must not keep the heap for it."""
	var tunnels := FarmTunnels.new()
	var crew := _crew(tunnels)
	var site: PackedInt32Array = _open_tunnel(true)
	crew.order(site[0], PackedInt32Array([1]))
	_run(crew, 2.0)
	_brain(1).release()
	crew.update(USEC)
	assert_equal(crew.row_of(1), -1, "the row ended")
	assert_equal(_brain(1).unfinished_labels().size(), 0, "nothing kept")
