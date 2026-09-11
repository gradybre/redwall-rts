#!/usr/bin/env python3
"""Enforce docs/persistence_state_registry.md against godot/scripts/core.

Task 09.1 requires a future-affecting-state registry that cannot silently rot. A
document nobody executes rots the moment the next store lands, so this script is
the enforcement: it reads the packed columns straight out of the GDScript and
fails when the registry and the code disagree.

It checks, in order:

  C1  every module under godot/scripts/core has a registry section;
  C2  every registry section names a module that still exists;
  C3  every packed column declared in code appears in exactly one registry row;
  C4  every member named in the registry is declared in that module;
  C5  the registry's element width equals the width of the declared GDScript type;
  C6  the registry's count cell quotes the module's own `resize()` expression and,
      where that expression resolves from `const` declarations, its exact value;
  C7  a category is 1, 2, 3 or UNRESOLVED, and an UNRESOLVED row states a question;
  C8  every cited save section is one of ARCH-SAVE-002's fifteen, read out of
      docs/systems_architecture.md rather than transcribed here;
  C9  category 3 rows cite no save section, and categories 1 and 2 cite one.

It deliberately does NOT decide whether a classification is correct. Category is
a judgement this script cannot make; membership, width, count and section names
are facts it can, and those are what rot first.

Standalone, no arguments, exit 0 on success and non-zero on any failure.
Follows the constant-reading pattern of docs/validation/ready07_arithmetic.py,
which is not modified by this script.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "godot/scripts/core"
REGISTRY = ROOT / "docs/persistence_state_registry.md"
ARCHITECTURE = ROOT / "docs/systems_architecture.md"

# Element widths of the packed types this repository uses for authoritative state.
# PackedStringArray has no fixed element width; the registry writes "var" for it.
WIDTH = {
    "PackedByteArray": "1",
    "PackedInt32Array": "4",
    "PackedInt64Array": "8",
    "PackedStringArray": "var",
    "PackedFloat32Array": "4",
    "PackedFloat64Array": "8",
}

DECL_RE = re.compile(r"^var (_[A-Za-z0-9_]+): (Packed[A-Za-z0-9]+Array)\b", re.M)
ALIAS_RE = re.compile(
    r"^const ([A-Za-z_][A-Za-z0-9_]*) := preload\(\"res://scripts/core/([a-z_0-9]+)\.gd\"\)",
    re.M,
)
CONST_RE = re.compile(r"^const ([A-Z][A-Z0-9_]*): int = (.+?)\s*$", re.M)
CLAMP_RE = re.compile(r"^\t(_[a-z0-9_]+) = clampi\([a-z_0-9]+, \d+, ([A-Z][A-Z0-9_]*)\)\s*$", re.M)
GROUP_RE = re.compile(
    r"^\tfor ([a-z_]+)(?:: Packed[A-Za-z0-9]+Array)? in \[([\s\S]*?)\]:\n((?:\t\t[^\n]*\n)+)",
    re.M,
)
HEADING_RE = re.compile(r"^### `godot/scripts/core/([a-z_0-9]+)\.gd`\s*$")
SECTION_LIST_RE = re.compile(r"\*\*ARCH-SAVE-002\.\*\*[^\n]*")

failures: list[str] = []


def fail(message: str) -> None:
    """Record one failure; every check runs so one report lists them all."""
    failures.append(message)


def load_modules() -> dict:
    """Parse every core module's columns, preload aliases, constants and clamped bounds."""
    modules = {}
    for path in sorted(CORE.glob("*.gd")):
        text = path.read_text()
        modules[path.stem] = {
            "text": text,
            "columns": dict(DECL_RE.findall(text)),
            "order": [name for name, _ in DECL_RE.findall(text)],
            "alias": dict(ALIAS_RE.findall(text)),
            "const": dict(CONST_RE.findall(text)),
            "clamp": dict(CLAMP_RE.findall(text)),
        }
    return modules


MODULES = load_modules()


def const_value(module: str, expr: str, depth: int = 0):
    """Resolve a GDScript integer constant expression, or None when it is not static."""
    if depth > 16:
        return None
    text = expr.strip()
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    qualified = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\.([A-Z][A-Z0-9_]*)", text)
    if qualified and qualified.group(1) in MODULES[module]["alias"]:
        target = MODULES[module]["alias"][qualified.group(1)]
        inner = MODULES[target]["const"].get(qualified.group(2))
        return None if inner is None else const_value(target, inner, depth + 1)
    if re.fullmatch(r"[A-Z][A-Z0-9_]*", text):
        inner = MODULES[module]["const"].get(text)
        return None if inner is None else const_value(module, inner, depth + 1)
    if not re.fullmatch(r"[A-Za-z0-9_.()+\-*/<> ]+", text):
        return None
    return _fold(module, text, depth)


