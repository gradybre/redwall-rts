extends SceneTree
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Case := preload("res://test/framework/test_case.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var f: Case = Case.new()
	var frame: Section.FramedOwner = Section.FramedOwner.new(13)
	var quantity: PackedInt64Array = frame.i64_column(2)
	var capacity: PackedInt64Array = frame.i64_column(3)
	f.assert_equal(quantity.size(),4096,"quantity extent")
	f.assert_equal(capacity.size(),4096,"capacity extent")
	quantity[4095] = 9007199254740993
	capacity[4095] = 9223372036854775807
	f.assert_true(frame.set_i64(2,quantity),"existing quantity setter")
	f.assert_true(frame.set_i64(3,capacity),"existing capacity setter")
	f.assert_equal(frame.i64_column(2)[4095],9007199254740993,"quantity exact above2^53")
	f.assert_equal(frame.i64_column(3)[4095],9223372036854775807,"capacity exact int64max")
	f.assert_true(Section.owner_shape_refusal(frame).is_ok(),"actual typed frame shape")
	f.assert_equal(Nodes.RESOURCE_NODE_CAPACITY,4096,"physical rows")
	f.assert_equal(Nodes.TILE_COUNT,16384,"tile domain")
	f.assert_equal(Nodes.EntityDirectory.DIRECTORY_CAPACITY,352418,"global ref domain")
	f.assert_equal(Nodes.MIN_CALENDAR_DAY,1,"day floor")
	f.assert_equal(Nodes.NULL_REF,Vector2i(-1,0),"null pair")
	for failure: String in f.failures: printerr(failure)
	print("RESOURCE_NODES_TYPED_API_PROBE assertions=%d failures=%d" % [f.assertions,f.failures.size()])
	quit(0 if f.failures.is_empty() else 1)
