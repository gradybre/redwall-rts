# 1046 — The fishing hazard roll needs two rulings before it is wired

Date: 2026-10-02 · Status: Proposed (written up, not built; questions for Brendan below)

## Why this is a write-up and not a fix

The brief said: wire the fishing hazard roll per the GDD's rule, or write it up
if the rule is not fully specified. The rule is mostly specified. Two inputs
that decide *who* is hurt and *how* are not, and both change what a player sees.
So nothing is built here. This record collects what is specified, what is not,
and the exact change that would wire it once the gaps are ruled.

## What the documents specify (would be implemented as written)

| Part | Rule | Source |
|---|---|---|
| When | "When a fishing expedition resolves, the system shall perform its one declared hazard roll" | REQ-SET-053 |
| Draw discipline | FISHING stream: "One hazard and one rare-quality roll per completed eligible fishing cycle", ordered by expedition ID; a cycle closed or invalid before departure consumes none; a departed, cancelled cycle keeps its saved rolls | ARCH-RNG-002 |
| Chance | `max(1, base*(1+danger) − 2*crew_skill − 4*additional_crew)` per 10000; base: net 12, trap 8, weir 5, boat 20, ice 24 | GDD §5.4; already `fishing_driver.gd injury_per_10000` and shown before authorising (REQ-SET-055) |
| Outcome | net/trap/weir: −20 health, severity 1 "bite/cut"; boat/ice: −35 health, severity 2 EXPOSURE; each untreated severity-2 hour then −4 | GDD §5.4 |
| Incapacitated | a rescue job at the expedition's bank landing, cargo kept there | REQ-SET-054. The demo never reaches it: health floor 16, decision 0622 P1 |
| The care hook | `care_desk.gd hurt(i, kind, severity, loss, source)` | decision 0622 |

## What the documents leave open

1. **Who is hurt on a crewed cycle.** A boat has two seats (`fishery.gd
   _boat_catch`). §5.4 rolls once a cycle and does not say which crew member
   takes the injury.
   - a. The helm, the first seat. Its FISH level is what lets the boat go out
     (`HELM_MIN_LEVEL`).
   - b. The lower-skilled member.
   - c. A second draw picks one. This would break ARCH-RNG-002's
     "one hazard roll" draw count.
   - d. Both.
   
   **Recommended: (a).** It is deterministic, needs no extra draw, and the
   helm is the one most exposed.
2. **Bite or cut.** "severity 1 bite/cut" names two InjuryKinds (CUT = 1,
   BITE = 2) for net, trap and weir.
   - a. A BITE for net and trap, which are hands in the water where the pike
     and eels are; a CUT for the weir, which is timber and stakes.
   - b. Always BITE, as the Demo Lab's test injury already does (decision 0622).
   - c. Pick from the encounter: §5.4's "River pike and territorial eels are
     the encounter descriptions selected by habitat/day hash" give a bite; a
     gear mishap would be a cut, but no such encounter is named.
   
   **Recommended: (b).** It is the smallest choice, matches the Lab, and has
   one source of words.
3. **`crew_skill` and `additional_crew` on a boat.** The preview passes one
   fisher's level and 0 additional crew (`fishing_driver.gd _preview_gear`).
   §5.4's catch uses the group level, `floor(mean crew FISH levels)`
   (`fish_skills.gd group_level`). The natural reading is the group level, and
   `additional_crew = crew − 1`, so a boat of two lowers the chance by 4. The
   preview should then quote the same figure. This is a reading, not a gap,
   but it changes the number REQ-SET-055 shows before authorising, so it is
   listed here.

## The change, once ruled (about 60 lines plus tests)

- **`demo/water/fishing_driver.gd`**: a FISHING `Rng`, seeded from the world
  seed as `care_state.gd` seeds FORAGE, and `hazard_into(cycle, crew_skill,
  additional_crew, out) -> bool`. It draws the hazard roll (bound 10000) and
  then the rare-quality roll, which is discarded because every lot stays PLAIN
  (the driver's named blocker). That keeps ARCH-RNG-002's two draws per
  completed cycle. It answers whether the injury happens. Remove the "hazard
  roll" named blocker from the header.
- **`demo/fishery/fishery.gd complete_cycle`**: after `result.ok`, call the
  driver. On a hit, call a `hazard: Callable` hook,
  `(who, kind, severity, loss) -> bool`, with ruling 1's crew member and
  ruling 2's kind. Also post the note "<trip>: <name> was bitten (−20)". The
  fishery stays independent of the infirmary; unset, nothing is hurt.
- **`demo/demo_village.gd _build_care`** (after the fishery, as it is now): one
  line that sets the fishery's `hazard` to a function calling
  `_care.desk.hurt(i, kind, severity, loss, NoticesScript.SOURCE_WATER)`.
- **`fishing_driver.gd _preview_gear`**: the crew's group level and
  `additional_crew` (ruling 3).
- **Tests**:
  - the draw count is two per completed cycle and none for a refused one;
  - at a forced chance of 10000 the helm is hurt, at the table's figures with
    the right kind and severity;
  - a seeded run reproduces the same injuries;
  - nothing happens without the hook.

## Files a reader should open first

`demo/fishery/fishery.gd` (`complete_cycle`, `_fishing_done`, `_boat_catch`),
`demo/water/fishing_driver.gd` (`injury_per_10000`, the NAMED BLOCKERS header),
`demo/infirmary/care_desk.gd` (`hurt`), `demo/infirmary/care_state.gd` (the
FORAGE roll's `Rng`), and `scripts/core/rng.gd` (`STREAM_FISHING`).
