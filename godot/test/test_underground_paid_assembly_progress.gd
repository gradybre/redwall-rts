extends "res://test/underground_paid_assembly_case.gd"
## The entry foreman's progress record through the hauled prefix: exact restores and exact refusals of corrupt or
## stale records (fixture: underground_paid_assembly_case.gd; decision 2044, CI time).


func test_entry_progress_restores_exactly_through_the_hauled_prefix() -> void:
	"""ADR1218 (G10): the hauled prefix runs uninterrupted, then again with the foreman captured and replaced by a
	fresh restore every RESTORE_EVERY ticks, and (ADR1221) Routes and WorldRoutes captured, blanked as a fresh
	Session's and cold-restored every ROUTE_RESTORE_EVERY ticks. Every stage of the foreman, installer and hauler is
	crossed, and the final owner ledgers, route images, the finishing tick and the terminal record are
	byte-identical to the uninterrupted run."""
	var started: int = Time.get_ticks_usec()
	var plain: Array[PackedByteArray] = _hauled_run(0, PackedInt64Array([0, 0, 0, 0]))
	if plain.is_empty(): return
	after_each()
	var middle: int = Time.get_ticks_usec()
	var seen: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	var restored: Array[PackedByteArray] = _hauled_run(RESTORE_EVERY, seen)
	if restored.is_empty(): return
	var spans: PackedInt64Array = PackedInt64Array([middle - started, Time.get_ticks_usec() - middle])
	print("ENTRY-PROGRESS restores=%d foreman_stages=%x installer_stages=%x hauler_stages=%x plain_us=%d restored_us=%d"
		% [seen[3], seen[0], seen[1], seen[2], spans[0], spans[1]])
	for index: int in plain.size():
		assert_equal(restored[index], plain[index], "ledger image %d is byte-identical after restores" % index)
	_assert_stages_seen(seen)


func test_entry_progress_refuses_every_corrupt_or_stale_record_exactly() -> void:
	"""ADR1218: a record captured mid-haul inside the L0 installation restores; every corruption or stale handle is
	refused with its exact code, the refused foreman holds that code, and no owner changes."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman(true)
	if foreman == null: return
	var tick: int = _probe._tick
	while foreman.error() == &"" and tick < _probe._tick + 20000 and not (foreman._stage == Foreman.STAGE_INSTALL
			and foreman._installer._hauler != null and foreman._installer._hauler._stage == Hauler.STAGE_CARRY):
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman._stage, Foreman.STAGE_INSTALL, "paused inside an installation's haul")
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(foreman.capture(bytes), &"", "mid-haul capture")
	_assert_record_layout(foreman, bytes)
	var world: RefCounted = _probe._world
	var before: Array[PackedByteArray] = [world._inventory.state_bytes(), world._jobs.state_bytes(),
		world._construction.state_bytes(), world._pool.state_bytes()]
	for case: Array in _corruptions(bytes):
		_expect_refusal(foreman, case[0], case[1], case[2])
	_expect_owner_refusals(foreman, bytes)
	assert_equal([world._inventory.state_bytes(), world._jobs.state_bytes(), world._construction.state_bytes(),
		world._pool.state_bytes()], before, "no refused restore touched an owner")
	var fresh: Foreman = Foreman.new()
	assert_equal(fresh.restore(bytes, foreman._owners, foreman._paid), &"", "the intact record still restores")
	assert_equal(fresh.restore(bytes, foreman._owners, foreman._paid), Progress.REFUSE_TARGET, "only into a fresh foreman")