def _fold(module: str, text: str, depth: int):
    """Substitute every name in an arithmetic expression, then evaluate it as integers."""

    def replace(match: re.Match) -> str:
        resolved = const_value(module, match.group(0), depth + 1)
        return "?" if resolved is None else "(%d)" % resolved

    folded = re.sub(r"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Z][A-Z0-9_]*)?\b", replace, text)
    if "?" in folded:
        return None
    try:
        return int(eval(folded.replace("/", "//")))  # noqa: S307 - digits and operators only
    except (ArithmeticError, SyntaxError, ValueError):
        return None


def resize_expression(module: str, column: str):
    """The literal argument of the `resize()` that sizes one column, or None if never sized."""
    text = MODULES[module]["text"]
    direct = re.search(r"^\t%s\.resize\(([^\n]+)\)\s*$" % re.escape(column), text, re.M)
    if direct:
        return direct.group(1)
    for group in GROUP_RE.finditer(text):
        members = [name.strip() for name in group.group(2).replace("\n", " ").split(",")]
        if column in members:
            inner = re.search(r"%s\.resize\(([^\n]+)\)" % re.escape(group.group(1)), group.group(3))
            if inner:
                return inner.group(1)
    return None


def save_sections() -> dict:
    """ARCH-SAVE-002's fifteen section ids and names, read out of systems_architecture.md."""
    text = ARCHITECTURE.read_text()
    match = SECTION_LIST_RE.search(text)
    if not match:
        fail("ARCH-SAVE-002 was not found in docs/systems_architecture.md")
        return {}
    pairs = re.findall(r"(\d+) ([A-Z][A-Z_]+)", match.group(0))
    sections = {int(number): name for number, name in pairs}
    if len(sections) != 15:
        fail("ARCH-SAVE-002 parsed %d sections, expected 15" % len(sections))
    return sections


SECTIONS = save_sections()


def parse_registry() -> dict:
    """Read the registry into {module: [row dicts]}, failing on malformed structure."""
    if not REGISTRY.exists():
        fail("missing registry: %s" % REGISTRY.relative_to(ROOT))
        return {}
    parsed: dict = {}
    current = None
    for number, line in enumerate(REGISTRY.read_text().splitlines(), start=1):
        heading = HEADING_RE.match(line)
        if heading:
            current = heading.group(1)
            if current in parsed:
                fail("line %d: duplicate registry section for %s.gd" % (number, current))
            parsed[current] = []
            continue
        if not line.startswith("| ") or current is None:
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 8 or cells[0] in ("Column group", "") or set(cells[0]) <= {"-", ":"}:
            continue
        parsed[current].append({"line": number, "cells": cells})
    return parsed


REGISTRY_ROWS = parse_registry()


def check_module_coverage() -> None:
    """C1/C2: registry sections and core modules are the same set."""
    on_disk = {path.stem for path in CORE.glob("*.gd")}
    for stem in sorted(on_disk - set(REGISTRY_ROWS)):
        fail("C1 %s.gd has no registry section -- a new store must be classified" % stem)
    for stem in sorted(set(REGISTRY_ROWS) - on_disk):
        fail("C2 registry names godot/scripts/core/%s.gd, which does not exist" % stem)
    for stem in sorted(set(REGISTRY_ROWS) & on_disk):
        if not REGISTRY_ROWS[stem]:
            fail("C1 %s.gd has an empty registry section" % stem)


def row_members(module: str, row: dict) -> list:
    """The backticked member names of one row, or [] for a row that lists no column."""
    cell = row["cells"][1]
    if cell == "--":
        return []
    names = re.findall(r"`(_[A-Za-z0-9_]+)`", cell)
    if not names:
        fail("C4 %s.gd line %d: member cell %r names no column" % (module, row["line"], cell))
    return names


def check_membership() -> None:
    """C3/C4: every declared column is claimed exactly once and every claim is real."""
    for module in sorted(set(REGISTRY_ROWS) & set(MODULES)):
        seen: dict = {}
        for row in REGISTRY_ROWS[module]:
            for name in row_members(module, row):
                if name not in MODULES[module]["columns"]:
                    fail("C4 %s.gd line %d: `%s` is not a packed column there"
                         % (module, row["line"], name))
                elif name in seen:
                    fail("C3 %s.gd line %d: `%s` already claimed on line %d"
                         % (module, row["line"], name, seen[name]))
                else:
                    seen[name] = row["line"]
        for name in MODULES[module]["order"]:
            if name not in seen:
                fail("C3 %s.gd declares `%s` with no registry row" % (module, name))


