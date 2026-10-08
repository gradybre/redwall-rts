extends RefCounted
## The whole settlement save file (ADR 1222 build steps 8-9): header, the fifteen 64-byte section
## descriptors, then the fifteen section bodies, written and read as one validated unit.
##
## LAYOUT. `save_header.gd` owns every byte rule of the 264-byte header and the descriptors; this
## module only places them. Sections are written CONTIGUOUSLY in ascending section id from offset
## 1224 (264 + 15 * 64), each descriptor carrying the section's own schema version, row count and
## CRC-32/ISO-HDLC, and the header carrying the exact file length and the SHA-256 body digest over
## everything from offset 264 on (ARCH-SAVE-001/002).
##
## IDENTITY. A DEVELOPMENT save (DEC-055 Q9): the rules and lookup identities are
## `development_identity_hash()` over the canonical registry id, catalog and engine are this
## build's, and the map hash is derived from section 1's own 44-byte provenance prefix
## (SAVE-R09-003). `decode_file()` runs `compatibility_refusal()` against this build before it
## hands a single section byte to anyone (DEC-055 Q1: refuse, never migrate).
##
## DECODE ORDER. Preamble and header, the exact file length, the descriptor table, all fifteen ids,
## contiguity, every CRC, the body digest, then the identities. A refusal returns no Body.
##
## DISK. `write_atomic()` writes `<path>.tmp` in 65536-byte chunks, re-reads and re-decodes it,
## and only then renames it over `<path>` (ARCH-SAVE-003). `read_file()` reads a whole file. Both
## refuse with an exact code; neither ever deletes a save.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveIdentity := preload("res://scripts/core/save_identity_hashes.gd")

const SECTION_COUNT: int = SaveHeader.SECTION_COUNT
const PROVENANCE_PREFIX_BYTES: int = SaveIdentity.PROVENANCE_PREFIX_BYTES
const WRITE_CHUNK_BYTES: int = 65536
const TEMP_SUFFIX: String = ".tmp"

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BODY_SHAPE: StringName = &"SAVE_FILE_BODY_SHAPE"
const REFUSE_NOT_CONTIGUOUS: StringName = &"SAVE_FILE_NOT_CONTIGUOUS"
const REFUSE_SECTION_ORDER: StringName = &"SAVE_FILE_SECTION_ORDER"
const REFUSE_SECTION_CRC: StringName = &"SAVE_FILE_SECTION_CRC"
const REFUSE_IDENTITY: StringName = &"SAVE_FILE_IDENTITY"
const REFUSE_IO: StringName = &"SAVE_FILE_IO"
const REFUSE_VERIFY: StringName = &"SAVE_FILE_VERIFY"


class Body:
	"""The fifteen section bodies with their descriptor facts, plus the header's scalar fields.

	`sections[i]` is section id `i + 1`. The checkpoint pair is section 12's allocator and the
	completed tick is section 1's, copied here by the capture so the header can redeclare them.
	"""
	var sections: Array[PackedByteArray] = []
	var schema_versions: PackedInt64Array = PackedInt64Array()
	var row_counts: PackedInt64Array = PackedInt64Array()
	var completed_tick: int = 0
	var chronicle_record_count: int = 0
	var economic_next_high: int = 0
	var economic_next_low: int = 0

	func _init() -> void:
		"""Fifteen empty sections at schema 0 and no rows."""
		sections.resize(SECTION_COUNT)
		for index: int in SECTION_COUNT:
			sections[index] = PackedByteArray()
		schema_versions.resize(SECTION_COUNT)
		row_counts.resize(SECTION_COUNT)

	func section(section_id: int) -> PackedByteArray:
		"""The body of one section id, 1..15 (shared, not copied)."""
		return sections[section_id - 1]

	func set_section(section_id: int, bytes: PackedByteArray, schema_version: int,
			row_count: int) -> void:
		"""Bind one section's body and its descriptor facts."""
		sections[section_id - 1] = bytes
		schema_versions[section_id - 1] = schema_version
		row_counts[section_id - 1] = row_count

	func shape_detail() -> String:
		"""The first malformed entry, or an empty string."""
		if sections.size() != SECTION_COUNT or schema_versions.size() != SECTION_COUNT \
				or row_counts.size() != SECTION_COUNT:
			return "the body does not carry exactly %d sections" % SECTION_COUNT
		if sections[0].size() < PROVENANCE_PREFIX_BYTES:
			return "section 1 is shorter than its %d-byte provenance prefix" \
				% PROVENANCE_PREFIX_BYTES
		return ""


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


# --- identity -------------------------------------------------------------------------------------

