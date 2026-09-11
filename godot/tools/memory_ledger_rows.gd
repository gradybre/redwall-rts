extends RefCounted
## ARCH-MEM-010's 24 printed allocation rows, transcribed, plus the columns each one claims.
##
## This file is a TRANSCRIPTION of `docs/systems_architecture.md` §2.3 as it stands, not a
## second opinion about it. `declared` is the row's own "Bytes" cell copied verbatim. The
## `owner` and `columns` fields are this file's reading of which code the row describes,
## taken from the row's own derivation text where it names a file (`world_init.gd`,
## `scheduler_events.gd`, `presentation_extract.gd`, `commands.gd`, `command_dispatch.gd`)
## and from the column shape it describes where it does not.
##
## A row with an empty `owner` is one this transcription could not attribute to any code at
## all. That is reported as UNATTRIBUTED and never as zero: "no store allocates this" and
## "this store allocates nothing" are different findings and the report keeps them apart.
##
## The two aggregate rows -- "Fixed registry payload" and "Auxiliary payload" -- are marked
## `aggregate`. They are the mechanical sums of the §2.2 and §3 tables, spread across every
## store in the project. NOTHING IN THE CODE MARKS A COLUMN AS §2.2 OR §3: `jobs.gd` holds
## both GDD Job fields and the §3 JobRuntime table in one flat set of members, and the
## docstring citations that do exist are uneven (measured 2026-09-11: 19 of 36 core scripts
## mention either section at all, `ecology.gd` and `crop_weather.gd` among those that do
## not). The two rows are therefore reported as one combined figure against the residual,
## and the split between them is reported as NOT MEASURABLE rather than guessed.

## Sentinel-free marker for a row this transcription could attribute to no code.
const UNATTRIBUTED: String = ""


func rows() -> Array[Dictionary]:
	"""Every §2.3 allocation row: declared bytes and the columns it claims, in table order."""
	var out: Array[Dictionary] = []
	out.append_array(_aggregate_rows())
	out.append_array(_navigation_rows())
	out.append_array(_route_rows())
	out.append_array(_command_rows())
	out.append_array(_unowned_rows())
	out.append_array(_named_file_rows())
	return out


func _aggregate_rows() -> Array[Dictionary]:
	"""The two rows that are mechanical sums of the §2.2 and §3 field tables."""
	return [
		{"name": "Fixed registry payload", "declared": 25028962, "aggregate": true,
			"owner": UNATTRIBUTED, "columns": []},
		{"name": "Auxiliary payload", "declared": 17232732, "aggregate": true,
			"owner": UNATTRIBUTED, "columns": []},
	]


func _navigation_rows() -> Array[Dictionary]:
	"""The ground map, the A* builder and the route arena."""
	return [
		{"name": "Static navigation map", "declared": 3670016, "aggregate": false,
			"owner": "res://scripts/core/spatial_world.gd",
			"columns": ["_walkable", "_layer", "_terrain", "_height_units", "_clearance"]},
		{"name": "Active A* builder", "declared": 5505024, "aggregate": false,
			"owner": "res://scripts/core/navigation.gd",
			"columns": ["_g", "_parent", "_heap", "_heap_position", "_stamp", "_state"]},
		{"name": "Route cell arena", "declared": 4194304, "aggregate": false,
			"owner": "res://scripts/core/navigation.gd", "columns": ["_arena"]},
	]


func _route_rows() -> Array[Dictionary]:
	"""Route descriptors, path request records and the two movement-side rows."""
	return [
		{"name": "Route descriptors", "declared": 16384, "aggregate": false,
			"owner": "res://scripts/core/navigation.gd", "columns": [
				"_d_route_id", "_d_generation", "_d_start_macro", "_d_goal_cell",
				"_d_clearance", "_d_map_revision", "_d_variant_start", "_d_anchor",
				"_d_offset", "_d_count", "_d_refcount", "_d_use_low", "_d_use_high",
				"_d_flags", "_d_next_variant", "_d_reserved"]},
		{"name": "Path request records", "declared": 524288, "aggregate": false,
			"owner": "res://scripts/core/navigation.gd", "columns": [
				"_r_job_slot", "_r_job_generation", "_r_start_cell", "_r_goal_cell",
				"_r_clearance", "_r_start_macro", "_r_map_revision", "_r_phase",
				"_r_route_id", "_r_route_generation", "_r_created_low", "_r_created_high",
				"_r_next_queue", "_r_exact_start", "_r_anchor", "_r_expansions"]},
		{"name": "Spatial heads", "declared": 65536, "aggregate": false,
			"owner": "res://scripts/core/movement.gd", "columns": []},
		{"name": "Resident motion/separation scratch", "declared": 32768, "aggregate": false,
			"owner": "res://scripts/core/movement.gd", "columns": [
				"_vx", "_vz", "_remainder_x", "_remainder_z", "_next_x", "_next_z",
				"_correction_x", "_correction_z", "_grid_next", "_grid_cell", "_radius_u",
				"_speed_u_per_s", "_desired_yaw", "_next_yaw", "_movement_phase",
				"_blocked_ticks"]},
	]


