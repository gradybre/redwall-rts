extends "res://test/framework/test_case.gd"
## Decision 2044 (P-2044-9 (a), P-2044-13 (a)): the module-aware successors of the tread geometry and the handling
## certificates. Every module-0 assembly (0-7) must get exactly the published answer, which is what keeps today's
## entry byte for byte as it was once the handling dispatch names the successor; a later module's assembly must be the
## published rule moved by its module translation, and must accept exactly the M5 bundle's own staged bearers.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Handling := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/handling_programs.gd")
const Published := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_physical_certificate.gd")
const PublishedTread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const Physical := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/paw_physical_certificate.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const AssemblySource := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/assembly_source_program.gd")
const AssemblyPhysical := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/assembly_physical_certificate.gd")
const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-m5-v1/catalog_source.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const ASSEMBLIES: int = 36


func _workpiece_rows() -> Array[PackedInt32Array]:
	"""The M5 bundle's 36 staged-bearer rows [part, turn, x, y, z, handling row], read from its published wire."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Bundle.WORKPIECES_PATH)
	var rows: Array[PackedInt32Array] = []
	for row: int in ASSEMBLIES:
		var at: int = 212 + 32 * row
		var values: PackedInt32Array = PackedInt32Array()
		for field: int in 6: values.append(bytes.decode_s32(at + 4 * field))
		rows.append(values)
	return rows


func test_the_dispatch_names_the_m5_successor() -> void:
	"""P-2044-13 (a): the handling dispatch's content-12 tread certificate is the module-aware successor, whose tread
	geometry is the M5 one (Contacts reads it through the dispatch)."""
	assert_true(Handling.PawPhysical10 == Physical, "the dispatch's content-12 certificate")
	assert_true(Handling.PawPhysical10.Tread == Tread, "and its tread geometry")


func test_module_zero_geometry_is_the_published_geometry() -> void:
	"""Assemblies 0-7: every derived value equals the published tread geometry's."""
	for assembly: int in 8:
		assert_equal(Tread.module_of(assembly), 0, "module 0 holds assembly %d" % assembly)
		assert_equal(Tread.is_tread(assembly), PublishedTread.is_tread(assembly), "tread %d" % assembly)
		if not PublishedTread.is_tread(assembly): continue
		assert_equal(Tread.station_of(assembly), PublishedTread.station_of(assembly), "station %d" % assembly)
		assert_equal(Tread.bearer_part(assembly), PublishedTread.bearer_part(assembly), "bearer part %d" % assembly)
		assert_equal(Tread.bearer_translation(assembly), PublishedTread.bearer_translation(assembly), "transform %d" % assembly)
		assert_equal(Tread.bearer_height(assembly), PublishedTread.bearer_height(assembly), "height %d" % assembly)
	assert_equal([Tread.bearer_part(0), Tread.bearer_part(1)], [1, 8], "L0's and T0's staged bearers")
	assert_equal(Tread.t0_station_of(1), Vector3i(0, 0, -1536), "T0's station, the prefix's L0 station")


func test_later_modules_are_module_zero_moved() -> void:
	"""Module j's T_k is assembly 1 + 7j + k, at module 0's T_k moved by (0, -1024j, -5120j)."""
	assert_equal([Tread.module_of(8), Tread.level_of(8), Tread.base_assembly(8)], [1, 0, 1], "module 1's T0")
	assert_equal([Tread.module_of(35), Tread.level_of(35), Tread.base_assembly(35)], [4, 6, 7], "module 4's sill")
	assert_equal([Tread.module_of(36), Tread.level_of(-1)], [-1, -2], "no assembly beyond 35 or below 0")
	assert_true(Tread.is_t0(15) and Tread.first_tread(16) and Tread.is_sill(21) and not Tread.is_tread(15), "kinds")
	for module: int in range(1, 5):
		for k: int in range(1, 7):
			var assembly: int = 1 + 7 * module + k
			assert_equal(Tread.station_of(assembly), PublishedTread.station_of(k + 1) + Tread.offset(module),
				"module %d T%d's station" % [module, k])
	assert_equal(Tread.t0_station_of(29), Vector3i(0, -4096, -1536 - 4 * 5120), "module 4's T0 at H'")
	assert_equal(Tread.part_base(1), 52, "module 1 starts after the first module's 52 parts")
	assert_equal(Tread.part_base(4), 52 + 3 * 45, "module 4")


