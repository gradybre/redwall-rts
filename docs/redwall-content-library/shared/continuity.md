# Cross-book identity, institutions and era reconciliation

The shared catalog preserves every book-qualified appearance. The relations below are a curated reconciliation layer; they do not erase appearances or claim a complete dated series chronology. Different narrators and frame stories can discuss an earlier person long after that person's lifetime.

## 1. Identity and naming decisions

| Relation | Evidence | Library decision |
| --- | --- | --- |
| Sunflash the Mace → Sunstripe the Mace | Outcast block 3549 explicitly gives the later change of name; Salamandastron block 1155 uses Sunstripe | Same individual, later-era alias. Earlier spelling-conflict warnings are superseded by this evidence. |
| Ancient Martin across Martin the Warrior, Mossflower and later memories/visions | Each book's Martin record distinguishes the original warrior from later Abbey references | Connect the original person's history and attributed appearances; do not assume a physical living cameo in every book. |
| Martin of Redwall in Pearls of Lutra versus the first Martin | Separate Pearls records explicitly distinguish the later warrior from the original | Different individuals; shared forename and sword tradition do not merge them. |
| Matthias in Redwall versus later historical references | Redwall's living protagonist; Pearls, Long Patrol and Taggerung retain historical references | Same historical identity, separate appearances and knowledge states. |
| Cregga in The Long Patrol, Marlfox and Taggerung | Military leader and acquired blindness; later Abbey Badgermum; later death, grave and reused room | Same individual with consequential changes of vocation, health, office and memorial status. |
| Tansy in Pearls and later Abbey history | Pearls appointment; Long Patrol office; later historical references | Same individual; distinguish live office-holding from memory. |
| Russano across Long Patrol, Lord Brocktree's frame, Taggerung and Triss | Infant in Long Patrol; later mountain lord and frame family | Connect identity while preserving frame versus main-story time. Do not insert adult Russano into Brocktree's main campaign. |
| Lord Brocktree, Boar, Bella and Sunflash | Source family references in Lord Brocktree, Mossflower and Outcast | Preserve the stated ancestry and separate lifetimes; “badger lord” is an office category, not one immortal person. |
| Skipper, Log-a-Log, Foremole, Friar, Abbot/Abbess | Reused offices throughout the corpus | Never automatically merge office-holders. A title alone provides neither personal identity nor a dated succession chain. |
| Guosim the individual shrew in Redwall versus the Guosim organization | Separate character and faction records | Preserve different entity types; a shared word is not identity. |
| Guosim / Guosssom and their book-specific crews | Different group descriptions and spellings, including Salamandastron's watermeadow shrews | Keep source spellings and memberships. Institution-family comparison is allowed; identical membership is not assumed. |
| Reused or variant OCR names | Examples retained in local alias notes: Morio/Mono, Burfal/Burial, Frackle/Freckle, Turry/Tuny | Mark editorial alias proposals. Do not create or erase an individual solely to make spelling consistent. |

Use `name_collisions.json` to discover possible overlaps. It deliberately marks matches `NOT_AUTOMATICALLY_MERGED`. The complete source appearances remain in `character_index.md` and `catalog.json`. `relationships.json` contains the curated machine-readable identity links and selected local route examples; it is deliberately not an exhaustive chronology.

## 2. Office and faction behavior

| Institution / household family | Observed variation useful to the game | What must remain era-specific |
| --- | --- | --- |
| Redwall Abbey | Refuge, shared food, infirmary, school, archive, elected/appointed service, defense under threat, repairs and memorials | Ruler, recorder, friar, cellar staff, resident population, building state, damaged spaces and current customs |
| Salamandastron and the Long Patrol | Household provisioning, forge, training, reconnaissance, service, rescue and leadership succession | Ruler, generals, troop organization, gardens, occupation/siege state and relationships with outside allies |
| Guosim and related shrew communities | Boats, scouts, elected or contested leadership, family flotillas, camps, food, trade and coalition work | Chief, crew, custom, current camp, who can vote and book-specific terminology |
| Otter holts and crews | Fishing, coastal/river knowledge, families, vessels, alliances and voluntary aid | Named holt, leader, waters, household ties and ships |
| Squirrel and mole communities | Canopy/route knowledge or excavation alongside families, politics, food and other work | Actual skills, residents, structures and access; species does not establish compulsory profession |
| Occupying armies and raiders | Provisioning pressures, coercion, rivalry, fear, desertion, deception and individual exceptions | Named command hierarchy and motivations; no universal species-alignment table |
| Refugees, freed captives and displaced households | New homes, returned homes, aid, coalition membership and ongoing relationships | Specific cause of displacement, consent to relocation and later choices |
| Traveling performers and storytellers | Entertainment, social information, memory, rhythm, exaggerated personas and distinct voices | Named troupe and era; a song's fictional character is not necessarily a historical person |

