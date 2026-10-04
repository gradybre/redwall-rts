#!/usr/bin/env python3
"""Read the actual finite image and existing loader declarations; this is not runtime admission."""
import argparse
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE))
import compile_native_program as C
import run_native_program as N


def census(folder):
    wire = folder / "compiled/haul-handling.ugactor"
    with wire.open("rb") as file:
        header = file.read(184)
        C.I.require(header[:8] == b"UGACNT01", "HAUL_NATIVE_CENSUS_HEADER")
        schema, revision, parts, clips, frames, stride = struct.unpack_from("<6I", header, 8)
        C.I.require((schema, revision, parts, clips, frames, stride) == (1, 1, 2, 8, 595, 300),
                    "HAUL_NATIVE_CENSUS_TABLES")
        vertices = []
        for _ in range(parts):
            row = file.read(72)
            vertices.append(struct.unpack_from("<4I", row)[1])
    C.I.require(vertices == [17172, 522], "HAUL_NATIVE_CENSUS_MESH")
    tables = 80 * parts + 48 * clips + 152
    retained = frames * (stride + 1) * 4
    mesh = max(vertices) * C.I.CONTENT.MESH_BYTES_PER_VERTEX
    peak = retained + max(retained, mesh) + tables + C.I.CONTENT.CONTROL_RESERVE
    expected_wire = 184 + parts * 72 + clips * 48 + retained + 8
    C.I.require(wire.stat().st_size == expected_wire, "HAUL_NATIVE_CENSUS_WIRE")
    sources = N.closure()
    return {"runtime_source_files": len(sources), "runtime_source_bytes": sum((C.ROOT / "godot" / p).stat().st_size for p in sources),
            "wire_bytes": expected_wire, "source_keys": frames, "rendered_intervals": frames - clips,
            "complete_vertices": vertices, "retained_palette_bytes": retained,
            "decode_staging_bytes": retained, "borrowed_mesh_array_allowance_bytes": mesh,
            "packed_tables_bytes": tables, "reader_native_control_reserve_bytes": C.I.CONTENT.CONTROL_RESERVE,
            "declared_offline_content_peak_bytes": peak, "world_basis_separate_bytes": 544768,
            "capture_rows": 7068, "capture_bytes": 16 + 7068 * 1288,
            "global_simulation_state_delta_bytes": 0, "runtime_admitted": False, "native_peak_measured": False,
            "exclusions": ["Original/derived mesh resources and textures", "Renderer RIDs and framebuffers",
                           "Python objects, verifier geometry scratch and native allocator overhead"],
            "scope": "Source-derived existing loader declaration for one isolated native replay. "
                     "This is not additional capacity inside the 100 MB gameplay gate or a whole-process peak."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--capture", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(census(args.capture), indent=2, sort_keys=True))
