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
## bottom left (demo/ui/demo_lens_picker.gd) picks them directly; V steps the same one active layer.
##   * ONE NOTICE FEED (demo_notices.gd): every farm, weather, tunnel and threat notice, date-stamped,
##     shown bottom centre (demo/ui/demo_news_strip.gd) and, per source, in the two panels. Nothing in
##     the demo raises a HUD alert card: the HUD shows the two earliest unresolved notices and demo
##     lines, which nothing resolves, would hold both cards for good (UI §7).
##   * VILLAGE NEWS (decision 0331, review F11, F37, UX-011): the feed's history window (demo/ui/demo_news_history.gd:
##     every kept entry, filtered by place and severity, with "Go to"), the incidents behind the warnings
##     (demo_incidents.gd: kept until resolved or acknowledged), the top-centre card queue of the critical and
##     pinned ones (demo/ui/demo_incident_cards.gd), and the news clock that stops toasts ageing while paused.
##     The news strip's button, the card's and the HUD's own history command (N, its trigger: `_on_shell_action`)
##     all open the window; it stands in for the shell's history in the top-centre zone, and offers the shell's
##     "Settlement notices" from its header. `_build_news()` wires it, and each target kind's "Go to".
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
## THE HUD'S VILLAGE READ MODEL (decision 0251, `_build_village_hud`): the top bar's counters and their ledger read
## the village's own stores, pantry, cast and homes (demo/ui/demo_hud_model.gd, demo_hud_counters.gd) -- the same
## figures the panels show, never written into the simulation; the Residents command lists the cast
## (demo/ui/demo_roster.gd); the minimap draws the village (demo/ui/demo_minimap.gd).
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
## SPOIL (demo/spoil/): a tunnel's spoil heaps can be selected and cleared -- their earth dug out and hauled into the
## village stores by the stockpile (Clear: right-click a heap with residents selected), where Raise and Bank fetch it
## again. Earth is never compost (decision 0401). `_build_spoil()` wires it.
##
## CANOPY (demo/camera/canopy_clear.gd, decision 0301): the camera's eye is held out of tree crowns, the
## crowns between the eye and the focus or a selected resident thin out, and a selected resident shows as
## a silhouette through foliage and roofs. `_build_canopy()` wires it after the woods; its materials are
## drawn once at boot (a prewarm frame step).
##
## SEASONS (demo/seasons/, decision 0551): the woods, the grass and the ground follow the one calendar -- fresh
## green and catkins in spring, a staggered turn to gold and russet in autumn with a few leaves falling, bare
## boughs in winter -- every tree in its model's ONE tree material (the canopy's) with per-tree instance numbers.
## `_build_seasons()` wires it after the canopy; the Demo Lab's Season preview draws a preset season.
## CAMERA MODES (demo/camera/camera_modes.gd, decision 0801): bookmarks (Ctrl+Shift / Shift + 1-4), follow the
## selected resident (End), orbit the building in view (Shift+O) and the U view's cutaway angle (Shift+U), with the
## edge pan and a strip saying which is on. `_build_camera_modes()` wires them.
##
## WOODS (demo/forestry/): every tree is a real ResourceNode row -- felled, hauled, regrown, blown down,
## replanted -- worked by the residents, with forestry and conservation zones, deadfall, a sawhorse and
## the "Woods (demo)" panel, the right column's third tab. Its wood goes into the demo's ONE stores
## (demo_services.gd `stores`), which the tunnels' bracing and lanterns spend; planting takes its
## compost from the farm's compost store. `_build_forestry()` wires it; its trees' and yard's circles
## join the cast's obstacles before the cast is built.
##
## INPUT, MENU AND KEYBOARD (decision 0261): ONE INPUT GATE (demo/ui/demo_input_gate.gd), added last so it
## reads every event first, owns the demo's modals -- the Pantry, the game menu (demo/ui/demo_menu.gd) and
## the Demo Lab (demo/ui/demo_lab.gd) -- and keyboard focus in the panels (F7, Tab, Enter/Space by focused
## context). The HUD's Menu button, and Esc once nothing else takes it (`_unhandled_input`, which runs
## after every child's), open the game menu; F8 opens the Lab, which holds the demo's test triggers.
##
## WORK (decision 0411, demo/work/): ONE WORK BOARD over every job owner -- the farm, the woods, the bridges, the
## tunnels' jobs, the rooms' fit-out, the spoil heaps -- claims their waiting work for idle eligible residents (the
## named, editable crews first: Field, Woods, Diggers, Haulers, Builders), in place of the old hidden fixed crews;
## the HUD's Jobs command (J) opens its Work screen (tasks, residents and crews, projects); Shift+right-click appends to
## the selection's order lists. `_build_work()` wires it once every owner is built -- the kitchen's cook and water
## drawers listed too, and no work handed out to a resident at its meal (`add_kitchen`, decision 0381 with 0411).
##
## GROUP SELECTION (decision 0791, demo/control/group_select.gd): control groups (Ctrl+0-9 keep, 0-9 select, twice: go
## to), a double click's residents of a kind in view, the box's "Selecting residents: n", Select idle, and the party
## panel's group section for two or more -- their status, a tile each, one crew for all, Send to... `group_select()` is
## where an owner adds a status row the group section shows (group_status.gd: e.g. Chilled, Injured).
##
## THE FIRST-VILLAGE GUIDE (decision 0481, demo/guide/; review F49, P7, UX-017 to UX-020): one objective card at a time,
## each completed only by its real outcome in the village (a resident inspected, a harvest shelved, a supper eaten, a
## bridge crossed / a tunnel walked / a bed readied before the frost), with a marker in the world; the village guide
## window behind the HUD's Objectives command (O) -- objectives, player-named projects, the field guide, the searchable
## help (also the game menu's Help page) and practice stories kept apart from the village. `_build_guide()` binds it to
## the village's real models (read only) and `_build_input()` hands it the menu, the Lab and the gate.
##
## PEOPLE (decision 0491, demo/people/; review group T: P6, SOC-001, SOC-014, SOC-028): the cast is an original
## community, each resident named, with an interest, from ONE data file (demo/people/demo_people.json) through every
## surface's `display_name`; trades stay roles. ONE people owner (demo_people.gd) records each COMMITTED deed -- a rescue
## that succeeded, a bridge, tunnel or room built, a first harvest, a skill level, a first meal cooked for everyone --
## and affinity from shared work and suppers (the GDD's own numbers), feeds the party panel's resident inspector, offers
## a spotlight after a distinctive deed and a reflection at a season's end (people_card.gd), and posts at most one
## light evening line a day. `_build_people()` wires it once the work board and the news are built.
##
## THE VILLAGE CHRONICLE (decision 0631, demo/chronicle/): at each season's end a short page in a record-keeper's voice
## -- the harvest and the table, weather and trouble, deeds, friendships, songs and gatherings -- written only from what
## the village recorded (the news by entry id, the incidents' lines, the farm's record, the people's ledger, the songs),
## and a book of the pages behind Village news' and the village guide's "Chronicle" (no key of its own). Its tapestry
## hook (`chronicle().page_written`) is left for the great hall. `_build_chronicle()` wires it after the guide.
##
## SOUND (decision 0351, demo/sound/): ONE SOUND OWNER (sound_director.gd), scene-scoped rather than an autoload,
## hears the village's committed events (its event map, sound_taps.gd) and plays them through six buses (the sixth,
## Songs, decision 0442) with a bounded voice pool; its volumes and mixes are the game menu's Settings. No sound files are staged yet, so it
## plays silent; its streams load in the boot prewarm.
##
## TIME CONTROLS (decision 0471, review UX-022, demo/session/): THE PAUSE LEDGER tells the pause types apart -- the
## player's, the game menu's, a planning surface's (Pause while planning, off by default) and a critical incident's
## (on by default) -- the PAUSE CARD top centre says each and offers the one Resume (Space too), and "RUN UNTIL..."
## (the button in the time cluster, G) runs the village to dawn, dusk, the next meal, a project, a harvest or a warning
## and pauses saying so. `_build_session()` wires it; the game menu holds its pause through the ledger.
##
## THE FERRY (decision 0437, demo/ferry/; review ECO-041): one fixed two-landing cargo ferry from the ferry stage on the
## run to the far stage at the stream's mouth -- the boat core's third boat on its fixed route, a staffed timetable, a
## departure threshold, weather closure -- carrying the far copse's windfall to the log stack, with a passenger seat
## the router may choose (water_crossings.gd FERRY_ROW). `_build_ferry()` wires it after the fishery, whose fleet,
## skills and ice it shares; its section is the Water panel's, its jobs the work board's.
##
## THE REGATTA (decision 0438, demo/regatta/; review SOC-023, SOC-025, UX-028): once a season -- the first in summer -- a
## boat race on the pond between the boathouse's two rowboats and the GDD's Hearth feast at the day's supper (the
## kitchen's occasion), its day and host the player's, remembered in the chronicle. `_build_regatta()` wires it after the
## people (the winners' deed, the feast's company); its section is the Water panel's, and the HUD's Feast command opens it.
##
## THE WINTER (decision 0571, demo/winter/; Brendan's rulings of 2026-10-01): the hearths -- the hall's and every fitted
## burrow home's -- burn the stores' wood by the GDD's continuous demand, rooms cool without it, residents build up
## exposure in the cold and are Chilled at 4 hours (working at 80% and warming up at a lit hearth), the woods keep a
## Firewood order (urgent under 2 fuel-days), the top bar's Fuel cell is UI-SET-003's Heating fuel again (its click
## opens the fuel breakdown with the emergency choices), the planner has a Fuel lane, and the Demo Lab's "Skip to next
## season" brings winter. `_build_winter()` wires it after the woods (its firewood) and the kitchen (its cooking wood);
## `_build_work()` hands it the work board.
##
## THE HALL (decision 0771, demo/hall/): the community hall grows in Brendan's adopted two stages -- the hall the village
## starts with, then its one tier-2 upgrade (REQ-SET-136) -- and up to four banners, each carried in and built by the
## residents through the work board; clicking the hall opens its panel, and from it the village tapestry, whose
## add-entry API (`tapestry()`, demo/hall/tapestry.gd THE API) the chronicle and milestones may weave into; `hall()`
## answers the feasts' gathering query. `_build_hall()` wires it once the work board and the guide are built.
##
## FORAGING TRIPS (decision 0681, demo/forage/; feature #22, review ECO-013/014): a small party sent into the woods for
## nuts, mushrooms or herbs, back hours later with a haul for the pantry -- the real forage store's one basin (§5.5's
## seasons, daily quota, sustainable floor and regrowth) on the demo calendar. `_build_forage()` wires it after the
## ferry; its section is the Woods panel's, its seats the work board's, its spots a public way on the Routes layer.
##
## ACCESSIBILITY (decision 0471, review UX-023, demo/access/): the four presets and their settings in the menu's
## Settings, applied live (`_on_access_changed`, access_effects.gd); the OBJECT LIST (F6) of every resident, bed, tree,
## bridge, tunnel mouth and room, and the rings that show them (village_targets.gd); the focus hints.

