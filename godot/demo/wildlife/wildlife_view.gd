extends Node3D
## THE VILLAGE'S WILDLIFE: robins on the lawn, butterflies over the beds, frogs on the pond's bank, trout leaping.
## Decision 1631 (feature #11, Brendan 2026-10-01 "NEW 2"; art pass 2, decision 0951; sizes DEC-047). Presentation only.
##
## NO FAUNA SIMULATION (REQ-SET-059/065; the fauna contract's "no active fauna"). What shows is wildlife_rules.gd's
## answer for the hour, the season and the weather the village already reads (demo_weather.gd); where, its authored
## spots (wildlife_spots.gd); how it moves, wildlife_motion.gd. Nothing is written anywhere: no row, no notice, no save.
## The animals are not selectable and say nothing; a robin is a wild bird, not a resident (wildlife_rules.gd).
##
## POOLED. Every body is made in `configure` (wildlife_bodies.gd: Rules.MAX_COUNT of each kind, and each robin's flight
## body) and only shown, hidden and moved after: per frame this allocates nothing -- a state, a timer and a pose per
## animal in packed columns, a clip started only when it changes. A hidden body's AnimationPlayer is switched off.
##
## EACH FRAME, on the demo clock (`delta_s`; paused, everything holds and the clips stop):
##   * when the hour, the season, the condition or the reduced-motion setting changed, the first N of each kind's pool
##     are shown (wildlife_rules.gd `count_of`) and the rest hidden;
##   * a ROBIN rests, pecks, hops or flies to another free spot -- and takes wing at once when a resident on the surface
##     comes within FLUSH_M (not in rain or snow: `may_fly`);
##   * a BUTTERFLY flutters round its spot and now and then settles (drops to REST_Y, rests, rises again);
##   * a FROG sits facing the water and now and then hops along the bank and back;
##   * a TROUT waits under the surface and leaps (its clip carries it 1.2 m) every LEAP_GAP_S.
##
## REDUCED MOTION (demo_motion.gd, decision 0471): nothing crosses the screen -- robins neither hop nor fly (nor flush),
## butterflies rest, frogs sit, trout do not leap. Each still breathes in its idle clip.
##
## THE BOOT PREWARM (demo_prewarm.gd): `begin_prewarm` shows every body before the camera for a few frames so its
## pipelines compile while the opening pause holds; `end_prewarm` puts them back.

