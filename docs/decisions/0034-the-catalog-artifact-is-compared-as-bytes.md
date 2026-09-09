# 0034 — The catalog artifact is compared as bytes, not as a reparsed structure
Date: 2026-09-09 · Status: Accepted

## Decision

Three things, settled while writing the acceptance suite for `catalog_ids.gd`, which had been
implemented with no test at all:

1. **`parse_canonical()` is a strict JSON reader plus canonical-form checks. It is not the
   canonicity authority — the exact byte comparison in `verify_bytes()` is.** The reader refuses
   insignificant whitespace, unsorted keys, duplicate keys, non-canonical escapes, leading zeros
   and a leading plus. It nevertheless accepts `-0`, which is valid JSON for the integer 0 while
   `encode_int()` writes `0`. Keep both checks.
2. **A raw DEL (0x7f) refuses as `CATALOG_IDS_RAW_CONTROL_BYTE`, not as a non-ASCII byte.**
   `_check_byte_shape()` tested the 0x7e printable ceiling first, which made its DEL clause
   unreachable. The order is now DEL first.
3. **A `\uXXXX` escape's four characters are checked to be lowercase hex before `hex_to_int()`
   sees them**, and the refusal detail names that gate.

## Why

1. §10B requires that "loader verification compares exact canonical bytes, not platform
   pretty-printing". Replacing that comparison with a re-parse-and-compare would accept a document
   whose bytes differ from the ones the offset-72 digest covers — and every other refusal in the
   module would still fire, so nothing else would notice.
   `test_verification_compares_bytes_not_a_reparsed_structure` pins it with the `-0` document: it
   asserts the document parses to an identical mapping and that `compare_domains()` finds nothing
   wrong, then that verification refuses it anyway. Mutating that single line to `if false:` is
   killed by that test and by no other. The reader is hand-written, so the byte comparison is the
   only check that cannot have a gap of its own.
2. A dead branch is a branch no test can kill. The refusal outcome was already correct; only the
   code was wrong, and the clause is now live and asserted.
3. `String.hex_to_int()` raises an engine error on non-hex input and returns a number anyway, so a
   truncated `\u00` escape ran the following `":` through it and printed an `ERROR:` line on every
   malformed artifact. The refusal *code* is identical either way, so a code-only test cannot tell
   the two implementations apart — hence the detail assertion.

Rejected: tightening the reader to refuse `-0`. It would leave no document that parses equal but
differs in bytes, which would make the byte comparison untestable by construction and let a future
regression replace it unnoticed.

## Consequences

- The committed artifact's byte length (2588), SHA-256
  (`73d34d26af1f690261957ef27c0e5a14a5462d5d57b2f55a84b69e5fa900a3bd`), domain list (21) and row
  count (182) are pinned in `godot/test/test_catalog_ids.gd`. Moving them is an intentional
  ID/schema change that invalidates every save written against the old digest. Regenerate with
  `./tools/generate_catalog_ids.sh`, update the four constants, and say so.
- The encoder emits DEL literally (JSON requires escaping only below 0x20) while the reader
  refuses that byte. The asymmetry is safe only while `is_ascii_key()` keeps DEL out of every key
  and the ruleset string stays plain ASCII. Both are asserted; do not relax either without
  revisiting `_escape_code_point()`.
- Save wiring stays **blocked**: no save module exists, so the offset-72 digest and the section-2
  embedding attach to nothing. `Artifact.bytes`, `Artifact.digest`, `Artifact.row_count`,
  `save_section_payload()` and `verify_embedded()` are implemented and tested so a save module can
  embed them unchanged. No save writer is stubbed.
- `VerifyResult.proves_rules_unchanged` is always false, success included. Numerical definitions
  are the separate offset-40 rules hash, whose serializer does not exist yet either.

Two traps worth recording for anyone testing this area: Godot's `JSON.stringify()` sorts object
keys unless `sort_keys` is passed false, so a test that re-serialises a deliberately scrambled map
silently tests nothing; and `String.chr(0)` yields U+FFFD in Godot 4, so a NUL cannot be handed to
the encoder from GDScript at all — the `\u0000` case is exercised on the reader side only.

## Source

`docs/rulings/2026-09-09_ready06_open_item_answers.md` §10B (artifact contract, canonical bytes,
acceptance list); GDD §4.2 closing paragraph and BAL-CAT-001/002; ARCH-SAVE-001 header offsets 40
and 72, ARCH-SAVE-002 section 2; decision 0033 for the ASCII-key ID rule. Verified by
`godot/test/test_catalog_ids.gd` and by 34 single-line mutations of `catalog_ids.gd`, each run
alone and restored under a SHA-256 byte comparison.
