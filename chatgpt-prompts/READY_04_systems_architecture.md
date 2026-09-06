# READY TO PASTE — Settlement Systems Architecture (ChatGPT Pro / GPT-6 Astra)

> **Run `READY_02_crowd_rendering.md` first.** The GDD defers to
> `docs/crowd_rendering_architecture.md` in six places — for the deterministic
> command/RNG boundary, the bounded integer separation grid, and the hardware
> qualification floor — and that document does not exist yet. This prompt can
> run without it (there is a fallback clause below), but the result will be
> weaker and you will have two documents to reconcile later.
>
> **Attach `docs/game_gdd.md` and `docs/ui_ux_controls.md`** before sending,
> plus `docs/crowd_rendering_architecture.md` if you have produced it.
> Save the output to `docs/systems_architecture.md`.

---

You are the Systems Architect for **Redwall RTS**, a woodland-creature
settlement simulation in Godot 4.x / GDScript. A complete Game Design Document
and UI/Controls specification already exist and are attached. Your job is to
turn their **entity/component registry into an implementable memory and
execution architecture** — the document a coding agent reads immediately before
writing the simulation core.

## THE MOST IMPORTANT RULE

**The GDD's §4.2 component registry is the schema of record.** Every component,
field, type, and cardinality it lists is fixed. You decide how those fields are
*laid out, ordered, and executed* — never what they are. If a field's stated
type or cardinality makes the performance budget unreachable, say so in a
`## Conflicts Found` section with the arithmetic, then design against the GDD
value anyway.

## Binding invariants

| Constraint | Value |
|---|---|
| Arithmetic | **Integer only** for authoritative state; float is presentation/import |
| Storage | **Structure-of-arrays**: `PackedInt32Array` / `PackedInt64Array` columns, not one object per entity |
| Entity handle | `EntityRef = (slot:int32, generation:int32)`, null `(-1,0)`; **slots reused with generation validation** |
| Tick | 30 fixed ticks/s at 1x; 750/hour; 18000/day; 12 days/season; 48/year |
| Speeds | PAUSED=0, NORMAL=1, DOUBLE=2, QUADRUPLE=4 — more ticks per real second, identical per-tick rules |
| Position | int32 in 1/1024 m units; +Y up, −Z forward; yaw 65536/turn |
| Population | 256 living residents; resident slot capacity 512 |
| Enum values | From the sorted-key `catalog_ids.json`, hash-verified at load. **Dictionary insertion order is prohibited** as an ordering source. |

Performance budgets you must design against (GDD REQ-SET-163): frame p95
≤16.67 ms / p99 ≤20 ms; simulation tick p99 ≤2 ms at 1x; aggregate simulation
CPU p95 ≤6 ms per render frame at 4x; UI work p95 ≤1.5 ms; simulation-owned
memory ≤100 MB; full process ≤4 GB; job route ready p95 ≤0.25 real seconds
at 1x; at most 24 skeletal actors of the 256 residents.

**If `crowd_rendering_architecture.md` is not attached:** define the
deterministic command/RNG boundary and the bounded integer separation grid
yourself, mark that section `[ASSUMED — pending crowd doc]`, and list every
decision the crowd document would need to confirm.

## Deliverables

### 1. Memory layout, with arithmetic

For every component in GDD §4.2, give the concrete column set: array type,
element width in bytes, allocated length, and total bytes. Sum to a **memory
budget table** and compare against the 100 MB simulation budget at 256
residents with all child stores at their stated capacities (16384 inventory
lots, 32768 reservations, 8192 jobs, 4096 farm plots, 1024 buildings).

Show the arithmetic. State explicitly which stores dominate and what the
headroom is. A budget that merely asserts "fits in 100 MB" is not usable.

### 2. Slot allocation and generation validation

Specify the free-list, generation increment rule, generation overflow behavior,
and how a stale `EntityRef` is detected on every access path. Give the exact
validation predicate. Specify what happens when a store is full — the GDD
requires **explicit refusal**, not silent eviction.

