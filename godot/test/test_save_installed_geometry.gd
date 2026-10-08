extends "res://test/framework/test_case.gd"
## `save_installed_geometry.gd` (ADR 1228's open point): a loaded Placement's installed parts are
## proved against the restored Space.
##
## The box subtraction is checked on its own. Then the live entry chain is run to the first
## boundary after its paid L0 installation completes: the live world proves (no false
## refusal), a Placement claiming one more installed group than Space holds refuses, and a Space whose
## installed region lost its owner refuses. Each tamper is undone before the next check.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Geometry := preload("res://scripts/core/save_installed_geometry.gd")
const Chain := preload("res://test/fixtures/underground_entry_chain.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")

## ADR 1228's goal chain stops by tick 4800 (`ENTRY_DESCENT_UNBUILT`); its paid L0 installation
## completes before that. The run stops at the first boundary with an installed group.
const LAST_TICK: int = 4800
## 100 ms host frames: exactly three ticks at 1x.
const FRAME_USEC: int = 100000

var _host: Node = null


func after_each() -> void:
	"""Free the host; leave the autoload as the other suites expect it."""
	if _host != null:
		_host.free()
		_host = null
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _boxes(values: Array) -> PackedInt32Array:
	"""A packed box list."""
	return PackedInt32Array(values)


func _volume(boxes: PackedInt32Array) -> int:
	"""The summed volume of a disjoint box list."""
	var total: int = 0
	@warning_ignore("integer_division") var count: int = boxes.size() / 6
	for index: int in count:
		var at: int = index * 6
		total += (boxes[at + 3] - boxes[at]) * (boxes[at + 4] - boxes[at + 1]) * (boxes[at + 5] - boxes[at + 2])
	return total


func test_subtraction_leaves_exactly_the_uncovered_volume() -> void:
	"""A cover inside, across and outside a box leaves its exact remainder; a full cover leaves none."""
	var box: PackedInt32Array = _boxes([0, 0, 0, 10, 10, 10])
	assert_true(Geometry.subtract(box, _boxes([0, 0, 0, 10, 10, 10])).is_empty(), "covered whole")
	assert_true(Geometry.subtract(box, _boxes([-5, -5, -5, 15, 15, 15])).is_empty(), "covered by more")
	assert_equal(_volume(Geometry.subtract(box, _boxes([2, 2, 2, 4, 4, 4]))), 1000 - 8, "a hole")
	assert_equal(_volume(Geometry.subtract(box, _boxes([5, -1, -1, 20, 20, 20]))), 500, "a half")
	assert_equal(Geometry.subtract(box, _boxes([10, 0, 0, 20, 10, 10])), box, "touching is not covering")
	var halves: PackedInt32Array = Geometry.subtract(box, _boxes([0, 0, 0, 5, 10, 10]))
	assert_true(Geometry.subtract(halves, _boxes([5, 0, 0, 10, 10, 10])).is_empty(), "two pieces cover it")


func _installed_host() -> Placements:
	"""The live chain run to its first installed group; its Placements owner."""
	_host = Settlement.new()
	var content: RefCounted = Chain.load_content()
	assert_equal(Chain.mount_and_compose(_host, content), &"", "mounted and composed")
	assert_true(GameManager.start_game(), "a fresh clock")
	assert_equal(Chain.begin_entry(_host), &"", "the entry begins")
	assert_true(GameManager.bind_simulation(_host.run_tick, _host.run_day_boundary), "bind")
	var placements: Placements = _host.underground_session()._retirement_owners.placements
	while GameManager.clock().completed_tick() < LAST_TICK and _installed_row(placements) < 0:
		GameManager.advance_host_time(FRAME_USEC)
	GameManager.unbind_simulation()
	return placements


func _installed_row(placements: Placements) -> int:
	"""The first live Placement with an installed group, or -1."""
	for row: int in placements._capacity:
		if placements._live.present[row] == 1 \
				and placements._get32(placements._live, Placements.INSTALLED, row) > 0:
			return row
	return -1


func test_the_live_installation_proves_and_a_tampered_image_refuses() -> void:
	"""No false refusal on the real installed world; an extra claimed group or a lost region refuses."""
	var placements: Placements = _installed_host()
	var row: int = _installed_row(placements)
	assert_true(row >= 0, "the chain installed a group by tick %d" % LAST_TICK)
	if row < 0:
		return
	assert_equal(Geometry.refusal(placements), &"", "the live installed parts are all in Space")
	var installed: int = placements._get32(placements._live, Placements.INSTALLED, row)
	if installed < placements._live.header[Placements.H_GROUP_COUNT]:
		placements._set32(placements._live, Placements.INSTALLED, row, installed + 1)
		assert_true(Geometry.refusal(placements) != &"", "a group never installed refuses")
		placements._set32(placements._live, Placements.INSTALLED, row, installed)
	var region: int = _covering_region(placements, row)
	assert_true(region >= 0, "an installed part has its region")
	var space: RefCounted = placements._space
	var owner_slot: int = space._r_owner_slot[region]
	space._r_owner_slot[region] = -1
	assert_equal(Geometry.refusal(placements), Geometry.REFUSE_MISSING, "a region that lost its owner refuses")
	space._r_owner_slot[region] = owner_slot
	assert_equal(Geometry.refusal(placements), &"", "and proves again once restored")


func _covering_region(placements: Placements, row: int) -> int:
	"""A live region carrying the first installed part's owner, level and role."""
	var part: Geometry.Expected = Geometry.Expected.new()
	var first: int = placements._assemblies._first_part[0]
	if Geometry.Locations.installed_prism_into(placements, row, first, part.box) != &"":
		return -1
	Geometry._expect(placements, row, first, part)
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for region: int in placements._space._region_capacity:
		if placements._space._r_present[region] != 1 or not Geometry._matches(placements._space, region, part):
			continue
		Geometry._box_of(placements._space, region, box)
		if Geometry.Space.overlaps(box, part.box):
			return region
	return -1
