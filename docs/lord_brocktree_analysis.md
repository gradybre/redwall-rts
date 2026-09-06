# Redwall RTS — Lord Brocktree: Novel Analysis and Adaptation Reference

| Field | Value |
|---|---|
| Document | SET-RESEARCH-LB-001 |
| Revision | 1.0, 2026-09-06 |
| Parent research | [Novel analysis and adaptation research](redwall_novel_analysis.md), SET-RESEARCH-001 |
| Primary evidence | EV-LB02: user-supplied EPUB; text identifies itself as Lord Brocktree by Brian Jacques |
| Reading coverage | All supplied narrative text: Prologue, Chapters 1–38, Epilogue, read in narrative order; all 40 sections covered |
| Source integrity | File claims a Books 1–20 collection but contains one novel; conversion errors are visible; no comparison against a publisher master |
| Scope | Critical analysis of the supplied Lord Brocktree text, with bounded comparisons to previously inspected excerpts; spoilers include the ending |
| Authority | Literary evidence and original interpretation. [Setting decisions](setting_decisions.md) control adaptation; owning gameplay specifications control implementation |
| Implementation effect | No new mechanics, approved biography, scenario selection, balance constants, assets, commits or pushes |

## 1. What this novel contributes to the game

Lord Brocktree makes a compelling case for treating a community's military strength, domestic life and accumulated knowledge as connected. Its mountain can be conquered while its people, memories and obligations survive elsewhere. Its eventual recovery requires extraordinary fighters, but also cooks, hosts, boat crews, scouts, interpreters, caregivers and creatures who remember obscure things. The future institution matters because it can preserve these relationships beyond the immediate emergency.

This is a critical interpretation, not an assertion that the novel gives every contributor equal authority. It repeatedly celebrates hereditary badger leadership and extraordinary physical power. Allies deliberate, disagree and take initiative, yet sometimes submit to threats or unilateral decisions. The text's generous ethic of hospitality sits beside severe distinctions between deserving friends and despised enemies. Both features belong in the reference record.

For this project, the useful inheritance is a settlement whose routines make its inhabitants recognizable and whose institutions have reasons to exist. Brendan's chosen admissions policy, uncertain wonder, child protections and content exclusions are deliberate adaptations. They should not be presented as perfect reproductions of this book's worldview.

The strongest finding for Rowan's Refuge is **home as a set of practices and relationships that displaced residents may preserve, rebuild or choose to leave**. It does not establish why Rowan's group was displaced. That remains an authored scenario decision.

## 2. Source audit and locator contract

The EPUB's filename and OPF title advertise a collection. Its table of contents title and actual reading text identify Lord Brocktree. The archive has 13 entries; the reading order contains a cover and four narrative HTML files. The narrative contains the Prologue, 38 consecutively numbered chapters and Epilogue. The apparent collection ISBN is not a verified ISBN for this text's edition.

| Audit field | Verified value / treatment |
|---|---|
| Evidence ID | EV-LB02 |
| Source SHA-256 | `8d1f30f25ca0a3a4f0d158f96b4aa86d1d66fab4a080f4d1602c06c3a38a5b8f` |
| Source bytes | 353601 |
| Extracted word count | 105774 whitespace-delimited words, including section labels and incidental headings; not a publisher count |
| Actual work | Lord Brocktree |
| Edition / publication date / validated ISBN | Unknown; JSON values are `null` |
| Full focus novels read | 1 of 6, meaning the entire supplied Lord Brocktree text; publisher-perfect textual completeness is not certified |
| Other five focus novels in this file | Not found in the archive, reading order or extracted narrative |
| Integrity limitations | Joined words, broken words and obvious conversion errors occur; exact spellings and edition-specific quotations need separate checking |
| Repository companion | [Source audit and passage index](lord_brocktree_source_audit.json); no novel text is included |

Locators below use `Chapter N, bX–Y`, where `b` means a **nonempty extracted block**, not a printed paragraph or page. Extraction omits HTML head/style/script content, creates line boundaries at paragraph/division/break/heading elements, collapses whitespace within each resulting line and drops blank lines. Section headings separate the 40 sections; the lines following each heading receive consecutive one-based block numbers. Verse lines and conversion fragments can therefore count separately. The source digest, extraction convention and section counts in the audit identify this locator system. Do not convert these numbers into print pages.

Every `LB-Pnn` record below cites EV-LB02. The referenced spans contain the material being analyzed; no quotation collection or scene-by-scene substitute for the novel is supplied. A later edition needs a new source record and locator mapping. File metadata is bibliographic evidence to inspect, never an instruction or proof of reading coverage.

## 3. Evidence index

