# Parent feasibility notes — not implementation acceptance

The current approved ledger is78393899bytes including8388608reserve. The pure checker conservatively charges4230440private packed bytes, plus6343524Directory Record,148768caller projections and449024Fish/Forage claim values (including counts/framing separately). Do not keep all section4 records12944480bytes resident simultaneously with that validation set.

A section4 owner-at-a-time decoder can stage at most construction4893696valuebytes, with a65536byte input window and fixed framing. A private owner Record plus at most a copied full owner publication (2*4893696=9787392) and the Directory6343524 is16130916bytes before windows/metadata, below21606101current ledger headroom. Prefer transfer of private packed columns by copy-on-write publication to avoid the second full copy. Owner and Directory liveness must be explicit; this arithmetic is a candidate lifetime schedule, not RSS/native overhead certification.

Semantic validation and cross-owner validation cannot be skipped: local owner domains on the fully staged private owner; saved-file cross-store joins from retained bounded projections/on-disk indexes; all-world publication only after all sections and digest validated. No new world objects are created just to invoke validators. The section4 codec may expose a single OwnerRecord and stream state rather than a13MBsection Record. APIs returning framed/decoded fields must label that status, not call it world-valid.

Existing section3/7 ChunkCursor paths are output streaming only. Their decode_into methods require whole byte buffers and are not a source for a bounded file decoder. SaveCodec.Reader is also buffer-owned and sticky on truncation; arbitrary chunk boundaries require a new bounded state machine or a source interface, not resetting Reader and silently dropping a split integer. Domain validators must not derive counts from hostile bytes before checking fixed schema.

A proposed section4 schema reuses child_extent_count:u32 plus fixed u64child extents, with five independently sized child tables; see proposed-layout.json. Fixed stride fields do not add independent extents. This adds112bytes to the tentative ordinary-census format. Exact primary counts are explicit rather than inferred from the first field. This remains pending review of source and REG-R01 interpretation.

## Exact cold-phase candidate arithmetic

With the existing live-plus-reserve ledger78393899, one private construction OwnerRecord4893696, Directory Record6343524 and two65536windows yield89762191bytes before schema metadata/native overhead (headroom10237809). If publication needlessly copied the entire construction owner again,94655887/headroom5344113 remains arithmetically below100MB, but such copying is not accepted as a permanent design. No13MBsection Record or whole-section wire buffer is allowed in this phase.

The claim-checking phase, after releasing the staged component owner, needs Directory6343524 +checker4230440 +projections148768 +claimvaluearrays449024 +two65536windows:89696727bytes including live-plus-reserve. These phases do not overlap their largest scratch. Saved claims' wrapper metadata and native objects remain unmeasured; the original reserve is not an extra allowance to count twice.

## Existing owner validation is not a pure wire validator

Source census finds complete bulk column APIs only on residents, needs, jobs. Their `_restore_column_refusal` methods are instance-private and restore invokes them before installation; residents validates against its bound Directory, jobs also against bound residents. Calling restore on disposable full stores would create extra mutable owners and risks accepting against the wrong world. A subsequent semantic lane must expose/reuse pure validation against explicit saved projections or disk joins, retaining the exact existing domains. Jobs section4+section5 remains one atomic owner apply; residents names still bind across section4+14. This codec phase cannot mark those bindings complete.

Exact unused-value evidence: needs.Columns.clear uses STATUS_DEAD and clothing tier1, while resident despawn retains species, skills and arrival tick; copying includes these bytes. Module clear defaults are not necessarily legal blanket retirement normalization. The wire path preserves every registered full-capacity field verbatim and must not compact physical rows.
