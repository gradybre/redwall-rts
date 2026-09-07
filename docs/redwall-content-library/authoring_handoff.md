# Content-library authoring contract

| Field | Value |
| --- | --- |
| Document | CONTENT-LIB-001 |
| Revision | 1.0 |
| Scope | Twelve supplied narratives; source reference and authored content candidates |
| Mechanical authority | Existing setting decisions, GDD/amendments, UI, balance and systems architecture retain their authority |
| Runtime activation | `NOT_RUNTIME_ACTIVE` for every record and recipe in this package |
| User authorization | Systematic book-by-book content extraction; explicit AI completion of omitted recipe ingredients; parallel work |

## 1. What the coding agent reads

Read `README.md`, `source_audit.json`, this contract, and the relevant book's `library.md`. Search `shared/catalog.json` for source records and `shared/recipes.json` for dish candidates. Resolve game ingredients through `shared/pantry.json`. Consult `shared/continuity.md` before combining appearances and `shared/locations_and_movement.md` before drafting spaces. The source-book JSON retains richer raw evidence where the normalized shared schema is more compact. `query_library.py` and `retrieval_examples.md` provide bounded, read-only access without loading the entire corpus into a coding agent’s context.

Research authority answers what was observed in the supplied books. It does not overrule Brendan's choices about admission, diet, anatomy, grief, children, rare uncertain wonder, scenario variety or movement. The source remains visible when a game adaptation differs.

The two earlier research directories remain separate historical passes. Their selected passages can still help interpretation, but this package owns the latest available-text coverage statement and content-library reconciliation. Its absence of a particular entry is not proof that the source never mentions it.

Strict machine schemas are supplied as `shared/catalog.schema.json` and `shared/recipes.schema.json`. `validation.json` also checks relational bounds, identity keys, source hashes and pantry joins that a per-record schema cannot establish.

## 2. Stable identity and provenance

The canonical research key is `book_key + "::" + local_id`. Matching a local prefix alone is prohibited: early per-book naming conventions reused `MF` for Mossflower and Marlfox. The book-qualified key prevents that ambiguity without breaking existing local references. Labels and spelling aliases are search aids, not keys. IDs are case-sensitive; a consumer must not lowercase them.

`book_key` is exactly one of:

```text
redwall
mossflower
salamandastron
martin_warrior
outcast
pearls_lutra
long_patrol
marlfox
lord_brocktree
taggerung
triss
rakkety_tam
```

| Field in `shared/catalog.json` | Exact type / rule |
| --- | --- |
| `schema_version` | String `redwall_research_catalog_v1` |
| `activation` | String `NOT_RUNTIME_ACTIVE` |
| `records` | Array of records; qualified `id` unique across the package |
| `id`, `book_key`, `local_id`, `label` | Nonempty strings; `id` equals qualified key above |
| `kind` | `CHARACTER`, `FACTION`, `PLACE`, `FOOD`, `INGREDIENT`, `OBJECT`, `CULTURE`, `ECOLOGY`, `SYSTEM`, or `THEME` |
| `aliases` | Array of strings; never an automatic identity merge |
| `record_scope` | `INDIVIDUAL_REFERENCE` or `CHUNK_DOSSIER` |
| `facts` | Nonempty array of fact objects |
| `facts[].text` | Paraphrase; may explicitly synthesize several events |
| `facts[].evidence_type` | `NARRATOR`, `CHARACTER_REPORT`, `BELIEF`, `AMBIGUOUS`, or `INFERRED_GAME` |
| `facts[].locator.block_start`, `.block_end` | Inclusive 1-based normalized source block IDs; integers satisfying `1 ≤ start ≤ end ≤ available_blocks` |
| `facts[].locator.source_start`, `.source_end` | Objects with `unit:string` and `unit_block:integer ≥ 1`; recalculated from the normalized source |
| `facts[].raw_fact_index` | Zero-based index into the source record's facts array |
| `game_use` | String describing candidate authoring use |
| `adaptation_notes` | Array of strings |
| `raw_record_path` | Package-relative path to book catalog |
| `runtime_activation` | String `NOT_RUNTIME_ACTIVE` |

A PDF unit such as `pdf_page_0078` is a physical PDF page identifier, not an asserted printed page number. Most EPUB units are actual member filenames. Lord Brocktree uses retained chapter/paragraph units (for example, Chapter 6); its source audit identifies the EPUB and this distinct normalization. Marlfox uses the retained MOBI text-unit label. The raw source filename and SHA-256 are in `source_audit.json`. Block IDs are meaningful only with that book, source hash and normalization. They must not be applied to another edition without relocation.

Some biographical records cover a long span; some compact dossiers list additional block references within their paraphrase. A broad biography supports discovery, while a new precise assertion needs the specific transition passage. A first-occurrence range must not be presented as independently proving a later death, promotion or migration. `CHUNK_DOSSIER` entries preserve category coverage and are excluded when counting individually named people.

## 3. Recipe contract

