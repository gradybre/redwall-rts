extends "res://test/framework/test_case.gd"
## SLOW TIER (decision 1240): every committed test checkpoint is what replaying its recipe from tick
## 0 produces today, byte for byte, and loads back into a fresh settlement that saves identically.
##
## `checkpoint_store.gd` refuses a checkpoint whose source fingerprint changed; this suite is the
## proof behind the fingerprint, and it catches what the literal walk cannot see (a source path
## assembled at run time). It replays every recipe in full, which is why it runs at milestones and
## in CI rather than per commit (docs/ENVIRONMENT.md, "Test tiers").

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Recipes := preload("res://test/fixtures/checkpoint_recipes.gd")
const Store := preload("res://test/fixtures/checkpoint_store.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const SettlementSave := preload("res://scripts/core/settlement_save.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")


func after_each() -> void:
	"""Leave the autoload as the other suites expect it."""
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _assert_replay_matches(name: String) -> void:
	"""Replay recipe `name` from tick 0; every point's save must equal the committed file exactly."""
	var built: Recipes.Built = Recipes.build(name)
	assert_equal(built.error, "", "%s replays from tick 0" % name)
	var manifest: Dictionary = Store.read_manifest(name)
	var committed: Array = manifest.get("points", {}).keys()
	var replayed: Array = built.points.keys()
	committed.sort()
	replayed.sort()
	assert_equal(committed, replayed, "%s: the committed points are the replay's points" % name)
	for point: String in built.points:
		var loaded: Store.Loaded = Store.read_point(name, point)
		assert_true(loaded.is_ok(), loaded.error)
		assert_equal(loaded.tick, int(built.points[point][0]), "%s %s: the same tick" % [name, point])
		assert_true(loaded.bytes == built.points[point][1],
			"%s %s: the committed checkpoint is byte-identical to the replay from tick 0" % [name, point])


func _assert_loads_and_resaves(name: String, content: RefCounted) -> void:
	"""Each committed point loads into a fresh settlement through the real loader and saves the same."""
	for point: String in Store.read_manifest(name).get("points", {}):
		var target: Node = Settlement.new()
		assert_equal(Store.load_into(target, GameManager, name, point, content), "",
			"%s %s loads into a fresh settlement" % [name, point])
		var bytes: PackedByteArray = PackedByteArray()
		var refusal: SaveHeader.Refusal = SettlementSave.save_bytes(target, GameManager, bytes)
		assert_true(refusal.is_ok(), "%s %s: resave %s" % [name, point, refusal.code])
		assert_true(bytes == Store.read_point(name, point).bytes,
			"%s %s: the loaded world saves byte-identically" % [name, point])
		target.free()
		assert_true(AutoloadClockReset.release(), "the autoload is back at tick 0")


func test_the_underground_entry_checkpoint_equals_its_replay_and_reloads() -> void:
	"""underground_entry: replay the live chain, compare every point, load each with its content, resave."""
	_assert_replay_matches(Recipes.UNDERGROUND)
	_assert_loads_and_resaves(Recipes.UNDERGROUND, Recipes.underground_content())
