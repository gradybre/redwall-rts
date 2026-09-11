extends RefCounted
## The `catalog_ids.json` artifact: one canonical encoder, one digest, one comparison.
##
## GDD §4.2's closing paragraph: "All gameplay enum numeric values not individually listed are
## generated once from the lexicographically sorted ASCII catalog keys within their own domain
## and committed to `catalog_ids.json`; loading verifies its hash." BAL-CAT-001 repeats it. The
## artifact contract is settled by docs/rulings/2026-09-09_ready06_open_item_answers.md §10B and
## implemented here.
##
## WHAT THIS MODULE IS. The generated artifact commits the key -> int32 ID mapping of every
## registered domain so that a save written today cannot be reinterpreted tomorrow by a build
## whose keys compile differently. `tools/generate_catalog_ids.gd` writes it at authoring time
## into `res://data/catalog_ids.json` and it is committed. Runtime NEVER writes it: verify_file()
## and verify_bytes() recompile the same domains from the same registries and COMPARE. A mismatch
## refuses; nothing here rewrites the artifact, reassigns a live ID, or mutates a world.
##
## READ FROM THE REGISTRIES, NEVER MIRRORED. Every domain table is fetched from the module that
## owns it -- catalog.gd's protected/compiled enum tables (ARCH-CMD-003's CommandKind among them,
## carried since `scripts/core/commands.gd` landed, and BuildingDefinition, FurnitureDefinition,
## RoomType and BuildingState since decision 0056: each addition moved these bytes and this
## digest, which is an intentional catalog change and not a parity result), residents.gd's
## species keys,
## farming.gd's crop keys, schedule.gd's template keys, forage.gd's quota-mode keys, and the
## ItemDefinition/ItemCategory/ItemEffect keys read out of `res://data/item_definitions.json`,
## the same file item_definitions.gd loads. There is no second copy of any domain here, so the
## artifact cannot drift from the code it describes.
##
## WHY THE REGISTRY LIVES HERE AND NOT IN catalog.gd. The build registry must reference
## residents.gd, farming.gd, schedule.gd, forage.gd and item_definitions.gd, and every one of
## those preloads catalog.gd. Putting the registry in catalog.gd would make those preloads
## circular. Nothing about a domain's own key table needs to move here: catalog.gd keeps
## owning its tables and this file keeps owning only the assembly of them.
##
## CANONICAL BYTES (ruling §10B). UTF-8 with no BOM; object keys sorted ascending ASCII at every
## level; no insignificant whitespace anywhere; exactly one final LF; integers in decimal with no
## leading plus and no leading zeros. Because every domain key, every entry key and the ruleset
## string are ASCII (is_ascii_key() enforces it), a canonical artifact is pure printable ASCII
## plus that one trailing LF, and the reader rejects any other byte. Strings escape only what
## JSON requires: \" \\ \b \f \n \r \t, and lowercase \u00xx for the remaining C0 controls.
## DEL (0x7f) and code points above 0x7f are NOT escaped -- JSON only requires escaping below
## 0x20 -- and cannot occur in an artifact anyway, because is_ascii_key() rejects both.
##
## ONE ENCODER, EXACT COMPARISON. encode_canonical() is the only producer. Verification compares
## the exact bytes, not a re-parsed structure: two documents can parse to equal dictionaries and
## still differ byte for byte, and it is the bytes the SHA-256 covers.
##
## ---------------------------------------------------------------------------------------
## SAVE WIRING -- IMPLEMENTED BUT UNWIRED (blocker: there is no save module in this repository).
## ARCH-SAVE-001/002 place this artifact in the save file as follows, and this module produces
## every value that placement needs, so the save module can embed them unchanged:
##   * `catalog_hash = SHA256(canonical catalog_ids.json bytes)`, the raw 32 digest bytes, goes
##     at save-header offset 72 (SAVE_HEADER_CATALOG_HASH_OFFSET). digest_of() / Artifact.digest.
##   * Section 2 CATALOG_IDS (SAVE_SECTION_ID) carries a little-endian u32 byte length followed
##     by those same canonical bytes: save_section_payload(). Its section descriptor's
##     schema_version is 1 (SAVE_SECTION_SCHEMA_VERSION) and its row_count is the number of
##     domain entries across all domains: Artifact.row_count.
##   * No duplicate embedded hash is needed; the header digest is the only copy.
##   * On load, verify_embedded() validates the embedded mapping, the digest and the installed
##     catalog BEFORE any world mutation, per §4.2's "a registry validation failure aborts
##     loading before mutating the current world". It is static and pure: it cannot mutate a
##     world even by mistake, and a mismatch refuses with a catalog/version code instead of
##     reassigning live IDs. An explicit migration is a separate, unwritten contract.
## No save writer is stubbed here. When the save module lands it calls the four functions named
## above; until then this wiring is unexercised by any shipping path.
##
## OFFSET 40 IS A DIFFERENT CONTRACT. The rules hash at SAVE_HEADER_RULES_HASH_OFFSET covers the
## numerical definitions; this digest covers only the key -> ID map. Growth hours, yields, masses
## and work costs are NOT in this artifact, so an unchanged catalog digest proves only that the
## ID mapping is unchanged. VerifyResult.proves_rules_unchanged is therefore always false, on
## success as well as on refusal. Never present a catalog match as a ruleset match.
##
## ---------------------------------------------------------------------------------------
## NOT RELEASE-COMPLETE, AND SAID SO OUT LOUD. This artifact carries every id-carrying domain
## that has both an implementation and a declared domain name today. These are named in the
## specifications and are NOT in it, each with its blocker:
##   * RecipeDefinition, RecipeFamily (BAL-CAT-002/005) and the Station service domain
##     (BAL-CAT-011, whose keys are brewery, composter, dryer, kitchen, mill, nursery, preserver,
##     saltpan, well, workbench, workshop and which BAL-CAT-011 says in terms "indexes a service
##     domain, not the BuildingDefinition index"): no module implements them yet, and
##     transcribing a document into a registry HERE would be the hand-written second copy this
##     module exists to prevent. BuildingDefinition and FurnitureDefinition left this list on
##     2026-09-11 (decision 0056): catalog.gd now owns both complete tables, so this file reads
##     them from a registry like every other domain and still holds no copy of its own.
##   * The entity-kind domain (entity_directory.gd KIND_KEYS) and the RNG stream domain (rng.gd
##     STREAM_KEYS) are both ASCII-compiled, save-carried ID domains, but neither has a declared
##     domain NAME anywhere in the specs or the code. A domain name is the artifact's own object
##     key and changing it later changes the hash, so one is not invented here.
## Adding any of these is an intentional artifact/schema change: the bytes and the digest move,
## and every save written against the old digest refuses until an explicit migration exists.

