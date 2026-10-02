#!/usr/bin/env python3
"""Judge a soak run (decision 0921): flag monotonic growth and frame-time drift, with the reason for every threshold.

Reads the JSON godot/tools/soak/soak_test.gd writes (with the machine samples tools/soak_test.py adds) and writes a
markdown report and a small verdict JSON. Every threshold, and why it is set where it is, is in a thresholds file
(tools/soak_thresholds.json by default); a flag quotes its reason.

    python3 tools/soak_report.py <run.json> --md <out.md> --json <out.verdict.json> [--thresholds <file>]

THE TESTS
  * GROWTH, per monitored column (static memory, objects, nodes, resources, orphan nodes, video memory, the village's
    own books). Each game day is reduced to its FLOOR -- the smallest hourly sample in it, what the day retained, not
    its busiest hour -- and a least-squares line is fitted to the floors of the days after the warm-up. A column is
    flagged when the line rises faster than its `per_day` threshold, the floors rose on at least `min_rising` of the
    day-to-day steps (monotonic, not one jump), and the net change over the kept days exceeds one day's allowance.
    With restarts in the run each day is a fresh village, so the same test reads growth per restart.
  * DRIFT, of frame time: the daily p50 and p95 of frame work (real microseconds a frame) relative to the first kept
    days. Because the machine is shared, the same slope is taken of the Godot process's own CPU time per frame (from
    the runner's `ps` samples): work that grows shows in both; a busier machine shows in wall time only, and is reported
    as load, not flagged.
  * SYSTEMS: each system's daily mean (the scale test's per-system driver) against its first kept days.
  * ERRORS: any error the harness heard or the log shows.
  * RESTARTS: objects of the old village still alive and unreachable after "Restart demo" (a reference cycle), and
    what stays held growing from restart to restart.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path

DEFAULT_THRESHOLDS = Path(__file__).resolve().parent / "soak_thresholds.json"


def load_thresholds(path: Path) -> dict:
    """The thresholds file (its path kept as `_source`, for the report)."""
    out = json.loads(Path(path).read_text())
    out["_source"] = str(path)
    return out


def slope(values: list[float]) -> float:
    """Least-squares slope of `values` against their index (0 for fewer than two)."""
    n = len(values)
    if n < 2:
        return 0.0
    mx = (n - 1) / 2
    my = sum(values) / n
    top = sum((k - mx) * (v - my) for k, v in enumerate(values))
    bottom = sum((k - mx) ** 2 for k in range(n))
    return top / bottom


def rising_share(values: list[float]) -> float:
    """Share of neighbour-to-neighbour steps that went up (0 for fewer than two)."""
    if len(values) < 2:
        return 0.0
    return sum(1 for a, b in zip(values, values[1:]) if b > a) / (len(values) - 1)


def daily_floors(run: dict, column: str) -> list[int]:
    """Each game day's smallest hourly sample of `column` (day d holds soak hours 24d .. 24d+23)."""
    cols = run.get("hour_columns", [])
    if column not in cols:
        return []
    at, hour_at = cols.index(column), cols.index("soak_hour")
    floors: dict[int, int] = {}
    for row in run.get("hours", []):
        day = row[hour_at] // 24
        floors[day] = min(floors.get(day, row[at]), row[at])
    complete = run.get("meta", {}).get("hours_run", 0) // 24
    return [floors[d] for d in sorted(floors) if d < complete]


def judge_growth(name: str, floors: list[int], rule: dict, skip: int, min_days: int) -> dict:
    """One column's growth verdict over its daily floors after `skip` warm-up days."""
    kept = floors[skip:]
    out = {"metric": name, "days": len(kept), "per_day": None, "net": None, "rising": None, "flag": False,
           "threshold": rule["per_day"], "reason": rule["reason"], "first": kept[0] if kept else None,
           "last": kept[-1] if kept else None}
    if len(kept) < min_days:
        out["note"] = f"only {len(kept)} kept days (needs {min_days})"
        return out
    out.update(per_day=round(slope(kept), 2), net=kept[-1] - kept[0], rising=round(rising_share(kept), 2))
    out["flag"] = (out["per_day"] > rule["per_day"] and out["rising"] >= rule.get("min_rising", 0.0)
                   and out["net"] > rule["per_day"])
    return out


