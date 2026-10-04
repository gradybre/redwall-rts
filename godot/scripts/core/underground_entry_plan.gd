extends RefCounted
## Cold caller input for one non-flat permanent Corridor. This packet grants no construction permission.
## Actual entry bindings attest every source/claim/contact before RoomOrders publishes. Decision1108.

const Space := preload("res://scripts/core/room_space.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE: StringName = &"ENTRY_PLAN_INVALID"
const SOURCE_BYTES: int = 128 # Catalog, assembly grouping, recipes, physical frontier SHA256.
const SCALAR_BYTES: int = 100

class Request extends RefCounted:

	var world: Vector2i = NULL_REF
	var space_revision: int = 0
	var base_level: int = -1
	var origin_u: Vector3i = Vector3i.ZERO
	var rotation: int = -1
	var anchor: Vector2i = NULL_REF
	var catalog_row: int = -1
	var catalog_revision: int = 0
	var variant_revision: int = 0
	var grouping_revision: int = 0
	var recipe_revision: int = 0
	var frontier_revision: int = 0
	var source_digests: PackedByteArray = PackedByteArray()
	var claims: PackedInt32Array = PackedInt32Array() # Absolute world boxes; overlaps share paid keys.
	var opening_targets: PackedInt32Array = PackedInt32Array() # Room/section pairs, or paired null for self.


static func payload_bytes(plan: Request) -> int:
	"""Count this one image; callers separately admit simultaneous copies, cursors, surveys and native headers."""
	return SCALAR_BYTES + SOURCE_BYTES + 4 * (plan.claims.size() + plan.opening_targets.size())


static func shape_refusal(plan: Request) -> StringName:
	"""Bound all dimensions without allocation; actual World/catalog/frontier truth is a separate gate."""
	if plan == null or not Space.Value.valid_ref(plan.world) or not Space.Value.valid_ref(plan.anchor) \
			or plan.space_revision < 1 or plan.base_level < 0 or plan.base_level > Space.I32_MAX \
			or plan.rotation < 0 or plan.rotation > 3 or plan.catalog_row < 0 or plan.catalog_row >= Catalog.MAX_VARIANTS:
		return REFUSE
	if plan.catalog_revision < 1 or plan.variant_revision < 1 or plan.grouping_revision < 1 \
			or plan.recipe_revision < 1 or plan.frontier_revision < 1 or plan.source_digests.size() != SOURCE_BYTES:
		return REFUSE
	if plan.claims.is_empty() or plan.claims.size() % 6 != 0 or plan.claims.size() > Space.MAX_REGIONS * 6 \
			or plan.opening_targets.is_empty() or plan.opening_targets.size() % 4 != 0 \
			or plan.opening_targets.size() > Catalog.MAX_OPENINGS_PER_VARIANT * 4:
		return REFUSE
	for offset: int in range(0, plan.claims.size(), 6):
		for axis: int in 3:
			if plan.claims[offset + axis] >= plan.claims[offset + axis + 3]:
				return REFUSE
	return _targets_refusal(plan.opening_targets)


static func _targets_refusal(targets: PackedInt32Array) -> StringName:
	"""Only a complete null pair denotes an unconnected draft end; partial/fabricated references refuse."""
	for offset: int in range(0, targets.size(), 4):
		var room: Vector2i = Vector2i(targets[offset], targets[offset + 1])
		var section: Vector2i = Vector2i(targets[offset + 2], targets[offset + 3])
		if room == NULL_REF and section == NULL_REF:
			continue
		if not Space.Value.valid_ref(room) or not Space.Value.valid_ref(section):
			return REFUSE
	return &""


static func copy_into(source: Request, target: Request) -> void:
	"""The actual original cold lease and full shape/size must be checked immediately before these copies."""
	target.world = source.world
	target.space_revision = source.space_revision
	target.base_level = source.base_level
	target.origin_u = source.origin_u
	target.rotation = source.rotation
	target.anchor = source.anchor
	target.catalog_row = source.catalog_row
	target.catalog_revision = source.catalog_revision
	target.variant_revision = source.variant_revision
	target.grouping_revision = source.grouping_revision
	target.recipe_revision = source.recipe_revision
	target.frontier_revision = source.frontier_revision
	target.source_digests = source.source_digests.duplicate()
	target.claims = source.claims.duplicate()
	target.opening_targets = source.opening_targets.duplicate()


static func same(first: Request, second: Request) -> bool:
	"""Compare every proposed input and immutable-source pin without a callback or a new packed image."""
	return first != null and second != null and first.world == second.world \
		and first.space_revision == second.space_revision and first.base_level == second.base_level \
		and first.origin_u == second.origin_u and first.rotation == second.rotation and first.anchor == second.anchor \
		and first.catalog_row == second.catalog_row and first.catalog_revision == second.catalog_revision \
		and first.variant_revision == second.variant_revision and first.grouping_revision == second.grouping_revision \
		and first.recipe_revision == second.recipe_revision and first.frontier_revision == second.frontier_revision \
		and first.source_digests == second.source_digests and first.claims == second.claims \
		and first.opening_targets == second.opening_targets
