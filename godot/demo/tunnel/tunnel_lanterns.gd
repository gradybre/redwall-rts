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
## ROOMS (decision 0209) hang their own lanterns: a row of spots per room after the tunnels' (`set_room_spots`),
## each row with its own light colour -- a home's warm, a cellar's cooler -- that the light takes when given to
## one of its spots.
##
## THE FIT-OUT (decision 0210) lights two more rows a room: its HEARTH while it is lit (`set_hearth_spots`, a deep
## orange), and the lantern a player hangs in it (`set_fit_spots`, the lanterns' own colour). They share the pool, so
## the U view still lights at most MAX_LIGHTS.
##
## THE DIG FACES (decision 0211) light one more row each: the digger's hand lantern, set down beside it at the face
## (`set_face_spot`, dig_theatre.gd), a candle's warm white. Still the one pool of MAX_LIGHTS.
##
## FLICKER. Each light's energy wavers FLICKER either side of ENERGY, two slow waves at its own phase, on
## the demo clock's time: paused, it holds still. It runs only while the U view is on (the surface culls
## these lights by their layer anyway).
##
## BLOOM (decision 0211: "Lanterns are hung and each light pool blooms on"). Every spot remembers when it was first
## hung (on the demo clock), and its light's energy swells up from nothing over BLOOM_S -- a little past full, then
## settling -- so a lantern hung, a hearth lit or a room dug blooms on rather than switching on. A spot handed in
## again unchanged keeps its age.

const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

const MAX_LIGHTS: int = 32
const RANGE_M: float = 3.5
const ENERGY: float = 0.9
const ATTENUATION: float = 1.8
const FLICKER: float = 0.08
const COLOUR: Color = Color(1.0, 0.72, 0.4)
const HEARTH_COLOUR: Color = Color(1.0, 0.5, 0.2)
## The rows after the tunnels': each room's lanterns, its hearth, its hung lantern.
const ROW_ROOMS: int = Rules.MAX_SEGMENTS
const ROW_HEARTHS: int = ROW_ROOMS + RoomsScript.MAX_ROOMS
const ROW_FIT: int = ROW_HEARTHS + RoomsScript.MAX_ROOMS
const ROWS: int = ROW_FIT + RoomsScript.MAX_ROOMS
const REASSIGN_M: float = 1.5
const WAVE_HZ: Vector2 = Vector2(1.7, 4.3)
## The dig faces' hand lanterns: a row each after the fit-out's (dig_theatre.gd), their candle colour.
const FACE_ROWS: int = 3
const ROW_FACES: int = ROWS
const ALL_ROWS: int = ROWS + FACE_ROWS
const CANDLE_COLOUR: Color = Color(1.0, 0.82, 0.6)
## A spot's light swells on over BLOOM_S (demo seconds), peaking at BLOOM_PEAK of its energy, and settles to it over
## as long again.
const BLOOM_S: float = 0.8
const BLOOM_PEAK: float = 1.3
## A spot handed in again within this of where it was is the same spot (it keeps its age).
const SAME_SPOT_M: float = 0.02

var _lights: Array[OmniLight3D] = []
## Per tunnel, then per room, its lanterns' light spots (world metres), when each was hung (demo seconds), and the
## colour of their light.
var _spots: Array[PackedVector3Array] = []
var _born: Array[PackedFloat32Array] = []
var _tints: PackedColorArray = PackedColorArray()
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
var _best_tint: PackedColorArray = PackedColorArray()
var _best_born: PackedFloat32Array = PackedFloat32Array()
## Per pooled light: when the spot it lights was hung.
var _light_born: PackedFloat32Array = PackedFloat32Array()
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
	for row in ALL_ROWS:
		_spots.append(PackedVector3Array())
		_born.append(PackedFloat32Array())
		_tints.append(_row_tint(row))
	_best.resize(MAX_LIGHTS)
	_best_tint.resize(MAX_LIGHTS)
	_best_born.resize(MAX_LIGHTS)
	_light_born.resize(MAX_LIGHTS)
	_gaps.resize(MAX_LIGHTS)


static func _row_tint(row: int) -> Color:
	"""The colour a row's light starts with: a hearth's deep orange, a face's candle, else the lanterns'."""
	if row >= ROW_HEARTHS and row < ROW_FIT:
		return HEARTH_COLOUR
	return CANDLE_COLOUR if row >= ROW_FACES else COLOUR


func follow(showing: Callable, looking_at: Callable) -> void:
	"""`showing() -> bool`: whether the U view is on; `looking_at() -> Vector3`: its focus."""
	_showing = showing
	_looking_at = looking_at


func set_spots(slot: int, spots: PackedVector3Array) -> void:
	"""Segment `slot`'s lanterns now hang here (empty: unlit; decision 0208: keyed by segment). A spot new to the row
	is hung now (see BLOOM); one already there keeps its age."""
	_born[slot] = births(_spots[slot], _born[slot], spots, _time)
	_spots[slot] = spots
	_dirty = true
	update(_focus if _focus.x != INF else Vector3.ZERO)


