#!/usr/bin/env python3
"""Exact native-validator tests and isolated-user-directory analyzer; no full-suite claim."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
SOURCE = HERE.parent / "capture_install_program.gd"
WRAPPER = HERE.parent / "run_install_program_capture.py"
TEST = HERE.parent / "test_install_program_capture.py"
override = ROOT / "godot/override.cfg"
if override.exists() or override.is_symlink():
    raise ValueError("INSTALL_PROGRAM_CHECK_OVERRIDE_EXISTS")
outputs = [HERE / name for name in ("tests.log", "analyzer.log", "analyzer.json", "invocation.json")]
if any(path.exists() or path.is_symlink() for path in outputs):
    raise ValueError("INSTALL_PROGRAM_CHECK_OUTPUT_EXISTS")
raw = b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-Codex-Install-Program-Check-v1"\n'
paths = (SOURCE, WRAPPER, TEST)
before = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
commands = [[sys.executable, str(TEST)], ["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", "6149",
            "--json", str(outputs[2]), str(SOURCE)]]
codes = []
with override.open("xb") as stream:
    stream.write(raw)
try:
    for command, logpath in zip(commands, outputs[:2]):
        with logpath.open("x") as log:
            codes.append(subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode)
        if codes[-1]:
            break
    after = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    outputs[3].write_text(json.dumps({"commands": commands, "returncodes": codes,
        "source_before": before, "source_after": after, "source_unchanged": before == after,
        "isolated_override_unchanged": override.read_bytes() == raw,
        "override_sha256": hashlib.sha256(raw).hexdigest()}, indent=2) + "\n")
    if codes != [0, 0] or before != after:
        raise ValueError("INSTALL_PROGRAM_CHECK_REFUSAL")
finally:
    if override.read_bytes() != raw:
        raise ValueError("INSTALL_PROGRAM_CHECK_OVERRIDE_DRIFT")
    override.unlink()
print(json.dumps({"returncodes": codes, "source_unchanged": before == after, "own_override_removed": True}))
