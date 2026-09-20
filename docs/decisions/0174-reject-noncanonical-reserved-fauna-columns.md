# 0174 — Reject noncanonical reserved fauna columns

Date: 2026-09-20. Status: Accepted. Contract: FAUNA-S4-VALIDATE-R01v1.

WorldInit's section 4 owner 17 stores a permanently empty reserved allocation: 384 rows, eight i32 columns and one i64 column. Every zone slot is -1, every zone generation is zero, and all seven other numerical fields are zero. GDD REQ-SET-059/065, SET-AMEND-001 section 3 and task 09.2 prohibit reviving or reinterpreting retired hunting state.

Add one static nine-argument predicate that checks every exact extent before whole-column default values. The existing `fauna_is_canonically_empty()` reader delegates to it. A framed owner bridge validates schema, metadata and physical shape before passing explicit typed columns. Both return exact refusal codes and preserve inputs. An all-zero wire frame is rejected because it does not contain null zone slots.

The bridge constructs no WorldInit or collaborator. That constructor allocates both map buffers and staging data, then stages masks; none of it belongs in save validation. No packed projection, scratch copy, catalog lookup, mutation, diagnostic write, repair or new resident allocation is added. The caller's 15,360 packed bytes remain in the existing streaming allowance; native overhead is unmeasured.

Source null sentinels and all three fauna shape constants are pinned by metadata. A clone fault must reach that guard before altered sentinels can affect column validation. Packed i64 counting was verified with the installed engine at both signed extrema and above float integer precision. Existing self-preloads are documented; import of the actual bridge remains required.

Canonical field order, versions and widths do not change. Allocation, generation, public reference-reader behavior and section 1 APIs remain unchanged. This closes a local reserved-data rule, not combined section 1/4 restoration, owner publication or full save/load. Two independent planning reviews and their dispositions are retained under `fauna-validation-planning-2026-09-20`.
