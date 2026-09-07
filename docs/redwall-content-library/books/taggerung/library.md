# The Taggerung — systematic content library

## Status and reading boundary

All 4,065 normalized source blocks were sequentially inspected across 22 chunks. This dossier is a content and direction reference, accompanied by source-located `catalog.json`, recipe candidates in `recipes.json`, and a complete inspected-range ledger in `coverage.json`. It contains paraphrases and locators, not reproduced chapters or lyrics. Full reading coverage is distinct from proving that every possible interpretation has been cataloged.

The book's frame and epilogue occur after its central events. Rosabel is Fwirl and Broggle's squirrel daughter; the epilogue reveals relationships and later occupations that the opening deliberately withholds. An implementation must retain these era differences. Fifteen *seasons* is a source interval, not fifteen years.

## Direction dossier

The central game opportunity is identity earned through repeated acts of care. Deyna's marks and upbringing encourage enemies and friends to misread him, while his decisions, relationships and eventual office create a different identity. This is also an imperfect moral story: he refuses execution of a helpless captive, later uses coercive interrogation, and eventually kills in a rescue/revenge sequence. Keep that tension in analysis; the project's exclusion of torture and cruelty toward children takes precedence over reproducing source actions.

Redwall should visibly cook, mend, teach, clean, care, tell stories, debate and remember. Those activities do not merely fill time between battles. Mhera becomes credible through rescue, delegation, listening to dissent, attention to grief and protection of elders. The puzzle book confirms observed fitness. It does not magically appoint the best solver. Fwirl's nonliteracy does not diminish her exceptional climbing or practical judgment; Broggle teaches needlework as well as preparing food. Occupations are learned competencies, not gender or species locks.

The feeling moves between warm inhabited rooms and exposed travel. Use rain against lit windows, steam and crust texture, colored glass, embroidered linen, root ceilings and the smell of herbs. Outdoors, terrain must be specific: misleading reeds over deep water, cold mountain ridges with poor fuel, flood channels that were dry, a river-cooled cider sack, and tide pools whose safe access changes. Home feels different because people maintain it and make room for a stranger.

Grief remains visible during joy. Filorn can enjoy a feast and then cry over a familiar soup. Cregga's final banquet honors a living friend before her death. Flowers are renewed at her grave; a forged medallion arrives from another institution; her room becomes a historian's office. Preserve consequences through routines, spaces, objects and relationships, without requiring a permanent grief debuff or a supernatural resurrection.

Comedy should be warm and situated: cooks repairing a trifle accident, obvious contests of impossible boasts, a formidable healer unexpectedly joining a joke, imperfect learners and ordinary household frustrations. Where teasing wounds someone, the story also supplies apology and repair. Distinct voices require rhythm, vocabulary and personal concerns; heavy eye dialect and species caricature are unnecessary.

Russano demonstrates an alternative to a berserk military climax: enormous organized force, calm restraint, surrender and a memorial visit. His source escort still humiliates captives. The game adaptation should retain disarmament and escorted departure while removing forced crawling and degradation. Dream reports and home-singing remain interpretively uncertain, matching the project's decision about supernatural truth.

## Source-grounded topology

The following is a qualitative graph based on blocks 1211–1232, 2339–2355, 3137–3160 and 3968–3976. It is not a measured build grid, and its directions are specific to this book.

```text
                              NORTH / MOSSFLOWER
              +---------------------------------------------+
              | gardens / beehives / lawns       grave NE   |
              |                                             |
WEST FLATLAND | Gatehouse       ABBEY BUILDING      ORCHARD  | EAST WOODS
  <- ditch <- | MAIN GATE       Great Hall / rooms           | -> east wicket
       path   |                cellars / kitchens            |
              |                     POND                     |
              |                     ASH                      |
              +---------------- south wicket ----------------+
                       SOUTH ROAD / WOODLAND EDGE
```

The small south wicket and separate wood-delivery cellar door are different entries. The main west gate remains distinct from a southern lookout's sightline. Outside the Abbey, a hidden multi-family vole burrow, open branch platform, high-bank shrew den, terraced cavern settlement, log cottage with sod roof, and traveling raft create materially different dwellings. The northern snowy mountain is not automatically Salamandastron.

## EARS constraints for downstream specifications

| ID | Requirement |
|---|---|
| TAG-CONT-001 | WHEN a source dish uses a nonwhitelisted animal ingredient, the content importer SHALL retain the source record and SHALL expose only a separately named compliant game counterpart as a candidate. |
| TAG-CONT-002 | WHEN an ingredient is absent from the source, the recipe record SHALL mark its proposed addition `AI_AUTHORED_GAME_ADAPTATION` with confidence and rationale. |
| TAG-CONT-003 | WHEN a source statement is a dream, omen, song persona, boast or deliberate lie, the lore layer SHALL retain that evidence class and SHALL NOT promote it to objective world history. |
| TAG-CONT-004 | WHILE a scenario uses post-reform Cavemob culture, its customs SHALL exclude sacrifice, ear-smacking and tail-kicking. |
| TAG-CONT-005 | WHEN a character attempts climbing, the movement specification SHALL evaluate individual capability, route geometry, equipment and assistance separately from species. |
| TAG-CONT-006 | WHEN a route changes from dry channel to floodwater, the route data SHALL distinguish walking, swimming, boating, rescue and inaccessible states. |
| TAG-CONT-007 | WHEN a recipe is converted for guard duty, its serving form SHALL preserve a relationship to the source dish and its portable counterpart. |
| TAG-CONT-008 | WHEN an injured or frail resident cannot use stairs, a care activity SHALL be placeable in an accessible room and preserve carrier access. |
| TAG-CONT-009 | WHEN a community records a death, its scenario content SHALL support a persistent memorial or changed routine without requiring revival. |
| TAG-CONT-010 | WHEN surrender resolves an encounter, the adaptation SHALL support disarmament and escorted withdrawal without torture or humiliating punishment. |
| TAG-CONT-011 | WHEN an actor is identified from appearance alone, the narrative state SHALL distinguish suspicion from verified identity. |
| TAG-CONT-012 | WHEN a role changes between central narrative and epilogue, the content record SHALL preserve both appearances with their era and source locators. |

These are authored content constraints, not inherited engine implementations. They introduce no population cap, resource rate, health value, recipe quantity or traversal cost.

## Recipe interpretation rules

`source_ingredients` contains only directly named components or components explicit in a dish name. A named white cheese does not prove a cow, dairy industry or nut base. `inferred_game_ingredients` completes missing binders, liquids, seasonings or substitutions; every such entry is authored, even when plausible. An unspecified cheese becomes an explicitly named cultured hazelnut product; meadowcream becomes oat cream. The source greensap drink is already plant-derived, but choosing birch is still an inference.

Shrimp/scallop becomes a renamed mussel dish; sole, vendace and burbot become whitefish counterparts; elver preparations become dace counterparts. Giant Yo Karr pie is a rejected joke, and eel remains a nonharvestable hazard. Predatory bird, egg, frog and lizard references remain source facts with renamed plant counterparts. Source comfrey, milkweed, bindweed, uncertain penny-plants and fictional healer lore are not safe recipes or medical instructions. Their proposed game dishes use explicitly different plants.

The strongest source preparation anchors are Lollery's corn/nutmeal pancakes with honey and chopped berries; Rawback's nut/wild-oat/barley stone cakes; Broggle's three-nut farls; Skipper's shrimp/hotroot/pepper/scallion soup; Jurkin's mixed-fruit duff and vanilla-almond white sauce; and the jointly named filboonimgun cheese. Each still leaves details unspecified. October Ale is explicitly secret. No full recovered recipe can be claimed for it.

## Contradictions and decisions retained

| Issue | Source evidence | Required interpretation |
|---|---|---|
| Rawback presumed dead | 3310–3316 versus 3863–3886 | Earlier death assumption is false; survivor testimony corrects it. |
| Tattoo removal and consent | Rukky scenes 3451–3758; Rosabel explanation 4059 | Epilogue reports permission, tattoo removal and birthmark covering; exact process remains unspecified. |
| Broggle's speech | 354–369 versus 3230 | Improvement through singing does not establish permanent cure; stress recurrence remains in characterization. |
| Child and prisoner cruelty | Multiple antagonistic scenes; Tagg interrogation 2368–2404 | Retain minimal analytic context; exclude playable torture and child cruelty. |
| Mercy and humiliation | 4016–4036 | Adapt escort without forced crawling or degradation. |
| Guest capacity | 4051–4056 | Russano and Mhera disagree; neither assertion is a calibrated storage rule. |
| Ash-tree clue | 1489–1494 | Claimed rising of an existing branch through growth is botanically questionable; author a physically plausible movement of the sightline if implemented. |
| Wax/honey rubbing | 1739–1755 | Material transfer needs a workable authored prop method, not blind literal execution. |
| Strawberry fizz age | 2312–2317 | Ten-summer aging and cordial language do not constitute validated fermentation instructions. |
| Filboonimgun process | 3913–3914 | Three days and boiling juice/cider wording is narrative description, not validated food processing. |
| Northern mountain identity | 1889–1914 | Do not merge it with coastal Salamandastron absent evidence. |
| Ribrow's camp directions | 2385–2404 | A coerced recollection is not sufficient to force precise map reconciliation. |
| Fox marks / species | 3626–3645; Nimbalo 3129 | Preserve literal Ruggan tail description and harvest-mouse/fieldmouse wording inconsistency rather than silently inventing changes. |
| Hohen / Hoben | 4060–4062 | Apparent spelling/extraction variant, same Recorder. |
| K-prefixed cloth | KITTAGALL references versus final decoding | Kindness may be a plausible completion, but do not claim an explicit final decoded word without its source. |

## Catalog index

Every following row links a candidate to inspected blocks. Exact EPUB member and unit-block locators are included in the JSON. Repeated appearances are retained as multiple facts rather than duplicate fictional people.


### Character (101)

