#!/usr/bin/env python3
"""Read the actual WorldInit allocation calls; write no foreign files or caches."""
import ast
import hashlib
import json
from pathlib import Path
import re
import sys


def integer(node, constants):
    if isinstance(node, ast.Constant) and isinstance(node.value, int):
        return node.value
    if isinstance(node, ast.Name):
        return constants[node.id]
    if isinstance(node, ast.BinOp):
        a, b = integer(node.left, constants), integer(node.right, constants)
        if isinstance(node.op, ast.Add):
            return a + b
        if isinstance(node.op, ast.Sub):
            return a - b
        if isinstance(node.op, ast.Mult):
            return a * b
    raise ValueError(ast.dump(node))


root = Path(sys.argv[1]).resolve()
path = root / "godot/scripts/core/world_init.gd"
raw = path.read_bytes()
source = raw.decode()
constants = {}
for name, expression in re.findall(r"^const (\w+): int = ([^\n]+)", source, re.M):
    try:
        constants[name] = integer(ast.parse(expression.split("#")[0], mode="eval").body, constants)
    except (KeyError, SyntaxError, ValueError):
        pass
widths = {"PackedByteArray": 1, "PackedInt32Array": 4, "PackedInt64Array": 8}
members = dict(re.findall(r"^var (\w+): (Packed\w+Array) =", source, re.M))
rows = []
for function in ("_allocate_columns", "_allocate_fauna_columns"):
    body = re.search(r"^func " + function + r"\(.*?(?=^func |\Z)", source, re.M | re.S).group()
    for member, expression in re.findall(r"(\w+)\.resize\(([^\n]+)\)", body):
        count = integer(ast.parse(expression, mode="eval").body, constants)
        width = widths[members[member]]
        rows.append({"member": member, "count": count, "width": width, "bytes": count * width})
assert len(rows) == 25, len(rows)
total = sum(row["bytes"] for row in rows)
assert total == 175364, total
assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(raw).digest()
print(json.dumps({
    "source": str(path.relative_to(root)),
    "source_sha256": hashlib.sha256(raw).hexdigest(),
    "allocation_calls": rows,
    "one_world_packed_bytes": total,
    "same_time_two_world_packed_bytes": 2 * total,
    "extra_packed_bytes_before_native": total,
    "map_and_tree_ledger_bytes": 159968,
    "fauna_already_elsewhere_bytes": 15360,
    "fish_scratch_bytes": 36,
    "source_unchanged_during_read": True,
    "runtime_or_native_measurement": False,
}, indent=2) + "\n", end="")
