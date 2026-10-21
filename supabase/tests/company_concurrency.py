"""Local-only race checks; uses the project's Docker Postgres, no credentials.
Run after supabase db reset: python3 supabase/tests/company_concurrency.py
Fixtures use random IDs and are deleted even when a test fails.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import threading
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--container', default='supabase_db_project5')
args = parser.parse_args()


def execute(sql, check=True):
    result = subprocess.run(
        ['docker', 'exec', '-i', args.container, 'psql', '-X', '-qAt',
         '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
        input=sql, text=True, capture_output=True, timeout=30)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result


def uid():
    return str(uuid.uuid4())


users = {key: uid() for key in ('choice', 'create', 'owner1', 'owner2', 'join', 'slot1', 'slot2', 'manual')}
companies = [uid(), uid()]
# Generated fixture codes use the same unambiguous alphabet as production.
alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
codes = [''.join(alphabet[b % len(alphabet)] for b in uuid.uuid4().bytes[:8]) for _ in range(3)]
user_ids = ','.join("'"+value+"'" for value in users.values())


def assert_sql(sql, expected, message):
    actual = execute(sql).stdout.strip()
    if actual != expected:
        raise AssertionError(f'{message}: expected {expected!r}, got {actual!r}')


def race(calls, expected_error=None):
    gate = threading.Barrier(2)

    def run(call):
        user, statement = call
        claims = json.dumps({'sub': user, 'role': 'authenticated'})
        gate.wait(timeout=10)
        return execute(
            f"begin; set local role authenticated; set local request.jwt.claims = '{claims}'; "
            f'{statement}; select pg_sleep(0.25); commit;', check=False)

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(run, calls))
    successes = sum(result.returncode == 0 for result in results)
    errors = [result.stderr for result in results if result.returncode]
    if expected_error is None:
        if successes != 2:
            raise AssertionError(f'Expected two successful serialized calls, got {successes}')
        return
    if successes != 1 or len(errors) != 1 or expected_error not in errors[0]:
        raise AssertionError(f'Expected one success and {expected_error}; got '
                             f'{successes} successes, {errors!r}')


try:
    # An auth insertion is committed before opening the independent sessions.
    values = ','.join(
        f"('{user}','race-{user}@example.test','{json.dumps({} if key == 'choice' else {'role':'candidate' if key == 'manual' else 'recruiter'})}'::jsonb)"
        for key, user in users.items())
    execute(f'insert into auth.users(id,email,raw_user_meta_data) values {values};')
    execute(f"""
      insert into public.companies(id,name,created_by) values
        ('{companies[0]}','Concurrency One','{users['owner1']}'),
        ('{companies[1]}','Concurrency Two','{users['owner2']}');
      insert into public.recruiters(profile_id,company_id,company_role) values
        ('{users['owner1']}','{companies[0]}','owner'),
        ('{users['owner2']}','{companies[1]}','owner');
      insert into public.company_invites(code,company_id,expires_at,max_uses) values
        ('{codes[0]}','{companies[0]}',now()+interval '1 day',10),
        ('{codes[1]}','{companies[1]}',now()+interval '1 day',10),
        ('{codes[2]}','{companies[0]}',now()+interval '1 day',1);
    """)

    race([(users['choice'], "select public.set_initial_role('candidate')"),
          (users['choice'], "select public.set_initial_role('recruiter')")], 'role_already_set')
    assert_sql(f"""select case when p.role='candidate' then
        (select count(*)=1 from public.candidates c where c.profile_id=p.id)
        else not exists(select 1 from public.candidates c where c.profile_id=p.id) end
      from public.profiles p where p.id='{users['choice']}';""", 't', 'role and candidate row stay consistent')
    print('PASS: concurrent initial-role choices are serialized')

    race([(users['create'], "select (public.create_company('Concurrent Create')).id"),
          (users['create'], "select (public.create_company('Concurrent Create')).id")], 'already_in_company')
    assert_sql(f"select count(*) from public.companies where created_by='{users['create']}';", '1', 'no orphan company')
    print('PASS: concurrent company creation produces one company')

    race([(users['join'], f"select (public.join_company('{codes[0]}')).id"),
          (users['join'], f"select (public.join_company('{codes[1]}')).id")], 'already_in_company')
    assert_sql(f"select sum(uses) from public.company_invites where code in ('{codes[0]}','{codes[1]}');", '1', 'only one join consumes an invite')
    print('PASS: concurrent joins cannot attach one recruiter to two companies')

    race([(users['slot1'], f"select (public.join_company('{codes[2]}')).id"),
          (users['slot2'], f"select (public.join_company('{codes[2]}')).id")], 'invalid_invite')
    assert_sql(f"select uses from public.company_invites where code='{codes[2]}';", '1', 'single-use code remains capped')
    assert_sql(f"select count(*) from public.recruiters where profile_id in ('{users['slot1']}','{users['slot2']}');", '1', 'only one recruiter joined')
    print('PASS: concurrent use cannot exceed an invite cap')

    race([(users['manual'], 'select (public.create_manual_profile()).id'),
          (users['manual'], 'select (public.create_manual_profile()).id')])
    assert_sql(f"select array_agg(version order by version)::text from public.profile_versions where candidate_id='{users['manual']}';",
               '{1,2}', 'concurrent manual versions are unique and consecutive')
    print('PASS: concurrent manual profiles get distinct consecutive versions')
    version = execute(f"select id from public.profile_versions where candidate_id='{users['manual']}' and version=1;").stdout.strip()
    race([(users['manual'], f"select public.confirm_profile('{version}','[{{\"raw_name\":\"First\",\"years\":1}}]'::jsonb)"),
          (users['manual'], f"select public.confirm_profile('{version}','[{{\"raw_name\":\"Second\",\"years\":2}}]'::jsonb)")], 'profile_already_confirmed')
    assert_sql(f"select count(*) from public.candidate_skills where profile_version_id='{version}';", '1', 'only winning reviewed skill persisted')
    assert_sql(f"select active_version_id::text from public.candidates where profile_id='{users['manual']}';", version, 'active version remains consistent')
    print('PASS: concurrent confirmation cannot overwrite an accepted profile snapshot')
finally:
    execute(f"delete from public.companies where created_by in ({user_ids}); "
            f"delete from auth.users where id in ({user_ids});")
