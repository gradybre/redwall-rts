#!/usr/bin/env python3
"""Source-proved numeric capacity audit for the canonical state registry (REG-C3-R01).

WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT

REG-C3-R01 authorises "mechanical numeric extraction ... with row-level
provenance and validation", emitted as "a reviewable numeric sidecar/delta, not
blind replacement of the active registry". This script therefore READS
docs/planning/canonical_state_registry.json and WRITES ONLY
docs/planning/registry_capacity_audit.json. It never edits the registry, the
registry's checker, the persistence document, or any compiled declaration.

REG-C4-R01 (2026-09-19, docs/rulings/2026-09-19_cycle04_resumption.md) extends
the proof grammar with bounded addition: a declared capacity may now be a
left-associative sum of the same allowlisted products, `sum := product ('+'
product)*`, with multiplication still binding tighter and every intermediate --
including inside a nested constant's own definition -- checked against signed
int64 before the next step. Nothing else about the sidecar's shape, scope or
authority changes: this is still a read-only proof grammar, not a store, a
capacity, a save schema or a memory allocation.

THE PROOF RULE. A capacity is proved by godot/scripts/core/<module>.gd and by
nothing else. The registry's own prose is the CLAIM under audit; agreement
between the registry and another document is not evidence and is never accepted
here. Concretely, for each field the audit:

  1. parses the prose against a closed grammar `` `expr` (= | <=) <digits> ``;
  2. locates the column's own `resize(...)` argument in the owning module and
     requires it to be the SAME expression text (the binding proof);
  3. resolves that expression with a restricted integer evaluator -- decimal
     literals, module constants, `Alias.CONST` through explicit `preload`
     aliases, and left-associative sums of `*` products (REG-C4-R01:
     `sum := product ('+' product)*`, multiplication binding tighter). There
     is no `eval`, no cross-module guessing of a bare name, and no float
     anywhere;
  4. classifies the SOURCE as equality or upper bound from the source itself: a
     compile-time constant is an equality, a runtime `var` narrowed by exactly
     one `clampi(arg, lo, MAX)` is an upper bound;
  5. compares the source's relation and value with the prose's.

EQUALITY VERSUS MAXIMUM IS THE POINT. A store sized AT its maximum and a store
sized EXACTLY are different claims about what a decode may accept. A prose `<=`
backed only by a constant, or a prose `=` backed only by a clamped variable, is
reported as a FINDING -- never quietly accepted, and never flattened into one
integer.

NO SENTINELS. Resolution returns either a `Proved` or an `Unproved`; there is no
-1, no magic zero and no None-as-value. An unprovable capacity is reported with
its reason and quarantined. It is never guessed and never dropped.

    python3 tools/audit_registry_capacities.py [--check]

`--check` regenerates in memory and fails if the committed sidecar differs,
which is also the determinism test: two runs must be byte-identical.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
from typing import NamedTuple

ROOT = pathlib.Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / "docs/planning/canonical_state_registry.json"
SIDECAR_PATH = ROOT / "docs/planning/registry_capacity_audit.json"
CORE_DIR = ROOT / "godot/scripts/core"

AUDIT_ID = "RWL-REGISTRY-CAPACITY-AUDIT-2026-09-14-1"
AUDIT_SCHEMA_VERSION = 2

INT64_MIN = -9223372036854775808
INT64_MAX = 9223372036854775807
MAX_RESOLVE_DEPTH = 16

# Astra's Cycle 3 census, quoted so a disagreement is loud instead of silent.
# cycle_03.md calls these "source snapshot counts, not future immutable totals",
# so a later legitimate change moves them; it does not license tuning the parser.
# Astra's Cycle 3 census, taken at merged master 388f4f4. It is a DATED SNAPSHOT for comparison,
# not a pin: cycle_03.md says so itself -- "source snapshot counts, not future immutable totals".
#
# Decision 0142 (SAVE-S1-OWNERS) then reclassified resource_nodes' three deposit members as
# category-3 scratch, which is why every count below moved by exactly three:
#
#     prose_records    519 -> 516      canonical_records  599 -> 596
#     equality         473 -> 470      packed_source      553 -> 550
#     distinct_expressions 56 -> 55    (one expression lost its last user)
#
# The disagreement machinery did its job here: this audit merged before 0142 did, the registry
# changed underneath it, and the tool REPORTED the difference rather than adjusting to it. The
# snapshot is therefore kept at its original values and dated, and the live expectation is
# derived from the registry -- suppressing the older figures would throw away the evidence that
# the mechanism works.
ASTRA_CYCLE_03_CENSUS_AT = "388f4f4"
ASTRA_CYCLE_03_CENSUS = {
	"prose_records": 519,
	"equality": 473,
	"upper_bound": 46,
	"other_canonical_shapes": 80,
	"distinct_expressions": 56,
	"canonical_records": 599,
	"packed_source_fields": 553,
	"owners": 52,
}

# What decision 0142 removed, so a later reader can tell an EXPLAINED drift from a new one. A
# disagreement that is not in this table is unexplained and wants a human.
EXPLAINED_SINCE_CENSUS = {
	"prose_records": -3,
	"equality": -3,
	"canonical_records": -3,
	"packed_source_fields": -3,
	"distinct_expressions": -1,
}

RELATION_EQ = "eq"
RELATION_LTE = "lte"

STATUS_PROVED_EQUALITY = "proved_equality"
STATUS_PROVED_UPPER_BOUND = "proved_upper_bound"

# --- source parsing -------------------------------------------------------

COLUMN_RE = re.compile(r"^var (_[A-Za-z0-9_]+): (Packed[A-Za-z0-9]+Array)\b", re.M)
INT_VAR_RE = re.compile(r"^var (_[A-Za-z0-9_]+): int\b", re.M)
CONST_TYPED_RE = re.compile(r"^const ([A-Z][A-Z0-9_]*): int = (.+?)[ \t]*$", re.M)
CONST_INFERRED_RE = re.compile(r"^const ([A-Z][A-Z0-9_]*) := (.+?)[ \t]*$", re.M)
ALIAS_RE = re.compile(
	r"^const ([A-Za-z_][A-Za-z0-9_]*) := preload\(\"res://scripts/core/([a-z_0-9]+)\.gd\"\)",
	re.M,
)
GROUP_RESIZE_RE = re.compile(
	r"^\tfor ([a-z_]+)(?:: Packed[A-Za-z0-9]+Array)? in \[([\s\S]*?)\]:\n((?:\t\t[^\n]*\n)+)",
	re.M,
)
# REG-C4-R01 independent-review F-01: a direct resize is now recognised at ANY
# indentation (nested if/for/match bodies), with an optional `self.` prefix,
# and as the tail of a single inline compound statement (`if cond: x.resize(...)`).
# Additional direct resize spellings are counted below: an unmatched call must
# quarantine the row even when a different, supported resize was recognised.
DIRECT_RESIZE_TEMPLATE = r"^[ \t]*(?:\S.*:[ \t]*)?(?:self\.)?%s\.resize\(([^\n]+)\)[ \t]*$"
CLAMPI_RE = re.compile(r"^[ \t]*(?:self\.)?(_[a-z0-9_]+) = clampi\(([^,]+), *(-?\d+), *([^()]+?)\)[ \t]*$", re.M)
# REG-C4-R01 independent-review F-02: every AUGMENTED runtime assignment counts
# too (=, +=, -=, *=, /=, %=, **=, <<=, >>=, &=, |=, ^=), with an optional
# `self.` prefix and conventional whitespace, so a single clamp proof cannot
# ignore a later write that moves the variable past its proved maximum.
# `%%=` below escapes the literal `%` this template is later formatted with via `%`.
ASSIGN_RE_TEMPLATE = (
	r"(?<![A-Za-z0-9_.])(?:self\.)?%s[ \t]*"
	r"(?:\*\*=|<<=|>>=|\+=|-=|\*=|/=|%%=|&=|\|=|\^=|=(?!=))"
)

TERM_RE = re.compile(r"^(?:\d+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)$")
RUNTIME_VAR_RE = re.compile(r"^_[a-z0-9_]+$")
DECIMAL_RE = re.compile(r"^\d+$")
UPPER_NAME_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
QUALIFIED_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Z][A-Z0-9_]*)$")
# REG-C4-R01 allowlists sums ('+') of products ('*') and qualified constants only.
# Everything below -- unary sign, parentheses, subtraction, division, calls,
# indexing, comparisons, bitwise operators -- halts resolution rather than being
# folded or guessed at.
NON_ALLOWLISTED_OPERATORS = "-/%()<>&|^~"


class Proved(NamedTuple):
	"""A value established from GDScript source, with the steps that established it."""

	value: int
	chain: tuple


class Unproved(NamedTuple):
	"""An explicit refusal. Carries why; carries no substitute value of any kind."""

	reason: str
	detail: str


class Binding(NamedTuple):
	"""The one `resize(...)` argument that sizes a column, and the line it sits on."""

	expression: str
	line: int


class Parse(NamedTuple):
	"""One reading of a declared_capacity string under the closed prose grammar."""

	expression: str
	relation: str
	value: int


class Module(NamedTuple):
	"""One parsed `godot/scripts/core/*.gd` file, reduced to what a capacity proof needs."""

	name: str
	relative_path: str
	text: str
	sha256: str
	columns: dict
	int_vars: dict
	consts: dict
	aliases: dict


def _line_of(text: str, offset: int) -> int:
	"""1-based line number of a character offset, for provenance that a reader can open."""
	return text.count("\n", 0, offset) + 1


def _collect_consts(text: str) -> dict:
	"""Map every integer `const` to (expression, line), marking redefinitions ambiguous."""
	found: dict = {}
	for pattern in (CONST_TYPED_RE, CONST_INFERRED_RE):
		for match in pattern.finditer(text):
			name = match.group(1)
			expression = match.group(2).strip()
			if expression.startswith("preload("):
				continue
			line = _line_of(text, match.start())
			if name in found and found[name][0] != expression:
				found[name] = (None, line)
			elif name not in found:
				found[name] = (expression, line)
	return found


def parse_module(name: str, relative_path: str, text: str) -> Module:
	"""Reduce one GDScript module to its columns, int vars, constants and preload aliases."""
	columns = {m.group(1): _line_of(text, m.start()) for m in COLUMN_RE.finditer(text)}
	int_vars = {m.group(1): _line_of(text, m.start()) for m in INT_VAR_RE.finditer(text)}
	aliases = {m.group(1): m.group(2) for m in ALIAS_RE.finditer(text)}
	return Module(
		name=name,
		relative_path=relative_path,
		text=text,
		sha256=hashlib.sha256(text.encode("utf-8")).hexdigest(),
		columns=columns,
		int_vars=int_vars,
		consts=_collect_consts(text),
		aliases=aliases,
	)


def load_source_index(core_dir: pathlib.Path = CORE_DIR) -> dict:
	"""Parse every core module once. The audit reads source only through this index."""
	index: dict = {}
	for path in sorted(core_dir.glob("*.gd")):
		relative = path.relative_to(ROOT).as_posix()
		index[path.stem] = parse_module(path.stem, relative, path.read_text())
	return index


# --- prose grammar --------------------------------------------------------

# The backtick class admits the same characters the resize-binding expression
# may use under REG-C4-R01: names, dots, digits, `*` and `+`. A prose reading
# still has to be the SAME text as the source's own resize argument (checked
# later in resize_binding/audit_field); widening this class only lets the
# prose SAY a sum, never lets it be believed without that binding match.
LHS_RE = re.compile(r"^\s*`([A-Za-z0-9_. +*]+)`\s*$")
RHS_RE = re.compile(r"^\s*(\d+)\s*$")
RELATION_SPELLINGS = (("<=", RELATION_LTE), ("=", RELATION_EQ))


def prose_candidates(prose: str) -> list:
	"""Every reading of the prose under the closed grammar, in split order.

	Each occurrence of a relation spelling is tried as the split point. `<=`
	contains `=`, so a lenient left-hand side would make every bound ALSO read
	as an equality; that reading is rejected here only because the left side
	must be exactly a backticked expression. Returning the list rather than the
	first hit is what lets the caller refuse ambiguity instead of preferring one.
	"""
	found: list = []
	for spelling, relation in RELATION_SPELLINGS:
		start = 0
		while True:
			at = prose.find(spelling, start)
			if at < 0:
				break
			start = at + 1
			left = LHS_RE.match(prose[:at])
			right = RHS_RE.match(prose[at + len(spelling):])
			if left and right:
				found.append(Parse(left.group(1).strip(), relation, int(right.group(1))))
	return found


def select_single_parse(candidates: list):
	"""Exactly one reading is a parse; zero or several are explicit refusals."""
	if not candidates:
		return Unproved("unparsed_prose", "no reading matches `expr` (= | <=) <digits>")
	unique = sorted(set(candidates))
	if len(unique) != 1:
		return Unproved("ambiguous_prose", "reads %d ways: %s" % (len(unique), unique))
	return unique[0]


def parse_prose(prose: str):
	"""Parse one declared_capacity string, or refuse. Returns a `Parse` or `Unproved`."""
	return select_single_parse(prose_candidates(prose))


# --- restricted integer resolution ---------------------------------------


def _guard_int64(value: int, where: str):
	"""Refuse any intermediate or final value a real int64 column could not hold."""
	if INT64_MIN <= value <= INT64_MAX:
		return Proved(value, ())
	return Unproved("overflow", "%s resolved to %d, outside int64" % (where, value))


def resolve_expression(index: dict, module: str, expression: str, depth: int = 0):
	"""Resolve an allowlisted sum of products (REG-C4-R01).

	The grammar is `sum := product ('+' product)*; product := term ('*' term)*`,
	with `*` binding before `+` and both associating left to right. Every
	intermediate result -- each product's running multiplication AND the running
	sum across `+` -- is checked against signed int64 before the next step is
	taken, including inside a nested constant's own definition, so an
	overflowing intermediate can never be rescued by a later term that happens
	to bring the total back into range.
	"""
	if depth > MAX_RESOLVE_DEPTH:
		return Unproved("resolution_too_deep", "exceeded %d substitutions" % MAX_RESOLVE_DEPTH)
	if module not in index:
		return Unproved("unknown_module", "no godot/scripts/core/%s.gd" % module)
	operators = sorted({character for character in expression if character in NON_ALLOWLISTED_OPERATORS})
	if operators:
		# REG-C4-R01 allowlists sums of products and qualified constants: `+` and
		# `*` only, left-associative, with `*` binding tighter. Everything else --
		# unary sign, parentheses, subtraction, division and the rest -- halts
		# here instead of being folded. That is a deliberate refusal, not a
		# parser gap: widening the grammar further is a decision for the
		# reviewer of this sidecar, and the quarantine row names the exact
		# definition and line where resolution stopped.
		return Unproved("non_allowlisted_operator",
			"%r uses %s; REG-C4-R01 allowlists sums of products and qualified constants only"
			% (expression, "".join(operators)))
	total = 0
	chain: list = []
	for summand in expression.split("+"):
		product = resolve_product(index, module, summand.strip(), depth)
		if isinstance(product, Unproved):
			return product
		chain.extend(product.chain)
		guarded = _guard_int64(total + product.value, expression)
		if isinstance(guarded, Unproved):
			return guarded
		total = guarded.value
	return Proved(total, tuple(chain))


def resolve_product(index: dict, module: str, expression: str, depth: int):
	"""Resolve one product term: literals and names joined by `*`, left to right."""
	terms = [term.strip() for term in expression.split("*")]
	if any(not TERM_RE.match(term) for term in terms):
		return Unproved("unsupported_expression", "%r is not literals and names joined by `*`" % expression)
	total = 1
	chain: list = []
	for term in terms:
		resolved = resolve_term(index, module, term, depth)
		if isinstance(resolved, Unproved):
			return resolved
		chain.extend(resolved.chain)
		guarded = _guard_int64(total * resolved.value, expression)
		if isinstance(guarded, Unproved):
			return guarded
		total = guarded.value
	return Proved(total, tuple(chain))


def resolve_term(index: dict, module: str, term: str, depth: int):
	"""Resolve one term: a decimal literal, a module constant, or `Alias.CONST`."""
	if DECIMAL_RE.match(term):
		return _guard_int64(int(term), term)
	qualified = QUALIFIED_RE.match(term)
	if qualified:
		alias, name = qualified.group(1), qualified.group(2)
		target = index[module].aliases.get(alias)
		if target is None:
			return Unproved("unknown_alias", "%s.gd has no `const %s := preload(...)`" % (module, alias))
		return _resolve_const(index, target, name, depth, "%s.%s" % (alias, name))
	if UPPER_NAME_RE.match(term):
		return _resolve_const(index, module, term, depth, term)
	return Unproved("unknown_symbol", "%r is not a literal, constant or qualified constant" % term)


def _resolve_const(index: dict, module: str, name: str, depth: int, label: str):
	"""Look one constant up in exactly one named module and resolve its own expression."""
	if module not in index:
		return Unproved("unknown_module", "no godot/scripts/core/%s.gd" % module)
	entry = index[module].consts.get(name)
	if entry is None:
		return Unproved("unknown_symbol", "%s.gd declares no `const %s`" % (module, name))
	expression, line = entry
	if expression is None:
		return Unproved("ambiguous_symbol", "%s.gd declares %s more than once" % (module, name))
	inner = resolve_expression(index, module, expression, depth + 1)
	if isinstance(inner, Unproved):
		return Unproved(inner.reason, "%s halted at %s:%d `const %s = %s`: %s"
			% (label, index[module].relative_path, line, name, expression, inner.detail))
	step = "%s -> %s:%d `const %s = %s` = %d" % (label, index[module].relative_path, line, name, expression, inner.value)
	return Proved(inner.value, inner.chain + (step,))


def resolve_clamped_bound(index: dict, module: str, variable: str):
	"""Prove a runtime int var's MAXIMUM: exactly one `clampi(arg, lo, MAX)` assignment."""
	if module not in index:
		return Unproved("unknown_module", "no godot/scripts/core/%s.gd" % module)
	source = index[module]
	if variable not in source.int_vars:
		return Unproved("unknown_symbol", "%s.gd declares no `var %s: int`" % (module, variable))
	assignment_source = "\n".join(line for line in source.text.splitlines()
		if not line.lstrip().startswith("#"))
	assignments = re.findall(ASSIGN_RE_TEMPLATE % re.escape(variable), assignment_source, re.M)
	clamps = [m for m in CLAMPI_RE.finditer(source.text) if m.group(1) == variable]
	if len(clamps) != 1 or len(assignments) != len(clamps):
		return Unproved(
			"unbounded_runtime_variable",
			"%s.gd assigns %s %d time(s) with %d clampi bound(s)" % (module, variable, len(assignments), len(clamps)),
		)
	clamp = clamps[0]
	bound = resolve_expression(index, module, clamp.group(4).strip())
	if isinstance(bound, Unproved):
		return bound
	step = "%s -> %s:%d `clampi(%s, %s, %s)` max = %d" % (
		variable, source.relative_path, _line_of(source.text, clamp.start()),
		clamp.group(2).strip(), clamp.group(3), clamp.group(4).strip(), bound.value,
	)
	return Proved(bound.value, bound.chain + (step,))


