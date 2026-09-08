#!/usr/bin/env python3
"""Run the work benchmark as sequential, independent Godot processes.

The Godot script is intentionally outside the copied baseline project. `--path` selects the
project whose res:// files are preloaded, while --script may point at this absolute file. This
lets the baseline and modified project use byte-for-byte the same fixture and hash protocol.

Every invocation freezes the fixture into a temporary directory and records its SHA-256, hashes
every core source the fixture preloads, bounds each subprocess to 120 seconds, rejects a run
whose output contains a logged script error even at exit code 0, and rejects any group of
repetitions whose final state digests disagree.

TWO RUNNERS, ONE PROTOCOL. `--runner editor` is the invocation above. `--runner release` times
the SAME fixture source inside an exported release build produced by
`tools/export_benchmark_build.py`, because Godot 4.7.2's official export templates are built
with `disable_path_overrides=true` and reject `--path`, `--main-pack` and `-s/--script`
outright, so the editor invocation has no release equivalent. In release mode the driver
refuses to run at all unless that build's manifest shows (a) the packed fixture is byte-identical
to `--script-path`, (b) the packed core sources are byte-identical to the project's, and (c) the
paired assert probe proved `assert()` is compiled out of the binary being timed.

WHAT NEITHER RUNNER MEASURES. Neither is the REQ-SET-163 qualification-floor measurement
(Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080). Windows is deferred. `--runner editor`
additionally times a binary that does not ship, with `assert()` live. No figure from either
runner may be presented as satisfying REQ-SET-163.
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
    parser.add_argument("--summary-path", type=Path, default=None,
                        help="write the per-workload Markdown table for this run")
    parser.add_argument("--compare-path", type=Path, default=None,
                        help="an earlier driver JSON to place beside this one in the summary")
    parser.add_argument("--runner", choices=("editor", "release"), default="editor",
                        help="editor binary via --path/--script, or an exported release build")
    parser.add_argument("--release-manifest", type=Path, default=None,
                        help="the build manifest from tools/export_benchmark_build.py; "
                             "required by --runner release and verified before any timing")
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


def load_manifest(args: argparse.Namespace, fixture_sha256: str,
                  project_sources: dict) -> dict | None:
    """Load and verify the release build manifest, or return None in editor mode.

    Every check here is a refusal, not a warning. A release measurement is worth nothing unless
    the binary being timed provably contains this fixture, this core source, and no asserts.
    """
    if args.runner != "release":
        return None
    if args.release_manifest is None:
        raise SystemExit("--runner release requires --release-manifest")
    manifest = json.loads(args.release_manifest.read_text())
    if manifest.get("schema") != "redwall-benchmark-build-manifest-v1":
        raise SystemExit(f"unrecognised build manifest: {args.release_manifest}")
    sources = manifest["sources"]
    if sources["packed_fixture_sha256"] != fixture_sha256:
        raise SystemExit("the exported build packs a different fixture than --script-path")
    packed = {name: digest for name, digest in sources["core_source_hashes"].items()}
    if packed != {Path(name).name: digest for name, digest in project_sources.items()}:
        raise SystemExit("the exported build packs different core sources than --project-path")
    if not manifest["assert_probes"]["verdict"]["release_asserts_compiled_out"]:
        raise SystemExit("the exported build did not prove asserts are compiled out")
    executable = Path(manifest["build"]["executable"])
    if not executable.is_file():
        raise SystemExit(f"the manifest's executable is missing: {executable}")
    on_disk = hashlib.sha256(executable.read_bytes()).hexdigest()
    if on_disk != manifest["build"]["executable_sha256"]:
        raise SystemExit("the binary on disk is not the one the assert probe was run against")
    return manifest


def release_note(manifest: dict) -> str:
    """The one sentence a release run is entitled to say about what it measured."""
    verdict = manifest["assert_probes"]["verdict"]
    return (
        "Exported release build (template_release), asserts proven compiled out: the probe "
        f"evaluated {verdict['release_argument_evaluations']} assert conditions in this binary "
        f"against {verdict['editor_argument_evaluations']} in the editor control, and walked "
        "past a failing assert the editor control halted on. This is a release measurement on "
        "one machine. It is NOT the REQ-SET-163 qualification-floor measurement "
        "(Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred."
    )


EDITOR_NOTE = (
    "Editor binary, with assert() live. These figures compare configurations against each "
    "other on one machine. They are not a release measurement and not the REQ-SET-163 "
    "qualification-floor measurement."
)


def build_context(args: argparse.Namespace, manifest: dict | None) -> dict:
    """Record the machine and the build under test, and what that build cannot be used to claim.

    Collected once before any timed run, never between runs, so nothing here competes with a
    measurement for the machine.
    """
    templates = Path.home() / "Library/Application Support/Godot/export_templates"
    presets = args.project_path.resolve() / "export_presets.cfg"
    template_entries = sorted(p.name for p in templates.iterdir()) if templates.is_dir() else []
    release = manifest is not None
    return {
        "godot_version": probe([args.godot, "--version"]),
        "runner": args.runner,
        "godot_binary_kind": "template_release" if release else "editor",
        "godot_binary_note": ("an exported release build, running its own main loop"
                              if release else
                              "the editor binary, not an exported release build"),
        "release_manifest_path": str(args.release_manifest) if release else None,
        "release_executable": manifest["build"]["executable"] if release else None,
        "release_executable_sha256": manifest["build"]["executable_sha256"] if release else None,
        "assert_probe_verdict": manifest["assert_probes"]["verdict"] if release else None,
        "asserts_live_in_timed_binary": not release,
        "export_presets_path": str(presets),
        "export_presets_present": presets.is_file(),
        "export_templates_path": str(templates),
        "export_templates_present": templates.is_dir(),
        "export_templates_entries": template_entries,
        "is_release_measurement": release,
        "is_qualification_floor_measurement": False,
        "measurement_scope_note": release_note(manifest) if release else EDITOR_NOTE,
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


def launch_prefix(args: argparse.Namespace, manifest: dict | None) -> list[str]:
    """The part of the command line that selects the binary and the fixture inside it.

    Editor mode points the editor binary at the project and the frozen fixture. Release mode
    launches the exported build, which reaches the same fixture through its own main loop
    because the release template rejects `--path` and `--script`.
    """
    if manifest is None:
        return [args.godot, "--headless",
                "--path", str(args.project_path.resolve()),
                "--script", str(args.script_path.resolve())]
    return [manifest["build"]["executable"], "--headless"]


def run_one(args: argparse.Namespace, config: str, workload: str, population: int,
            repetition: int, result_dir: Path, manifest: dict | None) -> dict:
    """Run one benchmark subprocess and return its record, raising on any sign of trouble."""
    output_file = result_dir / f"{config}-{workload}-{population}-rep{repetition}.json"
    command = launch_prefix(args, manifest) + [
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


WORKLOAD_LABEL = {
    "bands": "mixed bands, solo jobs -- ordinary-play comparison",
    "uniform": "uniform, solo jobs -- synchronised XP/write burst",
    "party": "mixed bands, parties -- coordinator/member structure",
}
SUMMARY_WORKLOAD_ORDER = ("bands", "uniform", "party")


def index_runs(payload: dict) -> dict:
    """Map (config, workload, population) to the per-repetition benchmark dicts, in run order."""
    indexed: dict[tuple[str, str, int], list[dict]] = {}
    for record in payload.get("runs", []):
        key = (record["config"], record["workload"], record["population"])
        indexed.setdefault(key, []).append(record["benchmark"])
    return indexed


def series(entries: list[dict], key: str) -> list[int]:
    """Every repetition's value of one metric, in repetition order."""
    return [int(entry[key]) for entry in entries]


