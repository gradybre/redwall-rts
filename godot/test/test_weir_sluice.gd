extends "res://test/framework/test_case.gd"
## The weir's sluice and the garden leat (decision 0441; review ECO-006): the sluice settings' table of bed services,
## what each service does to a bed's moisture at midnight through the farm's moisture model, the preview against the
## effect, the order and its card, floods down an open leat, the bed panel's sluice view and the Water service layer,
## and the gate's drawing. No scene tree and no staged assets. Values are worked by hand from the cited constants:
## §5.6's moisture bands (empty 4000-8000, roots 2500-7000, grain 3500-7500), MOISTURE_NEAR_MARGIN 2000, the leat's
## LEAT_PER_DAY 1500, WET_ABOVE_TOP 1000 and FLOOD_OVER_WET 500.

const Sluice := preload("res://demo/water/weir_sluice.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const LeatScript := preload("res://demo/farm/farm_leat.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const ViewScript := preload("res://demo/farm/farm_view.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const GateView := preload("res://demo/water/weir_gate_view.gd")
const SluiceBox := preload("res://demo/farm/farm_sluice_box.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
## The demo opens at 06:00: its first midnight is 18 hours on.
const TO_FIRST_MIDNIGHT_H: int = 18
const BED_2: int = 1
const BED_4: int = 3
const BED_6: int = 5

var _nodes: Array[Node] = []


func _open_incident(incidents: IncidentsScript, key: String) -> bool:
	"""Whether the incident `key` is raised and unresolved."""
	var serial: int = incidents.serial_of(key)
	return serial >= 0 and incidents.is_unresolved(serial)


func _disc(view: ViewScript, bed: int) -> Color:
	"""A bed's map-overlay disc colour as drawn."""
	return (view.beds[bed].overlay.material_override as StandardMaterial3D).albedo_color


func _farm(services: ServicesScript) -> DemoFarmScript:
	"""The farm over the placeholder village, off-tree, with a command layer and no HUD (test_demo_farm_ui.gd's)."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null, services)
	var farm := DemoFarmScript.new()
	_nodes.append(farm)
	var providers: Array[Callable] = []
	farm.configure({}, null, cast, command, camera, null, providers, services)
	return farm


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func _leat(sim: SimScript, setting: int, services: ServicesScript = null) -> LeatScript:
	"""A leat over `sim`, set to `setting`."""
	var leat := LeatScript.new()
	leat.configure(sim, services.incidents if services != null else null, services.notices if services != null else null)
	if setting != leat.setting:
		leat.set_sluice(setting)
	return leat


# --- the table --------------------------------------------------------------------------------------------

func test_each_setting_gives_each_bed_its_table_service() -> void:
	"""Closed: the zone dry; Half: Bed 2 and 4 normal, Bed 6 dry; Open: Bed 2 and 4 wet, Bed 6 normal; every other bed
	not served, and nothing for a setting that is not one."""
	var expected: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 0, 1, 0, 1]),
		PackedInt32Array([0, 2, 0, 2, 0, 1]),
		PackedInt32Array([0, 3, 0, 3, 0, 2]),
	]
	for setting: int in Sluice.SLUICE_COUNT:
		for bed: int in Catalog.BED_COUNT:
			assert_equal(Sluice.service_for(setting, bed), expected[setting][bed],
				"%s, bed %d" % [Sluice.SLUICE_NAMES[setting], bed + 1])
	assert_equal(Sluice.service_for(3, BED_2), Sluice.SERVICE_NONE, "no such setting")
	assert_equal(Sluice.service_for(-1, BED_2), Sluice.SERVICE_NONE, "nor below")
	assert_equal(Sluice.zone_index(BED_6), 2, "Bed 6 is last along the leat")
	assert_equal(Sluice.zone_index(0), -1, "Bed 1 is not on it")
	assert_equal(Sluice.list_words(PackedInt32Array([1, 3, 5])), "Bed 2, Bed 4 and Bed 6", "three named")
	assert_equal(Sluice.list_words(PackedInt32Array([3])), "Bed 4", "one named")


func test_the_leat_writes_the_table_into_the_farm_and_the_demo_opens_closed() -> void:
	"""The opening sluice is closed (the zone dry); each order writes its table row into the farm at once."""
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_CLOSED)
	assert_equal(Sluice.OPENING_SLUICE, Sluice.SLUICE_CLOSED, "the demo opens closed")
	for setting: int in [Sluice.SLUICE_OPEN, Sluice.SLUICE_HALF, Sluice.SLUICE_CLOSED]:
		var said: String = leat.set_sluice(setting)
		assert_false(said.begins_with("Can't"), "%s taken" % Sluice.SLUICE_NAMES[setting])
		for bed: int in Catalog.BED_COUNT:
			assert_equal(sim.leat_service_of(bed), Sluice.service_for(setting, bed),
				"%s writes bed %d" % [Sluice.SLUICE_NAMES[setting], bed + 1])
	assert_equal(leat.flow_permille(), 0, "closed: no flow")
	leat.set_sluice(Sluice.SLUICE_HALF)
	assert_equal(leat.flow_permille(), 500, "half: half")


func test_the_order_refuses_its_own_setting_and_an_unknown_one() -> void:
	"""Setting the sluice to what it is, or to no setting, is refused with the card's own words; nothing changes."""
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_OPEN)
	var revision: int = leat.revision
	assert_equal(leat.set_sluice(Sluice.SLUICE_OPEN), "Can't: the sluice is already open", "the same")
	assert_equal(leat.set_sluice(7), "Can't: there is no such sluice setting", "unknown")
	assert_equal(leat.revision, revision, "nothing changed")
	assert_equal(sim.leat_service_of(BED_2), Sluice.SERVICE_WET, "still wet")


# --- the moisture model -------------------------------------------------------------------------------------

func test_each_service_nudges_a_bed_through_the_moisture_model() -> void:
	"""NORMAL moves a bed toward its band's middle either way, at most 1500; WET raises it toward 1000 over its band's
	top and never lowers it; DRY and NONE add nothing."""
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_NORMAL, 5000, 4000, 8000), 1000, "normal up to the middle")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_NORMAL, 9000, 4000, 8000), -1500, "normal down, capped")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_NORMAL, 2000, 4000, 8000), 1500, "normal up, capped")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_WET, 8500, 4000, 8000), 500, "wet to 9000")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_WET, 5000, 4000, 8000), 1500, "wet, capped")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_WET, 9600, 4000, 8000), 0, "wet never lowers")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_DRY, 2000, 4000, 8000), 0, "dry adds nothing")
	assert_equal(SimScript.leat_delta(Sluice.SERVICE_NONE, 2000, 4000, 8000), 0, "nor none")


