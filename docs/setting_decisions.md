# Redwall RTS — Setting Decisions and Interview

| Field | Value |
|---|---|
| Document | SET-DEC-001 |
| Revision | 0.20, 2026-09-06 |
| Companion | [Setting bible](setting_bible.md) |
| Purpose | Preserve Brendan's decisions, distinguish recommendations from answers, and expose cross-document consequences |
| Current interview | Six-book focus, mouse-keeper Rowan and displaced founding recorded; exclusion versus offscreen-reference clarification pending |
| Mechanical effect | None; this file records decisions and proposed revisions, not unannounced ruleset changes |

## 1. Recorded authority

### DEC-000 — Creative source priority

| Field | Value |
|---|---|
| Status | `USER_CONFIRMED` |
| Source | Brendan, 2026-09-05, current conversation |
| User wording | “use Redwall as the main source, then our current project, then the woodlands colony to fill gaps. Then grill me on any questions to build details, close gaps, and ensure there is a deep, solid foundation.” |
| Operative decision | Redwall is the first creative source, the current Redwall-rts project is second, and the earlier woodland-colony material fills remaining gaps |
| Interpretation | Treat inherited mechanics honestly as current behavior; propose explicit changes when fidelity calls for a departure. Do not silently override either the source or the gameplay specification |
| Scope | Planning, lore, writing, UI flavor, visual/audio direction and asset briefs |
| Documents affected | `setting_bible.md`, this register, `CLAUDE.md` |
| Not decided by this instruction | Location, era, canonical cast, original founding story, species morality, diet, religion, final art style, or release scope changes |

## 2. Interview method

Ask in small rounds, normally three questions. Follow up on tensions in the answers rather than treating a selection as a complete biography or policy. A recommendation is not a preselected answer. Silence is not consent.

Each answer may be free-form. If Brendan says “use your judgment,” record that delegation and the chosen interpretation. Do not label the agent's resulting details as direct user wording. A partial answer closes only the part it actually addresses.

| Decision state | Meaning |
|---|---|
| `OPEN` | No sufficient answer yet |
| `USER_CONFIRMED` | Explicit answer recorded with its scope |
| `DELEGATED` | Brendan explicitly delegated a bounded decision; agent choice and rationale recorded separately |
| `DEFERRED_BY_USER` | Brendan explicitly chose to revisit; record current operative rule and revisit trigger |
| `SUPERSEDED` | A later decision replaced this one; link its ID |

DEC-000, DEC-001, DEC-002, DEC-003, DEC-005, DEC-006, DEC-007, DEC-008, DEC-009, DEC-010, DEC-011, DEC-012, DEC-013, DEC-015, DEC-016, DEC-017, DEC-018, DEC-019, DEC-021, DEC-022, DEC-023, DEC-024, DEC-025, DEC-028, DEC-029, DEC-030, DEC-031, DEC-032, DEC-033 and DEC-034 are `USER_CONFIRMED` within their recorded scope. DEC-004, DEC-014, DEC-020 and DEC-026 remain `OPEN`; DEC-027 has confirmed boundary subjects with treatment still `OPEN`. DEC-008 confirms scenario-dependent roles, not complete governance rules. DEC-009 confirms rarity and significance; DEC-030 now confirms that supernatural truth remains uncertain. DEC-010 confirms style choice and earth-built homes; DEC-029 subsequently confirms all three construction methods, including multiple-level excavation. DEC-011 confirms emotional seriousness, not a complete graphic-content policy. DEC-015 confirms visible family life; DEC-032 now adopts dependent residents and fixed release life stages. Exact needs/care values remain unspecified; DEC-033 now confirms serious survival vulnerability with non-graphic presentation. DEC-012 confirms warm everyday humor; antagonist humor remains to author. DEC-019 confirms recognizable anatomy, not exact relative sizes or locomotion. DEC-017 confirms light dialect. DEC-025 allows selective canon fidelity and departures with scenario-specific boundaries. DEC-016 adopts blended naming traditions; DEC-007 adopts all offered feast meanings; DEC-021 adopts a contextual mix of acoustic music, ambience, singing, quiet and orchestral adventure. Exact catalogs, recipes, diplomacy and audio implementation remain separate. DEC-022 adopts mixed story surfaces; DEC-023 adopts a self-authored civic Charter for Rowan’s Refuge; DEC-013 adopts varied antagonist motives and scales across future scenarios. DEC-003 confirms Rowan as an experienced mouse keeper; the Refuge’s founding is displacement under DEC-002. DEC-034 narrows creative emphasis to six named books without dropping the whole series. DEC-027 identifies torture and cruelty toward children as boundary subjects; offscreen treatment is being clarified. Source fidelity and authored implementation details remain distinct. The current GDD revision 1.1 and SET-AMEND-001 enact admission and food policies; concrete scenario histories and full-release content remain to be authored.

## 3. Round 1 — Identity, origin, and essential references

The three original questions are retained below for context. Brendan chose variety for both setting and starting premise, and the whole series as the reference scope; the answer records following the table govern interpretation.

| ID | Question | Why it comes first | Current behavior / dependent work |
|---|---|---|---|
| DEC-001 | Where does the game sit in Redwall's world: an original community away from the novels' main events; Redwall Abbey with a new story between novels; or a particular novel/era? | Determines canon obligations, available characters, map requirements and freedom to invent | All three types confirmed as product options; each concrete scenario still needs its own context |
| DEC-002 | What is the player building, and what condition is it in at the start: a new refuge, a damaged abbey being restored, or a small established community? What brought the first residents together? | Determines the opening's emotional purpose and how wealth, architecture and shared history should look | Varied premises confirmed; the current completed refuge is one baseline, not the initialization for every future start |
| DEC-024 | Which books, characters, places or moments are essential to your vision? What would make this feel wrong? Describing the feeling is sufficient if titles are forgotten | Determines the reference emphasis; prevents the agent's favorite reading of Redwall from replacing the user's | Whole series confirmed; no single preferred novel or specific adaptation/illustration selected |

The previous recommendation to choose an original community as the single setting is superseded by DEC-001. The existing refuge can still serve as one scenario; its candidacy as the first completed scenario is not a user selection.

### DEC-001 — All three setting types are player options

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “Options for all 3 to give variety of gameplay.” |
| interpretation | Offer original communities in Redwall's world, Redwall Abbey scenarios, and scenarios associated with particular novels or eras; do not choose one permanent setting for the whole product |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; first-release inclusion subsequently confirmed by DEC-028 |
| operative_rule | Organize setting context by scenario; preserve a common Redwall reference foundation and scenario-specific place, era, cast and initial conditions |
| affected_lore | `[LORE-U01, LORE-P06, LORE-C04, LORE-C16]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; candidate implementation revisions: GDD and UI |
| mechanical_change | Required scope: multiple scenario definitions, appropriate maps, scenario-selection UI and save compatibility. Named first-release set still needs specification; single-start GDD is an identified gap, not the accepted final scope |
| remaining_questions | `[DEC-003, DEC-004]`; named scenario lineup, exact continuity boundaries and valid premise combinations still needed; broad selective flexibility is confirmed under DEC-025; coverage closed by DEC-028 |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-001/revision-0.1 single-setting recommendation]`; this was an agent proposal, not a prior user decision |

### DEC-002 — Varied starting premises are player options

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “Again, options for the player to have various options here.” |
| interpretation | In response to the new-refuge/restoration/established-community question, retain those as player-facing premise families; author specific starts rather than imposing one origin on every playthrough |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; first-release inclusion subsequently confirmed by DEC-028 |
| operative_rule | Specify who founded or supplied each scenario, what condition it begins in and why the player takes responsibility; do not assume every setting/premise pairing is valid |
| affected_lore | `[LORE-U02, LORE-P03, LORE-P04, LORE-P05, LORE-C15]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; candidate implementation revisions: GDD, UI, balance and initialization validation |
| mechanical_change | Proposed scope: scenario-specific initial residents, inventory, building condition, ecology, objectives and onboarding, retaining the shared simulation. Values are not supplied by this answer and shall not be invented as inherited |
| remaining_questions | `[DEC-003, DEC-004, DEC-008, DEC-010, DEC-023]`; concrete founding/restoration histories and starting resources remain scenario-specific work; coverage closed by DEC-028 |
| revisit_trigger | `NONE` |
| supersedes | `[]` |

### DEC-024 — Whole-series reference scope

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “Spanning the whole series.” |
| interpretation | Use the complete Redwall series as the creative reference pool, rather than privileging a single novel. This does not commission an adaptation of every novel or combine every era's cast |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Draw relevant references across the series and verify claims per scenario; retain explicit evidence limits rather than claiming all novels have already been reviewed |
| affected_lore | `[LORE-U03, LORE-C16]`; reference map and scenario contracts |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]` |
| mechanical_change | `NONE`; individual source-inspired systems or scenarios require their own specifications |
| remaining_questions | `[DEC-004]`; specific scenario anchors, forbidden departures and named visual references remain to author. DEC-018/025 establish broad visual/adaptation policy |
| revisit_trigger | `NONE` |
| supersedes | `[]` |

### Follow-up probes after Round 1 answers

1. What is the community trying to preserve, rebuild or prove that it did not possess before?
2. Who built and supplied the starter hall, and why does responsibility pass to the player at this particular moment?
3. Which single choice should the player remember after the first winter?
4. If using a novel era, which named people must be alive, which major events have already happened, and which events may the game change?
5. If the fiction says the settlement is destitute or ruined, how should that be reconciled with the existing starter inventory and completed shelter?

These probes now apply to each concrete scenario under DEC-003/004 and the selected release scope. They must not be used to reopen the confirmed choice to offer variety.

## 4. Foundation questions — ask next according to dependencies

### Round 2 release question

| ID | Question | Current operative rule | Consequence of answer |
|---|---|---|---|
| DEC-028 | Are all three setting types and the varied starting premises required for the first playable release, or is that the full-game goal with one complete scenario first? | User answered “All built”: all option families required for first release; current single-start GDD needs expansion | Author the concrete launch scenarios and GDD/UI/map/initialization contracts. This answer concerns scenario coverage; it does not itself add battle or campaign systems |

