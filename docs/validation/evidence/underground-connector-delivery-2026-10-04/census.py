#!/usr/bin/env python3
"""1140 source-derived declared numeric/packed census; not native allocation or tick qualification."""
import hashlib, importlib.util, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location("census1134", ROOT/"docs/validation/evidence/underground-connector-workpieces-2026-10-04/census.py")
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
D="underground_connector_delivery"
s=c.source(D); declarations=c.members(s); numbers=c.numeric_members(D)
packed={name: 4*int(re.search(r"^\t"+re.escape(name)+r"\.resize\((\d+)\)$",s,re.M)[1]) for name,kind in declarations.items() if kind=="PackedInt32Array"}
packets={"order":c.record("underground_connector_placements","OrderRecord"),"selection":c.record("underground_profiles","Selection"),"location":c.record("underground_locations","Record",{"envelope":24,"support":24}),"box":c.record("underground_profiles","Box"),"number":c.record("int_math","IntResult")}
fixed=sum(numbers.values())+sum(packed.values())+sum(packets.values())
chain=c.chain(D)
# The 1141 callback lower frame115 is already inside its own512 helper reservation.
# Complete existing source/physical helpers are conservatively bounded by512 (1135/1133).
# Work's handling numeric stack is counted below; existing party storage is already allocated.
wf=c.functions("work")
work_frames=["_tick_spatial_handling_into","_prepare_handling_numbers","_handling_numbers_leaf","_publish_handling_tick","_capture_handling_inputs","_handling_contributor_leaf","tick_solo","tick_solo_into"]
work_prefix=sum(wf[n]["bytes"] for n in ["tick_solo","tick_solo_into","_tick_spatial_handling_into"])
work_max=work_prefix+max(wf["_prepare_handling_numbers"]["bytes"]+wf["_capture_handling_inputs"]["bytes"], wf["_handling_numbers_leaf"]["bytes"]+wf["_handling_contributor_leaf"]["bytes"], wf["_publish_handling_tick"]["bytes"])
helper=chain["bytes"]+work_max+512
assert helper<=1024,(helper,chain)
assert fixed+1+1024+2048<=4096
print(json.dumps({"scope":"Declared logical numeric/packed fields only; references, objects, expressions/interpreter/native frames remain unmeasured.","members":declarations,"numeric":numbers,"packed":packed,"packets":packets,"fixed":fixed,"work_new_numeric":1,"work_new_references":["_delivery_script","_spatial_delivery"],"own_chain":chain,"work_frames":{n:wf[n]["bytes"] for n in work_frames},"coupled_helper_bound":helper,"helper_reservation":1024,"native_provisional":2048,"total_admitted":4096,"payload_and_reservations":fixed+1+1024+2048,"lower_transfer_packet_counted_in1141":216,"lower_frame_counted_in1141":115,"sha256":{n:hashlib.sha256(c.source(n).encode()).hexdigest() for n in [D,"work","haul_planner"]},"runtime_qualified":False},indent=2))
