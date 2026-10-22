"""Evidence redaction and production request policy for the auth probe."""
from urllib.parse import urlsplit


def validate_probe_base(url):
    parsed = urlsplit(url)
    hosted = (parsed.scheme, parsed.netloc) == ('https', 'www.douglastkaiser.com')
    local = parsed.scheme == 'http' and parsed.hostname in ('localhost', '127.0.0.1')
    if not (hosted or local) or parsed.path != '/stones/' or parsed.query \
            or parsed.fragment or parsed.username or parsed.password:
        raise ValueError('Use the public Stones URL or a loopback /stones/ build')
    return url


def origin(url):
    """Discard paths, query, fragments and URL credentials."""
    parsed = urlsplit(url)
    if parsed.scheme not in ('http', 'https') or not parsed.hostname:
        return 'opaque'
    host = parsed.hostname
    if ':' in host:
        host = f'[{host}]'
    port = parsed.port
    suffix = f':{port}' if port and (parsed.scheme, port) not in (
        ('http', 80), ('https', 443)) else ''
    return f'{parsed.scheme}://{host}{suffix}'


def block_production(request):
    parsed = urlsplit(request.url)
    host = parsed.hostname or ''
    if parsed.username or parsed.password:
        return True
    if parsed.scheme == 'http' and host in ('localhost', '127.0.0.1'):
        return False
    # The hosted Firebase helper still uses public, read-only setup APIs via
    # POST. Allow generating an OAuth URL; keep identity exchanges blocked.
    if parsed.scheme == 'https' and parsed.port in (None, 443) and request.method == 'POST' and (
        (host == 'www.googleapis.com' and parsed.path in (
            '/identitytoolkit/v3/relyingparty/getProjectConfig',
            '/identitytoolkit/v3/relyingparty/createAuthUri'))
        or (host == 'identitytoolkit.googleapis.com'
            and parsed.path == '/v1/accounts:createAuthUri')
    ):
        return False
    public_config = (
        (host == 'identitytoolkit.googleapis.com' and parsed.path == '/v1/projects')
        or (host == 'www.googleapis.com' and parsed.path ==
            '/identitytoolkit/v3/relyingparty/getProjectConfig'))
    return (
        host.endswith(('google-analytics.com', 'googletagmanager.com'))
        or host in ('firestore.googleapis.com', 'securetoken.googleapis.com',
                    'firebaseappcheck.googleapis.com')
        or (host.endswith('.googleapis.com') and host != 'fonts.googleapis.com'
            and not (public_config and request.method in ('GET', 'OPTIONS')))
        or request.method not in ('GET', 'HEAD', 'OPTIONS')
    )
