#!/usr/bin/env python3
"""Source-only allocation proposal: current owned arenas plus complete prospective paired rows."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
REPORT = HERE / "source-3/result/step-program.json"
REPORT_SHA = "fff35c8c2ead2f43a68a242ca3ac156f9348af1880a00dd7ebbb16aaa1f476a0"


def need(condition, message):
    if not condition:
        raise ValueError(message)


def build(report, joint):
    """Reject changed profile/table/source topology before calculating a possible future configuration."""
    need(report["certificate_bits_written"] == 0 and report["production_qualified"] is False and
         report["native_replay"] is False, "SOURCE_ONLY_BOUNDARY")
    need(report["verified_source_files"] == 537 and len(report["rows"]) == 2 and
         [row["direction"] for row in report["rows"]] == [1, -1], "SOURCE_CENSUS")
    need(joint["profiles"] == 26 and joint["boxes"] == 250 and joint["source_count"] == 1 and
         joint["reservation"] == 262144, "CURRENT_JOINT_CONFIGURATION")
    terms = joint["terms"]
    wanted = {"paired_profiles", "profile_controls", "levels", "paired_motion", "decode",
              "motion_caller", "motion_helpers", "motion_native_provisional", "session", "retirement"}
    need(set(terms) == wanted and all(type(value) is int and value > 0 for value in terms.values()),
         "CURRENT_LIFETIME_TERMS")
    need(sum(terms.values()) == joint["total"] == 246868 and
         terms["paired_profiles"] == 2 * (26 * 98 + 250 * 28 + 32 + 32), "CURRENT_JOINT_SUM")
    boxes = 0
    for row in report["rows"]:
        need(row["runtime_profile_id"] is None and row["runtime_policy"] is None and
             row["body_yaw"] == 49152 and row["mode"] == "WALK", "NO_RUNTIME_PERMISSION")
        roles = row["roles"]
        need(set(roles) == {"BODY_HELD_LOAD", "TURN_RECOVERY", "STANCE_SUPPORT"} and
             [len(roles[k]) for k in ("BODY_HELD_LOAD", "TURN_RECOVERY", "STANCE_SUPPORT")] == [3, 3, 1],
             "COMPLETE_ROLE_CENSUS")
        need(roles["BODY_HELD_LOAD"] == roles["TURN_RECOVERY"], "COMPLETE_COLLISION_ROLES")
        for values in roles.values():
            for box in values:
                need(len(box) == 6 and all(type(v) is int for v in box) and
                     all(box[a] < box[a + 3] for a in range(3)), "EXACT_WHOLE_BOX")
                boxes += 1
    need(report["storage"]["new_actor_sources"] == 0 and report["storage"]["actor_image_delta"] == 0 and
         report["storage"]["new_resident_columns"] == 0 and
         report["storage"]["runtime_controls_not_yet_allocated_or_admitted"] is True, "NO_HIDDEN_OWNER")
    profile_count, box_count = 26 + len(report["rows"]), 250 + boxes
    paired = 2 * (profile_count * 98 + box_count * 28 + 32 + 32)
    total = joint["total"] - terms["paired_profiles"] + paired
    need(total <= joint["reservation"], "JOINT_CAPACITY")
    return {"source_only": True, "current_joint_terms": terms,
            "prospective_configuration": {"profiles": profile_count, "boxes": box_count, "sources": 1},
            "current_paired_profile_bytes": terms["paired_profiles"], "prospective_paired_profile_bytes": paired,
            "paired_delta": paired - terms["paired_profiles"], "before_new_controls": total,
            "reservation": joint["reservation"], "remaining_before_new_controls": joint["reservation"] - total,
            "actual_new_runtime_bytes": 0, "actual_runtime_source_files_added": 0,
            "proposal_admitted": False, "new_runtime_controls_measured_or_reserved": False,
            "presentation_actor_image_delta": 0, "new_per_resident_columns": 0,
            "offline_endpoint_bank_bytes": report["storage"]["offline_endpoint_bank_bytes"],
            "offline_selected_copy_upper_bound": report["storage"]["offline_selected_copy_max_bytes"],
            "scope": "No claim that this arithmetic accounts for future canonical dispatch or native headers. Current Profiles/Levels/Motion/Session/retirement terms remain charged exactly once."}


def main():
    need(REPORT.is_file() and REPORT.stat().st_size <= 4 * 1024 * 1024 and
         hashlib.sha256(REPORT.read_bytes()).hexdigest() == REPORT_SHA, "EXACT_SOURCE_REPORT")
    pack = ROOT / "docs/planning/underground_memory_pack.json"
    need(pack.stat().st_size <= 4 * 1024 * 1024, "CURRENT_PACK_CAPACITY")
    joint = json.loads(pack.read_text())["source_approach_reservation"]["joint"]
    source = ROOT / "godot/data/underground/mole-worker/work-step-v1"
    need(not list(source.rglob("*.gd")) and not list(source.rglob("*.ugactor")), "NO_NEW_RUNTIME_OR_ACTOR")
    result = build(json.loads(REPORT.read_text()), joint)
    result["input_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in (REPORT, pack, Path(__file__))}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
