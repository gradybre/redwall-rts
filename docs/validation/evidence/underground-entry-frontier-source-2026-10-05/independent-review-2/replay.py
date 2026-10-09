#!/usr/bin/env python3
"""Read-only independent full-box/path replay of the corrected 1188 source packet."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent
BASE = "godot/data/underground/first-entry-prefix-v1/"
NAMES = [BASE + n for n in ("compile_entry_frontier.py", "test_compile_entry_frontier.py",
                            "frontier-v2/frontier.ugfront", "frontier-v2/manifest.json")]
NAMES += ["godot/test/test_underground_entry_frontier_source.gd",
          "godot/scripts/core/underground_entry_frontier.gd",
          "godot/scripts/core/underground_connector_contacts.gd",
          "godot/data/underground/mole-worker/qualified-step-v4/mole-worker.ugprof"]


def pins():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in NAMES}


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + "\n")


def overlaps(a, b):
    return all(a[i] < b[i + 3] and b[i] < a[i + 3] for i in range(3))


def moved(box, root):
    return [box[i] + root[i % 3] for i in range(6)]


before = pins()
save("source-before.json", before)
test = subprocess.run([sys.executable, "-B", str(ROOT / BASE / "test_compile_entry_frontier.py")],
                      cwd=OUT, capture_output=True, text=True)
(OUT / "python-tests.log").write_text(test.stdout + test.stderr)
assert test.returncode == 0
spec = importlib.util.spec_from_file_location("frontier_reviewed", ROOT / BASE / "compile_entry_frontier.py")
compiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compiler)
rebuilt = compiler.build(ROOT)
assert all(raw == (ROOT / BASE / "frontier-v2" / name).read_bytes() for name, raw in rebuilt.items())
manifest = json.loads(rebuilt["manifest.json"])
for name, sha in manifest["inputs"].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == sha

# Decode the exact immutable wire independently from the author's geometry helpers.
profile = (ROOT / NAMES[-1]).read_bytes()
assert struct.unpack_from("<8sIqIII", profile) == (b"UGPROF01", 2, 3, 29, 271, 1)
rows = []
for row in range(29):
    fields = struct.unpack_from("<18i3q2B", profile, 64 + 98 * row)
    boxes = [struct.unpack_from("<7i", profile, 64 + 29 * 98 + at * 28)
             for at in range(fields[14], fields[14] + fields[15])]
    rows.append((fields, boxes))
wire = rebuilt["frontier.ugfront"]
assert len(wire) == 2212
stations = [struct.unpack_from("<9i", wire, 220 + 72 + 80 * i) for i in range(8)]
endpoint_start = 220 + 72 + 640 + 56 + 360
endpoints = [struct.unpack_from("<8iq", wire, endpoint_start + 40 * i) for i in range(10)]
episode_start = endpoint_start + 400
episodes = [struct.unpack_from("<19i", wire, episode_start + 76 * i) for i in range(6)]
cuts = [list(episode[:6]) for episode in episodes]
proof = []
volume_checks = 0
for ordinal, episode in enumerate(episodes):
    station = stations[episode[8]]
    root = station[1:4]
    assert episode[8:11] == (ordinal + 2,) * 3
    assert root == (-1536 if ordinal % 2 == 0 else 1536, 0, -512 - 1024 * (ordinal // 2))
    assert station[5] == (25 if ordinal % 2 == 0 else 17)
    assert all(endpoints[i][7:] == (12, 1) for i in (episode[15], episode[16], episode[17]))
    source_boxes = []
    for box in rows[station[5]][1]:
        actual = moved(box, root)
        source_boxes.append([*actual, box[6]])
        if box[6] <= 3:
            assert all(not overlaps(actual, cut) for cut in cuts)
            volume_checks += len(cuts)
        elif box[6] == 4 and actual[1] < 0:
            assert all(episode[i] <= actual[i] and actual[i + 3] <= episode[i + 3] for i in range(3))
        elif box[6] in (5, 6):
            assert actual[1] == actual[4] == 0
            assert all(episode[i] <= actual[i] <= actual[i + 3] < episode[i + 3] for i in (0, 2))
    gateway = (root[0], 0, 512)
    paths = []
    for selector in (episode[15], episode[16]):
        end = endpoints[selector][4:7]
        for a, b in ((end, gateway), (gateway, root)):
            sweeps = []
            for box in rows[12][1]:
                if box[6] > 3:
                    continue
                lo, hi = moved(box, a), moved(box, b)
                sweep = [min(lo[i], hi[i]) for i in range(3)] + [max(lo[i], hi[i]) for i in range(3, 6)]
                assert all(not overlaps(sweep, cut) for cut in cuts)
                volume_checks += len(cuts)
                sweeps.append([*sweep, box[6]])
            paths.append({"from": a, "to": b, "profile": 12, "full_role_sweeps": sweeps})
    proof.append({"station": root, "work_profile": station[5], "full_work_boxes": source_boxes,
                  "perimeter_legs": paths})

# The same unchanged complete footing is really unsafe at the prior station.
foot = next(box for box in rows[12][1] if box[6] == 1)
assert any(overlaps(moved(foot, (-1408, 0, -512)), cut) for cut in cuts)
assert any(overlaps(moved(foot, (-512, 0, -1024)), cut) for cut in cuts)
assert 1536 - max(abs(foot[0]), abs(foot[3])) - 1024 == 106
for key in ("current_world_qualified", "entry_workflow_qualified", "paid_handling_qualified", "traversal_qualified"):
    assert manifest[key] is False
after = pins()
assert after == before
save("source-after.json", after)
save("full-source-path-proof.json", {"checks": volume_checks, "minimum_side_foot_clearance_u": 106, "rows": proof})
save("review.json", {"accepted": True, "scope": "Static immutable source reach and complete perimeter envelope compatibility only",
                     "python_tests": 8, "byte_identical_rebuild": list(rebuilt), "volume_checks": volume_checks,
                     "input_manifest_pins": len(manifest["inputs"]), "source_unchanged": True,
                     "remaining": ["actual full-source endpoint and graph publication", "actual Contacts and paid phases",
                                   "world, worker, terrain, obstacles and current consumer qualification"]})
print("Static source review accepted;", volume_checks, "complete box/cut comparisons; all source pins unchanged")
