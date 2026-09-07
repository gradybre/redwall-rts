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


func test_fixed_enum_returns_empty_for_an_unknown_domain() -> void:
	"""A domain name that is not one of the six protected enums yields no fixed data."""
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
