extends "res://test/framework/test_case.gd"
## The scale test (decision 0561): the stress cast's rows and names, the in-code probe, the harness's system map and
## statistics -- and the real demo village booted headless with 25 residents for a short run (1x, a group order, 4x
## through the breakfast call), in its own process, asserting it finished with no error and its invariants held: every
## resident accounted for and the kitchen's food books balanced (tools/scale_test/scale_checks.gd). On placeholders
## when the demo's assets are not staged. Its exit report must be empty (decision 0998), and a fault-injected run that
## retains one extra resource must fail that check.

const StressCast := preload("res://demo/stress/stress_cast.gd")
const ProbeScript := preload("res://demo/stress/scale_probe.gd")
const DriverScript := preload("res://tools/scale_test/scale_driver.gd")
const RecordScript := preload("res://tools/scale_test/scale_record.gd")
const ReportScript := preload("res://tools/scale_test/scale_report.gd")
const DeskScript := preload("res://demo/cast/route_desk.gd")
const ChecksScript := preload("res://tools/scale_test/scale_checks.gd")
const KitchenRules := preload("res://demo/kitchen/meal_rules.gd")

const HARNESS: String = "res://tools/scale_test/scale_test.gd"
## FAULT INJECTION (decision 0998): the same harness, a tiny plan, one extra resource retained at exit.
const LEAK_FIXTURE: String = "res://test/fixtures/scale_exit_leak_fixture.gd"
const RESIDENTS: int = 25
## THE EXIT REPORT (decision 0998). The engine's report, as the process quits, of resources still cached and objects
## never freed. NOTHING OF IT IS TOLERATED: the harness frees the village before it quits (scale_test.gd "THE END FREES
## THE VILLAGE FIRST"), and its exit report is then empty.
## (Decision 0561 tolerated one such line of any count, for a kitchen cycle decision 0922 has since broken; what still
## printed it was the sounds playing as the harness quit with the village in the tree.) The counts are read to name a
## finding, never to allow one, and a real run's report lines are passed on to the outer runner as printed, so they
## count there as unexpected diagnostics and in its leak counts (and in tools/run_tests.sh's raw-log gate). The patterns
## are run_tests.gd's, widened for the engine's singular: one leaked object is reported as "1 ObjectDB instance was
## leaked at exit", which the outer leak count misses (its unexpected-warning count still fails it; decision 0998).
const EXIT_RESOURCES_PATTERN: String = "(\\d+) resources? still in use at exit"
const EXIT_OBJECTS_PATTERN: String = "(\\d+) ObjectDB instances? (?:were|was) leaked at exit"

## The kitchen's books, as scale_checks.gd reads them (duck-typed: `get` and `call`).
class StubStore extends RefCounted:
	var held: int = 0
	var spoiled_portions: int = 0

	func portions() -> int:
		"""Portions held."""
		return held


class StubPantry extends RefCounted:
	var low: int = 0

	func milli_of(item: int) -> int:
		"""Item 3 holds `low`; the rest nothing."""
		return low if item == 3 else 0


class StubKitchen extends RefCounted:
	var store: StubStore = StubStore.new()
	var pantry: StubPantry = StubPantry.new()
	var batches_cooked: int = 0
	var portions_eaten: int = 0
	var cooked_dishes: PackedInt32Array = PackedInt32Array()
	var cancelled_spoil_milli: int = 0
	var consumed_food_milli: int = 0

	func wip_dish() -> int:
		"""Nothing cooking."""
		return KitchenRules.NO_DISH


func after_each() -> void:
	"""No request left behind for the next suite."""
	StressCast.override_count = -1


func _cast_rows(count: int) -> Dictionary:
	"""A staged-looking cast of `count` rows, keyed like the demo's."""
	var cast: Dictionary = {}
	for k: int in count:
		cast["kind_%d" % k] = {"species": "kind", "body": "res://none_%d.glb" % k}
	return cast


