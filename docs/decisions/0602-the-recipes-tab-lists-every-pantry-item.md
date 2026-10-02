# 0602 — The Pantry's Recipes tab lists every pantry item, the catch included
Date: 2026-10-01 · Status: Accepted

Feature 16 (decision 0601). Decision 0436 left the Recipes tab at the sixteen crops: its rows are the content library's
pantry index, which had no fish.

## Decision

`tools/make_demo_pantry_index.py` now indexes all 24 pantry items in `farm_catalog.gd` order (schema
`demo_pantry_index_v2`), each with its pantry TARGETS:

- a crop: its LEAF (unchanged -- the sixteen crops' entries are byte-for-byte the dishes and counts they were);
- a fish of the catch: its LEAF (trout, dace, perch, whitefish). **Salmon and carp have no pantry leaf** (the library's
  fish leaves are dace, herring, mackerel, mussel, perch, trout, whitefish), so they are listed with no targets and the
  tab says "Salmon is not in the content library's pantry";
- dried fish: every `dried` COMPONENT whose leaves are the demo's fish -- the library's dried trout;
- flour: every `flour` COMPONENT whose leaves are wheat, barley or oats (wheat, wholemeal, oat, wholegrain oat, barley
  and selected flour).

A dish uses an item directly when an input is one of its targets, through a prepared part when a target is in the
closure of a component input. `farm_recipes.gd` loads the 24 items (a goods entry is checked by its key, a crop by its
LEAF too) and the Pantry lists them all, with their icons.

Rebuild: `python3 tools/make_demo_pantry_index.py` (source hash recorded in the file).

## Why

The fish the village catches had no row on the tab that is meant to say what each ingredient feeds. Computing the
goods' targets from the library's own component graph keeps them honest; no label matching.

## Source

CONTENT-LIB-001 §3 (resolution through precomputed targets, the leaf-closure formula) and §6 (resolve at build time);
decisions 0196, 0431, 0434, 0436.
