extends RefCounted
## The live demo's staged-asset manifest. Decision 0196.
##
## tools/stage_demo_assets.py copies the chosen library assets into the gitignored
## res://demo/assets/ and writes manifest.json there. The library lives outside git (decision
## 0188), so a fresh clone -- and CI -- has no manifest: `load_manifest()` then returns an empty
## one and every demo part must fall back to placeholder shapes rather than fail.
##
## Shape (all lengths in metres; library assets face +Z):
##   {"world": {key: {"category": "building"|"environment"|"prop", "path": res://..glb,
##                    "aabb_min": [x, y, z], "aabb_max": [x, y, z]}},
##    "cast":  {key: {"species", "height_m", "tailed", "body": res://..glb,
##                    "clips": {clip_name: res://..glb}, "walk_speed_m_s"}}}

const MANIFEST_PATH: String = "res://demo/assets/manifest.json"


static func load_manifest() -> Dictionary:
	"""The staged manifest, or {"world": {}, "cast": {}} when nothing is staged."""
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"world": {}, "cast": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("demo manifest at %s is not a JSON object; running on placeholders" % MANIFEST_PATH)
		return {"world": {}, "cast": {}}
	var manifest: Dictionary = parsed
	if not manifest.has("world"):
		manifest["world"] = {}
	if not manifest.has("cast"):
		manifest["cast"] = {}
	return manifest


static func is_staged(manifest: Dictionary) -> bool:
	"""Whether real assets were staged (otherwise the demo runs on placeholders)."""
	return not (manifest["world"] as Dictionary).is_empty() or not (manifest["cast"] as Dictionary).is_empty()