func test_a_watered_bed_is_not_drained_and_a_dry_one_keeps_its_tunnels() -> void:
	"""Bed 2 (empty, 4000-8000) at 5000 with a tunnel draining it: dry, the tunnel sheds 500 (to 4500); wet, the leat
	adds 1500 and nothing drains; normal, +1000. A ditch and a raised bed likewise yield to the leat."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_2, 5000)
	sim.set_tunnel_water(BED_2, true, false)
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_DRY, 5000), -500, "dry: the tunnel drains")
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_NONE, 5000), -500, "the same as no leat")
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_WET, 5000), 1500, "wet: the leat, no drain")
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_NORMAL, 5000), 1000, "normal: to the middle")
	sim.set_tunnel_water(BED_2, false, false)
	_set_moisture(sim, BED_2, 9000)
	assert_true(sim.drain_bed(BED_2).ok, "ditched")
	_set_moisture(sim, BED_2, 7000)
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_DRY, 7000), -1000, "dry: the ditch sheds 1000")
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_WET, 7000), 1000, "wet: up 1000, then over the top 0")
	var raised := SimScript.new()
	assert_true(raised.raise_bed(BED_2).ok, "raised")
	_set_moisture(raised, BED_2, 6000)
	assert_equal(raised.day_delta(BED_2, 0, Sluice.SERVICE_DRY, 6000), -800, "dry: the raised bed sheds 800")
	assert_equal(raised.day_delta(BED_2, 0, Sluice.SERVICE_NORMAL, 6000), 0, "normal at the middle: the leat holds it")


func test_wet_lands_in_the_wet_band_and_natural_drainage_still_applies() -> void:
	"""Bed 2 at 8000 (its band's top) served wet: +1000 from the leat, then the loam sheds 500 above the top -> 8500,
	in its WET band."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_2, 8000)
	assert_equal(sim.day_delta(BED_2, 0, Sluice.SERVICE_WET, 8000), 500, "+1000 - 500")
	assert_equal(sim.band_at(BED_2, 8500), SimScript.BAND_WET, "wet")


func test_a_closed_sluice_leaves_the_farm_exactly_as_without_the_leat() -> void:
	"""Three days and three midnights: a farm with the sluice closed matches one with no leat, bed for bed."""
	var with_leat := SimScript.new()
	var without := SimScript.new()
	_leat(with_leat, Sluice.SLUICE_CLOSED)
	with_leat.set_tunnel_water(BED_4, true, false)
	without.set_tunnel_water(BED_4, true, false)
	with_leat.advance_usec(72 * HOUR_USEC)
	without.advance_usec(72 * HOUR_USEC)
	for bed: int in Catalog.BED_COUNT:
		assert_equal(with_leat.moisture_of(bed), without.moisture_of(bed), "bed %d unchanged" % (bed + 1))


# --- the preview against the effect -------------------------------------------------------------------------

func test_the_preview_is_what_the_midnight_adds() -> void:
	"""Two farms from the same opening, one closed, one opened: Bed 2 at 5000, Bed 4 at 3000, Bed 6 at 5000. The
	preview says +1500, +1500 and +500 (wet, wet, normal toward 5500); at the first midnight the opened farm's beds
	stand exactly that much above the closed one's, and every other bed level with it."""
	var closed := SimScript.new()
	var opened := SimScript.new()
	_leat(closed, Sluice.SLUICE_CLOSED)
	var leat := _leat(opened, Sluice.SLUICE_OPEN)
	for sim: SimScript in [closed, opened]:
		_set_moisture(sim, BED_2, 5000)
		_set_moisture(sim, BED_4, 3000)
		_set_moisture(sim, BED_6, 5000)
	var preview: LeatScript.Preview = leat.preview()
	assert_equal(preview.beds, PackedInt32Array([BED_2, BED_4, BED_6]), "the zone, in leat order")
	assert_equal(preview.service_after, PackedInt32Array([3, 3, 2]), "wet, wet, normal")
	assert_equal(preview.nudge, PackedInt32Array([1500, 1500, 500]), "the preview's nudges")
	closed.advance_usec(TO_FIRST_MIDNIGHT_H * HOUR_USEC)
	opened.advance_usec(TO_FIRST_MIDNIGHT_H * HOUR_USEC)
	assert_equal(opened.days_run, 1, "one midnight")
	for k: int in preview.size():
		var bed: int = preview.beds[k]
		assert_equal(opened.moisture_of(bed) - closed.moisture_of(bed), preview.nudge[k], "bed %d as previewed" % (bed + 1))
	for bed: int in [0, 2, 4]:
		assert_equal(opened.moisture_of(bed), closed.moisture_of(bed), "bed %d untouched" % (bed + 1))


func test_near_its_top_a_bed_keeps_less_than_the_leat_s_share() -> void:
	"""Bed 2 at 7600: the preview's share opened is 1400 (to 9000); the first midnight's spring +600 takes both farms
	past the band's top, so the loam sheds 500 from the opened bed and 200 from the closed: 1100 more, not 1400 --
	why the preview names the leat's share and the weather and drainage come on top."""
	var closed := SimScript.new()
	var opened := SimScript.new()
	_leat(closed, Sluice.SLUICE_CLOSED)
	var leat := _leat(opened, Sluice.SLUICE_OPEN)
	_set_moisture(closed, BED_2, 7600)
	_set_moisture(opened, BED_2, 7600)
	assert_equal(leat.preview().nudge[0], 1400, "the leat's share")
	closed.advance_usec(TO_FIRST_MIDNIGHT_H * HOUR_USEC)
	opened.advance_usec(TO_FIRST_MIDNIGHT_H * HOUR_USEC)
	assert_equal(opened.last_weather_delta(), 600, "a +600 spring night")
	assert_equal(closed.moisture_of(BED_2), 8000, "7600 + 600 - 200")
	assert_equal(opened.moisture_of(BED_2), 9100, "7600 + 1400 + 600 - 500")


func test_the_preview_names_the_beds_each_setting_changes() -> void:
	"""The affected-bed preview, word for word, with Bed 4 waterlogged (9500 against roots' 7000 top)."""
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_CLOSED)
	_set_moisture(sim, BED_4, 9500)
	var p := LeatScript.Preview.new()
	assert_equal(leat.preview_into(Sluice.SLUICE_OPEN, p).text,
		"Open: Bed 2 and Bed 4 go to wet, Bed 6 to normal. Bed 4 is already waterlogged.", "open")
	assert_equal(leat.preview_into(Sluice.SLUICE_HALF, p).text,
		"Half open: Bed 2 and Bed 4 go to normal, Bed 6 gets none.", "half")
	assert_equal(leat.preview_into(Sluice.SLUICE_CLOSED, p).text,
		"Closed: Bed 2, Bed 4 and Bed 6 get no leat water.", "closed")
	assert_equal(p.service_now, PackedInt32Array([1, 1, 1]), "the zone dry now")
	_set_moisture(sim, BED_2, 5000)
	leat.preview_into(Sluice.SLUICE_OPEN, p)
	assert_equal(p.nudge[0], 1500, "the nudge is the previewed setting's, not the setting now's")
	assert_equal(p.flood_rise, PackedInt32Array([0, 0, 0]), "no flood running: no flood rise")
	assert_false(p.text.contains("Flood"), "and no flood words")
	assert_equal(p.band_now[1], SimScript.BAND_WATERLOGGED, "Bed 4's band now")
	_set_moisture(sim, BED_2, 500)
	assert_true(leat.preview_into(Sluice.SLUICE_CLOSED, p).text.ends_with("Bed 2 is already dry."), "a dry bed left dry")


