extends RefCounted
## SET-UX-001 §1.2's scaling and rectangle equations, and nothing else.
##
## §1.2 states the layout as arithmetic rather than as a picture: "Base scale=clamp(min(W/1920,
## H/1080),1,2)", "logical viewport Lw=W/S, Lh=H/S", a breakpoint table keyed on Lw, and one
## rectangle formula per permanent zone. This file is that arithmetic. Every number below is
## quoted from that section; nothing is chosen here, and a rectangle this module cannot derive
## is refused rather than guessed.
##
## ---------------------------------------------------------------------------------------
## FLOATS ARE LEGAL HERE AND ONLY HERE. AGENTS.md: "float is presentation and import only; it
## never decides a gameplay outcome". §1.2's own worked example is fractional -- "the minimum
## tested logical width 853.33 (1280 pixels with 1.5x user scale)" -- so the logical viewport
## cannot be an integer type without contradicting the specification. Nothing in this file
## reads or writes simulation state, so no float here can reach an authoritative decision. The
## user scale ITSELF is taken as an integer percent (100/125/150) so the caller's choice is an
## exact value rather than a float compared for equality.
##
## ---------------------------------------------------------------------------------------
## THE THREE PROFILES ARE §1.2's TABLE, NOT A RESPONSIVE HEURISTIC. Wide at Lw>=1600, Standard
## at 1120<=Lw<1600, Narrow below 1120, each with its own minimap, detail, resource, top-right
## and alert dimensions. §1.2 also publishes the exact resulting pixel spans at 1280x720, and
## `test_ui_layout.gd` asserts every one of them, so an equation transcribed wrongly fails
## against the document instead of merely looking plausible.
##
## ---------------------------------------------------------------------------------------
## A WINDOW BELOW THE SUPPORTED FLOOR IS REFUSED, NOT CLAMPED SILENTLY. The supported display
## range is "1280x720 through 3840x2160". Below that the equations still evaluate, but the
## resulting composition is not one this specification covers, so `compute_into()` refuses with
## VIEWPORT_BELOW_SUPPORTED and the caller decides what to show. It does not invent a smaller
## layout and it does not pretend the window is larger than it is.

# --- §1.2 constants -----------------------------------------------------------------------------

## "Base scale=clamp(min(W/1920,H/1080),1,2)".
const REFERENCE_WIDTH: float = 1920.0
const REFERENCE_HEIGHT: float = 1080.0
const BASE_SCALE_MIN: float = 1.0
const BASE_SCALE_MAX: float = 2.0

## "Supported display range 1280x720 through 3840x2160".
const SUPPORTED_MIN_WIDTH: int = 1280
const SUPPORTED_MIN_HEIGHT: int = 720
const SUPPORTED_MAX_WIDTH: int = 3840
const SUPPORTED_MAX_HEIGHT: int = 2160

## "User scale is 1.00,1.25, or 1.50", carried as an exact integer percent.
const USER_SCALE_100: int = 100
const USER_SCALE_125: int = 125
const USER_SCALE_150: int = 150
const USER_SCALES: Array[int] = [USER_SCALE_100, USER_SCALE_125, USER_SCALE_150]
const PERCENT: float = 100.0

## "Safe inset 16 logical pixels; grid spacing 8; panel internal padding 12; section gap 16."
const SAFE_INSET: float = 16.0
const GRID: float = 8.0
const PANEL_PADDING: float = 12.0
const SECTION_GAP: float = 16.0
## "Resource/time/minimap frames override profile padding to 8 px; the narrow time row uses 4 px."
const FRAME_PADDING: float = 8.0
const NARROW_TIME_PADDING: float = 4.0

const PROFILE_NARROW: int = 0
const PROFILE_STANDARD: int = 1
const PROFILE_WIDE: int = 2
const PROFILE_COUNT: int = 3
const PROFILE_KEYS: Array[StringName] = [&"NARROW", &"STANDARD", &"WIDE"]

## §1.2's breakpoint thresholds, in logical pixels.
const STANDARD_MIN_LOGICAL_WIDTH: float = 1120.0
const WIDE_MIN_LOGICAL_WIDTH: float = 1600.0