| ID / label | Source-located facts |
|---|---|
| `TAG_character_rosabel` — Rosabel | Female assistant Recorder in the frame; learns history gathering, composition and public reading from Hoben. [3–7; NARRATOR]<br>Epilogue identifies her as squirrelmaid daughter of Fwirl and Broggle and promotes her to Recorder; her manuscript is archived after four evenings of reading. [4058–4065; NARRATOR] |
| `TAG_character_brother_hoben` — Brother Hoben | Elderly Recorder and mentor, prone to sleeping during long manuscripts. [3–7; NARRATOR]<br>Retires to assist bedridden Hoarg at the gatehouse. Hohen in the epilogue is an apparent extraction/spelling variant of Hoben. [4060–4062; NARRATOR] |
| `TAG_character_sawney_rath` — Sawney Rath | Small, fast ferret chieftain of sixty Juskarath; chronic stomach distress, jeweled throwing knife, fear-based rule and Taggerung ambitions. [12–51; NARRATOR] |
| `TAG_character_grissoul` — Grissoul | Vixen seer and cook; barkcloth marked with red-black symbols, coral/brass/silver ornaments, divination equipment and political influence. [14–51; NARRATOR] |
| `TAG_character_antigra` — Antigra | Stoat mother of baby Zann, widow of challenger Gruven; ambitious and constrained by Sawney's violence. [24–43; NARRATOR] |
| `TAG_character_gruven_the_elder` — Gruven the elder | Antigra's mate, killed after challenging Sawney; distinct from their son later forced to bear his name. [24–43; NARRATOR] |
| `TAG_character_zann_the_former_taggerung` — Zann the former Taggerung | Sawney's deceased father, remembered as Zann Juskarath Taggerung; distinct from Antigra's child. [45–50; NARRATOR] |
| `TAG_character_eefera` — Eefera | Weasel attendant and experienced hunter who handles Sawney's knife; later rivals Vallug and abandons Gruven. [49–51; NARRATOR] |
| `TAG_character_cluny` — Cluny | Historical antagonist invoked in Sawney's account, not a contemporary participant. [57–57; NARRATOR] |
| `TAG_character_slagar` — Slagar | Historical antagonist invoked in Sawney's account, not a contemporary participant. [57–57; NARRATOR] |
| `TAG_character_ferahgo` — Ferahgo | Historical antagonist invoked in Sawney's account, not a contemporary participant. [57–57; NARRATOR] |
| `TAG_character_drogg_spearback` — Drogg Spearback | Hedgehog Cellarkeeper, grandfather of Egburt and Floburt, council member and keeper of food-and-drink traditions. [72–88; NARRATOR] |
| `TAG_character_egburt` — Egburt | Hedgehog Dibbun and Drogg's grandson; grows into helper, temporary wallguard commander and eventual healer. [72–88; NARRATOR]<br>Brother Egburt and Sister Floburt become Infirmary Keepers, making palatable remedies. [4063–4063; NARRATOR] |
| `TAG_character_floburt` — Floburt | Hedgehog Dibbun and Drogg's granddaughter; solves a compass clue and later becomes an Infirmary Keeper. [72–88; NARRATOR]<br>Sister Floburt and Brother Egburt succeed Alkanet as Infirmary Keepers. [4063–4063; NARRATOR] |
| `TAG_character_gundil` — Gundil | Mole Dibbun who grows into cook's helper, Mhera's trusted friend and eventual Foremole. [72–88; NARRATOR]<br>Eventually Foremole, leading a crew to furnish Rosabel's office. [4062–4062; NARRATOR] |
| `TAG_character_cregga_rose_eyes` — Cregga Rose Eyes | Blind, elderly Badgermum; former military leader whose authority now rests in patient care, experience and relationships. [83–83; NARRATOR]<br>Shot in a disrupted hostage confrontation when Nimbalo strikes Vallug's elbow; she dies during her honor feast after nominating Mhera. [3289–3618; NARRATOR]<br>Her grave is in the northeast wall corner. Russano offers a steel portrait medallion with ruby eyes, and her old room later becomes Rosabel's office. [3692–4062; NARRATOR] |
| `TAG_character_tansy` — Tansy | Former Abbess whom Cregga outlived; historical reference only. [83–83; NARRATOR] |
| `TAG_character_songbreeze` — Songbreeze | Former Abbess Song, whose leadership teaching and handmade puzzle legacy guide Mhera. [83–83; NARRATOR] |
| `TAG_character_arven` — Arven | Past Champion remembered by Cregga; historical reference only. [83–83; NARRATOR] |
| `TAG_character_gurgan_spearback` — Gurgan Spearback | Drogg's great-grandfather, remembered by Cregga; do not merge with contemporary cellarhog. [83–83; NARRATOR] |
| `TAG_character_friar_bobb` — Friar Bobb | Squirrel head cook, food teacher and affectionate authority; eventually succeeded by Broggle. [94–94; NARRATOR] |
| `TAG_character_filorn` — Filorn | Otter cook, mate of Rillflag and mother of Mhera and Deyna; long grief, everyday care and eventual reunion remain simultaneous parts of her identity. [100–110; NARRATOR] |
| `TAG_character_rillflag` — Rillflag | Otter father, council member, woodcarver and skilled swimmer; observes the river-back newborn rite rather than using the still Abbey pond. [100–129; NARRATOR] |
| `TAG_character_mhera` — Mhera | Rillflag and Filorn's otter daughter, older than the Dibbun trio; grows into an experienced, compassionate community leader and Abbess. [100–110; NARRATOR]<br>Appointed through Cregga's nomination and community approval after demonstrated leadership; cipher book confirms rather than replaces this process. [3555–3739; NARRATOR] |
| `TAG_character_deyna` — Deyna | Infant otter named for his father's warrior great-grandsire; right-paw pink speedwell-shaped birthmark has four petals, one thinner. [100–129; NARRATOR]<br>Kidnapped and renamed Zann Juskarath Taggerung, called Tagg; face black stripe/red dots and blue left-cheek lightning. As a youth wears barkcloth kilt, eelskin belt, flax wristbands, gold hoop and fishbone tailrings. [191–620; NARRATOR]<br>Publicly becomes Warrior of Redwall with Martin's sword. Rosabel later explains he allowed tattoo removal and covering of the speedwell birthmark to live peacefully beyond Juska pursuit. [3980–4059; CHARACTER_REPORT] |
| `TAG_character_deyna_the_ancestor` — Deyna the ancestor | Rillflag's warrior great-grandsire and namesake of the newborn; separate historical individual. [100–110; NARRATOR] |
| `TAG_character_sister_alkanet` — Sister Alkanet | Stern mouse healer and council member; concerned about defense, capable practical care, later learns cellarkeeping. [130–150; NARRATOR]<br>Becomes Drogg's Assistant Cellarkeeper; the community jokes about the resulting odd-tasting cordials. [4063–4063; NARRATOR] |
| `TAG_character_foremole_brull` — Foremole Brull | Female mole work-crew leader and councillor; competent, kindly and accepted in her office. [130–150; NARRATOR] |
| `TAG_character_broggle` — Broggle | Squirrel kitchen assistant with a stammer, musical and needlework talent, later Fwirl's partner and Head Cook. [130–146; NARRATOR]<br>Singing temporarily eases his stammer, but stress brings it back; do not represent an instant guaranteed cure. Later Head Cook and skilled embroiderer. [354–369; NARRATOR]<br>Stress-associated stammer is visible again during the gate crisis. [3230–3230; NARRATOR]<br>Father of Rosabel, partner of Fwirl, Head Cook after Friar Bobb; helps embroider a coverlet. [4062–4064; NARRATOR] |
| `TAG_character_martin_the_warrior` — Martin the Warrior | Remembered mouse founder-warrior, tapestry and sword icon; appearances in dreams are reported experiences rather than verified supernatural mechanics. [148–151; NARRATOR] |
| `TAG_character_matthias` — Matthias | Historical hero represented by a bell name and later bell-history teaching, not a contemporary resident. [151–151; NARRATOR] |
| `TAG_character_methuselah` — Methuselah | Historical figure represented by a bell name, not a contemporary resident. [151–151; NARRATOR] |
| `TAG_character_rawback` — Rawback | Stoat scout and camp deputy; follows the Taggerung hunt, later wrongly presumed dead in a swamp. [154–207; NARRATOR]<br>Gruven assumes his swamp death after screams cease; later search finds him alive. Rawback says an overhead branch allowed a two-day escape; his eyewitness gate-battle account proves useful. [3310–3316; CHARACTER_REPORT]<br>Alive when found, eating frogs and lizards; recruited into Juskabor, gives a detailed account contrasting Gruven's false testimony. [3863–3886; NARRATOR] |
| `TAG_character_dagrab` — Dagrab | Rat hunter; later explicitly female and identified as the killer of Nimbalo's father. [154–207; NARRATOR] |
| `TAG_character_felch` — Felch | Fox with an injured paw, abused by clan leadership; Tagg spares him, but Antigra later kills him to silence a witness. [154–207; NARRATOR] |
| `TAG_character_vallug_bowbeast` — Vallug Bowbeast | Ferret archer who kills Rillflag and participates in the kidnapping; dangerous experienced tracker, later slain by Deyna. [154–207; NARRATOR] |
| `TAG_character_ribrow` — Ribrow | Stoat hunter and long-serving clan witness; later captured and killed by vengeful Cavemob members after Tagg promises mercy. [154–207; NARRATOR] |
| `TAG_character_wherrul` — Wherrul | Rat responsible for track cleanup; later changes allegiance to Ruggan's Juskabor. [154–207; NARRATOR] |
| `TAG_character_gruven` — Gruven | Antigra's baby Zann is forcibly renamed Gruven; later claims leadership and the Taggerung title without its alleged deed. [191–207; NARRATOR] |
| `TAG_character_hoarg` — Hoarg | Ancient dormouse gatekeeper, reader with crystal spectacles and participant in Cregga's teaching scheme; later needs bedside care. [209–239; NARRATOR] |
| `TAG_character_skipper_of_otters` — Skipper of Otters | Unnamed leader of Redwall's tattooed otter crew; searcher, fighter, skilled shrimp-soup cook and trusted intermediary with Rukky. [209–239; NARRATOR] |
| `TAG_character_boorab` — Boorab | Traveling hare musician and comic storyteller, later wallguard commander and courageous messenger; handcrafted haredee gurdee accompanies appetite and elaborate speech. [320–339; NARRATOR]<br>Full name Bellscut Oglecrop Obrathon Ragglewaithe Audube Baggscut; becomes Assistant Cook in the epilogue. [389–392; NARRATOR]<br>Boorab becomes Assistant Cook and behaves well under Filorn's supervision; Nimbalo succeeds him as Master of Music. [4062–4062; NARRATOR] |
| `TAG_character_white_goose_patient` — White goose patient | Unnamed goose whose injured wing pinion Alkanet healed; recommends Redwall to Boorab. [337–339; NARRATOR] |
| `TAG_character_pieface_baggscut` — Pieface Baggscut | Boorab's grandfather, a leveret runner under Cregga; transmitter of military song and memory. [389–392; NARRATOR] |
| `TAG_character_grobait` — Grobait | Rat tracker in the search party; later found dead in a flood after the mountain pursuit. [443–448; NARRATOR] |
| `TAG_character_milkeye` — Milkeye | One-eyed weasel hunter, eats a raw scallop and later dies from Krobzy's poisoned dart. [452–454; NARRATOR] |
| `TAG_character_wummple` — Wummple | Kindly mole who volunteers as washerbeast so others can enjoy the feast. [536–536; NARRATOR] |
| `TAG_character_janglur_swifteye` — Janglur Swifteye | Song's father, maker of her carved squirrel-shaped gift bottle; remembered artisan rather than contemporary participant. [639–650; NARRATOR] |
| `TAG_character_gundil_s_grandfather` — Gundil's grandfather | Unnamed deceased mole associated with a similar carved bottle, recalled through a family keepsake. [639–650; NARRATOR] |
| `TAG_character_birrel` — Birrel | Mousemaid who contributes to the collaborative classroom letter puzzle. [978–978; NARRATOR] |
| `TAG_character_dingle` — Dingle | Duck character in a comic song; a nested fictional character, not a mapped historical resident. [1007–1030; NARRATOR] |
| `TAG_character_doctor_black` — Doctor Black | Fox doctor in the same comic duck song; nested fiction, not a canonical medical practitioner at Redwall. [1007–1030; NARRATOR] |
| `TAG_character_krobzy` — Krobzy | Bankvole head of a multi-family homestead; quick to defend guests and later avenges an arrow wound with a dart. [1121–1154; NARRATOR] |
| `TAG_character_prethil` — Prethil | Krobzy's wife, part of the hospitable vole household. [1121–1154; NARRATOR] |
| `TAG_character_sekkendin` — Sekkendin | Watervole deputy; wounded in a hindpaw by Vallug while the household protects its guest. [1121–1154; NARRATOR] |
| `TAG_character_rakkadoo` — Rakkadoo | Vole-community gob musician, using voice and rhythm alongside jaw harps; individual subtype not established here. [1152–1171; NARRATOR] |
| `TAG_character_rabbad` — Rabbad | Small fox in the hunting party; later killed in a dangerous river crossing and fish attack. [1181–1323; NARRATOR] |
| `TAG_character_fwirl` — Fwirl | Solitary squirrelmaid with large almond eyes, red-gold curled tail and short green tunic; expert treewhiffler, initially nonliterate, later resident, partner and mother. [1242–1282; NARRATOR]<br>Nonliterate expert climber collaborates through rubbings and verbal help; later learns needlework from Broggle and becomes Rosabel's mother. [1754–1755; NARRATOR]<br>Survives an arrow wound despite an initial mistaken death cry; romantic and practical support matter during recovery. [2965–2989; NARRATOR] |
| `TAG_character_perigord_habile_sinistra` — Perigord Habile Sinistra | Deceased saber-fighting hare of Salamandastron who gave Cregga the monocle later used in a puzzle. [1276–1276; NARRATOR] |
| `TAG_character_durby_furrel` — Durby Furrel | Mole Dibbun, pond paddler and performer, later involved in a missing-child rescue. [1235–1238; NARRATOR] |
| `TAG_character_durby_s_mother` — Durby's mother | Unnamed mole mother whose door-lintel growth marks anchor everyday care and a clue discussion. [1454–1462; NARRATOR] |
| `TAG_character_botarus` — Botarus | Male bittern with brown-black-fawn camouflage, green legs and strong bill; cares for Madd and guides Tagg away from danger. [1515–1549; NARRATOR] |
| `TAG_character_madd` — Madd | Female squirrel named Madd by Botarus after traumatic injury and family loss; violence and confusion complicate simple species morality. [1539–1549; NARRATOR] |
| `TAG_character_nimbalo_the_slayer` — Nimbalo the Slayer | Small harvest mouse in a yellow tunic, skilled forager and whistle player; extravagant boasts conceal an abusive childhood and longing for companionship. [1559–1691; NARRATOR]<br>His father was killed by Dagrab. He mourns privately despite childhood abuse; later becomes Master of Music and learns the haredee gurdee. [2783–2919; NARRATOR]<br>Called fieldmouse once during hostile identification, otherwise harvest mouse; preserve dominant species and source inconsistency. [3129–3129; NARRATOR] |
| `TAG_character_ruskem` — Ruskem | Elderly toothless shrew living alone in a flood-safe bank den; slate portrait maker, generous host and keeper of family memory. [1665–1727; NARRATOR] |
| `TAG_character_ruskem_s_family` — Ruskem's family | Unnamed late wife, parents, grandparents and children preserved in portraits; some children died and others moved away, not all deaths specified. [1702–1709; NARRATOR] |
| `TAG_character_nimbalo_s_father` — Nimbalo's father | Unnamed abusive farmer, later found killed; Nimbalo still mourns and privately tends his body. [1686–1691; NARRATOR] |
| `TAG_character_nimbalo_s_mother` — Nimbalo's mother | Absent mother with uncertain whereabouts; do not invent her death or a verified reason for leaving. [2783–2809; NARRATOR] |
| `TAG_character_feegle` — Feegle | Tiny mousemaid Dibbun performer; later rescued with Durby. [1824–1824; NARRATOR] |
| `TAG_character_wegg` — Wegg | Small hedgehog toddler, later rescued from the pond and a large grayling. [1824–1824; NARRATOR] |
| `TAG_character_alfik` — Alfik | Pigmy shrew scout and son of Cavemob chief Bodjev. [1939–1969; NARRATOR] |
| `TAG_character_bodjev` — Bodjev | Cavemob chief, father and host; publicly accepts reforms ending sacrifice and physical family punishment. [1939–1969; NARRATOR] |
| `TAG_character_chich` — Chich | Bodjev's wife and head cook, also called Chichwife; skilled pie maker and forceful domestic voice. [1986–2042; NARRATOR] |
| `TAG_character_dinat` — Dinat | One of Bodjev and Chich's four daughters, rescued from the lake sacrifice ritual. [1986–2042; NARRATOR] |
| `TAG_character_dinat_s_three_sisters` — Dinat's three sisters | Three unnamed daughters of Bodjev and Chich; do not invent names or merge with Dinat. [1986–2042; NARRATOR] |
| `TAG_character_cavemob_ritual_elder` — Cavemob ritual elder | Unnamed robed shrew who directs the lake ritual, part of a practice subsequently abolished. [2001–2026; NARRATOR] |
| `TAG_character_yo_karr` — Yo Karr | Giant eel treated as a lake power by Cavemob belief; dangerous creature, not evidence of a supernatural deity and not a food harvest. [2001–2040; NARRATOR] |
| `TAG_character_trey` — Trey | Youngest Abbey mousebabe; anxious witness, strawberry-patch explorer and trifle-accident comic participant. [2335–2344; NARRATOR] |
| `TAG_character_robald_forthright` — Robald Forthright | Educated, formally spoken hedgehog, poor fighter and dependent on his old nurse for cooking; later contributes literary and musical gifts. [2420–2509; NARRATOR] |
| `TAG_character_great_aunt_lollery` — Great-Aunt Lollery | Elderly thin gray-spiked hedgehog, Robald's former nurse and cook, not his biological aunt; Dillypin relative and warm host. [2470–2509; NARRATOR] |
| `TAG_character_jurkin_dillypin` — Jurkin Dillypin | Raft-family leader and skilled slinger, proud spiketussler who becomes Tagg's friend after a respectful contest. [2463–2507; NARRATOR] |
| `TAG_character_poskra` — Poskra | Isolated water rat, expelled for theft and cruelty; one tooth shapes his food texture, and his hostage-taking ends with Vallug killing him. [2567–2593; NARRATOR] |
| `TAG_character_tingle` — Tingle | Jurkin's niece, a singer whose river song evokes longing and private grief. [2815–2872; NARRATOR] |
| `TAG_character_campathia_forthright` — Campathia Forthright | Southern Forthright matriarch, class-conscious camper; relationship to Robald's eastern branch is not specified as close kin. [2874–2908; NARRATOR] |
| `TAG_character_merradink_forthright` — Merradink Forthright | Campathia's husband, echoing her remarks in the southern family group. [2874–2908; NARRATOR] |
| `TAG_character_pecunia_forthright` — Pecunia Forthright | Young daughter in the southern Forthright family. [2874–2908; NARRATOR] |
| `TAG_character_swash` — Swash | One of two sturdy otter sisters in Skipper's crew, assists care and transport. [3439–3447; NARRATOR] |
| `TAG_character_blekker` — Blekker | Swash's sister, otter helper who cautions that Rukky's return date is approximate. [3439–3447; NARRATOR] |
| `TAG_character_rukky_garge` — Rukky Garge | Ancient toothless silver-white otter healer and tattoo artist; jeweled black cloak, private river cave, firm touch boundaries and specialized care. [3356–3480; NARRATOR]<br>Tattoo removal and birthmark covering are later explained by Rosabel as permitted for Deyna's peace; no exact procedure or medical recipe is provided. [4059–4059; CHARACTER_REPORT] |
| `TAG_character_gruzzle` — Gruzzle | Large female weasel guard in Ruggan's camp. [3626–3645; NARRATOR] |
| `TAG_character_ruggan_bor` — Ruggan Bor | Golden fox, Lord of the Southern Coasts and Juskabor chief; black cloak/kilt, chain belt and saber, strategic and ruthless. [3626–3645; NARRATOR] |
| `TAG_character_ermath` — Ermath | Elder vixen seer who supports Ruggan's authority and later ratifies his Taggerung claim. [3626–3645; NARRATOR] |
| `TAG_character_colonel_stiff` — Colonel Stiff | Officer named in the Battle of Boiling Water song; nested song persona, not verified historical officer. [3586–3593; NARRATOR] |
| `TAG_character_sergeant_biff` — Sergeant Biff | Wooden-legged officer in the Battle of Boiling Water song; nested fiction or unverified tradition. [3586–3593; NARRATOR] |
| `TAG_character_corporal_black` — Corporal Black | Officer in the Battle of Boiling Water song; nested tradition, no independent biography established. [3586–3593; NARRATOR] |
| `TAG_character_small_fat_cook_of_the_march_song` — Small fat cook of the march song | Unnamed comic cook in the same traditional military song; do not merge with Friar Bobb. [3586–3593; NARRATOR] |
| `TAG_character_spike_of_the_duet` — Spike of the duet | Young hedgehog in a comic romantic song, with a mother and a frog; all nested song figures, not residents. [3926–3945; NARRATOR] |
| `TAG_character_russano_the_wise` — Russano the Wise | Badger Lord of Salamandastron, Cregga's former ward, calm and restrained military authority; arrives with a thousand Long Patrol hares. [4014–4051; NARRATOR] |
| `TAG_character_russano_s_colonel` — Russano's colonel | Unnamed older hare, stiff whiskers, monocle and lance; leads the escort after surrender. [4019–4035; NARRATOR] |
| `TAG_character_two_long_patrol_sergeants` — Two Long Patrol sergeants | Unnamed disciplined hares who organize the escorted withdrawal. [4035–4035; NARRATOR] |
| `TAG_character_gruven_s_six_guards` — Gruven's six guards | Unnamed Juskabor escort includes a tough vixen, a scar-faced lance rat and a muscular spear ferret; distinguish role-group from invented individuals. [3819–3832; NARRATOR] |

### Faction (17)

| ID / label | Source-located facts |
|---|---|
| `TAG_faction_juska_clans` — Juska clans | Independent nomadic mixed-species clans named after their chief; seers, challenge succession and Taggerung legends mediate power. [12–65; NARRATOR] |
| `TAG_faction_juskarath` — Juskarath | Sawney's sixty-member clan; black stripe with red-dot face lines and coercive provisioning hierarchy. [12–65; NARRATOR] |
| `TAG_faction_juskazann` — Juskazann | Renamed clan under Gruven Zann after Antigra and Grissoul stage a false explanation of Sawney's death. [1088–1116; NARRATOR] |
| `TAG_faction_juskabor` — Juskabor | Ruggan's roughly three-hundred-strong clan absorbs Juskazann; green wavy brow marks and yellow cheek circles overlay previous tattoos. [3626–3678; NARRATOR] |
| `TAG_faction_abbey_council` — Abbey council | Brull, Cregga, Hoben, Bobb, Alkanet, Drogg and Rillflag coordinate a community without a current Abbess or Champion. [135–150; NARRATOR] |
| `TAG_faction_redwall_community` — Redwall community | Leadership nomination requires public acceptance and already demonstrated care, judgment and practical work. [3555–3567; NARRATOR] |
| `TAG_faction_redwall_otter_crew` — Redwall otter crew | Forty otters attend the periodic Hullabaloo; absence creates a temporary defense gap and requires substitutes. [2146–2150; NARRATOR] |
| `TAG_faction_jolly_dibbuns_choir` — Jolly Dibbuns Choir | Children's ensemble with lanterns, playful parody and communal rather than exclusionary rewards. [468–515; NARRATOR] |
| `TAG_faction_abbey_school` — Abbey school | Hoben teaches collaborative letter solving; pupils' individual discoveries are publicly appreciated. [961–1003; NARRATOR] |
| `TAG_faction_vole_homestead` — Vole homestead | Bank, water and field vole households share a hidden pear-hill burrow, food, music and protective responsibility. [1139–1173; NARRATOR] |
| `TAG_faction_madd_and_botarus` — Madd and Botarus | A traumatized squirrel and her bittern caregiver form a small interdependent household beyond formal factions. [1539–1549; NARRATOR] |
| `TAG_faction_cavemob` — Cavemob | Thousands of pigmy shrews maintain cavern food production and terrace farms; public reform abolishes sacrifice and physical family punishment. [1984–2057; NARRATOR] |
| `TAG_faction_dillypin_raft_family` — Dillypin raft family | Extended traveling hedgehog community with shared food, watches, songs, contests and child-safety ropes. [2463–2531; NARRATOR] |
| `TAG_faction_eastern_forthrights` — Eastern Forthrights | Robald identifies with the eastern family branch; do not assume exact genealogical relationships to southern campers. [2874–2908; NARRATOR] |
| `TAG_faction_southern_forthrights` — Southern Forthrights | Campathia, Merradink and Pecunia form the named southern family camping group. [2874–2908; NARRATOR] |
| `TAG_faction_long_patrol` — Long Patrol | A thousand hares arrive with Russano; coordinated encirclement enables surrender without battle, while lodging them raises hospitality concerns. [4014–4051; NARRATOR] |
| `TAG_faction_salamandastron` — Salamandastron | Mountain institution of military leadership, memory, metalworking and Cregga's legacy; Russano is its current Badger Lord. [4039–4049; NARRATOR] |

### Place (40)

