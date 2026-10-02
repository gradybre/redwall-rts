extends Node3D
## The fishery's drawing (water part B, decision 0431): what each resident carries (a net, a trap, an ice kit, a
## basket of fish, a sack of flour, new gear), a net or trap in the water while it fishes (a boat's net over its side on
## station), the pond's ice and the hole
## cut in it, the drying rack's smoke while a batch cures, the mill's churning wheel while it grinds, and a load
## set down at a landing for the next to fetch. Presentation only: it reads fishery.gd and writes nothing. Every node
## is made once; a frame only moves, shows or hides them (no allocation per frame).

const FisheryScript := preload("res://demo/fishery/fishery.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const LockerScript := preload("res://demo/fishery/gear_locker.gd")

## The gear each locker kind is drawn as, and the loads.
const GEAR_KEYS: Array[StringName] = [&"fishing_net", &"eel_trap", &"fishing_rod", &""]
const BASKET_KEY: StringName = &"basket"
const SACK_KEY: StringName = &"sack_pile"
## The ice's colours (presentation): safe ice near-white and opaque, thin ice grey and see-through.
const SAFE_ICE: Color = Color(0.86, 0.92, 0.96, 0.92)
const THIN_ICE: Color = Color(0.7, 0.78, 0.82, 0.64)
const ICE_TOP_Y_M: float = -0.15
## The ice sheet's squares and how far inside the pond's circles it stops (m, presentation).
const ICE_CELL_M: float = 0.08
const ICE_INSET_M: float = 0.2
## The ice draws after the pond's own transparent water (which would otherwise sort over it), the hole after the ice.
const ICE_RENDER_PRIORITY: int = 2
## Where the rack's smoke rises (its fire, between its legs); the mill's wheel side.
const RACK_AT: Vector2 = Vector2(20.9, 11.6)
const MILL_WHEEL_AT: Vector3 = Vector3(25.7, 0.2, -19.5)
const LOAD_POOL: int = 4

var _fishery: FisheryScript = null
var _props: PropsScript = null
var _held: Array[StringName] = []
## Who holds a fishery model now, and who will after this frame (reused; at most a job row each).
var _holding: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _ice: Array[MeshInstance3D] = []
var _ice_material: StandardMaterial3D = StandardMaterial3D.new()
var _hole: MeshInstance3D = null
var _in_water: Array[MeshInstance3D] = []
var _in_water_key: Array[StringName] = []
var _boat_nets: Array[MeshInstance3D] = []
var _loads: Array[MeshInstance3D] = []
var _smoke: CPUParticles3D = null
var _churn: CPUParticles3D = null
var _ice_seen: int = -1


func configure(fishery: FisheryScript, props: PropsScript) -> void:
	"""Draw `fishery` with `props`' models (a fresh, unstaged table when none)."""
	name = "FisheryView"
	_fishery = fishery
	_props = props if props != null else PropsScript.new()
	_held.resize(fishery.cast().actor_count() if fishery.cast() != null else 0)
	_held.fill(&"")
	_build_ice()
	_build_props()
	_smoke = _particles(Vector3(RACK_AT.x, 0.35, RACK_AT.y), Color(0.78, 0.76, 0.72, 0.28), 1.0)
	_churn = _particles(MILL_WHEEL_AT, Color(0.92, 0.96, 1.0, 0.6), 1.6)


func _build_ice() -> void:
	"""One flat sheet over the pond (cells inside any of its circles, so see-through thin ice never doubles where the
	circles overlap); and the hole."""
	_ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_material.roughness = 0.25
	_ice_material.render_priority = ICE_RENDER_PRIORITY
	var sheet := MeshInstance3D.new()
	sheet.mesh = _ice_sheet()
	sheet.material_override = _ice_material
	sheet.visible = false
	add_child(sheet)
	_ice.append(sheet)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.28
	hole.bottom_radius = 0.28
	hole.height = 0.02
	_hole = MeshInstance3D.new()
	_hole.mesh = hole
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.14, 0.18)
	dark.render_priority = ICE_RENDER_PRIORITY + 1
	_hole.material_override = dark
	_hole.position = Vector3(FisheryScript.ICE_HOLE.x, ICE_TOP_Y_M + 0.006, FisheryScript.ICE_HOLE.y)
	_hole.visible = false
	add_child(_hole)


