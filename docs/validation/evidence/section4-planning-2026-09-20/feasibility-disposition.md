# Astra feasibility disposition — 2026-09-20

Accept the verified18owner/298field byte census, primary/child mappings and+112byte child-extent framing. Proposed exact section12947565bytes, descriptor row_count193184. The framing will retain current section4schema2: this freezes its first implemented body, not a reinterpretation of previously emitted bytes. Field/schema counts remain those of registry6. A versioned engineering decision will own this adoption before implementation.

Reviewer findings are not all new blockers:

- Findings1/2: correct warnings. Section-local primary/schema metadata must come from the section4declaration, not similarly named section1/7owner constants. No source contradiction requires altering those existing constants.
- Finding3/R3: buildings reference/chain fields are ALREADY declared in section5. Exact registry fields: _b_ref_slot,_b_ref_generation,_b_room_head,_b_room_count,_r_ref_slot,_r_ref_generation,_r_building_next,_r_building_prev,_r_furniture_head,_r_furniture_count,_f_ref_slot,_f_ref_generation,_f_room_next,_f_room_prev,_room_tile_id. The packet omitted that registry slice. No new generation/duplicatefield/schema relocation is authorized. Atomic buildings4+5apply must be included alongside jobs4+5.
- Finding4/R6: settled by accepted ADR0166/0168 and SAVE-CLAIM-CHECK-R01v2. Both totals are saved canonical state, checked against claims without rebuilding/normalizing. Old cache comments/helpers are not current save authority. They may not be silently removed from the298fields.
- Finding8/R5: REFUTED by supplied SAVE-LAYOUT-R01: section4descriptor row_count is explicitly the checked sum of block primary_count. The proposed sum193184 is intentionally not a unique-entity census. Section7 ambiguity does not override this explicitsection4ruling.
- Finding5/R7: preserve actual current reserved-field domains and compatibility rules. Source-backed per-owner semantic contracts must inspect current methods; framing alone does not grant semantic acceptance.
- Finding7: retain current section4owner versions; no module-level schema alias.
- Eight fixed-stride relations were listed under the review's word 'Seven'; exact table has fishing,forage,field_policy,needs,residents,priorities,schedule,work. Use all eight.
- Fishing inactive used-total cannot remain nonzero through ordinary destroy: destroy_habitat refuses when used>0 before changing anything. Retained capacity/type/etc are real residue. Do not turn generic retained-byte observations into a claim that any unused arbitrary value is valid.

The proposed per-owner structure is useful, but a SectionCursor(record) requiring all18decoded owners would retain a second13MBsection. The actual streaming interface must hold at most one owner's private record, plus bounded windows; full-buffer helpers must not be the production disk path. A no-allocation framing subtask is allowed only with explicit incomplete SAVE-S4-CODEC status and named semantic/bulk/API follow-through.

Next: freeze exact envelope/interface contract; independently review it before Claude implementation. Publish source-backed owner/API work and semantic gates. No whole-save or native-memory qualification follows from this report.
