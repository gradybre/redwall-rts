# Martin the Warrior — systematic content library

Full sequential reading: **3,995 extracted blocks; 100,604 words; 17 reviewed chunks**, including frame story and all intervening narrative. This is an all-block reading pass with source-located extraction, not a keyword sampling pass. Every chunk records all eleven requested content dimensions. JSON companion files contain 630 indexed records and 171 recipe candidates.

## Evidence and adaptation contract

- Source identity: `Redwall 06 - Martin The Warrior -- Martin The Warrior -- Redwall 06 -- a8301e3f8b1b4cbe28ed7068bc86e2aa -- Anna’s Archive.epub`; SHA-256 `ec0c10ee7b76a8a999710b83e921b6200d47773216945e0be851d16c943741c4`.
- Locators are global normalized block IDs plus EPUB member and member-local block IDs. Chunk labels are not chapter numbers.
- Named people and food variants have individual records; detailed section records preserve additional objects, ecology, beliefs, routes and contradictions.
- Ingredients supplied by the book remain in `source_ingredients`. Authored substitutions and missing bases remain in `inferred_game_ingredients`; the full proposed set is `game_ingredients`.
- Game cream/cheese use explicit oat-based alternatives. Nonwhitelisted fish/shellfish and seabirds receive named alternatives; originals remain visible. Unsafe/uncertain botanical names are not instructions for real preparation. Drinks described as ale/wine remain fictional recipe candidates, not fermentation guidance.
- Song, play-dialogue, proposal and prop foods are separately labeled. A proposed cherry soup is not reported as an actually served meal.
- No recipe is runtime active. Quantities, work, yields, nutrition and unlocks belong to later balance authoring. The user authorized ingredient inference, not silent canon changes.

## Direction that matters most

Martin's identity is measured through protection and constructive work as well as fighting. Rose's voice, Grumm's cooking and digging, Pallum's practical care, Boldred's maps and relationships, and Rowanoak's organization make survival possible. The tree-removal celebration is as important a game reference as the siege: moles remember Martin for helping their community.

Felldoh and Brome provide opposing responses to violence. Felldoh explicitly wishes he still could not kill; captivity has made hatred consume his freedom. Brome discovers that daring is not a desire to kill and becomes a healer, eventually sparing a named enemy. Juniper's funeral challenges revenge rhetoric. Victory does not cancel loss: Rose dies, Martin needs months of care and cannot return to Noonvale, and memory survives through a portrait and a living rose cutting.

The journey deliberately varies social texture: abundant open-handed hospitality; isolated formal restraint; noisy, competitive river crews; a predatory lawgiver; coercive smallfolk monarchy; territorial squirrels; artistic households; and voluntary pacifist aid. These are scenario cultures and relationships, not biological alignment tables.

## Implementation requirements in EARS form

| ID | Requirement |
|---|---|
| MW-LIB-001 | WHEN a recipe candidate is imported into a game specification, the author SHALL retain source locators and label each non-source ingredient as AI-authored. |
| MW-LIB-002 | WHEN a scenario uses named characters, the author SHALL resolve the era and SHALL NOT merge Redwall framing-era residents with Martin's eastern-coast contemporaries. |
| MW-LIB-003 | WHERE connected traversal is authored, the map SHALL distinguish accessible cliff stairs, rope/net anchors, cave entrances, tunnel branches, water passages and boat transfer points. |
| MW-LIB-004 | WHEN a source action conflicts with the project's torture or child-cruelty boundary, the scenario specification SHALL identify the adaptation explicitly before implementation. |
| MW-LIB-005 | WHEN a battle casualty occurs in story content, subsequent community scenes SHALL retain grief and relationship consequences rather than treating a feast as erasing the loss. |
| MW-LIB-006 | WHEN a belief or performance claims magic, the content record SHALL preserve whether the source reveals a stage trick, attributes a belief, or leaves truth uncertain. |

## Conceptual route topology — no invented scale

```text
NW shore caves -- forced long march --> Marshank / Eastern Coast
                                        | sea escape; party splits
                  Rosehip cliff camp <--+--> Highbeast southern cliffs
                                               |
                                         Polleekin treehouse
                                               |
                         dead three-top oak -- twin paths / bee colony
                                               |
                         Mirdop burrow -- West Marshes / Warden
                                               |
                         mountain cave -- Boldred's hidden family chamber
                                               |
                         Aggril oak -- Waterlily on Broadstream
                                               |
                         shrew logboat -- right sidestream -- Noonvale
                                               |
Noonvale -- northern tributary -- outlet rapids -- north landing -- Marshank
```

## Reading ledger and detailed category extraction

The following is the durable inspected extraction, kept in source sequence. Fine block references appear inside each section; cross-book reconciliation may add aliases without replacing this evidence.

# Chunk 1 — fully inspected blocks 1–223
## People
Bagg and Runn: otter twins; Grubb mole friend; haul beech log through winter snow (2–16). Bultip: strong travelling hedgehog, protective companion of Aubretia (8–16,49–51). Aubretia: healer mousemaid and frame narrator (10–65). Abbot Saxtus, blind herbalist Simeon and deceased Abbot Bernard (18–25). Friar Cockleburr and assistant Alder mice; Durry Quill cellar hedgehog, his uncle Gabriel/Gabe Quill (26–43); unnamed current Foremole (34,58); Dandin and Mariel away season and half (62). Badrang stoat former corsair, tyrant; mistrusts fellow stoats (66–71). Martin young mouse son of Luke the Warrior (74–111). Hisk weasel captain, initial OCR Risk (75–101). Gurrad rat and Skalrag fox aides (83). Laterose/Rose mouse daughter of chief Urran Voh, brother Brome; Grumm Trencher mole cooking/protector (124–141,195–202). Barkjon elderly squirrel father of Felldoh (145–148). Rotnose weasel guard (149–150). Windred maternal grandmother of Martin, dies enslaved (154–184). Timballisto older mouse left responsible for tribe by Luke (169). Lumpback and Stiffear weasel subordinates (209).
## Factions
Redwall household and hospitable travellers (17–65). Urran Voh's hidden Noonvale tribe, secrecy protects it from Badrang (137). Badrang's horde weasels/ferrets/foxes/rats; slaves coerced across two seasons of overland march, quarry builders (66–105,183). Luke's warrior coastal tribe and captured galley crew (154–170). Corsairs and searats not all one organization; Badrang has pirate enemies (69–71).
## Places and routes
Redwall backed by Mossflower, front west path/open flatland; red sandstone turrets, battlements, bell tower, Cavern Hole underground communal room, dormitories/cellars/visitor rooms (17–59). Marshank east coast shoreline, hills north, cliffs south, marsh west then forest; gate seaward, timber/stone quarters then perimeter, slave quarry and wooden compound (66–74,145). Badrang scuttled crippled ship NW coast, marched to eastern coast (69). Noonvale secret forest settlement, river song lyrical not exact cartography (112–123,137). Rose rocky camp south of fortress, shingle tideline and ebbing/floodtide (124–143). Luke's NW shore caves and shore northwards where Martin captured almost league away (154–183). Marshank walltop above gates and exposed execution posts (145–153,209).
## Food and ingredients
October ale (1,33,43,53), elderberry wine, strawberry cordial, fizzy dandelion cup (33–47). Honey-glazed pie unspecified filling (27); chopped nuts/greensap milk prep ingredients (28); pasties (29,52–53); hotroot-pepper soup (30–31); candied chestnut (33); nutbread and yellow sage cheese (43); snowcream pudding with damsons (46–52); hot fruit pies, colorful trifles, new golden-crusted bread, old cheeses studded with dandelion/acorn/celery, sugared plums, honeyed pears, winter salads, vegetable flans (52). Foremole turnip/potato/beetroot pie (58). Grumm wild oatcakes and vegetable soup cooked campfire, kept warm on flat rock, served scallop shell (128–139). Ingredient sets not complete recipes; cheese/cream need game plant adaptation with explicit names.
## Objects/materials
Beech log/tow rope, mittens, cloak, hawthorn stick, green habits, spectacles, carved chairs/cushions, wall torch sconces (2–59); scented fire damped snow-soaked herbs (59). Martin's inherited battle-scarred sword/crosshilt, ultimately grandfather→Luke→Martin, Badrang steals; warrior oath (105–111,154–180). Whips, spearhandle restraints, bone whistle alarm, velvet cloak stone throne then carved throne (83–104,209). Grumm small belt ladle, scallop shell bowl, sedge cleaning, Rose waist sling (129–140). Wet restraint ropes swell paws (221).
## Ecology
Snow/icicles winter; summer heat dusty quarry; east breeze storm, tide phases and shingle acoustics (17,74,124–153). Gannets/grey gulls threat to helpless mouse (148,209–223). Mussel simile not collected ingredient (139).
## Occupations/knowledge
Herbalist senses healer and movement, not reliable supernatural universal mechanic (18–25,46–51); seasonal kitchen and cellar division; winter reduced work (26–58). Quarrying/masonry/fortification slave labor (70–105); travelling healer/bodyguard pair; Grumm camp cook. Luke protection/disciplined weapon inheritance teaching (162–166).
## Customs/music/voice
Winter communal song, grace, feast and storytelling around aromatic hearth; visiting storyteller reciprocity; hospitality clean clothing/rest first (1–65). Mole dialect and otter banter; elder comic appetite and gendered courtesy preserve warmth without mandatory stereotypes. Rose song of home and reunion (112–123) do not reproduce lyrics. Martin oath to protect vulnerable and honor sword lineage (164–167).
## Theme/mood
Cosy frame contrasts slavery/open-coast exposure; quiet courage defending elder; inherited responsibility, parental absence, grief for grandmother; consent and fear under tyranny (66–223). Rose practical compassion and music amidst threat; warrior anger not sole identity. Abbot's historical knowledge incomplete, spirit presence belief (60–62).
## Movement/systems
Snow log drag, strong helper transport, coast tracking by pawprints and sword furrow; tide/weather visibility; sheer high Marshank walls block Rose/Grumm climbing despite rescue wish (199); slings and birdsong knowledge alternative rescue. Physical quarry progress and deadline/coercion compound injustice. Clothing wetness/exposure and rope constriction narrative source, not approved numeric damage.
## Uncertainty/adaptation
Frame era differs Martin past; do not merge named frame roles with past equivalents. Risk=Hisk OCR probable. Badrang's two-season travel followed by account spring/summer/autumn needs chronology kept qualitative. Cruelty/execution threat and child enslavement source-only for excluded depiction; inferred food ingredients must be separately labeled. Luke's original sword predates later reforging.


