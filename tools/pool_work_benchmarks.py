#!/usr/bin/env python3
"""Pool many work-benchmark driver runs per side and say whether a difference beats drift.

WHY THIS EXISTS. `tools/compare_work_benchmarks.py` places exactly two driver JSONs side by
side, which is the right shape when the effect under test is large. It is the wrong shape when
the effect is the same size as the machine's drift: two blocked runs of two repetitions each
gave `wu` deltas from +3.5% to -5.1% on this machine while the unmodified `needs` control moved
+5.4%, so the sign of the answer depended on which block ran first. This driver takes an
ARBITRARY NUMBER of driver JSONs per side, expects them to have been run INTERLEAVED, pools
every repetition, and reports a two-sided permutation test on the difference of medians.

WHAT IT REFUSES, MATCHING THE DRIVER IT READS FROM.
  * any pooled run whose repetitions disagreed on their setup or final state digest;
  * any pooled run that is not a `redwall-work-benchmark-driver-v2` payload;
  * a configuration whose before and after sides do not agree on the final state digest, which
    would mean the two sides are not simulating the same thing and no timing comparison of them
    means anything;
  * an empty side.

WHAT IT WILL NOT DO. It never combines the three workloads of decision 0024 section 3 into a
weighted score, and it reports the drift control alongside every measured configuration rather
than netting one off the other. A permutation p-value is evidence that two samples differ on
THIS machine in THIS session; it is not a REQ-SET-163 qualification-floor result.
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import random
import statistics
from pathlib import Path

DRIVER_SCHEMA = "redwall-work-benchmark-driver-v2"
METRICS = (("p99_us", "p99 1x"), ("p95_pair_us", "p95 pair"))
PERMUTATIONS = 20000
PERMUTATION_SEED = 20260908


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", nargs="+", required=True,
                        help="driver JSON paths or globs for the baseline side")
    parser.add_argument("--after", nargs="+", required=True,
                        help="driver JSON paths or globs for the candidate side")
    parser.add_argument("--before-label", default="before")
    parser.add_argument("--after-label", default="after")
    parser.add_argument("--drift-configs", nargs="*", default=["needs"],
                        help="configs that do not touch the code under test")
    parser.add_argument("--output-path", required=True, type=Path)
    parser.add_argument("--summary-path", type=Path, default=None)
    parser.add_argument("--permutations", type=int, default=PERMUTATIONS)
    return parser.parse_args()


def expand(patterns: list[str]) -> list[Path]:
    """Every existing path named by these literal paths or globs, sorted and de-duplicated."""
    found: set[Path] = set()
    for pattern in patterns:
        matches = [Path(item) for item in glob.glob(pattern)]
        if not matches and Path(pattern).is_file():
            matches = [Path(pattern)]
        if not matches:
            raise SystemExit(f"no driver JSON matched: {pattern}")
        found.update(matches)
    return sorted(found)


def load_side(paths: list[Path]) -> dict:
    """Pool one side's repetitions, refusing any run the driver itself would have rejected."""
    pooled: dict[tuple[str, str, int], dict] = {}
    provenance: list[dict] = []
    for path in paths:
        payload = json.loads(path.read_text())
        if payload.get("schema") != DRIVER_SCHEMA:
            raise SystemExit(f"not a {DRIVER_SCHEMA} payload: {path}")
        if not all(item["hashes_identical"] for item in payload["hash_comparisons"]):
            raise SystemExit(f"a pooled run's repetitions disagreed on their digests: {path}")
        provenance.append({
            "path": str(path),
            "started_utc": payload["started_utc"],
            "fixture_sha256": payload["fixture_sha256"],
            "runner": payload["build_context"].get("runner"),
            "asserts_live": payload["build_context"].get("asserts_live_in_timed_binary"),
            "work_gd_sha256": payload["source_hashes"].get("scripts/core/work.gd"),
        })
        absorb(payload, pooled)
    if not pooled:
        raise SystemExit(f"no runs pooled from {[str(p) for p in paths]}")
    return {"pooled": pooled, "provenance": provenance}


def absorb(payload: dict, pooled: dict) -> None:
    """Add every repetition of one driver payload to the pooled sample sets."""
    for record in payload["runs"]:
        key = (record["config"], record["workload"], record["population"])
        entry = pooled.setdefault(key, {"p99_us": [], "p95_pair_us": [], "digests": set()})
        for metric, _label in METRICS:
            entry[metric].append(int(record["benchmark"][metric]))
        entry["digests"].add(record["benchmark"]["final_hash_sha256"])


def permutation_p(before: list[int], after: list[int], iterations: int) -> float:
    """Two-sided permutation p-value for the difference of medians, seeded and reproducible."""
    rng = random.Random(PERMUTATION_SEED)
    observed = abs(statistics.median(after) - statistics.median(before))
    pool = list(before) + list(after)
    split = len(before)
    at_least = 0
    for _index in range(iterations):
        rng.shuffle(pool)
        if abs(statistics.median(pool[split:]) - statistics.median(pool[:split])) >= observed:
            at_least += 1
    return (at_least + 1) / (iterations + 1)


