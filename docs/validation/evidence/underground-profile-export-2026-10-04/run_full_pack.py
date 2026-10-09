#!/usr/bin/env python3
"""Run the unchanged complete demo builder with isolated user data and retained source/evidence pins."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
BAD = re.compile(r"^(?:ERROR:|SCRIPT ERROR:|USER ERROR:|WARNING:|USER WARNING:)|ObjectDB instances leaked|resources still in use", re.M)


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def inputs():
    """Pin the actual working source, including additive candidate scripts; generated import sidecars are separate."""
    files = {path for base in (ROOT / "godot", ROOT / "tools") for path in base.rglob("*")
             if path.is_file() and path.suffix in (".gd", ".py", ".godot") and ".godot" not in path.parts
             and "assets" not in path.relative_to(ROOT).parts}
    files.update((ROOT / "tools/demo_build/windows_export_preset.cfg", Path(__file__),
                  ROOT / "godot/demo/assets/manifest.json",
                  ROOT / "godot/data/underground/mole-worker/profile-publication-v1/mole-worker.ugprof",
                  ROOT / "godot/data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor"))
    return {str(path.relative_to(ROOT)): digest(path) for path in sorted(files)}


def run(folder_name):
    """No unstaged or skipped-verification flags; every builder refusal stays a failed full-package attempt."""
    evidence, output = HERE / folder_name, ROOT / "build" / ("profile-export-" + folder_name)
    if output.exists() or output.is_symlink() or (evidence / "build-invocation.json").exists():
        raise ValueError("FULL_PACK_OUTPUT_EXISTS")
    if not (ROOT / "godot/demo/assets/manifest.json").is_file():
        raise ValueError("FULL_PACK_STAGING_INCOMPLETE")
    override, preset = ROOT / "godot/override.cfg", ROOT / "godot/export_presets.cfg"
    if override.exists() or override.is_symlink() or preset.is_symlink():
        raise ValueError("FULL_PACK_LOCAL_CONFIG_EXISTS_OR_LINK")
    old_preset = preset.read_bytes() if preset.exists() else None
    raw = ("[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\""
           + "Redwall-Codex-Profile-Export-" + folder_name + "\"\n").encode()
    evidence.mkdir(parents=True, exist_ok=True)
    before = inputs()
    (evidence / "build-sources-before.json").write_text(json.dumps(before, indent=2) + "\n")
    (evidence / "runtime-override.cfg.txt").write_bytes(raw)
    if old_preset is not None:
        (evidence / "original-export-presets.cfg.txt").write_bytes(old_preset)
    codes, commands = [], [["godot", "--headless", "--path", "godot", "--editor", "--quit"],
                          [sys.executable, "tools/build_demo_windows.py", "--out", str(output)]]
    started = time.monotonic()
    with override.open("xb") as file:
        file.write(raw)
    try:
        shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
        for command, name in zip(commands, ("clean-import.log", "build.log")):
            with (evidence / name).open("x") as log:
                codes.append(subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=7200).returncode)
            if codes[-1] or (name == "clean-import.log" and BAD.search((evidence / name).read_text())):
                break
    finally:
        if old_preset is None:
            preset.unlink(missing_ok=True)
        else:
            preset.write_bytes(old_preset)
        override_same = override.is_file() and override.read_bytes() == raw
        if override_same:
            override.unlink()
        after = {path: digest(ROOT / path) if (ROOT / path).is_file() else None for path in before}
        (evidence / "build-sources-after.json").write_text(json.dumps(after, indent=2) + "\n")
        if (output / "logs").is_dir():
            shutil.copytree(output / "logs", evidence / "builder-logs", dirs_exist_ok=False)
        if (output / "build.json").is_file():
            shutil.copy2(output / "build.json", evidence / "build.json")
        logs = [path for path in evidence.rglob("*.log") if path.name not in ("clone.log", "stage.log")]
        diagnostic_lines = {str(path.relative_to(evidence)): BAD.findall(path.read_text(errors="replace"))
                            for path in logs if BAD.search(path.read_text(errors="replace"))}
        record = {"commands": commands, "codes": codes, "seconds": round(time.monotonic() - started, 3),
                  "source_unchanged": before == after, "override_restored": override_same,
                  "preset_restored": (preset.read_bytes() if preset.exists() else None) == old_preset,
                  "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  "generated_output": str(output), "diagnostic_matches": diagnostic_lines,
                  "scope": "Full staged Windows debug export and editor pack boot; not Windows native, World activation or Forward Plus profile qualification"}
        (evidence / "build-invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))
    if codes != [0, 0] or before != after or not override_same or diagnostic_lines:
        raise SystemExit(1)


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) == 2 else "full-pack-v1")