# Chunk 2 — fully inspected blocks 224–483
## People
Tramun Clogg enormously fat stoat pirate captain, braided fur, stained silks and carved wooden clogs (226–240); Boggs ferret lookout, Growch helmsbeast, Gritter crew relay (228–234); Crosstooth fox purple bandannas (303–309). Bluehide ferret experienced far north (245–251). Frogbit, Nipwort, Fleabane former shipmates now Badrang force; Fleabane confirmed weasel (347,421). Oilback searat (350). Keyla young male otter, deep singer and deceptive improviser (382–454). Hillgorse hedgehog rebellion organizer (457–477), Purslane mouse with unnamed husband/babe (461), Tullgrew female otter quarry slave (463–468), Druwp bankvole reluctant/informant accused (465–478). Felldoh kindness protects younger Brome with brave reassurance (327–343).
## Factions
Seascarab pirates want slave rowers, rival alliance with Badrang false friendship and disputed past (239,345–381). Rebel slave circle Barkjon/Keyla/Hillgorse; differing risk tolerance/coercion warning to Druwp (456–479). Badrang offers Martin captaincy across species, rejected (311–315).
## Places/routes
Seascarab green single mast, three stacked oar banks both sides, crow's nest/wheel/poopdeck, bay anchorage/four longboats ashore above tide (226–239,345); seaward approach 2 points north relative horizon not world coordinate. Marshank main gate, wooden longhut throne, bowmen surround quarters (348–380); prison pit inside courtyard left of gate, earth floor heavy grating (316–340). Escape shelter marsh behind fortress and rocky shore outcrop (300,398–420). Departing ship southerly tack (398).
## Food/ingredients
Clogg eats lobster and drinks seaweed grog (227–239); damson wine in cask (355–357), roasted fish unspecified species (382), kitchen leftovers/slave scraps (382–395), shellfish/shrimp extra rations and fruit/crops stolen from labor duties (462). Dead unspecified fish used bird bait, not a new recipe (254–268). Adapt lobster/shrimp to mussel game dishes and infer fermentation for grog; source remains intact.
## Objects/materials
Cutlass sharpened on clog sole, sash, flagon/cask/beaker, purple bandannas, bone-handled skinning dagger; poison weapons claimed by Badrang/Hisk, not demonstrated exact agent (232,304,355–376). Ladle rock-launcher (269–296), wooden wall ladders (274), heavy pit grating, stolen tools and sharp rock shards proposed weapons (464).
## Ecology
Rose imitates great eagle hunting cry, drives gulls/gannets/kittiwake; strains throat, Bluehide recognizes sound, Gurrad disputes eagle regional presence (241–259). Warm midmorning vs chilly sea night; slave fishing and cultivated fields feed horde (456).
## Occupations/knowledge
Voice mimicry, improvised ballistic ladle, prisoner supporting shoulders to reach grate (241–296,396); Keyla feigns deference/illness concern; Barkjon kitchen intelligence, sabotage slow labor, hidden food allocation (382–479).
## Customs/music/voice
Pirate mock welcome/jig and comic menace; singing used covert message and improvised illness charm (405–454). Flurgy twinj/grunge/wobbly paws in Keyla's invented song are jokes, not verified diagnoses; no lyrics copied.
## Theme/mood
Solidarity kindness and humor inside terror; repeated brave facade reassures Brome without certainty. Enemy rivalry exposes brittle authority. Druwp genuine fear of collective punishment alongside informant accusation; rebel movement has moral pressure of its own (327–343,465–477).
## Movement/systems
Two-sided stone harassment obscures direction (280–291). Eagle audio distraction, cover-limited rescue, guards' search/vision, nighttime contact via song. Longboat landing above tide and multilayer ship space; poison-threat parley. Ally secret-food network maintains escape fitness (462).
## Uncertainty/adaptation
Tramun great-uncle address is swagger not confirmed kinship; Badrang/Clogg accounts of abandoned reef/slaves conflict (366–367). Early source ship shape/sapient bird assumptions require policy review. Torture threats source only; do not instantiate. Captive food theft moral context differs routine colony theft.


# Chunk 3 — fully inspected blocks 484–740
## People
Frogbit/Nipwort confirmed rats (489). Aryan mother of Rose/Brome, wife of Urran Voh and celebrated cook (621–628). Wetpaw ferret pirate, Gruzzle searat, Dedjaw and Floater ram crew (642,691,731–739). Tailwart ferret given gate reinforcement job (693–694). Druwp now confirmed paid informer food/wine to Skalrag (574–592).
## Factions
Noonvale mixed moles/squirrels/hedgehogs/otters, Urran Voh kind but stern (621); reluctance to leave valley and follow chief is Brome's report, Rose hopes maternal persuasion (722–724). Five escaped friends collective pact to free all slaves (719–728). Competing corsair crews weaponized against each other.
## Places/routes
Exact narrative rescue reference: face middle gate, 20 paces south, pit depth three mice plus; Rose plans shaft twice her height then horizontal approach at head level, outcrop straightline marker (524–541,556–573). Not balanced metres. Noonvale deep forest glade, slopes moss/grass, cookhouse smoke through oak/sycamore/elm, seasonal flowers (619–623). Ship hidden south round headland, four longboat stealth attack (639–645). Marshank rear wall alternative exit, north corner defense, gate packed rocks/timber/sand (678–694).
## Food/ingredients
Aryan's little apple puddings (542–543); cold mint tea (566,706); Badrang roasted seabird (545); whole roast fish and dark damson wine informant bribe (581–582). Noonvale mushroom/chestnut stew; wild onion/leek soup; spring vegetable pasties; nutbread; oatfarl; wheat-cob; blackberry/apple tarts; plum maple pudding; elderberry pie served yellow summercream; gooseberry preserve scones served buttercup spread; dandelion ale, strawberry cordial, chestnut brown beer (623–629). Source ingredients named but proportions absent. Buttercup spread name does not justify toxic raw buttercup ingredient; infer safe plant spread labeled authorial. Seabird meat source-only replace with approved fish or plant version.
## Objects/materials
Sea coal on smooth rock instructions, charcoal X wall mark, canteen, digging claws and cut shaft steps (540–573); prison wall thumping guides miner (612–634). Rope/grappling hooks, muffled oars, chainmail vest, javelins, fire arrows oil/tinder/flint, copper-sheathed longboat keel with heavy prow used inverted ram/missile cover (639–694).
## Ecology
Oaks/sycamores/elms; columbines/foxgloves/bluebells/wood anemones/ground ivy/ferns, moss/dew (619). Lunar sliver, calm full tide, softly lapping waves (639). Crab dancing explanation guard sarcasm, not ecology (655). Wolf/deer comparisons not verified local species (502,636).
## Occupations/knowledge
Digging expert Grumm computes sightline, measures height by companions, clears sand from claws, works fast (556–573,631–635); cook/brew specialists (621–628); source no numeric universal dig rate. Sound-guided tunneling; informant barter; military inference of ship location.
## Customs/music/voice
Coded fever call gets message past guards with ears plugged; acknowledgement eagle calls (498–541). Grumm good-luck digging charm (564–565), do not copy verse. Winter fair drummers mentioned in simile (634). Paw-clasp solidarity pact (728).
## Theme/mood
Food-memory restores morale to desperate Brome; humor to cope with hunger; Martin's attraction causes speech stammer, friends kindly tease (619–629,707–715). Need retreat to help later contrasts Felldoh's immediate rescue impulse (719–728). Tyranny manipulation and illness superstition.
## Movement/systems
Wait guard change gap; rock-concealed spoil spreads low but thrown sand and digging knocks almost spotted (556–573,646–658). Grumm shaft steps, crawled narrow sand-shedding tunnel; temporary backfill disguises prison breach (700–705). Battle covers escape; protect retreat objective. Inverted copper boat mobile cover/ram; recoil/exhaustion limits attempts; backfilled gate resists even timber damage, enemy expedition burns logistics asset (678–740).
## Uncertainty/adaptation
Charcoal/sea coal wording preserve material uncertainty. Noonvale descriptions Brome report, not surveyed dimensions. Source 'strongest digger' praise not species multiplier. Marshank pit left-of-gate vs south mark must orient facing consistently. Fever fabricated, despite guards acting as if real. No complete ingredient list inferred canon.


