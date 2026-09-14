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
## UI-C3-R01 §3: "STANDARD/WIDE outer alert height becomes 104; width/x/y unchanged." NARROW
## "retains outer 48/card 44, width<=360, y76 and one summary".
const ALERT_H: Array[int] = [48, 104, 104]
const ALERT_Y: Array[int] = [76, 16, 16]
## "Narrow minimap 144x144 map content ... Standard and wide keep the same padding/header with
## 192x192 and 240x240 maps", with 8 px padding and a 32 px header.
const MINIMAP_CONTENT: Array[int] = [144, 192, 240]
const MINIMAP_HEADER: float = 32.0

## Cluster heights. §1.2 gave both clusters 88: "resources (16,16,R,88)"; "time (Lw-16-T,16,T,88)
## (narrow 48 high)". UI-C3-R01 §2 raises the RESOURCE frame alone to 128 -- "Replace the 36-high
## resource cells with 56-high readout buttons in a 128-high resource frame" -- and §4 states the
## consequence: "At all profiles the resource frame now ends at y144". The time cluster "keeps its
## existing geometry", so the two heights are separate constants rather than one shared 88.
const CLUSTER_HEIGHT: float = 88.0
const RESOURCE_HEIGHT: float = 128.0
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

## "Modal frame is centered with width=min(960,Lw-32), height=min(720,Lh-32)." This is the TRUE
## modal, which UI-C3-R01 §4 preserves for New Settlement, confirmation and error surfaces. It is
## NOT the ordinary workspace: that is the amendment below.
const MODAL_MAX_WIDTH: float = 960.0
const MODAL_MAX_HEIGHT: float = 720.0
const MODAL_MARGIN: float = 32.0

## SET-UX-VIS-002 §4.2's ordinary WORKSPACE, refined by UI-C3-R01 §4. "Ordinary WORKSPACE keeps
## SET-UX-VIS-002 §4.2's width<=640, command-strip-centered/clamped placement, detail avoidance,
## bottom=command_strip.top-8, no scrim and no full-screen input block. Its top is at least
## management_top. Use measured content height bounded by 560 and available height. If less than
## 248px remains, use the compact management variant."
const WORKSPACE_MAX_WIDTH: float = 640.0
const WORKSPACE_MAX_HEIGHT: float = 560.0
const WORKSPACE_MARGIN: float = 32.0
const WORKSPACE_GAP: float = 8.0
const WORKSPACE_MIN_ORDINARY_HEIGHT: float = 248.0

## "Define `management_top = max(128, bottom(resources), bottom(alerts), bottom(time)) + 8`, giving
## 152 at the supported profiles. No management body or title overlaps that band."
const MANAGEMENT_TOP_FLOOR: float = 128.0
const MANAGEMENT_TOP_GAP: float = 8.0

## Standard/wide resources. §1.2 gave "three columns and two 36-high rows, top y8/y44"; UI-C3-R01
## §2 keeps the columns, the gap and the width formula and replaces the rows: "Standard/Wide retain
## three columns and two rows: local y=8,64; horizontal gap=8; width=min(144,(R-32)/3)".
const COUNTER_COLUMNS: int = 3
const COUNTER_ROWS: int = 2
## The 56-high readout button UI-C3-R01 §2 replaces the 36-high cell with.
const RESOURCE_CELL_HEIGHT: float = 56.0
const RESOURCE_ROW_Y: Array[int] = [8, 64]
const COUNTER_GAP: float = 8.0
const COUNTER_MAX_WIDTH: float = 144.0
const COUNTER_WIDTH_MARGIN: float = 32.0
const COUNTER_CELL_COUNT: int = COUNTER_COLUMNS * COUNTER_ROWS

## §1.2's 36-high control row, which the TIME cluster still uses. Only the resource cells grew.
const CONTROL_HEIGHT: float = 36.0

