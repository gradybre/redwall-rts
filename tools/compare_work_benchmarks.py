#!/usr/bin/env python3
"""Place two work-benchmark driver runs side by side, and say whether the cost ranking moved.

Written for the editor-versus-release comparison of decision 0024 step 6, but it takes any two
driver JSONs. It reports the three standing workloads of decision 0024 section 3 INDEPENDENTLY
and never combines them into a weighted score: no workload distribution is defined, so no
combined figure may be produced.

WHAT THE PROBE DECOMPOSITION IS AND IS NOT. `benchmark_work.gd` documents this at length and it
is repeated here because a table invites the wrong reading. Each probe RUNS ONE NAMED PART of
the tick over the same contributor set and nothing else. Probe costs OVERLAP -- the per-iteration
loop floor sits inside all of them, which is why `loop` is subtracted -- and they OMIT
INTERACTION, so their sum is not the tick and the "unattributed remainder" below is a
subtraction, not a measured quantity. It can and does come out negative when the probes'
isolated costs exceed what the same work costs inside a full tick. A rank in this table is a
rank of ISOLATED COSTS. It does not promise that removing the top-ranked part recovers its
microseconds.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean

WORKLOADS = (("bands", "mixed bands, solo jobs"),
             ("uniform", "uniform, solo jobs"),
             ("party", "mixed bands, parties"))
CONFIG_ORDER = ("needs", "wu", "combined", "loop", "pid", "xp", "result", "factor", "gate",
                "party_fast", "party_finish")
PROBES = ("pid", "xp", "result", "factor", "gate")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, type=Path, help="driver JSON, left column")
    parser.add_argument("--candidate", required=True, type=Path, help="driver JSON, right column")
    parser.add_argument("--baseline-label", default="baseline")
    parser.add_argument("--candidate-label", default="candidate")
    parser.add_argument("--drift-runs", nargs="*", type=Path, default=[],
                        help="further driver JSONs holding the unmodified `needs` control")
    parser.add_argument("--drift-labels", nargs="*", default=[])
    parser.add_argument("--output-path", required=True, type=Path)
    return parser.parse_args()


def index_runs(payload: dict) -> dict:
    """Map (config, workload, population) to its repetitions' benchmark dicts, in run order."""
    indexed: dict[tuple[str, str, int], list[dict]] = {}
    for record in payload.get("runs", []):
        key = (record["config"], record["workload"], record["population"])
        indexed.setdefault(key, []).append(record["benchmark"])
    return indexed


def values(indexed: dict, key: tuple, metric: str) -> list[int]:
    """Every repetition's value of one metric, in repetition order, or an empty list."""
    return [int(entry[metric]) for entry in indexed.get(key, [])]


def average(indexed: dict, key: tuple, metric: str) -> float | None:
    """The mean across repetitions, or None when this run did not measure that triple."""
    series = values(indexed, key, metric)
    return mean(series) if series else None


def delta(before: float | None, after: float | None) -> str:
    """The signed change, or an explicit dash when either side is missing."""
    if before is None or after is None or before <= 0.0:
        return "-"
    return f"{100.0 * (after - before) / before:+.1f}%"


def populations(payload: dict) -> list[int]:
    """The populations this run measured, largest first."""
    return sorted((int(item) for item in payload["populations"]), reverse=True)


def timing_table(base: dict, cand: dict, labels: tuple[str, str], metric: str,
                 population: int) -> list[str]:
    """One config-by-workload table of a single metric for one population."""
    head = [f"| config | workload | {labels[0]} per rep | {labels[0]} mean "
            f"| {labels[1]} per rep | {labels[1]} mean | change |", "|---|---|---|---|---|---|---|"]
    rows = []
    for config in CONFIG_ORDER:
        for workload, label in WORKLOADS:
            key = (config, workload, population)
            if key not in base and key not in cand:
                continue
            base_mean, cand_mean = average(base, key, metric), average(cand, key, metric)
            rows.append(
                f"| `{config}` | {label} "
                f"| {'/'.join(str(v) for v in values(base, key, metric)) or '-'} "
                f"| {base_mean:.1f} "
                f"| {'/'.join(str(v) for v in values(cand, key, metric)) or '-'} "
                f"| {cand_mean:.1f} | {delta(base_mean, cand_mean)} |")
    return head + rows + [""] if rows else []


