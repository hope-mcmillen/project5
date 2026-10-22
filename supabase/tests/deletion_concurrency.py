"""Local-only check that an in-flight upload holds deletion until commit."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import uuid

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--container',default='supabase_db_project5')
args=p.parse_args()
user=str(uuid.uuid4())
command=['docker','exec','-i',args.container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres']
def sql(query):
    result=subprocess.run(command,input=query,text=True,capture_output=True,timeout=15)
    if result.returncode:raise AssertionError(result.stderr)
    return result.stdout.strip()
claim="set local request.jwt.claims='"+json.dumps({'sub':user,'role':'authenticated'})+"';"
upload=None
try:
    sql(f"insert into auth.users(id,email,raw_user_meta_data) values('{user}','delete-race-{user}@example.test','{{\"role\":\"candidate\"}}');")
    # Each line is a separate psql command. The result confirms the lock is held
    # before launching deletion in an independent connection.
    upload=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    upload.stdin.write('begin;\nset local role authenticated;\n'+claim+'\nselect public.candidate_upload_allowed();\n')
    upload.stdin.flush()
    if upload.stdout.readline().strip()!='t':raise AssertionError('upload permission/lock not acquired')
    with ThreadPoolExecutor(max_workers=1) as pool:
        deletion=pool.submit(sql,'begin;set local role authenticated;'+claim+'select public.prepare_account_deletion();commit;')
        # The deletion transaction must be blocked by the Storage permission lock.
        import time
        time.sleep(0.2)
        if deletion.done():raise AssertionError('deletion bypassed active upload lock')
        upload.stdin.write('commit;\n');upload.stdin.close()
        upload.wait(timeout=10)
        if upload.returncode:raise AssertionError(upload.stderr.read())
        deletion.result(timeout=10)
    allowed=sql('begin;set local role authenticated;'+claim+'select public.candidate_upload_allowed();rollback;')
    if allowed!='f':raise AssertionError('upload allowed after deletion preparation')
    print('PASS: deletion waits for active uploads and refuses later uploads')
finally:
    if upload and upload.poll() is None:upload.kill();upload.wait()
    sql(f"delete from auth.users where id='{user}';")