def cpu_at(samples: list, when: float) -> float | None:
    """The process's cumulative CPU seconds at `when`, interpolated between the runner's samples (None outside them).
    A day at 4x lasts about as long as a few samples, so reading the nearest sample would quantise a day's CPU."""
    for a, b in zip(samples, samples[1:]):
        if a[0] <= when <= b[0]:
            span = b[0] - a[0]
            return a[4] + (b[4] - a[4]) * ((when - a[0]) / span if span else 0.0)
    return None


def machine_by_day(run: dict) -> list[dict]:
    """Per day: mean load, the process's CPU seconds and its resident memory at the day's end (from the runner)."""
    samples = run.get("machine", {}).get("samples", [])
    out = []
    for day in run.get("days", []):
        lo, hi = day.get("unix_start", 0), day.get("unix_end", 0)
        inside = [s for s in samples if lo <= s[0] <= hi]
        start, end = cpu_at(samples, lo), cpu_at(samples, hi)
        cpu = end - start if start is not None and end is not None else None
        frames = day.get("frames_all") or day.get("frames") or 0
        loads = inside or [s for s in samples if s[0] >= lo][:1]
        out.append({"day": day["day"], "load1": round(statistics.mean(s[1] for s in loads), 1) if loads else None,
                    "cpu_s": round(cpu, 1) if cpu is not None else None,
                    "cpu_ms_per_frame": round(1000 * cpu / frames, 3) if cpu and frames else None,
                    "wall_s": round(hi - lo, 1), "rss_mb": round(loads[-1][3] / 1024) if loads else None})
    return out


def relative_slope(values: list[float], base_days: int) -> tuple[float | None, float | None]:
    """(slope per day relative to the median of the first `base_days` values, that baseline)."""
    if len(values) < 2:
        return None, None
    base = statistics.median(values[:base_days])
    if not base:
        return None, base
    return slope(values) / base, base


def judge_drift(run: dict, machine: list[dict], th: dict) -> list[dict]:
    """Frame-time drift: daily p50 and p95 of work, and CPU per frame (see DRIFT)."""
    rule, skip = th["frame_drift"], th["skip_days"]
    days = run.get("days", [])[skip:]
    # The last day may end after the runner's last sample; a day without a CPU reading is left out of this line.
    cpu = [m["cpu_ms_per_frame"] for m in machine[skip:] if m["cpu_ms_per_frame"]]
    cpu_rel, cpu_base = relative_slope(cpu, rule["base_days"]) if len(cpu) >= th["min_days"] else (None, None)
    out = []
    for stat in ("p50", "p95"):
        series = [d["columns"]["work_us"][stat] for d in days]
        rel, base = relative_slope(series, rule["base_days"])
        limit = rule[f"{stat}_relative_per_day"]
        entry = {"metric": f"frame work {stat}", "days": len(series), "baseline_us": base,
                 "relative_per_day": round(rel, 4) if rel is not None else None, "threshold": limit,
                 "cpu_relative_per_day": round(cpu_rel, 4) if cpu_rel is not None else None,
                 "reason": rule["reason"], "flag": False, "note": ""}
        if rel is None or len(series) < th["min_days"]:
            entry["note"] = "too few days"
        elif rel > limit and (cpu_rel is None or cpu_rel > rule["cpu_relative_per_day"]):
            entry["flag"] = True
        elif rel > limit:
            entry["note"] = "wall time drifted but the process's CPU per frame did not: machine load, not the game"
        out.append(entry)
    out.append({"metric": "CPU per frame", "days": len(cpu), "baseline_ms": cpu_base,
                "relative_per_day": round(cpu_rel, 4) if cpu_rel is not None else None,
                "threshold": rule["cpu_relative_per_day"], "reason": rule["reason"], "flag": False,
                "note": "context for the two rows above"})
    return out


