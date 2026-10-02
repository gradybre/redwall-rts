extends "res://test/framework/test_case.gd"
## The kitchen's rounds to come back to hold the kitchen weakly (kitchen.gd RoundBack; decision 0922). The soak test
## found the cycle brain -> unfinished job -> kitchen -> brain alive after Restart demo, with the whole cast behind it,
## once a cook or a drawer had been called away mid-round. That the round still comes back is
## test_demo_kitchen.gd `test_the_cook_called_away_mid_batch_comes_back_to_it`.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")


## A kitchen stand-in that answers its take-backs and counts them.
class StubKitchen extends RefCounted:
	var asked: int = 0

	func _take_back_cook(_brain: RefCounted) -> bool:
		"""Yes, and counted."""
		asked += 1
		return true


func test_a_brain_keeping_the_cooks_round_does_not_keep_its_kitchen() -> void:
	"""A kitchen that holds a brain which keeps the cook's round: once both are let go, both are freed (no cycle)."""
	var refs: Array[WeakRef] = _kitchen_and_brain_with_a_round()
	assert_null(refs[0].get_ref(), "the kitchen is freed")
	assert_null(refs[1].get_ref(), "and the brain with it")


func _kitchen_and_brain_with_a_round() -> Array[WeakRef]:
	"""A kitchen holding one brain that keeps the cook's round; only weak references come back."""
	var kitchen := KitchenScript.new()
	var brain := BrainScript.new()
	var brains: Array[BrainScript] = [brain]
	kitchen._brains = brains
	brain.remember_unfinished(kitchen.unfinished_of(0, KitchenScript.ROLE_COOK))
	assert_true(brain.unfinished_labels().has(Words.ROUND_LABEL), "the brain keeps the round")
	return [weakref(kitchen), weakref(brain)]


func test_the_round_is_stale_once_the_kitchen_is_gone() -> void:
	"""A round outliving its kitchen: the kitchen IS freed (the round does not keep it), and the round gives nothing
	back (and does not fail)."""
	var kitchen := KitchenScript.new()
	var gone: WeakRef = weakref(kitchen)
	var job: RefCounted = kitchen.unfinished_of(0, KitchenScript.ROLE_COOK)
	kitchen = null
	assert_null(gone.get_ref(), "the round does not keep its kitchen")
	assert_false(bool(job.call(&"resume", BrainScript.new())), "stale: false")


func test_a_drawers_trip_calls_the_draw_take_back() -> void:
	"""A drawer with water in hand keeps a trip whose take-back is the kitchen's own `_take_back_draw`; one with none
	keeps nothing."""
	var kitchen := KitchenScript.new()
	kitchen._water = PackedInt64Array([1000])
	kitchen._draw_amount = PackedInt64Array([0])
	var job: RefCounted = kitchen.unfinished_of(0, KitchenScript.ROLE_DRAW)
	assert_not_null(job, "a trip kept")
	var back: Object = (job.get("_take_back") as Callable).get_object()
	assert_equal(back.call(&"method_name"), &"_take_back_draw", "the draw take-back")
	kitchen._water = PackedInt64Array([0])
	assert_null(kitchen.unfinished_of(0, KitchenScript.ROLE_DRAW), "nothing in hand, nothing owed: no trip")


func test_the_round_asks_its_kitchen_while_it_lives() -> void:
	"""While the kitchen lives, the round's take-back is the kitchen's own answer."""
	var stub := StubKitchen.new()
	var back := KitchenScript.RoundBack.new(stub._take_back_cook)
	assert_true(back.take_back(BrainScript.new()), "the kitchen's answer")
	assert_equal([stub.asked, back.method_name()], [1, &"_take_back_cook"], "asked once, by its method")
	stub = null
	assert_false(back.take_back(BrainScript.new()), "gone: false")
