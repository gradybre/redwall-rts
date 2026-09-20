extends SceneTree
const Inv := preload("res://scripts/core/inventory.gd")
const Defs := preload("res://scripts/core/item_definitions.gd")
const Age := preload("res://scripts/core/stock_age.gd")
func _initialize() -> void:
	var original: Dictionary = _run(false)
	var sorted: Dictionary = _run(true)
	print(JSON.stringify({"original":original,"sorted":sorted}))
	assert(original.order == [2,1])
	assert(sorted.order == [1,2])
	assert(original.next_slots != sorted.next_slots)
	assert(not Age.is_hour_boundary(0))
	quit()
func _run(sort_rows: bool) -> Dictionary:
	var inv: Inv = Inv.new(8,16)
	var defs: Defs = Defs.new()
	assert(defs.load_default(inv).ok)
	var age: Age = Age.new(inv,defs)
	var refs: Array[Vector2i] = []
	for i: int in 3:
		var made = inv.create_container(Vector2i(9,1),100000000,Inv.FILTERS_ACCEPT_ALL,0,true)
		assert(made.ok)
		refs.append(made.ref)
		assert(age.declare_storage_class(made.ref,Age.STORAGE_OPEN_PILE,false))
	assert(age.withdraw_storage_class(refs[0]))
	var rows: PackedInt32Array = age.get("_declared_slots")
	if sort_rows:
		rows[0] = 1
		rows[1] = 2
		age.set("_declared_slots",rows)
	var order: Array = [rows[0],rows[1]]
	for i: int in [1,2]:
		assert(inv.create_lot(refs[i],defs.compiled_id(&"spoiled_food"),1000,0,0,0,240000,0).ok)
	var hour = age.run_hour(750)
	assert(hour.ok)
	var next_slots: Array = []
	for i: int in [1,2]:
		var made = inv.create_lot(refs[i],defs.compiled_id(&"wood"),1000,0,0,0,0,0)
		assert(made.ok)
		next_slots.append(made.ref.x)
	return {"order":order,"next_slots":next_slots,"declared_count":age.declared_container_count()}