const Catalog := preload("res://scripts/core/catalog.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const ForageScript := preload("res://scripts/core/forage.gd")

## Where the committed artifact lives. Generated into `godot/data/catalog_ids.json`.
const ARTIFACT_PATH: String = "res://data/catalog_ids.json"

## Ruling §10B's document shape. `schema_version` 1 is the only version this build accepts.
const SCHEMA_VERSION: int = 1
## AGENTS.md: "The active ruleset is settlement_rules_v2."
const RULESET: String = "settlement_rules_v2"
const FIELD_DOMAINS: String = "domains"
const FIELD_RULESET: String = "ruleset"
const FIELD_SCHEMA_VERSION: String = "schema_version"

## ARCH-SAVE-001's header table and ARCH-SAVE-002's section order. Implemented, unwired.
const SAVE_HEADER_RULES_HASH_OFFSET: int = 40
const SAVE_HEADER_CATALOG_HASH_OFFSET: int = 72
const SAVE_SECTION_ID: int = 2
const SAVE_SECTION_SCHEMA_VERSION: int = 1
const DIGEST_BYTES: int = 32
const SECTION_LENGTH_BYTES: int = 4
## A u32 length prefix cannot describe a longer payload than this.
const SECTION_LENGTH_MAX: int = 4294967295

const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647

## The seven compiled definition domains that have both an implementation and a declared name.
## The thirteen protected §4.3 enums and the six compiled §4.2 domains come straight from
## catalog.gd's own lists, so this file names no domain catalog.gd already names -- including
## BuildingDefinition and FurnitureDefinition, which catalog.gd owns and this file never spells.
const DEFINITION_DOMAINS: Array[String] = [
	Catalog.ITEM_DEFINITION_DOMAIN,
	ItemDefinitionsScript.CATEGORY_DOMAIN,
	ItemDefinitionsScript.EFFECT_DOMAIN,
	ResidentsScript.SPECIES_DOMAIN,
	FarmingScript.CROP_DEFINITION_DOMAIN,
	ScheduleScript.TEMPLATE_DOMAIN,
	ForageScript.QUOTA_MODE_DOMAIN,
]

# --- refusal codes (StringName, never a clamped value and never a sentinel id) -------------------

const REFUSE_NONE: StringName = &""
const REFUSE_EMPTY_INPUT: StringName = &"CATALOG_IDS_EMPTY_INPUT"
const REFUSE_BOM: StringName = &"CATALOG_IDS_BOM"
const REFUSE_NON_ASCII_BYTE: StringName = &"CATALOG_IDS_NON_ASCII_BYTE"
const REFUSE_RAW_CONTROL_BYTE: StringName = &"CATALOG_IDS_RAW_CONTROL_BYTE"
const REFUSE_MISSING_FINAL_LF: StringName = &"CATALOG_IDS_MISSING_FINAL_LF"
const REFUSE_TRAILING_BYTES: StringName = &"CATALOG_IDS_TRAILING_BYTES"
const REFUSE_WHITESPACE: StringName = &"CATALOG_IDS_NONCANONICAL_WHITESPACE"
const REFUSE_UNEXPECTED_TOKEN: StringName = &"CATALOG_IDS_UNEXPECTED_TOKEN"
const REFUSE_UNTERMINATED_STRING: StringName = &"CATALOG_IDS_UNTERMINATED_STRING"
const REFUSE_NONCANONICAL_ESCAPE: StringName = &"CATALOG_IDS_NONCANONICAL_ESCAPE"
const REFUSE_NONCANONICAL_INT: StringName = &"CATALOG_IDS_NONCANONICAL_INT"
const REFUSE_NON_INTEGER_ID: StringName = &"CATALOG_IDS_NON_INTEGER_ID"
const REFUSE_ID_OUT_OF_RANGE: StringName = &"CATALOG_IDS_ID_OUT_OF_RANGE"
const REFUSE_EMPTY_SENTINEL_ID: StringName = &"CATALOG_IDS_EMPTY_SENTINEL_ID"
const REFUSE_DUPLICATE_KEY: StringName = &"CATALOG_IDS_DUPLICATE_KEY"
const REFUSE_UNSORTED_KEY: StringName = &"CATALOG_IDS_UNSORTED_KEY"
const REFUSE_INVALID_ASCII_KEY: StringName = &"CATALOG_IDS_INVALID_ASCII_KEY"
const REFUSE_DUPLICATE_ID: StringName = &"CATALOG_IDS_DUPLICATE_ID"
const REFUSE_MISSING_FIELD: StringName = &"CATALOG_IDS_MISSING_FIELD"
const REFUSE_UNKNOWN_FIELD: StringName = &"CATALOG_IDS_UNKNOWN_FIELD"
const REFUSE_UNKNOWN_SCHEMA_VERSION: StringName = &"CATALOG_IDS_UNKNOWN_SCHEMA_VERSION"
const REFUSE_RULESET_MISMATCH: StringName = &"CATALOG_IDS_RULESET_MISMATCH"
const REFUSE_MISSING_DOMAIN: StringName = &"CATALOG_IDS_MISSING_DOMAIN"
const REFUSE_UNKNOWN_DOMAIN: StringName = &"CATALOG_IDS_UNKNOWN_DOMAIN"
const REFUSE_EMPTY_DOMAIN: StringName = &"CATALOG_IDS_EMPTY_DOMAIN"
const REFUSE_KEY_MISMATCH: StringName = &"CATALOG_IDS_KEY_MISMATCH"
const REFUSE_ID_MISMATCH: StringName = &"CATALOG_IDS_ID_MISMATCH"
const REFUSE_DIGEST_MISMATCH: StringName = &"CATALOG_IDS_DIGEST_MISMATCH"
const REFUSE_DIGEST_LENGTH: StringName = &"CATALOG_IDS_DIGEST_LENGTH"
const REFUSE_BYTES_MISMATCH: StringName = &"CATALOG_IDS_BYTES_MISMATCH"
const REFUSE_SECTION_TRUNCATED: StringName = &"CATALOG_IDS_SECTION_TRUNCATED"
const REFUSE_SECTION_LENGTH: StringName = &"CATALOG_IDS_SECTION_LENGTH"
const REFUSE_FILE_UNREADABLE: StringName = &"CATALOG_IDS_FILE_UNREADABLE"
const REFUSE_SOURCE_UNREADABLE: StringName = &"CATALOG_IDS_SOURCE_UNREADABLE"
const REFUSE_COMPILE_FAILED: StringName = &"CATALOG_IDS_COMPILE_FAILED"

# --- character codes used by the encoder and the strict reader -----------------------------------

const CH_TAB: int = 0x09
const CH_LF: int = 0x0a
const CH_SPACE: int = 0x20
const CH_QUOTE: int = 0x22
const CH_PLUS: int = 0x2b
const CH_COMMA: int = 0x2c
const CH_MINUS: int = 0x2d
const CH_ZERO: int = 0x30
const CH_NINE: int = 0x39
const CH_COLON: int = 0x3a
const CH_BACKSLASH: int = 0x5c
const CH_HEX_A_LOWER: int = 0x61
const CH_HEX_F_LOWER: int = 0x66
const CH_OPEN_BRACE: int = 0x7b
const CH_CLOSE_BRACE: int = 0x7d
const CH_DEL: int = 0x7f
const CH_PRINTABLE_MIN: int = 0x20
const CH_PRINTABLE_MAX: int = 0x7e
## Symbolic keys are printable ASCII excluding the space.
const CH_KEY_MIN: int = 0x21
const CH_KEY_MAX: int = 0x7e
## int32 in decimal is at most 10 digits plus a sign.
const MAX_INT_DIGITS: int = 10


class Refusal:
	"""One refusal: a StringName code and the human-readable detail behind it.

	`code == REFUSE_NONE` means no refusal. This is a result record, not a sentinel value
	standing in for data: nothing here ever returns a usable-looking id to signal failure.
	"""
	var code: StringName
	var detail: String

	func _init(p_code: StringName, p_detail: String) -> void:
		"""Store the refusal code and its detail."""
		code = p_code
		detail = p_detail

	func is_ok() -> bool:
		"""True when this record carries no refusal."""
		return code == REFUSE_NONE


class Artifact:
	"""One built catalog artifact: the mapping, its canonical bytes, its digest, its row count."""
	var domains: Dictionary
	var bytes: PackedByteArray
	var digest: PackedByteArray
	var row_count: int

	func _init(p_domains: Dictionary, p_bytes: PackedByteArray, p_digest: PackedByteArray,
			p_row_count: int) -> void:
		"""Store the built artifact's mapping, bytes, 32-byte digest and entry count."""
		domains = p_domains
		bytes = p_bytes
		digest = p_digest
		row_count = p_row_count

	func digest_hex() -> String:
		"""Lowercase hexadecimal spelling of the 32 digest bytes, for logs and manifests."""
		return digest.hex_encode()


class BuildResult:
	"""Outcome of building the artifact from the registries.

	`.ok` MUST be inspected first. On refusal `artifact` is null -- there is deliberately no
	half-built artifact and no placeholder to mistake for one.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var artifact: Artifact

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_artifact: Artifact) -> void:
		"""Store the outcome fields for this build attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		artifact = p_artifact


class ParseResult:
	"""Outcome of strictly parsing canonical artifact bytes.

	`.ok` MUST be inspected first. On refusal `domains` is empty and `row_count` is 0.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var domains: Dictionary
	var row_count: int

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_domains: Dictionary,
			p_row_count: int) -> void:
		"""Store the outcome fields for this parse attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		domains = p_domains
		row_count = p_row_count


class VerifyResult:
	"""Outcome of comparing an artifact against the installed catalog.

	`proves_rules_unchanged` is ALWAYS false, success included: this digest covers the key -> ID
	map only. The numerical definitions are the separate offset-40 rules hash, so a caller that
	wants "the ruleset is unchanged" must ask that contract, not this one.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var row_count: int
	var proves_rules_unchanged: bool = false

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_row_count: int) -> void:
		"""Store the outcome fields for this verification attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		row_count = p_row_count


class SectionResult:
	"""Outcome of decoding a CATALOG_IDS section payload back into canonical bytes."""
	var ok: bool
	var error: StringName
	var detail: String
	var bytes: PackedByteArray

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_bytes: PackedByteArray) -> void:
		"""Store the outcome fields for this section decode attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		bytes = p_bytes


class _Cursor:
	"""Reader state for the strict canonical parser: text, position and the first refusal."""
	var text: String
	var pos: int = 0
	var error: StringName = REFUSE_NONE
	var detail: String = ""

	func _init(p_text: String) -> void:
		"""Start a cursor at the beginning of `p_text`."""
		text = p_text

	func at_end() -> bool:
		"""True once every character has been consumed."""
		return pos >= text.length()

	func peek() -> int:
		"""The code point at the cursor, or -1 at the end of the text."""
		return -1 if at_end() else text.unicode_at(pos)

	func fail(p_code: StringName, p_detail: String) -> void:
		"""Record the FIRST refusal; later ones cannot overwrite what actually went wrong."""
		if error == REFUSE_NONE:
			error = p_code
			detail = p_detail


# --- the build registry --------------------------------------------------------------------------

static func registered_domains() -> Array[String]:
	"""Every domain the artifact is required to carry, taken from the registries themselves.

	Thirteen protected §4.3 enums plus six compiled §4.2 domains, both straight out of
	catalog.gd, plus the seven implemented definition domains. Declaration order is irrelevant:
	the encoder sorts, so this list may be shuffled without moving a single byte of the artifact.
	"""
	var names: Array[String] = []
	names.append_array(Catalog.PROTECTED_ENUM_DOMAINS)
	names.append_array(Catalog.COMPILED_ENUM_DOMAINS)
	names.append_array(DEFINITION_DOMAINS)
	return names


static func build(domain_names: Array[String] = registered_domains()) -> BuildResult:
	"""Compile every registered domain and produce the canonical bytes, digest and row count.

	Refuses without producing anything when a required domain is omitted, an unknown domain is
	requested, a domain fails to compile, or any key or id fails validation. Cold path only: it
	reads the item catalog from disk and allocates freely.
	"""
	var registry: Refusal = _check_registry(domain_names)
	if not registry.is_ok():
		return BuildResult.new(false, registry.code, registry.detail, null)
	var collected: Dictionary = {}
	var gather: Refusal = _gather_domains(domain_names, collected)
	if not gather.is_ok():
		return BuildResult.new(false, gather.code, gather.detail, null)
	var validation: Refusal = validate_domains(collected)
	if not validation.is_ok():
		return BuildResult.new(false, validation.code, validation.detail, null)
	var bytes: PackedByteArray = encode_canonical(collected)
	var artifact: Artifact = Artifact.new(collected, bytes, digest_of(bytes), row_count_of(collected))
	return BuildResult.new(true, REFUSE_NONE, "", artifact)


static func _check_registry(domain_names: Array[String]) -> Refusal:
	"""Refuse unless `domain_names` is exactly the registered set, in any order, without repeats."""
	var required: Array[String] = registered_domains()
	var seen: Dictionary = {}
	for name: String in domain_names:
		if seen.has(name):
			return Refusal.new(REFUSE_DUPLICATE_KEY, "domain '%s' requested twice" % name)
		if not required.has(name):
			return Refusal.new(REFUSE_UNKNOWN_DOMAIN, "'%s' is not a registered domain" % name)
		seen[name] = true
	for name: String in required:
		if not seen.has(name):
			return Refusal.new(REFUSE_MISSING_DOMAIN, "required domain '%s' is missing" % name)
	return Refusal.new(REFUSE_NONE, "")


static func _gather_domains(domain_names: Array[String], out: Dictionary) -> Refusal:
	"""Fill `out` with domain name -> (key -> id) for every requested domain, or refuse."""
	var item_source: Dictionary = {}
	var loaded: Refusal = _load_item_source(item_source)
	if not loaded.is_ok():
		return loaded
	for name: String in domain_names:
		var ids: Dictionary = {}
		var result: Refusal = _domain_ids(name, item_source, ids)
		if not result.is_ok():
			return result
		out[name] = ids
	return Refusal.new(REFUSE_NONE, "")


static func _domain_ids(domain_name: String, item_source: Dictionary, out: Dictionary) -> Refusal:
	"""Fill `out` with one domain's key -> id mapping, read from that domain's owning registry.

	A protected §4.3 enum is copied verbatim, explicit values and reserved gaps included. Every
	other domain is compiled by catalog.gd from its own key list, so its ids are the ascending
	ASCII order and nothing else.
	"""
	if Catalog.PROTECTED_ENUM_DOMAINS.has(domain_name):
		_copy_int_table(Catalog.fixed_enum(domain_name), out)
		return Refusal.new(REFUSE_NONE, "")
	if Catalog.COMPILED_ENUM_DOMAINS.has(domain_name):
		var verified: Catalog.DomainResult = Catalog.verify_compiled_enum(domain_name)
		if not verified.ok:
			return Refusal.new(REFUSE_COMPILE_FAILED, verified.error)
		_copy_int_table(verified.ids, out)
		return Refusal.new(REFUSE_NONE, "")
	var keys: Array[StringName] = []
	var source: Refusal = _definition_keys(domain_name, item_source, keys)
	if not source.is_ok():
		return source
	var compiled: Catalog.DomainResult = Catalog.compile_domain(domain_name, keys)
	if not compiled.ok:
		return Refusal.new(REFUSE_COMPILE_FAILED, compiled.error)
	_copy_int_table(compiled.ids, out)
	return Refusal.new(REFUSE_NONE, "")


static func _definition_keys(domain_name: String, item_source: Dictionary,
		out: Array[StringName]) -> Refusal:
	"""Fill `out` with one definition domain's keys, straight from its owning module's registry."""
	match domain_name:
		Catalog.ITEM_DEFINITION_DOMAIN:
			out.assign(item_source[Catalog.ITEM_DEFINITION_DOMAIN])
		ItemDefinitionsScript.CATEGORY_DOMAIN:
			out.assign(item_source[ItemDefinitionsScript.CATEGORY_DOMAIN])
		ItemDefinitionsScript.EFFECT_DOMAIN:
			out.assign(item_source[ItemDefinitionsScript.EFFECT_DOMAIN])
		ResidentsScript.SPECIES_DOMAIN:
			out.append_array(ResidentsScript.SPECIES_SMALL_KEYS)
			out.append_array(ResidentsScript.SPECIES_MEDIUM_KEYS)
			out.append_array(ResidentsScript.SPECIES_LARGE_KEYS)
		FarmingScript.CROP_DEFINITION_DOMAIN:
			out.append_array(FarmingScript.CROP_KEYS)
		ScheduleScript.TEMPLATE_DOMAIN:
			out.append_array(ScheduleScript.TEMPLATE_KEYS)
		ForageScript.QUOTA_MODE_DOMAIN:
			out.append_array(ForageScript.QUOTA_MODE_KEYS)
		_:
			return Refusal.new(REFUSE_UNKNOWN_DOMAIN, "no key source for '%s'" % domain_name)
	return Refusal.new(REFUSE_NONE, "")


static func _copy_int_table(table: Dictionary, out: Dictionary) -> void:
	"""Copy a key -> int table into `out` with String keys, never aliasing a const Dictionary."""
	for key: Variant in table.keys():
		out[String(key)] = int(table[key])


static func _load_item_source(out: Dictionary) -> Refusal:
	"""Read the item catalog file and fill `out` with the three item domains' key lists.

	The keys come from the same `res://data/item_definitions.json` item_definitions.gd loads, so
	the artifact describes the shipped item catalog rather than a transcription of it.
	"""
	var path: String = ItemDefinitionsScript.DEFAULT_JSON_PATH
	if not FileAccess.file_exists(path):
		return Refusal.new(REFUSE_SOURCE_UNREADABLE, "item catalog not found: %s" % path)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Refusal.new(REFUSE_SOURCE_UNREADABLE, "could not open item catalog: %s" % path)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return Refusal.new(REFUSE_SOURCE_UNREADABLE, "item catalog is not a JSON object: %s" % path)
	var dict: Dictionary = parsed
	if not dict.has("items") or typeof(dict["items"]) != TYPE_ARRAY:
		return Refusal.new(REFUSE_SOURCE_UNREADABLE, "item catalog has no \"items\" array")
	return _collect_item_keys(dict["items"], out)


static func _collect_item_keys(items: Array, out: Dictionary) -> Refusal:
	"""Collect the id, category and effect columns of every item row into three key lists."""
	var columns: Dictionary = {
		Catalog.ITEM_DEFINITION_DOMAIN: "id",
		ItemDefinitionsScript.CATEGORY_DOMAIN: "category",
		ItemDefinitionsScript.EFFECT_DOMAIN: "effect",
	}
	for domain_name: String in columns.keys():
		out[domain_name] = [] as Array[StringName]
	for index: int in items.size():
		if typeof(items[index]) != TYPE_DICTIONARY:
			return Refusal.new(REFUSE_SOURCE_UNREADABLE, "item row %d is not an object" % index)
		var row: Dictionary = items[index]
		for domain_name: String in columns.keys():
			var field: String = String(columns[domain_name])
			if not row.has(field) or typeof(row[field]) != TYPE_STRING:
				return Refusal.new(REFUSE_SOURCE_UNREADABLE,
					"item row %d has no string '%s'" % [index, field])
			var keys: Array[StringName] = out[domain_name]
			var key: StringName = StringName(String(row[field]))
			if not keys.has(key):
				keys.append(key)
	return Refusal.new(REFUSE_NONE, "")


# --- validation ----------------------------------------------------------------------------------

static func is_ascii_key(key: String) -> bool:
	"""True when `key` is a valid case-sensitive ASCII symbolic key.

	BAL-CAT-001: "IDs are case-sensitive ASCII StringName keys." Every character must be a
	printable ASCII code point 0x21..0x7e; the space, every control character and everything
	above 0x7f are rejected, and an empty key is rejected. No narrower alphabet is invented
	here: the specification states "ASCII" and nothing more, so nothing more is enforced.
	"""
	if key.is_empty():
		return false
	for index: int in key.length():
		var code: int = key.unicode_at(index)
		if code < CH_KEY_MIN or code > CH_KEY_MAX:
			return false
	return true


static func validate_domains(domains: Dictionary) -> Refusal:
	"""Refuse any domain map that could not be a legal artifact body.

	Rejects a non-ASCII domain or entry key, an empty domain, a non-integer id, an id outside
	int32, the -1 empty-reference sentinel (which is absence, never a catalog entry), and a
	duplicate id within one domain. Duplicate KEYS cannot exist in a Dictionary; the reader
	catches those in the document itself.
	"""
	for domain_name: Variant in domains.keys():
		if typeof(domain_name) != TYPE_STRING or not is_ascii_key(String(domain_name)):
			return Refusal.new(REFUSE_INVALID_ASCII_KEY, "domain key '%s' is not ASCII" % domain_name)
		if typeof(domains[domain_name]) != TYPE_DICTIONARY:
			return Refusal.new(REFUSE_UNEXPECTED_TOKEN, "domain '%s' is not an object" % domain_name)
		var entries: Dictionary = domains[domain_name]
		if entries.is_empty():
			return Refusal.new(REFUSE_EMPTY_DOMAIN, "domain '%s' has no entries" % domain_name)
		var refusal: Refusal = _validate_entries(String(domain_name), entries)
		if not refusal.is_ok():
			return refusal
	return Refusal.new(REFUSE_NONE, "")


static func _validate_entries(domain_name: String, entries: Dictionary) -> Refusal:
	"""Validate one domain's entry keys and ids: ASCII keys, int32 ids, no -1, no duplicate id."""
	var seen_ids: Dictionary = {}
	for key: Variant in entries.keys():
		if typeof(key) != TYPE_STRING or not is_ascii_key(String(key)):
			return Refusal.new(REFUSE_INVALID_ASCII_KEY,
				"'%s' key '%s' is not a valid ASCII key" % [domain_name, key])
		var refusal: Refusal = _validate_id(domain_name, String(key), entries[key])
		if not refusal.is_ok():
			return refusal
		var id: int = int(entries[key])
		if seen_ids.has(id):
			return Refusal.new(REFUSE_DUPLICATE_ID,
				"'%s' id %d is used by '%s' and '%s'" % [domain_name, id, seen_ids[id], key])
		seen_ids[id] = key
	return Refusal.new(REFUSE_NONE, "")


