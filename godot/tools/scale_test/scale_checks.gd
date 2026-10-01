extends RefCounted
## THE SCALE TEST'S INVARIANTS (decision 0561), checked at the end of a run: every resident accounted for, and the
## kitchen's food books balanced. `run` returns one line per failure (none: all hold).
##
## EVERY RESIDENT ACCOUNTED FOR: the cast has the residents asked for (all of them, unless the staged cast is smaller
## and the run asked for fewer); each is a live actor in the tree with a brain at a finite place inside the cast's
## walkable bounds (or in the water's band, or underground); names are unique; the work board, the kitchen and the
## people's ledger each hold a row for every one.
##
## FOOD CONSERVED (the kitchen's own books, as test_demo_kitchen.gd `_assert_books` states them): every portion cooked
## is held, eaten or spoiled -- `portions + eaten + spoiled == 2 x batches` -- and the batches took exactly their
## recipes' inputs (`consumed_food_milli == by recipe + cancelled + cooking`); and no pantry item is below zero.

const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const KitchenRules := preload("res://demo/kitchen/meal_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

## Residents may stand this far outside the walkable bounds (a swimmer's band, a formation's edge).
const BOUNDS_SLACK_M: float = 30.0


func run(village: Node, residents: int) -> PackedStringArray:
	"""Every invariant's failures (empty: all hold)."""
	var out := PackedStringArray()
	_residents(village, residents, out)
	_kitchen_books(village, out)
	return out


func _residents(village: Node, residents: int, out: PackedStringArray) -> void:
	"""Every resident accounted for (see the top)."""
	var cast: Node = village.get("_cast")
	var count: int = int(cast.call(&"actor_count"))
	if count != residents:
		out.append("the cast has %d residents, %d were asked for" % [count, residents])
	var bounds: Rect2 = (cast.call(&"bounds") as Rect2).grow(BOUNDS_SLACK_M)
	var names: Dictionary = {}
	for who: int in count:
		var actor := cast.call(&"actor", who) as DemoActorScript
		if actor == null or not actor.is_inside_tree() or actor.brain == null:
			out.append("resident %d is missing (no actor, not in the tree, or no brain)" % who)
			continue
		var at: Vector2 = actor.brain.position
		if not at.is_finite() or not bounds.has_point(at):
			out.append("resident %d (%s) is at %s, outside the village" % [who, actor.display_name, at])
		if names.has(actor.display_name):
			out.append("resident %d's name %s is also resident %d's" % [who, actor.display_name, names[actor.display_name]])
		names[actor.display_name] = who
	_rows(village, count, out)


func _rows(village: Node, count: int, out: PackedStringArray) -> void:
	"""The board, the kitchen and the people each hold a row for every resident."""
	var board: Object = (village.call(&"work") as Object).get("board")
	var board_rows: int = int(board.call(&"resident_count"))
	if board_rows != count:
		out.append("the work board has %d residents, the cast %d" % [board_rows, count])
	var people: Object = village.call(&"people")
	var ledger_rows: int = int((people.get("ledger") as Object).call(&"resident_count"))
	if ledger_rows != count:
		out.append("the people's ledger has %d residents, the cast %d" % [ledger_rows, count])


func _kitchen_books(village: Node, out: PackedStringArray) -> void:
	"""Food conserved (see the top), in the village's kitchen."""
	_books_of((village.call(&"kitchen") as Object).get("kitchen"), out)


func _books_of(kitchen: Object, out: PackedStringArray) -> void:
	"""Food conserved (see the top), in `kitchen` (kitchen.gd, or anything with its members)."""
	var store: Object = kitchen.get("store")
	var batches: int = int(kitchen.get("batches_cooked"))
	var held: int = int(store.call(&"portions"))
	var eaten: int = int(kitchen.get("portions_eaten"))
	var spoiled: int = int(store.get("spoiled_portions"))
	if held + eaten + spoiled != 2 * batches:
		out.append("portions: %d held + %d eaten + %d spoiled != 2 x %d batches" % [held, eaten, spoiled, batches])
	var by_recipe: int = 0
	for dish: int in kitchen.get("cooked_dishes") as PackedInt32Array:
		by_recipe += KitchenRules.INPUT_MILLI[dish]
	var wip: int = int(kitchen.call(&"wip_dish"))
	var cooking: int = KitchenRules.INPUT_MILLI[wip] if wip != KitchenRules.NO_DISH else 0
	var cancelled: int = 2 * int(kitchen.get("cancelled_spoil_milli"))
	var consumed: int = int(kitchen.get("consumed_food_milli"))
	if consumed != by_recipe + cancelled + cooking:
		out.append("the kitchen took %d milli, its batches %d + cancelled %d + cooking %d" % [consumed, by_recipe,
			cancelled, cooking])
	var pantry: Object = kitchen.get("pantry")
	for item: int in Catalog.ITEM_COUNT:
		if int(pantry.call(&"milli_of", item)) < 0:
			out.append("pantry item %d is below zero" % item)
