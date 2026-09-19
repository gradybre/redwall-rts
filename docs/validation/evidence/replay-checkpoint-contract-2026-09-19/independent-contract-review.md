# Independent contract review — SAVE-REPLAY-R01 draft v1

2026-09-19 · Independent source review of `docs/planning/replay_checkpoint_contract.md`
(sha256 `b28cbac0…6a21c`) against `docs/validation/evidence/replay-checkpoint-contract-2026-09-19/source-excerpts.json`
(sha256 `85196916…c25f6`). Review only: no source was edited, nothing was executed,
no test result is claimed. Conclusions are limited to the numbered lines supplied;
files and line ranges outside those slices are treated as unverified and named as such.

## 1. Verdict

The proposed 264-byte outer format2 header is a **complete, minimal and safe**
representation of the economic admission checkpoint, and the draft correctly keeps it a
redundant declaration rather than an allocator owner. Five bounded defects (B1–B5 below)
should be fixed in a v2 of the draft before the implementation packet is cut. None of them
is a design reversal; all are prose/API precision.

## 2. What verified against source

**Header arithmetic.** `save_header.gd:74,78,84-99` gives HEADER_BYTES 256,
SECTION_TABLE_OFFSET 256, OFFSET_REPLAY_SEQUENCE 216, OFFSET_BODY_DIGEST 224;
`test_save_header.gd:123-153` pins the same values as independent literals and asserts
`224 + 32 == 256` and `body_offset() == 256 + 64*15` (1216). The proposal's layout
216(u32) + 220(u32) + 224(u64) + 232(32) ends at exactly **264**, and
`264 + 64*15 = 1224`. Both are internally consistent and consistent with the current file.

**Cross-section offsets.** `save_section_01.gd:163-168` fixes SECTION_BYTES 3752768,
FIRST_SECTION_OFFSET 1216, SECTION_2_OFFSET 3753984; `test_save_section_01.gd:49-52`
pins 3752768 / 1216 / 3753984 as ruling-transcribed literals. The draft's 1224 and
3753992 are exactly +8 on both, and 1224 + 3752768 = 3753992. Correct.
Section-relative offsets (`save_section_01.gd:12-34`, test `RULING_BLOCK_OFFSETS`)
are untouched by the shift, as the draft says.

**Domain completeness.** SAVE-SEQ-R01 v2 admits high in 0..4294967295 with any u32 low,
plus exactly (4294967296, 0). The header pair (u32 low, u64 high with the same tuple rule)
represents that set exactly — 2^64 ordinary states plus one terminal — with no sentinel
overloading of (0,0). 12 value bytes is the minimum for a 65-bit space at these widths;
the 4 reserved bytes at 220 are load-bearing, not slack: they keep the u64 at 224 and the
digest at 232 eight-byte aligned. The existing single `replay_sequence` u64 at 216 cannot
represent the domain, which is the stated reason for the change and is confirmed by
`save_header.gd:178,276,295-296,344` (one nonnegative signed-int64 scalar).

**Structural/semantic decode separation is preserved.** `decode_header_into`
(`save_header.gd:312-328`) is explicitly structural, `header_refusal`/`_version_refusal`/
`_extent_refusal` (389-436) carry judgement. The draft's tuple, terminal and reserved rules
belong on the validation side, and `_encodable_ranges_refusal` (269-278) on the encode side;
the draft's "validate the whole tuple before any output mutation" is compatible with the
existing allocate-before-consume discipline (staging buffer at 247-254).
`_read_header_words` reads sequentially from 200 (200→208→216), so the new low/reserved/high
words can be read in the same run without a second `seek`, provided reserved is *read and
carried*, not skipped. `_extent_refusal`'s `body_offset()` recomputes to 1224 automatically
(441). `read_u64_into`'s existing GDScript-int-domain refusal covers the sign-bit case the
draft wants tested.