# Chunk 4 — fully inspected blocks 741–976
## People
Growch rat confirmed (772), Boggs ferret (771). Rambling Rosehip Players: Ballaw De Quincewold hare actor/tragedian/harecordion player; Rowanoak ('Rowan' address) large old female badger cart puller/props mistress/principal baritoness; Trefoil and Celandine young squirrelmaid soubrettes/sopranos/acrobats; Buckler mole juvenile lead/comedian/catcher; Gauchee and Kastern mousemaid balancers/chorus/cooks (944–972). Gauchee only eats apple/carrot by her claim (967). Brome tenor/yodel performer (968–972).
## Factions
Rambling Rosehip touring theatre kind to strangers and shares quartered company garments (932–972). Slave organizers acquire arms themselves, not passively waiting for rescuers; Tullgrew stores buried cache, Keyla watches informer Druwp (811–833). Clogg/Badrang siege negotiations under mutual treachery (904–917).
## Places/routes
Seascarab wreck bay south of headland; boats holed quietly to trap pirates (742–747). Small boat tide carries east to open sea then groups washed inland by tide; Felldoh/Brome return wreck bay, Marshank beyond hills, head south toward cliff crevice with players' wagon lean-to (834–930). Other trio sees dark cliffs west using afternoon sun orientation (873–882). Circular slave palisade upright ropebound logs, locked single gate, sack mattresses and rough awning, central dirt fire (811).
## Food/ingredients
Mushroom pastie fried with spring onion gravy (945,953,964); carrot/celery broth in scallop shells (961); honey/blackberry pie (965); apple and carrot raw paired meal (967). Supper food offered before interrogation after misunderstandings. Sweet-food voice health claim Brome's comic claim not medicine (966). Prison meals generic not infer unique recipes.
## Objects/materials
Ship pitch seams and green sail burn, knives hole longboat (742–746). Driftwood and oars improvised defense; oar flotation and makeshift hole plug (761–788,834–865). Kelp strands prisoner bindings (793). Weapons cache exact narrative inventory three knives/spearhead/four slings then axehead/broken sword/dagger without handle/pikehead/whip/two arrows/slingstones/iron hook (823–828). Wagon two wheels, lean-to canvas, gold/crimson quartered tunics green border black belt; drying cloths, fan stage prop and harecordion (930,944,961–971).
## Ecology
Unnamed giant deep-sea fish predatory/playful boat and oar attacks, no species identification (834–865). Sea spray/salt/rain/cold, tides/wave crests limit visibility and split party; sunset navigation (873–882). Kelp material; crab/swansdown/rose references threats/similes not food/ecological encounter.
## Occupations/knowledge
Sabotage alternatives fire vs quiet perforation; cargo boat plug means one crew cannot paddle; guard plan compromises communications. Costume tailoring Rowanoak lets out Felldoh tunic (962). Theatre catches/balancing/rehearsal roles and shared cook/hauler labor (944–972).
## Customs/music/voice
Player company song/routine, Bobble O riddle song begins, Brome and Rowanoak duet; acrobat timing coordinated fan/catch (944). Pirate jocular salutations mask lethal bargaining (905–916). Strangers dried/fed/clothed then invited to sing.
## Theme/mood
Liberation exhilarating but immediately precarious; resourcefulness over strength, humility/relief kissing shore; ordinary performers provide home on road. Celandine attraction to Felldoh; comic mistaken fight dissolves into generous welcome (945–970). Psychological torture source excluded depiction.
## Movement/systems
Waterlogged bushy squirrel tail impairs boat boarding; allies pull limbs with oar intervention (768–775). Oar buoyancy insufficient three, swimmers rotate and tow nonswimmer Grumm; keep group but drift splits (848–856). Inverted hull becomes refuge; waves obstruct search. Gate remains shut for hostage return via lowered basket/rope (914). Concealed weapons buried under pallet; discarded weapon recovery narrative not universal economy.
## Uncertainty/adaptation
Grumm explicitly cannot swim (835); do not make all moles identical skill failure, keep profile capability. Deep sea fish no invented species. Source enslaved very young collecting weapons is excluded child-combat direction. Positions inferred using tide/sky not surveyed map. Source silver/gold color descriptions not metal ingredients.


# Chunk 5 — fully inspected blocks 977–1261
## People
Pallum hedgehog captive of Highbeasts since younger, practical dialect guide and nurse (1028–1056,1237). Amballa Queen of Highbeast pigmy shrews, address Ballamum, golden pantaloons/light-blue cloak/shell-pebble coronet/seagull feather; her only heir Dinjer infant, father killed by gannet (1050–1077,1235–1238). Squidjees child title. Skalrag corpse shows executed after torture (1147–1151). Rowanoak/Ballaw founded players, trust earned in prior travels (1182).
## Factions
Highbeast tribe rejects 'pigmy shrew' name; captive nurses/fish-gear labor, infants revered and severe parental surveillance (1043–1095). Royal line Amballa→Dinjer not hereditary rule generic allshrews. Marshank–corsair signed alliance: borrowed slaves repair vessel, half crew hostages, first catch split then exclusive sale, supplies/quarters but keep fortress location secret (1137–1145). Players willingly mobilize rescue after discussion (1172–1208).
## Places/routes
Trio lands sandy beach under high dark cliffs, wet slippery ascent narrow→broad ledge ambush, cave entry cages and deeper living area (1001–1045). Hidden stairway cut in cliff to shore and rock pools; distant isolated gannet nest ledge (1220–1261). Players move farther along shore then concealed clifftop overlook (1152–1155); remembered southern swamps with toad audience (1192–1196).
## Food/ingredients
Highbeast carried fish smelts/shannies/butterfish (1028), source not whitelist. Nutstudded shrewbread/dandelion cordial (1078–1083); wild oat porridge/oatmeal and strawberry cordial (1087–1089,1217); mixed fruit pudding with cream and new cider (1124–1125). Best parsley wine treaty toast (1137). Leek/bean soup, wheatflour pancakes with wild honey, mint/buttercup cordial (1155–1171). Buttercup cordial needs safe renamed plant substitute, not raw buttercup recipe. Gauchee apple/carrot reiterated. South toad feast unspecified, not unique dish.
## Objects/materials
Paddle carried as shared climbing support; stone-weighted closewoven kelp nets, stout wooden cages, fishing gear tied fish on driftwood poles; obblewood wooden hobble log (1009–1079). Small sword dagger-size relative Martin; spare mattresses/pillows (1096–1126). Birch-bark treaty with Badrang flowing writing and Clogg X+clog pictogram; frog mask/red clown nose, lace square, awning/cart harness (1137–1208).
## Ecology
Fish species above; high cliff gannet predation/chicks in untidy ledge nest (1235–1261). 'Wolfpack' table manners metaphor not sighting. Riddle song answer deciduous leaf (977–996). Heat/cool buried sand (1223–1225).
## Occupations/knowledge
Language learned by paired/triple run-together words; Pallum reverse psychology guides captor responses (1045–1077,1087). Childcare labor day/night and sleep depletion; fish net checks daily (1211–1220). Players masks conceal faces but Brome recognizable singing voice excluded from role; movement/acrobatic competence doubles as rescue skill (1187–1208).
## Customs/music/voice
Bobble O communal riddle answer leaf (977–996); Highbeast court formal honorific, prohibition laughing at ruler, contrary reactions; bedtime insulting lullaby humor source not game dialogue template (1055–1120). South swamp toad/caterpillar courtship pantomime, staged butterfly transformation fraud (1192–1196); theatre identity/costume social camouflage.
## Theme/mood
Warm touring community contrasts renewed captivity; farcical childcare enslavement complicates pastoral morality. Compassion crosses captor boundary: Martin rescues Dinjer despite child torment, Rose consoles Amballa (1230–1261). Celandine flirting/Felldoh embarrassment, Trefoil practical interruption; Buckler past crush. Respect children game boundary means cruel threats/lullabies must be softened explicitly.
## Movement/systems
Grumm poor climber, put middle supporting paddle; wet stone slips and fatigue rests (1009–1015). Net ambush leverages ledge advantage. Hidden stairs dramatically change accessible route. Dynamic kelp-net climbing anchor: throw/catch/tug-test/ascent/retrieve/rethrow, sword held teeth; four nets lashed ground safety catch prepared (1240–1250), not all cliffs freely climbable.
## Uncertainty/adaptation
Pallum advice stereotypes particular hostile tribe, not universal shrew AI. 'Pigmy' source spelling preserve alias pygmy for search only. Source child abuse comedy/enslavement excluded game depiction. Treaty slave commerce villain background never colony production. Do not infer literal transformation magic from player trick.


# Chunk 6 — fully inspected blocks 1262–1497
## People
Polleekin old female mole independent tree-home host, oversized mobcap/flowery pinafore, family grown/tribe gone; claims intuitive visions, admits memory may err (1415–1458). Yarrow mouse slave lookout (1315), Hoopoe very young mouse shielded by Hillgorse (1321). Ballaw alias Tibbar ('rabbit' reversed), magician disguise (1379–1383). Amballa frees four and gives small sword after Martin rescues Dinjer; Pallum tearful liberation (1288–1295).
## Factions
Highbeast bargain transforms captives into free departing friends (1289–1300). Clogg crew camps outside despite offered billeting to avoid vulnerability (1347). Badrang spies coerced too; Druwp's self-preservation bargain fails safety (1304–1346). Theatre exploited superstitious guest-protection pledged by corsair (1383–1389,1494).
## Places/routes
Polleekin home more than day's journey south of players on same clifftops, scrub woodland at cliff edge (1402). Fallen dead oak rests inclined against rock; trunk stair, room between three boughs, driftwood/cordage floor/roof chinked moss/earth/leaves, woven foliage walls, mossy branch bed, leaf-screen windows, spring/pool below (1422–1446). Route barkcloth riddle: frontshadow, dead triple-top landmark, twin paths one sweet danger, camp close/night vs watch day, three-eyed guardian, Marshwood Hill warden; interpretation later pending (1458–1466). Hawthorn departure gift (1480). Marshank courtyard performance (1486–1497).
## Food/ingredients
Roast seabird, baked fish, new bread, damson wine bribe (1304–1313). Toasted mackerel/old seaweed ale (1348–1392); rosy apple conjuring prop edible (1376); wild cherry flan (1395). Oatmeal scones honey, strawberry cordial (1404–1427). Polleekin dandelion/burdock beer, hot mint tea, carrot/turnip/pea/leek stew, cottage loaf, parsley-garnished button mushroom turnover, dark heavy fruitcake maplecream topping, wildberry tartlets (1427). Fresh button mushrooms/celery/lettuce/early green hazelnuts/dandelion/crabapples (1443–1445); mushroom/celery soup with young dandelion petals, honey-soaked prior-day scones, crabapple cider (1446); wild plum/damson cake from prior autumn stores with meadowcream (1447,1480). Roast gull, greengage cordial, pickled mackerel, kelp beer (1487). Cream variants source flavor names only, infer explicit plant bases for game.
## Objects/materials
Laced four-net safety catch, small sword, torn smock bandage (1262–1291). Whipping rods source-only; sack/grass pallets, buried weapon relocation (1304–1343). Green flame/yellow smoke, multi-color ribbon personalized name, apple sleight of hand, purple smoke/white flash (1357–1389); mechanism unspecified stage trick not magic tech recipe. Charcoal stone oven, rush basket, barkcloth/charcoal map, four provision packs (1427–1458). Comic fox costume moving tongue/eyes, frog mask, theatre scenery cart (1497).
## Ecology
Mother gannet protective chicks; Rose withholds eagle cry because nesting bird may crush rescuers, Martin chooses not to kill mother (1262–1282). Seacoal fires, warm cliff stone; small dawn birds, edible ecology listed food above. Spring potable presented without laboratory claim.
## Occupations/knowledge
Nurse becomes liberator; hide-cache counterintelligence tracks watcher, moves cache from bed to center (1340–1343). Ship salvage at low water, recover hull rebuild (1348). Stagecraft deception gains access. Polleekin provisioning/forage/storage/cooking; nonliterate host dictates to literate Rose, Grumm asks reading aloud (1457–1466).
## Customs/music/voice
Farewell song gratitude memory home, unseen host answers with cake gift (1468–1481). Mole individual assertion 'like myself' rejects Grumm assumption (1414–1416). Courteous/corsair accent Badrang changes with status (1493); Clogg pledge on stomach comic values (1387).
## Theme/mood
Compassion includes dangerous animal: spare gannet with chicks. Freedom emotionally felt in missing burden. Generosity without payment and loneliness/age/precarious future; Polleekin sees happiness and sadness, truth uncertain. Return to captivity site triggers Brome fear, costume enables courage (1495–1497).
## Movement/systems
Rescue requires net edge teams and voice command; thrown fall catch story event not universal damage cancellation. Dead oak access makes tree home possible for poor-climbing mole. No fire on risky night route; safe host hearth changes exposure, sleep and resupply. Hidden cache relocation and theatre disguise support infiltrations.
## Uncertainty/adaptation
Polleekin predictions not proven omniscient navigation UI; keep belief attribution. Three vs four travellers in her phrasing (1451) source inconsistency; group actually four. Child spanking and earlier threats explicitly excluded visual/dialogue adaptation. Gull meat not approved game harvest; mackerel approved. Full ingredients remain inferred separately.


