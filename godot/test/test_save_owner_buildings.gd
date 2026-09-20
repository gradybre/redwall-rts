extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/buildings.gd")
const Bridge := preload("res://scripts/core/save_owner_buildings.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[String] = ["b_present", "r_present", "f_present", "b_type_id", "b_tier", "b_origin_tile", "b_rotation", "b_state", "b_condition", "b_construction_slot", "b_construction_generation", "b_interior_id", "r_type", "r_building_slot", "r_building_generation", "r_tile_offset", "r_tile_count", "r_temperature_tenths", "r_furniture_mask", "r_occupants", "r_valid", "f_type_id", "f_room_slot", "f_room_generation", "f_origin_tile", "f_rotation", "f_user_slot", "f_user_generation", "f_condition"]
const TYPES: Array[int] = [0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2]
const COUNTS: Array[int] = [1024, 16384, 81920, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 16384, 16384, 16384, 16384, 16384, 16384, 16384, 16384, 16384, 81920, 81920, 81920, 81920, 81920, 81920, 81920, 81920]
const BUILDING_X: Array[int] = [3, 6, 5, 6, 3, 6, 1, 4, 1, 4, 4, 2, 12, 8, 6, 2, 4, 5, 4, 4, 1, 5, 4, 10, 4, 1, 4, 2, 3, 6]
const BUILDING_Z: Array[int] = [3, 4, 4, 6, 3, 6, 1, 3, 1, 3, 4, 1, 10, 8, 6, 2, 4, 5, 4, 4, 1, 4, 4, 8, 4, 1, 2, 2, 3, 6]
const FURNITURE_X: Array[int] = [1, 1, 2, 0, 0, 2, 1, 1, 1]
const FURNITURE_Z: Array[int] = [1, 1, 1, 0, 0, 1, 1, 1, 1]
const CASES: Array = [
	["accept-clear", "clear", [], ""],
	["accept-building", "building", [], ""],
	["accept-retired-building", "retired-building", [], ""],
	["accept-room", "room", [], ""],
	["accept-retired-room", "retired-room", [], ""],
	["accept-furniture", "furniture", [], ""],
	["accept-retired-furniture", "retired-furniture", [], ""],
	["clear-b_present-2", "clear", [["b_present", 1023, 2]], "COLUMN_FLAG"],
	["clear-b_present-255", "clear", [["b_present", 1023, 255]], "COLUMN_FLAG"],
	["clear-r_present-2", "clear", [["r_present", 16383, 2]], "COLUMN_FLAG"],
	["clear-r_present-255", "clear", [["r_present", 16383, 255]], "COLUMN_FLAG"],
	["clear-f_present-2", "clear", [["f_present", 81919, 2]], "COLUMN_FLAG"],
	["clear-f_present-255", "clear", [["f_present", 81919, 255]], "COLUMN_FLAG"],
	["clear-r_valid-2", "clear", [["r_valid", 16383, 2]], "COLUMN_FLAG"],
	["clear-r_valid-255", "clear", [["r_valid", 16383, 255]], "COLUMN_FLAG"],
	["building-b_type_id--1", "building", [["b_type_id", 0, -1]], "COLUMN_BUILDING_ENUM"],
	["building-b_type_id-30", "building", [["b_type_id", 0, 30]], "COLUMN_BUILDING_ENUM"],
	["building-b_tier--1", "building", [["b_tier", 0, -1]], "COLUMN_BUILDING_ENUM"],
	["building-b_tier-3", "building", [["b_tier", 0, 3]], "COLUMN_BUILDING_ENUM"],
	["building-b_rotation--1", "building", [["b_rotation", 0, -1]], "COLUMN_BUILDING_ENUM"],
	["building-b_rotation-4", "building", [["b_rotation", 0, 4]], "COLUMN_BUILDING_ENUM"],
	["building-b_state--1", "building", [["b_state", 0, -1]], "COLUMN_BUILDING_ENUM"],
	["building-b_state-6", "building", [["b_state", 0, 6]], "COLUMN_BUILDING_ENUM"],
	["building-b_origin_tile--2", "building", [["b_origin_tile", 0, -2]], "COLUMN_BUILDING_VALUE"],
	["building-b_origin_tile-16384", "building", [["b_origin_tile", 0, 16384]], "COLUMN_BUILDING_VALUE"],
	["building-b_condition--1", "building", [["b_condition", 0, -1]], "COLUMN_BUILDING_VALUE"],
	["building-b_interior_id--2", "building", [["b_interior_id", 0, -2]], "COLUMN_BUILDING_VALUE"],
	["building-b_condition-2147483647", "building", [["b_condition", 0, 2147483647]], ""],
	["building-b_interior_id-2147483647", "building", [["b_interior_id", 0, 2147483647]], ""],
	["building-b_construction-ref--2-0", "building", [["b_construction_slot", 0, -2], ["b_construction_generation", 0, 0]], "COLUMN_BUILDING_REF"],
	["building-b_construction-ref-352418-1", "building", [["b_construction_slot", 0, 352418], ["b_construction_generation", 0, 1]], "COLUMN_BUILDING_REF"],
	["building-b_construction-ref--1-1", "building", [["b_construction_slot", 0, -1], ["b_construction_generation", 0, 1]], "COLUMN_BUILDING_REF"],
	["building-b_construction-ref-0-0", "building", [["b_construction_slot", 0, 0], ["b_construction_generation", 0, 0]], "COLUMN_BUILDING_REF"],
	["building-b_construction-ref-0--1", "building", [["b_construction_slot", 0, 0], ["b_construction_generation", 0, -1]], "COLUMN_BUILDING_REF"],
	["building-b_construction-max-ref", "building", [["b_construction_slot", 0, 352417], ["b_construction_generation", 0, 2147483647]], ""],
	["room-r_building-ref--2-0", "room", [["r_building_slot", 0, -2], ["r_building_generation", 0, 0]], "COLUMN_ROOM_REF"],
	["room-r_building-ref-352418-1", "room", [["r_building_slot", 0, 352418], ["r_building_generation", 0, 1]], "COLUMN_ROOM_REF"],
	["room-r_building-ref--1-1", "room", [["r_building_slot", 0, -1], ["r_building_generation", 0, 1]], "COLUMN_ROOM_REF"],
	["room-r_building-ref-0-0", "room", [["r_building_slot", 0, 0], ["r_building_generation", 0, 0]], "COLUMN_ROOM_REF"],
	["room-r_building-ref-0--1", "room", [["r_building_slot", 0, 0], ["r_building_generation", 0, -1]], "COLUMN_ROOM_REF"],
	["room-r_building-max-ref", "room", [["r_building_slot", 0, 352417], ["r_building_generation", 0, 2147483647]], ""],
	["furniture-f_room-ref--2-0", "furniture", [["f_room_slot", 0, -2], ["f_room_generation", 0, 0]], "COLUMN_FURNITURE_REF"],
	["furniture-f_room-ref-352418-1", "furniture", [["f_room_slot", 0, 352418], ["f_room_generation", 0, 1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_room-ref--1-1", "furniture", [["f_room_slot", 0, -1], ["f_room_generation", 0, 1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_room-ref-0-0", "furniture", [["f_room_slot", 0, 0], ["f_room_generation", 0, 0]], "COLUMN_FURNITURE_REF"],
	["furniture-f_room-ref-0--1", "furniture", [["f_room_slot", 0, 0], ["f_room_generation", 0, -1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_room-max-ref", "furniture", [["f_room_slot", 0, 352417], ["f_room_generation", 0, 2147483647]], ""],
	["furniture-f_user-ref--2-0", "furniture", [["f_user_slot", 0, -2], ["f_user_generation", 0, 0]], "COLUMN_FURNITURE_REF"],
	["furniture-f_user-ref-352418-1", "furniture", [["f_user_slot", 0, 352418], ["f_user_generation", 0, 1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_user-ref--1-1", "furniture", [["f_user_slot", 0, -1], ["f_user_generation", 0, 1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_user-ref-0-0", "furniture", [["f_user_slot", 0, 0], ["f_user_generation", 0, 0]], "COLUMN_FURNITURE_REF"],
	["furniture-f_user-ref-0--1", "furniture", [["f_user_slot", 0, 0], ["f_user_generation", 0, -1]], "COLUMN_FURNITURE_REF"],
	["furniture-f_user-max-ref", "furniture", [["f_user_slot", 0, 352417], ["f_user_generation", 0, 2147483647]], ""],
	["clear-b_type_id-1", "clear", [["b_type_id", 0, 1]], "COLUMN_BUILDING_FREE"],
	["clear-b_origin_tile-0", "clear", [["b_origin_tile", 0, 0]], "COLUMN_BUILDING_FREE"],
	["clear-b_rotation-1", "clear", [["b_rotation", 0, 1]], "COLUMN_BUILDING_FREE"],
	["clear-b_state-1", "clear", [["b_state", 0, 1]], "COLUMN_BUILDING_FREE"],
	["clear-b_condition-1", "clear", [["b_condition", 0, 1]], "COLUMN_BUILDING_FREE"],
	["clear-b_interior_id-0", "clear", [["b_interior_id", 0, 0]], "COLUMN_BUILDING_FREE"],
	["clear-building-nonnull-construction", "clear", [["b_construction_slot", 0, 0], ["b_construction_generation", 0, 1]], "COLUMN_BUILDING_FREE"],
	["building-b_tier-0", "building", [["b_tier", 0, 0]], "COLUMN_BUILDING_STATE"],
	["tier2-type-0", "building", [["b_type_id", 0, 0], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-1", "building", [["b_type_id", 0, 1], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-2", "building", [["b_type_id", 0, 2], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-3", "building", [["b_type_id", 0, 3], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-4", "building", [["b_type_id", 0, 4], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-5", "building", [["b_type_id", 0, 5], ["b_tier", 0, 2]], ""],
	["tier2-type-6", "building", [["b_type_id", 0, 6], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-7", "building", [["b_type_id", 0, 7], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-8", "building", [["b_type_id", 0, 8], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-9", "building", [["b_type_id", 0, 9], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-10", "building", [["b_type_id", 0, 10], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-11", "building", [["b_type_id", 0, 11], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-12", "building", [["b_type_id", 0, 12], ["b_tier", 0, 2]], ""],
	["tier2-type-13", "building", [["b_type_id", 0, 13], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-14", "building", [["b_type_id", 0, 14], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-15", "building", [["b_type_id", 0, 15], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-16", "building", [["b_type_id", 0, 16], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-17", "building", [["b_type_id", 0, 17], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-18", "building", [["b_type_id", 0, 18], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-19", "building", [["b_type_id", 0, 19], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-20", "building", [["b_type_id", 0, 20], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-21", "building", [["b_type_id", 0, 21], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-22", "building", [["b_type_id", 0, 22], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-23", "building", [["b_type_id", 0, 23], ["b_tier", 0, 2]], ""],
	["tier2-type-24", "building", [["b_type_id", 0, 24], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-25", "building", [["b_type_id", 0, 25], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-26", "building", [["b_type_id", 0, 26], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-27", "building", [["b_type_id", 0, 27], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-28", "building", [["b_type_id", 0, 28], ["b_tier", 0, 2]], "COLUMN_BUILDING_STATE"],
	["tier2-type-29", "building", [["b_type_id", 0, 29], ["b_tier", 0, 2]], ""],
	["hall-edge-fit-rot0", "building", [["b_rotation", 0, 0], ["b_origin_tile", 0, 15220]], ""],
	["hall-offmap-x-rot0", "building", [["b_rotation", 0, 0], ["b_origin_tile", 0, 15221]], "COLUMN_BUILDING_STATE"],
	["hall-offmap-z-rot0", "building", [["b_rotation", 0, 0], ["b_origin_tile", 0, 15348]], "COLUMN_BUILDING_STATE"],
	["hall-edge-fit-rot1", "building", [["b_rotation", 0, 1], ["b_origin_tile", 0, 14966]], ""],
	["hall-offmap-x-rot1", "building", [["b_rotation", 0, 1], ["b_origin_tile", 0, 14967]], "COLUMN_BUILDING_STATE"],
	["hall-offmap-z-rot1", "building", [["b_rotation", 0, 1], ["b_origin_tile", 0, 15094]], "COLUMN_BUILDING_STATE"],
	["hall-edge-fit-rot2", "building", [["b_rotation", 0, 2], ["b_origin_tile", 0, 15220]], ""],
	["hall-offmap-x-rot2", "building", [["b_rotation", 0, 2], ["b_origin_tile", 0, 15221]], "COLUMN_BUILDING_STATE"],
	["hall-offmap-z-rot2", "building", [["b_rotation", 0, 2], ["b_origin_tile", 0, 15348]], "COLUMN_BUILDING_STATE"],
	["hall-edge-fit-rot3", "building", [["b_rotation", 0, 3], ["b_origin_tile", 0, 14966]], ""],
	["hall-offmap-x-rot3", "building", [["b_rotation", 0, 3], ["b_origin_tile", 0, 14967]], "COLUMN_BUILDING_STATE"],
	["hall-offmap-z-rot3", "building", [["b_rotation", 0, 3], ["b_origin_tile", 0, 15094]], "COLUMN_BUILDING_STATE"],
	["one-tile-building-final-tile", "building", [["b_type_id", 0, 6], ["b_origin_tile", 0, 16383]], ""],
	["retired-building-b_tier-0", "retired-building", [["b_tier", 0, 0]], "COLUMN_BUILDING_FREE"],
	["room-r_type--1", "room", [["r_type", 0, -1]], "COLUMN_ROOM_ENUM"],
	["room-r_type-8", "room", [["r_type", 0, 8]], "COLUMN_ROOM_ENUM"],
	["room-r_tile_offset--1", "room", [["r_tile_offset", 0, -1]], "COLUMN_ROOM_VALUE"],
	["room-r_tile_offset-16385", "room", [["r_tile_offset", 0, 16385]], "COLUMN_ROOM_VALUE"],
	["room-r_tile_count--1", "room", [["r_tile_count", 0, -1]], "COLUMN_ROOM_VALUE"],
	["room-r_tile_count-16385", "room", [["r_tile_count", 0, 16385]], "COLUMN_ROOM_VALUE"],
	["room-r_furniture_mask--1", "room", [["r_furniture_mask", 0, -1]], "COLUMN_ROOM_VALUE"],
	["room-r_furniture_mask-512", "room", [["r_furniture_mask", 0, 512]], "COLUMN_ROOM_VALUE"],
	["room-r_occupants--1", "room", [["r_occupants", 0, -1]], "COLUMN_ROOM_VALUE"],
	["room-r_occupants-257", "room", [["r_occupants", 0, 257]], "COLUMN_ROOM_VALUE"],
	["room-r_temperature_tenths--2147483648", "room", [["r_temperature_tenths", 0, -2147483648]], ""],
	["room-r_temperature_tenths-2147483647", "room", [["r_temperature_tenths", 0, 2147483647]], ""],
	["room-r_occupants-256", "room", [["r_occupants", 0, 256]], ""],
	["room-r_furniture_mask-511", "room", [["r_furniture_mask", 0, 511]], ""],
	["room-r_valid-1", "room", [["r_valid", 0, 1]], ""],
	["present-room-null-parent", "room", [["r_building_slot", 0, -1], ["r_building_generation", 0, 0]], "COLUMN_ROOM_STATE"],
	["room-r_tile_count-0", "room", [["r_tile_count", 0, 0]], "COLUMN_ROOM_STATE"],
	["room-r_tile_offset-16384", "room", [["r_tile_offset", 0, 16384]], "COLUMN_ROOM_STATE"],
	["room-r_tile_offset-16383", "room", [["r_tile_offset", 0, 16383]], ""],
	["local-span-whole-arena-not-whole-world-acceptance", "room", [["r_tile_count", 0, 16384]], ""],
	["retired-room-r_tile_offset-1", "retired-room", [["r_tile_offset", 0, 1]], "COLUMN_ROOM_FREE"],
	["retired-room-r_tile_count-1", "retired-room", [["r_tile_count", 0, 1]], "COLUMN_ROOM_FREE"],
	["retired-room-r_furniture_mask-1", "retired-room", [["r_furniture_mask", 0, 1]], "COLUMN_ROOM_FREE"],
	["retired-room-r_valid-1", "retired-room", [["r_valid", 0, 1]], "COLUMN_ROOM_FREE"],
	["clear-r_type-1", "clear", [["r_type", 0, 1]], "COLUMN_ROOM_FREE"],
	["clear-r_temperature_tenths-1", "clear", [["r_temperature_tenths", 0, 1]], "COLUMN_ROOM_FREE"],
	["clear-r_occupants-1", "clear", [["r_occupants", 0, 1]], "COLUMN_ROOM_FREE"],
	["retired-room-keeps-history", "retired-room", [["r_type", 0, 7], ["r_temperature_tenths", 0, -2147483648], ["r_occupants", 0, 256]], ""],
	["furniture-f_type_id--1", "furniture", [["f_type_id", 0, -1]], "COLUMN_FURNITURE_ENUM"],
	["furniture-f_type_id-9", "furniture", [["f_type_id", 0, 9]], "COLUMN_FURNITURE_ENUM"],
	["furniture-f_rotation--1", "furniture", [["f_rotation", 0, -1]], "COLUMN_FURNITURE_ENUM"],
	["furniture-f_rotation-4", "furniture", [["f_rotation", 0, 4]], "COLUMN_FURNITURE_ENUM"],
	["furniture-f_origin_tile--2", "furniture", [["f_origin_tile", 0, -2]], "COLUMN_FURNITURE_VALUE"],
	["furniture-f_origin_tile-16384", "furniture", [["f_origin_tile", 0, 16384]], "COLUMN_FURNITURE_VALUE"],
	["furniture-f_condition--1", "furniture", [["f_condition", 0, -1]], "COLUMN_FURNITURE_VALUE"],
	["furniture-f_condition-2147483647", "furniture", [["f_condition", 0, 2147483647]], ""],
	["present-furniture-null-room", "furniture", [["f_room_slot", 0, -1], ["f_room_generation", 0, 0]], "COLUMN_FURNITURE_STATE"],
	["retired-furniture-user-forbidden", "retired-furniture", [["f_user_slot", 0, 0], ["f_user_generation", 0, 1]], "COLUMN_FURNITURE_FREE"],
	["clear-f_type_id-1", "clear", [["f_type_id", 0, 1]], "COLUMN_FURNITURE_FREE"],
	["clear-f_origin_tile-0", "clear", [["f_origin_tile", 0, 0]], "COLUMN_FURNITURE_FREE"],
	["clear-f_rotation-1", "clear", [["f_rotation", 0, 1]], "COLUMN_FURNITURE_FREE"],
	["clear-f_condition-1", "clear", [["f_condition", 0, 1]], "COLUMN_FURNITURE_FREE"],
	["retired-furniture-f_origin_tile--1", "retired-furniture", [["f_origin_tile", 0, -1]], "COLUMN_FURNITURE_STATE"],
	["edge-furniture-3-rot0", "furniture", [["f_type_id", 0, 3], ["f_rotation", 0, 0], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-3-rot1", "furniture", [["f_type_id", 0, 3], ["f_rotation", 0, 1], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-3-rot2", "furniture", [["f_type_id", 0, 3], ["f_rotation", 0, 2], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-3-rot3", "furniture", [["f_type_id", 0, 3], ["f_rotation", 0, 3], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-4-rot0", "furniture", [["f_type_id", 0, 4], ["f_rotation", 0, 0], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-4-rot1", "furniture", [["f_type_id", 0, 4], ["f_rotation", 0, 1], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-4-rot2", "furniture", [["f_type_id", 0, 4], ["f_rotation", 0, 2], ["f_origin_tile", 0, 16383]], ""],
	["edge-furniture-4-rot3", "furniture", [["f_type_id", 0, 4], ["f_rotation", 0, 3], ["f_origin_tile", 0, 16383]], ""],
	["hearth-offmap", "furniture", [["f_type_id", 0, 2], ["f_origin_tile", 0, 127]], "COLUMN_FURNITURE_STATE"],
	["rotated-hearth-fits", "furniture", [["f_type_id", 0, 2], ["f_origin_tile", 0, 127], ["f_rotation", 0, 1]], ""],
	["zero-user-slots-type1", "furniture", [["f_type_id", 0, 1], ["f_user_slot", 0, 352417], ["f_user_generation", 0, 2147483647]], ""],
	["zero-user-slots-type4", "furniture", [["f_type_id", 0, 4], ["f_user_slot", 0, 352417], ["f_user_generation", 0, 2147483647]], ""],
	["later-flag-before-building-enum", "building", [["b_type_id", 0, 30], ["f_present", 81919, 2]], "COLUMN_FLAG"],
	["building-before-room", "clear", [["b_type_id", 0, 30], ["r_type", 0, 8]], "COLUMN_BUILDING_ENUM"],
	["room-before-furniture", "clear", [["r_type", 0, 8], ["f_type_id", 0, 9]], "COLUMN_ROOM_ENUM"],
	["earlier-building-row-before-later-enum", "clear", [["b_condition", 0, -1], ["b_type_id", 1023, 30]], "COLUMN_BUILDING_VALUE"],
	["building-enum-before-value", "building", [["b_type_id", 0, -1], ["b_condition", 0, -1]], "COLUMN_BUILDING_ENUM"],
	["building-value-before-reference", "building", [["b_condition", 0, -1], ["b_construction_slot", 0, -2]], "COLUMN_BUILDING_VALUE"],
	["room-enum-before-value", "room", [["r_type", 0, -1], ["r_occupants", 0, -1]], "COLUMN_ROOM_ENUM"],
	["room-value-before-reference", "room", [["r_occupants", 0, -1], ["r_building_slot", 0, -2]], "COLUMN_ROOM_VALUE"],
	["furniture-enum-before-value", "furniture", [["f_type_id", 0, -1], ["f_condition", 0, -1]], "COLUMN_FURNITURE_ENUM"],
	["furniture-value-before-reference", "furniture", [["f_condition", 0, -1], ["f_room_slot", 0, -2]], "COLUMN_FURNITURE_VALUE"],
	["retired-building-keeps-nonnull-construction", "retired-building", [["b_construction_slot", 0, 352417], ["b_construction_generation", 0, 2147483647]], ""]
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
	var f: Section.FramedOwner = Section.FramedOwner.new(0)
	for field: int in 29:
		if TYPES[field] == 0: assert(f.set_u8(field,c.get(FIELDS[field])))
		else: assert(f.set_i32(field,c.get(FIELDS[field])))
	return f
func _building(c: Owner.Columns, row: int, retired: bool = false) -> void:
	c.b_present[row] = 0 if retired else 1
	c.b_type_id[row] = 12
	c.b_tier[row] = 1
	c.b_origin_tile[row] = 0
func _room(c: Owner.Columns, row: int, retired: bool = false) -> void:
	c.r_present[row] = 0 if retired else 1
	c.r_building_slot[row] = 0
	c.r_building_generation[row] = 1
	c.r_tile_count[row] = 0 if retired else 1
func _furniture(c: Owner.Columns, row: int, retired: bool = false) -> void:
	c.f_present[row] = 0 if retired else 1
	c.f_room_slot[row] = 0
	c.f_room_generation[row] = 1
	c.f_origin_tile[row] = 0
func _image(name: String) -> Owner.Columns:
	var c: Owner.Columns = Owner.Columns.new()
	if name == "clear": return c
	if name.ends_with("building"): _building(c,0,name.begins_with("retired"))
	elif name.ends_with("room"): _room(c,0,name.begins_with("retired"))
	else: _furniture(c,0,name.begins_with("retired"))
	return c
func _expect(c: Owner.Columns, code: StringName, label: String) -> void:
	var before: Array = _snapshot(c)
	var f: Section.FramedOwner = _frame(c)
	assert_equal(Owner.columns_refusal(c),code,label+" pure")
	var actual: Variant = Bridge.framed_refusal(f)
	assert_equal(actual.code,code,label+" bridge")
	assert_equal(actual.is_ok(),code == &"",label+" success")
	if code == &"": assert_equal(actual.detail,"",label+" empty success detail")
	else:
		assert_true(actual.detail.contains("Buildings owner 0 "),label+" owner detail")
		assert_true(actual.detail.contains(String(code)),label+" raw code detail")
	for field: int in 29:
		assert_true(c.get(FIELDS[field]) == before[field],label+" input unchanged")
		var held: Variant = f.u8_column(field) if TYPES[field] == 0 else f.i32_column(field)
		assert_true(held == before[field],label+" frame unchanged")
func test_layout_defaults_and_borrowed_constructor() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	_expect(c,&"","clear")
	var borrowed: Owner.Columns = Owner.Columns.new(false)
	assert_false(borrowed.is_sized(),"unbound borrowed view is not a valid image")
	assert_equal(Owner.columns_refusal(borrowed),&"COLUMN_SHAPE","empty view refuses before indexing")
	assert_equal(Schema.primary_count(0),1024,"primary buildings only")
	assert_equal(Schema.child_extent_count(0),2,"two child groups")
	assert_equal(Schema.child_extent(0,0),16384,"rooms")
	assert_equal(Schema.child_extent(0,1),81920,"furniture")
	assert_equal(Schema.field_count(0),29,"fields")
	var values: int = 0
	for field: int in 29:
		assert_equal(Schema.field_key(0,field),"_"+FIELDS[field],"canonical key")
		assert_equal(Schema.field_type(0,field),TYPES[field],"canonical type")
		assert_equal(Schema.element_count(0,field),COUNTS[field],"canonical count")
		assert_equal(c.get(FIELDS[field]).count(-1 if field in [5,9,11,13,22,24,26] else 0),COUNTS[field],"clear defaults")
		assert_equal(borrowed.get(FIELDS[field]).size(),0,"borrowed constructor allocates no packed rows")
		values += COUNTS[field]*(1 if TYPES[field] == 0 else 4)
	assert_equal(values,3298304,"value bytes")
	assert_equal(values+2*327680+3*65536,4150272,"borrowed logical envelope before native cost")
	assert_true(2*values > 6417408,"a full second image violates allowance")
func test_frozen_scalar_history_geometry_and_priority_images() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,FIELDS.find(change[0]),int(change[1]),int(change[2]))
		_expect(c,StringName(item[3]),item[0])
func test_null_unallocated_all_extents_and_bucket_shapes() -> void:
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","pure null")
	assert_equal(Bridge.framed_refusal(null).code,Section.REFUSE_SHAPE,"bridge null")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(1)).code,Section.REFUSE_OWNER,"wrong owner")
	for field: int in 29:
		for count: int in [0,COUNTS[field]-1,COUNTS[field]+1]:
			var c: Owner.Columns = Owner.Columns.new()
			var held: Variant = c.get(FIELDS[field]).duplicate()
			held.resize(count)
			c.set(FIELDS[field],held)
			if field == 0: c.r_present[0] = 2
			else: c.b_present[0] = 2
			var before: Array = _snapshot(c)
			assert_equal(Owner.columns_refusal(c),&"COLUMN_SHAPE","shape before flag")
			for key: int in 29: assert_true(c.get(FIELDS[key]) == before[key],"shape input unchanged")
	for bucket: int in 3:
		for delta: int in [-1,1]:
			if bucket == 2 and delta == -1: continue
			var f: Section.FramedOwner = _frame(Owner.Columns.new())
			if bucket == 0: f.u8_columns.resize(f.u8_columns.size()+delta)
			elif bucket == 1: f.i32_columns.resize(f.i32_columns.size()+delta)
			else: f.i64_columns.resize(f.i64_columns.size()+delta)
			var expected: Variant = Section.owner_shape_refusal(f)
			var actual: Variant = Bridge.framed_refusal(f)
			assert_equal(actual.code,expected.code,"shape code forwarded")
			assert_equal(actual.detail,expected.detail,"shape detail forwarded")
			assert_false(actual.is_ok(),"bad bucket shape")
func test_each_field_at_first_midpoint_and_last_physical_row() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var bad: Array[int] = [2,2,2,30,3,-2,4,6,-1,0,1,-2,8,0,1,-1,-1,1,512,257,2,9,0,1,-2,4,0,1,-1]
	var codes: Array[StringName] = [&"COLUMN_FLAG",&"COLUMN_FLAG",&"COLUMN_FLAG",&"COLUMN_BUILDING_ENUM",&"COLUMN_BUILDING_ENUM",&"COLUMN_BUILDING_VALUE",&"COLUMN_BUILDING_ENUM",&"COLUMN_BUILDING_ENUM",&"COLUMN_BUILDING_VALUE",&"COLUMN_BUILDING_REF",&"COLUMN_BUILDING_REF",&"COLUMN_BUILDING_VALUE",&"COLUMN_ROOM_ENUM",&"COLUMN_ROOM_REF",&"COLUMN_ROOM_REF",&"COLUMN_ROOM_VALUE",&"COLUMN_ROOM_VALUE",&"COLUMN_ROOM_FREE",&"COLUMN_ROOM_VALUE",&"COLUMN_ROOM_VALUE",&"COLUMN_FLAG",&"COLUMN_FURNITURE_ENUM",&"COLUMN_FURNITURE_REF",&"COLUMN_FURNITURE_REF",&"COLUMN_FURNITURE_VALUE",&"COLUMN_FURNITURE_ENUM",&"COLUMN_FURNITURE_REF",&"COLUMN_FURNITURE_REF",&"COLUMN_FURNITURE_VALUE"]
	for field: int in 29:
		for row: int in [0,COUNTS[field]/2,COUNTS[field]-1]:
			_put(c,field,row,bad[field])
			_expect(c,codes[field],"sampled field%d row%d" % [field,row])
			_put(c,field,row,-1 if field in [5,9,11,13,22,24,26] else 0)
	_expect(c,&"","all sampled faults restored")
func test_all_catalog_geometries_at_rotated_map_boundary() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	for typ: int in 30:
		for rotation: int in 4:
			var row: int = typ*4+rotation
			_building(c,row)
			c.b_type_id[row] = typ
			c.b_rotation[row] = rotation
			var x: int = BUILDING_X[typ] if rotation%2 == 0 else BUILDING_Z[typ]
			var z: int = BUILDING_Z[typ] if rotation%2 == 0 else BUILDING_X[typ]
			c.b_origin_tile[row] = (128-z)*128+(128-x)
	for typ: int in 9:
		for rotation: int in 4:
			var row: int = typ*4+rotation
			_furniture(c,row)
			c.f_type_id[row] = typ
			c.f_rotation[row] = rotation
			var x: int = FURNITURE_X[typ] if rotation%2 == 0 else FURNITURE_Z[typ]
			var z: int = FURNITURE_Z[typ] if rotation%2 == 0 else FURNITURE_X[typ]
			c.f_origin_tile[row] = 16383 if x == 0 else (128-z)*128+(128-x)
	_expect(c,&"","all120 building and36 furniture type/rotation fits; local only")
func test_full_capacity_mixed_live_retired_and_never_used_rows() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	for row: int in 1024:
		if row%3 == 0: continue
		_building(c,row,row%3 == 2)
		c.b_state[row] = row%6
		c.b_condition[row] = 2147483647
		c.b_interior_id[row] = 2147483647
	for row: int in 16384:
		if row%3 == 0: continue
		_room(c,row,row%3 == 2)
		c.r_type[row] = row%8
		c.r_temperature_tenths[row] = -2147483648+row
		c.r_occupants[row] = row%257
		if c.r_present[row] == 1:
			c.r_tile_offset[row] = row
			c.r_furniture_mask[row] = row%512
			c.r_valid[row] = row%2
	for row: int in 81920:
		if row%3 == 0: continue
		_furniture(c,row,row%3 == 2)
		c.f_type_id[row] = row%9
		c.f_rotation[row] = row%4
		c.f_condition[row] = 2147483647
		if c.f_present[row] == 1:
			c.f_user_slot[row] = 352417
			c.f_user_generation[row] = 2147483647
	_expect(c,&"","full storage capacity local image; not coherent saved world")
