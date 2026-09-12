extends RefCounted
## UI-IDENTITY-R01's resident identity row, stated as arithmetic and nothing else.
##
## The 2026-09-12 ruling replaces the composition that put the medallion ABOVE the name. Its
## reason is quoted exactly, because the geometry only makes sense against it: "With a 280px
## NAME column the row would require 388px Narrow or 404px Standard/Wide inside available
## 280/296/344px: over by 108/108/60px. The conflict is resolved by a flexible heading, not by
## pretending the old minimum fits."
##
## The adopted row, in logical UI pixels with the existing scale S applied ONCE by the shell's
## own canvas transform:
##
##     20 inset | medallion | 8 gap | name/species column | 8 gap | 44 Close | 20 inset
##
## | Profile  | Panel | Inner | Medallion | Name column | Close |
## | NARROW   |  320  |  280  |    48     |     172     |  44   |
## | STANDARD |  336  |  296  |    64     |     172     |  44   |
## | WIDE     |  384  |  344  |    64     |     220     |  44   |
##
## ---------------------------------------------------------------------------------------
## WHY THE TABLE IS WRITTEN OUT AND ALSO DERIVED. `derived_name_column_width()` computes the
## same number from the panel width and the inherited insets/gaps/Close. `is_consistent()`
## proves the two agree for all three profiles, and `_init()` asserts it. A transcription slip
## in either the table or the derivation therefore fails loudly instead of drawing a name
## column eight pixels into Close.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS FILE DELIBERATELY DOES NOT DO. It sets no minimum width on anything. UI-SET-037's
## §4 minimum of 280 is overridden FOR THIS INSTANCE by the ruling -- "in this resident template
## its intrinsic minimum width is 0; allocate exactly the remaining 172/172/220px" -- and the
## way to honour that is to allocate a rectangle, never to clamp a Control up to a floor. Other
## full-width UI-SET-037 uses keep their own layout; this is not a global shrink of all titles.
##
## It also measures no text. Height comes IN as a measured text-block height from the shell,
## which owns the fonts, so this file stays testable without a font server and cannot invent a
## line height for Noto Serif 20/600.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")

# --- the inherited frame ------------------------------------------------------------------

## §4.1's "reference's 20 px side insets", inherited unchanged.
const INSET: float = 20.0
## §1.2's 8 px grid, which the ruling spends twice across the identity row.
const GAP: float = 8.0
## §2.2's 44 px pointer target, which Close keeps at the row's right edge.
const CLOSE_SIZE: float = 44.0
## §4.1's "64 px center-action footer" and its "Center view is 44 high".
const FOOTER_HEIGHT: float = 64.0
const FOOTER_ACTION_HEIGHT: float = 44.0
## §4.1's "16 px section separation", between the identity block and what follows it.
const SECTION_GAP: float = 16.0

# --- UI-IDENTITY-R01's own table ----------------------------------------------------------

## ART-LOCK-001's production medallion sizes, chosen per profile by the ruling's table. NARROW
## takes the 48 px roundel; STANDARD and WIDE both take 64.
const MEDALLION_PIXELS: Array[int] = [48, 64, 64]
## The name/species column, allocated exactly. Not a minimum and not a preference.
const NAME_COLUMN_WIDTH: Array[float] = [172.0, 172.0, 220.0]
## §1.2's detail widths, restated so this file can check its own table without a Geometry.
const PANEL_WIDTH: Array[float] = [320.0, 336.0, 384.0]
## Panel width less the two 20 px insets: the ruling's "Inner" column.
const INNER_WIDTH: Array[float] = [280.0, 296.0, 344.0]

## Space between the name heading and the species/status line BENEATH it, inside one text
## block. §1.2 publishes one spacing unit smaller than the 16 px section separation -- "grid
## spacing 8" -- and the two lines are one block rather than two sections, so the block uses
## the grid unit. No new spacing value is introduced by this ruling and none is invented here.
const TEXT_LINE_GAP: float = GAP


func _init() -> void:
	"""Prove the published table and the derivation agree before any rectangle is computed."""
	assert(is_consistent(), "UI-IDENTITY-R01's name column must equal its own derivation")


static func is_profile(profile: int) -> bool:
	"""True for one of §1.2's three layout profiles, which the ruling's table is keyed on."""
	return profile >= 0 and profile < UiLayout.PROFILE_COUNT


static func medallion_pixels(profile: int) -> int:
	"""ART-LOCK-001's medallion size for a profile: 48 at NARROW, 64 at STANDARD and WIDE."""
	return MEDALLION_PIXELS[profile] if is_profile(profile) else 0