### 3. System execution order

A table of every system: name, read set, write set, frequency (every tick /
hourly at 750-tick boundaries / daily at the 00:00 crossing / on command), and
its ordering constraints against the others.

REQ-SET-007 fixes the daily order: age stocks → update ecology → advance
crops/weather → process immigration/departures → evaluate progression. Respect
it. Note that daily boundaries use the offset calendar `(tick+4500) mod 18000`
with first midnight at tick 13500 — **not** `tick mod 18000 == 0`.

Identify which systems could run concurrently and which must not, and say why.

### 4. Tick pipeline and the command queue

Trace one tick end to end. Then specify the command queue satisfying
REQ-SET-005: commands issued while paused append to the next-tick ordered queue
and render a pending preview **without early gameplay effect**. Give the
ordering key that makes replay deterministic.

Specify the overload response required by REQ-SET-008: >0.25 s backlog reduces
4x→2x→1x with a warning, and at 1x **pauses with a diagnostic rather than
skipping ticks**. Say precisely where backlog is measured and how the
diagnostic identifies the failing subsystem (REQ-SET-164).

### 5. Determinism and RNG

Enumerate the RNG streams, their seeding from the world seed, and their
advancement rules. Specify the simulation hash: what it covers, when it is
taken, and how a desync is localised. REQ-SET-160 requires hashes to match
after the next tick following a load.

### 6. Pathfinding

The GDD fixes: 0.5 m static cells; deterministic squad-free A*; routes cached
by `(start macro cell, goal, clearance, map_revision)`; neighbor order N, E, S,
W, NE, SE, SW, NW; diagonal corner blocking; 10/14 costs; ties broken by cell
index; main-thread cap 2048 expansions/tick; queries queued in job-ID order.

Design the cache — capacity, eviction, invalidation on `map_revision` change —
and the local entry/exit segment handling. Show how the 2048-expansion cap
still meets p95 route-ready ≤0.25 s at 1x with 256 residents, or state the
population at which it stops holding.

### 7. Save/load

Serialization format, field order, versioning, and the validation sequence from
REQ-SET-159/160/161. Include the tick-boundary guarantee and the
ruleset/map/catalog version checks. Specify what a corrupted save must **not**
do: no partial world load.

### 8. Godot patterns and anti-patterns

Autoload boundaries (max 6). Where `PackedInt32Array` beats `Array` and by how
much. Why no physics body, navigation agent, or `AnimationTree` per resident.
How UI reads simulation state without coupling to it, given the ≤1.5 ms UI
budget and REQ-SET-162's requirement that per-frame UI work stay independent of
hourly/daily simulation. Signal rules: which direction they may flow.

### 9. Migration from the existing prototype

A prototype bootstrap exists in `godot/` and diverges from this spec. It has:
an `EntityManager` with monotonic non-reused integer IDs and one `Resource`
object per component (array-of-structures); an `EconomySystem` holding four
float stockpiles on a 1-second float accumulator; a `GameManager` with speeds
`[1.0, 2.0, 3.0]` and no calendar; and a `CombatSystem` with a damage model the
settlement layer does not define.

For each: state whether it should be **migrated, rewritten, or deleted**, and
give the order of operations that keeps the existing 52-test suite meaningful
during the transition. Be blunt — if something should be thrown away, say so.

## FORMAT RULES

- Start with `---DOC:systems_architecture.md---` on its own line
- ID every decision `ARCH-[AREA]-001`
- ASCII data-flow diagrams for the tick pipeline and the job lifecycle
- Every memory figure derived, never asserted
- Include `## Conflicts Found` even if empty — say "none found"
- Mark anything the crowd document should confirm `[ASSUMED — pending crowd doc]`
- No placeholders. No "TBD". No "etc."
- Where you must judge, judge decisively with a one-line italic rationale. Do
  not hand the decision back to the reader.
