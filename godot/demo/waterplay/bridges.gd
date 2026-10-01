extends RefCounted
## The demo's bridges: where they may go, what they cost, how far each is built, and the deck walkers
## cross. Decision 0196 (live demo). Integer state: spans and decks in u, costs in milli-U, work in WU;
## the deck's drawn line and heights are presentation floats derived from them.
##
## WHERE. A bridge spans a stream between two banks. `survey_into` checks a proposed line -- one of the
## water map's bridge candidates (its narrowest spans, water_map.gd CROSSINGS), or two points the
## player clicked on opposite banks -- and says, in words, why not when it cannot be built: an end in
## the water, a line over dry ground between two waters, the pond, a deck longer than the kind of
## bridge spans, a footing in an obstacle (the weir, the mill, a tree), a deck through one, or another
## bridge too close. The deck reaches DECK_OVERHANG past each waterline onto the bank (its FOOTINGS),
## and walkers step onto it from an APPROACH a little further back.
##
## WHAT IT COSTS AND TAKES (swim_rules.gd, demo values): a plank footbridge 1.0 U of planks a metre of
## deck and 1.0 U of wood a pier (a pier every started 2.5 m of water over 3.5 m); a log bridge one 6 U
## log. The work is three STAGES -- piers, beams (for a log: shaping and setting it), deck -- each a
## number of WU, credited as the builder works (`add_work`).
##
## LIFE. FREE -> PLANNED (paid for, waiting for a builder or being walked to) -> OPEN when the deck's
## last WU is in. A bridge is never removed (MOVE-REQ-004's reading for a crossing). Only OPEN ones are
## offered to walkers (water_crossings.gd). Rows are EntityRef-shaped (row, generation).

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MAX_BRIDGES: int = 6
const PHASE_FREE: int = 0
const PHASE_PLANNED: int = 1
const PHASE_OPEN: int = 2
## The approach stands this far beyond a footing, on the bank (m).
const APPROACH_M: float = 0.9
## Survey sampling along a proposed line, and how far a footing keeps from an obstacle's edge (m).
const SURVEY_STEP_M: float = 0.05
const FOOTING_CLEAR_M: float = 0.25
const DECK_CLEAR_M: float = 0.2
## Two bridges' decks keep at least this apart (m).
const BRIDGE_GAP_M: float = 3.0
## The deck's top, per drawn metre of the model's height, at its ends and mid-span (measured on the
## staged models: the plank deck arches from 0.18 to 0.27 of 0.698; the hewn log's top 0.44 of 0.523).
const PLANK_TOP_END: float = 0.26
const PLANK_TOP_MID: float = 0.39
const LOG_TOP: float = 0.84
## The drawn heights of the two kinds (m; presentation).
const PLANK_HEIGHT_M: float = 1.2
const LOG_HEIGHT_M: float = 0.7


## A caller-owned answer to `survey_into`.
class Survey:
	var ok: bool = false
	var reason: String = ""
	var kind: int = Rules.KIND_PLANK
	var shore_a: Vector2 = Vector2.ZERO
	var shore_b: Vector2 = Vector2.ZERO
	var span_u: int = 0
	var deck_u: int = 0
	var piers: int = 0
	var planks_milli: int = 0
	var wood_milli: int = 0


var phase: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var kind: PackedByteArray = PackedByteArray()
var span_u: PackedInt32Array = PackedInt32Array()
var deck_u: PackedInt32Array = PackedInt32Array()
var piers: PackedInt32Array = PackedInt32Array()
## Work in each stage: row * STAGE_COUNT + stage.
var stage_total_wu: PackedInt32Array = PackedInt32Array()
var stage_done_wu: PackedInt32Array = PackedInt32Array()
var shore_a: PackedVector2Array = PackedVector2Array()
var shore_b: PackedVector2Array = PackedVector2Array()
## The footing heights of the carved bank under each deck end (m).
var footing_y_a: PackedFloat32Array = PackedFloat32Array()
var footing_y_b: PackedFloat32Array = PackedFloat32Array()
var names: PackedStringArray = PackedStringArray()
## Bumped whenever a bridge is planned, advances or opens.
var revision: int = 0
## Bumped only when a bridge is planned: what a survey reads of the rows (their decks) has changed.
var layout: int = 0

