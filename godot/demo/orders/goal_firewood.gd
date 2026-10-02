extends "res://demo/orders/woods_goal.gd"
## THE WINTER'S FIREWOOD as a built-in standing order (decision 0571, absorbed by decision 0711 with its behaviour
## unchanged): its OWN RULE, the winter's -- a job wanted while the wood is under the twelve-day projection in autumn or
## winter, or on any day heat is demanded (demo_winter.gd `firewood_wanted`); one at a time (forest_crew.gd
## `raise_firewood`, ORIGIN_FIREWOOD); in the food/fuel bucket under two fuel-days or while a hearth is out
## (`firewood_urgent`). The winter keeps it on its own hour (`_keep_firewood`), so it is evaluated exactly when it was.

const NOTHING_TO_TAKE: String = ("no deadfall is lying and no mature tree may be felled in a forestry zone — zone some "
	+ "woods for forestry (Woods panel)")

var _wanted: Callable = Callable()
var _urgent: Callable = Callable()
var _target: Callable = Callable()


func _init(crew: CrewScript, stores: StoresScript, is_wanted: Callable, is_urgent: Callable, projection: Callable) -> void:
	"""Over this woods' crew and the stores, with the winter's three readings: `is_wanted() -> bool`,
	`is_urgent() -> bool` and `projection() -> int` (milli-U)."""
	super(crew, stores)
	kind = Kinds.KIND_FIREWOOD
	_wanted = is_wanted
	_urgent = is_urgent
	_target = projection


func measure(_item: int) -> int:
	"""The wood in store."""
	return _stores.wood_milli_u


func target(_amount: int) -> int:
	"""The twelve-day winter projection (REQ-SET-114's fuel half)."""
	return int(_target.call()) if _target.is_valid() else 0


func own_rule() -> bool:
	"""The winter says when it is wanted."""
	return true


func wanted(_item: int) -> bool:
	"""demo_winter.gd `firewood_wanted`."""
	return _wanted.is_valid() and bool(_wanted.call())


func urgent(_item: int) -> bool:
	"""demo_winter.gd `firewood_urgent`."""
	return _urgent.is_valid() and bool(_urgent.call())


func raise_into(_item: int, _tracked: Callable, out: IntMath.IntResult) -> String:
	"""forest_crew.gd `raise_firewood` (a full woods board said as such)."""
	if board_full():
		return full_words()
	var row: int = _crew.raise_firewood()
	if row < 0:
		return NOTHING_TO_TAKE
	out.succeed(row)
	return ""
