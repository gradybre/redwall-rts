extends SceneTree
const Inventory = preload("res://scripts/core/inventory.gd")
var checks: int = 0
var failures: int = 0
func require(value: bool, label: String) -> void:
	checks += 1
	if not value:
		push_error(label)
		failures += 1
func _initialize() -> void:
	var inv = Inventory.new(2, 2)
	require(inv.register_item(7, 250, 0).ok, "register")
	var c = inv.create_container(Vector2i(4, 1), 100000, -1, 0, true).ref
	var a = inv.create_lot(c, 7, 1000, 0, 3, 0, 0, 0).ref
	var b = inv.create_lot(c, 7, 1000, 0, 3, 0, 0, 0).ref
	require(inv.reserve_lot(b, 250).ok, "reserve source")
	require(inv.merge_lots(a, b).ok, "merge reserved source")
	require(not inv.is_lot_valid(b), "old reference invalid")
	require(inv._l_live[b.x] == 0 and inv._l_quantity_milli[b.x] == 0, "source inactive")
	require(inv._l_reserved_milli[b.x] == 250, "retired reservation residue is real")
	require(inv._l_reserved_milli[a.x] == 250, "live reservation retained")
	require(inv.audit().ok, "live inventory audit")
	print("MERGE: dead quantity=", inv._l_quantity_milli[b.x], " dead reserved=", inv._l_reserved_milli[b.x], " live reserved=",inv._l_reserved_milli[a.x])
	var single = Inventory.new(2, 1)
	require(single.register_item(7, 250, 0).ok, "register single")
	var from = single.create_container(Vector2i(5, 1), 100000, -1, 0, true).ref
	var to = single.create_container(Vector2i(6, 1), 100000, -1, 0, true).ref
	var lot = single.create_lot(from, 7, 1000, 2, 3, 11, 123, 42).ref
	var moved = single.transfer(lot, to, 1000)
	require(moved.ok, "one-slot whole transfer")
	require(moved.ref.x == lot.x and moved.ref.y != lot.y, "reuse source slot with fresh generation")
	require(single._l_item_id[moved.ref.x] == 7 and single._l_quality[moved.ref.x] == 2 and single._l_provenance[moved.ref.x] == 3 and single._l_recipe_id[moved.ref.x] == 11, "attributes survive retire then read")
	require(single._l_age_milli_hours[moved.ref.x] == 123 and single._l_age_remainder[moved.ref.x] == 42, "unmerged transfer age and remainder")
	require(single.audit().ok, "transfer conservation")
	print("TRANSFER: slot reused, item/quality/provenance/recipe/age retained")
	print("CYCLE2 INVENTORY PROBE: ",checks," checks, ",failures," failures; production source unchanged")
	quit(0 if failures == 0 else 1)
