# Authoring handoff — turn evidence into coherent game content

`DESIGN-HANDOFF-002` · Revision 1.0 · This is a document/content workflow, not a new runtime ECS schema. No book excerpt, artwork slide or recommendation automatically registers a recipe, faction, species ability or scenario.

## 1. Content records and provenance

Use the following exact fields when proposing a content entry. Store one record per proposed item, character role, custom, place or asset brief. These fields belong in authoring data; the runtime receives validated compact numeric catalogs only after their owning specs define them.

| Field | Type / allowed values | Validation |
|---|---|---|
| `content_id` | String matching `^[A-Z]+-[0-9]{3}$` | Unique within this package's catalog |
| `kind` | `DISH`, `ITEM`, `CHARACTER_ROLE`, `FACTION`, `PLACE`, `CUSTOM`, `ASSET_BRIEF` | Required |
| `label` | Nonempty string | Clear source or adapted name |
| `evidence_ids` | Nonempty array of strings | Each resolves to a source register; explicitly prefix earlier studies |
| `source_claim` | Nonempty paraphrase | Observation distinguished from character belief |
| `interpretation` | Nonempty string | State why this matters to the game |
| `adaptation_status` | `SOURCE_ONLY`, `PROPOSED`, `ADOPTED_DIRECTION`, `APPROVED_CATALOG` | Only policy or owning catalog can promote status |
| `scenario_binding` | `UNASSIGNED` or an existing validated scenario key | Unassigned never implies all scenarios |
| `current_catalog_key` | Existing key or JSON `null` | Null means no runtime mapping; reject activation |
| `deviations` | Array of nonempty strings | Record all intentional changes; empty only when none claimed |
| `owner_document` | Repository-relative existing Markdown path | Owning specification identified |
| `numeric_provenance` | Array of records `{field, value, origin, evidence}` | Origin `INHERITED_PROJECT`, `DERIVED_PROJECT`, `AUTHORED_GAME`, `SOURCE_SCENE_COUNT`; no unsupported canon measurements |
| `activation_state` | `BLOCKED_UNSPECIFIED`, `READY_FOR_VALIDATION`, `VALIDATED` | Completeness and recorded checks determine promotion |

`null` and `UNASSIGNED` are deliberate inactive research states, not implementation placeholders. A consumer shall refuse to treat them as runtime defaults. In particular, “recipe details in source” is not a complete input/output definition.

## 2. Character and faction briefs

A named character's record must distinguish **individual identity, species, culture, affiliation, occupation, scenario era and portrayal**. Cregga's military role in one novel and her later Abbey role cannot be loaded as simultaneous defaults. The founding Martin and the Martin in Pearls of Lutra require different identity keys. Lord Brocktree's frame household belongs to a later era than its narrated events.

A faction brief needs its institutions, home territory, livelihood, leadership practice, internal disagreement, external relations and visual culture. Example distinctions supported by the studies:

| Community | Useful identity axes | Do not infer |
|---|---|---|
| Abbey | Hospitality, care, food, records, succession, ritual | Infallibility, one unchanged roster or universal moral agreement |
| Long Patrol | Service, training, dispatch, fellowship, veteran history | All hares enlist or want war |
| Guosim / particular shrew communities | Watercraft, cooking, public argument, local leadership custom | One culture or legal system for all shrews |
| Named otter holts | River/coast/island livelihoods, family histories and different manners | One otter voice, diet or mandatory job |
| Noonvale and players | Cultivation, privacy, performance and support networks | All peaceful communities lack agency or practical skill |
| Courts, raiders and coercive regimes | Specific leadership, supply dependencies and conduct | Moral alignment from species, fur color or dialect |

The individual book tables are casting references. They do not commission every canonical character for launch. A source-rich all-era collection and a temporally coherent scenario are different authoring responsibilities.

## 3. Art and animation handoff

The image-reference model guide remains the primary direct illustration handoff. Pair its IMG IDs with the relevant book evidence. The text adds material, function, social use and sensory context; a single illustration still cannot supply unseen topology or measured anatomy.

