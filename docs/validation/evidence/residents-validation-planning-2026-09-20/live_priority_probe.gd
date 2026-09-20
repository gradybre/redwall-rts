extends SceneTree
const Residents := preload("res://scripts/core/residents.gd")
const Case := preload("res://test/framework/test_case.gd")
const FIELDS: Array[String] = ["present","species","size_class","named","life_stage","arrival_tick","role","home_slot","home_generation","bed_slot","bed_generation","ref_slot","ref_generation","equip_tool_item_id","equip_tool_durability","equip_satchel_slot","equip_satchel_generation","skill_xp","skill_level"]
func _copy(c: Residents.Columns) -> Residents.Columns:
	var out: Residents.Columns = Residents.Columns.new()
	for key: String in FIELDS: out.set(key,c.get(key).duplicate())
	return out

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var f: Case = Case.new()
	var store: Residents = Residents.new()
	f.assert_true(store.spawn(&"mouse").ok,"first real resident")
	f.assert_true(store.spawn(&"mouse").ok,"second real resident")
	var base: Residents.Columns = Residents.Columns.new()
	f.assert_true(store.copy_columns_into(base),"real columns")
	var before: PackedByteArray = store.state_bytes()
	var c: Residents.Columns = _copy(base)
	c.size_class[0] = 1
	c.arrival_tick[1] = -1
	f.assert_false(store.restore_columns(c),"first row catalog size wins")
	f.assert_equal(store.last_column_refusal(),&"COLUMN_SIZE_CLASS_MISMATCH","legacy size priority")
	c = _copy(base)
	c.ref_slot[0] = 2147483647
	c.ref_generation[0] = 1
	c.species[1] = -1
	f.assert_false(store.restore_columns(c),"first row Directory wins")
	f.assert_equal(store.last_column_refusal(),&"COLUMN_DIRECTORY_REF","legacy directory priority")
	c = _copy(base)
	c.species[0] = -1
	c.size_class[0] = 1
	c.arrival_tick[0] = -1
	c.ref_slot[0] = 2147483647
	f.assert_false(store.restore_columns(c),"same row species first")
	f.assert_equal(store.last_column_refusal(),&"COLUMN_SPECIES","species priority")
	c.species[0] = base.species[0]
	f.assert_false(store.restore_columns(c),"same row size before arrival")
	f.assert_equal(store.last_column_refusal(),&"COLUMN_SIZE_CLASS_MISMATCH","size priority")
	c.size_class[0] = base.size_class[0]
	f.assert_false(store.restore_columns(c),"same row arrival before Directory")
	f.assert_equal(store.last_column_refusal(),&"COLUMN_ARRIVAL_TICK","arrival priority")
	f.assert_equal(store.state_bytes(),before,"all refused live attempts preserve state")

	for failure: String in f.failures: printerr(failure)
	print("RESIDENTS_LIVE_PRIORITY_PROBE assertions=%d failures=%d" % [f.assertions,f.failures.size()])
	quit(0 if f.failures.is_empty() else 1)
