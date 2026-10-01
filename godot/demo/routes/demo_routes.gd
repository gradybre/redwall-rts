extends Node
## ROUTES AND INFRASTRUCTURE PREVIEWS in the live demo: whether a bridge or a tunnel is worth building, how far a
## project has got and what it needs, how the selected residents will get there and what holds them up, the village's
## public ways, and each rescue's card. Decision 0461 (review P5, ECO-039, ECO-045). Presentation only.
##
## THE WATER PANEL'S SITE (`fill_site`, called by demo_waterplay.gd `refresh_panel` through `site_extras`):
##   * no bridge there -- each kind's shortage ("Plank footbridge: missing 4.7 U planks") with the SOURCE button to
##     what supplies it (the saw's task on the Work screen, else the Woods panel where Saw planks is; a log: the woods);
##     the Build buttons show only for a kind that can be built now (water_panel.gd); and the BENEFIT of the bridge the
##     panel would build (the footbridge where it fits, else the log bridge), estimated for up to three work trips that
##     cross the water, before and after, by route_estimator.gd -- with who can use it and its cost from the Build
##     button's own action card (decision 0332);
##   * a planned bridge -- its materials (paid all or nothing when it was planned, so none is missing) reserved at their
##     source, being carried, or delivered at the site; its stages' work; its builder; SOURCE: its task on the Work
##     screen;
##   * an open bridge -- its ROUTE and CONDITION, not construction controls: who may cross, the walk across, and the
##     route a work trip takes now.
## THE TUNNEL PANEL'S PROJECT (`project_text`, tunnel_ext.gd): the piece being laid in the Dig tool (its benefit, as
## laid and dug open, once the plan's whole-piece check passes), else the first dig in the job list: its STAGES and any
## dead-end heading (dig_stages.gd), the next payoff with its benefit (the piece dug to that stage), who fits it, and
## that digging takes no materials; Work ▸ opens the Work screen's projects.
## THE ROUTES LAYER ("Getting there: Routes", route_overlay.gd): the selected residents' routes and hold-ups, or with
## nobody selected the public ways (public walker: carrying, never swimming), a narrow body's tunnel shortcut beside
## one where there is one, and the swim links, drawn as what they are: optional crossings for swimmers. A swimmer's
## whole trip is not estimated for the layer -- a plan offered the swim links costs a dozen surface plans, tens of
## milliseconds -- the links themselves are the shortcut.
## THE RESCUE CARD (rescue_card.gd): demo_village.gd gives it to the incident card (`add_details`).
##
## THE BUDGET. The estimates are worked here, ONE step a frame across all of them, only for what is on screen (the
## Water panel shown, the Tunnels panel shown, the Routes layer on with nobody selected), through the cast's routing
## desk (route_estimator.gd THE BUDGET) -- at the END of the frame's routing window (demo_cast.gd `window_tail`), so
## the residents plan first and a preview takes only what they left. The panels' words are refreshed a few times a
## second on real time. An estimate is begun again when what it is for changes: the trips, the walker, the proposal,
## and (through route_estimator.gd STALE) the network, the water's crossings or the weather; a bridge planned or opened
## changes `_bridge_state` -- never its work in progress, which moves ten times a second.

