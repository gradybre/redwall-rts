extends Node3D
## What the fit-out looks like: every fixture standing in the rooms, a cellar's racks filling as its stock rises, the
## hearths' glow and the chimneys' smoke. Decision 0210 (the underground revamp's P4; design §2 "Living": "Inside:
## hearth glow, a rug, a table, beds in wall alcoves. Smoke rises from the mound's chimney pot"; "racks and jars that
## visibly fill as harvests come in"). Presentation only.
##
## BELOW (the U view's layers), per room and place (room_fixtures.gd): nothing while it is EMPTY, a chalk ring while it
## is PLANNED, the fixture once INSTALLED (fixture_kit.gd: the library's props -- since P7 (decision 0371) the root
## bin, the hanging stores, the rug and the large bed too -- each with a procedural stand-in for when it is not staged).
## The hanging stores hang from the room's ring beam by their wall brackets (`hang_back_m`), their top HANG_TOP_M over
## the floor. A place's node is built when its phase changes -- never on a view switch -- and a
## room's pieces show only while it is dug.
##
## PUT IN (decision 0211; design §4 "each with an install pop"): while a resident works a planned place, the fixture
## RISES from the floor up through its chalk ring as the work is done (room_fixtures.gd `work_usec` of its install
## time) -- a lantern or hanging stores swell out on the wall instead, a rug's colours come up through the floor --
## and once in, the ring goes and a puff of dust (the warren's pooled particles) marks it.
##
## LIT (`lit() -> bool`: the night routine's hearth hours) a home's hearth glows: its embers show and one of the pooled
## lights (tunnel_lanterns.gd `set_hearth_spots`) burns deep orange over its firebox; a lantern hung in a room lights too
## (`set_fit_spots`). ON THE GROUND a home with a hearth has a chimney pot on its mound over the hearth, SMOKING while
## it is lit; the smoke runs on the demo clock (paused, it stands still; at 4x it rises four times as fast). A home on
## LEVEL 2 (decision 0212) has no mound, so no chimney and no smoke: its fixtures stand on its own level's floor and
## layer.
##
## FILLING (`fill(r) -> permille`: how full the pantry holds cellar `r`, demo_farm.gd `cellar_fill`): a cellar's
## storage fixtures' slots show in order across the cellar -- its shelves' sacks, its rack's jars and sacks, its hanging
## stores' strings -- one more for each share of its fill, and its root bin's heap rises with it. Read a few times a
## second, never per frame.

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const KitScript := preload("res://demo/burrow/fixture_kit.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const RoomMeshScript := preload("res://demo/burrow/room_mesh.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const PLACES: int = FixturesScript.PLACES
## A floor piece stands this far over the floor (m).
const FLOOR_LIFT_M: float = 0.02
## The hearth's firebox, in its own frame: this share of its depth out from its middle, this high (m); its light
## this much higher and further out.
const FIRE_OUT_SHARE: float = 0.2
const FIRE_Y_M: float = 0.12
const FIRE_LIGHT: Vector3 = Vector3(0.0, 0.35, 0.2)
## The staged hanging stores hang with their top here over the floor: on the ring beam (room_view.gd BEAM_Y_M) by
## their brackets, their back against its inner face.
const HANG_TOP_M: float = RoomViewScript.BEAM_Y_M + RoomViewScript.BEAM_DEPTH_M * 0.5
## A hung lantern hangs this high on the wall, its bracket's reach out from it (the wall lantern's fit).
const LANTERN_LIFT_M: float = 1.0
const FILL_EVERY_S: float = 0.25
## A fixture being put in first shows this share of the way up (so the resident is plainly at work on something).
const FIRST_RISE: float = 0.08

var _graph: RefCounted = null
var _props: PropsScript = null
var _lights: LanternsScript = null
var _clock: DemoClockScript = null
var _lit: Callable = Callable()
var _fill: Callable = Callable()
var _below: Array[Node3D] = []
var _ground: Array[Node3D] = []
var _smoke: Array[CPUParticles3D] = []
## What lights the (unshaded) smoke now: the lighting cycle's tint (decision 0541, `set_smoke_tint`), each chimney's own.
var _smoke_tint: Color = Color.WHITE
var _embers: Array[MeshInstance3D] = []
## Per place row: its node, the key it was built for, and its fill slots.
var _pieces: Array[Node3D] = []
var _keys: PackedInt64Array = PackedInt64Array()
var _slots: Array = []
var _fill_in: float = 0.0
var _lit_now: PackedByteArray = PackedByteArray()
## Place builds so far (the tests: a view switch builds none).
var builds: int = 0
## Per place row: the fixture rising while it is put in (null: none; see PUT IN), and how tall it stands (m).
var _rising: Array[Node3D] = []
var _rise_tall: PackedFloat32Array = PackedFloat32Array()
## The warren's particles, for the puff when a fixture is in (none: no puff).
var _particles: ParticlesScript = null


func configure(graph: RefCounted, props: PropsScript, lights: LanternsScript, clock: DemoClockScript) -> void:
	"""Draw this network's fit-out with these props, lighting its hearths and hung lanterns from `lights`, its smoke on
	`clock` (none: still). Every room's and place's nodes are made once, empty."""
	name = "FixtureView"
	_graph = graph
	_props = props if props != null else PropsScript.new()
	_lights = lights
	_clock = clock
	_keys.resize(RoomsScript.MAX_ROOMS * PLACES)
	_keys.fill(-1)
	_lit_now.resize(RoomsScript.MAX_ROOMS)
	for r in RoomsScript.MAX_ROOMS:
		_build_room_row()
	for k in RoomsScript.MAX_ROOMS * PLACES:
		_pieces.append(null)
		_rising.append(null)
		_slots.append([] as Array[Node3D])
	_rise_tall.resize(RoomsScript.MAX_ROOMS * PLACES)


func set_particles(particles: ParticlesScript) -> void:
	"""The warren's particles (warren_particles.gd) a fixture's puff comes from (see PUT IN)."""
	_particles = particles


func _build_room_row() -> void:
	"""One room row's holders: below (hidden), and on the ground its chimney with its smoke (hidden)."""
	var below := Node3D.new()
	below.visible = false
	add_child(below)
	_below.append(below)
	var ground := Node3D.new()
	ground.visible = false
	add_child(ground)
	KitScript.chimney(ground, _props)
	var puffs := KitScript.smoke()
	puffs.color = _smoke_tint
	puffs.position = Vector3(0.0, KitScript.chimney_top_m(_props), 0.0)
	ground.add_child(puffs)
	Layers.set_layers(ground, Layers.SURFACE)
	_ground.append(ground)
	_smoke.append(puffs)
	_embers.append(null)


func set_smoke_tint(tint: Color) -> void:
	"""What lights the chimneys' smoke now (the lighting cycle's UNLIT_TINT, decision 0541): every chimney's particles'
	colour, which multiplies their ramp -- per chimney, never the shared puff material."""
	_smoke_tint = tint
	for puffs: CPUParticles3D in _smoke:
		puffs.color = tint


func smoke_tint() -> Color:
	"""What lights the chimneys' smoke now (checks)."""
	return _smoke_tint


func set_lit(lit: Callable) -> void:
	"""`lit() -> bool`: whether it is the hearths' hours now (see LIT)."""
	_lit = lit


func set_fill(fill: Callable) -> void:
	"""`fill(r: int) -> int`: how full cellar row `r` is, per mille (see FILLING)."""
	_fill = fill


func register(prewarm: PrewarmScript) -> void:
	"""Everything the fit-out draws below, for the U view's prewarm (decision 0206)."""
	KitScript.register(prewarm, _props)


# --- each frame ---------------------------------------------------------------------------------

func refresh(delta: float) -> void:
	"""Rebuild each place whose phase changed, show the dug rooms, light and smoke by the hour, follow the clock with
	the smoke, and a few times a second fill the cellars (see the header)."""
	var fit: FixturesScript = _graph.fit
	var lit := _lit.is_valid() and bool(_lit.call())
	for r in RoomsScript.MAX_ROOMS:
		var dug: bool = _graph.rooms.is_done(_graph, r)
		_below[r].visible = dug
		if dug:
			_refresh_places(fit, r)
		_light(r, dug and lit and fit.has_hearth(_graph, r))
	var speed := float(_clock.speed) if _clock != null else 1.0
	for puffs in _smoke:
		puffs.speed_scale = speed
	_fill_in -= delta
	if _fill_in <= 0.0:
		_fill_in = FILL_EVERY_S
		_fill_cellars()


func _refresh_places(fit: FixturesScript, r: int) -> void:
	"""Room `r`'s places: each rebuilt when its key (generation, template, phase) changed."""
	var template: int = _graph.rooms.template[r]
	for f in RoomsScript.fixture_count(template):
		var row := r * PLACES + f
		var phase := fit.phase_of(_graph, r, f)
		var working := 1 if phase == FixturesScript.PLANNED and fit.work_usec[row] > 0 else 0
		var key: int = (((_graph.rooms.generation[r] * 4 + template) * 4 + phase) * 2 + working) * 16 + fit.kind_at(_graph, r, f)
		if key != _keys[row]:
			var was_rising := _rising[row] != null
			_keys[row] = key
			_build_place(r, f, phase)
			if was_rising and phase == FixturesScript.INSTALLED:
				_puff_at(r, f)
		if _rising[row] != null:
			_rise(row, fit)


func _build_place(r: int, f: int, phase: int) -> void:
	"""Place `f` of room `r` as it stands (see BELOW)."""
	var row := r * PLACES + f
	if _pieces[row] != null:
		_pieces[row].queue_free()
		_pieces[row] = null
	(_slots[row] as Array).clear()
	_ground[r].visible = _graph.fit.has_hearth(_graph, r) and _graph.rooms.level[r] == Rules.TOP_LEVEL
	if f == _hearth_place(r) and phase != FixturesScript.INSTALLED:
		_embers[r] = null
	if phase == FixturesScript.EMPTY:
		_fit_lights(r)
		return
	var piece := Node3D.new()
	piece.transform = place_transform(r, f)
	_below[r].add_child(piece)
	_pieces[row] = piece
	_rising[row] = null
	if phase == FixturesScript.PLANNED:
		KitScript.planned(piece)
		if _graph.fit.work_usec[row] > 0:
			_start_rising(r, f, piece)
	else:
		_install(r, f, piece)
	Layers.set_layers(piece, Layers.below(_graph.rooms.level[r]))
	builds += 1
	_fit_lights(r)


# --- putting it in (see PUT IN) ------------------------------------------------------------------

func _start_rising(r: int, f: int, piece: Node3D) -> void:
	"""The fixture being put in at place `f` of room `r`, built under `piece` below its floor, to rise as it is worked."""
	var rising := Node3D.new()
	piece.add_child(rising)
	_install(r, f, rising)
	var row := r * PLACES + f
	_rising[row] = rising
	_rise_tall[row] = _tallness(rising)


static func _tallness(root: Node3D) -> float:
	"""How tall what stands under `root` is (m): the highest top of its meshes' boxes, at least 0.1."""
	var top := 0.1
	for child in root.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			var box: AABB = mesh.transform * mesh.mesh.get_aabb()
			top = maxf(top, box.end.y)
	return top


func _rise(row: int, fit: FixturesScript) -> void:
	"""The fixture being put in at place row `row` stands as far up as its work is done: a floor fixture risen that
	share of its height out of the floor, a hung one swollen to that share of its size, a rug that share come up."""
	var r := row / PLACES
	var kind := fit.kind_at(_graph, r, row % PLACES)
	var need := FixturesScript.install_usec(kind)
	var share := lerpf(FIRST_RISE, 1.0, clampf(float(fit.work_usec[row]) / float(maxi(need, 1)), 0.0, 1.0))
	var rising := _rising[row]
	if kind == RoomsScript.FIX_LANTERN or kind == RoomsScript.FIX_HANGING:
		rising.scale = Vector3.ONE * share
	elif kind == RoomsScript.FIX_RUG and rising.get_child_count() > 0 and rising.get_child(0) is Decal:
		(rising.get_child(0) as Decal).modulate = Color(1.0, 1.0, 1.0, share)
	else:
		rising.position.y = -_rise_tall[row] * (1.0 - share)


func _puff_at(r: int, f: int) -> void:
	"""A puff of dust where place `f` of room `r`'s fixture has just gone in."""
	if _particles != null:
		_particles.puff(place_transform(r, f).origin + Vector3(0.0, 0.2, 0.0), Layers.below(_graph.rooms.level[r]))


func rising(r: int, f: int) -> Node3D:
	"""The fixture rising at place `f` of room `r` while it is put in (null: none; checks)."""
	return _rising[r * PLACES + f]


func _install(r: int, f: int, piece: Node3D) -> void:
	"""The installed fixture at place `f` of room `r` into `piece` (see fixture_kit.gd)."""
	var kind: int = _graph.fit.kind_at(_graph, r, f)
	var slots: Array[Node3D] = _slots[r * PLACES + f]
	match kind:
		RoomsScript.FIX_RACK:
			KitScript.rack(piece, _props, slots)
		RoomsScript.FIX_BIN:
			KitScript.root_bin(piece, slots, _props)
		RoomsScript.FIX_HANGING:
			var back := hang_back_m(_graph.rooms.template[r], f)
			KitScript.hanging(piece, slots, _props, KitScript.hang_at(_props, HANG_TOP_M, back) if back >= 0.0 else Transform3D.IDENTITY)
			_fill_all(slots, _graph.rooms.template[r] == RoomsScript.TEMPLATE_HOME)
		RoomsScript.FIX_RUG:
			var rug := KitScript.rug(piece, _props)
			if rug is Decal:
				(rug as Decal).cull_mask = Layers.below(_graph.rooms.level[r])
		RoomsScript.FIX_LANTERN:
			_hang_lantern(piece)
		RoomsScript.FIX_BIG_BED:
			KitScript.large_bed(piece, _props)
		_:
			_stand_prop(r, f, kind, piece)


func _stand_prop(r: int, f: int, kind: int, piece: Node3D) -> void:
	"""A library prop fixture: the bed, the hearth (and its embers), the table, the shelf (and its sacks)."""
	var key: StringName = [&"bed", &"hearth", &"table_stools", &"pantry_shelf"][kind]
	KitScript.prop(piece, _props, key, Transform3D.IDENTITY)
	var bound: AABB = _props.drawn_bound(key)
	if kind == RoomsScript.FIX_HEARTH:
		_embers[r] = KitScript.embers(piece, Vector3(0.0, FIRE_Y_M, bound.size.z * FIRE_OUT_SHARE))
		_place_chimney(r, f)
	elif kind == RoomsScript.FIX_SHELF and _graph.rooms.template[r] == RoomsScript.TEMPLATE_CELLAR:
		KitScript.shelf_slots(piece, _props, bound.size.z, _slots[r * PLACES + f])


func _hang_lantern(piece: Node3D) -> void:
	"""A hung lantern: the wall lantern on the wall at its place (its plate at +X, turned to the wall, its cage out
	over the room), LANTERN_LIFT_M up, glowing."""
	var reach: float = _props.drawn_bound(&"wall_lantern").size.x * 0.5
	var hung := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, LANTERN_LIFT_M, reach))
	KitScript.prop(piece, _props, &"wall_lantern", hung)


