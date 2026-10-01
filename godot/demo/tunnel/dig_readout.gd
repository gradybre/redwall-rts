extends RefCounted
## The Dig tool's cost readout at the pointer. Decision 0208 (design docs/design/underground_revamp.md §2
## "Planning", §4 "Ghost preview"). Presentation only: it reads the rules and the ground, and writes nothing.
##
## e.g. "14.2 m · 16 quanta · 2.1 h (crew of 3)" over "32 U spoil · brace 4.0 wood + 4.0 stone · clay 4 m (slow),
## sand 2 m (weak: brace)":
##   * LENGTH as the panel shows lengths (tunnel_plan.gd `length_text`);
##   * QUANTA as the network will cut them (underground_graph.gd THE DIG TIMELINE): a shaft at each end that
##     opens a mouth, and every started metre of each segment the piece is cut into (at its ramps' feet and
##     its crossings);
##   * TIME on the demo calendar (demo_calendar.gd HOUR_USEC: a game hour every 25 demo seconds, so 750 of the
##     dig's 30 Hz ticks; decision 0421) -- minutes under an hour, else hours to the tenth (`time_text`) -- each
##     quantum at its ground's dig ticks (tunnel_ground.gd), over the crew's rate (tunnel_crew.gd: the pipeline for
##     the crew that would work the face, times the digger's skill);
##   * SPOIL as each quantum's ground posts it (ECON-002, by ground);
##   * THE BRACE COST (decision 0211; design §4 "Cost readout": "brace cost (wood 250 + stone 250 milli-U a quantum,
##     ECON-002)"): what bracing the dug piece would take from the demo stores -- the Brace job's own price
##     (tunnel_jobs.gd BRACE_WOOD_MILLI_U, BRACE_STONE_MILLI_U) on every quantum it cuts, shafts included, as each
##     segment's job charges it -- to the tenth of a unit;
##   * GROUND: the metres of bore through each ground that matters -- clay (slow), sand (weak: brace), rock
##     (needs a breaker), wet ground (seeps: brace) -- loam, the plain case, unnamed.
## A ROOM's readout (`room_text`, decision 0209) is the room tool's: its own quanta cell by cell, its door ramp,
## and its proposed passage, the room at its crew's three-face rate.
## LEVELS (decision 0212): each quantum's ground is read on its own level (tunnel_ground.gd THE GROUND AT DEPTH;
## a link's by the level its floor lies nearer there). A LINK's readout names its kind and grade and gives its run
## and its slope: e.g. "Stairs down · 5.2 m run, 6.6 m slope · 7 quanta · 12 min (crew of 2)" over "13 U spoil ·
## 16 timber risers, 4:5 (38.7°) · clay 3 m (slow)" -- its quanta the started metres of its slope, each stair
## quantum's time STAIR_WORK_PERMILLE of a bore's (tunnel_rules.gd LINKS).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

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
	var ticks: int = tally[T_TICKS] * Rules.PERMILLE / maxi(rate_permille, 1)
	var first := PackedStringArray([PlanScript.length_text(plan.length_u()), "%d quanta" % tally[T_QUANTA],
		"%s (%s)" % [time_text(ticks), "crew of %d" % crew if crew > 1 else "one digger"]])
	var second := PackedStringArray(["%d U spoil" % (tally[T_SPOIL] / 1000), brace_text(tally[T_QUANTA])])
	if plan.is_link():
		first[0] = link_heading(plan.link_kind, plan.length_u())
		second[1] = grade_text(plan.link_kind, plan.length_u())
	var ground_words := _ground_words(tally)
	if not ground_words.is_empty():
		second.append(ground_words)
	return "%s\n%s" % [" · ".join(first), " · ".join(second)]


static func link_heading(kind: int, run_u: int) -> String:
	"""A link's name and its run and slope: "Ramp down · 11.2 m run, 11.9 m slope"."""
	return "%s down · %s run, %s slope" % [Rules.LINK_NAMES[kind].capitalize(), _metres(run_u), _metres(Rules.link_slope_u(run_u))]


