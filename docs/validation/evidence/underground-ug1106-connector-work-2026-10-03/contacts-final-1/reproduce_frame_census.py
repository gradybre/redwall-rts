#!/usr/bin/env python3
"""Reproduce the pinned logical helper-frame census; this is not native profiling."""
import hashlib
import json
import re
from pathlib import Path


SOURCE = "godot/scripts/core/underground_connector_contacts.gd"
EXPECTED = "16a6c3a5e5792b1c938502edee32e8f6d4b251596b6078435cd4e6f531c989b2"
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}


def main() -> None:
    root = next(parent for parent in Path(__file__).resolve().parents if (parent / SOURCE).is_file())
    payload = (root / SOURCE).read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != EXPECTED:
        raise SystemExit("Frozen source changed; review the census rather than silently reusing it")
    source = payload.decode("utf-8")
    declarations = list(re.finditer(r"^(?:static )?func (\w+)\(", source, re.M))
    functions = {}
    for index, match in enumerate(declarations):
        end = declarations[index + 1].start() if index + 1 < len(declarations) else len(source)
        signature, body = source[match.end():end].split("->", 1)
        body = body.split("\n", 1)[1]
        numeric = re.findall(r"(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", signature)
        numeric += re.findall(r"\b(?:var|for)\s+(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", body)
        body = re.sub(r'""".*?"""', "", body, flags=re.S)
        functions[match[1]] = {
            "bytes": sum(WIDTHS[kind] for _, kind in numeric),
            "numeric_fields": numeric,
            "calls": set(re.findall(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", body)),
        }

    def chain(name, visited=()):
        if name in visited:
            raise SystemExit("Recursive helper chain needs explicit lifetime review")
        child = max((chain(callee, visited + (name,)) for callee in functions[name]["calls"]
                     if callee in functions), default=(0, []))
        return functions[name]["bytes"] + child[0], [name] + child[1]

    maximum, names = max((chain(name) for name in functions), key=lambda result: result[0])
    packet = {"top_level_packed": 376, "numeric_members": 148, "order_record": 96,
              "two_location_records": 232, "descriptor": 184, "selection": 168,
              "two_box_records": 64, "int_result": 9, "fragments": 1633}
    assert maximum == 289 and sum(packet.values()) == 2910
    assert maximum + 512 <= 1024 and sum(packet.values()) + 1024 <= 4096
    report = {
        "source": SOURCE, "source_sha256": digest,
        "scope": "Numeric arguments and typed locals in direct own-file calls; refs, native frames and temporaries are not measured",
        "runtime_reflection_test": "test_reflected_fixed_packets_fit_the_admitted_control_reserve",
        "reused_packet_bytes": packet, "reused_total": sum(packet.values()),
        "longest_own_chain_bytes": maximum,
        "chain": [{"function": name, "bytes": functions[name]["bytes"],
                   "numeric_fields": functions[name]["numeric_fields"]} for name in names],
        "existing_nested_reader_helper_allowance": 512, "conservative_nested_sum": maximum + 512,
        "admitted_helper_allowance": 1024, "total_with_allowance": sum(packet.values()) + 1024,
        "contacts_reserve": 4096, "native_qualification": False,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
