extends RefCounted
## The demo's seeded threats, and who shelters from them. Decision 0196 (live demo). Presentation
## only: nobody is hurt, nothing is lost and nothing enters the simulation -- a threat moves the
## demo cast out of harm's way and back.
##
## ---------------------------------------------------------------------------------------
## A THREAT covers a disc for DURATION_USEC of demo time: the STREAM FLOODING its edge by the reed
## beds (west) -- the disc the water query says a flood of it spills over (tunnel_water.gd; the demo
## knows water only through that query) -- or a FIRE at the covered store (east; the village has no
## barn, so the store stands in for one). Which comes next is SEEDED: kind = roll(count) mod 2, an integer hash of the
## event's ordinal and SEED, so every run meets the same sequence. They come on their own on a seeded
## schedule (FIRST_AUTO_USEC, then every AUTO_EVERY_USEC plus a seeded jitter), and the tunnel
## panel's "Test event (demo)" brings the next one at once.
##
## EVACUATION (`plan_escape`). Everyone on the surface inside the disc is sent away: through the
## nearest usable tunnel they fit whose near mouth is closer to them than its far mouth and whose far
## mouth lies outside the disc (by SAFE_MARGIN_M) -- down, through, up, and on to a spot beyond the far
## mouth, away from the threat -- or, with no such tunnel, straight out of the disc on foot. They
## shelter there until it clears, then go back to their own routines (evacuate_task.gd).
##
## All the numbers here are demo values.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const WaterScript := preload("res://demo/tunnel/tunnel_water.gd")

const KIND_FLOOD: int = 0
const KIND_FIRE: int = 1
const KIND_NAMES: Array[String] = ["flood at the stream edge", "fire at the covered store"]
## The fire's disc: the covered store, (x, z) and radius in u.
const FIRE_CENTRE_U: Vector2i = Vector2i(14336, 6349)
const FIRE_RADIUS_U: int = 6144
const DURATION_USEC: int = 40000000
const FIRST_AUTO_USEC: int = 360000000
const AUTO_EVERY_USEC: int = 540000000
const AUTO_JITTER_USEC: int = 120000000
const SEED: int = 5155
## A far mouth is safe this far outside the disc; a shelter stands this far beyond it or the edge.
const SAFE_MARGIN_M: float = 1.0
const SHELTER_M: float = 2.0

const CHANGE_NONE: int = 0
const CHANGE_STARTED: int = 1
const CHANGE_ENDED: int = 2

var active: bool = false
var kind: int = KIND_FLOOD
var left_usec: int = 0
## How many threats have come so far, and demo time until the next one comes on its own.
var count: int = 0
var next_auto_usec: int = FIRST_AUTO_USEC
## Bumped when a threat starts or ends.
var revision: int = 0

var _water: WaterScript = null


func _init(water: WaterScript = null) -> void:
	"""Threats over this water (none: the demo water table)."""
	_water = water if water != null else WaterScript.new()


static func roll(ordinal: int) -> int:
	"""The seeded integer roll for the `ordinal`-th threat (non-negative)."""
	var h := ((ordinal * 2654435761) ^ (SEED * 40503)) & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 2246822519) & 0x7FFFFFFF
	return h ^ (h >> 13)


static func kind_for(ordinal: int) -> int:
	"""KIND_*: what the `ordinal`-th threat is."""
	return roll(ordinal) % 2


func trigger() -> bool:
	"""Bring the next threat now. False (nothing changes) while one is already under way."""
	if active:
		return false
	kind = kind_for(count)
	count += 1
	active = true
	left_usec = DURATION_USEC
	next_auto_usec = AUTO_EVERY_USEC + roll(count + 1000) % AUTO_JITTER_USEC
	revision += 1
	return true


func advance(usec: int) -> int:
	"""Run on by `usec` demo microseconds: CHANGE_STARTED when a threat came on its own, CHANGE_ENDED
	when one cleared, else CHANGE_NONE."""
	if usec <= 0:
		return CHANGE_NONE
	if active:
		left_usec -= usec
		if left_usec > 0:
			return CHANGE_NONE
		active = false
		revision += 1
		return CHANGE_ENDED
	next_auto_usec -= usec
	if next_auto_usec > 0:
		return CHANGE_NONE
	trigger()
	return CHANGE_STARTED


func centre_u() -> Vector2i:
	"""The threatened disc's centre (x, z) in u: where the water spills, or the store."""
	return _water.spill_centre_u() if kind == KIND_FLOOD else FIRE_CENTRE_U


func centre_m() -> Vector2:
	"""The threatened disc's centre (x, z) in metres."""
	return Vector2(Rules.to_m(centre_u().x), Rules.to_m(centre_u().y))


func radius_m() -> float:
	"""The threatened disc's radius in metres."""
	return Rules.to_m(_water.spill_radius_u() if kind == KIND_FLOOD else FIRE_RADIUS_U)


func covers(at: Vector2) -> bool:
	"""Whether a point (x, z metres) lies in the threatened disc while a threat is under way."""
	return active and at.distance_to(centre_m()) < radius_m()


func threat_name() -> String:
	"""The threat under way, in words."""
	return KIND_NAMES[kind]


func shelter_from(at: Vector2) -> Vector2:
	"""A spot straight out of the disc from `at`, SHELTER_M beyond its edge."""
	var away := (at - centre_m()).normalized()
	if away == Vector2.ZERO:
		away = Vector2(0.0, 1.0)
	return centre_m() + away * (radius_m() + SHELTER_M)


func plan_escape(network: NetworkScript, index: int, at: Vector2, out: PackedFloat32Array) -> bool:
	"""The tunnel resident `index` standing at `at` escapes through (see EVACUATION): out[0] slot,
	out[1] 1 when it goes in at the exit, out[2..3] the shelter beyond the far mouth. False when no
	tunnel serves, and it walks out instead."""
	var best := INF
	for slot in Rules.MAX_TUNNELS:
		if not network.is_usable(slot) or not network.fits_tunnel(index, slot, false):
			continue
		for end in 2:
			var near := network.mouth(slot, end == 1)
			var far := network.mouth(slot, end == 0)
			var d := near.distance_to(at)
			if d < best and d < far.distance_to(at) and far.distance_to(centre_m()) > radius_m() + SAFE_MARGIN_M:
				best = d
				var beyond := far + (far - centre_m()).normalized() * SHELTER_M
				out[0] = slot
				out[1] = end
				out[2] = beyond.x
				out[3] = beyond.y
	return best < INF