**No competing owner.** `commands.gd:1046-1062` restricts `restore_sequence()` to empty
queues and ordinary u32 pairs and states in terms that "the separate header's replay
checkpoint field has no allocator binding here"; `commands.gd:1065-1078` makes
`restore_pending_window()` the section12 route and non-consuming. The architecture row
`systems_architecture.md:451` (`WorldRuntime.next_command_sequence`, I64×2) is a budget row
for a store that does not exist — the same pattern the 450 row documents for
`next_persistent_id` — so the draft's "historical reserved allowance, no live duplicate"
treatment is the correct reading, not an invention.

**Canonical and digest reasoning.** `save_header.gd:51-59` records that the body digest and
per-section CRC do **not** cover header bytes and that this is pinned in the header tests.
The draft's conclusion — a mutated header pair with an intact body digest is caught only by
the explicit header↔section12 cross-check, and mutating both is caught by section15 — follows
and is stated without overclaiming (it correctly calls SHA-256 corruption evidence, not
authentication). SAVE-R09-003 registration of outer format2 and every field's meaning/width
is required and named; the draft correctly notes the rules-identity producer is still absent
(`2026-09-11_save_codec_contract.md:52-58`).

**Frozen-admission semantics.** "Next economic admission frontier of the exact frozen
snapshot, never inferred from pending records, refusals do not advance, accepted-then-failed
commands have consumed" is coherent with SAVE-SEQ-R01's drained-queue requirement and with
ARCH-SAVE-003's completed-boundary freeze (`systems_architecture.md:870`). The refusal to
specify replay-record framing/append protocol (task09.4) and the refusal to claim a full-file
orchestrator are appropriate and are the right scope boundary.

## 3. Bounded defects to fix in draft v2

