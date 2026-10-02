extends RefCounted
## The water's words: the Water panel's lines, the party panel's meters, and every order's answer.
## Decision 0196 (live demo). Presentation only: it reads the water's parts and says what they hold;
## nothing here decides anything. Every refusal names its failed condition (MOVE-REQ-005, MOVE-REQ-018:
## text as well as colour).

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

## The water's own latest lines shown in its panel.
const LOG_LINES: int = 3
## Why a hurt resident may not go into the water (HAZ-001, decision 1045).
const HURT_WORDS: String = "it needs health 70 and no untreated injury"
## How each kind's cost line in `site_text` starts: the Water panel puts each beside its Build button (decision 0391).
const PLANK_LINE: String = "Plank footbridge: "
const LOG_LINE: String = "Log bridge: "

var _cast: DemoCastScript = null
var _state: StateScript = null
var _motion: MotionScript = null
var _bridges: BridgesScript = null
var _crew: CrewScript = null
var _rescue: RescueScript = null
var _services: ServicesScript = null
var _map: WaterMapScript = null
var _last_answer: String = ""


func configure(cast: DemoCastScript, state: StateScript, motion: MotionScript, bridges: BridgesScript,
		crew: CrewScript, rescue: RescueScript, services: ServicesScript, map: WaterMapScript) -> void:
	"""Speak for these parts of the water."""
	_cast = cast
	_state = state
	_motion = motion
	_bridges = bridges
	_crew = crew
	_rescue = rescue
	_services = services
	_map = map


func remember(said: String) -> void:
	"""Keep an order's answer for the panel's news."""
	_last_answer = said


func name_of(who: int) -> String:
	"""A resident's name."""
	return (_cast.actor(who) as DemoActorScript).display_name


func _brain(who: int) -> BrainScript:
	"""A resident's brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _species(who: int) -> String:
	"""A resident's species."""
	return (_cast.actor(who) as DemoActorScript).species


# --- answers -------------------------------------------------------------------------------------

func refusal_words(who: int, why: StringName, at: Vector2 = Vector2.ZERO) -> String:
	"""Why `who` was refused a swim or a dive, in words."""
	var name: String = name_of(who)
	match why:
		Rules.REFUSE_CANNOT_SWIM:
			return "%s doesn't swim (it wades only)" % name
		Rules.REFUSE_CANNOT_DIVE:
			return "%s doesn't dive" % name
		Rules.REFUSE_TIRED:
			@warning_ignore("integer_division") return "%s is too tired to swim (stamina %d%%, needs %d%%)" % [name, _state.rest_percent(who), Rules.REST_ENTRY_MIN / 100]
		Rules.REFUSE_NO_CONSENT:
			return "%s has swim shortcuts off" % name
		Rules.REFUSE_TOO_SHALLOW:
			return "too shallow for %s to dive here (%s)" % [name, depth_words(who, at)]
		Rules.REFUSE_ICE:
			return "%s can't swim there: ice covers the pond" % name
		Rules.REFUSE_HURT:
			return "%s isn't well enough to go in the water (%s)" % [name, HURT_WORDS]
	return "%s can't go: %s" % [name, String(why).to_lower().replace("_", " ")]


func bank_refusal_line(who: int, why: StringName) -> String:
	"""A swimmer refused at the bank on its way across (water_crossings.gd THE BANK RECHECK), in words."""
	return "%s won't swim across: %s — going round by land" % [name_of(who), reason_words(who, why)]


