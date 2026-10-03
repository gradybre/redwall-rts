extends "res://test/framework/test_case.gd"
## Actual Buildings/Construction/Directory identities; spatial extents are synthetic test surveys.
## These fixtures do not qualify profiles, underground Room registration, excavation or navigation.

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const ModularFixture := preload("res://test/test_modular_projects.gd")
const SparseSpace := preload("res://scripts/core/underground_space_owner.gd")
const PairFixture := preload("res://test/test_construction_furniture_batches.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")

const NULL_REF: Vector2i = Vector2i(-1, 0)
const R: int = 32
const O: int = 8


class BatchAuthority extends PairFixture.SyntheticAuthority:
	## Actual Router windows; only the room shell and fixture occupied boxes are synthetic.
	var attack_phase: int = 0
	var mutate_packet: bool = false
	var aborted: bool = false
	var rebegin_error: StringName = &""

	func furniture_candidates_refusal(room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> StringName:
		"""Adversarial callbacks cannot mutate the exact geometry transaction or rewrite its pinned request."""
		_attack(1, batch, entries)
		return super.furniture_candidates_refusal(room, batch, entries)

	func is_publishing_furniture_admissions(room: Vector2i, batch: Directory.CreateBatch) -> bool:
		"""Publication requires the actual Router bracket even when the fixture tries to reenter."""
		_attack(2, batch, PackedInt32Array())
		return super.is_publishing_furniture_admissions(room, batch)

	func _attack(phase: int, batch: Directory.CreateBatch, entries: PackedInt32Array) -> void:
		"""Only attack an active Space callback, not earlier actual Router/Buildings checks."""
		var target: AdmissionBatchOwner = batch_owner.get_ref() as AdmissionBatchOwner
		if attack_phase != phase or target == null or target.token == 0 or not target.geometry._room_callback:
			return
		if mutate_packet:
			if not entries.is_empty():
				entries[3] = (entries[3] + 1) % 4
			else:
				batch.persistent_ids[0] += 1
			return
		aborted = target.geometry.abort(target.token)
		rebegin_error = target.geometry.begin_stage(target.geometry.revision()).error
		target.geometry.publish(target.token)

class AdmissionBatchOwner extends PairFixture.SyntheticOwner:
	## Real mixed identity/accounting publication with actual future-source bridge.
	var geometry: SparseSpace = null
	var authority: WeakRef = null
	var floor_ref: Vector2i = NULL_REF
	var token: int = 0
	var refuse_after_seal: bool = false
	var skip_last: bool = false
	var region_role: int = Space.OBSTACLE
	var published_code: StringName = &""
	var after_drift: StringName = &""

	func stage_candidate(entries: PackedInt32Array) -> StringName:
		"""Pin the actual observation before any companion region, without allocating real identities."""
		var begun: SparseSpace.Result = geometry.begin_stage(geometry.revision())
		token = begun.token
		if begun.error != &"":
			return begun.error
		return geometry.stage_furniture_admissions(token, packet, room, entries, authority.get_ref())

	func add_candidate_regions() -> StringName:
		"""Use explicit separated test extents; these are not measured production furniture dimensions."""
		@warning_ignore("integer_division") var count: int = packet.count / 2
		for index: int in count - (1 if skip_last else 0):
			var piece: SparseSpace.Region = SparseSpace.Region.new()
			var x: int = entries_pin[index * 4 + 1] * 1024
			var z: int = entries_pin[index * 4 + 2] * 1024
			piece.box = PackedInt32Array([x, 0, z, x + 512, 512, z + 512])
			piece.role = region_role
			piece.level = 1
			piece.owner = packet.ref_at(index * 2)
			piece.section = floor_ref
			var result: SparseSpace.Result = geometry.stage_add(token, piece)
			if result.error != &"":
				return result.error
		return &""

	func furniture_batch_refusal(actual_room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> StringName:
		"""The actual Router cannot allocate one pair until the whole actual geometry image is sealed."""
		var code: StringName = super.furniture_batch_refusal(actual_room, batch, entries)
		if code == &"":
			code = stage_candidate(entries)
		if code == &"":
			code = add_candidate_regions()
		if code == &"":
			code = geometry.seal(token)
		if code == &"":
			code = geometry.prepared_refusal(token)
		return &"SYNTHETIC_BATCH_LATE_REFUSAL" if code == &"" and refuse_after_seal else code

	func publish_furniture_batch(actual_room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> void:
		"""The actual Router already published both real typed rows before this same-stack callback."""
		super.publish_furniture_batch(actual_room, batch, entries)
		var saved: int = _inject_after_drift(batch)
		published_code = geometry.publish_furniture_admissions(token, batch, actual_room, entries, authority.get_ref())
		_restore_after_drift(batch, saved)
		if published_code == &"":
			token = 0

	func _inject_after_drift(batch: Directory.CreateBatch) -> int:
		"""Test-only actual row corruption probes after-fact refusal; the original value is immediately restored."""
		if after_drift == &"":
			return 0
		var store: RefCounted = construction
		if after_drift.begins_with("_f_"):
			store = construction.buildings()
		var ref: Vector2i = batch.ref_at(0 if after_drift.begins_with("_f_") else 1)
		var row: int = construction.directory().get_typed_row(ref)
		var column: PackedInt32Array = store.get(after_drift)
		var old: int = column[row]
		column[row] += 1
		return old

	func _restore_after_drift(batch: Directory.CreateBatch, saved: int) -> void:
		"""Negative fixtures restore actual owner facts without pretending the rejected geometry published."""
		if after_drift == &"":
			return
		var store: RefCounted = construction
		if after_drift.begins_with("_f_"):
			store = construction.buildings()
		var ref: Vector2i = batch.ref_at(0 if after_drift.begins_with("_f_") else 1)
		var row: int = construction.directory().get_typed_row(ref)
		var column: PackedInt32Array = store.get(after_drift)
		column[row] = saved

	func discard_furniture_batch(actual_room: Vector2i, batch: Directory.CreateBatch) -> void:
		"""Abort only this exact geometry candidate before the caller can release its charged copies."""
		super.discard_furniture_batch(actual_room, batch)
		if token != 0:
			geometry.abort(token)
			token = 0

class AdmissionBatchHarness extends PairFixture:
	## Reuse actual paired allocation/accounting fixture with a real sparse source publication companion.
	func _bind_fixture() -> void:
		"""Keep exactly one actual Buildings authority and Furniture purpose owner in the real Router."""
		_authority = BatchAuthority.new()
		_authority.owner = weakref(_buildings)
		assert_true(_buildings.bind_spatial_authority(_authority).ok, "actual authority")
		_authority.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_KITCHEN)
		_room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN).ref
		_authority.allow(Buildings.SPATIAL_ROOM_VALID, _room, NULL_REF, 1)
		assert_true(_buildings.set_room_valid(_room, true).ok, "synthetic completed shell")
		_authority.reset()
		_authority.service_room = _room
		var fitting: AdmissionBatchOwner = AdmissionBatchOwner.new()
		_owner = fitting
		_owner.construction = _construction
		_owner.world = _world
		_owner.route = weakref(_router)
		_authority.batch_owner = weakref(_owner)
		fitting.authority = weakref(_authority)
		assert_true(_router.bind_owner(_owner).ok, "actual Furniture purpose")
		_geometry(fitting)

	func _geometry(fitting: AdmissionBatchOwner) -> void:
		"""Actual Room source/floor metadata only; no paid void, support or services are fabricated."""
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8),
			Vector3i(16, 16, 16), 64, 64, 100000), &"", "component domain")
		var sources: SparseSpace.CoreSources = SparseSpace.CoreSources.new(_construction.directory(), _buildings, _construction)
		fitting.geometry = SparseSpace.new(sources)
		assert_equal(fitting.geometry.configure(domain, 32, 16), &"", "actual sparse owner")
		var begun: SparseSpace.Result = fitting.geometry.begin_stage(1)
		assert_equal(fitting.geometry.stage_source(begun.token, _room), &"", "actual Room source")
		var floor_region: SparseSpace.Region = SparseSpace.Region.new()
		floor_region.box = PackedInt32Array([-8192, 0, -8192, 8192, 1, 8192])
		floor_region.role = Space.FLOOR_DATUM
		floor_region.level = 1
		floor_region.owner = _room
		var added: SparseSpace.Result = fitting.geometry.stage_add(begun.token, floor_region)
		assert_equal(added.error, &"", "actual Room datum")
		fitting.floor_ref = added.handle
		assert_equal(fitting.geometry.seal(begun.token), &"", "seal metadata")
		fitting.geometry.publish(begun.token)

	func batch_fitting() -> AdmissionBatchOwner:
		"""Typed borrowed fixture owner exposes assertions without any production dynamic calls."""
		return _owner as AdmissionBatchOwner


class InstallationOwner extends ModularFixture.SyntheticOwner:
	## Actual Router/Work/Inventory/Buildings; only contact/shape authoring is this explicit fixture.
	var geometry: SparseSpace = null
	var token: int = 0
	var refuse_after_seal: bool = false
	var before_install_refusal: StringName = &""
	var foreign_project_refusal: StringName = &""
	var foreign_owner_refusal: StringName = &""
	var published_refusal: StringName = &""

	func transition_refusal(candidate: Vector2i, action: int) -> StringName:
		"""All source preparation occurs in the actual Router's pre-payment completion check."""
		var code: StringName = super.transition_refusal(candidate, action)
		if code != &"" or action != ModularContract.COMMIT:
			return code
		var begun: SparseSpace.Result = geometry.begin_stage(geometry.revision())
		token = begun.token
		if begun.error != &"":
			return begun.error
		code = geometry.stage_furniture_install(token, candidate, route.get_ref(), self)
		if code == &"":
			code = geometry.seal(token)
		if code == &"" and refuse_after_seal:
			code = &"SYNTHETIC_INSTALLATION_REFUSAL"
		return code


	func discard_transition(candidate: Vector2i, action: int) -> void:
		"""Actual refusal drops the future source while retaining pending Furniture and all geometry."""
		if candidate == stage_project and action == ModularContract.COMMIT and token != 0:
			geometry.abort(token)
			token = 0
		super.discard_transition(candidate, action)


	func publish_completion(candidate: Vector2i) -> void:
		"""Observe exact source guards inside the real same-stack post-Inventory callback."""
		if not _authorized(candidate, ModularContract.COMMIT) or stage != ModularContract.COMMIT:
			return
		var router: ModularContract = route.get_ref() as ModularContract
		completion_saw_paid_clear = not funding.is_funded(candidate)
		before_install_refusal = geometry.publish_furniture_install(token, candidate, router, self)
		foreign_project_refusal = geometry.publish_furniture_install(token,
			Vector2i(candidate.x, candidate.y + 1), router, self)
		foreign_owner_refusal = geometry.publish_furniture_install(token, candidate, router, ModularContract.Owner.new())
		geometry.publish(token) # Generic publication cannot bypass the special actual installation check.
		assert(geometry.has_prepared(), "generic publication must leave the future installation staged")
		spatial.allow(Buildings.SPATIAL_FURNITURE_INSTALL, subject, NULL_REF)
		var installed: Buildings.OpResult = construction.buildings().install_spatial_furniture(subject)
		assert(installed.ok, "actual pending Furniture installs only after its bill and labor")
		spatial.reset()
		published_refusal = geometry.publish_furniture_install(token, candidate, router, self)
		assert(published_refusal == &"", "preflighted source publication must match actual installed facts")
		token = 0
		completed += 1
		retained = 0
		discard_transition(candidate, ModularContract.COMMIT)
		project = NULL_REF


class InstallationHarness extends ModularFixture:
	## Reuse reviewed actual payment/worker fixture helpers, carrying their assertion failures outward.
	func _new_owner() -> ModularFixture.SyntheticOwner:
		"""Both the tip fixture and later Furniture fixture use the exact actual Router object."""
		var owner: InstallationOwner = InstallationOwner.new()
		owner.construction = _construction
		owner.world = _world
		owner.route = weakref(_router)
		owner.funding = _funding
		return owner


	func furniture_with_geometry() -> InstallationOwner:
		"""Retain actual Room/Furniture identities with expressly synthetic component-test extents."""
		var fitting: InstallationOwner = _furniture_owner() as InstallationOwner
		var source: SparseSpace.CoreSources = SparseSpace.CoreSources.new(_construction.directory(),
			_construction.buildings(), _construction)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8),
			Vector3i(16, 16, 16), 64, 64, 100000), &"", "bounded installation fixture domain")
		fitting.geometry = SparseSpace.new(source)
		assert_equal(fitting.geometry.configure(domain, 16, 8), &"", "actual source owner")
		var room: Vector2i = _construction.buildings().room_ref_of_furniture(fitting.subject)
		var prepared: SparseSpace.Result = fitting.geometry.begin_stage(fitting.geometry.revision())
		assert_equal(fitting.geometry.stage_source(prepared.token, room), &"", "actual Room source")
		assert_equal(fitting.geometry.stage_source(prepared.token, fitting.subject), &"", "actual pending Furniture source")
		var floor_region: SparseSpace.Region = SparseSpace.Region.new()
		floor_region.box = PackedInt32Array([-2048, 0, -2048, 4096, 1, 4096])
		floor_region.role = Space.FLOOR_DATUM
		floor_region.level = 1
		floor_region.owner = room
		var added: SparseSpace.Result = fitting.geometry.stage_add(prepared.token, floor_region)
		assert_equal(added.error, &"", "actual Room floor identity")
		var piece: SparseSpace.Region = SparseSpace.Region.new()
		piece.box = PackedInt32Array([0, 0, 0, 1024, 1024, 1024])
		piece.role = Space.OBSTACLE
		piece.level = 1
		piece.owner = fitting.subject
		piece.section = added.handle
		assert_equal(fitting.geometry.stage_add(prepared.token, piece).error, &"", "retained pending fitting envelope")
		assert_equal(fitting.geometry.seal(prepared.token), &"", "strict actual before-facts")
		fitting.geometry.publish(prepared.token)
		return fitting

class SyntheticRoomCommands extends Buildings.SpatialAuthority:
	## Exact one-command test permit; production geometry and paid fitting installation are separate.
	var owner: WeakRef = null
	var action: int = -1
	var subject: Vector2i = NULL_REF
	var related: Vector2i = NULL_REF
	var value: int = 0
	var rotation: int = 0

	func buildings_owner() -> RefCounted:
		"""Return the actual store object, not a coincident Directory or numeric identity."""
		return owner.get_ref() if owner != null else null

	func mutation_refusal(next_action: int, next_subject: Vector2i, next_related: Vector2i,
			next_value: int, next_rotation: int) -> StringName:
		"""Only the precise operation explicitly arranged by this component test is allowed."""
		return &"" if next_action == action and next_subject == subject and next_related == related \
			and next_value == value and next_rotation == rotation else Buildings.REFUSE_SPATIAL_COMMAND

	func permit(next_action: int, next_subject: Vector2i, next_related: Vector2i,
			next_value: int = 0, next_rotation: int = 0) -> void:
		"""Keep every field explicit; a fixture does not publish an unscoped production permission."""
		action = next_action
		subject = next_subject
		related = next_related
		value = next_value
		rotation = next_rotation

class SyntheticAdmission extends Buildings.SpatialAuthority:
	## Actual identity publication; geometry/support/contact authoring remains an explicit component fixture.
	var owner: WeakRef = null
	var candidate: Directory.CreateCandidate = null
	var room_type: int = Buildings.ROOM_TYPE_KITCHEN
	var publishing: bool = false
	var admitted: bool = true
	var geometry: Owner = null
	var token: int = 0
	var attack_phase: int = 0
	var change_packet: bool = false
	var abort_succeeded: bool = false
	var rebegin_error: StringName = &""

	func buildings_owner() -> RefCounted:
		"""Attest the exact actual Buildings store without retaining a reference cycle."""
		_attack(3)
		return owner.get_ref() if owner != null else null

	func room_candidate_refusal(next: Directory.CreateCandidate, next_type: int) -> StringName:
		"""Attest only this retained packet and permanent purpose, without recursive Space validation."""
		_attack(1)
		return &"" if admitted and next == candidate and next_type == room_type else &"SYNTHETIC_ROOM_NOT_PREPARED"

	func is_publishing_room_admission(ref: Vector2i, next_type: int) -> bool:
		"""Explicit synthetic same-stack bracket; production confirmation must supply actual prepared proofs."""
		_attack(2)
		return publishing and candidate != null and ref == candidate.ref and next_type == room_type

	func _attack(phase: int) -> void:
		"""Adversarial test-only callback attempts must never steal or repurpose SpaceOwner's stage."""
		if attack_phase != phase or geometry == null:
			return
		if change_packet:
			candidate.persistent_id += 1
			return
		abort_succeeded = geometry.abort(token)
		rebegin_error = geometry.begin_stage(geometry.revision()).error
		geometry.publish(token)


