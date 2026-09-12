# 0082 — The look-development dimensions are bound in code, and the proportion comparison is built rather than approved
Date: 2026-09-11 · Status: Accepted for authoring; the creature proportion review it exists to enable is OPEN

## Decision

The 2026-09-11 [asset/save/movement ruling](../rulings/2026-09-11_asset_save_movement_blockers.md)
and [ART-GAP-R01–R05](../planning/asset_dimensions_and_budgets.md) are bound into three
places at once, so that a specification, a runnable check and a reviewable image cannot
drift from each other:

1. **`godot/assets/lookdev/lookdev_dimensions.gd`** carries the numbers as integer columns —
   thirty building exterior envelopes, five species comparison candidates, five static asset
   families, both hysteresis contracts, the crop and pile accounting, the aggregate
   environment sub-budgets and the GAP-09 material baseline.
2. **`godot/assets/lookdev/asset_import_validator.gd`** is the hierarchy-preserving import
   validator GAP-06 asks for, plus the GAP-03 envelope, GAP-04 budget and GAP-08 naming
   checks.
3. **`godot/assets/lookdev/proportion_comparison.gd`** builds the single comparison scene
   decision 0002 requires — mouse, mole, squirrel, otter and badger beside the same doorway,
   table and work surface, standing, walking, carrying and crouching — and
   `build_proportion_comparison.gd` measures it, writes its manifest and captures it at the
   sourced camera contract.

[`docs/art-reference/world_art_lookdev_brief.md`](../art-reference/world_art_lookdev_brief.md)
becomes revision 1.1 and resolves its own BLOCKED notes against the ruling.

**Fifteen of its eighteen entries are authoring-ready. Three — A2 mole, A3 squirrel,
A4 otter — have comparison briefs and are not.** Authoring-ready means the contracts a
modeller needs now exist; it does not mean exported, rendered, measured or qualified.

## Why these specific choices

### The authoritative unit stays 1/1024 m, and millimetres are a derived column

The brief asks for heights authored in **integer millimetres**. The project's authoritative
length unit is 1/1024 m (AGENTS.md), and the ruling states its numbers in that unit. Both
columns are therefore carried, with the unit column authoritative and the millimetre column
produced by half-up integer rounding.

They disagree on exactly one row. **`dirt_path` at 64 u is 62.5 mm**, which is not an integer
millimetre; the derived column records 63. That is a real contradiction between the ruling's
unit values and a millimetre authoring convention, and it is recorded rather than smoothed
over. `test_dirt_path_is_the_only_envelope_millimetres_cannot_express` asserts it **by name**,
so a later "tidy-up" that writes 63 into the authority column fails the suite instead of
silently changing a path's height by half a millimetre.

Every other envelope and every species candidate converts exactly.

### Pixel thresholds and roughness are stored as integers

GAP-05's promote/demote thresholds are 70.4 and 57.6 px and GAP-09's roughness targets are
0.9, 0.8, 0.85, 0.65 and 0.5. Both are presentation quantities, so a float would not violate
the integer-state rule — but both are *contract tables*, and a float table is a table that
can drift by rounding. They are stored as **integer tenths of a pixel** and **integer
permille**, and the tests recompute the hysteresis from its nominal rather than comparing a
constant to itself, so a transposed promote/demote pair fails.

### The comparison scene is hand-authored blockout geometry, and that is a limitation

Decision 0002 requires a visual comparison before bulk proportions are approved, and the
ruling names that comparison as the exact next art deliverable. No creature mesh exists for
four of the five species, and **this agent cannot spend generation credits** — it runs
unattended and cannot obtain consent, which `docs/design/paid_asset_process.md` reserves for
Brendan.

The scene is therefore built from hand-authored box volumes at the ruling's candidate
heights: the brief's own step 1.2, "blockout the body in simple volumes … before clothing".
It costs nothing and it can be rebuilt from a committed script.

**What that buys and what it does not.** It answers the **stature** half of the review —
whether 922 u reads correctly beside 1024 u, whether 2611 u sits correctly under a 3072 u
opening, whether one 640 u work surface can serve a mole and a badger. It does **not** answer
the **anatomy** half, because its bodies are boxes. Approving these captures approves the
proportions, not the modelling, and the per-species construction sheets remain separate
deliverables. Saying otherwise would convert a scale check into an art approval nobody gave.

