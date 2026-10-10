extends "res://test/framework/test_case.gd"
## The underground binaries the demo pack must carry (decision 1841): each listed file is on disk at its pinned digest,
## and every binary the demo's reachable code names is either listed or declared unread, so the list cannot go stale.

const Files := preload("res://data/underground/runtime_files.gd")
const DEMO_SCENE: String = "res://demo/demo_village.tscn"
## Resource types the exporter's "all_resources" filter follows; a reachable file of these kinds is walked.
const WALKED: PackedStringArray = ["gd", "tscn", "tres", "gdshader"]
## What the preset's include_filter already packs: every JSON file and the staged demo assets.
const INCLUDED_PREFIX: String = "res://demo/assets/"
## Neither is exported (the preset's exclude_filter), so nothing the game runs is named from there.
const UNEXPORTED: PackedStringArray = ["res://test/", "res://tools/"]
var _literal: RegEx = null
var _relative: RegEx = null


func before_each() -> void:
	"""Compile the two path patterns once per test."""
	_literal = RegEx.create_from_string("\"(res://[^\"]+)\"")
	_relative = RegEx.create_from_string("preload\\(\"(\\.{1,2}/[^\"]+)\"\\)")


func after_each() -> void:
	"""Release the compiled patterns."""
	_literal = null
	_relative = null


func test_every_listed_file_is_on_disk_at_its_pinned_digest() -> void:
	"""The list holds the readers' own pins, so a stale file or a renewed pin without its bytes fails here."""
	assert_equal(Files.FILES.size(), 14, "the level pack, six actors, profile, catalog, motion and four bundle files")
	for path: String in Files.FILES:
		assert_true(FileAccess.file_exists(path), "on disk: " + path)
		assert_equal(FileAccess.get_sha256(path), Files.FILES[path], "pinned digest: " + path)
		assert_false(ResourceLoader.exists(path), "not a resource the exporter would pack itself: " + path)


func test_the_list_names_exactly_the_binaries_the_demo_code_names() -> void:
	"""Walk the demo scene and every autoload through the resources their source names; each non-resource file they
	name, outside what the include_filter packs, must be listed or declared unread, and every listed one named."""
	var named: Dictionary = _named_binaries(_reachable())
	for path: String in named:
		assert_true(Files.FILES.has(path) or Files.NAMED_UNREAD.has(path),
			"a binary the demo names is in the pack list or declared unread: %s (named by %s)" % [path, named[path]])
	for path: String in Files.FILES:
		assert_true(named.has(path), "a listed binary is named by the demo's code: " + path)
	for path: String in Files.NAMED_UNREAD:
		assert_true(named.has(path) and not Files.FILES.has(path), "declared unread, named, and not packed: " + path)


func test_four_listed_files_sit_under_gdignore_where_include_filter_cannot_reach() -> void:
	"""Why the export plugin packs the list rather than the preset's include_filter (decision 1841)."""
	var ignored: int = 0
	for path: String in Files.FILES:
		if _under_gdignore(path):
			ignored += 1
	assert_equal(ignored, 4, "the wood and stone haul, claw and paw actor images")


func _reachable() -> PackedStringArray:
	"""Every walked resource reachable from the demo scene and the autoloads by a path its source names."""
	var queue: PackedStringArray = PackedStringArray([DEMO_SCENE])
	for setting: Dictionary in ProjectSettings.get_property_list():
		var name: String = setting["name"]
		if name.begins_with("autoload/"):
			queue.append(str(ProjectSettings.get_setting(name)).trim_prefix("*"))
	var seen: Dictionary = {}
	while not queue.is_empty():
		var path: String = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		if seen.has(path):
			continue
		seen[path] = true
		for named: String in _paths_in(path):
			if WALKED.has(named.get_extension()) and ResourceLoader.exists(named) and not seen.has(named):
				queue.append(named)
	return PackedStringArray(seen.keys())


func _named_binaries(sources: PackedStringArray) -> Dictionary:
	"""path -> the first source naming it, for every existing non-resource file the include_filter does not pack."""
	var named: Dictionary = {}
	for source: String in sources:
		for path: String in _paths_in(source):
			if not named.has(path) and FileAccess.file_exists(path) and not ResourceLoader.exists(path) \
					and path.get_extension() != "json" and not path.begins_with(INCLUDED_PREFIX):
				named[path] = source
	return named


func _paths_in(source: String) -> PackedStringArray:
	"""Every quoted res:// path in one file, and its preloads relative to its own folder, outside unexported trees."""
	var text: String = FileAccess.get_file_as_string(source)
	var out: PackedStringArray = PackedStringArray()
	for found: RegExMatch in _literal.search_all(text):
		out.append(found.get_string(1))
	for found: RegExMatch in _relative.search_all(text):
		out.append(source.get_base_dir().path_join(found.get_string(1)).simplify_path())
	return PackedStringArray(Array(out).filter(func(path: String) -> bool:
		return not path.begins_with(UNEXPORTED[0]) and not path.begins_with(UNEXPORTED[1])))


func _under_gdignore(path: String) -> bool:
	"""Whether any folder above `path` holds a .gdignore, which Godot's filesystem and exporter skip."""
	var folder: String = path.get_base_dir()
	while folder != "res://" and not folder.is_empty():
		if FileAccess.file_exists(folder.path_join(".gdignore")):
			return true
		folder = folder.get_base_dir()
	return false
