extends "res://test/live_harness_case.gd"
## The live demo's input, menu and keyboard on the REAL scene with REAL Viewport input (decision 0261;
## review F26, F29, F30, F50): runs test/live/demo_input_live.gd in its own headless process and asserts
## every check it prints. A separate process because this runner's worker runs every suite inside
## `_initialize`, before the root is in the tree -- there no Viewport can dispatch a click or a key. The
## harness boots demo/demo_village.tscn, on placeholders when the demo's assets are not staged. The runner is
## live_harness_case.gd's (decision 1921).


func test_the_real_scene_routes_input_menu_and_focus_at_1280x720() -> void:
	"""The Pantry, the menu, focus and the Lab, clicked and keyed on the real village at 1280x720."""
	_assert_run("1280x720")


func test_the_real_scene_routes_input_menu_focus_and_scale_at_1920x1080() -> void:
	"""The same at 1920x1080, where the harness also picks 150 %, restarts at it and shrinks the window."""
	_assert_run("1920x1080")


func test_room_blueprints_use_real_clicks_and_fit_at_1280x720() -> void:
	"""The live room review: held clicks, panel actions, explicit confirmation, refusal and Escape routing."""
	_assert_run("1280x720", "res://test/live/demo_room_blueprint_live.gd", 24)


func test_the_build_proof_of_concept_digs_a_painted_room_at_1280x720() -> void:
	"""Decision 1912: the entrance placed, a Passage and a Kitchen painted, Confirm all, the mole digs them, and a
	resident walks in -- through the real input gate on the real village; the rounded walls' rules (decision 1914);
	decision 2021's way cards, connector card, two more entrances dug and drawn, and a refused removal."""
	_assert_run("1280x720", "res://test/live/demo_build_dig_live.gd", 45)
