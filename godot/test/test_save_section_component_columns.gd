extends "res://test/framework/test_case.gd"
## Pure structural wire fixtures; these patterns are deliberately not valid gameplay worlds.
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const MIN64: int = -9223372036854775807 - 1
const MAX64: int = 9223372036854775807
const ZERO_SHA: String = "81a3c13ad70f9bf3678a93c58232b6c4f7f657490d055158c5a44ae7a66950d8"
const PATTERN_SHA: String = "1f38602203f4b3ba2897b9b71444904144b69c5546515a4868b26e14abe94037"

func _value(owner: int, field: int, row: int, kind: int) -> int:
	var n: int = owner * 100003 + field * 701 + row * 17
	if kind == 0: return n % 256
	if row == 0: return -2147483648 if kind == 2 else MIN64
	if row == 1: return 2147483647 if kind == 2 else MAX64
	if row == 2: return -1
	if kind == 4: n *= 1000000007
	return -n if row % 2 else n

func _record(owner: int, patterned: bool) -> Section.FramedOwner:
	var record: Section.FramedOwner = Section.FramedOwner.new(owner)
	if not patterned: return record
	for field: int in Schema.field_count(owner):
		var kind: int = Schema.field_type(owner,field)
		var count: int = Schema.element_count(owner,field)
		if kind == 0:
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(count)
			for row: int in count: bytes[row] = _value(owner,field,row,kind)
			assert_true(record.set_u8(field,bytes), "pattern byte column assigned")
		elif kind == 2:
			var words: PackedInt32Array = PackedInt32Array()
			words.resize(count)
			for row: int in count: words[row] = _value(owner,field,row,kind)
			assert_true(record.set_i32(field,words), "pattern signed32 column assigned")
		else:
			var longs: PackedInt64Array = PackedInt64Array()
			longs.resize(count)
			for row: int in count: longs[row] = _value(owner,field,row,kind)
			assert_true(record.set_i64(field,longs), "pattern signed64 column assigned")
	return record

func _same_columns(actual: Section.FramedOwner, expected: Section.FramedOwner) -> void:
	assert_equal(actual.owner,expected.owner,"decoded owner identity")
	for field: int in Schema.field_count(expected.owner):
		var kind: int = Schema.field_type(expected.owner,field)
		if kind == 0:
			assert_true(actual.u8_column(field) == expected.u8_column(field),
				"exact byte column owner%d field%d" % [expected.owner,field])
		elif kind == 2:
			assert_true(actual.i32_column(field) == expected.i32_column(field),
				"exact signed32 column owner%d field%d" % [expected.owner,field])
		else:
			assert_true(actual.i64_column(field) == expected.i64_column(field),
				"exact signed64 column owner%d field%d" % [expected.owner,field])

func _stream_round_trip(patterned: bool, expected_sha: String) -> void:
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(2,193184)
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	var chunk: Section.WireChunk = Section.WireChunk.new()
	var result: Section.OwnerResult = Section.OwnerResult.new()
	var expected: Section.FramedOwner = null
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var largest: int = 0
	var owners: int = 0
	var fragments: int = 0
	while encoder.has_more():
		if encoder.needs_owner():
			expected = _record(encoder.owner_index(),patterned)
			assert_true(encoder.bind_owner(expected).is_ok(),"bind one frozen owner")
		assert_true(encoder.next_chunk_into(chunk),"emit fragment: " + chunk.detail)
		if not chunk.is_ok(): return
		assert_true(chunk.bytes.size() > 0 and chunk.bytes.size() <= 65536,"bounded nonempty fragment")
		largest = maxi(largest,chunk.bytes.size())
		fragments += 1
		digest.update(chunk.bytes)
		assert_equal(decoder.next_read_size(),chunk.bytes.size(),"exact fragment request")
		var before: PackedByteArray = chunk.bytes.duplicate()
		var accepted: bool = decoder.accept_chunk(chunk.bytes).is_ok()
		assert_true(accepted,"decode fragment")
		if not accepted: return
		assert_equal(chunk.bytes,before,"caller input unchanged")
		if decoder.owner_ready():
			assert_equal(decoder.next_read_size(),0,"transfer required before more input")
			assert_true(decoder.take_owner_into(result),"only complete owner transferred")
			assert_true(result.is_ok(),"owner output holds a record")
			if not result.is_ok(): return
			_same_columns(result.record,expected)
			owners += 1
			assert_equal(encoder.emitted_bytes(),decoder.consumed_bytes(),"owner boundary offsets agree")
			# Two records coexist only for this comparison fixture; neither is a live world.
			expected = null
			result.record = null
	assert_equal(owners,18,"all owners transferred exactly once")
	assert_true(fragments > 600,"field framing is streamed, not one section buffer")
	assert_equal(largest,65536,"full-size fragments are exercised")
	assert_equal(encoder.emitted_bytes(),12947565,"literal full wire bytes")
	assert_equal(decoder.consumed_bytes(),12947565,"literal decoded bytes")
	assert_true(encoder.is_complete() and decoder.is_complete(),"both streams complete")
	assert_true(encoder.finish().is_ok() and decoder.finish().is_ok(),"explicit completion")
	assert_equal(digest.finish().hex_encode(),expected_sha,"independent Python whole-section golden")
	assert_false(encoder.has_more(),"complete encoder has no more fragments")
	assert_false(encoder.needs_owner(),"complete encoder requests no owner")
	assert_equal(encoder.owner_index(),18,"one-past final owner")
	assert_equal(decoder.next_read_size(),0,"complete decoder requests nothing")
	assert_false(encoder.next_chunk_into(chunk),"extra encode refuses")
	assert_equal(chunk.code,&"SAVE_COMPONENT_STATE","extra encode state error")
	assert_true(chunk.bytes.is_empty(),"extra encode clears old output")
	assert_equal(encoder.emitted_bytes(),12947565,"extra encode emits nothing")
	assert_equal(decoder.accept_chunk(PackedByteArray([0])).code,
		&"SAVE_COMPONENT_STATE","extra input checked before size")
	assert_equal(decoder.consumed_bytes(),12947565,"extra input consumes nothing")