const DemoManifestScript := preload("res://demo/demo_manifest.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const WoodlandSkinScript := preload("res://demo/ui/woodland_skin.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const TendingScript := preload("res://demo/farm/farm_tending.gd")
const KitchenNodeScript := preload("res://demo/kitchen/demo_kitchen.gd")
const FisheryNodeScript := preload("res://demo/fishery/demo_fishery.gd")
const FerryNodeScript := preload("res://demo/ferry/demo_ferry.gd")
const RegattaNodeScript := preload("res://demo/regatta/demo_regatta.gd")
const ForageNodeScript := preload("res://demo/forage/demo_forage.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterScript := preload("res://demo/village_water.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const HudDateScript := preload("res://demo/ui/demo_hud_date.gd")
const HudCountersScript := preload("res://demo/ui/demo_hud_counters.gd")
const RosterScript := preload("res://demo/ui/demo_roster.gd")
const MinimapScript := preload("res://demo/ui/demo_minimap.gd")
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
const InputGateScript := preload("res://demo/ui/demo_input_gate.gd")
const ActionCardScript := preload("res://demo/ui/action_card.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const LabScript := preload("res://demo/ui/demo_lab.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const TunnelPanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const ForestPanelScript := preload("res://demo/forestry/forest_panel.gd")
const WaterPanelScript := preload("res://demo/waterplay/water_panel.gd")
const CanopyScript := preload("res://demo/camera/canopy_clear.gd")
const SeasonViewScript := preload("res://demo/seasons/season_view.gd")
const CameraModesScript := preload("res://demo/camera/camera_modes.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const LensPickerScript := preload("res://demo/ui/demo_lens_picker.gd")
const LensKitScript := preload("res://demo/lenses/demo_lens_kit.gd")
const TunnelControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const ForestMarks := preload("res://demo/forestry/forest_marks.gd")
const NewsHistoryScript := preload("res://demo/ui/demo_news_history.gd")
const IncidentCardsScript := preload("res://demo/ui/demo_incident_cards.gd")
const NewsJumpScript := preload("res://demo/ui/demo_news_jump.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const SoundScript := preload("res://demo/sound/sound_director.gd")
const DemoWorkScript := preload("res://demo/work/demo_work.gd")
const GroupSelectScript := preload("res://demo/control/group_select.gd")
const GroupStatusScript := preload("res://demo/control/group_status.gd")
const StoresNodeScript := preload("res://demo/stores/demo_stores.gd")
const WeirViewScript := preload("res://demo/water/weir_gate_view.gd")
const SongsScript := preload("res://demo/songs/demo_songs.gd")
const RoutesScript := preload("res://demo/routes/demo_routes.gd")
const RescueCardScript := preload("res://demo/routes/rescue_card.gd")
const TimeControlScript := preload("res://demo/session/time_control.gd")
const PauseCardScript := preload("res://demo/ui/demo_pause_card.gd")
const RunMenuScript := preload("res://demo/ui/demo_run_menu.gd")
const AccessEffectsScript := preload("res://demo/access/access_effects.gd")
const TargetsScript := preload("res://demo/access/world_targets.gd")
const MarksScript := preload("res://demo/access/target_marks.gd")
const HintScript := preload("res://demo/access/focus_hint.gd")
const ObjectListScript := preload("res://demo/access/object_list.gd")
const VillageTargets := preload("res://demo/access/village_targets.gd")
const Access := preload("res://demo/access/demo_access.gd")
const FarmSimScript := preload("res://demo/farm/farm_sim.gd")
const OpeningPantryScript := preload("res://demo/farm/opening_pantry.gd")
const FarmCatalog := preload("res://demo/farm/farm_catalog.gd")
const GuideScript := preload("res://demo/guide/demo_guide.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const GuideWorldScript := preload("res://demo/guide/guide_world.gd")
const HelpTopics := preload("res://demo/guide/help_topics.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const PeopleScript := preload("res://demo/people/demo_people.gd")
const PeopleCardScript := preload("res://demo/people/people_card.gd")
const ChronicleScript := preload("res://demo/chronicle/demo_chronicle.gd")
const ChronicleWindowScript := preload("res://demo/chronicle/chronicle_window.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const ForestSkills := preload("res://demo/forestry/forest_skills.gd")
const DigSkills := preload("res://demo/tunnel/dig_skills.gd")
const BridgeCrew := preload("res://demo/waterplay/bridge_crew.gd")
const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const PlaytestTaps := preload("res://demo/playtest/playtest_taps.gd")
const WinterScript := preload("res://demo/winter/demo_winter.gd")
const StandingScript := preload("res://demo/orders/demo_standing.gd")
## GameManager's host-clock field the season skip re-bases (see `forgive_host_time`).
const HOST_USEC_FIELD: StringName = &"_last_host_usec"
## The food art's herb patch (decision 0941), drawn for the infirmary's patch when staged (decision 0903).
const HERB_PATCH_KEY: StringName = &"herb_patch"
const EvergreensScript := preload("res://demo/world/evergreens.gd")
const FuelPanelScript := preload("res://demo/winter/fuel_panel.gd")
const DayNightScript := preload("res://demo/world/day_night.gd")
const NightLightsScript := preload("res://demo/world/night_lights.gd")
const WorldLayout := preload("res://demo/world/world_layout.gd")
const ModularSession := preload("res://scripts/core/underground_session.gd")
const ModularSources := preload("res://demo/cast/underground_content_set.gd")
const MolePresentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const EntryWorkerView := preload("res://demo/cast/entry_worker_view.gd")
const EntryWorkerMeshes := preload("res://demo/cast/entry_worker_meshes.gd")
const ModularDemoMode := preload("res://demo/burrow/modular_demo_mode.gd")
const DaylightCurves := preload("res://demo/world/daylight_curves.gd")
const HearthFuelScript := preload("res://demo/winter/hearth_fuel.gd")
const HallScript := preload("res://demo/hall/demo_hall.gd")
const TapestryScript := preload("res://demo/hall/tapestry.gd")
const CareScript := preload("res://demo/infirmary/demo_care.gd")
const OrchardScript := preload("res://demo/orchard/demo_orchard.gd")

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
## An interface scale is offered only where it leaves the HUD this many logical pixels tall: 1280x720 at 125 %
## (decision 0391). Every demo panel reflows or scrolls there, and the bottom band's news strip and Map layer picker
## each keep a place clear of the right column; at 150 % on 1280x720 (480 rows) those two have no room apart, so
## that size stays refused. It was 720 -- 1280x720 at 100 % only -- under decision 0261.
const MIN_LOGICAL_HEIGHT: float = 576.0
## ... and this many wide (1280x720 at 125 %): narrower, the Map layer picker no longer fits between the party column
## and the right column and would share the news strip's gap (a 1440x900 or 1280x1024 window at 150 %; decision 0391).
const MIN_LOGICAL_WIDTH: float = 1024.0
## Frames the canopy's fade and silhouette samples, and the frost and snow overlay, are drawn for at boot
## (as the U view's, decision 0206).
const CANOPY_PREWARM_FRAMES: int = 2
const COVER_PREWARM_FRAMES: int = 2
## Frames the night's look is drawn for at boot (decision 0541: the shadowless moon, the glow and the lit pool).
const NIGHT_PREWARM_FRAMES: int = 2

@onready var _game: Node = $Game

var _world: Node3D = null
var _cast: Node3D = null
var _camera: Node3D = null
var _command: Node3D = null
var _farm: DemoFarmScript = null
var _kitchen: KitchenNodeScript = null
var _services: ServicesScript = null
var _hud_date: HudDateScript = HudDateScript.new()
var _counters: HudCountersScript = HudCountersScript.new()
var _roster: RosterScript = null
var _minimap: MinimapScript = null
var _news: NewsStripScript = null
var _stall_banner: StallBannerScript = null
var _zone: DetailZoneScript = null
var _water: DemoWaterScript = null
var _forestry: ForestryScript = null
var _waterplay: WaterplayScript = null
var _links: LinksScript = null
var _spoil: SpoilScript = null
var _canopy: CanopyScript = null
var _seasons: SeasonViewScript = null
## Art pass 2's pines and yews in the outer woods (demo/world/evergreens.gd; decision 0903).
var _evergreens: EvergreensScript = null
var _prewarm: PrewarmScript = PrewarmScript.new()
var _shadow_view_m: float = -1.0
var _gate: InputGateScript = InputGateScript.new()
var _menu: MenuScript = MenuScript.new()
var _lab: LabScript = LabScript.new()
var _sound: SoundScript = SoundScript.new()
## Whether this boot holds its own PLAYER pause until the first frames are drawn (a restart: UI-SET-103's
## opening pause is held only once per process).
var _held_open: bool = false
var _lens_picker: LensPickerScript = null
## The map layers' hover readout and compare outlines (decision 0581).
var _lens_kit: LensKitScript = null
## The Water range layer's row in the farm's lenses (its subject is set once the water's play is built).
var _water_lens: int = 0
var _history: NewsHistoryScript = null
var _cards: IncidentCardsScript = null
var _jump: NewsJumpScript = NewsJumpScript.new()
var _work: DemoWorkScript = null
var _group_select: GroupSelectScript = null
## The food stores at work: surplus food carried into a cool cellar (decision 0611).
var _stores: StoresNodeScript = null
var _weir_view: WeirViewScript = null
var _songs: SongsScript = null
## The route and infrastructure previews (decision 0461) and their map layer's row.
var _routes: RoutesScript = null
var _routes_lens: int = -1
var _time: TimeControlScript = TimeControlScript.new()
var _card: PauseCardScript = PauseCardScript.new()
var _run_menu: RunMenuScript = RunMenuScript.new()
var _effects: AccessEffectsScript = AccessEffectsScript.new()
var _targets: TargetsScript = TargetsScript.new()
var _marks: MarksScript = MarksScript.new()
var _hint: HintScript = HintScript.new()
var _objects: ObjectListScript = ObjectListScript.new()
var _guide: GuideScript = null
var _people: PeopleScript = null
var _people_card: PeopleCardScript = null
var _camera_modes: CameraModesScript = null
## The HUD's alert stack, found once (the pause card asks whether it shows every frame it is up; decision 0931).
var _alert_stack: Control = null
## The village chronicle and its book (decision 0631).
var _chronicle: ChronicleScript = null
var _chronicle_window: ChronicleWindowScript = null
## Water part B (decision 0431): fishing trips, boats, gear, ice, the drying rack and the mill.
var _fishery: FisheryNodeScript = null
## Water part B lane 3 (decision 0437): the ferry. (Decision 0438): the regatta.
var _ferry: FerryNodeScript = null
var _regatta: RegattaNodeScript = null
var _winter: WinterScript = null
var _standing: StandingScript = null
var _fuel_panel: FuelPanelScript = FuelPanelScript.new()
## The day and the night (decision 0541): the light on the calendar, and the surface's pooled night lights.
var _day_night: DayNightScript = null
var _night_lights: NightLightsScript = null
var _hall: HallScript = null
var _care: CareScript = null
## Feature #22 (decision 0681): the foraging trips.
var _forage: ForageNodeScript = null
## THE ORCHARD (decisions 0671-0677; demo/orchard/): built after the spoil heaps, before the woods (its clicks first).
var _orchard: OrchardScript = null
var _modular_mode: ModularDemoMode = null
## ADR1201/1211: one pinned presentation image per mole profile source (actor, assembly handling, wood haul, stone).
var _modular_sources: ModularSources = null
## ADR1211: the entry crew's worker Actors and the G5 surface walk to the stair-top anchor.
var _entry_worker: EntryWorkerView = null


func _ready() -> void:
	"""The game has booted (children ready first); build the demo over it. The village processes after
	its children, so the HUD's date is painted after the farm has advanced the calendar this frame. The playtest
	log (decision 0562) starts first, so its logger hears the rest of the boot."""
	PlaytestLog.ensure(get_tree())
	process_priority = PROCESS_AFTER_CHILDREN
	_quiet_game_presentation()
	var manifest: Dictionary = DemoManifestScript.load_manifest()
	if not DemoManifestScript.is_staged(manifest):
		push_warning("demo assets are not staged (tools/stage_demo_assets.py); running on placeholders")
	DemoWorldScript.Look.apply_shadow_quality()
	_build_world(manifest)
	_mount_modular_foundation()
	_build_cast(manifest)
	_build_entry_worker(manifest)
	_command = DemoCommandScript.new()
	add_child(_command)
	_command.configure(_cast, _camera.camera(), _game.get_node_or_null(GAME_HUD_ROOT) as Control, _services)
	_command.set_world(_world as DemoWorldScript)
	(_command as DemoCommandScript).set_centre((_camera as DemoCameraScript).centre_on)
	_build_farm(manifest)
	_build_kitchen()
	_build_spoil()
	_build_orchard()
	_build_forestry()
	_build_canopy()
	_build_winter()
	_build_seasons()
	_command.add_skill_text(_command.tunnels().ext.skill_text, true)
	_command.add_skill_text(_command.tunnels().ext.night.home_text)
	_command.set_fed_text(fed_and_warm_text)
	_build_waterplay()
	_build_fishery()
	_build_ferry()
	_build_care()
	_build_forage()
	_build_shared_ui()
	_build_daylight()
	_build_work()
	_build_stores()
	_build_routes()
	_build_people()
	_build_regatta()
	_build_sound()
	_build_guide()
	_bind_goal_measures()
	_build_camera_modes()
	_build_chronicle()
	_build_hall()
	_skin_hud.call_deferred()
	add_child(WindowKeysScript.new())
	_hold_restart_open()
	_warm_and_open()
	_build_input()
	_build_modular_room_mode()
	PlaytestTaps.wire(self, _gate, _zone, _farm.lenses, _command as DemoCommandScript, _services.notices,
		_services.calendar)


func _warm_and_open() -> void:
	"""Load now what would first load mid-game, and start the clock only once the first frames are drawn
	(demo_prewarm.gd, decision 0205) -- the rooms' pieces on the ground sampled (decision 0209), and the
	underground view drawn once with a sample of everything it can show (decision 0206)."""
	add_child(_prewarm)
	_day_night.begin_day_prewarm()
	_prewarm.add_step("props and icons", _services.props.warm_all)
	_prewarm.add_step("plant atlases", _farm.view.assets.ensure_all_loaded)
	_prewarm.add_step("woods: stumps, saplings, splits", _forestry.view.prewarm)
	_prewarm.add_step("woods: bare boughs", _seasons.prepare_bare)
	_prewarm.add_step("sound streams", _sound.warm)
	if _songs != null and _songs.hum != null:
		_prewarm.add_step("song hums", _songs.hum.warm)
	var view: TunnelViewScript = (_command as DemoCommandScript).tunnels().view
	var room_view: RoomViewScript = (_command as DemoCommandScript).tunnels().ext.room_view
	_prewarm.add_frame_step("rooms on the ground", UndergroundPrewarmScript.FRAMES, room_view.begin_surface_prewarm,
		room_view.end_surface_prewarm)
	_prewarm.add_frame_step("underground view", UndergroundPrewarmScript.FRAMES, view.begin_prewarm, view.end_prewarm)
	_prewarm.add_frame_step("canopy fade and silhouette", CANOPY_PREWARM_FRAMES, _canopy.begin_prewarm, _canopy.end_prewarm)
	var weather_view: WeatherViewScript = (_command as DemoCommandScript).tunnels().ext.weather_view
	_prewarm.add_frame_step("frost and snow overlay", COVER_PREWARM_FRAMES, weather_view.begin_prewarm, weather_view.end_prewarm)
	_prewarm.add_frame_step("the night's light", NIGHT_PREWARM_FRAMES, _day_night.begin_prewarm, _day_night.end_prewarm)
	_prewarm.add_frame_step("falling leaves", COVER_PREWARM_FRAMES, _seasons.begin_prewarm, _seasons.end_prewarm)
	_prewarm.warm()
	_prewarm.release_after_frames(_open_running)


func prewarm() -> PrewarmScript:
	"""The boot prewarm and its report (demo_prewarm.gd)."""
	return _prewarm


func _mount_modular_foundation() -> void:
	"""Give the actual settlement its single source-qualified underground foundation, without free construction."""
	var sources: ModularSources = ModularSources.new()
	# Content 6 publishes the wood and stone haul rows (ADR1200/1206), so both haul images load (ADR1211).
	var code: StringName = MolePresentation.load_sources(sources, true, true)
	if code == &"":
		_modular_sources = sources
	if code == &"" and not SettlementSystem.mount_underground(sources.content(MolePresentation.SOURCE_ACTOR)):
		code = SettlementSystem.last_refusal()
	if code == &"" and not SettlementSystem.compose_underground_room_owners():
		code = SettlementSystem.last_refusal()
	if code == &"" and not SettlementSystem.compose_underground_route_owners():
		code = SettlementSystem.last_refusal()
	if code != &"":
		UIManager.push_refusal(code)
		push_warning("Underground foundation unavailable: %s" % code)


func _build_entry_worker(manifest: Dictionary) -> void:
	"""ADR1211: one hidden worker Actor per loaded source for the entry crew, driven from its actual selected row.
	A composition refusal (assets not staged, a fingerprint mismatch) is retained and alerted only when the crew's
	resident is underground and would need drawing; the renderer's absence in a headless run is not a game gap."""
	if _modular_sources == null:
		return
	_entry_worker = EntryWorkerView.new()
	_entry_worker.name = "EntryWorker"
	add_child(_entry_worker)
	var code: StringName = _entry_worker.configure(SettlementSystem, _cast, _modular_sources, UIManager.push_refusal)
	if code != &"":
		UIManager.push_refusal(code)
		return
	_entry_worker.compose_actors(EntryWorkerMeshes.build(manifest, _services.props))


func _build_modular_room_mode() -> void:
	"""Open actual-world dirt planning from the existing tunnel panel; retain the older village on close."""
	_modular_mode = ModularDemoMode.new()
	add_child(_modular_mode)
	var code: StringName = _modular_mode.configure(SettlementSystem, self, _camera as DemoCameraScript,
		_stall_banner, [_camera, _camera_modes, _camera_modes.edge] as Array[Node], _modular_view_blocked)
	if code != &"": UIManager.push_refusal(code)
	_tunnel_tool().ext.panel.action.connect(_modular_panel_action)


func _modular_panel_action(action: StringName) -> void:
	"""The new blueprint action belongs to the original settlement's inspector, not a legacy dig timer."""
	if action != TunnelPanelScript.ACTION_MODULAR_ROOM: return
	var code: StringName = _modular_mode.open()
	if code != &"": UIManager.push_refusal(code)


func _modular_view_blocked() -> bool:
	"""Existing modals and the original stall banner keep their input ownership during a view handover."""
	return _gate.modal_open() or _stall_banner.is_shown()


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
	obstacles.append_array(WeirViewScript.land_obstacles())
	obstacles.append_array(OrchardScript.land_obstacles())
	obstacles.append_array(EvergreensScript.land_obstacles((_world as DemoWorldScript).trees()))
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
	_farm.tending.set_policy(TendingScript.GROUP_FIELD, TendingScript.POLICY_SOW, true)
	_command.tunnels().bed_laid = _farm.sim.is_laid
	_build_weir_view()
	_command.tunnels().ext.fixture_view.set_fill(_farm.cellar_fill)
	_command.tunnels().ext.set_stored(_farm.cellar_stored_u)
	_command.tunnels().ext.set_weather_skip(_farm.skip_to_next_weather)
	_command.tunnels().ext.events_view.set_flood_rise(_water.set_flood_rise)
	_water_lens = _farm.add_overlay("Getting there", "Water range", WATER_LENS_QUESTION, _water.set_overlay_shown)
	_farm.lenses.set_legend(_water_lens, PackedColorArray([WaterOverlayScript.WADE_COLOUR, WaterOverlayScript.SWIM_COLOUR,
		WaterOverlayScript.DIVE_COLOUR, WaterOverlayScript.FORD_COLOUR, WaterOverlayScript.BRIDGE_COLOUR,
		WaterOverlayScript.LINK_COLOUR, WaterOverlayScript.LANDING_COLOUR, WaterOverlayScript.ICE_SAFE_COLOUR,
		WaterOverlayScript.ICE_THIN_COLOUR]), PackedStringArray(["wade", "swim", "dive", "ford", "bridge site", "swim link",
		"landing", "safe ice (winter)", "thin ice: keep off"]))
	# The Routes layer beside the water's, both "Getting there" (the previews it shows are built later: _show_routes).
	_routes_lens = _farm.add_overlay("Getting there", "Routes", RoutesScript.QUESTION, _show_routes)
	_farm.lenses.set_legend(_routes_lens, RoutesScript.legend_swatches(), RoutesScript.legend_words())


func _build_weir_view() -> void:
	"""The weir's sluice gate and the garden leat's head, following the farm's leat (decision 0441)."""
	_weir_view = WeirViewScript.new()
	add_child(_weir_view)
	var weir := _world.find_child("Water_weir", true, false) as MeshInstance3D
	var surface := _water.surface()
	var material: Material = surface.materials[0] if surface != null and not surface.materials.is_empty() else null
	_weir_view.build(weir, material, _farm.leat, (_cast as DemoCastScript).clock)


func weir_view() -> WeirViewScript:
	"""The weir's sluice gate and the leat head (checks and the scripted run)."""
	return _weir_view


func _build_kitchen() -> void:
	"""The kitchen (demo/kitchen/, decision 0381): the meal loop over the farm's pantry and the village's stores, its
	cook the night's early riser; its tab in the Pantry; and the pantry the demo opens with (decision 0912). (Each
	resident's fed rows join the party panel in `_ready`, `set_fed_text`: their own rows after what it is doing,
	decision 0391.)"""
	_kitchen = KitchenNodeScript.new()
	add_child(_kitchen)
	var command := _command as DemoCommandScript
	_kitchen.configure(_cast as DemoCastScript, _farm.pantry, _services, _farm.goods, command.tunnels().ext.night)
	var tab := _kitchen.build_tab(command.selected, command.interrupt_text)
	tab.said.connect(command.say)
	_farm.pantry_panel.set_kitchen(_kitchen.kitchen, tab)
	_farm.bind_kitchen(_kitchen.kitchen)
	var stored: int = OpeningPantryScript.stock(_farm.pantry, _farm.record, _services.calendar.hour_index())
	if stored != OpeningPantryScript.total_milli():
		push_error("the opening pantry stored %d of %d milli-U" % [stored, OpeningPantryScript.total_milli()])


func kitchen() -> KitchenNodeScript:
	"""The village's kitchen (demo/kitchen/demo_kitchen.gd)."""
	return _kitchen


func _build_spoil() -> void:
	"""Spoil heaps to select and clear (demo/spoil/), after the farm, whose earth books they use, into the village
	stores, and before the woods, so a click on a heap in a forestry zone is the heap's."""
	_spoil = SpoilScript.new()
	add_child(_spoil)
	_spoil.configure(_cast as DemoCastScript, _command as DemoCommandScript, _camera.camera(), _cast.space().tunnels,
		_farm.tunnels, _services.props, _services.stores)


func spoil() -> SpoilScript:
	"""The spoil heaps' selection and clearing (demo/spoil/demo_spoil.gd)."""
	return _spoil


func _build_orchard() -> void:
	"""THE ORCHARD (demo/orchard/, decisions 0671-0677): the trees, the hedge, the nursery and the grove over the farm's
	pantry (its basket stands are in `storage_providers`) and compost; its hooks into the woods, the seasons, the
	right column and the work board are made as those are built."""
	_orchard = OrchardScript.new()
	add_child(_orchard)
	_orchard.configure(_world as DemoWorldScript, _cast as DemoCastScript, _command as DemoCommandScript,
		_camera.camera(), _services, _farm.pantry)
	_orchard.set_compost(compost_left, take_compost)
	_orchard.panel.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)


func orchard() -> OrchardScript:
	"""The village's orchard (demo/orchard/demo_orchard.gd)."""
	return _orchard


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
	_forestry.crew.set_protected(_orchard.grove_protects)
	_orchard.set_woods(_forestry.stand)
	_forestry.panel.watch_hud(_game.get_node_or_null(GAME_HUD_ROOT) as Control)
	var woods: int = _farm.add_overlay("Woods", "Zones and trees", WOODS_LENS_QUESTION, _forestry.set_overlay)
	_farm.lenses.set_legend(woods, PackedColorArray(ForestMarks.LEGEND_COLOURS), PackedStringArray(ForestMarks.LEGEND_NAMES))


func _build_canopy() -> void:
	"""The crowns kept out of the camera's way and the selected residents' silhouettes, over the woods'
	trees (demo/camera/canopy_clear.gd)."""
	_canopy = CanopyScript.new()
	add_child(_canopy)
	_canopy.configure(_camera as DemoCameraScript, _forestry.stand, _forestry.view, _cast as DemoCastScript,
		_command as DemoCommandScript)


func _build_winter() -> void:
	"""THE WINTER (see above): the hearths, the cold and the firewood over the village's stores, cast, homes, night,
	kitchen and the farm's real §5.10 row; the planner's Fuel lane; the fuel breakdown behind the Heating fuel cell."""
	_winter = WinterScript.new()
	add_child(_winter)
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_winter.configure(_services, _cast as DemoCastScript, tool.network, tool.ext.night, _farm.sim.crop_weather().weather())
	_winter.bind_kitchen(_kitchen.kitchen)
	_farm.planner.set_fuel(_winter.fuel)
	add_child(_fuel_panel)
	_fuel_panel.bind(_winter)


func winter() -> WinterScript:
	"""The village's winter (demo/winter/demo_winter.gd)."""
	return _winter


func fuel_panel() -> FuelPanelScript:
	"""The Heating fuel breakdown (demo/winter/fuel_panel.gd)."""
	return _fuel_panel


func fed_and_warm_text(i: int, alone: bool) -> String:
	"""The party panel's needs rows for resident `i`: the kitchen's fed rows, then the winter's cold line (Chilled and
	why, or the exposure building) when there is one."""
	var fed: String = _kitchen.kitchen.fed_text(i, alone)
	var warm: String = _winter.status_text(i, alone)
	if warm.is_empty():
		return fed
	return warm if fed.is_empty() else fed + ("\n" if alone else " · ") + warm


func fed_and_warm_word(i: int) -> String:
	"""The roster's fed word for resident `i`, and "chilled" after it when it is."""
	var word: String = _winter.status_word(i)
	return _kitchen.kitchen.fed_word(i) + ("" if word.is_empty() else " · " + word)


func skip_to_next_season() -> int:
	"""The Demo Lab's "Skip to next season" (decision 0571; demo/winter/season_skip.gd): the farm advances the calendar,
	the winter in lockstep. The real time the skip itself took is FORGIVEN, as a harness's screenshot is
	(docs/ENVIRONMENT.md: a long frame stalls the clock into its CRITICAL pause) -- the player asked for the jump; it is
	not a stall. The hours stepped."""
	var hours: int = _winter.skip_to_next_season(_farm.advance_calendar)
	forgive_host_time()
	return hours


static func forgive_host_time() -> void:
	"""Forgive the settlement clock the real time just spent (the harnesses' screenshot rule, docs/ENVIRONMENT.md): its
	host clock is re-based. GameManager has no public entry for it, so its field is set by name -- and checked, so a
	rename fails loudly here and in test_demo_winter.gd rather than letting the skip trip the stall pause."""
	if not (HOST_USEC_FIELD in GameManager):
		push_error("demo_village: GameManager has no %s to forgive the skip's real time" % HOST_USEC_FIELD)
		return
	(GameManager as GameManagerScript).set(HOST_USEC_FIELD, Time.get_ticks_usec())


func canopy() -> CanopyScript:
	"""The canopy clearance (demo/camera/canopy_clear.gd)."""
	return _canopy


func _build_seasons() -> void:
	"""The seasons on the woods, the grass and the ground (demo/seasons/season_view.gd), each tree in the canopy's
	material for its model."""
	_seasons = SeasonViewScript.new()
	add_child(_seasons)
	_seasons.configure(_services.calendar, (_cast as DemoCastScript).clock, _world as DemoWorldScript, _forestry.stand,
		_forestry.view, (_command as DemoCommandScript).tunnels().ext.weather_view, _canopy.fade_material_for)
	_seasons.add_trees(_orchard.view)
	var world := _world as DemoWorldScript
	_evergreens = EvergreensScript.new()
	add_child(_evergreens)
	if _evergreens.build(world.make_piece, world.is_staged, world.trees()) > 0:
		_seasons.add_trees(_evergreens)
	var rows: Dictionary = DemoManifestScript.load_manifest()["world"]
	_seasons.use_authored_bare(String((rows.get("oak_mature", {}) as Dictionary).get("path", "")),
		String((rows.get("oak_mature_bare", {}) as Dictionary).get("path", "")))


func seasons() -> SeasonViewScript:
	"""The seasons' view (demo/seasons/season_view.gd)."""
	return _seasons


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
	(_command as DemoCommandScript).add_ground_handlers(_farm.on_weir_click, func(_screen: Vector2) -> bool: return false)


func _build_fishery() -> void:
	"""WATER PART B (demo/fishery/, demo/boats/; decision 0431), after the water's play: the fishery over the water's
	fishing driver, the farm's pantry and the kitchen's reservations; its sections in the Water panel, its boats in the
	rescue, its jobs on the work board (`_build_work`)."""
	_fishery = FisheryNodeScript.new()
	add_child(_fishery)
	_fishery.configure(_cast as DemoCastScript, _command as DemoCommandScript, _services, _waterplay, _water,
		_farm.pantry, _kitchen.kitchen.takes, _water.map())


func fishery() -> FisheryNodeScript:
	"""The village's fishery (demo/fishery/demo_fishery.gd)."""
	return _fishery


func _build_ferry() -> void:
	"""THE FERRY (see the header), after the fishery: the boat core's ferry boat, the fishery's FISH skills and the pond's
	ice, the water's crossings (its passenger row) and the Water panel's Ferry section; its jobs on the work board
	(`_build_work`) and its line on the Routes layer (`_build_routes`)."""
	_ferry = FerryNodeScript.new()
	add_child(_ferry)
	_ferry.configure(_cast as DemoCastScript, _command as DemoCommandScript, _services, _waterplay, _fishery)


func ferry() -> FerryNodeScript:
	"""The village's ferry (demo/ferry/demo_ferry.gd)."""
	return _ferry


func _build_care() -> void:
	"""THE INFIRMARY (demo/infirmary/, decisions 0621-0623), after the kitchen, the water and the fishery: injuries and
	their care on the cast, the night's beds and the network's rooms, the kitchen's hunger and the water's stamina and
	hazards; its lines on the resident card, its factor on the work pace; the infirmary building placed from its section
	in the Tunnels panel, built from the village stores at the open stockpile and the care shelf through the work board
	(`_build_work` lists its places)."""
	_care = CareScript.new()
	add_child(_care)
	var command: DemoCommandScript = _command as DemoCommandScript
	var tool: TunnelControlScript = command.tunnels()
	_care.configure(_cast as DemoCastScript, _services, tool.ext.night, _cast.space().tunnels, _kitchen.kitchen.fed,
		_waterplay.state, _services.work_pace)
	_care.configure_building(SpoilScript.drop_point(_cast as DemoCastScript), tool.room_site, tool.site_key,
		tool.network, _camera.camera(), command.say, func() -> void:
			if tool.planning:
				tool.cancel_plan())
	command.add_skill_text(_care.card_text)
	command.add_task_text(_care.building.builders.doing_text)
	command.add_input_hook(_care.building.handle_input)
	tool.ext.panel.add_section(_care.section)
	_care.desk.pantry_herb = _pantry_herb
	var world := _world as DemoWorldScript
	if world.is_staged(HERB_PATCH_KEY):
		_care.patch_view.use_model(world.make_piece(HERB_PATCH_KEY, Vector2.ZERO, 0.4, 1.0))
	_winter.bind_infirmary(_care.building.project.is_done, _care.building.project.has_patients)


func _cast_key_of(who: int) -> StringName:
	"""Resident `who`'s cast key (its portrait's key, demo_props.gd `portrait`; decision 0903), or &"" when there is no
	such resident."""
	if who < 0 or who >= (_cast as DemoCastScript).actor_count():
		return &""
	return ((_cast as DemoCastScript).actor(who) as DemoActorScript).creature_key


func _pantry_herb(milli: int) -> int:
	"""The care shelf's share of the pantry's herb (care_desk.gd ONE SHELF, TWO SOURCES; decision 0902): up to `milli` of
	the free herb -- the foragers' -- taken out of its stores for the shelf."""
	return _kitchen.kitchen.takes.withdraw_free(_farm.pantry, FarmCatalog.CAT_HERB, milli, _services.calendar.hour_index())


func care() -> CareScript:
	"""The village's infirmary (demo/infirmary/demo_care.gd)."""
	return _care


func _build_forage() -> void:
	"""FORAGING TRIPS (see the header), after the ferry: the woods' forage basin, the trips into the farm's pantry, the
	Woods panel's Foraging section; its seats on the work board (`_build_work`)."""
	_forage = ForageNodeScript.new()
	add_child(_forage)
	_forage.configure(_cast as DemoCastScript, _command as DemoCommandScript, _services, _farm.pantry, _forestry.panel)
	var world := _world as DemoWorldScript
	if _forage.place_spots(world.make_piece, world.is_staged) > 0:
		_seasons.add_trees(_forage.view)


func forage() -> ForageNodeScript:
	"""The village's foraging trips (demo/forage/demo_forage.gd)."""
	return _forage


func _build_work() -> void:
	"""The village's work (see WORK): the board over every owner built so far, its screen behind the HUD's Jobs command,
	and Shift+right-click's queue -- after the shared UI, whose "Go to" its screen uses."""
	_work = DemoWorkScript.new()
	add_child(_work)
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_work.configure(_cast as DemoCastScript, _farm, _forestry, _waterplay, _spoil, tool.ext, tool.is_digger)
	_work.add_kitchen(_kitchen.kitchen)
	_work.add_fishery(_fishery.fishery)
	_work.add_ferry(_ferry.ferry)
	_build_standing()
	_winter.bind_work(_forestry.crew, _work.board, _standing.book)
	_work.add_care(_care.building.builders)
	if _forage.is_ready():
		_work.add_forage(_forage.trips)
	_work.add_orchard(_orchard.jobs)
	var command: DemoCommandScript = _command as DemoCommandScript
	_work.set_readouts(command.activity_text, (GameManager as GameManagerScript).is_paused, work_jump, command.selected)
	command.set_queue_handler(_work.queue_at)
	_work.unlock_jobs_command(_shell())
	_work.screen.close_requested.connect(_work.screen.close)
	_build_group_select()


func _build_group_select() -> void:
	"""GROUP SELECTION (decision 0791): over the command layer and the work board's crews, its needs read from the
	kitchen and the night's beds; the winter's Chilled (decision 0571) and the infirmary's Injured (decision 0622) a
	status row each."""
	_group_select = GroupSelectScript.new()
	add_child(_group_select)
	var command: DemoCommandScript = _command as DemoCommandScript
	_group_select.configure(command, _cast as DemoCastScript, _work.board, (_camera as DemoCameraScript).centre_on)
	_group_select.panel.set_portraits(_services.props, _cast_key_of)
	_group_select.bind_needs(_kitchen.kitchen.fed_word, command.tunnels().ext.night)
	_group_select.statuses.add(&"chilled", "Chilled", GroupStatusScript.SEVERITY_WARN, _winter.cold.is_chilled)
	_group_select.statuses.add(&"injured", "Injured", GroupStatusScript.SEVERITY_WARN, _care.desk.state.is_hurt)


func group_select() -> GroupSelectScript:
	"""The village's group selection (demo/control/group_select.gd): `group_select().statuses.add(...)` puts a status in
	the group section (group_status.gd)."""
	return _group_select


func _build_standing() -> void:
	"""THE STANDING ORDERS (decision 0711, demo/orders/): goals kept on the game hour through the owners' own boards,
	their section on the Work screen; the winter's Firewood joins the same book as a built-in order (`bind_work`)."""
	_standing = StandingScript.new()
	add_child(_standing)
	_standing.configure(_services, _work.board, _forestry, _farm.crew, _farm.sim, _farm.pantry, _kitchen.kitchen,
		_winter.firewood_urgent)
	_work.screen.set_standing(_standing.make_view())


func standing() -> StandingScript:
	"""The village's standing orders (demo/orders/demo_standing.gd)."""
	return _standing


func _build_stores() -> void:
	"""The food stores at work (demo/stores/, decision 0611): surplus food carried from a warmer store into a cool root
	cellar -- the farm's pantry, the kitchen's reservations left alone, on the demo calendar -- its moves on the work
	board as HAULING."""
	_stores = StoresNodeScript.new()
	add_child(_stores)
	var takes: RefCounted = _kitchen.kitchen.takes
	var pantry: RefCounted = _farm.pantry
	_stores.configure(_cast as DemoCastScript, (_command as DemoCommandScript).tunnels().network, _farm.pantry,
		func(lot: int) -> int: return int(takes.call(&"free_milli", pantry, lot)), _farm.sim.calendar.hour_index,
		_farm.goods)
	_build_cellar_buildings()
	_work.add_stores(_stores.haul, _farm.pantry, _stores.builders)
	(_command as DemoCommandScript).add_task_text(_stores.doing_text)


func _build_cellar_buildings() -> void:
	"""The cellar buildings (demo/stores/, decision 0612): placed from the Pantry's "Build a cellar…" (which closes the
	Pantry and arms the placing tool), built from the village stores at the open stockpile by residents through the work
	board, each a cellar store of the pantry once built."""
	var command: DemoCommandScript = _command as DemoCommandScript
	var tool: TunnelControlScript = command.tunnels()
	_stores.configure_cellars(_services.stores, _farm.goods.props, SpoilScript.drop_point(_cast as DemoCastScript),
		tool.room_site, tool.site_key, tool.network, _camera.camera(), command.say)
	_stores.set_unlock_facts(_cellar_unlock_facts)
	_farm.pantry_panel.add_store_control(_stores.bar)
	_stores.bar.build_requested.connect(func() -> void:
		_farm.pantry_panel.toggle()
		_stores.start_placing())
	command.add_input_hook(_stores.handle_input)


func _cellar_unlock_facts() -> Vector4i:
	"""What the cellar building's unlock reads (cellar_rules.gd THE UNLOCK): the calendar day, the residents living,
	the cast's size and the portions eaten so far (the kitchen's nearest count of portions made). The demo's cast never
	changes -- no deaths, no immigration -- so the residents living are the cast (decision 0612 P1)."""
	@warning_ignore("integer_division")  # whole days by intent
	var day: int = _farm.sim.calendar.hour_index() / 24 + 1
	var cast_size: int = (_cast as DemoCastScript).actor_count()
	return Vector4i(day, cast_size, cast_size, _kitchen.kitchen.portions_eaten)


func stores() -> StoresNodeScript:
	"""The food stores at work (demo/stores/demo_stores.gd)."""
	return _stores


func _build_hall() -> void:
	"""The hall (see THE HALL), once the work board, the guide and the people are built: its projects on the work board,
	its click and right-click after every other ground handler, the farm's harvest log for the tapestry, the night's
	bedless for its panel; the top-centre cards yield to its panel, which stands where they do."""
	_hall = HallScript.new()
	add_child(_hall)
	var command: DemoCommandScript = _command as DemoCommandScript
	_hall.configure(_cast as DemoCastScript, _services, _world, _camera.camera())
	_hall.tapestry_panel.set_art(_services.props)
	_hall.bind_board(_work.board)
	_hall.bind_farm(_farm.crew)
	_hall.set_selection(command.selected)
	_hall.set_bedless(command.tunnels().ext.night.bedless_names)
	command.add_ground_handlers(_hall.on_click, _hall.on_order)
	_cards.hide_while(_hall.is_open)
	if _guide != null:
		_guide.card.hide_while(_hall.is_open)
	if _people_card != null:
		_people_card.hide_while(_hall.is_open)
	_hall.set_hearth(_hall_hearth_words, _winter.stamp)
	_weave_history()


func _hall_hearth_words() -> String:
	"""The hall's hearth now, in the winter's words (demo_winter.gd `hearth_words`: heated -- fuelled and demanded, the
	`hearth_fuel.gd hearth_lit(HALL)` state -- out of fuel, not needed today...), for the hall's panel."""
	return _winter.hearth_words(HearthFuelScript.HALL)


func _weave_history() -> void:
	"""THE TAPESTRY'S OTHER WEAVERS (decision 0902): each chronicle page written (decision 0631's hook) and each goal
	reached (decision 0781) is also woven into the hall's tapestry, each once."""
	if _chronicle != null:
		_chronicle.page_written = _weave_page
	if _guide != null:
		_guide.goals.also_reached = _weave_goal


func _weave_page(absolute_season: int, title: String, summary: String) -> void:
	"""A chronicle page written: a chronicle knot, once a season."""
	_hall.tapestry.add_entry(TapestryScript.KIND_CHRONICLE, title, summary, StringName("chronicle:%d" % absolute_season))


func _weave_goal(goal_id: StringName, title: String, said: String) -> void:
	"""A goal or milestone reached: a milestone knot, once a goal."""
	_hall.tapestry.add_entry(TapestryScript.KIND_MILESTONE, title, said, StringName("goal:%s" % goal_id))


func hall() -> HallScript:
	"""The village's hall (demo/hall/demo_hall.gd): its stages, banners and the gathering query."""
	return _hall


func tapestry() -> RefCounted:
	"""The village tapestry (demo/hall/tapestry.gd; see its THE API), or null before the hall is built."""
	return _hall.tapestry if _hall != null else null


func _build_routes() -> void:
	"""The route and infrastructure previews (demo/routes/, decision 0461): the Water panel's bridge benefit and project
	lines, the Tunnels panel's project, the Routes layer, and the rescue's details on the incident card."""
	_routes = RoutesScript.new()
	add_child(_routes)
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_routes.configure(_cast as DemoCastScript, _command as DemoCommandScript, _waterplay, tool, _work, _forestry.crew.jobs,
		_zone.show_panel.bind(DetailZoneScript.PANEL_WOODS))
	_farm.lenses.set_subject(_routes_lens, _routes.subject)
	_routes.kinds.fleet = _fishery.fishery.fleet
	_routes.kinds.ferry_row = CrossingsScript.FERRY_ROW
	_routes.overlay.ferry_course = _ferry.course_m()
	_routes.overlay.ferry_status = _ferry.status_text
	_cards.add_details(RescueCardScript.KEY_PREFIX, _routes.rescue_card.card_into)
	_cards.set_centre((_camera as DemoCameraScript).centre_on)


func routes() -> RoutesScript:
	"""The route and infrastructure previews (demo/routes/demo_routes.gd)."""
	return _routes


func _show_routes(on: bool) -> void:
	"""The Routes layer's switch (built before the previews it shows: the picker lists it beside the water's)."""
	if _routes != null:
		_routes.show_lens(on)


func _bind_goal_measures() -> void:
	"""The goals' parts a later feature measures (goal_book.gd `bind_measure`; decision 0781 left them declared): M4's
	"fuel >= 18 winter days" from the winter's stores and hearths (decision 0902)."""
	_guide.goals.book.bind_measure(&"m4_hearth_charter", &"fuel", _winter.fuel_winter_days_milli)


func _build_guide() -> void:
	"""The first-village guide (see THE FIRST-VILLAGE GUIDE) over the village's real models, its card yielding to the
	incident card (one card at the top centre) as that yields, kept above the Map layer picker, and the commands its
	help topics link to."""
	_guide = GuideScript.new()
	add_child(_guide)
	_guide.configure(_guide_world(), _services.notices, _jump, _camera, GameManager as GameManagerScript)
	_guide.card.hide_while(_history.is_open)
	_guide.card.hide_while(_stall_banner.is_shown)
	_guide.card.hide_while(_cards.is_shown)
	# One card at the top centre, the most urgent: the incident card, then this guide card, then the people's offer card.
	# Both stand aside while the Residents list (L) is open: at 1280x720 they would cover its rows.
	_people_card.hide_while(_guide.card.is_shown)
	_guide.card.hide_while(_workspace_open)
	_people_card.hide_while(_workspace_open)
	_guide.card.set_avoid(func() -> Rect2: return _lens_picker.frame_rect() if _lens_picker.visible else Rect2())
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_guide.actions = {
		HelpTopics.ACTION_PANTRY: _farm.open_pantry,
		HelpTopics.ACTION_KITCHEN: func() -> void: _farm.open_pantry(); _farm.pantry_panel.show_tab(PantryPanelScript.TAB_KITCHEN),
		HelpTopics.ACTION_JOBS: _work.screen.open,
		HelpTopics.ACTION_NEWS: _history.open,
		HelpTopics.ACTION_RESIDENTS: _open_residents,
		HelpTopics.ACTION_WATER: _zone.show_panel.bind(DetailZoneScript.PANEL_WATER),
		HelpTopics.ACTION_DIG: _open_dig_tool.bind(tool),
		HelpTopics.ACTION_LOGS: PlaytestLog.open_folder,
		HelpTopics.ACTION_FUEL: _fuel_panel.open,
	}


func _build_camera_modes() -> void:
	"""The camera's modes over the rig: bookmarks, follow (End), orbit and the U view's cutaway angle, with the edge pan
	and their strip (demo/camera/camera_modes.gd, decision 0801)."""
	var tool: TunnelControlScript = _tunnel_tool()
	var command: DemoCommandScript = _command as DemoCommandScript
	_camera_modes = CameraModesScript.new()
	add_child(_camera_modes)
	_camera_modes.primary = command.first_selected
	_camera_modes.resident_point = resident_point
	_camera_modes.resident_name = func(who: int) -> String: return String(_cast.actor(who).get(&"display_name"))
	var shell: UiShell = _shell()
	_camera_modes.modal_open = func() -> bool:
		return _gate.modal_open() or (shell != null and shell.workspace_owns_input())
	_camera_modes.underground = func() -> bool: return tool.view.on
	_camera_modes.set_underground = show_underground
	_camera_modes.tunnel_extent = func() -> Rect2: return CameraModesScript.network_extent(tool.network, tool.view.level)
	_camera_modes.strip.journal_open = _zone.journal_open
	_camera_modes.follow_changed = command.panel().set_following
	_camera_modes.configure(_camera as DemoCameraScript)
	command.add_input_hook(_camera_modes.escape_hook)
	command.panel().follow_requested.connect(_camera_modes.toggle_follow)
	_news.lift = _camera_modes.strip.reserved_height


func camera_modes() -> CameraModesScript:
	"""The camera's modes (demo/camera/camera_modes.gd)."""
	return _camera_modes


func _open_dig_tool(tool: TunnelControlScript) -> void:
	"""The Dig tool open (B), or left open."""
	if not tool.planning:
		tool.begin_plan()


func _guide_world() -> GuideWorldScript:
	"""What the guide reads of the village (demo/guide/guide_world.gd): every model it completes an objective on."""
	var world := GuideWorldScript.new()
	var command: DemoCommandScript = _command as DemoCommandScript
	world.selected = command.selected
	world.first = command.first_selected
	world.name_of = func(i: int) -> String: return (_cast.actor(i) as DemoActorScript).display_name \
		if i >= 0 and i < _cast.actor_count() else "a resident"
	for i: int in _cast.actor_count():
		world.brains.append((_cast.actor(i) as DemoActorScript).brain)
	world.sim = _farm.sim
	world.pantry = _farm.pantry
	world.jobs = _farm.crew.jobs
	world.worker_name = _farm.crew.worker_name
	world.kitchen = _kitchen.kitchen
	world.bridges = _waterplay.bridges
	world.bridge_refusal = func(kind: int) -> String: return _waterplay.build_refusal(kind, command.selected())
	world.site_name = _waterplay.site_name
	world.network = command.tunnels().network
	world.calendar = _services.calendar
	world.record = _farm.record
	world.opening_stock = _farm.pantry.stored_total_milli(FarmCatalog.ITEM_KEYS.find(&"wheat")) > 0
	world.stores = _services.stores
	world.focus = (_camera as DemoCameraScript).focus
	world.selected_bed = func() -> int: return _farm.selected_bed
	world.selected_tunnel = func() -> int: return command.tunnels().ext.actions.selected
	world.water_map = _water.map()
	return world


func _open_residents() -> void:
	"""The HUD's Residents command (L), as a press of its button."""
	var residents := _shell().control_for(UiShell.ID_RESIDENTS) as Button if _shell() != null else null
	if residents != null and not residents.disabled:
		residents.pressed.emit()


func guide() -> GuideScript:
	"""The first-village guide (demo/guide/demo_guide.gd)."""
	return _guide


func _build_chronicle() -> void:
	"""The village chronicle (see THE VILLAGE CHRONICLE) over the news, the calendar, the farm's record, the people and
	the songs, and its book behind the "Chronicle" buttons of Village news and the village guide."""
	_chronicle = ChronicleScript.new()
	add_child(_chronicle)
	var titles: PackedStringArray = _songs.book.titles if _songs != null else PackedStringArray()
	_chronicle.configure(_services.notices, _services.calendar, _farm.record, _people.ledger, _people.names(),
		_songs.circle if _songs != null else null, titles)
	_chronicle_window = ChronicleWindowScript.new()
	add_child(_chronicle_window)
	_chronicle_window.configure(_chronicle)
	_chronicle_window.set_art(_services.props)
	_history.set_chronicle(_chronicle_window.open)
	_guide.window.set_chronicle(_chronicle_window.open)


func _attach_chronicle() -> void:
	"""The book as a modal of the input gate (Esc and × close it) and a planning surface."""
	_gate.watch_modal(_chronicle_window, _chronicle_window.frame(), _chronicle_window.close)
	_gate.set_modal_close(_chronicle_window, _chronicle_window.close_button())
	_time.add_planning("the chronicle", _chronicle_window.is_open)


func chronicle() -> ChronicleScript:
	"""The village chronicle (demo/chronicle/demo_chronicle.gd)."""
	return _chronicle


func chronicle_window() -> ChronicleWindowScript:
	"""The chronicle's book (demo/chronicle/chronicle_window.gd)."""
	return _chronicle_window


func _build_people() -> void:
	"""The village's people (see PEOPLE): the ledger's taps on every owner, its skills, the inspector, the roster's
	notable mark, the dig lead's voice, and the offer card under the incident card."""
	_people = PeopleScript.new()
	add_child(_people)
	_people.configure(_cast as DemoCastScript, _services.notices, _services.calendar)
	_people.bind_kitchen(_kitchen.kitchen)
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_bind_people_taps(tool.ext)
	_people.watch()
	var command: DemoCommandScript = _command as DemoCommandScript
	command.set_person_info(_people.inspector_info, _people.stamp_of)
	command.panel().person_section().go_to.connect(func(kind: int, id: int) -> void: _jump.jump(kind, id))
	command.panel().person_section().notable_pressed.connect(_people.pin_notable)
	command.panel().person_section().set_portraits(_services.props, _cast_key_of)
	_roster.set_notable(_people.is_notable)
	tool.ext.works.voice = _people.voice
	_people_card = PeopleCardScript.new()
	add_child(_people_card)
	_people_card.configure(_people, _jump)
	_people_card.hide_while(_cards.is_shown)
	_people_card.hide_while(_history.is_open)
	_people_card.hide_while(_stall_banner.is_shown)


func _build_regatta() -> void:
	"""THE REGATTA (see the header), after the people: the fishery's boats and skills, the kitchen's occasion, the
	people's deed and company hooks, the Water panel's section, and the HUD's Feast command."""
	_regatta = RegattaNodeScript.new()
	add_child(_regatta)
	_regatta.configure(_cast as DemoCastScript, _command as DemoCommandScript, _services, _waterplay, _fishery,
		_kitchen.kitchen)
	_regatta.bind_people(_people.record_regatta, _people.share_feast)
	_regatta.unlock_feast_command(_shell())


func regatta() -> RegattaNodeScript:
	"""The village's regatta (demo/regatta/demo_regatta.gd)."""
	return _regatta


func _bind_people_taps(ext: TunnelExtScript) -> void:
	"""The owners whose committed state the people read (people_taps.gd), and the four skills they watch."""
	var taps := _people.taps
	taps.bridges = _waterplay.bridges
	taps.bridge_crew = _waterplay.crew
	taps.rescue = _waterplay.rescue
	taps.network = (_cast as DemoCastScript).space().tunnels
	taps.tunnel_crew = ext.works.crew
	taps.farm_crew = _farm.crew
	taps.board = _work.board
	_people.board = _work.board
	var woods: ForestSkills = _forestry.crew.skills
	taps.add_skill(ForestRules.SKILL_NAMES[ForestRules.SKILL_FELLING],
		func(who: int) -> int: return woods.xp_of(who, ForestRules.SKILL_FELLING))
	taps.add_skill(ForestRules.SKILL_NAMES[ForestRules.SKILL_SAWING],
		func(who: int) -> int: return woods.xp_of(who, ForestRules.SKILL_SAWING))
	var dig: DigSkills = ext.works.crew.skills
	taps.add_skill(DigSkills.NAME, func(who: int) -> int: return dig.xp[who] if who < dig.xp.size() else 0)
	var bridging: BridgeCrew = _waterplay.crew
	taps.add_skill("Bridging", func(who: int) -> int: return bridging.xp[who] if who < bridging.xp.size() else 0)


func people() -> PeopleScript:
	"""The village's people (demo/people/demo_people.gd)."""
	return _people


func people_card() -> PeopleCardScript:
	"""The people's offer card (demo/people/people_card.gd)."""
	return _people_card


func work_jump(kind: int, id: int, point: Vector2) -> bool:
	"""The Work screen's "Go to": the news's own jump for a target it knows (selected, the camera eased over it), else
	the camera eased over the task's place."""
	if _jump.can_jump(kind, id):
		return _jump.jump(kind, id)
	(_camera as DemoCameraScript).centre_on(Vector3(point.x, 0.0, point.y))
	return true


func work() -> DemoWorkScript:
	"""The village's work board and Work screen (demo/work/demo_work.gd)."""
	return _work


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
	_build_village_hud()
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
	_zone.add_panel(DetailZoneScript.PANEL_ORCHARD, _orchard.panel)
	_orchard.set_panel_shower(_zone.show_panel.bind(DetailZoneScript.PANEL_ORCHARD))
	_build_lens_picker()
	_farm.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_FARM))
	ext.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_TUNNELS))
	_forestry.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_WOODS))
	_waterplay.panel_wanted.connect(_zone.show_panel.bind(DetailZoneScript.PANEL_WATER))
	_build_news()


func _build_daylight() -> void:
	"""The day and the night (demo/world/day_night.gd, decision 0541): the world's sun, sky and haze on the demo calendar,
	the weather on top, the surface's night lights at the homes and the tunnel mouths, and the date trigger's sun or
	moon."""
	var tunnels: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_night_lights = NightLightsScript.new()
	add_child(_night_lights)
	_night_lights.configure(NightLightsScript.home_spots(WorldLayout.placements()), tunnels.overlay.lantern_spots_into,
		(_camera as DemoCameraScript).focus, (_cast as DemoCastScript).clock)
	_day_night = DayNightScript.new()
	add_child(_day_night)
	_day_night.configure(_services.calendar, _world, tunnels.ext.weather_view, _night_lights)
	_day_night.set_smoke_tinter(tunnels.ext.fixture_view.set_smoke_tint)
	_night_lights.set_home_lit(home_lamp_lit)
	_night_lights.bind_windows((_world as DemoWorldScript).window_glow)
	var shell: UiShell = _shell()
	if shell != null:
		_day_night.set_date_button(shell.status_label())


func home_lamp_lit(k: int) -> bool:
	"""THE HOMES' LAMPLIGHT (night_lights.gd `set_home_lit`, home `k` in daylight_curves.gd LIT_HOMES order): the hall's
	stands dark only while its hearth is out of fuel or let go out (hearth_fuel.gd `hearth_cold(HALL)`, decision 0571):
	lit at night when heated, and on a night that wants no heat (Brendan's ruling on decision 0902's question 3,
	2026-10-02). The three surface residences and the kitchen have no hearth in the winter's model (its homes are the
	burrow rows below), so they keep the lamps' hours."""
	if _winter == null or k < 0 or k >= DaylightCurves.LIT_HOMES.size() or DaylightCurves.LIT_HOMES[k] != &"hall":
		return true
	return not _winter.fuel.hearth_cold(HearthFuelScript.HALL)


func day_night() -> DayNightScript:
	"""The day and the night (demo/world/day_night.gd)."""
	return _day_night


func night_lights() -> NightLightsScript:
	"""The surface's night lights (demo/world/night_lights.gd)."""
	return _night_lights


func _build_news() -> void:
	"""The village news (see VILLAGE NEWS): the strip on the news clock with its count, the history window, the
	incident card, every "Go to", and the HUD's history command routed to the window."""
	_news.bind_news(_services.incidents, _services.news_clock, (GameManager as GameManagerScript).is_paused)
	_news.bind_jump(_jump)
	_jump.bind_camera(_camera as DemoCameraScript)
	_register_jumps()
	_farm.set_bed_jump(func(bed: int) -> bool: return _jump.jump(NoticesScript.TARGET_BED, bed))
	_history = NewsHistoryScript.new()
	add_child(_history)
	_history.configure(_services.notices, _services.incidents, _jump)
	_cards = IncidentCardsScript.new()
	add_child(_cards)
	_cards.configure(_services.incidents, _jump)
	_cards.hide_while(_history.is_open)
	_cards.hide_while(_stall_banner.is_shown)
	_news.history_wanted.connect(_history.open)
	_cards.history_wanted.connect(_history.open)
	var shell: UiShell = _shell()
	if shell != null:
		_history.set_settlement(shell.open_notice_history)
		_history.defer_keys_while(shell.notice_details_open)
		_history.defer_keys_while(shell.workspace_owns_input)
		_cards.hide_while(shell.notice_details_open)
		shell.shell_action.connect(_on_shell_action)


func _register_jumps() -> void:
	"""Each target kind's "Go to": where it is now, and how a click selects it (demo_news_jump.gd)."""
	var network: GraphScript = (_command as DemoCommandScript).tunnels().network
	_jump.register(NoticesScript.TARGET_BED, func(bed: int) -> Vector3: return NewsJumpScript.bed_point(bed),
		_farm.select_bed)
	_jump.register(NoticesScript.TARGET_TREE,
		func(t: int) -> Vector3: return NewsJumpScript.tree_point(_forestry.stand, t), _forestry.select_tree)
	_jump.register(NoticesScript.TARGET_TUNNEL,
		func(slot: int) -> Vector3: return NewsJumpScript.tunnel_point(network, slot), select_tunnel)
	_jump.register(NoticesScript.TARGET_RESIDENT, resident_point, select_resident)
	_jump.register(NoticesScript.TARGET_BRIDGE,
		func(row: int) -> Vector3: return NewsJumpScript.bridge_point(_waterplay.bridges, row), _waterplay.select_bridge)


func resident_point(who: int) -> Vector3:
	"""Where resident `who` stands (INF: no such resident)."""
	if who < 0 or who >= _cast.actor_count():
		return Vector3.INF
	var at: Vector3 = (_cast.actor(who) as Node3D).position
	return Vector3(at.x, 0.0, at.z)


func select_resident(who: int) -> void:
	"""Select resident `who` alone, as a click on it does."""
	(_command as DemoCommandScript).select(PackedInt32Array([who]))


func select_tunnel(slot: int) -> void:
	"""Select tunnel `slot` and bring the Tunnels panel forward, as a click on it does; in the U view, on the level it
	lies on (decision 0212)."""
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	var ext: TunnelExtScript = tool.ext
	ext.deselect_room()
	ext.actions.select(slot)
	tool.reveal_tunnel(slot)
	ext.panel_wanted.emit()


func _on_shell_action(element_id: int) -> void:
	"""The HUD's history trigger (N is read by the window itself, first): the village news stands in for the
	shell's history in the top-centre zone (one expansion there), so the shell's opened history is closed --
	and the focus it hands back to the trigger let go, or the HUD would draw the trigger's keyboard description
	over the window -- and the window toggled; a shell history the trigger just closed (opened from a
	settlement card) closes the window too."""
	if element_id == UiShell.ID_FUEL:
		_fuel_panel.open()
		return
	if element_id != UiShell.ID_HISTORY_TRIGGER:
		return
	var shell: UiShell = _shell()
	if _history.take_trigger(shell != null and shell.notice_details_open()):
		shell.close_notice_details()
		get_viewport().gui_release_focus()


func news_history() -> NewsHistoryScript:
	"""The village-news history window (checks)."""
	return _history


func incident_cards() -> IncidentCardsScript:
	"""The top-centre incident card (checks)."""
	return _cards


func news_jump() -> NewsJumpScript:
	"""The news's "Go to" (checks)."""
	return _jump


func _build_village_hud() -> void:
	"""The HUD's village read model (decision 0251): the counters and ledger from the village's stores, pantry,
	cast and homes; the Residents command's roster from the cast; the minimap drawing the village."""
	var network: GraphScript = (_command as DemoCommandScript).tunnels().network
	_counters.model.bind_village(_services.stores, _farm.pantry, _cast as DemoCastScript, network)
	_counters.model.bind_meals(_kitchen.kitchen)
	_counters.model.bind_fuel(_winter)
	_counters.bind(_shell())
	_roster = RosterScript.new()
	add_child(_roster)
	_roster.configure(_shell(), _cast as DemoCastScript, _command as DemoCommandScript, _camera as DemoCameraScript)
	_roster.set_fed_text(fed_and_warm_word)
	var view: Control = _shell().control_for(UiShell.ID_MINIMAP_VIEW) if _shell() != null else null
	if view == null:
		return
	_shell().set_minimap_display("")
	_minimap = MinimapScript.new()
	view.add_child(_minimap)
	_minimap.configure(_cast as DemoCastScript, _camera as DemoCameraScript, _command as DemoCommandScript, _water.map())
	_minimap.watch(network, _waterplay.bridges, _forestry.stand)


func roster() -> RosterScript:
	"""The Residents command's cast roster (demo/ui/demo_roster.gd)."""
	return _roster


func minimap() -> MinimapScript:
	"""The HUD minimap's village map (demo/ui/demo_minimap.gd)."""
	return _minimap


func counters() -> HudCountersScript:
	"""The top bar's village counters and ledger (demo/ui/demo_hud_counters.gd)."""
	return _counters


func _build_lens_picker() -> void:
	"""The Underground layer (U's view, followed: map_lenses.gd) and the Map layer picker bottom left, clear
	of the news strip's band (which the journal moves)."""
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	var under: int = _farm.lenses.add("Underground", "Tunnels", UNDERGROUND_LENS_QUESTION, show_underground)
	_farm.lenses.follow_state(under, func() -> bool: return tool.view.on)
	_farm.lenses.set_legend(under, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]),
		PackedStringArray(["blue hatch: too wet to dig", "stone: building footings", "U: back to the surface"]))
	_lens_kit = LensKitScript.new()
	add_child(_lens_kit)
	_lens_kit.attach(_farm.lenses, _farm.sim, _water.map(), _water.overlay(), _forestry.stand, _forestry.zones)
	_lens_picker = LensPickerScript.new()
	add_child(_lens_picker)
	_lens_picker.configure(_farm.lenses, _zone.journal_open)


