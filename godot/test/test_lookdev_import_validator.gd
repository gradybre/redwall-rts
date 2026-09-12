extends "res://test/framework/test_case.gd"
## Coverage for `godot/assets/lookdev/asset_import_validator.gd`.
##
## The one check here that earns its keep is the JOIN check. `prep_unit.py` joins every
## imported object into a single mesh, and a managed building normalised through it arrives
## looking perfectly healthy -- correct height, base on zero, one tidy mesh -- with its
## cutaway destroyed. `test_a_single_joined_mesh_is_refused_for_a_managed_building` is the
## check that the destruction is caught at import rather than when someone selects the
## building in game and the roof will not come off.
##
## The naming tests bind asset names to the live catalog rather than to a copied list, so
## renaming a BuildingDefinition key without renaming its assets fails here.

const Validator := preload("res://assets/lookdev/asset_import_validator.gd")
const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")


func _report() -> Validator.Report:
	"""A fresh empty report for one assertion."""
	return Validator.Report.new()


# --- GAP-08 naming -----------------------------------------------------------------------


func test_a_well_formed_name_of_every_kind_passes() -> void:
	"""One valid example per GAP-08 kind, so the rule is exercised and not merely declared."""
	var names: Array[String] = [
		"building_covered_store_a_lod0", "building_hall_b_lod2",
		"furniture_kitchen_bench_a_lod1", "prop_wicker_basket_a_lod0",
		"flora_fern_clump_summer_lod2", "crop_grain_ripe_lod0", "terrain_loam_a",
	]
	for asset_name: String in names:
		var report: Validator.Report = _report()
		Validator.validate_asset_name(asset_name, report)
		assert_true(report.ok(), "%s passes: %s" % [asset_name, report.failures])


func test_a_name_that_is_not_lowercase_ascii_is_refused() -> void:
	"""GAP-08 says ASCII. A capital or an accent breaks a case-sensitive asset pipeline."""
	for asset_name: String in ["Building_hall_a_lod0", "building_håll_a_lod0",
			"building hall a lod0"]:
		var report: Validator.Report = _report()
		Validator.validate_asset_name(asset_name, report)
		assert_false(report.ok(), "%s is refused" % asset_name)


func test_a_name_with_no_kind_prefix_is_refused() -> void:
	"""Without a kind the name binds to no catalog domain at all."""
	var report: Validator.Report = _report()
	Validator.validate_asset_name("hall_a_lod0", report)
	assert_false(report.ok(), "an unprefixed name is refused")
	assert_true(report.failures[0].contains("kind prefix"), "the refusal says why")


func test_a_missing_or_out_of_range_tier_suffix_is_refused() -> void:
	"""n is 0, 1 or 2 for these static tiers; lod3 is a creature tier and does not apply."""
	for asset_name: String in ["building_hall_a", "building_hall_a_lod3",
			"building_hall_a_lodx", "building_hall_a_lod-1"]:
		var report: Validator.Report = _report()
		Validator.validate_asset_name(asset_name, report)
		assert_false(report.ok(), "%s is refused" % asset_name)


func test_terrain_carries_no_tier_suffix() -> void:
	"""GAP-08 gives terrain `terrain_<soil_key>_<variant>` with no lod tail."""
	var with_tier: Validator.Report = _report()
	Validator.validate_asset_name("terrain_loam_a_lod0", with_tier)
	assert_false(with_tier.ok(), "a terrain name with a tier suffix is refused")
	var without: Validator.Report = _report()
	Validator.validate_asset_name("terrain_sand_b", without)
	assert_true(without.ok(), "and without one it passes")


func test_a_name_that_invents_a_catalog_key_is_refused() -> void:
	"""Art semantic keys are not new catalog entries; a building name must name a building."""
	var cases: Array[String] = [
		"building_treehouse_a_lod0", "furniture_wardrobe_a_lod0",
		"crop_barley_ripe_lod0", "terrain_gravel_a",
	]
	for asset_name: String in cases:
		var report: Validator.Report = _report()
		Validator.validate_asset_name(asset_name, report)
		assert_false(report.ok(), "%s is refused" % asset_name)


func test_a_crop_name_must_name_a_real_crop_state() -> void:
	"""Five states exist. A crop asset for a sixth would bind to nothing at runtime."""
	var bad: Validator.Report = _report()
	Validator.validate_asset_name("crop_grain_harvested_lod0", bad)
	assert_false(bad.ok(), "an invented state is refused")
	for state: String in ["empty", "sown", "growing", "ripe", "withered"]:
		var good: Validator.Report = _report()
		Validator.validate_asset_name("crop_roots_%s_lod1" % state, good)
		assert_true(good.ok(), "crop_roots_%s_lod1 passes" % state)