def _flatten_terms(expression: str) -> list:
	"""Every leaf term across a sum of products, in left-to-right order.

	With only one summand this is exactly the old product-only term list, so a
	single-product expression's classification is unchanged; REG-C4-R01 only
	generalises this to look across every summand as well.
	"""
	terms: list = []
	for summand in expression.split("+"):
		terms.extend(term.strip() for term in summand.split("*"))
	return terms


def classify_from_source(index: dict, module: str, expression: str):
	"""Decide equality versus maximum FROM SOURCE, never from the prose operator.

	A compile-time constant sizes the column exactly. A runtime `var` narrowed by
	a single `clampi` sizes it at most. Mixing the two anywhere in the sum -- by
	`+` or by `*` -- is refused rather than collapsed, because the result would be
	neither claim.
	"""
	terms = _flatten_terms(expression)
	runtime = [term for term in terms if RUNTIME_VAR_RE.match(term)]
	if runtime and len(terms) > 1:
		return RELATION_LTE, Unproved("mixed_dynamic_expression",
			"%r mixes runtime var(s) %s with other term(s)" % (expression, runtime))
	if runtime:
		return RELATION_LTE, resolve_clamped_bound(index, module, runtime[0])
	return RELATION_EQ, resolve_expression(index, module, expression)


# --- binding a registry field to its column ------------------------------


