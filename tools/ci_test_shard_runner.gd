extends "res://test/run_tests.gd"
## CI changes suite selection only; the inherited worker and diagnostic supervisor remain authoritative.
## The shell's zero diagnostic/leak allowances still run after this supervisor exits.


func _discover_suites() -> PackedStringArray:
	"""Select validated names from the inherited discovery, refusing empty, unknown or duplicate files."""
	var requested: Variant = JSON.parse_string(OS.get_environment("REDWALL_TEST_SHARD_SUITES"))
	var selected: PackedStringArray = PackedStringArray()
	if not requested is Array or requested.is_empty():
		push_error("CI shard selection must be a non-empty JSON array")
		return selected
	var discovered: PackedStringArray = super._discover_suites()
	for entry: Variant in requested:
		if not entry is String:
			push_error("CI shard suite name must be a string")
			return PackedStringArray()
		var path: String = "res://test/" + String(entry)
		if not discovered.has(path) or selected.has(path):
			push_error("CI shard suite is missing or duplicated: %s" % entry)
			return PackedStringArray()
		selected.append(path)
	selected.sort()
	return selected


func _run_suite(suite_path: String) -> Dictionary:
	"""Keep the existing suite lifecycle and add a completion timestamp for future balancing."""
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._run_suite(suite_path)
	_emit("CI_SUITE_TIME " + JSON.stringify({"suite": suite_path.get_file(), "usec": Time.get_ticks_usec() - started,
		"tests": result["tests"], "assertions": result["assertions"], "failures": result["failed"]}))
	return result
