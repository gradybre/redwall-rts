extends "res://test/framework/test_case.gd"
## Tunnel outlets (review ECO-006, decision 0884; farm_sim.gd TUNNEL OUTLETS, farm_jobs.gd KIND_FIT_OUTLET,
## farm_outlet_box.gd): a tunnel under a bed is transport only until an outlet is fitted and set; Drain sheds into a dry
## tunnel, Feed waters from a wet one, Shut does nothing; the job, its refusals and the panel's words. The moisture
## figures are farm_sim.gd's own DRAIN_PER_DAY / IRRIGATE_PER_DAY (1500) at an empty bed's 4000-8000 band.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const OutletBox := preload("res://demo/farm/farm_outlet_box.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")

const BED_LOAM: int = 0
const BED_CLAY: int = 1
const GARDEN: int = Catalog.GARDEN_FIRST

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func test_a_tunnel_is_transport_only_until_an_outlet_is_set() -> void:
	"""A dry tunnel and a wet one under empty beds at 5000: no outlet, nothing; Shut, nothing; Drain sheds 500 to the
	low side's 4500; Feed lifts to the 6000 middle."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_LOAM, 5000)
	_set_moisture(sim, BED_CLAY, 5000)
	sim.set_tunnel_water(BED_LOAM, true, false)
	sim.set_tunnel_water(BED_CLAY, false, true)
	assert_equal(sim.day_delta(BED_LOAM, 0, Sluice.SERVICE_NONE, 5000), 0, "a dry tunnel, no outlet: nothing")
	assert_equal(sim.day_delta(BED_CLAY, 0, Sluice.SERVICE_NONE, 5000), 0, "a wet tunnel, no outlet: nothing")
	assert_false(sim.is_drained(BED_LOAM) or sim.is_irrigated(BED_CLAY), "neither drains nor feeds")
	assert_true(sim.dry_tunnel_under(BED_LOAM) and sim.wet_tunnel_under(BED_CLAY), "the facts are kept")
	for bed: int in [BED_LOAM, BED_CLAY]:
		assert_true(sim.fit_outlet(bed).ok, "fitted on bed %d" % (bed + 1))
		assert_equal(sim.outlet_of(bed), SimScript.OUTLET_SHUT, "fitted shut")
	assert_equal(sim.day_delta(BED_LOAM, 0, Sluice.SERVICE_NONE, 5000), 0, "shut: nothing")
	assert_true(sim.set_outlet(BED_LOAM, SimScript.OUTLET_DRAIN).ok, "set to drain")
	assert_equal(sim.day_delta(BED_LOAM, 0, Sluice.SERVICE_NONE, 5000), -500, "drain: down to 4500")
	assert_true(sim.set_outlet(BED_CLAY, SimScript.OUTLET_FEED).ok, "set to feed")
	assert_equal(sim.day_delta(BED_CLAY, 0, Sluice.SERVICE_NONE, 5000), 1000, "feed: up to the 6000 middle")


func test_an_outlet_only_does_what_its_tunnel_allows() -> void:
	"""Drain over a wet tunnel drains nothing; Feed over a dry one feeds nothing; the tunnel changing changes it."""
	var sim := SimScript.new()
	sim.set_tunnel_water(BED_LOAM, true, false)
	assert_true(sim.fit_outlet(BED_LOAM).ok and sim.set_outlet(BED_LOAM, SimScript.OUTLET_FEED).ok, "feed")
	assert_false(sim.is_irrigated(BED_LOAM), "a dry tunnel feeds nothing")
	sim.set_tunnel_water(BED_LOAM, false, true)
	assert_true(sim.is_irrigated(BED_LOAM), "the tunnel now carries water: fed")
	assert_true(sim.set_outlet(BED_LOAM, SimScript.OUTLET_DRAIN).ok, "drain")
	assert_false(sim.is_drained(BED_LOAM), "a wet tunnel takes no drainage")
	sim.set_tunnel_water(BED_LOAM, true, false)
	assert_true(sim.is_drained(BED_LOAM), "dry again: drained")


func test_fitting_and_setting_refuse_what_cannot_be() -> void:
	"""No tunnel, already fitted, no outlet to set, an unknown or the same setting, no bed; a garden site not laid out."""
	var sim := SimScript.new()
	assert_equal(sim.outlet_refusal(BED_LOAM), SimScript.REFUSE_NO_TUNNEL, "no tunnel under it")
	assert_false(sim.fit_outlet(BED_LOAM).ok, "so no outlet")
	assert_equal(sim.set_outlet(BED_LOAM, SimScript.OUTLET_DRAIN).error, SimScript.REFUSE_NO_OUTLET, "nothing to set")
	sim.set_tunnel_water(BED_LOAM, true, false)
	var revision: int = sim.revision
	assert_true(sim.fit_outlet(BED_LOAM).ok, "fitted")
	assert_true(sim.revision > revision, "a visible change")
	assert_equal(sim.outlet_refusal(BED_LOAM), SimScript.REFUSE_ALREADY, "fitted already")
	assert_equal(sim.set_outlet(BED_LOAM, SimScript.OUTLET_SHUT).error, SimScript.REFUSE_ALREADY, "shut already")
	assert_equal(sim.set_outlet(BED_LOAM, 3).error, SimScript.REFUSE_BAD_SETTING, "no such setting")
	assert_equal(sim.set_outlet(BED_LOAM, -1).error, SimScript.REFUSE_BAD_SETTING, "nor below")
	assert_equal(sim.set_outlet(Catalog.BED_COUNT, 1).error, SimScript.REFUSE_NOT_A_BED, "no bed")
	assert_equal(sim.outlet_refusal(-1), SimScript.REFUSE_NOT_A_BED, "no bed to fit")
	sim.set_tunnel_water(GARDEN, true, false)
	assert_equal(sim.outlet_refusal(GARDEN), SimScript.REFUSE_NOT_LAID, "a bare garden site takes no outlet")
	assert_true(sim.has_outlet(BED_LOAM) and not sim.has_outlet(BED_CLAY), "only the loam's")


func test_the_fit_outlet_job() -> void:
	"""Its plan (walk to the bed, 6 WU of spade-work), its name and card words, and its refusal through the board."""
	assert_equal(JobsScript.KIND_NAMES[JobsScript.KIND_FIT_OUTLET], "Fit outlet", "named")
	assert_equal(JobsScript.PLANS[JobsScript.KIND_FIT_OUTLET],
		[JobsScript.STEP_GO_BED, JobsScript.STEP_WORK + JobsScript.WORK_FIT_OUTLET], "walk, then the work")
	assert_equal(JobsScript.WORK_WU[JobsScript.WORK_FIT_OUTLET], 6, "a ditch's spade-work")
	assert_equal(JobsScript.KIND_DELIVER, JobsScript.KIND_COUNT, "deliveries still come after the orderable kinds")
	assert_equal(FarmCard.NEEDS.size(), JobsScript.KIND_COUNT, "a need for every orderable kind")
	var sim := SimScript.new()
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_FIT_OUTLET, BED_LOAM, 0), SimScript.REFUSE_NO_TUNNEL,
		"refused with no tunnel")
	assert_equal(FarmCard.reason_words(SimScript.REFUSE_NO_TUNNEL), "no finished tunnel runs under this bed", "in words")
	sim.set_tunnel_water(BED_LOAM, true, false)
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_FIT_OUTLET, BED_LOAM, 0), &"", "ordered with one")
	assert_true(FarmCard.result_text(sim, JobsScript.KIND_FIT_OUTLET, BED_LOAM, null).begins_with("Fit outlet"),
		"its card's result")


func test_the_outlet_box_says_what_runs_under_and_what_each_setting_does() -> void:
	"""Hidden with no tunnel; the facts, Fit outlet before it is fitted, the three settings after, the one set pressed
	and disabled, each tooltip its effect on this bed and why it would do nothing now."""
	var sim := SimScript.new()
	var box := OutletBox.new()
	_nodes.append(box)
	box.bind(sim)
	box.refresh(BED_LOAM)
	assert_false(box.visible, "no tunnel: hidden")
	sim.set_tunnel_water(BED_LOAM, true, false)
	box.refresh(BED_LOAM)
	assert_true(box.visible and box.fit_button().visible, "a dry tunnel: Fit outlet")
	assert_equal(box.state_line(), "No outlet fitted (transport only)", "transport only")
	assert_true(sim.fit_outlet(BED_LOAM).ok and sim.set_outlet(BED_LOAM, SimScript.OUTLET_DRAIN).ok, "drain")
	box.refresh(BED_LOAM)
	assert_false(box.fit_button().visible, "fitted: no Fit")
	assert_equal(box.state_line(), "Outlet: Drain — draining the bed into the tunnel", "draining")
	var drain: Button = box.setting_button(SimScript.OUTLET_DRAIN)
	assert_true(drain.button_pressed and drain.disabled, "the setting now: pressed, not pressable")
	assert_true(box.setting_button(SimScript.OUTLET_FEED).tooltip_text.ends_with(OutletBox.FEED_NO_WATER),
		"Feed would feed nothing: no water in the tunnel")
	assert_true(drain.tooltip_text.contains("15%"), "Drain's 1500 a day as a percentage")
	sim.set_tunnel_water(BED_LOAM, false, true)
	box.refresh(BED_LOAM)
	assert_equal(box.state_line(), "Outlet: Drain — nothing: no dry tunnel under it", "said when it cannot drain")
	assert_equal(OutletBox.facts_text(sim, BED_LOAM), "A tunnel carrying the stream's water runs under this bed.", "wet")
	box.refresh(Catalog.BED_COUNT)
	assert_false(box.visible, "no bed: hidden")
