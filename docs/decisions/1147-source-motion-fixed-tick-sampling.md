# 1147 — Source motion fixed-tick sampling

Date: 2026-10-04 · Status: independently accepted source/time component; route activation remains open

## Decision and boundary

[DEC-050](../setting_decisions.md#dec-050--initial-timber-stair-movement-pace)
and [ADR1145](1145-proposed-initial-timber-stair-timing.md) adopt 30 fixed ticks
per ascending or descending tread and 45 per supported half-turn for the first
unloaded adult mole carrying the existing pick. This component maps only those
choices to the exact accepted [ADR1143](1143-joint-source-motion-catalog.md)
source programs. It does not assign approach, retreat, laden, other-cast or
other-connector timings.

The content lane owns only new `underground_motion_clock.gd`, its test and UIDs,
this record and `validation/evidence/underground-motion-clock-2026-10-04/`.
Existing Motion, Profiles, Catalog, Routes, World, registry, queue, source images
and proof tables remain unchanged. The initial branch starts from fetched
`origin/master` at `82d60ba8`, fast-forwards to accepted `205ec79e`, and carries
the exact Motion prerequisite `0aeb7f82` as `6b6689b8`. The accepted shared
Motion registry/ledger prerequisite `1eb7a64d` is cherry-picked as `798220a7`.

## Exact mapping

The mapping accepts only the concrete Motion script's existing immutable wire
contract `495b22dacb303152651f8ca061a0017aa72a4031e281ac1df34dd9035bf695a0`.
The complete source key spacing is retained; preview duration does not supply a
new gameplay rate.

| Program | Source / clip | Source intervals | Adopted ticks | Source intervals per tick |
|---|---|---:|---:|---:|
| 0, ascent | 0 / 0 | 90 | 30 | 3 |
| 1, descent | 1 / 0 | 90 | 30 | 3 |
| 3, supported turn and reposition | 2 / 1 | 270 | 45 | 6 |
| 2, approach | 2 / 0 | 90 | Unassigned; refuse | — |
| 4, retreat | 2 / 2 | 90 | Unassigned; refuse | — |

For a supported program, `q = elapsed_ticks * intervals_per_tick * 65536`.
This is an exact integer mapping of the complete source timeline, including
stationary-root intervals. It does not derive phase from root displacement,
interpolate new joint poses, rotate a second time, or replace the reader's
signed-ceil root and heading equations. Source 2 clip 1 starts at absolute
frame 91 and ends at 361; Motion remains the owner of these frame offsets.

## Stateless interface and ownership

`sample_into(motion, revision, program, from_tick, to_tick, pose_out, intervals_out)`
returns a StringName refusal or empty success. The numeric command fields are
explicitly type-checked before integer conversion, so equal floats and booleans
cannot become authoritative ticks. Accepted ticks satisfy
`0 <= from_tick <= to_tick <= duration`; surplus ticks are refused, not clamped.

The caller supplies an existing nine-I32 pose output and two-I32 crossed-interval
output. Motion's actual `phase_into` provides XYZ, heading, source, clip, absolute
first/second frame and Q16 share for `to_tick`. The second output gives the full
half-open interval range `[from_tick * step, to_tick * step)`. Every interval in
that range, including stationary-root phases, still requires the actual route
owner's support, body/tool, paid primitive, dynamic occupancy and source proofs.
Equal ticks produce an empty range and the same pose. A terminal tick uses the
existing `(last, last, 0)` sample.

Both output arrays remain unchanged on every refusal. The concrete Motion
script identity and pinned source wire contract are checked; its current owner,
World, content revision and source-freshness refusals remain authoritative for
the source read. Sampler success is a source/time query, not actor eligibility,
route admission, Work credit, payment, renderer qualification or travel
permission. Motion's wire rate fields and unconditional activation refusal are
unchanged.

Routes will own any committed elapsed tick/progress, save meaning and cancellation
handoff. This class stores no resident clocks or mutable fields. Pause is equal
ticks; 2×/4× scheduling remains the existing fixed-tick host's responsibility.
Sampling multiple elapsed ticks cannot excuse skipped interval proofs. Reversing
the clock is refused; the separately authored opposite-direction program is
not an automatic cancellation permission.

## Allocation and validation packet

No retained banks, fields, arrays, per-resident objects or file reads are added.
The caller outputs total 44 bytes, below Motion's existing 176-byte caller
admission. The proposed extra logical scalar/helper ceiling is 256 bytes,
jointly counted with Motion's existing 1,090 inside the same 4,096-byte allowance;
it is not another 4,096-byte reserve. Exact source/call-chain/constant census
accompanies review: 64 bytes for the largest clock-only numeric call chain
(including the four checked integer Variant payloads), 16 bytes of numeric
constants and 128 bytes for expression results total **208 additional logical
bytes**. Together with Motion's existing 1,090, the count is **1,298 / 4,096**;
using the whole proposed 256 ceiling gives 1,346. The simultaneous clock plus
Motion phase numeric frames are 176 bytes; the conservative total retains the
entire preexisting Motion maximum and adds the clock maximum. Native Script,
digest/StringName, Variant representation and interpreter-frame costs remain
inside the existing provisional 32,768-byte allowance and require eventual
measurement. The joint admitted source arena remains **232,436 / 262,144**;
this component does not increase any shared or global reserve.

Focused tests must use the real accepted wire and actual Profile/Level/Directory
owners; cover every supported fixed tick, full interval coverage, terminal and
pause/chunked sampling, type/range refusal, unadopted program refusal, concrete
script identity, stale source/revision/World and unchanged caller outputs.
No existing source table or loader is weakened to make these tests pass. Clean
import, strict/raw diagnostics, changed-file analyzer and independent review
precede source acceptance. Full World playback and complete entry/retreat remain
separate engineering work.

## Retained component evidence

[Candidate 3](../validation/evidence/underground-motion-clock-2026-10-04/README.md)
passes the official exact singleton: 14 tests / 2,090 assertions / zero failures,
all strict/raw diagnostic and leak counts zero, and analyzer zero warnings in
the two changed GDScript files. Six source-census tests pass. The 1,195-file
input snapshot matches before and after. The isolated project user directory,
project settings, temporary stateless registry appendix, source, HEAD and import
sidecars are restored/unchanged. The appendix was expressly authorized for the
test; the permanent shared registry remains the root lane's integration task.

The earlier clean import correctly refused visible LFS pointers in the fresh
worktree; all 746 visible assets were then restored from existing local LFS
objects with exact OID hashes, without generation or main-worktree changes.
The next run's 14 tests passed but its analyzer rejected one unused test-subclass
parameter shadowing a base member. Only that parameter was renamed. Both
rejected runs, the previous test source and the initial census indexing error
remain in evidence. None is reported as an accepted full-project run.

Root independently reviewed the seven frozen source/UID/helper hashes, the
complete interval mapping, bounds before multiplication, concrete source and
World identity, Motion's final preflight before caller writes and refusal
preservation. Root reran all six census tests successfully and accepted this
source/time-only component with no blocking findings. Runtime movement,
presentation, complete approach/retreat and permanent shared-registry/helper
integration remain separate; the latter belongs to the root lane.
