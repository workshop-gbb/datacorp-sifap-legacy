output "schedule" {
  description = "The actual daily startup schedule, not an always-on watchdog."
  value = {
    name     = azurerm_automation_schedule.morning.name
    timezone = azurerm_automation_schedule.morning.timezone
    time     = "07:00"
    interval = "Every day"
  }
}
output "runbook_name" {
  description = "Runbook supporting Scheduled and non-mutating ValidateOnly modes."
  value       = azurerm_automation_runbook.morning.name
}
output "targets" {
  description = "Only the two application VMs; not the optional DDM workstation."
  value       = local.targets
}
