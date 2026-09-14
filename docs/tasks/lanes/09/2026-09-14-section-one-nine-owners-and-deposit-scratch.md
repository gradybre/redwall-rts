# SAVE-S1-OWNERS — section 1's nine owners, and the deposit scratch correction — 2026-09-14

Task: 09_persistence_replay_reliability.md
Date: 2026-09-14
Ruling: [R-WORLD-S1-001](../../../rulings/2026-09-14_world_section_owner_encoders.md)
Decision: [0142](../../../decisions/0142-section-one-carries-nine-owners-and-three-deposit-arrays-are-scratch.md)

Astra cycle 1, work item SAVE-S1-OWNERS. One coordinated activation: seven owners gained
encoders and the three `resource_nodes` deposit arrays left the save in the same change,
because a tree where the registry says "scratch" and the encoder still writes it is broken.

## What landed

- [x] `godot/scripts/core/save_section_01.gd` — the only producer of a section 1. Nine owners in
      strict ASCII key order, `store_count = 9`, section length **3752768**, descriptor
      `row_count` **344067** as the checked sum of the nine primary counts, first body offset
      **1216**, section 2 at **3753984**. Seven ordinary payloads use `element_count:u64` plus
      `element_count * type_width` value bytes per field; `entity_directory` (4 bytes) and
      `world_runtime` (80 bytes) keep their existing fixed formats with no count prefixes.
- [x] Every wrapper item and every field is read at a COMPILED ABSOLUTE OFFSET and the declared
      extent is COMPARED against it. Nothing advances a cursor by what it just read. This is the
      §7/§9 symmetric-blindness defect written out of the design rather than tested around;
      `test_save_section_01.gd` reads the wire with `PackedByteArray.decode_*` at literals
      transcribed from the ruling, and the swapped-owner case uses `forage`/`weather` precisely
      because both keys are seven and six bytes of the same shape, so a swap leaves every length
      in the file self-consistent.
- [x] Payloads are assembled with native `Packed*Array.to_byte_array()` and
      `PackedByteArray.append_array()`, gated by `little_endian_refusal()`. A per-value writer
      loop over 3.75 MB is roughly a million GDScript calls; the native conversion is a raw
      memory copy, so its endianness is proved rather than assumed.
- [x] Seven owner modules gained `copy_section_1_columns_into()`, `section_1_local_refusal()`,
      `section_1_cross_check_refusal()` and `restore_section_1_columns()`. Every domain rule is
      enforced by the store that owns it — `farming.is_history_pair_consistent()`,
      `weather._is_eligible()`, `buildings._footprint_fits()` — never by a second copy in the
      codec. Weather's temperature and rain bounds are DERIVED by walking §5.10's own tables and
      then pinned against the ruling's -120..300 and 0..3200.
- [x] Restore validates every owner to completion BEFORE publishing any of them, and publishes
      through no gameplay mutator: nothing is placed, created, cleared, generated or drawn.
      `spatial_world` installs stored legality and rebuilds only `_walkable_count` and
      `_clearance`; calling `rebuild_static_legality()` would restore the AUTHORED answer and
      silently discard every `override_static_legality()` edit the saved world had made.
- [x] The three deposit arrays are category-3 scratch in `docs/persistence_state_registry.md`,
      gone from `canonical_state_registry.json`, and `source_contracts` key C007 is deleted
      because nothing else cites it. `(1, resource_nodes)` takes owner schema **2**; section 1
      takes schema **3**; the other eight owner versions stay 1 and the section-4 block the same
      module owns is untouched.
- [x] Active rules identity CHANGED with the activation: `registry_id`
      `RWL-CANONICAL-REGISTRY-2026-09-12-1` → `RWL-CANONICAL-REGISTRY-2026-09-14-2`,
      `registry_version` 1 → 2, both compiled into `canonical_state_hash.gd` by
      `tools/generate_canonical_state_table.py` and pinned in `test_canonical_state_hash.gd`
      against LITERALS held outside the JSON, so no self-referential check can pass an identity
      that quietly stayed put.
- [x] `save_section_world_runtime.gd`'s two-block composer is renamed
      `encode_development_section()`; `encode_section()` refuses by name. Its existing wrapper,
      ordering and tiling tests keep working against the development fixture — none was deleted
      or weakened — and one new test asserts the refusal.

## Counts, and why they moved

`record_count` **599 → 596** and `packed_source_field_count` **553 → 550**. Three declarations
leave the canonical registry, so three `hash: true` records leave the first; the same three leave
`persistence_state_registry.md`'s category-1 set, so three persisted packed columns leave the
second. Both are snapshot pins REG-R01 requires to track the declarations, and both carry that
reason beside the number in `validate_save_registry_handoff.py` and `test_canonical_state_hash.gd`.
A previous lane froze such a pin and it then refused every new store; freezing is the failure
mode, not moving.

Section 1 itself goes from 47 declared stored fields and 39 canonical records to **44** and **36**.

## Not done, and not claimed

- **BLOCKER W1 stands.** `sim_clock.gd` has no side-effect-free writer for the completed tick,
  the debt or the six counters, so `world_runtime` is captured, validated and carried but never
  published. The D2 cursor is likewise installed with section 3.
- **`farming._tile_orchard_row` has no population writer anywhere.** R-WORLD-S1-001 §6 names this
  as an integration prerequisite. The field is bounded, round-tripped and retained, and
  `section_1_cross_check_refusal()` deliberately asserts NO orchard inverse: rubber-stamping an
  all-null column beside live orchards and reconstructing over a contradictory one are both
  forbidden, and there is no third option until a writer exists.
- The 44-byte provenance prefix's VALUES still belong to the map/scenario producer
  (SAVE-R09-003). None is invented; a caller that sets nothing saves zeros.
- No release-save completeness. Thirteen sections remain unwritten and the next-tick parity
  gate (ARCH-SAVE-006) is untouched by this lane.
