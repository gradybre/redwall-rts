#!/usr/bin/env python3
"""Self-test for balance_report.py (decision 0571): its definitions and flags on hand-built runs.

    python3 tools/test_balance_report.py

Each flag is driven both ways -- a run that should raise it and one that should not -- because a report whose flags
never fire looks exactly like a village with nothing wrong. The opening (the demo starts with an empty pantry) must
not read as food running out; spoilage is over the food AVAILABLE in a season (its opening stock too); idle is over
idle plus work only.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import balance_report as report  # noqa: E402

THRESHOLDS = report.load_thresholds(str(Path(__file__).with_name("balance_thresholds.json")))


def make_day(day: int, *, reserve: int = 3000, produced: int = 0, spoiled: int = 0, stock: int = 10000,
             without: int = 0, hungry: int = 0, work: int = 600, idle: int = 300, fish: int = 0,
             reserve_end: int | None = None, cancelled: int = 0) -> dict:
    """A day record shaped like year_runner.gd's, with every field the report reads."""
    items = {"carrot": produced} if produced else {}
    if fish:
        items["trout"] = fish
    zero_mats = {"in": 0, "out": 0, "end": 0}
    return {
        "day": day, "year": day // 48, "season": (day // 12) % 4, "season_day": day % 12 + 1, "partial": False,
        "items": {"produced": items, "withdrawn": {}, "spoiled": {"carrot": spoiled} if spoiled else {}},
        "kitchen": {"cancelled_spoil_milli": cancelled, "table_spoiled_portions": 0, "portions_eaten": 18,
                    "cooked_milli": 18000, "raw_eaten_milli": 0},
        "stock": {"total_milli": stock, "items": {}},
        "reserve_days_milli_min": reserve, "reserve_days_milli_end": reserve if reserve_end is None else reserve_end,
        "meals": {"ate": 18 - without, "raw": 0, "without": without},
        "fed_resident_hours": {"fed": 216 - hungry, "peckish": 0, "hungry": hungry},
        "labour_ticks": {"work": work, "idle": idle, "meal": 0, "rest": 0, "other": 0},
        "labour_ticks_by_resident": [{"work": work, "idle": idle, "meal": 0, "rest": 0, "other": 0}],
        "board": {"queue_task_ticks": 30, "queue_ticks": 60, "queue_max": 2, "claimed": 2, "dropped": 0,
                  "wait_ticks_sum": 25, "wait_ticks_max": 20},
        "materials": {m: dict(zero_mats) for m in ("wood", "planks", "stone", "earth", "water")},
        "weather": {"event": "", "frost_night": False, "blight_outbreak": False, "waterlogged_bed_hours": 0},
        "beds": {"withered": {}, "health_loss": {}, "sown": 0, "harvested": 0},
        "incidents": {"occurrences": 0, "critical": 0, "first_by_source": {}}, "threats": {}, "rescues": 0, "orders": {},
    }


def make_run(days: list[dict], policy: str = "light_touch", seed: int = 1) -> dict:
    """A run around `days`."""
    return {"meta": {"policy": policy, "seed": seed, "staged_assets": True, "fixed_fps": 30, "speed": 4,
                     "real_seconds": 1.0, "residents": ["A"]}, "days": days}


