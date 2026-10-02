extends Node3D
## THE WARREN'S PARTICLE BUDGET: every particle the underground revamp draws, from one fixed allocation. Decision 0211
## (the underground revamp's P5; design docs/design/underground_revamp.md §8 P5: "<= 200 particles live").
## Presentation only.
##
## A CPUParticles3D never has more particles alive than its `amount`, so a budget made of emitters built ONCE, each of a
## fixed amount, holds by construction: the sum of the amounts is the most that can ever be alive. The warren's
## effects are these rows and nothing else (`allocated()` sums them; a test walks the drawings and finds no other
## emitter):
##
##   pool         emitters x amount   layer         what it shows
##   smoke        8 x 16 = 128        surface       a home's chimney while its hearth burns (P4, fixture_kit.gd; a row
##                                                  per room, only homes with a hearth ever light it)
##   face clods   3 x 6  = 18         underground   a burst off a dig face with every quantum cut (dig_theatre.gd)
##   mound clods  3 x 4  = 12         surface       the disturbed earth over a digger below (P0's mound threw 14 a
##                                                  segment, one per segment: unbounded -- now pooled with the faces)
##   dust         2 x 8  = 16         either        a puff: a brace frame raised, a fixture put in, a basket tipped
##   drips        2 x 6  = 12         underground   a seep warning: water dripping from the crown (hazard_view.gd)
##   sand         2 x 6  = 12         underground   a strain warning: sand trickling from the crown
##   total               198 of TOTAL 200
## So at most FACE_SLOTS digs throw clods at once, DUST_SLOTS puffs hang in the air, and HAZARD_SLOTS seeps and strains
## drip and trickle; whoever asks past that is simply not drawn (the theatre gives the slots to the digs and hazards
## that matter most). OUTSIDE the budget: the weather's rain and snow, the woods' chips and leaves and the swimmers'
## bubbles -- their own pools from before the revamp, sized for the whole sky or a felled tree, not the warren's.
##
## Everything runs on the demo clock (`set_speed`): paused, a clod hangs where it is.
## THE BUDGET IS VILLAGE-WIDE (decision 0212): the second level shares these pools -- its faces take the same
## FACE_SLOTS, its hazards the same HAZARD_SLOTS. An emitter below is put on the layer of the level it emits on
## (demo_layers.gd `level_at`) each time it is given a place, so each level's view draws only its own.

