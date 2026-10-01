extends RefCounted
## The demo farm's job board: what work is wanted on which bed, who has it, and how far it has got.
## Decision 0196. Packed columns sized once; a job is a row. farm_crew.gd carries jobs out with the
## demo cast; this module only holds them and says which verbs a bed can take.
##
## THE VERBS and their work. §5.6 states four of them -- "4 WU sowing, 1 WU tending/day while growing,
## and 6 WU harvest", compost "for 8 WU" -- and REQ-SET-085 a 10-WU clearing job; those WU are used
## as written. Covering, raising and banking a bed, fetching water, digging earth off a heap and
## putting a load down have no stated work and take the DEMO WU below. DRAINING a wet
## bed is digging a ditch round it (farm_sim.gd `drain_bed()`), demo spade-work like raising one. A WU is "one game
## minute of base-speed productive labor" (GDD §4.1); the demo shows it as DEMO_USEC_PER_WU of the
## cast's own time (not the farm calendar's), so the work reads on screen.
##
## A job is a PLAN of steps: walk somewhere (a bed, the well, an earth source: farm_tunnels.gd SOURCES) or carry
## something there (the carry walk), then work there for the step's WU. Each kind's plan is in PLANS. Compost comes
## only from the farm's compost store, which only plant waste fills (decision 0401: earth is never compost).
##
## A DELIVERY (KIND_DELIVER, decision 0222) is what a harvest becomes when its production is cancelled
## with the crop already cut: the carrier finishes the carry walk and the drop, and the store is credited
## there, never at the cancel (the review's F24). It is not an order the player gives (KIND_COUNT counts
## the orderable kinds) and it no longer stands on its bed's harvest (a new one can be ordered there).
## Each job keeps a SERIAL for its whole life -- through rewinds, reassignment and becoming a delivery --
## so a resident's resume (resident_brain.gd RESUMING) comes back to the very job it left; its HOLD is the
## pantry reservation its harvest keeps (farm_pantry.gd RESERVATIONS), and BLOCKED says why it waits.
##
## AN EARTH RETURN (KIND_RETURN_EARTH, decision 0401) is what a Raise or a Bank becomes when it ends with earth in
## hand -- cancelled, or unable to reach or work its bed: the carrier walks the earth back to the heap (or the stores)
## it came from and tips it there, as a cancelled sawing carries its logs back (0222). Like a delivery it is not an
## order, and it no longer stands on its bed's Raise or Bank.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const KIND_SOW: int = 0
const KIND_WATER: int = 1
const KIND_HARVEST: int = 2
const KIND_CLEAR: int = 3
const KIND_COMPOST: int = 4
const KIND_COVER: int = 5
const KIND_RAISE: int = 6
const KIND_BANK: int = 7
const KIND_DRAIN: int = 8
## The kinds the player (or the farm's routine) orders; KIND_DELIVER comes after them.
const KIND_COUNT: int = 9
const KIND_DELIVER: int = 9
const KIND_RETURN_EARTH: int = 10
const KIND_NAMES: Array[String] = ["Sow", "Water", "Harvest", "Clear", "Compost", "Cover", "Raise", "Bank",
	"Drain", "Carry harvest", "Carry earth back"]
const KIND_DOING: Array[String] = ["Sowing", "Watering", "Harvesting", "Clearing", "Composting",
	"Covering", "Raising", "Banking", "Draining", "Carrying the harvest from", "Carrying earth back from"]

## Steps: walks (< STEP_WORK) and works (STEP_WORK + a WORK_* kind).
const STEP_GO_BED: int = 0
const STEP_GO_WELL: int = 1
const STEP_GO_HEAP: int = 2
const STEP_CARRY_BED: int = 3
const STEP_CARRY_STORE: int = 4
const STEP_CARRY_HEAP: int = 5
const STEP_WORK: int = 10
const WORK_SOW: int = 0
const WORK_TEND: int = 1
const WORK_HARVEST: int = 2
const WORK_CLEAR: int = 3
const WORK_COMPOST: int = 4
const WORK_COVER: int = 5
const WORK_RAISE: int = 6
const WORK_BANK: int = 7
const WORK_FETCH: int = 8
const WORK_DIG: int = 9
const WORK_DROP: int = 10
const WORK_DRAIN: int = 11
## WU per work kind: §5.6 / REQ-SET-085 for sow 4, tend 1, harvest 6, clear 10, compost 8; the rest
## are demo values -- a ditch (drain) is 6, the same spade-work as raising or banking a bed.
const WORK_WU: Array[int] = [4, 1, 6, 10, 8, 2, 6, 6, 1, 2, 1, 6]
const DEMO_USEC_PER_WU: int = 1500000