Round 2 received: “1. All built / 2. What is your recommendation / 3. What is your recommendation”. The first answer confirms scope. The other two initially requested advice; Brendan subsequently answered “Adopt both”, confirming DEC-005/006 below. In the admission and diet answers, distinguish universal world rules from scenario-specific cultural practices.

### DEC-028 — All option families built for the first release

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “1. All built” |
| interpretation | In response to all-options-first versus one-scenario-first, require all three setting types and varied starting-premise families in the first playable release |
| scope | `[RELEASE_1, PRESENTATION]` |
| operative_rule | Plan and complete the full confirmed option coverage; one finished scenario plus future promises does not meet the requirement |
| affected_lore | `[LORE-U04, LORE-C04, LORE-C15, LORE-G02, LORE-G08]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required follow-through: GDD, UI, scenario specifications, architecture and validation |
| mechanical_change | Current GDD §5.1 / REQ-SET-009 and UI-SET-103 define one refuge initialization. Expand to complete scenario definitions and selection; specify save/catalog compatibility, per-scenario initialization, objectives, opening descriptions and deterministic validation. Exact content lineup and numerical values remain to be authored |
| remaining_questions | `[]` for first-release inclusion; individual scenario design remains DEC-003/004/023/025 and the scenario contracts |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-028/revision-0.2 staged-release recommendation]`; that recommendation was the agent's, not the user's |

#### Required follow-through for DEC-028

| Work | Acceptance |
|---|---|
| Scenario lineup | Enumerate launch scenarios and their setting-type/premise coverage; all confirmed families have actual playable entries |
| Initialization | Each scenario has exact resident, inventory, building, condition, ecology and event data; no reused start falsely presented as a distinct premise |
| Objectives | Scenario-appropriate, completely specified goals; do not force the Hearth Charter onto every source-linked story by assumption |
| UI | All available choices have valid descriptions and inputs; no locked or future-only entry counted as delivered |
| Persistence / validation | Each scenario has specified identity/version handling, deterministic initialization and save/load verification under the eventual implementation contract |

Build order can still be sequential; completion criteria include all confirmed option families. This is a release requirement, not a claim that they have been implemented during the lore interview.

### 4.1 People, food, and community boundaries

| ID | Main question | Stress-case follow-up | Existing behavior and change implications |
|---|---|---|---|
| DEC-005 | Should rats, ferrets, weasels, foxes, wildcats and wolverines be ordinary residents, rare exceptions, members of separate societies, or generally excluded from the player's community? | A hungry rat family asks for shelter during a lean winter. What makes refusal or acceptance morally difficult here? Is species, personal conduct, allegiance, history, or available food decisive? Does the answer differ for an unarmed former raider? | Adopted: scenario-specific pools and authored exceptions under SET-AMEND-001; no hidden species betrayal or new probation system. Family is a hypothetical lore case, not a request to simulate children |
| DEC-006 | What are this world's dietary and sapience boundaries? Should the settlement hunt mammals and birds, eat fish/seafood but no land animals, or follow another explicit rule? | If a sparrow is a person but a grouse is hunted, is that distinction acceptable? Where do meat, hides and predatory-creature diets come from? Do you want this explained, avoided, or intentionally different from the books? | Adopted: land-animal hunting retired; plant/fish/seafood boundary and exact recipe/material revisions in SET-AMEND-001. This is the game policy, not a universal claim about every novel |
| DEC-007 | How closely should food follow Redwall's named dishes and feast culture? Are recognizably adapted meals enough, or are particular book dishes essential? How should mead and other drinks be depicted? | Should a feast feel like gratitude, hospitality, a seasonal festival, an achievement, or a political obligation? Would a feast held while someone goes hungry feel like a valid dilemma or a violation of the game's intended community? | The GDD has exact recipes and three feast themes. Named dishes must match actual ingredients; additions/replacements need catalog and balance review. Mead exists; intoxication does not |

DEC-005/006 are now closed for policy; build faction and diet context from these adopted boundaries. Rounds 3–4 are recorded below; Round 5 confirms DEC-031/030; DEC-032 is now adopted below.

### DEC-005 — Community-specific populations with individual exceptions

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “Adopt both” |
| interpretation | Each scenario has a culturally appropriate normal population. Unusual individuals enter through authored characters or encounters and explicit player decisions. Species alone does not produce hidden automatic betrayal or virtue. |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; exact scenario implementations remain individually scoped |
| operative_rule | Apply the adopted policy and the reconciled [setting_rules_amendment.md](setting_rules_amendment.md); do not implement the prior all-species/hunting defaults |
| affected_lore | `[LORE-A01–A04]`; related baseline/conflict records updated |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, docs/setting_rules_amendment.md, docs/game_gdd.md, docs/ui_ux_controls.md, docs/gameplay_balance.md, docs/systems_architecture.md, docs/validation_resolution.md, CLAUDE.md]` |
| mechanical_change | GDD admission uses a scenario profile; ordinary selection, the current refuge pool and its authored rat petition, expiry, auto-admission exclusions and atomic candidate clearing are specified in SET-AMEND-001 §5–6. |
| remaining_questions | `[]` for policy adoption; detailed cultural histories, other scenario rosters, faith and source-specific predation are separate interview/content work |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-005/revision-0.3 recommendation pending adoption]` |
| provenance_boundary | Exact authored profile order, event date/prose, recipe replacement and schema retirement choices are NEW implementation decisions, not direct user quotations or verified Redwall canon |

### DEC-006 — Plant staples plus fish and seafood

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-05 |
| user_wording | “Adopt both” |
| interpretation | Remove mammal/bird hunting from the normal settlement economy. Use plant staples and explicitly nonsapient aquatic food species; never classify a person as food. Resolve clothing/equipment with plant materials, wood and metal rather than a hide supply chain. |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; exact scenario implementations remain individually scoped |
| operative_rule | Apply the adopted policy and the reconciled [setting_rules_amendment.md](setting_rules_amendment.md); do not implement the prior all-species/hunting defaults |
| affected_lore | `[LORE-A05–A09]`; related baseline/conflict records updated |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, docs/setting_rules_amendment.md, docs/game_gdd.md, docs/ui_ux_controls.md, docs/gameplay_balance.md, docs/systems_architecture.md, docs/validation_resolution.md, CLAUDE.md]` |
| mechanical_change | SET-AMEND-001 retires hunt content, reserves enum/storage holes, adds the exact nut_roast recipe, updates Orchard feast and mastery policy, and rejects incompatible v1 saves. GDD/UI/derived catalogs are reconciled. |
| remaining_questions | `[]` for policy adoption; detailed cultural histories, other scenario rosters, faith and source-specific predation are separate interview/content work |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-006/revision-0.3 recommendation pending adoption]` |
| provenance_boundary | Exact authored profile order, event date/prose, recipe replacement and schema retirement choices are NEW implementation decisions, not direct user quotations or verified Redwall canon |

### 4.2 Leadership, belief, and the built home

| ID | Main question | Stress-case follow-up | Existing behavior and change implications |
|---|---|---|---|
| DEC-003 | For each scenario, who leads and what role does the player have? For the current refuge, who is Rowan: species, pronouns, life stage, strength and flaw? | What would this leader refuse even for survival? Who can challenge them? Does the scenario survive their death? | Rowan's GDD identity and succession apply to the existing refuge. They do not establish a universal leader for every confirmed setting type |
| DEC-004 | For each concrete scenario, what place, era and regional relationships apply? Which source events have happened and which people can be present? | For the original refuge, why is a coastal settlement here? How isolated is it? For an Abbey or novel scenario, which map and historical facts must remain intact? | Exact canonical geography and scenario eras remain unverified. Whole-series coverage does not place everyone in a single timeline. Trade routes, travel timers and new settlements are not current systems |
| DEC-008 | Who is the player in the fiction, and how is authority shared: Warden, Abbot/Abbess, council, or an overseeing community role? What makes a leader legitimate? | When elders disagree with a survival decision, can they refuse, advise, leave, or remove the leader? Are those only story possibilities or mechanics you eventually want? | Confirmed: role varies by scenario; exact legitimacy and resistance remain scenario authoring work. Existing refuge Warden succession remains operative |
| DEC-009 | What place do belief, remembrance, visions and legendary guidance have? Are they objectively real, ambiguous, or a matter of personal interpretation? | Could Martin appear in a dream? Would two residents interpret it differently? What does an abbey title mean, and what happens when someone dies? | Confirmed: rare and meaningful. DEC-030 now confirms uncertain supernatural truth; no complete theology or powers are authorized |
| DEC-010 | Should the settlement read as one growing abbey complex, a village organized around a communal hall, a riverside holt, or several equally important possibilities? | Does the community sleep and eat together as it grows, or does private domestic life become important? What must remain visually central at 200 residents? | Confirmed: scenario-dependent forms and player style choice, including earth-built homes. Existing three-kit/single-floor GDD is incomplete for this requirement; DEC-029 confirms all three underground construction methods; exact engineering remains to specify |

### Round 3 — Confirmed direction and bounded follow-through

The direct answers were “Role changes by scenario.”, “Rare and meaningful”, and “By scenario. All available, different styles for the player to choose. Also should include styles of building into the ground (think burrows, hobbit holes)”. The records below preserve their different scopes. No numeric event rate, tunnel depth, construction cost, or stat modifier was supplied.

### DEC-008 — Player role varies by scenario

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Role changes by scenario.” |
| interpretation | There is no universal player office or embodied protagonist across all scenarios |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Each scenario specifies the player role, represented person or institution, source of authority, title and leader-loss continuity; Rowan and Warden remain specific to the existing refuge |
| affected_lore | `[LORE-U05, LORE-C05]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; subsequent scenario GDD/UI contracts |
| mechanical_change | No global command, resident or succession change enacted by this answer; author differing authority mechanics explicitly if a scenario needs them |
| remaining_questions | `[DEC-003]`; concrete role, legitimacy, resident resistance and leadership continuity for each scenario |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-008/open universal-role selection]` |

