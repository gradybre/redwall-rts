#!/usr/bin/env python3
"""Allocate and audit the existing Godot suite without changing its runner.

    ./tools/run_tests.sh --shard 0/8 --output-dir artifacts/test-shards
    python3 tools/ci_test_shards.py verify --reports artifacts/test-shards --count 8
    python3 tools/ci_test_shards.py verify --reports artifacts/test-shards --count 8 --baseline-log full.log

Only direct test/test_*.gd files are suites, exactly as run_tests.gd discovers them.
Every shard uses the existing supervisor/worker and the unchanged zero allowances.
Plans cover the on-disk corpus exactly once; reports separately prove what ran.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import statistics
import sys

REPO = Path(__file__).resolve().parent.parent
WEIGHTS = REPO / "tools/ci_test_shard_weights.json"
COUNTS = ("tests", "assertions", "failures", "unexpected_errors", "unexpected_warnings",
          "expected", "tolerated", "leaked_objects", "leaked_resources")
ZERO_COUNTS = ("failures", "unexpected_errors", "unexpected_warnings", "leaked_objects", "leaked_resources")
SUMMARY = re.compile(r"^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$", re.M)
DIAGNOSTICS = re.compile(
    r"^diagnostics: (\d+) unexpected error\(s\), (\d+) unexpected warning\(s\), "
    r"(\d+) expected, (\d+) tolerated; leaked at exit: (\d+) object\(s\), (\d+) resource\(s\)$", re.M)
LOG_SUMMARY = re.compile(
    r"^log: (\d+) unexpected error\(s\), (\d+) unexpected warning\(s\); "
    r"leaked at exit: (\d+) object\(s\), (\d+) resource\(s\)\.$", re.M)
SUITE_LINE = re.compile(r"^(test_[^/\s]+\.gd)$", re.M)
TIMING_LINE = re.compile(r"^CI_SUITE_TIME (.+)$", re.M)


class InvalidRun(ValueError):
    """A plan or execution does not prove complete, clean coverage."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidRun(message)


def integer(value: object, minimum: int = 0) -> bool:
    return type(value) is int and value >= minimum


def discover(repo: Path = REPO) -> list[str]:
    """Mirror the runner's non-recursive discovery; no hand-maintained file list."""
    return sorted(p.name for p in (repo / "godot/test").iterdir()
                  if p.is_file() and p.name.startswith("test_") and p.name.endswith(".gd"))


