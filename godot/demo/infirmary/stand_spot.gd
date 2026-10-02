extends RefCounted
## Where a resident may stand to work at something: the standable, reachable spot nearest it on rings round a target,
## clear of anyone standing (cast_orders.gd `spot_ok`). Decision 0612's rule (demo/stores/stand_spot.gd on the cellar
## branch), copied for the infirmary's builders (decision 0623) so this branch does not depend on that one; merge the
## two when both land. Presentation only.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")

const RING_GAP_M: float = 0.45
const RINGS: int = 4
const RING_SPOTS: int = 12
## Nobody's spots are taken ahead of time (cast_orders.gd `spot_ok`'s `taken`).
const NO_TAKEN: PackedVector2Array = []


static func find_into(cast: DemoCastScript, target: Vector2, first_ring: float, brain: BrainScript,
		found: PackedVector2Array) -> bool:
	"""The nearest such spot to `brain`'s resident on RINGS rings round `target` (the first `first_ring` out), into
	`found[0]`. False when no ring has one."""
	var from: Vector2 = brain.surface_point()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(cast.space(), members)
	for ring: int in RINGS:
		var radius: float = first_ring + RING_GAP_M * ring
		var hit: bool = false
		for k: int in (1 if radius <= 0.0 else RING_SPOTS):
			var spot: Vector2 = target + Vector2.from_angle(TAU * k / RING_SPOTS) * radius
			if hit and spot.distance_squared_to(from) >= found[0].distance_squared_to(from):
				continue
			if CastOrdersScript.spot_ok(cast.space(), spot, brain.radius, cast.bounds(), avoid, NO_TAKEN, from):
				found[0] = spot
				hit = true
		if hit:
			return true
	return false
