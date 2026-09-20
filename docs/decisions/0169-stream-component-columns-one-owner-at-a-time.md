# 0169 — Stream component columns one owner at a time

Date: 2026-09-20 · Status: Accepted SAVE-S4-STREAM-R01v2

Section4 has298 canonical fields across18 owners, but no production byte codec. Holding its entire13MB body and decoded records beside the live world would undermine the selected disk-backed validation/rollback architecture.

Adopt the explicit component_columns_layout.json as the initial section4schema2 body: column-major owner blocks, exact fixed primary/child extents,193184 descriptor rows and12947565 bytes. Later REG-R01 LifeStage composition already advanced section4 from its historical initialschema1. No previously emitted section4format is reinterpreted; owner/registry/canonical fields remain unchanged.

Implement a bounded streaming envelope with one FramedOwner at a time. Both cursors use exact field-aligned fragments up to65536bytes; the decoder checks constant framing before allocating and releases a record only after all its fields arrive. Errors remain sticky, with no partial record publication. A framed record is not semantically valid and cannot authorize world publication.

Compile metadata from the explicit layout plus canonical registry, with an independent fresh source-capacity proof for all298counts. Runtime reads no JSON and touches no live owner. Preserve every physical row and declared value verbatim; saved resource totals remain checked state under ADR0168, not caches to rebuild.

The6417408-byte conservative owner/transient bound is conditional on the caller releasing all references before feeding the next owner. Immutable metadata/native overhead is accounted separately; this is not measured memory qualification. Full section4 acceptance still requires semantic validators and owner adapters, including all coupled sections listed in the contract. Add those explicit prerequisites rather than marking the parent task complete when framing alone passes.

Implementation accounting: separately charge the actual immutable table logical payload781 int64 cells +4288 UTF8 key bytes =10536. The new shared row advances planned payload to70015827 and live plus reserve to78404435; exclude the whole row from candidate mutable state, which remains63770659. Array/Variant/String headers, scalar constants and native code are outside this logical payload and still require runtime measurement. The stream's6417408 conditional transient bound is unchanged.
