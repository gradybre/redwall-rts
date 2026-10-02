extends Node3D
## THE INFIRMARY in the live village: injuries and their care, run each frame on the one calendar. Decision 0622 (the
## findings: 0621). Presentation only: it writes nothing into the settlement simulation.
##
## What it wires (the rules are care_desk.gd's and care_state.gd's):
##   * the care desk over the cast's brains, the night's beds (demo/burrow/night_routine.gd) and the network's rooms,
##     its news into the village's one feed and incidents (demo_notices.gd, demo_incidents.gd: the current call shape);
##   * the water's hazards (HAZ-002/003) read from its swim state each frame, before the desk;
##   * hunger from the kitchen (demo/kitchen/nourishment.gd) and rest from the water's stamina, mirrored into health;
##   * the village's one work pace (demo/work/work_pace.gd) -- the desk adds the health factor to it;
##   * the herb patch drawn by the south road (herb_patch_view.gd), and its standing spot found on the cast's ground;
##   * the FIELD-CARE SPOTS (P2): a row of places on the open ground before the hall's steps, one a resident, where a
##     patient with no bed lies to be treated, each found on the cast's ground and kept apart;
##   * the SICKBAY SECTION in a selected burrow home's box (sickbay_section.gd), refreshed while shown;
##   * the resident card's lines (`card_text`, through demo_command.gd `add_skill_text`) and the Demo Lab's test
##     injuries (`lab_hurt`).

