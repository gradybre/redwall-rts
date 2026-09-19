"""Independent Python struct oracle for the unchanged wrapper and six appended fields."""
import json
import struct
from pathlib import Path
extents = [4096, 1, 128, 1, 1024, 1]
values = [7, 1, 19, 1, 91, 1]
cursor = 363151
rows = []
for ordinal, (extent, first) in enumerate(zip(extents, values), start=29):
    rows.append({'ordinal': ordinal, 'count_offset': cursor, 'value_offset': cursor+8,
                 'extent': extent, 'first_twelve_bytes': struct.pack('<Qi',extent,first).hex()})
    cursor += 8 + extent*4
assert cursor == 384203
assert 383884 + 35*8 == 384164
wrapper = struct.pack('<II',1,11)+b'job_planner'+struct.pack('<IQQ',2,8192,384164)
assert len(wrapper) == 39
print(json.dumps({'wrapper_hex':wrapper.hex(), 'fields':rows, 'section_bytes':cursor},indent=2))