def mean_us(values: list[int]) -> float:
    """The arithmetic mean of the repetitions of one metric. Presentation only."""
    return sum(values) / len(values) if values else 0.0


def delta_percent(before: float, after: float) -> str:
    """The signed change from `before` to `after`, or an explicit dash when there is no before."""
    if before <= 0.0:
        return "-"
    return f"{100.0 * (after - before) / before:+.1f}%"


def summary_row(workload: str, entries: list[dict], prior: list[dict] | None) -> str:
    """One Markdown row: this workload's two repetitions, their mean, and any prior mean."""
    p99 = series(entries, "p99_us")
    pair = series(entries, "p95_pair_us")
    cells = [WORKLOAD_LABEL.get(workload, workload),
             "/".join(str(value) for value in p99), f"{mean_us(p99):.1f}",
             "/".join(str(value) for value in pair), f"{mean_us(pair):.1f}"]
    if prior is None:
        cells += ["-", "-", "-", "-"]
    else:
        prior_p99 = mean_us(series(prior, "p99_us"))
        prior_pair = mean_us(series(prior, "p95_pair_us"))
        cells += [f"{prior_p99:.1f}", delta_percent(prior_p99, mean_us(p99)),
                  f"{prior_pair:.1f}", delta_percent(prior_pair, mean_us(pair))]
    return "| " + " | ".join(cells) + " |"


