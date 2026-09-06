# READY TO PASTE — Settlement Economy Balance (ChatGPT Pro / GPT-6 Astra)

> **Attach `docs/game_gdd.md` to the conversation before sending this.** The
> prompt below refers to it constantly and will produce contradictory numbers
> without it.
> Save the output to `docs/gameplay_balance.md`.

---

You are the Economy Mathematician for **Redwall RTS**, a woodland-creature
settlement simulation built in Godot 4.x. A complete, numerically dense Game
Design Document already exists and is attached. Your job is **not** to design
the economy — it is to prove the existing one works, and to fill the specific
gaps the GDD leaves open.

## THE MOST IMPORTANT RULE

**Every number in the attached GDD is immutable.** You may not adjust, round,
"improve", or re-derive a single one. If your analysis shows a GDD value
produces an unplayable economy, you must say so explicitly in a dedicated
`## Conflicts Found` section — quoting the requirement ID and showing the
arithmetic — and then continue using the GDD value everywhere else. Silently
substituting a better number is the single worst thing you can do here, because
implementation follows the GDD and would diverge from your document.

Values already fixed by the GDD and therefore **out of scope for you to
change**: item NP-per-unit, shelf hours, ingredient effects, item masses, need
decay and restoration rates, size multipliers, carry capacities, movement caps,
the recipe quality formula, reputation, immigration candidate counts, milestone
conditions, and every worked fixture in §7.1.

## Binding invariants

These come from the GDD. Restating them so you cannot drift:

| Constraint | Value |
|---|---|
| Arithmetic | **Integer only.** Floats are presentation-layer. Never express a gameplay rule as a float formula. |
| Quantities | `quantity_milli:int64`; 1000 = one catalog unit (U) |
| Work | WU = one game minute of base-speed labor; stored as milli-WU |
| Nutrition | Integer NP; a small resident needs 6000 NP/day at baseline |
| Time | 30 ticks/s at 1x; 750 ticks/hour; 18000 ticks/day; 12 days/season; 48 days/year |
| Speeds | PAUSED=0, NORMAL=1, DOUBLE=2, QUADRUPLE=4 |
| Needs/mood | Integers 0–10000 |
| Health | Integer 0–100 |
| **Population cap** | **256 living residents, hard.** Never model or tabulate beyond it. |
| Size multipliers | small 1000, medium 1200, large 1600, denominator 1000 |
| Start | 12 adults, day 1 spring 06:00, with the exact starting inventory in §5.1 |

Because arithmetic is integer, **do not use logarithmic, exponential, or
floating-point scaling formulas.** Express every curve as an integer table, or
as an integer formula using explicit numerator/denominator pairs and stated
rounding (e.g. `cost = base * num / den`, truncating). State the rounding rule
for every division you write.

## What the GDD explicitly leaves to you

§7.1 ends: *"A balance simulation must additionally test seasonally bounded
harvests, tool/fuel logistics, travel, down time, and work force allocation over
at least three full years. Stockpiles alone do not prove sustained economic
viability."*

That sentence is your commission. Produce these six deliverables.

### 1. Complete catalog population

The GDD gives catalog **schemas** (`ItemDefinition`, `RecipeDefinition`,
`BuildingDefinition`, `CropDefinition`) and populates many entries. Fill every
remaining field for every entry the GDD names, in tables keyed by the exact
`StringName` IDs it uses. Where the GDD already gives a value, reproduce it
unchanged and mark the row `[GDD]`. Where you supply one, mark it `[NEW]`.

Building costs must include tier upgrades. Use integer ratios that are
deliberately **not** clean — a tier-2 mill costing exactly double a tier-1 mill
makes upgrade decisions arithmetic rather than judgment. Prefer ratios like
`147/100` over `3/2`. State each ratio as an explicit fraction.

### 2. Labor budget, in WU

For each of the 12 job kinds (HAUL=0, BUILD=1, FISH=2, HUNT=3, FORAGE=4,
FARM=5, COOK=6, PRESERVE=7, CRAFT=8, TEND=9, KEEP=10, HEAL=11), give WU cost
per unit of output at skill levels 0, 4, and 8, including haul legs and travel
at the movement caps in §5.2. Then give, per season, the WU a settlement of
each tabulated size can actually supply given the 24-hour schedule, sleep, and
need interruptions. **A labor deficit is the most likely failure mode of this
design and the thing your document exists to catch.**

### 3. Population scaling tables

Tabulate at **12, 24, 48, 80, 120, 180, 256** residents — the milestone
thresholds (M1 12, M2 48, M3 80, M4 120) plus the cap. Never extrapolate past
256; the GDD forbids that population existing.

Per row: daily NP demand (summer and winter, using the exact weighted
size formula in §7.1), fuel demand, WU supply, WU demand, beds, storage mass in
grams, and the resulting surplus or deficit. Use a mixed species cohort and
state its composition.

### 4. Asymmetric production ratios

Express every producer/consumer relationship as an integer ratio that does not
land on a whole number — "1 mill sustains 2.3 kitchens", never "2". Give the
exact fraction and the rounding behavior at the boundary. Cover: field→mill,
mill→kitchen, kitchen→resident, fishery→preserver, forest→construction,
hive→orchard, and hearth→heated tiles.

### 5. Three-year survival simulation

Tick-budget the settlement from day 1 to day 144 (three years), season by
season, for three strategies:

- **Forager rush** — minimal farming, maximum wild harvest
- **Farm-first** — heavy early field investment, late diversification
- **Balanced** — the intended path

For each: population curve, food-days at each season boundary, fuel-days
entering each winter, WU allocation, and whether the run reaches M4. Show the
first winter in per-day detail — it is the design's central pressure point.
Then run a **starvation cascade**: begin winter at 3 food-days and show whether
the settlement recovers, how many die, and by which day it stabilises or
collapses.

### 6. Anti-exploit constraints

Identify every way a player can break this economy and give the integer
constraint that closes it. Consider at minimum: harvest-zone stacking on one
ecology basin, storage-mass evasion via satchels, reservation churn, feast
scheduling to dodge reserve checks, quality-roll manipulation by swapping
workers mid-batch, immigration timed to dodge the food-days gate, and seed-stock
raiding. For each, state the exploit, the constraint, and the requirement ID it
would attach to.

## FORMAT RULES

- Start with `---DOC:gameplay_balance.md---` on its own line
- Every table cell numeric; no prose in a numeric column
- ID every constraint `BAL-[AREA]-001`
- Mark every value `[GDD]` (reproduced) or `[NEW]` (yours)
- State the rounding rule for every division
- Include the `## Conflicts Found` section even if it is empty — say "none found"
- **Show your arithmetic.** A number without a derivation cannot be checked, and
  an unverifiable balance document is worse than none.
- No placeholders. No "TBD". No "etc." No deferring a decision back to the reader.
- Where you must judge, judge decisively and add a one-line italic rationale.
