# Redwall RTS — Setting Bible

| Field | Value |
|---|---|
| Document | SET-LORE-001 |
| Revision | 0.20 — systematic supplied-book content library and recipe provenance, 2026-09-06 |
| Purpose | Shared creative context for the human director, planning agent, Claude Code, and asset agents |
| Creative source order | Redwall: six-book focus plus whole-series context → current Redwall-rts project → earlier woodland-colony material; see §3.2 |
| Decision owner | Brendan; explicit project choices may deliberately depart from Redwall |
| Companion | [Setting decisions and interview](setting_decisions.md) |
| Implementation status | GDD revision 1.1 and SET-AMEND-001 govern adopted admission and food rules; this is specification work, not a completed runtime |
| Foundation status | All setting types and starting-premise families confirmed for first release; whole series is the reference scope; admission/diet, scenario roles, rare wonder and selectable settlement forms including earth-built homes confirmed; all three underground construction methods, serious grief and visible family life confirmed; detailed scenario, construction and family simulation contracts remain open |

## 1. Read this first

The game should make a woodland community worth knowing: food has makers, buildings hold shared routines, the seasons leave marks, and hardship matters because particular creatures must live through it. Redwall is the primary creative reference. The first playable release expresses that world through settlement life; the larger project also intends campaign exploration and tactical warfare.

