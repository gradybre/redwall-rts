extends RefCounted
## SET-UX-001 §2's palette, typography and the five interaction states of every §2.2 profile.
##
## §2.2 is explicit that a profile is a COMPLETE contract: "Each registry row selects one
## profile. This provides font, size weight/color, background opacity/radius, all five
## interaction states, animation, and accessibility defaults. Row-specific constraints override
## only the listed size or label; no other override is implicit." So the state colours live in
## one table here rather than being chosen at each control, and a control that wants a sixth
## state has to change this file, where a reviewer can see it.
##
## ---------------------------------------------------------------------------------------
## THE PALETTE IS STORED AS EXACT 24-BIT HEX, NOT AS ROUNDED FLOATS. §2.1 gives nine computed
## contrast ratios to two decimals -- "TEXT/PANEL 12.20:1; MUTED/PANEL 8.21:1; ..." -- and
## `test_ui_theme.gd` RECOMPUTES all nine from these tokens with the WCAG relative-luminance
## formula and compares them to the document's published figures. A token typed one digit wrong
## moves a ratio by more than the tolerance and fails. Storing `0.117647` instead of `0x1E3028`
## would make that check meaningless.
##
## §2.1 also rules that "All functional panel/text backgrounds are opaque", so every token here
## except SCRIM and SHADOW carries alpha 255, and the two translucent ones are decorative only.
##
## ---------------------------------------------------------------------------------------
## NOTHING HERE READS GAME STATE. This is a style sheet. Its floats are Colors and pixel sizes.

# --- §2.1 tokens ----------------------------------------------------------------------------------

const TOKEN_INK: int = 0
const TOKEN_PANEL: int = 1
const TOKEN_HOVER: int = 2
const TOKEN_PRESSED: int = 3
const TOKEN_TEXT: int = 4
const TOKEN_MUTED: int = 5
const TOKEN_GOLD: int = 6
const TOKEN_SUCCESS: int = 7
const TOKEN_WARNING: int = 8
const TOKEN_DANGER: int = 9
const TOKEN_SCRIM: int = 10
const TOKEN_SHADOW: int = 11
const TOKEN_COUNT: int = 12

const TOKEN_KEYS: Array[StringName] = [
	&"INK", &"PANEL", &"HOVER", &"PRESSED", &"TEXT", &"MUTED",
	&"GOLD", &"SUCCESS", &"WARNING", &"DANGER", &"SCRIM", &"SHADOW",
]

## §2.1's hex column, exactly as written. SCRIM and SHADOW are #000000 with their own alphas.
const TOKEN_RGB: Array[int] = [
	0x14211B, 0x1E3028, 0x2B4638, 0x111C17, 0xF5F0DF, 0xBECABF,
	0xE6C77A, 0x9DD8AF, 0xFFD28A, 0xFFB3AD, 0x000000, 0x000000,
]

## §2.1's alpha column as an integer 0-255. "SCRIM #000000 /0.65"; "SHADOW #000000 /0.30".
const TOKEN_ALPHA: Array[int] = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 166, 77]

const BYTE_MAX: float = 255.0
const RED_SHIFT: int = 16
const GREEN_SHIFT: int = 8
const BYTE_MASK: int = 0xFF

# --- §2.2 interaction states ------------------------------------------------------------------

const STATE_DEFAULT: int = 0
const STATE_HOVER: int = 1
const STATE_PRESSED: int = 2
const STATE_DISABLED: int = 3
const STATE_SELECTED: int = 4
const STATE_COUNT: int = 5

const STATE_KEYS: Array[StringName] = [
	&"default", &"hover", &"pressed", &"disabled", &"selected",
]

const PROFILE_COUNT: int = 10

## Background token per (profile, state), row-major `profile * STATE_COUNT + state`.
## Transcribed from §2.2's "Default, hover, pressed, disabled, selected" column.
const BACKGROUND_TOKEN: Array[int] = [
	TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL,             # PANEL
	TOKEN_PANEL, TOKEN_HOVER, TOKEN_PRESSED, TOKEN_PANEL, TOKEN_GOLD,            # BUTTON
	TOKEN_PANEL, TOKEN_HOVER, TOKEN_PRESSED, TOKEN_PANEL, TOKEN_GOLD,            # TOGGLE
	TOKEN_PANEL, TOKEN_HOVER, TOKEN_PRESSED, TOKEN_PANEL, TOKEN_GOLD,            # ROW
	TOKEN_INK, TOKEN_HOVER, TOKEN_INK, TOKEN_PANEL, TOKEN_INK,                   # FIELD
	TOKEN_PANEL, TOKEN_HOVER, TOKEN_PRESSED, TOKEN_PANEL, TOKEN_PANEL,           # READOUT
	TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL,             # METER
	TOKEN_PANEL, TOKEN_HOVER, TOKEN_PRESSED, TOKEN_PANEL, TOKEN_PANEL,           # NOTICE
	TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL,             # OVERLAY
	TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL, TOKEN_PANEL,             # MODAL
]

