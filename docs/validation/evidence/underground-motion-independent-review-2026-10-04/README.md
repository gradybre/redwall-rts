# Independent motion review and composition audit

Reviewer: the Furnishing lane. All artifacts were written only in this owned
directory. Candidate worktrees were read-only; no engine, project or cache was
changed by these reviews.

- `design-v1/` records the earlier bounded ADR1143 storage design review.
- `runtime-v1/` retains the original candidate's one medium decode-lifetime
  finding, one low runner finding, exact engine source evidence, 11-test pass
  and independent byte-identical wire/manifest/census reconstruction.
- `runtime-v2/` accepts the narrowly corrected nine-pin candidate. Seven new
  adversarial tests and the corrected census were independently reproduced.
- `integration-audit-42bff090.md` is the separate pinned, read-only trace from
  demo confirmation to the missing first empty Kitchen composition. It is an
  implementation handoff, not playable acceptance.

The final runtime verdict is in `runtime-v2/README.md`; the source-only and
unmeasured native-memory limits remain explicit.
