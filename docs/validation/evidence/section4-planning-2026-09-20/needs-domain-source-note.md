# Needs validation follow-through: source observation only

Source SHA256: 31fc6a56d294154024f39ff4f04924d9c2148fc4f08acee388fd6ea94595d553

The existing Needs `_restore_column_refusal` at1977 checks shape, byte domains, value domains, inactive-row obligations, then the recomputed living cap. Its helpers appear to read only supplied Columns and constants; a pure API extraction may be possible without an extra live Needs object. This is a feasibility observation, not an accepted refactor packet.

Crucially, `_column_value_domain_refusal` at2025 currently accepts departure_days in0..INT32MAX; it does NOT require zero despite older reserved-column comments. `_free_row_is_clear` at2074 checks DEAD status, health/cold/starvation values and every need value/remainder, but intentionally leaves size/environment residue alone. Do not freeze a blanket unused-row blank or a reserved-zero rule from a comment without resolving this actual accepted API behavior against the owning contracts.

The semantic lane must review that distinction and the complete call graph before dispatch. The streaming envelope remains agnostic to these values and cannot certify their meaning.
