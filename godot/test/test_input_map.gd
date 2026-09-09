extends "res://test/framework/test_case.gd"
## Conformance suite for the settlement input map against
## `docs/ui_ux_controls.md` rev 1.1 section 5, "Complete Input Map and Interaction Precedence".
##
## ProjectSettings and InputMap are both populated under `--script`, so every assertion here
## reads the real `godot/project.godot` rather than a fixture. This is the same technique
## `test_legacy_battle_combat_system.gd` uses for its autoload guard.
##
## THREE THINGS THIS SUITE EXISTS TO CATCH.
## 1. A section 5 action ID silently missing. SPEC_ACTIONS names all 87 explicitly, so a gap
##    fails by name and not as a count that someone can "fix" by editing the expected number.
## 2. Pause drifting back onto Escape. The prototype mapped a `cancel` action on Escape to
##    `GameManager.toggle_pause()`. Section 5 puts pause on `time_pause` (Space, and Ctrl+Space
##    outside text/rebind) and gives Escape to the dismissal ladder. Renaming `cancel` to
##    `ui_cancel` without moving the consumer would have looked compliant and behaved wrongly.
## 3. A chord collision. Section 5: "No two enabled actions may share a chord in the same
##    context." Godot cannot express contexts, so this suite pins BOTH the exact-chord
##    collisions (which must be one of the three ladders section 5 itself specifies) and the
##    modifier-shadowing pairs that Godot's subset matching creates.
##
## VERIFIED ENGINE BEHAVIOUR (Godot 4.7.2): a key action matches when the ACTION's modifier
## mask is a subset of the pressed event's mask. A plain-key action therefore also fires while
## Ctrl/Shift/Alt is held, which is why SHADOW_PAIRS below is not empty and must be pinned.

## Modifier bit weights used to build a comparable chord identity.
const MASK_ALT: int = 1
const MASK_SHIFT: int = 2
const MASK_CTRL: int = 4
const MASK_META: int = 8

const PROJECT_INPUT_PREFIX: String = "input/"

## The one script in the project that consumes an input action.
const BOOT_SCRIPT_PATH: String = "res://scripts/main.gd"

## Every action ID named by the section 5 table, in table order.
const SPEC_ACTIONS: Array[String] = [
	# Pan, rotate, zoom, pitch.
	"camera_pan_left", "camera_pan_right", "camera_pan_forward", "camera_pan_back",
	"camera_rotate_left", "camera_rotate_right",
	"camera_zoom_in", "camera_zoom_out",
	"camera_pitch_up", "camera_pitch_down",
	# Selection.
	"select_primary", "select_box", "select_toggle", "select_similar", "selection_clear",
	"selection_next", "selection_previous",
	# Control groups: three families of ten.
	"group_assign_0", "group_assign_1", "group_assign_2", "group_assign_3", "group_assign_4",
	"group_assign_5", "group_assign_6", "group_assign_7", "group_assign_8", "group_assign_9",
	"group_recall_0", "group_recall_1", "group_recall_2", "group_recall_3", "group_recall_4",
	"group_recall_5", "group_recall_6", "group_recall_7", "group_recall_8", "group_recall_9",
	"group_center_0", "group_center_1", "group_center_2", "group_center_3", "group_center_4",
	"group_center_5", "group_center_6", "group_center_7", "group_center_8", "group_center_9",
	# Context commands.
	"command_context", "command_queue", "command_cancel",
	# Time and speed.
	"time_pause", "time_speed_1", "time_speed_2", "time_speed_4",
	# Panels and views.
	"open_build", "open_zones", "open_harvest", "open_jobs", "open_food", "open_residents",
	"open_feast", "open_objectives", "open_history", "open_calendar", "minimap_toggle",
	"camera_home", "camera_follow", "roof_cycle",
	# Placement and brush tools.
	"placement_commit", "placement_rotate", "placement_repeat",
	"brush_smaller", "brush_larger", "brush_erase", "interior_commit",
	# Review, accessibility, saves.
	"open_demolish", "resident_pin", "open_world_list", "save_quick", "load_quick",
	# UI ladder and editing.
	"ui_accept", "ui_cancel", "ui_tab_next", "ui_tab_previous",
	"tool_undo", "text_select_all", "open_menu",
]

