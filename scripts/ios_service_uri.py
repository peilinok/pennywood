#!/usr/bin/env python3
"""Read an authenticated VM URI from the newly launched simulator process."""
import json
import re
import subprocess
import sys
import time
from urllib.parse import urlsplit


def parse_service_uri(records, pid):
    for record in records:
        if not isinstance(record, dict) or record.get('processID') != pid:
            continue
        message = record.get('eventMessage', '')
        if not isinstance(message, str):
            continue
        match = re.search(r'Dart VM [Ss]ervice is listening on (http://\S+)', message)
        if not match:
            continue
        uri = match.group(1)
        try:
            parsed = urlsplit(uri)
            if (parsed.hostname in {'127.0.0.1', '::1'} and parsed.port
                    and parsed.username is None and parsed.password is None
                    and not parsed.query and not parsed.fragment
                    and re.fullmatch(r'/[A-Za-z0-9_-]+={0,2}/', parsed.path)):
                return uri
        except ValueError:
            continue
    return None


def wait_for_service(simulator, pid, timeout=120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = subprocess.run(
            ['xcrun', 'simctl', 'spawn', simulator, 'log', 'show', '--last', '2m',
             '--style', 'json', '--info', '--debug', '--predicate',
             f'processIdentifier == {pid} AND eventMessage CONTAINS "Dart VM"'],
            check=True, capture_output=True, text=True, timeout=20)
        records = json.loads(result.stdout)
        if not isinstance(records, list):
            raise ValueError('Unexpected simulator log format')
        uri = parse_service_uri(records, pid)
        if uri:
            return uri
        time.sleep(1)
    raise TimeoutError('Simulator VM service discovery timed out')


def main(args=None):
    args = sys.argv[1:] if args is None else args
    try:
        if len(args) != 2 or int(args[1]) <= 0:
            raise ValueError('Expected simulator and positive process ID')
        print(wait_for_service(args[0], int(args[1])))
        return 0
    except (ValueError, OSError, TimeoutError, subprocess.SubprocessError):
        # Logs and authenticated VM addresses stay private on failure.
        print('Cannot discover the launched process authenticated loopback VM service.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
