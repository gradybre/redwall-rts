extends "res://test/framework/test_case.gd"
## Coverage for `godot/assets/lookdev/lookdev_dimensions.gd` -- the ART-GAP-R01..R05 binding.
##
## What these tests are actually for. The ruling supplies thirty building envelopes, five
## species comparison candidates, five static budget families and two hysteresis contracts.
## Retyping forty-odd numbers into GDScript is exactly the kind of work where one digit goes
## wrong and nothing notices, so the checks below are written to fail on a single wrong digit
## rather than on a wholesale mistake:
##
##   * the envelope set is compared against `Catalog.BUILDING_DEFINITION` itself, so a
##     building added to the catalog without a height fails here rather than in a modeller's
##     inbox;
##   * every derived millimetre is recomputed from its 1/1024 m authority, and the one row
##     that cannot be an integer millimetre (`dirt_path` at 62.5 mm) is asserted BY NAME, so
##     quietly "fixing" 63 into the authority column fails;
##   * both hysteresis pairs are recomputed from their nominal rather than compared to
##     themselves, so a transposed promote/demote pair fails.
##
## The species heights are comparison candidates. These tests check that the file states the
## ruling's numbers; they assert nothing about whether those numbers are right, which is
## Brendan's review to make against the comparison scene.

const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")


func test_every_building_definition_has_exactly_one_vertical_envelope() -> void:
	"""A building with no envelope has no model brief; a stray key describes nothing."""
	assert_equal(Dimensions.building_count(), Catalog.BUILDING_DEFINITION.size(),
		"one envelope row per BuildingDefinition key")
	for key: String in Catalog.BUILDING_DEFINITION:
		assert_true(Dimensions.has_building(StringName(key)),
			"%s carries a vertical envelope" % key)
	for key: StringName in Dimensions.BUILDING_KEY:
		assert_true(Catalog.BUILDING_DEFINITION.has(String(key)),
			"%s is a real BuildingDefinition key" % key)


func test_the_building_columns_are_the_same_length() -> void:
	"""A short column would shift every building after the gap onto another building's height."""
	assert_equal(Dimensions.BUILDING_MAX_Y_U.size(), Dimensions.BUILDING_KEY.size(),
		"one unit height per building key")
	assert_equal(Dimensions.BUILDING_MAX_Y_MM.size(), Dimensions.BUILDING_KEY.size(),
		"one millimetre height per building key")


func test_named_building_envelopes_match_the_ruling() -> void:
	"""Spot-check the extremes and the three buildings the comparison scene depends on."""
	var expected: Dictionary = {
		&"lookout": 8192, &"hall": 7168, &"mill": 7168, &"residence": 6144,
		&"workbench": 3584, &"kitchen": 5120, &"open_stockpile": 2560,
		&"saltpan": 512, &"dirt_path": 64, &"paved_path": 128,
	}
	var found := IntMath.IntResult.new()
	for key: StringName in expected:
		assert_true(Dimensions.building_max_y_units_into(key, found),
			"%s resolves" % key)
		assert_equal(found.value, expected[key], "%s envelope in units" % key)


func test_every_derived_millimetre_is_the_rounded_unit_value() -> void:
	"""The millimetre column is derived. A hand-edited millimetre would silently disagree."""
	for row: int in Dimensions.building_count():
		assert_equal(Dimensions.BUILDING_MAX_Y_MM[row],
			Dimensions.millimetres_from_units(Dimensions.BUILDING_MAX_Y_U[row]),
			"%s millimetres follow its units" % Dimensions.BUILDING_KEY[row])
	for row: int in Dimensions.species_count():
		assert_equal(Dimensions.SPECIES_HEIGHT_MM[row],
			Dimensions.millimetres_from_units(Dimensions.SPECIES_HEIGHT_U[row]),
			"%s millimetres follow its units" % Dimensions.SPECIES_KEY[row])


func test_dirt_path_is_the_only_envelope_millimetres_cannot_express() -> void:
	"""64 u is 62.5 mm. Recorded by name so nobody later treats 63 mm as the authority."""
	var inexact: PackedStringArray = PackedStringArray()
	for row: int in Dimensions.building_count():
		if not Dimensions.units_convert_to_millimetres_exactly(Dimensions.BUILDING_MAX_Y_U[row]):
			inexact.append(String(Dimensions.BUILDING_KEY[row]))
	assert_equal(inexact.size(), 1, "exactly one envelope is not a whole millimetre")
	assert_equal(inexact[0], "dirt_path", "and it is dirt_path")
	assert_equal(Dimensions.millimetres_from_units(64), 63, "62.5 mm rounds half up to 63")


