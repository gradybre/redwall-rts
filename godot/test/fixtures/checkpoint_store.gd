extends RefCounted
## Committed save checkpoints for long live-chain tests (decision 1240).
##
## A long chain test replays a settlement from tick 0 before it reaches the state it checks. A
## checkpoint is that state saved once, by `test/generate_checkpoints.gd`, and committed under
## `DIR`: one gzip member per named point (`<name>-<point>.rwlsave.gz`, the exact save bytes; the
## save format itself stays uncompressed, DEC-055) and one manifest (`<name>.json`).
##
## A checkpoint is keyed by a SOURCE FINGERPRINT: the SHA-256 of the engine version and of every
## res:// file reachable from its recipe's roots through quoted `"res://..."` literals (preloads,
## loads, data paths, scene resources), each with its own SHA-256. A literal with a format
## placeholder, or ending in `/`, stands for every file of its directory. A checkpoint whose
## fingerprint differs from the current source is REFUSED, with the files that changed and the
## command that regenerates it; it is never used stale. What the literal walk cannot see (a path
## assembled at run time from pieces) is covered by `test_checkpoint_equivalence.gd`, slow tier,
## which replays every recipe from tick 0 and compares the saves byte for byte with the files.

const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

const DIR: String = "res://test/fixtures/checkpoints"
const MANIFEST_VERSION: int = 1
## The command a stale or missing checkpoint names; `<name>` is appended.
const REGENERATE: String = "./tools/regenerate_test_checkpoints.sh"
const LITERAL_PATTERN: String = "\"(res://[^\"]*)\""
const ROOT_PREFIX: String = "res://"
## Text resources whose own res:// literals are followed.
const FOLLOWED_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
## Sidecars the editor writes beside a source; never part of what a run executes.
const IGNORED_EXTENSIONS: PackedStringArray = ["uid", "import"]
## How many changed files a stale refusal lists.
const LISTED_CHANGES: int = 8


class Loaded:
	"""One checkpoint point read back: the save bytes and the tick they were taken at, or why not."""
	var bytes: PackedByteArray = PackedByteArray()
	var tick: int = -1
	var error: String = ""

	func is_ok() -> bool:
		"""Whether the point was read, fresh and intact."""
		return error == ""


# --- the source fingerprint ----------------------------------------------------------------------

static func source_digests(roots: PackedStringArray) -> Dictionary:
	"""Path -> SHA-256 hex of every res:// file reachable from `roots` through quoted literals."""
	var digests: Dictionary = {}
	var pending: PackedStringArray = roots.duplicate()
	var literal: RegEx = RegEx.create_from_string(LITERAL_PATTERN)
	while not pending.is_empty():
		var path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for file: String in _files_named_by(path):
			if digests.has(file):
				continue
			digests[file] = FileAccess.get_sha256(file)
			if FOLLOWED_EXTENSIONS.has(file.get_extension()):
				for found: RegExMatch in literal.search_all(FileAccess.get_file_as_string(file)):
					pending.append(found.get_string(1))
	return digests


static func _files_named_by(literal: String) -> PackedStringArray:
	"""The files one literal names: itself, or every file of its directory for a pattern or a folder."""
	var files: PackedStringArray = PackedStringArray()
	if FileAccess.file_exists(literal):
		files.append(literal)
		return files
	if not (literal.contains("%") or literal.contains("{") or literal.ends_with("/")):
		return files
	var folder: String = literal.substr(0, literal.rfind("/"))
	# A bare "res://" (globalize_path("res://")) names the project, not a data folder.
	if folder.length() <= ROOT_PREFIX.length() or not DirAccess.dir_exists_absolute(folder):
		return files
	for file_name: String in DirAccess.get_files_at(folder):
		if not IGNORED_EXTENSIONS.has(file_name.get_extension()):
			files.append("%s/%s" % [folder, file_name])
	return files


static func engine_version() -> String:
	"""The engine's release identity; a different engine is a different checkpoint."""
	var info: Dictionary = Engine.get_version_info()
	return "%d.%d.%d.%s" % [info["major"], info["minor"], info["patch"], info["status"]]


static func fingerprint(name: String, digests: Dictionary) -> String:
	"""SHA-256 hex over the engine version, the checkpoint name and every (path, digest) in path order."""
	var paths: Array = digests.keys()
	paths.sort()
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s\n%s\n" % [engine_version(), name]).to_utf8_buffer())
	for path: String in paths:
		context.update(("%s %s\n" % [path, digests[path]]).to_utf8_buffer())
	return context.finish().hex_encode()


static func regenerate_command(name: String) -> String:
	"""The command that rebuilds checkpoint `name`."""
	return "%s %s" % [REGENERATE, name]


# --- reading -------------------------------------------------------------------------------------

static func read_manifest(name: String, dir: String = DIR) -> Dictionary:
	"""The parsed manifest of checkpoint `name`, or an empty Dictionary when it is absent or malformed."""
	var path: String = "%s/%s.json" % [dir, name]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != MANIFEST_VERSION:
		return {}
	return parsed


static func staleness(name: String, manifest: Dictionary) -> String:
	"""Empty when the manifest's fingerprint is the current source's; otherwise the refusal to print."""
	var roots: PackedStringArray = PackedStringArray(manifest.get("roots", []))
	var digests: Dictionary = source_digests(roots)
	if roots.size() > 0 and fingerprint(name, digests) == String(manifest.get("fingerprint", "")):
		return ""
	return "checkpoint '%s' is STALE: its source fingerprint no longer matches (engine %s, recorded %s; %s). " \
		% [name, engine_version(), manifest.get("engine", "?"), _changes(manifest.get("sources", {}), digests)] \
		+ "It is never used stale. Regenerate it with: %s" % regenerate_command(name)