def check_width(module: str, row: dict, members: list) -> None:
    """C5: the stated element width matches every member's declared packed type."""
    stated = row["cells"][2]
    for name in members:
        declared = MODULES[module]["columns"].get(name)
        if declared is None:
            continue
        expected = WIDTH.get(declared)
        if expected is None:
            fail("C5 %s.gd line %d: unknown packed type %s" % (module, row["line"], declared))
        elif stated != expected:
            fail("C5 %s.gd line %d: `%s` is %s (width %s) but the registry says %s"
                 % (module, row["line"], name, declared, expected, stated))


COUNT_RE = re.compile(r"^`([^`]+)` (?:(=|<=) (\d+)|(runtime))$")


def check_count(module: str, row: dict, members: list) -> None:
    """C6: the count cell quotes the code's own resize expression and its resolved value."""
    stated = row["cells"][3]
    for name in members:
        expression = resize_expression(module, name)
        if stated == "never allocated":
            if expression is not None:
                fail("C6 %s.gd line %d: `%s` is resized to %s, not 'never allocated'"
                     % (module, row["line"], name, expression))
            continue
        if expression is None:
            fail("C6 %s.gd line %d: `%s` has no resize() call; say 'never allocated'"
                 % (module, row["line"], name))
            continue
        match = COUNT_RE.match(stated)
        if not match:
            fail("C6 %s.gd line %d: count %r is not `EXPR` = N, `EXPR` <= N, `EXPR` runtime"
                 " or 'never allocated'" % (module, row["line"], stated))
            return
        if match.group(1) != expression:
            fail("C6 %s.gd line %d: `%s` is resized to `%s`, registry quotes `%s`"
                 % (module, row["line"], name, expression, match.group(1)))
            continue
        _check_count_value(module, row, name, expression, match)


def _check_count_value(module: str, row: dict, name: str, expression: str, match: re.Match) -> None:
    """The numeric half of C6: '=' is static, '<=' is construction-clamped, 'runtime' is neither."""
    relation, stated_value = match.group(2), match.group(3)
    direct = const_value(module, expression)
    bound = MODULES[module]["clamp"].get(expression)
    if direct is not None:
        expected, wanted = direct, "="
    elif bound is not None:
        expected, wanted = const_value(module, bound), "<="
    else:
        expected, wanted = None, "runtime"
    if relation != wanted and not (wanted == "runtime" and match.group(4)):
        fail("C6 %s.gd line %d: `%s` count `%s` requires the '%s' form"
             % (module, row["line"], name, expression, wanted))
    elif expected is not None and int(stated_value) != expected:
        fail("C6 %s.gd line %d: `%s` resizes to %d, registry says %s"
             % (module, row["line"], name, expected, stated_value))


def check_category_and_section(module: str, row: dict) -> None:
    """C7/C8/C9: a legal category, a real ARCH-SAVE-002 section, and the two agreeing."""
    category, section, notes = row["cells"][5], row["cells"][6], row["cells"][7]
    if category not in ("1", "2", "3", "UNRESOLVED"):
        fail("C7 %s.gd line %d: category %r is not 1, 2, 3 or UNRESOLVED"
             % (module, row["line"], category))
        return
    if category == "UNRESOLVED" and "?" not in notes:
        fail("C7 %s.gd line %d: an UNRESOLVED row must state its question in Notes"
             % (module, row["line"]))
    if category == "3":
        if section != "--":
            fail("C9 %s.gd line %d: a category 3 row is not saved; its section must be --"
                 % (module, row["line"]))
        return
    match = re.match(r"^§(\d+) ([A-Z][A-Z_]+)$", section)
    if not match:
        fail("C8 %s.gd line %d: section %r is not '§N NAME'" % (module, row["line"], section))
        return
    number, name = int(match.group(1)), match.group(2)
    if SECTIONS.get(number) != name:
        fail("C8 %s.gd line %d: ARCH-SAVE-002 has no section %d %s (it has %r)"
             % (module, row["line"], number, name, SECTIONS.get(number)))


def check_rows() -> None:
    """Run the per-row checks over every section that names a live module."""
    for module in sorted(set(REGISTRY_ROWS) & set(MODULES)):
        for row in REGISTRY_ROWS[module]:
            members = row_members(module, row)
            check_category_and_section(module, row)
            if not members:
                continue
            check_width(module, row, members)
            check_count(module, row, members)


def main() -> int:
    """Run every check, print the outcome, and return a process exit status."""
    check_module_coverage()
    check_membership()
    check_rows()
    columns = sum(len(info["columns"]) for info in MODULES.values())
    if failures:
        for message in failures:
            print("FAIL %s" % message)
        print("state_registry_coverage: %d failure(s)" % len(failures))
        return 1
    rows = sum(len(rows) for rows in REGISTRY_ROWS.values())
    print("state_registry_coverage: PASS -- %d modules, %d rows, %d packed columns checked"
          % (len(REGISTRY_ROWS), rows, columns))
    return 0


if __name__ == "__main__":
    sys.exit(main())