# Chunk 7 — fully inspected blocks 1498–1771
## People
Ballaw's uncle Flobbears mentioned as source of sleight-of-paw saying, existence CHARACTER_REPORT not independently met (1765). Felldoh/Barkjon reunion affectionate old-bushtail teasing (1730–1732). Mirdop hidden threat identity unresolved yet (1693–1718).
## Factions
Players' split team infiltration uses same timing skills as art; hostile audience surprising sympathy for Celandine, Badrang lone death demand (1517–1538). Corsair alliance does not produce shared defense of prisoners (1738–1743). Slave escape organizes vulnerable first (1722–1729).
## Places/routes
Mossy hollow under dead three-topped oak confirms route landmark; twin paths left tangled/hot bee colony behind bend/dogrose, right onward, fallen elm blockage with hives, shaded high forest canopy and brook (1607–1692). Noonvale ancient northeastern forest hidden place (1628). Marshank compound rear wall escape via logs, mattress landing outside (1722–1729).
## Food/ingredients
Carrot/turnip farl; mint/lavender cordial (1616). Apple turnovers, candied hazelnuts and candied chestnuts (1635–1637). Exposed honeycomb/honey/amber nectar/wax at bee colony, not safely collected here (1656). Applescones and brook water lunch (1691). Greengage cordial/kelp beer reiterated; Mirdop soup/tail sandwiches are bluffs, NOT recipes (1705–1708).
## Objects/materials
Polished breastplate, spoons percussion, red silk dagger cushion, collapsible prop dagger swapped with matching real blade, drum, big black cloak, locked ropebound box with metal eyelets, hazel wand (1501–1601). Source explicitly explains illusions. Shrew sword path-clearing/camp reach; ladle breathing-gap cover under bees (1607–1656). Dockleaf/nightshade/mud sting poultice source fictional remedy (1684), requires non-toxic game plant adaptation. Kelp rope/palisade logs/sack mattresses rescue materials; firewood 'magic wands' improvised clubs (1726–1729,1764–1766).
## Ecology
Comet appearance (1616), ants carry bread crumb dawn (1629). Giant colony bees inhabit fallen elm/surrounding vegetation, honey/fungus; literally millions narrator hyperbole not entity count (1656). Song changes bees' behavior in fiction, physiological cause Rose hypothesis (1662–1673). Sycamore shelter, little brook, near-dark midday canopy (1681–1692).
## Occupations/knowledge
Ventriloquism Trefoil voice + Buckler moving box while hidden Felldoh departs; coordinated pyrotechnic distraction, audience locks empty box (1574–1583). Navigator identifies landmarks; tactful refusal unsafe fire; water-search separation risk (1631–1645). Sting removal with teeth/paws in narrative, not actual medical instructions. Forest echo supports intimidation and direction-finding (1693–1718).
## Customs/music/voice
Stage melodrama/chant/call-and-response magic, audience participation; no real resurrecting power. Rose Noonvale home song, every young creature can sing by her modest claim (1666–1687). Quiet farewell beliefs home security; sung code for escape and 'plan two' run (1745–1749).
## Theme/mood
Warrior identity protection not possession of sword: Rose explicitly argues Martin already warrior (1620–1622). Voice achieves victories sword cannot; tender companionship. Threatened slave escape vulnerable logistics, possessions lost with flight (1723–1725). Humor bluffs fear away, Pallum admitted fear welcomed not shamed (1644–1645).
## Movement/systems
Fire/noise avoidance on route; canopy lowers light despite day; bee hazard cannot be solved sword attack, differentiated ally skill opens passage; calming singing contextual narrative mechanic, not real bee advice. Escape first cut/remove palisade logs then lean them as ascent, controlled rope descent releases before landing to reduce bottleneck, mattresses cushion; bags too bulky abandoned (1722–1729). Badger cart charge breaks encirclement open gate (1764–1768).
## Uncertainty/adaptation
Mirdop claims omniscience/slaying and party counterclaims thousandswords are bluffs until identified. Do not catalog magic regions 'mountains of moon' stage verse as mapped place. Dock/nightshade/mud recipe is medicinal-fiction reference only; substitute explicit game poultice ingredients. Same protective attention applies children during evacuation.


# Chunk 8 — fully inspected blocks 1772–2005
## People
Hillgorse dies covering escape after arrows, Barkjon shoulder wounded, Druwp killed by Felldoh thrown spear (1772–1791). Fescue Mirdop rabbit father, wife Mildwort, twin babies Burnet/Buttercup; unnamed great grandfather built scarefigure (1826–1842). Juniper/Juno young male mouse freed slave guard (1891–1893); Floater confirmed weasel scout (1961). Unnamed red-frilled lizard leader (1886,1992). Celandine lost injured then intercepted by pirates, not intentional shirker (1900–1974).
## Factions
Half slaves escaped only; remaining forced back inside and continue captive; freed join players (1772–1807). Mirdop isolated family home protection via inherited theatrical threat (1840–1842). Lizards and two slowworms cooperate ambush (1886), lack dialogue does not prove non-sapience. Players camp duties/guard/forage rotate and care wounded (1889–1939).
## Places/routes
Narrow space compound-to-main wall holds attackers; south escape cart route (1777–1801). Mirdop burrow large clean comfortable below path, amplified ash log voice & suspended monster nearby (1809–1850). Forest edge rise overlooks West Marshes; hornbeam tree gong at Marshwood Hill per Fescue (1860–1877). Marshland mud/water/nettles/roots/gas, unknown forced distance to stakes (1977–2005). Players southern cliffs hideout reached dawn, cart trail erased (1889–1890).
## Food/ingredients
Formal mint tea honey; wafer-thin cucumber sandwiches; small oat scones raspberry preserve (1850). Candied acorns/chestnuts (1870). Mushroom soup plus apple/blackberry pudding campfire (1881–1884). Green-nettle convalescent soup other ingredients Brome explicitly doesn't know (1905–1907), do infer labeled game ingredient set. Clogg chews dandelion (1970); fresh water in gourds lizard camp (2003–2005).
## Objects/materials
Rock on kelp rope flail, spear, mattresses/carts moving wounded (1775–1807). Mirdop puppet fox body/owl talons/snake head/three eyes made straw/grass/bark/ferns/feathers/fur and creeper suspension; hollow ash log megaphone (1809–1823). Lavender soap/warm water/soft bark towels/spotless cloth formal tea (1849–1852). Gong hornbeam (1867); herb poultice unspecified, scallop bowl (1905). Fire-hardened driftwood javelins ground point on rock; shorter notched throwing board launcher (1920–1937). Vine nooses and stakes (1977–2005).
## Ecology
Slowworms look threatening but initially nonattacking, Pallum says cannot harm; later lead lizard ambush (1877–1886). Flies/midges/grasshoppers marsh margins, fern/beech/sycamore, full moon (1875–1886). Source lizard cannibal claim rabbits report, game species policy unresolved; not a source recipe. Night mist sulphurous yellow gases (1985–1986).
## Occupations/knowledge
Medic caregiver feeds weak patient; covering cart marks; proportional guard/forage after population increase, rest before workers forage (1889–1907). Spearthrower extends effective arm; narrator shows farther throw, Ballaw 'twice distance' demonstration claim not adopt numeric physics (1931–1937). Mirdop sound deception revealed, family uses fear deterrent.
## Customs/music/voice
Mirdop formal hygiene, grace thanking seasons, strict small portions/silent children; travelers humor about stingy hospitality (1849–1874). Protection through theatrical monster parallels players; contrast entirely humanlike rabbit manners vs variety among woodland communities.
## Theme/mood
Rescue success partial and costly; sacrifice and bereavement meaningful. Felldoh increasing rage, most life enslaved per father, friends win trust with skills instead direct argument (1917–1939). Rose tender care of frightened rabbit young, disputes Martin frightening them. Avoid source sarcasm toward female appearance becoming unit personality entirety.
## Movement/systems
Remove landing mattresses and time fleeing to collide enemy groups (1798–1807); wagon vulnerable-first loads and able push. Ascent rope choke point means incomplete evacuation. Reptile noose rush exposes stamina/drag/capture source. Root and wet mud trip; fire dwindling creates ambush opening. Tracking single pawprints after erased cart trail (1961–1968).
## Uncertainty/adaptation
Mirdop monster wholly fabricated; don't populate bestiary as actual creature. Lizard cannibal word not taxonomic proof victims lizards. Formal children's silence/ear punishment not approved community tone. Do not implement actual torture/captive abuse. Death Druwp ethically register source retribution, not generalized execution mechanic.


