# Construction immutable preflight proposal — revision 2

Astra proposal for owner-specific review, September 20. This resolves representation choices left open in draft1; it does not authorize implementation until the complete contract and witnesses are accepted. The section4 family, existing schema and borrowed-image rule remain unchanged.

## One source of validation facts

Keep the small frozen validation constants in construction.gd, next to its cold Columns contract. Use typed constant Arrays and Dictionaries, never new packed columns or a live compiled Construction/Buildings/Directory/Definitions object. Canonical building and furniture key arrays define ID order. Separate typed integer arrays hold building work, maximum workers, furniture work, upgrade IDs and upgrade work. Fixed exact bill arrays/dictionaries mirror the source-extracted authored values solely to detect drift. These are a bounded immutable validation oracle, not a second mutable gameplay catalog. No per-validation reconstruction, sorting, hashing/serialization or per-row objects.

Add static column_source_metadata_refusal()->StringName. Success returns existing REFUSE_NONE; any mismatch returns REFUSE_COLUMN_SOURCE_METADATA = COLUMN_SOURCE_METADATA. It proves scalar ordinals/capacities and constant array lengths before indexing; proves dictionary key membership/count, exact integer types and values, row shape and field-index constants, exact canonical IDs, work/max-worker facts and exact authored delivery/upgrade bills against frozen-source-facts.json. Check source Variant types before assignment to narrower typed locals. A string numeral is not an integer; bool is not an integer. Do not call a live catalog constructor or its object-returning lookup APIs.

Direct columns_refusal follows SHAPE then SOURCE_METADATA then the stated FLAG and row gates. It calls source preflight once per whole image, never per row. Once that preflight passes and a row's TYPE gate proves the index, private static scalar readers may return work/max-workers/bill-nonempty values from the fixed constants. Upgrade lookup is a bounded scan of four IDs, not a constructed map. The bridge invokes the same source preflight at its metadata gate; no copied second fact implementation. Repeating the small read-only preflight through the pure entry point is acceptable; skipping it in direct validation is not.

## Exact bridge presentation

The bridge's gate4 detail prefix is `Construction owner1 metadata:`. Its gate7 prefix is `Construction owner 1 `. Owner/schema/framed shape refusals preserve existing family code/detail without rewriting. On COLUMN_SOURCE_METADATA, gate4 returns the family metadata code with its declared prefix. On an ordinary column refusal, gate7 returns that exact column code and the column prefix, without row identity. Success has empty code/detail. Construction Columns(false) must remain an empty borrowed view until all16 canonical assignments are complete.

## Review questions to settle before dispatch

Review the type/shape-before-access order against actual GDScript constant dictionaries and existing source indices; identify any source representation that cannot fail closed without parse/runtime errors. Confirm retained-history phase/refund rules against public retirement, cancellation and completion code. The complete independent witness table must bind clear/current/retired cases to those observed histories; the public-history probe and frozen extraction already exist. Verify that no new logical packed allocation or second full image is introduced; native constant/container overhead remains unmeasured and must not be represented as zero.

No exact total test count, passing runtime result, new game economy, clearance profile or settlement acceptance is inferred from this proposal.
