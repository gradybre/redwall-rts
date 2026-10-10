extends "res://test/framework/test_case.gd"
## Actual pack-verifier checks, without starting a demo or granting World/renderer permission.

const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const RuntimeFiles := preload("res://data/underground/runtime_files.gd")
const DRIVER_PATH: String = "res://data/underground/mole-worker/mole_profile_driver.gd"
const STEP_PATH: String = "res://data/underground/mole-worker/work-step-v1/source_program.gd"
const TEMP: String = "user://test_demo_profile_pack.ugprof"
var _verifier: GDScript = null
var _changed_script: Script = null
var _original_source: String = ""


func before_each() -> void:
	"""Load the actual exported-pack checker by its repository tool path, retaining its real Script preloads."""
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/godot/verify_demo_pack.gd")
	_verifier = load(path) as GDScript


func after_each() -> void:
	"""Restore a deliberately stripped cached source before releasing every test-only reference."""
	if _changed_script != null:
		_changed_script.set_source_code(_original_source)
	_changed_script = null
	_original_source = ""
	_verifier = null
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(TEMP)


func _check(profile: String = Catalog.WIRE_PATH, actor: String = "") -> Dictionary:
	"""Call the public static verifier with its actual constants unless a negative path is supplied."""
	if actor.is_empty():
		return _verifier.call("profile_package", profile)
	return _verifier.call("profile_package", profile, actor)


func _write(bytes: PackedByteArray) -> void:
	"""Write one bounded negative binary fixture; never touch the production artifact."""
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_buffer(bytes)


func test_actual_profile_actor_and_cached_sources_pass_without_world_permission() -> void:
	"""The actual emitted artifacts and every published Script survive the check; no fake success flag is injected."""
	var report: Dictionary = _check()
	assert_equal(report.error, "", "same emitted artifacts and cached source")
	assert_equal(report.profiles.bytes, Catalog.WIRE_BYTES, "exact current published profile bytes")
	assert_equal(report.profiles.sha256, Catalog.Pins.WIRE_SHA, "exact profile digest")
	assert_equal(report.actor.bytes, 648760, "exact actor bytes")
	assert_equal(report.actor.sha256, Catalog.Pins.ACTOR_SHA, "exact actor digest")
	assert_equal(report.sources.count, Catalog.Pins.PATHS.size(), "complete current published consumer census")
	assert_true(report.sources.characters > 0, "nonempty cached source")
	assert_false(report.world_activation_qualified, "packaging grants no World activation")


func test_missing_or_wrong_size_artifacts_refuse() -> void:
	"""A missing exact path or positive but incomplete image never qualifies a demo pack."""
	assert_true(_check("user://absent_source_bound_profile.ugprof").error.contains("missing"), "missing wire refuses")
	_write(PackedByteArray([1, 2, 3]))
	assert_true(_check(TEMP).error.contains("byte count"), "truncated wire refuses")
	assert_true(_check(Catalog.WIRE_PATH, TEMP).error.contains("byte count"), "truncated actor refuses")
	assert_true(_check(Catalog.WIRE_PATH, "user://absent_actor.ugactor").error.contains("missing"), "missing actor refuses")


func test_changed_equal_size_profile_and_unbounded_size_refuse() -> void:
	"""Exact length does not replace the wire digest, and an oversized image refuses before streaming its body."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Catalog.WIRE_PATH)
	bytes[bytes.size() - 1] ^= 1
	_write(bytes)
	assert_true(_check(TEMP).error.contains("digest differs"), "equal length cannot hide changed bytes")
	bytes.resize(Catalog.WIRE_BYTES + 1)
	_write(bytes)
	var report: Dictionary = _check(TEMP)
	assert_true(report.error.contains("byte count"), "oversized image refuses")
	assert_equal(report.profiles.sha256, "", "refused size is never hashed")


func test_stripped_cached_script_refuses_even_with_same_identity() -> void:
	"""Reproduce mode2's empty actual cached text without changing the source files or recompiling a script."""
	_changed_script = ResourceLoader.load(DRIVER_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE) as Script
	_original_source = _changed_script.get_source_code()
	assert_true(_original_source.length() > 0, "real cached script has text")
	_changed_script.set_source_code("")
	assert_equal(_check().error, "MOLE_CATALOG_SOURCE_CAPACITY", "stripped source refuses")
	assert_true(ResourceLoader.load(DRIVER_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE) == _changed_script, "same actual cached Script identity")
	_changed_script.set_source_code(_original_source)
	assert_equal(_check().error, "", "restored source passes")


func test_changed_cached_source_refuses_and_restore_recovers() -> void:
	"""A matching disk file and cached object cannot hide changed source text in that running object."""
	_changed_script = ResourceLoader.load(DRIVER_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE) as Script
	_original_source = _changed_script.get_source_code()
	_changed_script.set_source_code(_original_source + "\n# altered cached source\n")
	assert_equal(_check().error, "MOLE_CATALOG_SOURCE_DRIFT", "changed cached text refuses")
	_changed_script.set_source_code(_original_source)
	assert_equal(_check().error, "", "restored source passes")


func test_short_step_consumer_is_retained_and_its_actual_cached_text_is_checked() -> void:
	"""The newly published tenth consumer must participate in the same real cached-source refusal gate."""
	assert_true(Catalog.Pins.PATHS.has(STEP_PATH), "published short-step consumer")
	_changed_script = ResourceLoader.load(STEP_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE) as Script
	_original_source = _changed_script.get_source_code()
	assert_true(_verifier.PROFILE_SCRIPTS.has(_changed_script), "actual export verifier retains step Script")
	_changed_script.set_source_code(_original_source + "\n# changed short-step cached source\n")
	assert_equal(_check().error, "MOLE_CATALOG_SOURCE_DRIFT", "step source mutation refuses")
	_changed_script.set_source_code(_original_source)
	assert_equal(_check().error, "", "restored exact step source passes")


func test_every_runtime_binary_passes_and_a_missing_or_changed_one_refuses() -> void:
	"""Decision 1841: the pack check reads every underground binary the game opens, at the reader's own pin."""
	var report: Dictionary = _verifier.call("runtime_files")
	assert_equal(report.error, "", "every listed binary on disk at its pinned digest")
	assert_equal(report.count, RuntimeFiles.FILES.size(), "the whole list is read")
	assert_equal(report.refused.size(), 0, "none refused")
	var absent: Dictionary = _verifier.call("runtime_files", {"user://absent_runtime_file.ugactor": "0".repeat(64)})
	assert_true(absent.error.contains("missing"), "a missing binary refuses")
	assert_equal(absent.refused, PackedStringArray(["user://absent_runtime_file.ugactor"]), "and is named")
	_write(PackedByteArray([1, 2, 3]))
	var changed: Dictionary = _verifier.call("runtime_files", {TEMP: "0".repeat(64)})
	assert_true(changed.error.contains("digest differs"), "changed bytes refuse")
	var oversized: PackedByteArray = PackedByteArray()
	oversized.resize(_verifier.RUNTIME_FILE_MAX_BYTES + 1)
	_write(oversized)
	var large: Dictionary = _verifier.call("runtime_files", {TEMP: FileAccess.get_sha256(TEMP)})
	assert_true(large.error.contains("byte count"), "an oversized binary refuses before it is streamed")
