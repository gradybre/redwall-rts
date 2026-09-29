extends Node3D
## The live demo: the real game with a small village of real assets and residents. Decision 0196.
##
## `Game` is `scenes/main.tscn`, instanced whole and unmodified: the settlement, the simulation
## clock, UIManager and the HUD all boot exactly as they do in the game, so every figure the HUD
## shows is live. The demo then hides the game's placeholder ground, crowd, sun and camera, and
## draws its own world, cast and camera in their place, and re-skins the HUD in the woodland
## visual language. Nothing here writes into the simulation: the cast's walking is presentation
## only, because the settlement's movement system is not built yet (MOVE gates are open).
##
## DEMO COMMAND (demo/control/): residents can be selected and ordered to move or work, with a
## "Demo party" panel in the HUD's free left column. The controller only needs the cast, the
## world's walkable bounds and the demo camera; it reads input the HUD did not consume. Its tunnel
## tool (demo/tunnel/) also gets the world, which the underground view fades.
##
## TUNNEL WORKS (demo/tunnel/tunnel_ext.gd: hazards, upgrades, chambers, threats) show themselves in the
## "Tunnels & burrows (demo)" panel; `chambers()` lists their chambers, whose root cellars are the
## farm's pantry stores (see FARM).
##
## ONE OF EACH (demo_services.gd, made first and handed to the tunnel works and the farm):
##   * ONE CALENDAR (demo_calendar.gd): farm time, the weather's hour and the date the HUD shows. The
##     farm advances it on the demo clock; the HUD's date trigger prints it (demo/ui/demo_hud_date.gd,
##     through the shell's public `set_status_line`), so the HUD, the farm panel and every notice's
##     stamp read the same date. The settlement's own clock runs on apart, unwritten.
##   * ONE WEATHER (demo/weather/demo_weather.gd, `weather()`): the farm's REAL §5.10 row read hour by
##     hour on that calendar. Its rain is the rain the beds take; it slows surface walking, soaks the
##     tunnels' wet ground and falls on screen.
##   * ONE WATER ADAPTER (village_water.gd, `water()`): the farm's edge query and the tunnels'
##     wet-ground, flood and route queries, answered from the water node's real map
##     (demo/water/water_map.gd) and nowhere else.
##
## WATER (demo/water/demo_water.gd): the stream down the east edge and the pond beyond the south-east
## corner, outside the ±20 m square residents and tunnels keep to; the cast walks the world's and the
## water's merged spots and obstacles. Its flow follows the demo clock and its fishery the demo
## calendar. V cycles the one set of map overlays: the farm's moisture, its ripeness, the water's
## zones, off (demo_farm.gd `add_overlay`).
##   * ONE NOTICE FEED (demo_notices.gd): every farm, weather, tunnel and threat notice, date-stamped,
##     shown bottom centre (demo/ui/demo_news_strip.gd) and, per source, in the two panels. Nothing in
##     the demo raises a HUD alert card: the HUD shows the two earliest unresolved notices and demo
##     lines, which nothing resolves, would hold both cards for good (UI §7).
## The HUD's right column holds ONE demo panel at a time -- the farm's or the tunnels' -- under a tab
## strip (demo/ui/demo_detail_zone.gd); a click on a bed or a tunnel brings its panel.
##
## TIME. The game's clock is started by `Game` itself (scripts/main.gd calls start_game()), and
## UIManager then holds UI-SET-103's opening inspection pause (PLAYER). The demo releases that one
## pause as it opens, so the village is alive and the HUD reads Playing; from then on the HUD's pause
## and 1x / 2x / 4x buttons are the real GameManager's, and the demo follows them: the cast's clock
## (demo_clock.gd) reads GameManager.get_effective_speed() every frame.
##
## FARM (demo/farm/): the six crop beds grow individual pantry ingredients by the settlement's own
## crop arithmetic, worked by the residents; the HUD's Food cell shows the pantry total and its Food
## command opens the Pantry. `_build_farm()` wires it; `storage_providers()` hands it the tunnels'
## root cellars (demo/farm/farm_cellars.gd over burrow_chambers `cellars()`), so a harvest goes to the
## slowest-spoiling store with room, the nearest to its bed among equals -- see farm_storage.gd.

