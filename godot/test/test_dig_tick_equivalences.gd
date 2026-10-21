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
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")

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
	"""Equal ranges match; a change at any one of the 32 bytes (any offset, any value) does not."""
	var a: PackedByteArray = _random(160)
	for offsets: Vector2i in [Vector2i(0, 64), Vector2i(32, 32), Vector2i(64, 128), Vector2i(7, 100)]:
		var b: PackedByteArray = _random(160)
		for index: int in 32: b[offsets.y + index] = a[offsets.x + index]
		assert_true(SourceFacts._same_words(a, offsets.x, b, offsets.y), "facts: equal %s" % offsets)
		for index: int in 32:
			var saved: int = b[offsets.y + index]
			b[offsets.y + index] = (saved + 1 + _rng.randi_range(0, 253)) % 256
			var expected: bool = _bytes_equal(a, offsets.x, b, offsets.y)
			assert_false(expected, "the byte loop sees byte %d" % index)
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
	assert_false(SourceFacts._digests_equal(digests, sources, 32, levels.slice(0, 31)),
		"a 31-byte Level digest takes the byte loop, which refuses at the first differing byte")


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


func test_final_facts_source_walk_reads_exactly_the_scanned_rows() -> void:
	"""Decision 1952: with a non-binary presence column the final snapshot still skips absent rows and refuses the
	first present row in row order: a stale source before an unknown presence byte answers STALE, not FORMAT."""
	var owner: Owner = _owner()
	assert_equal(FinalFacts._sources_refusal(owner, null, null), &"", "the configured World row alone is sound")
	owner._o_present[2] = 1
	owner._o_slot[2] = 7
	owner._o_generation[2] = 3
	owner._o_kind[2] = Directory.KIND_ROOM
	owner._o_present[3] = 2
	assert_equal(FinalFacts._sources_refusal(owner, null, null), &"SPACE_SOURCE_STALE", "row 2 before row 3; row 1 never read")
	owner._o_present[2] = 0
	assert_equal(FinalFacts._sources_refusal(owner, null, null), &"SPACE_SOURCE_FORMAT", "then the unknown presence byte")


func _required_oracle(owner: Owner) -> int:
	"""The pre-1952 precharge: both full scans."""
	var required: int = FinalFacts.BINDING_CHECKS + 2 * (owner._region_capacity + owner._source_capacity)
	for row: int in owner._source_capacity:
		if owner._o_present[row] != 0:
			required += FinalFacts.RESIDENT_CHECKS if owner._o_kind[row] == Directory.KIND_RESIDENT else FinalFacts.SOURCE_CHECKS
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 0 and owner._r_claim_kind[row] != Owner.CLAIM_NONE:
			required += FinalFacts.SOURCE_CHECKS
	return required


func test_final_facts_precharge_equals_both_full_scans() -> void:
	"""Decision 1952: random presence bytes 0/1/2, kinds and claims; binary and non-binary columns alike."""
	var owner: Owner = _owner()
	for trial: int in 16:
		for row: int in owner._source_capacity:
			var roll: int = _rng.randi_range(0, 9)
			owner._o_present[row] = 1 if roll < 4 else (2 if roll == 4 and trial % 2 == 1 else 0)
			owner._o_kind[row] = Directory.KIND_RESIDENT if _rng.randi_range(0, 1) == 0 else Directory.KIND_ROOM
		for row: int in owner._region_capacity:
			var roll: int = _rng.randi_range(0, 9)
			owner._r_present[row] = 1 if roll < 4 else (3 if roll == 4 and trial % 4 == 3 else 0)
			owner._r_claim_kind[row] = Owner.CLAIM_ROOM if _rng.randi_range(0, 2) == 0 else Owner.CLAIM_NONE
		assert_equal(FinalFacts._required_checks(owner), _required_oracle(owner), "trial %d" % trial)


func test_final_facts_claim_walk_reads_exactly_the_scanned_rows() -> void:
	"""Decision 1952: with a non-binary region presence column the claim walk still skips absent and unclaimed rows and
	refuses the first present row in row order: a stale Room claim before a presence byte of 2 answers STALE."""
	var owner: Owner = _owner()
	assert_equal(FinalFacts._claims_refusal(owner), &"", "no claims")
	owner._r_present[1] = 1
	owner._r_claim_kind[1] = Owner.CLAIM_NONE
	owner._r_present[2] = 1
	owner._r_claim_kind[2] = Owner.CLAIM_ROOM
	owner._r_claim_slot[2] = 7
	owner._r_claim_generation[2] = 3
	owner._r_present[3] = 2
	assert_equal(FinalFacts._claims_refusal(owner), &"SPACE_SOURCE_STALE", "row 2 before row 3; unclaimed row 1 passed")
	owner._r_present[2] = 0
	assert_equal(FinalFacts._claims_refusal(owner), &"SPACE_REGION_FORMAT", "then the unknown presence byte")



