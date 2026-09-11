extends "res://test/framework/test_case.gd"
## Coverage for §1.2's click-through rule and UX-T04: decorative UI must not eat world clicks.
##
## UX-T04's pass criterion is "Click/drag/scroll through 1000 UI interactions issue zero
## unintended world orders", and §1.2's rule is that the world click-through rectangle is "the
## viewport minus the ACTUAL VISIBLE INPUT RECTANGLES" -- with the explicit warning that "A
## transparent full-screen Control must not block the center."
##
## The decisive test below is `test_a_full_screen_decorative_region_never_consumes_a_point`: it
## registers a decorative region covering the entire viewport, on the permanent-HUD layer, and
## then samples a thousand world points. Every one must still reach the world. That is the exact
## failure mode a full-screen HUD root introduces, and it is invisible to a test that only
## checks the buttons work.

const UiHitTest := preload("res://scripts/ui/ui_hit_test.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## §4's ids for the regions registered below, so a failure names the element.
const ID_WORLD_SURFACE: int = 23
const ID_RESOURCE_CLUSTER: int = 1
const ID_TIME_CLUSTER: int = 13
const ID_MINIMAP: int = 20
const ID_DETAIL: int = 36
const ID_COMMANDS: int = 26
const ID_ALERTS: int = 10
const ID_MODAL: int = 51
const ID_TOOLTIP: int = 73

## UX-T04's interaction count.
const SAMPLE_COUNT: int = 1000

var _hits: UiHitTest = null
var _layout: UiLayout = null
var _geometry: UiLayout.Geometry = null


func before_each() -> void:
	"""Build an empty region table and the 1280x720 standard geometry to register."""
	_hits = UiHitTest.new()
	_layout = UiLayout.new()
	_geometry = UiLayout.Geometry.new()
	assert_true(_layout.compute_into(1280, 720, 100, true, _geometry), "the geometry computes")


func after_each() -> void:
	"""Drop everything so no region survives into the next test."""
	_hits = null
	_layout = null
	_geometry = null


# --- helpers ------------------------------------------------------------------------------------

func _register_permanent_hud() -> void:
	"""Register the five permanent HUD rectangles as real, consuming input rectangles."""
	_hits.add_region(ID_RESOURCE_CLUSTER, _geometry.resources, UiHitTest.LAYER_PERMANENT_HUD, true)
	_hits.add_region(ID_TIME_CLUSTER, _geometry.time, UiHitTest.LAYER_PERMANENT_HUD, true)
	_hits.add_region(ID_ALERTS, _geometry.alerts, UiHitTest.LAYER_PERMANENT_HUD, true)
	_hits.add_region(ID_MINIMAP, _geometry.minimap, UiHitTest.LAYER_PERMANENT_HUD, true)
	_hits.add_region(ID_COMMANDS, _geometry.commands, UiHitTest.LAYER_PERMANENT_HUD, true)
	_hits.add_region(ID_DETAIL, _geometry.detail, UiHitTest.LAYER_EXPANSION, true)


func _world_point(index: int) -> Vector2:
	"""One of SAMPLE_COUNT points spread across the centre band the world owns at 1280x720."""
	var columns: int = 40
	var x: float = 240.0 + float(index % columns) * 16.0
	var y: float = 120.0 + float(index / columns) * 16.0
	return Vector2(x, y)


# --- the decisive rule ----------------------------------------------------------------------------

func test_a_full_screen_decorative_region_never_consumes_a_point() -> void:
	"""§1.2: "A transparent full-screen Control must not block the center". UX-T04's criterion."""
	_hits.add_region(ID_WORLD_SURFACE, Rect2(0.0, 0.0, 1280.0, 720.0),
		UiHitTest.LAYER_PERMANENT_HUD, false)
	var reached: int = 0
	for index: int in SAMPLE_COUNT:
		if _hits.world_receives(_world_point(index)):
			reached += 1
	assert_equal(reached, SAMPLE_COUNT, "all 1000 sampled points still reach the world")
	assert_equal(_hits.region_count(), 1, "the decorative region is registered")
	assert_equal(_hits.consuming_count(), 0, "and consumes nothing at all")


func test_the_permanent_hud_leaves_the_centre_of_the_world_clickable() -> void:
	"""With every real HUD rectangle registered, the world band is still the player's."""
	_register_permanent_hud()
	_hits.add_region(ID_WORLD_SURFACE, Rect2(0.0, 0.0, 1280.0, 720.0),
		UiHitTest.LAYER_WORLD_OVERLAY, false)
	var blocked: int = 0
	for index: int in SAMPLE_COUNT:
		if not _hits.world_receives(_world_point(index)):
			blocked += 1
	assert_equal(blocked, 0, "no sampled world point is taken by the HUD")
	assert_equal(_hits.consuming_count(), 6, "six rectangles are real input rectangles")


func test_a_point_inside_a_real_control_is_taken_from_the_world() -> void:
	"""The other half of the rule: a visible interactive rectangle must consume its own area."""
	_register_permanent_hud()
	var inside_time: Vector2 = _geometry.time.position + Vector2(4.0, 4.0)
	assert_true(_hits.consumes_point(inside_time), "the time cluster takes its own point")
	assert_false(_hits.world_receives(inside_time), "so the world does not see it")
	assert_equal(_hits.element_at(inside_time).value, ID_TIME_CLUSTER, "and it names the element")


func test_a_point_just_outside_a_control_belongs_to_the_world() -> void:
	"""The rectangles are half-open: the pixel past the right edge is world, not UI."""
	_register_permanent_hud()
	var past_right: Vector2 = Vector2(_geometry.resources.position.x
		+ _geometry.resources.size.x, _geometry.resources.position.y + 4.0)
	assert_true(_hits.world_receives(past_right), "the pixel past the right edge is the world's")
	var last_inside: Vector2 = past_right - Vector2(1.0, 0.0)
	assert_false(_hits.world_receives(last_inside), "and the one before it is not")


# --- §3's layers -----------------------------------------------------------------------------------

func test_a_modal_takes_precedence_over_the_hud_beneath_it() -> void:
	"""§3 puts a modal at layer 80, above the permanent HUD at 20."""
	_register_permanent_hud()
	_hits.add_region(ID_MODAL, _geometry.modal, UiHitTest.LAYER_MODAL, true)
	var inside_modal: Vector2 = _geometry.modal.position + Vector2(8.0, 8.0)
	assert_equal(_hits.element_at(inside_modal).value, ID_MODAL, "the modal owns its own area")
	assert_equal(_hits.layer_at(inside_modal).value, UiHitTest.LAYER_MODAL, "at layer 80")


func test_registration_order_does_not_override_a_higher_layer() -> void:
	"""§1.2: "Visual z-order alone is insufficient to define interaction priority"."""
	_hits.add_region(ID_MODAL, Rect2(0.0, 0.0, 200.0, 200.0), UiHitTest.LAYER_MODAL, true)
	_hits.add_region(ID_COMMANDS, Rect2(0.0, 0.0, 200.0, 200.0),
		UiHitTest.LAYER_PERMANENT_HUD, true)
	assert_equal(_hits.element_at(Vector2(10.0, 10.0)).value, ID_MODAL,
		"the later-registered lower layer does not win")


func test_the_tooltip_layer_is_registered_without_consuming() -> void:
	"""§4 says UI-SET-073 is IGNORE; it must never take a click even at layer 60."""
	_register_permanent_hud()
	var tooltip: Rect2 = Rect2(300.0, 300.0, 200.0, 80.0)
	_hits.add_region(ID_TOOLTIP, tooltip, UiHitTest.LAYER_TOOLTIP, false)
	assert_true(_hits.world_receives(tooltip.position + Vector2(4.0, 4.0)),
		"a point under the tooltip still reaches the world")


func test_an_unknown_layer_is_refused_rather_than_placed_somewhere() -> void:
	"""§3 defines ten layers; a region cannot invent an eleventh."""
	assert_false(_hits.add_region(ID_MODAL, Rect2(0.0, 0.0, 10.0, 10.0), 35, true),
		"layer 35 is not one of §3's")
	assert_equal(_hits.last_refusal(), UiHitTest.REFUSE_UNKNOWN_LAYER, "with UNKNOWN_HIT_LAYER")
	assert_equal(_hits.region_count(), 0, "and nothing is registered")


# --- refusals and bookkeeping -----------------------------------------------------------------------

func test_a_point_owned_by_nothing_refuses_rather_than_naming_element_zero() -> void:
	""""No element here" is a different answer from "element 0", which §4 does not define."""
	_register_permanent_hud()
	var world_point: Vector2 = Vector2(640.0, 300.0)
	assert_false(_hits.element_at(world_point).ok, "no element owns a world point")
	assert_equal(_hits.last_refusal(), UiHitTest.REFUSE_NO_REGION, "with NO_REGION_AT_POINT")
	assert_false(_hits.layer_at(world_point).ok, "and no layer owns it either")


func test_a_negative_sized_region_is_refused() -> void:
	"""A rectangle with negative extent would contain nothing or everything, depending on order."""
	assert_false(_hits.add_region(ID_COMMANDS, Rect2(10.0, 10.0, -5.0, 20.0),
		UiHitTest.LAYER_PERMANENT_HUD, true), "a negative width refuses")
	assert_equal(_hits.last_refusal(), UiHitTest.REFUSE_NEGATIVE_SIZE, "with NEGATIVE_REGION_SIZE")


func test_the_table_refuses_rather_than_growing_past_its_capacity() -> void:
	"""ARCH-MEM-005: the columns are sized once, so the 257th region refuses."""
	for index: int in _hits.capacity():
		assert_true(_hits.add_region(ID_COMMANDS, Rect2(0.0, 0.0, 1.0, 1.0),
			UiHitTest.LAYER_PERMANENT_HUD, false) or index < 0, "region %d fits" % index)
	assert_equal(_hits.region_count(), _hits.capacity(), "the table is exactly full")
	assert_false(_hits.add_region(ID_COMMANDS, Rect2(0.0, 0.0, 1.0, 1.0),
		UiHitTest.LAYER_PERMANENT_HUD, false), "one more refuses")
	assert_equal(_hits.last_refusal(), UiHitTest.REFUSE_TABLE_FULL, "with HIT_TABLE_FULL")


func test_reset_drops_every_region_without_freeing_the_columns() -> void:
	"""Rebuilding the table each layout pass must allocate nothing."""
	_register_permanent_hud()
	assert_equal(_hits.region_count(), 6, "six regions are registered")
	_hits.reset()
	assert_equal(_hits.region_count(), 0, "reset drops them")
	assert_equal(_hits.capacity(), UiHitTest.REGION_CAPACITY, "the capacity is unchanged")
	assert_true(_hits.world_receives(Vector2(20.0, 20.0)), "and the world gets every point again")


func test_an_invalid_region_index_is_refused() -> void:
	"""Reading past the registered count refuses rather than returning a zero rectangle silently."""
	_register_permanent_hud()
	assert_false(_hits.region_consumes(6), "index 6 is past the six registered")
	assert_equal(_hits.last_refusal(), UiHitTest.REFUSE_INVALID_INDEX, "with INVALID_REGION_INDEX")
	assert_true(_hits.region_consumes(0), "and index 0 is a real consuming region")
