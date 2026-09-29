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
## TIME. The game's clock is started by `Game` itself (scripts/main.gd calls start_game()), and
## UIManager then holds UI-SET-103's opening inspection pause (PLAYER). The demo releases that one
## pause as it opens, so the village is alive and the HUD reads Playing; from then on the HUD's pause
## and 1x / 2x / 4x buttons are the real GameManager's, and the demo follows them: the cast's clock
## (demo_clock.gd) reads GameManager.get_effective_speed() every frame.
##
## FARM (demo/farm/): the six crop beds grow individual pantry ingredients by the settlement's own
## crop arithmetic, worked by the residents; the HUD's Food cell shows the pantry total and its Food
## command opens the Pantry. `_build_farm()` wires it; `storage_providers()` is where root cellars
## (and any other food store) are handed to it -- see demo/farm/farm_storage.gd for the API.

const DemoManifestScript := preload("res://demo/demo_manifest.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const WoodlandSkinScript := preload("res://demo/ui/woodland_skin.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmWater := preload("res://demo/farm/farm_water.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")

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
var _farm: DemoFarmScript = null
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
	_cast.build(manifest, _world.points_of_interest(), _obstacles_with_pond())
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
	_build_farm(manifest)
	_skin_hud.call_deferred()
	_open_running()


func _obstacles_with_pond() -> Array[Vector3]:
	"""The world's obstacles and the farm's PLACEHOLDER reed pond (demo/farm/farm_water.gd), which nobody
	walks into. Drop the append when the village's real water merges."""
	var circles: Array[Vector3] = _world.obstacles()
	circles.append(FarmWater.placeholder_obstacle())
	return circles


func _build_farm(manifest: Dictionary) -> void:
	"""The farm, after the world, the cast, the camera and the command layer it works through."""
	_farm = DemoFarmScript.new()
	add_child(_farm)
	var hud_root: Node = _game.get_node_or_null(GAME_HUD_ROOT)
	var shell: UiShell = hud_root.get_node_or_null(^"Shell") as UiShell if hud_root != null else null
	_farm.configure(manifest, _world as DemoWorldScript, _cast as DemoCastScript, _command as DemoCommandScript,
		_camera.camera(), shell, storage_providers(), water_edge_query())


func storage_providers() -> Array[Callable]:
	"""Food stores beyond the covered store, for the farm's pantry (farm_storage.gd's provider API).
	None yet: the root cellars of the tunnel extension are wired here when it merges."""
	return []


func water_edge_query() -> Callable:
	"""The farm's one water query, `(x_u: int, z_u: int) -> bool` (demo/farm/farm_water.gd): the demo
	table for now; point it at the village's real water when feat/demo-water merges."""
	return FarmWater.edge_query()


func _open_running() -> void:
	"""Release UI-SET-103's opening inspection pause, once, so the demo opens running (see TIME). Only
	the PLAYER reason is released; any other held reason stays."""
	if UIManager.opening_pause_applied() and not UIManager.player_has_resumed() and GameManager.is_paused():
		GameManager.resume_game()


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
