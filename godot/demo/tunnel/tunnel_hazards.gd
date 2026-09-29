extends RefCounted
## Warned, preventable tunnel hazards. Decision 0196 (live demo). Presentation only.
##
## ---------------------------------------------------------------------------------------
## DETERMINISTIC, WARNED AND PREVENTABLE (DEC-040: "warned, preventable hazards ... rather than
## surprise death rolls"; HAZ-001 adds no random disaster roll). Nothing here is rolled. An
## UNBRACED open tunnel builds up two pressures, in integer demo microseconds, from what the player
## can see:
##   * SEEP, while it runs through WET ground (tunnel_ground.gd: the stream edge) and rain falls
##     (demo_weather.is_wet), FLOOD_EVENT_FACTOR times faster while a stream flood covers one of its
##     mouths (demo/events/). At SEEP_FULL_USEC it FLOODS: the whole tunnel closes.
##   * STRAIN, while it runs through WEAK ground (sand) and rain falls, plus CROSSING_STRAIN_USEC each
##     time someone walks into it. At STRAIN_FULL_USEC its sand section COLLAPSES: up to
##     COLLAPSE_QUANTA quanta of it close -- but never on anyone: while someone stands under that
##     section the roof holds (and creaks), and falls once they are clear.
## At WARN_PERMILLE of either, a warning is raised once, naming the tunnel and the cure. BRACING
## (tunnel_jobs.gd) removes both for good: a braced tunnel builds up nothing. Nothing builds while a
## job is at work in the tunnel, nor in frost or snow (the ground is frozen). A PUMP job reopens a
## flooded tunnel and a CLEAR job a collapsed one, and each resets only the pressure that struck.
##
## These rules are the demo's own. HAZ-001 adopts, for production, that completed DRY, SUPPORTED
## tunnels never collapse, flood or injure, and adds no flood model: the demo's tunnels are dug with
## the cited brace TIME but no paid timber (ECON-002's wood 250 + stone 250 a quantum is charged
## only by the BRACE upgrade), so an unbraced demo tunnel is what the adopted rules would refuse to
## cut at all. Nobody is ever hurt: residents in a closing tunnel walk back out (tunnel_works.gd).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")

const SEEP_FULL_USEC: int = 40000000
const STRAIN_FULL_USEC: int = 75000000
const WARN_PERMILLE: int = 500
const CROSSING_STRAIN_USEC: int = 8000000
const FLOOD_EVENT_FACTOR: int = 4
const COLLAPSE_QUANTA: int = 3

const EVENT_NONE: int = 0
const EVENT_SEEP_WARNING: int = 1
const EVENT_FLOODED: int = 2
const EVENT_STRAIN_WARNING: int = 3
const EVENT_COLLAPSE_DUE: int = 4

const WARNED_SEEP: int = 1
const WARNED_STRAIN: int = 2

## Per tunnel slot: seep and strain built up (demo microseconds), warnings given (bits), how many of
## its quanta lie in wet and in weak ground, and where its collapse would fall (u along it).
var seep_usec: PackedInt64Array = PackedInt64Array()
var strain_usec: PackedInt64Array = PackedInt64Array()
var warned: PackedByteArray = PackedByteArray()
var wet_quanta: PackedInt32Array = PackedInt32Array()
var weak_quanta: PackedInt32Array = PackedInt32Array()
var fall_from_u: PackedInt32Array = PackedInt32Array()
var fall_to_u: PackedInt32Array = PackedInt32Array()

var _network: NetworkScript = null


func _init(network: NetworkScript) -> void:
	"""Hazards on this network's tunnels. Columns sized once."""
	_network = network
	seep_usec.resize(Rules.MAX_TUNNELS)
	strain_usec.resize(Rules.MAX_TUNNELS)
	warned.resize(Rules.MAX_TUNNELS)
	wet_quanta.resize(Rules.MAX_TUNNELS)
	weak_quanta.resize(Rules.MAX_TUNNELS)
	fall_from_u.resize(Rules.MAX_TUNNELS)
	fall_to_u.resize(Rules.MAX_TUNNELS)


func survey(slot: int) -> void:
	"""A tunnel just opened: count its wet and weak quanta, place where a collapse would fall -- the
	middle of its longest run of weak quanta, at most COLLAPSE_QUANTA long -- and start it clean."""
	seep_usec[slot] = 0
	strain_usec[slot] = 0
	warned[slot] = 0
	wet_quanta[slot] = 0
	weak_quanta[slot] = 0
	var ground := _network.ground
	var best_start := 0
	var best_run := 0
	var run := 0
	for k in _network.timeline_count(slot):
		var at := _network.quantum_point_u(slot, k)
		var weak := _network.quantum_kind(slot, k) == GroundScript.SAND
		wet_quanta[slot] += 1 if ground != null and ground.wet_at(at.x, at.y) else 0
		weak_quanta[slot] += 1 if weak else 0
		run = run + 1 if weak else 0
		if run > best_run:
			best_run = run
			best_start = k - run + 1
	_place_fall(slot, best_start, best_run)


