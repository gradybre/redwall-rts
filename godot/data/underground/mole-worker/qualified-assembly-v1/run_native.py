#!/usr/bin/env python3
"""Isolated create-only actual assembly image replay, with independent binary32 matrix and track audit."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import shutil

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
CONTACT = HERE.parent / "evidence/contact-qualification"
DEPENDENCIES = {
    HERE.parent / "work-approach-v1/run_canonical.py": "7d36f92546ce19604a0c2a59422a46675c270c4ff73da3992f2e86ccbb951281",
    CONTACT / "run_high_wall.py": "dc848d1f5bf150db287438f8a2b0b5210b35ce64b2c221df2ebd48ba8fc519a1",
    CONTACT / "run_capture.py": "52ae01f1e88d6b9a839381d896f7908e97ba2bacd65702870f00ae71d3aaca2b",
}
for path, sha in DEPENDENCIES.items():
    if not path.is_file() or path.is_symlink() or path.stat().st_size > 1048576 or hashlib.sha256(path.read_bytes()).hexdigest() != sha:
        raise ValueError("ASSEMBLY_NATIVE_DEPENDENCY")
SPEC = importlib.util.spec_from_file_location("assembly_native_predecessor", HERE.parent / "work-approach-v1/run_canonical.py")
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)
COUNTS = (55, 2, 55)
FIRST = (0, 55, 57)
ORIGIN = (16384, -4608, 8192)
BOXES = ((-192, 0, -512, 1856, 128, -384), (-256, 0, -512, 256, 128, -384))
ONE = 65536
SAMPLES = 5634


def events():
    """Expected order and phase derive only from the finite protocol, never the native report."""
    for assembly in range(2):
        for view in ("side", "opposite", "rts"):
            for reverse in (False, True):
                for clip in ((2, 1, 0) if reverse else (0, 1, 2)):
                    duration = (COUNTS[clip]-1)*ONE
                    for step in range((COUNTS[clip]-1)*4+1):
                        q = duration-step*16384 if reverse else step*16384
                        a = FIRST[clip]+q//ONE
                        frames = [a, a if q == duration else a+1, q % ONE]
                        yield {"assembly": assembly, "view": view, "reverse": reverse, "clip": clip,
                               "q16": q, "frames": frames, "bearer_offset_z_u": 0,
                               "kind": "quarter", "tick": -1}
            for tick in range(61):
                clip = 0 if tick < 30 else 2
                q = ((tick if tick < 30 else tick-30)*54*ONE)//30
                a = FIRST[clip]+q//ONE
                duration = (COUNTS[clip]-1)*ONE
                yield {"assembly": assembly, "view": view, "reverse": False, "clip": clip,
                       "q16": q, "frames": [a, a if q == duration else a+1, q % ONE],
                       "bearer_offset_z_u": 0, "kind": "clock", "tick": tick}


def source_arrays(spec):
    raw = P.bounded(P.B.actual(spec["content"]), 262144)
    P.need(hashlib.sha256(raw).hexdigest() == spec["content_sha256"] and raw[:8] == b"UGACNT01" and
           struct.unpack_from("<6I", raw, 8) == (1, 1178, 2, 3, 112, 300) and
           len(raw) == 135328 and raw[-8:] == b"UGAEND01", "ASSEMBLY_NATIVE_IMAGE")
    table = [struct.unpack_from("<4I", raw, 328+i*48) for i in range(3)]
    P.need(table == [(FIRST[i], COUNTS[i], 0, (COUNTS[i]-1)*ONE) for i in range(3)], "ASSEMBLY_NATIVE_TIMING")
    matrix = np.frombuffer(raw, dtype="<f4", count=112*300, offset=472).reshape(112, 25, 12)
    ground = np.frombuffer(raw, dtype="<f4", count=112, offset=472+112*300*4)
    P.need(np.isfinite(matrix).all() and np.isfinite(ground).all(), "ASSEMBLY_NATIVE_FINITE_SOURCE")
    ready = hashlib.sha256(matrix[0].tobytes()+ground[:1].tobytes()).hexdigest()
    P.need(ready == "393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462" and
           np.array_equal(matrix[0], matrix[-1]) and np.array_equal(matrix[54], matrix[55]) and
           np.array_equal(matrix[55], matrix[56]) and np.array_equal(matrix[56], matrix[57]) and
           np.all(ground == ground[0]), "ASSEMBLY_NATIVE_JOINS")
    return matrix, ground


def screen_name(row):
    direction = "reverse" if row["reverse"] else "forward"
    return f'a{row["assembly"]}-{row["view"]}-{direction}-c{row["clip"]}-q{row["q16"]}.png'


def validate(out):
    spec = P.json_read(out/"spec.json", 65536)
    report = P.json_read(out/"report.json", 8*1024*1024)
    P.need(report.get("schema") == 1 and report.get("content_sha256") == spec["content_sha256"] and
           report.get("poses") == SAMPLES and report.get("matrix_count") == 27 and
           report.get("resolution") == [1280, 720] and report.get("failures") == [] and
           report.get("assertions", 0) >= 4*SAMPLES and report.get("production_qualified") is False and
           report.get("user_directory", "").endswith("/"+spec["user_directory_name"]), "ASSEMBLY_NATIVE_REPORT")
    expected_events = list(events())
    P.need(report.get("events") == expected_events, "ASSEMBLY_NATIVE_EVENTS")
    raw = P.bounded(out/"native.bin", 8*1024*1024)
    P.need(raw[:8] == b"UGASMN01" and len(raw) == 8+SAMPLES*27*12*4 and
           hashlib.sha256(raw).hexdigest() == report.get("native_sha256"), "ASSEMBLY_NATIVE_BYTES")
    observed = np.frombuffer(raw, dtype="<f4", offset=8).reshape(SAMPLES, 27, 12)
    P.need(np.isfinite(observed).all(), "ASSEMBLY_NATIVE_FINITE")
    matrix, ground = source_arrays(spec)
    basis = P.bounded(P.B.actual(spec["basis"]), 1048576)
    P.need(hashlib.sha256(basis).hexdigest() == spec["basis_sha256"], "ASSEMBLY_NATIVE_BASIS")
    cs = struct.unpack_from("<ff", basis, len(basis)-65536*8-8)
    identity = np.array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype=np.float32)
    for at, row in enumerate(expected_events):
        a, b, share = row["frames"]
        values = (matrix[a].astype(np.float64)*(1-share/ONE)+matrix[b].astype(np.float64)*(share/ONE)).astype(np.float32)
        y = np.float32(float(ground[a])*(1-share/ONE)+float(ground[b])*(share/ONE))
        expected = np.empty((27, 12), dtype=np.float32)
        expected[:24] = values[:24]
        expected[24] = P.world_matrix(values[24], y, ORIGIN, cs)
        expected[25] = P.world_matrix(identity, y, ORIGIN, cs)
        expected[26] = identity
        box = BOXES[row["assembly"]]
        expected[26, 9:] = [(ORIGIN[axis]+(box[axis]+box[axis+3])/2+
                            (row["bearer_offset_z_u"] if axis == 2 else 0))/1024 for axis in range(3)]
        P.need(np.array_equal(observed[at].view(np.uint32), expected.view(np.uint32)), "ASSEMBLY_NATIVE_MATRIX:"+str(at))
    shots = {screen_name(row): row for row in expected_events if row["kind"] == "quarter" and row["q16"] in
             (0, (COUNTS[row["clip"]]-1)*ONE//2, (COUNTS[row["clip"]]-1)*ONE)}
    actual_shots = report.get("screenshots")
    P.need(type(actual_shots) is list and len(actual_shots) == len(shots) == 108 and
           {row.get("path") for row in actual_shots} == set(shots), "ASSEMBLY_NATIVE_SCREENS")
    for row in actual_shots:
        raw = P.bounded(out/row["path"], 4194304)
        P.need(raw[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack_from(">II", raw, 16) == (1280, 720) and
               hashlib.sha256(raw).hexdigest() == row["sha256"], "ASSEMBLY_NATIVE_SCREEN_SOURCE")
    return {"sampled_poses": SAMPLES, "exact_native_scalars": SAMPLES*27*12, "screenshots": len(shots),
            "assemblies": 2, "views": 3, "directions": 2, "intervals": 109,
            "scope": "Actual source image/native palette/grounding/held-pick/complete-bearer track. Quarter-Q16 sampling is not the continuous proof, physical World admission or adopted rate.",
            "production_qualified": False}


def run(out, compiled):
    P.need(not out.exists() and not out.is_symlink(), "ASSEMBLY_NATIVE_OUTPUT_EXISTS")
    out, compiled = out.resolve(), compiled.resolve()
    P.need(compiled.is_relative_to(HERE), "ASSEMBLY_NATIVE_COMPILED_SCOPE")
    compilation = P.json_read(compiled/"compilation.json", 65536)
    script, bake = HERE/"capture_assembly.gd", CONTACT/"high-wall-runtime-sources-v1/bake-spec.json"
    pins, historical = P.source_pins(script, bake)
    for path in [Path(__file__), HERE/"handling_clock.gd", *DEPENDENCIES, *(compiled/name for name in
                 ("mole-worker.ugactor", "candidate.json", "plan.json", "compilation.json"))]:
        pins[str(path)] = P.B.digest(path)
    spec = P.json_read(HERE.parent/"evidence/grip-native-v2/spec.json", 65536)
    name = "Redwall-Codex-Assembly-"+hashlib.sha256(str(out).encode()).hexdigest()[:16]
    spec.update(content="res://"+str((compiled/"mole-worker.ugactor").relative_to(ROOT/"godot")),
                content_sha256=compilation["content_sha256"], reserve_bytes=compilation["presentation_budget"]["admitted_peak_bytes"],
                user_directory_name=name, production_qualified=False)
    source_arrays(spec)
    override = ROOT/"godot/override.cfg"
    P.need(not override.exists() and not override.is_symlink(), "ASSEMBLY_NATIVE_OVERRIDE_EXISTS")
    override_raw = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+name+'"\n').encode()
    out.mkdir(parents=True)
    (out/".gdignore").touch()
    (out/"spec.json").write_text(json.dumps(spec, indent=2)+"\n")
    (out/"capture_assembly.gd.txt").write_bytes(script.read_bytes())
    (out/"run_native.py.txt").write_bytes(Path(__file__).read_bytes())
    (out/"sources-before.json").write_text(json.dumps(pins, indent=2)+"\n")
    (out/"historical-producer-current-executable-distinction.json").write_text(json.dumps(historical, indent=2)+"\n")
    commands = [["godot", "--headless", "--path", "godot", "--editor", "--quit", "--log-file", str(out/"engine-import.log")],
                ["godot", "--path", "godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                 "--fixed-fps", "60", "--log-file", str(out/"engine-native.log"), "--script", str(script), "--", str(out/"spec.json"), str(out)]]
    results = []
    sidecars = {p: p.read_bytes() for p in (ROOT/"godot").rglob("*.import")}
    cache, cache_backup = ROOT/"godot/.godot", out/".cache-backup"
    P.need(not cache.is_symlink() and (not cache.exists() or cache.is_dir()), "ASSEMBLY_NATIVE_CACHE_SCOPE")
    had_cache = cache.exists()
    if had_cache: cache.rename(cache_backup)
    with override.open("xb") as stream:
        stream.write(override_raw)
    try:
        for at, command in enumerate(commands):
            if at == 1:
                restored = P.H.restore_pinned_imports(bake, ROOT/"godot/demo/assets/underground-matrices/mole-grip-v3.inputs", ROOT)
                (out/"import-cache-restoration.json").write_text(json.dumps(restored, indent=2)+"\n")
            log = out/("import.log" if at == 0 else "native.log")
            with log.open("x") as stream:
                code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600).returncode
            engine_log = out/("engine-import.log" if at == 0 else "engine-native.log")
            bad = bool(P.B.DIAGNOSTIC.search(log.read_text())) or not engine_log.is_file() or bool(P.B.DIAGNOSTIC.search(engine_log.read_text()))
            results.append({"command": command, "exit": code, "raw_diagnostic": bad})
            P.need(code == 0 and not bad, "ASSEMBLY_NATIVE_ENGINE:"+str(at))
        (out/"verification.json").write_text(json.dumps(validate(out), indent=2)+"\n")
    finally:
        if cache.exists(): shutil.rmtree(cache)
        if had_cache: cache_backup.rename(cache)
        removed = P.restore_sidecars(ROOT/"godot", sidecars)
        (out/"generated-import-sidecars.json").write_text(json.dumps(removed, indent=2)+"\n")
        after = {p: P.B.digest(Path(p)) if Path(p).is_file() else None for p in pins}
        (out/"sources-after.json").write_text(json.dumps(after, indent=2)+"\n")
        restored = override.is_file() and override.read_bytes() == override_raw
        if restored: override.unlink()
        (out/"invocation.json").write_text(json.dumps({"commands": results, "source_unchanged": pins == after,
            "override_restored": restored, "import_sidecars_restored": True,
            "original_cache_restored": cache.exists() == had_cache and not cache_backup.exists(),
            "production_qualified": False}, indent=2)+"\n")
        P.need(pins == after and restored, "ASSEMBLY_NATIVE_RESTORATION")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--compiled", type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        print(json.dumps(validate(args.out), indent=2))
    else:
        P.need(args.compiled is not None, "ASSEMBLY_NATIVE_COMPILED_REQUIRED")
        run(args.out, args.compiled)
