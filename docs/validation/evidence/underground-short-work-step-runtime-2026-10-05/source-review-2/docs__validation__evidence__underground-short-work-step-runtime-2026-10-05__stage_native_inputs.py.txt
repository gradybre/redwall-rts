#!/usr/bin/env python3
"""Copy only exact historical native inputs into this isolated checkout; never mutate their source."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[4]
BAKE = ROOT / "godot/data/underground/mole-worker/evidence/contact-qualification/high-wall-runtime-sources-v1/bake-spec.json"
BAKE_SHA = "f912989add1284bd8653ca7e071d1e5c577738e44f2e559e372fafbdaf420b86"


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1048576):
            result.update(chunk)
    return result.hexdigest()


def run(source):
    assert BAKE.stat().st_size <= 1048576 and digest(BAKE) == BAKE_SHA
    metadata = json.loads(BAKE.read_text())
    rows = [metadata["manifest"], *metadata["sources"]]
    spec = json.loads((ROOT / "godot/data/underground/mole-worker/evidence/grip-native-v2/spec.json").read_text())
    rows.append({"path": spec["basis"], "sha256": spec["basis_sha256"]})
    destination = ROOT / "godot/demo/assets"
    assert not destination.exists() and not destination.is_symlink() and len(rows) <= 600
    pending = {}
    for row in rows:
        name = row["path"]
        if name.startswith("res://demo/assets/"):
            relative = Path(name.removeprefix("res://"))
        elif name.startswith("res://.godot/imported/"):
            relative = Path("demo/assets/underground-matrices/mole-grip-v3.inputs") / (row["sha256"] + ".input")
        else:
            continue
        assert ".." not in relative.parts and len(row["sha256"]) == 64
        original = source / "godot" / relative
        assert original.is_file() and not original.is_symlink() and original.stat().st_size <= 536870912
        assert digest(original) == row["sha256"], str(original)
        pending[str(relative)] = {"source": str(original), "sha256": row["sha256"], "bytes": original.stat().st_size}
    assert len(pending) <= 256 and sum(row["bytes"] for row in pending.values()) <= 2147483648
    for relative, row in pending.items():
        target = ROOT / "godot" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with Path(row["source"]).open("rb") as src, target.open("xb") as dst:
            shutil.copyfileobj(src, dst, 1048576)
        assert digest(target) == row["sha256"]
    result = {"bake_sha256": BAKE_SHA, "rows": pending,
              "scope": "disk-only historical native inputs; no source or runtime authority substitution"}
    output = Path(__file__).parent / "native-input-stage.json"
    with output.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print(len(pending), "exact disk inputs", sum(row["bytes"] for row in pending.values()), "bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("source", type=Path)
    run(parser.parse_args().source.resolve())
