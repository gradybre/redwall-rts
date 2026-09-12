extends "res://test/framework/test_case.gd"
## Coverage for catalog compilation and validation: ascending-ASCII determinism, insertion-order
## independence, fixed-enum preservation, and the ItemDefinition 256-key ceiling.

const CatalogScript := preload("res://scripts/core/catalog.gd")

const SPECIES_KEYS: Array[StringName] = [
	&"mouse", &"shrew", &"mole", &"rat", &"squirrel", &"sparrow", &"otter", &"hare",
	&"ferret", &"weasel", &"hedgehog", &"kestrel", &"badger", &"fox", &"wildcat", &"wolverine",
]
const SPECIES_SORTED: Array[StringName] = [
	&"badger", &"ferret", &"fox", &"hare", &"hedgehog", &"kestrel", &"mole", &"mouse",
	&"otter", &"rat", &"shrew", &"sparrow", &"squirrel", &"weasel", &"wildcat", &"wolverine",
]


func _assert_domain_ok(result: CatalogScript.DomainResult, message: String) -> CatalogScript.DomainResult:
	"""Assert a domain compile succeeded (surfacing its refusal reason if not) and return it."""
	assert_true(result.ok, "%s (error: %s)" % [message, result.error])
	return result


# --- ascending ASCII order and insertion-order independence --------------------------------------

func test_compile_domain_assigns_ascending_ascii_order_ids() -> void:
	"""16 species keys compile to 0..15 in ascending ASCII order, not declaration order."""
	var result: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain("SpeciesDefinition", SPECIES_KEYS), "species compile"
	)
	for index: int in SPECIES_SORTED.size():
		assert_equal(result.ids[SPECIES_SORTED[index]], index, "id for %s" % SPECIES_SORTED[index])


func test_compile_domain_is_independent_of_insertion_order() -> void:
	"""The same key set compiles to identical IDs regardless of the order keys were declared in."""
	var shuffled: Array[StringName] = SPECIES_KEYS.duplicate()
	shuffled.reverse()
	var forward: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain("SpeciesDefinition", SPECIES_KEYS), "forward order"
	)
	var reversed_result: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain("SpeciesDefinition", shuffled), "reversed order"
	)
	assert_equal(forward.ids, reversed_result.ids, "insertion order must not change compiled IDs")


func test_compile_domain_sorts_by_ascii_content_not_stringname_identity() -> void:
	"""StringName's own default comparator can order by an internal detail rather than string
	content; the compiler must sort by the actual ASCII text so 'Alpha' precedes 'alpha2'."""
	var keys: Array[StringName] = [&"charlie", &"Alpha", &"bravo", &"alpha2"]
	var result: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain("EventDefinition", keys), "mixed-case compile"
	)
	assert_equal(result.ids[&"Alpha"], 0, "uppercase A sorts before lowercase ascii letters")
	assert_equal(result.ids[&"alpha2"], 1, "alpha2 after Alpha")
	assert_equal(result.ids[&"bravo"], 2, "bravo after alpha2")
	assert_equal(result.ids[&"charlie"], 3, "charlie sorts last")


func test_compile_domain_rejects_duplicate_keys() -> void:
	"""A repeated key would make ID assignment ambiguous; refuse instead of picking one silently."""
	var keys: Array[StringName] = [&"wood", &"stone", &"wood"]
	var result: CatalogScript.DomainResult = CatalogScript.compile_domain("ItemDefinition", keys)
	assert_false(result.ok, "duplicate key must refuse")
	assert_true(result.ids.is_empty(), "a refused compile produces no IDs")


func test_compile_domain_handles_the_empty_key_set() -> void:
	"""An empty domain compiles successfully to an empty ID table."""
	var empty_keys: Array[StringName] = []
	var result: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain("CropDefinition", empty_keys), "empty compile"
	)
	assert_true(result.ids.is_empty(), "no keys means no IDs")


# --- ItemDefinition 256-key ceiling ----------------------------------------------------------------

func _make_unique_keys(count: int) -> Array[StringName]:
	"""Build `count` distinct StringName keys for capacity testing."""
	var keys: Array[StringName] = []
	for index: int in count:
		keys.append(StringName("item_%04d" % index))
	return keys


func test_compile_domain_accepts_exactly_256_item_definition_keys() -> void:
	"""256 keys is the documented ceiling, not the first rejected size."""
	var result: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"ItemDefinition", _make_unique_keys(256)
	)
	assert_true(result.ok, "256 ItemDefinition keys must be accepted")
	assert_equal(result.ids.size(), 256, "all 256 keys receive an id")


func test_compile_domain_rejects_257_item_definition_keys() -> void:
	"""ARCH-STATE-004: an ItemDefinition catalog over 256 keys is refused at compile time."""
	var result: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"ItemDefinition", _make_unique_keys(257)
	)
	assert_false(result.ok, "257 ItemDefinition keys must refuse")
	assert_true(result.ids.is_empty(), "a refused compile produces no IDs")


func test_compile_domain_256_ceiling_is_scoped_to_item_definition() -> void:
	"""The 256 cap is ARCH-STATE-004's ItemDefinition limit, not a blanket rule on every domain."""
	var result: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"RecipeDefinition", _make_unique_keys(257)
	)
	assert_true(result.ok, "257 keys in a non-ItemDefinition domain must not be rejected")


# --- fixed enum preservation -----------------------------------------------------------------------

func test_fixed_speed_enum_matches_gdd_4_3_exactly() -> void:
	"""Speed keeps its non-contiguous 0/1/2/4 values; it is data here, never regenerated."""
	assert_equal(CatalogScript.SPEED, {"PAUSED": 0, "NORMAL": 1, "DOUBLE": 2, "QUADRUPLE": 4}, "Speed enum")
	assert_equal(CatalogScript.fixed_enum("Speed"), CatalogScript.SPEED, "fixed_enum returns Speed")