def resize_binding(index: dict, module: str, member: str):
	"""The single `resize(...)` argument that sizes this column, with its line."""
	if module not in index:
		return Unproved("unknown_module", "no godot/scripts/core/%s.gd" % module)
	source = index[module]
	if member not in source.columns:
		return Unproved("missing_column", "%s.gd declares no packed column %s" % (module, member))
	# REG-C4-R01 independent-review F-01: DIRECT_RESIZE_TEMPLATE matches this column's
	# resize at any indentation and with or without a `self.` prefix, so a conflicting
	# resize nested inside an `if`/`for` body is no longer invisible to this scan.
	direct = list(re.finditer(DIRECT_RESIZE_TEMPLATE % re.escape(member), source.text, re.M))
	# Count every direct call token, including unsupported multiline/semicolon forms.
	# A supported call elsewhere must not hide an unrecognised second sizing.
	call_token = re.compile(r"(?<![A-Za-z0-9_])(?:self\.)?%s\.resize[ \t]*\(" % re.escape(member))
	call_count = sum(len(call_token.findall(line)) for line in source.text.splitlines()
		if not line.lstrip().startswith("#"))
	if call_count != len(direct):
		return Unproved("unsupported_resize", "%s.%s has an unrecognised direct resize" % (module, member))
	found = [(m.group(1).strip(), _line_of(source.text, m.start())) for m in direct]
	for group in GROUP_RESIZE_RE.finditer(source.text):
		members = [name.strip() for name in group.group(2).replace("\n", " ").split(",")]
		inner = re.search(r"%s\.resize\(([^\n]+)\)" % re.escape(group.group(1)), group.group(3))
		if member in members and inner:
			found.append((inner.group(1).strip(), _line_of(source.text, group.start())))
	distinct = sorted({expression for expression, _ in found})
	if not distinct:
		return Unproved("unsized_column", "%s.gd never resizes %s" % (module, member))
	if len(distinct) != 1:
		return Unproved("conflicting_resize", "%s.%s resized as %s" % (module, member, distinct))
	return Binding(distinct[0], min(line for _, line in found))


