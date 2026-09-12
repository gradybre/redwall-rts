extends Node
## Routes system signals into the active HUD, and player actions out through the command queue.
##
## This is the one place signals drive behaviour: every connection made here ends at a HUD
## control. Game logic calls systems directly instead, and every ECONOMIC player action leaves
## through `ui_command_bridge.gd` as an ARCH-CMD-001 command -- never as a store write.
##
## ---------------------------------------------------------------------------------------
## THE WORLD OPENS PAUSED, AND STAYS PAUSED UNTIL THE PLAYER RESUMES. UI-SET-103: "Generation
## succeeds into paused world inspection with PLAYER pause; the first Resume starts tick
## advancement." `start_game()` leaves the clock running at 1x, because it is the clock's owner
## and knows nothing about inspection; so the FIRST transition into PLAYING re-holds the PLAYER
## reason here, once, and `_player_has_resumed` records that the player has taken over. After
## that this file never pauses the world again -- a second automatic pause would fight the
## player for the pause button.
##
## The pause is applied through `GameManager`, which owns the clock. Nothing here writes a tick,
## a speed or a pause bit itself. ARCH-CMD-002's scheduler event queue is task 04.1's and does
## not exist yet, so this uses the existing IMMEDIATE pause and speed setters and says so.
##
## ---------------------------------------------------------------------------------------
## THE TIME SOURCE IS INJECTABLE, AND THE AUTOLOAD IS THE DEFAULT. A suite that had to pause the
## real `GameManager` autoload to test the paused-start rule would leave the whole runner in a
## state the next suite inherits. `bind_time_source()` lets a test drive its own clock owner;
## production passes nothing and gets the singleton.

