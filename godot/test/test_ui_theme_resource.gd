extends "res://test/framework/test_case.gd"
## Coverage for the committed Theme, the vendored fonts and the authored icon set.
##
## `woodland_theme.tres` is a build product of `scripts/ui/ui_theme.gd`'s §2.1 tokens. That is
## only worth anything if drift is caught, so every colour and size asserted below is read back
## out of the committed resource and compared to the tokens. A theme edited by hand in the
## inspector, or left stale after a token changed, fails here.
##
## ---------------------------------------------------------------------------------------
## THE FOUR FONT WEIGHTS ARE CHECKED BY THEIR OWN NAME TABLES. §2.1: "No OS font substitution in
## qualification builds", and the visual direction adds "never rename a regular font to pretend
## it is semibold". A renamed file would load, render and look almost right; the only thing that
## gives it away is the font's own style name and weight, which is what is asserted here.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")

const THEME_PATH: String = "res://ui/theme/woodland_theme.tres"

## §2.1's four runtime font paths, quoted, with the style name and weight each file must report.
const VENDORED_FONTS: Array = [
	["res://ui/fonts/NotoSans-Regular.ttf", "Regular", 400],
	["res://ui/fonts/NotoSans-Medium.ttf", "Medium", 500],
	["res://ui/fonts/NotoSans-SemiBold.ttf", "SemiBold", 600],
	["res://ui/fonts/NotoSans-Bold.ttf", "Bold", 700],
]
const FONT_FAMILY: String = "Noto Sans"

## The variation the shell selects for each §2.2 profile, in registry profile order.
const PROFILE_VARIATIONS: Array[StringName] = [
	&"WoodlandPanel", &"WoodlandButton", &"WoodlandToggle", &"WoodlandRow", &"WoodlandField",
	&"WoodlandReadout", &"WoodlandMeter", &"WoodlandNotice", &"WoodlandOverlay", &"WoodlandModal",
]
## Which variations are Button-based, and so carry four drawn states rather than one panel.
const BUTTON_VARIATIONS: Array[StringName] = [
	&"WoodlandButton", &"WoodlandToggle", &"WoodlandRow", &"WoodlandField", &"WoodlandReadout",
]

## §2.2's typographic roles and their sizes, quoted independently of the generator.
const LABEL_SIZES: Array = [
	[&"WoodlandBody", 16], [&"WoodlandSecondary", 14], [&"WoodlandPanelTitle", 20],
	[&"WoodlandPageTitle", 28], [&"WoodlandCounter", 18],
]

const ICON_DIRECTORY: String = "res://ui/icons/"
const ORNAMENT_PATH: String = "res://ui/ornaments/sprig.svg"
const LOCK_PATH: String = "res://ui/icons/lock.svg"
const WARNING_PATH: String = "res://ui/icons/warning.svg"

var _theme: Theme = null
var _tokens: UiTheme = null


func before_each() -> void:
	"""Load the committed theme and the token module it was generated from."""
	_theme = load(THEME_PATH) as Theme
	_tokens = UiTheme.new()


func after_each() -> void:
	"""Drop both so nothing crosses a test boundary."""
	_theme = null
	_tokens = null


# --- the vendored fonts ---------------------------------------------------------------------------

func test_all_four_weights_are_present_at_the_specified_paths() -> void:
	"""§2.1 names four exact runtime paths; every one of them must resolve to a real font."""
	for row: Array in VENDORED_FONTS:
		var font: FontFile = load(row[0]) as FontFile
		assert_not_null(font, "%s is vendored" % row[0])
		assert_true(font.get_font_name().begins_with(FONT_FAMILY),
			"%s is a Noto Sans file, got '%s'" % [row[0], font.get_font_name()])


func test_each_file_reports_its_own_weight_rather_than_a_renamed_regular() -> void:
	"""A renamed file renders almost right; its own name table is what gives it away."""
	for row: Array in VENDORED_FONTS:
		var font: FontFile = load(row[0]) as FontFile
		assert_equal(font.get_font_style_name(), row[1],
			"%s reports style '%s'" % [row[0], row[1]])
		assert_equal(font.get_font_weight(), row[2],
			"%s reports weight %d" % [row[0], row[2]])


