extends "res://demo/orders/woods_goal.gd"
## KEEP N PLANKS (decision 0711): the stores' planks, raised by sawing -- a Saw planks job on the woods' board, as the
## sawhorse's right-click with nobody selected queues one (forest_crew.gd `refusal_for`: a batch takes SAW_BATCH_MILLI
## of the stores' wood). Two saw batches at most at once (standing_kinds.gd MAX_JOBS).

const Measures := preload("res://scripts/ui/goods_measures.gd")

const NO_WOOD: String = "not enough wood to saw: a batch takes %s and the stores hold %s — keep wood stocked"


func _init(crew: CrewScript, stores: StoresScript) -> void:
	"""Over this woods' crew and the village's stores."""
	super(crew, stores)
	kind = Kinds.KIND_PLANKS


func measure(_item: int) -> int:
	"""The planks in store."""
	return _stores.plank_milli_u


func raise_into(_item: int, _tracked: Callable, out: IntMath.IntResult) -> String:
	"""A Saw planks job: refused for want of wood, or a full board."""
	if not _crew.refusal_for(JobsScript.KIND_SAW, JobsScript.NO_TARGET, 0).is_empty():
		return NO_WOOD % [Measures.need(&"wood", Rules.SAW_BATCH_MILLI), Measures.amount(&"wood", _stores.wood_milli_u)]
	if board_full():
		return full_words()
	if not _crew.jobs.open_into(JobsScript.KIND_SAW, JobsScript.NO_TARGET, 0, JobsScript.ORIGIN_PLAYER, out):
		return out.error.to_lower().replace("_", " ")
	return ""