def probe_rows(base: dict, cand: dict, workload: str, population: int) -> list[str]:
    """Each probe's isolated cost above the loop floor, on both sides, with its rank on each."""
    wu = (average(base, ("wu", workload, population), "p99_us"),
          average(cand, ("wu", workload, population), "p99_us"))
    floor = (average(base, ("loop", workload, population), "p99_us"),
             average(cand, ("loop", workload, population), "p99_us"))
    entries = []
    for probe in PROBES:
        key = (probe, workload, population)
        if key not in base or key not in cand:
            continue
        entries.append((probe, average(base, key, "p99_us") - floor[0],
                        average(cand, key, "p99_us") - floor[1]))
    base_rank = sorted(entries, key=lambda item: -item[1])
    cand_rank = sorted(entries, key=lambda item: -item[2])
    rows = [f"| `{name}` | {left:.1f} | {100 * left / wu[0]:.1f}% | {right:.1f} "
            f"| {100 * right / wu[1]:.1f}% | {base_rank.index(entry) + 1} "
            f"| {cand_rank.index(entry) + 1} |"
            for entry in entries for name, left, right in [entry]]
    return rows + summary_rows(entries, wu, floor)


def summary_rows(entries: list[tuple], wu: tuple, floor: tuple) -> list[str]:
    """The floor, the probes' sum and the remainder left over, on both sides."""
    left_sum = sum(item[1] for item in entries)
    right_sum = sum(item[2] for item in entries)
    return [
        f"| **loop floor** | {floor[0]:.1f} | {100 * floor[0] / wu[0]:.1f}% | {floor[1]:.1f} "
        f"| {100 * floor[1] / wu[1]:.1f}% | - | - |",
        f"| **probes summed (they overlap; not a partition)** | {left_sum:.1f} "
        f"| {100 * left_sum / wu[0]:.1f}% | {right_sum:.1f} | {100 * right_sum / wu[1]:.1f}% "
        "| - | - |",
        f"| **unattributed remainder (a subtraction, not a measurement)** "
        f"| {wu[0] - left_sum - floor[0]:.1f} "
        f"| {100 * (wu[0] - left_sum - floor[0]) / wu[0]:.1f}% "
        f"| {wu[1] - right_sum - floor[1]:.1f} "
        f"| {100 * (wu[1] - right_sum - floor[1]) / wu[1]:.1f}% | - | - |", ""]


def probe_table(base: dict, cand: dict, labels: tuple[str, str], workload: str,
                population: int, label: str) -> list[str]:
    """The decomposition block for one workload at one population, with both rankings."""
    wu = (average(base, ("wu", workload, population), "p99_us"),
          average(cand, ("wu", workload, population), "p99_us"))
    if wu[0] is None or wu[1] is None:
        return []
    return [f"#### {label}, population {population}", "",
            f"`wu` p99: {labels[0]} {wu[0]:.1f} us, {labels[1]} {wu[1]:.1f} us "
            f"({delta(wu[0], wu[1])})", "",
            f"| probe | {labels[0]} us above floor | share of {labels[0]} `wu` "
            f"| {labels[1]} us above floor | share of {labels[1]} `wu` "
            f"| rank {labels[0]} | rank {labels[1]} |",
            "|---|---|---|---|---|---|---|"] + probe_rows(base, cand, workload, population)


def ranking_verdict(base: dict, cand: dict) -> list[str]:
    """State plainly, for every workload and population, whether the ranking moved at all."""
    lines = ["## Did the ranking change?", "",
             "| workload | population | baseline order | candidate order | same order |",
             "|---|---|---|---|---|"]
    for population in sorted({key[2] for key in base}, reverse=True):
        for workload, label in WORKLOADS:
            keys = [(probe, workload, population) for probe in PROBES]
            if not all(key in base and key in cand for key in keys):
                continue
            left = order_of(base, keys)
            right = order_of(cand, keys)
            lines.append(f"| {label} | {population} | {' > '.join(left)} | "
                         f"{' > '.join(right)} | {left == right} |")
    return lines + [""]


def order_of(indexed: dict, keys: list[tuple]) -> list[str]:
    """The probe names ordered by isolated cost above the loop floor, most expensive first."""
    workload, population = keys[0][1], keys[0][2]
    floor = average(indexed, ("loop", workload, population), "p99_us")
    ranked = sorted(keys, key=lambda key: -(average(indexed, key, "p99_us") - floor))
    return [key[0] for key in ranked]


def drift_table(runs: list[tuple[str, dict]], metric: str, population: int) -> list[str]:
    """The unmodified `needs` control across every run supplied, so machine drift is visible."""
    labels = [label for label, _ in runs]
    lines = [f"#### `needs` control, {metric}, population {population}", "",
             "| workload | " + " | ".join(labels) + " |",
             "|---" * (len(labels) + 1) + "|"]
    for workload, label in WORKLOADS:
        key = ("needs", workload, population)
        cells = []
        for _, indexed in runs:
            value = average(indexed, key, metric)
            cells.append("-" if value is None else f"{value:.1f}")
        lines.append(f"| {label} | " + " | ".join(cells) + " |")
    return lines + [""]


