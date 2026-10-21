extends RefCounted
## Fresh static Room travel within one source-compatible heading family. No actor or READY permission.

const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const SourceProgram := preload("res://data/underground/mole-worker/work-approach-v1/source_program.gd")
const StepProgram := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_FAMILY: StringName = &"ROOM_ITINERARY_SOURCE_FAMILY"
## Decision 1970 (F2): a search memo slot's layout (WorldRoutes.SEARCH_MEMO_STRIDE words): SEARCH_KEY key words, then
## the spend, the chain length, the descriptor's five fields and the descriptor-write count.
const SEARCH_KEY: int = 19
const S_SPENT: int = 19
const S_COUNT: int = 20
const S_DESCRIPTOR: int = 21
const S_WRITES: int = 26

## Decision 1970 (F2): one fixed key packet the memo compares against (SEARCH_KEY words), allocated once.
static var _search_key: PackedInt64Array = PackedInt64Array()


static func reachability_refusal(actual: WorldRoutes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int, checks: int, out: PackedInt32Array) -> StringName:
	"""Reuse original search storage synchronously; publish remaining work only after every final source leaf."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes if actual != null and actual._routes_ref != null else null
	var owner: Owner = actual._owner_ref.get_ref() as Owner if actual != null and actual._owner_ref != null else null
	var locations: Locations = actual._locations_ref.get_ref() as Locations if actual != null and actual._locations_ref != null else null
	var sources: Owner.CoreSources = actual._sources_ref.get_ref() as Owner.CoreSources if actual != null and actual._sources_ref != null else null
	var code: StringName = _implementations(actual, graph, owner, locations)
	if code == &"": code = WorldRoutes._reach_entry_refusal(actual, graph, owner, locations, sources, checks, out)
	if code != &"": return code
	actual._reading = true; graph._searching = true
	graph._remaining = checks; graph._operation_error = &""
	actual._witness_serial = 0
	code = _search(actual, first, last, anchor, revision, content)
	if code == &"": out[0] = graph._remaining
	graph._searching = false; actual._reading = false
	return code


static func _implementations(actual: WorldRoutes, graph: Routes, owner: Owner, locations: Locations) -> StringName:
	"""Private pure helpers are used only on the concrete original implementations, never a caller override."""
	if actual == null or actual.get_script() != WorldRoutes or graph == null or graph.get_script() != Routes \
			or owner == null or owner.get_script() != Owner or locations == null or locations.get_script() != Locations \
			or actual._profiles == null or actual._profiles.get_script() != Profiles \
			or locations._ids == null or locations._ids.get_script() != Directory:
		return WorldRoutes.REFUSE_BINDING
	return &""


static func _search(actual: WorldRoutes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int) -> StringName:
	"""Charge the complete boundaries and array initialization before touching the original graph scratch."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes
	var owner: Owner = actual._owner_ref.get_ref() as Owner
	var locations: Locations = actual._locations_ref.get_ref() as Locations
	if not graph._spend(WorldRoutes.REACH_SCOPE_CHECKS + 4 * graph._location_capacity): return graph._operation_error
	var code: StringName = WorldRoutes._reach_stores_refusal(actual, graph, owner, locations)
	if code == &"": code = WorldRoutes._reach_descriptor(actual, anchor, revision, content)
	if code == &"": code = _anchor_refusal(actual._profiles, anchor, revision, content)
	if code == &"" and (not locations._live_ref(locations._live, first) or not locations._live_ref(locations._live, last)):
		code = &"ROUTE_LOCATION_STALE"
	if code == &"": code = _chain_refusal(actual, graph, first, last, anchor, revision, content)
	if code != &"": return code
	if not graph._spend(WorldRoutes.REACH_SCOPE_CHECKS): return graph._operation_error
	return WorldRoutes._reach_stores_refusal(actual, graph, owner, locations)


