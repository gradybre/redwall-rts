extends "res://test/framework/test_case.gd"
## The map layers and their picker (decision 0292, the review's F47 and UX-009): one layer at a time,
## picked directly or stepped by V, the Underground layer following U's own switch, the picker naming the
## shown layer with its question, subject and legend, a mixed group's water range per member (never the
## first selected alone), and the picker's place clear of the minimap, the news band, the command strip
## and the party panel's column at 1280x720 and 1920x1080.
##
## No scene tree and no staged assets: the picker is built off-tree; the farm and the water's play are the
## placeholder village's (as test_demo_farm_ui.gd and test_demo_water_play.gd build them).

const LensesScript := preload("res://demo/map_lenses.gd")
const SubjectScript := preload("res://demo/lens_subject.gd")
const PickerScript := preload("res://demo/ui/demo_lens_picker.gd")
const WaterRangeScript := preload("res://demo/waterplay/water_range.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ViewScript := preload("res://demo/farm/farm_view.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PartyScript := preload("res://demo/control/demo_party_panel.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const MOUSE_U: int = 1024
const OTTER_U: int = 1126
const BADGER_U: int = 2611
## The tallest picker card measured in the tree at 1920x1080 (the code review's measurement: a six-member
## group's Water range).
const TALLEST_CARD_H: float = 234.0

var _nodes: Array[Node] = []
## What each test lens was told, in order: "<lens>:on" / "<lens>:off".
var _said: PackedStringArray = PackedStringArray()
var _under_on: bool = false


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_said.clear()
	_under_on = false


func _show(on: bool, lens: String) -> void:
	"""A test lens's switch: remembers what it was told."""
	_said.append("%s:%s" % [lens, "on" if on else "off"])


func _show_under(on: bool) -> void:
	"""The test Underground's switch (its own state, like U's view)."""
	_under_on = on
	_said.append("under:%s" % ("on" if on else "off"))


func _lenses() -> LensesScript:
	"""Moisture, ripeness, water and woods on V's cycle, and an Underground followed by its own switch."""
	var lenses := LensesScript.new()
	lenses.add("Growing", "Soil moisture", "Which beds are too dry or too wet?", _show.bind("moisture"))
	lenses.add("Growing", "Ripeness", "Which beds are ready to harvest?", _show.bind("ripeness"))
	lenses.add("Getting there", "Water range", "Where can they wade, swim, dive or cross?", _show.bind("water"))
	lenses.add("Woods", "Zones and trees", "Which trees may be felled, which must stay?", _show.bind("woods"))
	var under: int = lenses.add("Underground", "Tunnels", "What lies under the village?", _show_under)
	lenses.follow_state(under, func() -> bool: return _under_on)
	lenses.set_legend(3, PackedColorArray([Color.YELLOW, Color(0, 0, 0, 0)]), PackedStringArray(["wade", "words only"]))
	return lenses


func _picker(lenses: LensesScript) -> PickerScript:
	"""The picker over `lenses`, off-tree."""
	var picker := PickerScript.new()
	_nodes.append(picker)
	picker.configure(lenses)
	return picker


# --- one at a time -------------------------------------------------------------------------------

func test_a_layer_is_shown_alone() -> void:
	"""Selecting a layer switches every other off first, then it on; OFF switches all off."""
	var lenses := _lenses()
	assert_equal(lenses.select(3), 3, "water")
	assert_equal(_said, PackedStringArray(["moisture:off", "ripeness:off", "woods:off", "under:off", "water:on"]), "the rest off, then it")
	_said.clear()
	lenses.turn_off()
	assert_equal(lenses.active, LensesScript.OFF, "off")
	assert_equal(_said, PackedStringArray(["moisture:off", "ripeness:off", "water:off", "woods:off", "under:off"]), "all off")
	assert_equal(lenses.select(99), LensesScript.OFF, "no such layer: off")
	assert_equal(lenses.select(-1), LensesScript.OFF, "nor this")


func test_v_steps_the_cycle_and_skips_the_followed_layer() -> void:
	"""off -> moisture -> ripeness -> water -> woods -> off: Underground is U's, not V's."""
	var lenses := _lenses()
	var seen := PackedInt32Array()
	for press: int in 6:
		seen.append(lenses.cycle())
	assert_equal(seen, PackedInt32Array([1, 2, 3, 4, 0, 1]), "the cycle")
	assert_false(lenses.is_on_cycle(5), "Underground is off V's cycle")
	assert_equal(lenses.title_of(3), "Getting there: Water range", "titled by its group")
	assert_equal(lenses.title_of(LensesScript.OFF), "Off", "off")


func test_the_underground_layer_follows_its_own_switch() -> void:
	"""U pressed (its switch on): sync makes it the shown layer and turns the shown one off; V from it goes
	to the first cycle layer and switches it off; U pressed again with it shown leaves none."""
	var lenses := _lenses()
	lenses.select(3)
	assert_false(lenses.sync(), "U off and not shown: nothing to adopt")
	assert_equal(lenses.active, 3, "the water stays")
	_said.clear()
	_under_on = true
	assert_true(lenses.sync(), "adopted")
	assert_equal(lenses.active, 5, "Underground shown")
	assert_true(_said.has("water:off"), "the water switched off")
	assert_false(lenses.sync(), "nothing more to adopt")
	assert_equal(lenses.cycle(), 1, "V: the first cycle layer")
	assert_false(_under_on, "and the underground view switched off")
	_under_on = true
	lenses.sync()
	_under_on = false
	assert_true(lenses.sync(), "U again")
	assert_equal(lenses.active, LensesScript.OFF, "none shown")


# --- the picker ---------------------------------------------------------------------------------

func test_the_picker_shows_each_layer_by_its_question_and_turns_off() -> void:
	"""Each list button shows its layer alone, its question and legend on the card; the shown one again,
	or Off, shows none."""
	var lenses := _lenses()
	var picker := _picker(lenses)
	assert_equal(picker.title_text(), "Map layer: off", "off at first")
	assert_false(picker.card_shown(), "no card")
	assert_true(picker.off_button().disabled, "Off has nothing to turn off")
	for lens: int in range(1, lenses.count()):
		picker.lens_button(lens).pressed.emit()
		assert_equal(lenses.active, lens, "%s shown" % lenses.title_of(lens))
		assert_equal(picker.title_text(), lenses.title_of(lens), "named")
		assert_equal(picker.question_text(), lenses.question_of(lens), "its one question")
		assert_true(picker.lens_button(lens).button_pressed, "its button pressed")
		assert_true(picker.legend_shown(lens), "its legend")
		for other: int in range(1, lenses.count()):
			if other != lens:
				assert_false(picker.legend_shown(other) or picker.lens_button(other).button_pressed, "%d alone" % other)
	assert_equal(picker.legend_words(3), PackedStringArray(["wade", "words only"]), "the water's legend words")
	picker.lens_button(5).pressed.emit()
	assert_equal(lenses.active, LensesScript.OFF, "the shown layer again: off")
	picker.lens_button(2).pressed.emit()
	picker.off_button().pressed.emit()
	assert_equal(lenses.active, LensesScript.OFF, "Off")
	assert_equal(picker.title_text(), "Map layer: off", "named off")


func test_the_list_unfolds_and_folds_on_a_pick() -> void:
	"""The header button unfolds the list; a pick folds it; the card shows only while it is folded."""
	var lenses := _lenses()
	var picker := _picker(lenses)
	assert_false(picker.list_shown(), "folded at first")
	picker.toggle_list()
	assert_true(picker.list_shown(), "unfolded")
	picker.lens_button(1).pressed.emit()
	assert_false(picker.list_shown(), "folded by the pick")
	assert_true(picker.card_shown(), "the card")
	picker.toggle_list()
	assert_false(picker.card_shown(), "the list in its place")


func test_v_and_the_picker_name_the_same_layer() -> void:
	"""The farm's V steps the picker's layer: after a pick, V goes on from it, and the picker names it."""
	var farm := _farm()
	farm.add_overlay("Getting there", "Water range", "Where?", _show.bind("water"))
	var picker := _picker(farm.lenses)
	picker.lens_button(2).pressed.emit()
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_RIPENESS, "the picker's ripeness")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_V
	assert_true(farm.handle_key(key), "V")
	picker.refresh()
	assert_equal(picker.title_text(), "Getting there: Water range", "V went on from the pick")
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_OFF, "the beds' overlay off")
	assert_true(picker.lens_button(3).button_pressed and not picker.lens_button(2).button_pressed, "the list agrees")
	farm.handle_key(key)
	picker.refresh()
	assert_equal(picker.title_text(), "Map layer: off", "V to off")
	picker.lens_button(1).pressed.emit()
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_MOISTURE, "picked moisture")
	assert_equal(farm.cycle_overlays(), "Growing: Ripeness", "V from the pick")


