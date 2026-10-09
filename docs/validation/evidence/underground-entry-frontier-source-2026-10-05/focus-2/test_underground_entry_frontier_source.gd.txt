extends "res://test/test_underground_entry_structure_source.gd"
## Inherits the two actual structural-source regressions; adds real Frontier admission without live activation.

const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const FRONTIER_PATH: String = "res://data/underground/first-entry-prefix-v1/frontier-v2/frontier.ugfront"
const FRONTIER_SHA: String = "1f7b6861cf30c55322e7adf1f4b4fc1d5e63b9fab68feaaea8c4b30d7ed898ca"
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
	var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, 10, 6])
	assert_equal(Frontier.required_bytes(capacities), 4032, "complete source bank")
	assert_equal(_frontier.configure(capacities, 4032), &"", "exact immutable source capacities")
	assert_equal(_frontier.bind_actual(_catalog, _assemblies, _recipes,
		_session._retirement_owners.profiles), &"", "actual complete source chain")


func test_actual_source_selects_eighteen_cube_phases_without_publishing_world_state() -> void:
	"""Every phase selects actual downward BUILD; reading a valid work packet grants no progress or contact."""
	_frontier_reader()
	var inventory: PackedByteArray = _host.inventory().state_bytes()
	var jobs: PackedByteArray = _host.jobs().state_bytes()
	assert_equal(_frontier.load_file(FRONTIER_PATH, FRONTIER_SHA, 1), &"", "actual source wire")
	_assert_phase_selectors()
	assert_equal(_host.inventory().state_bytes(), inventory, "no input or output change")
	assert_equal(_host.jobs().state_bytes(), jobs, "no worker or job")
	var o: Session.Retirement.Owners = _session._retirement_owners
	assert_equal(o.sites._count, 0, "no paid excavation")
	assert_equal(o.locations._live.count, 0, "no granted endpoints")
	assert_equal(o.routes._live.edge_count, 0, "no granted route")
	assert_equal(o.world_routes._catalog._live.header[1], 0, "mounted ground Catalog remains original")


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
			assert_equal(station[5], 25 if ordinal % 2 == 0 else 17, "actual downward top-face program")
			assert_equal(station[1], -1536 if ordinal % 2 == 0 else 1536, "complete all-yaw foot stays outside future cuts")
			assert_equal(revision.value, 1, "exact program revision")
			assert_equal(profiles._live.fields[Profiles.F_SOURCE * profiles._profile_capacity + station[5]], 0, "original source image")
		assert_equal(episode[15], 1, "material endpoint")
		assert_equal(episode[16], 2, "finite output endpoint")
		assert_equal(episode[17], 4 + ordinal, "same actual work station retains retreat")
	assert_equal(_frontier.row_count(Frontier.ENDPOINT, 1), 10, "no unqualified tread transit endpoint")


func test_wrong_source_hash_and_unqualified_work_yaw_refuse_cleanly() -> void:
	"""A filename or matching source index cannot bypass exact content and yaw admission."""
	_frontier_reader()
	assert_equal(_frontier.load_file(FRONTIER_PATH, "0".repeat(64), 1), Frontier.REFUSE_SOURCE, "stale wire")
	assert_equal(_frontier.content_revision(), 0, "no partially published source")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FRONTIER_PATH)
	bytes.encode_s32(220 + 2 * 36 + 2 * 80 + 5 * 4, 17)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	assert_equal(_frontier.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 1), Frontier.REFUSE_PROFILE,
		"right-facing work cannot borrow the left station")
	assert_equal(_frontier.content_revision(), 0, "refused reader remains retryable")
	assert_equal(_frontier.load_file(FRONTIER_PATH, FRONTIER_SHA, 1), &"", "exact retry")
