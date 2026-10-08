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
from types import ModuleType, SimpleNamespace

import audit_registry_capacities as audit

ROOT = Path(__file__).resolve().parents[1]
E = Path("docs/validation/evidence/underground-current-memory-2026-10-05")
MANIFEST = Path("docs/validation/evidence/underground-entry-source-phases-2026-10-05/memory-manifest-3.json")
MANIFEST_SHA = "0eb02a8f447fdea58032583e2828f4fe5f38dc28b15a9b810939cb532851ee7f"
PROJECTION = Path("docs/validation/evidence/underground-memory-census-2026-10-06/projection.json")
PROJECTION_SHA = "a40a0d6563cdb54b0fd4b7e92992fa5003d2dea7c9317dacc175c7d52f1cd932"
P = Path("docs/validation/evidence/underground-room-frontier-publication-2026-10-04")
I = Path("docs/validation/evidence/underground-room-itinerary-census-2026-10-05")
C = Path("docs/validation/evidence/underground-room-owner-composition-2026-10-04")
G = Path("docs/validation/evidence/underground-ground-pace-2026-10-04")
R = Path("docs/validation/evidence/underground-route-owner-composition-2026-10-04")
S = Path("docs/validation/evidence/underground-short-work-step-runtime-2026-10-05")
T = Path("docs/validation/evidence/underground-short-step-itinerary-2026-10-05")
A = Path("docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05")
Q = Path("docs/validation/evidence/underground-short-step-publication-2026-10-05")


