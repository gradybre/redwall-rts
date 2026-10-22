extends "res://test/underground_host_case.gd"
## Decision 2046 (P-2054-1 (a), Brendan 2026-10-22; decision 2054 B1): when the M5 entry finishes, the two scopes its
## last paid operation left open are closed, Contacts' retained observation (`_valid`) and the entry provider's timber
## scope (`_timber_token`), so the Session stops reporting WORLD_RETIREMENT_BUSY and a painted room can be ordered:
## from the committed underground_flight finish checkpoint the host's room order reaches the way-in seam and is
## refused only there (ROOM_DIG_NO_WAY_IN, slice D2's to fill), with no null borrow (the host once crashed on
## `room_orders()` while the Session was busy). The live finishing tick is held by test_underground_flight_22.gd.

const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const EntryBindings := preload("res://scripts/core/underground_entry_bindings.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const BUSY: StringName = &"WORLD_RETIREMENT_BUSY"
## A lease number no operation holds: the stale scope decision 2054 found.
const STALE_LEASE: int = 977


func _painted() -> Confirm.Painted:
	"""A 2 x 2 Kitchen painted on level 1 (as test_underground_room_confirm_host.gd paints it), the first idle mole."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1
	painted.room_type = Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(40960, -4608, 40960)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = 4096
	return painted


func _bindings(o: Session.Retirement.Owners) -> EntryBindings:
	"""The entry provider, as the Placement's authority holds it."""
	var authority: EntryBindings.AdmissionAuthority = o.placements._actual_authority() as EntryBindings.AdmissionAuthority
	assert_not_null(authority, "the Placement's authority is the entry provider's")
	var bindings: EntryBindings = authority.host.get_ref() as EntryBindings if authority != null else null
	assert_true(bindings != null and bindings == o.room_bindings, "the Session's room bindings")
	return bindings


func test_the_finished_session_is_quiescent_and_a_room_order_reaches_the_way_in() -> void:
	"""At the finish both scopes are closed; the Session lends its RoomOrders, and the host's order of a painted
	level-1 room is refused only by the way-in seam (nothing admitted, nothing recorded)."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var entry: Settlement.UndergroundEntryRuntime = done[1]
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_DONE, "the entry is done")
	assert_false(o.contacts._valid, "Contacts holds no retained scope (saved: the finish point saves it closed)")
	assert_not_null(_bindings(o), "the provider (its timber scope is not saved: test_underground_flight_22.gd checks it live)")
	assert_equal(_host.underground_session().current_refusal(), &"", "the Session is quiescent")
	assert_not_null(_host.underground_session().room_orders(), "it lends its RoomOrders")
	var rooms: int = _host.underground_session().room_orders().buildings_owner().live_room_count()
	var result: Confirm.Result = _host.order_painted_room(_painted())
	assert_equal(result.code, Confirm.REFUSE_NO_WAY_IN, "refused only for the way in (slice D2's seam)")
	assert_false(result.admitted, "not admitted")
	assert_equal(_host.underground_session().room_orders().buildings_owner().live_room_count(), rooms, "no room")


func test_either_scope_left_open_keeps_the_session_busy_until_the_finish_closes_it() -> void:
	"""Decision 2054 B1 reproduced on the finished entry: a timber scope no operation holds, or Contacts' last valid
	observation, keeps the Session WORLD_RETIREMENT_BUSY and lends no RoomOrders; the foreman's close at the finish
	clears each, and a second close is a no-op."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var entry: Settlement.UndergroundEntryRuntime = done[1]
	var session: Session = _host.underground_session()
	var bindings: EntryBindings = _bindings(o)
	bindings._timber_token = STALE_LEASE
	bindings._timber_assembly = 35
	assert_equal(session.current_refusal(), BUSY, "a stale timber scope: busy")
	assert_null(session.room_orders(), "no RoomOrders lent")
	assert_equal(entry._foreman.close_finished_scopes(), &"", "closed")
	assert_equal([bindings._timber_token, bindings._timber_assembly], [0, -1], "the scope is discarded")
	assert_equal(session.current_refusal(), &"", "quiescent again")
	o.contacts._valid = true
	assert_true(session.current_refusal() != &"", "Contacts' retained observation: busy")
	assert_equal(entry._foreman.close_finished_scopes(), &"", "closed")
	assert_false(o.contacts._valid, "dropped")
	assert_equal(session.current_refusal(), &"", "quiescent")
	assert_equal(entry._foreman.close_finished_scopes(), &"", "a second close changes nothing")


func test_nothing_is_closed_while_an_operation_still_holds_it() -> void:
	"""The close refuses, leaving the scope, while the Placement is prepared on the scope's own lease, while a proof
	reads, while Contacts proves or a phase holds its leases, and before every installation has settled."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var foreman: Foreman = done[1]._foreman
	var bindings: EntryBindings = _bindings(o)
	bindings._timber_token = STALE_LEASE
	o.placements._cold_token = STALE_LEASE
	assert_equal(bindings._close_finished_timber(), EntryBindings.REFUSE_ENTRY_COLD, "the lease is still prepared")
	o.placements._cold_token = 0
	bindings._reading = true
	assert_equal(bindings._close_finished_timber(), EntryBindings.REFUSE_MASK_BUSY, "a proof is reading")
	bindings._reading = false
	assert_equal(bindings._timber_token, STALE_LEASE, "kept while refused")
	o.contacts._valid = true
	o.contacts._busy = true
	assert_equal(o.contacts.close_finished_scope(), Contacts.REFUSE_REENTRY, "Contacts is proving")
	o.contacts._busy = false
	for field: String in ["_phase_space_token", "_phase_companion_token"]:
		o.contacts.set(field, STALE_LEASE)
		assert_equal(o.contacts.close_finished_scope(), Contacts.REFUSE_SCOPE, "%s held" % field)
		o.contacts.set(field, 0)
	assert_true(o.contacts._valid, "kept while refused")
	foreman._stage = Foreman.STAGE_TRAVEL
	assert_equal(foreman.close_finished_scopes(), Foreman.REFUSE_STATE, "a stage still running")
	foreman._stage = Foreman.STAGE_DONE
	foreman._install_count -= 1
	assert_equal(foreman.close_finished_scopes(), Foreman.REFUSE_STATE, "an installation not yet planned")
	foreman._install_count += 1
	assert_equal(foreman.close_finished_scopes(), &"", "then both close")
	assert_true(bindings._timber_token == 0 and not o.contacts._valid, "both closed")
