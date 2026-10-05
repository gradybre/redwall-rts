# Independent 1191 static work-area review

Accepted for the frozen diagnostic/source scope. No high or medium finding.
The five exact review pins are retained in `replay-1/review.json`; the compiler
is `efcd47c39b67004410592cf1de106eeebe2226663d1d276eab6c9b3dc7c1a164`
and its test is `cd8ce2c89056dba7268f319383f1b5e3b0939bf7dbc301a7ca18163af19a46a6`.

I read the complete new compiler/test and its three producer predecessors, the
actual Frontier field/byte schema, and ADR1191. Before execution I checked the
five reviewed bytes against both current files and immutable source snapshots,
plus all input hashes from the structural, Frontier and diagnostic manifests.
The eight Python tests passed. A fresh reconstruction in this review directory
is byte-identical to all three retained source-1 outputs. All 38 captured input
files were unchanged after the review. No engine or native process was run and
no subject worktree file was written.

The independent decoder confirms that only the declared endpoint coordinates,
travel selectors, L0 retreat selector, episode storage selectors, Frontier
revision and endpoint count changed. The station/cut/bearing tables and other
installation/episode fields are identical to the diagnostic predecessor. The
source profile, original structural parts and wood-only bills remain unchanged.
The wire is 2,292 bytes; the existing reader formula is 4,112 bytes for the
exact six table counts `[2, 8, 2, 10, 12, 6]`.

The review decoded every role box, including active tool/contact roles as an
additional check. Complete rows 2, 6, 16 and 29 fit the H air/support enclosure;
row 12 does not. Rows 2 and 6 preserve exact yaw zero with distinct forward and
backward policies. Selectors 1/10 and 2/11 retain identical underlying endpoint
geometry while selecting explicit 2/6 versus 12 travel profiles. The 12 outer
paths contain 42 axial segments; all 756 negative BODY/support versus cut tests
are clear, and the sweeps are identical in reverse.

This is not whole-World or paid admission. The broad source12 air sweep for
contacts 4 and 5 intersects the pending bearer, as intended by the explicit
contact-retirement requirement. Their paths do not become usable after timber
publication merely because the retained-ground footing is clear. Current
terrain, full air/collision, contact retirement, source transitions, native
forward/backward playback and paid execution remain separate open checks. The
reader/callback integration refusal reported by root is not waived here.

Reproduce into a new directory in the reviewer's own worktree:

```sh
python3 -B docs/validation/evidence/underground-entry-owner-composition-2026-10-05/entry-work-area-review-v1/review.py \
  /Users/brendan/Developer/redwall-rts-codex-ug-integration \
  docs/validation/evidence/underground-entry-owner-composition-2026-10-05/entry-work-area-review-v1/replay-next
```

The subject remains pinned to the exact reviewed sources and input manifests;
a later source change must be reviewed as a successor.
