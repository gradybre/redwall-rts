# Redwall RTS — Game Concept Brief

## The Pitch
A three-layer strategy game where you build a thriving woodland settlement,
expand across Mossflower, and fight Total War-scale tactical battles to defend
it. The cozy and the brutal feed each other: the feast you cook in autumn is
the morale buff that holds your line in winter.

**Closest comparison:** Manor Lords (deep settlement sim + tactical battles),
with Total War's campaign structure and Redwall's tone and creatures.

## The Three Layers

### Layer 1 — The Settlement (Cozy Colony Builder)
Your abbey/holt/mountain is home. This is where most playtime happens.

- Build rooms and structures, assign creatures to jobs
- Deep production chains: raw → refined → prepared goods
- Creatures have needs, skills, relationships, and routines
- Seasons drive everything: forage in summer, harvest in autumn, survive winter
- Feasts are a real mechanic — cook elaborate meals for faction-wide buffs
- The settlement produces the units, food, and equipment your armies need

### Layer 2 — The Campaign Map (Strategic)
Zoomed-out Mossflower. Turn-based or slow real-time (TBD).

- Territory control across regions
- Roaming armies (yours and vermin warbands)
- Encounters: landmarks, random events, quests, wandering heroes
- Riddles and prophecies unlock quest lines
- Diplomacy with neighboring settlements (otter holts, shrew tribes, Salamandastron)
- Armies carry food from your settlement — supply lines matter

### Layer 3 — Tactical Battles (Total War-scale)
When armies meet, drop into a real-time tactical battle.

- Squad-based units with 10-60 models depending on species size
- Formations, flanking, terrain advantage, morale/rout mechanics
- Legendary lords and heroes fight as powerful individual units
- Colossi as boss encounters (owls, eagles, pike, swans) — phased fights
- Siege battles at settlements using the walls you actually built

## Confirmed Decisions

| Decision | Choice |
|----------|--------|
| **Camera** | 3/4 perspective, WASD pan, Q/E rotate (standard RTS) |
| **Settlement scale** | Large — 80-200+ creatures |
| **Named characters** | Heroes, lords, and villains named; general population anonymous |
| **Unit structure** | Squad-based, with individual units where it matters (heroes, colossi) |
| **Multiplayer** | Single-player only for now |
| **Art style** | Detailed 3D units and buildings — Age of Empires / Total War fidelity |
| **Dev platform** | Built on Mac (M-series) |
| **Target platform** | Windows/PC primary |
| **Engine** | Godot 4.x, GDScript |
| **Assets** | Blender |

## Unit Sizing Tiers
Model count per squad scales inversely with creature size:

| Tier | Models/Squad | Species |
|------|-------------|---------|
| **Small** | 40-60 | Shrews, mice, moles, voles, rats, squirrels, bats, sparrows |
| **Medium** | 30-40 | Otters, hares, ferrets, weasels, hedgehogs, lizards, kestrels |
| **Large** | 10-15 | Badgers, foxes, wildcats, monitors, wolverines |
| **Giant** | 1 (single entity) | Falcons, snakes, eels, water rats, shrikes |

## Battle Mechanics

### Mixed-Weapon Units
Squads can contain multiple weapon types (or species) on a model-by-model
basis — a skirmish unit with slings and javelins, or elite infantry with
lances and great weapons. Enables varied stances and formations, and
reflects the looser, organic feel of battles in the source material.

### Specialists (Attached to Units)
Individual characters attached to a squad before battle to provide buffs:
- **Medic** — regenerates health
- **Piper/Drummer** — boosts morale
- **Field Cook** — extends stamina, applies food buffs
- **Sapper (mole)** — builds underground walls, collapses tunnels
- **Banner Bearer** — leadership aura

Specialists can be scattered among units or bundled onto a hero to form a
powerful party.

### Terrain-Based Mobility
Species-specific traversal opens tactical options:
- **Otters** — swim, river crossings
- **Squirrels** — climb trees, elevated firing positions
- **Moles** — burrow, undermine walls, block tunnels
- **Birds** — fly, scout, harass

### Colossi
Massive single entities encountered through quests. Apex predators: owls,
eagles, seals, pike, swans. Phased battles requiring tactical adaptation
(hurl rocks at spearbeasts, bait attacks, target weak points). Some can be
befriended and fight alongside you.

## Resource Systems (Deep & Dedicated)

### Fishing
- River, lake, and coastal fishing spots with species variety
- Seasonal availability (salmon runs, ice fishing)
- Gear progression: hand nets → traps → boats
- Risk: pike and eels can attack fisherbeasts

### Hunting & Foraging
- Track and hunt game in the woods
- Forage berries, nuts, mushrooms, herbs by season
- Deeper woods = better yield, higher danger
- Sustainable vs. over-harvest mechanics

### Farming
- Crop plots with soil quality, rotation, and seasonal planting windows
- Orchards (multi-year investment, big payoff)
- Beekeeping for honey and mead
- Weather events: drought, blight, early frost

