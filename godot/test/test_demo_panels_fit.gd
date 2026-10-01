extends "res://test/framework/test_case.gd"
## Review group F, "panels that stay usable on smaller screens" (decision 0391): the logic under the layout --
## the Water panel's pinned selection and folded roster, the crop picker kept current while open, the rows that
## select and centre, the bottom band's places at the narrow profile, the incident card's span, the input gate's
## covered stops, and the action cards' tooltips at the HUD's scale. The real Control rects, visibility and
## clipping on the real scene are test_demo_layout_live.gd's.

const WaterPanel := preload("res://demo/waterplay/water_panel.gd")
const WaterText := preload("res://demo/waterplay/waterplay_text.gd")
const PickRow := preload("res://demo/ui/demo_pick_row.gd")
const LensPicker := preload("res://demo/ui/demo_lens_picker.gd")
const NewsStrip := preload("res://demo/ui/demo_news_strip.gd")
const IncidentCards := preload("res://demo/ui/demo_incident_cards.gd")
const PartyPanel := preload("res://demo/control/demo_party_panel.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const VillageScript := preload("res://demo/demo_village.gd")
const TunnelPanel := preload("res://demo/tunnel/tunnel_panel.gd")
const ForestPanel := preload("res://demo/forestry/forest_panel.gd")

const BED_LOAM: int = 0
const PEA: int = 11
const WHEAT: int = 13
const SWIMMERS: String = "Mouse keeper (swims): on land · breath 100% · stamina 100%\nOtter fisher (dives): swimming · breath 80% · stamina 60%\nBadger quarryman (wades only): on land · breath 100% · stamina 100%"

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built, and put the interface scale and the tooltips' scale back."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	DemoUiScale.percent = UiLayout.USER_SCALE_100
	CardScript.scale_tooltips(1.0)


func _own(node: Node) -> Node:
	"""Keep `node` for after_each."""
	_nodes.append(node)
	return node


# --- F12: the Water panel ---------------------------------------------------------------------------

func _water() -> WaterPanel:
	"""A built Water panel showing three residents' swimming."""
	var panel := _own(WaterPanel.new()) as WaterPanel
	panel.build()
	panel.show_water("Stream flowing 0.40 m/s", "", "Swimmers — 1 in the water", SWIMMERS)
	return panel


func test_the_selected_resident_is_pinned_and_the_roster_folded() -> void:
	"""Selected residents' lines are pinned above the scroll, two at most then "n more selected"; the full roster
	starts folded and its rows are not shown (F12: healthy land residents never stand before an action)."""
	var panel := _water()
	assert_false(panel.roster_open(), "All residents starts folded")
	assert_equal(panel.roster_toggle().text, WaterPanel.ROSTER_SHOW % 3, "with its count")
	assert_equal(panel.picked_texts(), PackedStringArray(), "nobody selected: nothing pinned")
	panel.set_selected(PackedInt32Array([1]))
	assert_equal(panel.picked_texts(), PackedStringArray([SWIMMERS.split("\n")[1]]), "the otter's line, pinned")
	assert_false(panel.more_button().visible, "no more")
	panel.set_selected(PackedInt32Array([0, 1, 2]))
	assert_equal(panel.picked_texts().size(), WaterPanel.PINNED_MAX, "two pinned")
	assert_true(panel.more_button().visible, "and a way to the rest")
	assert_equal(panel.more_button().text, WaterPanel.MORE_SELECTED % 1, "says how many")
	panel.more_button().pressed.emit()
	assert_true(panel.roster_open(), "which opens All residents")
	panel.set_selected(PackedInt32Array())
	assert_false(panel.more_button().visible, "nothing selected: no more button")


func test_a_roster_row_picks_its_resident() -> void:
	"""All residents: a row per resident, each a 32 px row cut with an ellipsis and whole in its tooltip; pressing
	one emits its cast index; a changed line re-words its row in place."""
	var panel := _water()
	panel.toggle_roster()
	assert_true(panel.roster_open(), "unfolded")
	assert_equal(panel.roster_toggle().text, WaterPanel.ROSTER_HIDE % 3, "the toggle says so")
	var picked: Array[int] = []
	panel.resident_picked.connect(func(who: int) -> void: picked.append(who))
	panel.roster_row(2).pressed.emit()
	assert_equal(picked, [2] as Array[int], "the badger")
	var row: Button = panel.roster_row(1)
	assert_true(row.custom_minimum_size.y >= PickRow.ROW_H, "a 32 px target")
	assert_equal(row.tooltip_text, SWIMMERS.split("\n")[1], "whole in its tooltip")
	panel.show_water("", "", "", SWIMMERS.replace("breath 80%", "breath 40%"))
	assert_true(panel.roster_row(1).text.contains("breath 40%"), "re-worded in place")
	assert_true(panel.roster_row(1) == row, "the same row")
	assert_null(panel.roster_row(3), "no fourth row")
	panel.toggle_roster()
	assert_false(panel.roster_open(), "folded again")


func test_each_build_sits_under_its_kind_s_cost() -> void:
	"""The site's text is split: the span stays together, each kind's cost line goes over the Build buttons; the
	line as given is still readable whole (`line`)."""
	var panel := _water()
	var text: String = "3.4 m of water · 4.6 m of deck\n%s4.7 U planks, no piers\n%sone 6.0 U log" % [
		WaterText.PLANK_LINE, WaterText.LOG_LINE]
	panel.show_site("Bridge site 1 of 3", text, {})
	assert_equal(panel.line(&"site"), text, "the line as given")
	assert_equal((panel._lines[&"site"] as Label).text, "3.4 m of water · 4.6 m of deck", "the span alone")
	assert_equal((panel._lines[&"plank_cost"] as Label).text, WaterText.PLANK_LINE + "4.7 U planks, no piers", "plank")
	assert_equal((panel._lines[&"log_cost"] as Label).text, WaterText.LOG_LINE + "one 6.0 U log", "log")
	var builds: Node = panel.button(WaterPanel.ACTION_BUILD_PLANK).get_parent()
	assert_true(builds == panel.button(WaterPanel.ACTION_BUILD_LOG).get_parent(), "the two Builds share a row")
	assert_equal(builds.get_index(), (panel._lines[&"log_cost"] as Label).get_index() + 1, "right under the costs")
	panel.show_site("Bridge site 1 of 3", "Neck bridge: open", {})
	assert_false((panel._lines[&"plank_cost"] as Label).visible, "a standing bridge: no cost lines")


func test_water_text_and_targets_meet_the_floors() -> void:
	"""Every label at least 14 px and every button at least 32 px tall, each with a hover text (F12)."""
	var panel := _water()
	for node: Node in panel.find_children("*", "Label", true, false):
		assert_true((node as Label).get_theme_font_size(&"font_size") >= 14, "%s: 14 px" % node.name)
	for key: StringName in WaterPanel.BUTTON_TEXT:
		var b: Button = panel.button(key)
		assert_true(b.custom_minimum_size.y >= 32.0, "%s: 32 px" % key)
		assert_true(b.get_theme_font_size(&"font_size") >= 14, "%s: 14 px" % key)
		assert_false(b.tooltip_text.is_empty(), "%s: a hover text" % key)


# --- F36: the crop picker kept current --------------------------------------------------------------

func _picker_panel() -> Array:
	"""A bed panel over a fresh farm with its crew: [panel, sim]."""
	var world := _own(DemoWorldScript.new()) as DemoWorldScript
	var cast := _own(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), world.obstacles())
	var sim := SimScript.new()
	var crew := CrewScript.new()
	crew.configure(cast, sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast))), TunnelsScript.new(),
		DemoFarmScript.well_position(), func(_text: String) -> void: pass)
	var panel := _own(BedPanelScript.new()) as BedPanelScript
	panel.configure(sim, crew)
	return [panel, sim]


