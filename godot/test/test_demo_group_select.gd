extends "res://test/framework/test_case.gd"
## The live demo's group selection (decision 0791): control groups (control_groups.gd), the status registry the group
## panel reads by data (group_status.gd), the group panel's widgets (group_panel.gd) built out of the tree, and the
## words group_select.gd puts on them. The real scene -- the box's count, the keys, the double click, Select idle, the
## tiles, the crews and Send to... under real Viewport input -- is test/live/demo_select_live.gd's
## (test_demo_select_live.gd).

const ControlGroups := preload("res://demo/control/control_groups.gd")
const GroupStatus := preload("res://demo/control/group_status.gd")
const GroupPanel := preload("res://demo/control/group_panel.gd")
const GroupSelect := preload("res://demo/control/group_select.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")

const WIDTH: float = 276.0


# --- control groups ----------------------------------------------------------------------------------------

func test_a_group_keeps_its_members_sorted_and_an_empty_selection_changes_nothing() -> void:
	"""Ctrl+3 over residents 5, 1, 3 keeps [1, 3, 5]; Ctrl+3 with nobody selected leaves it; unknown slots refuse."""
	var groups := ControlGroups.new()
	assert_true(groups.assign(3, PackedInt32Array([5, 1, 3])), "kept")
	assert_equal(groups.size_of(3), 3, "three in group 3")
	assert_false(groups.assign(3, PackedInt32Array()), "nobody: refused")
	assert_equal(groups.size_of(3), 3, "group 3 kept as it was")
	assert_false(groups.assign(10, PackedInt32Array([1])), "slot 10 is no group")
	assert_false(groups.assign(-1, PackedInt32Array([1])), "slot -1 is no group")
	assert_equal(groups.size_of(10), 0, "an unknown slot holds nobody")
	var out := PackedInt32Array()
	assert_equal(groups.recall_into(3, 9, out), 3, "all three recalled")
	assert_equal(out, PackedInt32Array([1, 3, 5]), "in cast order")


func test_the_slots_run_zero_to_nine() -> void:
	"""UI §5's ten groups: 0 and 9 are groups, -1 and 10 are not."""
	assert_true(ControlGroups.is_slot(0) and ControlGroups.is_slot(9), "0 and 9")
	assert_false(ControlGroups.is_slot(-1) or ControlGroups.is_slot(10), "-1 and 10")
	assert_equal(ControlGroups.GROUP_COUNT, 10, "ten groups")


func test_a_recall_drops_members_the_cast_no_longer_has_for_good() -> void:
	"""§5.2: recall removes the departed and the group stays smaller; an unknown slot recalls nobody."""
	var groups := ControlGroups.new()
	groups.assign(1, PackedInt32Array([0, 4, 8]))
	var out := PackedInt32Array([99])
	assert_equal(groups.recall_into(1, 5, out), 2, "index 8 is gone from a cast of 5")
	assert_equal(out, PackedInt32Array([0, 4]), "the two still here")
	assert_equal(groups.size_of(1), 2, "the group lost it")
	assert_equal(groups.recall_into(1, 9, out), 2, "a bigger cast does not bring it back")
	groups.assign(2, PackedInt32Array([4, 5]))
	assert_equal(groups.recall_into(2, 5, out), 1, "index 5 is just past a cast of 5")
	assert_equal(out, PackedInt32Array([4]), "only 4 is left")
	assert_equal(groups.recall_into(12, 9, out), 0, "an unknown slot")
	assert_true(out.is_empty(), "out emptied")


func test_the_same_digit_twice_within_300_ms_is_a_double_tap() -> void:
	"""UI §5's group_center: the second press of the same digit within 300 ms (inclusive) -- not after, not another
	digit, and not a third press straight after a double."""
	var groups := ControlGroups.new()
	assert_false(groups.tap(2, 1000000), "first press")
	assert_true(groups.tap(2, 1300000), "300 ms later: double")
	assert_false(groups.tap(2, 1400000), "a third press starts again")
	assert_false(groups.tap(2, 1700001), "300.001 ms after: not a double")
	assert_false(groups.tap(3, 1700100), "another digit")
	assert_false(groups.tap(2, 1700200), "back to 2: a first press")
	assert_true(groups.tap(2, 1700300), "then quickly again")
	assert_false(groups.tap(4, 2000000), "4 first")
	assert_false(groups.tap(4, 1999999), "a clock going backwards is never a double")