func reason_words(who: int, why: StringName) -> String:
	"""Why `who` may not go into the water now, in words, without its name."""
	match why:
		Rules.REFUSE_NO_CONSENT:
			return "swim shortcuts are off"
		Rules.REFUSE_TIRED:
			@warning_ignore("integer_division") return "too tired (stamina %d%%, needs %d%%)" % [_state.rest_percent(who), Rules.REST_ENTRY_MIN / 100]
		Rules.REFUSE_LOADED:
			return "carrying a load"
		Rules.REFUSE_FLOW:
			return "the current is too strong to swim across"
		Rules.REFUSE_ICE:
			return "ice covers the pond"
		Rules.REFUSE_CANNOT_SWIM:
			return "it doesn't swim"
		Rules.REFUSE_HURT:
			return "not well enough (%s)" % HURT_WORDS
	return String(why).to_lower().replace("_", " ")


func depth_words(who: int, at: Vector2) -> String:
	"""The depth at `at` against the body's height (a dive needs water deeper than the body is tall)."""
	var depth: int = _map.depth_at(MotionScript.u_of(at))
	return "%.2f m deep; a dive needs over %.2f m" % [WaterRules.to_m(depth), WaterRules.to_m(WaterRules.dive_min_u(_state.height_u[who]))]


static func sent_line(sent: int, doing: String, refused: PackedStringArray) -> String:
	"""An order's answer: how many went, and each refusal ("Can't: ..." when nobody went)."""
	if sent == 0:
		return "Can't: %s" % "; ".join(refused) if not refused.is_empty() else "Can't: nobody selected"
	var head: String = "%d %s" % [sent, doing]
	return head if refused.is_empty() else "%s — %s" % [head, "; ".join(refused)]


func cold_line(cold: bool) -> String:
	"""The feed's line when the water turns cold or mild."""
	if cold:
		return "The water is cold today (%s): swimmers tire twice as fast" % degrees()
	return "The water is milder today (%s)" % degrees()


func degrees() -> String:
	"""The day's temperature (what the water follows), e.g. "6.5 °C"."""
	var tenths: int = _services.weather.day_temperature_tenths()
	@warning_ignore("integer_division") return "%s%d.%d °C" % ["-" if tenths < 0 else "", absi(tenths) / 10, absi(tenths) % 10]


static func cost_words(survey: BridgesScript.Survey) -> String:
	"""What a surveyed bridge costs, e.g. "4.7 U planks and 1.0 U wood for 1 pier"."""
	if survey.kind == Rules.KIND_LOG:
		return "one %s log" % Rules.units_text(Rules.LOG_WOOD_MILLI)
	var piers: String = "" if survey.piers == 0 else " and %s wood for %d pier%s" % [Rules.units_text(survey.wood_milli),
		survey.piers, "" if survey.piers == 1 else "s"]
	return "%s planks%s" % [Rules.units_text(survey.planks_milli), piers]


static func short_line(survey: BridgesScript.Survey, stores: StoresScript) -> String:
	"""The stores' refusal, with the way to put it right."""
	if survey.kind == Rules.KIND_LOG:
		return "Can't build a log bridge: it needs a %s log -- fell a tree (Woods), or bring wood to the log stack (it holds %s)" % [
			Rules.units_text(Rules.LOG_WOOD_MILLI), Rules.units_text(stores.wood_milli_u)]
	return "Can't build a plank footbridge: it needs %s; the stores hold %s planks and %s wood -- saw planks at the sawhorse (Woods)" % [
		cost_words(survey), Rules.units_text(stores.plank_milli_u), Rules.units_text(stores.wood_milli_u)]


static func site_answer(plank: BridgesScript.Survey, log_survey: BridgesScript.Survey) -> String:
	"""The answer when a span of two banks is chosen: can it take a bridge."""
	if plank.ok or log_survey.ok:
		return "Span chosen: %.1f m of water — build it from the Water panel" % WaterRules.to_m((plank if plank.ok else log_survey).span_u)
	return "Can't bridge there: %s" % plank.reason


# --- the panel -----------------------------------------------------------------------------------

