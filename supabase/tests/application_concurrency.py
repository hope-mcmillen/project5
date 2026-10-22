"""Local-only simultaneous apply/cap/status tests using separate Postgres sessions."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import threading
import uuid

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--container',default='supabase_db_project5')
args=parser.parse_args()


def sql(text,check=True):
    r=subprocess.run(['docker','exec','-i',args.container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1',
                      '-U','postgres','-d','postgres'],input=text,text=True,capture_output=True,timeout=35)
    if check and r.returncode:
        raise RuntimeError(r.stderr.strip())
    return r


def uid():return str(uuid.uuid4())
users={k:uid() for k in ('owner','cap','duplicate','decision','closing')}
company=uid()
jobs=[uid() for _ in range(29)]
versions={k:uid() for k in users if k!='owner'}
user_list=','.join("'"+u+"'" for u in users.values())


def claim(user):return "set local request.jwt.claims='"+json.dumps({'sub':user,'role':'authenticated'})+"';"


def race(calls,allowed_errors):
    gate=threading.Barrier(len(calls))
    def run(call):
        user,command=call
        gate.wait(timeout=10)
        return sql('begin; set local role authenticated; '+claim(user)+command+'; select pg_sleep(0.2); commit;',False)
    with ThreadPoolExecutor(max_workers=len(calls)) as pool:
        results=list(pool.map(run,calls))
    for result in results:
        if result.returncode and not any(e in result.stderr for e in allowed_errors):
            raise AssertionError('Unexpected concurrent SQL failure: '+result.stderr)
    return sum(r.returncode==0 for r in results)


def expect(query,value,message):
    if sql(query).stdout.strip()!=value:
        raise AssertionError(message)


try:
    values=','.join("('%s','race-%s@example.test','%s'::jsonb)"%(user,user,json.dumps({'role':'recruiter' if key=='owner' else 'candidate'})) for key,user in users.items())
    sql('insert into auth.users(id,email,raw_user_meta_data) values '+values+';')
    sql(f"insert into public.companies(id,name,created_by) values('{company}','Application Race','{users['owner']}');"
        f"insert into public.recruiters(profile_id,company_id,company_role) values('{users['owner']}','{company}','owner');")
    for key,version in versions.items():
        sql(f"insert into public.profile_versions(id,candidate_id,version,confirmed) values('{version}','{users[key]}',1,true);"
            f"update public.candidates set active_version_id='{version}' where profile_id='{users[key]}';"
            f"insert into public.candidate_skills(profile_version_id,skill_id,raw_name,years) select '{version}',id,'Flutter',4 from public.skills where name='Flutter';")
    for job in jobs:
        sql(f"insert into public.jobs(id,company_id,created_by,title,raw_description,status,parse_status) values('{job}','{company}','{users['owner']}','Race','Synthetic','OPEN','READY');"
            f"insert into public.job_requirements(job_id,skill_id,min_years) select '{job}',id,2 from public.skills where name='Flutter';")
    setup='begin;'+claim(users['cap'])+''.join(f"select public.swipe('{job}','right');" for job in jobs[:24])+'commit;'
    sql(setup)
    accepted=race([(users['cap'],f"select public.swipe('{jobs[24]}','right')"),
                   (users['cap'],f"select public.swipe('{jobs[25]}','right')")],['daily_cap_reached'])
    if accepted!=1:raise AssertionError('Exactly one of two final cap requests must succeed')
    expect(f"select count(*) from public.swipes where candidate_id='{users['cap']}' and direction='right';",'25','cap exceeded under concurrency')
    print('PASS: simultaneous final-slot applies cannot exceed daily cap')

    accepted=race([(users['duplicate'],f"select public.swipe('{jobs[0]}','right')"),
                   (users['duplicate'],f"select public.swipe('{jobs[0]}','right')")],['already_swiped'])
    if accepted!=1:raise AssertionError('Exactly one duplicate apply must succeed')
    expect(f"select count(*) from public.applications where candidate_id='{users['duplicate']}' and job_id='{jobs[0]}';",'1','duplicate applications created')
    print('PASS: duplicate simultaneous applies create one application/event')

    sql('begin;'+claim(users['decision'])+f"select public.swipe('{jobs[26]}','right');commit;")
    application=sql(f"update public.applications set committed_at=now()-interval '1 second' where candidate_id='{users['decision']}' returning id;").stdout.strip()
    accepted=race([(users['owner'],f"select public.reject('{application}','internal')"),
                   (users['decision'],f"select public.withdraw('{application}')")],['invalid_transition'])
    if accepted!=1:raise AssertionError('Only one competing terminal decision may win')
    expect(f"select status in ('WITHDRAWN','NOT_SELECTED') from public.applications where id='{application}';",'t','illegal final state')
    expect(f"select count(*) from public.status_events where application_id='{application}';",'2','duplicate/missing audit events')
    print('PASS: competing reject/withdraw serialize into one legal transition')

    race([(users['closing'],f"select public.swipe('{jobs[27]}','right')"),
          (users['owner'],f"select public.set_job_status('{jobs[27]}','CLOSED')")],['job_not_open'])
    expect(f"select status='CLOSED' from public.jobs where id='{jobs[27]}';",'t','job must close')
    expect(f"select count(*) from public.applications where job_id='{jobs[27]}' and status<>'JOB_CLOSED';",'0','late apply survived closure')
    print('PASS: job-close/apply race leaves no active application on a closed job')
finally:
    sql(f"delete from public.companies where id='{company}'; delete from auth.users where id in ({user_list});")
