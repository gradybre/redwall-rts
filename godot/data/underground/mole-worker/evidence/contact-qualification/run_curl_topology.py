#!/usr/bin/env python3
"""ADR 1216: native topology capture of the curled pick paw's compiled content (successor of run_capture.py --mode topology).

The accepted runner's import step, source closure, pre/post source pins, diagnostics rule and report validation
are reused unchanged. Only the content (`curl-v1`, compiled from mole-grip-v4.ugpal), the bake spec it is closed
over (`grip-source-v4`) and the capture script (`capture_topology_curl.gd`) differ.

    $PY .../run_curl_topology.py <fresh-out-dir>
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("accepted_run_capture", HERE / "run_capture.py")
RC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RC)
CONTENT = "res://data/underground/mole-worker/curl-v1/mole-worker.ugactor"
COMPILATION = RC.ROOT / "godot/data/underground/mole-worker/curl-v1/compilation.json"


def spec_for_curl() -> dict:
    """The accepted native spec with the curled content in place of firm-v1."""
    spec = json.loads((HERE.parent / "grip-native-v2/spec.json").read_text())
    produced = json.loads(COMPILATION.read_text())
    if RC.digest(RC.actual(CONTENT)) != produced["content_sha256"]:
        raise ValueError("CURL_TOPOLOGY_CONTENT")
    spec.update(content=CONTENT, content_sha256=produced["content_sha256"],
                reserve_bytes=produced["presentation_budget"]["admitted_peak_bytes"], last_source_frame=17, mode="topology")
    return spec


def run(command: list, log: Path) -> int:
    """One logged subprocess from the repository root."""
    with log.open("x") as stream:
        return subprocess.run(command, cwd=RC.ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=900).returncode


def main() -> int:
    """Import, pin, capture natively, re-pin and validate."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        raise ValueError("CURL_TOPOLOGY_OUTPUT_EXISTS")
    out.mkdir(parents=True)
    importer = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
    imported = run(importer, out / "import.log")
    if imported or RC.DIAGNOSTIC.search((out / "import.log").read_text()):
        raise ValueError("CURL_TOPOLOGY_IMPORT")
    script = HERE / "capture_topology_curl.gd"
    pins = RC.closure(script, HERE / "grip-source-v4/bake-spec.json")
    spec = spec_for_curl()
    for key in ("content", "basis", "manifest"):
        pins[str(RC.actual(spec[key]).resolve())] = RC.digest(RC.actual(spec[key]))
    (out / "sources.json").write_text(json.dumps(pins, indent=2) + "\n")
    (out / "spec.json").write_text(json.dumps(spec, indent=2) + "\n")
    native = ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
              "--fixed-fps", "60", "--script", str(script), "--", str(out / "spec.json"), str(out)]
    code = run(native, out / "native.log")
    after = {name: RC.digest(Path(name)) if Path(name).is_file() else None for name in pins}
    bad = bool(RC.DIAGNOSTIC.search((out / "native.log").read_text()))
    invocation = {"commands": [importer, native], "returncodes": [imported, code], "source_unchanged": pins == after,
                  "unexpected_diagnostics": bad, "production_qualified": False}
    if code or bad or pins != after:
        (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
        raise ValueError("CURL_TOPOLOGY_NATIVE_OR_SOURCE")
    report = json.loads((out / "topology.json").read_text())
    invocation["validated_report"] = RC.validate_report(report, "topology", spec, RC.wire_timing(spec))
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2) + "\n")
    (out / "output-sha256.json").write_text(json.dumps({"topology.json": RC.digest(out / "topology.json")}, indent=2) + "\n")
    print(json.dumps(invocation["validated_report"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
