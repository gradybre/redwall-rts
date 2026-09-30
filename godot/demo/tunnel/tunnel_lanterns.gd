extends Node3D
## The lanterns' light below: real omni lights, pooled and capped, flickering on the demo clock.
## Decision 0207 (the underground revamp's P1; design docs/design/underground_revamp.md §5 "Lighting").
## Presentation only.
##
## Every lit tunnel's lanterns are light SPOTS (tunnel_marks.gd hands them in as it hangs them). There
## are at most MAX_LIGHTS OmniLight3Ds, made once at boot -- shadowless, RANGE_M, on the UNDERGROUND layer
## lighting only it -- and they go to the spots nearest the U view's focus: reassigned when the spots
## change or the focus has moved REASSIGN_M, never per frame otherwise. So however many lanterns hang, the
## U view lights at most MAX_LIGHTS pools, where the player is looking.
##
## FLICKER. Each light's energy wavers FLICKER either side of ENERGY, two slow waves at its own phase, on
## the demo clock's time: paused, it holds still. It runs only while the U view is on (the surface culls
## these lights by their layer anyway).

const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

const MAX_LIGHTS: int = 32
const RANGE_M: float = 3.5
const ENERGY: float = 0.9
const ATTENUATION: float = 1.8
const FLICKER: float = 0.08
const COLOUR: Color = Color(1.0, 0.72, 0.4)
const REASSIGN_M: float = 1.5
const WAVE_HZ: Vector2 = Vector2(1.7, 4.3)

var _lights: Array[OmniLight3D] = []
## Per tunnel, its lanterns' light spots (world metres).
var _spots: Array[PackedVector3Array] = []
var _dirty: bool = true
var _focus: Vector3 = Vector3(INF, INF, INF)
var _time: float = 0.0
var _clock: DemoClockScript = null
## Whether the U view is on, and where it looks (none: always on, looking at the origin).
var _showing: Callable = Callable()
var _looking_at: Callable = Callable()
## Assignments so far (measurement and the tests).
var assignments: int = 0
## The nearest spots found by the last `find_nearest`, nearest first, and how many: sized once, so
## choosing never allocates (a toggle or a pan allocates nothing).
var _best: PackedVector3Array = PackedVector3Array()
var _gaps: PackedFloat32Array = PackedFloat32Array()
var _found: int = 0


func configure(clock: DemoClockScript = null) -> void:
	"""MAX_LIGHTS lights, dark and hidden, flickering on `clock` (none: still)."""
	name = "Lanterns"
	_clock = clock
	for k in MAX_LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = COLOUR
		light.light_energy = ENERGY
		light.omni_range = RANGE_M
		light.omni_attenuation = ATTENUATION
		light.shadow_enabled = false
		light.layers = Layers.UNDERGROUND
		light.light_cull_mask = Layers.UNDERGROUND
		light.visible = false
		add_child(light)
		_lights.append(light)
	for slot in Rules.MAX_TUNNELS:
		_spots.append(PackedVector3Array())
	_best.resize(MAX_LIGHTS)
	_gaps.resize(MAX_LIGHTS)


func follow(showing: Callable, looking_at: Callable) -> void:
	"""`showing() -> bool`: whether the U view is on; `looking_at() -> Vector3`: its focus."""
	_showing = showing
	_looking_at = looking_at


func set_spots(slot: int, spots: PackedVector3Array) -> void:
	"""Tunnel `slot`'s lanterns now hang here (empty: unlit)."""
	_spots[slot] = spots
	_dirty = true
	update(_focus if _focus.x != INF else Vector3.ZERO)


func light(k: int) -> OmniLight3D:
	"""Pooled light `k` (checks)."""
	return _lights[k]


func lit_count() -> int:
	"""How many pooled lights are on."""
	var count := 0
	for light_node: OmniLight3D in _lights:
		count += 1 if light_node.visible else 0
	return count


func spot_count() -> int:
	"""How many lantern spots hang, lit or not."""
	var count := 0
	for spots: PackedVector3Array in _spots:
		count += spots.size()
	return count


func _process(_delta: float) -> void:
	"""On the demo clock: follow the U view's focus and flicker, only while it is on."""
	if _clock != null:
		_time += _clock.delta_s()
	if _showing.is_valid() and not bool(_showing.call()):
		return
	update(_looking_at.call() if _looking_at.is_valid() else Vector3.ZERO)
	flicker()


func update(focus: Vector3) -> void:
	"""Give the lights to the spots nearest `focus` when the spots changed or the focus moved far."""
	if not _dirty and focus.distance_to(_focus) < REASSIGN_M:
		return
	_dirty = false
	_focus = focus
	find_nearest(focus)
	for k in MAX_LIGHTS:
		_lights[k].visible = k < _found
		if k < _found:
			_lights[k].position = _best[k]
	assignments += 1


func find_nearest(focus: Vector3) -> int:
	"""Keep the MAX_LIGHTS spots nearest `focus`, nearest first, in the scratch (all of them when fewer);
	returns how many. An insertion into a fixed row: nothing allocated."""
	_found = 0
	for spots: PackedVector3Array in _spots:
		for spot: Vector3 in spots:
			_keep_if_near(spot, spot.distance_squared_to(focus))
	return _found


func _keep_if_near(spot: Vector3, gap: float) -> void:
	"""Slot `spot` into the nearest-first row if it is nearer than its last (or the row is not full)."""
	var at := _found if _found < MAX_LIGHTS else MAX_LIGHTS - 1
	if _found == MAX_LIGHTS and gap >= _gaps[at]:
		return
	while at > 0 and _gaps[at - 1] > gap:
		_gaps[at] = _gaps[at - 1]
		_best[at] = _best[at - 1]
		at -= 1
	_gaps[at] = gap
	_best[at] = spot
	_found = mini(_found + 1, MAX_LIGHTS)


func nearest(k: int) -> Vector3:
	"""The `k`th nearest spot the last search kept (checks)."""
	return _best[k]


func flicker() -> void:
	"""Each lit light's energy on the demo clock's time (see FLICKER)."""
	for k in MAX_LIGHTS:
		if _lights[k].visible:
			_lights[k].light_energy = ENERGY * (1.0 + FLICKER * wave(_time, k))


static func wave(time: float, k: int) -> float:
	"""A light's waver at `time`, in -1..1: two slow waves at light `k`'s own phases."""
	var phase := float(k) * 2.39996
	return 0.6 * sin(TAU * WAVE_HZ.x * time + phase) + 0.4 * sin(TAU * WAVE_HZ.y * time + phase * 1.7)
