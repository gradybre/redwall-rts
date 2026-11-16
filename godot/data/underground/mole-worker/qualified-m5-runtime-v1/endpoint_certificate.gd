extends RefCounted
## Decision 2044 (P-2044-17 (a)): the module-aware successor of `qualified-claw-certificate-v2/endpoint_certificate.gd`,
## which the endpoint dispatch names for content 12. Every proof about an installation of module 0 (L0, T0..T6:
## assemblies 0-7), and anything else that certificate refuses, is handed to it unchanged, so today's entry behaves
## byte for byte as before. A later module's T0 (installed from its landing, M5) takes the same proofs with its station
## root moved by the module translation (`tread_geometry.gd`): its station record and the narrow approach and retreat
## spans that may omit its pending bearer. Its part is the M5 handling certificate's moved rule; its bearer prism, Room
## rule, envelope, support and row identities are the published T0's, unchanged.
## No reverse preload of Locations, Routes, Placements, Workpieces or Contacts is permitted here.

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Published := preload("res://data/underground/mole-worker/qualified-claw-certificate-v2/endpoint_certificate.gd")
const Physical := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/paw_physical_certificate.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const Pins := Published.Pins
const REFUSE: StringName = Published.REFUSE
const BUDGET: StringName = Published.BUDGET
const CONTENT: int = Published.CONTENT


static func later_t0(assembly: int) -> bool:
	"""A later module's T0: the only assembly this successor proves itself."""
	return Tread.is_t0(assembly) and Tread.module_of(assembly) > 0


static func prepared_record_refusal(actual_locations: RefCounted, original_context: RefCounted,
		record: RefCounted, snapshot_volume_row: int) -> StringName:
	"""Module 0 (and every other refusal): the published proof. A later T0: the same proof at its moved station."""
	if original_context == null or not later_t0(original_context.assembly):
		return Published.prepared_record_refusal(actual_locations, original_context, record, snapshot_volume_row)
	var code: StringName = _context_refusal(actual_locations, original_context, record)
	if code != &"": return code
	if not Published._spend(actual_locations, 4096 + 64 * actual_locations._capacity): return BUDGET
	var issuer: RefCounted = original_context.issuer.get_ref()
	code = Published._issuer_refusal(actual_locations, original_context, issuer)
	if code == &"": code = _piece_refusal(actual_locations, original_context, issuer)
	if code == &"": code = Published._profiles_refusal(issuer._profiles, original_context.profile_revision)
	if code == &"": code = _record_refusal(actual_locations, original_context, issuer, record)
	if code == &"": code = Published._snapshot_point_refusal(actual_locations, original_context, record.point,
		actual_locations._snapshot, snapshot_volume_row)
	return code


static func prepared_span_refusal(actual: RefCounted, first: Vector3i, last: Vector3i, volume_row: int) -> StringName:
	"""Module 0: the published span proof. A later T0: the same approach/retreat interval from its moved root."""
	if actual == null or actual._installation == null or not later_t0(actual._installation.assembly):
		return Published.prepared_span_refusal(actual, first, last, volume_row)
	if actual._locations_ref == null: return REFUSE
	var a: RefCounted = actual._locations_ref.get_ref()
	var c: RefCounted = actual._installation
	var code: StringName = _original_context_refusal(a, c)
	if code == &"": code = Published._span_scope_refusal(actual, a, c)
	if code != &"": return code
	var p: RefCounted = c.issuer.get_ref()
	code = Published._issuer_refusal(a, c, p)
	if code == &"": code = _piece_refusal(a, c, p)
	if code == &"": code = Published._profiles_refusal(p._profiles, c.profile_revision)
	if code == &"": code = _span_source_refusal(actual, p, c, first, last)
	if code != &"": return code
	return Published._snapshot_point_refusal(a, c, _root(p, c), actual._proof.image, volume_row)


static func _root(p: RefCounted, c: RefCounted) -> Vector3i:
	"""A later T0's station: the Placement origin plus its module's translated T0 station (H')."""
	return Vector3i(p._live.i32[p.X * p._capacity + c.placement.x], p._live.i32[(p.X + 1) * p._capacity + c.placement.x],
		p._live.i32[(p.X + 2) * p._capacity + c.placement.x]) + Tread.t0_station_of(c.assembly)


static func _context_refusal(a: RefCounted, c: RefCounted, record: RefCounted) -> StringName:
	"""The Location owns its original live survey only during this prepared record proof."""
	var code: StringName = _original_context_refusal(a, c)
	if code != &"": return code
	return &"" if record != null and a._snapshot != null \
		and a._snapshot.world_ref == c.world and a._snapshot.revision == c.target_revision else REFUSE


static func _original_context_refusal(a: RefCounted, c: RefCounted) -> StringName:
	"""The published original-context proof, its assembly bound read as a later module's T0 (the published one admits
	only L0 and T0, assemblies 0 and 1)."""
	if c == null or not later_t0(c.assembly): return REFUSE
	if a == null or not ("_installation" in a) \
			or a._installation != c or c.issuer == null or c.issuer.get_ref() == null \
			or c.space == null or c.space.get_ref() != a._owner or c.locations == null \
			or c.locations.get_ref() != a or c.budget == null or c.budget != a._cold \
			or c.world != a._world or c.action != Owner.ModularContract.START or a._owner == null \
			or not a._sources is Owner.CoreSources or a._owner._sources != a._sources \
			or a._sources._directory != a._ids or a._capacity <= 0 or a._capacity > a.MAX_LOCATIONS:
		return REFUSE
	return _original_tokens_refusal(a, c)