### DEC-009 — Rare and meaningful wonder

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Rare and meaningful” |
| interpretation | Visions, legendary guidance and related wonder have narrative weight and are uncommon; the answer does not settle their objective truth |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Author wonder around a specific memory, duty, uncertainty or choice; do not generate routine supernatural chatter or infer powers, stat rewards, resurrection or a full theology |
| affected_lore | `[LORE-U06, LORE-C12]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future narrative-event contract |
| mechanical_change | None yet. Exact trigger, repeat prevention, recipient, delivery and consequences must be specified for each playable event before implementation; no arbitrary probability or cooldown is adopted |
| remaining_questions | Specific event delivery and scenario interpretations; broad story surfaces now confirmed under DEC-022. DEC-030 confirms uncertain truth; named appearances still require era/source verification |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-009/open frequency and significance]` |

### DEC-010 — Scenario variety, selectable styles and earth-built homes

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “By scenario. All available, different styles for the player to choose. Also should include styles of building into the ground (think burrows, hobbit holes)” |
| interpretation | Offer the previously discussed abbey complex, woodland village and riverside holt forms, retain the existing fortress style, and include inhabited burrows/hillside homes; style is a player choice within authored scenario contracts |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; first-release inclusion follows the existing all-options scope |
| operative_rule | Build meaningful style choices across the scenario offering, including homes set into earth. A scenario's default cannot silently become its sole permitted style. Document exact available choices and any canon/map constraints; the answer does not require every possible combination |
| affected_lore | `[LORE-U07, LORE-U08, LORE-C06, LORE-C17]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required follow-through in GDD, UI, architecture, balance and Blender asset contracts |
| mechanical_change | Required first-release content expansion beyond the current three kits. Earth-built occupied rooms require a construction/traversal contract; current single-floor placement cannot be described as complete support. DEC-029 subsequently confirms all three methods; DEC-031 subsequently confirms that the methods work together |
| remaining_questions | `[DEC-020, DEC-004]`; mixed-style composition, exact scenario availability and materials. Construction interoperability is confirmed under DEC-031 |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-010/open settlement-form selection]`; does not supersede existing numeric geometry or performance contracts without a concrete replacement |
| provenance_boundary | “Hobbit holes” is the user's spatial reference for earth-built dwellings; it does not add Tolkien peoples, places, lore or copied film designs to this Redwall setting |

### Round 4 — Answered

| ID | User wording | Confirmed scope |
|---|---|---|
| DEC-029 | “All three options available to use” | Complete burrow placement with editable interiors; connected rooms/tunnels on one underground level; free excavation across multiple underground levels |
| DEC-011 | “Serious consequences and grief” | Loss carries emotional and practical weight; no graphic-intensity choice inferred from the shorter wording |
| DEC-015 | “Visible everyday community life” | Families, children and elders are visible in daily life, rather than confined to offscreen lore; simulation depth remains separate |

### DEC-029 — All three underground construction methods

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “All three options available to use” |
| interpretation | Refers to the three underground construction options asked immediately before the answer; all are required, including free excavation across multiple levels |
| scope | `[RELEASE_1, FUTURE, PRESENTATION]`; inherited all-options-first scope under DEC-028/010 |
| operative_rule | Offer complete burrow placement with editable interiors, room/tunnel planning on one level, and free multiple-level excavation. One-level-only implementation does not satisfy the final requirement |
| affected_lore | `[LORE-U08, LORE-U09, LORE-C17]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required owning changes in GDD, UI, architecture, balance and asset contracts |
| mechanical_change | Required expansion beyond current single-floor placement: vertical topology, excavation commands, work/material accounting, access links, terrain/cutaway rendering, save identity, capacity and performance qualification. Exact rules remain an engineering deliverable, not silently inferred values |
| remaining_questions | `[]` for method availability and interoperability, now confirmed by DEC-031. Finite depth/capacity, stairs/ramps, hazards and exact costs still require engineering specifications |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-029/proposed one-underground-level-only recommendation]`; that recommendation was never user-approved |
| provenance_boundary | Free excavation is approved gameplay scope; it does not prescribe voxels, unlimited depth, continuous terrain resolution, or a separate simulation implementation for each method |

### DEC-011 — Serious consequences and grief

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Serious consequences and grief” |
| interpretation | Death, injury and failure matter to surviving residents and the player's sense of responsibility |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Show loss with dignity and clear causality; acknowledge the affected people and the community's continued life. Do not trivialize death or equate seriousness with inflated penalties |
| affected_lore | `[LORE-U10, CULT-006]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future authored notices, memorials and sound briefs |
| mechanical_change | Existing death, grief, memory and recovery values remain numeric owners; no added mood penalty, scripted mortality, compulsory funeral cost or altered loss condition |
| remaining_questions | `[DEC-014, DEC-027]`; mourning customs and broader graphic-content ceiling; DEC-033 now settles non-graphic child survival vulnerability. Current non-graphic draft treatment remains an agent proposal, not a direct user decision |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-011/open emotional treatment]` |

### DEC-015 — Visible everyday family and age diversity

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Visible everyday community life” |
| interpretation | In response to the families/children/elders question, these belong visibly in ordinary settlement life; a prose-only mention of distant families is insufficient |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Author recognizable family and intergenerational routines in inhabited spaces. Specify the representation and simulation model before claiming support. Do not silently retain an exclusively adult-looking settlement as complete coverage |
| affected_lore | `[LORE-U11, LORE-C11]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required population, UI, animation and asset follow-through |
| mechanical_change | Required visible community content beyond the current adult-only baseline. This answer alone does not authorize births, aging, reproduction, dependency rates, marriage systems, child labor or child mortality mechanics |
| remaining_questions | `[DEC-014, DEC-027]`; mourning and broader content boundaries plus exact household/routine contracts. DEC-032 confirms dependents and DEC-033 their survival vulnerability |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-015/open visibility choice]` |

### Round 5 — Two decisions and requested advice

| ID | User wording | Status |
|---|---|---|
| DEC-031 | “All methods work together.” | `USER_CONFIRMED` |
| DEC-032 | “What do you recommend?” followed by “That works for me” | `USER_CONFIRMED` following the dependent-resident recommendation |
| DEC-030 | “Truth uncertain” | `USER_CONFIRMED` |

### DEC-031 — Interoperable underground construction

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “All methods work together.” |
| interpretation | Complete burrows, room/tunnel planning and multiple-level excavation can be used together in the same settlement |
| scope | `[RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | A placed burrow can be extended with planned rooms/tunnels and connected through valid vertical access to deeper excavated space. No mutually exclusive start mode or separate save is required to change methods |
| affected_lore | `[LORE-U09, LORE-U12, LORE-C17]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required underground GDD/UI/architecture/balance/asset follow-through |
| mechanical_change | Shared authoritative spatial connectivity, reservations, services and saved state across tools; exact packed schemas, geometry, costs and capacities remain engineering work |
| remaining_questions | `[]` for interoperability; legal connection geometry and occupied-space editing require concrete specification |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-031/open interoperable-versus-exclusive choice]` |

### DEC-030 — Uncertain supernatural truth

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Truth uncertain” |
| interpretation | Preserve uncertainty about the supernatural origin of rare meaningful guidance; characters may interpret it differently |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Present experiences and attributed beliefs without omniscient confirmation or debunking. Do not introduce a hidden authorial true/false verdict, an objective miracle label or a proven supernatural modifier |
| affected_lore | `[LORE-U06, LORE-U13, LORE-C12]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future event/codex/chronicle content |
| mechanical_change | No new powers or belief stats. Event occurrence can be deterministic and saved while its fictional cause remains uncertain; event outcomes must still be precisely specified |
| remaining_questions | Exact events and character viewpoints; mixed story delivery now confirmed under DEC-022; canonical portrayals require source/era review |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-030/open supernatural certainty]` |

### DEC-032 — Adopted dependent-resident family model

Brendan initially requested advice, then answered “That works for me” to the recommendation. The model is now `USER_CONFIRMED`; adoption establishes design and release scope, not missing implementation math.

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “That works for me” |
| interpretation | Adopts the immediately preceding dependent-resident recommendation, including shared care, active elders, family starts/immigration, population accounting and fixed first-release life stages |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; births and aging are separate later specification work |
| operative_rule | Implement children as dependents with real needs and play/learning routines; adults share care; elders retain individual roles; all simulated people count within existing caps |
| affected_lore | `[LORE-U11, LORE-U14, LORE-C11]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required GDD, UI, balance, architecture, save, initialization and asset revisions |
| mechanical_change | Required dependent-resident extension. Preserve existing numeric rules as the baseline until an exact family amendment supplies changed schemas, quantities, schedules and validation; adult-only coverage does not satisfy the adopted final scope |
| remaining_questions | `[DEC-014, DEC-027]`; family/mourning customs and wider portrayal limits; child vulnerability is confirmed under DEC-033 and exact family engineering remains required |
| revisit_trigger | Revisit birth/aging scope when planning the later lifecycle feature, before its implementation; no date or recurring reminder is set |
| supersedes | `[DEC-032/revision-0.7 proposed family model]` |
| provenance_boundary | The previous agent recommendation is adopted within its described scope; no new hunger multiplier, care workload or child danger rule was supplied by the user |


