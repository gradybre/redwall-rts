extends SceneTree
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const Bytes := preload("res://scripts/core/save_codec.gd")
func _initialize() -> void:
	var results: Array = []
	for count: int in [0,1,2,101376]:
		var block: Codec.OwnerRecord = Codec.OwnerRecord.new(5,101376,PackedInt64Array())
		assert(block.set_scalar(0,count))
		var classes: PackedByteArray = block.u8_column(2)
		var gens: PackedInt32Array = block.i32_column(4)
		var slots: PackedInt32Array = block.i32_column(5)
		for i: int in count:
			var slot: int = (2 - i) if count == 2 else i
			classes[slot] = 3
			gens[slot] = 1
			slots[i] = slot
		assert(Codec.owner_refusal(block).is_ok())
		var writer: Bytes.Writer = Bytes.Writer.new(Codec.block_bytes_of(block))
		writer.write_utf8_u32("stock_age",256)
		writer.write_u32(1)
		writer.write_u64(101376)
		writer.write_u64(Codec.payload_bytes_of(block))
		writer.write_u32(0)
		var raw: PackedByteArray = writer.to_bytes()
		for field: int in 6:
			var n: int = Codec.persisted_count_of(block,field)
			var prefix: Bytes.Writer = Bytes.Writer.new(8)
			prefix.write_u64(n)
			raw.append_array(prefix.to_bytes())
			raw.append_array(Codec.column_slice(block,field,0,n))
		assert(raw.size() == 608353 + 4*count)
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(raw)
		results.append({"count":count,"payload":Codec.payload_bytes_of(block),"block_bytes":raw.size(),"sha256":hash.finish().hex_encode()})
	print(JSON.stringify(results))
	quit()