## UI-C3-R01 §2's cell interior. "Within a cell reserve 4px on each edge. Put a 16px optical
## resource icon and 4px gap beside the caption in the first line; the number owns the full second
## line. Value width is cell_width-8 ... Caption uses 14px regular Sans, measured 20px line box;
## numeric line uses 18px Semibold, measured 26px line box, with no extra interline gap."
const RESOURCE_CELL_PADDING: float = 4.0
const RESOURCE_ICON: float = 16.0
const RESOURCE_ICON_GAP: float = 4.0
const RESOURCE_CAPTION_LINE: float = 20.0
const RESOURCE_VALUE_LINE: float = 26.0
## "Resource readouts use one explicit focus-geometry exception: a 2px ring inset 1px inside the
## cell, contained entirely in the reserved 4px padding." The external offset-2 ring of §2.2 is
## NOT used here, because the two resource rows touch at y64 and it would paint into the
## neighbouring cell's caption.
const RESOURCE_FOCUS_INSET: float = 1.0
const RESOURCE_FOCUS_WIDTH: float = 2.0

## Narrow resources: "Narrow retains Food then Population as two 104x56 cells at (8,8)/(8,64),
## with a 32x44 Expand button at (136,42)" (UI-C3-R01 §2).
const NARROW_COUNTER_WIDTH: float = 104.0
const NARROW_EXPAND_RECT_X: float = 136.0
const NARROW_EXPAND_RECT_Y: float = 42.0
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

## "Alert stack padding is 2 ... Each card width is A-40; its right 36 px rail contains the 32x32
## history trigger." UI-C3-R01 §3 keeps the 2 px inset, the 4 px gap and the 36 px rail and
## replaces the single 44 px card height with a per-profile MINIMUM: "Minimum full or summary card
## height is 48 in these profiles. A one-line 16px notice measures 23px; max(text23,icon24)+24=48.
## Two such full cards plus gap consume exactly 100." NARROW keeps its authored 44 px card.
const ALERT_PADDING: float = 2.0
const ALERT_CARD_HEIGHT: float = 44.0
const ALERT_CARD_MIN_H: Array[int] = [44, 48, 48]
## "NARROW ... Its summary-only vertical padding is 8, horizontal 12 remains; max(icon24,text23)
## +16=40<=44." Full messages keep the 12 px panel padding on every edge.
const ALERT_SUMMARY_PADDING_Y: Array[int] = [8, 12, 12]
const ALERT_CARD_GAP: float = 4.0
const ALERT_CARD_MARGIN: float = 40.0
const ALERT_RAIL_WIDTH: float = 36.0
const HISTORY_TRIGGER_SIZE: float = 32.0
const ALERT_CARDS_WIDE: int = 2
const ALERT_CARDS_NARROW: int = 1

## R-UI-ALERT-001's compact card interior. The severity icon is the shell's authored 24x24 grid,
## the gap between it and the text is §1.2's 8 px grid, and the text is inset by the same 12 px
## panel padding as every other panel body. `alert_summary_width()` is what a summary line must
## fit inside, and it is the number `test_ui_notices.gd` measures every authored title against.
const ALERT_SEVERITY_ICON: float = 24.0

# --- refusals -----------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_USER_SCALE: StringName = &"UI_UNSUPPORTED_USER_SCALE"
const REFUSE_VIEWPORT_BELOW_SUPPORTED: StringName = &"UI_VIEWPORT_BELOW_SUPPORTED_RANGE"
const REFUSE_INVALID_INDEX: StringName = &"UI_INVALID_LAYOUT_INDEX"
const REFUSE_INVALID_PROFILE: StringName = &"UI_INVALID_LAYOUT_PROFILE"
const REFUSE_ALERT_COUNT: StringName = &"UI_INVALID_ALERT_NOTICE_COUNT"


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
	## UI-C3-R01 §4's reserved band: no management body or title may start above this y.
	var management_top: float = MANAGEMENT_TOP_FLOOR
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
		management_top = MANAGEMENT_TOP_FLOOR
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
	assert(ALERT_CARD_MIN_H.size() == PROFILE_COUNT
		and ALERT_SUMMARY_PADDING_Y.size() == PROFILE_COUNT,
		"every profile must state its minimum card height and its summary padding")
	assert(RESOURCE_ROW_Y.size() == COUNTER_ROWS,
		"the resource grid must state one y per row")
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
	out.resources = Rect2(SAFE_INSET, SAFE_INSET, float(RESOURCE_W[profile]), RESOURCE_HEIGHT)
	out.time = Rect2(lw - SAFE_INSET - float(TIME_W[profile]), SAFE_INSET,
		float(TIME_W[profile]), time_height)
	out.alerts = Rect2(lw / 2.0 - alert_width / 2.0, float(ALERT_Y[profile]),
		alert_width, float(ALERT_H[profile]))
	out.minimap = Rect2(SAFE_INSET, lh - SAFE_INSET - float(MINIMAP_H[profile]),
		float(MINIMAP_W[profile]), float(MINIMAP_H[profile]))
	out.detail = Rect2(lw - SAFE_INSET - float(DETAIL_W[profile]), DETAIL_TOP,
		float(DETAIL_W[profile]), lh - DETAIL_HEIGHT_MARGIN)
	out.management_top = maxf(MANAGEMENT_TOP_FLOOR, maxf(out.resources.position.y
		+ out.resources.size.y, maxf(out.alerts.position.y + out.alerts.size.y,
		out.time.position.y + out.time.size.y))) + MANAGEMENT_TOP_GAP


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