def summary_table(payload: dict, prior: dict | None, config: str, population: int) -> list[str]:
    """The three-workload block for one config at one population. Never a combined score."""
    indexed = index_runs(payload)
    prior_indexed = index_runs(prior) if prior is not None else {}
    rows = [summary_row(workload, indexed[(config, workload, population)],
                        prior_indexed.get((config, workload, population)))
            for workload in SUMMARY_WORKLOAD_ORDER
            if indexed.get((config, workload, population))]
    if not rows:
        return []
    return [f"### `{config}` at population {population}", "",
            "| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean "
            "| prior p99 mean | p99 delta | prior pair mean | pair delta |",
            "|---|---|---|---|---|---|---|---|---|"] + rows + [""]


def summary_header(payload: dict, prior: dict | None) -> list[str]:
    """Protocol, provenance and the standing refusal to combine the three workloads."""
    lines = ["# Work benchmark -- three workloads, reported independently", "",
             "Decision 0024 section 3 forbids combining these into one weighted score without an",
             "explicitly defined workload distribution. No such distribution exists, so no",
             "combined figure is produced here.", "",
             f"- protocol: `{payload['hash_protocol']}`",
             f"- nearest rank, {payload['warmup_ticks']} warm-up ticks discarded, "
             f"{payload['sample_ticks']} sampled, {payload['repetitions']} independent processes "
             "per configuration",
             f"- fixture SHA-256: `{payload['fixture_sha256']}`",
             f"- subprocess bound: {payload['subprocess_timeout_seconds']} s",
             f"- started: {payload['started_utc']}",
             f"- runner: `{payload['build_context'].get('runner', 'editor')}` "
             f"({payload['build_context']['godot_binary_kind']}); asserts live in the timed "
             f"binary: {payload['build_context'].get('asserts_live_in_timed_binary')}",
             f"- build: {payload['build_context']['measurement_scope_note']}", ""]
    if prior is not None:
        lines += ["Prior columns come from a separate driver run:",
                  f"- prior runner: `{prior['build_context'].get('runner', 'editor')}` "
                  f"({prior['build_context']['godot_binary_kind']})",
                  f"- prior fixture SHA-256: `{prior['fixture_sha256']}`",
                  f"- prior started: {prior['started_utc']}",
                  "- prior and current fixtures are byte-identical: "
                  f"{prior['fixture_sha256'] == payload['fixture_sha256']}", ""]
    return lines


def summary_sources(payload: dict, prior: dict | None) -> list[str]:
    """The core sources each side timed, so a row names the code it measured."""
    lines = ["## Core sources timed", "", "| File | this run | prior run |", "|---|---|---|"]
    prior_hashes = prior.get("source_hashes", {}) if prior is not None else {}
    for name, digest in sorted(payload["source_hashes"].items()):
        lines.append(f"| `{name}` | `{digest[:16]}` | `{prior_hashes.get(name, '-')[:16]}` |")
    lines.append("")
    return lines


def summary_digests(payload: dict) -> list[str]:
    """Whether every repetition group agreed on its setup and final state digests."""
    lines = ["## Determinism digests", "",
             "| Config | Workload | Population | repetitions agree | final digest |",
             "|---|---|---|---|---|"]
    for item in payload["hash_comparisons"]:
        lines.append(f"| `{item['config']}` | {item['workload']} | {item['population']} "
                     f"| {item['hashes_identical']} | `{item['final_hashes'][0][:16]}` |")
    lines.append("")
    return lines


def write_summary(payload: dict, prior: dict | None, path: Path) -> None:
    """Write the per-config, per-workload Markdown tables for this driver run."""
    lines = summary_header(payload, prior)
    for config in payload["configs"]:
        for population in payload["populations"]:
            lines += summary_table(payload, prior, config, population)
    lines += summary_sources(payload, prior) + summary_digests(payload)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


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
    manifest = load_manifest(args, hashlib.sha256(fixture_bytes).hexdigest(), hashes)
    context = build_context(args, manifest)
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
                                       Path(temp), manifest))

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
    if args.summary_path is not None:
        prior = json.loads(args.compare_path.read_text()) if args.compare_path else None
        write_summary(payload, prior, args.summary_path)
    return 0


if __name__ == "__main__":
    main()
