extends "res://test/framework/test_case.gd"
## The accessibility presets and settings (decision 0471, review UX-023), off-tree: each preset's settings, its
## previewed change, applying and Restore defaults through the menu's section; reduced motion turning the right
## things down (particles, the camera's easing, the rings' pulse, the rain and snow) and back; high contrast
## re-rendering the shared panel pieces in place; fewer toasts; bigger tooltips; and the effects node reaching the
## pause ledger, the rings and the focus hint.

const Access := preload("res://demo/access/demo_access.gd")
const Motion := preload("res://demo/access/demo_motion.gd")
const SettingsScript := preload("res://demo/access/access_settings_ui.gd")
const EffectsScript := preload("res://demo/access/access_effects.gd")
const MarksScript := preload("res://demo/access/target_marks.gd")
const HintScript := preload("res://demo/access/focus_hint.gd")
const LedgerScript := preload("res://demo/session/pause_ledger.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Textures := preload("res://demo/ui/woodland_textures.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

var _nodes: Array[Node] = []
var _scaled_to: int = -1
var _applied: int = 0


func before_each() -> void:
	"""Every setting at its default."""
	_reset()


func after_each() -> void:
	"""Free what a test built, and put every setting back (they are static: the session's)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_reset()


func _reset() -> void:
	"""Defaults: flags, scale, mix, motion, contrast."""
	Access.reset()
	DemoUiScale.percent = UiLayout.USER_SCALE_100
	SoundMix.reset()
	Motion.reduced = false
	Styles.set_high_contrast(false)
	_scaled_to = -1
	_applied = 0


func _settings(fits: Callable = Callable()) -> SettingsScript:
	"""The menu's section, its scale and effects recorded here (the scale stored as the menu's choose_scale does)."""
	var section := SettingsScript.new()
	_nodes.append(section)
	section.scale_fits = fits
	section.scale_to = func(percent: int) -> void:
		_scaled_to = percent
		DemoUiScale.percent = percent
	section.applied = func() -> void: _applied += 1
	return section


# --- presets ------------------------------------------------------------------------------------------------

func test_large_readable_previews_then_applies_its_settings() -> void:
	"""Hovering previews the change (nothing applied); pressing applies 150 %, bigger tooltips, high contrast and brighter
	nights (decision 0541)."""
	var section := _settings()
	var line: String = section.preview(Access.PRESET_LARGE)
	assert_equal(line, "Large readable would change: Interface scale 100% → 150% · Bigger tooltips off → on · "
		+ "High-contrast panels off → on · Brighter nights off → on", "the preview")
	assert_false(Access.is_on(Access.SET_TOOLTIPS), "a preview applies nothing")
	section.apply_preset(Access.PRESET_LARGE)
	assert_equal(_scaled_to, 150, "the interface at 150 %")
	assert_true(Access.is_on(Access.SET_TOOLTIPS) and Access.is_on(Access.SET_CONTRAST)
		and Access.is_on(Access.SET_BRIGHT_NIGHTS), "its three settings on")
	assert_equal(_applied, 1, "the effects applied once")
	assert_true(section.toggle_button(Access.SET_CONTRAST).button_pressed, "its toggle shows it on")


func test_large_readable_takes_125_where_150_does_not_fit() -> void:
	"""At 1280x720 150 % is refused: Large readable picks 125 %."""
	var section := _settings(func(percent: int) -> bool: return percent <= 125)
	section.apply_preset(Access.PRESET_LARGE)
	assert_equal(_scaled_to, 125, "125 %")


func test_large_readable_never_shrinks_the_scale() -> void:
	"""Already at 150: Large readable keeps it."""
	DemoUiScale.percent = 150
	assert_equal(Access.large_scale(150, Callable()), 150, "kept")
	assert_equal(Access.large_scale(125, func(p: int) -> bool: return p <= 125), 125, "125 kept where 150 is refused")
	assert_equal(Access.large_scale(150, func(p: int) -> bool: return p <= 125), 150, "never steps an applied 150 down")


func test_keyboard_planner_turns_on_focus_hints_and_targets() -> void:
	"""Its two settings; nothing else changes."""
	var section := _settings()
	section.apply_preset(Access.PRESET_KEYBOARD)
	assert_true(Access.is_on(Access.SET_FOCUS_HINTS) and Access.is_on(Access.SET_TARGETS), "both on")
	assert_equal(_scaled_to, -1, "the scale untouched")
	assert_false(Access.is_on(Access.SET_MOTION), "motion untouched")


func test_quiet_focus_takes_the_quiet_mix_and_fewer_toasts() -> void:
	"""The sound's Quiet focus mix (its volumes) and fewer toasts."""
	var section := _settings()
	var change: String = section.apply_preset(Access.PRESET_QUIET)
	assert_equal(SoundMix.preset, SoundMix.PRESET_QUIET, "the Quiet focus mix")
	assert_equal(SoundMix.percents, SoundMix.QUIET_PERCENTS, "its volumes")
	assert_true(Access.is_on(Access.SET_QUIET_TOASTS), "fewer toasts")
	assert_equal(change, "Mix Balanced → Quiet focus · Fewer news toasts off → on", "what changed")


