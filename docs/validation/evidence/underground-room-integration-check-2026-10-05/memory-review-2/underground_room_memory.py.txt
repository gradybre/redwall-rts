#!/usr/bin/env python3
"""Replay reviewed room lifetimes before projecting unchanged historical slices.

Current source text is checked first, including caller-injected mutations. The
historical projection is an explicit accounting decomposition, never a runtime
source substitution. New transactions and constructor states are recounted by
their own reviewed producers within the original reservations.
"""
from __future__ import annotations

import builtins
import hashlib
import json
from pathlib import Path
import re
from types import SimpleNamespace

import audit_registry_capacities as audit

ROOT = Path(__file__).resolve().parents[1]
E = Path("docs/validation/evidence/underground-room-memory-integration-2026-10-05")
MANIFEST = E / "manifest.json"
MANIFEST_SHA = "40097d0372f0bd4c351f51f75882e151778e8c94248a3af20b414349f9c675b7"
P = Path("docs/validation/evidence/underground-room-frontier-publication-2026-10-04")
I = Path("docs/validation/evidence/underground-room-itinerary-census-2026-10-05")
C = Path("docs/validation/evidence/underground-room-owner-composition-2026-10-04")
G = Path("docs/validation/evidence/underground-ground-pace-2026-10-04")