func test_expand_keeps_the_originals_first_and_clones_by_index() -> void:
	"""Seven from three: the three originals unchanged, then clones of row i mod 3 with their own keys and names."""
	var cast: Dictionary = _cast_rows(3)
	var out: Dictionary = StressCast.expand(cast, 7)
	var keys: Array = out.keys()
	assert_equal(keys.size(), 7, "seven rows")
	assert_equal(keys.slice(0, 3), ["kind_0", "kind_1", "kind_2"], "the originals first, in order")
	assert_equal(String(keys[3]), "kind_0__t003", "a clone's key names its row and index")
	assert_equal(StressCast.creature_key_of(StringName(keys[4]), out[keys[4]]), &"kind_1", "clone 4 is row 1's kind")
	assert_equal(StressCast.creature_key_of(&"kind_2", out["kind_2"]), &"kind_2", "an original keeps its key")
	assert_true(bool(out[keys[5]][StressCast.ROW_TEST]), "a clone is marked demo-test")
	assert_false((cast["kind_0"] as Dictionary).has(StressCast.ROW_BASE), "the manifest's own rows are not written")


func test_expand_off_cut_and_capped() -> void:
	"""0 asks for nothing (the same cast back); fewer than staged cuts; past the population cap is capped."""
	var cast: Dictionary = _cast_rows(9)
	assert_true(is_same(StressCast.expand(cast, 0), cast), "0: the cast itself")
	assert_equal(StressCast.expand(cast, 4).size(), 4, "4 of 9: the first four")
	assert_equal(StressCast.expand(cast, 999).size(), StressCast.MAX_RESIDENTS, "never past 256")
	assert_true(StressCast.expand({}, 25).is_empty(), "nothing staged: nothing to grow (placeholders instead)")


func test_requested_count_and_placeholders() -> void:
	"""A script's request wins and is capped; unstaged, the placeholders follow it; off, the default stands."""
	StressCast.override_count = 0
	assert_false(StressCast.is_active(), "0: off")
	assert_equal(StressCast.placeholder_count(6), 6, "off: the default six placeholders")
	StressCast.override_count = 300
	assert_equal(StressCast.requested_count(), StressCast.MAX_RESIDENTS, "capped at 256")
	StressCast.override_count = 25
	assert_true(StressCast.is_active(), "25: on")
	assert_equal(StressCast.placeholder_count(6), 25, "on: 25 placeholders")


func test_generated_names_are_distinct_up_to_the_cap() -> void:
	"""Every index to 256 gets its own two-word name from the data file; no lists falls back to a numbered label."""
	var names: Dictionary = StressCast._load_names()
	var seen: Dictionary = {}
	for k: int in StressCast.MAX_RESIDENTS:
		seen[StressCast.name_for(k, names)] = true
	assert_equal(seen.size(), StressCast.MAX_RESIDENTS, "256 distinct names")
	assert_equal(StressCast.name_for(12, names).split(" ").size(), 2, "first name and surname")
	assert_equal(StressCast.name_for(3, {}), "Test resident 3", "no lists: a numbered label")
	assert_equal(StressCast.display_name_of({StressCast.ROW_NAME: "Abbet Ashby"}, "Wenna"), "Abbet Ashby", "a clone's")
	assert_equal(StressCast.display_name_of({}, "Wenna"), "Wenna", "an original's own")


func test_the_probe_sums_sections_and_clears() -> void:
	"""Sections add up within a frame, read 0 unseen, and clear to 0 with their names kept."""
	var probe := ProbeScript.new()
	probe.add(&"a", 5)
	probe.add(&"b", 2)
	probe.add(&"a", 7)
	assert_equal([probe.usec_of(&"a"), probe.usec_of(&"b"), probe.usec_of(&"c")], [12, 2, 0], "summed per section")
	probe.clear()
	var names: Array[StringName] = probe.sections()
	assert_equal([probe.usec_of(&"a"), names.size(), names[0], names[1]], [0, 2, &"a", &"b"], "cleared, names kept")


