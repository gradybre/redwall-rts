extends "res://test/underground_host_case.gd"
## Decision 2046 (P-2054-2 (a), Brendan 2026-10-22; decision 2054 B3, decision 2092 §2): the flight's foot F'(5) is
## published with air widened by the ground carry rows (32 wood, 37 stone): an envelope over their grounded boxes and
## the retreat 47's, and one extra air box (ADR 1215) over their raised load. From the committed underground_flight
## finish checkpoint, a CARRY span from F'(5) straight on to the level-1 store's yaw-0 stand (50 u past it, decision
## 2054 E2) is admitted by WorldRoutes' own seal. Clearance against every installed part is
## `test_landing_clearance.py`'s (`test_the_foot_air_holds_both_carry_rows_and_clears_every_part`).

const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const EntryBindings := preload("res://scripts/core/underground_entry_bindings.gd")
const Space := preload("res://scripts/core/room_space.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CARRY_ROWS: PackedInt32Array = [32, 37]
const RETREAT_ROW: int = 47
## F'(5) in the stair top's frame (the stair path's own classification) and the stand 50 u past it.
const FOOT: Vector3i = Vector3i(0, -5120, -26798)
const STAND_PAST: int = 50 # As `test_landing_clearance.py`'s STAND_PAST_FP.


func _record() -> Locations.Record:
	"""An empty Location packet of the fixed shape."""
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	return record


func _stop(o: Session.Retirement.Owners, local: Vector3i, out: Locations.Record) -> Vector2i:
	"""The live Location at the entry's source-local point, read into `out`; NULL_REF when none."""
	var origin: Vector3i = _host.underground_entry().origin()
	for row: int in o.locations._capacity:
		if o.locations._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, o.locations._live.i32[Locations.GENERATION * o.locations._capacity + row])
		if o.locations.read_location_into(ref, out) == &"" and out.point == origin + local: return ref
	return NULL_REF


func _boxes(o: Session.Retirement.Owners, row: int, roles: PackedInt32Array) -> Array[PackedInt32Array]:
	"""The row's boxes of the given roles, relative to its root."""
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	var box: Profiles.Box = Profiles.Box.new()
	var out: Array[PackedInt32Array] = []
	var content: int = o.profiles.content_revision()
	assert_equal(o.profiles.descriptor_into(row, content, d), &"", "row %d" % row)
	for ordinal: int in d.box_count:
		o.profiles.box_into(row, d.profile_revision, content, ordinal, box)
		if box.role in roles:
			out.append(PackedInt32Array([box.low.x, box.low.y, box.low.z, box.high.x, box.high.y, box.high.z]))
	return out


func _relative(box: PackedInt32Array, at: Vector3i) -> PackedInt32Array:
	"""A world box relative to a point."""
	return PackedInt32Array([box[0] - at.x, box[1] - at.y, box[2] - at.z, box[3] - at.x, box[4] - at.y, box[5] - at.z])


func _bodies_held(o: Session.Retirement.Owners, row: int, record: Locations.Record) -> bool:
	"""Every BODY/TURN box of the row standing at the record's point, above its floor, lies in the envelope or in one
	extra air box (WorldRoutes' endpoint body test, `Locations.air_contains`)."""
	var probe: Locations.Record = _record()
	probe.envelope = record.envelope
	probe.air_count = record.air_count
	probe.air = record.air
	for box: PackedInt32Array in _boxes(o, row, PackedInt32Array([Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY])):
		var placed: PackedInt32Array = PackedInt32Array([record.point.x + box[0], maxi(record.point.y + box[1],
			record.point.y), record.point.z + box[2], record.point.x + box[3], record.point.y + box[4],
			record.point.z + box[5]])
		if placed[1] >= placed[4]: continue
		if not Locations.air_contains(probe, placed): return false
	return true


