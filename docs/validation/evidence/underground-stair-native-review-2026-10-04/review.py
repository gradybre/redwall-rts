#!/usr/bin/env python3
"""Independent saved-witness review; all subject files and outside assets are read-only."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys


def digest(path):
    with path.open("rb") as stream:
        h = hashlib.sha256()
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("subject", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    root = args.subject.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    base = root / "godot/data/underground/mole-worker/evidence/contact-qualification/stair-handoffs-v1"
    pins = {}
    counts = {}
    for name in ("source", "output", "history", "inherited"):
        manifest = base / "native-review-v1" / f"{name}-sha256.json"
        pins[str(manifest)] = digest(manifest)
        entries = json.loads(manifest.read_text())
        counts[name] = len(entries)
        for relative, expected in entries.items():
            path = root / relative
            assert path.is_file() and not path.is_symlink(), path
            assert digest(path) == expected, path
            pins[str(path)] = expected
    script = base / "test_native_handoffs.py"
    command = [sys.executable, "-B", str(script)]
    with (args.out / "tests.log").open("x") as log:
        code = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT).returncode
    assert code == 0, "native report/source tests failed"
    imported = importlib.util.spec_from_file_location("independent_stair_native", base / "run_native_handoffs.py")
    module = importlib.util.module_from_spec(imported)
    imported.loader.exec_module(module)
    spec = json.loads((base / "native-v5/spec.json").read_text())
    report = json.loads((base / "native-v5/report.json").read_text())
    oracle = module.validate_report(report, spec)
    for shot in report["screenshots"]:
        path = base / "native-v5" / shot["path"]
        assert path.parent == base / "native-v5", path
        assert digest(path) == shot["sha256"], path
        header = path.read_bytes()[:24]
        assert header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR", path
        assert struct.unpack(">II", header[16:24]) == (1280, 720), path
    assert all(digest(Path(path)) == sha for path, sha in pins.items()), "subject changed during review"
    result = dict(subject=str(root), source_sha256=pins, counts=counts, tests_command=command,
                  tests_exit_code=code, oracle=oracle, verified_pngs=len(report["screenshots"]),
                  png_dimensions=[1280, 720], source_unchanged=True, engine_run=False,
                  production_qualified=False)
    (args.out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "source_sha256"}))


if __name__ == "__main__":
    main()
