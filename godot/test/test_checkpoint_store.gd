extends "res://test/framework/test_case.gd"
## `checkpoint_store.gd` (decision 1240): the source fingerprint, and the refusals that keep a stale,
## missing or damaged checkpoint from ever being used. Fast tier: nothing here replays a chain.
##
## The first test also fails the fast tier the moment a committed checkpoint goes stale, naming the
## command that regenerates it, so a per-commit run says so before any converted suite does.

const Recipes := preload("res://test/fixtures/checkpoint_recipes.gd")
const Store := preload("res://test/fixtures/checkpoint_store.gd")

const SCRATCH: String = "user://test_checkpoint_store"
const NAME: String = "scratch"
const POINT: String = "t9"


func after_each() -> void:
	"""Remove the scratch checkpoint directory."""
	var folder: String = ProjectSettings.globalize_path(SCRATCH)
	if DirAccess.dir_exists_absolute(folder):
		for file_name: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute("%s/%s" % [folder, file_name])
		DirAccess.remove_absolute(folder)


func test_every_committed_checkpoint_is_fresh() -> void:
	"""Each recipe has a committed manifest whose fingerprint is the current source's."""
	for name: String in Recipes.NAMES:
		var manifest: Dictionary = Store.read_manifest(name)
		assert_false(manifest.is_empty(), "%s is committed; generate it with %s" % [name, Store.regenerate_command(name)])
		assert_equal(Store.staleness(name, manifest), "", "%s is fresh" % name)
		assert_equal(PackedStringArray(manifest.get("roots", [])), Recipes.roots(), "%s: the recipe's roots" % name)


func test_the_walk_follows_preloads_and_data_literals() -> void:
	"""From the recipes the walk reaches the settlement, the save loader, the store and a data file."""
	var digests: Dictionary = Store.source_digests(Recipes.roots())
	for path: String in ["res://scripts/systems/settlement_system.gd", "res://scripts/core/settlement_save.gd",
			"res://test/fixtures/checkpoint_store.gd", "res://scripts/systems/game_manager.gd"]:
		assert_true(digests.has(path), "%s is in the fingerprint" % path)
	var data: int = 0
	for path: String in digests:
		if path.begins_with("res://data/"):
			data += 1
	assert_true(data > 0, "data files read by the simulation are in the fingerprint")
	assert_equal(digests[Recipes.SELF_PATH], FileAccess.get_sha256(Recipes.SELF_PATH), "each entry is the file's SHA-256")


func test_the_fingerprint_changes_with_any_file_the_engine_or_the_name() -> void:
	"""One changed digest, one more file or another name is another fingerprint; order is irrelevant."""
	var digests: Dictionary = {"res://a.gd": "11", "res://b.gd": "22"}
	var base: String = Store.fingerprint(NAME, digests)
	assert_equal(Store.fingerprint(NAME, {"res://b.gd": "22", "res://a.gd": "11"}), base, "order-free")
	assert_true(Store.fingerprint(NAME, {"res://a.gd": "11", "res://b.gd": "23"}) != base, "a changed file")
	assert_true(Store.fingerprint(NAME, {"res://a.gd": "11"}) != base, "a removed file")
	assert_true(Store.fingerprint("other", digests) != base, "another checkpoint")


func _scratch_write(bytes: PackedByteArray) -> Dictionary:
	"""Write a real, fresh scratch checkpoint of `bytes` at POINT; return its manifest."""
	assert_equal(Store.write(NAME, Recipes.roots(), {POINT: [9, bytes]}, SCRATCH), "", "the scratch writes")
	return Store.read_manifest(NAME, SCRATCH)


func _rewrite_manifest(manifest: Dictionary) -> void:
	"""Replace the scratch manifest."""
	var file: FileAccess = FileAccess.open("%s/%s.json" % [SCRATCH, NAME], FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()


func test_a_fresh_checkpoint_round_trips_its_exact_bytes() -> void:
	"""Written, then read: the same bytes and tick, from a gzip member smaller than them."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(100000)
	bytes[77] = 5
	_scratch_write(bytes)
	var loaded: Store.Loaded = Store.read_point(NAME, POINT, SCRATCH)
	assert_equal(loaded.error, "", "fresh and intact")
	assert_true(loaded.bytes == bytes, "the exact bytes")
	assert_equal(loaded.tick, 9, "its tick")
	assert_true(FileAccess.get_file_as_bytes("%s/%s-%s.rwlsave.gz" % [SCRATCH, NAME, POINT]).size() < 1000,
		"stored compressed")


func test_a_stale_checkpoint_is_refused_naming_the_changed_file_and_the_command() -> void:
	"""A recorded digest that differs from the source refuses; the refusal lists it and how to regenerate."""
	var manifest: Dictionary = _scratch_write(PackedByteArray([1, 2, 3]))
	manifest["sources"][Recipes.SELF_PATH] = "0".repeat(64)
	manifest["fingerprint"] = Store.fingerprint(NAME, manifest["sources"])
	_rewrite_manifest(manifest)
	var loaded: Store.Loaded = Store.read_point(NAME, POINT, SCRATCH)
	assert_true(loaded.error.contains("STALE"), "refused as stale: %s" % loaded.error)
	assert_true(loaded.error.contains(Recipes.SELF_PATH), "names the changed file")
	assert_true(loaded.error.contains(Store.regenerate_command(NAME)), "names the command")
	assert_true(loaded.bytes.is_empty(), "and hands back no bytes")


func test_a_missing_checkpoint_or_point_is_refused_with_the_command() -> void:
	"""No manifest, or no such point: refused, naming the generator."""
	var missing: Store.Loaded = Store.read_point(NAME, POINT, SCRATCH)
	assert_true(missing.error.contains("no checkpoint") and missing.error.contains(Store.REGENERATE), missing.error)
	_scratch_write(PackedByteArray([1]))
	var absent: Store.Loaded = Store.read_point(NAME, "t10", SCRATCH)
	assert_true(absent.error.contains("no point 't10'"), absent.error)


func test_a_damaged_checkpoint_file_is_refused() -> void:
	"""A gzip member whose content no longer has the recorded SHA-256 (or does not inflate) refuses."""
	_scratch_write(PackedByteArray([1, 2, 3, 4]))
	var other: PackedByteArray = PackedByteArray([1, 2, 3, 5]).compress(FileAccess.COMPRESSION_GZIP)
	var file: FileAccess = FileAccess.open("%s/%s-%s.rwlsave.gz" % [SCRATCH, NAME, POINT], FileAccess.WRITE)
	file.store_buffer(other)
	file.close()
	var loaded: Store.Loaded = Store.read_point(NAME, POINT, SCRATCH)
	assert_true(loaded.error.contains("damaged"), loaded.error)
	assert_true(loaded.bytes.is_empty(), "no bytes")


func test_a_rewrite_removes_points_the_recipe_no_longer_has() -> void:
	"""Regenerating with fewer points deletes the stale members."""
	assert_equal(Store.write(NAME, Recipes.roots(), {"a": [1, PackedByteArray([1])], "b": [2, PackedByteArray([2])]},
		SCRATCH), "", "two points")
	assert_equal(Store.write(NAME, Recipes.roots(), {"a": [1, PackedByteArray([1])]}, SCRATCH), "", "one point")
	assert_false(FileAccess.file_exists("%s/%s-b.rwlsave.gz" % [SCRATCH, NAME]), "b's member is gone")
	assert_true(FileAccess.file_exists("%s/%s-a.rwlsave.gz" % [SCRATCH, NAME]), "a's member stays")
