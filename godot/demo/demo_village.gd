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
## tool (demo/tunnel/) also gets the world, whose footings and roots the underground view's cap shows.
##
## TUNNEL WORKS (demo/tunnel/tunnel_ext.gd: hazards, upgrades, rooms, threats) show themselves in the
## "Tunnels & burrows (demo)" panel; `rooms()` lists the network's rooms (decision 0209), whose root cellars are the
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
## calendar. MAP LAYERS (decision 0292, demo/map_lenses.gd): one shown at a time, each with one question
## and a legend -- Growing: soil moisture and ripeness (the farm's), Getting there: water range (whose:
## demo/waterplay/water_range.gd), Woods, Underground (U's view, followed). The Map layer picker on the
## minimap's edge (demo/ui/demo_lens_picker.gd) picks them directly; V steps the same one active layer.
##   * ONE NOTICE FEED (demo_notices.gd): every farm, weather, tunnel and threat notice, date-stamped,
##     shown bottom centre (demo/ui/demo_news_strip.gd) and, per source, in the two panels. Nothing in
##     the demo raises a HUD alert card: the HUD shows the two earliest unresolved notices and demo
##     lines, which nothing resolves, would hold both cards for good (UI §7).
## The HUD's right column holds ONE demo panel at a time -- the farm's or the tunnels' -- under a tab
## strip (demo/ui/demo_detail_zone.gd); a click on a bed or a tunnel brings its panel.
##
## TIME. The game's clock is started by `Game` itself (scripts/main.gd calls start_game()), and
## UIManager then holds UI-SET-103's opening inspection pause (PLAYER). The demo releases that one
## pause once its first frames are drawn (demo_prewarm.gd: what would first load mid-game is loaded
## first, and the first frames' pipeline compiles are paid while paused -- decision 0205), so the
## village is alive and the HUD reads Playing; from then on the HUD's pause and 1x / 2x / 4x buttons
## are the real GameManager's, and the demo follows them: the cast's clock (demo_clock.gd) reads
## GameManager.get_effective_speed() every frame.
##
## FARM (demo/farm/): the six crop beds grow individual pantry ingredients by the settlement's own
## crop arithmetic, worked by the residents; the HUD's Food cell shows the pantry total and its Food
## command opens the Pantry. `_build_farm()` wires it; `storage_providers()` hands it the tunnels'
## root cellars (demo/farm/farm_cellars.gd over underground_rooms `cellars()`), so a harvest goes to the
## slowest-spoiling store with room, the nearest to its bed among equals -- see farm_storage.gd.
##
## WATER GAMEPLAY (demo/waterplay/, part A): wading, swimming, diving, rescue and bridges. The residents'
## walking area is widened over the stream, its far bank and round the pond (`walk_bounds`), the water
## too deep to wade joins the cast's obstacles as a band of circles (water_links.gd), and the cast plans
## inside the woods' reach. `_build_waterplay()` wires it after the woods (a log bridge's log may be a
## felled trunk); its "Water (demo)" panel is the right column's fourth tab.
##
## LIVING (decision 0210, demo/burrow/): the rooms' fit-out -- fixtures ordered on a selected room, paid from the one
## stores, put in by residents -- and the night: at dusk everyone goes home to bed (the party panel says whose bed, or
## that it has none), and the farm's pantry tells a cellar's racks how full it is (`cellar_fill`).
##
## SPOIL (demo/spoil/): a tunnel's spoil heaps can be selected and cleared -- dug out and hauled into the
## farm's compost store (Clear: right-click a heap with residents selected). `_build_spoil()` wires it.
##
## WOODS (demo/forestry/): every tree is a real ResourceNode row -- felled, hauled, regrown, blown down,
## replanted -- worked by the residents, with forestry and conservation zones, deadfall, a sawhorse and
## the "Woods (demo)" panel, the right column's third tab. Its wood goes into the demo's ONE stores
## (demo_services.gd `stores`), which the tunnels' bracing and lanterns spend; planting takes its
## compost from the farm's compost store. `_build_forestry()` wires it; its trees' and yard's circles
## join the cast's obstacles before the cast is built.

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
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const HudDateScript := preload("res://demo/ui/demo_hud_date.gd")
const BedsLabelScript := preload("res://demo/ui/demo_beds_label.gd")
const NewsStripScript := preload("res://demo/ui/demo_news_strip.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const TunnelExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WindowKeysScript := preload("res://demo/demo_window_keys.gd")
const StallBannerScript := preload("res://demo/ui/demo_stall_banner.gd")
const CommandTipsScript := preload("res://demo/ui/demo_command_tips.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const SpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const PrewarmScript := preload("res://demo/demo_prewarm.gd")
const TunnelViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const UndergroundPrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const LensPickerScript := preload("res://demo/ui/demo_lens_picker.gd")
const TunnelControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const ForestMarks := preload("res://demo/forestry/forest_marks.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## The game scene's own presentation, replaced by the demo's.
const GAME_NODES_TO_HIDE: Array[NodePath] = [^"World/Ground", ^"World/Entities", ^"World/Sun"]
const GAME_CAMERA: NodePath = ^"World/Camera3D"
const GAME_HUD_ROOT: NodePath = ^"UI/HUD/Root"
## The water's inspection overlay as a map layer (demo_farm.gd add_overlay; decision 0292).
const WATER_LENS_QUESTION: String = "Where can they wade, swim, dive or cross?"
const WOODS_LENS_QUESTION: String = "Which trees may be felled, which must stay?"
const UNDERGROUND_LENS_QUESTION: String = "What lies under the village?"
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
var _beds_label: BedsLabelScript = BedsLabelScript.new()
var _news: NewsStripScript = null
var _stall_banner: StallBannerScript = null
var _zone: DetailZoneScript = null
var _water: DemoWaterScript = null
var _forestry: ForestryScript = null
var _waterplay: WaterplayScript = null
var _links: LinksScript = null
var _spoil: SpoilScript = null
var _prewarm: PrewarmScript = PrewarmScript.new()
var _shadow_view_m: float = -1.0
var _lens_picker: LensPickerScript = null
## The Water range layer's row in the farm's lenses (its subject is set once the water's play is built).
var _water_lens: int = 0


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
	_build_spoil()
	_build_forestry()
	_command.add_skill_text(_command.tunnels().ext.skill_text)
	_command.add_skill_text(_command.tunnels().ext.night.home_text)
	_build_waterplay()
	_build_shared_ui()
	_skin_hud.call_deferred()
	add_child(WindowKeysScript.new())
	_warm_and_open()


func _warm_and_open() -> void:
	"""Load now what would first load mid-game, and start the clock only once the first frames are drawn
	(demo_prewarm.gd, decision 0205) -- the rooms' pieces on the ground sampled (decision 0209), and the
	underground view drawn once with a sample of everything it can show (decision 0206)."""
	add_child(_prewarm)
	_prewarm.add_step("props and icons", _services.props.warm_all)
	_prewarm.add_step("plant atlases", _farm.view.assets.ensure_all_loaded)
	_prewarm.add_step("woods: stumps, saplings, splits", _forestry.view.prewarm)
	var view: TunnelViewScript = (_command as DemoCommandScript).tunnels().view
	var rooms: RoomViewScript = (_command as DemoCommandScript).tunnels().ext.room_view
	_prewarm.add_frame_step("rooms on the ground", UndergroundPrewarmScript.FRAMES, rooms.begin_surface_prewarm,
		rooms.end_surface_prewarm)
	_prewarm.add_frame_step("underground view", UndergroundPrewarmScript.FRAMES, view.begin_prewarm, view.end_prewarm)
	_prewarm.warm()
	_prewarm.release_after_frames(_open_running)


func prewarm() -> PrewarmScript:
	"""The boot prewarm and its report (demo_prewarm.gd)."""
	return _prewarm


func _build_world(manifest: Dictionary) -> void:
	"""The world, its water (demo/water/: stream, pond, dressing, fishery), and the demo's shared
	services over the water's own map."""
	_world = DemoWorldScript.new()
	add_child(_world)
	_world.build(manifest)
	var props := PropsScript.new()
	props.load_from(manifest)
	_water = DemoWaterScript.new()
	add_child(_water)
	_water.build(manifest, _world, props)
	_services = ServicesScript.new(_water.map())
	_services.props = props


func _build_cast(manifest: Dictionary) -> void:
	"""The cast on the world's and the water's spots and obstacles, on the game's speed; the water on
	the same clock and the demo calendar; and the camera, which may look over the water."""
	_cast = DemoCastScript.new()
	add_child(_cast)
	var obstacles: Array[Vector3] = _water.merged_obstacles(_world.obstacles())
	obstacles.append_array(ForestryScript.extra_obstacles(_world as DemoWorldScript))
	obstacles.append_array(WaterplayScript.land_obstacles())
	_links = WaterplayScript.make_links(_water.map(), obstacles)
	obstacles.append_array(_links.band)
	_cast.build(manifest, _water.merged_points(_world.points_of_interest()), obstacles, _links.area)
	_cast.clock.bind(GameManager as GameManagerScript)
	_water.bind_clock(_cast.clock, _services.calendar.tick)
	_water.bind_calendar(_services.calendar)
	_camera = DemoCameraScript.new()
	add_child(_camera)
	var walk: AABB = WaterplayScript.walk_bounds(_world.bounds())
	_camera.configure(DemoWaterScript.view_bounds(walk), Vector3.ZERO)
	_camera.make_current()
	_cast.set_bounds(walk)


func _build_farm(manifest: Dictionary) -> void:
	"""The farm, after the world, the cast, the camera and the command layer it works through."""
	_farm = DemoFarmScript.new()
	add_child(_farm)
	_farm.configure(manifest, _world as DemoWorldScript, _cast as DemoCastScript, _command as DemoCommandScript,
		_camera.camera(), _shell(), storage_providers(), _services)
	_farm.follow_rooms(rooms())
	_command.tunnels().ext.fixture_view.set_fill(_farm.cellar_fill)
	_command.tunnels().ext.set_stored(_farm.cellar_stored_u)
	_command.tunnels().ext.set_weather_skip(_farm.skip_to_next_weather)
	_command.tunnels().ext.events_view.set_flood_rise(_water.set_flood_rise)
	_water_lens = _farm.add_overlay("Getting there", "Water range", WATER_LENS_QUESTION, _water.set_overlay_shown)
	_farm.lenses.set_legend(_water_lens, PackedColorArray([WaterOverlayScript.WADE_COLOUR, WaterOverlayScript.SWIM_COLOUR,
		WaterOverlayScript.DIVE_COLOUR, WaterOverlayScript.FORD_COLOUR, WaterOverlayScript.BRIDGE_COLOUR,
		WaterOverlayScript.LINK_COLOUR, WaterOverlayScript.LANDING_COLOUR]), PackedStringArray(["wade", "swim",
		"dive", "ford", "bridge site", "swim link", "landing"]))


func _build_spoil() -> void:
	"""Spoil heaps to select and clear (demo/spoil/), after the farm, whose spoil books and compost store
	they use, and before the woods, so a click on a heap in a forestry zone is the heap's."""
	_spoil = SpoilScript.new()
	add_child(_spoil)
	_spoil.configure(_cast as DemoCastScript, _command as DemoCommandScript, _camera.camera(), _cast.space().tunnels,
		_farm.tunnels, _services.props, give_compost)


func give_compost(milli: int) -> void:
	"""Put `milli` into the farm's compost store: a cleared heap's spoil (demo/spoil/spoil_crew.gd)."""
	if milli > 0:
		_farm.sim.compost_milli += milli


func spoil() -> SpoilScript:
	"""The spoil heaps' selection and clearing (demo/spoil/demo_spoil.gd)."""
	return _spoil


func _build_forestry() -> void:
	"""The woods, after the farm (the calendar's owner): the world's trees bound to real rows with the
	compiled `wood` item, the crew on the cast, planting's compost from the farm's store, and the woods'
	overlay last on V's cycle."""
	_forestry = ForestryScript.new()
	add_child(_forestry)
	var wood := IntMath.IntResult.new()
	ForestryScript.resolve_wood_id_into(wood)
	_forestry.configure(_world as DemoWorldScript, _cast as DemoCastScript, _command as DemoCommandScript,
		_camera.camera(), _services, wood)
	_forestry.crew.set_compost(compost_left, take_compost)
	_forestry.panel.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)
	var woods: int = _farm.add_overlay("Woods", "Zones and trees", WOODS_LENS_QUESTION, _forestry.set_overlay)
	_farm.lenses.set_legend(woods, PackedColorArray([ForestMarks.FORESTRY_COLOUR, ForestMarks.CONSERVATION_COLOUR,
		Palette.LEAF, Palette.BRASS, Palette.UMBER, Palette.CLAY]), PackedStringArray(["forestry zone",
		"conservation zone", "mature tree", "young tree", "stump", "cleared spot"]))


func compost_left() -> int:
	"""The farm's compost store, milli-U (what planting a sapling spends)."""
	return _farm.sim.compost_milli


func take_compost(milli: int) -> bool:
	"""Take `milli` of the farm's compost -- all of it, or (false) none."""
	if milli <= 0 or _farm.sim.compost_milli < milli:
		return false
	_farm.sim.compost_milli -= milli
	return true


func _build_waterplay() -> void:
	"""The water's gameplay (demo/waterplay/), after the woods: swimming, diving, rescue and bridges on
	the cast already built round the water's band."""
	_waterplay = WaterplayScript.new()
	add_child(_waterplay)
	_waterplay.configure(_cast as DemoCastScript, _command as DemoCommandScript, _camera.camera(), _services,
		_water.map(), _links, _water, _forestry.stand)
	_waterplay.panel.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)
	_farm.lenses.set_subject(_water_lens, _waterplay.water_range)


func waterplay() -> WaterplayScript:
	"""The water's gameplay (demo/waterplay/demo_waterplay.gd)."""
	return _waterplay


func forestry() -> ForestryScript:
	"""The woods (demo/forestry/demo_forestry.gd)."""
	return _forestry


func _build_shared_ui() -> void:
	"""The HUD date on the demo calendar, the news strip (centred on the command strip), the right
	column's one-panel zone (a panel's own × collapses it), the command strip's tooltips, and the
	stall banner (the player's Resume from the clock's REQ-SET-008 diagnostic pause, which stands in
	for and resolves the HUD's overload card)."""
	_hud_date.bind(_shell(), _services.calendar, GameManager as GameManagerScript)
	_beds_label.bind(_shell())
	_stall_banner = StallBannerScript.new()
	add_child(_stall_banner)
	_stall_banner.bind(GameManager as GameManagerScript)
	_stall_banner.bind_shell(_shell())
	CommandTipsScript.apply(_shell())
	_news = NewsStripScript.new()
	add_child(_news)
	_news.configure(_services.notices)
	_zone = DetailZoneScript.new()
	add_child(_zone)
	_news.follow_journal(_zone.journal_open)
	_zone.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)
	_zone.add_panel(DetailZoneScript.PANEL_FARM, _farm.bed_panel)
	var ext: TunnelExtScript = (_command as DemoCommandScript).tunnels().ext
	_zone.add_panel(DetailZoneScript.PANEL_TUNNELS, ext.panel)
	_zone.add_panel(DetailZoneScript.PANEL_WOODS, _forestry.panel)
	_zone.add_panel(DetailZoneScript.PANEL_WATER, _waterplay.panel)
	_build_lens_picker()
	_farm.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_FARM))
	ext.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_TUNNELS))
	_forestry.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_WOODS))
	_waterplay.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_WATER))


