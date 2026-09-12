extends "res://test/framework/test_case.gd"
## Coverage for §2's palette and profile table, checked against §2.1's published contrast ratios.
##
## §2.1 publishes nine computed ratios: "TEXT/PANEL 12.20:1; MUTED/PANEL 8.21:1; TEXT/HOVER
## 9.04:1; MUTED/HOVER 6.09:1; INK/GOLD 10.15:1; GOLD/PANEL 8.49:1; DANGER/PANEL 8.16:1;
## WARNING/PANEL 9.84:1; SUCCESS/PANEL 8.53:1." Those are arithmetic facts about the ten hex
## values, so recomputing them from the tokens and comparing against the published figures is a
## real transcription check: change one hex digit and at least one ratio moves well past the
## tolerance below.
##
## §2.1 also rules that "All functional panel/text backgrounds are opaque" and that disabled
## text "is not opacity-dimmed; its>=4.5:1 contrast remains". Both are checked directly.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

## §2.1's published ratios, quoted. The two-decimal figures are exact to well under 0.005.
const PUBLISHED_RATIOS: Array = [
	[UiTheme.TOKEN_TEXT, UiTheme.TOKEN_PANEL, 12.20],
	[UiTheme.TOKEN_MUTED, UiTheme.TOKEN_PANEL, 8.21],
	[UiTheme.TOKEN_TEXT, UiTheme.TOKEN_HOVER, 9.04],
	[UiTheme.TOKEN_MUTED, UiTheme.TOKEN_HOVER, 6.09],
	[UiTheme.TOKEN_INK, UiTheme.TOKEN_GOLD, 10.15],
	[UiTheme.TOKEN_GOLD, UiTheme.TOKEN_PANEL, 8.49],
	[UiTheme.TOKEN_DANGER, UiTheme.TOKEN_PANEL, 8.16],
	[UiTheme.TOKEN_WARNING, UiTheme.TOKEN_PANEL, 9.84],
	[UiTheme.TOKEN_SUCCESS, UiTheme.TOKEN_PANEL, 8.53],
]

const RATIO_TOLERANCE: float = 0.005

## §2.1's hex column, quoted independently of the module under test.
const QUOTED_HEX: Array = [
	[UiTheme.TOKEN_INK, 0x14211B], [UiTheme.TOKEN_PANEL, 0x1E3028],
	[UiTheme.TOKEN_HOVER, 0x2B4638], [UiTheme.TOKEN_PRESSED, 0x111C17],
	[UiTheme.TOKEN_TEXT, 0xF5F0DF], [UiTheme.TOKEN_MUTED, 0xBECABF],
	[UiTheme.TOKEN_GOLD, 0xE6C77A], [UiTheme.TOKEN_SUCCESS, 0x9DD8AF],
	[UiTheme.TOKEN_WARNING, 0xFFD28A], [UiTheme.TOKEN_DANGER, 0xFFB3AD],
]

## §2.2's ten profiles, in registry order.
const PROFILE_PANEL: int = 0
const PROFILE_BUTTON: int = 1
const PROFILE_FIELD: int = 4
const PROFILE_MODAL: int = 9

var _theme: UiTheme = null


func before_each() -> void:
	"""Build the theme."""
	_theme = UiTheme.new()


func after_each() -> void:
	"""Drop it so nothing crosses a test boundary."""
	_theme = null


# --- §2.1's palette -------------------------------------------------------------------------------

func test_every_published_contrast_ratio_is_reproduced_from_the_tokens() -> void:
	"""Recompute §2.1's nine figures with the WCAG formula and compare to the document."""
	for row: Array in PUBLISHED_RATIOS:
		var computed: float = UiTheme.token_contrast(row[0], row[1])
		assert_true(absf(computed - float(row[2])) < RATIO_TOLERANCE,
			"%s/%s is %.2f:1, computed %.4f" % [UiTheme.TOKEN_KEYS[row[0]],
				UiTheme.TOKEN_KEYS[row[1]], row[2], computed])


