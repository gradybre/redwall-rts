extends RefCounted
## Reference-control checkpoint codec. This is not the release RWL-SAVE format.

const MAGIC: String = "RWLCTRL1"
const MAX_PAYLOAD_BYTES: int = 1048576
const FIELDS: Array[StringName] = [
	&"recovery", &"size", &"need", &"counters", &"health", &"alive", &"state", &"until_tick", &"woken", &"food_np",
	&"skill_xp", &"xp_remainder", &"work_numerator", &"job_owner", &"job_remaining", &"job_np", &"job_travel_end",
	&"job_quality", &"job_sequence", &"next_job_sequence", &"meals", &"rations", &"roots", &"grain", &"water", &"wood",
	&"tick", &"rng", &"events", &"days", &"produced", &"consumed_np", &"spoiled_np", &"lost_np", &"food_surplus",
	&"heat_remainder", &"collapse_tick", &"stable_count", &"stable_day", &"initial_np"
]


static func hash_bytes(data: PackedByteArray) -> PackedByteArray:
	## Hash exact bytes without passing through JSON number conversion.
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	assert(start_error == OK)
	var update_error: Error = context.update(data)
	assert(update_error == OK)
	return context.finish()


static func encode(world: RefCounted) -> PackedByteArray:
	## Stable named-field order captures every mutable script property.
	var values: Array = []
	for key: StringName in FIELDS:
		values.append(world.get(key))
	var payload: PackedByteArray = var_to_bytes(values)
	assert(payload.size() <= MAX_PAYLOAD_BYTES)
	var output: PackedByteArray = MAGIC.to_ascii_buffer()
	output.resize(12)
	output.encode_u32(8, payload.size())
	output.append_array(hash_bytes(payload))
	output.append_array(payload)
	return output


static func digest(world: RefCounted) -> String:
	## Canonical only for this pinned-engine control schema, not the release schema.
	return hash_bytes(encode(world)).hex_encode()


static func restore(world: RefCounted, data: PackedByteArray) -> bool:
	## Reject damaged or incompatible envelopes before mutating any world field.
	if data.size() < 44 or data.slice(0, 8).get_string_from_ascii() != MAGIC:
		return false
	var length: int = data.decode_u32(8)
	if length > MAX_PAYLOAD_BYTES or data.size() != 44 + length:
		return false
	var payload: PackedByteArray = data.slice(44)
	if hash_bytes(payload) != data.slice(12, 44):
		return false
	var decoded: Variant = bytes_to_var(payload)
	if not decoded is Array or decoded.size() != FIELDS.size():
		return false
	for index: int in range(FIELDS.size()):
		if not field_compatible(world, FIELDS[index], decoded[index]):
			return false
	for index: int in range(FIELDS.size()):
		world.set(FIELDS[index], decoded[index])
	return true


static func field_compatible(world: RefCounted, key: StringName, actual: Variant) -> bool:
	## Variable histories/lots can differ in length from the current world's lists.
	if key == &"meals":
		if not actual is Array or actual.size() > 7:
			return false
		for meal: Variant in actual:
			if not meal is PackedInt64Array or meal.size() != 4:
				return false
		return true
	if key == &"events" or key == &"days":
		if not actual is Array or actual.size() > 13:
			return false
		for row: Variant in actual:
			if not row is Dictionary:
				return false
		return true
	return compatible(world.get(key), actual)


static func compatible(expected: Variant, actual: Variant) -> bool:
	## Validate fixed column shapes/types recursively; variable report/meal arrays vary.
	if typeof(expected) != typeof(actual):
		return false
	if expected is PackedInt64Array or expected is PackedInt32Array or expected is PackedByteArray:
		return expected.size() == actual.size()
	if expected is Dictionary:
		if expected.size() != actual.size():
			return false
		for key: Variant in expected:
			if not actual.has(key) or not compatible(expected[key], actual[key]):
				return false
	if expected is Array and not expected.is_empty():
		if expected.size() != actual.size():
			return false
		for index: int in range(expected.size()):
			if not compatible(expected[index], actual[index]):
				return false
	return true


static func audit_field_coverage(world: RefCounted) -> bool:
	## Fail when a future mutable field is added without checkpoint participation.
	var found: Array[StringName] = []
	for entry: Dictionary in world.get_property_list():
		if (int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			found.append(StringName(entry["name"]))
	if found.size() != FIELDS.size():
		return false
	for key: StringName in found:
		if not FIELDS.has(key):
			return false
	return true
