"""Independent planning arithmetic. No runtime-family acceptance is implied."""
import json

D = 750000

def step(value, remainder, served):
    accumulator = remainder + (2750000 if served else -250000)
    whole = (abs(accumulator) // D) * (1 if accumulator >= 0 else -1)
    return value + whole, accumulator - whole * D

value, remainder = 6000, 0
for _ in range(750):
    value, remainder = step(value, remainder, True)
assert (value, remainder) == (8750, 0)
first_turn = [value, remainder]
for _ in range(30):
    value, remainder = step(value, remainder, False)
assert (value, remainder) == (8740, 0)
second_ticks = 0
while value < 9000:
    value, remainder = step(value, remainder, True)
    second_ticks += 1
assert (second_ticks, value, remainder) == (71, 9000, 250000)
# Decay applies throughout the day. Gross care replaces what all 24 hours consumed.
assert -250000 * 18000 + 3000000 * 1500 == 0
# A feasible, unclamped two-turn day returns exactly to its initial care.
v, rem = 6500, 0
for tick in range(18000):
    served = 1500 <= tick < 2250 or 10500 <= tick < 11250
    v, rem = step(v, rem, served)
    assert 0 < v < 10000
assert (v, rem) == (6500, 0)
rows = []
for stage, multiplier in [('ADULT',1000),('CHILD',750),('ELDER',1000)]:
    for season, seasonal in [('other',1000),('winter',1200)]:
        rates = [250000*size*seasonal*multiplier//10**9 for size in (1000,1200,1600)]
        demand = [6000*size*seasonal*multiplier//10**9 for size in (1000,1200,1600)]
        assert all(rate*24//1000 == np for rate,np in zip(rates,demand))
        rows.append(dict(stage=stage,season=season,hunger_milli_per_hour=rates,np_per_day=demand))
assert rows[2]['np_per_day'] == [4500,5400,7200]
assert rows[3]['np_per_day'] == [5400,6480,8640]
assert max(max(x['hunger_milli_per_hour']) for x in rows) == 480000
assert 256+3*4*256+2*4*2048+8 == 19720
assert 4*512+4*512+2*4*512+2*4*512+4*512+8*512+2*4*512+4*512+4*512+8 == 26632
assert 19720+26632 == 46352
assert 46352+5632+46352 == 98336
print(json.dumps(dict(status='PASS',scope='planning arithmetic only',first_turn=first_turn,second_turn_ticks=second_ticks,completion=[value,remainder],daily_maintenance_service_ticks=1500,rows=rows,owner_payload_bytes=46352,owner_local_live_scratch_snapshot_bytes=98336),indent=2))