static func _chain_refusal(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int) -> StringName:
	"""Decision 1970 (F2): the chain search, check and source re-reads, answered from the search memo (its spend and
	scratch replayed) while every input it read is unchanged; with the framework's cache checks on, replayed, put back,
	run live and compared."""
	var at: int = _search_memo_at(actual, graph, first, last, anchor, revision, content)
	if at >= 0 and not Profiles.CacheChecks.enabled:
		_replay_search(actual, graph, at)
		return &""
	if at >= 0: return _checked_search(actual, graph, first, last, anchor, revision, content, at)
	return _remembered_search(actual, graph, first, last, anchor, revision, content)


static func _live_chain(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, content: int) -> StringName:
	"""The search itself: Dijkstra, the collected chain's check, then every endpoint, section and edge choice again."""
	var owner: Owner = actual._owner_ref.get_ref() as Owner
	var code: StringName = _find(actual, first, last, anchor)
	if code == &"": code = graph._path_chain_refusal(first, last, owner._header[17], content, actual)
	if code == &"": code = _sources(actual, first, anchor)
	return code


static func _remembered_search(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int) -> StringName:
	"""Decision 1970: the live search; a success is remembered with its spend and what it left."""
	var before: int = graph._remaining
	var writes: int = actual._descriptor_writes
	var code: StringName = _live_chain(actual, graph, first, last, anchor, content)
	if code == &"" and graph._operation_error == &"":
		_remember_search(actual, graph, first, last, anchor, revision, content, before - graph._remaining,
			actual._descriptor_writes - writes)
	return code


static func _search_key_into(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int, out: PackedInt64Array) -> bool:
	"""Decision 1970: the inputs the search reads, as WorldRoutes' witness keys them (each owner's instance and
	publication receipt), plus the certificates, the Profiles bank and load token, the catalog and levels revisions and
	the query; false when any receipt is unavailable (zero after a restore, or a loading store)."""
	var owner: Owner = actual._owner_ref.get_ref() as Owner
	var locations: Locations = actual._locations_ref.get_ref() as Locations
	var profiles: Profiles = actual._profiles
	if owner == null or locations == null or profiles == null or profiles._loading or profiles._live == null \
			or graph._last_published_token <= 0 or owner._last_published_token <= 0 \
			or locations._last_published_token <= 0 or actual._certificate_revision <= 0 \
			or profiles.load_revision() == 0 or actual._levels == null: return false
	if out.size() != SEARCH_KEY: out.resize(SEARCH_KEY)
	out[0] = graph.get_instance_id(); out[1] = graph._last_published_token; out[2] = owner.get_instance_id()
	out[3] = owner._last_published_token; out[4] = owner._header[17]; out[5] = locations.get_instance_id()
	out[6] = locations._last_published_token; out[7] = actual._certificate_revision
	out[8] = profiles._live.get_instance_id(); out[9] = profiles.load_revision(); out[10] = actual._live_catalog_revision
	out[11] = actual._levels._revision; out[12] = first.x; out[13] = first.y; out[14] = last.x; out[15] = last.y
	out[16] = anchor; out[17] = revision; out[18] = content
	return true


static func _search_memo_slot(first: Vector2i, last: Vector2i, anchor: int) -> int:
	"""A direct-mapped slot; a collision is only a miss."""
	return posmod(first.x * 31 + last.x * 7 + anchor, WorldRoutes.SEARCH_MEMO_SLOTS)


static func _search_memo_at(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int) -> int:
	"""Decision 1970: the offset of the slot that answers this search, or -1. Only with no recorded fault, a budget that
	covers the whole remembered spend, the same key, and every Room the chain's sections name still the one the search
	resolved (Buildings and the Directory carry no publication receipt, so `_sections_hold` re-reads them)."""
	var memo: PackedInt64Array = actual._search_memo
	if memo.size() != WorldRoutes.SEARCH_MEMO_SLOTS * WorldRoutes.SEARCH_MEMO_STRIDE or graph._operation_error != &"" \
			or not _search_key_into(actual, graph, first, last, anchor, revision, content, _search_key):
		return -1
	var at: int = _search_memo_slot(first, last, anchor) * WorldRoutes.SEARCH_MEMO_STRIDE
	for index: int in SEARCH_KEY:
		if memo[at + index] != _search_key[index]: return -1
	if memo[at + S_SPENT] > graph._remaining: return -1
	return at if _sections_hold(actual, graph, first, at) else -1


