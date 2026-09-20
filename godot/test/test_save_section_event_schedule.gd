extends "res://test/framework/test_case.gd"
## Independent literal-byte, state and continuation checks for SAVE-S11-R01v2.
const Section := preload("res://scripts/core/save_section_event_schedule.gd")
const Events := preload("res://scripts/core/event_schedule.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Math := preload("res://scripts/core/int_math.gd")

func _record(rows: int = 1) -> Section.Record:
	var r: Section.Record = Section.Record.new()
	r.next_sequence = rows + 1
	for name: StringName in [&"kind", &"source_id", &"arg0", &"arg1", &"due_tick", &"sequence"]:
		var column: Variant = r.get(name)
		column.resize(rows)
		r.set(name, column)
	for index: int in rows:
		r.kind[index] = -index - 1
		r.source_id[index] = index + 10
		r.arg0[index] = index + 20
		r.arg1[index] = index + 30
		r.due_tick[index] = index * 100
		r.sequence[index] = index + 1
	return r

func _image(r: Section.Record) -> PackedByteArray:
	return var_to_bytes([r.next_sequence,r.kind,r.source_id,r.arg0,r.arg1,r.due_tick,r.sequence])

func _clock() -> Clock:
	var clock: Clock = Clock.new()
	assert_true(clock.acquire_load_barrier().is_ok(), "barrier acquired")
	return clock

func test_literal_empty_and_extreme_row_bytes() -> void:
	var r: Section.Record = _record(0)
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(r,out), "empty encodes")
	assert_equal(out.bytes.hex_encode(), "0100000000000000", "empty is allocator, not zero bytes")
	r.next_sequence = 0
	assert_true(Section.encode_section(r,out), "empty exhausted encodes")
	assert_equal(out.bytes.hex_encode(), "0000000000000000", "exhaustion retained")
	r = _record()
	r.next_sequence = 0
	r.kind[0] = -2147483648
	r.source_id[0] = 2147483647
	r.arg0[0] = -1
	r.arg1[0] = 0
	r.due_tick[0] = 4294967297
	r.sequence[0] = 9223372036854775807
	assert_true(Section.encode_section(r,out), "all storage extrema valid")
	assert_equal(out.bytes.hex_encode(), "000000000000000000000080ffffff7fffffffff000000000100000001000000ffffffffffffff7f", "literal little-endian field order")
	var target: Section.Record = _record(3)
	assert_true(Section.decode_section_into(out.bytes,0,40,1,1,target).is_ok(), "extreme decodes")
	assert_equal(_image(target), _image(r), "exact extreme values")

func test_full_capacity_descriptor_and_variable_length_output() -> void:
	var r: Section.Record = _record(64)
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(r,out), "full")
	assert_equal(out.bytes.size(),2056,"8+32*64")
	var count: Math.IntResult = Math.IntResult.new()
	assert_true(Section.descriptor_row_count_into(r,count), "descriptor")
	assert_equal(count.value,64,"live rows")
	var target: Section.Record = _record()
	assert_true(Section.decode_section_into(out.bytes,0,2056,64,1,target).is_ok(), "replace all shapes")
	assert_equal(_image(target),_image(r),"full parity")
	assert_false(Section.descriptor_row_count_into(null,count),"null record count refuses")
	assert_equal(count.error,"SAVE_EVENT_RECORD_NULL","null diagnostic")
	assert_equal(count.value,0,"stale count cleared")