func test_the_hex_values_are_the_ones_section_two_one_lists() -> void:
	"""Ten tokens, ten hex values, quoted here rather than read back from the module."""
	for row: Array in QUOTED_HEX:
		assert_equal(UiTheme.TOKEN_RGB[row[0]], row[1],
			"%s is #%06X" % [UiTheme.TOKEN_KEYS[row[0]], row[1]])


func test_every_functional_token_is_fully_opaque() -> void:
	"""§2.1: "All functional panel/text backgrounds are opaque"; only SCRIM and SHADOW are not."""
	for token: int in UiTheme.TOKEN_COUNT:
		if token == UiTheme.TOKEN_SCRIM or token == UiTheme.TOKEN_SHADOW:
			continue
		assert_almost_equal(UiTheme.color_of(token).a, 1.0,
			"%s is opaque" % UiTheme.TOKEN_KEYS[token])
	assert_true(UiTheme.color_of(UiTheme.TOKEN_SCRIM).a < 1.0, "the modal scrim is translucent")
	assert_true(UiTheme.color_of(UiTheme.TOKEN_SHADOW).a
		< UiTheme.color_of(UiTheme.TOKEN_SCRIM).a, "and the decorative shadow is lighter still")


func test_the_relative_luminance_formula_is_the_wcag_one() -> void:
	"""Black is 0, white is 1, and their ratio is WCAG's 21:1 -- the formula's own endpoints."""
	assert_almost_equal(UiTheme.relative_luminance(Color(0.0, 0.0, 0.0)), 0.0, "black is 0")
	assert_almost_equal(UiTheme.relative_luminance(Color(1.0, 1.0, 1.0)), 1.0, "white is 1")
	assert_true(absf(UiTheme.contrast_ratio(Color(0, 0, 0), Color(1, 1, 1)) - 21.0) < 0.001,
		"black on white is 21:1")
	assert_almost_equal(UiTheme.contrast_ratio(Color(1, 1, 1), Color(1, 1, 1)), 1.0,
		"a colour against itself is 1:1")


# --- §2.2's five states ---------------------------------------------------------------------------

func test_disabled_text_keeps_its_contrast_instead_of_being_dimmed() -> void:
	"""§2.2: "Disabled text is not opacity-dimmed; its>=4.5:1 contrast remains"."""
	for profile: int in UiTheme.PROFILE_COUNT:
		var background: Color = _theme.background_of(profile, UiTheme.STATE_DISABLED)
		var foreground: Color = _theme.foreground_of(profile, UiTheme.STATE_DISABLED)
		assert_almost_equal(foreground.a, 1.0, "profile %d disabled text is opaque" % profile)
		assert_true(UiTheme.contrast_ratio(foreground, background)
			>= UiTheme.CONTRAST_TEXT_MINIMUM,
			"profile %d disabled text still meets 4.5:1" % profile)


func test_every_profile_and_state_meets_the_text_contrast_minimum() -> void:
	"""§2.1: "All normal text targets>=4.5:1", which every one of the fifty pairs must reach."""
	for profile: int in UiTheme.PROFILE_COUNT:
		for state: int in UiTheme.STATE_COUNT:
			var ratio: float = UiTheme.contrast_ratio(_theme.foreground_of(profile, state),
				_theme.background_of(profile, state))
			assert_true(ratio >= UiTheme.CONTRAST_TEXT_MINIMUM,
				"profile %d state %s is %.2f:1" % [profile, UiTheme.STATE_KEYS[state], ratio])


func test_a_selected_button_takes_ink_text_on_gold() -> void:
	"""§2.2's BUTTON row: "selected GOLD/INK+check", which is the 10.15:1 pair."""
	assert_equal(_theme.background_of(PROFILE_BUTTON, UiTheme.STATE_SELECTED),
		UiTheme.color_of(UiTheme.TOKEN_GOLD), "a selected button is GOLD")
	assert_equal(_theme.foreground_of(PROFILE_BUTTON, UiTheme.STATE_SELECTED),
		UiTheme.color_of(UiTheme.TOKEN_INK), "with INK text")


