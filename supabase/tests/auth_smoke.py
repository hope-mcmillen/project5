"""Exercise real local Auth signups and PostgREST RPCs; never targets a hosted project.
Uses only Python's standard library. Deletes its synthetic auth users on completion.
"""
import argparse
import json
import secrets
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--supabase', default='supabase')
args = parser.parse_args()
status = subprocess.run([args.supabase, 'status', '-o', 'json'],
                        capture_output=True, text=True, check=True)
config = json.loads(status.stdout)
base = config['API_URL'].rstrip('/')
if urllib.parse.urlsplit(base).hostname not in ('localhost', '127.0.0.1', '::1'):
    raise SystemExit('Refusing non-local Supabase endpoint')
anon_key = config['ANON_KEY']
service_key = config['SERVICE_ROLE_KEY']
users = []


def request(path, body=None, token=None, admin=False, method=None):
    key = service_key if admin else anon_key
    headers = {'apikey': key, 'Authorization': 'Bearer '+(token or key),
               'Content-Type': 'application/json'}
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base+path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def expect(condition, message):
    if not condition:
        # Do not include API responses: they can contain tokens.
        raise AssertionError(message)


def profile(token, user):
    code, body = request('/rest/v1/profiles?select=id,role&id=eq.'+user, token=token)
    expect(code == 200 and len(body) == 1, 'own profile must be readable')
    return body[0]


try:
    accounts = {}
    for label, metadata in [('candidate', {'role': 'candidate'}),
                            ('recruiter', {'role': 'recruiter'}),
                            ('missing', {}), ('invalid', {'role': 'admin'})]:
        code, body = request('/auth/v1/signup', {
            'email': 'onboarding-'+str(uuid.uuid4())+'@example.test',
            'password': secrets.token_urlsafe(24), 'data': metadata})
        expect(code == 200 and body.get('access_token'), 'local Auth signup must issue a session')
        user, token = body['user']['id'], body['access_token']
        users.append(user)
        accounts[label] = (user, token)
        expected = label if label in ('candidate', 'recruiter') else None
        expect(profile(token, user)['role'] == expected, 'signup must save only a valid role')
        code, candidate_rows = request('/rest/v1/candidates?select=profile_id', token=token)
        expect(code == 200 and len(candidate_rows) == (1 if label == 'candidate' else 0),
               'candidate row must match selected role')
    print('PASS: real Auth signups honor candidate, recruiter, absent and invalid role metadata')

    user, token = accounts['missing']
    code, body = request('/rest/v1/rpc/set_initial_role', {'p_role': 'candidate'}, token=token)
    expect(code in (200, 204), 'missing-role account must choose its initial role')
    expect(profile(token, user)['role'] == 'candidate', 'initial role must be persisted')
    code, body = request('/rest/v1/rpc/set_initial_role', {'p_role': 'recruiter'}, token=token)
    expect(code >= 400 and body.get('message') == 'role_already_set', 'second choice must be denied')
    print('PASS: initial-role choice is one-time through the real RPC endpoint')

    user, token = accounts['recruiter']
    code, company = request('/rest/v1/rpc/create_company', {'p_name': 'Auth Smoke Company'}, token=token)
    expect(code == 200 and company.get('id'), 'real recruiter session must create a company')
    code, invite = request('/rest/v1/rpc/create_invite', {}, token=token)
    expect(code == 200 and isinstance(invite, str) and len(invite) == 8, 'real owner session must create invite')
    code, body = request('/rest/v1/rpc/revoke_invite', {'p_code': invite}, token=token)
    expect(code in (200, 204), 'real owner session must revoke invite')
    print('PASS: real recruiter session creates company and creates/revokes invite')
finally:
    # Companies reference creators with SET NULL, so remove our companies first.
    for user in users:
        code, _ = request('/rest/v1/companies?created_by=eq.'+user, admin=True, method='DELETE')
        expect(code in (200, 204), 'synthetic company cleanup must succeed')
        code, _ = request('/auth/v1/admin/users/'+user, admin=True, method='DELETE')
        expect(code in (200, 204), 'synthetic user cleanup must succeed')
