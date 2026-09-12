extends "res://test/framework/test_case.gd"
## Coverage for `godot/assets/lookdev/proportion_comparison.gd` and its written manifest.
##
## The scene exists so Brendan can judge five species against one door, one table and one
## work surface. That judgement is only worth anything if the geometry is actually at the
## ruling's numbers, so these tests MEASURE the assembled meshes rather than reading the
## constants back:
##
##   * `test_every_standing_blockout_measures_its_candidate_height` takes the union AABB of
##     each blockout's real boxes and requires the top to land on the candidate height to the
##     millimetre. Shorten one ear and it fails;
##   * `test_the_tail_is_excluded_from_height` is the squirrel case the measurement convention
##     was written for -- its tail is 950 permille of its body and must not appear in height;
##   * `test_every_blockout_stands_on_the_ground_plane` checks soles on Y = 0, which is the
##     other half of the same convention.
##
## Nothing here asserts that a candidate height is correct. That is the review this scene is
## built to make possible, and no test can stand in for it.

const Comparison := preload("res://assets/lookdev/proportion_comparison.gd")
const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")

const MANIFEST_PATH: String = "res://assets/lookdev/proportion_comparison_manifest.json"
const SCENE_PATH: String = "res://assets/lookdev/proportion_comparison.tscn"

var _scene: Node3D = null


func before_each() -> void:
	"""Assemble one fresh comparison scene for the test about to run."""
	_scene = Comparison.build_scene()


func after_each() -> void:
	"""Release the assembled scene; it is never added to a running tree."""
	if _scene != null:
		_scene.free()
		_scene = null


func test_the_scene_holds_every_species_in_every_pose() -> void:
	"""Twenty cells. A missing one silently removes a species from the comparison."""
	assert_equal(Comparison.species_count(), 5, "five species")
	assert_equal(Comparison.POSE_COUNT, 4, "four poses")
	for row: int in Comparison.species_count():
		for pose: int in Comparison.POSE_COUNT:
			var blockout: Node3D = Comparison.blockout_of(_scene, row, pose)
			assert_not_null(blockout, "%s %s exists"
				% [Dimensions.SPECIES_KEY[row], Comparison.POSE_KEY[pose]])


func test_every_standing_blockout_measures_its_candidate_height() -> void:
	"""Measured from the real boxes: the crown must land on the ruling's candidate exactly."""
	for row: int in Comparison.species_count():
		var blockout: Node3D = Comparison.blockout_of(_scene, row, Comparison.POSE_STANDING)
		var bounds: AABB = Comparison.measured_bounds_mm(blockout)
		var crown: int = roundi(bounds.position.y + bounds.size.y)
		assert_equal(crown, Dimensions.SPECIES_HEIGHT_MM[row],
			"%s standing crown in millimetres" % Dimensions.SPECIES_KEY[row])


func test_every_blockout_stands_on_the_ground_plane() -> void:
	""""Supporting soles on Y = 0" is half the measurement convention, in every pose."""
	for row: int in Comparison.species_count():
		for pose: int in Comparison.POSE_COUNT:
			var blockout: Node3D = Comparison.blockout_of(_scene, row, pose)
			var bounds: AABB = Comparison.measured_bounds_mm(blockout)
			assert_equal(roundi(bounds.position.y), 0,
				"%s %s soles on zero" % [Dimensions.SPECIES_KEY[row],
					Comparison.POSE_KEY[pose]])


func test_the_tail_is_excluded_from_height() -> void:
	"""A squirrel tail is 950 permille of its body. Height must still be the 1024 u candidate."""
	var squirrel: int = Dimensions.SPECIES_KEY.find(&"squirrel")
	assert_true(squirrel >= 0, "the squirrel row exists")
	assert_true(Comparison.TAIL_PERMILLE[squirrel] > 900, "and its tail really is that long")
	var blockout: Node3D = Comparison.blockout_of(_scene, squirrel, Comparison.POSE_STANDING)
	var bounds: AABB = Comparison.measured_bounds_mm(blockout)
	assert_equal(roundi(bounds.position.y + bounds.size.y),
		Dimensions.SPECIES_HEIGHT_MM[squirrel], "the tail does not raise the crown")
	assert_true(bounds.size.z > Dimensions.SPECIES_HEIGHT_MM[squirrel] * 0.5,
		"but the tail is present in the depth extent")


