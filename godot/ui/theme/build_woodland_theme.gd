extends SceneTree
## Generator for `godot/ui/theme/woodland_theme.tres`, the one Theme the whole UI root uses.
##
## The committed `.tres` is a BUILD PRODUCT of `scripts/ui/ui_theme.gd`'s tokens, not a second
## place where colours are chosen. That is the point: SET-UX-001 §2.1 publishes nine computed
## contrast ratios against ten exact hex values, and a theme hand-edited in the inspector would
## drift from them silently. `test_ui_theme_resource.gd` loads the committed resource and
## compares every colour and font size back to `ui_theme.gd`, so a drifted theme fails the suite.
##
## Run it from the repository root after changing a token:
##     godot --headless --path godot --script ui/theme/build_woodland_theme.gd
##
## §2.1's four vendored font paths are used exactly as written. No system font is ever
## substituted: `_load_font()` fails loudly if a weight is missing, because a silent fallback is
## the one outcome the specification singles out as unacceptable in a qualification build.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

const OUTPUT_PATH: String = "res://ui/theme/woodland_theme.tres"

## §2.1: "Runtime font file paths are res://ui/fonts/NotoSans-Regular.ttf, NotoSans-Medium.ttf,
## NotoSans-SemiBold.ttf, NotoSans-Bold.ttf."
const FONT_REGULAR: String = "res://ui/fonts/NotoSans-Regular.ttf"
const FONT_MEDIUM: String = "res://ui/fonts/NotoSans-Medium.ttf"
const FONT_SEMIBOLD: String = "res://ui/fonts/NotoSans-SemiBold.ttf"
const FONT_BOLD: String = "res://ui/fonts/NotoSans-Bold.ttf"

## Theme type variations, one per §2.2 profile plus the typographic roles §2.2 lists.
const VARIATION_OF_PROFILE: Array[StringName] = [
	&"WoodlandPanel", &"WoodlandButton", &"WoodlandToggle", &"WoodlandRow", &"WoodlandField",
	&"WoodlandReadout", &"WoodlandMeter", &"WoodlandNotice", &"WoodlandOverlay", &"WoodlandModal",
]
## Which built-in Godot type each variation inherits from.
const BASE_OF_PROFILE: Array[StringName] = [
	&"Panel", &"Button", &"Button", &"Button", &"Button",
	&"Button", &"Panel", &"Panel", &"Panel", &"Panel",
]

const LABEL_VARIATIONS: Array[StringName] = [
	&"WoodlandBody", &"WoodlandSecondary", &"WoodlandPanelTitle", &"WoodlandPageTitle",
	&"WoodlandCounter",
]
const LABEL_FONT_SIZES: Array[int] = [
	UiTheme.FONT_BODY, UiTheme.FONT_SECONDARY, UiTheme.FONT_PANEL_TITLE,
	UiTheme.FONT_PAGE_TITLE, UiTheme.FONT_COUNTER,
]
const LABEL_TOKENS: Array[int] = [
	UiTheme.TOKEN_TEXT, UiTheme.TOKEN_MUTED, UiTheme.TOKEN_TEXT, UiTheme.TOKEN_TEXT,
	UiTheme.TOKEN_TEXT,
]

## §2.2's button state names, in the order Godot's Button theme uses them.
const BUTTON_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
const BUTTON_STATE_INDEX: Array[int] = [
	UiTheme.STATE_DEFAULT, UiTheme.STATE_HOVER, UiTheme.STATE_PRESSED, UiTheme.STATE_DISABLED,
]
const BUTTON_COLORS: Array[StringName] = [
	&"font_color", &"font_hover_color", &"font_pressed_color", &"font_disabled_color",
]
## The icon tint per state, so a §2.2 disabled control's lock icon is MUTED like its text.
const ICON_COLORS: Array[StringName] = [
	&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_disabled_color",
]
## Pixels between a control's border and its label, so a §4 label fits its §4 minimum width.
const CONTENT_MARGIN: float = 2.0
## The OpenType tag for tabular figures, which Noto Sans provides.
const TABULAR_FEATURE: String = "tnum"


func _initialize() -> void:
	"""Build the theme from the tokens and write it to the committed path."""
	var theme: Theme = Theme.new()
	var tokens: UiTheme = UiTheme.new()
	_apply_defaults(theme)
	_apply_profiles(theme, tokens)
	_apply_labels(theme)
	var code: int = ResourceSaver.save(theme, OUTPUT_PATH)
	print("THEME %s -> %s (error %d)" % ["saved" if code == OK else "failed", OUTPUT_PATH, code])
	quit(0 if code == OK else 1)


