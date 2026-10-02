extends RefCounted
## The rules of the demo's player-dug tunnels: units, digging time, spoil, bore fit and route
## validation. Decision 0196 (live demo). PRESENTATION ONLY -- nothing here feeds the simulation,
## whose movement and excavation are not built (MOVE-G01..05 are open). Pure static functions over
## integers, so the tests can pin every boundary exactly.
##
## ---------------------------------------------------------------------------------------
## UNITS. Positions and lengths are integers in u = 1/1024 m (AGENTS.md: positions are int32 in
## 1/1024 m units), so the cut lattice of SET-MOVE-ECON-001 ECON-001 -- a 1024u cube, 1 m^3 -- is
## exact. Time is integer fixed ticks at 30 per second (AGENTS.md). A float enters only at the
## import boundary (`to_u`, a click or a body size) and leaves only for drawing.
##
## CITED VALUES (docs/underground_economy_hazard_amendment.md, adopted by decision 0107):
##   * one cut quantum is a 1024u cube (ECON-001);
##   * brace 25 + cut 50 + finish 38 = 113 ticks per quantum for one F1000 worker (ECON-003's
##     worked example; the digger here works at F1000 with no modifiers);
##   * each quantum's CUT posts exactly one 2000 milli-U `excavated_earth` output (ECON-002). It
##     posts when the cut phase completes, 25 + 50 = 75 ticks into the quantum.
##
## DEMO VALUES (nothing adopted settles them; each is named here and listed in the report):
##   * BORE: one quantum wide and one high. ECON-002 says its example clear height "is an example
##     only, not a creature-fit ruling", and G01/G02 own tunnel geometry, so the bore is a demo
##     choice -- the smallest the lattice allows, which makes one metre of tunnel one quantum.
##   * SHAFTS: the entrance and the exit are one quantum each, dug before and after the bore.
##   * STOOP: a body may lower itself to STOOP_PERMILLE of its standing height in a bore. Fit is
##     2 * radius <= bore width AND ceil(height * stoop) <= bore height (MOVE-REQ-005 names the
##     failed condition). That admits mice, moles and squirrels and refuses otters and badgers.
##   * Route limits (points, length, the hole's clearance, the gap between points). Who digs is the
##     digging SKILL now (dig_skills.gd, decision 0208: anybeast who fits a bore; moles start skilled);
##     `is_digger` names the species that starts with it.
##   * A bore passes under open ground, trees and props, but never under a building or the well:
##     no leg may come within half a bore of a building's footprint circles (UNDER BUILDINGS).
##   * A mouth keeps SPOT_CLEAR_U clear of every work spot and every other tunnel's mouth, so no one
##     is sent to stand in a hole and no two holes overlap.
##   * RAMPS (decision 0207; design docs/design/underground_revamp.md §3 rule 6): each mouth's ramp goes
##     BORE_FLOOR_DEPTH_U down at no steeper than RAMP_GRADE_RISE:RAMP_GRADE_RUN (1:2.5), its ends eased
##     over RAMP_FILLET_U so the grade never jumps under a walker's feet -- RAMP_RUN_U (4 m) a ramp. A
##     route too short for both ramps to reach the tunnels' depth would need them steeper, and is refused
##     (REFUSE_RAMP_TOO_STEEP).
##   * DRAWN BORE AND STOOP (decision 0207; design §3 "Geometry"): the swept bore's drawn crown,
##     BORE_CROWNS_U per class -- the standard 1.0 m; the widened 1.1 m, since level 1's floor lies only
##     1.25 m down (a taller bore would break the surface); a room's 2.75 m (decision 0209: HEADROOM -- the
##     room rises into its own turfed mound, so everybeast stands upright in it). Presentation only: a walker in
##     a bore lowers its head to STOOP_CLEAR_U under the crown, by at most STOOP_MAX_PERMILLE of its height
##     (`stoop_drop_u`). Moles walk upright, mice stoop a little, squirrels more; otters, the beaver and
##     the badger stoop as far as they can.

const UNITS_PER_M: int = 1024
const TICKS_PER_SECOND: int = 30
const USEC_PER_SECOND: int = 1000000
const PERMILLE: int = 1000

# --- cited: SET-MOVE-ECON-001 ------------------------------------------------------------------
const QUANTUM_U: int = 1024
const BRACE_TICKS: int = 25
const CUT_TICKS: int = 50
const FINISH_TICKS: int = 38
const TICKS_PER_QUANTUM: int = BRACE_TICKS + CUT_TICKS + FINISH_TICKS
const SPOIL_PER_QUANTUM_MILLI_U: int = 2000

