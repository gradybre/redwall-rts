#!/usr/bin/env python3
"""Native images of the claw and paw sources with the tread and stair clips (ADR 1217, ADR 1209; content 10).

Successor of `native_claw_split.py` (content 8/9 images), which stays published. Every added clip is approved and
pinned by its own record; nothing is re-authored:

| Image | Source | Clips |
|---|---|---|
| claw v2 (`claw-stairs.ugactor`) | 4 | content 9's eight, then tread_tap_entry/work/recovery (DEC-058 candidate b), step_back, step_forward (ADR 1209 step 5), descent, ascent (M7), turn (step 5b) |
| paw v2 (`paw-stairs.ugactor`) | 5 | content 9's three, then tread_seat_entry/work/recovery (candidate b) |

The accepted compiler, capture script, runner and verifier equations are reused through `native_claw_split`, which
selects each image's clips. Two things are added, both checks rather than relaxations:

- **Joins** also cover the tread programs (ready -> entry -> work -> recovery -> ready, recovery the exact reverse)
  and every single travel clip (first and last key equal to the ready hub).
- **Floor rule.** The stair and turn clips are root-local: their root tracks (the lower tread, the turn's
  reposition) are applied by the program, so a foot planted on the lower tread is below the local floor. Their
  support is proved by the terrain, flight and handoff provers. For those five keys sets the floor check applies to
  nothing; it stays on every other clip, including the two flat steps.

    $PY .../native_claw_stairs.py compile|run|verify --image claw|paw ... (as native_claw_split.py)
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys

import numpy as np

import native_claw_split as SPLIT

NC, C, N, I = SPLIT.NC, SPLIT.C, SPLIT.N, SPLIT.I
ROOT, HERE = C.ROOT, NC.HERE
FIT = HERE / "evidence/tread-fit-v1/candidate-b/tread"
STEP_BACK = HERE / "evidence/tread-step-back-v1"
STEP_FORWARD = HERE / "evidence/tread-step-forward-v1"
STAIRS = HERE / "evidence/claw-stairs-v1"
TURN = HERE / "evidence/claw-turn-v1"
ADDED = {"tread_tap_entry": (FIT, "tap_entry", 0), "tread_tap_work": (FIT, "tap_work", 0),
         "tread_tap_recovery": (FIT, "tap_recovery", 0), "step_back": (STEP_BACK, "step_back", 0),
         "step_forward": (STEP_FORWARD, "step_forward", 0), "descent": (STAIRS, "descent", 0),
         "ascent": (STAIRS, "ascent", 0), "turn": (TURN, "turn", 0),
         "tread_seat_entry": (FIT, "seat_entry", 0), "tread_seat_work": (FIT, "seat_work", 0),
         "tread_seat_recovery": (FIT, "seat_recovery", 0)}
ROOTED = ("descent", "ascent", "turn")
SINGLES = ("step_back", "step_forward", "descent", "ascent", "turn")
IMAGES = {"claw": {"clips": SPLIT.IMAGES["claw"]["clips"] + ("tread_tap_entry", "tread_tap_work", "tread_tap_recovery",
                                                             "step_back", "step_forward", "descent", "ascent", "turn"),
                   "content": "claw-stairs.ugactor",
                   "programs": SPLIT.IMAGES["claw"]["programs"] + (("tread_tap_entry", "tread_tap_work",
                                                                    "tread_tap_recovery"),)},
          "paw": {"clips": SPLIT.IMAGES["paw"]["clips"] + ("tread_seat_entry", "tread_seat_work", "tread_seat_recovery"),
                  "content": "paw-stairs.ugactor",
                  "programs": SPLIT.IMAGES["paw"]["programs"] + (("tread_seat_entry", "tread_seat_work",
                                                                  "tread_seat_recovery"),)}}


def added_pins() -> dict:
    """Each added clip's digest from its approval record."""
    fit = C.read_json(FIT / "candidate.json")["clips"]
    stairs = C.read_json(STAIRS / "candidate.json")["clips"]
    expected = {**{f"tread_{n}": fit[n]["sha256"] for n in ("tap_entry", "tap_work", "tap_recovery",
                                                              "seat_entry", "seat_work", "seat_recovery")},
                "step_back": C.read_json(STEP_BACK / "step_back.json")["clip_sha256"],
                "step_forward": C.read_json(STEP_FORWARD / "step_forward.json")["clip_sha256"],
                "descent": stairs["descent"]["sha256"], "ascent": stairs["ascent"]["sha256"],
                "turn": C.read_json(TURN / "candidate.json")["clip_sha256"]}
    pins = {}
    for name, (folder, file, _) in ADDED.items():
        path = folder / (file + ".npz")
        I.require(C.digest(path) == expected[name], "CLAW_STAIRS_CLIP_PIN:" + name)
        pins[str(path.relative_to(ROOT))] = expected[name]
    return pins


BASE_PINS = SPLIT.ORIGINAL_PINS


def select(image: str) -> None:
    """Point the accepted compiler and verifier at one v2 image."""
    I.require(image in IMAGES, "CLAW_STAIRS_IMAGE")
    NC.SOURCES.update(ADDED)
    NC.CLIPS = IMAGES[image]["clips"]
    NC.CONTENT_NAME = IMAGES[image]["content"]

    def pins() -> dict:
        saved = NC.CLIPS
        NC.CLIPS = tuple(c for c in saved if c not in ADDED)
        try:
            base = BASE_PINS()
        finally:
            NC.CLIPS = saved
        return {**base, **added_pins(), str(Path(__file__).relative_to(ROOT)): C.digest(Path(__file__))}
    NC.record_pins = pins
    SPLIT.IMAGES.update(IMAGES)
    SPLIT.select = select


