# Independent source review — Work owner 16 validation
2026-09-20. Scope: `work.gd` (`columns_refusal`, `_handle_is_valid`) and `save_owner_work.gd`,
read against WORK-S4-VALIDATE-R01 v1, ADR 0175 and the compiled section-4 schema. Verdict:
no contradiction found with the accepted contract; the two files are fit to merge subject to
the outstanding evidence below. This is a reading, not a run.
## Independently re-derived
- Ordinal 2 is provably `_memory_total`. `OWNER_FIELD_BEGIN[16] = 280`; `FIELD_KEYS[280..288]`,
  `FIELD_TYPES` (2×8 then 0) and `FIELD_COUNTS` (512, 6144, 512×7) match the contract, and gate 4
  pins every key/type/extent by ordinal before any column is read. Ordinals 0..7 are all i32, so
  `storage_index()` is the identity on that bucket and `i32_columns[2]` is the memory column,
  `u8_columns[0]` the broken column. That structural derivation — not a test — is the honest
  warrant for excluding the correctly sized memory-zero substitution, which is genuinely
  equivalent while every int32 value is legal.
- Block arithmetic checks out: 512×4×7 + 6144×4 + 512 = 39424 value bytes, 39500 payload,
  39528 block, 12892567 + 39528 = 12932095 = owner 17's compiled offset.
- Gate order matches the contract exactly, and each gate is a full-extent loop, so a fault at
  row 511 under an earlier gate beats row 0 under a later one. `_handle_is_valid` accepts only
  `(-1,0)` or bounded slot with positive generation, using typed-store capacities (16384/8192),
  not directory bounds; both malformed null halves refuse. Broken uses `> 1` on unsigned bytes,
  so no negative case exists. Memory has no value gate at any row, which REQ-SET-020 requires.
- The predicate constructs nothing, calls no collaborator, sorts nothing and allocates no packed
  scratch; the bridge forwards schema and owner-shape refusals unchanged and returns stored
  columns unduplicated, so the caller image stays the existing 39424 bytes.
## Observed evidence limits
The 21 required mutants completed with real assertion kills across 23 valid runs (baseline and
restored controls passing); the 8 metadata bypasses were killed. The full suite is still running
and there is no CI result yet, so bridge import under exact head and full-suite parity are
unconfirmed. Native and wrapper overhead beside the 39424 caller bytes is unmeasured.

## Material gaps, no blocker

1. The direct static predicate is unpinned: only the bridge compares capacities and denominators
   to contract literals, so a future direct caller gains no source guard.
2. Gate 4 compares compiled metadata to literals; it is not publication-table parity. The
   independent schema generator and source-capacity audit remain required.
3. No duplicate lot/job rule here, by design. Saved Work/Gear/Jobs/Inventory and resident
   identity, claim coherence, bulk capture/restore and the derived bound-tool count stay
   downstream under SEMANTICS and OWNER-BINDINGS.
4. Source pins must never be described as an executable value-domain kill; the reviewed files
   do not do so.
