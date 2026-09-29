#!/usr/bin/env python3
"""Build the live demo's pantry index: which library dishes each farmed ingredient feeds.

The demo's farm (godot/demo/farm/) grows individual pantry ingredients -- a radish is a radish --
and its Pantry view lists, per ingredient, the content library's dishes that use it. The library
is an offline authoring corpus (docs/redwall-content-library/authoring_handoff.md section 6: "An
eventual approved content build should resolve selected research references into immutable
content definitions once at import/build time"), so the demo never parses the 16 MB pantry at
run time. This script resolves it once and writes a small committed JSON file.

WHAT IS RESOLVED, exactly as the handoff's section 3 specifies:
  * only `recipe_dependencies` rows with `production_candidate: true`;
  * each row's precomputed `game_inputs[].target_kind` / `target_id` -- never label matching;
  * a dish uses an ingredient DIRECTLY when one of its inputs is that LEAF, and VIA A COMPONENT
    when the leaf is in the recursive leaf closure of one of its COMPONENT inputs (the handoff's
    `Leaves(v)` formula over `game_components[].dependencies`).

Every record stays NOT_RUNTIME_ACTIVE: the demo shows dish names as library candidates, with no
quantities, yields or cooking (LIB-008, PANTRY-005). The ingredient list is the demo's own
selection (godot/demo/farm/farm_catalog.gd documents the choice and the exclusions).

	python3 tools/make_demo_pantry_index.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PANTRY = ROOT / "docs/redwall-content-library/shared/pantry.json"
OUT = ROOT / "godot/demo/farm/pantry_index.json"

## The farmed ingredients, as the pantry's own LEAF ids. Must match farm_catalog.gd ITEM_LEAVES.
LEAVES = [
    "LEAF_radish", "LEAF_turnip", "LEAF_carrot", "LEAF_beetroot", "LEAF_parsnip", "LEAF_onion",
    "LEAF_cabbage", "LEAF_lettuce", "LEAF_spinach", "LEAF_leek", "LEAF_celery",
    "LEAF_pea", "LEAF_broad_bean",
    "LEAF_wheat", "LEAF_barley", "LEAF_oats",
]
## At most this many dish names per ingredient are listed (direct uses first); the counts are whole.
MAX_LISTED = 40


def leaf_closure(components: dict, component_id: str, memo: dict) -> set:
    """The set of LEAF ids a component resolves to, recursively (the library has no cycles)."""
    if component_id in memo:
        return memo[component_id]
    out: set = set()
    for dep in components[component_id]["dependencies"]:
        if dep["target_kind"] == "LEAF":
            out.add(dep["target_id"])
        elif dep["target_kind"] == "COMPONENT":
            out |= leaf_closure(components, dep["target_id"], memo)
    memo[component_id] = out
    return out


def dish_label(row: dict) -> str:
    """The dish's shared game label, falling back to its book game label."""
    return row.get("shared_game_label") or row.get("book_game_label") or row["source_food_label"]


def uses(row: dict, leaf: str, components: dict, memo: dict) -> str:
    """'direct', 'component' or '' -- how a recipe row uses a leaf."""
    via = False
    for item in row["game_inputs"]:
        if item["target_kind"] == "LEAF" and item["target_id"] == leaf:
            return "direct"
        if item["target_kind"] == "COMPONENT" and leaf in leaf_closure(components, item["target_id"], memo):
            via = True
    return "component" if via else ""


def index_leaf(leaf: str, rows: list, components: dict, memo: dict) -> dict:
    """One ingredient's entry: counts of distinct dish labels, and the listed dishes."""
    found: dict = {}
    for row in rows:
        how = uses(row, leaf, components, memo)
        label = dish_label(row)
        if how and (label not in found or (how == "direct" and found[label]["use"] != "direct")):
            found[label] = {"label": label, "id": row["shared_recipe_id"], "use": how}
    ordered = sorted(found.values(), key=lambda d: (d["use"] != "direct", d["label"].lower()))
    return {
        "leaf_id": leaf,
        "direct_count": sum(1 for d in ordered if d["use"] == "direct"),
        "component_count": sum(1 for d in ordered if d["use"] == "component"),
        "dishes": ordered[:MAX_LISTED],
    }


def main() -> None:
    """Resolve every farmed leaf and write the index."""
    raw = PANTRY.read_bytes()
    pantry = json.loads(raw)
    known = {leaf["id"] for leaf in pantry["game_leaf_inputs"]}
    missing = [leaf for leaf in LEAVES if leaf not in known]
    if missing:
        raise SystemExit(f"not pantry leaves: {missing}")
    components = {c["id"]: c for c in pantry["game_components"]}
    rows = [r for r in pantry["recipe_dependencies"] if r["production_candidate"]]
    memo: dict = {}
    out = {
        "schema": "demo_pantry_index_v1",
        "activation": "NOT_RUNTIME_ACTIVE",
        "source": "docs/redwall-content-library/shared/pantry.json",
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "max_listed": MAX_LISTED,
        "items": [index_leaf(leaf, rows, components, memo) for leaf in LEAVES],
    }
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(LEAVES)} ingredients")


if __name__ == "__main__":
    main()
