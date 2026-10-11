"""Generate Dex config in Kubernetes Secrets; never persist credentials locally."""
import base64
import json
import secrets
import subprocess
import urllib.parse
import psycopg2
import sys

K = ['kubectl', '--kubeconfig=/mnt/d/Downloads/ali-prod-kubeconfig-admin.yaml', '-n', 'coder']
def get_secret(name):
    obj = json.loads(subprocess.check_output(K + ['get', 'secret', name, '-o', 'json']))
    return {k: base64.b64decode(v).decode() for k, v in obj['data'].items()}
def apply_secret(name, data):
    obj = {'apiVersion':'v1','kind':'Secret','metadata':{'name':name,'namespace':'coder'},'stringData':data}
    subprocess.run(K + ['apply', '-f', '-'], input=json.dumps(obj), text=True, check=True)

url = urllib.parse.urlparse(get_secret('coder-db-url')['url'])
if '--skip-database-create' not in sys.argv:
    conn = psycopg2.connect(host=url.hostname, port=url.port, user=urllib.parse.unquote(url.username), password=urllib.parse.unquote(url.password), dbname='postgres', sslmode='disable', connect_timeout=10)
    conn.autocommit = True
    with conn.cursor() as cursor:
        cursor.execute("SELECT 1 FROM pg_database WHERE datname='coder_sso'")
        if not cursor.fetchone():
            cursor.execute('CREATE DATABASE coder_sso OWNER magik')
    conn.close()
try:
    private = get_secret('coder-sso-private')
except subprocess.CalledProcessError:
    private = {'CODER_OIDC_SECRET': secrets.token_urlsafe(48)}
    apply_secret('coder-sso-private', private)
feishu = get_secret('coder-feishu')
config = {
    'issuer': 'https://coder.magikcloud.cn/sso',
    'storage': {'type':'postgres','config':{'host':url.hostname,'port':url.port,'database':'coder_sso','user':urllib.parse.unquote(url.username),'password':urllib.parse.unquote(url.password),'ssl':{'mode':'disable'}}},
    'web': {'http':'0.0.0.0:5556'},
    'logger': {'level':'warn','format':'json'},
    'oauth2': {'skipApprovalScreen':True},
    'staticClients': [{'id':'coder','name':'Coder','secret':private['CODER_OIDC_SECRET'],'redirectURIs':['https://coder.magikcloud.cn/api/v2/users/oidc/callback']}],
    'connectors': [{'type':'oauth','id':'feishu','name':'飞书','config':{
        'clientID':feishu['FEISHU_CLIENT_ID'],'clientSecret':feishu['FEISHU_CLIENT_SECRET'],
        'redirectURI':'https://coder.magikcloud.cn/sso/callback',
        'authorizationURL':'https://accounts.feishu.cn/open-apis/authen/v1/authorize',
        'tokenURL':'http://127.0.0.1:8081/token','userInfoURL':'http://127.0.0.1:8081/userinfo',
        'scopes':[],
    }}],
}
apply_secret('coder-sso-config', {'dex.json':json.dumps(config)})
print('SSO database and configuration ready')
