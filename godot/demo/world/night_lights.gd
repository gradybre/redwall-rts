extends Node3D
## THE SURFACE'S NIGHT LIGHTS: a small pool of warm omni lights, lit with the lamps' hour. Decision 0541 (the day and
## night). Presentation only.
##
## THE POOL, AND ITS BUDGET. At most daylight_curves.gd NIGHT_LIGHTS OmniLight3Ds, made once -- shadowless, short
## ranged, on the SURFACE layer and lighting only the surface view (the U view culls them by their layer, as it does
## the sun; decision 0206) -- given to the SPOTS nearest the camera's focus. They are reassigned only when the spots
## change or the focus has moved REASSIGN_M, never per frame otherwise; so however many lanterns and homes there are,
## the village lights at most NIGHT_LIGHTS pools, where the player is looking. Below, the underground keeps its own
## pool (tunnel_lanterns.gd, 32 lights, its own environment): this one never lights there.
##
## THE SPOTS:
##   * HOMES -- the hall, the three residences and the kitchen (daylight_curves.gd LIT_HOMES) -- lamplight at the door,
##     HOME_GAP_M out from each front, the spill that lights the doorway and the ground before it;
##     WHICH HOMES ARE LIT is one query, `set_home_lit(lit)` -- `lit(k: int) -> bool` for home k in LIT_HOMES order --
##     read with the mouths (every MOUTH_POLL_S). Without one every home is lit while the lamps are; the winter fuel
##     work wires it to its "fuelled and demanded" hearth (a home's `night_routine.hearth_lit(r)`, the hall's
##     `demo_winter.fuel.hearth_lit(HALL)`), so a cold, unfuelled home stands dark;
##   * TUNNEL MOUTHS -- each standing arch's lantern (tunnel_overlay.gd `lantern_spots_into`), read again every
##     MOUTH_POLL_S, since mouths come and go only as tunnels are dug.
##
## THE WINDOWS (art pass 2, decision 0951). Where a home's `<key>_windows` model is staged (demo_world.gd THE HOMES'
## WINDOWS; the hall's stone stage 2 too), its window mask glows: `bind_windows(glow_of)` -- `glow_of(id: StringName)
## -> Array` of BaseMaterial3D, demo_world.gd `window_glow` -- and each home's materials' emission_energy_multiplier is
## WINDOW_GLOW x the level while that home is lit (the SAME flag as its door lamp), 0 by day or while it stands dark.
## Written only when a home's value changes (the level easing at dawn and dusk, or its flag), never otherwise. Nothing
## staged: empty lists, nothing glows.
## The residence's mask is effectively empty (its windows are shutters) and the kitchen's small: their door lamps stay.
##
## THE LEVEL (`set_level`, the lighting cycle's LAMPS: 1 at night, 0 by day) scales every light's energy; at 0 the pool
## is hidden and nothing runs. Each light wavers FLICKER either side of its energy, gently and slowly, in REAL time so
## 2x and 4x do not quicken it -- but only while the demo clock runs (paused: it holds still, and only a reassignment,
## as the camera pans, writes anything); with reduced motion (demo_motion.gd) it holds steady.