| ID / label | Source-located facts |
|---|---|
| `TAG_place_coastal_scrub_camp` — Coastal scrub camp | Juskarath tents beyond dunes near incoming-tide fishing, separated from the kidnapping ford by several narrative marching days. [12–65; NARRATOR] |
| `TAG_place_kidnapping_ford` — Kidnapping ford | Stream crosses the north-south Mossflower path north of Redwall; current matters to the newborn otter rite, unlike the still Abbey pond. [121–201; NARRATOR] |
| `TAG_place_north_bank_river_camp` — North-bank river camp | Broad-stream camp roughly half a day from the ford; later withdrawal goes toward the shores. [154–155; NARRATOR] |
| `TAG_place_redwall_abbey` — Redwall Abbey | From south wall facing inward: north beehives/gardens/lawns; west main gate and gatehouse; east orchard; pond south of Abbey building and ash between pond and south wall. [1211–1232; NARRATOR] |
| `TAG_place_great_hall` — Great Hall | Tapestry wall has fluted half-columns and lantern holders; conserved slate clue is removed to archives during routine maintenance. [886–909; NARRATOR] |
| `TAG_place_cavern_hole` — Cavern Hole | Communal indoor space for full-attendance reading over four evenings; also ordinary meals and entertainment. [4058–4059; NARRATOR] |
| `TAG_place_abbey_kitchen_and_larder` — Abbey kitchen and larder | Warm workspaces with trolley routes, a floor dip, ovens and improvised beds; volunteers sustain searchers and routine meals. [209–262; NARRATOR] |
| `TAG_place_cregga_s_bedchamber` — Cregga's bedchamber | Former Abbess Song's room, with a south-facing window, chair and buffet; later converted into Rosabel's office while retaining the bed. [250–251; NARRATOR] |
| `TAG_place_recorder_s_office` — Recorder's office | Cregga's former chamber receives desk, shelves and cupboards made by Gundil's crew, plus an embroidered coverlet. [4060–4062; NARRATOR] |
| `TAG_place_gatehouse_and_archives` — Gatehouse and archives | Records and conserved objects stored near the west main gate; later Hoben cares for Hoarg here. [903–909; NARRATOR] |
| `TAG_place_abbey_orchard` — Abbey orchard | East-side fruit grounds host picnics, strawberry patch, seasonal races and russet-apple waiting ritual. [1187–1232; NARRATOR] |
| `TAG_place_abbey_pond` — Abbey pond | South-side water space with deep-water rescue hazards, a large grayling and a treasured floating wooden bowl. [2233–2266; NARRATOR] |
| `TAG_place_ash_clue_tree` — Ash clue tree | Tree between south pond and wall; high fork holds a monocle sightline toward Cregga's south window. [1275–1302; NARRATOR] |
| `TAG_place_bell_tower` — Bell tower | Spiral stairs, high conical roof and scarred oak beam; Matthias and Methuselah bells with a hidden cloth in the beam. [1793–1807; NARRATOR] |
| `TAG_place_infirmary` — Infirmary | Quiet round-window sickbay with verbena, truckle beds, linen cupboard and a medicinal memory poem; connected to recordkeeping. [2190–2239; NARRATOR] |
| `TAG_place_east_wicket_gate` — East wicket gate | Smaller east-side exit useful for rapid rescue; source sometimes spells it wicker, preserve as spelling variant. [2339–2355; NARRATOR] |
| `TAG_place_south_wicket_gate` — South wicket gate | Small recessed peak-arch oak door halfway along south wall; a tall visitor must duck, allowing an unlawful ambush. [3137–3159; NARRATOR] |
| `TAG_place_cellar_supply_room` — Cellar supply room | Hard floor, low beams, one thick door and a massive barrel; separate wood-delivery access permits barrow transport and is misused for detention. [3158–3160; NARRATOR] |
| `TAG_place_west_gate_ditch_and_path` — West gate ditch and path | North-south path along west wall, ditch between it and flatland; northwest lookout sees silent enemy formation below. [3968–3976; NARRATOR] |
| `TAG_place_cregga_s_grave` — Cregga's grave | Sunny northeast wall corner with sandstone memorial, regularly renewed flowers and later a ruby-eyed steel medallion. [3692–3703; NARRATOR] |
| `TAG_place_undercut_riverbank_refuge` — Undercut riverbank refuge | Deep-water ledge beneath willow/alder roots, hidden from above; current, wet footing and access height matter. [603–620; NARRATOR] |
| `TAG_place_vole_pear_hill_burrow` — Vole pear-hill burrow | Secret bank tunnel opens to a comfortable communal home under pear roots, with a separate moss-floored sleeping area for children. [1139–1173; NARRATOR] |
| `TAG_place_tagg_s_alder_cove` — Tagg's alder cove | Still shallows hide a coracle and ripe blackberries; nearby open branch platform is made from lashed boughs. [1359–1495; NARRATOR] |
| `TAG_place_madd_s_tree_platform` — Madd's tree platform | Roofless, wall-less bough platform between alder branches; bindings and reach determine escape possibilities. [1495–1530; NARRATOR] |
| `TAG_place_flatland_storm_channels` — Flatland storm channels | Hummocks, hollows and dry streambeds become dangerous flood routes after a storm; a presumed shelter holds adders. [1557–1727; NARRATOR] |
| `TAG_place_ruskem_s_bank_den` — Ruskem's bank den | Entrance near the bank top above floodwater, low ceiling, hearth, moss-reed rugs and family portraits. [1677–1727; NARRATOR] |
| `TAG_place_northern_mountain` — Northern mountain | Snowy inland landmark northward from Tagg's journey, not automatically Salamandastron; cold, thin air, poor fuel and food challenge pursuers. [1889–1914; NARRATOR] |
| `TAG_place_seasonal_looping_river` — Seasonal looping river | Ruskem reports a northern-foothill branch looping through flatlands and around the mountain to its west face, then drying after about twenty days. [1720–1720; NARRATOR] |
| `TAG_place_cavemob_cavern` — Cavemob cavern | Hidden waterfall entrance, central deep lake, inflow capture net, kitchen ledges, chief's alcove and a hanging stalactite above the ritual route. [1984–2043; NARRATOR] |
| `TAG_place_cavemob_terrace_farms` — Cavemob terrace farms | Alluvial cultivation below steep unstable scree, boulders and shale; crops and farm labor are damaged by a deliberately started landslide. [2085–2124; NARRATOR] |
| `TAG_place_robald_s_turf_hut` — Robald's turf hut | Bank-side home wrecked by raiders, with concealed cupboard slats protecting an emergency food cache. [2436–2445; NARRATOR] |
| `TAG_place_lollery_s_log_cottage` — Lollery's log cottage | Log walls, sod/moss roof, larch trellis, white-rock garden border, vegetable/flower plot and outdoor stone oven. [2470–2472; NARRATOR] |
| `TAG_place_dillypin_raft` — Dillypin raft | Central hut/tent with chimney and oven galley, broad deck, woven mats, tiller and safety ropes; watches allow sleep while traveling. [2511–2531; NARRATOR] |
| `TAG_place_disused_mole_tunnel` — Disused mole tunnel | Old east-wall woodland tunnel repurposed as a captor's hiding place; prior construction does not imply current mole ownership. [2567–2574; NARRATOR] |
| `TAG_place_watermeadow_reach` — Watermeadow reach | Broad clear river enters shallower lily/bulrush meadows with fruit trees at margins; seasonal recreation and forage interrupt travel. [2719–2794; NARRATOR] |
| `TAG_place_nimbalo_s_family_farm` — Nimbalo's family farm | Small cultivated flatland beside a thatched, single-window cottage, hearth and two battle-axe nails; a door-jamb belt latch is a private memory. [2791–2804; NARRATOR] |
| `TAG_place_twin_limestone_rocks` — Twin limestone rocks | Paired great riverbank rocks identify disembarkation and an inland walking route toward Redwall. [2871–2913; NARRATOR] |
| `TAG_place_forthright_summer_camp` — Forthright summer camp | Embroidered linen canopy pegged among hornbeam and fallen larch, with a rock oven; holly retains a pursuer's barkcloth trace. [2897–2913; NARRATOR] |
| `TAG_place_rukky_s_river_cave` — Rukky's river cave | South Mossflower riverbank rock ledges near a dead larch signal tree; hidden gem-bright cave, two firefly lanterns and riverbend support camp. [3438–3480; NARRATOR] |
| `TAG_place_ruggan_s_coastal_camp` — Ruggan's coastal camp | Larger camp south of abandoned Juska grounds, with seer fires, guarded prisoner space and a northbound march back to the former camp. [3620–3678; NARRATOR] |

### Food (160)

