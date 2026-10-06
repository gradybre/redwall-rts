extends RefCounted
## ADR1197 G1/G2: read-only survey and suggestion of a first-entry origin. Every check is the same Terrain
## local-facts query SurfaceAnchor and Sites make at publication and cutting; nothing is staged or published.

const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-handling-v1/catalog_source.gd")
const CATALOG_ROW: int = 0 # The bundle structure has exactly one entry variant.
const CELL_U: int = 1024
const REFUSE_NONE_FOUND: StringName = &"ENTRY_SITE_NONE_FOUND"


static func survey(terrain: Terrain, frontier: Frontier, revision: int, origin: Vector3i) -> StringName:
	"""All nine endpoints need exterior air and untouched footing; every authored cut cube must be diggable."""
	if terrain == null or frontier == null: return &"ENTRY_SITE_OWNER"
	for index: int in WorkArea.ENDPOINTS:
		var code: StringName = terrain.local_facts_refusal(WorkArea.air(origin, index), Terrain.EXTERIOR, revision)
		if code == &"": code = terrain.local_facts_refusal(WorkArea.foot(origin, index), Terrain.FOOTING, revision)
		if code == &"": code = terrain.local_facts_refusal(WorkArea.foot(origin, index), Terrain.EXCLUSIONS, revision)
		if code != &"": return code
	return _cubes_refusal(terrain, frontier, revision, origin)


static func _cubes_refusal(terrain: Terrain, frontier: Frontier, revision: int, origin: Vector3i) -> StringName:
	"""Each Frontier episode's cube, translated by the origin, must be natural dry matter that may be dug."""
	var episode: PackedInt32Array = PackedInt32Array()
	episode.resize(Frontier.row_fields(Frontier.EPISODE))
	for ordinal: int in frontier.row_count(Frontier.EPISODE, frontier.content_revision()):
		var code: StringName = frontier.episode_into(ordinal, episode)
		if code != &"": return code
		var cube: PackedInt32Array = PackedInt32Array([episode[0] + origin.x, episode[1] + origin.y, episode[2] + origin.z,
			episode[3] + origin.x, episode[4] + origin.y, episode[5] + origin.z])
		code = terrain.local_facts_refusal(cube, Terrain.DIG, revision)
		if code != &"": return code
	return &""


static func suggest(terrain: Terrain, frontier: Frontier, revision: int, near: Vector3i, rings: int,
		out: PackedInt32Array) -> StringName:
	"""Stable outward search on the cube grid around near; the first fully surveyed origin is suggested."""
	if out.size() != 3: return &"ENTRY_SITE_OUTPUT"
	var center: Vector3i = Vector3i(_snap(near.x), near.y, _snap(near.z))
	for ring: int in rings + 1:
		for step: int in maxi(1, 8 * ring):
			var candidate: Vector3i = center + _ring_offset(ring, step) * CELL_U
			if survey(terrain, frontier, revision, candidate) != &"": continue
			out[0] = candidate.x; out[1] = candidate.y; out[2] = candidate.z
			return &""
	return REFUSE_NONE_FOUND


static func _snap(value: int) -> int:
	"""Origins sit on the cube grid so every authored cut lands on whole canonical keys."""
	return int(floor(float(value) / CELL_U)) * CELL_U


static func _ring_offset(ring: int, step: int) -> Vector3i:
	"""Walk the square ring of radius ring clockwise from its north-west corner; ring 0 is the center."""
	if ring == 0: return Vector3i.ZERO
	var side: int = 2 * ring
	@warning_ignore("integer_division") var edge: int = step / side
	var along: int = step % side
	match edge:
		0: return Vector3i(-ring + along, 0, -ring)
		1: return Vector3i(ring, 0, -ring + along)
		2: return Vector3i(ring - along, 0, ring)
	return Vector3i(-ring, 0, ring - along)


static func entry_plan(world: Vector2i, space_revision: int, origin: Vector3i, anchor: Vector2i,
		catalog: RefCounted, frontier: Frontier) -> EntryPlan.Request:
	"""Every field comes from the mounted bundle Catalog/Frontier and the published anchor; null on refusal."""
	var plan: EntryPlan.Request = EntryPlan.Request.new()
	plan.world = world; plan.space_revision = space_revision
	plan.base_level = 0; plan.origin_u = origin; plan.rotation = 0; plan.anchor = anchor
	plan.catalog_row = CATALOG_ROW; plan.catalog_revision = Bundle.CATALOG_REVISION
	plan.variant_revision = catalog._live.variant_revisions[CATALOG_ROW]
	plan.grouping_revision = Bundle.GROUPING_REVISION; plan.recipe_revision = Bundle.RECIPE_REVISION
	plan.frontier_revision = Bundle.FRONTIER_REVISION
	plan.source_digests.resize(128)
	for index: int in 96: plan.source_digests[index] = frontier._digests[32 + index]
	for index: int in 32: plan.source_digests[96 + index] = frontier._digests[index]
	var cut: PackedInt32Array = PackedInt32Array()
	cut.resize(Frontier.row_fields(Frontier.CUT))
	for row: int in frontier.row_count(Frontier.CUT, frontier.content_revision()):
		if frontier.cut_into(row, cut) != &"": return null
		plan.claims.append_array(PackedInt32Array([cut[0] + origin.x, cut[1] + origin.y, cut[2] + origin.z,
			cut[3] + origin.x, cut[4] + origin.y, cut[5] + origin.z]))
	plan.opening_targets = PackedInt32Array([-1, 0, -1, 0])
	return plan if EntryPlan.shape_refusal(plan) == &"" else null
