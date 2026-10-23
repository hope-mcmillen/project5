"""Local real-service parser smoke test. Requires functions served with LLM_PROVIDER=mock.
Uses only the synthetic r01 PDF and refuses hosted API URLs.
"""
import argparse
import json,subprocess,urllib.request,urllib.error,urllib.parse,uuid,secrets
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--supabase',default='supabase');args=p.parse_args()
r=subprocess.run([args.supabase,'status','-o','json'],capture_output=True,text=True,check=True)
c=json.loads(r.stdout);base=c['API_URL'].rstrip('/')
assert urllib.parse.urlsplit(base).hostname in ('127.0.0.1','localhost'), 'Local only'
uid=None

def call(path,body=None,token=None,admin=False,method=None):
 key=c['SERVICE_ROLE_KEY'] if admin else c['ANON_KEY']
 req=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'},method=method)
 try:
  with urllib.request.urlopen(req,timeout=30) as response:
   raw=response.read();return response.status,json.loads(raw) if raw else None
 except urllib.error.HTTPError as error:return error.code,json.load(error)

try:
 status,data=call('/auth/v1/signup',{'email':'parse-local-'+str(uuid.uuid4())+'@example.test','password':secrets.token_urlsafe(24),'data':{'role':'candidate'}})
 assert status==200 and data.get('access_token'),'local signup failed'
 uid=data['user']['id'];token=data['access_token']
 boundary='parse-check-'+uuid.uuid4().hex
 file=Path('supabase/seed/resumes/r01_flutter_single_column.pdf').read_bytes()
 body=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="r01_flutter_single_column.pdf"\r\nContent-Type: application/pdf\r\n\r\n'.encode()+file+f'\r\n--{boundary}--\r\n'.encode())
 req=urllib.request.Request(base+'/functions/v1/parse-resume',data=body,headers={'apikey':c['ANON_KEY'],'Authorization':'Bearer '+token,'Content-Type':'multipart/form-data; boundary='+boundary,'Accept':'text/event-stream'})
 with urllib.request.urlopen(req,timeout=120) as response:raw=response.read().decode()
 events=[json.loads(line[5:].strip()) for line in raw.splitlines() if line.startswith('data:')]
 assert events and events[-1]['status']=='READY','parse did not finish READY: '+str(events[-1] if events else 'no events')
 version=events[-1]['profile_version_id']
 status,versions=call('/rest/v1/profile_versions?id=eq.'+version+'&select=*,candidate_skills(*),candidate_experiences(*)',token=token)
 assert status==200 and len(versions)==1,'saved profile missing'
 v=versions[0];assert v['resume_id'] is None and v['source']=='resume' and v['version']==1 and not v['confirmed'],'draft metadata wrong'
 assert len(v['candidate_experiences'])==2,'expected two verified jobs'
 skills=[{k:s.get(k) for k in ['skill_id','raw_name','years','evidence']} for s in v['candidate_skills']]
 status,_=call('/rest/v1/rpc/confirm_profile',{'p_version_id':version,'p_skills':skills},token)
 assert status in (200,204),'confirm_profile failed'
 status,confirmed=call('/rest/v1/profile_versions?id=eq.'+version+'&select=confirmed',token=token)
 assert status==200 and confirmed[0]['confirmed'] is True,'parsed version not confirmed'
 status,rows=call('/rest/v1/candidates?profile_id=eq.'+uid+'&select=active_version_id',token=token)
 assert status==200 and rows[0]['active_version_id']==version,'active profile not set'
 status,rows=call('/rest/v1/resumes?candidate_id=eq.'+uid+'&select=id',token=token)
 assert status==200 and rows==[],'unexpected resumes row'
 status,rows=call('/storage/v1/object/list/resumes',{'prefix':uid+'/','limit':100},admin=True)
 assert status==200 and rows==[],'unexpected stored resume file'
 print('PASS: actual local Auth + multipart/SSE Edge + service RPC + candidate review/confirmation')
 print('PASS: version=1; source=resume; resume_id=null; experiences=2; active_version_id set; resumes rows=0; stored files=0')
 print('Observed progress: '+', '.join(e['status'] for e in events))
finally:
 if uid:
  status,_=call('/rest/v1/llm_usage?user_id=eq.'+uid,admin=True,method='DELETE')
  assert status in (200,204),'synthetic usage cleanup failed'
  status,_=call('/auth/v1/admin/users/'+uid,admin=True,method='DELETE')
  assert status in (200,204),'synthetic local account cleanup failed'