class FakeRevision extends RefCounted:
	## Decision 1952: stands in for Profiles in the extent test.
	var revision: int = 0

	func content_revision() -> int:
		"""The fake catalog content revision."""
		return revision


class FakeResidents extends RefCounted:
	## Decision 1952: the one Residents column the occupancy walk reads.
	var _present: PackedByteArray = PackedByteArray()


class FakeMotion extends RefCounted:
	## Decision 1952: the one route bank the occupancy walk reads.
	var resident: PackedInt32Array = PackedInt32Array()


class FakeGraph extends RefCounted:
	## Decision 1952: the fields `occupancy_extent_fresh` and `next_occupancy_row` read from a Routes.
	var _residents: FakeResidents = FakeResidents.new()
	var _motion: FakeMotion = FakeMotion.new()
	var _profiles: FakeRevision = FakeRevision.new()
	var _extent_revision: int = 0


func _random_graph() -> FakeGraph:
	"""Random presence bytes (0, 1, 2) and route refs (null, slot -1 with a generation, a real pair)."""
	var graph: FakeGraph = FakeGraph.new()
	var capacity: int = Routes.RESIDENT_CAPACITY
	graph._residents._present.resize(capacity)
	graph._motion.resident.resize(Routes.R_GENERATION * capacity + capacity + capacity)
	for row: int in capacity:
		var roll: int = _rng.randi_range(0, 99)
		graph._residents._present[row] = 1 if roll < 4 else (2 if roll < 6 else 0)
		graph._motion.resident[Routes.R_SLOT * capacity + row] = 3 if _rng.randi_range(0, 99) < 4 else -1
		graph._motion.resident[Routes.R_GENERATION * capacity + row] = 1 if _rng.randi_range(0, 99) < 4 else 0
	return graph


func _occupancy_oracle(graph: FakeGraph, fresh: bool) -> PackedInt32Array:
	"""The rows the scan acts on: every row when stale, else all but unregistered rows whose Resident is absent."""
	var rows: PackedInt32Array = PackedInt32Array()
	var capacity: int = Routes.RESIDENT_CAPACITY
	for row: int in capacity:
		var unregistered: bool = graph._motion.resident[Routes.R_SLOT * capacity + row] == -1 \
			and graph._motion.resident[Routes.R_GENERATION * capacity + row] == 0
		if fresh and unregistered and graph._residents._present[row] != 1: continue
		rows.append(row)
	return rows


func _occupancy_walk(graph: FakeGraph, extent: bool) -> PackedInt32Array:
	"""The rows `next_occupancy_row` yields from row 0, the way the four occupancy scans call it."""
	var rows: PackedInt32Array = PackedInt32Array()
	var row: int = -1
	while true:
		row = Routes.next_occupancy_row(graph, row + 1, extent)
		if row >= Routes.RESIDENT_CAPACITY: break
		rows.append(row)
	return rows


func test_the_occupancy_walk_passes_over_exactly_the_rows_answering_nothing() -> void:
	"""Decision 1952: fresh, only unregistered rows whose Resident is not present are passed over (a presence
	byte of 2, a slot -1 with a generation and a slot with generation 0 are all still acted on); with a stale
	extent no row is, unless the scan makes no extent test."""
	for trial: int in 24:
		var graph: FakeGraph = _random_graph()
		graph._extent_revision = 3
		graph._profiles.revision = 3
		assert_equal(_occupancy_walk(graph, true), _occupancy_oracle(graph, true), "fresh walk %d" % trial)
		assert_equal(_occupancy_walk(graph, false), _occupancy_oracle(graph, true), "no extent test %d" % trial)
		graph._profiles.revision = 4
		assert_equal(_occupancy_walk(graph, true), _occupancy_oracle(graph, false), "stale walk %d" % trial)
		assert_equal(_occupancy_walk(graph, false), _occupancy_oracle(graph, true), "stale, no test %d" % trial)
	var empty: FakeGraph = _random_graph()
	empty._residents._present.fill(0)
	var capacity: int = Routes.RESIDENT_CAPACITY
	for row: int in capacity:
		empty._motion.resident[Routes.R_SLOT * capacity + row] = -1
		empty._motion.resident[Routes.R_GENERATION * capacity + row] = 0
	assert_equal(Routes.next_occupancy_row(empty, 0, false), capacity, "an empty graph has no row to check")
	assert_equal(Routes.next_occupancy_row(empty, 0), 0, "nor any skipped while the extent is unset")
	empty._residents._present[capacity - 1] = 1
	assert_equal(Routes.next_occupancy_row(empty, 0, false), capacity - 1, "the last row is reached")