func show_underground(on: bool) -> void:
	"""The Underground layer's switch: the tunnels' U view on or off (one cull-mask write)."""
	var tool: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	if tool.view.on != on:
		tool.toggle_view()


func lens_picker() -> LensPickerScript:
	"""The Map layer picker (demo/ui/demo_lens_picker.gd)."""
	return _lens_picker


func lens_kit() -> LensKitScript:
	"""The map layers' hover readout and compare outlines (demo/lenses/demo_lens_kit.gd)."""
	return _lens_kit


func _shell() -> UiShell:
	"""The game HUD's §4 shell (null without a HUD)."""
	var hud_root: Node = _game.get_node_or_null(GAME_HUD_ROOT)
	return hud_root.get_node_or_null(^"Shell") as UiShell if hud_root != null else null


func storage_providers() -> Array[Callable]:
	"""Food stores beyond the covered store, for the farm's pantry (farm_storage.gd's provider API): the
	network's dug root cellars (demo/farm/farm_cellars.gd over underground_rooms `cellars()`), delivered at
	their hatches, and the kitchen's pantry at its door (demo/kitchen/demo_kitchen.gd, decision 0381)."""
	var network: GraphScript = (_command as DemoCommandScript).tunnels().network
	var providers: Array[Callable] = [FarmCellars.provider(network), KitchenNodeScript.pantry_provider(),
		OrchardScript.stand_provider()]
	return providers