func test_the_card_is_the_preview_and_refuses_the_setting_it_has() -> void:
	"""Open's card: its verb, the preview, at once, the wheel; Closed's card (the setting now) refused in the order's
	words."""
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_CLOSED)
	var card := CardScript.new()
	leat.card_into(card, Sluice.SLUICE_OPEN)
	assert_true(card.is_ok(), "open may be ordered")
	assert_equal(card.verb, "Sluice: Open", "the verb")
	assert_true(card.result.begins_with("Open: Bed 2 and Bed 4 go to wet, Bed 6 to normal."), "the preview")
	assert_true(card.result.ends_with(LeatScript.WHEN_TEXT), "at once, free, at midnight")
	assert_equal(card.work_usec, CardScript.NO_WORK, "no work line")
	assert_true(card.text().replace("\n  ", " ").contains("the beds' water changes at the next midnight"), "on the card")
	assert_equal(card.who, LeatScript.WHO_TEXT, "the wheel")
	leat.card_into(card, Sluice.SLUICE_CLOSED)
	assert_false(card.is_ok(), "closed is refused")
	assert_equal(card.code, LeatScript.REFUSE_SAME, "the order's code")
	assert_equal(card.reason, "the sluice is already closed", "the order's words")
	assert_true(card.text().contains("Can't now: the sluice is already closed"), "on the card")


