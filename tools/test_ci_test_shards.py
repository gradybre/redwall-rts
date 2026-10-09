#!/usr/bin/env python3
"""Fault-test CI allocation/artifact guards; --godot also executes the inherited runner on fixtures."""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest

import ci_test_shards as shards

REPO = Path(__file__).resolve().parent.parent
WITH_GODOT = "--godot" in sys.argv
if WITH_GODOT:
    sys.argv.remove("--godot")


class ShardGuards(unittest.TestCase):
    def setUp(self) -> None:
        self.scratch = tempfile.TemporaryDirectory(prefix="redwall-ci-shard-test-")
        self.addCleanup(self.scratch.cleanup)
        self.repo = Path(self.scratch.name)
        self.tests = self.repo / "godot/test"
        self.tests.mkdir(parents=True)
        for name in ("test_a.gd", "test_b.gd", "test_c.gd", "test_d.gd"):
            (self.tests / name).write_text("fixture\n")
        self.absent_weights = self.repo / "no-weights.json"
        self.plan = shards.make_plan(2, self.repo, self.absent_weights)

    def test_discovers_every_new_direct_suite_but_not_framework_or_live_scripts(self) -> None:
        (self.tests / "live").mkdir()
        (self.tests / "live/test_nested.gd").write_text("fixture")
        (self.tests / "test_directory.gd").mkdir()
        (self.tests / "helper.gd").write_text("fixture")
        (self.tests / "test_new.gd").write_text("fixture")
        plan = shards.make_plan(2, self.repo, self.absent_weights)
        self.assertEqual(sorted(name for group in plan["shards"] for name in group),
                         ["test_a.gd", "test_b.gd", "test_c.gd", "test_d.gd", "test_new.gd"])

    def test_missing_duplicate_unknown_and_empty_assignments_are_refused(self) -> None:
        mutants = []
        missing = copy.deepcopy(self.plan)
        missing["shards"][0].pop()
        mutants.append(missing)
        duplicate = copy.deepcopy(self.plan)
        duplicate["shards"][0].append(duplicate["shards"][1][0])
        mutants.append(duplicate)
        unknown = copy.deepcopy(self.plan)
        unknown["shards"][0][0] = "test_unknown.gd"
        mutants.append(unknown)
        empty = copy.deepcopy(self.plan)
        empty["shards"][1] = []
        mutants.append(empty)
        for mutant in mutants:
            with self.subTest(mutant=mutant), self.assertRaises(shards.InvalidRun):
                shards.validate_plan(mutant, shards.discover(self.repo))

    def test_new_suite_invalidates_old_manifest(self) -> None:
        (self.tests / "test_new.gd").write_text("fixture")
        with self.assertRaises(shards.InvalidRun):
            shards.validate_plan(self.plan, shards.discover(self.repo))

    def test_partition_is_stable_and_separates_long_suites(self) -> None:
        weights = self.repo / "weights.json"
        shards.write_json(weights, {"suite_usec": {"test_a.gd": 1000, "test_b.gd": 900,
                                                  "test_c.gd": 100, "test_d.gd": 100}})
        plan = shards.make_plan(2, self.repo, weights)
        self.assertEqual(plan, shards.make_plan(2, self.repo, weights))
        self.assertNotEqual(next(i for i, group in enumerate(plan["shards"]) if "test_a.gd" in group),
                            next(i for i, group in enumerate(plan["shards"]) if "test_b.gd" in group))
        self.assertEqual(plan["estimated_usec"], [1100, 1000])

    def test_tiers_partition_the_corpus_and_default_to_all_fast(self) -> None:
        # Decision 1240: no slow_suites.json means everything is fast; with one, fast + slow == corpus, disjoint.
        self.assertEqual(shards.tier("fast", self.repo), shards.discover(self.repo))
        shards.write_json(self.repo / shards.SLOW_SUITES, {"slow": {"test_c.gd": 61, "test_a.gd": 300}})
        self.assertEqual(shards.tier("slow", self.repo), ["test_a.gd", "test_c.gd"])
        self.assertEqual(shards.tier("fast", self.repo), ["test_b.gd", "test_d.gd"])
        self.assertEqual(shards.make_plan(2, self.repo, self.absent_weights)["suites"], shards.discover(self.repo))

    def test_a_slow_tier_naming_a_missing_suite_or_unmeasured_fails_tier_and_plan(self) -> None:
        for slow in ({"test_gone.gd": 61}, {"test_a.gd": 0}, {"test_a.gd": "61"}, ["test_a.gd"]):
            shards.write_json(self.repo / shards.SLOW_SUITES, {"slow": slow})
            with self.subTest(slow=slow), self.assertRaises(shards.InvalidRun):
                shards.tier("fast", self.repo)
            with self.subTest(slow=slow, plan=True), self.assertRaises(shards.InvalidRun):
                shards.make_plan(2, self.repo, self.absent_weights)
        with self.assertRaises(shards.InvalidRun):
            shards.tier("medium", self.repo)

    def test_bad_indices_and_counts_fail(self) -> None:
        for spec in ("-1/2", "2/2", "0/0", "1", "x/2", "0/-2"):
            with self.subTest(spec=spec), self.assertRaises(shards.InvalidRun):
                shards.shard_spec(spec)
        for count in (0, 5):
            with self.subTest(count=count), self.assertRaises(shards.InvalidRun):
                shards.make_plan(count, self.repo, self.absent_weights)

    def log(self, names: list[str]) -> str:
        text = "".join(name + '\nCI_SUITE_TIME ' + json.dumps(
            {"suite": name, "usec": 10, "tests": 1, "assertions": 1, "failures": 0}) + "\n" for name in names)
        return (text + f"{len(names)} test(s), {len(names)} assertion(s), 0 failure(s)\n"
                "diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; "
                "leaked at exit: 0 object(s), 0 resource(s)\n"
                "log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).\n"
                f"ok: {len(names)} tests, {len(names)} assertions, 0 failures.\n")

    def artifacts(self) -> Path:
        output = self.repo / "artifacts"
        output.mkdir(exist_ok=True)
        for index, names in enumerate(self.plan["shards"]):
            shards.write_json(output / f"manifest-{index}.json", self.plan)
            log = self.log(names)
            (output / f"shard-{index}.log").write_text(log)
            counts, suites, timings = shards.parse_log(log)
            shards.write_json(output / f"shard-{index}.json", {
                "version": 1, "shard_index": index, "shard_count": 2,
                "manifest_sha256": shards.fingerprint(self.plan), "counts": counts,
                "suites": suites, "suite_usec": timings, "wall_seconds": 1,
                "suite_counts": shards.suite_counts_from_log(log),
            })
        return output

    def test_aggregate_matches_complete_baseline(self) -> None:
        baseline = self.repo / "baseline.log"
        baseline.write_text(self.log(shards.discover(self.repo)))
        result = shards.aggregate(self.artifacts(), 2, self.repo, baseline)
        self.assertTrue(result["baseline_matches"])
        self.assertEqual(result["counts"]["tests"], 4)

    def test_missing_result_and_extra_result_cannot_go_green(self) -> None:
        output = self.artifacts()
        (output / "shard-0.json").unlink()
        with self.assertRaisesRegex(shards.InvalidRun, "missing or extra"):
            shards.aggregate(output, 2, self.repo)
        self.artifacts()
        shutil.copyfile(output / "shard-0.json", output / "shard-9.json")
        with self.assertRaisesRegex(shards.InvalidRun, "missing or extra"):
            shards.aggregate(output, 2, self.repo)

    def test_changed_counts_or_file_lists_in_json_are_caught_by_raw_log(self) -> None:
        for field in ("counts", "suites", "manifest_sha256", "shard_index", "suite_usec"):
            output = self.artifacts()
            path = output / "shard-0.json"
            report = json.loads(path.read_text())
            if field == "counts":
                report[field]["assertions"] += 1
            elif field == "suites":
                report[field] = self.plan["shards"][1]
            elif field == "suite_usec":
                report[field].pop(next(iter(report[field])))
            else:
                report[field] = "wrong"
            shards.write_json(path, report)
            with self.subTest(field=field), self.assertRaises(shards.InvalidRun):
                shards.aggregate(output, 2, self.repo)

    def test_missing_or_duplicate_execution_is_refused_even_with_clean_counts(self) -> None:
        for replacement in ([], [self.plan["shards"][0][0]] * 2, self.plan["shards"][1]):
            output = self.artifacts()
            (output / "shard-0.log").write_text(self.log(replacement))
            with self.subTest(replacement=replacement), self.assertRaises(shards.InvalidRun):
                shards.aggregate(output, 2, self.repo)

    def test_raw_diagnostics_leaks_and_aborts_cannot_hide_behind_clean_summaries(self) -> None:
        clean = self.log(self.plan["shards"][0])
        for diagnostic in ("ERROR: hidden", "WARNING: hidden", "USER ERROR: hidden", "SCRIPT ERROR: abort",
                           "1 ObjectDB instances were leaked", "1 ObjectDB instance was leaked",
                           "1 resources still in use at exit"):
            with self.subTest(diagnostic=diagnostic), self.assertRaises(shards.InvalidRun):
                shards.parse_log(clean + diagnostic + "\n")

    def test_completed_suite_counters_must_sum_to_the_runner_totals(self) -> None:
        clean = self.log(self.plan["shards"][0])
        with self.assertRaisesRegex(shards.InvalidRun, "completed suite counters"):
            shards.parse_log(clean.replace('"assertions": 1', '"assertions": 2'))

    def test_missing_summary_success_guard_and_misclassified_diagnostics_fail(self) -> None:
        clean = self.log(self.plan["shards"][0])
        for mutant in (clean.replace("2 test(s)", "no summary"), clean.replace("ok:", "not ok:"),
                       clean + "EXPECTED WARNING: undeclared in summary\n", clean + "TOLERATED ERROR: missing in summary\n",
                       clean + "2 test(s), 2 assertion(s), 0 failure(s)\n"):
            with self.subTest(mutant=mutant), self.assertRaises(shards.InvalidRun):
                shards.parse_log(mutant)

    def test_baseline_assertions_and_diagnostic_totals_must_match(self) -> None:
        output = self.artifacts()
        baseline = self.repo / "baseline.log"
        log = self.log(shards.discover(self.repo))
        # The original full runner has no CI completion records.
        log = "\n".join(line for line in log.splitlines() if not line.startswith("CI_SUITE_TIME")) + "\n"
        baseline.write_text(log.replace("4 assertion(s)", "5 assertion(s)").replace("4 assertions", "5 assertions"))
        with self.assertRaisesRegex(shards.InvalidRun, "totals differ"):
            shards.aggregate(output, 2, self.repo, baseline)