static func workspace_available_height(geometry: Geometry) -> float:
	"""How much vertical room an ordinary workspace has between the reserved band and the strip.

	SET-UX-VIS-002 §4.2 puts its "bottom [at] command-strip top-8" and UI-C3-R01 §4 puts its top
	"at least management_top". This is the interval between those two, which is also the number
	the compact test is made against: "If this leaves less than 248 pixels, use the compact modal
	variant below."
	"""
	return geometry.commands.position.y - WORKSPACE_GAP - geometry.management_top


static func workspace_is_compact(geometry: Geometry) -> bool:
	"""True when the ordinary workspace interval is under 248 px and the compact variant owns it."""
	return workspace_available_height(geometry) < WORKSPACE_MIN_ORDINARY_HEIGHT


static func workspace_rect(geometry: Geometry, content_height: float) -> Rect2:
	"""Where an ORDINARY management workspace goes -- which is NOT the centred modal rectangle.

	This is the implementation of SET-UX-VIS-002 §4.2 that UI-C3-R01 §1 records as missing:
	"`ui_shell.gd` still places ID_WORKSPACE at `_geometry.modal`. This is an unimplemented
	amendment, not solely a missing z-order ruling." A 960x688 centred rectangle swallows the
	alert zone, the two right resource columns and the minimap at the supported floor; a 640-wide
	frame that starts below management_top does not. The fix is HERE, not in the layer table: the
	HUD is not raised above dialogs, and a true modal still occludes.
	"""
	if workspace_is_compact(geometry):
		return workspace_compact_rect(geometry)
	var width: float = minf(WORKSPACE_MAX_WIDTH, geometry.logical_width - WORKSPACE_MARGIN)
	var bottom: float = geometry.commands.position.y - WORKSPACE_GAP
	var height: float = minf(minf(content_height, WORKSPACE_MAX_HEIGHT),
		workspace_available_height(geometry))
	return Rect2(_workspace_x(geometry, width), bottom - height, width, height)


static func _workspace_x(geometry: Geometry, width: float) -> float:
	"""Centre an ordinary workspace on the command strip, clamped inside the safe viewport.

	§4.2: "center on command-strip center, clamped within safe viewport and avoiding the detail
	column when open". The right limit is the detail column's left edge less the 8 px grid while
	the column is open, so the two never overlap; the left limit is §1.2's 16 px safe inset, and
	it WINS when the two cannot both be honoured, because content pushed off the left edge is
	unreachable while content beside an open detail column is merely tight.
	"""
	var right_limit: float = geometry.logical_width - SAFE_INSET
	if geometry.detail_open:
		right_limit = minf(right_limit, geometry.detail.position.x - WORKSPACE_GAP)
	var centred: float = geometry.commands.position.x + geometry.commands.size.x / 2.0 - width / 2.0
	return clampf(centred, SAFE_INSET, maxf(SAFE_INSET, right_limit - width))