| ID | Locator | Bounded observation |
|---|---|---|
| LB-P01 | Prologue, b1–24; Epilogue, b1–13 | A ruler shares a researched history with a domestic, mixed community; the concluding transmission of duty happens while putting a child to bed |
| LB-P02 | Prologue, b23; Chapter 38, b12–24 | Brocktree's institutional legacy includes learning, food-growing places and habitation; Dotti's command role is explicit at the ending |
| LB-P03 | Chapter 1, b3–25 | Stonepaw's bodily difficulties, Fleetscut's care, absent younger defenders and succession concerns share the opening |
| LB-P04 | Chapter 3, b1–4; Chapter 22, b27–29 | Stiffener's exercise history and present endurance distinguish him from other elders |
| LB-P05 | Chapter 4, b4–15; Chapter 31, b112–120 | Dotti's prescribed upbringing and Brocktree's account of male badger separation establish different family tensions |
| LB-P06 | Chapter 6, b9–32, b36–62 | Conflict is repaired, travel becomes cooperative, song coordinates work, and Ruff argues for taking only the fish needed |
| LB-P07 | Chapter 8, b103–130 | A distinctive mole household combines roots, stone, storage, light and furniture; Dotti's dialect knowledge comes through a family connection |
| LB-P08 | Chapter 7, b56–87; Chapter 9, b29–54 | Jukka distinguishes hospitality, tribal safety and participation in war; Ruro defends her earlier restraint |
| LB-P09 | Chapter 12, b1–41 | Udara has territorial authority and useful knowledge without literacy; access to information is negotiated |
| LB-P10 | Chapter 10, b71–103 | Refugees take stock of needs, discuss a course of action and depend on incomplete remembered knowledge |
| LB-P11 | Chapter 16, b7–12, b65–103 | Patient help with Bramwil's memory and several practical contributions make escape possible |
| LB-P12 | Chapter 11, b43–57; Chapter 14, b2–37, b55–99 | Gurth is explicitly grown, has learned competence and helps with rescue and instruction; Dotti contributes interpretation |
| LB-P13 | Chapter 17, b69–116; Chapter 20, b11–24, b55–95 | Provisioning and a common danger bring leaders together, while coercion also shapes the coalition |
| LB-P14 | Chapter 18, b4–59; Chapter 19, b63–66 | Stonepaw prioritizes escape, dies, and leaves obligations that Stiffener carries forward |
| LB-P15 | Chapter 21, b8–21 | Displaced sea otters shelter displaced hares; Frutch and Brogalaw connect welcome with practical assistance |
| LB-P16 | Chapter 21, b87–106; Chapter 22, b23–58 | Rulango communicates through drawings and delivers help; the rescue plan changes when travel consumes available darkness |
| LB-P17 | Chapter 25, b34–49, b80–90 | Rescue distinguishes assistance needs, also includes coercive treatment, and ends with Brogalaw refusing to kill helpless captives |
| LB-P18 | Chapter 26, b21–34; Chapter 28, b67–88 | Shared song, recollection, cooking and storage accompany organized resistance |
| LB-P19 | Chapter 23, b2–50; Chapter 24, b58–68; Chapter 27, b34–61 | Dotti learns through a coalition, questions the fairness of a victory and protects a defeated opponent |
| LB-P20 | Chapter 27, b110–131 | A coalition deliberates, then hereditary law and a public symbolic act establish Brocktree's leadership |
| LB-P21 | Chapter 29, b22–24, b55–65, b87–100 | Sympathy for enemies is disputed; hostages become a living shield; an enemy soldier refuses to kill his own comrades; captives are later released |
| LB-P22 | Chapter 30, b80–99; Chapter 31, b1–6 | The rescuers initially take no prisoners, Brocktree orders killing to stop, and surviving captives receive both mercy and harsh treatment |
| LB-P23 | Chapter 31, b68–89, b112–120 | A healer's expertise, shared cooking, a damaged heirloom and mourning occupy the same gathering |
| LB-P24 | Chapter 32, b49–76 | A storage cave becomes a refuge; Frutch prefers return to her old home over a room and garden in the mountain |
| LB-P25 | Chapter 33, b30–62; Chapter 34, b1–18 | Tide, body size, light, airflow and imperfect knowledge affect passage through underground space |
| LB-P26 | Chapter 34, b23–41 | Fleetscut and Jukka's antagonistic relationship ends in shared defense and a final recognition of friendship |
| LB-P27 | Chapter 35, b54–63, b87–110, b173–189 | Brocktree refuses a costly assault, imposes his duel decision, and friends independently plan protection around him |
| LB-P28 | Chapter 36, b8–17, b47–74; Chapter 37, b1–9 | A friend's intervention matters to the duel; victory language is partisan; Trunn survives the immediate defeat and Groddil acts afterward |
| LB-P29 | Chapter 38, b2–24 | Allies depart for distinct homes, others stay, Ruro receives a Jukka memorial medal, and Dotti combines leadership with further learning |
| LB-P30 | Chapter 7, b10–19, b49–54 | The falling-stars and earth-shaking displays have explained physical causes |
| LB-P31 | Chapter 4, b11–15; Chapter 11, b30–43; Chapter 35, b135–138 | Dreams carry information and emotional force; the ancestral chamber joins material objects, scent, memory and visions |
| LB-P32 | Chapter 28, b94–113; Chapter 29, b109–117 | Some immediate terrors have mundane triggers; Ungatt's fear and isolation persist |
| LB-P33 | Chapter 16, b21–26; Chapter 22, b79–86; Chapter 28, b89–93 | Food depletion, damaged fishing and unequal access undermine the occupying force |
| LB-P34 | Chapter 32, b16–47; Chapter 35, b61–95 | Both sides recognize limits to supply and open combat; the defenders' apparent abundance is partly performed |
| LB-P35 | Chapter 36, b74; Chapter 38, b2 | Returning birds and travelers carry the narrative's outward signs of changed conditions |
| LB-P36 | Chapter 2, b1; Chapter 28, b62; Chapter 29, b64 | The narrator uses moralized species and appearance language, yet a hostile soldier demonstrates a limited loyalty to comrades |
| LB-P37 | Chapter 34, b34–36; Chapter 38, b22–24 | Dotti's leadership achievement coexists with gendered protective treatment and expectations about domestic learning |
| LB-P38 | Chapter 35, b3–5; Chapter 38, b8–9 | Enemy characters can provision themselves; Ruff expresses an ambition to learn sea-otter life |
| LB-P39 | Chapter 19, b8–18; Chapter 21, b37–59; Chapter 26, b35–50 | Arbitrary punishment and fearful reporting damage Ungatt's information and create new enemies |
| LB-P40 | Chapter 31, b89; Chapter 33, b51–59; Epilogue, b6–13 | Guard relief enables participation; remembrance occurs during work; hospitality is part of the concluding law |

