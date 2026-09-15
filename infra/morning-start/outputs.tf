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
  description = "Hourly recovery check bounded to working hours; it never starts a VM overnight."
  value = {
    name     = azurerm_automation_schedule.daytime.name
    timezone = azurerm_automation_schedule.daytime.timezone
    window   = "07:00-19:00"
    interval = "Every hour"
  }
}
output "targets" {
  description = "Only the two application VMs; not the optional DDM workstation."
  value       = local.targets
}