| Area | Adopted direction | Reason / boundary |
|---|---|---|
| Children | Real dependent residents with food, bed, warmth, health, social and care needs; visible play, learning and shared meals | Their presence affects decisions and makes care visible; avoid decorative children whose needs never count |
| Adult caregivers | Named household/care relationships, with care shared among available adults and a community fallback | Avoid assigning all care to one gender, assuming kinship from surname, or making a single guardian's loss delete a child's support network |
| Child activities | No ordinary productive labor assignments, hazardous expeditions or excavation jobs; play/learning use a separate routine policy | Children do not become cheap replacement workers; a visible helping animation must not secretly create inventory or production XP |
| Elders | Full residents with individual skills and chosen roles, including optional storytelling, teaching and care | Age alone does not imply helplessness or a universal productivity penalty |
| Initial release population | Authored households in scenario starts and family-aware immigration; life stage remains fixed for the scenario | Makes visible family life possible without requiring childbirth, aging or generational turnover to be complete |
| Later lifecycle work | Births, aging, adulthood transitions and death by age require a separate explicit decision and complete rules | Fixed first-release life stages are now adopted; later lifecycle implementation requires a separate scope decision and complete rules |
| Population accounting | All simulated people, including children and elders, count toward the existing 256 living cap and 512 resident slots | No free secondary population; household admission must account for all members before acceptance |
| Safety and loss | DEC-033 now confirms illness, injury and possible death from survival hazards, with clear warnings, rescue opportunities and non-graphic presentation | Exact hazard/needs/care values remain required; no hazardous work assignment or combat system is added |
| ECS representation | Extend shared resident data with tightly budgeted life-stage, household and care references; retain the crowd rendering path | Do not build a separate Node hierarchy or unbounded object graph for each family |

The adopted release model has fixed life stages: play/learning do not imply a promised adulthood transition during the initial scenario. That tradeoff must be visible in the scenario description. New hunger multipliers, care work, schedules, household capacities, elder modifiers and relationship bonuses are deliberately not fabricated as inherited values.

Before implementation, the adopted model requires an exact dependent-resident rules amendment covering needs/consumption, valid beds, care scheduling and fallback, household initialization/admission, family separation/loss, save schemas, UI forecasts, caps and integration tests. Full households are not added to the current rat petition or refuge initialization without a concrete, versioned initialization/admission amendment.

### Round 6 — Answers and requested visual comparison

| ID | Decision needed | Recommendation, not adoption |
|---|---|---|
| DEC-033 | Can children become ill, be injured and die from survival hazards; suffer illness/injury but always recover; or remain protected from all such harm? | Serious survival consequences, clear warnings, rescue opportunities and non-graphic presentation; never assign children hazardous work |
| DEC-012 | What place should humor have alongside grief and danger? | Warm everyday humor; the offered antagonist nuance remains a separate authoring question |
| DEC-018 | Which direction should lead the detailed 3D art? | Textured storybook realism: expressive animals, tactile materials and believable woodland homes |

Brendan answered “1. Your recommendation / 2. Warm everyday humor / 3. Can you describe the differences between each a bit more”. The first answer adopts the offered child-vulnerability recommendation; the second adopts everyday warmth in humor. The third requests explanation, not an art selection. The earlier recommendations above are retained as the questions originally offered.

### DEC-033 — Serious, non-graphic child survival vulnerability

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Your recommendation” |
| interpretation | Adopts the recommended first option: children can become ill, be injured and die from survival hazards, with clear warnings, rescue opportunities and non-graphic presentation |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; current mechanical application is settlement survival |
| operative_rule | Model consequences through specified survival systems; communicate unmet needs and danger; provide defined care/rescue opportunities. Never assign children hazardous work or stage graphic depictions of their injury/death |
| affected_lore | `[LORE-U14, LORE-U15, LORE-C11]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; dependent-resident GDD/UI/balance/save/validation contracts |
| mechanical_change | Family amendment must define child hazard exposure, prevention, warning thresholds, rescue eligibility and treatment/death outcomes. No arbitrary mortality roll, scripted death quota, new combat system or inherited adult coefficient is authorized by this policy alone |
| remaining_questions | `[DEC-014, DEC-027]`; mourning customs and wider content boundaries; exact child survival math remains engineering work |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-033/open child vulnerability]` |

### DEC-012 — Warm everyday humor

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Warm everyday humor” |
| interpretation | Everyday community life includes affectionate character humor and familiar small mishaps |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Draw humor from personality, food, friendships and ordinary routines; preserve dignity around grief, hunger, injury and care. Do not make every resident a gag character or force jokes into warnings |
| affected_lore | `[LORE-U16, LORE-C10]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; dialogue, chronicle, animation and sound briefs |
| mechanical_change | None; humor is an authored presentation policy, not a mood bonus or random joke-generation system |
| remaining_questions | `[DEC-013, DEC-027]`; antagonist-specific humor and broader boundaries. DEC-017 now confirms light dialect. The shorter answer does not adopt the entire offered antagonist policy |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-012/open everyday humor]`; legacy absolute restrictions on antagonist humor remain unadopted |

### DEC-018 — Adopted storybook and grounded-realism blend

Brendan selected “A combination of 1 and 3 appropriately combined”, referring to textured storybook realism and grounded fantasy realism. The comparison below is retained as decision context; the adopted record and bible §14.7 govern subsequent asset work.

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “A combination of 1 and 3 appropriately combined” |
| interpretation | Blend textured storybook expression and atmosphere with grounded fantasy anatomy, materials, construction and lighting |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Apply the domain-specific art direction in bible §14.7. Keep expressive, readable characters in a materially believable world; this is one coherent art direction, not a toggle between incompatible styles |
| affected_lore | `[LORE-U17]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; Blender briefs and future asset/look-development contracts |
| mechanical_change | Presentation policy only. Existing scales, geometry, rigs, atlases, crowd paths and performance gates remain the numeric owners; no new renderer or fidelity budget follows automatically |
| remaining_questions | `[DEC-020]`; specific cultural materials plus exact audio-production/runtime choices; broad sound blend is confirmed under DEC-021. DEC-019 confirms recognizable anatomy; exact size ratios remain engineering/art work. All 28 supplied screenshots now have individual visual reviews and direct model-reference assignments in docs/art-reference; neutral turnarounds, exact species sizes and production models remain to author |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-018/open art choice, DEC-018/storybook-only recommendation]` |
| provenance_boundary | The blend is user-approved. Its domain allocation and review procedure are NEW art-direction decisions authored here; no numerical blend percentage or canonical reproduction is claimed |

All three options are directions for the same detailed 3D game. The comparison below is `[NEW design explanation]`, not verified imagery from the books or a hardware/performance result.

| Aspect | Textured storybook realism | Painterly miniature | Grounded fantasy realism |
|---|---|---|---|
| Overall impression | A richly illustrated woodland story brought into 3D | A handcrafted model settlement viewed from above | A physically plausible animal-inhabited world |
| Characters | Expressive eyes, brows and poses; modest shape exaggeration; species anatomy remains recognizable | Strong simplified silhouettes, broader color areas and deliberately sculpted detail | More naturalistic anatomy, restrained expression and finer surface detail |
| Buildings | Believable stone, timber, plaster and earth, with authored irregularity and character | Compact readable masses, sculpted roof/stone forms and painterly surfaces | Convincing construction, material weathering and less exaggerated proportions |
| Lighting/color | Curated seasonal palettes and warm inhabited interiors; natural logic with artistic emphasis | Strong visual grouping and light/color separation; miniature effect need not rely on blur | More naturalistic light/material response; neutral and dramatic scenes both possible |
| Same burrow doorway | Worn round timber door, textured moss, warm windows and a readable family gathering | Sculpted earth mound, broad painted greens and a clear arrangement of tiny figures | Detailed packed earth, roots, damp stone, restrained silhouettes and natural light falloff |
| RTS-camera priority | Readable species, roles and personality while retaining texture | Clear construction shapes, paths and resident silhouettes | Readability must be protected from fine detail, similar material values and subtle expressions |
| Main art risk | Excessively cute faces or decorative clutter can weaken the intended seriousness | Toy-like proportions, visible brushwork or forced shallow focus may weaken the feeling of inhabited scale | Fine detail may disappear at play distance; naturalistic faces may need stronger pose design to communicate emotion |

The original storybook-only recommendation is superseded by the selected combination of options 1 and 3. The choice does not adopt the painterly-miniature direction, a miniature camera effect or new shader/texture/polygon budgets. The exact combined direction is specified in bible §14.7.

### Round 7 — Recorded answers

| ID | Decision needed | Recommendation, not adoption |
|---|---|---|
| DEC-019 | How should animal proportions and relative sizes work? | Recognizable animal anatomy and expressive faces, with sizes adjusted enough for shared usable spaces; exact size ratios remain to specify |
| DEC-017 | How much dialect should characters use? | Distinct voices with light dialect and readable dialogue; functional UI remains plain |
| DEC-025 | How closely should scenarios follow Redwall history? | Begin canon-based scenarios from verified history, allowing clearly labelled alternate outcomes from player actions |

Brendan answered “1. Recognizable animal anatomy / 2. Distinct voices with light dialect / 3.bits of all three”. These are adopted within the scopes below. The third answer permits selective combinations of the offered continuity approaches; it does not mandate three new menu modes or every possible departure in every scenario.

### DEC-019 — Recognizable animal anatomy

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Recognizable animal anatomy” |
| interpretation | Characters retain readable species anatomy within the approved storybook/grounded-realism blend |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Preserve distinctive head/muzzle/beak, ears, limb/paw or wing structure, tail and body silhouette; adapt expression, clothing and tool poses without erasing species identity |
| affected_lore | `[LORE-U17, LORE-U18]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future species sheets and animation contracts |
| mechanical_change | None from this answer alone; anatomy does not grant flight, swimming, climbing, innate digging or a navigation bypass |
| remaining_questions | Exact relative species sizes, biped/quadruped pose conventions, age-stage proportions and shared-space dimensions; current approved scale remains the baseline until those sheets exist |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-019/open recognizable-anatomy choice]` |
| provenance_boundary | The shortened answer does not adopt either real-world size ratios or the full offered size-normalization recommendation |

