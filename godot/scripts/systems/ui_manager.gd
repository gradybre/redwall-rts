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
	EconomySystem.stocks_changed.connect(_on_stocks_changed)
	EconomySystem.stock_depleted.connect(_on_stock_depleted)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.clock_diagnostic.connect(_on_clock_diagnostic)
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
	_refresh_counters()
	_refresh_status()


func _refresh_counters() -> void:
	"""Push every top-left counter this milestone can honestly derive.

	Five of the seven are supplied. `Food-days` is now among them: task 2.10 gave GDD §5.8 its
	divisor, so EconomySystem computes the figure whenever a residents store is bound and
	returns the unpopulated marker when one is not. Every value crosses this boundary EXACTLY as
	the system produced it -- the two text counters are forwarded verbatim and the three integer
	counters are forwarded unscaled, because a number invented or adjusted here would be
	indistinguishable on screen from one the simulation actually derived.

	`Fuel-days` stays unpopulated: its daily heating demand has no input in any implemented
	system (see EconomySystem.fuel_days_missing_input()). `Residents` and `Beds` stay
	unpopulated too -- residents.gd could supply a population, but `Beds` needs a Building/Room/
	Furniture store that does not exist, and the two are a §1.1 pair whose value is the
	comparison. Neither is approximated here.
	"""
	if not _has_hud():
		return
	_hud.set_counter_text(&"Food-days", EconomySystem.food_days_text())
	_hud.set_counter_text(&"Fuel-days", EconomySystem.fuel_days_text())
	_hud.set_counter(&"Ready NP", EconomySystem.ready_nutrition_points(), "NP")
	_hud.set_counter(&"Wood", EconomySystem.stock_units(&"wood"), "U")
	_hud.set_counter(&"Stone", EconomySystem.stock_units(&"stone"), "U")


func _refresh_status() -> void:
	"""Repaint the top-right state, speed and date readout from current clock state."""
	if not _has_hud():
		return
	_hud.set_status(GameManager.get_state_name(), GameManager.get_speed(), GameManager.get_calendar_text())


func _on_stocks_changed() -> void:
	"""Repaint the top-left counters after a committed change to the stores."""
	_refresh_counters()


func _on_stock_depleted(item_key: StringName) -> void:
	"""Raise an alert when the last unit of an item leaves the stores."""
	push_alert("Out of %s!" % item_key)


func _on_state_changed(_new_state: int) -> void:
	"""Refresh the status readout after a state transition."""
	_refresh_status()


func _on_speed_changed(_speed: int) -> void:
	"""Refresh the status readout after a speed change, including an overload step-down."""
	_refresh_status()


func _on_day_advanced(_absolute_day: int) -> void:
	"""Refresh the date readout when the offset calendar crosses into a new day."""
	_refresh_status()


func _on_clock_diagnostic(message: String) -> void:
	"""Surface a scheduler overload warning or diagnostic pause in the alert zone."""
	push_alert(message)
