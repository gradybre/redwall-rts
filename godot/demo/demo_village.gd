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
## TUNNEL WORKS (demo/tunnel/tunnel_ext.gd: weather, hazards, chambers, threats) raise their alerts
## through UIManager.push_alert -- the transient alert zone the game's own opening line uses -- and
## show the rest in their own panel. Two of their pieces are for the rest of the demo to read:
## `weather()`, the demo's one weather source, and `chambers()`, whose `cellars()` lists the root
## cellars (for the farming demo).
##
## TIME. The game's clock is started by `Game` itself (scripts/main.gd calls start_game()), and
## UIManager then holds UI-SET-103's opening inspection pause (PLAYER). The demo releases that one
## pause as it opens, so the village is alive and the HUD reads Playing; from then on the HUD's pause
## and 1x / 2x / 4x buttons are the real GameManager's, and the demo follows them: the cast's clock
## (demo_clock.gd) reads GameManager.get_effective_speed() every frame.

const DemoManifestScript := preload("res://demo/demo_manifest.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const WoodlandSkinScript := preload("res://demo/ui/woodland_skin.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")

## The game scene's own presentation, replaced by the demo's.
const GAME_NODES_TO_HIDE: Array[NodePath] = [^"World/Ground", ^"World/Entities", ^"World/Sun"]
const GAME_CAMERA: NodePath = ^"World/Camera3D"
const GAME_HUD_ROOT: NodePath = ^"UI/HUD/Root"
## Refit the sun's shadow range when the zoom has moved this far since the last fit.
const SHADOW_REFIT_M: float = 0.5

@onready var _game: Node = $Game

var _world: Node3D = null
var _cast: Node3D = null
var _camera: Node3D = null
var _command: Node3D = null
var _shadow_view_m: float = -1.0


func _ready() -> void:
	"""The game has booted (children ready first); build the demo over it."""
	_quiet_game_presentation()
	var manifest: Dictionary = DemoManifestScript.load_manifest()
	if not DemoManifestScript.is_staged(manifest):
		push_warning("demo assets are not staged (tools/stage_demo_assets.py); running on placeholders")
	DemoWorldScript.Look.apply_shadow_quality()
	_world = DemoWorldScript.new()
	add_child(_world)
	_world.build(manifest)
	_cast = DemoCastScript.new()
	add_child(_cast)
	_cast.build(manifest, _world.points_of_interest(), _world.obstacles())
	_cast.clock.bind(GameManager as GameManagerScript)
	_camera = DemoCameraScript.new()
	add_child(_camera)
	_camera.configure(_world.bounds(), Vector3.ZERO)
	_camera.make_current()
	_cast.set_bounds(_world.bounds())
	_command = DemoCommandScript.new()
	add_child(_command)
	_command.configure(_cast, _camera.camera(), _game.get_node_or_null(GAME_HUD_ROOT) as Control)
	_command.set_world(_world as DemoWorldScript)
	_command.set_alert(UIManager.push_alert)
	_skin_hud.call_deferred()
	_open_running()


func _open_running() -> void:
	"""Release UI-SET-103's opening inspection pause, once, so the demo opens running (see TIME). Only
	the PLAYER reason is released; any other held reason stays."""
	if UIManager.opening_pause_applied() and not UIManager.player_has_resumed() and GameManager.is_paused():
		GameManager.resume_game()


func weather() -> WeatherScript:
	"""The demo's one weather source (demo/weather/demo_weather.gd): `surface_speed_permille()`,
	`condition()`, `temperature_tenths()`, `rain()`. Read-only for everyone but the tunnel works."""
	return _command.tunnels().ext.works.weather


func chambers() -> ChambersScript:
	"""The demo's chambers (demo/burrow/burrow_chambers.gd): `cellars()` for the root cellars' API."""
	return _command.tunnels().ext.works.chambers


func _process(_delta: float) -> void:
	"""Keep the sun's shadow range fitted to the zoom; only touch it when the zoom moved."""
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
