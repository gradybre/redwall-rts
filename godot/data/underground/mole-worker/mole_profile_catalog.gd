extends RefCounted
## Source-qualified mole geometry only. Actual support, paid targets, Job/Gear and presentation remain separate.
## Ten borrowed cached Scripts, bounded hashing scratch, existing streamed two-bank Profiles; no third image.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Space := preload("res://scripts/core/room_space.gd")
## ADR1217 step 5: the runtime loads content 9 (`qualified-claw-approach-v10`): the pick rows 0-29 stay published
## and dormant (DEC-052); sources 2/3 are the v10 haul images, source 4 the claw image, source 5 the paw image.
const Pins := preload("./qualified-claw-approach-v10/catalog_source.gd")
const PROFILE_COUNT: int = 60
const BOX_COUNT: int = 517
const CONTENT_REVISION: int = 9
const PROFILE_REVISION: int = 1
const WIRE_BYTES: int = 20588
const PAIRED_BANK_BYTES: int = 41160
const SOURCE_CHARS: int = 262144
const HASH_CHARS: int = 1024
const CONTROL_RESERVE: int = 32768 # Existing Profiles reserve, never an additional arena.
const WIRE_PATH: String = "res://data/underground/mole-worker/qualified-claw-approach-v10/mole-worker.ugprof"
## ADR1200/1206/1217: actor, assembly-handling (row 29), wood haul v10 (30-36), stone haul v10 (37-41), claw (42-58),
## paw handling (59).
const SOURCE_COUNT: int = 6


static func load_into(profiles: Profiles, content: Content, domain: Space.Domain) -> StringName:
	"""Cold source geometry publication: all fixed source checks precede the existing atomic file loader."""
	if profiles == null or profiles.get_script() != Profiles or profiles.content_revision() != 0:
		return &"MOLE_CATALOG_OWNER"
	var code: StringName = content_refusal(content, domain)
	if code == &"":
		code = runtime_sources_refusal()
	return profiles.load_file(WIRE_PATH, Pins.WIRE_SHA, CONTENT_REVISION) if code == &"" else code


static func content_refusal(content: Content, domain: Space.Domain) -> StringName:
	"""An actual finite content image and exact datum/extents are required; this does not attest a World owner."""
	if content == null or content.get_script() != Content or content.source_digest() != Pins.ACTOR_SHA \
			or content.part_count() != 2 or content.clip_count() != 14 or domain == null:
		return &"MOLE_CATALOG_CONTENT"
	var descriptor: Dictionary = domain.descriptor()
	if not Space.Value.valid_ref(descriptor.world_ref) or descriptor.datum_u != Vector3i(0, 512, 0) \
			or descriptor.min_quantum != Vector3i(0, -32, 0) or descriptor.size_quanta != Vector3i(256, 48, 256) \
			or not content.domain_matches(descriptor.bounds_u):
		return &"MOLE_CATALOG_DOMAIN"
	var basis: PackedByteArray = PackedByteArray()
	basis.resize(32)
	return &"" if content.source_hash_into(0, basis) and basis.hex_encode() == Pins.BASIS_SHA else &"MOLE_CATALOG_BASIS"


static func presentation_refusal(content: Content, basis: Actor.WorldBasis, domain: Space.Domain) -> StringName:
	"""A headless geometry catalog cannot impersonate an actual native renderer attachment."""
	var code: StringName = content_refusal(content, domain)
	if code != &"":
		return code
	if basis == null or basis.source_digest() != Pins.BASIS_SHA or basis.producer_digest() != Pins.BASIS_PRODUCER \
			or not basis.matches_runtime():
		return &"MOLE_CATALOG_RENDERER"
	return runtime_sources_refusal()


static func runtime_sources_refusal() -> StringName:
	"""Use the already cached actual Script source, not mutable disk bytes or a fresh transitive load."""
	if Pins.PATHS.size() != 10 or Pins.DIGESTS.size() != 10:
		return &"MOLE_CATALOG_SOURCE_COUNT"
	for index: int in 10:
		var path: String = Pins.PATHS[index]
		if path.length() > 128 or not ResourceLoader.has_cached(path):
			return &"MOLE_CATALOG_SOURCE_UNCACHED"
		var script: Script = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE) as Script
		if script == null or script.resource_path != path:
			return &"MOLE_CATALOG_SCRIPT_IDENTITY"
		var code: StringName = _source_refusal(script.get_source_code(), Pins.DIGESTS[index])
		if code != &"":
			return code
	return &""