func water() -> WaterScript:
	"""THE village water adapter (village_water.gd): the farm's edge query and the tunnels' wet-ground,
	flood and route queries all go through it, over the water node's real map."""
	return _services.water


func services() -> ServicesScript:
	"""The demo's shared calendar, weather, water and notice feed."""
	return _services


func _open_running() -> void:
	"""Release UI-SET-103's opening inspection pause, once, so the demo opens running (see TIME) -- or, after
	a restart, the boot's own hold (`_hold_restart_open`). Only the PLAYER reason is released; any other held
	reason stays."""
	if _held_open or (UIManager.opening_pause_applied() and not UIManager.player_has_resumed() \
			and GameManager.is_paused()):
		_held_open = false
		GameManager.resume_game()
	_time.opened = true
	PlaytestTaps.opened()


func _hold_restart_open() -> void:
	"""After "Restart demo" the opening inspection pause is not held again (UIManager holds it once per
	process), so the clock would run through the prewarm's frames: hold PLAYER until they are drawn."""
	if UIManager.opening_pause_applied() and not GameManager.is_paused() and GameManager.pause_game():
		_held_open = true


func weather() -> WeatherScript:
	"""The demo's one weather (demo/weather/demo_weather.gd): `surface_speed_permille()`, `condition()`,
	`temperature_tenths()`, `rain()`. Driven by the farm's real row; read-only for everyone."""
	return _services.weather


