# 0168 — Check resource claims without repairing saved state

Date:2026-09-19 · Status:Accepted SAVE-CLAIM-CHECK-R01v2

Saved claim slices need a read-only comparison against the saved Directory, Jobs,
habitats and forage zones. Existing legacy helpers overwrite counts, scratch,
resource totals or ordering keys. They cannot validate the state they repair.

Use a pure checker over current section7 blocks, a section3 record/cursor and new
explicit immutable component projections. Preserve dead Job/Expedition claims for
normal later cleanup while refusing impossible future/live identity, ecological,
provenance or aggregate mismatches. Compare all totals, including no-claim rows;
count a shared designation/basin once. No member/cancelled/seasonal quota refusal
is invented. Public lifecycle witnesses refute three alleged Forage defects.

This separates independently testable checking from absent full-file integration.
SAVE-CLAIM-WORLD-BINDING owns actual section4 projection, descriptor/file/world
binding and pre-publication invocation in the complete coordinator. It remains a
blocking dependency of final SAVE-CAPTURE/activation. No new opaque token is claimed
to authenticate the origin of arbitrary caller arrays. No complete-save release
flag changes and no second mutable world is introduced.

The new projections total148768 packed bytes. Conservatively charge4230440 private
packed bytes including Directory Derived, two existing validator sort copies and
claim sums. Native overhead remains unmeasured. No permanent owner columns or wire
schema changes. The exact contract owns refusal order, diagnostics, allocation,
mutants and activation dependencies.