func test_the_four_weights_are_four_distinct_files() -> void:
	"""Four paths pointing at one file would pass a style check only if the names were faked."""
	var weights: Dictionary = {}
	for row: Array in VENDORED_FONTS:
		var font: FontFile = load(row[0]) as FontFile
		assert_false(weights.has(font.get_font_weight()), "weight %d appears once" % row[2])
		weights[font.get_font_weight()] = row[0]
	assert_equal(weights.size(), VENDORED_FONTS.size(), "four distinct weights are vendored")


func test_the_font_licence_travels_with_the_files() -> void:
	"""The OFL text must be in the repository beside the fonts it covers."""
	var licence: FileAccess = FileAccess.open("res://ui/fonts/OFL.txt", FileAccess.READ)
	assert_not_null(licence, "OFL.txt is vendored alongside the fonts")
	var text: String = licence.get_as_text()
	assert_true(text.contains("SIL Open Font License"), "and it is the SIL OFL")
	assert_true(text.contains("Noto Project Authors"), "for the Noto Project Authors' fonts")


# --- the committed theme --------------------------------------------------------------------------

func test_the_theme_loads_and_carries_section_two_twos_body_typography() -> void:
	"""§2.2's body text is 16/400; that is the theme default every control inherits."""
	assert_not_null(_theme, "the committed theme loads")
	assert_equal(_theme.default_font_size, UiTheme.FONT_BODY, "the default size is 16")
	assert_not_null(_theme.default_font, "and a default font is set")
	assert_equal((_theme.default_font as FontFile).get_font_style_name(), "Regular",
		"which is the 400 weight")


func test_every_profile_has_a_variation_in_the_committed_theme() -> void:
	"""Ten §2.2 profiles, ten variations; a missing one would silently fall back to Godot's."""
	for profile: int in UiRegistry.PROFILE_COUNT:
		var variation: StringName = PROFILE_VARIATIONS[profile]
		assert_true(_theme.is_type_variation(variation, &"Button")
			or _theme.is_type_variation(variation, &"Panel"),
			"%s is a registered variation" % variation)


func test_every_button_state_background_matches_the_token_it_was_built_from() -> void:
	"""The whole point of generating the theme: no colour may drift from §2.1's tokens."""
	for profile: int in UiRegistry.PROFILE_COUNT:
		var variation: StringName = PROFILE_VARIATIONS[profile]
		if not BUTTON_VARIATIONS.has(variation):
			continue
		_assert_state_color(variation, &"normal", profile, UiTheme.STATE_DEFAULT)
		_assert_state_color(variation, &"hover", profile, UiTheme.STATE_HOVER)
		_assert_state_color(variation, &"pressed", profile, UiTheme.STATE_PRESSED)
		_assert_state_color(variation, &"disabled", profile, UiTheme.STATE_DISABLED)


func _assert_state_color(variation: StringName, box_name: StringName, profile: int,
		state: int) -> void:
	"""One state's background colour in the committed theme must equal the token's.

	A TOGGLE's `pressed` slot carries its SELECTED colour, because Godot draws a latched toggle
	with `pressed` and §2.2 says a selected toggle is GOLD. That substitution is made here too,
	so the check follows the specification rather than the slot name.
	"""
	if variation == &"WoodlandToggle" and state == UiTheme.STATE_PRESSED:
		state = UiTheme.STATE_SELECTED
	var box: StyleBoxFlat = _theme.get_stylebox(box_name, variation) as StyleBoxFlat
	assert_not_null(box, "%s has a %s stylebox" % [variation, box_name])
	assert_equal(box.bg_color, _tokens.background_of(profile, state),
		"%s %s background is the §2.1 token" % [variation, box_name])


func test_a_selected_toggle_is_gold_with_ink_text() -> void:
	"""§2.2's TOGGLE row: "selected GOLD/INK+check". Cream on gold would be 1.4:1."""
	var box: StyleBoxFlat = _theme.get_stylebox(&"pressed", &"WoodlandToggle") as StyleBoxFlat
	assert_equal(box.bg_color, UiTheme.color_of(UiTheme.TOKEN_GOLD), "a selected toggle is GOLD")
	assert_equal(_theme.get_color(&"font_pressed_color", &"WoodlandToggle"),
		UiTheme.color_of(UiTheme.TOKEN_INK), "with INK text")
	assert_true(UiTheme.token_contrast(UiTheme.TOKEN_INK, UiTheme.TOKEN_GOLD)
		>= UiTheme.CONTRAST_TEXT_MINIMUM, "which is §2.1's 10.15:1 pair")