func _place_fall(slot: int, start: int, run: int) -> void:
	"""The collapse section: COLLAPSE_QUANTA quanta (or the whole run, if shorter) centred on the run."""
	var take := mini(run, COLLAPSE_QUANTA)
	var first := start + (run - take) / 2
	fall_from_u[slot] = _network.quantum_along_u(slot, first)
	fall_to_u[slot] = _network.quantum_along_u(slot, maxi(first + take - 1, first))


func exposed(slot: int) -> bool:
	"""Whether the tunnel can come to harm at all: open, unbraced, through wet or weak ground."""
	return _network.is_open(slot) and _network.braced[slot] == 0 \
			and (wet_quanta[slot] > 0 or weak_quanta[slot] > 0)


func update(slot: int, usec: int, raining: bool, flooding: bool, working: bool) -> int:
	"""Build up this frame's pressures on tunnel `slot` (see DETERMINISTIC ...). Returns what came of
	it: EVENT_NONE, a first warning, EVENT_FLOODED or EVENT_COLLAPSE_DUE."""
	if _network.braced[slot] == 1:
		seep_usec[slot] = 0
		strain_usec[slot] = 0
		return EVENT_NONE
	if not exposed(slot) or _network.closed[slot] != NetworkScript.CLOSED_NONE or working or usec <= 0:
		return EVENT_NONE
	if wet_quanta[slot] > 0 and (raining or flooding):
		seep_usec[slot] += usec * (FLOOD_EVENT_FACTOR if flooding else 1)
	if weak_quanta[slot] > 0 and raining:
		strain_usec[slot] += usec
	return _verdict(slot)


func add_crossing(slot: int) -> int:
	"""Someone walked into tunnel `slot`: a weak unbraced bore takes the strain. Returns what came of it."""
	if not exposed(slot) or weak_quanta[slot] == 0 or _network.closed[slot] != NetworkScript.CLOSED_NONE:
		return EVENT_NONE
	strain_usec[slot] += CROSSING_STRAIN_USEC
	return _verdict(slot)


func _verdict(slot: int) -> int:
	"""A flood or a collapse now due, else a first warning, else nothing."""
	if seep_usec[slot] >= SEEP_FULL_USEC:
		return EVENT_FLOODED
	if strain_usec[slot] >= STRAIN_FULL_USEC:
		return EVENT_COLLAPSE_DUE
	if seep_permille(slot) >= WARN_PERMILLE and warned[slot] & WARNED_SEEP == 0:
		warned[slot] |= WARNED_SEEP
		return EVENT_SEEP_WARNING
	if strain_permille(slot) >= WARN_PERMILLE and warned[slot] & WARNED_STRAIN == 0:
		warned[slot] |= WARNED_STRAIN
		return EVENT_STRAIN_WARNING
	return EVENT_NONE


func seep_permille(slot: int) -> int:
	"""How near flooding tunnel `slot` is, per mille (capped at 1000)."""
	return mini(Rules.PERMILLE, seep_usec[slot] * Rules.PERMILLE / SEEP_FULL_USEC)


func strain_permille(slot: int) -> int:
	"""How near collapse tunnel `slot` is, per mille (capped at 1000)."""
	return mini(Rules.PERMILLE, strain_usec[slot] * Rules.PERMILLE / STRAIN_FULL_USEC)


func flood(slot: int) -> void:
	"""Tunnel `slot` floods from end to end."""
	_network.close(slot, NetworkScript.CLOSED_FLOODED, 0, _network.length_u[slot])


func collapse(slot: int) -> void:
	"""Tunnel `slot`'s weak section falls in."""
	_network.close(slot, NetworkScript.CLOSED_COLLAPSED, fall_from_u[slot], fall_to_u[slot])


func repaired(slot: int, pumped: bool) -> void:
	"""A pump (`pumped`) or a clearing reopened tunnel `slot`: the pressure that struck starts again
	from nothing, and may be warned of again; the other keeps what it had built."""
	if pumped:
		seep_usec[slot] = 0
		warned[slot] &= ~WARNED_SEEP
	else:
		strain_usec[slot] = 0
		warned[slot] &= ~WARNED_STRAIN


func in_fall(slot: int, along_m: float) -> bool:
	"""Whether a point `along_m` metres into tunnel `slot` lies under its collapse section (with half a
	quantum's margin either side)."""
	var along := Rules.to_u(along_m)
	var margin := Rules.QUANTUM_U / 2
	return along >= fall_from_u[slot] - margin and along <= fall_to_u[slot] + margin
