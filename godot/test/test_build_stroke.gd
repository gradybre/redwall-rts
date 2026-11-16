extends "res://test/framework/test_case.gd"
## The stroke in progress (decision 1912; P-C7 (a)): the four tools on the planner's draft, the stamp's cells and the
## size label's width × depth.

const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 64, 64)
const KITCHEN: int = 2

var _stroke: Stroke = null


func before_each() -> void:
	"""A fresh stroke."""
	_stroke = Stroke.new()


func test_the_four_tools_and_their_words() -> void:
	"""Rectangle, Oval, Paint and Erase, each with a strip label, a name and a gesture in words."""
	assert_equal(Stroke.TOOL_COUNT, 4, "four")
	for tool: int in Stroke.TOOL_COUNT:
		assert_true(Stroke.valid_tool(tool), "tool %d" % tool)
		assert_false(Stroke.TOOL_GESTURES[tool].is_empty(), "a gesture")
	assert_false(Stroke.valid_tool(4) or Stroke.valid_tool(-1), "no others")
	assert_equal(Stroke.TOOL_NAMES, ["Rectangle", "Oval", "Paint", "Erase"], "the ruling's names")


func test_begin_refuses_an_unknown_tool_or_room_identity() -> void:
	"""An unknown tool, or a room type the planner refuses, starts nothing."""
	assert_false(_stroke.begin(9, KITCHEN, 1, Vector2i.ZERO, 1024, 4096, BOUNDS), "no tool 9")
	assert_false(_stroke.begin(Stroke.TOOL_RECTANGLE, 99, 1, Vector2i.ZERO, 1024, 4096, BOUNDS), "no type 99")
	assert_false(_stroke.active(), "nothing begun")
	assert_equal(_stroke.size(), Vector2i.ZERO, "no size")
	assert_true(_stroke.cells().is_empty(), "no cells")
	assert_false(_stroke.extend(Vector2i.ONE), "nothing to extend")


func test_a_rectangle_is_the_corners_box() -> void:
	"""Rectangle: the planner's rectangle between the corners; the size is the box."""
	assert_true(_stroke.begin(Stroke.TOOL_RECTANGLE, KITCHEN, 1, Vector2i(3, 3), 1024, 4096, BOUNDS), "begun")
	assert_true(_stroke.extend(Vector2i(0, 1)), "moved")
	assert_false(_stroke.extend(Vector2i(0, 1)), "the same cell again changes nothing")
	assert_equal(_stroke.size(), Vector2i(4, 3), "4 × 3")
	assert_equal(_stroke.cells(), Footprint.rectangle(0, 1, 4, 3, 4096).cells, "the planner's rectangle")
	assert_false(_stroke.erasing(), "painting")
	_stroke.clear()
	assert_false(_stroke.active(), "released")


func test_the_brush_size_is_its_stamps_box_and_erase_says_so() -> void:
	"""Paint and Erase: the size label reads the stamp's bounding box; Erase is erasing."""
	_stroke.begin(Stroke.TOOL_ERASE, KITCHEN, 1, Vector2i(2, 2), 1024, 4096, BOUNDS)
	_stroke.extend(Vector2i(2, 6))
	assert_true(_stroke.erasing(), "erasing")
	assert_equal(_stroke.size(), Vector2i(2, 6), "2 wide, rows 2-7")
	assert_equal(Stroke.box_of(_stroke.cells()), Rect2i(2, 2, 2, 6), "the box")
	assert_equal(Stroke.box_of(PackedInt32Array()), Rect2i(), "an empty box for nothing")


func test_a_stroke_past_the_area_reports_the_planners_refusal() -> void:
	"""The planner refuses the stamp whole; the stroke has no cells and says why."""
	_stroke.begin(Stroke.TOOL_RECTANGLE, KITCHEN, 1, Vector2i(60, 60), 1024, 4096, BOUNDS)
	_stroke.extend(Vector2i(70, 61))
	assert_equal(_stroke.error(), &"ROOM_OUTSIDE_PLANNING_BOUNDS", "refused")
	assert_true(_stroke.cells().is_empty(), "no cells shown")
