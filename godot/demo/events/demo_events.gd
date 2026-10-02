extends RefCounted
## The demo's seeded threats, and who shelters from them. Decision 0196 (live demo). Presentation
## only: nobody is hurt, nothing is lost and nothing enters the simulation -- a threat moves the
## demo cast out of harm's way and back.
##
## ---------------------------------------------------------------------------------------
## A THREAT covers a disc for DURATION_USEC of demo time: the east STREAM FLOODING over its west bank
## at the ford -- the disc the water query says a flood of it spills over (demo/village_water.gd, the
## village's one water adapter over the real water map; the demo knows water only through it) -- or a
## FIRE at the covered store (the village has no barn, so the store stands in for one). Which comes next is SEEDED: kind = roll(count) mod 2, an integer hash of the
## event's ordinal and SEED, so every run meets the same sequence. They come on their own on a seeded
## schedule IN GAME DAYS OF DEMO TIME (decision 0912): the first FIRST_AUTO_DAYS game days into the demo, then
## AUTO_EVERY_DAYS plus a seeded jitter under AUTO_JITTER_DAYS after the last one ENDED (the countdown waits while a
## threat is under way) -- about one every nine game days, where it was nine real
## minutes (about one a game day once decision 0421 made a day ten minutes). The schedule counts the demo time the
## calendar runs on (demo_calendar.gd: a game day is DAY_USEC of it), so pause, 1x, 2x and 4x move both together. The
## tunnel panel's "Test event (demo)" still brings the next one at once. A threat itself still lasts DURATION_USEC:
## the evacuation is walking, in demo seconds.
##
## EVACUATION (`plan_escape`). Everyone on the surface inside the disc is sent away: in at the nearest
## usable mouth of the tunnel network (decision 0208) from which a walk they fit leads to a far mouth
## that is farther from them than the near one and lies outside the disc (by SAFE_MARGIN_M) -- the far
## mouth cheapest to walk to -- down, through, up, and on to a spot beyond the far mouth, away from the
## threat; or, with no such way, straight out of the disc on foot. They shelter there until it clears,
## then go back to their own routines (evacuate_task.gd).
##
## All the numbers here are demo values.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const WaterScript := preload("res://demo/village_water.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const KIND_FLOOD: int = 0
const KIND_FIRE: int = 1
const KIND_NAMES: Array[String] = ["flood at the stream edge", "fire at the covered store"]
## The fire's disc: the covered store, (x, z) and radius in u.
const FIRE_CENTRE_U: Vector2i = Vector2i(14336, 6349)
const FIRE_RADIUS_U: int = 6144
const DURATION_USEC: int = 40000000
## The schedule, in game days (see the header) and the demo microseconds they are: the first on day 6, then every
## 9 days plus up to 2 (the old 6, 9 and 2 minutes, a game day each since decision 0421).
const FIRST_AUTO_DAYS: int = 6
const AUTO_EVERY_DAYS: int = 9
const AUTO_JITTER_DAYS: int = 2
const FIRST_AUTO_USEC: int = FIRST_AUTO_DAYS * CalendarScript.DAY_USEC
const AUTO_EVERY_USEC: int = AUTO_EVERY_DAYS * CalendarScript.DAY_USEC
const AUTO_JITTER_USEC: int = AUTO_JITTER_DAYS * CalendarScript.DAY_USEC
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
	"""Threats over this water (none: the village's water adapter over its authored water)."""
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


func plan_escape(network: GraphScript, index: int, at: Vector2, out: PackedFloat32Array) -> bool:
	"""The way resident `index` standing at `at` escapes through the network (see EVACUATION): out[0] the
	mouth row it goes in at, out[1] the one it comes up at, out[2..3] the shelter beyond. False when no way
	serves, and it walks out instead."""
	var fit_class := network.walker_class(index, false)
	var best := INF
	for near in Rules.MAX_MOUTHS:
		if not network.mouth_usable(near) or network.mouth_at(near).distance_to(at) >= best:
			continue
		var far := _safe_far_mouth(network, fit_class, near, at)
		if far < 0:
			continue
		best = network.mouth_at(near).distance_to(at)
		var far_at := network.mouth_at(far)
		var beyond := far_at + (far_at - centre_m()).normalized() * SHELTER_M
		out[0] = near
		out[1] = far
		out[2] = beyond.x
		out[3] = beyond.y
	return best < INF


func _safe_far_mouth(network: GraphScript, fit_class: int, near: int, at: Vector2) -> int:
	"""The mouth outside the disc, farther from `at` than mouth `near`, cheapest to walk to from `near`
	(-1: none)."""
	var near_d := network.mouth_at(near).distance_to(at)
	var best := -1
	var best_walk := PathsScript.UNREACHED
	for far in Rules.MAX_MOUTHS:
		if far == near or not network.mouth_usable(far):
			continue
		var far_at := network.mouth_at(far)
		if far_at.distance_to(at) <= near_d or far_at.distance_to(centre_m()) <= radius_m() + SAFE_MARGIN_M:
			continue
		var walk := network.paths.dist_u(network, fit_class, near, network.mouth_node[far])
		if walk < best_walk:
			best_walk = walk
			best = far
	return best
