extends SceneTree
## Boots the real demo village headless and prints what its pantry opened with (decision 0912), for
## test/test_demo_opening_pantry.gd. Not discovered by the runner (test/live/).
##
##     godot --headless --path godot --script res://test/live/opening_pantry_probe.gd
##
## Prints `OPENING wheat=<milli> carrot=<milli> ready_days_milli=<milli-days> harvested=<milli> residents=<n>` on the
## first frame (the
## village's `_ready` has run; its clock has not moved), then quits. `harvested` is what the record's open day would
## count as harvested if it closed now: the pantry's stored ledger less the record's snapshot (its private columns,
## read here only). Exits 1 (and says why) when a part it reads is not where it looks.

var _village: Node = null


func _initialize() -> void:
	"""Boot the village."""
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village


func _process(_delta: float) -> bool:
	"""On the first frame: read the pantry, the kitchen's Ready food and the record's open day; quit."""
	var farm: Node = _village.get(&"_farm")
	var pantry: RefCounted = farm.get(&"pantry") if farm != null else null
	var record: RefCounted = farm.get(&"record") if farm != null else null
	var kitchen_node: Node = _village.call(&"kitchen") as Node
	var kitchen: RefCounted = kitchen_node.get(&"kitchen") if kitchen_node != null else null
	var snap: Variant = record.get(&"_snap_items") if record != null else null
	if pantry == null or kitchen == null or not snap is PackedInt64Array:
		print("OPENING-ERROR the farm, its pantry, its record's snapshot or the kitchen is not where the probe reads it")
		quit(1)
		return true
	var catalog: GDScript = load("res://demo/farm/farm_catalog.gd") as GDScript
	var keys: Array = catalog.get(&"ITEM_KEYS")
	var harvested: int = 0
	for item: int in int(catalog.get(&"PANTRY_ITEM_COUNT")):
		harvested += int(pantry.call(&"stored_total_milli", item)) - int((snap as PackedInt64Array)[item])
	@warning_ignore("integer_division") var residents: int = int(kitchen.call(&"daily_portions")) / 2
	print("OPENING wheat=%d carrot=%d ready_days_milli=%d harvested=%d residents=%d" % [
		int(pantry.call(&"milli_of", keys.find(&"wheat"))), int(pantry.call(&"milli_of", keys.find(&"carrot"))),
		int(kitchen.call(&"days_of_meals_milli")), harvested, residents])
	quit(0)
	return true