static func hang_back_m(template: int, f: int) -> float:
	"""How far behind place `f` of a room of `template` -- back along its facing, in the room's own frame -- the ring
	beam's inner face is (m): where the hanging stores' back hangs (room_view.gd's beam: a circle BEAM_INSET_M inside a
	home's wall, a rectangle inside a cellar's). -1 when the way back never meets it."""
	var at := Vector2(Rules.to_m(RoomsScript.fixture_field(template, f, 1)), Rules.to_m(RoomsScript.fixture_field(template, f, 2)))
	var back := -Vector2(float(RoomsScript.fixture_field(template, f, 3)), float(RoomsScript.fixture_field(template, f, 4))).normalized()
	var wall := Vector2(Rules.to_m(RoomsScript.void_half(template).x), Rules.to_m(RoomsScript.void_half(template).y))
	var inset := RoomViewScript.BEAM_INSET_M + RoomViewScript.BEAM_WIDTH_M * 0.5
	if RoomsScript.SHAPE[template] == RoomsScript.SHAPE_ROUND:
		var reach := wall.x - inset
		var along := at.dot(back)
		var under := along * along - at.length_squared() + reach * reach
		return -along + sqrt(under) if under >= 0.0 else -1.0
	var best := -1.0
	for axis: int in 2:
		if absf(back[axis]) > 1e-4:
			var t := (signf(back[axis]) * (wall[axis] - inset) - at[axis]) / back[axis]
			if t >= 0.0 and (best < 0.0 or t < best):
				best = t
	return best