const Rules := preload("res://demo/wildlife/wildlife_rules.gd")
const Spots := preload("res://demo/wildlife/wildlife_spots.gd")
const Motion := preload("res://demo/wildlife/wildlife_motion.gd")
const Bodies := preload("res://demo/wildlife/wildlife_bodies.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const PrewarmScript := preload("res://demo/demo_prewarm.gd")

const ST_HIDDEN: int = 0
const ST_REST: int = 1
const ST_HOP: int = 2
const ST_PECK: int = 3
const ST_FLY: int = 4
const ST_LEAP: int = 5
const STATE_NAMES: Array[String] = ["hidden", "rest", "hop", "peck", "fly", "leap"]
const CLIPS: Array[StringName] = [&"idle", &"hop", &"peck", &"flap", &"glide", &"rest", &"leap"]
const CLIP_IDLE: int = 0
const CLIP_HOP: int = 1
const CLIP_PECK: int = 2
const CLIP_FLAP: int = 3
const CLIP_GLIDE: int = 4
const CLIP_REST: int = 5
const CLIP_LEAP: int = 6
const NO_CLIP: int = -1
## Per kind (Rules order): a hop's length and time (the clip's), and how long it rests between moves (min, max s).
const HOP_M: PackedFloat32Array = [0.15, 0.0, 0.3, 0.0]
const HOP_S: PackedFloat32Array = [0.5, 0.0, 0.7, 0.0]
const REST_S: Array[Vector2] = [Vector2(1.5, 4.0), Vector2(3.0, 7.0), Vector2(3.0, 9.0), Vector2(6.0, 16.0)]
const PECK_S: float = 1.0
const LEAP_S: float = 1.43
## The trout's leap travels this far along its heading (its clip's own travel).
const LEAP_TRAVEL_M: float = 1.2
## A butterfly flutters this long between rests (min, max s), and settles at this height (on a plant's top).
const FLUTTER_S: Vector2 = Vector2(6.0, 14.0)
const REST_Y: float = 0.45
## A butterfly takes this long to drop to its rest and rise from it (s).
const SETTLE_S: float = 0.6
## A robin takes wing when a resident on the surface comes this close (m).
const FLUSH_M: float = 1.6
## A robin at rest chooses its next move by a roll: under HOP_ROLL a hop, under PECK_ROLL a peck, else a flight.
const HOP_ROLL: float = 0.4
const PECK_ROLL: float = 0.8
## A robin hops back toward its spot once this far from it (m), else turns up to this much (radians) and hops on.
const HOME_REACH_M: float = 0.5
const HOP_TURN: float = 1.2
const SEED: int = 1631
## A key of the weather's hour (see EACH FRAME): season x HOURS + hour, its condition and the setting folded in.
const HOURS: int = 24
const CONDITIONS: int = 4
## Frames the boot prewarm draws every body for (demo_village.gd's COVER_PREWARM_FRAMES).
const PREWARM_FRAMES: int = 2

var _weather: WeatherScript = null
var _clock: DemoClockScript = null
var _brains: Array[BrainScript] = []
var _bodies: Bodies = Bodies.new()
var _dice: RandomNumberGenerator = RandomNumberGenerator.new()
## Per kind: its spots and its first row in the pool.
var _spots: Array[PackedVector3Array] = []
var _first: PackedInt32Array = PackedInt32Array()
var _shown: PackedInt32Array = PackedInt32Array()
## Per animal (the pool's rows): its kind, state, spot, time in its state and that state's length, its move's two ends,
## its yaw, its flutter phase and age, its clip, its body and players, and (robins) its flight body and player.
var _kind: PackedInt32Array = PackedInt32Array()
var _state: PackedInt32Array = PackedInt32Array()
var _spot: PackedInt32Array = PackedInt32Array()
var _t: PackedFloat32Array = PackedFloat32Array()
var _dur: PackedFloat32Array = PackedFloat32Array()
var _from: PackedVector3Array = PackedVector3Array()
var _to: PackedVector3Array = PackedVector3Array()
var _yaw: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _clip: PackedInt32Array = PackedInt32Array()
var _body: Array[Node3D] = []
var _player: Array[AnimationPlayer] = []
var _flight: Array[Node3D] = []
var _flight_player: Array[AnimationPlayer] = []
var _key_seen: int = -1
var _reduced: bool = false
var _anim_speed: float = -1.0
var _prewarming: bool = false


func wire(services: ServicesScript, cast: DemoCastScript, prewarm: PrewarmScript) -> void:
	"""THE VILLAGE'S HOOK (demo_village.gd), once this view is in the tree: the village's weather, the cast's clock and
	the real water map; flushed by the cast's residents; its bodies drawn once in the boot prewarm (null: none)."""
	var brains: Array[BrainScript] = []
	for i: int in cast.actor_count():
		brains.append((cast.actor(i) as DemoActorScript).brain)
	configure(services.weather, cast.clock, services.water.map(), brains)
	if prewarm != null:
		prewarm.add_frame_step("wildlife", PREWARM_FRAMES, begin_prewarm, end_prewarm)


func configure(weather: WeatherScript, clock: DemoClockScript, map: WaterMapScript, brains: Array[BrainScript]) -> void:
	"""The wildlife under this weather and clock, its pond spots measured on `map`, flushed by these residents' brains
	(none: never flushed). Builds every pooled body (see POOLED)."""
	name = "Wildlife"
	_weather = weather
	_clock = clock
	_brains = brains
	_dice.seed = SEED
	_spots = [Spots.robin_spots(), Spots.butterfly_spots(), Spots.frog_spots(map), Spots.trout_spots(map)]
	for kind: int in Rules.KINDS:
		_first.append(_kind.size())
		_shown.append(0)
		for k: int in mini(Rules.MAX_COUNT[kind], _spots[kind].size()):
			_add_animal(kind)
	_reduced = DemoMotion.reduced
	refresh(true)


func _add_animal(kind: int) -> void:
	"""One pooled animal of `kind`: its body (and a robin's flight body) made and added, hidden."""
	_kind.append(kind)
	_state.append(ST_HIDDEN)
	_spot.append(-1)
	_clip.append(NO_CLIP)
	_t.append(0.0)
	_dur.append(0.0)
	_yaw.append(0.0)
	_age.append(0.0)
	_phase.append(_dice.randf_range(0.0, TAU))
	_from.append(Vector3.ZERO)
	_to.append(Vector3.ZERO)
	var body: Node3D = _bodies.make(Bodies.KEYS[kind], kind, kind != Rules.BUTTERFLY)
	add_child(body)
	_body.append(body)
	_player.append(Bodies.player_of(body))
	var flight: Node3D = _bodies.make(Bodies.FLIGHT_KEY, kind, true) if kind == Rules.ROBIN else null
	if flight != null:
		add_child(flight)
	_flight.append(flight)
	_flight_player.append(Bodies.player_of(flight) if flight != null else null)


func _process(_delta: float) -> void:
	"""See EACH FRAME."""
	if _weather == null or _prewarming:
		return
	refresh(false)
	_follow_speed()
	var dt: float = _clock.delta_s() if _clock != null else 0.0
	if dt > 0.0:
		for i: int in _kind.size():
			if _state[i] != ST_HIDDEN:
				_step(i, dt)


func hour_key() -> int:
	"""The key `refresh` compares (see EACH FRAME)."""
	var key: int = (_weather.season() * HOURS + _weather.hour()) * CONDITIONS + _weather.condition()
	key = key * 2 + (1 if _weather.temperature_tenths() >= Rules.FLY_TENTHS else 0)
	return key * 2 + (1 if DemoMotion.reduced else 0)


func refresh(force: bool) -> bool:
	"""Show the first N of each kind for this hour and weather (see EACH FRAME); true when anything was redone."""
	var key: int = hour_key()
	if key == _key_seen and not force:
		return false
	_key_seen = key
	var restart: bool = _reduced != DemoMotion.reduced or force
	_reduced = DemoMotion.reduced
	for kind: int in Rules.KINDS:
		var want: int = mini(wanted(kind), pool_size(kind))
		_shown[kind] = want
		for k: int in pool_size(kind):
			_show(_first[kind] + k, k < want, restart)
	return true


func wanted(kind: int) -> int:
	"""How many of `kind` the rules show this hour (before the pool's size)."""
	return Rules.count_of(kind, _weather.season(), _weather.hour(), _weather.condition(), _weather.temperature_tenths())


func _show(i: int, on: bool, restart: bool) -> void:
	"""Show animal `i` (starting it at a free spot, or restarting it under a new setting) or hide it."""
	var hidden: bool = _spot[i] < 0
	if on and (hidden or restart):
		_start(i)
	elif not on and not hidden:
		_hide(i)


func _start(i: int) -> void:
	"""Animal `i` at a free spot of its kind, at rest (a trout under the water), its body shown."""
	var kind: int = _kind[i]
	_spot[i] = -1
	_spot[i] = _free_spot(kind, _dice.randi_range(0, _spots[kind].size() - 1))
	var at: Vector3 = _spots[kind][_spot[i]]
	_from[i] = at
	_to[i] = at
	_yaw[i] = _home_yaw(i)
	_set_flying(i, false)
	_rest(i)
	_pose(i, _spot_pose(i), _yaw[i])
	if kind == Rules.BUTTERFLY and not _reduced:
		_flutter(i)
		_pose(i, Motion.flutter_at(at, _phase[i], _age[i]), _yaw[i])


func _hide(i: int) -> void:
	"""Animal `i` gone: its bodies hidden, its players off, its spot freed."""
	_state[i] = ST_HIDDEN
	_spot[i] = -1
	_clip[i] = NO_CLIP
	_body_on(_body[i], _player[i], false)
	if _flight[i] != null:
		_body_on(_flight[i], _flight_player[i], false)


static func _body_on(body: Node3D, player: AnimationPlayer, on: bool) -> void:
	"""Show or hide one body, its AnimationPlayer running only while shown."""
	body.visible = on
	if player != null:
		player.active = on


func _free_spot(kind: int, from: int) -> int:
	"""The first spot of `kind` from `from` (wrapping) no other animal of the kind holds."""
	var n: int = _spots[kind].size()
	for step: int in n:
		var s: int = (from + step) % n
		if not _spot_taken(kind, s):
			return s
	return from % n


func _spot_taken(kind: int, s: int) -> bool:
	"""Whether another shown animal of `kind` holds spot `s`."""
	for k: int in pool_size(kind):
		if _spot[_first[kind] + k] == s:
			return true
	return false


func _home_yaw(i: int) -> float:
	"""The yaw an animal takes at its spot: a frog faces the water, a trout leaps along its heading, a robin and a
	butterfly face a seeded way."""
	var at: Vector3 = _spots[_kind[i]][_spot[i]]
	match _kind[i]:
		Rules.FROG:
			return Motion.yaw_toward(at, Spots.pond_middle(), 0.0)
		Rules.TROUT:
			var heading: Vector2 = Spots.heading_at(at)
			return atan2(heading.x, heading.y)
	return _phase[i]


func _spot_pose(i: int) -> Vector3:
	"""Where animal `i` stands at rest: its spot (a butterfly on its plant, at REST_Y)."""
	var at: Vector3 = _spots[_kind[i]][_spot[i]]
	return at + Vector3.UP * REST_Y if _kind[i] == Rules.BUTTERFLY else at


func _rest(i: int) -> void:
	"""Animal `i` at rest for its kind's REST_S (a trout hidden under the surface)."""
	var span: Vector2 = REST_S[_kind[i]]
	_enter(i, ST_REST, _dice.randf_range(span.x, span.y))
	var trout: bool = _kind[i] == Rules.TROUT
	_body_on(_body[i], _player[i], not trout)
	_play(i, CLIP_REST if _kind[i] == Rules.BUTTERFLY else CLIP_IDLE)


func _enter(i: int, state: int, seconds: float) -> void:
	"""Animal `i` into `state` for `seconds`."""
	_state[i] = state
	_t[i] = 0.0
	_dur[i] = seconds


func _play(i: int, clip: int) -> void:
	"""Start clip `clip` on animal `i`'s shown body (only on a change; a stand-in has none)."""
	if _clip[i] == clip:
		return
	_clip[i] = clip
	var player: AnimationPlayer = _flight_player[i] if _on_wing(i) else _player[i]
	if player != null and player.has_animation(CLIPS[clip]):
		player.play(CLIPS[clip])


func _on_wing(i: int) -> bool:
	"""Whether animal `i` shows its flight body: a robin flying (a butterfly flutters in its one body)."""
	return _state[i] == ST_FLY and _flight[i] != null


func _pose(i: int, at: Vector3, yaw: float) -> void:
	"""Put animal `i`'s shown body at `at`, turned to `yaw`."""
	var body: Node3D = _flight[i] if _on_wing(i) else _body[i]
	body.transform = Transform3D(Basis(Vector3.UP, yaw), at)


func _follow_speed() -> void:
	"""The clips run at the demo clock's speed (0 paused); only written on a change."""
	var speed: float = float(_clock.speed) if _clock != null and _clock.frame_usec > 0 else 0.0
	if is_equal_approx(speed, _anim_speed):
		return
	_anim_speed = speed
	for players: Array[AnimationPlayer] in [_player, _flight_player]:
		for player: AnimationPlayer in players:
			if player != null:
				player.speed_scale = speed


func _step(i: int, dt: float) -> void:
	"""Advance animal `i` by `dt` demo seconds."""
	_t[i] += dt
	match _kind[i]:
		Rules.ROBIN:
			_step_robin(i)
		Rules.BUTTERFLY:
			_step_butterfly(i, dt)
		Rules.FROG:
			_step_frog(i)
		Rules.TROUT:
			_step_trout(i)


# --- the robin ----------------------------------------------------------------------------------------

func _step_robin(i: int) -> void:
	"""Rest, peck, hop or fly (see EACH FRAME)."""
	match _state[i]:
		ST_REST, ST_PECK:
			if _may_take_wing() and is_flushed(i):
				_fly(i)
			elif _t[i] >= _dur[i]:
				_robin_next(i)
		ST_HOP:
			_pose(i, _from[i].lerp(_to[i], Motion.hop_share(_t[i] / _dur[i])), _yaw[i])
			if _t[i] >= _dur[i]:
				_from[i] = _to[i]
				_rest(i)
		ST_FLY:
			var share: float = _t[i] / _dur[i]
			_play(i, CLIP_GLIDE if Motion.is_gliding(share) else CLIP_FLAP)
			_pose(i, Motion.flight_at(_from[i], _to[i], share), _yaw[i])
			if _t[i] >= _dur[i]:
				_land(i)


func _may_take_wing() -> bool:
	"""Whether robins fly now: not with reduced motion, not in rain or snow."""
	return not _reduced and Rules.may_fly(_weather.condition())


func is_flushed(i: int) -> bool:
	"""Whether a resident on the surface stands within FLUSH_M of animal `i`."""
	var at := Vector2(_from[i].x, _from[i].z)
	for b: BrainScript in _brains:
		if not b.underground and not b.indoors and at.distance_squared_to(b.position) < FLUSH_M * FLUSH_M:
			return true
	return false


func _robin_next(i: int) -> void:
	"""A rested robin's next move, by a roll: a hop on, a peck, or a flight to another spot (see HOP_ROLL)."""
	var roll: float = _dice.randf()
	if roll < HOP_ROLL and not _reduced:
		_hop(i, _hop_way(i))
	elif roll < PECK_ROLL:
		_enter(i, ST_PECK, PECK_S)
		_clip[i] = NO_CLIP
		_play(i, CLIP_PECK)
	elif _may_take_wing():
		_fly(i)
	else:
		_rest(i)


func _hop_way(i: int) -> Vector3:
	"""Which way a robin hops: back toward its spot once it has strayed HOME_REACH_M, else a turn of up to HOP_TURN
	either side of where it faces."""
	var home: Vector3 = _spots[_kind[i]][_spot[i]]
	if Vector2(home.x - _from[i].x, home.z - _from[i].z).length() > HOME_REACH_M:
		return home - _from[i]
	var turn: float = _yaw[i] + _dice.randf_range(-HOP_TURN, HOP_TURN)
	return Vector3(sin(turn), 0.0, cos(turn))


func _hop(i: int, ahead: Vector3) -> void:
	"""A hop of the kind's HOP_M along `ahead` (in plan), over its HOP_S."""
	_to[i] = _from[i] + ahead.normalized() * HOP_M[_kind[i]]
	_yaw[i] = Motion.yaw_toward(_from[i], _to[i], _yaw[i])
	_enter(i, ST_HOP, HOP_S[_kind[i]])
	_play(i, CLIP_HOP)


func _fly(i: int) -> void:
	"""Take wing from where the robin is to another free spot."""
	var kind: int = _kind[i]
	var held: int = _spot[i]
	_spot[i] = -1
	_spot[i] = _free_spot(kind, held + 1 + _dice.randi_range(0, _spots[kind].size() - 2))
	_to[i] = _spots[kind][_spot[i]]
	_yaw[i] = Motion.yaw_toward(_from[i], _to[i], _yaw[i])
	_set_flying(i, true)
	_enter(i, ST_FLY, Motion.flight_seconds(_from[i], _to[i]))
	_play(i, CLIP_FLAP)
	_pose(i, _from[i], _yaw[i])


func _land(i: int) -> void:
	"""Down at the flight's end: the perched body back, at rest."""
	_from[i] = _to[i]
	_set_flying(i, false)
	_rest(i)
	_pose(i, _from[i], _yaw[i])


func _set_flying(i: int, on: bool) -> void:
	"""Swap a robin's perched and flight bodies (others have no flight body)."""
	if _flight[i] == null:
		return
	_body_on(_flight[i], _flight_player[i], on)
	_body_on(_body[i], _player[i], not on)
	_clip[i] = NO_CLIP
	_state[i] = ST_FLY if on else ST_REST


# --- the butterfly, the frog and the trout ------------------------------------------------------------

func _step_butterfly(i: int, dt: float) -> void:
	"""Flutter round its spot, settle, rest, rise (see EACH FRAME)."""
	var centre: Vector3 = _spots[Rules.BUTTERFLY][_spot[i]]
	if _state[i] == ST_FLY:
		_age[i] += dt
		_yaw[i] = Motion.flutter_yaw(centre, _phase[i], _age[i])
		_pose(i, Motion.flutter_at(centre, _phase[i], _age[i]), _yaw[i])
		if _t[i] >= _dur[i]:
			_rest(i)
		return
	if _reduced:
		_pose(i, _spot_pose(i), _yaw[i])
		return
	var air: Vector3 = Motion.flutter_at(centre, _phase[i], _age[i])
	var settle: float = clampf(minf(_t[i], maxf(_dur[i] - _t[i], 0.0)) / SETTLE_S, 0.0, 1.0)
	_pose(i, Vector3(air.x, lerpf(air.y, REST_Y, smoothstep(0.0, 1.0, settle)), air.z), _yaw[i])
	if _t[i] >= _dur[i]:
		_flutter(i)


func _flutter(i: int) -> void:
	"""A butterfly takes off on its loop for a FLUTTER_S."""
	_enter(i, ST_FLY, _dice.randf_range(FLUTTER_S.x, FLUTTER_S.y))
	_clip[i] = NO_CLIP
	_play(i, CLIP_FLAP)


func _step_frog(i: int) -> void:
	"""Sit, then hop along the bank and, next time, back to its spot."""
	if _state[i] == ST_HOP:
		_pose(i, _from[i].lerp(_to[i], Motion.hop_share(_t[i] / _dur[i])), _yaw[i])
		if _t[i] >= _dur[i]:
			_from[i] = _to[i]
			_land_frog(i)
	elif _t[i] >= _dur[i]:
		if _reduced:
			_rest(i)
			return
		var home: Vector3 = _spots[Rules.FROG][_spot[i]]
		var along: Vector3 = (Spots.pond_middle() - home).cross(Vector3.UP)
		_hop(i, home - _from[i] if _from[i].distance_to(home) > 0.01 else along)


func _land_frog(i: int) -> void:
	"""A frog down from a hop, at rest; back on its spot it turns to face the water again."""
	if _from[i].distance_to(_spots[Rules.FROG][_spot[i]]) < 0.01:
		_yaw[i] = _home_yaw(i)
		_pose(i, _from[i], _yaw[i])
	_rest(i)


func _step_trout(i: int) -> void:
	"""Wait under the surface, then leap along its heading (see EACH FRAME)."""
	if _state[i] == ST_HIDDEN or _t[i] < _dur[i]:
		return
	if _state[i] == ST_LEAP:
		_rest(i)
	elif not _reduced:
		var ahead := Vector3(sin(_yaw[i]), 0.0, cos(_yaw[i]))
		_enter(i, ST_LEAP, LEAP_S)
		_body_on(_body[i], _player[i], true)
		_pose(i, _spots[Rules.TROUT][_spot[i]] - ahead * (LEAP_TRAVEL_M * 0.5), _yaw[i])
		_clip[i] = NO_CLIP
		_play(i, CLIP_LEAP)
	else:
		_rest(i)


# --- the boot prewarm -----------------------------------------------------------------------------------

func begin_prewarm() -> void:
	"""Every body shown before the camera (the view stands at the world's origin, so a body's position is its place in
	the world), its clip running, so its pipelines compile (see THE BOOT PREWARM)."""
	_prewarming = true
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var at: Vector3 = camera.global_position - camera.global_basis.z * 6.0 if camera != null else Vector3.ZERO
	for i: int in _kind.size():
		var side: Vector3 = Vector3.RIGHT * (0.5 * float(i) - 2.0)
		_body_on(_body[i], _player[i], true)
		_body[i].position = at + side
		if _flight[i] != null:
			_body_on(_flight[i], _flight_player[i], true)
			_flight[i].position = at + Vector3.UP * 0.6 + side


func end_prewarm() -> void:
	"""Every body back as the hour says."""
	_prewarming = false
	for i: int in _kind.size():
		_hide(i)
	refresh(true)


# --- what the checks read -------------------------------------------------------------------------------

func count() -> int:
	"""How many animals the pool holds."""
	return _kind.size()


func pool_size(kind: int) -> int:
	"""How many of `kind` the pool holds."""
	var next: int = _first[kind + 1] if kind + 1 < Rules.KINDS else _kind.size()
	return next - _first[kind]


func first_of(kind: int) -> int:
	"""The first pool row of `kind`."""
	return _first[kind]


func shown(kind: int) -> int:
	"""How many of `kind` show this hour."""
	return _shown[kind]


func kind_of(i: int) -> int:
	"""Animal `i`'s kind."""
	return _kind[i]


func state_of(i: int) -> int:
	"""Animal `i`'s state (ST_*)."""
	return _state[i]


func spot_of(i: int) -> int:
	"""Animal `i`'s spot in its kind's list (-1 hidden)."""
	return _spot[i]


func spots_of(kind: int) -> PackedVector3Array:
	"""A kind's spots."""
	return _spots[kind]


func body_of(i: int) -> Node3D:
	"""Animal `i`'s perched (or only) body."""
	return _body[i]


func flight_body_of(i: int) -> Node3D:
	"""A robin's flight body (null for the others)."""
	return _flight[i]


func shown_body_of(i: int) -> Node3D:
	"""The body animal `i` shows now (a flying robin's flight body)."""
	return _flight[i] if _on_wing(i) else _body[i]


func clip_of(i: int) -> StringName:
	"""The clip animal `i` last started (&"" none)."""
	return CLIPS[_clip[i]] if _clip[i] >= 0 else &""


func staged_count() -> int:
	"""How many of the five wildlife models are staged."""
	return _bodies.staged_count()