def require(condition, message):
    if not condition:
        raise ValueError("room memory: " + message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def projection_rows():
    """ADR 1212: the archived manifest-3 bytes of inputs that changed after the last passing pack."""
    data = (ROOT / PROJECTION).read_bytes()
    require(digest(data) == PROJECTION_SHA, "immutable reviewed-source projection changed")
    rows = json.loads(data)["inputs"]
    for relative, row in rows.items():
        raw = (ROOT / row["locator"]).read_bytes()
        require(digest(raw) == row["sha256"], "archived reviewed source changed: " + relative)
    return rows


def reviewed_bytes(relative, expected, live, projection, projected):
    """Live bytes when unchanged; otherwise the archived reviewed bytes, recorded as projected.

    A projected input's current bytes are not admitted here. The joint pack
    refuses unless tools/underground_current_census.py recounts that module.
    """
    if digest(live) == expected:
        return live
    row = projection.get(relative)
    require(row is not None and row["sha256"] == expected, "reviewed witness changed: " + relative)
    projected.add(relative)
    return (ROOT / row["locator"]).read_bytes()


def verified_inputs(index, projected=None):
    """Verify the complete producer/baseline closure before any code executes."""
    data = (ROOT / MANIFEST).read_bytes()
    require(digest(data) == MANIFEST_SHA, "immutable manifest changed")
    manifest = json.loads(data)
    projection = projection_rows()
    projected = set() if projected is None else projected
    blobs = {}
    for relative, expected in manifest["witnesses"].items():
        raw = reviewed_bytes(relative, expected, (ROOT / relative).read_bytes(), projection, projected)
        require(digest(raw) == expected, "reviewed witness changed: " + relative)
        blobs[relative] = raw
    for group in ("baseline", "publisher_predecessors", "route_predecessors"):
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
        live = module.text.encode()
        if digest(live) != row["sha256"]:
            require(row["path"] in projection, "current reviewed source changed: " + name)
            live = reviewed_bytes(row["path"], row["sha256"], live, projection, projected)
        require(digest(live) == row["sha256"], "current reviewed source changed: " + name)
        current[name] = audit.parse_module(name, module.relative_path, live.decode())
    return manifest, blobs, {name: current[name] for name in manifest["sources"]}


def producer(relative, blobs, imports=None, view=None):
    """Execute only a previously verified producer, preserving assertions under -O."""
    require(str(relative) in blobs, "unverified producer: " + str(relative))
    namespace = {"__file__": str(ROOT / relative), "__name__": "_reviewed_room_census"}
    if imports or view is not None:
        imports = dict(imports or {})
        if view is not None:
            imports.update(view.imports())
        original = builtins.__import__

        def import_module(name, globals=None, locals=None, fromlist=(), level=0):
            if name in imports and level == 0:
                replacement = imports[name]
                return replacement if fromlist or "." not in name else imports[name.split(".")[0]]
            return original(name, globals, locals, fromlist, level)

        namespace["__builtins__"] = dict(vars(builtins), __import__=import_module)
    exec(compile(blobs[str(relative)], namespace["__file__"], "exec", optimize=0), namespace)
    return namespace


def normalized(result):
    return json.loads(json.dumps(result))


class FrozenInputs:
    """Read only the captured files used by these exact reviewed producers.

    Nested imports also execute the captured bytes with optimize=0. This is a
    census input facade, not a runtime filesystem or a general import loader.
    No disk reads, Git commands or source writes occur during replay.
    """

    def __init__(self, blobs, modules):
        self.blobs = blobs
        self.files = dict(blobs)
        self.files.update({module.relative_path: module.text.encode() for module in modules.values()})

    def path(self, value):
        return FrozenPath(self, Path(str(value)))

    def imports(self):
        view = self

        class Loader:
            def __init__(self, name, path):
                self.name, self.path = name, path

            def exec_module(self, module):
                relative = Path(str(self.path)).relative_to(ROOT)
                module.__dict__.update(producer(relative, view.blobs, view=view))

        def spec_from_file_location(name, path):
            return SimpleNamespace(name=name, loader=Loader(name, path))

        util = SimpleNamespace(spec_from_file_location=spec_from_file_location,
            spec_from_loader=lambda name, loader: SimpleNamespace(name=name, loader=loader),
            module_from_spec=lambda spec: ModuleType(spec.name))
        machinery = SimpleNamespace(SourceFileLoader=Loader)
        package = SimpleNamespace(util=util, machinery=machinery)
        return {"pathlib": SimpleNamespace(Path=self.path), "importlib": package,
                "importlib.util": util, "importlib.machinery": machinery}


class FrozenPath:
    """Only path operations actually used by the immutable census closure."""

    def __init__(self, view, path):
        self.view, self.path = view, path

    def __str__(self):
        return str(self.path)

    def __truediv__(self, part):
        return FrozenPath(self.view, self.path / str(part))

    def __eq__(self, other):
        return str(self) == str(other)

    def __hash__(self):
        return hash(str(self))

    @property
    def parent(self):
        return FrozenPath(self.view, self.path.parent)

    @property
    def parents(self):
        return tuple(FrozenPath(self.view, p) for p in self.path.parents)

    @property
    def stem(self):
        return self.path.stem

    def resolve(self):
        return self

    def relative_to(self, other):
        return self.path.relative_to(str(other))

    def exists(self):
        return str(self.path.relative_to(ROOT)) in self.view.files

    def glob(self, pattern):
        require(self.path == ROOT / "godot/scripts/core" and pattern == "*.gd", "unreviewed census directory scan")
        return [self.view.path(ROOT / name) for name in sorted(self.view.files)
                if Path(name).parent == Path("godot/scripts/core") and name.endswith(".gd")]

    def read_bytes(self):
        key = str(self.path.relative_to(ROOT))
        require(key in self.view.files, "uncaptured census input: " + key)
        return self.view.files[key]

    def read_text(self):
        return self.read_bytes().decode()


def projected(current, rows, blobs, versions=None):
    """Select named, already verified historical bytes; never alter live source."""
    result = dict(current)
    for name, row in rows.items():
        module = result[name]
        if digest(module.text.encode()) == row["sha256"]:
            continue
        original = row if "locator" in row else versions[row["sha256"]]
        require(original.get("path", module.relative_path) == module.relative_path,
                "historical module identity: " + name)
        raw = blobs[original["locator"]]
        require(digest(raw) == row["sha256"], "historical module bytes: " + name)
        result[name] = audit.parse_module(name, module.relative_path, raw.decode())
    return result


def original_rows(path, expected, manifest, blobs):
    """Verify a historical manifest against its exact archived source versions.

    Current constructor reads stay in the separate current input view. This
    function neither substitutes current code nor skips the predecessor proof.
    """
    key = str(Path(str(path)).relative_to(ROOT))
    raw = blobs[key]
    require(digest(raw) == expected, "historical constructor manifest changed")
    rows = json.loads(raw)
    for name, row in rows.items():
        locator = row.get("locator", name) if isinstance(row, dict) else name
        wanted = row["sha256"] if isinstance(row, dict) else row
        data = blobs.get(locator)
        if data is None or digest(data) != wanted:
            version = manifest["historical_versions"][wanted]
            require(version["path"] == name, "historical constructor source identity")
            data = blobs[version["locator"]]
        require(digest(data) == wanted, "historical constructor input changed: " + name)
    return rows


def same_accounting(actual, expected, label):
    actual, expected = dict(normalized(actual)), dict(expected)
    actual.pop("source_sha256", None)
    expected.pop("source_sha256", None)
    require(actual == expected, label + " reviewed allocation/lifetime result changed")


def ui_notice_alias(current, manifest, blobs):
    """Prove the sole current UI alias before replaying its original source.

    Both full current sources and the archived original were captured and
    hashed above. This equality admits no body, initializer or preload change.
    The existing UiNotices preload must resolve the exact former literal.
    """
    row = manifest["ui_alias"]
    module = current["ui_manager"]
    original = blobs[row["original"]["locator"]]
    actual = module.text.encode()
    dependency = current["ui_notices"].text
    old = b'const CLOCK_OVERLOAD_CODE: String = "CLOCK_OVERLOADED"\n'
    new = b'const CLOCK_OVERLOAD_CODE: String = UiNotices.CLOCK_OVERLOAD_CODE\n'
    require(original.count(old) == actual.count(new) == 1,
            "one exact UI notice alias")
    require(actual.replace(new, old, 1) == original,
            "UI notice alias changed another source byte")
    require(module.text.count('const UiNotices := preload("res://scripts/ui/ui_notices.gd")\n') == 1,
            "UI notice alias original dependency")
    require(re.findall(r"^const CLOCK_OVERLOAD_CODE\b[^\n]*", dependency, re.M) == [old.decode().rstrip("\n")],
            "UI notice alias literal changed")
    return {"source_sha256": {module.relative_path: digest(actual),
                              row["dependency"]["path"]: digest(dependency.encode())},
            "historical_ui_manager_sha256": digest(original),
            "reconstruction": "one exact constant alias; all other bytes identical",
            "additional_reserved_bytes": 0}


def entry_air_contact_memory(current, manifest, blobs, view):
    """Recount the exact current physical-plan predicate before selecting any historical source.

    All complete volume rows and existing retained storage remain byte-exact.
    The new scalar helper affects only additional positive air-contact rows;
    real physical acceptance is independently recorded, not inferred here.
    """
    row = manifest["entry_air_contact"]
    original = blobs[row["previous_locator"]].decode()
    source = current["underground_entry_world_bindings"].text
    helper = ('func _entry_has_air_contact(actual: PhaseContacts, role: int) -> bool:\n'
              '\t"""Contacts already proves complete stance residuals; only above-plane primitives additionally describe air approach."""\n'
              '\treturn _entry_is_approach(role) and _entry_box[4] > actual._location.point.y\n\n\n')
    require(source.count(helper) == 1 and source.count("_entry_has_air_contact(actual, role)") == 1
            and source.count("_entry_has_air_contact(actual, actual._box.role)") == 2,
            "entry air-contact exact predicate and three uses")
    reconstructed = source.replace(helper, "", 1).replace("_entry_has_air_contact(actual, role)",
        "_entry_is_approach(role)").replace("_entry_has_air_contact(actual, actual._box.role)",
        "_entry_is_approach(actual._box.role)")
    require(reconstructed == original, "entry air-contact changed another source byte")
    census = producer(Path(row["census"]), blobs, view=view)
    retained, native = census["packet"](source)
    old_retained, old_native = census["packet"](original)
    frames, previous = census["frames"](source), census["frames"](original)
    receipt = json.loads(blobs[row["receipt"]])
    require(retained == old_retained and native == old_native and sum(retained.values()) == 202
            and frames["bytes"] == previous["bytes"] == receipt["own_numeric_chain"]["bytes"] == 224
            and receipt["source_sha256"] == digest(source.encode())
            and receipt["own_helper_reserve_bytes"] == 1024
            and receipt["fixed_plus_helper_bytes"] == 1226, "entry air-contact existing reservation")
    return {"source_sha256": digest(source.encode()), "previous_source_sha256": digest(original.encode()),
            "fixed_bytes": sum(retained.values()), "own_numeric_frames": frames,
            "existing_helper_reservation": 1024, "existing_total_reservation": 2048,
            "additional_reserved_bytes": 0, "native_measured": False}


def publication(current, manifest, blobs, view):
    census = producer(P / "census.py", blobs, view=view)

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


def itinerary(current, blobs, view):
    census = producer(I / "census.py", blobs, view=view)
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


def composition(current, historical, blobs, view):
    constructor = producer(C / "constructor_census.py", blobs, view=view)
    census = producer(C / "census.py", blobs, {"constructor_census": SimpleNamespace(**constructor)}, view=view)
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


def route_composition(current, blobs, view):
    """Recount the actual route constructor and its complete original owner reset."""
    census = producer(R / "census.py", blobs, view=view)
    result = census["build"]({role: current[Path(path).stem].text
                              for role, path in census["FILES"].items()})
    same_accounting(result, json.loads(blobs[str(R / "source-review-1/census.json")]),
                    "route composition")
    return result


def source_extensions(current, manifest, blobs, view):
    """Current runtime and source identities close before any old projection."""
    step = producer(S / "census.py", blobs, view=view)
    runtime = step["build"]({name: module.text for name, module in current.items()})
    same_accounting(runtime, json.loads(blobs[str(S / "census.json")]), "current short-step runtime")
    paths = producer(T / "census.py", blobs, view=view)
    # Reuse the already recounted current step result. Its verified parser and
    # complete current source view remain the actual itinerary dependencies.
    paths["dependency"] = lambda: SimpleNamespace(**(step | {"build": lambda: runtime}))
    itinerary_result = paths["build"]()
    same_accounting(itinerary_result, json.loads(blobs[str(T / "census.json")]), "current itinerary")
    metadata = producer(Q / "census.py", blobs, view=view)["build"]()
    same_accounting(metadata, json.loads(blobs[str(Q / "census.json")]), "current publication metadata")
    require(metadata["retained_owner_fields_delta"] == metadata["runtime_bank_count_delta"] == 0,
            "metadata publication added storage")
    return runtime, itinerary_result, metadata


def surface_composition(current, manifest, blobs, view, previous_routes):
    """Recount actual current constructors; verify original manifests separately.

    The 1171 predecessor has already reproduced byte-for-byte in its original
    view. Its current constructor parser reads the actual current owners here,
    including 1168, after the exact 1173 metadata equivalence proof.
    """
    base = producer(R / "census.py", blobs, view=view)
    base["verified_rows"] = lambda path, expected: original_rows(path, expected, manifest, blobs)
    census = producer(A / "census.py", blobs, view=view)
    census["verified"] = lambda path, expected: original_rows(path, expected, manifest, blobs)
    rows = original_rows(ROOT / A / "predecessor/manifest.json", census["PREDECESSOR_SHA"], manifest, blobs)
    old = {key: blobs[rows[path]["locator"]].decode() for key, path in census["FILES"].items()
           if path in rows and "locator" in rows[path]}
    census["predecessor"] = lambda: (SimpleNamespace(**base), old, previous_routes)
    result = census["build"]()
    same_accounting(result, json.loads(blobs[str(A / "source-review-3/census.json")]),
                    "current SurfaceAnchor constructor/reset")
    return result


def build(index):
    """Return current recounts and explicitly separate unchanged older slices."""
    archived = set()
    manifest, blobs, current = verified_inputs(index, archived)
    alias = ui_notice_alias(current, manifest, blobs)
    view = FrozenInputs(blobs, current)
    entry = entry_air_contact_memory(current, manifest, blobs, view)
    runtime, paths, metadata = source_extensions(current, manifest, blobs, view)
    # Only after all current changed-call/source proofs, select the exact old
    # source versions needed by immutable predecessor constructors and1156.
    previous = projected(current, manifest["previous_current"], blobs, manifest["historical_versions"])
    metadata_rows = json.loads(blobs[str(Q / "baseline.json")])["sources"]
    previous = projected(previous, {Path(path).stem: row for path, row in metadata_rows.items()}, blobs)
    old_view = FrozenInputs(blobs, previous)
    historical = projected(previous, manifest["baseline"], blobs)
    routes = route_composition(previous, blobs, old_view)
    surface = surface_composition(current, manifest, blobs, view, routes)
    room_inputs = projected(previous, manifest["route_predecessors"], blobs)
    published = publication(current, manifest, blobs, view)
    old_paths = itinerary(previous, blobs, old_view)
    owners, closure = composition(room_inputs, historical, blobs, old_view)
    ground = ground_catalog(current, historical, blobs)
    require(published["new_global_reservation"] == 0 and owners["additional_packed_bytes"] == 0
            and surface["additional_packed_bytes"] == 0 and surface["retained_reference_delta"] == 2
            and surface["retained_numeric_delta"] == 0, "new room reservation is not admitted")
    result = {
        "scope": __doc__, "manifest_sha256": MANIFEST_SHA,
        "current_ui_alias": alias,
        "current_entry_air_contact": entry,
        "current_source_sha256": {row["path"]: row["sha256"] for row in manifest["sources"].values()},
        "historical_projection": manifest["baseline"],
        "historical_current_projection": manifest["previous_current"],
        "publication": published, "itinerary": paths, "composition": owners,
        "current_source_runtime": runtime, "current_publication_metadata": metadata,
        "historical_itinerary": old_paths, "historical_route_composition": routes,
        "route_composition": surface,
        "room_composition_projection": manifest["route_predecessors"], "ground_catalog": ground,
        "unchanged_locations_constructor_closure": closure,
        "additional_global_reserved_bytes": 0, "runtime_qualified": False, "native_measured": False,
        "projected_reviewed_inputs": sorted(archived),
    }
    legacy = E / "predecessors/underground_motion_memory.py.txt"
    result["historical_motion"] = producer(legacy, blobs)["build"](historical)
    return result, historical


def reconcile(result, index, session, retirement, ui_reset, motion):
    """Replace historical lifecycle figures with the reviewed current coexistence."""
    current = result["route_composition"]
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
    session["current_composition_frames"] = current["phases"]["route_own_prefix_and_result_tail"]["frames"]
    session["historical_room_composition_frames"] = result["composition"]["phases"]["composition_own_prefix"]["frames"]
    for report in (retirement, ui_reset):
        report["historical_accounting"] = dict(report["accounting"])
        report["historical_frames"] = report.pop("frames")
        report["historical_source_sha256"] = report.pop("source_sha256")
        report["source_sha256"] = {path: digest(index[Path(path).stem].text.encode())
                                   for path in report["historical_source_sha256"]}
        report["current_composition_source_sha256"] = current["source_sha256"]
        report["current_constructor_exclusive_reuse"] = current["constructor_exclusive_reuse"]
    direct = current["phases"]["direct_reset"]["provisional_bytes"]
    controls = accounting["controls"]
    require(controls == 6131 and current["constructor_exclusive_reuse"]["simultaneous_total"] == 8185,
            "current lifecycle coexistence differs")
    retirement["accounting"].update(control_provisional_bytes=controls,
        control_remaining=6144 - controls,
        direct_reset_helper_bytes=direct,
        helper_provisional_bytes=accounting["helpers"], helper_remaining=2048 - accounting["helpers"])
    retirement["current_frames"] = current["phases"]["direct_reset"]["frames"]
    ui_reset["accounting"].update(controls=accounting["controls"], helpers=accounting["helpers"])
    ui_reset["current_frames"] = current["phases"]["reset_with_ui"]["frames"]

    # Old constructors and caller frames were checked with their original
    # configuration above. Replace only derived dimensions after exact1173
    # source equivalence and current1168/1172 arithmetic have closed.
    reviewed = result["current_publication_metadata"]["joint"]
    require(reviewed == result["current_source_runtime"]["joint"]["total"] == 248632 == 238904 + 1536 + 8192,
            "reviewed complete joint disagrees")
    # ADR1212: the reviewed Session (1,536) and retirement (8,192) terms are unchanged; the Motion/Profile/Level
    # term is the current source count (content 6), so the joint follows the published profile configuration.
    joint = motion["joint"]["total"] + 1536 + 8192
    require(joint <= 262144, "current complete joint exceeds PROFILE_BYTES")
    terms = {"paired_profiles": motion["joint"]["profiles"] - 32768, "profile_controls": 32768,
             "levels": motion["joint"]["levels"]}
    result["current_publication_metadata"]["historical_joint"] = reviewed
    session["historical_profile_accounting"] = {
        key: session[key] for key in ("existing_profile_paired_plus_control_bytes",
            "foundation_profile_level_session_bytes", "source_counted_motion_joint_before_session_bytes",
            "profile_level_motion_session_joint_bytes", "joint_remaining_bytes")}
    session.update(existing_profile_paired_plus_control_bytes=terms["paired_profiles"] + terms["profile_controls"],
        foundation_profile_level_session_bytes=terms["paired_profiles"] + terms["profile_controls"] + terms["levels"] + 1536,
        source_counted_motion_joint_before_session_bytes=motion["joint"]["total"],
        profile_level_motion_session_joint_bytes=motion["joint"]["total"] + 1536,
        joint_remaining_bytes=262144 - motion["joint"]["total"] - 1536)
    retirement["accounting"].update(parent_1156_joint_bytes=session["profile_level_motion_session_joint_bytes"],
        joint_with_retirement=joint, joint_remaining_bytes=262144-joint)
    # Preserve the old report's label exactly in historical_accounting only.
    retirement["accounting"]["current_source_joint_bytes"] = retirement["accounting"].pop("parent_1156_joint_bytes")
    ui_reset["accounting"].update(profile_joint_unchanged=joint)
    current["historical_profile_joint_bytes"] = accounting["profile_joint"]
    accounting["profile_joint"] = joint
