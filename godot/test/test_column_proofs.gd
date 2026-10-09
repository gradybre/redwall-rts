extends "res://test/framework/test_case.gd"
## `column_proofs.gd`, `save_inventories_proof.gd` and `save_integrity_jobs.gd` (ADR 1235).
##
## Each proof may only ever say "the row walk would accept". These tests pin what each helper
## answers and, for the row proof, that a single differing cell anywhere is judged.

const ColumnProofs := preload("res://scripts/core/column_proofs.gd")
const InventoriesProof := preload("res://scripts/core/save_inventories_proof.gd")
const S07 := preload("res://scripts/core/save_section_inventories.gd")
const Jobs := preload("res://scripts/core/save_integrity_jobs.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")


func _ints(values: Array) -> PackedInt32Array:
	"""A PackedInt32Array of `values`."""
	return PackedInt32Array(values)


func test_bytes_are_flags_accepts_only_zero_and_one() -> void:
	"""Any byte above 1 fails the flag proof."""
	assert_true(ColumnProofs.bytes_are_flags(PackedByteArray([0, 1, 1, 0])), "0/1")
	assert_true(ColumnProofs.bytes_are_flags(PackedByteArray()), "empty")
	assert_false(ColumnProofs.bytes_are_flags(PackedByteArray([0, 2, 1])), "a 2")


func test_rows_holding_lists_every_match_ascending() -> void:
	"""Every index holding the value, in order, and nothing else."""
	assert_equal(ColumnProofs.rows_holding(PackedByteArray([1, 0, 1, 1, 0]), 1), _ints([0, 2, 3]),
		"ones")
	assert_equal(ColumnProofs.rows_holding(PackedByteArray([0, 0]), 1), _ints([]), "none")


func test_others_equal_ignores_only_the_skipped_rows() -> void:
	"""Skipped rows may hold anything; every other row must hold the value."""
	assert_true(ColumnProofs.i32_others_equal(_ints([-1, 7, -1]), _ints([1]), -1), "i32 skip")
	assert_false(ColumnProofs.i32_others_equal(_ints([-1, 7, 5]), _ints([1]), -1), "i32 stray")
	assert_true(ColumnProofs.i64_others_equal(PackedInt64Array([0, 9]), _ints([1]), 0), "i64")
	assert_false(ColumnProofs.i64_others_equal(PackedInt64Array([3, 9]), _ints([1]), 0), "i64 x")
	assert_true(ColumnProofs.u8_others_equal(PackedByteArray([0, 4]), _ints([1]), 0), "u8")
	assert_false(ColumnProofs.u8_others_equal(PackedByteArray([2, 4]), _ints([1]), 0), "u8 x")
	var column: PackedInt32Array = _ints([5, 5])
	ColumnProofs.i32_others_equal(column, _ints([0]), 1)
	assert_equal(column, _ints([5, 5]), "the caller's column is not written")


func test_minimum_ascending_and_permutation() -> void:
	"""The three set helpers the free-stack proofs use."""
	assert_equal(ColumnProofs.i32_minimum(_ints([4, -2, 9])), -2, "minimum")
	assert_equal(ColumnProofs.i32_minimum(_ints([])), 0, "empty minimum")
	assert_equal(ColumnProofs.ascending_except(6, _ints([0, 3, 5])), _ints([1, 2, 4]), "except")
	assert_equal(ColumnProofs.ascending_except(3, _ints([])), _ints([0, 1, 2]), "nothing out")
	assert_true(ColumnProofs.is_permutation_of(_ints([4, 1, 2]), _ints([1, 2, 4])), "same set")
	assert_false(ColumnProofs.is_permutation_of(_ints([4, 4, 2]), _ints([1, 2, 4])), "a repeat")
	assert_false(ColumnProofs.is_permutation_of(_ints([4, 2]), _ints([1, 2, 4])), "short")