## The four prototype IDs decision 0006 row 10 rejects. None may survive.
const PROTOTYPE_ACTIONS: Array[String] = ["select", "move_command", "build", "cancel"]

## Section 5 gives group_center only "double digit within 300 ms", a same-key double tap inside
## a time window. That is not expressible as an InputMap event; the input router must emit it.
const ROUTER_ONLY_ACTIONS: Array[String] = [
	"group_center_0", "group_center_1", "group_center_2", "group_center_3", "group_center_4",
	"group_center_5", "group_center_6", "group_center_7", "group_center_8", "group_center_9",
]

## The only actions allowed a raw pointer binding. Section 5 rules that pointer-derived
## gestures are emitted by the router and "must not each execute independently from duplicate
## raw mouse bindings"; the wheel is one discrete event meaning one action in every context.
const MOUSE_BOUND_ACTIONS: Array[String] = ["camera_zoom_in", "camera_zoom_out"]

## Exact-chord collisions section 5 itself specifies, keyed "modifier_mask/keycode".
const CONTEXT_LADDERS: Dictionary = {
	"0/4194309": ["select_primary", "placement_commit", "interior_commit", "ui_accept"],
	"2/4194309": ["select_toggle", "command_queue", "placement_repeat"],
	"0/4194305": ["selection_clear", "ui_cancel", "open_menu"],
}

## Ordered "shadowed|shadowing" pairs created by Godot's subset modifier matching. Each is a
## pair section 5 places in different contexts, so the router's classification precedence
## ("active UI/tool, modifier gesture, drag, double-click, single-click") resolves it. A new
## pair appearing here means a binding was added that fires an unrelated action.
const SHADOW_PAIRS: Array[String] = [
	"camera_pan_back|select_box",
	"camera_pan_forward|select_box",
	"camera_pan_left|select_box",
	"camera_pan_left|text_select_all",
	"camera_pan_right|select_box",
	"camera_zoom_in|camera_pitch_up",
	"camera_zoom_out|camera_pitch_down",
	"group_recall_0|group_assign_0",
	"group_recall_1|group_assign_1",
	"group_recall_2|group_assign_2",
	"group_recall_3|group_assign_3",
	"group_recall_4|group_assign_4",
	"group_recall_5|group_assign_5",
	"group_recall_6|group_assign_6",
	"group_recall_7|group_assign_7",
	"group_recall_8|group_assign_8",
	"group_recall_9|group_assign_9",
	"interior_commit|brush_erase",
	"interior_commit|command_queue",
	"interior_commit|placement_repeat",
	"interior_commit|select_similar",
	"interior_commit|select_toggle",
	"open_zones|tool_undo",
	"placement_commit|brush_erase",
	"placement_commit|command_queue",
	"placement_commit|placement_repeat",
	"placement_commit|select_similar",
	"placement_commit|select_toggle",
	"select_primary|brush_erase",
	"select_primary|command_queue",
	"select_primary|placement_repeat",
	"select_primary|select_similar",
	"select_primary|select_toggle",
	"selection_next|selection_previous",
	"selection_next|ui_tab_next",
	"selection_next|ui_tab_previous",
	"selection_previous|ui_tab_previous",
	"ui_accept|brush_erase",
	"ui_accept|command_queue",
	"ui_accept|placement_repeat",
	"ui_accept|select_similar",
	"ui_accept|select_toggle",
	"ui_tab_next|ui_tab_previous",
]


func test_every_action_named_by_section_5_is_registered() -> void:
	"""All 87 section 5 action IDs resolve in the InputMap, each failing by its own name."""
	for action: String in SPEC_ACTIONS:
		assert_true(InputMap.has_action(action), "section 5 action '%s' is registered" % action)


