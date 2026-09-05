# Redwall RTS — Game Concept Brief

## The Pitch
A cozy-but-dangerous RTS colony-builder where you lead a community of woodland
creatures defending their abbey from vermin warlords. Think Redwall meets
Dwarf Fortress meets Northgard — warm hearths, feasting halls, and desperate
last stands on the walltops.

## Setting & Fantasy
The player is the Abbotess/Abbot — not directly controlling units, but guiding
the community through priorities and construction. Creatures have their own
routines (eating, sleeping, socializing) that the player shapes rather than
micromanages. The abbey is home. Building it, feeding it, and defending it
IS the game.

Seasons cycle and matter: summer is for foraging and building, autumn for
harvest and stockpiling, winter tests your reserves, spring brings new
arrivals (and new threats).

## Camera Perspective
<!-- BRENDAN: Pick one -->
- [ ] **Top-down isometric** (like Rimworld/Prison Architect — clearest for colony management)
- [ ] **3/4 perspective** (like Northgard/Age of Empires — more visual depth)
- [ ] **Side-on cutaway** (like Fallout Shelter/Oxygen Not Included — shows interior rooms)

## Colony Scale
<!-- BRENDAN: Pick one -->
- [ ] **Small & intimate** (10-30 creatures, each named with personalities — like Rimworld)
- [ ] **Medium village** (30-80 creatures, named leaders + anonymous workers)
- [ ] **Large settlement** (80-200 creatures, mostly anonymous, squad-based)

## Core Gameplay Loops

### Loop 1: Build & Sustain (Peaceful)
1. Designate rooms/buildings inside and around the abbey
2. Creatures claim jobs based on skills (cook, brewer, builder, healer, warrior)
3. Production chains convert raw resources → refined goods → meals/equipment
4. Maintain happiness through feasts, festivals, and comfortable living spaces

### Loop 2: Explore & Forage
1. Send parties into Mossflower Woods to gather resources
2. Discover points of interest (ruins, groves, rival settlements)
3. Encounter wandering creatures who may join your abbey
4. Risk/reward: deeper woods = better resources but more danger

### Loop 3: Defend & Fight
1. Vermin warlords send raiding parties (escalating waves)
2. Build walls, gates, towers along approach paths
3. Assign defenders to positions (walltop archers, gate guards, boiling-pot crews)
4. Combat is positional — terrain and fortifications matter more than unit count

## Resource Types
<!-- BRENDAN: Adjust these -->
| Resource | Source | Used For |
|----------|--------|----------|
| Wood | Forest trees | Construction, fuel |
| Stone | Quarry, ruins | Walls, fortifications |
| Food (raw) | Farms, foraging, fishing | Cooking |
| Meals | Kitchen (from raw food) | Feeding creatures, feasts |
| Cloth | Flax fields, looms | Clothing, banners, beds |
| Iron | Trade, rare mine | Weapons, tools |
| Herbs | Garden, forest | Medicine, brewing |
| Ale/Cordial | Brewery (from herbs + food) | Happiness, trade |

## Creatures & Roles
Drawing from Redwall lore:
- **Mice** — Balanced, good leaders and scribes
- **Moles** — Excellent diggers and builders, slow but strong
- **Hares** — Fast fighters, high food consumption ("the long patrol")
- **Otters** — Swimmers, fishers, aggressive warriors
- **Squirrels** — Archers, scouts, foragers (climb trees)
- **Badgers** — Rare, powerful, berserker warriors (1-2 per game max)
- **Hedgehogs** — Crafters, brewers, cooks

### Vermin (enemies)
- **Rats** — Common raiders, attack in numbers
- **Weasels/Stoats** — Faster, flanking tactics
- **Foxes** — Leaders, buff nearby vermin
- **Ferrets** — Siege specialists (ladders, battering rams)
- **Wildcat** — Boss-tier, late game

## Combat Style
<!-- BRENDAN: Pick one -->
- [ ] **Fully automated** — You set positions and priorities, creatures fight on their own (like Dwarf Fortress)
- [ ] **Semi-tactical** — You assign squads to zones, can trigger abilities (like Northgard)
- [ ] **Full tactical** — Pause-and-command, direct unit control (like classic RTS)

## Multiplayer
<!-- BRENDAN: Pick one -->
- [ ] **Single-player only** (focus all effort here first)
- [ ] **Co-op** (2 players share an abbey)
- [ ] **Competitive** (abbey vs abbey, or abbey vs vermin player)

## Art Style
<!-- BRENDAN: Pick one -->
- [ ] **Stylized low-poly** (like Northgard — fits Blender workflow, good perf)
- [ ] **Pixel art** (like Rimworld — simpler asset pipeline)
- [ ] **Painterly 2.5D** (like Banner Saga — beautiful but heavy asset cost)
- [ ] **Voxel** (like Stonehearth — Blender-friendly, moddable)

## Design References
- **Evil Genius 2** — Room-based building, minion management, base defense
- **Dwarf Fortress / Rimworld** — Creature autonomy, emergent stories, colony sim depth
- **Northgard** — Territory control, seasonal pressure, accessible RTS
- **Redwall novels** — Tone, creatures, abbey life, feast culture, walltop defense
- **Banished** — Small-community survival, supply chain management
- **They Are Billions** — Defensive RTS, wall-building under pressure

## Firm Preferences (Non-Negotiable)
<!-- BRENDAN: List anything you're certain about -->
- Godot 4.x engine, GDScript
- Must run well on MacBook (M-series)
- Blender for 3D assets
- Seasonal cycle affects gameplay
- Abbey is the central structure (not a generic base)
- Feasting/food culture is a core mechanic, not just a resource bar

## Open Questions
<!-- BRENDAN: Anything you're still unsure about -->
- How much interior space management? (room assignment like Prison Architect, or exterior-only?)
- Tech tree vs organic discovery?
- How does the game end? (endless sandbox, campaign missions, threat escalation to final boss?)
- Day/night cycle separate from seasons?
