extends "res://test/framework/test_case.gd"
## UI-BUILD-012, the connector card, in the build panel off-tree (decision 2021; Brendan's rulings P-D1-3 (a), P-D1-4
## (a), P-D1-12 (a)): pinning a way opens it; Down / Up with the impossible one disabled and its reason; the result in
## words, "✓ Connects to ..." or why not, with the placeholder's notes; Add to plan (Shift keeps the way's card);
## Cancel and Escape; R turns the pinned way; its rectangle; and its words never depend on colour.

const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const ConnectorCard := preload("res://scripts/ui/build_connector_card.gd")

var _panel: BuildPanel = null
var _batch: Batch = null
var _added: Array = []


func before_each() -> void:
	"""A panel over a fresh batch, placed for 1280×720, open on the Surface."""
	var catalog: BuildCatalog = BuildCatalog.new()
	_batch = Batch.new()
	assert_equal(_batch.configure(catalog, Rect2i(0, 0, 128, 128), 4096), &"", "batch")
	_panel = BuildPanel.new()
	_panel.configure(_batch, catalog, Callable())
	_added.clear()
	_panel.way_added.connect(func(kind: int) -> void: _added.append(kind))
	_place(1280, 720, 100)
	_panel.open_on(0)


func after_each() -> void:
	"""Free the panel (its lambdas hold it)."""
	_panel.free()
	_panel = null


func _place(width: int, height: int, percent: int) -> UiLayout.Geometry:
	"""Place the panel for a viewport; the geometry."""
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	assert_true(UiLayout.new().compute_into(width, height, percent, false, geometry), "geometry")
	_panel.place(geometry)
	return geometry


func _choose(card_name: String) -> void:
	"""Choose the row's card named `card_name`."""
	var cards: Array[BuildCatalog.Card] = _panel.row_cards()
	for k: int in cards.size():
		if cards[k].name == card_name:
			_panel.choose_card(k)
			return
	assert_true(false, "no card %s" % card_name)


func test_pinning_a_way_opens_the_card_saying_where_it_leads() -> void:
	"""On the Surface a hatch goes down: "✓ Connects to Underground level 1", Up disabled with its reason, the
	placeholder's notes, Add to plan enabled."""
	assert_false(_panel.pin_way(Vector2i(10, 10)), "nothing armed: no pin")
	_choose("Hatch with ladder")
	assert_equal(_panel.armed_family(), Families.LADDER_HATCH, "the hatch armed")
	assert_true(_panel.pin_way(Vector2i(10, 10)), "pinned")
	var card: ConnectorCard = _panel.connector()
	assert_true(card.visible and _panel.pinned(), "the card open")
	assert_equal(card.title(), "Hatch with ladder", "named")
	assert_true(card.words().begins_with("✓ Connects to Underground level 1"), card.words())
	assert_true(card.toggle(true).disabled, "Up disabled on the Surface")
	assert_equal(card.toggle(true).tooltip_text, "X Not possible: No level above the surface", "with its reason")
	assert_true(card.words().contains("Up: X Not possible: No level above the surface"), "said on the card too")
	assert_true(card.toggle(false).button_pressed and not card.toggle(false).disabled, "Down chosen")
	assert_true(card.words().contains(Families.PLACEHOLDER), "placeholder")
	assert_true(card.words().contains(Families.CLIMBERS_ONLY), "climbers only (P-D1-8 (a))")
	assert_true(card.words().contains(Families.NOT_QUALIFIED), "proof of concept")
	assert_false(card.add_button().disabled, "Add to plan enabled")
	assert_equal(card.accessibility_name, "Connector card: Hatch with ladder; ✓ Connects to Underground level 1", "named")


func test_add_to_plan_puts_it_in_the_batch_and_shift_keeps_the_card() -> void:
	"""Add to plan places the pinned way (one step), closes the card and puts the way's card down; with Shift the
	way's card stays chosen for another."""
	_choose("Burrow mouth")
	_panel.pin_way(Vector2i(10, 10))
	assert_equal(_panel.add_pinned(true), Validity.KIND_CAN_BUILD, "added")
	assert_equal(_added, [Validity.KIND_CAN_BUILD], "said to the host")
	assert_false(_panel.pinned(), "the card closed")
	assert_true(_panel.way_down_armed(), "Shift: still armed")
	assert_equal(_batch.items().family_of(0), Families.RAMP, "a burrow mouth in the batch")
	_panel.pin_way(Vector2i(40, 10))
	_panel.connector().add_button().pressed.emit()
	assert_equal(_batch.items().live_count(), 2, "the button adds too")
	assert_false(_panel.way_down_armed(), "without Shift the card is put down")
	assert_equal(_panel.add_pinned(), -1, "nothing pinned: nothing added")


