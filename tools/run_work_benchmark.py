#!/usr/bin/env python3
"""Run the work benchmark as sequential, independent Godot processes.

The Godot script is intentionally outside the copied baseline project. `--path` selects the
project whose res:// files are preloaded, while --script may point at this absolute file. This
lets the baseline and modified project use byte-for-byte the same fixture and hash protocol.

Every invocation freezes the fixture into a temporary directory and records its SHA-256, hashes
every core source the fixture preloads, bounds each subprocess to 120 seconds, rejects a run
whose output contains a logged script error even at exit code 0, and rejects any group of
repetitions whose final state digests disagree.

WHAT THIS DRIVER DOES NOT MEASURE. The Godot binary used here is the EDITOR binary. There are
no export presets in the project and the export-template directory is empty, both of which are
recorded in `build_context`. These numbers are therefore not a release measurement and not the
REQ-SET-163 qualification-floor measurement; they compare configurations against each other on
one machine and nothing more.
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


CONFIGS = ("needs", "wu", "combined", "loop", "pid", "xp", "result", "factor", "gate",
           "party_fast", "party_finish")
WORKLOADS = ("uniform", "bands", "party")
PARTY_ONLY_CONFIGS = ("party_fast", "party_finish")
POPULATIONS = (12, 256)
SUBPROCESS_TIMEOUT_SECONDS = 120
ERROR_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "USER SCRIPT ERROR:")


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
    parser.add_argument("--configs", nargs="+", default=list(CONFIGS), choices=list(CONFIGS))
    parser.add_argument("--workloads", nargs="+", default=list(WORKLOADS), choices=list(WORKLOADS))
    parser.add_argument("--populations", nargs="+", type=int, default=list(POPULATIONS),
                        choices=list(POPULATIONS))
    return parser.parse_args()


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def run_plan(configs, workloads, populations) -> list[tuple[str, str, int]]:
    """Every (config, workload, population) triple to measure, in a fixed order.

    `party_fast` and `party_finish` exist only to compare decision 0017's two acceptance paths
    against each other, so they are paired with the party workload alone.
    """
    plan = []
    for config in configs:
        for workload in workloads:
            if config in PARTY_ONLY_CONFIGS and workload != "party":
                continue
            for population in populations:
                plan.append((config, workload, population))
    return plan


def probe(command: list[str]) -> dict:
    """Run one short informational command and record its result, or why it could not run."""
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False,
                                   timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        return {"command": command, "error": str(exc)}
    return {
        "command": command,
        "returncode": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def build_context(args: argparse.Namespace) -> dict:
    """Record the machine and the build under test, and what that build cannot be used to claim.

    Collected once before any timed run, never between runs, so nothing here competes with a
    measurement for the machine.
    """
    templates = Path.home() / "Library/Application Support/Godot/export_templates"
    presets = args.project_path.resolve() / "export_presets.cfg"
    template_entries = sorted(p.name for p in templates.iterdir()) if templates.is_dir() else []
    return {
        "godot_version": probe([args.godot, "--version"]),
        "godot_binary_kind": "editor",
        "godot_binary_note": "the editor binary, not an exported release build",
        "export_presets_path": str(presets),
        "export_presets_present": presets.is_file(),
        "export_templates_path": str(templates),
        "export_templates_present": templates.is_dir(),
        "export_templates_entries": template_entries,
        "is_release_measurement": False,
        "is_qualification_floor_measurement": False,
        "measurement_scope_note": (
            "Editor binary, no export presets, empty export-template directory. These figures "
            "compare configurations against each other on one machine. They are not a release "
            "measurement and not the REQ-SET-163 qualification-floor measurement."
        ),
        "machine": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "processor": probe(["sysctl", "-n", "machdep.cpu.brand_string"]),
            "logical_cores": probe(["sysctl", "-n", "hw.logicalcpu"]),
            "physical_cores": probe(["sysctl", "-n", "hw.physicalcpu"]),
            "memory_bytes": probe(["sysctl", "-n", "hw.memsize"]),
            "os_version": probe(["sw_vers"]),
        },
    }


def run_one(args: argparse.Namespace, config: str, workload: str, population: int,
            repetition: int, result_dir: Path) -> dict:
    """Run one benchmark subprocess and return its record, raising on any sign of trouble."""
    output_file = result_dir / f"{config}-{workload}-{population}-rep{repetition}.json"
    command = [
        args.godot,
        "--headless",
        "--path", str(args.project_path.resolve()),
        "--script", str(args.script_path.resolve()),
        "--",
        "--config", config,
        "--workload", workload,
        "--population", str(population),
        "--warmup", str(args.warmup),
        "--samples", str(args.samples),
        "--output", str(output_file),
    ]
    started = time.monotonic()
    completed = subprocess.run(command, capture_output=True, text=True, check=False,
                               timeout=SUBPROCESS_TIMEOUT_SECONDS)
    wall_seconds = time.monotonic() - started
    record = {
        "config": config,
        "workload": workload,
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
    verify_record(record, completed)
    return record


def verify_record(record: dict, completed: subprocess.CompletedProcess) -> None:
    """Reject a run that logged a script error, exited nonzero, or produced no valid result."""
    if any(marker in completed.stdout + completed.stderr for marker in ERROR_MARKERS):
        raise RuntimeError(f"Godot script error: {record}")
    if completed.returncode != 0:
        raise RuntimeError(f"benchmark failed: {record}")
    benchmark = record.get("benchmark")
    if not isinstance(benchmark, dict) or benchmark.get("schema") != "redwall-work-benchmark-v1":
        raise RuntimeError(f"benchmark output is missing or invalid: {record}")
    if benchmark.get("ok", True) is False:
        raise RuntimeError(f"benchmark reported failure: {record}")
    for key in ("config", "workload", "population"):
        if benchmark.get(key) != record[key]:
            raise RuntimeError(f"benchmark answered for the wrong {key}: {record}")


def compare_hashes(records: list[dict]) -> list[dict]:
    """Group repetitions and report whether each group's setup and final digests agree."""
    groups: dict[tuple[str, str, int], list[dict]] = {}
    for record in records:
        key = (record["config"], record["workload"], record["population"])
        groups.setdefault(key, []).append(record)
    comparisons = []
    for (config, workload, population), group in groups.items():
        setup = [record["benchmark"]["setup_hash_sha256"] for record in group]
        final = [record["benchmark"]["final_hash_sha256"] for record in group]
        comparisons.append({
            "config": config,
            "workload": workload,
            "population": population,
            "setup_hashes": setup,
            "final_hashes": final,
            "hashes_identical": len(set(setup)) == 1 and len(set(final)) == 1,
        })
    return comparisons


