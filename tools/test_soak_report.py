#!/usr/bin/env python3
"""Tests for tools/soak_report.py and tools/soak_test.py's helpers (decision 0921), on hand-built runs.

    python3 tools/test_soak_report.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import soak_report  # noqa: E402
import soak_test  # noqa: E402

TH = soak_report.load_thresholds(soak_report.DEFAULT_THRESHOLDS)
COLUMNS = ["soak_hour", "static_kb", "objects", "nodes", "resources", "orphans"]


def day_record(day: int, p50: int, p95: int, cast_mean: int = 500, tiny_mean: int = 5) -> dict:
    """A day's record as the harness writes it (`frames_all` 18 000: twice the measured frames)."""
    stats = lambda v: {"n": 9000, "p50": v, "p95": v, "p99": v, "max": v, "mean": v}  # noqa: E731
    work = {"n": 9000, "p50": p50, "p95": p95, "p99": p95, "max": p95, "mean": p50}
    return {"day": day, "frames": 9000, "frames_all": 18000, "unix_start": 1000.0 + 100 * day,
            "unix_end": 1100.0 + 100 * day, "pauses_lifted": 1, "errors": 0,
            "columns": {"work_us": work, "sys.cast": stats(cast_mean), "sys.tiny": stats(tiny_mean)}}


def make_run(days: int = 10, objects_per_day: int = 0, static_per_day: int = 0, p50_per_day: int = 0,
             cpu_per_day: float = 0.0, cast_per_day: int = 0, tiny_per_day: int = 0) -> dict:
    """A run of `days` game days: hourly samples whose floors rise as asked, frames drifting as asked, and machine
    samples whose CPU per frame drifts as asked."""
    hours = []
    for h in range(days * 24 + 1):
        day = h // 24
        bump = 30 if h % 24 == 12 else 0  # a busy hour every day: the floor ignores it
        hours.append([h, 1_000_000 + static_per_day * day + bump, 13_500 + objects_per_day * day + bump, 3650, 1462, 1])
    run = {"meta": {"hours_asked": days * 24, "hours_run": days * 24, "residents_asked": 9},
           "hour_columns": COLUMNS, "hours": hours,
           "days": [day_record(d, 3000 + p50_per_day * d, 9000, 500 + cast_per_day * d, 5 + tiny_per_day * d)
                    for d in range(days)],
           "errors": {"errors": 0, "warnings": 0}, "restarts": []}
    samples, cpu = [[1000.0, 5.0, 5.0, 170_000, 0.0]], 0.0
    for d in range(days):
        cpu += 18000 * (3.0 + cpu_per_day * d) / 1000
        samples.append([1100.0 + 100 * d, 5.0, 5.0, 170_000, round(cpu, 3)])
    run["machine"] = {"samples": samples, "cpus": 18}
    return run


def kinds(verdict: dict) -> list[str]:
    """The flags' kind:metric."""
    return [f"{f['kind']}:{f['metric']}" for f in verdict["flags"]]


class SlopeTests(unittest.TestCase):
    def test_slope_and_rising(self):
        self.assertAlmostEqual(soak_report.slope([1, 3, 5, 7]), 2.0)
        self.assertEqual(soak_report.slope([4]), 0.0)
        self.assertAlmostEqual(soak_report.rising_share([1, 2, 2, 3, 1]), 0.5)
        self.assertEqual(soak_report.rising_share([]), 0.0)

    def test_floors_take_each_days_smallest_sample_of_complete_days(self):
        run = make_run(days=3, objects_per_day=10)
        self.assertEqual(soak_report.daily_floors(run, "objects"), [13_500, 13_510, 13_520])
        self.assertEqual(soak_report.daily_floors(run, "nope"), [])


