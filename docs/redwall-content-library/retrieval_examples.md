# Bounded retrieval for the local coding agent

`query_library.py` reads this package without modifying it. Python's standard library is sufficient. Run these commands from the repository root after this package is installed under `docs/redwall-content-library/`.

Search individually indexed people, including their aliases and fact text:

```sh
python3 docs/redwall-content-library/query_library.py search Rulango --kind CHARACTER
```

Retrieve the complete, book-qualified record with source locators:

```sh
python3 docs/redwall-content-library/query_library.py record lord_brocktree::LB-CHARACTER-rulango
```

Search a selected book's food references, using all query words:

```sh
python3 docs/redwall-content-library/query_library.py search 'cranberry tart' --book lord_brocktree --kind FOOD --limit 10
```

Retrieve the recipe and its exact pantry dependency row together:

```sh
python3 docs/redwall-content-library/query_library.py recipe lord_brocktree::LB-RECIPE-cranberry-tarts-with-sweet-chestnut-sauce
```

Inspect a prepared component or leaf using the `target_id` returned by that recipe query:

```sh
python3 docs/redwall-content-library/query_library.py pantry COMPONENT_shared_wheat_flour
```

Search defaults to 25 compact results and excludes broader chunk dossiers. `--include-dossiers` includes those source-reading category notes. `--offset` selects the next page; `next_offset: null` means the search is exhausted. The maximum page size is 100. These are retrieval-interface limits authored for bounded output, not gameplay constants.

Exact record, recipe and pantry queries return one complete result or an error. They do not substitute a similarly named entry. Source-only entries and unbalanced production candidates retain their status; retrieval never activates game content.