func test_fixed_job_kind_enum_preserves_the_reserved_gap() -> void:
	"""JobKind.RESERVED_3=3 must stay reserved and unrenumbered alongside its neighbors."""
	var job_kind: Dictionary = CatalogScript.fixed_enum("JobKind")
	assert_equal(job_kind["RESERVED_3"], 3, "RESERVED_3 keeps its reserved slot")
	assert_equal(job_kind["HAUL"], 0, "HAUL=0")
	assert_equal(job_kind["HEAL"], 11, "HEAL=11")
	assert_equal(job_kind.size(), 12, "all 12 JobKind values are present")


func test_fixed_zone_type_enum_preserves_the_reserved_gap() -> void:
	"""ZoneType.RESERVED_1=1 must stay reserved alongside CONSERVATION=8."""
	var zone_type: Dictionary = CatalogScript.fixed_enum("ZoneType")
	assert_equal(zone_type["RESERVED_1"], 1, "RESERVED_1 keeps its reserved slot")
	assert_equal(zone_type["CONSERVATION"], 8, "CONSERVATION=8")
	assert_equal(zone_type.size(), 9, "all 9 ZoneType values are present")


func test_fixed_season_quality_severity_enums_match_gdd_4_3() -> void:
	"""The three small 0-based contiguous enums must still be preserved verbatim, not sorted."""
	assert_equal(CatalogScript.fixed_enum("Season"), {"SPRING": 0, "SUMMER": 1, "AUTUMN": 2, "WINTER": 3}, "Season")
	assert_equal(CatalogScript.fixed_enum("Quality"), {"POOR": 0, "PLAIN": 1, "GOOD": 2, "EXCELLENT": 3}, "Quality")
	assert_equal(CatalogScript.fixed_enum("Severity"), {"INFO": 0, "ADVISORY": 1, "WARNING": 2, "CRITICAL": 3}, "Severity")


func test_fixed_activity_enum_matches_gdd_4_3_exactly() -> void:
	"""Decision 0018: Activity is protected data, numbered by §4.3 and never regenerated."""
	var activity: Dictionary = CatalogScript.fixed_enum("Activity")
	assert_equal(activity, {"SLEEP": 0, "ANYTHING": 1, "WORK": 2, "SOCIAL": 3}, "Activity enum")
	assert_equal(activity.size(), 4, "all 4 Activity values are present")
	assert_equal(CatalogScript.ACTIVITY, activity, "fixed_enum returns the ACTIVITY table itself")


const EXPECTED_JOB_STATE: Dictionary = {
	"QUEUED": 0, "RESERVED": 1, "TRAVEL": 2, "WORK": 3,
	"HAUL_OUTPUT": 4, "COMPLETE": 5, "BLOCKED": 6, "CANCELLED": 7,
}


func test_fixed_job_state_enum_matches_gdd_4_3_exactly() -> void:
	"""Decision 0018: JobState was absent from the codebase entirely; §4.3 numbers all eight.

	The whole-dictionary comparison comes FIRST and is the load-bearing assertion. Indexing a
	Dictionary with a key that a mutation removed aborts the rest of the method at runtime, so a
	suite built only from per-key lookups reports PASS against a table with a missing member --
	which is exactly how a deleted CANCELLED survived the first mutation run of this file."""
	var job_state: Dictionary = CatalogScript.fixed_enum("JobState")
	assert_equal(job_state, EXPECTED_JOB_STATE, "the whole JobState table")
	assert_equal(job_state.size(), 8, "all 8 JobState values are present")
	for key: String in EXPECTED_JOB_STATE:
		assert_true(job_state.has(key), "JobState is missing %s" % key)
		if job_state.has(key):
			assert_equal(job_state[key], EXPECTED_JOB_STATE[key], "JobState.%s" % key)


func test_the_whole_job_kind_and_zone_type_tables_are_unchanged() -> void:
	"""Whole-table equality for the two enums with reserved gaps, so a dropped or renumbered
	member fails an assertion rather than aborting a method mid-way through per-key lookups."""
	assert_equal(CatalogScript.fixed_enum("JobKind"), {
		"HAUL": 0, "BUILD": 1, "FISH": 2, "RESERVED_3": 3, "FORAGE": 4, "FARM": 5,
		"COOK": 6, "PRESERVE": 7, "CRAFT": 8, "TEND": 9, "KEEP": 10, "HEAL": 11,
	}, "the whole JobKind table")
	assert_equal(CatalogScript.fixed_enum("ZoneType"), {
		"FISH": 0, "RESERVED_1": 1, "FORAGE": 2, "FARM": 3, "ORCHARD": 4,
		"FORESTRY": 5, "QUARRY": 6, "STOCKPILE": 7, "CONSERVATION": 8,
	}, "the whole ZoneType table")


func test_job_state_work_is_not_activity_work() -> void:
	"""§4.3 gives WORK=3 in JobState and WORK=2 in Activity. Two enums, two numbers; confusing
	them would silently mislabel a job phase as a schedule activity."""
	assert_equal(CatalogScript.fixed_enum("JobState")["WORK"], 3, "JobState.WORK is 3")
	assert_equal(CatalogScript.fixed_enum("Activity")["WORK"], 2, "Activity.WORK is 2")


func test_activity_and_job_state_refuse_recompilation() -> void:
	"""Decision 0018's whole point: the protected table is the thing that REFUSES a recompile,
	so a sorted-key regeneration of either enum cannot produce IDs."""
	var activity_keys: Array[StringName] = [&"SLEEP", &"ANYTHING", &"WORK", &"SOCIAL"]
	var activity: CatalogScript.DomainResult = CatalogScript.compile_domain("Activity", activity_keys)
	assert_false(activity.ok, "compiling Activity must refuse")
	assert_true(activity.ids.is_empty(), "a refused compile produces no IDs")
	var state_keys: Array[StringName] = [&"QUEUED", &"RESERVED", &"TRAVEL"]
	var job_state: CatalogScript.DomainResult = CatalogScript.compile_domain("JobState", state_keys)
	assert_false(job_state.ok, "compiling JobState must refuse")
	assert_true(job_state.ids.is_empty(), "a refused compile produces no IDs")