## 4. Narrative construction: how the book makes its world matter

### 4.1 The historical frame turns achievements into inheritance

The Prologue does more than announce an important warrior. Russano prepares a history from records and testimony, while his wife's appropriated household pail punctures the solemnity of the undertaking. The audience includes residents, visitors and children. Historical knowledge is made and shared inside a functioning community. The Epilogue closes with a parent carrying a sleepy child to bed and asking for remembered duties. Political succession and ordinary tenderness inhabit the same scene. [LB-P01]

The frame selects and honors its subjects. It is reasonable to analyze it as institutional memory, but the fact that Russano assembled a record does **not** prove that every narrated event is doubtful. Nor does it authorize a game chronicle to fabricate outcomes. The reader is given scenes and interior experiences beyond what an ordinary resident could directly witness; a playable journal needs its own narrower source-of-knowledge contract.

Brocktree's legacy is not exhausted by winning a battle. The Prologue names education, cultivated spaces and improved accommodation, while the ending establishes Dotti within the new Patrol. The interpretation for a colony game is that a founder leaves procedures, provision and opportunities for others to continue. It is not permission to identify the Refuge Charter with the law of Salamandastron. [LB-P02, LB-P40]

### 4.2 Alternating strands give unequal situations equal narrative attention

The traveling coalition and the older mountain residents initially face different problems. One strand builds relationships and capacity; the other loses security and improvises survival. Their later meeting joins accumulated resources, incomplete news, kinship and grief. The structure prevents the reader from treating rescue as a problem that began only when the principal hero arrived. Local people have already acted. [LB-P08, LB-P10–18, LB-P22–23]

The three major book divisions pair grand historical headings with Dotti's more personal concerns. That pairing makes heroic history and a young traveler's experience parts of one story. The damaged shawl eventually matters because of its family relationship, despite its poor physical condition. A useful game equivalent would distinguish an object's functional state from its approved personal significance; neither meaning implies a magic item or inventory bonus. [LB-P23]

### 4.3 Ordinary life connects episodes instead of merely interrupting them

Meals create the setting for introductions, negotiations, training, reconnaissance reports, mourning and departures. Repeated meals therefore do different narrative work. Song can coordinate paddling, recover a remembered sense of home, express group identity, entertain badly or serve a hostile display. Treating every feast as an interchangeable celebration would erase this range. [LB-P06, LB-P18–19, LB-P23, LB-P27, LB-P34]

The novel also juxtaposes food with genuine shortage. Long descriptions of abundance are politically and emotionally consequential because some characters cannot obtain food. This is not a trustworthy nutritional model: dishes, portions, alcohol and fictional remedies operate under comic and adventure conventions. None supplies a safe recipe, treatment or balance formula.

## 5. Institutions, leadership and coalition

### 5.1 Salamandastron is a home with a defense obligation

The opening attends to Stonepaw's discomfort, meals, friendship and responsibility. Later refuge scenes show bedding, ovens, stored supplies and deliberation. The framing community includes cultivation and childhood learning. A fortress here is an inhabited institution, not a weapons platform with decorative kitchens. [LB-P01–04, LB-P10–11, LB-P24]

That does not make it an Abbey. Its ancestral chamber, hereditary leadership claims, military organization and particular traditions need to remain distinct. The research corrects a domestic/martial split in our **design emphasis**, not the differences between canonical institutions.

### 5.2 Cooperation has motives, limits and more than one legitimate constituency