def require(condition, message):
    if not condition:
        raise ValueError("room memory: " + message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verified_inputs(index):
    """Verify the complete producer/baseline closure before any code executes."""
    data = (ROOT / MANIFEST).read_bytes()
    require(digest(data) == MANIFEST_SHA, "immutable manifest changed")
    manifest = json.loads(data)
    blobs = {}
    for relative, expected in manifest["witnesses"].items():
        raw = (ROOT / relative).read_bytes()
        require(digest(raw) == expected, "reviewed witness changed: " + relative)
        blobs[relative] = raw
    for group in ("baseline", "publisher_predecessors"):
        for row in manifest[group].values():
            raw = (ROOT / row["locator"]).read_bytes()
            require(digest(raw) == row["sha256"], "reviewed predecessor changed: " + row["locator"])
            blobs[row["locator"]] = raw
    current = dict(index)
    for name, row in manifest["sources"].items():
        if name not in current:
            current[name] = audit.parse_module(name, row["path"], (ROOT / row["path"]).read_text())
        module = current[name]
        require(module.name == name and module.relative_path == row["path"], "module identity: " + name)
        # Do not trust cached hashes or parsed constants when text was injected.
        require(digest(module.text.encode()) == row["sha256"], "current reviewed source changed: " + name)
        current[name] = audit.parse_module(name, module.relative_path, module.text)
    return manifest, blobs, current


def producer(relative, blobs, imports=None):
    """Execute only a previously verified producer, preserving assertions under -O."""
    require(str(relative) in blobs, "unverified producer: " + str(relative))
    namespace = {"__file__": str(ROOT / relative), "__name__": "_reviewed_room_census"}
    if imports:
        original = builtins.__import__

        def import_module(name, globals=None, locals=None, fromlist=(), level=0):
            if name in imports and level == 0:
                return imports[name]
            return original(name, globals, locals, fromlist, level)

        namespace["__builtins__"] = dict(vars(builtins), __import__=import_module)
    exec(compile(blobs[str(relative)], namespace["__file__"], "exec", optimize=0), namespace)
    return namespace


def normalized(result):
    return json.loads(json.dumps(result))


def same_accounting(actual, expected, label):
    actual, expected = dict(normalized(actual)), dict(expected)
    actual.pop("source_sha256", None)
    expected.pop("source_sha256", None)
    require(actual == expected, label + " reviewed allocation/lifetime result changed")


def publication(current, manifest, blobs):
    census = producer(P / "census.py", blobs)

    def source(name):
        require(name in manifest["sources"], "unreviewed publication dependency: " + name)
        module = current[name]
        census["SOURCES"][module.relative_path] = digest(module.text.encode())
        return module.text

    def predecessor(command, cwd, text):
        require(cwd == ROOT and text is True and len(command) == 3 and command[:2] == ["git", "show"],
                "unreviewed publication predecessor operation")
        revision, relative = command[2].split(":", 1)
        name = Path(relative).stem
        require(revision == "8373d146" and relative == "godot/scripts/core/" + name + ".gd"
                and name in manifest["publisher_predecessors"], "unreviewed publication predecessor")
        return blobs[manifest["publisher_predecessors"][name]["locator"]].decode()

    census["source"] = source
    census["subprocess"] = SimpleNamespace(check_output=predecessor)
    result = census["build"]()
    same_accounting(result, json.loads(blobs[str(P / "source-review-2/census.json")]), "publication")
    return result


def itinerary(current, blobs):
    census = producer(I / "census.py", blobs)
    result = census["build"]({name: module.text for name, module in current.items()})
    same_accounting(result, json.loads(blobs[str(I / "census.json")]), "itinerary")
    return result


def functions(source):
    """Complete local bodies for the unchanged constructor compatibility proof."""
    return {m[1]: m[0] for m in re.finditer(
        r"^(?:static )?func (\w+)\(.*?(?=^(?:static )?func |\Z)", source, re.M | re.S)}


def location_constructors(before, after):
    old, new = functions(before), functions(after)
    roots = {"configure", "bind_sites", "bind_room_orders", "exact_inventory_binding",
             "world_ref", "_write_header", "_reject_retention_callback"}
    seen = set()

    def visit(name):
        if name in seen:
            return
        seen.add(name)
        require(name in new and old[name] == new[name], "changed Locations constructor body: " + name)
        for child in set(re.findall(r"(?<![\w.])(?:self\.)?(\w+)\(", old[name])) & old.keys():
            visit(child)

    for name in sorted(roots):
        visit(name)
    for match in re.finditer(r"^class (\w+)\b[^\n]*:\n.*?(?=^\S|\Z)", before, re.M | re.S):
        pattern = r"^class " + re.escape(match[1]) + r"\b[^\n]*:\n.*?(?=^\S|\Z)"
        actual = re.search(pattern, after, re.M | re.S)
        require(actual is not None and actual[0] == match[0], "changed Locations constructor class: " + match[1])
    original = re.findall(r"^var .+$", before, re.M)
    current = re.findall(r"^var .+$", after, re.M)
    require(all(line in current for line in original), "changed Locations initializer")
    require([line for line in current if line not in original] == [
        "var _frontier: FrontierContext = null # Borrowed only for one admitted synchronous cold transaction."],
        "unreviewed Locations retained constructor delta")
    return sorted(seen)


def composition(current, historical, blobs):
    constructor = producer(C / "constructor_census.py", blobs)
    census = producer(C / "census.py", blobs, {"constructor_census": SimpleNamespace(**constructor)})
    closure = location_constructors(historical["underground_locations"].text, current["underground_locations"].text)
    # 1165 already checks every Provider body/member except the sole path
    # dispatch. That operation is absent from the inherited constructor closure.
    replacements = {role: current[Path(relative).stem].text for role, relative in census["FILES"].items()}
    constructor_sources = {module.relative_path: module.text for module in current.values()}
    for name in ("underground_locations", "underground_room_world_bindings"):
        constructor_sources[current[name].relative_path] = historical[name].text
    result = census["build"](replacements, constructor_sources)
    same_accounting(result, json.loads(blobs[str(C / "census.json")]), "composition")
    return result, closure


def ground_catalog(current, historical, blobs):
    census = producer(G / "census.py", blobs)

    class Inputs:
        def __truediv__(self, path):
            require(path in (census["PATH"], "godot/scripts/core/underground_profiles.gd"),
                    "unreviewed Catalog source read")
            return SimpleNamespace(read_text=lambda: current[Path(path).stem].text)

    inputs = Inputs()

    def predecessor(command, cwd, text):
        require(command == ["git", "show", census["BASE"] + ":" + census["PATH"]]
                and cwd is inputs and text is True, "unreviewed Catalog predecessor operation")
        return historical["underground_connector_catalog"].text

    census["ROOT"] = inputs
    census["subprocess"] = SimpleNamespace(check_output=predecessor)
    result = census["build"]()
    same_accounting(result, json.loads(blobs[str(G / "census.json")]), "ground Catalog")
    return result


def build(index):
    """Return a current recount and separately labelled historical owner inputs."""
    manifest, blobs, current = verified_inputs(index)
    historical = dict(current)
    for name, row in manifest["baseline"].items():
        module = current[name]
        historical[name] = audit.parse_module(name, module.relative_path, blobs[row["locator"]].decode())
    published = publication(current, manifest, blobs)
    paths = itinerary(current, blobs)
    owners, closure = composition(current, historical, blobs)
    ground = ground_catalog(current, historical, blobs)
    require(published["new_global_reservation"] == 0 and owners["additional_packed_bytes"] == 0,
            "new room reservation is not admitted")
    result = {
        "scope": __doc__, "manifest_sha256": MANIFEST_SHA,
        "current_source_sha256": {row["path"]: row["sha256"] for row in manifest["sources"].values()},
        "historical_projection": manifest["baseline"],
        "publication": published, "itinerary": paths, "composition": owners,
        "ground_catalog": ground,
        "unchanged_locations_constructor_closure": closure,
        "additional_global_reserved_bytes": 0, "runtime_qualified": False, "native_measured": False,
    }
    return result, historical


def reconcile(result, index, session, retirement, ui_reset):
    """Replace historical lifecycle figures with the reviewed current coexistence."""
    current = result["composition"]
    accounting = current["accounting"]
    require(accounting["retirement_reserved_bytes"] == retirement["accounting"]["retirement_reserved_bytes"]
            and accounting["profile_joint"] == retirement["accounting"]["joint_with_retirement"],
            "current composition joint differs")
    session["historical_foundation_source_sha256"] = session["source_sha256"]
    session["source_sha256"] = digest(index["underground_session"].text.encode())
    session["foundation_retained_numeric_bytes"] = session["retained_numeric_bytes"]
    session["retained_numeric_bytes"] += 16
    session["additional_composition_numeric_bytes_charged_to_retirement"] = 16
    session["historical_foundation_frames"] = session.pop("frames")
    session["current_composition_frames"] = current["phases"]["composition_own_prefix"]["frames"]
    for report in (retirement, ui_reset):
        report["historical_accounting"] = dict(report["accounting"])
        report["historical_frames"] = report.pop("frames")
        report["historical_source_sha256"] = report.pop("source_sha256")
        report["source_sha256"] = {path: digest(index[Path(path).stem].text.encode())
                                   for path in report["historical_source_sha256"]}
        report["current_composition_source_sha256"] = current["source_sha256"]
        report["current_constructor_exclusive_reuse"] = current["constructor_exclusive_reuse"]
    direct = current["phases"]["direct_reset"]["provisional_bytes"]
    retirement["accounting"].update(control_provisional_bytes=5673 + current["retained_numeric_delta"],
        control_remaining=6144 - 5673 - current["retained_numeric_delta"],
        helper_provisional_bytes=direct, helper_remaining=2048 - direct)
    retirement["current_frames"] = current["phases"]["direct_reset"]["frames"]
    ui_reset["accounting"].update(controls=accounting["controls"], helpers=accounting["helpers"])
    ui_reset["current_frames"] = current["phases"]["reset_with_ui"]["frames"]
