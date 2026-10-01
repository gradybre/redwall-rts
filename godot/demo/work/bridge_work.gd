extends "res://demo/work/work_source.gd"
## The bridges as the work board reads them (decision 0411; see work_source.gd). A planned bridge is one task, built by
## one builder (bridge_crew.gd); every command is the bridge crew's own. A builder let go puts any material it carried
## back at its source (bridge_crew.gd `_drop`), so a bridge may be paused or handed over at any step.

const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const NO_CANCEL: String = "a bridge's material is paid when it is planned — the demo cannot take a bridge back"
const OTHER_BRIDGE: String = "builds another bridge"
const IN_WATER: String = "in the water"

var _crew: CrewScript = null
var _bridges: BridgesScript = null


func _init(crew: CrewScript, bridges: BridgesScript) -> void:
	"""Read these bridges and their crew."""
	id = WorkIds.SOURCE_BRIDGES
	_crew = crew
	_bridges = bridges


func capacity() -> int:
	"""The bridge rows."""
	return BridgesScript.MAX_BRIDGES


func live(row: int) -> bool:
	"""Whether `row` is a bridge being built."""
	return _bridges.is_planned(row)


func key(row: int) -> int:
	"""The bridge's generation."""
	return _bridges.generation[row]


func worker(row: int) -> int:
	"""The builder."""
	return _crew.builder[row]


func activity(_row: int) -> int:
	"""Bridges are BUILDING."""
	return WorkIds.ACT_BUILD


func point(row: int) -> Vector2:
	"""Where its material lies while it waits (where a builder goes first)."""
	return _crew.source_at[row]


func waiting(row: int) -> bool:
	"""bridge_crew.gd `waiting`."""
	return _crew.waiting(row)


func eligibility(_row: int, who: int) -> String:
	"""Anybeast on land may build (LORE-P12): not one in the water, nor one building another bridge (bridge_crew.gd
	`reassign`'s own refusals)."""
	if _crew.can_build(who):
		return ""
	return OTHER_BRIDGE if _crew.builder.has(who) else IN_WATER


func claim(row: int, who: int) -> bool:
	"""bridge_crew.gd `claim`."""
	return _crew.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The bridge's record: who builds it, its step in words, the work left."""
	task.reset(id, row)
	task.key = _bridges.generation[row]
	task.action = "Build"
	task.target = "the %s" % _bridges.names[row]
	task.worker = _crew.builder[row]
	task.activity = WorkIds.ACT_BUILD
	task.carrying = _crew.step[row] == CrewScript.STEP_CARRY
	task.point = _crew.site_point(row)
	task.target_kind = NoticesScript.TARGET_BRIDGE
	task.target_id = row
	task.remaining_usec = _crew.remaining_usec(row)
	task.percent = _bridges.percent(row)
	task.cancel_refusal = NO_CANCEL
	if task.worker == CrewScript.NOBODY:
		waiting_state_into(task, _crew.is_paused(row), _unreached_words(row))
		return
	var step: int = _crew.step[row]
	var walking: bool = step == CrewScript.STEP_GO_SOURCE or step == CrewScript.STEP_CARRY
	worker_state_into(task, _crew.brain_of(task.worker), walking, _crew.issued[row] == 1)


func _unreached_words(row: int) -> String:
	"""A bridge its builder could not get to, while the crew leaves it (bridge_crew.gd UNREACHED_WAITING)."""
	if _crew.unreached_usec[row] <= 0:
		return ""
	return CrewScript.UNREACHED_WAITING % ceili(float(_crew.unreached_usec[row]) / 1000000.0)


func pause(row: int, on: bool) -> String:
	"""bridge_crew.gd `pause`."""
	return _crew.pause(row, on)


func cancel(_row: int) -> String:
	"""Not in the demo (NO_CANCEL)."""
	return NO_CANCEL


func reassign(row: int, who: int) -> String:
	"""bridge_crew.gd `reassign`."""
	return _crew.reassign(row, who)
