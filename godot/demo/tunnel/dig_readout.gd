extends RefCounted
## The Dig tool's cost readout at the pointer. Decision 0208 (design docs/design/underground_revamp.md §2
## "Planning", §4 "Ghost preview"). Presentation only: it reads the rules and the ground, and writes nothing.
##
## e.g. "14.2 m · 16 quanta · 21.3 h (crew of 3)" over "32 U spoil · clay 4 m (slow), sand 2 m (weak: brace)":
##   * LENGTH as the panel shows lengths (tunnel_plan.gd `length_text`);
##   * QUANTA as the network will cut them (underground_graph.gd THE DIG TIMELINE): a shaft at each end that
##     opens a mouth, and every started metre of each segment the piece is cut into (at its ramps' feet and
##     its crossings);
##   * TIME in hours of the demo calendar (demo_calendar.gd HOUR_USEC: a game hour every 2.5 demo seconds, so
##     75 of the dig's 30 Hz ticks), each quantum at its ground's dig ticks (tunnel_ground.gd), over the crew's
##     rate (tunnel_crew.gd: the pipeline for the crew that would work the face, times the digger's skill);
##   * SPOIL as each quantum's ground posts it (ECON-002, by ground);
##   * GROUND: the metres of bore through each ground that matters -- clay (slow), sand (weak: brace), rock
##     (needs a breaker), wet ground (seeps: brace) -- loam, the plain case, unnamed.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

## Ticks of the dig's 30 Hz clock in a demo-calendar hour.
const TICKS_PER_CALENDAR_HOUR: int = CalendarScript.HOUR_USEC * Rules.TICKS_PER_SECOND / Rules.USEC_PER_SECOND
const GROUND_WORDS: Array[String] = ["", "clay %d m (slow)", "sand %d m (weak: brace)", "rock %d m (needs a breaker)"]
const WET_WORDS: String = "wet %d m (seeps: brace)"
## Tallies: quanta, ticks, spoil, then metres of loam, clay, sand, rock, wet.
const T_QUANTA: int = 0
const T_TICKS: int = 1
const T_SPOIL: int = 2
const T_METRES: int = 3
const T_WET: int = 7
const T_SIZE: int = 8


static func text(plan: PlanScript, ground: GroundScript, rate_permille: int, crew: int) -> String:
	"""The readout for the piece as laid (see the header); "" with under two points."""
	if plan.count < 2:
		return ""
	var tally := PackedInt64Array()
	tally.resize(T_SIZE)
	tally_into(plan, ground, tally)
	var hours_tenths := tally[T_TICKS] * Rules.PERMILLE * 10 / maxi(rate_permille, 1) / TICKS_PER_CALENDAR_HOUR
	var first := PackedStringArray([PlanScript.length_text(plan.length_u()), "%d quanta" % tally[T_QUANTA],
		"%d.%d h (%s)" % [hours_tenths / 10, hours_tenths % 10, "crew of %d" % crew if crew > 1 else "one digger"]])
	var second := PackedStringArray(["%d U spoil" % (tally[T_SPOIL] / 1000)])
	var ground_words := _ground_words(tally)
	if not ground_words.is_empty():
		second.append(ground_words)
	return "%s\n%s" % [" · ".join(first), " · ".join(second)]


static func tally_into(plan: PlanScript, ground: GroundScript, tally: PackedInt64Array) -> void:
	"""The piece's quanta, ticks, spoil and metres through each ground, into `tally` (T_* slots)."""
	tally.fill(0)
	var cuts := _cuts(plan)
	for i in cuts.size() - 1:
		var run := cuts[i + 1] - cuts[i]
		var q := Rules.bore_quanta(run)
		for k in q:
			var at := GraphScript.route_point_u(plan.points_u, plan.count, cuts[i] + (2 * k + 1) * run / (2 * q))
			_count(ground, at, tally, true)
	if plan.starts_at_mouth():
		_count(ground, plan.point_u(0), tally, false)
	if plan.ends_at_mouth():
		_count(ground, plan.point_u(plan.count - 1), tally, false)


static func _cuts(plan: PlanScript) -> PackedInt32Array:
	"""Where along the piece (u) it is cut into segments, in order: its ends, its ramps' feet and its
	crossings."""
	var length := plan.length_u()
	var cuts := PackedInt32Array([0, length])
	if plan.starts_at_mouth() and length > Rules.RAMP_RUN_U:
		cuts.append(Rules.RAMP_RUN_U)
	if plan.ends_at_mouth() and length - Rules.RAMP_RUN_U > 0:
		cuts.append(length - Rules.RAMP_RUN_U)
	for c in plan.crossings.size() / 3:
		cuts.append(GraphScript.route_along_u(plan.points_u, plan.count, Vector2i(plan.crossings[3 * c + 1], plan.crossings[3 * c + 2])))
	cuts.sort()
	var unique := PackedInt32Array()
	for cut in cuts:
		if unique.is_empty() or cut > unique[unique.size() - 1]:
			unique.append(cut)
	return unique


static func _count(ground: GroundScript, at: Vector2i, tally: PackedInt64Array, bore: bool) -> void:
	"""One quantum at `at`: its ticks and spoil, and (a bore quantum) a metre of its ground."""
	var kind := ground.type_at(at.x, at.y) if ground != null else GroundScript.LOAM
	tally[T_QUANTA] += 1
	tally[T_TICKS] += GroundScript.dig_ticks(kind)
	tally[T_SPOIL] += GroundScript.spoil_of(kind)
	if not bore:
		return
	tally[T_METRES + kind] += 1
	if ground != null and ground.wet_at(at.x, at.y):
		tally[T_WET] += 1


static func _ground_words(tally: PackedInt64Array) -> String:
	"""The grounds that matter, in words (see GROUND)."""
	var words := PackedStringArray()
	for kind in range(GroundScript.CLAY, GroundScript.ROCK + 1):
		if tally[T_METRES + kind] > 0:
			words.append(GROUND_WORDS[kind] % tally[T_METRES + kind])
	if tally[T_WET] > 0:
		words.append(WET_WORDS % tally[T_WET])
	return ", ".join(words)
