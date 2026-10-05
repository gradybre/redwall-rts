"""Serialize ADR1190's fixed accessor after a publisher has qualified its inputs.

This pure formatter validates linked wire metadata. It does not qualify source
geometry, consumers, paid execution or World access, and writes no files.
"""
from __future__ import annotations

import hashlib
import json
import struct

DESTINATION = "res://data/underground/first-entry-prefix-v1/qualified-handling-v1/"
FILES = {
    "CATALOG": "structure.ugconn", "GROUPING": "assemblies.ugasmb",
    "RECIPE": "recipes.ugrecp", "FRONTIER": "frontier.ugfront",
    "WORKPIECES": "workpieces.ugwipc", "GROUND": "ground-pace.ugconn",
}
TABLES = ("INSTALL", "STATION", "CUT", "BEARING", "ENDPOINT", "EPISODE")
ROW_BYTES = (36, 80, 28, 36, 40, 76)


def require(ok, code):
    if not ok:
        raise ValueError("ENTRY_CONSTANTS_" + code)


def words(raw, offset, count=1, kind="q"):
    return struct.unpack_from("<" + kind * count, raw, offset)


def digest(raw):
    return hashlib.sha256(raw).digest()


def _catalog(raw, version):
    require(len(raw) >= 144 and raw[:8] == b"UGCONN01" and raw[-8:] == b"UGCEND01"
            and words(raw, 8, kind="I") == (version,), "CATALOG_FORMAT")
    counts = words(raw, 20, 7, "I")
    limits = (16, 512, 1024, 256, 2048, 16, 256)
    require(all(0 <= n <= limit for n, limit in zip(counts, limits)), "CATALOG_CAPACITY")
    require(all(n > 0 for n in counts) if version == 1 else
            counts[:6] == (0,) * 6 and counts[6] > 0, "CATALOG_TABLES")
    require(len(raw) == 144 + sum(n * width for n, width in
            zip(counts, (112, 16, 32, 36, 12, 4, 36))), "CATALOG_LENGTH")
    require(words(raw, 12) == (1,) and words(raw, 48)[0] > 0, "CATALOG_REVISION")
    return counts


def _linked(packet):
    """Resolve only the fixed names; constants cannot embed caller paths or capacities."""
    require(type(packet) is dict and set(packet) == set(FILES.values()) | {"mole-worker.ugprof"}, "FILES")
    require(all(type(raw) is bytes and 8 <= len(raw) <= 131072 for raw in packet.values()), "BYTES")
    cat, group, recipe, frontier, pieces, ground = (packet[name] for name in FILES.values())
    profile = packet["mole-worker.ugprof"]
    cc, gc = _catalog(cat, 1), _catalog(ground, 2)
    require(cat[48:136] == ground[48:136] and cc[6] == gc[6], "GROUND_SOURCE")
    require(len(profile) >= 40 and profile[:8] == b"UGPROF01" and profile[-8:] == b"UGPEND01"
            and words(profile, 8, kind="I") == (2,), "PROFILE_FORMAT")
    content, profiles, boxes, sources = struct.unpack_from("<qIII", profile, 12)
    require(content == words(cat, 48)[0] and 1 <= profiles <= 256 and 1 <= boxes <= 3072
            and 2 <= sources <= 64 and len(profile) == 40 + sources * 32 + profiles * 98 + boxes * 28,
            "PROFILE_CENSUS")
    require(cat[72:104] == profile[32:64], "CATALOG_SOURCE")
    require(len(group) >= 96 and group[:8] == b"UGASMB01" and group[-8:] == b"UGAEND01"
            and words(group, 8, kind="I") == (1,), "GROUP_FORMAT")
    assemblies = words(group, 48, kind="I")[0]
    require(1 <= assemblies <= 256 and len(group) == 96 + 16 * assemblies
            and words(group, 52, kind="I") == (cc[3],), "GROUP_CENSUS")
    require(words(group, 20) == words(cat, 12) and group[56:88] == digest(cat), "GROUP_LINK")
    require(len(recipe) == 124 + assemblies * 80 and recipe[:8] == b"UGRECP01"
            and recipe[-8:] == b"UGREND01" and words(recipe, 8, kind="I") == (1,), "RECIPE_FORMAT")
    require(words(recipe, 12) == words(group, 28) and words(recipe, 28) == words(group, 12)
            and words(recipe, 20) == words(cat, 12) and recipe[36:48] == group[36:48]
            and words(recipe, 48, kind="I") == (assemblies,)
            and recipe[52:116] == digest(cat) + digest(group), "RECIPE_LINK")
    counts = _frontier(frontier, cat, group, recipe, profile, assemblies)
    _pieces(pieces, cat, group, recipe, frontier, profile, assemblies)
    revisions = (words(raw, 12)[0] for raw in (cat, group, recipe, frontier, pieces))
    result = {name + "_REVISION": revision for name, revision in zip(tuple(FILES)[:5], revisions)}
    require(all(n > 0 for n in result.values()), "REVISION")
    result["CONTENT_REVISION"] = content
    result.update({name + "_COUNT": count for name, count in zip(TABLES, counts)})
    return result