static func _validate_id(domain_name: String, key: String, value: Variant) -> Refusal:
	"""Refuse a non-integer id, the -1 empty sentinel, and anything outside 0..int32 max."""
	if typeof(value) != TYPE_INT:
		return Refusal.new(REFUSE_NON_INTEGER_ID,
			"'%s' key '%s' has a non-integer id" % [domain_name, key])
	var id: int = int(value)
	if id == Catalog.EMPTY_CATALOG_ID:
		return Refusal.new(REFUSE_EMPTY_SENTINEL_ID,
			"'%s' key '%s' is the -1 empty sentinel, which is never a catalog entry"
				% [domain_name, key])
	if id < 0 or id > INT32_MAX:
		return Refusal.new(REFUSE_ID_OUT_OF_RANGE,
			"'%s' key '%s' id %d is outside 0..%d" % [domain_name, key, id, INT32_MAX])
	return Refusal.new(REFUSE_NONE, "")


static func row_count_of(domains: Dictionary) -> int:
	"""Number of domain entries across all domains: the CATALOG_IDS section descriptor row_count."""
	var total: int = 0
	for domain_name: Variant in domains.keys():
		var entries: Dictionary = domains[domain_name]
		total += entries.size()
	return total


# --- the one canonical encoder --------------------------------------------------------------------

