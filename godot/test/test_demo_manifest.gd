extends "res://test/framework/test_case.gd"
## The live demo's manifest loader. Decision 0196. CI has no staged assets, and a developer
## machine may; both must yield a manifest the demo can run on.

const DemoManifestScript := preload("res://demo/demo_manifest.gd")


func test_the_manifest_always_has_both_halves() -> void:
	"""Staged or not, `world` and `cast` exist, so no demo part has to guard the keys."""
	var manifest: Dictionary = DemoManifestScript.load_manifest()
	assert_true(manifest.has("world") and manifest.has("cast"), "both halves present")
	assert_equal(DemoManifestScript.is_staged(manifest), not ((manifest["world"] as Dictionary).is_empty()
		and (manifest["cast"] as Dictionary).is_empty()), "is_staged agrees with the contents")


func test_an_empty_manifest_is_not_staged() -> void:
	"""The fresh-clone case: placeholders."""
	assert_false(DemoManifestScript.is_staged({"world": {}, "cast": {}}), "nothing staged")


func test_one_staged_half_counts() -> void:
	"""Staging only the cast (`--only cast`) is still a staged demo."""
	assert_true(DemoManifestScript.is_staged({"world": {}, "cast": {"mouse_keeper": {}}}), "cast only")
	assert_true(DemoManifestScript.is_staged({"world": {"hall": {}}, "cast": {}}), "world only")
