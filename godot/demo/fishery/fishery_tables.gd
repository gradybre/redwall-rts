extends RefCounted
## The fishery's rows (fishery.gd drives them): TRIPS, the JOBS residents do for them and for the stations, and the
## drying rack's batch slots. Decision 0431 (live demo). Structure of arrays, sized once; integer authoritative state
## (positions only as float presentation goals). No logic here beyond opening and closing rows.
##
## A TRIP is one authorised fishing expedition: its method, site, species, its gear or boat, the open fishing cycle
## (fishing_driver.gd Cycle: the effort slots and the coordinator Job the gear's claim belongs to), the room held in the
## pantry for its catch, its state and its deadline. A JOB is one resident's part -- a trip's seat (a boat has two),
## a trap's collection, a rack batch, a mill batch, making or mending gear -- with the load it carries in hand.

const FishingDriver := preload("res://demo/water/fishing_driver.gd")

const MAX_TRIPS: int = 8
const MAX_JOBS: int = 24
const NONE: int = -1

## Trip states.
const TRIP_QUEUED: int = 0        # authorised; the crew is on its way (no cycle yet)
const TRIP_FISHING: int = 1       # the cycle is open: at the bank, on the ice, or the boat out
const TRIP_SOAKING: int = 2       # a trap set and left (its cycle open, nobody there)
const TRIP_LANDING: int = 3       # the catch is out of the water, being carried to the stores
const TRIP_RETURNING: int = 4     # called off afloat or on the ice: coming back, nothing caught
const TRIP_WORDS: Array[String] = ["setting out", "fishing", "trap soaking", "landing the catch", "coming back"]

## Job kinds.
const KIND_SEAT: int = 0          # a trip's fisher (a boat's two seats)
const KIND_COLLECT: int = 1       # a set trap's collection (or lifting it, called off)
const KIND_DRY: int = 2           # carry fish to the rack and hang a batch
const KIND_TAKE_DOWN: int = 3     # take a cured batch down and carry it to the stores
const KIND_MILL: int = 4          # carry grain to the mill, grind it, carry the flour to the stores
const KIND_MAKE: int = 5          # make a piece of gear at the workbench, carry it to the locker
const KIND_MEND: int = 6          # mend a piece of gear at the locker, or a boat at the jetty
const KIND_BATCH: int = 7         # a station batch with no passive wait (decision 1611: rations at the preserving table)
## The kinds' words (a recipe row's own words come first: fishery.gd `job_words`).
const KIND_WORDS: Array[String] = ["Fish", "Collect the trap", "Dry fish", "Take down dried fish", "Mill grain",
	"Make gear", "Mend gear", "Pack rations"]

## Rack slot states.
const SLOT_EMPTY: int = 0
const SLOT_LOADING: int = 1       # a batch's fish on the way, or being hung (its DRY job)
const SLOT_CURING: int = 2        # hung: 12 h passive (REQ-SET-093: the slot is taken, the worker free)
const SLOT_READY: int = 3         # cured: waiting to be taken down
const SLOT_TAKING: int = 4        # being taken down (its TAKE_DOWN job)

# --- trips ----------------------------------------------------------------------------------
var t_live: PackedByteArray = PackedByteArray()
var t_serial: PackedInt32Array = PackedInt32Array()
var t_method: PackedInt32Array = PackedInt32Array()
var t_site: PackedInt32Array = PackedInt32Array()
var t_species: PackedInt32Array = PackedInt32Array()
var t_boat: PackedInt32Array = PackedInt32Array()
var t_gear: PackedInt32Array = PackedInt32Array()
var t_outfit: PackedInt32Array = PackedInt32Array()
var t_state: PackedInt32Array = PackedInt32Array()
var t_hold: PackedInt32Array = PackedInt32Array()
var t_item: PackedInt32Array = PackedInt32Array()
var t_expected: PackedInt64Array = PackedInt64Array()
var t_caught: PackedInt64Array = PackedInt64Array()
var t_due: PackedInt64Array = PackedInt64Array()
var t_soak_until: PackedInt64Array = PackedInt64Array()
var t_work_mwu: PackedInt64Array = PackedInt64Array()
var t_called_off: PackedByteArray = PackedByteArray()
var t_overdue: PackedByteArray = PackedByteArray()
var t_seat_job: PackedInt32Array = PackedInt32Array()
var t_cycle: Array = []
var t_words: PackedStringArray = PackedStringArray()
## The fishing revamp (decisions 1711-1712): 1 for a BEST CATCH trip (catch_plan.gd: its species is chosen again at the
## water), the trap's collection policy (catch_plan.gd COLLECT_*), and the EXCELLENT share of its catch (milli-U).
var t_auto: PackedByteArray = PackedByteArray()
var t_collect: PackedByteArray = PackedByteArray()
var t_excellent: PackedInt64Array = PackedInt64Array()
## The FISHING stream's two draws for the trip's open cycle, taken when it departed (fishing_rolls.gd; -1: none yet).
var t_hazard_roll: PackedInt32Array = PackedInt32Array()
var t_rare_roll: PackedInt32Array = PackedInt32Array()
## The tick a soaked trap's collection goes on the board (-1: not worked out yet; catch_plan.gd COLLECTION).
var t_collect_at: PackedInt64Array = PackedInt64Array()