def judge_systems(run: dict, th: dict) -> list[dict]:
    """Each system's daily mean: its drift relative to the first kept days (see SYSTEMS), costliest first."""
    rule, skip = th["systems"], th["skip_days"]
    days = run.get("days", [])[skip:]
    if not days:
        return []
    out = []
    for name in days[0]["columns"]:
        if not (name.startswith("sys.") or name.startswith("cast.")):
            continue
        means = [d["columns"][name]["mean"] for d in days]
        rel, base = relative_slope(means, rule["base_days"])
        flag = (rel is not None and base is not None and base >= rule["min_mean_us"] and len(means) >= th["min_days"]
                and rel > rule["mean_relative_per_day"] and rising_share(means) >= rule["min_rising"])
        out.append({"metric": name, "baseline_mean_us": base, "last_mean_us": means[-1],
                    "relative_per_day": round(rel, 4) if rel is not None else None,
                    "rising": round(rising_share(means), 2), "max_us": max(d["columns"][name]["max"] for d in days),
                    "flag": flag, "threshold": rule["mean_relative_per_day"], "reason": rule["reason"]})
    out.sort(key=lambda e: -(e["baseline_mean_us"] or 0))
    return out


def judge_restarts(run: dict, th: dict) -> list[dict]:
    """Flags from the restarts: anything unreachable, and what stays held or retained growing restart by restart."""
    rule, restarts, out = th["restarts"], run.get("restarts", []), []
    freed = restarts + ([run["exit"]] if run.get("exit", {}).get("leaks") else [])
    for k, r in enumerate(freed):
        leaks = r.get("leaks", {})
        where = f"restart at soak hour {r['soak_hour']}" if k < len(restarts) else "freeing the village at the end"
        if leaks.get("unreachable", 0) > rule["max_unreachable"]:
            out.append({"kind": "restart_leak", "metric": where,
                        "value": leaks["unreachable"], "threshold": rule["max_unreachable"],
                        "detail": leaks.get("unreachable_by_label"), "reason": rule["reason_unreachable"]})
    for metric, key in (("held objects", None), ("objects after restart", "objects"),
                        ("static KB after restart", "static_kb")):
        series = [r["leaks"]["held"] if key is None else r["after"][key] for r in restarts if "after" in r]
        limit = rule["held_per_restart"] if key is None else rule[f"{key}_per_restart"]
        if len(series) >= 3 and slope(series) >= limit and rising_share(series) >= rule["min_rising"]:
            out.append({"kind": "restart_growth", "metric": metric, "value": round(slope(series), 1),
                        "threshold": limit, "detail": series, "reason": rule["reason_growth"]})
    return out


def judge(run: dict, th: dict) -> dict:
    """Every test's verdicts and the flags they raise."""
    skip, min_days = th["skip_days"], th["min_days"]
    growth = [judge_growth(name, daily_floors(run, name), rule, skip, min_days) for name, rule in th["growth"].items()]
    machine = machine_by_day(run)
    drift = judge_drift(run, machine, th)
    systems = judge_systems(run, th)
    flags = [{"kind": "growth", **g} for g in growth if g["flag"]]
    flags += [{"kind": "drift", **d} for d in drift if d["flag"]]
    flags += [{"kind": "system_drift", **s} for s in systems if s["flag"]]
    flags += judge_restarts(run, th)
    flags += judge_errors(run, th)
    flags += judge_harness(run)
    return {"verdict": "flag" if flags else "pass", "flags": flags, "growth": growth, "drift": drift,
            "systems": systems, "machine": machine}


