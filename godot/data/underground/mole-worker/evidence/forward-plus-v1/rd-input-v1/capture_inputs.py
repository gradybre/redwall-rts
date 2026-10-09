#!/usr/bin/env python3
"""Create-only actual Mole RD input capture; no current renderer/profile source is modified."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
CONTACT = HERE.parents[1] / "contact-qualification"
BAKE = CONTACT / "published-native-runtime-sources-v1/bake-spec.json"
BAKE_SHA = "a3e6e55ed0ea158606ed649983920d8f0198d020c70aff5cc519c06d16c45674"
SCRIPT = ROOT / "tools/capture_underground_metal_inputs.gd"
CONTENT = CONTACT / "install-program-compile-v3/result/mole-worker.ugactor"
CONTENT_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
TOPOLOGY = CONTACT / "topology-v5/topology.json"
TOPOLOGY_SHA = "da623e5c7c3c5a6aff5c466b143425422f3aa2253497527c84f713738f997b42"
MANIFEST_SHA = "ce3206671b74b1602f23e992b648d4093ea8c51fc259b0e13c1769b8facbbf37"
BAD = r"(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:)|ObjectDB instances? (?:were|was) leaked|resources still in use"


def require(value, code):
    if not value:
        raise ValueError(code)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def actual(name):
    original = Path("/Users/brendan/Developer/redwall-rts/assets/library")
    if name.startswith(str(original) + "/"):
        name = str(ROOT / "assets/library" / Path(name).relative_to(original))
    path = ROOT / "godot" / name[6:] if name.startswith("res://") else Path(name)
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(ROOT), "INPUT_CAPTURE_SOURCE_PATH")
    return path.resolve()


def source_pins(imports=False):
    """Accepted raw/import asset identities plus all current executable scripts; neither replaces the other."""
    require(sha(BAKE) == BAKE_SHA and sha(CONTENT) == CONTENT_SHA and sha(TOPOLOGY) == TOPOLOGY_SHA,
            "INPUT_CAPTURE_IMMUTABLE_SOURCE")
    result = {}
    for row in [json.loads(BAKE.read_text())["manifest"], *json.loads(BAKE.read_text())["sources"]]:
        name = row["path"]
        if name.endswith(".gd") or (not imports and name.startswith("res://.godot/")):
            continue
        path = actual(name)
        require(sha(path) == row["sha256"], "INPUT_CAPTURE_ASSET_SOURCE")
        result[str(path)] = row["sha256"]
    paths = list((ROOT / "godot").rglob("*.gd")) + [SCRIPT, Path(__file__), BAKE, CONTENT, TOPOLOGY,
            ROOT / "tools/audit_underground_metal_inputs.py", ROOT / "tools/test_audit_underground_metal_inputs.py",
            CONTACT / "run_high_wall.py", CONTACT / "run_capture.py"]
    paths += list((HERE / "engine-source").iterdir())
    paths += list((HERE.parent / "engine-source").iterdir())
    require(len(paths) <= 4096 and sum(p.stat().st_size for p in paths) <= 32*1024*1024, "INPUT_CAPTURE_SOURCE_CAPACITY")
    for path in paths:
        result[str(actual(str(path)))] = sha(path)
    require(len(result) <= 4096, "INPUT_CAPTURE_SOURCE_CAPACITY")
    return result


def report_refusal(report, spec, raw):
    """A zero process exit is insufficient: require a complete positive real census and explicit nonpermission."""
    require(report.get("error") == "" and report.get("failures") == [] and
            type(report.get("assertions")) is int and report["assertions"] == 8 and
            complete_census(report) and
            report.get("content_sha256") == CONTENT_SHA and report.get("spec_sha256") == spec and
            report.get("qualified_profiles") == 0 and report.get("gpu_arithmetic_qualified") is False and
            report.get("world_qualified") is False, "INPUT_CAPTURE_REPORT")
    require((report.get("driver"), report.get("method"), report.get("display")) == ("metal", "forward_plus", "macOS") and
            report.get("engine", {}).get("hash") == "ed1daf0bf001b61586d9930840f2f1394092c079", "INPUT_CAPTURE_BACKEND")
    require(not re.search(BAD, raw), "INPUT_CAPTURE_DIAGNOSTICS")


def complete_census(report):
    meshes, rows = report.get("meshes"), report.get("rows")
    if type(meshes) is not list or not 2 <= len(meshes) <= 4 or type(rows) is not list:
        return False
    if any(type(row) is not dict for row in meshes + rows):
        return False
    if [(m.get("part"), m.get("vertices"), m.get("surfaces"), m.get("shadow_of")) for m in meshes[:2]] != \
            [(0, 17172, 1, -1), (1, 1176, 1, -1)]:
        return False
    if any(type(m.get("vertices")) is not int or not 1 <= m["vertices"] <= 32768 or
           type(m.get("surfaces")) is not int or not 1 <= m["surfaces"] <= 8 for m in meshes):
        return False
    return report.get("surfaces") == len(rows) == sum(m["surfaces"] for m in meshes) and \
        report.get("vertices") == sum(m["vertices"] for m in meshes)


def audit_capture(output, report, spec):
    """Complete independent byte/topology/auxiliary audit must agree with the actual capture's census."""
    loader = importlib.util.spec_from_file_location("actual_metal_input_audit", ROOT / "tools/audit_underground_metal_inputs.py")
    module = importlib.util.module_from_spec(loader)
    loader.loader.exec_module(module)
    with (output / "inputs.bin").open("rb") as stream:
        result = module.audit(stream, report["inputs_sha256"], spec, module.content_parts(CONTENT),
                              json.loads(TOPOLOGY.read_text())["parts"])
    for key in ("surfaces", "vertices", "numeric_bytes"):
        require(report.get(key) == result[key], "INPUT_CAPTURE_AUDIT_CENSUS")
    require(len(report["meshes"]) == len(result["parts"]), "INPUT_CAPTURE_AUDIT_CENSUS")
    for native, audited in zip(report["meshes"], result["parts"]):
        require(native.get("mesh_sha256") == audited["sha256"] and
                all(native.get(key) == audited[key] for key in ("part", "shadow_of", "has_shadow", "vertices", "surfaces", "fingerprint_kind")),
                "INPUT_CAPTURE_AUDIT_IDENTITY")
    result["topology_sha256"], result["auditor_sha256"] = TOPOLOGY_SHA, sha(ROOT / "tools/audit_underground_metal_inputs.py")
    with (output / "audit.json").open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")