const Layers := preload("res://demo/demo_layers.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const KitScript := preload("res://demo/burrow/fixture_kit.gd")

const TOTAL: int = 200
const SMOKE_EMITTERS: int = RoomsScript.MAX_ROOMS
const SMOKE_AMOUNT: int = KitScript.SMOKE_AMOUNT
const FACE_SLOTS: int = 3
const CLOD_AMOUNT: int = 6
const MOUND_AMOUNT: int = 4
const DUST_SLOTS: int = 2
const DUST_AMOUNT: int = 8
const HAZARD_SLOTS: int = 2
const DRIP_AMOUNT: int = 6
const SAND_AMOUNT: int = 6
const CLOD_LIFE_S: float = 0.55
const MOUND_LIFE_S: float = 0.7
const DUST_LIFE_S: float = 1.1
const DRIP_LIFE_S: float = 0.75
const SAND_LIFE_S: float = 0.9
const EARTH: Color = Color(0.302, 0.224, 0.165)
const DAMP_EARTH: Color = Color(0.2, 0.15, 0.11)
const DUST: Color = Color(0.46, 0.38, 0.29)
const WATER: Color = Color(0.46, 0.6, 0.72)
const SAND: Color = Color(0.62, 0.52, 0.34)

var _clods: Array[CPUParticles3D] = []
var _mounds: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _drips: Array[CPUParticles3D] = []
var _sand: Array[CPUParticles3D] = []
var _next_dust: int = 0
## Every emitter of every pool, and the speed they were last set to (see `set_speed`).
var _all: Array[CPUParticles3D] = []
var _speed: float = 1.0
## Bursts and puffs started so far (checks).
var bursts: int = 0
var puffs: int = 0

static var _meshes: Dictionary = {}


static func allocated() -> int:
	"""Every particle the warren may ever have alive at once (see the header's table): the sum of its emitters'
	amounts, smoke included."""
	return SMOKE_EMITTERS * SMOKE_AMOUNT + FACE_SLOTS * (CLOD_AMOUNT + MOUND_AMOUNT) + DUST_SLOTS * DUST_AMOUNT \
			+ HAZARD_SLOTS * (DRIP_AMOUNT + SAND_AMOUNT)


static func capacity_under(root: Node) -> int:
	"""The most particles every CPUParticles3D at and under `root` can have alive at once: the sum of their amounts
	(the stress test's count)."""
	var total := 0
	if root is CPUParticles3D:
		total += (root as CPUParticles3D).amount
	for child in root.get_children():
		total += capacity_under(child)
	return total


static func live_under(root: Node) -> int:
	"""The most particles alive at and under `root` right now: the amounts of the emitters that are emitting (a
	one-shot burst counts while it runs)."""
	var total := 0
	if root is CPUParticles3D and (root as CPUParticles3D).emitting:
		total += (root as CPUParticles3D).amount
	for child in root.get_children():
		total += live_under(child)
	return total


func configure() -> void:
	"""Every pool, once (see the header), none emitting."""
	name = "WarrenParticles"
	assert(allocated() <= TOTAL, "the warren's particles must fit its budget")
	for k in FACE_SLOTS:
		_clods.append(_emitter(CLOD_AMOUNT, CLOD_LIFE_S, clod_mesh(), true, Layers.UNDERGROUND))
		_mounds.append(_emitter(MOUND_AMOUNT, MOUND_LIFE_S, clod_mesh(), false, Layers.SURFACE))
	for k in DUST_SLOTS:
		_dust.append(_emitter(DUST_AMOUNT, DUST_LIFE_S, dust_mesh(), true, Layers.UNDERGROUND))
	for k in HAZARD_SLOTS:
		_drips.append(_emitter(DRIP_AMOUNT, DRIP_LIFE_S, drip_mesh(), false, Layers.UNDERGROUND))
		_sand.append(_emitter(SAND_AMOUNT, SAND_LIFE_S, sand_mesh(), false, Layers.UNDERGROUND))
	for clod_set in _clods:
		_throw(clod_set, 55.0, Vector2(0.8, 1.6), -6.0)
	for mound_set in _mounds:
		_throw(mound_set, 40.0, Vector2(1.0, 1.8), -6.0)
	for dust_set in _dust:
		_billow(dust_set)
	for drip in _drips:
		_fall(drip, 0.02, -9.0)
	for trickle in _sand:
		_fall(trickle, 0.015, -4.0)


func _emitter(amount: int, life: float, mesh: Mesh, burst: bool, layer: int) -> CPUParticles3D:
	"""One emitter of the pool: `amount` particles of `mesh` living `life` seconds, a one-shot `burst` or a stream, on
	`layer`, idle."""
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.mesh = mesh
	p.one_shot = burst
	p.explosiveness = 0.9 if burst else 0.0
	p.local_coords = false
	p.emitting = false
	p.layers = layer
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_all.append(p)
	return p


static func _throw(p: CPUParticles3D, spread: float, speed: Vector2, gravity: float) -> void:
	"""Clods thrown up and out, falling back."""
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3


static func _billow(p: CPUParticles3D) -> void:
	"""A dust puff: soft billboards swelling out and settling."""
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0.0, -0.15, 0.0)
	p.damping_min = 0.6
	p.damping_max = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.55
	p.scale_amount_curve = KitScript.grow_curve()
	p.color_ramp = _dust_ramp()


static func _fall(p: CPUParticles3D, speed: float, gravity: float) -> void:
	"""A thin stream falling from the crown: drips or sand, emitted along a short line (`emission_box_extents` set by
	`set_hazard`)."""
	p.direction = Vector3.DOWN
	p.spread = 4.0
	p.initial_velocity_min = speed
	p.initial_velocity_max = speed * 2.0
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.02, 0.3)


static func _dust_ramp() -> Gradient:
	"""A puff's colour over its life: dust thickening in, then thinning away."""
	var ramp := Gradient.new()
	ramp.set_color(0, Color(DUST, 0.0))
	ramp.set_color(1, Color(DUST, 0.0))
	ramp.add_point(0.2, Color(DUST, 0.45))
	return ramp


# --- the meshes (shared, made once) -------------------------------------------------------------

static func clod_mesh() -> SphereMesh:
	"""A clod of damp earth, lit: a lumpy, faceted ball (few sides, so it reads as a broken lump, not a sphere)."""
	if not _meshes.has("clod"):
		var lump := SphereMesh.new()
		lump.radius = 0.05
		lump.height = 0.075
		lump.radial_segments = 5
		lump.rings = 2
		lump.material = _lit(DAMP_EARTH, 1.0)
		_meshes["clod"] = lump
	return _meshes["clod"]


