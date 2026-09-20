# Astra disposition of independent Schedule source review

Accepted: no blocker or material source/test gap. Frozen input hashes and the160-line/1600-word output budget were checked before intake; reviewer stopped. Actual output:108lines/1112words. No run claims by reviewer.

At dispatch, source review lacked the later required mutation/static/import/full evidence and parent registry files. The12required mutation variants subsequently all failed actual assertions, with baseline/restored62/17896/0 and unchanged product SHA.17static gates and import subsequently passed. Registry prose and matching canonical notes now say _resolved is successful resolve history, not current-hour state. Full suite subsequently passed4907/233113/0; exact-head CI remains a separate pending acceptance gate. Needs bulk APIs were reviewed and runtime tested in merged PR161 and are unchanged; Schedule's public-history fixture additionally exercises them in the actual engine. No extra public API change is inferred from this review.

One phrasing clarification: _write_template_hours itself resets only the latch, template and hourly cells; it does not reset current/resolved. The reviewer separately correctly identifies assign_template retaining current/resolved. spawn explicitly initializes current/resolved after calling that helper, and both producer invariants remain proven. No source change is required.

The exact detail prefixes are deliberately pinned and passed; no cosmetic normalization. Packed argument aliasing is outside the immutable caller contract, and the bridge's independently reviewed canonical mappings are explicit. Deferred section2 identity, Needs agreement, bulk APIs and world publication remain incomplete.