static func encode_canonical(domains: Dictionary) -> PackedByteArray:
	"""Encode one domain map into the artifact's canonical bytes. The ONLY producer of them.

	Top-level members are emitted in ascending ASCII order -- domains, ruleset, schema_version --
	as are the domain names and every entry key inside them. No whitespace, one final LF, UTF-8
	without a BOM.
	"""
	var text: String = "{" + encode_string(FIELD_DOMAINS) + ":{"
	var names: Array[String] = _sorted_keys(domains)
	for index: int in names.size():
		if index > 0:
			text += ","
		text += encode_string(names[index]) + ":" + _encode_entries(domains[names[index]])
	text += "}," + encode_string(FIELD_RULESET) + ":" + encode_string(RULESET)
	text += "," + encode_string(FIELD_SCHEMA_VERSION) + ":" + encode_int(SCHEMA_VERSION) + "}"
	text += String.chr(CH_LF)
	return text.to_utf8_buffer()


static func _encode_entries(entries: Dictionary) -> String:
	"""Encode one domain's key -> id object with its keys in ascending ASCII order."""
	var keys: Array[String] = _sorted_keys(entries)
	var text: String = "{"
	for index: int in keys.size():
		if index > 0:
			text += ","
		text += encode_string(keys[index]) + ":" + encode_int(int(entries[keys[index]]))
	return text + "}"