static func _sections_hold(actual: WorldRoutes, graph: Routes, first: Vector2i, at: int) -> bool:
	"""Decision 1970: the same `Locations._resolve_section_refusal` calls `_sources` made for this chain, in its order
	and with its arguments (so Locations' source hint is left as the live search leaves it), each still passing."""
	var owner: Owner = actual._owner_ref.get_ref() as Owner
	var locations: Locations = actual._locations_ref.get_ref() as Locations
	var section: Vector2i = locations._ref_at(locations._live, Locations.SECTION_SLOT, first.x)
	if not _section_holds(owner, locations, section): return false
	var count: int = actual._search_memo[at + S_COUNT]
	@warning_ignore("integer_division") var chain: int = (at / WorldRoutes.SEARCH_MEMO_STRIDE) * 2 * WorldRoutes.SEARCH_CHAIN_EDGES
	for index: int in count:
		var row: int = actual._search_chains[chain + (count - index - 1) * 2]
		var next: Vector2i = graph._edge_pair(graph._live, Routes.E_SECTION_SLOT, row)
		if next != section:
			if not _section_holds(owner, locations, next): return false
			section = next
		var to: Vector2i = graph._edge_pair(graph._live, Routes.E_TO_SLOT, row)
		var reached: Vector2i = locations._ref_at(locations._live, Locations.SECTION_SLOT, to.x)
		if reached != section and not _section_holds(owner, locations, reached): return false
		section = reached
	return true


static func _section_holds(owner: Owner, locations: Locations, section: Vector2i) -> bool:
	"""`WorldRoutes._reach_section_refusal`'s leaf without its precharge (the replay charges the whole spend)."""
	if not owner._region_live(section, false): return false
	var room: Vector2i = Vector2i(owner._r_owner_slot[section.x], owner._r_owner_generation[section.x])
	if room == locations._world: room = NULL_REF
	return locations._resolve_section_refusal(room, section, owner._r_level[section.x],
		Vector3i(owner._r_lo_x[section.x], owner._r_lo_y[section.x], owner._r_lo_z[section.x])) == &""


static func _replay_search(actual: WorldRoutes, graph: Routes, at: int) -> void:
	"""Decision 1970: what the live chain search leaves that anything reads afterwards: the spend, the path serial
	step `_find` takes, the proposed chain, and the search descriptor as its last write left it. The distance,
	predecessor, heap and state scratch is read outside a search only by `_witness_chain_matches`, which the serial
	step (with `reachability_refusal`'s zeroed witness serial) keeps from matching, as after a live search."""
	var memo: PackedInt64Array = actual._search_memo
	graph._remaining -= memo[at + S_SPENT]
	if graph._path_serial > 0: graph._path_serial = 0 if graph._path_serial == Routes.I64_MAX else graph._path_serial + 1
	var count: int = memo[at + S_COUNT]
	@warning_ignore("integer_division") var chain: int = (at / WorldRoutes.SEARCH_MEMO_STRIDE) * 2 * WorldRoutes.SEARCH_CHAIN_EDGES
	for index: int in 2 * count: graph._proposed_edges[index] = actual._search_chains[chain + index]
	graph._proposed_count = count
	var descriptor: Profiles.Descriptor = actual._descriptor
	descriptor.profile_id = memo[at + S_DESCRIPTOR]
	descriptor.profile_revision = memo[at + S_DESCRIPTOR + 1]
	descriptor.content_revision = memo[at + S_DESCRIPTOR + 2]
	descriptor.mode = memo[at + S_DESCRIPTOR + 3]
	descriptor.posture = memo[at + S_DESCRIPTOR + 4]
	actual._descriptor_writes += memo[at + S_WRITES]


