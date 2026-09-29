extends RefCounted
## The demo's water rules: units, the four water-column zones and the integer helpers every water
## query shares. Decision 0196 (live demo), water foundation. Pure static functions over integers.
##
## ---------------------------------------------------------------------------------------
## UNITS. Positions, lengths and depths are integers in u = 1/1024 m (AGENTS.md: positions are
## int32 in 1/1024 m units; docs/movement_direction_amendment.md §4 inherits the same convention).
## A float enters only at the import boundary (`to_u`) and leaves only for drawing (`to_m`).
##
## ---------------------------------------------------------------------------------------
## ZONES -- what the water column at a point is, for one body height. SET-MOVE-001 adopts three
## distinct water behaviours and settles none of their numbers ("Wading/surface swimming/diving
## distinctions | Valid entry, exit, body/gear/load compatibility and planned return to air | NOT
## settled: per-profile capability assignments, speeds, air/recovery rates, hazards"; §4: "New
## production speeds, depths, oxygen values ... None originated by this amendment"). The zones
## below therefore classify WATER, never grant a capability:
##   * DRY  -- no water.
##   * WADE -- shallow enough to stay GROUND movement. TRV-W01 (traversal review §6): "Walking
##             through the current shallow ford remains ground movement; surface swimming uses a
##             separate eligible profile".
##   * SWIM -- too deep to wade: only a surface-swimming profile may enter (TRV-W01/W02), and only
##             at a validated bank connection (TRV-W02, MOVE-REQ-001).
##   * DIVE -- deeper than the body is tall, so a submerged segment is possible there; a dive is
##             a PLANNED segment between air endpoints with a budget (MOVE-REQ-009/010, TRV-W04).
## Being in a zone admits nothing: MOVE-REQ-005 conjuncts capability, clearance, posture, grip and
## load, and "Individual eligibility" is per resident. Phase 2 owns those checks.
##
## DEMO THRESHOLDS (nothing adopted settles them; each is named here and in the report):
##   * WADE_MAX_PERMILLE = 250: water up to a quarter of the body's standing height -- knee-deep on
##     the 1.0 m mouse anchor (crowd §9.1; lookdev_dimensions.gd SPECIES_HEIGHT_U mouse = 1024 u),
##     i.e. 256 u. The only nearby body figure in the project is proportion_comparison.gd's mouse
##     hip at 460 permille, which is itself PROPOSED_FOR_REVIEW; a knee at about half the hip is a
##     demo reading of it, not a ruling.
##   * DIVE_MIN_PERMILLE = 1000: water deeper than the body is tall (1024 u for the mouse), so the
##     whole body can be under the surface. Between the two the body must surface-swim.
## Thresholds scale with body height (`zone_for_depth`), so a 2.55 m badger wades where a mouse
## must swim; `zone_at` in water_map.gd uses the mouse anchor.

const UNITS_PER_M: int = 1024
const PERMILLE: int = 1000

## crowd §9.1's 1.0 m mouse anchor, as lookdev_dimensions.gd's SPECIES_HEIGHT_U row (tested equal).
const MOUSE_HEIGHT_U: int = 1024

const ZONE_DRY: int = 0
const ZONE_WADE: int = 1
const ZONE_SWIM: int = 2
const ZONE_DIVE: int = 3
const ZONE_COUNT: int = 4
const ZONE_NAMES: Array[StringName] = [&"DRY", &"WADE", &"SWIM", &"DIVE"]

## Demo thresholds, permille of the body's standing height (see the header).
const WADE_MAX_PERMILLE: int = 250
const DIVE_MIN_PERMILLE: int = 1000

## 64 unit directions round the circle, (cos, sin) * 1024 rounded -- the integer table every
## shoreline sample is taken along, so no trigonometry runs when a map is finalised.
const DIRECTION_COUNT: int = 64
const DIRECTIONS_1024: Array[int] = [
	1024, 0, 1019, 100, 1004, 200, 980, 297, 946, 392, 903, 483, 851, 569, 792, 650,
	724, 724, 650, 792, 569, 851, 483, 903, 392, 946, 297, 980, 200, 1004, 100, 1019,
	0, 1024, -100, 1019, -200, 1004, -297, 980, -392, 946, -483, 903, -569, 851, -650, 792,
	-724, 724, -792, 650, -851, 569, -903, 483, -946, 392, -980, 297, -1004, 200, -1019, 100,
	-1024, 0, -1019, -100, -1004, -200, -980, -297, -946, -392, -903, -483, -851, -569, -792, -650,
	-724, -724, -650, -792, -569, -851, -483, -903, -392, -946, -297, -980, -200, -1004, -100, -1019,
	0, -1024, 100, -1019, 200, -1004, 297, -980, 392, -946, 483, -903, 569, -851, 650, -792,
	724, -724, 792, -650, 851, -569, 903, -483, 946, -392, 980, -297, 1004, -200, 1019, -100,
]
const DIRECTION_SCALE: int = 1024


static func to_u(metres: float) -> int:
	"""A float length or coordinate in metres, as integer u (the import boundary)."""
	return roundi(metres * float(UNITS_PER_M))


static func to_m(units: int) -> float:
	"""Integer u as float metres, for drawing."""
	return float(units) / float(UNITS_PER_M)


static func isqrt(n: int) -> int:
	"""The exact floor square root of `n`, by integer Newton iteration (no float anywhere).

	`n` must be non-negative: every caller passes a sum of squares. A negative argument is a
	programming error and is asserted, not answered.
	"""
	assert(n >= 0, "isqrt of a negative number")
	if n < 2:
		return n
	var x: int = 1
	while x * x <= n / 4:
		x *= 2
	x *= 2
	var y: int = (x + n / x) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


static func ceil_div(a: int, b: int) -> int:
	"""ceil(a / b) for a >= 0 and b > 0."""
	return (a + b - 1) / b


static func zone_for_depth(depth_u: int, body_height_u: int) -> int:
	"""The zone a water column of `depth_u` is for a body `body_height_u` tall (> 0), by the demo
	thresholds in the header. Exactly at a threshold the shallower zone holds: a knee-deep ford
	(depth == 250 permille of height) is still wading, water exactly one body deep is still swum."""
	assert(body_height_u > 0, "a zone needs a positive body height")
	if depth_u <= 0:
		return ZONE_DRY
	if depth_u * PERMILLE <= WADE_MAX_PERMILLE * body_height_u:
		return ZONE_WADE
	if depth_u * PERMILLE <= DIVE_MIN_PERMILLE * body_height_u:
		return ZONE_SWIM
	return ZONE_DIVE


static func wade_max_u(body_height_u: int) -> int:
	"""The deepest water a body this tall still wades, in u (floor)."""
	return WADE_MAX_PERMILLE * body_height_u / PERMILLE


static func dive_min_u(body_height_u: int) -> int:
	"""The depth past which water is a dive zone for a body this tall, in u (floor)."""
	return DIVE_MIN_PERMILLE * body_height_u / PERMILLE