## Breakpoint table, indexed by profile: minimap width/height, detail width, resource width,
## top-right width, alert width and alert height. Narrow's alert width is `min(360, Lw-32)`,
## so its entry is the 360 cap that formula takes the minimum of.
const MINIMAP_W: Array[int] = [160, 208, 256]
const MINIMAP_H: Array[int] = [192, 240, 288]
const DETAIL_W: Array[int] = [320, 336, 384]
const RESOURCE_W: Array[int] = [176, 360, 480]
const TIME_W: Array[int] = [256, 304, 320]
const ALERT_W: Array[int] = [360, 360, 420]
const ALERT_H: Array[int] = [48, 96, 96]
const ALERT_Y: Array[int] = [76, 16, 16]
## "Narrow minimap 144x144 map content ... Standard and wide keep the same padding/header with
## 192x192 and 240x240 maps", with 8 px padding and a 32 px header.
const MINIMAP_CONTENT: Array[int] = [144, 192, 240]
const MINIMAP_HEADER: float = 32.0

## Cluster heights. "resources (16,16,R,88)"; "time (Lw-16-T,16,T,88) (narrow 48 high)".
const CLUSTER_HEIGHT: float = 88.0
const NARROW_TIME_HEIGHT: float = 48.0
## "detail (Lw-16-D,128,D,Lh-144)".
const DETAIL_TOP: float = 128.0
const DETAIL_HEIGHT_MARGIN: float = 144.0

## Command strip: "left=Mw+32; right=Lw-D-32 when detail open, otherwise Lw-16; width=min(640,
## available); y=Lh-152; height 136. Minimum command width 240."
const COMMAND_LEFT_GAP: float = 32.0
const COMMAND_RIGHT_GAP_OPEN: float = 32.0
const COMMAND_MAX_WIDTH: float = 640.0
const COMMAND_MIN_WIDTH: float = 240.0
const COMMAND_HEIGHT: float = 136.0
const COMMAND_BOTTOM_OFFSET: float = 152.0

## "Modal frame is centered with width=min(960,Lw-32), height=min(720,Lh-32)."
const MODAL_MAX_WIDTH: float = 960.0
const MODAL_MAX_HEIGHT: float = 720.0
const MODAL_MARGIN: float = 32.0

## Standard/wide resources: "three columns and two 36-high rows, top y8/y44, horizontal gap 8,
## counter width min(144,(R-32)/3)".
const COUNTER_COLUMNS: int = 3
const COUNTER_ROWS: int = 2
const COUNTER_HEIGHT: float = 36.0
const COUNTER_ROW_Y: Array[int] = [8, 44]
const COUNTER_GAP: float = 8.0
const COUNTER_MAX_WIDTH: float = 144.0
const COUNTER_WIDTH_MARGIN: float = 32.0
const COUNTER_CELL_COUNT: int = COUNTER_COLUMNS * COUNTER_ROWS

## Narrow resources: "two 104x36 rows at local (8,8) and (8,44); expand button 32x44 at (136,22)".
const NARROW_COUNTER_WIDTH: float = 104.0
const NARROW_EXPAND_RECT_X: float = 136.0
const NARROW_EXPAND_RECT_Y: float = 22.0
const NARROW_EXPAND_W: float = 32.0
const NARROW_EXPAND_H: float = 44.0
const NARROW_COUNTER_CELL_COUNT: int = 2

## Narrow time: "Pause 44 wide, three speed buttons 36 each, calendar 36, menu 36; gaps 4,
## padding 4, y6. Total width 252 fits the 256-wide cluster."
const NARROW_TIME_WIDTHS: Array[int] = [44, 36, 36, 36, 36, 36]
const NARROW_TIME_GAP: float = 4.0
const NARROW_TIME_Y: float = 6.0
## §1.3's stated total. It counts the padding on BOTH sides: 4 + 44 + five 36s + five 4 px gaps
## is 248, and the closing 4 px of padding makes the 252 the section quotes. The six controls
## therefore end at 248, which is what `_narrow_time_control()` places them at.
const NARROW_TIME_TOTAL: float = 252.0
## Standard/wide time row 1 is Pause plus three speeds; row 2 is the date trigger and the menu.
const TIME_ROW_Y: Array[int] = [8, 44]
const TIME_ROW1_WIDTHS: Array[int] = [44, 36, 36, 36]
const TIME_GAP: float = 8.0
const TIME_MENU_W: float = 36.0
## UI-SET-101's maximum width, which the standard/wide date trigger takes in time row 2.
const MAX_DATE_TRIGGER_WIDTH: float = 120.0