| ID / label | Source-located facts |
|---|---|
| `TAG_food_autumn_harvest_soup` — Autumn Harvest soup | Named in the winter frame; no ingredients supplied. Source-named ingredients: none supplied. [5–5; NARRATOR] |
| `TAG_food_fire_skewered_mackerel` — Fire-skewered mackerel | Green withes hold the fish over fire; no seasoning stated. Source-named ingredients: mackerel. [12–12; NARRATOR] |
| `TAG_food_nettle_beer` — Nettle beer | Named drink, fermentation recipe absent. Source-named ingredients: nettle. [14–14; NARRATOR] |
| `TAG_food_mackerel_milkweed_and_dock_stew` — Mackerel milkweed and dock stew | Fish is skinless and boneless; preserve hazardous/uncertain source plants and adapt separately. Source-named ingredients: mackerel, milkweed, dock. [18–18; NARRATOR] |
| `TAG_food_candied_chestnuts` — Candied chestnuts | Sweetening medium not stated by the name alone. Source-named ingredients: chestnut. [76–85; NARRATOR] |
| `TAG_food_october_ale` — October Ale | Explicitly a secret Cellarkeeper recipe; all proposed ingredients are AI-authored, not recovered canon. Source-named ingredients: none supplied. [85–3515; NARRATOR] |
| `TAG_food_preserved_fruit_pieces` — Preserved fruit pieces | Container of preserved fruit; fruit species and preservation medium unspecified here. Source-named ingredients: fruit. [113–113; NARRATOR] |
| `TAG_food_mushroom_scallion_pasties` — Mushroom-scallion pasties | Named filling, pastry composition absent. Source-named ingredients: mushroom, scallion. [130–130; NARRATOR] |
| `TAG_food_fruit_honey_cake` — Fruit-honey cake | Fruit species absent; proposed game version uses apple and blackberry as labeled additions. Source-named ingredients: fruit, honey. [130–130; NARRATOR] |
| `TAG_food_strawberry_fizz` — Strawberry fizz | Later a ten-summer-aged cask is still called cordial; no verified real fermentation procedure. Source-named ingredients: strawberry. [130–2317; NARRATOR] |
| `TAG_food_spring_vegetable_soup` — Spring vegetable soup | Spring flavor profile and vegetable selection are author additions. Source-named ingredients: vegetables. [135–135; NARRATOR] |
| `TAG_food_oatbread` — Oatbread | Named new bread; no dairy or eggs asserted. Source-named ingredients: oat. [135–135; NARRATOR] |
| `TAG_food_white_cheese_with_hazelnuts` — White cheese with hazelnuts | Source cheese base unspecified; game uses a named cultured hazelnut cream. Source-named ingredients: white cheese, hazelnut. [135–135; NARRATOR] |
| `TAG_food_apple_flan` — Apple flan | Pastry and binder absent from source. Source-named ingredients: apple. [135–135; NARRATOR] |
| `TAG_food_steamed_plum_pudding` — Steamed plum pudding | Steam preparation explicit; cooks risk boiling pot dry. Source-named ingredients: plum. [146–148; NARRATOR] |
| `TAG_food_watershrimp_and_hotroot_soup` — Watershrimp and hotroot soup | Onionbread and tea accompany; hotroot essence served separately. Source-named ingredients: watershrimp, hotroot. [214–219; NARRATOR] |
| `TAG_food_onionbread` — Onionbread | Named bread, process otherwise unspecified. Source-named ingredients: onion. [214–219; NARRATOR] |
| `TAG_food_cold_mint_dandelion_tea` — Cold mint-dandelion tea | Served cold. Source-named ingredients: mint, dandelion. [214–219; NARRATOR] |
| `TAG_food_heavy_fruitcake` — Heavy fruitcake | Heavy texture explicit, fruit mix absent. Source-named ingredients: fruit. [219–219; NARRATOR] |
| `TAG_food_blackberry_wine` — Blackberry wine | Later also diluted with water; fermentation input amounts absent. Source-named ingredients: blackberry. [219–219; NARRATOR] |
| `TAG_food_flat_oatcakes` — Flat oatcakes | Breakfast warming food, no fruit specified in this variant. Source-named ingredients: oat. [262–262; NARRATOR] |
| `TAG_food_scones` — Scones | Generic recurring scones; distinguish specifically named oatmeal variant. Source-named ingredients: none supplied. [262–262; NARRATOR] |
| `TAG_food_turnovers` — Turnovers | Generic named pastry; apple filling is an AI choice, not canon. Source-named ingredients: none supplied. [262–262; NARRATOR] |
| `TAG_food_poached_dace` — Poached dace | Poaching explicit; no herb seasoning stated. Source-named ingredients: dace. [266–266; NARRATOR] |
| `TAG_food_apple_pie` — Apple pie | First a song reference, later a hot crusted feast dish at 518–524. Source-named ingredients: apple. [326–330; NARRATOR] |
| `TAG_food_onion_pastie` — Onion pastie | Song-only menu reference in this occurrence. Source-named ingredients: onion. [326–330; NARRATOR] |
| `TAG_food_apple_raspberry_flan_with_mint_cream_pattern` — Apple-raspberry flan with mint cream pattern | Uses stored last-autumn russets despite present season; mint pattern decorates cream. Source-named ingredients: russet apple, raspberry, meadowcream, mint. [376–378; NARRATOR] |
| `TAG_food_crumpets` — Crumpets | Promised in a song, not confirmed plated here. Source-named ingredients: none supplied. [420–420; NARRATOR] |
| `TAG_food_baby_sole_with_seaweed` — Baby sole with seaweed | Soft cooked white fish flesh; species requires game substitution. Source-named ingredients: sole, young seaweed, sea salt. [437–440; NARRATOR] |
| `TAG_food_raw_scallop` — Raw scallop | Source consumption reference; game uses cooked mussel counterpart, never imports scallop harvest. Source-named ingredients: scallop. [454–454; NARRATOR] |
| `TAG_food_scallops_with_wild_celery_and_onion` — Scallops with wild celery and onion | Young shellfish cooked with these vegetables/herbs. Source-named ingredients: scallop, wild celery, onion, herbs. [459–460; NARRATOR] |
| `TAG_food_blackberry_pudding_with_meadowcream` — Blackberry pudding with meadowcream | Cream topping explicit, pudding base incomplete. Source-named ingredients: blackberry, meadowcream. [518–524; NARRATOR] |
| `TAG_food_hazelnut_cake` — Hazelnut cake | Named cake; no egg or milk assertion. Source-named ingredients: hazelnut. [518–524; NARRATOR] |
| `TAG_food_mushroom_pastie_with_onion_gravy` — Mushroom pastie with onion gravy | Onion gravy runs from hot pastry; sauce binder not given. Source-named ingredients: mushroom, onion gravy. [525–525; NARRATOR] |
| `TAG_food_summer_fruit_salad` — Summer fruit salad | Specific fruit selection is a seasonal game proposal. Source-named ingredients: fruit. [532–532; NARRATOR] |
| `TAG_food_mint_wafer_with_soft_white_cheese` — Mint wafer with soft white cheese | Wafer base unspecified; source cheese retained in source layer. Source-named ingredients: mint, soft white cheese. [532–532; NARRATOR] |
| `TAG_food_deeper_n_ever_turnip_tater_beetroot_pie` — Deeper'n ever turnip-tater-beetroot pie | Named traditional layered vegetable pie; exact construction not specified here. Source-named ingredients: turnip, potato, beetroot. [533–538; NARRATOR] |
| `TAG_food_summer_vegetable_soup` — Summer vegetable soup | Summer vegetable choices are proposed. Source-named ingredients: vegetables. [533–533; NARRATOR] |
| `TAG_food_apple_cream_flan` — Apple cream flan | Cream base unknown; game uses oat cream. Source-named ingredients: apple, cream. [533–533; NARRATOR] |
| `TAG_food_dandelion_cordial` — Dandelion cordial | Named cordial with no source proportions. Source-named ingredients: dandelion. [536–536; NARRATOR] |
| `TAG_food_elderberry_wine` — Elderberry wine | Named wine; no source process provided. Source-named ingredients: elderberry. [537–537; NARRATOR] |
| `TAG_food_plum_cake` — Plum cake | Recurring cake and travel-cache food. Source-named ingredients: plum. [542–542; NARRATOR] |
| `TAG_food_trifle` — Trifle | Generic trifle references distinct from named woodland/redcurrant variants. Source-named ingredients: none supplied. [545–545; NARRATOR] |
| `TAG_food_old_damson_wine` — Old damson wine | Old and strong, small cups, sweet fiery impression; not grief medication. Source-named ingredients: damson. [557–562; NARRATOR] |
| `TAG_food_honeyed_hazelnut_slice` — Honeyed hazelnut slice | Named slice; binder inferred. Source-named ingredients: honey, hazelnut. [585–585; NARRATOR] |
| `TAG_food_gundil_s_mixed_hotroot_drink` — Gundil's mixed hotroot drink | Comic favored concoction; adapt nonalcoholic game drink and retain odd flavor as optional cultural content. Source-named ingredients: hotroot soup, dandelion wine, hot mint tea, roasted chestnut. [598–598; NARRATOR] |
| `TAG_food_roasted_chestnuts` — Roasted chestnuts | Explicit roasted component of the comic mixed drink. Source-named ingredients: chestnut. [598–598; NARRATOR] |
| `TAG_food_dandelion_wine` — Dandelion wine | Named ingredient in Gundil's drink, not the same as cordial. Source-named ingredients: dandelion. [598–598; NARRATOR] |
| `TAG_food_hot_mint_tea` — Hot mint tea | Hot component of the mixed drink; simple standalone candidate. Source-named ingredients: mint. [598–598; NARRATOR] |
| `TAG_food_roast_woodpigeon` — Roast woodpigeon | Recurring predatory meal; game uses roasted mushroom cap counterpart. Source-named ingredients: woodpigeon. [608–820; NARRATOR] |
| `TAG_food_mushroom_celery_broth_with_hotroot_pepper` — Mushroom-celery broth with hotroot pepper | Hotroot sprinkled on broth; served with barley farl. Source-named ingredients: mushroom, celery, hotroot pepper. [632–644; NARRATOR] |
| `TAG_food_barley_farl` — Barley farl | Used for dipping in broth. Source-named ingredients: barley. [632–644; NARRATOR] |
| `TAG_food_cold_mint_tea` — Cold mint tea | Separate cold serving variant. Source-named ingredients: mint. [632–644; NARRATOR] |
| `TAG_food_minted_potato_leek_turnover` — Minted potato-leek turnover | Browned crust and melting-soft filling provide sensory doneness cues. Source-named ingredients: mint, potato, leek. [719–727; NARRATOR] |
| `TAG_food_fire_roasted_vendace` — Fire-roasted vendace | Green willow spits; adapted whitefish counterpart required. Source-named ingredients: vendace. [770–775; NARRATOR] |
| `TAG_food_roast_dove` — Roast dove | Source seer bribe; mushroom counterpart for game diet. Source-named ingredients: dove. [821–835; NARRATOR] |
| `TAG_food_raw_dove_eggs` — Raw dove eggs | Source-only item; replace with stuffed small mushroom in the game, explicitly renamed. Source-named ingredients: dove egg. [821–835; NARRATOR] |
| `TAG_food_honey_sweet_mint_tea` — Honey-sweet mint tea | Honey explicitly stated. Source-named ingredients: mint, honey. [821–821; NARRATOR] |
| `TAG_food_woodland_trifle` — Woodland trifle | Source topping explicit; fruit/base are authored additions. Source-named ingredients: flaked almond, meadowcream. [937–938; NARRATOR] |
| `TAG_food_celery_carrot_soup` — Celery-carrot soup | Chopped vegetables, starter soup. Source-named ingredients: celery, carrot. [939–941; NARRATOR] |
| `TAG_food_crusty_bread_with_chive_cheese` — Crusty bread with chive cheese | Bread dipped in cheese; source cheese base unspecified. Source-named ingredients: bread, soft cheese, chive. [960–960; NARRATOR] |
| `TAG_food_baton_loaf` — Baton loaf | Shape named, grain absent. Source-named ingredients: none supplied. [975–975; NARRATOR] |
| `TAG_food_oatmeal_scones` — Oatmeal scones | Kneaded and baked for breakfast. Source-named ingredients: oatmeal. [1053–1059; NARRATOR] |
| `TAG_food_hot_nutbread` — Hot nutbread | Vole hospitality; nut species unspecified. Source-named ingredients: nuts. [1152–1153; NARRATOR] |
| `TAG_food_vole_vegetable_stew` — Vole vegetable stew | Pan of stew; proposed vegetables clearly authored. Source-named ingredients: vegetables. [1152–1153; NARRATOR] |
| `TAG_food_bankbrew` — Bankbrew | Described as fruity beer in tankards; exact ingredients unknown. Source-named ingredients: none supplied. [1152–1153; NARRATOR] |
| `TAG_food_blackberry_pies` — Blackberry pies | Named pie variant. Source-named ingredients: blackberry. [1187–1187; NARRATOR] |
| `TAG_food_pennywort_cordial` — Pennywort cordial | Botanical identity unresolved; game counterpart uses mint and is renamed. Source-named ingredients: pennywort. [1191–1191; NARRATOR] |
| `TAG_food_oatmeal_scone_with_honey` — Oatmeal scone with honey | Serving variant of oatmeal scone. Source-named ingredients: oatmeal scone, honey. [1191–1191; NARRATOR] |
| `TAG_food_barley_toast_with_quince_jam` — Barley toast with quince jam | Quince jam composition not elaborated; source names establish quince. Source-named ingredients: barley toast, quince jam. [1197–1197; NARRATOR] |
| `TAG_food_quince_jam` — Quince jam | Named preserve; sweetener inferred. Source-named ingredients: quince. [1197–1197; NARRATOR] |
| `TAG_food_candied_plum` — Candied plum | Named preserved fruit. Source-named ingredients: plum. [1202–1202; NARRATOR] |
| `TAG_food_cream_mushroom_soup` — Cream mushroom soup | Game uses oat cream; source cream not assumed plant or dairy beyond wording. Source-named ingredients: mushroom, cream. [1280–1282; NARRATOR] |
| `TAG_food_broggle_s_nutfarls` — Broggle's nutfarls | Three nut species explicitly named. Source-named ingredients: hazelnut, beech nut, chestnut. [1280–1282; NARRATOR] |
| `TAG_food_turnip_gravy_pastie` — Turnip-gravy pastie | Gravy base unknown; onion gravy is authored choice. Source-named ingredients: turnip, gravy. [1288–1288; NARRATOR] |
| `TAG_food_maple_wafer_with_white_cheese` — Maple wafer with white cheese | Maple form not stated; game uses maple syrup explicitly as interpretation. Source-named ingredients: maple, white cheese. [1289–1289; NARRATOR] |
| `TAG_food_dried_fish` — Dried fish | Fish species absent; game uses dried herring. Source-named ingredients: fish. [1319–1323; NARRATOR] |
| `TAG_food_vole_oat_and_dried_fruit_travel_cakes` — Vole oat-and-dried-fruit travel cakes | Distinct from Rawback's nut/oat/barley cakes. Source-named ingredients: oat, dried fruit. [1359–1509; NARRATOR] |
| `TAG_food_pear_cordial` — Pear cordial | Travel drink. Source-named ingredients: pear. [1359–1359; NARRATOR] |
| `TAG_food_grilled_burbot` — Grilled burbot | Green willow spit; aggressive fish ecology stylized; game uses whitefish. Source-named ingredients: burbot. [1403–1410; NARRATOR] |
| `TAG_food_steamed_damson_plum_pudding` — Steamed damson-plum pudding | Boorab's menu verse describes the present dish; ingredients are character report rather than an independent recipe card. Source-named ingredients: damson, plum, flour, honey, nuts. [1469–1477; NARRATOR] |
| `TAG_food_hazelnut_mushroom_turnip_casserole` — Hazelnut-mushroom-turnip casserole | Baked dish, additional binder absent. Source-named ingredients: hazelnut, mushroom, turnip. [1469–1469; NARRATOR] |
| `TAG_food_dandelion_burdock_cordial` — Dandelion-burdock cordial | Recurring travel provision. Source-named ingredients: dandelion, burdock. [1469–1469; NARRATOR] |
| `TAG_food_nimbalo_s_flatlands_salad` — Nimbalo's flatlands salad | Fictional foraging description includes unsafe/uncertain plants; game counterpart replaces these explicitly. Source-named ingredients: whitlow, pennycress, comfrey root, pepperwort, bindweed flower, dandelion leaf, dandelion root, wild strawberry, blackberry. [1608–1610; NARRATOR] |
| `TAG_food_ruskem_s_burgoo` — Ruskem's burgoo | Replenished cauldron, ingredients vary; no real-world perpetual-pot food safety instruction. Source-named ingredients: berries, fruit, roots. [1679–1679; NARRATOR] |
| `TAG_food_mint_comfrey_tea` — Mint-comfrey tea | Fictional herbal drink; game counterpart omits comfrey and is renamed. Source-named ingredients: mint, comfrey. [1680–1680; NARRATOR] |
| `TAG_food_breakfast_strawberry_honey_burgoo` — Breakfast strawberry-honey burgoo | Celery and onion are proposed but explicitly rejected: do not add them as canonical ingredients. Source-named ingredients: oat, barley, strawberry, honeycomb. [1692–1694; NARRATOR] |
| `TAG_food_fruit_loaves` — Fruit loaves | Small portable loaves, fruit species unspecified. Source-named ingredients: fruit. [1713–1713; NARRATOR] |
| `TAG_food_rosehip_tea` — Rosehip tea | Named tea. Source-named ingredients: rosehip. [1735–1735; NARRATOR] |
| `TAG_food_old_barley_beer` — Old barley beer | Harvest-mouse song reference, not served in the immediate scene. Source-named ingredients: barley. [1921–1937; NARRATOR] |
| `TAG_food_mellow_cheese` — Mellow cheese | Song reference; game nut-cheese counterpart separately named. Source-named ingredients: cheese. [1921–1937; NARRATOR] |
| `TAG_food_snakeyfish_pie` — Snakeyfish pie | Soft white pastry; oatmeal-like filling texture does NOT establish oatmeal as a source ingredient. Source-named ingredients: elver, salt, parsley, sage. [1957–1995; NARRATOR] |
| `TAG_food_stewed_elvers` — Stewed elvers | One of four explicit Cavemob preparations; adapted dace stew. Source-named ingredients: elver. [1984–1984; NARRATOR] |
| `TAG_food_baked_elvers` — Baked elvers | Adapted baked dace. Source-named ingredients: elver. [1984–1984; NARRATOR] |
| `TAG_food_roasted_elvers` — Roasted elvers | Adapted roast dace. Source-named ingredients: elver. [1984–1984; NARRATOR] |
| `TAG_food_fried_elvers` — Fried elvers | Frying medium absent; adapted fried dace. Source-named ingredients: elver. [1984–1984; NARRATOR] |
| `TAG_food_iced_rosehip_almond_flower_tea` — Iced rosehip-almond-flower tea | Iced, snow origin guessed by visitor; game uses separately named apple-blossom counterpart. Source-named ingredients: rosehip, almond flower. [1991–1994; NARRATOR] |
| `TAG_food_celery_chestnut_bake` — Celery-chestnut bake | Surrounded by salad at serving. Source-named ingredients: celery, chestnut. [2151–2151; NARRATOR] |
| `TAG_food_cherryjuice_wine` — Cherryjuice wine | Alliterative spoken menu reference, not confirmed batch production. Source-named ingredients: cherry juice. [2152–2161; NARRATOR] |
| `TAG_food_pennycress_cordial` — Pennycress cordial | Alliterative menu reference; botanical food identity uncertain, renamed mint counterpart. Source-named ingredients: pennycress. [2152–2161; NARRATOR] |
| `TAG_food_sweet_cider` — Sweet cider | Fruit base not supplied in this mention; apple is an authored interpretation. Source-named ingredients: none supplied. [2152–2161; NARRATOR] |
| `TAG_food_celery_salad` — Celery salad | Alliterative menu reference; added salad companions are authored. Source-named ingredients: celery. [2152–2161; NARRATOR] |
| `TAG_food_nut_shortbreads` — Nut shortbreads | Special race-day treat; nut species absent. Source-named ingredients: nuts. [2330–2330; NARRATOR] |
| `TAG_food_mint_rosehip_tea` — Mint-rosehip tea | Served iced/cold at breakfast. Source-named ingredients: mint, rosehip. [2402–2402; NARRATOR] |
| `TAG_food_nut_cheese` — Nut cheese | Robald's cache; does not prove a dairy-free source production method, so game formulation labeled separately. Source-named ingredients: nuts. [2437–2437; NARRATOR] |
| `TAG_food_fruit_biscuits` — Fruit biscuits | Cache food, later served with cheese topping. Source-named ingredients: fruit. [2437–2443; NARRATOR] |
| `TAG_food_spikebeer` — Spikebeer | Hedgehog-associated named beer, ingredients not supplied. Source-named ingredients: none supplied. [2437–2437; NARRATOR] |
| `TAG_food_candied_apples` — Candied apples | Named cache preserve. Source-named ingredients: apple. [2437–2437; NARRATOR] |
| `TAG_food_lollery_s_raisin_teabread` — Lollery's raisin teabread | Tea in teabread name does not establish tea leaf ingredient. Source-named ingredients: raisin. [2437–2437; NARRATOR] |
| `TAG_food_mushroom_soup` — Mushroom soup | Stolen meal reference; no cream explicitly stated here. Source-named ingredients: mushroom. [2439–2439; NARRATOR] |
| `TAG_food_carrot_turnip_flan` — Carrot-turnip flan | Savory pastry base inferred. Source-named ingredients: carrot, turnip. [2439–2439; NARRATOR] |
| `TAG_food_lollery_s_folded_honey_berry_pancakes` — Lollery's folded honey-berry pancakes | Paste spread on hot stone, flipped with slate, topped and folded; binding liquid absent. Corn may mean grain, not definitely maize. Good hot or cold. Source-named ingredients: ground corn, nutmeal, honey, chopped berries. [2472–2511; NARRATOR] |
| `TAG_food_greensap_milk` — Greensap milk | Explicit plant-sap drink, not livestock dairy; exact plant identity unknown. Source-named ingredients: green sap. [2486–2503; NARRATOR] |
| `TAG_food_dandelion_tea` — Dandelion tea | Requested aboard raft, later Hoarg's actual morning drink. Source-named ingredients: dandelion. [2532–3780; NARRATOR] |
| `TAG_food_poskra_s_vegetation_soup` — Poskra's vegetation soup | Soft food suits missing teeth; exact plants absent, authored safe vegetable counterpart. Source-named ingredients: vegetation. [2569–2569; NARRATOR] |
| `TAG_food_bird_eggs` — Bird eggs | Source-only soft meal; renamed mushroom mash counterpart for game. Source-named ingredients: bird egg. [2569–2569; NARRATOR] |
| `TAG_food_cabbage_fennel_bake` — Cabbage-fennel bake | Prepared during defense mobilization. Source-named ingredients: cabbage, fennel. [2640–2640; NARRATOR] |
| `TAG_food_cabbage_fennel_pasties` — Cabbage-fennel pasties | Same bake converted to portable pastry for wallguards, a logistical serving change. Source-named ingredients: cabbage-fennel bake, pastry. [2683–2683; NARRATOR] |
| `TAG_food_raspberry_cream_turnovers` — Raspberry cream turnovers | Game oat cream replacement explicitly named. Source-named ingredients: raspberry, cream. [2640–2683; NARRATOR] |
| `TAG_food_bilberry_cordial` — Bilberry cordial | Raft breakfast accompaniment. Source-named ingredients: bilberry. [2719–2719; NARRATOR] |
| `TAG_food_jurkin_s_allfruit_duff` — Jurkin's allfruit duff | Soft crumble crust and thick white sauce. Hazelnuts were gathered but not explicitly included among all fruit; do not silently add as canon. Source-named ingredients: pear, apple, blackberry, raspberry, wild damson, honey, white sauce, vanilla, almond. [2775–2810; NARRATOR] |
| `TAG_food_pale_cider` — Pale cider | Cooled in a sack trailing in river current; fruit base inferred. Source-named ingredients: none supplied. [2834–2834; NARRATOR] |
| `TAG_food_rawback_s_stone_baked_flatcakes` — Rawback's stone-baked flatcakes | Paste flattened on a heated stone; separate from vole fruit cakes. Source-named ingredients: nuts, wild oat, barley. [2921–2928; NARRATOR] |
| `TAG_food_strawberry_flan` — Strawberry flan | Pastry-rolling lesson accompanies preparation. Source-named ingredients: strawberry. [2931–2931; NARRATOR] |
| `TAG_food_tearose_violet_cordial` — Tearose-violet cordial | Recovery gift; no healing effect established. Source-named ingredients: tea rose, violet. [2986–2986; NARRATOR] |
| `TAG_food_pancakes_with_honey` — Pancakes with honey | Breakfast variant; Lollery's precise corn formulation not automatically inherited. Source-named ingredients: pancake, honey. [3075–3078; NARRATOR] |
| `TAG_food_motherwort_tea` — Motherwort tea | Fictional herbal care suggestion; game renamed mint-rosehip tea, no health prescription. Source-named ingredients: motherwort. [3336–3336; NARRATOR] |
| `TAG_food_damson_cream_pie` — Damson cream pie | Source cream replaced with oat cream in adaptation. Source-named ingredients: damson, cream. [3433–3433; NARRATOR] |
| `TAG_food_skipper_s_shrimp_hotroot_soup` — Skipper's shrimp-hotroot soup | Peppers and scallions explicitly chopped/slivered; use mussel counterpart for game. Source-named ingredients: freshwater shrimp, hotroot, pepper, scallion. [3439–3445; NARRATOR] |
| `TAG_food_mushroom_gravy_flan` — Mushroom-gravy flan | Gravy base unknown; onion is author choice. Source-named ingredients: mushroom, gravy. [3495–3496; NARRATOR] |
| `TAG_food_white_cheese_with_celery_and_hazelnuts` — White cheese with celery and hazelnuts | Different explicit inclusions from earlier hazelnut cheese. Source-named ingredients: white cheese, celery, hazelnut. [3496–3496; NARRATOR] |
| `TAG_food_candied_fruits` — Candied fruits | Cregga's favored feast food; species not fixed. Source-named ingredients: fruit. [3511–3511; NARRATOR] |
| `TAG_food_honey_sweetened_pale_cider` — Honey-sweetened pale cider | Both floral honey sources explicitly named; no apple base asserted by source here. Source-named ingredients: pale cider, heather honey, clover honey. [3515–3515; NARRATOR] |
| `TAG_food_redcurrant_cordial` — Redcurrant cordial | Named cordial. Source-named ingredients: redcurrant. [3552–3552; NARRATOR] |
| `TAG_food_roasted_seabird` — Roasted seabird | Species unspecified; game roasted mushroom counterpart. Source-named ingredients: seabird. [3656–3656; NARRATOR] |
| `TAG_food_barley_wine` — Barley wine | Named strong drink, no production formula. Source-named ingredients: barley. [3656–3656; NARRATOR] |
| `TAG_food_cornmeal_shellfish_porridge` — Cornmeal-shellfish porridge | Corn grain identity and shellfish species unspecified; game barleymeal-mussel version explicitly renamed. Source-named ingredients: cornmeal, shellfish. [3667–3667; NARRATOR] |
| `TAG_food_watered_blackberry_wine` — Watered blackberry wine | Dilution explicit, ratio absent. Source-named ingredients: blackberry wine, water. [3669–3674; NARRATOR] |
| `TAG_food_redcurrant_trifle` — Redcurrant trifle | Golden cream with almond decoration and a strawberry peak; base inferred. Source-named ingredients: redcurrant, meadowcream, flaked almond, candied strawberry. [3704–3714; NARRATOR] |
| `TAG_food_candied_strawberry` — Candied strawberry | Explicit trifle decoration, independent preserve candidate. Source-named ingredients: strawberry. [3704–3714; NARRATOR] |
| `TAG_food_mulled_spiced_ale` — Mulled spiced ale | Warm fireholder service; named spices are AI choices, not canon. Source-named ingredients: ale, spices. [3759–3765; NARRATOR] |
| `TAG_food_warm_mushroom_soup` — Warm mushroom soup | Night-watch nourishment, distinct serving context rather than proven new recipe. Source-named ingredients: mushroom. [3759–3765; NARRATOR] |
| `TAG_food_water_softened_stale_barley_bread` — Water-softened stale barley bread | Prison ration; softness adaptation has broader elder-care use without copying coercion. Source-named ingredients: barley bread, water. [3827–3827; NARRATOR] |
| `TAG_food_swamp_frogs_and_lizards` — Swamp frogs and lizards | Source survivor food; explicitly excluded animal pipeline, game pondside mushroom/greens substitute. Source-named ingredients: frog, lizard. [3869–3871; NARRATOR] |
| `TAG_food_warm_rye_bread` — Warm rye bread | Specific grain and warm service explicit. Source-named ingredients: rye. [3875–3875; NARRATOR] |
| `TAG_food_pickled_onions` — Pickled onions | Pickling liquid inferred. Source-named ingredients: onion. [3911–3911; NARRATOR] |
| `TAG_food_warm_ovenbread_farl` — Warm ovenbread farl | Warm farl accompanies new cheese; grain absent. Source-named ingredients: none supplied. [3911–3911; NARRATOR] |
| `TAG_food_filboonimgun_cheese` — Filboonimgun cheese | Named for Filorn, Boorab, Nimbalo and Gundil; three-day soaking in described boiling juice/cider mixture is source wording, not a validated real recipe. Source-named ingredients: yellow cheese, nuts, celery, herbs, carrot juice, dandelion juice, pale cider. [3913–3924; NARRATOR] |
| `TAG_food_button_mushroom_herb_sauce_sandwich` — Button-mushroom herb-sauce sandwich | Friar Bobb fills hot bread with cooked mushrooms; sauce composition absent. Source-named ingredients: hot bread, button mushroom, savory herb sauce. [3968–3968; NARRATOR] |
| `TAG_food_pennycloud_violet_tea` — Pennycloud-violet tea | Unpleasant cellar experiment; pennycloud identity unresolved, renamed violet-mint game infusion. Source-named ingredients: pennycloud, violet. [4063–4063; NARRATOR] |
| `TAG_food_fresh_bread_in_harvest_song` — Fresh bread in harvest song | Nested song reference to ordinary bread; specific grain absent. [1921–1937; NARRATOR] |
| `TAG_food_requested_perch_or_trout_breakfast` — Requested perch or trout breakfast | Nimbalo requests these fish but the actual breakfast is pancakes, honey, cordial, mushrooms and cress; request is not evidence of a catch. [3070–3078; NARRATOR] |
| `TAG_food_little_hot_cakes_guess` — Little hot cakes guess | A mistaken interpretation of clue initials, not a confirmed served dish. [755–755; NARRATOR] |
| `TAG_food_nursery_rhyme_dumpling` — Nursery-rhyme dumpling | Named within nursery entertainment, not a photographed or prepared meal. [1450–1450; NARRATOR] |
| `TAG_food_custard_reference` — Custard reference | Part of Boorab's invented anecdote, not evidence of Alkanet's actual past or a canonical recipe. [2164–2164; NARRATOR] |
| `TAG_food_little_hot_cakes_clue_guess` — Little hot cakes (clue guess) | False clue expansion; not a prepared meal. [755–755; NARRATOR] |
| `TAG_food_nursery_dumpling_song_reference` — Nursery dumpling (song reference) | Nursery-rhyme reference only; filling absent. [1450–1450; NARRATOR] |
| `TAG_food_custard_invented_anecdote` — Custard (invented anecdote) | Boorab's invented anecdote, not verified meal history. [2164–2164; NARRATOR] |
| `TAG_food_requested_perch_or_trout` — Requested perch or trout | Requested breakfast fish are not caught or served in this scene. [3070–3078; NARRATOR] |
| `TAG_food_giant_yo_karr_pie_rejected_joke` — Giant Yo Karr pie (rejected joke) | Chich rejects making the giant eel into pie. Preserve the refusal; do not make an eel recipe or harvest unlock. [2037–2040; NARRATOR] |

### Ingredient (163)