const PLANS: Array[Array] = [
	[STEP_GO_BED, STEP_WORK + WORK_SOW],
	[STEP_GO_WELL, STEP_WORK + WORK_FETCH, STEP_CARRY_BED, STEP_WORK + WORK_TEND],
	[STEP_GO_BED, STEP_WORK + WORK_HARVEST, STEP_CARRY_STORE, STEP_WORK + WORK_DROP],
	[STEP_GO_BED, STEP_WORK + WORK_CLEAR],
	[STEP_GO_BED, STEP_WORK + WORK_COMPOST],
	[STEP_GO_BED, STEP_WORK + WORK_COVER],
	[STEP_GO_HEAP, STEP_WORK + WORK_DIG, STEP_CARRY_BED, STEP_WORK + WORK_RAISE],
	[STEP_GO_HEAP, STEP_WORK + WORK_DIG, STEP_CARRY_BED, STEP_WORK + WORK_BANK],
	[STEP_GO_BED, STEP_WORK + WORK_DRAIN],
	[STEP_CARRY_STORE, STEP_WORK + WORK_DROP],
	[STEP_CARRY_HEAP, STEP_WORK + WORK_DROP],
]
## Earth a raise or a bank takes from a heap or the stores (demo value, 2 U; it was §5.6's compost dose while spoil
## could be dug in as compost -- decision 0401 retired that, the amount stays).
const EARTH_PER_JOB_MILLI: int = 2000

const ORIGIN_PLAYER: int = 0
const ORIGIN_ROUTINE: int = 1
const FREE: int = -1
const NOBODY: int = -1
const MAX_JOBS: int = 24
const MAX_TRIES: int = 3
## Why a job waits (BLOCKED): not at all; for store room (lifted as soon as there is room); or for a way
## to its target (lifted at the farm's next hour).
const BLOCK_NONE: int = 0
const BLOCK_ROOM: int = 1
const BLOCK_WAY: int = 2

const REFUSE_BOARD_FULL: String = "JOB_BOARD_FULL"
const REFUSE_DUPLICATE: String = "JOB_ALREADY_QUEUED"
const REFUSE_BAD_KIND: String = "NOT_A_JOB_KIND"
const REFUSE_NO_EARTH: String = "NO_EARTH"
const REFUSE_NOT_GROWING: String = "NOTHING_GROWING"
const REFUSE_NOT_RIPE: String = "NOT_RIPE"
const REFUSE_NO_JOB: String = "NO_SUCH_JOB"

var kind: PackedInt32Array = PackedInt32Array()
var bed: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var step: PackedInt32Array = PackedInt32Array()
var elapsed_usec: PackedInt64Array = PackedInt64Array()
var origin: PackedInt32Array = PackedInt32Array()
## The earth source (farm_tunnels.gd SOURCES) a raise or a bank took its earth from, and an earth return goes back to.
var heap: PackedInt32Array = PackedInt32Array()
var load_item: PackedInt32Array = PackedInt32Array()
var load_milli: PackedInt64Array = PackedInt64Array()
var location: PackedInt32Array = PackedInt32Array()
var issued: PackedByteArray = PackedByteArray()
## Whether the current work step's opening effect (sowing's seed commitment) has been applied.
var begun: PackedByteArray = PackedByteArray()
## Walks a worker gave up on (blocked) for the current step; the step is tried again up to
## MAX_TRIES times before the job ends.
var tries: PackedByteArray = PackedByteArray()
var goal: PackedVector2Array = PackedVector2Array()
## The job's identity for its whole life (see the header); never reused.
var serial: PackedInt64Array = PackedInt64Array()
## The pantry reservation its harvest keeps (FREE: none).
var hold: PackedInt32Array = PackedInt32Array()
## BLOCK_* (see the header).
var blocked: PackedByteArray = PackedByteArray()
var _next_serial: int = 0