static func name_column_width(profile: int) -> float:
	"""The ruling's allocated name/species column: 172, 172 or 220 logical pixels."""
	return NAME_COLUMN_WIDTH[profile] if is_profile(profile) else 0.0


static func derived_name_column_width(profile: int) -> float:
	"""The same column computed from the row equation, for `is_consistent()` to check against.

	`panel - inset - medallion - gap - gap - close - inset`, which is the ruling's row read
	left to right. It is a second opinion about one number, not a second source of truth.
	"""
	if not is_profile(profile):
		return 0.0
	return PANEL_WIDTH[profile] - 2.0 * INSET - float(MEDALLION_PIXELS[profile]) \
		- 2.0 * GAP - CLOSE_SIZE


static func is_consistent() -> bool:
	"""True when the published name column equals the derivation, and inner equals panel-40."""
	for profile: int in UiLayout.PROFILE_COUNT:
		if not is_equal_approx(NAME_COLUMN_WIDTH[profile], derived_name_column_width(profile)):
			return false
		if not is_equal_approx(INNER_WIDTH[profile], PANEL_WIDTH[profile] - 2.0 * INSET):
			return false
		if not is_equal_approx(PANEL_WIDTH[profile], float(UiLayout.DETAIL_W[profile])):
			return false
	return true


static func medallion_rect(profile: int) -> Rect2:
	"""The medallion, at the top-left of the identity block. Decoration: no hit or focus target."""
	var pixels: float = float(medallion_pixels(profile))
	return Rect2(INSET, INSET, pixels, pixels)


static func name_column_left(profile: int) -> float:
	"""Where the name/species column starts: past the inset, the medallion and one 8 px gap."""
	if not is_profile(profile):
		return 0.0
	return INSET + float(MEDALLION_PIXELS[profile]) + GAP


static func close_rect(profile: int, panel_width: float) -> Rect2:
	"""Close's 44x44 hit rectangle at the row's right edge, aligned with the block's top.

	Anchored to the panel's actual right edge rather than to the table, so a panel that is not
	the profile's nominal width still puts Close 20 px inside it instead of somewhere the
	pointer is not.
	"""
	if not is_profile(profile):
		return Rect2()
	return Rect2(panel_width - INSET - CLOSE_SIZE, INSET, CLOSE_SIZE, CLOSE_SIZE)


static func identity_height(profile: int, text_block_height: float) -> float:
	"""The ruling's measurement: the MAXIMUM of medallion, whole text block and Close.

	`text_block_height` is the complete name-plus-secondary block the shell measured, including
	`TEXT_LINE_GAP`. Taking the maximum is what lets a three-line name grow the header rather
	than run under the medallion or behind Close.
	"""
	if not is_profile(profile):
		return 0.0
	return maxf(maxf(float(MEDALLION_PIXELS[profile]), text_block_height), CLOSE_SIZE)


static func text_block_height(heading_height: float, secondary_height: float) -> float:
	"""One name-plus-secondary block: the heading, the declared line gap and the secondary line.

	A secondary line the store could not supply is zero high and takes no gap with it, so an
	omitted life-stage does not leave an 8 px hole under the name.
	"""
	if secondary_height <= 0.0:
		return maxf(heading_height, 0.0)
	return maxf(heading_height, 0.0) + TEXT_LINE_GAP + secondary_height


static func footer_top(panel_height: float) -> float:
	"""Where §4.1's fixed 64 px action footer begins inside the detail panel."""
	return panel_height - FOOTER_HEIGHT


static func footer_action_rect(panel_width: float, panel_height: float) -> Rect2:
	"""Center view: 44 high, centred in the 64 px footer, inside the inherited 20 px insets."""
	var width: float = maxf(0.0, panel_width - 2.0 * INSET)
	return Rect2(INSET, footer_top(panel_height) + (FOOTER_HEIGHT - FOOTER_ACTION_HEIGHT) / 2.0,
		width, FOOTER_ACTION_HEIGHT)


static func body_height(panel_height: float, header_bottom: float) -> float:
	"""What is left for the scrolling body between the grown header and the fixed footer.

	Never negative. Zero is the honest answer when the fixed header and footer have consumed
	the panel, and `body_is_starved()` is how a caller asks about that case by name rather
	than by comparing a float against zero at every call site.
	"""
	return maxf(0.0, footer_top(panel_height) - header_bottom)


static func body_is_starved(panel_height: float, header_bottom: float) -> bool:
	"""True when the fixed header and footer leave the body no room at all.

	The ruling: "Fit must be checked at the minimum logical viewport; fixed header/footer may
	not consume the whole body." This reports that condition; it does not silently shrink the
	header to hide it.
	"""
	return body_height(panel_height, header_bottom) <= 0.0