# --- per-field audit ------------------------------------------------------


def audit_field(index: dict, owner: dict, field: dict) -> dict:
	"""Audit one registry field and return its sidecar row, proved or quarantined."""
	row = {
		"section_id": owner["section_id"],
		"owner_key": owner["owner_key"],
		"ordinal": field["ordinal"],
		"field_key": field["field_key"],
		"source_module": field["source_module"],
		"source_member": field["source_member"],
		"declared_capacity_prose": field["shape"]["declared_capacity"],
	}
	parsed = parse_prose(row["declared_capacity_prose"])
	if isinstance(parsed, Unproved):
		return _quarantine(row, "unproved_" + parsed.reason, parsed.detail)
	row["parsed_expression"] = parsed.expression
	row["prose_relation"] = parsed.relation
	row["prose_value"] = parsed.value
	binding = resize_binding(index, field["source_module"], field["source_member"])
	if isinstance(binding, Unproved):
		return _quarantine(row, "unproved_" + binding.reason, binding.detail)
	resize_expression, resize_line = binding.expression, binding.line
	row["source_file"] = index[field["source_module"]].relative_path
	row["source_resize_expression"] = resize_expression
	row["source_resize_line"] = resize_line
	if resize_expression != parsed.expression:
		return _quarantine(row, "unproved_binding_mismatch",
			"prose says %r; source sizes the column with %r" % (parsed.expression, resize_expression))
	return _finish(index, row, field, parsed)