func test_every_protected_domain_has_a_fixed_enum_table() -> void:
	"""A name in PROTECTED_ENUM_DOMAINS with no fixed_enum entry would refuse compilation while
	publishing nothing, leaving that enum with no numbers at all.

	The count rose from eight to eleven when Soil, CropState and OrderMode joined the table,
	and from eleven to thirteen when RoomType and BuildingState did (decision 0018: every enum
	§4.3 numbers explicitly belongs here). The number is asserted so a domain added without a
	fixed_enum table, or a table added without its domain name, fails."""
	assert_equal(CatalogScript.PROTECTED_ENUM_DOMAINS.size(), 13, "thirteen protected enum domains")
	for domain_name: String in CatalogScript.PROTECTED_ENUM_DOMAINS:
		assert_false(CatalogScript.fixed_enum(domain_name).is_empty(),
			"protected domain %s must publish a fixed enum table" % domain_name)
		var refused: CatalogScript.DomainResult = CatalogScript.compile_domain(
			domain_name, [&"A", &"B"] as Array[StringName]
		)
		assert_false(refused.ok, "protected domain %s must refuse recompilation" % domain_name)


func test_fixed_enum_returns_empty_for_an_unknown_domain() -> void:
	"""A domain name that is not one of the eight protected enums yields no fixed data."""
	assert_true(CatalogScript.fixed_enum("ItemDefinition").is_empty(), "not a fixed enum domain")


func test_compile_domain_refuses_to_recompile_a_protected_enum() -> void:
	"""Explicit enums are never regenerated, even if someone tries to compile them like a catalog."""
	var keys: Array[StringName] = [&"PAUSED", &"NORMAL"]
	var result: CatalogScript.DomainResult = CatalogScript.compile_domain("Speed", keys)
	assert_false(result.ok, "compiling a protected enum domain must refuse")


# --- compile_catalog batch: all-or-nothing ----------------------------------------------------------

func test_compile_catalog_returns_every_domains_ids_when_all_succeed() -> void:
	"""A batch of independently valid domains compiles to one report with all of their IDs."""
	var domains: Dictionary = {
		"SpeciesDefinition": SPECIES_KEYS,
		"CropDefinition": [&"grain", &"beans", &"cabbage"] as Array[StringName],
	}
	var report: CatalogScript.CompileReport = CatalogScript.compile_catalog(domains)
	assert_true(report.ok, "a fully valid batch succeeds")
	assert_equal(report.domains["SpeciesDefinition"][&"badger"], 0, "species ids are present")
	assert_equal(report.domains["CropDefinition"][&"beans"], 0, "crop ids are present")


func test_compile_catalog_aborts_before_producing_any_domain_on_failure() -> void:
	"""GDD §4.2: a validation failure aborts before mutating anything, not just the bad domain."""
	var domains: Dictionary = {
		"SpeciesDefinition": SPECIES_KEYS,
		"ItemDefinition": _make_unique_keys(257),
	}
	var report: CatalogScript.CompileReport = CatalogScript.compile_catalog(domains)
	assert_false(report.ok, "one invalid domain fails the whole batch")
	assert_true(report.domains.is_empty(), "no domain's IDs are produced, including the valid one")


func test_compile_catalog_accepts_a_plain_untyped_array_of_string_keys() -> void:
	"""H3: a data-driven loader (e.g. one reading ids out of JSON) hands compile_catalog a plain
	untyped Array of Strings, not an Array[StringName] literal cast at the call site. That is the
	realistic caller and must compile cleanly rather than throwing a SCRIPT ERROR and returning null."""
	var raw_keys: Array = []
	raw_keys.append("grain")
	raw_keys.append("beans")
	raw_keys.append("cabbage")
	var domains: Dictionary = {"CropDefinition": raw_keys}
	var report: CatalogScript.CompileReport = CatalogScript.compile_catalog(domains)
	assert_not_null(report, "compile_catalog must never return null")
	assert_true(report.ok, "a plain untyped Array of String keys must compile cleanly (error: %s)" % report.error)
	assert_equal(report.domains["CropDefinition"][&"beans"], 0, "beans sorts first among the crop keys")


func test_compile_catalog_refuses_an_untyped_array_with_a_non_string_element() -> void:
	"""An element that is neither String nor StringName must produce a clean refusal object,
	never a crash and never null."""
	var raw_keys: Array = ["grain", 42, "cabbage"]
	var domains: Dictionary = {"CropDefinition": raw_keys}
	var report: CatalogScript.CompileReport = CatalogScript.compile_catalog(domains)
	assert_not_null(report, "compile_catalog must never return null")
	assert_false(report.ok, "a non-string, non-StringName key must refuse the batch")
	assert_true(report.domains.is_empty(), "no domain's IDs are produced on refusal")


const EXPECTED_SOIL: Dictionary = {"LOAM": 0, "CLAY": 1, "SAND": 2}
const EXPECTED_CROP_STATE: Dictionary = {
	"EMPTY": 0, "SOWN": 1, "GROWING": 2, "RIPE": 3, "WITHERED": 4,
}
const EXPECTED_ORDER_MODE: Dictionary = {"ONCE": 0, "REPEAT": 1, "MAINTAIN_STOCK": 2}


func test_fixed_soil_enum_matches_gdd_4_3_exactly() -> void:
	"""§4.3: "Soil | LOAM=0, CLAY=1, SAND=2". BAL-CROP-001 derives every crop's `allowed_soils`
	mask as `1<<Soil`, so a renumbering here repoints grain's mask 3 at a different pair of soils.

	The whole-dictionary comparison comes FIRST and is the load-bearing assertion: indexing a
	Dictionary with a key a mutation removed aborts the rest of the method at runtime, which is
	how a deleted member survived this file's first mutation run."""
	var soil: Dictionary = CatalogScript.fixed_enum("Soil")
	assert_equal(soil, EXPECTED_SOIL, "the whole Soil table")
	assert_equal(soil.size(), 3, "all 3 Soil values are present")
	assert_equal(CatalogScript.SOIL, soil, "fixed_enum returns the SOIL table itself")
	for key: String in EXPECTED_SOIL:
		assert_true(soil.has(key), "Soil is missing %s" % key)
		if soil.has(key):
			assert_equal(soil[key], EXPECTED_SOIL[key], "Soil.%s" % key)