def judge_harness(run: dict) -> list[dict]:
    """The harness's own verdict: a run that stopped early, failed its in-run checks or exited non-zero is flagged,
    whatever this report's own tests found."""
    meta, out = run.get("meta", {}), []
    if meta.get("hours_run", 0) < meta.get("hours_asked", 1):
        out.append({"kind": "incomplete", "metric": "hours run", "value": meta.get("hours_run"),
                    "threshold": meta.get("hours_asked"), "reason": "the run stopped early"})
    if run.get("failures"):
        out.append({"kind": "harness_failure", "metric": "the harness's verdict", "value": len(run["failures"]),
                    "threshold": 0, "reason": "the harness failed the run itself (its in-run checks, or it could "
                    "not finish or write)", "detail": run["failures"][:4]})
    code = run.get("log", {}).get("exit", 0)
    if code:
        out.append({"kind": "exit", "metric": "exit code", "value": code, "threshold": 0,
                    "reason": "Godot exited non-zero"})
    return out


def judge_errors(run: dict, th: dict) -> list[dict]:
    """Errors the harness heard, script errors in the log and exit-time leak reports."""
    rule, out = th["errors"], []
    heard = run.get("errors", {}).get("errors", 0)
    log = run.get("log", {})
    logged = log.get("script_errors", 0) + log.get("errors", 0)
    if heard > rule["max_errors"] or logged > rule["max_errors"]:
        out.append({"kind": "errors", "metric": "errors", "value": max(heard, logged),
                    "threshold": rule["max_errors"], "reason": rule["reason"],
                    "detail": run.get("errors", {}).get("first_errors", []) + log.get("first_errors", [])})
    if log.get("exit_leaks"):
        out.append({"kind": "exit_leak", "metric": "exit report", "value": len(log["exit_leaks"]), "threshold": 0,
                    "reason": rule["reason_exit_leak"], "detail": log["exit_leaks"]})
    return out


def fmt(value, digits: int = 1) -> str:
    """A number for a table ('-' for none)."""
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def markdown(run: dict, verdict: dict, th: dict) -> str:
    """The report."""
    meta = run.get("meta", {})
    lines = [f"# Soak run: {meta.get('hours_run', 0) / 24:.1f} game days, {meta.get('residents_asked')} residents",
             "", f"**Verdict: {verdict['verdict'].upper()}** ({len(verdict['flags'])} flags). "
             f"Thresholds: `{th.get('_source', 'tools/soak_thresholds.json')}`; the first {th['skip_days']} day(s) are "
             "warm-up and are not judged.", ""]
    lines += flags_section(verdict) + meta_section(run) + growth_section(verdict) + drift_section(verdict)
    lines += days_section(run, verdict) + systems_section(verdict) + restarts_section(run) + errors_section(run)
    return "\n".join(lines) + "\n"


def flags_section(verdict: dict) -> list[str]:
    """The flags, each with its reason."""
    if not verdict["flags"]:
        return ["No flags.", ""]
    out = ["## Flags", ""]
    for f in verdict["flags"]:
        value = f.get("value", f.get("per_day", f.get("relative_per_day")))
        out.append(f"- **{f['kind']}** {f['metric']}: {fmt(value, 4)} (threshold {f['threshold']}). {f['reason']}"
                   + (f" Detail: {f['detail']}" if f.get("detail") else ""))
    return out + [""]