## Foreground token per (profile, state). §2.2: disabled text is MUTED and "is not
## opacity-dimmed; its>=4.5:1 contrast remains"; a GOLD selected background takes INK text.
const FOREGROUND_TOKEN: Array[int] = [
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # PANEL
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_INK,                  # BUTTON
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_INK,                  # TOGGLE
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_INK,                  # ROW
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_GOLD,                 # FIELD
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # READOUT
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # METER
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # NOTICE
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # OVERLAY
	TOKEN_TEXT, TOKEN_TEXT, TOKEN_TEXT, TOKEN_MUTED, TOKEN_TEXT,                 # MODAL
]

## §2.2's "Background / border / radius" column: corner radius per profile.
const CORNER_RADIUS: Array[int] = [8, 6, 6, 0, 4, 4, 4, 8, 0, 12]
## Border width per profile. ROW's single pixel is its bottom rule; NOTICE's two are its
## severity token; MODAL's two are MUTED.
const BORDER_WIDTH: Array[int] = [1, 1, 1, 1, 1, 0, 1, 2, 0, 2]

# --- §2.2 typography ------------------------------------------------------------------------------

const FONT_BODY: int = 16
const FONT_LABEL: int = 16
const FONT_SECONDARY: int = 14
const FONT_PANEL_TITLE: int = 20
const FONT_PAGE_TITLE: int = 28
const FONT_COUNTER: int = 18
## "Minimum rendered font size 14 logical pixels; critical message body 16 minimum."
const FONT_MINIMUM: int = 14
const FONT_CRITICAL_MINIMUM: int = 16

## Body font size per profile. READOUT uses the 18/600 numerical counter size.
const PROFILE_FONT: Array[int] = [
	FONT_BODY, FONT_LABEL, FONT_LABEL, FONT_BODY, FONT_BODY,
	FONT_COUNTER, FONT_LABEL, FONT_LABEL, FONT_LABEL, FONT_BODY,
]

## Title font size per profile; only PANEL, NOTICE and MODAL draw a title of their own.
const PROFILE_TITLE_FONT: Array[int] = [
	FONT_PANEL_TITLE, FONT_LABEL, FONT_LABEL, FONT_BODY, FONT_BODY,
	FONT_COUNTER, FONT_LABEL, FONT_LABEL, FONT_LABEL, FONT_PAGE_TITLE,
]

# --- §2.2 hit targets and focus -------------------------------------------------------------------

## "Interactive minimum hitbox 32x32; ordinary buttons 44 px high".
const MINIMUM_HITBOX: int = 32
const ORDINARY_BUTTON_HEIGHT: int = 44
## "destructive confirm 44x120 minimum".
const DESTRUCTIVE_CONFIRM_WIDTH: int = 120
## "Every interactive element has a 2 px GOLD keyboard focus outline offset 2 px".
const FOCUS_OUTLINE_WIDTH: int = 2
const FOCUS_OUTLINE_OFFSET: int = 2
## §8.1 high_contrast: "Adds 2 px MUTED panel borders,3 px GOLD focus".
const HIGH_CONTRAST_FOCUS_WIDTH: int = 3
const HIGH_CONTRAST_BORDER_WIDTH: int = 2

# --- §2.2 animation -------------------------------------------------------------------------------

## Seconds, presentation only. "Show alpha 0->1 over 120 ms"; "hide 80 ms"; "Background colour
## 80 ms linear"; meter fill "interpolates 100 ms linear for presentation".
const SHOW_SECONDS: float = 0.120
const HIDE_SECONDS: float = 0.080
const COLOR_SECONDS: float = 0.080
const METER_FILL_SECONDS: float = 0.100
## "Tooltips wait 350 ms pointer hover or 0 ms keyboard focus".
const TOOLTIP_HOVER_SECONDS: float = 0.350
const TOOLTIP_FOCUS_SECONDS: float = 0.0

# --- WCAG arithmetic ------------------------------------------------------------------------------

const SRGB_LOW_THRESHOLD: float = 0.04045
const SRGB_LOW_DIVISOR: float = 12.92
const SRGB_OFFSET: float = 0.055
const SRGB_SCALE: float = 1.055
const SRGB_EXPONENT: float = 2.4
const LUMA_RED: float = 0.2126
const LUMA_GREEN: float = 0.7152
const LUMA_BLUE: float = 0.0722
const CONTRAST_OFFSET: float = 0.05
## §2.1: "All normal text targets>=4.5:1"; "functional icons/boundaries>=3:1".
const CONTRAST_TEXT_MINIMUM: float = 4.5
const CONTRAST_NON_TEXT_MINIMUM: float = 3.0

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_TOKEN: StringName = &"UI_UNKNOWN_COLOR_TOKEN"
const REFUSE_UNKNOWN_STATE: StringName = &"UI_UNKNOWN_INTERACTION_STATE"
const REFUSE_UNKNOWN_PROFILE: StringName = &"UI_UNKNOWN_PROFILE"

