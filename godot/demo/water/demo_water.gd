extends Node3D
## The live demo's water: a stream and a pond in the village, their surface, the depth/shore map
## other systems query, water-side dressing, and the real fishery on demo-clock time. Decision 0196
## (live demo), water foundation -- phase 1 of the water request; phase 2 (movement, boats, bridges,
## fishing gameplay) builds on the interface below.
##
## Interface (stable):
##   build(manifest, world)      carve the world's ground, lay the water and its dressing, start the
##                               fishery. `world` is demo_world.gd (or null: water without a world).
##   bind_clock(clock, tick)     follow the demo clock (demo_clock.gd): flow and fishing stop when
##                               paused and run 2x / 4x with the HUD; the fishery starts at `tick`.
##   bind_calendar(calendar)     run the fishery on the demo's ONE calendar (demo_calendar.gd), tick
##                               for tick, so its days are the farm's and the HUD's days; unbound it
##                               counts the clock's microseconds at the settlement's 30 ticks a second.
##   map()                       the integer depth/shore/zone/flow/crossing/tunnel queries
##                               (water_map.gd) -- the foundation phase 2 depends on.
##   fishing()                   the fishing driver (fishing_driver.gd), or null if the item catalog
##                               could not be bound (the water still draws).
##   points_of_interest()        the water's resident spots, in demo_world.gd's published shape.
##   obstacles()                 the dressing circles residents walk round, (x, radius, z).
##   merged_points(p) / merged_obstacles(o)   the world's lists with the water's appended.
##   toggle_overlay() / set_overlay_shown(on)   the inspection overlay. It has no key of its own: V is
##                               the village's one overlay cycle (demo_farm.gd add_overlay), and the
##                               water's zones are its last step.
##   set_flood_rise(level)       raise the stream to `level` (0..1) of its bank: a flood (demo/events/).
##
## UNDERGROUND VIEW (U, demo/tunnel/tunnel_view.gd) hides the world's Ground node by name and fades
## the Village. The water follows the Ground's own visibility -- its bank film hides with it and the
## surface fades to a faint sheet -- so nothing floats oddly over the deep-earth plane; the dressing
## is parented under the Village and fades with the rest of it. MOVE-REQ-015: presentation only.
##
## Everything here is presentation except the map's integers and the fishing store, and nothing
## writes into the simulation, a pantry or an inventory.

