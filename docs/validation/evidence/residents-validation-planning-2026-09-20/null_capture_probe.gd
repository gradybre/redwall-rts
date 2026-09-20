extends SceneTree
const Residents := preload("res://scripts/core/residents.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var store: Residents = Residents.new()
	var result: bool = store.copy_columns_into(null)
	print("RESIDENTS_NULL_CAPTURE returned=%s diagnostic=%s" % [result,store.last_column_refusal()])
	quit()
