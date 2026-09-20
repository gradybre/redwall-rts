extends SceneTree
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Bytes := preload("res://scripts/core/save_codec.gd")
func _initialize() -> void:
	var results: Array = []
	for variant: int in 4:
		var rows: int = 8 if variant < 2 else 32768
		var block: Codec.OwnerRecord = Codec.OwnerRecord.new(4,rows,PackedInt64Array())
		if variant == 1 or variant == 3:
			for row: int in rows:
				if variant == 1 and row != 2 and row != 5:
					continue
				block.u8_columns[0][row] = 1
				block.i32_columns[0][row] = 1
				block.i32_columns[1][row] = 2
				block.i32_columns[2][row] = 0
				block.i32_columns[3][row] = 3
				block.i32_columns[4][row] = -2147483648 + rows - row
				block.i64_columns[0][row] = row + 1
				block.i64_columns[1][row] = row
		if not Codec.owner_refusal(block).is_ok():
			print("codec refused fixture:",variant)
			quit(1)
			return
		var writer: Bytes.Writer = Bytes.Writer.new(40)
		writer.write_utf8_u32("reservations",256)
		writer.write_u32(1)
		writer.write_u64(rows)
		writer.write_u64(Codec.payload_bytes_of(block))
		writer.write_u32(0)
		var raw: PackedByteArray = writer.to_bytes()
		for ordinal: int in 8:
			var prefix: Bytes.Writer = Bytes.Writer.new(8)
			prefix.write_u64(rows)
			raw.append_array(prefix.to_bytes())
			raw.append_array(Codec.column_slice(block,ordinal,0,rows))
		if raw.size() != 104 + 37*rows:
			print("unexpected framing:",raw.size())
			quit(1)
			return
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		results.append({"variant":variant,"rows":rows,"bytes":raw.size(),"sha256":hash.finish().hex_encode()})
	print(JSON.stringify(results))
	quit()