## "Alert stack padding is 2; two 44-high cards plus a 4 px gap fit 96. Each card width is A-40;
## its right 36 px rail contains the 32x32 history trigger."
const ALERT_PADDING: float = 2.0
const ALERT_CARD_HEIGHT: float = 44.0
const ALERT_CARD_GAP: float = 4.0
const ALERT_CARD_MARGIN: float = 40.0
const ALERT_RAIL_WIDTH: float = 36.0
const HISTORY_TRIGGER_SIZE: float = 32.0
const ALERT_CARDS_WIDE: int = 2
const ALERT_CARDS_NARROW: int = 1

# --- refusals -----------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_USER_SCALE: StringName = &"UI_UNSUPPORTED_USER_SCALE"
const REFUSE_VIEWPORT_BELOW_SUPPORTED: StringName = &"UI_VIEWPORT_BELOW_SUPPORTED_RANGE"
const REFUSE_INVALID_INDEX: StringName = &"UI_INVALID_LAYOUT_INDEX"
const REFUSE_INVALID_PROFILE: StringName = &"UI_INVALID_LAYOUT_PROFILE"


class Geometry:
	"""Every §1.2 rectangle for one viewport, in logical pixels. Reused; never reallocated."""

	var scale: float = 1.0
	var logical_width: float = 0.0
	var logical_height: float = 0.0
	var profile: int = PROFILE_STANDARD
	var resources: Rect2 = Rect2()
	var time: Rect2 = Rect2()
	var alerts: Rect2 = Rect2()
	var minimap: Rect2 = Rect2()
	var detail: Rect2 = Rect2()
	var commands: Rect2 = Rect2()
	var modal: Rect2 = Rect2()
	var detail_open: bool = false
	## True when the command strip fell below §1.2's "Minimum command width 240".
	var commands_below_minimum: bool = false

	func reset() -> void:
		"""Return every field to its empty state so a refused computation leaves no stale rect."""
		scale = 1.0
		logical_width = 0.0
		logical_height = 0.0
		profile = PROFILE_STANDARD
		resources = Rect2()
		time = Rect2()
		alerts = Rect2()
		minimap = Rect2()
		detail = Rect2()
		commands = Rect2()
		modal = Rect2()
		detail_open = false
		commands_below_minimum = false


var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Prove the breakpoint table holds one entry per profile before any rectangle is computed."""
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every §1.2 breakpoint column must carry exactly one value per layout profile."""
	assert(MINIMAP_W.size() == PROFILE_COUNT and MINIMAP_H.size() == PROFILE_COUNT,
		"the minimap columns must hold one entry per §1.2 profile")
	assert(DETAIL_W.size() == PROFILE_COUNT and RESOURCE_W.size() == PROFILE_COUNT,
		"the detail and resource widths must hold one entry per §1.2 profile")
	assert(TIME_W.size() == PROFILE_COUNT and ALERT_W.size() == PROFILE_COUNT,
		"the top-right and alert widths must hold one entry per §1.2 profile")
	assert(ALERT_H.size() == PROFILE_COUNT and ALERT_Y.size() == PROFILE_COUNT,
		"the alert height and y columns must hold one entry per §1.2 profile")
	assert(MINIMAP_CONTENT.size() == PROFILE_COUNT and PROFILE_KEYS.size() == PROFILE_COUNT,
		"every profile must name its map content size and itself")


static func is_user_scale(percent: int) -> bool:
	"""True for §1.2's three user scales, 100, 125 and 150 percent."""
	return USER_SCALES.has(percent)


static func base_scale(width: int, height: int) -> float:
	"""§1.2: `clamp(min(W/1920, H/1080), 1, 2)` for a physical viewport."""
	var fit: float = minf(float(width) / REFERENCE_WIDTH, float(height) / REFERENCE_HEIGHT)
	return clampf(fit, BASE_SCALE_MIN, BASE_SCALE_MAX)


