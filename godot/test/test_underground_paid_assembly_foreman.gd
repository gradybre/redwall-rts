extends "res://test/underground_paid_assembly_case.gd"
## The entry foreman on the real source and original paid owners: cuts, retirement, paid handling and install, the
## complete prefix and its hauled inputs (fixture: underground_paid_assembly_case.gd; decision 2044, CI time).


func test_entry_foreman_drives_cuts_retirement_paid_handling_and_install() -> void:
	"""ADR1196: only Foreman.advance(tick) runs twelve phases and the whole paid L0; ledgers match the hand path."""
	_probe = PaidProbe.new()
	_probe.before_each()
	if _probe._confirm_prefix() == NULL_REF: return
	var first: Vector3i = _probe._surface_point(3)
	assert_true(_probe._world._transforms.place(_probe._world._worker, first.x, first.y, first.z, 49152),
		"worker physically stands at the first authored station")
	var foreman: Foreman = Foreman.new()
	var placement: Vector2i = Vector2i(0, _probe._placements._get32(_probe._placements._live, Prefix.Placements.GENERATION, 0))
	assert_equal(foreman.configure(WorkAreaTests.foreman_owners(_probe), WorkAreaTests.foreman_crew(_probe), placement),
		&"", "cut plan")
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = _probe._router; paid.connector = _probe._paid; paid.contacts = _probe._contacts; paid.budget = _probe._world._budget
	assert_equal(foreman.configure_installation(paid, 0), &"", "installation plan from the Frontier install row")
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 40000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal")
	assert_true(foreman.is_done(), "cuts, retirement, handling, fastening and commit all completed")
	assert_equal(foreman.accepted_mwu() + foreman.install_mwu(), 48920, "16920 excavation plus 32000 fastening")
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._wood), 1500, "one whole L0 bill paid once")
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, 0), 1, "L0 installed")
	assert_equal(_probe._world._construction.live_project_count(), 0, "every Project retired")


func test_entry_foreman_runs_the_complete_prefix_from_the_confirmed_prefix() -> void:
	"""ADR1202/1207: only Foreman.advance(tick) runs six cubes, the paid L0 (split landing), the crossing survey,
	which now re-proves only the Locations it touches, and the paid T0, each group INSTALLED exactly once."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman()
	if foreman == null: return
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 120000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal on the whole prefix")
	assert_true(foreman.is_done(), "every planned task finished")
	assert_true(_probe._anchor._last_checks < 600000,
		"the crossing survey carries the untouched Locations: %d of 1048576 checks" % _probe._anchor._last_checks)
	_assert_complete_prefix_ledger(foreman)
	_assert_split_landing()
	_assert_crossing_reachability()


func test_entry_foreman_hauls_every_input_of_the_complete_prefix() -> void:
	"""ADR1210 (G4): all inputs start as surface stock staged at R. Only Foreman.advance(tick) runs; every unit
	reaches M by a real Delivery haul between the claw cuts (no tool at all, DEC-052), and the prefix installs once."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman(true)
	if foreman == null: return
	var peaks: PackedInt64Array = PackedInt64Array([0, 0])
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 200000:
		foreman.advance(tick)
		peaks[0] = maxi(peaks[0], _probe._world._binding._proof_checks)
		peaks[1] = maxi(peaks[1], _probe._anchor._last_checks)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal on the hauled prefix")
	assert_true(foreman.is_done(), "every planned task finished")
	print("HAULED-PREFIX ticks=%d trips=%d haul_mwu=%d route_peak=%d location_peak=%d" % [tick - _probe._tick,
		foreman.haul_trips(), foreman.haul_mwu(), peaks[0], peaks[1]])
	assert_true(peaks[0] < Prefix.Space.MAX_CHECKS and peaks[1] < Prefix.Space.MAX_CHECKS, "both check budgets hold")
	_assert_hauled_ledger(foreman)