# --- floods ------------------------------------------------------------------------------------------------

func test_a_flood_down_an_open_leat_waterlogs_its_wet_beds_when_it_passes() -> void:
	"""Open in a flood: an incident names what it will do; as it passes Bed 4 (roots, 3000) rises to 9500 --
	waterlogged -- Bed 2 (empty, 5000) to the scale's top 10000 (wet: its band reaches 10000) and Bed 6 (normal, grain
	5000) to 8500, wet. The incident resolves and the feed says so."""
	var services := ServicesScript.new()
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_OPEN, services)
	_set_moisture(sim, BED_2, 5000)
	_set_moisture(sim, BED_4, 3000)
	_set_moisture(sim, BED_6, 5000)
	leat.follow_flood(true)
	assert_true(leat.flooding, "flooding")
	assert_equal(leat.at_risk(), PackedInt32Array([BED_2, BED_4, BED_6]), "all three at risk")
	assert_true(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "the incident is raised")
	var p: LeatScript.Preview = leat.preview()
	assert_equal(p.flood_rise, PackedInt32Array([5000, 6500, 3500]), "the flood's rise, bed by bed")
	assert_true(p.text.ends_with("Flood: left like this, it waterlogs Bed 4 and wets Bed 2 and Bed 6 as it passes."),
		"the preview says it: %s" % p.text)
	leat.follow_flood(false)
	assert_equal(sim.moisture_of(BED_4), 9500, "Bed 4 at 7000 + 2000 + 500")
	assert_equal(sim.band_of(BED_4), SimScript.BAND_WATERLOGGED, "waterlogged")
	assert_equal(sim.moisture_of(BED_2), 10000, "Bed 2 at the top of the scale")
	assert_equal(sim.moisture_of(BED_6), 8500, "Bed 6 at 7500 + 1000")
	assert_equal(sim.band_of(BED_6), SimScript.BAND_WET, "wet")
	assert_false(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "resolved")
	assert_true(services.notices.text(0).begins_with("The flood ran down the open leat: Bed 2, Bed 4 and Bed 6"),
		"the feed: %s" % services.notices.text(0))