class SyntheticSpatial extends Contract.SpatialAuthority:
	## Actual Rooms, but only synthetic geometry admission for claim-lifetime/identity tests.
	var buildings: Buildings = null
	var domain: Space.Domain = null

	func domain_into(out: Contract.Domain) -> bool:
		"""Copy an explicit test domain; this is not a qualified production spatial adapter."""
		var binding: Dictionary = domain.descriptor()
		out.world_ref = binding.world_ref
		out.datum_u = binding.datum_u
		out.minimum_quantum = binding.min_quantum
		out.size_quanta = binding.size_quanta
		return true

	func room_refusal(room: Vector2i) -> StringName:
		"""This fixture still requires an actual live Room in the shared Buildings owner."""
		return &"" if buildings.is_live_room(room) else &"SYNTHETIC_ROOM_STALE"

	func operation_refusal(_origin: Vector3i, _operation: int, _stage: int, room: Vector2i) -> StringName:
		"""No profiles or geometry are qualified by this deliberately synthetic claim fixture."""
		return room_refusal(room)

	func publish_transition(_origin: Vector3i, _operation: int, _stage: int, _room: Vector2i) -> void:
		"""Synthetic no-op: this fixture never publishes geometry or a usable route."""
		pass

	func discard_transition(_origin: Vector3i, _operation: int, _stage: int, _room: Vector2i) -> void:
		"""No physical geometry preparation exists in this isolated identity/lifetime fixture."""
		pass

class SiteFixture extends RefCounted:
	var sites: Sites = null
	var spatial: SyntheticSpatial = null
	var jobs: Jobs = null

	func _init(construction: Construction, buildings: Buildings, domain: Space.Domain) -> void:
		"""Real physical/accounting identities with explicitly unqualified synthetic space admission."""
		var residents: Residents = Residents.new(buildings.directory())
		jobs = Jobs.new(residents)
		var work: Work = Work.new(jobs)
		var inventory: Inventory = Inventory.new(8, 32)
		var pool: Reservations = Reservations.new()
		var items: Items = Items.new()
		assert(items.load_default(inventory).ok, "fixture catalog")
		var gear: Gear = Gear.new(8)
		assert(gear.bind_equipment(inventory, buildings.directory(), residents).ok, "fixture Gear")
		assert(work.bind_gear(gear).ok, "fixture Work")
		spatial = SyntheticSpatial.new()
		spatial.buildings = buildings
		spatial.domain = domain
		sites = Sites.new(construction, inventory, pool, items, jobs, work, spatial, 32, 8)

	func bind_unstarted_job(site: Vector2i, project: Vector2i) -> bool:
		"""Cancellation still names a real exact-work BUILD Job, even before any material or labor."""
		var remaining: IntMath.IntResult = IntMath.IntResult.new()
		if not sites.construction_owner().remaining_mwu_into(project, remaining):
			return false
		var row: int = jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, remaining.value, 0).value
		return jobs.set_requester(row, project).ok and jobs.set_tool_gate(row, Jobs.GATE_SATISFIED).ok \
			and sites.bind_job(site, jobs.ref_of(row)).ok


class SyntheticLocations extends Owner.ResidentLocations:
	## Real Resident and XYZ stores, explicitly synthetic mode/Room containment for this unit fixture.
	var residents: Residents = null
	var transforms: Transforms = null
	var containing_room: Vector2i = NULL_REF
	var mode: int = 5
	var pose: Transforms.Pose = Transforms.Pose.new()

	func directory() -> Directory:
		"""The real Resident store supplies the same global generations as Buildings."""
		return residents.directory()

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""No production qualification: mode and containment are deliberately fixture-controlled."""
		out.clear()
		if not residents.slot_of_ref(ref).ok or not transforms.read_into(ref, pose):
			return &"SYNTHETIC_LOCATION_STALE"
		out.kind = Directory.KIND_RESIDENT
		out.parent = containing_room
		out.a = pose.x
		out.b = pose.y
		out.c = pose.z
		out.d = mode
		return &""


class ReentrantSources extends Owner.CoreSources:
	## Attack only the validation callback boundary; all source identities still come from actual stores.
	var geometry: WeakRef = null
	var token: int = 0
	var attack: bool = false
	var abort_succeeded: bool = false
	var edit_error: StringName = &""
	var begin_error: StringName = &""

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""Borrowed heaps must never be consumed by edits hidden in a trusted-boundary callback."""
		if attack:
			var owner: Owner = geometry.get_ref() as Owner
			abort_succeeded = owner.abort(token)
			edit_error = owner.stage_source(token, ref)
			begin_error = owner.begin_stage(owner.revision()).error
		return super.read_into(ref, out)


var _buildings: Buildings = null
var _construction: Construction = null
var _sources: Owner.CoreSources = null
var _owner: Owner = null
var _domain: Space.Domain = null
var _world: Vector2i = NULL_REF
var _hall: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""Borrow real identity owners; synthetic geometry never invents an EntityRef."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_world = _buildings.directory().create(Directory.KIND_WORLD)
	_hall = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["hall"]), 59 * 128 + 58, 0, 1).ref
	_room = _buildings.designate_room(_hall, int(Catalog.ROOM_TYPE["DORMITORY"]), _room_tiles()).ref
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction)
	_domain = _new_domain()
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain, R, O), &"", "actual world binding")
	assert_true(_buildings.is_live_room(_room), "real room fixture")


func after_each() -> void:
	"""Release borrowed stores without reference cycles or retained engine objects."""
	_owner = null
	_sources = null
	_domain = null
	_construction = null
	_buildings = null


func _room_tiles() -> PackedInt32Array:
	"""GDD hall's first five columns; only actual source identity comes from this ground room."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for z: int in range(60, 68):
		for x: int in range(59, 64):
			tiles.append(z * 128 + x)
	return tiles


func _new_domain(checks: int = 100000) -> Space.Domain:
	"""Explicit negative-coordinate bounds and operation budget are synthetic, not production defaults."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(16, 16, 16),
		64, 64, checks), &"", "domain")
	return domain


func _begin() -> int:
	"""Use the exact live revision at the cold transaction boundary."""
	var result: Owner.Result = _owner.begin_stage(_owner.revision())
	assert_true(result.ok(), "prepare: %s" % result.error)
	return result.token


func _region(box: Array[int], role: int, ref: Vector2i, level: int = 1) -> Owner.Region:
	"""One input packet, never an authoritative per-entity object."""
	var region: Owner.Region = Owner.Region.new()
	region.box = PackedInt32Array(box)
	region.role = role
	region.owner = ref
	region.level = level
	return region


func _put(token: int, region: Owner.Region) -> Vector2i:
	"""Append a checked staged extent and retain its exact internal generation."""
	var result: Owner.Result = _owner.stage_add(token, region)
	assert_true(result.ok(), "region: %s" % result.error)
	return result.handle


func _publish(token: int) -> void:
	"""Model immediate prepare/preflight/publish with no physical mutation or yielding in between."""
	assert_equal(_owner.seal(token), &"", "sealed")
	assert_equal(_owner.prepared_refusal(token), &"", "immediate identity preflight")
	_owner.publish(token)


func _snapshot() -> Space.Snapshot:
	"""Return copied complete actual facts and blockers, with one explicit project exemption."""
	var result: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_into(result), &"", "snapshot")
	return result


func test_unbound_source_identity_and_capacity_refuse_before_allocation() -> void:
	"""The empty/unconfigured base cannot declare an underground world clear or supported."""
	var absent: Owner = Owner.new(Owner.Sources.new())
	assert_equal(absent.configure(_domain, R, O), &"SPACE_WORLD_UNBOUND", "no source adapter")
	assert_equal(absent.initialization_refusal(), &"SPACE_WORLD_UNBOUND", "explicit unbound state")
	assert_equal(absent.packed_memory_bytes(), 0, "no allocation")
	var bounded: Owner = Owner.new(_sources)
	assert_equal(bounded.configure(_domain, 65, O), &"SPACE_WORLD_CAPACITY", "capacity beyond domain")
	assert_equal(bounded.configure(_domain, R, 9223372036854775807), &"SPACE_WORLD_CAPACITY", "huge capacity")
	assert_equal(bounded.packed_memory_bytes(), 0, "refusal precedes allocation")
	assert_equal(_owner.configure(_domain, R, O), &"SPACE_WORLD_ALREADY_BOUND", "immutable world")


func test_geometry_is_invisible_until_non_failing_publication() -> void:
	"""Preparation exposes no free void, reservation or half-updated revision to readers."""
	var token: int = _begin()
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	assert_equal(handle, Vector2i(0, 1), "lowest slot, first generation")
	assert_false(_owner.is_live_region(handle), "unpublished handle")
	assert_equal(_snapshot().volumes.role.size(), 0, "live survey stays empty")
	assert_true(_owner.state_bytes().is_empty(), "mid-transaction save refused")
	_publish(token)
	assert_true(_owner.is_live_region(handle), "published handle")
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.DRY_SOLID]), "actual soil")
	assert_equal(_owner.revision(), 2, "one world revision")


func test_abort_wrong_tokens_and_stale_revisions_preserve_live_bytes() -> void:
	"""A failed material transaction can discard only its own preparation and retry afresh."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	_put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.SUPPORT, _world))
	assert_equal(_owner.begin_stage(1).error, &"SPACE_TRANSACTION_BUSY", "one transaction")
	assert_false(_owner.abort(token + 1), "another operation cannot abort")
	assert_true(_owner.abort(token), "abort")
	assert_equal(_owner.state_bytes(), before, "byte exact live state")
	assert_equal(_owner.begin_stage(0).error, &"SPACE_REVISION_STALE", "old proof refuses")
	assert_equal(_owner.stage_remove(token, Vector2i(0, 1)), &"SPACE_TRANSACTION_STALE", "discarded token")
	var next: int = _begin()
	assert_true(next != token, "no transient token reuse")
	assert_true(_owner.abort(next), "retry ends")


func test_snapshot_and_region_results_do_not_alias_authority() -> void:
	"""Caller edits cannot rewrite actual occupancy, the immutable datum or source inventory."""
	var token: int = _begin()
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORTED_VOID, _world))
	_publish(token)
	var copy: Space.Snapshot = _snapshot()
	copy.volumes.hi_x[0] = 8192
	copy.live_refs[0] = 123
	var row: Owner.Region = Owner.Region.new()
	assert_equal(_owner.region_into(handle, row), &"", "region reads")
	row.box[0] = -8192
	assert_equal(_snapshot().volumes.box_at(0), PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), "exact authority remains")
	var domain: Space.Domain = _owner.domain_copy()
	domain._bounds[0] = 0
	assert_equal(_owner.domain_copy().descriptor().bounds_u[0], -8192, "domain copy isolated")


func test_confirmed_claims_block_but_never_supply_void_or_dry_matter() -> void:
	"""A plan marker over dirt is neither a cut nor a finished navigation region."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	_publish(token)
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.DRY_SOLID, Space.OBSTACLE]), "reservation is only blocker")


func test_project_generation_loss_invalidates_confirmed_claims() -> void:
	"""A retired project's numbers cannot remain a valid claim or acquire an exemption."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	_publish(token)
	assert_true(_buildings.directory().destroy(project), "force owner-loss fixture")
	assert_equal(_owner.snapshot_into(Space.Snapshot.new()), &"SPACE_SOURCE_STALE", "stale actual claim refuses")


func test_source_facts_revalidate_even_when_entity_generation_is_unchanged() -> void:
	"""A geometry revision is not proof that a Building's actual placement facts remained unchanged."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "real Building source")
	var region: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _hall))
	_publish(token)
	assert_equal(_owner.source_refusal(_hall), &"", "source valid")
	assert_true(_buildings.set_building_interior_id(_hall, 12).ok, "same entity changes structural fact")
	assert_equal(_owner.source_refusal(_hall), &"SPACE_SOURCE_DRIFT", "exact fact drift")
	token = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"SPACE_SOURCE_REBUILD_REQUIRED", "must remove old geometry")
	assert_equal(_owner.stage_remove(token, region), &"", "remove old extent")
	assert_equal(_owner.stage_source(token, _hall), &"", "now rebind actual facts")
	_publish(token)
	assert_equal(_owner.source_refusal(_hall), &"", "updated exact source")


func test_final_preflight_detects_source_change_after_seal() -> void:
	"""No callback or awaited interval may separate final preflight from physical commit/publication."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "Building source")
	assert_equal(_owner.seal(token), &"", "sealed")
	assert_equal(_owner.stage_source(token, _room), &"SPACE_TRANSACTION_SEALED", "cannot edit sealed candidate")
	assert_true(_buildings.set_building_interior_id(_hall, 17).ok, "actual external mutation")
	assert_equal(_owner.prepared_refusal(token), &"SPACE_SOURCE_DRIFT", "last-moment preflight refuses")
	assert_true(_owner.abort(token), "discard stale preparation")


func test_prepared_readers_require_current_sealed_token_and_preserve_live_state() -> void:
	"""Prepared facts are available only through the receiver's current sealed token namespace."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var row: Owner.Region = Owner.Region.new()
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.prepared_region_into(token, handle, row), &"SPACE_TRANSACTION_UNSEALED", "unsealed row")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "unsealed survey")
	assert_equal(_owner.seal(token), &"", "sealed")
	assert_equal(_owner.prepared_snapshot_into(token + 1, image), &"SPACE_TRANSACTION_UNSEALED", "wrong token")
	var foreign: Owner = Owner.new(_sources)
	assert_equal(foreign.configure(_domain, R, O), &"", "separate actual owner")
	assert_equal(foreign.prepared_snapshot_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "other receiver owns no candidate")
	assert_equal(_owner.prepared_region_into(token, Vector2i(handle.x, handle.y + 1), row), &"SPACE_REGION_STALE", "full region generation")
	assert_equal(_owner.prepared_region_into(token, handle, row), &"", "actual candidate reads")
	assert_equal(row.box, PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), "exact future geometry")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"", "actual survey reads")
	assert_equal(image.revision, _owner.revision() + 1, "future revision is explicit")
	assert_equal(_snapshot().volumes.role.size(), 0, "live world remains unchanged")
	assert_true(_owner.abort(token), "discard preparation")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "aborted token")
	assert_equal(_owner.state_bytes(), before, "reads and abort preserve every live byte")


func test_prepared_results_are_copied_and_retain_claims_removals_and_next_generation() -> void:
	"""No caller can rewrite staged facts or see a removed row through its retired handle."""
	var token: int = _begin()
	var old: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, old), &"", "remove old solid")
	var replacement: Vector2i = _put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.UNFINISHED, _world))
	_room_claim(token)
	assert_equal(_owner.seal(token), &"", "sealed replacement")
	var row: Owner.Region = Owner.Region.new()
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.prepared_region_into(token, old, row), &"SPACE_REGION_STALE", "old handle retired")
	assert_equal(_owner.prepared_region_into(token, replacement, row), &"", "replacement generation")
	row.box[0] = -8192
	assert_equal(_owner.prepared_snapshot_into(token, image), &"", "copied candidate")
	assert_equal(image.volumes.role, PackedInt32Array([Space.UNFINISHED, Space.OBSTACLE]), "actual future roles and Room claim")
	image.volumes.hi_x[0] = 8192
	image.live_refs[0] = 123
	assert_equal(_owner.prepared_region_into(token, replacement, row), &"", "read pristine candidate")
	assert_equal(row.box, PackedInt32Array([1024, 0, 0, 2048, 1024, 1024]), "caller mutations isolated")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"", "fresh source identities")
	assert_equal(image.live_refs[0], _world.x, "World source remains actual")
	_owner.publish(token)
	assert_equal(_owner.prepared_snapshot_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "published token cannot reread")
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.UNFINISHED, Space.OBSTACLE]), "exact prepared candidate published")