func rooms() -> RoomsScript:
	"""The network's rooms (demo/burrow/underground_rooms.gd): `cellars(graph)` for the root cellars' API."""
	return _command.tunnels().network.rooms


func _build_sound() -> void:
	"""The demo's sound owner (see SOUND): its table, buses and voices, listening to the camera, the clock, the U
	view and the village's models; then the residents' songs, which hum on its Songs bus."""
	add_child(_sound)
	_sound.configure()
	var tunnels: TunnelControlScript = (_command as DemoCommandScript).tunnels()
	_sound.bind(_camera as DemoCameraScript, GameManager as GameManagerScript, func() -> bool: return tunnels.view.on)
	_sound.follow_demo(_cast as DemoCastScript, _forestry, tunnels.network, _waterplay, _services, _water.map())
	_sound.follow_fishery(_fishery.fishery)
	_build_songs()


func _build_songs() -> void:
	"""The residents' songs (decision 0442): read from the cast, the kitchen, the night and the work board; their news
	to the village feed; their slots filled from the deeds the water's play has recorded."""
	_songs = SongsScript.new()
	add_child(_songs)
	if _songs.configure(_cast as DemoCastScript, _camera.camera(), _services.calendar, _services.notices):
		_songs.follow(_kitchen.kitchen, _work.board)
		_songs.set_deeds(village_deeds)
		_songs.add_work_reader(_regatta.regatta.rowing)