const Curves := preload("res://demo/world/daylight_curves.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

## Reassign when the focus has moved this far since the last time.
const REASSIGN_M: float = 2.0
## Read the mouths' lanterns again this often (real seconds).
const MOUTH_POLL_S: float = 0.5
## At most this many mouth lanterns are considered: one a mouth row.
const MAX_MOUTHS: int = Rules.MAX_MOUTHS
## A light's spot kinds.
const KIND_HOME: int = 0
const KIND_LANTERN: int = 1
## The windows' emission at full night (I11 Ember's mask, art pass 2: "0 -> about 1.5").
const WINDOW_GLOW: float = 1.5

var _lights: Array[OmniLight3D] = []
## Per pooled light: its spot's kind (-1: unused).
var _light_kind: PackedInt32Array = PackedInt32Array()
var _homes: PackedVector3Array = PackedVector3Array()
## Per home: whether it is lit (1) by the `set_home_lit` query, read with the mouths.
var _home_on: PackedByteArray = PackedByteArray()
var _home_lit: Callable = Callable()
var _mouths: PackedVector3Array = PackedVector3Array()
var _mouth_count: int = 0
## Scratch for a fresh read of the mouths (compared with the last, so an unchanged read reassigns nothing).
var _mouths_read: PackedVector3Array = PackedVector3Array()
## `(out: PackedVector3Array) -> int`: writes the mouths' lantern spots; `() -> Vector3`: the camera's focus.
var _mouth_source: Callable = Callable()
var _focus_source: Callable = Callable()
## Whether the demo clock runs (none: always).
var _clock: DemoClockScript = null
var _level: float = 0.0
var _focus: Vector3 = Vector3(INF, INF, INF)
var _dirty: bool = true
var _poll_in: float = 0.0
var _time: float = 0.0
## The nearest-spot scratch: gaps and kinds of the best so far, sized once.
var _best: PackedVector3Array = PackedVector3Array()
var _best_gap: PackedFloat32Array = PackedFloat32Array()
var _best_kind: PackedInt32Array = PackedInt32Array()
var _found: int = 0
## Assignments so far (checks and measurement).
var assignments: int = 0
## Per home (LIT_HOMES order): its window materials (THE WINDOWS; the world's own lists), and the energy last written.
var _glow: Array[Array] = []
var _glow_at: PackedFloat64Array = PackedFloat64Array()
## Window energy writes so far (checks).
var glow_writes: int = 0


func configure(homes: PackedVector3Array, mouth_source: Callable, focus_source: Callable,
		clock: DemoClockScript = null) -> void:
	"""The pool of NIGHT_LIGHTS lights, dark; lighting `homes` (world metres) and the mouths `mouth_source` writes,
	nearest `focus_source()`, flickering while `clock` runs (none: always)."""
	name = "NightLights"
	_homes = homes
	_home_on.resize(homes.size())
	_home_on.fill(1)
	_mouth_source = mouth_source
	_focus_source = focus_source
	_clock = clock
	_mouths.resize(MAX_MOUTHS)
	_mouths_read.resize(MAX_MOUTHS)
	for k in Curves.NIGHT_LIGHTS:
		var lamp := OmniLight3D.new()
		lamp.shadow_enabled = false
		lamp.layers = Layers.SURFACE
		lamp.light_cull_mask = Layers.SURFACE_VIEW
		lamp.omni_attenuation = 1.6
		lamp.light_specular = 0.2
		lamp.visible = false
		add_child(lamp)
		_lights.append(lamp)
	_light_kind.resize(Curves.NIGHT_LIGHTS)
	_light_kind.fill(-1)
	_best.resize(Curves.NIGHT_LIGHTS)
	_best_gap.resize(Curves.NIGHT_LIGHTS)
	_best_kind.resize(Curves.NIGHT_LIGHTS)


static func home_spots(world_layout_placements: Array[Dictionary]) -> PackedVector3Array:
	"""Where each lit home's lamplight hangs: HOME_GAP_M out from its front, HOME_UP_M up (see THE SPOTS)."""
	var out := PackedVector3Array()
	for id: StringName in Curves.LIT_HOMES:
		var placement: Dictionary = Layout.find_placement(world_layout_placements, id)
		if placement.is_empty():
			continue
		var spot: Array[Vector2] = Layout.anchored_spot(placement, {"side": &"front", "gap": Curves.HOME_GAP_M, "along": 0.0})
		out.append(Vector3(spot[0].x, Layout.GROUND_Y + Curves.HOME_UP_M, spot[0].y))
	return out


func set_level(lit: float) -> void:
	"""How lit the lamps are, `lit` 0..1 (see THE LEVEL): shown or hidden on a change across 0, the lit ones' energies
	written at once (paused too)."""
	var was_lit := _level > 0.0
	var was := _level
	_level = clampf(lit, 0.0, 1.0)
	if _level > 0.0 and _level != was:
		flicker()
	if _level != was:
		write_windows()
	if (_level > 0.0) != was_lit:
		_dirty = true
		if _level <= 0.0:
			for lamp: OmniLight3D in _lights:
				lamp.visible = false


func level() -> float:
	"""How lit the lamps are now (checks)."""
	return _level


func set_home_lit(lit: Callable) -> void:
	"""Which homes are lit (see WHICH HOMES ARE LIT): `lit(k: int) -> bool`, read at once and with the mouths after."""
	_home_lit = lit
	read_homes()


func read_homes() -> bool:
	"""Ask the query which homes are lit (all of them without one); true (and the pool marked for reassignment) when any
	changed."""
	var changed := false
	for k in _homes.size():
		var on: int = 1 if not _home_lit.is_valid() or bool(_home_lit.call(k)) else 0
		if on != _home_on[k]:
			_home_on[k] = on
			changed = true
	if changed:
		_dirty = true
		write_windows()
	return changed


func bind_windows(glow_of: Callable) -> void:
	"""The homes' window materials (see THE WINDOWS): `glow_of(id)` for each home's LIT_HOMES id, kept by reference,
	and written at once. After a world rebuild (its lists refilled dark) bind again, so every home is rewritten."""
	_glow.clear()
	for k in mini(_homes.size(), Curves.LIT_HOMES.size()):
		_glow.append(glow_of.call(Curves.LIT_HOMES[k]) as Array)
	_glow_at.resize(_glow.size())
	_glow_at.fill(-1.0)
	write_windows()


func write_windows() -> void:
	"""Each home's windows at WINDOW_GLOW x the level while it is lit, else dark -- written only where that changed."""
	for k in _glow.size():
		var energy: float = WINDOW_GLOW * _level if _home_on[k] == 1 else 0.0
		if energy == _glow_at[k]:
			continue
		_glow_at[k] = energy
		for material: BaseMaterial3D in _glow[k]:
			material.emission_energy_multiplier = energy
		glow_writes += 1


func window_energy(k: int) -> float:
	"""The energy home `k`'s windows were last written at (-1: never; checks)."""
	return _glow_at[k] if k < _glow_at.size() else -1.0


func set_mouth_source(source: Callable) -> void:
	"""Where the mouths' lanterns are read from now (see THE SPOTS), read at the next frame."""
	_mouth_source = source
	_poll_in = 0.0


func _process(delta: float) -> void:
	"""While lit: read the mouths now and then and reassign when the spots or the focus moved (paused too: the camera
	still pans); flicker only while the demo clock runs."""
	if _level <= 0.0:
		return
	_poll_in -= delta
	if _poll_in <= 0.0:
		_poll_in = MOUTH_POLL_S
		read_mouths()
		read_homes()
	update(_focus_source.call() if _focus_source.is_valid() else Vector3.ZERO)
	if _clock == null or _clock.delta_s() > 0.0:
		_time += delta
		flicker()


func read_mouths() -> bool:
	"""Read the mouths' lanterns; true (and the pool marked for reassignment) when they changed."""
	var count := 0
	if _mouth_source.is_valid():
		count = mini(int(_mouth_source.call(_mouths_read)), MAX_MOUTHS)
	var changed := count != _mouth_count
	for k in count:
		if changed:
			break
		changed = _mouths_read[k] != _mouths[k]
	if changed:
		for k in count:
			_mouths[k] = _mouths_read[k]
		_mouth_count = count
		_dirty = true
	return changed


func update(focus: Vector3) -> void:
	"""Give the lights to the spots nearest `focus` when the spots changed or the focus moved far."""
	if not _dirty and focus.distance_to(_focus) < REASSIGN_M:
		return
	_dirty = false
	_focus = focus
	_found = 0
	for k in _homes.size():
		if _home_on[k] == 1:
			_keep_if_near(_homes[k], KIND_HOME, focus)
	for k in _mouth_count:
		_keep_if_near(_mouths[k], KIND_LANTERN, focus)
	for k in Curves.NIGHT_LIGHTS:
		var lamp := _lights[k]
		lamp.visible = k < _found
		_light_kind[k] = _best_kind[k] if k < _found else -1
		if k < _found:
			lamp.position = _best[k]
			var home := _best_kind[k] == KIND_HOME
			lamp.light_color = Curves.HOME_COLOUR if home else Curves.LANTERN_COLOUR
			lamp.omni_range = Curves.HOME_RANGE_M if home else Curves.LANTERN_RANGE_M
	assignments += 1
	flicker()


func _keep_if_near(spot: Vector3, kind: int, focus: Vector3) -> void:
	"""Slot `spot` into the nearest-first scratch if it is nearer than its last (or the scratch is not full)."""
	var gap := spot.distance_squared_to(focus)
	var at := _found if _found < Curves.NIGHT_LIGHTS else Curves.NIGHT_LIGHTS - 1
	if _found == Curves.NIGHT_LIGHTS and gap >= _best_gap[at]:
		return
	while at > 0 and _best_gap[at - 1] > gap:
		_best_gap[at] = _best_gap[at - 1]
		_best[at] = _best[at - 1]
		_best_kind[at] = _best_kind[at - 1]
		at -= 1
	_best_gap[at] = gap
	_best[at] = spot
	_best_kind[at] = kind
	_found = mini(_found + 1, Curves.NIGHT_LIGHTS)


func flicker() -> void:
	"""Each lit light's energy: its kind's, times the level, wavering gently (steady with reduced motion)."""
	var waver := 0.0 if DemoMotion.reduced else Curves.FLICKER
	for k in Curves.NIGHT_LIGHTS:
		if _light_kind[k] < 0:
			continue
		var energy := Curves.HOME_ENERGY if _light_kind[k] == KIND_HOME else Curves.LANTERN_ENERGY
		_lights[k].light_energy = energy * _level * (1.0 + waver * wave(_time, k))


static func wave(time: float, k: int) -> float:
	"""A light's waver at `time`, in -1..1: two slow waves at light `k`'s own phases."""
	var phase := float(k) * 2.39996
	return 0.6 * sin(TAU * Curves.FLICKER_HZ.x * time + phase) + 0.4 * sin(TAU * Curves.FLICKER_HZ.y * time + phase * 1.7)


func light(k: int) -> OmniLight3D:
	"""Pooled light `k` (checks)."""
	return _lights[k]


func lit_count() -> int:
	"""How many pooled lights are on."""
	var count := 0
	for lamp: OmniLight3D in _lights:
		count += 1 if lamp.visible else 0
	return count


func spot_count() -> int:
	"""How many spots there are to light: the homes and the mouths read last."""
	return _homes.size() + _mouth_count


func begin_prewarm() -> void:
	"""The boot prewarm's night frames (day_night.gd): every light shown at the focus's nearest spots."""
	set_level(1.0)
	_dirty = true
	read_mouths()
	update(_focus_source.call() if _focus_source.is_valid() else Vector3.ZERO)
	flicker()
