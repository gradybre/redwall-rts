extends RefCounted
## Test support for the work board's promises (decision 0411; decisions 1900 and 1905: a worker called away keeps her
## job, and the board leaves it to her meanwhile). Shared by the suites whose rigs hand out an owner's jobs -- the
## fishery, the ferry, the forage trips and the orchard -- so each rig honours a promise as the real board does, and
## each "real work board" test builds that board one way. Not a suite (no `test_` prefix).
##
## An OWNER here is any of those job holders: it answers `brain_of(who)` and `name_of(who)`.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WorkBoard := preload("res://demo/work/work_board.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")


static func promised_to(owner: Object, residents: int, task_source: int, task_key: int) -> int:
	"""Who of the first `residents` means to come back to that task (the work board leaves it to them; -1: nobody)."""
	for who: int in residents:
		if (owner.call(&"brain_of", who) as BrainScript).promises(task_source, task_key):
			return who
	return -1


static func board_over(owner: Object, residents: int, source: SourceScript, row: int) -> WorkBoard:
	"""The REAL work board over the owner's first `residents`, `source` its one source: a crew key a resident, and every
	crew allowed row `row`'s activity, so the board WOULD give it to an idle resident -- the promise is what stops it."""
	var board := WorkBoard.new()
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for who: int in residents:
		brains.append(owner.call(&"brain_of", who) as BrainScript)
		names.append(String(owner.call(&"name_of", who)))
		keys.append(&"")
	board.bind(brains, names, keys)
	for crew: int in CrewsScript.CREW_COUNT:
		board.crews.set_priority(crew, source.activity(row), WorkIds.PRIORITY_NORMAL)
	board.add_source(source)
	return board
