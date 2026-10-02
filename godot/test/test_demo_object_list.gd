extends "res://test/framework/test_case.gd"
## The accessible object list and the interactive targets (decision 0471, review UX-023, P9), off-tree: what exists is
## listed in kind order and named as its owner names it; a row selects its thing as a click does and centres the camera
## on it, then closes; a filter shows one kind; a thing gone since the list was drawn says so; and the targets' rings
## are drawn on the surface and below.

const TargetsScript := preload("res://demo/access/world_targets.gd")
const ListScript := preload("res://demo/access/object_list.gd")
const MarksScript := preload("res://demo/access/target_marks.gd")
const VillageTargets := preload("res://demo/access/village_targets.gd")
const RunScript := preload("res://demo/session/run_until.gd")

var _nodes: Array[Node] = []
var _targets: TargetsScript = null
var _picked: Array[String] = []
var _centred: Array[Vector3] = []
var _bridge_there: bool = true


func before_each() -> void:
	"""Three residents, two beds, one bridge (which may vanish), one tunnel mouth, one room below."""
	_targets = TargetsScript.new()
	_picked.clear()
	_centred.clear()
	_bridge_there = true
	var names: PackedStringArray = ["Mouse keeper", "Otter boatwright", "Mole digger"]
	_targets.register(TargetsScript.KIND_RESIDENT, func() -> int: return 3, func(_i: int) -> bool: return true,
		func(i: int) -> String: return names[i], func(i: int) -> Vector3: return Vector3(float(i), 0.0, 2.0),
		func(i: int) -> void: _picked.append("resident %d" % i))
	_targets.register(TargetsScript.KIND_BED, func() -> int: return 2, func(_b: int) -> bool: return true,
		func(b: int) -> String: return "the carrot bed" if b == 0 else "bed 2", func(b: int) -> Vector3: return Vector3(5.0, 0.0, float(b)),
		func(b: int) -> void: _picked.append("bed %d" % b))
	_targets.register(TargetsScript.KIND_BRIDGE, func() -> int: return 4, func(r: int) -> bool: return r == 2 and _bridge_there,
		func(_r: int) -> String: return "Neck bridge", func(_r: int) -> Vector3: return Vector3(9.0, 0.0, 9.0),
		func(r: int) -> void: _picked.append("bridge %d" % r))
	_targets.register(TargetsScript.KIND_MOUTH, func() -> int: return 1, func(_m: int) -> bool: return true,
		func(_m: int) -> String: return "Mouth of tunnel 1", func(_m: int) -> Vector3: return Vector3(2.0, 0.0, -6.0),
		func(m: int) -> void: _picked.append("mouth %d" % m))
	_targets.register(TargetsScript.KIND_ROOM, func() -> int: return 1, func(_r: int) -> bool: return true,
		func(_r: int) -> String: return "Burrow home 1", func(_r: int) -> Vector3: return Vector3(-3.0, -2.5, 4.0),
		func(r: int) -> void: _picked.append("room %d" % r))
	_targets.centre = func(at: Vector3) -> void: _centred.append(at)


func after_each() -> void:
	"""Free what a test built, and drop the targets: their lambdas capture this suite, which holds them (a cycle)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_targets = null


func _list() -> ListScript:
	"""The object list over the test's targets, opened."""
	var list := ListScript.new()
	_nodes.append(list)
	list.targets = _targets
	list.open()
	return list


func test_collect_lists_what_exists_in_kind_order() -> void:
	"""Residents, then beds, then the one bridge that exists, then the mouth, then the room."""
	assert_equal(_targets.collect(), 8, "eight things")
	assert_equal(_targets.kinds, PackedByteArray([0, 0, 0, 1, 1, 3, 4, 5]), "in kind order")
	assert_equal(_targets.ids, PackedInt32Array([0, 1, 2, 0, 1, 2, 0, 0]), "with their own ids")


func test_rows_name_things_as_their_owners_do() -> void:
	"""'Mouse keeper — resident', 'The carrot bed — crop bed' (first letter up), 'Burrow home 1 — room'."""
	_targets.collect()
	assert_equal(_targets.row_text(0), "Mouse keeper — resident", "a resident")
	assert_equal(_targets.row_text(3), "The carrot bed — crop bed", "a bed")
	assert_equal(_targets.row_text(7), "Burrow home 1 — room", "a room")