func test_every_action_is_declared_by_the_project_file() -> void:
	"""Each ID comes from project.godot, not from a Godot built-in that happens to share a name.

	`ui_accept` and `ui_cancel` exist in every Godot project; without this check they would
	satisfy the presence test while the project file declared nothing at all.
	"""
	for action: String in SPEC_ACTIONS:
		assert_true(ProjectSettings.has_setting(PROJECT_INPUT_PREFIX + action),
			"project.godot declares input/%s" % action)


func test_the_four_prototype_action_ids_are_gone() -> void:
	"""Decision 0006 row 10: none of the prototype IDs may remain reachable."""
	for action: String in PROTOTYPE_ACTIONS:
		assert_false(InputMap.has_action(action), "prototype action '%s' was removed" % action)
		assert_false(ProjectSettings.has_setting(PROJECT_INPUT_PREFIX + action),
			"project.godot no longer declares input/%s" % action)


func test_pause_is_time_pause_on_space() -> void:
	"""Pause is Space, and Ctrl+Space outside text/rebind contexts — section 5's time_pause row."""
	assert_true(_action_has_chord("time_pause", KEY_SPACE, 0), "time_pause is bound to Space")
	assert_true(_action_has_chord("time_pause", KEY_SPACE, MASK_CTRL),
		"time_pause is bound to Ctrl+Space")
	assert_false(_action_has_chord("time_pause", KEY_ESCAPE, 0),
		"time_pause is NOT bound to Escape")


func test_escape_belongs_to_the_dismissal_ladder_and_never_to_pause() -> void:
	"""Escape drives selection_clear, ui_cancel and open_menu — and no other action."""
	var on_escape: Array[String] = []
	for action: String in SPEC_ACTIONS:
		if _action_has_chord(action, KEY_ESCAPE, 0):
			on_escape.append(action)
	on_escape.sort()
	var expected: Array[String] = ["open_menu", "selection_clear", "ui_cancel"]
	assert_equal(on_escape, expected, "Escape is exactly the section 5 dismissal ladder")


func test_no_two_actions_share_an_exact_chord_outside_the_specified_ladders() -> void:
	"""Section 5: no two enabled actions may share a chord in the same context.

	The only permitted exact-chord sharing is the three ladders section 5 states outright:
	Enter (world-list select / placement commit / interior commit / UI confirm), Shift+Enter
	(toggle / queue / repeat placement) and Escape (clear selection / dismiss / open menu).
	"""
	var chords: Dictionary = _chord_map()
	for chord: String in chords:
		var actions: Array[String] = chords[chord]
		if actions.size() < 2:
			continue
		assert_true(CONTEXT_LADDERS.has(chord),
			"chord %s is shared only by a specified ladder, got %s" % [chord, actions])
		if not CONTEXT_LADDERS.has(chord):
			continue
		var expected: Array = (CONTEXT_LADDERS[chord] as Array).duplicate()
		expected.sort()
		actions.sort()
		assert_equal(actions, expected, "ladder on chord %s has its specified members" % chord)


func test_modifier_shadowing_pairs_are_exactly_the_documented_set() -> void:
	"""Godot fires a plain-key action while modifiers are held; pin every pair that creates.

	Each documented pair is two actions section 5 places in different contexts. A pair that is
	not on the list means a new binding silently fires an unrelated action.
	"""
	var found: Array[String] = _shadow_pairs()
	for pair: String in found:
		assert_true(SHADOW_PAIRS.has(pair), "shadowing pair '%s' is documented" % pair)
	for pair: String in SHADOW_PAIRS:
		assert_true(found.has(pair), "documented shadowing pair '%s' still exists" % pair)


func test_movement_keys_use_physical_positions() -> void:
	"""Section 5: "physical key positions for WASD/QE movement". Pan direction is checked too."""
	assert_true(_action_has_physical("camera_pan_left", KEY_A), "A pans left by position")
	assert_true(_action_has_physical("camera_pan_right", KEY_D), "D pans right by position")
	assert_true(_action_has_physical("camera_pan_forward", KEY_W), "W pans forward by position")
	assert_true(_action_has_physical("camera_pan_back", KEY_S), "S pans back by position")
	assert_true(_action_has_physical("camera_rotate_left", KEY_Q), "Q rotates left by position")
	assert_true(_action_has_physical("camera_rotate_right", KEY_E), "E rotates right by position")