static func _sorted_keys(source: Dictionary) -> Array[String]:
	"""One object's keys as Strings in ascending ASCII order, independent of insertion order."""
	var keys: Array[String] = []
	for key: Variant in source.keys():
		keys.append(String(key))
	keys.sort()
	return keys


static func encode_int(value: int) -> String:
	"""Canonical decimal spelling of an integer: no leading plus, no leading zeros, no exponent."""
	return String.num_int64(value, 10)


static func encode_string(value: String) -> String:
	"""Encode one JSON string with the canonical escape set, quotes included."""
	var text: String = String.chr(CH_QUOTE)
	for index: int in value.length():
		text += _escape_code_point(value.unicode_at(index))
	return text + String.chr(CH_QUOTE)


static func _escape_code_point(code: int) -> String:
	"""One code point's canonical JSON spelling.

	Short escapes for quote, backslash and the five named controls; lowercase `\\u00xx` for the
	remaining C0 controls. DEL and everything above 0x7f are emitted literally, because JSON
	requires escaping only below 0x20 -- neither can appear in an artifact, since is_ascii_key()
	rejects both in every key and the ruleset string is plain ASCII.
	"""
	match code:
		CH_QUOTE:
			return "\\\""
		CH_BACKSLASH:
			return "\\\\"
		0x08:
			return "\\b"
		0x0c:
			return "\\f"
		CH_LF:
			return "\\n"
		0x0d:
			return "\\r"
		CH_TAB:
			return "\\t"
	if code < CH_PRINTABLE_MIN:
		return "\\u00%02x" % code
	return String.chr(code)


