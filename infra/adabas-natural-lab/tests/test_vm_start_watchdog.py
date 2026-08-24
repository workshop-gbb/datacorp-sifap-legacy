"""Guard the Azure Automation VM start watchdog.

Tenant governance deallocates this lab outside the resource group, so disabling
the two DevTestLab shutdown schedules is not sufficient. The compensating
control has a narrow contract: use managed identity, read/start only the VMs
passed by Terraform, and never carry a cloud credential.
"""

from __future__ import annotations

import re

from conftest import LAB, PROVISIONING

MAIN_TF = (LAB / "main.tf").read_text(encoding="utf-8")
RUNBOOK = (PROVISIONING / "vm-start-watchdog.ps1").read_text(
    encoding="utf-8"
)


def test_should_create_four_offset_hourly_schedules() -> None:
    schedule = MAIN_TF.split(
        'resource "azurerm_automation_schedule" "vm_watchdog"',
        1,
    )[1].split(
        'resource "azurerm_automation_job_schedule" "vm_watchdog"',
        1,
    )[0]

    assert schedule.count('"leg-') == 4
    assert 'frequency               = "Hour"' in schedule
    assert "interval                = 1" in schedule
    assert "ignore_changes = [start_time]" in schedule


def test_should_use_a_system_assigned_identity_without_local_auth() -> None:
    account = MAIN_TF.split(
        'resource "azurerm_automation_account" "vm_watchdog"',
        1,
    )[1].split(
        'resource "azurerm_automation_runbook" "vm_watchdog"',
        1,
    )[0]

    assert 'type = "SystemAssigned"' in account
    assert "local_authentication_enabled  = false" in account
    assert "password" not in account.lower()
    assert "secret" not in account.lower()


def test_should_pass_vm_names_as_parameters_not_hardcode_them() -> None:
    assert "[Parameter(Mandatory = $true)]" in RUNBOOK
    assert "[string] $SubscriptionId" in RUNBOOK
    assert "[string] $ResourceGroup" in RUNBOOK
    assert "[string] $VirtualMachineNames" in RUNBOOK
    assert "sifap-lab-vm-" not in RUNBOOK
    assert "bf39c110-" not in RUNBOOK


def test_should_call_only_read_and_start_vm_operations() -> None:
    lower = RUNBOOK.lower()

    assert "instanceview?api-version=" in lower
    assert "start?api-version=" in lower
    for destructive in (
        "deallocate",
        "poweroff",
        "delete",
        "stop-azvm",
        "remove-az",
    ):
        assert destructive not in lower


def test_should_get_an_arm_token_from_managed_identity() -> None:
    assert "$env:IDENTITY_ENDPOINT" in RUNBOOK
    assert "$env:IDENTITY_HEADER" in RUNBOOK
    assert '"X-IDENTITY-HEADER" = $env:IDENTITY_HEADER' in RUNBOOK
    assert "client_secret" not in RUNBOOK.lower()
    assert "clientsecret" not in RUNBOOK.lower()


def test_should_keep_role_assignments_out_of_the_plan() -> None:
    # The policy auditor rejects role assignments in this lab. Terraform prints
    # one-time CLI commands instead, scoped to the individual VM IDs.
    assert 'resource "azurerm_role_assignment"' not in MAIN_TF
    assert "vm_start_watchdog_role_commands" in (
        LAB / "outputs.tf"
    ).read_text(encoding="utf-8")


def test_should_verify_both_vms_reach_running() -> None:
    assert '$expectedState = "PowerState/running"' in RUNBOOK
    assert "$maxAttempts = 40" in RUNBOOK
    assert "$pollSeconds = 15" in RUNBOOK
    assert re.search(r"if \(\$allRunning\) \{.*?return", RUNBOOK, re.DOTALL)
    assert "throw \"One or more SIFAP lab VMs did not reach" in RUNBOOK


def test_should_poll_when_instance_view_temporarily_has_no_power_state() -> None:
    # Azure can omit PowerState while a VM is transitioning to running. The GET
    # succeeded, so this is not an authorization or missing-resource failure.
    assert 'return "PowerState/unknown"' in RUNBOOK