func test_the_foot_is_published_with_the_carry_rows_air() -> void:
	"""At the finish, F'(5) holds the envelope over the grounded carry boxes and 47's, one extra box over the raised
	load, and the carry rows' footing; every carry body fits it. Air sized by 47 alone, as M5 published it before,
	holds neither carry row (decision 2054 B3); the other landings' F' keep their single box."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var foot: Locations.Record = _record()
	assert_true(_stop(o, FOOT, foot) != NULL_REF, "F'(5) is live at the finish")
	assert_equal(StairPath.classify(FOOT), Vector2i(StairPath.KIND_FP, StairPath.MODULES), "the stair path's F'(5)")
	assert_equal(_relative(foot.envelope, foot.point), PackedInt32Array([-679, 0, -679, 679, 937, 679]), "envelope")
	assert_equal(foot.air_count, 1, "one extra air box")
	assert_equal(_relative(foot.air.slice(0, 6), foot.point), PackedInt32Array([-714, 447, -714, 714, 821, 714]),
		"over the raised load")
	assert_equal(_relative(foot.support, foot.point), PackedInt32Array([-375, -1, -375, 375, 0, 375]), "footing")
	for row: int in CARRY_ROWS:
		assert_true(_bodies_held(o, row, foot), "carry row %d's bodies fit F'(5)'s air" % row)
		assert_equal(Grip.carry_of(CARRY_ROWS.find(row)), row, "the grip family's carry row")
	var narrow: Locations.Record = _record()
	var retreat: Array[PackedInt32Array] = _boxes(o, RETREAT_ROW, PackedInt32Array([Profiles.BODY_HELD_LOAD]))
	narrow.point = foot.point
	for axis: int in 6: narrow.envelope[axis] = int(foot.point[axis % 3]) + retreat[0][axis]
	for row: int in CARRY_ROWS:
		assert_false(_bodies_held(o, row, narrow), "47's air alone does not hold carry row %d" % row)
	for landing: int in range(1, StairPath.MODULES):
		var other: Locations.Record = _record()
		var local: Vector3i = FOOT + Vector3i(0, 1024 * (StairPath.MODULES - landing), 5120 * (StairPath.MODULES - landing))
		assert_true(_stop(o, local, other) != NULL_REF, "landing %d's F' is live" % landing)
		assert_equal(other.air_count, 0, "landing %d's F' keeps one box" % landing)


func _stand(o: Session.Retirement.Owners, foot: Locations.Record) -> Vector2i:
	"""The level-1 store's yaw-0 grip stand 50 u past F'(5) (decision 2054 E2), a WORK endpoint in the run-out's floor
	air with the ground rows' footing, published through Locations' own staging; NULL_REF when refused."""
	var stand: Locations.Record = _record()
	stand.point = foot.point + Vector3i(0, 0, -STAND_PAST)
	stand.section = foot.section; stand.room = foot.room; stand.level = foot.level
	stand.role = Locations.ROLE_WORK
	var wall: int = _host.underground_entry().origin().z + Flight.layout_end_wall_z(Flight.LAYOUT_M5)
	var open: PackedInt32Array = PackedInt32Array([foot.point.x - Flight.HALF_WIDTH, foot.point.y, wall,
		foot.point.x + Flight.HALF_WIDTH, foot.point.y + Flight.QUANTUM, wall + Flight.RUN_OUT])
	for axis: int in 6: stand.envelope[axis] = open[axis]
	stand.support = PackedInt32Array([stand.point.x - 406, stand.point.y - 1, stand.point.z - 406, stand.point.x + 406,
		stand.point.y, stand.point.z + 406])
	var cold: int = o.budget.acquire(Budget.COLD_BYTES)
	var started: Locations.Result = o.locations.begin_prepare(cold)
	var added: Locations.Result = o.locations.stage_add(started.token, stand)
	var published: bool = added.error == &"" and o.locations.seal(started.token) == &"" \
		and o.locations.publish(started.token)
	if not published: o.locations.abort(started.token)
	o.budget.release(cold)
	return added.location if published else NULL_REF


func _span(o: Session.Retirement.Owners, foot: Locations.Record, from: Vector2i, to: Vector2i, mode: int) -> StringName:
	"""One straight ground span down the flight, staged, sealed (WorldRoutes certifies its rows) and published."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = from; edge.to_location = to
	edge.section = foot.section; edge.room = foot.room; edge.level = foot.level
	edge.family = -1; edge.variant = 0; edge.rotation = 0
	edge.mode = mode; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = o.profiles.content_revision(); edge.geometry_revision = o.space.revision()
	edge.point_count = 2
	edge.points = PackedInt32Array([foot.point.x, foot.point.y, foot.point.z, foot.point.x, foot.point.y,
		foot.point.z - STAND_PAST])
	edge.length_u = STAND_PAST
	var lease: int = o.budget.acquire(Budget.COLD_BYTES)
	var begun: Routes.Result = o.world_routes.begin_prepare(lease)
	var code: StringName = begun.error
	if code == &"": code = o.routes.stage_add(begun.token, edge).error
	if code == &"": code = o.world_routes.seal(begun.token)
	if code == &"": code = o.world_routes.publish(begun.token)
	if begun.token != 0: o.world_routes.abort(begun.token)
	o.budget.release(lease)
	return code


