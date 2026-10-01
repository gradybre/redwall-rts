#!/usr/bin/env python3
"""Run the live demo's scale test over a matrix of resident counts and tabulate it (decision 0561).

Each run is godot/tools/scale_test/scale_test.gd in its own process: the real demo village with N residents, a plan of
game hours at 1x and 4x through breakfast, supper and bed, every frame's cost per system. This script runs them, keeps
each run's JSON (and optionally CSV) and log, and prints markdown tables -- the ones in
docs/performance/2026-10-01-scale-test.md.

    python3 tools/scale_test.py --out <dir> [--residents 9 25 50 100 256] [--windowed] [--plan full|short]
    python3 tools/scale_test.py --out <dir> --tables-only      # re-tabulate runs already in <dir>

WHY --fixed-fps 60: the harness runs the engine uncapped while each frame hands the village a 60 Hz frame's demo time,
so a frame's real duration is its work (see the harness's FRAMES). Godot is the `godot` on PATH (docs/ENVIRONMENT.md).
Paths given to Godot are absolute: it runs with its working directory in godot/.
"""
from __future__ import annotations

import argparse
import json
import os
import resource
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HARNESS = "res://tools/scale_test/scale_test.gd"
DEFAULT_RESIDENTS = [9, 25, 50, 100, 256]
TIMEOUT_S = 3600
PHASES = ["1x_breakfast", "order", "4x_day", "1x_supper", "4x_evening", "1x_dusk"]
BURSTS = ["breakfast_call_0700", "supper_call_1700", "bed_at_dusk_2000"]
SYSTEMS = [
    ("sys.cast", "cast total (all below to nav)"),
    ("cast.brains", "brains (incl. their route plans)"),
    ("cast.route_spend", "route plans charged to the frame's window (all callers)"),
    ("cast.actor_draw", "actors' drawing (transforms, clips)"),
    ("cast.route_serve", "routing desk: serving waiters (their plans)"),
    ("cast.nav_builds", "nav rebuild slices"),
    ("cast.window_tail", "route previews (window tail)"),
    ("sys.work_board", "work board"),
    ("sys.kitchen", "kitchen"),
    ("sys.tunnels_and_night", "tunnels + night routine"),
    ("sys.people", "people and affinity"),
    ("sys.songs", "songs"),
    ("sys.sound", "sound"),
    ("sys.overlays", "overlays"),
    ("sys.ui", "UI"),
    ("sys.farm", "farm"),
    ("sys.woods", "woods"),
    ("sys.waterplay", "waterplay"),
    ("sys.fishery", "fishery"),
    ("sys.water", "water"),
    ("sys.camera", "camera"),
    ("sys.route_previews", "route previews (node)"),
    ("sys.settlement_clock", "settlement clock (GameManager)"),
    ("sys.demo_other", "village node (HUD sync etc.)"),
    ("sys.presentation", "presentation"),
    ("sys.other", "other scripts"),
]


def run_one(godot: str, residents: int, out: Path, windowed: bool, plan: str, csv: bool) -> dict:
    """One harness run; returns its JSON report (or a stub with the failure)."""
    tag = f"{'win' if windowed else 'hl'}_{residents}"
    args = [godot]
    if not windowed:
        args.append("--headless")
    args += ["--fixed-fps", "60", "--path", str(REPO / "godot"), "--script", HARNESS, "--",
             "--residents", str(residents), "--plan", plan, "--out", str(out / f"{tag}.json")]
    if csv:
        args += ["--csv", str(out / f"{tag}.csv")]
    path = out / f"{tag}.json"
    path.unlink(missing_ok=True)
    (out / f"{tag}.csv").unlink(missing_ok=True)
    started = time.time()
    load_before = os.getloadavg()[0]
    usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    with open(out / f"{tag}.log", "w") as log:
        try:
            code = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT, timeout=TIMEOUT_S).returncode
        except subprocess.TimeoutExpired:
            code = -1
    wall = time.time() - started
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu = (usage.ru_utime - usage_before.ru_utime) + (usage.ru_stime - usage_before.ru_stime)
    if not path.exists():
        return {"residents": residents, "failed": f"exit {code}, no report (see {tag}.log)", "wall_s": wall}
    report = json.loads(path.read_text())
    report["exit"] = code
    report["script_errors"] = sum(1 for line in (out / f"{tag}.log").read_text(errors="replace").splitlines()
                                  if "SCRIPT ERROR" in line)
    report["wall_s"] = round(wall, 1)
    report["load_avg_1m"] = [round(load_before, 1), round(os.getloadavg()[0], 1)]
    report["cpu_s"] = round(cpu, 1)
    path.write_text(json.dumps(report, indent=1))
    return report