func test_fixed_crop_state_enum_matches_gdd_4_3_exactly() -> void:
	"""§4.3: "CropState | EMPTY=0, SOWN=1, GROWING=2, RIPE=3, WITHERED=4". `FarmPlot.state` is
	persisted, so any renumbering here silently rewrites every saved plot's state."""
	var crop_state: Dictionary = CatalogScript.fixed_enum("CropState")
	assert_equal(crop_state, EXPECTED_CROP_STATE, "the whole CropState table")
	assert_equal(crop_state.size(), 5, "all 5 CropState values are present")
	assert_equal(CatalogScript.CROP_STATE, crop_state, "fixed_enum returns the CROP_STATE table")
	for key: String in EXPECTED_CROP_STATE:
		assert_true(crop_state.has(key), "CropState is missing %s" % key)
		if crop_state.has(key):
			assert_equal(crop_state[key], EXPECTED_CROP_STATE[key], "CropState.%s" % key)


func test_fixed_order_mode_enum_matches_gdd_4_3_exactly() -> void:
	"""§4.3: "OrderMode | ONCE=0, REPEAT=1, MAINTAIN_STOCK=2", the type of `ProductionOrder.mode`."""
	var order_mode: Dictionary = CatalogScript.fixed_enum("OrderMode")
	assert_equal(order_mode, EXPECTED_ORDER_MODE, "the whole OrderMode table")
	assert_equal(order_mode.size(), 3, "all 3 OrderMode values are present")
	assert_equal(CatalogScript.ORDER_MODE, order_mode, "fixed_enum returns the ORDER_MODE table")
	for key: String in EXPECTED_ORDER_MODE:
		assert_true(order_mode.has(key), "OrderMode is missing %s" % key)
		if order_mode.has(key):
			assert_equal(order_mode[key], EXPECTED_ORDER_MODE[key], "OrderMode.%s" % key)


func test_soil_crop_state_and_order_mode_refuse_recompilation() -> void:
	"""Decision 0018's whole point: the protected table is the thing that REFUSES a recompile.

	Sorted-key regeneration would number Soil CLAY=0, LOAM=1, SAND=2 and CropState EMPTY=0,
	GROWING=1, RIPE=2, SOWN=3, WITHERED=4 -- neither of which is what §4.3 states."""
	var soil_keys: Array[StringName] = [&"LOAM", &"CLAY", &"SAND"]
	var soil: CatalogScript.DomainResult = CatalogScript.compile_domain("Soil", soil_keys)
	assert_false(soil.ok, "compiling Soil must refuse")
	assert_true(soil.ids.is_empty(), "a refused compile produces no IDs")
	var state_keys: Array[StringName] = [&"EMPTY", &"SOWN", &"GROWING", &"RIPE", &"WITHERED"]
	var crop_state: CatalogScript.DomainResult = CatalogScript.compile_domain("CropState", state_keys)
	assert_false(crop_state.ok, "compiling CropState must refuse")
	assert_true(crop_state.ids.is_empty(), "a refused compile produces no IDs")
	var mode_keys: Array[StringName] = [&"ONCE", &"REPEAT", &"MAINTAIN_STOCK"]
	var order_mode: CatalogScript.DomainResult = CatalogScript.compile_domain("OrderMode", mode_keys)
	assert_false(order_mode.ok, "compiling OrderMode must refuse")
	assert_true(order_mode.ids.is_empty(), "a refused compile produces no IDs")


func test_the_three_new_protected_enums_are_named_in_the_protected_table() -> void:
	"""A fixed_enum table whose domain name is absent from PROTECTED_ENUM_DOMAINS would still be
	recompilable, which is the exact drift decision 0018 exists to prevent."""
	for domain_name: String in ["Soil", "CropState", "OrderMode"]:
		assert_true(CatalogScript.PROTECTED_ENUM_DOMAINS.has(domain_name),
			"%s must be a protected domain" % domain_name)


# --- compiled enum domains (GDD §4.2's closing paragraph, BAL-CAT-001/002) --------------------------

## The three domains §4.2's closing paragraph numbers from their own ascending ASCII keys.
## Transcribed from the contract, never read back out of the module under test.
const EXPECTED_CROP_FAMILY: Dictionary = {
	"CEREAL": 0, "FIBER": 1, "LEAF": 2, "LEGUME": 3, "ROOT": 4,
}
const EXPECTED_EVENT_DEFINITION: Dictionary = {
	"blight": 0, "calm_days": 1, "drought": 2, "early_frost": 3,
	"hard_freeze": 4, "heavy_rain": 5, "ideal_spell": 6,
}
const EXPECTED_HABITAT_TYPE: Dictionary = {"COAST": 0, "LAKE": 1, "RIVER": 2}


func test_the_compiled_enum_tables_are_the_generated_ascii_order() -> void:
	"""Whole-table equality first, so a dropped key fails an assertion instead of aborting."""
	assert_equal(CatalogScript.CROP_FAMILY, EXPECTED_CROP_FAMILY, "the whole CropFamily table")
	assert_equal(CatalogScript.EVENT_DEFINITION, EXPECTED_EVENT_DEFINITION,
		"the whole EventDefinition table")
	assert_equal(CatalogScript.HABITAT_TYPE, EXPECTED_HABITAT_TYPE, "the whole HabitatType table")
	assert_equal(CatalogScript.compiled_enum("CropFamily"), EXPECTED_CROP_FAMILY,
		"compiled_enum returns the CropFamily table")
	assert_equal(CatalogScript.compiled_enum("EventDefinition"), EXPECTED_EVENT_DEFINITION,
		"compiled_enum returns the EventDefinition table")
	assert_equal(CatalogScript.compiled_enum("HabitatType"), EXPECTED_HABITAT_TYPE,
		"compiled_enum returns the HabitatType table")
	assert_true(CatalogScript.compiled_enum("Nonesuch").is_empty(),
		"an unknown domain name owns no compiled table")