const DeskScript := preload("res://demo/infirmary/care_desk.gd")
const SectionScript := preload("res://demo/infirmary/sickbay_section.gd")
const PatchViewScript := preload("res://demo/infirmary/herb_patch_view.gd")
const Rules := preload("res://demo/infirmary/care_rules.gd")
const PaceScript := preload("res://demo/work/work_pace.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

@warning_ignore_start("integer_division")

## The herb patch's standing spot is looked for on rings round CareRules.HERB_PATCH_AT (fishery.gd's own search).
const SPOT_BODY_M: float = 0.56
const SPOT_RING_M: float = 0.3
const SPOT_RINGS: int = 12
## The field-care spots: FIELD_ROW across, FIELD_STEP_M apart, FIELD_OUT_M out from the hall's steps toward the square.
const FIELD_ROW: int = 5
const FIELD_STEP_M: float = 1.3
const FIELD_OUT_M: float = 2.6
## The herb shelf's delivery spot: this far out from the hall's steps toward the square, clear of the steps' own spot
## (residents stand there), so a carrier's way is not blocked.
const SHELF_OUT_M: float = 1.2
## The sickbay section is refreshed this often while shown (real seconds).
const SECTION_REFRESH_S: float = 0.25
const MAKE: String = "Make it the sickbay"
const STOP: String = "Stop using it as the sickbay"
const MAKE_TIP: String = "Keep this home's beds for the sick: they mend at +4 health an hour here, not +2 (REQ-SET-017)"
const STOP_TIP: String = "Give this home's beds back to the night's sleepers"

var desk: DeskScript = DeskScript.new()
var section: SectionScript = SectionScript.new()
var patch_view: PatchViewScript = PatchViewScript.new()

var _cast: DemoCastScript = null
var _services: ServicesScript = null
var _night: NightScript = null
## Read each frame: the kitchen's nourishment (its `hunger`) and the water's swim state (its `rest` and hazards).
var _fed: RefCounted = null
var _swim: SwimStateScript = null
## `selected_room() -> int`: the room the tunnels' panel shows (-1: none).
var _selected_room: Callable = Callable()
var _empty: PackedInt32Array = PackedInt32Array()
var _section_in: float = 0.0
var _field_spots: PackedVector2Array = PackedVector2Array()


func configure(cast: DemoCastScript, services: ServicesScript, night: NightScript, graph: RefCounted, fed: RefCounted,
		swim: SwimStateScript, pace: PaceScript) -> void:
	"""The infirmary for this cast on this village's services, beds, rooms, hunger and water (any but the cast may be
	null), adding its factor to the village's work pace (null: a private one)."""
	name = "DemoCare"
	_cast = cast
	_services = services
	_night = night
	_fed = fed
	_swim = swim
	_configure_desk(night, graph)
	desk.bind_news(services.notices, services.incidents)
	if pace != null:
		desk.use_pace(pace)
	var none := PackedVector2Array()
	desk.set_places(_standable(Rules.HERB_PATCH_AT, none), _standable(_shelf() + _toward() * SHELF_OUT_M, none))
	_find_field_spots()
	desk.set_field_spot(field_spot)
	desk.start_at(services.calendar.tick, services.calendar.now().absolute_day)
	add_child(patch_view)
	patch_view.build(Rules.HERB_PATCH_AT, 0.0)
	patch_view.show_stock(desk.state.patch_milli)
	section.on_press(_on_sickbay_pressed)


func _configure_desk(night: NightScript, graph: RefCounted) -> void:
	"""The desk over the cast's brains, names, cast keys and §5.2 size classes (meal_rules.gd by species)."""
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	var sizes := PackedByteArray()
	for i: int in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		keys.append(actor.creature_key)
		sizes.append(MealRules.size_of_species(actor.species))
	desk.configure(brains, names, keys, sizes, night, graph)


func watch_rooms(selected_room: Callable) -> void:
	"""`selected_room() -> int`: the room the tunnels' panel shows, whose sickbay section this fills."""
	_selected_room = selected_room


func _toward() -> Vector2:
	"""From the hall's steps toward the village's middle (the square)."""
	var shelf: Vector2 = _shelf()
	return (-shelf).normalized() if shelf.length() > 0.1 else Vector2(0.0, 1.0)


func _shelf() -> Vector2:
	"""The herb shelf's spot: the hall's steps (the night's hall), else the village's middle."""
	var hall: int = _cast.space().poi_names.find(NightScript.HALL_POI)
	return _cast.space().poi_position[hall] if hall >= 0 else Vector2.ZERO


func _find_field_spots() -> void:
	"""One field-care spot a resident (see the header), kept apart from those found before it."""
	var shelf: Vector2 = _shelf()
	var toward: Vector2 = _toward()
	var across: Vector2 = Vector2(-toward.y, toward.x)
	_field_spots.clear()
	for i: int in _cast.actor_count():
		var row: int = i / FIELD_ROW
		var along: float = (float(i % FIELD_ROW) - float(FIELD_ROW - 1) * 0.5) * FIELD_STEP_M
		var target: Vector2 = shelf + toward * (FIELD_OUT_M + FIELD_STEP_M * float(row)) + across * along
		_field_spots.append(_standable(target, _field_spots))


func field_spot(i: int) -> Vector2:
	"""Resident `i`'s field-care spot (see the header)."""
	return _field_spots[i] if i >= 0 and i < _field_spots.size() else Vector2.ZERO


func _standable(target: Vector2, taken: PackedVector2Array) -> Vector2:
	"""The spot nearest `target`, on rings round it, that the widest resident may stand at and reach, clear of the
	`taken` spots (the target itself with no cast)."""
	if _cast.actor_count() == 0:
		return target
	var from: Vector2 = (_cast.actor(0) as DemoActorScript).brain.surface_point()
	var none := PackedVector3Array()
	for ring: int in SPOT_RINGS:
		for k: int in (1 if ring == 0 else 12):
			var at: Vector2 = target + Vector2.from_angle(TAU * k / 12.0) * SPOT_RING_M * ring
			if CastOrdersScript.spot_ok(_cast.space(), at, SPOT_BODY_M, _cast.bounds(), none, taken, from):
				return at
	return target


func _process(delta: float) -> void:
	"""Once a frame, after the calendar has moved (see the header)."""
	update()
	_section_in -= delta
	if _section_in <= 0.0:
		_section_in = SECTION_REFRESH_S
		refresh_section()


func update() -> void:
	"""The water's hazards, then the desk on this frame's calendar tick; the patch drawn to its stock."""
	var calendar := _services.calendar
	var now := calendar.now()
	desk.watch_water(_swim)
	var hunger: PackedInt32Array = _fed.get(&"hunger") if _fed != null else _empty
	var rest: PackedInt32Array = _swim.rest if _swim != null else _empty
	desk.update(calendar.tick, now.absolute_day, now.season, hunger, rest, _night != null and _night.is_night())
	patch_view.show_stock(desk.state.patch_milli)


func refresh_section() -> void:
	"""Fill the sickbay section for the burrow home the tunnels' panel shows (hidden for anything else)."""
	var r: int = int(_selected_room.call()) if _selected_room.is_valid() else -1
	if r < 0 or desk.sickbay_refusal(r) == DeskScript.NOT_A_HOME:
		section.hide_section()
		return
	var is_it: bool = r == desk.sickbay and desk.is_designated()
	var why: String = desk.sickbay_refusal(r)
	section.show_home(desk.home_lines(r), STOP if is_it else MAKE, is_it or why.is_empty(),
		STOP_TIP if is_it else (MAKE_TIP if why.is_empty() else "Not yet: " + why))


func _on_sickbay_pressed() -> void:
	"""The section's button: make the shown home the sickbay, or stop using it as one; said in the news."""
	var r: int = int(_selected_room.call()) if _selected_room.is_valid() else -1
	if r < 0:
		return
	var words: String
	if r == desk.sickbay and desk.is_designated():
		desk.clear_sickbay()
		words = "%s is a home again: its beds are the night's" % NightScript.room_name(r)
	else:
		var why: String = desk.set_sickbay(r)
		words = "%s is the sickbay: its beds are kept for the sick" % NightScript.room_name(r) if why.is_empty() \
			else "%s cannot be the sickbay: %s" % [NightScript.room_name(r), why]
	_services.notices.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_NOTE, words)
	refresh_section()


func card_text(i: int, alone: bool) -> String:
	"""The party panel's infirmary lines for resident `i` (care_desk.gd `card_text`)."""
	return desk.card_text(i, alone)


func lab_hurt(members: PackedInt32Array, serious: bool) -> int:
	"""The Demo Lab's test injury on these residents (care_desk.gd `test_hurt`); how many were hurt."""
	return desk.test_hurt(members, serious)