class OpeningAndRunningOut(unittest.TestCase):
    def test_the_opening_is_not_food_running_out(self) -> None:
        days = [make_day(0, reserve=0), make_day(1, reserve=0), make_day(2, reserve=2500), make_day(3, reserve=2500)]
        a = report.analyse(make_run(days), THRESHOLDS)
        self.assertEqual(a["first_food"], 2)
        self.assertEqual(a["whole"]["ran_out_on"], "")
        self.assertEqual(a["whole"]["opening_days_without_food"], 2)
        self.assertNotIn("food ran out", " ".join(a["seasons"][0]["flags"]))

    def test_food_running_out_after_the_first_food_is_flagged(self) -> None:
        days = [make_day(0, reserve=2500), make_day(1, reserve=1000), make_day(2, reserve=0), make_day(3, reserve=0)]
        a = report.analyse(make_run(days), THRESHOLDS)
        self.assertEqual(a["whole"]["ran_out_on"], "Y1 Spring 3")
        self.assertEqual(a["whole"]["days_without_food"], 2)
        self.assertIn("food ran out", " ".join(a["seasons"][0]["flags"]))
        self.assertIn("food runs out Y1 Spring 3", report.headline(a))

    def test_the_first_food_day_is_the_first_midnight_with_food_and_is_not_running_out(self) -> None:
        # Day 1 opens empty (its minimum 0) and closes with food: it is the first food day, not a day food ran out.
        days = [make_day(0, reserve=0), make_day(1, reserve=0, reserve_end=2500), make_day(2, reserve=2500)]
        a = report.analyse(make_run(days), THRESHOLDS)
        self.assertEqual(a["first_food"], 1)
        self.assertEqual(a["whole"]["ran_out_on"], "")
        self.assertEqual(a["whole"]["opening_days_without_food"], 2)

    def test_the_opening_does_not_count_as_a_low_reserve(self) -> None:
        days = [make_day(0, reserve=0), make_day(1, reserve=3000), make_day(2, reserve=2500)]
        a = report.analyse(make_run(days), THRESHOLDS)
        self.assertNotIn("reserve fell", " ".join(a["seasons"][0]["flags"]))

    def test_food_running_out_is_not_also_a_low_reserve(self) -> None:
        days = [make_day(0, reserve=3000), make_day(1, reserve=1000), make_day(2, reserve=0)]
        flags = " ".join(report.analyse(make_run(days), THRESHOLDS)["seasons"][0]["flags"])
        self.assertIn("food ran out", flags)
        self.assertNotIn("reserve fell", flags)

    def test_a_low_reserve_is_flagged_and_an_ample_one_is_not(self) -> None:
        low = report.analyse(make_run([make_day(0, reserve=3000), make_day(1, reserve=1500)]), THRESHOLDS)
        ample = report.analyse(make_run([make_day(0, reserve=3000), make_day(1, reserve=2500)]), THRESHOLDS)
        self.assertIn("reserve fell to 1.50 days", " ".join(low["seasons"][0]["flags"]))
        self.assertNotIn("reserve fell", " ".join(ample["seasons"][0]["flags"]))


class Spoilage(unittest.TestCase):
    def test_spoilage_is_over_the_food_available_with_the_opening_stock(self) -> None:
        # Spring stores 10 U and closes with 30 U; summer stores 10 U more and spoils 8 U: 8 / (30 + 10) = 20%.
        days = [make_day(d, produced=1000 if d < 10 else 0, stock=30000) for d in range(12)]
        days += [make_day(12, produced=10000, spoiled=8000, stock=32000)]
        a = report.analyse(make_run(days), THRESHOLDS)
        summer = a["seasons"][1]
        self.assertAlmostEqual(summer["m"]["spoilage_pct"], 20.0)
        self.assertIn("spoilage 20.0%", " ".join(summer["flags"]))
        self.assertNotIn("spoilage", " ".join(a["seasons"][0]["flags"]))

    def test_a_cancelled_batch_counts_as_spoiled(self) -> None:
        a = report.analyse(make_run([make_day(0, produced=10000, spoiled=1000, cancelled=2000)]), THRESHOLDS)
        self.assertAlmostEqual(a["whole"]["spoiled_u"], 3.0)

    def test_the_headline_names_the_worst_counted_season(self) -> None:
        days = [make_day(d, produced=10000, spoiled=1000 if d == 3 else 0) for d in range(12)]
        days += [make_day(12 + d, produced=10000, spoiled=5000 if d == 2 else 0) for d in range(12)]
        line = report.headline(report.analyse(make_run(days), THRESHOLDS))
        self.assertIn("in Y1 Summer", line)
        self.assertIn("spoilage worst", line)

    def test_a_sliver_spoiled_is_not_flagged(self) -> None:
        days = [make_day(0, produced=500, stock=500), make_day(1, spoiled=500, stock=0)]
        a = report.analyse(make_run(days), THRESHOLDS)
        self.assertAlmostEqual(a["whole"]["spoilage_pct"], 100.0)
        self.assertNotIn("spoilage", " ".join(a["seasons"][0]["flags"]))

    def test_fish_is_counted_apart(self) -> None:
        a = report.analyse(make_run([make_day(0, produced=1000, fish=2500)]), THRESHOLDS)
        self.assertAlmostEqual(a["whole"]["produced_u"], 3.5)
        self.assertAlmostEqual(a["whole"]["fish_u"], 2.5)


