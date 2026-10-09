# 1136 — Publish prepared connector workpieces after paid START

Date: 2026-10-04 · Status: accepted prepared-publication seam; physical composition pending

The actual modular Router already consumes delivered claims through Inventory's
final observation barrier and begins Construction using the same preflighted
connector facts. Its START tail previously discarded physical preparation.
Decision1134 needs that exact tail to publish the prepared static workpiece.

Add `Owner.publish_start(project)` to the existing publication dispatch. Only
the actual connector purpose receives this callback, after Funding's receipt,
Construction's concrete begin and existing Job state updates. Selection reads
Construction's actual packed purpose. It does not call a virtual purpose or
bill observer after the payment barrier, and it retains the original owner.
The existing synchronous Project/action/owner tuple and busy guard cover this
callback; there is no new permit, retained field, quantity or progress ledger.

The base callback preserves discard-only behavior for existing owners with no
START geometry, including explicit synthetic fixtures. It grants no physical
permission. A newly bound Workpieces composition must prove and retain its
complete original spatial candidate before Inventory commits, override the
callback with its static prepared publication, and refuse payment when that
candidate is missing. Decisions1134/1135 own those concrete obligations.
All other purposes retain their existing direct START discard. Resume does
not repay or republish the workpiece.

The new regression fixture uses actual Inventory, Reservations, Funding,
Construction, Jobs, Work and Gear. Only the physical owner is explicitly
synthetic. It checks postpayment ordering, original preparation, absence of
late virtual bill/purpose reads, reentry and replay refusals, byte-identical
goods/claims/receipts after a late refusal, clean retry and unchanged ordinary
purpose behavior. Real material hauling, source-bound workpieces, rendered
handling and the playable first-entry workflow remain separate acceptance.

Root owns only the shared Contract/Router seam and its new test. Construction
owns Workpieces/ConnectorWork/Contacts; Geometry owns the prepared spatial
companion. The root branch was created from freshly fetched origin/master
82d60ba8 and fast-forwarded to accepted own integration a5a647b9. No other
checkout or agent branch was changed.

## Verification

The independent presentation/furnishing agent accepted the exact Contract,
Router and new regression-test source pins after reviewing the payment,
concrete begin, Job-state, publication and resume paths. No retained member
was added. The existing general `is_publishing` method still requalifies the
virtual owner: it is not a pure postpayment observer. The physical workpiece
kernel must inspect the concrete Router tuple and publish already prepared
facts without new virtual observations.

The clean-assets/cache/import procedure followed by four official singleton
shards passed 62 tests and 2787 assertions. Every shard reported zero
unexpected diagnostics, zero expected/tolerated diagnostics, and zero object
or resource leaks; the analyzer reported zero warnings in all three changed
GDScript files. Exact commands, source pins, summaries and scope are retained
in `docs/validation/evidence/underground-workpiece-publication-2026-10-04/`.
This is component evidence, not a passing integrated full-suite checkpoint.
