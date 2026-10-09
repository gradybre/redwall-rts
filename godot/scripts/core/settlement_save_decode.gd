extends RefCounted
## Decode and verify a validated save body into staged records, before any world is touched
## (ADR 1222 build step 9, load steps 3-5).
##
## `decode_body(body, header, out)` decodes all fourteen record sections with their own codecs into
## a `Capture.Staged` (the same record set a capture builds), checks the descriptor facts a capture
## writes, verifies section 2's catalog against this build, binds the header's Chronicle count and
## economic checkpoint to sections 13 and 12, and proves section 4 carries all eighteen owners in
## order (each bridge's `apply()` judges its own values). `verify_digest()` then recomputes
## ARCH-HASH-001's digest over the staged records and compares it with section 15. Nothing here
## touches a store, a clock or the disk.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const SaveDigest := preload("res://scripts/core/settlement_save_digest.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const CatalogIds := preload("res://scripts/core/catalog_ids.gd")
const S01 := preload("res://scripts/core/save_section_01.gd")
const S03 := preload("res://scripts/core/save_section_directory.gd")
const S04 := preload("res://scripts/core/save_section_component_columns.gd")
const S04Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const S05 := preload("res://scripts/core/save_section_child_arenas.gd")
const S06 := preload("res://scripts/core/save_section_auxiliary.gd")
const S07 := preload("res://scripts/core/save_section_inventories.gd")
const S08 := preload("res://scripts/core/save_section_job_indexes.gd")
const S09 := preload("res://scripts/core/save_section_navigation.gd")
const S10 := preload("res://scripts/core/save_section_rng.gd")
const S11 := preload("res://scripts/core/save_section_event_schedule.gd")
const S12 := preload("res://scripts/core/save_section_pending_commands.gd")
const S13 := preload("res://scripts/core/save_section_chronicle.gd")
const S14 := preload("res://scripts/core/save_section_name_pool.gd")
const MovementScript := preload("res://scripts/core/movement.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_DESCRIPTOR: StringName = &"SAVE_LOAD_DESCRIPTOR"
const REFUSE_CATALOG: StringName = &"SAVE_LOAD_CATALOG"
const REFUSE_DIGEST: StringName = &"SAVE_LOAD_DIGEST_MISMATCH"
const DIGEST_BYTES: int = 32


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func _wrap(section: int, refusal: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""Prefix a refusal's detail with its section; keep its exact code."""
	if refusal.is_ok():
		return refusal
	return _no(refusal.code, "section %d: %s" % [section, refusal.detail])


static func decode_body(body: SaveFile.Body, header: SaveHeader.Header,
		out: Capture.Staged) -> SaveHeader.Refusal:
	"""Decode and structurally verify every section into a staged set adopted only on success."""
	var staged: Capture.Staged = Capture.Staged.new()
	var steps: Array[Callable] = [_decode_01, _decode_02, _decode_03, _decode_04, _decode_05_06,
		_decode_07, _decode_08, _decode_09, _decode_10, _decode_11, _decode_12, _decode_13,
		_decode_14, _decode_15]
	for step: Callable in steps:
		var refusal: SaveHeader.Refusal = step.call(body, header, staged)
		if not refusal.is_ok():
			return refusal
	_adopt(staged, out)
	return _ok()


static func _adopt(staged: Capture.Staged, out: Capture.Staged) -> void:
	"""Publish every decoded record."""
	out.s01 = staged.s01
	out.s03 = staged.s03
	out.s04 = staged.s04
	out.s05 = staged.s05
	out.s06 = staged.s06
	out.s07 = staged.s07
	out.s08 = staged.s08
	out.s09 = staged.s09
	out.s10 = staged.s10
	out.s11 = staged.s11
	out.s12 = staged.s12
	out.s13 = staged.s13
	out.s14 = staged.s14


static func _facts_refusal(body: SaveFile.Body, section: int, schema: int,
		rows: int) -> SaveHeader.Refusal:
	"""The descriptor's schema version and row count equal what a capture writes."""
	if body.schema_versions[section - 1] != schema or body.row_counts[section - 1] != rows:
		return _no(REFUSE_DESCRIPTOR, "section %d declares schema %d with %d rows, not %d with %d"
			% [section, body.schema_versions[section - 1], body.row_counts[section - 1], schema,
				rows])
	return _ok()


# --- sections 1 to 4 ------------------------------------------------------------------------------

static func _decode_01(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 1 in either layout, then its descriptor facts."""
	var bytes: PackedByteArray = body.section(1)
	var refusal: SaveHeader.Refusal = S01.decode_section(bytes, 0, bytes.size(), staged.s01)
	if not refusal.is_ok():
		return _wrap(1, refusal)
	return _facts_refusal(body, 1, S01.SECTION_SCHEMA_VERSION,
		S01.DESCRIPTOR_ROW_COUNTS[staged.s01.space_layout])


static func _decode_02(body: SaveFile.Body, header: SaveHeader.Header,
		_staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 2 must be this build's catalog, carrying the header's catalog digest."""
	var verified: CatalogIds.VerifyResult = CatalogIds.verify_embedded(body.section(2),
		header.catalog_hash)
	if not verified.ok:
		return _no(REFUSE_CATALOG, "section 2: %s %s" % [String(verified.error), verified.detail])
	return _facts_refusal(body, 2, CatalogIds.SAVE_SECTION_SCHEMA_VERSION, verified.row_count)


static func _decode_03(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 3's six columns."""
	var refusal: SaveHeader.Refusal = S03.section_length_refusal(body.section(3).size())
	if refusal.is_ok():
		refusal = S03.decode_into(body.section(3), 0, staged.s03)
	if not refusal.is_ok():
		return _wrap(3, refusal)
	return _facts_refusal(body, 3, Capture.SECTION_3_SCHEMA_VERSION, S03.descriptor_row_count())


static func _decode_04(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 4 through its decode cursor, keeping all eighteen records."""
	var bytes: PackedByteArray = body.section(4)
	var cursor: S04.DecodeCursor = S04.DecodeCursor.new(body.schema_versions[3],
		body.row_counts[3], bytes.size())
	var taken: S04.OwnerResult = S04.OwnerResult.new()
	var records: Array[S04.FramedOwner] = []
	var at: int = 0
	while not cursor.is_complete() and not cursor.failed():
		var size: int = cursor.next_read_size()
		cursor.accept_chunk(bytes.slice(at, at + size))
		at += size
		if cursor.owner_ready() and cursor.take_owner_into(taken):
			records.append(taken.record)
			taken.record = null
	var finished: SaveHeader.Refusal = cursor.finish()
	if not finished.is_ok():
		return _wrap(4, finished)
	staged.s04 = records
	return _framed_refusal(records)


static func _framed_refusal(records: Array[S04.FramedOwner]) -> SaveHeader.Refusal:
	"""All eighteen records, each in its own slot. Each bridge's `apply()` judges the values."""
	if records.size() != S04Schema.STORE_COUNT:
		return _no(REFUSE_DESCRIPTOR, "section 4 decoded %d owners" % records.size())
	for owner: int in records.size():
		if records[owner].owner != owner:
			return _no(REFUSE_DESCRIPTOR, "section 4 slot %d holds owner %d"
				% [owner, records[owner].owner])
	return _ok()


# --- sections 5 to 9 ------------------------------------------------------------------------------

static func _decode_05_06(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Sections 5 and 6 through their framing codecs."""
	var five: PackedByteArray = body.section(5)
	var refusal: SaveHeader.Refusal = S05.decode_section(five, 0, five.size(), staged.s05)
	if not refusal.is_ok():
		return _wrap(5, refusal)
	refusal = _facts_refusal(body, 5, S05.Schema.SECTION_SCHEMA_VERSION, S05.OWNER_COUNT)
	if not refusal.is_ok():
		return refusal
	var six: PackedByteArray = body.section(6)
	refusal = S06.decode_section(six, 0, six.size(), staged.s06)
	if not refusal.is_ok():
		return _wrap(6, refusal)
	return _facts_refusal(body, 6, S06.Schema.SECTION_SCHEMA_VERSION, S06.OWNER_COUNT)


static func _decode_07(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 7's six owners at the file's schema."""
	var bytes: PackedByteArray = body.section(7)
	var refusal: SaveHeader.Refusal = S07.decode_into_versioned(bytes, 0, bytes.size(),
		body.schema_versions[6], staged.s07)
	if not refusal.is_ok():
		return _wrap(7, refusal)
	return _facts_refusal(body, 7, S07.SECTION_SCHEMA_VERSION, Capture.section_7_rows(staged.s07))


static func _decode_08(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 8's planner indexes."""
	var refusal: SaveHeader.Refusal = S08.section_length_refusal(body.section(8).size())
	if refusal.is_ok():
		refusal = S08.decode_section_with_schema_into(body.section(8), 0, body.schema_versions[7],
			staged.s08)
	if not refusal.is_ok():
		return _wrap(8, refusal)
	return _facts_refusal(body, 8, S08.SECTION_SCHEMA_VERSION, S08.descriptor_row_count())


static func _decode_09(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 9's two blocks."""
	var refusal: SaveHeader.Refusal = S09.decode_into(body.section(9), 0, staged.s09)
	if refusal.is_ok():
		refusal = S09.section_length_refusal(body.section(9).size(), staged.s09)
	if not refusal.is_ok():
		return _wrap(9, refusal)
	return _facts_refusal(body, 9, S09.SECTION_SCHEMA_VERSION, S09.descriptor_row_count())


# --- sections 10 to 15 ----------------------------------------------------------------------------

static func _decode_10(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 10's nine streams."""
	var refusal: SaveHeader.Refusal = S10.decode_into(body.section(10), 0, staged.s10)
	if not refusal.is_ok():
		return _wrap(10, refusal)
	return _facts_refusal(body, 10, Capture.SECTION_10_SCHEMA_VERSION, S10.STREAM_COUNT)


static func _decode_11(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 11 at its descriptor's row count and schema."""
	var bytes: PackedByteArray = body.section(11)
	var refusal: SaveHeader.Refusal = S11.decode_section_into(bytes, 0, bytes.size(),
		body.row_counts[10], body.schema_versions[10], staged.s11)
	return _wrap(11, refusal)


static func _decode_12(body: SaveFile.Body, header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 12, its descriptor facts, and the header's redundant checkpoint."""
	var refusal: SaveHeader.Refusal = S12.decode_into(body.section(12), 0, staged.s12)
	if refusal.is_ok():
		refusal = S12.section_length_refusal(body.section(12).size(), staged.s12)
	if not refusal.is_ok():
		return _wrap(12, refusal)
	refusal = _facts_refusal(body, 12, S12.SECTION_SCHEMA_VERSION,
		S12.descriptor_row_count(staged.s12))
	if not refusal.is_ok():
		return refusal
	return SaveHeader.checkpoint_binding_refusal(header, staged.s12.economic_next_sequence_high,
		staged.s12.economic_next_sequence_low, staged.s01.runtime.completed_tick)


static func _decode_13(body: SaveFile.Body, header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 13 and the header's Chronicle count."""
	var bytes: PackedByteArray = body.section(13)
	var refusal: SaveHeader.Refusal = S13.decode_section_into(bytes, 0, bytes.size(), staged.s13)
	if refusal.is_ok():
		refusal = S13.header_count_refusal(header, staged.s13)
	if not refusal.is_ok():
		return _wrap(13, refusal)
	return _facts_refusal(body, 13, S13.SECTION_SCHEMA_VERSION, staged.s13.record_count)


static func _decode_14(body: SaveFile.Body, _header: SaveHeader.Header,
		staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 14's name rows."""
	var bytes: PackedByteArray = body.section(14)
	var refusal: SaveHeader.Refusal = S14.decode_into(bytes, 0, bytes.size(), staged.s14)
	if not refusal.is_ok():
		return _wrap(14, refusal)
	return _facts_refusal(body, 14, S14.SCHEMA_VERSION, S14.PRIMARY_COUNT)


static func _decode_15(body: SaveFile.Body, _header: SaveHeader.Header,
		_staged: Capture.Staged) -> SaveHeader.Refusal:
	"""Section 15 is exactly one 32-byte digest."""
	if body.section(15).size() != DIGEST_BYTES:
		return _no(REFUSE_DESCRIPTOR, "section 15 holds %d bytes, not %d"
			% [body.section(15).size(), DIGEST_BYTES])
	return _facts_refusal(body, 15, Capture.SECTION_15_SCHEMA_VERSION, 1)


static func verify_digest(staged: Capture.Staged, body: SaveFile.Body, header: SaveHeader.Header,
		movement: MovementScript) -> SaveHeader.Refusal:
	"""Recompute the canonical digest over the decoded records and compare it with section 15."""
	var inputs: Variant = SaveDigest.inputs_for(header.rules_hash, header.catalog_hash,
		header.map_hash, header.lookup_hash, header.completed_tick)
	var outcome: SaveDigest.DigestOutcome = SaveDigest.digest_of(staged, movement, inputs)
	if not outcome.ok:
		return _no(outcome.code, "section 15: " + outcome.detail)
	if outcome.digest != body.section(15):
		return _no(REFUSE_DIGEST, "section 15 does not match the decoded state's digest")
	return _ok()