| Field in `shared/recipes.json` | Exact type / rule |
| --- | --- |
| `schema_version` | `redwall_research_recipes_v1` |
| `id`, `local_id`, `book_key` | Qualified and local recipe identities |
| `source_food_id` | Qualified key resolving to a `FOOD` record |
| `source_label` | Literary dish, drink or serving reference |
| `game_label` | Candidate game name, changed where ingredients materially differ; null for source-discourse-only records |
| `production_candidate` | Boolean; false means a source reference without a proposed production recipe |
| `source_occurrence` | Preserved per-book status; distinguishes service, recollection, proposal, joke and other contexts |
| `source_locators` | Nonempty array of the locator objects specified above |
| `source_ingredients` | Array of `{ingredient:string, raw_evidence:object}`; may be empty when the source only names the dish |
| `inferred_game_ingredients` | Array of `{ingredient:string, reason:string, confidence:string, evidence_type:"INFERRED_GAME"}` |
| `game_ingredients` | Ordered, duplicate-free ingredient strings; order is not a quantity ratio |
| `game_method_steps` | Nonempty array of authored preparation strings for production candidates; empty for discourse-only references |
| `method_evidence` | Preserved origin label; missing source steps remain authored |
| `source_preparation_context` | Source-context string; empty means consult linked food record and raw recipe |
| `adaptation_notes` | Array of strings |
| `raw_recipe_path` | Package-relative source recipe file |
| `quantities_status` | `NOT_BALANCED_LIBRARY_CANDIDATE` |
| `runtime_activation` | `NOT_RUNTIME_ACTIVE` |

Confidence is editorial confidence in a useful game completion, not the probability that Jacques intended the ingredient. A high-confidence bread base is still invented if the book only says bread. Ingredients nested inside “pastry,” “custard,” “fruit,” “herbs” or “cheese” are not recovered canon merely because a plausible formula can be supplied.

The pantry retains book-local formulas before applying shared defaults. Different oat creams or cheeses can therefore coexist. Join a shared recipe to `pantry.json.recipe_dependencies` by exact equality of `book_key == book` and `local_id == book_recipe_id`. Pantry dependency `id` uses a single colon; shared recipe `id` uses two colons, so these display keys are not equal. Pantry also exposes `shared_recipe_id`, which equals the shared recipe ID directly. Prefer each precomputed `game_inputs[].target_id` and `target_kind`. If rebuilding resolution, apply the explicit `game_only_normalization_map` first (for example, almonds → almond and barley malt → malted barley), then resolve exact local variant → exact shared variant → explicit leaf → unresolved error. Resolve recursively until all leaves are declared. Never apply game normalization to canonical source terms or use fuzzy similarity.

For a recipe dependency graph `G = (V,E)`, `E` points from a prepared component to each required constituent. A candidate is dependency-complete exactly when every referenced node exists and a depth-first search finds no edge to a currently visiting node. Leaf closure is:

```text
Leaves(v) = {v}                                      if v is a declared leaf
Leaves(v) = union(Leaves(c) for c in constituents(v)) otherwise
```

This is a dependency formula, not mass conservation or yield math. Source quantities, such as the two dace in Ruff's preparation, remain source examples. They do not become `quantity_milli`, nourishment, portion count or work ticks.

## 4. Required transformations and distinctions

| Source situation | Required authoring behavior |
| --- | --- |
| Ingredients omitted | Supply a concrete, labeled game formula and explain each addition; preserve the empty or partial source list |
| Generic ingredients | Select specific game plants, grains or fruit and mark the selection as inferred |
| Milk, cream or cheese with unstated origin | Retain unknown source origin; identify the proposed plant counterpart separately |
| Outcast greensap cheese | Preserve the specific grass-stem/tuber milk and nut-cheese evidence; do not generalize it to every cheese in every book |
| Source shellfish/fish outside the current whitelist | Preserve the source animal; name and document the approved game alternative |
| Source eel, pike or speaking fish | Keep literary evidence; no automatic food/resource or sapience rule follows |
| Fictional or uncertain culinary plants | Use an explicitly selected cultivated game counterpart; no real medicinal or foraging instructions are inferred |
| Wished-for, sung, pretended or rejected food | Retain occurrence status; do not label it an observed prepared meal |
| Feast or preservation quantities | Preserve narrative numbers as source facts; author gameplay values in the owning balance specification |
| A dish has multiple regional or household variants | Keep each source occurrence and formula provenance; combine only through an explicit recipe-family relation |
| Source abuse, torture or cruelty toward children | Preserve critical research context; apply the user's boundaries, with unresolved offscreen treatment still unresolved |

The existing setting bible §12.5 supplies an interim authoring guard: until offscreen treatment is clarified, exclude torture and deliberate cruelty toward children from new game depictions, backstory, implied threats and offscreen events. This broader interim exclusion is the existing agent interpretation, not a claim that Brendan has answered the unresolved treatment question. Critical research can identify the need for adaptation without importing those events into game content.

## 5. EARS acceptance rules

