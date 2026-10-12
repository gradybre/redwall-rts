extends "res://test/underground_host_case.gd"
## The live entry chain with its crew lost in each installation stage, plain and restored. Split from
## test_underground_host.gd so CI can shard it apart (decision 1243); fixture: underground_host_case.gd. Each loss
## starts from the committed underground_spare checkpoint at its stage instead of replaying the chain from tick 1
## (decision 1895): the tests assert what follows the loss, not the path to it.


func _lose_and_resume(at: Array, restore_every: int) -> Array:
	"""Load the chain with its crew in installer stage `at`, kill the crew; run to the finish (restoring the runtime
	every `restore_every` ticks when positive). Returns [finish tick, prefix done, DONE_LEDGER-shaped ledger...,
	owner images...]."""
	var live: Array = _spare_from_checkpoint(Recipes.loss_point(at))
	if live.is_empty(): return []
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var tick: int = live[4]
	assert_true(entry.is_running() and Recipes.installing_at(entry, at[0], at[1]), "reached installation %d stage %d" % at)
	_kill(o, live[2])
	assert_equal(entry.advance(tick), Jobs.REFUSE_RESIDENT_DEAD, "the loss is alerted once (stage %d)" % at[1])
	assert_true(entry.is_running() and entry.crew().worker == live[3], "the spare walks in (stage %d)" % at[1])
	assert_true(o.routes._lost_actor_row(live[2]) < 0, "the lost actor is unregistered")
	tick += 1
	while _host.underground_entry().is_running() and not _prefix_done(_host.underground_entry()) and tick < 12000:
		if restore_every > 0 and tick % restore_every == 0 and not _replace_entry_with_its_record(_host.underground_session(), tick):
			return []
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	return [tick, _prefix_done(_host.underground_entry())] + _done_ledger(o, _host.underground_entry()._foreman) + _snapshot()


func test_a_crew_lost_in_any_installation_stage_is_replaced_and_re_handles_in_place() -> void:
	"""DEC-057 (Brendan: re-handle in place): the crew dies in each installer stage it can rest in -- L0's haul,
	station approach, handling, INSTALL entry, fastening and recovery, and T0's split-landing arrival. The spare mole
	walks in, is registered on H, walks to M and on to the station; a funded order is revalidated with resume_work
	and the piece is handled again where it stands (or, already handled, goes straight to INSTALL). Every run reaches
	the end of the prefix with L0 and T0 each installed exactly once and no Work paid twice."""
	for at: Array in Recipes.LOSS_STAGES:
		var result: Array = _lose_and_resume(at, 0)
		if result.is_empty(): return
		assert_true(result[1], "lost in installation %d stage %d: finished the prefix" % at)
		assert_equal(result.slice(2, 7), DONE_LEDGER,
			"lost in installation %d stage %d: cut Work, both fastenings and INSTALLED exactly once" % at)
		after_each()
		before_each()


func test_a_crew_lost_while_handling_resumes_byte_identically_across_restores() -> void:
	"""DEC-057 persistence: lost mid-handling, run to the finish uninterrupted and again with the whole runtime replaced
	by its restored record every 7 ticks (the walk-in, the RESUME wait and the re-handling are all crossed); the finish
	and every owner image are byte-identical."""
	var plain: Array = _lose_and_resume([0, 4], 0)
	if plain.is_empty(): return
	after_each()
	before_each()
	var restored: Array = _lose_and_resume([0, 4], 7)
	if restored.is_empty(): return
	for index: int in plain.size():
		assert_equal(restored[index], plain[index], "image %d is byte-identical after restores" % index)
