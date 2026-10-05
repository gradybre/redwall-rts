#!/usr/bin/env python3
"""Read-only corrected analyzer probes; framed replies, no engine or socket."""
import hashlib
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch
A=Path('/Users/brendan/Developer/redwall-rts-codex-ug-analyzer-lifetime')
O=Path(__file__).resolve().parent
import types
a=types.ModuleType('analyzer');a.__file__=str(O/'gdscript_warnings.py.txt')
exec(compile(Path(a.__file__).read_bytes(),a.__file__,'exec'),a.__dict__)
p=O/'fixture';p.mkdir(exist_ok=True)
files=[p/'dependency.gd.txt',p/'consumer.gd.txt']
for f in files:f.write_text('extends RefCounted\n')
warning={'range':{'start':{'line':0,'character':0},'end':{'line':0,'character':1}},'severity':2,'message':'late dependency warning'}
def frame(uri,d):
 b=json.dumps({'method':'textDocument/publishDiagnostics','params':{'uri':uri,'diagnostics':d}}).encode()
 return b'Content-Length: %d\r\n\r\n'%len(b)+b
class Client(a.Lsp):
 def __init__(self,mode):
  self.mode=mode;self.buf=b'';self.diagnostics={};self.findings={};self.opened=0;self.sock=self;self.closed=False
 def close(self):self.closed=True
 def send(self,m):pass
 def pump(self,until,uri=None):
  if uri is None:
   if self.opened and self.mode in ('queued','retry_late'):
    self.buf+=frame(files[0].as_uri(),[warning]);self._drain(None)
   return False
  self.opened+=1
  if self.opened==2:
   if self.mode in ('clear','crash'):
    self.buf+=frame(files[0].as_uri(),[warning])+frame(files[0].as_uri(),[])
   if self.mode in ('crash','clean_crash'):
    self._drain(uri);raise a.EditorCrashed('controlled EOF')
  self.buf+=frame(uri,[]);return self._drain(uri)

def run(client, selected, found, done):
 with patch.object(a,'Lsp',return_value=client):a.collect(selected,p,p,1,found,done)
results={}
for mode in ('clear','queued'):
 found={};done=[];run(Client(mode),files,found,done)
 results[mode]={'found':found,'done':len(done)}
 assert len(found['dependency.gd.txt'])==1 and done==files
found={};done=[]
try:run(Client('crash'),files,found,done)
except a.EditorCrashed:pass
run(Client('clean'),files[len(done):],found,done)
results['crash_retry']={'found':found,'done':len(done)}
assert len(found['dependency.gd.txt'])==1 and done==files

# A retry can newly diagnose an earlier requested dependency when reparsing the
# remaining consumer. That URI remains in the original invocation's selection.
found={};done=[]
try:run(Client('clean_crash'),files,found,done)
except a.EditorCrashed:pass
retry=Client('retry_late');run(retry,files[len(done):],found,done)
results['earlier_file_new_warning_during_retry']={'found':found,'done':len(done),'received':retry.findings,'lost':not found}
assert not found and files[0].as_uri() in retry.findings and done==files
try:a.gd_files(p,[str(p/'missing.gd')]);missing=False
except SystemExit:missing=True
results['missing_refused']=missing
assert missing
results['source_sha256']={rel:hashlib.sha256((O/(Path(rel).name+'.txt')).read_bytes()).hexdigest() for rel in ['tools/gdscript_warnings.py','tools/test_gdscript_warnings.py']}
results['engines_started']=0
(O/'probe.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