func test_disabled_text_in_the_theme_is_muted_and_still_readable() -> void:
	"""§2.2: "Disabled text is not opacity-dimmed; its>=4.5:1 contrast remains"."""
	for variation: StringName in BUTTON_VARIATIONS:
		var color: Color = _theme.get_color(&"font_disabled_color", variation)
		var background: Color = (_theme.get_stylebox(&"disabled", variation)
			as StyleBoxFlat).bg_color
		assert_almost_equal(color.a, 1.0, "%s disabled text is opaque" % variation)
		assert_true(UiTheme.contrast_ratio(color, background) >= UiTheme.CONTRAST_TEXT_MINIMUM,
			"%s disabled text still meets 4.5:1" % variation)


func test_the_focus_outline_in_the_theme_is_the_gold_two_pixel_rule() -> void:
	"""§2.2: "a 2 px GOLD keyboard focus outline offset 2 px", on every interactive variation."""
	for variation: StringName in BUTTON_VARIATIONS:
		var box: StyleBoxFlat = _theme.get_stylebox(&"focus", variation) as StyleBoxFlat
		assert_not_null(box, "%s has a focus stylebox" % variation)
		assert_equal(box.border_color, UiTheme.color_of(UiTheme.TOKEN_GOLD),
			"%s focus is GOLD" % variation)
		assert_equal(box.get_border_width(SIDE_TOP), UiTheme.FOCUS_OUTLINE_WIDTH,
			"%s focus is 2 px" % variation)
		assert_false(box.draw_center, "%s focus is an outline, not a fill" % variation)


func test_the_typographic_roles_carry_their_documented_sizes() -> void:
	"""§2.2: body 16, secondary 14, panel title 20, page title 28, counter 18."""
	for row: Array in LABEL_SIZES:
		assert_equal(_theme.get_font_size(&"font_size", row[0]), row[1],
			"%s is %d px" % [row[0], row[1]])


func test_the_counter_role_uses_tabular_figures() -> void:
	"""§2.2: "numerical counter 18/600/TEXT with tabular numbers"."""
	var font: FontVariation = _theme.get_font(&"font", &"WoodlandCounter") as FontVariation
	assert_not_null(font, "the counter role uses a font variation")
	assert_true(font.opentype_features.has("tnum"), "with the tabular-figures feature")
	assert_equal((font.base_font as FontFile).get_font_style_name(), "SemiBold",
		"over the 600 weight §2.2 asks for")


func test_the_readout_profile_also_uses_tabular_figures() -> void:
	"""The resource counters are READOUT controls, and their digits must not shift width."""
	var font: FontVariation = _theme.get_font(&"font", &"WoodlandReadout") as FontVariation
	assert_not_null(font, "the readout variation uses a font variation")
	assert_true(font.opentype_features.has("tnum"), "with tabular figures")


# --- the authored icon set --------------------------------------------------------------------

func test_every_icon_the_shell_names_exists() -> void:
	"""A missing icon would leave a control with no glyph and no error."""
	for id: int in UiShell.ICON_OF_ELEMENT:
		var path: String = "%s%s.svg" % [ICON_DIRECTORY, UiShell.ICON_OF_ELEMENT[id]]
		assert_true(ResourceLoader.exists(path), "UI-SET-%03d's icon %s exists" % [id, path])
		assert_not_null(load(path) as Texture2D, "and it loads as a texture")


func test_the_disabled_lock_and_the_refusal_warning_are_present() -> void:
	"""§2.2's lock and §7's severity icon are both required by the specification."""
	assert_not_null(load(LOCK_PATH) as Texture2D, "the lock icon exists")
	assert_not_null(load(WARNING_PATH) as Texture2D, "the warning icon exists")
	assert_not_null(load(ORNAMENT_PATH) as Texture2D, "the sprig ornament exists")


func test_the_icons_are_authored_on_the_documented_grid() -> void:
	"""The visual direction's starting grid: 24x24 with nominal 2 px strokes."""
	for id: int in UiShell.ICON_OF_ELEMENT:
		var texture: Texture2D = load("%s%s.svg" % [ICON_DIRECTORY,
			UiShell.ICON_OF_ELEMENT[id]]) as Texture2D
		assert_equal(texture.get_width(), 24, "%s is 24 wide" % UiShell.ICON_OF_ELEMENT[id])
		assert_equal(texture.get_height(), 24, "%s is 24 high" % UiShell.ICON_OF_ELEMENT[id])
