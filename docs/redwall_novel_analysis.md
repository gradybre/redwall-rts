# Redwall RTS — Novel Analysis and Adaptation Research

| Field | Value |
|---|---|
| Document | SET-RESEARCH-001 |
| Revision | 0.3, 2026-09-06 |
| Request | “Can you do novel analysis to get a deeper understanding?” |
| Purpose | Give planning, writing, art and implementation agents a traceable understanding of the reference literature |
| Coverage | Complete supplied Lord Brocktree text; selected Eulalia! excerpts; eleven additional targeted primary-passage studies; historical publisher/author evidence retained separately |
| Full novels read for this research | 1 of 6: all supplied Lord Brocktree narrative sections read; edition integrity not independently certified. The supplied EPUB is mislabeled as a collection |
| Authority | Research informs [setting_bible.md](setting_bible.md); [setting_decisions.md](setting_decisions.md) controls adopted adaptations; gameplay owners retain numeric authority |
| Implementation effect | No runtime changes, balance changes, new content approvals, commits or pushes |

## 1. Working conclusion

The most useful direction for this game is to make belonging observable through what residents do for one another. This is a project interpretation, supported by the care episodes examined below and by Brendan's existing decisions about visible community life. A settlement becomes emotionally legible when the player can recognize who prepares, carries, tends, welcomes and remembers.

This pass also challenges a possible oversimplification in our six-book guidance: treating Abbey references as domestic and Salamandastron references as purely martial. The passage evidence in OBS-LB01 and OBS-EU02 supports a more connected treatment. Preserve differences between institutions without assigning everyday humanity to only one of them.

The analysis is deliberately uneven because the evidence is uneven. A publisher synopsis supports a premise; it cannot establish narrative technique across a whole book. The four publisher-premise entries below preserve the initial evidence pass; separate targeted primary-text studies now exist in [the expanded package](redwall-series/README.md). They do not convert the original synopsis evidence into full readings. Full character arcs, endings, contradictory passages and recurring motifs for the other five focus novels remain incompletely verified. The [Lord Brocktree study](lord_brocktree_analysis.md) now examines its entire supplied narrative, including its ending and counterexamples; exact cross-book chronology remains separate.

## 2. Evidence and coverage ledger

`PRIMARY_COMPLETE_SUPPLIED_TEXT` means all narrative sections present in the supplied file were read, without certifying a publisher-perfect edition. `PRIMARY_EXCERPT` means actual novel text was inspected. `PRIMARY_TARGETED_PASSAGES` means specified ranges of a supplied complete-length file were inspected, without a complete sequential reading. `PUBLISHER_SUMMARY` means promotional description, not the novel. `AUTHOR_COMMENTARY` concerns the author's account of his work. `EDITORIAL_GUIDE` identifies the guide writer's interpretation or teaching prompts; those are not automatically Jacques's words.

