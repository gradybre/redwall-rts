extends "res://test/framework/test_case.gd"
## Objects the demo drops must be freed, not kept alive by a reference cycle (decision 0501).
##
## A reference cycle between RefCounted objects is never collected: GDScript has no cycle collector. The suite's
## shutdown report counted 13,034 leaked ObjectDB instances. Two causes were in production code, and a Restart
## (demo_village.gd `restart`, a scene reload) kept the old village alive through each: the tunnel router held the
## network that owns it after every plan (and the router's MAX_NODES * MAX_NODES columns with it), and a resident's
## unfinished job held its owner (the kitchen, the tunnel works), which holds the residents. Each test builds the
## objects, drops every strong reference it made, and asserts through a WeakRef that the object is gone.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")


func _planned_space() -> CastSpaceScript:
	"""Open ground with one post, a surface route planned across it through the network's router."""
	var space := CastSpaceScript.new()
	space.setup([], [Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.tunnels.plan(space.nav, Vector2(-4.0, 0.0), Vector2(4.0, 0.0), 0.25, PackedVector3Array(), 0, out, legs)
	assert_true(out.size() > 0, "the plan found a way round the post")
	return space


func _weak_network() -> WeakRef:
	"""A weak reference to the network of a space that has planned and been dropped."""
	var space := _planned_space()
	return weakref(space.tunnels)


func test_a_network_that_planned_is_freed_with_its_space() -> void:
	"""The router lets go of the network (and the surface planner) once a plan is done: no cycle survives the space."""
	var network: WeakRef = _weak_network()
	assert_null(network.get_ref(), "the network is freed when nothing holds it")


func _weak_network_after_a_failed_plan() -> WeakRef:
	"""A weak reference to the network of a space whose plan to an unreachable node underground found nothing."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var found: bool = space.tunnels.plan(space.nav, Vector2(-4.0, 0.0), Vector2(4.0, 0.0), 0.25, PackedVector3Array(),
		0, out, legs, -1, false, null, true, 0)
	assert_false(found, "no network: the node underground is out of reach")
	assert_null(space.tunnels.router._graph, "the fallback lets go of the network too")
	return weakref(space.tunnels)


func test_a_network_whose_plan_fell_back_is_freed_with_its_space() -> void:
	"""The router's fallback (no route) releases what it held, as a found route does."""
	var network: WeakRef = _weak_network_after_a_failed_plan()
	assert_null(network.get_ref(), "the network is freed when nothing holds it")


func test_the_router_holds_no_network_between_plans() -> void:
	"""Between plans the router keeps neither the network it costed tunnels through nor the planner it asked."""
	var space := _planned_space()
	assert_null(space.tunnels.router._graph, "no network held after the plan")
	assert_null(space.tunnels.router._nav, "no surface planner held after the plan")


class JobOwner extends RefCounted:
	## A long-lived job owner as the kitchen and the tunnel works are: it holds the residents' brains.
	var brains: Array[RefCounted] = []

	func take_back(_brain: RefCounted) -> bool:
		"""Never gives the job back (only its lifetime is under test)."""
		return false


func _weak_owner_of_a_freed_actor() -> WeakRef:
	"""An actor whose brain keeps an unfinished job of an owner that holds that brain, then the actor freed."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var actor := DemoActorScript.new()
	actor.setup_placeholder(0, space, 7)
	var owner := JobOwner.new()
	owner.brains.append(actor.brain)
	actor.brain.remember_unfinished(UnfinishedScript.new(owner.take_back, "Cook, the kitchen"))
	assert_equal(actor.brain.unfinished_labels(), PackedStringArray(["Cook, the kitchen"]), "the job is kept")
	actor.free()
	return weakref(owner)


func test_a_freed_actor_lets_go_of_the_owners_of_its_unfinished_jobs() -> void:
	"""An unfinished job holds its owner and the owner holds the brain: freeing the actor breaks that cycle, so neither
	outlives the cast (a Restart reloads the scene; before, the old village's kitchen stayed alive)."""
	var owner: WeakRef = _weak_owner_of_a_freed_actor()
	assert_null(owner.get_ref(), "the job's owner is freed with the cast")


class OwnedTask extends TaskScript:
	## A task held by a brain whose owner holds the brain, as a kitchen's or a crew's task can be.
	var owner_ref: RefCounted = null


func _weak_owner_of_a_freed_actors_task() -> WeakRef:
	"""An actor whose brain is on a task that holds an owner that holds the brain, then the actor freed."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var actor := DemoActorScript.new()
	actor.setup_placeholder(0, space, 7)
	var owner := JobOwner.new()
	owner.brains.append(actor.brain)
	var task := OwnedTask.new()
	task.owner_ref = owner
	actor.brain.task = task
	assert_true(actor.brain.task == task, "the brain is on the task")
	actor.free()
	return weakref(owner)


func test_a_freed_actor_lets_go_of_the_owner_of_its_task() -> void:
	"""The brain's task holds its owner and the owner holds the brain: freeing the actor drops the task."""
	var owner: WeakRef = _weak_owner_of_a_freed_actors_task()
	assert_null(owner.get_ref(), "the task's owner is freed with the cast")
