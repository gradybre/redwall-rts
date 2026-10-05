#!/usr/bin/env python3
"""Create-only Python evidence; no engine, runtime source edits, imports of Git or checkout history."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE))
import test_wrapper as tests


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: reproduce.py NEW_OUTPUT_DIRECTORY")
    output = Path(sys.argv[1]).resolve()
    if output.exists():
        raise SystemExit("output directory must not exist")
    output.mkdir(parents=True)
    index = tests.fixture_index()
    tool = ROOT / "tools/underground_approach_memory.py"
    inputs = {tool, HERE / "test_wrapper.py", Path(__file__),
              ROOT / "tools/audit_registry_capacities.py", HERE / "fixtures/catalog-v3.gd.txt"}
    inputs |= {ROOT / path for path in tests.approach.PINS}
    inputs |= {ROOT / tests.approach.relative_path(name)
               for name in set(tests.approach.CURRENT) | set(tests.approach.JOINT_SOURCES)}
    before = {path.relative_to(ROOT).as_posix(): sha(path) for path in sorted(inputs)}
    write(output / "source-before.json", before)
    commands = [
        [sys.executable, "-B", str(HERE / "test_wrapper.py"), "-v"],
        [sys.executable, "-B", "-O", str(HERE / "test_wrapper.py"), "-v",
         "WrapperTests.test_unaccounted_cold_child_and_larger_buffer_refuse",
         "WrapperTests.test_added_retained_bank_refuses"],
    ]
    runs = []
    for ordinal, command in enumerate(commands):
        started = time.monotonic()
        completed = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (output / f"tests-{ordinal}.log").write_text(completed.stdout)
        runs.append({"argv": command, "exit": completed.returncode,
                     "elapsed_seconds": time.monotonic() - started})
        if completed.returncode:
            write(output / "invocation.json", runs)
            raise SystemExit(completed.returncode)
    report = tests.approach.build(index, tests.JOINT)
    write(output / "census.json", report)
    write(output / "input-index.json", {name: {"path": module.relative_path,
          "sha256": hashlib.sha256(module.text.encode()).hexdigest()}
          for name, module in index.items() if name in set(tests.approach.CURRENT) | set(tests.approach.JOINT_SOURCES)})
    after = {path.relative_to(ROOT).as_posix(): sha(path) for path in sorted(inputs)}
    write(output / "source-after.json", after)
    write(output / "invocation.json", runs)
    if before != after:
        raise SystemExit("input source changed during reproduction")
    summary = {
        "all_commands_passed": True, "source_unchanged": True,
        "normal_tests": 22, "optimized_assertion_regressions": 2,
        "logical_controls": report["profile_control"]["counted_subtotal"],
        "logical_slice": report["profile_control"]["bounded_logical_slice"],
        "unchanged_profile_control_reserve": report["profile_control"]["unchanged_helper_native_reserve"],
        "source_program_shared_bytes": report["source_program"]["shared_counted_once"],
        "complete_joint_bytes": report["joint"]["total"],
        "existing_envelope": report["joint"]["reservation"],
        "additional_reserved_bytes": report["additional_reserved_bytes"],
        "catalog_input": "Exact reviewed v3 Catalog snapshot injected into the actual parsed index; this branch's pending publication remains v2.",
        "normal_integrated_main_checker": "Root-owned follow-up; not claimed by this component run.",
        "engine_or_native_qualification": False,
    }
    write(output / "summary.json", summary)
    write(output / "output-sha256.json", {path.name: sha(path) for path in sorted(output.iterdir()) if path.is_file()})
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
