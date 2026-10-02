extends Node3D
## THE FORAGING TRIPS in the village (decision 0681; feature #22): the real forage store driven on the demo calendar
## (forage_driver.gd), the trips over the cast, the farm's pantry, the calendar and the weather (forage_trips.gd), the
## Woods panel's Foraging section, the work board (`_build_work` adds the seats), the party panel's words and the
## foragers' baskets. Presentation over integer rules; nothing writes into the simulation.
##
## PLAYER VERBS (the Woods panel's Foraging section; each order's tooltip is its ACTION CARD from the order's own
## decision, decision 0332):
##   Gather ▸        nuts, mushrooms, herbs or berries (a kind out of season is still shown, its order refused with when it comes)
##   Party ▸         one to three foragers
##   Authorise trip  its seats on the work board (the Woods crew's work), to the selected residents first
##   Cancel trip     the earliest trip out called off: its seats not yet carrying end; a haul in hand comes home
##
## TIME. The trips run on this frame's demo time (paused, nothing moves; at 4x four times as fast); the section follows
## on real time, only while the Woods panel is shown.

const DriverScript := preload("res://demo/forage/forage_driver.gd")
const TripsScript := preload("res://demo/forage/forage_trips.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const ViewScript := preload("res://demo/forage/forage_view.gd")
const SectionScript := preload("res://demo/forage/forage_section.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const PanelScript := preload("res://demo/forestry/forest_panel.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

const PANEL_REFRESH_S: float = 0.25

var trips: TripsScript = TripsScript.new()
var view: ViewScript = null
var section: SectionScript = null
var services: ServicesScript = null
## The section's choices: the kind (index into Rules.KINDS) and the party.
var choice_kind: int = 0
var choice_party: int = Rules.PARTY_DEFAULT
## What the last frame's trips and drawing cost on the main thread, microseconds (the performance check).
var last_usec: int = 0

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _panel: PanelScript = null
var _card: CardScript = CardScript.new()
var _refresh_in: float = 0.0


func configure(cast: DemoCastScript, command: DemoCommandScript, shared: ServicesScript, pantry: PantryScript,
		panel: PanelScript) -> void:
	"""Wire the trips into this village (`command` and `panel` may be null in a check): the real forage store from the
	compiled catalogue's five ids, at the calendar's tick."""
	name = "DemoForage"
	_cast = cast
	_command = command
	_panel = panel
	services = shared
	var ids: DriverScript.IdsResult = DriverScript.resolve_item_ids()
	assert(ids.ok, "the five forage items bind (%s)" % ids.error)
	var driver: DriverScript = DriverScript.create(ids.ids, maxi(shared.calendar.tick, 0)) as DriverScript
	trips.configure(cast, driver, pantry, shared.calendar, shared.weather)
	trips.say = _say
	view = ViewScript.new()
	add_child(view)
	view.configure(trips, shared.props, cast.actor_count())
	if command != null:
		command.add_task_text(task_text)
		command.add_skill_text(skill_text)
	if panel != null:
		section = SectionScript.new()
		section.build(panel.content_width())
		panel.add_section(section)
		section.action.connect(on_action)


func task_text(who: int) -> String:
	"""What `who` does for a foraging trip, in words ("" when nothing)."""
	var j: int = trips.job_of_worker(who)
	return trips.doing_text(j, trips.j_serial[j]) if j >= 0 else ""


func skill_text(who: int, _alone: bool) -> String:
	"""The party panel's foraging line."""
	return trips.skills.line_of(who)


func status_text() -> String:
	"""The Routes layer's foraging line."""
	return trips.status_line()


# --- per frame ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the trips on this frame's demo time; the view follows; the section on real time, while shown."""
	if view == null:
		return
	var started: int = Time.get_ticks_usec()
	trips.update(_cast.clock.frame_usec if _cast != null else 0)
	view.refresh()
	last_usec = Time.get_ticks_usec() - started
	_refresh_in -= delta
	if _refresh_in <= 0.0 and section != null and _panel != null and _panel.is_shown():
		_refresh_in = PANEL_REFRESH_S
		refresh_section()


func _say(text: String, warning: bool) -> void:
	"""Post a line to the one notice feed, from the woods."""
	services.notices.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, text)


# --- the orders --------------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Foraging section button."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	match action_name:
		SectionScript.ACTION_KIND:
			choice_kind = posmod(choice_kind + 1, Rules.KIND_COUNT)
		SectionScript.ACTION_PARTY:
			choice_party = Rules.PARTY_MIN + posmod(choice_party - Rules.PARTY_MIN + 1, Rules.PARTY_MAX - Rules.PARTY_MIN + 1)
		SectionScript.ACTION_AUTHORISE:
			_answer(_ordered(trips.order_trip(choice_kind, choice_party, members),
				"A foraging trip for %s: on the work board" % Rules.KIND_WORDS[choice_kind]))
		SectionScript.ACTION_CANCEL:
			_answer(_ordered(trips.cancel_trip(trips.first_trip()), "The foraging trip is called off"))
		_:
			return
	_refresh_in = 0.0


func _ordered(why: String, done: String) -> String:
	"""An order's answer: done, or why not."""
	return done if why.is_empty() else "Can't: %s" % why


func _answer(said: String) -> void:
	"""An order's answer beside the selection (the party panel's notice)."""
	if _command != null and _command.panel() != null:
		_command.say(said)


# --- the section --------------------------------------------------------------------------------------------

func refresh_section() -> void:
	"""Fill the Foraging section and set its orders' cards."""
	section.show_lines(woods_line(), trip_preview(), trips_out_line(), Rules.KIND_WORDS[choice_kind], choice_party)
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	var card: CardScript = trip_card(members)
	section.set_card(SectionScript.ACTION_AUTHORISE, card.text(), card.is_ok())
	card = cancel_card()
	section.set_card(SectionScript.ACTION_CANCEL, card.text(), card.is_ok())


func woods_line() -> String:
	"""What the woods hold of the chosen kind now (GDD §5.5's figures): its stock, its floor, the season, the quota."""
	var d: DriverScript = trips.driver
	var kind: int = Rules.KINDS[choice_kind]
	var season: String = "in season now" if d.availability(kind) > 0 else "out of season now"
	return "The woods' %s: %s of %s (keeps %s) · %s (%s) · today's quota %s of %s left" % [Rules.KIND_WORDS[choice_kind],
		Rules.units_text(d.stock_milli(kind)), Rules.units_text(d.capacity_milli(kind)), Rules.units_text(d.floor_milli(kind)),
		season, trips.season_words(choice_kind), Rules.units_text(d.quota_left_milli()), Rules.units_text(d.quota_today_milli())]


func trip_preview() -> String:
	"""What the chosen trip would do: where, how much, the work and the risk -- or why it can't."""
	var why: String = trips.trip_refusal(choice_kind, choice_party)
	if not why.is_empty():
		return "Can't now: %s" % why
	var kind: int = Rules.KINDS[choice_kind]
	var milli: int = trips.trip_milli(choice_kind, choice_party)
	return "A trip to %s: about %s home, %d WU a unit gathering · injury risk %d in 10000 each hour's work (shown, not rolled)" % [
		Rules.SPOT_NAMES[choice_kind], Rules.units_text(milli), trips.driver.work_per_u_wu(kind, 0),
		trips.driver.injury_per_10000(0)]


func trips_out_line() -> String:
	"""Each trip out, a line; '' with none."""
	var lines := PackedStringArray()
	for t: int in Rules.MAX_TRIPS:
		if trips.t_live[t] == 1:
			lines.append(trips.trip_line(t))
	return "\n".join(lines)


# --- the cards (decision 0332: each from its order's own decision) -------------------------------------------

func trip_card(members: PackedInt32Array) -> CardScript:
	"""Authorise trip's card: `trips.trip_refusal`, the haul, the work, who goes."""
	_card.reset("Forage %s at %s" % [Rules.KIND_WORDS[choice_kind], Rules.SPOT_NAMES[choice_kind]])
	var milli: int = trips.trip_milli(choice_kind, choice_party)
	_card.result = "%d foragers bring about %s of %s home to the stores, hours later (a basket each, at most %s)" % [
		choice_party, Rules.units_text(milli), Rules.KIND_WORDS[choice_kind], Rules.units_text(Rules.BASKET_MILLI)]
	_card.prerequisites.append("%s in season (%s); the woods' daily quota and their stock above the sustainable floor" % [
		Rules.KIND_WORDS[choice_kind].capitalize(), trips.season_words(choice_kind)])
	var why: String = trips.trip_refusal(choice_kind, choice_party)
	if not why.is_empty():
		_card.refuse("CANT_FORAGE", why, "another kind, a smaller party, or tomorrow")
		return _card
	var per: int = trips.driver.work_per_u_wu(Rules.KINDS[choice_kind], 0)
	@warning_ignore("integer_division") var each_mwu: int = Rules.work_mwu(milli, per) / choice_party
	_card.work_usec = FisheryRules.work_usec(each_mwu, 0)
	_card.work_note = " gathering each, plus the walks to the woods and home"
	_who_for(members)
	return _card


func cancel_card() -> CardScript:
	"""Cancel trip's card: `trips.cancel_refusal` on the earliest trip out, read without calling it off."""
	_card.reset("Call the foraging trip off")
	_card.result = "Its foragers not yet carrying come home empty (their claims and room given back); a haul in hand is brought home"
	var why: String = trips.cancel_refusal(trips.first_trip())
	if not why.is_empty():
		_card.refuse("NO_TRIP" if trips.trip_count() == 0 else "CARRYING", why, "")
	return _card


func _who_for(members: PackedInt32Array) -> void:
	"""The card's Who: the selected residents who may go, else the work board's queue; and what the first stops."""
	var going: int = -1
	var able: int = 0
	for who: int in members:
		if trips.job_of_worker(who) < 0:
			able += 1
			going = who if going < 0 else going
	if going >= 0:
		_card.worker = going
		_card.who = CardScript.assign_selected(trips.name_of(going), able, members.size())
		if _command != null:
			_card.interrupts = _command.interrupt_text(going)
		return
	_card.who = "Queue on the work board (J) for the Woods crew, then anyone free"