func test_a_carry_span_from_the_foot_to_the_level_one_stand_is_admitted() -> void:
	"""P-2091-7 (a) as refined by decision 2092 §2.2: with the widened air, the loaded span F'(5) -> the store's yaw-0
	stand, straight on down the flight, is certified and published (D2 publishes it at bind; the probe of decision
	2054 found it refused WORLD_ROUTE_NO_FITTING_PROFILE); the empty walk the same way too."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var foot: Locations.Record = _record()
	var fp: Vector2i = _stop(o, FOOT, foot)
	assert_true(fp != NULL_REF, "F'(5)")
	var stand: Vector2i = _stand(o, foot)
	assert_true(stand != NULL_REF, "the stand is published")
	assert_equal(_span(o, foot, fp, stand, Profiles.MODE_CARRY), &"", "the CARRY span is admitted")
	assert_equal(_span(o, foot, fp, stand, Profiles.MODE_WALK), &"", "and the empty WALK")


func _extra_air_refusal(o: Session.Retirement.Owners, foot: Locations.Record, shift: Vector3i) -> StringName:
	"""The entry provider's own proof of F'(5)'s extra air box (`_timber_extra_air_box`, its staging pass, which reads
	the Space's staged copy: a stage begun on the live Space and aborted after), with the box moved by `shift`."""
	var bindings: EntryBindings = o.room_bindings as EntryBindings
	var contact: Locations.Record = bindings._entry_contact
	contact.point = foot.point
	contact.air_count = foot.air_count
	for axis: int in 6: contact.air[axis] = foot.air[axis] + shift[axis % 3]
	var proof: EntryBindings.TimberClearance = EntryBindings.TimberClearance.new()
	proof.allocate_rows(o.space._region_capacity, Space.MAX_CHECKS)
	bindings._timber_placement = _host.underground_entry()._foreman._placement
	var begun: Owner.Result = o.space.begin_stage(o.space.revision())
	assert_equal(begun.error, &"", "a Space stage over the live Space")
	var code: StringName = bindings._timber_extra_air_box(proof, begun.token, true)
	assert_true(o.space.abort(begun.token), "aborted")
	bindings._timber_placement = NULL_REF
	return code


func test_the_extra_air_box_must_lie_in_completed_void() -> void:
	"""Review M2: F'(5)'s extra box as published passes the provider's proof; moved down into the uncut earth under
	level 1's floor (no completed void) or onto the last sill's deck (installed SOLID) it refuses
	ENTRY_INSTALLED_CONTACT_REQUIRED; a single-box endpoint proves nothing here. Locations proves the box again on its
	own rule (ADR 1215), which is the authority."""
	var done: Array = _finished_entry()
	if done.is_empty(): return
	var o: Session.Retirement.Owners = done[0]
	var foot: Locations.Record = _record()
	assert_true(_stop(o, FOOT, foot) != NULL_REF, "F'(5)")
	assert_equal(_extra_air_refusal(o, foot, Vector3i.ZERO), &"", "the published box is completed void")
	assert_equal(_extra_air_refusal(o, foot, Vector3i(0, -Flight.QUANTUM, 0)), EntryBindings.REFUSE_TIMBER_CONTACT,
		"under the floor: uncut earth")
	assert_equal(_extra_air_refusal(o, foot, Vector3i(0, -380, 600)), EntryBindings.REFUSE_TIMBER_CONTACT,
		"lowered onto the last sill's deck, still above the floor")
	assert_equal(_extra_air_refusal(o, foot, Vector3i(0, -2 * Flight.QUANTUM, 0)), EntryBindings.REFUSE_TIMBER_CONTACT,
		"deep in natural earth, where no Region lies: nothing covers it")
	foot.air_count = 0
	assert_equal(_extra_air_refusal(o, foot, Vector3i(0, -Flight.QUANTUM, 0)), &"", "no extra box, nothing proved")