### DEC-017 — Distinct voices with light dialect

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Distinct voices with light dialect” |
| interpretation | Different people sound distinct through rhythm, vocabulary, attitude and restrained regional/cultural phrasing |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Keep dialogue readily understandable; use light dialect without heavily phonetic spelling. Each authored voice has individual interests and habits; species does not determine one shared personality |
| affected_lore | `[LORE-U19]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future dialogue and resident-copy briefs |
| mechanical_change | None; distinct written voices do not approve full voice acting, procedural dialogue, branching conversation or a new personality simulation |
| remaining_questions | Exact authored story/audio delivery; broad surfaces now confirmed under DEC-022; naming and broad sound direction are confirmed under DEC-016/021; specific dialect registers need source-aware authored examples |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-017/open dialect intensity]` |

### DEC-025 — Selective canon fidelity and departures

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within broad adaptation direction |
| answered_on | 2026-09-06 |
| user_wording | “bits of all three” |
| interpretation | Combine preservation of important established facts/outcomes, alternate outcomes from player actions and freer authored reinterpretation where appropriate; no one rule governs every aspect of every scenario |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Each scenario identifies verified anchors, any protected outcomes, changeable outcomes and explicit original departures. Present inventions as game adaptations; require coherent geography, cast and chronology inside the selected scenario |
| affected_lore | `[LORE-U20, LORE-C16]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; concrete scenario and objective contracts |
| mechanical_change | No automatic event rewrites or new selection UI. Protected outcomes and alternate branches need exact scenario rules; do not secretly override simulated agency to force an ending |
| remaining_questions | `[DEC-003, DEC-004, DEC-023, DEC-026]`; exact cast/era, protected facts, permitted departures, completion conditions and campaign relationships per scenario |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-025/open broad fidelity choice]` |
| provenance_boundary | The policy allows flexibility; it does not classify all past inventions as approved canon or require three mutually exclusive game modes. Exact continuity records below are NEW authoring procedure |

### Round 8 — Recorded answers

| ID | Decision needed | Recommendation, not adoption |
|---|---|---|
| DEC-016 | What naming traditions should shape the world? | A broad mix of personal, descriptive and place-related names, differing by culture |
| DEC-007 | What should meals and feasts primarily express? | Hospitality, gratitude and seasonal traditions |
| DEC-021 | What should music and sound emphasize? | Intimate acoustic music, woodland ambience and occasional communal singing |

Brendan answered “1. A mix of these blended appropriately / 2. All of the above / 3. A mix of all of these”. Each refers to the corresponding question above. The blend is adopted; its content allocation below is an authored interpretation, not a new numeric simulation rule.

### DEC-016 — Blended naming traditions

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “A mix of these blended appropriately” |
| interpretation | Combine personal, descriptive, place-related and woodland/nature names, with cultural variation and meaningful titles or earned nicknames |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Curate coherent names per community and individual; titles reflect an actual office and earned names an authored or recorded basis. Do not require every name to contain all categories or assign naming traits mechanically by species |
| affected_lore | `[LORE-U21, LORE-C07]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; subsequent named catalogs and identity presentation briefs |
| mechanical_change | No silent replacement of current 32-entry name arrays, selection algorithm, alias limits or notability rules. Culture-bound selection or dynamic nickname awards require a versioned catalog/UI/save amendment |
| remaining_questions | Exact cultural name lists, named casts and nickname provenance; always-visible names versus current notability display remain separate UI work |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-016/open naming register]` |

### DEC-007 — Layered feast meanings

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within feast meaning |
| answered_on | 2026-09-06 |
| user_wording | “All of the above” |
| interpretation | Meals and feasts express hospitality, gratitude, seasonal tradition, survival, shared achievement, community identity, alliances and obligations |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Give each authored occasion a concrete reason, participants and social context. Meanings can overlap; routine meals and major celebrations need not express every purpose simultaneously |
| affected_lore | `[LORE-U22, CULT-001, CULT-005]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future feast copy and scenario event briefs |
| mechanical_change | Current recipes, eligible attendance, costs, service, success, buffs and cooldowns remain owned by the GDD/amendment. Alliance/obligation themes do not add diplomacy, contracts, tribute or new rewards |
| remaining_questions | `[DEC-014]`; concrete customs, book-specific dishes, beverage/alcohol presentation, guests and meaningful scarcity choices |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-007/open feast meaning]`; culinary and beverage subquestions remain unanswered |

### DEC-021 — Contextual acoustic, ambient and orchestral sound

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within sound direction |
| answered_on | 2026-09-06 |
| user_wording | “A mix of all of these” |
| interpretation | Combine intimate acoustic music, woodland ambience, occasional communal singing, stretches of environmental sound with sparse music, and fuller orchestral adventure scoring |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; specific cues belong to their supported scenes |
| operative_rule | Use scene-appropriate emphasis over shared musical identity; silence and environmental detail have an intentional place. Orchestral scale should serve meaningful events rather than run constantly over daily life |
| affected_lore | `[LORE-U23]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future music, ambience, audio-runtime and performance briefs |
| mechanical_change | No middleware, voice-acting scope, per-resident emitter, new gameplay event or numeric bus/stream budget is implied. Exact triggers, transitions, priorities and limits require an audio contract |
| remaining_questions | Instrument/voice palette, original motifs and singing content, voice acting scope, accessible cue presentation, playback/stream/memory budgets |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-021/open music/sound emphasis]` |

### Round 9 — Recorded answers

| ID | Decision needed | Recommendation, not adoption |
|---|---|---|
| DEC-022 | How should players discover history and stories? | Environmental detail and resident stories, supported by a readable chronicle/codex |
| DEC-023 | What does the Hearth Charter mean in the current Rowan's Refuge scenario? | A promise written by the community after demonstrating it can sustain and care for its people |
| DEC-013 | What distinguishes future antagonist groups? | Different motives and cultures, combining survival, ambition, loyalty, conquest and cruelty differently |

Brendan answered “1. A mix of three where appropriate / 2. Your recommendation / 3. A mix of all three to ensure variety in gameplay”. The answer adopts the story blend, the recommended community-written Charter for the current Refuge, and varied antagonist motives/scales. These decisions do not silently turn future campaign/battle systems into implemented settlement features.

### DEC-022 — Mixed story delivery suited to the moment

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “A mix of three where appropriate” |
| interpretation | Combine environmental details, resident stories, chronicle/codex entries, optional descriptions, authored events, dialogue and scenario objectives |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; individual content/features retain their scenario and release bindings |
| operative_rule | Use environment and short contextual text for everyday discovery; authored events/dialogue/objectives for consequential moments; optional descriptions and a readable chronicle/codex for deeper context. Keep essential action information available without mandatory lore reading |
| affected_lore | `[LORE-U24]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required story-surface UI/content/save contracts |
| mechanical_change | Codex and any new event/dialogue interaction require explicit UI IDs, data, reveal/trigger rules, saved state and validation. Current chronicle/notices stay bound to committed events; no duplicate simulation rewards across surfaces |
| remaining_questions | `[DEC-017, DEC-021]` exact written/audio delivery details; concrete UI layouts, event scripts and unlock rules still need authoring, despite those broad voice/sound directions being confirmed |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-022/open story surface selection]` |

### DEC-023 — Rowan’s Refuge writes its own Hearth Charter

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “Your recommendation” |
| interpretation | Adopts a promise the community writes together after demonstrating that it can sustain and care for its people |
| scope | `[RELEASE_1, PRESENTATION]`; specifically the current Rowan’s Refuge scenario |
| operative_rule | Present the Charter as the community’s own civic commitment. Redwall Abbey or a regional authority is not its required issuer. It acknowledges collective care and continued responsibility rather than making Rowan sole author/owner |
| affected_lore | `[LORE-U25, LORE-C13]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; completion copy, monument brief and chronicle text |
| mechanical_change | None to current M4 thresholds, award timing, completion pause, cosmetic monument or same-save continuation. Any future family or scenario amendment must explicitly reconcile thresholds rather than imply new ones through this fiction |
| remaining_questions | `[DEC-014]`; exact ceremony, final text, community symbols and participants; other scenarios still specify their own completion meaning |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-023/open current-Refuge granting authority]` |

### DEC-013 — Varied antagonist motives and scales

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within antagonist direction |
| answered_on | 2026-09-06 |
| user_wording | “A mix of all three to ensure variety in gameplay” |
| interpretation | Include groups with different motives/cultures, larger conquering powers and the groups reacting to them, and local/personal rivals where large organized threats are less common |
| scope | `[WORLD, FUTURE, PRESENTATION]`; campaign/battle behaviors remain separately scoped |
| operative_rule | Vary conflict scale and motive by region/scenario so opposing groups create distinct decisions and pressures. A local-focused scenario need not also contain a dominant empire; one conquering power need not explain every conflict in the world |
| affected_lore | `[LORE-U26]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future faction/campaign/battle contracts |
| mechanical_change | Required differentiation in eventual supported behaviors, not only names and appearance. Exact objectives, resources, triggers, responses, negotiation/combat rules and limits must be specified for each implemented group |
| remaining_questions | `[DEC-004, DEC-026, DEC-027]`; named groups, era/geography, threat frequency, campaign relationship, antagonist-specific humor and content boundaries |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-013/open broad threat model]`; the legacy rat warlord, homeland and permanent camp remain unselected examples |
| provenance_boundary | Diverse motives do not establish species-based morality or imported canonical villains. Scope variety does not require every scenario to use every antagonist type simultaneously |

### Round 10 — Recorded answers and reference refinement

The user retains whole-series context and names Redwall, Mossflower, The Long Patrol, Salamandastron, Eulalia! and Lord Brocktree for closer guidance. The answers to the current Refuge questions are “An experienced mouse keeper”, “displaced”, and “torture and cruelty towards children”. The shorter answers settle only the details explicitly stated.

