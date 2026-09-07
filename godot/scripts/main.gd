extends Node
## Boot scene: wires the HUD to UIManager and seeds the starting settlement stores.

const HudScript := preload("res://scripts/ui/hud.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

## GDD §5.1 initial inventory, in whole catalog units. Copied verbatim from the specification
## line "Initial inventory U: wood 180, stone 100, ..."; nothing here is invented or rounded.
## Placement order does not matter: the pantry and material store take disjoint categories and
## every listed item fits, so the GDD's "food first, then item ID" fill order and this order
## produce the same result.
const STARTING_INVENTORY_U: Dictionary = {
	&"wood": 180,
	&"stone": 100,
	&"iron": 20,
	&"rope": 20,
	&"tool": 24,
	&"cloth": 24,
	&"water": 60,
	&"grain": 80,
	&"roots": 80,
	&"berries": 40,
	&"nuts": 40,
	&"dried_fish": 60,
	&"ration": 60,
	&"seed_grain": 32,
	&"seed_roots": 32,
	&"seed_beans": 16,
	&"seed_cabbage": 16,
	&"seed_flax": 16,
	&"herb": 12,
	&"compost": 32,
}

const MILLI_PER_UNIT: int = 1000

@onready var _hud: HudScript = $UI/HUD as HudScript

## The settlement's population, owned here for as long as this scene lives. EconomySystem only
## BORROWS it as the food-days divisor, so the reference must be held somewhere that outlives
## the binding; a local would make `bind_residents(null)` free the settlement.
var _residents: ResidentsScript = null


func _ready() -> void:
	"""Reset autoload state, register the HUD, seed the stores, and start play.

	EntityManager and EconomySystem are autoloads and outlive this scene, so a
	reload would otherwise inherit the previous run's entities and stores.
	"""
	EntityManager.clear()
	EconomySystem.reset()
	if _hud == null:
		push_error("main.tscn has no HUD at UI/HUD; the interface will not update.")
	UIManager.register_hud(_hud)
	_spawn_initial_cohort()
	_seed_stores()
	GameManager.start_game()
	UIManager.push_alert("Mossflower stirs.")
	print("[Main] boot complete: %s  food-days %s  ready %d NP  fuel-days %s" % [
		GameManager.get_state_name(),
		EconomySystem.food_days_text(),
		EconomySystem.ready_nutrition_points(),
		EconomySystem.fuel_days_text(),
	])


func _spawn_initial_cohort() -> void:
	"""Create the GDD §5.1 starting settlement and bind it as the food-days divisor.

	Without a living cohort the food-days denominator is undefined, so
	EconomySystem refuses the figure rather than displaying an unbounded reserve.

	A refused spawn unbinds explicitly. Leaving an earlier run's cohort bound after a scene
	reload would divide this run's stores by the previous run's population, which is a wrong
	number on screen rather than an absent one.
	"""
	var residents: ResidentsScript = ResidentsScript.new()
	var spawned: ResidentsScript.OpResult = residents.spawn_initial_settlement()
	if not spawned.ok:
		_residents = null
		EconomySystem.bind_residents(null)
		push_error("Initial settlement could not be created: %s" % spawned.error)
		return
	_residents = residents
	EconomySystem.bind_residents(_residents)


func _exit_tree() -> void:
	"""Release the HUD reference and the borrowed residents binding before this scene is freed."""
	UIManager.unregister_hud()
	EconomySystem.bind_residents(null)
	_residents = null


func _unhandled_input(event: InputEvent) -> void:
	"""Map the cancel action to the pause toggle."""
	if event.is_action_pressed(&"cancel"):
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


func _seed_stores() -> void:
	"""Deposit the GDD §5.1 starting inventory, reporting any item the stores refuse."""
	for item_key: StringName in STARTING_INVENTORY_U:
		var quantity_milli: int = int(STARTING_INVENTORY_U[item_key]) * MILLI_PER_UNIT
		if not EconomySystem.deposit(item_key, quantity_milli):
			push_error("Starting inventory refused for '%s': %s" % [item_key, EconomySystem.last_refusal()])
