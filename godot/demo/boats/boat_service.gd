extends RefCounted
## A BOAT ROW'S SERVICE (decision 1821): what serves one boat crossing row (demo/routes/boat_rows.gd) -- the ferry today
## (demo/ferry/ferry.gd, row 0). It fills its row for each trip the router plans (its landings, its ride, its boardings
## with a seat free; nothing while closed), and walks a passenger's leg across once a route takes it: wait at the
## landing, board, ride, step off. Any refusal while it waits ends the leg where it stands (the resident plans again by
## land), as every crossing's does (water_crossings.gd THE BANK RECHECK). The base serves nothing: its row is never
## offered and a leg on it is over at once. No free sailing: a service's boat keeps to its fixed route.

const BoatBrain := preload("res://demo/cast/resident_brain.gd")
const BoatRowsTable := preload("res://demo/routes/boat_rows.gd")


func fill_boat_row(_rows: BoatRowsTable, _r: int, _walker: int, _from: Vector2, _loaded: bool) -> void:
	"""Fill row `_r` of `_rows` for resident `_walker` setting out from `_from` (carrying, when `_loaded`): `open_row`,
	then each landing's boardings in ticks from now. The table has cleared the row; the base leaves it closed."""
	pass


func end_point(_far: bool) -> Vector2:
	"""The row's land end a (b when `_far`), metres."""
	return Vector2.ZERO


func begin_passenger(_brain: BoatBrain, _reverse: bool) -> void:
	"""`_brain` reaches landing a (b when `_reverse`) to cross: it waits there for a boarding."""
	pass


func step_passenger(_brain: BoatBrain, _delta: float) -> bool:
	"""One step of a passenger's leg; true once it stands at the other landing's land end (or, refused, where it
	waits). The base has no boat, so the leg is over at once."""
	return true


func abandon_passenger(_brain: BoatBrain) -> void:
	"""Forget a passenger's leg (an emergency took it off where it stands), freeing its seat."""
	pass


func passenger_text(_who: int) -> String:
	"""What a passenger is doing, in words."""
	return "crossing by boat"