func test_the_open_picker_follows_the_calendar_across_spring_5() -> void:
	"""Open at Spring 1, the real calendar crosses into Spring 5 and the panel refreshes: wheat (sow in Spring 1-4)
	is disabled with its reason, peas -- out of window before -- are enabled, the title's date is today's; no row
	was rebuilt or moved (F36)."""
	var made: Array = _picker_panel()
	var panel: BedPanelScript = made[0]
	var sim: SimScript = made[1]
	panel.show_bed(BED_LOAM)
	panel.open_picker()
	assert_false(panel.picker_button(WHEAT).disabled, "wheat sowable on Spring 1")
	assert_true(panel.picker_button(PEA).disabled, "peas not yet")
	var title: String = panel.picker_title_text()
	assert_true(title.contains(sim.calendar.date_text()), "the title's date: %s" % title)
	var first_row: Node = panel._picker_rows.get_child(0)
	var pea_index: int = panel.picker_button(PEA).get_parent().get_index()
	var wheat_button: Button = panel.picker_button(WHEAT)
	sim.advance_usec(4 * 24 * CalendarScript.HOUR_USEC)
	panel.refresh()
	assert_true(panel.picker_button(WHEAT).disabled, "wheat out of its window now")
	assert_true(panel.picker_button(WHEAT).tooltip_text.contains(Text.pick_reason(sim, BED_LOAM, WHEAT)),
		"with the reason: %s" % panel.picker_button(WHEAT).tooltip_text)
	assert_true(panel.picker_detail(WHEAT).ends_with("can't: " + Text.pick_reason(sim, BED_LOAM, WHEAT)), "its line says why")
	assert_false(panel.picker_button(PEA).disabled, "peas sowable now")
	assert_false(panel.picker_detail(PEA).contains("can't"), "and their line no longer refuses")
	assert_equal(panel.picker_title_text(), panel.picker_title(), "the title")
	assert_true(panel.picker_title_text().contains(sim.calendar.date_text()), "today's date")
	assert_false(panel.picker_title_text() == title, "not the date it opened on")
	assert_true(panel._picker_rows.get_child(0) == first_row, "no row rebuilt")
	assert_equal(panel.picker_button(PEA).get_parent().get_index(), pea_index, "and none moved")
	assert_true(panel.picker_button(WHEAT) == wheat_button, "the same buttons (a focused one keeps its focus)")