func test_prepared_readers_refuse_actual_source_drift_without_overwriting_outputs() -> void:
	"""A sealed old source is not future truth after an actual owner changes its structural facts."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "actual Building")
	var handle: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _hall))
	assert_equal(_owner.seal(token), &"", "sealed")
	var row: Owner.Region = Owner.Region.new()
	var image: Space.Snapshot = Space.Snapshot.new()
	row.level = 771
	image.revision = 991
	assert_true(_buildings.set_building_interior_id(_hall, 17).ok, "actual structural change")
	assert_equal(_owner.prepared_region_into(token, handle, row), &"SPACE_SOURCE_DRIFT", "region source drift")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"SPACE_SOURCE_DRIFT", "survey source drift")
	assert_equal(row.level, 771, "refusal preserved caller packet")
	assert_equal(image.revision, 991, "refusal preserved prior caller survey")
	assert_true(_owner.abort(token), "stale candidate can be discarded")


func test_floor_section_generation_cannot_transfer_furniture_to_reused_floor() -> void:
	"""Removing and reusing the same floor row never silently reparents a bed to another floor."""
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	assert_true(_buildings.is_live_furniture(bed), "actual bed")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	assert_equal(_owner.stage_source(token, bed), &"", "bed source")
	var floor_ref: Vector2i = _put(token, _region([0, -1024, 0, 2048, -1023, 2048], Space.FLOOR_DATUM, _room))
	var bed_box: Owner.Region = _region([0, -1024, 0, 1024, 0, 1024], Space.OBSTACLE, bed)
	bed_box.section = floor_ref
	var bed_ref: Vector2i = _put(token, bed_box)
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, floor_ref), &"", "prepare floor removal")
	assert_equal(_owner.seal(token), &"SPACE_SECTION_STALE", "dependent bed prevents removal")
	var replacement: Vector2i = _put(token, _region([0, -1024, 0, 2048, -1023, 2048], Space.FLOOR_DATUM, _room))
	assert_equal(replacement, Vector2i(floor_ref.x, floor_ref.y + 1), "slot reused with new generation")
	assert_equal(_owner.seal(token), &"SPACE_SECTION_STALE", "old bed link cannot attach to reused row")
	assert_equal(_owner.stage_remove(token, bed_ref), &"", "remove dependent bed geometry")
	_publish(token)
	assert_false(_owner.is_live_region(floor_ref), "old handle stays stale")
	assert_true(_owner.is_live_region(replacement), "new actual floor")


func test_two_levels_use_actual_xyz_and_level_label_cannot_hide_overlap() -> void:
	"""Same X/Z on different heights is separate; two different level labels do not excuse collision."""
	var token: int = _begin()
	_put(token, _region([0, -2048, 0, 1024, -1024, 1024], Space.DRY_SOLID, _world, 1))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORTED_VOID, _world, 2))
	_publish(token)
	assert_equal(_snapshot().volumes.role.size(), 2, "distinct actual heights")
	token = _begin()
	_put(token, _region([0, -2048, 0, 1024, -1024, 1024], Space.UNFINISHED, _world, 99))
	assert_equal(_owner.seal(token), &"SPACE_SURVEY_CONTRADICTION", "actual XYZ governs contradiction")
	assert_true(_owner.abort(token), "refusal leaves actual levels unchanged")


func test_capacity_budget_and_scalar_overflow_refuse_without_live_changes() -> void:
	"""Finite engineering ceilings do not truncate a room or narrow enormous scalar values."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	var invalid: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	invalid.role = 9223372036854775807
	assert_equal(_owner.stage_add(token, invalid).error, &"SPACE_REGION_FORMAT", "role before B8 narrowing")
	invalid.role = Space.OBSTACLE
	invalid.level = 9223372036854775807
	assert_equal(_owner.stage_add(token, invalid).error, &"SPACE_REGION_FORMAT", "level before I32 narrowing")
	assert_true(_owner.abort(token), "invalid stage ends")
	assert_equal(_owner.state_bytes(), before, "live unchanged")
	var limited: Owner = Owner.new(_sources)
	assert_equal(limited.configure(_new_domain(1), R, O), &"", "explicit tiny work budget")
	assert_equal(limited.begin_stage(1).error, &"SPACE_OPERATION_BUDGET", "refuse before bank copy")


func test_saved_columns_roundtrip_and_allocator_continue_identically() -> void:
	"""Every authoritative column and retired generation survives the local schema boundary."""
	var token: int = _begin()
	var first: Vector2i = _put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.SUPPORT, _world))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, first), &"", "leave generation history in free row")
	_publish(token)
	var bytes: PackedByteArray = _owner.state_bytes()
	assert_equal(bytes.size(), 68 * R + 42 * O + 144, "exact persisted payload")
	assert_equal(_owner.packed_memory_bytes(), 149 * R + 92 * O + 288, "two banks, heaps and changed-row scratch")
	var restored: Owner = Owner.new(_sources)
	assert_equal(restored.configure(_domain, R, O), &"", "load target same domain")
	assert_equal(restored.restore_state_bytes(bytes), &"", "validated restore")
	assert_equal(restored.state_bytes(), bytes, "all columns byte exact")
	var resumed: Owner.Result = restored.begin_stage(restored.revision())
	var added: Owner.Result = restored.stage_add(resumed.token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world))
	assert_equal(added.handle, Vector2i(0, 2), "lowest free row generation preserved")
	assert_true(restored.abort(resumed.token), "roundtrip probe ends")


func test_corrupt_load_never_changes_live_or_partial_geometry() -> void:
	"""Wrong domain, sizes, hidden unused data and malformed lifecycle all fail in the alternate bank."""
	var before: PackedByteArray = _owner.state_bytes()
	var broken: PackedByteArray = before.duplicate()
	broken.resize(broken.size() - 1)
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_SIZE", "truncated")
	broken = before.duplicate()
	broken.encode_s64(5 * 8, 1024)
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_DOMAIN", "datum mismatch")
	broken = before.duplicate()
	broken[144] = 2
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_LIFECYCLE", "presence mask")
	broken = before.duplicate()
	broken[144 + 2 * R] = 1
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_LOAD_UNUSED", "hidden free geometry")
	assert_equal(_owner.state_bytes(), before, "all corrupt loads atomic")
	assert_false(_owner.has_prepared(), "no failed load keeps transaction lock")


func test_exhausted_generations_retire_instead_of_wrapping() -> void:
	"""An exhausted internal slot remains unavailable after save and load."""
	var bytes: PackedByteArray = _owner.state_bytes()
	bytes[144 + R] = 1
	bytes.encode_s32(144 + 4 * R, 2147483647)
	assert_equal(_owner.restore_state_bytes(bytes), &"", "canonical retired row")
	var token: int = _begin()
	var next: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	assert_equal(next, Vector2i(1, 1), "skip retired row zero")
	_publish(token)
	bytes = _owner.state_bytes()
	bytes.encode_s64(17 * 8, 9223372036854775807)
	assert_equal(_owner.restore_state_bytes(bytes), &"", "maximum world revision can be read")
	assert_equal(_owner.begin_stage(_owner.revision()).error, &"SPACE_REVISION_EXHAUSTED", "no revision wrap")


func test_finite_source_and_region_capacity_refuse_without_truncation() -> void:
	"""A full arena explicitly refuses; no room extent or owner is silently omitted."""
	var tiny: Owner = Owner.new(_sources)
	assert_equal(tiny.configure(_domain, 1, 1), &"", "one physical region, one actual world source")
	var token: int = tiny.begin_stage(1).token
	assert_equal(tiny.stage_source(token, _room), &"SPACE_SOURCE_CAPACITY", "world occupies only source row")
	assert_true(tiny.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world)).ok(), "first extent")
	assert_equal(tiny.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORT, _world)).error,
		&"SPACE_REGION_CAPACITY", "no truncation")
	assert_true(tiny.abort(token), "capacity failure leaves live empty")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(tiny.snapshot_into(image), &"", "complete image")
	assert_equal(image.volumes.role.size(), 0, "nothing partially published")


func test_two_real_projects_cannot_claim_the_same_actual_volume() -> void:
	"""Other-project conflicts use full Construction references across any nominal level labels."""
	var first_project: Vector2i = _construction.open_build(_hall).ref
	var path: Vector2i = _buildings.place_building(int(Catalog.BUILDING_DEFINITION["dirt_path"]), 0, 0, 1).ref
	var second_project: Vector2i = _construction.open_build(path).ref
	var token: int = _begin()
	for project: Vector2i in [first_project, second_project]:
		var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
		claim.claim_kind = Owner.CLAIM_CONSTRUCTION
		claim.claim_ref = project
		_put(token, claim)
	assert_equal(_owner.seal(token), &"SPACE_RESERVATION_CONFLICT", "no row-order winner")
	assert_true(_owner.abort(token), "neither conflicting claim installed")


func test_final_preflight_revalidates_project_claim_generation() -> void:
	"""Claims are checked even when their project is not a registered geometry source."""
	var project: Vector2i = _construction.open_build(_hall).ref
	var token: int = _begin()
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	assert_equal(_owner.seal(token), &"", "prepare actual claim")
	assert_true(_buildings.directory().destroy(project), "identity disappears before physical commit")
	assert_equal(_owner.prepared_refusal(token), &"SPACE_SOURCE_STALE", "last-moment claim refusal")
	assert_true(_owner.abort(token), "discard")


func test_region_query_and_source_retirement_keep_internal_namespace_exact() -> void:
	"""The edit query returns generations, and forgetting a source cannot orphan its extents."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "register room")
	var region: Vector2i = _put(token, _region([-1024, -1024, -1024, 0, 0, 0], Space.OBSTACLE, _room))
	assert_equal(_owner.stage_forget_source(token, _room), &"SPACE_SOURCE_IN_USE", "cannot orphan")
	_publish(token)
	var hits: PackedInt32Array = PackedInt32Array()
	assert_equal(_owner.overlapping_regions_into(PackedInt32Array([-512, -512, -512, 512, 512, 512]), hits), &"", "query")
	assert_equal(hits, PackedInt32Array([region.x, region.y]), "full internal region handle")
	token = _begin()
	assert_equal(_owner.stage_remove(token, region), &"", "release extent")
	assert_equal(_owner.stage_forget_source(token, _room), &"", "retire source")
	_publish(token)
	assert_equal(_owner.source_revision(_room), 0, "retired source has no revision")
	assert_equal(_owner.source_refusal(_room), &"SPACE_SOURCE_NOT_REGISTERED", "no inherited binding")


func _resident_locations() -> SyntheticLocations:
	"""Bind real transform/resident owners but explicitly label the unqualified containment/mode."""
	var fixture: SyntheticLocations = SyntheticLocations.new()
	fixture.residents = Residents.new(_buildings.directory())
	fixture.transforms = Transforms.new(_buildings.directory())
	fixture.containing_room = _room
	_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction, fixture)
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain, R, O), &"", "bind explicit resident reader")
	return fixture


func _occupant(token: int, resident: Vector2i, floor_ref: Vector2i) -> Owner.Region:
	"""A synthetic full envelope uses the actual resident feet coordinate supplied through Transform."""
	assert_equal(_owner.stage_source(token, resident), &"", "actual resident source")
	var body: Owner.Region = _region([0, -1024, 0, 1024, 0, 1024], Space.OCCUPANT, resident)
	body.section = floor_ref
	return body


func test_missing_actual_resident_location_reader_never_uses_flat_ground() -> void:
	"""Directory liveness cannot invent Y, a Room or a movement mode."""
	var residents: Residents = Residents.new(_buildings.directory())
	var resident: Vector2i = residents.spawn(&"mouse").ref
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, resident), &"SPACE_RESIDENT_LOCATION_UNBOUND", "no fallback")
	assert_true(_owner.abort(token), "refusal leaves owner unchanged")


func test_resident_xyz_mode_and_generation_changes_invalidate_old_geometry() -> void:
	"""Same X/Z below another floor, posture/mode changes and recycled IDs require new actual evidence."""
	var fixture: SyntheticLocations = _resident_locations()
	var resident: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_true(fixture.transforms.place(resident, 64, -1024, 64, 0), "real XYZ placement")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	var floor_ref: Vector2i = _put(token, _region([0, -1024, 0, 1024, -1023, 1024], Space.FLOOR_DATUM, _room))
	_put(token, _occupant(token, resident, floor_ref))
	_publish(token)
	assert_equal(_owner.source_refusal(resident), &"", "exact actual position")
	fixture.mode = 4
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_DRIFT", "changed movement mode")
	fixture.mode = 5
	assert_true(fixture.transforms.place(resident, 64, -2048, 64, 0), "real lower level")
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_DRIFT", "height drift despite same X/Z")
	assert_true(fixture.residents.despawn(resident).ok, "real resident retires")
	var replacement: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_equal(replacement.x, resident.x, "actual slot reuse")
	assert_true(replacement.y != resident.y, "new generation")
	assert_equal(_owner.source_refusal(resident), &"SPACE_SOURCE_STALE", "old occupant cannot follow reused slot")


func test_resident_floor_owner_and_actual_height_are_both_required() -> void:
	"""A Room-shaped reference and a level label cannot move an occupant away from real XYZ."""
	var fixture: SyntheticLocations = _resident_locations()
	var resident: Vector2i = fixture.residents.spawn(&"mouse").ref
	assert_true(fixture.transforms.place(resident, 64, -1024, 64, 0), "real position")
	var token: int = _begin()
	var wrong_floor: Vector2i = _put(token, _region([0, -1024, 0, 1024, -1023, 1024], Space.FLOOR_DATUM, _world))
	_put(token, _occupant(token, resident, wrong_floor))
	assert_equal(_owner.seal(token), &"SPACE_SECTION_OWNER", "world floor is not containing Room")
	assert_true(_owner.abort(token), "discard wrong owner")
	token = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room")
	var floor_ref: Vector2i = _put(token, _region([0, -2048, 0, 1024, -2047, 1024], Space.FLOOR_DATUM, _room))
	var body: Owner.Region = _occupant(token, resident, floor_ref)
	body.box = PackedInt32Array([0, -2048, 0, 1024, -1024, 1024])
	_put(token, body)
	assert_equal(_owner.seal(token), &"SPACE_RESIDENT_POSITION", "lower envelope cannot contain actual upper feet")
	assert_true(_owner.abort(token), "discard wrong height")


func test_changed_row_validation_catches_later_row_edit_against_unchanged_earlier_row() -> void:
	"""Incremental pair checking cannot skip the lower-index unchanged half of a new collision."""
	var token: int = _begin()
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var later: Vector2i = _put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.SUPPORTED_VOID, _world))
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	token = _begin()
	assert_equal(_owner.stage_remove(token, later), &"", "replace later row")
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, _world))
	assert_equal(_owner.seal(token), &"SPACE_SURVEY_CONTRADICTION", "edit checked against lower unchanged row")
	assert_true(_owner.abort(token), "refusal atomic")
	var loaded: PackedByteArray = before.duplicate()
	loaded.encode_s32(144 + 8 * R + 4, 0)
	loaded.encode_s32(144 + 20 * R + 4, 1024)
	assert_equal(_owner.restore_state_bytes(loaded), &"SPACE_SURVEY_CONTRADICTION", "incoming changed row also checked")
	assert_equal(_owner.state_bytes(), before, "load failure leaves exact prior image")


func test_load_removal_rechecks_retained_floor_dependents() -> void:
	"""An incoming image with fewer regions must not retain references to a deleted floor generation."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "room source")
	var floor_ref: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _room))
	var attached: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.PROTECTED_ACCESS, _room)
	attached.section = floor_ref
	_put(token, attached)
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	var corrupt: PackedByteArray = before.duplicate()
	corrupt.encode_s32(144 + 4 * R, 2)
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_SECTION_STALE", "floor generation changed without dependent update")
	assert_equal(_owner.state_bytes(), before, "source and floor data retained")
	corrupt = before.duplicate()
	_erase_saved_region(corrupt, floor_ref.x)
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_SECTION_STALE", "canonical removed floor with retained dependent")
	assert_equal(_owner.state_bytes(), before, "removed-floor refusal preserves live bytes")


func _erase_saved_region(bytes: PackedByteArray, row: int) -> void:
	"""Author an actually absent row under the fixed 1064 wire contract, retaining only its generation."""
	var widths: Array[int] = [1, 1, 1, 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 8, 4, 4]
	var offset: int = 144
	for column: int in widths.size():
		var at: int = offset + widths[column] * row
		if column == 4:
			offset += widths[column] * R
			continue
		if widths[column] == 1:
			bytes[at] = 0
		elif widths[column] == 4:
			bytes.encode_s32(at, -1 if column in [12, 14, 17] else 0)
		else:
			bytes.encode_s64(at, 0)
		offset += widths[column] * R