func test_a_preset_leaves_other_settings_as_the_player_set_them() -> void:
	"""A preset only turns its own settings on: one the player turned on stays, one turned off stays off."""
	var section := _settings()
	Access.set_flag(Access.SET_PAUSE_PLANNING, true)
	Access.set_flag(Access.SET_PAUSE_CRITICAL, false)
	section.apply_preset(Access.PRESET_MOTION)
	assert_true(Access.is_on(Access.SET_PAUSE_PLANNING), "the player's own on stays on")
	assert_false(Access.is_on(Access.SET_PAUSE_CRITICAL), "the player's own off stays off")
	assert_true(Access.is_on(Access.SET_MOTION), "the preset's own on")


func test_a_preset_already_applied_says_nothing_to_change() -> void:
	"""Pressed twice: the second says so."""
	var section := _settings()
	section.apply_preset(Access.PRESET_MOTION)
	assert_equal(section.apply_preset(Access.PRESET_MOTION), "", "nothing changed")
	assert_true(section.preview_text().ends_with(Access.NO_CHANGE), section.preview_text())


func test_each_setting_toggles_on_its_own() -> void:
	"""A toggle sets just its setting and applies; its words say on or off."""
	var section := _settings()
	section.toggle_button(Access.SET_MOTION).button_pressed = true
	assert_true(Access.is_on(Access.SET_MOTION), "on")
	assert_equal(section.toggle_button(Access.SET_MOTION).text, "Reduced motion: on", "in words")
	assert_equal(_applied, 1, "applied")
	section.toggle_button(Access.SET_MOTION).button_pressed = false
	assert_false(Access.is_on(Access.SET_MOTION), "off again")


# --- restore defaults -------------------------------------------------------------------------------------------

func test_restore_defaults_asks_with_the_change_then_restores() -> void:
	"""After two presets: Restore asks, saying everything it will change; confirmed, all back to the defaults."""
	var section := _settings()
	section.apply_preset(Access.PRESET_LARGE)
	section.apply_preset(Access.PRESET_QUIET)
	section.ask_restore()
	assert_true(section.confirm_shown(), "it asks first")
	assert_true(Access.is_on(Access.SET_CONTRAST), "nothing restored yet")
	var change: String = section.restore_defaults()
	assert_equal(change, "Interface scale 150% → 100% · Mix Quiet focus → Balanced · Bigger tooltips on → off · "
		+ "High-contrast panels on → off · Fewer news toasts on → off · Brighter nights on → off", "the change")
	assert_equal(Access.flags, Access.DEFAULTS, "flags at their defaults")
	assert_equal(_scaled_to, 100, "100 %")
	assert_equal(SoundMix.preset, SoundMix.PRESET_BALANCED, "Balanced")
	assert_false(section.confirm_shown(), "the question goes")


func test_restore_defaults_with_nothing_to_restore_says_so() -> void:
	"""At the defaults: no question, a line."""
	var section := _settings()
	section.ask_restore()
	assert_false(section.confirm_shown(), "nothing to ask")
	assert_equal(section.preview_text(), SettingsScript.RESTORE_NONE, "says so")


