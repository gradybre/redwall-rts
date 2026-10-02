extends "res://demo/orders/order_goal.gd"
## The woods' side of the standing orders (decision 0711): a job is a row of the woods' job board (forest_jobs.gd), its
## identity the row's serial, and what it will still bring in read from the job's own load and target. The planks, the
## wood and the winter's Firewood goals extend this.

const CrewScript := preload("res://demo/forestry/forest_crew.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

const BOARD_FULL: String = "the woods' job board is full (%d jobs) — cancel some there first"

var _crew: CrewScript = null
var _stores: StoresScript = null
var _deadfall: DeadfallScript = null
var _stand: StandScript = null


func _init(crew: CrewScript, stores: StoresScript, deadfall: DeadfallScript = null, stand: StandScript = null) -> void:
	"""Over this woods' crew and the village's stores (the deadfall and the stand for what a job will bring; null: not
	counted)."""
	source = WorkIds.SOURCE_WOODS
	_crew = crew
	_stores = stores
	_deadfall = deadfall
	_stand = stand


func key_of(row: int) -> int:
	"""The woods job's serial."""
	return _crew.jobs.serial[row]


func live(row: int, job_key: int) -> bool:
	"""The same job (its serial) is still on the woods' board."""
	return _crew.jobs.is_live(row) and _crew.jobs.serial[row] == job_key


func output_of(row: int, _item: int) -> int:
	"""A load in hand, else what the job is for: a saw batch, a deadfall pile, a felled tree, the wood left on a trunk."""
	var jobs: JobsScript = _crew.jobs
	if jobs.load_milli[row] > 0:
		return jobs.load_milli[row]
	var t: int = jobs.target[row]
	match jobs.kind[row]:
		JobsScript.KIND_SAW:
			return Rules.SAW_BATCH_MILLI
		JobsScript.KIND_GATHER:
			return _deadfall.milli[t] if _deadfall != null and _deadfall.is_live(t, jobs.target_gen[row]) else 0
		JobsScript.KIND_FELL:
			return Rules.TREE_WOOD_MILLI
		JobsScript.KIND_HAUL:
			return _stand.trunk_milli[t] if _stand != null and _stand.is_tree(t) else 0
	return 0


func board_full() -> bool:
	"""Whether the woods' board has no free row."""
	return _crew.jobs.live_count() >= JobsScript.MAX_JOBS


func full_words() -> String:
	"""The full board, in words."""
	return BOARD_FULL % JobsScript.MAX_JOBS