func test_the_group_holding_a_selection_is_found_exactly() -> void:
	"""slot_holding: the lowest group with exactly these members; a subset or nobody is none."""
	var groups := ControlGroups.new()
	groups.assign(7, PackedInt32Array([2, 3]))
	groups.assign(4, PackedInt32Array([3, 2]))
	assert_equal(groups.slot_holding(PackedInt32Array([2, 3])), 4, "the lowest of 4 and 7")
	assert_equal(groups.slot_holding(PackedInt32Array([2])), -1, "a subset is not the group")
	assert_equal(groups.slot_holding(PackedInt32Array()), -1, "nobody")


# --- the status registry --------------------------------------------------------------------------------

func _registry() -> GroupStatus:
	"""Idle for 0 and 2; Hungry (a warning) for 1 and 2; No bed (a note) for 2."""
	var statuses := GroupStatus.new()
	statuses.add(GroupStatus.IDLE, "Idle", GroupStatus.SEVERITY_NOTE, func(who: int) -> bool: return who == 0 or who == 2)
	statuses.add(&"hungry", "Hungry", GroupStatus.SEVERITY_WARN, func(who: int) -> bool: return who == 1 or who == 2)
	statuses.add(&"no_bed", "No bed", GroupStatus.SEVERITY_NOTE, func(who: int) -> bool: return who == 2)
	return statuses


func test_a_status_row_is_added_by_data_and_replaced_in_place() -> void:
	"""add: a row each; the same id again replaces it where it stood; every change bumps the revision."""
	var statuses := _registry()
	assert_equal(statuses.count(), 3, "three rows")
	assert_equal(statuses.revision, 3, "three adds")
	assert_true(statuses.add(&"hungry", "Starving", GroupStatus.SEVERITY_NOTE, func(_who: int) -> bool: return true),
		"replaced")
	assert_equal(statuses.count(), 3, "still three")
	assert_equal(statuses.find(&"hungry"), 1, "in its place")
	assert_equal(statuses.word_of(1), "Starving", "its new word")
	assert_equal(statuses.severity_of(1), GroupStatus.SEVERITY_NOTE, "its new severity")
	assert_equal(statuses.revision, 4, "bumped")


func test_a_bad_row_is_refused() -> void:
	"""No id, no word, an unknown severity or an invalid query: refused, nothing added, no revision."""
	var statuses := GroupStatus.new()
	var yes := func(_who: int) -> bool: return true
	assert_false(statuses.add(&"", "Word", GroupStatus.SEVERITY_WARN, yes), "no id")
	assert_false(statuses.add(&"a", "", GroupStatus.SEVERITY_WARN, yes), "no word")
	assert_false(statuses.add(&"a", "Word", 2, yes), "severity 2")
	assert_false(statuses.add(&"a", "Word", -1, yes), "severity -1")
	assert_false(statuses.add(&"a", "Word", GroupStatus.SEVERITY_WARN, Callable()), "no query")
	assert_equal(statuses.count(), 0, "nothing added")
	assert_equal(statuses.revision, 0, "no revision")
	assert_equal(statuses.id_of(0), &"", "no row 0")
	assert_equal(statuses.word_of(-1), "", "no row -1")
	assert_false(statuses.holds(0, 0), "no row holds")


func test_who_holds_a_row_and_in_what_order_rows_show() -> void:
	"""members_into keeps the members' order; bits_of has a bit per held row; warnings show first, each in added
	order; first_warning finds the first warning held."""
	var statuses := _registry()
	var out := PackedInt32Array([42])
	assert_equal(statuses.members_into(1, PackedInt32Array([2, 0, 1]), out), 2, "two hungry")
	assert_equal(out, PackedInt32Array([2, 1]), "in the members' order")
	assert_equal(statuses.members_into(5, PackedInt32Array([2]), out), 0, "no row 5")
	assert_equal(statuses.bits_of(2), 7, "resident 2 holds all three")
	assert_equal(statuses.bits_of(0), 1, "resident 0 only idle")
	assert_equal(statuses.bits_of(3), 0, "resident 3 none")
	assert_equal(statuses.shown_order(), PackedInt32Array([1, 0, 2]), "the warning first, then the notes")
	assert_equal(statuses.first_warning(2), 1, "resident 2's warning: Hungry")
	assert_equal(statuses.first_warning(0), -1, "resident 0 has none")


