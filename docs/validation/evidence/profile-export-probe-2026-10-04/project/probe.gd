class_name CodexProfileExportProbe extends SceneTree
## Isolated export capability probe, not suite or gameplay qualification.

const Owner := preload("res://probe_owner.gd")


func _initialize() -> void:
	"""Observe the executing cached resource and the raw profile extension in this exact pack."""
	var path: String = "res://probe_owner.gd"
	var actual: RefCounted = Owner.new()
	var script: Script = actual.get_script() as Script
	var record: Dictionary = {
		"value": Owner.value(),
		"cached": ResourceLoader.has_cached(path),
		"source_length": script.get_source_code().length(),
		"source_matches_cached": ResourceLoader.get_cached_ref(path) == script,
		"raw_profile_exists": FileAccess.file_exists("res://probe.ugprof"),
		"template": OS.has_feature("template"),
		"debug_build": OS.is_debug_build(),
	}
	print("PROFILE_EXPORT_CAPABILITY ", JSON.stringify(record))
	quit(0 if record["value"] == 17 else 1)