func test_decode_bounds_precedence_and_atomic_output() -> void:
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record(),out),"valid")
	var target: Section.Record = _record(2)
	var before: PackedByteArray = _image(target)
	var cases: Array = [[-1,0,-1,99,"SAVE_EVENT_SECTION_SCHEMA"],
		[-1,0,-1,1,"SAVE_EVENT_ROW_COUNT"],[-1,0,65,1,"SAVE_EVENT_ROW_COUNT"],
		[-1,0,1,1,"SAVE_EVENT_LENGTH"],[-1,40,1,1,"SAVE_EVENT_NEGATIVE_OFFSET"],
		[9223372036854775807,40,1,1,"SAVE_EVENT_TRUNCATED"],
		[1,40,1,1,"SAVE_EVENT_TRUNCATED"]]
	for c: Array in cases:
		assert_equal(String(Section.decode_section_into(out.bytes,c[0],c[1],c[2],c[3],target).code),c[4],"precedence")
		assert_equal(_image(target),before,"target unchanged")
	for length: int in 40:
		assert_equal(Section.decode_section_into(out.bytes.slice(0,length),0,40,1,1,target).code,
			&"SAVE_EVENT_TRUNCATED","every byte truncation")
		assert_equal(_image(target),before,"truncation atomic")
	assert_equal(Section.decode_section_into(out.bytes,0,40,1,1,null).code,&"SAVE_EVENT_RECORD_NULL","null output")
	var wrapped: PackedByteArray = PackedByteArray([99,88,77])
	wrapped.append_array(out.bytes)
	wrapped.append_array(PackedByteArray([66,55]))
	var input_before: PackedByteArray = wrapped.duplicate()
	assert_true(Section.decode_section_into(wrapped,3,40,1,1,target).is_ok(),"bounded subsection")
	assert_equal(wrapped,input_before,"input not written")
	assert_equal(_image(target),_image(_record()),"exact rows")

func test_record_validation_order_and_encode_failure_clears_stale_bytes() -> void:
	var out: Section.EncodeResult = Section.EncodeResult.new()
	var r: Section.Record = _record()
	assert_true(Section.encode_section(r,out),"seed success")
	r.next_sequence = -1
	assert_false(Section.encode_section(r,out),"bad allocator")
	assert_false(out.ok,"ok cleared")
	assert_equal(out.bytes.size(),0,"bytes cleared")
	assert_equal(out.refusal,&"EVENT_RESTORE_ALLOCATOR_RANGE","owner diagnostic")
	r.kind.resize(65)
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_COUNT","count before ragged/allocator")
	r.kind.resize(2)
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_COLUMNS_RAGGED","ragged before allocator")
	r = _record(2)
	r.due_tick[0] = -1
	r.sequence[0] = 0
	assert_equal(Section.record_refusal(r).code,&"EVENT_TICK_NEGATIVE","tick before sequence")
	r.due_tick[0] = 0
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_SEQUENCE_RANGE","zero sequence")
	r.sequence[0] = 3
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_SEQUENCE_RANGE","allocator relation")
	r = _record(2)
	r.due_tick[0] = 200
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_ORDER","descending due")
	r.due_tick[0] = 0
	r.sequence[1] = 1
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_DUPLICATE_SEQUENCE","duplicate at distinct due ticks")
	r.due_tick[1] = 0
	assert_equal(Section.record_refusal(r).code,&"EVENT_RESTORE_ORDER","equal pair order before duplicate")

func test_real_continuation_preserves_consumed_ids_and_pop_order() -> void:
	var owner: Events = Events.new()
	assert_equal(owner.schedule(3,4,5,6,20,0).value,1,"first")
	assert_equal(owner.schedule(7,8,9,10,10,0).value,2,"earlier due, later sequence")
	assert_equal(owner.schedule(11,12,13,14,20,0).value,3,"equal due")
	assert_true(owner.cancel(1),"consumed identity")
	var before: PackedByteArray = owner.state_bytes()
	var r: Section.Record = _record(0)
	assert_true(Section.capture_into(owner,r).is_ok(),"live capture")
	assert_equal(owner.state_bytes(),before,"capture no canonical writes")
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(r,out),"encode")
	var decoded: Section.Record = _record(0)
	assert_true(Section.decode_section_into(out.bytes,0,72,2,1,decoded).is_ok(),"decode")
	var restored: Events = Events.new()
	assert_true(restored.schedule(99,0,0,0,30,0).ok,"old target row")
	assert_true(Section.apply(decoded,restored,_clock()).is_ok(),"apply replaces target")
	assert_equal(restored.state_bytes(),before,"unused tail and allocator exact")
	assert_equal(owner.schedule(15,0,0,0,20,0).value,4,"uninterrupted next ID")
	assert_equal(restored.schedule(15,0,0,0,20,0).value,4,"restored next ID")
	var a: Events.Event = Events.Event.new()
	var b: Events.Event = Events.Event.new()
	for expected: int in [2,3,4]:
		assert_true(owner.pop_due_into(20,a),"original pop")
		assert_true(restored.pop_due_into(20,b),"restored pop")
		assert_equal(a.sequence,expected,"ordered original")
		assert_equal(b.sequence,expected,"ordered restored")
	assert_equal(restored.state_bytes(),owner.state_bytes(),"post-continuation parity")

