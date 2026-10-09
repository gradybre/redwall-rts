extends RefCounted
## Final actual recipe-source facts after all observation callbacks (decision1102).
## Static typed leaf reads add no bank, survey, mutable revision or content permission.

const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const REFUSE: StringName = &"CONNECTOR_RECIPE_SOURCE"


static func refusal(actual: Catalog, row: int, variant_revision: int, revision: int,
		expected_digest: PackedByteArray, digest_offset: int = 0) -> StringName:
	"""Read exact current underlying banks/wiring, never another overridable source observation."""
	if actual == null or not actual._configured or actual._loading or actual._live.header.size() != 11 \
			or actual._live.digests.size() != 96 or revision < 1 or revision != actual._live.header[0] \
			or row < 0 or row >= actual._live.header[1] or row >= Catalog.MAX_VARIANTS \
			or actual._live.variant_revisions.size() != Catalog.MAX_VARIANTS \
			or actual._live.variant_revisions[row] != variant_revision or variant_revision < 1:
		return REFUSE
	if expected_digest.size() < 32 or digest_offset < 0 or digest_offset > expected_digest.size() - 32:
		return REFUSE
	for index: int in 32:
		if actual._live.digests[index] != expected_digest[digest_offset + index]:
			return REFUSE
	if not _same_actual_owners(actual) or not _source_storage_matches(actual):
		return REFUSE
	return &"" if _source_digests_match(actual) else REFUSE


static func _same_actual_owners(actual: Catalog) -> bool:
	"""Use actual non-observing wiring and full Directory generation, never equal foreign IDs."""
	if actual._profiles == null or actual._levels == null or actual._movement == null \
			or actual._residents == null or actual._transforms == null:
		return false
	var ids: Directory = actual._residents._directory
	if ids == null or actual._levels._directory != ids or actual._movement._directory != ids \
			or actual._movement._residents != actual._residents \
			or actual._movement._transforms != actual._transforms or actual._transforms._directory != ids \
			or actual._levels._identity.size() != Levels.IDENTITY_FIELDS:
		return false
	var world: Vector2i = Vector2i(actual._levels._identity[0], actual._levels._identity[1])
	return ids.is_valid_of_kind(world, Directory.KIND_WORLD)


static func _source_storage_matches(actual: Catalog) -> bool:
	"""Positive exact revisions and bounded actual digest spans precede the fixed leaf comparison."""
	if actual._profiles._loading or actual._profiles._live.header.size() != 4 \
			or actual._live.header[8] < 1 or actual._live.header[8] != actual._profiles._live.header[0] \
			or actual._live.header[9] < 1 or actual._live.header[9] != actual._levels._revision \
			or actual._levels._digest.size() != 32:
		return false
	var source_id: int = actual._live.header[10]
	return source_id >= 0 and source_id < actual._profiles._live.header[3] \
		and source_id < actual._profiles._source_capacity \
		and actual._profiles._live.sources.size() == actual._profiles._source_capacity * 32


static func _source_digests_match(actual: Catalog) -> bool:
	"""No source callback or temporary hash buffer follows this final immutable-byte comparison."""
	var source_offset: int = actual._live.header[10] * 32
	for index: int in 32:
		if actual._live.digests[32 + index] != actual._profiles._live.sources[source_offset + index] \
				or actual._live.digests[64 + index] != actual._levels._digest[index]:
			return false
	return true