func test_the_picker_has_one_scroll_and_a_fixed_title_and_back() -> void:
	"""The crop picker's list is in the panel's one scroll; its title is in the fixed head and Back in the fixed
	foot, shown only while picking (F12's nested-scroll paragraph)."""
	var made: Array = _picker_panel()
	var panel: BedPanelScript = made[0]
	panel.show_bed(BED_LOAM)
	assert_false(panel.back_button().is_visible_in_tree() or panel._foot.visible, "no Back while not picking")
	panel.open_picker()
	assert_equal(panel.find_children("*", "ScrollContainer", true, false).size(), 1, "one scroll owner")
	assert_true(panel.body().is_ancestor_of(panel.picker_button(WHEAT)), "the list scrolls")
	assert_false(panel.body().is_ancestor_of(panel.back_button()), "Back does not")
	assert_false(panel.body().is_ancestor_of(panel._picker_title), "nor the title")
	assert_true(panel._foot.visible and panel._picker_title.visible, "both shown while picking")
	panel.back_button().pressed.emit()
	assert_false(panel.picking, "Back closes the picker")
	assert_false(panel._foot.visible, "and hides itself")
	assert_equal(panel.picker_title_text(), "", "and the title")


func test_the_woods_and_tunnels_buttons_meet_the_floors() -> void:
	"""Every Woods and Tunnels button at least 32 px tall and 14 px type, shown or not (the tunnels' show only with a
	tunnel selected, which the live harness does not do)."""
	for panel: CanvasLayer in [_own(TunnelPanel.new()), _own(ForestPanel.new())] as Array[CanvasLayer]:
		panel.call(&"build")
		var buttons: Array[Node] = panel.find_children("*", "Button", true, false)
		assert_true(buttons.size() > 0, "%s has buttons" % panel.name)
		for node: Node in buttons:
			var b := node as Button
			assert_true(b.custom_minimum_size.y >= 32.0 or b.get_combined_minimum_size().y >= 32.0, "%s: 32 px" % b.text)
			assert_true(b.get_theme_font_size(&"font_size") >= 14, "%s: 14 px" % b.text)