func test_barrier_refusals_and_invalid_apply_are_atomic() -> void:
	var owner: Events = Events.new()
	assert_true(owner.schedule(1,2,3,4,10,0).ok,"live target")
	var before: PackedByteArray = owner.state_bytes()
	var r: Section.Record = _record()
	r.next_sequence = -1
	var clock: Clock = Clock.new()
	assert_equal(Section.apply(null,null,clock).code,&"SAVE_EVENT_RECORD_NULL","record first")
	assert_equal(Section.apply(r,null,clock).code,&"SAVE_EVENT_NULL_STORE","store next")
	assert_equal(Section.apply(r,owner).code,&"SAVE_EVENT_NULL_CLOCK","clock missing")
	assert_equal(Section.apply(r,owner,clock).code,&"SAVE_EVENT_BARRIER_NOT_HELD","barrier before semantic")
	assert_true(clock.acquire_load_barrier().is_ok(),"held")
	assert_equal(Section.apply(r,owner,clock).code,&"EVENT_RESTORE_ALLOCATOR_RANGE","owner refuses")
	assert_equal(owner.state_bytes(),before,"all failed paths atomic")
	assert_true(clock.is_load_barrier_held(),"adapter retains caller barrier")

func test_exhausted_allocator_with_live_and_empty_rows_stays_exhausted() -> void:
	for rows: int in [0,1]:
		var r: Section.Record = _record(rows)
		r.next_sequence = 0
		if rows == 1:
			r.sequence[0] = 9223372036854775807
		var out: Section.EncodeResult = Section.EncodeResult.new()
		assert_true(Section.encode_section(r,out),"exhausted encode")
		var decoded: Section.Record = _record(2)
		assert_true(Section.decode_section_into(out.bytes,0,8+32*rows,rows,1,decoded).is_ok(),"exhausted decode")
		var owner: Events = Events.new()
		assert_true(Section.apply(decoded,owner,_clock()).is_ok(),"exhausted apply")
		assert_true(owner.is_sequence_exhausted(),"cursor retained")
		var before: PackedByteArray = owner.state_bytes()
		assert_false(owner.schedule(1,0,0,0,10,0).ok,"never issue after exhaustion")
		assert_equal(owner.state_bytes(),before,"refusal changes no canonical byte")

func test_copy_decode_capture_and_apply_buffers_are_independent() -> void:
	var source: Section.Record = _record(2)
	source.source_id = source.kind
	source.arg0 = source.kind
	source.arg1 = source.kind
	var target: Section.Record = _record(0)
	target.copy_from(source)
	target.kind[0] = 55
	assert_equal(target.source_id[0],-1,"aliased inputs separated")
	assert_equal(source.kind[0],-1,"source independent")
	var owner: Events = Events.new()
	assert_true(Section.apply(source,owner,_clock()).is_ok(),"apply")
	var before: PackedByteArray = owner.state_bytes()
	source.kind[0] = 66
	assert_equal(owner.state_bytes(),before,"restore copies caller")
	assert_true(Section.capture_into(owner,target).is_ok(),"capture")
	target.kind[0] = 77
	assert_equal(owner.state_bytes(),before,"capture copies owner")


func _math_image(owner: Events) -> PackedByteArray:
	var math: Object = owner.get("_math")
	return var_to_bytes([math.get("ok"),math.get("value"),math.get("error")])

