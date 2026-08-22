"""Guard the values this tenant's platform applies to the deployed lab.

Azure does not accept every attribute this configuration asks for. It
rewrites disk SKUs to Standard_LRS, creates subnets with default outbound
access off, and enrolls both VMs in Azure Update Manager.

Declaring the "nicer" value does not produce it. It only makes the next
plan force-replace the subnets, which cascades into destroying both VMs
and the attachment of the disk holding the Adabas database.

A plan that reads "0 to destroy" is therefore a correctness property of
main.tf, not a preference. These tests fail the moment someone restores a
value the platform will override.
"""

from __future__ import annotations

import re

from conftest import LAB

MAIN_TF = (LAB / "main.tf").read_text(encoding="utf-8")


def test_should_not_declare_premium_disks() -> None:
    # Assignments only. The surrounding comments name Premium_LRS to
    # explain why it must not be requested.
    pattern = r'storage_account_type\s*=\s*"(\w+)"'
    declared = re.findall(pattern, MAIN_TF)

    assert declared, "No storage_account_type assignment found in main.tf."
    assert set(declared) == {"Standard_LRS"}, (
        "Azure applies Standard_LRS in this tenant. Declaring Premium_LRS "
        "force-replaces both VMs on the next apply and destroys the "
        f"attachment of the Adabas data disk. Got: {declared}"
    )


def test_should_declare_subnets_without_default_outbound() -> None:
    pattern = r"default_outbound_access_enabled\s*=\s*(\w+)"
    declared = re.findall(pattern, MAIN_TF)

    assert declared == ["false", "false"], (
        "Both subnets must declare default_outbound_access_enabled = "
        "false. Azure created them that way, so letting the value drift "
        f"to the provider default force-replaces them. Got: {declared}"
    )


def test_should_adopt_update_manager_patch_mode() -> None:
    mode = re.findall(r'patch_mode\s*=\s*"AutomaticByPlatform"', MAIN_TF)
    assessment = re.findall(
        r'patch_assessment_mode\s*=\s*"AutomaticByPlatform"', MAIN_TF
    )

    assert len(mode) == 2, mode
    assert len(assessment) == 2, assessment


def test_should_give_the_workstation_an_outbound_path() -> None:
    # No public IP plus no default outbound access means no internet at
    # all, and the workstation exists only to download and run the
    # NaturalONE installer that creates the DDMs.
    assert 'resource "azurerm_nat_gateway" "workstation"' in MAIN_TF
    assert (
        'resource "azurerm_subnet_nat_gateway_association" "workstation"'
        in MAIN_TF
    )


def test_should_keep_the_nat_address_off_the_nic() -> None:
    # A NAT gateway is outbound-only. Binding a public IP to the NIC
    # instead would expose RDP, which this tenant strips anyway and which
    # audit-plan.py rejects.
    assert 'resource "azurerm_public_ip" "workstation"' not in MAIN_TF
    assert 'resource "azurerm_public_ip" "workstation_nat"' in MAIN_TF


def test_should_let_both_shutdown_schedules_be_switched_off() -> None:
    # A lab whose URL is handed out in advance has to stay reachable, and
    # both VMs have to make that choice together: shutting only one down
    # leaves the pair half-running, which reads as a broken lab rather
    # than a paused one.
    declared = re.findall(r"^\s*enabled\s*=\s*(.+)$", MAIN_TF, re.MULTILINE)
    schedule_flags = [d for d in declared if "auto_shutdown_enabled" in d]

    assert len(schedule_flags) == 4, (
        "Both shutdown schedules must read var.auto_shutdown_enabled for "
        "the schedule itself and for its notification, so the lab and the "
        f"workstation can be kept up together. Got: {schedule_flags}"
    )
    assert "enabled               = true" not in MAIN_TF, (
        "A hardcoded enabled = true pins the shutdown schedule on and "
        "silently deallocates a lab that is meant to stay reachable."
    )
