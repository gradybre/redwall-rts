extends "./capture_cardinal_program.gd"
## The emitted immutable source catalog on its actual native backend; no World/paid-target permission.

const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
var _published_basis: Actor.WorldBasis = null
var _published_domain: Actor.Space.Domain = null
var _catalog_record: Dictionary = {}


func _bind_actor(meshes: Dictionary) -> void:
	"""Use the same shared coefficient table for both the concrete catalog gate and actual Actor attachment."""
	_published_basis = Actor.WorldBasis.new()
	_suite.assert_equal(_published_basis.load_file(_spec.basis, _spec.basis_sha256, _spec.basis_producer_sha256,
		Actor.WorldBasis.RESERVED_BYTES), &"", "actual same-file native basis")
	_published_domain = Actor.Space.Domain.new()
	_suite.assert_equal(_published_domain.configure(Vector2i(5, 9), Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Actor.Space.MAX_CHECKS), &"", "finite extent, fixture World identity")
	_suite.assert_equal(Catalog.presentation_refusal(_content, _published_basis, _published_domain), &"", "actual native presentation gate")
	_actor = Actor.new()
	_world.add_child(_actor)
	_suite.assert_equal(_content.configure_actor(_actor, meshes.meshes, meshes.materials), &"", "actual immutable mesh binding")
	_suite.assert_equal(_actor.bind_world_source(_published_basis, _published_domain, _published_domain.descriptor(),
		_content.source_digest(), _published_basis.source_digest()), &"", "the exact checked basis/domain reaches renderer")
	_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), ORIGIN_U, 0), &"", "initial native integer root")


func _install_fixture_profiles() -> void:
	"""Override only the historical hook: no synthetic wire, category or certificate bit is created here."""
	_identity_values = _actual._identity.duplicate()
	_actual._profiles = Profiles.new()
	_suite.assert_equal(_actual._profiles.configure(Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, 1,
		Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE), &"", "minimal actual catalog banks")
	_suite.assert_equal(_actual._bind(_actual._profiles), &"", "same actual Resident/Job/Gear owners")
	_suite.assert_equal(Catalog.load_into(_actual._profiles, _content, _published_domain), &"", "actual emitted source-qualified wire")
	var pins: PackedInt64Array = PackedInt64Array()
	pins.resize(Catalog.PROFILE_COUNT * 3)
	_suite.assert_equal(Catalog.pins_into(_actual._profiles, pins), &"", "complete streamed row digest and exact pins")
	var flags: PackedInt32Array = PackedInt32Array()
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	for index: int in Catalog.PROFILE_COUNT:
		_suite.assert_equal(_actual._profiles.descriptor_into(index, Catalog.CONTENT_REVISION, descriptor), &"", "actual selected source row")
		flags.append(descriptor.certificate_flags)
	_catalog_record = {"wire_sha256": Catalog.Pins.WIRE_SHA, "actor_sha256": _content.source_digest(),
		"basis_sha256": _published_basis.source_digest(), "content_revision": _actual._profiles.content_revision(),
		"pins": Array(pins), "certificate_flags": Array(flags), "profile_count": _actual._profiles.profile_count(1),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "world_activation_qualified": false}


func _finish() -> void:
	"""Report exact emitted catalog attachment separately from the inherited native event and contact witnesses."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"phase_counts": Array(_phase_counts), "events": _events, "native_contacts": _native_contacts,
		"production_qualified": false, "program_version": 4, "actual_species_stage_rig": Array(_identity_values),
		"user_directory": OS.get_user_data_dir(), "published_catalog": _catalog_record,
		"world_identity": "actual source-qualified catalog/Resident/Job/Work/Gear/renderer; fixture World, no paid target or WIP"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	_published_basis = null
	_published_domain = null
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-published-program: %d poses, %d assertions, %d failures; world_qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
