"""Source-census tests using an explicit read-only Contacts source pending integration."""
import hashlib,json,sys,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[5]
sys.path.insert(0,str(root/'tools'))
import underground_memory_budget as b
import test_underground_memory_budget as t
assert len(sys.argv)==2, 'usage: reproduce.py path-to-actual-contact-source'
path=Path(sys.argv[1]).resolve()
raw=path.read_bytes()
index=b.audit.load_source_index()
index['underground_connector_contacts']=b.audit.parse_module('underground_connector_contacts','godot/scripts/core/underground_connector_contacts.gd',raw.decode())
@classmethod
def set_up(cls): cls.index=index
t.JointPackTests.setUpClass=set_up
result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(t.JointPackTests))
record={'external_contacts_path':str(path),'source_sha256':hashlib.sha256(raw).hexdigest(),'source_unchanged':path.read_bytes()==raw,
        'tools':{name:hashlib.sha256((root/'tools'/name).read_bytes()).hexdigest() for name in ('underground_memory_budget.py','test_underground_memory_budget.py')},
        'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'contacts':b.connector_contacts_reservation(index),
        'scope':'Read-only source census and adversarial mutations; not an engine run, integrated checkpoint or native memory qualification.'}
Path(__file__).with_name('result.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
sys.exit(0 if result.wasSuccessful() and record['source_unchanged'] else 1)