### Cooking
- Recipe system: ingredients combine into dishes
- Each ingredient contributes a buff; dishes stack them
- Quality tiers based on cook skill and ingredient freshness
- **Feasts**: elaborate multi-dish events granting faction-wide bonuses
- Field rations vs. abbey meals — armies eat what you pack

## Species Roster

### Woodlander Factions
- **Mice** — Balanced, leaders, scribes, staffbeasts and swordbeasts
- **Moles** — Diggers, builders, sappers; slow but immensely strong
- **Hares** — Fast, elite fighters, high food consumption (Long Patrol)
- **Otters** — Swimmers, javelineers, aggressive shock troops
- **Squirrels** — Archers, scouts, climbers
- **Hedgehogs** — Crafters, brewers, mallet and hand-axe warriors
- **Badgers** — Rare, devastating, berserker rage mechanic
- **Shrews** — Numerous, quarrelsome, boat handlers

### Vermin Factions
- **Rats** — Numerous common infantry, mobs and guards
- **Weasels/Stoats** — Fast flankers, archers, poison specialists
- **Ferrets** — Siege specialists, lurkers, cutthroats
- **Foxes** — Commanders, rangers, poison knives
- **Wildcats** — Boss-tier lords and tyrants

## Faction Structure
Each faction has:
- **Legendary Lords** — Unique named characters with narrative objectives
- **Lords** — Generic high-tier commanders
- **Heroes** — Named support characters
- **Melee Infantry** / **Ranged Infantry** / **Mobility & Mixed Units**
- **Specialists** — Attachable to squads

## Campaign Structure
- Legendary lords each have narrative objectives (build a fortress, defeat a
  warlord) with enough flexibility that no two playthroughs are identical
- Roaming armies trigger encounters at landmarks
- Riddles and prophecies unlock quest chains and unique rewards
- RPG emphasis over pure conquest — adventure, character growth, immersion

## Design References
| Game | What to take from it |
|------|---------------------|
| **Manor Lords** | The exact hybrid: settlement depth + tactical battles, solo-dev proof |
| **Total War: Warhammer** | Campaign map, faction rosters, legendary lords, monstrous units |
| **Heroes of Might & Magic** | Encounters, landmarks, roaming army exploration |
| **Rimworld / Dwarf Fortress** | Creature autonomy, needs, emergent stories |
| **Age of Empires** | Camera feel, 3D unit fidelity, RTS readability |
| **Evil Genius 2** | Room-based interior building, minion job assignment |
| **Banished / Farthest Frontier** | Seasonal survival, food chain depth |
| **Redwall novels** | Tone, feast culture, creature personalities, walltop defense |

## Open Questions

### Combat Style (Still Undecided)
Given the Total War scale, the realistic options are:
- **Real-time with pause** — Total War battles. Issue orders, pause to reassess. Best fit for the scale you're describing.
- **Real-time without pause** — More frantic, AoE-style. Harder with 40-60 model squads.
- **Turn-based tactical** — Songs of Conquest style. Much easier to implement, very different feel.

**Recommendation:** Real-time with pause. Matches Total War references and gives you room to handle large squad counts without demanding twitch reflexes.

### Campaign Map Timing
- **Turn-based** (Total War, HoMM) — easier to build, natural pacing for settlement management
- **Slow real-time with pause** (Crusader Kings, Manor Lords) — more immersive, harder to balance with settlement sim

### Other Unresolved
- Interior room management depth? (Prison Architect-style interiors, or exterior building only?)
- How does the game end? Campaign victory conditions, endless sandbox, or both?
- Day/night cycle in addition to seasons?
- Do settlements persist between battles, or is there a separate battle map?
- Tech tree vs. organic discovery through quests and encounters?

## Technical Constraints & Concerns

### Performance Reality Check
Total War-scale battles are the hardest part of this project. At 40-60 models
per squad and 10+ squads per side, you're looking at 400-1200+ animated
characters on screen. This demands:
- GPU instancing (`MultiMeshInstance3D`) for crowd rendering
- Aggressive LOD (distant units drop to low-poly or billboards)
- Animation batching — no per-unit `AnimationPlayer` at that scale
- Flow-field pathfinding, not per-unit A*
- Squad-level logic, model-level visuals only

Godot 4 can do this, but crowd rendering at Total War scale is not a solved
problem in the engine the way it is in Unreal. This is the biggest technical
risk in the project.

### Cross-Platform
Developing on Mac (Metal) and shipping to Windows (Vulkan/D3D12) means
testing exports on Windows regularly, not at the end. Rendering differences
and shader compilation issues surface late otherwise.

### Scope
This is three games in one — a colony sim, a strategy layer, and a tactical
battle engine. Recommend building them in this order, each playable before
moving on:
1. **Settlement layer alone** — a cozy woodland colony sim. Shippable on its own.
2. **Battle layer** — tactical battles as a standalone skirmish mode.
3. **Campaign layer** — the connective tissue that binds them.

## IP Note
Redwall is Brian Jacques' copyrighted work (estate-controlled). Character
names like Martin the Warrior, Cregga, and Tsarmina are protected. This is
fine for a personal project. If commercial release ever becomes the goal,
you'd need either a license or to rename characters and locations while
keeping the woodland-creature-fantasy genre, which isn't protectable.