static func _source_refusal(source: String, expected: String) -> StringName:
	"""Borrow the source String; only one <=4KiB substring and <=4KiB UTF-8 chunk coexist."""
	if source.is_empty() or source.length() > SOURCE_CHARS or not Actor.WorldBasis.valid_digest(expected):
		return &"MOLE_CATALOG_SOURCE_CAPACITY"
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var offset: int = 0
	while offset < source.length():
		var chunk: String = source.substr(offset, mini(HASH_CHARS, source.length() - offset))
		hashing.update(chunk.to_utf8_buffer())
		offset += chunk.length()
	return &"" if hashing.finish().hex_encode() == expected else &"MOLE_CATALOG_SOURCE_DRIFT"


static func profile_id(source_role: int, yaw: int) -> int:
	"""Explicit immutable role/heading map; ordinary movement permits every native heading, work only four."""
	if yaw < 0 or yaw >= 65536 or source_role < 0 or source_role > 5:
		return -1
	if source_role < 2:
		return source_role
	if yaw % 16384 != 0:
		return -1
	@warning_ignore("integer_division") var heading: int = yaw / 16384
	return 13 + 4 * heading + source_role - 2


static func approach_profile_id(yaw: int, backward: bool = false) -> int:
	"""Exact body heading selects the complete forward/backward source; path heading is a separate route fact."""
	if yaw < 0 or yaw >= 65536 or yaw % 16384 != 0:
		return -1
	@warning_ignore("integer_division") var heading: int = yaw / 16384
	return (6 if backward else 2) + heading


static func canonical_ground_profile_id() -> int:
	"""Explicit canonical admission opts into Routes' integer source clock; legacy WALK remains row one."""
	return 12


static func short_step_profile_id(yaw: int, backward: bool = false) -> int:
	"""Only the source-proved positive-X body heading has this finite232u protocol."""
	return (11 if backward else 10) if yaw == 49152 else -1


static func pins_into(profiles: Profiles, out: PackedInt64Array) -> StringName:
	"""Cold binding also hashes actual loaded rows; equal revisions/source names cannot replace the authored geometry."""
	if out.size() != PROFILE_COUNT * 3:
		return &"MOLE_CATALOG_PINS_SIZE"
	var code: StringName = catalog_refusal(profiles)
	if code != &"":
		return code
	for index: int in PROFILE_COUNT:
		out[index * 3] = index
		out[index * 3 + 1] = PROFILE_REVISION
		out[index * 3 + 2] = CONTENT_REVISION
	return &""


static func driver_pins_into(profiles: Profiles, out: PackedInt64Array) -> StringName:
	"""The existing eighteen-role driver packet names STAND/WALK and WORK; Routes owns directed travel state."""
	if out.size() != 54:
		return &"MOLE_CATALOG_PINS_SIZE"
	var code: StringName = catalog_refusal(profiles)
	if code != &"":
		return code
	for index: int in 18:
		out[index * 3] = index if index < 2 else index + 11
		out[index * 3 + 1] = PROFILE_REVISION
		out[index * 3 + 2] = CONTENT_REVISION
	return &""


static func catalog_refusal(profiles: Profiles) -> StringName:
	"""Reconstruct the canonical small wire through public immutable readers without retaining another image."""
	if profiles == null or profiles.get_script() != Profiles or profiles.content_revision() != CONTENT_REVISION \
			or profiles.profile_count(CONTENT_REVISION) != PROFILE_COUNT:
		return &"MOLE_CATALOG_OWNER"
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(_wire_header())
	var code: StringName = _hash_sources(profiles, hashing)
	if code == &"":
		code = _hash_rows(profiles, hashing)
	if code == &"":
		code = _hash_boxes(profiles, hashing)
	if code != &"":
		return code
	hashing.update("UGPEND01".to_ascii_buffer())
	return &"" if hashing.finish().hex_encode() == Pins.WIRE_SHA else &"MOLE_CATALOG_GEOMETRY_DRIFT"