static func digest_of(bytes: PackedByteArray) -> PackedByteArray:
	"""SHA-256 over exactly these bytes: the save header's offset-72 catalog hash."""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()


# --- the strict canonical reader ------------------------------------------------------------------

static func parse_canonical(bytes: PackedByteArray) -> ParseResult:
	"""Parse artifact bytes strictly, refusing all but a hair's breadth of the canonical form.

	Rejects a BOM, a missing or extra final LF, any raw control or non-ASCII byte, insignificant
	whitespace, a duplicate object key, an unsorted object key, a non-canonical integer or
	escape, an unknown schema version, a foreign ruleset, and any id validate_domains() refuses.

	IT IS NOT THE CANONICITY AUTHORITY, and must not be treated as one. `-0` is valid JSON for
	the integer 0 and parses here, though encode_int() would have written `0`; the EXACT BYTE
	COMPARISON in verify_bytes() is what refuses it. Keep both. This reader is hand-written, so
	the byte comparison is the only check that cannot have a gap of its own.
	"""
	var shape: Refusal = _check_byte_shape(bytes)
	if not shape.is_ok():
		return ParseResult.new(false, shape.code, shape.detail, {}, 0)
	var cursor: _Cursor = _Cursor.new(bytes.slice(0, bytes.size() - 1).get_string_from_ascii())
	var top: Variant = _parse_value(cursor)
	if cursor.error != REFUSE_NONE:
		return ParseResult.new(false, cursor.error, cursor.detail, {}, 0)
	if not cursor.at_end():
		return ParseResult.new(false, REFUSE_TRAILING_BYTES,
			"%d byte(s) follow the top-level object" % (cursor.text.length() - cursor.pos), {}, 0)
	return _validate_document(top)


static func _check_byte_shape(bytes: PackedByteArray) -> Refusal:
	"""Refuse an empty document, a BOM, a missing final LF, and any non-printable-ASCII byte."""
	if bytes.is_empty():
		return Refusal.new(REFUSE_EMPTY_INPUT, "the artifact is empty")
	if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
		return Refusal.new(REFUSE_BOM, "the artifact starts with a UTF-8 BOM")
	if bytes[bytes.size() - 1] != CH_LF:
		return Refusal.new(REFUSE_MISSING_FINAL_LF, "the artifact does not end with one LF")
	for index: int in bytes.size() - 1:
		var byte: int = bytes[index]
		# DEL is tested BEFORE the printable ceiling: 0x7f is above CH_PRINTABLE_MAX, so testing
		# the ceiling first would make this clause unreachable and report the DEL control as a
		# non-ASCII byte.
		if byte < CH_PRINTABLE_MIN or byte == CH_DEL:
			return Refusal.new(REFUSE_RAW_CONTROL_BYTE,
				"byte %d is the raw control 0x%02x" % [index, byte])
		if byte > CH_PRINTABLE_MAX:
			return Refusal.new(REFUSE_NON_ASCII_BYTE,
				"byte %d is 0x%02x, outside printable ASCII" % [index, byte])
	return Refusal.new(REFUSE_NONE, "")


static func _parse_value(cursor: _Cursor) -> Variant:
	"""Parse one canonical value: an object, a string or an integer. Nothing else is legal."""
	var code: int = cursor.peek()
	if code == CH_OPEN_BRACE:
		return _parse_object(cursor)
	if code == CH_QUOTE:
		return _parse_string(cursor)
	if code == CH_MINUS or (code >= CH_ZERO and code <= CH_NINE):
		return _parse_int(cursor)
	if code == CH_PLUS:
		cursor.fail(REFUSE_NONCANONICAL_INT, "leading plus at offset %d" % cursor.pos)
		return null
	if code == CH_SPACE:
		cursor.fail(REFUSE_WHITESPACE, "whitespace at offset %d" % cursor.pos)
		return null
	cursor.fail(REFUSE_UNEXPECTED_TOKEN, "unexpected byte at offset %d" % cursor.pos)
	return null


static func _parse_object(cursor: _Cursor) -> Dictionary:
	"""Parse one object, enforcing unique, strictly ascending ASCII keys and no whitespace."""
	var out: Dictionary = {}
	cursor.pos += 1
	if cursor.peek() == CH_CLOSE_BRACE:
		cursor.pos += 1
		return out
	var previous: String = ""
	var count: int = 0
	while true:
		previous = _parse_member(cursor, out, previous, count)
		if cursor.error != REFUSE_NONE:
			return out
		count += 1
		var next: int = cursor.peek()
		if next == CH_COMMA:
			cursor.pos += 1
			continue
		if next == CH_CLOSE_BRACE:
			cursor.pos += 1
			return out
		_fail_separator(cursor, next)
		return out
	return out


static func _fail_separator(cursor: _Cursor, code: int) -> void:
	"""Record the right refusal for a byte where a comma or closing brace was required."""
	if code == CH_SPACE:
		cursor.fail(REFUSE_WHITESPACE, "whitespace at offset %d" % cursor.pos)
		return
	cursor.fail(REFUSE_UNEXPECTED_TOKEN,
		"expected ',' or '}' at offset %d" % cursor.pos)


static func _parse_member(cursor: _Cursor, out: Dictionary, previous: String, index: int) -> String:
	"""Parse one `"key":value` member into `out`; returns the key for the ordering check."""
	if cursor.peek() != CH_QUOTE:
		_fail_separator(cursor, cursor.peek())
		return previous
	var key: String = _parse_string(cursor)
	if cursor.error != REFUSE_NONE:
		return previous
	if out.has(key):
		cursor.fail(REFUSE_DUPLICATE_KEY, "duplicate object key '%s'" % key)
		return previous
	if index > 0 and key < previous:
		cursor.fail(REFUSE_UNSORTED_KEY, "key '%s' sorts before '%s'" % [key, previous])
		return previous
	if cursor.peek() != CH_COLON:
		_fail_separator(cursor, cursor.peek())
		return key
	cursor.pos += 1
	var value: Variant = _parse_value(cursor)
	if cursor.error == REFUSE_NONE:
		out[key] = value
	return key


static func _parse_string(cursor: _Cursor) -> String:
	"""Parse one quoted string, refusing raw control characters and non-canonical escapes.

	The raw-control branch is a backstop, not the active gate: _check_byte_shape() has already
	screened every byte of the document, so a control can only arrive here if that screen is ever
	weakened. Keep both.
	"""
	cursor.pos += 1
	var text: String = ""
	while true:
		if cursor.at_end():
			cursor.fail(REFUSE_UNTERMINATED_STRING, "string is not closed")
			return text
		var code: int = cursor.peek()
		cursor.pos += 1
		if code == CH_QUOTE:
			return text
		if code == CH_BACKSLASH:
			text += _parse_escape(cursor)
			if cursor.error != REFUSE_NONE:
				return text
			continue
		if code < CH_PRINTABLE_MIN or code == CH_DEL:
			cursor.fail(REFUSE_RAW_CONTROL_BYTE, "raw control 0x%02x inside a string" % code)
			return text
		text += String.chr(code)
	return text


