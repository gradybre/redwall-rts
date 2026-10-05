# 1182 — Memory closure for the UI notice alias
Date: 2026-10-05 · Status: Accepted after independent review

## Decision

Extend the 1174 source closure only for 1177's `UIManager.CLOCK_OVERLOAD_CODE`
alias to the actual `UiNotices.CLOCK_OVERLOAD_CODE` constant. Keep the accepted
1174 manifest and every old producer unchanged. Pin a successor manifest,
verify the actual dependency's exact literal, and reconstruct the old
UIManager bytes with only that one reviewed line before historical accounting.

## Why

At integration `32c65ecd9b509d5944cce443cfff410fcadabfd2`, all 64 current
modules and 138 witnesses still match 1174 except UIManager, listed in both
maps. Its full-source hash changes from `3cf277da…` to `4d64b299…`; the only
executable change replaces the same string literal with its already-preloaded
notice owner's constant. Blind hash renewal would conceal an unrelated body,
allocation or source-value change.

## Consequences

The new dependency is a current module, so both injected text and exact owner
identity close before any producer executes. Current and archived
UIManager identities remain distinct. The exact current constructor and all
existing producers still run; numerical accounting and reservations do not
change. The shared global declaration remains 99,999,806 bytes with 194 bytes
remaining, without native-memory or gameplay qualification. Root owns permanent
pack regeneration. Only the room-memory tool/test and this new evidence/ADR
change; UI, runtime, old evidence, registry and other tools stay untouched.

## Source

Root's narrow follow-up authorization after independent 1174 acceptance and
review of the exact 1177 alias-only delta, 2026-10-05.

## Validation

The final candidate passes 278 memory tests and 190 capacity checks. Root
independently reran all 32 focused tests and rebuilt the proposed pack
byte-identically (`a47a2fb0…`). All frozen candidate-2 source pins remain
unchanged. The independent [acceptance receipt](../validation/evidence/underground-memory-ui-alias-2026-10-05/independent-review/acceptance.json)
is copied byte-exact from root’s `underground-memory-ui-alias-review-2026-10-05`
evidence. This accepts source accounting only; permanent pack regeneration
remains root-owned.
