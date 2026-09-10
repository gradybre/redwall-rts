# 0042 — The command queue orders by an unsigned key, and its arena resets when it empties
Date: 2026-09-10 · Status: Accepted

## Decision

`godot/scripts/core/commands.gd` implements ARCH-CMD-001/003 and §8.1's economic
command queue: 4096 records at §8.1's exact 64-byte layout, a 1048576-byte
payload arena, `execute_tick = completed_tick + 1`, and the 24 ARCH-CMD-003 kinds
compiled as the catalog domain `CommandKind`.

Seven things are settled here.

1. **The two sequence words are compared UNSIGNED.** §8.1 types them "u32 bits"
   and they live in `PackedInt32Array` columns, so a session counter crossing
   `0x80000000` stores a negative i32. `compare_key_parts()` masks both words
   with `0xffffffff` before comparing, exactly as ARCH-RNG-001 already requires
   for stored xorshift state. A signed comparison orders `0x80000000` before
   `0x7fffffff` and silently reverses two player edits.
2. **`CommandKind` is a compiled catalog domain, so the artifact digest moved.**
   `catalog_ids.json` goes from 2588 bytes /
   `73d34d26af1f690261957ef27c0e5a14a5462d5d57b2f55a84b69e5fa900a3bd` to 3064
   bytes / `00e3ffd5c98b5f5da050cc13be91895b85744eb3b3f3cfb5e50dde85a598cbf1`,
   21 domains / 182 rows to 22 / 206. **Intentional catalog change, not parity.**
3. **ARCH-CMD-002's speed/pause events are NOT here and no value of theirs is
   invented.** They are a separate queue awaiting task 04.1's amendment, and
   their keys stay out of the sorted kind domain. **U2 is therefore only partly
   closed.**
4. **Order is a ring index over fixed rows: `_order` is always a permutation of
   0..4095**, whose unqueued half is the free list. 16384 bytes, added to §2.3.
5. **The payload arena is bump-and-reset**, reclaimed only while the queue is
   empty, refusing rather than overwriting. INTERPRETATION.
6. **A nonzero `flags` is refused**, because no bit of it is defined anywhere.
   INTERPRETATION.
7. **Nothing is wired to a producer.** This is transport; `job_planner.gd` is
   untouched and unreferenced.

## Why

**The unsigned comparison is the defect this module exists to avoid.** ARCH-CMD-001
spells the key `sequence_high_unsigned, sequence_low_unsigned` and the field table
types both halves "u32 bits". Nothing else in the store can tell the difference:
a signed compare produces a perfectly ordered-looking queue that plays two edits
back in the wrong order once the counter passes 2147483647.
`test_sequence_order_is_unsigned_across_the_sign_bit()` resumes the counter at
`0x7fffffff`, queues two commands, and asserts on `arg0` — deleting the mask
fails it on a value, not on a message. The pure `compare_key_parts()` is also
tested term by term, because the `player_id` term is unreachable through the API
while release 1 has one player and would otherwise be untested dead code.

**A ring index rather than a free list, because the free list is already there.**
Positions `_head .. _head+_count-1` name the queued rows; the rest hold the free
rows. Insert takes the row at the first free position and shifts the tail right
over it; pop advances `_head`, which leaves the freed row in what has just become
the LAST free position, so the permutation is preserved by doing nothing. That is
one 4096-entry i32 column instead of a free stack plus a reverse map, and it makes
"no row is ever handed out twice" structural rather than a check that could be
forgotten. The alternative — keeping the record columns themselves in canonical
order — would shift fifteen columns on every insert AND on every drain, which is
the per-tick path.

**Bump-and-reset is exhaustive for the specified cycle, and its limit is stated
rather than hidden.** Every accepted command is due at `completed_tick+1`, so one
drain empties the queue and returns the whole arena. §8.1 budgets the arena and
defines no allocator, so the choice was between this, a free list the
specification does not describe, and refusing payload-bearing kinds outright. A
free list would be inventing an unbudgeted structure; refusing payloads would
make `payload_offset`/`payload_length` dead fields. What this cannot do is serve a
queue that stays non-empty across more than 1048576 bytes of payload, and in that
case it REFUSES with `COMMAND_PAYLOAD_ARENA_FULL` rather than overwriting a
pending command. A drained command's payload stays readable until the next
accepted submission; the drain loop is where a tick reads it.

**`flags` is refused nonzero because accepting it would invent a semantic.** No
document defines a bit in that field. A stored undefined bit would enter the
canonical hash, mean nothing to the drain, and become load-bearing by accident.
This is the treatment §8.1 already prescribes for `reserved_zero` one field along,
and it narrows the day a flag is specified. Recorded here because a later reader
could reasonably do the opposite.