static func births(old: PackedVector3Array, old_born: PackedFloat32Array, spots: PackedVector3Array,
		now: float) -> PackedFloat32Array:
	"""When each of `spots` was hung: the age of the same spot in `old` (within SAME_SPOT_M), else `now`."""
	var out := PackedFloat32Array()
	out.resize(spots.size())
	for k in spots.size():
		out[k] = now
		for j in old.size():
			if old[j].distance_to(spots[k]) <= SAME_SPOT_M:
				out[k] = old_born[j]
				break
	return out


func set_face_spot(k: int, at: Vector3, on: bool) -> void:
	"""Dig face `k`'s hand lantern lights at `at` (off: none; see THE DIG FACES). Moved less than SAME_SPOT_M, nothing
	is written."""
	var row := ROW_FACES + k
	var had := _spots[row].size() == 1
	if had == on and (not on or _spots[row][0].distance_to(at) <= SAME_SPOT_M):
		return
	set_spots(row, PackedVector3Array([at]) if on else PackedVector3Array())


func set_room_spots(r: int, spots: PackedVector3Array, tint: Color) -> void:
	"""Room `r`'s lanterns now hang here, lighting `tint` (empty: none; see ROOMS)."""
	_tints[ROW_ROOMS + r] = tint
	set_spots(ROW_ROOMS + r, spots)


func set_hearth_spots(r: int, spots: PackedVector3Array) -> void:
	"""Room `r`'s hearth glows here while it is lit (empty: cold; see THE FIT-OUT)."""
	if spots != _spots[ROW_HEARTHS + r]:
		set_spots(ROW_HEARTHS + r, spots)


func set_fit_spots(r: int, spots: PackedVector3Array) -> void:
	"""Room `r`'s hung lantern lights here (empty: none; see THE FIT-OUT)."""
	if spots != _spots[ROW_FIT + r]:
		set_spots(ROW_FIT + r, spots)


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
	"""Give the lights to the spots nearest `focus` when the spots changed or the focus moved far (a level switch moves
	the focus to the other floor, so the lights go to the level shown); each light on the layer of the level its spot is
	on, lighting only it (decision 0212)."""
	if not _dirty and focus.distance_to(_focus) < REASSIGN_M:
		return
	_dirty = false
	_focus = focus
	find_nearest(focus)
	for k in MAX_LIGHTS:
		_lights[k].visible = k < _found
		if k < _found:
			_lights[k].position = _best[k]
			_lights[k].light_color = _best_tint[k]
			_lights[k].layers = Layers.below(Layers.level_at(_best[k].y))
			_lights[k].light_cull_mask = _lights[k].layers
			_light_born[k] = _best_born[k]
	assignments += 1


func find_nearest(focus: Vector3) -> int:
	"""Keep the MAX_LIGHTS spots nearest `focus`, nearest first, in the scratch (all of them when fewer);
	returns how many. An insertion into a fixed row: nothing allocated."""
	_found = 0
	for row in _spots.size():
		var spots := _spots[row]
		for k in spots.size():
			_keep_if_near(spots[k], spots[k].distance_squared_to(focus), _tints[row], _born[row][k])
	return _found


func _keep_if_near(spot: Vector3, gap: float, tint: Color, born: float) -> void:
	"""Slot `spot` (lighting `tint`, hung at `born`) into the nearest-first row if it is nearer than its last (or the
	row is not full)."""
	var at := _found if _found < MAX_LIGHTS else MAX_LIGHTS - 1
	if _found == MAX_LIGHTS and gap >= _gaps[at]:
		return
	while at > 0 and _gaps[at - 1] > gap:
		_gaps[at] = _gaps[at - 1]
		_best[at] = _best[at - 1]
		_best_tint[at] = _best_tint[at - 1]
		_best_born[at] = _best_born[at - 1]
		at -= 1
	_gaps[at] = gap
	_best[at] = spot
	_best_tint[at] = tint
	_best_born[at] = born
	_found = mini(_found + 1, MAX_LIGHTS)


func nearest(k: int) -> Vector3:
	"""The `k`th nearest spot the last search kept (checks)."""
	return _best[k]


func flicker() -> void:
	"""Each lit light's energy on the demo clock's time (see FLICKER)."""
	for k in MAX_LIGHTS:
		if _lights[k].visible:
			_lights[k].light_energy = ENERGY * bloom(_time - _light_born[k]) * (1.0 + FLICKER * wave(_time, k))


static func bloom(age: float) -> float:
	"""A light's share of its energy `age` demo seconds after its spot was hung (see BLOOM): 0 before, swelling to
	BLOOM_PEAK at BLOOM_S, settling to 1 by twice that."""
	if age <= 0.0:
		return 0.0
	if age < BLOOM_S:
		var up := sin(age / BLOOM_S * PI * 0.5)
		return BLOOM_PEAK * up * up
	return lerpf(BLOOM_PEAK, 1.0, minf((age - BLOOM_S) / BLOOM_S, 1.0))


func time_now() -> float:
	"""The lights' demo clock time (seconds; the bloom's reference)."""
	return _time


static func wave(time: float, k: int) -> float:
	"""A light's waver at `time`, in -1..1: two slow waves at light `k`'s own phases."""
	var phase := float(k) * 2.39996
	return 0.6 * sin(TAU * WAVE_HZ.x * time + phase) + 0.4 * sin(TAU * WAVE_HZ.y * time + phase * 1.7)
