output "resource_group_name" {
  description = "Resource group holding every lab resource. Delete it to stop all charges."
  value       = azurerm_resource_group.lab.name
}

output "vm_name" {
  description = "Lab VM name, used by az vm deallocate / az vm start."
  value       = azurerm_linux_virtual_machine.lab.name
}

output "public_ip" {
  description = "Public IP of the lab VM."
  value       = azurerm_public_ip.lab.ip_address
}

output "ssh_command" {
  description = "SSH entry point."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.ip_address}"
}

output "natural_development_server" {
  description = "Endpoint to register in NaturalONE as a remote development server."
  value       = "${azurerm_public_ip.lab.ip_address}:2700"
}

output "adabas_admin_url" {
  description = "Adabas REST administration endpoint."
  value       = "http://${azurerm_public_ip.lab.ip_address}:8190"
}

# The password itself is never an output. This emits the *command* to fetch it, so the value
# stays in Key Vault and never lands in `terraform output`, CI logs or the state's output map.
# That is also why no output here needs `sensitive = true`: none carries a secret value.
output "adabas_admin_password_command" {
  description = "Reads the generated Adabas administration password from Key Vault."
  value       = "az keyvault secret show --vault-name ${azurerm_key_vault.lab.name} --name adabas-admin-password --query value -o tsv"
}

output "bootstrap_log_command" {
  description = "Follows the first-boot bootstrap, including the multi-GB image pull."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.ip_address} 'sudo tail -f /var/log/sifap-bootstrap.log'"
}

# Cost figures are Azure retail (pay-as-you-go) list prices for brazilsouth, USD, checked against
# the Azure Retail Prices API on 2026-08-12. They are estimates: your agreement, reservations and
# taxes will differ. Recheck with:
#   curl -s "https://prices.azure.com/api/retail/prices?\$filter=armRegionName eq 'brazilsouth'"
output "estimated_cost_note" {
  description = "Cost reminder, including what keeps billing after the VM is stopped."
  value       = <<-EOT
    Running:     ~USD 0.20/h  (${var.vm_size} ~0.159/h + Premium SSD OS 64GB ~0.024/h + data ${var.data_disk_size_gb}GB ~0.013/h + static IP ~0.005/h)
    Deallocated: ~USD 0.04/h  (~USD 1/day, ~USD 30/month) - Premium disks and the static IP bill
                 even while the VM is stopped. 'az vm deallocate' stops ONLY the compute charge.
    Auto-shutdown runs daily at ${var.auto_shutdown_time} (${var.auto_shutdown_timezone}); it stops
    compute, it does not delete storage.
    To stop ALL charges, destroy the lab: terraform destroy (or delete the resource group).
  EOT
}