static func _remember_search(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i, anchor: int,
		revision: int, content: int, spent: int, writes: int) -> void:
	"""Decision 1970: keep one successful search; a chain longer than a slot holds is not kept."""
	var memo: PackedInt64Array = actual._search_memo
	if memo.size() != WorldRoutes.SEARCH_MEMO_SLOTS * WorldRoutes.SEARCH_MEMO_STRIDE or spent < 0 \
			or graph._proposed_count < 0 or graph._proposed_count > WorldRoutes.SEARCH_CHAIN_EDGES \
			or not _search_key_into(actual, graph, first, last, anchor, revision, content, _search_key): return
	var at: int = _search_memo_slot(first, last, anchor) * WorldRoutes.SEARCH_MEMO_STRIDE
	for index: int in SEARCH_KEY: memo[at + index] = _search_key[index]
	memo[at + S_SPENT] = spent
	memo[at + S_COUNT] = graph._proposed_count
	var descriptor: Profiles.Descriptor = actual._descriptor
	memo[at + S_DESCRIPTOR] = descriptor.profile_id
	memo[at + S_DESCRIPTOR + 1] = descriptor.profile_revision
	memo[at + S_DESCRIPTOR + 2] = descriptor.content_revision
	memo[at + S_DESCRIPTOR + 3] = descriptor.mode
	memo[at + S_DESCRIPTOR + 4] = descriptor.posture
	memo[at + S_WRITES] = writes
	@warning_ignore("integer_division") var chain: int = (at / WorldRoutes.SEARCH_MEMO_STRIDE) * 2 * WorldRoutes.SEARCH_CHAIN_EDGES
	for index: int in 2 * graph._proposed_count: actual._search_chains[chain + index] = graph._proposed_edges[index]


static func search_scratch(actual: WorldRoutes, graph: Routes) -> PackedInt64Array:
	"""Decision 1970, checks on only (never on the game's path): what a chain search leaves that is read afterwards,
	as one comparable packet: budget, fault, serial, descriptor fields, and the proposed chain. The descriptor-write
	count is not in it: only its change within one edge choice is ever read (`_remembered_edge_profile`), and an edge
	choice answered from the edge memo writes once where the live choice wrote once per row it tried."""
	var d: Profiles.Descriptor = actual._descriptor
	var out: PackedInt64Array = PackedInt64Array([graph._remaining, 1 if graph._operation_error != &"" else 0,
		graph._path_serial, d.profile_id, d.profile_revision, d.content_revision, d.mode, d.posture,
		graph._proposed_count])
	for index: int in 2 * maxi(graph._proposed_count, 0): out.append(graph._proposed_edges[index])
	return out


static func _restore_scratch(actual: WorldRoutes, graph: Routes, state: PackedInt64Array) -> void:
	"""Decision 1970, checks on only: put back a packet from `search_scratch` (the fault was empty: checked hits only)."""
	var d: Profiles.Descriptor = actual._descriptor
	graph._remaining = state[0]
	graph._path_serial = state[2]
	d.profile_id = state[3]
	d.profile_revision = state[4]
	d.content_revision = state[5]
	d.mode = state[6]
	d.posture = state[7]
	graph._proposed_count = state[8]
	for index: int in state.size() - 9: graph._proposed_edges[index] = state[9 + index]


static func _checked_search(actual: WorldRoutes, graph: Routes, first: Vector2i, last: Vector2i,
		anchor: int, revision: int, content: int, at: int) -> StringName:
	"""Decision 1970, checks on: run the replay the game would run and keep what it leaves, put it back, then search
	live (the answer used) and report any difference."""
	var before: PackedInt64Array = search_scratch(actual, graph)
	_replay_search(actual, graph, at)
	var replayed: PackedInt64Array = search_scratch(actual, graph)
	_restore_scratch(actual, graph, before)
	var code: StringName = _remembered_search(actual, graph, first, last, anchor, revision, content)
	var live: PackedInt64Array = search_scratch(actual, graph)
	if code != &"" or live != replayed:
		Profiles.CacheChecks.report("itinerary search", "an input changed without moving its receipt (%s)" % code)
	return code


