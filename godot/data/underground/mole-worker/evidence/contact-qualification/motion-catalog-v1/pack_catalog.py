#!/usr/bin/env python3
"""Wrap exact accepted source-only tables; no native, source qualification or pace grant."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

P = Path("godot/data/underground/mole-worker/evidence/contact-qualification")
FIXTURE = "docs/design/underground-planning/first-entry-prefix-v1.json"
PINNED = {
    str(P / "stair-program-v1/candidate-4/result/program.json"): "1f00fdfd773b129af04d5bd9a6eae0c20cca604959777221bae4b23f7fd91983",
    str(P / "stair-program-v1/candidate-4/result/stair-program.ugstep"): "c966b64608b0308cca2e54973aeb72dd55a2b5b4e59f0b834517933667b50ee8",
    str(P / "stair-handoffs-v1/column-proposal-v2/result/program.json"): "34a62009ebefa9055444353a900abb24b5a225f10ee91dd81899292fe597177f",
    str(P / "stair-handoffs-v1/candidate-6/result/candidate.json"): "e639a9500b8cbac23e1665f7a26477b83a0b971ad7c4c26ab3eb4818d9d01d49",
    FIXTURE: "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81",
}
PROFILE_SHA = "b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac"
LEVEL_SHA = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
READY_SHA = "393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462"
GAIT_SHAPES = [("DESC", 2, 12), ("ROOT", 182, 3), ("STEP", 180, 4), ("BOXE", 348, 6),
               ("SUPP", 122, 8), ("SIDX", 180, 1), ("SOLI", 44, 6)]
HANDOFF_SHAPES = [("PROGRAM", 3, 8), ("KEY", 453, 5), ("INTERVAL", 450, 6), ("BOX", 681, 6),
                  ("SUPPORT", 306, 8), ("SUPPORT_REF", 450, 1), ("SOLID", 22, 6)]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load(root, path, expected=None):
    p = root / path
    require(p.is_file() and not p.is_symlink() and p.resolve().is_relative_to(root), "ordinary contained source")
    require(p.stat().st_size <= 1048576, "bounded offline source image")
    with p.open("rb") as stream:
        raw = stream.read(1048577)
    require(len(raw) <= 1048576, "bounded offline source image")
    require(expected is None or digest(raw) == expected, "source drift: " + str(path))
    return raw


def decode_gait(raw):
    require(raw[:16] == b"UGSTEP01" + struct.pack("<II", 1, 0), "gait header")
    tables, at = {}, 48
    for name, count, width in GAIT_SHAPES:
        require(raw[at:at+4] == name.encode() and struct.unpack_from("<II", raw, at+4) == (width, count), "gait column")
        at += 12
        tables[name] = [list(struct.unpack_from("<"+"i"*width, raw, at+i*width*4)) for i in range(count)]
        at += count*width*4
    require(raw[at:] == b"UGSEND01", "exact gait footer")
    return tables


def field_major(rows, width):
    require(all(len(row) == width and all(type(v) is int and -(1 << 31) <= v < (1 << 31) for v in row) for row in rows), "I32 rows")
    return [row[field] for field in range(width) for row in rows]


def transformed(values, origin, turn):
    require(turn in (0, 2), "exact source fixture orientation")
    if len(values) == 6 and turn == 2:
        values = [-values[3], values[1], -values[5], -values[0], values[4], -values[2]]
    elif turn == 2:
        values = [-values[0], values[1], -values[2]]
    return [value + origin[index % 3] for index, value in enumerate(values)]


def validate_tables(gait, handoff, recipes, fixture, gt, ht):
    """Independently close semantic counts, all source keys, exact solids and the four joins."""
    canonical = [part["bounds_u"] for part in fixture["parts"]] + [part["bounds_u"] for part in fixture["natural_bearings"]]
    require([part["id"] for part in fixture["parts"]] == list(range(14)), "canonical timber identities")
    require([part["part"] for part in fixture["natural_bearings"]] == [3, 4, 5, 6, 10, 11, 12, 13], "natural primitive identities")
    require(ht["SOLID"] == canonical, "all fixed fixture solids")
    states = {}
    for index, program in enumerate(gait["programs"]):
        origin, turn = program["fixture_placement"]["origin_u"], program["fixture_placement"]["quarter_turn"]
        roots = gt["ROOT"][index * 91:(index + 1) * 91]
        require(roots == program["root_u"], "complete gait root keys")
        require([i for i in range(90) if roots[i] == roots[i + 1]] == program["stationary_intervals"], "stationary phase keys")
        require(gt["DESC"][index] == [index, (128, -128)[index], index*91, 91, index*90, 90, index*22, 22, 90*65536, 0, 0, 0], "gait descriptor")
        require([transformed(box, origin, turn) for box in gt["SOLI"][index*22:(index+1)*22]] == canonical, "complete transformed gait solids")
        states[program["direction"]] = {"entry": [transformed(roots[0], origin, turn), turn*16384, program["pose_entry_sha256"]],
                                         "exit": [transformed(roots[-1], origin, turn), turn*16384, program["pose_exit_sha256"]]}
    for index, descriptor in enumerate(ht["PROGRAM"]):
        first, count, interval, intervals, _, clip, one, reserved = descriptor
        recipe = recipes[index]
        keys = ht["KEY"][first:first+count]
        require((first, count, interval, intervals) == ((0, 91, 0, 90), (91, 271, 90, 270), (362, 91, 360, 90))[index], "handoff full interval range")
        require(clip == index and one == 65536 and reserved == 0, "handoff phase protocol")
        require(keys == [[*key["root_u"], key["yaw"], key["planted_mask"]] for key in recipe["keys"]], "complete handoff root and heading keys")
        states[recipe["name"]] = {"entry": [keys[0][:3], keys[0][3], recipe["endpoint_pose_sha256"]],
                                  "exit": [keys[-1][:3], keys[-1][3], recipe["endpoint_pose_sha256"]]}
    joins = handoff["source_joins"]
    require(len(joins["joins"]) == 4, "all four exact joins")
    for join in joins["joins"]:
        require(states[join["from"]]["exit"] == states[join["to"]]["entry"] == join["state"], "root heading and pose join")
    require(states["approach"]["entry"] == joins["initial"] and states["retreat"]["exit"] == joins["terminal"], "episode endpoints")
    require(joins["initial"][1] == 0 and joins["terminal"][1] == 32768, "terminal heading cannot reset")


def source_images(root, gait, manifest):
    result = []
    for program in gait["programs"]:
        path, expected = program["source"]["paths"]["image"], program["source"]["sha256"]["image"]
        result.append((path, expected))
    path = P / "stair-handoffs-v1/candidate-6/result/mole-worker.ugactor"
    result.append((str(path), "c0d74030fc7e0a56a24d08315af197b82530aae682067f94e2bcd2faedd543af"))
    sources = []
    for path, expected in result:
        raw = load(root, path, expected)
        require(raw[:8] == b"UGACNT01", "actor image")
        revision, parts, count, frames = struct.unpack_from("<4I", raw, 12)
        clips = [struct.unpack_from("<4i", raw, 184+parts*72+i*48) for i in range(count)]
        require(parts == 2 and [c[0] for c in clips] == [sum(prior[1] for prior in clips[:i]) for i in range(count)]
                and sum(c[1] for c in clips) == frames and all(c[2] == 0 and c[3] == (c[1]-1)*65536 for c in clips), "source phase protocol")
        require(list(struct.unpack_from("<6i", raw, 32)) == [0, -32256, 0, 262144, 16896, 262144], "numerical Domain")
        manifest[path] = expected
        sources.append({"sha256": expected, "revision": revision, "clips": clips})
    return sources


def metadata(gait, handoff, source, numerical_digest, fixture):
    # Header counts/revisions remain source-only. All runtime geometry-owner pins are absent.
    header = [1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 5, 3, 66, 4, 0, 0]
    hashes = [PROFILE_SHA, LEVEL_SHA, "0"*64, "0"*64, "0"*64,
              "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9",
              "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f",
              numerical_digest, "0"*64, "0"*64, READY_SHA, PINNED[FIXTURE]]
    programs, longs = [], []
    for i in range(5):
        component, local, image, clip = (0, i, i, 0) if i < 2 else (1, i-2, 2, i-2)
        origin, turn = ([0, -128, -2217], 2) if i == 0 else ([0, 0, -1879], 0)
        if component == 1:
            origin, turn = [0, 0, 0], 0
        count = 271 if i == 3 else 91
        first_yaw = 32768 if i in (0, 4) else 0
        last_yaw = 32768 if i in (0, 3, 4) else 0
        programs.append([component, local, image, clip, component, turn, *origin, -1, -1,
                         0, 2, min(i, 2)*22, 22, 0, count-1, first_yaw, last_yaw, 0])
        longs.append([0, 0, 1, (count-1)*65536, 0, 0, 0])
        actual_clip = source[image]["clips"][clip]
        require(actual_clip[1:] == (count, 0, (count-1)*65536), "exact selected source clip")
    mappings = []
    for block in range(3):
        for i in range(22):
            part = i if i < 14 else fixture["natural_bearings"][i-14]["part"]
            assembly = fixture["parts"][part]["assembly"]
            mappings.append([int(block == 2), (block*22+i if block < 2 else i), i,
                             int(i >= 14), part, assembly])
    joins = [[2, 1, 90, 0], [1, 3, 90, 0], [3, 0, 270, 0], [0, 4, 90, 0]]
    source_values = [[s["revision"], len(s["clips"]), 0, 0] for s in source]
    return header, hashes, programs, longs, mappings, joins, source_values


def compile_image(root):
    manifest = dict(PINNED)
    inputs = {p: load(root, p, expected) for p, expected in PINNED.items()}
    gait = json.loads(inputs[str(P / "stair-program-v1/candidate-4/result/program.json")])
    handoff = json.loads(inputs[str(P / "stair-handoffs-v1/column-proposal-v2/result/program.json")])
    recipes = json.loads(inputs[str(P / "stair-handoffs-v1/candidate-6/result/candidate.json")])["attempts"]
    fixture = json.loads(inputs[FIXTURE])
    gt = decode_gait(inputs[str(P / "stair-program-v1/candidate-4/result/stair-program.ugstep")])
    ht = handoff["tables"]
    require(inputs[str(P / "stair-program-v1/candidate-4/result/stair-program.ugstep")][16:48].hex() == gait["source_input_sha256"], "gait aggregate source")
    for tables, shapes in [(gt, GAIT_SHAPES), (ht, HANDOFF_SHAPES)]:
        require(set(tables) == {name for name, _, _ in shapes}, "exact table membership")
        for name, count, width in shapes:
            require(len(tables[name]) == count, "exact complete table count")
            field_major(tables[name], width)
    validate_tables(gait, handoff, recipes, fixture, gt, ht)
    sources = source_images(root, gait, manifest)
    profile_path = "godot/data/underground/mole-worker/profile-publication-v2/mole-worker.ugprof"
    level_path = "godot/data/underground/initial_level_pack.uglvl"
    load(root, profile_path, PROFILE_SHA)
    load(root, level_path, LEVEL_SHA)
    manifest.update({profile_path: PROFILE_SHA, level_path: LEVEL_SHA})
    numerical_digest = digest(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode())
    header, hashes, programs, longs, mappings, joins, source_values = metadata(gait, handoff, sources, numerical_digest, fixture)
    ints = []
    for tables, shapes in [(gt, GAIT_SHAPES), (ht, HANDOFF_SHAPES)]:
        for name, count, width in shapes:
            require(len(tables[name]) == count, "exact complete table count")
            ints.extend(field_major(tables[name], width))
    ints += field_major(programs, 20) + field_major(mappings, 6) + field_major(joins, 4)
    ints += [0, -32256, 0, 262144, 16896, 262144]
    i64 = header + field_major(source_values, 4) + field_major(longs, 7)
    legacy = bytes.fromhex(gait["source_input_sha256"])
    legacy += b"".join(hashlib.sha256(json.dumps(recipes[i], sort_keys=True, separators=(",", ":")).encode()).digest() for i in range(3))
    legacy += hashlib.sha256(inputs[str(P / "stair-handoffs-v1/column-proposal-v2/result/program.json")]).digest()
    bytes_ = legacy + b"".join(bytes.fromhex(v) for v in hashes) + b"".join(bytes.fromhex(s["sha256"]) for s in sources)
    require((len(ints), len(i64), len(bytes_)) == (17421, 67, 640), "three packed columns")
    raw = bytearray(b"UGMOTN01" + struct.pack("<IIqII", 1, 70860, 1, 3, 0))
    for tag, size, values in [(b"I032", 4, ints), (b"I064", 8, i64), (b"BYTE", 1, bytes_)]:
        raw += tag + struct.pack("<II", size, len(values))
        raw += bytes(values) if size == 1 else struct.pack("<" + ("i" if size == 4 else "q")*len(values), *values)
    raw += b"UGMEND01"
    require(len(raw) == 70936, "complete exact wire")
    for name, expected in manifest.items():
        load(root, name, expected)
    return bytes(raw), {"schema": 1, "wire_sha256": digest(raw), "wire_bytes": len(raw), "bank_bytes": 70860,
                        "columns": {"i32": 17421, "i64": 67, "bytes": 640}, "source_pins": manifest,
                        "numerical_input_manifest_sha256": numerical_digest, "runtime_activation": False,
                        "pace_adopted": False, "all_original_geometry_preserved": True}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "fresh output directory")
    raw, report = compile_image(args.root.resolve())
    args.out.mkdir(parents=True)
    (args.out / "motion.ugmotion").write_bytes(raw)
    (args.out / "manifest.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({k: v for k, v in report.items() if k != "source_pins"}))


if __name__ == "__main__":
    main()