| Brief element | Required content |
|---|---|
| Identity/silhouette | Species features, individual build, clothing/culture, era, reference IMG IDs |
| Anatomy | Recognizable face, paws, ears and tail; game scale anchored on the existing 1.0 m mouse |
| Materials | Named primary cloth/wood/clay/stone/metal and surface condition tied to use |
| Work props | Actual task, hands/support needed, held/stowed state and storage location |
| Movement | Supported profile/mode, clearance envelope, transition endpoints and contact anchors |
| Views | Front/side/back plus necessary contact/stowed-gear views before claiming a complete model sheet |
| Export | Follow crowd §9 and current Blender pipeline; no new axes, bone budget or mesh limits here |
| Review | Inspect at actual RTS camera distance and at close detail; compare silhouette and contacts against references |

Use original designs guided by references and declared adaptations. This task generates no models and runs no paid asset services.

## 4. Scenario and systems opportunities

| Priority | Proposed work | Concrete deliverable | Adoption state |
|---|---|---|---|
| 1 | Connected inhabited movement | Close MOVE-G01–05 in order | Direction adopted; exact engineering incomplete |
| 2 | Rowan's daily presence | Original routine/voice brief tied to existing start data and named relationships | Authoring proposal; founding biography remains open |
| 3 | First cuisine extension | Complete game rows for chosen dishes, including source mapping and every economy field | Proposal; no new recipes activated |
| 4 | Dwelling contrast | Measured game plans for root home, accessible tree home and light cave household | Accepted style variety; individual plans still to author |
| 5 | Community event briefs | Welcome meal, harvest celebration, skill demonstration, quiet remembrance | Existing broad themes adopted; each event's mechanics need owner approval |
| 6 | Regional/cast packets | Era-specific Abbey, mountain, holt and traveling community briefs | Scenario choices remain to bind |

Additional useful systems contexts are literacy/apprenticeship, repair, seasonal work, water access, household accessibility, object custody, recipe transmission, guest service, duty coverage, care staffing and respectful retirement. They can first appear through authored descriptions and existing tasks. Do not launch a new simulation subsystem merely because a novel provides an appealing example.

## 5. EARS checks for content integration

| ID | Requirement |
|---|---|
| CONTENT-REQ-001 | WHEN a source detail becomes gameplay content, its record shall identify the owning catalog and all deliberate deviations. |
| CONTENT-REQ-002 | IF a recipe lacks any required authoritative field, THEN the importer shall reject activation instead of supplying an arbitrary default. |
| CONTENT-REQ-003 | WHEN a scenario selects a canonical character, its roster shall bind an era-specific identity and role. |
| CONTENT-REQ-004 | IF a source claim is a dream, recollection, report or hypothesis, THEN the lore record shall preserve that attribution. |
| CONTENT-REQ-005 | WHEN a narrative object is renamed or transferred, its persistent identity shall remain distinct from its display name under the eventual object contract. |
| CONTENT-REQ-006 | WHEN flavor presentation depicts a simulated transfer or completed job, it shall correspond to committed authoritative state. |
| CONTENT-REQ-007 | IF a movement brief lacks profile clearance or transition contacts, THEN asset acceptance shall remain incomplete for that movement mode. |
| CONTENT-REQ-008 | WHEN a source practice conflicts with adopted morality, diet, anatomy or content boundaries, the brief shall record the adaptation explicitly. |

## 6. Completion and limitations of this pass

Completed: twelve separate design studies; 115 traceable passage records; food/ingredient/object/custom catalog; qualitative location atlas; authoring rules; movement direction reconciliation in owning files. Earlier plot-oriented studies remain separate.

Not completed or claimed: complete sequential rereading of twelve novels; a full Eulalia study; an exhaustive canon concordance; all scenario eras/casts; measured canonical maps; production-ready new recipes; completed movement engine/schema/budgets; Windows qualification; final model sheets. These are bounded limitations, not hidden defaults. No new quantitative game balance originates in this literary analysis.