static func effective_scale(width: int, height: int, user_percent: int) -> float:
	"""§1.2's S: the base scale multiplied by the user scale. Callers validate the percent."""
	return base_scale(width, height) * (float(user_percent) / PERCENT)


static func profile_for(logical_width: float) -> int:
	"""§1.2's breakpoint table, keyed on logical width: Narrow, Standard or Wide."""
	if logical_width >= WIDE_MIN_LOGICAL_WIDTH:
		return PROFILE_WIDE
	if logical_width >= STANDARD_MIN_LOGICAL_WIDTH:
		return PROFILE_STANDARD
	return PROFILE_NARROW


static func is_profile(profile: int) -> bool:
	"""True for one of §1.2's three layout profiles."""
	return profile >= 0 and profile < PROFILE_COUNT


func compute_into(width: int, height: int, user_percent: int, detail_open: bool,
		out: Geometry) -> bool:
	"""Fill `out` with every §1.2 rectangle for this viewport, or refuse and leave it empty.

	Refuses an unsupported user scale and a viewport below the supported 1280x720 floor. Both
	are the specification's own bounds; neither is clamped into a layout §1.2 does not define.
	"""
	out.reset()
	if not is_user_scale(user_percent):
		return _refuse(REFUSE_USER_SCALE)
	if width < SUPPORTED_MIN_WIDTH or height < SUPPORTED_MIN_HEIGHT:
		return _refuse(REFUSE_VIEWPORT_BELOW_SUPPORTED)
	out.scale = effective_scale(width, height, user_percent)
	out.logical_width = float(width) / out.scale
	out.logical_height = float(height) / out.scale
	out.profile = profile_for(out.logical_width)
	out.detail_open = detail_open
	_fill_permanent_zones(out)
	_fill_command_strip(out)
	_fill_modal(out)
	_last_refusal = REFUSE_NONE
	return true


func _fill_permanent_zones(out: Geometry) -> void:
	"""§1.2's five permanent-zone rectangles: resources, time, alerts, minimap and detail."""
	var profile: int = out.profile
	var lw: float = out.logical_width
	var lh: float = out.logical_height
	var time_height: float = NARROW_TIME_HEIGHT if profile == PROFILE_NARROW else CLUSTER_HEIGHT
	var alert_width: float = float(ALERT_W[profile])
	if profile == PROFILE_NARROW:
		alert_width = minf(alert_width, lw - 2.0 * SAFE_INSET)
	out.resources = Rect2(SAFE_INSET, SAFE_INSET, float(RESOURCE_W[profile]), CLUSTER_HEIGHT)
	out.time = Rect2(lw - SAFE_INSET - float(TIME_W[profile]), SAFE_INSET,
		float(TIME_W[profile]), time_height)
	out.alerts = Rect2(lw / 2.0 - alert_width / 2.0, float(ALERT_Y[profile]),
		alert_width, float(ALERT_H[profile]))
	out.minimap = Rect2(SAFE_INSET, lh - SAFE_INSET - float(MINIMAP_H[profile]),
		float(MINIMAP_W[profile]), float(MINIMAP_H[profile]))
	out.detail = Rect2(lw - SAFE_INSET - float(DETAIL_W[profile]), DETAIL_TOP,
		float(DETAIL_W[profile]), lh - DETAIL_HEIGHT_MARGIN)


func _fill_command_strip(out: Geometry) -> void:
	"""§1.2's command interval: the bottom strip between the minimap and the detail panel."""
	var left: float = float(MINIMAP_W[out.profile]) + COMMAND_LEFT_GAP
	var right: float = out.logical_width - SAFE_INSET
	if out.detail_open:
		right = out.logical_width - float(DETAIL_W[out.profile]) - COMMAND_RIGHT_GAP_OPEN
	var available: float = right - left
	var width: float = minf(COMMAND_MAX_WIDTH, available)
	out.commands_below_minimum = width < COMMAND_MIN_WIDTH
	out.commands = Rect2(left + (available - width) / 2.0,
		out.logical_height - COMMAND_BOTTOM_OFFSET, width, COMMAND_HEIGHT)