func _command_rows() -> Array[Dictionary]:
	"""ARCH-CMD-001's queue and arena, and everything `command_dispatch.gd` keeps per result."""
	return [
		{"name": "Command queue", "declared": 262144, "aggregate": false,
			"owner": "res://scripts/core/commands.gd", "columns": [
				"_execute_tick", "_player_id", "_sequence_low", "_sequence_high", "_kind",
				"_target_slot", "_target_generation", "_goal_x", "_goal_z", "_arg0",
				"_arg1", "_payload_offset", "_payload_length", "_flags", "_reserved_zero"]},
		{"name": "Command queue order index", "declared": 16384, "aggregate": false,
			"owner": "res://scripts/core/commands.gd", "columns": ["_order"]},
		{"name": "Command payload arena", "declared": 1048576, "aggregate": false,
			"owner": "res://scripts/core/commands.gd", "columns": ["_payload"]},
		{"name": "Command result ledger", "declared": 147456, "aggregate": false,
			"owner": "res://scripts/core/command_dispatch.gd", "columns": [
				"_result_execute_tick", "_result_sequence_low", "_result_sequence_high",
				"_result_kind", "_result_code", "_result_value", "_result_target_slot",
				"_result_target_generation"]},
		{"name": "Command result store codes", "declared": 32768, "aggregate": false,
			"owner": "res://scripts/core/command_dispatch.gd", "columns": [],
			"containers": ["_result_store_code"]},
		{"name": "Command payload decode scratch", "declared": 65540, "aggregate": false,
			"owner": "res://scripts/core/command_dispatch.gd", "columns": ["_payload"]},
		{"name": "Command dispatch source-intent ledger", "declared": 2048,
			"aggregate": false, "owner": "res://scripts/core/command_dispatch.gd",
			"columns": ["_intent_player_id", "_intent_sequence_high",
				"_intent_sequence_low", "_intent_zone_generation"]},
	]


func _unowned_rows() -> Array[Dictionary]:
	"""Rows whose derivation names no file and for which no allocating code was found."""
	return [
		{"name": "Tick event ring", "declared": 262144, "aggregate": false,
			"owner": UNATTRIBUTED, "columns": []},
		{"name": "Read-only catalog/lookup budget", "declared": 2097152, "aggregate": false,
			"owner": UNATTRIBUTED, "columns": []},
		{"name": "I/O streaming buffers", "declared": 262144, "aggregate": false,
			"owner": UNATTRIBUTED, "columns": []},
		{"name": "UI numeric snapshots", "declared": 131072, "aggregate": false,
			"owner": UNATTRIBUTED, "columns": []},
		{"name": "Timing samples", "declared": 55200, "aggregate": false,
			"owner": "res://scripts/systems/settlement_system.gd",
			"columns": ["_stage_usec", "_stage_usec_total", "_stage_measured"]},
	]


func _named_file_rows() -> Array[Dictionary]:
	"""Rows whose own derivation text names the exact script that allocates them."""
	return [
		{"name": "World generation map masks and tree plan", "declared": 159968,
			"aggregate": false, "owner": "res://scripts/core/world_init.gd", "columns": [
				"_terrain", "_soil", "_basin", "_cleared", "_staged_terrain",
				"_staged_soil", "_staged_basin", "_staged_cleared", "_staged_used",
				"_basin_ref_slot", "_basin_ref_generation", "_basin_danger",
				"_staged_danger", "_staged_centres", "_staged_grove"]},
		{"name": "Scheduler event queue and control header", "declared": 8224,
			"aggregate": false, "owner": "res://scripts/core/scheduler_events.gd",
			"columns": ["_boundary_tick", "_sequence_low", "_sequence_high", "_kind",
				"_reason", "_value", "_reserved"]},
		{"name": "ARCH-SYS-023 presentation snapshot", "declared": 244, "aggregate": false,
			"owner": "res://scripts/core/presentation_extract.gd",
			"columns": ["_current", "_previous", "_available", "_layer_visible"]},
	]


func declared_total() -> int:
	"""Sum of every row's declared bytes; must reproduce §2.3's printed 60821078."""
	var total: int = 0
	for row: Dictionary in rows():
		total += int(row["declared"])
	return total