static func _hash_sources(profiles: Profiles, hashing: HashingContext) -> StringName:
	"""Every source digest is exactly its pinned image, in wire order; no source past the last one exists."""
	var digests: PackedStringArray = PackedStringArray([Pins.ACTOR_SHA, Pins.HANDLING_SOURCE_SHA,
		Pins.HAUL_SOURCE_SHA, Pins.STONE_SOURCE_SHA, Pins.CLAW_SOURCE_SHA, Pins.PAW_SOURCE_SHA])
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	for source: int in SOURCE_COUNT:
		if not profiles.source_hash_into(source, CONTENT_REVISION, digest) or digest.hex_encode() != digests[source]:
			return &"MOLE_CATALOG_CONTENT"
		hashing.update(digest)
	return &"MOLE_CATALOG_CONTENT" if profiles.source_hash_into(SOURCE_COUNT, CONTENT_REVISION, digest) else &""


static func _wire_header() -> PackedByteArray:
	"""Fixed32-byte wire header is reused only during this cold exact-content check."""
	var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
	bytes.resize(32)
	bytes.encode_u32(8, 2)
	bytes.encode_s64(12, CONTENT_REVISION)
	bytes.encode_u32(20, PROFILE_COUNT)
	bytes.encode_u32(24, BOX_COUNT)
	bytes.encode_u32(28, SOURCE_COUNT)
	return bytes


static func _hash_rows(profiles: Profiles, hashing: HashingContext) -> StringName:
	"""One184-byte descriptor and98-byte output row; caller content cannot alias this scratch."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(98)
	var first: int = 0
	for index: int in PROFILE_COUNT:
		if profiles.descriptor_into(index, CONTENT_REVISION, descriptor) != &"":
			return &"MOLE_CATALOG_DESCRIPTOR"
		_encode_fields(descriptor, first, bytes)
		bytes.encode_s64(72, descriptor.profile_revision)
		bytes.encode_s64(80, descriptor.quantity_min_milli)
		bytes.encode_s64(88, descriptor.quantity_max_milli)
		bytes[96] = descriptor.certificate_flags
		var policy: int = profiles.selection_policy_of(index, descriptor.profile_revision, CONTENT_REVISION)
		if policy < 0:
			return &"MOLE_CATALOG_DESCRIPTOR"
		bytes[97] = policy
		hashing.update(bytes)
		first += descriptor.box_count
	return &"" if first == BOX_COUNT else &"MOLE_CATALOG_BOX_CENSUS"


static func _encode_fields(row: Profiles.Descriptor, first: int, bytes: PackedByteArray) -> void:
	"""Exact existing UGPROF01 field order; no temporary field Array or private bank reader."""
	bytes.encode_s32(0, row.source_id)
	bytes.encode_s32(4, row.species)
	bytes.encode_s32(8, row.life_stage)
	bytes.encode_s32(12, row.rig)
	bytes.encode_s32(16, row.mode)
	bytes.encode_s32(20, row.posture)
	bytes.encode_s32(24, row.tool_item)
	bytes.encode_s32(28, row.tool_variant)
	bytes.encode_s32(32, row.cargo_item)
	bytes.encode_s32(36, row.cargo_variant)
	bytes.encode_s32(40, row.yaw_kind)
	bytes.encode_s32(44, row.yaw)
	bytes.encode_s32(48, row.family_mask)
	bytes.encode_s32(52, row.state_mask)
	bytes.encode_s32(56, first)
	bytes.encode_s32(60, row.box_count)
	bytes.encode_s32(64, row.work_kind)
	bytes.encode_s32(68, row.contact_kind)


static func _hash_boxes(profiles: Profiles, hashing: HashingContext) -> StringName:
	"""Every mandatory volume/anchor/patch is included once; no phase may borrow another role's presence."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var box: Profiles.Box = Profiles.Box.new()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(28)
	for index: int in PROFILE_COUNT:
		if profiles.descriptor_into(index, CONTENT_REVISION, descriptor) != &"":
			return &"MOLE_CATALOG_DESCRIPTOR"
		for ordinal: int in descriptor.box_count:
			if profiles.box_into(index, descriptor.profile_revision, CONTENT_REVISION, ordinal, box) != &"":
				return &"MOLE_CATALOG_BOX"
			for axis: int in 3:
				bytes.encode_s32(axis * 4, box.low[axis])
				bytes.encode_s32(12 + axis * 4, box.high[axis])
			bytes.encode_s32(24, box.role)
			hashing.update(bytes)
	return &""