func _fill_modal(out: Geometry) -> void:
	"""§1.2's centred modal frame: `min(960,Lw-32)` by `min(720,Lh-32)`."""
	var width: float = minf(MODAL_MAX_WIDTH, out.logical_width - MODAL_MARGIN)
	var height: float = minf(MODAL_MAX_HEIGHT, out.logical_height - MODAL_MARGIN)
	out.modal = Rect2((out.logical_width - width) / 2.0, (out.logical_height - height) / 2.0,
		width, height)


func counter_cell(profile: int, resource_width: float, index: int) -> Rect2:
	"""One resource counter cell, local to the UI-SET-001 cluster.

	Standard and wide use §1.2's three columns by two 36-high rows; narrow uses its two 104x36
	rows. An index outside the profile's cell count refuses and returns an empty rectangle,
	because there is no seventh cell to place and no size to invent for one.
	"""
	if not is_profile(profile):
		_refuse(REFUSE_INVALID_PROFILE)
		return Rect2()
	if index < 0 or index >= counter_cell_count(profile):
		_refuse(REFUSE_INVALID_INDEX)
		return Rect2()
	_last_refusal = REFUSE_NONE
	if profile == PROFILE_NARROW:
		return Rect2(FRAME_PADDING, float(COUNTER_ROW_Y[index]),
			NARROW_COUNTER_WIDTH, COUNTER_HEIGHT)
	var width: float = counter_width(resource_width)
	var column: int = index % COUNTER_COLUMNS
	return Rect2(FRAME_PADDING + float(column) * (width + COUNTER_GAP),
		float(COUNTER_ROW_Y[index / COUNTER_COLUMNS]), width, COUNTER_HEIGHT)


static func counter_cell_count(profile: int) -> int:
	"""Six counters in the standard and wide clusters; §1.3's two in the narrow one."""
	if profile == PROFILE_NARROW:
		return NARROW_COUNTER_CELL_COUNT
	return COUNTER_CELL_COUNT


static func counter_width(resource_width: float) -> float:
	"""§1.2's counter width: `min(144,(R-32)/3)`."""
	return minf(COUNTER_MAX_WIDTH, (resource_width - COUNTER_WIDTH_MARGIN) / float(COUNTER_COLUMNS))


func time_control(profile: int, index: int) -> Rect2:
	"""One control in the UI-SET-013 time cluster, local to it and in focus order.

	Index 0 is Pause, 1..3 the three speeds, 4 the date trigger and 5 the menu button: the
	order §1.2 lays the two rows out in, and the order §8.2 walks them in.
	"""
	if not is_profile(profile):
		_refuse(REFUSE_INVALID_PROFILE)
		return Rect2()
	if index < 0 or index >= NARROW_TIME_WIDTHS.size():
		_refuse(REFUSE_INVALID_INDEX)
		return Rect2()
	_last_refusal = REFUSE_NONE
	if profile == PROFILE_NARROW:
		return _narrow_time_control(index)
	return _wide_time_control(index)


func _narrow_time_control(index: int) -> Rect2:
	"""§1.3's single narrow time row: padding 4, gaps 4, y6, six controls totalling 252."""
	var x: float = NARROW_TIME_PADDING
	for before: int in index:
		x += float(NARROW_TIME_WIDTHS[before]) + NARROW_TIME_GAP
	return Rect2(x, NARROW_TIME_Y, float(NARROW_TIME_WIDTHS[index]), COUNTER_HEIGHT)


func _wide_time_control(index: int) -> Rect2:
	"""§1.2's two standard/wide time rows: Pause and three speeds, then date and menu."""
	if index < TIME_ROW1_WIDTHS.size():
		var x: float = FRAME_PADDING
		for before: int in index:
			x += float(TIME_ROW1_WIDTHS[before]) + TIME_GAP
		return Rect2(x, float(TIME_ROW_Y[0]), float(TIME_ROW1_WIDTHS[index]), COUNTER_HEIGHT)
	if index == TIME_ROW1_WIDTHS.size():
		return Rect2(FRAME_PADDING, float(TIME_ROW_Y[1]),
			MAX_DATE_TRIGGER_WIDTH, COUNTER_HEIGHT)
	return Rect2(FRAME_PADDING + MAX_DATE_TRIGGER_WIDTH + TIME_GAP, float(TIME_ROW_Y[1]),
		TIME_MENU_W, COUNTER_HEIGHT)



