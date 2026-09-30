extends RefCounted
## Work on finished tunnels: upgrades and repairs. Decision 0196 (live demo). Presentation
## only: the jobs change the demo's tunnels (underground_graph.gd) and its own stores, never the
## simulation.
##
## ONE JOB PER SEGMENT (underground_graph.gd, decision 0208: a segment is what a tunnel slot was), held in
## that segment's slot of fixed columns (sized once). A job has a kind,
## the tunnel's generation (a job on a freed and reused slot is void), the resident working it, its
## TOTAL in F1000 ticks and the F1000-equivalent microseconds credited so far at the crew's rate
## (with the remainder kept, as the dig keeps it), and the stretch of tunnel it works along.
##
##   kind     who                 work (ticks)                         cost                  then
##   WIDEN    the mole (+ crew)   5 more quanta per metre, each in its  --                    bore WIDE
##                                 ground's dig ticks (tunnel_ground)
##   BRACE    anyone who fits     25 a quantum (ECON-002 brace work)    wood 250 + stone 250  BRACED
##                                                                      milli-U a quantum
##                                                                      (ECON-002, cited)
##   LANTERNS anyone who fits     LANTERN_TICKS a lantern, one per      LANTERN_WOOD_MILLI_U  LIT
##                                 LANTERN_SPACING_M (demo)             a lantern (demo)
##   PUMP     anyone              PUMP_TICKS a quantum (demo)           --                    reopened
##   CLEAR    the mole (+ crew)   the collapsed quanta's dig ticks      --                    reopened
## (Burrow homes and root cellars are no longer a job on a tunnel: each is a room dug as its own piece of the
## network, decision 0209 -- underground_graph.gd ROOMS.)
##
## MATERIALS are paid once, when the work STARTS (ECON-003: "consume material inputs once at WORK
## start"), from the demo stores; a job whose worker is called away keeps its progress and its paid
## inputs (ECON-005: pause retains progress), and resumes when ordered again.
##
## SPOIL from re-digging (WIDEN, CLEAR) posts as each quantum's cut completes and heaps at
## the segment's spoil mouth (underground_graph.add_spoil); rock quanta also yield stone to the demo stores.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

const JOB_NONE: int = 0
const JOB_WIDEN: int = 1
const JOB_BRACE: int = 2
const JOB_LANTERNS: int = 3
const JOB_PUMP: int = 4
const JOB_CLEAR: int = 5
const NAMES: Array[String] = ["", "Widen", "Brace", "Hang lanterns", "Pump out", "Clear the fall"]
const ACTIVITY: Array[String] = ["", "widening the tunnel", "bracing the tunnel", "hanging lanterns",
	"pumping out the tunnel", "clearing the fall"]

const BRACE_WOOD_MILLI_U: int = 250
const BRACE_STONE_MILLI_U: int = 250
const LANTERN_SPACING_M: int = 4
const LANTERN_TICKS: int = 60
const LANTERN_WOOD_MILLI_U: int = 500
const PUMP_TICKS: int = 30
## Faces a crew can work side by side: widening re-digs five quanta a metre.
const WIDEN_FACES: int = Rules.WIDE_EXTRA_QUANTA

## Per tunnel slot (see ONE JOB PER TUNNEL).
var kind: PackedByteArray = PackedByteArray()
var tunnel_gen: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var total: PackedInt32Array = PackedInt32Array()
var work_usec: PackedInt64Array = PackedInt64Array()
var work_rem: PackedInt64Array = PackedInt64Array()
var rate_permille: PackedInt32Array = PackedInt32Array()
var paid: PackedByteArray = PackedByteArray()
var from_u: PackedInt32Array = PackedInt32Array()
var to_u: PackedInt32Array = PackedInt32Array()
## Cuts, spoil and stone already posted by the job (so each posts once).
var posted_cuts: PackedInt32Array = PackedInt32Array()
var posted_spoil: PackedInt64Array = PackedInt64Array()
var posted_stone: PackedInt64Array = PackedInt64Array()
## Bumped when a job is posted, starts, pauses or ends.
var revision: int = 0

var _network: GraphScript = null
var _stores: StoresScript = null
var _progress: PackedInt64Array = PackedInt64Array()
var _cost: PackedInt32Array = PackedInt32Array()