func place_transform(r: int, f: int) -> Transform3D:
	"""Where place `f` of room `r` stands on its floor, turned to face its way (the props face +Z); a large bed out in
	its nook (room_fixtures.gd `bed_middle_u`)."""
	var rooms: RoomsScript = _graph.rooms
	var template: int = rooms.template[r]
	var at: Vector2i = _graph.fit.bed_middle_u(_graph, r, f)
	var face := RoomsScript.rotate_u(Vector2i(RoomsScript.fixture_field(template, f, 3), RoomsScript.fixture_field(template, f, 4)),
		rooms.turns[r])
	return Transform3D(Basis(Vector3.UP, atan2(float(face.x), float(face.y))),
		Vector3(Rules.to_m(at.x), Layers.floor_y(_graph.rooms.level[r]) + FLOOR_LIFT_M, Rules.to_m(at.y)))


func _hearth_place(r: int) -> int:
	"""Room `r`'s hearth place (-1: its template has none)."""
	var template: int = _graph.rooms.template[r]
	for f in RoomsScript.fixture_count(template):
		if FixturesScript.place_kind(template, f) == RoomsScript.FIX_HEARTH:
			return f
	return -1


# --- light, smoke and the chimney ---------------------------------------------------------------

func _light(r: int, lit: bool) -> void:
	"""Room `r`'s hearth lit or cold: its embers, its light, its smoke -- written only when that changes."""
	var now := 1 if lit else 0
	if _lit_now[r] == now and (_embers[r] == null or _embers[r].visible == lit):
		return
	_lit_now[r] = now
	if _embers[r] != null:
		_embers[r].visible = lit
	_smoke[r].emitting = lit and _graph.rooms.level[r] == Rules.TOP_LEVEL
	_fit_lights(r)


