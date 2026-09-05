# READY TO PASTE — Settlement Layer GDD (ChatGPT Pro / GPT-6 Astra)

> Copy everything below the line into ChatGPT Pro. No edits needed.
> Save the two output documents to `docs/game_gdd.md` and `docs/ui_ux_controls.md`.

---

You are the Game Design & UX Architect for **Redwall RTS**, a woodland-creature
strategy game built in Godot 4.x. Your job is to translate a project concept
into two exhaustive specification documents that leave ZERO room for ambiguity.
Downstream coding agents implement directly from these specs — if something is
vague, they will guess wrong.

## Project Context

**The full game (3 layers, built in order):**
1. **Settlement Layer** — Cozy colony sim. Deep fishing/hunting/farming/cooking,
   creature needs and jobs, seasonal cycles, building construction. *(This is
   the current build target and the scope of your task.)*
2. **Battle Layer** — Total War-scale real-time-with-pause tactical battles,
   squad-based, 10-60 models per unit depending on species size.
3. **Campaign Layer** — Strategic map with territory, roaming armies,
   encounters, quests.

**Confirmed technical decisions:**
| Decision | Choice |
|----------|--------|
| Engine | Godot 4.x, GDScript |
| Camera | 3/4 perspective, WASD pan, Q/E rotate |
| Settlement scale | Large — 80-200+ creatures |
| Named characters | Heroes/lords/villains named; general population anonymous |
| Art style | Detailed 3D — Age of Empires / Total War fidelity |
| Combat (later phase) | Real-time with pause |
| Multiplayer | Single-player only |
| Dev platform | macOS (M-series) |
| Target platform | Windows/PC |
| Assets | Blender |

**Tone and setting:** Woodland creatures in a Redwall-inspired world. The
settlement is home — an abbey, holt, or mountain fortress. Warm hearths,
feasting halls, and the constant low pressure of seasons turning. Cozy but
never safe.

**Design references:** Manor Lords (the exact settlement-sim + battle hybrid),
Rimworld and Dwarf Fortress (creature autonomy, emergent stories), Banished
and Farthest Frontier (seasonal survival, food chain depth), Evil Genius 2
(room-based interior building, job assignment), Age of Empires (camera feel,
3D readability).

## YOUR SCOPE: The Settlement Layer Only

Design the settlement layer as a **complete, standalone, shippable game**. It
must be satisfying on its own without any battle or campaign content. Assume
the battle layer arrives later and design data structures that won't need to
be torn up when it does — but do not design battle content.

### Core Systems to Specify

**1. Creature Simulation**
- Needs (hunger, rest, comfort, social, purpose) with decay rates and thresholds
- Skills and skill progression per job type
- Job assignment: priority-based, player-set, with automatic fallback
- Daily routines and schedules
- Relationships between creatures
- Mood/happiness and its consequences (productivity, departure, conflict)
- Named vs. anonymous creature handling — when does an anonymous creature
  become named and tracked?

**2. Fishing System (deep)**
- Fishing spot types: river, lake, coastal — each with distinct fish species
- Seasonal availability windows (salmon runs, ice fishing, spawning closures)
- Gear progression: hand nets → traps → weirs → boats
- Skill influence on yield and rare catch chance
- Danger: pike and eels can injure or kill fisherbeasts
- Sustainability: over-fishing depletes spots, recovery over time

**3. Hunting & Foraging System (deep)**
- Trackable game animals with migration and population dynamics
- Forageables by season: berries, nuts, mushrooms, herbs, roots
- Zone danger gradient — deeper woods yield more but carry risk
- Sustainable harvest vs. depletion mechanics
- Hunting party composition and equipment

**4. Farming System (deep)**
- Crop types with soil requirements, growth duration, seasonal planting windows
- Soil quality, depletion, fertilization, and crop rotation
- Orchards: multi-year investment with delayed large payoff
- Beekeeping: honey, wax, mead, and pollination bonuses to nearby crops
- Weather events: drought, blight, early frost, ideal seasons
- Storage, spoilage, and preservation (drying, salting, cellaring)

**5. Cooking System (deep)**
- Ingredient properties — each contributes distinct buffs
- Recipe system: ingredients combine into dishes; dish quality tiers
- Cook skill influence on output quality and ingredient efficiency
- **Feasts**: elaborate multi-dish events granting settlement-wide buffs.
  Specify trigger conditions, ingredient costs, buff magnitudes, durations.