const DemoManifestScript := preload("res://demo/demo_manifest.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const WoodlandSkinScript := preload("res://demo/ui/woodland_skin.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterScript := preload("res://demo/village_water.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const HudDateScript := preload("res://demo/ui/demo_hud_date.gd")
const NewsStripScript := preload("res://demo/ui/demo_news_strip.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const TunnelExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")

## The game scene's own presentation, replaced by the demo's.
const GAME_NODES_TO_HIDE: Array[NodePath] = [^"World/Ground", ^"World/Entities", ^"World/Sun"]
const GAME_CAMERA: NodePath = ^"World/Camera3D"
const GAME_HUD_ROOT: NodePath = ^"UI/HUD/Root"
## The water's inspection overlay, the last step of V's one overlay cycle (demo_farm.gd add_overlay).
const WATER_OVERLAY_NAME: String = "water zones and fishery"
## Process priority: after the farm (priority 0) has advanced the calendar each frame.
const PROCESS_AFTER_CHILDREN: int = 1
## Refit the sun's shadow range when the zoom has moved this far since the last fit.
const SHADOW_REFIT_M: float = 0.5

@onready var _game: Node = $Game

var _world: Node3D = null
var _cast: Node3D = null
var _camera: Node3D = null
var _command: Node3D = null
var _farm: DemoFarmScript = null
var _services: ServicesScript = null
var _hud_date: HudDateScript = HudDateScript.new()
var _news: NewsStripScript = null
var _zone: DetailZoneScript = null
var _water: DemoWaterScript = null
var _shadow_view_m: float = -1.0


func _ready() -> void:
	"""The game has booted (children ready first); build the demo over it. The village processes after
	its children, so the HUD's date is painted after the farm has advanced the calendar this frame."""
	process_priority = PROCESS_AFTER_CHILDREN
	_quiet_game_presentation()
	var manifest: Dictionary = DemoManifestScript.load_manifest()
	if not DemoManifestScript.is_staged(manifest):
		push_warning("demo assets are not staged (tools/stage_demo_assets.py); running on placeholders")
	DemoWorldScript.Look.apply_shadow_quality()
	_build_world(manifest)
	_build_cast(manifest)
	_command = DemoCommandScript.new()
	add_child(_command)
	_command.configure(_cast, _camera.camera(), _game.get_node_or_null(GAME_HUD_ROOT) as Control, _services)
	_command.set_world(_world as DemoWorldScript)
	_build_farm(manifest)
	_build_shared_ui()
	_skin_hud.call_deferred()
	_open_running()


func _build_world(manifest: Dictionary) -> void:
	"""The world, its water (demo/water/: stream, pond, dressing, fishery), and the demo's shared
	services over the water's own map."""
	_world = DemoWorldScript.new()
	add_child(_world)
	_world.build(manifest)
	_water = DemoWaterScript.new()
	add_child(_water)
	_water.build(manifest, _world)
	_services = ServicesScript.new(_water.map())


func _build_cast(manifest: Dictionary) -> void:
	"""The cast on the world's and the water's spots and obstacles, on the game's speed; the water on
	the same clock and the demo calendar; and the camera, which may look over the water."""
	_cast = DemoCastScript.new()
	add_child(_cast)
	_cast.build(manifest, _water.merged_points(_world.points_of_interest()),
		_water.merged_obstacles(_world.obstacles()))
	_cast.clock.bind(GameManager as GameManagerScript)
	_water.bind_clock(_cast.clock, _services.calendar.tick)
	_water.bind_calendar(_services.calendar)
	_camera = DemoCameraScript.new()
	add_child(_camera)
	_camera.configure(DemoWaterScript.view_bounds(_world.bounds()), Vector3.ZERO)
	_camera.make_current()
	_cast.set_bounds(_world.bounds())


func _build_farm(manifest: Dictionary) -> void:
	"""The farm, after the world, the cast, the camera and the command layer it works through."""
	_farm = DemoFarmScript.new()
	add_child(_farm)
	_farm.configure(manifest, _world as DemoWorldScript, _cast as DemoCastScript, _command as DemoCommandScript,
		_camera.camera(), _shell(), storage_providers(), _services)
	_command.tunnels().ext.set_weather_skip(_farm.skip_to_next_weather)
	_command.tunnels().ext.events_view.set_flood_rise(_water.set_flood_rise)
	_farm.add_overlay(WATER_OVERLAY_NAME, _water.set_overlay_shown)


func _build_shared_ui() -> void:
	"""The HUD date on the demo calendar, the news strip, and the right column's one-panel zone."""
	_hud_date.bind(_shell(), _services.calendar, GameManager as GameManagerScript)
	_news = NewsStripScript.new()
	add_child(_news)
	_news.configure(_services.notices)
	_zone = DetailZoneScript.new()
	add_child(_zone)
	_zone.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)
	_zone.add_panel(DetailZoneScript.PANEL_FARM, _farm.bed_panel)
	var ext: TunnelExtScript = (_command as DemoCommandScript).tunnels().ext
	_zone.add_panel(DetailZoneScript.PANEL_TUNNELS, ext.panel)
	_farm.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_FARM))
	ext.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_TUNNELS))