func _assert_compiles_to(domain_name: String, expected: Dictionary) -> void:
	"""Compile one domain's keys in both directions and assert both give `expected`."""
	var keys: Array[StringName] = CatalogScript.compiled_enum_keys(domain_name)
	assert_equal(keys.size(), expected.size(), "%s key count" % domain_name)
	var forward: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain(domain_name, keys), "%s forward" % domain_name)
	var shuffled: Array[StringName] = keys.duplicate()
	shuffled.reverse()
	var backward: CatalogScript.DomainResult = _assert_domain_ok(
		CatalogScript.compile_domain(domain_name, shuffled), "%s reversed" % domain_name)
	assert_equal(forward.ids, backward.ids, "%s: input order must not change ids" % domain_name)
	for key: String in expected:
		assert_true(forward.ids.has(StringName(key)), "%s compiled %s" % [domain_name, key])
		if forward.ids.has(StringName(key)):
			assert_equal(forward.ids[StringName(key)], expected[key],
				"%s.%s is the generated id" % [domain_name, key])


func test_every_compiled_domain_regenerates_its_own_table_from_its_keys() -> void:
	"""The acceptance test: shuffled input order produces identical mappings, table for table."""
	_assert_compiles_to("CropFamily", EXPECTED_CROP_FAMILY)
	_assert_compiles_to("EventDefinition", EXPECTED_EVENT_DEFINITION)
	_assert_compiles_to("HabitatType", EXPECTED_HABITAT_TYPE)


func test_verify_compiled_enum_accepts_the_compiled_domains_and_refuses_others() -> void:
	"""verify_compiled_enum() is what every owning module's `_init()` calls; it must pass here."""
	for domain_name: String in ["BuildingDefinition", "CommandKind", "CropFamily",
			"EventDefinition", "FurnitureDefinition", "HabitatType"]:
		var result: CatalogScript.DomainResult = CatalogScript.verify_compiled_enum(domain_name)
		assert_true(result.ok, "%s must verify (error: %s)" % [domain_name, result.error])
		assert_equal(result.ids.size(), CatalogScript.compiled_enum(domain_name).size(),
			"%s verifies its whole table" % domain_name)
	var unknown: CatalogScript.DomainResult = CatalogScript.verify_compiled_enum("Nonesuch")
	assert_false(unknown.ok, "an unknown domain cannot be verified")
	assert_true(unknown.ids.is_empty(), "a refusal carries no ids")
	var protected: CatalogScript.DomainResult = CatalogScript.verify_compiled_enum("Season")
	assert_false(protected.ok, "a protected §4.3 enum is not a compiled domain")


func test_the_compiled_domains_are_registered_and_never_protected() -> void:
	"""Decision 0018 protects what §4.3 NUMBERS; these six it does not number, so they compile."""
	for domain_name: String in ["BuildingDefinition", "CommandKind", "CropFamily",
			"EventDefinition", "FurnitureDefinition", "HabitatType"]:
		assert_true(CatalogScript.COMPILED_ENUM_DOMAINS.has(domain_name),
			"%s must be a registered compiled domain" % domain_name)
		assert_false(CatalogScript.PROTECTED_ENUM_DOMAINS.has(domain_name),
			"%s must NOT be protected: §4.3 states none of its numbers" % domain_name)
		assert_true(CatalogScript.fixed_enum(domain_name).is_empty(),
			"%s owns no fixed §4.3 table" % domain_name)
	assert_equal(CatalogScript.COMPILED_ENUM_DOMAINS.size(), 6,
		"six compiled domains today: BuildingDefinition and FurnitureDefinition joined them "
		+ "under decision 0056, after CommandKind under decision 0042")


func test_compiled_id_of_resolves_every_key_and_refuses_the_unknown() -> void:
	"""Key lookups answer with an id or refuse; there is no sentinel to mistake for an answer."""
	var river: CatalogScript.EnumLookup = CatalogScript.compiled_id_of("HabitatType", &"RIVER")
	assert_true(river.ok, "RIVER is a HabitatType key")
	assert_equal(river.id, 2, "RIVER sorts third of COAST, LAKE, RIVER")
	assert_equal(river.key, &"RIVER", "the lookup echoes the key it resolved")
	var legume: CatalogScript.EnumLookup = CatalogScript.compiled_id_of("CropFamily", &"LEGUME")
	assert_true(legume.ok, "LEGUME is a CropFamily key")
	assert_equal(legume.id, 3, "LEGUME sorts fourth")
	var unknown_key: CatalogScript.EnumLookup = CatalogScript.compiled_id_of("HabitatType",
		&"river")
	assert_false(unknown_key.ok, "keys are case-sensitive ASCII (BAL-CAT-001)")
	assert_false(unknown_key.error.is_empty(), "a refusal names what it rejected")
	var unknown_domain: CatalogScript.EnumLookup = CatalogScript.compiled_id_of("Nonesuch",
		&"RIVER")
	assert_false(unknown_domain.ok, "an unknown domain is refused, not searched")


func test_compiled_key_of_resolves_every_id_and_refuses_the_unknown() -> void:
	"""Id lookups answer with a key or refuse, including for §4.2's empty catalog id -1."""
	assert_equal(CatalogScript.compiled_key_of("EventDefinition", 0).key, &"blight",
		"EventDefinition 0 is blight")
	assert_equal(CatalogScript.compiled_key_of("EventDefinition", 6).key, &"ideal_spell",
		"EventDefinition 6 is ideal_spell")
	assert_equal(CatalogScript.compiled_key_of("HabitatType", 0).key, &"COAST",
		"HabitatType 0 is COAST")
	assert_false(CatalogScript.compiled_key_of("EventDefinition", 7).ok, "there is no eighth id")
	assert_false(CatalogScript.compiled_key_of("HabitatType", 3).ok, "there is no fourth habitat")
	assert_false(CatalogScript.compiled_key_of("CropFamily", -1).ok,
		"-1 is absence, and absence names no key")
	assert_false(CatalogScript.compiled_key_of("Nonesuch", 0).ok, "an unknown domain is refused")


func test_the_legacy_conversion_maps_translate_every_old_ordinal() -> void:
	"""The old provisional ordinals are translated key by key, never reinterpreted as new ones."""
	_assert_legacy("HabitatType", [&"RIVER", &"LAKE", &"COAST"])
	_assert_legacy("EventDefinition", [&"ideal_spell", &"heavy_rain", &"drought", &"blight",
		&"early_frost", &"hard_freeze", &"calm_days"])
	_assert_legacy("CropFamily", [&"CEREAL", &"ROOT", &"LEGUME", &"LEAF", &"FIBER"])


