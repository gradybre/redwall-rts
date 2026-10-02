# 0621 — Herbalist and infirmary (demo feature #26): what is adopted, what the demo has, what can hurt
Date: 2026-10-01 · Status: Accepted (findings; the build is decision 0622)

## Decision
The adopted rules are sufficient to build a NON-FATAL injury-and-care loop in the live demo, so the
feature proceeds to Phase 2 (decision 0622). The only rule the demo cannot carry as written is death
at health 0 (REQ-SET-016) — the brief's hard limit forbids death, and the demo already keeps a
non-fatal safety net for its water hazards (decisions 0196, 0231) — so the build stops health at a
floor (PROPOSAL P1 in 0622). Illness is not built: no illness model is adopted.

## What is adopted (read, with sources)

| Rule | Where | Used? |
|---|---|---|
| `Injury` row: kind, severity, untreated_hours, care_progress_mwu, rescuer; one aggregate per resident, worse severity replaces | GDD §4.2; HAZ-004 merge/dedupe | Yes, through `scripts/core/injury.gd` (decision 0109) |
| `InjuryKind` NONE 0, CUT 1, BITE 2, FALL 3, EXPOSURE 4, EXHAUSTION 5; `ResidentStatus` INJURED 2 / INCAPACITATED 3; `JobKind` HEAL 11; `RoomType` INFIRMARY 5 | GDD §4.3 | Yes |
| Untreated drain: severity 1 −1 health/h and no hazardous work; severity 2 −4 health/h | REQ-SET-172 | Yes (`needs.gd` single health rate) |
| Treatment: herb 1 + cloth 0.5, 60 WU of HEAL, clears the injury, +10 health (cap 100), at a field landing point or a bed | REQ-SET-173; balance HEAL row | Yes |
| Recovery: +2 health/h while health<100, hunger and rest ≥4000 and no untreated serious injury; +4/h in an infirmary | REQ-SET-017 | Yes |
| Reduced work: health factor 600 (<40), 850 (40–69), 1000 (≥70) in the work factor | GDD §5.2 | Yes (the work-pace hook) |
| Status: DEAD 0, INCAPACITATED 1–15, INJURED 16–99 with an injury | GDD §5.2 | Yes, but the floor keeps the demo at ≥16 |
| Incapacitated → rescue carried to a bed at 50% speed, then treatment | REQ-SET-171, HAZ-004 | Not reached (floor 16) |
| Infirmary: 8×8, wood 40 stone 30 cloth 12, 1000 WU, Healer 2, 8 patient beds, M1 | GDD §5.9 | Its room rule only (below) |
| Infirmary room valid with ≥3 tiles/bed, ≥1 bed, ≥1 shelf, heated | GDD §5.9 room validity | Yes, mapped onto a burrow home (0622) |
| Herb: forage patch kind 3, K 160 U, base 8 WU/U, regrowth 80/1000, seasons 1000/1200/600/200; work per U `ceil(base*10^6/((1000+40L)(1000+100d)))`; floors 20%/5% K; initial stock 0.8 K | GDD §5.5, §5.1; `scripts/core/forage.gd` constants | Yes |
| Starting stocks herb 12 U, cloth 24 U | GDD §5.1 initial inventory | Yes (the demo's care supplies) |
| Memory `untreated_injury` −800 | GDD §5.2 | No: the demo has no mood |
| Last resident self-treatment at 120 WU | REQ-SET-174 | No: nine residents |

## Injury sources the GDD adopts, and which the demo has

| Source | Adopted rule | In the demo |
|---|---|---|
| Exhaustion in the water | HAZ-003: rest 0 while in water → EXHAUSTION sev 1, 0 immediate loss; re-arms at rest 4000 on safe support | **Already reached** (`waterplay/swim_state.gd` EXHAUSTED; the Lab's Cramp), but recorded "unhurt". Now an injury. |
| Airless below | HAZ-002: transition to airless → EXPOSURE sev 2, 0 immediate loss, −125 health/h while airless | **Already reached** (a held victim below whose air runs out). Now an injury. |
| Fishing hazard roll | §5.4/REQ-SET-053: per completed cycle, chance `max(1, base*(1+danger) − 2*skill − 4*extra crew)`/10000; net/trap: −20, sev 1 BITE/CUT; boat/ice: −35, sev 2 EXPOSURE | Risk shown, never rolled (decision 0431: no FISHING stream). Not wired here: it needs a hook inside the fishery owner's cycle completion (0622 lists it for the fishery owner). |
| Foraging | REQ-SET-068: per completed 60 WU at natural danger ≥1, chance `max(1, 8*danger − FORAGE)`/10000; −10, sev 1 | No foraging existed. The new herb gathering rolls it (danger 1: inside 64 m of the hall, no lookout). |
| Falls | HAZ-003: only from DECLARED UNPROTECTED CLIMBS, `min(40, ceil(D*8/1024))` | None: the demo has no climbing connections. |
| Falls while digging / tunnel collapse | HAZ-001: supported dry excavation adds no hazard; tunnels never collapse, flood or injure | None. The demo's own unbraced-tunnel floods and collapses hurt no one (0196 item 46) and stay so. |
| Storms | §5.10 heavy rain/storm: −3 °C, rain, boats disabled, outdoor work ×0.80 — no injury | None. |
| Wildlife | §5.9: "Emit an advisory; do not injure residents" | None. |
| Generic work accidents | None adopted (tool wear only) | None. |
| Cold exposure | REQ-SET-018: health loss, no Injury row | Not here: the winter-fuel agent's Chilled status. The private needs row keeps the NEUTRAL cold environment, so this feature adds no cold damage and cannot double count it. |
| Illness | REQ-SET-150 names illness; CHILL and the family illnesses are DRAFT (systems_architecture ARCH-SYS-017b) | **Not built**, per the brief. |

## What the demo had before this feature
Nothing of health: a presentation-only cast of nine (decision 0196) with hunger (kitchen
`nourishment.gd`, 0..10000) and stamina (`swim_state.gd` rest, 0..10000); a non-fatal water safety net
("washed ashore", unhurt); no HEAL skill, no herbs, no cloth, no infirmary. `scripts/core/injury.gd` and
`needs.gd` exist with no scheduler binding.

## Source
docs/game_gdd.md §4.2, §4.3, §5.1, §5.2 (REQ-SET-014..019), §5.4, §5.5 (REQ-SET-066..069), §5.9, §5.10,
§7 (REQ-SET-171..174); docs/underground_economy_hazard_amendment.md HAZ-001..004;
docs/gameplay_balance.md HEAL row; docs/setting_decisions.md DEC-033, DEC-040; decisions 0109, 0196,
0231, 0431.
