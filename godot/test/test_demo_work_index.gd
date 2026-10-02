extends "res://test/framework/test_case.gd"
## The work board's candidate index (work_board.gd THE INDEX DOES NOT GROW WITH THE VILLAGE, decision 1004): a source
## that never holds a task to claim is not read, the promises are looked up by task, and the index is the one the old
## rebuild made -- every waiting task of every source in order, each with the first resident whose list promises it --
## over random boards and order lists. No scene tree, no assets.

const BoardScript := preload("res://demo/work/work_board.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")

const SEED: int = 1004
const RESIDENTS: int = 30
const ROUNDS: int = 25


## A source of `rows` rows, some waiting, each with its own key; `claims` false: one that never waits (the kitchen's).
class StubSource extends "res://demo/work/work_source.gd":
	var waits: PackedByteArray = PackedByteArray()
	var keys: PackedInt64Array = PackedInt64Array()
	var claims: bool = true
	var rows_read: int = 0

	func capacity() -> int:
		"""Its rows."""
		return waits.size()

	func may_wait() -> bool:
		"""Whether it may hold a task to claim."""
		return claims

	func waiting(row: int) -> bool:
		"""Whether row `row` waits (counted)."""
		rows_read += 1
		return claims and waits[row] == 1

	func key(row: int) -> int:
		"""Row `row`'s task key."""
		return keys[row]


func _take_nothing(_brain: RefCounted) -> bool:
	"""A take-back that takes nothing back."""
	return false


func _board(rng: RandomNumberGenerator, brains: Array[BrainScript]) -> BoardScript:
	"""A board over these residents with three random claimable sources and a kitchen-like one; each resident's list
	names up to three random tasks."""
	var board := BoardScript.new()
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i in brains.size():
		names.append("r%d" % i)
		keys.append(&"mouse_fieldworker")
	board.bind(brains, names, keys)
	for id in [WorkIds.SOURCE_FARM, WorkIds.SOURCE_WOODS, WorkIds.SOURCE_KITCHEN, WorkIds.SOURCE_BRIDGES]:
		var source := StubSource.new()
		source.id = id
		source.claims = id != WorkIds.SOURCE_KITCHEN
		for row in 12:
			source.waits.append(1 if rng.randf() < 0.5 else 0)
			source.keys.append(rng.randi_range(0, 20))
		board.add_source(source)
	for brain in brains:
		for k in rng.randi_range(0, 3):
			var source: int = [WorkIds.SOURCE_FARM, WorkIds.SOURCE_WOODS, WorkIds.SOURCE_KITCHEN][rng.randi_range(0, 2)]
			brain.append_queued(UnfinishedScript.new(_take_nothing, "job %d" % k, source, rng.randi_range(0, 20)))
	return board


func _old_index(board: BoardScript, brains: Array[BrainScript]) -> Array:
	"""The index as the old rebuild made it: every waiting row of every source, with the first promiser in resident
	order, then list order. [sources, rows, promised]."""
	var sources := PackedInt32Array()
	var rows := PackedInt32Array()
	var promised := PackedInt32Array()
	for id in WorkIds.SOURCE_COUNT:
		var src: StubSource = board.source(id) as StubSource
		if src == null:
			continue
		for row in src.capacity():
			if src.waiting(row):
				sources.append(id)
				rows.append(row)
				promised.append(_first_promiser(brains, id, src.key(row)))
	return [sources, rows, promised]


func _first_promiser(brains: Array[BrainScript], source: int, key: int) -> int:
	"""The first resident whose list names (source, key), -1: none."""
	for who in brains.size():
		for k in brains[who].queue_size():
			if brains[who].queue_entry(k).names_task(source, key):
				return who
	return -1


func test_the_index_is_the_old_rebuilds_entry_for_entry() -> void:
	"""Random boards and lists: the same entries in the same order, each promised to the same resident."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var differ := 0
	var promised := 0
	for round_index in ROUNDS:
		var brains: Array[BrainScript] = []
		for i in RESIDENTS:
			brains.append(BrainScript.new())
		var board := _board(rng, brains)
		board.rebuild_index()
		var old := _old_index(board, brains)
		var now := [board._idx_source, board._idx_row, board._idx_promised]
		differ += 0 if now == old else 1
		for who in board._idx_promised:
			promised += 1 if who >= 0 else 0
	assert_equal(differ, 0, "the old index every round")
	assert_true(promised > ROUNDS, "promises among them (%d)" % promised)


func test_a_source_that_never_waits_is_not_read() -> void:
	"""The kitchen-like source's rows are never read by a rebuild; the others' are, once each."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var brains: Array[BrainScript] = [BrainScript.new()]
	var board := _board(rng, brains)
	board.rebuild_index()
	assert_equal((board.source(WorkIds.SOURCE_KITCHEN) as StubSource).rows_read, 0, "never read")
	assert_equal((board.source(WorkIds.SOURCE_FARM) as StubSource).rows_read, 12, "each farm row once")
