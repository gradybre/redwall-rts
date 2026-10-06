#!/usr/bin/env python3
"""Read the actual ten-clip stone image and existing loader declarations (ADR 1206); not runtime admission.

Also sums the four per-source presentation reservations the runtime ContentSet would hold if the stone image
were loaded beside the actor, assembly and wood-haul images (underground_session.gd constants).
"""
import argparse
import json
from pathlib import Path
import re
import struct
import sys

HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE))
import compile_native_program as C
import compile_native_program_v9 as C9
import run_native_program_v9 as N9
import verify_native_program_v9 as V9

SESSION = C.ROOT / "godot/scripts/core/underground_session.gd"


def session_constant(text: str, name: str) -> int:
    found = re.findall(r"(?m)^const %s: int = (\d+)$" % name, text)
    C.I.require(len(found) == 1, "STONE_NATIVE_CENSUS_SESSION")
    return int(found[0])


def census(folder: Path) -> dict:
    wire = folder / "compiled/stone-handling.ugactor"
    with wire.open("rb") as file:
        header = file.read(184)
        C.I.require(header[:8] == b"UGACNT01", "STONE_NATIVE_CENSUS_HEADER")
        schema, revision, parts, clips, frames, stride = struct.unpack_from("<6I", header, 8)
        C.I.require((schema, revision, parts, clips, frames, stride) == (1, 1, 2, 10, 657, 300),
                    "STONE_NATIVE_CENSUS_TABLES")
        vertices = [struct.unpack_from("<4I", file.read(72))[1] for _ in range(parts)]
    C.I.require(vertices == [17172, 70] and clips <= C.I.CONTENT.MAX_CLIPS, "STONE_NATIVE_CENSUS_MESH")
    tables = 80 * parts + 48 * clips + 152
    retained = frames * (stride + 1) * 4
    mesh = max(vertices) * C.I.CONTENT.MESH_BYTES_PER_VERTEX
    peak = retained + max(retained, mesh) + tables + C.I.CONTENT.CONTROL_RESERVE
    expected_wire = 184 + parts * 72 + clips * 48 + retained + 8
    C.I.require(wire.stat().st_size == expected_wire, "STONE_NATIVE_CENSUS_WIRE")
    text = SESSION.read_text()
    reservations = {name: session_constant(text, name) for name in
                    ("PRESENTATION_BYTES", "HANDLING_PRESENTATION_BYTES", "HAUL_PRESENTATION_BYTES")}
    reservations["STONE_PRESENTATION_BYTES (v9, declared here)"] = peak
    sources = N9.closure()
    return {"wire_bytes": expected_wire, "clips": clips, "max_clips": C.I.CONTENT.MAX_CLIPS,
            "clip_frames": dict(zip(C9.CLIPS, C9.COUNTS)), "source_keys": frames, "rendered_intervals": frames - clips,
            "complete_vertices": vertices, "retained_palette_bytes": retained, "decode_staging_bytes": retained,
            "borrowed_mesh_array_allowance_bytes": mesh, "packed_tables_bytes": tables,
            "reader_native_control_reserve_bytes": C.I.CONTENT.CONTROL_RESERVE,
            "declared_offline_content_peak_bytes": peak, "world_basis_separate_bytes": 544768,
            "capture_rows": V9.ROWS, "capture_bytes": 16 + V9.ROWS * V9.ROW_BYTES,
            "runtime_source_files": len(sources),
            "presentation_reservations_bytes": reservations,
            "presentation_set_with_stone_bytes": sum(reservations.values()),
            "v8_comparison": {"wire_bytes": 993008, "retained_palette_bytes": 992096,
                              "declared_offline_content_peak_bytes": 7486168},
            "global_simulation_state_delta_bytes": 0, "runtime_admitted": False, "native_peak_measured": False,
            "exclusions": ["Original/derived mesh resources and textures", "Renderer RIDs and framebuffers",
                           "Python objects, verifier geometry scratch and native allocator overhead"],
            "scope": "Source-derived existing loader declarations. The presentation set is a declared reservation, "
                     "not a measured peak and not capacity inside the 100 MB simulation-owned gate."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--capture", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(census(args.capture), indent=2, sort_keys=True))