func _init() -> void:
	"""Size every column once; every row free."""
	for column: PackedInt32Array in [kind, bed, worker, step, origin, heap, load_item, location, hold]:
		column.resize(MAX_JOBS)
	for column: PackedInt64Array in [elapsed_usec, load_milli, serial]:
		column.resize(MAX_JOBS)
	issued.resize(MAX_JOBS)
	blocked.resize(MAX_JOBS)
	begun.resize(MAX_JOBS)
	tries.resize(MAX_JOBS)
	goal.resize(MAX_JOBS)
	kind.fill(FREE)
	worker.fill(NOBODY)
	hold.fill(FREE)


func open_into(job_kind: int, job_bed: int, job_origin: int, out: IntMath.IntResult) -> bool:
	"""Queue a job; writes its row into `out`. Refuses a bad kind or bed, a second job of the same
	kind already on that bed, or a full board."""
	if job_kind < 0 or job_kind >= KIND_COUNT or not Catalog.is_bed(job_bed):
		return out.refuse(REFUSE_BAD_KIND)
	for row: int in MAX_JOBS:
		if kind[row] == job_kind and bed[row] == job_bed:
			return out.refuse(REFUSE_DUPLICATE)
	var row: int = kind.find(FREE)
	if row < 0:
		return out.refuse(REFUSE_BOARD_FULL)
	kind[row] = job_kind
	bed[row] = job_bed
	worker[row] = NOBODY
	origin[row] = job_origin
	heap[row] = FREE
	load_item[row] = Catalog.NO_ITEM
	load_milli[row] = 0
	location[row] = 0
	hold[row] = FREE
	blocked[row] = BLOCK_NONE
	_next_serial += 1
	serial[row] = _next_serial
	_start_step(row, 0)
	return out.succeed(row)


func _plan(row: int) -> Array:
	"""The step list job `row` runs through (a constant table; nothing is copied)."""
	return PLANS[kind[row]]


static func plan_work_usec(job_kind: int, from_step: int) -> int:
	"""The work left in a job's plan from step `from_step` on, in the cast's demo microseconds -- every work step's
	`work_usec_of`, the walks not counted (the action card's work, decision 0332)."""
	var plan: Array = PLANS[job_kind]
	var usec: int = 0
	for k: int in range(maxi(from_step, 0), plan.size()):
		if int(plan[k]) >= STEP_WORK:
			usec += work_usec_of(int(plan[k]) - STEP_WORK)
	return usec


func plan_size(row: int) -> int:
	"""How many steps job `row` has."""
	return _plan(row).size()


func current_step(row: int) -> int:
	"""The step code job `row` is on."""
	return int(_plan(row)[step[row]])


func advance(row: int) -> bool:
	"""Move job `row` to its next step; false when that was its last (the job is done). Leaving a work
	step clears its progress; walking into one keeps whatever an earlier worker did there."""
	if step[row] + 1 >= plan_size(row):
		return false
	if current_step(row) >= STEP_WORK:
		elapsed_usec[row] = 0
		begun[row] = 0
	step[row] += 1
	issued[row] = 0
	tries[row] = 0
	return true


func _start_step(row: int, index: int) -> void:
	"""Begin a fresh job at step `index`: nothing issued, no work done."""
	step[row] = index
	elapsed_usec[row] = 0
	issued[row] = 0
	begun[row] = 0
	tries[row] = 0


func rewind_to_walk(row: int) -> void:
	"""A worker left job `row` during a work step: go back to the walk that leads there, KEEPING the
	work already done and its opening effect (REQ-SET-071: completed work is retained when the worker
	changes), so the next worker walks there and carries on."""
	if current_step(row) >= STEP_WORK and step[row] > 0:
		step[row] -= 1
	issued[row] = 0


func become_delivery(row: int) -> void:
	"""A cut harvest's production is cancelled: job `row` is now only its delivery, at the same point of
	the carry walk or the drop (a walk under way carries on; work done on the drop is kept)."""
	var code: int = current_step(row)
	kind[row] = KIND_DELIVER
	step[row] = 1 if code == STEP_WORK + WORK_DROP else 0


func become_earth_return(row: int) -> void:
	"""A raise or a bank ends with its earth in hand (see AN EARTH RETURN): job `row` is now only that earth's walk
	back to its source and the tip there, from the start of the walk (nothing issued, no work done)."""
	kind[row] = KIND_RETURN_EARTH
	_start_step(row, 0)