static func grade_text(kind: int, run_u: int) -> String:
	"""A link's grade in words: a ramp's steepest (1:2.5 at most), stairs' risers and pitch."""
	var permille := Rules.link_grade_permille(kind, run_u)
	var degrees := roundi(rad_to_deg(atan(float(permille) / float(Rules.PERMILLE))) * 10.0)
	var pitch := "%d.%d°" % [degrees / 10, degrees % 10]
	if kind == Rules.LINK_STAIRS:
		return "%d timber risers, pitch %s" % [Rules.STAIR_RISERS, pitch]
	return "grade 1:%s (%s)" % [_ratio(permille), pitch]


static func _ratio(permille: int) -> String:
	"""Run over rise for a grade in per mille, to the tenth (400 -> "2.5")."""
	var tenths_value := Rules.PERMILLE * 10 / maxi(permille, 1)
	return "%d.%d" % [tenths_value / 10, tenths_value % 10]


static func _metres(u: int) -> String:
	"""A length in u as metres to the tenth, rounded to the nearest ("11.9 m")."""
	var tenths_value := (u * 10 + Rules.UNITS_PER_M / 2) / Rules.UNITS_PER_M
	return "%d.%d m" % [tenths_value / 10, tenths_value % 10]


static func brace_text(quanta: int) -> String:
	"""What bracing `quanta` quanta costs, in words (see THE BRACE COST): "brace 4.0 wood + 4.0 stone"."""
	return "brace %s wood + %s stone" % [tenths(JobsScript.BRACE_WOOD_MILLI_U * quanta),
		tenths(JobsScript.BRACE_STONE_MILLI_U * quanta)]


static func tenths(milli_u: int) -> String:
	"""A quantity in milli-U as units to the tenth, rounded down ("4.0", "3.7")."""
	return "%d.%d" % [milli_u / 1000, milli_u % 1000 / 100]


static func tally_into(plan: PlanScript, ground: GroundScript, tally: PackedInt64Array) -> void:
	"""The piece's quanta, ticks, spoil and metres through each ground, into `tally` (T_* slots), each quantum on
	its own level (see LEVELS)."""
	tally.fill(0)
	if plan.is_link():
		_link_tally(plan, ground, tally)
		return
	var cuts := _cuts(plan)
	for i in cuts.size() - 1:
		var run := cuts[i + 1] - cuts[i]
		var q := Rules.bore_quanta(run)
		for k in q:
			var at := GraphScript.route_point_u(plan.points_u, plan.count, cuts[i] + (2 * k + 1) * run / (2 * q))
			_count(ground, at, tally, true, plan.level)
	if plan.starts_at_mouth():
		_count(ground, plan.point_u(0), tally, false)
	if plan.ends_at_mouth():
		_count(ground, plan.point_u(plan.count - 1), tally, false)


static func _link_tally(plan: PlanScript, ground: GroundScript, tally: PackedInt64Array) -> void:
	"""A link's quanta -- the started metres of its slope, spread along its run, each on the level its floor lies
	nearer -- their ticks at the link's work (stairs' risers), spoil and ground (see LEVELS)."""
	var run := plan.length_u()
	var q := Rules.link_quanta(run)
	for k in q:
		var along := (2 * k + 1) * run / (2 * q)
		var drop := Rules.link_drop_u(plan.link_kind, along, run)
		var at_level := plan.level + (1 if 2 * drop >= Rules.LEVEL_SPACING_U else 0)
		_count(ground, GraphScript.route_point_u(plan.points_u, plan.count, along), tally, true, at_level)
	tally[T_TICKS] = tally[T_TICKS] * Rules.link_work_permille(plan.link_kind) / Rules.PERMILLE


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


static func _count(ground: GroundScript, at: Vector2i, tally: PackedInt64Array, bore: bool,
		level: int = Rules.TOP_LEVEL) -> void:
	"""One quantum at `at` on `level`: its ticks and spoil, and (a bore quantum) a metre of its ground."""
	var kind := ground.type_at_level(at.x, at.y, level) if ground != null else GroundScript.LOAM
	tally[T_QUANTA] += 1
	tally[T_TICKS] += GroundScript.dig_ticks(kind)
	tally[T_SPOIL] += GroundScript.spoil_of(kind)
	if not bore:
		return
	tally[T_METRES + kind] += 1
	if ground != null and ground.wet_at_level(at.x, at.y, level):
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


