extends "res://demo/orders/woods_goal.gd"
## KEEP N U OF WOOD (decision 0711): the stores' wood, raised by the winter's own Firewood rule shared
## (forest_crew.gd `raise_wood`, decision 0571): gather the deadfall pile nearest the log stack, else fell the nearest
## mature tree in a forestry zone its floor allows -- never a conservation zone or an unzoned tree. Its jobs are in the
## food/fuel bucket while fuel-days are under two (the winter's own test, `set_fuel_urgent`).

const NO_WOOD_TO_TAKE: String = ("no deadfall is lying and no mature tree may be felled in a forestry zone — zone some "
	+ "woods for forestry (Woods panel), or wait for deadfall")

var _fuel_urgent: Callable = Callable()


func _init(crew: CrewScript, stores: StoresScript, deadfall: DeadfallScript, stand: StandScript) -> void:
	"""Over this woods' crew, the village's stores and the woods' deadfall and stand."""
	super(crew, stores, deadfall, stand)
	kind = Kinds.KIND_WOOD


func set_fuel_urgent(fuel_urgent: Callable) -> void:
	"""`fuel_urgent() -> bool`: the winter's fuel-days under two (demo_winter.gd `firewood_urgent`)."""
	_fuel_urgent = fuel_urgent


func measure(_item: int) -> int:
	"""The wood in store."""
	return _stores.wood_milli_u


func urgent(_item: int) -> bool:
	"""Fuel jobs while the fuel reserve is under two days (GDD §5.3 bucket 2)."""
	return _fuel_urgent.is_valid() and bool(_fuel_urgent.call())


func raise_into(_item: int, _tracked: Callable, out: IntMath.IntResult) -> String:
	"""A gather of deadfall, else a fell (forest_crew.gd `raise_wood`)."""
	if board_full():
		return full_words()
	var row: int = _crew.raise_wood(JobsScript.ORIGIN_PLAYER)
	if row < 0:
		return NO_WOOD_TO_TAKE
	out.succeed(row)
	return ""
