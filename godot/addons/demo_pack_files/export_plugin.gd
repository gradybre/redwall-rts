@tool
extends EditorExportPlugin
## Adds the underground binaries the running game opens with FileAccess (res://data/underground/runtime_files.gd) to
## an export carrying the demo_build feature (decision 1841).
##
## The preset's include_filter cannot pack them: Godot's exporter never enters a folder holding a .gdignore, even
## for a path named exactly, and four of them sit under one. Each file is packed only at its pinned digest. A missing
## or changed file is pushed as an ERROR line and left out: Godot gives _export_begin no way to abort the export, so
## that ERROR line is what fails tools/build_demo_windows.py's export step (and the pack check refuses the file again).
## Keep it an error, never a warning.

const FEATURE: String = "demo_build"
const MANIFEST: String = "res://data/underground/runtime_files.gd"


func _get_name() -> String:
	"""The plugin's name, which Godot requires."""
	return "DemoPackFiles"


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	"""Pack every listed file at its own res:// path, and report each one that cannot be."""
	var selected: Dictionary = files_to_pack(features)
	for path: String in selected["refused"]:
		push_error("demo pack files: %s is missing or not at its pinned digest" % path)
	var bytes: Dictionary = selected["bytes"]
	for path: String in bytes:
		add_file(path, bytes[path], false)


static func files_to_pack(features: PackedStringArray, files: Dictionary = {}) -> Dictionary:
	"""{"bytes": path -> bytes at its pinned digest, "refused": paths missing or changed} for an export with
	`features`: nothing without the demo_build feature. `files` defaults to the manifest, loaded here rather than
	preloaded so an editor session that never exports the demo never compiles the underground readers it names."""
	var result: Dictionary = {"bytes": {}, "refused": PackedStringArray()}
	if not features.has(FEATURE):
		return result
	if files.is_empty():
		var manifest: Script = load(MANIFEST) as Script
		files = manifest.get_script_constant_map().get("FILES", {}) if manifest != null else {}
	var refused: PackedStringArray = PackedStringArray([MANIFEST]) if files.is_empty() else PackedStringArray()
	for path: String in files:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or _sha256(bytes) != files[path]:
			refused.append(path)
		else:
			result["bytes"][path] = bytes
	result["refused"] = refused
	return result


static func _sha256(bytes: PackedByteArray) -> String:
	"""Lowercase hex SHA-256, as the readers pin it."""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