func test_a_name_with_no_variant_token_is_refused() -> void:
	"""Variants begin a, b, c. Without one, a second variant has nowhere to go."""
	var report: Validator.Report = _report()
	Validator.validate_asset_name("building_hall_lod0", report)
	assert_false(report.ok(), "a name with no variant is refused")


# --- GAP-06 hierarchy --------------------------------------------------------------------


func _complete_parts() -> PackedStringArray:
	"""The ten GAP-06 named parts of a managed building."""
	var names: PackedStringArray = PackedStringArray()
	for part: StringName in Validator.REQUIRED_BUILDING_PARTS:
		names.append(String(part))
	return names


func test_the_complete_named_part_set_passes() -> void:
	"""Roof, four upper walls, four lower walls and a floor: ten addressable parts."""
	var report: Validator.Report = _report()
	Validator.validate_building_parts(_complete_parts(), report)
	assert_true(report.ok(), "the complete set passes: %s" % report.failures)
	assert_equal(report.notes.size(), 0, "and raises no note")
	assert_equal(Validator.REQUIRED_BUILDING_PARTS.size(), 10, "ten named parts")


func test_a_missing_cutaway_part_is_refused_by_name() -> void:
	"""A building with no `wall_n_upper` cannot hide its camera-facing north wall."""
	var parts: PackedStringArray = _complete_parts()
	parts.remove_at(parts.find("wall_n_upper"))
	var report: Validator.Report = _report()
	Validator.validate_building_parts(parts, report)
	assert_false(report.ok(), "the incomplete set is refused")
	assert_true(report.failures[0].contains("wall_n_upper"), "the refusal names the part")


func test_a_duplicated_part_is_refused() -> void:
	"""Two nodes called `roof` make "hide the roof" ambiguous at runtime."""
	var parts: PackedStringArray = _complete_parts()
	parts.append("roof")
	var report: Validator.Report = _report()
	Validator.validate_building_parts(parts, report)
	assert_false(report.ok(), "a duplicate part is refused")


func test_a_single_joined_mesh_is_refused_for_a_managed_building() -> void:
	"""This is the prep_unit.py hazard: one tidy mesh, cutaway silently destroyed."""
	var report: Validator.Report = _report()
	Validator.validate_building_parts(PackedStringArray(["residence"]), report)
	assert_false(report.ok(), "a joined single mesh is refused")
	var joined: bool = false
	for failure: String in report.failures:
		if failure.contains("prep_unit.py"):
			joined = true
	assert_true(joined, "and the refusal names the tool that did it")


func test_an_unnamed_extra_part_is_a_note_and_not_a_failure() -> void:
	"""Cap and opening naming is not settled; the validator records it instead of inventing it."""
	var parts: PackedStringArray = _complete_parts()
	parts.append("cap_door_north")
	var report: Validator.Report = _report()
	Validator.validate_building_parts(parts, report)
	assert_true(report.ok(), "an extra part does not fail the import")
	assert_equal(report.notes.size(), 1, "but it is recorded for a human")
	assert_true(report.notes[0].contains("cap_door_north"), "the note names the part")


func test_a_wall_part_on_the_wrong_side_of_the_cut_is_refused() -> void:
	"""The cut is 1 m = 1024 u. An upper wall that starts below it cannot fade independently."""
	var low: Validator.Report = _report()
	Validator.validate_part_cut("wall_e_upper", 900, 3000, low)
	assert_false(low.ok(), "an upper wall starting below the cut is refused")
	var high: Validator.Report = _report()
	Validator.validate_part_cut("wall_e_lower", 0, 1100, high)
	assert_false(high.ok(), "a lower wall reaching above the cut is refused")
	var good: Validator.Report = _report()
	Validator.validate_part_cut("wall_e_upper", 1024, 3000, good)
	Validator.validate_part_cut("wall_e_lower", 0, 1024, good)
	assert_true(good.ok(), "parts meeting exactly at the cut pass: %s" % good.failures)


func test_inverted_part_bounds_are_refused_before_the_cut_is_judged() -> void:
	"""min above max is a broken measurement, not a cut-line question."""
	var report: Validator.Report = _report()
	Validator.validate_part_cut("wall_w_lower", 2000, 100, report)
	assert_false(report.ok(), "inverted bounds are refused")
	assert_equal(report.failures.size(), 1, "and only that one thing is reported")