func test_the_list_shows_a_row_per_thing_and_the_count() -> void:
	"""Open: eight rows shown, the count line."""
	var list := _list()
	assert_equal(list.shown_rows(), 8, "eight")
	assert_true(list.row_button(7).visible, "the last row shown")
	assert_equal(list.row_button(1).text, "Otter boatwright — resident", "a row's words")
	assert_equal(list.status_text(), "8 listed", "the count")


func test_choosing_a_row_selects_centres_and_closes() -> void:
	"""The second resident: picked as a click does, the camera over it, the list closed."""
	var list := _list()
	assert_true(list.choose(1), "chosen")
	assert_equal(_picked, ["resident 1"] as Array[String], "selected through the owner's own call")
	assert_equal(_centred, [Vector3(1.0, 0.0, 2.0)] as Array[Vector3], "the camera over it")
	assert_false(list.visible, "closed")


func test_a_room_is_centred_on_the_ground_above_it() -> void:
	"""A room below: the camera's focus is its (x, z) on the ground."""
	var list := _list()
	list.choose(7)
	assert_equal(_picked, ["room 0"] as Array[String], "the room")
	assert_equal(_centred[0], Vector3(-3.0, 0.0, 4.0), "its ground point")


func test_a_filter_lists_one_kind() -> void:
	"""Crop beds alone: two rows; All again: seven."""
	var list := _list()
	list.set_filter(1 << TargetsScript.KIND_BED)
	assert_equal(list.shown_rows(), 2, "two beds")
	assert_false(list.row_button(2).visible, "the rest hidden")
	assert_true(list.filter_button(1 + TargetsScript.KIND_BED).button_pressed, "its filter lit")
	list.set_filter(TargetsScript.ALL_KINDS)
	assert_equal(list.shown_rows(), 8, "all again")
	assert_true(list.filter_button(0).button_pressed, "All lit")


func test_a_thing_gone_since_says_so_and_stays_open() -> void:
	"""The bridge removed after the list was drawn: no selection, the line says so."""
	var list := _list()
	_bridge_there = false
	assert_false(list.choose(5), "not chosen")
	assert_equal(_picked.size(), 0, "nothing selected")
	assert_equal(list.status_text(), "Neck bridge is no longer there.", "says so")
	assert_true(list.visible, "still open")


func test_an_empty_kind_says_so() -> void:
	"""Trees: none registered here, nothing listed."""
	var list := _list()
	list.set_filter(1 << TargetsScript.KIND_TREE)
	assert_equal(list.status_text(), ListScript.EMPTY_TEXT, "nothing of that kind")


func test_rings_are_drawn_on_the_surface_and_below() -> void:
	"""Seven things on the surface get a surface ring; the room and the mouth a ring below."""
	var marks := MarksScript.new()
	_nodes.append(marks)
	marks.configure(_targets)
	marks.set_shown(true)
	assert_equal(marks.surface_rings, 7, "residents, beds, the bridge, the mouth")
	assert_equal(marks.below_rings, 2, "the mouth and the room")
	marks.set_shown(false)
	assert_false(marks.visible, "hidden")


func test_bridge_state_reads_gone_when_the_row_is_reused() -> void:
	"""A project's watch names its row by (row, generation)."""
	var bridges: RefCounted = load("res://demo/waterplay/bridges.gd").new()
	assert_equal(VillageTargets.bridge_state(bridges, 0, 0), RunScript.PROJECT_GONE, "a free row: gone")


func test_the_rings_refreshing_never_move_the_lists_rows() -> void:
	"""Review H1: the rings list every kind on their own; a filtered list's row 0 still picks its own thing after."""
	var list := _list()
	var marks := MarksScript.new()
	_nodes.append(marks)
	marks.configure(_targets)
	list.set_filter(1 << TargetsScript.KIND_BED)
	marks.set_shown(true)
	marks.rebuild()
	assert_equal(list.shown_rows(), 2, "the list still holds its two beds")
	assert_true(list.choose(0), "chosen")
	assert_equal(_picked, ["bed 0"] as Array[String], "the bed, not resident 0")