def source_hashes(project: Path) -> dict:
    """SHA-256 of every core script the fixture preloads, so a result names the code it timed."""
    return {
        str(path.relative_to(project)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted((project / "scripts/core").glob("*.gd"))
    }


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
    hashes = source_hashes(project)
    context = build_context(args)
    plan = run_plan(args.configs, args.workloads, args.populations)
    args.output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="redwall-work-bench-") as temp:
        frozen_script = Path(temp) / "benchmark_work.gd"
        frozen_script.write_bytes(fixture_bytes)
        args.script_path = frozen_script
        records: list[dict] = []
        for config, workload, population in plan:
            for repetition in range(1, args.repetitions + 1):
                records.append(run_one(args, config, workload, population, repetition,
                                       Path(temp)))

    comparisons = compare_hashes(records)
    if not all(item["hashes_identical"] for item in comparisons):
        raise RuntimeError(f"independent repetitions disagreed: {comparisons}")

    payload = {
        "schema": "redwall-work-benchmark-driver-v2",
        "ok": True,
        "started_utc": started_utc,
        "project_path": str(project),
        "script_path": str(script),
        "fixture_sha256": hashlib.sha256(fixture_bytes).hexdigest(),
        "source_hashes": hashes,
        "godot": args.godot,
        "python": sys.version,
        "platform": platform.platform(),
        "build_context": context,
        "repetitions": args.repetitions,
        "warmup_ticks": args.warmup,
        "sample_ticks": args.samples,
        "subprocess_timeout_seconds": SUBPROCESS_TIMEOUT_SECONDS,
        "configs": list(args.configs),
        "workloads": list(args.workloads),
        "populations": list(args.populations),
        "run_plan": [list(item) for item in plan],
        "hash_protocol": "redwall-work-benchmark-v1/sha256/utf8-canonical-lines",
        "hash_comparisons": comparisons,
        "runs": records,
        "finished_utc": utc_now(),
    }
    args.output_path.write_text(json.dumps(payload, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    main()