func conditions_line() -> String:
	"""The water today: the stream's flow (a flood's too), and whether it is cold."""
	var flow_mm: int = Rules.flow_mm_s(WaterLayout.STREAM_FLOW_U_S, _motion.flood_permille)
	var line: String = "Stream flowing %.2f m/s%s" % [float(flow_mm) / 1000.0, " — in flood" if _motion.flood_permille > 0 else ""]
	line += " · %s water (%s)" % ["cold" if _motion.cold else "mild", degrees()]
	return line + (": swimmers tire twice as fast" if _motion.cold else "")


func alert_line() -> String:
	"""Every resident in difficulty, one incident apiece (`incident_words`); "" when nobody is."""
	var parts := PackedStringArray()
	for who: int in _rescue.victims:
		parts.append(incident_words(who))
	return "" if parts.is_empty() else "In difficulty: %s" % "; ".join(parts)


func incident_words(who: int) -> String:
	"""One victim's incident, updated in place: where it is and its breath, who is answering it and at
	what, the landing it is being brought to, and why nothing better went -- or, with nobody, when the
	water will carry it ashore (rescue.gd's safety net). E.g. "Otter, underwater, breath 37% — Otter 2:
	diving to fetch them"."""
	var task: Tasks.VictimTask = _rescue.victim_task(who)
	if task == null:
		return "%s — in difficulty" % name_of(who)
	var where: String = "being brought ashore" if task.towed else ("underwater" if task.down_m > 0.0 else "at the surface")
	@warning_ignore("integer_division") var victim: String = "%s, %s, breath %d%%" % [name_of(who), where, _state.air[who] * 100 / Rules.AIR_FULL]
	if not task.engaged:
		var left_s: int = maxi(ceili(RescueScript.WASH_ASHORE_S - task.waited_s), 0)
		return "%s — no rescuer free yet (the water brings it ashore in %d s)" % [victim, left_s]
	var landing: String = _rescue.landing_words_of(_brain(task.responder))
	var why: String = "" if task.why.is_empty() else " (%s)" % task.why
	return "%s — %s: %s%s%s" % [victim, name_of(task.responder), _brain(task.responder).task_label(), landing, why]


func swimmers_title() -> String:
	"""The swimmers' heading, with how many are in the water and the rescues so far (a tally, not an
	alert: the alert line is for a resident in difficulty now)."""
	var n: int = 0
	for who: int in _state.count:
		n += 1 if _brain(who).in_water else 0
	var tally: String = "" if _rescue.rescued == 0 else " · %d rescue%s so far" % [_rescue.rescued, "" if _rescue.rescued == 1 else "s"]
	return "Swimmers — %d in the water%s" % [n, tally]


func swimmers_text() -> String:
	"""One line per resident: what it can do, what the water is doing to it, breath and stamina."""
	var lines := PackedStringArray()
	for who: int in _state.count:
		@warning_ignore("integer_division") lines.append("%s (%s): %s · breath %d%% · stamina %d%%" % [name_of(who), ability_word(who), mode_words(who),
			_state.air[who] * 100 / Rules.AIR_FULL, _state.rest_percent(who)])
	return "\n".join(lines)


func ability_word(who: int) -> String:
	"""What `who` can do in the water, in a word or two: dives, swims or wades."""
	if _state.can_dive(who):
		return "dives"
	return "swims" if _state.can_swim(who) else "wades only"


func mode_words(who: int) -> String:
	"""What the water is doing to `who` -- its task's words when it has one in the water."""
	var brain: BrainScript = _brain(who)
	if brain.in_water and brain.order == BrainScript.ORDER_TASK:
		return brain.task_label()
	return StateScript.MODE_WORDS[_state.mode[who]]


func any_diver(members: PackedInt32Array) -> bool:
	"""Whether a selected resident dives."""
	for who: int in members:
		if _state.can_dive(who):
			return true
	return false


func any_in_water(members: PackedInt32Array) -> bool:
	"""Whether a selected resident is in the water."""
	for who: int in members:
		if _brain(who).in_water:
			return true
	return false