# --- jobs -----------------------------------------------------------------------------------
var j_live: PackedByteArray = PackedByteArray()
var j_serial: PackedInt32Array = PackedInt32Array()
var j_kind: PackedInt32Array = PackedInt32Array()
var j_worker: PackedInt32Array = PackedInt32Array()
var j_trip: PackedInt32Array = PackedInt32Array()
var j_seat: PackedInt32Array = PackedInt32Array()
var j_slot: PackedInt32Array = PackedInt32Array()
## A station batch's recipe row (demo/preserve/preserve_rules.gd R_*; NONE for any other job).
var j_recipe: PackedInt32Array = PackedInt32Array()
var j_prog: PackedInt32Array = PackedInt32Array()
var j_pos: PackedInt32Array = PackedInt32Array()
var j_goal: PackedVector2Array = PackedVector2Array()
var j_issued: PackedByteArray = PackedByteArray()
var j_mwu: PackedInt64Array = PackedInt64Array()
var j_num: PackedInt64Array = PackedInt64Array()
var j_need: PackedInt64Array = PackedInt64Array()
var j_load_item: PackedInt32Array = PackedInt32Array()
var j_load_milli: PackedInt64Array = PackedInt64Array()
var j_load_at: PackedVector2Array = PackedVector2Array()
var j_take: PackedInt32Array = PackedInt32Array()
var j_hold: PackedInt32Array = PackedInt32Array()
var j_tries: PackedInt32Array = PackedInt32Array()
var j_wait_usec: PackedInt64Array = PackedInt64Array()
var j_paused: PackedByteArray = PackedByteArray()
var j_started: PackedByteArray = PackedByteArray()
## 1 while the worker stands at its work in a work step (fishery.gd credits the work then, on the demo clock).
var j_at: PackedByteArray = PackedByteArray()
var j_words: PackedStringArray = PackedStringArray()

# --- the rack -------------------------------------------------------------------------------
var s_state: PackedInt32Array = PackedInt32Array()
var s_ready_tick: PackedInt64Array = PackedInt64Array()
var s_hold: PackedInt32Array = PackedInt32Array()
## Each slot's batch's recipe row (preserve_rules.gd: the Dryer dries fish or fruit).
var s_recipe: PackedInt32Array = PackedInt32Array()

var _next_serial: int = 1


func _init(rack_slots: int) -> void:
	"""Empty tables: MAX_TRIPS trips, MAX_JOBS jobs and `rack_slots` rack slots."""
	_size_trips()
	_size_jobs()
	s_state.resize(rack_slots)
	s_ready_tick.resize(rack_slots)
	s_hold.resize(rack_slots)
	s_hold.fill(NONE)
	s_recipe.resize(rack_slots)


func _size_trips() -> void:
	"""Every trip column, MAX_TRIPS long."""
	for column: PackedByteArray in [t_live, t_called_off, t_overdue, t_auto, t_collect]:
		column.resize(MAX_TRIPS)
	for column: PackedInt32Array in [t_serial, t_method, t_site, t_species, t_boat, t_gear, t_outfit, t_state, t_hold,
			t_item, t_hazard_roll, t_rare_roll]:
		column.resize(MAX_TRIPS)
	for column: PackedInt64Array in [t_expected, t_caught, t_due, t_soak_until, t_work_mwu, t_excellent, t_collect_at]:
		column.resize(MAX_TRIPS)
	t_seat_job.resize(MAX_TRIPS * 2)
	t_seat_job.fill(NONE)
	t_cycle.resize(MAX_TRIPS)
	t_words.resize(MAX_TRIPS)


