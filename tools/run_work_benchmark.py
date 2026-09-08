#!/usr/bin/env python3
"""Run the work benchmark as sequential, independent Godot processes.

The Godot script is intentionally outside the copied baseline project. `--path` selects the
project whose res:// files are preloaded, while --script may point at this absolute file. This
lets the baseline and modified project use byte-for-byte the same fixture and hash protocol.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import hashlib
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time


CONFIGS = ("needs", "wu", "combined")
POPULATIONS = (12, 256)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-path", required=True, type=Path)
    parser.add_argument("--output-path", required=True, type=Path)
    parser.add_argument("--repetitions", type=int, default=2)
    parser.add_argument("--godot", default="godot")
    parser.add_argument(
        "--script-path", type=Path,
        default=Path(__file__).with_name("benchmark_work.gd"),
    )
    parser.add_argument("--warmup", type=int, default=300)
    parser.add_argument("--samples", type=int, default=3000)
    return parser.parse_args()


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def run_one(args: argparse.Namespace, config: str, population: int, repetition: int,
            result_dir: Path) -> dict:
    output_file = result_dir / f"{config}-{population}-rep{repetition}.json"
    command = [
        args.godot,
        "--headless",
        "--path", str(args.project_path.resolve()),
        "--script", str(args.script_path.resolve()),
        "--",
        "--config", config,
        "--population", str(population),
        "--warmup", str(args.warmup),
        "--samples", str(args.samples),
        "--output", str(output_file),
    ]
    started = time.monotonic()
    completed = subprocess.run(command, capture_output=True, text=True, check=False, timeout=120)
    wall_seconds = time.monotonic() - started
    record = {
        "config": config,
        "population": population,
        "repetition": repetition,
        "command": command,
        "wall_seconds": wall_seconds,
        "returncode": completed.returncode,
        "stdout_tail": completed.stdout[-4000:],
        "stderr_tail": completed.stderr[-4000:],
    }
    if output_file.exists():
        try:
            record["benchmark"] = json.loads(output_file.read_text())
        except json.JSONDecodeError as exc:
            record["parse_error"] = str(exc)
    if any(marker in completed.stdout + completed.stderr for marker in ("SCRIPT ERROR:", "Parse Error:", "USER SCRIPT ERROR:")):
        raise RuntimeError(f"Godot script error: {record}")
    if completed.returncode != 0:
        raise RuntimeError(f"benchmark failed for {config}/{population}/rep{repetition}: {record}")
    benchmark = record.get("benchmark")
    if not isinstance(benchmark, dict) or benchmark.get("schema") != "redwall-work-benchmark-v1":
        raise RuntimeError(f"benchmark output is missing or invalid: {record}")
    if benchmark.get("ok", True) is False:
        raise RuntimeError(f"benchmark reported failure: {record}")
    return record


def main() -> int:
    started_utc = utc_now()
    args = parse_args()
    if args.repetitions < 1:
        raise SystemExit("--repetitions must be at least 1")
    if args.warmup < 0 or args.samples < 2:
        raise SystemExit("--warmup must be >= 0 and --samples must be >= 2")
    project = args.project_path.resolve()
    script = args.script_path.resolve()
    if not project.exists():
        raise SystemExit(f"project path does not exist: {project}")
    if not script.is_file():
        raise SystemExit(f"benchmark script does not exist: {script}")
    fixture_bytes = script.read_bytes()
    source_hashes = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((project / "scripts/core").glob("*.gd"))}
    args.output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="redwall-work-bench-") as temp:
        frozen_script = Path(temp) / "benchmark_work.gd"
        frozen_script.write_bytes(fixture_bytes)
        args.script_path = frozen_script
        records: list[dict] = []
        for config in CONFIGS:
            for population in POPULATIONS:
                for repetition in range(1, args.repetitions + 1):
                    records.append(run_one(args, config, population, repetition, Path(temp)))

    groups: dict[tuple[str, int], list[dict]] = {}
    for record in records:
        key = (record["config"], record["population"])
        groups.setdefault(key, []).append(record)
    comparisons = []
    for (config, population), group in groups.items():
        hashes = [record["benchmark"]["final_hash_sha256"] for record in group]
        comparisons.append({
            "config": config,
            "population": population,
            "final_hashes": hashes,
            "hashes_identical": len(set(hashes)) == 1,
        })
    if not all(item["hashes_identical"] for item in comparisons):
        raise RuntimeError(f"independent repetitions disagreed: {comparisons}")

    payload = {
        "schema": "redwall-work-benchmark-driver-v1",
        "ok": True,
        "started_utc": started_utc,
        "project_path": str(project),
        "script_path": str(script),
        "fixture_sha256": hashlib.sha256(fixture_bytes).hexdigest(),
        "source_hashes": source_hashes,
        "godot": args.godot,
        "python": sys.version,
        "platform": platform.platform(),
        "repetitions": args.repetitions,
        "warmup_ticks": args.warmup,
        "sample_ticks": args.samples,
        "configs": list(CONFIGS),
        "populations": list(POPULATIONS),
        "hash_protocol": "redwall-work-benchmark-v1/sha256/utf8-canonical-lines",
        "hash_comparisons": comparisons,
        "runs": records,
        "finished_utc": utc_now(),
    }
    args.output_path.write_text(json.dumps(payload, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    main()