func _init(network: GraphScript, stores: StoresScript) -> void:
	"""Jobs on this network's tunnels, paid from these stores. Columns sized once."""
	_network = network
	_stores = stores
	kind.resize(Rules.MAX_SEGMENTS)
	paid.resize(Rules.MAX_SEGMENTS)
	_size_ints()
	work_usec.resize(Rules.MAX_SEGMENTS)
	work_rem.resize(Rules.MAX_SEGMENTS)
	posted_spoil.resize(Rules.MAX_SEGMENTS)
	posted_stone.resize(Rules.MAX_SEGMENTS)
	_progress.resize(GraphScript.P_SIZE)
	_cost.resize(2)


func _size_ints() -> void:
	"""Size the per-slot integer columns."""
	tunnel_gen.resize(Rules.MAX_SEGMENTS)
	worker.resize(Rules.MAX_SEGMENTS)
	worker.fill(-1)
	total.resize(Rules.MAX_SEGMENTS)
	rate_permille.resize(Rules.MAX_SEGMENTS)
	rate_permille.fill(Rules.PERMILLE)
	from_u.resize(Rules.MAX_SEGMENTS)
	to_u.resize(Rules.MAX_SEGMENTS)
	posted_cuts.resize(Rules.MAX_SEGMENTS)


func has_job(slot: int) -> bool:
	"""Whether tunnel `slot` has a job posted (under way or waiting) that is still its own."""
	return kind[slot] != JOB_NONE and _network.is_ref(slot, tunnel_gen[slot])


func lantern_count(slot: int) -> int:
	"""How many lanterns light tunnel `slot`: one per started LANTERN_SPACING_M."""
	return Rules.ceil_div(_network.length_u[slot], LANTERN_SPACING_M * Rules.UNITS_PER_M)


func cost_into(slot: int, job: int, out: PackedInt32Array) -> void:
	"""What job `job` on tunnel `slot` costs from the stores: out[0] wood, out[1] stone (milli-U)."""
	out[0] = 0
	out[1] = 0
	if job == JOB_BRACE:
		out[0] = BRACE_WOOD_MILLI_U * _network.timeline_count(slot)
		out[1] = BRACE_STONE_MILLI_U * _network.timeline_count(slot)
	elif job == JOB_LANTERNS:
		out[0] = LANTERN_WOOD_MILLI_U * lantern_count(slot)


func ticks_for(slot: int, job: int) -> int:
	"""The work job `job` on tunnel `slot` takes one F1000 worker, in ticks (see the table)."""
	match job:
		JOB_WIDEN:
			return _network.pass_ticks(slot, Rules.WIDE_EXTRA_QUANTA)
		JOB_BRACE:
			return Rules.BRACE_TICKS * _network.timeline_count(slot)
		JOB_LANTERNS:
			return LANTERN_TICKS * lantern_count(slot)
		JOB_PUMP:
			return PUMP_TICKS * _network.timeline_count(slot)
	return _clear_ticks(slot)


func _clear_ticks(slot: int) -> int:
	"""The dig ticks of every quantum in tunnel `slot`'s collapsed section."""
	var ticks := 0
	for k in _network.timeline_count(slot):
		if _in_section(slot, _network.quantum_along_u(slot, k)):
			ticks += GroundScript.dig_ticks(_network.quantum_kind(slot, k))
	return maxi(ticks, 1)


func _in_section(slot: int, along: int) -> bool:
	"""Whether `along` (u) lies in tunnel `slot`'s collapsed section."""
	return along >= _network.closed_from_u[slot] and along <= _network.closed_to_u[slot]


func post(slot: int, job: int, resident: int, span_from_u: int, span_to_u: int) -> void:
	"""Post job `job` on tunnel `slot` for `resident`, working from span_from_u to span_to_u along it.
	A job of the same kind already posted there keeps its progress and paid inputs (a resume)."""
	if has_job(slot) and kind[slot] == job:
		worker[slot] = resident
		revision += 1
		return
	kind[slot] = job
	tunnel_gen[slot] = _network.generation[slot]
	worker[slot] = resident
	work_usec[slot] = 0
	work_rem[slot] = 0
	paid[slot] = 0
	posted_cuts[slot] = 0
	posted_spoil[slot] = 0
	posted_stone[slot] = 0
	from_u[slot] = span_from_u
	to_u[slot] = span_to_u
	total[slot] = ticks_for(slot, job)
	revision += 1


func start(slot: int) -> bool:
	"""The worker is at the job: pay its inputs, once. False (nothing paid) when the stores are short."""
	if paid[slot] == 1:
		return true
	cost_into(slot, kind[slot], _cost)
	if not _stores.pay(_cost[0], _cost[1]):
		return false
	paid[slot] = 1
	revision += 1
	return true


