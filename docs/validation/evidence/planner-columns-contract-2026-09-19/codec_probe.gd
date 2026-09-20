extends "schema_probe.gd"
static func encode(record: Record) -> PackedByteArray:
	return record.values.to_byte_array()
