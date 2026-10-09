# 1235 — Fast settlement saves: whole-column proofs, native CRC and worker-thread hashing
Date: 2026-10-08 · Status: Accepted

## Decision

The settlement save and load keep every byte of the file, every refusal and every proof that ADR 1222 built, and
become fast enough to autosave in play. **Target, on this Mac at the generated test settlement:** a save under 1 s
and a load under 2 s, the load measured the way the game does it (over a live world, so including ARCH-SAVE-004's
rollback checkpoint).

| Measured (generated settlement, 56,989,480-byte file, this Mac, 2026-10-08) | Before | After |
|---|---:|---:|
| `save_slot()` (capture, section 15, encode, atomic write) | about 33 s | 0.65-0.68 s |
| `load_slot()` into an empty settlement | about 66 s | 1.02-1.08 s |
| `load_slot()` over the live world (rollback checkpoint written first) | about 66 s + a 33 s checkpoint save (not timed together) | 1.67-1.76 s |

The after-numbers were taken with other lanes running (load average 6-9); `prof_e2e`-style harness, three rounds.
The file is byte-identical: the format, its versions and DEC-055's "no compression" are unchanged.

## Why: where the time was

Profiled with `Time.get_ticks_usec()` per section, per owner and per step:

- **Section 7 validation, about 20 s of a save and 30 s of a load.** `save_section_inventories.gd` walks every row of
  six tables (101,376 containers, 16,384 lots, ...) a cell at a time, allocating a `Refusal` per check; a save ran it
  twice on the same record (capture and encode) and a load three times (apply and the two of the proving recapture).
- **The section 15 walk, about 12 s per pass.** `canonical_state_hash.gd` emitted ~50 MB of values one integer at
  a time through the codec's checked writers.
- **Construction and Buildings column predicates, 0.3 s per pass**, and Inventory's canonical partition, inactive and
  projection loops, about 0.15 s per pass; each runs several times per load.
- **CRC-32, about 1 s per pass** (a byte loop over 57 MB), on encode, decode and `write_atomic()`'s re-decode.
- **The proving recapture** repeated the whole save, section 15 included.

## What changed

1. **Whole-column proofs** (`column_proofs.gd`, `save_inventories_proof.gd`). A validator first asks a proof whether
   its row walk would accept; only a block the proof cannot vouch for is walked, so **every refusal (code, detail,
   first row) is the row walk's own**. A proof is too strict at worst, never too lax:
   - `rows_proven()`: for a row-local validator (its verdict on a row reads only that row of the listed columns),
     identical rows get identical verdicts. It judges the last row, every row that differs from it in any column
     (found by native `slice().count()` halving), and nothing else. Used for Construction's `columns_refusal()` and
     `restore_columns()` (extension, split and ledger walks; the ledger's four cells per row through
     `strided_deviant_rows()`) and Buildings' `columns_refusal()`. Each call site lists the gates' columns; the
     gates were checked to read nothing else (`[row]` only, plus constant tables).
   - Section 7 and Inventory: occupancy bytes are 0/1 (`count()`), free rows carry their canonical blank in every
     column (fill-and-compare), generations are in range (a sorted copy's minimum), and with no retired slot each
     free stack's prefix is exactly the set of non-live slots (sorted comparison). Each live row, and one
     representative free row, still runs its row validator.
2. **Bulk section 15** (`canonical_state_hash.gd`). Each column is one little-endian run folded into SHA-256
   (`Emitter.put_bulk()`); `to_byte_array()` produces the very bytes the per-value writers did (the pinned fixture
   stream and digest are unchanged). Range refusals keep their first index. A host that is not little-endian takes the
   per-value path.
3. **Native CRC-32** (`save_header.gd`). A gzip member's trailer is the CRC-32/ISO-HDLC of its input (RFC 1952), so
   `crc32_of()` reads it from `PackedByteArray.compress(GZIP)`'s output (100 ms for a whole save instead of 1 s) and
   checks the trailer's length field; the byte loop stays as `crc32_by_bytes()`, the reference the test compares
   against, and as the fallback.
4. **Worker-thread hashing** (`save_integrity_jobs.gd`). The section CRCs and the body SHA-256 are pure functions of
   immutable bytes. On a save the CRCs of sections 1-14 fold while the main thread walks section 15; on a load the
   CRCs are collected first (about 0.1 s, so no decoder ever sees a section its CRC refuses) and the body digest
   folds while the main thread decodes the sections and recomputes section 15 over them.
   Their verdicts are judged afterwards in the sequential order, and nothing is published before; the decoders are
   bound to refuse hostile bytes, so decoding a file a CRC would have refused costs only time. No simulation state is
   touched off the main thread, and the save still captures entirely at the quiescent boundary.
5. **The atomic write** (`SaveFile.write_encoded_atomic()`): for bytes `encode_file()` has just produced,
   ARCH-SAVE-003's re-open-and-validate is a byte-for-byte comparison of the re-read temp file with them (their CRCs
   and body digest were computed over exactly those bytes). `write_atomic()` keeps the re-decode for bytes of unknown
   provenance.
