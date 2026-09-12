extends SceneTree
## Prints ARCH-MEM-010's ledger against what the stores actually allocate.
##
## Usage, from the repository root:
##     godot --headless --path godot --script tools/measure_memory_ledger.gd
##
## The work runs from `_process`, not `_initialize`: autoloads are added to the root AFTER a
## custom main loop initialises (verified on 4.7.2 -- `[SettlementSystem] ready` prints after
## `_initialize` returns), and the "Timing samples" row is owned by the SettlementSystem
## autoload's own columns. Measuring from `_initialize` would report that row as absent when
## it is merely not built yet.
##
## Everything printed here is ALLOCATED payload -- the bytes a store's packed arrays were
## sized to hold -- except the two lines explicitly labelled static memory, which are the
## process's own `OS.get_static_memory_usage()`. See `memory_ledger_probe.gd` for what that
## figure does and does not contain.

const Probe := preload("res://tools/memory_ledger_probe.gd")
const LedgerRows := preload("res://tools/memory_ledger_rows.gd")

## §2.3's own printed metric rows, for the closing comparison.
const PRINTED_PAYLOAD: int = 60821078
const PRINTED_RESERVE: int = 8388608
const PRINTED_LIVE_TOTAL: int = 69209686

var _probe: Probe = Probe.new()
var _ledger: LedgerRows = LedgerRows.new()
var _done: bool = false


func _process(_delta: float) -> bool:
	"""Run the whole measurement once on the first frame, then stop the main loop."""
	if _done:
		return true
	_done = true
	_report()
	return true


func _report() -> void:
	"""Print calibration, the per-row comparison, the residual and the process-level total."""
	_print_calibration()
	var before: int = OS.get_static_memory_usage()
	var world: Dictionary = _probe.build_world()
	var measured: Array[Dictionary] = _probe.collect_instances(world)
	var static_delta: int = OS.get_static_memory_usage() - before
	measured.append(_probe.measure_instance(_settlement_autoload()))
	_print_rows(measured)
	_print_stores(measured)
	_print_columns(measured)
	_print_string_columns(measured)
	_print_totals(measured, static_delta)


func _print_columns(measured: Array[Dictionary]) -> void:
	"""Print every measured column individually, for cross-checking against the state registry.

	`docs/persistence_state_registry.md` declares a width and a count per column group.
	This section is what lets that declaration be compared with the live array, so the
	comparison is two instruments disagreeing rather than one document quoting itself.
	"""
	print("")
	print("## Every measured column (script,column,type,length,bytes)")
	for row: Dictionary in measured:
		for column: Dictionary in row["columns"]:
			print("%s,%s,%s,%d,%d" % [String(row["script"]), String(column["name"]),
				String(column["type"]), int(column["length"]), int(column["bytes"])])


func _print_string_columns(measured: Array[Dictionary]) -> void:
	"""Print every PackedStringArray column, which §2.3 gives no byte model for."""
	print("")
	print("## PackedStringArray columns (no §2.3 byte model; excluded from every total)")
	var slot: Dictionary = _probe.calibrate_string_array_element_bytes()
	var per_slot: String = \
		str(slot["bytes_per_empty_element"]) if slot["measured"] else "UNMEASURED"
	print("measured_bytes_per_empty_slot,%s" % per_slot)
	print("script,column,slots,utf8_content_bytes")
	for row: Dictionary in measured:
		for column: Dictionary in row["string_columns"]:
			print("%s,%s,%d,%d" % [String(row["script"]), String(column["name"]),
				int(column["length"]), int(column["utf8_content_bytes"])])


func _settlement_autoload() -> Object:
	"""The live SettlementSystem autoload, whose own columns own the Timing samples row."""
	var node: Node = root.get_node_or_null("/root/SettlementSystem")
	if node == null:
		push_error("measure_memory_ledger: SettlementSystem autoload is absent")
		return RefCounted.new()
	return node


func _print_calibration() -> void:
	"""Print the measured bytes per element of every container type the ledger assumes."""
	print("## Element-size calibration (static-memory delta / element count)")
	print("type,declared_bytes_per_element,measured_bytes_per_element,delta_bytes")
	for row: Dictionary in _probe.calibrate_element_bytes():
		var value: String = str(row["bytes_per_element"]) if row["measured"] else "UNMEASURED"
		print("%s,%d,%s,%d" % [row["type"], row["declared"], value, row["delta_bytes"]])
	var array_row: Dictionary = _probe.calibrate_array_element_bytes()
	var array_value: String = \
		str(array_row["bytes_per_element"]) if array_row["measured"] else "UNMEASURED"
	print("Array[StringName],%d,%s,%d"
		% [array_row["declared"], array_value, array_row["delta_bytes"]])


func _print_rows(measured: Array[Dictionary]) -> void:
	"""Print each §2.3 allocation row: declared, measured, delta, and how it was measured."""
	print("")
	print("## ARCH-MEM-010 allocation rows: declared vs measured allocated bytes")
	print("row,declared,measured,delta,basis")
	for row: Dictionary in _ledger.rows():
		var result: Dictionary = _measure_row(row, measured)
		print("%s,%d,%s,%s,%s" % [row["name"], int(row["declared"]),
			result["measured"], result["delta"], result["basis"]])