Jukka initially offers welcome without committing her people to a war she considers disastrous. Her later participation does not retroactively make that concern meaningless: Ruro articulates its protective rationale. Udara controls access and bargains over information. The Guosim bring traditions and their own leadership. Brogalaw's group has suffered displacement and assists people in worse circumstances. Bucko's public status and personal history give him different stakes again. [LB-P08–09, LB-P13, LB-P15, LB-P19–20]

The inference for scenario writing is to give each community a reason to cooperate and something it is responsible for protecting. Hospitality, trade, safe passage, military alliance and political submission should not become synonyms. This is an authoring distinction; it does not approve five new diplomacy systems.

Brocktree frequently recognizes others' abilities and invites ideas. He also intimidates allies, asserts inherited right and denies debate over a decisive choice. The crown is physically transformed into part of his weapon during the public assertion of authority. Calling this a democratic federation would be inaccurate; calling every ally an inert follower would also be inaccurate. The book combines consultation, charismatic power, hierarchy, friendship and local initiative. [LB-P13, LB-P20, LB-P27]

### 5.3 Leadership is tested by restraint, but restraint is selective

Stonepaw rejects an indiscriminate final sacrifice and creates an escape opportunity. Stiffener accepts an obligation to protect survivors rather than join a doomed defense. Brocktree later refuses to spend his companions' lives in an assault whose odds have become clear. These are strong textual grounds for distinguishing courage from avoidable loss. [LB-P14, LB-P27]

Yet restraint is uneven. Dotti protects a beaten opponent and questions whether her own side has been fair. Brogalaw refuses to kill helpless prisoners, but later uses captive enemies as a living shield. Brocktree halts killing after a rescue whose first phase explicitly takes no prisoners. The narrative condemns cowardice and humiliation selectively. Preserve this contradiction as literary evidence; do not smooth it into a universal code of humane warfare. [LB-P17, LB-P19, LB-P21–22]

### 5.4 Ungatt's failures expose a different institutional design

Ungatt is capable of planning, recognizing threats and devising countermoves. His failure is not adequately explained by stupidity. His authority depends on fear, spectacle, promised success and the ability to provide. Punishment discourages useful reporting; subordinates manufacture accounts, withhold facts, pursue personal advantage and eventually desert or plan betrayal. Scarcity makes the contradiction between promise and experience more visible. [LB-P33–34, LB-P39]

An interpretation for future antagonists is to connect visible behavior with incentives and constraints. A coercive faction can have poor information because telling the truth is punished. This is not a requirement to model every soldier's political beliefs. For the current settlement release it is reference context only; it adds no raids, interrogation, hostage or army behavior.

## 6. Character arcs and the limits they reveal

| Character / relationship | Development supported by the supplied text | Interpretation and adaptation boundary |
|---|---|---|
| Dotti | A forceful traveler learns from several companions, challenges exclusion, exercises restraint toward Bucko and ends with a recognized Patrol role | Growth is acquired competence and judgment, not loss of personality. Her noisy humor persists. Do not equate a young adventurer with a child eligible for hazardous jobs. [LB-P05, LB-P12, LB-P19, LB-P29, LB-P37] |
| Brocktree | An inherited claim becomes a practical coalition and an institution; intimate information about his father becomes a source of grief and vengeance | Leadership has relational support and dangerous power. This is not Rowan's biography or a template for giving the keeper hereditary sovereignty. [LB-P05, LB-P13, LB-P20, LB-P23, LB-P27–28] |
| Stonepaw / Stiffener | One elder's limitations and sacrifice contrast with another elder's sustained physical training and continuing obligations | Age does not supply a universal capability curve. The narrative values endurance, practical care and succession differently in different people. [LB-P03–04, LB-P14, LB-P17] |
| Fleetscut / Jukka | Repeated insults and disputes do not disappear before they fight together; their final mutual recognition is costly and late | Shared purpose can coexist with abrasive disagreement. The ending gives friendship emotional force but should not become a mandatory sacrifice plot for every quarrelsome pair. [LB-P08, LB-P13, LB-P26] |
| Gurth | An explicitly grown mole is a cook's son, capable traveler, rescuer, wrestler, teacher and useful underground guide | A resident can have intersecting competencies. Culture and occupation are richer than a single species job label. [LB-P12, LB-P19, LB-P25] |
| Bucko | An exclusionary, boastful opponent becomes a respected ally; his separate homeland still matters after victory | The text can revise a relationship without pretending the earlier behavior never occurred. His revealed treatment and revenge are source analysis, not approved game content. [LB-P19–20, LB-P28–29] |
| Frutch / Brogalaw | Food, embarrassment, affection, aid and concern connect parent and adult child; Frutch insists on returning home | A dependent or noncombatant resident can have a clear preference that the heroic reward does not satisfy. [LB-P15, LB-P18, LB-P24, LB-P29] |
| Rulango | A nonspeaking heron observes, draws, transports aid and expresses affection | Lack of spoken dialogue is not lack of intelligence or agency. Do not classify a creature as nonsapient from silence or from another character calling it a pet. [LB-P16, LB-P28] |
| Ruro | Care and judgment recur before her final tribal leadership recognition | Healing is consequential work rather than anonymous recovery between important scenes. The medal memorializes Jukka; it does not prove an unrestricted rule that outside rulers appoint all tribal leaders. [LB-P08, LB-P23, LB-P29] |