# Chunk 9 — fully inspected blocks 2006–2253
## People
Dipper unnamed species title becomes Rose-given proper name (2023–2036,2161–2162); intelligent messenger bird family nest (2235). Warden of Marshwood Hill adult male grey heron, clipped speech authoritarian territorial arbiter; kills/eats lizard leader and others (2128–2153). Wulpp wounded searat cared for by Brome/Bucktail (2094–2096,2242–2250). Crableg and Gritter searats killed, Bluddnose searat witness flees, Floater killed scout (2059–2087); Critter OCR variant Gritter at2059/2073. Grumm grandfather/grandmother in tall-tale song not independent named individuals (2211–2232).
## Factions
Lizard settlement fears heron, hides captives under vegetation; he claims law over reptiles/frogs, narrative allies call necessary evil and criticize predation (2124–2178). Corsairs lose confidence due unseen thrower, leader also flees (2087–2102). Brome independent slave rescue aspiration, disguised Bucktail, children's battle ambition source not approved player role (2115–2121).
## Places/routes
Lizard camp has ash-cleaned long cooking pit, stakes, gnarled wych-elm margin; prison food pan central reach (2007–2042,2129). Dune ambush line and hill just north/west of camp: players camp next hill south/east on clifftops (2105). Heron narrow marsh trail, crossing paths wooded islet camp, destination mountain not Noonvale which he only heard named (2143–2170).
## Food/ingredients
Warm pale mushroom porridge: taste identification tentative at2009, repeated narrative2037; ingredients beyond mushroom unknown. Hard bread/dried fish + seaweed ale (2251). Fruit flans/hazelnut scones/mint-lavender cordial marsh meal, battered but edible, Dipper shares scone (2179–2184). Lizards eating captives and heron eating reptiles/frogs are diet/predation records, not colony recipes. Milk-swigging insult2093 not confirmed drink.
## Objects/materials
Lime-trunk section wooden pan, water gourds, flint/tinder charcoal pit (2007–2042). Curved dagger transfer Crableg→Crosstooth; good sword Gritter→Floater then Brome recovers near bodies, source potential weapon continuity unclear (2073–2120). Headgear Crableg floppy hat, mixed corsair clothes/dust disguise; torn shirt bandage Wulpp (2120,2245). Damp earth fire suppression using mole claws (2150).
## Ecology
Dipper brown-red plumage/fawn breast, phonetic language mimicry; grey heron long neck/beak, twin black head feathers, territorial predation (2023–2036,2128–2142). Marsh gas/mossed branch ooze, wet narrow path; heron hunting croaking frogs at dusk (2167–2176). Night unknown constrictors bind heron limbs/neck (2236–2238).
## Occupations/knowledge
Rose approximate bird language message translated uncertain but rescue delivered (2024–2036). Lizards sustained forced feeding/readied pit confirms deadly intent. Grumm firefighting valued specialist; silent trailfollowing. Celandine actress resourcefulness sand face escape, cue phrase snaps her from shock (2046–2072). Brome field bandaging enemy doubles as cover, willingness help recognized (2242–2250).
## Customs/music/voice
Warden repeats jurisdiction and no-fire rule; mocks punished threat. Rose happiness song and Grumm dance/tall-tale singing, applause to Dipper; creature-specific dance part community life (2184–2235). 'Twelveteen' cake number explicitly comic not quantity. No lyrics reproduced.
## Theme/mood
Law as predator's appetite, morally uncomfortable rescue/reciprocity; compassion rescue may reverse soon. Enemies have gratitude Wulpp despite hostile side. Celandine competence and panic coexist; beauty/flirt behavior not full personality. Brome resentment excluded from hero work drives dangerous imitation.
## Movement/systems
Dune high ground concealed javelin throwers break larger force morale; no safe path around dune in immediate chase (2060). Clothing frills trip Celandine and endurance not assumed from species acrobat talent (2058). Marsh guide exact foot placement narrow passable trail, no offpath shortcut implied. Sound message evades lizards' comprehension. No campfire under Warden authority, cold packed meal.
## Uncertainty/adaptation
Cannibal lizard label source/report, not taxonomic cannibalism proof. Source prose suggests heron webbed feet (2129) conflicts real anatomy; concept reference keep recognizable heron anatomy. Medicine/food claims not real advice. Strong grim moral theme can inform scenario choice without player torture mechanisms.


# Chunk 10 — fully inspected blocks 2254–2478
## People
Geum old mousewife captive complaining in cramped tunnel (2330–2341); Wakk squirrel Gawtrybe chief most feathered tail, extorts sword and cheats duel opening (2450–2461). Boldred named female authority feared by Gawtrybe not yet seen (2388–2437). Stumptooth ferret relief guard (2478). Gurrad killed by Oilback mistaken for cloaked Badrang (2298–2301). Oilback drinks poisoned stolen flagon (2327), fate next. Keyla chose remain with slow elders/babies (2278), excavates cave-in himself (2470–2473).
## Factions
Gawtrybe young wild squirrels barkcloth bright sashes/tail feathers territorial clan, fear Boldred not marsh warden off domain (2416–2461). Marshank shared costume style enables outsider impersonation. Source class 'vermin' insult Martin directs squirrels (2446), moral factions not biology only.
## Places/routes
Prison pit backfilled tunnel reopened via disguised breach driftwood/earth, exit shore rocks beyond corsair camp (2329–2343). Temporary tunnel collapsed at exit. Marshes lead dry scrub then pine foothills; solitary mountain pine lower→shrub/lupin→bare dun rock peak; cave halfway tunnel through, bird vision sees beyond mice (2375–2392). Three hours after dawn reaches shale scree/fern/lupin above forest (2439–2440).
## Food/ingredients
Blackberry grog normal beverage, poisoned batch wolfbane/hemlock source poison-only not edible recipe or preparation (2280–2283). Roasted leek/pennycress/shallots, wild celery/herb soup, experimental barley scones (2364). Last stores wizened apples/wheatflour/candied nuts/raspberry scones/mint cordial (2395). Foraged apples/early wild plums/green acorns/parsley/dandelion/wild oats/honeycomb/mushrooms/watercress (2405). Grumm thick mushroom-watercress-parsley-dandelion-green-acorn soup (2406). **Grumm invention cakes explicit mixture wild plum + flour (wheat from2395) + wild oats + honey + apples, small rounds on flat rock over fire, batches for travel (2406–2415), eaten breakfast2439.** No source ratios; AI author labeled proportions only if needed.
## Objects/materials
Improvised sandbag subdues Wulpp; dark cloaks mistaken identity, poisoned flagon, driftwood spar target (2273–2301). Moss/herb warm poultice bird neck (2358–2360); flint/tinder/drygrass fire; sword used vegetable knife; flat cooking stone (2405–2411). Feather-decorated tail status and barkcloth sashes Gawtrybe; discarded pirate clothing at exit (2473).
## Ecology
Two slowworms killed, grass snake and young adder stunned then thrown swamp, source no compound monster (2345–2373). Adder bite checked absent (2359). Heron rapid recovery narrative not med timescale. Mountain thermal lifts heron; plants/seasonality listed above; honeycomb drifting rivulet not guaranteed spawn.
## Occupations/knowledge
Fake official orders exploit authority ambiguity; co-conspirators deceive each other accidentally; keep guarded pit watched then redirect sentry to shore (2289–2324). Congested tunnel dark/airless, bodies disturb weak walls; Keyla otter digs emergency though not mole (2342–2473). Foraging role allocation and return-before-sunset, food experimentation/storage recipes (2397–2415).
## Customs/music/voice
Grumm comic command/'law' echoes Warden, food serious; Gawtrybe pebbles/taunts mimic travelers, tailfeather stealing game rough social life (2416–2458). Warden farewell gratitude vows reciprocal help while territorial limits persist (2386).
## Theme/mood
Brome ambition meets consequences; comradeship helps escape panic. Martin refuses murder chaotic squirrels when not directly attacking (2417). Warden punishment absolutism rejected by narrative allies discomfort; mercy isn't effortless. Practical cooking joy sustains quest amid dread.
## Movement/systems
Patient recovery delays travel; thermal flight scouting sees cave; route only half mountain ascent then tunnel. Poison assassination fails identity discrimination. Collapsed excavation edge exits risky, crowds bottleneck; non-specialist emergency digging painful and desperate, not equal dig capability guarantee. Fire low dampwood overnight and watch shifts after harassment (2433–2439).
## Uncertainty/adaptation
Badrang poison recipe hazard not provide amounts/instructions in game library. Raw acorns require game preparation assumption disclosed; source did chop green acorns straight soup. Dead vs stunned serpents difference preserved; Warden demands kill contradicted compassionate direction. Do not import disabled/elder disrespect from panic as normal UI tone.


