extends RefCounted
## The woods' job board. Decision 0196 (live demo). Packed columns sized once; a job is a row.
## forest_crew.gd carries the jobs out with the demo cast; this module only holds them.
##
## A job is a PLAN of steps -- walk somewhere, or carry something there on the carry walk, then work
## there for the step's WU (forest_rules.gd) -- as the farm's board is (demo/farm/farm_jobs.gd).
##
##   FELL    to the tree, fell it (120 WU, §5.9); the feller then hauls it (the row becomes a HAUL)
##   HAUL    to the trunk, load CARRY_LOAD_MILLI, carry it to the log stack, stack it; again while
##           wood lies there. A haul ordered on a tree still standing waits beside it for the fall.
##   GATHER  to a deadfall pile, gather it, carry it to the log stack, stack it
##   SAW     to the log stack, take a batch of logs, carry them to the sawhorse, saw, carry the
##           planks to the plank stack, stack them
##   PLANT   to the yard, take a sapling basket, carry it to the cleared spot, plant (4 WU, §5.9)
##   GRUB    to the stump, dig it out
##
## A DELIVERY (decision 0222, the review's F24) is what a job with a load in hand becomes when its work is
## cancelled: CARRY_LOGS walks logs or deadfall wood to the log stack and stacks them, CARRY_PLANKS walks
## planks to the plank stack. The stores are credited there, on arrival -- never at the cancel. Neither is
## an order (KIND_COUNT counts the orderable kinds). A job keeps its SERIAL through everything it becomes
## (a fell turned haul, a haul turned delivery), so a resident's resume finds it; PAID says planting's
## compost is paid for this job (F25: once per job, kept through rewinds and a change of hands); BLOCKED
## says it waits for a way to its target, lifted at the woods' next hour.

const IntMath := preload("res://scripts/core/int_math.gd")

const KIND_FELL: int = 0
const KIND_HAUL: int = 1
const KIND_GATHER: int = 2
const KIND_SAW: int = 3
const KIND_PLANT: int = 4
const KIND_GRUB: int = 5
## The orderable kinds; the two deliveries come after them.
const KIND_COUNT: int = 6
const KIND_CARRY_LOGS: int = 6
const KIND_CARRY_PLANKS: int = 7
const KIND_NAMES: Array[String] = ["Fell", "Haul logs", "Gather deadfall", "Saw planks", "Plant a sapling", "Grub out a stump",
	"Carry logs to the stack", "Carry planks to the stack"]
const KIND_DOING: Array[String] = ["Felling", "Hauling logs from", "Gathering deadfall", "Sawing planks",
	"Planting a sapling at", "Grubbing out", "Carrying logs to the log stack", "Carrying planks to the plank stack"]

## Walks (< STEP_WORK) and works (STEP_WORK + WORK_*).
const STEP_GO_TREE: int = 0
const STEP_GO_PILE: int = 1
const STEP_GO_STACK: int = 2
const STEP_GO_YARD: int = 3
const STEP_CARRY_STACK: int = 4
const STEP_CARRY_SAW: int = 5
const STEP_CARRY_PLANKS: int = 6
const STEP_CARRY_SITE: int = 7
const STEP_WORK: int = 10
const WORK_FELL: int = 0
const WORK_LOAD: int = 1
const WORK_DROP: int = 2
const WORK_GATHER: int = 3
const WORK_FETCH_LOGS: int = 4
const WORK_SAW: int = 5
const WORK_STACK_PLANKS: int = 6
const WORK_FETCH_SAPLING: int = 7
const WORK_PLANT: int = 8
const WORK_GRUB: int = 9

const PLANS: Array[Array] = [
	[STEP_GO_TREE, STEP_WORK + WORK_FELL],
	[STEP_GO_TREE, STEP_WORK + WORK_LOAD, STEP_CARRY_STACK, STEP_WORK + WORK_DROP],
	[STEP_GO_PILE, STEP_WORK + WORK_GATHER, STEP_CARRY_STACK, STEP_WORK + WORK_DROP],
	[STEP_GO_STACK, STEP_WORK + WORK_FETCH_LOGS, STEP_CARRY_SAW, STEP_WORK + WORK_SAW, STEP_CARRY_PLANKS,
		STEP_WORK + WORK_STACK_PLANKS],
	[STEP_GO_YARD, STEP_WORK + WORK_FETCH_SAPLING, STEP_CARRY_SITE, STEP_WORK + WORK_PLANT],
	[STEP_GO_TREE, STEP_WORK + WORK_GRUB],
	[STEP_CARRY_STACK, STEP_WORK + WORK_DROP],
	[STEP_CARRY_PLANKS, STEP_WORK + WORK_STACK_PLANKS],
]

