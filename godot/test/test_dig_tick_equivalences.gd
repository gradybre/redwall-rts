extends "res://test/framework/test_case.gd"
## Decision 1951: the small exact rewrites of the dig-tick lane, each checked against the loop it replaced. The
## present-row walk visits exactly the rows a `!= 0` scan admits, whatever bytes the column holds; the 64-bit word
## comparison of two 32-byte digests is true exactly when every byte is equal.

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""One fixed seed per test."""
	_rng.seed = 1951


func _walk(column: PackedByteArray) -> PackedInt32Array:
	"""The rows `_next_present` visits from row 0, in order."""
	var rows: PackedInt32Array = PackedInt32Array()
	var binary: bool = Owner._binary_present(column)
	var row: int = Owner._next_present(column, 0, binary)
	while row >= 0 and row < column.size():
		rows.append(row)
		row = Owner._next_present(column, row + 1, binary)
	return rows


func _nonzero(column: PackedByteArray) -> PackedInt32Array:
	"""The rows the original scan admitted."""
	var rows: PackedInt32Array = PackedInt32Array()
	for row: int in column.size():
		if column[row] != 0: rows.append(row)
	return rows


func test_the_present_walk_visits_exactly_the_rows_the_scan_admits() -> void:
	"""Binary columns are walked by `find(1)`; any other byte value falls back to every row, still exact."""
	for size: int in [0, 1, 7, 64, 1024]:
		for density: int in [0, 3, 50, 100]:
			var column: PackedByteArray = PackedByteArray()
			column.resize(size)
			for row: int in size:
				column[row] = 1 if _rng.randi_range(0, 99) < density else 0
			assert_true(Owner._binary_present(column), "0/1 columns are binary")
			assert_equal(_walk(column), _nonzero(column), "binary walk %d/%d" % [size, density])
			if size > 0:
				column[_rng.randi_range(0, size - 1)] = 2
				assert_false(Owner._binary_present(column), "a 2 is not binary")
				var visited: PackedInt32Array = _walk(column)
				assert_equal(visited.size(), size, "a non-binary column visits every row")
				for row: int in _nonzero(column): assert_true(row in visited, "row %d still checked" % row)


func test_the_walk_from_past_the_end_is_finished() -> void:
	"""`from` at or past the column's end returns -1 on both paths."""
	var column: PackedByteArray = PackedByteArray([1, 0, 1])
	assert_equal(Owner._next_present(column, 3, true), -1, "binary end")
	assert_equal(Owner._next_present(column, 3, false), -1, "full-scan end")
	assert_equal(Owner._next_present(column, 1, true), 2, "next present row")
	assert_equal(Owner._next_present(column, 1, false), 1, "full scan visits the next row")


func _bytes_equal(a: PackedByteArray, a_at: int, b: PackedByteArray, b_at: int) -> bool:
	"""The original 32-iteration byte loop."""
	for index: int in 32:
		if a[a_at + index] != b[b_at + index]: return false
	return true


func _random(size: int) -> PackedByteArray:
	"""`size` random bytes."""
	var out: PackedByteArray = PackedByteArray()
	out.resize(size)
	for index: int in size:
		out[index] = _rng.randi_range(0, 255)
	return out


func test_word_comparison_equals_the_byte_loop_at_every_differing_byte() -> void:
	"""Equal ranges match; a change at any one of the 32 bytes (any offset, any value) does not, in both copies."""
	var a: PackedByteArray = _random(160)
	for offsets: Vector2i in [Vector2i(0, 64), Vector2i(32, 32), Vector2i(64, 128), Vector2i(7, 100)]:
		var b: PackedByteArray = _random(160)
		for index: int in 32: b[offsets.y + index] = a[offsets.x + index]
		assert_true(Frontier._same_words(a, offsets.x, b, offsets.y), "frontier: equal %s" % offsets)
		assert_true(SourceFacts._same_words(a, offsets.x, b, offsets.y), "facts: equal %s" % offsets)
		for index: int in 32:
			var saved: int = b[offsets.y + index]
			b[offsets.y + index] = (saved + 1 + _rng.randi_range(0, 253)) % 256
			var expected: bool = _bytes_equal(a, offsets.x, b, offsets.y)
			assert_false(expected, "the byte loop sees byte %d" % index)
			assert_equal(Frontier._same_words(a, offsets.x, b, offsets.y), expected, "frontier byte %d" % index)
			assert_equal(SourceFacts._same_words(a, offsets.x, b, offsets.y), expected, "facts byte %d" % index)
			b[offsets.y + index] = saved