# --- the words ------------------------------------------------------------------------------------------

func test_short_names_keep_a_shared_first_word_whole() -> void:
	"""First names -- unless another in the list shares the first word (two placeholders)."""
	assert_equal(GroupSelect.short_names(PackedStringArray(["Wenna Tallowby", "Jory Whitethorn"])),
		PackedStringArray(["Wenna", "Jory"]), "first names")
	assert_equal(GroupSelect.short_names(PackedStringArray(["Mouse keeper", "Mouse fieldworker", "Badger quarryman"])),
		PackedStringArray(["Mouse keeper", "Mouse fieldworker", "Badger"]), "the shared first word stays whole")
	assert_equal(GroupSelect.short_names(PackedStringArray(["Hulda"])), PackedStringArray(["Hulda"]), "one word")
	assert_true(GroupSelect.short_names(PackedStringArray()).is_empty(), "nobody")


func test_a_status_line_and_a_tally() -> void:
	"""names_line: "Hungry ×2 — Tobit, Corra"; tally: most first, ties in first-seen order."""
	assert_equal(GroupSelect.names_line("Hungry", PackedStringArray(["Tobit", "Corra"])), "Hungry ×2 — Tobit, Corra",
		"the line")
	assert_equal(GroupSelect.tally(PackedStringArray(["Haulers", "Field", "Field", "Woods"])),
		"Field ×2 · Haulers ×1 · Woods ×1", "most first, then first seen")
	assert_equal(GroupSelect.tally(PackedStringArray()), "", "nothing")


func test_a_tile_names_its_warning_else_idle_else_its_activity() -> void:
	"""tile_tag: the warning first, then Idle, then the activity's first word capitalised."""
	assert_equal(GroupSelect.tile_tag("Hungry", true, "wandering"), "Hungry", "the warning wins")
	assert_equal(GroupSelect.tile_tag("", true, "wandering"), "Idle", "idle")
	assert_equal(GroupSelect.tile_tag("", false, "walking to the well"), "Walking", "the activity's first word")
	assert_equal(GroupSelect.tile_tag("", false, "Digging tunnel — 43%"), "Digging", "before its progress")


# --- the group panel ------------------------------------------------------------------------------------

func _view(count: int) -> GroupPanel.GroupView:
	"""A view of `count` members, member 1 warned, crews Field allowed and Woods refused."""
	var view := GroupPanel.GroupView.new()
	view.shown = count >= 2
	view.doing = "Doing: Holding ×%d" % count
	view.attention = PackedStringArray(["Hungry ×1 — Jory"])
	view.notes = PackedStringArray(["No bed ×1 — Jory"])
	view.idle_line = "Idle: nobody"
	for k: int in count:
		view.index.append(10 + k)
		view.colour.append(Color(0.2, 0.4, 0.6))
		view.first_name.append("Name%d" % k)
		view.tag.append("Holding")
		view.tip.append("tip %d" % k)
		view.warn.append(1 if k == 1 else 0)
	view.crew_line = "Crews: Field ×%d — put them all on:" % count
	view.crew_tip = PackedStringArray(["Field card", "Woods card", "", "", ""])
	view.crew_why = PackedStringArray(["", "All on Woods already", "", "", ""])
	view.group_line = "Kept as group 3"
	return view


func _built() -> GroupPanel:
	"""A group panel built out of the tree."""
	var panel := GroupPanel.new()
	panel.build(WIDTH)
	return panel


func _free(panel: GroupPanel) -> void:
	"""Free a panel and its top row (which a party panel would hold)."""
	if panel.top_row().get_parent() == null:
		panel.top_row().free()
	panel.free()


func test_the_section_shows_a_group_and_hides_for_one() -> void:
	"""Two or more: shown, every line and a tile each; one: hidden, its tiles not counted."""
	var panel := _built()
	assert_false(panel.visible, "hidden until shown")
	panel.show_group(_view(4))
	assert_true(panel.visible, "a group shows")
	assert_equal(panel.tile_count(), 4, "a tile each")
	var text: String = panel.lines_text()
	for part: String in ["Doing: Holding ×4", "Needs attention:", "Hungry ×1 — Jory", "No bed ×1 — Jory", "Idle: nobody",
			"Crews: Field ×4", "Kept as group 3"]:
		assert_true(text.contains(part), "says %s" % part)
	panel.show_group(_view(1))
	assert_false(panel.visible, "one: hidden")
	assert_equal(panel.tile_count(), 0, "no tiles counted")
	_free(panel)


