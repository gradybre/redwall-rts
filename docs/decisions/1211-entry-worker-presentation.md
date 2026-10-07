# 1211 — Entry worker presentation: the stone source, the row program and the surface hand-off alert

Date: 2026-10-06 · Status: Accepted; step 1 implemented

ADR 1197 G8 (remainder) and the presentation half of G5. It builds on ADR 1201 (per-source presentation) and
ADR 1206 (native stone image v9 as runtime source 3). Presentation only: nothing here advances a simulation clock or
grants work, contact or movement.

## Step 1 — the stone image is the fourth presentation source

| Piece | Change |
|---|---|
| `godot/demo/cast/underground_content_set.gd` | `MAX_SOURCES` 3 → **4**. Nothing else changes: each slot still holds one exact-sha image inside the one declared budget. |
| `godot/scripts/core/underground_session.gd` | `STONE_ACTOR_PATH`, `STONE_ACTOR_SHA` (`49ff3018…`, equal to `Pins.STONE_SOURCE_SHA`), `STONE_PRESENTATION_BYTES` = 7,285,004, and `PRESENTATION_SET_BYTES` now sums four images. |
| `godot/data/underground/mole-worker/mole_presentation.gd` | `SOURCE_STONE` = 3, `STONE_MASKS` (v9 `plan.json`: mask 3 on all ten clips), `load_sources(sources, include_haul, include_stone)` over `load_sources_within(…, budget, …)`, and `stone_material()`. |
| `godot/data/underground/mole-worker/mole_haul_program.gd` | The clip ordinals of both haul images (0–7 shared; v8 8–11 stand/walk/enter_haul/leave_haul; v9 8–9 enter_haul_stone/leave_haul_stone). |

**The stone image needs the haul image.** v9 holds no stand or walk; the tool-free stand and walk (rows 30/31)
are v8's, and v9's `enter_haul_stone`@0 is v8's `stand`@8 (the ADR 1206 cross-image join). Asking for stone without
haul refuses `MOLE_PRESENTATION_INPUT`.

**The stone part binds the tunnel dressing's own lump.** `Content.mesh_fingerprint(bore_dressing.gd::stone_mesh(),
0, 70, 1)` is exactly v9's part-1 hash (`e9c10ccc…`), so the Actor binds the shared factory mesh with no copy.

**Stone material (no new art).** The dressing's lump material colours each MultiMesh instance
(`vertex_color_use_as_albedo`); a single Actor part has no instance colour, so v9's replay drew the lump white.
`stone_material()` duplicates that same material (roughness 0.9, back-face culling) and fixes the albedo at the
dressing's own `STONE_COLOUR` with vertex colour off. The dressing's MultiMesh material is untouched, and the derived
material passes `Actor._material_error` (no next pass, grow or billboard). It is bound as a material override on part
1 only; the body keeps its original material.

### Budget and memory census

| Source | Image | Declared peak (B) |
|---|---|---|
| 0 actor | `install-program-compile-v3` (`adc61764…`) | 7,141,920 |
| 1 assembly | `qualified-assembly-v1/compiled-3` (`b94d676e…`) | 6,628,488 |
| 2 wood haul | `native-program-v8` (`cc854271…`) | 7,486,168 |
| 3 stone haul | `native-program-v9` (`49ff3018…`) | 7,285,004 |
| **`PRESENTATION_SET_BYTES`** | plain sum, nothing shared | **28,541,580** (was 21,256,576) |

Each figure is that image's exact `Content.required_peak_bytes()` (retained palette, the larger of a second palette
copy or the 17,172-vertex mesh pass, tables, and the 2 MiB control reserve). It is a declared upper bound, not a
measurement. Retained palettes: 647,752 + 134,848 + 992,096 + 791,028 = 2,565,724 B. This is presentation memory,
outside the 100 MB simulation-owned gate (REQ-SET-163); simulation-owned memory changes by **0 B** in this ADR.
`tools/underground_memory_budget.py` is not changed here.

Refusals are exact: one byte short of the set refuses the stone image with `CONTENT_SET_BUDGET` and keeps the
other three admitted; a reserve below the exact peak refuses `ACTOR_CONTENT_PRESENTATION_RESERVE`.

## Tests

`godot/test/test_mole_presentation.gd` (step 1): four pinned images at their exact peaks and the new set sum; the
stone digest equals the catalog's; stone clip masks and spans; stone optional and dependent on haul; the dressing
lump's exact fingerprint and the derived material; stone clips shown only on the stone Actor; the one-byte-short
budget refusal.
