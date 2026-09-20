extends RefCounted
const SIZE: int = 3
class Record:
	var values: PackedInt32Array = PackedInt32Array([1, 2, 3])
static func accepted(record: Record) -> bool:
	return record.values.size() == SIZE
