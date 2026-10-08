extends RefCounted
## ADR 1217 step 5: the prepared endpoint certificate is chosen by the installation's content revision. Content 9's
## claw certificate (`qualified-claw-certificate-v1`, narrow claw rows 43/47, tap 52, paw handling 59) serves the
## active runtime; the pick certificate (`qualified-assembly-v1`, rows 2/6/16/29) stays with the dormant pick contents
## it was proved for (DEC-052). Neither certificate is edited; this only routes a call to the one bound to the
## content the installation was opened under. No reverse preload of Locations, Routes, Placements or Workpieces.

const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/endpoint_certificate.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-certificate-v1/endpoint_certificate.gd")


static func is_claw(content: int) -> bool:
	"""Content 9 is the claw certificate's; every earlier content is the pick's."""
	return content == Claw.CONTENT


static func prepared_record_refusal(actual_locations: RefCounted, original_context: RefCounted,
		record: RefCounted, snapshot_volume_row: int) -> StringName:
	"""The record proof of the certificate bound to the installation's content."""
	if original_context != null and is_claw(original_context.profile_revision):
		return Claw.prepared_record_refusal(actual_locations, original_context, record, snapshot_volume_row)
	return Pick.prepared_record_refusal(actual_locations, original_context, record, snapshot_volume_row)


static func prepared_span_refusal(actual: RefCounted, first: Vector3i, last: Vector3i, volume_row: int) -> StringName:
	"""The span proof of the certificate bound to the installation's content."""
	if actual != null and actual._installation != null and is_claw(actual._installation.profile_revision):
		return Claw.prepared_span_refusal(actual, first, last, volume_row)
	return Pick.prepared_span_refusal(actual, first, last, volume_row)


static func excuses_pending(profile: int, content: int) -> bool:
	"""Only the certified narrow approach and retreat at heading 0 may omit a pending bearer (ADR1205): claw rows
	43/47 in content 9, pick rows 2/6 before it."""
	if is_claw(content):
		return profile == Claw.Pins.CLAW_APPROACH_ROWS[0] or profile == Claw.Pins.CLAW_RETREAT_ROWS[0]
	return profile == 2 or profile == 6
