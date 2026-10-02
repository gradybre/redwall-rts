#!/usr/bin/env python3
"""Run the live demo's soak test and judge it (decision 0921; docs/performance/2026-10-01-soak-test.md).

The run is godot/tools/soak/soak_test.gd in its own process: the real demo village at 4x for many game days, sampled
every game hour. This script starts it, samples the MACHINE beside it every few seconds -- the load average, and the
Godot process's resident memory and CPU time (`ps`) -- because the machine is shared and a slower day may be load
rather than the game, then folds those samples and the log's error lines into the run's JSON and writes the report
(tools/soak_report.py): markdown plus a small verdict JSON.

    python3 tools/soak_test.py --out-dir <dir> [--days 20] [--residents 9] [--restart-every-hours 0] [--tag soak]
    python3 tools/soak_test.py --out-dir <dir> --report-only --tag soak     # re-judge a run already in <dir>

Writes <dir>/<tag>.json (the run), <tag>.log, <tag>.md and <tag>.verdict.json. Exits 0 when the run finished and the
report raised no flag, 1 otherwise. Godot is the `godot` on PATH (docs/ENVIRONMENT.md); paths given to it are absolute.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import soak_report  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
HARNESS = "res://tools/soak/soak_test.gd"
SAMPLE_S = 5.0
# The engine's exit-time report of leaked resources and objects (decision 0561 found one): its summary line, and under
# --verbose (which the runner passes) one line per object or resource.
# The engine's singular for one object, "1 ObjectDB instance was leaked at exit", counts too (decision 0998, P1).
EXIT_SUMMARY = re.compile(r"resources still in use at exit|ObjectDB instances? ((were|was) )?leaked at exit")
EXIT_ITEM = re.compile(r"^(Leaked instance: (?P<cls>\w+):|Resource still in use: (?P<path>\S+) \((?P<rcls>\w+)\))")
# A sound still playing as the process quits leaves its stream and playback to the exit report (decision 0921 §7):
# the audio server lets them go on a mix that headless never runs. Not a leak of the village's.
AUDIO_CLASSES = {"AudioStreamOggVorbis", "AudioStreamWAV", "AudioStreamMP3", "OggPacketSequence",
                 "OggPacketSequencePlayback", "AudioStreamPlaybackOggVorbis", "AudioStreamPlaybackWAV",
                 "AudioStreamPlaybackMP3"}


def cpu_seconds(text: str) -> float:
    """`ps -o time=` as seconds: [[dd-]hh:]mm:ss[.cc]."""
    days = 0
    if "-" in text:
        head, text = text.split("-", 1)
        days = int(head)
    parts = [float(p) for p in text.strip().split(":")]
    seconds = 0.0
    for part in parts:
        seconds = seconds * 60 + part
    return days * 86400 + seconds


def sample(pid: int) -> list | None:
    """[unix, load 1 min, load 5 min, rss KB, cpu s] for `pid` now (None once it has gone)."""
    try:
        out = subprocess.run(["ps", "-o", "rss=,time=", "-p", str(pid)], capture_output=True, text=True,
                             timeout=10).stdout.split()
    except subprocess.TimeoutExpired:
        return None
    if len(out) < 2:
        return None
    load = os.getloadavg()
    return [round(time.time(), 1), round(load[0], 2), round(load[1], 2), int(out[0]), round(cpu_seconds(out[1]), 2)]


def godot_args(args: argparse.Namespace, json_path: Path) -> list[str]:
    """The harness's command line."""
    out = [args.godot, "--headless", "--verbose", "--fixed-fps", str(args.fps), "--path", str(REPO / "godot"), "--script", HARNESS,
           "--", "--residents", str(args.residents), "--fps", str(args.fps), "--out", str(json_path),
           "--restart-every-hours", str(args.restart_every_hours), "--growth-skip-hours", str(args.growth_skip_hours)]
    out += ["--hours", str(args.hours)] if args.hours else ["--days", str(args.days)]
    if args.no_stock:
        out.append("--no-stock")
    if args.no_order:
        out.append("--no-order")
    return out


