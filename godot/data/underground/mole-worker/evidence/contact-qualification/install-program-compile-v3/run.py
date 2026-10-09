#!/usr/bin/env python3
"""Reproduce the source-only INSTALL program with create-only evidence and explicit NumPy runtime."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
SOURCE = HERE.parent / "author_install_program.py"
TEST = HERE.parent / "test_install_program.py"
paths = (SOURCE, TEST)
before = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
outputs = [HERE / name for name in ("tests.log", "compile.log", "invocation.json", "result")]
if any(path.exists() or path.is_symlink() for path in outputs):
    raise ValueError("INSTALL_PROGRAM_RUN_EXISTS")
commands = [[sys.executable, str(TEST)], [sys.executable, str(SOURCE), str(HERE / "result")]]
codes = []
for command, log in zip(commands, outputs[:2]):
    with log.open("x") as stream:
        codes.append(subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1800).returncode)
    if codes[-1]:
        break
after = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
(HERE / "invocation.json").write_text(json.dumps({"commands": commands, "returncodes": codes,
    "source_before": before, "source_after": after, "source_unchanged": before == after}, indent=2) + "\n")
print(json.dumps({"returncodes": codes, "source_unchanged": before == after}), flush=True)
raise SystemExit(0 if codes == [0, 0] and before == after else 2)