func _fit_lights(r: int) -> void:
	"""Room `r`'s rows in the light pool: its hearth's while it is lit, its hung lantern's while it hangs."""
	if _lights == null:
		return
	var hearth := PackedVector3Array()
	var hearth_f := _hearth_place(r)
	if _lit_now[r] == 1 and hearth_f >= 0 and _pieces[r * PLACES + hearth_f] != null and _embers[r] != null:
		hearth.append(place_transform(r, hearth_f) * (_embers[r].position + FIRE_LIGHT))
	_lights.set_hearth_spots(r, hearth)
	var hung := PackedVector3Array()
	for f in RoomsScript.fixture_count(_graph.rooms.template[r]):
		if FixturesScript.place_kind(_graph.rooms.template[r], f) == RoomsScript.FIX_LANTERN \
				and _graph.fit.phase_of(_graph, r, f) == FixturesScript.INSTALLED:
			hung.append(place_transform(r, f) * Vector3(0.0, LANTERN_LIFT_M + 0.15, 0.3))
	_lights.set_fit_spots(r, hung)


func _place_chimney(r: int, f: int) -> void:
	"""Home `r`'s chimney on its mound over its hearth at place `f` (see ON THE GROUND), set into the turf."""
	var rooms: RoomsScript = _graph.rooms
	var local := FixturesScript.place_u(rooms.template[r], f)
	var x := Rules.to_m(local.x)
	var z := Rules.to_m(local.y)
	var top := RoomMeshScript.height_at(x, z, RoomViewScript.mound_reach(rooms.template[r]), RoomViewScript.MOUND_TOP_M)
	var at := place_transform(r, f).origin
	_ground[r].position = Vector3(at.x, top - 0.05, at.z)