func test_rows_proven_judges_every_row_that_differs() -> void:
	"""A single differing cell in any column, at any position, is passed to the row check."""
	for position: int in [0, 63, 64, 500, 998]:
		var a: PackedInt32Array = PackedInt32Array()
		a.resize(1000)
		var b: PackedByteArray = PackedByteArray()
		b.resize(1000)
		b[position] = 3
		var judged: PackedInt32Array = PackedInt32Array()
		var proven: bool = ColumnProofs.rows_proven([a, b], func(row: int) -> bool:
			judged.append(row)
			return b[row] == 0)
		assert_false(proven, "the bad row at %d is found" % position)
		assert_true(judged.has(position), "and judged")
	var clean: PackedInt32Array = PackedInt32Array()
	clean.resize(4096)
	var calls: Array[int] = [0]
	assert_true(ColumnProofs.rows_proven([clean], func(_row: int) -> bool:
		calls[0] += 1
		return true), "a uniform column")
	assert_equal(calls[0], 1, "is judged once")


func test_rows_proven_refuses_columns_of_different_lengths() -> void:
	"""Unequal columns cannot be proved row by row."""
	assert_false(ColumnProofs.rows_proven([_ints([1, 2]), _ints([1])],
		func(_row: int) -> bool: return true), "unequal")
	assert_true(ColumnProofs.rows_proven([], func(_row: int) -> bool: return false), "none")


func test_strided_deviant_rows_maps_cells_to_rows() -> void:
	"""Cells that differ from the last row's uniform value name their row; a mixed last row
	cannot be relied on."""
	var cells: PackedInt64Array = PackedInt64Array([0, 0, 0, 5, 0, 0, 0, 0])
	var rows: PackedInt32Array = PackedInt32Array()
	assert_true(ColumnProofs.strided_deviant_rows(cells, 2, 4, rows), "uniform last row")
	assert_equal(rows, _ints([1]), "cell 3 is row 1")
	var mixed: PackedInt64Array = PackedInt64Array([0, 0, 1, 0])
	assert_false(ColumnProofs.strided_deviant_rows(mixed, 2, 2, PackedInt32Array()), "mixed")
	assert_false(ColumnProofs.strided_deviant_rows(cells, 3, 4, PackedInt32Array()), "bad shape")


func test_an_empty_section_7_is_proven_and_a_forged_free_row_is_not() -> void:
	"""Every owner of the empty record is proved; one stray blank on a free row is left to the
	row walk, which refuses it."""
	var record: S07.Record = S07.empty_record()
	for owner: int in S07.OWNER_COUNT:
		assert_true(InventoriesProof.owner_proven(record.of(owner)), "owner %d" % owner)
	var gear: S07.OwnerRecord = record.of(S07.OWNER_GEAR)
	var item: PackedInt32Array = gear.i32_column(3).duplicate()
	item[7] = 12
	gear.set_i32_column(3, item)
	assert_false(InventoriesProof.owner_proven(gear), "a forged free gear row")
	assert_false(S07.owner_refusal(gear).is_ok(), "and the row walk refuses it")


func test_integrity_jobs_match_the_sequential_hashes() -> void:
	"""Worker CRCs and body digest equal the main-thread values."""
	var sections: Array[PackedByteArray] = [PackedByteArray([1, 2, 3]), PackedByteArray()]
	var big: PackedByteArray = PackedByteArray()
	big.resize(300000)
	big[1234] = 9
	sections.append(big)
	var job: Jobs.CrcJob = Jobs.CrcJob.new(sections)
	var crcs: PackedInt64Array = job.values()
	assert_equal(job.count(), 3, "three sections")
	for index: int in sections.size():
		assert_equal(crcs[index], SaveHeader.crc32_by_bytes(sections[index]), "section %d" % index)
	var digest: Jobs.DigestJob = Jobs.DigestJob.new(big)
	assert_equal(digest.digest(), SaveHeader.compute_body_digest(big), "body digest")
	var dropped: Jobs.CrcJob = Jobs.CrcJob.new(sections)
	assert_equal(dropped.values_for([PackedByteArray([9])] as Array[PackedByteArray]),
		PackedInt64Array(), "CRCs of bytes that were replaced are not handed out")
	assert_equal(dropped.values_for(sections), crcs, "the same bytes give the same CRCs")