func test_every_bundle_bearer_is_accepted_and_only_its_own() -> void:
	"""The successor accepts each of the M5 bundle's 36 staged bearers for its own assembly and no other; module 0's
	answers equal the published certificate's."""
	var rows: Array[PackedInt32Array] = _workpiece_rows()
	for assembly: int in ASSEMBLIES:
		var row: PackedInt32Array = rows[assembly]
		var translation: Vector3i = Vector3i(row[2], row[3], row[4])
		assert_equal(Physical.part_refusal(assembly, row[0], row[1], translation), &"", "assembly %d's bearer" % assembly)
		if assembly < 8:
			assert_equal(Physical.part_refusal(assembly, row[0], row[1], translation),
				Published.part_refusal(assembly, row[0], row[1], translation), "published answer %d" % assembly)
		var other: int = (assembly + 7) % ASSEMBLIES
		assert_equal(Physical.part_refusal(other, row[0], row[1], translation), &"ASSEMBLY_SOURCE_PART",
			"assembly %d's bearer is not %d's" % [assembly, other])
		assert_equal(Physical.part_refusal(assembly, row[0], row[1], translation + Vector3i(1, 0, 0)),
			&"ASSEMBLY_SOURCE_PART", "moved one unit (%d)" % assembly)


func test_module_zero_refusals_and_prisms_are_the_published_ones() -> void:
	"""Every module-0 bearer prism and part answer the published certificate gives, for good and moved inputs."""
	var prism: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for assembly: int in range(2, 8):
		var root: Vector3i = PublishedTread.station_of(assembly)
		assert_true(PublishedTread.bearer_prism_into(assembly, root, prism), "prism %d" % assembly)
		assert_equal(Physical.bearer_refusal(assembly, root, prism), Published.bearer_refusal(assembly, root, prism),
			"prism answer %d" % assembly)
		assert_equal(Physical.bearer_refusal(assembly, root + Vector3i(0, 0, 1), prism),
			Published.bearer_refusal(assembly, root + Vector3i(0, 0, 1), prism), "moved prism answer %d" % assembly)
	for assembly: int in 2:
		var bounds: PackedInt32Array = PackedInt32Array([-256, 0, -512, 256, 128, -384])
		assert_equal(Physical.bearer_refusal(assembly, Vector3i.ZERO, bounds),
			Published.bearer_refusal(assembly, Vector3i.ZERO, bounds), "L0/T0 prism answer %d" % assembly)
	assert_equal(Physical.is_tap(57) and Physical.is_tap(64) and not Physical.is_tap(65), true, "the published taps")


func test_a_later_modules_t0_and_treads_use_the_moved_prisms() -> void:
	"""Module j's T0 takes T0's relative prism (the published T0 rule) and its treads their published tread's."""
	var t0: PackedInt32Array = PackedInt32Array([-256, 0, -512, 256, 128, -384])
	var root: Vector3i = Tread.t0_station_of(8)
	var bounds: PackedInt32Array = PackedInt32Array()
	for axis: int in 6: bounds.append(t0[axis] + root[axis % 3])
	assert_equal(Physical.bearer_refusal(8, root, bounds), Pick.bearer_refusal(1, root, bounds), "module 1's T0 is T0's")
	assert_equal(AssemblySource.bearer_refusal(8, root, bounds), &"", "the T0 prism around its root")
	var prism: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_true(Tread.bearer_prism_into(21, Tread.station_of(21), prism), "module 2's sill prism")
	assert_equal(Physical.bearer_refusal(21, Tread.station_of(21), prism), &"", "accepted at its station")
	assert_equal(Physical.bearer_refusal(20, Tread.station_of(21), prism), &"ASSEMBLY_SOURCE_BEARER", "not T5's")
	assert_equal(AssemblyPhysical.station_refusal(Vector3i(10, 20, 30), 8, Vector3i(10, 20 - 1024, 30 - 1536 - 5120)),
		&"", "module 1's T0 station")
	assert_equal(AssemblyPhysical.station_refusal(Vector3i.ZERO, 9, Tread.t0_station_of(9)), AssemblyPhysical.REFUSE,
		"a tread is not a T0")


func test_the_taps_are_certified_at_a_later_modules_stations() -> void:
	"""Tap 57 at a later T0's root with T0's prism, and the tread tap 64 at a later tread's station, as module 0's."""
	var profiles: Profiles = Profiles.new()
	var packed: int = 2 * (85 * Profiles.PROFILE_WIRE_BYTES + 637 * 28 + 8 * 32 + 32)
	assert_equal(profiles.configure(85, 637, 8, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(profiles.load_file(WIRE, Pins.WIRE_SHA, 12), &"", "content 12")
	var prism: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_true(Tread.bearer_prism_into(17, Tread.station_of(17), prism), "module 2's T2 prism")
	assert_true(Physical.tap_certified(profiles, 64, 1, 17, Tread.station_of(17), prism), "tread tap at its station")
	assert_false(Physical.tap_certified(profiles, 57, 1, 17, Tread.station_of(17), prism), "not the T0 tap")
	var root: Vector3i = Tread.t0_station_of(22)
	var t0: PackedInt32Array = PackedInt32Array([-256, 0, -512, 256, 128, -384])
	for axis: int in 6: t0[axis] += root[axis % 3]
	assert_true(Physical.tap_certified(profiles, 57, 1, 22, root, t0), "tap 57 at module 3's T0")
	assert_equal(Physical.tap_certified(profiles, 64, 1, 3, PublishedTread.station_of(3), prism),
		Published.tap_certified(profiles, 64, 1, 3, PublishedTread.station_of(3), prism), "module 0 unchanged")
