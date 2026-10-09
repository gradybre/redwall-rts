extends SceneTree

func _initialize() -> void:
	var base: Script = load("res://test/test_underground_entry_world_bindings.gd")
	if base == null or not base.can_instantiate():
		quit(1)
		return
	var script: Script = load("/Users/brendan/Developer/redwall-rts-codex-ug-connector-work/docs/validation/evidence/underground-first-prefix-2026-10-03/phase-world-28/diagnose_location_budget.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var fixture: RefCounted = script.new()
	print("LOCATION-BUDGET-PROBE ", JSON.stringify(fixture.run_probe()))
	fixture = null
	quit(0)