# --- demo -----------------------------------------------------------------------------------
const BORE_WIDTH_U: int = 1024
const BORE_HEIGHT_U: int = 1024
@warning_ignore("integer_division") const CROSS_SECTION_QUANTA: int = (BORE_WIDTH_U / QUANTUM_U) * (BORE_HEIGHT_U / QUANTUM_U)
const SHAFT_QUANTA: int = 1
const STOOP_PERMILLE: int = 850
## WIDE BORE (demo, the WIDEN upgrade): two quanta wide and three high -- the smallest lattice bore
## an otter (1.49 m, stooped 1.27 m) and the badger (2.55 m, stooped 2.17 m; 1.12 m across) fit.
## Six quanta a metre, so widening re-digs WIDE_EXTRA_QUANTA more of them per metre (and per shaft).
## ROOM (decision 0209, the underground revamp's P3): the class of a room's own segments -- the walk from
## its door's foot or a socket to its middle -- as wide as a room and ROOM_CROWN_U high, so everybeast,
## the badger too, fits and stands upright in it. No bore is widened to it; only rooms are.
const BORE_STANDARD: int = 0
const BORE_WIDE: int = 1
const BORE_ROOM: int = 2
const BORE_WIDTHS_U: Array[int] = [1024, 2048, 4096]
const BORE_HEIGHTS_U: Array[int] = [1024, 3072, 2816]
const WIDE_QUANTA: int = 6
const WIDE_EXTRA_QUANTA: int = WIDE_QUANTA - CROSS_SECTION_QUANTA
## LOADED (demo): a carrier holds its load across its body, hand to hand with an overhang, so its
## width while carrying is LOAD_WIDTH_PERMILLE of its standing height (never less than its own
## body). MOVE-REQ-005: the carried-load condition is checked like any other and names the failed
## dimension. With 850 every body that fits a standard bore fits it loaded (a mouse is 0.85 m wide
## with its log, a squirrel 0.98 m), an otter hauls only through a wide bore, and the badger -- 2.17 m
## across with its load -- through none.
const LOAD_WIDTH_PERMILLE: int = 850
## A mouth must not cut into an obstacle: its centre stays half a bore clear of every circle.
@warning_ignore("integer_division") const MOUTH_CLEAR_U: int = BORE_WIDTH_U / 2
## Two consecutive points closer than this would make a leg with no direction.
const MIN_POINT_GAP_U: int = 256
const MIN_LENGTH_U: int = 2 * QUANTUM_U
const MAX_LENGTH_U: int = 64 * QUANTUM_U
## Entrance, up to six bends, exit.
const MAX_POINTS: int = 8
## The species that starts with the digging skill (dig_skills.gd; `is_digger`, a name kept for the verbatim
## rules tests): anybeast who fits a bore may dig (decision 0208).
const DIGGER_SPECIES: String = "mole"
## Presentation only: how deep the bore's floor runs (BORE_FLOOR_DEPTH_U in metres).
const BORE_FLOOR_DEPTH_M: float = 1.25
const BORE_FLOOR_DEPTH_U: int = 1280
## RAMPS (see the header): the steepest grade, rise to run, and each end's easing.
const RAMP_GRADE_RISE: int = 2
const RAMP_GRADE_RUN: int = 5
const RAMP_FILLET_U: int = 896
## A ramp's whole run: the depth at the steepest grade, plus the easing (4096u, 4 m).
@warning_ignore("integer_division") const RAMP_RUN_U: int = BORE_FLOOR_DEPTH_U * RAMP_GRADE_RUN / RAMP_GRADE_RISE + RAMP_FILLET_U
## THE DRAWN BORE AND THE STOOP (see the header), per bore class.
const BORE_CROWNS_U: Array[int] = [1024, 1126, 2816]
## HEADROOM (decision 0209): a room's drawn crown over its floor -- the badger (2.55 m) plus STOOP_CLEAR_U,
## rounded up to the quarter metre: 2.75 m. Rooms keep level 1's floor, so the crown rises 1.5 m over the
## ground, and the turfed mound over it on the surface IS the room (design §3).
const ROOM_CROWN_U: int = 2816
const STOOP_CLEAR_U: int = 102
const STOOP_MAX_PERMILLE: int = 350
## Presentation: a mouth's hole and the earthen rim round it (the rim reaches RIM_FACTOR further).
const HOLE_RADIUS_M: float = 0.42
const RIM_FACTOR: float = 1.45

const STAGE_ENTRANCE: int = 0
const STAGE_BORE: int = 1
const STAGE_EXIT: int = 2
const STAGE_OPEN: int = 3

const FIT_OK: int = 0
const FIT_TOO_WIDE: int = 1
const FIT_TOO_TALL: int = 2

const REFUSE_NONE: int = 0
const REFUSE_TOO_FEW_POINTS: int = 1
const REFUSE_TOO_MANY_POINTS: int = 2
const REFUSE_OUT_OF_BOUNDS: int = 3
const REFUSE_ENTRANCE_BLOCKED: int = 4
const REFUSE_EXIT_BLOCKED: int = 5
const REFUSE_TOO_SHORT: int = 6
const REFUSE_TOO_LONG: int = 7
const REFUSE_NO_ROOM: int = 8
const REFUSE_UNREACHABLE: int = 9
const REFUSE_NOT_A_DIGGER: int = 10
const REFUSE_BUSY: int = 11
const REFUSE_REPEATED_POINT: int = 12
const REFUSE_UNDER_BUILDING: int = 13
const REFUSE_ENTRANCE_OCCUPIED: int = 14
const REFUSE_ON_SPOT: int = 15
const REFUSE_UNDER_WATER: int = 16
const REFUSE_RAMP_TOO_STEEP: int = 17
const REASONS: Array[String] = [
	"",
	"a tunnel needs an entrance and an exit",
	"a tunnel has at most 8 points",
	"that is outside the village",
	"the entrance would open inside a building or obstacle",
	"the exit would open inside a building or obstacle",
	"a tunnel must be at least 2 m long",
	"a tunnel can be at most 64 m long",
	"no more tunnels can be dug in this demo (8 at most)",
	"the mole cannot reach that entrance",
	"nobody selected can dig -- select someone who fits a bore (moles dig best)",
	"the mole is already digging a tunnel",
	"each point must be at least 0.25 m from the one before",
	"a tunnel cannot pass under a building or the well",
	"someone is standing on that entrance",
	"a mouth would open on a work spot or another tunnel's mouth",
	"a tunnel cannot pass under the stream or the pond",
	"too short for its ramps: going 1.25 m down and back up at no steeper than 1:2.5 takes 8 m",
]


static func reason_text(code: int) -> String:
	"""The words for a refusal code (REFUSE_*)."""
	return REASONS[code]


static func to_u(metres: float) -> int:
	"""A float length or coordinate in metres, as integer u (the import boundary)."""
	return roundi(metres * float(UNITS_PER_M))


static func to_m(units: int) -> float:
	"""Integer u as float metres, for drawing."""
	return float(units) / float(UNITS_PER_M)


static func isqrt(n: int) -> int:
	"""The exact floor square root of a non-negative integer (a float seed, corrected exactly)."""
	if n < 2:
		return maxi(n, 0)
	var x := int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x


static func ceil_div(a: int, b: int) -> int:
	"""ceil(a / b) for a >= 0, b > 0."""
	@warning_ignore("integer_division") return (a + b - 1) / b


static func isqrt_ceil(n: int) -> int:
	"""The exact ceiling square root of a non-negative integer."""
	var x := isqrt(n)
	return x if x * x == n else x + 1


static func leg_squared_u(points_u: PackedInt32Array, k: int) -> int:
	"""The squared length in u^2 of the leg ending at point `k` (k >= 1)."""
	var dx := points_u[2 * k] - points_u[2 * k - 2]
	var dz := points_u[2 * k + 1] - points_u[2 * k - 1]
	return dx * dx + dz * dz


static func route_length_u(points_u: PackedInt32Array, count: int) -> int:
	"""The route's length in u: the sum of each leg's floored integer length. Points are (x, z) pairs."""
	var total := 0
	for k in range(1, count):
		total += isqrt(leg_squared_u(points_u, k))
	return total


static func route_cost_u(points_u: PackedInt32Array, count: int) -> int:
	"""What walking the route costs a planner, in u: each leg's length rounded UP, so a tunnel is never
	costed below its true length and can never undercut an equally long walk by a floored sliver."""
	var total := 0
	for k in range(1, count):
		total += isqrt_ceil(leg_squared_u(points_u, k))
	return total