func test_closing_the_sluice_in_a_flood_spares_the_garden() -> void:
	"""Half open as a flood starts (Bed 2 and 4 normal: at risk); closed in time, the incident resolves, and the flood
	passes without touching a bed."""
	var services := ServicesScript.new()
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_HALF, services)
	_set_moisture(sim, BED_2, 5000)
	leat.follow_flood(true)
	assert_true(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "raised")
	leat.set_sluice(Sluice.SLUICE_CLOSED)
	assert_false(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "closed in time: resolved")
	assert_equal(leat.at_risk().size(), 0, "nothing at risk")
	leat.follow_flood(false)
	assert_equal(sim.moisture_of(BED_2), 5000, "untouched")


func test_a_closed_sluice_raises_no_flood_incident_and_opening_it_mid_flood_does() -> void:
	"""Closed as the flood starts: no incident. Opened during it: the incident comes."""
	var services := ServicesScript.new()
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_CLOSED, services)
	leat.follow_flood(true)
	assert_false(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "none while closed")
	leat.set_sluice(Sluice.SLUICE_OPEN)
	assert_true(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "opened mid-flood: raised")
	var posted: int = services.notices.count()
	leat.set_sluice(Sluice.SLUICE_HALF)
	leat.set_sluice(Sluice.SLUICE_OPEN)
	assert_equal(services.notices.count(), posted, "toggling during the flood warns no more")
	var serial: int = services.incidents.serial_of(LeatScript.FLOOD_KEY)
	assert_true(services.incidents.text_of(serial).contains("sluice open"), "its words follow the setting")
	assert_equal(sim.flood_surge(BED_2, Sluice.SERVICE_DRY), 0, "a dry bed takes no surge")


# --- the panel, the layer and the gate ----------------------------------------------------------------------

