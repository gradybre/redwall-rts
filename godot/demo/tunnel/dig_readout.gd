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
## A ROOM's readout (`room_text`, decision 0209) is the room tool's: its own quanta cell by cell, its door ramp,
## and its proposed passage, the room at its crew's three-face rate.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
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


# --- a room (decision 0209) -------------------------------------------------------------------

static func room_text(kind: int, centre: Vector2i, turns: int, passage: PlanScript, ground: GroundScript,
		rate_one: int, rate_room: int, crew: int, passage_to: String) -> String:
	"""The room tool's readout (room_tool.gd): the room's name, all its quanta -- its cells, its door ramp and
	shaft, and its proposed passage -- the hours its crew takes (the room at its ROOM_FACES faces' rate
	`rate_room`, the rest at `rate_one`), its spoil, and its passage (or that it stands alone). e.g.
	"Burrow home · 33 quanta · 7.9 h (crew of 3)" over "66 U spoil · passage 3.2 m to Tunnel 4"."""
	var cells := _tally()
	var rest := _tally()
	var way := _tally()
	room_tally_into(kind, centre, turns, ground, cells, rest)
	if passage.count >= 2:
		tally_into(passage, ground, way)
	var quanta := cells[T_QUANTA] + rest[T_QUANTA] + way[T_QUANTA]
	var hours_tenths := (cells[T_TICKS] * Rules.PERMILLE * 10 / maxi(rate_room, 1)
		+ (rest[T_TICKS] + way[T_TICKS]) * Rules.PERMILLE * 10 / maxi(rate_one, 1)) / TICKS_PER_CALENDAR_HOUR
	var first := "%s · %d quanta · %d.%d h (%s)" % [RoomsScript.NAMES[kind], quanta, hours_tenths / 10, hours_tenths % 10,
		"crew of %d" % crew if crew > 1 else "one digger"]
	var joined := "passage %s to %s" % [PlanScript.length_text(passage.length_u()), passage_to] if passage.count >= 2 \
			else "standalone: dig a tunnel to one of its sockets later"
	return "%s\n%d U spoil · %s" % [first, (cells[T_SPOIL] + rest[T_SPOIL] + way[T_SPOIL]) / 1000, joined]


static func _tally() -> PackedInt64Array:
	"""An empty tally (T_* slots)."""
	var tally := PackedInt64Array()
	tally.resize(T_SIZE)
	return tally


static func room_tally_into(kind: int, centre: Vector2i, turns: int, ground: GroundScript, cells: PackedInt64Array,
		ramp: PackedInt64Array) -> void:
	"""A room's own quanta cell by cell into `cells` (underground_rooms.gd `cell_local`), and its door ramp's --
	the shaft at its mouth and each metre down -- into `ramp`."""
	for k in RoomsScript.total_quanta(kind):
		_count(ground, centre + RoomsScript.rotate_u(RoomsScript.cell_local(kind, k), turns), cells, false)
	var hole := RoomsScript.mouth_at(kind, centre, turns)
	var door := RoomsScript.door_at(kind, centre, turns)
	_count(ground, hole, ramp, false)
	var metres := Rules.bore_quanta(Rules.RAMP_RUN_U)
	for k in metres:
		_count(ground, hole + (door - hole) * (2 * k + 1) / (2 * metres), ramp, true)