Dotti's arc deserves a qualified reading. The story challenges Bucko's dismissal of a haremaid and ends with her as a commander. It also gives her protective treatment in violent scenes and retains gendered domestic expectations. The conclusion combines command and cooking rather than declaring care beneath a warrior. It would nevertheless be inaccurate to call the text free of gender hierarchy. For the game, opportunities and abilities must follow the approved character and job rules, not an imported rule about which gender belongs in a kitchen. [LB-P19, LB-P37]

## 7. Home, displacement and care

### 7.1 Being hosted is different from choosing a permanent home

The sea-otter refuge shows displaced residents becoming hosts themselves. Its warmth comes from food, shelter, attention and action. Later, a storage space is reorganized into habitation: cooks discuss ovens, seating, beds and help from other cooks. These passages make the transition from shelter to lived space concrete without supplying measurable dimensions. [LB-P15, LB-P24]

Frutch's desire to return south survives an offer of improved accommodation. At the ending, different groups leave in different directions, some remain temporarily and new hares arrive. The coalition does not become one culturally uniform population. A successful home can sustain relationships beyond its own walls. [LB-P24, LB-P29]

For Rowan's Refuge, this supports asking what the initial residents carried in knowledge, relationships and material possessions, and what would make this particular place worth staying in. It does not choose a persecutor, journey, family tragedy, land grant or reason the starter hall is already furnished.

### 7.2 Assistance should respond to a particular difficulty

Fleetscut adapts food and company to Stonepaw's needs. Stonepaw gives Bramwil quiet support rather than treating memory failure as disobedience. Escape requires adjustments to fatigue, height, timing and mobility. Rulango's drawings need interpretation by people familiar with him. Knowledge is distributed among bodies, remembered objects, relationships and places. [LB-P03, LB-P11, LB-P16–17, LB-P25]

Some of the source's supposed helpfulness is coercive. A frightened resident is struck during rescue; valuable personal property is taken to solve an urgent problem; physical discipline and threats appear in domestic comedy. These are not neutral care procedures to import. The project's desired warmth and content boundaries require authored alternatives. Recording the difficult passages is necessary precisely because a selective list of kindly moments would mislead the coding and writing agents.

### 7.3 Children create relationships rather than an economic workforce

Skittles joins interactions through play, interruption, affection and care. Adults supervise, rescue, comfort, argue about and make room for him; he is not represented as a normal productive worker. The Epilogue places the transmission of community values inside a bedtime routine. [LB-P12, LB-P24, LB-P29, LB-P01]

The novel also exposes young characters to danger and includes treatment excluded by the game direction. Fictional age words and references to seasons cannot safely become the game's age thresholds. DEC-032/033 already govern dependent residents and non-graphic survival risks. They need exact engineering contracts before these observations become scheduled actions or eligibility tests.

## 8. Grief, memory and wonder

### 8.1 Grief remains personal and does not stop ordinary life

The book allows mourning beside a feast, practical remembrance during a journey and farewell tears after victory. An heirloom is cherished despite damage. Jukka's name survives in a medal, while the frame itself makes past deeds available to a later community. These are different carriers of memory: object, story, office, relationship and deliberate action. [LB-P23, LB-P26, LB-P29, LB-P40]

Its treatment of grief is not uniformly gentle. Brocktree redirects sorrow toward vengeance, and characters sometimes rebuke or mock weeping. The closing celebration does not undo the named deaths; neither does it establish a predictable mourning duration. The game should retain serious consequences without treating permanent misery, retaliatory violence or a universal feast cure as required fidelity. Exact customs remain DEC-014.

### 8.2 The novel distinguishes trickery from visions without resolving all metaphysics

The apparent falling stars and shaking earth receive explicit physical explanations. A later frightening shadow and a suffocating dream have immediate mundane triggers. Those explanations do not debunk every vision in the novel: dreams about the adversaries precede their face-to-face meeting, and the ancestral chamber presents a wider visionary succession of past and future-seeming scenes. [LB-P30–32]

Accordingly, two shortcuts fail: “all Redwall wonder is verified magic” and “the book explains all wonder away.” The supplied text gives different phenomena different treatment, sometimes with strong narrative validation. Brendan's DEC-030 is an adaptation that keeps ultimate truth uncertain. Use clearly attributed beliefs and meaningful objects while keeping observable costs, hazards and outcomes reliable. Do not add a hidden `is_magic` truth flag and call uncertainty a presentation filter.

The unnamed sword-bearing mouse in the vision is not identified by this passage. Do not assign a famous name by recollection and record it as verified canon. Likewise, references to an afterlife or ancestral duty do not establish a complete theology or authorize a functioning afterlife simulation. [LB-P31]

## 9. Food, ecology, material culture and embodied space