func test_the_ear_crowned_species_are_taller_than_their_skulls() -> void:
	"""Mouse and squirrel crowns are ear tips; mole, otter and badger crowns are skulls."""
	for row: int in Comparison.species_count():
		var skull: int = Comparison.SKULL_TOP_PERMILLE[row]
		if Comparison.EAR_DEFINES_CROWN[row] == 1:
			assert_true(skull < Comparison.PERMILLE,
				"%s skull sits below its ear tip" % Dimensions.SPECIES_KEY[row])
		else:
			assert_equal(skull, Comparison.PERMILLE,
				"%s crown is its skull" % Dimensions.SPECIES_KEY[row])


func test_crouching_lowers_the_crown_and_standing_walking_carrying_do_not() -> void:
	"""Only the crouch changes stature; a walking pose that shrank a species would mislead."""
	for row: int in Comparison.species_count():
		var standing: int = Comparison.crown_mm(row, Comparison.POSE_STANDING)
		assert_equal(Comparison.crown_mm(row, Comparison.POSE_WALKING), standing,
			"%s walks at full height" % Dimensions.SPECIES_KEY[row])
		assert_equal(Comparison.crown_mm(row, Comparison.POSE_CARRYING), standing,
			"%s carries at full height" % Dimensions.SPECIES_KEY[row])
		assert_true(Comparison.crown_mm(row, Comparison.POSE_CROUCHING) < standing,
			"%s crouches lower" % Dimensions.SPECIES_KEY[row])


func test_the_landmark_columns_are_ordered_and_complete() -> void:
	"""Eye above shoulder above hip, for every species, and one entry per species."""
	var columns: Array = [Comparison.SKULL_TOP_PERMILLE, Comparison.EYE_PERMILLE,
		Comparison.NECK_PERMILLE, Comparison.SHOULDER_PERMILLE, Comparison.HIP_PERMILLE,
		Comparison.TORSO_WIDTH_PERMILLE, Comparison.TORSO_DEPTH_PERMILLE,
		Comparison.MUZZLE_PERMILLE, Comparison.TAIL_PERMILLE, Comparison.EAR_DEFINES_CROWN]
	for column: Array in columns:
		assert_equal(column.size(), Comparison.species_count(), "one entry per species")
	for row: int in Comparison.species_count():
		var key: StringName = Dimensions.SPECIES_KEY[row]
		assert_true(Comparison.EYE_PERMILLE[row] > Comparison.NECK_PERMILLE[row],
			"%s eye above neck" % key)
		assert_true(Comparison.NECK_PERMILLE[row] > Comparison.SHOULDER_PERMILLE[row],
			"%s neck above shoulder" % key)
		assert_true(Comparison.SHOULDER_PERMILLE[row] > Comparison.HIP_PERMILLE[row],
			"%s shoulder above hip" % key)


func test_the_landmarks_are_still_review_inputs_although_the_heights_are_approved() -> void:
	"""The two axes moved apart on 2026-09-12 and this is what keeps them apart.

	THIS TEST WAS CHANGED. It previously asserted that the heights were NOT production approval,
	which was true until DEC-039 approved the relative proportions of all five species against the
	rendered elevation. What DEC-039 did NOT rule on is where the eye, hip and shoulder sit WITHIN
	a body -- so `LANDMARK_STATUS` is unchanged, and asserting both here is what stops a later
	reader treating one approval as the other.
	"""
	assert_equal(String(Comparison.LANDMARK_STATUS), "PROPOSED_FOR_REVIEW",
		"landmarks are still only proposed")
	assert_false(String(Comparison.HEIGHT_STATUS).contains("NOT_PRODUCTION_APPROVAL"),
		"heights are no longer labelled as un-approved")
	assert_true(String(Comparison.HEIGHT_STATUS).contains("APPROVED"),
		"and say so positively rather than by the absence of a denial")


func test_the_doorway_carries_the_rulings_opening_to_the_millimetre() -> void:
	"""1536 x 3072 u is exactly 1500 x 3000 mm, so the scene rounds nothing."""
	assert_equal(Comparison.DOOR_OPENING_WIDTH_MM,
		Dimensions.millimetres_from_units(Dimensions.DOOR_OPENING_WIDTH_U), "opening width")
	assert_equal(Comparison.DOOR_OPENING_HEIGHT_MM,
		Dimensions.millimetres_from_units(Dimensions.DOOR_OPENING_HEIGHT_U), "opening height")
	assert_true(Dimensions.units_convert_to_millimetres_exactly(
		Dimensions.DOOR_OPENING_WIDTH_U), "the width is a whole millimetre")
	assert_true(Dimensions.units_convert_to_millimetres_exactly(
		Dimensions.DOOR_OPENING_HEIGHT_U), "the height is a whole millimetre")