| Evidence ID | Work and source | Inspected coverage | Limits |
|---|---|---|---|
| EV-EU01 | [Eulalia! — official Puffin sample](https://cdn.penguin.co.uk/dam-assets/books/9780241525555/9780241525555-sample.pdf); 2021 edition, ISBN 9780241525555 | PRIMARY_EXCERPT: prologue, printed p. ix; chapter 1, printed pp. 3–7; chapter 3, printed pp. 16–27. Other opening passages were encountered but are not claimed as a complete chapter review | 40 PDF pages include front matter. The sample is not the full novel. Printed page labels differ from PDF viewer positions |
| EV-LB01 | [Lord Brocktree — licensed BookBrowse excerpt, page 1](https://www.bookbrowse.com/excerpts/index.cfm/book_number/727/lord-brocktree) and [page 2](https://www.bookbrowse.com/excerpts/index.cfm/book_number/727/page_number/2/lord-brocktree) | PRIMARY_EXCERPT: Chapter One as displayed across those two web pages | Web pagination is not print pagination. Print edition/ISBN not established from the excerpt. The third web page did not load; no claim depends on it |
| EV-LB02 | User-supplied Lord Brocktree EPUB; [source audit](lord_brocktree_source_audit.json) and [full study](lord_brocktree_analysis.md) | PRIMARY_COMPLETE_SUPPLIED_TEXT: Prologue, Chapters 1–38 and Epilogue, all read in order | File metadata advertises Books 1–20 but contents hold only Lord Brocktree. Edition/validated ISBN unknown; conversion errors visible. Chapter/block locators are extraction-specific |
| EV-RW01 | [Redwall — Penguin edition page](https://www.penguin.co.uk/books/321984/redwall-by-jacquesbrianillustrated-by-gary-chalk/9781862301382) | PUBLISHER_SUMMARY: threatened Abbey and woodland allies | No novel passages verified in this pass |
| EV-MF01 | [Mossflower — Penguin Random House](https://www.penguinrandomhouse.com/books/289823/mossflower-by-brian-jacques/) | PUBLISHER_SUMMARY: ruler, resistance and journey premise | No novel passages verified in this pass |
| EV-LP01 | [The Long Patrol — Penguin edition page](https://www.penguin.co.uk/books/322372/the-long-patrol-by-brian-jacques/9781782954620) | PUBLISHER_SUMMARY: Tammo, the Patrol and Rapscallion threat | No novel passages verified in this pass; no doctrine, rank chart or battle sequence extracted |
| EV-SA01 | [Salamandastron — Penguin edition page](https://www.penguin.co.uk/books/322250/salamandastron-by-jacquesbrian/9781862301412) | PUBLISHER_SUMMARY: concurrent siege and fever threats | No novel passages verified in this pass; no disease model or fortress plan extracted |
| EV-HR01 | [High Rhulain — official excerpt](https://www.penguinrandomhouse.ca/books/292508/high-rhulain-by-brian-jacques/excerpt) | PRIMARY_EXCERPT: Chapter 2 passage returned by the publisher's indexed excerpt, including return to the Abbey and care handoffs | Supporting series only. A subsequent direct page fetch returned navigation alone; the recorded interpretation uses the previously returned passage, not unseen text |
| EV-AU01 | [Redwall teacher's guide](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf) | AUTHOR_COMMENTARY: interview, printed pp. 2–3; EDITORIAL_GUIDE: introduction, printed p. 4 | Historical guide describes a then-incomplete series. No universal theology, modern title count or exhaustive timeline inferred |
| EV-AU02 | [Eulalia! publisher page, Author Interview](https://www.penguinrandomhouse.com/books/292509/eulalia-by-brian-jacques/) | AUTHOR_COMMENTARY: Jacques's anniversary message | Authorial framing, not fictional proof that a game narrator is omniscient |

### 2.1 Additional supplied primary-text evidence

The original ledger above records the earlier pass. Current additional evidence is indexed below; exact file digests, ranges and original analysis are in [SET-RESEARCH-SERIES-001](redwall-series/README.md) and its [audit](redwall-series/source_audit.json). All eleven rows are `PRIMARY_TARGETED_PASSAGES`, not complete sequential readings. The files contain 1,174,789 extracted words; this pass inspected 102,954 unique extracted words and registered 96 analytical passage entries.

| Evidence ID | Work | Study |
|---|---|---|
| EV-RW02 | Redwall | [Hospitality and renewal](redwall-series/redwall.md) |
| EV-MF02 | Mossflower | [Collective freedom and founding](redwall-series/mossflower.md) |
| EV-LP02 | The Long Patrol | [Service and consequences](redwall-series/long_patrol.md) |
| EV-SA02 | Salamandastron | [Distributed care](redwall-series/salamandastron.md) |
| EV-MX02 | Marlfox | [Performance and authority](redwall-series/marlfox.md) |
| EV-MW02 | Martin the Warrior | [Liberation and memory](redwall-series/martin_warrior.md) |
| EV-OC02 | Outcast of Redwall | [Community judgment](redwall-series/outcast.md) |
| EV-TG02 | Taggerung | [Identity and refusal](redwall-series/taggerung.md) |
| EV-PL02 | Pearls of Lutra | [Value and ownership](redwall-series/pearls_lutra.md) |
| EV-RT02 | Rakkety Tam | [Obligation and crowns](redwall-series/rakkety_tam.md) |
| EV-TR02 | Triss | [Life after liberation](redwall-series/triss.md) |

All sources were consulted on 2026-09-06. Failed preview links and unverified fan recollections are not evidence. This document contains analytical notes, not copied chapters, dialogue collections, song lyrics or a substitute plot retelling.

## 3. Passage-level analysis

### 3.1 Eulalia! — households, institutions and remembered lives

| Observation ID | Textual observation | Interpretation and boundary |
|---|---|---|
| OBS-EU01 | Gorath supports grandparents after displacement; stories shape their knowledge of the havens | Shelter means livelihood and relationships. This does not supply Rowan's history |
| OBS-EU02 | Asheye receives assistance and shares tea alongside command responsibilities | Military identity includes dependence and friendship; present competence and need together |
| OBS-EU03 | The prologue frames a chronicle assembled from recollections | Remembering is social work. This framing alone does not prove an unreliable narrator |
| OBS-EU04 | Ancestral dreams influence Asheye's decisions | DEC-030 remains an adaptation; do not describe universal supernatural uncertainty as established canon |

Domestic and institutional concerns share narrative space. The completed succession arc remains unverified. Source: [EV-EU01](https://cdn.penguin.co.uk/dam-assets/books/9780241525555/9780241525555-sample.pdf).

### 3.2 Lord Brocktree — the body of a ruler and the work of a friend

| Observation ID | Textual observation | Interpretation and boundary |
|---|---|---|
| OBS-LB01 | Stonepaw needs assistance; Fleetscut provides warmth and an adapted meal | Individualized care coexists with rank |
| OBS-LB02 | Recollections contrast past strength with present limitations | Identity exceeds output; no universal decline curve follows |
| OBS-LB03 | Coastal foreboding accompanies concerns about absent defenders and succession | Readiness is an institutional concern; the complete supplied narrative is now analyzed separately under EV-LB02 |

The detail makes leadership relational and embodied. Needing help does not remove narrative importance. Sources: [EV-LB01, first page](https://www.bookbrowse.com/excerpts/index.cfm/book_number/727/lord-brocktree), [second page](https://www.bookbrowse.com/excerpts/index.cfm/book_number/727/page_number/2/lord-brocktree).

### 3.2.1 Complete supplied Lord Brocktree reading

[SET-RESEARCH-LB-001](lord_brocktree_analysis.md), revision 1.0, adds 40 passage records, a source-integrity audit, character and institutional analysis, ending checks, adaptation conflicts and planning handoff requirements. It confirms that domestic life and military identity interlock, while qualifying any assumption that sympathetic characters always embody the same care or mercy ethic. Hospitality does not automatically imply alliance, victory does not make every ally choose the same home, and explained spectacle does not disprove every vision.

The source's narrator often moralizes species and appearance. Its humane moments coexist with coercion and severe treatment of enemies. These are reasons to state the game's departures honestly under DEC-005/027/030, not to reverse those decisions. The detailed study identifies the relevant passages without reproducing the novel or importing its incidents into the game.

### 3.3 High Rhulain — supporting evidence for connected community roles

`OBS-HR01`: In the inspected Chapter 2 passage, returning woodland workers bring someone needing help into a sequence involving gatekeepers, leadership, healing, recording and domestic comfort. Brinty's reaction also gives violent action an emotional aftermath. The literary value is the transition between ordinary work, exceptional need and coordinated response: familiar institutions receive the consequences of adventure. This supports studying care and aftermath together; it does not establish a clinical trauma model or authorize importing the incident. [EV-HR01](https://www.penguinrandomhouse.ca/books/292508/high-rhulain-by-brian-jacques/excerpt).

### 3.4 Author and editorial context

`OBS-AU01`: Jacques connects character accents to people he knew, and describes the wartime library as a warm place of imaginative escape. The guide separately presents the Abbey as a recurring center across changing stories. These are different speakers and evidence types. My interpretation is that distinctive social voices and a place readers want to return to deserve deliberate attention; this is not a claim that the novels prescribe a particular class system. [EV-AU01, printed pp. 2–4](https://images.penguinrandomhouse.com/promo_image/9780142302378_5151.pdf).

`OBS-AU02`: In his anniversary message, Jacques playfully casts himself as the Abbey's recorder. That supports examining storytelling as part of the series' hospitality to its reader. Our proposed chronicle still needs its own viewpoint and truth rules. [EV-AU02, Author Interview](https://www.penguinrandomhouse.com/books/292509/eulalia-by-brian-jacques/).

## 4. The other four focus books: bounded interpretations

| Book / observation | Evidence-supported premise | Working interpretation | Full-text question that could change it |
|---|---|---|---|
| Redwall / OBS-RW01 | The Abbey's peaceful inhabitants and woodland allies face Cluny's assault | For game design, home must acquire value before danger can test it. Collective defense suggests looking beyond a single champion | How do work, hospitality, learning and other residents contribute alongside Matthias? Read the actual transitions between ordinary and threatened life. [EV-RW01](https://www.penguin.co.uk/books/321984/redwall-by-jacquesbrianillustrated-by-gary-chalk/9781862301382) |
| Mossflower / OBS-MF01 | Martin and Gonff oppose Tsarmina and seek help through a dangerous journey with an ally | Study how cooperation becomes possible under pressure, including whose knowledge is useful. A refuge scenario should have reasons for trust and mutual aid | What existing local institutions, resources and relationships make resistance possible? How does the conclusion alter those relationships? [EV-MF01](https://www.penguinrandomhouse.com/books/289823/mossflower-by-brian-jacques/) |
| The Long Patrol / OBS-LP01 | Tammo's desired membership meets a dangerous external threat | Distinguish wanting an identity from bearing its responsibilities. Recruitment, competence and obligation are different design concerns | What changes Tammo's understanding of service, and what does the novel retain or challenge about military prestige? This pass has not answered that arc. [EV-LP01](https://www.penguin.co.uk/books/322372/the-long-patrol-by-brian-jacques/9781782954620) |
| Salamandastron / OBS-SA01 | The fortress faces siege while fever threatens the Abbey | Different institutions can face different kinds of vulnerability within one world. Defense capability cannot be assumed to solve all settlement risks | How does the narrative distribute agency between defenders, travelers and caregivers, and what links the threats beyond simultaneity? [EV-SA01](https://www.penguin.co.uk/books/322250/salamandastron-by-jacquesbrian/9781862301412) |

These are neither comparative rankings nor claims that a theme occurs only in one novel. Exact narrative causation and outcomes need primary passages before a named-book scenario can use them as anchors.

## 5. Implications for the current project

The following are **PROPOSED applications** to Brendan's adopted direction. They are original design recommendations, not newly discovered canonical rules. Adopted choices remain the cited DEC records; research does not close open implementation contracts.

### 5.1 Make care visible without turning affection into an efficiency score

DEC-015/032 already require everyday family life, dependent residents and active elders. Give their eventual specification explicit observability: who needs assistance, who can provide it, what interrupts it and what the player can do. Show the existing needs and committed actions before adding another abstract meter.

For Rowan, the immediate writing target is professional attention: notices, checks and practical knowledge appropriate to an experienced keeper. Compassion, a private trauma, reluctance to delegate, age and pronouns remain unapproved characterization. Demonstrating the confirmed occupation does not require inventing a biography.

### 5.2 Give institutions social identities within every building style

A scenario's role and community purpose should guide who welcomes arrivals, organizes common work, preserves knowledge and responds to hardship. Stone construction, a riverbank settlement or an earth-built home cannot answer those questions by itself.

For each selected scenario, specify the following authoring fields before detailed dialogue: `responsibility`, `decision_holder`, `participants`, `place_used`, `ordinary_routine`, `response_when_interrupted`, `mechanical_owner`. These are research/planning fields, not new per-resident runtime components. Do not fill missing fields with an Abbey office that the scenario has never established.

### 5.3 Use specific actions to carry warmth and grief

Warm everyday humor is DEC-012. The practical writing test is whether a scene reveals a relationship or a recognizable inconvenience while preserving the stakes of the active situation. Distinct voices under DEC-017 can come from vocabulary, priorities and conversational habits; the UI still uses plain language.

Serious grief is DEC-011. Before authoring a memorial, establish what the game actually retains about the person and the event. A cosmetic remembrance may refer to committed history; a work interruption, morale effect or recurring observance requires explicit rules. Do not make every loss trigger the same joke or automatically resolve every sorrow at a feast. Exact mourning customs remain DEC-014.

### 5.4 Design history as something the community can know

DEC-022 approves mixed story surfaces and DEC-030 keeps supernatural truth uncertain. An eventual chronicle should distinguish witnessed events, a named resident's recollection, a circulating story and an unresolved interpretation. This is a proposed editorial distinction, not approval for a memory simulator.

A report of an actual death, meal, harvest or departure must match authoritative state. A belief about why an event happened must be attributed as belief. A resident can confidently hold a belief while the game leaves its ultimate explanation open. Do not use unreliable narration to conceal action costs, hazards or outcomes from the player.

### 5.5 Treat displacement as a history to author

DEC-002 establishes displacement for Rowan's Refuge, but it does not establish its cause. The scenario still needs a coherent account of the furnished hall, initial supplies, arrival sequence and why this group stays together. Research can offer questions; it cannot select a war, ruined homeland, canonical persecutor or lost relative on Brendan's behalf.

Resolve the practical founding facts before writing emotional references to them. The initial roster and stockpiles must agree with that history; if the chosen story requires a different roster or resources, prepare an explicit GDD amendment.

### 5.6 Put lived use into the art brief

DEC-018/019 establish grounded construction, storybook expression and recognizable animal anatomy. For an original room, derive prop placement from an approved activity and usable access. A serving surface should be reachable; a seat must support the approved body/rig; the rendered route must match the navigable route. Canonical architecture requires separate passage evidence and cannot be measured from literary adjectives.

Review first at the ordinary RTS camera. Reuse the existing crowd, material and geometry budgets. A detailed room description does not authorize additional actors, collisions, light sources or a new simulation subsystem. No exact species scale, floor plan or Blender export number originates in this research.

## 6. Adaptation and contradiction register

| ID | Potential mistake | Resolution for this project |
|---|---|---|
| ADAPT-001 | Treat the source hierarchy as permission to reverse an adopted choice | Brendan's explicit decisions govern adaptation. Report the difference honestly |
| ADAPT-002 | Call uncertain supernatural truth a verified universal novel rule | Apply DEC-030 as game direction; retain the evidence boundary identified in OBS-EU04 |
| ADAPT-003 | Import a depicted source incident despite content exclusions | Apply DEC-027. No depiction of torture or deliberate cruelty toward children; pending clarification, exclude both entirely from new story content. Existing non-graphic survival hazards remain distinct |
| ADAPT-004 | Infer individual evil or automatic betrayal from species labels | Apply DEC-005 and the adopted petition rules; no hidden species-morality mechanic |
| ADAPT-005 | Call the game's diet a complete account of Redwall ecology | DEC-006 is the adopted game diet. Comprehensive sapience/predation classification remains unverified |
| ADAPT-006 | Give every young character a normal job because source adventures involve the young | DEC-032/033 govern child care, survival and prohibited work. Fictional labels are not numeric ages or child-labor eligibility |
| ADAPT-007 | Make every elder physically incapable, or every elder exceptionally wise | Use individual authored identity within the approved family contract. Fixed release life stages do not authorize an aging system |
| ADAPT-008 | Treat fortress and domestic identity as mutually exclusive | Refine the bible's reference guidance; do not erase the institution-specific distinctions |
| ADAPT-009 | Treat a novel's underground dwelling as proof of a multi-level excavation algorithm | DEC-029/031 establish scope; topology, engineering and save contracts still need specification |
| ADAPT-010 | Treat novel-scale time, forces or descriptions as exact balance data | Use the owning gameplay and performance specifications; record any future numeric changes as game design |

Two findings warrant particular care in our existing documents: the original six-book table retains its synopsis-based evidence, while Lord Brocktree now has a separate complete-supplied-text study; and the setting bible remains a foundation in progress. This research strengthens its evidence without making revision 1.0 or the implementation ready by implication.

## 7. Research-to-spec handoff contract

These requirements govern use of this research, not new game features. They operationalize the existing source/proposal distinction.

| Requirement | EARS statement |
|---|---|
| REQ-RESEARCH-001 | When a plan claims a fact from a novel, the author shall supply an evidence ID, verified locator and the claim's bounded scope. |
| REQ-RESEARCH-002 | If support is limited to a publisher summary, then the plan shall label it PUBLISHER_SUMMARY and shall not claim passage-level verification. |
| REQ-RESEARCH-003 | When an interpretation motivates a feature, the plan shall distinguish the observation, interpretation, adopted decision and proposed implementation. |
| REQ-RESEARCH-004 | If an adaptation contradicts a source observation, then the plan shall preserve the adopted decision and record the departure explicitly. |
| REQ-RESEARCH-005 | When a proposal affects authoritative state, the author shall identify the owning rules, schema, persistence and validation changes before implementation. |
| REQ-RESEARCH-006 | While a novel's primary-text coverage is incomplete, the research record shall retain that limit and shall not report a complete analysis of that novel. |

The following is a completed example of a research note, not an executable feature declaration:

```yaml
research_contract_version: 1
record_id: NOTE-CARE-001
evidence_ids: [EV-LB01, EV-LB02]
observation_ids: [OBS-LB01]
interpretation_scope: SELECTED_PASSAGE
decision_dependencies: [DEC-015, DEC-032]
proposal: Make caregiver actions and unmet assistance visible in the family specification.
status: PROPOSED
mechanical_owner: docs/game_gdd.md
runtime_changes_authorized_by_this_note: false
new_simulation_numbers: []
complete_supplied_lord_brocktree_read: true
source_edition_validated: false
```

```text
Verified passage ------> Bounded observation ------> Interpretation
                                                       |
User decisions ----------------------------------------+
                                                       v
                                               Adaptation proposal
                                                       |
                        +------------------------------+-----------------+
                        v                                                v
                Text / asset brief                              Gameplay amendment
                        |                                                |
                        +------------------------------+-----------------+
                                                       v
                                         Review against owning contracts
```

Keep this ledger as static authoring material. Do not create an object per resident to store literary research, attach it to simulation ordering, or add narrative RNG calls. Existing ECS and presentation contracts continue to apply.

## 8. Full-text research progress and remaining work

Brendan supplied a local EPUB on 2026-09-06. Its advertised collection metadata is wrong: the actual contents contain Lord Brocktree alone. Its entire supplied narrative has now been read and analyzed. The [source audit](lord_brocktree_source_audit.json) records identity, digest, section coverage and locators. Eleven more supplied files have since been verified and studied through targeted passages. Redwall, Mossflower, The Long Patrol and Salamandastron now have accessible source texts and targeted studies. Eulalia! still lacks a verified complete text here. Complete sequential reading remains pending for those five focus titles and the seven additional novels.

| Focus work | Current reading coverage | Next evidence needed |
|---|---|---|
| Lord Brocktree | All 40 supplied narrative sections read; complete supplied-text analysis | Independent edition/text-integrity comparison if exact wording or edition-specific claims matter |
| Eulalia! | Previously recorded selected official excerpts | Complete novel and full reading |
| Redwall | Supplied text verified; [targeted passage study](redwall-series/redwall.md) | Read remaining text sequentially and revisit complete arcs |
| Mossflower | Supplied text verified; [targeted passage study](redwall-series/mossflower.md) | Read remaining text sequentially and revisit complete arcs |
| The Long Patrol | Supplied text verified; [targeted passage study](redwall-series/long_patrol.md) | Read remaining text sequentially and revisit complete arcs |
| Salamandastron | Supplied text verified; [targeted passage study](redwall-series/salamandastron.md) | Read remaining text sequentially and revisit complete arcs |

READ-001–005 and READ-007 are complete for the supplied Lord Brocktree text within the stated edition limits. READ-006 has a bounded mixed-coverage comparison in the expanded package, but remains incomplete as a full six-novel reading comparison. READ-002 is not complete for any of the eleven new files; READ-003–005 and READ-007 have targeted evidence and documented limits.

| Step | Exact research action | Completion evidence |
|---|---|---|
| READ-001 | Identify each supplied file's title, edition, ISBN when present, contents order and text accessibility | File manifest with verified metadata; unknown fields explicitly null |
| READ-002 | Read each focus novel in narrative order; track actual chapter/part labels and gaps | Coverage ledger records completed sections; keyword hits alone never mark a section read |
| READ-003 | Record passages bearing on home, food, work, authority, care, grief, humor, wonder, species, geography and material culture | Concise observation records with locators; absent evidence recorded without inventing it |
| READ-004 | Examine apparent exceptions and conflicts against each proposed generalization | Claim-level status: supported within scope, qualified, contradicted or unresolved; no percentage confidence invented |
| READ-005 | Analyze changes across character arcs and the consequences retained at each ending | Original critical synthesis with bounded evidence, not scene-by-scene substitute retellings |
| READ-006 | Compare the six books without collapsing their eras or institutions | Shared patterns and exceptions linked to observations from the relevant books |
| READ-007 | Reconcile findings with game decisions and scenario restrictions | Updated adaptation register; no automatic approval of mechanics or biography |

No complete novel or protected ebook material needs to be copied into the repository. Store analysis and bibliographic locators there; keep the supplied reading files separate.

## 9. Provenance and verification

Inherited: the six-book focus; the decisions referenced above; the current spec authority and ECS direction. Newly authored: observation IDs, critical interpretations, adaptation checks, proposed editorial fields and research handoff requirements. No production rates, costs, dimensions, age thresholds, combat stats or performance budgets were invented.

Document IDs, version numbers and research-step counts are organizational metadata. Printed page numbers and ISBNs are source locators, not gameplay constants. The initial excerpt pass and the complete supplied Lord Brocktree pass are documented separately. Exhaustive analysis of all six novels still requires Eulalia! full-text access and completion of the other five sequential readings. The expanded eleven-book package is a substantive targeted pass, not evidence that those readings occurred. New file sizes, digests, section counts and extracted word counts are source-audit measurements, not gameplay values.
