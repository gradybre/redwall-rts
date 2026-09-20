extends SceneTree

class Result:
	var a: PackedInt64Array = PackedInt64Array([1, 2])
	var b: PackedInt64Array = PackedInt64Array([3, 4])

func _init() -> void:
	var target: Result = Result.new()
	target.b = target.a
	target.a[0] = 9
	print("cross_field_alias_after_write=", target.b[0])
	var held: PackedInt64Array = target.a
	var staged: Result = Result.new()
	target.a = staged.a
	target.b = staged.b
	target.a[0] = 7
	print("after_rebind_a=", target.a, " b=", target.b, " retained_old=", held)
	assert(target.b[0] == 3)
	assert(held[0] == 9)
	quit(0)