func _frontier_oracle(assemblies: PackedByteArray, recipes: PackedByteArray, own: PackedByteArray,
		sources: PackedByteArray, source: int) -> bool:
	"""The entry Frontier's original seven-way byte loop."""
	for index: int in 32:
		if assemblies[index] != own[64 + index] or recipes[index] != own[96 + index] \
				or assemblies[32 + index] != own[32 + index] or recipes[32 + index] != own[32 + index] \
				or assemblies[64 + index] != own[96 + index] or recipes[64 + index] != own[64 + index] \
				or sources[source + index] != own[128 + index]:
			return false
	return true


func _matching_frontier() -> Array[PackedByteArray]:
	"""[assemblies, recipes, own, sources] whose seven ranges all agree; sources' digest sits at row 2."""
	var own: PackedByteArray = _random(160)
	var assemblies: PackedByteArray = own.slice(64, 96) + own.slice(32, 64) + own.slice(96, 128)
	var recipes: PackedByteArray = own.slice(96, 128) + own.slice(32, 64) + own.slice(64, 96)
	var sources: PackedByteArray = _random(64) + own.slice(128, 160) + _random(32)
	return [assemblies, recipes, own, sources]


func test_the_frontier_word_match_equals_its_byte_loop_under_any_one_byte_change() -> void:
	"""Every byte of every compared range, changed alone, refuses in both; untouched bytes elsewhere do not."""
	var arrays: Array[PackedByteArray] = _matching_frontier()
	assert_true(Frontier._digest_words_match(arrays[0], arrays[1], arrays[2], arrays[3], 64), "all agree")
	assert_true(_frontier_oracle(arrays[0], arrays[1], arrays[2], arrays[3], 64), "and the loop agrees")
	for which: int in 4:
		for index: int in arrays[which].size():
			var saved: int = arrays[which][index]
			arrays[which][index] = (saved + 1) % 256
			var expected: bool = _frontier_oracle(arrays[0], arrays[1], arrays[2], arrays[3], 64)
			assert_equal(Frontier._digest_words_match(arrays[0], arrays[1], arrays[2], arrays[3], 64), expected,
				"array %d byte %d" % [which, index])
			arrays[which][index] = saved


func test_the_frontier_word_path_needs_every_range() -> void:
	"""Its own image must reach byte 160 and the Profiles source row must lie inside the sources bank."""
	var own: PackedByteArray = _random(160)
	var sources: PackedByteArray = _random(96)
	assert_true(Frontier._digest_ranges(own, sources, 64), "both ranges exist")
	assert_false(Frontier._digest_ranges(own.slice(0, 159), sources, 64), "own one byte short")
	assert_false(Frontier._digest_ranges(own, sources, 65), "source row one byte past the bank")
	assert_false(Frontier._digest_ranges(own, sources, -32), "a negative source row")


func _facts_oracle(digests: PackedByteArray, sources: PackedByteArray, offset: int, levels: PackedByteArray) -> bool:
	"""The Catalog source-facts original byte loop."""
	for index: int in 32:
		if digests[32 + index] != sources[offset + index] or digests[64 + index] != levels[index]:
			return false
	return true


func test_the_catalog_digest_match_equals_its_byte_loop() -> void:
	"""Agreeing digests match; any one changed byte of either pair refuses, as in the loop; a short Level digest
	takes the loop itself."""
	var digests: PackedByteArray = _random(96)
	var sources: PackedByteArray = _random(32) + digests.slice(32, 64)
	var levels: PackedByteArray = digests.slice(64, 96)
	assert_true(SourceFacts._digests_equal(digests, sources, 32, levels), "agree")
	for which: int in 3:
		var array: PackedByteArray = [digests, sources, levels][which]
		for index: int in array.size():
			var saved: int = array[index]
			array[index] = (saved + 1) % 256
			assert_equal(SourceFacts._digests_equal(digests, sources, 32, levels), _facts_oracle(digests, sources, 32, levels),
				"array %d byte %d" % [which, index])
			array[index] = saved
	levels[0] = (levels[0] + 1) % 256
	assert_false(SourceFacts._digests_equal(digests, sources, 32, levels.slice(0, 31)), "short Level digest: the loop")