# Chunk 11 — fully inspected blocks 2479–2729
## People
Oilback confirmed poisoned dead (2500). Groot Purslane husband, Fuffle baby child (2674–2679). Ferndew freed cook species not specified, Burrwen hedgehog goodwife cook (2685). Wakk now Wakka spelling variant leader defeated/deposed; no two chiefs invented (2577–2607). Hoopoe leads liberation singing (2685), Juniper distinct unless source later says otherwise.
## Factions
Thirty-or-so second escape wave celebrate, support wounded Buckler, shared larder ownership open to freed families (2667–2685). Gawtrybe after chief defeated several leaders, still attacks; authority removal doesn't dissolve aggression (2605–2613). Clogg occupies empty Marshank while Badrang pursues slaves, gate locked/crew fed on walls (2567–2574).
## Places/routes
Exit tunnel→visible open shore→southern cliff ropes rescue; four ropes retained after Rowanoak first hauled one; rock anchors cliff crest and subsequent boulder fall (2517–2555). Gawtrybe mountain route tall lupins/fern→scree/rock ledges→distant cave (2592–2662). Narrative direction head-start ledge not measured map. Marshank main doors unwatched except wall before takeover.
## Food/ingredients
Herring eaten unspecified preparation and damson wine (2567–2569). Invention cakes reiterated (2597). Dried fruits/maplecream, violet crystals, candied mintleaves, honey-preserved chestnuts/beechnuts/acorns (2674–2676). Liberation song candidate references plum pudding, cider, round golden cheese, light brown nutbread, berryfruit tartlets/yellow meadowcream, pepper/hotroot soup, burdock ale (2686–2703), **song-only evidence rather than proved served**. Served hot barley-bread farl filled brown onion gravy/mashed turnip, strawberry tart and unspecified soup; blackberry cordial; basin pudding yellow meadowcream; summer salad/cheese; damson flan crisp thin pastry whiterose cream/candied mintleaves/nuts; beetroot/mushroom pastie leek gravy; honey-baked apple; summer-fruit platter (2705–2726). Trifle requested skill gap upcoming feast but not exact served recipe (2682–2683).
## Objects/materials
Vine climbing ropes anchored boulders, branch lever/cart push rocks, shoulder sling (2526–2552,2670). Shale axeheads in notched sticks Gawtrybe; foodpack shoulderstrap rescue Pallum, sword crack foothold/handhold (2613,2652–2654). Sedgebraid hat/onion conducting shoot (2685); wood spoons, basin, delicate kerchief (2709–2714).
## Ecology
Shale sliding under climbers and crumbly sandstone-like mountain surface (2652); lupins/ferns cool cover vs exposed heat (2592). Fox/owl/snake combined puppet previous not real; no new standalone fauna.
## Occupations/knowledge
Cliff rescue teams wounded/elder/young carried by strong units; javelin cover. Freed skilled cooks resume lost craft; nutpreserving late autumn household tradition recalls intimacy (2674–2685). Inventory detects scarce trifle ability; actor convoy doubles logistics. Clogg strategy exploits enemy garrison depletion.
## Customs/music/voice
Victory cart parade; shared pantry restores belonging, young first feast; permissive child eating vs Geum propriety, old songs communal conducting (2667–2709). Ballaw manipulates Celandine weight insecurity to steal food source humor avoid game bodyshaming default. Names and lovestories food-linked.
## Theme/mood
Freedom joy plus losses: source enemy count fifteen dead/about same wounded and eight former slaves lost, attributed Hisk/Fleabane not validated casualty ledger (2559–2562). Martin red mist desire to kill Wakka interrupted by Rose (2582–2586), distinguish warrior fury from exclusive badger Bloodwrath label. Felldoh isolated from joy signals trauma, not ungrateful.
## Movement/systems
Rope rescue bottlenecks, large creature hauls many; source strength exaggeration no exact capability constants. Anchor can move under deliberate force, ropes become hazards when boulders pushed, ranged retaliation still threatens top (2539–2555). Pursuit trackers ordered observe/report not engage (2564). Gawtrybe head-start bargain deceptive; assisted ascent poor climbers, strap catch falling ally, cave choke point goal (2631–2662).
## Uncertainty/adaptation
Narrative heroic child-risk endorsement not player childhood policy. Source food song separate discourse list useful recipe inspirations with explicit evidence. Wakk/Wakka alias preserve inconsistency. Root docs must not treat limited full-release inventory based on feast quantities. Childcare/physical punitive threats and violent boundary retained only as source criticism.


# Chunk 12 — fully inspected blocks 2730–2946
## People
Bugpaw/Buggy and Flink (OCR FHnk) weasel trackers die swallowed swamp (2743–2772); Fraggun rat killed (2775–2777). Findo weasel advance scout with Fleabane (2804). Boldred short-eared owl female, title Skyqueen used Gawtrybe; Hortwingle/Horty male husband; Emalet quiet owlet daughter (2843–2893). Grumm only two seasons older Rose by own childhood recollection (2890), don't assume old from dialect/role. Brome and Felldoh friendship acknowledges nonkiller courage (2793–2795).
## Factions
Owls cartographers/historians, parenting/exploration shifts, daytime hunters source claim (2882–2892). Network knows Polleekin, Mirdops, Amballa, Warden and Noonvale family; no acquaintance with Badrang (2904–2908). Captured corsairs choose coerced allegiance to Badrang over slavery/death, Crosstooth first (2941–2946).
## Places/routes
False cart trail west lowhill→furze→damp sandyflat→reedgrass/bulrush marsh; safe edges vs central quagmire (2754–2791). Mountain cave narrow two-abreast entrance; tunnel winding through with offshoots/deadends; hidden family sidechamber moonlight roof shaft (2837–2882,2910). Far slope gentler woodland/grassyglades/orchards, shallow stream; Broadstream otter boat then stream-shrew logboat relay planned (2911–2922). Polleekin visit by Boldred day after party stayed establishes communication not psychic certainty (2923). Badrang returns fortress via bidirectional slave tunnel (2932–2934).
## Food/ingredients
Plumcake, brown nut cheese, fresh wheat farl, redcurrant/roseleaf cordial carried to solitary Felldoh (2730–2738). Blossom-petal cider, carrot/parsley turnover (2798–2803). Pickled whelks and cockles, seaweed ale (2927); beetroot wine (2938). Far-slope wild plum/damson/pear/apple abundant, berryjuice unspecified (2915–2917). Owlet enjoys invention cake (2897); no assumption all bird diet colony whitelist.
## Objects/materials
Javelin blunt ends score false cart ruts, throwing board carved on site (2757–2765); sword makes lifting platform for short hedgehog (2815). Owl brushes/pens/inks/vegetable dyes/charcoal/bark parchment, moss ledge family living (2882). Purple saxifrage wreath Rose; rowan ash tree source wording (2921–2922).
## Ecology
Tracking scent claims 'badger mile' hyperbole, fresh vs old ruts/deeper gouges (2746–2767). Quickswamp disguises treacherous surface, safepath search. Gawtrybe agile highcliff pursuers; owl nocturnal pupils source prose reverses pupil/iris color terminology (2852) flag art anatomy. Short-eared owl day-active source behavior (2885). Lower mountain fruit grows differing warmer gentler aspect.
## Occupations/knowledge
Countertracking and decoy conceal refugees but lethal ambush for Felldoh revenge. Mapmaking combined history, explorers share contacts/hunts and childcare; routes passed via birds ahead arranging transport. Guest care despite imposing appearance. Badrang exploits known tunnel enemies overlooked reverse travel.
## Customs/music/voice
Pallum hedgehog identity ditty (2598 previous note), owls domestic nicknames/parental tenderness; theatrical stern 'great voice' vs friendly private manner (2843–2881). Gawtrybe Skyqueen perceived all-knowing due aerial observation; she rhetorically claims foreknowledge even surprised at chief defeat (2852–2857).
## Theme/mood
**Brome learns horror of killing; Felldoh says wishes he still couldn't kill, slavery/trauma caused burning hatred (2777–2795)** foundational warrior and grief arc, not cowardice penalty. Martin and Rose insist together rather than abandoned heroic last stand (2819–2825). Pallum doesn't remember home; Rose offers Noonvale belonging (2913–2914). Safe family cave and lovely travel interlude under uncertain ominous future (2894–2923).
## Movement/systems
Rope-less aided climbing and forefoot/sword support; choke point two enemies maximum in narrow cave but masses threaten eventual overwhelm (2839–2848), owl body fills aperture. Three-dimensional flying route knowledge, tunnel branches need guide, river transport relay offsets exhausted walkers. Decoy tracking manipulates depth/scent evidence, not perfect tracking omniscience.
## Uncertainty/adaptation
Hisk force counts now ten soldiers+two trackers despite prior 'take ten'; preserve source count variation. Brome 'never seen close killing' despite earlier dune observation resolve distance/subjectivity, not retcon. Warden eating squirrels joke hypothetical not documented meal. Punitive owl starvation threat source conflicts torture/child boundaries; adapt deterrence without cruel confinement. Source grass snake/adder fate not established death.


# Chunk 13 — fully inspected blocks 2947–3178
## People
Starwort male otter Waterlily captain tattooed paws; wife Marigold serves bowls, Stewer fat otter cook (3041–3074). Aggril ancient grey hedgehog cordial maker/hollow-oak resident, square glasses/blackthorn staff, false claim owns communal cherries, secretly drugs travelers according Starwort (3010–3049). Juniper killed, Yarrow paw wounded, Brome healer (3156–3178). Hisk and four returning soldiers killed by own leader in mistaken night archery (3152–3175). Wulpp survives and assigned oversight of Clogg burial labor (3175).
## Factions
**Fur and Freedom Fighters** new rebel army named2950, green flag flying javelin cuts chain sewn Rowanoak; mixed liberated people/players, debate safety vs prevention of future slavery (2950–3002). Brome explicitly nonkiller chooses healer honored as brave (2991–2992). Broadstream shrews decentralized no single leader, short rapiers/baggy pantaloons, trade cakes for relay voyage (3087–3117). Waterlily family crew two dozen otters including children (3053–3077).
## Places/routes
Aggril standing dead hollow oak cool room base small door, cordial casks walls (3030–3038). Broadstream broad/deepbank tree shade and inlets; Waterlily square sail flat-bottom stable, masthead owl perch/forecastle children/afterdeck brazier/midships rails (3044–3081). Six shrew logboats downstream then right narrow sidestream under knotty willows, Rose childhood recognizes route Noonvale tomorrowafternoon (3115–3118). Marshank pit filled by Clogg ends tunnel access (2949,3122). Juniper grave near cliff edge sea view sunlight/wind (3176–3178).
## Food/ingredients
Leek/cabbage soup, summer salad, honeyed scones, strawberry cordial (2984). Cherries fresh, cherry soup **proposed experiment only** Grumm3006. Aggril cherry cordial variants: dark honey-lined-cask score-of-seasons-old; brighter-red fizzy ancestral recipe (3031–3038), pure white cheese/celery wafers; sedating cordial source contaminants unnamed not recipe. Waterlily **watershrimp/bulrush/hotroot soup** explicit3068, barleybread, scupperjuice ingredients unnamed; game mussel/bulrush/hotroot adaptation and inferred fruit/leaf cooling drink. Fish/water roastfowl speculative Clogg3134 not served variant.
## Objects/materials
Green severed-chain banner costume scraps, military costume Ballaw; vine sling leather-like tongue middle, tentpoles become pointed pikes, rosewater cosmetic (2952–2977). Honey spoon/toddler apron mockquartermaster (2980). Cherrywood carved bowls, honey casklining, cordial gourds/kegs/flasks labels; hammock carries sedated travellers to ship (3030–3049). Triangle mealtime signal, charcoal brazier/bowls/ladles, shrew poles/loghulls careen moss (3063–3094).
## Ecology
Dark-red cherry trees communal, daisies, bird morning songs, roach/tench/perch/pike follow ship scraps; kingfisher hovers inlet for fry (3005–3038,3053,3081). Only perch whitelist among observed fish, pike hazard, others observation not harvested dish. Willow landmarks sidechannel.
## Occupations/knowledge
Weapons/drill roles Felldoh javelin, Keyla sling, Barkjon slingmaker, Buckler pikes despite wounded shoulder, cooks remain vital (2962–2994). Otters teach reef/tack/scull/row/steer; stable boat acclimates afraid passengers (3076–3077). Mapmaker revises streams; shrews careen hulls. Funeral/healer social care.
## Customs/music/voice
Actor good-luck 'break a leg' explained not literal injury wish (2999–3001); food-based naval bargaining and rapiers social emphasis. Otter work song synchronizes sail hoist, family meal, nautical slang adoption. Short funeral flowers/grave community gather (3178). No lyrics copied.
## Theme/mood
Warmest travel/cordial scene undercut by Aggril malicious hidden sedation; Boldred 'harmless' earlier wrong/incomplete, record contradiction not safe elder service. War jubilation turns grief after Juniper loss (3168–3177); friends don't uniformly experience victory. Institutional choices roles not all fighters; liberation alone may leave future victims at risk (2993–2995).
## Movement/systems
River relay mobility and stable vs narrow fast vessel comfort; cargo/logboat competition rocks passengers. Raiding staggered teams change sides after volley, prone concealment, suppressive fire can pin even successful raiders; friendly fire from mud/night identification; casualty retrieval. Burning wood walls/javelins suppressed earth/sand not only water (3126–3166).
## Uncertainty/adaptation
Scupperjuice game ingredients authored not source; cherry-cordial drugging no recipe doses. Grumm spicy tolerance exceeds otters, individual variation over species lock (3071–3074). Forty/24crew not balanced unit counts. Broadstream shrews not assumed later GUOSIM unified charter. Source coerced Clogg labor and violent toddler jokes outside game everyday tone.