func test_scripts_are_booked_to_their_systems() -> void:
	"""The more specific path wins (the work screen is UI, the board is the board); an unknown path is other."""
	assert_equal(DriverScript.system_of("res://demo/cast/demo_cast.gd"), &"cast", "the cast")
	assert_equal(DriverScript.system_of("res://demo/work/work_screen.gd"), &"ui", "the Work screen is UI")
	assert_equal(DriverScript.system_of("res://demo/work/demo_work.gd"), &"work_board", "the board")
	assert_equal(DriverScript.system_of("res://demo/tunnel/tunnel_ext.gd"), &"tunnels_and_night", "the night's owner")
	assert_equal(DriverScript.system_of("res://somewhere/else.gd"), &"other", "unknown")


func test_the_record_keeps_rows_and_ranks_percentiles() -> void:
	"""Rows keep their columns; nearest-rank percentiles over a filter; empty is all zeros."""
	var record := RecordScript.new()
	record.define(PackedStringArray(["x", "y"]))
	for k: int in 100:
		record.set_value(record.column("x"), k + 1)
		record.set_value(record.column("y"), k % 2)
		record.commit()
	assert_equal([record.row_count(), record.value(9, 0), record.column("nope")], [100, 10, -1], "rows and columns")
	var all: Dictionary = record.stats(0, func(_row: int) -> bool: return true)
	assert_equal([all["p50"], all["p95"], all["p99"], all["max"], all["mean"]], [50, 95, 99, 100, 50], "percentiles")
	var odd: Dictionary = record.stats(0, func(row: int) -> bool: return record.value(row, 1) == 1)
	assert_equal([odd["n"], odd["max"]], [50, 100], "a filter")
	assert_equal(RecordScript.summary(PackedInt64Array())["p95"], 0, "empty")


func test_the_desk_tallies_plans_per_resident_only_when_asked() -> void:
	"""Off by default nothing is counted; on, each resident's plans and their time add up; a formation's (-1) is not
	a resident's."""
	var desk := DeskScript.new()
	desk.charge(2, 500)
	assert_equal(desk.plans_of.size(), 0, "off: nothing counted")
	desk.tally = true
	desk.charge(2, 500)
	desk.charge(2, 300)
	desk.charge(0, 100)
	desk.charge(-1, 999)
	assert_equal([desk.plans_of[0], desk.plans_of[2], desk.plan_usec_of[2], desk.plan_usec_of[0]], [1, 2, 800, 100],
		"two plans of resident 2 (800 us), one of resident 0; the formation's not counted")


func test_a_phase_keeps_only_the_frames_run_at_its_speed() -> void:
	"""A phase's statistics keep its frames the village ran at its own speed; a frame stepped down to 2x is left out
	(and counted in its speeds)."""
	var record := RecordScript.new()
	record.define(PackedStringArray(["phase", "speed", "tick", "frame_us", "harness_us", "scripts_us", "x"]))
	for row: Array in [[0, 4, 10, 1000], [0, 4, 11, 2000], [0, 2, 12, 9000], [1, 1, 13, 500]]:
		for k: int in 4:
			record.set_value(k if k < 3 else record.column("frame_us"), int(row[k]))
		record.commit()
	var work: PackedInt64Array = ReportScript._work_column(record)
	var keep: Callable = func(row: int) -> bool: return record.value(row, 0) == 0 and record.value(row, 1) == 4
	var section: Dictionary = ReportScript._section(record, work, keep, PackedInt64Array())
	assert_equal([section["frames"], section["work_us"]["max"]], [2, 2000], "the 2x frame is not in phase 0's 4x")
	var speeds: Array = ReportScript._phase_speeds(record, 2)
	assert_equal([(speeds[0] as Dictionary).get("4"), (speeds[0] as Dictionary).get("2")], [2, 1], "but counted")


