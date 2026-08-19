from __future__ import annotations

import json
import subprocess
import sys

import pytest

from conftest import LAB

AUDITOR = LAB / "audit-plan.py"


def run_auditor(resources: list[dict]) -> subprocess.CompletedProcess[str]:
    plan = {"planned_values": {"root_module": {"resources": resources}}}
    return subprocess.run(
        [sys.executable, str(AUDITOR)],
        input=json.dumps(plan),
        text=True,
        capture_output=True,
        check=False,
    )


def private_plan() -> list[dict]:
    return [
        {
            "address": "azurerm_key_vault.lab",
            "type": "azurerm_key_vault",
            "values": {"public_network_access_enabled": False},
        },
        {
            "address": "azurerm_private_endpoint.key_vault",
            "type": "azurerm_private_endpoint",
            "values": {},
        },
    ]


def test_should_accept_private_key_vault_plan_without_forbidden_resources():
    result = run_auditor(private_plan())

    assert result.returncode == 0
    assert "Plan policy audit: PASS" in result.stdout


@pytest.mark.parametrize(
    ("address", "resource_type"),
    [
        ("azurerm_storage_account.payload", "azurerm_storage_account"),
        ("azurerm_role_assignment.reader", "azurerm_role_assignment"),
        ("azurerm_key_vault_secret.password", "azurerm_key_vault_secret"),
    ],
)
def test_should_reject_policy_incompatible_resource_when_present(
    address: str, resource_type: str
):
    resources = private_plan()
    resources.append({"address": address, "type": resource_type, "values": {}})

    result = run_auditor(resources)

    assert result.returncode == 1
    assert address in result.stderr


def test_should_reject_key_vault_when_public_network_is_enabled():
    resources = private_plan()
    resources[0]["values"]["public_network_access_enabled"] = True

    result = run_auditor(resources)

    assert result.returncode == 1
    assert "public network access is disabled" in result.stderr


def test_should_reject_plan_when_key_vault_private_endpoint_is_missing():
    result = run_auditor(private_plan()[:1])

    assert result.returncode == 1
    assert "private endpoint" in result.stderr