func test_cancel_leaves_the_settings() -> void:
	"""Asked, then Cancel: nothing changes."""
	var section := _settings()
	section.apply_preset(Access.PRESET_KEYBOARD)
	section.ask_restore()
	section.cancel_restore()
	assert_true(Access.is_on(Access.SET_TARGETS), "kept")


func test_the_menu_shows_the_section_in_settings() -> void:
	"""The game menu's Settings page carries the accessibility section and its Time toggles."""
	var game := GameManagerScript.new()
	game.start_game()
	var menu := MenuScript.new()
	_nodes.append(menu)
	menu.bind(game)
	var text: String = menu.page_text(MenuScript.PAGE_SETTINGS)
	game.free()
	for words: String in ["Accessibility", "Large readable", "Keyboard planner", "Reduced motion", "Quiet focus",
			"Pause while planning: off", "Pause on a critical incident: on", "Restore defaults"]:
		assert_true(text.contains(words), "Settings shows '%s'" % words)


# --- reduced motion -----------------------------------------------------------------------------------------------

func test_reduced_motion_cuts_particles_and_brings_them_back() -> void:
	"""A CPU system emits PARTICLE_RATIO of its count with reduced motion, all of it again without."""
	var root := Node3D.new()
	_nodes.append(root)
	var chips := CPUParticles3D.new()
	chips.amount = 40
	root.add_child(chips)
	Motion.reduced = true
	assert_equal(Motion.apply_tree(root), 1, "one system touched")
	assert_equal(chips.amount, 14, "35 % of 40")
	Motion.reduced = false
	Motion.apply_tree(root)
	assert_equal(chips.amount, 40, "back to 40")


func test_reduced_motion_keeps_at_least_one_particle() -> void:
	"""A one-particle system keeps its one."""
	var single := CPUParticles3D.new()
	_nodes.append(single)
	single.amount = 1
	Motion.reduced = true
	Motion.apply_particles(single)
	assert_equal(single.amount, 1, "one")


func test_reduced_motion_stops_the_camera_easing() -> void:
	"""One step lands the view on its target with reduced motion; without it the view eases part of the way."""
	var rig := CameraScript.new()
	_nodes.append(rig)
	rig.configure(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 0.0, 40.0)), Vector3.ZERO)
	rig.centre_on(Vector3(10.0, 0.0, 0.0))
	rig.step(1.0 / 60.0)
	assert_true(rig.focus().x < 9.0, "eased: part way (%.2f)" % rig.focus().x)
	Motion.reduced = true
	rig.step(1.0 / 60.0)
	assert_almost_equal(rig.focus().x, 10.0, "reduced: there at once")


func test_reduced_motion_stills_the_pulse_and_calms_the_veil() -> void:
	"""The rings' pulse is 1.0 exactly; the rain and snow fall at VEIL_SPEED."""
	assert_almost_equal(Motion.pulse(1.06), 1.06, "pulsing")
	assert_almost_equal(Motion.veil_speed(), 1.0, "full speed")
	Motion.reduced = true
	assert_almost_equal(Motion.pulse(1.06), 1.0, "still")
	assert_almost_equal(Motion.veil_speed(), Motion.VEIL_SPEED, "calmer")


func test_the_effects_turn_reduced_motion_on_across_the_village() -> void:
	"""The effects node with reduced motion set: the flag up and every particle system under its root cut."""
	var root := Node3D.new()
	_nodes.append(root)
	var smoke := CPUParticles3D.new()
	smoke.amount = 20
	root.add_child(smoke)
	var effects := EffectsScript.new()
	_nodes.append(effects)
	effects.motion_root = root
	Access.set_flag(Access.SET_MOTION, true)
	effects.apply()
	assert_true(Motion.reduced, "reduced")
	assert_equal(smoke.amount, 7, "smoke cut")
	Access.set_flag(Access.SET_MOTION, false)
	effects.apply()
	assert_false(Motion.reduced, "not reduced")
	assert_equal(smoke.amount, 20, "smoke back")