func done_ticks(slot: int) -> int:
	"""F1000 ticks of the job done, capped at its total."""
	return mini(total[slot], work_usec[slot] * Rules.TICKS_PER_SECOND / Rules.USEC_PER_SECOND)


func percent(slot: int) -> int:
	"""Whole percent of the job done (floored)."""
	return done_ticks(slot) * 100 / maxi(total[slot], 1)


func is_done(slot: int) -> bool:
	"""Whether the job's work is all done."""
	return done_ticks(slot) >= total[slot]


func work(slot: int, usec: int) -> void:
	"""Credit `usec` microseconds of work at the job's crew rate (remainder kept)."""
	if not has_job(slot) or usec <= 0 or paid[slot] == 0:
		return
	var credited := usec * rate_permille[slot] + work_rem[slot]
	work_usec[slot] += credited / Rules.PERMILLE
	work_rem[slot] = credited % Rules.PERMILLE


func along_m(slot: int) -> float:
	"""Where along the tunnel the work is now, in metres: through its span as the work goes."""
	var span := to_u[slot] - from_u[slot]
	var along := from_u[slot] + span * done_ticks(slot) / maxi(total[slot], 1)
	return Rules.to_m(along)


func cut_progress_into(slot: int, out: PackedInt64Array) -> void:
	"""The job's re-dig progress so far (underground_graph.gd P_* slots): cuts, spoil and stone. Only WIDEN and
	CLEAR cut; the others leave `out` empty."""
	out.fill(0)
	var job := kind[slot]
	if job == JOB_WIDEN:
		_network.progress_into(slot, done_ticks(slot), Rules.WIDE_EXTRA_QUANTA, out)
	elif job == JOB_CLEAR:
		_clear_progress_into(slot, out)


func _clear_progress_into(slot: int, out: PackedInt64Array) -> void:
	"""Cuts, spoil and stone of the collapsed quanta dug out so far, in timeline order."""
	var left := done_ticks(slot)
	for k in _network.timeline_count(slot):
		if not _in_section(slot, _network.quantum_along_u(slot, k)):
			continue
		var ground := _network.quantum_kind(slot, k)
		if left < GroundScript.dig_ticks(ground):
			return
		left -= GroundScript.dig_ticks(ground)
		out[GraphScript.P_CUTS] += 1
		out[GraphScript.P_SPOIL] += GroundScript.spoil_of(ground)
		out[GraphScript.P_STONE] += GroundScript.stone_of(ground)


func post_cuts(slot: int) -> int:
	"""Post the job's new cuts: their spoil to the entrance heap and their stone to the stores. Returns
	how many cuts were new (each is posted once)."""
	cut_progress_into(slot, _progress)
	var fresh := int(_progress[GraphScript.P_CUTS]) - posted_cuts[slot]
	if fresh <= 0:
		return 0
	_network.add_spoil(slot, _progress[GraphScript.P_SPOIL] - posted_spoil[slot])
	_stores.add_stone(_progress[GraphScript.P_STONE] - posted_stone[slot])
	posted_spoil[slot] = _progress[GraphScript.P_SPOIL]
	posted_stone[slot] = _progress[GraphScript.P_STONE]
	posted_cuts[slot] += fresh
	return fresh


func finish(slot: int) -> int:
	"""The job's work is done: apply it to the tunnel and clear the job. Returns the kind finished."""
	var job := kind[slot]
	post_cuts(slot)
	match job:
		JOB_WIDEN:
			_network.set_bore(slot, Rules.BORE_WIDE)
		JOB_BRACE:
			_network.set_braced(slot)
		JOB_LANTERNS:
			_network.set_lit(slot)
		JOB_PUMP, JOB_CLEAR:
			_network.reopen(slot)
	clear(slot)
	return job


func pause(slot: int) -> void:
	"""The worker was called away: the job waits with its progress and paid inputs (see MATERIALS)."""
	if kind[slot] == JOB_NONE:
		return
	worker[slot] = -1
	revision += 1


func clear(slot: int) -> void:
	"""No job on tunnel `slot`."""
	kind[slot] = JOB_NONE
	worker[slot] = -1
	revision += 1


func label(slot: int) -> String:
	"""e.g. "Brace — 40%", or "Brace — waiting for a worker"."""
	if not has_job(slot):
		return ""
	if worker[slot] < 0:
		return "%s — paused at %d%%" % [NAMES[kind[slot]], percent(slot)]
	return "%s — %d%%" % [NAMES[kind[slot]], percent(slot)]
