extends "res://test/framework/test_case.gd"
## The demo's boot prewarm (demo/demo_prewarm.gd, decision 0205): what would first load mid-game is
## loaded while the village opens, each step timed, and the clock is started only once WARM_FRAMES
## frames are drawn. Out of the tree: `_process` is called by hand.

const PrewarmScript := preload("res://demo/demo_prewarm.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const FarmAssetsScript := preload("res://demo/farm/farm_assets.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")


func test_every_step_runs_once_and_is_timed() -> void:
	"""warm() runs the registered steps in order, adds up what they loaded and reports each."""
	var prewarm := PrewarmScript.new()
	var ran: Array[String] = []
	prewarm.add_step("props", func() -> int:
		ran.append("props")
		return 5)
	prewarm.add_step("atlases", func() -> int:
		ran.append("atlases")
		return 3)
	assert_equal(prewarm.warm(), 8, "eight loaded")
	assert_equal(ran, ["props", "atlases"] as Array[String], "in order, once each")
	assert_equal(prewarm.report.size(), 2, "a row a step")
	assert_equal(String(prewarm.report[1]["step"]), "atlases", "named")
	assert_equal(int(prewarm.report[0]["loaded"]), 5, "what it loaded")
	var summed: int = 0
	for row: Dictionary in prewarm.report:
		summed += int(row["usec"])
	assert_equal(prewarm.total_usec(), summed, "the total is the steps' own times")
	prewarm.free()


func test_the_clock_is_released_after_the_warm_frames_once() -> void:
	"""The release waits for WARM_FRAMES frames to be DRAWN -- `_process` runs before its frame is
	drawn, so it fires in the process after the last warm one -- fires once, and never again."""
	var prewarm := PrewarmScript.new()
	var released: Array[int] = [0]
	prewarm.release_after_frames(func() -> void: released[0] += 1)
	assert_equal(PrewarmScript.WARM_FRAMES, 3, "three frames")
	for frame: int in PrewarmScript.WARM_FRAMES:
		prewarm._process(0.016)
	assert_equal(released[0], 0, "not before the third warm frame has been drawn")
	prewarm._process(0.016)
	assert_equal(released[0], 1, "released")
	assert_false(prewarm.is_processing(), "done counting")
	prewarm._fire()
	assert_equal(released[0], 1, "a second fire calls nothing")
	for frame: int in 10:
		prewarm._process(0.016)
	assert_equal(released[0], 1, "once")
	prewarm.release_after_frames(func() -> void: released[0] += 10, 0)
	assert_equal(released[0], 11, "no frames: at once")
	assert_equal(prewarm.process_mode, Node.PROCESS_MODE_ALWAYS, "it counts frames while the game is paused")
	prewarm.free()


func test_the_props_warm_every_staged_model_once() -> void:
	"""With nothing staged there is nothing to warm (a placeholder is made when asked, not warmed); a
	staged row is loaded by warm_all, and not again."""
	var props := PropsScript.new()
	props.load_from({})
	assert_equal(props.warm_all(), 0, "nothing staged")
	assert_equal(props.loaded_count(), 0, "nothing loaded")
	props._rows[&"basket"] = {"path": "res://demo/demo_village.tscn", "aabb_min": [0, 0, 0], "aabb_max": [1, 1, 1]}
	assert_equal(props.warm_all(), 1, "the staged row loaded")
	assert_equal(props.loaded_count(), 1, "one model")
	assert_equal(props.warm_all(), 0, "not twice")


func test_the_plant_atlases_warm_every_deferred_kind() -> void:
	"""ensure_all_loaded reads every plant kind still waiting (none unstaged), and a second call none."""
	var assets := FarmAssetsScript.new()
	assert_equal(assets.ensure_all_loaded(), 0, "none waiting")
	var kind: int = Catalog.VIS_PLANT_FIRST
	assets._deferred[kind] = {"texture": ""}
	assert_equal(assets.ensure_all_loaded(), 1, "the waiting kind read")
	assert_false(assets._deferred.has(kind), "and no longer waiting")
	assert_equal(assets.ensure_all_loaded(), 0, "none the second time")
