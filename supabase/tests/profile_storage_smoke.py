"""Real local demo login, profile RPC and Storage boundary checks. No hosted writes."""
import argparse
import json
from pathlib import Path
import re
import secrets
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--supabase', default='supabase')
args = parser.parse_args()
result = subprocess.run([args.supabase,'status','-o','json'],capture_output=True,text=True,check=True)
config = json.loads(result.stdout)
base = config['API_URL'].rstrip('/')
if urllib.parse.urlsplit(base).hostname not in ('localhost','127.0.0.1','::1'):
    raise SystemExit('Refusing non-local Supabase endpoint')
root = Path(__file__).resolve().parents[2]
users, uploads = [], []


def call(path, body=None, token=None, admin=False, method=None, content_type='application/json'):
    key = config['SERVICE_ROLE_KEY'] if admin else config['ANON_KEY']
    headers = {'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':content_type}
    data = body if isinstance(body,bytes) else None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=20) as response:
            raw = response.read()
            if 'application/json' in response.headers.get('Content-Type',''):
                return response.status,json.loads(raw) if raw else None
            return response.status,raw
    except urllib.error.HTTPError as error:
        # Do not report response bodies; they may contain tokens or credentials.
        error.read()
        return error.code,None


def expect(condition,message):
    if not condition:
        raise AssertionError(message)


def signup():
    code,body = call('/auth/v1/signup',{'email':'storage-'+str(uuid.uuid4())+'@example.test',
        'password':secrets.token_urlsafe(24),'data':{'role':'candidate'}})
    expect(code==200 and body.get('access_token'),'synthetic candidate signup must succeed')
    users.append(body['user']['id'])
    return body['user']['id'],body['access_token']


try:
    # Credentials are defined only in README's local-dev table and seed.sql.
    accounts = re.findall(r'^\| (candidate|recruiter) \| ([^|]+) \| ([^|]+) \|$',
                          (root/'README.md').read_text(),re.M)
    expect(len(accounts)==2,'README must document both local demo accounts')
    demo = {}
    for role,email,password in accounts:
        code,body = call('/auth/v1/token?grant_type=password',{'email':email.strip(),'password':password.strip()})
        expect(code==200 and body.get('access_token'),'documented demo login must succeed')
        demo[role]=body['access_token']
        code,profiles = call('/rest/v1/profiles?select=role',token=body['access_token'])
        expect(code==200 and len(profiles)==1 and profiles[0]['role']==role,'demo login must have correct role')
    print('PASS: documented candidate/recruiter demo logins work through real Auth')

    uid,token = signup()
    _,other_token = signup()
    code,version = call('/rest/v1/rpc/create_manual_profile',{},token=token)
    expect(code==200 and version['source']=='manual' and not version['confirmed'],'manual draft must be created')
    code,skills = call('/rest/v1/skills?select=id&name=eq.Flutter',token=token)
    expect(code==200 and skills,'seed taxonomy must be readable')
    code,_ = call('/rest/v1/rpc/confirm_profile',{'p_version_id':version['id'],
        'p_skills':[{'skill_id':skills[0]['id'],'raw_name':'Flutter','years':2,'evidence':'Built synthetic mobile apps'}]},token=token)
    expect(code in (200,204),'review confirmation must work through real API')
    code,rows = call('/rest/v1/profile_versions?select=confirmed,embedding_model&id=eq.'+version['id'],token=token)
    expect(code==200 and rows[0]['confirmed'] and rows[0]['embedding_model']=='gemini-embedding-001@1536',
           'confirmed profile must have taxonomy embedding')
    code,_ = call('/rest/v1/rpc/save_preferences',{'p_prefs':{'remote':['remote'],'include_stretch':True}},token=token)
    expect(code in (200,204),'valid preferences must save')
    code,_ = call('/rest/v1/rpc/save_preferences',{'p_prefs':{'role':'recruiter'}},token=token)
    expect(code>=400,'unknown preference keys must fail')
    print('PASS: manual profile confirmation, taxonomy vector and preferences work through real API')

    file_bytes=(root/'supabase/seed/resumes/r01_flutter_single_column.pdf').read_bytes()
    path=uid+'/'+str(uuid.uuid4())+'.pdf'
    code,_=call('/storage/v1/object/resumes/'+path,file_bytes,token=token,content_type='application/pdf')
    expect(code in (200,201),'own private PDF upload must succeed')
    uploads.append(path)
    code,download=call('/storage/v1/object/authenticated/resumes/'+path,token=token)
    expect(code==200 and download==file_bytes,'owner must download exact uploaded bytes')
    code,_=call('/storage/v1/object/authenticated/resumes/'+path,token=other_token)
    expect(code>=400,'another candidate must not download private resume')
    code,_=call('/storage/v1/object/authenticated/resumes/'+path,token=demo['recruiter'])
    expect(code>=400,'recruiter must not directly download private resume')
    code,_=call('/storage/v1/object/public/resumes/'+path)
    expect(code>=400,'private resume must not have public URL')
    code,_=call('/storage/v1/object/resumes/'+uid+'/'+str(uuid.uuid4())+'.pdf',file_bytes,
                token=other_token,content_type='application/pdf')
    expect(code>=400,'cross-folder upload must fail')
    code,_=call('/storage/v1/object/resumes/'+uid+'/'+str(uuid.uuid4())+'.txt',b'not a PDF',
                token=token,content_type='text/plain')
    expect(code>=400,'unsupported MIME type must fail')
    code,_=call('/storage/v1/object/resumes/'+uid+'/'+str(uuid.uuid4())+'.pdf',b'X'*(5242880+1),
                token=token,content_type='application/pdf')
    expect(code>=400,'oversized upload must fail')
    print('PASS: real Storage protects resume reads/uploads and enforces MIME/size limits')
finally:
    if uploads:
        code,_=call('/storage/v1/object/resumes',{'prefixes':uploads},admin=True,method='DELETE')
        expect(code in (200,204),'synthetic storage cleanup must succeed')
    for user in users:
        code,_=call('/auth/v1/admin/users/'+user,admin=True,method='DELETE')
        expect(code in (200,204),'synthetic auth cleanup must succeed')