func test_empty_source_retirement_spends_its_real_scan_budget() -> void:
	"""Repeated empty-source retirement cannot bypass the declared cold transaction work ceiling."""
	var tiny: Owner = Owner.new(_sources)
	assert_equal(tiny.configure(_new_domain(256), 1, 4), &"", "finite cold transaction ceiling")
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	for source: Vector2i in [_hall, _room, bed]:
		var source_token: int = tiny.begin_stage(tiny.revision()).token
		assert_equal(tiny.stage_source(source_token, source), &"", "register one actual source")
		assert_equal(tiny.seal(source_token), &"", "bounded source transaction")
		tiny.publish(source_token)
	var before: PackedByteArray = tiny.state_bytes()
	var token: int = tiny.begin_stage(tiny.revision()).token
	while tiny._remaining > 11:
		assert_equal(tiny.stage_source(token, _world), &"", "charge repeated actual one-row lookup")
	assert_equal(tiny.stage_forget_source(token, _hall), &"", "first retirement")
	assert_equal(tiny.stage_forget_source(token, _room), &"", "second retirement")
	assert_equal(tiny.stage_forget_source(token, bed), &"SPACE_OPERATION_BUDGET", "third scan refuses before mutation")
	assert_true(tiny.abort(token), "abort over-budget batch")
	assert_equal(tiny.state_bytes(), before, "live source/allocator state remains byte exact")


func _room_claim(token: int, room: Vector2i = NULL_REF) -> Vector2i:
	"""A persistent accepted footprint is owned by its actual Room, not a synthetic paid project."""
	if room == NULL_REF:
		room = _room
	assert_equal(_owner.stage_source(token, room), &"", "actual Room source")
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.UNFINISHED, room)
	claim.claim_kind = Owner.CLAIM_ROOM
	claim.claim_ref = room
	return _put(token, claim)


func test_room_claim_survives_actual_paid_phase_retirement() -> void:
	"""The confirmed layout outlives each real quantum phase; cancellation cannot erase it."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	assert_equal(fixture.sites.initialization_refusal(), &"", "real Sites composition")
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var phase: Vector2i = fixture.sites.open_phase(site, Contract.OP_BRACE).ref
	assert_true(_construction.is_live_project(phase), "real phase project")
	assert_true(fixture.bind_unstarted_job(site, phase), "real phase Job binds before cancellation")
	var token: int = _begin()
	var claim: Vector2i = _room_claim(token)
	_publish(token)
	var cancelled: Construction.OpResult = fixture.sites.cancel_phase(site, NULL_REF)
	assert_true(cancelled.ok, "unstarted empty phase retires: %s" % cancelled.error)
	assert_false(_construction.is_live_project(phase), "phase generation no longer live")
	assert_true(_owner.is_live_region(claim), "confirmed room claim persists")
	assert_equal(_snapshot().volumes.role, PackedInt32Array([Space.OBSTACLE]), "ordinary survey still blocks")
	var scoped: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, site), &"", "exact retained physical Room scope")
	assert_equal(scoped.volumes.role.size(), 0, "only that Room's marker omitted")


func test_site_scoped_snapshot_keeps_actual_geometry_and_other_phase_claims() -> void:
	"""An exemption cannot erase residents, fixtures, exits or another paid project's work area."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var project: Vector2i = fixture.sites.open_phase(site, Contract.OP_BRACE).ref
	var token: int = _begin()
	_room_claim(token)
	var phase_claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room)
	phase_claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	phase_claim.claim_ref = project
	_put(token, phase_claim)
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.PROTECTED_ACCESS, _room))
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room))
	_publish(token)
	assert_equal(_snapshot().volumes.role.size(), 4, "both markers plus actual geometry")
	var scoped: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, site), &"", "same actual Room/phase scope")
	assert_equal(scoped.volumes.role, PackedInt32Array([Space.PROTECTED_ACCESS, Space.OBSTACLE]), "actual rows retained")
	var next_site: Vector2i = fixture.sites.claim_quantum(Vector3i(1024, 0, 0), _room).ref
	assert_true(fixture.sites.open_phase(next_site, Contract.OP_BRACE).ok, "separate real paid phase")
	assert_equal(_owner.snapshot_for_site_into(scoped, fixture.sites, next_site), &"", "different exact phase")
	assert_equal(scoped.volumes.role.size(), 3, "other phase's marker remains blocking")


func test_prepared_site_scope_uses_actual_phase_and_keeps_same_room_obstacles() -> void:
	"""Future supported space cannot erase physical blockers under an own-Room reservation exemption."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var project: Vector2i = fixture.sites.open_phase(site, Contract.OP_BRACE).ref
	var token: int = _begin()
	_room_claim(token)
	var phase: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room)
	phase.claim_kind = Owner.CLAIM_CONSTRUCTION
	phase.claim_ref = project
	_put(token, phase)
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room))
	_put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.SUPPORTED_VOID, _room))
	assert_equal(_owner.seal(token), &"", "actual future candidate")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.prepared_snapshot_for_site_into(token, image, fixture.sites, site), &"", "typed future scope")
	assert_equal(image.volumes.role, PackedInt32Array([Space.OBSTACLE, Space.SUPPORTED_VOID]), "only exact own markers omitted")
	assert_equal(_owner.prepared_snapshot_into(token, image), &"", "unscoped remains complete")
	assert_equal(image.volumes.role.size(), 4, "all claims and physical facts retained")
	assert_equal(_owner.prepared_snapshot_for_site_into(token, image, fixture.sites,
		Vector2i(site.x, site.y + 1)), &"SPACE_SITE_STALE", "full site generation")
	var other: Construction = Construction.new()
	other.directory().create(Directory.KIND_WORLD)
	var foreign: SiteFixture = SiteFixture.new(other, other.buildings(), _domain)
	assert_equal(_owner.prepared_snapshot_for_site_into(token, image, foreign.sites, site),
		&"SPACE_SITE_OWNER_MISMATCH", "foreign owner with coincident ref cannot filter")
	assert_true(_owner.abort(token), "no public space was changed by scoped reads")


func test_room_claim_kind_is_typed_and_corrupt_load_refuses() -> void:
	"""A Room cannot impersonate a paid project or lend its claim to another geometric owner."""
	var token: int = _begin()
	var bad: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	bad.claim_kind = Owner.CLAIM_ROOM
	bad.claim_ref = _room
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_ROOM_CLAIM_IDENTITY", "wrong claim owner")
	bad.claim_kind = Owner.CLAIM_CONSTRUCTION
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_PROJECT_IDENTITY", "wrong reference namespace")
	bad.claim_kind = 9223372036854775807
	assert_equal(_owner.stage_add(token, bad).error, &"SPACE_RESERVATION_FORMAT", "kind narrowing refused")
	assert_true(_owner.abort(token), "invalid claims unchanged")
	token = _begin()
	_room_claim(token)
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	var corrupt: PackedByteArray = before.duplicate()
	corrupt[144 + 3 * R] = 3
	assert_equal(_owner.restore_state_bytes(corrupt), &"SPACE_REGION_FORMAT", "unknown on-disk claim kind")
	assert_equal(_owner.state_bytes(), before, "corrupt claim load atomic")


func test_foreign_sites_and_changed_domain_cannot_receive_an_exemption() -> void:
	"""Coincident ref numbers and a drifted descriptor never prove the actual world's claim scope."""
	var fixture: SiteFixture = SiteFixture.new(_construction, _buildings, _domain)
	var site: Vector2i = fixture.sites.claim_quantum(Vector3i.ZERO, _room).ref
	var other: Construction = Construction.new()
	assert_equal(other.directory().create(Directory.KIND_WORLD), _world, "coincident World numbers in another real directory")
	var foreign: SiteFixture = SiteFixture.new(other, other.buildings(), _domain)
	assert_equal(foreign.sites.initialization_refusal(), &"", "foreign world is separately valid")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_site_into(image, foreign.sites, site), &"SPACE_SITE_OWNER_MISMATCH", "actual owner pointer required")
	var shifted: Space.Domain = Space.Domain.new()
	assert_equal(shifted.configure(_world, Vector3i(1024, 0, 0), Vector3i(-8, -8, -8), Vector3i(16, 16, 16), 64, 64, 100000), &"", "different datum")
	fixture.spatial.domain = shifted
	assert_equal(_owner.snapshot_for_site_into(image, fixture.sites, site), &"SPACE_SITE_DOMAIN", "domain identity drift")


func test_actual_room_domains_and_furniture_installation_are_exact_source_facts() -> void:
	"""Underground sources have real identities without flat coordinates; installation drift is visible."""
	var commands: SyntheticRoomCommands = SyntheticRoomCommands.new()
	commands.owner = weakref(_buildings)
	assert_true(_buildings.bind_spatial_authority(commands).ok, "actual command owner binds")
	commands.permit(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_PRIVATE_ROOM)
	var room: Vector2i = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_PRIVATE_ROOM).ref
	commands.permit(Buildings.SPATIAL_FURNITURE_CREATE, NULL_REF, room,
		int(Catalog.FURNITURE_DEFINITION["bed"]), 3)
	var bed: Vector2i = _buildings.stage_spatial_furniture(room, int(Catalog.FURNITURE_DEFINITION["bed"]), 3).ref
	commands.action = -1
	var facts: Owner.Facts = Owner.Facts.new()
	assert_equal(_sources.read_into(room, facts), &"", "actual underground Room reads")
	assert_equal([facts.parent, facts.a, facts.b, facts.c, facts.d],
		[NULL_REF, Buildings.ROOM_TYPE_PRIVATE_ROOM, 0, 0, Buildings.ROOM_SPACE_UNDERGROUND], "no invented tile membership")
	assert_false(_buildings.tile_offset_of_room(room).ok, "coordinate API correctly refuses")
	assert_equal(_sources.read_into(bed, facts), &"", "pending actual Furniture reads despite refused tile API")
	assert_equal([facts.parent, facts.b, facts.c, facts.d], [room, Buildings.NO_LINK, 3, 0], "pending orientation and no tile")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, room), &"", "actual underground source")
	assert_equal(_owner.stage_source(token, bed), &"", "actual pending source")
	_publish(token)
	commands.permit(Buildings.SPATIAL_FURNITURE_INSTALL, bed, NULL_REF)
	assert_true(_buildings.install_spatial_furniture(bed).ok, "synthetic install command changes actual flag")
	commands.action = -1
	assert_equal(_owner.source_refusal(bed), &"SPACE_SOURCE_DRIFT", "installation invalidates earlier evidence")
	assert_equal(_sources.read_into(bed, facts), &"", "installed exact source")
	assert_equal(facts.d, 1, "actual installed state")


func test_surface_facts_remain_actual_and_unknown_room_domain_refuses() -> void:
	"""The new discriminator keeps existing surface identity guards, and corrupted tags fail closed."""
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]),
		60 * 128 + 59, 0).ref
	var facts: Owner.Facts = Owner.Facts.new()
	assert_equal(_sources.read_into(_room, facts), &"", "surface source")
	assert_equal([facts.parent, facts.b, facts.c, facts.d], [_hall, _buildings.tile_offset_of_room(_room).value,
		40, Buildings.ROOM_SPACE_SURFACE], "actual surface membership")
	assert_equal(_sources.read_into(bed, facts), &"", "actual surface furniture")
	assert_equal([facts.b, facts.c, facts.d], [60 * 128 + 59, 0, 1], "surface origin and installed state")
	var row: int = _buildings.directory().get_typed_row(_room)
	_buildings._r_spatial_kind[row] = 255
	assert_equal(_sources.read_into(_room, facts), &"SPACE_SOURCE_FACTS", "unknown Room kind refused")
	assert_equal(_sources.read_into(bed, facts), &"SPACE_SOURCE_FACTS", "unknown containing domain refused")


func test_prepared_change_query_distinguishes_noop_and_source_only_changes() -> void:
	"""No-op lifecycle candidates need not invalidate every worker's static geometry proof."""
	var token: int = _begin()
	assert_false(_owner.prepared_has_changes(token), "unsealed candidate cannot claim exact changes")
	assert_equal(_owner.seal(token), &"", "empty stage seals")
	assert_false(_owner.prepared_has_changes(token), "identical packed state")
	assert_false(_owner.prepared_has_changes(token + 1), "wrong token never proves anything")
	assert_true(_owner.abort(token), "no-op abort")
	token = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "source-only stage")
	assert_equal(_owner.seal(token), &"", "source stage seals")
	assert_true(_owner.prepared_has_changes(token), "source facts are real state changes")
	assert_true(_owner.abort(token), "source-only abort")


func _installation_fixture() -> InstallationHarness:
	"""Build actual payment/worker stores; every nested helper failure is checked by the outer test."""
	var harness: InstallationHarness = InstallationHarness.new()
	harness.before_each()
	return harness


func _release_installation_fixture(harness: InstallationHarness) -> void:
	"""Audit shared actual goods and report helper failures before borrowed owners are released."""
	harness.after_each()
	assert_true(harness.failures.is_empty(), "actual installation fixture checks: %s" % harness.failures)


func test_furniture_future_source_requires_actual_completed_project() -> void:
	"""Foreign purpose owners, stale projects and unpaid work cannot prepare installed source facts."""
	var harness: InstallationHarness = _installation_fixture()
	var fitting: InstallationOwner = harness.furniture_with_geometry()
	var project: Vector2i = harness._open(fitting)
	var before: PackedByteArray = fitting.geometry.state_bytes()
	var token: int = fitting.geometry.begin_stage(fitting.geometry.revision()).token
	assert_equal(fitting.geometry.stage_furniture_install(token, project, harness._router, fitting),
		&"SPACE_INSTALLATION_NOT_COMPLETED", "unpaid pending project")
	assert_equal(fitting.geometry.stage_furniture_install(token, Vector2i(project.x, project.y + 1),
		harness._router, fitting), &"SPACE_INSTALLATION_PROJECT", "full project generation")
	assert_equal(fitting.geometry.stage_furniture_install(token, project, ModularContract.new(), fitting),
		&"SPACE_INSTALLATION_BINDING", "actual router required")
	assert_equal(fitting.geometry.stage_furniture_install(token, project, harness._router, harness._new_owner()),
		&"SPACE_INSTALLATION_BINDING", "exact bound purpose owner required")
	assert_true(fitting.geometry.abort(token), "discard preparation")
	assert_equal(fitting.geometry.state_bytes(), before, "no source or geometry changes")
	assert_false(harness._construction.buildings().is_furniture_installed(fitting.subject), "still pending")
	_release_installation_fixture(harness)


func test_furniture_install_source_publishes_only_after_actual_paid_installation() -> void:
	"""Actual Work/receipts/Buildings complete one fitting while source geometry retains the same envelope."""
	var harness: InstallationHarness = _installation_fixture()
	var fitting: InstallationOwner = harness.furniture_with_geometry()
	var piece: Vector2i = fitting.subject
	var project: Vector2i = harness._open(fitting)
	var job: Vector2i = harness._job(project)
	var before: Space.Snapshot = Space.Snapshot.new()
	assert_equal(fitting.geometry.snapshot_into(before), &"", "actual pending source survey")
	var revision: int = fitting.geometry.source_revision(piece)
	harness._start(project)
	harness._finish_labor(project, job)
	assert_true(harness._router.complete_order(project).ok, "actual completed paid publication")
	assert_equal(fitting.before_install_refusal, &"SPACE_SOURCE_DRIFT", "COMMIT alone is not installed truth")
	assert_equal(fitting.foreign_project_refusal, &"SPACE_INSTALLATION_TOKEN", "exact project in callback")
	assert_equal(fitting.foreign_owner_refusal, &"SPACE_INSTALLATION_TOKEN", "exact purpose owner in callback")
	assert_equal(fitting.published_refusal, &"", "actual after-facts published")
	assert_true(fitting.completion_saw_paid_clear, "all actual inputs committed before installation")
	assert_true(harness._construction.buildings().is_furniture_installed(piece), "actual installed flag")
	assert_false(harness._construction.is_live_project(project), "completed actual project retired")
	assert_false(fitting.geometry.has_prepared(), "no abandoned future source")
	assert_equal(fitting.geometry.source_revision(piece), revision + 1, "one source revision change")
	var after: Space.Snapshot = Space.Snapshot.new()
	assert_equal(fitting.geometry.snapshot_into(after), &"", "normal source guard accepts actual installed facts")
	assert_equal(after.volumes.role.size(), before.volumes.role.size(), "same number of actual regions")
	for index: int in before.volumes.role.size():
		assert_equal(after.volumes.box_at(index), before.volumes.box_at(index), "unchanged exact fitting/floor geometry")
	assert_equal(fitting.completed, 1, "one physical installation")
	_release_installation_fixture(harness)


func test_refused_furniture_completion_aborts_future_source_and_retries_once() -> void:
	"""A sealed-source refusal preserves live geometry and paid receipts, then the same real work retries."""
	var harness: InstallationHarness = _installation_fixture()
	var fitting: InstallationOwner = harness.furniture_with_geometry()
	var project: Vector2i = harness._open(fitting)
	var job: Vector2i = harness._job(project)
	harness._start(project)
	harness._finish_labor(project, job)
	var before: PackedByteArray = fitting.geometry.state_bytes()
	var paid: PackedByteArray = harness._image()
	fitting.refuse_after_seal = true
	assert_equal(harness._router.complete_order(project).error, &"SYNTHETIC_INSTALLATION_REFUSAL", "pre-payment companion refusal")
	assert_equal(fitting.geometry.state_bytes(), before, "abort retains previous source/regions")
	assert_equal(harness._image(), paid, "actual paid WIP retained unchanged")
	assert_false(harness._construction.buildings().is_furniture_installed(fitting.subject), "pending identity remains")
	fitting.refuse_after_seal = false
	assert_true(harness._router.complete_order(project).ok, "same paid work retries without repayment")
	assert_equal(fitting.completed, 1, "exactly one installation")
	_release_installation_fixture(harness)