@unittest.skipUnless(WITH_GODOT, "pass --godot to execute real runner and shell guards")
class RealRunner(unittest.TestCase):
    def setUp(self) -> None:
        self.scratch = tempfile.TemporaryDirectory(prefix="redwall-ci-shard-godot-")
        self.addCleanup(self.scratch.cleanup)
        self.repo = Path(self.scratch.name)
        (self.repo / "godot/test/framework").mkdir(parents=True)
        (self.repo / "tools").mkdir()
        (self.repo / "docs/validation").mkdir(parents=True)
        (self.repo / "godot/project.godot").write_text(
            f'config_version=5\n[application]\nconfig/name="CI shard fixture {os.getpid()}"\n')
        for name in ("ci_test_shards.py", "ci_test_shard_runner.gd", "run_tests.sh"):
            shutil.copy(REPO / "tools" / name, self.repo / "tools" / name)
        for name in ("run_tests.gd", "framework/test_case.gd"):
            shutil.copy(REPO / "godot/test" / name, self.repo / "godot/test" / name)
        (self.repo / "docs/validation/state_registry_coverage.py").write_text('print("fixture registry preflight")\n')
        self.output = self.repo / "artifacts"

    def suite(self, name: str, body: str) -> None:
        (self.repo / "godot/test" / name).write_text('extends "res://test/framework/test_case.gd"\n' + body)

    def run_shell(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", "tools/run_tests.sh", *args], cwd=self.repo,
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)

    def test_real_full_and_sharded_counts_and_diagnostics_match(self) -> None:
        self.suite("test_a.gd", '\nfunc test_expected() -> void:\n\texpect_diagnostic("fixture expected")\n'
                   '\tpush_error("fixture expected")\n\tassert_true(true, "ran")\n')
        self.suite("test_b.gd", '\nfunc test_tolerated() -> void:\n\ttolerate_diagnostic("fixture tolerated")\n'
                   '\tpush_warning("fixture tolerated")\n\tassert_true(true, "ran")\n')
        full = self.run_shell()
        self.assertEqual(full.returncode, 0, full.stdout)
        baseline = self.repo / "full.log"
        baseline.write_text(full.stdout)
        for index in range(2):
            run = self.run_shell("--shard", f"{index}/2", "--output-dir", str(self.output))
            self.assertEqual(run.returncode, 0, run.stdout)
        result = shards.aggregate(self.output, 2, self.repo, baseline)
        self.assertEqual(result["counts"]["expected"], 1)
        self.assertEqual(result["counts"]["tolerated"], 1)

    def test_real_unexpected_warning_abort_and_leak_fail_sharded_shell(self) -> None:
        cases = {
            "warning": '\nfunc test_bad() -> void:\n\tpush_warning("fixture undeclared")\n\tassert_true(true, "ran")\n',
            "abort": '\nfunc test_bad() -> void:\n\tassert_true(true, "ran")\n\tvar target: Object = null\n\ttarget.call("missing")\n',
            "leak": '\nclass Pair extends RefCounted:\n\tvar other: RefCounted\n\nfunc test_bad() -> void:\n'
                    '\tvar first := Pair.new()\n\tvar second := Pair.new()\n\tfirst.other = second\n\tsecond.other = first\n'
                    '\tassert_true(true, "ran")\n',
        }
        for label, body in cases.items():
            self.suite("test_bad.gd", body)
            run = self.run_shell("--shard", "0/1", "--output-dir", str(self.output / label))
            with self.subTest(label=label):
                self.assertNotEqual(run.returncode, 0, run.stdout)
                self.assertFalse((self.output / label / "shard-0.json").exists())
                self.assertTrue((self.output / label / "shard-0.log").exists())

    def test_one_leaked_object_is_counted_by_the_shard_runner_and_its_shell(self) -> None:
        # Decision 0998 (Brendan's P1): the engine's singular, "1 ObjectDB instance was leaked", is counted by the
        # shard runner (the runner's subclass) and by tools/run_tests.sh's own tally, not only failed as a warning.
        self.suite("test_bad.gd", '\nfunc test_bad() -> void:\n\tvar a := RefCounted.new()\n\ta.set_meta("me", a)\n'
                   '\tassert_true(true, "ran")\n')
        run = self.run_shell("--shard", "0/1", "--output-dir", str(self.output / "one"))
        self.assertNotEqual(run.returncode, 0, run.stdout)
        log = (self.output / "one" / "shard-0.log").read_text()
        self.assertIn("1 ObjectDB instance was leaked", log)
        self.assertRegex(log, r"(?m)^diagnostics: .*leaked at exit: 1 object\(s\), 0 resource\(s\)$")
        self.assertRegex(log, r"(?m)^log: .*leaked at exit: 1 object\(s\), 0 resource\(s\)\.$")

    def test_discovery_rejects_invalid_selection_in_the_actual_godot_worker(self) -> None:
        self.suite("test_ok.gd", '\nfunc test_ok() -> void:\n\tassert_true(true, "ran")\n')
        for selection in ([], ["test_ok.gd", "test_ok.gd"], ["test_absent.gd"], [123]):
            env = dict(os.environ, REDWALL_TEST_SHARD_SUITES=json.dumps(selection))
            result = subprocess.run(["godot", "--headless", "--path", str(self.repo / "godot"), "--script",
                                     str(self.repo / "tools/ci_test_shard_runner.gd")], env=env,
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
            with self.subTest(selection=selection):
                self.assertIn("CI shard", result.stdout)
                self.assertNotIn("  PASS ", result.stdout)
                self.assertIn("unexpected error(s)", result.stdout)

    def test_new_runner_has_zero_analyzer_warnings(self) -> None:
        # The project's existing analyzer only walks godot/. Check the tools/ subclass
        # in a disposable project too, without staging files in the real project.
        staged = self.repo / "godot/ci_test_shard_runner.gd"
        shutil.copyfile(REPO / "tools/ci_test_shard_runner.gd", staged)
        with socket.socket() as available:
            available.bind(("127.0.0.1", 0))
            port = available.getsockname()[1]
        result = subprocess.run([sys.executable, str(REPO / "tools/gdscript_warnings.py"),
                                 "--project", str(self.repo / "godot"), "--port", str(port),
                                 "--max", "0", str(staged)], text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