### DEC-034 — Six-book primary reference focus

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “While the series as a whole should still be relied on for context, Redwall, Mossflower, The Long Patrol, Salamandastron, Eulalia, Lord Brocktree can help provide more guidance to narrow in on.” |
| interpretation | Use these six as the main creative focus, retaining the full series as supporting context |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Apply bible §3.2’s reference map. Inside the Redwall creative source tier, consult the six focus books first for relevant anchors, then other novels for additional context; current project and legacy gap sources retain their lower positions |
| affected_lore | `[LORE-U27]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; every future feature, scenario and asset context capsule |
| mechanical_change | None. This is reference emphasis, not six commissioned campaigns, a single shared era, or permission to bypass adopted gameplay/content boundaries |
| remaining_questions | Specific era/cast anchors and verified maps for each concrete scenario remain open. Lord Brocktree now has a complete supplied-text reading and eleven additional novels have targeted passage studies; no complete illustration review has been performed |
| revisit_trigger | `NONE` |
| supersedes | No supersession of DEC-024; this refines focus within its whole-series scope |
| provenance_boundary | User supplied the book selection. The guide’s thematic allocations are agent interpretations based on narrow publisher evidence, not user-ranked percentages or claims of exhaustive novel analysis |

### DEC-003 — Rowan is an experienced mouse keeper

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within current Refuge identity |
| answered_on | 2026-09-06 |
| user_wording | “An experienced mouse keeper” |
| interpretation | Rowan is an original mouse character with an established practical keeper background |
| scope | `[RELEASE_1, PRESENTATION]`; current Rowan’s Refuge scenario |
| operative_rule | Use mouse anatomy and a keeper’s role for Rowan; retain the existing Warden display identity, persistent ID 1, KEEP level 3 and succession rules. “Experienced” describes the background, not extra unlisted stats |
| affected_lore | `[LORE-U28, LORE-C05]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; final Refuge initialization and Rowan asset/biography sheet |
| mechanical_change | Final initialization must bind ID 1 to mouse within the existing six-mouse cohort, rather than adding a thirteenth adult. Full scenario/family initialization remains a separate required revision |
| remaining_questions | Pronouns, exact life stage, appearance, prior home, relationships and defining experiences. Compassion/dependability and reluctance to delegate from the offered option remain PROPOSED, because the user repeated only species/occupation/experience |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-003/open Rowan species and occupation]`; other scenario protagonists remain independently authored |

### DEC-002 follow-through — Displacement founded Rowan’s Refuge

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` within the current Refuge’s founding premise |
| answered_on | 2026-09-06 |
| user_wording | “displaced” |
| interpretation | The community is making a lasting home after displacement; it is not merely an unmotivated settlement expedition |
| scope | `[RELEASE_1, PRESENTATION]`; current estuary Refuge |
| operative_rule | Frame the Refuge as rebuilding a home and community after displacement. Do not invent a named war, villain, burned village, abusive captivity, travel route or canonical event to supply its cause |
| affected_lore | `[LORE-U29, LORE-C15]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; opening scene and exact scenario/family initialization |
| mechanical_change | No invented losses, migration penalties or free aid inventory. Existing completed hall and inventory remain the baseline; its pre-play construction and provision history still needs authoring |
| remaining_questions | `[DEC-004]`; cause of displacement, original homes, route, timing, why this site, who built/supplied the hall and who belongs to which household. Volunteers were offered but not explicitly confirmed |
| revisit_trigger | `NONE` |
| supersedes | Current-Refuge unknown founding premise only; all other approved starting-premise families remain required |

### DEC-027 — Named content boundaries; treatment clarification pending

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` boundary subjects; `OPEN` treatment |
| answered_on | 2026-09-06 |
| user_wording | “torture and cruelty towards children” |
| interpretation | The user names torture and deliberate cruelty toward children in response to a question asking what should be excluded or kept offscreen |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Do not depict torture or deliberate cruelty toward children. Pending clarification, keep both out of new backstory, offscreen events and implied threats as a conservative authoring guard; this broader guard is an agent interpretation, not a recorded user selection between the two treatments |
| affected_lore | `[LORE-U30]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future writing, events, codex, audiovisual and antagonist briefs |
| mechanical_change | No torture mechanics or authored child-abuse actions. DEC-033’s non-graphic survival illness/injury/death remains separately approved; do not recast accidental deprivation or weather exposure as deliberate punishment |
| remaining_questions | Whether these subjects are excluded entirely or may be mentioned in restrained offscreen/past references. Clarification asked; no automatic interpretation of elapsed time as an answer |
| revisit_trigger | User clarification updates the guard; otherwise affected material remains unwritten |
| supersedes | Previously unconstrained treatment of these two subjects; other content boundaries remain independently scoped |

### Current follow-through

The single active clarification asks whether torture and deliberate cruelty toward children are excluded entirely, including backstory/offscreen events, or may receive restrained offscreen references without depiction. The recommendation is complete exclusion. Independent source, Rowan and founding work continues while this is pending.

### 4.3 Emotional range and difficult content

| ID | Main question | Stress-case follow-up | Existing behavior and change implications |
|---|---|---|---|
| DEC-011 | How should loss, injury and failure feel and look? What is the upper limit for visible violence or distress? | After a preventable winter death, should the player experience grief, accountability, fear, practical recovery, or some combination? Would seeing the body help the story or undermine the tone you want? | Confirmed: serious consequences and grief. Visual intensity remains open; non-graphic treatment is the draft default. Existing numeric consequences remain unchanged |
| DEC-012 | How much humor belongs in danger and among antagonists? Should villains ever be absurd, charming, incompetent or pitiable? | Can a raider be funny in one scene and frightening in the next? Which kind of humor would trivialize the people at risk? | Legacy “never comic” is unconfirmed here. Release 1 has no raider system; this establishes future tone and current narrative restraint |
| DEC-013 | What drives the long-term antagonists: conquest, cruelty, survival, loyalty, status, or a different motive for each group? Should the legacy rat warlord and permanent camp survive as a proposal? | Is the present threat new, cyclical, or the result of something the woodland community did? Could peace work, and what would make a particular antagonist reject it? | Varied motives/scales confirmed; named antagonist groups remain unselected. Legacy homeland/raiding culture is a candidate, and faction behavior remains future scope |
| DEC-015 | How important are families, children, elders, romance and generational change to the world you want, even if some stay outside release 1? | Would an adults-only playable community feel incomplete? Can offscreen families be mentioned without implying missing playable dependents? What should “a home for future generations” mean during the current three-year objective? | Confirmed: visible everyday family life. The adult-only GDD is an identified content gap; DEC-032 confirms dependent residents and fixed first-release life stages. Births/aging require separate later rules; DEC-033 confirms non-graphic survival vulnerability |
| DEC-027 | For future Redwall-style conflicts, what subjects should appear directly, be implied, or stay out: captivity, enslavement, coercion, cruelty to children, predation, betrayal and revenge? | Which subject can motivate a villain but should never become a player-controlled system? Are there any hard boundaries for the school presentation? | Torture and deliberate cruelty toward children are named boundaries; no depiction, with offscreen allowance being clarified. Other topics and formal rating remain undecided |

## 5. Specificity questions — turn atmosphere into authored content

| ID | Main question | Follow-up that forces specificity | Existing behavior / dependency |
|---|---|---|---|
| DEC-014 | Which three customs would make this community recognizable: welcoming meals, seasonal names, communal repair days, storytelling, memorials, orchard planting or something else? | Who performs each custom, what object or place matters, and what happens when the custom cannot be afforded? Which is shared with Redwall Abbey and which is local? | Candidate customs CULT-001–006 in the bible add no mechanics. New events need conditions, costs, timing and UI only if they become gameplay |
| DEC-016 | What should names sound like? Should cultures have different naming traditions, and should every resident have an everyday name even before the UI marks them notable? | Should Rowan remain? Give two names you like and two you dislike. Are titles earned, inherited, occupational or optional? | GDD already supplies ordered 32-entry given/surname arrays and naming triggers. Blended naming is confirmed; revised culturally curated arrays and always-named UI require explicit follow-through |
| DEC-017 | How much dialect, dialogue and literary narration do you want: lightly flavored descriptions, readable dialogue, or strongly differentiated speech? | Would a phonetic mole paragraph delight or frustrate you? Should clicking a worker reveal personality, or should it emerge mainly from actions? | Confirmed: distinct voices with light dialect; plain functional UI. Branching dialogue, barks and voice systems still need separate contracts |
| DEC-018 | Which visual direction should lead: textured storybook realism, painterly miniature, grounded detailed fantasy, or a specific Redwall illustration/animation reference? | At the normal RTS camera, what must be recognizable first: species, job, personality or clothing? Which visual treatment would look too childish or too grim? | Confirmed: storybook/grounded-realism blend under §14.7. Proportion policy and selected reference assets remain separate; detailed 3D/crowd budgets still govern |
| DEC-019 | How animal-like should bodies, movement and relative scale feel? What must be true of birds, moles, otters and badgers even when release 1 uses ground paths? | Is a kestrel using the same hall credible? Are adapted perches and poses enough for now? Would a walking bird resident feel worse than delaying that species? | Recognizable anatomy confirmed; prototype mouse remains 1.0 m gameplay scale. No new species heights, flight, swimming or innate tunneling are decided here. Changing the roster affects DEC-005 |
| DEC-020 | What architecture, clothing and material details should signal culture, occupation and history? | What would make a kitchen unmistakably part of this game with no characters present? Are clothes mostly practical, ceremonial, individually repaired, or tied to institutions? | Three architecture kits have equal gameplay properties. Material/style choices must fit current footprints and asset budgets |
| DEC-021 | What should the game sound like: environmental quiet, melodic acoustic music, communal singing, voiced characters, or a chosen mixture? | Which sound would make you feel safe inside the hall? Should winter mostly change music, ambient sound, silence, or all three? Are there specific performances or soundtracks you want examined? | Broad acoustic/ambient/singing/quiet/orchestral blend confirmed; exact ensemble, voice budget and dynamic audio implementation remain to specify |
| DEC-022 | How should players discover lore: item descriptions, a chronicle, residents, a codex, environmental storytelling, or authored events? | What should a player who skips all text still understand? What valuable detail should reward someone who reads everything? | Mixed story surfaces are approved. Chronicle/notices exist in current specs; codex and new event/dialogue interactions require explicit UI/content/save specifications |
| DEC-023 | What does the Hearth Charter mean in the fiction, and who recognizes it? | Is it self-authored proof of belonging, recognition from Redwall Abbey, a regional compact, or something else? What changes emotionally after it is earned? | Current Refuge Charter is a community-written promise under DEC-023. Existing completion rules remain unchanged; no external granting authority or political dependency is added |
| DEC-025 | What can this project deliberately change about Redwall while still feeling right to you? | Would changed species allegiance, original foods, a flexible chronology or practical game-scale architecture be acceptable? Which exact things are untouchable? | Selective flexibility is confirmed; each scenario must state exact anchors, changeable outcomes and deliberate departures under bible §7.6 |
| DEC-026 | What should the world promise about the eventual campaign and battles while release 1 remains a settlement game? | Which future institution, danger or mystery should be foreshadowed now? Which would create distracting expectations before it can be built? | Three-layer vision remains; no campaign/combat in release 1. Foreshadowing may not masquerade as an available feature |

## 6. Decision dependencies

```text
DEC-000  Source priority [CONFIRMED]
    |
    +--> DEC-001 + DEC-002 + DEC-024  Variety / premises / whole series [CONFIRMED]
    |         |
    |         +--> DEC-028  All option families in first release [CONFIRMED]
    |         +--> DEC-003 + DEC-004  Per-scenario cast / era / geography
    |
    +--> DEC-005 + DEC-006 [CONFIRMED] --> DEC-007 feast meanings [CONFIRMED; specific dishes/drinks open]
    |         |
    |         +--> potential GDD + catalog + UI revisions
    |
    +--> DEC-008 + DEC-009 + DEC-010 [CONFIRMED within scope]
    |         +--> DEC-029 [CONFIRMED all construction methods]
    |         +--> DEC-030 + DEC-031 [CONFIRMED]
    |         +--> DEC-032 [CONFIRMED family model]
    |         +--> DEC-033 [CONFIRMED child vulnerability]
    |         +--> DEC-003 [OPEN details]
    |
    +--> DEC-011 + DEC-015 [CONFIRMED emotional/visible scope]
    |         +--> DEC-012 [CONFIRMED everyday warmth]
    |         +--> DEC-027 [OPEN wider boundaries]
              |
              +--> DEC-013 + DEC-026  Future conflict / promises

