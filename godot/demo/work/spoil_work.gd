extends "res://demo/work/work_source.gd"
## Spoil-heap clearing as the work board reads it (decision 0411; see work_source.gd): a row a worker (spoil_crew.gd),
## given only by the player's order on a heap, so nothing waits to be claimed. The board lists each worker's row --
## its phase, a blocked walk in A's words -- and its "Go to"; stopping one is giving its worker another order.

const CrewScript := preload("res://demo/spoil/spoil_crew.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const BY_ORDER: String = "a heap is cleared by those you order to it — give its worker another order to stop"
const RETRYING: String = "can't reach it, trying again"

var _crew: CrewScript = null
var _network: GraphScript = null
var _brains: Array[BrainScript] = []


func _init(crew: CrewScript, network: GraphScript, brains: Array[BrainScript]) -> void:
	"""Read this spoil crew's rows on this network, worked by these residents' brains."""
	id = WorkIds.SOURCE_SPOIL
	_crew = crew
	_network = network
	_brains = brains


func capacity() -> int:
	"""The spoil crew's rows."""
	return CrewScript.MAX_ROWS


func live(row: int) -> bool:
	"""A row with its worker."""
	return _crew.worker[row] != CrewScript.NOBODY


func key(row: int) -> int:
	"""The row and its heap."""
	return _crew.heap[row] * CrewScript.MAX_ROWS + row


func worker(row: int) -> int:
	"""The row's worker."""
	return _crew.worker[row]


func activity(_row: int) -> int:
	"""Clearing spoil is HAULING."""
	return WorkIds.ACT_HAUL


func point(row: int) -> Vector2:
	"""The heap."""
	return _network.heap_at[_crew.heap[row]]


func fill(task: TaskScript, row: int) -> void:
	"""The row's record."""
	task.reset(id, row)
	task.key = key(row)
	task.action = "Clear"
	task.target = "spoil heap %d (%s left)" % [_crew.heap[row] + 1, Measures.amount_cell(&"earth",
		_crew.spoil_left(_crew.heap[row]))]
	task.worker = _crew.worker[row]
	task.activity = WorkIds.ACT_HAUL
	task.carrying = _crew.load_milli[row] > 0
	task.point = point(row)
	var loads: int = ceili(float(_crew.spoil_left(_crew.heap[row])) / float(CrewScript.LOAD_MILLI))
	task.remaining_usec = loads * (CrewScript.DIG_USEC + CrewScript.DROP_USEC)
	task.pause_refusal = BY_ORDER
	task.cancel_refusal = BY_ORDER
	task.reassign_refusal = BY_ORDER
	if _crew.blocked[row] == 1:
		task.state = WorkIds.STATE_BLOCKED
		task.reason = RETRYING
		return
	var step: int = _crew.step[row]
	var walking: bool = step == CrewScript.STEP_GO or step == CrewScript.STEP_CARRY
	worker_state_into(task, _brains[task.worker], walking, _crew.issued[row] == 1)
