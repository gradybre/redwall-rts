#!/usr/bin/env python3
"""Validate the design package, not runtime UI behavior. Standard library only."""
import csv
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'docs/design/ui_refinement'

def luminance(value):
    rgb=[int(value[i:i+2],16)/255 for i in (1,3,5)]
    lin=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in rgb]
    return sum(a*b for a,b in zip(lin,(0.2126,0.7152,0.0722)))

def main():
    c=json.loads((D/'contract.json').read_text())
    amendment=(ROOT/'docs/ui_visual_refinement_amendment.md').read_text()
    rows=list(csv.DictReader((D/'requirements.csv').open()))
    ids=[r['id'] for r in rows]
    assert ids==c['requirements']==[f'UXV-{i:03}' for i in range(1,43)]
    assert re.findall(r'^\| (UXV-\d{3}) \|',amendment,re.M)==ids
    acceptance=(D/'acceptance.md').read_text()
    assert re.findall(r'^\| (A\d{2}) \|',acceptance,re.M)==c['acceptance_ids']
    for row in rows:
        assert row['acceptance'] in c['acceptance_ids'] and row['requirement'] in amendment
    base=(ROOT/'docs/ui_ux_controls.md').read_text()
    contrasts=[]
    for key,value in c['tokens'].items():
        source=amendment if key.startswith('PAPER') or key=='SURFACE_EDGE' else base
        assert re.search(r'\|\s*'+re.escape(key)+r'\s*\|\s*'+re.escape(value),source),(key,value)
    for fg,bg,minimum in c['contrast_pairs']:
        lo,hi=sorted([luminance(c['tokens'][fg]),luminance(c['tokens'][bg])])
        ratio=(hi+.05)/(lo+.05)
        assert ratio>=minimum,(fg,bg,ratio,minimum)
        contrasts.append({'foreground':fg,'background':bg,'ratio':round(ratio,4),'minimum':minimum})
    layouts=[]
    for width,height,user,expected in c['layout_fixtures']:
        s=max(1,min(2,min(width/1920,height/1080)))*user
        lw,lh=width/s,height/s
        profile='WIDE' if lw>=1600 else 'STANDARD' if lw>=1120 else 'NARROW'
        assert profile==expected,(lw,profile,expected)
        mw,dw=(256,384) if profile=='WIDE' else (208,336) if profile=='STANDARD' else (160,320)
        available=lw-dw-32-(mw+32)
        assert available>=240
        dh=min(640,lh-144);assert dh>=240
        cols=3 if profile=='NARROW' or min(640,available)<640 else 6
        bh=44 if cols==3 else 52;count=6;nr=(count+cols-1)//cols
        ch=24+nr*bh+(nr-1)*8
        assert ch<=136
        layouts.append(dict(physical=[width,height],user_scale=user,S=s,logical=[lw,lh],profile=profile,command_available=available,command_height=ch,detail_height=dh))
    font_manifest=json.loads((D/'assets_manifest.json').read_text())
    for a in font_manifest['fonts']:
        p=D/a['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']
        assert (D/a['license_file']).exists()
    images=[]
    for fn,w,h in c['reference_images']:
        data=(D/'visuals'/fn).read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n'
        actual=struct.unpack('>II',data[16:24]);assert actual==(w,h),(fn,actual)
        images.append(dict(file=fn,dimensions=actual,sha256=hashlib.sha256(data).hexdigest()))
    paths=[ROOT/'docs/ui_visual_refinement_amendment.md',ROOT/'docs/tasks/04_5_ui_visual_refinement.md',D/'README.md',D/'acceptance.md',D/'ASSETS.md']
    links=0
    for p in paths:
        for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
            if '://' in target or target.startswith('#'):continue
            target=target.split('#')[0]
            assert (p.parent/target).exists(),(p,target)
            links+=1
    print(json.dumps({'status':'PASS','requirements':len(rows),'acceptance_cases':len(c['acceptance_ids']),'contrast_pairs':contrasts,'layout_fixtures':layouts,'fonts':len(font_manifest['fonts']),'reference_images':images,'checked_links':links,'runtime_UI':'NOT_RUN','user_visual_approval':'PENDING'},indent=2))

if __name__=='__main__':main()
