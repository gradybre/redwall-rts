# Exact storage-aging columns and owner-block adapter

SAVE-AGE-R01v2 / ADR0162 adds owner capture/restore and a separate single-block
section7 adapter. It preserves all four declaration arrays, list order, native
count and hour latch. It neither restores Inventory nor assembles a whole save.

- Independent implementation and review sessions are archived with SHA-pinned
  inputs, exact file allowlists and stopped-owner evidence.
- Initial focus failed to parse a parent-authored typed-array test expression;
  corrected before acceptance. The implementation itself parsed successfully.
- Focus after correction:126 tests/1938 assertions/0 failures.
- Full local suite:4728/184803/0. Then two test additions and review refinements;
  final focus128/2322/0. Exact final-head CI remains required before merge.
- The only production edit after review changes tail iteration to an integer
  count; every refusal and continuation test remains green. No format change.
- The actual order witness distinguishes restored[0,1] versus wrongly sorted[1,0]
  next lot slots after waste expiration. Same-hour replay refuses; next hour
  ages exactly once. Destroyed/reused container generations survive until sweep.
- Literal pre-change block hashes pass for empty, one, reversed two and maximum
  declarations. Existing whole-section codec tests remain in the focused run.
- Malformed blocks, owner columns, native scalars and payloads refuse atomically.
  Paired codec/owner adversarial cases cover both restore and corrupt live capture.
- Existing shutdown553objects/33resources remains the baseline; native gameplay,
  art, full-world association, complete save/load and first playable are not
  claimed. Allocation accounting is source-derived and does not qualify RSS.

See review-disposition.md, allocation-phases.md and mutation-results.json.
