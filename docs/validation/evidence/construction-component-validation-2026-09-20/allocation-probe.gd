extends SceneTree
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_construction.gd")
const LIMIT: int = 1048576
var evidence: Dictionary = {}
func _finish(status: String, code: String, exit_code: int) -> void:
	evidence["status"] = status
	evidence["code"] = code
	print("CONSTRUCTION_ALLOCATION "+JSON.stringify(evidence))
	quit(exit_code)
func _initialize() -> void:
	if not ClassDB.class_has_method("OS","get_static_memory_usage") or not ClassDB.class_has_method("OS","get_static_memory_peak_usage"):
		_finish("UNAVAILABLE","MEMORY_API",2)
		return
	var frame: Section.FramedOwner = Section.FramedOwner.new(1)
	for field: int in [1,9,11,14]:
		var values: PackedInt32Array = frame.i32_column(field)
		values.fill(-1)
		if not frame.set_i32(field,values):
			_finish("ERROR","FRAME_SETUP",2)
			return
	var prior_peak: int = OS.get_static_memory_peak_usage()
	var prior_usage: int = OS.get_static_memory_usage()
	if prior_peak <= 0 or prior_usage <= 0 or prior_peak < prior_usage:
		_finish("UNAVAILABLE","INVALID_PRIOR_READING",2)
		return
	var ballast_size: int = prior_peak-prior_usage+LIMIT
	if ballast_size <= 0 or ballast_size > 134217728:
		_finish("UNAVAILABLE","BALLAST_BOUNDS",2)
		return
	var ballast: PackedByteArray = PackedByteArray()
	if ballast.resize(ballast_size) != OK:
		_finish("UNAVAILABLE","BALLAST_ALLOCATION",2)
		return
	var lifted_usage: int = OS.get_static_memory_usage()
	var before_peak: int = OS.get_static_memory_peak_usage()
	if lifted_usage <= prior_peak or before_peak < lifted_usage:
		_finish("UNAVAILABLE","BALLAST_NOT_ABOVE_PRIOR_PEAK",2)
		return
	var result: Variant = Bridge.framed_refusal(frame)
	var after_peak: int = OS.get_static_memory_peak_usage()
	var after_usage: int = OS.get_static_memory_usage()
	# Record after measuring so Dictionary growth does not pollute this increment.
	evidence = {"prior_peak":prior_peak,"prior_usage":prior_usage,"ballast_bytes":ballast.size(),"lifted_usage":lifted_usage,"before_peak":before_peak,"after_peak":after_peak,"after_usage":after_usage,"increment":after_peak-before_peak,"limit":LIMIT,"bridge_code":String(result.code)}
	if after_peak <= 0 or after_usage <= 0 or after_peak < before_peak or after_peak < after_usage:
		_finish("UNAVAILABLE","INVALID_AFTER_READING",2)
		return
	if not result.is_ok() or result.detail != "":
		_finish("ERROR","BRIDGE_REFUSAL",2)
		return
	if after_peak-before_peak >= LIMIT:
		_finish("FAIL","ALLOCATION_EXTRA_OWNER",1)
		return
	_finish("PASS","",0)
