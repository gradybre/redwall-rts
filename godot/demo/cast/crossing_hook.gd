extends RefCounted
## What the demo cast asks the water as it plans and walks. Decision 0196 (live demo). Presentation
## only. The water's gameplay (demo/waterplay/water_crossings.gd) extends this; the base answers "no
## water", so a cast built without it plans, walks and stands exactly as before.
##
##   PLANNING   `offers_for` / `offer_into`: the crossings a trip may use -- a finished bridge, a
##              swimmer's link across the stream -- offered to the tunnel router as extra pairs
##              (tunnel_router.gd CROSSINGS). `revision` changes whenever what is offered changes,
##              so the router's mouth-to-mouth cache is dropped with it.
##   CROSSING   `begin_leg` / `step_leg`: a resident on a crossing leg (resident_brain.gd State.CROSS)
##              is moved by the water, not by the brain's walking: along a bridge's deck, or down a
##              bank, across the water and up the far bank. `abandon_leg` forgets one cut short.
##   WALKING    `ground_y_m` and `wade_permille`: on dry ground and on a bank's slope the feet follow
##              the carved ground, and in wading water the pace slows.
##   STANDING   `water_clearance_m`: no spot a resident is sent to stand, work or idle at -- a formation,
##              a job's spot, a deadfall pile, a spoil heap, a step out of a tunnel -- is in the water.
## Untyped `brain` and `router` parameters avoid a preload cycle (the brain preloads the space, which
## preloads this); implementations cast them.

const FULL_PERMILLE: int = 1000


func revision() -> int:
	"""Bumped whenever the crossings on offer change (the base never changes)."""
	return 0


func offers_for(_walker: int, _from: Vector2, _to: Vector2, _loaded: bool) -> bool:
	"""Whether a trip from -> to by resident `_walker` (carrying, when `_loaded`) has any crossing to
	consider. The base has none."""
	return false


func offer_into(_router: RefCounted, _walker: int, _from: Vector2, _to: Vector2, _loaded: bool) -> void:
	"""Offer the router this trip's crossings (tunnel_router.gd `add_crossing`). The base offers none."""
	pass


func begin_leg(_brain: RefCounted, _row: int, _reverse: bool) -> void:
	"""A resident starts across crossing `_row` (from its end b to its end a when `_reverse`)."""
	pass


func step_leg(_brain: RefCounted, _delta: float) -> bool:
	"""Move a resident on its crossing leg by `_delta` demo seconds; true once it stands at the far end.
	The base has no legs to walk, so any leg is over at once."""
	return true


func abandon_leg(_brain: RefCounted) -> void:
	"""Forget a resident's crossing leg, cut short by an emergency (the water's rescue)."""
	pass


func swim_ashore(_brain: RefCounted) -> void:
	"""A resident in the water under a new order swims to the nearest bank connection first (a crossing
	leg of its own). The base never has anyone in the water."""
	pass


func leg_text(_brain: RefCounted) -> String:
	"""What a resident on a crossing leg is doing, in words, for the panel."""
	return "crossing"


func ground_y_m(_at: Vector2) -> float:
	"""The height of the ground (or a wading bed) at `_at`, metres from the datum. The base is flat."""
	return 0.0


func wade_extra_m(_a: Vector2, _b: Vector2) -> float:
	"""How much longer, in metres at walk speed, the walk a -> b takes for the wading water on it (a
	route's cost is its walking time: tunnel_router.gd). The base has no water."""
	return 0.0


func water_clearance_m(_at: Vector2) -> float:
	"""How far `_at` stands from the water's edge, metres (negative in the water). Every spot a resident
	is sent to stand, work or idle at keeps its body clear of it (CastSpace.obstacle_clearance). The base
	has no water."""
	return INF


func wade_permille(_walker: int, _at: Vector2) -> int:
	"""Walking pace at `_at` for resident `_walker`, per mille of its walk (wading is slower)."""
	return FULL_PERMILLE