var _map: WaterMapScript = null
var _obstacles: Array[Vector3] = []
var _area: Rect2 = Rect2()
var _body: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Size every column once."""
	phase.resize(MAX_BRIDGES)
	generation.resize(MAX_BRIDGES)
	kind.resize(MAX_BRIDGES)
	span_u.resize(MAX_BRIDGES)
	deck_u.resize(MAX_BRIDGES)
	piers.resize(MAX_BRIDGES)
	stage_total_wu.resize(MAX_BRIDGES * Rules.STAGE_COUNT)
	stage_done_wu.resize(MAX_BRIDGES * Rules.STAGE_COUNT)
	shore_a.resize(MAX_BRIDGES)
	shore_b.resize(MAX_BRIDGES)
	footing_y_a.resize(MAX_BRIDGES)
	footing_y_b.resize(MAX_BRIDGES)
	names.resize(MAX_BRIDGES)


func configure(map: WaterMapScript, obstacles: Array[Vector3], area: Rect2) -> void:
	"""Survey against `map`, keeping footings and decks clear of `obstacles` (Vector3(x, radius, z)
	circles on land) and inside `area`."""
	_map = map
	_obstacles = obstacles
	_area = area


# --- candidates ----------------------------------------------------------------------------------

func candidate_count() -> int:
	"""How many of the map's bridge candidates (narrowest spans first) lie inside the area."""
	var n: int = 0
	for c: int in _map.crossing_count():
		if _is_candidate(c):
			n += 1
	return n


func _is_candidate(c: int) -> bool:
	"""Whether map crossing `c` is a bridge candidate with its middle inside the area."""
	return _map.crossing_kind(c) == WaterMapScript.CROSSING_BRIDGE \
		and _area.has_point((_m(_map.crossing_a(c)) + _m(_map.crossing_b(c))) * 0.5)


func candidate_ends(k: int) -> PackedVector2Array:
	"""Bridge candidate `k`'s two dry waterline ends, metres (the map's own points)."""
	var seen: int = 0
	for c: int in _map.crossing_count():
		if not _is_candidate(c):
			continue
		if seen == k:
			return PackedVector2Array([_m(_map.crossing_a(c)), _m(_map.crossing_b(c))])
		seen += 1
	return PackedVector2Array()


func survey_candidate_into(k: int, bridge_kind: int, out: Survey) -> bool:
	"""`survey_into` along candidate `k`, from well up one bank to well up the other."""
	var ends: PackedVector2Array = candidate_ends(k)
	if ends.size() < 2:
		out.ok = false
		out.reason = "no such crossing"
		return false
	var dir: Vector2 = (ends[1] - ends[0]).normalized()
	return survey_into(ends[0] - dir * 2.0, ends[1] + dir * 2.0, bridge_kind, out)


# --- surveying -----------------------------------------------------------------------------------

func survey_into(a: Vector2, b: Vector2, bridge_kind: int, out: Survey) -> bool:
	"""Whether a `bridge_kind` bridge may span the water on the line a -> b (both on a bank), into
	`out`: its waterline ends, span, deck, piers and cost -- or the reason it may not (see WHERE)."""
	out.ok = false
	out.kind = bridge_kind
	out.reason = _crossing_reason(a, b, out)
	if out.reason.is_empty():
		out.reason = _size_reason(out)
	if out.reason.is_empty():
		out.reason = _footing_reason(out)
	out.ok = out.reason.is_empty()
	return out.ok


func _crossing_reason(a: Vector2, b: Vector2, out: Survey) -> String:
	"""Find the line's one stretch of stream (its two waterline points) or say why there is none."""
	if _wet(a) or _wet(b):
		return "both ends must be on a bank, not in the water"
	var length: float = a.distance_to(b)
	var steps: int = maxi(2, ceili(length / SURVEY_STEP_M))
	var first: int = -1
	var last: int = -1
	for k: int in steps + 1:
		if _wet(a.lerp(b, float(k) / float(steps))):
			if first >= 0 and last < k - 1:
				return "the line crosses dry ground between two waters"
			first = k if first < 0 else first
			last = k
	if first < 0:
		return "the line crosses no water"
	out.shore_a = a.lerp(b, float(first - 1) / float(steps))
	out.shore_b = a.lerp(b, float(last + 1) / float(steps))
	var mid: Vector2 = a.lerp(b, float(first + last) * 0.5 / float(steps))
	if not _map.body_at_into(_u(mid), _body) or _map.body_kind(_body.value) != WaterMapScript.KIND_STREAM:
		return "only the stream is bridged -- the pond is too wide"
	return ""


func _size_reason(out: Survey) -> String:
	"""Measure the span, deck, piers and cost, or say the deck is too long for the kind."""
	out.span_u = WaterRules.to_u(out.shore_a.distance_to(out.shore_b))
	out.deck_u = Rules.deck_u(out.span_u)
	out.piers = Rules.piers_for(out.kind, out.span_u)
	if out.deck_u > Rules.max_deck_u(out.kind):
		return "a %s spans at most %.1f m of deck; this needs %.1f m" % [Rules.KIND_NAMES[out.kind],
			WaterRules.to_m(Rules.max_deck_u(out.kind)), WaterRules.to_m(out.deck_u)]
	out.planks_milli = Rules.plank_milli(out.deck_u) if out.kind == Rules.KIND_PLANK else 0
	out.wood_milli = out.piers * Rules.PIER_WOOD_MILLI if out.kind == Rules.KIND_PLANK else Rules.LOG_WOOD_MILLI
	return ""