func test_the_bed_panel_shows_the_sluice_and_each_served_bed_says_so() -> void:
	"""The farm's weir view: the weir's title, the three settings (Closed lit), the preview of the setting under the
	pointer and a row per zone bed; a press gives the order, its answer on the panel. A served bed's line names its
	service; Bed 1's has none; Esc closes the weir view."""
	var farm := _farm(ServicesScript.new())
	var panel: BedPanelScript = farm.bed_panel
	farm.show_weir()
	assert_true(panel.showing_weir, "the weir shown")
	var texts: PackedStringArray = panel.shown_texts()
	assert_true(texts.has(BedPanelScript.WEIR_TITLE), "titled")
	assert_true(texts.has("Sluice: Closed"), "the setting")
	var box: SluiceBox = panel.sluice_box()
	assert_true(box.button(Sluice.SLUICE_CLOSED).button_pressed, "Closed lit")
	assert_true(box.button(Sluice.SLUICE_CLOSED).disabled, "and refused")
	assert_false(box.button(Sluice.SLUICE_OPEN).disabled, "Open may be pressed")
	assert_true(box.button(Sluice.SLUICE_OPEN).tooltip_text.begins_with("Sluice: Open"), "its card")
	box.hover(Sluice.SLUICE_OPEN)
	assert_true(box.preview_text().begins_with("Open: Bed 2 and Bed 4 go to wet"), "the hovered setting's preview")
	assert_true(box.row(0).begins_with("Bed 2 · "), "a row per bed")
	box.button(Sluice.SLUICE_OPEN).pressed.emit()
	assert_equal(farm.leat.setting, Sluice.SLUICE_OPEN, "ordered")
	assert_true(panel.shown_texts().has("Sluice now open: Bed 2 and Bed 4 go to wet, Bed 6 to normal."), "answered")
	assert_true(box.button(Sluice.SLUICE_OPEN).button_pressed, "Open lit now")
	farm.select_bed(BED_2)
	assert_false(panel.showing_weir, "a bed replaces it")
	assert_true(panel.shown_texts().has("Garden leat: wet (sluice open)"), "Bed 2 says so")
	farm.select_bed(0)
	for text: String in panel.shown_texts():
		assert_false(text.begins_with("Garden leat"), "Bed 1 is not served")
	farm.show_weir()
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.physical_keycode = KEY_ESCAPE
	assert_true(farm.handle_key(esc), "Esc taken")
	assert_false(panel.showing_weir, "and the weir view closed")


func test_the_tunnels_flood_reaches_the_garden_through_the_farm() -> void:
	"""The tunnels' threat brought now (a flood) with the sluice open: the farm's frame sees it and the incident is
	raised; the threat run out, the farm's next frame lands the surge on Bed 4 (waterlogged)."""
	var services := ServicesScript.new()
	var farm := _farm(services)
	assert_false(farm.flood_running(), "no threat running")
	farm.set_sluice(Sluice.SLUICE_OPEN)
	_set_moisture(farm.sim, BED_4, 3000)
	var events: RefCounted = farm._command.tunnels().ext.works.events
	assert_true(events.trigger(), "a threat brought")
	assert_equal(events.kind, 0, "the first is a flood")
	assert_true(farm.flood_running(), "the farm sees it")
	farm._process(0.0)
	assert_true(farm.leat.flooding, "the leat follows it")
	assert_true(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "raised through the farm's services")
	events.advance(events.left_usec)
	assert_false(farm.flood_running(), "over")
	farm._process(0.0)
	assert_equal(farm.sim.band_of(BED_4), SimScript.BAND_WATERLOGGED, "Bed 4 waterlogged as it passed")
	assert_false(_open_incident(services.incidents, LeatScript.FLOOD_KEY), "resolved")
	assert_equal(farm.lenses.title_of(3), "Growing: Water service", "the layer, third of the farm's")
	farm.lenses.select(3)
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_WATER, "it shows the water service")


func test_the_water_service_layer_colours_each_bed_by_its_service() -> void:
	"""The Water service layer: each bed's disc in its service's colour; a change of service redraws the bed."""
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_OPEN)
	var view := ViewScript.new()
	_nodes.append(view)
	view.build({}, sim)
	view.set_overlay(ViewScript.OVERLAY_WATER)
	view.refresh()
	assert_equal(_disc(view, BED_2), Look.SERVICE_OVERLAY[Sluice.SERVICE_WET], "Bed 2 wet")
	assert_equal(_disc(view, BED_6), Look.SERVICE_OVERLAY[Sluice.SERVICE_NORMAL], "Bed 6 normal")
	assert_equal(_disc(view, 0), Look.SERVICE_OVERLAY[Sluice.SERVICE_NONE], "Bed 1 not served")
	leat.set_sluice(Sluice.SLUICE_CLOSED)
	view.refresh()
	assert_equal(_disc(view, BED_2), Look.SERVICE_OVERLAY[Sluice.SERVICE_DRY], "redrawn dry")