static func _anchor_refusal(profiles: Profiles, anchor: int, revision: int, content: int) -> StringName:
	"""Decision 1952: the anchor check, answered from Profiles' anchor memo while its bank and load revision are the ones
	it was read at (with the framework's cache checks on, read live and compared)."""
	var at: int = _anchor_memo_at(profiles, anchor, revision, content)
	if at >= 0 and not Profiles.CacheChecks.enabled:
		return REFUSE_FAMILY if profiles._anchor_memo[at + 5] == 1 else &""
	var code: StringName = _anchor_refusal_live(profiles, anchor, revision, content)
	if at >= 0 and (profiles._anchor_memo[at + 5] == 1) != (code != &""):
		Profiles.CacheChecks.report("anchor check", "anchor %d: Profiles bank edited in place" % anchor)
	_remember_anchor(profiles, anchor, revision, content, code)
	return code


static func _anchor_memo_at(profiles: Profiles, anchor: int, revision: int, content: int) -> int:
	"""Decision 1952: the offset of the slot that answers this check, or -1 (also for a loading or poisoned store)."""
	var token: int = profiles.load_revision() if profiles._live != null and not profiles._loading else 0
	var at: int = posmod(anchor, Profiles.ANCHOR_MEMO_SLOTS) * Profiles.ANCHOR_MEMO_STRIDE
	var memo: PackedInt64Array = profiles._anchor_memo
	if token == 0 or memo.size() != Profiles.ANCHOR_MEMO_SLOTS * Profiles.ANCHOR_MEMO_STRIDE or memo[at] != token \
			or memo[at + 1] != profiles._live.get_instance_id() or memo[at + 2] != anchor or memo[at + 3] != revision \
			or memo[at + 4] != content: return -1
	return at


static func _remember_anchor(profiles: Profiles, anchor: int, revision: int, content: int, code: StringName) -> void:
	"""Decision 1952: keep one answer, keyed on the store's current token and bank."""
	var token: int = profiles.load_revision() if profiles._live != null and not profiles._loading else 0
	if token == 0 or profiles._anchor_memo.size() != Profiles.ANCHOR_MEMO_SLOTS * Profiles.ANCHOR_MEMO_STRIDE: return
	var at: int = posmod(anchor, Profiles.ANCHOR_MEMO_SLOTS) * Profiles.ANCHOR_MEMO_STRIDE
	profiles._anchor_memo[at] = token
	profiles._anchor_memo[at + 1] = profiles._live.get_instance_id()
	profiles._anchor_memo[at + 2] = anchor
	profiles._anchor_memo[at + 3] = revision
	profiles._anchor_memo[at + 4] = content
	profiles._anchor_memo[at + 5] = 1 if code != &"" else 0


static func _anchor_refusal_live(profiles: Profiles, anchor: int, revision: int, content: int) -> StringName:
	"""The exact finite forward/backward programme fixes heading and source; ordinary untagged rows are not anchors.
	Decision 1939: a program-owned source's (the claws') READY row anchors its own family."""
	if _owned(profiles, anchor):
		var policy: int = Profiles.selection_policy_leaf(profiles, anchor, revision, content)
		return &"" if (policy == Profiles.POLICY_READY_FORWARD or policy == Profiles.POLICY_READY_BACKWARD) \
			and Routes._source_profile_refusal(profiles, anchor, revision, content) == &"" else REFUSE_FAMILY
	if Routes._step_closure(profiles):
		return &"" if anchor >= 2 and anchor < StepProgram.GROUND \
			and StepProgram.profile_refusal(profiles, anchor, revision, content) == &"" else REFUSE_FAMILY
	if SourceProgram.profile_refusal(profiles, anchor, revision, content) != &"" \
			or anchor < 2 or anchor >= 10:
		return REFUSE_FAMILY
	return &""


