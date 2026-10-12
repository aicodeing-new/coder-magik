import base64
import http.client
import json
import threading
import unittest
from unittest.mock import patch
from http.server import ThreadingHTTPServer
import adapter

class AdapterTests(unittest.TestCase):
    def setUp(self):
        adapter.CLIENT_ID, adapter.CLIENT_SECRET = 'test-client', 'test-secret'
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), adapter.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
    def request(self, method, path, body=None, headers=None):
        c = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        c.request(method, path, body, headers or {})
        r = c.getresponse()
        result = r.status, json.loads(r.read())
        c.close()
        return result
    def test_no_email_has_stable_identity(self):
        result = adapter.identity({'data': {'open_id':'ou_123', 'name':'Dev', 'mobile':'12345'}})
        self.assertEqual(result['email'], 'ou_123@feishu.invalid')
        self.assertFalse(result['email_verified'])
        self.assertNotIn('mobile', result)
    def test_username_is_pinyin_of_name(self):
        result = adapter.identity({'data': {'open_id':'ou_123', 'name':'张三'}})
        self.assertEqual(result['preferred_username'], 'zhangsan')
        self.assertEqual(result['user_name'], '张三')
        self.assertEqual(adapter.identity({'data': {'open_id':'ou_123', 'name':'李小明'}})['preferred_username'], 'lixiaoming')
        self.assertEqual(adapter.identity({'data': {'open_id':'ou_123', 'name':'吕雉'}})['preferred_username'], 'lvzhi')
    def test_surname_readings_apply_to_first_char_only(self):
        self.assertEqual(adapter.pinyin_username('单伟', 'ou_x'), 'shanwei')
        self.assertEqual(adapter.pinyin_username('曾青', 'ou_x'), 'zengqing')
        self.assertEqual(adapter.pinyin_username('乐磊', 'ou_x'), 'yuelei')
        self.assertEqual(adapter.pinyin_username('明单', 'ou_x'), 'mingdan')
    def test_ascii_and_untranslatable_names(self):
        self.assertEqual(adapter.pinyin_username('Dev Wang', 'ou_x'), 'devwang')
        self.assertEqual(adapter.pinyin_username('买买提·艾力', 'ou_x'), 'maimaitiaili')
        self.assertEqual(adapter.pinyin_username('!!!', 'ou_x'), 'ou_x')
        self.assertEqual(adapter.pinyin_username('', 'ou_x'), 'ou_x')
    def test_missing_identity_rejected(self):
        with self.assertRaises(ValueError): adapter.identity({'data': {'name':'Dev'}})
    def test_token_translation_and_client_auth(self):
        auth = 'Basic ' + base64.b64encode(b'test-client:test-secret').decode()
        body = 'grant_type=authorization_code&code=test-code&redirect_uri=' + adapter.CALLBACK
        with patch('adapter.upstream', return_value={'code':0,'access_token':'access','expires_in':123}) as api:
            status, result = self.request('POST','/token',body,{'Authorization':auth})
            self.assertEqual(status, 200)
            self.assertEqual(result['access_token'], 'access')
            self.assertEqual(api.call_args.kwargs['payload']['redirect_uri'], adapter.CALLBACK)
        with patch('adapter.upstream') as api:
            self.assertEqual(self.request('POST','/token',body)[0],401)
            api.assert_not_called()
    def test_wrong_redirect_rejected_before_exchange(self):
        body = 'client_id=test-client&client_secret=test-secret&grant_type=authorization_code&code=x&redirect_uri=https://evil.example'
        with patch('adapter.upstream') as api:
            self.assertEqual(self.request('POST','/token',body)[0],400)
            api.assert_not_called()
    def test_userinfo_requires_token_and_subject(self):
        self.assertEqual(self.request('GET','/userinfo')[0],401)
        with patch('adapter.upstream', return_value={'data': {'name':'Dev'}}):
            self.assertEqual(self.request('GET','/userinfo',headers={'Authorization':'Bearer x'})[0],401)
    def test_upstream_errors_do_not_leak_credentials(self):
        with patch('adapter.upstream', side_effect=ValueError('secret')):
            status, body = self.request('GET','/userinfo',headers={'Authorization':'Bearer x'})
            self.assertEqual(status,401)
            self.assertNotIn('secret',json.dumps(body))

if __name__ == '__main__': unittest.main()