func _build_lens_picker() -> void:
	"""The Underground layer (U's view, followed: map_lenses.gd) and the Map layer picker by the minimap,
	clear of the news strip's band."""
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	var under: int = _farm.lenses.add("Underground", "Tunnels", UNDERGROUND_LENS_QUESTION, show_underground)
	_farm.lenses.follow_state(under, func() -> bool: return tool.view.on)
	_farm.lenses.set_legend(under, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]),
		PackedStringArray(["blue hatch: too wet to dig", "stone: building footings", "U: back to the surface"]))
	_lens_picker = LensPickerScript.new()
	add_child(_lens_picker)
	_lens_picker.configure(_farm.lenses, _news.band_in)


func show_underground(on: bool) -> void:
	"""The Underground layer's switch: the tunnels' U view on or off (one cull-mask write)."""
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	if tool.view.on != on:
		tool.toggle_view()


func lens_picker() -> LensPickerScript:
	"""The Map layer picker (demo/ui/demo_lens_picker.gd)."""
	return _lens_picker


func _shell() -> UiShell:
	"""The game HUD's §4 shell (null without a HUD)."""
	var hud_root: Node = _game.get_node_or_null(GAME_HUD_ROOT)
	return hud_root.get_node_or_null(^"Shell") as UiShell if hud_root != null else null


func storage_providers() -> Array[Callable]:
	"""Food stores beyond the covered store, for the farm's pantry (farm_storage.gd's provider API): the
	network's dug root cellars (demo/farm/farm_cellars.gd over underground_rooms `cellars()`), delivered at
	their hatches."""
	var network: GraphScript = (_command as DemoCommandScript).tunnels().network
	var providers: Array[Callable] = [FarmCellars.provider(network)]
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


func rooms() -> RoomsScript:
	"""The network's rooms (demo/burrow/underground_rooms.gd): `cellars(graph)` for the root cellars' API."""
	return _command.tunnels().network.rooms


func _process(_delta: float) -> void:
	"""Keep the HUD's date on the demo calendar and its Beds cell relabelled (demo_beds_label.gd), and the sun's
	shadow range fitted to the zoom (only touched when the zoom moved)."""
	_hud_date.sync()
	_beds_label.sync()
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
