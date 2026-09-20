extends SceneTree
const Injury := preload("res://scripts/core/injury.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Case := preload("res://test/framework/test_case.gd")
const MAX_I64: int = 9223372036854775807
const MIN_I64: int = -9223372036854775807 - 1
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var f: Case = Case.new()
	var injury: Injury = Injury.new()
	var needs: Needs = Needs.new()
	for row: int in [0,511]:
		f.assert_true(needs.spawn(row,Needs.SIZE_SMALL).ok,"public needs spawn")
		f.assert_true(injury.spawn(row).ok,"public injury spawn")
		f.assert_true(injury.apply_incident(row,1,1,0,1,needs).ok,"public injury incident")
	# Deliberate test-only boundary injection, NOT reachable public history or a save restore.
	# No production getter/setter is added. Public readers/diagnostic observe the actual tick.
	var seeded: PackedInt64Array = PackedInt64Array()
	seeded.resize(512)
	seeded[0] = 7
	seeded[511] = MAX_I64
	injury.set("_untreated_ticks",seeded)
	f.assert_equal(injury.untreated_ticks_of(511).value,MAX_I64,"injected boundary verified publicly")
	var before: PackedByteArray = injury.state_bytes()
	var outcome: Needs.OpResult = injury.tick_all(needs)
	f.assert_true(outcome.ok,"CURRENT BUG: whole sweep claims success")
	f.assert_equal(injury.untreated_ticks_of(0).value,8,"CURRENT BUG: earlier row advanced")
	f.assert_equal(injury.untreated_ticks_of(511).value,MIN_I64,"CURRENT BUG: int64 overflow wrapped")
	f.assert_false(injury.state_bytes() == before,"CURRENT BUG: public diagnostic changed")
	f.assert_equal(injury.last_refused_slot(),-1,"CURRENT BUG: no overflow diagnostic")
	for failure: String in f.failures: printerr(failure)
	print("INJURY_INJECTED_BOUNDARY_CHARACTERIZATION assertions=%d failures=%d" % [f.assertions,f.failures.size()])
	quit(0 if f.failures.is_empty() else 1)
