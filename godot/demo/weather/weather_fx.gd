extends Node3D
## THE LIVELIER WEATHER: a storm's lightning, its brief smoulder, the storm's work factor and the event notices.
## Decision 1632 (feature #34, Brendan 2026-10-01; the effects of art pass 3, decision 0971). Presentation only.
##
## LIGHTNING. While a §5.10 heavy rain/storm day is raining (`is_storming`), lightning strikes every STRIKE_GAP_S of demo
## time, near where the camera looks (within STRIKE_REACH_M of the view's focus), so the player sees it. WHERE IT MAY
## STRIKE (Q-D15, built as its recommended option (a), a PROPOSAL in decision 1632): a tree, or open ground at least
## BUILDING_CLEAR_M from every building and off the water -- never a building -- and never within SAFE_M of a resident on
## the surface. The storm hurts nobody and damages nothing: GDD §5.9 has "no additional random disaster, structure fire"
## in release 1.
##
## THE SMOULDER (PROPOSAL, decision 1632). A strike on a tree leaves a small flare at its foot (fire_fx.gd, SMOULDER_M
## across) that catches, burns SMOULDER_BURN_S and dies in the rain, smoking away -- about 13 demo seconds in all. No fire
## spreads, nothing burns down, nothing is written. Two fires are pooled (FIRES: 2 x 54 particles, outside the warren's 200, as art_pass3_mapping.md asks); a
## strike while both are busy leaves none.
##
## PHOTOSENSITIVITY (WCAG 2.3.1). The bolt's flash runs in REAL time whatever the game's speed (at 4x a demo-time flash
## would flicker four times as fast), and strikes are at least MIN_REAL_GAP_S seconds of running real time apart -- one
## strike (its two return strokes, 0.6 s) in any three seconds, at most two flashes a second (lightning_fx.gd's own floor
## is 1.5 s of its clock); paused time does not count toward the gap. Paused, a strike holds still. With
## reduced motion (demo_motion.gd) each strike is one soft swell (lightning_fx.gd `set_reduced`) and the fires hold
## their light steady.
##
## THE STORM'S WORK FACTOR (storm_pace.gd) is added to the village's one work pace here, once.
##
## THE NOTICES (weather_events.gd `follow`): the village is told when a §5.10 event begins -- what it does, by its
## numbers -- and when it is over.
##
## Everything is built in `configure`: the bolt meshes, the fires, the strike targets. A frame allocates nothing.