func test_zero_wire_stream_matches_independent_bytes() -> void:
	_stream_round_trip(false,ZERO_SHA)

func test_signed_boundary_pattern_stream_preserves_every_column() -> void:
	_stream_round_trip(true,PATTERN_SHA)

func test_descriptor_preflight_refuses_before_any_fragment() -> void:
	for schema: int in PackedInt32Array([0,1,3]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(schema,193184,12947565)
		assert_equal(decoder.refusal().code,&"SAVE_COMPONENT_SCHEMA","section schema is external metadata")
		assert_equal(decoder.next_read_size(),0,"no allocation request after bad schema")
	for count: int in PackedInt32Array([0,193183,193185]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,count,12947565)
		assert_equal(decoder.refusal().code,&"SAVE_COMPONENT_DESCRIPTOR","exact primary sum")
	for length: int in PackedInt64Array([-1,0,12947564,12947566,MAX64]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,length)
		assert_equal(decoder.refusal().code,&"SAVE_COMPONENT_LENGTH","exact descriptor byte extent")
		assert_equal(decoder.next_read_size(),0,"no fragment after bad length")
		assert_equal(decoder.consumed_bytes(),0,"preflight consumed nothing")
	var both: Section.DecodeCursor = Section.DecodeCursor.new(1,0,0)
	assert_equal(both.refusal().code,&"SAVE_COMPONENT_SCHEMA","schema precedes row/length failures")

func test_initial_decode_read_sizes_are_literal_protocol_boundaries() -> void:
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	assert_equal(decoder.next_read_size(),4,"store_count comes first")
	assert_true(decoder.accept_chunk(PackedByteArray([18,0,0,0])).is_ok(),"literal store_count")
	assert_equal(decoder.next_read_size(),53,"Buildings wrapper includes both child extents")
	var pins: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../docs/validation/evidence/section4-planning-2026-09-20/independent-wire-goldens.json")) as Dictionary
	var framing: PackedByteArray = String(pins["fixtures"][0]["owner_framing"][0]["framing_hex"]).hex_decode()
	assert_true(decoder.accept_chunk(framing).is_ok(),"independent literal Buildings wrapper")
	assert_equal(decoder.next_read_size(),8,"first element-count prefix")
	var out: Section.OwnerResult = Section.OwnerResult.new()
	assert_false(decoder.take_owner_into(out),"framing alone cannot publish partial owner")
	assert_equal(out.code,&"SAVE_COMPONENT_STATE","partial publication refuses")
	assert_true(out.record == null,"partial columns never escape")

func _building_wrapper() -> PackedByteArray:
	var pins: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../docs/validation/evidence/section4-planning-2026-09-20/independent-wire-goldens.json")) as Dictionary
	return String(pins["fixtures"][0]["owner_framing"][0]["framing_hex"]).hex_decode()

func test_each_wrapper_member_is_checked_before_owner_allocation() -> void:
	# Offsets are literal Buildings framing, independently emitted by Python.
	for offset: int in PackedInt32Array([0,4,13,17,24,25,32,33,37,44,45,52]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
		assert_true(decoder.accept_chunk(PackedByteArray([18,0,0,0])).is_ok(),"valid section count")
		var bad: PackedByteArray = _building_wrapper()
		bad[offset] = bad[offset] ^ 1
		var before: PackedByteArray = bad.duplicate()
		assert_equal(decoder.accept_chunk(bad).code,&"SAVE_COMPONENT_FRAME","malformed wrapper member refuses")
		assert_equal(bad,before,"hostile input preserved")
		assert_equal(decoder.consumed_bytes(),4,"bad wrapper never advances accepted offset")
		assert_equal(decoder.next_read_size(),0,"failed cursor requests no column input")
		var out: Section.OwnerResult = Section.OwnerResult.new()
		assert_false(decoder.take_owner_into(out),"no allocation escapes a bad wrapper")
		assert_true(out.record == null,"no partial owner output")
		assert_equal(out.code,&"SAVE_COMPONENT_FRAME","first error stays sticky")
		assert_equal(decoder.finish().code,&"SAVE_COMPONENT_FRAME","finish preserves first refusal")

func test_fragment_sizes_and_early_finish_do_not_advance() -> void:
	for size: int in PackedInt32Array([0,3,5,65536]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(size)
		assert_equal(decoder.accept_chunk(bytes).code,&"SAVE_COMPONENT_CHUNK","exact requested size required")
		assert_equal(decoder.consumed_bytes(),0,"bad fragment consumes nothing")
		assert_equal(decoder.accept_chunk(PackedByteArray([18,0,0,0])).code,
			&"SAVE_COMPONENT_CHUNK","later correct data cannot revive failed cursor")
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	assert_equal(decoder.finish().code,&"SAVE_COMPONENT_TRUNCATED","early finish explicitly refuses")
	assert_false(decoder.is_complete(),"empty input never complete")

func test_encoder_requires_expected_owner_and_complete_shape() -> void:
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(2,193184)
	var chunk: Section.WireChunk = Section.WireChunk.new()
	assert_true(encoder.next_chunk_into(chunk),"section prefix")
	assert_equal(chunk.bytes,PackedByteArray([18,0,0,0]),"literal prefix")
	assert_true(encoder.needs_owner(),"first owner must be bound")
	var wrong: Section.FramedOwner = Section.FramedOwner.new(1)
	assert_equal(encoder.bind_owner(wrong).code,&"SAVE_COMPONENT_OWNER","owner order is enforced")
	assert_equal(encoder.emitted_bytes(),4,"wrong owner emits nothing")
	assert_false(encoder.next_chunk_into(chunk),"sticky binding refusal")
	assert_equal(chunk.code,&"SAVE_COMPONENT_OWNER","output and cursor agree")
	assert_true(chunk.bytes.is_empty(),"refusal clears previous chunk")
	encoder = Section.EncodeCursor.new(2,193184)
	assert_true(encoder.next_chunk_into(chunk),"new cursor starts independently")
	var malformed: Section.FramedOwner = Section.FramedOwner.new(0)
	var shortened: PackedByteArray = PackedByteArray([0])
	malformed.u8_columns[0] = shortened
	assert_false(Section.owner_shape_refusal(malformed).is_ok(),"fixture has wrong physical extent")
	assert_equal(encoder.bind_owner(malformed).code,&"SAVE_COMPONENT_SHAPE","all columns preflighted before borrow")

func test_setters_snapshot_input_and_refuse_type_or_extent_without_changes() -> void:
	var record: Section.FramedOwner = Section.FramedOwner.new(0)
	var values: PackedByteArray = PackedByteArray()
	values.resize(1024)
	values[0] = 255
	assert_true(record.set_u8(0,values),"u8 covers all representable bits, not just boolean")
	values[0] = 17
	assert_equal(record.u8_column(0)[0],255,"setter snapshots caller input")
	var before: PackedByteArray = record.u8_column(0).duplicate()
	assert_false(record.set_u8(0,PackedByteArray([1])),"short column refuses")
	assert_false(record.set_i32(0,PackedInt32Array()),"wrong setter type refuses")
	assert_false(record.set_u8(-1,before),"invalid ordinal refuses")
	assert_equal(record.u8_column(0),before,"all refused setters preserve the column")
	assert_true(record.i32_column(0).is_empty(),"wrong-type accessor returns no neighbour")
	assert_true(record.u8_column(-1).is_empty(),"invalid accessor is bounded")
	assert_true(record.u8_column(29).is_empty(),"one-past accessor is bounded")
	var invalid: Section.FramedOwner = Section.FramedOwner.new(-1)
	assert_equal(invalid.owner,-1,"invalid record cannot masquerade as first owner")
	assert_true(invalid.u8_columns.is_empty() and invalid.i32_columns.is_empty()
		and invalid.i64_columns.is_empty(),"invalid construction allocates no field arrays")
	assert_false(Section.owner_shape_refusal(invalid).is_ok(),"invalid record shape refuses")

func test_field_count_must_match_before_values() -> void:
	for offset: int in PackedInt32Array([0,1,7]):
		var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
		assert_true(decoder.accept_chunk(PackedByteArray([18,0,0,0])).is_ok(),"section prefix")
		assert_true(decoder.accept_chunk(_building_wrapper()).is_ok(),"whole wrapper")
		var count: PackedByteArray = PackedByteArray([0,4,0,0,0,0,0,0])
		count[offset] = count[offset] ^ 1
		assert_equal(decoder.accept_chunk(count).code,&"SAVE_COMPONENT_FRAME","full u64 count checked")
		assert_equal(decoder.consumed_bytes(),57,"bad count consumes no bytes")
		assert_false(decoder.owner_ready(),"no owner escapes field-count refusal")

func test_null_outputs_and_wrong_states_are_sticky() -> void:
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(2,193184)
	assert_false(encoder.next_chunk_into(null),"null chunk safely refuses")
	assert_equal(encoder.refusal().code,&"SAVE_COMPONENT_STATE","null encoder output is state error")
	assert_equal(encoder.emitted_bytes(),0,"null output makes no progress")
	var chunk: Section.WireChunk = Section.WireChunk.new()
	chunk.bytes = PackedByteArray([99])
	assert_false(encoder.next_chunk_into(chunk),"valid output cannot revive failed cursor")
	assert_equal(chunk.code,encoder.refusal().code,"same sticky code")
	assert_equal(chunk.detail,encoder.refusal().detail,"same sticky detail")
	assert_true(chunk.bytes.is_empty(),"stale output bytes cleared")
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	assert_false(decoder.take_owner_into(null),"null owner output safely refuses")
	assert_equal(decoder.refusal().code,&"SAVE_COMPONENT_STATE","null decoder output is state error")
	assert_equal(decoder.consumed_bytes(),0,"null output consumes nothing")
	encoder = Section.EncodeCursor.new(2,193184)
	assert_true(encoder.next_chunk_into(chunk),"initial count does not need owner")
	assert_false(encoder.next_chunk_into(chunk),"waiting for bind refuses next")
	assert_equal(encoder.refusal().code,&"SAVE_COMPONENT_STATE","bind is required")
	assert_equal(encoder.emitted_bytes(),4,"waiting refusal emits nothing")

func test_encoder_preflight_early_bind_and_finish() -> void:
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(1,0)
	assert_equal(encoder.refusal().code,&"SAVE_COMPONENT_SCHEMA","schema first")
	encoder = Section.EncodeCursor.new(2,0)
	assert_equal(encoder.refusal().code,&"SAVE_COMPONENT_DESCRIPTOR","exact descriptor rows")
	encoder = Section.EncodeCursor.new(2,193184)
	assert_false(encoder.needs_owner(),"owner cannot precede store count")
	assert_equal(encoder.bind_owner(Section.FramedOwner.new(0)).code,
		&"SAVE_COMPONENT_STATE","early bind refuses")
	encoder = Section.EncodeCursor.new(2,193184)
	assert_equal(encoder.finish().code,&"SAVE_COMPONENT_TRUNCATED","early encoder finish refuses")
	assert_false(encoder.has_more(),"failed encoder is single-use")
	assert_false(encoder.is_complete(),"truncation cannot become completion")

func _ready_first_owner() -> Section.DecodeCursor:
	"""Feed exactly Buildings with production encoder; independent golden checks live elsewhere."""
	var encoder: Section.EncodeCursor = Section.EncodeCursor.new(2,193184)
	var decoder: Section.DecodeCursor = Section.DecodeCursor.new(2,193184,12947565)
	var chunk: Section.WireChunk = Section.WireChunk.new()
	while not decoder.owner_ready():
		if encoder.needs_owner():
			assert_true(encoder.bind_owner(_record(0,true)).is_ok(),"patterned Buildings")
		if not encoder.next_chunk_into(chunk):
			assert_true(false,"fixture encoder unexpectedly refused")
			return decoder
		if not decoder.accept_chunk(chunk.bytes).is_ok():
			assert_true(false,"fixture decoder unexpectedly refused")
			return decoder
	return decoder

func test_ready_owner_requires_transfer_before_any_more_input() -> void:
	var decoder: Section.DecodeCursor = _ready_first_owner()
	assert_true(decoder.owner_ready(),"complete Buildings ready")
	assert_equal(decoder.consumed_bytes(),3298593,"literal next-owner boundary")
	assert_equal(decoder.next_read_size(),0,"no next wrapper before transfer")
	assert_equal(decoder.accept_chunk(PackedByteArray()).code,
		&"SAVE_COMPONENT_STATE","state checked before zero chunk size")
	assert_false(decoder.owner_ready(),"failure discards untaken record")
	var out: Section.OwnerResult = Section.OwnerResult.new()
	assert_false(decoder.take_owner_into(out),"discarded record cannot escape")
	assert_true(out.record == null,"no completed but refused publication")

func test_transferred_record_survives_later_refusal() -> void:
	var decoder: Section.DecodeCursor = _ready_first_owner()
	var out: Section.OwnerResult = Section.OwnerResult.new()
	assert_true(decoder.take_owner_into(out),"first owner transferred")
	if out.record == null: return
	var retained: Section.FramedOwner = out.record
	var first: PackedByteArray = retained.u8_column(0).duplicate()
	var last: PackedInt32Array = retained.i32_column(28).duplicate()
	assert_equal(decoder.next_read_size(),40,"Construction wrapper width")
	# A double take refuses and clears the reused output; separate caller reference survives.
	assert_false(decoder.take_owner_into(out),"double transfer refuses")
	assert_true(out.record == null,"reused refused output is cleared")
	assert_equal(out.code,&"SAVE_COMPONENT_STATE","same sticky state code")
	assert_equal(retained.u8_column(0),first,"prior u8 values unchanged")
	assert_equal(retained.i32_column(28),last,"prior last column unchanged")
	assert_equal(decoder.consumed_bytes(),3298593,"failure retains accepted offset")

func test_typed_setters_snapshot_signed_extrema_and_shape_checks_buckets() -> void:
	var record: Section.FramedOwner = Section.FramedOwner.new(1)
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(82944)
	ints[0] = -2147483648
	assert_true(record.set_i32(1,ints),"Construction material container slot i32")
	ints[0] = 7
	assert_equal(record.i32_column(1)[0],-2147483648,"i32 setter snapshots")
	var longs: PackedInt64Array = PackedInt64Array()
	longs.resize(82944)
	longs[0] = MIN64
	longs[1] = MAX64
	assert_true(record.set_i64(6,longs),"Construction remaining work i64")
	longs[0] = 9
	assert_equal(record.i64_column(6)[0],MIN64,"i64 setter snapshots")
	assert_equal(record.i64_column(6)[1],MAX64,"signed max preserved")
	assert_false(record.set_i64(6,PackedInt64Array([1])),"wrong i64 extent")
	assert_false(record.set_i32(6,ints),"wrong i32 type")
	assert_true(record.i64_column(1).is_empty(),"wrong signed bucket accessor")
	assert_true(Section.owner_shape_refusal(record).is_ok(),"complete original buckets")
	record.i64_columns.clear()
	assert_equal(Section.owner_shape_refusal(record).code,&"SAVE_COMPONENT_SHAPE","missing bucket refuses")
	assert_equal(Section.owner_shape_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null record refuses")

func test_component_sources_keep_integer_conversion_paths() -> void:
	"""ARCH-AUTH-002: no floating-point conversion enters either codec source."""
	for path: String in ["res://scripts/core/save_component_columns_schema.gd",
			"res://scripts/core/save_section_component_columns.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(),"inspect actual component source")
		for banned: String in ["encode_float", "decode_float", "encode_double", "decode_double",
				"encode_half", "decode_half", "PackedFloat32Array", "PackedFloat64Array", ": float", "-> float"]:
			assert_false(source.contains(banned),"no floating path " + banned)
	assert_true(Section.byte_order_refusal().is_ok(),"actual host passes its conversion probe")