func _assert_legacy(domain_name: String, old_order: Array[StringName]) -> void:
	"""Assert each old ordinal converts to the compiled id of the key it used to name."""
	assert_equal(CatalogScript.legacy_ids_of(domain_name).size(), old_order.size(),
		"%s has one legacy entry per old ordinal" % domain_name)
	for legacy_id: int in old_order.size():
		var got: CatalogScript.EnumLookup = CatalogScript.convert_legacy_id(domain_name, legacy_id)
		assert_true(got.ok, "%s legacy %d converts" % [domain_name, legacy_id])
		assert_equal(got.key, old_order[legacy_id],
			"%s legacy %d named %s" % [domain_name, legacy_id, old_order[legacy_id]])
		var expected: CatalogScript.EnumLookup = CatalogScript.compiled_id_of(domain_name,
			old_order[legacy_id])
		assert_equal(got.id, expected.id,
			"%s legacy %d becomes the compiled id of %s" % [domain_name, legacy_id,
			old_order[legacy_id]])


func test_the_legacy_maps_are_the_ruled_permutations() -> void:
	"""READY_06 §2's own numbers: Habitat [2,1,0], Weather [6,5,2,0,3,4,1], Family [0,4,3,2,1]."""
	assert_equal(CatalogScript.legacy_ids_of("HabitatType"), [2, 1, 0] as Array[int],
		"the HabitatType conversion map")
	assert_equal(CatalogScript.legacy_ids_of("EventDefinition"),
		[6, 5, 2, 0, 3, 4, 1] as Array[int], "the EventDefinition conversion map")
	assert_equal(CatalogScript.legacy_ids_of("CropFamily"), [0, 4, 3, 2, 1] as Array[int],
		"the CropFamily conversion map")
	assert_true(CatalogScript.legacy_ids_of("Nonesuch").is_empty(), "an unknown domain has none")


func test_an_untranslatable_ordinal_is_refused_rather_than_reinterpreted() -> void:
	"""A snapshot carrying an ordinal no old schema had is rejected with an unsupported message."""
	var too_high: CatalogScript.EnumLookup = CatalogScript.convert_legacy_id("HabitatType", 3)
	assert_false(too_high.ok, "the old HabitatType had three ordinals, not four")
	assert_true(too_high.error.contains("unsupported schema"),
		"and says so as an unsupported schema/catalog, not as a missing key")
	assert_false(CatalogScript.convert_legacy_id("EventDefinition", 7).ok, "no eighth old event")
	assert_false(CatalogScript.convert_legacy_id("CropFamily", 5).ok, "no sixth old family")
	assert_false(CatalogScript.convert_legacy_id("CropFamily", -2).ok, "-2 names nothing at all")
	assert_false(CatalogScript.convert_legacy_id("Nonesuch", 0).ok, "an unknown domain refuses")


func test_absence_converts_to_absence_in_every_compiled_domain() -> void:
	"""§4.2: "empty catalog IDs are -1". Absence means the same in both schemas."""
	for domain_name: String in ["CropFamily", "EventDefinition", "HabitatType"]:
		var empty: CatalogScript.EnumLookup = CatalogScript.convert_legacy_id(domain_name, -1)
		assert_true(empty.ok, "%s: -1 is absence, not a corrupt ordinal" % domain_name)
		assert_equal(empty.id, CatalogScript.EMPTY_CATALOG_ID,
			"%s: absence converts to absence" % domain_name)
		assert_equal(empty.key, &"", "%s: absence names no key" % domain_name)
	assert_equal(CatalogScript.EMPTY_CATALOG_ID, -1, "§4.2's empty catalog id is -1")


# --- the starter-colony domains (decision 0056, READY_07 §7.2 step 1) -----------------------------

## Transcribed from the OWNING FULL CATALOG -- gameplay_balance.md §4.1's thirty BuildingDefinition
## rows -- and sorted here by hand into ascending ASCII order, never read back out of the module
## under test. §5.9 prints thirty building rows and BAL §2 states "30 buildings" outright, so a
## table of any other size is not that catalog.
const EXPECTED_BUILDING_DEFINITION: Dictionary = {
	"apiary": 0, "boathouse": 1, "brewery": 2, "cellar": 3, "composter": 4,
	"covered_store": 5, "dirt_path": 6, "dryer": 7, "fence": 8, "fisher_shelter": 9,
	"forester_lodge": 10, "gate": 11, "hall": 12, "infirmary": 13, "kitchen": 14,
	"lookout": 15, "memorial_garden": 16, "mill": 17, "nursery": 18, "open_stockpile": 19,
	"paved_path": 20, "preserver": 21, "quarry_shed": 22, "residence": 23, "saltpan": 24,
	"stone_wall": 25, "weir": 26, "well": 27, "workbench": 28, "workshop": 29,
}
## gameplay_balance.md §4.3's nine FurnitureDefinition rows, same treatment.
const EXPECTED_FURNITURE_DEFINITION: Dictionary = {
	"bed": 0, "decoration": 1, "hearth": 2, "interior_door": 3, "interior_partition": 4,
	"kitchen_bench": 5, "patient_bed": 6, "seat": 7, "shelf": 8,
}
## GDD §4.3's own two tables, character for character.
const EXPECTED_ROOM_TYPE: Dictionary = {
	"DORMITORY": 0, "PRIVATE_ROOM": 1, "KITCHEN": 2, "DINING": 3,
	"COMMON": 4, "INFIRMARY": 5, "PANTRY": 6, "CORRIDOR": 7,
}
const EXPECTED_BUILDING_STATE: Dictionary = {
	"BLUEPRINT": 0, "BUILDING": 1, "ACTIVE": 2, "PAUSED": 3, "DAMAGED": 4, "DEMOLISHING": 5,
}
## READY_07 §7.1's starter table, by the key each of its display names belongs to.
const STARTER_BUILDING_KEYS: Array[String] = ["hall", "open_stockpile", "well", "workbench"]