- Meal variety tracking — creatures tire of repeated dishes
- Preservation and field-ration preparation (forward-compatible with the
  later battle layer, where armies carry food)

**6. Building & Construction**
- Building categories: production, storage, housing, social, defensive
- Interior room designation vs. exterior structures — specify which
  buildings have managed interiors and which are black boxes
- Construction: material requirements, build time, worker assignment
- Upgrade paths
- Placement rules, adjacency bonuses, and terrain requirements

**7. Seasonal Cycle**
- Four seasons with distinct gameplay pressure
- Season length in game-time and real-time
- What each season changes: resource availability, creature needs, weather,
  events
- Winter as the primary survival test — specify the failure cascade

**8. Time & Progression**
- Day/night cycle: does it exist separately from seasons? What changes?
- Game speed controls and pause
- Long-term progression: what does the player unlock or work toward across
  many in-game years?
- Victory/end conditions, if any — or is it endless sandbox?

## OUTPUT REQUIREMENTS

### Document 1: `game_gdd.md`

Use **EARS notation** (Easy Approach to Requirements Syntax) for every
functional requirement:
- **Ubiquitous:** "The system shall [action]"
- **Event-driven:** "When [trigger], the system shall [action]"
- **State-driven:** "While [state], the system shall [action]"
- **Optional:** "Where [condition], the system shall [action]"
- **Unwanted:** "If [undesired trigger], then the system shall [action]"

Structure:
1. **Feature Overview** — one paragraph per major system
2. **Player Fantasy** — the emotional experience each system creates
3. **Core Loops** — numbered step-by-step for each of: daily management,
   seasonal cycle, long-term progression
4. **Entities & Components** — every game object, with typed properties
   (`int`, `float`, `bool`, `enum`, `StringName`) and relationships. This
   section feeds directly into ECS implementation, so be precise about data
   types and cardinality.
5. **Requirements** — EARS-notation, every requirement gets ID `REQ-SET-001`
6. **Progressive Disclosure** — what the player encounters at:
   - Minute 1 (first contact / tutorial)
   - Hour 1 (competent basic play)
   - Hour 10 (system mastery)
   - Hour 50+ (optimization and edge strategies)
7. **Edge Cases & Failure States** — starvation cascade, creature death,
   settlement collapse, resource deadlocks, unreachable job sites
8. **Forward Compatibility Notes** — where the settlement layer must expose
   hooks for the later battle and campaign layers

### Document 2: `ui_ux_controls.md`

**Screen zone map** — assign every UI element to a zone:
- Top-left: Resource counters
- Top-center: Alerts and notifications
- Top-right: Time controls, season indicator, game menu
- Bottom-left: Minimap
- Bottom-center: Selected entity commands
- Bottom-right: Context detail panel
- Center: Game world (click-through)

**For every UI element specify:**
- Element ID (`UI-SET-001`)
- Zone placement and anchoring behavior
- Size constraints (min/max, in pixels)
- Typography: font size, weight, color token
- Background: color token, opacity, border radius
- All states: default, hover, pressed, disabled, selected
- Animation: property, duration in ms, easing curve
- Accessibility: contrast ratio (WCAG AA minimum), screen reader label
- Show/hide conditions and progressive disclosure gating

**Input mapping table:**

| Action | Mouse | Keyboard | Notes |
|--------|-------|----------|-------|
| Pan camera | Edge scroll | WASD | |
| Rotate camera | — | Q / E | |
| Zoom | Scroll wheel | — | |
| Select | Left click | — | |
| Command | Right click | — | |
| Pause | — | Spacebar | |
| (continue for all actions) | | | |

**Also specify:**
- HUD priority stack — z-index and dismissal rules when panels compete
- Responsive behavior from 1280x720 to 3840x2160
- Camera constraints: min/max zoom, rotation limits, pitch angle range,
  edge-of-map behavior
- Selection feedback: single select, box select, control groups
- Notification system: severity tiers, dismissal, history log

## FORMAT RULES
- Output each document with a `---DOC:filename.md---` header on its own line
- Markdown headers, tables, and lists throughout
- Every requirement and UI element gets a unique ID
- **Be exhaustive.** A 6000-word document beats a 1500-word one. This spec is
  the sole input to implementation.
- **No placeholders.** No "TBD", no "to be determined", no "etc."
- Where you must make a design judgment call, make it decisively and add a
  one-line rationale in italics. Do not defer decisions back to the reader.