const EstimatorScript := preload("res://demo/routes/route_estimator.gd")
const KindsScript := preload("res://demo/routes/route_kinds.gd")
const ReasonsScript := preload("res://demo/routes/route_reasons.gd")
const StagesScript := preload("res://demo/routes/dig_stages.gd")
const TextScript := preload("res://demo/routes/route_text.gd")
const TripsScript := preload("res://demo/routes/work_trips.gd")
const OverlayScript := preload("res://demo/routes/route_overlay.gd")
const SubjectScript := preload("res://demo/routes/routes_subject.gd")
const RescueCardScript := preload("res://demo/routes/rescue_card.gd")
const ProjectScript := preload("res://demo/routes/bridge_project.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const ToolScript := preload("res://demo/tunnel/tunnel_control.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const WorkScript := preload("res://demo/work/demo_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const WorkScreenScript := preload("res://demo/work/work_screen.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const TaskRowScript := preload("res://demo/work/work_task_row.gd")

const QUESTION: String = "How do they get there, and what holds them up?"
const REFRESH_S: float = 0.25
## Trips a bridge or a tunnel is estimated for.
const PREVIEW_TRIPS: int = 3
## Members a group's notes name before "and N more".
const NOTES_MEMBERS: int = 4
## The source button's targets.
const SOURCE_NONE: int = 0
const SOURCE_SAW: int = 1
const SOURCE_WOODS: int = 2
const SOURCE_BRIDGE_TASK: int = 3
const SOURCE_CAPTIONS: Array[String] = ["", "Saw planks ▸", "Woods: fell or haul logs ▸", "Bridge task ▸"]
const SOURCE_TIPS: Array[String] = ["", "The sawhorse's planks: the Work screen's saw task if one is queued, else the Woods panel's Saw planks — nothing is ordered for you",
	"A log: fell a tree in the Woods panel, or haul logs to the log stack — nothing is ordered for you",
	"This bridge's task on the Work screen: its builder, its step, why it waits"]
## A dig tick in demo microseconds (30 ticks a second at one F1000 digger: underground_graph.gd THE DIG TIMELINE).
const TICK_USEC: int = 1000000 / Rules.TICKS_PER_SECOND
const DIG_MATERIALS: String = "Materials: none to dig — its spoil goes to the heap at its mouth"

var trips: TripsScript = TripsScript.new()
var kinds: KindsScript = KindsScript.new()
var bridge_estimate: EstimatorScript = EstimatorScript.new(PREVIEW_TRIPS)
var dig_estimate: EstimatorScript = EstimatorScript.new(PREVIEW_TRIPS + 1)
var public_estimate: EstimatorScript = EstimatorScript.new(TripsScript.DISTRICTS.size())
var shortcut_estimate: EstimatorScript = EstimatorScript.new(TripsScript.DISTRICTS.size())
var overlay: OverlayScript = null
var subject: SubjectScript = SubjectScript.new()
var rescue_card: RescueCardScript = RescueCardScript.new()
var stages: StagesScript = StagesScript.new()
## Steps worked this session (measurement).
var steps: int = 0

var _cast: DemoCastScript = null
var _command: CommandScript = null
var _water: WaterplayScript = null
var _tool: ToolScript = null
var _work: WorkScript = null
var _jobs: ForestJobs = null
var _show_woods: Callable = Callable()
var _estimates: Array[EstimatorScript] = []
var _turn: int = 0
var _refresh_in: float = 0.0
var _selection_seen: int = -1
var _found: IntMath.IntResult = IntMath.IntResult.new()
var _trip_ids: PackedInt32Array = PackedInt32Array()
var _source: int = SOURCE_NONE
var _source_row: int = -1
var _piece_key: int = 0
var _piece_ok: bool = false
var _laid: SpecScript = null
var _crosses: Callable = Callable()
var _scratch: BridgesScript = null
var _scratch_key: int = 0
var _where: ReasonsScript.Where = ReasonsScript.Where.new()
var _boat_leg: PackedVector2Array = PackedVector2Array()


func configure(cast: DemoCastScript, command: CommandScript, water: WaterplayScript, tool: ToolScript,
		work: WorkScript, jobs: ForestJobs, show_woods: Callable) -> void:
	"""Preview over this village: its cast, command layer, water, Dig tool and Work screen; the woods' jobs (a saw task)
	and how to bring the Woods panel forward."""
	name = "DemoRoutes"
	_cast = cast
	_command = command
	_water = water
	_tool = tool
	_work = work
	_jobs = jobs
	_show_woods = show_woods
	var space: CastSpaceScript = cast.space()
	trips.resolve(space, water.map())
	kinds.configure(space.crossings, CrossingsScript.LINK_ROW0, water.links.link_count)
	_crosses = func(a: Vector2, b: Vector2) -> bool:
		return water.map().segment_crosses_water(MotionScript.u_of(a), MotionScript.u_of(b), 0)
	_estimates = [bridge_estimate, dig_estimate, public_estimate, shortcut_estimate]
	for estimate: EstimatorScript in _estimates:
		estimate.configure(space.nav, space.tunnels, space.crossings, _crosses)
	rescue_card.configure(water.rescue, water.state, cast)
	_build_overlay()
	water.site_extras = fill_site
	cast.window_tail = step_one
	water.panel.action.connect(_on_water_action)
	tool.ext.project_text = project_text
	tool.ext.project_link = open_work_projects


func _build_overlay() -> void:
	"""The Routes layer's drawing."""
	overlay = OverlayScript.new()
	add_child(overlay)
	overlay.configure(_cast, _cast.space().tunnels, kinds)
	overlay.public_estimate = public_estimate
	overlay.shortcut_estimate = shortcut_estimate
	overlay.public_label = public_label
	overlay.public_shortcut = public_shortcut
	overlay.set_swim_links(_water.links.link_land_a, _water.links.link_land_b)


static func legend_swatches() -> PackedColorArray:
	"""The Routes layer's legend swatches (map_lenses.gd `set_legend`), one per `legend_words`."""
	var out := PackedColorArray(OverlayScript.KIND_COLOURS.slice(0, 6))
	out.append(OverlayScript.KIND_COLOURS[KindsScript.KIND_FERRY])
	out.append_array([OverlayScript.WAIT_COLOUR, OverlayScript.BLOCK_COLOUR, Color(0, 0, 0, 0)])
	return out


static func legend_words() -> PackedStringArray:
	"""The legend's words: each stretch, the two posts, and the promise that nobody is made to swim (ECO-039)."""
	return PackedStringArray(["surface", "wading", "underground (dashed)", "bridge", "swimming (optional)", "by boat",
		"by ferry", "post: waiting", "post: blocked", "public ways never swim"])


func show_lens(on: bool) -> void:
	"""The Routes layer's switch."""
	overlay.set_shown(on)
	_selection_seen = -1
	_refresh_in = 0.0


# --- per frame ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""One estimate step for what is on screen; the layer follows the selection; words a few times a second."""
	if overlay.is_shown() and _command != null and _command.selection_revision() != _selection_seen:
		_selection_seen = _command.selection_revision()
		overlay.follow(_command.selected())
		_refresh_in = 0.0
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	if overlay.is_shown():
		refresh_lens()


func step_one() -> void:
	"""ONE step of one estimate a frame (see THE BUDGET), taking turns among those wanted now -- one refused (resting,
	or no room) leaves the frame's step to the next. Run as the cast's `window_tail`: after the residents' plans, in
	the window they leave."""
	for n: int in _estimates.size():
		var k: int = (_turn + n) % _estimates.size()
		if _wanted(k) and _estimates[k].is_calculating() and _estimates[k].step(_cast.space().routes):
			_turn = k + 1
			steps += 1
			return


func _wanted(k: int) -> bool:
	"""Whether estimate `k` is on screen: the bridge's in the Water panel, the dig's in the Tunnels panel, the public
	ways' on the Routes layer with nobody selected."""
	match k:
		0:
			return _water.panel.is_shown()
		1:
			return _tool.ext.panel.is_shown()
	return overlay.is_shown() and overlay.members.is_empty()


# --- the Water panel's site ---------------------------------------------------------------------------------

func fill_site(members: PackedInt32Array) -> void:
	"""The site's project and benefit lines and its source button (see THE WATER PANEL'S SITE)."""
	if _water.bridge_on_site_into(_found):
		_fill_standing(_found.value, members)
		return
	var project := PackedStringArray()
	_source = SOURCE_NONE
	for kind: int in 2:
		var line: String = _shortage_line(kind, members)
		if not line.is_empty():
			project.append(line)
	var kind: int = SwimRules.KIND_PLANK if _water.survey_site(SwimRules.KIND_PLANK).ok else SwimRules.KIND_LOG
	var benefit: String = ""
	if _water.survey_site(kind).ok:
		benefit = "\n".join(_bridge_benefit(kind, members))
	_water.panel.show_routes("\n".join(project), benefit)
	_water.panel.set_source(SOURCE_CAPTIONS[_source], SOURCE_TIPS[_source], _source != SOURCE_NONE)


func _shortage_line(kind: int, members: PackedInt32Array) -> String:
	"""A kind the site takes but the stores cannot pay for: what is missing (bridge_project.gd), and the source button set
	to what supplies it. "" when it can be built or the site does not take it."""
	var card: CardScript = _water.build_card(kind, members)
	if card.is_ok() or _water.build_refused_by != WaterplayScript.BUILD_MATERIAL:
		return ""
	if _source == SOURCE_NONE:
		_source = SOURCE_SAW if kind == SwimRules.KIND_PLANK else SOURCE_WOODS
	return ProjectScript.shortage_line(kind, card)


func _bridge_benefit(kind: int, members: PackedInt32Array) -> PackedStringArray:
	"""The benefit of a `kind` bridge at the site (see THE WATER PANEL'S SITE), its users and its cost."""
	var scratch: BridgesScript = _scratch_bridge(_water.survey_site(kind))
	if scratch == null:
		return PackedStringArray()
	var who: int = _subject_of(members)
	var a: Vector2 = scratch.approach(0, false)
	var b: Vector2 = scratch.approach(0, true)
	_set_bridge_trips(a, b)
	bridge_estimate.set_walker(who, brain_of(who).radius, true)
	bridge_estimate.propose_bridge(a, b, scratch.walk_length_m(0))
	bridge_estimate.start(hash([a, b, kind, who, _trip_ids, _bridge_state()]))
	var lines := TextScript.benefit_lines(bridge_estimate, pace_of(who), "carrying, for %s" % name_of(who))
	lines.insert(lines.size() - 1, TextScript.BRIDGE_WHO + _members_note(members))
	lines.insert(lines.size() - 1, _cost_line(kind, members))
	return lines


func _scratch_bridge(survey: BridgesScript.Survey) -> BridgesScript:
	"""A bridge table of its own with `survey`'s bridge in row 0 -- the approaches and walk a planned row gives
	(bridges.gd) -- made again only for a new survey; null when it cannot be planned."""
	var key: int = hash([survey.ok, survey.kind, survey.shore_a, survey.shore_b, survey.deck_u])
	if key == _scratch_key and _scratch != null:
		return _scratch
	_scratch_key = key
	_scratch = BridgesScript.new()
	_scratch.configure(_water.map(), [] as Array[Vector3], _water.links.area)
	if not _scratch.plan_into(survey, "proposal", _found):
		_scratch = null
	return _scratch


func _set_bridge_trips(a: Vector2, b: Vector2) -> void:
	"""The work trips that cross the water nearest the bridge (work_trips.gd RELEVANT); none: straight across it."""
	bridge_estimate.clear_trips()
	trips.water_trips_into((a + b) * 0.5, _crosses, PREVIEW_TRIPS, _trip_ids)
	for t: int in _trip_ids:
		bridge_estimate.add_trip(trips.trip_from(t), trips.trip_to(t), trips.trip_name(t))
	if _trip_ids.is_empty():
		var out: Vector2 = (b - a).normalized() * 3.0
		bridge_estimate.add_trip(a - out, b + out, "straight across here")


func _cost_line(kind: int, members: PackedInt32Array) -> String:
	"""The bridge's cost from its Build button's card: each material have / need, and the work."""
	var card: CardScript = _water.build_card(kind, members)
	var parts := PackedStringArray()
	for k: int in card.cost_names.size():
		parts.append(card.cost_line(k))
	if card.work_usec >= 0:
		parts.append("work %s" % CardScript.hours_text(card.work_usec))
	return "Cost (%s): %s" % [SwimRules.KIND_NAMES[kind], " · ".join(parts)]


func _members_note(members: PackedInt32Array) -> String:
	"""For a group, each member by name (a bridge takes every one of them: MOVE-REQ-012 is still said per member)."""
	if members.size() < 2:
		return ""
	var names := PackedStringArray()
	for who: int in members:
		names.append(name_of(who))
	return " (each of %s can use it)" % ", ".join(names)


func _fill_standing(row: int, members: PackedInt32Array) -> void:
	"""A planned bridge's materials and work, or an open one's route and condition (see THE WATER PANEL'S SITE)."""
	var bridges: BridgesScript = _water.bridges
	if bridges.is_open(row):
		_source = SOURCE_NONE
		_water.panel.show_routes(_open_lines(row, members), "")
	else:
		_source = SOURCE_BRIDGE_TASK
		_source_row = row
		_water.panel.show_routes(ProjectScript.planned_lines(bridges, _water.crew, row), "")
	_water.panel.set_source(SOURCE_CAPTIONS[_source], SOURCE_TIPS[_source], _source != SOURCE_NONE)


func _bridge_state() -> int:
	"""What of the bridges changes a route (see THE BUDGET): one planned (`layout`), one opened -- not the work."""
	return _water.bridges.layout * 64 + _water.bridges.phase.count(BridgesScript.PHASE_OPEN)


func _open_lines(row: int, members: PackedInt32Array) -> String:
	"""An open bridge: its route and condition -- who may cross, the walk across, and a work trip's route now."""
	var bridges: BridgesScript = _water.bridges
	var who: int = _subject_of(members)
	var walk: String = TextScript.time_text(bridges.walk_length_m(row), pace_of(who))
	var lines := PackedStringArray([ProjectScript.ROUTE % [walk, _members_note(members)], ProjectScript.CONDITION])
	_set_bridge_trips(bridges.approach(row, false), bridges.approach(row, true))
	bridge_estimate.set_walker(who, brain_of(who).radius, true)
	bridge_estimate.propose_nothing()
	bridge_estimate.start(hash([row, who, _trip_ids, _bridge_state(), -1]))
	if bridge_estimate.trip_count > 0:
		var route: String = TextScript.CALCULATING
		if bridge_estimate.trip_known(0):
			route = kinds.runs_text(_cast.space().tunnels, bridge_estimate.trip_from[0], bridge_estimate.before_paths[0],
				bridge_estimate.before_legs[0])
		lines.append("Route now, %s: %s" % [bridge_estimate.trip_names[0], route])
	return "\n".join(lines)


func _on_water_action(action_name: StringName) -> void:
	"""The site's source button (water_panel.gd ACTION_SOURCE): to what supplies the missing material, or the bridge's
	task -- it orders nothing."""
	if action_name != PanelScript.ACTION_SOURCE:
		return
	match _source:
		SOURCE_SAW:
			var row: int = saw_task_row()
			if row >= 0:
				open_work_task(WorkIds.SOURCE_WOODS, row)
			elif _show_woods.is_valid():
				_show_woods.call()
		SOURCE_WOODS:
			if _show_woods.is_valid():
				_show_woods.call()
		SOURCE_BRIDGE_TASK:
			open_work_task(WorkIds.SOURCE_BRIDGES, _source_row)


func saw_task_row() -> int:
	"""The woods' board row holding a saw job (-1: none queued)."""
	if _jobs == null:
		return -1
	for row: int in ForestJobs.MAX_JOBS:
		if _jobs.is_live(row) and _jobs.kind[row] == ForestJobs.KIND_SAW:
			return row
	return -1


func open_work_task(task_source: int, row: int) -> bool:
	"""Open the Work screen's task list with that task's row focused (its Go to button); whether the row was found and
	focused (the screen opens either way, unless there is none)."""
	if _work == null:
		return false
	var screen: WorkScreenScript = _work.screen
	screen.open()
	screen.show_view(WorkScreenScript.VIEW_TASKS)
	for task_row: TaskRowScript in screen.task_rows_shown():
		if task_row.task_source == task_source and task_row.task_row == row and task_row.is_inside_tree():
			task_row.button_of(&"go").grab_focus()
			return true
	return false


func open_work_projects() -> void:
	"""The tunnel project's Work ▸: the Work screen's Projects view."""
	if _work == null:
		return
	_work.screen.open()
	_work.screen.show_view(WorkScreenScript.VIEW_PROJECTS)


func source_kind() -> int:
	"""What the site's source button leads to now (SOURCE_*; checks)."""
	return _source


# --- the Tunnels panel's project --------------------------------------------------------------------------

func project_text() -> String:
	"""The piece being laid, else the first dig in the job list (see THE TUNNEL PANEL'S PROJECT); "" for none, or while
	the Tunnels panel is not shown (nothing is read for a hidden panel)."""
	if not _tool.ext.panel.is_shown():
		return ""
	if _tool.planning and _tool.plan.count >= 2:
		return _laid_text()
	var list := PackedInt32Array()
	_tool.network.job_list_into(list)
	if list.is_empty():
		dig_estimate.stop()
		return ""
	return _dig_text(list[0], list.size())


func _laid_text() -> String:
	"""The piece as laid: its benefit if dug as it is, once the whole-piece check passes (else what the panel says)."""
	var key: int = hash([_tool.plan.points_u.slice(0, 2 * _tool.plan.count), _tool.plan.level, _tool.plan.link_kind,
		_tool.network.revision])
	if key != _piece_key:
		_piece_key = key
		_piece_ok = _tool.laid_piece_reason() == Rules.REFUSE_NONE
		_laid = _tool.laid_spec() if _piece_ok else null
	if not _piece_ok:
		return ""
	dig_estimate.propose_piece(_laid)
	var a: Vector2 = _tool.plan.point_m(0)
	var b: Vector2 = _tool.plan.point_m(_tool.plan.count - 1)
	_set_dig_trips(a, b, key, _tool.plan.starts_at_mouth() and _tool.plan.ends_at_mouth())
	var lines := PackedStringArray(["If this piece is dug as laid:"])
	lines.append_array(_dig_benefit())
	lines.append(_bore_words(Rules.BORE_STANDARD))
	return "\n".join(lines)


func _dig_text(p: int, digs: int) -> String:
	"""A dig under way: its work left, stages and heading, the next payoff's benefit, who fits it, its materials."""
	var graph: GraphScript = _tool.network
	stages.read(graph, p)
	var ticks := PackedInt32Array([0, 0])
	graph.piece_ticks_into(p, ticks)
	var lines := PackedStringArray([
		"Project: %s — %d%% dug%s" % [_tool.ext.piece_name(p, graph.first_of_piece(p)), graph.piece_percent(p),
			"" if digs < 2 else " (1 of %d digs)" % digs],
		"Work left: %s at one digger's pace (a crew is quicker)" % CardScript.hours_text((ticks[1] - ticks[0]) * TICK_USEC)])
	for k: int in stages.count():
		lines.append(stages.stage_line(k))
	if not stages.heading_line().is_empty():
		lines.append(stages.heading_line())
	lines.append_array(_payoff_lines(graph, p))
	lines.append(_bore_words(graph.bore[stages.chain[0]]))
	lines.append(DIG_MATERIALS)
	return "\n".join(lines)


func _payoff_lines(graph: GraphScript, p: int) -> PackedStringArray:
	"""The next stage (`stages`, read): what it opens, how far the dig to it is, and its benefit -- the piece open to it,
	for one end to the other when both are on the surface, and the work trips near its ends."""
	var next: int = stages.next_milestone()
	if next < 0:
		dig_estimate.stop()
		return PackedStringArray()
	var lines := PackedStringArray(["Next payoff: %s — %d%% of the way there" % [StagesScript.GIVES[stages.kinds[next]],
		stages.percent_to_next(graph)]])
	var start: int = graph.node_a[stages.chain[0]]
	var end: int = stages.nodes[next]
	dig_estimate.propose_open(p, stages.upto[next])
	_set_dig_trips(graph.node_m(start), graph.node_m(end), hash([p, next, graph.revision]),
		graph.node_mouth[start] >= 0 and graph.node_mouth[end] >= 0)
	lines.append_array(_dig_benefit())
	return lines


func _set_dig_trips(a: Vector2, b: Vector2, key: int, ends_on_surface: bool) -> void:
	"""Estimate the dig for one end to the other -- only when both ends are mouths: an end below has no surface place to
	walk to -- and the work trips that might use it (work_trips.gd RELEVANT)."""
	var who: int = _dig_walker()
	dig_estimate.set_walker(who, brain_of(who).radius, _fits(who, true))
	dig_estimate.clear_trips()
	if ends_on_surface:
		dig_estimate.add_trip(a, b, "one end to the other")
	trips.near_trips_into(a, b, PREVIEW_TRIPS, _trip_ids)
	for t: int in _trip_ids:
		dig_estimate.add_trip(trips.trip_from(t), trips.trip_to(t), trips.trip_name(t))
	dig_estimate.start(hash([key, who, _trip_ids, _bridge_state()]))


func _dig_benefit() -> PackedStringArray:
	"""The dig estimate's lines, for its walker (carrying when it fits a bore with a load)."""
	var who: int = dig_estimate.walker
	var how: String = "carrying" if dig_estimate.loaded else "unloaded"
	return TextScript.benefit_lines(dig_estimate, pace_of(who, dig_estimate.loaded), "%s, for %s" % [how, name_of(who)])


func _dig_walker() -> int:
	"""Whose trips a dig is estimated for: the first selected who fits a bore, else the first resident who fits one
	carrying, else the first who fits at all."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	for who: int in members:
		if _fits(who, false):
			return who
	for loaded: bool in [true, false]:
		for who: int in _cast.actor_count():
			if _fits(who, loaded):
				return who
	return 0


func _fits(who: int, loaded: bool) -> bool:
	"""Whether resident `who` fits a standard bore (carrying, when `loaded`)."""
	return _tool.network.fit_class_refusal(who, Rules.BORE_STANDARD, loaded) == Rules.FIT_OK


func _bore_words(bore_class: int) -> String:
	"""Who a bore takes: by body, how many here, and each selected member's own verdict."""
	var counts: Vector2i = TextScript.fit_counts(_tool.network, _cast.actor_count(), bore_class)
	var line: String = TextScript.bore_who(bore_class, counts.x, counts.y, _cast.actor_count())
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	if members.size() >= 2:
		line += "\n" + "\n".join(TextScript.member_lines(_tool.network, members, bore_class, true, name_of))
	return line


# --- the Routes layer -------------------------------------------------------------------------------------

func refresh_lens() -> void:
	"""The layer's subject words, and with nobody selected the public ways' estimates asked for (ECO-039)."""
	var members: PackedInt32Array = overlay.members
	if members.is_empty():
		_request_public()
		subject.set_words(SubjectScript.NOBODY, _public_notes())
		return
	var line: String = SubjectScript.ONE % name_of(members[0]) if members.size() == 1 else SubjectScript.GROUP % members.size()
	var notes := PackedStringArray()
	for k: int in mini(members.size(), NOTES_MEMBERS):
		notes.append(member_note(members[k]))
	if members.size() > NOTES_MEMBERS:
		notes.append("and %d more — each its own route on the map" % (members.size() - NOTES_MEMBERS))
	subject.set_words(line, "\n".join(notes))


func member_note(who: int) -> String:
	"""One member's route in words: its hold-up, else its stretches ("Wenna Tallowby: surface 12 m · underground, level 1
	8 m"), else that it is not going anywhere."""
	var brain: BrainScript = brain_of(who)
	var why: int = ReasonsScript.diagnose(brain, _cast.space().tunnels, _where)
	if why != ReasonsScript.NONE:
		return "%s: %s" % [name_of(who), ReasonsScript.WORDS[why]]
	if kinds.boat_leg_into(who, _boat_leg):
		var metres: float = 0.0
		for p: int in range(1, _boat_leg.size()):
			metres += _boat_leg[p - 1].distance_to(_boat_leg[p])
		return "%s: %s %d m" % [name_of(who), KindsScript.KIND_WORDS[kinds.boat_kind_of(who)], maxi(roundi(metres), 1)]
	if brain.trip_outcome != BrainScript.TRIP_UNDERWAY or brain.path_index >= brain.path.size():
		return "%s: not on a trip" % name_of(who)
	return "%s: %s" % [name_of(who), kinds.runs_text(_cast.space().tunnels, brain.position, brain.path,
		brain.path_tunnel, brain.path_index)]


func _request_public() -> void:
	"""The public ways from the square to each work district for the public walker, and the same trips for the
	shortcut walker (the narrowest body, also carrying, so neither swims) -- each kept until something changes."""
	var square: Vector2 = trips.points[TripsScript.SQUARE]
	var walker: int = public_walker()
	var quick: int = shortcut_walker()
	for estimate: EstimatorScript in [public_estimate, shortcut_estimate]:
		estimate.clear_trips()
		for place: int in TripsScript.DISTRICTS:
			estimate.add_trip(square, trips.points[place], TripsScript.NAMES[place])
		estimate.propose_nothing()
	public_estimate.set_walker(walker, brain_of(walker).radius, true)
	shortcut_estimate.set_walker(quick, brain_of(quick).radius, true)
	public_estimate.start(hash([walker, trips.points, _bridge_state()]))
	shortcut_estimate.start(hash([quick, trips.points, _bridge_state(), 1]))


func public_walker() -> int:
	"""The public walker: whoever fits the fewest bores carrying (the widest body), so a public way takes everyone; a
	carrier never swims (water_crossings.gd LOADS CANNOT SWIM)."""
	var best: int = 0
	for who: int in _cast.actor_count():
		var cls: int = _cast.space().tunnels.walker_class(who, true)
		var best_cls: int = _cast.space().tunnels.walker_class(best, true)
		if cls > best_cls or (cls == best_cls and brain_of(who).radius > brain_of(best).radius):
			best = who
	return best


func shortcut_walker() -> int:
	"""Whose tunnel shortcuts are shown: the narrowest body (it fits the most bores, carrying too)."""
	var best: int = 0
	for who: int in _cast.actor_count():
		if brain_of(who).radius < brain_of(best).radius:
			best = who
	return best


func _public_notes() -> String:
	"""The layer's notes with nobody selected: the promise, and how far the estimate has got."""
	var state: String = TextScript.CALCULATING if public_estimate.is_calculating() or shortcut_estimate.is_calculating() \
		else "times are estimates for %s carrying" % name_of(public_estimate.walker)
	return "%s\n%s" % [SubjectScript.PUBLIC_NOTE, state]


func public_label(k: int) -> String:
	"""Public way `k`'s label on the map: its walking time carrying, and the tunnel shortcut where there is one."""
	var line: String = "To %s: %s carrying" % [public_estimate.trip_names[k],
		TextScript.short_time_text(public_estimate.before_m[k], pace_of(public_estimate.walker))]
	if public_shortcut(k):
		line += "\nNarrow bodies' shortcut below (optional): %s carrying" % TextScript.short_time_text(
			shortcut_estimate.before_m[k], pace_of(shortcut_estimate.walker))
	return line


func public_shortcut(k: int) -> bool:
	"""Whether district `k` has a tunnel SHORTCUT beside its public way: the narrowest body's route there goes below where
	the public way does not (ECO-039: a body-compatible way, never the only one)."""
	if k >= shortcut_estimate.trip_count or shortcut_estimate.before_known[k] == 0 or public_estimate.before_known[k] == 0:
		return false
	var below := KindsScript.KIND_UNDERGROUND
	return _has(shortcut_estimate, k, below) and not _has(public_estimate, k, below)


func _has(estimate: EstimatorScript, k: int, kind: int) -> bool:
	"""Whether trip `k`'s route (before) has a stretch of `kind`."""
	return kinds.has_kind(estimate.trip_from[k], estimate.before_paths[k], estimate.before_legs[k], kind)


# --- residents ---------------------------------------------------------------------------------------------

func _subject_of(members: PackedInt32Array) -> int:
	"""Whose trips a bridge is estimated for: the first selected, else the public walker."""
	return members[0] if not members.is_empty() else public_walker()


func pace_of(who: int, carrying: bool = true) -> float:
	"""The pace a trip is timed at for `who` (route_estimator.gd `pace_m_s`)."""
	return EstimatorScript.pace_m_s(brain_of(who).walk_speed, carrying)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name
