"""Exercise the candidate-to-recruiter loop through local Auth/PostgREST APIs."""
import argparse
from datetime import datetime,timedelta,timezone
import json
import secrets
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--supabase',default='supabase');args=p.parse_args()
s=subprocess.run([args.supabase,'status','-o','json'],capture_output=True,text=True,check=True)
c=json.loads(s.stdout);base=c['API_URL'].rstrip('/')
if urllib.parse.urlsplit(base).hostname not in ('127.0.0.1','localhost','::1'):raise SystemExit('Local endpoint required')
users=[];company=None


def call(path,body=None,token=None,admin=False,method=None):
    key=c['SERVICE_ROLE_KEY'] if admin else c['ANON_KEY']
    r=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),
        headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'},method=method)
    try:
        with urllib.request.urlopen(r,timeout=20) as response:
            raw=response.read();return response.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code,json.load(error)


def good(condition,message):
    if not condition:raise AssertionError(message)


def rpc(name,body,token):
    status,data=call('/rest/v1/rpc/'+name,body,token)
    good(status in (200,204),'RPC failed: '+name)
    return data


def signup(role):
    email='loop-'+str(uuid.uuid4())+'@example.test'
    status,data=call('/auth/v1/signup',{'email':email,'password':secrets.token_urlsafe(24),'data':{'role':role}})
    good(status==200 and data.get('access_token'),'local signup failed')
    users.append(data['user']['id']);return data['user']['id'],data['access_token'],email


try:
    rec,rt,rec_email=signup('recruiter');cand,ct,_=signup('candidate')
    company=rpc('create_company',{'p_name':'Loop API Demo'},rt)['id']
    job=str(uuid.uuid4())
    status,_=call('/rest/v1/jobs',{'id':job,'company_id':company,'created_by':rec,'title':'Flutter Developer','raw_description':'Synthetic Flutter role'},rt)
    good(status in (200,201),'job insert failed')
    status,skills=call('/rest/v1/skills?select=id&name=eq.Flutter',token=rt)
    good(status==200 and skills,'taxonomy unavailable');skill=skills[0]['id']
    rpc('save_requirements',{'p_job_id':job,'p_requirements':[{'skill_id':skill,'required':True,'min_years':2,'weight':2,'evidence':'Flutter role'}]},rt)
    rpc('set_job_status',{'p_job_id':job,'p_status':'OPEN'},rt)
    version=rpc('create_manual_profile',{},ct)['id']
    rpc('confirm_profile',{'p_version_id':version,'p_skills':[{'skill_id':skill,'raw_name':'Flutter','years':3,'evidence':'Built apps'}]},ct)
    applied=rpc('swipe',{'p_job_id':job,'p_direction':'right'},ct);application=applied['application_id']
    good(rpc('get_board',{'p_job_id':job},rt)==[],'pending apply visible')
    status,rows=call('/rest/v1/applications?select=id&id=eq.'+application,token=rt)
    good(status==200 and rows==[],'pending apply leaked through direct API')
    status,_=call('/rest/v1/rpc/advance',{'p_application_id':application},rt)
    good(status>=400,'pending apply could advance')
    # Test-only local service update simulates the five-second commit deadline.
    status,_=call('/rest/v1/applications?id=eq.'+application,
        {'committed_at':(datetime.now(timezone.utc)-timedelta(seconds=1)).isoformat()},admin=True,method='PATCH')
    good(status in (200,204),'test deadline update failed')
    board=rpc('get_board',{'p_job_id':job},rt)
    good(len(board)==1 and board[0]['match_score']==100,'committed real score absent')
    good(set(board[0])=={'application_id','handle','match_score','band','total_years','top_skills','gaps','status','committed_at'},'blind board contract changed')
    good('identity' not in rpc('get_candidate_detail',{'p_application_id':application},rt),'identity revealed before advance')
    rpc('open_application',{'p_application_id':application},rt)
    rpc('advance',{'p_application_id':application,'p_note':'Synthetic interview note'},rt)
    good('identity' in rpc('get_candidate_detail',{'p_application_id':application},rt),'advanced identity missing')
    contact=rpc('get_application_contact',{'p_application_id':application},ct)
    good(contact['email']==rec_email and contact['note']=='Synthetic interview note','contact scope incorrect')
    good(len(rpc('get_interview_list',{'p_job_id':job},rt))==1,'interview list incorrect')
    rpc('reject',{'p_application_id':application,'p_reason':'PRIVATE_TEST_REASON'},rt)
    status,reasons=call('/rest/v1/application_reject_reasons?select=reason&application_id=eq.'+application,token=ct)
    good(status==200 and reasons==[],'internal reason leaked')
    rpc('undo_reject',{'p_application_id':application},rt)
    rpc('withdraw',{'p_application_id':application},ct)
    good(rpc('get_board',{'p_job_id':job},rt)==[],'withdrawn application remains on default board')
    print('PASS: real API loop applies, hides pending identity, scores, advances, shares contact, rejects/undoes and withdraws')
finally:
    if company:
        status,_=call('/rest/v1/companies?id=eq.'+company,admin=True,method='DELETE')
        good(status in (200,204),'synthetic company cleanup failed')
    for user in users:
        status,_=call('/auth/v1/admin/users/'+user,admin=True,method='DELETE')
        good(status in (200,204),'synthetic auth cleanup failed')
