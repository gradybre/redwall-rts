extends RefCounted
## HOW THE WILDLIFE MOVES. Decision 1631 (feature #11). Pure, static, presentation only: where an animal is a time into
## its move, so the view (wildlife_view.gd) only keeps each animal's state and timer and asks here for the pose. Every
## clip in art pass 2 plays IN PLACE except the trout's leap (art_pass2_mapping.md): so a hop's few centimetres and a
## flight's path are moved here. Value types only: nothing is allocated.
##
##   * A HOP (robin 0.15 m, frog 0.3 m) moves the body only in the clip's air frames, AIR_FROM..AIR_TO of the clip,
##     eased, so the feet do not slide on the ground before take-off or after landing.
##   * A ROBIN'S FLIGHT is an arc from one spot to another: straight in plan, rising to `arc_m` at its middle (a sine),
##     at FLY_SPEED_M_S (no shorter than MIN_FLIGHT_S); it flaps while it climbs and glides down the last GLIDE_FROM.
##   * A BUTTERFLY'S FLUTTER is a slow, uneven loop round its spot: two sines out of step in plan, a third in height,
##     each with the animal's own phase, so no two follow the same path.

const AIR_FROM: float = 0.2
const AIR_TO: float = 0.75
const FLY_SPEED_M_S: float = 3.2
const MIN_FLIGHT_S: float = 1.2
## A flight rises this high at its middle, plus this share of its length (demo values: over a resident's head).
const ARC_BASE_M: float = 1.6
const ARC_SHARE: float = 0.12
const GLIDE_FROM: float = 0.6
## The flutter's reach round its spot, its mean height and its rise and fall (metres), and its pace (radians a second).
const FLUTTER_REACH_M: float = 0.9
const FLUTTER_HEIGHT_M: float = 0.75
const FLUTTER_RISE_M: float = 0.3
const FLUTTER_PACE: float = 0.7
## How far ahead a flutter's heading looks (seconds).
const LOOK_AHEAD_S: float = 0.08


static func hop_share(t: float) -> float:
	"""How far along a hop's ground the body is at share `t` (0..1) of the clip: 0 before the air frames, 1 after."""
	return smoothstep(AIR_FROM, AIR_TO, clampf(t, 0.0, 1.0))


static func flight_seconds(from: Vector3, to: Vector3) -> float:
	"""How long a robin's flight between two spots takes (see A ROBIN'S FLIGHT)."""
	return maxf(MIN_FLIGHT_S, Vector2(to.x - from.x, to.z - from.z).length() / FLY_SPEED_M_S)


static func arc_m(from: Vector3, to: Vector3) -> float:
	"""The height a flight between two spots rises to at its middle."""
	return ARC_BASE_M + ARC_SHARE * Vector2(to.x - from.x, to.z - from.z).length()


static func flight_at(from: Vector3, to: Vector3, t: float) -> Vector3:
	"""Where a robin is at share `t` (0..1) of its flight."""
	var s: float = clampf(t, 0.0, 1.0)
	return from.lerp(to, s) + Vector3.UP * (arc_m(from, to) * sin(PI * s))


static func is_gliding(t: float) -> bool:
	"""Whether a flight at share `t` glides (its last stretch) rather than flaps."""
	return t >= GLIDE_FROM


static func flutter_at(centre: Vector3, phase: float, time_s: float) -> Vector3:
	"""Where a butterfly is `time_s` into its flutter round `centre` (see A BUTTERFLY'S FLUTTER)."""
	var w: float = FLUTTER_PACE * time_s + phase
	var x: float = FLUTTER_REACH_M * (cos(w) + 0.35 * sin(2.3 * w + phase))
	var z: float = FLUTTER_REACH_M * sin(0.8 * w + 0.5 * phase)
	var y: float = FLUTTER_HEIGHT_M + FLUTTER_RISE_M * sin(1.7 * w + phase)
	return centre + Vector3(x, y, z)


static func yaw_toward(from: Vector3, to: Vector3, fallback: float) -> float:
	"""The yaw that turns a model facing +Z from `from` toward `to` (`fallback` when they meet in plan)."""
	var d := Vector2(to.x - from.x, to.z - from.z)
	return atan2(d.x, d.y) if d.length_squared() > 1e-8 else fallback


static func flutter_yaw(centre: Vector3, phase: float, time_s: float) -> float:
	"""A butterfly's heading along its flutter now."""
	return yaw_toward(flutter_at(centre, phase, time_s), flutter_at(centre, phase, time_s + LOOK_AHEAD_S), 0.0)