def fingerprint(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def shard_spec(value: str) -> tuple[int, int]:
    require(re.fullmatch(r"[0-9]+/[1-9][0-9]*", value) is not None, "shard must be INDEX/COUNT (zero-based)")
    index, count = map(int, value.split("/"))
    require(index < count, f"shard index {index} is outside 0..{count - 1}")
    return index, count


def validate_plan(plan: dict, corpus: list[str]) -> None:
    require(isinstance(plan, dict) and plan.get("version") == 1, "invalid manifest version")
    require(integer(plan.get("shard_count"), 1), "invalid shard count")
    require(plan.get("suites") == corpus and bool(corpus), "manifest corpus differs from discovered test files")
    shards = plan.get("shards")
    require(isinstance(shards, list) and len(shards) == plan["shard_count"], "missing shard in manifest")
    require(all(isinstance(group, list) and group and all(isinstance(s, str) for s in group)
                for group in shards), "every shard must contain suite names")
    actual = Counter(name for group in shards for name in group)
    require(actual == Counter(corpus), f"manifest must assign every suite exactly once: {coverage_difference(corpus, actual)}")


def coverage_difference(corpus: list[str], actual: Counter) -> str:
    expected = Counter(corpus)
    return f"missing={list((expected - actual).elements())}, extra/duplicate={list((actual - expected).elements())}"


def make_plan(count: int, repo: Path = REPO, weights_path: Path = WEIGHTS) -> dict:
    corpus = discover(repo)
    require(integer(count, 1) and count <= len(corpus), "shard count must be between 1 and the suite count")
    known = json.loads(weights_path.read_text(encoding="utf-8"))["suite_usec"] if weights_path.exists() else {}
    require(isinstance(known, dict) and all(isinstance(k, str) and integer(v, 1) for k, v in known.items()),
            "timing weights must be positive integer microseconds")
    # Unknown files get a conservative source-size estimate; coverage never depends on timing data.
    rates = [known[name] / (repo / "godot/test" / name).stat().st_size for name in corpus if name in known]
    rate = max(1.0, statistics.median(rates)) if rates else 1.0
    weights = {name: known.get(name, max(1, round((repo / "godot/test" / name).stat().st_size * rate)))
               for name in corpus}
    shards: list[list[str]] = [[] for _ in range(count)]
    totals = [0] * count
    for name in sorted(corpus, key=lambda name: (-weights[name], name)):
        index = min(range(count), key=lambda index: (totals[index], index))
        shards[index].append(name)
        totals[index] += weights[name]
    for group in shards:
        group.sort()
    plan = {"version": 1, "shard_count": count, "suites": corpus, "shards": shards,
            "estimated_usec": totals, "weights_sha256": fingerprint(known)}
    validate_plan(plan, corpus)
    return plan


def one_match(pattern: re.Pattern, text: str, label: str) -> tuple[str, ...]:
    matches = list(pattern.finditer(text))
    require(len(matches) == 1, f"expected exactly one {label}; found {len(matches)}")
    return matches[0].groups()


def parse_log(text: str) -> tuple[dict[str, int], list[str], dict[str, int]]:
    """Cross-check both runner summaries against raw output, including all zero allowances."""
    values = tuple(map(int, one_match(SUMMARY, text, "test summary")))
    values += tuple(map(int, one_match(DIAGNOSTICS, text, "diagnostic summary")))
    counts = dict(zip(COUNTS, values))
    require(counts["tests"] > 0 and counts["assertions"] > 0, "no tests or assertions ran")
    require(all(counts[key] == 0 for key in ZERO_COUNTS), f"unclean test result: {counts}")
    require(not re.search(r"^(?:USER )?SCRIPT ERROR:", text, re.M), "script abort in test log")
    raw = (
        len(re.findall(r"^(?:USER )?ERROR:", text, re.M)),
        len(re.findall(r"^(?:USER )?WARNING:", text, re.M)),
        sum(map(int, re.findall(r"(\d+) ObjectDB instances were leaked", text))),
        sum(map(int, re.findall(r"(\d+) resources still in use at exit", text))),
    )
    require(raw == (0, 0, 0, 0), f"unexpected diagnostics or leaks in raw log: {raw}")
    require(tuple(map(int, one_match(LOG_SUMMARY, text, "shell log summary"))) == raw, "shell diagnostic tally mismatch")
    for key, prefix in (("expected", "EXPECTED"), ("tolerated", "TOLERATED")):
        actual = len(re.findall(rf"^{prefix} (?:USER )?(?:ERROR|WARNING):", text, re.M))
        require(counts[key] == actual, f"{key} diagnostic tally mismatch: summary={counts[key]}, raw={actual}")
    success = re.findall(r"^ok: (\d+) tests, (\d+) assertions, 0 failures\.$", text, re.M)
    require(success == [(str(counts["tests"]), str(counts["assertions"]))], "missing or inconsistent shell success guard")
    suites = SUITE_LINE.findall(text)
    timings: dict[str, int] = {}
    completed_counts = dict.fromkeys(COUNTS[:3], 0)
    for line in TIMING_LINE.findall(text):
        entry = json.loads(line)
        require(isinstance(entry, dict) and isinstance(entry.get("suite"), str)
                and integer(entry.get("usec")), "invalid suite timing record")
        require(all(integer(entry.get(key)) for key in COUNTS[:3]), "missing or invalid completed suite counters")
        require(entry["suite"] not in timings, f"duplicate completed suite: {entry['suite']}")
        timings[entry["suite"]] = entry["usec"]
        for key in completed_counts:
            completed_counts[key] += entry[key]
    if timings:
        require(all(completed_counts[key] == counts[key] for key in completed_counts),
                "completed suite counters differ from the runner summary")
    return counts, suites, timings


def suite_counts_from_log(text: str) -> dict[str, dict[str, int]]:
    """Per-suite counts from an already validated log, retained to diagnose equivalence differences."""
    entries = [json.loads(line) for line in TIMING_LINE.findall(text)]
    return {entry["suite"]: {key: entry[key] for key in COUNTS[:3]} for entry in entries}


def validate_report(report: dict, plan: dict, index: int) -> None:
    require(isinstance(report, dict) and report.get("version") == 1, "invalid report version")
    require(report.get("shard_index") == index and report.get("shard_count") == plan["shard_count"], "report shard identity mismatch")
    require(report.get("manifest_sha256") == fingerprint(plan), "report manifest fingerprint mismatch")
    require(report.get("suites") == plan["shards"][index], f"shard {index} executed files differ from its assignment")
    counts = report.get("counts", {})
    require(set(counts) == set(COUNTS) and all(integer(value) for value in counts.values()), "invalid report counters")
    require(counts["tests"] > 0 and counts["assertions"] > 0, "empty shard execution")
    require(all(counts[key] == 0 for key in ZERO_COUNTS), "report contains failures, unexpected diagnostics or leaks")
    timings = report.get("suite_usec", {})
    require(set(timings) == set(report["suites"]) and all(integer(value) for value in timings.values()), "missing or invalid completion timings")
    completed = report.get("suite_counts", {})
    require(set(completed) == set(report["suites"]) and all(
        isinstance(row, dict) and set(row) == set(COUNTS[:3]) and all(integer(value) for value in row.values())
        for row in completed.values()), "missing or invalid completed suite counters")
    require(all(sum(row[key] for row in completed.values()) == counts[key] for key in COUNTS[:3]),
            "completed suite report counters differ from the runner summary")
    require(integer(report.get("wall_seconds")), "invalid shard wall time")


def aggregate(reports_dir: Path, count: int, repo: Path = REPO, baseline_log: Path | None = None) -> dict:
    require(integer(count, 1), "shard count must be positive")
    expected_files = {f"shard-{index}.json" for index in range(count)}
    require({p.name for p in reports_dir.glob("shard-*.json")} == expected_files, "missing or extra shard reports")
    totals = dict.fromkeys(COUNTS, 0)
    all_suites: list[str] = []
    suite_usec: dict[str, int] = {}
    wall_times: list[int] = []
    first_plan: dict | None = None
    for index in range(count):
        plan = json.loads((reports_dir / f"manifest-{index}.json").read_text(encoding="utf-8"))
        validate_plan(plan, discover(repo))
        require(plan["shard_count"] == count, "artifact shard count differs from workflow matrix")
        require(first_plan is None or plan == first_plan, "shards used different manifests")
        first_plan = plan
        report = json.loads((reports_dir / f"shard-{index}.json").read_text(encoding="utf-8"))
        validate_report(report, plan, index)
        # Uploaded JSON is corroborated by the raw execution log rather than trusted alone.
        raw_log = (reports_dir / f"shard-{index}.log").read_text(encoding="utf-8")
        counts, observed, timings = parse_log(raw_log)
        require((counts, observed, timings) == (report["counts"], report["suites"], report["suite_usec"]),
                f"shard {index} report differs from its raw log")
        require(suite_counts_from_log(raw_log) == report["suite_counts"], f"shard {index} completed counters differ from its raw log")
        all_suites.extend(observed)
        suite_usec.update(timings)
        wall_times.append(report["wall_seconds"])
        for key in COUNTS:
            totals[key] += counts[key]
    require(Counter(all_suites) == Counter(discover(repo)), "executed suite corpus is missing or duplicated")
    if baseline_log is not None:
        baseline_counts, baseline_suites, _ = parse_log(baseline_log.read_text(encoding="utf-8"))
        require(Counter(baseline_suites) == Counter(discover(repo)), "baseline did not execute every suite exactly once")
        require(totals == baseline_counts, f"shard totals differ from full suite: shards={totals}, baseline={baseline_counts}")
    return {"version": 1, "suite_count": len(all_suites), "shard_count": count, "counts": totals,
            "wall_seconds": wall_times, "suite_usec": suite_usec, "baseline_matches": baseline_log is not None}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare", help="write a complete plan and print this shard's selected suites as JSON")
    prepare.add_argument("--shard", required=True)
    prepare.add_argument("--output-dir", type=Path, required=True)
    record = sub.add_parser("record", help="audit the completed wrapper log and write its result")
    record.add_argument("--shard", required=True)
    record.add_argument("--output-dir", type=Path, required=True)
    record.add_argument("--wall-seconds", type=int, required=True)
    verify = sub.add_parser("verify", help="fail on missing, duplicate, failed or inconsistent shard execution")
    verify.add_argument("--reports", type=Path, required=True)
    verify.add_argument("--count", type=int, required=True)
    verify.add_argument("--baseline-log", type=Path)
    verify.add_argument("--output", type=Path)
    weights = sub.add_parser("weights", help="refresh timing estimates from verified shard reports")
    weights.add_argument("--reports", type=Path, required=True)
    weights.add_argument("--count", type=int, required=True)
    weights.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            index, count = shard_spec(args.shard)
            plan = make_plan(count)
            write_json(args.output_dir / f"manifest-{index}.json", plan)
            print(json.dumps(plan["shards"][index]))
        elif args.command == "record":
            index, count = shard_spec(args.shard)
            plan = json.loads((args.output_dir / f"manifest-{index}.json").read_text(encoding="utf-8"))
            validate_plan(plan, discover())
            raw_log = (args.output_dir / f"shard-{index}.log").read_text(encoding="utf-8")
            counts, suites, timings = parse_log(raw_log)
            report = {"version": 1, "shard_index": index, "shard_count": count, "manifest_sha256": fingerprint(plan),
                      "counts": counts, "suites": suites, "suite_usec": timings, "wall_seconds": args.wall_seconds,
                      "suite_counts": suite_counts_from_log(raw_log)}
            validate_report(report, plan, index)
            write_json(args.output_dir / f"shard-{index}.json", report)
        else:
            result = aggregate(args.reports, args.count, baseline_log=getattr(args, "baseline_log", None))
            if args.command == "weights":
                write_json(args.output, {"version": 1, "note": "Measured suite microseconds; estimates only, never a coverage allowlist.",
                                         "suite_usec": {name: max(1, usec) for name, usec in result["suite_usec"].items()}})
            else:
                if args.output:
                    write_json(args.output, result)
                print(f"ok: {result['suite_count']} suite files executed exactly once across {args.count} shards")
                print(json.dumps({key: value for key, value in result.items() if key != "suite_usec"}, sort_keys=True))
    except (InvalidRun, OSError, ValueError, KeyError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