func test_no_warning_says_none_and_the_pool_shrinks() -> void:
	"""Without warnings: "Needs attention: none"; fewer members hide the spare tiles."""
	var panel := _built()
	panel.show_group(_view(5))
	var view := _view(2)
	view.attention = PackedStringArray()
	panel.show_group(view)
	assert_true(panel.lines_text().contains("Needs attention: none"), "none")
	assert_false(panel.lines_text().contains("Hungry"), "the old warning gone")
	assert_not_null(panel.tile(1), "tile 1 shows")
	assert_null(panel.tile(2), "tile 2 hidden")
	assert_null(panel.tile(-1), "no tile -1")
	_free(panel)


func test_a_tile_says_its_name_and_tag_and_wears_a_warning_edge() -> void:
	"""Tile k: the name and tag given, its tooltip, a clay edge for a warning only."""
	var panel := _built()
	panel.show_group(_view(3))
	var warned: Button = panel.tile(1)
	var plain: Button = panel.tile(0)
	assert_equal((warned.get_node(^"Lines/Name") as Label).text, "Name1", "its name")
	assert_equal((warned.get_node(^"Lines/Tag") as Label).text, "Holding", "its tag")
	assert_equal(warned.tooltip_text, "tip 1", "its tooltip")
	var edge: StyleBoxFlat = warned.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_equal(edge.border_color, GroupPanel.Palette.CLAY, "a clay edge")
	assert_equal(edge.border_width_left, GroupPanel.WARN_BORDER, "two pixels")
	assert_true((plain.get_theme_stylebox(&"normal") as StyleBoxFlat).border_color != GroupPanel.Palette.CLAY, "plain")
	_free(panel)


func test_a_tile_press_says_who_and_whether_shift_was_held() -> void:
	"""tile_pressed(index, shift): a plain press, then a Shift press noted from its click."""
	var panel := _built()
	panel.show_group(_view(3))
	var got: Array = []
	panel.tile_pressed.connect(func(who: int, shift: bool) -> void: got.append([who, shift]))
	panel.tile(2).pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.shift_pressed = true
	click.pressed = true
	panel.tile(0).gui_input.emit(click)
	panel.tile(0).pressed.emit()
	panel.tile(0).pressed.emit()
	assert_equal(got, [[12, false], [10, true], [10, false]], "who, and Shift once")
	panel.tile(1).gui_input.emit(click)
	panel.tile(1).mouse_exited.emit()
	panel.tile(1).pressed.emit()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.shift_pressed = true
	panel.tile(2).gui_input.emit(release)
	panel.tile(2).pressed.emit()
	assert_equal(got.slice(3), [[11, false], [12, false]], "a Shift press left behind, or a release alone, is no Shift")
	_free(panel)


func test_crew_buttons_send_their_crew_and_one_all_are_on_is_disabled() -> void:
	"""crew_pressed(crew); a crew with a why is disabled with it as its tooltip, another wears its card."""
	var panel := _built()
	panel.show_group(_view(2))
	var got := PackedInt32Array()
	panel.crew_pressed.connect(func(crew: int) -> void: got.append(crew))
	panel.crew_button(CrewsScript.CREW_FIELD).pressed.emit()
	assert_equal(got, PackedInt32Array([CrewsScript.CREW_FIELD]), "Field")
	assert_true(panel.crew_button(CrewsScript.CREW_WOODS).disabled, "Woods refused")
	assert_equal(panel.crew_button(CrewsScript.CREW_WOODS).tooltip_text, "All on Woods already", "why")
	assert_false(panel.crew_button(CrewsScript.CREW_FIELD).disabled, "Field allowed")
	assert_equal(panel.crew_button(CrewsScript.CREW_FIELD).tooltip_text, "Field card", "its card")
	assert_null(panel.crew_button(CrewsScript.CREW_COUNT), "no sixth crew")
	_free(panel)


