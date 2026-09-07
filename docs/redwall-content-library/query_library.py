#!/usr/bin/env python3
"""Read-only, bounded retrieval from the adjacent research JSON files."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["search", "record", "recipe", "pantry"])
    parser.add_argument("query", help="Search text, qualified record/recipe ID, or component/leaf ID")
    parser.add_argument("--book", help="Exact book_key filter for search")
    parser.add_argument("--kind", help="Exact uppercase catalog kind filter for search")
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--include-dossiers", action="store_true")
    args = parser.parse_args()
    if args.offset < 0 or not 1 <= args.limit <= 100:
        parser.error("offset must be nonnegative and limit must be from 1 through 100")
    if args.mode == "search":
        terms = args.query.casefold().split()
        matches = []
        for row in read("shared/catalog.json")["records"]:
            if args.book and row["book_key"] != args.book:
                continue
            if args.kind and row["kind"] != args.kind:
                continue
            if not args.include_dossiers and row["record_scope"] == "CHUNK_DOSSIER":
                continue
            text = " ".join([row["label"]] + row["aliases"] + [f["text"] for f in row["facts"]]).casefold()
            if all(term in text for term in terms):
                matches.append({key: row[key] for key in ["id", "book_key", "kind", "label", "record_scope"]})
        page = matches[args.offset:args.offset + args.limit]
        next_offset = args.offset + len(page)
        result = {"total_matches": len(matches), "offset": args.offset, "next_offset": next_offset if next_offset < len(matches) else None, "matches": page}
    elif args.mode == "record":
        matches = [r for r in read("shared/catalog.json")["records"] if r["id"] == args.query]
        if len(matches) != 1:
            parser.error("qualified record ID did not resolve exactly once")
        result = matches[0]
    elif args.mode == "recipe":
        matches = [r for r in read("shared/recipes.json")["recipes"] if r["id"] == args.query]
        if len(matches) != 1:
            parser.error("qualified recipe ID did not resolve exactly once")
        recipe = matches[0]
        dependencies = [d for d in read("shared/pantry.json")["recipe_dependencies"] if d["book"] == recipe["book_key"] and d["book_recipe_id"] == recipe["local_id"]]
        if len(dependencies) != 1:
            parser.error("recipe pantry join did not resolve exactly once")
        result = {"recipe": recipe, "pantry_dependencies": dependencies[0]}
    else:
        pantry = read("shared/pantry.json")
        matches = [r for key in ["game_components", "game_leaf_inputs"] for r in pantry[key] if r["id"] == args.query]
        if len(matches) != 1:
            parser.error("component/leaf ID did not resolve exactly once")
        result = matches[0]
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