static func _find(actual: WorldRoutes, first: Vector2i, last: Vector2i, anchor: int) -> StringName:
	"""Existing positive-length Dijkstra and its stable heap/predecessor rules select a complete directed chain."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes
	if graph._path_serial > 0: graph._path_serial = 0 if graph._path_serial == Routes.I64_MAX else graph._path_serial + 1
	graph._distance.fill(Routes.I64_MAX); graph._predecessor.fill(-1)
	graph._heap_position.fill(-1); graph._search_state.fill(0)
	graph._heap_count = 0; graph._proposed_count = 0
	graph._distance[first.x] = 0; graph._heap_insert(first.x)
	while graph._heap_count > 0:
		if graph._operation_error != &"" or not graph._spend(): return graph._operation_error
		var node: int = graph._heap_take()
		if graph._operation_error != &"": return graph._operation_error
		graph._search_state[node] = 2
		if node == last.x: return graph._collect_path(first, last)
		var generation: int = first.y if node == first.x else graph._edge_i32(graph._live, Routes.E_TO_GENERATION, graph._predecessor[node])
		var code: StringName = _relax(actual, Vector2i(node, generation), anchor)
		if code != &"": return code
	return &"ROUTE_NOT_CONNECTED"


static func _relax(actual: WorldRoutes, origin: Vector2i, anchor: int) -> StringName:
	"""Inspect only actual outgoing edges and complete current masks; endpoint proximity never creates a leg."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes
	var posture: int = actual._profiles._live.fields[Profiles.F_POSTURE * actual._profiles._profile_capacity + anchor]
	var index: int = graph._first_edge_index(origin)
	while index < graph._live.edge_count:
		if not graph._spend(): return graph._operation_error
		var row: int = graph._live.ordered[index]
		if graph._edge_pair(graph._live, Routes.E_FROM_SLOT, row) != origin: break
		index += 1
		if not graph._path_terms_match(row, Profiles.MODE_WALK, posture): continue
		if not graph._path_edge_current(row, actual): return &"ROUTE_EDGE_REVISION"
		var next: Vector2i = graph._edge_pair(graph._live, Routes.E_TO_SLOT, row)
		if not graph._path_location_live(next, actual): return &"ROUTE_LOCATION_STALE"
		if graph._search_state[next.x] == 2: continue
		var profile: int = _edge_profile(actual, row, anchor)
		if graph._operation_error != &"": return graph._operation_error
		if profile < 0: continue
		var length: int = graph._edge_i64(graph._live, Routes.E_LENGTH, row)
		if length <= 0 or graph._distance[origin.x] > Routes.I64_MAX - length: return &"ROUTE_DISTANCE_OVERFLOW"
		graph._relax(next.x, row, graph._distance[origin.x] + length)
	return graph._operation_error


