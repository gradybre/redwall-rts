extends "res://test/underground_host_case.gd"
## The uninterrupted live entry chain at its finish: the whole flight to its last sill. Split from
## test_underground_host.gd so CI can shard it apart (decision 1243); fixture: underground_host_case.gd. Decision 2045
## (M5): the flight is about 92,500 ticks, so this suite reads its finish from the committed underground_flight
## checkpoint, and test_underground_flight_<k>.gd fly it segment by segment, restored along the way, each segment's
## end byte-identical to the uninterrupted flight's (they replace decision 2044's restored whole entry and its second
## process, and carry DEC-059's never-back-at-M count).

const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")


func test_the_live_chain_builds_the_descent_down_the_stair_to_the_sill() -> void:
	"""ADR1229 increment 6b: past the prefix the crew cuts the descent's cubes from the surface, then installs T1-T6,
	each from the tread above: it walks from M to the crossing arrival, down the stair (walk-in, step forward, one
	descent per tread, step back onto the station), funds and fits the tread. Decision 2044: then each later module
	from its landing (T0' to T6'); decision 2045 (M5): five modules, each landing's deep stage first. Each group is
	installed exactly once; the foreman ends with G9 at the Kitchen (DEC-054), and a finished entry re-raises it. The
	crew's needs and R's stock are sustained (see DESCENT_DONE_TICK)."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var entry: Settlement.UndergroundEntryRuntime = done[1]
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_DONE, "the runtime finished the flight")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "and stopped at the Kitchen")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G9"), "named gap row G9")
	assert_true(entry._foreman.is_done() and entry._foreman.error() == &"", "every planned task done")
	assert_equal(_done_ledger(o, entry._foreman), DESCENT_LEDGER, "every group and every cut with their exact Work, once")
	assert_equal(o.construction.live_project_count(), 0, "every Project retired")
	assert_false(_host.begin_underground_entry(Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)), "a finished entry")
	assert_equal(_host.last_refusal(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "re-raises G9")
	_assert_stair_carry_published(o, entry)


func _assert_stair_carry_published(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime) -> void:
	"""Decision 1972: once module 0's sill is in, its stops A/U stand and the stair carry H <-> T6 is published (17
	CARRY edges, all EARTH_TIMBER, beside the ground hauls' two). Decision 2044 (M2): the carry stays module 0's
	(module 1's treads are fitted from the flight, P-2044-16 (a)); landing 1's floor stops stand below that sill and
	the last landing's floor stops are the lowest installed stops."""
	var stops: StairPath.Stops = entry._foreman._stops()
	assert_true(stops.at(StairPath.KIND_H, -1) != StairPath.NULL_REF, "H stands on L0")
	assert_true(stops.at(StairPath.KIND_A, StairPath.SILL_LEVEL) != StairPath.NULL_REF
		and stops.at(StairPath.KIND_U, StairPath.SILL_LEVEL) != StairPath.NULL_REF, "module 0's sill's A and U stand")
	assert_true(stops.at(StairPath.KIND_F, 1) != StairPath.NULL_REF and stops.at(StairPath.KIND_FP, 1) != StairPath.NULL_REF,
		"landing 1's F and F' stand")
	var frontier: RefCounted = entry._foreman._owners.frontier
	var endpoint: PackedInt32Array = PackedInt32Array()
	endpoint.resize(Frontier.row_fields(Frontier.ENDPOINT))
	var lowest: int = 0
	for selector: int in frontier.row_count(Frontier.ENDPOINT, frontier.content_revision()):
		if frontier.endpoint_into(selector, endpoint) == &"" and endpoint[0] == Frontier.INSTALLED_CONTACT:
			lowest = mini(lowest, endpoint[5])
	assert_equal(lowest, -1024 * StairPath.MODULES, "the last landing's floor stops are the lowest installed stops")
	var edge: Session.Retirement.Routes.Edge = Session.Retirement.Routes.Edge.new()
	var carry: PackedInt32Array = PackedInt32Array([0, 0])
	for row: int in o.routes._edge_capacity:
		if o.routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, o.routes._live.fields[Session.Retirement.Routes.E_GENERATION \
			* o.routes._edge_capacity + row])
		if o.routes.edge_metadata_into(ref, edge) != &"" or edge.mode != Profiles.MODE_CARRY: continue
		carry[0 if edge.family == 0 else 1] += 1
	assert_equal(carry, PackedInt32Array([17, 2]), "the stair carry H <-> T6 (17 EARTH_TIMBER), the ground hauls' 2")
