extends SceneTree
const Inv := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
func _initialize() -> void:
	var inv: Inv = Inv.new(2,4)
	var pool: Reservations = Reservations.new(4,4,4)
	if not inv.register_item(0,1,0).ok or not inv.register_item(1,1,0).ok:
		quit(1)
		return
	var container = inv.create_container(Vector2i(1,1),9223372036854775807,Inv.FILTERS_ACCEPT_ALL,0,true)
	if not container.ok:
		print("container refused:",container.code)
		quit(1)
		return
	for item: int in [0,1]:
		var lot = inv.create_lot(container.ref,item,6000000000000000000,0,0,0,0,0)
		if not lot.ok:
			print("lot refused:",lot.code)
			quit(1)
			return
		var result = pool.claim_batch(Vector2i(1,1),PackedInt64Array([lot.ref.x,lot.ref.y,item,6000000000000000000,100]),1,inv)
		if not result.ok:
			print("claim refused:",result.code)
			quit(1)
			return
	print(JSON.stringify({"active_rows":pool.active_row_count(),"job_total_accessor":pool.job_reserved_total_milli(Vector2i(1,1)),"pool_audit_ok":pool.audit(inv).ok,"individual_lot_quantity":6000000000000000000}))
	quit()