static func bore_quanta(length_u: int) -> int:
	"""Cut quanta in the bore: every started metre is a whole quantum (ECON-001: no partial quantum)."""
	return ceil_div(length_u, QUANTUM_U) * CROSS_SECTION_QUANTA


# --- digging time and spoil -------------------------------------------------------------------

static func total_ticks(quanta: int) -> int:
	"""Ticks to dig a tunnel of `quanta` bore quanta: entrance shaft, bore, exit shaft."""
	return (quanta + 2 * SHAFT_QUANTA) * TICKS_PER_QUANTUM


static func done_ticks(dig_usec: int, quanta: int) -> int:
	"""Whole fixed ticks of digging in `dig_usec` microseconds of work, capped at the total."""
	@warning_ignore("integer_division") return mini(total_ticks(quanta), dig_usec * TICKS_PER_SECOND / USEC_PER_SECOND)


static func stage_of(done: int, quanta: int) -> int:
	"""STAGE_*: which part is being dug after `done` ticks, or STAGE_OPEN once all of it is."""
	if done >= total_ticks(quanta):
		return STAGE_OPEN
	if done < SHAFT_QUANTA * TICKS_PER_QUANTUM:
		return STAGE_ENTRANCE
	if done < (SHAFT_QUANTA + quanta) * TICKS_PER_QUANTUM:
		return STAGE_BORE
	return STAGE_EXIT


static func percent(done: int, quanta: int) -> int:
	"""Whole percent of the tunnel dug (floored, so 100 only when it is open)."""
	@warning_ignore("integer_division") return done * 100 / total_ticks(quanta)


static func cut_quanta(done: int) -> int:
	"""Quanta whose CUT has completed after `done` ticks: every whole quantum, plus the current one
	once its brace and cut phases are through."""
	var partial := 1 if done % TICKS_PER_QUANTUM >= BRACE_TICKS + CUT_TICKS else 0
	@warning_ignore("integer_division") return done / TICKS_PER_QUANTUM + partial


static func spoil_into(done: int, quanta: int, out: PackedInt64Array) -> void:
	"""Write the spoil (milli-U of excavated_earth) heaped at the entrance into out[0] and at the exit
	into out[1]. The entrance shaft and the bore spoil out of the entrance, the only opening while
	they are dug; the exit shaft's own quantum spoils out of the exit. `out` has at least 2 slots."""
	var cut := cut_quanta(done)
	var through_entrance := SHAFT_QUANTA + quanta
	out[0] = mini(cut, through_entrance) * SPOIL_PER_QUANTUM_MILLI_U
	out[1] = maxi(cut - through_entrance, 0) * SPOIL_PER_QUANTUM_MILLI_U


static func face_u(done: int, quanta: int, length_u: int) -> int:
	"""How far along the route the dig face has reached after `done` ticks, in u (0 during the
	entrance shaft, the whole length from the exit shaft on)."""
	var into_bore := clampi(done - SHAFT_QUANTA * TICKS_PER_QUANTUM, 0, quanta * TICKS_PER_QUANTUM)
	@warning_ignore("integer_division") return into_bore * length_u / (quanta * TICKS_PER_QUANTUM)


# --- who fits, who digs -----------------------------------------------------------------------

static func fit_refusal(height_u: int, radius_u: int) -> int:
	"""FIT_OK, or the condition a body of this standing height and radius fails in the bore
	(MOVE-REQ-005): too wide (2 * radius > bore width), or too tall even stooped."""
	if 2 * radius_u > BORE_WIDTH_U:
		return FIT_TOO_WIDE
	if ceil_div(height_u * STOOP_PERMILLE, PERMILLE) > BORE_HEIGHT_U:
		return FIT_TOO_TALL
	return FIT_OK


static func fits_bore(height_u: int, radius_u: int) -> bool:
	"""Whether a body of this standing height and radius may use a bore."""
	return fit_refusal(height_u, radius_u) == FIT_OK


static func fit_refusal_in(height_u: int, width_u: int, bore: int) -> int:
	"""FIT_OK, or the condition a body this tall and this wide (u) fails in a bore of class `bore`
	(BORE_STANDARD or BORE_WIDE): too wide, or too tall even stooped (MOVE-REQ-005)."""
	if width_u > BORE_WIDTHS_U[bore]:
		return FIT_TOO_WIDE
	if ceil_div(height_u * STOOP_PERMILLE, PERMILLE) > BORE_HEIGHTS_U[bore]:
		return FIT_TOO_TALL
	return FIT_OK


static func loaded_width_u(height_u: int, radius_u: int) -> int:
	"""A carrier's width with its load across it: LOAD_WIDTH_PERMILLE of its height, at least its body."""
	return maxi(2 * radius_u, ceil_div(height_u * LOAD_WIDTH_PERMILLE, PERMILLE))


static func is_digger(species: String) -> bool:
	"""Whether residents of this species start with the digging skill (demo: moles; dig_skills.gd)."""
	return species.to_lower() == DIGGER_SPECIES


# --- route validation -------------------------------------------------------------------------

static func circles_to_u(circles: PackedVector3Array) -> PackedInt32Array:
	"""Obstacle circles (x, radius, z) in metres as integer (x, radius, z) triples in u (import)."""
	var out := PackedInt32Array()
	out.resize(circles.size() * 3)
	for i in circles.size():
		out[3 * i] = to_u(circles[i].x)
		out[3 * i + 1] = to_u(circles[i].y)
		out[3 * i + 2] = to_u(circles[i].z)
	return out


static func mouth_blocked(x_u: int, z_u: int, circles_u: PackedInt32Array) -> bool:
	"""Whether a mouth centred here would cut into an obstacle: closer than its radius plus
	MOUTH_CLEAR_U to any circle's centre."""
	@warning_ignore("integer_division") for i in circles_u.size() / 3:
		var dx := x_u - circles_u[3 * i]
		var dz := z_u - circles_u[3 * i + 2]
		var reach := circles_u[3 * i + 1] + MOUTH_CLEAR_U
		if dx * dx + dz * dz < reach * reach:
			return true
	return false


static func in_bounds(x_u: int, z_u: int, bounds_u: Rect2i) -> bool:
	"""Whether a whole bore (half its width either side) at this point stays inside the bounds."""
	@warning_ignore("integer_division") var half := BORE_WIDTH_U / 2
	return x_u - half >= bounds_u.position.x and x_u + half <= bounds_u.end.x \
			and z_u - half >= bounds_u.position.y and z_u + half <= bounds_u.end.y