static func workspace_compact_rect(geometry: Geometry) -> Rect2:
	"""UI-C3-R01 §4's compact management variant, placed BELOW the reserved band rather than over it.

	"width=min(640,Lw-32), horizontally centered; available=Lh-16-management_top; height=min(560,
	available); center vertically within that available interval. ... At 1280x720/150% (logical
	853⅓x480), body is (106⅔,152,640,312) with 188px between header/footer. This is intentional
	reflow, not a clipped 560px dialog." The scrim may dim the reserved HUD; no opaque management
	content covers it.
	"""
	var width: float = minf(WORKSPACE_MAX_WIDTH, geometry.logical_width - WORKSPACE_MARGIN)
	var available: float = geometry.logical_height - SAFE_INSET - geometry.management_top
	var height: float = minf(WORKSPACE_MAX_HEIGHT, available)
	return Rect2((geometry.logical_width - width) / 2.0,
		geometry.management_top + (available - height) / 2.0, width, height)


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
		return Rect2(FRAME_PADDING, float(RESOURCE_ROW_Y[index]),
			NARROW_COUNTER_WIDTH, RESOURCE_CELL_HEIGHT)
	var width: float = counter_width(resource_width)
	var column: int = index % COUNTER_COLUMNS
	return Rect2(FRAME_PADDING + float(column) * (width + COUNTER_GAP),
		float(RESOURCE_ROW_Y[index / COUNTER_COLUMNS]), width, RESOURCE_CELL_HEIGHT)


static func counter_cell_count(profile: int) -> int:
	"""Six counters in the standard and wide clusters; §1.3's two in the narrow one."""
	if profile == PROFILE_NARROW:
		return NARROW_COUNTER_CELL_COUNT
	return COUNTER_CELL_COUNT


static func counter_width(resource_width: float) -> float:
	"""§1.2's counter width: `min(144,(R-32)/3)`."""
	return minf(COUNTER_MAX_WIDTH, (resource_width - COUNTER_WIDTH_MARGIN) / float(COUNTER_COLUMNS))


static func resource_caption_rect(cell_size: Vector2) -> Rect2:
	"""The caption line inside a resource cell: the 20 px box beside its 16 px optical icon.

	UI-C3-R01 §2: "Within a cell reserve 4px on each edge. Put a 16px optical resource icon and
	4px gap beside the caption in the first line". The width this returns is what a caption must
	MEASURE inside -- "Measure caption+icon as well as the value" -- so a caption too long for it
	is a content defect to be reported, never a string for this file to shorten.
	"""
	return Rect2(RESOURCE_CELL_PADDING + RESOURCE_ICON + RESOURCE_ICON_GAP, RESOURCE_CELL_PADDING,
		resource_caption_width(cell_size.x), RESOURCE_CAPTION_LINE)


static func resource_caption_width(cell_width: float) -> float:
	"""How wide a resource caption may measure: the cell less both 4 px edges, the icon and its gap."""
	return cell_width - 2.0 * RESOURCE_CELL_PADDING - RESOURCE_ICON - RESOURCE_ICON_GAP


static func resource_icon_rect(_cell_size: Vector2) -> Rect2:
	"""The 16 px optical resource icon, centred in the caption line at the cell's left padding.

	"Center the icon in the caption line": the icon is 16 and the line box is 20, so it sits 2 px
	below the caption line's top. It replaces §2.2's 24 px inline resource icon for these cells
	only -- "This explicit optical-size exception replaces the old 24px inline resource icon; it
	does not shrink typography."
	"""
	return Rect2(RESOURCE_CELL_PADDING,
		RESOURCE_CELL_PADDING + (RESOURCE_CAPTION_LINE - RESOURCE_ICON) / 2.0,
		RESOURCE_ICON, RESOURCE_ICON)


static func resource_value_rect(cell_size: Vector2) -> Rect2:
	"""The numeric line inside a resource cell: the full second line, `cell_width-8` wide.

	"the number owns the full second line. Value width is cell_width-8: Standard 101⅓, Wide 136,
	Narrow 96 ... Combined 46px plus 8px padding fits 56", with "no extra interline gap", so the
	26 px numeric box begins exactly where the 20 px caption box ends.
	"""
	return Rect2(RESOURCE_CELL_PADDING, RESOURCE_CELL_PADDING + RESOURCE_CAPTION_LINE,
		resource_value_width(cell_size.x), RESOURCE_VALUE_LINE)


static func resource_value_width(cell_width: float) -> float:
	"""How wide a resource value may measure before UI-C3-R01 §2's ledger disclosure takes over."""
	return cell_width - 2.0 * RESOURCE_CELL_PADDING


