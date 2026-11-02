"""Verify process-scoped, authenticated simulator service discovery."""
from contextlib import redirect_stderr
from io import StringIO
import subprocess
import unittest
from unittest.mock import patch

import ios_service_uri


class ServiceDiscoveryTests(unittest.TestCase):
    def record(self, uri='http://127.0.0.1:8123/sample=/', pid=51):
        return {'processID': pid, 'eventMessage': 'The Dart VM service is listening on ' + uri}

    def test_authenticated_loopback_address_is_preserved(self):
        for host in ['127.0.0.1', '[::1]']:
            uri = f'http://{host}:8123/sample=/'
            self.assertEqual(ios_service_uri.parse_service_uri([self.record(uri)], 51), uri)

    def test_previous_process_cannot_supply_restart_address(self):
        old = self.record(pid=50)
        new = self.record('http://127.0.0.1:8124/new=/', 51)
        self.assertIsNone(ios_service_uri.parse_service_uri([old], 51))
        self.assertEqual(ios_service_uri.parse_service_uri([old, new], 51),
                         'http://127.0.0.1:8124/new=/')

    def test_remote_or_unauthenticated_addresses_are_rejected(self):
        invalid = ['http://example.invalid:8123/sample=/', 'http://127.0.0.1:8123/',
                   'http://127.0.0.1:8123/sample=/?query=1',
                   'http://127.0.0.1:8123/sample=/#fragment',
                   'http://@127.0.0.1:8123/sample=/',
                   'http://' + 'name' + ':' + 'synthetic' + '@127.0.0.1:8123/sample=/',
                   'http://127.0.0.1:0/sample=/', 'http://127.0.0.1:65536/sample=/']
        for uri in invalid:
            with self.subTest(uri=uri):
                self.assertIsNone(ios_service_uri.parse_service_uri([self.record(uri)], 51))

    def test_unrelated_or_malformed_log_records_do_not_connect(self):
        self.assertIsNone(ios_service_uri.parse_service_uri(
            [None, {'processID': 51, 'eventMessage': 'Open http://127.0.0.1:8123/sample=/'}], 51))

    def test_discovery_reads_later_logs_for_the_launched_process(self):
        empty = subprocess.CompletedProcess([], 0, stdout='[]', stderr='')
        ready = subprocess.CompletedProcess([], 0, stdout='[{"processID":51,"eventMessage":'
                                            '"Dart VM Service is listening on http://127.0.0.1:8123/sample=/"}]',
                                            stderr='')
        with patch.object(ios_service_uri.subprocess, 'run', side_effect=[empty, ready]) as run:
            with patch.object(ios_service_uri.time, 'sleep'):
                self.assertEqual(ios_service_uri.wait_for_service('synthetic-simulator', 51),
                                 'http://127.0.0.1:8123/sample=/')
        self.assertEqual(run.call_count, 2)
        self.assertIn('processIdentifier == 51', run.call_args.args[0][-1])

    def test_missing_service_has_a_finite_failure(self):
        with self.assertRaises(TimeoutError):
            ios_service_uri.wait_for_service('synthetic-simulator', 51, timeout=0)

    def test_command_failure_does_not_echo_log_payload(self):
        error = subprocess.CalledProcessError(1, ['synthetic'], output='private synthetic payload')
        output = StringIO()
        with patch.object(ios_service_uri, 'wait_for_service', side_effect=error):
            with redirect_stderr(output):
                self.assertEqual(ios_service_uri.main(['synthetic-simulator', '51']), 1)
        self.assertNotIn('private synthetic payload', output.getvalue())


if __name__ == '__main__':
    unittest.main()
