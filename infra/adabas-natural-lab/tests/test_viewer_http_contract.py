"""Keep the deployed viewer probe read-only and its credentials out of argv."""

from __future__ import annotations

import os
import subprocess

from conftest import LAB

SCRIPT = LAB / "verify-viewer-access.sh"


def run_probe(**variables: str) -> subprocess.CompletedProcess[str]:
    environment = {
        key: value for key, value in os.environ.items()
        if not key.startswith("SIFAP_")
    }
    environment.update(variables)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )


def test_should_fail_before_network_when_viewer_password_is_missing():
    # REQ-112 (modern): uma verificacao sem credenciais nao pode ficar verde.
    result = run_probe()

    assert result.returncode == 2
    assert "set SIFAP_VIEWER_PASSWORD" in result.stderr
    assert "PASS" not in result.stdout


def test_should_reject_plaintext_and_credential_bearing_origins():
    # REQ-112 (modern): nunca enviar a credencial a uma URL insegura.
    for origin in (
        "http://localhost",
        "https://viewer:password@localhost",
        "https://localhost/terminal/",
        'https://localhost\nheader = "Injected: true"',
    ):
        result = run_probe(SIFAP_LAB_URL=origin)

        assert result.returncode == 2
        assert "HTTPS origin" in result.stderr


def test_should_reject_invalid_viewer_name_before_network():
    result = run_probe(SIFAP_VIEWER_USERNAME="viewer:admin")

    assert result.returncode == 2
    assert "invalid format" in result.stderr


def test_should_keep_the_probe_read_only_and_authentication_out_of_arguments():
    # REQ-104 (modern): testa limites HTTP sem executar operacoes de negocio.
    source = SCRIPT.read_text(encoding="utf-8")

    assert "curl --config -" in source
    assert "--proto '=https'" in source
    assert "--insecure" not in source
    assert "--location" not in source
    assert "--user " not in source
    assert "--data" not in source
    assert "--request" not in source
    assert "check_status viewer /admin 403" in source
    assert "check_status viewer /admin/ 403" in source