static func resource_focus_rect(cell_size: Vector2) -> Rect2:
	"""UI-C3-R01 §2's inset focus ring: "a 2px ring inset 1px inside the cell".

	The two resource rows TOUCH -- y8 and y64 with 56 high cells -- so §2.2's ring "offset 2 px"
	outside the control would paint across the neighbouring cell's caption. The ring is therefore
	drawn inward and is "contained entirely in the reserved 4px padding": 1 px inset plus a 2 px
	stroke ends 3 px in, inside the 4 px the cell reserves on every edge.
	"""
	return Rect2(RESOURCE_FOCUS_INSET, RESOURCE_FOCUS_INSET,
		cell_size.x - 2.0 * RESOURCE_FOCUS_INSET, cell_size.y - 2.0 * RESOURCE_FOCUS_INSET)


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
	return Rect2(x, NARROW_TIME_Y, float(NARROW_TIME_WIDTHS[index]), CONTROL_HEIGHT)


func _wide_time_control(index: int) -> Rect2:
	"""§1.2's two standard/wide time rows: Pause and three speeds, then date and menu."""
	if index < TIME_ROW1_WIDTHS.size():
		var x: float = FRAME_PADDING
		for before: int in index:
			x += float(TIME_ROW1_WIDTHS[before]) + TIME_GAP
		return Rect2(x, float(TIME_ROW_Y[0]), float(TIME_ROW1_WIDTHS[index]), CONTROL_HEIGHT)
	if index == TIME_ROW1_WIDTHS.size():
		return Rect2(FRAME_PADDING, float(TIME_ROW_Y[1]),
			MAX_DATE_TRIGGER_WIDTH, CONTROL_HEIGHT)
	return Rect2(FRAME_PADDING + MAX_DATE_TRIGGER_WIDTH + TIME_GAP, float(TIME_ROW_Y[1]),
		TIME_MENU_W, CONTROL_HEIGHT)



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
	var height: float = alert_card_min_height(profile)
	return Rect2(ALERT_PADDING, ALERT_PADDING + float(index) * (height + ALERT_CARD_GAP),
		alert_width - ALERT_CARD_MARGIN, height)


static func alert_card_min_height(profile: int) -> float:
	"""UI-C3-R01 §3's minimum full-or-summary card height: 48 at STANDARD/WIDE, NARROW's 44.

	This is the number that makes a card REACHABLE rather than merely placed. "A one-line 16px
	notice measures 23px; max(text23,icon24)+24=48", so a 44 px card at STANDARD cannot hold one
	line of body text beside a 24 px severity icon at the 12 px panel padding -- which is the
	unreachable example ALERT-R02 published and this replaces. An unknown profile has no card.
	"""
	if not is_profile(profile):
		return 0.0
	return float(ALERT_CARD_MIN_H[profile])


static func alert_summary_padding_y(profile: int) -> float:
	"""The vertical padding inside a SUMMARY card: NARROW's authored 8, elsewhere the 12 px panel.

	UI-C3-R01 §3: "Its summary-only vertical padding is 8, horizontal 12 remains; max(icon24,
	text23)+16=40<=44." Named as "an explicit NOTICE summary exception to generic panel padding,
	not a change to full-message padding", which is why a full message never reads this.
	"""
	if not is_profile(profile):
		return 0.0
	return float(ALERT_SUMMARY_PADDING_Y[profile])


static func alert_summary_width(profile: int, alert_width: float) -> float:
	"""How wide an R-UI-ALERT-001 compact summary line may be, inside its own card.

	The card is `alert_width - ALERT_CARD_MARGIN`, which already accounts for §1.2's 36 px
	history rail. Inside it sit the 12 px panel padding, the 24 px severity icon, the 8 px grid
	gap, the text, and the closing 12 px padding. At NARROW and STANDARD, where §1.2's alert
	width is 360, that is 264 logical pixels, and it does not change with the user scale because
	the whole composition is in logical pixels. A caller that cannot fit an authored title in
	this width must write a shorter title; nothing in this file will shorten one for it.
	"""
	if not is_profile(profile):
		return 0.0
	return alert_width - ALERT_CARD_MARGIN - 2.0 * PANEL_PADDING - ALERT_SEVERITY_ICON - GRID