def capture(output):
    require(not output.exists() and not output.is_symlink(), "INPUT_CAPTURE_OUTPUT_EXISTS")
    output = output.resolve()
    override = ROOT / "godot/override.cfg"
    name = "Redwall-Codex-Metal-Inputs-" + hashlib.sha256(str(output).encode()).hexdigest()[:16]
    user = Path.home() / "Library/Application Support" / name
    require(not override.exists() and not override.is_symlink() and not user.exists() and not user.is_symlink(),
            "INPUT_CAPTURE_EXISTING_OVERRIDE_OR_USER")
    before, project = source_pins(), sha(ROOT / "godot/project.godot")
    output.mkdir()
    (output / "source-before-import.json").write_text(json.dumps(before, indent=2)+"\n")
    text = '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n'
    record, after_native = {"user_directory": str(user), "commands": [], "qualified_profiles": 0}, None
    try:
        with override.open("x") as stream:
            stream.write(text)
        command = ["godot", "--headless", "--path", "godot", "--editor", "--quit"]
        run(command, output / "import.log", record)
        require(source_pins() == before, "INPUT_CAPTURE_IMPORT_SOURCE_DRIFT")
        loader = importlib.util.spec_from_file_location("accepted_import_replay", CONTACT / "run_high_wall.py")
        restore = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(restore)
        imports = restore.restore_pinned_imports(BAKE, ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.inputs", ROOT)
        (output / "restored-imports.json").write_text(json.dumps(imports, indent=2)+"\n")
        pins = source_pins(True)
        spec = {"schema": 1, "content": str(CONTENT), "content_sha256": CONTENT_SHA, "reserve_bytes": 7141920,
                "manifest": "res://demo/assets/manifest.json", "manifest_sha256": MANIFEST_SHA, "source_pins": pins}
        encoded = (json.dumps(spec, indent=2)+"\n").encode()
        require(len(encoded) <= 524288, "INPUT_CAPTURE_SPEC_CAPACITY")
        with (output / "spec.json").open("xb") as stream:
            stream.write(encoded)
        command = ["godot", "--path", "godot", "--rendering-method", "forward_plus", "--rendering-driver", "metal",
                   "--audio-driver", "Dummy", "--script", str(SCRIPT), "--", str(output / "spec.json"),
                   hashlib.sha256(encoded).hexdigest(), str(output)]
        run(command, output / "native.log", record)
        report = json.loads((output / "report.json").read_text())
        report_refusal(report, hashlib.sha256(encoded).hexdigest(), (output / "native.log").read_text())
        require(report.get("inputs_sha256") == sha(output / "inputs.bin"), "INPUT_CAPTURE_DATA_HASH")
        audit_capture(output, report, hashlib.sha256(encoded).hexdigest())
        after_native = source_pins(True)
        require(after_native == pins and sha(override) == hashlib.sha256(text.encode()).hexdigest(), "INPUT_CAPTURE_FINAL_DRIFT")
        record["source_unchanged"] = True
    finally:
        require(override.read_text() == text, "INPUT_CAPTURE_OVERRIDE_DRIFT")
        override.unlink()
        record.update(project_unchanged=sha(ROOT / "godot/project.godot") == project,
                      override_restored=not override.exists(), source_after_import_unchanged=source_pins() == before)
        if after_native is not None:
            (output / "source-after-native.json").write_text(json.dumps(after_native, indent=2)+"\n")
        (output / "invocation.json").write_text(json.dumps(record, indent=2)+"\n")
    require(record["project_unchanged"] and record["source_after_import_unchanged"], "INPUT_CAPTURE_RESTORE_DRIFT")
    print(json.dumps(record))


def run(command, log, record):
    record["commands"].append(command)
    with log.open("x") as stream:
        code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600).returncode
    record[log.stem + "_exit"] = code
    require(code == 0 and not re.search(BAD, log.read_text()), "INPUT_CAPTURE_COMMAND_OR_DIAGNOSTICS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    capture(parser.parse_args().out)
