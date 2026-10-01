extends RefCounted
## WCAG 2.2 contrast checks for the demo skin: which text may sit on which surface.
##
## The ratio itself is `ui_theme.gd`'s, reused rather than re-derived, so the demo and the game
## cannot disagree about what 4.5:1 means. What this file adds is the THRESHOLD a given piece of
## text owes -- WCAG's "large text" is 24 px regular or 18.66 px bold (18 pt / 14 pt), which
## earns the 3:1 floor instead of 4.5:1 -- and the checks against a textured face, whose grain
## spans a range of tones rather than one colour.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

## WCAG 2.2 SC 1.4.3 minimums.
const BODY_MINIMUM: float = 4.5
const LARGE_MINIMUM: float = 3.0
## SC 1.4.11: user-interface components and graphical objects (focus rings, track edges).
const NON_TEXT_MINIMUM: float = 3.0
## WCAG's large-text thresholds in CSS pixels: 18 pt regular, 14 pt bold.
const LARGE_REGULAR_PX: float = 24.0
const LARGE_BOLD_PX: float = 18.66


static func ratio(first: Color, second: Color) -> float:
	"""The WCAG contrast ratio between two opaque colours, always >= 1.0."""
	return UiTheme.contrast_ratio(first, second)


static func is_large(font_px: float, bold: bool) -> bool:
	"""True when WCAG counts text of this size and weight as large."""
	return font_px >= (LARGE_BOLD_PX if bold else LARGE_REGULAR_PX)


static func minimum_for(font_px: float, bold: bool) -> float:
	"""The contrast ratio text of this size and weight owes: 3:1 when large, 4.5:1 otherwise."""
	return LARGE_MINIMUM if is_large(font_px, bold) else BODY_MINIMUM


static func passes(text: Color, background: Color, font_px: float, bold: bool) -> bool:
	"""True when text of this size and weight reads against one background colour."""
	return ratio(text, background) >= minimum_for(font_px, bold)


static func worst_ratio(text: Color, backgrounds: PackedColorArray) -> float:
	"""The lowest ratio text reaches over a set of background tones; 0.0 for an empty set."""
	if backgrounds.is_empty():
		return 0.0
	var worst: float = INF
	for background: Color in backgrounds:
		worst = minf(worst, ratio(text, background))
	return worst


static func composite(over: Color, under: Color) -> Color:
	"""A translucent colour laid over an opaque one, as the canvas blends it (source-over)."""
	var alpha: float = clampf(over.a, 0.0, 1.0)
	return Color(lerpf(under.r, over.r, alpha), lerpf(under.g, over.g, alpha),
		lerpf(under.b, over.b, alpha), 1.0)