Chosen foundation --> DEC-014 + DEC-016..023 + DEC-025
                       Customs / names / presentation / adaptation limits
```

This is a dependency guide, not a fixed questionnaire order. A strong answer may close parts of several decisions; record each separately to avoid losing the connection.

## 7. Exact answer-record schema

Each decided item shall have one Markdown subsection `### DEC-nnn — title` and the following field table. The schema below defines required values; it is not a list of instructions to leave blank in a finished decision.

| Field | Type / allowed values | Meaning |
|---|---|---|
| `status` | One decision state from §2 | Current disposition |
| `answered_on` | ISO date `YYYY-MM-DD` | Date of user's answer or delegated resolution |
| `user_wording` | Text; exact relevant statement | Direct evidence; avoid paraphrase labelled as a quote |
| `interpretation` | Text | What the agent understands it to mean |
| `scope` | Array drawn from `WORLD`, `RELEASE_1`, `FUTURE`, `PRESENTATION` | Where the decision applies |
| `operative_rule` | Text | What authors and implementers should now do |
| `affected_lore` | Array of `LORE-*` / `CULT-*` IDs | Content to reconcile |
| `affected_docs` | Array of repository-relative paths | Owning specs and instructions |
| `mechanical_change` | `NONE` or a concrete change proposal | Explicitly distinguish prose from rules |
| `remaining_questions` | Array of DEC IDs or precise follow-up text | `[]` means the decision is complete within its recorded scope |
| `revisit_trigger` | Text or `NONE` | Required for `DEFERRED_BY_USER` |
| `supersedes` | Array of prior decision IDs/revisions | `[]` for a first decision |

### 7.1 Change-proposal minimum

If `mechanical_change` is not `NONE`, record old behavior, chosen behavior, affected requirement/catalog IDs, save/version implications, dependent UI/asset work and validation. Do not approve a lore choice and then leave old instructions silently directing Claude to build the opposite behavior.

Completed specification reconciliation for DEC-006: identify every raw_game/hide/carcass producer and consumer; resolve alternate materials or remove dependent recipes; update job and fauna scope; re-evaluate recipe mastery and milestone attainability; update inventories, UI labels and tutorials; update numerical validation and expected outputs. SET-AMEND-001 and revised owners resolve these specification changes; full-runtime validation remains outstanding.

## 8. Unresolved facts and research follow-through

Research request, 2026-09-06: “Can you do novel analysis to get a deeper understanding?” [SET-RESEARCH-001](redwall_novel_analysis.md) records the initial bounded excerpt pass and the subsequent complete reading of the supplied Lord Brocktree narrative. Brendan supplied a local EPUB; its metadata claims a collection, but the actual contents contain only Lord Brocktree. The [dedicated study](lord_brocktree_analysis.md) and [source audit](lord_brocktree_source_audit.json) document all 40 narrative sections, passage locators, interpretation and adaptation conflicts. The [expanded package](redwall-series/README.md) now studies eleven additional user-supplied novels through 96 targeted passage records (102,954 inspected extracted words). Four of these belong to the six-book focus; seven expand its supporting evidence. None of these eleven had a complete sequential reading in that earlier pass. The later systematic library in §8.3 supersedes the current coverage status; Eulalia! still lacks full supplied text. The source audit records file identity and exact inspected ranges. This is research authorization, not adoption of its new design recommendations; no DEC record is closed. Continue independent work under existing decisions.

| Topic | Current evidence limit | How to close it |
|---|---|---|
| Exact Redwall era and cast | Multiple setting types and whole-series scope confirmed; individual eras and casts not chosen | Resolve DEC-004 for each selected scenario, then verify the relevant books and timeline relationships |
| Species morality and exceptions | The expanded passages include Romsca, peaceful water rats, Veil and Tagg alongside moralized narration and conflicting judgments; adopted admission policy remains distinct | Apply DEC-005; verify selected character examples before using them as precedents |
| Diet and sapience | The expanded corpus directly adds speaking predators and bird consumption; no complete sapience taxonomy follows, and silence still does not prove nonsapience | Use adopted DEC-006; verify any additional source-specific claims rather than rewriting the policy by assumption |
| Religion and visions | The expanded studies add concealment through clothing, the tortoise Walking Stone and consequential prophetic appointments; no universal theology or skepticism is established | Apply DEC-009 rarity/significance; apply DEC-030 uncertain truth; distinguish source text, interpretation and deliberate game invention |
| Architectural authenticity | Gameplay map and technical scale exist; no canonical measured floor plan inspected | Apply DEC-010 style variety and earth-built homes; implement DEC-029 all-method scope, apply DEC-031 interoperability and inspect scenario references before claiming fidelity |
| Preferred illustration/animation | Storybook/grounded-realism blend selected; all 28 supplied screenshots visually reviewed and assigned as direct references; creators/editions remain unidentified | Apply DEC-018/019 and docs/art-reference/model_reference_guide.md; author missing model views and verify any later source attribution |
| Rowan, founding and neighbors | Experienced mouse keeper and displaced founding confirmed; neighbors/cause/route unknown | Finish concrete DEC-003/004 records, including hall provision history; do not claim a canonical identity or location |

### 8.1 Supplied visual references reviewed

On 2026-09-06 Brendan requested detailed review of every screenshot in the project's image-reference folder, explicitly including their use as direct modeling references and special attention to tunneling, swimming and climbing. [The completed package](art-reference/README.md) records 28 inspected PNGs, 27 distinct slide compositions and 62 viewing windows. The [model guide](art-reference/model_reference_guide.md) is the direct-reference handoff; the [traversal review](art-reference/traversal_design_review.md) contains proposed interfaces, formulas, fixtures and remaining engineering decisions.

This authorizes direct-reference use and analysis; it does not turn every slide bonus, faction, era, hazard or release label into a confirmed DEC. Existing underground scope remains confirmed. Source-specific art choices are documented as observed features or authored adaptations. No gameplay value, species morality rule, Rowan biography, full campaign or completed runtime is inferred from an image.

### DEC-035 — Connected movement for ordinary settlement life

| Field | Value |
|---|---|
| Status | `USER_CONFIRMED` |
| Source | Brendan, 2026-09-06, current conversation |
| User wording | “Agreed with your recommendation on movement, let’s make sure that’s built in the right places in the various spec/md files.” |
| Adopted direction | Persistent tunnels and inhabited underground routes; surface swimming and diving with valid shore/air access; connected climbing/canopy routes for daily work and access; body, equipment and load compatibility |
| Preserved scope | DEC-029/031 all three underground methods interoperable in first release; ordinary settlement and battle stores remain separate |
| Mechanical change | SET-MOVE-001 supersedes ground-only/one-floor claims as complete product scope; old runtime remains incomplete baseline |
| Not decided | Species-wide innate permissions, exact speeds/depths/air values, sapping/traps/water combat, free flight, arbitrary jumping, new hazard penalties or production recipes |
| Save/version impact | Expanded spatial identity and traversal state require a completed versioned save contract; no new active ruleset or migration number assigned here |
| Owners | GDD, UI, balance, systems architecture, crowd/assets, validation, setting bible and agent reading order |
| Engineering remaining | MOVE-G01–05; accepted direction does not imply finished algorithms, catalogs or qualification |

### 8.2 Separate design-focused novel pass

[DESIGN-READ-SERIES-002](redwall-design/README.md) responds to Brendan's request for themes, feeling, people, factions, food, objects, places and other useful design context. Twelve supplied works receive separate studies, with 115 records and 47,139 unique extracted words inspected this pass; 36,073 lie outside previous inspected ranges. This remains targeted reading, not twelve new complete sequential readings. The earlier research is retained separately; full Eulalia text remains absent from the verified corpus. Content candidates have no automatic mechanical authority.