| ID / label | Source-located facts |
|---|---|
| `TAG_ingredient_ale` — ale | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3759–3765; NARRATOR] |
| `TAG_ingredient_almond` — almond | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2775–2810; NARRATOR] |
| `TAG_ingredient_almond_flower` — almond flower | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1991–1994; NARRATOR] |
| `TAG_ingredient_apple` — apple | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [135–135; NARRATOR]<br>Also explicitly named in Apple pie. [326–330; NARRATOR]<br>Also explicitly named in Apple cream flan. [533–533; NARRATOR]<br>Also explicitly named in Candied apples. [2437–2437; NARRATOR]<br>Also explicitly named in Jurkin's allfruit duff. [2775–2810; NARRATOR] |
| `TAG_ingredient_barley` — barley | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [632–644; NARRATOR]<br>Also explicitly named in Breakfast strawberry-honey burgoo. [1692–1694; NARRATOR]<br>Also explicitly named in Old barley beer. [1921–1937; NARRATOR]<br>Also explicitly named in Rawback's stone-baked flatcakes. [2921–2928; NARRATOR]<br>Also explicitly named in Barley wine. [3656–3656; NARRATOR] |
| `TAG_ingredient_barley_bread` — barley bread | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3827–3827; NARRATOR] |
| `TAG_ingredient_barley_toast` — barley toast | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1197–1197; NARRATOR] |
| `TAG_ingredient_beech_nut` — beech nut | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1280–1282; NARRATOR] |
| `TAG_ingredient_beetroot` — beetroot | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [533–538; NARRATOR] |
| `TAG_ingredient_berries` — berries | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1679–1679; NARRATOR] |
| `TAG_ingredient_bilberry` — bilberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2719–2719; NARRATOR] |
| `TAG_ingredient_bindweed_flower` — bindweed flower | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_bird_egg` — bird egg | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2569–2569; NARRATOR] |
| `TAG_ingredient_blackberry` — blackberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [219–219; NARRATOR]<br>Also explicitly named in Blackberry pudding with meadowcream. [518–524; NARRATOR]<br>Also explicitly named in Blackberry pies. [1187–1187; NARRATOR]<br>Also explicitly named in Nimbalo's flatlands salad. [1608–1610; NARRATOR]<br>Also explicitly named in Jurkin's allfruit duff. [2775–2810; NARRATOR] |
| `TAG_ingredient_blackberry_wine` — blackberry wine | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3669–3674; NARRATOR] |
| `TAG_ingredient_bread` — bread | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [960–960; NARRATOR] |
| `TAG_ingredient_burbot` — burbot | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1403–1410; NARRATOR] |
| `TAG_ingredient_burdock` — burdock | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1469–1469; NARRATOR] |
| `TAG_ingredient_button_mushroom` — button mushroom | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3968–3968; NARRATOR]<br>Cultivated and gathered food, later raw breakfast and cooked sandwich filling; game species identity should be controlled. [2113–2118; NARRATOR] |
| `TAG_ingredient_cabbage` — cabbage | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2640–2640; NARRATOR] |
| `TAG_ingredient_cabbage_fennel_bake` — cabbage-fennel bake | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2683–2683; NARRATOR] |
| `TAG_ingredient_candied_strawberry` — candied strawberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3704–3714; NARRATOR] |
| `TAG_ingredient_carrot` — carrot | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [939–941; NARRATOR]<br>Also explicitly named in Carrot-turnip flan. [2439–2439; NARRATOR] |
| `TAG_ingredient_carrot_juice` — carrot juice | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3913–3924; NARRATOR] |
| `TAG_ingredient_celery` — celery | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [632–644; NARRATOR]<br>Also explicitly named in Celery-carrot soup. [939–941; NARRATOR]<br>Also explicitly named in Celery-chestnut bake. [2151–2151; NARRATOR]<br>Also explicitly named in Celery salad. [2152–2161; NARRATOR]<br>Also explicitly named in White cheese with celery and hazelnuts. [3496–3496; NARRATOR]<br>Also explicitly named in Filboonimgun cheese. [3913–3924; NARRATOR] |
| `TAG_ingredient_cheese` — cheese | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1921–1937; NARRATOR] |
| `TAG_ingredient_cherry_juice` — cherry juice | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2152–2161; NARRATOR] |
| `TAG_ingredient_chestnut` — chestnut | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [76–85; NARRATOR]<br>Also explicitly named in Roasted chestnuts. [598–598; NARRATOR]<br>Also explicitly named in Broggle's nutfarls. [1280–1282; NARRATOR]<br>Also explicitly named in Celery-chestnut bake. [2151–2151; NARRATOR] |
| `TAG_ingredient_chive` — chive | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [960–960; NARRATOR] |
| `TAG_ingredient_chopped_berries` — chopped berries | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2472–2511; NARRATOR] |
| `TAG_ingredient_clover_honey` — clover honey | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3515–3515; NARRATOR] |
| `TAG_ingredient_comfrey` — comfrey | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1680–1680; NARRATOR] |
| `TAG_ingredient_comfrey_root` — comfrey root | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_cornmeal` — cornmeal | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3667–3667; NARRATOR] |
| `TAG_ingredient_cream` — cream | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [533–533; NARRATOR]<br>Also explicitly named in Cream mushroom soup. [1280–1282; NARRATOR]<br>Also explicitly named in Raspberry cream turnovers. [2640–2683; NARRATOR]<br>Also explicitly named in Damson cream pie. [3433–3433; NARRATOR] |
| `TAG_ingredient_dace` — dace | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [266–266; NARRATOR] |
| `TAG_ingredient_damson` — damson | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [557–562; NARRATOR]<br>Also explicitly named in Steamed damson-plum pudding. [1469–1477; NARRATOR]<br>Also explicitly named in Damson cream pie. [3433–3433; NARRATOR] |
| `TAG_ingredient_dandelion` — dandelion | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [214–219; NARRATOR]<br>Also explicitly named in Dandelion cordial. [536–536; NARRATOR]<br>Also explicitly named in Dandelion wine. [598–598; NARRATOR]<br>Also explicitly named in Dandelion-burdock cordial. [1469–1469; NARRATOR]<br>Also explicitly named in Dandelion tea. [2532–3780; NARRATOR] |
| `TAG_ingredient_dandelion_juice` — dandelion juice | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3913–3924; NARRATOR] |
| `TAG_ingredient_dandelion_leaf` — dandelion leaf | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_dandelion_root` — dandelion root | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_dandelion_wine` — dandelion wine | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [598–598; NARRATOR] |
| `TAG_ingredient_dock` — dock | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [18–18; NARRATOR] |
| `TAG_ingredient_dove` — dove | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [821–835; NARRATOR] |
| `TAG_ingredient_dove_egg` — dove egg | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [821–835; NARRATOR] |
| `TAG_ingredient_dried_fruit` — dried fruit | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1359–1509; NARRATOR] |
| `TAG_ingredient_elderberry` — elderberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [537–537; NARRATOR] |
| `TAG_ingredient_elver` — elver | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1957–1995; NARRATOR]<br>Also explicitly named in Stewed elvers. [1984–1984; NARRATOR]<br>Also explicitly named in Baked elvers. [1984–1984; NARRATOR]<br>Also explicitly named in Roasted elvers. [1984–1984; NARRATOR]<br>Also explicitly named in Fried elvers. [1984–1984; NARRATOR] |
| `TAG_ingredient_fennel` — fennel | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2640–2640; NARRATOR] |
| `TAG_ingredient_fish` — fish | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1319–1323; NARRATOR] |
| `TAG_ingredient_flaked_almond` — flaked almond | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [937–938; NARRATOR]<br>Also explicitly named in Redcurrant trifle. [3704–3714; NARRATOR] |
| `TAG_ingredient_flour` — flour | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1469–1477; NARRATOR] |
| `TAG_ingredient_freshwater_shrimp` — freshwater shrimp | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3439–3445; NARRATOR] |
| `TAG_ingredient_frog` — frog | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3869–3871; NARRATOR] |
| `TAG_ingredient_fruit` — fruit | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [113–113; NARRATOR]<br>Also explicitly named in Fruit-honey cake. [130–130; NARRATOR]<br>Also explicitly named in Heavy fruitcake. [219–219; NARRATOR]<br>Also explicitly named in Summer fruit salad. [532–532; NARRATOR]<br>Also explicitly named in Ruskem's burgoo. [1679–1679; NARRATOR]<br>Also explicitly named in Fruit loaves. [1713–1713; NARRATOR]<br>Also explicitly named in Fruit biscuits. [2437–2443; NARRATOR]<br>Also explicitly named in Candied fruits. [3511–3511; NARRATOR] |
| `TAG_ingredient_gravy` — gravy | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1288–1288; NARRATOR]<br>Also explicitly named in Mushroom-gravy flan. [3495–3496; NARRATOR] |
| `TAG_ingredient_green_sap` — green sap | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2486–2503; NARRATOR] |
| `TAG_ingredient_ground_corn` — ground corn | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2472–2511; NARRATOR] |
| `TAG_ingredient_hazelnut` — hazelnut | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [135–135; NARRATOR]<br>Also explicitly named in Hazelnut cake. [518–524; NARRATOR]<br>Also explicitly named in Honeyed hazelnut slice. [585–585; NARRATOR]<br>Also explicitly named in Broggle's nutfarls. [1280–1282; NARRATOR]<br>Also explicitly named in Hazelnut-mushroom-turnip casserole. [1469–1469; NARRATOR]<br>Also explicitly named in White cheese with celery and hazelnuts. [3496–3496; NARRATOR] |
| `TAG_ingredient_heather_honey` — heather honey | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3515–3515; NARRATOR] |
| `TAG_ingredient_herbs` — herbs | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [459–460; NARRATOR]<br>Also explicitly named in Filboonimgun cheese. [3913–3924; NARRATOR] |
| `TAG_ingredient_honey` — honey | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [130–130; NARRATOR]<br>Also explicitly named in Honeyed hazelnut slice. [585–585; NARRATOR]<br>Also explicitly named in Honey-sweet mint tea. [821–821; NARRATOR]<br>Also explicitly named in Oatmeal scone with honey. [1191–1191; NARRATOR]<br>Also explicitly named in Steamed damson-plum pudding. [1469–1477; NARRATOR]<br>Also explicitly named in Lollery's folded honey-berry pancakes. [2472–2511; NARRATOR]<br>Also explicitly named in Jurkin's allfruit duff. [2775–2810; NARRATOR]<br>Also explicitly named in Pancakes with honey. [3075–3078; NARRATOR] |
| `TAG_ingredient_honeycomb` — honeycomb | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1692–1694; NARRATOR]<br>Explicit breakfast-burgoo ingredient and cultural harvest-song food. [1692–1694; NARRATOR] |
| `TAG_ingredient_hot_bread` — hot bread | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3968–3968; NARRATOR] |
| `TAG_ingredient_hot_mint_tea` — hot mint tea | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [598–598; NARRATOR] |
| `TAG_ingredient_hotroot` — hotroot | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [214–219; NARRATOR]<br>Also explicitly named in Skipper's shrimp-hotroot soup. [3439–3445; NARRATOR] |
| `TAG_ingredient_hotroot_pepper` — hotroot pepper | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [632–644; NARRATOR] |
| `TAG_ingredient_hotroot_soup` — hotroot soup | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [598–598; NARRATOR] |
| `TAG_ingredient_leek` — leek | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [719–727; NARRATOR] |
| `TAG_ingredient_lizard` — lizard | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3869–3871; NARRATOR] |
| `TAG_ingredient_mackerel` — mackerel | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [12–12; NARRATOR]<br>Also explicitly named in Mackerel milkweed and dock stew. [18–18; NARRATOR] |
| `TAG_ingredient_maple` — maple | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1289–1289; NARRATOR] |
| `TAG_ingredient_meadowcream` — meadowcream | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [376–378; NARRATOR]<br>Also explicitly named in Blackberry pudding with meadowcream. [518–524; NARRATOR]<br>Also explicitly named in Woodland trifle. [937–938; NARRATOR]<br>Also explicitly named in Redcurrant trifle. [3704–3714; NARRATOR] |
| `TAG_ingredient_milkweed` — milkweed | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [18–18; NARRATOR] |
| `TAG_ingredient_mint` — mint | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [214–219; NARRATOR]<br>Also explicitly named in Apple-raspberry flan with mint cream pattern. [376–378; NARRATOR]<br>Also explicitly named in Mint wafer with soft white cheese. [532–532; NARRATOR]<br>Also explicitly named in Hot mint tea. [598–598; NARRATOR]<br>Also explicitly named in Cold mint tea. [632–644; NARRATOR]<br>Also explicitly named in Minted potato-leek turnover. [719–727; NARRATOR]<br>Also explicitly named in Honey-sweet mint tea. [821–821; NARRATOR]<br>Also explicitly named in Mint-comfrey tea. [1680–1680; NARRATOR]<br>Also explicitly named in Mint-rosehip tea. [2402–2402; NARRATOR] |
| `TAG_ingredient_motherwort` — motherwort | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3336–3336; NARRATOR] |
| `TAG_ingredient_mushroom` — mushroom | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [130–130; NARRATOR]<br>Also explicitly named in Mushroom pastie with onion gravy. [525–525; NARRATOR]<br>Also explicitly named in Mushroom-celery broth with hotroot pepper. [632–644; NARRATOR]<br>Also explicitly named in Cream mushroom soup. [1280–1282; NARRATOR]<br>Also explicitly named in Hazelnut-mushroom-turnip casserole. [1469–1469; NARRATOR]<br>Also explicitly named in Mushroom soup. [2439–2439; NARRATOR]<br>Also explicitly named in Mushroom-gravy flan. [3495–3496; NARRATOR]<br>Also explicitly named in Warm mushroom soup. [3759–3765; NARRATOR] |
| `TAG_ingredient_nettle` — nettle | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [14–14; NARRATOR] |
| `TAG_ingredient_nutmeal` — nutmeal | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2472–2511; NARRATOR] |
| `TAG_ingredient_nuts` — nuts | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1152–1153; NARRATOR]<br>Also explicitly named in Steamed damson-plum pudding. [1469–1477; NARRATOR]<br>Also explicitly named in Nut shortbreads. [2330–2330; NARRATOR]<br>Also explicitly named in Nut cheese. [2437–2437; NARRATOR]<br>Also explicitly named in Rawback's stone-baked flatcakes. [2921–2928; NARRATOR]<br>Also explicitly named in Filboonimgun cheese. [3913–3924; NARRATOR] |
| `TAG_ingredient_oat` — oat | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [135–135; NARRATOR]<br>Also explicitly named in Flat oatcakes. [262–262; NARRATOR]<br>Also explicitly named in Vole oat-and-dried-fruit travel cakes. [1359–1509; NARRATOR]<br>Also explicitly named in Breakfast strawberry-honey burgoo. [1692–1694; NARRATOR] |
| `TAG_ingredient_oatmeal` — oatmeal | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1053–1059; NARRATOR] |
| `TAG_ingredient_oatmeal_scone` — oatmeal scone | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1191–1191; NARRATOR] |
| `TAG_ingredient_onion` — onion | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [214–219; NARRATOR]<br>Also explicitly named in Onion pastie. [326–330; NARRATOR]<br>Also explicitly named in Scallops with wild celery and onion. [459–460; NARRATOR]<br>Also explicitly named in Pickled onions. [3911–3911; NARRATOR] |
| `TAG_ingredient_onion_gravy` — onion gravy | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [525–525; NARRATOR] |
| `TAG_ingredient_pale_cider` — pale cider | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3515–3515; NARRATOR]<br>Also explicitly named in Filboonimgun cheese. [3913–3924; NARRATOR] |
| `TAG_ingredient_pancake` — pancake | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3075–3078; NARRATOR] |
| `TAG_ingredient_parsley` — parsley | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1957–1995; NARRATOR] |
| `TAG_ingredient_pastry` — pastry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2683–2683; NARRATOR] |
| `TAG_ingredient_pear` — pear | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1359–1359; NARRATOR]<br>Also explicitly named in Jurkin's allfruit duff. [2775–2810; NARRATOR] |
| `TAG_ingredient_pennycloud` — pennycloud | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [4063–4063; NARRATOR] |
| `TAG_ingredient_pennycress` — pennycress | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR]<br>Also explicitly named in Pennycress cordial. [2152–2161; NARRATOR] |
| `TAG_ingredient_pennywort` — pennywort | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1191–1191; NARRATOR] |
| `TAG_ingredient_pepper` — pepper | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3439–3445; NARRATOR] |
| `TAG_ingredient_pepperwort` — pepperwort | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_plum` — plum | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [146–148; NARRATOR]<br>Also explicitly named in Plum cake. [542–542; NARRATOR]<br>Also explicitly named in Candied plum. [1202–1202; NARRATOR]<br>Also explicitly named in Steamed damson-plum pudding. [1469–1477; NARRATOR] |
| `TAG_ingredient_potato` — potato | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [533–538; NARRATOR]<br>Also explicitly named in Minted potato-leek turnover. [719–727; NARRATOR] |
| `TAG_ingredient_quince` — quince | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1197–1197; NARRATOR] |
| `TAG_ingredient_quince_jam` — quince jam | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1197–1197; NARRATOR] |
| `TAG_ingredient_raisin` — raisin | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2437–2437; NARRATOR] |
| `TAG_ingredient_raspberry` — raspberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [376–378; NARRATOR]<br>Also explicitly named in Raspberry cream turnovers. [2640–2683; NARRATOR]<br>Also explicitly named in Jurkin's allfruit duff. [2775–2810; NARRATOR] |
| `TAG_ingredient_redcurrant` — redcurrant | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3552–3552; NARRATOR]<br>Also explicitly named in Redcurrant trifle. [3704–3714; NARRATOR] |
| `TAG_ingredient_roasted_chestnut` — roasted chestnut | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [598–598; NARRATOR] |
| `TAG_ingredient_roots` — roots | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1679–1679; NARRATOR] |
| `TAG_ingredient_rosehip` — rosehip | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1735–1735; NARRATOR]<br>Also explicitly named in Iced rosehip-almond-flower tea. [1991–1994; NARRATOR]<br>Also explicitly named in Mint-rosehip tea. [2402–2402; NARRATOR] |
| `TAG_ingredient_russet_apple` — russet apple | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [376–378; NARRATOR] |
| `TAG_ingredient_rye` — rye | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3875–3875; NARRATOR] |
| `TAG_ingredient_sage` — sage | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1957–1995; NARRATOR] |
| `TAG_ingredient_salt` — salt | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1957–1995; NARRATOR] |
| `TAG_ingredient_savory_herb_sauce` — savory herb sauce | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3968–3968; NARRATOR] |
| `TAG_ingredient_scallion` — scallion | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [130–130; NARRATOR]<br>Also explicitly named in Skipper's shrimp-hotroot soup. [3439–3445; NARRATOR] |
| `TAG_ingredient_scallop` — scallop | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [454–454; NARRATOR]<br>Also explicitly named in Scallops with wild celery and onion. [459–460; NARRATOR] |
| `TAG_ingredient_sea_salt` — sea salt | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [437–440; NARRATOR] |
| `TAG_ingredient_seabird` — seabird | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3656–3656; NARRATOR] |
| `TAG_ingredient_shellfish` — shellfish | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3667–3667; NARRATOR] |
| `TAG_ingredient_soft_cheese` — soft cheese | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [960–960; NARRATOR] |
| `TAG_ingredient_soft_white_cheese` — soft white cheese | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [532–532; NARRATOR] |
| `TAG_ingredient_sole` — sole | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [437–440; NARRATOR] |
| `TAG_ingredient_spices` — spices | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3759–3765; NARRATOR] |
| `TAG_ingredient_strawberry` — strawberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [130–2317; NARRATOR]<br>Also explicitly named in Breakfast strawberry-honey burgoo. [1692–1694; NARRATOR]<br>Also explicitly named in Strawberry flan. [2931–2931; NARRATOR]<br>Also explicitly named in Candied strawberry. [3704–3714; NARRATOR] |
| `TAG_ingredient_tea_rose` — tea rose | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2986–2986; NARRATOR] |
| `TAG_ingredient_turnip` — turnip | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [533–538; NARRATOR]<br>Also explicitly named in Turnip-gravy pastie. [1288–1288; NARRATOR]<br>Also explicitly named in Hazelnut-mushroom-turnip casserole. [1469–1469; NARRATOR]<br>Also explicitly named in Carrot-turnip flan. [2439–2439; NARRATOR] |
| `TAG_ingredient_vanilla` — vanilla | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2775–2810; NARRATOR] |
| `TAG_ingredient_vegetables` — vegetables | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [135–135; NARRATOR]<br>Also explicitly named in Summer vegetable soup. [533–533; NARRATOR]<br>Also explicitly named in Vole vegetable stew. [1152–1153; NARRATOR] |
| `TAG_ingredient_vegetation` — vegetation | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2569–2569; NARRATOR] |
| `TAG_ingredient_vendace` — vendace | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [770–775; NARRATOR] |
| `TAG_ingredient_violet` — violet | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2986–2986; NARRATOR]<br>Also explicitly named in Pennycloud-violet tea. [4063–4063; NARRATOR] |
| `TAG_ingredient_water` — water | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3669–3674; NARRATOR]<br>Also explicitly named in Water-softened stale barley bread. [3827–3827; NARRATOR] |
| `TAG_ingredient_watershrimp` — watershrimp | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [214–219; NARRATOR] |
| `TAG_ingredient_white_cheese` — white cheese | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [135–135; NARRATOR]<br>Also explicitly named in Maple wafer with white cheese. [1289–1289; NARRATOR]<br>Also explicitly named in White cheese with celery and hazelnuts. [3496–3496; NARRATOR] |
| `TAG_ingredient_white_sauce` — white sauce | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2775–2810; NARRATOR] |
| `TAG_ingredient_whitlow` — whitlow | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_wild_celery` — wild celery | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [459–460; NARRATOR] |
| `TAG_ingredient_wild_damson` — wild damson | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2775–2810; NARRATOR] |
| `TAG_ingredient_wild_oat` — wild oat | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [2921–2928; NARRATOR] |
| `TAG_ingredient_wild_strawberry` — wild strawberry | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [1608–1610; NARRATOR] |
| `TAG_ingredient_woodpigeon` — woodpigeon | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [608–820; NARRATOR] |
| `TAG_ingredient_yellow_cheese` — yellow cheese | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [3913–3924; NARRATOR] |
| `TAG_ingredient_young_seaweed` — young seaweed | Explicit source food ingredient or named edible component; see linked dish variants for form and uncertainty. [437–440; NARRATOR] |
| `TAG_ingredient_radish` — Radish | Salad-bed crop in the Abbey garden, also young radishes at Nimbalo's former home. [78–78; NARRATOR] |
| `TAG_ingredient_cucumber` — Cucumber | Cultivated salad-bed ingredient. [78–78; NARRATOR] |
| `TAG_ingredient_cress` — Cress | Garden green; later gathered raw with button mushrooms during breakfast. [78–78; NARRATOR] |
| `TAG_ingredient_lettuce` — Lettuce | Cultivated salad green, also present in Nimbalo's family garden. [78–78; NARRATOR] |
| `TAG_ingredient_apple_orchard_fruit` — Apple orchard fruit | Orchard fruit and later watermeadow forage; russets stored from prior autumn are specifically available for flan. [78–78; NARRATOR] |
| `TAG_ingredient_pear_orchard_fruit` — Pear orchard fruit | Orchard/riverbank fruit; unripe pear has hard flesh and little juice, while autumn pears turn yellow. [78–78; NARRATOR] |
| `TAG_ingredient_plum_orchard_fruit` — Plum orchard fruit | Cultivated fruit, distinct from damson references in preserves and puddings. [78–78; NARRATOR] |
| `TAG_ingredient_damson_fruit` — Damson fruit | Orchard and wild fruit, used across cakes, cordial, pie and wine. [78–78; NARRATOR] |
| `TAG_ingredient_strawberry_fruit` — Strawberry fruit | Cultivated patch, wild forage and decorative candied form; patch can be damaged by racing shortcuts. [78–78; NARRATOR] |
| `TAG_ingredient_blackberry_fruit` — Blackberry fruit | Orchard, river-cove and flatland fruit, eaten fresh and preserved in several dishes. [78–78; NARRATOR] |
| `TAG_ingredient_redcurrant_hedge` — Redcurrant hedge | Fruit-bearing hedge around cultivated grounds, later cordial/trifle ingredient. [78–78; NARRATOR] |
| `TAG_ingredient_milky_grass_sap` — Milky grass sap | Chewed grass stem sap is a sensory snack reference; plant identity unspecified and distinct from greensap milk. [83–83; NARRATOR] |
| `TAG_ingredient_bilberry_seasonal_reference` — Bilberry seasonal reference | Bilberry ripeness is discussed with seasonal caution; do not turn a literary seasonal remark into exact crop timing. [86–88; NARRATOR] |
| `TAG_ingredient_watercress_forage` — Watercress forage | Prospective river forage alongside shrimp and hotroot, not automatically a soup ingredient in every later version. [127–127; NARRATOR] |
| `TAG_ingredient_roasted_trout_scavenging` — Roasted trout scavenging | Felch has a small dead trout falsely claimed as a catch; provenance is a lie, trout species itself is named. [608–613; NARRATOR] |
| `TAG_ingredient_dandelion_buds` — Dandelion buds | Foraged buds described with lemon-like tang. [1557–1557; NARRATOR] |
| `TAG_ingredient_sorrel` — Sorrel | Named flatland forage plant. [1557–1557; NARRATOR] |
| `TAG_ingredient_wild_onion` — Wild onion | Flatland forage and Cavemob terrace crop. [1557–1557; NARRATOR] |
| `TAG_ingredient_cornsalad` — Cornsalad | Named forage green; do not split this plant name into corn and salad. [1557–1557; NARRATOR] |
| `TAG_ingredient_milk_vetch_leaves` — Milk-vetch leaves | Hunters eat these leaves; source-only botanical identity, do not infer safe real-world edibility. [2082–2082; NARRATOR] |
| `TAG_ingredient_scallion_crop` — Scallion crop | Cavemob cultivated produce, also soup/pastie ingredient. [2113–2118; NARRATOR] |
| `TAG_ingredient_young_carrot_crop` — Young carrot crop | Harvested Cavemob terrace produce. [2113–2118; NARRATOR] |
| `TAG_ingredient_wild_ramsons` — Wild ramsons | Strong garlic-scented greens eaten raw near the ditch, affecting nearby sensory description. [2653–2657; NARRATOR] |
| `TAG_ingredient_hazelnut_forage` — Hazelnut forage | Gathered at watermeadow margins; not explicitly a constituent of Jurkin's allfruit filling. [2775–2775; NARRATOR] |