class GrowthTests(unittest.TestCase):
    def test_a_flat_run_passes(self):
        verdict = soak_report.judge(make_run(), TH)
        self.assertEqual(verdict["verdict"], "pass", kinds(verdict))

    def test_steady_object_growth_is_flagged_with_its_reason(self):
        verdict = soak_report.judge(make_run(objects_per_day=80), TH)
        self.assertEqual(kinds(verdict), ["growth:objects"])
        self.assertIn("leak", verdict["flags"][0]["reason"])

    def test_growth_under_the_threshold_passes(self):
        self.assertEqual(soak_report.judge(make_run(objects_per_day=20, static_per_day=300), TH)["verdict"], "pass")

    def test_static_growth_is_flagged(self):
        self.assertEqual(kinds(soak_report.judge(make_run(static_per_day=900), TH)), ["growth:static_kb"])

    def test_a_rise_too_small_in_net_is_not_flagged(self):
        rule = {"per_day": 10, "min_rising": 0.0, "reason": "r"}
        out = soak_report.judge_growth("objects", [0, 0, 0, 200, 200, 200, 200, 5], rule, 0, 4)
        self.assertGreater(out["per_day"], 10, "the line rises over the threshold")
        self.assertFalse(out["flag"], "but the net change is 5, under a day's 10")

    def test_one_jump_is_not_monotonic_growth(self):
        rule = {"per_day": 50, "min_rising": 0.6, "reason": "r"}
        out = soak_report.judge_growth("objects", [100] * 8 + [900], rule, 1, 4)
        self.assertFalse(out["flag"], out)

    def test_too_few_days_are_not_judged(self):
        rule = {"per_day": 1, "min_rising": 0.0, "reason": "r"}
        out = soak_report.judge_growth("x", [1, 100, 200], rule, 1, 4)
        self.assertFalse(out["flag"])
        self.assertIn("kept days", out["note"])


class DriftTests(unittest.TestCase):
    def test_drift_in_wall_and_cpu_is_flagged(self):
        verdict = soak_report.judge(make_run(p50_per_day=120, cpu_per_day=0.12), TH)
        self.assertIn("drift:frame work p50", kinds(verdict))

    def test_drift_in_wall_time_only_is_load(self):
        verdict = soak_report.judge(make_run(p50_per_day=120, cpu_per_day=0.0), TH)
        self.assertNotIn("drift:frame work p50", kinds(verdict))
        p50 = next(d for d in verdict["drift"] if d["metric"] == "frame work p50")
        self.assertIn("load", p50["note"])

    def test_cpu_is_interpolated_between_samples(self):
        samples = [[0.0, 1, 1, 1, 0.0], [10.0, 1, 1, 1, 20.0]]
        self.assertAlmostEqual(soak_report.cpu_at(samples, 2.5), 5.0)
        self.assertIsNone(soak_report.cpu_at(samples, 11.0))

    def test_cpu_per_frame_from_the_machine_samples(self):
        machine = soak_report.machine_by_day(make_run(days=2))
        self.assertAlmostEqual(machine[0]["cpu_ms_per_frame"], 3.0, places=2, msg="divided by every frame")
        self.assertEqual(machine[1]["load1"], 5.0)

    def test_a_system_that_grows_is_flagged_and_a_tiny_one_is_not_judged(self):
        verdict = soak_report.judge(make_run(cast_per_day=40, tiny_per_day=1), TH)
        self.assertIn("system_drift:sys.cast", kinds(verdict))
        tiny = next(s for s in verdict["systems"] if s["metric"] == "sys.tiny")
        self.assertGreater(tiny["relative_per_day"], TH["systems"]["mean_relative_per_day"], "the tiny one drifts")
        self.assertFalse(tiny["flag"], "but is under min_mean_us")

    def test_a_system_that_jumps_once_is_not_drift(self):
        run = make_run()
        for day in run["days"][-2:]:
            day["columns"]["sys.cast"]["mean"] = 900
        self.assertNotIn("system_drift:sys.cast", kinds(soak_report.judge(run, TH)))

    def test_drift_without_cpu_readings_is_judged_on_wall_time(self):
        run = make_run(p50_per_day=120)
        run["machine"]["samples"] = []
        self.assertIn("drift:frame work p50", kinds(soak_report.judge(run, TH)))


