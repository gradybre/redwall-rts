#!/usr/bin/env python3
"""Build the live demo's pantry index: which library dishes each pantry item feeds.

The demo's farm (godot/demo/farm/) grows individual pantry ingredients -- a radish is a radish --
and the water and the stations add the pantry's other goods (the six fish of the catch, dried fish
and flour; decision 0431). The Pantry's Recipes tab lists, per item, the content library's dishes
that use it. Decision 0196; the goods were added by decision 0602 (the tab was missing the fish). The library
is an offline authoring corpus (docs/redwall-content-library/authoring_handoff.md section 6: "An
eventual approved content build should resolve selected research references into immutable
content definitions once at import/build time"), so the demo never parses the 16 MB pantry at
run time. This script resolves it once and writes a small committed JSON file.

WHAT IS RESOLVED, exactly as the handoff's section 3 specifies:
  * only `recipe_dependencies` rows with `production_candidate: true`;
  * each row's precomputed `game_inputs[].target_kind` / `target_id` -- never label matching;
  * each pantry item is one or more pantry TARGETS: a crop or a fish its LEAF; dried fish the
    library's dried forms of the demo's fish, and flour its flours of the demo's grain -- every
    COMPONENT whose id says so and whose leaf closure is within those leaves (computed, below);
  * a dish uses an item DIRECTLY when one of its inputs is one of the item's targets, and VIA A
    COMPONENT when a target is in the recursive closure (leaves and components) of one of its
    COMPONENT inputs (the handoff's `Leaves(v)` formula over `game_components[].dependencies`).
  * potato and honey (decision 0603: ingredients with no source yet) by their LEAF;
  * the woods' forage (decision 0681: nuts, mushrooms, herb, berries) by the woodland leaves each stands for
    (FORAGE_LEAVES: the batch 7 integration's demo selection, decision 0902 -- never nutmeg, a spice);
  * the orchard's apple and pear (decision 0671) by their LEAF (batch 8 integration, decision 0903);
  * the preserves (decision 1611): dried fruit as the library's dried forms of apple and pear (as dried fish is of the
    fish); rations by a LEAF the library does not have, so with no targets and no dishes; likewise the drinks (decision
    1621: mead and the cordial), which the library has as no leaf; the new recipes (decision 1625) by the library
    components they are drafted from (NEW_RECIPE_TARGETS);
  * Salmon and carp have no pantry leaf (the library's fish leaves are dace, herring, mackerel,
    mussel, perch, trout and whitefish): they are listed with no targets and no dishes.

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
## Every pantry item, in farm_catalog.gd ITEM_KEYS order: the sixteen crops, then the goods.
ITEM_KEYS = [
    "radish", "turnip", "carrot", "beetroot", "parsnip", "onion",
    "cabbage", "lettuce", "spinach", "leek", "celery",
    "pea", "broad_bean",
    "wheat", "barley", "oats",
    "trout", "dace", "salmon", "perch", "carp", "whitefish",
    "dried_fish", "flour",
    "potato", "honey",
    "nuts", "mushrooms", "herb", "berries",
    "apple", "pear",
    "dried_fruit", "ration",
    "mead", "cordial",
    "jam", "cheese", "ale", "cider",
]
## The woods' forage (farm_catalog.gd THE WOODS' FORAGE): each item's pantry leaves, the demo's own selection of the
## woodland's nuts, fungi, pot herbs and wild berries (decision 0902).
FORAGE_LEAVES = {
    "nuts": ["LEAF_hazelnut", "LEAF_beechnut", "LEAF_chestnut", "LEAF_sweet_chestnut"],
    "mushrooms": ["LEAF_mushroom", "LEAF_button_mushroom"],
    "herb": ["LEAF_mint", "LEAF_thyme", "LEAF_sage", "LEAF_rosemary"],
    "berries": ["LEAF_raspberry", "LEAF_blackberry", "LEAF_bilberry", "LEAF_elderberry", "LEAF_strawberry",
                "LEAF_whortleberry"],
}
CATCH = ["trout", "dace", "salmon", "perch", "carp", "whitefish"]
GRAIN_LEAVES = {"LEAF_wheat", "LEAF_barley", "LEAF_oats"}
## The orchard's fruit (decision 0671): dried fruit (decision 1611) is the library's dried forms of them.
FRUIT_LEAVES = {"LEAF_apple", "LEAF_pear"}
## The new recipes (decision 1625): each the library components it is drafted from -- the honey berry jams, the
## ale and the ciders. The salt-free nut cheese has no library component of its own (the cultured hazelnut cheese takes
## salt), so it lists no dishes.
NEW_RECIPE_TARGETS = {
    "jam": ["COMPONENT_shared_blackberry_jam", "COMPONENT_shared_strawberry_jam"],
    "cheese": [],
    "ale": ["COMPONENT_shared_ale", "COMPONENT_shared_october_ale"],
    "cider": ["COMPONENT_shared_pale_cider", "COMPONENT_shared_old_cider"],
}
## At most this many dish names per ingredient are listed (direct uses first); the counts are whole.
MAX_LISTED = 40


def closure(components: dict, component_id: str, memo: dict) -> set:
    """Every LEAF and COMPONENT id a component resolves through, recursively (the library has no cycles)."""
    if component_id in memo:
        return memo[component_id]
    out: set = set()
    for dep in components[component_id]["dependencies"]:
        if dep["target_kind"] in ("LEAF", "COMPONENT"):
            out.add(dep["target_id"])
        if dep["target_kind"] == "COMPONENT":
            out |= closure(components, dep["target_id"], memo)
    memo[component_id] = out
    return out


def leaves_of(components: dict, component_id: str, memo: dict) -> set:
    """The LEAF ids in a component's closure."""
    return {t for t in closure(components, component_id, memo) if t.startswith("LEAF_")}


