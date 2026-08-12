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

output "adabas_admin_password_command" {
  description = "Reads the generated Adabas administration password from Key Vault."
  value       = "az keyvault secret show --vault-name ${azurerm_key_vault.lab.name} --name adabas-admin-password --query value -o tsv"
}

output "bootstrap_log_command" {
  description = "Follows the first-boot bootstrap, including the multi-GB image pull."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.ip_address} 'sudo tail -f /var/log/sifap-bootstrap.log'"
}

output "estimated_cost_note" {
  description = "Cost reminder."
  value       = "~USD 0.10/h while running (${var.vm_size} + Premium SSD + static IP). Auto-shutdown at ${var.auto_shutdown_time}. Run 'az vm deallocate' or 'terraform destroy' when finished."
}
