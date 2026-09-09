"""Contract for the opt-in public landing, not the privileged Natural shell."""
from conftest import LAB

ACCESS = LAB / "provisioning" / "viewer-access"


def test_should_route_only_the_authenticated_server_role():
    # REQ-122: o cabecalho do cliente e removido antes da decisao de perfil.
    caddy = (ACCESS / "Caddyfile").read_text()
    terminal = caddy.split("handle /terminal*", 1)[1].split("handle /admin*", 1)[0]
    assert "request_header -X-Sifap-Role" in terminal
    assert "uri /auth/check" in terminal
    assert "copy_headers X-Sifap-Role" in terminal
    assert "@admin header X-Sifap-Role ADMIN" in terminal
    assert "reverse_proxy ttyd-viewer:7681" in terminal
    assert "reverse_proxy ttyd:7681" in terminal
    assert "stream_timeout 1h" in terminal
    assert "uri /auth/check-admin" in caddy


def test_should_keep_session_gateway_isolated_and_unprivileged():
    # REQ-121 REQ-122: hashes, sem plaintext, socket Docker ou acesso ao banco.
    compose = (ACCESS / "compose.viewer.yaml").read_text().split("  caddy:", 1)[0]
    for prohibited in ("docker.sock", "PASSWORD:", "ports:", "/data", "DB_"):
        assert prohibited not in compose
    assert "PASSWORD_HASH" in compose
    assert "read_only: true" in compose
    assert "cap_drop: [ALL]" in compose
    assert "USER node" in (ACCESS / "Dockerfile").read_text()


def test_should_ship_a_public_local_asset_landing():
    # REQ-116 REQ-121: formulario credenciado e ilustracao explicitamente estatica.
    index = (LAB / "payload-static" / "www" / "index.html").read_text()
    assert 'lang="pt-BR"' in index
    assert 'method="post" action="/auth/login"' in index
    assert 'name="role"' not in index
    assert 'type="password"' in index
    assert "Ilustração não interativa" in index
    assert 'href="/en/"' in index and 'href="/es/"' in index
    assert "/auth/viewer" not in index
    for path in ("landing.css", "landing.js", "favicon.svg"):
        assert (LAB / "payload-static" / "www" / path).is_file()


def test_should_reap_the_restricted_natural_process_on_disconnect():
    # REQ-124: a vaga limitada do buffer pool nao fica presa apos fechar a aba.
    session = (ACCESS / "viewer-session.sh").read_text()
    assert "trap 'cleanup; exit 0' EXIT HUP INT TERM" in session
    assert "MARKER=" in session
    assert "kill -TERM" in session
    assert "kill -KILL" in session
    assert "cleanup_previous" in session
    assert "natural*VIEWBENF*" in session
    assert "timeout 3300" in session
    assert "VIEWBENF;FIN" in session
    assert "/bin/bash" not in session
    assert "--max-clients=1" in (ACCESS / "compose.viewer.yaml").read_text()


def test_should_reap_only_previous_administrator_sessions_before_login():
    # REQ-124: o próximo login admin não herda uma vaga órfã do buffer pool.
    session = (ACCESS / "admin-session.sh").read_text()
    assert "natural*VIEWBENF*" in session
    assert "natural*) kill -TERM" in session
    assert "natural*) kill -KILL" in session
    assert "timeout 3300" in session
    assert "/usr/local/bin/sifap-session" in session
    compose = (ACCESS / "compose.viewer.yaml").read_text()
    assert "--max-clients=1" in compose
    assert "sifap-admin-session" in compose


def test_should_derive_account_hashes_from_existing_key_vault_secrets():
    seed = (ACCESS / "seed-accounts.sh").read_text()
    assert "demo-basic-auth-password" in seed
    assert "demo-viewer-password" in seed
    assert "hash-password.mjs" in seed
    assert "workshop-accounts.env" in seed
    assert "PASSWORD='" not in seed
    assert "chmod 0600" in seed