static func dust_mesh() -> QuadMesh:
	"""A dust puff: the chimney smoke's soft disc (fixture_kit.gd) tinted by the puff's own colour ramp, but LIT -- so
	below it is as dark as the earth round it but where a lantern falls on it, never a glowing ball."""
	if not _meshes.has("dust"):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		var puff_material := StandardMaterial3D.new()
		puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		puff_material.vertex_color_use_as_albedo = true
		puff_material.vertex_color_is_srgb = true
		puff_material.roughness = 1.0
		puff_material.albedo_texture = (KitScript.smoke_mesh().material as StandardMaterial3D).albedo_texture
		quad.material = puff_material
		_meshes["dust"] = quad
	return _meshes["dust"]


static func drip_mesh() -> SphereMesh:
	"""A water drop, stretched as it falls, glinting in lantern light."""
	if not _meshes.has("drip"):
		var drop := SphereMesh.new()
		drop.radius = 0.024
		drop.height = 0.1
		drop.radial_segments = 6
		drop.rings = 3
		drop.material = _glinting(WATER)
		_meshes["drip"] = drop
	return _meshes["drip"]


static func sand_mesh() -> BoxMesh:
	"""A grain run of sand, pale against the dark earth."""
	if not _meshes.has("sand"):
		var grain := BoxMesh.new()
		grain.size = Vector3(0.035, 0.08, 0.035)
		grain.material = _glinting(SAND)
		_meshes["sand"] = grain
	return _meshes["sand"]


static func _lit(colour: Color, roughness: float) -> StandardMaterial3D:
	"""A lit material of `colour` and `roughness`."""
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


static func _glinting(colour: Color) -> StandardMaterial3D:
	"""A material of `colour` that shows in an unlit bore: unshaded, so falling drips and sand read from the RTS camera
	in the dark (a warning, DEC-040 "warned")."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


static func meshes() -> Array[Mesh]:
	"""Every mesh the pools draw (the prewarms')."""
	return [clod_mesh(), dust_mesh(), drip_mesh(), sand_mesh()] as Array[Mesh]


# --- using the pools -------------------------------------------------------------------------------

func burst_clods(slot: int, at: Vector3, toward: Vector3) -> void:
	"""Face slot `slot` throws a burst of clods off the face at `at`, back along `toward` (the way out of the bore)."""
	var p := _clods[slot]
	p.layers = Layers.below(Layers.level_at(at.y))
	p.position = at
	p.direction = (toward + Vector3.UP * 0.8).normalized()
	p.restart()
	bursts += 1


func set_mound(slot: int, at: Vector3, on: bool) -> void:
	"""Face slot `slot`'s clods over its digger's mound on the ground at `at` (off: none)."""
	var p := _mounds[slot]
	if on:
		p.position = at
	if p.emitting != on:
		p.emitting = on


func puff(at: Vector3, layer: int) -> void:
	"""A dust puff at `at` on `layer` (surface or underground): the next of the dust pool, whatever it was doing."""
	var p := _dust[_next_dust]
	_next_dust = (_next_dust + 1) % DUST_SLOTS
	p.layers = layer
	p.position = at
	p.restart()
	puffs += 1


func set_hazard(slot: int, sand: bool, at: Vector3, along: Vector3, half_m: float, on: bool) -> void:
	"""Hazard slot `slot`'s drips (or `sand`) falling from the crown at `at`, spread `half_m` either way along the
	bore's heading `along` (off: none)."""
	var p := _sand[slot] if sand else _drips[slot]
	if on:
		p.layers = Layers.below(Layers.level_at(at.y))
		p.position = at
		p.rotation = Vector3(0.0, atan2(along.x, along.z), 0.0)
		p.emission_box_extents = Vector3(0.18, 0.02, maxf(half_m, 0.1))
	if p.emitting != on:
		p.emitting = on


func set_speed(speed: float) -> void:
	"""Every emitter on the demo clock's speed (0: everything hangs where it is) -- written only when it changes."""
	if speed == _speed:
		return
	_speed = speed
	for p in _all:
		p.speed_scale = speed


func clods(slot: int) -> CPUParticles3D:
	"""Face slot `slot`'s clod emitter (checks)."""
	return _clods[slot]


func mound(slot: int) -> CPUParticles3D:
	"""Face slot `slot`'s mound emitter (checks)."""
	return _mounds[slot]


func dust(k: int) -> CPUParticles3D:
	"""Dust emitter `k` (checks)."""
	return _dust[k]


func hazard(slot: int, sand: bool) -> CPUParticles3D:
	"""Hazard slot `slot`'s drips (or sand) emitter (checks)."""
	return _sand[slot] if sand else _drips[slot]