func _shell() -> UiShell:
	"""The game HUD's §4 shell (null without a HUD)."""
	var hud_root: Node = _game.get_node_or_null(GAME_HUD_ROOT)
	return hud_root.get_node_or_null(^"Shell") as UiShell if hud_root != null else null


func storage_providers() -> Array[Callable]:
	"""Food stores beyond the covered store, for the farm's pantry (farm_storage.gd's provider API): the
	tunnels' finished root cellars (demo/farm/farm_cellars.gd over burrow_chambers `cellars()`)."""
	var providers: Array[Callable] = [FarmCellars.provider(chambers())]
	return providers


func water() -> WaterScript:
	"""THE village water adapter (village_water.gd): the farm's edge query and the tunnels' wet-ground,
	flood and route queries all go through it, over the water node's real map."""
	return _services.water


func services() -> ServicesScript:
	"""The demo's shared calendar, weather, water and notice feed."""
	return _services


func _open_running() -> void:
	"""Release UI-SET-103's opening inspection pause, once, so the demo opens running (see TIME). Only
	the PLAYER reason is released; any other held reason stays."""
	if UIManager.opening_pause_applied() and not UIManager.player_has_resumed() and GameManager.is_paused():
		GameManager.resume_game()


func weather() -> WeatherScript:
	"""The demo's one weather (demo/weather/demo_weather.gd): `surface_speed_permille()`, `condition()`,
	`temperature_tenths()`, `rain()`. Driven by the farm's real row; read-only for everyone."""
	return _services.weather


func chambers() -> ChambersScript:
	"""The demo's chambers (demo/burrow/burrow_chambers.gd): `cellars()` for the root cellars' API."""
	return _command.tunnels().ext.works.chambers


func _process(_delta: float) -> void:
	"""Keep the HUD's date on the demo calendar, and the sun's shadow range fitted to the zoom (only
	touched when the zoom moved)."""
	_hud_date.sync()
	var view_m: float = _camera.distance()
	if absf(view_m - _shadow_view_m) < SHADOW_REFIT_M:
		return
	_shadow_view_m = view_m
	_world.set_view_distance(view_m)


func _quiet_game_presentation() -> void:
	"""Hide the game's placeholder ground, crowd and sun, and retire its fixed camera."""
	for path in GAME_NODES_TO_HIDE:
		var node := _game.get_node_or_null(path) as Node3D
		if node != null:
			node.visible = false
	var camera := _game.get_node_or_null(GAME_CAMERA) as Camera3D
	if camera != null:
		camera.current = false


func _skin_hud() -> void:
	"""Apply the woodland skin once the HUD has built its panels."""
	var hud_root := _game.get_node_or_null(GAME_HUD_ROOT) as Control
	if hud_root == null:
		push_warning("no HUD at %s; the demo runs unskinned" % GAME_HUD_ROOT)
		return
	WoodlandSkinScript.apply(hud_root)
