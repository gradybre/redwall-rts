#!/usr/bin/env python3
"""ADR1132: inspect finite, source-pinned native caches; grant no physical permission.

The wire is the little-endian macOS ABI of the pinned Godot build. Every stage
is consumed, decompressed under an explicit budget, and checked against its
embedded SHA. Generated MSL is evidence, not proof of the machine optimizer.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import re
import struct

import prove_underground_forward_backend as F

MAX_CACHE = 4 * 1024 * 1024
MAX_STAGE = 2 * 1024 * 1024
MAX_CACHE_SOURCE = 8 * 1024 * 1024
MAX_TOTAL_SOURCE = 32 * 1024 * 1024
MAX_VARIANTS, MAX_STAGES, MAX_SETS, MAX_UNIFORMS = 32, 5, 8, 128
PARSER_SOURCE = "278c57cebb994ce3c4ec719bdee4dd0c9070abf76975aa8e2c2ea9e58db9b96a"
SKELETON_3D_SOURCE = "db853b0698c5fbee583c268327263448d1c11b47b3d33c08d48a16c28970813c"
ENGINE_SOURCES = {
    "servers/rendering/rendering_shader_container.h": "9d04168966f3b5b4703b0f81a00c6bf4b43dfe9223a2ed1045670b7d2f2f2ee3",
    "servers/rendering/rendering_shader_container.cpp": "9015e1f85c0fe86be133e6223b33faba243dfb67d0636652b864fe824ed645b7",
    "servers/rendering/renderer_rd/shader_rd.cpp": "4f0264598233380f1f5809afb0b461c5a81f6c4bb68dcc3510675c8713d15de1",
    "drivers/metal/metal_device_profile.h": "4861e5c0f2956e0fc971fdfe4991350d24873c3b8d487e647fd57be7c78d5a54",
    "drivers/metal/sha256_digest.h": "08a603e196e9dfa391c65788ca5ff08a8a163f9cea088c9008134dc3504d4cf4",
}


class Refused(ValueError):
    """A malformed, unsupported or incompletely consumed image cannot enter this audit."""


def require(condition, code):
    if not condition:
        raise Refused(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bounded_file(path, maximum, expected):
    require(F.digest_format(expected), "METAL_HASH_FORMAT")
    with path.open("rb") as stream:
        data = stream.read(maximum + 1)
    require(0 < len(data) <= maximum, "METAL_FILE_CAPACITY")
    require(digest(data) == expected, "METAL_SOURCE_DRIFT")
    return data


class Reader:
    """Bound every count before slicing; consuming a record cannot silently skip its suffix."""

    def __init__(self, data):
        require(type(data) is bytes and 0 < len(data) <= MAX_CACHE, "METAL_FILE_CAPACITY")
        self.data, self.offset = data, 0

    def take(self, count):
        require(type(count) is int and 0 <= count <= len(self.data) - self.offset, "METAL_TRUNCATED")
        result = self.data[self.offset:self.offset + count]
        self.offset += count
        return result

    def unpack(self, pattern):
        return struct.unpack(pattern, self.take(struct.calcsize(pattern)))

    def align(self):
        self.take((-self.offset) % 4)

    def finish(self):
        require(self.offset == len(self.data), "METAL_TRAILING_DATA")


class Zstd:
    """Use an explicitly pinned local decoder, with no search/download or unbounded output allocation."""

    def __init__(self, path, expected):
        bounded_file(path, 32 * 1024 * 1024, expected)
        self.library = ctypes.CDLL(str(path.resolve()))
        self.sha256 = expected
        signatures = {
            "ZSTD_findFrameCompressedSize": ([ctypes.c_void_p, ctypes.c_size_t], ctypes.c_size_t),
            "ZSTD_getFrameContentSize": ([ctypes.c_void_p, ctypes.c_size_t], ctypes.c_ulonglong),
            "ZSTD_decompress": ([ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t], ctypes.c_size_t),
            "ZSTD_isError": ([ctypes.c_size_t], ctypes.c_uint),
            "ZSTD_versionNumber": ([], ctypes.c_uint),
        }
        for name, (arguments, result) in signatures.items():
            function = getattr(self.library, name)
            function.argtypes, function.restype = arguments, result

    def decompress(self, data, count):
        require(type(count) is int and 0 < count <= MAX_STAGE and 0 < len(data) <= MAX_STAGE,
                "METAL_STAGE_CAPACITY")
        size = self.library.ZSTD_findFrameCompressedSize(data, len(data))
        require(not self.library.ZSTD_isError(size) and size == len(data), "METAL_COMPRESSED_FRAME")
        declared = self.library.ZSTD_getFrameContentSize(data, len(data))
        require(declared == count, "METAL_DECOMPRESSED_CAPACITY")
        out = ctypes.create_string_buffer(count)
        actual = self.library.ZSTD_decompress(out, count, data, len(data))
        require(not self.library.ZSTD_isError(actual) and actual == count, "METAL_DECOMPRESSED_SIZE")
        return out.raw


def reflection(reader, shader_count):
    """Pinned ABI: 64-byte base reflection and 36-byte Metal profile, not a portable C struct guess."""
    start = reader.offset
    fields = reader.unpack("<Q13I4x")
    profile = reader.unpack("<4I2B2x4I")
    sets, specializations, stages, name_size = fields[9], fields[2], fields[12], fields[13]
    require(sets <= MAX_SETS and specializations <= MAX_UNIFORMS and stages == shader_count and
            0 < name_size <= 128, "METAL_REFLECTION_CAPACITY")
    require(fields[3] in (0, 1) and fields[4] in (0, 1) and fields[5] in (0, 1), "METAL_REFLECTION_KIND")
    require(profile[0] == 0 and 1001 <= profile[1] <= 1009 and profile[3] == 40000 and
            profile[4] in (0, 1) and profile[5] in (0, 1) and profile[6] == 40000 and
            profile[8] & ~7 == 0, "METAL_PROFILE")
    raw_name = reader.take(name_size)
    require(b"\0" not in raw_name, "METAL_SHADER_NAME")
    try:
        name = raw_name.decode("utf-8")
    except UnicodeError as exc:
        raise Refused("METAL_SHADER_NAME") from exc
    reader.align()
    uniform_count = 0
    for _ in range(sets):
        count, = reader.unpack("<I")
        require(count <= MAX_UNIFORMS - uniform_count, "METAL_UNIFORM_CAPACITY")
        uniform_count += count
        reader.take(count * 80)  # ReflectionBindingData20 + MetalUniformData60.
    reader.take(specializations * 16)
    stage_ids = reader.unpack("<" + "I" * stages)
    require(len(set(stage_ids)) == stages and set(stage_ids) <= {0, 1, 4}, "METAL_STAGE_CENSUS")
    return {"name": name, "profile": list(profile), "base_fields": list(fields), "stage_ids": list(stage_ids),
            "uniform_count": uniform_count, "specialization_count": specializations,
            "compute_local_size": list(fields[6:9]), "pipeline_type": fields[3],
            "reflection_sha256": digest(reader.data[start:reader.offset])}


def shader(reader, decoder, remaining):
    """Validate counts before decompression, then require the entire source and no unreviewed library payload."""
    stage, compressed, flags, expanded = reader.unpack("<4I")
    require(stage in (0, 1, 4) and 0 < compressed <= MAX_STAGE and
            0 < expanded <= min(MAX_STAGE, remaining), "METAL_STAGE_CAPACITY")
    require(flags in (0, 1), "METAL_COMPRESSION_FLAGS")
    payload = reader.take(compressed)
    reader.align()
    input_mask, invariant, fast_math = reader.unpack("<3I")
    expected = reader.take(32).hex()
    source_size, library_size = reader.unpack("<2I")
    require(source_size == expanded and library_size == 0 and invariant in (0, 1) and fast_math in (0, 1),
            "METAL_STAGE_METADATA")
    source = decoder.decompress(payload, expanded) if flags == 1 else payload
    require(len(source) == expanded and digest(source) == expected, "METAL_STAGE_SOURCE_HASH")
    try:
        text = source.decode("utf-8")
    except UnicodeError as exc:
        raise Refused("METAL_STAGE_SOURCE_TEXT") from exc
    require("\0" not in text and "#include <metal_stdlib>" in text, "METAL_STAGE_SOURCE_TEXT")
    return {"stage": stage, "sha256": expected, "bytes": expanded, "input_binding_mask": input_mask,
            "position_invariant": bool(invariant), "supports_fast_math": bool(fast_math)}, source


def container(data, decoder, remaining):
    reader = Reader(data)
    magic, version, format_id, format_version, count = reader.unpack("<5I")
    require((magic, version, format_id, format_version) == (0x43535247, 2, 0x42424242, 2), "METAL_CONTAINER_ABI")
    require(0 < count <= MAX_STAGES, "METAL_STAGE_CAPACITY")
    meta = reflection(reader, count)
    records, sources, total = [], {}, 0
    for _ in range(count):
        record, source = shader(reader, decoder, remaining - total)
        records.append(record)
        sources[record["sha256"]] = source
        total += len(source)
    reader.finish()
    require([row["stage"] for row in records] == meta["stage_ids"], "METAL_STAGE_CENSUS")
    require((meta["pipeline_type"] == 1) == (meta["stage_ids"] == [4]), "METAL_PIPELINE_STAGE")
    return {**meta, "stages": records}, sources, total


def cache(data, expected, decoder, remaining=MAX_TOTAL_SOURCE):
    require(F.digest_format(expected) and digest(data) == expected, "METAL_CACHE_HASH")
    reader = Reader(data)
    magic, version, count = reader.unpack("<4s2I")
    require((magic, version) == (b"GDSC", 4), "METAL_CACHE_ABI")
    require(0 < count <= MAX_VARIANTS, "METAL_VARIANT_CAPACITY")
    records, sources, total, names = [], {}, 0, set()
    for index in range(count):
        size, = reader.unpack("<I")
        require(size <= MAX_CACHE, "METAL_CONTAINER_CAPACITY")
        if size == 0:
            records.append({"index": index, "compiled": False})
            continue
        row, extracted, length = container(reader.take(size), decoder, min(MAX_CACHE_SOURCE, remaining) - total)
        require(row["name"] not in names, "METAL_VARIANT_IDENTITY")
        names.add(row["name"])
        records.append({"index": index, "compiled": True, **row})
        sources.update(extracted)
        total += length
    reader.finish()
    require(total > 0, "METAL_NO_COMPILED_STAGES")
    return {"sha256": expected, "bytes": len(data), "decoded_source_bytes": total, "variants": records}, sources


def source_contract(directory):
    """A refreshed caller manifest cannot replace the reviewed parser or engine ABI."""
    bounded_file(Path(F.__file__), 1024 * 1024, PARSER_SOURCE)
    old = F.source_contract(F.EVIDENCE / "engine-source")
    for name, expected in ENGINE_SOURCES.items():
        bounded_file(directory / name.replace("/", "__"), 1024 * 1024, expected)
    return {**old, **ENGINE_SOURCES}


def function_slice(text, name):
    """Extract a bounded generated function for inspection; this is not an arithmetic AST certificate."""
    pattern = r"\b(?:void|float\d?(?:x\d)?) " + re.escape(name) + r"\([^\n]*\)\n\{"
    matches = list(re.finditer(pattern, text))
    require(len(matches) == 1, "METAL_POSITION_FUNCTION_CENSUS")
    start, cursor, depth = matches[0].start(), matches[0].end(), 1
    while cursor < len(text) and depth:
        depth += (text[cursor] == "{") - (text[cursor] == "}")
        cursor += 1
    require(depth == 0, "METAL_POSITION_FUNCTION_TRUNCATED")
    return text[start:cursor]


def position_observation(name, stage, source):
    """Keep exact generated source scopes separate from native optimizer/input precision obligations."""
    text = source.decode("utf-8")
    if name == "SkeletonShaderRD:1" and stage == 4:
        require(digest(source) == SKELETON_3D_SOURCE, "METAL_SKIN_EXPRESSION_DRIFT")
        return {"kind": "reviewed_exact_3d_skin_source", "source_sha256": digest(source),
                "influences": [4, 8], "source_input": "binary32 float3 bitcast",
                "weights": "unpack_unorm2x16_to_float", "position": "float4(vertex0,1) * sum(weight_i * bone_i)",
                "required_state": ["has_skeleton=1", "has_blend_shape=0", "skin_weight_offset=2 or 4"],
                "arithmetic_qualified": False}
    if name.startswith("SceneForwardClusteredShaderRD:") and stage == 0:
        blocks = {key: function_slice(text, key) for key in ("_unpack_vertex_attributes", "vertex_shader")}
        return {"kind": "generated_forward_vertex_for_review", "source_sha256": digest(source),
                "function_sha256": {key: digest(value.encode()) for key, value in blocks.items()},
                "functions": blocks, "arithmetic_qualified": False}
    return {"kind": "other_stage_retained", "source_sha256": digest(source), "arithmetic_qualified": False}


def child(directory, relative):
    require(type(relative) is str and not Path(relative).is_absolute(), "METAL_INPUT_PATH")
    path = (directory / relative).resolve()
    require(path.is_relative_to(directory.resolve()), "METAL_INPUT_PATH")
    return path


def audit(manifest_path, decoder, output):
    require(not output.is_symlink() and not output.exists(), "METAL_OUTPUT_EXISTS")
    output = output.resolve()
    require(not output.exists(), "METAL_OUTPUT_EXISTS")
    with manifest_path.open("rb") as stream:
        manifest_raw = stream.read(16385)
    require(0 < len(manifest_raw) <= 16384, "METAL_MANIFEST_CAPACITY")
    manifest = json.loads(manifest_raw)
    require(type(manifest) is dict and type(manifest.get("schema")) is int and manifest["schema"] == 1,
            "METAL_MANIFEST_SCHEMA")
    directory = manifest_path.parent
    engines = source_contract(directory / "engine-source")
    rows = manifest.get("caches")
    require(type(rows) is list and 0 < len(rows) <= 8 and
            all(type(row) is dict for row in rows) and len({row.get("file") for row in rows}) == len(rows),
            "METAL_MANIFEST_CENSUS")
    records, sources, observations, total, input_pins = [], {}, [], 0, []
    for row in rows:
        path = child(directory, row["file"])
        data = bounded_file(path, MAX_CACHE, row["sha256"])
        input_pins.append((path, row["sha256"]))
        require(type(row.get("bytes")) is int and len(data) == row["bytes"], "METAL_CACHE_SIZE")
        record, extracted = cache(data, row["sha256"], decoder, MAX_TOTAL_SOURCE - total)
        record["file"] = row["file"]
        records.append(record)
        sources.update(extracted)
        total += record["decoded_source_bytes"]
        for variant in record["variants"]:
            for stage in variant.get("stages", []):
                observation = position_observation(variant["name"], stage["stage"], extracted[stage["sha256"]])
                observations.append({"cache_sha256": row["sha256"], "variant_index": variant["index"],
                                     "variant_name": variant["name"], "stage": stage["stage"], **observation})
    result = {"scope": "pinned generated Metal source census; no optimizer or physical certificate", "schema": 1,
              "engine_sources": engines, "caches": records, "decoded_source_bytes": total,
              "unique_sources": len(sources), "position_observations": observations,
              "decoder_sha256": decoder.sha256, "decoder_version": decoder.library.ZSTD_versionNumber(),
              "manifest_sha256": digest(manifest_raw), "tool_sha256": digest(Path(__file__).read_bytes()),
              "qualified_profiles": 0, "complete_numerical_enclosure": False, "world_qualified": False}
    bounded_file(manifest_path, 16384, digest(manifest_raw))
    for path, expected in input_pins:
        bounded_file(path, MAX_CACHE, expected)
    require(source_contract(directory / "engine-source") == engines, "METAL_FINAL_ENGINE_DRIFT")
    output.mkdir()
    for source_hash, source in sorted(sources.items()):
        (output / (source_hash + ".metal.txt")).write_bytes(source)
    (output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--zstd-library", type=Path, required=True)
    parser.add_argument("--zstd-sha256", required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.manifest, Zstd(args.zstd_library, args.zstd_sha256), args.out_dir)
    print(json.dumps({"caches": len(result["caches"]), "unique_sources": result["unique_sources"],
                      "decoded_source_bytes": result["decoded_source_bytes"], "qualified_profiles": 0}))


if __name__ == "__main__":
    main()