func test_building_definition_is_the_complete_thirty_row_catalog() -> void:
	"""The whole published table, against the owning catalog's thirty rows.

	READY_07 §7.2 step 1 names the failure outright: publishing the starter colony's handful of
	ordinals "later renumber[s] all buildings". Thirty is therefore the assertion, not four."""
	assert_equal(CatalogScript.BUILDING_DEFINITION, EXPECTED_BUILDING_DEFINITION,
		"the whole BuildingDefinition table")
	assert_equal(CatalogScript.BUILDING_DEFINITION.size(), 30, "thirty building rows")
	assert_equal(CatalogScript.compiled_enum("BuildingDefinition"), EXPECTED_BUILDING_DEFINITION,
		"compiled_enum returns the BuildingDefinition table")


func test_furniture_definition_is_the_complete_nine_row_catalog() -> void:
	"""All nine furniture rows, likewise complete rather than the starter subset."""
	assert_equal(CatalogScript.FURNITURE_DEFINITION, EXPECTED_FURNITURE_DEFINITION,
		"the whole FurnitureDefinition table")
	assert_equal(CatalogScript.FURNITURE_DEFINITION.size(), 9, "nine furniture rows")
	assert_equal(CatalogScript.compiled_enum("FurnitureDefinition"), EXPECTED_FURNITURE_DEFINITION,
		"compiled_enum returns the FurnitureDefinition table")


func test_the_starter_buildings_and_furniture_are_inside_the_complete_domains() -> void:
	"""§7.1's four starter structures and the starter interior's five furniture kinds resolve.

	They are ordinary members of the full domain: `hall` is 12 of 30 because twelve keys sort
	before it, not because it is the first thing the colony places."""
	for key: String in STARTER_BUILDING_KEYS:
		var found: CatalogScript.EnumLookup = CatalogScript.compiled_id_of(
			"BuildingDefinition", StringName(key))
		assert_true(found.ok, "starter building '%s' must be a BuildingDefinition key" % key)
		assert_equal(found.id, EXPECTED_BUILDING_DEFINITION[key], "starter building '%s' id" % key)
	for furniture_key: String in ["bed", "kitchen_bench", "hearth", "shelf", "seat"]:
		var furniture: CatalogScript.EnumLookup = CatalogScript.compiled_id_of(
			"FurnitureDefinition", StringName(furniture_key))
		assert_true(furniture.ok, "starter furniture '%s' must be a key" % furniture_key)
		assert_equal(furniture.id, EXPECTED_FURNITURE_DEFINITION[furniture_key],
			"furniture '%s' id" % furniture_key)


func test_display_names_are_not_keys_in_either_new_domain() -> void:
	"""READY_07 §7.2: "display names are not ordering keys".

	§5.9 prints "Refuge/community hall", "Workbench shelter", "Open stockpile",
	"Preserver/smokehouse", "Seat/table place" and "Fence segment"; the owning §4.1/§4.3 rows key
	them hall, workbench, open_stockpile, preserver, seat and fence. Keying on the printed name
	would put `refuge_hall` between `quarry_shed` and `residence` and renumber six buildings."""
	for absent: String in ["refuge_hall", "community_hall", "workbench_shelter", "Refuge hall",
			"open stockpile", "smokehouse", "fence_segment", "stone_wall_segment"]:
		assert_false(CatalogScript.BUILDING_DEFINITION.has(absent),
			"'%s' is a display name, not a BuildingDefinition key" % absent)
		assert_false(CatalogScript.compiled_id_of("BuildingDefinition", StringName(absent)).ok,
			"'%s' must be refused, not resolved" % absent)
	for missing: String in ["seat_table_place", "table", "partition", "door", "Bed"]:
		assert_false(CatalogScript.FURNITURE_DEFINITION.has(missing),
			"'%s' is not a FurnitureDefinition key" % missing)


func test_building_and_furniture_are_two_domains_that_never_share_an_id() -> void:
	"""BAL-CAT-007: "furniture definitions occupy a separate domain".

	`kitchen` is building 14 and `kitchen_bench` is furniture 5; neither key resolves in the
	other's domain, so a furniture id can never be read as a building id by accident."""
	assert_equal(CatalogScript.compiled_id_of("BuildingDefinition", &"kitchen").id, 14,
		"the exterior kitchen building")
	assert_equal(CatalogScript.compiled_id_of("FurnitureDefinition", &"kitchen_bench").id, 5,
		"the interior kitchen bench")
	assert_false(CatalogScript.compiled_id_of("BuildingDefinition", &"kitchen_bench").ok,
		"a furniture key is not a building key")
	assert_false(CatalogScript.compiled_id_of("FurnitureDefinition", &"kitchen").ok,
		"a building key is not a furniture key")
	assert_false(CatalogScript.compiled_id_of("FurnitureDefinition", &"well").ok,
		"nor is the well, which §5.9 lists as a building")


func test_unknown_keys_and_ids_in_the_new_domains_are_refused_without_a_sentinel() -> void:
	"""A refusal carries no usable key or id: there is nothing to mistake for an answer."""
	var unknown: CatalogScript.EnumLookup = CatalogScript.compiled_id_of(
		"BuildingDefinition", &"tavern")
	assert_false(unknown.ok, "there is no tavern in the catalog")
	assert_equal(unknown.id, 0, "a refusal publishes no id")
	assert_equal(unknown.key, &"", "a refusal publishes no key")
	assert_true(unknown.error.contains("tavern"), "and names what was rejected")
	assert_false(CatalogScript.compiled_key_of("BuildingDefinition", 30).ok,
		"thirty keys occupy 0..29; there is no id 30")
	assert_false(CatalogScript.compiled_key_of("BuildingDefinition", -1).ok,
		"-1 is absence, and absence names no building")
	assert_false(CatalogScript.compiled_key_of("FurnitureDefinition", 9).ok, "no ninth id")
	assert_equal(CatalogScript.compiled_key_of("FurnitureDefinition", 8).key, &"shelf",
		"furniture 8 is the shelf")