If a reviewer decides the comparison genuinely needs generated art, the itemised request in
the brief's §9 is the one to approve, in session, by Brendan. It was not called.

### The landmark columns are review inputs, not contract values

The ruling specifies the measurement convention and requires crown, eye and shoulder heights
to be *recorded*. It does not supply them. The per-species permille columns in
`proportion_comparison.gd` are read off the DEC-036 authorized references named per row and
are labelled `PROPOSED_FOR_REVIEW`. A reviewer can reject any of them without touching a
single ruling number. This is the line between "recording what the deliverable is required to
record" and "inventing a constant the specification left open"; the second is forbidden and
did not happen.

### The cap and opening part names are a blocker, not a gap to fill

GAP-06 lists "opening/cap geometry" as an addressable part of a managed building and does not
name it. The validator requires the ten parts that *are* named, **accepts** any further part,
and records each unnamed extra as a note rather than enforcing an invented `cap_*` convention.
The blocker is named in the file, in the brief and here. Close it before a reviewer reads
those notes as approval.

### Yaw is captured at 45° and 225°, and that is a finding

Residents face **−Z**. `ui_ux_controls.md` §6 sets the *initial* orbit yaw to 45°, which puts
the camera in the +X/+Z octant — behind them. Orbit yaw is unrestricted, so 225° is an equally
legal camera, and the captures use both. The pair is also the facing check §2.1 says no script
can make: a model that is upright, correctly scaled and facing backwards passes every
automated check in `prep_unit.py`.

### The stockpile reading in revision 1.0 was wrong and is corrected

Revision 1.0's D3 entry treated GDD §5.9's "Ground piles hold at most 400000 g each and create
adjacent passable tiles in N,E,S,W breadth-first order when a pile is full" as a property of
the **open stockpile building**, and specified a per-tile spilling pile module for it.

It is not. That sentence belongs to the temporary ground piles REQ-SET-110 allows when storage
capacity is insufficient. An 8 × 8 m open stockpile with its 400000 g main container is **one
container**, not sixteen independent 400000 g piles, and there is no automatic per-tile
capacity expansion. Modelling the revision 1.0 reading would have shown the player sixteen
times the storage that exists. The visual now binds to the actual container, with fill variants
at ≤ 1/3, ≤ 2/3 and > 2/3 of its real capacity.

## Consequences

- A modeller can start B1, B2, B3, C1–C4 and D1–D6 today against real ceilings.
- **No bulk creature generation starts**, for any species, until Brendan rules on the
  comparison captures. A2, A3 and A4 remain comparison-brief entries.
- `prep_unit.py` is unchanged and byte-untouched. Multi-part buildings bypass it; the
  validator is the check that they did.
- The render-pixel, triangle and memory numbers are **design decisions, not measurements**.
  GAP-10 — Windows / minimum-hardware qualification — is untouched, and Mac evidence
  establishes nothing about the specified minimum GPU.
- Captures require a real rendering device. A `--headless` Godot run uses the dummy renderer
  and `ViewportTexture.get_image()` returns null; the builder records that as an explicit
  refusal per view rather than writing an empty file or claiming a capture it did not take.
- The ruling's recorded `source_lookdev_brief.sha256` in
  `docs/planning/asset_dimensions_and_budgets.json` is the digest of **revision 1.0**, the
  revision Astra reviewed. It is left untouched, because it is a historical review record and
  not a checksum of the current file.

## Source

`docs/rulings/2026-09-11_asset_save_movement_blockers.md`;
`docs/planning/asset_dimensions_and_budgets.md` and its JSON;
`docs/art-reference/world_art_lookdev_brief.md` revision 1.0 and decisions 0002, 0079 and 0080;
`docs/ui_ux_controls.md` §6; `docs/game_gdd.md` §5.1, §5.9, §5.11 and REQ-SET-110;
`docs/crowd_rendering_architecture.md` §2.7, §5 and §9; `godot/data/catalog_ids.json`;
`.claude/skills/asset-pipeline/scripts/prep_unit.py`; and direct inspection of
`docs/art-reference/visuals/grounded_expressive_rts_example_v1.png` (DEC-038) and IMG-25 at
`[413,247,1304,565)` of 1366×1026, plus IMG-07, IMG-08, IMG-12 and IMG-18 at their manifest
regions, under DEC-036.