func test_the_farm_s_two_layers_share_the_beds_overlay() -> void:
	"""Moisture then ripeness then moisture: each shows (the others are switched off before it is on)."""
	var farm := _farm()
	farm.lenses.select(2)
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_RIPENESS, "ripeness")
	farm.lenses.select(1)
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_MOISTURE, "moisture")
	farm.lenses.select(2)
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_RIPENESS, "ripeness again: moisture's off came first")
	farm.lenses.turn_off()
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_OFF, "off")


func test_the_picker_shows_the_subject_and_steps_a_group() -> void:
	"""A layer with a subject: its line, notes and the ◀ ▶ stepper for a group; without one, none."""
	var lenses := _lenses()
	var range_of := _range()
	lenses.set_subject(3, range_of)
	var picker := _picker(lenses)
	picker.lens_button(1).pressed.emit()
	assert_equal(picker.subject_text(), "", "moisture has no subject")
	assert_false(picker.subject_shown() or picker.notes_shown(), "no subject line, no notes")
	assert_false(picker.stepper_shown(), "no stepper")
	picker.lens_button(3).pressed.emit()
	assert_equal(picker.subject_text(), "Water range for: a 1.0 m mouse (nobody selected)", "nobody")
	range_of.follow(PackedInt32Array([1]))
	picker.refresh()
	assert_equal(picker.subject_text(), "Water range for: Otter fisher", "one")
	assert_false(picker.stepper_shown(), "one: nothing to step")
	range_of.follow(PackedInt32Array([0, 1, 2]))
	picker.refresh()
	assert_equal(picker.subject_text(), "Water range for: all 3 selected", "the group")
	assert_true(picker.stepper_shown(), "the stepper")
	assert_equal(picker.notes_text(), "All of them wade the yellow. Swim: all but Badger quarryman. Dive: Otter fisher.", "who does what")
	picker.step_subject(1)
	assert_equal(picker.subject_text(), "Water range for: Mouse keeper (1 of 3 selected)", "stepped to the first")
	picker.step_subject(-1)
	assert_equal(picker.subject_text(), "Water range for: all 3 selected", "back to the group")