func test_capture_diagnostics_and_source_failures_are_explicit() -> void:
	var owner: Events = Events.new()
	var target: Section.Record = _record(2)
	assert_false(owner.cancel(999),"establish owner refusal")
	var old_code: StringName = owner.last_refusal()
	var math: PackedByteArray = _math_image(owner)
	assert_true(Section.capture_into(owner,target).is_ok(),"empty capture")
	assert_equal(owner.last_refusal(),old_code,"empty performs no row reads")
	assert_equal(_math_image(owner),math,"scratch untouched")
	assert_true(owner.schedule(1,2,3,4,10,0).ok,"live event")
	assert_false(owner.cancel(999),"new stale diagnostic")
	math = _math_image(owner)
	assert_true(Section.capture_into(owner,target).is_ok(),"nonempty capture")
	assert_equal(owner.last_refusal(),&"","successful getter clears diagnostic")
	assert_equal(_math_image(owner),math,"nonempty scratch untouched")
	var before: PackedByteArray = _image(target)
	assert_equal(Section.capture_into(null,null).code,&"SAVE_EVENT_NULL_STORE","store before output")
	assert_equal(Section.capture_into(owner,null).code,&"SAVE_EVENT_RECORD_NULL","null output")
	for count: int in [-1,65]:
		owner.set("_count",count)
		var state: PackedByteArray = owner.state_bytes()
		assert_equal(Section.capture_into(owner,target).code,&"EVENT_RESTORE_COUNT","bad live count")
		assert_equal(owner.state_bytes(),state,"source fault unchanged")
		assert_equal(_image(target),before,"target unchanged")
	owner.set("_count",1)
	owner.set("_next_sequence",-1)
	var invalid_state: PackedByteArray = owner.state_bytes()
	assert_equal(Section.capture_into(owner,target).code,&"EVENT_RESTORE_ALLOCATOR_RANGE","invalid staged cursor")
	assert_equal(owner.state_bytes(),invalid_state,"invalid source not repaired")
	assert_equal(_image(target),before,"invalid staged source not published")

func test_semantically_invalid_wire_preserves_output_and_input_bytes() -> void:
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record(),out),"valid wire")
	var target: Section.Record = _record(2)
	var before: PackedByteArray = _image(target)
	for offset: int in [0,24,32]:
		var broken: PackedByteArray = out.bytes.duplicate()
		broken.encode_s64(offset,-1 if offset != 32 else 0)
		var input_before: PackedByteArray = broken.duplicate()
		var expected: StringName = &"EVENT_RESTORE_ALLOCATOR_RANGE" if offset == 0 else (
			&"EVENT_TICK_NEGATIVE" if offset == 24 else &"EVENT_RESTORE_SEQUENCE_RANGE")
		assert_equal(Section.decode_section_into(broken,0,40,1,1,target).code,expected,"parsed semantic refusal")
		assert_equal(_image(target),before,"no partial scalar/column publication")
		assert_equal(broken,input_before,"bad bytes unchanged")
	var prior_kind: PackedInt32Array = target.kind
	assert_true(Section.decode_section_into(out.bytes,0,40,1,1,target).is_ok(),"decode success")
	out.bytes.fill(0)
	assert_equal(target.kind[0],-1,"decoded array independent of input bytes")
	assert_equal(prior_kind.size(),2,"prior held output remains previous array")


func test_empty_high_allocator_issues_the_saved_next_identity() -> void:
	var r: Section.Record = _record(0)
	r.next_sequence = 500
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(r,out),"empty high cursor")
	assert_equal(out.bytes.hex_encode(),"f401000000000000","literal cursor500")
	var decoded: Section.Record = _record(2)
	assert_true(Section.decode_section_into(out.bytes,0,8,0,1,decoded).is_ok(),"no rows needed to retain cursor")
	var owner: Events = Events.new()
	assert_true(Section.apply(decoded,owner,_clock()).is_ok(),"restore high cursor")
	assert_equal(owner.next_sequence(),500,"not inferred from empty rows")
	assert_equal(owner.schedule(1,0,0,0,10,0).value,500,"next identity preserved")


func test_offset_at_exact_buffer_end_refuses_without_publication() -> void:
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record(),out),"one record")
	var target: Section.Record = _record(2)
	var before: PackedByteArray = _image(target)
	assert_equal(Section.decode_section_into(out.bytes,out.bytes.size(),40,1,1,target).code,
		&"SAVE_EVENT_TRUNCATED","zero bytes remaining at exact end")
	assert_equal(_image(target),before,"output unchanged")
