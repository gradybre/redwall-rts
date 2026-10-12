extends RefCounted
## UI-BUILD-001 "Geometry" (docs/ui_ux_controls.md, DEC-061): the build panel, the level bar and the connector card,
## and the panel's inner rows, in LOGICAL pixels from the HUD's own §1.2 rectangles (ui_layout.gd Geometry). Pure and
## static: every number below is the section's, and test_build_layout.gd checks the section's worked figures (1280×720,
## 1920×1080 and the narrowest 853.33 × 480).
##
##   Build panel   left = Mw + 32, right = Lw − 16 (the BR detail is closed while it is open),
##                 width = min(912, right − left), x = left + (right − left − width)/2, y = Lh − 16 − 256, height 256.
##   Inside        12 px padding; tabs row 44 high at y 12; content row 128 high at y 64 (info card 208 wide, 160 in
##                 NARROW, then cards 8 px apart); footer 44 high at y 200 (ledger, Undo, Redo, Discard all, Confirm all).
##   Level bar     x = 16, width = Mw; 2 columns × 3 rows of buttons 44 high (32 in NARROW), 4 px gaps, so Hb = 140
##                 (104); y = Lh − 16 − Mh − 8 − Hb with the minimap shown, or Lh − 16 − 44 − 8 − Hb hidden.
##   Connector     STANDARD/WIDE: right edge on the panel's, bottom 8 px above its top; NARROW: inside the content row.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const SAFE_INSET: float = 16.0
const PANEL_LEFT_GAP: float = 32.0
const PANEL_MAX_WIDTH: float = 912.0
const PANEL_HEIGHT: float = 256.0
const PADDING: float = 12.0
const TABS_Y: float = 12.0
const ROW_HEIGHT: float = 44.0
const CONTENT_Y: float = 64.0
const CONTENT_HEIGHT: float = 128.0
const FOOTER_Y: float = 200.0
const GAP: float = 8.0
## Info card width by §1.2 profile (NARROW, STANDARD, WIDE).
const INFO_WIDTH: Array[int] = [160, 208, 208]
## UI-BUILD-002/003: tab and card widths, minimum and maximum.
const TAB_MIN_WIDTH: float = 96.0
const TAB_MAX_WIDTH: float = 160.0
const CARD_MIN_WIDTH: float = 136.0
const CARD_MAX_WIDTH: float = 208.0
## UI-BUILD-005..009 footer widths, minimum -> maximum.
const LEDGER_MIN_WIDTH: float = 120.0
const LEDGER_MAX_WIDTH: float = 520.0
const UNDO_MIN_WIDTH: float = 44.0
const UNDO_MAX_WIDTH: float = 96.0
const DISCARD_MIN_WIDTH: float = 96.0
const DISCARD_MAX_WIDTH: float = 160.0
const CONFIRM_MIN_WIDTH: float = 120.0
const CONFIRM_MAX_WIDTH: float = 240.0
## UI-BUILD-005 expanded: 320×160 -> 640×320, growing upward from the footer.
const LEDGER_OPEN_MIN: Vector2 = Vector2(320.0, 160.0)
const LEDGER_OPEN_MAX: Vector2 = Vector2(640.0, 320.0)
## The level bar.
const LEVEL_COLUMNS: int = 2
const LEVEL_ROWS: int = 3
const LEVEL_GAP: float = 4.0
const LEVEL_BUTTON_HEIGHT: Array[int] = [32, 44, 44]
const MINIMAP_GAP: float = 8.0
## The minimap's restore control's height when the map is hidden (§1.2's 44 px row).
const RESTORE_HEIGHT: float = 44.0
## UI-BUILD-012.
const CONNECTOR_SIZE: Vector2 = Vector2(280.0, 136.0)
const CONNECTOR_NARROW: Vector2 = Vector2(280.0, 128.0)


static func panel_rect(geometry: UiLayout.Geometry) -> Rect2:
	"""UI-BUILD-001's rectangle (see the header)."""
	var left: float = geometry.minimap.size.x + PANEL_LEFT_GAP
	var right: float = geometry.logical_width - SAFE_INSET
	var available: float = right - left
	var width: float = minf(PANEL_MAX_WIDTH, available)
	return Rect2(left + (available - width) / 2.0, geometry.logical_height - SAFE_INSET - PANEL_HEIGHT, width, PANEL_HEIGHT)


static func level_bar_height(profile: int) -> float:
	"""Hb: three rows of level buttons and their two gaps -- 140, or 104 in NARROW."""
	return LEVEL_ROWS * level_button_height(profile) + (LEVEL_ROWS - 1) * LEVEL_GAP


static func level_button_height(profile: int) -> float:
	"""A level button's height: 44, or 32 in NARROW."""
	return float(LEVEL_BUTTON_HEIGHT[clampi(profile, 0, LEVEL_BUTTON_HEIGHT.size() - 1)])


