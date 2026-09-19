"""Recreate the independent SAVE-REPLAY-R01 fixture from literal contract fields."""
import hashlib
import json
import struct

header = bytearray(264)
header[:8] = b'RWLSET01'
struct.pack_into('<IIIIQq', header, 8, 2, 264, 16909060, 15, 1224, 7)
for offset, value in [(40, 0x11), (72, 0x22), (104, 0x33),
                      (136, 0x44), (168, 0x55), (232, 0x66)]:
    header[offset:offset + 32] = bytes([value]) * 32
struct.pack_into('<QQIIQ', header, 200, 264, 3, 0x89abcdef, 0, 0x80000000)
assert len(header) == 264
print(json.dumps({'bytes': len(header), 'sha256': hashlib.sha256(header).hexdigest(),
                  'hex': header.hex()}, indent=2))