const HudScript := preload("res://scripts/ui/hud.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiCommandBridge := preload("res://scripts/ui/ui_command_bridge.gd")
const UiWorldSession := preload("res://scripts/ui/ui_world_session.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")


## GameManager's PLAYING state, restated so the paused-start rule does not depend on an import
## order. `GameManagerScript.GameState.PLAYING` is the same value; this is the readable form.
const STATE_PLAYING: int = 1

const REFUSE_NONE: StringName = &""
const REFUSE_NO_TIME_SOURCE: StringName = &"UI_NO_TIME_SOURCE"
const REFUSE_NOT_STARTED: StringName = &"UI_CLOCK_NOT_STARTED"
const REFUSE_NO_SETTLEMENT: StringName = &"UI_NO_SETTLEMENT"

## UI-SET-103, the New Settlement modal whose Create action this router performs.
const NEW_SETTLEMENT_ID: int = 103
## UI-SET-031's roster command and UI-SET-006's population counter, which both open the roster.
const ROSTER_ID: int = 31
const POPULATION_ID: int = 6
## GDD §4.3's FORAGING skill index, the one this milestone's detail row reports.
const FORAGING_SKILL: int = 0

var _hud: HudScript = null
var _time_source: GameManagerScript = null
var _bridge: UiCommandBridge = UiCommandBridge.new()
var _session: UiWorldSession = UiWorldSession.new()
## True once the player has resumed the world themselves. The opening pause is applied once.
var _player_has_resumed: bool = false
var _opening_pause_applied: bool = false
var _last_refusal: StringName = REFUSE_NONE
## Which resident slot each roster row currently IS. REQ-UX-013: identity, not a render index.
var _roster_slots: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	"""Stay alive through pauses, connect system signals, and report readiness."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	EconomySystem.stocks_changed.connect(_on_stocks_changed)
	EconomySystem.stock_depleted.connect(_on_stock_depleted)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.clock_diagnostic.connect(_on_clock_diagnostic)
	_bind_settlement()
	print("[UIManager] ready")


func _bind_settlement() -> void:
	"""Point the command bridge at the running settlement's ARCH-CMD-001 queue.

	Every zone, policy, cancellation and naming action the interface offers is submitted to that
	one queue, so a UI action and a replayed command travel the same path.
	"""
	if SettlementSystem == null:
		return
	_bridge.bind_queue(SettlementSystem.commands())


func register_hud(hud: HudScript) -> void:
	"""Bind the active HUD, give its shell the bridge and session, and push current state in."""
	if hud == null:
		push_error("UIManager.register_hud() was given null; the HUD will not update.")
		return
	_hud = hud
	var shell: UiShell = hud.shell()
	if shell != null:
		_bind_shell(shell)
	_refresh_hud()


func _bind_shell(shell: UiShell) -> void:
	"""Give the shell everything it may hold, and listen for the actions it cannot perform.

	The shell gets the command bridge, the New Settlement session and the ARCH-SYS-023 snapshot.
	It does NOT get a store: generation and selection need stores, so the shell asks for them by
	signal and this router, which owns the settlement reference, does the work.
	"""
	shell.bind_bridge(_bridge)
	shell.bind_session(_session)
	if SettlementSystem != null:
		shell.bind_presentation(SettlementSystem.presentation())
	if not shell.shell_action.is_connected(_on_shell_action):
		shell.shell_action.connect(_on_shell_action)
	if not shell.tile_picked.is_connected(_on_tile_picked):
		shell.tile_picked.connect(_on_tile_picked)
	if not shell.resident_row_picked.is_connected(_on_resident_row_picked):
		shell.resident_row_picked.connect(_on_resident_row_picked)


func _on_shell_action(element_id: int) -> void:
	"""Perform the one shell action that needs the settlement's stores: New Settlement."""
	if element_id == NEW_SETTLEMENT_ID:
		create_world()
		return
	if element_id == ROSTER_ID or element_id == POPULATION_ID:
		refresh_roster()


func create_world() -> bool:
	"""UI-SET-103's Create: discard the current settlement and create §5.1's world AND cohort.

	THE COHORT AND THEN ITS WORLD, in that order (R-INIT-ID-001). This generated the world and no residents,
	so pressing Create emptied the settlement it had just made and the HUD read
	"Residents 0" against a fully generated map. Decision 0071 fixed boot; the UI kept the
	poorer path.

	The session still generates, because it owns the published map, the attempt report and
	the generator's own refusal codes -- calling `create_generated_settlement()` instead
	bypassed all three and broke two tests that had every right to fail. The cohort is
	spawned after it, and a cohort refusal fails the WHOLE action rather than leaving a
	generated map with nobody on it.

	The reset is the PLAYER'S OWN DISCARD and happens first, because `world_init.gd` refuses to
	publish over live rows it does not own -- a settlement's residents are exactly that. One
	consequence is stated rather than hidden: if generation then refuses, the previous world is
	already gone and the settlement is left EMPTY, not restored. The refusal says so.
	"""
	if SettlementSystem == null:
		return _refuse(REFUSE_NO_SETTLEMENT)
	var report: UiWorldSession.Report = _session.last_report()
	var ok: bool = _session.create_with_cohort_into(SettlementSystem.directory(),
		SettlementSystem.ecology().resource_nodes(), SettlementSystem.ecology().forage(),
		SettlementSystem.ecology().fishing(), SettlementSystem.rng(),
		SettlementSystem.crop_weather().farming(), SettlementSystem.ecology().orchard_hive(),
		SettlementSystem.jobs(), SettlementSystem.commands(), report,
		SettlementSystem.reset, SettlementSystem.create_initial_settlement)
	if not ok and report.error == UiWorldSession.REFUSE_COHORT:
		report.error = SettlementSystem.last_refusal()
	_report_generation(ok, report)
	if ok and EconomySystem != null:
		EconomySystem.bind_residents(SettlementSystem.residents())
		refresh_roster()
	return ok


func _report_generation(ok: bool, report: UiWorldSession.Report) -> void:
	"""Put the generator's own counts, or its own refusal code, in front of the player."""
	if not _has_hud():
		return
	var shell: UiShell = _hud.shell()
	if ok:
		shell.report_action_result(true,
			"Settlement generated: %d resource nodes, %d basins, %d fish stocks, %d residents, seed %d."
			% [report.resource_nodes, report.basins, report.fish_stocks,
				SettlementSystem.population(), report.accepted_seed])
	else:
		shell.report_action_result(false,
			"Generation refused (%s): %s The settlement is now empty." % [report.error, report.detail])
	_refresh_hud()


func refresh_roster() -> bool:
	"""Fill UI-SET-069's rows from the living residents, or report that there are none.

	§4 binds a resident row to "Name/anonymous label+species+role+mood+health+current job". Four
	of those six have a store today; role and current job do not, and are left out rather than
	filled with a plausible word. `_roster_slots` records which resident each row IS, because
	REQ-UX-013 requires resolving persistent identity rather than a render index.
	"""
	if not _has_hud() or SettlementSystem == null:
		return _refuse(REFUSE_NO_SETTLEMENT)
	var residents: ResidentsScript = SettlementSystem.residents()
	var needs: NeedsScript = SettlementSystem.needs()
	_roster_slots.clear()
	var labels: PackedStringArray = PackedStringArray()
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if labels.size() >= UiShell.ROSTER_POOL:
			break
		if not residents.is_alive(slot):
			continue
		_roster_slots.append(slot)
		labels.append(_roster_label(residents, needs, slot))
	_hud.shell().set_roster(labels, residents.living_count())
	_last_refusal = REFUSE_NONE
	return true


func _roster_label(residents: ResidentsScript, needs: NeedsScript, slot: int) -> String:
	"""One row's visible text: the facts a store actually publishes for that resident."""
	var name_text: String = String(residents.name_key_of(slot)) if residents.is_named(slot) \
		else "Unnamed"
	var species: IntMath.IntResult = residents.species_of(slot)
	var health: IntMath.IntResult = needs.health_of(slot)
	var species_key: StringName = residents.species_key(species.value) if species.ok else &""
	return "%s  %s  health %d" % [name_text,
		String(species_key) if species_key != &"" else "unknown species",
		health.value if health.ok else 0]


func _on_resident_row_picked(row_index: int) -> void:
	"""Open UI-SET-036 on the resident that row IS, resolved through its stored slot."""
	if not _has_hud() or row_index < 0 or row_index >= _roster_slots.size():
		return
	var slot: int = _roster_slots[row_index]
	var residents: ResidentsScript = SettlementSystem.residents()
	var needs: NeedsScript = SettlementSystem.needs()
	if not residents.is_alive(slot):
		_hud.shell().report_action_result(false,
			"That resident is no longer living; the roster row is stale.")
		return
	_show_resident_detail(residents, needs, slot)


func _show_resident_detail(residents: ResidentsScript, needs: NeedsScript, slot: int) -> void:
	"""Fill the detail panel with that resident's real identity, need and skill rows."""
	var shell: UiShell = _hud.shell()
	var hunger: IntMath.IntResult = needs.need_of(slot, NeedsScript.NEED_HUNGER)
	var rest: IntMath.IntResult = needs.need_of(slot, NeedsScript.NEED_REST)
	var level: IntMath.IntResult = residents.skill_level_of(slot, FORAGING_SKILL)
	shell.set_detail_display(_roster_label(residents, needs, slot),
		"Hunger %d of %d; Rest %d of %d" % [hunger.value, NeedsScript.NEED_MAX,
			rest.value, NeedsScript.NEED_MAX],
		"Foraging level %d" % level.value if level.ok else "Foraging level unavailable")
	shell.select_resident(residents.ref_of(slot), "")
	shell.set_detail_open(true)


func _on_tile_picked(tile_index: int) -> void:
	"""Resolve the picked tile against the published map and open UI-SET-036 on it."""
	if not _has_hud():
		return
	var shell: UiShell = _hud.shell()
	if not _session.has_world():
		shell.report_action_result(false, "No world has been generated yet, so no tile can be inspected.")
		return
	_select_tile(shell, tile_index)


func _select_tile(shell: UiShell, tile_index: int) -> void:
	"""Point the zone tool at the picked tile's basin and describe the tile in the detail panel."""
	var world: WorldInitScript = _session.world()
	var basin_index: IntMath.IntResult = world.basin_index_at(tile_index)
	var terrain: IntMath.IntResult = world.terrain_at(tile_index)
	var title: String = "Tile %d,%d - %s" % [WorldInitScript.tile_x_of(tile_index),
		WorldInitScript.tile_z_of(tile_index),
		WorldInitScript.TERRAIN_KEYS[terrain.value] if terrain.ok else "unknown"]
	if not basin_index.ok or basin_index.value == WorldInitScript.NO_BASIN:
		shell.set_detail_display(title, "No ecology basin here.", "")
		shell.set_detail_open(true)
		return
	var danger: IntMath.IntResult = world.basin_danger_of(basin_index.value)
	shell.select_basin(world.basin_ref_of(basin_index.value), danger.value if danger.ok else 0)
	shell.set_detail_display(title, "Basin: %s" % WorldInitScript.BASIN_KEYS[basin_index.value],
		"Danger band %d" % (danger.value if danger.ok else 0))
	shell.set_detail_open(true)


func unregister_hud() -> void:
	"""Drop the HUD reference when its scene is leaving the tree."""
	_hud = null


func bind_time_source(source: GameManagerScript) -> void:
	"""Use an explicit clock owner instead of the autoload. Tests bind their own."""
	_time_source = source


func push_alert(text: String) -> void:
	"""Show a transient message in the top-centre alert zone."""
	if _has_hud():
		_hud.show_alert(text)


func push_refusal(code: StringName) -> void:
	"""Show an exact refusal code and its plain reading in UI-SET-085's accessible display."""
	if _has_hud():
		_hud.show_refusal(_bridge.refusal_sentence(code))


func _time() -> GameManagerScript:
	"""The bound clock owner, or the GameManager autoload when none was injected."""
	if _time_source != null:
		return _time_source
	return GameManager as GameManagerScript


func apply_opening_pause() -> bool:
	"""Hold UI-SET-103's PLAYER pause for the opening inspection, exactly once.

	Refuses before `start_game()`, because `pause_game()` does nothing on an unstarted clock and
	reporting success would claim an inspection pause that is not held.
	"""
	var manager: GameManagerScript = _time()
	if manager == null:
		return _refuse(REFUSE_NO_TIME_SOURCE)
	if manager.get_state() == GameManagerScript.GameState.BOOT:
		return _refuse(REFUSE_NOT_STARTED)
	manager.pause_game()
	_opening_pause_applied = true
	_last_refusal = REFUSE_NONE
	return true


func player_has_resumed() -> bool:
	"""True once the player has released the opening pause themselves."""
	return _player_has_resumed


func opening_pause_applied() -> bool:
	"""True once the opening inspection pause has been held for this world."""
	return _opening_pause_applied


func command_bridge() -> UiCommandBridge:
	"""The bridge every economic player action travels through."""
	return _bridge


func world_session() -> UiWorldSession:
	"""The UI-SET-103 New Settlement session."""
	return _session


func _has_hud() -> bool:
	"""True when a HUD is bound and has not been freed out from under us.

	A plain null check is not enough: a freed Object still compares != null.
	"""
	return _hud != null and is_instance_valid(_hud)


func _refresh_hud() -> void:
	"""Push every current value into a freshly registered HUD."""
	if not _has_hud():
		return
	_refresh_counters()
	_refresh_status()
	_refresh_world()


func _refresh_counters() -> void:
	"""Push every top-left counter this milestone can honestly derive.

	Five of the seven are supplied. `Food-days` is now among them: task 2.10 gave GDD §5.8 its
	divisor, so EconomySystem computes the figure whenever a residents store is bound and
	returns the unpopulated marker when one is not. Every value crosses this boundary EXACTLY as
	the system produced it -- the two text counters are forwarded verbatim and the three integer
	counters are forwarded unscaled, because a number invented or adjusted here would be
	indistinguishable on screen from one the simulation actually derived.

	`Fuel-days` stays unpopulated: its daily heating demand has no input in any implemented
	system (see EconomySystem.fuel_days_missing_input()). `Beds` stays unpopulated too, because
	it needs a Building/Room/Furniture store that does not exist. `Residents` is now supplied
	from the residents store's own living count when one is bound.
	"""
	if not _has_hud():
		return
	_hud.set_counter_text(&"Food-days", EconomySystem.food_days_text())
	_hud.set_counter_text(&"Fuel-days", EconomySystem.fuel_days_text())
	_hud.set_counter(&"Ready NP", EconomySystem.ready_nutrition_points(), "NP")
	_hud.set_counter(&"Wood", EconomySystem.stock_units(&"wood"), "U")
	_hud.set_counter(&"Stone", EconomySystem.stock_units(&"stone"), "U")
	_refresh_population()


func _refresh_population() -> void:
	"""Push UI-SET-006's living count, or leave it unpopulated when no cohort is bound.

	A generated world has terrain, trees, ore and fish and NOBODY LIVING IN IT: task 06 owns the
	resident fixture. Zero residents is the truth in that world and is printed as zero; an
	ABSENT residents store is a different statement and stays unpopulated.
	"""
	if not EconomySystem.has_residents():
		_hud.set_counter_text(&"Residents", HudScript.UNPOPULATED)
		return
	_hud.set_counter(&"Residents", EconomySystem.residents().living_count(), "")


func _refresh_status() -> void:
	"""Repaint the top-right state, speed and date readout, and the pause label, from the clock."""
	if not _has_hud():
		return
	var manager: GameManagerScript = _time()
	_hud.set_status(manager.get_state_name(), manager.get_speed(), manager.get_calendar_text())
	_hud.set_pause(manager.is_paused(), ", ".join(manager.get_pause_reason_names()))


func _refresh_world() -> void:
	"""Repaint UI-SET-021 with what the published map actually holds, or that none is published."""
	if not _has_hud():
		return
	var shell: UiShell = _hud.shell()
	if shell == null:
		return
	if not _session.has_world():
		shell.set_minimap_display("No world generated")
		return
	shell.set_minimap_display("%d x %d tiles, seed %d" % [WorldInitScript.MAP_TILES_X,
		WorldInitScript.MAP_TILES_Z, _session.world().published_seed().value])


func _on_stocks_changed() -> void:
	"""Repaint the top-left counters after a committed change to the stores."""
	_refresh_counters()


func _on_stock_depleted(item_key: StringName) -> void:
	"""Raise an alert when the last unit of an item leaves the stores."""
	push_alert("Out of %s!" % item_key)


func _on_state_changed(new_state: int) -> void:
	"""Refresh the status readout, and hold UI-SET-103's opening pause the first time only."""
	_refresh_status()
	if new_state != STATE_PLAYING:
		return
	if not _opening_pause_applied:
		apply_opening_pause()
		_refresh_status()
		return
	_player_has_resumed = true


func _on_speed_changed(_speed: int) -> void:
	"""Refresh the status readout after a speed change, including an overload step-down."""
	_refresh_status()


func _on_day_advanced(_absolute_day: int) -> void:
	"""Refresh the date readout when the offset calendar crosses into a new day."""
	_refresh_status()


func _on_clock_diagnostic(message: String) -> void:
	"""Surface a scheduler overload warning or diagnostic pause in the alert zone."""
	push_alert(message)


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