static func _parse_escape(cursor: _Cursor) -> String:
	"""Parse one escape sequence, accepting only the escapes the canonical encoder emits."""
	if cursor.at_end():
		cursor.fail(REFUSE_UNTERMINATED_STRING, "escape at end of text")
		return ""
	var code: int = cursor.peek()
	cursor.pos += 1
	match code:
		CH_QUOTE:
			return "\""
		CH_BACKSLASH:
			return "\\"
		0x62:
			return String.chr(0x08)
		0x66:
			return String.chr(0x0c)
		0x6e:
			return String.chr(CH_LF)
		0x72:
			return String.chr(0x0d)
		0x74:
			return String.chr(CH_TAB)
		0x75:
			return _parse_unicode_escape(cursor)
	cursor.fail(REFUSE_NONCANONICAL_ESCAPE, "'\\%s' is not a canonical escape" % String.chr(code))
	return ""


static func _parse_unicode_escape(cursor: _Cursor) -> String:
	"""Parse `\\u00xx`: exactly four digits, `00` then two LOWERCASE hex digits below 0x20.

	Anything the canonical encoder would have written differently is refused: an uppercase hex
	digit, a code point that has a short escape, and any code point a canonical encoder emits
	literally. The four characters are checked to BE hex digits before `hex_to_int()` sees them:
	a truncated escape otherwise hands it the following `":` and it raises an engine error while
	quietly returning 0.
	"""
	if cursor.text.length() - cursor.pos < 4:
		cursor.fail(REFUSE_NONCANONICAL_ESCAPE, "truncated \\u escape")
		return ""
	var digits: String = cursor.text.substr(cursor.pos, 4)
	cursor.pos += 4
	if not _is_lowercase_hex(digits):
		cursor.fail(REFUSE_NONCANONICAL_ESCAPE,
			"'\\u%s' is not four lowercase hexadecimal digits" % digits)
		return ""
	if not digits.begins_with("00"):
		cursor.fail(REFUSE_NONCANONICAL_ESCAPE, "'\\u%s' is not a C0 control escape" % digits)
		return ""
	var code: int = digits.hex_to_int()
	if _escape_code_point(code) != "\\u%s" % digits:
		cursor.fail(REFUSE_NONCANONICAL_ESCAPE, "'\\u%s' has a shorter canonical spelling" % digits)
		return ""
	return String.chr(code)


static func _is_lowercase_hex(text: String) -> bool:
	"""True when every character is `0`-`9` or a LOWERCASE `a`-`f`: the only hex this encoder emits."""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var is_digit: bool = code >= CH_ZERO and code <= CH_NINE
		var is_letter: bool = code >= CH_HEX_A_LOWER and code <= CH_HEX_F_LOWER
		if not (is_digit or is_letter):
			return false
	return true


static func _parse_int(cursor: _Cursor) -> Variant:
	"""Parse one canonical integer: optional minus, no leading zeros, no fraction, no exponent."""
	var start: int = cursor.pos
	if cursor.peek() == CH_MINUS:
		cursor.pos += 1
	var first: int = cursor.pos
	while not cursor.at_end():
		var code: int = cursor.peek()
		if code < CH_ZERO or code > CH_NINE:
			break
		cursor.pos += 1
	if cursor.pos == first:
		cursor.fail(REFUSE_NON_INTEGER_ID, "no digits at offset %d" % start)
		return null
	var digits: String = cursor.text.substr(first, cursor.pos - first)
	if digits.length() > 1 and digits.begins_with("0"):
		cursor.fail(REFUSE_NONCANONICAL_INT, "'%s' has a leading zero" % digits)
		return null
	if digits.length() > MAX_INT_DIGITS:
		cursor.fail(REFUSE_ID_OUT_OF_RANGE, "'%s' cannot be an int32" % digits)
		return null
	return _finish_int(cursor, start)


static func _finish_int(cursor: _Cursor, start: int) -> Variant:
	"""Reject a fraction or exponent following an integer, then return its value."""
	var next: int = cursor.peek()
	if next == 0x2e or next == 0x65 or next == 0x45:
		cursor.fail(REFUSE_NON_INTEGER_ID, "non-integer number at offset %d" % start)
		return null
	var token: String = cursor.text.substr(start, cursor.pos - start)
	var value: int = token.to_int()
	if value < INT32_MIN or value > INT32_MAX:
		cursor.fail(REFUSE_ID_OUT_OF_RANGE, "'%s' is outside int32" % token)
		return null
	return value


static func _validate_document(top: Variant) -> ParseResult:
	"""Check the three top-level fields, then hand the domain map to validate_domains()."""
	if typeof(top) != TYPE_DICTIONARY:
		return ParseResult.new(false, REFUSE_UNEXPECTED_TOKEN, "top level is not an object", {}, 0)
	var document: Dictionary = top
	var fields: Refusal = _check_fields(document)
	if not fields.is_ok():
		return ParseResult.new(false, fields.code, fields.detail, {}, 0)
	if typeof(document[FIELD_DOMAINS]) != TYPE_DICTIONARY:
		return ParseResult.new(false, REFUSE_UNEXPECTED_TOKEN, "\"domains\" is not an object", {}, 0)
	var domains: Dictionary = document[FIELD_DOMAINS]
	var validation: Refusal = validate_domains(domains)
	if not validation.is_ok():
		return ParseResult.new(false, validation.code, validation.detail, {}, 0)
	return ParseResult.new(true, REFUSE_NONE, "", domains, row_count_of(domains))


static func _check_fields(document: Dictionary) -> Refusal:
	"""Refuse a missing or unknown top-level field, a foreign ruleset, or an unknown version."""
	for field: String in [FIELD_DOMAINS, FIELD_RULESET, FIELD_SCHEMA_VERSION]:
		if not document.has(field):
			return Refusal.new(REFUSE_MISSING_FIELD, "no \"%s\" field" % field)
	if document.size() != 3:
		return Refusal.new(REFUSE_UNKNOWN_FIELD, "the document has %d fields, not 3" % document.size())
	if typeof(document[FIELD_SCHEMA_VERSION]) != TYPE_INT \
			or int(document[FIELD_SCHEMA_VERSION]) != SCHEMA_VERSION:
		return Refusal.new(REFUSE_UNKNOWN_SCHEMA_VERSION,
			"schema_version %s is not %d" % [document[FIELD_SCHEMA_VERSION], SCHEMA_VERSION])
	if typeof(document[FIELD_RULESET]) != TYPE_STRING or String(document[FIELD_RULESET]) != RULESET:
		return Refusal.new(REFUSE_RULESET_MISMATCH,
			"ruleset %s is not '%s'" % [document[FIELD_RULESET], RULESET])
	return Refusal.new(REFUSE_NONE, "")


