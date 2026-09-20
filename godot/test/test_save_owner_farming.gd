extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/farming.gd")
const Bridge := preload("res://scripts/core/save_owner_farming.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[String] = ["present", "crop_id", "state", "soil", "fertility", "moisture", "growth_milli_hours", "health", "last_family", "family_streak", "compost_milli", "sow_day", "tile", "ref_slot", "ref_generation"]
const TYPES: Array[int] = [0, 2, 2, 2, 2, 2, 4, 2, 2, 2, 4, 2, 2, 2, 2]
const FIXTURES: Dictionary = {
 "clear": {},
 "empty": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 10000,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647
 },
 "sown": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 10000,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647,
  "crop_id": 3,
  "state": 1,
  "sow_day": 1
 },
 "growing": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 1,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647,
  "crop_id": 3,
  "state": 2,
  "sow_day": 1,
  "growth_milli_hours": 191999
 },
 "ripe": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 1,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647,
  "crop_id": 3,
  "state": 3,
  "sow_day": 1,
  "growth_milli_hours": 192000
 },
 "withered_health": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 0,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647,
  "crop_id": 3,
  "state": 4,
  "sow_day": 1,
  "growth_milli_hours": 191999
 },
 "withered_age": {
  "present": 1,
  "soil": 0,
  "fertility": 7000,
  "moisture": 6000,
  "health": 1,
  "tile": 16383,
  "ref_slot": 352417,
  "ref_generation": 2147483647,
  "crop_id": 3,
  "state": 4,
  "sow_day": 1,
  "growth_milli_hours": 192000
 },
 "inactive_history": {
  "soil": 2,
  "fertility": 10000,
  "moisture": 10000,
  "growth_milli_hours": 9223372036854775807,
  "health": 10000,
  "last_family": 4,
  "family_streak": 2147483647,
  "compost_milli": 2000,
  "sow_day": 2147483647
 }
}
const CASES: Array = [
	["accept-clear", "clear", [], ""],
	["accept-empty", "empty", [], ""],
	["accept-sown", "sown", [], ""],
	["accept-growing", "growing", [], ""],
	["accept-ripe", "ripe", [], ""],
	["accept-withered_health", "withered_health", [], ""],
	["accept-withered_age", "withered_age", [], ""],
	["accept-inactive_history", "inactive_history", [], ""],
	["projection-present", "clear", [[0, 4095, 2]], "COLUMN_PRESENT"],
	["projection-crop_id", "clear", [[1, 4095, -2]], "COLUMN_ENUM"],
	["projection-state", "clear", [[2, 4095, 5]], "COLUMN_ENUM"],
	["projection-soil", "clear", [[3, 4095, 3]], "COLUMN_ENUM"],
	["projection-fertility", "clear", [[4, 4095, -1]], "COLUMN_VALUE"],
	["projection-moisture", "clear", [[5, 4095, -1]], "COLUMN_VALUE"],
	["projection-growth_milli_hours", "clear", [[6, 4095, -1]], "COLUMN_VALUE"],
	["projection-health", "clear", [[7, 4095, -1]], "COLUMN_VALUE"],
	["projection-last_family", "clear", [[8, 4095, -2]], "COLUMN_HISTORY"],
	["projection-family_streak", "clear", [[9, 4095, -1]], "COLUMN_HISTORY"],
	["projection-compost_milli", "clear", [[10, 4095, 1]], "COLUMN_VALUE"],
	["projection-sow_day", "clear", [[11, 4095, -1]], "COLUMN_VALUE"],
	["projection-tile", "clear", [[12, 4095, -2]], "COLUMN_IDENTITY"],
	["projection-ref_slot", "clear", [[13, 4095, -2]], "COLUMN_IDENTITY"],
	["projection-ref_generation", "clear", [[14, 4095, -1]], "COLUMN_IDENTITY"],
	["enum-crop_id--2", "clear", [[1, 4095, -2]], "COLUMN_ENUM"],
	["enum-crop_id-5", "clear", [[1, 4095, 5]], "COLUMN_ENUM"],
	["enum-state--1", "clear", [[2, 4095, -1]], "COLUMN_ENUM"],
	["enum-state-5", "clear", [[2, 4095, 5]], "COLUMN_ENUM"],
	["enum-soil--1", "clear", [[3, 4095, -1]], "COLUMN_ENUM"],
	["enum-soil-3", "clear", [[3, 4095, 3]], "COLUMN_ENUM"],
	["range-fertility--1", "clear", [[4, 4095, -1]], "COLUMN_VALUE"],
	["range-fertility-10001", "clear", [[4, 4095, 10001]], "COLUMN_VALUE"],
	["range-moisture--1", "clear", [[5, 4095, -1]], "COLUMN_VALUE"],
	["range-moisture-10001", "clear", [[5, 4095, 10001]], "COLUMN_VALUE"],
	["range-health--1", "clear", [[7, 4095, -1]], "COLUMN_VALUE"],
	["range-health-10001", "clear", [[7, 4095, 10001]], "COLUMN_VALUE"],
	["value-growth_milli_hours--1", "clear", [[6, 4095, -1]], "COLUMN_VALUE"],
	["value-compost_milli--1", "clear", [[10, 4095, -1]], "COLUMN_VALUE"],
	["value-compost_milli-1", "clear", [[10, 4095, 1]], "COLUMN_VALUE"],
	["value-compost_milli-1999", "clear", [[10, 4095, 1999]], "COLUMN_VALUE"],
	["value-compost_milli-2001", "clear", [[10, 4095, 2001]], "COLUMN_VALUE"],
	["value-compost_milli-9223372036854775807", "clear", [[10, 4095, 9223372036854775807]], "COLUMN_VALUE"],
	["value-sow_day--1", "clear", [[11, 4095, -1]], "COLUMN_VALUE"],
	["history--2-1", "clear", [[8, 4095, -2], [9, 4095, 1]], "COLUMN_HISTORY"],
	["history-5-1", "clear", [[8, 4095, 5], [9, 4095, 1]], "COLUMN_HISTORY"],
	["history--1-1", "clear", [[8, 4095, -1], [9, 4095, 1]], "COLUMN_HISTORY"],
	["history-0-0", "clear", [[8, 4095, 0], [9, 4095, 0]], "COLUMN_HISTORY"],
	["history-4-0", "clear", [[8, 4095, 4], [9, 4095, 0]], "COLUMN_HISTORY"],
	["history-0--1", "clear", [[8, 4095, 0], [9, 4095, -1]], "COLUMN_HISTORY"],
	["history--1--1", "clear", [[8, 4095, -1], [9, 4095, -1]], "COLUMN_HISTORY"],
	["accept-family-0-1", "clear", [[8, 4095, 0], [9, 4095, 1]], ""],
	["accept-family-0-2147483647", "clear", [[8, 4095, 0], [9, 4095, 2147483647]], ""],
	["accept-family-1-1", "clear", [[8, 4095, 1], [9, 4095, 1]], ""],
	["accept-family-1-2147483647", "clear", [[8, 4095, 1], [9, 4095, 2147483647]], ""],
	["accept-family-2-1", "clear", [[8, 4095, 2], [9, 4095, 1]], ""],
	["accept-family-2-2147483647", "clear", [[8, 4095, 2], [9, 4095, 2147483647]], ""],
	["accept-family-3-1", "clear", [[8, 4095, 3], [9, 4095, 1]], ""],
	["accept-family-3-2147483647", "clear", [[8, 4095, 3], [9, 4095, 2147483647]], ""],
	["accept-family-4-1", "clear", [[8, 4095, 4], [9, 4095, 1]], ""],
	["accept-family-4-2147483647", "clear", [[8, 4095, 4], [9, 4095, 2147483647]], ""],
	["present-identity-tile--1", "empty", [[12, 4095, -1]], "COLUMN_IDENTITY"],
	["present-identity-tile-16384", "empty", [[12, 4095, 16384]], "COLUMN_IDENTITY"],
	["present-identity-ref_slot--1", "empty", [[13, 4095, -1]], "COLUMN_IDENTITY"],
	["present-identity-ref_slot-352418", "empty", [[13, 4095, 352418]], "COLUMN_IDENTITY"],
	["present-identity-ref_generation-0", "empty", [[14, 4095, 0]], "COLUMN_IDENTITY"],
	["present-identity-ref_generation--1", "empty", [[14, 4095, -1]], "COLUMN_IDENTITY"],
	["inactive-identity-tile", "clear", [[12, 4095, 0]], "COLUMN_IDENTITY"],
	["inactive-identity-ref_slot", "clear", [[13, 4095, 0]], "COLUMN_IDENTITY"],
	["inactive-identity-ref_generation", "clear", [[14, 4095, 1]], "COLUMN_IDENTITY"],
	["free-crop", "clear", [[1, 4095, 0]], "COLUMN_FREE_ROW"],
	["free-state", "clear", [[2, 4095, 1]], "COLUMN_FREE_ROW"],
	["empty-state-crop_id", "empty", [[1, 4095, 0]], "COLUMN_STATE"],
	["empty-state-growth_milli_hours", "empty", [[6, 4095, 1]], "COLUMN_STATE"],
	["empty-state-health", "empty", [[7, 4095, 0]], "COLUMN_STATE"],
	["empty-state-health", "empty", [[7, 4095, 9999]], "COLUMN_STATE"],
	["empty-state-sow_day", "empty", [[11, 4095, 1]], "COLUMN_STATE"],
	["sown-state-crop_id--1", "sown", [[1, 4095, -1]], "COLUMN_STATE"],
	["sown-state-sow_day-0", "sown", [[11, 4095, 0]], "COLUMN_STATE"],
	["sown-state-soil-2", "sown", [[3, 4095, 2]], "COLUMN_STATE"],
	["sown-state-growth_milli_hours-1", "sown", [[6, 4095, 1]], "COLUMN_STATE"],
	["sown-state-health-9999", "sown", [[7, 4095, 9999]], "COLUMN_STATE"],
	["sown-state-health-0", "sown", [[7, 4095, 0]], "COLUMN_STATE"],
	["growing-health-zero", "growing", [[7, 4095, 0]], "COLUMN_STATE"],
	["growing-at-target", "growing", [[6, 4095, 192000]], "COLUMN_STATE"],
	["ripe-health-zero", "ripe", [[7, 4095, 0]], "COLUMN_STATE"],
	["ripe-below-target", "ripe", [[6, 4095, 191999]], "COLUMN_STATE"],
	["ripe-over-maximum", "ripe", [[6, 4095, 193000]], "COLUMN_STATE"],
	["withered-zero-health-at-target", "withered_health", [[6, 4095, 192000]], "COLUMN_STATE"],
	["withered-positive-health-below-target", "withered_age", [[6, 4095, 191999]], "COLUMN_STATE"],
	["withered-over-maximum", "withered_age", [[6, 4095, 193000]], "COLUMN_STATE"],
	["accept-ripe-192000", "ripe", [[6, 4095, 192000]], ""],
	["accept-ripe-192999", "ripe", [[6, 4095, 192999]], ""],
	["accept-withered_age-192000", "withered_age", [[6, 4095, 192000]], ""],
	["accept-withered_age-192999", "withered_age", [[6, 4095, 192999]], ""],
	["accept-health-death-before-growth", "withered_health", [[6, 4095, 0]], ""],
	["accept-sown-max-day", "sown", [[11, 4095, 2147483647]], ""],
	["value-before-state", "growing", [[6, 4095, -1]], "COLUMN_VALUE"],
	["global-present-before-early-enum", "clear", [[3, 0, 3], [0, 4095, 2]], "COLUMN_PRESENT"],
	["per-row-value-before-later-enum", "clear", [[4, 0, -1], [3, 4095, 3]], "COLUMN_VALUE"],
	["accept-two-identities", "empty", [[0, 0, 1], [7, 0, 10000], [12, 0, 0], [13, 0, 0], [14, 0, 1]], ""],
	["duplicate-tile", "empty", [[0, 0, 1], [7, 0, 10000], [12, 0, 0], [13, 0, 0], [14, 0, 1], [12, 4095, 0]], "COLUMN_DUPLICATE_TILE"],
	["duplicate-ref-same-generation", "empty", [[0, 0, 1], [7, 0, 10000], [12, 0, 0], [13, 0, 0], [14, 0, 1], [13, 4095, 0], [14, 4095, 1]], "COLUMN_DUPLICATE_REF"],
	["duplicate-ref-different-generation", "empty", [[0, 0, 1], [7, 0, 10000], [12, 0, 0], [13, 0, 0], [14, 0, 1], [13, 4095, 0]], "COLUMN_DUPLICATE_REF"],
	["duplicate-tile-before-ref", "empty", [[0, 0, 1], [7, 0, 10000], [12, 0, 0], [13, 0, 0], [14, 0, 1], [12, 4095, 0], [13, 4095, 0]], "COLUMN_DUPLICATE_TILE"],
	["crop-soil-0-0", "sown", [[1, 4095, 0], [3, 4095, 0]], ""],
	["crop-soil-0-1", "sown", [[1, 4095, 0], [3, 4095, 1]], ""],
	["crop-soil-0-2", "sown", [[1, 4095, 0], [3, 4095, 2]], "COLUMN_STATE"],
	["crop-soil-1-0", "sown", [[1, 4095, 1], [3, 4095, 0]], ""],
	["crop-soil-1-1", "sown", [[1, 4095, 1], [3, 4095, 1]], ""],
	["crop-soil-1-2", "sown", [[1, 4095, 1], [3, 4095, 2]], "COLUMN_STATE"],
	["crop-soil-2-0", "sown", [[1, 4095, 2], [3, 4095, 0]], ""],
	["crop-soil-2-1", "sown", [[1, 4095, 2], [3, 4095, 1]], "COLUMN_STATE"],
	["crop-soil-2-2", "sown", [[1, 4095, 2], [3, 4095, 2]], ""],
	["crop-soil-3-0", "sown", [[1, 4095, 3], [3, 4095, 0]], ""],
	["crop-soil-3-1", "sown", [[1, 4095, 3], [3, 4095, 1]], ""],
	["crop-soil-3-2", "sown", [[1, 4095, 3], [3, 4095, 2]], "COLUMN_STATE"],
	["crop-soil-4-0", "sown", [[1, 4095, 4], [3, 4095, 0]], ""],
	["crop-soil-4-1", "sown", [[1, 4095, 4], [3, 4095, 1]], "COLUMN_STATE"],
	["crop-soil-4-2", "sown", [[1, 4095, 4], [3, 4095, 2]], ""],
	["state-edge-0-2-1-143999", "sown", [[1, 4095, 0], [2, 4095, 2], [6, 4095, 143999], [7, 4095, 1]], ""],
	["state-edge-0-2-1-144000", "sown", [[1, 4095, 0], [2, 4095, 2], [6, 4095, 144000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-0-3-1-144000", "sown", [[1, 4095, 0], [2, 4095, 3], [6, 4095, 144000], [7, 4095, 1]], ""],
	["state-edge-0-3-1-144999", "sown", [[1, 4095, 0], [2, 4095, 3], [6, 4095, 144999], [7, 4095, 1]], ""],
	["state-edge-0-3-1-145000", "sown", [[1, 4095, 0], [2, 4095, 3], [6, 4095, 145000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-0-4-0-143999", "sown", [[1, 4095, 0], [2, 4095, 4], [6, 4095, 143999], [7, 4095, 0]], ""],
	["state-edge-0-4-0-144000", "sown", [[1, 4095, 0], [2, 4095, 4], [6, 4095, 144000], [7, 4095, 0]], "COLUMN_STATE"],
	["state-edge-0-4-1-144000", "sown", [[1, 4095, 0], [2, 4095, 4], [6, 4095, 144000], [7, 4095, 1]], ""],
	["state-edge-0-4-1-143999", "sown", [[1, 4095, 0], [2, 4095, 4], [6, 4095, 143999], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-1-2-1-119999", "sown", [[1, 4095, 1], [2, 4095, 2], [6, 4095, 119999], [7, 4095, 1]], ""],
	["state-edge-1-2-1-120000", "sown", [[1, 4095, 1], [2, 4095, 2], [6, 4095, 120000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-1-3-1-120000", "sown", [[1, 4095, 1], [2, 4095, 3], [6, 4095, 120000], [7, 4095, 1]], ""],
	["state-edge-1-3-1-120999", "sown", [[1, 4095, 1], [2, 4095, 3], [6, 4095, 120999], [7, 4095, 1]], ""],
	["state-edge-1-3-1-121000", "sown", [[1, 4095, 1], [2, 4095, 3], [6, 4095, 121000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-1-4-0-119999", "sown", [[1, 4095, 1], [2, 4095, 4], [6, 4095, 119999], [7, 4095, 0]], ""],
	["state-edge-1-4-0-120000", "sown", [[1, 4095, 1], [2, 4095, 4], [6, 4095, 120000], [7, 4095, 0]], "COLUMN_STATE"],
	["state-edge-1-4-1-120000", "sown", [[1, 4095, 1], [2, 4095, 4], [6, 4095, 120000], [7, 4095, 1]], ""],
	["state-edge-1-4-1-119999", "sown", [[1, 4095, 1], [2, 4095, 4], [6, 4095, 119999], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-2-2-1-167999", "sown", [[1, 4095, 2], [2, 4095, 2], [6, 4095, 167999], [7, 4095, 1]], ""],
	["state-edge-2-2-1-168000", "sown", [[1, 4095, 2], [2, 4095, 2], [6, 4095, 168000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-2-3-1-168000", "sown", [[1, 4095, 2], [2, 4095, 3], [6, 4095, 168000], [7, 4095, 1]], ""],
	["state-edge-2-3-1-168999", "sown", [[1, 4095, 2], [2, 4095, 3], [6, 4095, 168999], [7, 4095, 1]], ""],
	["state-edge-2-3-1-169000", "sown", [[1, 4095, 2], [2, 4095, 3], [6, 4095, 169000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-2-4-0-167999", "sown", [[1, 4095, 2], [2, 4095, 4], [6, 4095, 167999], [7, 4095, 0]], ""],
	["state-edge-2-4-0-168000", "sown", [[1, 4095, 2], [2, 4095, 4], [6, 4095, 168000], [7, 4095, 0]], "COLUMN_STATE"],
	["state-edge-2-4-1-168000", "sown", [[1, 4095, 2], [2, 4095, 4], [6, 4095, 168000], [7, 4095, 1]], ""],
	["state-edge-2-4-1-167999", "sown", [[1, 4095, 2], [2, 4095, 4], [6, 4095, 167999], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-3-2-1-191999", "sown", [[1, 4095, 3], [2, 4095, 2], [6, 4095, 191999], [7, 4095, 1]], ""],
	["state-edge-3-2-1-192000", "sown", [[1, 4095, 3], [2, 4095, 2], [6, 4095, 192000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-3-3-1-192000", "sown", [[1, 4095, 3], [2, 4095, 3], [6, 4095, 192000], [7, 4095, 1]], ""],
	["state-edge-3-3-1-192999", "sown", [[1, 4095, 3], [2, 4095, 3], [6, 4095, 192999], [7, 4095, 1]], ""],
	["state-edge-3-3-1-193000", "sown", [[1, 4095, 3], [2, 4095, 3], [6, 4095, 193000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-3-4-0-191999", "sown", [[1, 4095, 3], [2, 4095, 4], [6, 4095, 191999], [7, 4095, 0]], ""],
	["state-edge-3-4-0-192000", "sown", [[1, 4095, 3], [2, 4095, 4], [6, 4095, 192000], [7, 4095, 0]], "COLUMN_STATE"],
	["state-edge-3-4-1-192000", "sown", [[1, 4095, 3], [2, 4095, 4], [6, 4095, 192000], [7, 4095, 1]], ""],
	["state-edge-3-4-1-191999", "sown", [[1, 4095, 3], [2, 4095, 4], [6, 4095, 191999], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-4-2-1-119999", "sown", [[1, 4095, 4], [2, 4095, 2], [6, 4095, 119999], [7, 4095, 1]], ""],
	["state-edge-4-2-1-120000", "sown", [[1, 4095, 4], [2, 4095, 2], [6, 4095, 120000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-4-3-1-120000", "sown", [[1, 4095, 4], [2, 4095, 3], [6, 4095, 120000], [7, 4095, 1]], ""],
	["state-edge-4-3-1-120999", "sown", [[1, 4095, 4], [2, 4095, 3], [6, 4095, 120999], [7, 4095, 1]], ""],
	["state-edge-4-3-1-121000", "sown", [[1, 4095, 4], [2, 4095, 3], [6, 4095, 121000], [7, 4095, 1]], "COLUMN_STATE"],
	["state-edge-4-4-0-119999", "sown", [[1, 4095, 4], [2, 4095, 4], [6, 4095, 119999], [7, 4095, 0]], ""],
	["state-edge-4-4-0-120000", "sown", [[1, 4095, 4], [2, 4095, 4], [6, 4095, 120000], [7, 4095, 0]], "COLUMN_STATE"],
	["state-edge-4-4-1-120000", "sown", [[1, 4095, 4], [2, 4095, 4], [6, 4095, 120000], [7, 4095, 1]], ""],
	["state-edge-4-4-1-119999", "sown", [[1, 4095, 4], [2, 4095, 4], [6, 4095, 119999], [7, 4095, 1]], "COLUMN_STATE"]
]

func _put(c: Owner.Columns, field: int, row: int, value: int) -> void:
	var values: Variant = c.get(FIELDS[field])
	values[row] = value
	c.set(FIELDS[field],values)

func _snapshot(c: Owner.Columns) -> Array:
	var out: Array = []
	for key: String in FIELDS: out.append(c.get(key).duplicate())
	return out

func _frame(c: Owner.Columns) -> Section.FramedOwner:
	var f: Section.FramedOwner = Section.FramedOwner.new(2)
	for field: int in 15:
		var ok: bool
		if TYPES[field] == 0: ok = f.set_u8(field,c.get(FIELDS[field]))
		elif TYPES[field] == 2: ok = f.set_i32(field,c.get(FIELDS[field]))
		else: ok = f.set_i64(field,c.get(FIELDS[field]))
		assert_true(ok,"typed canonical setter")
	return f

func _image(name: String) -> Owner.Columns:
	var c: Owner.Columns = Owner.Columns.new()
	var values: Dictionary = FIXTURES[name]
	for key: String in values: _put(c,FIELDS.find(key),4095,int(values[key]))
	return c

func _expect(c: Owner.Columns, code: StringName, label: String) -> void:
	var before: Array = _snapshot(c)
	var f: Section.FramedOwner = _frame(c)
	assert_equal(Owner.columns_refusal(c),code,label+" pure")
	var result: Variant = Bridge.framed_refusal(f)
	assert_equal(result.code,code,label+" bridge")
	assert_equal(result.is_ok(),code == &"",label+" success")
	if code == &"": assert_equal(result.detail,"",label+" success detail")
	else:
		assert_true(result.detail.contains("Farming owner 2 "),label+" owner detail")
		assert_true(result.detail.contains(String(code)),label+" raw code detail")
	for field: int in 15:
		assert_true(c.get(FIELDS[field]) == before[field],label+" original unchanged")
		var held: Variant
		if TYPES[field] == 0: held = f.u8_column(field)
		elif TYPES[field] == 2: held = f.i32_column(field)
		else: held = f.i64_column(field)
		assert_true(held == before[field],label+" framed unchanged")

func test_layout_clear_defaults_and_conditional_packed_budget() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	_expect(c,&"","clear")
	assert_equal(Schema.owner_version(2),1,"version")
	assert_equal(Schema.primary_count(2),4096,"primary")
	assert_equal(Schema.child_extent_count(2),0,"no child")
	assert_equal(Schema.field_count(2),15,"fields")
	var value_bytes: int = 0
	for field: int in 15:
		assert_equal(Schema.field_key(2,field),"_"+FIELDS[field],"canonical key")
		assert_equal(Schema.field_type(2,field),TYPES[field],"canonical type")
		assert_equal(Schema.element_count(2,field),4096,"all physical rows")
		var expected: int = -1 if field in [1,8,12,13] else 0
		assert_equal(c.get(FIELDS[field]).count(expected),4096,"clear default")
		value_bytes += 4096*(1 if TYPES[field] == 0 else 4 if TYPES[field] == 2 else 8)
	assert_equal(value_bytes,266240,"value bytes")
	assert_equal(2*value_bytes+2*4096*4,565248,"conservative packed budget, not RSS")

func test_frozen_domains_states_history_and_projection_witnesses() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,int(change[0]),int(change[1]),int(change[2]))
		_expect(c,StringName(item[3]),item[0])

func test_null_all_extents_and_physical_bucket_shapes() -> void:
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","pure null")
	assert_equal(Bridge.framed_refusal(null).code,Section.REFUSE_SHAPE,"bridge null")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(3)).code,Section.REFUSE_OWNER,"wrong owner")
	for field: int in 15:
		for count: int in [0,4095,4097]:
			var c: Owner.Columns = Owner.Columns.new()
			var values: Variant = c.get(FIELDS[field]).duplicate()
			values.resize(count)
			c.set(FIELDS[field],values)
			if field == 0: c.soil[0] = 3
			else: c.present[0] = 2
			var before: Array = _snapshot(c)
			assert_equal(Owner.columns_refusal(c),&"COLUMN_SHAPE","shape before values")
			for key: int in 15: assert_true(c.get(FIELDS[key]) == before[key],"shape refusal unchanged")
	for bucket: int in 3:
		for delta: int in [-1,1]:
			var frame: Section.FramedOwner = _frame(Owner.Columns.new())
			if bucket == 0: frame.u8_columns.resize(frame.u8_columns.size()+delta)
			elif bucket == 1: frame.i32_columns.resize(frame.i32_columns.size()+delta)
			else: frame.i64_columns.resize(frame.i64_columns.size()+delta)
			var expected: Variant = Section.owner_shape_refusal(frame)
			var actual: Variant = Bridge.framed_refusal(frame)
			assert_equal(actual.code,expected.code,"shape code forwarded")
			assert_equal(actual.detail,expected.detail,"shape detail forwarded")
			assert_false(actual.is_ok(),"bad bucket refused")

func test_every_physical_row_and_every_column_at_head_and_tail() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var original: Array = _snapshot(c)
	var bad: Array[int] = [2,-2,5,3,-1,-1,-1,-1,-2,-1,1,-1,-2,-2,-1]
	var codes: Array[StringName] = [&"COLUMN_PRESENT",&"COLUMN_ENUM",&"COLUMN_ENUM",&"COLUMN_ENUM",&"COLUMN_VALUE",&"COLUMN_VALUE",&"COLUMN_VALUE",&"COLUMN_VALUE",&"COLUMN_HISTORY",&"COLUMN_HISTORY",&"COLUMN_VALUE",&"COLUMN_VALUE",&"COLUMN_IDENTITY",&"COLUMN_IDENTITY",&"COLUMN_IDENTITY"]
	# Every physical row, varying fault column. This is not a15x4096Cartesian campaign.
	for row: int in 4096:
		var field: int = row % 15
		_put(c,field,row,bad[field])
		assert_equal(Owner.columns_refusal(c),codes[field],"physical row%d field%d" % [row,field])
		assert_equal(int(c.get(FIELDS[field])[row]),bad[field],"fault preserved")
		_put(c,field,row,-1 if field in [1,8,12,13] else 0)
	for field: int in 15:
		for row: int in [0,4095]:
			_put(c,field,row,bad[field])
			assert_equal(Owner.columns_refusal(c),codes[field],"every field at both physical edges")
			_put(c,field,row,-1 if field in [1,8,12,13] else 0)
	for field: int in 15: assert_true(c.get(FIELDS[field]) == original[field],"all restored bytes unchanged")
	assert_equal(Owner.columns_refusal(c),&"","restored clear")

func test_full_capacity_unique_identity_and_duplicate_priority() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	c.present.fill(1)
	c.health.fill(10000)
	c.ref_generation.fill(1)
	for row: int in 4096:
		c.tile[row] = row
		c.ref_slot[row] = row
	_expect(c,&"","all4096present with unique identities")
	c.tile[4095] = 0
	_expect(c,&"COLUMN_DUPLICATE_TILE","head/tail tile collision")
	c.ref_slot[4095] = 0
	c.ref_generation[4095] = 2147483647
	_expect(c,&"COLUMN_DUPLICATE_TILE","tile duplicate precedes ref duplicate")
	c.tile[4095] = 4095
	_expect(c,&"COLUMN_DUPLICATE_REF","one slot cannot hold two current generations")
	c.ref_slot[4095] = 4095
	_expect(c,&"","restored unique allrows")

func test_retained_inactive_extremes_across_all_physical_rows() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	c.growth_milli_hours.fill(9223372036854775807)
	c.sow_day.fill(2147483647)
	c.last_family.fill(4)
	c.family_streak.fill(2147483647)
	c.compost_milli.fill(2000)
	c.health.fill(10000)
	c.moisture.fill(10000)
	c.fertility.fill(10000)
	c.soil.fill(2)
	_expect(c,&"","inactive broad history is not normalized")
	c.last_family[4095] = -1
	_expect(c,&"COLUMN_HISTORY","retained family/count consistency applies to inactive")

func test_present_history_and_compost_endpoints_are_accepted() -> void:
	for family: int in range(-1,5):
		var c: Owner.Columns = _image("sown")
		c.last_family[4095] = family
		c.family_streak[4095] = 0 if family == -1 else 2147483647
		c.compost_milli[4095] = 2000
		c.fertility[4095] = 0
		c.moisture[4095] = 10000
		c.sow_day[4095] = 2147483647
		_expect(c,&"","present history and commodity endpoints")