### Object (53)

| ID / label | Source-located facts |
|---|---|
| `TAG_object_sawney_s_jeweled_knife` — Sawney's jeweled knife | Straight throwing knife with amber handle and sapphire setting; later moves through theft, gift, false affiliation evidence and Rukky's cave. [12–51; NARRATOR] |
| `TAG_object_grissoul_s_seer_kit` — Grissoul's seer kit | Symbol-painted barkcloth, bone belt/pouch, starling-skull whistle on twine, stones/shells/bones; colored-fire powders remain chemically unspecified. [14–51; NARRATOR] |
| `TAG_object_juska_tabard_and_belt` — Juska tabard and belt | Plain leather tabard and fine brass-link belt accompany camp equipment; source leather has no automatic game livestock chain. [154–208; NARRATOR] |
| `TAG_object_groundsel_watermint_track_broom` — Groundsel-watermint track broom | Plants used to sweep tracks and mask scent; source concealment tool, not a numeric invisibility buff. [154–208; NARRATOR] |
| `TAG_object_infant_rush_cradle_and_sling` — Infant rush cradle and sling | Woven rush cradle at home; traveling cloak becomes a carry sling, tying craft to family routines. [90–132; NARRATOR] |
| `TAG_object_rillflag_s_ash_spear` — Rillflag's ash spear | Ash-handled spear doubles as walking support during travel. [121–151; NARRATOR] |
| `TAG_object_boorab_s_harlequin_costume` — Boorab's harlequin costume | Ragged bright silk jester clothing and bells on ears; snagging in undergrowth affects travel and comedy. [320–339; NARRATOR] |
| `TAG_object_haredee_gurdee` — Haredee gurdee | Handmade hybrid of mandolin, drums, fiddle, flutes, bugles and harp with levers/bellows; mandolin bowl hides food, maintenance includes grease and dust removal. [349–349; NARRATOR] |
| `TAG_object_reed_pitch_flute_and_bulrush_baton` — Reed pitch flute and bulrush baton | Simple ensemble-leading instruments used with the Dibbun choir; ordinary craft rather than magical objects. [464–515; NARRATOR] |
| `TAG_object_shell_tableware` — Shell tableware | Scallop-shell plate and mussel-shell spoon, useful shape reference but not authorization to harvest excluded shellfish. [437–460; NARRATOR] |
| `TAG_object_tagg_s_youth_attire` — Tagg's youth attire | Barkcloth kilt, eelskin belt, patterned flax wristbands, gold hoop earring and two white fishbone tailrings. [620–620; NARRATOR] |
| `TAG_object_song_s_squirrel_bottle` — Song's squirrel bottle | Heavy dark driftwood carved as a squirrel, mistaken for stone/doorstop; twist-off head, concealed neck container, barkcloth scroll, cream silk ribbon and intact red wax seal. [638–661; NARRATOR] |
| `TAG_object_oak_leaf_seal_keepsake` — Oak-leaf seal keepsake | Small blade carefully preserves a seal instead of destroying it, making fine craft and memory part of clue handling. [659–705; NARRATOR] |
| `TAG_object_hoarg_s_crystal_spectacles` — Hoarg's crystal spectacles | Rock-crystal reading lenses, an elder's practical visual aid. [731–731; NARRATOR] |
| `TAG_object_lantern_service_kit` — Lantern service kit | Cart with vegetable oil scented with lilac, candles, wicks and cleaning tools; six-day refill/trim cadence is a narrated routine, not engine scheduling guidance. [892–898; NARRATOR] |
| `TAG_object_conserved_slate_clue` — Conserved slate clue | Thin blue-gray oblong with Abbess writing, preserved inside an archive volume after routine wall maintenance removes it. [909–931; NARRATOR] |
| `TAG_object_recorder_s_field_writing_kit` — Recorder's field writing kit | Charcoal stick and scrap parchment support collaborative classroom transcription. [977–1000; NARRATOR] |
| `TAG_object_perigord_s_monocle` — Perigord's monocle | Corded lens passes from a hare to Cregga to Song and into the ash-tree clue; material wear and provenance matter. [1275–1302; NARRATOR] |
| `TAG_object_climbing_rope` — Climbing rope | Stout loop over branch, expert placement and assisted footholds let an unpracticed climber reach the clue. [1294–1302; NARRATOR] |
| `TAG_object_vole_coracle` — Vole coracle | Woven-rush basket hull with sycamore blocks supporting a double-ended paddle mast; tested with Tagg aboard. [1307–1313; NARRATOR] |
| `TAG_object_waterproof_sail_cloak` — Waterproof sail-cloak | Cloak treated with beeswax and unspecified secret plant oils doubles as sail and bedding; do not invent the secret oil as canon. [1307–1313; NARRATOR] |
| `TAG_object_poison_dart_kit` — Poison dart kit | Reed blowpipe and protected darts in source defense; chemical preparation and harmful construction details excluded from game reference instructions. [1318–1354; NARRATOR] |
| `TAG_object_gentian_whistle` — Gentian whistle | Nimbalo makes music with a hollow gentian stem and finger holes; botanical form and musical prop value, no speculative pitch formula. [1586–1610; NARRATOR] |
| `TAG_object_firefly_lantern` — Firefly lantern | Ruskem keeps six insects in a light container and feeds honey-water; later Cavemob and Rukky have other lantern counts, stylized ecology. [1665–1702; NARRATOR] |
| `TAG_object_slate_family_portraits` — Slate family portraits | Flint-scratched portraits preserve Ruskem's family and welcome guest faces into his memory collection. [1702–1709; NARRATOR] |
| `TAG_object_pine_log_raft` — Pine-log raft | Trimmed spare branches and a pine trunk make a temporary downstream craft through a seasonal loop. [1717–1721; NARRATOR] |
| `TAG_object_masonry_rubbing_kit` — Masonry rubbing kit | Weighted knife on cord, small nail/stone hammer, linen, honey at corners and beeswax stub; the precise physical transfer method needs adaptation rather than untested duplication. [1739–1755; NARRATOR] |
| `TAG_object_leadership_clue_cloths` — Leadership clue cloths | Lilac/green homespun cloths carry prefixed ITTAGALL initials; reused or apparently freshly placed linens lead to a book of leadership virtues. [1800–3567; NARRATOR] |
| `TAG_object_bell_beam` — Bell beam | Scarred oak beam holds a hidden cloth; careful knife shaving preserves evidence while exposing it. [1800–1808; NARRATOR] |
| `TAG_object_cavemob_tools` — Cavemob tools | Flint-tipped pine clubs, stream net, sieve paddles, food cart, stone ovens, wood paddle, cooling shelf and bronze gong combine food production with ritual space. [1984–2043; NARRATOR] |
| `TAG_object_rillflag_s_carved_beech_bowl` — Rillflag's carved beech bowl | Treasured hand-carved trifle bowl floats briefly with a toddler, sinks, then is recovered; emotional provenance exceeds market value. [2233–2266; NARRATOR] |
| `TAG_object_solstice_regalia` — Solstice regalia | Grainsack flag, woven reed cloak, primrose/kingcup garlands, pink cask staves and elm-wood tankards mark a playful one-night office. [2286–2314; NARRATOR] |
| `TAG_object_robald_s_sycamore_root_club` — Robald's sycamore-root club | Heavy carved club unfamiliar to its educated owner; owning equipment does not grant proficiency. [2424–2448; NARRATOR] |
| `TAG_object_lollery_s_stone_oven_and_slate_turner` — Lollery's stone oven and slate turner | Outdoor stone heat surface and flat slate utensil enable pancake spreading, flipping and folding. [2470–2472; NARRATOR] |
| `TAG_object_raft_safety_ropes_and_mats` — Raft safety ropes and mats | Tethers protect children, mats soften deck resting, watch positions preserve steering during sleep shifts. [2511–2531; NARRATOR] |
| `TAG_object_nimbalo_s_family_battle_axe` — Nimbalo's family battle-axe | Missing from two hearth nails, carried by Dagrab; provenance links a private loss to later confrontation. [2794–2919; NARRATOR] |
| `TAG_object_river_cooled_cider_sack` — River-cooled cider sack | Drink sack trails in current for cooling; storage practice uses travel environment. [2834–2834; NARRATOR] |
| `TAG_object_forthright_embroidered_canopy` — Forthright embroidered canopy | Fine linen fixed by rough pegs among branches, visibly contrasting refined identity with improvised outdoor construction. [2897–2899; NARRATOR] |
| `TAG_object_emergency_stretcher` — Emergency stretcher | Window poles and drapes form a casualty carrier; household objects acquire emergency uses. [2965–2965; NARRATOR] |
| `TAG_object_boorab_s_tray_message` — Boorab's tray message | Charcoal writing on a serving tray communicates departure without specialized stationery. [3111–3114; NARRATOR] |
| `TAG_object_cooper_mallet_and_ash_handles` — Cooper mallet and ash handles | Domestic tools become improvised ambush weapons in an unlawful detention; competence in craft does not justify vigilantism. [3147–3159; NARRATOR] |
| `TAG_object_martin_s_sword_display` — Martin's sword display | Sword held by two silver spikes near the tapestry; retrieved during rescue and later worn as the Warrior's visible office sign. [3291–3294; NARRATOR] |
| `TAG_object_javelin_and_belt_litter` — Javelin-and-belt litter | Initial stretcher is enlarged and padded for comfort, with multiple carriers and head support to reduce jostling. [3302–3380; NARRATOR] |
| `TAG_object_rukky_s_ornamented_cloak` — Rukky's ornamented cloak | Black cloak set with crystal, shell, amber and polished stones, complemented by hoop earrings. [3451–3473; NARRATOR] |
| `TAG_object_rukky_s_instrument_box` — Rukky's instrument box | Dark lacquered box appears amid scented smoke from roots/herbs; exact instruments and treatment procedure are not given. [3475–3475; NARRATOR] |
| `TAG_object_soapwort_rose_almond_wash` — Soapwort-rose-almond wash | Soapwort, rose petals and almond oil explicitly form a cosmetic washing preparation, not food or a healing recipe. [3519–3527; NARRATOR] |
| `TAG_object_crystal_window_repair` — Crystal window repair | Knapped crystal pane held by lead flashing pressed with smooth beech block; ladder partner stabilizes work and broken fragments are cleared. [3680–3684; NARRATOR] |
| `TAG_object_sandstone_memorial` — Sandstone memorial | Cregga's smooth engraved headstone and renewed flowers make grief an ongoing community activity. [3692–3703; NARRATOR] |
| `TAG_object_welcome_banner` — Welcome banner | Old tablecloth attached to a window pole converts domestic surplus into communal celebration. [3810–3810; NARRATOR] |
| `TAG_object_russano_s_hardwood_staff` — Russano's hardwood staff | Short dark polished hardwood scepter-like stick, with simple brown clothing instead of a sword, conveys disciplined authority. [4019–4027; NARRATOR] |
| `TAG_object_cregga_s_steel_medallion` — Cregga's steel medallion | Large heavy burnished-steel likeness with two ruby eyes and chain, forged at Salamandastron and placed on the headstone. [4049–4049; NARRATOR] |
| `TAG_object_deyna_s_souvenir_tailring` — Deyna's souvenir tailring | Polished bone ring given to Rosabel after her reading, linking the living witness to a communal archive. [4059–4059; NARRATOR] |
| `TAG_object_recorder_s_furniture_and_coverlet` — Recorder's furniture and coverlet | Desk, shelves, cupboards and an embroidered bedcover made by friends turn an inherited room into a living workplace. [4062–4062; NARRATOR] |

### Ecology (23)

| ID / label | Source-located facts |
|---|---|
| `TAG_ecology_speedwell_identity_motif` — Speedwell identity motif | Four-petal pink flower likeness, one petal thinner, becomes a physical identity clue on Deyna's right paw; no genetic rule derived. [100–110; NARRATOR] |
| `TAG_ecology_woodland_seasonal_texture` — Woodland seasonal texture | Spring rain, heat, dew, dogrose, vetchling, red clover, orchards and garden rows create inhabited woodland rather than empty wilderness. [68–151; NARRATOR] |
| `TAG_ecology_tidal_foraging` — Tidal foraging | Rockpools, coves and young seaweed offer food, but tide state controls safe access and coercive timing increases danger. [437–459; NARRATOR] |
| `TAG_ecology_river_vegetation_and_depth` — River vegetation and depth | Reeds do not guarantee shallows; trailing weed and a concealed rock ledge create drowning risks and failed rescues. [1389–1403; NARRATOR] |
| `TAG_ecology_burbot_and_pike_hazard` — Burbot and pike hazard | Source presents unusually aggressive burbot and blood-attracted pike; stylized narrative ecology, not real-species behavioral guidance or harvest unlock. [1400–1403; NARRATOR] |
| `TAG_ecology_bittern_camouflage` — Bittern camouflage | Brown-black-fawn plumage, green legs and motionless concealment offer recognizable animal anatomy and scouting reference. [1515–1532; NARRATOR] |
| `TAG_ecology_flatland_flora_and_weather_signs` — Flatland flora and weather signs | Heather, furze, teasel, grasshoppers, butterflies, bees and low-flying swifts establish habitat and impending storm through character observation. [1557–1617; NARRATOR] |
| `TAG_ecology_smooth_snake` — Smooth snake | Gray snake with dark eye stripe constricts Nimbalo; Tagg releases it without killing, distinguishing predator hazard from moral faction. [1557–1571; NARRATOR] |
| `TAG_ecology_adder_den` — Adder den | Several adders occupy an apparent shelter; no sapient speech or exact population certainty established. [1625–1652; NARRATOR] |
| `TAG_ecology_flash_flood_activation` — Flash-flood activation | Storm changes dry channels to muddy transport and danger corridors; high-bank shelters remain different from low caves. [1695–1727; NARRATOR] |
| `TAG_ecology_mountain_exposure` — Mountain exposure | Snowfields, ridges, thin air, poor fuel and little food frustrate pursuers' romantic assumptions about mountains. [1889–1894; NARRATOR] |
| `TAG_ecology_elver_overland_migration` — Elver overland migration | Dewy grass and stream entry guide mass juvenile-eel movement in the story; game eel remains nonharvestable despite source consumption. [1957–1974; NARRATOR] |
| `TAG_ecology_cavern_limestone_and_lake` — Cavern limestone and lake | Waterfall, limestone ceiling, stalactite, cold deep lake and ledges create a habitat with both farms and a dangerous eel. [1984–2043; NARRATOR] |
| `TAG_ecology_terrace_alluvium_and_scree` — Terrace alluvium and scree | Fertile deposited soil under unstable slope supports diverse cultivation but exposes crops and labor to rockfall. [2085–2124; NARRATOR] |
| `TAG_ecology_pond_grayling` — Pond grayling | Large male fish with purplish fin threatens a toddler; this hazard appearance does not add grayling to the game food whitelist. [2244–2265; NARRATOR] |
| `TAG_ecology_healer_s_botanical_memory_poem` — Healer's botanical memory poem | White campion, valerian, angelica, yarrow, dock, sanicle, water-parsnip, whitlow, wintergreen and pepperwort appear in fictional treatment lore; woodruff is a perfume reference. [2192–2209; NARRATOR] |
| `TAG_ecology_agrimony_and_soapwort_care` — Agrimony and soapwort care | A physick and cleansing bath are source care references, without exact formulation or validated effects. [2258–2258; NARRATOR] |
| `TAG_ecology_watermeadow_habitat` — Watermeadow habitat | Waterweed, flat rocks, minnows, dragonflies, swallows, willow warblers, lilies and bulrushes surround fruit-bearing margins. [2719–2775; NARRATOR] |
| `TAG_ecology_woodland_tracking_cues` — Woodland tracking cues | Distressed tree pipit, snagged cloth on holly, fern/loam/moss prints, rosebay willowherb and buckthorn support multi-sense tracking. [2873–2913; NARRATOR] |
| `TAG_ecology_firefly_and_mineral_cave_palette` — Firefly and mineral cave palette | Amber, carnelian, peridot, black jet, crystal and metal catch small insect lights; Rukky's palette is jewel-dark rather than generic green woodland. [3451–3475; NARRATOR] |
| `TAG_ecology_autumn_watch_palette` — Autumn watch palette | Russet apples, yellow pears, purple berries, blue harebells, spinning sycamore seed pods and cold fog connect seasonal waiting with memory. [3685–3780; NARRATOR] |
| `TAG_ecology_first_frost_at_redwall` — First frost at Redwall | Frost on red sandstone, rowan red/cream berries, brown fir cones and orange-peach dawn establish late-season calm before a military threat. [3968–3974; NARRATOR] |
| `TAG_ecology_vervain_by_the_memorial` — Vervain by the memorial | Delicate pink flowers and subtle fragrance soften a military leader's public grief; botanical identity retained without edible inference. [4054–4055; NARRATOR] |