This paragraph is a project synthesis of [GDD §2](game_gdd.md#2-player-fantasy), the [concept brief](game_concept.md), and the reference evidence in §3. It is not a quotation or a claim that every game mechanic appears in the novels.

`USER_CONFIRMED`, Rounds 1–2: The product shall offer original communities in Redwall's world, Redwall Abbey scenarios, and scenarios associated with particular novels or eras. Players shall also have different starting premises, including new refuges, restoration, and established communities. The creative reference spans the whole series. DEC-028 confirms these options must be built for the first playable release; one scenario plus later promises is insufficient. The concrete scenario lineup and initialization contracts still require specification. Section 7 defines the scenario-specific context needed to keep that variety coherent.

### 1.1 Two kinds of authority

| Question | Authority | Required response to a conflict |
|---|---|---|
| What is true in the books? | An identified novel passage; official author material; then publisher summaries, with evidence limits recorded | Record both claims and their sources; do not invent a reconciliation |
| What creative direction should this game pursue? | Brendan's explicit decisions, then Redwall, then the current project, then woodland-colony gap material | Use the stronger source; record any deliberate adaptation |
| What does the current game implement? | `game_gdd.md`, `ui_ux_controls.md`, and applicable architecture contracts | Preserve the current rule until a concrete revision reconciles affected documents |
| What is still undecided? | `setting_decisions.md` | Ask the linked question; continue work that does not depend on the answer |
| Can an asset or text imply a new mechanic? | No; it needs a matching gameplay specification | Flag the implication and revise the asset/text or the gameplay specification |

The creative hierarchy does **not** mean hiding contradictions under the existing GDD. It means Redwall motivates the proposed correction, while the correction is documented explicitly instead of silently changing simulations, saves, content IDs, or balance.

### 1.2 Status vocabulary

These exact tokens apply to every numbered creative record. A section-level status applies to its unlabelled rows and examples.

| Token | Meaning | What an implementation agent may do |
|---|---|---|
| `USER_CONFIRMED` | Explicitly chosen in this conversation; decision record includes the statement | Use within the recorded scope; reconcile mechanics before changing them |
| `SOURCE_SUPPORTED` | Supported by an identified Redwall source at the stated evidence level | Use as reference; this alone does not authorize a character cameo or a new system |
| `PROJECT_BASELINE` | Already specified in the current project | Implement under the owning specification; do not call it book canon |
| `LEGACY_CANDIDATE` | Imported from woodland-colony for consideration | Use to formulate proposals; do not silently establish it as current lore |
| `PROPOSED` | Newly authored direction in this document | Explore in clearly identified drafts; do not present it as an accepted world fact |
| `OPEN` | A material creative decision lacks an answer | Preserve the stated existing behavior; defer only the dependent creative content |
| `SUPERSEDED` | Replaced by a recorded decision | Retain as history; do not implement |

`SOURCE_SUPPORTED` means the narrow claim is supported, not that the complete series has been examined. Publisher descriptions cannot establish exact room dimensions, all moral exceptions, a universal theology, or an exhaustive chronology.

### 1.3 Mandatory context capsule

Every feature plan and asset brief shall name its relevant lore records, its mechanical owner, and any unresolved decisions. Use this document's IDs rather than relying on a task's conversation history.

```yaml
context_contract_version: 1
creative_document: docs/setting_bible.md
creative_revision: "0.20"
decision_document: docs/setting_decisions.md
mechanical_documents:
  - docs/game_gdd.md
  - docs/ui_ux_controls.md
scope: RELEASE_1
lore_records:
  - LORE-P01
  - LORE-T01
open_decisions:
  - DEC-003
canon_claims_added: []
gameplay_changes: []
```

This is a document header example for a release 1 communal-life task, not a runtime file or a universal list of dependencies. Replace its record lists with the records relevant to the actual task. Empty arrays mean no additions; they are not unfinished work.

## 2. Source map and research boundaries

### 2.1 Redwall evidence consulted

Initial web sources were inspected on 2026-09-05; the six-book publisher descriptions were checked on 2026-09-06. The book titles below identify creative anchors; the evidence used here is the linked publisher text or identified guide pages. The subsequent [novel research](redwall_novel_analysis.md) adds selected primary-text excerpts and a complete reading of the supplied Lord Brocktree text. Its [dedicated study](lord_brocktree_analysis.md) and [source audit](lord_brocktree_source_audit.json) distinguish that coverage from unverified edition integrity. The [expanded series package](redwall-series/README.md) now adds targeted primary-passage studies of eleven supplied novels, including four more focus books. It records 96 passage entries across 102,954 inspected extracted words. At that stage the other five focus novels lacked complete sequential readings; the later systematic pass in §23 supersedes that coverage status. Selected PDF pages were visually checked for text extraction; no edition-wide illustration analysis was performed. The original publisher-source rows below retain their original evidence status.

| Source ID | Source | Evidence used | Appropriate use |
|---|---|---|---|
| SRC-R01 | [Redwall — publisher description](https://www.penguinrandomhouse.ca/books/722141/redwall-by-brian-jacques/9781400085798) | Publisher account of Matthias, Cluny, and supporting cast | Home, personal courage, contrasting danger and humor |
| SRC-R02 | [Mossflower — publisher description](https://www.penguinrandomhouse.com/books/289823/mossflower-by-brian-jacques/) | Tsarmina, Kotir, Martin, Gonff, and the journey toward Salamandastron | Oppression, resourcefulness, allied resistance, the wider world |
| SRC-R03 | [The Redwall Cookbook — official publisher page](https://www.penguinrandomhouse.com/books/286798/the-redwall-cookbook-by-brian-jacques-illustrated-by-christopher-denise/) | Official culinary companion; plant dishes, a seafood soup, beverages, storytelling | Food vocabulary and the importance of culinary identity; no game recipe math |
| SRC-R04 | [Publisher's Redwall series overview](https://www.penguinrandomhouse.com/series/DUI/redwall/) | Separate title descriptions, including The Long Patrol, High Rhulain, Outcast of Redwall, and Marlfox | Institutions, foreign communities, artifacts, and tensions; no assumed universal rules |
| SRC-R06 | [The Long Patrol — publisher description](https://www.penguinrandomhouse.com/books/294609/the-long-patrol-by-brian-jacques/9781101666074) | Tammo’s ambition to join, his journey and the Patrol’s defence of the Abbey | Service, experience, collective duty and stakes; no unit-stat or complete drill doctrine claim |
| SRC-R07 | [Salamandastron — publisher description](https://www.penguinrandomhouse.com/books/291947/salamandastron-by-brian-jacques/) | Summer at the Abbey contrasted with a besieged stronghold and intersecting character journeys | Differentiated communities, fortress identity and connected storylines; no measured floor plan |
| SRC-R08 | [Eulalia! — publisher description](https://www.penguinrandomhouse.com/books/292509/eulalia-by-brian-jacques/) | Sea raiders, a succession search and a separate force in Mossflower | Several threat groups and leadership continuity; no automatic import of every plot incident |
| SRC-R09 | [Lord Brocktree — publisher description](https://www.penguinrandomhouse.com/books/296445/lord-brocktree-by-brian-jacques/) | Brocktree and Dotti rally varied allies against an occupied Salamandastron | Coalition-building and resourceful leadership; no full campaign/chronology verification |
| SRC-R05 | [Publisher-hosted teacher's guide](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf) | Printed pp. 2–4: author/editor conversation and introduction; p. 8: classroom discussion of material culture | Evidence about accents, recurring abbey identity, chronology distinction, symbols and simple machinery |

SRC-R10 / EV-LB02 is the user-supplied Lord Brocktree text, fully read in the supplied form. Its filename and metadata claim a Books 1–20 collection, but its actual narrative contains only Lord Brocktree. Use the source audit and Chapter/block locators; do not treat the collection ISBN as a verified edition identifier.

SRC-R11 identifies the eleven-file user-supplied corpus in [the expanded source audit](redwall-series/source_audit.json). Individual EV identifiers and coverage resolve there. The user requested deeper analysis of these additional books; this expands evidence, not the approved launch lineup or the six-book focus.

Do not cite fan discussion as though Jacques wrote it. The official author's FAQ did not load successfully during this research; no claim in this draft depends on its contents. No supposed chapter numbers or novel page numbers have been invented.

### 2.2 Local evidence

| Source ID | File | Relevant sections / interpretation |
|---|---|---|
| SRC-P01 | [game_concept.md](game_concept.md) | Pitch, three layers, Redwall references, early species ideas; some mechanics superseded |
| SRC-P02 | [game_gdd.md](game_gdd.md) | Revision 1.1; authoritative rules v2, reconciled with [setting_rules_amendment.md](setting_rules_amendment.md) |
| SRC-P03 | [ui_ux_controls.md](ui_ux_controls.md) | §2 palette/type; resident naming and new-settlement controls |
| SRC-P04 | [crowd_rendering_architecture.md](crowd_rendering_architecture.md) | §9 asset scale, axes, rig and export limits |
| SRC-P05 | [gameplay_balance.md](gameplay_balance.md) | Derived catalogs and explicit newly authored values; carries its own draft/conflict status |
| SRC-P06 | [systems_architecture.md](systems_architecture.md) | Packed data, persistence, allocation and validation contracts |
| SRC-L01 | Earlier `work/publish-woodland-colony/SETTING_BIBLE.md` | Separate project's living draft; portable extract recorded in §6 |
| SRC-U01 | Brendan's instruction, 2026-09-05 | Redwall first, current project second, woodland-colony for gaps; interview to deepen the foundation |
| SRC-U02 | Brendan's Round 1 answers, 2026-09-05 | All three setting types as player options; multiple starting premises; references spanning the whole series |
| SRC-U13 | Brendan's reference refinement and Round 10 answers, 2026-09-06 | Six named books guide the whole-series reference; experienced mouse-keeper Rowan; displaced founding; torture/child-cruelty boundaries with treatment clarification pending |
| SRC-U12 | Brendan's Round 9 answers, 2026-09-06 | Mixed story delivery; recommended community-written Refuge Charter; varied antagonist motives/scales for gameplay variety; DEC-022/023/013 |
| SRC-U11 | Brendan's Round 8 answers, 2026-09-06 | Blended naming traditions, all offered feast meanings and a mix of all offered sound directions; DEC-016/007/021 |
| SRC-U10 | Brendan's Round 7 answers, 2026-09-06 | Recognizable animal anatomy, distinct voices with light dialect, and “bits of all three” continuity approaches; DEC-019/017/025 |
| SRC-U09 | Brendan's art-direction selection, 2026-09-06 | “A combination of 1 and 3 appropriately combined” adopts the storybook/grounded-realism blend in DEC-018 |
| SRC-U08 | Brendan's Round 6 answers, 2026-09-06 | “Your recommendation” adopts DEC-033; “Warm everyday humor” confirms DEC-012; visual comparison requested with no selection |
| SRC-U07 | Brendan's family-model approval, 2026-09-06 | “That works for me” adopts DEC-032 following the recommendation; child vulnerability remains separate under DEC-033 |
| SRC-U06 | Brendan's Round 5 answers, 2026-09-06 | “All methods work together.” and “Truth uncertain” confirm DEC-031/030. “What do you recommend?” requests advice on DEC-032 without adopting it |
| SRC-U05 | Brendan's Round 4 answers, 2026-09-06 | All three underground construction options; serious consequences and grief; visible everyday family life. Exact wording and limits are in DEC-029/011/015 |
| SRC-U04 | Brendan's Round 3 answers, recorded 2026-09-06 | Roles vary by scenario; wonder is rare and meaningful; players choose settlement styles including burrows/hillside homes. Exact wording is in DEC-008/009/010 |
| SRC-U03 | Brendan's Round 2 answers, 2026-09-05 | “All built” confirms coverage; following the requested recommendations, “Adopt both” confirms DEC-005/006 |

SRC-L01 was read at `/Users/brendan/Documents/Codex/2026-09-05/i-am-building-a-woodland-rts/work/publish-woodland-colony/SETTING_BIBLE.md`. It is not required on Claude's machine: all material considered for import is summarized below with its original status. Its original-setting restriction is superseded **for this project** by SRC-U01; the old file itself remains unchanged.

## 3. Redwall reference anchors

All records in this section are `SOURCE_SUPPORTED`. The final column is explicitly project interpretation, not an additional canon claim.

| Record | Narrow supported reference | Project interpretation |
|---|---|---|
| LORE-R01 | Matthias must overcome personal fear to help his home face Cluny; Constance, Basil, and Methuselah have distinct identities. [SRC-R01](https://www.penguinrandomhouse.ca/books/722141/redwall-by-brian-jacques/9781400085798) | Give work, friendship, and courage recognizable individuals; a population counter alone cannot carry the fantasy |
| LORE-R02 | Martin and Gonff escape Kotir under Tsarmina's rule and seek help at Salamandastron. [SRC-R02](https://www.penguinrandomhouse.com/books/289823/mossflower-by-brian-jacques/) | The wider world can contain oppression and meaningful alliances without turning every settlement activity into warfare |
| LORE-R03 | The official cookbook connects named dishes and drinks with an accompanying Redwall story; its examples include vegetable cookery and seafood. [SRC-R03](https://www.penguinrandomhouse.com/books/286798/the-redwall-cookbook-by-brian-jacques-illustrated-by-christopher-denise/) | Meals deserve sensory specificity and social context. This evidence does not establish mammal-hunting customs |
| LORE-R04 | The Long Patrol is associated with hares and Salamandastron in the publisher's summaries. [SRC-R04](https://www.penguinrandomhouse.com/series/DUI/redwall/) | A culture or institution is not equivalent to a species-wide occupation restriction |
| LORE-R05 | High Rhulain connects an otter at Redwall, an injured osprey, and oppressed otters elsewhere. [SRC-R04](https://www.penguinrandomhouse.com/series/DUI/redwall/) | There can be several communities and histories within one species |
| LORE-R06 | Outcast of Redwall describes Veil being raised at the abbey, banished, and facing competing loyalties. [SRC-R04](https://www.penguinrandomhouse.com/series/DUI/redwall/) | Species morality and acceptance require a deliberate adaptation decision, not a simplistic universal inference from a blurb |
| LORE-R07 | Marlfox centers a threat to the tapestry of Martin. [SRC-R04](https://www.penguinrandomhouse.com/series/DUI/redwall/) | A shared object can embody communal memory; do not install the canonical tapestry in an unrelated settlement by default |
| LORE-R08 | The guide treats the abbey as the continuing center across generations, distinguishes publication from story order, and discusses its leaders and defenders. [SRC-R05, printed p. 4](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf) | Choose an era before placing named characters together. An abbey's continuity can be more important than one protagonist's lifetime |
| LORE-R09 | Jacques and his editor discuss distinct accents; the guide also discusses tapestries, standards, fortresses, and simple machines. [SRC-R05, printed pp. 2–3, 8](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf) | Differentiate voices and useful handmade objects while preserving readable instructions |

### 3.1 What remains unverified

The following are research questions, not negative claims about Redwall: exact dietary boundaries across the novels; an exhaustive sapience classification; detailed religious practice and afterlife terminology; precise map distances; exact heights; universal rules for species allegiance; whether a particular proposed cameo is alive in a chosen era. Answer with the selected book/edition and relevant passage, or classify the game choice as an adaptation.

The bible intentionally avoids a compressed retelling of every novel. Its role is to preserve the specific context that changes design and implementation decisions.

Whole-series reference scope is confirmed by SRC-U02. It does not mean this draft has verified every book, that every novel already has a commissioned scenario, or that characters from different eras coexist. Individual scenario evidence must be added as those scenarios are selected.

### 3.2 Six-book primary creative focus

`USER_CONFIRMED`, DEC-034 / SRC-U13. `LORE-U27`: Keep the whole series available for context, with **Redwall, Mossflower, The Long Patrol, Salamandastron, Eulalia! and Lord Brocktree** as the primary creative focus. The user supplied this set; its listed order is not a numeric ranking or a chronology. Explicit adopted game decisions remain the adaptation authority. Within Redwall references, begin with the relevant focus books, then use other novels to fill or challenge the context before falling back to current-project and legacy-original material.

The evidence column below summarizes only the consulted official publisher descriptions. The design-use column is `[NEW interpretation]`, not a quotation from Jacques, a promise that every feature exists in that novel, or a replacement for reading the relevant passages.

| Focus book | Narrow source evidence | Main design guidance to develop | Limit / verification needed |
|---|---|---|---|
| Redwall | Matthias, the threatened Abbey and a distinctive supporting cast [SRC-R01](https://www.penguinrandomhouse.ca/books/722141/redwall-by-brian-jacques/9781400085798) | A home worth caring about; ordinary residents, courage and collective defence | Inspect passages for exact routines, descriptions, cast and places before recreating them |
| Mossflower | Martin and Gonff oppose Tsarmina, with allies and a journey toward Salamandastron [SRC-R02](https://www.penguinrandomhouse.com/books/289823/mossflower-by-brian-jacques/) | Woodland communities under pressure, resourcefulness, solidarity and resistance | Rowan’s displacement is not automatically this novel’s conflict; exact links need scenario selection |
| The Long Patrol | Tammo joins a larger duty around protecting Redwall, confronting the stakes of service [SRC-R06](https://www.penguinrandomhouse.com/books/294609/the-long-patrol-by-brian-jacques/9781101666074) | Institutional identity, comradeship, new versus experienced members and the cost of protecting others | Exact ranks, drills, tactics and unit mechanics require separate evidence/specification |
| Salamandastron | The Abbey and besieged fortress appear in connected storylines [SRC-R07](https://www.penguinrandomhouse.com/books/291947/salamandastron-by-brian-jacques/) | Contrast civic and fortress life while keeping them part of one world; distinct places and responsibilities | A fortress theme is not a verified terrain cross-section, interior map or license for extra combat mechanics |
| Eulalia! | Maritime raiders, a leadership succession search and another hostile group share the story [SRC-R08](https://www.penguinrandomhouse.com/books/292509/eulalia-by-brian-jacques/) | Multiple pressures rather than one universal enemy; continuity of leadership and meaningful journeys | Apply content boundaries before selecting incidents; uncertain supernatural truth remains DEC-030 |
| Lord Brocktree | Brocktree and Dotti gather different allies to challenge occupation [SRC-R09](https://www.penguinrandomhouse.com/books/296445/lord-brocktree-by-brian-jacques/) | Leadership through coalition, complementary peoples and ingenuity against larger forces | No automatic named cameo, founding date, army roster or imported war in the current Refuge |

For every scenario/feature/asset brief, identify which focus-book anchor informs it and the supported claim. If another novel supplies a better specific reference, name it and explain the connection; do not exclude it because it is outside the six. If a visual or detail is original game design, label it original rather than attaching an unrelated book citation. Include the exact source evidence before claiming canonical dialogue, geometry, clothing, chronology or biography.

Reference selection does not commission six campaigns, combine their casts into one era, or replace source-supported contradictions with an invented answer. Boundary subjects named under DEC-027 are filtered during adaptation even when a focus novel contains relevant material. Existing numeric simulation and asset budgets remain unchanged by this creative refinement.

### 3.3 Passage analysis and adaptation research

[Novel analysis and adaptation research](redwall_novel_analysis.md), SET-RESEARCH-001 revision 0.3, supplements this bible. [Lord Brocktree: novel analysis](lord_brocktree_analysis.md), SET-RESEARCH-LB-001 revision 1.0, now covers its entire supplied narrative: Prologue, Chapters 1–38 and Epilogue. Selected Eulalia! excerpts and limited author evidence retain their stated limits. [SET-RESEARCH-SERIES-001](redwall-series/README.md) adds eleven targeted primary-passage studies, including Redwall, Mossflower, The Long Patrol and Salamandastron. Earlier publisher rows remain premise-level evidence, while the new studies supply separate passage-backed findings. **That earlier pass fully read one focus novel. The later §23 systematic pass inspects all available text for five focus novels and seven additional works; full Eulalia! is still absent and Salamandastron has a known source gap.** Use the evidence ledgers before describing an observation as canonical.

The research's Section 5 contains `PROPOSED` applications, not new user decisions. Its Section 6 identifies adaptation risks and Section 7 defines the evidence handoff. Read those sections when planning care, institutional routines, history, character writing or related assets. Existing DEC records, mechanical owners and content boundaries remain binding. The reference table in §3.2 is a set of useful emphases, not an exclusive division of domestic and military life between books.

### 3.4 Lord Brocktree findings for shared creative context

The observations below are `SOURCE_SUPPORTED` within EV-LB02 / SRC-R10; the implications are `PROPOSED` interpretations constrained by adopted DEC records. Passage IDs resolve in [the dedicated study](lord_brocktree_analysis.md#3-evidence-index). They do not approve new mechanics or select scenarios.

| Record | Bounded source finding | Consequence for planning |
|---|---|---|
| LORE-R10 | Salamandastron combines domestic care, education, food-growing places, hospitality and defense. LB-P01–04, LB-P40 | Give every settlement form an inhabited social identity; preserve distinctions between Abbey, fortress and civic refuge |
| LORE-R11 | Hosts and allies have distinct local obligations, and some return to their own homes after victory. LB-P08–09, LB-P15, LB-P24, LB-P29 | Do not equate hospitality with submission or assume every successful community absorbs its neighbors |
| LORE-R12 | Elders differ in capability; practical assistance and distributed knowledge enable survival. LB-P03–04, LB-P11, LB-P16–17 | Apply DEC-032 through individual capability and care contracts; no universal elder decline or wisdom multiplier |
| LORE-R13 | Food, family objects, shared songs and remembrance connect ordinary life with major events. LB-P18–19, LB-P23, LB-P40 | Author participants and context before extra effects; feasts do not automatically erase grief |
| LORE-R14 | Explained spectacles coexist with consequential visions. LB-P30–32 | DEC-030 is an explicit adaptation; do not claim universal source skepticism or quietly settle supernatural truth in hidden data |
| LORE-R15 | Source ideals coexist with moralized species language, coercion and severe enemy treatment. LB-P17, LB-P21–22, LB-P28, LB-P36 | Apply DEC-005/027 to sympathetic and hostile characters alike; acknowledge departures rather than sanitizing claims about the books |
| LORE-R16 | Root-built homes and cave refuges have specific uses; tide, air, body width and uncertain routes matter underground. LB-P07, LB-P24–25 | Use qualitative references for inhabited burrows; exact terrain topology, dimensions, costs and navigation require approved engineering |

For Rowan's Refuge, this reading most strongly motivates resolving what the displaced founders retained and how their existing hall and supplies were provided. It supplies no cause of displacement, named homeland, trauma history or hidden personality for Rowan. For a Lord Brocktree scenario, consult the study's ending corrections and DEC-025 before importing canonical outcomes.

### 3.5 Expanded series findings and contradictions

The observations are `SOURCE_SUPPORTED` within the specifically inspected passages, not whole-book completeness claims. Their planning implications are `PROPOSED`, constrained by existing decisions. Read [the comparative study](redwall-series/README.md) for 96 passage records, measured coverage, source tensions and a static authoring handoff. Eleven individual studies include the additional titles requested by Brendan.

| Record | Bounded source finding | Consequence for planning |
|---|---|---|
| LORE-R17 | Redwall's ending changes offices, welcomes sparrows throughout the Abbey and repurposes bells as memorials. RW-P08–09 | Survival should have an inhabited aftermath; do not reduce the community to its champion |
| LORE-R18 | Mossflower joins council deliberation, root-hall shelter, landscape engineering and recovery before Abbey construction. MF-P03–09 | Explain founding through prior relationships and provision; root imagery does not supply excavation algorithms |
| LORE-R19 | The Long Patrol links failed infrastructure to historical decisions and preserves injury and reconstruction after victory. LP-P03, LP-P06–08 | Restoration and aftermath need context; no new structural or combat system is approved |
| LORE-R20 | Salamandastron distributes care across tasks and exposes a bottleneck when medical knowledge becomes unavailable. SA-P03–05 | Exact care scheduling and relief matter; fictional remedies do not become game or medical instructions |
| LORE-R21 | Romsca, peaceful water rats and other specific exceptions coexist with prejudice, harsh judgments and moralized species language. PL-P04; MX-P09; OC-P01–06; TG-P02–03 | Apply DEC-005 as an explicit adaptation; preserve individual acts without inventing moral genetics |
| LORE-R22 | Grief includes private silence, changed routines, continued humor and material remembrance. MW-P07–09; TG-P04; TR-P04; OC-P08 | Support DEC-011 without forcing one response, timetable, diagnosis or bonus |
| LORE-R23 | Recovered tapestries, discarded pearls/crowns and renamed ships carry different meanings. MX-P05; PL-P07; RT-P07; TR-P04 | Give focal objects use, custody and claims; no universal treasure morality or reward rule |
| LORE-R24 | Several endings preserve different destinations and chosen families rather than universal Abbey settlement. MF-P06; PL-P06; MX-P09; TR-P07; RT-P07 | Hospitality need not mean assimilation; exact travel/admission mechanics remain separately owned |
| LORE-R25 | Some wonder has an ordinary mechanism, while dreams and prophecy retain narrative weight. MF-P07; MX-P05, MX-P08; RT-P03–04 | DEC-030 remains a deliberate uncertain-truth choice; do not debunk every vision or add a hidden truth flag |
| LORE-R26 | Martin explicitly plans his shortened origin account, but the inspected Abbey-founding accounts remain in conflict. MW-P08; RW-P01; MF-P01, MF-P09; LP-P06 | Use SERIES-C01–02; distinguish an explained omission from an unresolved source contradiction |

This research does not supply Rowan's displacement cause, prior home, pronouns, personal trauma or the furnished hall's history. It does not commission scenes from the newly studied novels. Torture and deliberate child cruelty remain excluded from new content, including backstory while treatment scope remains open. No new numeric gameplay values or runtime state were adopted.

### 3.6 Reviewed visual and game-concept references

Brendan supplied 28 PNG screenshots in `ImageReference/` and explicitly requested individual review, direct use as model references, and particular attention to tunneling, swimming and climbing. [SET-ART-PACKAGE-001](art-reference/README.md) records all 28 inspections, 62 named viewing windows, direct model-reference assignments and a traversal design review. IMG-02/28 repeat the same specialist slide; the originals remain separately indexed. Source creators, original presentation URL and illustration editions are unidentified.

Use [the individual reviews](art-reference/screenshot_review.md) and [direct modeling guide](art-reference/model_reference_guide.md) while building assets. These images are now concrete visual references under DEC-018/019; keep their species silhouettes, practical clothing, material distinctions and movement poses through the stated adaptations. Hidden anatomy, rear views, exact relative dimensions and rig construction still need authored sheets. The reference does not replace existing geometry, scale, animation or Windows qualification contracts.

The slides also contain game-design proposals that are not novel evidence or blanket gameplay adoption. [The movement review](art-reference/traversal_design_review.md) distinguishes excavation from tunnel travel and sapping; wading from swimming/diving; and ladders from trunk/branch movement. DEC-029/031's interoperable multi-level construction remains required. DEC-035 now adopts ordinary connected swimming/diving and climbing/canopy direction through [SET-MOVE-001](movement_direction_amendment.md). Exact production profiles, hazards and tactical effects remain separately specified engineering work. The review explicitly flags the current single-floor memory derivation, ground-only routes and absent traversal clips.

The package records source contradictions rather than importing them: IMG-15's five pearls conflicts with six in the supplied Pearls of Lutra text; IMG-04's waterfowl diet conflicts with DEC-006; era-spanning faction tables and launch/DLC labels do not set our campaigns or release plan. All original screenshots remain in their supplied folder; research docs carry portable source paths and digests.

## 4. Existing game foundation

All records here are `PROJECT_BASELINE`. These are game facts, not assertions of literary canon.

| Record | Current fact | Owner / creative consequence |
|---|---|---|
| LORE-P01 | Release 1 is one standalone settlement with survival, care, ecology, production and interior management | GDD §§1–3; stories must emerge from these supported activities |
| LORE-P02 | The long-term concept includes tactical battles and a campaign | Concept §The Three Layers; future context does not create release 1 combat |
| LORE-P03 | Start: 12 adults, comprising 6 mice, 2 moles, 2 otters, 2 squirrels | GDD §5.1; no child, army, or second settlement in the initial simulation |
| LORE-P04 | Resident ID 1 is Warden Rowan; UI default settlement name is Rowan's Refuge | GDD §5.1 and UI-SET-103; Rowan's species assignment, pronouns, age, family and origin are not explicitly established by these facts |
| LORE-P05 | The refuge already has a completed furnished hall, well, stockpiles and workbench | GDD §5.1; the first playable moment is not arrival on empty ground |
| LORE-P06 | The standard map is a 256 m square authored estuary with river, lake and coast | GDD §5.1; this geometry is not a sourced map of Redwall Abbey |
| LORE-P07 | Abbey, Holt and Fortress are selectable visual kits with equal semantic geometry, capacities and costs | GDD §§4.2, 5.1; a style choice does not secretly select a faction or difficulty |
| LORE-P08 | The global 16-species resident catalog is retained; normal arrivals use a scenario roster and exceptions require explicit authored offers | GDD §5.11; SET-AMEND-001 §5; adopted DEC-005 |
| LORE-P09 | Land-animal hunting is retired; edible aquatic stocks are an explicit nonsapient whitelist; residents cannot be food | GDD §5.5; SET-AMEND-001; adopted DEC-006 |
| LORE-P10 | Resident identity persists even before notable naming; named residents receive no invulnerability | GDD §5.3; a name is recognition, not promotion into a superior class of person |
| LORE-P11 | Adult immigration supplies population growth; childhood, births and age-related death are outside release 1 | GDD §1; absence of child simulation does not establish a childless fictional world |
| LORE-P12 | Skills and roles are distinct from species; work has no hidden species productivity multiplier | GDD §§4.1, 5.2–5.3; cultural flavor must not invent job locks or bonuses |
| LORE-P13 | Feasts consume real portions and have exact attendance, staffing, reserve and effect rules | GDD §5.7; food descriptions cannot stack additional effects |
| LORE-P14 | Four 12-day seasons form a 48-day game year; play begins in spring at 06:00 | GDD §5.1; this is simulation time, not a claim about book chronology |
| LORE-P15 | The Hearth Charter is the settlement completion objective, with continued play afterward | GDD §5.11; no granting sovereign, abbey hierarchy or magical authority is specified |
| LORE-P16 | Existing runtime uses ground navigation; required settlement design now includes connected movement under DEC-035 | SET-MOVE-001 supersedes the ground-only release exclusion; anatomy alone still grants no flight or route bypass |
| LORE-P17 | The mouse prototype is 1.0 m high at gameplay scale; Godot and Blender conventions are fixed | Crowd architecture §9.1; do not rescale the world to biological mouse dimensions |

## 5. Creative pillars and scene tests

Status: `PROPOSED` synthesis grounded in LORE-R01–R09, LORE-P01–P17 and the compatible legacy material. These guide draft review while the interview establishes final preferences.

| Record | Pillar | Show it concretely | Reject this interpretation |
|---|---|---|---|
| LORE-T01 | Home is the accumulated work of a community | Repaired roof timbers, reachable bowls, a tended hearth, stores filled by known workers | A decorative abbey facade attached to an otherwise generic resource factory |
| LORE-T02 | Food carries identity and care | Distinct bread, root dishes, fruit, fish and preserved stores; serving and preparation remain legible | Identical glowing food cubes or a feast that visibly creates supplies |
| LORE-T03 | Woodland life mixes comfort with consequence | Warm interiors beside cold weather; a rescued resident recovering; an empty bed after loss | Relentless bleakness, or suffering treated as a joke |
| LORE-T04 | Competence can be heroic | A keeper plans fuel, a cook feeds a difficult winter, a friend completes rescue | Only armed characters receive distinctive portraits, names or narrative importance |
| LORE-T05 | The world extends beyond the camera | Travel-worn belongings and carefully attributed recollections | Claiming a functioning campaign, trade route or allied army where none exists |
| LORE-T06 | Personalities exceed species stereotypes | A patient otter cook, an anxious hare craftsperson, a proud mouse keeper | Species determining every voice, aptitude, moral choice and social status |
| LORE-T07 | Memory accumulates honestly | Chronicle entries refer to actual arrivals, rescues, deaths and milestones | Invented accomplishments or friendships presented as recorded simulation history |
| LORE-T08 | Wonder belongs alongside useful detail | A meaningful old carving or a remembered story, once approved | Decorative mystery objects promising rewards or powers without a specification |

### 5.1 Reference scene — first evening

`PROPOSED`, original project prose, not an excerpt: A resident returns a tool to the workbench as dusk reaches the hall. Bowls are laid beside the hearth. Rowan reviews tomorrow's supplies while others settle into the room they share. The sense of accomplishment is modest: everyone has somewhere to sleep, and there is work worth doing in the morning.

This is art and narrative direction, not an opening cutscene specification. No tool-return action, autonomous record-reading animation, extra dialogue system or scripted dusk event is added by this example.

### 5.2 Reference scene — winter strain

`PROPOSED`: The pantry shelves are thinning. Wet tracks lead from the door toward the hearth. A meal is still served; the interface explains precisely how little reserve remains. The scene conveys concern through the state the player can inspect, without inventing a catastrophe or blaming the player in dialogue.

## 6. Woodland-colony imports and exclusions

These records preserve useful prior thinking without importing the old game's separate setting wholesale.

| Record | Legacy idea | Disposition in Redwall-rts |
|---|---|---|
| LORE-L01 | Warm, tactile, pastoral life centered on food, wood, moss and stone | `LEGACY_CANDIDATE`; compatible with §5 and the current player fantasy |
| LORE-L02 | Home and people matter more than prestige | `LEGACY_CANDIDATE`; strong candidate for community values, DEC-008 |
| LORE-L03 | One growing abbey complex rather than disconnected facilities | `LEGACY_CANDIDATE`; cannot replace the current exterior/interior building system; DEC-010 |
| LORE-L04 | Practical mouse Abbot and Council of Elders; no confirmed religion | `LEGACY_CANDIDATE`; does not rename Rowan or settle Redwall theology; DEC-008/009 |
| LORE-L05 | Serious antagonists whose danger is never defused by jokes | `LEGACY_CANDIDATE`; potentially too absolute for the desired Redwall tonal range; DEC-012 |
| LORE-L06 | Raiding begins in hardship, becomes custom, then supports one ruler's conquest | `LEGACY_CANDIDATE`; optional future faction history, not a universal explanation for Redwall antagonists; DEC-013 |
| LORE-L07 | Distant harsh homeland; current rat warlord establishes an unusual permanent camp | `LEGACY_CANDIDATE`; no current location, antagonist, camp, or recurring raid is established; DEC-013 |
| LORE-L08 | Warm nature names for woodlanders and harsher names for raiders | `LEGACY_CANDIDATE`; useful style option but not a moral classifier; DEC-016 |
| LORE-L09 | Beaver builder with species construction bonus | Not adopted; beaver absent from release catalog and hidden productivity bonuses conflict with LORE-P12 |
| LORE-L10 | Original-only proper names and exclusion of Redwall names | `SUPERSEDED` for this project by SRC-U01 |
| LORE-L11 | Fernwhistle, Brambeck, Hollowmere, Brackenhall, Thistledown, Millstone, Reedwhisker, Gnashfang, Cragmaw, Skarrow | Illustrative legacy candidates only; none is a current character, place or final name |
| LORE-L12 | Recurring raids with no inciting incident | `LEGACY_CANDIDATE`; do not contradict a subsequently chosen founding event or install release 1 raids |

## 7. Place, era, and geography

### 7.1 Current truth and unresolved placement

`PROJECT_BASELINE`: Rowan's Refuge occupies the game estuary preset. The concept names Mossflower and Salamandastron as wider-world references. The current documents do not specify the refuge's distance or direction from either place, its era relative to the novels, or a relationship to Redwall Abbey. This is the existing baseline scenario, not the identity of every future playthrough.

`USER_CONFIRMED`: DEC-001 establishes all three setting types as player options; DEC-002 establishes multiple starting premises; DEC-024 establishes whole-series reference scope. The earlier suggestion to select one permanent setting is superseded. DEC-003/004 now resolve protagonist, place and time **per scenario**; DEC-028 confirms all these option families belong in the first playable release.

### 7.2 Playable geography reference

`PROJECT_BASELINE`, a coarse index of the exact masks in GDD §5.1. Each cell covers 16×16 exterior tiles; each exterior tile is 2 m. North is decreasing Z. Exact GDD masks override this overview.

```text
         X=0  16  32  48  64  80  96 112
Z=  0     C   C   C   C   C   C   C   C
   16     F   F   F   .   R   F   F   F
   32     F   F   F   .   R   F   F   F
   48     F   F   I   A   R   F   L   F
   64     F   F   S   H   R   F   L   F
   80     F   F   F   .   R   F   F   F
   96     F   F   F   .   R   F   F   F
  112     .   .   .   .   E   .   .   .
C coast; R river; L lake; F forest; A arable;
H hall; I iron; S stone; E arrival/departure exit.
```

This is a gameplay map, not a geographic reconstruction of Mossflower. Do not label the coast with a canonical sea, the river with a canonical river, or the exit with a named road until DEC-004 is resolved.

### 7.3 Geography content rules

| ID | EARS requirement |
|---|---|
| REQ-LORE-001 | When a brief names a canonical place, the author shall state whether it is visible, playable, remembered, or merely referenced, and attach a source-supported location claim. |
| REQ-LORE-002 | If an exact distance, date or travel time is not sourced or explicitly chosen for the game, then the author shall omit the quantity and record the relevant open decision. |
| REQ-LORE-003 | When an illustration depicts the current playable settlement, the asset brief shall preserve the GDD's navigable geometry and distinguish distant backdrop scenery from reachable space. |

### 7.4 Scenario variety — confirmed product direction

| Record | Decision | Status / evidence |
|---|---|---|
| LORE-U01 | Offer all three setting types: original community in Redwall's world, Redwall Abbey, and a particular novel/era | `USER_CONFIRMED`, SRC-U02 / DEC-001 |
| LORE-U02 | Offer varied starting premises, including a new refuge, a restoration and an established community | `USER_CONFIRMED`, SRC-U02 / DEC-002 |
| LORE-U03 | Draw creative context from across the whole Redwall series | `USER_CONFIRMED`, SRC-U02 / DEC-024 |
| LORE-U04 | Build all confirmed setting types and starting-premise families for the first playable release | `USER_CONFIRMED`, SRC-U03 / DEC-028 |

The two selections answer different questions: **setting type** determines where the story sits; **starting premise** determines what the player inherits and is trying to accomplish. An Abbey scenario could itself be tied to a novel, so setting-type labels are player-facing entry categories, not mutually exclusive claims about the world. A named scenario can carry more than one category without becoming two separate saved worlds.

`PROPOSED` authoring interpretation: build named, validated scenarios from these choices. Do not assume every possible combination is coherent or commissioned. In particular, a ruined abbey, a newly founded community and an established abbey require different authored context; changing a menu label on the current map would not deliver the requested variety.

| Setting type | New refuge premise | Restoration premise | Established-community premise |
|---|---|---|---|
| Original community | Current refuge start is a candidate foundation; exact founding story still needed | Original damaged site and damage history must be authored | Existing population, supplies and community history must be authored |
| Redwall Abbey | Requires a verified founding-era premise or an explicitly chosen adaptation | Requires a verified or explicitly invented restoration episode | Requires chosen era, cast and an appropriate abbey layout |
| Novel / era scenario | Available only when the selected story context supports it or the departure is declared | Available only when the selected story context supports it or the departure is declared | Available only when the selected story context supports it or the departure is declared |

This matrix is a content feasibility map, not nine finished scenarios. All its setting types and premise families are now first-release requirements under DEC-028. The named scenario list and valid combinations still need authoring; no category may be dismissed as future-only. The current GDD's single initialization contract is an identified specification gap against this confirmed scope, not permission to reduce the release.

### 7.5 Scenario context record

`PROPOSED` planning contract: author one record per concrete scenario. The fields below are document metadata; they do not allocate per-resident components, invent enum IDs, or implement a menu.

| Field | Required content before that scenario is implementation-ready |
|---|---|
| `scenario_key` | Stable unique lowercase ASCII key using letters, digits and underscores |
| `setting_types` | Nonempty subset of `ORIGINAL_COMMUNITY`, `REDWALL_ABBEY`, `NOVEL_ERA`; multiple labels allowed |
| `starting_premise` | One of `NEW_REFUGE`, `RESTORATION`, `ESTABLISHED_COMMUNITY` |
| `source_anchors` | Identified books and verified passages or official evidence for relevant facts; no invented page numbers |
| `era_anchor` | Identified story period and already-occurred events, or an explicitly approved original period |
| `continuity_policy` | Under adopted DEC-025, declare verified anchors, protected outcomes, changeable outcomes and deliberate departures using §7.6; broad flexibility is not an empty waiver |
| `location` | Site, regional relation and map specification; distinguish canon from invented geography |
| `opening_context` | Why these residents are here, who supplied the site, what occurred before play and why responsibility begins now |
| `player_role_and_cast` | Scenario-specific player role, represented person/institution, title, basis of authority, leader-loss continuity, relevant people and sources; DEC-008 is confirmed |
| `available_building_styles` | Nonempty explicit style list, default choice, compatible building definitions, scenario/map constraints and selector owner; include earth-built coverage in the first-release matrix under DEC-010 |
| `wonder_policy` | Apply rare/meaningful direction; declare whether any authored event exists, its content-contract owner and DEC-030 dependency. No event frequency inferred from theme |
| `initialization_owner` | Concrete owning spec for population, species, identities, skills, inventory, buildings, damage, ecology and event schedule |
| `objectives_owner` | Concrete owning spec for objectives and completion; do not assume every story uses the Hearth Charter |
| `variation` | Exact choices players may change and which facts stay fixed; not an unrestricted cross-product |
| `release_assignment` | Explicit first-release assignment or later release decision; unresolved means not scheduled |
| `open_decisions` | Specific unresolved dependencies; must be empty for final scenario implementation handoff |

An incomplete record can be a research draft; it cannot stand in for a finished scenario specification. Rowan's existing start has many initialization details but still lacks a complete historical and cultural context.

### 7.6 Continuity and shared-system boundaries

`USER_CONFIRMED`, DEC-025 / SRC-U10: “bits of all three”. `LORE-U20`: Use selective fidelity and freedom. Some facts or major outcomes can be preserved; player actions can produce alternate outcomes; original scenarios or declared departures can reinterpret places, histories and relationships. These permissions apply through each scenario's explicit boundary record, not a blanket license to change every fact. Different aspects of one scenario may use different treatments. No three-mode menu or additional scenario count is implied.

Each scenario still needs coherent era, cast and geography. Source-backed fact, interpretation and game invention remain separate. Whole-series influence alone does not place characters from different eras together. A deliberate cross-era scenario would need its own declared cast/timeline departure; do not insert one simply because canon flexibility exists.

The following is `[NEW authoring metadata]`, not a runtime schema or a substitute for verified source passages:

| Boundary field | Required content |
|---|---|
| `verified_anchors` | Each source-backed starting fact with its source ID and the limited claim verified; use an explicit empty list for a wholly original fact set |
| `protected_outcomes` | Each outcome the scenario intends to preserve, why it is protected and its exact objective/event owner; empty means no authored future outcome is protected |
| `changeable_outcomes` | Each authored outcome players may change, the governing mechanic/objective and the extent of that freedom; do not promise simulated choices for unwritten systems |
| `declared_departures` | Each changed place, date, relationship or character fact, the replacement and affected scenario records; mark project-authored rather than claiming source support |
| `player_disclosure` | Concrete scenario-description text communicating the continuity premise and any consequential agency restrictions before starting |
| `contradiction_review` | Check that no single fact/outcome is simultaneously protected and freely changeable, and that cast/location/event records agree with the declared timeline |

Preserving an outcome must be implemented through clear scenario rules and objectives. Do not secretly resurrect a dead person, confiscate earned resources or force a loss to restore book history. A declared fixed ending must not be described as an unrestricted alternate-outcome scenario. Existing global gameplay contracts continue to govern unless the scenario's mechanical amendments explicitly revise them.


| ID | EARS requirement |
|---|---|
| REQ-LORE-011 | When an author prepares a concrete scenario brief, the author shall identify its setting types, starting premise, source anchors and individual unresolved decisions using Section 7.5. |
| REQ-LORE-012 | If a scenario changes the current map, initial population, inventory, building condition, events or objectives, then the implementation plan shall identify the precise owning specification changes before describing the scenario as playable. |
| REQ-LORE-013 | When a scenario includes canonical characters or events, the author shall verify their relationship to its chosen era and record deliberate departures separately from source-supported claims. |
| REQ-LORE-014 | When additional scenarios are specified, the systems plan shall express their initial data and supported rules through the shared data-oriented simulation and versioned content contracts; lore variety alone shall not introduce a separate object hierarchy for each scenario. |

Scenario save identity, catalog compatibility, deterministic initialization and scenario-selection UI now require a dedicated implementation contract for the confirmed first-release variety. This bible identifies that required work; it does not claim their binary fields, UI control IDs or save-version changes have already been specified.

### 7.7 First-release coverage acceptance

`USER_CONFIRMED` scope, with the following authored acceptance interpretation: the release must expose working choices covering all three setting types and all three starting-premise families. Each available scenario needs its own complete initialization, meaningful opening context, objectives, UI description, and validation. A locked menu entry, renamed refuge preset, or future-content promise does not satisfy a missing option.

The final scenario list must enumerate the supported combinations. The user's answer does not name every novel to adapt or establish that all possible combinations share identical canon compatibility. First-release coverage is settled; choosing the concrete content within it remains necessary work. Existing settlement-only scope is not automatically expanded to tactical battles or a campaign by this answer about scenario variety.

## 8. Peoples, sapience, and belonging

### 8.1 Current roster

Status: `PROJECT_BASELINE`. Table order follows the GDD's species list, not an invented numeric ID allocation. Every row is a sapient species available to validated scenario definitions; each scenario restricts ordinary candidates through its admission profile.

| Species | Size class | Initial adults | Creative caution |
|---|---|---:|---|
| Mouse | SMALL | 6 | Do not assume every mouse is a leader or Rowan's biography is settled |
| Shrew | SMALL | 0 | A cultural reference does not automatically make every shrew a member of one tribe |
| Mole | SMALL | 2 | Digging imagery does not create underground navigation |
| Rat | SMALL | 0 | Refuge ordinary pool excludes rats; the authored petition provides an individual exception |
| Squirrel | SMALL | 2 | Climbing imagery does not create elevated work paths |
| Sparrow | SMALL | 0 | Ground navigation remains binding |
| Otter | MEDIUM | 2 | Water-associated identity does not grant a swimming path bypass |
| Hare | MEDIUM | 0 | Not every hare is automatically a Long Patrol soldier |
| Ferret | MEDIUM | 0 | Outside the refuge normal pool; other scenarios require explicit profiles |
| Weasel | MEDIUM | 0 | Do not invent theft or betrayal probabilities |
| Hedgehog | MEDIUM | 0 | Quills are not unlisted defensive stats |
| Kestrel | MEDIUM | 0 | Ground navigation and shared service access must remain visually coherent |
| Badger | LARGE | 0 | No rage, guardian office or hereditary rulership is installed by species |
| Fox | LARGE | 0 | No automatic officer role or poison skill |
| Wildcat | LARGE | 0 | No automatic tyranny or hereditary nobility |
| Wolverine | LARGE | 0 | No automatic resident predation mechanic |

The early concept also names stoats; the release 1 resident catalog does not. Do not quietly add stoats, beavers or giant residents through lore generation.

### 8.2 Three separate questions

| Question | Current mechanical answer | Required creative decision |
|---|---|---|
| Who is a person? | Residents are sapient; edible aquatic keys are nonsapient; no mammal/bird food stocks | DEC-006 adopted; follow SET-AMEND-001 |
| Who may enter this settlement? | Scenario normal pool plus authored individual petitions | DEC-005 adopted; exact current-refuge profile in SET-AMEND-001 |
| Who is trusted? | Relationships and mood follow their GDD rules; no species prejudice system exists | No hidden species virtue/betrayal; additional trust mechanics require their own spec |

`USER_CONFIRMED` policy application: Refer neutrally to a resident by identity and behavior. Do not add narrator claims that a species is incapable of kindness, or that old prejudices have already disappeared. Neither conclusion follows from the current simulation.

### 8.3 Animal embodiment

`USER_CONFIRMED`, DEC-019 / SRC-U10: “Recognizable animal anatomy.” `LORE-U18`: Preserve species identity through characteristic face, limbs, ears, tail and body form while applying the approved expressive art direction. The answer does not choose real-world relative sizes or adopt a complete size-normalization scheme. Existing gameplay scales remain the numeric baseline until species reference sheets and shared-space dimensions are specified. Anatomy alone grants no new flight, swimming, climbing or innate tunneling mechanics.


`PROPOSED`: Faces, posture, tails, ears, paws, beaks and clothing fit must remain recognizably species-specific. Emotional expression should work at the game's camera distance. Shared furniture can use presentation adaptations that preserve the same service slot and access point; special animation work still requires an asset brief. Do not solve bird or badger proportions by silently changing tile occupancy or importing a new skeleton per resident.

### 8.4 Adopted rule — community identity with individual exceptions

`USER_CONFIRMED`, Brendan: “Adopt both”; DEC-005. These are adopted game adaptations, not a claim that the novels follow a uniform admission policy. The publisher's account of Veil being raised at Redwall and later banished is a useful example of admission, conduct and loyalty being distinct narrative questions. [SRC-R04, Outcast of Redwall entry](https://www.penguinrandomhouse.com/series/DUI/redwall/)

| Record | Recommended rule | Purpose / implementation consequence |
|---|---|---|
| LORE-A01 | Each scenario defines its normal resident and immigration roster from the settlement's era and culture | Preserve distinct communities; GDD v2 now uses scenario-defined admission under SET-AMEND-001 |
| LORE-A02 | A species outside the normal roster enters through an explicitly authored character or encounter with player choice | Make exceptions meaningful; ordinary immigration shall not silently draw exceptions. Specific event triggers, cast and quantities belong to the scenario spec; no invented rarity percentage here |
| LORE-A03 | Do not assign inevitable betrayal or innate virtue as a hidden species mechanic | Individual conduct, affiliation and authored history can matter; any additional simulation needs an explicit rule |
| LORE-A04 | Distinguish aid to a stranger, permission to stay and durable trust in the fiction | An unarmed rat can be heard and helped without making automatic permanent admission the only response. New aid/probation mechanics are not installed by this policy |

An Abbey scenario, otter community and military mountain community should not all feel like the same randomly mixed population. Their exact normal rosters must be verified against the chosen context; these illustrative community types do not establish additional commissioned scenarios. A more permissive original-community scenario could exist if deliberately authored, rather than erasing the baseline identity of every community.

This adopted policy changes the social possibilities of the game deliberately; it is not evidence that all source characters or institutions would make identical decisions. Authored exceptions should have a reason to be present and a role beyond demonstrating the rule.

## 9. Community, leadership, and ordinary life

### 9.1 Roles and authority

`PROJECT_BASELINE`: The player controls policies and priorities. Rowan holds the Warden designation; a successor can be appointed without a stat change if the Warden dies or leaves. There is no current election, succession crisis, council voting, class hierarchy, tithe or command-radius rule.

`USER_CONFIRMED`, DEC-008 / SRC-U04: “Role changes by scenario.” Each scenario supplies its own player role. Warden, Abbot/Abbess, council and community stewardship remain possible scenario roles rather than one required global identity. Specific office, person, legitimacy and resident resistance are still scenario decisions under DEC-003; this answer adds no elections, disobedience or leader-death defeat condition.

`LORE-U05`: Scenario role descriptions must agree across opening text, objectives, notices and leader UI. Merely changing a title cannot imply new authority mechanics. Preserve the existing refuge succession until its owning rules are explicitly revised.

`PROPOSED`: Treat cook, keeper, healer, fisher and craftsperson as dignified kinds of contribution. A resident can be tired, proud, difficult, generous or mistaken without becoming comic disposable labor. Responsibility is visible in what someone cares for and whom they help.

### 9.2 Daily culture candidates

These are `PROPOSED` descriptive customs, each limited to an existing activity. They create no scheduled event, state field, bonus or forced line of dialogue.

| Custom ID | Candidate custom | Existing anchor | Decision |
|---|---|---|---|
| CULT-001 | A first shared meal marks a newcomer's welcome | Arrival and shared dining | DEC-014; do not claim every newcomer has already attended |
| CULT-002 | A keeper records the season's most consequential events | Chronicle records | DEC-014; add no record of an event that did not occur |
| CULT-003 | Repaired objects remain in use and carry signs of care | Building condition, tools and clothing presentation | DEC-010/020; wear does not add durability values |
| CULT-004 | An orchard is spoken of as a gift to later seasons | Existing orchard maturity | DEC-014; no hereditary ownership or child system |
| CULT-005 | A feast acknowledges the labor that supplied it | Existing feast service | DEC-007/014; no extra feast theme or duplicate effect |
| CULT-006 | The community remembers those who died | Existing death and chronicle behavior | DEC-011/014; specific burial beliefs remain unresolved |

### 9.3 Disagreement and social depth

`PROPOSED`: Useful disputes concern risk, fairness, waste, rest, hospitality or use of limited stores. These make the community particular without requiring every resident to agree. Release 1 copy may describe a real conflict event; it may not fabricate motives or an entire political simulation from the generic conflict memory.

`OPEN`: Whether there are formal customs concerning outsiders, private possessions, marriages, family obligations or exile belongs to DEC-008/015 beyond the adopted admission policy. Adult-only simulation must not be rewritten as a claim that these institutions do not exist in the world.

### 9.4 Confirmed everyday family life

`USER_CONFIRMED`, DEC-015 / SRC-U05: “Visible everyday community life.” `LORE-U11`: Families, children and elders must be recognizable participants in inhabited spaces. Their existence cannot be satisfied only by distant relatives in lore text. This is required first-release presentation/content under the existing project scope; it does not settle a generational simulation.

Candidate visible routines `[PROPOSED]`: sharing meals, an elder recounting a story, children playing near a common space, and adults caring for dependents. These are content directions, not scheduled jobs, authored dialogue already present, or automatic relationship assignments. Do not show an adult merely scaled down and count child animation/rig work as complete.

| Required contract | Current decision boundary |
|---|---|
| Identity and relationships | Specify household/kinship authoring and persistence; never infer family from species, proximity or matching surname |
| Residents versus presentation figures | DEC-032 confirms real dependents; count their food, housing, care and population honestly, with exact values supplied by the family amendment |
| Routines and access | Bind visible activities to legal locations and movement; presentation cannot block doors or silently create path exemptions |
| Age and generation | Visible age diversity and fixed first-release life stages are adopted; age-band initialization needs a contract. Births, aging, death by age and fertility require later specification |
| Safety and loss | DEC-033 adopts serious survival vulnerability, warnings, rescue opportunities and non-graphic presentation; exact rescue/hazard contracts remain required |
| Performance | Preserve the existing caps and crowd approach until a measured, versioned change is specified; visible families do not create an unbudgeted extra population of Node-based actors |

The current adult-only simulation remains the numeric baseline during specification work. It is an explicit gap against this requirement, not a design permission to remove children or elders from the promised visible community.

### 9.5 Adopted dependent-resident simulation model

`USER_CONFIRMED`, DEC-032 / SRC-U07: “That works for me.” `LORE-U14`: Children are real dependent residents with food, bed, warmth, health, social and care needs. Adults share caregiving with community fallback; elders retain individual skills and roles. Children play, learn and share meals without ordinary labor, hazardous expeditions or excavation assignments. All simulated children, adults and elders count toward the existing 256 living cap and 512 resident slots; no extra unbudgeted actor population is implied.

The initial release uses fixed life stages and households introduced through authored scenario starts and family-aware immigration. Births, aging, adulthood transitions and death by age are separate later specification work. Learning does not promise an adulthood transition during the current scenario; scenario descriptions must make the fixed-stage scope clear. Household/care relationships must be authored, never inferred from species, surname, gender or proximity.

This is adopted design scope. Exact child nutrition, care work, routine timing, household capacities and packed schema remain required engineering work. `USER_CONFIRMED`, DEC-033 / SRC-U08: children can become ill, be injured and die through survival hazards; clear warnings, defined care/rescue opportunities and non-graphic presentation are required. This specifies policy, not exact hazard rates or adult-equivalent need coefficients. The current refugee population and individual rat petition retain their specified data until a complete, versioned family amendment replaces the relevant initialization/admission contracts.

| Required owning revision | Completion evidence before family implementation |
|---|---|
| GDD and balance | Exact dependent needs/consumption, bed validity, care jobs and fallback, schedules, activity restrictions and household admission; retain explicit provenance for changed quantities |
| Architecture and saves | Packed household/life-stage/care fields, finite capacities and byte totals, reference validation, stable identity, atomic admission and caregiver-loss handling |
| UI and content | Household and care visibility, total population/food/housing forecasts including dependents, unmet-care causes and fixed-life-stage scope text |
| Assets and routines | Readable child/elder silhouettes and approved animations at the RTS camera; safe legal activity locations using the shared crowd system |
| Validation | Household acceptance at bed/food/cap boundaries, care reassignment when a guardian leaves or dies, no child productive/hazard jobs, saved relationships and deterministic routines; vulnerability cases follow DEC-033 |

These are exact deliverables required for the later executable rules amendment, not claims that family mechanics have been built or tested. DEC-033 now settles the vulnerability policy. Complete exact child needs, warning thresholds, hazard exposure, rescue eligibility and treatment/death rules before implementation; do not substitute an arbitrary child mortality roll.

## 10. Food, ecology, and material culture

### 10.1 Culinary identity

`SOURCE_SUPPORTED`: The official cookbook supports a food-centered reading of the setting and provides examples of vegetable dishes, seafood and drinks. It does not supply this game's yields, ingredient categories or nutritional values. [SRC-R03](https://www.penguinrandomhouse.com/books/286798/the-redwall-cookbook-by-brian-jacques-illustrated-by-christopher-denise/)

`PROJECT_BASELINE`: Current food includes porridge, root stew, fish stew, bean hotpot, woodland pie, bean/root/nut roast, berry tart, orchard crumble, nut loaf and feast fish. Hearth, Harvest and Orchard feasts have fixed catalog definitions. The game has mead; no intoxication subsystem is specified. GDD §5.7 owns all ingredients, units, quality and effects.

`USER_CONFIRMED`: DEC-006 removes land-animal hunting and the hide supply chain. [setting_rules_amendment.md](setting_rules_amendment.md) provides exact retirements, nut_roast and Orchard feast changes. DEC-007 now confirms the layered feast meanings below; exact culinary traditions, book-specific dishes and beverage presentation remain to author.

`USER_CONFIRMED`, DEC-007 / SRC-U11: “All of the above.” `LORE-U22`: Meals and feasts express hospitality, gratitude, seasonal tradition, survival, shared achievement, community identity, alliances and obligations. Give an occasion a concrete context; several meanings may coexist without forcing every meal to represent all of them.

| Social meaning | Authored expression | Truth boundary |
|---|---|---|
| Hospitality and gratitude | Welcome an actual newcomer or acknowledge the people who supplied and prepared the meal | Do not claim a guest attended without supported attendance or an authored scene |
| Seasons and survival | Mark the turn of a season or recognize a hardship the community actually endured | No claim of a safe winter when food/fuel forecasts disagree |
| Shared achievement | Recall a completed communal undertaking or earned milestone | No duplicate reward or automatic extra feast buff |
| Identity and continuity | Use a community's approved foods, table customs, stories and decorations | Specific customs remain DEC-014; no invented book attribution |
| Alliances and obligations | An authored gathering can carry social significance beyond eating | No implicit diplomacy, tribute, relationship contract or visiting delegation in the current settlement runtime |

These meanings enrich current Hearth, Harvest and Orchard occasions when applicable. They are not new recipe families or an additional parallel feast system. Any new guest/event/service behavior requires an exact owner, participants, trigger, cost, timing, UI and saved-state contract.

### 10.2 Original description examples

Status: `PROPOSED`; these are newly authored descriptions of current recipes. They are not book excerpts or additional ingredient specifications.

| Current recipe | Candidate description | Constraint |
|---|---|---|
| `root_stew` | A warming bowl of softened roots and broth. | Do not show meat in a roots-and-water recipe |
| `woodland_pie` | Mushroom and root filling beneath a browned crust. | Do not imply a meat or dairy input |
| `berry_tart` | A crisp shell filled with berries and a little honey. | Visual berry variety does not create a new inventory item |
| `nut_loaf` | A firm loaf, rich with nuts and cut into generous slices. | Slice count is decorative; portion yield remains the catalog value |
| `feast_fish` | Fish and roots prepared with herbs for the shared table. | No magical glow, extra benefit or unlisted cooking process |

### 10.3 Technology envelope

`PROPOSED` presentation envelope derived from the existing catalog: hand tools, timber joinery, masonry, weaving, milling, water collection, ovens/hearths, metalworking, simple boats, nets, wax lighting and written records. Surfaces should show the making process: tool marks, seams, woven texture, fittings and repairs.

Release 1 contains no firearm, steam engine, electrical grid, industrial assembly line, magical fabrication, livestock breeding or coin economy. This records current scope; it is not a claim that every object or economic practice is absent from all Redwall stories. Future siege machinery must come from a battle specification.

### 10.4 Adopted rule — plant staples, fish and seafood

`USER_CONFIRMED`, Brendan: “Adopt both”; DEC-006. Use grains, roots, beans, mushrooms, nuts, fruit and honey as the everyday culinary foundation, with fish and seafood as permitted food sources. Remove deer, boar and grouse hunting from the ordinary settlement economy. The official cookbook's plant dishes and seafood example support this direction; a universal dietary or sapience rule for the entire series is not established by that evidence. [SRC-R03](https://www.penguinrandomhouse.com/books/286798/the-redwall-cookbook-by-brian-jacques-illustrated-by-christopher-denise/)

| Record | Recommended rule | Consequence |
|---|---|---|
| LORE-A05 | Ordinary settlement food uses plant staples plus explicitly classified nonsapient fish/seafood; mammal and bird hunting is removed | Food remains culturally central without a grouse being ordinary meat beside a sapient sparrow resident |
| LORE-A06 | Every edible creature species must be explicitly classified before catalog approval; no person may also be a food stock | Do not assume every aquatic creature is nonsapient, and do not give one species contradictory classifications for convenience. Audit future aquatic-character concepts |
| LORE-A07 | Cultural variation changes permitted dishes, preparations and preferences within the coherent food boundary | Different settlement menus do not require different definitions of personhood |
| LORE-A08 | Use plant-based cloth, cordage, wax treatments, wood and metal for the practical equipment economy | Retire hide-dependent production or specify alternative materials explicitly; do not relabel hide as cloth while leaving its source unchanged |
| LORE-A09 | Keep wilderness risk and discovery through fishing hazards, ecology, foraging and separately specified scouting/rescue content | A lost hunter or scout story must not be mistaken for an implemented replacement subsystem; no free substitute yields or unlisted rewards |

Predation by a threatening creature in a source-linked story can remain a narrative danger if chosen under the content-boundary decisions. That is distinct from making residents' bodies a normal tradable resource. No current predator-care, captive-feeding or cannibalism mechanic is requested.

#### Reconciled mechanical implementation

The [rules amendment](setting_rules_amendment.md) and GDD/UI revision 1.1 enact the policy. Retired hunting items, recipes, buildings and active jobs are removed. The replacement roast uses beans, roots, nuts and herbs; Orchard feasts use it as their main course. Existing fishing, foraging, farms, orchards and preserves retain their rules. The amendment distinguishes inherited output/work values from new inputs and defines all resulting catalog counts, reserved schema fields and acceptance fixtures.

The current refuge admission profile uses mouse, mole, otter, squirrel, shrew, hedgehog, hare and badger as ordinary candidates, plus one authored rat petition at absolute day 10. These are NEW implementation choices under the adopted policy, not Redwall canon or a universal population for every scenario. Other launch scenarios require their own profiles.

Exact numeric changes and new content are recorded in SET-AMEND-001. Full-runtime population decisions, save transactions and long-term survival remain unverified until integrated; isolated food controls do not certify those systems.

## 11. Wonder, spirituality, and inherited memory

`SOURCE_SUPPORTED`: The teacher's guide describes Martin appearing across the series as an active figure or in visions and refers to abbey leadership in spiritual terms. That supports asking about wonder and belief; it does not define one complete religion. [SRC-R05, printed p. 4](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf)

`LEGACY_CANDIDATE`: The earlier woodland-colony deliberately left faith unconfirmed and used Abbot as a practical office. That is not sufficient grounds to declare this Redwall project wholly secular.

`USER_CONFIRMED`, DEC-009 / SRC-U04: “Rare and meaningful.” `LORE-U06`: Wonder must be exceptional and tied to a specific remembered duty, uncertainty or consequential choice. It is not routine background chatter. No numeric encounter frequency is chosen by this answer.

`USER_CONFIRMED`, DEC-030 / SRC-U06: “Truth uncertain.” `LORE-U13`: The game preserves uncertainty about the origin of visions or legendary guidance. Characters may believe, doubt or disagree; omniscient narration and UI do not confirm or debunk the supernatural explanation. Do not store a hidden authorial boolean declaring the experience genuinely supernatural or definitively ordinary. No god, creation myth, church hierarchy, resurrection, curse, spell resource or prophetic modifier is established.

An event can have an exact deterministic trigger and a persistent occurrence record without certifying its fictional cause. Separate mechanical certainty from narrative uncertainty: the player must still receive accurate information about actual resources, injuries, objectives and outcomes. A dream should not present a guaranteed prediction of hidden future state and thereby settle the intended ambiguity.

Authored event handoff requires exact trigger, eligible recipient, scene/text, once-only or repeat rule, saved completion state, existing UI delivery owner and declared consequences. A narrative-only event declares no simulation reward. If any event changes a need, objective or resource, its owning GDD/UI/save contract must define that change first. Named canonical appearances also require the selected era and verified source context. These are authoring requirements, not a new event engine.

`PROPOSED`: Shared objects may carry remembered meaning before they confer any mechanical effect. An original memorial must not be casually identified as Martin's sword or tapestry. A future riddle needs a specified answer, complete clue path and fair resolution; mystery is not permission for an undefined reward.

## 12. Danger, antagonists, and content limits

### 12.1 Release 1 danger

`PROJECT_BASELINE`: Exposure, hunger, injuries, ecological depletion and strained relationships create danger. The GDD's causes and warnings govern outcomes. There are no army raids or battle damage rules. Death can occur; names do not protect residents.

`USER_CONFIRMED`, DEC-011 / SRC-U05: “Serious consequences and grief.” `LORE-U10`: Loss must matter to those who remain. Names, causes, treatment, mourning and continued daily life carry the consequence. Existing simulation rules determine who was affected and what happened; serious tone does not require extra death rates or duplicate grief penalties.

Authored presentation guidance: death notices state the actual identity and cause; later text may recall a real loss but must not invent kinship or blame. Avoid cheerful quips over loss. Recovery can coexist with grief. Specific funeral customs, narrative durations and audiovisual treatment need their own content briefs.

`PROPOSED`: Keep bodily detail non-graphic. The user confirmed seriousness but did not repeat the offered non-graphic qualifier; the graphic-content ceiling remains open under DEC-027. No formal age rating is established.

### 12.2 Future conflict

`USER_CONFIRMED`, DEC-013 / SRC-U12: “A mix of all three to ensure variety in gameplay.” `LORE-U26`: The wider world supports distinct groups with different motives/cultures, large conquering powers and their opponents, and local/personal conflicts that can dominate other scenarios. Vary those combinations by place and story; do not make every region a copy of one empire-versus-refuge plot.

| Conflict emphasis | Distinction to author | Required gameplay follow-through when that layer is implemented |
|---|---|---|
| Local rivalry or personal conflict | Specific people, grievances, contested access or community obligations | Define the supported trigger, affected activity, available response and resolution; do not infer an active political simulation from flavor text |
| Independent organized group | Its own needs, ambitions, loyalties, culture and way of operating | Define actual objectives, resources and response rules so it behaves differently from other groups |
| Conquering power and reactions | Expansion affects several groups with their own reasons to oppose, cooperate or compete | Define regional progression, faction dependencies and available counterplay in the future campaign/battle specs |

Survival, ambition, loyalty, conquest and cruelty may occur in different combinations. Motive and behavior are authored per group/leader, not assigned by species. Understanding a motive need not make its actions harmless. Variety must eventually affect player decisions and supported behaviors, not merely naming, color or cosmetic appearance. No exact aggression probability, raid interval or diplomacy formula is originated here.

Every future group brief must specify its scenario/era, motive, objective, means, constraints, relationships, player-visible tells, supported interactions and defeat/departure/transformation conditions. Tie each behavior to its concrete owning spec. The current settlement release still has no armies, raids, tribute or diplomacy state; descriptive world context does not implement these systems.

`OPEN` scenario content work: war’s wider visual intensity, antagonist humor and redemption remain unsettled. DEC-027 now names torture and deliberate cruelty toward children as boundary subjects; apply §12.5. The legacy rat warlord, permanent camp and harsh homeland remain optional proposals, not selected facts.

No canonical villain is designated as the current antagonist. No alliance with the Long Patrol, tribute relationship, invasion schedule, prisoner system or warlord genealogy is established.

### 12.3 Content boundary register

| Subject | Existing scope | Pending direction |
|---|---|---|
| Resident death and grief | Existing rules; serious consequences and grief confirmed | DEC-014/027: specific mourning customs and presentation limits |
| Graphic injury / gore | No presentation standard chosen | DEC-011; draft scenes use non-graphic treatment |
| Children | Required visible everyday life under DEC-015; current adult-only GDD is incomplete for this direction | DEC-032 adopts dependent needs/care; exact rules remain to specify. DEC-033 confirms non-graphic survival danger; DEC-027 retains wider content boundaries |
| Captivity, enslavement, coercion | No release 1 mechanic | DEC-027: future story boundaries |
| Alcohol | Mead in current recipes | DEC-007: naming and depiction; no invented impairment |
| Horror, supernatural threat | No release 1 system | DEC-009/012: atmosphere and future use |
| Romance and family | Family life must be visible; no reproduction or romance subsystem specified | DEC-032 adopts the household model; romance and later generational mechanics remain separate |

### 12.4 Adopted child-survival and everyday-humor tone

`LORE-U15`, `USER_CONFIRMED`, DEC-033: Children face serious settlement survival consequences, including possible illness, injury and death. Present their unmet needs and danger clearly and provide explicitly specified care/rescue opportunities. Children remain excluded from hazardous work and ordinary production. Non-graphic presentation means no exposed wounds, mutilation or graphic death animation; communicate the outcome through restrained animation, truthful notices and the survivors' responses. These are presentation limits for this adopted policy, not a new combat or threat system.

`LORE-U16`, `USER_CONFIRMED`, DEC-012: Use warm everyday humor. Affectionate teasing, contrasting personalities and small domestic mishaps can make ordinary life inviting. As proposed examples, a proud cook might fuss over a lopsided loaf, or two friends disagree about a harmless household habit. These are original writing examples, not authored events or canonical claims. Avoid jokes at the expense of a starving, injured or grieving resident, or comic failure in critical alerts. Antagonist-specific humor remains to be authored under DEC-013/027; warmth does not automatically make every threat comedic.

### 12.5 Torture and deliberate cruelty toward children

`LORE-U30`: Brendan answered “torture and cruelty towards children” when asked which subjects should be excluded or kept offscreen. The subjects are `USER_CONFIRMED` boundaries; whether restrained offscreen/past references are allowed is being clarified under DEC-027. **No depiction is permitted.** Until the user answers, exclude both from new explicit content, backstory, implied threats and offscreen events as a conservative authoring guard. That broader interim guard is the agent’s interpretation, not a claim that the user already selected total exclusion.

This boundary applies to writing, events, codex entries, ambient dialogue, images, animation and sound. Do not import a source scene involving these subjects simply because a focus book is now prioritized. No torture action, reward or deliberately abusive child-targeting mechanic is authorized. Exact source analysis may note that adaptation needs a change without reproducing the excluded material in game content.

DEC-033 remains distinct: non-graphic illness, accidental injury, hunger/exposure consequences and rescue/care needs are approved survival stakes. Do not convert those stakes into deliberate punishment, targeted torment or an abuse narrative. General captivity/enslavement and other wider topics are not automatically approved or prohibited by the named subjects; their specific treatment still requires context and the final boundary decision.

## 13. Characters, names, and voice

### 13.1 Rowan's known identity in the existing refuge scenario

DEC-008 confirms the player role varies by scenario. Rowan is not the universal protagonist or an established book character. Other scenarios require their own role/cast records under DEC-003; the Warden title remains specific to the existing refuge.

| Field | Value | Status |
|---|---|---|
| Display identity | Warden Rowan | `PROJECT_BASELINE` |
| Persistent resident ID | 1 at initialization | `PROJECT_BASELINE` |
| Starting capability | KEEP level 3; other initial skills follow GDD | `PROJECT_BASELINE` |
| Settlement default | Rowan's Refuge | `PROJECT_BASELINE` |
| Species / occupation | Mouse; experienced keeper | `USER_CONFIRMED`, DEC-003 / SRC-U13 |
| Pronouns / exact age / appearance | Not fixed by this bible | `OPEN` details under DEC-003 |
| Why the refuge exists | Community rebuilding after displacement | `USER_CONFIRMED`, DEC-002 follow-through; cause/location/history remain open |
| Family, origin, faith, flaw, defining memory | Not established | `OPEN`, DEC-003/009/015 |
| Plot protection | None | `PROJECT_BASELINE` |

`LORE-U28`: Rowan is an experienced mouse keeper. Keep the Warden designation and ID 1; the approved final initialization must place Rowan within the existing six-mouse cohort, not add an extra starting adult. Experience supports the practical role and already-specified KEEP level; it grants no new stat. Compassion, dependability and difficulty delegating remain offered character possibilities, not confirmed traits, because the user’s shorter answer named only species, occupation and experience. Do not equate Rowan with the legacy mouse Abbot or a canonical character.

`LORE-U29`: The Refuge forms after displacement. Its emotional purpose is establishing a lasting home and shared care after losing or leaving a former place. The cause, route, prior homes, exact date and any involvement of volunteers remain to author. Do not manufacture a war, named perpetrator, abusive backstory or canonical disaster to explain the one-word answer. The completed hall, supplies and starting adults still need a coherent pre-play provision history; no inventory penalty or aid grant follows automatically. Other scenarios retain their approved founding-premise variety.

### 13.2 Naming contract

`PROJECT_BASELINE`: GDD §5.3 specifies fixed 32-entry given-name and surname catalogs, deterministic selection by persistent ID/world seed, and an identity suffix for duplicates. Player aliases are 2–32 characters. This draft does not invent replacement arrays or change the naming algorithm.

`USER_CONFIRMED`, DEC-016 / SRC-U11: “A mix of these blended appropriately.” `LORE-U21`: Combine personal names, woodland/nature names, descriptive and place-related names, distinct local traditions, and meaningful titles or earned nicknames. Curate the mix per community and individual; do not turn it into equal random weights or force all categories into one long name.

| Name layer | Intended use | Required boundary |
|---|---|---|
| Personal name | An everyday spoken identity, including short personal and nature-derived names | Use approved content; matching a canonical first name alone never identifies the resident as that book character |
| Descriptive/place name | A family, home, place or individual association, when authored | Do not infer kinship or birthplace from an automatically generated surname |
| Cultural variation | Coherent vocabulary and naming customs for a selected scenario/community | Culture is not a species lock; no unapproved per-species naming algorithm |
| Title | A real office or role, such as the existing Warden identity where applicable | Removal/succession/display follows actual scenario and UI rules |
| Earned nickname | An epithet with an authored history or a recorded achievement | No invented past exploit or automatic nickname-award subsystem; title/alias display must fit a defined UI contract |

The existing ordered arrays already contain real entries; they are not blank catalogs. Expanding or replacing them, adding culture-indexed selection, or dynamically granting names needs a versioned catalog/save/UI amendment. The adopted creative policy does not alter persistent IDs, deterministic selection, alias limits or notability display by itself.

### 13.3 Writing direction

`USER_CONFIRMED`, DEC-017 / SRC-U10: “Distinct voices with light dialect.” `LORE-U19`: Give people distinct rhythm, preferred vocabulary, interests and attitudes. Keep spelling readily legible; avoid long phonetic passages. Character voice can suggest culture without giving every member of a species identical speech or personality. Functional UI, quantities, causes and instructions remain plain.

The table supplies authoring guidance under that direction. Concrete dialect registers and character biographies require their own sourced or explicitly original examples; distinct voices do not automatically commission voice acting or a dialogue engine.

| Voice | Direction | Example / boundary |
|---|---|---|
| System interface | Plain and exact; existing UI language and values win | Use "No fuel available" with the actual cause; never hide it inside dialect |
| Object description | Concrete material, use and wear | "A broad worktop marked by years of cutting and kneading" only for an object with that approved history |
| Resident flavor | Distinct rhythm, interests and attitude | Do not give every mole the same personality or every hare the same joke |
| Chronicle | Record the real event before interpretation | "Rowan rescued [actual resident name]" requires a recorded rescue |
| Tutorial | Patient, practical, respectful | Explain a reachable remedy; do not shame the player |
| Celebration | Warm, communal, specific to earned progress | Do not claim winter reserves are safe when the forecast disagrees |

Brackets in the chronicle example describe a required binding to actual recorded identity, not literal shipping copy. Light dialect and the broad sound blend are confirmed; voice acting and exact audio implementation remain to specify under DEC-021. Essential information always remains readable without recognizing an accent.

## 14. Visual and asset direction

### 14.1 Approved technical boundaries

`PROJECT_BASELINE`: Detailed 3D at an RTS camera; Blender source assets; Godot gameplay scale. Crowd architecture §9 owns axes, transforms, rig limits, atlas rules and exports. UI §2 owns functional color and type tokens. This bible does not invent competing triangle budgets, dimensions or render settings.

| Inherited asset value | Exact value | Owner |
|---|---|---|
| Prototype mouse height | 1.0 m gameplay scale | Crowd §9.1 |
| Blender unit scale | Metric, 1.0 | Crowd §9.1 |
| Coordinate conversion | `(x_g,y_g,z_g)=(x_b,z_b,-y_b)` | Crowd §9.1 |
| Crowd skeleton | At most 64 bones including sockets | Crowd §9.1 |
| Initial species atlas | 2048×2048 albedo, normal and ORM per family | Crowd §9.1 |
| Fur | Silhouette and surface detail; no crowd hair strands/shell fur | Crowd §9.1 |
| Functional panel | `#1E3028`, opaque | UI §2.1 |
| Functional text | `#F5F0DF`, opaque | UI §2.1 |
| Focus / selection gold | `#E6C77A`, opaque | UI §2.1 |

### 14.2 Proposed visual vocabulary

`USER_CONFIRMED`, DEC-018 / SRC-U09: blend textured storybook realism and grounded fantasy realism. Section 14.7 defines the shared visual direction for all styles, residents and environments. The comparison remains in the decision register as history. Existing asset budgets remain unchanged.


Style availability and earth-built homes are `USER_CONFIRMED` under DEC-010. The broad art blend is confirmed under DEC-018. Culture-specific material details below remain `PROPOSED` under DEC-020 and must follow §14.7; exact relative species size remains to specify; recognizable anatomy is confirmed under DEC-019. These are draft asset directions, not verified reproductions of book illustrations.

| Domain | Candidate direction | Incompatible shortcut |
|---|---|---|
| Abbey kit | Substantial masonry, timber fittings, visibly repaired textiles, communal hall as visual center | Human religious symbols inserted without a setting decision |
| Woodland village form | Separate earth/timber/stone dwellings connected by visible paths and shared service spaces | Treating a composition choice as automatic new household or ownership mechanics |
| Earth-built homes | Inhabited rooms set into earth, an exposed entrance facade and legible interior access; burrow and hillside-home variants | A sealed decorative mound passed off as an occupied home, or unsupported tunnel/terrain behavior |
| Holt kit | Timber, reed and rope details suggesting life near water | Elevated decks that imply inaccessible gameplay floors or new water routes |
| Fortress kit | Heavy stone and timber, orderly practical storage, strong enclosing forms | Adding battle slots, arrow attacks or superior defence stats to a visual kit |
| Clothing | Layered cloth, useful belts, satchels, aprons, repair patches | Random costume clutter obscuring species silhouette or tool hand |
| Furniture | Handmade construction, stable feet, visible service access | Ornamental clutter covering doors, beds or path-critical tiles |
| Food | Recipe-appropriate forms, baskets, bowls, pottery, preserved stores | Unlisted ingredients, limitless piled food that contradicts an inventory display |
| Landscape | Distinct managed land, damp margins, woodland depth and seasonal states | Decorative harvest plants implying resources where no stock exists |
| Wear | Use concentrated at grips, hinges, thresholds and work surfaces | Uniform dirt that makes every maintained home look abandoned |

### 14.3 Spatial composition guide

Status: `PROPOSED`, semantic relationships only; actual floor plans and footprints remain GDD §5.9.

```text
WORK / STORES  -->  PREPARATION  -->  SHARED TABLE
      |                |                 |
      +---------- paths of care ---------+
                       |
                 WARMTH / REST

Inside: useful surfaces, shared routines, shelter.
Threshold: wet boots/paws, stored tools, doors and paths.
Outside: weather, growing food, water and managed woodland.
```

The diagram is an art-composition guide, not an adjacency bonus formula or permission to rearrange the starter hall.

### 14.4 Required fields for a Blender or asset-agent brief

| Field | Required content |
|---|---|
| `asset_id` | Stable project asset key |
| `scope` | `RELEASE_1` or `FUTURE` |
| `lore_records` | Specific IDs from this bible |
| `decision_dependencies` | Specific DEC IDs; an empty list means none |
| `status` | Status token from §1.2 |
| `mechanical_binding` | Existing catalog key / geometry contract, or `DECORATIVE_ONLY` |
| `reference_claim` | Source ID plus the supported claim, or `ORIGINAL_PROJECT_DESIGN` |
| `silhouette_and_materials` | Concrete approved characteristics; no "make it Redwall" instruction alone |
| `technical_owner` | Relevant crowd architecture / GDD section |
| `review_views` | Front, side, rear, three-quarter, and the existing game-camera view |
| `acceptance` | Pass/fail observations tied to geometry, readability and lore |

These fields are authoring metadata. They do not introduce a Godot component or permission to bypass existing platform/asset validation gates.

### 14.5 Confirmed settlement variety and earth-built homes

`USER_CONFIRMED`, DEC-010 / SRC-U04. `LORE-U07`: Form varies by scenario and remains a player choice. Offer abbey complexes, woodland villages, riverside holts and the existing fortress style across the scenario package. `LORE-U08`: Include homes built into the ground, including burrows and hillside homes. First-release coverage follows the established all-options requirement; an unavailable menu promise is insufficient. The exact compatible style list for each scenario must be authored rather than assuming either total freedom or one fixed style.

The user's “hobbit holes” reference describes inhabited-earth architecture. Use Redwall's setting and original project designs; do not import Tolkien peoples, places, history, emblems or a specific film dwelling. Novel authenticity and original architecture must remain distinguishable.

| Layer | Confirmed direction / current boundary | Required next specification |
|---|---|---|
| Settlement composition | Scenario-dependent; connected complex and distributed homes both belong in the offered variety | Concrete available styles, defaults and scenario constraints; mixing styles within one settlement is not yet specified |
| Earth-built dwelling | Occupied interior visibly set into surrounding earth, with an identifiable entrance and usable access | All three methods approved by DEC-029; specify footprint, entrance elevations, traversable layout and finite depth/capacity |
| Structure and style | A visual kit alone grants no capacity, warmth, cost, defence or species bonus | Bind appearance to a building definition; separately cost/validate structural differences |
| Terrain and navigation | Current GDD uses one floor, slope <=8 degrees and height spread <=0.5 m for placement | Specify cut/mound ownership, placement validity, entrance connections, obstruction and path updates; do not silently waive placement rules |
| Underground editing | All three methods required: complete burrows, one-level room/tunnel planning and free multiple-level excavation | DEC-031 confirms interoperability; specify exact commands, shared topology and vertical access rules |
| Interior visibility | Current roof controls assume ordinary buildings | Earth/roof cutaway selection, cursor picking, occlusion and restoration must reveal occupied rooms without hiding neighboring playable terrain |
| Ecology and water | No new moisture, collapse, ventilation or flooding benefit/hazard inferred | If adopted later, supply exact state, triggers, rates, UI and saves; otherwise no such simulation effects |
| ECS and performance | Existing SoA, fixed tick, resident caps and measured-performance gates remain binding | Any new topology needs exact capacities, bytes, traversal representation and deterministic updates; earth geometry is not permission for per-tile Nodes |
| Blender handoff | Existing coordinate, scale, rig and atlas contracts remain binding | Separate earth-cover, entrance, room and cutaway ownership; validate selected exterior/interior views against the final construction contract |

`USER_CONFIRMED`, DEC-029 / SRC-U05: “All three options available to use.” `LORE-U09`: Complete burrow placement with editable interiors, connected room/tunnel planning on one level, and free excavation across multiple underground levels are required methods. The former single-level-only recommendation is superseded. These are construction methods, not three additional art styles.

Free excavation means player-authored underground space rather than only fixed building shells. It does not imply infinite depth, a voxel implementation or removal of performance bounds. `USER_CONFIRMED`, DEC-031 / SRC-U06: “All methods work together.” `LORE-U12`: The same settlement supports placed burrows, planned room/tunnel extensions and deeper excavated spaces joined by valid vertical access. Switching construction tools does not require a new scenario or an exclusive mode. Shared authoritative connectivity, reservations, services and saved state must govern the result. The current single-floor GDD cannot satisfy the full requirement.

| ID | EARS authoring requirement |
|---|---|
| REQ-LORE-015 | When a scenario is handed to implementation, the scenario record shall declare its player role and available building styles rather than inherit a universal Warden or one mandatory architecture. |
| REQ-LORE-016 | When an earth-built dwelling is handed to implementation, the plan shall bind it to an approved construction and navigation contract and record any departure from current placement or interior rules. |
| REQ-LORE-017 | When a wonder event is handed to implementation, the content record shall specify its exact trigger, recipient, repeat behavior, delivery, saved state and consequences and shall distinguish character belief from a confirmed world fact. |

These requirements govern authoring handoff. They do not supply missing runtime formulas or certify new systems. DEC-029 fixes the all-method scope. Each scenario's concrete records and the engineering contracts below must resolve before dependent feature implementation.

### 14.6 Underground construction engineering follow-through

The following is a required specification checklist, not permission for Claude to invent the missing rules during implementation. Stable keys below are `[NEW authoring metadata]`, not runtime enum numbers. No excavation cost, depth, duration or extra memory allowance is originated in this revision.

| Method key | Required player capability | Acceptance evidence required after implementation |
|---|---|---|
| `BURROW_BUILDING` | Place a complete earth-built dwelling and edit its permitted interior | Valid entrance route, usable edited rooms, correct cost and saved layout |
| `ROOM_TUNNEL_PLAN` | Plan connected underground rooms and tunnels on one level | Legal connectivity, sequential construction, occupied-space protection and saved topology |
| `MULTILEVEL_EXCAVATION` | Excavate player-designed space across multiple underground levels | Vertical access routes, correct excavation progress and resource accounting, level selection/cutaway, deterministic save/reload |

| Spec owner | Required concrete work before coding |
|---|---|
| GDD | Define excavatable material/state, exact depth/cell bounds, room validity, stairs/ramps/access, queued excavation, cancellation and trapped-resident handling; decide any supports/water/air hazards explicitly |
| Balance | Define work and material flows for all methods, labor availability and costs of shared structures; account for existing interior/heat/storage rules without free thermal bonuses |
| Architecture | Specify packed cell/edge/portal stores, capacities and byte totals; deterministic topology invalidation, vertical path queries, job reservations and save migration; bind all methods to consistent committed state |
| UI | Specify construction-method controls, underground level selection, section/cutaway picking, obstruction and access feedback, preview versus committed terrain and cancel behavior |
| Blender/rendering | Specify earth-cover, floor/wall, excavation-face and entrance modules, seams and cutaway ownership at the approved grid/scale; preserve crowd and rendering limits |
| Validation | Exercise all methods, blocked vertical access, occupied-room edits, save/reload with pending work, cancellation material accounting, worst-case path/topology updates and Windows performance gates |

Required coverage includes all three methods. Delivering one method first during development does not change the first-release requirement. Shared-method interoperability is confirmed under DEC-031; validation must also cover extending a placed burrow through a planned tunnel into deeper excavated space.

### 14.7 Adopted art direction — storybook expression and grounded construction

Concrete reference follow-through: [SET-ART-MODEL-001](art-reference/model_reference_guide.md) assigns the reviewed images to species bodies, garments, props and traversal poses. Open those originals during modeling; retain observed features and label original construction of hidden surfaces. This supplements the responsibilities below without changing the art direction or numeric asset limits.

`LORE-U17`, `USER_CONFIRMED`, DEC-018 / SRC-U09: combine options 1 and 3. The guiding direction is **expressive woodland inhabitants in a materially believable world**. The domain allocation below is `[NEW art direction under the adopted blend]`; no percentage such as “70% realism” is specified because it would not tell an asset author what to build.

| Domain | Grounded foundation | Storybook contribution | Asset review condition |
|---|---|---|---|
| Species identity | Preserve distinguishing muzzle/beak, ears, limbs, paws/claws, tail and body silhouette | Emphasize pose, eye direction and silhouette enough to communicate intent | Species remains identifiable at the normal gameplay view; recognizable anatomy follows DEC-019; exact relative sizes require approved species sheets |
| Faces and performance | Expressions follow the creature's face structure; ears, head and posture participate | Broader readable expressions on close/featured actors; strong poses for distant crowds | Emotion survives the permitted camera/LOD; tiny facial details are not its only carrier |
| Bodies and clothing | Garments have plausible seams, fastening, layering and tool access | Selective asymmetry, repairs and color accents suggest personality and occupation | Clothing does not hide species identity, tool hands or action poses; no unapproved age/size ratio |
| Architecture | Timber spans, masonry support, usable thresholds and earth-cover relationships look credible | Slight authored irregularity and distinct entrances/roof lines give each home character | Visual load/support logic is coherent and the model obeys actual gameplay doors, footprints and access |
| Burrows and tunnels | Earth, roots, retaining surfaces, entrances and revealed interiors join convincingly | Warm thresholds and room compositions show habitation beneath the ground | The same art language continues from placed burrow through planned tunnels into deeper excavated rooms |
| Materials | Wood grain follows the piece; stone has mass; cloth reads as cloth; metal, earth and wet surfaces react differently | Curate texture scale, wear placement and broad color grouping | Material identity reads at gameplay distance; fine noise is not mistaken for useful detail |
| Wear and history | Wear appears at contact, water paths, grips, thresholds, hinges and repairs | Distinct repaired objects or favored furnishings provide memorable details | Maintained homes can look cared for; age is not represented by uniform dirt everywhere |
| Landscape | Roots, banks, rocks, canopy and water margins follow a coherent terrain form | Frame paths, entrances and clearings for readable composition | Decoration does not masquerade as harvestable stock, obscure commands or imply unsupported traversal |
| Light and color | Light appears to come from sun, sky, hearths, lamps or other defined scene sources | Art-directed seasonal palettes, warm interiors and restrained emphasis guide attention | Residents and entrances remain readable in the actual game view, including winter and low-light scenes; effects remain within existing contracts |
| Tone | Injury, exhaustion and grief use believable posture and restrained presentation | Expressiveness supports affection, humor and individual character | Warmth and seriousness coexist without changing the art pipeline or making suffering a gag |

Apply one coherent baseline to Abbey, Holt, Fortress, village and earth-built styles. Cultural variation can change shapes, materials and decoration; it must not produce cartoon residents beside unrelated photoreal buildings. Grounded realism does not require strand fur, more bones, larger atlases, physical bodies per resident or a replacement renderer. Existing crowd/Blender/Godot contracts remain binding.

**Priority when visual goals conflict:** gameplay geometry and current technical budgets → readable species/action/access at the actual RTS camera → grounded material/construction logic → expressive and atmospheric embellishment. Resolve a readability issue through silhouette, pose, value grouping, texture scale or lighting composition before proposing a budget increase. A required technical change needs its own measured proposal.

The inhabited world should retain a consistent sense of scale. Painterly-miniature staging, toy-like construction and tilt-shift blur are not part of the selected blend. This does not prohibit authored textures or simplified distant assets; both must support the approved world and rendering contracts.

| Required look-development review | Views and pass conditions |
|---|---|
| Resident and clothing study | Front, side, rear, three-quarter and normal gameplay view under the existing scale/camera; species, clothing/tool function and selected expression are legible within the actual rig/atlas constraints |
| Earth-built dwelling study | Exterior, occupied interior cutaway and normal gameplay view; entrance/ground/room relationships are coherent, selection remains readable and surface detail does not conceal usable space |
| Inhabited environment study | The same small scene in daylight, warm interior light and winter conditions; material identity and route/entrance readability persist without changing resident scale or using a cinematic camera to hide gameplay problems |

These are required future art review artifacts, not assets generated by this document. Use existing approved dimensions and bindings for a study; if a burrow geometry or species-size contract is not yet complete, label the study a visual concept and keep it out of production assets until the geometry is defined. Do not fabricate a canonical building floor plan or artist attribution.

| ID | EARS authoring requirement |
|---|---|
| REQ-LORE-018 | When a resident or environment asset is briefed, the art brief shall apply the grounded and expressive responsibilities in Section 14.7 and identify the existing geometry and rendering contracts it must obey. |
| REQ-LORE-019 | When a look-development asset is reviewed, the review shall include its normal gameplay-camera appearance and shall verify readable species, action or access as applicable before accepting close-up detail as sufficient. |
| REQ-LORE-020 | If a requested visual detail exceeds an existing budget or changes gameplay geometry, then the asset plan shall identify a separate measured technical revision rather than treat the art-style decision as authorization to change that contract. |

## 15. Sound and musical identity

`USER_CONFIRMED`, DEC-021 / SRC-U11: “A mix of all of these.” `LORE-U23`: Combine intimate acoustic music, woodland ambience, occasional communal singing, environmental quiet with sparse music, and fuller orchestral adventure scoring. These are complementary forms within one musical identity. The context allocation below is `[NEW audio direction]`, not an implemented music scheduler or a numerical mix specification.

| Context/layer | Intended emphasis | State and scope constraint |
|---|---|---|
| Ordinary settlement work | Woodland/settlement ambience with intimate acoustic passages and breathing room | Tools, footsteps and facilities must agree with the approved audio representation; no sound of an active nonexistent facility |
| Homes and common spaces | Close domestic detail, restrained melodic warmth and room-appropriate acoustics | Unlit hearths do not sound like fires; sound must not imply uncounted residents |
| Quiet landscape or reflection | Environmental sound and sparse or absent score | Follow actual location, weather and season; silence is an authored option, not a broken music state |
| Feasts and gathering | Acoustic ensemble and occasional communal singing with warmth and shared rhythm | Singing does not require every resident to have a unique voice; stage/performance/participant assumptions need an approved content contract |
| Major achievement or adventure | Fuller orchestral statements that develop the same musical identity | Bind to supported events; this does not add a campaign or battle system to the settlement release |
| Danger and loss | Clear priority for warnings, restrained scoring and space for human-readable consequence | Do not mask alerts with music, trivialize grief with a celebratory cue or falsely announce an invasion |
| Seasonal change | Change orchestration, density and ambience in a coherent palette | Season/weather state remains owned by simulation; music invents no second calendar |

Use related original motifs across solo/small-ensemble and orchestral arrangements so the soundtrack feels like the same world at different emotional scales. Occasional singing is confirmed direction; specific lyrics, singers, instruments and recordings remain content choices. “Distinct voices” in dialogue does not automatically commission full voice acting.

Before audio implementation, specify cue/event bindings, transition and interruption rules, priority/ducking, concurrency, streaming and memory limits, bus controls, save/reload behavior and accessibility treatment for meaningful cues. None of those numeric budgets or middleware choices is established by this blend. Existing performance gates remain binding, including Windows validation when available. Do not create an always-active per-resident audio node or assume simultaneous playback of every layer.

## 16. Story delivery and scope map

`USER_CONFIRMED`, DEC-022 / SRC-U12: “A mix of three where appropriate.” `LORE-U24`: Combine environmental storytelling, resident stories, chronicle/codex entries, optional descriptions, authored events, dialogue and scenario objectives. Each surface has a purpose; the user did not request constant interruptions or every story duplicated on every surface.

| Surface role | Intended use | Authoring constraint |
|---|---|---|
| Environment and short descriptions | Let players notice use, care, history and cultural difference while playing | Physical details cannot imply stock, injuries, ancestry or events absent from approved scenario/state |
| Residents and contextual dialogue | Present individual memories, interpretations and meaningful responses | Bind identity and known facts; distinguish attributed belief from verified history, including uncertain visions |
| Authored events and objectives | Deliver consequential scenes and clarify the action actually available | Specify trigger, participants, eligibility, exact consequences, interruption behavior, UI and saved completion state |
| Chronicle | Preserve what happened in this playthrough and its participants | Read committed events once; repeated presentation does not execute the event or grant a second reward |
| Codex and optional deeper text | Explain verified setting context, declared adaptations and learned information at the player’s chosen pace | Separate source fact, original lore and resident belief; specify reveal/spoiler rules and avoid exposing unknown state |

Essential instructions, causes, resource costs, risks and available choices must remain understandable without reading optional lore. Reopening a codex/chronicle entry must not mutate simulation. Narrative uncertainty concerns interpretation, never an ambiguous account of an actual mechanical debit, injury or objective.

A readable codex and new story interactions are approved direction requiring concrete UI/content contracts. The present UI registry must be extended explicitly with layout, navigation/search as selected, reveal/save behavior and accessibility; the bible does not assign invented UI IDs or claim these surfaces are implemented. Full voiced dialogue and branching conversation engines are not automatically commissioned by mixed delivery.



| Story surface | Release 1 status | Permitted foundation work |
|---|---|---|
| Resident identity and naming | Existing GDD/UI | Apply adopted DEC-016 naming direction; retain existing arrays/selection until an explicit catalog revision |
| Arrival, rescue, death, notability and Charter chronicle records | Existing GDD | Bind approved prose to the actual event and participants |
| Item/building descriptions | Existing content-facing context | Describe current catalog behavior without hiding mechanics |
| Weather/shortage notices | Existing GDD/UI | Preserve severity, cause and exact remedies |
| Codex and optional deeper descriptions | Approved direction; codex UI/content contract absent | Author concrete information architecture, entry/reveal rules and UI bindings |
| Resident stories and authored event/dialogue surfaces | Approved direction; exact interaction contracts absent | Author bounded scenes and supported responses; full voice acting and unrestricted branching remain separate |
| Canonical cameos and authored quests | Future / undecided | Resolve era and named-character constraints first |
| Army personalities, campaigns and diplomacy | Future concept | Maintain world context without adding release 1 state |
| Riddles, prophecies and legendary artifacts | Future concept | Design only when a bounded quest specification exists |

### 16.1 The Hearth Charter in Rowan’s Refuge

`USER_CONFIRMED`, DEC-023 / SRC-U12: “Your recommendation.” `LORE-U25`: The Refuge writes its own Charter after demonstrating that it can sustain and care for its people. It is a civic promise made by the community, not an award issued by Redwall Abbey or a regional authority. Rowan is not its sole owner or the sole person credited with the community’s work.

Its meaning is continued responsibility: shared care, keeping a viable home, remembrance and preparation for those who live there. The existing M4 thresholds, award timing, completion pause, cosmetic monument and option to continue the same save remain unchanged. The Charter does not erase prior deaths or imply that every need will be met automatically from then on. Future family rules must explicitly reconcile M4 accounting; this prose does not quietly change its criteria.

Original draft civic text `[NEW project prose; not a book quotation or final approved ceremony]`:

> We keep this hearth together. We will share the work of care, remember those we have lost, and prepare our home for the seasons to come.

Exact ceremony, final wording, material form, emblem and participants remain DEC-014/content work. No visiting delegation, vote tally, signature minigame, extra feast cost or supernatural blessing is implied. Other scenarios retain their own explicitly authored completion meanings; this choice answers only the current Refuge question.

## 17. Context-to-ECS contract

Lore gives meaning to data; it does not replace data-oriented simulation.

| ID | EARS requirement |
|---|---|
| REQ-LORE-004 | The authoring pipeline shall reference residents through existing persistent IDs and runtime EntityRefs rather than storing Node references in lore records. |
| REQ-LORE-005 | When cosmetic or narrative metadata is added, the implementation plan shall classify it as immutable catalog data, presentation state, or authoritative state before allocating storage. |
| REQ-LORE-006 | If a proposed cultural trait changes work, hunger, access, relationships, immigration or outcomes, then the plan shall identify the GDD rules, catalogs, saves and tests requiring revision before implementation. |
| REQ-LORE-007 | While a decision is OPEN, the implementation agent shall preserve existing specified behavior and continue independent work, without presenting an invented answer as project canon. |
| REQ-LORE-008 | When narrative text reports a simulated event, the presentation shall bind identity, quantities and outcomes to committed state and shall not create gameplay consequences through text generation. |
| REQ-LORE-009 | The implementation shall keep names, lore text and cosmetic variation out of authoritative ordering and RNG decisions unless an explicit versioned ruleset change requires otherwise. |
| REQ-LORE-010 | When a brief proposes a new faction, cultural affiliation or biography system, the author shall specify its actual use and storage budget; the implementation shall not add per-resident objects merely to hold unused worldbuilding. |

The current task creates documents only. No additional culture, religion, morality, age, family, dialogue or reputation component is requested by these rules.

## 18. Contradictions and adaptation register

| Conflict ID | Tension | Current behavior / recommended next action | Decision |
|---|---|---|---|
| LORE-C01 | Redwall-centered setting versus old original-only setting restriction | Follow SRC-U01; old names and institutions remain candidates, not imports | DEC-001 |
| LORE-C02 | Former universal immigration versus community identity | Resolved in specs: scenario rosters and explicit petitions, GDD v2 / SET-AMEND-001; runtime pending | DEC-005 confirmed |
| LORE-C03 | Former land-animal hunting versus adopted dietary boundary | Resolved in specs: hunting chain removed, nut_roast and Orchard main course reconciled; runtime pending | DEC-006 confirmed |
| LORE-C04 | Current estuary preset versus confirmed first-release variety including Redwall Abbey | Keep the refuge as one baseline; author appropriate maps and eras to satisfy confirmed coverage | DEC-004; coverage confirmed DEC-028 |
| LORE-C05 | Warden Rowan versus scenario-dependent player authority | Current Refuge: experienced mouse keeper; preserve succession. Other scenario roles remain separately authored | DEC-003/008 confirmed within scope |
| LORE-C06 | Confirmed selectable settlement forms versus only three current visual kits | Required first-release expansion; author scenario availability and geometry without silently reducing player choice | DEC-010 confirmed |
| LORE-C07 | Anonymous population in early concept versus persistent identities and notability in GDD | GDD wins; anonymous presentation never means interchangeable simulation | DEC-016 |
| LORE-C08 | Early dish effect stacking versus one bounded current food effect | GDD wins; flavor descriptions add no bonuses | No open mechanical decision |
| LORE-C09 | Adopted connected movement versus ground-only baseline | Follow SET-MOVE-001; finish MOVE-G01–05; do not label approved movement merely a future candidate | DEC-019/035 |
| LORE-C10 | Legacy threats never humorous versus broader Redwall tonal inspiration | Warm everyday humor confirmed; antagonist-specific menace/humor remains open | DEC-012 confirmed; DEC-013/027 open |
| LORE-C11 | Confirmed visible family/age diversity versus adult-only simulation | Dependent-resident model adopted; complete family rules/schema/UI revisions with adopted non-graphic child survival vulnerability | DEC-015/032/033 confirmed |
| LORE-C12 | Rare meaningful wonder and its supernatural interpretation | Resolved direction: truth uncertain; preserve attributed beliefs without objective confirmation or debunking | DEC-009/030 confirmed |
| LORE-C13 | Charter name could imply an outside granting authority | Resolved for Rowan’s Refuge: community-written civic promise; preserve current M4 mechanics | DEC-023 confirmed |
| LORE-C14 | Stoats in the early concept / beavers in legacy versus fixed current roster | No catalog additions by flavor text; roster changes require explicit follow-through | DEC-005 |
| LORE-C15 | Confirmed first-release starting-premise variety versus one fixed twelve-adult furnished-hall start | Author exact initialization and objectives for every available launch scenario; do not apply Rowan's start to every premise by default | DEC-002/028 confirmed; individual scenario specs outstanding |
| LORE-C16 | Whole-series references versus a single undifferentiated era or cast | Record context per scenario and verify relevant chronology; cross-era play remains an explicit adaptation choice | DEC-004/025 |
| LORE-C17 | All three underground methods versus current flat-placement/single-floor construction | All-method interoperability confirmed; implement §14.6 engineering contracts without exclusive construction modes | DEC-010/029/031 confirmed |

## 19. Interview and revision procedure

The complete question bank is [setting_decisions.md](setting_decisions.md). Rounds 1–2 confirm variety and its first-release inclusion. Brendan adopted both admission and diet policies. SET-AMEND-001 and revised mechanical owners enact them. Round 3 confirms scenario roles, rare meaningful wonder and selectable settlement forms including earth-built homes. Round 4 confirms all three underground methods, serious grief and visible family life. Round 5 confirms interoperable construction and uncertain supernatural truth; DEC-032 subsequently adopts the dependent-resident family model. Round 6 confirms child survival vulnerability and warm everyday humor; the visual follow-up confirms a blend of storybook and grounded realism under DEC-018. Round 7 confirms recognizable anatomy, light dialect and selective canon flexibility. Round 8 confirms blended naming, layered feast meanings and contextual acoustic/ambient/quiet/singing/orchestral sound. Round 9 confirms mixed story delivery, a community-written Refuge Charter and varied antagonist motives/scales. Round 10 confirms mouse-keeper Rowan and displaced founding, adds the six-book focus, and names torture/child cruelty as boundaries; offscreen-reference treatment is being clarified. Do not reopen the settled first-release scope merely because it requires more work.

For each answer: retain the user's wording; distinguish it from the agent's interpretation; update the decision status; name affected bible records; list mechanical change proposals separately; revise any dependent draft text; and record what remains unanswered. If an answer changes an existing rule, make the concrete cross-document revision reviewable rather than pretending the contradiction disappeared.

### 19.1 Foundation completion gate

| ID | Required evidence | Current state |
|---|---|---|
| LORE-G01 | Source order and adaptation authority explicitly recorded | Complete: SRC-U01 |
| LORE-G02 | Scenario families confirmed and individual scenario place, era and premise specified | Families and first-release inclusion complete: DEC-001/002/024/028; specific context and lineup still pending |
| LORE-G03 | Resident belonging and dietary/sapience boundaries selected | DEC-005/006 and DEC-007 feast meanings confirmed; exact dishes/drinks/customs remain to author |
| LORE-G04 | Leadership, spirituality and community customs selected | Scenario roles and rare meaningful wonder confirmed; uncertain supernatural truth confirmed; Rowan’s mouse-keeper role confirmed; specific governance/biography and customs remain to author |
| LORE-G05 | Content limits and tonal range selected | Serious grief and visible family life confirmed; dependent-resident model confirmed; warm everyday humor and non-graphic child survival vulnerability confirmed; torture and child cruelty are named boundaries; offscreen allowance and wider content details remain DEC-027 |
| LORE-G06 | Character, naming, art and audio direction sufficient for bounded asset briefs | Art blend, recognizable anatomy and light dialect confirmed; naming and sound blends confirmed; exact character/name catalogs/size/material/audio contracts still need authoring |
| LORE-G07 | Story delivery, long-term conflict and completion meaning selected or explicitly deferred | Broad DEC-013/022/023/025 directions confirmed; exact factions, story surfaces and scenario completion contracts remain to author; campaign relationship DEC-026 open |
| LORE-G08 | All chosen departures mapped to concrete GDD/UI/catalog changes or marked descriptive-only | Scope impacts recorded in §7.5–7.7; admission/diet reconciliation complete in SET-AMEND-001; complete scenario contracts, all-method underground engineering, family representation and runtime integration still needed |
| LORE-G09 | Claude instructions require this bible and the decision register | Added with this draft |

Revision 1.0 requires these gates to close or record an explicit user deferral with an operative rule. An unanswered question is not approval, and a detailed draft is not evidence that the foundation is settled.

## 20. Numeric and creative provenance

| Category | Origin |
|---|---|
| Population, roster, initial conditions, calendar, map, scale and asset limits | Inherited from the cited current specifications |
| Source evidence | Earlier bounded studies plus systematic full available-text inspection of twelve supplied narratives; known Salamandastron source gap, absent full Eulalia!, edition integrity and whole-series completeness remain explicit limits |
| Legacy ideas | Explicit candidates extracted from the separate woodland-colony bible |
| New work in this draft | Document/record IDs, status vocabulary, review rules, proposed pillars, original example prose, asset brief fields and interview questions |
| New gameplay quantities or balance values | SET-AMEND-001 records NEW roast inputs, admission pool order and a minimal original petition date/text; inherited output/work values are labelled separately |
| New original authored content | Minimal rat-traveler petition in SET-AMEND-001; no canonical identity, family, named homeland or theology invented |
| Confirmed product direction from Round 1 | Three setting types, multiple starting premises and whole-series references; no launch scenario count or new balance values chosen |
| Round 2 | All confirmed option families required in first playable release; admission and diet subsequently adopted; exact implementation choices and changed catalog values recorded in SET-AMEND-001 |

## 21. Revision log

| Revision | Changes | Remaining scope |
|---|---|---|
| 0.1 | Created sourced creative foundation, inherited game reference, legacy gap extract, adaptation register and agent context contract | Interview answers not yet received; no commit or push |
| 0.2 | Recorded Round 1 as multi-scenario, varied-premise, whole-series direction; added scenario context and impact contracts | Individual scenarios, launch coverage, continuity policy and further creative questions remain open; no commit or push |
| 0.3 | Recorded first-release coverage; supplied requested admission/diet recommendations with source limits and dependency audit | Recommendations awaiting user choice; scenario list and implementation contracts outstanding; no commit or push |
| 0.4 | Adopted DEC-005/006 and reconciled GDD, UI, catalogs and architecture via SET-AMEND-001; asked Round 3 | Full runtime and first-release scenario content outstanding; no commit or push |
| 0.5 | Recorded scenario roles, rare meaningful wonder and selectable settlement styles including earth-built homes; added scope gaps and Round 4 | DEC-029 excavation and DEC-030 supernatural truth remain open; no numeric runtime changes, commit or push |
| 0.6 | Confirmed all three underground construction methods, serious consequences/grief and visible family life; added engineering checklist and Round 5 | Method interoperability, child simulation, content limits and supernatural certainty remain open; no numeric runtime changes, commit or push |
| 0.7 | Confirmed shared construction methods and uncertain supernatural truth; documented the requested family recommendation | DEC-032 recommendation awaits adoption; engineering and content boundaries remain outstanding; no commit or push |
| 0.8 | Adopted dependent residents, shared care, active elders, population accounting and fixed first-release life stages; added required family engineering handoff | Child vulnerability and exact family rules remain outstanding; Round 6 asked; no commit or push |
| 0.9 | Adopted serious non-graphic child survival vulnerability and warm everyday humor; explained art alternatives | Art direction, exact family mechanics and wider boundaries remain open; no commit or push |
| 0.10 | Adopted the storybook/grounded-realism blend; added domain rules, look-development review and art handoff requirements; asked Round 7 | Species proportions, dialect, canon divergence and implementation contracts remain open; no assets generated, commit or push |
| 0.11 | Adopted recognizable anatomy, distinct voices/light dialect and selective canon flexibility; added scenario boundary records; asked Round 8 | Exact species sizes, scenario histories, names, culinary culture and audio remain open; no commit or push |
| 0.12 | Adopted blended naming traditions, layered feast meanings and contextual sound/music blend; asked Round 9 | Exact content lists/customs/audio contracts and remaining scenario/story decisions stay open; no commit or push |
| 0.13 | Adopted mixed story delivery, the community-written Refuge Charter and varied antagonist motives/scales; asked Round 10 | Rowan/founding, wider boundaries and exact story/faction implementations remain open; no commit or push |
| 0.14 | Added six-book focus with bounded publisher evidence; confirmed experienced mouse-keeper Rowan and displaced founding; recorded torture/child-cruelty boundaries | Offscreen-reference clarification pending; exact biography/cause/maps and mechanics remain open; no commit or push |
| 0.15 | Added bounded primary-excerpt research companion and evidence handoff | Full six-novel reading remains incomplete; no new creative decisions, runtime or numeric changes |
| 0.16 | Added complete supplied Lord Brocktree study, audited the mislabeled EPUB and integrated bounded findings LORE-R10–R16 | Other five full readings, edition verification and existing creative/engineering gaps remain; no new policy or gameplay values |
| 0.17 | Added eleven targeted primary-passage studies, 96 evidence records, comparative handoff and LORE-R17–R26 | No new full sequential reading, policy approval, gameplay values or runtime changes; Eulalia! full text remains unavailable in verified files |
| 0.18 | Reviewed all 28 screenshots; added direct modeling references, 62 viewing windows, traversal analysis and source/spec conflict register | No meshes or runtime changes; multi-level engineering and swimming/climbing contracts remain to complete; changes uncommitted |
| 0.19 | Adopted DEC-035 movement in owning specs; added separate twelve-book design/material-world pass, catalog, atlas and handoff | MOVE-G01–05 engineering, new recipe catalogs, scenario bindings and Windows evidence remain open |
| 0.20 | Systematically inspected the available twelve-book corpus; added per-book content libraries, source/game recipe provenance, shared pantry and continuity checks | Full Eulalia!, Salamandastron source gap, recipe balance, scenario selection and existing engineering gates remain open; no runtime values or policies changed |

## 22. Adopted movement and material-world direction — revision 0.19

`USER_CONFIRMED`, DEC-035. The settlement's ordinary life uses persistent tunnels, inhabited underground rooms, surface swimming/diving and connected climbing/canopy access. [SET-MOVE-001](movement_direction_amendment.md) owns this adopted direction. DEC-029/031's interoperable construction scope remains intact. Individual body, training, posture, gear and carried loads determine eligibility through completed profiles; species identity alone grants no bypass.

[The separate design-reading package](redwall-design/README.md) adds twelve thematic studies, a food/ingredient/object catalog, qualitative location atlas and authoring handoff. Its 115 evidence records cover 47,139 inspected extracted words; this is targeted reading, not a complete rereading of the corpus. Eulalia's full text remains unavailable in the verified sources.

New useful source details include Polleekin's inhabited tree home, greensap plant cheese, Didjety's grain/vegetable sausages, cooperative earth/water/tree work, regional hosting customs, ordinary sewing and recipe transmission. These enrich the shared direction; recipe names and source processes do not supply complete game math. The current edible whitelist and content boundaries still apply. The source's early goat milk/eggs and later plant preparations are recorded separately rather than harmonized by assumption.

Artists use the direct IMG assignments together with textual materials and room functions. Writers bind characters/factions to scenario eras and preserve attributed belief. Implementers use the owning numeric catalogs, MOVE-G01–05 and the authoring validation rules. No new recipe, canonical cast, founding biography or measured map is activated by literary interpretation.


## 23. Systematic book-by-book content library — revision 0.20

The [systematic content library](redwall-content-library/README.md), CONTENT-LIB-001, now records full sequential inspection of all available normalized narrative blocks in twelve supplied works: 1,280,344 words across 221 chunks. It indexes 7,665 records and 1,755 food/recipe/discourse candidates, with source ingredients separated from explicitly AI-authored game completions. The source audit retains the confirmed Salamandastron gap, apparently printed pages 314–315; full Eulalia! remains absent; the collection-labeled EPUB contains Lord Brocktree only. This is not complete-series or verified-edition certification.

Use the [authoring contract](redwall-content-library/authoring_handoff.md), [shared pantry](redwall-content-library/shared/pantry.md), [continuity reconciliation](redwall-content-library/shared/continuity.md), [location/movement atlas](redwall-content-library/shared/locations_and_movement.md) and [theme/material direction](redwall-content-library/shared/theme_and_material_direction.md). Character and faction appearances retain eras and source uncertainty; shared titles are not automatically shared individuals. All records remain research candidates, with recipe quantities, yields, work and unlocks requiring the owning balance specification.

Outcast block 3549 explicitly resolves Sunflash’s later name as Sunstripe. Outcast blocks 434–437 support one particular plant-derived greensap milk and cheese preparation; other books’ unspecified milk/cream/cheese origins remain unspecified. Source conflicts over first mountain lord, sapience, geography, visions and moral judgments are preserved rather than silently harmonized. Current admission, diet, content boundaries and DEC-035 movement direction retain their authority. The broader interim boundary guard in §12.5 still applies.
