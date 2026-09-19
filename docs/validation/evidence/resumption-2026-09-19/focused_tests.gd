extends SceneTree
## Bounded diagnostic runner. The repository supervisor remains the acceptance runner.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: int = 0
	var tests: int = 0
	for path: String in ["res://test/test_ui_context_gates.gd", "res://test/test_stock_authority_lifetime.gd", "res://test/test_inventory.gd"]:
		var script = load(path)
		if not script.can_instantiate():
			quit(2)
			return
		var suite = script.new()
		for method: Dictionary in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			tests += 1
			suite.failures.clear()
			var before: int = suite.assertions
			suite.before_each()
			suite.call(name)
			suite.after_each()
			if suite.assertions == before or not suite.failures.is_empty():
				failures += 1
				print("FOCUSED_FAIL " + path + " " + name + " " + str(suite.failures))
	print("FOCUSED_TESTS " + JSON.stringify({"tests":tests,"failures":failures}))
	quit(1 if failures else 0)