def _finish(index: dict, row: dict, field: dict, parsed: Parse) -> dict:
	"""Resolve the bound expression from source and compare relation, then value."""
	relation, proof = classify_from_source(index, field["source_module"], parsed.expression)
	row["source_relation"] = relation
	if isinstance(proof, Unproved):
		return _quarantine(row, "unproved_" + proof.reason, proof.detail)
	row["source_value"] = proof.value
	row["proof_chain"] = list(proof.chain)
	row["proof_kind"] = "clamped_runtime_bound" if relation == RELATION_LTE else "compiled_constant"
	if relation != parsed.relation:
		return _quarantine(row, "finding_relation_mismatch",
			"prose claims %s but source proves %s; equality and maximum are different claims" % (parsed.relation, relation))
	if proof.value != parsed.value:
		return _quarantine(row, "finding_value_mismatch",
			"prose claims %d; source proves %d" % (parsed.value, proof.value))
	row["status"] = STATUS_PROVED_EQUALITY if relation == RELATION_EQ else STATUS_PROVED_UPPER_BOUND
	row["quarantine_reason"] = ""
	return row


def _quarantine(row: dict, status: str, detail: str) -> dict:
	"""Mark a row unproved or contradicted. No value is guessed and no row is dropped."""
	row["status"] = status
	row["quarantine_reason"] = detail
	return row