def goods_targets(components: dict, word: str, within: set, memo: dict) -> list:
    """The COMPONENT ids naming `word` (dried, flour) whose leaves are non-empty and all within `within`."""
    found = []
    for cid in sorted(components):
        leaves = leaves_of(components, cid, memo)
        if word in cid and leaves and leaves <= within:
            found.append(cid)
    return found


def targets_of(key: str, known: set, components: dict, memo: dict) -> list:
    """The pantry targets a demo item stands for (see WHAT IS RESOLVED)."""
    if key in ITEM_KEYS[:len(LEAVES)]:
        return [LEAVES[ITEM_KEYS.index(key)]]
    if key in CATCH:
        return [f"LEAF_{key}"] if f"LEAF_{key}" in known else []
    if key == "dried_fish":
        return goods_targets(components, "dried", {f"LEAF_{k}" for k in CATCH}, memo)
    if key == "flour":
        return goods_targets(components, "flour", GRAIN_LEAVES, memo)
    if key in NEW_RECIPE_TARGETS:
        return [target for target in NEW_RECIPE_TARGETS[key] if target in components or target in known]
    if key == "dried_fruit":
        return goods_targets(components, "dried", FRUIT_LEAVES, memo)
    if key in FORAGE_LEAVES:
        return [leaf for leaf in FORAGE_LEAVES[key] if leaf in known]
    return [f"LEAF_{key}"] if f"LEAF_{key}" in known else []


def dish_label(row: dict) -> str:
    """The dish's shared game label, falling back to its book game label."""
    return row.get("shared_game_label") or row.get("book_game_label") or row["source_food_label"]


def uses(row: dict, targets: set, components: dict, memo: dict) -> str:
    """'direct', 'component' or '' -- how a recipe row uses any of an item's targets."""
    via = False
    for item in row["game_inputs"]:
        if item["target_kind"] in ("LEAF", "COMPONENT") and item["target_id"] in targets:
            return "direct"
        if item["target_kind"] == "COMPONENT" and targets & closure(components, item["target_id"], memo):
            via = True
    return "component" if via else ""


def index_item(key: str, targets: list, rows: list, components: dict, memo: dict) -> dict:
    """One pantry item's entry: its targets, counts of distinct dish labels, and the listed dishes."""
    found: dict = {}
    wanted = set(targets)
    for row in rows:
        how = uses(row, wanted, components, memo) if wanted else ""
        label = dish_label(row)
        if how and (label not in found or (how == "direct" and found[label]["use"] != "direct")):
            found[label] = {"label": label, "id": row["shared_recipe_id"], "use": how}
    ordered = sorted(found.values(), key=lambda d: (d["use"] != "direct", d["label"].lower()))
    return {
        "item_key": key,
        "leaf_id": targets[0] if key in ITEM_KEYS[:len(LEAVES)] else "",
        "targets": targets,
        "direct_count": sum(1 for d in ordered if d["use"] == "direct"),
        "component_count": sum(1 for d in ordered if d["use"] == "component"),
        "dishes": ordered[:MAX_LISTED],
    }


def build() -> dict:
    """Resolve every pantry item into the index (what `main` writes)."""
    raw = PANTRY.read_bytes()
    pantry = json.loads(raw)
    known = {leaf["id"] for leaf in pantry["game_leaf_inputs"]}
    missing = [leaf for leaf in LEAVES if leaf not in known]
    if missing:
        raise SystemExit(f"not pantry leaves: {missing}")
    components = {c["id"]: c for c in pantry["game_components"]}
    rows = [r for r in pantry["recipe_dependencies"] if r["production_candidate"]]
    memo: dict = {}
    items = [index_item(k, targets_of(k, known, components, memo), rows, components, memo) for k in ITEM_KEYS]
    return {
        "schema": "demo_pantry_index_v2",
        "activation": "NOT_RUNTIME_ACTIVE",
        "source": "docs/redwall-content-library/shared/pantry.json",
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "max_listed": MAX_LISTED,
        "items": items,
    }


def main() -> None:
    """Resolve every pantry item and write the index."""
    out = build()
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(out['items'])} pantry items")


if __name__ == "__main__":
    main()
