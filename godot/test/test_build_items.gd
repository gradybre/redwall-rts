extends "res://test/framework/test_case.gd"
## The pending ways down (decision 1912's proof of concept): rows, Undo's live flag, where they land, clashes.

const Items := preload("res://scripts/ui/build_items.gd")

var _items: Items = null


func before_each() -> void:
	"""No ways down."""
	_items = Items.new()


func test_a_way_down_lands_on_the_level_below_its_two_by_two() -> void:
	"""Its footprint is canonical; it lands on the next level only, and only while live."""
	assert_equal(Items.footprint(Vector2i(3, 4)), PackedInt32Array([3, 4, 4, 4, 3, 5, 4, 5]), "canonical 2 × 2")
	var row: int = _items.add(0, Vector2i(3, 4))
	assert_equal(_items.landings(1), Items.footprint(Vector2i(3, 4)), "on level 1")
	assert_true(_items.landings(2).is_empty() and _items.landings(0).is_empty(), "nowhere else")
	_items.set_live(row, false)
	assert_true(_items.landings(1).is_empty(), "undone: lands nowhere")
	assert_equal(_items.live_count(), 0, "none live")
	assert_equal(_items.count(), 1, "the row kept for Redo")
	_items.set_live(row, true)
	assert_true(_items.is_live(row) and not _items.is_live(5) and not _items.is_live(-1), "live again; no other rows")


func test_names_levels_cells_and_clashes() -> void:
	"""The Entrance on the surface, a Way down below; two on overlapping cells of one level clash, not on two levels."""
	assert_equal(Items.name_of(0), "Entrance", "the surface's")
	assert_equal(Items.name_of(2), "Way down", "below")
	_items.add(1, Vector2i(10, 10))
	assert_equal(_items.level_of(0), 1, "its level")
	assert_equal(_items.cell_of(0), Vector2i(10, 10), "its cell")
	assert_equal(_items.clashes(1, Vector2i(11, 11)), 0, "overlapping on level 1")
	assert_equal(_items.clashes(1, Vector2i(12, 10)), -1, "beside it")
	assert_equal(_items.clashes(2, Vector2i(10, 10)), -1, "a level down")
	_items.clear()
	assert_equal(_items.count(), 0, "cleared")
