extends "res://test/test_underground_entry_structure_source.gd"
## Inherits the two actual structural-source regressions; adds real Frontier admission without live activation.

const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const FRONTIER_PATH: String = Bundle.FRONTIER_PATH
const FRONTIER_SHA: String = Bundle.FRONTIER_SHA
const TEMP_PATH: String = "user://entry-frontier-source-negative.bin"

var _frontier: Frontier = null


func after_each() -> void:
	"""Drop the cold immutable reader before the original owner graph; remove only this test's negative wire."""
	_frontier = null
	if FileAccess.file_exists(TEMP_PATH): DirAccess.remove_absolute(TEMP_PATH)
	super.after_each()


func _frontier_reader() -> void:
	"""Read accepted source bytes against the actual original Profiles, Items and Inventory identities."""
	assert_equal(_catalog.load_file(CATALOG_PATH, CATALOG_SHA, 1), &"", "actual geometry")
	_bind_bills()
	_frontier = Frontier.new()
	var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, Bundle.ENDPOINT_COUNT, 6])
	assert_equal(Frontier.required_bytes(capacities), 4192, "complete source bank (ADR1202: two arrival selectors)")
	assert_equal(_frontier.configure(capacities, 4192), &"", "exact immutable source capacities")
	assert_equal(_frontier.bind_actual(_catalog, _assemblies, _recipes,
		_session._retirement_owners.profiles), &"", "actual complete source chain")


func test_actual_source_selects_eighteen_cube_phases_without_publishing_world_state() -> void:
	"""Every phase selects actual downward BUILD; reading a valid work packet grants no progress or contact."""
	_frontier_reader()
	var inventory: PackedByteArray = _host.inventory().state_bytes()
	var jobs: PackedByteArray = _host.jobs().state_bytes()
	assert_equal(_frontier.load_file(FRONTIER_PATH, FRONTIER_SHA, Bundle.FRONTIER_REVISION), &"", "actual source wire")
	_assert_phase_selectors()
	assert_equal(_host.inventory().state_bytes(), inventory, "no input or output change")
	assert_equal(_host.jobs().state_bytes(), jobs, "no worker or job")
	var o: Session.Retirement.Owners = _session._retirement_owners
	assert_equal(o.sites._count, 0, "no paid excavation")
	assert_equal(o.locations._live.count, 0, "no granted endpoints")
	assert_equal(o.routes._live.edge_count, 0, "no granted route")
	assert_equal(o.world_routes._catalog._live.header[1], 1, "mounted entry structure Catalog remains original")


func _assert_phase_selectors() -> void:
	"""Check original full source rows and complete profile/revision identity through the actual reader."""
	var episode: PackedInt32Array = PackedInt32Array(); episode.resize(19)
	var station: PackedInt32Array = PackedInt32Array(); station.resize(9)
	var revision: Catalog.IntMath.IntResult = Catalog.IntMath.IntResult.new()
	var profiles: Profiles = _session._retirement_owners.profiles
	for ordinal: int in 6:
		assert_equal(_frontier.episode_into(ordinal, episode), &"", "exact physical cube")
		assert_equal(episode[6], 7, "BRACE CUT FINISH remain distinct required operations")
		for phase: int in 3:
			assert_equal(_frontier.station_into(episode[8 + phase], station, revision), &"", "actual phase station")
			assert_equal(station[5], 57 if ordinal % 2 == 0 else 53, "actual claw dig row (ADR1217 step 4e: yaw 49152 / 16384)")
			assert_equal(station[1], -1430 if ordinal % 2 == 0 else 1430, "the claw station at 1,430 u stays outside future cuts")
			assert_equal(revision.value, 1, "exact program revision")
			assert_equal(profiles._live.fields[Profiles.F_SOURCE * profiles._profile_capacity + station[5]], 4, "claw source image")
		# Revision 2 (ADR1191) routes cuts through explicit travel selectors 10/11, aliases of M/R endpoints 1/2.
		assert_equal(episode[15], 10, "material endpoint")
		assert_equal(episode[16], 11, "finite output endpoint")
		assert_equal(episode[17], 4 + ordinal, "same actual work station retains retreat")
	assert_equal(_frontier.row_count(Frontier.ENDPOINT, Bundle.FRONTIER_REVISION), Bundle.ENDPOINT_COUNT, "no unqualified tread transit endpoint")


func test_wrong_source_hash_and_unqualified_work_yaw_refuse_cleanly() -> void:
	"""A filename or matching source index cannot bypass exact content and yaw admission."""
	_frontier_reader()
	assert_equal(_frontier.load_file(FRONTIER_PATH, "0".repeat(64), Bundle.FRONTIER_REVISION), Frontier.REFUSE_SOURCE, "stale wire")
	assert_equal(_frontier.content_revision(), 0, "no partially published source")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FRONTIER_PATH)
	bytes.encode_s32(220 + 2 * 36 + 2 * 80 + 5 * 4, 17)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	assert_equal(_frontier.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), Bundle.FRONTIER_REVISION), Frontier.REFUSE_PROFILE,
		"right-facing work cannot borrow the left station")
	assert_equal(_frontier.content_revision(), 0, "refused reader remains retryable")
	assert_equal(_frontier.load_file(FRONTIER_PATH, FRONTIER_SHA, Bundle.FRONTIER_REVISION), &"", "exact retry")