### Culture (26)

| ID / label | Source-located facts |
|---|---|
| `TAG_culture_river_back_newborn_rite` — River-back newborn rite | Otter parent takes a newborn to flowing water before the naming celebration; rite distinguishes river current from the still pond. [121–201; NARRATOR] |
| `TAG_culture_taggerung_belief_and_investiture` — Taggerung belief and investiture | Paint, feather, flint, pike talisman and old-language naming declare a chosen warrior; seers disagree and manipulate interpretation. [278–293; NARRATOR] |
| `TAG_culture_juska_challenge_succession` — Juska challenge succession | Violent succession is disguised as prophecy and inherited naming; a source political institution requiring filtered game treatment. [1067–1116; NARRATOR] |
| `TAG_culture_summer_of_friendship_feast` — Summer of Friendship feast | Mhera proposes feast, music, dance, games and poetry while unresolved bereavement continues. [253–258; NARRATOR] |
| `TAG_culture_cook_appreciation` — Cook appreciation | Choir, bouquets and washer volunteers publicly honor food labor rather than only combat achievements. [464–568; NARRATOR] |
| `TAG_culture_hare_speech_and_performance` — Hare speech and performance | Elaborate names, mock military diction, appetite jokes and rhythmic interjections shape Boorab's voice; use light distinct voices rather than dense phonetic transcription. [320–409; NARRATOR] |
| `TAG_culture_mole_speech_and_gesture` — Mole speech and gesture | Warm dialect, snout salutes and embarrassed tail movement support recognizable animal expression without making intelligence a species joke. [629–656; NARRATOR] |
| `TAG_culture_vole_gob_music` — Vole gob music | Voice percussion, jaw harps and acrobatic dancing turn an underground host household into a specific cultural encounter. [1154–1171; NARRATOR] |
| `TAG_culture_brainy_duck_ballad` — Brainy Duck ballad | Comic nested tale uses a duck/doctor pun; treat characters as performance content, not historical world entities. [1004–1030; NARRATOR] |
| `TAG_culture_abbey_bell_tradition` — Abbey bell tradition | Bells mark noon, midnight, eventide, feast, victory and death; Joseph-bell splitting history is a character's lesson, not newly verified chronology. [1773–1774; NARRATOR] |
| `TAG_culture_cavemob_public_reform` — Cavemob public reform | After a rescue, community agreement ends sacrifice, ear-smacking, tail-kicking and name-calling; choose this reformed practice for the game's preferred cultural baseline. [2001–2057; NARRATOR] |
| `TAG_culture_otter_hullabaloo` — Otter Hullabaloo | Every fourth summer, crews and northern sea otters reunite at the coast for wavesports, songs, dancing, bonfires and food, potentially staying until autumn. [2146–2147; NARRATOR] |
| `TAG_culture_wall_n_grass_race` — Wall'n'grass race | Annual midsummer-eve event has parallel walltop and ground routes, rules against shortcuts/pushing, garlanded winners and one-night Lord/Lady Strawberry titles. [2274–2334; NARRATOR] |
| `TAG_culture_dillypin_spiketussling` — Dillypin spiketussling | Proud athletic contest permits an otter's anatomical adaptation; respectful victory and face-saving compliments create friendship. [2494–2501; NARRATOR] |
| `TAG_culture_dillypin_pawspike_dance` — Dillypin pawspike dance | Old family/tribal chant pairs paw, spike and snout gestures, turns and bows; outsiders can learn and join. [2815–2834; NARRATOR] |
| `TAG_culture_riverbend_song` — Riverbend song | Tingle and Robald's performance gives river travel longing and tenderness; implied lost love belongs to song, not a verified missing-person quest. [2834–2872; NARRATOR] |
| `TAG_culture_private_mourning` — Private mourning | Nimbalo privately tends his father's body and clothing despite abuse, and Tagg respects the confidence without forcing disclosure. [2783–2809; NARRATOR] |
| `TAG_culture_abbess_appointment` — Abbess appointment | Community approval follows long demonstration of care; leadership virtues in the teaching book include humility, patience, wisdom, understanding, friendliness, strength, courage, compassion, fairness and decision. [3555–3739; NARRATOR] |
| `TAG_culture_cregga_s_honor_feast` — Cregga's honor feast | Accessible banquet around her bed celebrates her living presence; she dies during a remembered march song, and mourning follows without resurrection. [3511–3618; NARRATOR] |
| `TAG_culture_battle_of_boiling_water_song` — Battle of Boiling Water song | Traditional military food-comedy passed through Boorab's grandfather; named officers remain unverified song personas. [3574–3617; NARRATOR] |
| `TAG_culture_home_singing` — Home-singing | Residents sing to call travelers safely home; coincident return supports hope but does not prove supernatural causation. [3780–3808; NARRATOR] |
| `TAG_culture_hornpipe_and_entwined_rudders` — Hornpipe and entwined rudders | Otter crew finishes a dance facing outward with patterned entwined tails, a direct animation and anatomy reference. [3925–3925; NARRATOR] |
| `TAG_culture_friendly_fibbing_contest` — Friendly fibbing contest | Obvious escalating boasts invite elders and children to participate; Alkanet's medicinal threat is part of humor, not a proven treatment effect. [3946–3963; NARRATOR] |
| `TAG_culture_eulalia_recognition_call` — Eulalia recognition call | A repeated collective war cry identifies friends at distance and accelerates approaching relief; do not reproduce copyrighted song lyrics to model this function. [4007–4015; NARRATOR] |
| `TAG_culture_hospitality_and_capacity_debate` — Hospitality and capacity debate | Russano worries a thousand hares will burden supplies; Mhera insists Redwall can host them for many seasons. Keep both judgments, not infinite storage. [4051–4056; NARRATOR] |
| `TAG_culture_living_communal_archive` — Living communal archive | Four-evening reading, children's questions, a witness's keepsake, formal archiving and occupational succession make history a practiced community activity. [4058–4065; NARRATOR] |

### System (25)

| ID / label | Source-located facts |
|---|---|
| `TAG_system_individual_climbing_proficiency` — Individual climbing proficiency | Fwirl climbs expertly while Mhera needs rope, guidance and footholds; not all members of a species share unlimited access. [1294–1302; NARRATOR] |
| `TAG_system_masonry_traversal_collaboration` — Masonry traversal collaboration | Nonliterate Fwirl can reach and capture an inscription while literate companions interpret it; literacy and climbing are separate competencies. [1739–1755; NARRATOR] |
| `TAG_system_burrows_as_homes_and_reused_infrastructure` — Burrows as homes and reused infrastructure | Pear-root multi-family burrow has concealed bank entry and internal rooms; later abandoned mole tunnel is repurposed by someone else. [1139–1173; NARRATOR] |
| `TAG_system_water_route_modes` — Water route modes | Coracle, paddle and sail-cloak provide traversal distinct from swimming; capacity is tested locally, not assumed from species. [1307–1313; NARRATOR] |
| `TAG_system_current_aware_rescue` — Current-aware rescue | Otter carries a non-swimmer clear of water while propelling with remaining limbs and tail; rescue changes speed, posture and safety obligations. [1653–1659; NARRATOR] |
| `TAG_system_flood_opened_route_graph` — Flood-opened route graph | Rain activates a looping stream route that can carry travelers downstream toward a mountain; dry and wet path availability differ. [1720–1727; NARRATOR] |
| `TAG_system_depth_visibility_and_failed_rescue` — Depth visibility and failed rescue | Reed-covered water, hidden ledges, weeds, panic and weak swimming combine; a chain of paws or bow used as a reach aid can fail. [1392–1403; NARRATOR] |
| `TAG_system_collective_net_rescue` — Collective net rescue | Weighted harvest net and multiple pullers save a child and then an exhausted otter from deep cold water; civilian tools support rescue roles. [2027–2043; NARRATOR] |
| `TAG_system_forage_timing_and_tide` — Forage timing and tide | Safe collection depends on tide and local judgment; authoritarian deadlines impose avoidable risk. [437–459; NARRATOR] |
| `TAG_system_inhabited_canopy` — Inhabited canopy | Lashed branch platforms and expert tree movement make canopy a place to dwell and travel, with open edges and binding/reach constraints. [1495–1530; NARRATOR] |
| `TAG_system_weather_dependent_tracking` — Weather-dependent tracking | Rain washes sap and scent; protected prints, broken vegetation, gear marks and disturbed birds support uncertain rather than omniscient tracking. [1318–1355; NARRATOR] |
| `TAG_system_terrain_and_load_cost` — Terrain and load cost | A single-file party is bottlenecked by an unfit leader; carrying large instruments or injured companions changes practical movement. [1328–1329; NARRATOR] |
| `TAG_system_hospitality_and_gift_reciprocity` — Hospitality and gift reciprocity | Food, cloak and boat gifts create support obligations and vulnerable hosts; possessions carry relationship history rather than only price. [1304–1316; NARRATOR] |
| `TAG_system_food_mobility_conversion` — Food mobility conversion | Kitchen turns cabbage-fennel bake into portable pasties for wallguards, linking recipe form to duty location. [2640–2683; NARRATOR] |
| `TAG_system_specialist_care_and_transport` — Specialist care and transport | Local healer recognizes a limit, trusted otter network reaches a recluse specialist, carriers improve litter comfort, and provisions sustain recovery. [3342–3480; NARRATOR] |
| `TAG_system_accessible_room_and_feast_layout` — Accessible room and feast layout | A heavy, frail badger cannot use stairs, so care bed and three-table banquet occupy Great Hall floor with access gap near tapestry. [3393–3511; NARRATOR] |
| `TAG_system_layered_alarms_and_covered_guards` — Layered alarms and covered guards | Arrows can strike bells without intentional signaling, stone harassment bluffs force size, and withdrawing every lookout creates an information failure. [2960–3235; NARRATOR] |
| `TAG_system_appearance_based_false_identification` — Appearance-based false identification | Tattoo and tail shape trigger wrongful detention by frightened residents; listening, disclosure and evidence correct the error. [3137–3282; NARRATOR] |
| `TAG_system_gate_retreat_and_defender_cooperation` — Gate retreat and defender cooperation | Gate defenders, wall throwers, closing doors and allied pincer movement form interacting tactical roles; exact narrative counts are not balance values. [3974–4016; NARRATOR] |
| `TAG_system_nonlethal_surrender_resolution` — Nonlethal surrender resolution | Overwhelming organized relief enables disarmament and withdrawal rather than slaughter; adapt away from source humiliation and forced crawling. [4016–4036; NARRATOR] |
| `TAG_system_daily_work_under_crisis` — Daily work under crisis | Watch rotations require warm food, heat, blankets and safety ropes; cooks remain active while others wait and sing. [3759–3765; NARRATOR] |
| `TAG_system_occupational_succession` — Occupational succession | Recorder, Foremole, Head Cook, music and infirmary roles pass through practice and retirement; species and gender do not hard-lock the roles. [4062–4063; NARRATOR] |
| `TAG_system_memorial_stewardship` — Memorial stewardship | Flower gathering, crafted tribute and room reuse let grief leave persistent world changes while life continues. [3692–4062; NARRATOR] |
| `TAG_system_portable_cold_storage` — Portable cold storage | Raft travelers cool cider in current; environment can support food handling without adding a powered technology. [2834–2834; NARRATOR] |
| `TAG_system_child_safety_environmental_care` — Child-safety environmental care | Raft ropes, walltop supervision and swimming rescue are care systems; avoid rewarding child danger, cruelty or coercion. [2511–2531; NARRATOR] |

### Theme (15)

| ID / label | Source-located facts |
|---|---|
| `TAG_theme_chosen_identity_and_imposed_identity` — Chosen identity and imposed identity | Tagg refuses killing a helpless captive despite clan command; conscience is a decision, not a face mark or training outcome. [844–877; NARRATOR] |
| `TAG_theme_hospitality_as_practiced_labor` — Hospitality as practiced labor | Bread kneading, serving, washing and covering a shift make belonging tangible; welcome requires work by ordinary residents. [1053–1065; NARRATOR] |
| `TAG_theme_grief_within_abundance` — Grief within abundance | A favorite soup recalls missing kin during a joyful feast; shared food does not erase loss and elders permit tears. [547–562; NARRATOR] |
| `TAG_theme_elder_authority_and_changing_needs` — Elder authority and changing needs | Cregga retains insight and humor while needing help with stairs and room tasks; neither helplessness nor superhuman compensation is the whole portrayal. [623–650; NARRATOR] |
| `TAG_theme_appearance_is_weak_moral_evidence` — Appearance is weak moral evidence | A tattooed otter shows mercy while a woodland squirrel can be dangerous; good-community prejudice later repeats this error. [1512–1549; NARRATOR] |
| `TAG_theme_bravado_protects_vulnerability` — Bravado protects vulnerability | Nimbalo's tall stories coexist with fear, loneliness and a painful history; friendship does not demand immediate disclosure. [1686–1709; NARRATOR] |
| `TAG_theme_moral_limits_of_heroic_violence` — Moral limits of heroic violence | Tagg's coercive interrogation and Cavemob vengeance conflict with his earlier mercy; record the tension rather than laundering all hero actions into design approval. [2368–2404; NARRATOR] |
| `TAG_theme_everyday_leadership_before_office` — Everyday leadership before office | Mhera protects, delegates, listens to dissent and learns military terms; practical judgment precedes a title or solved puzzle. [2622–2640; NARRATOR] |
| `TAG_theme_craft_as_memory` — Craft as memory | A carved bottle, seal, bowl and portrait retain relationships across years; ordinary items deserve emotional provenance. [638–661; NARRATOR] |
| `TAG_theme_domestic_variety_and_visible_life` — Domestic variety and visible life | Dance, cooking, care, class friction, music and private grief give travelers and settlements identities beyond combat rosters. [2815–2834; NARRATOR] |
| `TAG_theme_consequences_outlast_victory` — Consequences outlast victory | Reunion and rescue coexist with serious wounds, extended care and Cregga's death; tactical success does not restore the previous world. [3295–3618; NARRATOR] |
| `TAG_theme_calm_power_and_mercy` — Calm power and mercy | Russano's immense force is meaningful because disciplined restraint prevents expected slaughter and makes space for mourning. [4014–4049; NARRATOR] |
| `TAG_theme_uncertain_supernatural_truth` — Uncertain supernatural truth | Russano reports a dream of Cregga; characters interpret dreams and home-singing, but the game need not establish objective magic. [4039–4044; NARRATOR] |
| `TAG_theme_warm_humor_with_repair` — Warm humor with repair | Teasing that hurts is challenged and apologized for; affectionate comedy should not become an excuse for contempt. [2167–2188; NARRATOR] |
| `TAG_theme_intergenerational_future` — Intergenerational future | The epilogue changes jobs and makes a historian's office in a memorial room: continuity is active care, learning and adaptation. [4058–4065; NARRATOR] |

## Recipe candidate index

The JSON holds ingredient-by-ingredient provenance, substitutions, confidence and rationale. Counts include explicitly marked song, rejected-joke and requested-but-unserved candidates.