static func _edge_profile(actual: WorldRoutes, edge: int, anchor: int) -> int:
	"""Choose the first exact compatible bit in the original mask, spending every attempted row and source check.
	Decision 1952: answered from WorldRoutes' memo, spend and descriptor write replayed, while every input is unchanged."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes
	var at: int = WorldRoutes.edge_memo_hit(actual, graph, edge, anchor)
	if at >= 0 and not Profiles.CacheChecks.enabled: return WorldRoutes.replay_edge_profile(actual, graph, at)
	if at >= 0: return _checked_edge_profile(actual, graph, edge, anchor, at)
	return _remembered_edge_profile(actual, graph, edge, anchor)


static func _remembered_edge_profile(actual: WorldRoutes, graph: Routes, edge: int, anchor: int) -> int:
	"""Decision 1952: the live choice, then remembered with its spend and whether it wrote the descriptor."""
	var epoch: int = WorldRoutes.edge_memo_epoch(actual, graph)
	var before: int = graph._remaining
	var writes: int = actual._descriptor_writes
	var row: int = _edge_profile_live(actual, graph, edge, anchor)
	WorldRoutes.remember_edge_profile(actual, graph, edge, anchor, row, before - graph._remaining,
		writes != actual._descriptor_writes, epoch)
	return row


static func _checked_edge_profile(actual: WorldRoutes, graph: Routes, edge: int, anchor: int, at: int) -> int:
	"""Decision 1952, checks on: run the replay the game would run and keep what it leaves (budget and descriptor),
	put both back, then choose live (the choice used) and report any difference."""
	var before: PackedInt64Array = WorldRoutes.search_state(actual, graph)
	var replayed: int = WorldRoutes.replay_edge_profile(actual, graph, at)
	var after_replay: PackedInt64Array = WorldRoutes.search_state(actual, graph)
	WorldRoutes.restore_search_state(actual, graph, before)
	var row: int = _remembered_edge_profile(actual, graph, edge, anchor)
	if row != replayed or graph._operation_error != &"" or WorldRoutes.search_state(actual, graph) != after_replay:
		Profiles.CacheChecks.report("itinerary edge profile", "edge %d: an input changed without moving its token" % edge)
	return row


static func _edge_profile_live(actual: WorldRoutes, graph: Routes, edge: int, anchor: int) -> int:
	"""The choice itself, read from the current certificates and Profiles bank."""
	var profiles: Profiles = actual._profiles
	for row: int in profiles._live.header[1]:
		if not graph._spend(16): return -1
		if not actual._live.admits(edge, row): continue
		if not graph._spend(192): return -1
		if not _compatible(profiles, anchor, row): continue
		if WorldRoutes._reach_descriptor(actual, row, profiles._live.quantities[row], profiles._live.header[0]) != &"": continue
		if graph._committed_mask_refusal(edge, actual) == &"": return row
		if graph._operation_error != &"": return -1
	return -1


static func family_row(profiles: Profiles, anchor: int, yaw: int, policy: int) -> int:
	"""ADR1213: the lowest certified exact-yaw row of this policy that shares the anchor's actor/tool/cargo identity."""
	var stride: int = profiles._profile_capacity
	if anchor < 0 or anchor >= profiles._live.header[1]: return -1
	for row: int in profiles._live.header[1]:
		if profiles._live.flags[row] != Profiles.CERT_REQUIRED or profiles._live.fields[Profiles.F_YAW_KIND * stride + row] != Profiles.YAW_EXACT \
				or profiles._live.fields[Profiles.F_YAW * stride + row] != yaw \
				or Profiles.selection_policy_leaf(profiles, row, profiles._live.quantities[row], profiles._live.header[0]) != policy: continue
		var same: bool = true
		for field: int in 10: same = same and profiles._live.fields[field * stride + row] == profiles._live.fields[field * stride + anchor]
		for field: int in range(Profiles.L_QUANTITY_MIN, Profiles.L_QUANTITY_MAX + 1):
			same = same and profiles._live.quantities[field * stride + row] == profiles._live.quantities[field * stride + anchor]
		if same: return row
	return -1


static func _compatible(profiles: Profiles, anchor: int, row: int) -> bool:
	"""Identical payload and heading families share READY; only the same source's complete all-yaw WALK is included."""
	var stride: int = profiles._profile_capacity
	if row < 0 or row >= profiles._live.header[1] or profiles._live.flags[row] != Profiles.CERT_REQUIRED: return false
	for field: int in 10:
		if profiles._live.fields[field * stride + row] != profiles._live.fields[field * stride + anchor]: return false
	for field: int in range(Profiles.L_QUANTITY_MIN, Profiles.L_QUANTITY_MAX + 1):
		if profiles._live.quantities[field * stride + row] != profiles._live.quantities[field * stride + anchor]: return false
	if _owned(profiles, anchor): return _owned_compatible(profiles, anchor, row)
	if Routes._step_closure(profiles):
		return _canonical_compatible(profiles, anchor, row)
	var policy: int = Profiles.selection_policy_leaf(profiles, row, profiles._live.quantities[row], profiles._live.header[0])
	if policy == Profiles.POLICY_AUTOMATIC:
		return row == 1 and profiles._live.fields[Profiles.F_YAW_KIND * stride + row] == Profiles.YAW_ALL
	return row >= 2 and row < 10 and profiles._live.fields[Profiles.F_YAW * stride + row] \
		== profiles._live.fields[Profiles.F_YAW * stride + anchor] \
		and SourceProgram.profile_refusal(profiles, row, profiles._live.quantities[row], profiles._live.header[0]) == &""


