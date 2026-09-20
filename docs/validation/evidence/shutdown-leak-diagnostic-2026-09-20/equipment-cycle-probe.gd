extends SceneTree
const Inventory = preload("res://scripts/core/inventory.gd")
const Gear = preload("res://scripts/core/gear.gd")
const Residents = preload("res://scripts/core/residents.gd")
func _initialize() -> void:
	var inventory: Inventory = Inventory.new()
	var residents: Residents = Residents.new()
	var gear: Gear = Gear.new()
	var bound: bool = gear.bind_equipment(inventory, residents.directory(), residents).ok
	var wi: WeakRef = weakref(inventory)
	var wg: WeakRef = weakref(gear)
	var wr: WeakRef = weakref(residents)
	inventory = null
	gear = null
	residents = null
	var retained: Array[bool] = [wi.get_ref() != null, wg.get_ref() != null, wr.get_ref() != null]
	var rescued: Inventory = wi.get_ref()
	var unbound: bool = rescued != null and rescued.set_equipment_authority(null).ok
	rescued = null
	var released: Array[bool] = [wi.get_ref() == null, wg.get_ref() == null, wr.get_ref() == null]
	print("CYCLE_PROBE " + JSON.stringify({"bind_ok":bound,"retained_without_external_owners":retained,"explicit_unbind_ok":unbound,"released_after_unbind":released}))
	quit(0 if bound and unbound and retained == [true,true,true] and released == [true,true,true] else 1)