func test_the_kitchen_books_check_finds_each_imbalance() -> void:
	"""Balanced books pass; a portion unaccounted for, food taken past the recipes and a pantry item below zero are
	each named."""
	var checks := ChecksScript.new()
	var kitchen := StubKitchen.new()
	kitchen.batches_cooked = 2
	kitchen.store.held = 1
	kitchen.portions_eaten = 2
	kitchen.store.spoiled_portions = 1
	kitchen.cooked_dishes = PackedInt32Array([0, 1])
	kitchen.consumed_food_milli = KitchenRules.INPUT_MILLI[0] + KitchenRules.INPUT_MILLI[1]
	var out := PackedStringArray()
	checks._books_of(kitchen, out)
	assert_equal(out.size(), 0, "balanced: %s" % out)
	kitchen.portions_eaten = 1
	kitchen.consumed_food_milli += 1
	kitchen.pantry.low = -5
	checks._books_of(kitchen, out)
	assert_equal(out.size(), 3, "each imbalance named: %s" % out)


func test_twenty_five_residents_run_headless_with_their_invariants() -> void:
	"""The real village, 25 residents, the short plan: it finishes, nothing errors, every invariant holds, and nothing
	is left at exit (see THE EXIT REPORT)."""
	var run: Dictionary = _run_harness(HARNESS, PackedStringArray(["--plan", "short"]))
	var lines: PackedStringArray = run["lines"]
	var report: Dictionary = exit_report(lines)
	for line: String in report["lines"]:
		printerr(line)
	for line: String in _errors_in(lines):
		fail("the stress run printed: %s" % line)
	var parts: PackedStringArray = _done_line(lines).split(" ")
	assert_true(parts.size() > 3, "the run finished (SCALE-DONE printed)")
	assert_equal(parts[1] if parts.size() > 3 else "", str(RESIDENTS), "with 25 residents")
	assert_true(parts.size() > 3 and parts[2].to_int() > 600, "and ran its frames: %s" % " ".join(parts))
	assert_equal(parts[3] if parts.size() > 3 else "", "0", "no invariant failed")
	assert_equal(exit_report_findings(report), PackedStringArray(), "nothing left at exit: %s" % report["lines"])
	assert_equal(_close_held(lines), 0, "the close let go of every sound (scale_test.gd, THE END)")
	assert_equal(run["code"], 0, "exit 0")


func test_one_extra_retained_resource_fails_the_exit_check() -> void:
	"""FAULT INJECTION: the same harness and end, a tiny plan, and one resource retained at exit (the fixture). The run
	itself is clean, the engine counts exactly that one resource and its one object, and the check fails both."""
	var run: Dictionary = _run_harness(LEAK_FIXTURE, PackedStringArray())
	var lines: PackedStringArray = run["lines"]
	var report: Dictionary = exit_report(lines)
	assert_equal(_errors_in(lines), PackedStringArray(), "the injected run printed no other error")
	assert_true(_done_line(lines).ends_with(" 0"), "it finished, no invariant failed: %s" % _done_line(lines))
	assert_equal(_close_held(lines), 0, "the close let go of every sound, so the one resource is the injected one")
	assert_equal([report["resources"], report["objects"]], [1, 1], "exactly the injected one: %s" % report["lines"])
	assert_equal(exit_report_findings(report).size(), 2, "the check fails it: %s" % exit_report_findings(report))
	assert_equal(run["code"], 0, "exit 0: only the exit report tells")