class Stack:
	"""Where the alert cards actually go, and which of them had to fall back to a summary."""

	## One rectangle per card §7 allows on the widest profile. Reused; never reallocated.
	var rects: Array[Rect2] = [Rect2(), Rect2()]
	## 1 where the card could not show its measured content and must draw its compact summary.
	var summarised: PackedByteArray = PackedByteArray([0, 0])
	## How many cards fit. §7's limit is a MAXIMUM, so this may be fewer, including zero.
	var visible_count: int = 0

	func reset() -> void:
		"""Return the stack to empty so a refused computation leaves no stale rectangle."""
		for index: int in rects.size():
			rects[index] = Rect2()
			summarised[index] = 0
		visible_count = 0


func alert_stack_into(profile: int, alert_width: float, measured: PackedFloat32Array,
		count: int, out: Stack) -> bool:
	"""Pack `count` notices down their zone at the heights their own content needs.

	ALERT-R02's four packing rules, in order, at UI-C3-R01 §3's heights. (1) The highest-priority
	notice shows its full text when its measured card is at most the zone interior, otherwise its
	authored summary at the profile's MINIMUM card height. (2) A second notice takes its full card
	if it fits the room left after the 4 px gap, otherwise its summary if THAT fits, otherwise it
	is not shown. (3) The count of notices this leaves undisplayed is the caller's to publish
	through the history rail; no third row is created here. (4) Card two begins at
	`card1_bottom + 4`, which is what the cursor is -- never at a fixed origin, which is how
	independently grown cards came to overlap.

	UI-C3-R01 §3 replaces ALERT-R02's unreachable two-44px example: "STANDARD/WIDE outer alert
	height becomes 104 ... Minimum full or summary card height is 48 ... Two such full cards plus
	gap consume exactly 100." Its own worked cases are the arithmetic here: 48+4+48 fits; 70+4+48
	does not, so a 70 px first card is alone; a first full card of 101 becomes a 48 summary and
	can still admit a second 48.

	NARROW is not a case of rule 1. `ALERT_H` is [48,104,104]: the NARROW zone's interior is 44
	logical pixels, which is exactly one card, so its ceiling EQUALS its floor and no measured
	content can ever be granted more room. The compact form there is the construction, and the
	`profile != PROFILE_NARROW` term states it rather than leaving it to arithmetic that would
	silently admit a short message.

	Nothing here shortens a string. A card that cannot show its measured content is SUMMARISED
	-- it draws the caller's authored compact line at the minimum height -- and never clipped,
	ellipsized or drawn at a reduced font size.
	"""
	out.reset()
	if not is_profile(profile):
		return _refuse(REFUSE_INVALID_PROFILE)
	if count < 0 or count > measured.size():
		return _refuse(REFUSE_ALERT_COUNT)
	var ceiling: float = float(ALERT_H[profile]) - 2.0 * ALERT_PADDING
	var floor_height: float = alert_card_min_height(profile)
	var cursor: float = ALERT_PADDING
	var wanted: int = mini(count, alert_card_count(profile))
	for index: int in wanted:
		var remaining: float = ceiling + ALERT_PADDING - cursor
		if remaining < floor_height:
			break
		var fits: bool = measured[index] <= remaining and profile != PROFILE_NARROW
		var height: float = maxf(measured[index], floor_height) if fits else floor_height
		out.rects[index] = Rect2(ALERT_PADDING, cursor, alert_width - ALERT_CARD_MARGIN, height)
		out.summarised[index] = 0 if fits else 1
		out.visible_count += 1
		cursor += height + ALERT_CARD_GAP
	_last_refusal = REFUSE_NONE
	return true


static func alert_zone_interior(profile: int) -> float:
	"""The content height inside one profile's alert zone: its height less both 2 px insets.

	44 at NARROW -- one card and nothing else -- and 100 at STANDARD and WIDE, which is the
	number UI-C3-R01 §3 measures a full card against: "Content height is 100."
	"""
	if not is_profile(profile):
		return 0.0
	return float(ALERT_H[profile]) - 2.0 * ALERT_PADDING


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