# --- whose water range ---------------------------------------------------------------------------

func _range() -> WaterRangeScript:
	"""A water range over three residents: a 1.00 m mouse, a 1.10 m otter (dives), a 2.55 m badger (wades
	only)."""
	var state := StateScript.new()
	state.setup(PackedStringArray(["mouse", "otter", "badger"]), PackedInt32Array([MOUSE_U, OTTER_U, BADGER_U]))
	var names: PackedStringArray = ["Mouse keeper", "Otter fisher", "Badger quarryman"]
	var range_of := WaterRangeScript.new()
	range_of.configure(state, func(who: int) -> String: return names[who])
	return range_of


func test_a_group_is_painted_for_all_of_it_not_its_first_member() -> void:
	"""Badger first in the selection, mouse second: the group's zones are the mouse's (what every one
	wades), and the lens says it is the group."""
	var range_of := _range()
	range_of.follow(PackedInt32Array([2, 0]))
	assert_equal(range_of.painted_who(), 0, "the shortest, not the first selected")
	assert_equal(range_of.paint_height_u(), MOUSE_U, "the mouse's height")
	assert_equal(range_of.paint_label(), "all 2 selected, by the shortest: Mouse keeper (1.00 m)", "the overlay's legend")
	assert_equal(range_of.subject_line(), "Water range for: all 2 selected", "the group named")
	assert_equal(range_of.notes(), "All of them wade the yellow. Swim: Mouse keeper. Dive: none.", "per member")


func test_each_member_of_a_group_can_be_evaluated() -> void:
	"""▶ steps the group -> each member in cast order -> the group; each member painted at its own height
	with its own range; ◀ goes back."""
	var range_of := _range()
	range_of.follow(PackedInt32Array([0, 1, 2]))
	var heights := PackedInt32Array()
	var lines := PackedStringArray()
	for press: int in 4:
		range_of.step(1)
		heights.append(range_of.paint_height_u())
		lines.append(range_of.notes())
	assert_equal(heights, PackedInt32Array([MOUSE_U, OTTER_U, BADGER_U, MOUSE_U]), "each, then the group")
	range_of.step(1)
	assert_equal(range_of.paint_label(), "Mouse keeper (1.00 m)", "a member stepped to is named alone")
	range_of.step(-1)
	assert_equal(lines[0], "Wades to 0.25 m · swims · does not dive", "the mouse")
	assert_equal(lines[1], "Wades to 0.27 m · swims · dives", "the otter")
	assert_equal(lines[2], "Wades to 0.64 m · cannot swim · does not dive", "the badger")
	assert_true(lines[3].begins_with("All of them"), "the group again")
	range_of.step(-1)
	assert_equal(range_of.subject_line(), "Water range for: Badger quarryman (3 of 3 selected)", "◀ from the group: the last")


