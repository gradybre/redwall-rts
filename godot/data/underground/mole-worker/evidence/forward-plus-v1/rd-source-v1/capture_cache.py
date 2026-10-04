#!/usr/bin/env python3
"""Capture the accepted native witness in a new user directory, then retain its exact shader caches.

No current Actor/Profile source is patched. The existing actual Metal helper
still owns every native assertion. A cache is provenance evidence, not a GPU
arithmetic or physical clearance certificate.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
BASE = HERE.parent
HELPER = BASE / "native_forward_actor.gd"
HELPER_SHA = "3d2d50dc000ae34574e806a4bc04de86660b1eedc8fcc662e6f15d26dab104f0"
BASIS_SHA = "bc8061e73781f2851c85d0c0e9868b24bc2c99e733ccfcfe8ab5717d5570bbf1"
OLD_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
ENGINE = "ed1daf0bf001b61586d9930840f2f1394092c079"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def pins():
    """Pin every current project script, including transitive test/owner sources; no historical override."""
    paths = sorted((ROOT / "godot").rglob("*.gd"))
    require(0 < len(paths) <= 4096 and sum(p.stat().st_size for p in paths) <= 32 * 1024 * 1024,
            "NATIVE_CACHE_SOURCE_CAPACITY")
    paths += [ROOT / "tools/bake_underground_world_basis.gd", Path(__file__),
              BASE / "focused-v3/forward.ugyaw", ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"]
    paths += sorted((HERE / "engine-source").iterdir())
    return {str(path.relative_to(ROOT)): sha(path) for path in paths}


def validate_report(report, raw, image):
    """Keep exact positive assertion/lifecycle/backend evidence and reject raw failures regardless of exit code."""
    require(report.get("qualified_profiles") == 0 and report.get("world_qualified") is False and
            report.get("complete_numerical_enclosure") is False and report.get("failures") == [] and
            report.get("assertions") == 43 and report.get("attachment_cycles") == 2, "NATIVE_CACHE_REPORT_SCOPE")
    engine = report.get("engine", {})
    require(engine.get("hash") == ENGINE and engine.get("build") == "official" and
            (engine.get("major"), engine.get("minor"), engine.get("patch")) == (4, 7, 2), "NATIVE_CACHE_ENGINE")
    require((report.get("rendering_driver"), report.get("rendering_method"), report.get("display_server"),
             report.get("api_version")) == ("metal", "forward_plus", "macOS", "4.0"), "NATIVE_CACHE_BACKEND")
    require(report.get("basis_sha256") == BASIS_SHA and report.get("image_sha256") == sha(image), "NATIVE_CACHE_OUTPUT")
    require("native-forward: 45 assertions, 0 failures;" in raw and
            re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:)|ObjectDB instances leaked|resources still in use", raw) is None,
            "NATIVE_CACHE_DIAGNOSTICS")


def copy_caches(user, output):
    """Only the two exact built-in shader families are relevant; every produced file is retained in full."""
    paths = []
    for family in ("SkeletonShaderRD", "SceneForwardClusteredShaderRD"):
        group = user / "shader_cache" / family
        require(group.is_dir(), "NATIVE_CACHE_FAMILY_MISSING")
        paths += sorted(group.rglob("*.metal.cache"))
    require(1 <= len(paths) <= 8, "NATIVE_CACHE_FILE_CAPACITY")
    rows = []
    raw_dir = output / "raw"
    raw_dir.mkdir()
    for index, path in enumerate(paths):
        require(not path.is_symlink() and 0 < path.stat().st_size <= 4 * 1024 * 1024, "NATIVE_CACHE_BYTE_CAPACITY")
        expected = sha(path)
        with path.open("rb") as stream:
            data = stream.read(4 * 1024 * 1024 + 1)
        require(0 < len(data) <= 4 * 1024 * 1024 and hashlib.sha256(data).hexdigest() == expected,
                "NATIVE_CACHE_COPY_DRIFT")
        relative = "raw/%02d-%s.cache" % (index, expected)
        with (output / relative).open("xb") as stream:
            stream.write(data)
        require(sha(path) == expected, "NATIVE_CACHE_COPY_DRIFT")
        rows.append({"file": relative, "sha256": expected, "bytes": len(data),
                     "original_relative_path": str(path.relative_to(user))})
    return rows


def capture(output):
    require(not output.is_symlink() and not output.exists(), "NATIVE_CACHE_OUTPUT_EXISTS")
    output = output.resolve()
    require(not output.exists(), "NATIVE_CACHE_OUTPUT_EXISTS")
    require((ROOT / "godot/project.godot").is_file() and sha(HELPER) == HELPER_SHA, "NATIVE_CACHE_SOURCE_ROOT")
    old = ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
    basis = BASE / "focused-v3/forward.ugyaw"
    require(sha(old) == OLD_SHA and sha(basis) == BASIS_SHA, "NATIVE_CACHE_BASIS_SOURCE")
    name = "Redwall-Codex-Metal-Cache-" + hashlib.sha256(str(output).encode()).hexdigest()[:16]
    user = Path.home() / "Library/Application Support" / name
    override = ROOT / "godot/override.cfg"
    require(not user.exists() and not user.is_symlink() and not override.exists() and not override.is_symlink(),
            "NATIVE_CACHE_EXISTING_USER_OR_OVERRIDE")
    before, project = pins(), sha(ROOT / "godot/project.godot")
    output.mkdir()
    (output / "source-before.json").write_text(json.dumps(before, indent=2) + "\n")
    command = ["godot", "--path", "godot", "--script", str(HELPER), "--", str(basis), BASIS_SHA,
               "df6bb71866a5839815b112f544348b6ca436020bb56d9c46293455f817d5e018",
               str(output / "metal.png"), str(output / "native-report.json"), str(old)]
    record = {"command": command, "user_directory": str(user), "cache_initially_absent": True,
              "scope": "fresh native synthetic attachment witness and generated shader-source provenance"}
    try:
        override.write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n')
        override_sha = sha(override)
        with (output / "native.log").open("x") as log:
            run = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        record["exit"] = run.returncode
        require(run.returncode == 0, "NATIVE_CACHE_EXIT")
        report = json.loads((output / "native-report.json").read_text())
        validate_report(report, (output / "native.log").read_text(), output / "metal.png")
        require(sha(override) == override_sha, "NATIVE_CACHE_OVERRIDE_DRIFT")
        rows = copy_caches(user, output)
        engine_output = output / "engine-source"
        engine_output.mkdir()
        for source in sorted((HERE / "engine-source").iterdir()):
            with (engine_output / source.name).open("xb") as stream:
                stream.write(source.read_bytes())
        (output / "cache-manifest.json").write_text(json.dumps({"schema": 1, "caches": rows}, indent=2) + "\n")
        record["cache_files"] = len(rows)
    finally:
        override.unlink(missing_ok=True)
        after = pins()
        (output / "source-after.json").write_text(json.dumps(after, indent=2) + "\n")
        record.update(source_unchanged=before == after, project_unchanged=sha(ROOT / "godot/project.godot") == project,
                      override_restored=not override.exists())
        (output / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    require(record["source_unchanged"] and record["project_unchanged"] and record["override_restored"], "NATIVE_CACHE_FINAL_DRIFT")
    print(json.dumps(record))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    capture(parser.parse_args().out)