func _ice_sheet() -> ArrayMesh:
	"""The pond's ice as ICE_CELL_M squares, each kept when its centre lies inside a pond circle (inset ICE_INSET_M)."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	@warning_ignore("integer_division") for k: int in WaterLayout.POND_CIRCLES.size() / 4:
		var r: float = WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4 + 2])
		var c := Vector2(WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4]), WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4 + 1]))
		lo = lo.min(c - Vector2(r, r))
		hi = hi.max(c + Vector2(r, r))
	var x: float = lo.x
	while x < hi.x:
		var z: float = lo.y
		while z < hi.y:
			if _in_pond(Vector2(x + ICE_CELL_M * 0.5, z + ICE_CELL_M * 0.5)):
				_ice_cell(tool, x, z)
			z += ICE_CELL_M
		x += ICE_CELL_M
	return tool.commit()


static func _in_pond(at: Vector2) -> bool:
	"""Whether `at` (m) lies inside a pond circle less ICE_INSET_M."""
	@warning_ignore("integer_division") for k: int in WaterLayout.POND_CIRCLES.size() / 4:
		var c := Vector2(WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4]), WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4 + 1]))
		if at.distance_to(c) <= WaterRules.to_m(WaterLayout.POND_CIRCLES[k * 4 + 2]) - ICE_INSET_M:
			return true
	return false


static func _ice_cell(tool: SurfaceTool, x: float, z: float) -> void:
	"""One square of ice, two triangles facing up."""
	var a := Vector3(x, ICE_TOP_Y_M, z)
	var b := Vector3(x + ICE_CELL_M, ICE_TOP_Y_M, z)
	var c := Vector3(x + ICE_CELL_M, ICE_TOP_Y_M, z + ICE_CELL_M)
	var d := Vector3(x, ICE_TOP_Y_M, z + ICE_CELL_M)
	for v: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(v)


func _build_props() -> void:
	"""The gear-in-the-water marks (one per site), the rack's fish (two a slot) and the set-down loads' baskets."""
	for site: int in Rules.SITE_BANK.size():
		var mark: MeshInstance3D = _props.instance(GEAR_KEYS[0])
		mark.visible = false
		add_child(mark)
		_in_water.append(mark)
		_in_water_key.append(&"")
	for boat: int in _fishery.fleet.count:
		var net: MeshInstance3D = _props.instance(GEAR_KEYS[0])
		net.visible = false
		add_child(net)
		_boat_nets.append(net)
	for k: int in LOAD_POOL:
		var basket: MeshInstance3D = _props.instance(BASKET_KEY)
		basket.visible = false
		add_child(basket)
		_loads.append(basket)


func _particles(at: Vector3, colour: Color, size: float) -> CPUParticles3D:
	"""A small, bounded particle puff (presentation: the rack's smoke, the mill's spray), off until wanted."""
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 2.4
	p.position = at
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.6
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = mat
	p.mesh = puff
	p.emitting = false
	add_child(p)
	return p


func refresh() -> void:
	"""Follow the fishery: carried things, gear in the water, the ice, the rack, the mill, set-down loads."""
	if _fishery == null:
		return
	_follow_held()
	_follow_water_gear()
	_follow_ice()
	_follow_rack()
	_follow_loads()
	_churn.emitting = _fishery.grinding()


func _follow_held() -> void:
	"""Each job's worker holds what the fishery says it carries; whoever held something and no longer works a job that
	carries drops it. One pass over the job rows a frame, and a model changed only when it changes."""
	_next.resize(0)
	for j: int in Tables.MAX_JOBS:
		var who: int = _fishery.tables.j_worker[j]
		if _fishery.tables.j_live[j] == 0 or who < 0 or who >= _held.size():
			continue
		var key: StringName = _fishery.held_key_of_job(j)
		if key != &"":
			_show_held(who, key)
			_next.append(who)
	for who: int in _holding:
		if not _next.has(who):
			_show_held(who, &"")
	var swap: PackedInt32Array = _holding
	_holding = _next
	_next = swap


func _show_held(who: int, key: StringName) -> void:
	"""Resident `who` holds the model `key` (&"": nothing)."""
	if _held[who] == key:
		return
	var actor := _fishery.cast().actor(who) as DemoActorScript
	if key == &"":
		actor.drop_held()
	else:
		var bound: AABB = _props.drawn_bound(key)
		actor.hold(_props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key))
	_held[who] = key


func _follow_water_gear() -> void:
	"""A net cast or a trap set lies in the water at its site's bank while it fishes or soaks."""
	for site: int in _in_water.size():
		var key: StringName = _fishery.gear_in_water_at(site)
		_in_water[site].visible = key != &""
		if key != &"" and _in_water_key[site] != key:
			_in_water[site].mesh = _props.mesh_of(key)
			_in_water_key[site] = key
		if key != &"":
			var at: Vector2 = _fishery.bank_water(site)
			_in_water[site].transform = Transform3D(Basis.IDENTITY, Vector3(at.x, -0.3, at.y)) * _props.fit_of(key)
	for boat: int in _boat_nets.size():
		var net_at: Vector2 = _fishery.boat_net_at(boat)
		_boat_nets[boat].visible = net_at.is_finite()
		if net_at.is_finite():
			_boat_nets[boat].transform = Transform3D(Basis.IDENTITY, Vector3(net_at.x, -0.3, net_at.y)) * _props.fit_of(GEAR_KEYS[0])


func _follow_ice() -> void:
	"""The pond's ice: drawn while frozen, safe ice white, thin ice grey and see-through; the hole while an ice trip
	fishes."""
	if _fishery.ice.revision != _ice_seen:
		_ice_seen = _fishery.ice.revision
		_ice_material.albedo_color = SAFE_ICE if _fishery.ice.safe() else THIN_ICE
		for disc: MeshInstance3D in _ice:
			disc.visible = _fishery.ice.frozen()
	_hole.visible = _fishery.ice.frozen() and _fishery.ice_trip_out()


func _follow_rack() -> void:
	"""Smoke rises from the rack's fire while any batch cures (the staged rack shows its hanging fish itself)."""
	_smoke.emitting = _fishery.tables.s_state.has(Tables.SLOT_CURING)


func _follow_loads() -> void:
	"""A load set down where its carrier was called away shows as a basket there."""
	var used: int = 0
	for j: int in Tables.MAX_JOBS:
		if used >= LOAD_POOL:
			break
		if _fishery.tables.j_live[j] == 1 and _fishery.tables.j_load_milli[j] > 0 and _fishery.tables.j_load_at[j].is_finite():
			var at: Vector2 = _fishery.tables.j_load_at[j]
			_loads[used].transform = Transform3D(Basis.IDENTITY, Vector3(at.x, 0.0, at.y)) * _props.fit_of(BASKET_KEY)
			_loads[used].visible = true
			used += 1
	for k: int in range(used, LOAD_POOL):
		_loads[k].visible = false