func test_arrow_keys_pan_in_the_specified_directions() -> void:
	"""Section 5: A/Left->left, D/Right->right, W/Up->forward, S/Down->back."""
	assert_true(_action_has_chord("camera_pan_left", KEY_LEFT, 0), "Left pans left")
	assert_true(_action_has_chord("camera_pan_right", KEY_RIGHT, 0), "Right pans right")
	assert_true(_action_has_chord("camera_pan_forward", KEY_UP, 0), "Up pans forward")
	assert_true(_action_has_chord("camera_pan_back", KEY_DOWN, 0), "Down pans back")


func test_text_editing_actions_use_logical_keys_with_both_modifiers() -> void:
	"""Section 5: logical keys for text editing, and Cmd+Z / Cmd+A alongside Ctrl on macOS."""
	assert_true(_action_has_chord("text_select_all", KEY_A, MASK_CTRL), "Ctrl+A selects field text")
	assert_true(_action_has_chord("text_select_all", KEY_A, MASK_META), "Cmd+A selects field text")
	assert_true(_action_has_chord("tool_undo", KEY_Z, MASK_CTRL), "Ctrl+Z undoes the stroke")
	assert_true(_action_has_chord("tool_undo", KEY_Z, MASK_META), "Cmd+Z undoes the stroke")
	assert_false(_action_has_physical("text_select_all", KEY_A),
		"text_select_all uses the logical A, not the physical position")


func test_os_reserved_chords_are_not_captured() -> void:
	"""Section 5: Cmd+Q and Alt+F4 are OS-reserved and never captured for gameplay."""
	for action: String in SPEC_ACTIONS:
		assert_false(_action_has_chord(action, KEY_Q, MASK_META), "'%s' does not take Cmd+Q" % action)
		assert_false(_action_has_chord(action, KEY_F4, MASK_ALT), "'%s' does not take Alt+F4" % action)


func test_control_group_families_carry_their_specified_digits() -> void:
	"""Ctrl+0..9 assigns and 0..9 recalls, for all ten slots."""
	for digit: int in range(10):
		var code: int = KEY_0 + digit
		assert_true(_action_has_chord("group_assign_%d" % digit, code, MASK_CTRL),
			"group_assign_%d is Ctrl+%d" % [digit, digit])
		assert_true(_action_has_chord("group_recall_%d" % digit, code, 0),
			"group_recall_%d is %d" % [digit, digit])


func test_router_only_actions_are_registered_but_unbound() -> void:
	"""group_center_0..9 has no expressible chord and waits on the input router.

	Registering them unbound keeps the section 5 vocabulary complete without binding a raw
	event that would fire on every single digit press.
	"""
	for action: String in ROUTER_ONLY_ACTIONS:
		assert_true(InputMap.has_action(action), "%s is registered" % action)
		assert_equal(InputMap.action_get_events(action).size(), 0,
			"%s has no binding: a 300 ms double tap is router work" % action)


func test_only_the_wheel_is_bound_as_a_raw_pointer_event() -> void:
	"""No pointer gesture gets a duplicate raw mouse binding that could double-fire."""
	for action: String in SPEC_ACTIONS:
		var mouse_events: int = 0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				mouse_events += 1
		if MOUSE_BOUND_ACTIONS.has(action):
			assert_equal(mouse_events, 1, "%s carries exactly its wheel binding" % action)
		else:
			assert_equal(mouse_events, 0, "%s has no raw pointer binding" % action)


func test_ui_accept_drops_the_engine_default_space_binding() -> void:
	"""Section 5 gives ui_accept Enter only; Godot's default also carries Space, which is pause."""
	assert_true(_action_has_chord("ui_accept", KEY_ENTER, 0), "ui_accept confirms on Enter")
	assert_false(_action_has_chord("ui_accept", KEY_SPACE, 0),
		"ui_accept does not steal Space from time_pause")