func test_a_field_sits_on_ink_rather_than_on_panel() -> void:
	"""§2.2's FIELD row: "INK 1.0;1 px MUTED;4 px", which distinguishes an input from a panel."""
	assert_equal(_theme.background_of(PROFILE_FIELD, UiTheme.STATE_DEFAULT),
		UiTheme.color_of(UiTheme.TOKEN_INK), "a field's default background is INK")
	assert_equal(UiTheme.CORNER_RADIUS[PROFILE_FIELD], 4, "with a 4 px radius")
	assert_equal(UiTheme.CORNER_RADIUS[PROFILE_PANEL], 8, "against the panel's 8 px")
	assert_equal(UiTheme.CORNER_RADIUS[PROFILE_MODAL], 12, "and the modal's 12 px")


func test_an_unknown_profile_or_state_is_refused_rather_than_defaulted() -> void:
	"""A colour for a state §2.2 does not define would be invented, so it refuses."""
	_theme.background_of(UiTheme.PROFILE_COUNT, UiTheme.STATE_DEFAULT)
	assert_equal(_theme.last_refusal(), UiTheme.REFUSE_UNKNOWN_PROFILE, "an eleventh profile refuses")
	_theme.foreground_of(PROFILE_BUTTON, UiTheme.STATE_COUNT)
	assert_equal(_theme.last_refusal(), UiTheme.REFUSE_UNKNOWN_STATE, "a sixth state refuses")
	assert_almost_equal(_theme.background_of(-1, 0).a, 0.0, "and no colour is returned")


# --- §2.2's typography and targets -----------------------------------------------------------------

func test_no_profile_renders_below_the_minimum_font_size() -> void:
	"""§2.2: "Minimum rendered font size 14 logical pixels"."""
	for profile: int in UiTheme.PROFILE_COUNT:
		assert_true(UiTheme.PROFILE_FONT[profile] >= UiTheme.FONT_MINIMUM,
			"profile %d body text is at least 14" % profile)
		assert_true(UiTheme.PROFILE_TITLE_FONT[profile] >= UiTheme.FONT_MINIMUM,
			"profile %d title text is at least 14" % profile)


func test_the_focus_outline_is_gold_and_thickens_under_high_contrast() -> void:
	"""§2.2's 2 px GOLD focus outline, and §8.1's high_contrast 3 px."""
	var normal: StyleBoxFlat = UiTheme.focus_style(false)
	var high: StyleBoxFlat = UiTheme.focus_style(true)
	assert_equal(normal.border_color, UiTheme.color_of(UiTheme.TOKEN_GOLD), "the outline is GOLD")
	assert_equal(normal.get_border_width(SIDE_TOP), UiTheme.FOCUS_OUTLINE_WIDTH, "2 px normally")
	assert_equal(high.get_border_width(SIDE_TOP), UiTheme.HIGH_CONTRAST_FOCUS_WIDTH,
		"3 px in high contrast")
	assert_false(normal.draw_center, "and it is an outline, not a fill over the control")


func test_a_panel_style_carries_the_profiles_border_and_radius() -> void:
	"""§2.2's "Background / border / radius" column reaches the StyleBox intact."""
	var box: StyleBoxFlat = _theme.panel_style(PROFILE_PANEL, UiTheme.STATE_DEFAULT)
	assert_equal(box.bg_color, UiTheme.color_of(UiTheme.TOKEN_PANEL), "PANEL background")
	assert_equal(box.border_color, UiTheme.color_of(UiTheme.TOKEN_MUTED), "MUTED border")
	assert_equal(box.get_border_width(SIDE_LEFT), 1, "1 px wide")
	assert_equal(box.get_corner_radius(CORNER_TOP_LEFT), 8, "and an 8 px radius")