func alert_card(profile: int, alert_width: float, index: int) -> Rect2:
	"""One alert card inside the UI-SET-010 stack, local to it.

	§7: "Wide/standard HUD shows at most 2 cards; narrow shows 1 and an unread count." An index
	beyond that is refused rather than stacked outside the panel.
	"""
	if not is_profile(profile):
		_refuse(REFUSE_INVALID_PROFILE)
		return Rect2()
	if index < 0 or index >= alert_card_count(profile):
		_refuse(REFUSE_INVALID_INDEX)
		return Rect2()
	_last_refusal = REFUSE_NONE
	return Rect2(ALERT_PADDING, ALERT_PADDING + float(index) * (ALERT_CARD_HEIGHT + ALERT_CARD_GAP),
		alert_width - ALERT_CARD_MARGIN, ALERT_CARD_HEIGHT)


func alert_card_sized(profile: int, alert_width: float, index: int,
		measured_content_height: float) -> Rect2:
	"""One alert card grown to the height its own wrapped text needs.

	Same shape as §4.1's detail rule -- `min(max(measured, floor), ceiling)` -- reused rather
	than a new policy invented for this card. The floor is the existing ALERT_CARD_HEIGHT, so
	the §1.2 composition is byte-identical whenever the text already fits; the ceiling is the
	alerts zone itself, so a long message can never draw past the zone it lives in.

	WHY THIS EXISTS. UXV-032 forbids clipping critical content, so the message wraps, and a
	fixed 44 px card then drew wrapped lines over its neighbours. The shell cannot fix that:
	`_place_local()` re-sets the rect from this layout on every pass.

	WHAT IT CANNOT FIX, MEASURED. `ALERT_H` is [48, 96, 96], so at NARROW the whole alerts
	ZONE is 48 px -- one 44 px card plus its padding. The ceiling therefore equals the floor
	and the card cannot grow there at all, by construction rather than by defect. STANDARD
	and WIDE have 96 px and do grow. A three-line message at NARROW needs a §1.2 decision,
	not a larger number here: §7 already says narrow shows "one highest-severity active
	alert plus count; history contains all", which reads as shortening the displayed text
	rather than enlarging the zone. That is the planner's call and is raised, not taken.
	"""
	var base: Rect2 = alert_card(profile, alert_width, index)
	if _last_refusal != REFUSE_NONE:
		return base
	var ceiling: float = float(ALERT_H[profile]) - 2.0 * ALERT_PADDING
	var grown: float = minf(maxf(measured_content_height, ALERT_CARD_HEIGHT), ceiling)
	_last_refusal = REFUSE_NONE
	return Rect2(base.position, Vector2(base.size.x, grown))


static func alert_card_count(profile: int) -> int:
	"""§7's visible card budget: two on standard and wide, one on narrow."""
	if profile == PROFILE_NARROW:
		return ALERT_CARDS_NARROW
	return ALERT_CARDS_WIDE


static func history_trigger_rect(alert_width: float) -> Rect2:
	"""UI-SET-102's 32x32 trigger in the alert stack's right 36 px rail.

	"The history trigger remains visible on its own even with no active card", so this rectangle
	does not depend on how many cards are showing.
	"""
	return Rect2(alert_width - ALERT_RAIL_WIDTH + (ALERT_RAIL_WIDTH - HISTORY_TRIGGER_SIZE) / 2.0,
		ALERT_PADDING, HISTORY_TRIGGER_SIZE, HISTORY_TRIGGER_SIZE)


static func minimap_content_rect(profile: int) -> Rect2:
	"""§1.3's map content inside the UI-SET-020 frame: 8 px padding below a 32 px header."""
	var size: float = float(MINIMAP_CONTENT[profile])
	return Rect2(FRAME_PADDING, MINIMAP_HEADER, size, size)


static func narrow_expand_rect() -> Rect2:
	"""§1.3's narrow expand-resources button: 32x44 at local (136,22)."""
	return Rect2(NARROW_EXPAND_RECT_X, NARROW_EXPAND_RECT_Y, NARROW_EXPAND_W, NARROW_EXPAND_H)


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false. No rectangle is invented on refusal."""
	_last_refusal = code
	return false