# --- the other effects ----------------------------------------------------------------------------------------------

func test_high_contrast_renders_the_panel_face_flat() -> void:
	"""The panel piece's recipe with high contrast on renders one opaque tone across its face; off, the parchment's
	shading again. (The in-place texture update itself shows in the live frames: a headless renderer keeps no pixels.)"""
	var middle := Vector2i(64, 64)
	var off: Image = Textures.build_image(Styles.spec_for(Styles.PIECE_PANEL))
	assert_true(Styles.set_high_contrast(true) >= 0, "switched on")
	var flat: Image = Textures.build_image(Styles.spec_for(Styles.PIECE_PANEL))
	assert_true(flat.get_data() != off.get_data(), "a different face")
	for offset: Vector2i in [Vector2i(9, 7), Vector2i(-20, 15), Vector2i(30, -25)]:
		assert_true(flat.get_pixelv(middle).is_equal_approx(flat.get_pixelv(middle + offset)), "one tone at %s" % offset)
	assert_almost_equal(flat.get_pixelv(middle).a, 1.0, "opaque")
	Styles.set_high_contrast(false)
	assert_true(Textures.build_image(Styles.spec_for(Styles.PIECE_PANEL)).get_data() == off.get_data(), "the parchment again")


func test_fewer_toasts_shows_warnings_only_one_at_a_time() -> void:
	"""Quiet: notes are not toasted, and one warning at most."""
	var feed := NoticesScript.new()
	var strip := NewsScript.new()
	_nodes.append(strip)
	strip.configure(feed)
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight")
	feed.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_WARNING, "A storm is coming")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "The beans are up")
	assert_equal(strip.refresh(feed.now_msec()), 3, "all three")
	strip.quiet = true
	assert_equal(strip.refresh(feed.now_msec()), 1, "one")
	assert_true(strip.line_text(0).contains("A storm is coming"), "the newest warning, not the note: %s" % strip.line_text(0))


func test_bigger_tooltips_scale() -> void:
	"""TOOLTIP_BOOST with the setting on."""
	assert_almost_equal(Access.tooltip_scale(), 1.0, "off")
	Access.set_flag(Access.SET_TOOLTIPS, true)
	assert_almost_equal(Access.tooltip_scale(), Access.TOOLTIP_BOOST, "on")


func test_the_effects_reach_the_ledger_the_rings_and_the_hint() -> void:
	"""The time settings go to the pause ledger; targets show the rings; focus hints enable the hint."""
	var effects := EffectsScript.new()
	var marks := MarksScript.new()
	var hint := HintScript.new()
	_nodes.append_array([effects, marks, hint])
	var ledger := LedgerScript.new()
	effects.ledger = ledger
	effects.marks = marks
	effects.hint = hint
	Access.set_flag(Access.SET_PAUSE_PLANNING, true)
	Access.set_flag(Access.SET_PAUSE_CRITICAL, false)
	Access.set_flag(Access.SET_TARGETS, true)
	Access.set_flag(Access.SET_FOCUS_HINTS, true)
	effects.apply()
	assert_true(ledger.auto_planning, "pause while planning")
	assert_false(ledger.auto_critical, "no pause on a critical incident")
	assert_true(marks.visible, "the rings shown")
	assert_true(hint.enabled, "the hint on")
	Access.reset()
	effects.apply()
	assert_false(marks.visible or hint.enabled, "both off at the defaults")
	assert_true(ledger.auto_critical and not ledger.auto_planning, "the default pauses")


func test_a_preset_is_lit_while_all_it_sets_is_in_place() -> void:
	"""Applied: lit; one of its settings turned off: no longer lit."""
	var section := _settings()
	assert_false(section.preset_button(Access.PRESET_KEYBOARD).button_pressed, "not yet")
	section.apply_preset(Access.PRESET_KEYBOARD)
	assert_true(section.preset_button(Access.PRESET_KEYBOARD).button_pressed, "lit")
	section.toggle_button(Access.SET_TARGETS).button_pressed = false
	assert_false(section.preset_button(Access.PRESET_KEYBOARD).button_pressed, "unlit once one setting is off")