class RestartAndErrorTests(unittest.TestCase):
    def restart(self, hour: int, unreachable: int, objects: int, held: int = 45, static_kb: int = 1_000_000) -> dict:
        """One restart's record as the harness writes it."""
        return {"soak_hour": hour, "leaks": {"watched": 4300, "unreachable": unreachable, "held": held,
                                             "unreachable_by_label": {"kitchen.gd": unreachable} if unreachable else {}},
                "before": {"objects": objects, "static_kb": static_kb},
                "after": {"objects": objects, "static_kb": static_kb}}

    def test_an_unreachable_survivor_is_a_leak(self):
        run = make_run()
        run["restarts"] = [self.restart(24, 0, 13_500), self.restart(48, 110, 13_500)]
        flags = soak_report.judge(run, TH)["flags"]
        self.assertEqual([f["kind"] for f in flags], ["restart_leak"])
        self.assertEqual(flags[0]["detail"], {"kitchen.gd": 110})

    def test_what_freeing_the_village_at_the_end_leaves_is_a_leak(self):
        run = make_run()
        run["exit"] = self.restart(240, 3, 13_500)
        flags = soak_report.judge(run, TH)["flags"]
        self.assertEqual([(f["kind"], f["metric"]) for f in flags], [("restart_leak", "freeing the village at the end")])

    def test_objects_growing_restart_after_restart(self):
        run = make_run()
        run["restarts"] = [self.restart(24 * k, 0, 13_500 + 4300 * k) for k in range(1, 5)]
        self.assertIn("restart_growth:objects after restart", kinds(soak_report.judge(run, TH)))

    def test_held_and_static_growing_restart_after_restart(self):
        run = make_run()
        run["restarts"] = [self.restart(24 * k, 0, 13_500, held=45 + k, static_kb=1_000_000 + 400 * k)
                           for k in range(1, 5)]
        found = kinds(soak_report.judge(run, TH))
        self.assertIn("restart_growth:held objects", found)
        self.assertIn("restart_growth:static KB after restart", found)

    def test_restart_noise_is_not_growth(self):
        run = make_run()
        run["restarts"] = [self.restart(24 * k, 0, 13_500 + (300 if k == 2 else 0)) for k in range(1, 6)]
        self.assertEqual(kinds(soak_report.judge(run, TH)), [], "one high restart, not a rise")

    def test_the_harness_failing_or_godot_exiting_non_zero_is_flagged(self):
        run = make_run()
        run["failures"] = ["orphans grew 3.0 a game day"]
        run["log"] = {"exit": 1, "errors": 5, "script_errors": 0}
        self.assertEqual(sorted(f["kind"] for f in soak_report.judge(run, TH)["flags"]),
                         ["errors", "exit", "harness_failure"])

    def test_errors_and_exit_leaks_are_flagged(self):
        run = make_run()
        run["errors"] = {"errors": 2, "first_errors": ["ERROR: x"]}
        run["log"] = {"script_errors": 0, "exit_leaks": ["ERROR: 41 resources still in use at exit"]}
        self.assertEqual(sorted(f["kind"] for f in soak_report.judge(run, TH)["flags"]), ["errors", "exit_leak"])

    def test_an_unfinished_run_is_flagged(self):
        run = make_run()
        run["meta"]["hours_run"] = 30
        run["failures"] = ["the village never opened"]
        self.assertIn("incomplete:hours run", kinds(soak_report.judge(run, TH)))


class OutputTests(unittest.TestCase):
    def test_write_gives_markdown_and_a_small_json(self):
        run = make_run(objects_per_day=80)
        with tempfile.TemporaryDirectory() as tmp:
            md, js = Path(tmp) / "r.md", Path(tmp) / "r.json"
            verdict = soak_report.write(run, TH, md, js)
            text = md.read_text()
            small = json.loads(js.read_text())
        self.assertEqual(verdict["verdict"], "flag")
        self.assertIn("**Verdict: FLAG**", text)
        self.assertIn("| objects |", text)
        self.assertEqual(small["verdict"], "flag")
        self.assertEqual(set(small), {"verdict", "flags", "meta", "growth", "drift"})

    def test_every_threshold_has_a_reason(self):
        for name, rule in TH["growth"].items():
            self.assertTrue(rule.get("reason"), name)
        for key in ("frame_drift", "systems", "errors"):
            self.assertTrue(TH[key].get("reason"), key)


class RunnerTests(unittest.TestCase):
    def test_the_exit_report_keeps_sounds_apart(self):
        lines = ["ERROR: 3 resources still in use at exit.", "ERROR: real trouble",
                 "Leaked instance: AudioStreamWAV:922 - Reference count: 1",
                 "Resource still in use: res://a.ogg (AudioStreamOggVorbis)",
                 "SCRIPT ERROR: oops"]
        out = soak_test.scan_lines(lines)
        self.assertEqual([out["errors"], out["script_errors"], out["exit_audio"], out["exit_leaks"]], [1, 1, 2, []])
        out = soak_test.scan_lines(lines + ["Leaked instance: kitchen_like:77 - Reference count: 1"])
        self.assertEqual(out["exit_leaks"], ["Leaked instance: kitchen_like:77 - Reference count: 1"])
        out = soak_test.scan_lines(["ERROR: 41 resources still in use at exit (run with --verbose for details)."])
        self.assertEqual(len(out["exit_leaks"]), 1, "not verbose: the summary is the report")

    def test_ps_cpu_time_parses(self):
        self.assertAlmostEqual(soak_test.cpu_seconds("0:17.33"), 17.33)
        self.assertAlmostEqual(soak_test.cpu_seconds("1:02:03"), 3723.0)
        self.assertAlmostEqual(soak_test.cpu_seconds("2-00:00:01"), 172801.0)


if __name__ == "__main__":
    unittest.main()