func _owner() -> Owner:
	"""An actual configured SpaceOwner (the space owner suite's fixture) with empty banks."""
	var buildings: Buildings = Buildings.new()
	var world: Vector2i = buildings.directory().create(Directory.KIND_WORLD)
	_world = world
	var sources: Owner.CoreSources = Owner.CoreSources.new(buildings.directory(), buildings, Construction.new(buildings))
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(world, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(16, 16, 16), 64, 64, 100000), &"",
		"domain")
	var owner: Owner = Owner.new(sources)
	assert_equal(owner.configure(domain, 32, 8), &"", "configured")
	return owner


func test_unclaimed_and_absent_region_rows_are_skipped_in_both_banks() -> void:
	"""A present row with no claim (even naming a reference) is skipped; the staged walk reads the staged bank."""
	var owner: Owner = _owner()
	owner._r_present[3] = 1
	owner._r_claim_slot[3] = 5
	owner._r_claim_generation[3] = 1
	assert_equal(owner._claims_refusal(false), &"", "live: no claim, no refusal")
	owner._s_r_present[4] = 1
	owner._s_r_claim_slot[4] = 5
	owner._s_r_claim_generation[4] = 1
	assert_equal(owner._claims_refusal(true), &"", "staged: no claim, no refusal")
	owner._s_r_claim_kind[4] = Owner.CLAIM_CONSTRUCTION
	var refused: StringName = owner._claims_refusal(true)
	assert_true(refused != &"", "staged: a stale Construction claim refuses")
	assert_equal(refused, owner._claim_refusal(Owner.CLAIM_CONSTRUCTION, Vector2i(5, 1),
		Vector2i(owner._s_r_owner_slot[4], owner._s_r_owner_generation[4]), true), "exactly its refusal")
	assert_equal(owner._claims_refusal(false), &"", "the live bank is unchanged")


func test_a_non_binary_presence_byte_is_still_checked_and_zero_rows_skipped() -> void:
	"""A presence byte of 2 counts as present, as in the scan; a zero row before it is never read, in either bank,
	even when that zero row names a reference that would refuse. Row 0 is the configured World source."""
	var owner: Owner = _owner()
	owner._o_slot[2] = 7
	owner._o_generation[2] = 3
	owner._o_present[3] = 2
	owner._o_slot[3] = _world.x
	owner._o_generation[3] = _world.y
	var expected: StringName = owner._source_row_refusal(3, false, true)
	var skipped: StringName = owner._source_row_refusal(2, false, true)
	assert_equal(owner._source_row_refusal(0, false, true), &"", "the World source row is sound")
	assert_true(expected != &"" and skipped != &"" and expected != skipped, "rows 2 and 3 refuse differently")
	assert_equal(owner._sources_refusal(false), expected, "live: the present row's refusal")
	owner._o_present[3] = 0
	owner._s_o_slot[2] = 7
	owner._s_o_generation[2] = 3
	owner._s_o_present[3] = 2
	owner._s_o_slot[3] = _world.x
	owner._s_o_generation[3] = _world.y
	assert_true(Owner._binary_present(owner._o_present), "the live bank is binary again")
	assert_equal(owner._sources_refusal(true, false), owner._source_row_refusal(3, true, false), "staged: the same")
	assert_true(owner._source_row_refusal(3, true, false) != &"", "and it refuses")


func test_the_staged_claim_walk_continues_in_the_staged_bank() -> void:
	"""After an unclaimed staged row the walk goes on in the staged bank to its later claimed row."""
	var owner: Owner = _owner()
	owner._s_r_present[2] = 1
	owner._s_r_present[6] = 1
	owner._s_r_claim_kind[6] = Owner.CLAIM_CONSTRUCTION
	owner._s_r_claim_slot[6] = 5
	owner._s_r_claim_generation[6] = 1
	assert_true(owner._claims_refusal(true) != &"", "the later staged claim is reached and refuses")
	assert_equal(owner._claims_refusal(false), &"", "the live bank holds nothing")
