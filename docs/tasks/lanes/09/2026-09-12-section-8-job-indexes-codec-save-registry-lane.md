# 2026-09-12 — §8 JOB_INDEXES codec (save/registry lane)

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


`godot/scripts/core/save_section_job_indexes.gd` and
`godot/test/test_save_section_job_indexes.gd` are new; see
[decision 0120](../decisions/0120-section-8-freezes-its-payload-and-refuses-to-invent-a-primary-count.md).
Nothing outside those two files, this subsection and that record was touched.

- [x] **§8's wire body is frozen for the 29 declared fields.** SAVE-LAYOUT-R01's
      owner wrapper (`store_count:u32`=1, `owner_key`="job_planner",
      `owner_schema_version:u32`=1, `primary_count:u64`, `payload_byte_length:u64`)
      followed by 29 × (`element_count:u64` + column values), column-major, in the
      registry artifact's declared ordinal order. 39 + 232 + 362880 = **363151 bytes**;
      canonical hash contribution **362880 bytes**, which excludes the wrapper and the
      29 element counts.
- [x] **Each of the five child extents is validated from the owning schema**, not from
      whichever column is encoded first: 8192 service rows (ordinals 0–10), 4096 cycle
      rows (11–12), 128 zone rows (13–15), 640 demand rows (16–20), 1024 hive rows
      (21–28). Deriving either the encoded or the decoded `element_count` from ordinal
      0's extent kills 8 and 7 tests respectively.
- [x] **Validate then commit.** A full-length section carrying an invalid value leaves
      the caller's Record byte-identical, asserted by comparing all 29 columns. The
      extent gate catches truncation long before anything is read, so the
      commit-then-validate mutant is exercised with a full-length invalid section.
- [x] **26 mutants run, one per Godot invocation**, production file `shasum -a 256`
      byte-compared against a pristine copy after each restore. 25 killed; one
      (`extent_refusal`'s redundant `bytes.size() < SECTION_BYTES` clause) is an
      equivalent mutant, and disabling the gate outright kills one test. One real
      coverage hole was found and closed this way: the u8 branch of the free-row
      hygiene check had no test until `_requires_water` and `_gate_reason` residue
      cases were added.

- [ ] **BLOCKER J1 — §8's `primary_count` value is unruled and is not invented here.**
      `job_planner` owns three independent owner capacities (4096 plots, 128
      designations, 1024 hives) plus two derived child tables, and REG-R01's artifact
      declares no `primary_count` for it. `encode_section()` takes the count as a
      required argument, `decode_section_into()` takes the value it must match, and
      `production_write_refusal()` refuses `SAVE_JOB_PRIMARY_COUNT_UNRULED` so no
      section 8 block reaches a real save file until a ruling supplies the number.
      Only those eight bytes wait; the other 363143 are frozen.
- [ ] **BLOCKER J2 — `job_planner.gd` publishes no bulk column API**, so there is no
      live-store round trip yet. Its public readers are gated (a FREE row and a
      non-daily operation both refuse, a Job answers only while PENDING, the sowing
      readers address only an owner's SOW row), so a capture built on them would have
      to synthesise values it cannot read. `capture_into()` and `apply()` refuse
      `SAVE_JOB_STORE_NO_COLUMN_API` and name the validating, transactional
      `copy_job_index_columns_into()` / `restore_job_index_columns()` pair the planner
      owner must publish — the same resolution decision 0105 gave §3 and RESTORE-R01
      gave the clock. The exact signature is that owner's to choose.
- [ ] **Registry rows owed, reported and not applied** (the files are other owners'):
      `docs/persistence_state_registry.md` needs a
      `### \`godot/scripts/core/save_section_job_indexes.gd\`` section with one
      category-3 codec row and one category-3 scratch row (`Record` is 362880 bytes of
      bounded codec scratch on ARCH-SAVE-003's cold path, holding no module-level
      `var` and adding no authoritative column), and `docs/systems_architecture.md`'s
      ledger needs the same classification. Until that section exists
      **`state_registry_coverage.py` fails its C1 check** for the new module; every
      other listed validator passes.