func _footing_reason(out: Survey) -> String:
	"""Both footings and approaches dry, in the area and clear; the deck clear; no bridge too close."""
	var dir: Vector2 = (out.shore_b - out.shore_a).normalized()
	var overhang: float = WaterRules.to_m(Rules.DECK_OVERHANG_U)
	var ends: PackedVector2Array = PackedVector2Array([out.shore_a - dir * overhang, out.shore_b + dir * overhang,
		out.shore_a - dir * (overhang + APPROACH_M), out.shore_b + dir * (overhang + APPROACH_M)])
	for at: Vector2 in ends:
		var blocked: String = _point_blocked(at)
		if not blocked.is_empty():
			return blocked
	var deck_hit: String = _deck_blocked(ends[0], ends[1])
	if not deck_hit.is_empty():
		return deck_hit
	return _near_bridge(ends[0], ends[1])


func _point_blocked(at: Vector2) -> String:
	"""Why a footing or approach at `at` cannot stand ("" when it can)."""
	if not _area.has_point(at):
		return "a footing is off the map"
	if _wet(at):
		return "a footing would stand in the water"
	for o: Vector3 in _obstacles:
		if Vector2(o.x, o.z).distance_to(at) < o.y + FOOTING_CLEAR_M:
			return "a footing is not clear: something stands at (%.1f, %.1f)" % [o.x, o.z]
	return ""


func _deck_blocked(a: Vector2, b: Vector2) -> String:
	"""Why the deck a -> b would run into something ("" when it runs clear)."""
	for o: Vector3 in _obstacles:
		if _segment_distance(Vector2(o.x, o.z), a, b) < o.y + DECK_CLEAR_M:
			return "the deck would run into something at (%.1f, %.1f)" % [o.x, o.z]
	return ""


func _near_bridge(a: Vector2, b: Vector2) -> String:
	"""Why the deck a -> b is too close to a bridge already planned or open ("" when it is not)."""
	for row: int in MAX_BRIDGES:
		if phase[row] == PHASE_FREE:
			continue
		var d: float = minf(minf(_segment_distance(deck_end(row, false), a, b), _segment_distance(deck_end(row, true), a, b)),
			minf(_segment_distance(a, deck_end(row, false), deck_end(row, true)), _segment_distance(b, deck_end(row, false), deck_end(row, true))))
		if d < BRIDGE_GAP_M:
			return "too close to the %s" % names[row]
	return ""


# --- rows ----------------------------------------------------------------------------------------

func plan_into(survey: Survey, label: String, out: IntMath.IntResult) -> bool:
	"""Take a free row for a surveyed bridge (the caller has paid for it); refuses with none free."""
	if not survey.ok:
		return out.refuse(survey.reason)
	for row: int in MAX_BRIDGES:
		if phase[row] == PHASE_FREE:
			_write(row, survey, label)
			return out.succeed(row)
	return out.refuse("every bridge row is taken (%d)" % MAX_BRIDGES)


func has_free_row() -> bool:
	"""Whether a bridge row is free for `plan_into` (an action card's check, decision 0331)."""
	for row: int in MAX_BRIDGES:
		if phase[row] == PHASE_FREE:
			return true
	return false


func _write(row: int, survey: Survey, label: String) -> void:
	"""A planned bridge's columns."""
	phase[row] = PHASE_PLANNED
	generation[row] += 1
	kind[row] = survey.kind
	span_u[row] = survey.span_u
	deck_u[row] = survey.deck_u
	piers[row] = survey.piers
	shore_a[row] = survey.shore_a
	shore_b[row] = survey.shore_b
	names[row] = label
	for stage: int in Rules.STAGE_COUNT:
		stage_total_wu[row * Rules.STAGE_COUNT + stage] = Rules.stage_wu(survey.kind, stage, survey.deck_u, survey.piers)
		stage_done_wu[row * Rules.STAGE_COUNT + stage] = 0
	footing_y_a[row] = _ground_m(deck_end(row, false))
	footing_y_b[row] = _ground_m(deck_end(row, true))
	revision += 1
	layout += 1


func is_open(row: int) -> bool:
	"""Whether bridge `row` is built and may be walked."""
	return row >= 0 and row < MAX_BRIDGES and phase[row] == PHASE_OPEN


func is_planned(row: int) -> bool:
	"""Whether bridge `row` is planned and not yet built."""
	return row >= 0 and row < MAX_BRIDGES and phase[row] == PHASE_PLANNED