const LightningScript := preload("res://demo/fx/lightning_fx.gd")
const FireScript := preload("res://demo/fx/fire_fx.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const EventsScript := preload("res://demo/weather/weather_events.gd")
const StormPaceScript := preload("res://demo/weather/storm_pace.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WeirViewScript := preload("res://demo/water/weir_gate_view.gd")
const OrchardScript := preload("res://demo/orchard/demo_orchard.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")

## Demo seconds between strikes (min, max; a game hour is 25 demo seconds at 1x).
const STRIKE_GAP_S: Vector2 = Vector2(5.0, 12.0)
const MIN_REAL_GAP_S: float = 3.0
const STRIKE_REACH_M: float = 16.0
const SAFE_M: float = 6.0
const BUILDING_CLEAR_M: float = 6.0
## The open-ground targets: a grid of this step over this half-extent (m) round the village's centre.
const GROUND_STEP_M: float = 5.0
const GROUND_HALF_M: float = 35.0
## A bolt comes down from this high, leaning by up to this much (m).
const SKY_M: float = 38.0
const LEAN_M: float = 6.0
const FIRES: int = 2
const SMOULDER_M: float = 0.8
const SMOULDER_BURN_S: float = 0.5
const SEED: int = 1632

var lightning: LightningScript = null
var pace: StormPaceScript = StormPaceScript.new()
var events: EventsScript = EventsScript.new()
## Strikes landed so far, and where the last one landed (for checks).
var strikes: int = 0
var last_target: int = -1

var _weather: WeatherScript = null
var _clock: DemoClockScript = null
var _notices: NoticesScript = null
var _brains: Array[BrainScript] = []
var _fires: Array[FireScript] = []
var _targets: PackedVector3Array = PackedVector3Array()
var _is_tree: PackedByteArray = PackedByteArray()
var _dice: RandomNumberGenerator = RandomNumberGenerator.new()
var _gap_s: float = 0.0
var _real_since_s: float = 1e6
var _reduced: bool = false
## The speeds last handed to the bolt and the fires (written only on a change: `set_speed` builds an array).
var _bolt_speed: float = -1.0
var _fire_speed: float = -1.0
## `() -> PackedVector3Array`: every standing structure's circle now (x, radius, z) -- the player's buildings too
## (cast_space.gd `structure_circles`); and `(t: int) -> int`: tree `t`'s state in the woods (forest_stand.gd STATE_*).
## Unbound: none, and every tree stands.
var _structures: Callable = Callable()
var _tree_state: Callable = Callable()


func wire(services: ServicesScript, cast: DemoCastScript, world: DemoWorldScript, tree_state: Callable) -> void:
	"""THE VILLAGE'S HOOK (demo_village.gd), once this node is in the tree: the village's weather, the cast's clock,
	the notice feed, the world's trees (`tree_state`: the woods' stand), every building and the real water map; the
	player's structures as they stand; the storm factor on the work pace."""
	var brains: Array[BrainScript] = []
	for i: int in cast.actor_count():
		brains.append((cast.actor(i) as DemoActorScript).brain)
	configure(services.weather, cast.clock, services.notices, brains)
	set_targets(trees_of(world), buildings_of(world), services.water.map())
	bind_sites(cast.space().structure_circles, tree_state)
	services.work_pace.add_factor(StormPaceScript.FACTOR_NAME, pace.permille)


static func buildings_of(world: DemoWorldScript) -> Array[Vector3]:
	"""Every built thing lightning keeps clear of (x, radius, z): the village's buildings, the water-side buildings
	(the mill, the boathouse, the shelter, the weir: water_dressing.gd), the leat head and the orchard's stands."""
	var out: Array[Vector3] = world.building_obstacles()
	for circle: Vector3 in WaterDressing.footprint_circles():
		out.append(DemoWorldScript.public_circle(circle))
	out.append_array(WeirViewScript.land_obstacles())
	out.append_array(OrchardScript.land_obstacles())
	return out


func bind_sites(structures: Callable, tree_state: Callable) -> void:
	"""What changes while the village runs: the standing structures now and each tree's state (see `_structures`)."""
	_structures = structures
	_tree_state = tree_state


func configure(weather: WeatherScript, clock: DemoClockScript, notices: NoticesScript, brains: Array[BrainScript]) -> void:
	"""The weather this follows, its clock, the feed it tells (null: none) and the residents it keeps clear of; builds
	the bolt and the pooled fires."""
	name = "WeatherFx"
	_weather = weather
	_clock = clock
	_notices = notices
	_brains = brains
	_dice.seed = SEED
	pace.bind(weather, brains)
	lightning = LightningScript.new()
	add_child(lightning)
	lightning.configure()
	for k: int in FIRES:
		var fire := FireScript.new()
		add_child(fire)
		fire.configure()
		_fires.append(fire)
	_gap_s = _dice.randf_range(STRIKE_GAP_S.x, STRIKE_GAP_S.y)
	_follow_reduced(true)


static func trees_of(world: DemoWorldScript) -> PackedVector3Array:
	"""Every tree's foot on the ground (the world's placements, the woods' included)."""
	var out := PackedVector3Array()
	for p: Dictionary in world.trees():
		var at: Vector2 = p["at"]
		out.append(Vector3(at.x, 0.0, at.y))
	return out


func set_targets(trees: PackedVector3Array, buildings: Array[Vector3], map: WaterMapScript) -> void:
	"""Where lightning may strike (see WHERE IT MAY STRIKE): every tree, then open ground on a grid -- dry, and at
	least BUILDING_CLEAR_M from every building circle (`buildings` as (x, radius, z), demo_world.gd's public form)."""
	_targets = trees.duplicate()
	_is_tree.resize(trees.size())
	_is_tree.fill(1)
	var steps: int = int(GROUND_HALF_M / GROUND_STEP_M)
	for gx: int in range(-steps, steps + 1):
		for gz: int in range(-steps, steps + 1):
			var at := Vector3(gx * GROUND_STEP_M, 0.0, gz * GROUND_STEP_M)
			if is_open_ground(at, buildings, map):
				_targets.append(at)
				_is_tree.append(0)


static func is_open_ground(at: Vector3, buildings: Array[Vector3], map: WaterMapScript) -> bool:
	"""Whether `at` is dry and BUILDING_CLEAR_M clear of every building's circle."""
	if map != null and map.is_near_water(Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.z))):
		return false
	for c: Vector3 in buildings:
		if Vector2(at.x - c.x, at.z - c.z).length() < c.y + BUILDING_CLEAR_M:
			return false
	return true


func _process(delta: float) -> void:
	"""Follow the event (its notices), the reduced-motion setting and the clock; strike while it storms."""
	if _weather == null:
		return
	events.follow(_weather.event(), _notices, _weather.season())
	_follow_reduced(false)
	var running: bool = _clock != null and _clock.frame_usec > 0
	_follow_speeds(running)
	if not running:
		return
	_real_since_s += delta
	if not is_storming():
		return
	_gap_s -= _clock.delta_s()
	if _gap_s <= 0.0 and _real_since_s >= MIN_REAL_GAP_S:
		strike_near(view_focus())


