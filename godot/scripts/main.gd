extends Node
## Boot scene: wires the HUD to UIManager and seeds the starting settlement.

const HudScript := preload("res://scripts/ui/hud.gd")

const STARTING_STOCKPILES: Dictionary = {
	&"food": 120.0,
	&"wood": 80.0,
	&"stone": 40.0,
	&"herbs": 10.0,
}

@onready var _hud: HudScript = $UI/HUD as HudScript


func _ready() -> void:
	"""Reset autoload state, register the HUD, seed stockpiles, and start play.

	EntityManager and EconomySystem are autoloads and outlive this scene, so a
	reload would otherwise inherit the previous run's entities and stockpiles.
	"""
	EntityManager.clear()
	EconomySystem.reset()
	if _hud == null:
		push_error("main.tscn has no HUD at UI/HUD; the interface will not update.")
	UIManager.register_hud(_hud)
	_seed_stockpiles()
	GameManager.start_game()
	UIManager.push_alert("Mossflower stirs.")
	print("[Main] boot complete: %s" % GameManager.get_state_name())


func _exit_tree() -> void:
	"""Release the HUD reference before this scene is freed."""
	UIManager.unregister_hud()


func _unhandled_input(event: InputEvent) -> void:
	"""Map the cancel action to the pause toggle."""
	if event.is_action_pressed(&"cancel"):
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


func _seed_stockpiles() -> void:
	"""Fill the opening stockpiles the settlement starts the game with."""
	for resource_type: StringName in STARTING_STOCKPILES:
		EconomySystem.add_resource(resource_type, STARTING_STOCKPILES[resource_type])
