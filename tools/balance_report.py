#!/usr/bin/env python3
"""Turn balance-harness runs into a readable markdown report (decision 0571).

    python3 tools/balance_report.py --out docs/balance/<name>.md [--svg-dir docs/balance/<name>] \
        [--summary-dir docs/balance/<name>] [--notes findings.md] [--thresholds tools/balance_thresholds.json] \
        [--title "..."] run1.json ...

Each run is the JSON godot/tools/balance/year_runner.gd writes. The report has:
  * the runs and the thresholds (with the reason each was chosen);
  * HEADLINES -- one line per run: when the food ran out, the worst spoilage, idle labour, meals missed;
  * a season table per policy (each seed's figure side by side) and the FLAGS the thresholds raise;
  * per run, the seasons in detail and text sparklines of the daily series;
  * with --svg-dir, one small SVG chart per policy of the daily Ready food, linked from the report.

Everything is computed from the runs' DAY records; the runs' own season roll-ups are not re-read, so a figure here
has one definition (below). Standard library only.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

TICKS_PER_HOUR = 750  # SimClock.TICKS_PER_HOUR; each run also states it in meta.ticks_per_hour
DAYS_PER_YEAR = 48
SEASON_NAMES = ["Spring", "Summer", "Autumn", "Winter"]
FISH = {"trout", "dace", "salmon", "perch", "carp", "whitefish"}
SPARK = "▁▂▃▄▅▆▇█"
RESERVE_CHART_CAP_DAYS = 10.0
COLOURS = ["#2a6f97", "#c0392b", "#27ae60", "#8e44ad", "#d68910"]


def load_runs(paths: list[str]) -> list[dict]:
    """Read each run JSON; a run with no days is refused."""
    runs = []
    for path in paths:
        data = json.loads(Path(path).read_text())
        if not data.get("days"):
            raise SystemExit(f"error: {path} has no day records")
        if int(data["meta"].get("ticks_per_hour", TICKS_PER_HOUR)) != TICKS_PER_HOUR:
            raise SystemExit(f"error: {path} counts {data['meta']['ticks_per_hour']} ticks an hour, not {TICKS_PER_HOUR}")
        data["_path"] = path
        runs.append(data)
    return runs


def load_thresholds(path: str) -> dict:
    """The thresholds file: name -> {value, why}."""
    data = json.loads(Path(path).read_text())
    return {k: v for k, v in data.items() if not k.startswith("_")}


def total(d: dict) -> int:
    """The sum of a {key: number} dictionary."""
    return sum(int(v) for v in d.values())


def season_key(day: dict) -> tuple[int, int]:
    """(year, season) of a day record."""
    return int(day["year"]), int(day["season"])


def season_label(key: tuple[int, int]) -> str:
    """'Y1 Spring' for (0, 0)."""
    return f"Y{key[0] + 1} {SEASON_NAMES[key[1]]}"


def day_label(day: dict) -> str:
    """'Y1 Spring 3' for a day record."""
    return f"Y{int(day['year']) + 1} {SEASON_NAMES[int(day['season'])]} {int(day['season_day'])}"


def group_seasons(days: list[dict]) -> list[tuple[tuple[int, int], list[dict], int]]:
    """The days in season groups, in order, each with the pantry stock (milli-U) it opened with."""
    groups: list[tuple[tuple[int, int], list[dict], int]] = []
    opening = 0
    for day in days:
        key = season_key(day)
        if not groups or groups[-1][0] != key:
            groups.append((key, [], opening))
        groups[-1][1].append(day)
        opening = int(day["stock"]["total_milli"])
    return groups


def first_food_day(days: list[dict]) -> int:
    """The calendar day of the first midnight with any Ready food (-1: never). The demo opens with an empty pantry,
    so the days before it are the OPENING, not food running out."""
    for d in days:
        if int(d["reserve_days_milli_end"]) > 0:
            return int(d["day"])
    return -1


def season_metrics(days: list[dict], opening_milli: int, first_food: int) -> dict:
    """Every figure the report shows for one group of days (`first_food`: the run's first_food_day)."""
    m: dict = {"days": len(days), "partial": any(d.get("partial") for d in days)}
    produced = sum(total(d["items"]["produced"]) for d in days)
    fish = sum(int(v) for d in days for k, v in d["items"]["produced"].items() if k in FISH)
    spoiled = sum(total(d["items"]["spoiled"]) + int(d["kitchen"]["cancelled_spoil_milli"]) for d in days)
    m["produced_u"] = produced / 1000
    m["fish_u"] = fish / 1000
    m["withdrawn_u"] = sum(total(d["items"]["withdrawn"]) for d in days) / 1000
    m["spoiled_u"] = spoiled / 1000
    # Spoilage: the share of the food available in the season (its opening stock plus what was stored) that spoiled.
    available = opening_milli + produced
    m["spoilage_pct"] = 100.0 * spoiled / available if available > 0 else 0.0
    m["table_spoiled_portions"] = sum(int(d["kitchen"]["table_spoiled_portions"]) for d in days)
    m["portions_eaten"] = sum(int(d["kitchen"]["portions_eaten"]) for d in days)
    m["eaten_u"] = sum(int(d["kitchen"]["cooked_milli"]) + int(d["kitchen"]["raw_eaten_milli"]) for d in days) / 1000
    m["stock_end_u"] = int(days[-1]["stock"]["total_milli"]) / 1000
    m["reserve_min_days"] = min(int(d["reserve_days_milli_min"]) for d in days) / 1000
    fed = [int(d["reserve_days_milli_min"]) for d in days if 0 <= first_food < int(d["day"])]
    m["reserve_min_fed_days"] = min(fed) / 1000 if fed else None
    m["reserve_end_days"] = int(days[-1]["reserve_days_milli_end"]) / 1000
    empty = [d for d in days if int(d["reserve_days_milli_min"]) == 0]
    out = [d for d in empty if 0 <= first_food < int(d["day"])]
    m["ran_out_on"] = day_label(out[0]) if out else ""
    m["days_without_food"] = len(out)
    m["opening_days_without_food"] = len(empty) - len(out)
    m.update(meal_metrics(days))
    m.update(labour_metrics(days))
    m.update(world_metrics(days))
    return m


def meal_metrics(days: list[dict]) -> dict:
    """Meals served and missed; resident-hours fed, peckish and hungry."""
    ate = sum(int(d["meals"]["ate"]) for d in days)
    raw = sum(int(d["meals"]["raw"]) for d in days)
    without = sum(int(d["meals"]["without"]) for d in days)
    diners = ate + raw + without
    fed = {k: sum(int(d["fed_resident_hours"][k]) for d in days) for k in ("fed", "peckish", "hungry")}
    hours = sum(fed.values())
    return {"meals_ate": ate, "meals_raw": raw, "meals_without": without,
            "missed_pct": 100.0 * without / diners if diners else 0.0,
            "fed_pct": 100.0 * fed["fed"] / hours if hours else 0.0,
            "peckish_pct": 100.0 * fed["peckish"] / hours if hours else 0.0,
            "hungry_pct": 100.0 * fed["hungry"] / hours if hours else 0.0}


def labour_metrics(days: list[dict]) -> dict:
    """Labour per resident-day (hours) and the idle share; the work board's queue and waits."""
    lab = {k: sum(int(d["labour_ticks"][k]) for d in days) for k in ("work", "idle", "meal", "rest", "other")}
    residents = max(1, len(days[0]["labour_ticks_by_resident"]))
    resident_days = residents * len(days)
    board = [d["board"] for d in days]
    claimed = sum(int(b["claimed"]) for b in board)
    queue_ticks = sum(int(b["queue_ticks"]) for b in board)
    out = {f"{k}_h_per_resident_day": lab[k] / TICKS_PER_HOUR / resident_days for k in lab}
    out["idle_pct"] = 100.0 * lab["idle"] / (lab["idle"] + lab["work"]) if lab["idle"] + lab["work"] else 0.0
    out["queue_avg"] = sum(int(b["queue_task_ticks"]) for b in board) / queue_ticks if queue_ticks else 0.0
    out["queue_max"] = max(int(b["queue_max"]) for b in board)
    out["claimed"] = claimed
    out["dropped"] = sum(int(b["dropped"]) for b in board)
    out["wait_mean_min"] = (sum(int(b["wait_ticks_sum"]) for b in board) / claimed * 60 / TICKS_PER_HOUR
                            if claimed else 0.0)
    out["wait_max_min"] = max(int(b["wait_ticks_max"]) for b in board) * 60 / TICKS_PER_HOUR
    out["work_h_by_resident"] = [
        sum(int(d["labour_ticks_by_resident"][r]["work"]) for d in days) / TICKS_PER_HOUR / len(days)
        for r in range(residents)]
    return out


def world_metrics(days: list[dict]) -> dict:
    """Materials, weather, losses, incidents and the policy's orders."""
    out: dict = {}
    for mat in ("wood", "planks", "stone", "earth", "water"):
        out[f"{mat}_in_u"] = sum(int(d["materials"][mat]["in"]) for d in days) / 1000
        out[f"{mat}_out_u"] = sum(int(d["materials"][mat]["out"]) for d in days) / 1000
        out[f"{mat}_end_u"] = int(days[-1]["materials"][mat]["end"]) / 1000
    events = []
    for d in days:
        event = d["weather"]["event"]
        if event and event not in events:
            events.append(event)
    out["events"] = events
    out["frost_nights"] = sum(1 for d in days if d["weather"]["frost_night"])
    out["blight_outbreaks"] = sum(1 for d in days if d["weather"]["blight_outbreak"])
    out["waterlogged_bed_hours"] = sum(int(d["weather"]["waterlogged_bed_hours"]) for d in days)
    out["withered"] = sum_dicts(d["beds"]["withered"] for d in days)
    out["health_loss"] = sum_dicts(d["beds"]["health_loss"] for d in days)
    out["sown"] = sum(int(d["beds"]["sown"]) for d in days)
    out["harvested"] = sum(int(d["beds"]["harvested"]) for d in days)
    out["incidents"] = sum(int(d["incidents"]["occurrences"]) for d in days)
    out["critical"] = sum(int(d["incidents"]["critical"]) for d in days)
    out["incidents_by_source"] = sum_dicts(d["incidents"]["first_by_source"] for d in days)
    out["threats"] = sum_dicts(d["threats"] for d in days)
    out["rescues"] = sum(int(d["rescues"]) for d in days)
    out["orders"] = sum_dicts(d.get("orders", {}) for d in days)
    return out


def sum_dicts(dicts) -> dict:
    """Key-wise sums of {key: number} dictionaries."""
    out: dict = {}
    for d in dicts:
        for k, v in d.items():
            out[k] = out.get(k, 0) + int(v)
    return out


def flags_for(m: dict, th: dict) -> list[str]:
    """The thresholds a season's metrics cross, in words."""
    flags = []
    if m["ran_out_on"]:
        flags.append(f"food ran out ({m['ran_out_on']}; {m['days_without_food']} day(s) with no Ready food)")
    if m["opening_days_without_food"]:
        flags.append(f"{m['opening_days_without_food']} opening day(s) before the first Ready food")
    low = m["reserve_min_fed_days"]
    if not m["ran_out_on"] and low is not None and low < th["reserve_min_days"]["value"]:
        flags.append(f"reserve fell to {low:.2f} days (< {th['reserve_min_days']['value']:g})")
    if m["spoilage_pct"] > th["spoilage_max_pct"]["value"] and m["spoiled_u"] >= th["spoilage_min_u"]["value"]:
        flags.append(f"spoilage {m['spoilage_pct']:.1f}% (> {th['spoilage_max_pct']['value']:g}%)")
    if m["idle_pct"] > th["idle_max_pct"]["value"]:
        flags.append(f"idle labour {m['idle_pct']:.0f}% (> {th['idle_max_pct']['value']:g}%)")
    if m["missed_pct"] > th["missed_meals_max_pct"]["value"]:
        flags.append(f"meals missed: {m['meals_without']} ({m['missed_pct']:.0f}% of diners)")
    if m["hungry_pct"] > th["hungry_max_pct"]["value"]:
        flags.append(f"hungry {m['hungry_pct']:.0f}% of resident-hours (> {th['hungry_max_pct']['value']:g}%)")
    return flags


def sparkline(values: list[float]) -> str:
    """A text sparkline, scaled to the series' own maximum (all-zero: the lowest bar)."""
    top = max(values) if values else 0
    if top <= 0:
        return SPARK[0] * len(values)
    return "".join(SPARK[min(len(SPARK) - 1, int(v / top * (len(SPARK) - 1) + 0.5))] for v in values)


def run_name(run: dict) -> str:
    """'hands_off seed 1', with its length when it is not one year ('hands_off seed 1, 96 days')."""
    name = f"{run['meta']['policy']} seed {run['meta']['seed']}"
    days = len(run["days"])
    return name if days == DAYS_PER_YEAR else f"{name}, {days} days"


def analyse(run: dict, th: dict) -> dict:
    """A run's seasons (label, metrics, flags), and its whole-run metrics."""
    seasons = []
    first_food = first_food_day(run["days"])
    for key, days, opening in group_seasons(run["days"]):
        m = season_metrics(days, opening, first_food)
        seasons.append({"label": season_label(key), "m": m, "flags": flags_for(m, th)})
    whole = season_metrics(run["days"], 0, first_food)
    return {"run": run, "seasons": seasons, "whole": whole, "first_food": first_food,
            "spoilage_floor_u": float(th["spoilage_min_u"]["value"])}


def min_after(a: dict) -> float:
    """The lowest Ready food (days) after the first food."""
    after = [int(d["reserve_days_milli_min"]) for d in a["run"]["days"] if int(d["day"]) > a["first_food"]]
    return min(after) / 1000 if after else 0.0


def headline(a: dict) -> str:
    """One line for a run: when the food ran out, the worst spoilage, idle labour and meals missed."""
    w = a["whole"]
    first = [d for d in a["run"]["days"] if int(d["day"]) == a["first_food"]]
    parts = [f"first Ready food {day_label(first[0])}" if first else "never any Ready food"]
    if w["ran_out_on"]:
        parts.append(f"food runs out {w['ran_out_on']} ({w['days_without_food']} days with none after that)")
    elif first:
        parts.append(f"food never runs out after that (lowest {min_after(a):.1f} days)")
    floor = a["spoilage_floor_u"]
    counted = [s for s in a["seasons"] if s["m"]["spoiled_u"] >= floor]
    if counted:
        worst = max(counted, key=lambda s: s["m"]["spoilage_pct"])
        parts.append(f"spoilage worst {worst['m']['spoilage_pct']:.0f}% in {worst['label']} "
                     f"({w['spoiled_u']:.1f} of {w['produced_u']:.1f} U stored over the run)")
    else:
        parts.append(f"spoilage negligible ({w['spoiled_u']:.1f} U over the run)")
    parts.append(f"{w['idle_pct']:.0f}% idle labour")
    parts.append(f"{w['meals_without']} meals missed of {w['meals_ate'] + w['meals_raw'] + w['meals_without']} "
                 f"({w['missed_pct']:.0f}%)")
    parts.append(f"hungry {w['hungry_pct']:.0f}% of resident-hours")
    return f"**{run_name(a['run'])}**: " + "; ".join(parts) + "."


SEASON_ROWS = [
    ("Food stored (U)", "produced_u", "{:.1f}"),
    ("of which fish (U)", "fish_u", "{:.1f}"),
    ("Food eaten (U)", "eaten_u", "{:.1f}"),
    ("Portions eaten", "portions_eaten", "{}"),
    ("Spoiled in store (U)", "spoiled_u", "{:.1f}"),
    ("Spoilage %", "spoilage_pct", "{:.0f}"),
    ("Stock at end (U)", "stock_end_u", "{:.1f}"),
    ("Ready food min (days)", "reserve_min_days", "{:.2f}"),
    ("Days with no Ready food (opening)", None, None),
    ("Meals: ate / raw / missed", None, None),
    ("Missed %", "missed_pct", "{:.0f}"),
    ("Fed / peckish / hungry % of hours", None, None),
    ("Work h / resident-day", "work_h_per_resident_day", "{:.1f}"),
    ("Idle h / resident-day", "idle_h_per_resident_day", "{:.1f}"),
    ("Idle %", "idle_pct", "{:.0f}"),
    ("Board queue avg / max", None, None),
    ("Board wait mean / max (game min)", None, None),
    ("Wood in / out / end (U)", None, None),
    ("Planks / stone / earth at end (U)", None, None),
    ("Beds sown / harvested", None, None),
    ("Crops withered (blight/frost/overripe/other)", None, None),
    ("Weather events", None, None),
    ("Frost nights / blight outbreaks", None, None),
    ("Incident raises (critical) / rescues", None, None),
]


def cell(m: dict, label: str, key: str | None, fmt: str | None) -> str:
    """One season cell of SEASON_ROWS."""
    if key is not None:
        return fmt.format(m[key])
    w = m["withered"]
    composite = {
        "Days with no Ready food (opening)": f"{m['days_without_food']} ({m['opening_days_without_food']})",
        "Meals: ate / raw / missed": f"{m['meals_ate']} / {m['meals_raw']} / {m['meals_without']}",
        "Fed / peckish / hungry % of hours": f"{m['fed_pct']:.0f} / {m['peckish_pct']:.0f} / {m['hungry_pct']:.0f}",
        "Board queue avg / max": f"{m['queue_avg']:.2f} / {m['queue_max']}",
        "Board wait mean / max (game min)": f"{m['wait_mean_min']:.0f} / {m['wait_max_min']:.0f}",
        "Wood in / out / end (U)": f"{m['wood_in_u']:.1f} / {m['wood_out_u']:.1f} / {m['wood_end_u']:.1f}",
        "Planks / stone / earth at end (U)": f"{m['planks_end_u']:.1f} / {m['stone_end_u']:.1f} / {m['earth_end_u']:.1f}",
        "Beds sown / harvested": f"{m['sown']} / {m['harvested']}",
        "Crops withered (blight/frost/overripe/other)":
            f"{w.get('blight', 0)}/{w.get('frost', 0)}/{w.get('overripe', 0)}/{w.get('other', 0)}",
        "Weather events": ", ".join(m["events"]) or "-",
        "Frost nights / blight outbreaks": f"{m['frost_nights']} / {m['blight_outbreaks']}",
        "Incident raises (critical) / rescues": f"{m['incidents']} ({m['critical']}) / {m['rescues']}",
    }
    return composite[label]


def season_table(a: dict) -> list[str]:
    """A run's seasons as a markdown table (one column a season)."""
    seasons = a["seasons"]
    head = "| | " + " | ".join(s["label"] + (" (part)" if s["m"]["partial"] else "") for s in seasons) + " |"
    lines = [head, "|---" * (len(seasons) + 1) + "|"]
    for label, key, fmt in SEASON_ROWS:
        lines.append(f"| {label} | " + " | ".join(cell(s["m"], label, key, fmt) for s in seasons) + " |")
    return lines


def policy_table(analyses: list[dict], metric: str, fmt: str) -> list[str]:
    """One metric, seasons down, seeds across, for the runs of one policy."""
    labels = []
    for a in analyses:
        for s in a["seasons"]:
            if s["label"] not in labels:
                labels.append(s["label"])
    head = "| Season | " + " | ".join(run_name(a["run"]).split(" ", 1)[1] for a in analyses) + " |"
    lines = [head, "|---" * (len(analyses) + 1) + "|"]
    for label in labels:
        row = []
        for a in analyses:
            found = [s for s in a["seasons"] if s["label"] == label]
            row.append(fmt.format(found[0]["m"][metric]) if found else "-")
        lines.append(f"| {label} | " + " | ".join(row) + " |")
    return lines


def daily_series(run: dict) -> dict[str, list[float]]:
    """The daily series the sparklines draw."""
    days = run["days"]
    return {
        "Ready food (days)": [int(d["reserve_days_milli_end"]) / 1000 for d in days],
        "Pantry stock (U)": [int(d["stock"]["total_milli"]) / 1000 for d in days],
        "Food stored (U)": [total(d["items"]["produced"]) / 1000 for d in days],
        "Portions eaten": [float(d["kitchen"]["portions_eaten"]) for d in days],
        "Spoiled (U)": [total(d["items"]["spoiled"]) / 1000 for d in days],
        "Meals missed": [float(d["meals"]["without"]) for d in days],
        "Hungry resident-hours": [float(d["fed_resident_hours"]["hungry"]) for d in days],
        "Work h (all residents)": [int(d["labour_ticks"]["work"]) / TICKS_PER_HOUR for d in days],
        "Idle h (all residents)": [int(d["labour_ticks"]["idle"]) / TICKS_PER_HOUR for d in days],
        "Wood (U)": [int(d["materials"]["wood"]["end"]) / 1000 for d in days],
    }


def reserve_svg(policy: str, analyses: list[dict]) -> str:
    """A small line chart of each seed's daily Ready food (capped at RESERVE_CHART_CAP_DAYS), with season bands."""
    width, height, left, bottom, top = 640, 220, 44, 28, 16
    n = max(len(a["run"]["days"]) for a in analyses)
    sx = (width - left - 10) / max(1, n - 1)
    sy = (height - bottom - top) / RESERVE_CHART_CAP_DAYS
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
             f'viewBox="0 0 {width} {height}" font-family="sans-serif" font-size="11">',
             f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
             f'<text x="{left}" y="12" fill="#333">Ready food at each midnight (days, capped at '
             f'{RESERVE_CHART_CAP_DAYS:g}) -- {policy}</text>']
    for k in range(0, n, 12):
        x = left + k * sx
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{height - bottom}" stroke="#ddd"/>')
        parts.append(f'<text x="{x + 2:.1f}" y="{height - bottom + 14}" fill="#555">'
                     f'{SEASON_NAMES[(k // 12) % 4]}</text>')
    for v in (0, 2, 5, 10):
        y = height - bottom - v * sy
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width - 10}" y2="{y:.1f}" stroke="#eee"/>')
        parts.append(f'<text x="4" y="{y + 4:.1f}" fill="#555">{v}</text>')
    for i, a in enumerate(analyses):
        days = a["run"]["days"]
        points = " ".join(f"{left + k * sx:.1f},{height - bottom - min(RESERVE_CHART_CAP_DAYS, int(d['reserve_days_milli_end']) / 1000) * sy:.1f}"
                          for k, d in enumerate(days))
        colour = COLOURS[i % len(COLOURS)]
        parts.append(f'<polyline fill="none" stroke="{colour}" stroke-width="1.6" points="{points}"/>')
        parts.append(f'<text x="{width - 120}" y="{top + 14 * (i + 1)}" fill="{colour}">'
                     f'seed {a["run"]["meta"]["seed"]} ({len(days)} d)</text>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def write_report(analyses: list[dict], th: dict, title: str, svg_dir: Path | None, out: Path, notes: str = "") -> str:
    """The whole markdown report (and the SVGs, when asked); `notes` (markdown written by a person) goes before the
    generated sections."""
    lines = [f"# {title}", "",
             "Generated by `tools/balance_report.py` from the balance harness (`godot/tools/balance/`, decision 0571).",
             "Every figure is measured on the real demo village; nothing here is a projection.", ""]
    if notes:
        lines += [notes.rstrip(), ""]
    lines += ["## Runs", "",
             "| Policy | Seed | Days | Staged assets | FPS x speed | Real seconds |", "|---|---|---|---|---|---|"]
    for a in analyses:
        meta = a["run"]["meta"]
        lines.append(f"| {meta['policy']} | {meta['seed']} | {len(a['run']['days'])} | {meta['staged_assets']} | "
                     f"{meta['fixed_fps']} x {meta['speed']} | {meta['real_seconds']} |")
    lines += ["", "## Headlines", ""] + [f"- {headline(a)}" for a in analyses]
    lines += ["", "## Flags", ""]
    for a in analyses:
        for s in a["seasons"]:
            if s["flags"]:
                lines.append(f"- {run_name(a['run'])}, {s['label']}: " + "; ".join(s["flags"]))
    lines += ["", "## Thresholds", "", "| Threshold | Value | Why |", "|---|---|---|"]
    for name, spec in th.items():
        lines.append(f"| `{name}` | {spec['value']:g} | {spec['why']} |")
    for policy in sorted({a["run"]["meta"]["policy"] for a in analyses}):
        group = [a for a in analyses if a["run"]["meta"]["policy"] == policy]
        lines += policy_section(policy, group, svg_dir, out)
    for a in analyses:
        lines += run_section(a)
    lines += ["", "## Definitions", "", DEFINITIONS]
    return "\n".join(lines) + "\n"


def policy_section(policy: str, group: list[dict], svg_dir: Path | None, out: Path) -> list[str]:
    """One policy's seeds side by side, season by season, and its chart."""
    lines = ["", f"## Policy: {policy}", ""]
    if svg_dir is not None:
        svg_dir.mkdir(parents=True, exist_ok=True)
        path = svg_dir / f"reserve_{policy}.svg"
        path.write_text(reserve_svg(policy, group))
        rel = path.relative_to(out.parent) if path.is_relative_to(out.parent) else path
        lines += [f"![Ready food, {policy}]({rel.as_posix()})", ""]
    for title, metric, fmt in (("Ready food, lowest (days)", "reserve_min_days", "{:.2f}"),
                               ("Food stored (U)", "produced_u", "{:.1f}"), ("Spoilage %", "spoilage_pct", "{:.0f}"),
                               ("Meals missed", "meals_without", "{}"), ("Hungry % of resident-hours", "hungry_pct", "{:.0f}"),
                               ("Idle labour %", "idle_pct", "{:.0f}"), ("Work h / resident-day", "work_h_per_resident_day", "{:.1f}")):
        lines += [f"**{title}**", ""] + policy_table(group, metric, fmt) + [""]
    return lines


def run_section(a: dict) -> list[str]:
    """One run in detail: its season table, sparklines and orders."""
    run = a["run"]
    lines = ["", f"## Run: {run_name(run)}", ""] + season_table(a) + ["", "Daily series (each scaled to its own maximum):",
                                                                      "", "```"]
    for name, values in daily_series(run).items():
        lines.append(f"{name:<24} {sparkline(values)}  max {max(values):.1f}")
    lines.append("```")
    w = a["whole"]
    if w["orders"]:
        lines += ["", "Orders given by the policy: " + ", ".join(f"{k} {v}" for k, v in sorted(w["orders"].items()))]
    lines += ["", "Work hours per resident-day, by resident: " + ", ".join(
        f"{name} {h:.1f}" for name, h in zip(run["meta"]["residents"], w["work_h_by_resident"]))]
    if w["incidents_by_source"]:
        lines += ["", "New incidents by source: " + ", ".join(f"{k} {v}" for k, v in sorted(w["incidents_by_source"].items()))
                  + "; threats: " + (", ".join(f"{k} {v}" for k, v in sorted(w["threats"].items())) or "none")]
    return lines


DEFINITIONS = """\
- **Food stored**: the pantry's ledger of food credited to a store (harvests, catches, the rack's and mill's outputs).
- **Food eaten**: the kitchen's food cooked into batches plus food eaten raw (milli-U as the kitchen counts it).
- **Spoiled in store**: the pantry's ledger of spoiled food plus a cancelled batch's; **spoilage %** is that over the food
  available in the season (the stock it opened with plus what was stored in it). Portions spoiled on the table are
  counted apart (table_spoiled_portions in the JSON).
- **Ready food**: the HUD's figure (`kitchen.gd days_of_meals_milli`): portions held plus the portions the stores'
  grain, roots and fresh fish would cook, over the village's daily portions; read every farm hour (the minimum) and at
  midnight. "Food ran out" is a day whose lowest reading is 0 after the first midnight with any Ready food; the days
  before that are the OPENING (the demo opens with an empty pantry and its first crops still growing).
- **Meals**: each resident at each meal ate a portion, ate raw, or went without (the kitchen's own tally).
- **Fed / peckish / hungry**: one reading an hour of every resident's need (nourishment.gd).
- **Labour**: every few frames each resident is REST (in bed or going), MEAL (a diner), WORK (holds a board task, cooks
  or draws water, or is on an order), OTHER (an evacuation, a rescue, in the water) or IDLE. **Idle %** is idle over
  idle plus work.
- **Board**: waiting tasks across every work-board source, time-weighted; a wait runs from the first frame a task waits to
  the frame a worker holds it (claimed) or it stops waiting without one (dropped).
- **Materials**: each frame's rise (in) and fall (out) of the stores' stocks; two moves in one frame net out.
- **Withered**: a crop lost, charged to blight (the bed was blighted), frost (a cold hour), overripe (it stood ripe)
  or other.
"""


def write_summaries(analyses: list[dict], folder: Path) -> None:
    """Each run's metrics, season by season and whole, as a small JSON (the raw run regenerates exactly: same seed,
    same policy, same numbers)."""
    folder.mkdir(parents=True, exist_ok=True)
    for a in analyses:
        meta = a["run"]["meta"]
        name = f"{meta['policy']}_s{meta['seed']}_d{len(a['run']['days'])}.summary.json"
        data = {"meta": meta, "first_food_day": a["first_food"], "whole": a["whole"],
                "seasons": [{"season": s["label"], "flags": s["flags"], **s["m"]} for s in a["seasons"]]}
        (folder / name).write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")


def main(argv: list[str]) -> int:
    """Read the runs and the thresholds; write the report."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("runs", nargs="+", help="run JSON files from year_runner.gd")
    parser.add_argument("--out", required=True, help="the markdown report to write")
    parser.add_argument("--svg-dir", help="write one reserve chart per policy here and link it")
    parser.add_argument("--thresholds", default=str(Path(__file__).with_name("balance_thresholds.json")))
    parser.add_argument("--title", default="Balance baseline")
    parser.add_argument("--summary-dir", help="write each run's season metrics as <policy>_s<seed>_d<days>.summary.json")
    parser.add_argument("--notes", help="a markdown file (findings written by a person) placed before the generated part")
    args = parser.parse_args(argv)
    th = load_thresholds(args.thresholds)
    runs = sorted(load_runs(args.runs), key=lambda r: (r["meta"]["policy"], int(r["meta"]["seed"]), len(r["days"])))
    analyses = [analyse(r, th) for r in runs]
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    notes = Path(args.notes).read_text() if args.notes else ""
    out.write_text(write_report(analyses, th, args.title, Path(args.svg_dir) if args.svg_dir else None, out, notes))
    if args.summary_dir:
        write_summaries(analyses, Path(args.summary_dir))
    print(f"wrote {out} ({len(runs)} runs)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