func test_farm_small_text_is_at_least_14_px() -> void:
	"""The farm's small type and every farm button meet UI §2.1's 14 px and UX-T03's 32 px (F35's 13 px)."""
	assert_true(FarmUi.SMALL_PX >= 14, "small type: %d px" % FarmUi.SMALL_PX)
	var button := _own(FarmUi.button("Plant…")) as Button
	assert_true(button.custom_minimum_size.y >= 32.0, "a 32 px button")


# --- the rows that select and centre ------------------------------------------------------------------

func test_a_pick_row_is_a_32_px_focusable_row_with_its_whole_text() -> void:
	"""A row button: 32 px, keyboard focus with the ring, ellipsis-cut, the text whole in its tooltip, a chip when
	coloured; re-worded only when its words change."""
	var row := _own(PickRow.make("Mouse keeper — wandering", Color.RED, 14, Color.BLACK)) as Button
	assert_equal(row.custom_minimum_size.y, PickRow.ROW_H, "32 px")
	assert_equal(row.focus_mode, Control.FOCUS_ALL, "takes focus")
	assert_equal(row.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "ellipsis")
	assert_equal(row.tooltip_text, row.text, "whole in its tooltip")
	assert_not_null(row.get_node_or_null(^"Chip"), "a chip")
	var plain := _own(PickRow.make("x", Color(0, 0, 0, 0), 14, Color.BLACK)) as Button
	assert_null(plain.get_node_or_null(^"Chip"), "no chip when transparent")
	PickRow.set_text(row, "Mouse keeper — holding")
	assert_equal(row.tooltip_text, "Mouse keeper — holding", "re-worded")


func test_pick_member_selects_alone_and_centres() -> void:
	"""The command layer's pick_member: that resident alone, the camera's centre asked for at its feet; an index
	out of range does nothing."""
	var cast := _own(DemoCastScript.new()) as DemoCastScript
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera := _own(Camera3D.new()) as Camera3D
	var command := _own(CommandScript.new()) as CommandScript
	command.configure(cast, camera)
	var centred: Array[Vector3] = []
	command.set_centre(func(at: Vector3) -> void: centred.append(at))
	command.select(PackedInt32Array([0, 1, 2]))
	command.pick_member(2)
	assert_equal(command.selected(), PackedInt32Array([2]), "alone")
	var feet: Vector2 = cast.actor(2).brain.position
	assert_equal(centred, [Vector3(feet.x, 0.0, feet.y)] as Array[Vector3], "centred on it")
	command.pick_member(99)
	assert_equal(command.selected(), PackedInt32Array([2]), "out of range: unchanged")
	assert_equal(centred.size(), 1, "and not centred")
	command.panel().member_picked.emit(1)
	assert_equal(command.selected(), PackedInt32Array([1]), "the party panel's row reaches it")
	assert_true(command.panel().release_requested.is_connected(command.release_selection), "Release (R) is the R key's own")


# --- the bottom band and the card at the narrow profile ---------------------------------------------

func _geometry(width: int, height: int, percent: int) -> UiLayout.Geometry:
	"""The HUD's layout for a window at an interface scale."""
	var geometry := UiLayout.Geometry.new()
	assert_true(UiLayout.new().compute_into(width, height, percent, false, geometry), "laid out")
	return geometry


func _party_column(geometry: UiLayout.Geometry) -> Rect2:
	"""The party panel's column with its carved frame."""
	return Rect2(UiLayout.SAFE_INSET, geometry.management_top,
		PartyPanel.WIDTH + 2.0 * PartyPanel.FRAME_EXPAND, geometry.minimap.position.y - geometry.management_top)