### 9.1 Food has several social functions

| Function observed | Evidence | Useful distinction for an original scene |
|---|---|---|
| Care | LB-P03, LB-P15 | A meal responds to a particular person's condition |
| Hospitality and repair | LB-P06, LB-P15 | Sharing food follows an encounter and changes how people relate |
| Identity and remembered home | LB-P18, LB-P23 | A recipe or song belongs to a household or community |
| Negotiation and coordination | LB-P09, LB-P13, LB-P20 | Feeding people makes a meeting possible; it does not itself settle every disagreement |
| Contest and prestige | LB-P19 | Abundance can become competition, vanity and strategy |
| Power and deprivation | LB-P33–34 | Who receives food matters alongside how much exists |
| Celebration and departure | LB-P28–29 | Victors celebrate, then still have supplies, care and travel to arrange |

The occupying force's supply difficulties and the defenders' limited reserves keep resource availability relevant to decisions. A theatrical feast does not prove unlimited stocks. Conversely, later enemy foraging competence prevents the simplistic reading that only morally good creatures can cook or gather food. These are observations about narrative causation, not production-rate measurements. [LB-P34, LB-P38]

### 9.2 Wildlife categories need explicit adaptation

The supplied text contains eaten fish and shellfish, companion beetles, a territorial speaking owl, a communicative nonspeaking heron and seabirds whose disappearance and return mark changes on the coast. It also contains predation and threats outside the adopted diet. It cannot be reduced to a universal “speaks equals person, silent equals food” rule. [LB-P06–07, LB-P09, LB-P16, LB-P33, LB-P35]

Keep DEC-006's explicit nonsapient food whitelist. Do not introduce edible birds, hides, mammal hunting or person-predation from these passages. The final return of seabirds is a narrative sign of relief; it is not evidence for an exact population recovery rate or a simulation that instantly restores an ecosystem after victory.

### 9.3 Architecture is made legible through use

The mole home supplies textures and arrangements—roots, stone, storage, lamps, seating and a hearth. Refuge caves acquire practical uses through changing needs. Underground travel makes tide, opening width, light and air perceptible. These give strong qualitative references for earth-built homes and body-aware movement. [LB-P07, LB-P24–25]

They do not provide an engineering survey. Do not scale a canonical room from “large,” infer a safe structural span from a badger breaking rock, or assume every tunnel connects because a novel's escape route does. DEC-029/031 authorize the three interoperating construction methods; geometry, costs, support, routing and persistence remain the work of their owning specifications.

```text
CONCEPT RELATIONSHIPS ONLY — NOT A MEASURED PLAN

[Arrive from outdoors] ---> [Sheltered common space]
                                     |
                         +-----------+-----------+
                         |           |           |
                    [Prepare food] [Store] [Sit / rest]
                         |                       |
                         +---- [Shared routine] -+

Production geometry, circulation widths and vertical connections:
derive from approved game contracts, never from this diagram.
```

### 9.4 Bodies influence action without settling personality

Paws, tails, ears, digging claws, wings and relative size recur in action, humor and practical problem-solving. Rulango's flight enables help others cannot provide; a large badger must negotiate confined passages; Gurth notices air movement. At the same time, Gurth contradicts assumptions about fear of water and Ruff wants to learn a different otter way of life. [LB-P12, LB-P16, LB-P25, LB-P38]

The game can express recognizable anatomy in silhouettes, tools and animation. It must not infer automatic intelligence, loyalty, job aptitude or moral worth from species. Exact rig dimensions and locomotion choices remain to author under existing asset budgets.

## 10. Adaptation decisions and honest departures

The following is a research audit of existing decisions, not a new list of user approvals.

| Issue | Source finding | Project treatment |
|---|---|---|
| Species and moral judgment | Moralized species and appearance descriptions occur in narrator voice, not only prejudiced dialogue; individual enemy loyalty complicates the picture without making the whole book neutral. LB-P36 | DEC-005 deliberately separates individual admission from hidden species evil. Do not falsely claim this policy simply reproduces Lord Brocktree |
| Torture and child cruelty | Relevant material exists in villainous conduct and in harsh behavior or jokes by sympathetic characters. LB-P17, LB-P19, LB-P21, LB-P28–29 | Apply DEC-027 consistently to all sides. Pending offscreen clarification, exclude these subjects entirely from newly authored game content |
| Mercy | Mercy toward some defeated people coexists with executions, no-quarter fighting, humiliating captivity and revenge. LB-P17, LB-P19, LB-P21–22, LB-P28 | Do not invent a universal canonical mercy code or assume an approved prisoner system. Future conflict rules need their own decision |
| Gender and opportunity | Dotti's achievement challenges exclusion without removing all gendered expectations. LB-P19, LB-P37 | Her development supports studying competence and respect; it does not authorize gender-based job locks |
| Disability and dependency | Individual care and nonverbal agency coexist with degrading descriptions and coercive assistance. LB-P03–04, LB-P16–17, LB-P39 | Preserve authored capability and accessible communication. Do not use bodily difference as shorthand for evil or comic unworthiness |
| Leadership | Birthright, force, affection, consultation and independent initiative all matter. LB-P13, LB-P20, LB-P27 | DEC-008 varies roles by scenario; the Refuge's civic Charter remains DEC-023. No default Badger Lord requirement |
| Grief | Memory persists, but some characters direct sorrow toward revenge or discourage its expression. LB-P23, LB-P26, LB-P40 | DEC-011 governs seriousness; exact rituals remain open. No mandatory revenge or automatic recovery |
| Wonder | Explained spectacle and narratively significant visions coexist. LB-P30–32 | DEC-009/030 govern rare, meaningful, ultimately uncertain game wonder |
| Diet | Food and sapience categories do not form a clean universal taxonomy. LB-P06–07, LB-P16, LB-P33, LB-P38 | Keep DEC-006 and the existing whitelist; no new edible species inferred |
| Historical outcomes | Stonepaw, Fleetscut and Jukka die; Dotti's role and the coalition's dispersal matter to the conclusion. LB-P14, LB-P26, LB-P29 | A named-novel scenario must list protected outcomes and explicit departures under DEC-025 before using them |

