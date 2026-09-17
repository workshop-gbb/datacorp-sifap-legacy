mock_provider "azurerm" {
  mock_data "azurerm_automation_account" {
    defaults = {
      identity = [{
        type         = "SystemAssigned"
        principal_id = "00000000-0000-0000-0000-000000000002"
        tenant_id    = "00000000-0000-0000-0000-000000000003"
      }]
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000001"
}

run "daily_readiness_for_both_systems" {
  command = apply

  assert {
    condition = (
      azurerm_automation_schedule.morning.frequency == "Day" &&
      azurerm_automation_schedule.morning.interval == 1 &&
      azurerm_automation_schedule.morning.timezone == "America/Sao_Paulo" &&
      endswith(azurerm_automation_schedule.morning.start_time, "T06:30:00-03:00")
    )
    error_message = "Both systems must start at 06:30 Brasilia every day for 07:00 readiness."
  }

  assert {
    condition = (
      toset([for target in local.targets : target.kind]) == toset(["legacy", "modern"]) &&
      jsondecode(base64decode(azurerm_automation_job_schedule.morning.parameters["targetsbase64"])) == local.targets &&
      azurerm_automation_job_schedule.morning.parameters["mode"] == "Scheduled"
    )
    error_message = "The daily job must bind both existing application targets."
  }

  assert {
    condition = (
      toset(azurerm_role_definition.morning.permissions[0].actions) == toset([
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Compute/virtualMachines/instanceView/read",
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/runCommands/read",
        "Microsoft.Compute/virtualMachines/runCommands/write"
      ]) &&
      length(azurerm_role_assignment.targets) == 2 &&
      alltrue([for kind, assignment in azurerm_role_assignment.targets : assignment.scope == local.target_ids[kind]])
    )
    error_message = "Only VM-scoped read, start and managed readiness commands may be granted."
  }

  assert {
    condition     = azurerm_automation_runbook.morning.content == file("./morning-start.ps1")
    error_message = "The published runbook must match the tested source."
  }

  assert {
    condition = (
      length(azurerm_automation_schedule.daytime) == 4 &&
      alltrue([for s in azurerm_automation_schedule.daytime : s.frequency == "Hour" && s.interval == 1 && s.timezone == "America/Sao_Paulo"]) &&
      toset([for k, s in azurerm_automation_schedule.daytime : endswith(s.start_time, "T07:${k}:00-03:00")]) == toset([true]) &&
      alltrue([for j in azurerm_automation_job_schedule.daytime : j.parameters["mode"] == "Daytime" &&
        j.runbook_name == azurerm_automation_runbook.morning.name &&
      jsondecode(base64decode(j.parameters["targetsbase64"])) == local.targets])
    )
    error_message = "Four offset schedules must give a 15-minute working-hours recovery check covering both systems."
  }
}