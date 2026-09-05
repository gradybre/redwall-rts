# READY TO PASTE — Crowd Rendering & Performance Architecture (ChatGPT Pro / GPT-6 Astra)

> Copy everything below the line into ChatGPT Pro. No edits needed.
> Save output to `docs/crowd_rendering_architecture.md`.
>
> **Why send this now, before building the battle layer?** The answer
> determines how entity and component data must be laid out from day one.
> If squads need contiguous float arrays for GPU instancing, the settlement
> layer's ECS has to be built that way from the start rather than retrofitted.

---

You are a senior graphics and systems engineer specializing in real-time
crowd rendering. Solve a specific, hard technical problem.

## The Problem

I am building a Total War-scale tactical battle system in **Godot 4.x with
GDScript**. I need to render and simulate large numbers of individually
animated 3D characters at 60 FPS.

### Target Scale

| Tier | Models per Squad | Species |
|------|-----------------|---------|
| Small | 40-60 | Shrews, mice, moles, rats, squirrels, sparrows |
| Medium | 30-40 | Otters, hares, ferrets, weasels, hedgehogs, kestrels |
| Large | 10-15 | Badgers, foxes, wildcats, wolverines |
| Giant | 1 (single entity) | Falcons, snakes, eels, shrikes |

**Worst case on screen:** 10-16 squads per side, two sides.
That is **800-1600 individually animated characters** simultaneously.

### Hard Requirements
- **60 FPS** during battle at worst-case unit count
- **Real-time with pause** — simulation must be deterministic and pausable at
  any tick, with full camera control while paused
- Camera: 3/4 perspective RTS, zooms from tactical overview down to near
  ground level where individual models are clearly visible
- Art fidelity target: Age of Empires IV / Total War: Warhammer III
- Units need visible weapons, armor variation, and per-model equipment
  differences within a squad (mixed-weapon squads are a core mechanic)
- Formations, flanking, morale/rout — units must physically move as coherent
  groups and visibly break apart when routing

### Platform Constraints
- **Developed on:** macOS, Apple Silicon (M-series), Metal backend
- **Shipping to:** Windows/PC as the primary platform (Vulkan / D3D12)
- Must run acceptably on mid-range hardware, not just high-end
- Godot 4.x, GDScript primary. **Tell me explicitly if any part of this
  problem requires GDExtension/C++ rather than GDScript** — I would rather
  know now than discover it in month eight.

## What I Need From You

### 1. Rendering Architecture
- Is `MultiMeshInstance3D` the right primitive here? What are its hard limits
  in Godot 4.x for *animated* meshes specifically?
- How do I achieve per-instance animation when MultiMesh instances share a
  mesh? Cover the realistic options: vertex animation textures (VAT),
  GPU skinning via custom shader, animation texture atlases, or something else.
- How do I handle per-model equipment variation (different weapons within one
  squad) under an instanced rendering approach?
- Concrete LOD strategy: at what screen-space sizes or camera distances do I
  drop from full skeletal → VAT → simplified → impostor/billboard? Give me
  actual thresholds to start from.
- Draw call budget: what should I target, and how do I get there?

### 2. Animation Approach
- Compare skeletal animation vs. vertex animation textures for this exact
  scale. Where is the crossover point?
- How many unique animation states does a unit realistically need (idle,
  walk, run, attack variants, hit reaction, death variants, rout)?
- Animation LOD: when can I reduce animation update rate, and by how much,
  before it becomes visible?
- How do I avoid the "everyone marching in lockstep" look while using
  instanced animation? Per-instance time offset — what are the mechanics and
  costs?

### 3. Simulation Architecture (separate from rendering)
- Recommended data layout for squad and model state. Be specific about Godot
  types: `PackedFloat32Array`, `PackedVector3Array`, typed `Array`, or custom
  `Resource` classes — and why.
- Squad-level vs. model-level simulation: what must be simulated per model,
  and what can be simulated per squad and merely *rendered* per model?
- Pathfinding for coherent groups: flow-field implementation specifics.
  How do I keep a 60-model squad in formation while pathing around obstacles?
- Collision and unit separation without a physics engine per model — what is
  the cheap approach that still looks right?
- Combat resolution: per-model pairwise combat, or statistical resolution at
  the squad level with visual approximation? Give me the tradeoff honestly.

### 4. Determinism & Pause
- What breaks determinism in Godot 4 that I need to actively avoid?
  (float non-determinism, `randf()` seeding, physics timestep, delta variance)
- How do I structure the simulation tick so pause is clean and resume is
  seamless?
- Should the simulation run on a fixed timestep decoupled from render frame
  rate? If so, how do I handle interpolation for smooth visuals at
  variable FPS?

### 5. Memory Budget
Give me a concrete table:

| Data | Bytes per Model | At 800 Models | At 1600 Models |
|------|----------------|---------------|----------------|
| Transform | | | |
| Animation state | | | |
| Combat stats | | | |
| (etc.) | | | |

Target: keep total battle simulation data under 100 MB.

### 6. Cross-Platform Risk
- What specifically differs between Metal (Mac dev) and Vulkan/D3D12
  (Windows target) that will bite me with instanced rendering and custom
  shaders?
- What should I be testing on Windows from week one rather than at the end?

### 7. Honest Feasibility Assessment
This is the most important section. Tell me directly:
- **Is 800-1600 animated characters at 60 FPS realistic in Godot 4.x?**
  If not, what is the actual achievable number, and what does it cost me
  in visual fidelity to get there?
- What do I have to give up? Rank the fidelity sacrifices from
  least-painful to most-painful.
- Where does GDScript become the bottleneck and GDExtension/C++ become
  mandatory?
- Would you recommend a different engine for this specific problem? If so,
  say so plainly and explain what Godot fundamentally cannot do here. I would
  rather hear it now than after a year of work.
- If the answer is "reduce squad sizes," tell me what the honest maximum is
  and what a good-looking battle at that scale actually looks like.

### 8. Prototype Plan
Give me a sequenced list of small, isolated technical prototypes that
validate or kill this architecture as fast as possible — cheapest and most
decisive test first. For each: what it builds, what it measures, and what
result means "stop and rethink."

## FORMAT
- Wrap the full response in `---DOC:crowd_rendering_architecture.md---`
- Use Markdown headers, tables, and code blocks
- Include actual GDScript snippets for the core patterns you recommend
- Cite Godot 4.x API specifics (class names, method signatures) wherever possible
- **Be brutally honest about feasibility.** I would rather abandon this
  approach now than discover its limits after a year of work. Do not soften
  bad news.