6. **The load's proof** recaptures sections 1-14 and compares them byte for byte, as before, but no longer recomputes
   section 15: the decode already proved section 15 equals the digest of these bytes' decoded records, so
   byte-identical sections carry it. That repeated the SHA-256 walk for nothing (about 130 ms). Section 15 also
   hashes the four movement profile revisions, which no section carries, so the proof compares the restored
   world's revisions with the ones the digest was verified under.
7. **Inventory's projection and rebuild** are vectorised: unused-filled columns with the live rows copied over them,
   free-stack prefixes by slice, and the derived counts from the live-row list.

## Rejected or deferred

- **A sparse file.** 76% of the 57 MB are zeros (gzip makes it 267 KB). Writing only live rows would cut every hash
  and the disk write, but it changes all eight large section schemas, the registry and every pinned layout test.
  Not needed for the target; it is the next lever if saves must get faster still (it needs its own schema bump under
  the established registry/version conventions, and DEC-055 Q3 still rules out compression).
- **Capturing on the main thread and encoding/writing on a worker** (the frame then stalls only for the capture,
  about 0.35 s). Deterministic (encoding is a pure function of the capture) and compatible with the save-at-boundary
  rule, but the session would have to report completion asynchronously and hold the captured image alive. Deferred:
  at 0.65 s a save is already inside the target.
- **Trusting the encoder and skipping the load's recapture.** Rejected: the byte comparison of the restored world is
  the load's only end-to-end proof that every apply installed what the file holds.
- **Running the rollback checkpoint concurrently with the incoming file's decode.** Rejected for now: on an incoming
  refusal it would have to restore a previous `.rollback` file it had already replaced (DEC-055 Q10 offers it as
  recovered).

## Consequences

- A new validator over a fixed-capacity table should take a proof first (`ColumnProofs.rows_proven()` for a
  row-local one) and keep its row walk as the authority on refusals. A proof must list every column its gates read.
- `Emitter.put_bulk()` is the way to fold a column into section 15; a per-value loop over a large column is a
  regression.
- The memory census charges the transient proof copies to the save/load working set (reviewed deltas for
  `buildings.gd`, `construction.gd`, `inventory.gd`).

## Review and what it changed

An independent review (code-reviewer agent, mutation testing in a scratch copy) found nothing CRITICAL and
confirmed claims 1-6 (proof soundness, projection, bulk stream, CRC, refusal order, function length). It found five
proof guards no test exercised (HIGH); each now has a test: the recapture refusing a changed world, a mid-ledger
delivery, a non-flag byte on a live construction row and on a live room, an inactive container's `c_reachable`, and
a stored body digest the worker's SHA-256 does not match. MEDIUM items fixed: the profile-revision gap in the proof
(above), CRC-first decoding, `CrcJob.values_for()` refusing CRCs of replaced sections in `encode_file()`, one
shared `_write_verified()`, dead projection helpers removed, one `i64_minimum()`. LOW: the CRC lookup table is
built before any worker starts. Not done: a differential test of the section 7 proof against single-cell forgeries
of a populated capture; `Emitter.put_bulk()` captures nothing of a run that exceeds the capture cap (only the
captured bytes after a refusal differ).

**A GDScript trap found on the way:** a lambda inside a static function of `buildings.gd` made every script that
`extends` it (`test_underground_entry_orders.gd`'s `ObservedBuildings`) fail to load with "Could not resolve class"
(108 failures in a full run). The row checks are bound static functions (`_building_row_ok.bind(image)`) instead.

## Evidence

Every save suite, the save→load→continue goal test (`test_settlement_save_load.gd`), the underground six-checkpoint
goal test (`test_settlement_save_underground.gd`) and ARCH-SAVE-006 parity (`test_settlement_save_parity.gd`) pass
byte-identically; Construction, Buildings and Inventory suites pass; the analyzer reports 0 warnings.

## Source

Brendan's chat decision of 2026-10-08 ("make saves fast first"); ADR 1222; ARCH-SAVE-003/004; ARCH-HASH-001;
SAVE-R09; RFC 1952 §2.3.1.
