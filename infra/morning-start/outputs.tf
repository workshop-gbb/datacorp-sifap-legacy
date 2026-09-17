output "schedule" {
  description = "The actual daily startup schedule, not an always-on watchdog."
  value = {
    name     = azurerm_automation_schedule.morning.name
    timezone = azurerm_automation_schedule.morning.timezone
    time     = "06:30"
    interval = "Every day"
  }
}
output "runbook_name" {
  description = "Runbook supporting Scheduled, Daytime and non-mutating ValidateOnly modes."
  value       = azurerm_automation_runbook.morning.name
}
output "daytime_schedule" {
  description = "Recovery check every 15 minutes bounded to working hours; it never starts a VM overnight."
  value = {
    names    = sort([for schedule in azurerm_automation_schedule.daytime : schedule.name])
    timezone = "America/Sao_Paulo"
    window   = "07:00-19:00"
    interval = "Every 15 minutes"
  }
}
output "targets" {
  description = "Only the two application VMs; not the optional DDM workstation."
  value       = local.targets
}