func village_deeds() -> PackedStringArray:
	"""What the village has done that a song may name (demo_songs.gd DEEDS): each bridge it has opened, and a rescue."""
	var out := PackedStringArray()
	if _waterplay == null:
		return out
	for row: int in _waterplay.bridges.names.size():
		if _waterplay.bridges.is_open(row) and not _waterplay.bridges.names[row].is_empty():
			out.append("the " + _waterplay.bridges.names[row])
	if _waterplay.rescue.rescued > 0:
		out.append("the swimmer saved")
	return out


func songs() -> SongsScript:
	"""The residents' songs (demo/songs/demo_songs.gd)."""
	return _songs


func sound() -> SoundScript:
	"""The demo's sound owner (demo/sound/sound_director.gd)."""
	return _sound


func _build_input() -> void:
	"""The game menu, the Demo Lab and, last of all the village's children, the input gate over them, the
	Pantry and the panels (see INPUT, MENU AND KEYBOARD)."""
	_build_menu()
	_build_lab()
	_build_session()
	_build_access()
	add_child(_gate)
	_gate.yield_to(_stall_banner.is_shown)
	var shell: UiShell = _shell()
	if shell != null:
		_gate.defer_to(shell.workspace_owns_input)
		_gate.occlude_with(_workspace_rect.bind(shell))
	get_viewport().size_changed.connect(_refit_ui_scale)
	get_viewport().size_changed.connect(_scale_tooltips)
	_scale_tooltips()
	_gate.watch_modal(_farm.pantry_panel, _farm.pantry_panel, _farm.toggle_pantry, [&"open_food"] as Array[StringName])
	_gate.set_modal_close(_farm.pantry_panel, _farm.pantry_panel.close_button())
	_gate.watch_modal(_menu, _menu, _menu.back_or_close)
	_gate.watch_modal(_lab, _lab, _lab.close, [] as Array[StringName], [LabScript.KEY] as Array[Key])
	_gate.watch_modal(_work.screen, _work.screen, _work.screen.close, [&"open_jobs"] as Array[StringName])
	_gate.set_modal_close(_work.screen, _work.screen.close_button())
	_gate.watch_modal(_farm.planner, _farm.planner, _farm.planner.close, [] as Array[StringName],
		[_farm.planner.KEY] as Array[Key])
	_gate.set_modal_close(_farm.planner, _farm.planner.close_button())
	_gate.watch_modal(_run_menu, _run_menu.frame(), _run_menu.close, [] as Array[StringName], [RunMenuScript.KEY] as Array[Key])
	_gate.set_modal_close(_run_menu, _run_menu.close_button())
	_gate.watch_modal(_objects, _objects.frame(), _objects.close, [ObjectListScript.ACTION] as Array[StringName])
	_gate.set_modal_close(_objects, _objects.close_button())
	_gate.watch_modal(_fuel_panel, _fuel_panel.frame(), _fuel_panel.close)
	_gate.set_modal_close(_fuel_panel, _fuel_panel.close_button())
	var ext: TunnelExtScript = (_command as DemoCommandScript).tunnels().ext
	_gate.add_region("right column", [_zone, _farm.bed_panel, ext.panel, _forestry.panel, _waterplay.panel] as Array[Node])
	_gate.add_region("left column", [(_command as DemoCommandScript).panel()] as Array[Node])
	_gate.add_region("map layers", [_lens_picker] as Array[Node])
	_guide.attach(_menu, _lab, _gate, _shell())
	_attach_chronicle()
	_gate.add_region("offer card", [_people_card] as Array[Node])
	_sound.watch_buttons.call_deferred(get_tree().root)