func _size_jobs() -> void:
	"""Every job column, MAX_JOBS long."""
	for column: PackedByteArray in [j_live, j_issued, j_paused, j_started, j_at]:
		column.resize(MAX_JOBS)
	for column: PackedInt32Array in [j_serial, j_kind, j_worker, j_trip, j_seat, j_slot, j_recipe, j_prog, j_pos,
			j_load_item, j_take, j_hold, j_tries]:
		column.resize(MAX_JOBS)
	for column: PackedInt64Array in [j_mwu, j_num, j_need, j_load_milli, j_wait_usec]:
		column.resize(MAX_JOBS)
	j_goal.resize(MAX_JOBS)
	j_load_at.resize(MAX_JOBS)
	j_words.resize(MAX_JOBS)


func new_serial() -> int:
	"""A fresh serial (> 0): a trip's or a job's identity for life."""
	_next_serial += 1
	return _next_serial


func open_trip(method: int, site: int, species: int) -> int:
	"""A trip row for `method` at `site` (`species` its index 0..2 there), QUEUED; NONE when every row is taken."""
	var t: int = t_live.find(0)
	if t < 0:
		return NONE
	t_live[t] = 1
	t_serial[t] = new_serial()
	t_method[t] = method
	t_site[t] = site
	t_species[t] = species
	for column: PackedInt32Array in [t_boat, t_gear, t_outfit, t_hold, t_item, t_hazard_roll, t_rare_roll]:
		column[t] = NONE
	for column: PackedInt64Array in [t_expected, t_caught, t_due, t_soak_until, t_work_mwu, t_excellent]:
		column[t] = 0
	t_state[t] = TRIP_QUEUED
	t_called_off[t] = 0
	t_overdue[t] = 0
	t_auto[t] = 0
	t_collect[t] = 0
	t_collect_at[t] = NONE
	t_seat_job[t * 2] = NONE
	t_seat_job[t * 2 + 1] = NONE
	t_cycle[t] = null
	t_words[t] = ""
	return t


func close_trip(t: int) -> void:
	"""Free a trip row (its claims already released by the caller)."""
	t_live[t] = 0
	t_cycle[t] = null
	t_seat_job[t * 2] = NONE
	t_seat_job[t * 2 + 1] = NONE


func is_trip(t: int) -> bool:
	"""Whether `t` is a live trip row."""
	return t >= 0 and t < MAX_TRIPS and t_live[t] == 1


func open_job(kind: int, prog: int, trip: int) -> int:
	"""A job row of `kind` running program `prog` (fishery.gd PROG_*), for trip `trip` (NONE: a station's); NONE when
	every row is taken."""
	var j: int = j_live.find(0)
	if j < 0:
		return NONE
	j_live[j] = 1
	j_serial[j] = new_serial()
	j_kind[j] = kind
	j_prog[j] = prog
	j_trip[j] = trip
	for column: PackedInt32Array in [j_worker, j_seat, j_slot, j_recipe, j_load_item, j_take, j_hold]:
		column[j] = NONE
	j_pos[j] = 0
	j_tries[j] = 0
	for column: PackedInt64Array in [j_mwu, j_num, j_need, j_load_milli, j_wait_usec]:
		column[j] = 0
	for column: PackedByteArray in [j_issued, j_paused, j_started, j_at]:
		column[j] = 0
	j_goal[j] = Vector2.ZERO
	j_load_at[j] = Vector2.INF
	j_words[j] = ""
	return j


func close_job(j: int) -> void:
	"""Free a job row (its load, take and hold already settled by the caller)."""
	j_live[j] = 0
	j_worker[j] = NONE


func is_job(j: int, serial: int) -> bool:
	"""Whether `j` is a live job row still opened with `serial` (a stale task's row is someone else's now)."""
	return j >= 0 and j < MAX_JOBS and j_live[j] == 1 and j_serial[j] == serial


func job_of_worker(who: int) -> int:
	"""The live job resident `who` works (NONE: none)."""
	for j: int in MAX_JOBS:
		if j_live[j] == 1 and j_worker[j] == who:
			return j
	return NONE


func trip_count() -> int:
	"""Live trips."""
	return t_live.count(1)


func job_count() -> int:
	"""Live jobs."""
	return j_live.count(1)