func _measure_row(row: Dictionary, measured: Array[Dictionary]) -> Dictionary:
	"""Measure one ledger row, or say why it cannot be measured. Never substitutes a zero."""
	if bool(row["aggregate"]):
		return {"measured": "SEE RESIDUAL", "delta": "SEE RESIDUAL",
			"basis": "sum of §2.2/§3 field tables; no column is marked with its section"}
	if String(row["owner"]) == LedgerRows.UNATTRIBUTED:
		return {"measured": "UNATTRIBUTED", "delta": "UNATTRIBUTED",
			"basis": "no allocating code found for this row"}
	var instance: Dictionary = _find_instance(String(row["owner"]), measured)
	if instance.is_empty():
		return {"measured": "OWNER ABSENT", "delta": "OWNER ABSENT",
			"basis": "%s was not instantiated" % String(row["owner"])}
	var columns: Array = row["columns"]
	if columns.is_empty():
		return _measure_container_row(row, instance)
	var bytes: int = _probe.column_bytes_named(instance, columns)
	return {"measured": bytes, "delta": bytes - int(row["declared"]),
		"basis": "%d columns of %s" % [columns.size(), String(row["owner"]).get_file()]}


func _measure_container_row(row: Dictionary, instance: Dictionary) -> Dictionary:
	"""Measure a row held in a GDScript Array rather than a packed column, or report none."""
	var wanted: Array = row.get("containers", [])
	var file: String = String(row["owner"]).get_file()
	if wanted.is_empty():
		return {"measured": 0, "delta": -int(row["declared"]),
			"basis": "%s allocates no column for this row" % file}
	var element: int = int(_probe.calibrate_array_element_bytes()["bytes_per_element"])
	var length: int = 0
	for container: Dictionary in instance["containers"]:
		if wanted.has(String(container["name"])):
			length += int(container["length"])
	var bytes: int = length * element
	return {"measured": bytes, "delta": bytes - int(row["declared"]),
		"basis": "%d Array elements in %s at a measured %d bytes each"
			% [length, file, element]}


func _find_instance(script_path: String, measured: Array[Dictionary]) -> Dictionary:
	"""The measured row for one script path, or an empty Dictionary when it was not built."""
	for row: Dictionary in measured:
		if String(row["script"]) == script_path:
			return row
	return {}


func _print_stores(measured: Array[Dictionary]) -> void:
	"""Print every measured instance and how much of it no §2.3 row claims."""
	print("")
	print("## Per-store allocated payload, and the part no §2.3 allocation row claims")
	print("script,columns,allocated_bytes,claimed_by_rows,unclaimed_bytes,in_autoload_world")
	var claimed: Dictionary = _claimed_columns()
	for row: Dictionary in measured:
		var path: String = String(row["script"])
		var names: Array = claimed.get(path, [])
		var taken: int = _probe.column_bytes_named(row, names)
		print("%s,%d,%d,%d,%d,%s" % [path, (row["columns"] as Array).size(),
			int(row["packed_bytes"]), taken, int(row["packed_bytes"]) - taken,
			str(Probe.COMPOSED_SCRIPTS.has(path))])


func _claimed_columns() -> Dictionary:
	"""Map every owner script path to the column names its §2.3 rows claim."""
	var claimed: Dictionary = {}
	for row: Dictionary in _ledger.rows():
		var path: String = String(row["owner"])
		if path == LedgerRows.UNATTRIBUTED:
			continue
		var names: Array = claimed.get(path, [])
		names.append_array(row["columns"])
		claimed[path] = names
	return claimed


func _print_totals(measured: Array[Dictionary], static_delta: int) -> void:
	"""Print the residual against the two aggregate rows and the process-level figures."""
	var total: int = _probe.total_packed_bytes(measured)
	var attributed: int = _attributed_total(measured)
	var aggregate_declared: int = 25028962 + 17232732
	print("")
	print("## Totals (all figures are allocated packed payload unless labelled otherwise)")
	print("measured_allocated_total,%d" % total)
	print("measured_packed_columns_only,true")
	print("array_container_bytes_excluded_from_total,%d" % _container_bytes(measured))
	print("measured_attributed_to_subsystem_rows,%d" % attributed)
	print("measured_residual_vs_registry_and_auxiliary,%d" % (total - attributed))
	print("declared_registry_plus_auxiliary,%d" % aggregate_declared)
	print("residual_delta,%d" % (total - attributed - aggregate_declared))
	print("declared_printed_payload,%d" % PRINTED_PAYLOAD)
	print("transcribed_row_sum,%d" % _ledger.declared_total())
	print("measured_total_vs_declared_payload,%d" % (total - PRINTED_PAYLOAD))
	print("declared_allocator_reserve,%d" % PRINTED_RESERVE)
	print("declared_one_live_world_plus_reserve,%d" % PRINTED_LIVE_TOTAL)
	print("static_memory_delta_building_the_world,%d" % static_delta)
	print("static_memory_overhead_above_payload,%d" % (static_delta - total))
	print("process_static_memory_after,%d" % OS.get_static_memory_usage())
	print("duplicate_store_instances,%s" % str(_probe.duplicate_instances(measured)))


func _container_bytes(measured: Array[Dictionary]) -> int:
	"""Bytes held in GDScript Arrays across every store, at the measured Variant size.

	Kept out of the allocated total because ARCH-MEM-010's rows are packed-column
	arithmetic; folding a 24-byte-per-Variant container into them would compare two
	different things.
	"""
	var element: int = int(_probe.calibrate_array_element_bytes()["bytes_per_element"])
	var total: int = 0
	for row: Dictionary in measured:
		for container: Dictionary in row["containers"]:
			if String(container["kind"]) == "Array":
				total += int(container["length"]) * element
	return total


func _attributed_total(measured: Array[Dictionary]) -> int:
	"""Bytes of every column claimed by a non-aggregate §2.3 row that has an owner."""
	var total: int = 0
	for row: Dictionary in _ledger.rows():
		if bool(row["aggregate"]) or String(row["owner"]) == LedgerRows.UNATTRIBUTED:
			continue
		var instance: Dictionary = _find_instance(String(row["owner"]), measured)
		if instance.is_empty():
			continue
		total += _probe.column_bytes_named(instance, row["columns"])
	return total