func test_the_exit_check_allows_no_count() -> void:
	"""One resource and a thousand are both findings, an object leak is one too (the engine's singular included), and
	their counts add up; a log with no exit report has none (see THE EXIT REPORT)."""
	var one: Dictionary = exit_report(PackedStringArray(["SCALE-DONE 25 725 0",
		"ERROR: 1 resources still in use at exit (run with --verbose for details).",
		"   at: clear (core/io/resource.cpp:822)"]))
	assert_equal([one["resources"], one["objects"], exit_report_findings(one).size()], [1, 0, 1], "one resource")
	var single: Dictionary = exit_report(PackedStringArray([
		"WARNING: 1 ObjectDB instance was leaked at exit (run with `--verbose` for details)."]))
	assert_equal([single["resources"], single["objects"], exit_report_findings(single).size()], [0, 1, 1], "one object")
	var many: Dictionary = exit_report(PackedStringArray([
		"ERROR: 1000 resources still in use at exit (run with --verbose for details).",
		"WARNING: 6 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
		"ERROR: 2 resources still in use at exit"]))
	assert_equal([many["resources"], many["objects"]], [1002, 6], "counts add up")
	assert_equal(exit_report_findings(many).size(), 2, "resources and objects, each a finding")
	assert_equal((many["lines"] as PackedStringArray).size(), 3, "every report line kept, to pass on")
	var clean: Dictionary = exit_report(PackedStringArray(["SCALE-DONE 25 725 0", "ERROR: something else"]))
	assert_equal([clean["resources"], clean["objects"], exit_report_findings(clean)], [0, 0, PackedStringArray()],
		"no exit report: no finding (other errors are _errors_in's)")


func _run_harness(script: String, user_args: PackedStringArray) -> Dictionary:
	"""Run `script` headless at the fixed 60 Hz step with RESIDENTS residents (and `user_args`): its exit code and its
	merged output's lines."""
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--script", script, "--", "--residents", str(RESIDENTS)]
	args.append_array(user_args)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	return {"code": code, "lines": ("".join(PackedStringArray(output))).split("\n")}


func _done_line(lines: PackedStringArray) -> String:
	"""The run's `SCALE-DONE <residents> <frames> <errors>` line ("" when it never finished)."""
	for line: String in lines:
		if line.begins_with("SCALE-DONE "):
			return line.strip_edges()
	return ""


func _close_held(lines: PackedStringArray) -> int:
	"""The sounds still held as the harness quit, from its `SCALE close <playing> <held> <frames> <ms>` line (-1: no
	such line, so the run did not close as scale_test.gd's THE END FREES THE VILLAGE FIRST says)."""
	for line: String in lines:
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() == 6 and parts[0] == "SCALE" and parts[1] == "close":
			return parts[3].to_int()
	return -1


func _errors_in(lines: PackedStringArray) -> PackedStringArray:
	"""Every script error, engine error and harness error the run printed, the exit report apart (`exit_report`)."""
	var report: PackedStringArray = exit_report(lines)["lines"]
	var out := PackedStringArray()
	for line: String in lines:
		var text: String = line.strip_edges()
		if report.has(text):
			continue
		if text.contains("SCRIPT ERROR") or text.begins_with("ERROR:") or text.begins_with("SCALE-ERROR"):
			out.append(text)
	return out


static func exit_report(lines: PackedStringArray) -> Dictionary:
	"""The engine's exit report in `lines` (see THE EXIT REPORT): the resources and objects it counted, and its lines
	as printed."""
	var resources_re: RegEx = RegEx.create_from_string(EXIT_RESOURCES_PATTERN)
	var objects_re: RegEx = RegEx.create_from_string(EXIT_OBJECTS_PATTERN)
	var resources: int = 0
	var objects: int = 0
	var report := PackedStringArray()
	for line: String in lines:
		var text: String = line.strip_edges()
		var resource_match: RegExMatch = resources_re.search(text)
		var object_match: RegExMatch = objects_re.search(text)
		if resource_match != null:
			resources += int(resource_match.get_string(1))
		if object_match != null:
			objects += int(object_match.get_string(1))
		if resource_match != null or object_match != null:
			report.append(text)
	return {"resources": resources, "objects": objects, "lines": report}


static func exit_report_findings(report: Dictionary) -> PackedStringArray:
	"""Each thing the exit report says was left behind; empty only for a clean exit. No count is allowed."""
	var out := PackedStringArray()
	if int(report["resources"]) > 0:
		out.append("%d resource(s) still in use at exit" % int(report["resources"]))
	if int(report["objects"]) > 0:
		out.append("%d object(s) leaked at exit" % int(report["objects"]))
	return out
