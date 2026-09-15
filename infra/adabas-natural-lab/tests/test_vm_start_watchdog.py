"""Regression gates for morning-only startup, replacing the always-on watchdog."""
from __future__ import annotations

from conftest import LAB

AUTOMATION = LAB.parent / "morning-start"
MAIN = (AUTOMATION / "main.tf").read_text(encoding="utf-8")
RUNBOOK = (AUTOMATION / "morning-start.ps1").read_text(encoding="utf-8")
VALIDATOR = (LAB / "provisioning" /
             "verify-startup.sh").read_text(encoding="utf-8")


def test_should_start_daily_before_seven_brasilia_instead_of_hourly():
    # REQ-113 (modern): todos os dias, respeitando o desligamento noturno.
    assert 'frequency               = "Day"' in MAIN
    assert 'timezone                = "America/Sao_Paulo"' in MAIN
    assert "T06:30:00-03:00" in MAIN
    # O unico agendamento horario aceito e o de horario comercial (REQ-117).
    assert MAIN.count('frequency               = "Hour"') == 1
    assert 'mode           = "Daytime"' in MAIN
    assert '$local.Hour -ge 7 -and $local.Hour -lt 19' in RUNBOOK
    assert 'resource "azurerm_automation_schedule"' not in (
        LAB / "main.tf").read_text()


def test_should_recover_both_systems_during_working_hours_only():
    # REQ-117: uma parada no meio do dia nao pode durar ate o dia seguinte.
    assert 'name                    = "sifap-daytime-availability"' in MAIN
    assert 'mode           = "Daytime"' in MAIN
    assert '$local.Hour -ge 7 -and $local.Hour -lt 19' in RUNBOOK
    assert 'if ($Mode -eq "Daytime")' in RUNBOOK
    assert "the nightly shutdown is preserved" in RUNBOOK


def test_should_target_only_the_two_application_vms():
    assert 'name          = "sifap-lab-vm-eus2"' in MAIN
    assert 'name          = "sifap-modern-vm"' in MAIN
    assert "ddmws" not in MAIN
    assert 'if ($targets.Count -ne 2)' in RUNBOOK
    assert "Duplicate target kind" in RUNBOOK


def test_should_gate_starts_and_bound_every_operation():
    # REQ-113: uma execucao atrasada nunca religa as VMs a noite.
    assert '$local.Hour -eq 7' in RUNBOOK
    assert '$local.Hour -eq 6 -and $local.Minute -ge 30' in RUNBOOK
    assert '$Mode -eq "Scheduled" -and -not (Test-MorningWindow)' in RUNBOOK
    assert "AddMinutes(25)" in RUNBOOK
    assert "AddMinutes(11)" in RUNBOOK
    assert "TimeoutSec = 45" in RUNBOOK
    assert "timeout 600 bash" in RUNBOOK
    assert "test `$(date +%s) -lt $expires" in RUNBOOK
    assert 'Mode -eq "ValidateOnly"' in RUNBOOK


def test_should_use_managed_identity_and_minimal_scoped_actions():
    assert "$env:IDENTITY_ENDPOINT" in RUNBOOK
    assert "$env:IDENTITY_HEADER" in RUNBOOK
    assert "client_secret" not in RUNBOOK
    for action in (
        "start/action", "instanceView/read", "runCommands/read",
        "runCommands/write",
    ):
        assert action in MAIN
    for action in (
        "/delete", "/powerOff", "/deallocate", "Virtual Machine Contributor",
    ):
        assert action not in MAIN
    assert 'scope              = each.value' in MAIN


def test_should_require_application_and_database_readiness():
    # REQ-114: VM running ou um systemd active nao bastam.
    assert "SIFAP_STARTUP_VALIDATION=OK" in RUNBOOK
    assert "SIFAP_VALIDATION_ID" in RUNBOOK
    assert (
        '$view.executionState -ne "Succeeded" -or $view.exitCode -ne 0'
        in RUNBOOK
    )
    assert "/actuator/health" in RUNBOOK
    assert "Invoke-Validation $target" in RUNBOOK
    assert "adabas-db natural-ce ttyd-viewer caddy" in VALIDATOR
    assert "sifap-viewer-access" in VALIDATOR
    assert "/usr/local/bin/healthcheck.sh" in VALIDATOR
    assert '[[ "$health" == missing ]]' in VALIDATOR


def test_should_never_reseed_or_run_financial_batches_during_validation():
    assert "BATCHPGT" not in VALIDATOR
    assert "01-load" not in VALIDATOR
    assert "docker start" in VALIDATOR
    assert "--check-only" in VALIDATOR
    assert "docker rm" not in VALIDATOR
    assert "docker compose down" not in VALIDATOR