func test_collect_part_names_reports_direct_child_meshes_in_order() -> void:
	"""What a hierarchy check reads: a joined import yields one name, a split import many."""
	var root := Node3D.new()
	for part: String in ["roof", "floor"]:
		var mesh := MeshInstance3D.new()
		mesh.name = part
		mesh.mesh = BoxMesh.new()
		root.add_child(mesh)
	var spare := Node3D.new()
	spare.name = "pivot"
	root.add_child(spare)
	var names: PackedStringArray = Validator.collect_part_names(root)
	assert_equal(names.size(), 2, "only mesh children are parts")
	assert_equal(names[0], "roof", "in scene order")
	assert_equal(names[1], "floor", "in scene order")
	root.free()


# --- GAP-03 envelope and GAP-04 budget -----------------------------------------------------


func test_a_building_over_its_envelope_is_refused_with_both_numbers() -> void:
	"""The workbench envelope is 3584 u; a 3585 u model is one unit over and still refused."""
	var over: Validator.Report = _report()
	Validator.validate_building_envelope(&"workbench", 0, 3585, over)
	assert_false(over.ok(), "one unit over is refused")
	assert_true(over.failures[0].contains("3584"), "the refusal states the envelope")
	var exact: Validator.Report = _report()
	Validator.validate_building_envelope(&"workbench", 0, 3584, exact)
	assert_true(exact.ok(), "exactly at the envelope passes: %s" % exact.failures)


func test_a_building_not_based_at_local_zero_is_refused() -> void:
	"""GAP-03 fixes local Y = 0 as the placed base; a floating pivot misplaces every model."""
	var report: Validator.Report = _report()
	Validator.validate_building_envelope(&"kitchen", 128, 5000, report)
	assert_false(report.ok(), "a base above zero is refused")


func test_an_unknown_building_envelope_refuses_rather_than_passing() -> void:
	"""An asset for a building with no envelope must not be waved through as compliant."""
	var report: Validator.Report = _report()
	Validator.validate_building_envelope(&"treehouse", 0, 1000, report)
	assert_false(report.ok(), "an unknown building is refused")


func test_a_static_asset_over_any_of_its_three_ceilings_is_refused() -> void:
	"""Triangles, draw surfaces and texture edge are separate limits, all enforced."""
	var triangles: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_FURNITURE_INSTANCE, 0, 2001, 2, 1024,
		triangles)
	assert_false(triangles.ok(), "2001 triangles at furniture near is refused")
	var surfaces: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_SMALL_PROP, 0, 100, 2, 1024, surfaces)
	assert_false(surfaces.ok(), "two surfaces on a one-surface prop is refused")
	var texture: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_GROUND_COVER_CLUSTER, 0, 10, 1, 2048,
		texture)
	assert_false(texture.ok(), "a 2048 texture on a 1024 family is refused")
	var good: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_FURNITURE_INSTANCE, 0, 2000, 2, 1024,
		good)
	assert_true(good.ok(), "exactly at every ceiling passes: %s" % good.failures)


func test_a_far_building_may_keep_four_surfaces_but_not_five() -> void:
	"""Far must still honour cutaway grouping; five surfaces would break the far budget."""
	var five: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_BUILDING_ASSEMBLY, 2, 2500, 5, 2048,
		five)
	assert_false(five.ok(), "five far surfaces is refused")
	var four: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_BUILDING_ASSEMBLY, 2, 2500, 4, 2048,
		four)
	assert_true(four.ok(), "four passes: %s" % four.failures)


func test_a_budget_check_on_an_unknown_family_refuses_rather_than_passing() -> void:
	"""An unrecognised family must not report a clean bill of health."""
	var report: Validator.Report = _report()
	Validator.validate_static_budget(Dimensions.FAMILY_COUNT, 0, 1, 1, 64, report)
	assert_false(report.ok(), "an unknown family is refused")


func test_a_building_over_four_distinct_materials_is_refused() -> void:
	"""GAP-04 caps a building assembly at four distinct shared materials."""
	var five: Validator.Report = _report()
	Validator.validate_building_materials(5, five)
	assert_false(five.ok(), "five materials is refused")
	var four: Validator.Report = _report()
	Validator.validate_building_materials(4, four)
	assert_true(four.ok(), "four passes")


func test_a_report_summary_names_the_outcome_and_the_counts() -> void:
	"""A tool prints this line; it must not read PASS when something failed."""
	var clean: Validator.Report = _report()
	assert_true(clean.summary().begins_with("PASS"), "an empty report passes")
	clean.note("something for a human")
	assert_true(clean.summary().begins_with("PASS"), "a note alone does not fail it")
	clean.fail("something broken")
	assert_true(clean.summary().begins_with("REFUSED"), "a failure flips it")
	assert_true(clean.summary().contains("1 failure(s)"), "and the count is reported")
