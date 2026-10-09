extends "bake_underground_matrices.gd"
## ADR 1216: the curled pick paw's bake, successor to bake_mole_grip_content.gd. The same source-bound mole and pick,
## with the curled derivative (mole_grip_curl_source.gd) and its lateral-2 fit in place of the closed paw's.

const Curl := preload("res://data/underground/mole-worker/mole_grip_curl_source.gd")
const Accepted := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const CURL_SOURCE: String = "res://data/underground/mole-worker/mole_grip_curl_source.gd"
const RECIPE: String = "mole_curl_v1"
var _curl_fit: Transform3D = Transform3D.IDENTITY


func _case_error(request: Variant, pins: Dictionary, ids: Dictionary) -> String:
	"""Only the explicitly authored adult mole/pick source and the curled derivative's identity enter this bake."""
	var code: String = super._case_error(request, pins, ids)
	if code != "":
		return code
	if request.cast != "mole_digger" or request.species != "mole" \
			or request.life_stage != "adult_presentation_candidate" or request.attachments != ["mole_pick"] \
			or request.get("grip_recipe") != RECIPE or request.get("source_mesh_sha256") != Accepted.SOURCE_DIGEST \
			or request.get("derived_mesh_sha256") != Curl.DERIVED_DIGEST:
		return "MOLE_CURL_CASE_IDENTITY"
	return ""


func _implementation_error(pins: Dictionary) -> String:
	"""Close the curled derivative's literal source dependencies, in addition to the inherited closure."""
	var code: String = super._implementation_error(pins)
	if code != "":
		return code
	var pending: Array[String] = [CURL_SOURCE]
	var seen: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("(?:preload|load)\\(\\s*\"(res://[^\"]+\\.gd)\"\\s*\\)")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		if seen.size() >= MAX_SOURCES or not pins.has(path):
			return "MOLE_CURL_IMPLEMENTATION_UNPINNED"
		seen[path] = true
		for item: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			pending.append(item.get_string(1))
	return ""


func _start_case() -> void:
	"""Replace the instance's fixed source mesh with the curled paw before any inherited cache or pose capture."""
	_curl_fit = Transform3D.IDENTITY
	super._start_case()
	if _finished or _actor == null:
		return
	var nodes: Array[Node] = _actor.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	if nodes.size() != 1:
		_error = "MOLE_CURL_BODY_CENSUS"
		_finish()
		return
	if _tunnel_ext == null:
		_tunnel_ext = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
	var instance: MeshInstance3D = nodes[0] as MeshInstance3D
	var fit: Transform3D = _tunnel_ext.call("pick_fit", _props)
	var result: Curl.Result = Curl.create(instance.mesh as ArrayMesh, instance.skin, _skeleton, fit)
	if result.error != &"":
		_error = String(result.error)
		_finish()
		return
	instance.mesh = result.mesh
	_curl_fit = result.fit


func _attachment_data(key: String) -> Dictionary:
	"""The same original pick, held by the lateral-2 fit; geometry is neither hidden nor shortened."""
	var data: Dictionary = super._attachment_data(key)
	if not data.has("error") and key == "mole_pick":
		data.fit = _curl_fit
	return data


func _presentation_metadata(path: String) -> Dictionary:
	"""Bind both sides of the authored change to the binary and its source closure."""
	var metadata: Dictionary = super._presentation_metadata(path)
	metadata["grip_recipe"] = {"id": RECIPE, "source": CURL_SOURCE,
		"source_sha256": FileAccess.get_sha256(CURL_SOURCE), "original_mesh_sha256": Accepted.SOURCE_DIGEST,
		"derived_mesh_sha256": Curl.DERIVED_DIGEST, "original_hand_sha256": Accepted.HAND_DIGEST,
		"original_fit_sha256": Accepted.FIT_DIGEST, "changed_vertices": Curl.CHANGED_VERTICES,
		"production_qualified": false}
	return metadata
