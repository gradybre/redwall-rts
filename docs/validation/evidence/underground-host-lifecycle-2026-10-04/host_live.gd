extends "res://test/live/demo_layout_live.gd"
## Actual demo boot/restart probe. Inherits real scene setup and 1280x720 viewport handling.

const ActualSession := preload("res://scripts/core/underground_session.gd")


func _run() -> void:
	"""Observe two real demo boots and the intervening retirement, without editing production stores."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	var host: Node = root.get_node(^"SettlementSystem")
	var old: ActualSession = host.call(&"underground_session") as ActualSession
	var original: Vector2i = host.call(&"world_ref")
	_check_foundation(host, "first")
	_village.queue_free()
	await _frames(4)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	_check_foundation(host, "restart")
	_check("fresh full World", host.call(&"world_ref") != original)
	_check("distinct foundation", host.call(&"underground_session") != old)
	_check("prior foundation retired", old != null and old.current_refusal() == &"UNDERGROUND_SESSION_UNAVAILABLE")
	_village.queue_free()
	await _frames(4)
	_check("final host reset", bool(host.call(&"reset")))
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check_foundation(host: Node, label: String) -> void:
	"""Read the actual live foundation and borrowed owners after the complete demo has entered the tree."""
	var session: ActualSession = host.call(&"underground_session") as ActualSession
	_check(label + " mounted", session != null)
	if session == null:
		return
	_check(label + " current", session.current_refusal() == &"", str(session.current_refusal()))
	_check(label + " actual World", session._world == host.call(&"world") and session._world_ref == host.call(&"world_ref"))
	_check(label + " actual equipment", session._gear == host.call(&"gear") and session._carry == host.call(&"haul_carry"))
	_check(label + " foundation quiescent", session.reset_refusal() == &"")
