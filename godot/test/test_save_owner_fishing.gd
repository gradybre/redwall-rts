extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/fishing.gd")
const Bridge := preload("res://scripts/core/save_owner_fishing.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[String] = ["habitat_present", "stock_present", "habitat_type", "habitat_zone_slot", "habitat_zone_generation", "habitat_effort_slots", "habitat_pollution", "habitat_danger", "habitat_protected_fraction", "habitat_capacity_milli", "habitat_ref_slot", "habitat_ref_generation", "habitat_effort_used", "habitat_intensive", "stock_habitat_slot", "stock_habitat_generation", "stock_species_id", "stock_population_milli", "stock_capacity_milli", "stock_harvested_today_milli", "stock_closed", "stock_restocking"]
const TYPES: Array[int] = [0, 0, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 0, 2, 2, 2, 4, 4, 4, 0, 0]
const COUNTS: Array[int] = [32, 96, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 96, 96, 96, 96, 96, 96, 96, 96]
const CASES: Array = [
	["accept-clear", "clear", [], ""],
	["accept-coast", "coast", [], ""],
	["accept-lake", "lake", [], ""],
	["accept-river", "river", [], ""],
	["accept-inactive-coast", "inactive-coast", [], ""],
	["accept-inactive-lake", "inactive-lake", [], ""],
	["accept-inactive-river", "inactive-river", [], ""],
	["flag-habitat_present", "coast", [["habitat_present", 31, 2]], "COLUMN_FLAG"],
	["flag-stock_present", "coast", [["stock_present", 95, 2]], "COLUMN_FLAG"],
	["flag-habitat_intensive", "coast", [["habitat_intensive", 31, 2]], "COLUMN_FLAG"],
	["flag-stock_closed", "coast", [["stock_closed", 95, 2]], "COLUMN_FLAG"],
	["flag-stock_restocking", "coast", [["stock_restocking", 95, 2]], "COLUMN_FLAG"],
	["habitat-type--1", "coast", [["habitat_type", 31, -1]], "COLUMN_HABITAT_ENUM"],
	["habitat-type-3", "coast", [["habitat_type", 31, 3]], "COLUMN_HABITAT_ENUM"],
	["habitat_pollution-negative", "coast", [["habitat_pollution", 31, -1]], "COLUMN_HABITAT_VALUE"],
	["habitat_pollution-MAX", "coast", [["habitat_pollution", 31, 2147483647]], ""],
	["inactive-habitat_pollution-MAX", "inactive-river", [["habitat_pollution", 31, 2147483647]], ""],
	["habitat_protected_fraction-negative", "coast", [["habitat_protected_fraction", 31, -1]], "COLUMN_HABITAT_VALUE"],
	["habitat_protected_fraction-MAX", "coast", [["habitat_protected_fraction", 31, 2147483647]], ""],
	["inactive-habitat_protected_fraction-MAX", "inactive-river", [["habitat_protected_fraction", 31, 2147483647]], ""],
	["danger--1", "coast", [["habitat_danger", 31, -1]], "COLUMN_HABITAT_VALUE"],
	["danger-4", "coast", [["habitat_danger", 31, 4]], "COLUMN_HABITAT_VALUE"],
	["danger-accepted-0", "coast", [["habitat_danger", 31, 0]], ""],
	["danger-accepted-3", "coast", [["habitat_danger", 31, 3]], ""],
	["hab-ref-habitat_ref_slot-1", "coast", [["habitat_ref_slot", 31, -1]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_ref_slot352418", "coast", [["habitat_ref_slot", 31, 352418]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_ref_generation0", "coast", [["habitat_ref_generation", 31, 0]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_ref_generation-1", "coast", [["habitat_ref_generation", 31, -1]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_zone_slot-2", "coast", [["habitat_zone_slot", 31, -2]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_zone_slot352418", "coast", [["habitat_zone_slot", 31, 352418]], "COLUMN_HABITAT_REF"],
	["hab-ref-habitat_zone_generation1", "coast", [["habitat_zone_generation", 31, 1]], "COLUMN_HABITAT_REF"],
	["nonnull-zone", "coast", [["habitat_zone_slot", 31, 352417], ["habitat_zone_generation", 31, 2147483647]], ""],
	["inactive-ref-habitat_ref_slot", "clear", [["habitat_ref_slot", 31, 0]], "COLUMN_HABITAT_REF"],
	["inactive-ref-habitat_ref_generation", "clear", [["habitat_ref_generation", 31, 1]], "COLUMN_HABITAT_REF"],
	["inactive-ref-habitat_zone_slot", "clear", [["habitat_zone_slot", 31, 0]], "COLUMN_HABITAT_REF"],
	["inactive-ref-habitat_zone_generation", "clear", [["habitat_zone_generation", 31, 1]], "COLUMN_HABITAT_REF"],
	["inactive-state-habitat_capacity_milli", "inactive-river", [["habitat_capacity_milli", 31, 1]], "COLUMN_HABITAT_FREE"],
	["inactive-state-habitat_effort_used", "inactive-river", [["habitat_effort_used", 31, 1]], "COLUMN_HABITAT_FREE"],
	["inactive-state-habitat_intensive", "inactive-river", [["habitat_intensive", 31, 1]], "COLUMN_HABITAT_FREE"],
	["inactive-state-habitat_effort_slots", "inactive-river", [["habitat_effort_slots", 31, 5]], "COLUMN_HABITAT_FREE"],
	["inactive-coast-zero-effort", "inactive-coast", [["habitat_effort_slots", 31, 0]], ""],
	["inactive-lake-zero-effort", "inactive-lake", [["habitat_effort_slots", 31, 0]], ""],
	["inactive-river-zero-effort", "inactive-river", [["habitat_effort_slots", 31, 0]], ""],
	["hab-state-habitat_capacity_milli0", "coast", [["habitat_capacity_milli", 31, 0]], "COLUMN_HABITAT_STATE"],
	["hab-state-habitat_capacity_milli3100001", "coast", [["habitat_capacity_milli", 31, 3100001]], "COLUMN_HABITAT_STATE"],
	["hab-state-habitat_effort_slots0", "coast", [["habitat_effort_slots", 31, 0]], "COLUMN_HABITAT_STATE"],
	["hab-state-habitat_effort_slots7", "coast", [["habitat_effort_slots", 31, 7]], "COLUMN_HABITAT_STATE"],
	["hab-state-habitat_effort_used-1", "coast", [["habitat_effort_used", 31, -1]], "COLUMN_HABITAT_STATE"],
	["hab-state-habitat_effort_used7", "coast", [["habitat_effort_used", 31, 7]], "COLUMN_HABITAT_STATE"],
	["effort-used-endpoint-0", "coast", [["habitat_effort_used", 31, 0]], ""],
	["effort-used-endpoint-6", "coast", [["habitat_effort_used", 31, 6]], ""],
	["missing-owned-stock", "coast", [["stock_present", 95, 0]], "COLUMN_STOCK_LINK"],
	["orphan-stock", "clear", [["stock_present", 95, 1]], "COLUMN_STOCK_LINK"],
	["free-stock-stock_habitat_slot", "clear", [["stock_habitat_slot", 95, 0]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_habitat_generation", "clear", [["stock_habitat_generation", 95, 1]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_species_id", "clear", [["stock_species_id", 95, 0]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_population_milli", "clear", [["stock_population_milli", 95, 1]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_capacity_milli", "clear", [["stock_capacity_milli", 95, 1]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_harvested_today_milli", "clear", [["stock_harvested_today_milli", 95, 1]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_closed", "clear", [["stock_closed", 95, 1]], "COLUMN_STOCK_FREE"],
	["free-stock-stock_restocking", "clear", [["stock_restocking", 95, 1]], "COLUMN_STOCK_FREE"],
	["stock-link-stock_habitat_slot", "coast", [["stock_habitat_slot", 95, 352417]], "COLUMN_STOCK_LINK"],
	["stock-link-stock_habitat_generation", "coast", [["stock_habitat_generation", 95, 2]], "COLUMN_STOCK_LINK"],
	["negative-species", "coast", [["stock_species_id", 95, -1]], "COLUMN_STOCK_SPECIES"],
	["MAX-species", "coast", [["stock_species_id", 95, 2147483647]], ""],
	["coast-0-wrong-capacity", "coast", [["stock_capacity_milli", 93, 1200001]], "COLUMN_STOCK_VALUE"],
	["coast-0-bad-population-119999", "coast", [["stock_population_milli", 93, 119999]], "COLUMN_STOCK_VALUE"],
	["coast-0-bad-population-1200001", "coast", [["stock_population_milli", 93, 1200001]], "COLUMN_STOCK_VALUE"],
	["coast-0-10percent-latch0", "coast", [["stock_population_milli", 93, 120000], ["stock_restocking", 93, 0]], "COLUMN_STOCK_STATE"],
	["coast-0-10percent-latch1", "coast", [["stock_population_milli", 93, 120000], ["stock_restocking", 93, 1]], ""],
	["coast-0-30percent-latch0", "coast", [["stock_population_milli", 93, 360000], ["stock_restocking", 93, 0]], ""],
	["coast-0-30percent-latch1", "coast", [["stock_population_milli", 93, 360000], ["stock_restocking", 93, 1]], ""],
	["coast-0-40percent-latch0", "coast", [["stock_population_milli", 93, 480000], ["stock_restocking", 93, 0]], ""],
	["coast-0-40percent-latch1", "coast", [["stock_population_milli", 93, 480000], ["stock_restocking", 93, 1]], ""],
	["coast-0-100percent-latch0", "coast", [["stock_population_milli", 93, 1200000], ["stock_restocking", 93, 0]], ""],
	["coast-0-100percent-latch1", "coast", [["stock_population_milli", 93, 1200000], ["stock_restocking", 93, 1]], "COLUMN_STOCK_STATE"],
	["coast-1-wrong-capacity", "coast", [["stock_capacity_milli", 94, 900001]], "COLUMN_STOCK_VALUE"],
	["coast-1-bad-population-89999", "coast", [["stock_population_milli", 94, 89999]], "COLUMN_STOCK_VALUE"],
	["coast-1-bad-population-900001", "coast", [["stock_population_milli", 94, 900001]], "COLUMN_STOCK_VALUE"],
	["coast-1-10percent-latch0", "coast", [["stock_population_milli", 94, 90000], ["stock_restocking", 94, 0]], "COLUMN_STOCK_STATE"],
	["coast-1-10percent-latch1", "coast", [["stock_population_milli", 94, 90000], ["stock_restocking", 94, 1]], ""],
	["coast-1-30percent-latch0", "coast", [["stock_population_milli", 94, 270000], ["stock_restocking", 94, 0]], ""],
	["coast-1-30percent-latch1", "coast", [["stock_population_milli", 94, 270000], ["stock_restocking", 94, 1]], ""],
	["coast-1-40percent-latch0", "coast", [["stock_population_milli", 94, 360000], ["stock_restocking", 94, 0]], ""],
	["coast-1-40percent-latch1", "coast", [["stock_population_milli", 94, 360000], ["stock_restocking", 94, 1]], ""],
	["coast-1-100percent-latch0", "coast", [["stock_population_milli", 94, 900000], ["stock_restocking", 94, 0]], ""],
	["coast-1-100percent-latch1", "coast", [["stock_population_milli", 94, 900000], ["stock_restocking", 94, 1]], "COLUMN_STOCK_STATE"],
	["coast-2-wrong-capacity", "coast", [["stock_capacity_milli", 95, 1000001]], "COLUMN_STOCK_VALUE"],
	["coast-2-bad-population-99999", "coast", [["stock_population_milli", 95, 99999]], "COLUMN_STOCK_VALUE"],
	["coast-2-bad-population-1000001", "coast", [["stock_population_milli", 95, 1000001]], "COLUMN_STOCK_VALUE"],
	["coast-2-10percent-latch0", "coast", [["stock_population_milli", 95, 100000], ["stock_restocking", 95, 0]], "COLUMN_STOCK_STATE"],
	["coast-2-10percent-latch1", "coast", [["stock_population_milli", 95, 100000], ["stock_restocking", 95, 1]], ""],
	["coast-2-30percent-latch0", "coast", [["stock_population_milli", 95, 300000], ["stock_restocking", 95, 0]], ""],
	["coast-2-30percent-latch1", "coast", [["stock_population_milli", 95, 300000], ["stock_restocking", 95, 1]], ""],
	["coast-2-40percent-latch0", "coast", [["stock_population_milli", 95, 400000], ["stock_restocking", 95, 0]], ""],
	["coast-2-40percent-latch1", "coast", [["stock_population_milli", 95, 400000], ["stock_restocking", 95, 1]], ""],
	["coast-2-100percent-latch0", "coast", [["stock_population_milli", 95, 1000000], ["stock_restocking", 95, 0]], ""],
	["coast-2-100percent-latch1", "coast", [["stock_population_milli", 95, 1000000], ["stock_restocking", 95, 1]], "COLUMN_STOCK_STATE"],
	["coast-bad-harvest--1", "coast", [["stock_harvested_today_milli", 95, -1]], "COLUMN_STOCK_VALUE"],
	["coast-bad-harvest-77501", "coast", [["stock_harvested_today_milli", 95, 77501]], "COLUMN_STOCK_VALUE"],
	["coast-bad-harvest-9223372036854775807", "coast", [["stock_harvested_today_milli", 95, 9223372036854775807]], "COLUMN_STOCK_VALUE"],
	["coast-quota-endpoint", "coast", [["stock_harvested_today_milli", 95, 77500]], ""],
	["coast-aggregate-over-quota", "coast", [["stock_harvested_today_milli", 93, 77500], ["stock_harvested_today_milli", 94, 1]], "COLUMN_QUOTA"],
	["coast-aggregate-exact-quota", "coast", [["stock_harvested_today_milli", 93, 77499], ["stock_harvested_today_milli", 94, 1]], ""],
	["lake-0-wrong-capacity", "lake", [["stock_capacity_milli", 93, 900001]], "COLUMN_STOCK_VALUE"],
	["lake-0-bad-population-89999", "lake", [["stock_population_milli", 93, 89999]], "COLUMN_STOCK_VALUE"],
	["lake-0-bad-population-900001", "lake", [["stock_population_milli", 93, 900001]], "COLUMN_STOCK_VALUE"],
	["lake-0-10percent-latch0", "lake", [["stock_population_milli", 93, 90000], ["stock_restocking", 93, 0]], "COLUMN_STOCK_STATE"],
	["lake-0-10percent-latch1", "lake", [["stock_population_milli", 93, 90000], ["stock_restocking", 93, 1]], ""],
	["lake-0-30percent-latch0", "lake", [["stock_population_milli", 93, 270000], ["stock_restocking", 93, 0]], ""],
	["lake-0-30percent-latch1", "lake", [["stock_population_milli", 93, 270000], ["stock_restocking", 93, 1]], ""],
	["lake-0-40percent-latch0", "lake", [["stock_population_milli", 93, 360000], ["stock_restocking", 93, 0]], ""],
	["lake-0-40percent-latch1", "lake", [["stock_population_milli", 93, 360000], ["stock_restocking", 93, 1]], ""],
	["lake-0-100percent-latch0", "lake", [["stock_population_milli", 93, 900000], ["stock_restocking", 93, 0]], ""],
	["lake-0-100percent-latch1", "lake", [["stock_population_milli", 93, 900000], ["stock_restocking", 93, 1]], "COLUMN_STOCK_STATE"],
	["lake-1-wrong-capacity", "lake", [["stock_capacity_milli", 94, 700001]], "COLUMN_STOCK_VALUE"],
	["lake-1-bad-population-69999", "lake", [["stock_population_milli", 94, 69999]], "COLUMN_STOCK_VALUE"],
	["lake-1-bad-population-700001", "lake", [["stock_population_milli", 94, 700001]], "COLUMN_STOCK_VALUE"],
	["lake-1-10percent-latch0", "lake", [["stock_population_milli", 94, 70000], ["stock_restocking", 94, 0]], "COLUMN_STOCK_STATE"],
	["lake-1-10percent-latch1", "lake", [["stock_population_milli", 94, 70000], ["stock_restocking", 94, 1]], ""],
	["lake-1-30percent-latch0", "lake", [["stock_population_milli", 94, 210000], ["stock_restocking", 94, 0]], ""],
	["lake-1-30percent-latch1", "lake", [["stock_population_milli", 94, 210000], ["stock_restocking", 94, 1]], ""],
	["lake-1-40percent-latch0", "lake", [["stock_population_milli", 94, 280000], ["stock_restocking", 94, 0]], ""],
	["lake-1-40percent-latch1", "lake", [["stock_population_milli", 94, 280000], ["stock_restocking", 94, 1]], ""],
	["lake-1-100percent-latch0", "lake", [["stock_population_milli", 94, 700000], ["stock_restocking", 94, 0]], ""],
	["lake-1-100percent-latch1", "lake", [["stock_population_milli", 94, 700000], ["stock_restocking", 94, 1]], "COLUMN_STOCK_STATE"],
	["lake-2-wrong-capacity", "lake", [["stock_capacity_milli", 95, 600001]], "COLUMN_STOCK_VALUE"],
	["lake-2-bad-population-59999", "lake", [["stock_population_milli", 95, 59999]], "COLUMN_STOCK_VALUE"],
	["lake-2-bad-population-600001", "lake", [["stock_population_milli", 95, 600001]], "COLUMN_STOCK_VALUE"],
	["lake-2-10percent-latch0", "lake", [["stock_population_milli", 95, 60000], ["stock_restocking", 95, 0]], "COLUMN_STOCK_STATE"],
	["lake-2-10percent-latch1", "lake", [["stock_population_milli", 95, 60000], ["stock_restocking", 95, 1]], ""],
	["lake-2-30percent-latch0", "lake", [["stock_population_milli", 95, 180000], ["stock_restocking", 95, 0]], ""],
	["lake-2-30percent-latch1", "lake", [["stock_population_milli", 95, 180000], ["stock_restocking", 95, 1]], ""],
	["lake-2-40percent-latch0", "lake", [["stock_population_milli", 95, 240000], ["stock_restocking", 95, 0]], ""],
	["lake-2-40percent-latch1", "lake", [["stock_population_milli", 95, 240000], ["stock_restocking", 95, 1]], ""],
	["lake-2-100percent-latch0", "lake", [["stock_population_milli", 95, 600000], ["stock_restocking", 95, 0]], ""],
	["lake-2-100percent-latch1", "lake", [["stock_population_milli", 95, 600000], ["stock_restocking", 95, 1]], "COLUMN_STOCK_STATE"],
	["lake-bad-harvest--1", "lake", [["stock_harvested_today_milli", 95, -1]], "COLUMN_STOCK_VALUE"],
	["lake-bad-harvest-55001", "lake", [["stock_harvested_today_milli", 95, 55001]], "COLUMN_STOCK_VALUE"],
	["lake-bad-harvest-9223372036854775807", "lake", [["stock_harvested_today_milli", 95, 9223372036854775807]], "COLUMN_STOCK_VALUE"],
	["lake-quota-endpoint", "lake", [["stock_harvested_today_milli", 95, 55000]], ""],
	["lake-aggregate-over-quota", "lake", [["stock_harvested_today_milli", 93, 55000], ["stock_harvested_today_milli", 94, 1]], "COLUMN_QUOTA"],
	["lake-aggregate-exact-quota", "lake", [["stock_harvested_today_milli", 93, 54999], ["stock_harvested_today_milli", 94, 1]], ""],
	["river-0-wrong-capacity", "river", [["stock_capacity_milli", 93, 600001]], "COLUMN_STOCK_VALUE"],
	["river-0-bad-population-59999", "river", [["stock_population_milli", 93, 59999]], "COLUMN_STOCK_VALUE"],
	["river-0-bad-population-600001", "river", [["stock_population_milli", 93, 600001]], "COLUMN_STOCK_VALUE"],
	["river-0-10percent-latch0", "river", [["stock_population_milli", 93, 60000], ["stock_restocking", 93, 0]], "COLUMN_STOCK_STATE"],
	["river-0-10percent-latch1", "river", [["stock_population_milli", 93, 60000], ["stock_restocking", 93, 1]], ""],
	["river-0-30percent-latch0", "river", [["stock_population_milli", 93, 180000], ["stock_restocking", 93, 0]], ""],
	["river-0-30percent-latch1", "river", [["stock_population_milli", 93, 180000], ["stock_restocking", 93, 1]], ""],
	["river-0-40percent-latch0", "river", [["stock_population_milli", 93, 240000], ["stock_restocking", 93, 0]], ""],
	["river-0-40percent-latch1", "river", [["stock_population_milli", 93, 240000], ["stock_restocking", 93, 1]], ""],
	["river-0-100percent-latch0", "river", [["stock_population_milli", 93, 600000], ["stock_restocking", 93, 0]], ""],
	["river-0-100percent-latch1", "river", [["stock_population_milli", 93, 600000], ["stock_restocking", 93, 1]], "COLUMN_STOCK_STATE"],
	["river-1-wrong-capacity", "river", [["stock_capacity_milli", 94, 900001]], "COLUMN_STOCK_VALUE"],
	["river-1-bad-population-89999", "river", [["stock_population_milli", 94, 89999]], "COLUMN_STOCK_VALUE"],
	["river-1-bad-population-900001", "river", [["stock_population_milli", 94, 900001]], "COLUMN_STOCK_VALUE"],
	["river-1-10percent-latch0", "river", [["stock_population_milli", 94, 90000], ["stock_restocking", 94, 0]], "COLUMN_STOCK_STATE"],
	["river-1-10percent-latch1", "river", [["stock_population_milli", 94, 90000], ["stock_restocking", 94, 1]], ""],
	["river-1-30percent-latch0", "river", [["stock_population_milli", 94, 270000], ["stock_restocking", 94, 0]], ""],
	["river-1-30percent-latch1", "river", [["stock_population_milli", 94, 270000], ["stock_restocking", 94, 1]], ""],
	["river-1-40percent-latch0", "river", [["stock_population_milli", 94, 360000], ["stock_restocking", 94, 0]], ""],
	["river-1-40percent-latch1", "river", [["stock_population_milli", 94, 360000], ["stock_restocking", 94, 1]], ""],
	["river-1-100percent-latch0", "river", [["stock_population_milli", 94, 900000], ["stock_restocking", 94, 0]], ""],
	["river-1-100percent-latch1", "river", [["stock_population_milli", 94, 900000], ["stock_restocking", 94, 1]], "COLUMN_STOCK_STATE"],
	["river-2-wrong-capacity", "river", [["stock_capacity_milli", 95, 600001]], "COLUMN_STOCK_VALUE"],
	["river-2-bad-population-59999", "river", [["stock_population_milli", 95, 59999]], "COLUMN_STOCK_VALUE"],
	["river-2-bad-population-600001", "river", [["stock_population_milli", 95, 600001]], "COLUMN_STOCK_VALUE"],
	["river-2-10percent-latch0", "river", [["stock_population_milli", 95, 60000], ["stock_restocking", 95, 0]], "COLUMN_STOCK_STATE"],
	["river-2-10percent-latch1", "river", [["stock_population_milli", 95, 60000], ["stock_restocking", 95, 1]], ""],
	["river-2-30percent-latch0", "river", [["stock_population_milli", 95, 180000], ["stock_restocking", 95, 0]], ""],
	["river-2-30percent-latch1", "river", [["stock_population_milli", 95, 180000], ["stock_restocking", 95, 1]], ""],
	["river-2-40percent-latch0", "river", [["stock_population_milli", 95, 240000], ["stock_restocking", 95, 0]], ""],
	["river-2-40percent-latch1", "river", [["stock_population_milli", 95, 240000], ["stock_restocking", 95, 1]], ""],
	["river-2-100percent-latch0", "river", [["stock_population_milli", 95, 600000], ["stock_restocking", 95, 0]], ""],
	["river-2-100percent-latch1", "river", [["stock_population_milli", 95, 600000], ["stock_restocking", 95, 1]], "COLUMN_STOCK_STATE"],
	["river-bad-harvest--1", "river", [["stock_harvested_today_milli", 95, -1]], "COLUMN_STOCK_VALUE"],
	["river-bad-harvest-52501", "river", [["stock_harvested_today_milli", 95, 52501]], "COLUMN_STOCK_VALUE"],
	["river-bad-harvest-9223372036854775807", "river", [["stock_harvested_today_milli", 95, 9223372036854775807]], "COLUMN_STOCK_VALUE"],
	["river-quota-endpoint", "river", [["stock_harvested_today_milli", 95, 52500]], ""],
	["river-aggregate-over-quota", "river", [["stock_harvested_today_milli", 93, 52500], ["stock_harvested_today_milli", 94, 1]], "COLUMN_QUOTA"],
	["river-aggregate-exact-quota", "river", [["stock_harvested_today_milli", 93, 52499], ["stock_harvested_today_milli", 94, 1]], ""],
	["species-duplicate", "coast", [["stock_species_id", 95, 101]], "COLUMN_SPECIES_DUPLICATE"],
	["species-before-quota", "coast", [["stock_species_id", 95, 101], ["stock_harvested_today_milli", 93, 77500], ["stock_harvested_today_milli", 94, 1]], "COLUMN_SPECIES_DUPLICATE"],
	["two-present", "two-coast", [], ""],
	["same-species-across-habitats", "two-coast", [], ""],
	["duplicate-self-samegen", "duplicate-self", [], "COLUMN_SELF_DUPLICATE"],
	["duplicate-self-differentgen", "duplicate-self-newgen", [], "COLUMN_SELF_DUPLICATE"],
	["duplicate-zone-pair", "duplicate-zone", [], "COLUMN_ZONE_DUPLICATE"],
	["zone-same-slot-newgen", "zone-newgen", [], ""],
	["self-before-zone", "duplicate-self-zone", [], "COLUMN_SELF_DUPLICATE"],
	["global-flag-before-habitat-enum", "clear", [["habitat_type", 0, 3], ["stock_restocking", 95, 2]], "COLUMN_FLAG"],
	["earlier-habitat-value-before-later-enum", "clear", [["habitat_pollution", 0, -1], ["habitat_type", 31, 3]], "COLUMN_HABITAT_VALUE"],
	["habitat-before-stock", "coast", [["habitat_pollution", 31, -1], ["stock_species_id", 0, 0]], "COLUMN_HABITAT_VALUE"],
	["stock-link-before-stock-free", "clear", [["stock_present", 95, 1], ["stock_capacity_milli", 95, 1]], "COLUMN_STOCK_LINK"],
	["stock-value-before-hysteresis", "coast", [["stock_population_milli", 95, -1], ["stock_restocking", 95, 0]], "COLUMN_STOCK_VALUE"]
]

func _put(c: Owner.Columns, field: int, row: int, value: int) -> void:
	var held: Variant = c.get(FIELDS[field])
	held[row] = value
	c.set(FIELDS[field],held)
func _snapshot(c: Owner.Columns) -> Array:
	var out: Array = []
	for key: String in FIELDS: out.append(c.get(key).duplicate())
	return out
func _frame(c: Owner.Columns) -> Section.FramedOwner:
	var f: Section.FramedOwner = Section.FramedOwner.new(4)
	for field: int in 22:
		var values: Variant = c.get(FIELDS[field]).duplicate()
		if TYPES[field] == 0: assert(f.set_u8(field,values))
		elif TYPES[field] == 2: assert(f.set_i32(field,values))
		else: assert(f.set_i64(field,values))
	return f
func _fill(c: Owner.Columns, row: int, kind: int, self_slot: int, generation: int) -> void:
	var capacities: Array = [[1200000,900000,1000000],[900000,700000,600000],[600000,900000,600000]]
	c.habitat_present[row] = 1
	c.habitat_type[row] = kind
	c.habitat_effort_slots[row] = 4 if kind == 2 else 6
	c.habitat_capacity_milli[row] = [3100000,2200000,2100000][kind]
	c.habitat_ref_slot[row] = self_slot
	c.habitat_ref_generation[row] = generation
	for index: int in 3:
		var stock: int = row*3+index
		c.stock_present[stock] = 1
		c.stock_habitat_slot[stock] = self_slot
		c.stock_habitat_generation[stock] = generation
		c.stock_species_id[stock] = 101+index
		c.stock_capacity_milli[stock] = int(capacities[kind][index])
		@warning_ignore("integer_division") c.stock_population_milli[stock] = int(capacities[kind][index])*8/10
func _image(name: String) -> Owner.Columns:
	var c: Owner.Columns = Owner.Columns.new()
	if name == "clear": return c
	if name.begins_with("inactive-"):
		var kind: int = {"inactive-coast":0,"inactive-lake":1,"inactive-river":2}[name]
		c.habitat_type[31] = kind
		c.habitat_effort_slots[31] = 4 if kind == 2 else 6
		c.habitat_pollution[31] = 2147483647
		c.habitat_protected_fraction[31] = 2147483647
		c.habitat_danger[31] = 3
		return c
	var kind_id: int = {"coast":0,"lake":1,"river":2}.get(name,0)
	_fill(c,31,kind_id,31,1)
	if name in ["two-coast","duplicate-self","duplicate-self-newgen","duplicate-zone","zone-newgen","duplicate-self-zone"]:
		_fill(c,0,0,0,1)
	if name in ["duplicate-self","duplicate-self-newgen","duplicate-self-zone"]:
		_fill(c,31,0,0,2 if name == "duplicate-self-newgen" else 1)
	if name in ["duplicate-zone","zone-newgen","duplicate-self-zone"]:
		c.habitat_zone_slot[0] = 352417
		c.habitat_zone_generation[0] = 1
		c.habitat_zone_slot[31] = 352417
		c.habitat_zone_generation[31] = 2 if name == "zone-newgen" else 1
	return c
func _expect(c: Owner.Columns, code: StringName, label: String) -> void:
	var before: Array = _snapshot(c)
	var f: Section.FramedOwner = _frame(c)
	assert_equal(Owner.columns_refusal(c),code,label+" pure")
	var actual: Variant = Bridge.framed_refusal(f)
	assert_equal(actual.code,code,label+" bridge")
	assert_equal(actual.is_ok(),code == &"",label+" success")
	if code == &"": assert_equal(actual.detail,"",label+" success detail")
	else:
		assert_true(actual.detail.contains("Fishing owner 4 "),label+" owner detail")
		assert_true(actual.detail.contains(String(code)),label+" raw code detail")
	for field: int in 22:
		assert_true(c.get(FIELDS[field]) == before[field],label+" input unchanged")
		var held: Variant
		if TYPES[field] == 0: held = f.u8_column(field)
		elif TYPES[field] == 2: held = f.i32_column(field)
		else: held = f.i64_column(field)
		assert_true(held == before[field],label+" frame unchanged")
func test_layout_defaults_and_conditional_memory() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	_expect(c,&"","clear")
	assert_equal(Schema.owner_version(4),1,"section4 version, not claim schema")
	assert_equal(Schema.primary_count(4),32,"primary")
	assert_equal(Schema.child_extent_count(4),0,"stock counts are literal, not child extent")
	assert_equal(Schema.field_count(4),22,"fields")
	var payload: int = 0
	for field: int in 22:
		assert_equal(Schema.field_key(4,field),"_"+FIELDS[field],"key")
		assert_equal(Schema.field_type(4,field),TYPES[field],"type")
		assert_equal(Schema.element_count(4,field),COUNTS[field],"extent")
		assert_equal(c.get(FIELDS[field]).count(-1 if field in [3,10,14,16] else 0),COUNTS[field],"clear default")
		payload += COUNTS[field]*(1 if TYPES[field] == 0 else 4 if TYPES[field] == 2 else 8)
	assert_equal(payload,5344,"value bytes")
	assert_equal(2*payload,10688,"conservative packed arithmetic, not RSS")
func test_frozen_domains_history_relations_and_projection_witnesses() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,FIELDS.find(change[0]),int(change[1]),int(change[2]))
		_expect(c,StringName(item[3]),item[0])
func test_null_all_extents_and_bucket_shapes() -> void:
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","pure null")
	assert_equal(Bridge.framed_refusal(null).code,Section.REFUSE_SHAPE,"bridge null")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(3)).code,Section.REFUSE_OWNER,"wrong owner")
	for field: int in 22:
		for count: int in [0,COUNTS[field]-1,COUNTS[field]+1]:
			var c: Owner.Columns = Owner.Columns.new()
			var values: Variant = c.get(FIELDS[field]).duplicate()
			values.resize(count)
			c.set(FIELDS[field],values)
			if field == 0: c.stock_present[0] = 2
			else: c.habitat_present[0] = 2
			var before: Array = _snapshot(c)
			assert_equal(Owner.columns_refusal(c),&"COLUMN_SHAPE","shape before malformed flag")
			for key: int in 22: assert_true(c.get(FIELDS[key]) == before[key],"shape input unchanged")
	for bucket: int in 3:
		for delta: int in [-1,1]:
			var f: Section.FramedOwner = _frame(Owner.Columns.new())
			if bucket == 0: f.u8_columns.resize(f.u8_columns.size()+delta)
			elif bucket == 1: f.i32_columns.resize(f.i32_columns.size()+delta)
			else: f.i64_columns.resize(f.i64_columns.size()+delta)
			var expected: Variant = Section.owner_shape_refusal(f)
			var actual: Variant = Bridge.framed_refusal(f)
			assert_equal(actual.code,expected.code,"shape forwarded")
			assert_equal(actual.detail,expected.detail,"shape detail forwarded")
			assert_false(actual.is_ok(),"malformed bucket")
func test_every_field_at_every_physical_row() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var before: Array = _snapshot(c)
	var bad: Array[int] = [2,2,3,0,1,5,-1,4,-1,1,0,1,1,2,0,1,0,1,1,1,2,2]
	var codes: Array[StringName] = [&"COLUMN_FLAG",&"COLUMN_FLAG",&"COLUMN_HABITAT_ENUM",&"COLUMN_HABITAT_REF",&"COLUMN_HABITAT_REF",&"COLUMN_HABITAT_FREE",&"COLUMN_HABITAT_VALUE",&"COLUMN_HABITAT_VALUE",&"COLUMN_HABITAT_VALUE",&"COLUMN_HABITAT_FREE",&"COLUMN_HABITAT_REF",&"COLUMN_HABITAT_REF",&"COLUMN_HABITAT_FREE",&"COLUMN_FLAG",&"COLUMN_STOCK_FREE",&"COLUMN_STOCK_FREE",&"COLUMN_STOCK_FREE",&"COLUMN_STOCK_FREE",&"COLUMN_STOCK_FREE",&"COLUMN_STOCK_FREE",&"COLUMN_FLAG",&"COLUMN_FLAG"]
	for field: int in 22:
		for row: int in COUNTS[field]:
			_put(c,field,row,bad[field])
			assert_equal(Owner.columns_refusal(c),codes[field],"physical field%d row%d" % [field,row])
			assert_equal(int(c.get(FIELDS[field])[row]),bad[field],"fault preserved")
			if row == 0 or row == COUNTS[field]-1: _expect(c,codes[field],"bridge edges")
			_put(c,field,row,-1 if field in [3,10,14,16] else 0)
	for field: int in 22: assert_true(c.get(FIELDS[field]) == before[field],"all bytes restored")
	_expect(c,&"","restored clear")
func test_full_capacity_and_present_identity_endpoints() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	for row: int in 32: _fill(c,row,row%3,row,1)
	_expect(c,&"","32 habitats and96stocks; same species IDs across habitats legal")
	_fill(c,31,1,352417,2147483647)
	c.habitat_zone_slot[31] = 0
	c.habitat_zone_generation[31] = 2147483647
	c.habitat_effort_used[31] = 6
	c.habitat_intensive[31] = 1
	c.stock_closed[93] = 1
	_expect(c,&"","max structural identity and nondefault policy/occupancy/event bits")
func test_retained_inactive_history_all_rows() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	for row: int in 32:
		c.habitat_type[row] = row%3
		c.habitat_effort_slots[row] = 4 if row%3 == 2 else 6
		c.habitat_pollution[row] = 2147483647
		c.habitat_protected_fraction[row] = 2147483647
		c.habitat_danger[row] = 3
	_expect(c,&"","all inactive habitats retain valid history, stocks blank")
func test_paired_priorities_not_just_acceptance() -> void:
	var c: Owner.Columns = _image("duplicate-self-zone")
	_expect(c,&"COLUMN_SELF_DUPLICATE","self before zone")
	c = _image("coast")
	c.stock_species_id[95] = 101
	c.stock_harvested_today_milli[93] = 77500
	c.stock_harvested_today_milli[94] = 1
	_expect(c,&"COLUMN_SPECIES_DUPLICATE","species before quota")


# --- ADR 1222 step 2: bulk capture and apply ------------------------------------------------------

func _bulk_owner() -> Owner:
	"""A store with live, edited, freed and reused rows, built through the public lifecycle only."""
	var owner: Owner = Owner.new()
	var coast: Owner.OpResult = owner.create_habitat(Owner.HABITAT_COAST, Owner.NULL_REF,
		PackedInt32Array([10, 11, 12]), 3, 1, 5)
	var lake: Owner.OpResult = owner.create_habitat(Owner.HABITAT_LAKE, Owner.NULL_REF,
		PackedInt32Array([20, 21, 22]), 0, 0, 0)
	var river: Owner.OpResult = owner.create_habitat(Owner.HABITAT_RIVER, Owner.NULL_REF,
		PackedInt32Array([30, 31, 32]), 0, 2, 25)
	assert_true(coast.ok and lake.ok and river.ok, "create the three starting habitats")
	assert_true(owner.set_intensive_harvest(lake.ref, true).ok, "edit the intensive flag")
	assert_true(owner.set_closed(river.ref, 0, true).ok, "edit a closure flag")
	assert_true(owner.destroy_habitat(coast.ref).ok, "free a habitat row")
	var reused: Owner.OpResult = owner.create_habitat(Owner.HABITAT_COAST, Owner.NULL_REF,
		PackedInt32Array([40, 41, 42]), 1, 1, 1)
	assert_true(reused.ok, "reuse the freed row")
	var extra: Owner.OpResult = owner.create_habitat(Owner.HABITAT_RIVER, Owner.NULL_REF,
		PackedInt32Array([50, 51, 52]), 0, 0, 0)
	assert_true(extra.ok, "create a fourth habitat")
	assert_true(owner.destroy_habitat(extra.ref).ok, "leave a freed row behind")
	return owner


func _bulk_columns(owner: Owner) -> Owner.Columns:
	"""The owner's 22 columns through the bulk reader."""
	var columns: Owner.Columns = Owner.Columns.new()
	assert_true(owner.copy_columns_into(columns), "bulk copy succeeds")
	return columns


func test_capture_then_apply_into_a_fresh_store_is_exact_and_continues_identically() -> void:
	"""The restored store holds the same columns and continues to answer later calls the same way."""
	var source: Owner = _bulk_owner()
	var frame: Section.FramedOwner = Section.FramedOwner.new(4)
	assert_true(Bridge.capture_into(source, frame).is_ok(), "capture succeeds")
	var target: Owner = Owner.new()
	assert_true(Bridge.apply(frame, target).is_ok(), "apply succeeds")
	assert_true(_bulk_columns(target).equals(_bulk_columns(source)), "columns are byte-identical")
	assert_equal(target.habitat_count(), source.habitat_count(), "the active list is rebuilt")
	for store: Owner in [source, target]:
		assert_true(store.recover_daily(Owner.SEASON_SPRING, 1).ok, "a later sweep succeeds")
		store.reset_harvested_today()
	assert_true(_bulk_columns(target).equals(_bulk_columns(source)),
		"both stores stayed identical after the same later operations")


func test_every_column_refusal_leaves_the_target_byte_identical() -> void:
	"""Each column code refuses through apply with the exact code and writes nothing."""
	var target: Owner = _bulk_owner()
	var before: Owner.Columns = _bulk_columns(target)
	var cases: Array = [["coast", "habitat_present", 31, 2, &"COLUMN_FLAG"],
		["coast", "habitat_type", 31, -1, &"COLUMN_HABITAT_ENUM"],
		["clear", "stock_present", 95, 1, &"COLUMN_STOCK_LINK"],
		["coast", "stock_species_id", 95, 101, &"COLUMN_SPECIES_DUPLICATE"]]
	for entry: Array in cases:
		var c: Owner.Columns = _image(entry[0])
		_put(c, FIELDS.find(entry[1]), int(entry[2]), int(entry[3]))
		var refusal: Variant = Bridge.apply(_frame(c), target)
		assert_equal(refusal.code, entry[4], "exact code for %s" % entry[1])
	assert_true(_bulk_columns(target).equals(before), "no refusal wrote a column")


func test_null_and_misshaped_inputs_refuse_without_writing() -> void:
	"""Null stores, null records, a wrong owner and a short bulk buffer all refuse."""
	var target: Owner = _bulk_owner()
	var before: Owner.Columns = _bulk_columns(target)
	var clear_frame: Section.FramedOwner = Section.FramedOwner.new(4)
	assert_true(Bridge.capture_into(Owner.new(), clear_frame).is_ok(), "capture an empty store")
	assert_equal(Bridge.apply(clear_frame, null).code, Bridge.REFUSE_NULL_STORE, "null store")
	assert_equal(Bridge.capture_into(null, Section.FramedOwner.new(4)).code,
		Bridge.REFUSE_NULL_STORE, "capture from no store")
	assert_equal(Bridge.capture_into(target, null).code, Section.REFUSE_SHAPE, "null record")
	assert_equal(Bridge.capture_into(target, Section.FramedOwner.new(3)).code,
		Section.REFUSE_OWNER, "wrong owner")
	var short: Owner.Columns = Owner.Columns.new()
	short.habitat_present.resize(3)
	assert_false(target.restore_columns(short), "a short column refuses")
	assert_equal(target.last_column_refusal(), Owner.REFUSE_COLUMN_SHAPE, "shape code")
	assert_false(target.copy_columns_into(short), "a short output buffer refuses")
	assert_false(target.restore_columns(null), "null columns refuse")
	assert_false(target.copy_columns_into(null), "null output refuses")
	assert_true(_bulk_columns(target).equals(before), "nothing was written")
