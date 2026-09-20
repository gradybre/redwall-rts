extends SceneTree
const Schema := preload("schema_probe.gd")
const Codec := preload("codec_probe.gd")
func _init() -> void:
	var record: Codec.Record = Codec.Record.new()
	assert(Codec.SIZE == 3)
	assert(Codec.accepted(record))
	assert(Schema.accepted(record))
	assert(Codec.encode(record).size() == 12)
	print("inherited const, nested type, constructor and static validator: PASS")
	quit(0)
