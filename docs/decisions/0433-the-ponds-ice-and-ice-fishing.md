# 0433 — The pond's ice: how it forms, when it is safe, and ice fishing through it
Date: 2026-10-01 · Status: Accepted

Water part B (0431). Numbered in this lane's 0431–0439 range.

## Decision

**The GDD never says when a lake freezes, how ice grows or how thick is safe.** REQ-SET-051 ("Where winter ice covers
a lake, the system shall permit only equipped ice-kit crews or a maintained ice-access station, while river/coast access
remains weather-dependent"), the ice kit's "Frozen lake; tier 2 clothing required", perch's "Ice access in winter",
whitefish's "Ice fishing favored" and §5.10's hard freeze ("lake ice access only") are all it states. So the ice is a
DEMO model (`fishery/pond_ice.gd`), in whole micrometres, driven each game hour by the one weather's day temperature:

| Rule | Value |
|---|---|
| Growth below 0 °C | 20 µm an hour per tenth of a degree: winter's −5.0 °C baseline (§5.10) a millimetre an hour; a hard freeze's −12.0 °C 2.4 mm |
| Melt above 0 °C | 40 µm an hour per tenth: +8.0 °C melts 3.2 mm an hour |
| FROZEN | from 10 mm: no boat leaves the jetty, no net or trap is set from the pond's bank, nobody swims or dives the pond |
| SAFE | from 60 mm -- about two and a half baseline winter days of cold: ice fishing only |
| THIN | frozen but under 60 mm: nobody is sent onto it; a WARNING incident `water:thin_ice` while it lasts |
| The stream | never freezes (it flows; REQ-SET-051 leaves river access to the weather) |

- **REQ-SET-051 lives in the fishery's rules**: `fishing_driver.gd set_lake_frozen` -- frozen, the lake's sites take
  only the ice kit (`ICE_COVERS_THE_LAKE`); open, never the ice kit (`LAKE_NOT_FROZEN`). The pond's ice tells the driver
  as it changes. The ice kit is now offered at the pond.
- **Ice fishing**: an ice kit and a tier-2 outfit from the locker (0435), a walk to the ice's edge (the pond's south bank,
  (27.5, 37.6)), the recheck there (the ice SAFE now), the cycle opened, a straight 3 m walk out over the ice to the hole
  at (27.4, 34.6), clear of the jetty, the berths and the raft
  (held on the ice: `water_hold`), §5.4's 90 WU, the catch, back to the edge and the locker, the catch to the stores. Ice
  that thins under an ice trip still fishing calls it off at once: the cycle released, the walker straight back (one
  already landing its catch is ashore and carries on).
- **Ice forming under open-water fishing**: a boat, net or trap fishing or soaking on the pond when it freezes is called
  off (the cycle released, no catch, no wear; the boat rows home; a soaking trap is lifted). A swimmer already in the
  pond when it freezes finishes its swim (only new swims and dives are refused) -- a known demo limit.
- **Nobody swims under ice**: `swim_motion.gd pond_frozen` / `iced_at`; `water_crossings.gd` offers no link across the
  frozen pond and refuses one at the bank (`ICE_COVERS_THE_WATER`); a swim or dive ordered onto it is refused.
- **Shown**: an ice sheet over the pond (white when safe, grey and see-through when thin) and the hole while an ice trip
  fishes (`fishery_view.gd`); on the **Water range** map layer (decision 0292) the pond paints SAFE ICE white or THIN ICE
  slate in place of its zones, with its own legend line and two swatches in the layer's key.

## Why

A thickness, not a flag: thin ice is the warned, preventable hazard DEC-040 asks for -- the player sees it, sees how
long it will take at this cold ("safe in about 32 game hours"), and nobody is sent onto it. Rejected: freezing the pond
by calendar (winter = frozen) -- the weather's cold spells and thaws would not show, and a hard freeze would mean
nothing.

## Consequences

The pond's ice is presentation state of the fishery, not a simulation store; a GDD ice rule, when one is written,
replaces these four numbers. Nothing walks on the stream's ice because there is none.

## Source

GDD §5.4 (ice kit row; REQ-SET-051), §5.10 (winter −5 °C; hard freeze −12 °C, "lake ice access only"); DEC-040 (warned,
preventable hazards); decisions 0196, 0231, 0292.