static func level_bar_rect(geometry: UiLayout.Geometry, minimap_shown: bool) -> Rect2:
	"""UI-BUILD-013's rectangle: above the minimap, or above its restore control when the map is hidden."""
	var height: float = level_bar_height(geometry.profile)
	var below: float = geometry.minimap.size.y if minimap_shown else RESTORE_HEIGHT
	var y: float = geometry.logical_height - SAFE_INSET - below - MINIMAP_GAP - height
	return Rect2(SAFE_INSET, y, geometry.minimap.size.x, height)


static func level_button_rect(bar: Rect2, index: int, profile: int) -> Rect2:
	"""UI-BUILD-014 `index` (0 Surface, 1-4 the levels, 5 Overview) inside the bar, in reading order, bar-local."""
	var height: float = level_button_height(profile)
	var width: float = (bar.size.x - (LEVEL_COLUMNS - 1) * LEVEL_GAP) / LEVEL_COLUMNS
	@warning_ignore("integer_division") var row: int = index / LEVEL_COLUMNS
	var column: int = index % LEVEL_COLUMNS
	return Rect2(column * (width + LEVEL_GAP), row * (height + LEVEL_GAP), width, height)


static func connector_rect(geometry: UiLayout.Geometry) -> Rect2:
	"""UI-BUILD-012: above the panel's top-right edge, or inside its content row in NARROW."""
	var panel: Rect2 = panel_rect(geometry)
	if geometry.profile == UiLayout.PROFILE_NARROW:
		return Rect2(panel.position + Vector2(PADDING, CONTENT_Y), CONNECTOR_NARROW)
	return Rect2(panel.end.x - CONNECTOR_SIZE.x, panel.position.y - GAP - CONNECTOR_SIZE.y, CONNECTOR_SIZE.x, CONNECTOR_SIZE.y)


static func info_width(profile: int) -> float:
	"""UI-BUILD-004's width: 208, or 160 in NARROW."""
	return float(INFO_WIDTH[clampi(profile, 0, INFO_WIDTH.size() - 1)])


static func tabs_rect(panel_width: float) -> Rect2:
	"""The tabs row, panel-local."""
	return Rect2(PADDING, TABS_Y, panel_width - 2.0 * PADDING, ROW_HEIGHT)


static func info_rect(profile: int) -> Rect2:
	"""The info card, panel-local: the content row's left."""
	return Rect2(PADDING, CONTENT_Y, info_width(profile), CONTENT_HEIGHT)


static func cards_rect(panel_width: float, profile: int) -> Rect2:
	"""The card row, panel-local: the rest of the content row after the info card and a gap."""
	var x: float = PADDING + info_width(profile) + GAP
	return Rect2(x, CONTENT_Y, maxf(panel_width - PADDING - x, 0.0), CONTENT_HEIGHT)


static func footer_rect(panel_width: float) -> Rect2:
	"""The footer, panel-local."""
	return Rect2(PADDING, FOOTER_Y, panel_width - 2.0 * PADDING, ROW_HEIGHT)


static func footer_widths_into(footer_width: float, out: PackedFloat32Array) -> void:
	"""The footer's five widths [ledger, Undo, Redo, Discard all, Confirm all], 8 px apart: the buttons at their
	maximum where they fit with the ledger's minimum, else at their minimum; the ledger takes what remains (up to 520)."""
	if out.size() != 5:
		out.resize(5)
	var gaps: float = 4.0 * GAP
	var wide: float = 2.0 * UNDO_MAX_WIDTH + DISCARD_MAX_WIDTH + CONFIRM_MAX_WIDTH
	var narrow: float = 2.0 * UNDO_MIN_WIDTH + DISCARD_MIN_WIDTH + CONFIRM_MIN_WIDTH
	var big: bool = footer_width - gaps - wide >= LEDGER_MIN_WIDTH
	out[1] = UNDO_MAX_WIDTH if big else UNDO_MIN_WIDTH
	out[2] = out[1]
	out[3] = DISCARD_MAX_WIDTH if big else DISCARD_MIN_WIDTH
	out[4] = CONFIRM_MAX_WIDTH if big else CONFIRM_MIN_WIDTH
	out[0] = clampf(footer_width - gaps - (wide if big else narrow), 0.0, LEDGER_MAX_WIDTH)


static func ledger_open_size(lines: int, line_height: float, profile: int) -> Vector2:
	"""UI-BUILD-005 expanded: 320×160 at least, its lines' height plus padding, at most 640×320 (WIDE) -- STANDARD and
	NARROW keep the 160 minimum height above a 256-high panel's footer unless more lines need it."""
	var width: float = LEDGER_OPEN_MAX.x if profile == UiLayout.PROFILE_WIDE else LEDGER_OPEN_MIN.x
	var height: float = clampf(lines * line_height + 2.0 * PADDING, LEDGER_OPEN_MIN.y, LEDGER_OPEN_MAX.y)
	return Vector2(width, height)
