extends "res://test/framework/test_case.gd"
## Historical published source geometry only. The current production Catalog must still refuse source drift.
## No profile flag, motion box, paid state, runtime source pin or renderer qualification is fabricated here.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Published := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Pins := preload("res://data/underground/mole-worker/profile-publication-v1/catalog_source.gd")
const Entry := preload("res://scripts/core/underground_entry_bindings.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const LocationFixture := preload("res://test/test_underground_locations.gd")
const SurfaceFixture := preload("res://test/test_underground_surface_anchor.gd")
# Retain all exact cached consumers so production drift is distinguished from an absent cached Script.
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")

class Bounds extends Entry:
	## Unit selector names an immutable row only; it supplies no physical or source-binding success hook.
	var selected_profile: int = 1

	func _timber_profile(_endpoint: int) -> int:
		"""Exercise the production profile-box and below-plane helpers without inventing a Frontier permission."""
		return selected_profile

var _profiles: Profiles = null
var _bounds: Bounds = null
var _local: LocationFixture = null
var _surface: SurfaceFixture = null


func before_each() -> void:
	"""Read the unchanged accepted wire through the actual loader, separately from current runtime closure."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(18, 194, 1, Published.PAIRED_BANK_BYTES + Published.CONTROL_RESERVE), &"", "exact finite source bank")
	assert_equal(FileAccess.get_sha256(Published.WIRE_PATH), Pins.WIRE_SHA, "immutable historical publication")
	assert_equal(_profiles.load_file(Published.WIRE_PATH, Pins.WIRE_SHA, 1), &"", "actual unchanged profile wire")
	assert_equal(Published.catalog_refusal(_profiles), &"", "all published rows, boxes and flags still exact")
	_bounds = Bounds.new()
	_bounds._entry_placements = Placements.new()
	_bounds._entry_placements._profiles = _profiles
	_bounds._entry_contact.envelope.resize(6)
	_bounds._entry_contact.support.resize(6)


func after_each() -> void:
	"""Release fixture-owned stores and propagate actual owner assertions; no shared source is changed."""
	if _local != null:
		_local.after_each()
		assert_true(_local.failures.is_empty(), "actual Location fixture: %s" % _local.failures)
	if _surface != null:
		_surface.after_each()
		assert_true(_surface.failures.is_empty(), "actual generated World fixture: %s" % _surface.failures)
	_local = null
	_surface = null
	_bounds = null
	_profiles = null


func _record(profile: int = 1, point: Vector3i = Vector3i.ZERO) -> Locations.Record:
	"""Production derivation consumes the exact historical row; this alone publishes no endpoint or movement."""
	_bounds.selected_profile = profile
	_bounds._entry_contact.point = point
	_bounds._entry_checks = Space.MAX_CHECKS
	assert_equal(_bounds._timber_profile_envelope(0), &"", "full source footprint and air")
	var record: Locations.Record = Locations.Record.new()
	record.point = point
	record.level = 0
	record.role = Locations.ROLE_WORK
	record.envelope = _bounds._entry_contact.envelope.duplicate()
	record.support = _bounds._entry_contact.support.duplicate()
	return record


func _put(token: int, box: PackedInt32Array, role: int) -> Vector2i:
	"""Actual finite sparse rows are explicit geometry fixtures, never a paid excavation or installed prefix."""
	var row: Owner.Region = Owner.Region.new()
	row.box = box
	row.role = role
	row.owner = _local._world
	row.level = 0
	var added: Owner.Result = _local._owner.stage_add(token, row)
	assert_equal(added.error, &"", "actual bounded geometry")
	return added.handle


func _geometry(record: Locations.Record, footing: Array[PackedInt32Array], air: PackedInt32Array) -> void:
	"""Keep floor metadata at the exact foot footprint, with full separate physical air/support coverage."""
	_local = LocationFixture.new()
	_local.before_each()
	var token: int = _local._owner.begin_stage(_local._owner.revision()).token
	for ref: Vector2i in [_local._floor_ref, _local._void_ref, _local._support_ref]:
		assert_equal(_local._owner.stage_remove(token, ref), &"", "replace only explicit fixture rows")
	var datum: PackedInt32Array = record.support.duplicate()
	datum[1] = record.point.y
	datum[4] = record.point.y + 1
	record.section = _put(token, datum, Space.FLOOR_DATUM)
	_put(token, air, Space.SUPPORTED_VOID)
	for box: PackedInt32Array in footing: _put(token, box, Space.SUPPORT)
	assert_equal(_local._owner.seal(token), &"", "actual sparse geometry sealed")
	_local._owner.publish(token)


func test_exact_published_ground_stance_does_not_expand_to_tool_air() -> void:
	"""The812u stance and2512u held-tool air remain independently complete, including below-plane residuals."""
	var record: Locations.Record = _record()
	assert_equal(record.support, PackedInt32Array([-406, -1, -406, 406, 0, 406]), "exact published stance")
	assert_equal(record.envelope, PackedInt32Array([-1256, 0, -1256, 1256, 1036, 1256]), "whole body and held-tool air")
	var proof: Entry.TimberClearance = Entry.TimberClearance.new()
	proof.allocate_rows(64, Space.MAX_CHECKS)
	assert_equal(_bounds._timber_profile_foot(proof, 0), &"", "all authored below-plane body/turn residual in stance")
	_geometry(record, [record.support], record.envelope)
	for role: int in [Locations.ROLE_TRANSIT, Locations.ROLE_STORAGE, Locations.ROLE_WORK]:
		record.role = role
		assert_equal(_local._endpoint_refusal(record), &"", "complete air may overhang the real supported footprint")
	var ref: Vector2i = _local._add(record)
	assert_true(_local._locations.is_live_location(ref), "actual endpoint publication")
	var image: PackedByteArray = _local._image()
	var cold: int = _local._cold.acquire(LocationFixture.COLD_BYTES)
	assert_equal(_local._locations.restore_state_bytes(cold, image), &"", "same independent boxes survive actual restore")
	assert_equal(_local._cold.release(cold), &"", "restore releases only owned scratch")
	record.section.y += 1
	assert_equal(_local._endpoint_refusal(record), &"LOCATION_SECTION_STALE", "same-number stale section cannot borrow overhang")
	assert_true(_local._locations.is_live_location(ref), "original full endpoint remains live after refusal")


func test_real_512u_tread_cannot_borrow_body_only_air() -> void:
	"""The unchanged812u stance fails over an actual512u support even though all body air is present."""
	var record: Locations.Record = _record()
	var tread: PackedInt32Array = PackedInt32Array([-1024, -1, -256, 1024, 0, 256])
	_geometry(record, [tread], record.envelope)
	assert_equal(_local._endpoint_refusal(record), &"LOCATION_COVERAGE_MISSING", "no fractional-height or adjacent-air footing")
	assert_equal(_local._locations._live.count, 0, "refusal creates no endpoint")


func test_one_unit_interior_footing_gap_remains_a_real_support_failure() -> void:
	"""Complete body air cannot cover a missing interval within the exact source stance."""
	var record: Locations.Record = _record()
	var left: PackedInt32Array = record.support.duplicate()
	var right: PackedInt32Array = record.support.duplicate()
	left[3] = 0
	right[0] = 1
	_geometry(record, [left, right], record.envelope)
	assert_equal(_local._endpoint_refusal(record), &"LOCATION_COVERAGE_MISSING", "interior hole is not sampled away")


func test_complete_stance_still_requires_every_unit_of_overhanging_air() -> void:
	"""A missing outer air strip is not hidden by a complete central foot support box."""
	var record: Locations.Record = _record()
	var air: PackedInt32Array = record.envelope.duplicate()
	air[3] -= 1
	_geometry(record, [record.support], air)
	assert_equal(_local._endpoint_refusal(record), &"LOCATION_COVERAGE_MISSING", "whole held-tool envelope remains mandatory")


func test_obstacle_in_overhanging_tool_air_refuses_without_changing_footing() -> void:
	"""An actual retained solid outside the stance but inside the full source air still blocks the endpoint."""
	var record: Locations.Record = _record()
	_geometry(record, [record.support], record.envelope)
	var token: int = _local._owner.begin_stage(_local._owner.revision()).token
	_put(token, PackedInt32Array([1254, 400, -1, 1256, 500, 1]), Space.OBSTACLE)
	assert_equal(_local._owner.seal(token), &"", "real outer obstacle")
	_local._owner.publish(token)
	assert_equal(_local._endpoint_refusal(record), &"LOCATION_ENVELOPE_BLOCKED", "no tool-air clipping")


func test_exact_install_stance_keeps_raised_contact_and_full_air_separate() -> void:
	"""Historical INSTALL geometry retains its actual128u contact; this change grants no WIP target permission."""
	var record: Locations.Record = _record(5)
	assert_equal(record.support, PackedInt32Array([-274, -1, -169, 299, 0, 174]), "573 by343 source stance")
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	assert_equal(_profiles.descriptor_into(5, 1, descriptor), &"", "exact immutable INSTALL row")
	var box: Profiles.Box = Profiles.Box.new()
	var contacts: int = 0
	for ordinal: int in descriptor.box_count:
		assert_equal(_profiles.box_into(5, 1, 1, ordinal, box), &"", "complete published source box")
		if box.role != Profiles.CONTACT_POINT: continue
		contacts += 1
		assert_equal(box.low.y, 128, "raised contact cannot be projected to the floor")
	assert_equal(contacts, 1, "exact source contact retained")
	assert_true(record.envelope[0] < record.support[0] and record.envelope[2] < record.support[2], "tool/approach air retains overhang")
	_bounds._entry_checks = 0
	assert_equal(_bounds._timber_profile_envelope(0), Entry.REFUSE_MASK_BUDGET, "finite source work refuses explicitly")


func test_actual_natural_anchor_proves_published_air_and_stance_independently() -> void:
	"""Generated terrain establishes real surface footing and full exterior without any Room or paid-air Site."""
	_surface = SurfaceFixture.new()
	_surface._setup()
	var point: Vector3i = Vector3i(SurfaceFixture.X + 1024, 512, SurfaceFixture.Z + 1024)
	var record: Locations.Record = _record(1, point)
	var made: SurfaceFixture.Anchor.Result = _surface._anchor.create(point, record.envelope, record.support)
	assert_equal(made.error, &"", "real broad exterior above independently narrow natural support")
	if made.error != &"": return
	var actual: Locations.Record = _surface._record(made.location)
	assert_equal(actual.envelope, record.envelope, "all source air published unchanged")
	assert_equal(actual.support, record.support, "only source stance protected as natural support")
	var datum: Owner.Region = Owner.Region.new()
	datum.box.resize(6)
	assert_equal(_surface._actual._owner.region_into_reused(made.section, datum), &"", "actual full floor")
	assert_equal(datum.box[0], record.support[0], "metadata follows footing, not held tool")
	assert_equal(datum.box[3], record.support[3], "no body-only floor extension")


func test_historical_geometry_input_cannot_reopen_current_production_catalog() -> void:
	"""Source-qualified historical boxes are useful test inputs, not current consumer or native-backend approval."""
	assert_equal(Published.runtime_sources_refusal(), &"MOLE_CATALOG_SOURCE_DRIFT", "current changed consumer remains closed")
	assert_equal(Published.catalog_refusal(_profiles), &"", "the original artifact was never rewritten")


func test_late_actual_tree_in_tool_overhang_refuses_before_surface_publication() -> void:
	"""A last observer adds real excluded matter outside the feet but inside air; no narrow-foot shortcut hides it."""
	_surface = SurfaceFixture.new()
	_surface._setup()
	var point: Vector3i = Vector3i(SurfaceFixture.X + 1024, 512, SurfaceFixture.Z + 1024)
	var record: Locations.Record = _record(1, point)
	var before: PackedByteArray = _surface._actual._owner.state_bytes()
	var observed: SurfaceFixture.WatchedLocations = _surface._actual._locations as SurfaceFixture.WatchedLocations
	observed.probe = func() -> void:
		var made: SurfaceFixture.Fixture.Nodes.OpResult = _surface._actual._nodes.create_at_tile(50 * 128 + 61,
			_surface._actual._items.compiled_id(&"wood"), 1000, 4, 1)
		assert_true(made.ok, "actual neighboring tree appears after ordinary observation")
	var result: SurfaceFixture.Anchor.Result = _surface._anchor.create(point, record.envelope, record.support)
	assert_true(result.error != &"", "complete final air exclusion refuses the late tree")
	assert_equal(observed.fired, 1, "last actual Location observer ran")
	assert_equal(_surface._actual._owner.state_bytes(), before, "no Space swap before final facts")
	assert_equal(_surface._actual._locations._live.count, 0, "no endpoint swap before final facts")
