"""Contract for the opt-in public landing, not the privileged Natural shell."""
from conftest import LAB

ACCESS = LAB / "provisioning" / "viewer-access"


def test_should_send_guest_terminal_only_to_the_restricted_upstream():
    # REQ-118: a sessao guest nunca escolhe o terminal administrativo.
    caddy = (ACCESS / "Caddyfile").read_text()
    guest = caddy.split("forward_auth viewer-access:8082", 1)[1].split("@admin", 1)[0]
    assert "uri /auth/check" in guest
    assert "reverse_proxy ttyd-viewer:7681" in guest
    assert "reverse_proxy ttyd:7681" not in guest
    assert "stream_timeout 1h" in guest
    assert 'respond "Viewer access cannot administer Adabas." 403' in caddy


def test_should_keep_session_gateway_isolated_and_unprivileged():
    # REQ-117 REQ-118: sem senha, socket Docker ou acesso ao banco no gateway.
    compose = (ACCESS / "compose.viewer.yaml").read_text().split("  caddy:", 1)[0]
    for prohibited in ("docker.sock", "password", "HASH", "ports:", "/data"):
        assert prohibited not in compose
    assert "read_only: true" in compose
    assert "cap_drop: [ALL]" in compose
    assert "USER node" in (ACCESS / "Dockerfile").read_text()


def test_should_ship_a_public_local_asset_landing():
    # REQ-116: nao apresenta um login de senha ou figura como terminal real.
    index = (LAB / "payload-static" / "www" / "index.html").read_text()
    assert 'lang="pt-BR"' in index
    assert 'method="post" action="/auth/viewer"' in index
    assert "Ilustração não interativa" in index
    assert 'href="/en/"' in index and 'href="/es/"' in index
    assert "type=\"password\"" not in index
    for path in ("landing.css", "landing.js", "favicon.svg"):
        assert (LAB / "payload-static" / "www" / path).is_file()