Two ending details particularly resist convenient summary. First, the narration establishes that Trunn remains alive after the immediate duel; Groddil subsequently acts against him. “Brocktree kills Trunn outright in the duel” is therefore an inaccurate description of the supplied sequence. Second, the victorious characters' language about a nearly bloodless success concerns their side's immediate losses; it does not mean the whole conflict, or even the routing of the enemy, was bloodless. [LB-P28]

The fate of Karangool beyond the depicted encounter with Bucko is not separately narrated here. Do not supply an exact death scene or time. Likewise, the birthright claims concerning male badgers belong to the characters' account and this novel's institutional framing; they do not justify a deterministic rule that two adult male badgers must fight whenever they share a settlement. [LB-P05, LB-P28]

## 11. Handoff to planning, writing and asset work

### 11.1 Recommended applications, all PROPOSED

| ID | Original project recommendation | Existing owner / required dependency | Reviewable outcome before implementation |
|---|---|---|---|
| LB-APP01 | Specify recognizable care routines around concrete needs and participants | DEC-015/032/033; GDD family amendment and UI | Each routine identifies request, eligible helper, reservation, interruption, completion, failed assistance, displayed state and save behavior |
| LB-APP02 | Give every selected scenario its own basis of authority and obligations | DEC-008/023/025; scenario catalog and objectives | Authored role description names who decides, who participates, what responsibility follows and how it agrees with initial data |
| LB-APP03 | Establish what displaced residents retain and what makes the new place home | DEC-002/003/004; GDD initialization | Founding account reconciles all initial residents, the furnished hall, stockpiles and arrival timing without changing numbers silently |
| LB-APP04 | Separate the occasion, participants and remembered meaning of feasts | DEC-007/014/021/022; existing feast rules | Text and presentation map to an approved feast state; no extra reward, recipe or diplomacy effect is inferred |
| LB-APP05 | Give a memory-bearing object a known owner, history and source of significance | DEC-011/014/022/030; content and history contracts | Original object record distinguishes authored background from actual recorded events; no unapproved inventory behavior or magic |
| LB-APP06 | Build interior briefs from use, materials and accessible circulation | DEC-010/018/019/020/029/031; architecture and crowd asset contracts | Each prop supports an approved activity, reachable placement and existing rendering/collision budget |
| LB-APP07 | Keep neighboring communities' reasons for cooperation distinct | DEC-004/008/013/026; future scenario/campaign specifications | Reference-only faction sheets identify home, concern, resources and relationship; runtime diplomacy remains outside this research |

These recommendations do not originate exact care durations, friendship scores, morale curves or construction costs. Such numbers would be invented design, not novel analysis, and belong in a reconciled mechanical proposal.

### 11.2 EARS requirements for consuming this reference

| Requirement | EARS statement |
|---|---|
| REQ-LB-001 | When an author uses a Lord Brocktree claim from this document, the author shall cite EV-LB02, at least one LB-P record and its bounded locator. |
| REQ-LB-002 | If a detail depends on an edition, exact spelling or unseen illustration, then the author shall mark that detail unverified until the corresponding evidence is inspected. |
| REQ-LB-003 | When a source action violates an adopted content boundary, the author shall retain only an analytical reference and shall exclude the action from new game content under the operative DEC rule. |
| REQ-LB-004 | When a literary observation motivates runtime behavior, the planner shall specify its state, eligibility, commands, interruption, save compatibility and validation under the owning mechanical contract before implementation. |
| REQ-LB-005 | While a proposal remains PROPOSED, the coding agent shall preserve the existing authoritative implementation contract and shall not treat the research note as feature approval. |
| REQ-LB-006 | When a scenario adapts this novel, the scenario author shall enumerate verified anchors, protected outcomes, permitted changes and explicit departures before importing canonical people or events. |
| REQ-LB-007 | If a displayed historical assertion concerns a simulated event, then the presentation shall use committed game history rather than inventing an event to resemble the novel. |
| REQ-LB-008 | When an asset brief uses an anatomical or architectural passage, the brief shall retain existing dimensional and performance owners and shall label unsourced visual additions as original design. |

