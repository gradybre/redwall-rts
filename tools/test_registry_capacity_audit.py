#!/usr/bin/env python3
"""Self-test for the source-proved registry capacity audit (REG-C3-R01).

NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES, deliberately. An
auditor with no refusal test is indistinguishable from one that stamps
"proved" on every row, and a relation classifier with no contradiction test is
indistinguishable from one that returns `eq` unconditionally -- which is
precisely the flattening REG-C3-R01 forbids.

The five cases this file exists for are the ones the task names:

  N01  prose that could be read two ways is refused, never resolved by
       preference. `<=` contains `=`, so a lenient left-hand side would make
       every one of the 46 bounds ALSO read as an equality.
  N03  an equality claim contradicted by source is a finding, not a pass.
  N04  an upper bound backed only by a compiled constant is a FINDING.
  N05  and the mirror image: an equality backed only by a clamped runtime
       variable is a finding too. Neither direction is quietly accepted.
  N06  a symbol that no longer exists is unproved -- never borrowed from
       another module that happens to declare the same name, and never
       inferred from the number the registry document already wrote down.
  N08  a capacity defined by an expression rather than a literal resolves when
       the expression is an allowlisted product, and is refused with its exact
       halting definition when it is not.

EVERY SYNTHETIC MODULE HERE IS FICTIONAL. The constants are named so a search
for a real store cannot find them, and no synthetic number is a capacity this
project uses. The tests that touch real files read them; none writes them.

    python3 tools/test_registry_capacity_audit.py
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import pathlib
import random
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

_spec = importlib.util.spec_from_file_location("audit_registry_capacities", ROOT / "tools/audit_registry_capacities.py")
audit = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit)

CASES: list = []
FAILURES: list = []


def check(label: str, condition: bool) -> bool:
	"""Record one check; a false condition is a failure but never stops the run."""
	CASES.append(label)
	if not condition:
		FAILURES.append(label)
	return bool(condition)


def module_index(**sources) -> dict:
	"""Build a source index from synthetic GDScript text, exactly as the tool parses real files."""
	return {
		name: audit.parse_module(name, "synthetic/%s.gd" % name, text)
		for name, text in sources.items()
	}


def const_module(const_name: str, const_expression: str, column: str = "_alpha_column",
		resize_expression: str = "", extra: str = "") -> str:
	"""A module that sizes one packed column from one compile-time constant."""
	return (
		"const %s: int = %s\n" % (const_name, const_expression)
		+ extra
		+ "var %s: PackedInt32Array = PackedInt32Array()\n" % column
		+ "func _init() -> void:\n"
		+ "\t%s.resize(%s)\n" % (column, resize_expression or const_name)
	)


def clamped_module(variable: str, maximum_name: str, maximum: int, column: str = "_alpha_column",
		resize_expression: str = "") -> str:
	"""A module whose column is sized by a runtime int var narrowed by one clampi."""
	return (
		"const %s: int = %d\n" % (maximum_name, maximum)
		+ "var %s: int = 0\n" % variable
		+ "var %s: PackedInt32Array = PackedInt32Array()\n" % column
		+ "func _init(p_rows: int = %s) -> void:\n" % maximum_name
		+ "\t%s = clampi(p_rows, 1, %s)\n" % (variable, maximum_name)
		+ "\t%s.resize(%s)\n" % (column, resize_expression or variable)
	)


def one_field(prose: str, module: str = "alpha", member: str = "_alpha_column",
		section: int = 12, owner: str = "synthetic_owner") -> tuple:
	"""One (owner, field) pair shaped like a registry record, for a single-row audit."""
	owner_record = {"section_id": section, "owner_key": owner, "owner_schema_version": 1, "fields": []}
	field = {
		"field_key": member,
		"type": "i32",
		"hash": True,
		"source_module": module,
		"source_member": member,
		"shape": {"declared_capacity": prose},
		"ordinal": 0,
	}
	owner_record["fields"].append(field)
	return owner_record, field


def audit_one(index: dict, prose: str, module: str = "alpha", member: str = "_alpha_column") -> dict:
	"""Run the per-field audit once and hand back its sidecar row."""
	owner, field = one_field(prose, module=module, member=member)
	return audit.audit_field(index, owner, field)


def fake_registry(owners: list) -> dict:
	"""The minimum registry envelope build_audit needs, with synthetic owners."""
	return {
		"registry_id": "SYNTHETIC-REGISTRY",
		"registry_version": 1,
		"packed_source_field_count": 0,
		"owners": owners,
	}


# --------------------------------------------------------------------------
# NEGATIVE TESTS
# --------------------------------------------------------------------------


def test_n01_upper_bound_never_reads_as_equality() -> None:
	"""N01: `<=` prose yields exactly one reading, and that reading is never `eq`."""
	for prose, value in (("`_beta_rows` <= 16384", 16384), ("`_beta_rows`<=1", 1), ("  `_beta_rows`  <=  7  ", 7)):
		candidates = audit.prose_candidates(prose)
		check("N01 %r reads exactly once, not twice" % prose, len(candidates) == 1)
		check("N01 %r is a bound" % prose, [c.relation for c in candidates] == [audit.RELATION_LTE])
		check("N01 %r has no equality reading" % prose,
			not any(c.relation == audit.RELATION_EQ for c in candidates))
		parsed = audit.parse_prose(prose)
		check("N01 %r parses to %d as a bound" % (prose, value),
			isinstance(parsed, audit.Parse) and parsed.relation == audit.RELATION_LTE and parsed.value == value)


def test_n02_prose_that_reads_two_ways_is_refused() -> None:
	"""N01 cont.: several readings are refused outright; the first is never preferred."""
	two = [audit.Parse("A", audit.RELATION_EQ, 5), audit.Parse("A", audit.RELATION_LTE, 5)]
	refusal = audit.select_single_parse(two)
	check("N02 two readings are refused, not resolved by preference",
		isinstance(refusal, audit.Unproved) and refusal.reason == "ambiguous_prose")
	check("N02 the refusal names both readings", isinstance(refusal, audit.Unproved) and "2 ways" in refusal.detail)
	for prose in ("`A` = 5 = 5", "`A` = 5 <= 5", "A = 5", "`A` = ", "`A` = -5", "`A` = 5 rows", "`A` == 5"):
		check("N02 %r is refused" % prose, isinstance(audit.parse_prose(prose), audit.Unproved))
	row = audit_one(module_index(alpha=const_module("BETA_ROWS", "512")), "`BETA_ROWS` = 5 = 5")
	check("N02 an unparsable row is quarantined, not dropped", row["status"] == "unproved_unparsed_prose")


def test_n03_equality_contradicted_by_source_is_a_finding() -> None:
	"""N03: prose says 256, source says 512. The audit reports the contradiction."""
	index = module_index(alpha=const_module("BETA_ROWS", "512"))
	row = audit_one(index, "`BETA_ROWS` = 256")
	check("N03 contradicted equality is a finding", row["status"] == "finding_value_mismatch")
	check("N03 the finding keeps both numbers", row["prose_value"] == 256 and row["source_value"] == 512)
	check("N03 the contradiction is not reported as proved", not row["status"].startswith("proved_"))
	agreeing = audit_one(index, "`BETA_ROWS` = 512")
	check("N03 the same row proves when the numbers agree", agreeing["status"] == "proved_equality")


def test_n04_upper_bound_proved_only_as_equality_is_a_finding() -> None:
	"""N04: a `<=` claim backed by a compiled constant is a finding, never a pass."""
	index = module_index(alpha=const_module("BETA_ROWS", "512"))
	row = audit_one(index, "`BETA_ROWS` <= 512")
	check("N04 bound over a constant is a finding", row["status"] == "finding_relation_mismatch")
	check("N04 the source relation is recorded as equality", row["source_relation"] == audit.RELATION_EQ)
	check("N04 matching numbers do not launder the relation", row["prose_value"] == row["source_value"] == 512)


def test_n05_equality_proved_only_as_a_bound_is_a_finding() -> None:
	"""N05: the mirror image. A `=` claim backed by a clamped runtime var is a finding."""
	index = module_index(alpha=clamped_module("_beta_rows", "BETA_ROW_MAX", 16384))
	row = audit_one(index, "`_beta_rows` = 16384")
	check("N05 equality over a clamped var is a finding", row["status"] == "finding_relation_mismatch")
	check("N05 the source relation is recorded as a bound", row["source_relation"] == audit.RELATION_LTE)
	bound = audit_one(index, "`_beta_rows` <= 16384")
	check("N05 the honest bound proves", bound["status"] == "proved_upper_bound")


def test_n06_missing_symbol_is_unproved() -> None:
	"""N06: a symbol the source no longer declares is unproved -- and never guessed."""
	index = module_index(alpha=const_module("BETA_ROWS", "512", resize_expression="GONE_ROWS"))
	row = audit_one(index, "`GONE_ROWS` = 512")
	check("N06 a vanished constant is unproved", row["status"] == "unproved_unknown_symbol")
	check("N06 no value is invented", "source_value" not in row)
	check("N06 the refusal names the module and symbol", "GONE_ROWS" in row["quarantine_reason"])


def test_n07_a_symbol_is_never_borrowed_from_another_module() -> None:
	"""N06 cont.: a bare name is resolved in its OWN module only, never by search."""
	index = module_index(
		alpha=const_module("BETA_ROWS", "512", resize_expression="GAMMA_ROWS"),
		gamma=const_module("GAMMA_ROWS", "512", column="_gamma_column"),
	)
	row = audit_one(index, "`GAMMA_ROWS` = 512")
	check("N07 a same-named constant elsewhere does not prove this row",
		row["status"] == "unproved_unknown_symbol")
	qualified = audit.resolve_expression(index, "alpha", "Gamma.GAMMA_ROWS")
	check("N07 an unqualified alias is refused too",
		isinstance(qualified, audit.Unproved) and qualified.reason == "unknown_alias")


def test_n08_expression_not_a_literal() -> None:
	"""N08: allowlisted products resolve; other arithmetic halts with its exact definition."""
	product = module_index(alpha=const_module(
		"BETA_TOTAL", "BETA_ROWS * BETA_COLUMNS",
		extra="const BETA_ROWS: int = 7\nconst BETA_COLUMNS: int = 11\n"))
	row = audit_one(product, "`BETA_TOTAL` = 77")
	check("N08 a product of constants proves", row["status"] == "proved_equality" and row["source_value"] == 77)
	check("N08 the proof chain shows every substitution", len(row["proof_chain"]) == 3)
	for expression, operator in (("BETA_ROWS + BETA_COLUMNS", "+"), ("BETA_ROWS - BETA_COLUMNS", "-"),
			("BETA_ROWS / BETA_COLUMNS", "/"), ("(BETA_ROWS)", "(")):
		index = module_index(alpha=const_module(
			"BETA_TOTAL", expression,
			extra="const BETA_ROWS: int = 7\nconst BETA_COLUMNS: int = 11\n"))
		refused = audit_one(index, "`BETA_TOTAL` = 77")
		check("N08 %r halts with its definition" % expression,
			refused["status"] == "unproved_non_allowlisted_operator"
			and "BETA_TOTAL halted at synthetic/alpha.gd:1" in refused["quarantine_reason"]
			and operator in refused["quarantine_reason"])


def test_n09_overflow_is_refused() -> None:
	"""A product no int64 column could hold is refused rather than silently widened."""
	index = module_index(alpha=const_module(
		"BETA_TOTAL", "BETA_BIG * BETA_BIG",
		extra="const BETA_BIG: int = 4000000000\n"))
	row = audit_one(index, "`BETA_TOTAL` = 16000000000000000000")
	check("N09 an int64 overflow is refused", row["status"] == "unproved_overflow")
	check("N09 no overflowed value is published", "source_value" not in row)
	edge = module_index(alpha=const_module("BETA_TOTAL", "%d" % audit.INT64_MAX))
	check("N09 the largest int64 still proves",
		audit_one(edge, "`BETA_TOTAL` = %d" % audit.INT64_MAX)["status"] == "proved_equality")


def test_n10_document_agreement_is_never_proof() -> None:
	"""A capacity the documents all agree on is still unproved if source does not say it."""
	index = module_index(alpha=const_module("BETA_ROWS", "512", resize_expression="ABSENT_ROWS"))
	row = audit_one(index, "`ABSENT_ROWS` = 512")
	check("N10 registry agreement does not prove a capacity", row["status"] == "unproved_unknown_symbol")
	check("N10 the prose value is recorded as a claim only", row["prose_value"] == 512 and "source_value" not in row)
	text = (ROOT / "tools/audit_registry_capacities.py").read_text()
	check("N10 the tool never evaluates source text", "eval(" not in text and "exec(" not in text)
	receivers = sorted(set(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\.read_text\(\)", text)))
	check("N10 the tool reads only the registry, the sidecar and .gd files",
		receivers == ["REGISTRY_PATH", "SIDECAR_PATH", "path"])
	check("N10 the only source glob is GDScript", text.count("glob(") == 1 and 'glob("*.gd")' in text)
	check("N10 no markdown or table document is opened",
		not re.search(r"[\"\'][^\"\']*\.md[\"\']\s*\)?\.read_text", text))
	check("N10 nothing is read with a bare open()", "open(" not in text)


def test_n11_binding_mismatch_is_unproved() -> None:
	"""The prose expression must be the SAME text that sizes the column, or the row refuses."""
	index = module_index(alpha=const_module(
		"BETA_ROWS", "512", resize_expression="BETA_OTHER",
		extra="const BETA_OTHER: int = 512\n"))
	row = audit_one(index, "`BETA_ROWS` = 512")
	check("N11 a different sizing expression refuses", row["status"] == "unproved_binding_mismatch")
	check("N11 the refusal shows both expressions",
		"BETA_ROWS" in row["quarantine_reason"] and "BETA_OTHER" in row["quarantine_reason"])


def test_n12_unbounded_runtime_variable_is_unproved() -> None:
	"""A runtime var with no single clampi has no proved maximum, so it is refused."""
	unclamped = (
		"var _beta_rows: int = 0\n"
		"var _alpha_column: PackedInt32Array = PackedInt32Array()\n"
		"func _init(p_rows: int = 4) -> void:\n"
		"\t_beta_rows = p_rows\n"
		"\t_alpha_column.resize(_beta_rows)\n"
	)
	row = audit_one(module_index(alpha=unclamped), "`_beta_rows` <= 16384")
	check("N12 an unclamped var is unproved", row["status"] == "unproved_unbounded_runtime_variable")
	twice = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384).replace(
		"\t_alpha_column.resize(_beta_rows)\n", "\t_beta_rows = 99\n\t_alpha_column.resize(_beta_rows)\n")
	second = audit_one(module_index(alpha=twice), "`_beta_rows` <= 16384")
	check("N12 a second assignment defeats the clamp proof",
		second["status"] == "unproved_unbounded_runtime_variable")


def test_n13_conflicting_and_missing_columns_are_unproved() -> None:
	"""A column sized two ways, or not a packed column at all, is quarantined."""
	conflicting = const_module("BETA_ROWS", "512", extra="const BETA_OTHER: int = 8\n") \
		+ "\t_alpha_column.resize(BETA_OTHER)\n"
	row = audit_one(module_index(alpha=conflicting), "`BETA_ROWS` = 512")
	check("N13 two sizing expressions refuse", row["status"] == "unproved_conflicting_resize")
	absent = audit_one(module_index(alpha=const_module("BETA_ROWS", "512")), "`BETA_ROWS` = 512", member="_missing")
	check("N13 a member that is not a packed column refuses", absent["status"] == "unproved_missing_column")
	no_module = audit_one(module_index(alpha=const_module("BETA_ROWS", "512")), "`BETA_ROWS` = 512", module="absent")
	check("N13 a missing module refuses", no_module["status"] == "unproved_unknown_module")


def test_n14_ambiguous_constant_is_refused() -> None:
	"""A constant declared twice with different values is ambiguous, so it is not picked."""
	doubled = "const BETA_ROWS: int = 512\n" + const_module("BETA_ROWS", "256")
	row = audit_one(module_index(alpha=doubled), "`BETA_ROWS` = 512")
	check("N14 a redeclared constant is ambiguous", row["status"] == "unproved_ambiguous_symbol")
	repeated = "const BETA_ROWS: int = 512\n" + const_module("BETA_ROWS", "512")
	check("N14 an identical redeclaration is not ambiguous",
		audit_one(module_index(alpha=repeated), "`BETA_ROWS` = 512")["status"] == "proved_equality")


def test_n15_mixed_dynamic_expression_is_refused() -> None:
	"""A product of a runtime var and a constant is neither claim, so it is not collapsed."""
	mixed = (
		"const BETA_STRIDE: int = 4\n"
		"const BETA_ROW_MAX: int = 64\n"
		"var _beta_rows: int = 0\n"
		"var _alpha_column: PackedInt32Array = PackedInt32Array()\n"
		"func _init(p_rows: int = 8) -> void:\n"
		"\t_beta_rows = clampi(p_rows, 1, BETA_ROW_MAX)\n"
		"\t_alpha_column.resize(_beta_rows * BETA_STRIDE)\n"
	)
	row = audit_one(module_index(alpha=mixed), "`_beta_rows * BETA_STRIDE` <= 256")
	check("N15 a mixed product is refused", row["status"] == "unproved_mixed_dynamic_expression")
	check("N15 it is not silently called an equality", row["source_relation"] == audit.RELATION_LTE)


def test_n16_non_hash_rows_are_never_swept_in() -> None:
	"""REG-C3-R01 acceptance: the non-canonical rows must not enter the audit."""
	owner, field = one_field("`BETA_ROWS` = 512")
	shadow = dict(field)
	shadow["field_key"] = "_shadow_column"
	shadow["hash"] = False
	shadow["ordinal"] = 1
	owner["fields"].append(shadow)
	built = audit.build_audit(fake_registry([owner]), module_index(alpha=const_module("BETA_ROWS", "512")))
	check("N16 only the canonical row is audited", len(built["rows"]) == 1)
	check("N16 the non-hash row is counted, not audited",
		built["census"]["observed"]["non_hash_fields"] == 1
		and built["census"]["observed"]["non_hash_fields_admitted_to_audit"] == 0
		and built["census"]["observed"]["non_hash_fields_carrying_declared_capacity"] == 1)


def test_n17_no_row_is_ever_dropped() -> None:
	"""Every capacity field produces exactly one row, even when every one of them fails."""
	owner, field = one_field("`GONE_ROWS` = 512")
	for ordinal in range(1, 4):
		extra = dict(field)
		extra["field_key"] = "_gone_%d" % ordinal
		extra["source_member"] = "_gone_%d" % ordinal
		extra["ordinal"] = ordinal
		owner["fields"].append(extra)
	built = audit.build_audit(fake_registry([owner]), module_index(alpha=const_module("BETA_ROWS", "512")))
	check("N17 four capacity fields produce four rows", len(built["rows"]) == 4)
	check("N17 all four are quarantined", len(built["unproved_or_contradicted"]) == 4)
	check("N17 the status counts sum to the row count",
		sum(built["status_counts"].values()) == 4)


# --------------------------------------------------------------------------
# POSITIVE AND STRUCTURAL TESTS
# --------------------------------------------------------------------------


def test_p01_below_maximum_bound_stays_a_bound() -> None:
	"""A store sized BELOW its maximum must not become an equality claim.

	REG-C3-R01 asks for exactly this fixture. The clamp proves 16384 as a
	MAXIMUM; the module actually constructs 4096 rows. The audit must publish
	the maximum as a bound, and must refuse a prose equality at either number.
	"""
	below = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384).replace(
		"func _init(p_rows: int = BETA_ROW_MAX)", "func _init(p_rows: int = 4096)")
	index = module_index(alpha=below)
	bound = audit_one(index, "`_beta_rows` <= 16384")
	check("P01 the bound proves at the maximum", bound["status"] == "proved_upper_bound")
	check("P01 the proof is recorded as a clamped bound", bound["proof_kind"] == "clamped_runtime_bound")
	check("P01 the bound is the clamp maximum, not the constructed size", bound["source_value"] == 16384)
	check("P01 equality at the maximum is refused",
		audit_one(index, "`_beta_rows` = 16384")["status"] == "finding_relation_mismatch")
	check("P01 equality at the actual below-maximum size is refused too",
		audit_one(index, "`_beta_rows` = 4096")["status"] == "finding_relation_mismatch")


def test_p02_qualified_constants_resolve_through_preload_aliases() -> None:
	"""`Alias.CONST` resolves only through an explicit preload in the owning module."""
	index = module_index(
		alpha='const Gamma := preload("res://scripts/core/gamma.gd")\n'
			+ const_module("BETA_ROWS", "Gamma.GAMMA_ROWS", resize_expression="Gamma.GAMMA_ROWS"),
		gamma=const_module("GAMMA_ROWS", "384", column="_gamma_column"),
	)
	row = audit_one(index, "`Gamma.GAMMA_ROWS` = 384")
	check("P02 a qualified constant proves", row["status"] == "proved_equality" and row["source_value"] == 384)
	check("P02 the chain names the defining module",
		any("synthetic/gamma.gd" in step for step in row["proof_chain"]))


def test_p03_ordering_is_deterministic_and_independent_of_input_order() -> None:
	"""Rows sort by (section, owner, ordinal, field_key) whatever order the registry lists."""
	index = module_index(alpha=const_module("BETA_ROWS", "512"))
	owners = []
	for section, owner_key in ((12, "zeta"), (11, "alpha_owner"), (12, "alpha_owner")):
		owner, _ = one_field("`BETA_ROWS` = 512", section=section, owner=owner_key)
		owners.append(owner)
	expected = [(11, "alpha_owner"), (12, "alpha_owner"), (12, "zeta")]
	for seed in range(6):
		shuffled = list(owners)
		random.Random(seed).shuffle(shuffled)
		built = audit.build_audit(fake_registry(shuffled), index)
		got = [(row["section_id"], row["owner_key"]) for row in built["rows"]]
		check("P03 seed %d sorts identically" % seed, got == expected)
		reference = audit.build_audit(fake_registry(owners), index)
		check("P03 seed %d renders the same rows" % seed,
			json.dumps(built["rows"], sort_keys=True) == json.dumps(reference["rows"], sort_keys=True))
		check("P03 seed %d renders the same census" % seed,
			json.dumps(built["census"], sort_keys=True) == json.dumps(reference["census"], sort_keys=True))


def test_p04_render_is_byte_stable() -> None:
	"""Rendering the same audit twice is byte-identical, which is what --check relies on."""
	index = module_index(alpha=const_module("BETA_ROWS", "512"))
	owner, _ = one_field("`BETA_ROWS` = 512")
	first = audit.render(audit.build_audit(fake_registry([owner]), index))
	second = audit.render(audit.build_audit(fake_registry([owner]), index))
	check("P04 two renders are byte-identical", first == second)
	check("P04 the render ends in exactly one newline", first.endswith("}\n") and not first.endswith("\n\n"))
	check("P04 keys are sorted", json.loads(first) == json.loads(second))


def test_p05_real_census_matches_astra_or_says_so_loudly() -> None:
	"""The real registry's census, stated against Astra's Cycle 3 numbers."""
	built = real_audit()
	observed = built["census"]["observed"]
	check("P05 516 prose records", observed["prose_records"] == 516)
	check("P05 470 equality", observed["equality"] == 470)
	check("P05 46 upper bounds", observed["upper_bound"] == 46)
	check("P05 80 other canonical shapes", observed["other_canonical_shapes"] == 80)
	check("P05 55 distinct expressions", observed["distinct_expressions"] == 55)
	check("P05 596 canonical records and 8 non-hash", observed["canonical_records"] == 596 and observed["non_hash_fields"] == 8)
	check("P05 no non-hash row was swept in", observed["non_hash_fields_admitted_to_audit"] == 0)
	# The census no longer equals Astra's 388f4f4 snapshot, and must not be made to. Decision
	# 0142 retired three deposit members after that snapshot was taken, so five counts moved.
	# What matters is that EVERY difference is one a recorded decision accounts for: zero
	# UNEXPLAINED disagreements. Asserting equality here would have meant either reverting a
	# correct registry change or editing Astra's evidence to match the code.
	check("P05 every difference from Astra Cycle 3 is explained by a recorded decision",
		built["census"]["disagreements"] == [])
	check("P05 the explained drift is decision 0142's three deposit members",
		len(built["census"]["explained_since_census"]) == 5)
	check("P05 equality plus bounds is the whole prose set",
		observed["equality"] + observed["upper_bound"] == observed["prose_records"])


def test_p06_real_proof_status_is_exactly_reported() -> None:
	"""The real proof outcome: 468 equalities, 46 bounds, 2 unproved, 0 contradictions."""
	built = real_audit()
	counts = built["status_counts"]
	check("P06 468 proved equalities", counts.get("proved_equality") == 468)
	check("P06 46 proved upper bounds", counts.get("proved_upper_bound") == 46)
	check("P06 2 unproved non-allowlisted operators", counts.get("unproved_non_allowlisted_operator") == 2)
	check("P06 no other status appears", set(counts) == {"proved_equality", "proved_upper_bound", "unproved_non_allowlisted_operator"})
	check("P06 the statuses sum to 516", sum(counts.values()) == 516)
	quarantined = built["unproved_or_contradicted"]
	check("P06 both quarantined rows are orchard_hive link columns",
		sorted(row["field_key"] for row in quarantined) == ["_link_hive_generation", "_link_hive_slot"])
	check("P06 the quarantine names the halting definition",
		all("orchard_hive.gd:316" in row["quarantine_reason"] for row in quarantined))
	check("P06 no quarantined row carries a value",
		all("source_value" not in row for row in built["rows"] if row["status"].startswith("unproved_")))


def test_p07_every_proved_row_carries_its_provenance() -> None:
	"""A proved row without a file, line and chain is an assertion, not a proof."""
	built = real_audit()
	proved = [row for row in built["rows"] if row["status"].startswith("proved_")]
	check("P07 514 rows are proved", len(proved) == 514)
	check("P07 every proved row names a real source file",
		all((ROOT / row["source_file"]).is_file() for row in proved))
	check("P07 every proved row cites a resize line", all(row["source_resize_line"] >= 1 for row in proved))
	check("P07 every proved row has a non-empty proof chain", all(row["proof_chain"] for row in proved))
	check("P07 every proved row binds prose to the same source expression",
		all(row["parsed_expression"] == row["source_resize_expression"] for row in proved))
	check("P07 every proved row agrees on relation and value",
		all(row["prose_relation"] == row["source_relation"] and row["prose_value"] == row["source_value"] for row in proved))
	check("P07 the 46 bounds are all clamped runtime bounds",
		[row["proof_kind"] for row in proved].count("clamped_runtime_bound") == 46)


def test_p08_keys_are_unique_and_nothing_is_lost() -> None:
	"""Every audit key is unique, and the 596 canonical records are fully accounted for."""
	built = real_audit()
	keys = [(row["section_id"], row["owner_key"], row["ordinal"], row["field_key"]) for row in built["rows"]]
	check("P08 516 keys, all unique", len(keys) == 516 and len(set(keys)) == 516)
	other = built["non_capacity_canonical_records"]
	check("P08 80 non-capacity records are listed, not dropped", len(other) == 80)
	check("P08 the two lists partition the 596 canonical records", len(keys) + len(other) == 596)
	overlap = set(keys) & {(row["section_id"], row["owner_key"], row["ordinal"], row["field_key"]) for row in other}
	check("P08 the two lists do not overlap", overlap == set())


def test_p09_committed_sidecar_is_what_this_source_produces() -> None:
	"""The committed sidecar regenerates byte-identically, and nothing active is touched."""
	before = hashlib.sha256(audit.REGISTRY_PATH.read_bytes()).hexdigest()
	result = subprocess.run([sys.executable, str(ROOT / "tools/audit_registry_capacities.py"), "--check"],
		capture_output=True, text=True)
	check("P09 --check passes against the committed sidecar", result.returncode == 0)
	check("P09 --check prints no refusal", "REFUSED" not in result.stdout)
	after = hashlib.sha256(audit.REGISTRY_PATH.read_bytes()).hexdigest()
	check("P09 the active registry is byte-unchanged by a run", before == after)
	check("P09 the sidecar on disk is what render() produces",
		audit.SIDECAR_PATH.read_text() == audit.render(real_audit()))


def test_p10_the_sidecar_declares_itself_unadopted() -> None:
	"""The sidecar must not read as a registry edit or as an adopted conversion."""
	built = real_audit()
	check("P10 the sidecar is marked read-only", built["kind"] == "read_only_sidecar")
	check("P10 the sidecar is marked unadopted", built["adopted"] is False)
	# registry_version is the ACTIVE registry's, read not asserted: decision 0142 moved it 1 -> 2
	# with the rules identity. Pinning a literal here would make this sidecar refuse every future
	# registry revision, which is the opposite of an audit's job.
	check("P10 the audit reports the registry version it actually read",
		built["audited_registry"]["registry_version"]
			== json.loads((ROOT / "docs/planning/canonical_state_registry.json").read_text())["registry_version"])
	check("P10 the audit does not re-assert the registry's source sha",
		"source_registry_sha256" not in json.dumps(built["audited_registry"]))
	check("P10 the notes say no prose is converted",
		any("later ruling decides adoption" in note for note in built["notes"]))


_REAL: dict = {}


def real_audit() -> dict:
	"""Build the real audit once and reuse it; every caller reads the same object."""
	if not _REAL:
		registry = json.loads(audit.REGISTRY_PATH.read_text())
		_REAL["value"] = audit.build_audit(registry, audit.load_source_index())
	return _REAL["value"]


def main() -> int:
	"""Run every test and print the summary line this lane reports verbatim."""
	for name, test in sorted(globals().items()):
		if name.startswith("test_") and callable(test):
			try:
				test()
			except Exception as error:  # noqa: BLE001 -- a crash is a failure, not a lost run
				check("%s raised %s: %s" % (name, type(error).__name__, error), False)
	for failure in FAILURES:
		print("FAIL %s" % failure)
	print("test_registry_capacity_audit: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
