data "azurerm_automation_account" "existing" {
  name                = var.automation_account_name
  resource_group_name = var.automation_resource_group
}

locals {
  targets = [
    {
      name          = "sifap-lab-vm-eus2"
      resourceGroup = var.automation_resource_group
      kind          = "legacy"
      origin        = "https://sifap-lab-438k30.eastus2.cloudapp.azure.com"
    },
    {
      name          = "sifap-modern-vm"
      resourceGroup = var.modern_resource_group
      kind          = "modern"
      origin        = "https://sifap-modern-fiepi9.eastus2.cloudapp.azure.com"
    }
  ]
  target_ids = {
    for target in local.targets : target.kind =>
    "/subscriptions/${var.subscription_id}/resourceGroups/${target.resourceGroup}/providers/Microsoft.Compute/virtualMachines/${target.name}"
  }
  tags = {
    project     = "sifap"
    environment = "workshop"
    owner       = var.owner
    managed-by  = "terraform"
  }
}

resource "azurerm_role_definition" "morning" {
  name        = "SIFAP Morning Start and Readiness"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Read/start and run the fixed readiness validator on the two SIFAP VMs. No stop, delete or IAM changes."
  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/runCommands/read",
      "Microsoft.Compute/virtualMachines/runCommands/write"
    ]
  }
  assignable_scopes = distinct([
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.automation_resource_group}",
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.modern_resource_group}"
  ])
}

resource "azurerm_role_assignment" "targets" {
  for_each           = local.target_ids
  scope              = each.value
  principal_id       = data.azurerm_automation_account.existing.identity[0].principal_id
  role_definition_id = azurerm_role_definition.morning.role_definition_resource_id
}

resource "azurerm_automation_runbook" "morning" {
  name                    = "Start-SifapWorkshopMorning"
  location                = var.location
  resource_group_name     = var.automation_resource_group
  automation_account_name = var.automation_account_name
  runbook_type            = "PowerShell"
  log_progress            = false
  log_verbose             = false
  description             = "Daily 06:30 Brasilia startup for 07:00 readiness of both systems; never restart at night."
  content                 = file("${path.module}/morning-start.ps1")
  tags                    = local.tags
}

resource "azurerm_automation_schedule" "morning" {
  name                    = "sifap-morning-0700"
  resource_group_name     = var.automation_resource_group
  automation_account_name = var.automation_account_name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Sao_Paulo"
  start_time              = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), "21h"))}T06:30:00-03:00"
  description             = "Every day at 06:30 Sao Paulo for both systems ready by 07:00; weekends included; MCAPS shutdown preserved."
  lifecycle {
    ignore_changes = [start_time]
  }
}

# O provider azurerm 3.x nao aceita frequencia "Minute"; quatro agendas horarias
# deslocadas entregam a mesma cadencia de 15 minutos de forma declarativa.
resource "azurerm_automation_schedule" "daytime" {
  for_each                = toset(["00", "15", "30", "45"])
  name                    = "sifap-daytime-availability-${each.key}"
  resource_group_name     = var.automation_resource_group
  automation_account_name = var.automation_account_name
  frequency               = "Hour"
  interval                = 1
  timezone                = "America/Sao_Paulo"
  start_time              = "${formatdate("YYYY-MM-DD", timeadd(timestamp(), "21h"))}T07:${each.key}:00-03:00"
  description             = "Working-hours recovery check at minute ${each.key}; the runbook only acts between 07:00 and 19:00 Sao Paulo and never starts a VM overnight."
  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "daytime" {
  for_each                = azurerm_automation_schedule.daytime
  resource_group_name     = var.automation_resource_group
  automation_account_name = var.automation_account_name
  schedule_name           = each.value.name
  runbook_name            = azurerm_automation_runbook.morning.name
  parameters = {
    subscriptionid = var.subscription_id
    targetsbase64  = base64encode(jsonencode(local.targets))
    mode           = "Daytime"
  }
  depends_on = [azurerm_role_assignment.targets]
}

resource "azurerm_automation_job_schedule" "morning" {
  resource_group_name     = var.automation_resource_group
  automation_account_name = var.automation_account_name
  schedule_name           = azurerm_automation_schedule.morning.name
  runbook_name            = azurerm_automation_runbook.morning.name
  parameters = {
    subscriptionid = var.subscription_id
    targetsbase64  = base64encode(jsonencode(local.targets))
    mode           = "Scheduled"
  }
  depends_on = [azurerm_role_assignment.targets]
}
