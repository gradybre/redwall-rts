extends "res://test/framework/test_case.gd"
## ADR 1229 increment 4: content 10's handling layer against the actual content-10 rows: the paw programs of rows 65
## and 66, the claw endpoint certificate successor (rows 43/47/57/65), the content-aware handling selector (content 9's
## row 59 is a claw tap in content 10) and the derived tread geometry (stations, staged bearers).

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Handling := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/handling_programs.gd")
const Paw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_program.gd")
const Physical := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_physical_certificate.gd")
const Endpoint := preload("res://data/underground/mole-worker/qualified-claw-certificate-v2/endpoint_certificate.gd")
const Endpoints := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/endpoint_certificates.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
var _profiles: Profiles = null


func before_each() -> void:
	"""Content 10 through the actual loader."""
	_profiles = Profiles.new()
	var packed: int = 2 * (67 * Profiles.PROFILE_WIRE_BYTES + 547 * 28 + 6 * 32 + 32)
	assert_equal(_profiles.configure(67, 547, 6, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(_profiles.load_file(WIRE, Pins.WIRE_SHA, 10), &"", "content 10")


func after_each() -> void:
	"""Drop the store."""
	_profiles = null


func test_paw_rows_sixty_five_and_sixty_six_are_exact() -> void:
	"""Every word and box of both handling rows; the stance is footing and the body every word above the floor."""
	assert_true(Paw.uses(_profiles), "content 10 with both rows")
	for row: int in [Pins.PAW_HANDLING_ROW, Pins.PAW_TREAD_HANDLING_ROW]:
		assert_equal(Paw.profile_refusal(_profiles, row, 1, 10), &"", "row %d exact" % row)
		assert_equal(Paw.profile_refusal(_profiles, row, 1, 9), &"ASSEMBLY_SOURCE_PROFILE", "content 10 only")
	var body: Array = []
	var foot: Array = []
	for field: int in 6:
		body.append(Paw.volume_word(Pins.PAW_TREAD_HANDLING_ROW, 0, field))
		foot.append(Paw.volume_word(Pins.PAW_TREAD_HANDLING_ROW, 1, field))
	assert_equal(body, [-478, 0, -410, 445, 840, 234], "tread seat body")
	assert_equal(foot, [-276, -1, -169, 299, 0, 175], "tread seat stance")
	assert_equal([Paw.clip_of(65, Paw.Clock.ENTRY), Paw.clip_of(66, Paw.Clock.ENTRY), Paw.clip_of(66, Paw.Clock.RECOVERY)],
		[0, 3, 5], "paw v2 clips")


func test_the_selector_reads_rows_under_their_content() -> void:
	"""Row 59 is paw handling in content 9 and a claw tap in content 10; 65/66 are content 10's handling rows."""
	assert_equal([Handling.is_handling(59, 9), Handling.is_handling(59, 10), Handling.is_handling(65, 10),
		Handling.is_handling(66, 10), Handling.is_handling(66, 9), Handling.is_handling(29, 10)],
		[true, false, true, true, false, true], "handling rows")
	assert_equal([Handling.is_install_tap(52, 9), Handling.is_install_tap(52, 10), Handling.is_install_tap(57, 10),
		Handling.is_install_tap(64, 10), Handling.is_install_tap(57, 9)], [true, false, true, true, false], "taps")
	assert_equal([Handling.source_of(65, 10), Handling.role_count(66, 10), Handling.part_count(64, 10)], [5, 7, 2],
		"content 10's program")
	assert_equal(Handling.profile_refusal(_profiles, 66, 1, 10), &"", "row 66 through the selector")


func test_the_content_ten_endpoint_certificate_reads_the_moved_rows() -> void:
	"""Rows 43, 47, 57 and 65 keep every word they had in content 9 (43, 47, 52, 59)."""
	for row: int in [43, 47, Pins.CLAW_TAP_ROWS[0], Pins.PAW_HANDLING_ROW]:
		assert_equal(Endpoint._source_row_refusal(_profiles, row, 10), &"", "row %d" % row)
	assert_equal(Endpoint._profiles_refusal(_profiles, 10), &"", "both v2 digests and all four rows")
	assert_true(Endpoints.is_claw(10) and Endpoints.excuses_pending(43, 10), "routed for content 10")
	assert_false(Endpoints.excuses_pending(57, 10), "a tap is never excused")


func test_tread_geometry_extends_t0_by_one_pitch_per_tread() -> void:
	"""T1's station is 310 u behind T0's far edge on T0's top; its staged bearer is T0's moved one pitch; the sill's
	bearer is 64 u tall and its prism 64 u high."""
	assert_equal([Tread.station_of(2), Tread.station_of(7)], [Vector3i(0, -128, -2250), Vector3i(0, -768, -4810)], "stations")
	assert_equal([Tread.bearer_part(2), Tread.bearer_part(7)], [15, 50], "the left bearer of T1 and of the sill")
	assert_equal([Tread.bearer_translation(1 + 1), Tread.bearer_translation(7)],
		[Vector3i(2816, 320, -3328), Vector3i(5376, 256, -5888)], "translations")
	var prism: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_true(Tread.bearer_prism_into(2, Tread.station_of(2), prism), "T1's prism")
	assert_equal(prism, PackedInt32Array([-256, -128, -2560, 256, 0, -2432]), "across T0's forward top edge")
	assert_true(Tread.bearer_prism_into(7, Tread.station_of(7), prism), "the sill's prism")
	assert_equal(prism[4] - prism[1], 64, "64 u high")
	assert_false(Tread.bearer_prism_into(1, Vector3i.ZERO, prism), "T0 is not a tread assembly")
	assert_equal(Physical.part_refusal(2, 15, 3, Vector3i(2816, 320, -3328)), &"", "T1's staged bearer")
	assert_equal(Physical.part_refusal(2, 8, 3, Vector3i(2304, 320, -2816)), &"ASSEMBLY_SOURCE_PART", "not T0's")
	assert_equal(Physical.part_refusal(1, 8, 3, Vector3i(2304, 320, -2816)), Pick.part_refusal(1, 8, 3,
		Vector3i(2304, 320, -2816)), "T0 keeps the pick certificate's transform")
	assert_equal(Physical.bearer_refusal(2, Tread.station_of(2), prism), &"ASSEMBLY_SOURCE_BEARER", "the sill's prism is not T1's")


func test_the_tread_taps_are_certified_only_at_their_stations() -> void:
	"""Tap 57 at L0/T0 roots with their pick prisms; tap 64 at a tread station with its derived prism."""
	var prism: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_true(Tread.bearer_prism_into(3, Tread.station_of(3), prism), "T2's prism")
	assert_true(Physical.tap_certified(_profiles, 64, 1, 3, Tread.station_of(3), prism), "tread tap at T2's station")
	assert_false(Physical.tap_certified(_profiles, 64, 1, 3, Tread.station_of(3) + Vector3i(0, 0, 1), prism), "moved")
	assert_false(Physical.tap_certified(_profiles, 57, 1, 3, Tread.station_of(3), prism), "the L0/T0 tap is not a tread's")
	var t0: PackedInt32Array = PackedInt32Array([-256, 0, -2048, 256, 128, -1920])
	assert_true(Physical.tap_certified(_profiles, 57, 1, 1, Vector3i(0, 0, -1536), t0), "tap 57 at T0's root")
	assert_true(Handling.tap_certified(_profiles, 57, 1, 10, 1, Vector3i(0, 0, -1536), t0), "through the selector")
