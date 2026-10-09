#!/usr/bin/env python3
"""Independent provenance and decoder counterexamples for the frozen native packet."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
from unittest.mock import patch

from reproduce import OWN, ROOT, BASE, PACKET, PALETTE, GRIP, sha

sys.path.insert(0, str(BASE))
import compile_native_program as C
import run_native_program as N
import verify_native_program as V


def refused(call, label):
    try:
        call()
    except ValueError as error:
        assert str(error) == label, str(error)
        return label
    raise AssertionError("unexpected acceptance: " + label)


def main():
    invocation = json.loads((PACKET / "invocation.json").read_text())
    runtime = N.closure()
    for name, expected in runtime.items():
        assert invocation["source_sha256"]["godot/" + name] == expected
    for name, expected in invocation["source_sha256"].items():
        assert sha(ROOT / name) == expected
    commands = []
    for command in invocation["commands"]:
        log = PACKET / command["log"]
        assert sha(log) == command["log_sha256"]
        bad = [line for line in log.read_text().splitlines() if any(x in line for x in N.DIAGNOSTICS)]
        assert command["exit_code"] == 0 and command["diagnostics"] == [] and not bad
        commands.append({"log": command["log"], "exit_code": 0, "raw_diagnostics": []})
    assert sha(C.BASIS) == C.BASIS_SHA
    assert invocation["source_unchanged"] and invocation["error"] is None
    assert json.loads((PACKET / "analyzer.json").read_text()) == {}
    assert sha(PACKET / "native-stock.json") == C.WRAPPER_SHA
    report = json.loads((PACKET / "report.json").read_text())
    assert report["rows"] == 7068 and report["assertions"] == 21251 and not report["failures"]
    assert len(report["screenshots"]) == 8
    for name in report["screenshots"]:
        assert (PACKET / name).read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"

    outcomes = {}
    original = (PACKET / "native.bin").read_bytes()
    with tempfile.TemporaryDirectory(prefix="mutants-", dir=OWN) as folder:
        path = Path(folder) / "capture.bin"
        for name, offset, payload in (("magic", 0, b"BADNAT01"), ("shape", 8, struct.pack("<II", 8, 313))):
            data = bytearray(original)
            data[offset:offset + len(payload)] = payload
            path.write_bytes(data)
            with patch.object(V.np, "frombuffer", side_effect=AssertionError("array decoder entered")):
                outcomes[name] = refused(lambda: V.capture(path), "HAUL_NATIVE_CAPTURE_HEADER")
        data = bytearray(original)
        data[16 + 8 * 4:16 + 8 * 4 + 4] = struct.pack("<f", float("nan"))
        path.write_bytes(data)
        outcomes["nonfinite"] = refused(lambda: V.capture(path), "HAUL_NATIVE_CAPTURE_NONFINITE")
    _, body, wood, _, _, _, _, _ = C.I.current_inputs(PALETTE, GRIP)
    cases = C.cases_from_review(body, wood)
    row = V.capture(PACKET / "native.bin")[0].copy()
    expected_pair = row["values"][312:].copy()
    row["values"][312] = 0.5
    outcomes["changed_basis_input"] = refused(lambda: V.row_refusal(row, 0, 0, 0, cases[0], expected_pair),
                                                "HAUL_NATIVE_COEFFICIENT")
    source_manifest = json.loads((PACKET / "final-source-sha256.json").read_text())
    output_manifest = json.loads((PACKET / "output-sha256.json").read_text())
    assert all(sha(ROOT / name) == expected for name, expected in source_manifest.items())
    assert all(sha(PACKET / name) == expected for name, expected in output_manifest.items())
    result = {"source_pins_match": len(source_manifest), "output_pins_match": len(output_manifest),
              "runtime_closure_files": len(runtime), "all_native_invocation_source_pins_match": len(invocation["source_sha256"]),
              "basis_sha256": C.BASIS_SHA, "commands": commands, "additional_counterexamples": outcomes,
              "native_engine_rerun": False, "foreign_writes": False,
              "scope": "Frozen sampled native input packet only; no runtime or GPU qualification."}
    (OWN / "audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