func test_the_door_panel_head_fits_the_workbench_envelope_exactly() -> void:
	"""The panel is not invented: 3000 mm opening plus header equals the 3584 u envelope."""
	var envelope := preload("res://scripts/core/int_math.gd").IntResult.new()
	assert_true(Dimensions.building_max_y_units_into(&"workbench", envelope),
		"the workbench envelope resolves")
	assert_equal(Comparison.DOOR_PANEL_HEIGHT_MM,
		Dimensions.millimetres_from_units(envelope.value), "panel head at the envelope")
	assert_true(Comparison.DOOR_PANEL_HEIGHT_MM > Comparison.DOOR_OPENING_HEIGHT_MM,
		"a header exists above the opening")
	assert_true(Comparison.DOOR_PANEL_WIDTH_MM > Comparison.DOOR_OPENING_WIDTH_MM,
		"jambs exist beside it")


func test_the_work_surface_top_is_the_rulings_640_unit_candidate() -> void:
	"""640 u is exactly 625 mm. Table and work surface share it, as the ruling states."""
	assert_equal(Comparison.WORK_SURFACE_TOP_MM,
		Dimensions.millimetres_from_units(Dimensions.WORK_SURFACE_TOP_U), "625 mm")
	assert_equal(Comparison.WORK_SURFACE_TOP_MM, 625, "and the number is 625")
	assert_equal(Comparison.TABLE_SIZE_MM, 2000, "a seat place is one 2 m tile")


func test_the_shelter_reference_stands_at_the_workbench_envelope() -> void:
	"""The one full-size building in the scene must measure its own GAP-03 maximum Y."""
	var shelter: Node3D = _scene.get_node_or_null(
		NodePath("building_workbench_reference")) as Node3D
	assert_not_null(shelter, "the shelter is in the scene")
	var bounds: AABB = Comparison.measured_bounds_mm(shelter)
	assert_equal(roundi(bounds.position.y + bounds.size.y), Comparison.SHELTER_HEIGHT_MM,
		"measured roof top")
	assert_equal(Comparison.SHELTER_HEIGHT_MM,
		Dimensions.millimetres_from_units(3584), "and that is the 3584 u envelope")
	assert_equal(Comparison.SHELTER_FOOTPRINT_MM, 6000, "3x3 tiles of 2 m")


func test_every_pose_meets_a_named_station() -> void:
	"""The doorway, the table and the work surface each appear; one pose is open ground."""
	var stations: Dictionary = {}
	for pose: int in Comparison.POSE_COUNT:
		stations[String(Comparison.POSE_STATION[pose])] = true
	for required: String in ["doorway", "table", "work_surface", "open_ground"]:
		assert_true(stations.has(required), "%s is a station" % required)
	assert_equal(stations.size(), Comparison.POSE_COUNT, "no two poses share a station")


func test_every_species_meets_the_same_prop_in_its_own_bay() -> void:
	""""The same door" means identical dimensions in all five bays, not one shared instance."""
	var widths: Array[float] = []
	for row: int in Comparison.species_count():
		var doorway: Node3D = _scene.get_node_or_null(NodePath(
			"%s_%s/doorway" % [Dimensions.SPECIES_KEY[row],
				Comparison.POSE_KEY[Comparison.POSE_STANDING]])) as Node3D
		assert_not_null(doorway, "%s has a doorway" % Dimensions.SPECIES_KEY[row])
		widths.append(Comparison.measured_bounds_mm(doorway).size.x)
	for row: int in widths.size():
		assert_equal(roundi(widths[row]), Comparison.DOOR_PANEL_WIDTH_MM,
			"%s doorway is the same width" % Dimensions.SPECIES_KEY[row])


func test_the_bays_read_first_species_first_in_the_front_elevation() -> void:
	"""The elevation is taken from -Z, where +X is on the left, so bay X descends by row."""
	var previous: int = Comparison.bay_x_mm(0) + 1
	for row: int in Comparison.species_count():
		var here: int = Comparison.bay_x_mm(row)
		assert_true(here < previous, "%s sits left of the next bay"
			% Dimensions.SPECIES_KEY[row])
		previous = here
	assert_equal(Comparison.bay_x_mm(0) + Comparison.bay_x_mm(
		Comparison.species_count() - 1), 0, "the five bays are centred on the origin")