static func _changes(recorded: Dictionary, current: Dictionary) -> String:
	"""The first LISTED_CHANGES paths added, removed or changed since the checkpoint was made."""
	var changed: PackedStringArray = PackedStringArray()
	var paths: Array = recorded.keys() + current.keys()
	paths.sort()
	for path: String in paths:
		if changed.size() < LISTED_CHANGES and String(recorded.get(path, "")) != String(current.get(path, "")) \
				and not changed.has(path):
			changed.append(path)
	return "changed: " + (", ".join(changed) if not changed.is_empty() else "no file; the engine or roots")


static func read_point(name: String, point: String, dir: String = DIR) -> Loaded:
	"""The save bytes of checkpoint `name` at `point`, refused when missing, stale or damaged."""
	var loaded: Loaded = Loaded.new()
	var manifest: Dictionary = read_manifest(name, dir)
	if manifest.is_empty():
		loaded.error = "no checkpoint '%s' in %s. Generate it with: %s" % [name, dir, regenerate_command(name)]
		return loaded
	loaded.error = staleness(name, manifest)
	var entry: Variant = manifest.get("points", {}).get(point)
	if loaded.is_ok() and not entry is Dictionary:
		loaded.error = "checkpoint '%s' has no point '%s'. Regenerate it with: %s" \
			% [name, point, regenerate_command(name)]
	if loaded.is_ok():
		_inflate(loaded, entry, dir)
	return loaded


static func _inflate(loaded: Loaded, entry: Dictionary, dir: String) -> void:
	"""Read one point's gzip member and check its length and SHA-256 against the manifest."""
	var path: String = "%s/%s" % [dir, entry.get("file", "")]
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) \
		else PackedByteArray()
	var size: int = int(entry.get("bytes", 0))
	var bytes: PackedByteArray = packed.decompress(size, FileAccess.COMPRESSION_GZIP) \
		if not packed.is_empty() and size > 0 else PackedByteArray()
	if bytes.size() != size or _sha256(bytes) != String(entry.get("sha256", "")):
		loaded.error = "checkpoint file %s is missing or damaged (%d of %d bytes, or a different SHA-256)" \
			% [path, bytes.size(), size]
		return
	loaded.bytes = bytes
	loaded.tick = int(entry.get("tick", -1))


static func load_into(settlement: Node, manager: Node, name: String, point: String,
		content: RefCounted = null) -> String:
	"""Load checkpoint `name` at `point` into `settlement` through the real save loader; "" or the refusal."""
	var loaded: Loaded = read_point(name, point)
	if not loaded.is_ok():
		return loaded.error
	var refusal: SaveHeader.Refusal = SettlementSave.load_bytes(settlement, manager, loaded.bytes, content)
	if not refusal.is_ok():
		return "checkpoint '%s' at '%s' did not load: %s %s" % [name, point, refusal.code, refusal.detail]
	if manager.clock().completed_tick() != loaded.tick:
		return "checkpoint '%s' at '%s' loaded at tick %d, not %d" \
			% [name, point, manager.clock().completed_tick(), loaded.tick]
	return ""


static func _sha256(bytes: PackedByteArray) -> String:
	"""SHA-256 hex of `bytes`."""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


# --- writing (test/generate_checkpoints.gd only) -------------------------------------------------

static func write(name: String, roots: PackedStringArray, points: Dictionary, dir: String = DIR) -> String:
	"""Write every point (point name -> [tick, bytes]) and the manifest, and remove this checkpoint's
	other files. Returns "" or why the write failed."""
	var entries: Dictionary = {}
	for point: String in points:
		var bytes: PackedByteArray = points[point][1]
		var file_name: String = "%s-%s.rwlsave.gz" % [name, point]
		if not _write_bytes("%s/%s" % [dir, file_name], bytes.compress(FileAccess.COMPRESSION_GZIP)):
			return "could not write %s/%s" % [dir, file_name]
		entries[point] = {"tick": int(points[point][0]), "file": file_name, "bytes": bytes.size(),
			"sha256": _sha256(bytes)}
	_remove_unlisted(name, entries, dir)
	var digests: Dictionary = source_digests(roots)
	var manifest: Dictionary = {"version": MANIFEST_VERSION, "name": name, "engine": engine_version(),
		"fingerprint": fingerprint(name, digests), "regenerate": regenerate_command(name),
		"roots": Array(roots), "points": entries, "sources": digests}
	var text: String = JSON.stringify(manifest, "\t", true) + "\n"
	if not _write_bytes("%s/%s.json" % [dir, name], text.to_utf8_buffer()):
		return "could not write the manifest of %s" % name
	return ""


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	"""Write `bytes` to `path`, creating its directory; true on success."""
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


static func _remove_unlisted(name: String, entries: Dictionary, dir: String) -> void:
	"""Delete gzip members of checkpoint `name` that no longer belong to any of its points."""
	var kept: PackedStringArray = PackedStringArray()
	for point: String in entries:
		kept.append(entries[point]["file"])
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.begins_with(name + "-") and file_name.ends_with(".rwlsave.gz") and not kept.has(file_name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [dir, file_name]))