func _workspace_rect(shell: UiShell) -> Rect2:
	"""Where the HUD's workspace (the Residents roster and its kin) is drawn now, in viewport pixels; empty when it is
	closed. It draws over the right column at 1280x720, and the input gate skips what it covers (decision 0391)."""
	var workspace: Control = shell.control_for(UiShell.ID_WORKSPACE)
	if workspace == null or not workspace.is_visible_in_tree():
		return Rect2()
	return InputGateScript.screen_rect(workspace)


func _scale_tooltips() -> void:
	"""The action cards' tooltips at the HUD's effective scale for this window (decision 0391), larger with bigger
	tooltips on (decision 0471)."""
	ActionCardScript.scale_tooltips(DemoUiScale.effective_scale(get_viewport().get_visible_rect().size)
		* Access.tooltip_scale())


func _build_menu() -> void:
	"""UI-SET-019's game menu: Resume, Restart, Controls, Settings, the Lab and Quit (demo_menu.gd)."""
	add_child(_menu)
	_menu.bind(GameManager as GameManagerScript)
	_menu.on_restart = restart
	_menu.on_quit = get_tree().quit
	_menu.on_lab = _lab.open
	_menu.on_scale = set_ui_scale
	_menu.scale_fits = ui_scale_fits
	_menu.on_fullscreen = WindowKeysScript.toggle
	_menu.is_fullscreen = func() -> bool: return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var shell: UiShell = _shell()
	if shell != null:
		shell.set_menu_handler(_menu.open)
		if DemoUiScale.percent != DemoUiScale.UiLayout.USER_SCALE_100:
			shell.apply_user_scale.call_deferred(DemoUiScale.percent)
	_menu.scale_percent = DemoUiScale.percent
	_menu.sound.apply = _sound.mix.apply
	_menu.sound.set_silent(_sound.is_silent())