# --- filling ---------------------------------------------------------------------------------------

func _fill_cellars() -> void:
	"""Every dug cellar's slots shown to its fill (see FILLING)."""
	if not _fill.is_valid():
		return
	for r in RoomsScript.MAX_ROOMS:
		if _graph.rooms.template[r] == RoomsScript.TEMPLATE_CELLAR and _graph.rooms.is_done(_graph, r):
			show_fill(r, int(_fill.call(r)))


func show_fill(r: int, permille: int) -> void:
	"""Cellar `r`'s slots shown for a fill of `permille`: across its places in order, a slot for each started share;
	its root bin's heap raised to match."""
	var total := 0
	for f in PLACES:
		total += (_slots[r * PLACES + f] as Array).size()
	var shown := ceili(float(clampi(permille, 0, 1000)) * float(total) / 1000.0)
	for f in PLACES:
		for slot: Node3D in _slots[r * PLACES + f]:
			slot.visible = shown > 0
			shown -= 1
			KitScript.fill_heap(slot, permille)


static func _fill_all(slots: Array, full: bool) -> void:
	"""Every slot shown (a home's hanging stores are always full) or left as it is."""
	if full:
		for slot: Node3D in slots:
			slot.visible = true


func shown_slots(r: int) -> int:
	"""How many of cellar `r`'s slots show (checks)."""
	var n := 0
	for f in PLACES:
		for slot: Node3D in _slots[r * PLACES + f]:
			n += 1 if slot.visible else 0
	return n


func piece(r: int, f: int) -> Node3D:
	"""Place `f` of room `r`'s node (null: empty; checks)."""
	return _pieces[r * PLACES + f]


func chimney(r: int) -> Node3D:
	"""Room `r`'s chimney and smoke on the ground (checks)."""
	return _ground[r]


func smoke(r: int) -> CPUParticles3D:
	"""Room `r`'s smoke (checks)."""
	return _smoke[r]
