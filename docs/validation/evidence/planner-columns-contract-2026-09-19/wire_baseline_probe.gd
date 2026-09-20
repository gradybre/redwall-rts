extends SceneTree
## Preserve actual schema2 bytes before any proposed shared-schema extraction.
const Section := preload("res://scripts/core/save_section_job_indexes.gd")

func _init() -> void:
	var examples: Array[Dictionary] = []
	for label: String in ["empty", "dirty_farm_0_1", "dirty_farm_1_0"]:
		var record: Section.Record = Section.Record.new()
		if label != "empty":
			record.set_value(Section.FIELD_DIRTY_COUNT, 0, 2)
			record.set_value(Section.FIELD_DIRTY_ROWS, 0, 0 if label.ends_with("0_1") else 1)
			record.set_value(Section.FIELD_DIRTY_ROWS, 1, 1 if label.ends_with("0_1") else 0)
		var encoded: Section.EncodeResult = Section.EncodeResult.new()
		assert(Section.encode_section(record, encoded))
		var hash: HashingContext = HashingContext.new()
		assert(hash.start(HashingContext.HASH_SHA256) == OK)
		assert(hash.update(encoded.bytes) == OK)
		examples.append({"fixture": label, "bytes": encoded.bytes.size(),
			"sha256": hash.finish().hex_encode(), "fields": Section.FIELD_COUNT,
			"groups": [record.u8_columns.size(), record.i32_columns.size(), record.i64_columns.size()]})
	print("WIRE_BASELINE=" + JSON.stringify(examples))
	quit(0)
