output "resource_group_name" {
  description = "Resource group holding every lab resource. Delete it to stop all charges."
  value       = azurerm_resource_group.lab.name
}

output "vm_name" {
  description = "Lab VM name, used by az vm deallocate / az vm start."
  value       = azurerm_linux_virtual_machine.lab.name
}

# ---------------------------------------------------------------------------
# The demo endpoint
# ---------------------------------------------------------------------------

# THE link to hand an audience. Read from the public IP resource rather than rebuilt from
# parts, so it is whatever Azure actually issued.
output "demo_url" {
  description = "Public HTTPS URL for the demo. TLS terminates at the Caddy reverse proxy on the VM; the Adabas console behind it is never served in plaintext over the network."
  value       = "https://${azurerm_public_ip.lab.fqdn}"
}

output "demo_fqdn" {
  description = "DNS name Azure issued for the lab public IP. Stable across stop/start because the IP is Static/Standard."
  value       = azurerm_public_ip.lab.fqdn
}

output "admin_console_url" {
  description = "Adabas REST administration console, proxied over TLS. Same origin as demo_url; sign in as 'admin' with the password from Key Vault."
  value       = "https://${azurerm_public_ip.lab.fqdn}/"
}

output "admin_console_direct_url" {
  description = "PLAINTEXT fallback straight to the Adabas console, for when the proxy itself is the broken part. Reachable only while expose_adabas_admin_port = true, and only from allowed_source_cidrs."
  value       = var.expose_adabas_admin_port ? "http://${azurerm_public_ip.lab.ip_address}:8190" : "disabled (expose_adabas_admin_port = false; use admin_console_url instead)"
}

output "tls_mode" {
  description = "Which certificate authority signs the demo URL, and what that implies for a browser."
  value = var.enable_public_acme ? join("", [
    "Let's Encrypt (publicly trusted). Ports 80/443 are open to the Internet service tag ",
    "because ACME HTTP-01 validation arrives from arbitrary addresses. No browser warning.",
    ]) : join("", [
    "Caddy internal CA (self-signed root). Ports 80/443 are open only to allowed_source_cidrs. ",
    "The connection is encrypted, but a browser warns until you trust the root - see ",
    "trust_demo_ca_command, or set enable_public_acme = true.",
  ])
}

output "health_check_command" {
  description = "Confirms the demo URL is live. Answers as soon as Caddy holds a certificate, without waiting for Adabas to finish building the demo database."
  value       = var.enable_public_acme ? "curl -sSf https://${azurerm_public_ip.lab.fqdn}/healthz" : "curl -sSfk https://${azurerm_public_ip.lab.fqdn}/healthz   # -k: internal CA, see trust_demo_ca_command"
}

output "trust_demo_ca_command" {
  description = "Exports Caddy's internal root certificate so a browser or curl can trust the demo URL without -k. Not needed when enable_public_acme = true."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn} 'sudo docker exec caddy cat /data/caddy/pki/authorities/local/root.crt' > sifap-lab-root.crt"
}

# ---------------------------------------------------------------------------
# Direct access
# ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP of the lab VM. Prefer demo_fqdn: the name is what participants get, and it survives a rebuild that changes the address."
  value       = azurerm_public_ip.lab.ip_address
}

output "ssh_command" {
  description = "SSH entry point."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn}"
}

output "natural_development_server" {
  description = "Endpoint to register in NaturalONE as a remote development server. Raw TCP, so it does not go through the TLS proxy."
  value       = "${azurerm_public_ip.lab.fqdn}:2700"
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
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn} 'sudo tail -f /var/log/sifap-bootstrap.log'"
}

# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------

output "log_analytics_workspace_name" {
  description = "Workspace collecting VM syslog, Key Vault audit events and NSG rule counters."
  value       = azurerm_log_analytics_workspace.lab.name
}

output "bootstrap_status_query" {
  description = "KQL that answers 'did first boot succeed?' without SSH. Run it in the Log Analytics workspace; allow a few minutes for the agent's first upload."
  value       = "Syslog | where SyslogMessage has \"SIFAP-BOOTSTRAP RESULT\" | project TimeGenerated, SyslogMessage | order by TimeGenerated desc"
}

output "quota_preflight_command" {
  description = "Run this BEFORE the first apply. A vCPU quota of zero in the target region is the failure that left the previous attempt half-applied."
  value       = "az vm list-usage --location ${var.location} -o table | grep -i 'Standard DSv3'"
}

output "data_disk_snapshot_name" {
  description = "Name of the on-demand Adabas data disk snapshot, when data_disk_snapshot_label is set."
  value       = var.data_disk_snapshot_label != "" ? azurerm_snapshot.adabas_data[0].name : "none (set data_disk_snapshot_label to create one)"
}

# Cost figures are ROUNDED Azure retail (pay-as-you-go) list prices for eastus2, USD, and are
# estimates only: your agreement, reservations and taxes will differ. The authoritative guard
# is azurerm_consumption_budget_resource_group.lab, not this note. Recheck with:
#   curl -s "https://prices.azure.com/api/retail/prices?\$filter=armRegionName eq 'eastus2'"
output "estimated_cost_note" {
  description = "Cost reminder, including what keeps billing after the VM is stopped."
  value       = <<-EOT
    Running:     ~USD 0.12/h  (${var.vm_size} + Premium SSD OS 64GB + data ${var.data_disk_size_gb}GB + static IP)
    Deallocated: ~USD 0.03/h  (~USD 0.70/day) - Premium disks and the static IP bill even while
                 the VM is stopped. 'az vm deallocate' stops ONLY the compute charge.
    Also billing: Log Analytics ingestion, capped at ${var.log_daily_quota_gb} GB/day.
    Auto-shutdown runs daily at ${var.auto_shutdown_time} (${var.auto_shutdown_timezone}); it stops
    compute, it does not delete storage.
    A monthly budget of ${var.monthly_budget_amount} alerts at 50%, 80% and 100% (forecast).
    To stop ALL charges, destroy the lab: see README.md -> "Destroy the environment".
  EOT
}
