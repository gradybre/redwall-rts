extends Node3D
## The live demo's water gameplay, part A: wading, swimming, diving, rescue and bridges. Decision 0196
## (live demo). Presentation over integer rules (swim_rules.gd names every number, cited or demo);
## nothing here writes into the simulation.
##
## REACHING THE WATER. The village square is ±20 m and the water lies east of it; the residents' walking
## area is widened to WALK_BOUNDS (the stream from above the neck, both banks and round the pond) for
## orders, formations and tunnels alike (tunnels are still refused under water: tunnel_rules.gd and
## water_map.gd `segment_crosses_water`). Routes are kept inside the woods' reach (water_links.gd AREA),
## and the water too deep to wade is a band of circles no walker enters (water_links.gd THE BAND).
##
## PLAYER VERBS (with the demo's selection):
##   right click deep water       swimmers swim out and tread water there; an otter over water deeper
##                                than it is tall dives (a planned dive); a non-swimmer is refused by name
##                                (water a mouse wades -- the ford, a bank's shallows -- is an ordinary move:
##                                nobody is sent to stand in the water, so the spots snap to the bank)
##   right click a bridge site    the selected build it (a planned bridge waiting for hands)
##   left click a bridge site     select it (a candidate span, or a bridge planned or built)
##   Water panel                  ◀ / ▶ step through the map's bridge candidates; "Span two banks…" then
##                                click one bank and the other; Build footbridge (plank) / Build log bridge
##                                (paid from the one stores, built by the selection or queued for the
##                                bridgewright); Dive in the pond (selected otters); Swim shortcuts on/off
##                                (HAZ-001 consent, for the selection); Cramp (demo): a selected swimmer in
##                                the water tires at once -- the rescue on demand
##   V / the Map layer picker     "Getting there: Water range" shows the zones for its subject
##                                (water_range.gd: one resident's own height; a group's per member, painted
##                                for the shortest, steppable member by member), the ford, the bridge
##                                candidates, the swim links and landings (decision 0292)
##
## TIME is the demo clock: air and stamina tick at 30 a second of demo time (none while paused), the
## work and the walking run 2x / 4x with the HUD. What happens goes to the one notice feed (Water).
##
## RESCUE INCIDENTS (decision 0331, review UX-011): every resident in difficulty is also a CRITICAL incident,
## "water:rescue:<who>" on that resident (demo_incidents.gd), so it queues in the top-centre alert zone until it
## is over. Its text is the Water panel's one incident line per victim (waterplay_text.gd `incident_words`),
## updated in place a few times a second (`sync_incidents`); it NEEDS A DECISION while nobody answers, is
## ASSIGNED once a responder is on it, RECOVERING while being brought ashore, RESOLVED once it is out.

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const BridgeViewScript := preload("res://demo/waterplay/bridge_view.gd")
const SwimViewScript := preload("res://demo/waterplay/swim_view.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const TextScript := preload("res://demo/waterplay/waterplay_text.gd")
const SwimTaskScript := preload("res://demo/waterplay/swim_task.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoPick := preload("res://demo/control/demo_pick.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const WaterRangeScript := preload("res://demo/waterplay/water_range.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The player did something with the water: show the Water panel (demo/ui/demo_detail_zone.gd).
signal panel_wanted

## The residents' walking area: the village square widened east over the stream, its far bank and round
## the pond (x -20..36 m, z -34..42 m).
const WALK_BOUNDS: AABB = AABB(Vector3(-20.0, 0.0, -34.0), Vector3(56.0, 4.0, 76.0))
## Small water props standing on land (water_dressing.gd PROP_PLACEMENTS), as circles: rod, net, rack.
const PROP_CIRCLES: Array[Vector3] = [Vector3(21.3, 0.3, 9.7), Vector3(21.0, 0.45, 5.2), Vector3(20.9, 0.6, 11.6)]
const PANEL_REFRESH_S: float = 0.25
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const RESCUE_KEY: String = "water:rescue:%d"
const DIVE_SPREAD_M: float = 1.4
const SWIM_SPREAD_M: float = 1.2
## A left click this near a bridge site's line selects it (m).
const PICK_SITE_M: float = 1.2
## The water's surface, for the pointer's ray (the level's drop below the datum).
const SURFACE_Y_M: float = -0.18
## THE SUNKEN FINDS (demo; freshwater and original -- mussels are the coast's, GDD §5.7): each dive's
## search draws one, deterministically from the dive's number hashed (`find_of`), by these per-mille
## bands. The seed makes the village's first dives a stone, a hook, silt and then a relic.
const FIND_SEED: int = 92
const FIND_NAMES: Array[String] = ["nothing but silt", "a smooth river stone", "a lost fishing float",
	"an old iron hook", "a sunken clay cup", "a relic"]
const FIND_BANDS: Array[int] = [300, 550, 730, 870, 960, 1000]
const FIND_RELIC: int = 5
const FIND_STONE: int = 1
const STONE_FIND_MILLI: int = 250
## A builder works a log off a lying trunk this far out from its middle (m, demo: beside a felled
## trunk's 1.1 m girth).
const TRUNK_SIDE_M: float = 1.6
## A span of two banks is named for the landing nearest it.
const SITE_NAMES: Dictionary = {&"fisher_shelter": "fisher's bridge", &"ford_west": "ford bridge",
	&"ford_east": "ford bridge", &"weir_bank": "weir bridge", &"boathouse": "boathouse bridge", &"pond_west": "pond bridge"}

var links: LinksScript = null
var bridges: BridgesScript = BridgesScript.new()
var state: StateScript = StateScript.new()
var motion: MotionScript = MotionScript.new()
var crossings: CrossingsScript = CrossingsScript.new()
var rescue: RescueScript = RescueScript.new()
var crew: CrewScript = CrewScript.new()
var text: TextScript = TextScript.new()
## Whose water range the Water range lens paints (decision 0292).
var water_range: WaterRangeScript = WaterRangeScript.new()
var bridge_view: BridgeViewScript = null
var swim_view: SwimViewScript = null
var panel: PanelScript = null
var services: ServicesScript = null
## Residents whose rescue incident is open (see RESCUE INCIDENTS).
var _rescue_open: PackedInt32Array = PackedInt32Array()
## The bridge site chosen for the panel: a candidate (index), or a surveyed span of two banks.
var site_candidate: int = 0
var site_custom: bool = false
var custom_a: Vector2 = Vector2.ZERO
var custom_b: Vector2 = Vector2.ZERO
## The span tool: armed, and its first bank once clicked.
var tool_armed: bool = false
var tool_has_first: bool = false
## Dives made, and what each find has turned up (FIND_NAMES order).
var dives: int = 0
var finds: PackedInt32Array = PackedInt32Array()

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _water: DemoWaterScript = null
var _map: WaterMapScript = null
var _stand: StandScript = null
## The chosen site's surveys by kind, and the site and layout they were taken for (`survey_site`).
var _surveys: Array[BridgesScript.Survey] = [BridgesScript.Survey.new(), BridgesScript.Survey.new()]
var _surveyed_site: Vector4 = Vector4.ZERO
var _surveyed_on: Vector3i = Vector3i(0, 0, -1)
var _read: IntMath.IntResult = IntMath.IntResult.new()
## The answer of a lookup (`ready_trunk_into`, `bridge_at_into`, `bridge_on_site_into`), kept apart from
## `_read` so a lookup never overwrites a store's answer in flight.
var _found: IntMath.IntResult = IntMath.IntResult.new()
var _refresh_in: float = 0.0
var _panel_was_shown: bool = false
var _cold_said: int = -1
var _overlay_revision: int = -1
var _point: Vector2 = Vector2.ZERO


static func walk_bounds(world_bounds: AABB) -> AABB:
	"""The residents' walking area: the world's own, widened over the water (WALK_BOUNDS)."""
	return world_bounds.merge(WALK_BOUNDS)


static func land_obstacles() -> Array[Vector3]:
	"""What the widened area adds for walkers on land (Vector3(x, radius, z)): every water-side building's
	footprint circle the village's list leaves out (the mill, the far sides of the boathouse, shelter
	and weir), and the small water props standing on the bank."""
	var out: Array[Vector3] = []
	for circle: Vector3 in WaterDressing.footprint_circles():
		if not WaterDressing.Layout.circle_reaches_play(circle):
			out.append(Vector3(circle.x, circle.z, circle.y))
	out.append_array(PROP_CIRCLES)
	return out


static func make_links(map: WaterMapScript, obstacles: Array[Vector3]) -> LinksScript:
	"""The band, swim links and connections for `map` among the walkers' land `obstacles`."""
	var out := LinksScript.new()
	out.build(map, obstacles)
	return out


func configure(cast: DemoCastScript, command: DemoCommandScript, camera: Camera3D, shared: ServicesScript,
		map: WaterMapScript, water_links: LinksScript, water: DemoWaterScript = null, stand: StandScript = null) -> void:
	"""Wire the water's gameplay into this village: its cast (already built on `water_links`' band over
	`map`), command layer and camera (none: no player input), shared services (none: a fresh set), the
	water node (its flood and overlay; none: neither) and the woods' trees (a log bridge's trunk; none:
	logs come from the log stack)."""
	name = "DemoWaterplay"
	services = shared if shared != null else ServicesScript.new()
	_cast = cast
	_command = command
	_camera = camera
	_map = map
	_water = water
	_stand = stand
	links = water_links
	finds.resize(FIND_NAMES.size())
	_set_up_state()
	water_range.configure(state, _name_of)
	motion.configure(map, state)
	bridges.configure(map, _bridge_obstacles(), links.area)
	crossings.configure(cast, map, links, bridges, state, motion)
	cast.space().crossings = crossings
	crossings.on_refused = _on_bank_refusal
	rescue.configure(cast, crossings, _say)
	crew.configure(cast, bridges, services.weather, services.props, _say.bind(false))
	text.configure(cast, state, motion, bridges, crew, rescue, services, map)
	_build_views()
	_hook_command()


func _set_up_state() -> void:
	"""One swim row per resident, by species and height."""
	var species := PackedStringArray()
	var heights := PackedInt32Array()
	for who: int in _cast.actor_count():
		var actor := _cast.actor(who) as DemoActorScript
		species.append(actor.species)
		heights.append(WaterRules.to_u(actor.height_m))
	state.setup(species, heights)


func _bridge_obstacles() -> Array[Vector3]:
	"""Everything a bridge's footings and deck must keep clear of: the cast's obstacles less the water's
	own band (a band circle is water, not a thing)."""
	var out: Array[Vector3] = []
	var band: Dictionary = {}
	for circle: Vector3 in links.band:
		band[circle] = true
	for circle: Vector3 in _cast.space().obstacles:
		if not band.has(circle):
			out.append(circle)
	return out


func _build_views() -> void:
	"""The bridges, the swimmers' ripples, bubbles and lines, and the Water panel."""
	bridge_view = BridgeViewScript.new()
	add_child(bridge_view)
	bridge_view.configure(bridges, services.props)
	swim_view = SwimViewScript.new()
	add_child(swim_view)
	swim_view.configure(_cast, state, motion, rescue)
	panel = PanelScript.new()
	add_child(panel)
	panel.build()
	panel.action.connect(on_action)
	if _water != null and _water.overlay() != null:
		_water.overlay().show_links(links.link_water_a, links.link_water_b)


func _hook_command() -> void:
	"""The water's clicks, orders, span tool, "doing" words and meters in the command layer."""
	if _command == null:
		return
	_command.add_ground_handlers(on_ground_click, on_ground_order)
	_command.add_task_text(task_text)
	_command.add_input_hook(handle_tool_input)
	_command.add_skill_text(skill_text)


# --- per frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the water on this frame's demo time; the panel and overlay on real time (they work paused).
	The panel is filled only while shown, and at once when it comes forward (never shown stale)."""
	step(_cast.clock.frame_usec if _cast != null else 0)
	bridge_view.refresh()
	_follow_selection()
	var shown: bool = panel.is_shown()
	if shown and not _panel_was_shown:
		_refresh_in = 0.0
	_panel_was_shown = shown
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		sync_incidents()
		if panel.is_shown():
			refresh_panel()
		panel.follow_hud()


func step(usec: int) -> void:
	"""Advance the water by `usec` demo microseconds: the day's cold and flood, the ticks of air and
	stamina, the rescue and the bridge crew."""
	_follow_conditions()
	state.advance_usec(usec)
	rescue.update(float(usec) / float(Rules.USEC_PER_SECOND))
	crew.update(usec)


func _follow_conditions() -> void:
	"""Cold water and the flood, from the one weather and the water node; the cold is announced once."""
	var cold: bool = Rules.cold_water(services.weather.day_temperature_tenths())
	motion.cold = cold
	if _water != null:
		motion.flood_rise_m = _water.flood_rise_m()
		var full: float = maxf(_water.flood_rise_full_m(), 1e-4)
		motion.flood_permille = clampi(roundi(motion.flood_rise_m / full * 1000.0), 0, Rules.PERMILLE)
	if int(cold) != _cold_said:
		if _cold_said >= 0:
			_say(text.cold_line(cold), cold)
		_cold_said = int(cold)


func _follow_selection() -> void:
	"""The overlay's zones follow the Water range lens's subject (water_range.gd): the selection, a group by
	its shortest member or the member stepped to, the mouse with nobody selected."""
	if _water == null or _command == null:
		return
	water_range.follow(_command.selected())
	if water_range.revision == _overlay_revision:
		return
	_overlay_revision = water_range.revision
	_water.overlay().set_body(water_range.paint_label(), water_range.paint_height_u())


func _name_of(who: int) -> String:
	"""A resident's name, as the panels show it."""
	return (_cast.actor(who) as DemoActorScript).display_name


func sync_incidents() -> void:
	"""Each resident in difficulty as its rescue incident, raised, updated in place, or resolved once it is out
	(see RESCUE INCIDENTS)."""
	var incidents: IncidentsScript = services.incidents
	for who: int in rescue.victims:
		var key: String = RESCUE_KEY % who
		if not incidents.update(key, rescue_state(who), text.incident_words(who)):
			incidents.raise(key, NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, text.incident_words(who),
				NoticesScript.TARGET_RESIDENT, who, rescue_state.bind(who))
			incidents.update(key, rescue_state(who))
			if not _rescue_open.has(who):
				_rescue_open.append(who)
	for k: int in range(_rescue_open.size() - 1, -1, -1):
		if not rescue.victims.has(_rescue_open[k]):
			incidents.resolve(RESCUE_KEY % _rescue_open[k])
			_rescue_open.remove_at(k)


func rescue_state(who: int) -> int:
	"""A victim's incident state (its watch): RESOLVED once out of difficulty, RECOVERING while being brought
	ashore, ASSIGNED with a responder on it, else needing a decision."""
	if not rescue.victims.has(who):
		return IncidentsScript.STATE_RESOLVED
	var task: Tasks.VictimTask = rescue.victim_task(who)
	if task == null or not task.engaged:
		return IncidentsScript.STATE_NEEDS_DECISION
	return IncidentsScript.STATE_RECOVERING if task.towed else IncidentsScript.STATE_ASSIGNED


func select_bridge(row: int) -> void:
	"""Show bridge `row`'s span as the chosen site, as a click on it does (the news's "Go to")."""
	if row >= 0 and row < BridgesScript.MAX_BRIDGES and bridges.phase[row] != BridgesScript.PHASE_FREE:
		_select_row(row)


func _say(line: String, warning: bool) -> void:
	"""Post a line to the one notice feed, from the water."""
	services.notices.post(NoticesScript.SOURCE_WATER, NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, line)


func _on_bank_refusal(who: int, why: StringName) -> void:
	"""A swimmer turned back at the bank (water_crossings.gd THE BANK RECHECK): the feed says why."""
	_say(text.bank_refusal_line(who, why), false)


func _answer(said: String) -> void:
	"""An order's answer: beside the selection, and the Water panel comes forward."""
	if _command != null and _command.panel() != null:
		_command.say(said)
	text.remember(said)
	_refresh_in = 0.0
	panel_wanted.emit()


# --- orders ---------------------------------------------------------------------------------------

func order_swim(members: PackedInt32Array, spot: Vector2) -> String:
	"""Swimmers among `members` swim out to `spot` (spread round it) and tread water; the rest are
	refused by name. Says what happened."""
	var sent: int = 0
	var refused := PackedStringArray()
	for k: int in members.size():
		var who: int = members[k]
		var why: StringName = state.swim_refusal(who, false)
		if why != Rules.REFUSE_NONE:
			refused.append(text.refusal_words(who, why))
			continue
		var at: Vector2 = spot + Vector2.from_angle(TAU * float(sent) / 5.0) * (SWIM_SPREAD_M if sent > 0 else 0.0)
		if not links.body_at_into(at, _read):
			at = spot
		brain_of(who).order_task(SwimTaskScript.new(motion, links, at))
		sent += 1
	return TextScript.sent_line(sent, "swimming out", refused)


func order_dive(members: PackedInt32Array, spot: Vector2) -> String:
	"""Divers among `members` dive at `spot` (planned dives, HAZ-002); anyone who cannot is refused with
	the reason. Says what happened."""
	var sent: int = 0
	var refused := PackedStringArray()
	for who: int in members:
		var at: Vector2 = spot + Vector2.from_angle(TAU * float(sent) / 4.0) * (DIVE_SPREAD_M if sent > 0 else 0.0)
		var why: StringName = dive_refusal(who, at)
		if why != Rules.REFUSE_NONE:
			refused.append(text.refusal_words(who, why, at))
			continue
		var down: float = motion.max_dive_m(who, at)
		brain_of(who).order_task(DiveTaskScript.new(motion, links, at, down, roll_find, find_home))
		sent += 1
	return TextScript.sent_line(sent, "diving", refused)


func dive_refusal(who: int, at: Vector2) -> StringName:
	"""Why `who` may not dive at `at` now (Rules.REFUSE_NONE: it may): capability, the depth for its own
	height (water_rules.gd's DIVE zone), consent and rest."""
	if not state.can_dive(who):
		return Rules.REFUSE_CANNOT_DIVE
	if motion.zone_for(who, at) != WaterRules.ZONE_DIVE or motion.max_dive_m(who, at) <= 0.0:
		return Rules.REFUSE_TOO_SHALLOW
	return state.swim_refusal(who, false)


func roll_find(_brain: RefCounted) -> int:
	"""What a finished search brings up: the next dive's find (see THE SUNKEN FINDS)."""
	dives += 1
	return find_of(dives)


static func find_of(dive: int) -> int:
	"""The find of the village's `dive`-th dive (1, 2, ...): a 32-bit avalanche hash of its number and
	FIND_SEED, per mille, in FIND_BANDS. Integer and deterministic."""
	var x: int = (dive * 2654435761 + FIND_SEED * 40503) & 0xFFFFFFFF
	x ^= x >> 15
	x = (x * 2246822519) & 0xFFFFFFFF
	x ^= x >> 13
	var roll: int = x % 1000
	for k: int in FIND_BANDS.size():
		if roll < FIND_BANDS[k]:
			return k
	return 0


func find_home(brain: RefCounted, find: int) -> void:
	"""A diver is up the bank with its find: tallied, a stone to the stores, a relic to the finds."""
	var who: int = brain.index
	if find < 0:
		_say("%s came back up with nothing: the air ran short" % name_of(who), false)
		return
	finds[find] += 1
	if find == FIND_RELIC:
		services.stores.add_find(FindsScript.FIND_RELIC)
	elif find == FIND_STONE:
		services.stores.add_stone(STONE_FIND_MILLI)
	_say("%s brought up %s from the pond" % [name_of(who), FIND_NAMES[find]], false)


func cramp(members: PackedInt32Array) -> String:
	"""THE TEST (demo): every selected resident swimming now tires at once -- in difficulty."""
	var hit: int = 0
	for who: int in members:
		if brain_of(who).in_water and not brain_of(who).water_hold:
			state.rest[who] = 0
			rescue.start_difficulty(who)
			hit += 1
	return "Cramp (demo): %d swimmer%s in difficulty" % [hit, "" if hit == 1 else "s"] if hit > 0 else "Cramp (demo): select a resident in the water"


func toggle_consent(members: PackedInt32Array) -> String:
	"""Swim shortcuts (HAZ-001's consent) on or off for the selection (every swimmer with none)."""
	var targets: PackedInt32Array = members if not members.is_empty() else PackedInt32Array(range(state.count))
	var on: bool = not consent_shown(targets)
	for who: int in targets:
		state.set_consent(who, on)
	return "Swim shortcuts %s for %s" % ["on" if on else "off", "the selection" if not members.is_empty() else "everyone"]


func consent_shown(targets: PackedInt32Array) -> bool:
	"""Whether swim shortcuts show as on: every one of `targets` who swims consents."""
	for who: int in targets:
		if state.can_swim(who) and state.consent[who] == 0:
			return false
	return true


# --- bridges ---------------------------------------------------------------------------------------

func survey_site(kind: int) -> BridgesScript.Survey:
	"""The chosen site surveyed for `kind`. A survey walks every obstacle (about 2 ms), so both kinds are
	surveyed again only when the site or the bridges' layout has changed; callers read, never write."""
	var site: Vector4 = Vector4(custom_a.x, custom_a.y, custom_b.x, custom_b.y) if site_custom else Vector4.ZERO
	var on: Vector3i = Vector3i(int(site_custom), site_candidate, bridges.layout)
	if site != _surveyed_site or on != _surveyed_on:
		_surveyed_site = site
		_surveyed_on = on
		for k: int in _surveys.size():
			if site_custom:
				bridges.survey_into(custom_a, custom_b, k, _surveys[k])
			else:
				bridges.survey_candidate_into(site_candidate, k, _surveys[k])
	return _surveys[kind]


func build(kind: int, members: PackedInt32Array) -> String:
	"""Plan and pay for a `kind` bridge at the chosen site, and set it building (see bridge_crew.gd).
	Refused in words: the site, the stores, or no free row."""
	var survey: BridgesScript.Survey = survey_site(kind)
	if not survey.ok:
		return "Can't build a %s here: %s" % [Rules.KIND_NAMES[kind], survey.reason]
	var source: PackedVector2Array = PackedVector2Array()
	var paid: String = _pay(survey, source, brain_of(members[0]).surface_point() if not members.is_empty() else survey.shore_a)
	if not paid.is_empty():
		return paid
	if not bridges.plan_into(survey, site_name(), _read):
		_refund(survey, source)
		return "Can't build: %s" % _read.error
	crossings.bump()
	bridge_view.hide_survey()
	var row: int = _read.value
	_say("%s planned: a %s, %s" % [TextScript.first_up(bridges.names[row]), Rules.KIND_NAMES[kind], TextScript.cost_words(survey)], false)
	return crew.start(row, int(source[0].x), source[1], members)


func _pay(survey: BridgesScript.Survey, source: PackedVector2Array, near: Vector2) -> String:
	"""Take the bridge's material from the one stores (a log: from the felled trunk lying ready nearest
	`near` -- the builder, else the site) -- all of it, or (a refusal in words) none. `source` gets
	[(SOURCE_*, 0), where it is]."""
	var stores: StoresScript = services.stores
	if survey.kind == Rules.KIND_PLANK:
		if not stores.can_pay_planks(survey.planks_milli) or stores.wood_milli_u < survey.wood_milli:
			return TextScript.short_line(survey, stores)
		stores.pay_planks(survey.planks_milli)
		stores.take_wood(survey.wood_milli)
		source.append_array([Vector2(CrewScript.SOURCE_PLANKS, 0.0), Yard.at(Yard.PLANK_STACK)])
		return ""
	if ready_trunk_into(near, _found) and _stand.take_trunk_into(_found.value, Rules.LOG_WOOD_MILLI, _read):
		source.append_array([Vector2(CrewScript.SOURCE_TRUNK, 0.0), beside_trunk(_found.value, near)])
		return ""
	if not stores.take_wood(Rules.LOG_WOOD_MILLI):
		return TextScript.short_line(survey, stores)
	source.append_array([Vector2(CrewScript.SOURCE_LOG_STACK, 0.0), Yard.log_stack_at()])
	return ""


func _refund(survey: BridgesScript.Survey, source: PackedVector2Array) -> void:
	"""Put back what `_pay` took (no row was free): planks and pier wood, or the log as wood."""
	if survey.kind == Rules.KIND_PLANK:
		services.stores.add_planks(survey.planks_milli)
		services.stores.add_wood(survey.wood_milli)
	elif int(source[0].x) != CrewScript.SOURCE_PLANKS:
		services.stores.add_wood(Rules.LOG_WOOD_MILLI)


func beside_trunk(trunk: int, near: Vector2) -> Vector2:
	"""Where a builder stands to work a log off a lying trunk: beside its middle, TRUNK_SIDE_M out across
	it on the side nearer `near` (not along it, where the trunk lies)."""
	var middle: Vector2 = Roots.trunk_middle(_stand, trunk)
	var across: Vector2 = _stand.fall_dir[trunk].orthogonal()
	var side: float = 1.0 if across.dot(near - middle) >= 0.0 else -1.0
	return middle + across * side * TRUNK_SIDE_M


func ready_trunk_into(near: Vector2, out: IntMath.IntResult) -> bool:
	"""The felled trunk lying nearest `near` with a log's worth of wood in it, into `out`; refuses when
	no trunk (or no woods) has one."""
	if _stand == null:
		return out.refuse("NO_WOODS")
	var best_d: float = INF
	for t: int in _stand.count():
		if _stand.trunk_milli[t] < Rules.LOG_WOOD_MILLI:
			continue
		var d: float = Roots.trunk_middle(_stand, t).distance_to(near)
		if d < best_d:
			best_d = d
			out.value = t
	if best_d == INF:
		return out.refuse("NO_READY_TRUNK")
	return out.succeed(out.value)


func site_name() -> String:
	"""A name for a bridge at the chosen site: the neck (the narrowest candidate), the upper reaches, or
	for a span of two banks the landing nearest it (SITE_NAMES), numbered when that name is taken."""
	if not site_custom:
		return "neck bridge" if site_candidate == 0 else "upper bridge %d" % site_candidate
	var map: WaterMapScript = _map
	var mid: Vector2 = (custom_a + custom_b) * 0.5
	var best: int = 0
	for k: int in map.landing_count():
		if _m(map.landing_water(k)).distance_to(mid) < _m(map.landing_water(best)).distance_to(mid):
			best = k
	var base: String = String(SITE_NAMES.get(map.landing_name(best), "stream bridge"))
	var name: String = base
	var n: int = 1
	while bridges.names.has(name):
		n += 1
		name = "%s %d" % [base, n]
	return name


static func _m(at_u: Vector2i) -> Vector2:
	"""An integer point as metres."""
	return Vector2(WaterRules.to_m(at_u.x), WaterRules.to_m(at_u.y))


# --- input -----------------------------------------------------------------------------------------

func _point_at(screen: Vector2, y: float) -> bool:
	"""The point on the plane at height `y` under a screen point, into `_point`. False when missed."""
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	var t: float = DemoPick.ray_ground(origin, direction, y)
	if t < 0.0:
		return false
	var at: Vector3 = origin + direction * t
	_point = Vector2(at.x, at.z)
	return true


func on_ground_order(screen: Vector2) -> bool:
	"""A right click with residents selected: a bridge site's hands, or a swim or a dive (see the
	header). Anything else is not the water's."""
	if not _point_at(screen, SURFACE_Y_M):
		return false
	var members: PackedInt32Array = _command.selected()
	if bridge_at_into(_point, _found) and bridges.is_planned(_found.value):
		var row: int = _found.value
		_answer(crew.start(row, crew.source[row], crew.source_at[row], members))
		_command.mark(Vector3(_point.x, 0.0, _point.y), true)
		return true
	if not is_swim_water(_point):
		return false
	var said: String = order_dive(members, _point) if wants_dive(members, _point) else order_swim(members, _point)
	_command.mark(Vector3(_point.x, SURFACE_Y_M, _point.y), not said.begins_with("Can't"))
	_answer(said)
	return true


func is_swim_water(at: Vector2) -> bool:
	"""Whether a right click at `at` is a swim or dive order: water deeper than a mouse wades. The ford
	and the banks' shallows are an ordinary move, whose spots snap to dry ground."""
	return _map.depth_at(MotionScript.u_of(at)) > WaterRules.wade_max_u(WaterRules.MOUSE_HEIGHT_U)


func wants_dive(members: PackedInt32Array, at: Vector2) -> bool:
	"""Whether a click on the water is a dive: some selected resident dives, and dives there."""
	for who: int in members:
		if dive_refusal(who, at) != Rules.REFUSE_CANNOT_DIVE and state.can_dive(who) \
				and motion.zone_for(who, at) == WaterRules.ZONE_DIVE:
			return true
	return false


func on_ground_click(screen: Vector2) -> bool:
	"""A left click on no resident: a bridge candidate's span or a bridge selects it for the panel."""
	if tool_armed or not _point_at(screen, 0.0):
		return false
	if bridge_at_into(_point, _found):
		_select_row(_found.value)
		return true
	for k: int in bridges.candidate_count():
		var ends: PackedVector2Array = bridges.candidate_ends(k)
		if CrossingsScript._segment_distance(_point, ends[0], ends[1]) <= PICK_SITE_M:
			select_candidate(k)
			return true
	return false


func bridge_on_site_into(out: IntMath.IntResult) -> bool:
	"""The planned or open bridge standing at the chosen site (its middle within BRIDGE_GAP_M of the
	site's line), into `out`; refuses when none does."""
	var ends: PackedVector2Array = PackedVector2Array([custom_a, custom_b]) if site_custom else bridges.candidate_ends(site_candidate)
	if ends.size() < 2:
		return out.refuse("NO_SITE")
	for row: int in BridgesScript.MAX_BRIDGES:
		if bridges.phase[row] != BridgesScript.PHASE_FREE and CrossingsScript._segment_distance(
				(bridges.shore_a[row] + bridges.shore_b[row]) * 0.5, ends[0], ends[1]) < BridgesScript.BRIDGE_GAP_M:
			return out.succeed(row)
	return out.refuse("NO_BRIDGE_ON_SITE")


func bridge_at_into(at: Vector2, out: IntMath.IntResult) -> bool:
	"""The planned or open bridge whose deck line passes within PICK_SITE_M of `at`, into `out`; refuses
	when none does."""
	for row: int in BridgesScript.MAX_BRIDGES:
		if bridges.phase[row] != BridgesScript.PHASE_FREE and \
				CrossingsScript._segment_distance(at, bridges.approach(row, false), bridges.approach(row, true)) <= PICK_SITE_M:
			return out.succeed(row)
	return out.refuse("NO_BRIDGE_HERE")


func _select_row(row: int) -> void:
	"""Show a planned or open bridge's own span as the chosen site."""
	site_custom = true
	custom_a = bridges.approach(row, false)
	custom_b = bridges.approach(row, true)
	bridge_view.hide_survey()
	_refresh_in = 0.0
	panel_wanted.emit()


func select_candidate(k: int) -> void:
	"""Choose the map's bridge candidate `k` as the site (wrapping round)."""
	var n: int = maxi(bridges.candidate_count(), 1)
	site_candidate = posmod(k, n)
	site_custom = false
	var ends: PackedVector2Array = bridges.candidate_ends(site_candidate)
	if ends.size() == 2 and not bridge_on_site_into(_found):
		bridge_view.show_survey(ends[0], ends[1], survey_site(Rules.KIND_PLANK).ok or survey_site(Rules.KIND_LOG).ok)
	else:
		bridge_view.hide_survey()
	_refresh_in = 0.0
	panel_wanted.emit()


func handle_tool_input(event: InputEvent) -> bool:
	"""The span tool, while armed: a left click on a bank starts the span, the pointer draws it and the
	next click ends it (surveyed for the panel); Esc or a right click puts the tool away. True: taken."""
	if not tool_armed:
		return false
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and _point_at(button.position, 0.0):
		_tool_click(_point)
		return true
	var motion_event := event as InputEventMouseMotion
	if motion_event != null and tool_has_first and _point_at(motion_event.position, 0.0):
		bridge_view.show_survey(custom_a, _point, false)
		return false
	var key := event as InputEventKey
	var cancel: bool = key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE
	if cancel or (button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT):
		disarm_tool()
		_answer("Span tool put away")
		return true
	return button != null


func _tool_click(at: Vector2) -> void:
	"""A bank clicked with the span tool: the first end, or the second -- then the span is surveyed."""
	if not tool_has_first:
		custom_a = at
		tool_has_first = true
		_answer("Now click the far bank")
		return
	custom_b = at
	site_custom = true
	disarm_tool()
	var ok: bool = survey_site(Rules.KIND_PLANK).ok or survey_site(Rules.KIND_LOG).ok
	bridge_view.show_survey(custom_a, custom_b, ok)
	_answer(TextScript.site_answer(survey_site(Rules.KIND_PLANK), survey_site(Rules.KIND_LOG)))


func arm_tool() -> void:
	"""Arm the span tool (or, armed, put it away)."""
	if tool_armed:
		disarm_tool()
		return
	tool_armed = true
	tool_has_first = false
	panel.set_tool_armed(true)
	_answer("Click a point on one bank of the stream (Esc: cancel)")


func disarm_tool() -> void:
	"""Put the span tool away."""
	tool_armed = false
	tool_has_first = false
	panel.set_tool_armed(false)


# --- the panel ------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Water panel button (water_panel.gd ACTION_*)."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	match action_name:
		PanelScript.ACTION_PREV_SITE:
			select_candidate(site_candidate - (0 if site_custom else 1))
		PanelScript.ACTION_NEXT_SITE:
			select_candidate(site_candidate + (0 if site_custom else 1))
		PanelScript.ACTION_SPAN_TOOL:
			arm_tool()
		PanelScript.ACTION_BUILD_PLANK:
			_answer(build(Rules.KIND_PLANK, members))
		PanelScript.ACTION_BUILD_LOG:
			_answer(build(Rules.KIND_LOG, members))
		PanelScript.ACTION_DIVE:
			_answer(order_dive(members, pond_dive_spot()) if not members.is_empty() else "Select an otter to dive")
		PanelScript.ACTION_CONSENT:
			_answer(toggle_consent(members))
		PanelScript.ACTION_CRAMP:
			_answer(cramp(members))
	_refresh_in = 0.0


func pond_dive_spot() -> Vector2:
	"""The pond's deepest point: its first circle's centre."""
	var map: WaterMapScript = _map
	for body: int in map.body_count():
		if map.body_kind(body) == WaterMapScript.KIND_POND:
			var seg: PackedInt32Array = map.segment(map.body_segment_range(body).x)
			return Vector2(WaterRules.to_m(seg[0]), WaterRules.to_m(seg[1]))
	return Vector2.ZERO


func refresh_panel() -> void:
	"""Fill the Water panel from the state, the bridges, the stores and the feed."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	panel.show_water(text.conditions_line(), text.alert_line(), text.swimmers_title(), text.swimmers_text())
	panel.set_swim_buttons(consent_shown(members if not members.is_empty() else PackedInt32Array(range(state.count))),
		{PanelScript.ACTION_DIVE: text.any_diver(members), PanelScript.ACTION_CRAMP: text.any_in_water(members)})
	var plank: BridgesScript.Survey = survey_site(Rules.KIND_PLANK)
	var log: BridgesScript.Survey = survey_site(Rules.KIND_LOG)
	var about: String = text.standing_text(_found.value) if bridge_on_site_into(_found) \
		else TextScript.site_text(plank, log, ready_trunk_into(log.shore_a, _found))
	panel.show_site(text.site_title(site_custom, site_candidate), about,
		{PanelScript.ACTION_BUILD_PLANK: plank.ok, PanelScript.ACTION_BUILD_LOG: log.ok})
	panel.show_status(text.bridges_text(), services.stores.stock_line(), text.log_text())


func task_text(who: int) -> String:
	"""What `who` is doing for the water ("" for nothing): building a bridge, or crossing."""
	var building: String = crew.task_text(who)
	if not building.is_empty():
		return building
	var brain: BrainScript = brain_of(who)
	return crossings.leg_text(brain) if brain.state == BrainScript.State.CROSS else ""


func skill_text(who: int, alone: bool) -> String:
	"""A resident's bridge building, swimming, breath and stamina for the party panel."""
	return text.skill_line(who, alone)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name


func cast() -> DemoCastScript:
	"""The cast the water moves."""
	return _cast


func water_node() -> DemoWaterScript:
	"""The water node (its flood and overlay; null without one)."""
	return _water


func map() -> WaterMapScript:
	"""The water map the gameplay runs on."""
	return _map