func test_the_subject_follows_the_selection() -> void:
	"""The same selection keeps the member stepped to; a new one goes back to the group; nobody: the mouse
	anchor; one: that resident, nothing to step."""
	var range_of := _range()
	assert_false(range_of.follow(PackedInt32Array()), "nobody, as it was")
	assert_equal(range_of.paint_height_u(), WaterRules.MOUSE_HEIGHT_U, "the mouse anchor")
	assert_equal(range_of.notes(), "Select residents to see their own range.", "asks")
	assert_true(range_of.follow(PackedInt32Array([1, 2])), "a group")
	range_of.step(1)
	var revision: int = range_of.revision
	assert_false(range_of.follow(PackedInt32Array([1, 2])), "the same group")
	assert_equal(range_of.focus, 0, "the member kept")
	assert_equal(range_of.revision, revision, "nothing to repaint")
	assert_true(range_of.follow(PackedInt32Array([0, 2])), "another group")
	assert_equal(range_of.focus, WaterRangeScript.GROUP, "back to the whole group")
	range_of.follow(PackedInt32Array([2]))
	assert_false(range_of.can_step(), "one: nothing to step")
	range_of.step(1)
	assert_equal(range_of.focus, WaterRangeScript.GROUP, "a step does nothing")
	assert_equal(range_of.paint_label(), "Badger quarryman (2.55 m)", "named with its height")
	assert_equal(range_of.notes(), "Wades to 0.64 m · cannot swim · does not dive", "its own range")


func test_who_swims_names_the_smaller_side() -> void:
	"""'all', 'none', the swimmers by name, or 'all but' the few who cannot."""
	var range_of := _range()
	range_of.follow(PackedInt32Array([0, 1]))
	assert_equal(range_of.notes(), "All of them wade the yellow. Swim: all. Dive: Otter fisher.", "both swim")
	range_of.follow(PackedInt32Array([1, 2]))
	assert_equal(range_of.notes(), "All of them wade the yellow. Swim: Otter fisher. Dive: Otter fisher.", "one of two: by name")


func test_the_water_paints_the_group_s_range_not_the_first_selected() -> void:
	"""demo_waterplay.gd: with a tall resident selected first and a short one second, the water's zones are
	painted for the short one (the group's), and stepping to the first repaints for it."""
	var rig: Dictionary = _water_rig()
	var play: WaterplayScript = rig["play"]
	var command: CommandScript = rig["command"]
	var water: DemoWaterScript = rig["water"]
	play.state.height_u[0] = BADGER_U
	play.state.height_u[1] = MOUSE_U
	command.select(PackedInt32Array([0, 1]))
	play._follow_selection()
	assert_equal(water.overlay().body_height_u, MOUSE_U, "the group's: every one wades the yellow")
	play.water_range.step(1)
	play._follow_selection()
	assert_equal(water.overlay().body_height_u, BADGER_U, "stepped to the first member: its own")
	command.select(PackedInt32Array())
	play._follow_selection()
	assert_equal(water.overlay().body_height_u, WaterRules.MOUSE_HEIGHT_U, "nobody: the mouse anchor")