func _apply_defaults(theme: Theme) -> void:
	"""§2.2's body typography as the theme default: Noto Sans Regular at 16."""
	theme.default_font = _load_font(FONT_REGULAR)
	theme.default_font_size = UiTheme.FONT_BODY
	theme.set_font(&"font", &"Label", _load_font(FONT_REGULAR))
	theme.set_font_size(&"font_size", &"Label", UiTheme.FONT_BODY)
	theme.set_color(&"font_color", &"Label", UiTheme.color_of(UiTheme.TOKEN_TEXT))
	theme.set_font(&"font", &"Button", _load_font(FONT_SEMIBOLD))
	theme.set_font_size(&"font_size", &"Button", UiTheme.FONT_LABEL)


func _apply_profiles(theme: Theme, tokens: UiTheme) -> void:
	"""One variation per §2.2 profile, carrying all five of its interaction states."""
	for profile: int in UiTheme.PROFILE_COUNT:
		var variation: StringName = VARIATION_OF_PROFILE[profile]
		var base: StringName = BASE_OF_PROFILE[profile]
		theme.set_type_variation(variation, base)
		if base == &"Button":
			_apply_button_variation(theme, tokens, variation, profile)
		else:
			theme.set_stylebox(&"panel", variation,
				_style(tokens, profile, UiTheme.STATE_DEFAULT))
		theme.set_font_size(&"font_size", variation, UiTheme.PROFILE_FONT[profile])


func _apply_button_variation(theme: Theme, tokens: UiTheme, variation: StringName,
		profile: int) -> void:
	"""Give one button-based variation §2.2's four drawn states plus the GOLD focus outline.

	A TOGGLE's Godot `pressed` slot is its SELECTED state, not a transient push: Godot draws a
	latched toggle with `pressed`, and §2.2 says a selected toggle is "GOLD/INK+check". Mapping
	it to the PRESSED token instead would leave a selected speed button looking unselected.
	"""
	for index: int in BUTTON_STATES.size():
		var state: int = BUTTON_STATE_INDEX[index]
		if profile == UiRegistry.PROFILE_TOGGLE and state == UiTheme.STATE_PRESSED:
			state = UiTheme.STATE_SELECTED
		theme.set_stylebox(BUTTON_STATES[index], variation, _style(tokens, profile, state))
		theme.set_color(BUTTON_COLORS[index], variation, tokens.foreground_of(profile, state))
		theme.set_color(ICON_COLORS[index], variation, tokens.foreground_of(profile, state))
	theme.set_stylebox(&"focus", variation, UiTheme.focus_style(false))
	if profile == UiRegistry.PROFILE_READOUT:
		theme.set_font(&"font", variation, _tabular_font(FONT_SEMIBOLD))
		return
	theme.set_font(&"font", variation, _load_font(_font_for_profile(profile)))


func _apply_labels(theme: Theme) -> void:
	"""§2.2's typographic roles: body 16, secondary 14, panel title 20, page title 28,
	counter 18 with tabular numbers."""
	for index: int in LABEL_VARIATIONS.size():
		var variation: StringName = LABEL_VARIATIONS[index]
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size(&"font_size", variation, LABEL_FONT_SIZES[index])
		theme.set_color(&"font_color", variation, UiTheme.color_of(LABEL_TOKENS[index]))
		if LABEL_FONT_SIZES[index] == UiTheme.FONT_COUNTER:
			theme.set_font(&"font", variation, _tabular_font(_font_for_label(index)))
			continue
		theme.set_font(&"font", variation, _load_font(_font_for_label(index)))


func _font_for_profile(profile: int) -> String:
	"""§2.2's weights: label text is 600 semibold, body text is 400 regular."""
	if profile == UiRegistry.PROFILE_PANEL or profile == UiRegistry.PROFILE_MODAL:
		return FONT_REGULAR
	if profile == UiRegistry.PROFILE_METER:
		return FONT_MEDIUM
	return FONT_SEMIBOLD


func _font_for_label(index: int) -> String:
	"""Secondary text is 400; titles and counters are 600; the page title is 700."""
	if index == 3:
		return FONT_BOLD
	if index == 2 or index == 4:
		return FONT_SEMIBOLD
	return FONT_REGULAR


func _style(tokens: UiTheme, profile: int, state: int) -> StyleBoxFlat:
	"""One §2.2 StyleBox with the content margin a §4-sized label needs."""
	var box: StyleBoxFlat = tokens.panel_style(profile, state)
	box.set_content_margin_all(CONTENT_MARGIN)
	return box


func _tabular_font(path: String) -> FontVariation:
	"""§2.2's "numerical counter 18/600/TEXT with tabular numbers".

	Tabular figures are an OpenType feature of the vendored file, not a second font: a counter
	whose digits change width makes a steady number look like a moving one.
	"""
	var variation: FontVariation = FontVariation.new()
	variation.base_font = _load_font(path)
	variation.opentype_features = {TABULAR_FEATURE: 1}
	return variation


func _load_font(path: String) -> FontFile:
	"""Load one vendored weight. A missing weight is fatal: §2.1 forbids a system fallback."""
	var font: FontFile = load(path) as FontFile
	assert(font != null, "§2.1's vendored font is missing: %s" % path)
	return font