static func _owned(profiles: Profiles, row: int) -> bool:
	"""Decision 1939: a row of a source its own program owns (the claws, Routes' `_source_owner`), not the parent or
	step program's source 0, whose rows the fixed positions below describe."""
	return Routes._source_owner(profiles, row, profiles._live.header[0]) >= 0


static func _owned_compatible(profiles: Profiles, anchor: int, row: int) -> bool:
	"""Decision 1939: in a program-owned family, the READY and short-step rows at the anchor's heading and the source's
	all-yaw canonical ground WALK share travel, each passing its owner's own source proof (Routes'). Stair and other
	rows are not travel legs."""
	var stride: int = profiles._profile_capacity
	var revision: int = profiles._live.quantities[row]
	var policy: int = Profiles.selection_policy_leaf(profiles, row, revision, profiles._live.header[0])
	var exact: bool = profiles._live.fields[Profiles.F_YAW_KIND * stride + row] == Profiles.YAW_EXACT \
		and profiles._live.fields[Profiles.F_YAW * stride + row] == profiles._live.fields[Profiles.F_YAW * stride + anchor]
	var travel: bool = exact and (policy == Profiles.POLICY_READY_FORWARD or policy == Profiles.POLICY_READY_BACKWARD \
		or policy == Profiles.POLICY_SHORT_FORWARD or policy == Profiles.POLICY_SHORT_BACKWARD)
	var ground: bool = policy == Profiles.POLICY_CANONICAL_GROUND \
		and profiles._live.fields[Profiles.F_YAW_KIND * stride + row] == Profiles.YAW_ALL \
		and profiles._live.fields[Profiles.F_MODE * stride + row] == Profiles.MODE_WALK
	return (travel or ground) and Routes._source_profile_refusal(profiles, row, revision, profiles._live.header[0]) == &""


static func _canonical_compatible(profiles: Profiles, anchor: int, row: int) -> bool:
	"""Protocol6 uses canonical READY at its wide gateway and exact finite programmes on narrow legs."""
	if row < 2 or row > StepProgram.GROUND or StepProgram.profile_refusal(profiles, row,
			profiles._live.quantities[row], profiles._live.header[0]) != &"": return false
	return row == StepProgram.GROUND or profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + row] \
		== profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + anchor]


static func _sources(actual: WorldRoutes, first: Vector2i, anchor: int) -> StringName:
	"""Recheck every collected full endpoint/section and freshly reselect each edge's actual current Profile bit."""
	var graph: Routes = actual._routes_ref.get_ref() as Routes
	var owner: Owner = actual._owner_ref.get_ref() as Owner
	var locations: Locations = actual._locations_ref.get_ref() as Locations
	var section: Vector2i = locations._ref_at(locations._live, Locations.SECTION_SLOT, first.x)
	var code: StringName = WorldRoutes._reach_endpoint_refusal(graph, owner, locations, first, NULL_REF)
	if code != &"": return code
	for index: int in graph._proposed_count:
		if not graph._spend(64): return graph._operation_error
		var row: int = graph._proposed_edges[(graph._proposed_count - index - 1) * 2]
		var next: Vector2i = graph._edge_pair(graph._live, Routes.E_SECTION_SLOT, row)
		if next != section:
			code = WorldRoutes._reach_section_refusal(graph, owner, locations, next)
			if code != &"": return code
			section = next
		if _edge_profile(actual, row, anchor) < 0:
			return graph._operation_error if graph._operation_error != &"" else &"WORLD_ROUTE_CERTIFICATE_STALE"
		code = WorldRoutes._reach_endpoint_refusal(graph, owner, locations, graph._edge_pair(graph._live, Routes.E_TO_SLOT, row), section)
		if code != &"": return code
		section = locations._ref_at(locations._live, Locations.SECTION_SLOT, graph._edge_i32(graph._live, Routes.E_TO_SLOT, row))
	return &""
