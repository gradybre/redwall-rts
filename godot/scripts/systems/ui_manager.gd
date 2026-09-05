extends Node
## Routes system signals into the active HUD. Owns no game state of its own.
##
## This is the one place signals drive behaviour: every connection made here
## ends at a HUD label. Game logic calls systems directly instead.

const HudScript := preload("res://scripts/ui/hud.gd")

var _hud: HudScript = null


func _ready() -> void:
	"""Stay alive through pauses, connect system signals, and report readiness."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	EconomySystem.resource_changed.connect(_on_resource_changed)
	EconomySystem.resource_depleted.connect(_on_resource_depleted)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	print("[UIManager] ready")


func register_hud(hud: HudScript) -> void:
	"""Bind the active HUD and push the current game state into it."""
	if hud == null:
		push_error("UIManager.register_hud() was given null; the HUD will not update.")
		return
	_hud = hud
	_refresh_hud()


func unregister_hud() -> void:
	"""Drop the HUD reference when its scene is leaving the tree."""
	_hud = null


func push_alert(text: String) -> void:
	"""Show a transient message in the top-centre alert zone."""
	if _has_hud():
		_hud.show_alert(text)


func _has_hud() -> bool:
	"""True when a HUD is bound and has not been freed out from under us.

	A plain null check is not enough: a freed Object still compares != null.
	"""
	return _hud != null and is_instance_valid(_hud)


func _refresh_hud() -> void:
	"""Push every current value into a freshly registered HUD."""
	if not _has_hud():
		return
	var amounts: Dictionary = EconomySystem.get_all_amounts()
	for resource_type: StringName in amounts:
		_hud.set_resource(resource_type, amounts[resource_type])
	_hud.set_status(GameManager.get_state_name(), GameManager.get_speed())


func _on_resource_changed(resource_type: StringName, amount: float) -> void:
	"""Update one resource counter in the top-left zone."""
	if _has_hud():
		_hud.set_resource(resource_type, amount)


func _on_resource_depleted(resource_type: StringName) -> void:
	"""Raise an alert when a stockpile runs dry."""
	push_alert("Out of %s!" % resource_type)


func _on_state_changed(_new_state: int) -> void:
	"""Refresh the status readout after a state transition."""
	if _has_hud():
		_hud.set_status(GameManager.get_state_name(), GameManager.get_speed())


func _on_speed_changed(multiplier: float) -> void:
	"""Refresh the status readout after a speed change."""
	if _has_hud():
		_hud.set_status(GameManager.get_state_name(), multiplier)