func test_every_species_candidate_is_present_and_looked_up_by_key() -> void:
	"""The five species the ruling names, and no silent extra."""
	assert_equal(Dimensions.species_count(), 5, "five comparison candidates")
	var expected: Dictionary = {
		&"mouse": 1024, &"mole": 922, &"squirrel": 1178, &"otter": 1526, &"badger": 2611,
	}
	var found := IntMath.IntResult.new()
	for key: StringName in expected:
		assert_true(Dimensions.has_species(key), "%s is declared" % key)
		assert_true(Dimensions.species_height_units_into(key, found), "%s resolves" % key)
		assert_equal(found.value, expected[key], "%s candidate height in units" % key)


func test_every_species_row_names_its_approval_and_the_anchor_keeps_its_provenance() -> void:
	"""Each row says where its number came from, and DEC-039 is why they now say APPROVED.

	THIS TEST WAS INVERTED, and the old assertion is worth recording. It required every status to
	contain "COMPARISON", because bulk proportions were open and nothing could read as production
	approval. DEC-039 closed that on 2026-09-12 against decision 0002's rendered elevation, so the
	old assertion now pins the defect rather than the contract.

	What is NOT approved stays visible: the mouse keeps ANCHOR_SOURCED because its 1.0 m came from
	crowd §9.1 rather than from this review, and `proportion_comparison.LANDMARK_STATUS` is still
	PROPOSED_FOR_REVIEW -- DEC-039 ruled on scale BETWEEN species, not on where the eye, hip and
	shoulder sit within one body.
	"""
	assert_equal(Dimensions.SPECIES_STATUS.size(), Dimensions.species_count(),
		"one status per species")
	for row: int in Dimensions.species_count():
		var status: String = String(Dimensions.SPECIES_STATUS[row])
		assert_true(status.contains("APPROVED"),
			"%s names its approval" % Dimensions.SPECIES_KEY[row])
		assert_false(status.contains("CANDIDATE"),
			"%s no longer reads as an unapproved candidate" % Dimensions.SPECIES_KEY[row])
	assert_true(String(Dimensions.SPECIES_STATUS[0]).contains("ANCHOR_SOURCED"),
		"the mouse still records that its height is sourced, not authored for this review")


func test_an_unknown_species_refuses_instead_of_reporting_a_height() -> void:
	"""A missing lookup must not hand back a number that a modeller could build to."""
	var found := IntMath.IntResult.new()
	found.succeed(9999)
	assert_false(Dimensions.species_height_units_into(&"wolverine", found),
		"an undeclared species refuses")
	assert_false(found.ok, "the result is marked failed")
	assert_equal(found.value, 0, "and the stale 9999 is cleared, not returned")
	assert_true(found.error.contains("wolverine"), "the refusal names the key")


func test_an_unknown_building_refuses_instead_of_reporting_zero_height() -> void:
	"""0 u is a legal flat-surface envelope, so absence must not be reported as 0."""
	var found := IntMath.IntResult.new()
	assert_false(Dimensions.building_max_y_units_into(&"treehouse", found),
		"an undeclared building refuses")
	assert_equal(found.value, 0, "value zeroed")
	assert_false(found.ok, "outcome is a refusal, not a zero-height answer")


func test_settlement_l0_admission_carries_the_ruling_hysteresis() -> void:
	"""64 px nominal, +/-10%, cap 24, 0.20 s. Battle's 180 px and cap 48 are untouched."""
	assert_equal(Dimensions.SETTLEMENT_L0_NOMINAL_TENTHS_PX, 640, "nominal 64.0 px")
	assert_equal(Dimensions.SETTLEMENT_L0_PROMOTE_TENTHS_PX,
		Dimensions.SETTLEMENT_L0_NOMINAL_TENTHS_PX * 11 / 10, "promote is nominal + 10%")
	assert_equal(Dimensions.SETTLEMENT_L0_DEMOTE_BELOW_TENTHS_PX,
		Dimensions.SETTLEMENT_L0_NOMINAL_TENTHS_PX * 9 / 10, "demote is nominal - 10%")
	assert_equal(Dimensions.SETTLEMENT_L0_POOL_CAP, 24, "settlement pool cap")
	assert_equal(Dimensions.SETTLEMENT_L0_RESIDENCE_MS, 200, "0.20 s residence")
	assert_equal(Dimensions.BATTLE_L0_NOMINAL_TENTHS_PX, 1800, "battle stays at 180 px")
	assert_equal(Dimensions.BATTLE_L0_POOL_CAP, 48, "battle cap stays at 48")


