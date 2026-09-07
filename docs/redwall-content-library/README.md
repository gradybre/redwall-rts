# Redwall — systematic content library

This package is the full available-text content pass requested after the earlier targeted studies. It separates book evidence, interpretation, and openly authored game recipe completions. It contains no active game data.

## Start here

1. Read [the source audit](source_audit.json) for the exact corpus and coverage limits.
2. Read [the authoring contract](authoring_handoff.md) before using references in specifications or assets.
3. Use the [shared catalog](shared/catalog.json) and [recipe library](shared/recipes.json) for stable, book-qualified machine-readable records.
4. Use the [shared pantry](shared/pantry.md) for ingredient variants and complete component dependencies.
5. Read [identity and era reconciliation](shared/continuity.md), [locations and movement](shared/locations_and_movement.md), and [theme and material direction](shared/theme_and_material_direction.md) before combining books.
6. Use [bounded retrieval examples](retrieval_examples.md) to query specific records without loading the whole library into context.

## Available corpus and coverage

| Book | Inspected blocks | Inspected words | Chunks | Catalog records | Recipe / serving candidates |
| --- | ---: | ---: | ---: | ---: | ---: |
| [Redwall](books/redwall/library.md) | 3,730 | 102,835 | 18 | 446 | 63 |
| [Mossflower](books/mossflower/library.md) | 5,099 | 114,268 | 20 | 608 | 89 |
| [Salamandastron](books/salamandastron/library.md) | 3,959 | 103,693 | 18 | 757 | 172 |
| [Martin the Warrior](books/martin_warrior/library.md) | 3,995 | 100,604 | 17 | 630 | 171 |
| [The Outcast of Redwall](books/outcast/library.md) | 3,577 | 97,362 | 17 | 817 | 189 |
| [Pearls of Lutra](books/pearls_lutra/library.md) | 481 | 110,415 | 19 | 662 | 172 |
| [The Long Patrol](books/long_patrol/library.md) | 3,389 | 95,163 | 16 | 600 | 135 |
| [Marlfox](books/marlfox/library.md) | 3,473 | 108,548 | 19 | 684 | 177 |
| [Lord Brocktree](books/lord_brocktree/library.md) | 3,560 | 105,555 | 18 | 499 | 139 |
| [The Taggerung](books/taggerung/library.md) | 4,065 | 126,217 | 22 | 623 | 155 |
| [Triss](books/triss/library.md) | 3,857 | 110,414 | 19 | 626 | 147 |
| [Rakkety Tam](books/rakkety_tam/library.md) | 583 | 105,270 | 18 | 713 | 146 |

Current totals: **1,280,344 inspected words**, **221 reading chunks**, **7,665 catalog records** and **1,755 recipe/serving candidates**. These include 1,430 broader category dossiers; counts are not all unique in-world people or meals. Different appearances, variants, recollections and cultural references are retained.

## Exact completeness claim

All twelve available books are read block by block when `source_audit.json` has `FULL_AVAILABLE_CORPUS_INSPECTED`. This is systematic coverage of the supplied normalized narrative, not a promise of an infallible concordance or a complete library of the entire Redwall series. **Eulalia! full text is absent. Salamandastron has a confirmed break in the supplied EPUB, apparently missing printed pages 314–315.** The collection-labeled EPUB contains Lord Brocktree, not twenty books. No missing source prose has been invented.

Source audit hashes identify the supplied files and each inspected normalized chunk. Full novels, extracted prose and source-reading scratch files are excluded from this package. Facts use paraphrases and edition-specific locators. Earlier plot-oriented and targeted material-world studies remain historical companions, with their original narrower coverage.

## Browse by content kind

| Content | Directory |
| --- | --- |
| Character | [character index](shared/character_index.md) |
| Faction | [faction index](shared/faction_index.md) |
| Place | [place index](shared/place_index.md) |
| Food | [food index](shared/food_index.md) |
| Ingredient | [ingredient index](shared/ingredient_index.md) |
| Object | [object index](shared/object_index.md) |
| Culture | [culture index](shared/culture_index.md) |
| Ecology | [ecology index](shared/ecology_index.md) |
| System | [system index](shared/system_index.md) |
| Theme | [theme index](shared/theme_index.md) |

## Recipe use

A dish named without ingredients receives an explicitly AI-authored game ingredient set and preparation proposal. A dish with some ingredients preserves those separately from added binders, liquid, seasoning or component formulas. A story recipe is not assumed to supply quantities, cooking times, yields or unlock rules. Those values belong to a separate economy/balance specification; every candidate here remains `NOT_RUNTIME_ACTIVE`. Source fish, uncertain plants, milk and cheeses retain their literary evidence even where the current game needs a renamed counterpart.

The library includes jokes, wished-for dishes, raw food stocks, rejected foods and ritual uses where relevant. Their occurrence status matters. A recipe candidate is not proof that a meal was cooked, and a generic ingredient such as “fruit” is not proof of any particular orchard crop.

## Validation and remaining work

[validation.json](validation.json) records coverage, locator, ID, recipe-reference and pantry-dependency checks. [authoring_handoff.md](authoring_handoff.md) specifies the remaining source, continuity, balance and implementation gates. No gameplay rule, current admission policy, numerical catalog, save version or movement engineering gate is changed by this research.
