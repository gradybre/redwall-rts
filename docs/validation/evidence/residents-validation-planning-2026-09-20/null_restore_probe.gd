extends SceneTree
const Residents := preload("res://scripts/core/residents.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var store: Residents = Residents.new()
	var result: bool = store.restore_columns(null)
	print("RESIDENTS_NULL_RESTORE returned=%s diagnostic=%s" % [result,store.last_column_refusal()])
	quit()