def _frontier(raw, cat, group, recipe, profile, assemblies):
    require(len(raw) >= 228 and raw[:8] == b"UGFRNT01" and raw[-8:] == b"UGFEND01"
            and words(raw, 8, kind="I") == (1,), "FRONTIER_FORMAT")
    counts = words(raw, 68, 6, "I")
    require(counts[0] == assemblies and all(1 <= n <= 2048 for n in counts)
            and 2048 + sum(n * width for n, width in zip(counts, ROW_BYTES)) <= 28597,
            "FRONTIER_CAPACITY")
    require(len(raw) == 228 + sum(n * width for n, width in zip(counts, ROW_BYTES)), "FRONTIER_LENGTH")
    require(words(raw, 20) == words(cat, 12) and words(raw, 28) == words(group, 40)
            and words(raw, 36) == words(group, 12) and words(raw, 44) == words(recipe, 12)
            and words(raw, 52) == words(profile, 12) and raw[60:64] == group[36:40], "FRONTIER_REVISIONS")
    source = words(raw, 64, kind="i")[0]
    require(0 <= source < words(profile, 28, kind="I")[0]
            and raw[92:188] == digest(cat) + digest(group) + digest(recipe)
            and raw[188:220] == profile[32 + 32 * source:64 + 32 * source], "FRONTIER_LINK")
    return counts


def _pieces(raw, cat, group, recipe, frontier, profile, assemblies):
    require(len(raw) == 220 + 32 * assemblies and raw[:8] == b"UGWIPC01"
            and raw[-8:] == b"UGWEND01" and words(raw, 8, kind="I") == (1,), "WORKPIECES_FORMAT")
    revision, catalog, variant, grouping, bill, content, count, row, source = words(raw, 12, 9)
    require(revision > 0 and catalog == words(cat, 12)[0] and variant == words(group, 40)[0]
            and grouping == words(group, 12)[0] and bill == words(recipe, 12)[0]
            and content == words(profile, 12)[0] and count == assemblies
            and row == words(group, 36, kind="i")[0], "WORKPIECES_REVISIONS")
    require(0 <= source < words(profile, 28, kind="I")[0]
            and raw[84:180] == digest(cat) + digest(group) + digest(recipe)
            and raw[180:212] == profile[32 + 32 * source:64 + 32 * source], "WORKPIECES_LINK")
    require(raw[180:212] != frontier[188:220], "WORKPIECES_NOT_DISTINCT")


def generate(packet):
    """Emit constant data only; independent source/reader/native qualification belongs to the publisher."""
    values = _linked(packet)
    lines = ["extends RefCounted", "## Generated fixed first-entry source metadata; ADR1190.", ""]
    for name, filename in FILES.items():
        lines.append("const " + name + "_PATH: String = " + json.dumps(DESTINATION + filename))
        lines.append("const " + name + "_SHA: String = " + json.dumps(digest(packet[filename]).hex()))
    lines.extend("const " + name + ": int = " + str(value) for name, value in values.items())
    for name in ("CATALOG", "GROUND"):
        for index, value in enumerate(struct.unpack("<4q", digest(packet[FILES[name]]))):
            lines.append("const " + name + "_DIGEST_" + str(index) + ": int = " + str(value))
    return ("\n".join(lines) + "\n").encode()