static func validate_point(x_u: int, z_u: int, index: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""REFUSE_NONE, or why a route cannot take this as its point `index` (checked as it is laid):
	past the point limit, outside the bounds, or -- for the entrance -- inside an obstacle or on a
	spot (x, radius, z triples kept clear like obstacles; see the header)."""
	if index >= MAX_POINTS:
		return REFUSE_TOO_MANY_POINTS
	if not in_bounds(x_u, z_u, bounds_u):
		return REFUSE_OUT_OF_BOUNDS
	if index == 0 and mouth_blocked(x_u, z_u, circles_u):
		return REFUSE_ENTRANCE_BLOCKED
	if index == 0 and mouth_blocked(x_u, z_u, spots_u):
		return REFUSE_ON_SPOT
	return REFUSE_NONE


static func points_too_close(points_u: PackedInt32Array, k: int) -> bool:
	"""Whether point `k` (k >= 1) lies closer than MIN_POINT_GAP_U to point k - 1."""
	return leg_squared_u(points_u, k) < MIN_POINT_GAP_U * MIN_POINT_GAP_U


static func validate_route(points_u: PackedInt32Array, count: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array(), under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""REFUSE_NONE, or the first reason the whole route is refused: its point count, a point outside
	the bounds or on top of the last, a mouth inside an obstacle or on a spot, a leg under a
	building (`under_u`), or its length. Bends may pass under anything else."""
	return validate_piece_route(points_u, count, bounds_u, circles_u, spots_u, under_u, true, true)


static func validate_piece_route(points_u: PackedInt32Array, count: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array, under_u: PackedInt32Array, start_mouth: bool, end_mouth: bool) -> int:
	"""`validate_route` for a piece of the network (decision 0208), whose start or end may join the network
	instead of opening a mouth: the mouth checks are made only at an end that opens one."""
	if count < 2:
		return REFUSE_TOO_FEW_POINTS
	if count > MAX_POINTS:
		return REFUSE_TOO_MANY_POINTS
	for k in count:
		if not in_bounds(points_u[2 * k], points_u[2 * k + 1], bounds_u):
			return REFUSE_OUT_OF_BOUNDS
		if k > 0 and points_too_close(points_u, k):
			return REFUSE_REPEATED_POINT
	var mouths := _mouth_reason(points_u, count, circles_u, spots_u, start_mouth, end_mouth)
	if mouths != REFUSE_NONE:
		return mouths
	for k in range(1, count):
		if leg_under(points_u, k, under_u):
			return REFUSE_UNDER_BUILDING
	return _length_reason(route_length_u(points_u, count))


static func _mouth_reason(points_u: PackedInt32Array, count: int, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array, start_mouth: bool, end_mouth: bool) -> int:
	"""REFUSE_NONE, or why the entrance or exit (where the route opens one) may not open where it is."""
	var last := 2 * count - 2
	if start_mouth and mouth_blocked(points_u[0], points_u[1], circles_u):
		return REFUSE_ENTRANCE_BLOCKED
	if end_mouth and mouth_blocked(points_u[last], points_u[last + 1], circles_u):
		return REFUSE_EXIT_BLOCKED
	if (start_mouth and mouth_blocked(points_u[0], points_u[1], spots_u)) \
			or (end_mouth and mouth_blocked(points_u[last], points_u[last + 1], spots_u)):
		return REFUSE_ON_SPOT
	return REFUSE_NONE


static func _length_reason(length: int) -> int:
	"""REFUSE_NONE, or why a route of this length (u) is too short or too long."""
	if length < MIN_LENGTH_U:
		return REFUSE_TOO_SHORT
	if length > MAX_LENGTH_U:
		return REFUSE_TOO_LONG
	return REFUSE_NONE


static func leg_under(points_u: PackedInt32Array, k: int, under_u: PackedInt32Array) -> bool:
	"""Whether the leg ending at point `k` passes within half a bore of any (x, radius, z) circle in
	`under_u` -- a building's footprint. Exact integers: beyond either end the distance is to that
	end (squared); alongside, the leg is refused when |cross| < reach x isqrt(|leg|^2), the
	perpendicular distance measured against the leg's floored length, so no product overflows."""
	var ax := points_u[2 * k - 2]
	var az := points_u[2 * k - 1]
	var abx := points_u[2 * k] - ax
	var abz := points_u[2 * k + 1] - az
	var length_sq := abx * abx + abz * abz
	@warning_ignore("integer_division") for i in under_u.size() / 3:
		var acx := under_u[3 * i] - ax
		var acz := under_u[3 * i + 2] - az
		@warning_ignore("integer_division") var reach := under_u[3 * i + 1] + BORE_WIDTH_U / 2
		var along := abx * acx + abz * acz
		if along <= 0 and acx * acx + acz * acz < reach * reach:
			return true
		var bcx := acx - abx
		var bcz := acz - abz
		if along >= length_sq and bcx * bcx + bcz * bcz < reach * reach:
			return true
		if along > 0 and along < length_sq and absi(abx * acz - abz * acx) < reach * isqrt(length_sq):
			return true
	return false


# --- ramps and the drawn bore (presentation; see the header) ----------------------------------

static func ramp_grade_ok(depth_u: int, run_u: int, fillet_u: int) -> bool:
	"""Whether a ramp going `depth_u` down over `run_u`, eased over `fillet_u` at each end, is nowhere
	steeper than RAMP_GRADE_RISE:RAMP_GRADE_RUN: its straight middle, the steepest part, falls
	depth over (run - fillet)."""
	return depth_u * RAMP_GRADE_RUN <= (run_u - fillet_u) * RAMP_GRADE_RISE


static func ramp_refusal(length_u: int) -> int:
	"""REFUSE_RAMP_TOO_STEEP when a route this long (u) is too short for a ramp at each mouth to reach
	the tunnels' depth at the ramps' grade; REFUSE_NONE otherwise. The planner asks it last, once the
	route is otherwise sound (tunnel_plan.gd route_reason), so a route under water says so first."""
	return REFUSE_RAMP_TOO_STEEP if length_u < 2 * RAMP_RUN_U else REFUSE_NONE


static func ramp_depth_m(from_mouth_m: float) -> float:
	"""How far below the ground a ramp's floor lies this far from its mouth (m): eased in over the
	fillet, straight at the steepest grade, eased out to the full depth at RAMP_RUN_U."""
	var grade := float(RAMP_GRADE_RISE) / float(RAMP_GRADE_RUN)
	var fillet := to_m(RAMP_FILLET_U)
	var run := to_m(RAMP_RUN_U)
	var x := clampf(from_mouth_m, 0.0, run)
	if x <= fillet:
		return grade * x * x / (2.0 * fillet)
	if x >= run - fillet:
		return BORE_FLOOR_DEPTH_M - grade * (run - x) * (run - x) / (2.0 * fillet)
	return grade * (x - fillet * 0.5)


static func ramp_slope(from_mouth_m: float) -> float:
	"""How steeply the ramp falls this far from its mouth (m of depth per m along; 0 past the run)."""
	var grade := float(RAMP_GRADE_RISE) / float(RAMP_GRADE_RUN)
	var fillet := to_m(RAMP_FILLET_U)
	var run := to_m(RAMP_RUN_U)
	if from_mouth_m <= 0.0 or from_mouth_m >= run:
		return 0.0
	if from_mouth_m <= fillet:
		return grade * from_mouth_m / fillet
	if from_mouth_m >= run - fillet:
		return grade * (run - from_mouth_m) / fillet
	return grade


static func floor_y_m(along_m: float, length_m: float) -> float:
	"""Presentation: the bore floor's height (negative, below ground) this far along a tunnel, down each
	mouth's ramp (`ramp_depth_m`; a tunnel too short for both stays shallower in the middle)."""
	return -ramp_depth_m(minf(along_m, length_m - along_m))


static func floor_grade(along_m: float, length_m: float) -> float:
	"""Presentation: how the floor's height changes per metre along, entrance to exit (negative going
	down the entrance's ramp, positive coming up the exit's)."""
	if along_m <= length_m - along_m:
		return -ramp_slope(along_m)
	return ramp_slope(length_m - along_m)


static func crown_m(bore: int) -> float:
	"""The drawn crown of a bore of class `bore` over its floor (m)."""
	return to_m(BORE_CROWNS_U[bore])


static func portal_m(bore: int) -> float:
	"""How far down its ramp a bore of class `bore` goes under the ground: where the ramp is as deep as
	the crown is high (m from the mouth). Before it the ramp is an open cutting."""
	var crown := crown_m(bore)
	var lo := 0.0
	var hi := to_m(RAMP_RUN_U)
	for i in 30:
		var mid := (lo + hi) * 0.5
		if ramp_depth_m(mid) < crown:
			lo = mid
		else:
			hi = mid
	return hi


static func stoop_drop_u(height_u: int, crown_u: int) -> int:
	"""How far (u) a walker `height_u` tall lowers its head in a bore with this drawn crown: to
	STOOP_CLEAR_U under it, but at most STOOP_MAX_PERMILLE of its height (see the header)."""
	var need := height_u - (crown_u - STOOP_CLEAR_U)
	@warning_ignore("integer_division") return clampi(need, 0, height_u * STOOP_MAX_PERMILLE / PERMILLE)


# --- the network's connection rules (decision 0208) -------------------------------------------
##
## THE NETWORK (underground_graph.gd) joins bores at JUNCTIONS. Its connection rules are DEMO VALUES
## (design docs/design/underground_revamp.md §3 "Connection rules"), checked in integers on the route
## polylines -- the drawn curve (bore_curve.gd) only rounds their corners:
##   * JUNCTION_GAP_U: a junction stands at least 1.5 m from every other node (a junction, a ramp's foot,
##     a mouth), so no two hubs overlap.
##   * MEETING: a branch meets its host, and a crossing crosses it, at 40 degrees or more either way; at an
##     existing junction a new branch keeps 40 degrees from every branch already there. Compared on unit
##     directions DIR_SCALE long: |sin| >= MEET_SIN_PERMILLE, and cos <= MEET_COS_PERMILLE.
##   * PILLAR_U: voids that are not joined keep 1 m of solid earth between them in plan -- centreline to
##     centreline, at least both half-widths and the pillar (`pillar_gap_u`). Within JOIN_ZONE_U of a node
##     two bores share they are joined there, and exempt. Checked every PILLAR_STEP_U of the new route.
##   * BEND_RADIUS_U: the drawn centreline turns no tighter than 1 m. A corner's fillet reaches
##     `fillet_reach_u` along each leg, and must fit in FILLET_SHARE_PERMILLE of the shorter one.
##   * A mouth's RAMP runs straight for RAMP_RUN_U: the first bend stands beyond it.
##   * JUNCTION_DEGREE: at most four bores meet at one junction (its hub has four openings).
##   * LEVELS (decision 0212, the revamp's P6): level 1's floor is BORE_FLOOR_DEPTH_U down, and every mouth
##     opens onto it (TOP_LEVEL). Level 2's lies LEVEL_SPACING_U lower -- DEC-040's CANDIDATE 4 m spacing,
##     carried here as a named demo value and NOT settled: MOVE-G01..05 stay open. Both are dug
##     (`is_buildable_level`); nothing opens onto level 2 from the surface, so it is reached only by a LINK.
##   * LINKS (see LINKS below): a RAMP or STAIRS segment is the only thing that joins two levels (design §3
##     rule 7). It runs straight, from a point on level 1's network down to level 2.
## Their refusals are LINK_BASE + k, worded in LINK_REASONS (MOVE-REQ-018: in text, not colour alone); a
## "%s" in one is the tunnel it names (`link_text`).

## The network's capacity (design §3's demo caps): nodes, bores (segments), surface mouths, pieces.
const MAX_NODES: int = 96
const MAX_SEGMENTS: int = 96
## Mouths: 16 for tunnels as before, and one more for each room's own door or hatch (decision 0209:
## underground_rooms.gd MAX_ROOMS).
const MAX_MOUTHS: int = 24
## A piece has at least one segment, so a piece row per segment row: the pieces never run out first (a
## finished piece keeps its row -- its segments still name it).
const MAX_PIECES: int = MAX_SEGMENTS
const JUNCTION_GAP_U: int = 1536
const DIR_SCALE: int = 1024
const MEET_SIN_PERMILLE: int = 642
const MEET_COS_PERMILLE: int = 766
const PILLAR_U: int = 1024
const JOIN_ZONE_U: int = 3200
const PILLAR_STEP_U: int = 256
const BEND_RADIUS_U: int = 1024
const FILLET_SHARE_PERMILLE: int = 450
const JUNCTION_DEGREE: int = 4
const LEVEL_SURFACE: int = 0
const LEVEL_1: int = 1
const LEVEL_2: int = 2
## The level every mouth opens onto (and every room's own door or hatch reaches): level 1.
const TOP_LEVEL: int = LEVEL_1
const DEEPEST_LEVEL: int = LEVEL_2
## THE CANDIDATE SPACING between level floors (DEC-040's 4 m; a demo value, unsettled against MOVE-G01..05).
const LEVEL_SPACING_U: int = 4096
const LEVEL_2_FLOOR_DEPTH_U: int = BORE_FLOOR_DEPTH_U + LEVEL_SPACING_U
## A turn this near straight back has no fillet that fits anywhere.
const TURN_BACK_SLACK: int = 64

const LINK_BASE: int = 100
const REFUSE_NEAR_NODE: int = 100
const REFUSE_SHALLOW_MEETING: int = 101
const REFUSE_PILLAR: int = 102
const REFUSE_SHALLOW_CROSSING: int = 103
const REFUSE_TIGHT_BEND: int = 104
const REFUSE_RAMP_BEND: int = 105
const REFUSE_JOIN_RAMP: int = 106
const REFUSE_JUNCTION_FULL: int = 107
const REFUSE_HOST_BUSY: int = 108
const REFUSE_NETWORK_FULL: int = 109
const REFUSE_SELF_PILLAR: int = 110
const REFUSE_SAME_NODE: int = 111
## A room's (decision 0209): a tunnel may not break into a room but at a free socket, and leaves one straight
## out through its wall.
const REFUSE_INTO_ROOM: int = 112
const REFUSE_SOCKET_ANGLE: int = 113
const REFUSE_SOCKET_TAKEN: int = 114
## The second level and the links down to it (decision 0212; see LINKS).
const REFUSE_LINK_START: int = 115
const REFUSE_RAMP_SHORT: int = 116
const REFUSE_STAIRS_SHORT: int = 117
const REFUSE_LINK_LONG: int = 118
const REFUSE_LINK_BEND: int = 119
const REFUSE_LOWER_START: int = 120
const REFUSE_JOIN_LINK: int = 121
const REFUSE_LOWER_JOIN: int = 122
## The network's capacity, by what ran out (decision 0361, the review's F08): the Dig tool opens whenever some piece
## could still fit, and the piece as laid is refused naming the capacity it would exhaust.
const REFUSE_NO_MOUTH_ROWS: int = 123
const REFUSE_NO_NODE_ROWS: int = 124
const REFUSE_NO_SEGMENT_ROWS: int = 125
## A socket's passage runs straight out of the wall this far (u) before it may bend, within the MEETING angle
## of straight out (design §3 rule 5: "a passage leaves a socket straight for >= 1 m").
const SOCKET_STRAIGHT_U: int = 1024
const LINK_REASONS: Array[String] = [
	"too near a junction, a ramp's foot or a mouth: keep 1.5 m from it",
	"tunnels meet at 40° or more: come at it more squarely",
	"it would break into %s: join it instead, or keep 1 m of earth between them",
	"it would cross %s at under 40°: cross it more squarely",
	"too sharp a bend: a tunnel turns no tighter than a 1 m radius",
	"a mouth's ramp runs straight for 4 m: put the first bend further in",
	"a ramp cannot be joined: join the tunnel below it",
	"four tunnels meet there already",
	"%s is being dug, worked on or is closed: join it once it is open and quiet",
	"the tunnel network is full in this demo (96 bores, 96 nodes, 24 mouths)",
	"it would run into itself: keep 1 m of earth between its turns",
	"a tunnel cannot start and end at the same place",
	"it would break into %s: join it at one of its sockets, or keep 1 m of earth from it",
	"a tunnel leaves a room's socket straight out through its wall for 1 m",
	"that socket already has a tunnel",
	"a ramp or stairs down starts on the first level's network: at a junction, a ramp's foot, a room's free socket or a bore's side",
	"too short for a ramp: going 4 m down at no steeper than 1:2.5 takes at least 10.9 m",
	"too short for stairs: 16 timber risers of 0.25 m need treads of at least 0.31 m -- 5 m of run",
	"too long: a ramp down runs at most 16 m, stairs at most 8 m",
	"a ramp or stairs runs straight from its head to its foot: no bends",
	"on the second level a tunnel starts from the network: from a stair's or ramp's foot, a junction or a bore",
	"stairs or a ramp between the levels cannot be joined on the slope: join it at its head or its foot",
	"a room on the second level is reached only through the tunnels: it needs a passage to the network",
	"all %d mouths in this demo are open: join the tunnels you have instead of opening a new mouth",
	"all %d junctions and ends in this demo are used: join at an existing junction or end",
	"all %d bores in this demo are laid: no room for another",
]
## The capacity each REFUSE_NO_*_ROWS refusal names, in order from REFUSE_NO_MOUTH_ROWS.
const ROWS_CAPS: Array[int] = [MAX_MOUTHS, MAX_NODES, MAX_SEGMENTS]


static func link_text(code: int, name: String) -> String:
	"""The words for any refusal code: a route's (REFUSE_*) or the network's (LINK_BASE and up), with
	`name` -- the tunnel it concerns -- where the words name one."""
	if code < LINK_BASE:
		return reason_text(code)
	var words := LINK_REASONS[code - LINK_BASE]
	if code >= REFUSE_NO_MOUTH_ROWS and code <= REFUSE_NO_SEGMENT_ROWS:
		return words % ROWS_CAPS[code - REFUSE_NO_MOUTH_ROWS]
	return words % name if words.contains("%s") else words


static func unit_of(dx: int, dz: int) -> Vector2i:
	"""The direction (dx, dz) as an integer vector DIR_SCALE long (truncated); zero stays zero."""
	var length := isqrt(dx * dx + dz * dz)
	if length == 0:
		return Vector2i.ZERO
	@warning_ignore("integer_division") return Vector2i(dx * DIR_SCALE / length, dz * DIR_SCALE / length)


static func meets_squarely(a: Vector2i, b: Vector2i) -> bool:
	"""Whether two directions (any length) cross at the MEETING angle or more, either way round."""
	var ua := unit_of(a.x, a.y)
	var ub := unit_of(b.x, b.y)
	var cross := absi(ua.x * ub.y - ua.y * ub.x)
	return cross * PERMILLE >= MEET_SIN_PERMILLE * DIR_SCALE * DIR_SCALE


static func leaves_straight(leaving: Vector2i, outward: Vector2i) -> bool:
	"""Whether a passage leaving a socket along `leaving` runs within the MEETING angle of straight out
	(`outward`, the socket's own direction out of its room): cos >= MEET_COS_PERMILLE."""
	var ua := unit_of(leaving.x, leaving.y)
	var ub := unit_of(outward.x, outward.y)
	return (ua.x * ub.x + ua.y * ub.y) * PERMILLE >= MEET_COS_PERMILLE * DIR_SCALE * DIR_SCALE


static func branches_apart(a: Vector2i, b: Vector2i) -> bool:
	"""Whether two branches leaving one junction (directions away from it) keep the MEETING angle apart."""
	var ua := unit_of(a.x, a.y)
	var ub := unit_of(b.x, b.y)
	return (ua.x * ub.x + ua.y * ub.y) * PERMILLE <= MEET_COS_PERMILLE * DIR_SCALE * DIR_SCALE


static func fillet_reach_u(into: Vector2i, onward: Vector2i) -> int:
	"""How far along each leg a corner's fillet reaches (u) for its tightest radius to be BEND_RADIUS_U,
	turning from `into` to `onward`: R tan(t/2) / cos(t/2) = R sqrt(2 (1 - cos t)) / (1 + cos t), the
	fillet bore_curve.gd draws. 0 straight on; MAX_LENGTH_U when it turns (almost) straight back."""
	var ua := unit_of(into.x, into.y)
	var ub := unit_of(onward.x, onward.y)
	var scale := DIR_SCALE * DIR_SCALE
	var c := ua.x * ub.x + ua.y * ub.y
	if c <= -scale + TURN_BACK_SLACK * DIR_SCALE:
		return MAX_LENGTH_U
	@warning_ignore("integer_division") return BEND_RADIUS_U * isqrt(2 * (scale - c) * scale) / (scale + c)


static func bend_ok(points_u: PackedInt32Array, k: int) -> bool:
	"""Whether corner `k` (0 < k < last) of a route bends no tighter than BEND_RADIUS_U: its fillet's reach
	fits in FILLET_SHARE_PERMILLE of the shorter leg beside it."""
	var into := Vector2i(points_u[2 * k] - points_u[2 * k - 2], points_u[2 * k + 1] - points_u[2 * k - 1])
	var onward := Vector2i(points_u[2 * k + 2] - points_u[2 * k], points_u[2 * k + 3] - points_u[2 * k + 1])
	var shorter := mini(isqrt(leg_squared_u(points_u, k)), isqrt(leg_squared_u(points_u, k + 1)))
	return fillet_reach_u(into, onward) * PERMILLE <= FILLET_SHARE_PERMILLE * shorter


static func point_leg_u(p: Vector2i, a: Vector2i, b: Vector2i) -> int:
	"""The distance (u) from P to leg A-B: to the nearer end beyond either, else across it (the cross
	product over the leg's floored length, so no product leaves int64)."""
	var ab := b - a
	var ap := p - a
	var length_sq := ab.x * ab.x + ab.y * ab.y
	var along := ab.x * ap.x + ab.y * ap.y
	if length_sq == 0 or along <= 0:
		return isqrt(ap.x * ap.x + ap.y * ap.y)
	if along >= length_sq:
		var bp := p - b
		return isqrt(bp.x * bp.x + bp.y * bp.y)
	@warning_ignore("integer_division") return absi(ab.x * ap.y - ab.y * ap.x) / isqrt(length_sq)


static func _turn_sign(a: Vector2i, b: Vector2i, p: Vector2i) -> int:
	"""Which side of the line A->B point P lies: 1 left, -1 right, 0 on it."""
	return signi((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x))


static func legs_cross(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	"""Whether legs A-B and C-D cross properly: each one's ends on opposite sides of the other's line
	(touching at an end is not a crossing)."""
	return _turn_sign(a, b, c) * _turn_sign(a, b, d) < 0 and _turn_sign(c, d, a) * _turn_sign(c, d, b) < 0


static func crossing_point(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> Vector2i:
	"""Where legs A-B and C-D cross (u, truncated), for legs `legs_cross` says do."""
	var r := b - a
	var s := d - c
	var den := r.x * s.y - r.y * s.x
	var num := (c.x - a.x) * s.y - (c.y - a.y) * s.x
	@warning_ignore("integer_division") return Vector2i(a.x + r.x * num / den, a.y + r.y * num / den)


static func pillar_gap_u(bore_a: int, bore_b: int) -> int:
	"""The least centreline gap (u) between two unjoined bores of these classes: both half-widths and the
	pillar of earth between them."""
	@warning_ignore("integer_division") return BORE_WIDTHS_U[bore_a] / 2 + BORE_WIDTHS_U[bore_b] / 2 + PILLAR_U


static func level_floor_depth_u(level: int) -> int:
	"""How far below the ground a level's floor lies (u): the surface 0, level 1 the bores' depth, level 2
	the candidate spacing lower (see LEVELS)."""
	return [0, BORE_FLOOR_DEPTH_U, LEVEL_2_FLOOR_DEPTH_U][clampi(level, LEVEL_SURFACE, LEVEL_2)]


static func level_floor_m(level: int) -> float:
	"""A level's floor height (m, negative below the ground; presentation)."""
	return -to_m(level_floor_depth_u(level))


static func is_buildable_level(level: int) -> bool:
	"""Whether pieces and rooms may be dug on `level` (level 1 and level 2; see LEVELS)."""
	return level >= TOP_LEVEL and level <= DEEPEST_LEVEL


static func vertical_gap_u(top_a: int, floor_a: int, top_b: int, floor_b: int) -> int:
	"""How much earth stands between two voids one over the other (u; negative where their heights overlap):
	each given by the depth below the ground of its top and its floor (top < floor)."""
	return maxi(top_b - floor_a, top_a - floor_b)


static func ramp_depth_u(from_mouth_u: int) -> int:
	"""How far below the ground a mouth's ramp floor lies this far from its mouth (u, exact to a unit): the
	integer twin of `ramp_depth_m` -- eased in, straight at the steepest grade, eased out at RAMP_RUN_U."""
	var x := clampi(from_mouth_u, 0, RAMP_RUN_U)
	var f := RAMP_FILLET_U
	if x <= f:
		@warning_ignore("integer_division") return RAMP_GRADE_RISE * x * x / (RAMP_GRADE_RUN * 2 * f)
	if x >= RAMP_RUN_U - f:
		var left := RAMP_RUN_U - x
		@warning_ignore("integer_division") return BORE_FLOOR_DEPTH_U - RAMP_GRADE_RISE * left * left / (RAMP_GRADE_RUN * 2 * f)
	@warning_ignore("integer_division") return RAMP_GRADE_RISE * (2 * x - f) / (RAMP_GRADE_RUN * 2)


# --- links between levels (decision 0212) --------------------------------------------------------
##
## LINKS. The only way from one level to the next (design §3 rule 7): a straight LINK segment from its HEAD on
## level 1's network (a junction, a ramp's foot, a room's free socket, or a point on a bore's side) down
## LEVEL_SPACING_U to its FOOT on level 2 (a junction, a room's free socket, a bore's side, or a new blind end
## to dig on from). Two kinds, DEMO VALUES:
##   * RAMP: at no steeper than RAMP_GRADE_RISE:RAMP_GRADE_RUN (1:2.5, the mouths' grade), its ends eased over
##     RAMP_FILLET_U as a mouth's ramp is: at least `link_min_run_u` (10.875 m) of run, walked at walk speed
##     along its slope.
##   * STAIRS: STAIR_RISERS timber risers of STAIR_RISE_U (0.25 m) on treads of STAIR_MIN_TREAD_U (0.3125 m,
##     a 4:5 grade, 38.7 degrees) up to STAIR_MAX_TREAD_U: 5 to 8 m of run -- steeper, so less to dig, but
##     walked at STAIR_SPEED_PERMILLE of walk speed along the slope, and each quantum takes STAIR_WORK_PERMILLE
##     of a bore's work (the risers are set as it is dug).
## A link runs at most its kind's `link_max_run_u`. Its void is one standard bore along the slope: its quanta
## are the started metres of its SLOPE length (`link_slope_u`), and so is a planner's cost. A stair's walking
## line runs through the middle of every tread (the drawn risers sit half a riser either side of it).
const LINK_NONE: int = 0
const LINK_RAMP: int = 1
const LINK_STAIRS: int = 2
const LINK_NAMES: Array[String] = ["", "ramp", "stairs"]
const LINK_MAX_RAMP_RUN_U: int = 16384
const STAIR_RISERS: int = 16
@warning_ignore("integer_division") const STAIR_RISE_U: int = LEVEL_SPACING_U / STAIR_RISERS
const STAIR_MIN_TREAD_U: int = 320
const STAIR_MAX_TREAD_U: int = 512
const STAIR_SPEED_PERMILLE: int = 500
const STAIR_WORK_PERMILLE: int = 1250


static func link_min_run_u(kind: int) -> int:
	"""The shortest run (u) a link of `kind` may have: a ramp's at its steepest grade and easing, stairs' on
	their shortest treads (see LINKS)."""
	if kind == LINK_STAIRS:
		return STAIR_RISERS * STAIR_MIN_TREAD_U
	@warning_ignore("integer_division") return LEVEL_SPACING_U * RAMP_GRADE_RUN / RAMP_GRADE_RISE + RAMP_FILLET_U


static func link_max_run_u(kind: int) -> int:
	"""The longest run (u) a link of `kind` may have (see LINKS)."""
	return STAIR_RISERS * STAIR_MAX_TREAD_U if kind == LINK_STAIRS else LINK_MAX_RAMP_RUN_U


static func link_refusal(kind: int, run_u: int) -> int:
	"""REFUSE_NONE, or why a link of `kind` may not run `run_u` (too short for its grade, or too long)."""
	if run_u < link_min_run_u(kind):
		return REFUSE_STAIRS_SHORT if kind == LINK_STAIRS else REFUSE_RAMP_SHORT
	if run_u > link_max_run_u(kind):
		return REFUSE_LINK_LONG
	return REFUSE_NONE


static func link_slope_u(run_u: int) -> int:
	"""A link's length along its slope (u, rounded up): its run and LEVEL_SPACING_U down."""
	return isqrt_ceil(run_u * run_u + LEVEL_SPACING_U * LEVEL_SPACING_U)


static func link_quanta(run_u: int) -> int:
	"""The quanta a link cuts: every started metre of its slope (ECON-001: no partial quantum)."""
	return ceil_div(link_slope_u(run_u), QUANTUM_U) * CROSS_SECTION_QUANTA


static func link_drop_u(kind: int, along_u: int, run_u: int) -> int:
	"""How far below its head a link's walking floor lies `along_u` into its run (u, exact to a unit): a ramp
	eased in and out over RAMP_FILLET_U at the one grade that takes it LEVEL_SPACING_U down in `run_u`; stairs
	straight down their pitch line (see LINKS)."""
	var x := clampi(along_u, 0, run_u)
	var d := LEVEL_SPACING_U
	if kind == LINK_STAIRS:
		@warning_ignore("integer_division") return d * x / maxi(run_u, 1)
	var f := RAMP_FILLET_U
	var span := maxi(run_u - f, 1)
	if x <= f:
		@warning_ignore("integer_division") return d * x * x / (2 * f * span)
	if x >= run_u - f:
		var left := run_u - x
		@warning_ignore("integer_division") return d - d * left * left / (2 * f * span)
	@warning_ignore("integer_division") return d * (2 * x - f) / (2 * span)


static func link_drop_m(kind: int, along_m: float, run_m: float) -> float:
	"""`link_drop_u` in metres for drawing and walking (presentation; the same curve in floats)."""
	var x := clampf(along_m, 0.0, run_m)
	var d := to_m(LEVEL_SPACING_U)
	if kind == LINK_STAIRS:
		return d * x / maxf(run_m, 1e-6)
	var f := to_m(RAMP_FILLET_U)
	var span := maxf(run_m - f, 1e-6)
	if x <= f:
		return d * x * x / (2.0 * f * span)
	if x >= run_m - f:
		return d - d * (run_m - x) * (run_m - x) / (2.0 * f * span)
	return d * (2.0 * x - f) / (2.0 * span)


static func link_slope(kind: int, along_m: float, run_m: float) -> float:
	"""How steeply a link's floor falls this far into its run (m down per m along; 0 past either end)."""
	if along_m <= 0.0 or along_m >= run_m:
		return 0.0
	var d := to_m(LEVEL_SPACING_U)
	if kind == LINK_STAIRS:
		return d / maxf(run_m, 1e-6)
	var f := to_m(RAMP_FILLET_U)
	var span := maxf(run_m - f, 1e-6)
	if along_m <= f:
		return d * along_m / (f * span)
	if along_m >= run_m - f:
		return d * (run_m - along_m) / (f * span)
	return d / span


static func link_grade_permille(kind: int, run_u: int) -> int:
	"""A link's steepest grade, per mille (rise over run): a ramp's straight middle, stairs' pitch."""
	if kind == LINK_STAIRS:
		@warning_ignore("integer_division") return LEVEL_SPACING_U * PERMILLE / maxi(run_u, 1)
	@warning_ignore("integer_division") return LEVEL_SPACING_U * PERMILLE / maxi(run_u - RAMP_FILLET_U, 1)


static func link_speed_permille(kind: int) -> int:
	"""How fast a link is walked along its slope, per mille of walk speed (see LINKS)."""
	return STAIR_SPEED_PERMILLE if kind == LINK_STAIRS else PERMILLE


static func link_work_permille(kind: int) -> int:
	"""How much work a link's quantum takes, per mille of a bore's (see LINKS)."""
	return STAIR_WORK_PERMILLE if kind == LINK_STAIRS else PERMILLE
