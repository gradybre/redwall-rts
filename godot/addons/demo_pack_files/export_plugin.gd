@tool
extends EditorExportPlugin
## Adds the underground binaries the running game opens with FileAccess (res://data/underground/runtime_files.gd) to
## an export carrying the demo_build feature (decision 1841).
##
## The preset's include_filter cannot pack them: Godot's exporter never enters a folder holding a .gdignore, even
## for a path named exactly, and four of them sit under one. Each file is read at its pinned digest or not packed at
## all: a missing or changed file is an ERROR line, which fails tools/build_demo_windows.py's export step.

const FEATURE: String = "demo_build"
const MANIFEST: String = "res://data/underground/runtime_files.gd"


func _get_name() -> String:
	"""The plugin's name, which Godot requires."""
	return "DemoPackFiles"


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	"""Pack every listed file at its own res:// path. Loaded here, not preloaded, so an editor session that never
	exports the demo never compiles the underground readers the list names."""
	if not features.has(FEATURE):
		return
	var manifest: Script = load(MANIFEST) as Script
	var files: Dictionary = manifest.get_script_constant_map().get("FILES", {}) if manifest != null else {}
	if files.is_empty():
		push_error("demo pack files: no FILES in " + MANIFEST)
		return
	for path: String in files:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or _sha256(bytes) != files[path]:
			push_error("demo pack files: %s is missing or not at its pinned digest %s" % [path, files[path]])
			continue
		add_file(path, bytes, false)


static func _sha256(bytes: PackedByteArray) -> String:
	"""Lowercase hex SHA-256, as the readers pin it."""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
