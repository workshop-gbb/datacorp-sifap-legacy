# SIFAP morning startup and readiness

This independent Terraform module reuses the existing
`sifap-lab-aa-watchdog-eus2` Automation account. It does **not** recreate a VM,
network, disk or database.

## Schedule

- Every day, including weekends, at **07:00 America/Sao_Paulo (Brasilia)**.
- The current equivalent is 10:00 UTC; Azure retains the named time zone.
- The runbook refuses scheduled starts outside 07:00-08:00.
- VM/application readiness has a 25-minute deadline with bounded HTTP calls.
- Already running VMs are not restarted. No nighttime keep-alive is installed.
- MCAPS shutdown policy and shutdown schedules are not changed.

The targets are the existing `sifap-lab-vm-eus2` and `sifap-modern-vm`. The optional
DDM workstation is deliberately not included.

## Validation

The legacy [guest validator](../adabas-natural-lab/provisioning/verify-startup.sh)
checks `adabas-db`, `natural-ce`, `ttyd-viewer` and `caddy`, requires real container
healthchecks, and runs the Adabas image's read-only health probe. It never invokes
the financial batch or reloads seed data.

The modern validator is owned by
[SIFAP Modern](https://github.com/workshop-gbb/datacorp-sifap-modern/blob/develop/infra/runtime/verify-startup.sh).
It checks PostgreSQL with `SELECT 1`, Spring database health and frontend health.
The existing boot service is used for startup; data volumes are preserved.

Both validators must emit `SIFAP_STARTUP_VALIDATION=OK`. The runbook also checks
the actual public HTTPS endpoints. VM running or systemd active alone is not
accepted as proof of readiness.

The on-demand `ValidateOnly` mode is safe outside the morning window: it never
starts a stopped VM and passes `--check-only` to guest validators.

## Deployment order

1. Install the two versioned guest validators on their existing VMs using an
   authenticated Azure Run Command, without passwords or inbound SSH.
2. Initialize/validate this module, review its plan and apply using protected
   Terraform state outside Git.
3. Disable obsolete `vm-watchdog-*` and `vm-daily-start-0700-brt` schedules in this
   Automation account. Keep only `sifap-morning-0700` enabled for this purpose.
   Do not touch unrelated or MCAPS schedules.
4. Validate the new managed-identity job in `ValidateOnly` mode.
5. Remove old `Virtual Machine Contributor` grants belonging to the retired
   watchdog. The new role permits only VM read, instance view, start and Run
   Command validation on the two target VM resource IDs.
6. Verify the Azure schedule's actual `nextRun`, time zone, daily recurrence,
   job binding and final successful validation job.

The older lab module preserves the Automation account but no longer creates the
obsolete watchdog schedules. This separation prevents an operational scheduling
change from accidentally replacing the live lab infrastructure.

## Tests

Existing pytest tests cover the schedule/RBAC/guest validation contracts. Run
`tests/runbook.tests.ps1` in PowerShell to verify the actual Brasilia boundary,
weekends, and duplicate target rejection. No Az PowerShell module is required;
the runbook uses managed identity and Azure Resource Manager directly.

No operator permissions, cloud credentials or application secrets are granted
or copied by the runbook. Readiness failures fail the job and are visible in the
Automation job history.