# Chunk 14 — fully inspected blocks 3179–3410
## People
Bungo tiny mole nephew of Grumm (3220–3221,3379–3383). Teaslepaw hedgehog maid family chestnut-ale brewers, Pallum attracted/flustered misnames Peasletaw/Pawseltea comic aliases not people (3222–3225). Auntie Poppy wafer baker species unspecified (3394). Gumbler mole digger (3391,3406). Aryah source also Aryan OCR/editor spelling (3203–3204 etc). Urran Voh greybearded but not old green robe cream cord (3203); Aryah lilac embroidered leaves gown. Malcolm the Magnificent Diving Mole = Buckler stage persona (3302–3321), not extra character. Lumpback killed by Felldoh (3274).
## Factions
Noonvale peaceful voluntary aid recruits permitted after Aryah mediates; no weapons inside domestic haven but personal blade hung not surrendered (3242–3251). Fur/Freedom disagreement Brome confronts revenge oath, Kastern warrior assumption challenged (3179–3190). Noonvale household shared daily work all species, chosen community places (3385–3388).
## Places/routes
Noonvale conical timeworn monolith overlook; huge descending valley thatch roofs, flower gardens/orchards no marked fences, waterfall stream/pool, Council Lodge big thatched hall four-square tables smoke-dark rafters; Voh cottage chair/embroidery/windowseat/guest rooms (3193–3253). Backwater Broadstream tributary final approach foot forest (3193). Orchard borders raspberries/blackcurrant/bilberry/redcurrant→vegetable garden; dead sycamore at far end; waterfall planned stump seats (3402–3410).
## Food/ingredients
Homecoming strawberry cordial, dandelion/burdock cup, mint/lavender water, chestnut ale, blackcurrant wine, cider; nonspecific salads/cheeses/breads/pasties/trifles/flans/puddings/pies/tartlets honey/cream (3219). Cherrycake candied nuts glaze (3220); leek/chestnut pastie thyme/radish sauce (3222); damson/hazelnut flan mintcream (3226–3228); wild plum/apple pudding (3232). Custard pie real stage prop (3306–3320); cream pudding play dialogue only3351 (not actually hidden in drum). Breakfast honey pancakes with pear slices/raspberries, fruit salad, barleybread, maple/buttercup wafer Poppy, maplescone Teaslepaw, leek/mushroom soup, nutbread, special Grumm rose/onion/daisy/carrot/plum/turnip soup (3385–3401). Flower food safe game ingredients reviewed/rename buttercup without asserting raw plant safety.
## Objects/materials
Juniper sling/stones laid with flowers grave, Brome healing kit (3180–3190). Blossom bathing water and clean faded-purple tunic (3212). Floral garlands urn decorations, reed flutes/drums slipjig (3219–3236). Black moustache/costume/cloth/tambourine/custardpie/lantern/tasseled nightcap/drum with cut skin pantomime (3301–3352). Mole axe, six excavation holes, taproot, forked rowan timber assigned lodge ridgepole (3404–3410).
## Ecology
Noonvale fish perch/trout visible waterfall pool (3368), orchard listed plum/greengage/damson/pear/apple/cherry and berries (3402). Beech bowl wood; dead sycamore still anchored taproot. Habitat felt sanctuary due maintenance not wild abundance alone (3368).
## Occupations/knowledge
Tree removal digging/chopping, reallocating building timber for leverage pending; roles vary from warrior to civic labor (3403–3410). Herbal dressing Yarrow prior3176, care and grief persist; entertainment collective grief respite not erased memory (3292–3300). Kin training cooking Bungo supervised and comic contested method (3379–3401).
## Customs/music/voice
Homecoming toast peace/season blessing then music dance; private family council after public meal. Breakfast familiar lap/friend/elder seating, hygiene/clothes, grace (3388). Memorial honor vs vengeance condemned Brome (3179–3188). Periwinkle Parade comedic fictional stage event, do not schedule as proven actual festival; pie slapstick and faux mishearing.
## Theme/mood
**Peace and warrior duty both stubborn valid paths Aryah mediation (3374–3378)**; Rose hopes change Martin, parental fears foretell grief not verified fate. Domestic beauty shows what violence protects/jeopardizes; Martin anxious without weapon and unfamiliar bed. Felldoh isolated plotting while others laugh, ominous last farewells. War grief cannot be resolved mandatory revenge.
## Movement/systems
Last route lighten packs for faster familiar approach; thermal aerial scout to reunification. In village hauling/levering available civic task not only combat roles. Weapon-free zone supports compromise retain ownership with storage action. Auditory target location risky wall-javelin raid (3273–3285), hidden ammo caches allow one raider mistaken many.
## Uncertainty/adaptation
Kastern claims all warriors like Felldoh is her opinion contradicted themes; 'death walks beside warrior' Urran warning belief. Food metaphor 'rock swallowing party' not recipe. Source family kin 'Auntie' may honorific not infer lineage. Source deprivation/torture threats and cruel child jokes do not enter default game tone.


# Chunk 15 — fully inspected blocks 3411–3636
## People
Tramun's full self-title **Tramun Josiah Cuttlefish Clogg** (3466). Felldoh dies after beating Badrang and surrounded ambush, father and Brome mourn (3556–3568). Marigold tail-drums recruitment signals (3634). No additional named persons.
## Factions
Noonvale volunteers sixteen including Martin's three friends count phrasing, moles/hedgehogs/otter quartet, others families/pacifism valid reasons decline (3538–3541). Boldred recruiting broader alliance via prior network, Starwort otters/shrew flotilla plus raft otter/hedgehog allies (3542–3551,3617–3636). Fur/Freedom besieged shore fighter/healer roles share crisis (3562–3602).
## Places/routes
Short route Noonvale north two-hour walk wide Broadstream tributary→Starwort boat, earlier quest long detour far south coast and Marshank further north east-facing (3548–3551). Tree fall picnic around trunk at Noonvale, stump rootplate near Lodge height (3438). Shore cart cover front fort/flanks50each/back sea; trenches above tideline behind dunes/outcrops (3460–3465,3575–3593). Barge and raft rickety central shed flotilla (3617,3636).
## Food/ingredients
Deeper 'n' Ever turnip/potato/beetroot pies traditional tall patterned glossy crusts, ten narrative pies, strawberry cordial and waterfall-cooled cider (3439–3449). Siege scarce water mouthful+scone ration (3590) not fullbalanced units. Fish/roastfowl/wine Clogg assumes master dining (3124 context). No new recipe from 'fishbait' threat.
## Objects/materials
Forked rowan lever under roots fulcrum built earth/stones, ropes additional crowd force, axe-cut taproot, flexible beam then retained lodge use (3414–3437). Thrower strapped back/javelin bundles, slittrenches and spade/barrow (3454–3466). Flanking sandhillocks, cart side shield arrows penetrate; reclaimed enemy arrows, improvised springywood/cord bows by Kastern/Groot (3577–3601). Comfrey poultice and clean linen on Ballaw paw source-fiction medicine (3585–3587), dockleaf Badrang shoulder (3581). Quartermaster bag herbs/bandages, tail percussion drum on coil (3564,3634).
## Ecology
Heat/little wind siege dehydration, calm sea denies helpful cover (3589). Leverage uproot old sycamore living community material cycle; river current navigation speed physical constraint (3625). Otter fish/sports slings source3618; does not identify catch species.
## Occupations/knowledge
Engineering cooperation Martin+Urran solves tree extraction with weighted lever, everyday victory reconciles paths. Healer distinguishes dead vs treatliving compassion (3564–3566). Mapmaker logistics and recruitment bridges isolated settlements, prospective contingencies vs regret (3544–3551,3625–3630). Kastern craft reuses projectiles.
## Customs/music/voice
Mole pie song during civic celebration, cheering dance picnic after labor; recipe tied species culture not locked eligibility (3438–3449). Silent forest afterlife metaphor Barkjon for Felldoh (3565). Theater coping humor consciously chosen to face fear (3598–3602). Drum signals summon river allies; goodseasons blessing farewell.
## Theme/mood
Felldoh vengeance blindness/overconfidence versus Badrang manipulated pride; mercy boundaries tragic. Brome still loves friend while rejects killing; grief appropriate explicitly taught by Barkjon (3566). Martin guilt counterfactual challenged: focus plans, community preparation enabled army (3626–3630). Pacifist refusal respected, volunteer support endorsed.
## Movement/systems
Exact source mechanical chains: weakened taproot+fork lever+fulcrum+crowd/rope load→uproot. **Do not use physically dangerous jumping crowds as real engineering instructions.** Battle lure visibility/cue 'Marshank', slittrenches conceal flanks; elevated defender dodges known incoming throws (3470–3497). Cart overturned cover and sandwork, alternating javelin/sling volleys catch retaliation; burning arrows escalation (3613). River flotilla tow barge, broadflat raft/poles, tail-drum coordination.
## Uncertainty/adaptation
Counts 'thirty times' Kastern rhetorical versus actual fort force and volunteer counts don't reconcile to runtime. Source child Bungo helps community/logplay not combat; Grumm redirects him stayinghome3535. Felldoh beating captive enemy source torture boundary explicit. Comfrey/dockleaf source medicinal references no actual dosage or treatment validation.