def run(args: argparse.Namespace, out: Path) -> dict:
    """One harness run with the machine sampled beside it; returns the run's JSON with `machine` and `log` added."""
    json_path, log_path = out / f"{args.tag}.json", out / f"{args.tag}.log"
    json_path.unlink(missing_ok=True)
    samples = []
    started = time.time()
    with open(log_path, "w") as log:
        proc = subprocess.Popen(godot_args(args, json_path), stdout=log, stderr=subprocess.STDOUT)
        while proc.poll() is None:
            row = sample(proc.pid)
            if row:
                samples.append(row)
            try:
                proc.wait(timeout=SAMPLE_S)
            except subprocess.TimeoutExpired:
                pass
    result = json.loads(json_path.read_text()) if json_path.exists() else {"failures": ["no JSON written"]}
    result["machine"] = {"samples": samples, "sample_columns": ["unix", "load1", "load5", "rss_kb", "cpu_s"],
                         "cpus": os.cpu_count(), "wall_s": round(time.time() - started, 1)}
    result["log"] = scan_log(log_path, proc.returncode)
    json_path.write_text(json.dumps(result, indent=1))
    return result


def scan_log(path: Path, code: int) -> dict:
    """The log's error lines, counted (the harness counts what it heard; this also sees the exit-time report)."""
    lines = path.read_text(errors="replace").splitlines()
    return {"exit": code, **scan_lines(lines)}


def scan_lines(lines: list[str]) -> dict:
    """Script errors, engine errors (not the exit report's own summary line) and the exit report's items, the sounds
    still playing apart (AUDIO_CLASSES)."""
    script = [line for line in lines if "SCRIPT ERROR" in line]
    errors = [line for line in lines if line.startswith("ERROR:") and not EXIT_SUMMARY.search(line)]
    summaries = [line for line in lines if EXIT_SUMMARY.search(line)]
    items, audio = [], 0
    for line in lines:
        match = EXIT_ITEM.match(line)
        if match:
            cls = match.group("cls") or match.group("rcls")
            if cls in AUDIO_CLASSES:
                audio += 1
            else:
                items.append(line)
    # Without --verbose there are no items: then the summary itself is the report.
    leaks = items if items or audio else summaries
    return {"script_errors": len(script), "errors": len(errors), "exit_leaks": leaks[:8], "exit_audio": audio,
            "exit_summaries": summaries[:2], "first_errors": (script + errors)[:8]}


def main() -> int:
    """Run (or re-read) and report."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--tag", default="soak")
    parser.add_argument("--days", type=int, default=20)
    parser.add_argument("--hours", type=int, default=0, help="game hours instead of --days")
    parser.add_argument("--residents", type=int, default=9)
    parser.add_argument("--restart-every-hours", type=int, default=0)
    parser.add_argument("--growth-skip-hours", type=int, default=24)
    parser.add_argument("--fps", type=int, default=60)
    parser.add_argument("--no-stock", action="store_true")
    parser.add_argument("--no-order", action="store_true")
    parser.add_argument("--thresholds", type=Path, default=soak_report.DEFAULT_THRESHOLDS)
    parser.add_argument("--report-only", action="store_true")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.report_only:
        result = json.loads((out / f"{args.tag}.json").read_text())
    else:
        print(f"soak: {args.tag} running ...", file=sys.stderr, flush=True)
        result = run(args, out)
    verdict = soak_report.write(result, soak_report.load_thresholds(args.thresholds), out / f"{args.tag}.md",
                                out / f"{args.tag}.verdict.json")
    print(f"soak: {args.tag} {verdict['verdict']} ({len(verdict['flags'])} flags); see {out / (args.tag + '.md')}")
    return 0 if verdict["verdict"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