func test_the_occupancy_extent_is_fresh_exactly_when_the_body_test_reaches_standing() -> void:
	"""Decision 1952: the same test `unregistered_body_refusal` makes before reading standing."""
	var graph: FakeGraph = FakeGraph.new()
	assert_false(Routes.occupancy_extent_fresh(graph), "an unset extent is stale")
	graph._extent_revision = 4
	graph._profiles.revision = 4
	assert_true(Routes.occupancy_extent_fresh(graph), "matching revisions are fresh")
	graph._profiles.revision = 5
	assert_false(Routes.occupancy_extent_fresh(graph), "a changed catalog is stale")
	graph._extent_revision = -5
	graph._profiles.revision = -5
	assert_false(Routes.occupancy_extent_fresh(graph), "a poisoned revision is stale")


func test_the_contact_region_walk_visits_exactly_the_present_rows() -> void:
	"""Decision 1952: the `present != 1` test admits only 1 bytes, so `find(1)` is exact for any byte values,
	and the walk stops at the region capacity."""
	var owner: Owner = _owner()
	for trial: int in 8:
		var expected: PackedInt32Array = PackedInt32Array()
		for row: int in owner._region_capacity:
			var roll: int = _rng.randi_range(0, 9)
			owner._r_present[row] = 1 if roll < 3 else (2 if roll == 3 else 0)
			if owner._r_present[row] == 1: expected.append(row)
		var visited: PackedInt32Array = PackedInt32Array()
		var row: int = Contacts._next_region(owner, 0)
		while row < owner._region_capacity:
			visited.append(row)
			row = Contacts._next_region(owner, row + 1)
		assert_equal(row, owner._region_capacity, "the walk ends at the capacity")
		assert_equal(visited, expected, "region walk %d" % trial)
	assert_equal(Contacts._next_region(owner, owner._region_capacity), owner._region_capacity, "from the end")


func _source_row_oracle(owner: Owner, ref: Vector2i) -> int:
	"""The pre-1952 `_resolve_source_row` scan (without its hint)."""
	var found: int = -1
	for row: int in owner._source_capacity:
		if owner._o_present[row] == 0 or owner._o_slot[row] != ref.x:
			continue
		if owner._o_present[row] != 1 or owner._o_generation[row] != ref.y or found >= 0:
			return -1
		found = row
	return found


func test_the_source_row_lookup_reads_only_rows_naming_the_slot() -> void:
	"""Decision 1952: Locations' source lookup walks `_o_slot.find(slot)`. Random slots, presence bytes 0/1/2 and
	generations, including absent rows that name the slot, duplicates and the null slot, answer as the full scan."""
	var owner: Owner = _owner()
	var locations: Locations = Locations.new()
	locations._owner = owner
	for trial: int in 24:
		for row: int in owner._source_capacity:
			var roll: int = _rng.randi_range(0, 9)
			owner._o_slot[row] = [-1, 3, 5, 7][_rng.randi_range(0, 3)] if roll < 7 else 9
			owner._o_present[row] = [0, 1, 1, 2][_rng.randi_range(0, 3)] if roll < 9 else 0
			owner._o_generation[row] = _rng.randi_range(1, 2)
		for ref: Vector2i in [Vector2i(3, 1), Vector2i(5, 2), Vector2i(7, 1), Vector2i(9, 1), Vector2i(-1, 0), Vector2i(11, 1)]:
			locations._resolve_source_ref = Vector2i(-1, 0)
			locations._resolve_source_hint = -1
			assert_equal(locations._resolve_source_row(ref), _source_row_oracle(owner, ref), "trial %d ref %s" % [trial, ref])
	for row: int in owner._source_capacity:
		owner._o_slot[row] = -1
		owner._o_present[row] = 0
	owner._o_slot[owner._source_capacity - 1] = 4
	owner._o_present[owner._source_capacity - 1] = 1
	owner._o_generation[owner._source_capacity - 1] = 1
	locations._resolve_source_ref = Vector2i(-1, 0)
	assert_equal(locations._resolve_source_row(Vector2i(4, 1)), owner._source_capacity - 1, "the last row is reached")


func test_the_framework_runs_every_suite_with_the_cache_checks_on() -> void:
	"""Decision 1952: test_case.gd's static initializer turns Profiles.CacheChecks.enabled on for the test process."""
	assert_true(Routes.Profiles.CacheChecks.enabled, "the runtime-cache checks are on")
