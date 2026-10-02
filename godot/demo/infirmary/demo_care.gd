extends Node3D
## THE INFIRMARY in the live village: injuries and their care, run each frame on the one calendar, and the infirmary
## building the hurt go to. Decisions 0622, 0623 (the findings: 0621). Presentation only: it writes nothing into the
## settlement simulation.
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
##   * the INFIRMARY BUILDING (infirmary_building.gd, decision 0623): placed from the Tunnels panel's INFIRMARY SECTION
##     (infirmary_section.gd: its state, the supplies, the patients; "Build the infirmary…" or "Cancel the
##     infirmary"), built by residents through the work board, and handed to the desk, which sends the hurt there;
##   * the resident card's lines (`card_text`, through demo_command.gd `add_skill_text`) and the Demo Lab's test
##     injuries (`lab_hurt`).

const DeskScript := preload("res://demo/infirmary/care_desk.gd")
const SectionScript := preload("res://demo/infirmary/infirmary_section.gd")
const BuildingScript := preload("res://demo/infirmary/infirmary_building.gd")
const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const PatchViewScript := preload("res://demo/infirmary/herb_patch_view.gd")
const Rules := preload("res://demo/infirmary/care_rules.gd")
const PaceScript := preload("res://demo/work/work_pace.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
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
## The infirmary section is refreshed this often (real seconds).
const SECTION_REFRESH_S: float = 0.25
const BUILD: String = "Build the infirmary…"
const CANCEL: String = "Cancel the infirmary"
const BUILT: String = "The infirmary is built"
const BUILD_TIP: String = ("Place it, then residents fetch wood 40, stone 30 and cloth 12 and build it (1000 WU):"
	+ " the hurt rest and heal there at +4 health an hour (REQ-SET-017)")
const BUILT_TIP: String = ("The hurt rest and heal here; before it, or when its 8 beds are full, they rest in their own"
	+ " beds or by the hall")

var desk: DeskScript = DeskScript.new()
var section: SectionScript = SectionScript.new()
var patch_view: PatchViewScript = PatchViewScript.new()
var building: BuildingScript = BuildingScript.new()

var _cast: DemoCastScript = null
var _services: ServicesScript = null
var _night: NightScript = null
## Read each frame: the kitchen's nourishment (its `hunger`) and the water's swim state (its `rest` and hazards).
var _fed: RefCounted = null
var _swim: SwimStateScript = null
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
	add_child(building)
	building.configure(cast, services.stores, desk.state, services.props, Vector2.ZERO, desk.shelf_at())
	desk.infirmary = building.project
	building.project.cloth_held = desk.cloth_for_treatments
	section.on_press(_on_section_pressed)


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


func configure_building(store_at: Vector2, site: Callable, site_key: Callable, network: RefCounted, camera: Camera3D,
		say: Callable, before_placing: Callable) -> void:
	"""Where its builders fetch wood and stone (`store_at`, the open stockpile), its placing tool's site, network, camera
	and voice (infirmary_building.gd `configure_place`) -- kept clear of the shelf, the herb patch, the field-care spots
	and the stockpile -- and what runs before the tool is armed (the Dig tool put away)."""
	building.builders.configure(_cast, _services.props, store_at, desk.shelf_at())
	var keep := PackedVector2Array([desk.shelf_at(), desk.patch_at(), store_at])
	keep.append_array(_field_spots)
	building.configure_place(site, site_key, network, camera, _services.props, say, keep)
	building.before_placing = before_placing


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
	"""Fill the infirmary section: its lines and its one button (see the header)."""
	var project: ProjectsScript = building.project
	if project.is_done():
		section.show_lines(desk.infirmary_lines(), BUILT, false, BUILT_TIP)
	elif project.is_active():
		section.show_lines(desk.infirmary_lines(), CANCEL, true, "Cancel it: " + project.refund_text())
	else:
		section.show_lines(desk.infirmary_lines(), BUILD, true, BUILD_TIP)


func _on_section_pressed() -> void:
	"""The section's button: arm the placing tool, or cancel the planned infirmary (said in the news)."""
	var project: ProjectsScript = building.project
	if project.is_active():
		var refund: String = project.refund_text()
		if building.cancel().is_empty():
			_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE,
				"The infirmary was cancelled: it " + refund)
	elif not project.is_done():
		building.start_placing()
	refresh_section()


func card_text(i: int, alone: bool) -> String:
	"""The party panel's infirmary lines for resident `i` (care_desk.gd `card_text`)."""
	return desk.card_text(i, alone)


func lab_hurt(members: PackedInt32Array, serious: bool) -> int:
	"""The Demo Lab's test injury on these residents (care_desk.gd `test_hurt`); how many were hurt."""
	return desk.test_hurt(members, serious)