func site_title(custom: bool, candidate: int) -> String:
	"""The chosen site's heading."""
	if custom:
		return "Bridge site: a span of two banks"
	return "Bridge site %d of %d: %s" % [candidate + 1, _bridges.candidate_count(),
		"the neck, the stream's narrowest" if candidate == 0 else "upstream of the neck"]


static func site_text(plank: BridgesScript.Survey, log_survey: BridgesScript.Survey, trunk_ready: bool) -> String:
	"""The chosen site: span, deck and piers, and each kind's cost or reason."""
	var shown: BridgesScript.Survey = plank if plank.span_u > 0 else log_survey
	var lines := PackedStringArray()
	if shown.span_u > 0:
		lines.append("%.1f m of water · %.1f m of deck" % [WaterRules.to_m(shown.span_u), WaterRules.to_m(shown.deck_u)])
	var piers: String = ", no piers" if plank.piers == 0 else ""
	lines.append(PLANK_LINE + (cost_words(plank) + piers if plank.ok else "can't — " + plank.reason))
	var source: String = " (a felled trunk lies ready)" if trunk_ready else " (from the log stack)"
	lines.append(LOG_LINE + (cost_words(log_survey) + source if log_survey.ok else "can't — " + log_survey.reason))
	return "\n".join(lines)


func standing_text(row: int) -> String:
	"""A bridge standing at the chosen site: what it is, and how far built."""
	var what: String = "%s, a %s: " % [first_up(_bridges.names[row]), Rules.KIND_NAMES[_bridges.kind[row]]]
	if _bridges.is_open(row):
		return what + "open — anyone may cross, carrying or not"
	return what + "%d%% built — %s" % [_bridges.percent(row), _crew.job_text(row)]


func bridges_text() -> String:
	"""Every bridge planned or open: its stage and builder."""
	var lines := PackedStringArray()
	for row: int in BridgesScript.MAX_BRIDGES:
		if _bridges.is_open(row):
			lines.append("%s (%s): open" % [first_up(_bridges.names[row]), Rules.KIND_NAMES[_bridges.kind[row]]])
		elif _bridges.is_planned(row):
			lines.append("%s (%s): %d%% — %s" % [first_up(_bridges.names[row]), Rules.KIND_NAMES[_bridges.kind[row]],
				_bridges.percent(row), _crew.job_text(row)])
	return "No bridges yet." if lines.is_empty() else "\n".join(lines)


func log_text() -> String:
	"""The last answer and the water's latest news."""
	var out := PackedStringArray()
	_services.notices.latest_of_into(NoticesScript.SOURCE_WATER, LOG_LINES, out)
	if not _last_answer.is_empty():
		out.insert(0, _last_answer)
	return "\n".join(out)


func skill_line(who: int, alone: bool) -> String:
	"""The party panel's water words: bridge building, and swimming with breath and stamina."""
	var swim: String = swim_line(who, alone)
	return bridge_line(who, alone) + ("" if swim.is_empty() else ("\n" if alone else " · ") + swim)


func bridge_line(who: int, alone: bool) -> String:
	"""Bridge building: "Bridging 6 · XP .../..." alone, "bridge 6" in a list."""
	return _crew.line_of(who) if alone else _crew.short_of(who)


func swim_line(who: int, alone: bool) -> String:
	"""Swimming with breath and stamina alone; in a list the breath only while in the water or short of air ("")."""
	if alone:
		return "%s\n%s" % [first_up(Rules.swim_words(_species(who))), first_up(_state.meter_text(who))]
	if _brain(who).in_water or _state.air[who] < Rules.AIR_FULL:
		@warning_ignore("integer_division") return "breath %d%%" % (_state.air[who] * 100 / Rules.AIR_FULL)
	return ""


static func first_up(words: String) -> String:
	"""`words` with its first letter a capital (nothing else changed)."""
	return words.left(1).to_upper() + words.substr(1)
