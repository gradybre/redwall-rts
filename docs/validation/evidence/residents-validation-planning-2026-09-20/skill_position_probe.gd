extends SceneTree
const Residents := preload("res://scripts/core/residents.gd")
const Case := preload("res://test/framework/test_case.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var f: Case = Case.new()
	var store: Residents = Residents.new()
	var c: Residents.Columns = Residents.Columns.new()
	f.assert_true(store.copy_columns_into(c),"real capture")
	for index: int in 6144:
		c.skill_xp[index] = -1
		f.assert_false(store.restore_columns(c),"each XP address refuses")
		f.assert_equal(store.last_column_refusal(),&"COLUMN_SKILL_XP","XP exactcode")
		c.skill_xp[index] = 0
		c.skill_level[index] = 1
		f.assert_false(store.restore_columns(c),"each level address refuses")
		f.assert_equal(store.last_column_refusal(),&"COLUMN_SKILL_LEVEL","level exactcode")
		c.skill_level[index] = 0
	f.assert_true(store.restore_columns(c),"restored cleared image succeeds")
	for failure: String in f.failures: printerr(failure)
	print("RESIDENTS_SKILL_POSITION_PROBE assertions=%d failures=%d" % [f.assertions,f.failures.size()])
	quit(0 if f.failures.is_empty() else 1)