func _water_rig() -> Dictionary:
	"""The placeholder cast on the real layout (walking the village square: the water's play is wired over
	it, links and all, but nobody walks here), the water node, a command layer and the water's play."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var water := DemoWaterScript.new()
	_nodes.append(water)
	water.build({"world": {}, "cast": {}}, world)
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(water.map(), circles)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	var services := ServicesScript.new()
	command.configure(cast, camera, null, services)
	var play := WaterplayScript.new()
	_nodes.append(play)
	play.configure(cast, command, null, services, water.map(), links, water)
	return {"play": play, "command": command, "water": water}


# --- where the picker goes ------------------------------------------------------------------------

func test_the_picker_keeps_clear_of_the_hud_at_both_sizes() -> void:
	"""At 1280x720 and 1920x1080, journal open or closed: the picker's whole slot -- all the room it may grow
	into, frame included -- is inside the view and clear of the minimap, the news band, the command strip and
	the party panel's column, and is at least TALLEST_CARD_H tall (the tallest card measured, 234 px: a
	six-member group's water range) and WIDTH wide."""
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for journal: bool in [false, true]:
			var layout := UiLayout.new()
			var geometry := UiLayout.Geometry.new()
			var band: Rect2 = NewsScript.band_placement(size.x, size.y, layout, geometry, journal)
			var slot: Rect2 = PickerScript.slot_rect(geometry, band)
			var drawn: Rect2 = slot.grow(PickerScript.FRAME_EXPAND)
			var party := PartyScript.placement(size.x, size.y, layout, UiLayout.Geometry.new()).grow(PartyScript.FRAME_EXPAND)
			var at: String = "%dx%d journal %s" % [size.x, size.y, journal]
			assert_true(Rect2(0, 0, geometry.logical_width, geometry.logical_height).encloses(drawn), "%s: inside" % at)
			for other: Rect2 in [geometry.minimap, geometry.commands, band, party]:
				assert_false(drawn.intersects(other), "%s: %s clear of %s" % [at, drawn, other])
			assert_true(slot.size.x >= PickerScript.WIDTH, "%s: at least its width" % at)
			assert_true(slot.size.y >= TALLEST_CARD_H, "%s: room for the tallest card (%.0f)" % [at, slot.size.y])


func test_the_slot_sits_on_the_command_strip_where_it_has_room() -> void:
	"""1920x1080: down on the command strip, right of the party column; 1280x720: above the bottom band."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	var band: Rect2 = NewsScript.band_placement(1920, 1080, layout, geometry, false)
	var slot: Rect2 = PickerScript.slot_rect(geometry, band)
	var column: float = UiLayout.SAFE_INSET + 2.0 * PartyScript.FRAME_EXPAND + PartyScript.WIDTH
	assert_equal(slot.position.x, column + PickerScript.GAP + PickerScript.FRAME_EXPAND, "right of the party column")
	assert_equal(slot.end.y, geometry.commands.position.y - PickerScript.GAP - PickerScript.FRAME_EXPAND, "on the command strip")
	assert_equal(slot.size.x, band.position.x - PickerScript.GAP - PickerScript.FRAME_EXPAND - slot.position.x, "up to the news band")
	band = NewsScript.band_placement(1280, 720, layout, geometry, false)
	slot = PickerScript.slot_rect(geometry, band)
	assert_equal(slot.end.y, geometry.minimap.position.y - PickerScript.GAP - PickerScript.FRAME_EXPAND, "above the bottom band")
	assert_equal(slot.size.x, PickerScript.WIDTH, "its own width")
	slot = PickerScript.slot_rect(geometry, Rect2())
	assert_equal(slot.size.x, PickerScript.MAX_WIDTH, "no news strip: as wide as it may be")


func test_the_picker_follows_the_journal_without_touching_the_news_strip() -> void:
	"""At 1920x1080 the picker sits on the command strip with the journal closed and above the bottom band
	with it open -- it asks the journal itself and works the band out from the strip's static equation, so
	the strip's own journal state is left for the strip to follow (writing it once made the strip miss a
	journal opening)."""
	var open: Array[bool] = [false]
	var query := func() -> bool: return open[0]
	var news := NewsScript.new()
	_nodes.append(news)
	news.configure(ServicesScript.new().notices)
	news.follow_journal(query)
	var picker := PickerScript.new()
	_nodes.append(picker)
	picker.configure(_lenses(), query)
	var closed: Rect2 = picker.slot_for(Vector2(1920.0, 1080.0))
	open[0] = true
	var opened: Rect2 = picker.slot_for(Vector2(1920.0, 1080.0))
	assert_equal(closed.end.y, 978.0, "closed: on the command strip (996 less the gap and the frame)")
	assert_equal(opened.end.y, 758.0, "open: above the bottom band (776 less the gap and the frame)")
	assert_false(news.journal_followed(), "the strip's journal state untouched")
	news.band_in(Vector2(1920.0, 1080.0))
	assert_true(news.journal_followed(), "for the strip to follow itself")


func _farm() -> DemoFarmScript:
	"""The farm over the placeholder village, off-tree, with a command layer and no HUD."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var services := ServicesScript.new()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null, services)
	var farm := DemoFarmScript.new()
	_nodes.append(farm)
	var providers: Array[Callable] = []
	farm.configure({}, null, cast, command, camera, null, providers, services)
	return farm