# --- sidecar assembly -----------------------------------------------------


def capacity_fields(registry: dict) -> list:
	"""Every canonical (`hash: true`) field carrying a `shape.declared_capacity`."""
	selected = []
	for owner in registry["owners"]:
		for field in owner["fields"]:
			if field.get("hash") and "declared_capacity" in field.get("shape", {}):
				selected.append((owner, field))
	return selected


def _census(registry: dict, rows: list) -> dict:
	"""Counts this run observed, beside Astra's, with the comparison stated explicitly."""
	fields = [f for o in registry["owners"] for f in o["fields"]]
	canonical = [f for f in fields if f.get("hash")]
	non_hash = [f for f in fields if not f.get("hash")]
	observed = {
		"registry_listed_fields": len(fields),
		"canonical_records": len(canonical),
		"non_hash_fields": len(non_hash),
		"non_hash_fields_carrying_declared_capacity":
			len([f for f in non_hash if "declared_capacity" in f.get("shape", {})]),
		"non_hash_fields_admitted_to_audit": 0,
		"owners": len(registry["owners"]),
		"prose_records": len(rows),
		"other_canonical_shapes": len([f for f in canonical if "declared_capacity" not in f.get("shape", {})]),
		"equality": len([r for r in rows if r.get("prose_relation") == RELATION_EQ]),
		"upper_bound": len([r for r in rows if r.get("prose_relation") == RELATION_LTE]),
		"distinct_expressions": len({r["declared_capacity_prose"] for r in rows}),
		"packed_source_fields": registry["packed_source_field_count"],
	}
	# A difference is EXPLAINED when it is exactly the delta a recorded decision accounts for,
	# and UNEXPLAINED otherwise. Collapsing the two would mean either suppressing a real drift
	# or refusing forever on a drift already understood -- and the second teaches people to
	# ignore the line, which is the same failure as the first.
	explained: list = []
	unexplained: list = []
	for key, value in sorted(ASTRA_CYCLE_03_CENSUS.items()):
		seen = observed.get(key)
		if seen == value:
			continue
		delta = seen - value
		line = "%s: this audit %d, Astra Cycle 3 %d (%+d)" % (key, seen, value, delta)
		if EXPLAINED_SINCE_CENSUS.get(key) == delta:
			explained.append(line + " -- decision 0142 retired three deposit members")
		else:
			unexplained.append(line)
	return {
		"observed": observed,
		"astra_cycle_03": dict(ASTRA_CYCLE_03_CENSUS),
		"astra_cycle_03_taken_at": ASTRA_CYCLE_03_CENSUS_AT,
		"agrees_with_astra_cycle_03": not explained and not unexplained,
		"explained_since_census": explained,
		"disagreements": unexplained,
	}


