# Independent review of the 1143 storage design

Reviewed commit: `54cf571c` in the Geometry worktree. Reviewer: furnishing lane.
This verdict covers the committed design and census, not the unfinished runtime
catalog, packer, allocation measurements or route activation.

No high or medium design finding was identified. All 26 retained input hashes
match. The frozen census was copied byte for byte and replayed from this review
directory, with output written here only. Its complete payload and source pins
match the retained result; the independently recorded checkout HEADs differ
because the same accepted input files are now present in later commits. See
`replay-comparison.json`. No engine, project/cache mutation or foreign edit ran.

The source-derived configured Profile cost is correct:

`2 × (18 × (18×4 + 3×8 + 2) + 194×7×4 + 1×32 + 4×8) + 32768 = 47288`.

Adding Levels (244 + 2048), both complete motion/identity banks
`2 × (19224 + 48548 + 3088)`, the 4096-byte decoder, 176-byte caller, separate
4096-byte logical/helper ceiling and 32768-byte new native allowance gives
**232,436 bytes**, leaving **29,708** of the unchanged **262,144** reservation.
The existing Profile control allowance and the new native allowance are charged
separately. The independent Profile maxima correctly require 444,284 in this
composition and must refuse. Presentation palettes, mesh-array scratch and
original borrowed resources are kept outside this simulation arena.

The design preserves every source table row, stationary interval and original
solid. Its source metadata distinguishes exact image/clip, program, coordinate
equation, fixed fixture transform, moving heading, Profile/Catalog revisions,
primitive identity, proof/backend/consumer closure and the shared ready pose.
Root-local ceil before a gait rotation remains distinct from the fixed-frame
handoff equation. The terminal heading remains 32768; no hidden heading reset,
loop or pace adoption is claimed. Immutable primitive correspondence cannot
stand in for current paid Placement/Region identity.

The source-once first implementation is a coherent boundary: charge two motion
banks, reject replacement/reentry, stream only to the inactive bank and publish
after complete validation. A later joint Profiles/motion reload still needs an
explicit prepare/seal/publication coordinator; existing Profiles swaps itself
immediately. The design correctly leaves every activation refused while those
owner, physical, profile, renderer, rate and lifetime requirements are missing.

The runtime review remains pending and must establish these concrete obligations:

1. Derive the admission calculation from actual configured Profile capacities
   and charge Levels before any motion-bank allocation. No second owner or
   replacement may silently duplicate controls/decoder/native allowances.
2. Count every actual retained numeric member, bank header, output packet,
   digest, parser/hash buffer and simultaneous helper/callback path. The 4096
   and 32768 ceilings are proposals, not existing measured facts. Shared caller
   and decode storage need a real busy/reentry boundary.
3. Reject malformed matching-hash images, changed actual owner objects/full
   World references, stale source/revision identities and late callback drift.
   Failed load/read must preserve the published state and caller outputs.
4. Keep source-only flags, unresolved runtime fields and unconditional route
   activation refusal enforceable. No generic box coincidence or opaque digest
   may substitute for exact proof/part ownership.
5. Exercise complete per-table ranges, stationary/terminal sampling, signed
   root ceil, heading interpolation, output non-aliasing and the four full joins.

Geometry was asked for an exact runtime diff base, source/test pins and evidence
before code review. No moving runtime code was reviewed for this verdict.
