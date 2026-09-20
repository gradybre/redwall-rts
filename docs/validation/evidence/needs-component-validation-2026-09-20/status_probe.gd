extends SceneTree
const Needs := preload("res://scripts/core/needs.gd")
func _initialize() -> void:
	var store: Needs = Needs.new()
	store.spawn(0,Needs.SIZE_SMALL)
	var columns: Needs.Columns = Needs.Columns.new()
	store.copy_columns_into(columns)
	columns.health[0] = 0
	columns.status[0] = Needs.STATUS_ACTIVE
	var accepted: bool = store.restore_columns(columns)
	var before: Dictionary = {"accepted":accepted,"health":store.health_of(0).value,
		"status":store.status_of(0).value,"living":store.living_count()}
	store.tick_all()
	var after: Dictionary = {"health":store.health_of(0).value,
		"status":store.status_of(0).value,"living":store.living_count()}
	print("NEEDS_STATUS_PROBE "+JSON.stringify({"before_tick":before,"after_tick":after}))
	quit(0 if accepted else 1)