func test_static_admission_carries_its_own_hysteresis() -> void:
	"""Static near/mid thresholds are 180/48 px with the same 10% band, per GAP-04."""
	assert_equal(Dimensions.STATIC_PROMOTE_NEAR_TENTHS_PX,
		Dimensions.STATIC_INITIAL_NEAR_TENTHS_PX * 11 / 10, "near promote is 198.0 px")
	assert_equal(Dimensions.STATIC_DEMOTE_NEAR_BELOW_TENTHS_PX,
		Dimensions.STATIC_INITIAL_NEAR_TENTHS_PX * 9 / 10, "near demote is 162.0 px")
	assert_equal(Dimensions.STATIC_PROMOTE_MID_TENTHS_PX,
		Dimensions.STATIC_INITIAL_MID_TENTHS_PX * 11 / 10, "mid promote is 52.8 px")
	assert_equal(Dimensions.STATIC_DEMOTE_MID_BELOW_TENTHS_PX,
		Dimensions.STATIC_INITIAL_MID_TENTHS_PX * 9 / 10, "mid demote is 43.2 px")


func test_every_static_family_ceiling_falls_from_near_to_far() -> void:
	"""A mid tier heavier than its near tier would make the LOD chain pointless."""
	var near := IntMath.IntResult.new()
	var mid := IntMath.IntResult.new()
	var far := IntMath.IntResult.new()
	for family: int in Dimensions.FAMILY_COUNT:
		assert_true(Dimensions.family_triangle_ceiling_into(family, 0, near), "near resolves")
		assert_true(Dimensions.family_triangle_ceiling_into(family, 1, mid), "mid resolves")
		assert_true(Dimensions.family_triangle_ceiling_into(family, 2, far), "far resolves")
		assert_true(near.value > mid.value and mid.value > far.value,
			"%s falls near > mid > far" % Dimensions.FAMILY_KEY[family])


func test_named_static_family_ceilings_match_the_ruling() -> void:
	"""The five published rows, checked at their near tier and their texture edge."""
	var expected_near: Array[int] = [32000, 2000, 1200, 6000, 600]
	var expected_edge: Array[int] = [2048, 1024, 1024, 2048, 1024]
	var found := IntMath.IntResult.new()
	for family: int in Dimensions.FAMILY_COUNT:
		assert_true(Dimensions.family_triangle_ceiling_into(family, 0, found), "resolves")
		assert_equal(found.value, expected_near[family],
			"%s near triangles" % Dimensions.FAMILY_KEY[family])
		assert_equal(Dimensions.FAMILY_TEXTURE_EDGE_CEILING[family], expected_edge[family],
			"%s texture edge" % Dimensions.FAMILY_KEY[family])


func test_a_building_keeps_sixteen_surfaces_at_near_and_mid_and_four_at_far() -> void:
	"""GAP-04 reconciles multipart cutaways with the budget; far must not fuse into a shell."""
	var found := IntMath.IntResult.new()
	assert_true(Dimensions.family_surface_ceiling_into(
		Dimensions.FAMILY_BUILDING_ASSEMBLY, 0, found), "near resolves")
	assert_equal(found.value, 16, "sixteen draw surfaces at near")
	assert_true(Dimensions.family_surface_ceiling_into(
		Dimensions.FAMILY_BUILDING_ASSEMBLY, 1, found), "mid resolves")
	assert_equal(found.value, 16, "sixteen at mid")
	assert_true(Dimensions.family_surface_ceiling_into(
		Dimensions.FAMILY_BUILDING_ASSEMBLY, 2, found), "far resolves")
	assert_equal(found.value, 4, "four at far")
	assert_equal(Dimensions.BUILDING_MATERIAL_CEILING, 4, "four distinct shared materials")