func _follow_speeds(running: bool) -> void:
	"""The bolt's flash in real time (1, or 0 paused) and the fires on the demo clock, handed over only on a change."""
	var bolt: float = 1.0 if running else 0.0
	if bolt != _bolt_speed:
		_bolt_speed = bolt
		lightning.set_speed(bolt)
	var flames: float = float(_clock.speed) if running else 0.0
	if flames != _fire_speed:
		_fire_speed = flames
		for fire: FireScript in _fires:
			fire.set_speed(flames)


func _follow_reduced(force: bool) -> void:
	"""Hand the reduced-motion setting to the bolt and the fires when it changes."""
	if DemoMotion.reduced == _reduced and not force:
		return
	_reduced = DemoMotion.reduced
	lightning.set_reduced(_reduced)
	for fire: FireScript in _fires:
		fire.set_reduced(_reduced)


func is_storming() -> bool:
	"""Whether it storms now: a §5.10 heavy rain/storm day, and raining this hour."""
	return _weather.event() == WeatherCore.EVENT_HEAVY_RAIN and _weather.condition() == WeatherScript.COND_RAIN


func view_focus() -> Vector3:
	"""Where the camera looks at the ground (the village's middle without a camera)."""
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return Vector3.ZERO
	var ahead: Vector3 = -camera.global_basis.z
	var t: float = -camera.global_position.y / ahead.y if ahead.y < -0.01 else 0.0
	return camera.global_position + ahead * t


func strike_near(focus: Vector3) -> int:
	"""Strike the first allowed target within STRIKE_REACH_M of `focus`, from a seeded start; its index, or -1 (none
	allowed -- the next try waits STRIKE_GAP_S.x -- or the bolt refused: too soon after the last)."""
	var n: int = _targets.size()
	var built: PackedVector3Array = _structures.call() if _structures.is_valid() else PackedVector3Array()
	var start: int = _dice.randi_range(0, maxi(n - 1, 0))
	for k: int in n:
		var j: int = (start + k) % n
		if Vector2(_targets[j].x - focus.x, _targets[j].z - focus.z).length() <= STRIKE_REACH_M and is_safe(j, built):
			return j if strike(j) else -1
	_gap_s = STRIKE_GAP_S.x
	return -1


func is_safe(j: int, built: PackedVector3Array = PackedVector3Array()) -> bool:
	"""Whether target `j` may be struck now: SAFE_M clear of every resident on the surface; a tree still standing (not
	felled to a stump or cleared); open ground BUILDING_CLEAR_M clear of every structure in `built` (x, radius, z)."""
	var at := Vector2(_targets[j].x, _targets[j].z)
	for b: BrainScript in _brains:
		if not b.underground and not b.indoors and at.distance_squared_to(b.position) < SAFE_M * SAFE_M:
			return false
	if _is_tree[j] == 1:
		return is_standing(j)
	for c: Vector3 in built:
		if at.distance_to(Vector2(c.x, c.z)) < c.y + BUILDING_CLEAR_M:
			return false
	return true


func is_standing(t: int) -> bool:
	"""Whether tree `t` still stands (mature or young) in the woods (true unbound)."""
	if not _tree_state.is_valid():
		return true
	var state: int = int(_tree_state.call(t))
	return state == StandScript.STATE_MATURE or state == StandScript.STATE_YOUNG


func strike(j: int) -> bool:
	"""Strike target `j` now (a tree's foot left smouldering); false when the bolt refused (see PHOTOSENSITIVITY)."""
	var ground: Vector3 = _targets[j]
	var lean := Vector3(_dice.randf_range(-LEAN_M, LEAN_M), SKY_M, _dice.randf_range(-LEAN_M, LEAN_M))
	if not lightning.strike(ground + lean, ground):
		return false
	strikes += 1
	last_target = j
	_gap_s = _dice.randf_range(STRIKE_GAP_S.x, STRIKE_GAP_S.y)
	_real_since_s = 0.0
	if _is_tree[j] == 1:
		_smoulder(ground)
	return true


func _smoulder(at: Vector3) -> void:
	"""A brief smoulder at a struck tree's foot that the rain puts out after SMOULDER_BURN_S (see THE SMOULDER); none if
	both fires are busy."""
	for fire: FireScript in _fires:
		if fire.is_idle():
			fire.ignite(at, SMOULDER_M, SMOULDER_BURN_S)
			return


func target_count() -> int:
	"""How many targets lightning may strike."""
	return _targets.size()


func target(j: int) -> Vector3:
	"""Target `j`'s ground point."""
	return _targets[j]


func is_tree(j: int) -> bool:
	"""Whether target `j` is a tree."""
	return _is_tree[j] == 1


func pooled_fire(k: int) -> FireScript:
	"""Pooled fire `k`."""
	return _fires[k]


func fire_count() -> int:
	"""How many fires are pooled."""
	return _fires.size()
