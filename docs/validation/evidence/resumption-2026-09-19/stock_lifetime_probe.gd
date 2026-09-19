extends SceneTree
## Isolated ownership probe; does not mutate the active settlement autoload.
const Inventory = preload("res://scripts/core/inventory.gd")
const StockAge = preload("res://scripts/core/stock_age.gd")
const Items = preload("res://scripts/core/item_definitions.gd")

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var inventory = Inventory.new()
	var definitions = Items.new()
	definitions.load_default(inventory)
	var age = StockAge.new(inventory, definitions)
	var inventory_ref: WeakRef = weakref(inventory)
	var age_ref: WeakRef = weakref(age)
	var bound: bool = inventory.set_seed_expiry_authority(age).ok
	inventory = null
	age = null
	definitions = null
	var retained_inventory: bool = inventory_ref.get_ref() != null
	var retained_age: bool = age_ref.get_ref() != null
	var retained = inventory_ref.get_ref()
	var released: bool = false
	if retained != null:
		released = retained.set_seed_expiry_authority(null).ok
	retained = null
	print("REDWALL_STOCK_LIFETIME " + JSON.stringify({
		"bound": bound,
		"inventory_retained_after_external_refs_dropped": retained_inventory,
		"stock_age_retained_after_external_refs_dropped": retained_age,
		"cleanup_unbind_attempted": retained_inventory,
		"cleanup_unbind_succeeded": released if retained_inventory else null,
		"inventory_released_at_probe_end": inventory_ref.get_ref() == null,
		"stock_age_released_at_probe_end": age_ref.get_ref() == null
	}))
	quit(0)