# --- verification (never a write, never a world mutation) -----------------------------------------

static func verify_bytes(bytes: PackedByteArray) -> VerifyResult:
	"""Compare candidate artifact bytes with the installed catalog. Mutates nothing, ever.

	Parses strictly, compares the mapping domain by domain for a precise refusal, then compares
	the EXACT canonical bytes: a document that re-parses equal but encodes differently is still
	refused, because the digest covers bytes and not a parsed structure.
	"""
	var parsed: ParseResult = parse_canonical(bytes)
	if not parsed.ok:
		return VerifyResult.new(false, parsed.error, parsed.detail, 0)
	var built: BuildResult = build()
	if not built.ok:
		return VerifyResult.new(false, built.error, built.detail, 0)
	var compared: Refusal = compare_domains(parsed.domains, built.artifact.domains)
	if not compared.is_ok():
		return VerifyResult.new(false, compared.code, compared.detail, 0)
	if bytes != built.artifact.bytes:
		return VerifyResult.new(false, REFUSE_BYTES_MISMATCH,
			"canonical bytes differ at offset %d" % _first_difference(bytes, built.artifact.bytes), 0)
	return VerifyResult.new(true, REFUSE_NONE, "", parsed.row_count)


static func verify_file(path: String = ARTIFACT_PATH) -> VerifyResult:
	"""Verify the committed artifact file against the installed catalog. Never rewrites it."""
	if not FileAccess.file_exists(path):
		return VerifyResult.new(false, REFUSE_FILE_UNREADABLE, "artifact not found: %s" % path, 0)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return VerifyResult.new(false, REFUSE_FILE_UNREADABLE, "could not open %s" % path, 0)
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return verify_bytes(bytes)


static func verify_embedded(section_payload: PackedByteArray,
		header_digest: PackedByteArray) -> VerifyResult:
	"""The save-load entry point: validate an embedded mapping, its digest and the catalog.

	Called BEFORE any world mutation (GDD §4.2, ARCH-SAVE-004). Every function it reaches is
	static and pure, so a refusal cannot have touched a live column, and it never reassigns an
	id: a mismatch is a catalog/version refusal for the caller to act on.
	"""
	if header_digest.size() != DIGEST_BYTES:
		return VerifyResult.new(false, REFUSE_DIGEST_LENGTH,
			"the header digest is %d bytes, not %d" % [header_digest.size(), DIGEST_BYTES], 0)
	var section: SectionResult = decode_section_payload(section_payload)
	if not section.ok:
		return VerifyResult.new(false, section.error, section.detail, 0)
	if digest_of(section.bytes) != header_digest:
		return VerifyResult.new(false, REFUSE_DIGEST_MISMATCH,
			"offset-%d catalog hash does not cover these bytes" % SAVE_HEADER_CATALOG_HASH_OFFSET, 0)
	return verify_bytes(section.bytes)


static func compare_domains(actual: Dictionary, expected: Dictionary) -> Refusal:
	"""Compare a candidate mapping against the installed one, naming the first difference."""
	for name: String in _sorted_keys(expected):
		if not actual.has(name):
			return Refusal.new(REFUSE_MISSING_DOMAIN, "the artifact has no domain '%s'" % name)
		var refusal: Refusal = _compare_entries(name, actual[name], expected[name])
		if not refusal.is_ok():
			return refusal
	for name: String in _sorted_keys(actual):
		if not expected.has(name):
			return Refusal.new(REFUSE_UNKNOWN_DOMAIN,
				"the artifact carries domain '%s', which this build does not compile" % name)
	return Refusal.new(REFUSE_NONE, "")


static func _compare_entries(domain_name: String, actual: Dictionary,
		expected: Dictionary) -> Refusal:
	"""Compare one domain's keys and ids, naming the first key or id that differs."""
	for key: String in _sorted_keys(expected):
		if not actual.has(key):
			return Refusal.new(REFUSE_KEY_MISMATCH, "'%s' is missing key '%s'" % [domain_name, key])
		if int(actual[key]) != int(expected[key]):
			return Refusal.new(REFUSE_ID_MISMATCH, "'%s' key '%s' is %d here and %d installed"
				% [domain_name, key, int(actual[key]), int(expected[key])])
	for key: String in _sorted_keys(actual):
		if not expected.has(key):
			return Refusal.new(REFUSE_KEY_MISMATCH,
				"'%s' carries key '%s', which this build does not compile" % [domain_name, key])
	return Refusal.new(REFUSE_NONE, "")


static func _first_difference(left: PackedByteArray, right: PackedByteArray) -> int:
	"""Offset of the first differing byte, or the shorter length when one is a prefix."""
	var limit: int = mini(left.size(), right.size())
	for index: int in limit:
		if left[index] != right[index]:
			return index
	return limit


# --- save section payload (ARCH-SAVE-002 section 2; implemented, unwired) --------------------------

static func save_section_payload(artifact: Artifact) -> PackedByteArray:
	"""The CATALOG_IDS section body: little-endian u32 byte length then the canonical bytes.

	A save writer copies this verbatim; its section descriptor takes SAVE_SECTION_ID,
	SAVE_SECTION_SCHEMA_VERSION and `artifact.row_count`, and the header takes `artifact.digest`
	at SAVE_HEADER_CATALOG_HASH_OFFSET.
	"""
	var payload: PackedByteArray = PackedByteArray()
	payload.resize(SECTION_LENGTH_BYTES)
	payload.encode_u32(0, artifact.bytes.size())
	payload.append_array(artifact.bytes)
	return payload


static func decode_section_payload(payload: PackedByteArray) -> SectionResult:
	"""Decode a CATALOG_IDS section body back into canonical bytes, or refuse."""
	if payload.size() < SECTION_LENGTH_BYTES:
		return SectionResult.new(false, REFUSE_SECTION_TRUNCATED,
			"the section is %d bytes, shorter than its length prefix" % payload.size(),
			PackedByteArray())
	var length: int = payload.decode_u32(0)
	if length > SECTION_LENGTH_MAX or length != payload.size() - SECTION_LENGTH_BYTES:
		return SectionResult.new(false, REFUSE_SECTION_LENGTH,
			"the length prefix says %d bytes but %d follow"
				% [length, payload.size() - SECTION_LENGTH_BYTES], PackedByteArray())
	return SectionResult.new(true, REFUSE_NONE, "", payload.slice(SECTION_LENGTH_BYTES))