func test_the_picker_and_news_band_keep_clear_of_the_right_column_at_every_offered_size() -> void:
	"""At 1280x720 and 1920x1080, at 100 / 125 / 150 % where offered, and at an effective 200 % (2560x1440 at
	150 %), the Map layer picker's slot and the news band stay clear of the right column, the minimap, the
	party column and each other; at 125 % on 1280x720 the news band takes the whole gap (decision 0391)."""
	var cases: Array = [[1280, 720, 100], [1280, 720, 125], [1920, 1080, 100], [1920, 1080, 125],
		[1920, 1080, 150], [2560, 1440, 150], [3840, 2160, 100], [1366, 768, 125], [1920, 1200, 150], [1440, 900, 125]]
	for c: Array in cases:
		var geometry := UiLayout.Geometry.new()
		DemoUiScale.percent = c[2]
		var band: Rect2 = NewsStrip.band_placement(c[0], c[1], UiLayout.new(), geometry)
		var slot: Rect2 = LensPicker.slot_rect(geometry, band).grow(LensPicker.FRAME_EXPAND)
		var at: String = "%dx%d@%d" % c
		var detail := Rect2(geometry.detail.position, Vector2(geometry.detail.size.x, geometry.commands.position.y))
		assert_false(slot.intersects(detail), "%s: picker clear of the right column" % at)
		assert_false(slot.intersects(geometry.minimap), "%s: and the minimap" % at)
		assert_false(slot.intersects(_party_column(geometry)), "%s: and the party column" % at)
		assert_true(slot.size.x >= LensPicker.MIN_WIDTH, "%s: at least its least width" % at)
		assert_false(band.intersects(detail), "%s: news band clear of the right column" % at)
		assert_false(slot.intersects(band), "%s: picker and news band apart" % at)
		assert_true(band.size.x >= NewsStrip.MIN_W, "%s: a readable band (%.0f)" % [at, band.size.x])
	DemoUiScale.percent = 125
	var narrow := UiLayout.Geometry.new()
	var gap: Rect2 = NewsStrip.band_placement(1280, 720, UiLayout.new(), narrow)
	assert_equal(gap.position.x, narrow.minimap.end.x + NewsStrip.GAP, "the narrow band starts by the minimap")


func test_the_picker_falls_back_beside_the_minimap_where_the_column_gap_is_too_narrow() -> void:
	"""At 150 % on 1280x720 (not offered, but a resize may pass through it) there is no room right of the party
	column: the picker goes right of the minimap, still clear of the right column."""
	DemoUiScale.percent = 150
	var geometry := _geometry(1280, 720, 150)
	var slot: Rect2 = LensPicker.slot_rect(geometry, Rect2())
	assert_equal(slot.position.x, geometry.minimap.end.x + LensPicker.GAP + LensPicker.FRAME_EXPAND, "beside the minimap")
	assert_true(slot.end.x <= geometry.detail.position.x - LensPicker.GAP, "short of the right column")


func test_the_incident_card_stays_between_the_side_columns() -> void:
	"""The card is WIDTH centred on the alerts at 1280x720 and 1920x1080; at 125 % on 1280x720 (the narrow profile)
	it is narrowed to the gap between the party column and the right column."""
	for c: Array in [[1280, 720, 100], [1920, 1080, 100], [1920, 1080, 150]]:
		var geometry := _geometry(c[0], c[1], c[2])
		assert_equal(IncidentCards.card_span(geometry).size.x, IncidentCards.WIDTH, "%dx%d@%d: its own width" % c)
	var narrow := _geometry(1280, 720, 125)
	var span: Rect2 = IncidentCards.card_span(narrow)
	assert_true(span.size.x < IncidentCards.WIDTH, "narrowed")
	assert_true(span.position.x >= _party_column(narrow).end.x, "right of the party column")
	assert_true(span.end.x <= narrow.detail.position.x, "left of the right column")


# --- the input gate's covered stops -------------------------------------------------------------------

func _stop(region: Control, at: Vector2) -> Button:
	"""A 40 x 32 focusable button in `region` at `at`."""
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.position = at
	button.size = Vector2(40, 32)
	region.add_child(button)
	return button