func test_the_gate_rises_with_the_setting_on_the_demo_clock() -> void:
	"""The board stands at 0 closed, half of LIFT_MODEL half open, LIFT_MODEL open; it winds at LIFT_RATE a second of
	demo time, and the leat head's water shows only while it flows."""
	assert_almost_equal(GateView.target_lift(0), 0.0, "closed")
	assert_almost_equal(GateView.target_lift(500), GateView.LIFT_MODEL * 0.5, "half")
	assert_almost_equal(GateView.target_lift(1000), GateView.LIFT_MODEL, "open")
	var sim := SimScript.new()
	var leat := _leat(sim, Sluice.SLUICE_CLOSED)
	var view := GateView.new()
	_nodes.append(view)
	view.build(null, null, leat, null)
	assert_almost_equal(view.lift, 0.0, "built closed")
	assert_false(view.head_water().visible, "the head empty")
	leat.set_sluice(Sluice.SLUICE_HALF)
	view.snap()
	assert_almost_equal(view.head_water().position.y, (GateView.HEAD_FLOOR + GateView.HEAD_BRIM) * 0.5, "half full")
	view.lift = 0.0
	leat.set_sluice(Sluice.SLUICE_OPEN)
	view.step(0.5)
	assert_almost_equal(view.lift, GateView.LIFT_RATE * 0.5, "half a second wound")
	view.step(10.0)
	assert_almost_equal(view.lift, GateView.LIFT_MODEL, "fully up")
	assert_true(view.head_water().visible, "the head full")
	assert_almost_equal(view.head_water().position.y, GateView.HEAD_BRIM, "to the brim")
	view.step(0.0)
	assert_almost_equal(view.lift, GateView.LIFT_MODEL, "no demo time, no winding")


func test_the_bay_board_is_taken_out_of_the_weir_and_nothing_else() -> void:
	"""open_bay drops the triangles centred in the bay and keeps the rest (and any other surface)."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.33, 0.4, 0.0), Vector3(0.41, 0.4, 0.0), Vector3(0.37, 0.7, 0.0),
		Vector3(-0.5, 0.4, 0.0), Vector3(-0.4, 0.4, 0.0), Vector3(-0.45, 0.7, 0.0),
		Vector3(0.33, 0.9, 0.0), Vector3(0.41, 0.9, 0.0), Vector3(0.37, 1.0, 0.0)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var opened: ArrayMesh = GateView.open_bay(mesh)
	assert_equal(opened.get_surface_count(), 2, "both surfaces")
	assert_equal((opened.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array), PackedInt32Array([3, 4, 5, 6, 7, 8]),
		"the bay's triangle gone, the wall's and the crossbeam's kept")
	assert_equal((opened.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 9, "the sill untouched")
	assert_true(GateView.in_bay(Vector3(0.37, 0.5, 0.0)), "the bay")
	assert_false(GateView.in_bay(Vector3(0.37, 0.5, 0.2)), "downstream of it")


func test_a_click_on_the_weir_picks_it_and_elsewhere_does_not() -> void:
	"""A ray straight down onto the weir's middle picks it; onto the village square, or upward, does not."""
	var at: Vector2 = GateView.weir_placement()["at"]
	assert_true(GateView.ray_hits_weir(Vector3(at.x, 30.0, at.y), Vector3.DOWN), "the weir")
	assert_false(GateView.ray_hits_weir(Vector3(0.0, 30.0, 0.0), Vector3.DOWN), "the square")
	assert_false(GateView.ray_hits_weir(Vector3(at.x, 30.0, at.y), Vector3.UP), "upward")
	var slant := Vector3(0.0, -1.0, 1.0).normalized()
	assert_true(GateView.ray_hits_weir(Vector3(at.x, 10.0, at.y - 10.0), slant), "45 degrees onto its crest")
	assert_false(GateView.ray_hits_weir(Vector3(at.x, 10.0, at.y + 3.0 - 10.0), slant), "45 degrees, 3 m south of it")
	var obstacle: Vector3 = GateView.land_obstacles()[0]
	assert_almost_equal(Vector2(obstacle.x, obstacle.y).distance_to(GateView.HEAD_AT), 0.0, "the head is an obstacle")