### 8.3 Systematic content-library pass

The [systematic content library](redwall-content-library/README.md), CONTENT-LIB-001, now records full sequential inspection of all available normalized narrative blocks in twelve supplied works: 1,280,344 words across 221 chunks. It indexes 7,665 records and 1,755 food/recipe/discourse candidates, with source ingredients separated from explicitly AI-authored game completions. The source audit retains the confirmed Salamandastron gap, apparently printed pages 314–315; full Eulalia! remains absent; the collection-labeled EPUB contains Lord Brocktree only. This is not complete-series or verified-edition certification.

Brendan requested a systematic book-by-book library for all previously named content areas and explicitly allowed AI guesses for missing recipe ingredients, then authorized parallel work. The package preserves canon lists separately from inferred ingredients and methods, exposes source-only discourse versus production candidates, and keeps all numerical recipe values inactive. This is authorization for research and labeled content completion, not a new gameplay policy or an answer to outstanding interview questions. [Decision 0014](decisions/0014-systematic-content-library-keeps-source-and-game-separate.md) records the handoff.

### DEC-036 — Supplied visual references may guide direct builds

2026-09-11 · State: `USER_CONFIRMED` for reference use.

Brendan explicitly corrected the claim that IMG-25 was limited to observation:
“We are allowed to use those images I gave you to guide direct builds in our world.”
His supplied images and material may be used directly as reference inputs for
image-to-image, image-to-3D, drawing/tracing/adaptation and modeling/texturing for
this project. This includes IMG-25 and other `ImageReference/` files, not merely
written observations of them. Record input files/regions and transformations;
keep unknown creator/edition/license fields unknown without making them an
invented observe-only restriction. This records project authorization, not a new
claim of copyright ownership, a CC license or verified source attribution.

The authorization applies to supplied material; it is not an instruction to copy
every external RTS screenshot collected as research. Source gameplay claims do
not supersede the GDD. Do not put slide UI/text or a full HUD screenshot into the
runtime as finished assets. Purpose-made asset sheets may be cut into clean
individual assets. Paid generation remains a separate itemized approval under
[the paid-asset process](design/paid_asset_process.md); no quoted spend is approved
by this reference clarification. [ART-LOCK-001](design/ui_refinement/asset_generation_lock.md)
records Astra-authored production details; final aesthetic approval remains pending.

### DEC-037 — Whole-game reference synthesis and modern RTS presentation

2026-09-11 · State: `USER_CONFIRMED` for goals and reference roles.

Brendan clarifies that Redwall material provides theme, feel, style and atmosphere;
supplied pictures provide complementary concept and construction references.
IMG-25 supplies animal outlines to combine with the other individual character
images, not an exclusive model template. All of this should become high-quality,
modern RTS visuals informed by Company of Heroes 1–3, Age of Empires, Northgard,
Total War and other suitable comparisons. Apply the approach to every visual
need, including environments, items and units. Older games are useful references
without their dated graphics being a target.

This extends the application of DEC-018/019/036; it does not settle a new renderer,
world shader, species-size ratio or asset budget. UI illustration parameters do
not automatically govern 3D world rendering. Refinement questions about finish,
camera emphasis and world/UI treatment were initially unanswered; DEC-038 below
subsequently approves the concrete world-finish example. See
[whole-game visual alignment](art-reference/visual_direction_alignment.md) for
executor instructions, reference synthesis and the proposed next review artifact.

### DEC-038 — Approved grounded, expressive 3D visual target

2026-09-11 · State: `USER_CONFIRMED` for visual direction.

Brendan answered “Yes - this is what I'm looking for” after viewing
[the mouse keeper / mole worker courtyard example](art-reference/visuals/grounded_expressive_rts_example_v1.png).
That image is the approved concrete visual reference for the DEC-018/037 blend:
expressive species-specific anatomy, composed woodland color, convincing cloth,
leather, iron, timber and stone, and an inhabited world that reads from an RTS
camera. Use its close view for character/material intent and its elevated view
for scene composition and the intended relationship between units and environment.

The world-finish question recorded in DEC-037 is now answered by this example.
Future briefs must open this image alongside relevant supplied source images and
literary context. Preserve its visual character when simplifying detail for runtime.
The image is a generated concept, not a production mesh, measured Godot render,
new species-size specification or approval of incidental gameplay content.
No new paid-generation budget is authorized. Existing UI illustration treatment
remains separately scoped; this image contains no UI and does not approve unseen
UI assets. See [visual alignment](art-reference/visual_direction_alignment.md).

## 9. Progress ledger

| Date | Work completed | Still open |
|---|---|---|
| 2026-09-05 | Read current concept/GDD/UI/asset contracts and legacy bible; inspected publisher/author reference material; wrote setting bible and agent handoff; asked Round 1 | DEC-001–027; no answers recorded yet |
| 2026-09-05, revision 0.2 | Recorded DEC-001/002/024 as confirmed variety and whole-series scope; added scenario contracts and DEC-028; asked Round 2 | DEC-003–023 and DEC-025–028; concrete scenario lineups and first-release coverage remain open |
| 2026-09-05, revision 0.3 | Recorded DEC-028 as all-options-first; supplied requested recommendations for DEC-005/006 with source limits and revision consequences | Admission and diet choices, concrete scenario lineup and remaining interview topics |
| 2026-09-05, revision 0.4 | Adopted DEC-005/006; reconciled rules v2 across GDD, UI, catalogs, architecture and validation policy; asked Round 3 | Full runtime and scenario content still outstanding; player role, belief and building form awaiting answers |
| 2026-09-06, revision 0.5 | Recorded DEC-008/009/010 within their answered scopes; added earth-built home requirement and DEC-029/030; asked Round 4 | Excavation scope, supernatural certainty, exact scenarios, content boundaries and family simulation remain open |
| 2026-09-06, revision 0.6 | Recorded all three underground methods, serious consequences/grief and visible family life; superseded the single-level recommendation; asked Round 5 | Exact underground engineering, method interoperability, family simulation and content limits remain open |
| 2026-09-06, revision 0.7 | Confirmed interoperable construction and uncertain supernatural truth; supplied dependent-resident family recommendation | DEC-032 remains open; detailed underground/family engineering and content limits remain outstanding |
| 2026-09-06, revision 0.8 | Adopted dependent residents, shared care, active elders and fixed first-release life stages; asked Round 6 | Child vulnerability, humor/art direction, exact family engineering and remaining lore questions stay open |
| 2026-09-06, revision 0.9 | Adopted child-vulnerability recommendation and warm everyday humor; explained three visual styles | DEC-018 remains open; exact family engineering, antagonist tone and wider content boundaries remain outstanding |
| 2026-09-06, revision 0.10 | Adopted the storybook/grounded-realism blend and domain-specific art guide; asked Round 7 | Species proportions, dialogue, canon divergence, exact mechanics and remaining lore details are open |
| 2026-09-06, revision 0.11 | Recorded recognizable anatomy, light dialect and selective canon flexibility; added continuity boundary records; asked Round 8 | Exact sizes, scenario continuity/cast, naming, culinary traditions and audio remain open |
| 2026-09-06, revision 0.12 | Adopted blended naming, all offered feast meanings and contextual sound/music blend; asked Round 9 | Exact names/customs/audio contracts, story delivery, Charter meaning and antagonist motives remain open |
| 2026-09-06, revision 0.13 | Adopted mixed story delivery, the Refuge’s community-written Charter and varied antagonist motives/scales; asked Round 10 | Rowan/founding, wider content limits, exact story UI and future faction rules remain open |
| 2026-09-06, revision 0.14 | Added six-book primary focus with publisher evidence; recorded mouse-keeper Rowan, displaced founding and two boundary subjects | Offscreen/exclusion clarification pending; detailed cause, place, cast and engineering remain open |
| 2026-09-06, revision 0.15 | Added passage-analysis companion, explicit source coverage and adaptation checks | Complete six-novel analysis needs full texts and reading; no interview decisions changed |
| 2026-09-06, revision 0.16 | Read all supplied Lord Brocktree narrative sections; recorded source mismatch, detailed analysis and bounded bible integration | Other five complete readings, edition verification and existing decision gaps remain; no new interview answers or mechanics |
| 2026-09-06, revision 0.17 | Verified eleven additional files and authored targeted studies, source audit, comparative contradictions and context integration | All eleven new sequential readings, full Eulalia! access, edition checks and existing DEC gaps remain open; no user answers or mechanics invented |
| 2026-09-06, revision 0.18 | Reviewed every supplied screenshot and recorded direct model-reference use, traversal analysis and source conflicts | Model production and complete traversal amendments remain; no slide-wide gameplay adoption or new interview answers |

Rounds 1–10 establish product range, first-release coverage, admission, diet, scenario-dependent player roles, rare meaningful wonder and player-selectable settlement forms including earth-built homes. Round 4 adds all underground construction methods, serious consequences/grief and visible family life. Round 5 confirms construction interoperability and uncertain supernatural truth; DEC-032 subsequently adopts the dependent-resident model. Round 6 adopts child survival vulnerability and warm everyday humor; the visual follow-up adopts a blend of storybook and grounded realism. Round 7 confirms recognizable anatomy, light dialect and selective canon flexibility. Round 8 adopts naming, feast and sound blends. Round 9 adopts story-delivery variety, the community-written Refuge Charter and varied antagonist motives/scales. Round 10 confirms experienced mouse-keeper Rowan and displaced founding, adds six-book reference emphasis, and names torture/child cruelty as boundaries with offscreen treatment being clarified. Policy adoption does not complete the game implementation or interview.

Revision 0.19 records DEC-035 and the separate design-focused pass. SET-MOVE-001 and all owning-document integration notes are adopted direction with explicit engineering gates, not a claim of runtime completion.

Revision 0.20 adds the systematic supplied-book content library. Source coverage is complete for available normalized blocks; missing source material and all existing engineering/creative decisions retain their stated limits. No DEC-nnn policy is newly closed.