Factions are not just combat rosters. A household, crew, religious or cultural community, elected council, imperial command and temporary alliance have different membership semantics. Research records can overlap: a creature may belong to a family, boat crew, settlement and expedition at the same time. The existing simulation specification must own any eventual membership storage and update rules.

## 3. Important corrections and unresolved contradictions

| ID | Source evidence | Resolution / implementation consequence |
| --- | --- | --- |
| CONT-001 | Salamandastron calls Brocktree an earliest/first badger lord; Lord Brocktree names Stonepaw and earlier rulers at blocks 49 and 3383 | The broad founding claim cannot erase explicit predecessors. Use a contested tradition or distinguish founding the Patrol from first occupying the mountain; do not assert a proven universal chronology. |
| CONT-002 | Outcast block 3549 names Sunflash's later Sunstripe identity | Resolved alias; amend earlier uncertainty in current reference entrypoints. |
| CONT-003 | Outcast block 434 identifies greensap milk and nut cheese as a specific plant preparation | Correct any blanket assertion that every source milk or cheese is animal dairy. Equally, do not claim all source cheese is greensap cheese. |
| CONT-004 | Mossflower includes speaking Snakefish; Outcast includes a speaking swamp eel and a mixed swamp following | Canonical sapience does not reduce cleanly to the active game food whitelist. Preserve both source evidence and the deliberate game policy. |
| CONT-005 | Mossflower destroys/floods Kotir; Long Patrol places buried Kotir structures beneath the Abbey's south-wall area | Preserve historical terrain and building change. A precise georeferenced reconciliation remains unproven. Do not flatten every era into one intact fortress/Abbey map. |
| CONT-006 | Lord Brocktree dye is claimed permanent, later washes off | Preserve claim versus observed outcome; blue dye is equipment/costume state, not inherited moral identity. |
| CONT-007 | Lord Brocktree's final shore action has no allied deaths, while earlier battles kill named allies and enemies drown | “Bloodless” cannot describe the whole campaign or erase previous losses. |
| CONT-008 | Outcast narrator depicts Veil's protective intervention; Meriam and Bryony later judge him differently | Keep behavior, intention uncertainty and character judgments separate. Do not turn one judgment into a genetic morality mechanic. |
| CONT-009 | Source dreams and visions sometimes receive stronger confirmation than the project's uncertain-wonder direction | Label selective ambiguity as adaptation; do not falsely claim all novels keep truth uncertain. |
| CONT-010 | Source mercy coexists with torture, captives used as shields, no-quarter commands and coercive punishment | Retain critical evidence, implement the user's boundaries and accepted admission policy, and leave unresolved offscreen treatment open. Apply the existing bible §12.5 interim guard excluding new game depictions, backstory, implied threats and offscreen events involving the named subjects; this guard is an agent interpretation. |
| CONT-011 | Redwall's early-world references and later books do not supply a single consistent scale/sapience ecology | Use the adopted 1.0 m mouse model anchor and recognizable anatomy as project choices; no canonical measured biological scale is asserted. |
| CONT-012 | Salamandastron source has a broken passage around blocks 3498–3501, apparently printed pages 314–315 | No reconstruction is canon. Source integrity remains limited even with 100% of available normalized blocks inspected. |

The supplied Rakkety Tam text adds two further continuity flags: Zerig is explicitly killed at block 249 and active again at 284–285; Didjety, otherwise a vole, is called a shrew at 456. Preserve these as source conflicts pending edition comparison. Do not invent resurrection, a second Zerig or a species change to conceal them. The book dossier also retains its duel-witness headcount inconsistency.

## 4. Knowledge and appearance contract

For every planned source character, the scenario author must state a selected source era, role at entry, known injuries, household and office, owned or borrowed significant items, and whether the reference is living presence, remembered history, story performance or uncertain vision. These are authoring requirements, not new runtime columns.

| ID | EARS rule |
| --- | --- |
| CONT-E01 | When two records share a title, the author shall require explicit identity evidence before linking them as the same individual. |
| CONT-E02 | When a framing narrator recounts an earlier campaign, the scenario shall separate frame residents and campaign residents. |
| CONT-E03 | When an office changes hands, the author shall keep the previous holder's history and select the scenario's current holder. |
| CONT-E04 | When a death is rumored and later contradicted, the scenario shall preserve the rumor as knowledge and the later survival as historical state. |
| CONT-E05 | When an adaptation changes a source outcome or moral framing, the author shall identify the source event and the deliberate change. |

No dates, absolute ages, travel durations, population totals or diplomatic modifiers are newly asserted by this reconciliation.