func test_select_idle_counts_and_is_disabled_with_nobody_idle() -> void:
	"""The top row's button: "Select idle (n)" naming them; at 0 disabled saying why."""
	var panel := _built()
	panel.show_idle(2, "Wenna, Jory")
	assert_equal(panel.idle_button().text, "Select idle (2)", "two")
	assert_false(panel.idle_button().disabled, "enabled")
	assert_true(panel.idle_button().tooltip_text.contains("Wenna, Jory"), "names them")
	panel.show_idle(0, "")
	assert_equal(panel.idle_button().text, "Select idle (0)", "none")
	assert_true(panel.idle_button().disabled, "disabled")
	assert_equal(panel.idle_button().tooltip_text, GroupPanel.IDLE_NONE, "why")
	assert_true(panel.top_row().is_ancestor_of(panel.idle_button()), "in the top row")
	var got: Array = []
	panel.idle_pressed.connect(func() -> void: got.append(true))
	panel.send_pressed.connect(func() -> void: got.append(false))
	panel.idle_button().pressed.emit()
	panel.send_button().pressed.emit()
	assert_equal(got, [true, false], "each says so")
	_free(panel)


func test_send_to_shows_its_wait_and_text_and_buttons_meet_the_floors() -> void:
	"""set_armed presses Send to… without a signal; every label and button 14 px or more, buttons 32 px tall or more
	(UI §2.1, UX-T03); three tiles fit the width."""
	var panel := _built()
	panel.show_group(_view(3))
	var got: Array = []
	panel.send_pressed.connect(func() -> void: got.append(1))
	panel.set_armed(true)
	assert_true(panel.send_button().button_pressed, "pressed while waiting")
	panel.set_armed(false)
	assert_false(panel.send_button().button_pressed, "released")
	assert_true(got.is_empty(), "no signal")
	for node: Node in panel.find_children("*", "Control", true, false) + panel.top_row().find_children("*", "Button",
			true, false):
		if node is Label or node is Button:
			assert_true((node as Control).get_theme_font_size(&"font_size") >= 14, "%s text >= 14 px" % node.name)
		if node is Button:
			assert_true((node as Control).get_combined_minimum_size().y >= 32.0, "%s >= 32 px tall" % node.name)
	assert_true(3.0 * GroupPanel.tile_width(WIDTH) + 2.0 * GroupPanel.TILE_GAP <= WIDTH, "three tiles fit")
	assert_equal(GroupPanel.tile_width(WIDTH), 88.0, "88 px each at 276")
	_free(panel)


func test_the_party_panel_hosts_the_section_after_its_notice_and_the_row_in_its_top() -> void:
	"""add_section puts the group panel right after the notice; add_top_row in the actions' flow, after the room tools
	(decision 0902), so it shows while nobody is selected and adds no row of its own."""
	var party := PanelScript.new()
	party.build()
	var panel := _built()
	party.add_section(panel)
	party.add_top_row(panel.top_row())
	var notice: Label = party.notice_label()
	assert_equal(panel.get_parent(), notice.get_parent(), "beside the notice")
	assert_equal(panel.get_index(), notice.get_index() + 1, "right after it")
	assert_equal(panel.top_row().get_parent().name, &"Actions", "in the actions' flow")
	assert_equal(panel.top_row().get_index(), panel.top_row().get_parent().get_child_count() - 1, "after the room tools")
	party.show_party([])
	assert_true(panel.top_row().get_parent().visible, "shown with nobody selected")
	party.free()


func test_the_box_count_sits_past_the_box_and_inside_the_view() -> void:
	"""label_at: 8 px past the box's lower right corner; at the view's right or bottom edge, kept inside it."""
	var view := Vector2(1280.0, 720.0)
	var size := Vector2(160.0, 24.0)
	assert_equal(GroupSelect.label_at(Rect2(100.0, 100.0, 200.0, 100.0), size, view), Vector2(308.0, 208.0), "past it")
	assert_equal(GroupSelect.label_at(Rect2(1000.0, 600.0, 270.0, 110.0), size, view), Vector2(1120.0, 696.0),
		"kept inside at the corner")
	assert_equal(GroupSelect.label_at(Rect2(0.0, 0.0, 10.0, 10.0), Vector2(2000.0, 900.0), view), Vector2.ZERO,
		"a label bigger than the view starts at its corner")