**What "group" means was ambiguous, so BOTH readings are implemented.**
ARCH-CMD-003's sentence — "count first followed by owner-ID-sorted rows; all IDs
must validate before committing any member of a group" — describes ID rows inside
ONE command's payload; 04.2's "whole command operations succeed or refuse
atomically" describes a set of commands. `submit_id_group_into()` is the first,
`submit_group_into()` the second, and both validate everything before writing one
byte (decision 0024). The ID-group form BUILDS its payload, so an envelope that
also carries opaque bytes is refused (`COMMAND_PAYLOAD_CONFLICT`) rather than
having them silently dropped. The ID rows use the original component field types, so a
4-byte count and 8-byte `(slot, generation)` rows — derived from GDD §4.2's
EntityRef, not chosen. **Which kinds carry an ID group is unspecified**, so the
form is selected by the caller; deriving it from the kind would mean inventing 24
payload schemas that no document states.

**Two entry points, because a replay stream carries its own envelope.**
`submit_into()` stamps `execute_tick`, `player_id` and the sequence and is the
only production stamper. `admit_stamped_into()` reads them instead, which is what
04.2's "permuted input arrival produces canonical order by the owning key"
requires and what §8.1's append-only replay stream will need. A stamped record due
at an already-completed tick refuses rather than executing late, and a repeated
key refuses rather than leaving the order ambiguous.

**What is NOT decided here**, each with its owner: the per-kind payload schemas
(04.2); the `goal_x`/`goal_z` unit, which §8.1 does not state and which is either
GDD §4.2's 1/1024 m or ARCH-PATH-001's 1/2 m cell (a specification change, so
only the i32 range is checked and no map bound is asserted); which kinds require
a target (04.2); the scheduler-event queue (04.1); and persistence, which has no
save module in this repository at all.

## Consequences

- **Every save or replay fixture written against the old catalog digest refuses.**
  There is no production save module yet, so nothing on disk is affected today,
  but the pinned constants in `godot/test/test_catalog_ids.gd` moved and say why.
- The 24 kind ids are now save- and replay-carried. Renumbering one silently
  repoints stored commands; `verify_compiled_enum()` refuses a hand edit.
- `COMPILED_ENUM_DOMAINS` has four members, so any loop over it covers a fourth
  domain. `test_catalog.gd`'s "three compiled domains today" assertion was
  updated to four, and its two domain loops now include `CommandKind`.
- **U2 stays open for speed and pause.** `sim_clock.gd` is untouched and its two
  "BLOCKER U2 ... not implemented" comments remain accurate. Task 04.1's
  amendment must land before a speed or pause command can be queued at all.
- A future save writer calls `encode_record_into()`; a loader calls
  `decode_record_into()`, `envelope_refusal()` and `restore_sequence()`. All four
  exist and none is wired.
- Nothing yet delivers a drained command to a producer. `job_planner.gd`'s four
  producers are still uncallable by a player.

## Ledger

One §2.3 allocation is added; no §2.2 field row changes, because the command
queue is not a GDD §4.2 component.

| Figure | Before | After |
|---|---:|---:|
| Command queue order index | — | 16384 |
| Planned allocated payload | 59304654 | 59321038 |
| One live world plus reserve | 67693262 | 67709646 |
| Headroom below decimal 100 MB | 32306738 | 32290354 |
| Additional candidate mutable state | 53089070 | 53105454 |
| Transactional peak plus same reserve | 120782332 | 120815100 |
| Transactional headroom | −20782332 | −20815100 |

All five identities were re-derived after the edit: `live = payload + reserve`,
`headroom = 1e8 − live`, `candidate = payload − 6215584`, `peak = live +
candidate`, `t-headroom = 1e8 − peak`.

**The 437632-byte discrepancy decisions 0039, 0040 and 0041 recorded is still
there and is still not corrected here.** Measured again on this checkout: §2.2's
own `Payload bytes` column sums to **24952146**, which is exactly the ledger's
*Fixed registry payload* row, while §2.2's prose sentence states **24514514**, and
the *Planned allocated payload* figure is computed from the prose. Removing this
decision's +16384 reproduces the identical gap, so it predates this change and the
+16384 is applied consistently to both sides of it. It is left for whoever owns
that arithmetic.

## Source

- `docs/systems_architecture.md` ARCH-CMD-001, ARCH-CMD-003, §8.1's command byte
  table and §2.3's ledger row.
- `docs/tasks/04_world_commands.md` §04.1 (the scheduler-event queue's deliverables
  and the instruction not to insert speed/pause keys into the sorted catalog) and
  §04.2 (64-byte records, queue 4096, arena 1048576, unsigned high-then-low
  comparison, atomic whole-command operations).
- `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1's implementation
  boundary: refine existing payloads rather than renumbering ARCH-CMD-003.
- Decision 0024 (allocate before consume), decision 0033 (enum ids come from
  ASCII keys) and decision 0034 (the catalog artifact is compared as bytes).