func test_a_ceiling_lookup_outside_its_domain_refuses() -> void:
	"""Out-of-range family or tier must refuse rather than report a budget of zero."""
	var found := IntMath.IntResult.new()
	assert_false(Dimensions.family_triangle_ceiling_into(Dimensions.FAMILY_COUNT, 0, found),
		"an unknown family refuses")
	assert_false(Dimensions.family_triangle_ceiling_into(0, Dimensions.STATIC_LOD_COUNT, found),
		"an unknown tier refuses")
	assert_false(Dimensions.family_surface_ceiling_into(-1, 0, found),
		"a negative family refuses")
	assert_false(Dimensions.crop_whole_field_triangles_into(3, found),
		"an unknown crop tier refuses")


func test_the_whole_field_crop_arithmetic_matches_the_rulings_published_totals() -> void:
	"""4096 permitted farm tiles: 1048576 all-near, 393216 all-mid, 65536 all-far."""
	var found := IntMath.IntResult.new()
	assert_true(Dimensions.crop_whole_field_triangles_into(0, found), "near resolves")
	assert_equal(found.value, 1048576, "all-near worst case")
	assert_true(Dimensions.crop_whole_field_triangles_into(1, found), "mid resolves")
	assert_equal(found.value, 393216, "all-mid")
	assert_true(Dimensions.crop_whole_field_triangles_into(2, found), "far resolves")
	assert_equal(found.value, 65536, "all-far")
	assert_equal(Dimensions.CROP_ACTIVE_TILE_LIMIT, 4096, "GDD §4.2's permitted farm tiles")


func test_the_aggregate_environment_allowances_are_the_published_byte_counts() -> void:
	"""128 MiB meshes and 256 MiB textures, inside the existing loaded-graphics ceiling."""
	assert_equal(Dimensions.NONCREATURE_MESH_BYTES, 134217728, "128 MiB of meshes")
	assert_equal(Dimensions.NONCREATURE_TEXTURE_BYTES, 268435456, "256 MiB of textures")
	var one_set: int = 0
	for level: int in 12:
		one_set += (1 << level) * (1 << level) * 4 * 3
	assert_equal(one_set, 67108860, "one 2048 albedo+normal+ORM set with full mips")
	assert_true(one_set * 4 <= Dimensions.NONCREATURE_TEXTURE_BYTES,
		"four such sets fit, and a fifth does not")
	assert_true(one_set * 5 > Dimensions.NONCREATURE_TEXTURE_BYTES, "the fifth does not")


func test_the_shared_enclosed_building_values_are_the_rulings() -> void:
	"""Door opening, clear internal height and the work-surface candidate, in units."""
	assert_equal(Dimensions.DOOR_OPENING_WIDTH_U, 1536, "door opening width")
	assert_equal(Dimensions.DOOR_OPENING_HEIGHT_U, 3072, "door opening height")
	assert_equal(Dimensions.MIN_CLEAR_INTERNAL_HEIGHT_U, 3072, "minimum clear internal height")
	assert_equal(Dimensions.WORK_SURFACE_TOP_U, 640, "work-surface top candidate")
	assert_equal(Dimensions.CUTAWAY_CUT_HEIGHT_U, 1024, "the inherited 1 m cutaway cut")


func test_the_material_baseline_stores_roughness_and_metallic_as_integers() -> void:
	"""GAP-09's starting values, kept off floats so the table cannot drift by rounding."""
	assert_equal(Dimensions.MATERIAL_KEY.size(),
		Dimensions.MATERIAL_ROUGHNESS_PERMILLE.size(), "one roughness per material")
	assert_equal(Dimensions.MATERIAL_KEY.size(),
		Dimensions.MATERIAL_METALLIC_PERMILLE.size(), "one metallic per material")
	var expected: Array[int] = [900, 800, 850, 650, 500]
	for row: int in Dimensions.MATERIAL_KEY.size():
		assert_equal(Dimensions.MATERIAL_ROUGHNESS_PERMILLE[row], expected[row],
			"%s roughness" % Dimensions.MATERIAL_KEY[row])
	for row: int in Dimensions.MATERIAL_KEY.size():
		var metallic: int = Dimensions.MATERIAL_METALLIC_PERMILLE[row]
		assert_true(metallic == 0 or metallic == 1000,
			"%s is fully metal or fully not" % Dimensions.MATERIAL_KEY[row])
