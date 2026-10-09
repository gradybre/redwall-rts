#!/usr/bin/env python3
"""Independent conservative numeric-frame review of the ordinary publication tail.

This sums every selected function's parameters and declared numeric locals, even
though most execute sequentially. It is a logical upper allowance for this
reviewed source slice, not a native allocator measurement or whole-runtime gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

FILES = {
    "underground_room_orders.gd": "_publish_room _room_publication_refusal _publish_flat_room_identity _flat_room_claims_leaf_refusal _flat_room_binding_leaf_refusal _same_room_plan _room_budget_covers _publish_room_geometry",
    "excavation_sites.gd": "room_claim_prepared_leaf_refusal publish_room_claim_preflighted _room_claim_current_leaf_refusal _room_claim_composition_leaf_refusal _room_claim_bracket_refusal _entry_claim_receipt_refusal _publish_claim_rows_preflighted _merge_claim_rows_preflighted _unchanged matches_input _drop_scratch advance_cursor cursor_key cursor_error cursor_count",
    "buildings.gd": "publish_spatial_room_preflighted _write_room_row_preflighted",
    "entity_directory.gd": "create_candidate candidate_refusal create _refuse_create _pop_min _publish_row is_valid_of_kind is_valid get_typed_row get_persistent_id last_refusal",
    "underground_room_cut_map.gd": "advance _emit _prepare_band _gather_band _sort_intervals _sift _merge_intervals _row_first_quantum _row_last_quantum _quantum _spend _fail current_key refusal emitted_count clear",
    "underground_budget.gd": "covers",
    "underground_space_owner.gd": "room_prepared_leaf_refusal _room_source_leaf_refusal room_commit_preflighted _room_issuer_leaf_matches _ordinary_room_plan_matches _room_after_leaf_matches _commit_preflighted_columns _commit_columns_0 _commit_columns_1 _commit_columns_2 _commit_columns_3 _commit_columns_4",
}
WIDTH = {"int": 8, "bool": 1, "float": 8, "Vector2i": 8, "Vector3i": 12}


def function(source, name):
    starts = list(re.finditer(r"(?m)^([\t ]*)(?:static )?func (\w+)\(", source))
    rows = [row for row in starts if row[2] == name]
    if len(rows) != 1:
        raise ValueError("REVIEW_FUNCTION_CENSUS:" + name)
    row = rows[0]
    end = source.find("\n", row.start())
    while not source[row.start():end].rstrip().endswith(":"):
        end = source.find("\n", end + 1)
    cursor = end + 1
    while cursor < len(source):
        next_line = source.find("\n", cursor)
        next_line = len(source) if next_line < 0 else next_line
        line = source[cursor:next_line]
        if line.strip() and not line.lstrip().startswith("#") and len(line) - len(line.lstrip()) <= len(row[1]):
            break
        cursor = next_line + 1
    return source[row.start():end], source[end + 1:cursor]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    rows, pins = [], {}
    for filename, names in FILES.items():
        path = args.root / "godot/scripts/core" / filename
        raw = path.read_bytes()
        pins[str(path.relative_to(args.root))] = hashlib.sha256(raw).hexdigest()
        for name in names.split():
            signature, body = function(raw.decode(), name)
            params = re.findall(r"\b(\w+)\s*:\s*(\w+)", signature.split(") ->")[0])
            clean = re.sub(r'"""[\s\S]*?"""', "", body)
            clean = re.sub(r"(?m)#.*$", "", clean)
            locals_ = re.findall(r"\b(?:var|for)\s+(\w+)\s*:\s*(\w+)", clean)
            values = [(key, typ, WIDTH[typ]) for key, typ in params + locals_ if typ in WIDTH]
            rows.append({"file": filename, "function": name, "numeric": values,
                         "bytes": sum(value[2] for value in values)})
    total = sum(row["bytes"] for row in rows)
    result = {"scope": "Conservative sum of sequential final-publication functions, not a live native stack measurement.",
              "source_sha256": pins, "functions": rows, "all_declared_frames_bytes": total,
              "expression_and_numeric_return_allowance_bytes": 128,
              "existing_ADR1095_packet_allowance_bytes": 812,
              "combined_logical_allowance_bytes": 812 + total + 128,
              "existing_control_ceiling_bytes": 2048,
              "no_new_retained_fields_or_arrays": True,
              "native_runtime_qualified": False}
    if result["combined_logical_allowance_bytes"] > 2048:
        raise ValueError("REVIEW_CONTROL_CAPACITY:" + str(result))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