| Source dish | Proposed game candidate | Evidence |
|---|---|---|
| Autumn Harvest soup | Autumn Harvest soup | 5–5; CONTENT_CANDIDATE_NOT_BALANCED |
| Fire-skewered mackerel | Fire-skewered mackerel | 12–12; CONTENT_CANDIDATE_NOT_BALANCED |
| Nettle beer | Nettle beer | 14–14; CONTENT_CANDIDATE_NOT_BALANCED |
| Mackerel milkweed and dock stew | Mackerel, spinach and sorrel stew | 18–18; CONTENT_CANDIDATE_NOT_BALANCED |
| Candied chestnuts | Candied chestnuts | 76–85; CONTENT_CANDIDATE_NOT_BALANCED |
| October Ale | October Ale | 85–3515; CONTENT_CANDIDATE_NOT_BALANCED |
| Preserved fruit pieces | Preserved fruit pieces | 113–113; CONTENT_CANDIDATE_NOT_BALANCED |
| Mushroom-scallion pasties | Mushroom-scallion pasties | 130–130; CONTENT_CANDIDATE_NOT_BALANCED |
| Fruit-honey cake | Fruit-honey cake | 130–130; CONTENT_CANDIDATE_NOT_BALANCED |
| Strawberry fizz | Strawberry fizz | 130–2317; CONTENT_CANDIDATE_NOT_BALANCED |
| Spring vegetable soup | Spring vegetable soup | 135–135; CONTENT_CANDIDATE_NOT_BALANCED |
| Oatbread | Oatbread | 135–135; CONTENT_CANDIDATE_NOT_BALANCED |
| White cheese with hazelnuts | White cheese with hazelnuts — plant/approved-fish game adaptation | 135–135; CONTENT_CANDIDATE_NOT_BALANCED |
| Apple flan | Apple flan | 135–135; CONTENT_CANDIDATE_NOT_BALANCED |
| Steamed plum pudding | Steamed plum pudding | 146–148; CONTENT_CANDIDATE_NOT_BALANCED |
| Watershrimp and hotroot soup | Mussel and hotroot soup | 214–219; CONTENT_CANDIDATE_NOT_BALANCED |
| Onionbread | Onionbread | 214–219; CONTENT_CANDIDATE_NOT_BALANCED |
| Cold mint-dandelion tea | Cold mint-dandelion tea | 214–219; CONTENT_CANDIDATE_NOT_BALANCED |
| Heavy fruitcake | Heavy fruitcake | 219–219; CONTENT_CANDIDATE_NOT_BALANCED |
| Blackberry wine | Blackberry wine | 219–219; CONTENT_CANDIDATE_NOT_BALANCED |
| Flat oatcakes | Flat oatcakes | 262–262; CONTENT_CANDIDATE_NOT_BALANCED |
| Scones | Scones | 262–262; CONTENT_CANDIDATE_NOT_BALANCED |
| Turnovers | Turnovers | 262–262; CONTENT_CANDIDATE_NOT_BALANCED |
| Poached dace | Poached dace | 266–266; CONTENT_CANDIDATE_NOT_BALANCED |
| Apple pie | Apple pie | 326–330; CONTENT_CANDIDATE_NOT_BALANCED |
| Onion pastie | Onion pastie | 326–330; CONTENT_CANDIDATE_NOT_BALANCED |
| Apple-raspberry flan with mint cream pattern | Apple-raspberry flan with mint cream pattern — plant/approved-fish game adaptation | 376–378; CONTENT_CANDIDATE_NOT_BALANCED |
| Crumpets | Crumpets | 420–420; CONTENT_CANDIDATE_NOT_BALANCED |
| Baby sole with seaweed | Whitefish with young seaweed | 437–440; CONTENT_CANDIDATE_NOT_BALANCED |
| Raw scallop | Gently cooked mussels | 454–454; CONTENT_CANDIDATE_NOT_BALANCED |
| Scallops with wild celery and onion | Mussels with wild celery and onion | 459–460; CONTENT_CANDIDATE_NOT_BALANCED |
| Blackberry pudding with meadowcream | Blackberry pudding with meadowcream — plant/approved-fish game adaptation | 518–524; CONTENT_CANDIDATE_NOT_BALANCED |
| Hazelnut cake | Hazelnut cake | 518–524; CONTENT_CANDIDATE_NOT_BALANCED |
| Mushroom pastie with onion gravy | Mushroom pastie with onion gravy | 525–525; CONTENT_CANDIDATE_NOT_BALANCED |
| Summer fruit salad | Summer fruit salad | 532–532; CONTENT_CANDIDATE_NOT_BALANCED |
| Mint wafer with soft white cheese | Mint wafer with soft white cheese — plant/approved-fish game adaptation | 532–532; CONTENT_CANDIDATE_NOT_BALANCED |
| Deeper'n ever turnip-tater-beetroot pie | Deeper'n ever turnip-tater-beetroot pie | 533–538; CONTENT_CANDIDATE_NOT_BALANCED |
| Summer vegetable soup | Summer vegetable soup | 533–533; CONTENT_CANDIDATE_NOT_BALANCED |
| Apple cream flan | Apple cream flan — plant/approved-fish game adaptation | 533–533; CONTENT_CANDIDATE_NOT_BALANCED |
| Dandelion cordial | Dandelion cordial | 536–536; CONTENT_CANDIDATE_NOT_BALANCED |
| Elderberry wine | Elderberry wine | 537–537; CONTENT_CANDIDATE_NOT_BALANCED |
| Plum cake | Plum cake | 542–542; CONTENT_CANDIDATE_NOT_BALANCED |
| Trifle | Trifle | 545–545; CONTENT_CANDIDATE_NOT_BALANCED |
| Old damson wine | Old damson wine | 557–562; CONTENT_CANDIDATE_NOT_BALANCED |
| Honeyed hazelnut slice | Honeyed hazelnut slice | 585–585; CONTENT_CANDIDATE_NOT_BALANCED |
| Gundil's mixed hotroot drink | Gundil's mixed hotroot drink | 598–598; CONTENT_CANDIDATE_NOT_BALANCED |
| Roasted chestnuts | Roasted chestnuts | 598–598; CONTENT_CANDIDATE_NOT_BALANCED |
| Dandelion wine | Dandelion wine | 598–598; CONTENT_CANDIDATE_NOT_BALANCED |
| Hot mint tea | Hot mint tea | 598–598; CONTENT_CANDIDATE_NOT_BALANCED |
| Roast woodpigeon | Roast woodland mushroom caps | 608–820; CONTENT_CANDIDATE_NOT_BALANCED |
| Mushroom-celery broth with hotroot pepper | Mushroom-celery broth with hotroot pepper | 632–644; CONTENT_CANDIDATE_NOT_BALANCED |
| Barley farl | Barley farl | 632–644; CONTENT_CANDIDATE_NOT_BALANCED |
| Cold mint tea | Cold mint tea | 632–644; CONTENT_CANDIDATE_NOT_BALANCED |
| Minted potato-leek turnover | Minted potato-leek turnover | 719–727; CONTENT_CANDIDATE_NOT_BALANCED |
| Fire-roasted vendace | Willow-roasted whitefish | 770–775; CONTENT_CANDIDATE_NOT_BALANCED |
| Roast dove | Roast small mushroom caps | 821–835; CONTENT_CANDIDATE_NOT_BALANCED |
| Raw dove eggs | Stuffed small mushrooms | 821–835; CONTENT_CANDIDATE_NOT_BALANCED |
| Honey-sweet mint tea | Honey-sweet mint tea | 821–821; CONTENT_CANDIDATE_NOT_BALANCED |
| Woodland trifle | Woodland trifle — plant/approved-fish game adaptation | 937–938; CONTENT_CANDIDATE_NOT_BALANCED |
| Celery-carrot soup | Celery-carrot soup | 939–941; CONTENT_CANDIDATE_NOT_BALANCED |
| Crusty bread with chive cheese | Crusty bread with chive cheese — plant/approved-fish game adaptation | 960–960; CONTENT_CANDIDATE_NOT_BALANCED |
| Baton loaf | Baton loaf | 975–975; CONTENT_CANDIDATE_NOT_BALANCED |
| Oatmeal scones | Oatmeal scones | 1053–1059; CONTENT_CANDIDATE_NOT_BALANCED |
| Hot nutbread | Hot nutbread | 1152–1153; CONTENT_CANDIDATE_NOT_BALANCED |
| Vole vegetable stew | Vole vegetable stew | 1152–1153; CONTENT_CANDIDATE_NOT_BALANCED |
| Bankbrew | Bankbrew | 1152–1153; CONTENT_CANDIDATE_NOT_BALANCED |
| Blackberry pies | Blackberry pies | 1187–1187; CONTENT_CANDIDATE_NOT_BALANCED |
| Pennywort cordial | Mint cordial | 1191–1191; CONTENT_CANDIDATE_NOT_BALANCED |
| Oatmeal scone with honey | Oatmeal scone with honey | 1191–1191; CONTENT_CANDIDATE_NOT_BALANCED |
| Barley toast with quince jam | Barley toast with quince jam | 1197–1197; CONTENT_CANDIDATE_NOT_BALANCED |
| Quince jam | Quince jam | 1197–1197; CONTENT_CANDIDATE_NOT_BALANCED |
| Candied plum | Candied plum | 1202–1202; CONTENT_CANDIDATE_NOT_BALANCED |
| Cream mushroom soup | Cream mushroom soup — plant/approved-fish game adaptation | 1280–1282; CONTENT_CANDIDATE_NOT_BALANCED |
| Broggle's nutfarls | Broggle's nutfarls | 1280–1282; CONTENT_CANDIDATE_NOT_BALANCED |
| Turnip-gravy pastie | Turnip-gravy pastie | 1288–1288; CONTENT_CANDIDATE_NOT_BALANCED |
| Maple wafer with white cheese | Maple wafer with white cheese — plant/approved-fish game adaptation | 1289–1289; CONTENT_CANDIDATE_NOT_BALANCED |
| Dried fish | Dried fish — plant/approved-fish game adaptation | 1319–1323; CONTENT_CANDIDATE_NOT_BALANCED |
| Vole oat-and-dried-fruit travel cakes | Vole oat-and-dried-fruit travel cakes | 1359–1509; CONTENT_CANDIDATE_NOT_BALANCED |
| Pear cordial | Pear cordial | 1359–1359; CONTENT_CANDIDATE_NOT_BALANCED |
| Grilled burbot | Grilled whitefish | 1403–1410; CONTENT_CANDIDATE_NOT_BALANCED |
| Steamed damson-plum pudding | Steamed damson-plum pudding | 1469–1477; CONTENT_CANDIDATE_NOT_BALANCED |
| Hazelnut-mushroom-turnip casserole | Hazelnut-mushroom-turnip casserole | 1469–1469; CONTENT_CANDIDATE_NOT_BALANCED |
| Dandelion-burdock cordial | Dandelion-burdock cordial | 1469–1469; CONTENT_CANDIDATE_NOT_BALANCED |
| Nimbalo's flatlands salad | Nimbalo-style safe-greens and berry salad | 1608–1610; CONTENT_CANDIDATE_NOT_BALANCED |
| Ruskem's burgoo | Ruskem's burgoo | 1679–1679; CONTENT_CANDIDATE_NOT_BALANCED |
| Mint-comfrey tea | Gentle mint infusion | 1680–1680; CONTENT_CANDIDATE_NOT_BALANCED |
| Breakfast strawberry-honey burgoo | Breakfast strawberry-honey burgoo | 1692–1694; CONTENT_CANDIDATE_NOT_BALANCED |
| Fruit loaves | Fruit loaves | 1713–1713; CONTENT_CANDIDATE_NOT_BALANCED |
| Rosehip tea | Rosehip tea | 1735–1735; CONTENT_CANDIDATE_NOT_BALANCED |
| Old barley beer | Old barley beer | 1921–1937; CONTENT_CANDIDATE_NOT_BALANCED |
| Mellow cheese | Mellow cheese — plant/approved-fish game adaptation | 1921–1937; CONTENT_CANDIDATE_NOT_BALANCED |
| Snakeyfish pie | Cavemob-style dace and herb pie | 1957–1995; CONTENT_CANDIDATE_NOT_BALANCED |
| Stewed elvers | Stewed dace | 1984–1984; CONTENT_CANDIDATE_NOT_BALANCED |
| Baked elvers | Baked dace | 1984–1984; CONTENT_CANDIDATE_NOT_BALANCED |
| Roasted elvers | Roasted dace | 1984–1984; CONTENT_CANDIDATE_NOT_BALANCED |
| Fried elvers | Fried dace | 1984–1984; CONTENT_CANDIDATE_NOT_BALANCED |
| Iced rosehip-almond-flower tea | Iced rosehip and apple-blossom tea | 1991–1994; CONTENT_CANDIDATE_NOT_BALANCED |
| Celery-chestnut bake | Celery-chestnut bake | 2151–2151; CONTENT_CANDIDATE_NOT_BALANCED |
| Cherryjuice wine | Cherryjuice wine | 2152–2161; CONTENT_CANDIDATE_NOT_BALANCED |
| Pennycress cordial | Cress-and-mint cordial | 2152–2161; CONTENT_CANDIDATE_NOT_BALANCED |
| Sweet cider | Sweet cider | 2152–2161; CONTENT_CANDIDATE_NOT_BALANCED |
| Celery salad | Celery salad | 2152–2161; CONTENT_CANDIDATE_NOT_BALANCED |
| Nut shortbreads | Nut shortbreads | 2330–2330; CONTENT_CANDIDATE_NOT_BALANCED |
| Mint-rosehip tea | Mint-rosehip tea | 2402–2402; CONTENT_CANDIDATE_NOT_BALANCED |
| Nut cheese | Nut cheese | 2437–2437; CONTENT_CANDIDATE_NOT_BALANCED |
| Fruit biscuits | Fruit biscuits | 2437–2443; CONTENT_CANDIDATE_NOT_BALANCED |
| Spikebeer | Spikebeer | 2437–2437; CONTENT_CANDIDATE_NOT_BALANCED |
| Candied apples | Candied apples | 2437–2437; CONTENT_CANDIDATE_NOT_BALANCED |
| Lollery's raisin teabread | Lollery's raisin teabread | 2437–2437; CONTENT_CANDIDATE_NOT_BALANCED |
| Mushroom soup | Mushroom soup | 2439–2439; CONTENT_CANDIDATE_NOT_BALANCED |
| Carrot-turnip flan | Carrot-turnip flan | 2439–2439; CONTENT_CANDIDATE_NOT_BALANCED |
| Lollery's folded honey-berry pancakes | Lollery-style barley-nut honey-berry pancakes | 2472–2511; CONTENT_CANDIDATE_NOT_BALANCED |
| Greensap milk | Greensap-inspired birch drink | 2486–2503; CONTENT_CANDIDATE_NOT_BALANCED |
| Dandelion tea | Dandelion tea | 2532–3780; CONTENT_CANDIDATE_NOT_BALANCED |
| Poskra's vegetation soup | Poskra's vegetation soup | 2569–2569; CONTENT_CANDIDATE_NOT_BALANCED |
| Bird eggs | Soft mushroom mash | 2569–2569; CONTENT_CANDIDATE_NOT_BALANCED |
| Cabbage-fennel bake | Cabbage-fennel bake | 2640–2640; CONTENT_CANDIDATE_NOT_BALANCED |
| Cabbage-fennel pasties | Cabbage-fennel pasties | 2683–2683; CONTENT_CANDIDATE_NOT_BALANCED |
| Raspberry cream turnovers | Raspberry cream turnovers — plant/approved-fish game adaptation | 2640–2683; CONTENT_CANDIDATE_NOT_BALANCED |
| Bilberry cordial | Bilberry cordial | 2719–2719; CONTENT_CANDIDATE_NOT_BALANCED |
| Jurkin's allfruit duff | Jurkin's allfruit duff — plant/approved-fish game adaptation | 2775–2810; CONTENT_CANDIDATE_NOT_BALANCED |
| Pale cider | Pale cider | 2834–2834; CONTENT_CANDIDATE_NOT_BALANCED |
| Rawback's stone-baked flatcakes | Rawback's stone-baked flatcakes | 2921–2928; CONTENT_CANDIDATE_NOT_BALANCED |
| Strawberry flan | Strawberry flan | 2931–2931; CONTENT_CANDIDATE_NOT_BALANCED |
| Tearose-violet cordial | Tearose-violet cordial | 2986–2986; CONTENT_CANDIDATE_NOT_BALANCED |
| Pancakes with honey | Pancakes with honey | 3075–3078; CONTENT_CANDIDATE_NOT_BALANCED |
| Motherwort tea | Rosehip-mint infusion | 3336–3336; CONTENT_CANDIDATE_NOT_BALANCED |
| Damson cream pie | Damson cream pie — plant/approved-fish game adaptation | 3433–3433; CONTENT_CANDIDATE_NOT_BALANCED |
| Skipper's shrimp-hotroot soup | Skipper-style mussel, hotroot and scallion soup | 3439–3445; CONTENT_CANDIDATE_NOT_BALANCED |
| Mushroom-gravy flan | Mushroom-gravy flan | 3495–3496; CONTENT_CANDIDATE_NOT_BALANCED |
| White cheese with celery and hazelnuts | White cheese with celery and hazelnuts — plant/approved-fish game adaptation | 3496–3496; CONTENT_CANDIDATE_NOT_BALANCED |
| Candied fruits | Candied fruits | 3511–3511; CONTENT_CANDIDATE_NOT_BALANCED |
| Honey-sweetened pale cider | Honey-sweetened pale cider | 3515–3515; CONTENT_CANDIDATE_NOT_BALANCED |
| Redcurrant cordial | Redcurrant cordial | 3552–3552; CONTENT_CANDIDATE_NOT_BALANCED |
| Roasted seabird | Coastal roast mushroom caps | 3656–3656; CONTENT_CANDIDATE_NOT_BALANCED |
| Barley wine | Barley wine | 3656–3656; CONTENT_CANDIDATE_NOT_BALANCED |
| Cornmeal-shellfish porridge | Barleymeal and mussel porridge | 3667–3667; CONTENT_CANDIDATE_NOT_BALANCED |
| Watered blackberry wine | Watered blackberry wine | 3669–3674; CONTENT_CANDIDATE_NOT_BALANCED |
| Redcurrant trifle | Redcurrant trifle — plant/approved-fish game adaptation | 3704–3714; CONTENT_CANDIDATE_NOT_BALANCED |
| Candied strawberry | Candied strawberry | 3704–3714; CONTENT_CANDIDATE_NOT_BALANCED |
| Mulled spiced ale | Mulled spiced ale | 3759–3765; CONTENT_CANDIDATE_NOT_BALANCED |
| Warm mushroom soup | Warm mushroom soup | 3759–3765; CONTENT_CANDIDATE_NOT_BALANCED |
| Water-softened stale barley bread | Water-softened stale barley bread | 3827–3827; CONTENT_CANDIDATE_NOT_BALANCED |
| Swamp frogs and lizards | Swamp-edge mushroom and cress bowl | 3869–3871; CONTENT_CANDIDATE_NOT_BALANCED |
| Warm rye bread | Warm rye bread | 3875–3875; CONTENT_CANDIDATE_NOT_BALANCED |
| Pickled onions | Pickled onions | 3911–3911; CONTENT_CANDIDATE_NOT_BALANCED |
| Warm ovenbread farl | Warm ovenbread farl | 3911–3911; CONTENT_CANDIDATE_NOT_BALANCED |
| Filboonimgun cheese | Filboonimgun cultured hazelnut wheel | 3913–3924; CONTENT_CANDIDATE_NOT_BALANCED |
| Button-mushroom herb-sauce sandwich | Button-mushroom herb-sauce sandwich | 3968–3968; CONTENT_CANDIDATE_NOT_BALANCED |
| Pennycloud-violet tea | Violet-mint infusion | 4063–4063; CONTENT_CANDIDATE_NOT_BALANCED |
| Little hot cakes (clue guess) | Little hot cakes — authored game proposal | 755–755; REFERENCE_ONLY_NOT_SERVED |
| Nursery dumpling (song reference) | Nursery dumpling — authored game proposal | 1450–1450; REFERENCE_ONLY_NOT_SERVED |
| Custard (invented anecdote) | Custard — authored game proposal | 2164–2164; REFERENCE_ONLY_NOT_SERVED |
| Requested perch or trout | Poached perch proposal | 3070–3078; REFERENCE_ONLY_NOT_SERVED |
| Giant Yo Karr pie (rejected joke) | Cavern mushroom pie | 2037–2040; REFERENCE_ONLY_NOT_SERVED |

## Handoff boundary

This package originated the proposed recipe completions, renamed substitutions, content IDs, classifications, topology diagram and EARS constraints. Character names, directly named foods/materials, narrative relationships, reported counts and source descriptions were inherited from the inspected novel. No game balance numbers, runtime catalog edits, commits or pushes were produced. Exact ingredient quantities, production yields, work duration, unlock costs, 3D measurements and route costs remain a separate implementation specification, rather than pretending the novel supplies them.

## Ordered game recipe completion

Every one of the 155 existing recipe candidates now includes `proposed_game_method`, a concrete ordered AI-authored preparation; `proposed_game_ingredient_set`, explicit game selections; and `source_status`, distinguishing references, dreams, proposals, preparations, meals, stories, care and editorial inference. Original source ingredients, locators and IDs remain intact. Generic food terms stay in source evidence while the game formula selects particular ingredients.

These operations are content candidates, not calibrated production recipes: amounts, cooking temperatures, timing, yields, work and unlocks remain unbalanced. Source preparation facts remain separate from all newly authored steps. Fictional medicinal references gain no clinical effect. Source coercion, predatory diets and unsafe/unknown botanicals remain documented while the game recipe preserves the approved alternative.

- WHEN a coding agent uses a recipe, THE content importer SHALL read its concrete game ingredient set and ordered method while preserving the source occurrence status.
- WHEN source wording gives only a dream, joke, proposal or memory, THE game library SHALL retain that modality even if an edible AI-authored counterpart exists.
- WHILE numeric production contracts are absent, THE candidate SHALL remain inactive in runtime content.
