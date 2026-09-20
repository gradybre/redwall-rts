# Reservation row and index restoration

SAVE-RES-R01v2 / ADR0163 preserves eight canonical arrays and exact row identities,
rebuilds semantic chains and a valid lowest-free-index heap, and bridges one
section7 block without changing its wire schema.

Initial and integrated focus:117 tests/2639 assertions/0 failures, including17
new independent parent tests and existing reservation/section-codec suites.
Fifteen static contract/registry checks pass. Full local suite passed4747tests/
186266assertions/0failures. Independent source review found no correctness defect; acceptance gaps were
closed by five additional tests, final focus122/2944/0. Exact-head CI remains
required before merge. Existing shutdown553objects/33resources unchanged.

Cases include genuine coalescing, expiry, renewal, job/lot release and lowest
free allocation after restore; malformed source/index/input refusal atomicity;
all registry ordinals/types and four literal pre-change block hashes; the full
32768-row reverse semantic order; target J/L interpretation; nonascending valid
heap and stale tail acceptance; buffer independence; preserved math/pending
scratch and fresh claim-count recomputation. No Inventory restore or whole-save
claim is made. See allocation-phases.md and parent-integration-notes.md.

Contract/probe evidence: [sibling contract directory](../reservations-columns-contract-2026-09-19/).
Review resolutions: [review-disposition.md](review-disposition.md).
