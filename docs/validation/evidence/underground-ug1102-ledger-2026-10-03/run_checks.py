#!/usr/bin/env python3
"""Reproduce the unchanged CI specification commands and the scoped stale-census tests."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ENV = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
COMMANDS = [
    ["docs/validation/decision_numbers.py"],
    ["docs/validation/ready07_arithmetic.py", "--output", str(HERE / "arithmetic.json")],
    ["tools/underground_memory_budget.py", "--check"],
    ["tools/test_underground_memory_budget.py"],
    ["docs/validation/merge_gate.py"],
    ["docs/validation/setting_contract.py", "--output", str(HERE / "setting-contract.json")],
    ["tools/dispatch_plan.py", "--validate"],
    ["tools/astra_inbox.py", "--check"],
    ["docs/validation/validate_save_registry_handoff.py", "--source-root", "."],
    ["tools/generate_canonical_state_table.py", "--check"],
    ["docs/validation/validate_cycle01_handoff.py"],
    ["docs/validation/validate_cycle02_handoff.py"],
    ["docs/validation/validate_cycle03_handoff.py", "--source-root", "."],
    ["tools/audit_registry_capacities.py", "--check"],
    ["tools/test_registry_capacity_audit.py"],
    ["tools/generate_component_columns_schema.py", "--check"],
    ["tools/test_component_columns_schema.py"],
    ["tools/lane_notes.py", "--check"],
    ["tools/test_movement_envelopes.py"],
    ["tools/test_movement_profile_policy.py"],
    ["docs/validation/state_registry_coverage.py"],
    ["docs/validation/test_headless_runner.py"],
    ["docs/validation/test_qualify.py"],
    ["docs/validation/test_winter.py"],
    ["docs/validation/test_merge_gate.py"],
    ["tools/test_repair_meshy_rig.py"],
    ["tools/test_rig_meshy_tail.py"],
    ["tools/test_bake_meshy_tail.py"],
    ["tools/test_ground_meshy_clips.py"],
    ["tools/test_demo_texture_imports.py"],
    ["tools/test_build_demo_windows.py"],
    ["tools/test_balance_report.py"],
    ["tools/test_soak_report.py"],
    ["tools/test_stage_art_passes.py"],
    [str(HERE / "test_stale_census.py"), "-v"],
]


def main():
    """Retain every command's complete output and exit code without relaxing any check."""
    records = []
    for number, args in enumerate(COMMANDS, 1):
        command = [sys.executable, "-B", *args]
        start = time.monotonic()
        result = subprocess.run(command, cwd=ROOT, env=ENV, capture_output=True, text=True)
        log = HERE / f"{number:02d}-{Path(args[0]).stem}.log"
        log.write_text(result.stdout + result.stderr)
        records.append({"command": command, "exit_code": result.returncode,
            "seconds": round(time.monotonic() - start, 3), "log": log.name,
            "sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        print(f"{number:02d} exit={result.returncode} {Path(args[0]).name}", flush=True)
    (HERE / "checks.json").write_text(json.dumps(records, indent=2) + "\n")
    failures = sum(record["exit_code"] != 0 for record in records)
    print(f"{len(records)} checks; {failures} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