| ID | Requirement |
| --- | --- |
| LIB-001 | When a specification uses a source claim, the author shall attach a qualified record ID and an edition-specific locator. |
| LIB-002 | When an author adds an unstated ingredient or processing step, the author shall label it `INFERRED_GAME` and preserve the source list unchanged. |
| LIB-003 | If a source ingredient conflicts with the active game diet, the author shall provide an explicitly named alternative before submitting a production candidate. |
| LIB-004 | When an author combines books, the author shall select an era for every appearance and shall resolve office titles separately from individual identity. |
| LIB-005 | When contradictory claims exist, the author shall record the claims and evidence before selecting a scenario interpretation. |
| LIB-006 | When a source becomes incomplete or its hash changes, the author shall invalidate affected coverage claims and relocate affected citations. |
| LIB-007 | When a recipe dependency is absent or cyclic, the content validator shall reject activation with the unresolved component path. |
| LIB-008 | While numerical quantities, yield, work and unlock rules lack an owning approved specification, the candidate shall remain `NOT_RUNTIME_ACTIVE`. |
| LIB-009 | When a building or traversal reference is selected, its asset brief shall include connected access requirements and the mechanical owner. |
| LIB-010 | When an image or literary prop implies a mechanic, the author shall trace that mechanic to an adopted specification before asking the coding agent to implement it. |
| LIB-011 | When named-character source knowledge differs from player knowledge, the scenario author shall preserve the difference as event knowledge rather than alter historical identity. |
| LIB-012 | When a character changes health, office, household or item ownership, the scenario shall preserve the transition and its relevant continuing consequences. |

## 6. Data-oriented implementation boundary

This package is an offline authoring corpus. Do not load thousands of prose strings into each entity, attach a script per source person, or run source searching in a simulation tick. Do not invent a second ECS architecture here. The existing packed integer structure-of-arrays, generation-checked entity references, fixed ticks and settlement population limits remain authoritative.

An eventual approved content build should resolve selected research references into immutable content definitions once at import/build time. Simulation rows store the owning specification's compact IDs; localized prose, art annotations and literary evidence remain in separate authoring/presentation resources. Runtime save IDs must be assigned by the existing content/versioning contract, never by alphabetical position in this research index.

Connected tunneling, swimming/diving and climbing are already adopted direction under DEC-035 and SET-MOVE-001. These references add authoring evidence; they do not close MOVE-G01–05 or establish new speed, oxygen, excavation, clearance or hazard constants. The Windows qualification remains deferred until the user's PC is available; its stated 64 GB RAM and RTX 5090 are hardware context, not measured performance evidence.

## 7. Execution checklist for the next content task

1. Select the scenario family and era under the owning scenario decision. Record whether it is an original community, an Abbey scenario or a novel-associated scenario.
2. Select qualified references from this corpus; distinguish live participants, history, legends, artifacts and optional cameos. Do not fill all source characters into one population.
3. Resolve identity and geography conflicts using the continuity and location ledgers. Preserve any unresolved point as an explicit authoring issue.
4. Select household, food, craft, everyday-life and environmental references alongside military ones. Name their visible evidence: objects, surfaces, jobs, sounds or routines.
5. For each dish, select its source occurrence and game variant, expand pantry dependencies and record all inferred ingredients and methods.
6. Author quantities, work, yields, resource IDs, equipment, unlocks and economic interactions in the owning balance/data document before activation. Use its existing integer units; no numerical defaults come from this library.
7. For each traversable space, specify connected entrances/exits, body/load clearance, surface and water state, construction method, assisted access and failure recovery in the movement owner.
8. Produce an asset brief that points to the reviewed image IDs and literary records. Required new views are authored references; do not pretend a novel supplies a measured model sheet.
9. Validate references, dependencies, policy compatibility, locale strings, save/content versioning and scenario coherence using the relevant existing acceptance checks.
10. Change `NOT_RUNTIME_ACTIVE` only in the approved implementation content, never by rewriting research evidence. Record implementation decisions and validate the resulting behavior separately.

## 8. Numbers and remaining limits

| Number family | Origin | Allowed interpretation |
| --- | --- | --- |
| Word/block/chunk/record totals and hashes | Computed from this supplied corpus and generated records | Audit and indexing only |
| Block ranges, physical page units and source counts | Inherited source/extraction evidence | Locate and assess a claim |
| Source food amounts, distances, army sizes and seasons | Inherited narrative statements | Fictional context; uncertainty retained |
| Qualified-ID convention and schema version | Newly authored research infrastructure | Offline authoring and validation |
| AI recipe constituents and component methods | Newly authored by this pass | Explicit game candidates, no canonical status |
| Runtime quantities, yields, work, speeds and effects | Not originated by this pass | Must come from the owning implementation specification |

The unsatisfied source item is full Eulalia! access; the supplied Salamandastron edition also has a verified gap. A complete edition-level illustration review, measured canonical world map and absolutely error-free concordance are not established. Precise scenario casts, maps and recipe balance remain separate design tasks. These limits do not invalidate the completed inspection of every available normalized narrative block.
