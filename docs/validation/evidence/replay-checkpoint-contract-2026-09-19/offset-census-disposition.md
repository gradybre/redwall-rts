# Header-dependent offset census

The retained before census searches every GDScript/Python source and test under
godot/scripts, godot/test, tools and docs/validation for whole-number256/1216/
3753984/216/224 and the old checkpoint symbols. It found371 lines. Historical raw
evidence, assets and literary source records are excluded: they are not runtime
header consumers and are preserved verbatim. The source regex also matches SHA-256,
so a match is not itself a header dependency.

Active changes:
- save_header and test_save_header: current header/table264, low216/reserved220/
  high224/body-digest232, first body1224; remove scalar replay_sequence/old offset.
  CRC-32 still has256 entries. New adversarial tests deliberately retain old256
  and version1 as refused input fixtures.
- save_section_01 and its test: first file offset1224 and next section3753992.
  Body length3752768 and every section-relative field/wrapper offset are unchanged.
- canonical_state_hash: only its explanatory body-digest start comment moves264;
  canonical field declarations/bytes and generator output are unchanged.
- validate_blocker_package: current header/table arithmetic moves264+960=1224.
- validate_cycle01_handoff: retains its historical Cycle1 manifest proof using256/
  3753984 and adds the current264/3753992 relocation proof. It validates a historical
  target manifest, not current runtime offsets; that distinction is now explicit.

Retained independent fixtures:
- test_save_section_directory and test_save_section_navigation use1216 as an
  arbitrary padded-buffer offset for standalone section decoders. They assemble
  no header/table and require the decoder to work at any supplied valid offset.
  Their1216 is intentionally retained: refusing that offset would be a regression.
- The navigation descriptor-row-count test uses descriptor.offset256 while checking
  only encoded row_count and the standalone descriptor codec. It does not claim a
  structurally valid whole file; range validation remains with the header table tests.
- Other save modules use256 for ASCII owner-key caps, scheduler/route capacities,
  SHA-256 names or literal hostile field values. These meanings do not change.

Other census matches belong to living population/item limits, route descriptors,
spatial half-cell offsets, UI dimensions, shelf bit masks, packed owner budgets,
benchmark populations, validation counterexamples and SHA-256 prose. None names
an outer-header field or derives a file-section position. No blanket numeric
replacement was used. Relevant architecture and ruling tables were separately
updated or explicitly annotated with current-versus-historical provenance.

WorldRuntime's unchanged80-byte body declares seed/seeded, completed tick, debt,
requested speed, pause mask and six counters: no command sequence field exists.
The old WorldRuntime architecture allowance remains marked historical reserved
budget, with no live duplicate owner or claimed measured memory reduction.