func test_speed_actions_cover_one_two_and_four_with_no_third_speed() -> void:
	"""Section 5 binds F1/F2/F3 to 1x/2x/4x. There is no 3x action to bind."""
	assert_true(_action_has_chord("time_speed_1", KEY_F1, 0), "F1 requests 1x")
	assert_true(_action_has_chord("time_speed_2", KEY_F2, 0), "F2 requests 2x")
	assert_true(_action_has_chord("time_speed_4", KEY_F3, 0), "F3 requests 4x")
	assert_false(InputMap.has_action("time_speed_3"), "no 3x action exists")


func test_the_boot_scene_consumes_time_pause_and_no_prototype_action() -> void:
	"""main.gd's only input consumer must be `time_pause`, not a renamed Escape binding.

	This reads the script's source text rather than driving the scene, because instantiating
	main.tscn would seed a settlement and print a boot line inside the suite. Decision 0006
	row 10 is a semantic fix: renaming `cancel` to `ui_cancel` while leaving pause on Escape
	would satisfy every InputMap assertion above and still be the wrong behaviour.
	"""
	var source: String = FileAccess.get_file_as_string(BOOT_SCRIPT_PATH)
	assert_false(source.is_empty(), "main.gd was read from disk")
	assert_true(source.contains("is_action_pressed(&\"time_pause\")"),
		"main.gd toggles pause on time_pause")
	for action: String in PROTOTYPE_ACTIONS:
		assert_false(source.contains("&\"%s\"" % action),
			"main.gd no longer references the prototype action '%s'" % action)


func _chord_id(event: InputEventKey) -> String:
	"""Identity of one key binding as "modifier_mask/keycode", logical or physical alike."""
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	return "%d/%d" % [_mask_of(event), code]


func _mask_of(event: InputEventKey) -> int:
	"""Pack the four modifier flags of a key event into a comparable bit mask."""
	var mask: int = 0
	if event.alt_pressed:
		mask |= MASK_ALT
	if event.shift_pressed:
		mask |= MASK_SHIFT
	if event.ctrl_pressed:
		mask |= MASK_CTRL
	if event.meta_pressed:
		mask |= MASK_META
	return mask


func _action_has_chord(action: String, keycode: int, mask: int) -> bool:
	"""True when the action carries a logical-key binding for exactly this keycode and mask."""
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		if key.keycode == keycode and _mask_of(key) == mask:
			return true
	return false


func _action_has_physical(action: String, physical_keycode: int) -> bool:
	"""True when the action carries an unmodified binding on this physical key position."""
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode == physical_keycode and _mask_of(key) == 0:
			return true
	return false


func _chord_map() -> Dictionary:
	"""Map every chord identity to the sorted list of section 5 actions that claim it."""
	var chords: Dictionary = {}
	for action: String in SPEC_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var chord: String = _chord_id(key)
			if not chords.has(chord):
				chords[chord] = [] as Array[String]
			var claimants: Array[String] = chords[chord]
			if not claimants.has(action):
				claimants.append(action)
	return chords


func _binding_rows() -> Array:
	"""Flatten every section 5 key binding to [action, keycode, modifier_mask] triples."""
	var rows: Array = []
	for action: String in SPEC_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var code: int = key.keycode if key.keycode != 0 else key.physical_keycode
			rows.append([action, code, _mask_of(key)])
	return rows


func _shadow_pairs() -> Array[String]:
	"""Find "shadowed|shadowing" pairs: same key, the first action's mask a strict subset.

	Godot 4.7.2 matches a key action when the action's modifier mask is a subset of the
	pressed event's mask, so the first action of each pair also fires on the second's chord.
	"""
	var pairs: Array[String] = []
	for lower: Array in _binding_rows():
		for higher: Array in _binding_rows():
			if lower[0] == higher[0] or lower[1] != higher[1] or lower[2] == higher[2]:
				continue
			if (int(lower[2]) & int(higher[2])) != int(lower[2]):
				continue
			var pair: String = "%s|%s" % [lower[0], higher[0]]
			if not pairs.has(pair):
				pairs.append(pair)
	pairs.sort()
	return pairs