const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoCalendarScript := preload("res://demo/demo_calendar.gd")
const Look := preload("res://demo/world/world_look.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Rules := preload("res://demo/water/water_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterGridScript := preload("res://demo/water/water_grid.gd")
const WaterTerrain := preload("res://demo/water/water_terrain.gd")
const WaterSurfaceScript := preload("res://demo/water/water_surface.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const FishingDriverScript := preload("res://demo/water/fishing_driver.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const BANK_SHADER := preload("res://demo/water/water_bank.gdshader")

## A flood raises the stream this share of its surface's drop below the ground datum (demo value):
## nearly brim-full, so the water climbs its carved banks and spills onto their tops.
const FLOOD_RISE_PERMILLE: int = 900
const GROUND_NODE: NodePath = ^"Ground"
const ENVIRONMENT_NODE: NodePath = ^"Environment"
## Where the camera may look: the stream from the mill to the pond's far shore (m).
const WATER_VIEW: AABB = AABB(Vector3(18.0, 0.0, -30.0), Vector3(18.0, 0.0, 68.0))
const VILLAGE_NODE: NodePath = ^"Village"
## Runs after the cast (process priority 0), which advances the demo clock each frame.
const PROCESS_AFTER_CAST: int = 10
const BANK_NOISE_SEED: int = 31

var _map: WaterMapScript = null
var _grid: WaterGridScript = null
var _surface: WaterSurfaceScript = null
var _skirt: MeshInstance3D = null
var _overlay: WaterOverlayScript = null
var _driver: FishingDriverScript = null
var _clock: DemoClockScript = null
var _species_ids: PackedInt32Array = PackedInt32Array()
var _underground: bool = false
var _calendar: DemoCalendarScript = null
var _stream_surface: Node3D = null
var _flood_rise_m: float = 0.0


func build(manifest: Dictionary, world: Node3D, props: PropsScript = null) -> void:
	"""Lay the water into `world` (see the header), its small props from `props` (the demo's; none:
	boxes). Call once, after world.build()."""
	name = "Water"
	process_priority = PROCESS_AFTER_CAST
	_map = WaterLayout.make_map()
	_grid = WaterGridScript.new()
	_grid.build(_map, Look.GROUND_SIZE_M * 0.5)
	_skirt = WaterTerrain.make_skirt(_grid, _map.bank_run_u(), _bank_material())
	add_child(_skirt)
	_surface = WaterSurfaceScript.new()
	_surface.build(_grid, _map, _sky_colour(world))
	for body: int in _surface.nodes.size():
		add_child(_surface.nodes[body])
		if _map.body_kind(body) == WaterMapScript.KIND_STREAM:
			_stream_surface = _surface.nodes[body]
			_flood_rise_m = Rules.to_m(_map.body_level_drop_u(body) * FLOOD_RISE_PERMILLE / 1000)
	var village: Node3D = world.get_node_or_null(VILLAGE_NODE) as Node3D if world != null else null
	WaterDressing.build(village if village != null else self, manifest.get("world", {}), _map, props)
	if world != null:
		_attach_ground(world)
		_clear_cover(world)
	var ids: FishingDriverScript.IdsResult = FishingDriverScript.resolve_species_item_ids()
	if ids.ok:
		_species_ids = ids.ids
	else:
		push_warning("demo water: fish item ids did not bind (%s); fishing is off" % ids.error)
	_overlay = WaterOverlayScript.new()
	add_child(_overlay)
	_overlay.configure(_map, _grid)


func bind_clock(clock: DemoClockScript, start_tick: int) -> void:
	"""Follow `clock` from now on, and start the fishery on game tick `start_tick` (>= 0)."""
	_clock = clock
	if _driver != null or _species_ids.is_empty():
		return
	var made: FishingDriverScript.CreateResult = FishingDriverScript.create(_species_ids,
		maxi(start_tick, 0), weir_width_u())
	if not made.ok:
		push_warning("demo water: fishing store refused (%s); fishing is off" % made.error)
		return
	_driver = made.driver as FishingDriverScript
	_overlay.set_driver(_driver, _map)


func bind_calendar(calendar: DemoCalendarScript) -> void:
	"""Run the fishery on `calendar` (see the header); its first catch-up happens on the next frame."""
	_calendar = calendar


func set_flood_rise(level: float) -> void:
	"""Raise the stream's surface `level` (0 dry .. 1 in full flood) of FLOOD_RISE_PERMILLE of its
	drop below the ground datum: a flood visibly climbs the real banks. Presentation only."""
	if _stream_surface == null:
		return
	_stream_surface.position.y = _flood_rise_m * clampf(level, 0.0, 1.0)


func flood_rise_m() -> float:
	"""How high the stream's surface stands above its level now, in metres (checks)."""
	return _stream_surface.position.y if _stream_surface != null else 0.0


func flood_rise_full_m() -> float:
	"""How high a full flood raises the stream's surface, in metres (demo/waterplay/: a flood's share)."""
	return _flood_rise_m


func weir_width_u() -> int:
	"""The stream's bank-to-bank width at the weir, in u (0 if the stream was never measured)."""
	var weir: Vector2 = Layout.find_placement(WaterDressing.placements(), &"weir")["at"]
	var width := IntMath.IntResult.new()
	if not _map.stream_width_at_into(Vector2i(Rules.to_u(weir.x), Rules.to_u(weir.y)), width):
		return 0
	return width.value


func map() -> WaterMapScript:
	"""The integer water map (water_map.gd)."""
	return _map


func fishing() -> FishingDriverScript:
	"""The fishing driver, or null when the catalog did not bind or no clock was bound yet."""
	return _driver


func points_of_interest() -> Array[Dictionary]:
	"""The water's resident spots: {name, position, face, activities, capacity}."""
	return WaterDressing.points_of_interest()


func obstacles() -> Array[Vector3]:
	"""The dressing circles residents walk round, Vector3(x, radius, z)."""
	return WaterDressing.obstacles()


func merged_points(world_points: Array[Dictionary]) -> Array[Dictionary]:
	"""`world_points` with the water's spots appended (a new array)."""
	var out: Array[Dictionary] = world_points.duplicate()
	out.append_array(points_of_interest())
	return out


func merged_obstacles(world_obstacles: Array[Vector3]) -> Array[Vector3]:
	"""`world_obstacles` with the water's circles appended (a new array)."""
	var out: Array[Vector3] = world_obstacles.duplicate()
	out.append_array(obstacles())
	return out


func toggle_overlay() -> bool:
	"""Show or hide the inspection overlay; returns whether it is now shown."""
	return _overlay.toggle()


func set_overlay_shown(on: bool) -> void:
	"""Show or hide the inspection overlay (the village's V cycle)."""
	if _overlay.visible != on:
		_overlay.toggle()


func overlay() -> WaterOverlayScript:
	"""The inspection overlay node."""
	return _overlay


func surface() -> WaterSurfaceScript:
	"""The water surfaces (meshes, materials and the flow phase)."""
	return _surface


func is_underground_view() -> bool:
	"""Whether the water is currently drawn for the underground view."""
	return _underground


func _process(_delta: float) -> void:
	"""Advance the flow by this frame's demo time (0 while paused), and the fishery to the demo
	calendar's tick -- or by the frame's microseconds with no calendar bound. No allocation."""
	if _clock == null:
		return
	_surface.advance(_clock.frame_usec)
	if _driver == null:
		return
	if _calendar != null:
		_driver.advance_ticks(maxi(_calendar.tick - _driver.completed_tick(), 0))
	else:
		_driver.advance_usec(_clock.frame_usec)


func set_underground_view(on: bool) -> void:
	"""Draw the water for the underground view (bank film hidden, surface faint) or normally."""
	_underground = on
	_skirt.visible = not on
	_surface.set_underground_view(on)


func _attach_ground(world: Node3D) -> void:
	"""Carve the world's ground and follow its visibility (the underground view hides it)."""
	var ground := world.get_node_or_null(GROUND_NODE) as MeshInstance3D
	if ground == null:
		return
	WaterTerrain.carve_ground(ground, _grid)
	ground.visibility_changed.connect(_on_ground_visibility.bind(ground))


func _on_ground_visibility(ground: MeshInstance3D) -> void:
	"""The ground was hidden or shown: the underground view went on or off."""
	set_underground_view(not ground.visible)


func _clear_cover(world: Node3D) -> void:
	"""Hide the world's grass and mushrooms in the water and on its banks (once, at build)."""
	if not world.has_method(&"hide_cover"):
		return
	var margin: float = Rules.to_m(WaterLayout.BANK_RUN_U)
	var circles := PackedVector3Array()
	for circle: Vector3 in WaterLayout.water_circles_m(margin):
		circles.append(Vector3(circle.x, circle.z, circle.y))
	for circle: Vector3 in WaterDressing.footprint_circles():
		circles.append(Vector3(circle.x, circle.z, circle.y))
	world.call(&"hide_cover", PackedVector2Array(), 0.0, circles)


static func _sky_colour(world: Node3D) -> Color:
	"""The top colour of the world's own sky, so the water reflects exactly that tone."""
	var holder := world.get_node_or_null(ENVIRONMENT_NODE) as WorldEnvironment if world != null else null
	if holder != null and holder.environment != null and holder.environment.sky != null:
		var sky := holder.environment.sky.sky_material as ProceduralSkyMaterial
		if sky != null:
			return sky.sky_top_color
	return WaterSurfaceScript.DEFAULT_SKY


static func view_bounds(world_bounds: AABB) -> AABB:
	"""`world_bounds` grown to take in the water by the village, for the camera's focus only --
	residents and tunnels keep the world's own bounds."""
	return world_bounds.merge(WATER_VIEW)


func _bank_material() -> ShaderMaterial:
	"""The bank film's material: locked-pigment muds (world_look.gd) over a seeded noise."""
	var noise := FastNoiseLite.new()
	noise.seed = BANK_NOISE_SEED
	noise.frequency = 0.04
	var texture := NoiseTexture2D.new()
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	var material := ShaderMaterial.new()
	material.shader = BANK_SHADER
	material.render_priority = 0
	material.set_shader_parameter(&"mud_dry", Look.UMBER.lerp(Look.LEAF, 0.3).lerp(Look.TIMBER, 0.1))
	material.set_shader_parameter(&"mud_wet", Look.UMBER.lerp(Look.INK, 0.5))
	material.set_shader_parameter(&"bed_color", Look.UMBER.lerp(Look.INK, 0.5).lerp(Look.BRASS, 0.15))
	material.set_shader_parameter(&"noise", texture)
	return material