static func header_identity_into(section1: PackedByteArray,
		header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Fill the five identity digests for a development save written from `section1`."""
	var local: SaveIdentity.LocalIdentityResult = SaveIdentity.local_identity(true)
	if not local.ok:
		return _no(REFUSE_IDENTITY, "%s: %s" % [String(local.error), local.detail])
	var provenance: SaveIdentity.ProvenanceResult = SaveIdentity.provenance_from_prefix(
		section1.slice(0, PROVENANCE_PREFIX_BYTES))
	if not provenance.ok:
		return _no(REFUSE_IDENTITY, provenance.detail)
	var map: SaveIdentity.DigestResult = SaveIdentity.expected_map_hash(provenance.provenance)
	if not map.ok:
		return _no(REFUSE_IDENTITY, "%s: %s" % [String(map.error), map.detail])
	header.rules_hash = local.identity.rules
	header.catalog_hash = local.identity.catalog
	header.map_hash = map.digest
	header.lookup_hash = local.identity.lookup
	header.engine_hash = local.identity.engine
	return _ok()


static func identity_refusal(header: SaveHeader.Header,
		section1: PackedByteArray) -> SaveHeader.Refusal:
	"""DEC-055 Q1: the file's five identities against this build, before any world is touched."""
	var local: SaveIdentity.LocalIdentityResult = SaveIdentity.local_identity(true)
	if not local.ok:
		return _no(REFUSE_IDENTITY, "%s: %s" % [String(local.error), local.detail])
	var provenance: SaveIdentity.ProvenanceResult = SaveIdentity.provenance_from_prefix(
		section1.slice(0, PROVENANCE_PREFIX_BYTES))
	if not provenance.ok:
		return _no(REFUSE_IDENTITY, provenance.detail)
	return SaveIdentity.compatibility_refusal(header, provenance.provenance, local.identity)


# --- encode ---------------------------------------------------------------------------------------

static func encode_file(body: Body, out: PackedByteArray) -> SaveHeader.Refusal:
	"""Lay out header, table and sections into `out`. A refusal leaves `out` unchanged."""
	if body == null or body.shape_detail() != "":
		return _no(REFUSE_BODY_SHAPE, "no body" if body == null else body.shape_detail())
	var staging: PackedByteArray = PackedByteArray()
	staging.resize(SaveHeader.body_offset())
	var table: SaveHeader.Refusal = _write_table_and_sections(body, staging)
	if not table.is_ok():
		return table
	var header: SaveHeader.Header = _header_of(body, staging.size())
	var identity: SaveHeader.Refusal = header_identity_into(body.section(1), header)
	if not identity.is_ok():
		return identity
	header.body_digest = SaveHeader.compute_body_digest(staging)
	var written: SaveHeader.Refusal = SaveHeader.encode_header_into(header, staging)
	if not written.is_ok():
		return written
	out.clear()
	out.append_array(staging)
	return _ok()


static func _header_of(body: Body, total: int) -> SaveHeader.Header:
	"""The header's scalar fields; the digests are filled by the caller."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	header.total_file_bytes = total
	header.completed_tick = body.completed_tick
	header.chronicle_record_count = body.chronicle_record_count
	header.economic_next_sequence_high = body.economic_next_high
	header.economic_next_sequence_low = body.economic_next_low
	return header


static func _write_table_and_sections(body: Body, staging: PackedByteArray) -> SaveHeader.Refusal:
	"""Each descriptor at its table slot; each body appended at its contiguous offset."""
	var at: int = SaveHeader.body_offset()
	for index: int in SECTION_COUNT:
		var bytes: PackedByteArray = body.sections[index]
		var descriptor: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
		descriptor.section_id = index + 1
		descriptor.schema_version = body.schema_versions[index]
		descriptor.offset = at
		descriptor.byte_length = bytes.size()
		descriptor.row_count = body.row_counts[index]
		descriptor.crc32 = SaveHeader.crc32_of(bytes)
		var refusal: SaveHeader.Refusal = SaveHeader.encode_descriptor_into(descriptor, staging,
			SaveHeader.SECTION_TABLE_OFFSET + index * SaveHeader.SECTION_DESCRIPTOR_BYTES)
		if not refusal.is_ok():
			return refusal
		staging.append_array(bytes)
		at += bytes.size()
	return _ok()


# --- decode ---------------------------------------------------------------------------------------

static func decode_file(bytes: PackedByteArray, out: Body,
		out_header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Validate the whole file, then fill `out` and `out_header`. A refusal changes neither."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	var parsed: SaveHeader.Refusal = SaveHeader.decode_header_into(bytes, header)
	if parsed.is_ok():
		parsed = SaveHeader.header_refusal(header, bytes.size())
	if not parsed.is_ok():
		return parsed
	var descriptors: Array[SaveHeader.Descriptor] = []
	var table: SaveHeader.Refusal = SaveHeader.decode_section_table(bytes, descriptors)
	if table.is_ok():
		table = SaveHeader.section_table_refusal(descriptors, header)
	if table.is_ok():
		table = _layout_refusal(descriptors, bytes)
	if table.is_ok():
		table = SaveHeader.body_digest_refusal(bytes, header)
	if not table.is_ok():
		return table
	var staged: Body = _body_of(bytes, descriptors, header)
	var identity: SaveHeader.Refusal = identity_refusal(header, staged.section(1))
	if not identity.is_ok():
		return identity
	_adopt(staged, out, header, out_header)
	return _ok()


static func _layout_refusal(descriptors: Array[SaveHeader.Descriptor],
		bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Table slot `i` is section `i + 1`, sections tile the body exactly, and every CRC matches."""
	var at: int = SaveHeader.body_offset()
	for index: int in SECTION_COUNT:
		var descriptor: SaveHeader.Descriptor = descriptors[index]
		if descriptor.section_id != index + 1:
			return _no(REFUSE_SECTION_ORDER, "table slot %d holds section %d"
				% [index, descriptor.section_id])
		if descriptor.offset != at:
			return _no(REFUSE_NOT_CONTIGUOUS, "section %d starts at %d, not %d"
				% [descriptor.section_id, descriptor.offset, at])
		var slice: PackedByteArray = bytes.slice(at, at + descriptor.byte_length)
		if SaveHeader.crc32_of(slice) != descriptor.crc32:
			return _no(REFUSE_SECTION_CRC, "section %d fails its CRC" % descriptor.section_id)
		at += descriptor.byte_length
	if at != bytes.size():
		return _no(REFUSE_NOT_CONTIGUOUS, "the sections end at %d of %d bytes" % [at, bytes.size()])
	return _ok()


static func _body_of(bytes: PackedByteArray, descriptors: Array[SaveHeader.Descriptor],
		header: SaveHeader.Header) -> Body:
	"""Slice every validated section out of the file into a staged Body."""
	var body: Body = Body.new()
	for index: int in SECTION_COUNT:
		var descriptor: SaveHeader.Descriptor = descriptors[index]
		body.set_section(index + 1, bytes.slice(descriptor.offset,
			descriptor.offset + descriptor.byte_length), descriptor.schema_version,
			descriptor.row_count)
	body.completed_tick = header.completed_tick
	body.chronicle_record_count = header.chronicle_record_count
	body.economic_next_high = header.economic_next_sequence_high
	body.economic_next_low = header.economic_next_sequence_low
	return body


static func _adopt(staged: Body, out: Body, header: SaveHeader.Header,
		out_header: SaveHeader.Header) -> void:
	"""Publish the staged body and header into the caller's objects."""
	out.sections = staged.sections
	out.schema_versions = staged.schema_versions
	out.row_counts = staged.row_counts
	out.completed_tick = staged.completed_tick
	out.chronicle_record_count = staged.chronicle_record_count
	out.economic_next_high = staged.economic_next_high
	out.economic_next_low = staged.economic_next_low
	if out_header == null:
		return
	out_header.total_file_bytes = header.total_file_bytes
	out_header.completed_tick = header.completed_tick
	out_header.rules_hash = header.rules_hash
	out_header.catalog_hash = header.catalog_hash
	out_header.map_hash = header.map_hash
	out_header.lookup_hash = header.lookup_hash
	out_header.engine_hash = header.engine_hash
	out_header.chronicle_record_count = header.chronicle_record_count
	out_header.economic_next_sequence_low = header.economic_next_sequence_low
	out_header.economic_next_sequence_high = header.economic_next_sequence_high
	out_header.body_digest = header.body_digest


# --- disk -----------------------------------------------------------------------------------------

static func read_file(path: String, out: PackedByteArray) -> SaveHeader.Refusal:
	"""Read a whole file into `out`. A refusal leaves `out` unchanged."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no(REFUSE_IO, "cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var error: Error = file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		return _no(REFUSE_IO, "reading %s failed (error %d)" % [path, error])
	out.clear()
	out.append_array(bytes)
	return _ok()


static func write_atomic(path: String, bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Write `<path>.tmp` in chunks, re-read and re-decode it, then rename it over `path`."""
	var temp: String = path + TEMP_SUFFIX
	var written: SaveHeader.Refusal = _write_chunks(temp, bytes)
	if not written.is_ok():
		return written
	var back: PackedByteArray = PackedByteArray()
	var read: SaveHeader.Refusal = read_file(temp, back)
	if not read.is_ok():
		return read
	if back != bytes:
		return _no(REFUSE_VERIFY, "%s does not read back as written" % temp)
	var verify: SaveHeader.Refusal = decode_file(back, Body.new(), null)
	if not verify.is_ok():
		return _no(REFUSE_VERIFY, "%s does not decode: %s" % [temp, verify.detail])
	var error: Error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		return _no(REFUSE_IO, "renaming %s over %s failed (error %d)" % [temp, path, error])
	return _ok()


static func _write_chunks(path: String, bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Create `path` and stream `bytes` into it in WRITE_CHUNK_BYTES pieces."""
	var directory: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory != OK and directory != ERR_ALREADY_EXISTS:
		return _no(REFUSE_IO, "cannot create %s (error %d)" % [path.get_base_dir(), directory])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _no(REFUSE_IO, "cannot create %s (error %d)" % [path, FileAccess.get_open_error()])
	var at: int = 0
	while at < bytes.size():
		var end: int = mini(at + WRITE_CHUNK_BYTES, bytes.size())
		file.store_buffer(bytes.slice(at, end))
		at = end
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return _no(REFUSE_IO, "writing %s failed (error %d)" % [path, error])
	return _ok()
