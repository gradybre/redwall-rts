#!/usr/bin/env python3
"""Independent read-only native haul review; writes only beside this script."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

OWN = Path(__file__).resolve().parent
ROOT = Path("/Users/brendan/Developer/redwall-rts-codex-ug-haul-handling")
BASE = ROOT / "godot/data/underground/mole-worker/haul-handling-v1"
PACKET = BASE / "evidence/native-program-v7"
PALETTE = Path("/Users/brendan/Developer/redwall-rts-codex-ug-space/godot/demo/assets/underground-matrices/all-cast-v9.ugpal")
GRIP = PALETTE.with_name("mole-grip-v3.ugpal")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_manifest(base: Path, name: str) -> dict:
    manifest = json.loads((PACKET / name).read_text())
    actual = {path: sha(base / path) for path in manifest}
    assert actual == manifest, name
    return actual


def main() -> None:
    assert not (OWN / "invocation.json").exists(), "fresh review output required"
    sources = check_manifest(ROOT, "final-source-sha256.json")
    outputs = check_manifest(PACKET, "output-sha256.json")
    common = ["--palette", str(PALETTE), "--grip-palette", str(GRIP)]
    commands = [
        ("tests", [str(BASE / "test_native_program.py"), *common, "--capture", str(PACKET), "-v"]),
        ("census", [str(PACKET / "census.py"), "--capture", str(PACKET)]),
        ("compile", [str(BASE / "compile_native_program.py"), *common, "--out", str(OWN / "compiled")]),
        ("verify", [str(BASE / "verify_native_program.py"), *common, "--capture", str(PACKET), "--out", str(OWN / "verification.json")]),
    ]
    records = []
    for name, arguments in commands:
        command = [sys.executable, "-B", *arguments]
        start = time.monotonic()
        with (OWN / (name + ".log")).open("xb") as log:
            result = subprocess.run(command, cwd=OWN, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        records.append({"command": command, "exit_code": result.returncode,
                        "elapsed_seconds": time.monotonic() - start,
                        "log": name + ".log", "log_sha256": sha(OWN / (name + ".log"))})
        assert result.returncode == 0, name
    comparisons = {}
    for name in ("haul-handling.ugactor", "proof.json", "compilation.json", "program.json", "plan.json"):
        comparisons["compiled/" + name] = sha(OWN / "compiled" / name) == sha(PACKET / "compiled" / name)
    comparisons["verification.json"] = sha(OWN / "verification.json") == sha(PACKET / "verification.json")
    comparisons["census.json"] = json.loads((OWN / "census.log").read_text()) == json.loads((PACKET / "census.json").read_text())
    assert all(comparisons.values()), comparisons
    assert sources == check_manifest(ROOT, "final-source-sha256.json")
    assert outputs == check_manifest(PACKET, "output-sha256.json")
    payload = {"scope": "Independent Python replay only; no engine or foreign writes.",
               "commands": records, "comparisons": comparisons, "source_sha256": sources,
               "source_manifest_sha256": sha(PACKET / "final-source-sha256.json"),
               "output_manifest_sha256": sha(PACKET / "output-sha256.json"),
               "source_and_output_unchanged": True, "production_qualified": False,
               "runtime_admitted": False}
    (OWN / "invocation.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({"commands_passed": len(records), "comparisons": comparisons}, indent=2))


if __name__ == "__main__":
    main()
