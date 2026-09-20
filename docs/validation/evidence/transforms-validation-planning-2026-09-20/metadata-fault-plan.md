# Transform metadata fault witness arithmetic

Planning only; real-engine runs and bypass evidence required after implementation. Clone schema owner15, global firstfield271. Eightfaults must retain valid Schema.schema_refusal and Section.owner_shape_refusal to isolate bridge metadata.

- Ownerkey transforms→transformz (tenASCIIbytes, order remains afterschedule andbeforework); version1→2.
- Primary15=87553 and16=511 preserve193184primarysum.
- Childextent: move owner's10existingchild to15; count10=0/15=1; childbegins11..15become4; owner10payload/block−8 andowner15+8; offsets11..15−8; offsets16/17unchanged.
- Fieldcount: moveWorkfirst i32[512] field intoTransforms. Counts15=10/16=8; begin16=281; owner15payload/block+2056 andowner16−2056; offset16+2056; later17unchanged. ExistingnineTransformfields untouched, so removingcountguard reacheslowergates withouta missing-field guardmaskingit.
- Firstfieldkeyglobal271changed toanothernonemptykey.
- Firstfieldtypeglobal271 i32→u8: widthdelta−3*87552=−262656; owner15payload/blockshiftbydelta, offsets16..17shiftbydelta; bothcompiledandexpectedsectiontotals12947565+delta. Predicateaccessorboundarraywouldbeemptyifmetadataignored; stillactualassertionfailure,noParseError.
- Firstfieldcountglobal27187552→87553: delta4; sameowner/offset/totalrebalancing.

Eachmatchingcomparisonbypassuses the schema-validcounterfactual, asserts exactSAVE_COMPONENT_METADATA andprefix. No guard removal should be credited for a parsererror or unsafe indexing. Production sourceSHAunchanged before/after clone. Baseline zeroFrameexpectsuccess, malformedSchemaforwardingexpectexactoriginaldetail. A type-or-count bypass can cause COLUMN_SHAPE, which is a valid observed assertionkill; it is not a crash.
