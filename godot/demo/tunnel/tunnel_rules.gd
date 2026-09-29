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
##   * Route limits (points, length, the hole's clearance) and who digs (moles).

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
const CROSS_SECTION_QUANTA: int = (BORE_WIDTH_U / QUANTUM_U) * (BORE_HEIGHT_U / QUANTUM_U)
const SHAFT_QUANTA: int = 1
const STOOP_PERMILLE: int = 850
## A mouth must not cut into an obstacle: its centre stays half a bore clear of every circle.
const MOUTH_CLEAR_U: int = BORE_WIDTH_U / 2
const MIN_LENGTH_U: int = 2 * QUANTUM_U
const MAX_LENGTH_U: int = 64 * QUANTUM_U
## Entrance, up to six bends, exit.
const MAX_POINTS: int = 8
const MAX_TUNNELS: int = 8
const DIGGER_SPECIES: String = "mole"
## Presentation only: how deep the bore's floor runs, and how long each end's ramp is.
const BORE_FLOOR_DEPTH_M: float = 1.25
const SHAFT_RAMP_M: float = 1.5

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
	"only a mole can dig tunnels -- select the mole",
	"the mole is already digging a tunnel",
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
	return (a + b - 1) / b


static func route_length_u(points_u: PackedInt32Array, count: int) -> int:
	"""The route's length in u: the sum of each leg's floored integer length. Points are (x, z) pairs."""
	var total := 0
	for k in range(1, count):
		var dx := points_u[2 * k] - points_u[2 * k - 2]
		var dz := points_u[2 * k + 1] - points_u[2 * k - 1]
		total += isqrt(dx * dx + dz * dz)
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
	return mini(total_ticks(quanta), dig_usec * TICKS_PER_SECOND / USEC_PER_SECOND)


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
	return done * 100 / total_ticks(quanta)


static func cut_quanta(done: int) -> int:
	"""Quanta whose CUT has completed after `done` ticks: every whole quantum, plus the current one
	once its brace and cut phases are through."""
	var partial := 1 if done % TICKS_PER_QUANTUM >= BRACE_TICKS + CUT_TICKS else 0
	return done / TICKS_PER_QUANTUM + partial


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
	return into_bore * length_u / (quanta * TICKS_PER_QUANTUM)


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


static func is_digger(species: String) -> bool:
	"""Whether residents of this species dig tunnels (demo: moles)."""
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
	for i in circles_u.size() / 3:
		var dx := x_u - circles_u[3 * i]
		var dz := z_u - circles_u[3 * i + 2]
		var reach := circles_u[3 * i + 1] + MOUTH_CLEAR_U
		if dx * dx + dz * dz < reach * reach:
			return true
	return false


static func in_bounds(x_u: int, z_u: int, bounds_u: Rect2i) -> bool:
	"""Whether a whole bore (half its width either side) at this point stays inside the bounds."""
	var half := BORE_WIDTH_U / 2
	return x_u - half >= bounds_u.position.x and x_u + half <= bounds_u.end.x \
			and z_u - half >= bounds_u.position.y and z_u + half <= bounds_u.end.y


static func validate_point(x_u: int, z_u: int, index: int, bounds_u: Rect2i, circles_u: PackedInt32Array) -> int:
	"""REFUSE_NONE, or why a route cannot take this as its point `index` (checked as it is laid):
	past the point limit, outside the bounds, or -- for the entrance -- inside an obstacle."""
	if index >= MAX_POINTS:
		return REFUSE_TOO_MANY_POINTS
	if not in_bounds(x_u, z_u, bounds_u):
		return REFUSE_OUT_OF_BOUNDS
	if index == 0 and mouth_blocked(x_u, z_u, circles_u):
		return REFUSE_ENTRANCE_BLOCKED
	return REFUSE_NONE


static func validate_route(points_u: PackedInt32Array, count: int, bounds_u: Rect2i, circles_u: PackedInt32Array) -> int:
	"""REFUSE_NONE, or the first reason the whole route is refused: its point count, a point outside
	the bounds, a mouth inside an obstacle, or its length. Bends may pass under anything."""
	if count < 2:
		return REFUSE_TOO_FEW_POINTS
	if count > MAX_POINTS:
		return REFUSE_TOO_MANY_POINTS
	for k in count:
		if not in_bounds(points_u[2 * k], points_u[2 * k + 1], bounds_u):
			return REFUSE_OUT_OF_BOUNDS
	if mouth_blocked(points_u[0], points_u[1], circles_u):
		return REFUSE_ENTRANCE_BLOCKED
	if mouth_blocked(points_u[2 * count - 2], points_u[2 * count - 1], circles_u):
		return REFUSE_EXIT_BLOCKED
	var length := route_length_u(points_u, count)
	if length < MIN_LENGTH_U:
		return REFUSE_TOO_SHORT
	if length > MAX_LENGTH_U:
		return REFUSE_TOO_LONG
	return REFUSE_NONE


static func floor_y_m(along_m: float, length_m: float) -> float:
	"""Presentation: the bore floor's height (negative, below ground) this far along a tunnel, ramping
	down from each mouth over SHAFT_RAMP_M."""
	var from_mouth := minf(along_m, length_m - along_m)
	return -BORE_FLOOR_DEPTH_M * clampf(from_mouth / SHAFT_RAMP_M, 0.0, 1.0)
