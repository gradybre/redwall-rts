extends "res://demo/cast/crossing_hook.gd"
## The crossings a ROUTE ESTIMATE offers its router (demo/routes/route_estimator.gd, decision 0461): the village's
## own -- exactly what the live water offers that trip (demo/waterplay/water_crossings.gd) -- and, for an "after"
## estimate, one PROPOSED bridge besides, as if it were open. Presentation only; it plans, it moves nobody.
##
## THE SAME OFFER AS THE LIVE ONE. `offers_for` and `offer_into` hand the trip to the real hook first, so every open
## bridge and every swim link the live router would see for that walker, load and weather is offered here too, at the
## same cost; a trip whose straight line meets no water is offered nothing (the real rule), the proposal included.
## Wading costs are the real hook's (`wade_extra_m`). A proposal is offered as the live water offers an OPEN bridge:
## between its two approaches, at its approach-to-approach walk times the weather's surface scale -- the figures a
## planned bridge row gives (bridges.gd `approach`, `walk_length_m`), so once the real bridge opens the live router
## is offered exactly this pair.
##
## THE CACHE. The estimate's router is its own (a scratch copy of the network), so this hook's revision only keys that
## router's stop-to-stop cache: it moves with the real hook's and with every new proposal (`propose`).

const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")

## The crossing row a proposal is offered under: above every real row (bridges, swim links, the water's ashore row
## 4000 is never offered), so its leg code says "the proposed crossing" (route_kinds.gd).
const PROPOSAL_ROW: int = 3000
## Room in the revision for the real hook's own count.
const SERIAL_SHIFT: int = 20

## The live water's hook (the base hook offers nothing: a village without water).
var real: CrossingHookScript = CrossingHookScript.new()
## `(a: Vector2, b: Vector2) -> bool`: whether a straight line meets water (none: never).
var crosses_water: Callable = Callable()
## The proposal: whether there is one, its two approaches, its walk (m at walk speed, before the weather) and the
## weather's surface pace it is offered at (per mille).
var proposing: bool = false
var end_a: Vector2 = Vector2.ZERO
var end_b: Vector2 = Vector2.ZERO
var walk_m: float = 0.0
var surface_permille: int = 1000
## Whether the last `offer_into` could add the proposal (the router takes at most MAX_CROSSING_PAIRS a plan).
var proposal_offered: bool = false

var _serial: int = 0


func configure(live: CrossingHookScript, water_crossing: Callable) -> void:
	"""Offer what `live` offers; `water_crossing(a, b) -> bool` says whether a straight line meets water."""
	real = live if live != null else CrossingHookScript.new()
	crosses_water = water_crossing


func propose(a: Vector2, b: Vector2, walk_metres: float, permille: int) -> void:
	"""Offer a bridge between approaches `a` and `b`, `walk_metres` long, at surface pace `permille`."""
	proposing = true
	end_a = a
	end_b = b
	walk_m = walk_metres
	surface_permille = maxi(permille, 1)
	_serial += 1


func withdraw() -> void:
	"""Offer no proposal: exactly the live water's crossings."""
	if proposing:
		_serial += 1
	proposing = false


func revision() -> int:
	"""The real hook's revision, moved by every proposal made or withdrawn (see THE CACHE)."""
	return real.revision() + (_serial << SERIAL_SHIFT)


func offers_for(walker: int, from: Vector2, to: Vector2, loaded: bool) -> bool:
	"""What the live water offers this trip -- or, with a proposal, any trip whose straight line meets water."""
	var live: bool = real.offers_for(walker, from, to, loaded)
	return live or (proposing and _meets_water(from, to))


func offer_into(router: RefCounted, walker: int, from: Vector2, to: Vector2, loaded: bool) -> void:
	"""The live water's offer for this trip, then the proposal (see THE SAME OFFER AS THE LIVE ONE)."""
	real.offer_into(router, walker, from, to, loaded)
	proposal_offered = false
	if proposing and _meets_water(from, to):
		var scale: float = float(FULL_PERMILLE) / float(surface_permille)
		proposal_offered = (router as RouterScript).add_crossing(PROPOSAL_ROW, end_a, end_b, walk_m * scale)


func wade_extra_m(a: Vector2, b: Vector2) -> float:
	"""The live water's wading cost."""
	return real.wade_extra_m(a, b)


func ground_y_m(at: Vector2) -> float:
	"""The live water's ground height."""
	return real.ground_y_m(at)


func _meets_water(from: Vector2, to: Vector2) -> bool:
	"""Whether the straight line from -> to meets water (the live water's own test)."""
	return crosses_water.is_valid() and bool(crosses_water.call(from, to))