def compare_key(key: tuple, before: dict, after: dict, iterations: int) -> dict:
    """One configuration's pooled comparison, or a refusal if the two sides diverged in state."""
    if before["digests"] != after["digests"] or len(before["digests"]) != 1:
        raise SystemExit(f"final state digests disagree for {key}: "
                         f"{sorted(before['digests'])} vs {sorted(after['digests'])}")
    metrics = {}
    for metric, label in METRICS:
        left, right = before[metric], after[metric]
        left_median, right_median = statistics.median(left), statistics.median(right)
        metrics[metric] = {
            "label": label,
            "n_before": len(left), "n_after": len(right),
            "before_median_us": left_median, "after_median_us": right_median,
            "before_min_us": min(left), "before_max_us": max(left),
            "after_min_us": min(right), "after_max_us": max(right),
            "delta_percent": 100.0 * (right_median - left_median) / left_median,
            "permutation_p": permutation_p(left, right, iterations),
            "before_samples": left, "after_samples": right,
        }
    return {"config": key[0], "workload": key[1], "population": key[2],
            "final_digest": sorted(before["digests"])[0], "metrics": metrics}


def build_payload(args: argparse.Namespace, before: dict, after: dict) -> dict:
    """Assemble the pooled comparison for every configuration both sides measured."""
    shared = sorted(set(before["pooled"]) & set(after["pooled"]))
    if not shared:
        raise SystemExit("the two sides share no configuration")
    comparisons = [compare_key(key, before["pooled"][key], after["pooled"][key],
                               args.permutations)
                   for key in shared]
    return {
        "schema": "redwall-work-benchmark-pooled-v1",
        "generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "before_label": args.before_label,
        "after_label": args.after_label,
        "drift_configs": list(args.drift_configs),
        "permutations": args.permutations,
        "permutation_seed": PERMUTATION_SEED,
        "before_runs": before["provenance"],
        "after_runs": after["provenance"],
        "comparisons": comparisons,
        "combined_score": None,
        "combined_score_note": "decision 0024 section 3 forbids one; no workload distribution "
                               "is defined, so none is produced",
    }


def summary_rows(payload: dict) -> list[str]:
    """One Markdown row per configuration and metric, drift controls marked as such."""
    rows = []
    for item in payload["comparisons"]:
        drift = item["config"] in payload["drift_configs"]
        for metric, _label in METRICS:
            data = item["metrics"][metric]
            rows.append(
                f"| `{item['config']}`{' (drift control)' if drift else ''} | {item['workload']} "
                f"| {item['population']} | {data['label']} | {data['n_before']}/{data['n_after']} "
                f"| {data['before_median_us']:.1f} ({data['before_min_us']}-"
                f"{data['before_max_us']}) | {data['after_median_us']:.1f} "
                f"({data['after_min_us']}-{data['after_max_us']}) "
                f"| {data['delta_percent']:+.2f}% | {data['permutation_p']:.4f} |")
    return rows


def write_summary(payload: dict, path: Path) -> None:
    """Write the pooled Markdown table. Three workloads, independently, never combined."""
    lines = [
        "# Pooled work benchmark -- interleaved runs, three workloads reported independently",
        "",
        "Decision 0024 section 3 forbids combining these into one weighted score without an",
        "explicitly defined workload distribution. No such distribution exists, so none is here.",
        "",
        f"- before: `{payload['before_label']}` ({len(payload['before_runs'])} driver runs)",
        f"- after: `{payload['after_label']}` ({len(payload['after_runs'])} driver runs)",
        f"- two-sided permutation test on the difference of medians, "
        f"{payload['permutations']} permutations, seed {payload['permutation_seed']}",
        f"- generated: {payload['generated_utc']}",
        "",
        "| Config | Workload | Pop | Metric | n before/after | before median us (min-max) "
        "| after median us (min-max) | delta | permutation p |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    lines += summary_rows(payload)
    lines += ["", "## Driver runs pooled", "",
              "| Side | Path | Started | work.gd SHA-256 | fixture SHA-256 | runner |",
              "|---|---|---|---|---|---|"]
    for side in ("before", "after"):
        for run in payload[f"{side}_runs"]:
            lines.append(f"| {side} | `{run['path']}` | {run['started_utc']} "
                         f"| `{(run['work_gd_sha256'] or '')[:16]}` "
                         f"| `{run['fixture_sha256'][:16]}` | `{run['runner']}` |")
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    """Pool both sides, compare every shared configuration, and write the artifacts."""
    args = parse_args()
    if args.permutations < 1000:
        raise SystemExit("--permutations must be at least 1000 to resolve a p-value")
    before = load_side(expand(args.before))
    after = load_side(expand(args.after))
    payload = build_payload(args, before, after)
    args.output_path.parent.mkdir(parents=True, exist_ok=True)
    args.output_path.write_text(json.dumps(payload, indent=2, default=list) + "\n")
    if args.summary_path is not None:
        write_summary(payload, args.summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