def meta_section(run: dict) -> list[str]:
    """What the run was."""
    m, mach = run.get("meta", {}), run.get("machine", {})
    loads = [s[1] for s in mach.get("samples", [])]
    load = f"{min(loads):.0f}-{max(loads):.0f} (mean {statistics.mean(loads):.0f}) on {mach.get('cpus')} CPUs" \
        if loads else "not sampled"
    return ["## The run", "", "| | |", "|---|---|",
            f"| Engine / build / display | {m.get('engine')} / {'debug' if m.get('debug_build') else 'release'} / "
            f"{m.get('display')} |",
            f"| Game hours asked / run | {m.get('hours_asked')} / {m.get('hours_run')} at {m.get('speed')}x, "
            f"{m.get('fps')} fixed frames a second |",
            f"| Restart every (game hours) | {m.get('restart_every_hours') or 'never'} |",
            f"| Pantry topped up / work-party orders | {m.get('stocked')} / {m.get('orders_given')} given, "
            f"{m.get('orders_refused')} refused |",
            f"| Frames (all / measured run / off 4x) | {m.get('frames')} / {m.get('frames_run')} / "
            f"{m.get('off_speed_frames')} |",
            f"| Pauses lifted (of them stalls) / 4x step-downs | {m.get('pauses_lifted')} ({m.get('stall_lifts')}) / "
            f"{m.get('fallbacks')} |",
            f"| Wall time | {m.get('wall_s')} s |", f"| Machine load (1 min) | {load} |", ""]


def growth_section(verdict: dict) -> list[str]:
    """The growth table."""
    out = ["## Growth (daily floors)", "", "| Metric | Days | First | Last | Net | Per day | Rising | Threshold | "
           "Flag |", "|---|---|---|---|---|---|---|---|---|"]
    for g in verdict["growth"]:
        out.append(f"| {g['metric']} | {g['days']} | {fmt(g['first'])} | {fmt(g['last'])} | {fmt(g['net'])} | "
                   f"{fmt(g['per_day'], 2)} | {fmt(g['rising'], 2)} | {g['threshold']} | "
                   f"{'**yes**' if g['flag'] else 'no'}{(' (' + g['note'] + ')') if g.get('note') else ''} |")
    return out + [""]


def drift_section(verdict: dict) -> list[str]:
    """The drift table."""
    out = ["## Frame-time drift", "", "| Metric | Days | Baseline | Per day (relative) | CPU per frame, per day | "
           "Threshold | Flag |", "|---|---|---|---|---|---|---|"]
    for d in verdict["drift"]:
        base = d.get("baseline_us", d.get("baseline_ms"))
        out.append(f"| {d['metric']} | {d['days']} | {fmt(base, 3)} | {fmt(d['relative_per_day'], 4)} | "
                   f"{fmt(d.get('cpu_relative_per_day'), 4)} | {d['threshold']} | "
                   f"{'**yes**' if d['flag'] else 'no'}{(' -- ' + d['note']) if d.get('note') else ''} |")
    return out + [""]