def joins_for(image: str, ready: dict | None):
    """The split image joins over the v2 programs, plus every single travel clip's ends on the hub."""
    programs = SPLIT.joins_for(image, ready)

    def joins(rows: np.ndarray, counts: list) -> int:
        checked = programs(rows, counts)
        table = SPLIT.table_of(rows)
        for view in range(3):
            hub = table[view, 0, NC.READY * 65536] if ready is None else ready[view]
            for name in SINGLES:
                if name not in NC.CLIPS:
                    continue
                clip = NC.CLIPS.index(name)
                for at in (0, (counts[clip] - 1) * 65536):
                    I.require(np.array_equal(table[view, clip, at], hub), "CLAW_STAIRS_SINGLE_JOIN:" + name)
                    checked += 1
        return checked
    return joins


def verify(folder: Path, palette: Path, grip: Path) -> dict:
    """`native_claw.verify` with the rooted clips' floor rule recorded (their support is proved elsewhere)."""
    report, compiled = C.read_json(folder / "report.json"), C.read_json(folder / "compiled/compilation.json")
    counts, body = compiled["clip_frames"], NC.open_body(palette, grip)
    clips = NC.cases(body)
    loops = [c["source_loop_mode"] for c in clips]
    rows_expected = 3 * sum(4 * (n - 1) + 1 for n in counts)
    I.require(report["failures"] == [] and report["rows"] == rows_expected and
              report["content_sha256"] == compiled["content_sha256"] and report["rendering_driver"] == "metal" and
              report["display_server"] == "macOS", "CLAW_STAIRS_REPORT")
    rows = NC.V8_capture(folder / "native.bin", rows_expected)
    raw = C.BASIS.read_bytes()
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + struct.unpack_from("<I", raw, 16)[0]).reshape(-1, 2)
    paw = np.any(np.isin(body["geometry"][0]["ids"], [15, 19]) & (body["geometry"][0]["weights"] > 0), axis=1)
    worst, floor, at = 0.0, float("inf"), 0
    for view_index, view in enumerate(N.VIEWS):
        for clip, case in enumerate(clips):
            first = sum(counts[:clip])
            for elapsed in range(0, (case["frames"] - 1) * 65536 + 1, 16384):
                row, chosen = rows[at], NC.timing(counts, loops, clip, elapsed)
                I.require(row["meta"].tolist() == [view_index, clip, elapsed, *chosen, view["yaw"], 1], "CLAW_STAIRS_EVENT")
                pose, ground, values = NC.expected_row(case, first, chosen, view, basis[view["yaw"]])
                I.require(np.array_equal(row["values"], values), "CLAW_STAIRS_COEFFICIENT")
                error, observed = NC.body_error(body, pose, ground, row["values"], view, basis[view["yaw"]])
                worst = max(worst, error)
                name = NC.CLIPS[clip]
                if name not in ROOTED:
                    kept = ~paw if name.startswith("dig") else np.ones(len(paw), dtype=bool)
                    floor = min(floor, float(observed[kept, 1].min()) * 1024 - view["root_u"][1])
                at += 1
    I.require(at == rows_expected and floor >= 0, "CLAW_STAIRS_FLOOR")
    return {"schema": 1, "adr": ["1217", "1209"], "rows": rows_expected, "clips": list(NC.CLIPS), "clip_frames": counts,
            "coefficient_mismatches": 0, "max_source_to_native_input_vertex_error_u": worst,
            "minimum_floor_gap_u": floor,
            "floor_rule": "every body vertex, except paw vertices in the dig clips; the rooted clips (descent, ascent, "
                          "turn) are proved on their terrain, flight and handoff fixtures instead",
            "exact_joins": NC.joins(rows, counts), "native_capture_sha256": C.digest(folder / "native.bin"),
            "production_qualified": False, "runtime_admitted": False}


def main() -> int:
    """compile | run | verify, as native_claw_split."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("compile", "run", "verify"))
    parser.add_argument("--image", choices=tuple(IMAGES), required=True)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--body", type=Path)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--claw-capture", type=Path)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    args.out = args.out.resolve()
    select(args.image)
    SPLIT.OWN = SPLIT.OWN + (Path(__file__),)
    if args.action == "compile":
        result = SPLIT.compile_image(args.image, args.palette, args.grip_palette, args.out)
        print(json.dumps({k: result[k] for k in ("wire_bytes", "frames", "clips", "content_sha256")}))
    elif args.action == "run":
        SPLIT.replay.__globals__["__file__"] = str(Path(__file__))
        SPLIT.run(args)
    else:
        I.require(not args.out.exists(), "CLAW_STAIRS_OUTPUT_EXISTS")
        ready = None
        if args.image == "paw":
            I.require(args.claw_capture is not None, "CLAW_STAIRS_CLAW_CAPTURE")
            ready = SPLIT.claw_ready(args.claw_capture)
        NC.joins = joins_for(args.image, ready)
        result = verify(args.capture, args.palette, args.grip_palette)
        result["image"] = args.image
        C.write_json(args.out, result)
        print(json.dumps({k: v for k, v in result.items() if k != "scope"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
