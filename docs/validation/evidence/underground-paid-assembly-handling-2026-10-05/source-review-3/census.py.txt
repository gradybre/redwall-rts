#!/usr/bin/env python3
"""Source-only image and stateless clock census; actual shared owner admission remains separate."""
import hashlib
import json
from pathlib import Path
import re
import struct

HERE = Path(__file__).resolve().parent


def need(test, code):
    if not test: raise ValueError(code)


def build(image=None, source=None):
    image = (HERE/"compiled-3/mole-worker.ugactor").read_bytes() if image is None else image
    source = (HERE/"handling_clock.gd").read_text() if source is None else source
    need(len(image) == 135328 and image[:8] == b"UGACNT01" and image[-8:] == b"UGAEND01" and
         struct.unpack_from("<6I", image, 8) == (1, 1178, 2, 3, 112, 300), "ASSEMBLY_IMAGE_CENSUS")
    need([struct.unpack_from("<4I", image, 328+i*48) for i in range(3)] ==
         [(0, 55, 0, 54*65536), (55, 2, 0, 65536), (57, 55, 0, 54*65536)], "ASSEMBLY_CLIP_CENSUS")
    constants = re.findall(r"^const (\w+): int = (.+)$", source, re.M)
    need(constants == [("ONE", "65536"), ("TRANSITION_TICKS", "30"),
                       ("DURATION", "TRANSITION_TICKS * ONE"), ("SOURCE_INTERVALS", "54"),
                       ("READY", "0"), ("ENTRY", "5"), ("RECOVERY", "7"),
                       ("ENTRY_RETRACE", "8"), ("HANDLED_READY", "11")], "ASSEMBLY_CLOCK_CONSTANTS")
    need(source.startswith("extends RefCounted\n") and not re.search(r"^var |^class |preload\(|load\(", source, re.M),
         "ASSEMBLY_CLOCK_RETAINED")
    code = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith(('#', '"""'))
                     and line.strip() != '@warning_ignore("integer_division")')
    need(not re.search(r"(?:Array|Dictionary|Packed\w+Array)\s*\(|\.resize\(|\.duplicate\(|\.append\(|"
                       r"\.new\(|=\s*[\[{]", code), "ASSEMBLY_CLOCK_ALLOCATION")
    functions = re.findall(r"^static func (\w+)\(", source, re.M)
    need(functions == ["state_valid", "advance", "interrupt", "source_into"], "ASSEMBLY_CLOCK_CALLS")
    called = set(re.findall(r"\b(\w+)\(", code)) - {"func"}
    need(called == {*functions, "Vector2i", "size"}, "ASSEMBLY_CLOCK_CALLS")
    locals_ = re.findall(r"^\s+var (\w+): (\w+) = (.+)$", code, re.M)
    need(locals_ == [("clip", "int", "0"), ("source_time", "int", "0")] and
         len(re.findall(r"\bvar\s", code)) == 2 and not re.search(r"\bfor\s|\bwhile\s", code),
         "ASSEMBLY_CLOCK_LOCALS")
    need(re.findall(r"^static func (.+)$", source, re.M) == [
         "state_valid(phase: int, time: int) -> bool:",
         "advance(phase: int, time: int) -> Vector2i:",
         "interrupt(phase: int, time: int) -> Vector2i:",
         "source_into(phase: int, time: int, out: PackedInt32Array) -> StringName:"], "ASSEMBLY_CLOCK_SIGNATURE")
    # Vocabulary checks explain the census, but are not a GDScript parser.
    # Pin exact reviewed bytes, including mixed docstring/executable lines.
    # Even comment edits require explicit source correspondence and re-review.
    need(hashlib.sha256(source.encode()).hexdigest() ==
         "042f43c8ccc812642608773bd0b068bf7d0b0838a2e1f1a1180d77fec9ef3275",
         "ASSEMBLY_CLOCK_EXECUTABLE")
    return {"schema": 1, "source_image_sha256": hashlib.sha256(image).hexdigest(),
            "image_bytes": len(image), "parts": 2, "palette_rows": 25, "keys": 112,
            "clips": [55, 2, 55], "intervals": 109, "retained_palette": 112*(300+1)*4,
            "retained_tables": 456, "incremental_retained_presentation": 135304,
            "new_meshes": 0, "second_actor": False, "clock_retained_fields": 0,
            "clock_constant_numeric_bytes": 8*len(constants), "clock_caller_output_bytes": 8,
            "clock_frames": {"state_valid": 16, "advance": 16, "interrupt": 16, "source_into": 32},
            "maximum_declared_clock_chain": 48, "expression_return_allowance": 32,
            "clock_own_logical_proposal": 72+8+48+32,
            "numeric_scope": "Pure clock only; foreign actual-owner caller chains must be counted at integration.",
            "native_memory_measured": False, "shared_runtime_admission": False,
            "decode_scope": "Content1181 must admit simultaneous original palettes and decode; no duplicate mesh/native reserve is assumed."}


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