def digest_agreement(base: dict, cand: dict) -> list[str]:
    """Whether the two runs produced identical setup and final state digests, triple by triple."""
    shared = sorted(set(base) & set(cand))
    mismatches = [key for key in shared
                  if base[key][0]["setup_hash_sha256"] != cand[key][0]["setup_hash_sha256"]
                  or base[key][0]["final_hash_sha256"] != cand[key][0]["final_hash_sha256"]]
    lines = ["## Determinism digests across the two runs", "",
             f"- triples present in both runs: {len(shared)}",
             f"- digest disagreements: {len(mismatches)}"]
    for key in mismatches:
        lines.append(f"  - MISMATCH `{key[0]}` / {key[1]} / {key[2]}")
    return lines + [""]


def provenance(payload: dict, label: str) -> list[str]:
    """Everything that identifies what a run timed, so a row can name its own evidence."""
    context = payload["build_context"]
    return [f"- **{label}** — runner `{context.get('runner', 'editor')}` "
            f"({context['godot_binary_kind']}), asserts live in the timed binary: "
            f"{context.get('asserts_live_in_timed_binary')}",
            f"  - started {payload['started_utc']}, fixture SHA-256 "
            f"`{payload['fixture_sha256']}`",
            f"  - {payload['warmup_ticks']} warm-up ticks discarded, "
            f"{payload['sample_ticks']} sampled, {payload['repetitions']} independent "
            "processes per configuration, nearest rank",
            f"  - {context['measurement_scope_note']}"]


def header(base_payload: dict, cand_payload: dict, labels: tuple[str, str]) -> list[str]:
    """Title, provenance for both sides, and the refusals this document is bound by."""
    same_fixture = base_payload["fixture_sha256"] == cand_payload["fixture_sha256"]
    same_sources = base_payload["source_hashes"] == cand_payload["source_hashes"]
    return ["# Work benchmark — two runs side by side", "",
            *provenance(base_payload, labels[0]), *provenance(cand_payload, labels[1]), "",
            f"- both runs timed a byte-identical fixture: {same_fixture}",
            f"- both runs timed byte-identical core sources: {same_sources}", "",
            "Decision 0024 section 3 forbids combining the three workloads into one weighted "
            "score without an explicitly defined workload distribution. None exists, so none "
            "is produced here.", "",
            "No figure in this document is a REQ-SET-163 qualification-floor measurement: the "
            "floor is a Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB machine at 1920x1080, and "
            "Windows remains deferred.", ""]


def build_document(args: argparse.Namespace, base_payload: dict, cand_payload: dict,
                   drift: list[tuple[str, dict]]) -> list[str]:
    """Assemble every section of the comparison in a fixed order."""
    labels = (args.baseline_label, args.candidate_label)
    base, cand = index_runs(base_payload), index_runs(cand_payload)
    lines = header(base_payload, cand_payload, labels) + ranking_verdict(base, cand)
    for metric, title in (("p99_us", "p99 at 1x (us)"),
                          ("p95_pair_us", "p95 pair proxy (us)")):
        lines += [f"## {title}", ""]
        for population in populations(base_payload):
            lines += [f"### Population {population}", ""]
            lines += timing_table(base, cand, labels, metric, population)
    lines += ["## Probe decomposition, both sides", "",
              "Probe costs overlap and omit interaction; they are not a partition of the tick.",
              ""]
    for population in populations(base_payload):
        for workload, label in WORKLOADS:
            lines += probe_table(base, cand, labels, workload, population, label)
    if drift:
        lines += ["## Machine drift control", "",
                  "The unmodified `needs` configuration, unchanged by any optimisation, across "
                  "every run of this session. A release-versus-editor difference is only "
                  "interpretable against this spread.", ""]
        for metric in ("p99_us", "p95_pair_us"):
            for population in populations(base_payload):
                lines += drift_table(drift, metric, population)
    return lines + digest_agreement(base, cand)


def main() -> int:
    """Read both driver runs, write the comparison, and report where it went."""
    args = parse_args()
    base_payload = json.loads(args.baseline.read_text())
    cand_payload = json.loads(args.candidate.read_text())
    drift = [(args.baseline_label, index_runs(base_payload)),
             (args.candidate_label, index_runs(cand_payload))]
    for index, path in enumerate(args.drift_runs):
        label = args.drift_labels[index] if index < len(args.drift_labels) else path.stem
        drift.append((label, index_runs(json.loads(path.read_text()))))
    lines = build_document(args, base_payload, cand_payload, drift)
    args.output_path.parent.mkdir(parents=True, exist_ok=True)
    args.output_path.write_text("\n".join(lines) + "\n")
    print(f"comparison written: {args.output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
