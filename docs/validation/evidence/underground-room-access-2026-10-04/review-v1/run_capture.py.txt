#!/usr/bin/env python3
"""Create-only actual-renderer D11 view witness; no production content or performance claim."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import time

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("access_checks", HERE / "reproduce.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
ROOT = CHECK.ROOT
NAMES = ("ready.png", "choose-boundary.png", "invalid-boundary.png")


def validate_report(out):
    report = json.loads((out / "report.json").read_text())
    if (report.get("scope") != "actual room-access view with synthetic source/physical fixture" or
            report.get("qualified") is not False or report.get("assertions") != 15 or
            report.get("failures") != [] or report.get("images") != list(NAMES) or
            report.get("renderer") != "forward_plus" or report.get("driver") != "metal"):
        raise ValueError("Native actual-renderer/state assertion census")
    if sorted(p.name for p in out.glob("*.png")) != sorted(NAMES):
        raise ValueError("Native image census")
    result = {}
    for name in NAMES:
        path = out / name
        raw = path.read_bytes()
        if len(raw) < 33 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR" or struct.unpack(">II", raw[16:24]) != (1280, 720):
            raise ValueError("Native image dimensions")
        result[name] = CHECK.sha(path)
    return result


def pins():
    result = CHECK.snapshot()
    for name in ("capture_access.gd", "run_capture.py"):
        path = HERE / name
        result[str(path.relative_to(ROOT))] = CHECK.sha(path)
    return result


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--port", type=int, default=6339)
    args = parser.parse_args()
    if args.out.is_symlink() or args.out.exists():
        raise ValueError("Evidence output must be new and not a symlink")
    out = args.out.resolve()
    project = ROOT / "godot/project.godot"
    original = project.read_bytes()
    if b"config/use_custom_user_dir" in original or original.count(b"[application]\n") != 1:
        raise ValueError("Incompatible user directory configuration")
    out.mkdir(parents=True, exist_ok=False)
    before = pins()
    CHECK.write(out / "source-before.json", before)
    sidecars = {p: p.read_bytes() for p in (ROOT / "godot").rglob("*.import")}
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    user = "Redwall-ug1154-native-" + hashlib.sha256(str(out).encode()).hexdigest()[:16]
    record = {"head": head, "commands": [], "custom_user_dir": user, "qualified": False,
              "project_sha256": CHECK.sha(project), "source_count": len(before)}
    status = 1
    try:
        project.write_bytes(original.replace(b"[application]\n", ("[application]\nconfig/use_custom_user_dir=true\n"
                            f'config/custom_user_dir_name="{user}"\n').encode(), 1))
        commands = [(["godot", "--path", "godot", "--script", str(HERE / "capture_access.gd"), "--", str(out)], "native.log"),
                    (["python3", "tools/gdscript_warnings.py", "--project", str(HERE), "--editor-project", str(ROOT / "godot"),
                      "--max", "0", "--port", str(args.port), "--json", str(out / "analyzer.json"),
                      str(HERE / "capture_access.gd")], "analyzer.log")]
        for command, log_name in commands:
            started = time.monotonic()
            with (out / log_name).open("w") as log:
                completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            raw = CHECK.raw_findings((out / log_name).read_text())
            record["commands"].append({"command": command, "exit_code": completed.returncode, "raw_findings": raw,
                                       "seconds": round(time.monotonic() - started, 3), "log": log_name})
            print(log_name, completed.returncode, flush=True)
            if completed.returncode or raw:
                raise ValueError(log_name + " refused")
        record["images"] = validate_report(out)
        status = 0
    except (Exception, KeyboardInterrupt) as error:
        record["error"] = repr(error)
    finally:
        after = pins()
        CHECK.write(out / "source-after.json", after)
        record["source_unchanged"] = before == after
        project.write_bytes(original)
        for path in set((ROOT / "godot").rglob("*.import")) - set(sidecars):
            path.unlink()
        for path, raw in sidecars.items():
            path.write_bytes(raw)
        record["project_restored"] = project.read_bytes() == original
        record["sidecars_restored"] = {p: p.read_bytes() for p in (ROOT / "godot").rglob("*.import")} == sidecars
        record["head_unchanged"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == head
        if not all(record[key] for key in ("source_unchanged", "project_restored", "sidecars_restored", "head_unchanged")):
            status = 1
        record["exit_code"] = status
        CHECK.write(out / "invocation.json", record)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