func test_an_impossible_way_is_x_on_the_card_and_never_added() -> void:
	"""A way running off the planning area: X in words, Add to plan disabled; forced, it is dropped, the card stays."""
	_choose("Burrow mouth")
	_panel.pin_way(Vector2i(10, 120))
	var card: ConnectorCard = _panel.connector()
	assert_true(card.words().begins_with(Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.outside())), card.words())
	assert_true(card.add_button().disabled, "Add to plan disabled")
	assert_equal(_panel.add_pinned(), Validity.KIND_NOT_POSSIBLE, "forced: dropped")
	assert_true(_panel.pinned(), "the card stays to say why")
	assert_equal(_batch.items().count(), 0, "nothing added")


func test_down_and_up_between_the_levels() -> void:
	"""On level 2 both directions are offered; Up stands it on level 1; on level 4 only Up, and it starts there."""
	_panel.set_level(2)
	_choose("Stair-head")
	_panel.pin_way(Vector2i(20, 20))
	assert_false(_panel.pinned_up(), "down by default")
	assert_equal(_panel.standing_level(), 2, "standing here")
	assert_true(_panel.set_way_up(true), "Up chosen")
	assert_equal(_panel.standing_level(), 1, "standing on the level above")
	assert_true(_panel.connector().words().contains("needs a passage under it"), _panel.connector().words())
	assert_true(_panel.connector().toggle(true).button_pressed, "Up pressed")
	_panel.set_level(4)
	_choose("Stair-head")
	_panel.pin_way(Vector2i(20, 20))
	assert_true(_panel.pinned_up(), "only up from level 4")
	assert_false(_panel.set_way_up(false), "Down refused")
	assert_true(_panel.connector().toggle(false).disabled, "and disabled")
	assert_equal(BuildPanel.direction_refusal(4, false), Validity.no_level_below(), "its reason")
	assert_equal(BuildPanel.direction_refusal(2, true), "", "up from 2 is fine")


func test_a_way_up_to_the_surface_connects_to_the_surface() -> void:
	"""From level 1, Up stands it on the Surface: "✓ Connects to Surface"."""
	_panel.set_level(1)
	_choose("Hatch with ladder")
	_panel.pin_way(Vector2i(20, 20))
	_panel.set_way_up(true)
	assert_true(_panel.connector().words().begins_with("✓ Connects to Surface"), _panel.connector().words())


func test_cancel_escape_and_a_level_change_close_the_card() -> void:
	"""Cancel closes it with nothing added; Escape closes it before anything else; changing level closes it."""
	_choose("Hatch with ladder")
	_panel.pin_way(Vector2i(10, 10))
	_panel.connector().cancel_button().pressed.emit()
	assert_false(_panel.pinned(), "Cancel")
	assert_equal(_batch.items().count(), 0, "nothing added")
	_panel.pin_way(Vector2i(10, 10))
	assert_true(_panel.escape(), "Escape taken")
	assert_false(_panel.pinned(), "the card closed first")
	assert_true(_panel.is_open(), "the panel stays open")
	_panel.pin_way(Vector2i(10, 10))
	_panel.set_level(1)
	assert_false(_panel.pinned(), "a level change closes it")
	assert_equal(_panel.connector_words(), "", "nothing said while closed")


func test_r_turns_the_pinned_way_and_the_card_follows() -> void:
	"""R turns the way; pinned, the card judges it again (a ramp turned east runs off the area's east edge)."""
	_choose("Burrow mouth")
	assert_equal(_panel.rotate_way(1), 1, "turned once")
	assert_equal(_panel.rotate_way(-2), 3, "Shift+R twice back")
	_panel.rotate_way(-3)
	_panel.pin_way(Vector2i(120, 10))
	assert_true(_panel.connector().words().begins_with("✓"), "turn 0 fits: %s" % _panel.connector().words())
	_panel.rotate_way(1)
	assert_true(_panel.connector().words().contains(Validity.outside()), "turned east it does not")


func test_the_card_stands_in_its_rectangle_and_in_narrow_replaces_the_cards() -> void:
	"""Placed by build_layout.gd `connector_rect`; in NARROW the card row is hidden while it is open."""
	_choose("Hatch with ladder")
	_panel.pin_way(Vector2i(10, 10))
	var geometry: UiLayout.Geometry = _place(1920, 1080, 100)
	var card: ConnectorCard = _panel.connector()
	assert_equal(Rect2(card.position, card.size), BuildLayout.connector_rect(geometry), "its rectangle")
	assert_true(card.add_button().position.y + card.add_button().size.y <= card.size.y, "its buttons inside it")
	geometry = _place(1280, 720, 150)
	assert_equal(geometry.profile, UiLayout.PROFILE_NARROW, "NARROW")
	_panel.pin_way(Vector2i(10, 10))
	assert_false((_panel.controls()[&"cards"] as Control).visible, "the card row gives way")
	_panel.cancel_pin()
	assert_true((_panel.controls()[&"cards"] as Control).visible, "and comes back")