def _status_counts(rows: list) -> dict:
	"""How many rows landed in each status, so a silent drop cannot hide in a total."""
	counts: dict = {}
	for row in rows:
		counts[row["status"]] = counts.get(row["status"], 0) + 1
	return counts


def build_audit(registry: dict, index: dict) -> dict:
	"""Assemble the whole sidecar. Deterministic: ordered by (section, owner, ordinal)."""
	pairs = capacity_fields(registry)
	rows = [audit_field(index, owner, field) for owner, field in pairs]
	rows.sort(key=lambda row: (row["section_id"], row["owner_key"], row["ordinal"], row["field_key"]))
	keys = [(r["section_id"], r["owner_key"], r["ordinal"], r["field_key"]) for r in rows]
	if len(set(keys)) != len(keys):
		raise SystemExit("REFUSED: duplicate audit key; the registry is not uniquely keyed")
	modules = sorted({row["source_module"] for row in rows})
	return {
		"audit_id": AUDIT_ID,
		"audit_schema_version": AUDIT_SCHEMA_VERSION,
		"contract": "REG-C3-R01 (docs/rulings/2026-09-14_cycle03_save_counts_and_capacities.md); "
			"REG-C4-R01 (docs/rulings/2026-09-19_cycle04_resumption.md)",
		"kind": "read_only_sidecar",
		"adopted": False,
		"notes": [
			"Sidecar only: the active registry, its checker and every compiled declaration are unchanged.",
			"No prose capacity is converted into the registry here; a later ruling decides adoption.",
			"Every proof is GDScript source. Agreement with another document is never accepted as proof.",
			"Equality and upper bound are preserved as distinct claims and are never flattened.",
			"REG-C4-R01 extends the proof grammar to bounded, left-associative sums of the existing "
				"allowlisted products; no store, capacity or save schema changed as a result.",
			"source_registry_sha256 in the registry is NOT re-asserted by this audit; only the canonical JSON digest below is this audit's own observation.",
		],
		"audited_registry": {
			"registry_id": registry["registry_id"],
			"registry_version": registry["registry_version"],
			"registry_canonical_json_sha256": hashlib.sha256(
				json.dumps(registry, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest(),
			"path": REGISTRY_PATH.relative_to(ROOT).as_posix(),
		},
		"audited_source": {
			"root": CORE_DIR.relative_to(ROOT).as_posix(),
			"module_sha256": {name: index[name].sha256 for name in modules},
		},
		"census": _census(registry, rows),
		"status_counts": _status_counts(rows),
		"unproved_or_contradicted": [
			{k: row[k] for k in ("section_id", "owner_key", "ordinal", "field_key", "status", "quarantine_reason")}
			for row in rows if not row["status"].startswith("proved_")
		],
		"rows": rows,
		"non_capacity_canonical_records": _non_capacity_records(registry),
	}


def _non_capacity_records(registry: dict) -> list:
	"""The canonical records with no declared_capacity, listed so none is silently lost."""
	listed = []
	for owner in registry["owners"]:
		for field in owner["fields"]:
			if field.get("hash") and "declared_capacity" not in field.get("shape", {}):
				listed.append({
					"section_id": owner["section_id"],
					"owner_key": owner["owner_key"],
					"ordinal": field["ordinal"],
					"field_key": field["field_key"],
					"shape_keys": sorted(field.get("shape", {})),
				})
	listed.sort(key=lambda row: (row["section_id"], row["owner_key"], row["ordinal"], row["field_key"]))
	return listed


def render(audit: dict) -> str:
	"""Serialise deterministically: sorted keys, fixed indent, ASCII, one trailing newline."""
	return json.dumps(audit, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def main(argv: list) -> int:
	"""Regenerate or check the sidecar and print the census and proof summary."""
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--check", action="store_true", help="fail if the committed sidecar differs")
	args = parser.parse_args(argv)
	registry = json.loads(REGISTRY_PATH.read_text())
	audit = build_audit(registry, load_source_index())
	text = render(audit)
	if args.check:
		if not SIDECAR_PATH.exists() or SIDECAR_PATH.read_text() != text:
			print("REFUSED: %s is not what this source produces" % SIDECAR_PATH.relative_to(ROOT))
			return 1
	else:
		SIDECAR_PATH.write_text(text)
	return _report(audit)


def _report(audit: dict) -> int:
	"""Print the census, the proof counts and every disagreement or quarantine."""
	census = audit["census"]
	observed = census["observed"]
	print("registry: %d listed fields, %d canonical, %d non-hash (0 admitted here)"
		% (observed["registry_listed_fields"], observed["canonical_records"], observed["non_hash_fields"]))
	print("capacity census: %d prose = %d equality + %d upper bound, %d other canonical shapes, %d distinct expressions"
		% (observed["prose_records"], observed["equality"], observed["upper_bound"],
			observed["other_canonical_shapes"], observed["distinct_expressions"]))
	for status, count in sorted(audit["status_counts"].items()):
		print("  %-32s %d" % (status, count))
	for row in audit["unproved_or_contradicted"]:
		print("  QUARANTINE %s/%s#%d %s: %s -- %s"
			% (row["section_id"], row["owner_key"], row["ordinal"], row["field_key"], row["status"], row["quarantine_reason"]))
	for line in census["disagreements"]:
		print("  DISAGREEMENT WITH ASTRA CYCLE 3 CENSUS -- %s" % line)
	for line in census.get("explained_since_census", []):
		print("  explained drift -- %s" % line)
	if census["agrees_with_astra_cycle_03"]:
		print("census agrees with Astra Cycle 3 (%s): yes" % ASTRA_CYCLE_03_CENSUS_AT)
	elif not census["disagreements"]:
		print("census differs from Astra Cycle 3 (%s) only by recorded decisions: reconciled"
			% ASTRA_CYCLE_03_CENSUS_AT)
	else:
		print("census differs from Astra Cycle 3 (%s) in ways NO recorded decision explains: %d"
			% (ASTRA_CYCLE_03_CENSUS_AT, len(census["disagreements"])))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
