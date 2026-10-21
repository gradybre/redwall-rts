extends "res://test/underground_host_case.gd"
## Decision 2045: one segment of the whole M5 flight. The committed underground_flight checkpoint (decision 1240,
## test/fixtures/checkpoint_recipes.gd) holds the sustained flight at every FLIGHT_TICKS tick and at its finish, as
## the generator flew it uninterrupted from tick 0. Segment k loads point k - 1 (segment 0 begins the entry), flies to
## point k with its runtime replaced by its record every ENTRY_RESTORE_EVERY ticks and its route owners cold-restored
## every ROUTE_RESTORE_EVERY ticks, and requires the save there to equal the committed point byte for byte. So every
## point is the uninterrupted flight's (by induction from tick 0), the restored flight ends byte-identical to the
## uninterrupted one at every point, and each suite flies one stretch within CI's per-suite budget. Not a suite:
## test_underground_flight_<k>.gd are.

## DEC-059: the restored flight replaces the runtime by its record this often (ticks; prime).
const ENTRY_RESTORE_EVERY: int = 11

var _restores: int = 0
var _at_m: int = 0
var _crew_row: int = -1


func _assert_flight_segment(index: int) -> void:
	"""Fly segment `index` with restores along the way; its end must be the committed point byte for byte."""
	_checkpoint_loaded = true
	var point: String = Recipes.flight_point(index)
	var refusal: String = String(Recipes.begin_flight(_host, _content)) if index == 0 \
		else Store.load_into(_host, GameManager, Recipes.FLIGHT, Recipes.flight_point(index - 1), _content)
	assert_equal(refusal, "", "segment %d starts (%s)" % [index, "tick 0" if index == 0 else Recipes.flight_point(index - 1)])
	if refusal != "": return
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	_crew_row = o.residents.directory().get_typed_row(_host.underground_entry().crew().worker)
	var stepper: Recipes.FlightStepper = Recipes.FlightStepper.new(_host)
	stepper.between = _restore_along_the_way
	var built: Recipes.Built = Recipes.Built.new()
	Recipes.drive_flight(built, stepper, PackedStringArray([point]))
	assert_equal(built.error, "", "the restored flight reaches %s" % point)
	if built.error != "": return
	var committed: Store.Loaded = Store.read_point(Recipes.FLIGHT, point)
	assert_true(committed.is_ok(), committed.error)
	assert_equal(int(built.points[point][0]), committed.tick, "%s: the same tick" % point)
	assert_true(built.points[point][1] == committed.bytes,
		"%s: the flight restored along the way saves byte-identically to the uninterrupted one" % point)
	assert_true(_restores > 0, "the runtime was replaced by its record along the way (%d)" % _restores)
	assert_equal(_at_m, 0, "DEC-059 (P1): after T1 and before module 0's sill the fitter never stands at M")


func _restore_along_the_way(tick: int) -> bool:
	"""Before tick `tick`, after the stand-ins (as `_whole_entry(true)` ordered them): count DEC-059's ticks at M,
	replace the runtime by its record and cold-restore the route owners on their periods."""
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	if _at_m_past_t1(o, _host.underground_entry()): _at_m += 1
	if tick % ENTRY_RESTORE_EVERY == 0:
		if not _replace_entry_with_its_record(_host.underground_session(), tick): return false
		_restores += 1
	return tick % ROUTE_RESTORE_EVERY != 0 or _cold_restore_routes(o, tick)


func _at_m_past_t1(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""DEC-059 (P1): after T1 is installed and before module 0's sill, the crew stands at M."""
	var installed: int = _installed_groups(entry) if entry._foreman != null else 0
	return installed > PREFIX_INSTALLS and installed < MODULE_ZERO_INSTALLS \
		and o.routes._resident_pair(Session.Retirement.Routes.R_LOCATION_SLOT, _crew_row) == entry._published.endpoints[1]