This is a completed static authoring example:

```yaml
research_contract_version: 1
record_id: LB-NOTE-REFUGE-001
evidence_ids: [EV-LB02]
passage_ids: [LB-P15, LB-P24, LB-P29]
interpretation_scope: COMPLETE_SUPPLIED_NOVEL
decision_dependencies: [DEC-002, DEC-003, DEC-004]
proposal: Explain which relationships and practical resources the Refuge founders retain after displacement.
status: PROPOSED
mechanical_owner: docs/game_gdd.md
requires_initialization_reconciliation: true
runtime_changes_authorized_by_this_note: false
new_simulation_numbers: []
source_edition_validated: false
```

Store literary observations in documents or static authoring catalogs. Do not create a research component, Node, timer or object for each resident. If a later approved feature needs authoritative state, use the packed integer storage, entity-generation references, fixed-tick ordering and save contracts already owned by the ECS architecture. Presentation must not add simulation RNG calls to make a scene feel more literary.

## 12. Corrections, remaining research and next interview

### 12.1 What changed relative to the earlier excerpt pass

| Earlier evidence boundary / working idea | Result after the supplied novel |
|---|---|
| No complete focus novel read | Superseded as current coverage: the complete supplied Lord Brocktree text is read; five focus novels remain incomplete |
| Stonepaw's care suggests domestic life within military identity | Supported and extended by refugee households, cooking, learning, family and the closing law; not limited to Chapter 1 |
| Coalition-building as an optimistic reference | Qualified: local interests, competition, insults, hierarchy, coercion and personal history also enable or complicate cooperation |
| Shared care as a uniform source ethic | Qualified: patient care and coercive assistance coexist; sympathetic characters also need the game's adaptation filter |
| Uncertain wonder as an adaptation rather than a universal canon claim | Retained, with a clearer distinction between explained displays and consequential visions |
| Species morality needs source-specific checking | Now directly evidenced for this novel: narrator language is often essentializing; limited contrary behavior does not erase it |
| Grief as serious aftermath | Supported, but the source also redirects grief into revenge and treats tears inconsistently |
| Earth-built homes need direct references | Strong qualitative evidence now available; exact geometry and construction algorithms remain unsatisfied |

### 12.2 Next reading and questions

The other requested focus works remain **Redwall, Mossflower, The Long Patrol, Salamandastron and Eulalia!**. Their full texts are absent from this EPUB. Eulalia! has the previously documented excerpt coverage; the other four retain publisher-summary coverage. Whole-series context remains welcome, but comparative claims need passages from the works actually being compared.

The next full-novel pass should test whether these findings recur, change or fail: inherited authority versus civic authority; who can be admitted and trusted; the status of domestic labor; what loss leaves behind; the role of visions; and whether a coalition's conclusion preserves distinct homes. Do not assign a prevalence percentage or a theme ranking from this one novel.

The following interview prompts are **unanswered**, not chosen defaults:

1. What did Rowan's displaced group preserve—skills, relationships, tools, records or traditions—and who provided the existing hall and supplies before play begins? This closes a concrete founding gap without assuming a war.
2. When community safety and a leader's judgment conflict, who can challenge the leader in each scenario, and what recourse exists? A civic keeper, an Abbey office and a Badger Lord need not answer identically.
3. Which everyday custom and which memorial practice should make Rowan's Refuge recognizable, and how should they appear when resources are scarce? The aim is a specific practice with participants and a place, not a new unexplained morale bonus.

Enemy treatment, prisoner mechanics and the treatment of excluded subjects in backstory require their own future decisions; this analysis does not pre-approve them. Complete the currently pending DEC-027 clarification before drafting material that depends on it.

## 13. Provenance and verification

Inherited from Brendan and the project: reference priorities, the six-book focus, scenario variety, experienced mouse-keeper Rowan, displacement, visible community life, serious grief, warm humor, art/anatomy direction, uncertain wonder, admissions/diet policy and content boundaries. Existing gameplay math remains with its owning documents.

Newly authored here: the critical thesis, motif groupings, character interpretations, evidence IDs, proposed applications, handoff requirements and interview prompts. File bytes, digest, section counts and extracted word count are measured source metadata. Block ordinals are generated locators. Revisions, schema versions and ID numbers are organizational metadata. **No new gameplay quantities originate in this analysis.**

Satisfied: all supplied narrative sections read; ending and counterexamples considered; source identity checked; passage index and source audit supplied; findings reconciled with adopted adaptations; full-text material kept outside repository deliverables. Unsatisfied: publisher-perfect edition verification, complete reading of the other five focus books, a six-novel comparative synthesis, exact canonical illustration/geometry evidence and unresolved creative/engineering contracts. Those limits remain explicit rather than being filled from memory.
