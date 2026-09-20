extends SceneTree
func _initialize() -> void:
	"""Check the installed engine's typed i64 count operation without float conversion."""
	var values: PackedInt64Array = PackedInt64Array()
	values.resize(384)
	assert(values.count(0) == 384)
	values[383] = 9007199254740993
	assert(values.count(0) == 383 and values.count(9007199254740993) == 1)
	values[0] = -9223372036854775807-1
	values[1] = 9223372036854775807
	assert(values.count(0) == 381)
	assert(values.count(-9223372036854775807-1) == 1)
	assert(values.count(9223372036854775807) == 1)
	print("FAUNA_INT64_COUNT_PROBE exact384zeros_and_signed_extrema_PASS")
	quit(0)