const ORIGIN_PLAYER: int = 0
const ORIGIN_ROUTINE: int = 1
const FREE: int = -1
const NOBODY: int = -1
const NO_TARGET: int = -1
const MAX_JOBS: int = 24
const MAX_TRIES: int = 3
## Haulers one trunk takes at once (demo): the feller and two more.
const MAX_HAULERS: int = 3

const REFUSE_BAD_KIND: String = "NOT_A_JOB_KIND"
const REFUSE_DUPLICATE: String = "JOB_ALREADY_QUEUED"
const REFUSE_FULL: String = "JOB_BOARD_FULL"
const REFUSE_NO_JOB: String = "NO_SUCH_JOB"
const REFUSE_ENOUGH_HANDS: String = "ENOUGH_HAULERS"

var kind: PackedInt32Array = PackedInt32Array()
## The tree (FELL, HAUL, PLANT, GRUB) or deadfall pile (GATHER) the job is on; NO_TARGET for SAW.
var target: PackedInt32Array = PackedInt32Array()
## The pile's generation for GATHER (a reused row is a different pile).
var target_gen: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var step: PackedInt32Array = PackedInt32Array()
var origin: PackedInt32Array = PackedInt32Array()
var elapsed_usec: PackedInt64Array = PackedInt64Array()
## The current work step's length, fixed when it starts (skill, season and weather at that moment).
var work_usec: PackedInt64Array = PackedInt64Array()
var load_milli: PackedInt64Array = PackedInt64Array()
var issued: PackedByteArray = PackedByteArray()
var tries: PackedByteArray = PackedByteArray()
var goal: PackedVector2Array = PackedVector2Array()
var revision: int = 0
## The job's identity for its whole life (see the header); never reused.
var serial: PackedInt64Array = PackedInt64Array()
## 1 once planting's compost is paid for this job (see the header).
var paid: PackedByteArray = PackedByteArray()
## 1 while it waits for a way to its target (see the header).
var blocked: PackedByteArray = PackedByteArray()
var _next_serial: int = 0


func _init() -> void:
	"""Size every column once; every row free."""
	for column: PackedInt32Array in [kind, target, target_gen, worker, step, origin]:
		column.resize(MAX_JOBS)
	for column: PackedInt64Array in [elapsed_usec, work_usec, load_milli, serial]:
		column.resize(MAX_JOBS)
	issued.resize(MAX_JOBS)
	paid.resize(MAX_JOBS)
	blocked.resize(MAX_JOBS)
	tries.resize(MAX_JOBS)
	goal.resize(MAX_JOBS)
	kind.fill(FREE)
	worker.fill(NOBODY)


func is_live(row: int) -> bool:
	"""Whether `row` holds a job."""
	return row >= 0 and row < MAX_JOBS and kind[row] != FREE


func open_into(job_kind: int, job_target: int, gen: int, job_origin: int, out: IntMath.IntResult) -> bool:
	"""Queue a job; its row into `out`. Refuses a bad kind, a second job of the same kind on the same
	target (hauls excepted, up to MAX_HAULERS), or a full board."""
	if job_kind < 0 or job_kind >= KIND_COUNT:
		return out.refuse(REFUSE_BAD_KIND)
	if job_kind != KIND_SAW and job_kind != KIND_HAUL and find_into(job_kind, job_target, out):
		return out.refuse(REFUSE_DUPLICATE)
	if job_kind == KIND_HAUL and on_target(KIND_HAUL, job_target) + on_target(KIND_FELL, job_target) >= MAX_HAULERS:
		return out.refuse(REFUSE_ENOUGH_HANDS)
	var row: int = kind.find(FREE)
	if row < 0:
		return out.refuse(REFUSE_FULL)
	kind[row] = job_kind
	target[row] = job_target
	target_gen[row] = gen
	origin[row] = job_origin
	worker[row] = NOBODY
	_next_serial += 1
	serial[row] = _next_serial
	_reset(row)
	revision += 1
	return out.succeed(row)


