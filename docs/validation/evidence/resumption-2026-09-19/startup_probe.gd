extends SceneTree
## Read-only audit of the actual main scene after its normal startup path.

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	var economy: Node = root.get_node("EconomySystem")
	var settlement: Node = root.get_node("SettlementSystem")
	var result: Dictionary = {
		"scope": "actual main-scene startup; no fabricated ticks or state injection",
		"inventory_same_instance": economy.inventory() == settlement.inventory(),
		"residents": settlement.residents().living_count(),
		"buildings": settlement.buildings().live_building_count(),
		"rooms": settlement.buildings().live_room_count(),
		"furniture": settlement.buildings().live_furniture_count(),
		"items": {}
	}
	for key: StringName in [&"wood", &"berries", &"tool"]:
		var eid: int = economy.definitions().compiled_id(key)
		var sid: int = settlement.item_definitions().compiled_id(key)
		result["items"][key] = {
			"displayed_inventory_milli": economy.inventory().total_live_milli(eid),
			"simulation_inventory_milli": settlement.inventory().total_live_milli(sid)
		}
	print("REDWALL_STARTUP_AUDIT " + JSON.stringify(result))
	main.queue_free()
	await process_frame
	quit(0)