func test_furniture_install_before_facts_reject_type_room_rotation_and_generation_drift() -> void:
	"""The sole installation exception never masks a changed real source identity or Room."""
	var harness: InstallationHarness = _installation_fixture()
	var fitting: InstallationOwner = harness.furniture_with_geometry()
	var project: Vector2i = harness._open(fitting)
	var job: Vector2i = harness._job(project)
	harness._start(project)
	harness._finish_labor(project, job)
	var buildings: Buildings = harness._construction.buildings()
	var row: int = buildings.directory().get_typed_row(fitting.subject)
	var before: PackedByteArray = fitting.geometry.state_bytes()
	for field: StringName in [&"_f_type_id", &"_f_room_generation", &"_f_rotation", &"_f_ref_generation"]:
		var token: int = fitting.geometry.begin_stage(fitting.geometry.revision()).token
		assert_equal(fitting.geometry.stage_furniture_install(token, project, harness._router, fitting), &"", "actual pending before-facts")
		assert_equal(fitting.geometry.seal(token), &"", "sealed exact d=1 candidate")
		assert_equal(fitting.geometry.prepared_refusal(token), &"", "fresh before-facts")
		assert_equal(fitting.geometry.publish_furniture_install(token, project, harness._router, fitting),
			&"SPACE_INSTALLATION_PUBLICATION", "no caller can manufacture a paid callback")
		var saved: PackedInt32Array = buildings.get(field).duplicate()
		var changed: PackedInt32Array = saved.duplicate()
		changed[row] += 1
		buildings.set(field, changed)
		assert_true(fitting.geometry.prepared_refusal(token) != &"", "changed actual %s refuses" % field)
		buildings.set(field, saved)
		assert_equal(fitting.geometry.prepared_refusal(token), &"", "restored exact actual facts")
		assert_true(fitting.geometry.abort(token), "abort owns only transient source")
		assert_equal(fitting.geometry.state_bytes(), before, "live bytes unchanged after %s" % field)
	_release_installation_fixture(harness)


func _admission_fixture() -> SyntheticAdmission:
	"""Observe the actual next Room without spending an allocator or inventing a live reference."""
	var commands: SyntheticAdmission = SyntheticAdmission.new()
	commands.owner = weakref(_buildings)
	commands.geometry = _owner
	commands.candidate = Directory.CreateCandidate.new()
	assert_equal(_buildings.directory().peek_create_into(Directory.KIND_ROOM, commands.candidate), &"", "actual future Room")
	assert_true(_buildings.bind_spatial_authority(commands).ok, "one real authority binding")
	return commands


func _stage_room_markers(commands: SyntheticAdmission) -> int:
	"""Fine256u planned shape is exact and remains an obstruction rather than free physical excavation."""
	var token: int = _begin()
	commands.token = token
	assert_equal(_owner.stage_room_admission(token, commands.candidate, commands.room_type, commands), &"", "typed future source")
	var future: Vector2i = commands.candidate.ref
	var floor_region: Owner.Region = _region([-768, 0, -256, 768, 1, 512], Space.FLOOR_DATUM, future)
	var section: Vector2i = _put(token, floor_region)
	var marker: Owner.Region = _region([-768, 0, -256, 768, 1536, 512], Space.OBSTACLE, future)
	marker.section = section
	marker.claim_kind = Owner.CLAIM_ROOM
	marker.claim_ref = future
	_put(token, marker)
	return token


func test_room_admission_keeps_exact_fine_plan_unpublished_until_real_identity() -> void:
	"""Only actual typed Room creation in its exact authority window can publish matching planned blockers."""
	var commands: SyntheticAdmission = _admission_fixture()
	var candidate: Directory.CreateCandidate = commands.candidate
	var before_pid: int = _buildings.directory().next_persistent_id()
	var token: int = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "fine plan seals without a paid cut")
	assert_equal(_owner.prepared_refusal(token), &"", "exact observed allocator still current")
	assert_false(_buildings.is_live_room(candidate.ref), "observation is not a Room")
	assert_equal(_buildings.directory().next_persistent_id(), before_pid, "no PID spent")
	_owner.publish(token)
	assert_true(_owner.has_prepared(), "generic publication cannot bypass Room authority")
	assert_equal(_owner.publish_room_admission(token, candidate, commands.room_type, commands),
		&"SPACE_ROOM_ADMISSION_PUBLICATION", "no direct caller publication")
	commands.publishing = true
	assert_equal(_owner.publish_room_admission(token, candidate, commands.room_type, commands),
		&"SPACE_ROOM_AFTER_IDENTITY", "authority window alone is not a live Room")
	assert_true(_buildings.designate_spatial_room_candidate(commands.room_type, candidate).ok, "actual Room allocation")
	assert_equal(_owner.publish_room_admission(token, candidate, commands.room_type, commands), &"", "exact after-facts")
	commands.publishing = false
	assert_equal(_buildings.directory().next_persistent_id(), before_pid + 1, "one PID consumed")
	assert_equal(_owner.source_refusal(candidate.ref), &"", "ordinary source reader now accepts real Room")
	var survey: Space.Snapshot = _snapshot()
	assert_equal(survey.volumes.role, PackedInt32Array([Space.FLOOR_DATUM, Space.OBSTACLE]), "no void or support created")
	assert_equal(survey.volumes.box_at(1), PackedInt32Array([-768, 0, -256, 768, 1536, 512]), "fine exact shape not rounded")
	assert_equal(_owner.publish_room_admission(token, candidate, commands.room_type, commands),
		&"SPACE_ROOM_ADMISSION_TOKEN", "same identity cannot republish")


func test_room_admission_mutable_candidate_fields_and_authority_are_rechecked() -> void:
	"""Mutating any observed allocator fact after preparation cannot rewrite the private pinned identity."""
	var commands: SyntheticAdmission = _admission_fixture()
	var before: PackedByteArray = _owner.state_bytes()
	for field: StringName in [&"ref", &"kind", &"typed_row", &"persistent_id"]:
		var token: int = _stage_room_markers(commands)
		assert_equal(_owner.seal(token), &"", "sealed original tuple")
		var saved: Variant = commands.candidate.get(field)
		if field == &"ref":
			commands.candidate.ref.y += 1
		else:
			commands.candidate.set(field, saved + 1)
		assert_equal(_owner.prepared_refusal(token), &"SPACE_ROOM_CANDIDATE", "changed %s" % field)
		assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands),
			&"SPACE_ROOM_ADMISSION_TOKEN", "changed publication tuple")
		commands.candidate.set(field, saved)
		commands.admitted = false
		assert_equal(_owner.prepared_refusal(token), &"SYNTHETIC_ROOM_NOT_PREPARED", "lost actual coordinator proof")
		commands.admitted = true
		assert_equal(_owner.prepared_refusal(token), &"", "exact prior state still valid")
		assert_true(_owner.abort(token), "abort staged source only")
		assert_equal(_owner.state_bytes(), before, "live source/geometry identical")


func test_room_admission_wrong_owner_type_candidate_and_stale_allocator_refuse() -> void:
	"""Coincident foreign numbers, changed purpose and consumed allocator observations never qualify."""
	var commands: SyntheticAdmission = _admission_fixture()
	var token: int = _begin()
	assert_equal(_owner.stage_room_admission(token, commands.candidate, commands.room_type, SyntheticAdmission.new()),
		&"SPACE_ROOM_ADMISSION_BINDING", "foreign authority")
	assert_equal(_owner.stage_room_admission(token, commands.candidate, -1, commands),
		Buildings.REFUSE_UNKNOWN_ROOM_TYPE, "unknown purpose")
	assert_equal(_owner.stage_room_admission(token, commands.candidate, Buildings.ROOM_TYPE_DORMITORY, commands),
		&"SYNTHETIC_ROOM_NOT_PREPARED", "changed permanent purpose")
	var other: Directory = Directory.new()
	var original_directory: WeakRef = commands.candidate._directory
	commands.candidate._directory = weakref(other)
	assert_true(_owner.stage_room_admission(token, commands.candidate, commands.room_type, commands) != &"", "foreign Directory")
	commands.candidate._directory = original_directory
	assert_equal(_owner.stage_source(token, commands.candidate.ref), &"SPACE_SOURCE_STALE", "ordinary reader rejects future facts")
	assert_true(_owner.abort(token), "preparation discarded")
	token = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "sealed unspent observation")
	var other_ref: Vector2i = _buildings.directory().create(Directory.KIND_JOB)
	assert_true(other_ref != NULL_REF, "another real allocation consumes the global root and PID")
	assert_true(_owner.prepared_refusal(token) != &"", "allocator changed after seal")
	assert_true(_owner.abort(token), "no rollback of another owner's real allocation")
	assert_true(_buildings.directory().is_valid(other_ref), "unrelated allocation remains real")
	assert_false(_buildings.is_live_room(commands.candidate.ref), "no accidental Room source")


func test_room_admission_all_physical_roles_and_unclaimed_geometry_refuse() -> void:
	"""Confirming a plan never provides support, a paid solid removal, unfinished work or walkable void."""
	var commands: SyntheticAdmission = _admission_fixture()
	var token: int = _begin()
	assert_equal(_owner.stage_room_admission(token, commands.candidate, commands.room_type, commands), &"", "future Room")
	assert_equal(_owner.seal(token), &"SPACE_ROOM_ADMISSION_FOOTPRINT", "empty identity is not an admitted floor plan")
	for role: int in Space.WORLD_ROLE_COUNT:
		if role == Space.FLOOR_DATUM:
			continue
		var region: Owner.Region = _region([0, 0, 0, 256, 1024, 256], role, commands.candidate.ref)
		assert_equal(_owner.stage_add(token, region).error, &"SPACE_ROOM_ADMISSION_REGION", "unclaimed/physical role %d" % role)
	var marker: Owner.Region = _region([0, 0, 0, 256, 1024, 256], Space.OBSTACLE, commands.candidate.ref)
	marker.claim_kind = Owner.CLAIM_ROOM
	marker.claim_ref = commands.candidate.ref
	assert_equal(_owner.stage_add(token, marker).error, &"SPACE_ROOM_ADMISSION_REGION", "missing actual planned section")
	assert_true(_owner.abort(token), "all rejected forms preserve live geometry")


func test_room_admission_after_facts_and_exact_publication_arguments_are_guarded() -> void:
	"""Actual allocation must retain exact Room purpose/domain and the same sealed invocation identity."""
	var commands: SyntheticAdmission = _admission_fixture()
	var token: int = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "sealed")
	commands.publishing = true
	var made: Buildings.OpResult = _buildings.designate_spatial_room_candidate(commands.room_type, commands.candidate)
	assert_true(made.ok, "actual Room")
	assert_equal(_owner.publish_room_admission(token + 1, commands.candidate, commands.room_type, commands),
		&"SPACE_ROOM_ADMISSION_TOKEN", "wrong token")
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type + 1, commands),
		&"SPACE_ROOM_ADMISSION_TOKEN", "wrong purpose")
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, SyntheticAdmission.new()),
		&"SPACE_ROOM_ADMISSION_TOKEN", "wrong owner")
	for field: StringName in [&"_r_type", &"_r_spatial_kind"]:
		var saved: Variant = _buildings.get(field).duplicate()
		var changed: Variant = saved.duplicate()
		changed[_buildings.directory().get_typed_row(made.ref)] += 1
		_buildings.set(field, changed)
		assert_true(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands) != &"", "changed %s" % field)
		_buildings.set(field, saved)
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands), &"", "exact real after-facts")


func test_room_admission_abort_retries_identical_future_identity_and_keeps_prior_claims() -> void:
	"""A rejected confirmation consumes no Room, source, region generation or PID, and does not erase prior space."""
	var initial: int = _begin()
	assert_equal(_owner.stage_source(initial, _room), &"", "existing actual Room")
	_put(initial, _region([2048, 0, 2048, 4096, 1, 4096], Space.FLOOR_DATUM, _room))
	_publish(initial)
	var commands: SyntheticAdmission = _admission_fixture()
	var ref: Vector2i = commands.candidate.ref
	var pid: int = commands.candidate.persistent_id
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "sealed candidate")
	assert_true(_owner.abort(token), "discard before actual identity allocation")
	assert_equal(_owner.state_bytes(), before, "every prior source and region unchanged")
	assert_equal(_buildings.directory().candidate_refusal(commands.candidate), &"", "same observed allocator still current")
	token = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "same plan can retry")
	commands.publishing = true
	assert_true(_buildings.designate_spatial_room_candidate(commands.room_type, commands.candidate).ok, "one actual allocation")
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands), &"", "one publication")
	assert_equal(_buildings.directory().get_persistent_id(ref), pid, "original exact persistent identity")
	assert_equal(_owner.source_refusal(_room), &"", "previous actual Room source retained")


func test_room_admission_callbacks_cannot_abort_rebegin_or_publish_the_stage() -> void:
	"""A reentrant attestation fails closed while preserving a clean abort/retry path and actual identity."""
	var commands: SyntheticAdmission = _admission_fixture()
	var before: PackedByteArray = _owner.state_bytes()
	var pid: int = _buildings.directory().next_persistent_id()
	for phase: int in [1, 3]:
		var token: int = _begin()
		commands.token = token
		commands.attack_phase = phase
		assert_equal(_owner.stage_room_admission(token, commands.candidate, commands.room_type, commands),
			&"SPACE_ROOM_ADMISSION_REENTRY", "candidate or owner callback mutation")
		assert_false(commands.abort_succeeded, "callback cannot drop caller stage")
		assert_equal(commands.rebegin_error, &"SPACE_ROOM_ADMISSION_REENTRY", "callback cannot start another stage")
		assert_true(_owner.has_prepared(), "original stage still belongs to caller")
		commands.attack_phase = 0
		assert_true(_owner.abort(token), "abort after callback releases all transient controls")
		assert_equal(_owner.state_bytes(), before, "all prior live bytes retained")
		assert_equal(_buildings.directory().next_persistent_id(), pid, "no identity consumed")
		token = _stage_room_markers(commands)
		assert_equal(_owner.seal(token), &"", "same plan retries without stale busy latch")
		assert_true(_owner.abort(token), "retry discarded cleanly")


func test_room_admission_seal_and_prepared_callbacks_guard_transaction_identity() -> void:
	"""The before-facts path is protected at sealing and final preflight, not only the first preparation."""
	var commands: SyntheticAdmission = _admission_fixture()
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _stage_room_markers(commands)
	commands.attack_phase = 1
	assert_equal(_owner.seal(token), &"SPACE_ROOM_ADMISSION_REENTRY", "seal callback abort attempt")
	assert_false(commands.abort_succeeded, "original unsealed stage retained")
	commands.attack_phase = 0
	assert_equal(_owner.seal(token), &"", "same exact geometry can seal after refusal")
	commands.attack_phase = 1
	assert_equal(_owner.prepared_refusal(token), &"SPACE_ROOM_ADMISSION_REENTRY", "sealed callback abort attempt")
	commands.attack_phase = 0
	assert_equal(_owner.prepared_refusal(token), &"", "refusal did not alter sealed geometry")
	assert_true(_owner.abort(token), "caller still owns cleanup")
	assert_equal(_owner.state_bytes(), before, "no live mutation")


func test_room_admission_publication_callback_cannot_destroy_the_sealed_candidate() -> void:
	"""A bad publication attestation cannot erase its stage even after actual identity publication."""
	var commands: SyntheticAdmission = _admission_fixture()
	var token: int = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "sealed")
	commands.publishing = true
	assert_true(_buildings.designate_spatial_room_candidate(commands.room_type, commands.candidate).ok, "actual Room allocated")
	commands.attack_phase = 2
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands),
		&"SPACE_ROOM_ADMISSION_REENTRY", "mutation cannot masquerade as pure publication proof")
	assert_false(commands.abort_succeeded, "sealed claim retained")
	assert_true(_owner.has_prepared(), "no half-published source")
	assert_equal(_owner.source_revision(commands.candidate.ref), 0, "future source not live")
	commands.attack_phase = 0
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands), &"", "same retained candidate publishes")
	assert_equal(_owner.source_refusal(commands.candidate.ref), &"", "exact actual after-facts")