func test_a_control_under_the_cover_is_no_focus_stop() -> void:
	"""With a cover over part of a region, its covered buttons drop out of the ring and Enter on one already
	focused is not pressed but goes on (G's open item, decision 0391); without a cover nothing changes."""
	var gate := _own(GateScript.new()) as GateScript
	var region := _own(Control.new()) as Control
	var open: Button = _stop(region, Vector2.ZERO)
	var hidden: Button = _stop(region, Vector2(100, 0))
	gate.add_region("test", [region] as Array[Node])
	assert_equal(gate.region_controls(0).size(), 2, "no cover: both")
	assert_false(gate.covered(hidden), "nothing covers it")
	var cover: Array[Rect2] = [Rect2(90, 0, 60, 60)]
	gate.occlude_with(func() -> Rect2: return cover[0])
	assert_equal(GateScript.screen_rect(hidden), Rect2(100, 0, 40, 32), "its rect on screen")
	assert_true(gate.covered(hidden), "under the cover")
	cover[0] = Rect2(120, 0, 60, 60)
	assert_true(gate.covered(hidden), "half under it is covered too")
	assert_equal(gate.region_controls(0), [open] as Array[Control], "and no stop")
	cover[0] = Rect2(90, 0, 60, 60)
	assert_false(gate.covered(open), "the other is not")
	assert_equal(gate.region_controls(0), [open] as Array[Control], "the covered one is no stop")
	var focus := GateScript.Focus.new()
	focus.control = hidden
	focus.keyboard = true
	focus.button = true
	focus.in_region = true
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	assert_equal(gate.route(enter, focus), GateScript.ROUTE_DROP_FOCUS, "Enter on a covered button: not pressed")
	focus.control = open
	assert_equal(gate.route(enter, focus), GateScript.ROUTE_PRESS, "on an open one: pressed")
	cover[0] = Rect2()
	assert_false(gate.covered(hidden), "the cover gone: open again")
	assert_equal(gate.region_controls(0).size(), 2, "both stops again")


# --- F35: the tooltips at the HUD's scale ---------------------------------------------------------------

func test_the_card_tooltips_follow_the_hud_scale() -> void:
	"""The card tooltip's type and margins at the effective scale: 15 px at S=1, 23 at 1.5, 30 at 2; the
	effective scale is the HUD's own (base x interface scale)."""
	var theme: Theme = CardScript.tooltip_theme()
	CardScript.scale_tooltips(1.5)
	assert_equal(theme.get_font_size(&"font_size", &"TooltipLabel"), 23, "at 1.5")
	CardScript.scale_tooltips(2.0)
	assert_equal(theme.get_font_size(&"font_size", &"TooltipLabel"), 30, "at 2")
	assert_almost_equal(theme.get_stylebox(&"panel", &"TooltipPanel").content_margin_left, CardScript.TIP_MARGINS[0] * 2.0,
		"its margins too")
	CardScript.scale_tooltips(1.0)
	assert_equal(theme.get_font_size(&"font_size", &"TooltipLabel"), CardScript.TIP_PX, "back at 1")
	DemoUiScale.percent = 150
	assert_almost_equal(DemoUiScale.effective_scale(Vector2(1920, 1080)), 1.5, "1080p at 150 %")
	assert_almost_equal(DemoUiScale.effective_scale(Vector2(2560, 1440)), 2.0, "1440p at 150 %: 200 %")
	DemoUiScale.percent = 100
	assert_almost_equal(DemoUiScale.effective_scale(Vector2(3840, 2160)), 2.0, "4K at 100 %: 200 %")
	assert_almost_equal(DemoUiScale.effective_scale(Vector2(800, 600)), 1.0, "below the floor: the floor's")


