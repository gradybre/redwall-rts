extends RefCounted
## Who puts the fit-out in. Decision 0210 (the underground revamp's P4). Presentation only.
##
## A fixture ordered (or the suggested layout) is PLANNED on its place (room_fixtures.gd), paid for, waiting for a
## resident. Residents selected when the player orders it are given it at once, taken off whatever they were doing
## (a direct order: `give`) -- one place each, in place order. Anything still waiting is handed out every PICKUP_USEC
## of demo time to the nearest resident wandering on its own who can reach the room, at most MAX_INSTALLERS at once;
## not at night (the night routine's `resting`), when the village sleeps. Each is an install_task.gd.
##
## KEPT. A place kept for a resident (the one the player asked, or one called away from it -- to bed at dusk, say) goes
## only to that resident, while it is free, for KEEP_USEC of demo time (a game day) of waiting; then the keep lapses and
## anyone may take it. So the installers who were at it in the evening come back to it in the morning.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const InstallTaskScript := preload("res://demo/burrow/install_task.gd")

const PICKUP_USEC: int = 500000
const MAX_INSTALLERS: int = 3
const KEEP_USEC: int = 60000000

var _graph: RefCounted = null
var _brains: Array[BrainScript] = []
var _pickup_usec: int = 0
var _waiting: PackedInt32Array = PackedInt32Array()


func configure(graph: RefCounted, brains: Array[BrainScript]) -> void:
	"""Fit out this network's rooms with these residents (by index)."""
	_graph = graph
	_brains = brains


func update(usec: int) -> void:
	"""Hand out waiting fixtures every PICKUP_USEC of demo time (none while paused), and age the keeps."""
	if usec <= 0:
		return
	_age_keeps(usec)
	_pickup_usec += usec
	if _pickup_usec < PICKUP_USEC:
		return
	_pickup_usec = 0
	hand_out()


func hand_out() -> int:
	"""Give each waiting fixture, in place order, to the nearest free resident who can reach its room, while fewer
	than MAX_INSTALLERS are at it. How many were given."""
	var given := 0
	var fit: FixturesScript = _graph.fit
	fit.waiting_into(_graph, _waiting)
	for row in _waiting:
		if installers() >= MAX_INSTALLERS:
			break
		var who := taker(row)
		if who >= 0 and give(row, who):
			given += 1
	return given


func taker(row: int) -> int:
	"""Who may take waiting place row `row` now: the resident it is kept for, while free (see KEPT); else the nearest
	free one (-1: nobody)."""
	var kept: int = _graph.fit.asked[row]
	if kept >= 0 and kept < _brains.size():
		return kept if is_free(kept) and can_reach(kept, row / FixturesScript.PLACES) else -1
	return nearest_free(row / FixturesScript.PLACES)


func _age_keeps(usec: int) -> void:
	"""Every place kept for someone ages by `usec` (room_fixtures.gd `kept_usec`, zeroed when the keep begins); past
	KEEP_USEC its keep lapses (see KEPT). (A place put in, or taken back by its keeper, is kept for nobody.)"""
	var fit: FixturesScript = _graph.fit
	for row in fit.asked.size():
		if fit.asked[row] < 0:
			continue
		fit.kept_usec[row] += usec
		if fit.kept_usec[row] >= KEEP_USEC:
			fit.release_keep(row)


func installers() -> int:
	"""How many residents are putting a fixture in now."""
	var n := 0
	for b in _brains:
		n += 1 if b.task is InstallTaskScript else 0
	return n


func is_free(i: int) -> bool:
	"""Whether resident `i` is wandering on its own by day, able to take a fixture."""
	var b := _brains[i]
	return b.order == BrainScript.ORDER_NONE and not b.resting and not b.water_hold and not b.in_water \
			and b.state != BrainScript.State.CROSS


func can_reach(i: int, r: int) -> bool:
	"""Whether resident `i` can walk into room `r` through the network (one who fits no bore reaches no mouth)."""
	return _graph.paths.nearest_mouth(_graph, _graph.rooms.middle[r], _graph.walker_class(i, false)) >= 0


func nearest_free(r: int) -> int:
	"""The free resident nearest room `r`'s middle who can reach it (-1: none)."""
	var at: Vector2 = _graph.node_m(_graph.rooms.middle[r])
	var best := -1
	var best_d := INF
	for i in _brains.size():
		if not is_free(i) or not can_reach(i, r):
			continue
		var d := _brains[i].position.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


func give(row: int, who: int) -> bool:
	"""Resident `who` puts in the fixture planned at place row `row`, taken off whatever it was doing. False when the
	place is not waiting, it cannot reach the room, or the water's rescue holds it (it would take no order)."""
	var r := row / FixturesScript.PLACES
	var f := row % FixturesScript.PLACES
	if _brains[who].water_hold or not can_reach(who, r) or not _graph.fit.claim(_graph, r, f, who):
		return false
	_brains[who].order_task(InstallTaskScript.new(_graph, r, f, who))
	return true


func first_able(r: int, members: PackedInt32Array) -> int:
	"""The first of `members` `give` would accept for room `r` -- one the water's rescue does not hold, who can reach the
	room (-1: none). `give_selected` hands the room's first waiting fixture to this resident (an action card's
	assignment, decision 0331)."""
	for who in members:
		if who >= 0 and who < _brains.size() and not _brains[who].water_hold and can_reach(who, r):
			return who
	return -1


func give_selected(r: int, members: PackedInt32Array) -> int:
	"""The selected residents each take one of room `r`'s waiting fixtures, in place order (see the header). How many
	were given."""
	var given := 0
	var m := 0
	var fit: FixturesScript = _graph.fit
	fit.waiting_into(_graph, _waiting)
	for row in _waiting:
		if row / FixturesScript.PLACES != r:
			continue
		while m < members.size() and not give(row, members[m]):
			m += 1
		if m >= members.size():
			break
		m += 1
		given += 1
	return given
