from types import SimpleNamespace
import unittest

from tools.google_auth_policy import block_production, origin, validate_probe_base


class GoogleAuthProbePolicyTests(unittest.TestCase):
    def test_probe_only_visits_the_public_app_or_a_loopback_build(self):
        for url in ('https://www.douglastkaiser.com/stones/',
                    'http://localhost:4174/stones/', 'http://127.0.0.1:4174/stones/'):
            self.assertEqual(validate_probe_base(url), url)
        for url in ('https://evil.example/stones/', 'http://localhost.evil.test/stones/',
                    'https://user:secret@www.douglastkaiser.com/stones/',
                    'http://user:secret@localhost:4174/stones/',
                    'http://localhost:4174/other/', 'http://localhost:4174/stones/?token=private'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_probe_base(url)

    def test_origin_drops_credentials_oauth_data_and_personal_path(self):
        self.assertEqual(origin(
            'https://user:password@accounts.google.com/person@example.com'
            '?state=private&code=secret#id_token=private'),
            'https://accounts.google.com')
        self.assertEqual(origin('about:blank'), 'opaque')
        self.assertEqual(origin('data:text/html,private'), 'opaque')

    def test_origin_keeps_nonstandard_port_and_ipv6(self):
        self.assertEqual(origin('http://127.0.0.1:9099/callback?token=secret'),
                         'http://127.0.0.1:9099')
        self.assertEqual(origin('https://example.com:443/private'), 'https://example.com')
        self.assertEqual(origin('http://[::1]:9099/private'), 'http://[::1]:9099')

    def test_production_writes_and_account_reads_are_blocked(self):
        for url, method in [
            ('https://identitytoolkit.googleapis.com/v1/accounts:signUp', 'POST'),
            ('https://identitytoolkit.googleapis.com/v1/accounts:lookup', 'GET'),
            ('https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo', 'GET'),
            ('https://accounts.google.com/signin', 'POST'),
            ('https://evil.example/upload', 'POST'),
            ('http://identitytoolkit.googleapis.com/v1/accounts:createAuthUri', 'POST'),
            ('https://identitytoolkit.googleapis.com:444/v1/accounts:createAuthUri', 'POST'),
            ('https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp', 'POST'),
            ('https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyAssertion', 'POST'),
            ('https://firestore.googleapis.com/v1/private', 'GET'),
            ('https://securetoken.googleapis.com/v1/token', 'POST'),
            ('https://firebaseinstallations.googleapis.com/v1/installations', 'POST'),
            ('https://firebasestorage.googleapis.com/v0/upload', 'POST'),
            ('https://www.google-analytics.com/g/collect', 'GET'),
            ('https://www.googletagmanager.com/gtag/js', 'GET'),
        ]:
            with self.subTest(url=url, method=method):
                self.assertTrue(block_production(SimpleNamespace(url=url, method=method)))

    def test_public_config_helpers_and_local_emulator_are_allowed(self):
        for url, method in [
            ('https://identitytoolkit.googleapis.com/v1/projects?key=public', 'GET'),
            ('https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig?key=public', 'GET'),
            ('https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig', 'POST'),
            ('https://www.googleapis.com/identitytoolkit/v3/relyingparty/createAuthUri', 'POST'),
            ('https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri', 'POST'),
            ('https://stones-9a6a0.firebaseapp.com/__/auth/handler', 'GET'),
            ('https://accounts.google.com/o/oauth2/auth', 'GET'),
            ('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp', 'POST'),
        ]:
            with self.subTest(url=url, method=method):
                self.assertFalse(block_production(SimpleNamespace(url=url, method=method)))


if __name__ == '__main__':
    unittest.main()