func test_a_scale_is_offered_only_where_the_bottom_band_has_room() -> void:
	"""The menu's rule (demo_village.gd MIN_LOGICAL_HEIGHT and MIN_LOGICAL_WIDTH): 125 % at 1280x720 and every scale
	at 1920x1080; never 150 % at 1280x720, 1440x900 or 1280x1024, where the picker and the news strip would share one
	gap (the code review's cases)."""
	var h: float = VillageScript.MIN_LOGICAL_HEIGHT
	var w: float = VillageScript.MIN_LOGICAL_WIDTH
	assert_true(DemoUiScale.fits(1280, 720, 125, h, w), "1280x720 at 125 %")
	assert_false(DemoUiScale.fits(1280, 720, 150, h, w), "not 150 %")
	assert_true(DemoUiScale.fits(1920, 1080, 150, h, w), "1920x1080 at 150 %")
	assert_false(DemoUiScale.fits(1440, 900, 150, h, w), "1440x900 at 150 %: too narrow")
	assert_false(DemoUiScale.fits(1280, 1024, 150, h, w), "1280x1024 at 150 %: too narrow")
	assert_true(DemoUiScale.fits(1440, 900, 125, h, w), "1440x900 at 125 %")
	assert_true(DemoUiScale.fits(1366, 768, 125, h, w), "1366x768 at 125 %")
	assert_false(DemoUiScale.fits(1366, 768, 150, h, w), "1366x768 at 150 %: too short")
	assert_false(DemoUiScale.fits(1920, 720, 150, h, w), "1920x720 at 150 %: wide enough, too short")


func test_a_reveal_works_in_the_scroll_s_own_pixels() -> void:
	"""Under a frame drawn at 1.5, `offset_in` sums the content's own positions (not the drawn ones), and a control
	outside the scroll is -1."""
	var frame := _own(Control.new()) as Control
	frame.scale = Vector2(1.5, 1.5)
	var scroll := DemoScroll.new()
	frame.add_child(scroll)
	var content := VBoxContainer.new()
	scroll.add_child(content)
	var group := Control.new()
	group.position = Vector2(0, 300)
	content.add_child(group)
	var row := Button.new()
	row.position = Vector2(0, 100)
	group.add_child(row)
	assert_equal(scroll.offset_in(row), 400.0, "300 + 100, unscaled")
	assert_equal(scroll.offset_in(frame), -1.0, "not inside")
	assert_equal(scroll.follow_focus, false, "the engine's focus following is off (it is wrong at S != 1)")


func test_the_party_rows_are_a_pool_re_worded_in_place() -> void:
	"""A group re-shown -- other members, other order -- keeps the same row buttons (a click, focus or tooltip on one
	survives the refresh); a row presses for whoever it lists now; one resident's lines are a pool too."""
	var panel := _own(PartyPanel.new()) as PartyPanel
	panel.build()
	var three: Array[Dictionary] = []
	for i: int in 3:
		three.append({"index": 10 + i, "name": "R%d" % i, "state": "holding"})
	panel.show_party(three)
	var rows: Array[Button] = [panel.member_row(0), panel.member_row(1), panel.member_row(2)]
	var two: Array[Dictionary] = [three[2], three[0]]
	panel.show_party(two)
	assert_true(panel.member_row(0) == rows[0] and panel.member_row(1) == rows[1], "the same buttons")
	assert_equal(panel.member_row_count(), 2, "two in use")
	assert_null(panel.member_row(2), "the third out of use")
	assert_false(rows[2].visible, "and hidden")
	var picked: Array[int] = []
	panel.member_picked.connect(func(i: int) -> void: picked.append(i))
	rows[0].pressed.emit()
	assert_equal(picked, [12] as Array[int], "the first row lists R2 now")
	var chips: Array[Color] = [Color.RED, Color.GREEN]
	panel.show_party([{"index": 1, "name": "A", "state": "holding", "colour": chips[0]},
		{"index": 2, "name": "B", "state": "holding", "colour": chips[1]}] as Array[Dictionary])
	assert_equal((rows[1].get_node(^"Chip") as ColorRect).color, chips[1], "each row's chip is its resident's")
	panel.show_party([{"index": 4, "name": "A", "species": "Mouse", "state": "holding"}] as Array[Dictionary])
	var lines: Array[Label] = panel.get("_line_labels")
	var first: Label = lines[0]
	panel.show_party([{"index": 5, "name": "B", "species": "Otter", "state": "wandering"}] as Array[Dictionary])
	assert_true((panel.get("_line_labels") as Array)[0] == first, "the same line label")
	assert_equal(first.text, "Otter", "re-worded")
	assert_false(rows[0].visible, "no member rows for one resident")
