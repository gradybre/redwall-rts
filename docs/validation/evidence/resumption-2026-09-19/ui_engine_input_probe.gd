extends SceneTree
## Real Godot viewport routing, with an unhandled-world canary and live command-count observation.
## This is headless synthetic engine input; it is not native pointer or visual acceptance.

class WorldCanary extends Node:
	var presses: int = 0
	var bridge: Object
	var target: Vector2i
	var refused: int = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			presses += 1
			if not bridge.name_resident(target, "Input probe"):
				refused += 1

var rows: Array = []
var failed: int = 0
var shell: Control
var canary: WorldCanary

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	root.size = Vector2i(1280, 720)
	var settlement: Node = root.get_node("SettlementSystem")
	if not settlement.create_initial_settlement():
		quit(2)
		return
	canary = WorldCanary.new()
	canary.bridge = load("res://scripts/ui/ui_command_bridge.gd").new(settlement.commands())
	canary.target = settlement.directory().ref_of_slot(0)
	root.add_child(canary)
	var script = load("res://scripts/ui/ui_shell.gd")
	if not script.can_instantiate():
		quit(2)
		return
	shell = script.new()
	root.add_child(shell)
	shell.size = Vector2(1280, 720)
	await process_frame
	shell.layout_for(1280, 720)
	await process_frame
	await _click_case("open_world", Vector2(640, 350), true)
	shell.set_detail_open(true)
	await process_frame
	var detail_point: Vector2 = shell.control_for(36).get_global_rect().get_center()
	await _click_case("detail_open", detail_point, false)
	shell.set_detail_open(false)
	await process_frame
	await _click_case("detail_closed", detail_point, true)
	shell.open_workspace_page(69)
	await process_frame
	var workspace_point: Vector2 = shell.control_for(51).get_global_rect().get_center()
	await _click_case("workspace_open", workspace_point, false)
	var back_point: Vector2 = shell.control_for(92).get_global_rect().get_center()
	await _click_case("back_button", back_point, false)
	await process_frame
	await _click_case("workspace_closed", workspace_point, true)
	print("REDWALL_UI_ENGINE_INPUT " + JSON.stringify({"failures": failed, "cases": rows,
		"scope": "headless viewport routing with instrumented world handler submitting NAME_RESIDENT through real UiCommandBridge and Settlement commands; seeded resident fixture, no simulation ticks; not production world router, native pointer or visual acceptance"}))
	shell.queue_free()
	canary.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _click_case(label: String, point: Vector2, expect_world: bool) -> void:
	var before: int = canary.presses
	var settlement: Node = root.get_node("SettlementSystem")
	var pending_before: int = settlement.commands().pending_count()
	var table_world: bool = shell.hit_test().world_receives(point / shell.scale)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.position = point
	up.global_position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	var observed_world: bool = canary.presses > before
	var pending_after: int = settlement.commands().pending_count()
	var expected_delta: int = 1 if expect_world else 0
	var passed: bool = observed_world == expect_world and table_world == expect_world \
		and pending_after - pending_before == expected_delta and canary.refused == 0
	if not passed:
		failed += 1
	rows.append({"case": label, "point": [point.x, point.y], "expected_world": expect_world,
		"engine_unhandled_world": observed_world, "hit_table_world": table_world,
		"pending_commands_before": pending_before, "pending_commands_after": pending_after, "passed": passed})