def days_section(run: dict, verdict: dict) -> list[str]:
    """One row a day."""
    cols = run.get("hour_columns", [])
    out = ["## Day by day", "", "| Day | Frames | Work p50 / p95 / p99 / max (ms) | CPU ms/frame | Load | Wall s | "
           "Static MB (floor) | Objects | Nodes | Resources | Orphans | RSS MB | Pauses | Errors |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    floors = {c: daily_floors(run, c) for c in ("static_kb", "objects", "nodes", "resources", "orphans") if c in cols}
    for k, day in enumerate(run.get("days", [])):
        w, m = day["columns"]["work_us"], verdict["machine"][k]
        f = {c: (v[k] if k < len(v) else None) for c, v in floors.items()}
        out.append(f"| {day['day']} | {day['frames']} | {w['p50'] / 1000:.1f} / {w['p95'] / 1000:.1f} / "
                   f"{w['p99'] / 1000:.1f} / {w['max'] / 1000:.0f} | {fmt(m['cpu_ms_per_frame'], 2)} | "
                   f"{fmt(m['load1'])} | {fmt(m['wall_s'], 0)} | "
                   f"{fmt(f.get('static_kb') / 1024 if f.get('static_kb') else None, 2)} | {fmt(f.get('objects'))} | "
                   f"{fmt(f.get('nodes'))} | {fmt(f.get('resources'))} | {fmt(f.get('orphans'))} | "
                   f"{fmt(m['rss_mb'])} | "
                   f"{day.get('pauses_lifted')} | {day.get('errors')} |")
    return out + [""]


def systems_section(verdict: dict, top: int = 14) -> list[str]:
    """The costliest systems' daily means and drift."""
    out = ["## Systems (daily mean frame time, costliest first)", "", "| System | First days (us) | Last day (us) | "
           "Per day (relative) | Rising | Max (ms) | Flag |", "|---|---|---|---|---|---|---|"]
    for s in verdict["systems"][:top]:
        out.append(f"| {s['metric']} | {fmt(s['baseline_mean_us'], 0)} | {s['last_mean_us']} | "
                   f"{fmt(s['relative_per_day'], 4)} | {s['rising']} | {s['max_us'] / 1000:.1f} | "
                   f"{'**yes**' if s['flag'] else 'no'} |")
    return out + [""]


def restarts_section(run: dict) -> list[str]:
    """One row a restart."""
    restarts = run.get("restarts", [])
    end = run.get("exit", {}).get("leaks")
    tail = [f"Freeing the village at the end: {end.get('watched')} watched, {end.get('unreachable')} unreachable "
            f"{end.get('unreachable_by_label') or ''}, {end.get('held')} held.", ""] if end else []
    if not restarts:
        return ["## Restarts", "", "None in this run.", ""] + tail
    out = ["## Restarts", "", "| Soak hour | Watched | Unreachable | Held | Objects before / after | "
           "Static MB before / after | Reopen (ms, frames) |", "|---|---|---|---|---|---|---|"]
    for r in restarts:
        lk, b, a = r.get("leaks", {}), r.get("before", {}), r.get("after", {})
        out.append(f"| {r['soak_hour']} | {lk.get('watched')} | {lk.get('unreachable')} "
                   f"{lk.get('unreachable_by_label') or ''} | {lk.get('held')} | {b.get('objects')} / "
                   f"{a.get('objects')} | {b.get('static_kb', 0) / 1024:.1f} / {a.get('static_kb', 0) / 1024:.1f} | "
                   f"{r.get('reopen_ms')}, {r.get('frames')} |")
    held = restarts[-1].get("leaks", {}).get("held_by_label", {})
    return out + ["", f"Held after the last restart (shared state and static caches): {held}", ""] + tail


def errors_section(run: dict) -> list[str]:
    """Errors and warnings."""
    e, log = run.get("errors", {}), run.get("log", {})
    out = ["## Errors and warnings", "", f"- Heard by the harness: {e.get('errors', '-')} errors, "
           f"{e.get('warnings', '-')} warnings.",
           f"- In the log: {log.get('script_errors', '-')} script errors, {log.get('errors', '-')} engine errors; "
           f"exit code {log.get('exit', '-')}; exit-time leak reports: {log.get('exit_leaks') or 'none'}"
           f" (sounds still playing at quit, not counted: {log.get('exit_audio', 0)})."]
    for line in (e.get("first_errors", []) + e.get("first_warnings", []))[:8]:
        out.append(f"  - `{line[:200]}`")
    if run.get("failures"):
        out.append(f"- The harness's own verdict: {run['failures']}")
    return out + [""]


def write(run: dict, th: dict, md_path: Path, json_path: Path) -> dict:
    """Judge `run`, write the markdown and the verdict JSON; returns the verdict."""
    verdict = judge(run, th)
    Path(md_path).write_text(markdown(run, verdict, th))
    small = {"verdict": verdict["verdict"], "flags": verdict["flags"], "meta": run.get("meta", {}),
             "growth": verdict["growth"], "drift": verdict["drift"]}
    Path(json_path).write_text(json.dumps(small, indent=1))
    return verdict


def main() -> int:
    """Judge one run."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("run", type=Path)
    parser.add_argument("--md", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--thresholds", type=Path, default=DEFAULT_THRESHOLDS)
    args = parser.parse_args()
    th = load_thresholds(args.thresholds)
    verdict = write(json.loads(args.run.read_text()), th, args.md, args.json)
    print(f"{verdict['verdict']}: {len(verdict['flags'])} flags")
    return 0 if verdict["verdict"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
