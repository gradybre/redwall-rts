extends "res://test/framework/test_case.gd"
## The live demo's input gate, its focusable panels and the Demo Lab (decision 0261; review F26, F30, F50),
## off-tree: the routing table, the modal stack and its scrim, the focus rings, and every demo action
## button's focus. The same routes on the real scene with real Viewport input are
## test_demo_input_live.gd's.

const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const LabScript := preload("res://demo/ui/demo_lab.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const ForestPanel := preload("res://demo/forestry/forest_panel.gd")
const WaterPanel := preload("res://demo/waterplay/water_panel.gd")
const TunnelPanel := preload("res://demo/tunnel/tunnel_panel.gd")
const PartyPanel := preload("res://demo/control/demo_party_panel.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")

## Every label a test trigger had in the player panels (review F50).
const TRIGGER_WORDS: Array[String] = ["Next weather", "Test event", "Storm gust", "Cramp"]

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _own(node: Node) -> Node:
	"""Track a node for freeing after the test."""
	_nodes.append(node)
	return node


func _key(code: Key, shift: bool = false, ctrl: bool = false, pressed: bool = true, echo: bool = false) -> InputEventKey:
	"""A key event."""
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	event.echo = echo
	return event


func _focus(control: Control, keyboard: bool, in_region: bool) -> GateScript.Focus:
	"""A focus as the gate reads it."""
	var focus := GateScript.Focus.new()
	focus.control = control
	focus.keyboard = keyboard
	focus.button = control is BaseButton
	focus.in_region = in_region
	return focus


func _none() -> GateScript.Focus:
	"""The world holds the focus."""
	return GateScript.Focus.new()


func _layer_with_buttons(count: int) -> CanvasLayer:
	"""A CanvasLayer holding a VBox of `count` focusable buttons."""
	var layer := _own(CanvasLayer.new()) as CanvasLayer
	var box := VBoxContainer.new()
	layer.add_child(box)
	for k: int in count:
		var button := Button.new()
		button.name = "B%d" % k
		button.focus_mode = Control.FOCUS_ALL
		box.add_child(button)
	return layer


func _modal_gate(close_count: Array[int]) -> GateScript:
	"""A gate with one open modal (two buttons) whose close counts into `close_count`, K and F8 closing it."""
	var gate := _own(GateScript.new()) as GateScript
	var layer := _layer_with_buttons(2)
	gate.watch_modal(layer, layer, func() -> void: close_count[0] += 1, [&"open_food"] as Array[StringName],
		[KEY_F8] as Array[Key])
	return gate


# --- routing with a modal open ------------------------------------------------------------------------

func test_a_modal_swallows_world_keys_and_lets_navigation_through() -> void:
	"""B, V, R, W and Space (with no focus) are swallowed; arrows and F11 pass; releases pass."""
	var gate := _modal_gate([0])
	assert_true(gate.modal_open(), "the modal is open")
	for code: Key in [KEY_B, KEY_V, KEY_R, KEY_W, KEY_1, KEY_N]:
		assert_equal(gate.route(_key(code), _none()), GateScript.ROUTE_CONSUME, "%s swallowed" % OS.get_keycode_string(code))
	assert_equal(gate.route(_key(KEY_SPACE), _none()), GateScript.ROUTE_CONSUME, "Space with no focus: no pause")
	for code: Key in [KEY_UP, KEY_DOWN, KEY_PAGEDOWN, KEY_HOME, KEY_F11]:
		assert_equal(gate.route(_key(code), _none()), GateScript.ROUTE_PASS, "%s passes" % OS.get_keycode_string(code))
	assert_equal(gate.route(_key(KEY_W, false, false, false), _none()), GateScript.ROUTE_PASS, "a release passes")
	assert_equal(gate.route(_key(KEY_B, false, false, true, true), _none()), GateScript.ROUTE_CONSUME, "an echo too")
	assert_equal(gate.route(InputEventMouseButton.new(), _none()), GateScript.ROUTE_PASS, "the pointer is the scrim's")


func test_a_modal_closes_on_escape_and_its_own_keys() -> void:
	"""Esc, the modal's close action (K is open_food) and close key (F8) close it; Ctrl+F8 does not."""
	var gate := _modal_gate([0])
	assert_equal(gate.route(_key(KEY_ESCAPE), _none()), GateScript.ROUTE_CLOSE, "Esc")
	assert_equal(gate.route(_key(KEY_K), _none()), GateScript.ROUTE_CLOSE, "K, its action")
	assert_equal(gate.route(_key(KEY_F8), _none()), GateScript.ROUTE_CLOSE, "F8, its key")
	assert_equal(gate.route(_key(KEY_F8, false, true), _none()), GateScript.ROUTE_CONSUME, "Ctrl+F8 is not")
	assert_equal(gate.route(_key(KEY_ESCAPE, false, false, true, true), _none()), GateScript.ROUTE_CONSUME,
		"a held Esc closes one layer, not every layer")


func test_a_modal_s_tab_and_activation() -> void:
	"""Tab / Shift+Tab cycle it; Enter and Space press a keyboard-focused button, and nothing from a
	click's focus."""
	var gate := _modal_gate([0])
	var button: Control = gate.modal_controls()[0]
	assert_equal(gate.route(_key(KEY_TAB), _none()), GateScript.ROUTE_NEXT, "Tab")
	assert_equal(gate.route(_key(KEY_TAB, true), _none()), GateScript.ROUTE_PREVIOUS, "Shift+Tab")
	for code: Key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		assert_equal(gate.route(_key(code), _focus(button, true, false)), GateScript.ROUTE_PRESS, "keyboard press")
		assert_equal(gate.route(_key(code), _focus(button, false, false)), GateScript.ROUTE_CONSUME, "click focus: nothing")


func test_the_stall_banner_comes_first() -> void:
	"""While the banner shows (`yield_to`) its Enter is left alone, but Esc still closes the modal: the gate
	keeps guarding it."""
	var closed: Array[int] = [0]
	var gate := _modal_gate(closed)
	gate.yield_to(func() -> bool: return true)
	gate._input(_key(KEY_ENTER))
	assert_equal(closed[0], 0, "Enter is the banner's")
	gate._input(_key(KEY_ESCAPE))
	assert_equal(closed[0], 1, "Esc still closes the modal")


func test_closing_calls_the_top_modal_s_close() -> void:
	"""ROUTE_CLOSE runs the top modal's own close, once."""
	var closed: Array[int] = [0]
	var gate := _modal_gate(closed)
	gate.apply(GateScript.ROUTE_CLOSE, _none())
	assert_equal(closed[0], 1, "closed once")


# --- routing with no modal ----------------------------------------------------------------------------

func test_without_a_modal_world_keys_pass() -> void:
	"""With nothing open and no focus every key but F7 passes to the HUD and the world."""
	var gate := _own(GateScript.new()) as GateScript
	for code: Key in [KEY_B, KEY_V, KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_TAB, KEY_K, KEY_F8]:
		assert_equal(gate.route(_key(code), _none()), GateScript.ROUTE_PASS, "%s passes" % OS.get_keycode_string(code))
	assert_equal(gate.route(_key(KEY_F7), _none()), GateScript.ROUTE_SWITCH, "F7 switches focus")
	assert_equal(gate.route(_key(KEY_F7, false, true), _none()), GateScript.ROUTE_PASS, "Ctrl+F7 does not")


func test_enter_and_space_go_by_focused_context() -> void:
	"""A keyboard-focused button takes Enter and Space; a clicked one drops its focus and lets the key go
	on to the Dig tool or the pause; Ctrl+Space is the global pause always; a focused non-button passes."""
	var gate := _own(GateScript.new()) as GateScript
	var button := _own(Button.new()) as Button
	var field := _own(LineEdit.new()) as LineEdit
	for code: Key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		assert_equal(gate.route(_key(code), _focus(button, true, true)), GateScript.ROUTE_PRESS, "keyboard: press")
		assert_equal(gate.route(_key(code), _focus(button, false, true)), GateScript.ROUTE_DROP_FOCUS, "click: drop")
		assert_equal(gate.route(_key(code), _focus(button, true, false)), GateScript.ROUTE_PRESS, "a HUD button too")
		assert_equal(gate.route(_key(code), _focus(field, true, false)), GateScript.ROUTE_PASS, "a text field keeps it")
	assert_equal(gate.route(_key(KEY_SPACE, false, true), _focus(button, true, true)), GateScript.ROUTE_PASS,
		"Ctrl+Space pauses")


func test_a_click_s_focus_gives_the_arrows_back_and_f7_starts_from_the_world() -> void:
	"""A clicked button drops its focus on an arrow or Page Up (the camera's keys pass on); the keyboard's
	keeps them for Godot's own focus moves; F7 from a click's focus starts at the first region."""
	var gate := _own(GateScript.new()) as GateScript
	var right := _layer_with_buttons(2)
	var left := _layer_with_buttons(1)
	gate.add_region("right", [right] as Array[Node])
	gate.add_region("left", [left] as Array[Node])
	var clicked: Button = right.get_child(0).get_child(1) as Button
	for code: Key in [KEY_LEFT, KEY_UP, KEY_PAGEUP]:
		assert_equal(gate.route(_key(code), _focus(clicked, false, true)), GateScript.ROUTE_DROP_FOCUS, "click: drop")
		assert_equal(gate.route(_key(code), _focus(clicked, true, true)), GateScript.ROUTE_PASS, "keyboard: Godot's")
	gate.apply(GateScript.ROUTE_SWITCH, _focus(clicked, false, true))
	assert_equal(gate.last_focused, right.get_child(0).get_child(0), "F7 from a click: the first region")
	gate.apply(GateScript.ROUTE_SWITCH, _focus(clicked, true, true))
	assert_equal(gate.last_focused, left.get_child(0).get_child(0), "F7 from the keyboard's: the next region")


func test_the_hud_workspace_holding_input_stops_panel_routing() -> void:
	"""While the shell's scrimmed workspace holds the input, F7, Tab and Enter are not the gate's."""
	var gate := _own(GateScript.new()) as GateScript
	var button := _own(Button.new()) as Button
	var holds: Array[bool] = [true]
	gate.defer_to(func() -> bool: return holds[0])
	for code: Key in [KEY_F7, KEY_TAB, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		assert_equal(gate.route(_key(code), _focus(button, true, true)), GateScript.ROUTE_PASS, "%s passes" % OS.get_keycode_string(code))
	for code: Key in [KEY_ENTER, KEY_LEFT]:
		assert_equal(gate.route(_key(code), _focus(button, false, false)), GateScript.ROUTE_PASS,
			"a clicked workspace button keeps %s" % OS.get_keycode_string(code))
	holds[0] = false
	assert_equal(gate.route(_key(KEY_F7), _focus(button, true, true)), GateScript.ROUTE_SWITCH, "then F7 is the gate's")


func test_the_banner_takes_only_enter_and_space() -> void:
	"""While the stall banner shows, Enter and Space are its own; every other key is still routed."""
	var gate := _modal_gate([0])
	var banner: Array[bool] = [true]
	gate.yield_to(func() -> bool: return banner[0])
	assert_true(gate.yields(_key(KEY_ENTER)), "Enter: the banner's")
	assert_true(gate.yields(_key(KEY_SPACE)), "Space: the banner's")
	assert_false(gate.yields(_key(KEY_B)), "B is not")
	assert_equal(gate.route(_key(KEY_B), _none()), GateScript.ROUTE_CONSUME, "and the modal still swallows it")
	banner[0] = false
	assert_false(gate.yields(_key(KEY_ENTER)), "no banner: nothing yielded")


func test_a_modal_presses_only_its_own_buttons() -> void:
	"""A keyboard-focused button behind the top modal is not pressed by Enter."""
	var gate := _modal_gate([0])
	var behind := _own(Button.new()) as Button
	var inside: Control = gate.modal_controls()[0]
	assert_equal(gate.route(_key(KEY_ENTER), _focus(behind, true, false)), GateScript.ROUTE_CONSUME, "behind: nothing")
	assert_equal(gate.route(_key(KEY_ENTER), _focus(inside, true, false)), GateScript.ROUTE_PRESS, "inside: pressed")


func test_closing_a_lower_modal_keeps_focus_in_the_top_one() -> void:
	"""Two modals; the lower closes: focus goes to the top one's first control, not behind it."""
	var gate := _own(GateScript.new()) as GateScript
	var lower := _layer_with_buttons(1)
	var upper := _layer_with_buttons(2)
	gate.watch_modal(lower, lower, Callable())
	gate.watch_modal(upper, upper, Callable())
	lower.visible = false
	assert_equal(gate.top_layer(), upper, "the upper is still open")
	assert_equal(gate.last_focused, gate.modal_controls()[0], "focus in it")
	assert_true(gate.in_top_modal(gate.last_focused), "inside the upper")


func test_the_focus_read_is_one_reused_object() -> void:
	"""No allocation per key press: the gate fills one Focus."""
	var gate := _own(GateScript.new()) as GateScript
	assert_true(gate.focus_now() == gate.focus_now(), "the same Focus")
	assert_null(gate.focus_now().control, "off-tree: the world's")


func test_tab_and_escape_in_a_region() -> void:
	"""In a region Tab cycles it and Esc (keyboard focus) leaves it; outside one both pass to Godot and the
	world."""
	var gate := _own(GateScript.new()) as GateScript
	var button := _own(Button.new()) as Button
	assert_equal(gate.route(_key(KEY_TAB), _focus(button, true, true)), GateScript.ROUTE_NEXT, "Tab")
	assert_equal(gate.route(_key(KEY_TAB, true), _focus(button, true, true)), GateScript.ROUTE_PREVIOUS, "Shift+Tab")
	assert_equal(gate.route(_key(KEY_TAB, false, true), _focus(button, true, true)), GateScript.ROUTE_PASS, "Ctrl+Tab")
	assert_equal(gate.route(_key(KEY_TAB), _focus(button, true, false)), GateScript.ROUTE_PASS, "outside a region")
	assert_equal(gate.route(_key(KEY_ESCAPE), _focus(button, true, true)), GateScript.ROUTE_TO_WORLD, "Esc leaves")
	assert_equal(gate.route(_key(KEY_ESCAPE), _focus(button, false, true)), GateScript.ROUTE_PASS,
		"a click's focus leaves Esc to the world")


# --- the modal stack ----------------------------------------------------------------------------------

func test_a_watched_modal_opens_and_closes_with_its_layer() -> void:
	"""Shown: on the stack with a full-view scrim that stops the pointer, under its frame. Hidden: off, the
	scrim gone."""
	var gate := _own(GateScript.new()) as GateScript
	var layer := _layer_with_buttons(2)
	layer.visible = false
	gate.watch_modal(layer, layer, func() -> void: layer.visible = false)
	assert_false(gate.modal_open(), "hidden: not open")
	layer.visible = true
	assert_true(gate.modal_open(), "shown: open")
	var scrim: ColorRect = gate.scrim_of(layer)
	assert_not_null(scrim, "a scrim")
	assert_equal(scrim.get_index(), 0, "under the frame")
	assert_equal(scrim.mouse_filter, Control.MOUSE_FILTER_STOP, "it takes every click")
	assert_equal(scrim.anchor_right, 1.0, "across the view")
	assert_equal(gate.top_layer(), layer, "the top modal")
	gate.close_top()
	assert_false(gate.modal_open(), "Esc's close hid it and took it off")
	assert_equal(layer.get_child_count(), 1, "the scrim is gone")


func test_the_modal_s_ring_puts_its_close_last_and_focuses_content_first() -> void:
	"""With its close button named, the ring is content first and close last, and opening focuses content."""
	var gate := _own(GateScript.new()) as GateScript
	var layer := _layer_with_buttons(3)
	var close: Button = layer.get_child(0).get_child(0) as Button
	layer.visible = false
	gate.watch_modal(layer, layer, Callable())
	gate.set_modal_close(layer, close)
	layer.visible = true
	var ring: Array[Control] = gate.modal_controls()
	assert_equal(ring.size(), 3, "three buttons")
	assert_equal(ring[2], close, "the close is last")
	assert_equal(gate.last_focused, ring[0], "opening focuses the content's first")
	assert_true(gate.in_top_modal(ring[1]), "inside the modal")


func test_stacked_modals_close_top_first() -> void:
	"""Two modals: the later is the top one; closing it leaves the first open."""
	var gate := _own(GateScript.new()) as GateScript
	var first := _layer_with_buttons(1)
	var second := _layer_with_buttons(1)
	gate.watch_modal(first, first, func() -> void: first.visible = false)
	gate.watch_modal(second, second, func() -> void: second.visible = false)
	assert_equal(gate.top_layer(), second, "the second is on top")
	gate.close_top()
	assert_equal(gate.top_layer(), first, "then the first")
	assert_true(first.visible, "still shown")


# --- focus rings --------------------------------------------------------------------------------------

func test_focusables_skip_hidden_branches_hidden_layers_and_non_buttons() -> void:
	"""Reading order; a hidden container, a hidden layer, a FOCUS_NONE button and a focusable scroll box are
	not stops."""
	var layer := _layer_with_buttons(3)
	var box: Control = layer.get_child(0) as Control
	(box.get_child(1) as Button).focus_mode = Control.FOCUS_NONE
	var hidden := VBoxContainer.new()
	hidden.visible = false
	hidden.add_child(Button.new())
	box.add_child(hidden)
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_ALL
	box.add_child(scroll)
	var roots: Array[Node] = [layer]
	var ring: Array[Control] = GateScript.focusables(roots)
	assert_equal(ring.size(), 2, "B0 and B2")
	assert_equal(ring[0].name, "B0", "in order")
	assert_equal(ring[1].name, "B2", "in order")
	layer.visible = false
	assert_equal(GateScript.focusables(roots).size(), 0, "a hidden layer has none")


func test_step_wraps_both_ways() -> void:
	"""Next after the last is the first; before the first is the last; from outside, first or last."""
	var a := _own(Button.new()) as Button
	var b := _own(Button.new()) as Button
	var c := _own(Button.new()) as Button
	var ring: Array[Control] = [a, b, c]
	assert_equal(GateScript.step(ring, a, true), b, "a -> b")
	assert_equal(GateScript.step(ring, c, true), a, "c -> a")
	assert_equal(GateScript.step(ring, a, false), c, "a <- c")
	assert_equal(GateScript.step(ring, null, true), a, "from outside: first")
	assert_equal(GateScript.step(ring, null, false), c, "from outside backwards: last")
	assert_null(GateScript.step([] as Array[Control], a, true), "nothing to step to")


func test_f7_cycles_world_regions_and_back_skipping_empty_ones() -> void:
	"""F7 from the world: the first region's first button; then the next region with anything; then the
	world."""
	var gate := _own(GateScript.new()) as GateScript
	var right := _layer_with_buttons(2)
	var empty := _layer_with_buttons(0)
	var left := _layer_with_buttons(1)
	gate.add_region("right", [right] as Array[Node])
	gate.add_region("empty", [empty] as Array[Node])
	gate.add_region("left", [left] as Array[Node])
	gate.switch_region(null)
	assert_equal(gate.last_focused, right.get_child(0).get_child(0), "world -> right")
	gate.switch_region(right.get_child(0).get_child(1) as Control)
	assert_equal(gate.last_focused, left.get_child(0).get_child(0), "right -> left, past the empty one")
	gate.switch_region(left.get_child(0).get_child(0) as Control)
	assert_null(gate.last_focused, "left -> the world")
	assert_equal(gate.region_of(left.get_child(0).get_child(0) as Control), 2, "the left region")


func test_tab_in_a_region_moves_along_its_ring() -> void:
	"""ROUTE_NEXT from a region's last button wraps to its first."""
	var gate := _own(GateScript.new()) as GateScript
	var right := _layer_with_buttons(3)
	gate.add_region("right", [right] as Array[Node])
	var last: Button = right.get_child(0).get_child(2) as Button
	gate.apply(GateScript.ROUTE_NEXT, _focus(last, true, true))
	assert_equal(gate.last_focused, right.get_child(0).get_child(0), "wraps to the first")
	gate.apply(GateScript.ROUTE_PREVIOUS, _focus(right.get_child(0).get_child(0) as Control, true, true))
	assert_equal(gate.last_focused, last, "and back")


func test_press_toggles_and_emits_and_spares_a_disabled_button() -> void:
	"""The gate's press: a toggle flips then `pressed` fires; a disabled button does nothing."""
	var button := _own(Button.new()) as Button
	button.toggle_mode = true
	var heard: Array[int] = [0]
	button.pressed.connect(func() -> void: heard[0] += 1)
	GateScript.press(button)
	assert_true(button.button_pressed, "flipped")
	assert_equal(heard[0], 1, "pressed once")
	button.disabled = true
	GateScript.press(button)
	assert_equal(heard[0], 1, "a disabled button does nothing")


# --- F30: every demo action button takes keyboard focus -----------------------------------------------

func _show_all(node: Node) -> void:
	"""Make every control under `node` visible (every section of a panel, as if all were in use)."""
	for child: Node in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = true
		_show_all(child)


func _buttons_under(node: Node, out: Array[Button]) -> void:
	"""Every Button under `node`."""
	for child: Node in node.get_children():
		if child is Button:
			out.append(child as Button)
		_buttons_under(child, out)


func _assert_every_button_is_a_stop(panel: Node, label: String) -> void:
	"""Every button of `panel`, all sections shown, takes keyboard focus with the ring and is in its ring."""
	_show_all(panel)
	var all: Array[Button] = []
	_buttons_under(panel, all)
	var roots: Array[Node] = [panel]
	var ring: Array[Control] = GateScript.focusables(roots)
	assert_true(all.size() >= 2, "%s has buttons" % label)
	var missing: int = 0
	for button: Button in all:
		missing += 0 if ring.has(button) and button.get_theme_stylebox(&"focus") is StyleBoxTexture else 1
	assert_equal(missing, 0, "%s: all %d buttons are focus stops with the ring" % [label, all.size()])


func test_every_panel_button_is_a_keyboard_focus_stop() -> void:
	"""The Woods, Water, Tunnels (tunnel actions, rooms and fit-out included) and party panels, the zone's
	tabs and close, and the farm's shared wood button."""
	var forest := _own(ForestPanel.new()) as ForestPanel
	forest.build()
	_assert_every_button_is_a_stop(forest, "Woods")
	var water := _own(WaterPanel.new()) as WaterPanel
	water.build()
	_assert_every_button_is_a_stop(water, "Water")
	var tunnel := _own(TunnelPanel.new()) as TunnelPanel
	tunnel.build()
	_assert_every_button_is_a_stop(tunnel, "Tunnels")
	var party := _own(PartyPanel.new()) as PartyPanel
	party.build()
	_assert_every_button_is_a_stop(party, "Party")
	var zone := _own(ZoneScript.new()) as ZoneScript
	zone.build()
	_assert_every_button_is_a_stop(zone, "Zone tabs")
	var wood: Button = _own(FarmUi.button("Plant…")) as Button
	assert_equal(wood.focus_mode, Control.FOCUS_ALL, "the farm's and the Pantry's buttons take focus")
	assert_true(wood.get_theme_stylebox(&"focus") is StyleBoxTexture, "with the woodland ring")


# --- F50: the Demo Lab --------------------------------------------------------------------------------

func _found_triggers(panel: Node) -> PackedStringArray:
	"""Every button under `panel` whose text names a test trigger."""
	var found := PackedStringArray()
	var all: Array[Button] = []
	_buttons_under(panel, all)
	for button: Button in all:
		for word: String in TRIGGER_WORDS:
			if button.text.contains(word):
				found.append(button.text)
	return found


func test_the_player_panels_hold_no_test_trigger() -> void:
	"""Tunnels, Woods and Water, every section shown: no Next weather, Test event, Storm gust or Cramp; the
	player's own controls stay."""
	var tunnel := _own(TunnelPanel.new()) as TunnelPanel
	tunnel.build()
	_show_all(tunnel)
	var forest := _own(ForestPanel.new()) as ForestPanel
	forest.build()
	_show_all(forest)
	var water := _own(WaterPanel.new()) as WaterPanel
	water.build()
	_show_all(water)
	for panel: Node in [tunnel, forest, water]:
		assert_equal(_found_triggers(panel).size(), 0, "%s holds none: %s" % [panel.name, ", ".join(_found_triggers(panel))])
	assert_false(tunnel.has_button(TunnelPanel.ACTION_EVENT), "no test event button")
	assert_false(tunnel.has_button(TunnelPanel.ACTION_NEXT_WEATHER), "no next-weather button")
	assert_not_null(water.button(WaterPanel.ACTION_DIVE), "the water keeps its dive")
	assert_not_null(water.button(WaterPanel.ACTION_CONSENT), "and its swim shortcuts")
	assert_not_null(forest.button(ForestPanel.ACTION_GATHER), "the woods keep their work")


func test_the_lab_holds_its_triggers_in_order_and_fires_them() -> void:
	"""Each trigger is a button before the status line and Close; firing one runs it and says so."""
	var lab := _own(LabScript.new()) as LabScript
	var fired: Array[String] = []
	for word: String in TRIGGER_WORDS:
		lab.add_trigger(word, "tip", "Woods", func() -> void: fired.append(word))
	assert_equal(Array(lab.trigger_labels()), TRIGGER_WORDS, "the four, in order")
	var column: Node = lab.trigger_button(0).get_parent()
	assert_equal(lab.trigger_button(3).get_index() + 1, lab.close_button().get_index() - 1, "above the status and Close")
	lab.trigger_button(2).pressed.emit()
	assert_equal(fired, ["Storm gust"] as Array[String], "it ran")
	assert_true(lab.status_text().begins_with("Sent: Storm gust"), "and says so")
	assert_equal(column.get_child(0).get_class(), "Label", "the title first")


func test_a_trigger_that_cannot_act_is_disabled_with_its_reason() -> void:
	"""Cramp with no swimmer selected: disabled, the reason as its tooltip, and firing it does nothing."""
	var lab := _own(LabScript.new()) as LabScript
	var ran: Array[int] = [0]
	var swimmer: Array[bool] = [false]
	lab.add_trigger("Cramp", "tip", "Water", func() -> void: ran[0] += 1, func() -> bool: return swimmer[0],
		"Select a resident in the water first")
	lab.open()
	assert_true(lab.trigger_button(0).disabled, "disabled")
	assert_equal(lab.trigger_button(0).tooltip_text, "Select a resident in the water first", "with the reason")
	lab.trigger(0)
	assert_equal(ran[0], 0, "nothing ran")
	swimmer[0] = true
	lab.refresh()
	lab.trigger(0)
	assert_equal(ran[0], 1, "with a swimmer it runs")


func test_firing_a_trigger_reads_every_trigger_s_availability_again() -> void:
	"""A trigger whose firing makes another unavailable disables it at once."""
	var lab := _own(LabScript.new()) as LabScript
	var swimming: Array[bool] = [true]
	lab.add_trigger("Storm gust", "tip", "Woods", func() -> void: swimming[0] = false)
	lab.add_trigger("Cramp", "tip", "Water", func() -> void: pass, func() -> bool: return swimming[0], "why")
	lab.open()
	assert_false(lab.trigger_button(1).disabled, "Cramp can act")
	lab.trigger(0)
	assert_true(lab.trigger_button(1).disabled, "after the gust it cannot, and says so at once")


func test_the_lab_opens_and_closes_on_its_key() -> void:
	"""toggle (F8) opens and closes; opening clears the last status."""
	var lab := _own(LabScript.new()) as LabScript
	lab.add_trigger("Storm gust", "tip", "Woods", func() -> void: pass)
	lab.toggle()
	assert_true(lab.visible, "open")
	lab.trigger(0)
	lab.toggle()
	assert_false(lab.visible, "closed")
	lab.open()
	assert_equal(lab.status_text(), "", "a fresh status")
	assert_equal(LabScript.KEY, KEY_F8, "on F8")