func stage_of(row: int) -> int:
	"""The first stage of bridge `row` with work left (STAGE_COUNT once all are done)."""
	for stage: int in Rules.STAGE_COUNT:
		if stage_done_wu[row * Rules.STAGE_COUNT + stage] < stage_total_wu[row * Rules.STAGE_COUNT + stage]:
			return stage
	return Rules.STAGE_COUNT


func stage_left_wu(row: int, stage: int) -> int:
	"""WU left in one stage of bridge `row`."""
	var k: int = row * Rules.STAGE_COUNT + stage
	return stage_total_wu[k] - stage_done_wu[k]


func add_work(row: int, wu: int) -> int:
	"""Credit `wu` WU to bridge `row`'s current stage (never past it); opens the bridge when the deck's
	last WU is in. Returns the WU credited."""
	var stage: int = stage_of(row)
	if not is_planned(row) or stage >= Rules.STAGE_COUNT or wu <= 0:
		return 0
	var credited: int = mini(wu, stage_left_wu(row, stage))
	stage_done_wu[row * Rules.STAGE_COUNT + stage] += credited
	if stage_of(row) >= Rules.STAGE_COUNT:
		phase[row] = PHASE_OPEN
	revision += 1
	return credited


func percent(row: int) -> int:
	"""How much of bridge `row`'s work is done, whole per cent (floored)."""
	var done: int = 0
	var total: int = 0
	for stage: int in Rules.STAGE_COUNT:
		done += stage_done_wu[row * Rules.STAGE_COUNT + stage]
		total += stage_total_wu[row * Rules.STAGE_COUNT + stage]
	return 100 if total == 0 else done * 100 / total


func stage_permille(row: int, stage: int) -> int:
	"""How far one stage of bridge `row` is done, per mille (1000 for a stage with no work)."""
	var total: int = stage_total_wu[row * Rules.STAGE_COUNT + stage]
	return Rules.PERMILLE if total == 0 else stage_done_wu[row * Rules.STAGE_COUNT + stage] * Rules.PERMILLE / total


# --- the deck ------------------------------------------------------------------------------------

func direction(row: int) -> Vector2:
	"""Along bridge `row`, from end a to end b (unit)."""
	return (shore_b[row] - shore_a[row]).normalized()


func deck_end(row: int, far: bool) -> Vector2:
	"""A footing: the deck's end past a waterline (end b when `far`), metres."""
	var overhang: float = WaterRules.to_m(Rules.DECK_OVERHANG_U)
	return shore_b[row] + direction(row) * overhang if far else shore_a[row] - direction(row) * overhang


func approach(row: int, far: bool) -> Vector2:
	"""Where walkers step onto the deck at an end (end b when `far`), metres."""
	return deck_end(row, far) + direction(row) * (APPROACH_M if far else -APPROACH_M)


func deck_y_m(row: int, t: float) -> float:
	"""The deck's walking height a share `t` (0..1) along it from end a: the footings' ground under it,
	plus the drawn model's deck top (a plank deck arches to its middle)."""
	var ground: float = lerpf(footing_y_a[row], footing_y_b[row], t)
	if kind[row] == Rules.KIND_LOG:
		return ground + LOG_TOP * LOG_HEIGHT_M
	var arch: float = 1.0 - absf(2.0 * t - 1.0)
	return ground + lerpf(PLANK_TOP_END, PLANK_TOP_MID, arch) * PLANK_HEIGHT_M


func walk_length_m(row: int) -> float:
	"""Approach to approach, metres."""
	return approach(row, false).distance_to(approach(row, true))


func pier_points(row: int) -> PackedVector2Array:
	"""Where bridge `row`'s piers stand: evenly along its deck, so each carries a joint of the deck's
	segments (bridge_view.gd); every one in the water (presentation, allocates)."""
	var out := PackedVector2Array()
	for k: int in piers[row]:
		out.append(deck_end(row, false).lerp(deck_end(row, true), float(k + 1) / float(piers[row] + 1)))
	return out


# --- helpers -------------------------------------------------------------------------------------

func _wet(at: Vector2) -> bool:
	"""Whether `at` is in the water."""
	return _map.is_water(_u(at))


func _ground_m(at: Vector2) -> float:
	"""The carved ground's height at `at`."""
	return WaterRules.to_m(_map.ground_height_at(_u(at)))


static func _u(at: Vector2) -> Vector2i:
	"""A metre point as integer u."""
	return Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.y))


static func _m(at_u: Vector2i) -> Vector2:
	"""An integer point as metres."""
	return Vector2(WaterRules.to_m(at_u.x), WaterRules.to_m(at_u.y))


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from `p` to the segment a-b."""
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-9 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
