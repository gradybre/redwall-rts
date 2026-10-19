extends "res://test/framework/test_case.gd"
## Decision 2044 (P-2044-17 (a)): the endpoint dispatch names the module-aware successor, which hands every module-0
## installation to today's certificate (so today's entry behaves byte for byte as before) and proves a later module's T0
## at its moved station root.

const Dispatch := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/endpoint_certificates.gd")
const Published := preload("res://data/underground/mole-worker/qualified-claw-certificate-v2/endpoint_certificate.gd")
const Successor := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/endpoint_certificate.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")


class Context extends RefCounted:
	## The fields both certificates read first; nothing else, so every proof refuses at its first identity check.
	var assembly: int = 0
	var issuer: WeakRef = null
	var profile_revision: int = 12
	var placement: Vector2i = Vector2i(-1, 0)


class Issuer extends RefCounted:
	## A Placement bank of one row at a fixed origin.
	const X: int = 0
	@warning_ignore("unused_private_class_variable")
	var _capacity: int = 1
	@warning_ignore("unused_private_class_variable")
	var _live: Live = Live.new()


class Live extends RefCounted:
	## X, Y, Z of row 0.
	var i32: PackedInt32Array = PackedInt32Array([1000, 512, 2000])


class Installation extends RefCounted:
	## A Routes binding holding the installation context.
	var _installation: Context = null
	@warning_ignore("unused_private_class_variable")
	var _locations_ref: WeakRef = null


func test_the_dispatch_names_the_successor() -> void:
	"""P-2044-17 (a): content 12's (and 10's) endpoint certificate is the module-aware successor."""
	assert_true(Dispatch.Claw10 == Successor, "the dispatch's content-10/12 certificate")
	assert_equal(Successor.CONTENT, Published.CONTENT, "the published content")
	assert_true(Successor.Pins == Published.Pins, "the published pins")


func test_only_a_later_modules_t0_is_proved_by_the_successor() -> void:
	"""Assemblies 0-7 (module 0) and every later tread go to the published certificate; a later T0 is its own."""
	for assembly: int in 8:
		assert_false(Successor.later_t0(assembly), "module 0's assembly %d" % assembly)
	for module: int in range(1, Tread.MODULES):
		for k: int in 7:
			var assembly: int = 1 + 7 * module + k
			assert_equal(Successor.later_t0(assembly), k == 0, "module %d T%d" % [module, k])


func test_module_zero_answers_are_the_published_answers() -> void:
	"""Byte identity: for module 0 the successor returns exactly what the published certificate returns, record and
	span alike, whatever the context (here every proof refuses at its first identity check)."""
	for assembly: int in 8:
		var context: Context = Context.new()
		context.assembly = assembly
		assert_equal(Successor.prepared_record_refusal(null, context, null, 0),
			Published.prepared_record_refusal(null, context, null, 0), "record, assembly %d" % assembly)
		var binding: Installation = Installation.new()
		binding._installation = context
		assert_equal(Successor.prepared_span_refusal(binding, Vector3i.ZERO, Vector3i.ZERO, 0),
			Published.prepared_span_refusal(binding, Vector3i.ZERO, Vector3i.ZERO, 0), "span, assembly %d" % assembly)
	assert_equal(Successor.prepared_record_refusal(null, null, null, 0), Published.prepared_record_refusal(null, null, null, 0),
		"no context")
	assert_equal(Successor.prepared_span_refusal(null, Vector3i.ZERO, Vector3i.ZERO, 0),
		Published.prepared_span_refusal(null, Vector3i.ZERO, Vector3i.ZERO, 0), "no binding")


func test_a_later_t0s_root_is_its_moved_station() -> void:
	"""The station root is the Placement origin plus the module's translated T0 station (H')."""
	var issuer: Issuer = Issuer.new()
	var context: Context = Context.new()
	context.placement = Vector2i(0, 1)
	for module: int in range(1, Tread.MODULES):
		context.assembly = 1 + 7 * module
		assert_equal(Successor._root(issuer, context), Vector3i(1000, 512, 2000) + Tread.t0_station_of(context.assembly),
			"module %d's T0 root" % module)
		assert_equal(Successor._root(issuer, context), Vector3i(1000, 512 - 1024 * module, 2000 - 1536 - 5120 * module),
			"H' %d" % module)


func test_a_later_t0_without_its_context_refuses() -> void:
	"""A later T0's proofs refuse without the complete original context, as the published ones do."""
	var context: Context = Context.new()
	context.assembly = 8
	assert_equal(Successor.prepared_record_refusal(null, context, null, 0), Successor.REFUSE, "record")
	var binding: Installation = Installation.new()
	binding._installation = context
	assert_equal(Successor.prepared_span_refusal(binding, Vector3i.ZERO, Vector3i.ZERO, 0), Successor.REFUSE, "span")


func test_the_moved_span_admits_the_landing_approach_and_retreat() -> void:
	"""From H', F' -> H' is the narrow approach (forward, down the flight) and H' -> F' the retreat, both within the
	published 4,096 u interval of the moved root."""
	var root: Vector3i = Tread.t0_station_of(8)
	var f_prime: Vector3i = Vector3i(0, -1024, -2560 - 6 * 512 - 686)
	assert_true(Published._span_points_match(Published.Pins.CLAW_APPROACH_ROWS[0], root, f_prime, root), "F' -> H'")
	assert_true(Published._span_points_match(Published.Pins.CLAW_RETREAT_ROWS[0], root, root, f_prime), "H' -> F'")
	assert_false(Published._span_points_match(Published.Pins.CLAW_APPROACH_ROWS[0], Tread.t0_station_of(1), f_prime, root),
		"not from module 0's root")