var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Prove every palette and profile column is complete before a control asks for a colour."""
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every token must have a colour, an alpha and a name; every profile all five states."""
	assert(TOKEN_RGB.size() == TOKEN_COUNT and TOKEN_ALPHA.size() == TOKEN_COUNT,
		"every §2.1 token must carry both a hex colour and its alpha")
	assert(TOKEN_KEYS.size() == TOKEN_COUNT and STATE_KEYS.size() == STATE_COUNT,
		"every token and interaction state must be named")
	assert(BACKGROUND_TOKEN.size() == PROFILE_COUNT * STATE_COUNT,
		"every profile must define a background for all five §2.2 states")
	assert(FOREGROUND_TOKEN.size() == PROFILE_COUNT * STATE_COUNT,
		"every profile must define a foreground for all five §2.2 states")
	assert(CORNER_RADIUS.size() == PROFILE_COUNT and BORDER_WIDTH.size() == PROFILE_COUNT,
		"every profile must state its radius and border width")
	assert(PROFILE_FONT.size() == PROFILE_COUNT and PROFILE_TITLE_FONT.size() == PROFILE_COUNT,
		"every profile must state its body and title font size")


static func is_token(token: int) -> bool:
	"""True for a defined §2.1 palette token."""
	return token >= 0 and token < TOKEN_COUNT


static func is_state(state: int) -> bool:
	"""True for one of §2.2's five interaction states."""
	return state >= 0 and state < STATE_COUNT


static func is_profile(profile: int) -> bool:
	"""True for one of §2.2's ten style profiles."""
	return profile >= 0 and profile < PROFILE_COUNT


static func color_of(token: int) -> Color:
	"""The exact §2.1 colour for a token. Callers validate the token first."""
	var rgb: int = TOKEN_RGB[token]
	return Color(float((rgb >> RED_SHIFT) & BYTE_MASK) / BYTE_MAX,
		float((rgb >> GREEN_SHIFT) & BYTE_MASK) / BYTE_MAX,
		float(rgb & BYTE_MASK) / BYTE_MAX,
		float(TOKEN_ALPHA[token]) / BYTE_MAX)


func background_of(profile: int, state: int) -> Color:
	"""The §2.2 background colour for one profile in one interaction state."""
	if not _valid_pair(profile, state):
		return Color(0, 0, 0, 0)
	return color_of(BACKGROUND_TOKEN[profile * STATE_COUNT + state])


func foreground_of(profile: int, state: int) -> Color:
	"""The §2.2 text colour for one profile in one interaction state."""
	if not _valid_pair(profile, state):
		return Color(0, 0, 0, 0)
	return color_of(FOREGROUND_TOKEN[profile * STATE_COUNT + state])


func _valid_pair(profile: int, state: int) -> bool:
	"""Validate a (profile, state) address, recording which half was wrong."""
	if not is_profile(profile):
		return _refuse(REFUSE_UNKNOWN_PROFILE)
	if not is_state(state):
		return _refuse(REFUSE_UNKNOWN_STATE)
	_last_refusal = REFUSE_NONE
	return true


static func relative_luminance(color: Color) -> float:
	"""WCAG 2.2 relative luminance of an sRGB colour, alpha ignored."""
	return LUMA_RED * _linearize(color.r) + LUMA_GREEN * _linearize(color.g) \
		+ LUMA_BLUE * _linearize(color.b)


static func _linearize(channel: float) -> float:
	"""WCAG's per-channel sRGB linearisation."""
	if channel <= SRGB_LOW_THRESHOLD:
		return channel / SRGB_LOW_DIVISOR
	return pow((channel + SRGB_OFFSET) / SRGB_SCALE, SRGB_EXPONENT)


static func contrast_ratio(first: Color, second: Color) -> float:
	"""WCAG 2.2 contrast ratio between two opaque colours, always >= 1.0."""
	var a: float = relative_luminance(first)
	var b: float = relative_luminance(second)
	var high: float = maxf(a, b)
	var low: float = minf(a, b)
	return (high + CONTRAST_OFFSET) / (low + CONTRAST_OFFSET)


static func token_contrast(first_token: int, second_token: int) -> float:
	"""Contrast ratio between two §2.1 tokens, for checking the published figures."""
	return contrast_ratio(color_of(first_token), color_of(second_token))


func panel_style(profile: int, state: int) -> StyleBoxFlat:
	"""One §2.2 StyleBox: opaque background, MUTED border and the profile's corner radius.

	Allocates a StyleBox, so callers build these once at construction and reuse them; nothing
	on a per-frame path calls it.
	"""
	var box: StyleBoxFlat = StyleBoxFlat.new()
	if not _valid_pair(profile, state):
		return box
	box.bg_color = background_of(profile, state)
	box.set_corner_radius_all(CORNER_RADIUS[profile])
	box.set_border_width_all(BORDER_WIDTH[profile])
	box.border_color = color_of(TOKEN_MUTED)
	box.set_content_margin_all(0)
	return box


static func focus_style(high_contrast: bool) -> StyleBoxFlat:
	"""§2.2's keyboard focus outline: 2 px GOLD, or 3 px under the high-contrast setting."""
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color_of(TOKEN_GOLD)
	box.set_border_width_all(HIGH_CONTRAST_FOCUS_WIDTH if high_contrast else FOCUS_OUTLINE_WIDTH)
	box.set_corner_radius_all(0)
	return box


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