func back_to_carry(row: int) -> void:
	"""A drop that could not store everything: walk the rest on to the store now reserved (the carry step,
	nothing issued, the drop to do afresh)."""
	if step[row] > 0 and current_step(row) >= STEP_WORK:
		step[row] -= 1
	elapsed_usec[row] = 0
	begun[row] = 0
	issued[row] = 0
	tries[row] = 0


func assign(row: int, who: int) -> void:
	"""Give job `row` to resident `who` from its current step: its walk tried afresh (and a wait for a
	way there lifted)."""
	worker[row] = who
	issued[row] = 0
	tries[row] = 0
	blocked[row] = BLOCK_NONE


func unassign(row: int) -> void:
	"""Take job `row` back from its resident (it waits on the board, where it had got to)."""
	worker[row] = NOBODY
	issued[row] = 0


func close(row: int) -> void:
	"""Free job `row`."""
	kind[row] = FREE
	worker[row] = NOBODY
	bed[row] = FREE


func job_of_worker_into(who: int, out: IntMath.IntResult) -> bool:
	"""The job resident `who` is doing, into `out`; refuses NO_SUCH_JOB."""
	for row: int in MAX_JOBS:
		if kind[row] != FREE and worker[row] == who:
			return out.succeed(row)
	return out.refuse(REFUSE_NO_JOB)


func job_on_bed_into(job_kind: int, job_bed: int, out: IntMath.IntResult) -> bool:
	"""The job of this kind on this bed, into `out`; refuses NO_SUCH_JOB."""
	for row: int in MAX_JOBS:
		if kind[row] == job_kind and bed[row] == job_bed:
			return out.succeed(row)
	return out.refuse(REFUSE_NO_JOB)


func is_live(row: int) -> bool:
	"""Whether row `row` holds a job."""
	return kind[row] != FREE


func work_usec(work_kind: int) -> int:
	"""How long a work kind takes, in the cast's demo microseconds."""
	return work_usec_of(work_kind)


static func work_usec_of(work_kind: int) -> int:
	"""How long a work kind takes, in the cast's demo microseconds: its WU at DEMO_USEC_PER_WU."""
	return WORK_WU[work_kind] * DEMO_USEC_PER_WU


func live_count() -> int:
	"""How many jobs are on the board."""
	return MAX_JOBS - kind.count(FREE)


# --- which verbs a bed can take ---------------------------------------------------------------

static func refusal_for(sim: SimScript, job_kind: int, job_bed: int, earth_milli: int) -> StringName:
	"""Why `job_kind` cannot be ordered on `job_bed` now (empty when it can). `earth_milli` is the
	most earth any one source holds (farm_tunnels.gd `most_earth`): Raise and Bank need it, nothing else does."""
	if not Catalog.is_bed(job_bed) or job_kind < 0 or job_kind >= KIND_COUNT:
		return StringName(REFUSE_BAD_KIND)
	var stage: int = sim.stage_of(job_bed)
	match job_kind:
		KIND_SOW:
			if sim.chosen_of(job_bed) == Catalog.NO_ITEM:
				return SimScript.REFUSE_NO_ITEM
			return sim.sow_refusal(job_bed, sim.chosen_of(job_bed))
		KIND_WATER:
			return &"" if _is_growing_stage(stage) else StringName(REFUSE_NOT_GROWING)
		KIND_HARVEST:
			return &"" if stage == SimScript.STAGE_RIPE else StringName(REFUSE_NOT_RIPE)
		KIND_CLEAR:
			return sim.clear_refusal(job_bed)
		KIND_COMPOST:
			return sim.compost_refusal(job_bed)
		KIND_COVER:
			if sim.is_covered(job_bed):
				return SimScript.REFUSE_ALREADY
			return &"" if stage != SimScript.STAGE_EMPTY else SimScript.REFUSE_NO_CROP
		KIND_DRAIN:
			return sim.drain_refusal(job_bed)
	if (job_kind == KIND_RAISE and sim.is_raised(job_bed)) or (job_kind == KIND_BANK and sim.is_banked(job_bed)):
		return SimScript.REFUSE_ALREADY
	return &"" if earth_milli >= EARTH_PER_JOB_MILLI else StringName(REFUSE_NO_EARTH)


static func _is_growing_stage(stage: int) -> bool:
	"""Whether a stage is a growing crop (what tending acts on)."""
	return stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING \
		or stage == SimScript.STAGE_BLIGHTED