# Chunk 16 — fully inspected blocks 3637–3849
## People
Gulba large female hedgehog raft fighter, colored headspike tassels/crystal-studded club; husband Trung small fat hedgehog, splitthong two stones weapon, gives Martin cloak (3637–3647,3806–3808,3839). Clogg head injury causes confused grave obsession per Crosstooth (3791–3832). Wulpp spared by Brome, directed flee south (3752–3754). No invented propernames for unnamed battlefield casualties.
## Factions
Regional army includes Highbeast Amballa, Gawtrybe with Warden, otters/shrews/hedgehogs/mice/squirrels/moles; new **Council of Chieftains** led deliberation Rowanoak/Boldred advise Martin (3728–3798). Families protected back camp Geum/Purslane while fighters away (3684). Army desire peacepreventslavery vs alliance opportunisticgame Gawtrybe; not merged ideology automatically.
## Places/routes
Broadstream outlet rapids joins main river, fleets run drop, rocky hazards and downstream clearance (3649–3668). Landing hill north of Marshank, fortress northwall visible left at hill (3724–3729). Hillock outside missile range birds wait; assault walls north hedgehogs/shrews net, south squirrels/otters, rear mole tunnel, front firecart (3796–3812,3845–3847). Felldoh grave wherefell source observed enemies3818, distinct Juniper cliffgrave.
## Food/ingredients
Watershrimp pastie Trung (3641) game mussel substitute labeled. Siege half-scone/water, smoked herrings/dandelion water Badrang (3677–3694); kelpbeer supper wish3823. Stocks diminish healer materials too3708; no numeric economy from narrative quotas.
## Objects/materials
Crystal-studded warclub, twin-stone split thong, tattoo/regalia, central raft shack partlybreaks rapids (3638–3659). Salvaged burning arrows reused, one reserved javelin each, nearlyburnedcart repaired temporary (3675–3676). Big square kelp net repurposed enemy entanglement for wall ascent aerial carry; boulders/fishnets/fire wall defense and wounded ammo carriers (3760–3764,3796–3804). Cartgrass/driftwood/brush, fiftyarchers cover narrativecount3847.
## Ecology
Swifts over river (3670), water spray rainbow, variablecurrents/rapids. Night/darkness decreases airborne missile exposure birds wait3768; doesn't grant invisibility. Bright sun/heat dehydration vs shaded protected defender logistics3694.
## Occupations/knowledge
Taildrum river network, navigation skill despite firsttimerapids not guaranteedsafety. War council corrects furious unplanned masscharge: commander needs cool advisers (3774–3781). Wounded noncombat supply runners source, game triage capabilities require spec. Patient materialdepletion; repair cart finalrun craft assessment.
## Customs/music/voice
Battlecries regional identity distinct 'Fur/Freedom','Broadstream',Amballa,Martin (3755–3759) paraphrase notlyrics. Laststand farewell preserves personality with theater analogy (3681,3715–3719). Memorial burial includes originalescapecompanions/actors (3813–3815). Peace and war share sky Rose3834; Grumm ladlecomfort.
## Theme/mood
**Hero remembered by moles for tree work, not battle** (3836–3838) key communityidentity. **Brome explicitly spares named enemy Wulpp** despite tryingforcewarrior identity; mercy closes healerarc (3752–3754). Rescue army strength alone fails fortress, voluntary collective wisdom replaces rage. Clogg trauma treated source tragicconfusion not comedygame debuff default.
## Movement/systems
Rivercraft congestion collisions/wreck shed/rescue/righting after rapids; bank runners keep fleetpace (3648–3664). No mass swimming escape when boxed at tideline, capacities situation-specific. Fort net crowdentanglement, ropes/grapnelscut and highground. Fourlinked approaches coordinated timedpredawn; rear tunnel addsalternativebreach. Repairburnedcart judged shortdistance only, specific assetstate.
## Uncertainty/adaptation
Army hundreds no precisevalidatedcensus; fiftyarchers sourcecount not forceunitcap. Short-earedowls battle daytime available but darknessneeded for survival missilefire. Hero force includes cruel Gawtrybe allies, uneasy coalition not goodnessbynature. Named foodhorspecies adaptation separate. All combat deaths preserve emotionalconsequences no score-only framing.


# Chunk 17 — fully inspected blocks 3850–3995
## People
Rotnose killed wall arrow3865; Crosstooth Amballa kills after Martin intervention3897–3901; Badrang slain with Luke sword3913; Rose dies thrown head against wall3905, recoveredhome body3923; Grumm facial wound temporarily loses voice in grief3921–3922; Pallum scarred back392?3952. Clogg survives hidden grave despite narrator initially 'not one foebeast alive'3925, final gravekeeper madness3938–3946. Boggs/Stumptooth dead bodies named3943–3944. Brome title The Healer ancestor of Aubretia, ruling Noonvale line; Pallum the Peaceful ancestor Bultip (3981). Emalet later gave portrait to Brome family (3986); Boldred artist mother. Laterose full title daughter Urran Voh/Aryah3989.
## Factions
Allied force victories achieved timedrolecooperation, postwar homes: Broadstream riverfolk return, Warden guides Gawtrybe mountain, Amballa clan south coast; homeless offered Noonvale if leave weapons (3928–3936). Players migrate Noonvale Ballawlead, Rowanoak joins after nursing Martin. Redwall later interprets Martin peace/orderfounder, Rose beauty legacy (3980–3994).
## Places/routes
Fort front gates burn collapse inward; south wall ladders to courtyard; northwall Badrang longhouse rearwindow; rear compound→fresh tunnel exit potential escape (3866–3906). Marshank ruins deliberately left warning, bodies seabirds except Clogg burials (3925–3946). Martin recovery at Polleekin treehome south, not Noonvale; remainder summer→autumn solitary south departure (3949–3976). Rose grave Noonvale, redrosecutting destined Abbeygrounds spring (3988–3989). Frame Cavern Hole stairs→rooms (3993).
## Food/ingredients
Convalescent breakfast oatmeal/honey, nutbread/strawberry preserve, mint/dandelion tea (3958). Source says good food but Martin eats without enjoyment, grief not instant morale cure. Travelfoodpacks unnamed3970; no new ingredient inferred from animal simile.
## Objects/materials
Three-rank archery rotation, firecart loses attendants to heat, net hangs threebattlements anchor tested, rope ladders sticks crosspieces, soil tunnel (3853–3874). Grumm ladle smashed head impact3905; Badrang swordtaken original Luke recovered, shrew sword laterlaid withRosebier (3911–3914,3934–3936). White linen shroud, stretcher wounded secured, herb dressings, largekerchief grief (3919–3932). **Scallopshell locket on thong, polishedcherrywood miniatureportrait Martin/Rose in plant/vegetabledyes painted Boldred, inherited viaEmalet** (3984–3986). Living memorialrosecutting wetloambag3988.
## Ecology
Burntfort opens insects/birds/seasons, gullscavenging bodies, autumn leafgold/brown frost/dew/flowersdie (3937–3970). **Laterose redrose cultivar sometimes lateblooming, Grumm planted original Rosegrave, cutting viable to Abbey** (3988–3989), separate human-name/plant records.
## Occupations/knowledge
Moleteam wide deep rear tunnel; squirrels establishwall foothold coverrope-ladder installers; flyingbirdnet carry; coordinated frontarcher distraction (3866–3874). Wounded nursing months not instanthealing; community deathcare preserves name/body/portrait/cultivar. Artist mapmaker recordvisual history; herbalist plansspringplant.
## Customs/music/voice
Victorydrum stops forgrief3918; burial sword tribute Amballa remembersRoseallseasons; silentforestafterlife prior sourcebelief. Martin silenceprivatecry/nevermentionsRose, protects Noonvale by vow altered backstory (3950–3968). Frame night+day oralstory sharedtears then gift and hospitality seasonalstay (3979–3994). No lyricscopied.
## Theme/mood
**War victory bitter price; Brome selfblame corrected responsibility Badrang (3919–3924).** Martin posttraumaticmute/grief and failurepromise cannotbe healed byfood/hero status. Recovery speechchosen departure, hopes eventualpeace. Finalwordmartin toRose about treecutting3914 ties weapon back constructive life. Communitymemory living rose and handmadeportrait provide intergenerationalcontinuity; originsecrecy explains later omission not authoronlyplot inconsistency.
## Movement/systems
Aerial net invasion timing dark, stronganchor/limitedwidth. Archeryreloadrank sequencing. Gates collapse hotdust hazards, otterspikesclosequarter agility, badger leap after gatesopen explicitlyshedeclinednet (3882–3896). Exit tunnel must block retreat Pallum defensivecurl getsinjured; no invulnerability. Alliedactions can openenemyescape route. Stretchertransport, longrecovery, commemorativeplantcultivation assetchain.
## Uncertainty/adaptation
'Not one foebeast' immediate impression contradicted Clogg survivor and sparedWulppoffsite; neverassert totalannihilation. Rose mortal blow non-graphic gameboundary seriousgrief fits but no childcruelty. Martin rewrites ownpastdeliberately3968, preserve source and later contradictorydialogue both. Portrait facefromsamepasttime impliesartistknew, not exactdate specified. Fullcoverage blocks1–3995 actualread; Eulalia absent unrelated.
