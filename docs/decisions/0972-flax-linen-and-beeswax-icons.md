# 0972 — Flax, linen and beeswax icons
Date: 2026-10-02 · Status: Accepted (Brendan's approval of the sheet; visual acceptance is still his, through
`tools/art_gate.py`)

A follow-up to art pass 3 ([decision 0971](0971-art-pass-3-preserving-brewing-digging-and-free-effects.md)). Numbered
0972, inside pass 3's 0971–0979; it was taken on no branch or worktree.

## Decision

On 2026-10-02 Brendan approved **an icon sheet for flax, linen and beeswax** in the 3D-render item-icon style. That is
the style he ruled for list item, food and dish icons, recorded in 0971. The coordinator delegated the call under
[decision 0961](0961-paid-generation-is-by-request-and-may-be-delegated-within-an-approved-cap.md), with a **hard cap
of 12 credits**.

- **One call:** a `nano-banana-2` image-to-image 3×3 sheet, conditioned on pass 1's `sheet_foods_a`, as pass 3's nine
  icons were. It cost **6 credits**, task `01a0fce6-bbf4-75f2-92a6-c99baf0c1a38`.
  - The balance was 104 before and 98 after.
  - It was on-style first time, so no redo was needed.
- **Nine cells for three goods.** The 3×3 cutter wants nine cells, and a sheet costs the same with three or nine. Each
  row is one good, in its main form and two alternates. The integrator uses the main key, or swaps in an alternate by
  key, with no new spend:

  | Good | Main key (cell) | Alternates (cell) |
  |---|---|---|
  | Flax | `item_flax`, a tied sheaf with seed bolls (0,0) | `item_flax_fibre`, combed fibre (1,0); `item_flax_seed`, a heap of seed (2,0) |
  | Linen | `item_linen`, a folded stack of undyed cloth (0,1) | `item_linen_bolt`, a tied bolt (1,1); `item_linen_thread`, a spool (2,1) |
  | Beeswax | `item_wax`, a block (0,2) | `item_wax_candles`, three candles (1,2); `item_wax_comb`, empty comb (2,2) |

- **The cut.** `python3 tools/make_art_pass3.py --icons` now reads its sheet per key. It cuts this sheet with pass 1's
  cutter into 128 px transparent icons in `godot/demo/assets/icons/`, as it does pass 3's nine. Their rows are in
  `godot/demo/assets/art_pass3_icons.json`, marked decision 0972.

What each one serves, and how to wire it, is in `docs/art-reference/art_pass3_mapping.md`, under "Flax, linen and
beeswax icons". The keys are proposed; wire by key, never by index. Nothing is wired into gameplay.

## Source

Brendan's approval, relayed by the coordinator on 2026-10-02. The ledger rows carry "decision 0972":
- `docs/art-reference/asset_library/meshy_tasks.jsonl`;
- `concept_prompts.json`;
- `files.json`.

The review sheets are `art3_check/icons_flax_dark.png` and `icons_flax_light.png` in the session scratchpad, at
native size and at 32 px.