func test_props_sit_behind_or_ahead_according_to_minus_z_forward() -> void:
	"""A doorway stands behind a resident at +Z; a surface they work at is ahead at -Z."""
	assert_true(Comparison.PROP_BEHIND_Z_MM > 0, "the doorway is behind at +Z")
	assert_true(Comparison.PROP_AHEAD_Z_MM < 0, "a work surface is ahead at -Z")
	assert_equal(Comparison.PROP_BEHIND_Z_MM, -Comparison.PROP_AHEAD_Z_MM,
		"both stand off by the same distance")


func test_the_scale_rule_is_graduated_in_whole_bands_to_its_top() -> void:
	"""A rule whose bands did not divide its height would mis-measure everything beside it."""
	assert_equal(Comparison.SCALE_RULE_TOP_MM % Comparison.SCALE_RULE_BAND_MM, 0,
		"the bands divide the rule exactly")
	var rule: Node3D = _scene.get_node_or_null(NodePath("scale_rule")) as Node3D
	assert_not_null(rule, "the rule is in the scene")
	var bounds: AABB = Comparison.measured_bounds_mm(rule)
	assert_equal(roundi(bounds.position.y + bounds.size.y), Comparison.SCALE_RULE_TOP_MM,
		"the rule measures its declared top")


func test_the_written_manifest_agrees_with_the_module_it_was_built_from() -> void:
	"""A stale manifest would describe a scene nobody can rebuild. Regenerate it, do not edit it."""
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "the manifest is committed")
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var document: Variant = JSON.parse_string(text)
	assert_true(document is Dictionary, "the manifest is a JSON object")
	var rows: Array = (document as Dictionary)["species"]
	assert_equal(rows.size(), Comparison.species_count(), "one manifest row per species")
	for row: int in rows.size():
		var entry: Dictionary = rows[row]
		assert_equal(entry["key"], String(Dimensions.SPECIES_KEY[row]), "species order")
		assert_equal(int(entry["candidate_height_u"]), Dimensions.SPECIES_HEIGHT_U[row],
			"%s manifest height in units" % Dimensions.SPECIES_KEY[row])
		assert_equal(int(entry["candidate_height_mm"]), Dimensions.SPECIES_HEIGHT_MM[row],
			"%s manifest height in millimetres" % Dimensions.SPECIES_KEY[row])


func test_the_manifest_records_the_camera_contract_and_its_captures() -> void:
	"""A capture with no camera row cannot be reproduced; a listed capture must exist on disk."""
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	var cameras: Array = document["camera"]
	assert_true(cameras.size() >= 4, "the prescribed views are recorded")
	var default_found: bool = false
	for camera: Dictionary in cameras:
		if float(camera["orbit_metres"]) == 40.0 and float(camera["pitch_degrees"]) == 48.0:
			default_found = true
			assert_equal(float(camera["fov_degrees"]), 55.0, "the shipped vertical FOV")
	assert_true(default_found, "the shipped default camera is among the views")
	for capture: Dictionary in document["captures"]:
		assert_true(FileAccess.file_exists(String(capture["path"])),
			"%s exists on disk" % capture["path"])
		assert_equal(FileAccess.get_sha256(String(capture["path"])),
			String(capture["sha256"]), "%s matches its recorded digest" % capture["view"])


func test_the_manifest_states_that_nothing_here_is_approved_or_generated() -> void:
	"""The scene is a review input. A manifest that read as approval would be the whole risk."""
	var document: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	assert_true(String(document["status"]).contains("NOT_PRODUCTION_APPROVAL"),
		"the status denies approval")
	assert_true(String(document["origin"]).contains("no credit was spent")
		or String(document["origin"]).contains("no credit was spent."),
		"the origin denies paid generation")
	assert_true(document["references"] is Array and (document["references"] as Array).size() > 0,
		"provenance for the supplied references is recorded")


func test_the_packed_scene_on_disk_reopens_with_its_hierarchy_intact() -> void:
	"""The committed .tscn is the reviewable artifact; a flattened pack would lose every bay."""
	assert_true(ResourceLoader.exists(SCENE_PATH), "the packed scene is committed")
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "it loads as a PackedScene")
	var reopened: Node3D = packed.instantiate() as Node3D
	assert_not_null(reopened, "it instantiates")
	for row: int in Comparison.species_count():
		assert_not_null(Comparison.blockout_of(reopened, row, Comparison.POSE_STANDING),
			"%s survived the round trip" % Dimensions.SPECIES_KEY[row])
	reopened.free()
