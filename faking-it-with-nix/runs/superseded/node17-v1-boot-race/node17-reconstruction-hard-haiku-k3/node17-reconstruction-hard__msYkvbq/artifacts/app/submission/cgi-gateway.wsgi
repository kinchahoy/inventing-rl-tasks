"""Per-tenant CGI gateway.

Runs inside the owning tenant's mod_wsgi daemon process (user = tenant), so
every CGI script under /home/<tenant>/public_html/cgi-bin executes with the
tenant's own uid/gid, the same identity the reference gets from suEXEC.
Scripts owned by any other uid are refused.
"""
import os
import re
import stat
import subprocess

_URL = re.compile(r'^/~([A-Za-z0-9_.-]+)/cgi-bin/(.+)$')


def _reply(start_response, status, text):
    data = text.encode('utf-8')
    start_response(status, [('Content-Type', 'text/plain; charset=utf-8'),
                            ('Content-Length', str(len(data)))])
    return [data]


def application(environ, start_response):
    url = environ.get('SCRIPT_NAME', '') + environ.get('PATH_INFO', '')
    match = _URL.match(url)
    if not match:
        return _reply(start_response, '404 Not Found', 'Not Found\n')
    user, rel = match.group(1), match.group(2)
    home = os.path.join('/home', user)
    base = os.path.join(home, 'public_html', 'cgi-bin')
    script = os.path.normpath(os.path.join(base, rel))
    if not script.startswith(base + os.sep):
        return _reply(start_response, '404 Not Found', 'Not Found\n')
    try:
        st = os.stat(script)
    except OSError:
        return _reply(start_response, '404 Not Found', 'Not Found\n')
    if not stat.S_ISREG(st.st_mode) or not os.access(script, os.X_OK):
        return _reply(start_response, '403 Forbidden', 'Forbidden\n')
    if st.st_uid != os.getuid():
        # Only the tenant that owns the script may run it.
        return _reply(start_response, '403 Forbidden', 'Forbidden\n')

    length = environ.get('CONTENT_LENGTH') or ''
    try:
        size = int(length)
    except ValueError:
        size = 0
    body_in = environ['wsgi.input'].read(size) if size > 0 else b''

    env = {
        'PATH': '/usr/local/bin:/usr/bin:/bin',
        'GATEWAY_INTERFACE': 'CGI/1.1',
        'SERVER_SOFTWARE': 'Apache',
        'SERVER_PROTOCOL': environ.get('SERVER_PROTOCOL', 'HTTP/1.1'),
        'SERVER_NAME': environ.get('SERVER_NAME', ''),
        'SERVER_PORT': environ.get('SERVER_PORT', ''),
        'REQUEST_METHOD': environ.get('REQUEST_METHOD', 'GET'),
        'REQUEST_URI': environ.get('REQUEST_URI', url),
        'SCRIPT_NAME': url,
        'PATH_INFO': '',
        'SCRIPT_FILENAME': script,
        'QUERY_STRING': environ.get('QUERY_STRING', ''),
        'REMOTE_ADDR': environ.get('REMOTE_ADDR', ''),
        'DOCUMENT_ROOT': os.path.join(home, 'public_html'),
        'CONTENT_TYPE': environ.get('CONTENT_TYPE', ''),
        'CONTENT_LENGTH': length if size > 0 else '',
    }
    if environ.get('wsgi.url_scheme') == 'https':
        env['HTTPS'] = 'on'
    for key, value in environ.items():
        if key.startswith('HTTP_') and key != 'HTTP_PROXY':
            env[key] = value

    try:
        proc = subprocess.run([script], input=body_in, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, env=env,
                              cwd=os.path.dirname(script), timeout=180)
    except subprocess.TimeoutExpired:
        return _reply(start_response, '504 Gateway Timeout', 'Gateway Timeout\n')
    except OSError:
        return _reply(start_response, '500 Internal Server Error', 'Internal Server Error\n')

    out = proc.stdout
    sep = out.find(b'\r\n\r\n')
    skip = 4
    if sep < 0:
        sep = out.find(b'\n\n')
        skip = 2
    if sep < 0:
        return _reply(start_response, '500 Internal Server Error', 'Internal Server Error\n')

    status = None
    headers = []
    for line in out[:sep].decode('latin-1').splitlines():
        if ':' not in line:
            continue
        name, _, value = line.partition(':')
        name = name.strip()
        value = value.strip()
        if name.lower() == 'status':
            status = value
        else:
            headers.append((name, value))
    if status is None:
        status = '302 Found' if any(n.lower() == 'location' for n, _ in headers) else '200 OK'
    payload = out[sep + skip:]
    start_response(status, headers + [('Content-Length', str(len(payload)))])
    return [payload]
