"""Independent read-only 1191 source review; all generated evidence stays in a fresh own directory."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys

SOURCE = "godot/data/underground/first-entry-prefix-v1/"
EVIDENCE = "docs/validation/evidence/underground-entry-work-area-2026-10-05/"
DIAGNOSTIC = "docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1/"
PINS = {
    SOURCE + "compile_entry_work_area.py": "efcd47c39b67004410592cf1de106eeebe2226663d1d276eab6c9b3dc7c1a164",
    SOURCE + "test_entry_work_area.py": "cd8ce2c89056dba7268f319383f1b5e3b0939bf7dbc301a7ca18163af19a46a6",
    EVIDENCE + "source-1/frontier.ugfront": "1068db6b1217e6542f6489cd56add7af52db663c756e572c86c1128e8227a058",
    EVIDENCE + "source-1/layout.json": "56e1357ba712c2bdc6f888c8668126bd43922c5ab4dfae56c03addece8064755",
    EVIDENCE + "source-1/manifest.json": "62b00025fabad7997bb9978a92a55299a1a57b27098bfefcdf512b6e663ec4d1",
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def decode_frontier(raw):
    """Use the actual fixed wire widths, independently of compiler helper functions."""
    assert raw[:8] == b"UGFRNT01" and raw[-8:] == b"UGFEND01"
    counts = list(struct.unpack_from("<6I", raw, 68))
    tables, cursor = [], 220
    for table, (count, fields) in enumerate(zip(counts, [9, 9, 7, 9, 7, 19])):
        rows = []
        for _ in range(count):
            row = list(struct.unpack_from("<" + "i" * fields, raw, cursor))
            cursor += fields * 4
            suffix = "qiqiqiq" if table == 1 else "iq" if table == 4 else ""
            if suffix:
                row += struct.unpack_from("<" + suffix, raw, cursor)
                cursor += struct.calcsize("<" + suffix)
            rows.append(row)
        tables.append(rows)
    assert cursor == len(raw) - 8
    return counts, tables


def profile_rows(raw):
    assert struct.unpack_from("<8sIqIII", raw) == (b"UGPROF01", 2, 4, 30, 281, 2)
    return [(struct.unpack_from("<18i3q2B", raw, 96 + 98 * i), None) for i in range(30)]


def boxes(raw, fields):
    return [list(struct.unpack_from("<7i", raw, 96 + 30 * 98 + 28 * i))
            for i in range(fields[14], fields[14] + fields[15])]


def contains(outer, inner):
    return all(outer[i] <= inner[i] <= inner[i + 3] <= outer[i + 3] for i in range(3))


def overlaps(first, last):
    return all(first[i] < last[i + 3] and last[i] < first[i + 3] for i in range(3))


def sweep(box, first, last):
    return [min(first[i], last[i]) + box[i] for i in range(3)] + \
        [max(first[i], last[i]) + box[i + 3] for i in range(3)]


def geometry_checks(profile, layout, table):
    rows = profile_rows(profile)
    reports = []
    for row in (2, 6, 12, 16, 29):
        fields = rows[row][0]
        volumes = boxes(profile, fields)
        air = [b for b in volumes if b[1] >= 0]
        foot = [b for b in volumes if b[1] < 0]
        complete_fit = all(contains(layout["handling_air"], b) for b in air) and \
            all(contains(layout["handling_foot"], b) for b in foot)
        assert complete_fit == (row != 12)
        reports.append({"profile": row, "source": fields[0], "yaw_mode": fields[10],
                        "yaw": fields[11], "policy": fields[22], "all_role_boxes": len(volumes),
                        "complete_fit_in_handling_area": complete_fit})
    assert rows[2][0][22] == 1 and rows[6][0][22] == 2 and rows[12][0][22] == 6
    assert rows[2][0][10:12] == rows[6][0][10:12] == (0, 0)
    assert rows[12][0][10] == 1
    assert table[4][0][4:7] == [-832, 0, 512]
    assert table[4][1][4:7] == [-832, 0, 2048] and table[4][2][4:7] == [-832, 0, 1536]
    assert table[4][1][0:7] == table[4][10][0:7] and table[4][2][0:7] == table[4][11][0:7]
    assert [table[4][i][7] for i in (0, 1, 2, 10, 11)] == [2, 2, 6, 12, 12]
    # Approaching yaw zero decreases Z; the backward retreat increases Z without changing yaw.
    assert table[4][1][6] > table[4][0][6] < table[4][2][6]
    ground = boxes(profile, rows[12][0])
    cut_boxes = [row[:6] for row in table[5]]
    bearer = [-1024, 0, 0, 1024, 128, 128]
    foot_checks, segment_count, pending_blocked = 0, 0, set()
    for path in layout["perimeter_paths"]:
        assert path["profile"] == 12
        assert path["points"][0] == table[4][path["from_selector"]][4:7]
        assert path["points"][-1] == table[4][path["to_selector"]][4:7]
        for first, last in zip(path["points"], path["points"][1:]):
            segment_count += 1
            assert sum(a != b for a, b in zip(first, last)) == 1
            for box in ground:
                swept = sweep(box, first, last)
                assert swept == sweep(box, last, first)
                if box[1] < 0:
                    assert box[4] <= 0 and all(not overlaps(swept, cut) for cut in cut_boxes)
                    foot_checks += len(cut_boxes)
            if overlaps(sweep(layout["ground_air"], first, last), bearer):
                pending_blocked.add(path["to_selector"])
    assert len(layout["perimeter_paths"]) == 12 and sorted(pending_blocked) == [4, 5]
    assert layout["retire_after_completed_cut_selectors"] == [4, 5]
    return {"profiles": reports, "perimeter_paths": 12, "axial_segments": segment_count,
            "full_negative_body_support_cut_checks": foot_checks,
            "reversible_sweeps": True, "pending_bearer_blocked_selectors": sorted(pending_blocked)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    assert not args.output.resolve().is_relative_to(root), "review output must be outside subject worktree"
    manifests = [SOURCE + "structural-v1/manifest.json", SOURCE + "frontier-v2/manifest.json",
                 DIAGNOSTIC + "manifest.json", EVIDENCE + "static-review-1/source-sha256.json"]
    paths = set(PINS) | set(manifests)
    paths.update(SOURCE + name for name in ("rebind_handling_diagnostic.py", "compile_entry_frontier.py", "compile_entry_prefix.py"))
    paths.add("docs/decisions/1191-original-entry-work-area-and-contact-retirement.md")
    for path in manifests[:3]:
        manifest = json.loads((root / path).read_bytes())
        paths.update(manifest["inputs"])
        paths.update(str(Path(path).parent / name) for name in manifest["outputs"])
        for name, digest in manifest["inputs"].items():
            assert sha((root / name).read_bytes()) == digest, name
    for name in PINS:
        paths.add(EVIDENCE + "static-review-1/source/" + name + ".txt")
    captured = {path: (root / path).read_bytes() for path in sorted(paths)}
    before = {path: sha(raw) for path, raw in captured.items()}
    for name, digest in PINS.items():
        assert before[name] == digest and before[EVIDENCE + "static-review-1/source/" + name + ".txt"] == digest
    (args.output / "source-before.json").write_text(json.dumps(before, indent=2) + "\n")
    command = [sys.executable, "-B", str(root / (SOURCE + "test_entry_work_area.py")), "-v"]
    result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (args.output / "tests.log").write_bytes(result.stdout)
    assert result.returncode == 0, "independent tests failed"
    spec = importlib.util.spec_from_file_location("reviewed_work_area", root / (SOURCE + "compile_entry_work_area.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    profile = captured[DIAGNOSTIC + "mole-worker.ugprof"]
    packet = module.build(profile)
    for name, raw in packet.items():
        assert raw == captured[EVIDENCE + "source-1/" + name], name
        (args.output / name).write_bytes(raw)
    counts, table = decode_frontier(packet["frontier.ugfront"])
    old = captured[DIAGNOSTIC + "frontier.ugfront"]
    old_counts, old_table = decode_frontier(old)
    expected = [[list(row) for row in rows] for rows in old_table]
    expected[4][0][4:7] = [-832, 0, 512]
    expected[4][1][4:7] = [-832, 0, 2048]
    expected[4][2][4:7] = [-832, 0, 1536]
    expected[4] += [expected[4][1].copy(), expected[4][2].copy()]
    for index, value in zip((0, 1, 2, 10, 11), (2, 2, 6, 12, 12)):
        expected[4][index][7] = value
    expected[0][0][8] = 2
    for row in expected[5]:
        row[15:17] = [10, 11]
    assert table == expected
    expected_header = bytearray(old[:220])
    struct.pack_into("<q", expected_header, 12, 2)
    struct.pack_into("<6I", expected_header, 68, *counts)
    assert packet["frontier.ugfront"][:220] == expected_header
    assert counts == [2, 8, 2, 10, 12, 6] and old_counts == [2, 8, 2, 10, 10, 6]
    widths = [36, 80, 28, 36, 40, 76]
    assert 2048 + sum(a * b for a, b in zip(counts, widths)) == 4112
    assert 220 + sum(a * b for a, b in zip(counts, widths)) + 8 == 2292
    layout = json.loads(packet["layout.json"])
    geometry = geometry_checks(profile, layout, table)
    after = {path: sha((root / path).read_bytes()) for path in captured}
    assert before == after, "subject input drift"
    (args.output / "source-after.json").write_text(json.dumps(after, indent=2) + "\n")
    verdict = {"scope": "Diagnostic pure source compiler and finite static geometry only",
               "source_pins": PINS, "tests": 8, "test_exit": result.returncode, "command": command,
               "captured_inputs_unchanged": len(before), "saved_outputs_byte_equal": True,
               "only_declared_frontier_delta": True, "all_source_artifacts_unchanged": True,
               "geometry": geometry, "reader_bank_bytes": 4112, "frontier_bytes": 2292,
               "engine_run": False, "native_qualified": False, "paid_execution_qualified": False,
               "world_activation_qualified": False}
    (args.output / "review.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict, indent=2))


if __name__ == "__main__":
    main()