static func _original_tokens_refusal(a: RefCounted, c: RefCounted) -> StringName:
	"""The published original lease, tokens and revisions, unchanged."""
	if c.cold_token <= 0 or c.cold_token != a._cold_token or a._cold._token != c.cold_token \
			or a._cold._used < Owner.Budget.COLD_BYTES or c.location_token <= 0 \
			or c.location_token != a._token or c.space_token <= 0 or c.space_token != a._owner_token \
			or c.space_token != a._owner._stage_token or not a._owner._sealed \
			or a._retention_reentered or c.base_revision != a._owner._header[17] \
			or c.base_revision != a._base_geometry_revision or c.target_revision != c.base_revision + 1 \
			or c.target_revision != a._owner._s_header[17] or c.target_revision != a._target_geometry_revision:
		return REFUSE
	return &""


static func _piece_refusal(a: RefCounted, c: RefCounted, p: RefCounted) -> StringName:
	"""The published pending-request proof, its part checked by the M5 handling certificate's moved T0 rule."""
	var piece: RefCounted = p._workpieces.get_ref() if p._workpieces != null else null
	if piece == null or not piece._configured or not piece._loaded or piece._placements != p \
			or piece._budget != a._cold or piece._profiles != p._profiles or piece._catalog != p._catalog \
			or piece._router != c.router.get_ref() or piece._paid_owner == null \
			or piece._paid_owner.get_ref() != c.paid_owner.get_ref() \
			or c.paid_owner.get_ref() == null or c.paid_owner.get_ref()._workpieces != piece \
			or piece._stage_placement != c.placement or piece._stage_project != c.project \
			or piece._stage_action != c.action or piece._stage_assembly != c.assembly \
			or piece._stage_payload != c.payload_revision or piece._cold_token != c.cold_token \
			or piece._live.present[c.placement.x] != 0 or piece._assembly_capacity <= c.assembly \
			or piece._header[piece.H_PROFILES] != c.profile_revision \
			or piece._header[piece.H_PROGRAM] != Published.PAW_SOURCE \
			or piece._parts[piece.PROFILE * piece._assembly_capacity + c.assembly] != Pins.PAW_HANDLING_ROW \
			or piece._profile_revisions[c.assembly] != 1:
		return REFUSE
	var at: int = c.assembly
	return Physical.part_refusal(at, piece._parts[piece.PART * piece._assembly_capacity + at],
		piece._parts[piece.ROTATION * piece._assembly_capacity + at], Vector3i(piece._parts[piece.X * piece._assembly_capacity + at],
		piece._parts[(piece.X + 1) * piece._assembly_capacity + at], piece._parts[(piece.X + 2) * piece._assembly_capacity + at]))


static func _record_refusal(a: RefCounted, c: RefCounted, p: RefCounted, record: RefCounted) -> StringName:
	"""The published station record proof at the moved root: WORK, the Placement's Room and level, the published
	envelope and support words, and the one unchanged live record."""
	if record.role != a.ROLE_WORK or not Published._record_room_matches(p, c, record) \
			or record.envelope.size() != 6 or record.support.size() != 6 or record.point != _root(p, c):
		return REFUSE
	for axis: int in 6:
		if int(record.envelope[axis]) - record.point[axis % 3] != Published._envelope_word(axis) \
				or int(record.support[axis]) - record.point[axis % 3] != Published._support_word(axis): return REFUSE
	return _live_record_refusal(a, record)


static func _live_record_refusal(a: RefCounted, record: RefCounted) -> StringName:
	"""Exactly one live record equals it, unchanged in the stage (the published loop)."""
	var found: int = -1
	for row: int in a._capacity:
		if a._live.present[row] != 1 or not Published._record_matches(a, row, record): continue
		if found >= 0 or a._stage.present[row] != 1 \
				or a._stage.i32[a.GENERATION * a._capacity + row] != a._live.i32[a.GENERATION * a._capacity + row] \
				or a._stage.i64[a.PAYLOAD_REVISION * a._capacity + row] != a._live.i64[a.PAYLOAD_REVISION * a._capacity + row]:
			return REFUSE
		for field: int in a.I32_FIELDS:
			if a._stage.i32[field * a._capacity + row] != a._live.i32[field * a._capacity + row]: return REFUSE
		found = row
	return &"" if found >= 0 else REFUSE


static func _span_source_refusal(b: RefCounted, p: RefCounted, c: RefCounted,
		first: Vector3i, last: Vector3i) -> StringName:
	"""The published span source proof, from the moved root."""
	if p._world_routes != b or p._routes != b._routes_ref.get_ref() or p._profiles != b._profiles \
			or not Published._span_descriptor_matches(b._descriptor, c.profile_revision) \
			or not Published._span_body_matches(b._body):
		return REFUSE
	return &"" if Published._span_points_match(b._descriptor.profile_id, _root(p, c), first, last) else REFUSE
