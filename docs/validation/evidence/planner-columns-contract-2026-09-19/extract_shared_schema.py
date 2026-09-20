from pathlib import Path
import re

root = Path(__file__).resolve().parents[4]
codec_path = root / 'godot/scripts/core/save_section_job_indexes.gd'
owner_path = root / 'godot/scripts/core/job_planner.gd'
codec = codec_path.read_text()
owner = owner_path.read_text()
names = set(re.findall(r'JobPlannerScript\.([A-Z][A-Z0-9_]+)', codec)) | {'STATUS_UNMET'}
assert len(names) == 22
moved = []
for line in owner.splitlines():
    match = re.fullmatch(r'const ([A-Z0-9_]+): int = (.+)', line)
    if match and match[1] in names:
        moved.append(line)
        owner = owner.replace(line, f'const {match[1]}: int = JobIndexSchema.{match[1]}')
assert len(moved) == 22
start = codec.index('# --- ARCH-SAVE-002 identity')
record_end = codec.index('class EncodeResult:')
validation_start = codec.index('# --- validation ')
shared = codec[start:record_end] + codec[validation_start:]
for name in names:
    shared = re.sub(rf'^const {name}: int = JobPlannerScript\.{name}\n', '', shared, flags=re.M)
shared = re.sub(r'JobPlannerScript\.([A-Z][A-Z0-9_]+)', r'\1', shared)
header = '''extends RefCounted
## SAVE-J2-R02: shared schema2 layout, typed Record and pure structural validation.
## No planner/codec preload: both consume this schema without a cycle.
## Cold record payload383884B and dirty-validation scratch4096B; no live owner state.
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")

'''
shared = header + '\n'.join(moved) + '\n\n' + shared
needle = '\tfor field: int in FIELD_COUNT:\n\t\tif record.column_size(field) != FIELD_EXTENTS[field]:'
assert shared.count(needle) == 1
shared = shared.replace(needle, '''\tif record == null:
\t\treturn SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE, "no planner record")
\tif record.u8_columns.size() != 8 or record.i32_columns.size() != 25 \\
\t\t\tor record.i64_columns.size() != 2:
\t\treturn SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE, "planner groups require8/25/2 columns")
\tfor field: int in FIELD_COUNT:
\t\tif record.column_size(field) != FIELD_EXTENTS[field]:''')
shared += '''\n\nstatic func shape_refusal(record: Record) -> SaveHeader.Refusal:
\t"""Validate a caller output's groups/extents without inspecting prior values."""
\treturn _shape_refusal(record)
'''
new_codec = '''extends "res://scripts/core/job_index_schema.gd"
## Schema2 section8 byte codec. Shared layout/Record/validation remain public by inheritance.
## SAVE-J2-R02 owner adapters are integrated separately; whole-world save remains incomplete.
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

''' + codec[record_end:validation_start]
owner = owner.replace('const IntMath :=', 'const JobIndexSchema := preload("res://scripts/core/job_index_schema.gd")\nconst IntMath :=', 1)
(root / 'godot/scripts/core/job_index_schema.gd').write_text(shared)
owner_path.write_text(owner)
codec_path.write_text(new_codec)
print('Extracted shared Record/layout/validation;22 owner aliases; strengthened shape gate')