**B1 — SAVE-R09-001 is not amended, and an earlier v2 was already rejected.**
`2026-09-11_save_codec_contract.md:11-15` states "Keep `RWLSET01`, outer `format_version=1`,
256-byte header" *and* "The scheduler proposal's outer-container version 2 is superseded."
The draft invokes SAVE-R09-001:20 ("change the outer version only when header/descriptor
interpretation changes") as authority but never says it supersedes SAVE-R09-001's §1 sentence,
leaving two rulings in contradiction, and never distinguishes this format2 from the earlier
superseded format2 proposal. *Revision:* add one paragraph naming
`SAVE-R09-001 §Container and section versions` as amended by SAVE-REPLAY-R01 for the outer
number only (section vector, descriptor size and section12 schema unchanged), and state
explicitly that this format2 is a different change from the superseded scheduler proposal,
so the historical record is not rewritten.

**B2 — "Current release writers emit only format2" is false as written.**
`save_header.gd:75` is `FORMAT_VERSION = 1`, and `test_save_header.gd:267-278` pins version 2
as *refused* (`REFUSE_FUTURE_FORMAT_VERSION`) and version 1 as accepted. There are also no
release writers at all today. *Revision:* rewrite as "after activation, every writer in this
repository emits format2 and no format1 writer remains; no released file of either version
exists, so no migration is owed."

**B3 — the preamble parse needs a named API and an explicit precedence order.**
Today `decode_header_into` refuses `bytes.size() < HEADER_BYTES` *before* any version word is
read (`save_header.gd:319-321`), so a 256-byte format1 file under format2 code would report
`SAVE_HEADER_TRUNCATED` rather than the intended legacy-format refusal — which defeats the
draft's own "explicitly refuse format1, preserving the file and caller's record".
*Revision:* name the new surface (e.g. `preamble_refusal(bytes) -> Refusal` reading only
offsets 0..15) and pin the order: preamble-truncated → magic → legacy format1 → future
format>2 → header-truncated (<264) → structural decode → `header_refusal`. Put that function
in SAVE-HEADER-REPLAY-FORMAT's owned surface; it is currently implied but unowned.

**B4 — refusal-code identity for the new rules is unstated.** The draft lists what must
refuse (sign bit, high>4294967296, terminal with nonzero low, negative words, nonzero
reserved) but not under which `StringName`. `save_header.gd:121-145` already has
`REFUSE_VALUE_RANGE` and `REFUSE_RESERVED_NONZERO` (currently used for descriptor padding).
*Revision:* state exactly one new code, e.g. `SAVE_HEADER_SEQUENCE_RANGE`, for every invalid
(low, high) tuple; reuse `REFUSE_RESERVED_NONZERO` for offset-220 padding and
`REFUSE_FORMAT_VERSION` for legacy format1 (no third code). Tests can then pin the tuple rule
separately from generic width faults, which the current wording cannot support.

**B5 — the binding helper has no home and no dependency rule.** The draft requires a "pure
header/section12 binding helper" that "accepts decoded values". `save_section_01.gd:85`
preloads `save_header.gd`; a helper living in `save_header.gd` that preloaded a section module
would risk a preload cycle and would also make the header module depend on a section it must
not own. *Revision:* state that the helper is static, takes plain ints
(header low/high/tick, section12 low/high, section1 clock tick), returns `Refusal`, preloads
no section module, and mutates no store — and name where it lives.

## 4. Missing ownership / evidence items (not scope creep)

1. **Ruling provenance for the +8 shift.** `test_save_section_01.gd:4-8,51-52` states its
   literals are transcribed from R-WORLD-S1-001, *not* read from the module. Editing them to
   1224 / 3753992 without amending or annotating R-WORLD-S1-001 §8 silently breaks the
   independent-anchor discipline that file exists to enforce. Add "amend R-WORLD-S1-001 §8's
   absolute file positions (section-relative offsets unchanged)" to the owned artefacts.
   Same for the stale comment at `save_section_01.gd:165-167`.
2. **A repo-wide census of hardcoded 256 / 1216 / 3753984 is not an acceptance item.** The
   supplied excerpts cover two modules and two tests; other consumers are unverified here.
   Add "enumerate every occurrence and show each is either shifted or provably header-size
   independent" to required evidence, otherwise the +8 relocation is unproven outside these files.
3. **Section1's frozen 80-byte `world_runtime` payload was not supplied.** The claim that it
   carries no command-sequence duplicate is plausible from `systems_architecture.md:450-451`
   but is not verifiable from these excerpts. Make "confirm the 80-byte body declares no
   command-sequence field" an explicit implementation check, not an assumption.
4. **Stale comment correction is owed twice.** SAVE-SEQ-R01 v2 already requires fixing
   `commands.gd`'s comment about the header at 216; after format2 that comment must name the
   216/224 pair. `commands.gd:1050-1051` should be listed in the owned-files set of whichever
   task lands second, with an explicit note so the two tasks do not both claim it.
5. **Header struct churn is under-enumerated.** Replacing `Header.replay_sequence` touches
   `save_header.gd:178, 276, 295-296, 344, 373` and `test_save_header.gd:48, 139, 145-148,
   153, 187`. Listing these in the packet prevents a partial edit that compiles and silently
   drops the high word.

## 5. Suggested downstream tasks (precise)

- **SAVE-HEADER-REPLAY-FORMAT** (as drafted, plus B3's `preamble_refusal`, B4's single new
  refusal code, B5's helper location, and item 1/5 above). Depends on
  SAVE-ECONOMIC-SEQUENCE-FORMAT. No disk publication, no recorder.
- **SAVE-REPLAY-R01-DOC-AMEND** (tiny, may be folded in): amend SAVE-R09-001 §1,
  R-WORLD-S1-001 §8 absolute positions, `systems_architecture.md` §8.2 header table and the
  `WorldRuntime.next_command_sequence` row annotation, and the task09 lane record. Historical
  evidence untouched.
- **SAVE-OFFSET-CENSUS** (evidence-only, may be a checklist inside the above): the item-2 sweep.
- Unchanged and still owed elsewhere: task09.4 replay-record framing/append protocol; the
  rules-identity producer (SAVE-R09-003); the full-file coordinator that performs the
  header↔section12↔section1↔section15 checks and the exhaustion acceptance the draft correctly
  refuses to infer from an isolated codec.

## 6. Non-blockers deliberately not raised

The reserved word at 220 rather than a packed 12-byte layout, the choice to keep the digest at
the header tail, the decision to widen the header rather than move the checkpoint wholly into
section12, and the deferral of replay-file framing are all sound and are not reopened here.