def ms(us: int) -> str:
    """Microseconds as milliseconds, one decimal."""
    return f"{us / 1000:.1f}"


def frame_table(reports: list[dict]) -> str:
    """Frame work p50/p95/p99/max per N and phase."""
    lines = ["| N | phase | frames | work p50 | p95 | p99 | max (ms) | scripts mean | engine+render mean | at speed |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for r in reports:
        for phase in PHASES:
            sec = r.get("phases", {}).get(phase)
            if not sec:
                continue
            w = sec["work_us"]
            ran = r["phase_speeds"][[row[0] for row in r["plan"]].index(phase)]
            lines.append(f"| {r['residents']} | {phase} | {sec['frames']} | {ms(w['p50'])} | {ms(w['p95'])} | "
                         f"{ms(w['p99'])} | {ms(w['max'])} | {ms(sec['scripts_us']['mean'])} | "
                         f"{ms(sec['engine_us']['mean'])} | {speeds(ran)} |")
    return "\n".join(lines)


def speeds(counts: dict) -> str:
    """'1x' or '4x 90% / 2x 10%' from a frames-per-speed map."""
    total = sum(counts.values()) or 1
    parts = sorted(counts.items(), key=lambda kv: -kv[1])
    return " / ".join(f"{'paused' if k == '0' else k + 'x'} {100 * v // total}%" for k, v in parts)


def system_table(reports: list[dict], phase: str, stat: str) -> str:
    """Per-system `stat` (mean or p95) per N in one phase, ms."""
    head = "| system | " + " | ".join(f"N={r['residents']}" for r in reports) + " |"
    lines = [head, "|---|" + "---|" * len(reports)]
    for key, label in SYSTEMS:
        row = []
        for r in reports:
            v = r.get("phases", {}).get(phase, {}).get("systems", {}).get(key)
            row.append(f"{v[stat] / 1000:.2f}" if v else "-")
        lines.append(f"| {label} | " + " | ".join(row) + " |")
    return "\n".join(lines)


def burst_table(reports: list[dict]) -> str:
    """The meal calls and bed time: frame work and the top systems' max in the burst window."""
    lines = ["| N | burst | frames | work p95 | p99 | max (ms) | worst system (max ms) | route waiting max |",
             "|---|---|---|---|---|---|---|---|"]
    for r in reports:
        for burst in BURSTS:
            sec = r.get("bursts", {}).get(burst)
            if not sec or not sec["frames"]:
                continue
            w = sec["work_us"]
            worst = max(sec["systems"].items(), key=lambda kv: kv[1]["max"] if kv[0] not in ("cast.route_spend", "sys.cast") else 0)
            lines.append(f"| {r['residents']} | {burst} | {sec['frames']} | {ms(w['p95'])} | {ms(w['p99'])} | "
                         f"{ms(w['max'])} | {worst[0]} {ms(worst[1]['max'])} | {sec['route_waiting']['max']} |")
    return "\n".join(lines)


def route_table(reports: list[dict]) -> str:
    """The group order and residents' waits for a route, in 60 Hz virtual time."""
    lines = ["| N | party | whole-village order call (ms) | party order call (ms) | party served after (frames / virtual ms) "
             "| most waiting | wait p50 / p95 / max at 1x (virtual ms) | at 4x |", "|---|---|---|---|---|---|---|---|"]
    for r in reports:
        o = r.get("order", {})
        waits = []
        for phase in ("1x_breakfast", "4x_day"):
            w = r.get("phases", {}).get(phase, {}).get("route_wait_us")
            waits.append(f"{ms(w['p50'])} / {ms(w['p95'])} / {ms(w['max'])} (n={w['n']})" if w else "-")
        every = o.get("everyone") or {}
        party = f"{o.get('members', '-')}{'' if o.get('ok') else ' REFUSED'}"
        whole = f"{ms(every['call_us'])} ({'ok' if every['ok'] else 'refused'})" if every else "-"
        lines.append(f"| {r['residents']} | {party} | {whole} | {ms(o.get('call_us', 0))} | {o.get('served_frames', '-')} / "
                     f"{o.get('served_virtual_ms', '-')} | {o.get('max_waiting', '-')} | {waits[0]} | {waits[1]} |")
    return "\n".join(lines)


def plans_table(reports: list[dict]) -> str:
    """Route plans charged to residents over the whole run, by what each was doing, and how the village fared."""
    lines = ["| N | off-POI starts | plans by kind: count / total ms / mean ms / max ms | meals: ate (breakfast, supper) "
             "| went without | bedless at dusk |", "|---|---|---|---|---|---|"]
    for r in reports:
        kinds = sorted((r.get("plans_by_kind") or {}).items(), key=lambda kv: -kv[1][1])
        text = "; ".join(f"{k} {v[0]} / {v[1] / 1000:.0f} / {v[1] / 1000 / max(v[0], 1):.1f} / {v[2] / 1000:.0f}"
                         for k, v in kinds) or "-"
        b = r.get("behaviour") or {}
        lines.append(f"| {r['residents']} | {r.get('off_poi_starts', '-')} | {text} | {b.get('meal_ate', '-')} | "
                     f"{b.get('meal_without', '-')} | {b.get('bedless', '-')} |")
    return "\n".join(lines)


def memory_table(reports: list[dict]) -> str:
    """Static memory, nodes, objects, video memory and draw calls at the end of each run."""
    lines = ["| N | static MB (end) | nodes | objects | video MB | draw calls (max) | run wall (s) | process CPU (s) | "
             "stalls lifted | 4x fallbacks | machine load (1 min, before/after) |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in reports:
        m = r.get("memory", {})
        if not m:
            continue
        lines.append(f"| {r['residents']} | {m['static_kb']['last'] / 1024:.0f} | {m['nodes']['last']} | "
                     f"{m['objects']['last']} | {m['video_kb']['last'] / 1024:.0f} | {m['draw_calls']['max']} | "
                     f"{r.get('wall_s', '-')} | {r.get('cpu_s', '-')} | {r.get('unasked_pauses', '-')} | "
                     f"{r.get('fallbacks', '-')} | "
                     f"{r.get('load_avg_1m', '-')} |")
    return "\n".join(lines)


def tables(reports: list[dict]) -> str:
    """Every table, markdown."""
    ok = [r for r in reports if "failed" not in r]
    out = ["## Frame work (ms)", frame_table(ok)]
    for phase in ("1x_breakfast", "4x_day", "1x_supper", "1x_dusk"):
        out += [f"## Per system, {phase}: mean ms a frame", system_table(ok, phase, "mean"),
                f"## Per system, {phase}: p99 ms", system_table(ok, phase, "p99")]
    out += ["## Bursts", burst_table(ok), "## Routing", route_table(ok), "## Plans and outcomes", plans_table(ok), "## Memory", memory_table(ok)]
    for r in reports:
        if "failed" in r:
            out.append(f"- N={r['residents']}: FAILED {r['failed']}")
        elif r.get("errors") or r.get("exit", 0) != 0 or r.get("script_errors"):
            out.append(f"- N={r['residents']}: exit {r.get('exit')}, errors {r.get('errors')}, "
                       f"script errors in the log {r.get('script_errors')}")
    return "\n\n".join(out)


def main() -> int:
    """Run the matrix (or re-read it) and print the tables."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--residents", type=int, nargs="+", default=DEFAULT_RESIDENTS)
    parser.add_argument("--windowed", action="store_true")
    parser.add_argument("--plan", default="full", choices=["full", "short"])
    parser.add_argument("--csv", action="store_true")
    parser.add_argument("--tables-only", action="store_true")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    tag = "win" if args.windowed else "hl"
    reports = []
    for n in args.residents:
        path = out / f"{tag}_{n}.json"
        if args.tables_only:
            reports.append(json.loads(path.read_text()) if path.exists() else {"residents": n, "failed": "no report"})
            continue
        print(f"running N={n} ({'windowed' if args.windowed else 'headless'}) ...", file=sys.stderr, flush=True)
        report = run_one(args.godot, n, out, args.windowed, args.plan, args.csv)
        print(f"  done in {report.get('wall_s')} s", file=sys.stderr, flush=True)
        reports.append(report)
    text = tables(reports)
    (out / f"tables_{tag}.md").write_text(text + "\n")
    print(text)
    return 0 if all("failed" not in r and not r.get("errors") and r.get("exit", 0) == 0
                    and not r.get("script_errors") for r in reports) else 1


if __name__ == "__main__":
    sys.exit(main())