func _reset(row: int) -> void:
	"""Start a row's plan from its first step, carrying nothing."""
	step[row] = 0
	elapsed_usec[row] = 0
	work_usec[row] = 0
	load_milli[row] = 0
	issued[row] = 0
	tries[row] = 0
	paid[row] = 0
	blocked[row] = 0


func find_into(job_kind: int, job_target: int, out: IntMath.IntResult) -> bool:
	"""The first live job of this kind on this target, into `out`."""
	for row: int in MAX_JOBS:
		if kind[row] == job_kind and target[row] == job_target:
			return out.succeed(row)
	return out.refuse(REFUSE_NO_JOB)


func on_target(job_kind: int, job_target: int) -> int:
	"""How many live jobs of this kind are on this target."""
	var n: int = 0
	for row: int in MAX_JOBS:
		if kind[row] == job_kind and target[row] == job_target:
			n += 1
	return n


func of_worker_into(who: int, out: IntMath.IntResult) -> bool:
	"""The job resident `who` holds, into `out`."""
	for row: int in MAX_JOBS:
		if kind[row] != FREE and worker[row] == who:
			return out.succeed(row)
	return out.refuse(REFUSE_NO_JOB)


func assign(row: int, who: int) -> void:
	"""Give job `row` to resident `who`, from its current step's walk (a wait for a way is lifted)."""
	worker[row] = who
	issued[row] = 0
	tries[row] = 0
	blocked[row] = 0
	revision += 1


func unassign(row: int) -> void:
	"""Take job `row` back onto the board."""
	worker[row] = NOBODY
	issued[row] = 0
	revision += 1


func current_step(row: int) -> int:
	"""The step code job `row` stands at."""
	return int((PLANS[kind[row]] as Array)[step[row]])


func advance(row: int) -> bool:
	"""On to the next step (fresh walk, no work counted). False when the plan is done."""
	step[row] += 1
	issued[row] = 0
	elapsed_usec[row] = 0
	work_usec[row] = 0
	tries[row] = 0
	revision += 1
	return step[row] < (PLANS[kind[row]] as Array).size()


func restart(row: int) -> void:
	"""Run the plan again from its first step (a hauler going back for the next load)."""
	_reset(row)
	revision += 1


func become(row: int, job_kind: int) -> void:
	"""Turn job `row` into another kind on the same target, from its first step (a feller hauls)."""
	kind[row] = job_kind
	_reset(row)
	revision += 1


func become_delivery(row: int, job_kind: int) -> void:
	"""Job `row`'s work is cancelled with a load in hand: it is now the delivery `job_kind` of that load.
	At a step the delivery shares (the carry walk under way, the drop begun) it carries on from there;
	otherwise (logs on their way to the sawhorse, or on it) it sets off afresh for the stack."""
	var at: int = (PLANS[job_kind] as Array).find(current_step(row))
	kind[row] = job_kind
	revision += 1
	if at >= 0:
		step[row] = at
		return
	step[row] = 0
	issued[row] = 0
	elapsed_usec[row] = 0
	work_usec[row] = 0
	tries[row] = 0


func is_delivery(row: int) -> bool:
	"""Whether job `row` is a delivery (see the header)."""
	return kind[row] == KIND_CARRY_LOGS or kind[row] == KIND_CARRY_PLANKS


func rewind_to_walk(row: int) -> void:
	"""Called away mid-plan: back to the latest walk before the current step, keeping the load, so
	the next worker starts by walking there."""
	var plan: Array = PLANS[kind[row]]
	while step[row] > 0 and int(plan[step[row]]) >= STEP_WORK:
		step[row] -= 1
	issued[row] = 0
	elapsed_usec[row] = 0
	work_usec[row] = 0


func close(row: int) -> void:
	"""Free row `row`."""
	kind[row] = FREE
	worker[row] = NOBODY
	target[row] = NO_TARGET
	revision += 1


func live_count() -> int:
	"""How many jobs are on the board."""
	var n: int = 0
	for row: int in MAX_JOBS:
		n += 1 if kind[row] != FREE else 0
	return n