func _build_lab() -> void:
	"""The Demo Lab's test triggers: the four its panels' buttons used to call, Skip to next season (decision 0571), the
	season preview (presentation only; decision 0551) and the infirmary's two test injuries (decision 0622)."""
	add_child(_lab)
	var ext: TunnelExtScript = (_command as DemoCommandScript).tunnels().ext
	_lab.add_trigger("Next weather", "Run the one calendar on to the next change of weather", "Tunnels",
		ext.on_action.bind(TunnelPanelScript.ACTION_NEXT_WEATHER))
	_lab.add_trigger("Test event", "Bring the tunnels' next seeded threat now", "Tunnels",
		ext.on_action.bind(TunnelPanelScript.ACTION_EVENT))
	_lab.add_trigger("Storm gust", "Blow a storm gust through the woods now", "Woods",
		_forestry.on_action.bind(ForestPanelScript.ACTION_STORM))
	_lab.add_trigger("Cramp", "Every selected resident swimming tires at once and needs rescue", "Water",
		_waterplay.on_action.bind(WaterPanelScript.ACTION_CRAMP), _swimmer_selected, "Select a resident in the water first")
	_lab.add_trigger("Skip to next season", "Run the one calendar on to 06:00 on day 1 of the next season: crops, stores, "
		+ "weather and the hearths catch up; walking, work, meals and the cold are skipped", "Village news",
		skip_to_next_season)
	_seasons.bind_lab(_lab.add_trigger(SeasonViewScript.PREVIEW_LABEL, SeasonViewScript.PREVIEW_TIP, "", _seasons.next_preview,
		Callable(), "", SeasonViewScript.PREVIEW_DONE))
	_lab.add_trigger("Injury", "Every selected resident takes the net hazard's bite (minor, −20 health; GDD §5.4)",
		"Demo party", _lab_hurt.bind(false), _resident_selected, "Select a resident first")
	_lab.add_trigger("Serious injury", "Every selected resident takes the boat hazard's exposure (serious, −35 health)",
		"Demo party", _lab_hurt.bind(true), _resident_selected, "Select a resident first")


func _build_session() -> void:
	"""The time controls (see TIME CONTROLS): the ledger the menu holds its pause through, the run on the demo
	calendar and the farm's beds, the planning surfaces, the pause card, and the run's button and menu."""
	var manager := GameManager as GameManagerScript
	add_child(_time)
	_time.configure(manager, _cast.clock, _services.notices, _services.incidents)
	_time.bind_shell(_shell())
	_time.run.calendar = _services.calendar
	_time.run.ripe_mask = ripe_beds
	_time.run.growing = func() -> bool: return growing_beds() != 0
	_menu.hold_pause = _time.ledger.hold_menu
	_guide.window.hold_pause = _time.ledger.hold_guide
	_add_planning()
	add_child(_card)
	_card.configure(_time.ledger, manager.get_speed)
	_card.on_resume = _time.resume
	_card.run_note = _time.run_note
	_card.hide_while = [_stall_banner.is_shown, func() -> bool: return not _time.opened,
		func() -> bool: return _menu.visible] as Array[Callable]
	_card.modal_open = func() -> bool: return _gate.modal_open()
	_card.avoid = _top_card_rect
	_card.keep_clear = func() -> Rect2: return _lens_picker.frame_rect() if _lens_picker.visible else Rect2()
	_card.hud_cards_shown = _hud_cards_shown
	add_child(_run_menu)
	add_child(_run_menu.button_layer())
	_run_menu.configure(_time.run, _hud_rect.bind(UiShell.ID_TIME_CLUSTER), _hud_rect.bind(UiShell.ID_SPEED_4))
	_run_menu.on_start = _time.start_run
	_run_menu.on_stop = _time.stop_run
	_run_menu.on_speed = manager.set_speed
	_run_menu.speed = manager.get_speed
	_run_menu.before_open = func() -> void: VillageTargets.project_into(_time.run, _tunnel_tool(), _waterplay)
	_time.run_menu = _run_menu


func _top_card_rect() -> Rect2:
	"""The one card shown at the top centre under the alerts, which the pause card steps below: the incident card, else
	the first-village guide's card (which yields to it), else the people's offer card (which yields to both; decision
	0931), else nothing."""
	if _cards.is_shown():
		return _cards.frame_rect()
	if _guide != null and _guide.card.is_shown():
		return _guide.card.frame_rect()
	if _people_card != null and _people_card.is_shown():
		return _people_card.frame_rect()
	return Rect2()


func _add_planning() -> void:
	"""The planning surfaces the planning pause follows, first named first."""
	var tool: TunnelControlScript = _tunnel_tool()
	_time.add_planning("the Pantry", func() -> bool: return _farm.pantry_panel.visible)
	_time.add_planning("the Work screen", func() -> bool: return _work.screen.visible)
	_time.add_planning("the seasonal planner", func() -> bool: return _farm.planner.visible)
	_time.add_planning("the village news", _history.is_open)
	_time.add_planning("the object list", func() -> bool: return _objects.visible)
	_time.add_planning("the Dig tool", func() -> bool: return tool.planning)
	_time.add_planning("the Residents list", _workspace_open)
	_time.add_planning("the heating fuel breakdown", func() -> bool: return _fuel_panel.visible)
	_time.add_planning("the hall", _hall.is_open)


func _workspace_open() -> bool:
	"""Whether the HUD's ordinary workspace (the Residents list) is open."""
	var shell: UiShell = _shell()
	return shell != null and _workspace_rect(shell).has_area()


func _build_access() -> void:
	"""Accessibility (see ACCESSIBILITY): the targets and their rings, the object list, the focus hint, and the
	settings' effects, applied now from the settings the session kept."""
	_targets.centre = (_camera as DemoCameraScript).centre_on
	VillageTargets.register(_targets, _cast as DemoCastScript, _farm, _forestry, _waterplay, _tunnel_tool(),
		select_resident, select_tunnel)
	add_child(_marks)
	_marks.configure(_targets)
	add_child(_hint)
	_hint.modal_open = func() -> bool: return _gate.modal_open()
	add_child(_objects)
	_objects.targets = _targets
	add_child(_effects)
	_effects.ledger = _time.ledger
	_effects.marks = _marks
	_effects.hint = _hint
	_effects.news = _news
	_effects.hud_theme_owner = _shell()
	_effects.motion_root = self
	_effects.on_tooltips = _scale_tooltips
	_effects.on_sound = _sound.mix.apply
	_menu.access.scale_to = _menu.choose_scale
	_menu.access.scale_fits = ui_scale_fits
	_menu.access.applied = _on_access_changed
	_effects.apply()


func _on_access_changed() -> void:
	"""A setting changed in the menu: apply every effect now, and repaint the sound's rows (a preset may set the mix)."""
	_effects.apply()
	_menu.sound.refresh()


func _tunnel_tool() -> TunnelControlScript:
	"""The Dig tool and the network it owns."""
	return (_command as DemoCommandScript).tunnels()


func _hud_rect(id: int) -> Rect2:
	"""HUD element `id`'s rectangle in viewport pixels (empty without a HUD)."""
	var shell: UiShell = _shell()
	var control: Control = shell.control_for(id) if shell != null else null
	return InputGateScript.screen_rect(control) if control != null else Rect2()


func _hud_cards_shown() -> bool:
	"""Whether the HUD's own alert cards are showing (the pause card then sits under them). The stack is looked up
	once, not each frame."""
	if _alert_stack == null or not is_instance_valid(_alert_stack):
		var shell: UiShell = _shell()
		_alert_stack = shell.control_for(UiShell.ID_ALERT_STACK) if shell != null else null
	return _alert_stack != null and _alert_stack.visible


func ripe_beds() -> int:
	"""A bit per crop bed that is ripe now (the farm's own stage): the harvest windows open."""
	var mask: int = 0
	for bed: int in FarmCatalog.BED_COUNT:
		if _farm.sim.stage_of(bed) == FarmSimScript.STAGE_RIPE:
			mask |= 1 << bed
	return mask


func growing_beds() -> int:
	"""A bit per crop bed growing toward a harvest (sown, sprouting or growing)."""
	var mask: int = 0
	for bed: int in FarmCatalog.BED_COUNT:
		var stage: int = _farm.sim.stage_of(bed)
		if stage == FarmSimScript.STAGE_SOWN or stage == FarmSimScript.STAGE_SPROUTING \
				or stage == FarmSimScript.STAGE_GROWING:
			mask |= 1 << bed
	return mask


func time_control() -> TimeControlScript:
	"""The time controls: the pause ledger and the run (checks)."""
	return _time


func pause_card() -> PauseCardScript:
	"""The pause card (checks)."""
	return _card


func run_menu() -> RunMenuScript:
	"""The "Run until…" button and menu (checks)."""
	return _run_menu


func object_list() -> ObjectListScript:
	"""The F6 object list (checks)."""
	return _objects


func access_effects() -> AccessEffectsScript:
	"""The accessibility settings' effects (checks)."""
	return _effects


func target_marks() -> MarksScript:
	"""The interactive targets' rings (checks)."""
	return _marks


func focus_hint() -> HintScript:
	"""The focus hint (checks)."""
	return _hint


func _resident_selected() -> bool:
	"""Whether any resident is selected (the Lab's test injuries can act)."""
	return not (_command as DemoCommandScript).selected().is_empty()


func _lab_hurt(serious: bool) -> void:
	"""The Lab's test injury on the selected residents (demo/infirmary/demo_care.gd `lab_hurt`)."""
	_care.lab_hurt((_command as DemoCommandScript).selected(), serious)


func _swimmer_selected() -> bool:
	"""Whether a selected resident is in the water (the Lab's Cramp can act)."""
	return _waterplay.text.any_in_water((_command as DemoCommandScript).selected())


func restart() -> void:
	"""The menu's confirmed Restart: the demo scene again from its first morning (nothing is saved)."""
	PlaytestTaps.restarting()
	get_tree().reload_current_scene.call_deferred()


func set_ui_scale(percent: int) -> void:
	"""The menu's interface scale: the HUD's (`apply_user_scale`) and every demo panel's (they re-place on the
	viewport's `size_changed`, which `apply` raises -- the tooltips' scale too)."""
	var shell: UiShell = _shell()
	if shell != null:
		shell.apply_user_scale(percent)
	DemoUiScale.apply(percent, get_viewport())


func _refit_ui_scale() -> void:
	"""After a resize or a full-screen toggle, step the interface scale down to the largest one the window
	still fits (MIN_LOGICAL_HEIGHT), so a 150 % chosen full screen does not squeeze a smaller window."""
	if ui_scale_fits(DemoUiScale.percent):
		return
	var best: int = DemoUiScale.UiLayout.USER_SCALE_100
	for percent: int in DemoUiScale.UiLayout.USER_SCALES:
		if percent < DemoUiScale.percent and ui_scale_fits(percent):
			best = percent
	_menu.scale_percent = best
	set_ui_scale(best)


func ui_scale_fits(percent: int) -> bool:
	"""Whether this window can show the demo at `percent` (MIN_LOGICAL_HEIGHT, MIN_LOGICAL_WIDTH)."""
	var size_px: Vector2 = get_viewport().get_visible_rect().size
	return DemoUiScale.fits(int(size_px.x), int(size_px.y), percent, MIN_LOGICAL_HEIGHT, MIN_LOGICAL_WIDTH)


func input_gate() -> InputGateScript:
	"""The demo's input gate (checks)."""
	return _gate


func menu() -> MenuScript:
	"""The demo's game menu (checks)."""
	return _menu


func lab() -> LabScript:
	"""The Demo Lab (checks)."""
	return _lab


func _unhandled_input(event: InputEvent) -> void:
	"""Last of the demo's handlers: Esc that nothing else dismissed opens the game menu (UI §3's ladder
	ends there); F8 opens the Demo Lab; F6 the object list (decision 0471)."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.keycode == KEY_ESCAPE:
		_menu.open()
	elif key.keycode == LabScript.KEY:
		_lab.open()
	elif key.is_action_pressed(ObjectListScript.ACTION):
		_objects.open()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	"""Keep the HUD's date on the demo calendar and its counters and ledger the village's (demo_hud_counters.gd),
	and the sun's shadow range fitted to the zoom (only touched when the zoom moved)."""
	_hud_date.sync()
	_counters.sync()
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
	_effects.apply_tooltips()