# --- a room (decision 0209) -------------------------------------------------------------------

static func room_text(kind: int, centre: Vector2i, turns: int, passage: PlanScript, ground: GroundScript,
		rate_one: int, rate_room: int, crew: int, passage_to: String, level: int = Rules.TOP_LEVEL) -> String:
	"""The room tool's readout (room_tool.gd): the room's name, all its quanta -- its cells, its door ramp and
	shaft (on level 1), and its proposed passage -- the hours its crew takes (the room at its ROOM_FACES faces'
	rate `rate_room`, the rest at `rate_one`), its spoil, and its passage (or that it stands alone). e.g.
	"Burrow home · 33 quanta · 48 min (crew of 3)" over "66 U spoil · passage 3.2 m to Tunnel 4"."""
	var cells := _tally()
	var rest := _tally()
	var way := _tally()
	room_tally_into(kind, centre, turns, ground, cells, rest, level)
	if passage.count >= 2:
		tally_into(passage, ground, way)
	var quanta := cells[T_QUANTA] + rest[T_QUANTA] + way[T_QUANTA]
	var ticks: int = cells[T_TICKS] * Rules.PERMILLE / maxi(rate_room, 1) \
		+ (rest[T_TICKS] + way[T_TICKS]) * Rules.PERMILLE / maxi(rate_one, 1)
	var first := "%s · %d quanta · %s (%s)" % [RoomsScript.NAMES[kind], quanta, time_text(ticks),
		"crew of %d" % crew if crew > 1 else "one digger"]
	var joined := "passage %s to %s" % [PlanScript.length_text(passage.length_u()), passage_to] if passage.count >= 2 \
			else "standalone: dig a tunnel to one of its sockets later"
	return "%s\n%d U spoil · %s" % [first, (cells[T_SPOIL] + rest[T_SPOIL] + way[T_SPOIL]) / 1000, joined]


static func time_text(ticks: int) -> String:
	"""Dig ticks as time on the demo calendar (decision 0421: 750 a game hour): under an hour in whole minutes, rounded
	up ("35 min"); from an hour in hours to the tenth, floored, never under "1.0 h" ("2.1 h")."""
	var minutes: int = (ticks * 60 + TICKS_PER_CALENDAR_HOUR - 1) / TICKS_PER_CALENDAR_HOUR
	if minutes < 60:
		return "%d min" % minutes
	var tenths: int = maxi(ticks * 10 / TICKS_PER_CALENDAR_HOUR, 10)
	return "%d.%d h" % [tenths / 10, tenths % 10]


static func _tally() -> PackedInt64Array:
	"""An empty tally (T_* slots)."""
	var tally := PackedInt64Array()
	tally.resize(T_SIZE)
	return tally


static func room_tally_into(kind: int, centre: Vector2i, turns: int, ground: GroundScript, cells: PackedInt64Array,
		ramp: PackedInt64Array, level: int = Rules.TOP_LEVEL) -> void:
	"""A room's own quanta cell by cell on its level into `cells` (underground_rooms.gd `cell_local`), and on level 1
	its door ramp's -- the shaft at its mouth and each metre down -- into `ramp` (a lower level's room has none)."""
	for k in RoomsScript.total_quanta(kind):
		_count(ground, centre + RoomsScript.rotate_u(RoomsScript.cell_local(kind, k), turns), cells, false, level)
	if level != Rules.TOP_LEVEL:
		return
	var hole := RoomsScript.mouth_at(kind, centre, turns)
	var door := RoomsScript.door_at(kind, centre, turns)
	_count(ground, hole, ramp, false)
	var metres := Rules.bore_quanta(Rules.RAMP_RUN_U)
	for k in metres:
		_count(ground, hole + (door - hole) * (2 * k + 1) / (2 * metres), ramp, true)