func test_room_admission_callbacks_cannot_rewrite_the_pinned_allocator_packet() -> void:
	"""The private observation predates callbacks; mutating the supplied candidate never changes it."""
	var commands: SyntheticAdmission = _admission_fixture()
	var before: PackedByteArray = _owner.state_bytes()
	var pid: int = commands.candidate.persistent_id
	var token: int = _begin()
	commands.token = token
	commands.attack_phase = 1
	commands.change_packet = true
	assert_true(_owner.stage_room_admission(token, commands.candidate, commands.room_type, commands) != &"", "changed tuple refuses")
	commands.attack_phase = 0
	commands.candidate.persistent_id = pid
	assert_true(_owner.abort(token), "mutation refusal remains abortable")
	assert_equal(_owner.state_bytes(), before, "no future source or live change")
	token = _stage_room_markers(commands)
	assert_equal(_owner.seal(token), &"", "original observation remains usable")
	commands.publishing = true
	assert_true(_buildings.designate_spatial_room_candidate(commands.room_type, commands.candidate).ok, "actual Room")
	commands.attack_phase = 2
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands),
		&"SPACE_ROOM_CANDIDATE", "post-callback packet is rechecked")
	commands.attack_phase = 0
	commands.candidate.persistent_id = pid
	assert_equal(_owner.publish_room_admission(token, commands.candidate, commands.room_type, commands), &"", "exact candidate retained")


func test_actual_allocation_and_resident_location_readers_do_not_change_state() -> void:
	"""Composition must attest the actual capacities and actual location object before copying anything."""
	var absent: Owner = Owner.new(_sources)
	assert_false(absent.allocation_within(R, O), "unconfigured is not a zero-cost bound owner")
	var before: PackedByteArray = _owner.state_bytes()
	assert_true(_owner.allocation_within(R, O), "exact actual capacities")
	assert_true(_owner.allocation_within(Owner.I64_MAX, Owner.I64_MAX), "comparisons cannot overflow")
	for limits: Vector2i in [Vector2i(R - 1, O), Vector2i(R, O - 1), Vector2i(0, O), Vector2i(R, -1)]:
		assert_false(_owner.allocation_within(limits.x, limits.y), "undersized/nonpositive bound")
	assert_equal(_sources.resident_locations_owner(), null, "no implicit flat fallback")
	assert_equal(_owner.state_bytes(), before, "readers do not touch geometry")
	var actual: SyntheticLocations = _resident_locations()
	assert_true(_sources.resident_locations_owner() == actual, "exact actual containment provider")
	var foreign: SyntheticLocations = SyntheticLocations.new()
	foreign.residents = Residents.new()
	foreign.transforms = Transforms.new(foreign.residents.directory())
	var refused: Owner.CoreSources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction, foreign)
	assert_equal(refused.resident_locations_owner(), null, "foreign Directory cannot bind")


func _production_capacity_owner(sources: Owner.CoreSources = null) -> Owner:
	"""The exact admitted technical pack uses synthetic extents, never synthetic entity identities."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(1024, 16, 16),
		Space.MAX_CELLS, Space.MAX_REGIONS, Space.MAX_CHECKS), &"", "actual maximum work ceiling")
	var owner: Owner = Owner.new(_sources if sources == null else sources)
	assert_equal(owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "real joint pack")
	assert_equal(owner.packed_memory_bytes(), Budget.SPACE_BANK_BYTES, "no new packed allocation")
	return owner


func test_joint_capacity_minimal_stage_and_restore_fit_the_unchanged_work_limit() -> void:
	"""An empty R6144/O2048 arena can seal and restore one exact row without a capacity product."""
	var large: Owner = _production_capacity_owner()
	var token: int = large.begin_stage(large.revision()).token
	var added: Owner.Result = large.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	assert_equal(added.error, &"", "minimal actual row")
	assert_equal(large.seal(token), &"", "capacity alone does not consume quadratic work")
	print("SPACE-CAPACITY minimal seal checks=", Space.MAX_CHECKS - large._remaining)
	large.publish(token)
	var saved: PackedByteArray = large.state_bytes()
	var restored: Owner = _production_capacity_owner()
	assert_equal(restored.restore_state_bytes(saved), &"", "minimal actual-pack load")
	print("SPACE-CAPACITY minimal restore checks=", Space.MAX_CHECKS - restored._remaining)
	assert_equal(restored.state_bytes(), saved, "all saved source revisions preserved")
	assert_true(restored.is_live_region(added.handle), "same exact region generation")


func _large_occupant_batch(large: Owner, fixture: SyntheticLocations) -> PackedInt32Array:
	"""Create 256 real living Residents/Transforms and explicit synthetic extent packets in one transaction."""
	var token: int = large.begin_stage(large.revision()).token
	var refs: PackedInt32Array = PackedInt32Array()
	for index: int in Residents.RESIDENT_LIVING_CAP:
		var resident: Vector2i = fixture.residents.spawn(&"mouse").ref
		var x: int = index * 1024
		assert_true(fixture.transforms.place(resident, x + 64, 64, 64, 0), "actual body anchor")
		assert_equal(large.stage_source(token, resident), &"", "actual source generation")
		var added: Owner.Result = large.stage_add(token,
			_region([x, 0, 0, x + 512, 1024, 512], Space.OCCUPANT, resident))
		assert_equal(added.error, &"", "actual resident extent")
		refs.append(resident.x)
		refs.append(resident.y)
	assert_equal(large.seal(token), &"", "all 256 sources, bounds and overlap checks fit")
	print("SPACE-CAPACITY 256 residents seal checks=", Space.MAX_CHECKS - large._remaining)
	large.publish(token)
	return refs


func test_joint_capacity_256_actual_residents_batch_edit_and_restore() -> void:
	"""All living residents fit one cold source/geometry transaction without a per-capacity nested scan."""
	var fixture: SyntheticLocations = _resident_locations()
	fixture.containing_room = NULL_REF
	var large: Owner = _production_capacity_owner(_sources)
	var refs: PackedInt32Array = _large_occupant_batch(large, fixture)
	assert_equal(refs.size(), Residents.RESIDENT_LIVING_CAP * 2, "the actual living cap only")
	var saved: PackedByteArray = large.state_bytes()
	var restored: Owner = _production_capacity_owner(_sources)
	assert_equal(restored.restore_state_bytes(saved), &"", "all 256 actual residents restore")
	print("SPACE-CAPACITY 256 residents restore checks=", Space.MAX_CHECKS - restored._remaining)
	assert_equal(restored.state_bytes(), saved, "byte-exact identity/geometry image")
	var token: int = restored.begin_stage(restored.revision()).token
	assert_equal(restored.stage_remove(token, Vector2i(127, 1)), &"", "one actual resident moves within its envelope")
	var resident: Vector2i = Vector2i(refs[254], refs[255])
	var x: int = 127 * 1024
	var next: Owner.Result = restored.stage_add(token, _region([x, 0, 0, x + 768, 1024, 512], Space.OCCUPANT, resident))
	assert_equal(next.handle, Vector2i(127, 2), "only exact freed row reused")
	assert_equal(restored.seal(token), &"", "one changed body still checks every retained source")
	print("SPACE-CAPACITY 256 residents single edit checks=", Space.MAX_CHECKS - restored._remaining)
	restored.publish(token)
	assert_false(restored.is_live_region(Vector2i(127, 1)), "old generation cannot alias edited body")


func test_failed_seal_restores_heaps_for_edit_retry_and_source_revision_propagation() -> void:
	"""A contradictory candidate can be edited after refusal; retained same-source rows receive one new revision."""
	var token: int = _begin()
	var kept: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	_publish(token)
	var previous: int = _owner.source_revision(_world)
	token = _begin()
	var bad: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.SUPPORTED_VOID, _world))
	assert_equal(_owner.seal(token), &"SPACE_SURVEY_CONTRADICTION", "strict overlap gate remains")
	assert_equal(_owner.stage_remove(token, bad), &"", "failed seal restored allocators before editing")
	var good: Vector2i = _put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.SUPPORTED_VOID, _world))
	assert_equal(good, Vector2i(bad.x, bad.y + 1), "same minimum free row, fresh generation")
	_publish(token)
	assert_equal(_owner.source_revision(_world), previous + 1, "one source revision per transaction")
	var retained: Owner.Region = Owner.Region.new()
	assert_equal(_owner.region_into(kept, retained), &"", "unchanged extent stays live")
	var image: Space.Snapshot = _snapshot()
	assert_equal(image.volumes.owner_revision, PackedInt64Array([previous + 1, previous + 1]), "retained and new revisions agree")


func test_indexed_validation_preserves_mixed_remove_reuse_and_strict_loaded_revisions() -> void:
	"""Source index order differs from slot order; a load never repairs an invalid saved geometry revision."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "later global slot registers first")
	assert_equal(_owner.stage_source(token, _hall), &"", "earlier global slot registers second")
	var removed: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	_put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.OBSTACLE, _world))
	_publish(token)
	token = _begin()
	assert_equal(_owner.stage_remove(token, removed), &"", "retire one geometry row")
	assert_equal(_owner.stage_forget_source(token, _hall), &"", "retire nonlast source slot")
	var bed: Vector2i = _buildings.place_furniture(_room, int(Catalog.FURNITURE_DEFINITION["bed"]), 60 * 128 + 59, 0).ref
	assert_equal(_owner.stage_source(token, bed), &"", "reuse source row with a different actual full ref")
	var next: Vector2i = _put(token, _region([2048, 0, 0, 3072, 1024, 1024], Space.OBSTACLE, _world))
	assert_equal(next, Vector2i(removed.x, removed.y + 1), "reuse region row")
	_publish(token)
	var saved: PackedByteArray = _owner.state_bytes()
	var broken: PackedByteArray = saved.duplicate()
	broken.encode_s64(144 + 52 * R, _owner.source_revision(_world) - 1)
	assert_equal(_owner.restore_state_bytes(broken), &"SPACE_SOURCE_STALE", "load does not normalize a stale region revision")
	assert_equal(_owner.state_bytes(), saved, "failed indexed load preserves live rows and allocators")
	assert_equal(_owner.restore_state_bytes(saved), &"", "valid image succeeds after failed indexed load")
	assert_equal(_owner.state_bytes(), saved, "exact schema remains unchanged")
	assert_equal(_owner.source_refusal(bed), &"", "new source retains exact facts")
	assert_equal(_owner.source_refusal(_hall), &"SPACE_SOURCE_NOT_REGISTERED", "old source cannot return through sorted scratch")


func test_validation_callbacks_cannot_mutate_borrowed_heap_indexes() -> void:
	"""Even a hostile source reader cannot abort/rebegin or allocate while staged heaps hold indexes."""
	var source: ReentrantSources = ReentrantSources.new(_buildings.directory(), _buildings, _construction)
	var owner: Owner = Owner.new(source)
	assert_equal(owner.configure(_domain, R, O), &"", "same actual owners")
	source.geometry = weakref(owner)
	source.token = owner.begin_stage(owner.revision()).token
	assert_equal(owner.stage_source(source.token, _room), &"", "register outside callback")
	source.attack = true
	assert_equal(owner.seal(source.token), &"", "pure evidence still validates while rejected writes cannot run")
	assert_false(source.abort_succeeded, "callback could not discard borrowed arrays")
	assert_equal(source.edit_error, &"SPACE_VALIDATION_BUSY", "callback cannot pop an index as a free slot")
	assert_equal(source.begin_error, &"SPACE_TRANSACTION_BUSY", "callback cannot replace either bank")
	source.attack = false
	assert_true(owner.abort(source.token), "normal cleanup works after indexes became heaps again")
	var token: int = owner.begin_stage(owner.revision()).token
	var added: Owner.Result = owner.stage_add(token, _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world))
	assert_equal(added.handle, Vector2i(0, 1), "retry gets the actual minimum free slot")
	assert_equal(owner.seal(token), &"", "retry retains a valid source index")
	owner.publish(token)


func test_true_pair_work_exhaustion_refuses_without_expanding_the_budget() -> void:
	"""1024 static world extents are geometry, not residents; genuinely excessive pair work still refuses."""
	var owner: Owner = _production_capacity_owner()
	var before: PackedByteArray = owner.state_bytes()
	var token: int = owner.begin_stage(owner.revision()).token
	var region: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	for index: int in 1024:
		assert_equal(owner.stage_add(token, region).error, &"", "finite rows fit before expensive validation")
	assert_equal(owner.seal(token), &"SPACE_OPERATION_BUDGET", "the original 1048576-check ceiling remains")
	assert_equal(owner._remaining, 0, "actual checks exhaust the finite budget")
	assert_equal(owner._validation_regions, -1, "failed validation released region-index borrowing")
	assert_equal(owner._validation_sources, -1, "failed validation released source-index borrowing")
	assert_true(owner.abort(token), "caller can release the refused candidate")
	assert_equal(owner.state_bytes(), before, "no partial source or geometry publication")
	token = owner.begin_stage(owner.revision()).token
	var next: Owner.Result = owner.stage_add(token, region)
	assert_equal(next.handle, Vector2i(0, 1), "aborted history cannot consume a live generation")
	assert_equal(owner.seal(token), &"", "small retry at unchanged capacity succeeds")
	owner.publish(token)


func test_same_source_forget_and_reregister_never_resets_its_revision() -> void:
	"""Source-row relocation within one transaction preserves monotonic full-identity revisions."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "source row one")
	assert_equal(_owner.stage_source(token, _hall), &"", "source row two")
	_publish(token)
	var old: int = _owner.source_revision(_hall)
	token = _begin()
	assert_equal(_owner.stage_forget_source(token, _room), &"", "make earlier source row free")
	assert_equal(_owner.stage_forget_source(token, _hall), &"", "release same actual source")
	assert_equal(_owner.stage_source(token, _hall), &"", "same full identity moves to minimum row")
	_publish(token)
	assert_equal(_owner.source_revision(_hall), old + 1, "identity revision never returns to one")
	assert_equal(_owner.source_refusal(_hall), &"", "relocated source facts still read actual Buildings")


func test_snapshot_revision_reader_checks_current_geometry_and_preserves_live_bytes() -> void:
	"""The public preflight copies nothing and compares the exact live revision, including during staging."""
	var absent: Owner = Owner.new(_sources)
	assert_equal(absent.snapshot_revision_refusal(0), &"SPACE_WORLD_UNBOUND", "missing owner cannot attest zero")
	var previous: int = _owner.revision()
	var before: PackedByteArray = _owner.state_bytes()
	assert_equal(_owner.snapshot_revision_refusal(previous), &"", "empty actual image is current")
	assert_equal(_owner.snapshot_revision_refusal(previous + 1), &"SPACE_REVISION_STALE", "future revision")
	assert_equal(_owner.state_bytes(), before, "read-only preflight")
	var token: int = _begin()
	_put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	assert_equal(_owner.snapshot_revision_refusal(previous), &"", "unpublished candidate cannot change live image")
	_publish(token)
	assert_equal(_owner.snapshot_revision_refusal(previous), &"SPACE_REVISION_STALE", "prior copied geometry is stale")
	assert_equal(_owner.snapshot_revision_refusal(_owner.revision()), &"", "new exact live revision")


func test_snapshot_revision_reader_revalidates_source_and_claim_lifetimes() -> void:
	"""A matching geometry revision does not excuse actual source drift, stale claims or a destroyed World."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "actual Building structural facts")
	_publish(token)
	var expected: int = _owner.revision()
	assert_equal(_owner.snapshot_revision_refusal(expected), &"", "actual source matches")
	var original_interior: int = _buildings.interior_id_of_building(_hall).value
	assert_true(_buildings.set_building_interior_id(_hall, 91).ok, "change actual source without geometry publication")
	assert_equal(_owner.snapshot_revision_refusal(expected), &"SPACE_SOURCE_DRIFT", "fresh structural evidence required")
	assert_true(_buildings.set_building_interior_id(_hall, original_interior).ok, "restore actual authored fixture source")
	var project: Vector2i = _construction.open_build(_hall).ref
	token = _begin()
	var claim: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _world)
	claim.claim_kind = Owner.CLAIM_CONSTRUCTION
	claim.claim_ref = project
	_put(token, claim)
	_publish(token)
	expected = _owner.revision()
	assert_equal(_owner.snapshot_revision_refusal(expected), &"", "exact live claim")
	assert_true(_buildings.directory().destroy(project), "retire actual claimed project")
	assert_equal(_owner.snapshot_revision_refusal(expected), &"SPACE_SOURCE_STALE", "claim generation rechecked")
	assert_true(_buildings.directory().destroy(_world), "retire actual World")
	assert_equal(_owner.snapshot_revision_refusal(expected), &"SPACE_SOURCE_STALE", "world lifetime rechecked")