func test_the_new_compiled_domains_regenerate_from_shuffled_keys() -> void:
	"""The acceptance property: input order cannot reach an id. Reversed, and rotated four ways."""
	_assert_compiles_to("BuildingDefinition", EXPECTED_BUILDING_DEFINITION)
	_assert_compiles_to("FurnitureDefinition", EXPECTED_FURNITURE_DEFINITION)
	for domain_name: String in ["BuildingDefinition", "FurnitureDefinition"]:
		_assert_rotations_agree(domain_name)


func _assert_rotations_agree(domain_name: String) -> void:
	"""Compile one domain's keys from four rotated starting points and assert one mapping."""
	var keys: Array[StringName] = CatalogScript.compiled_enum_keys(domain_name)
	var expected: CatalogScript.DomainResult = CatalogScript.compile_domain(domain_name, keys)
	for rotation: int in [1, 7, 13, 29]:
		var shift: int = rotation % maxi(1, keys.size())
		var rotated: Array[StringName] = []
		rotated.append_array(keys.slice(shift))
		rotated.append_array(keys.slice(0, shift))
		assert_equal(rotated.size(), keys.size(), "%s rotation keeps every key" % domain_name)
		var built: CatalogScript.DomainResult = CatalogScript.compile_domain(domain_name, rotated)
		assert_true(built.ok, "%s rotation %d compiles" % [domain_name, rotation])
		assert_equal(built.ids, expected.ids,
			"%s rotation %d gives identical ids" % [domain_name, rotation])


func test_room_type_and_building_state_match_gdd_4_3_exactly() -> void:
	"""§4.3 numbers both tables individually, so they are fixed data and never regenerated."""
	assert_equal(CatalogScript.ROOM_TYPE, EXPECTED_ROOM_TYPE, "the whole RoomType table")
	assert_equal(CatalogScript.BUILDING_STATE, EXPECTED_BUILDING_STATE,
		"the whole BuildingState table")
	assert_equal(CatalogScript.fixed_enum("RoomType"), EXPECTED_ROOM_TYPE,
		"fixed_enum returns the RoomType table")
	assert_equal(CatalogScript.fixed_enum("BuildingState"), EXPECTED_BUILDING_STATE,
		"fixed_enum returns the BuildingState table")
	assert_true(CatalogScript.PROTECTED_ENUM_DOMAINS.has("RoomType"), "RoomType is protected")
	assert_true(CatalogScript.PROTECTED_ENUM_DOMAINS.has("BuildingState"),
		"BuildingState is protected")


func test_room_type_and_building_state_are_not_their_own_ascii_order() -> void:
	"""Exactly why they must be protected rather than compiled.

	Sorted-key regeneration would number RoomType COMMON=0, CORRIDOR=1, DINING=2, DORMITORY=3,
	INFIRMARY=4, KITCHEN=5, PANTRY=6, PRIVATE_ROOM=7 and BuildingState ACTIVE=0, BLUEPRINT=1,
	BUILDING=2, DAMAGED=3, DEMOLISHING=4, PAUSED=5 -- neither of which is what §4.3 states, and
	both of which would silently repoint every persisted Room.type and Building.state."""
	var room_keys: Array[StringName] = [&"DORMITORY", &"PRIVATE_ROOM", &"KITCHEN", &"DINING",
		&"COMMON", &"INFIRMARY", &"PANTRY", &"CORRIDOR"]
	var ascii_room: Dictionary = CatalogScript.compile_domain("Nonesuch", room_keys).ids
	assert_equal(ascii_room[&"COMMON"], 0, "ASCII order would start RoomType at COMMON")
	assert_false(ascii_room[&"DORMITORY"] == int(CatalogScript.ROOM_TYPE["DORMITORY"]),
		"so the two orders genuinely disagree")
	var refused_room: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"RoomType", room_keys)
	assert_false(refused_room.ok, "compiling RoomType must refuse")
	assert_true(refused_room.ids.is_empty(), "a refused compile produces no IDs")
	var state_keys: Array[StringName] = [&"BLUEPRINT", &"BUILDING", &"ACTIVE", &"PAUSED",
		&"DAMAGED", &"DEMOLISHING"]
	var refused_state: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"BuildingState", state_keys)
	assert_false(refused_state.ok, "compiling BuildingState must refuse")
	assert_true(refused_state.ids.is_empty(), "a refused compile produces no IDs")


func test_the_fixed_enum_table_index_and_the_protected_list_name_the_same_domains() -> void:
	"""A table with no protected name is recompilable; a protected name with no table publishes
	no numbers at all. Both halves are asserted, in both directions."""
	assert_equal(CatalogScript.FIXED_ENUM_TABLES.size(),
		CatalogScript.PROTECTED_ENUM_DOMAINS.size(), "one fixed table per protected domain")
	for table_name: Variant in CatalogScript.FIXED_ENUM_TABLES.keys():
		assert_true(CatalogScript.PROTECTED_ENUM_DOMAINS.has(String(table_name)),
			"'%s' has a fixed table and must be protected" % table_name)
	for domain_name: String in CatalogScript.PROTECTED_ENUM_DOMAINS:
		assert_true(CatalogScript.FIXED_ENUM_TABLES.has(domain_name),
			"protected '%s' must have a fixed table" % domain_name)
		assert_equal(CatalogScript.fixed_enum(domain_name),
			CatalogScript.FIXED_ENUM_TABLES[domain_name],
			"fixed_enum('%s') returns that table" % domain_name)


func test_the_new_domains_were_never_numbered_any_other_way() -> void:
	"""No pre-decision-0056 ordinals exist for these, so a legacy ordinal is refused by name
	rather than silently reinterpreted as an id in the new numbering."""
	for domain_name: String in ["BuildingDefinition", "FurnitureDefinition"]:
		assert_true(CatalogScript.legacy_ids_of(domain_name).is_empty(),
			"%s has no legacy conversion map" % domain_name)
		var converted: CatalogScript.EnumLookup = CatalogScript.convert_legacy_id(domain_name, 0)
		assert_false(converted.ok, "%s legacy ordinal 0 must refuse" % domain_name)
		assert_true(converted.error.contains("never numbered any other way"),
			"%s says why, rather than reporting an unknown domain" % domain_name)
	assert_false(CatalogScript.convert_legacy_id("RoomType", 0).ok,
		"RoomType is protected, not a compiled domain at all")
