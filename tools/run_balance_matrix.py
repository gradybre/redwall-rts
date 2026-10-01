#!/usr/bin/env python3
"""Run the balance harness over seeds x policies, several at once (decision 0571).

    python3 tools/run_balance_matrix.py --out-dir <dir> [--seeds 1 2 3] [--policies hands_off light_touch] \
        [--days 48] [--jobs 3] [--godot godot]

Each run is one headless Godot process (godot/tools/balance/year_runner.gd) writing <dir>/<policy>_s<seed>_d<days>.json
and .csv, its log beside them. A run counts as done only when its log carries the harness's own
`BALANCE-RUN ok` line, its JSON exists and its log has no `SCRIPT ERROR` or `ERROR:` line -- a Godot exit status of 0
proves nothing here (docs/ENVIRONMENT.md). A run past --timeout wall-clock seconds is killed and counted failed.
Exits 1 when any run failed. Then: python3 tools/balance_report.py --out ... <dir>/*.json
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FPS = 30


def command(godot: str, seed: int, policy: str, days: int, out: Path) -> list[str]:
    """The Godot command line for one run."""
    return [godot, "--headless", "--path", str(REPO / "godot"), "--fixed-fps", str(FPS), "--script",
            "res://tools/balance/year_runner.gd", "--", "--seed", str(seed), "--policy", policy, "--days", str(days),
            "--fps", str(FPS), "--out", str(out.with_suffix(".json")), "--csv", str(out.with_suffix(".csv"))]


def run_all(jobs: list[tuple[int, str, int]], out_dir: Path, godot: str, parallel: int, timeout: float) -> list[str]:
    """Run every (seed, policy, days), at most `parallel` at once, each for at most `timeout` seconds; the failures."""
    pending = list(jobs)
    running: list[tuple[subprocess.Popen, Path, float, object]] = []
    failures: list[str] = []
    while pending or running:
        while pending and len(running) < parallel:
            seed, policy, days = pending.pop(0)
            stem = out_dir / f"{policy}_s{seed}_d{days}"
            stem.with_suffix(".json").unlink(missing_ok=True)
            log = open(stem.with_suffix(".log"), "w")
            proc = subprocess.Popen(command(godot, seed, policy, days, stem), stdout=log, stderr=subprocess.STDOUT,
                                    stdin=subprocess.DEVNULL)
            running.append((proc, stem, time.monotonic(), log))
            print(f"started {stem.name} (pid {proc.pid})", flush=True)
        for entry in list(running):
            proc, stem, began, log = entry
            if proc.poll() is None and time.monotonic() - began < timeout:
                continue
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            log.close()
            running.remove(entry)
            failures += check(stem, proc.returncode, time.monotonic() - began)
        time.sleep(2)
    return failures


def check(stem: Path, code: int, seconds: float) -> list[str]:
    """Whether a finished run really ran: its summary line and its JSON."""
    log = stem.with_suffix(".log").read_text(errors="replace")
    ok = [line for line in log.splitlines() if line.startswith("BALANCE-RUN ok")]
    errors = [line for line in log.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    if ok and not errors and stem.with_suffix(".json").exists():
        print(f"done {stem.name} in {seconds:.0f} s: {ok[-1]}", flush=True)
        return []
    errors += [line for line in log.splitlines() if "BALANCE-RUN error" in line]
    print(f"FAILED {stem.name} (exit {code}): {errors[:3]}", flush=True)
    return [f"{stem.name}: exit {code}; {errors[:3]}"]


def main(argv: list[str]) -> int:
    """Parse the matrix and run it."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3])
    parser.add_argument("--policies", nargs="+", default=["hands_off", "light_touch"])
    parser.add_argument("--days", type=int, default=48)
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout", type=float, default=3 * 3600, help="wall-clock seconds a run may take")
    args = parser.parse_args(argv)
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs = [(seed, policy, args.days) for policy in args.policies for seed in args.seeds]
    failures = run_all(jobs, out_dir, args.godot, max(1, args.jobs), args.timeout)
    for failure in failures:
        print(f"error: {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