func test_reusable_region_reader_has_explicit_borrowed_output_contract() -> void:
	"""Hot readers overwrite borrowed scratch; explicit duplicates and the old allocating reader remain stable."""
	var token: int = _begin()
	var first: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var second: Vector2i = _put(token, _region([2048, 0, 0, 3072, 1024, 1024], Space.DRY_SOLID, _world))
	_publish(token)
	var out: Owner.Region = Owner.Region.new()
	out.box.resize(6)
	assert_equal(_owner.region_into_reused(first, out), &"", "preallocated scratch accepted")
	var retained: PackedInt32Array = out.box.duplicate()
	assert_equal(_owner.region_into_reused(second, out), &"", "next read reuses caller shape")
	assert_equal(retained, PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), "retained prior value unchanged")
	assert_equal(out.box, PackedInt32Array([2048, 0, 0, 3072, 1024, 1024]), "complete second physical box")
	out.box[0] = 99
	assert_equal(_owner.region_into_reused(second, out), &"", "caller mutation is not authority")
	assert_equal(out.box[0], 2048, "source column copied again")
	var previous: PackedInt32Array = out.box.duplicate()
	assert_equal(_owner.region_into_reused(Vector2i(second.x, second.y + 1), out), &"SPACE_REGION_STALE", "full generation required")
	assert_equal(out.box, previous, "refused output unchanged")


func test_region_reader_keeps_allocating_contract_and_reused_reader_refuses_wrong_shape() -> void:
	"""Existing reads replace their output array; the explicit hot reader never allocates missing scratch."""
	var token: int = _begin()
	var first: Vector2i = _put(token, _region([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID, _world))
	var second: Vector2i = _put(token, _region([2048, 0, 0, 3072, 1024, 1024], Space.DRY_SOLID, _world))
	_publish(token)
	var out: Owner.Region = Owner.Region.new()
	assert_equal(_owner.region_into_reused(first, out), &"SPACE_REGION_OUTPUT_SHAPE", "no hidden hot allocation")
	assert_true(out.box.is_empty(), "refused scratch remains untouched")
	assert_equal(_owner.region_into(first, out), &"", "original allocating reader")
	var prior: PackedInt32Array = out.box
	assert_equal(_owner.region_into(second, out), &"", "original replaces array")
	assert_equal(prior[0], 0, "prior old-reader array remains isolated")
	var borrowed: PackedInt32Array = out.box
	assert_equal(_owner.region_into_reused(first, out), &"", "explicit borrowed-scratch call")
	assert_equal(borrowed[0], 0, "borrowed alias visibly overwritten by contract")


func _batch_fixture() -> AdmissionBatchHarness:
	"""Own an isolated actual Router fixture and propagate every nested helper assertion."""
	var harness: AdmissionBatchHarness = AdmissionBatchHarness.new()
	harness.before_each()
	return harness


func _release_batch_fixture(harness: AdmissionBatchHarness) -> void:
	"""Drop the actual callback graph and verify nested helper evidence before fixture retirement."""
	if harness.batch_fitting().token != 0:
		harness.batch_fitting().geometry.abort(harness.batch_fitting().token)
		harness.batch_fitting().token = 0
	harness.after_each()
	assert_true(harness.failures.is_empty(), "actual paired fixture checks: %s" % harness.failures)


func test_future_furniture_batch_publishes_actual_pairs_and_blockers_only() -> void:
	"""Every real Furniture/Construction pair and exact pending source publishes, without installed service grants."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	assert_equal(Owner.furniture_admission_cold_bytes(3), 196, "exact60N private payload plus16 controls")
	for count: int in [-1, 0, Space.MAX_REGIONS + 1, 9223372036854775807]:
		assert_equal(Owner.furniture_admission_cold_bytes(count), 0, "invalid count refuses before multiplication")
	var result: Construction.OpResult = harness._router.open_furniture_batch(fitting, harness._room, harness._batch, harness._entries)
	assert_true(result.ok, "actual paired Router: %s" % result.error)
	assert_equal(fitting.published_code, &"", "same-stack future source publication")
	assert_equal(fitting.geometry._furniture_pins.size() + fitting.geometry._furniture_entries.size()
		+ fitting.geometry._furniture_rows.size(), 0, "all private copies released")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(fitting.geometry.snapshot_into(image), &"", "all after-facts now real")
	assert_equal(image.volumes.role, PackedInt32Array([Space.FLOOR_DATUM, Space.OBSTACLE, Space.OBSTACLE, Space.OBSTACLE]), "no free void/support")
	for index: int in range(0, harness._batch.count, 2):
		harness._assert_pair(index)
		assert_equal(fitting.geometry.source_refusal(harness._batch.ref_at(index)), &"", "actual pending source")
		assert_equal(fitting.geometry.source_revision(harness._batch.ref_at(index + 1)), 0, "no invented master/project source")
	_release_batch_fixture(harness)


func test_future_furniture_batch_whole_refusal_keeps_geometry_allocator_and_goods() -> void:
	"""A late companion refusal retains every original owner byte and retries the same exact observation."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var before: PackedByteArray = fitting.geometry.state_bytes()
	fitting.refuse_after_seal = true
	harness._refused_unchanged()
	assert_equal(fitting.geometry.state_bytes(), before, "no pending geometry prefix")
	assert_equal(fitting.geometry._furniture_pins.size() + fitting.geometry._furniture_entries.size()
		+ fitting.geometry._furniture_rows.size(), 0, "aborted copies released before lease")
	fitting.refuse_after_seal = false
	assert_true(harness._router.open_furniture_batch(fitting, harness._room, harness._batch, harness._entries).ok, "same observation retries")
	assert_equal(fitting.published_code, &"", "one actual geometry publication")
	assert_equal(fitting.publications, 1, "exactly one paired publication")
	_release_batch_fixture(harness)


func test_future_furniture_batch_rechecks_all_mutable_tuple_and_entry_fields() -> void:
	"""Prepared permission pins both kinds' slot/generation/kind/row/PID and every exact layout integer."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	assert_equal(fitting.stage_candidate(harness._entries), &"", "future sources")
	assert_equal(fitting.add_candidate_regions(), &"", "all occupied envelopes")
	assert_equal(fitting.geometry.seal(fitting.token), &"", "sealed")
	for field: StringName in [&"slots", &"generations", &"kinds", &"typed_rows", &"persistent_ids"]:
		var values: PackedInt32Array = harness._batch.get(field)
		for index: int in [0, 1]:
			var saved: int = values[index]
			values[index] += 1
			assert_true(fitting.geometry.prepared_refusal(fitting.token) != &"", "changed actual tuple refuses")
			values[index] = saved
	for index: int in harness._entries.size():
		var saved: int = harness._entries[index]
		harness._entries[index] += 1
		assert_true(fitting.geometry.prepared_refusal(fitting.token) != &"", "changed type/XYZ/rotation refuses")
		harness._entries[index] = saved
	assert_equal(fitting.geometry.prepared_refusal(fitting.token), &"", "restored exact packet retains permission")
	var late: Vector2i = harness._residents.directory().create(Directory.KIND_RESIDENT)
	assert_true(late != NULL_REF, "actual allocator moved")
	assert_true(fitting.geometry.prepared_refusal(fitting.token) != &"", "stale next-identity observation refuses")
	_release_batch_fixture(harness)


func test_future_furniture_batch_requires_every_piece_and_forbids_physical_permissions() -> void:
	"""Missing pieces and fabricated air/support are rejected before any actual identities publish."""
	for role: int in [Space.SUPPORTED_VOID, Space.SUPPORT, Space.UNFINISHED, Space.FLOOR_DATUM]:
		var harness: AdmissionBatchHarness = _batch_fixture()
		var fitting: AdmissionBatchOwner = harness.batch_fitting()
		var before: PackedByteArray = fitting.geometry.state_bytes()
		fitting.region_role = role
		harness._refused_unchanged()
		assert_equal(fitting.geometry.state_bytes(), before, "forbidden role retains actual prior state")
		_release_batch_fixture(harness)
	var missing: AdmissionBatchHarness = _batch_fixture()
	missing.batch_fitting().skip_last = true
	missing._refused_unchanged()
	_release_batch_fixture(missing)


func test_future_furniture_batch_refuses_foreign_binding_and_unscoped_publication() -> void:
	"""An equal-looking Authority/Room/token never replaces exact actual owner or same-stack Router evidence."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var before: PackedByteArray = fitting.geometry.state_bytes()
	var foreign: BatchAuthority = BatchAuthority.new()
	foreign.owner = weakref(harness._buildings)
	fitting.token = fitting.geometry.begin_stage(fitting.geometry.revision()).token
	assert_equal(fitting.geometry.stage_furniture_admissions(fitting.token, harness._batch, harness._room,
		harness._entries, foreign), &"SPACE_ROOM_ADMISSION_BINDING", "exact one authority")
	assert_true(fitting.geometry.stage_furniture_admissions(fitting.token, harness._batch, NULL_REF,
		harness._entries, harness._authority) != &"", "actual Room required")
	assert_equal(fitting.geometry.stage_furniture_admissions(fitting.token, harness._batch, harness._room,
		harness._entries, harness._authority), &"", "current actual packet")
	assert_equal(fitting.add_candidate_regions(), &"", "all occupied boxes")
	assert_equal(fitting.geometry.seal(fitting.token), &"", "sealed")
	var revision: int = fitting.geometry.revision()
	fitting.geometry.publish(fitting.token)
	assert_equal(fitting.geometry.revision(), revision, "generic publish cannot create future facts")
	assert_equal(fitting.geometry.publish_furniture_admissions(fitting.token, harness._batch, harness._room,
		harness._entries, harness._authority), &"SPACE_FURNITURE_ADMISSION_PUBLICATION", "no forged actual Router window")
	assert_true(fitting.geometry.abort(fitting.token), "owner abort remains available")
	fitting.token = 0
	assert_equal(fitting.geometry.state_bytes(), before, "unscoped publication preserved live bytes")
	_release_batch_fixture(harness)


func test_future_furniture_batch_callback_reentry_and_request_rewrite_refuse() -> void:
	"""Even initial and prepared attestations cannot abort/rebegin or swap in an edited request."""
	for phase: int in [0, 1]:
		var harness: AdmissionBatchHarness = _batch_fixture()
		var fitting: AdmissionBatchOwner = harness.batch_fitting()
		var authority: BatchAuthority = harness._authority as BatchAuthority
		var before: PackedByteArray = fitting.geometry.state_bytes()
		if phase == 1:
			assert_equal(fitting.stage_candidate(harness._entries), &"", "prepared sources")
			assert_equal(fitting.add_candidate_regions(), &"", "candidate boxes")
		authority.attack_phase = 1
		var code: StringName = fitting.stage_candidate(harness._entries) if phase == 0 else fitting.geometry.seal(fitting.token)
		assert_equal(code, &"SPACE_ROOM_ADMISSION_REENTRY", "callback cannot steal inactive bank")
		assert_false(authority.aborted, "callback abort refused")
		assert_equal(authority.rebegin_error, &"SPACE_ROOM_ADMISSION_REENTRY", "callback rebegin refused")
		authority.attack_phase = 0
		assert_true(fitting.geometry.abort(fitting.token), "caller can abort after callback refusal")
		fitting.token = 0
		assert_equal(fitting.geometry.state_bytes(), before, "byte-exact prior geometry")
		_release_batch_fixture(harness)


func test_future_furniture_batch_source_capacity_refuses_before_private_copies() -> void:
	"""Technical arena exhaustion is atomic, without silently limiting a room or truncating its fitting plan."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var source: Owner.CoreSources = Owner.CoreSources.new(harness._construction.directory(), harness._buildings, harness._construction)
	var smaller: Owner = Owner.new(source)
	assert_equal(smaller.configure(fitting.geometry.domain_copy(), 8, 3), &"", "finite World plus two sources")
	var token: int = smaller.begin_stage(smaller.revision()).token
	assert_equal(smaller.stage_furniture_admissions(token, harness._batch, harness._room, harness._entries,
		harness._authority), &"SPACE_FURNITURE_ADMISSION_CAPACITY", "three fits cannot fit two available rows")
	assert_equal(smaller._furniture_pins.size() + smaller._furniture_entries.size() + smaller._furniture_rows.size(), 0, "no private copies")
	assert_true(smaller.abort(token), "unchanged source bank remains abortable")
	_release_batch_fixture(harness)


func test_future_furniture_batch_after_facts_require_real_pending_rows_and_project_pairs() -> void:
	"""Adversarial typed-row drift after allocation cannot make a sealed future source masquerade as actual."""
	for field: StringName in [&"_f_type_id", &"_f_rotation", &"_f_room_generation", &"_subject_generation", &"_purpose", &"_type_id"]:
		var harness: AdmissionBatchHarness = _batch_fixture()
		var fitting: AdmissionBatchOwner = harness.batch_fitting()
		var before: PackedByteArray = fitting.geometry.state_bytes()
		fitting.after_drift = field
		assert_true(harness._router.open_furniture_batch(fitting, harness._room, harness._batch, harness._entries).ok,
			"negative fixture deliberately corrupts after actual pairs exist")
		assert_true(fitting.published_code != &"", "actual changed after-fact %s refuses" % field)
		assert_true(fitting.geometry.abort(fitting.token), "discard rejected geometry only")
		fitting.token = 0
		assert_equal(fitting.geometry.state_bytes(), before, "no future geometry became authoritative")
		_release_batch_fixture(harness)


func test_future_furniture_batch_publication_callback_reentry_keeps_sealed_geometry() -> void:
	"""After real paired allocation even a hostile publication attestation cannot swap or destroy the Space bank."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var before: PackedByteArray = fitting.geometry.state_bytes()
	var authority: BatchAuthority = harness._authority as BatchAuthority
	authority.attack_phase = 2
	assert_true(harness._router.open_furniture_batch(fitting, harness._room, harness._batch, harness._entries).ok,
		"negative fixture reaches actual post-identity callback")
	assert_equal(fitting.published_code, &"SPACE_ROOM_ADMISSION_REENTRY", "guarded same-stack callback")
	assert_false(authority.aborted, "no hidden abort")
	assert_equal(authority.rebegin_error, &"SPACE_ROOM_ADMISSION_REENTRY", "no replacement bank")
	authority.attack_phase = 0
	assert_true(fitting.geometry.abort(fitting.token), "real coordinator can discard its failed fixture candidate")
	fitting.token = 0
	assert_equal(fitting.geometry.state_bytes(), before, "live bank was never exchanged")
	_release_batch_fixture(harness)


func test_future_furniture_batch_callback_mutation_and_same_room_floor_generation_refuse() -> void:
	"""The real coordinator's initial pins precede copying; a future source also needs the exact live floor generation."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var authority: BatchAuthority = harness._authority as BatchAuthority
	authority.attack_phase = 1
	authority.mutate_packet = true
	assert_true(fitting.stage_candidate(harness._entries) != &"", "rewriting caller entry cannot change accepted plan")
	assert_equal(fitting.geometry._furniture_pins.size(), 0, "initial rewritten packet was never copied")
	assert_true(fitting.geometry.abort(fitting.token), "abort refused initial plan")
	fitting.token = 0
	authority.attack_phase = 0
	harness._prepare()
	assert_equal(fitting.stage_candidate(harness._entries), &"", "exact retry")
	fitting.floor_ref.y += 1
	assert_equal(fitting.add_candidate_regions(), &"", "record input remains staged only")
	assert_equal(fitting.geometry.seal(fitting.token), &"SPACE_SECTION_STALE", "same Room cannot borrow another floor generation")
	_release_batch_fixture(harness)


func test_future_furniture_batch_seals_under_real_joint_sparse_capacities() -> void:
	"""The unchanged R6144/O2048 arena can admit a real small fitting batch inside MAX_CHECKS."""
	var harness: AdmissionBatchHarness = _batch_fixture()
	var fitting: AdmissionBatchOwner = harness.batch_fitting()
	var source: Owner.CoreSources = Owner.CoreSources.new(harness._construction.directory(), harness._buildings, harness._construction)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(harness._world, Vector3i.ZERO, Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 8192, 8192, Space.MAX_CHECKS), &"", "explicit actual joint capacities")
	fitting.geometry = Owner.new(source)
	assert_equal(fitting.geometry.configure(domain, 6144, 2048), &"", "full sparse arena")
	var begun: Owner.Result = fitting.geometry.begin_stage(1)
	assert_equal(fitting.geometry.stage_source(begun.token, harness._room), &"", "actual Room source")
	var floor_region: Owner.Region = _region([-8192, 0, -8192, 8192, 1, 8192], Space.FLOOR_DATUM, harness._room)
	var added: Owner.Result = fitting.geometry.stage_add(begun.token, floor_region)
	assert_equal(added.error, &"", "floor datum")
	fitting.floor_ref = added.handle
	assert_equal(fitting.geometry.seal(begun.token), &"", "metadata fits unchanged work limit")
	fitting.geometry.publish(begun.token)
	assert_true(harness._router.open_furniture_batch(fitting, harness._room, harness._batch, harness._entries).ok, "actual three-pair batch")
	assert_equal(fitting.published_code, &"", "sealed source published under full pack")
	assert_true(fitting.geometry._remaining > 0, "bounded comparisons did not raise MAX_CHECKS")
	print("UG1075_FURNITURE full_pack_checks=", Space.MAX_CHECKS - fitting.geometry._remaining)
	_release_batch_fixture(harness)


func _traversal_fixture_rows(token: int) -> void:
	"""Room ownership markers and actual physical matter remain separate typed records."""
	assert_equal(_owner.stage_source(token, _room), &"", "actual Room source")
	var marker: Owner.Region = _region([0, 0, 0, 1024, 1024, 1024], Space.OBSTACLE, _room)
	marker.claim_kind = Owner.CLAIM_ROOM
	marker.claim_ref = _room
	_put(token, marker)
	_room_claim(token) # A legacy UNFINISHED-typed claim is deliberately not a traversal marker.
	_put(token, _region([0, 0, 0, 256, 1024, 256], Space.OBSTACLE, _room))
	_put(token, _region([256, 0, 0, 512, 1024, 256], Space.UNFINISHED, _room))
	_put(token, _region([512, 0, 0, 768, 1024, 256], Space.PROTECTED_ACCESS, _room))
	var project: Vector2i = _construction.open_build(_hall).ref
	var phase: Owner.Region = _region([2048, 0, 0, 2304, 1024, 256], Space.OBSTACLE, _room)
	phase.claim_kind = Owner.CLAIM_CONSTRUCTION
	phase.claim_ref = project
	_put(token, phase)


func test_traversal_snapshot_omits_only_typed_room_owned_obstacle_markers() -> void:
	"""An accepted outline cannot block a finished doorway or erase the actual same-Room wall beside it."""
	var token: int = _begin()
	_traversal_fixture_rows(token)
	_publish(token)
	var before: PackedByteArray = _owner.state_bytes()
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_owner.snapshot_for_traversal_into(image), &"", "source-validated traversal observation")
	assert_equal(image.volumes.role, PackedInt32Array([Space.OBSTACLE, Space.OBSTACLE,
		Space.UNFINISHED, Space.PROTECTED_ACCESS, Space.OBSTACLE]), "only typed reservation omitted")
	assert_equal(image.volumes.box_at(1), PackedInt32Array([0, 0, 0, 256, 1024, 256]), "actual wall retained")
	assert_equal(image.volumes.box_at(2), PackedInt32Array([256, 0, 0, 512, 1024, 256]), "unfinished cut retained")
	assert_equal(_snapshot().volumes.role.size(), 6, "ordinary placement survey remains complete")
	assert_equal(_owner.state_bytes(), before, "observation changes no physical or claim state")


func test_prepared_traversal_snapshot_keeps_physical_rows_and_exact_token() -> void:
	"""The same narrow predicate observes sealed geometry without publishing it or bypassing stale sources."""
	var before: PackedByteArray = _owner.state_bytes()
	var token: int = _begin()
	_traversal_fixture_rows(token)
	var image: Space.Snapshot = Space.Snapshot.new()
	image.revision = 901
	assert_equal(_owner.prepared_snapshot_for_traversal_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "no unsealed facts")
	assert_equal(image.revision, 901, "refusal preserves output")
	assert_equal(_owner.seal(token), &"", "exact actual candidate")
	assert_equal(_owner.prepared_snapshot_for_traversal_into(token + 1, image), &"SPACE_TRANSACTION_UNSEALED", "full token")
	assert_equal(_owner.prepared_snapshot_for_traversal_into(token, image), &"", "sealed traversal truth")
	assert_equal(image.volumes.role.size(), 5, "same exact physical retention as live view")
	image.volumes.hi_x[0] = 777
	assert_equal(_owner.prepared_snapshot_for_traversal_into(token, image), &"", "independent copied output")
	assert_equal(image.volumes.hi_x[0], 1024, "caller cannot mutate claim geometry")
	assert_equal(_snapshot().volumes.role.size(), 0, "no live geometry publication")
	assert_true(_owner.abort(token), "discard candidate")
	assert_equal(_owner.prepared_snapshot_for_traversal_into(token, image), &"SPACE_TRANSACTION_UNSEALED", "expired token")
	assert_equal(_owner.state_bytes(), before, "abort restores unchanged live bytes")


func test_traversal_source_and_claim_lifetime_are_not_exempted() -> void:
	"""The omitted shape still requires its actual full Room identity and exact source facts."""
	var token: int = _begin()
	_traversal_fixture_rows(token)
	_publish(token)
	var image: Space.Snapshot = Space.Snapshot.new()
	image.revision = 901
	assert_true(_buildings.directory().destroy(_room), "actual Room generation retired")
	assert_equal(_owner.snapshot_for_traversal_into(image), &"SPACE_SOURCE_STALE", "room marker cannot outlive owner")
	assert_equal(image.revision, 901, "failed lifetime proof does not replace caller's prior survey")


class CountedSources extends Owner.CoreSources:
	## Exact actual source reader with a test-only counter for bounded observation loops.
	var reads: int = 0

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""Counting cannot authorize missing or changed actual source facts."""
		reads += 1
		return super.read_into(ref, out)


func test_prepared_region_observation_uses_no_source_scan_and_requires_full_final_preflight() -> void:
	"""Observation copies sealed scalars only; it cannot replace the batch's actual source freshness proof."""
	var counted: CountedSources = CountedSources.new(_buildings.directory(), _buildings, _construction)
	_owner = Owner.new(counted)
	assert_equal(_owner.configure(_domain, R, O), &"", "counted actual reader")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _hall), &"", "actual Building source")
	var floor_ref: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _hall))
	assert_equal(_owner.seal(token), &"", "strict candidate")
	assert_equal(_owner.prepared_refusal(token), &"", "one full source proof before batch")
	var out: Owner.Region = Owner.Region.new()
	out.box.resize(6)
	var reads: int = counted.reads
	for index: int in 1536:
		assert_equal(_owner.prepared_region_observation_into(token, floor_ref, out), &"", "bounded fixed observation")
	assert_equal(counted.reads, reads, "no source reader or arena scan per row")
	assert_equal(out.section, floor_ref, "full internal generation remains explicit")
	assert_true(_buildings.set_building_interior_id(_hall, 29).ok, "actual source changes without allocator reuse")
	assert_equal(_owner.prepared_region_observation_into(token, floor_ref, out), &"", "raw observation is not freshness permission")
	assert_equal(_owner.prepared_refusal(token), &"SPACE_SOURCE_DRIFT", "mandatory final full proof detects changed owner")
	assert_true(_owner.abort(token), "discard stale candidate")


