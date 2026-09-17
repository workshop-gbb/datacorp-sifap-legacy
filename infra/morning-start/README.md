# SIFAP morning startup and readiness

This independent Terraform module reuses the existing
`sifap-lab-aa-watchdog-eus2` Automation account. It does **not** recreate a VM,
network, disk or database.

## Schedule

- Start every day, including weekends, at **06:30 America/Sao_Paulo (Brasilia)**,
   with both applications and databases expected ready **by 07:00**.
- The current startup equivalent is 09:30 UTC; Azure retains the named time zone.
- The runbook refuses scheduled starts outside 06:30-08:00.
- Readiness has a 25-minute overall deadline and an 11-minute deadline per target.
   A failure in either environment does not prevent checking the other.
- Already running VMs are not restarted. No nighttime keep-alive is installed.
- MCAPS shutdown policy and shutdown schedules are not changed.

## Working-hours recovery

Starting both VMs at 06:30 does not keep them available all day. Guest shutdown
history (`last -x`) and Resource Health show both machines booting around 07:00
and then shutting down cleanly mid-day (for example 13:07 and 15:04 on 15 Sep
2026) without any ARM `deallocate`/`powerOff` operation, so the stop is initiated
inside the guest or by the platform, not by an operator. Both VMs run
`patchMode=AutomaticByPlatform` with no maintenance configuration, and several of
those stops follow a completed `installPatches` within 1-9 minutes.

The `sifap-daytime-availability` schedule therefore runs the same runbook every
15 minutes in `Daytime` mode. It only acts between **07:00 and 19:00
America/Sao_Paulo**: it restarts a stopped VM, then re-runs the guest and public
readiness checks. Outside that window it writes one line and exits successfully,
so the nightly MCAPS shutdown is preserved and no overnight keep-alive exists.
When a VM is already serving its public endpoints the check stops after a short
probe instead of running a guest command, which keeps job minutes low.

Patch orchestration is **not** ours to change: both VMs are already assigned to
MCAPS maintenance configurations in the governed `mcapsgov-updatemanagementcenter`
subscription. Do not create a competing configuration or remove those assignments;
moving the patch window requires the policy owner. Recovery latency is therefore
bounded by this 15-minute check rather than by preventing the reboot.

The Azure schedule retains the historical resource name `sifap-morning-0700`
to preserve its existing resource ID and job binding; its actual time is 06:30.
The Terraform `start_time` is ignored after creation to avoid daily replacements.
Changing that default alone does not migrate a deployed schedule: update the
existing Azure schedule explicitly and verify its actual `nextRun` afterwards.

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

Both validators must emit `SIFAP_STARTUP_VALIDATION=OK`. Each invocation uses the
VM's fixed `sifap-morning-readiness` managed Run Command with a unique execution
marker and expiration time, so a stale result cannot pass or replay startup later.
Readiness requires `instanceView.executionState=Succeeded`, exit code zero, and
both markers, even if the ARM provisioning operation remains pending. The runbook
also checks the actual public HTTPS endpoints. VM running or systemd active alone
is not accepted as proof of readiness.

The on-demand `ValidateOnly` mode is safe outside the morning window: it never
starts a stopped VM and passes `--check-only` to guest validators.

## Deployment order

Set `AZURE_SUBSCRIPTION_ID` explicitly before invoking the Node.js operator tools;
they never fall back to an embedded subscription. Their output buffers remain
bounded and no cloud credential is copied into a runbook.

1. Install the two versioned guest validators on their existing VMs using an
   authenticated Azure Run Command, without passwords or inbound SSH.
2. Initialize/validate this module, review its plan and apply using protected
   Terraform state outside Git.
3. Disable obsolete `vm-watchdog-*` and `vm-daily-start-0700-brt` schedules in this
   Automation account. Keep only `sifap-morning-0700` enabled for this purpose.
   Do not touch unrelated or MCAPS schedules.
4. Validate the new managed-identity job in `ValidateOnly` mode.
5. Remove old `Virtual Machine Contributor` grants belonging to the retired
   watchdog. The new role permits only VM read, instance view, start and managed
   Run Command read/write on the two target VM resource IDs. No operator grants
   or subscription-wide role assignments are added.
6. Verify the Azure schedule's actual `nextRun`, time zone, daily recurrence,
   job binding and final successful validation job.

The older lab module preserves the Automation account but no longer creates the
obsolete watchdog schedules. This separation prevents an operational scheduling
change from accidentally replacing the live lab infrastructure.

## Tests

Existing pytest tests cover the schedule/RBAC/guest validation contracts. Run
`tests/runbook.tests.ps1` in PowerShell to verify the actual Brasilia boundary,
weekends, stale-result rejection, failure isolation, and non-mutating validation.
Run `terraform test -filter=tests/availability.tftest.hcl` for the mocked schedule
and permission gates. No Az PowerShell module is required; the runbook uses
managed identity and Azure Resource Manager directly.

No operator permissions, cloud credentials or application secrets are granted
or copied by the runbook. Readiness failures fail the job and are visible in the
Automation job history.

## References

- [Azure Automation schedules](https://learn.microsoft.com/azure/automation/shared-resources/schedules)
- [Managed Run Command for Linux](https://learn.microsoft.com/azure/virtual-machines/linux/run-command-managed)
- [Terraform Automation schedule](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/automation_schedule)