class LabourAndMeals(unittest.TestCase):
    def test_idle_share_is_over_idle_plus_work(self) -> None:
        busy = report.analyse(make_run([make_day(0, work=750, idle=250)]), THRESHOLDS)
        idle = report.analyse(make_run([make_day(0, work=250, idle=750)]), THRESHOLDS)
        self.assertAlmostEqual(busy["whole"]["idle_pct"], 25.0)
        self.assertNotIn("idle labour", " ".join(busy["seasons"][0]["flags"]))
        self.assertIn("idle labour 75%", " ".join(idle["seasons"][0]["flags"]))

    def test_missed_meals_and_hunger_are_flagged(self) -> None:
        fine = report.analyse(make_run([make_day(0)]), THRESHOLDS)
        poor = report.analyse(make_run([make_day(0, without=9, hungry=108)]), THRESHOLDS)
        self.assertEqual(fine["seasons"][0]["flags"], [])
        flags = " ".join(poor["seasons"][0]["flags"])
        self.assertIn("meals missed: 9 (50% of diners)", flags)
        self.assertIn("hungry 50% of resident-hours", flags)

    def test_the_board_s_maxima_are_the_greatest_day_s(self) -> None:
        busy = make_day(1)
        busy["board"] = dict(busy["board"], queue_max=5, wait_ticks_max=40)
        a = report.analyse(make_run([make_day(0), busy]), THRESHOLDS)
        self.assertEqual(a["whole"]["queue_max"], 5)
        self.assertAlmostEqual(a["whole"]["wait_max_min"], 40 / 750 * 60)

    def test_board_waits_read_in_game_minutes(self) -> None:
        a = report.analyse(make_run([make_day(0)]), THRESHOLDS)
        self.assertAlmostEqual(a["whole"]["wait_mean_min"], 12.5 / 750 * 60)
        self.assertAlmostEqual(a["whole"]["queue_avg"], 0.5)
        self.assertEqual(a["whole"]["queue_max"], 2)
        self.assertAlmostEqual(a["whole"]["wait_max_min"], 20 / 750 * 60)


class Output(unittest.TestCase):
    def test_sparklines_scale_to_their_maximum(self) -> None:
        self.assertEqual(report.sparkline([0, 1, 2]), "▁▅█")
        self.assertEqual(report.sparkline([0, 0]), "▁▁")

    def test_the_whole_report_and_its_chart_are_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            run_path = Path(tmp) / "run.json"
            run_path.write_text(json.dumps(make_run([make_day(d) for d in range(14)], policy="hands_off")))
            out = Path(tmp) / "report.md"
            self.assertEqual(report.main([str(run_path), "--out", str(out), "--svg-dir", str(Path(tmp) / "charts")]), 0)
            text = out.read_text()
            self.assertIn("## Headlines", text)
            self.assertIn("hands_off seed 1, 14 days", text)
            self.assertIn("![Ready food, hands_off](charts/reserve_hands_off.svg)", text)
            self.assertTrue((Path(tmp) / "charts" / "reserve_hands_off.svg").read_text().startswith("<svg"))

    def test_every_threshold_says_why(self) -> None:
        for name, spec in THRESHOLDS.items():
            self.assertIn("value", spec, name)
            self.assertGreater(len(spec.get("why", "")), 40, name)


if __name__ == "__main__":
    unittest.main()