func test_prepared_region_observation_refusals_preserve_exact_caller_scratch() -> void:
	"""No stale token, retired row or undersized scratch can expose a different prepared namespace."""
	var token: int = _begin()
	var floor_ref: Vector2i = _put(token, _region([0, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _world))
	var out: Owner.Region = Owner.Region.new()
	out.level = 773
	out.box = PackedInt32Array([1, 2, 3, 4, 5, 6])
	assert_equal(_owner.prepared_region_observation_into(token, floor_ref, out), &"SPACE_TRANSACTION_UNSEALED", "unsealed")
	assert_equal(_owner.seal(token), &"", "actual seal")
	assert_equal(_owner.prepared_region_observation_into(token + 1, floor_ref, out), &"SPACE_TRANSACTION_UNSEALED", "foreign token")
	assert_equal(_owner.prepared_region_observation_into(token, Vector2i(floor_ref.x, floor_ref.y + 1), out),
		&"SPACE_REGION_STALE", "full generation")
	assert_equal(out.level, 773, "metadata preserved")
	assert_equal(out.box, PackedInt32Array([1, 2, 3, 4, 5, 6]), "all refused bytes preserved")
	out.box.resize(5)
	assert_equal(_owner.prepared_region_observation_into(token, floor_ref, out), &"SPACE_REGION_OUTPUT_SHAPE", "no implicit allocation")
	assert_true(_owner.abort(token), "expire exact observation")
	assert_equal(_owner.prepared_region_observation_into(token, floor_ref, out), &"SPACE_TRANSACTION_UNSEALED", "aborted candidate")


func _section_claim(token: int, floor_ref: Vector2i, bounds: Array[int]) -> Vector2i:
	"""Retain an exact fine synthetic Room claim, distinct from the enclosing floor metadata."""
	var claim: Owner.Region = _region(bounds, Space.OBSTACLE, _room)
	claim.section = floor_ref
	claim.claim_kind = Owner.CLAIM_ROOM
	claim.claim_ref = _room
	return _put(token, claim)


func _section_query_fixture() -> Vector2i:
	"""One actual Room source owns a synthetic concave plan four metres high, with a negative floor."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "actual Room")
	assert_equal(_owner.stage_source(token, _hall), &"", "actual source for drift regression")
	var floor_ref: Vector2i = _put(token, _region([-1024, -2048, -1024, 1024, -2047, 1024],
		Space.FLOOR_DATUM, _room))
	_section_claim(token, floor_ref, [-1024, -2048, -1024, 0, 2048, -768])
	_section_claim(token, floor_ref, [-1024, -2048, -768, -768, 2048, 0])
	_section_claim(token, floor_ref, [0, -2048, 0, 256, 2048, 256])
	_put(token, _region([1024, 0, 0, 2048, 1024, 1024], Space.UNFINISHED, _room))
	_publish(token)
	return floor_ref


func test_paid_cube_section_resolves_fine_claims_without_inventing_floor_or_void() -> void:
	"""An upper paid cube keeps the actual lower floor; partial claims grant metadata only."""
	var floor_ref: Vector2i = _section_query_fixture()
	var before: PackedByteArray = _owner.state_bytes()
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(-1024, 0, -1024),
		_owner.revision(), out), &"", "two fine strips intersect the same exact cube")
	assert_equal(out.section, floor_ref, "full actual section generation")
	assert_equal(out.box, PackedInt32Array([-1024, -2048, -1024, 1024, -2047, 1024]), "no upper-Y floor inference")
	assert_equal(out.owner, _room, "actual Room")
	assert_equal(out.role, Space.FLOOR_DATUM, "metadata only")
	assert_equal(out.level, 1, "actual stored level")
	var prior: PackedInt32Array = out.box.duplicate()
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(0, 2048, 0), _owner.revision(), out),
		&"SPACE_SECTION_MISSING", "touching upper boundary is not an intersection")
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(1024, 0, 0), _owner.revision(), out),
		&"SPACE_SECTION_MISSING", "physical unfinished row cannot impersonate a Room claim")
	assert_equal(out.box, prior, "refused reads preserve prior scratch")
	assert_equal(_owner.state_bytes(), before, "no physical, claim or allocator mutation")
	assert_false(_snapshot().volumes.role.has(Space.SUPPORTED_VOID), "metadata never creates free void")


func test_paid_cube_section_refuses_ambiguous_or_missing_full_section_links() -> void:
	"""Adjacent older sections within one paid cube cannot be collapsed to the first matching row."""
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "actual Room")
	var first: Vector2i = _put(token, _region([0, 0, 0, 512, 1, 1024], Space.FLOOR_DATUM, _room))
	var second: Vector2i = _put(token, _region([512, 0, 0, 1024, 1, 1024], Space.FLOOR_DATUM, _room))
	_section_claim(token, first, [0, 0, 0, 512, 1024, 1024])
	_section_claim(token, second, [512, 0, 0, 1024, 1024, 1024])
	_publish(token)
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i.ZERO, _owner.revision(), out),
		&"SPACE_SECTION_AMBIGUOUS", "all intersecting claims must share one full section")
	assert_equal(out.box[0], 77, "ambiguous output untouched")
	token = _begin()
	_section_claim(token, NULL_REF, [1024, 0, 0, 1280, 1024, 256])
	_publish(token)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(1024, 0, 0), _owner.revision(), out),
		&"SPACE_SECTION_STALE", "legacy claim without actual floor cannot supply guessed metadata")
	assert_equal(out.role, Space.WATER, "all refused output fields survive")


func test_paid_cube_section_rechecks_revision_room_generation_and_actual_source_facts() -> void:
	"""The query cannot cache metadata across geometry, actual source drift or Room retirement."""
	_section_query_fixture()
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	var origin: Vector3i = Vector3i(-1024, 0, -1024)
	var revision: int = _owner.revision()
	assert_equal(_owner.section_for_paid_cube_into(_room, origin, revision - 1, out),
		&"SPACE_REVISION_STALE", "exact retained image revision")
	assert_equal(_owner.section_for_paid_cube_into(Vector2i(_room.x, _room.y + 1), origin, revision, out),
		&"SPACE_SECTION_ROOM", "foreign Room generation")
	assert_true(_buildings.set_building_interior_id(_hall, 91).ok, "real structural source changed")
	assert_equal(_owner.section_for_paid_cube_into(_room, origin, revision, out),
		&"SPACE_SOURCE_DRIFT", "same geometry revision is insufficient")
	assert_true(_buildings.set_building_interior_id(_hall, 1).ok, "restore original source")
	assert_true(_buildings.directory().destroy(_room), "actual Room retirement")
	assert_equal(_owner.section_for_paid_cube_into(_room, origin, revision, out),
		&"SPACE_SOURCE_STALE", "full actual Room lifetime is rechecked")
	assert_equal(out.box, PackedInt32Array([77, 78, 79, 80, 81, 82]), "no refused mutation")


func test_paid_cube_section_domain_overflow_scratch_and_work_ceiling_refuse() -> void:
	"""No fine-grid rounding, overflowing far corner or uncharged scan is accepted."""
	_section_query_fixture()
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	for origin: Vector3i in [Vector3i(1, 0, 0), Vector3i(8192, 0, 0), Vector3i(2147483136, 0, 0)]:
		assert_equal(_owner.section_for_paid_cube_into(_room, origin, _owner.revision(), out),
			&"SPACE_SITE_DOMAIN", "exact finite paid quantum only")
	out.box.resize(5)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i.ZERO, _owner.revision(), out),
		&"SPACE_REGION_OUTPUT_SHAPE", "caller owns exact scratch")
	out.box.resize(6)
	var small: Owner = Owner.new(_sources)
	assert_equal(small.configure(_new_domain(64), R, O), &"", "small actual cold work allowance")
	assert_equal(small.section_for_paid_cube_into(_room, Vector3i.ZERO, small.revision(), out),
		&"SPACE_OPERATION_BUDGET", "both source scans and complete scalar scan admitted before use")


func test_paid_cube_section_uses_actual_immutable_datum_and_rejects_foreign_floor_owner() -> void:
	"""The economic grid translates explicitly, while Room section ownership stays generation-qualified."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i(0, 512, 0), Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 64, 64, 100000), &"", "actual translated domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, R, O), &"", "new owner keeps explicit immutable datum")
	var token: int = _begin()
	assert_equal(_owner.stage_source(token, _room), &"", "actual Room")
	var floor_ref: Vector2i = _put(token, _region([0, -1536, 0, 1024, -1535, 1024], Space.FLOOR_DATUM, _world))
	_section_claim(token, floor_ref, [0, -1536, 0, 256, 2560, 256])
	_publish(token)
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i.ZERO, _owner.revision(), out),
		&"SPACE_SITE_DOMAIN", "do not silently shift cube to512")
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(0, 512, 0), _owner.revision(), out),
		&"SPACE_SECTION_STALE", "a World floor cannot stand in for the actual Room floor")
	assert_equal(out.owner, _world, "refusal leaves prior owner untouched")


func test_paid_cube_section_resolves_under_the_unchanged_actual_joint_capacities() -> void:
	"""R6144/O2048 must support a real small claim query without increasing the cold work ceiling."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 8192, 8192, Space.MAX_CHECKS), &"", "actual joint limits")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, 6144, 2048), &"", "joint finite allocation")
	var floor_ref: Vector2i = _section_query_fixture()
	var out: Owner.Region = _region([77, 78, 79, 80, 81, 82], Space.WATER, _world)
	assert_equal(_owner.section_for_paid_cube_into(_room, Vector3i(-1024, 0, -1024),
		_owner.revision(), out), &"", "bounded scans fit existing MAX_CHECKS")
	assert_equal(out.section, floor_ref, "exact full section, no slot-only result")
