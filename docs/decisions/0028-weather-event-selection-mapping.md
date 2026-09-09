# 0028 — The WEATHER roll-to-row mapping
Date: 2026-09-09 · Status: **Accepted — planner ruling**
Amends: `game_gdd.md` §5.10, `systems_architecture.md` ARCH-RNG-002

## The gap
ARCH-RNG-002 fixed the WEATHER draw count at one per season and §5.10 said
weights are "normalized within the season's eligible rows" — but **nothing
stated how a `uint32` draw becomes a table row.** Four sub-decisions were open,
and each changes which event a given seed produces: row order, range reduction,
boundary comparison, and whether "normalized" meant numeric conversion.

No weighted picker was written while this was open. Inventing the scan order
would have been inventing a contract, and an invisible one: the code would have
looked correct and produced a different world from the specified one.

## The ruling
Scan §5.10's printed event order — Ideal spell, Heavy rain/storm, Drought,
Blight, Early frost, Hard freeze, Calm days — filtered to the season's eligible
rows. Retain **raw integer weights**; "normalized" means relative probability
within the eligible set, not a numeric percentage conversion.

```
roll = uint32_draw mod weight_sum
cumulative = 0
for row in eligible_rows:
    cumulative += row.weight
    if roll < cumulative: select row; stop
```

Strict `<`. Modulo bias is accepted and disclosed; **rejection sampling stays
forbidden**, because variable draws per call break ARCH-RNG-002's per-stream
disciplines.

| Season | Weight sum | Mapping (inclusive) |
|---|---:|---|
| Spring | 85 | Ideal 0–29; Heavy rain 30–64; Calm 65–84 |
| Summer | 120 | Ideal 0–29; Drought 30–79; Blight 80–99; Calm 100–119 |
| Autumn | 135 | Ideal 0–29; Heavy rain 30–64; Blight 65–84; Early frost 85–114; Calm 115–134 |
| Winter | 110 | Ideal 0–29; Hard freeze 30–89; Calm 90–109 |

All four sums and every interval were independently recomputed from §5.10's
weights before implementation. **No weight sum is a power of two**, so the
modulo bias is real and differs per season — that is the disclosed cost of the
no-rejection rule, not an oversight.

Season index **orders** the event and must not cause per-season reseeding.
Forced first spring is Ideal spell and consumes **zero** draws.

## Why the omission was worth escalating rather than guessing
The sibling streams state their mappings outright — QUALITY gives
`R=(draw mod 21)-10`, IMMIGRATION gives "modulo 12" for a duplicate skill.
WEATHER gave neither. That asymmetry is what identified it as an omission rather
than deliberate silence, and the planner confirmed it as such.

## Consequences
- The mapping table is encoded as **test data** and asserted row by row, not
  re-derived from the implementation's own constants — a test that recomputes
  from the same source proves nothing.
- Both sides of every interval boundary are tested, in all four seasons.
- Draw counts are asserted explicitly: one per ordinary season, zero for forced
  first spring, and no reseed across a season change.

## Source
Planner ruling, 2026-09-09, responding to `chatgpt-prompts/READY_05_planner_rulings.md`.
