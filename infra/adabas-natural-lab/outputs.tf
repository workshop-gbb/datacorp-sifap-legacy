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
  description = "Public HTTPS URL for the demo. Opens the landing page, which links the legacy green screen and the modern app. TLS terminates at the Caddy reverse proxy on the VM; nothing behind it is served in plaintext over the network, and every route except /healthz needs the basic-auth credential."
  value       = "https://${azurerm_public_ip.lab.fqdn}/"
}

output "demo_fqdn" {
  description = "DNS name Azure issued for the lab public IP. Stable across stop/start because the IP is Static/Standard."
  value       = azurerm_public_ip.lab.fqdn
}

# One origin, four routes. They are separate outputs rather than one blob of text because a
# workshop facilitator pastes them individually into chat, and a CI job can consume them.
output "terminal_url" {
  description = "The legacy green screen: a Natural session in the browser, served by ttyd over the TLS proxy. Natural itself speaks a character protocol on 2700 that no browser can open, which is why this route exists."
  value       = "https://${azurerm_public_ip.lab.fqdn}/terminal/"
}

output "modern_app_url" {
  description = "The modern Java + Next.js application from Stage 3. The route is provisioned before the app exists, so the URL never changes later; until a container answers on var.modern_app_upstream it returns 502, which is the honest answer rather than a 404."
  value       = "https://${azurerm_public_ip.lab.fqdn}/app/"
}

output "admin_console_url" {
  description = "Adabas REST administration console, proxied over TLS behind basic auth. No longer the default route - '/' is the landing page. Sign in to the console itself as 'admin' with the password from adabas_admin_password_command."
  value       = "https://${azurerm_public_ip.lab.fqdn}/admin/"
}

output "healthz_url" {
  description = "Readiness endpoint. The ONLY route without basic auth, so uptime probes need no credential; it returns a fixed string and reveals nothing about the lab."
  value       = "https://${azurerm_public_ip.lab.fqdn}/healthz"
}

output "admin_console_direct_url" {
  description = "PLAINTEXT fallback straight to the Adabas console, for when the proxy itself is the broken part. Reachable only while expose_adabas_admin_port = true, and only from allowed_source_cidrs."
  value       = var.expose_adabas_admin_port ? "http://${azurerm_public_ip.lab.ip_address}:8190" : "disabled (expose_adabas_admin_port = false; use admin_console_url, or admin_console_tunnel_command)"
}

output "admin_console_tunnel_command" {
  description = "Second fallback for the Adabas console: an SSH tunnel to 8190, bypassing the proxy entirely. Use it if the console's own assets turn out to need a root path and the /admin/ prefix renders it half-broken. Then open http://localhost:8190/."
  value       = "ssh -L 8190:127.0.0.1:8190 ${var.admin_username}@${azurerm_public_ip.lab.fqdn}"
}

# ---------------------------------------------------------------------------
# Demo authentication
# ---------------------------------------------------------------------------

# Basic auth over TLS. Modest by design: this is a disposable workshop lab with no production
# data, and the alternative - an unauthenticated public origin serving an interactive shell
# into the database host - is not a trade worth making. The NSG still gates 80/443 unless
# enable_public_acme is on.
output "demo_basic_auth_username" {
  description = "Username for the demo URL. Every route except /healthz requires it."
  value       = var.demo_basic_auth_username
}

# Same discipline as the Adabas password: emit the COMMAND, never the value, so nothing
# secret lands in `terraform output`, in CI logs or in the state's output map.
output "demo_basic_auth_password_command" {
  description = "Reads the demo URL password from Key Vault. Returns a usable password only when Terraform generated one; if you supplied demo_basic_auth_password_hash yourself, the vault holds that hash and only you know the plaintext."
  value = local.basic_auth_generate ? join("", [
    "az keyvault secret show --vault-name ${azurerm_key_vault.lab.name} ",
    "--name ${local.basic_auth_secret_name} --query value -o tsv",
    ]) : join("", [
    "not generated: you supplied demo_basic_auth_password_hash, so only the bcrypt hash ",
    "is stored. Use the password you hashed.",
  ])
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
# Legacy provisioning
# ---------------------------------------------------------------------------

# Loading Adabas and compiling the Natural library takes far longer than cloud-init should be
# kept waiting, so it runs as a systemd unit. These three outputs are how you find out what
# happened without reading a log you have to know the path of.
output "provisioning_status_command" {
  description = "Answers where the two-phase provisioning stands. A fresh lab can be active (exited) after base only; /opt/sifap/PROVISIONED means finalize completed."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn} 'systemctl status sifap-provisioning --no-pager'"
}

output "provisioning_log_command" {
  description = "Follows the Adabas load and the Natural compile. Expect several minutes: Adabas builds its demo database on first boot before any ADALOD can succeed."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn} 'sudo tail -f /var/log/sifap-provisioning.log'"
}

output "provisioning_rerun_command" {
  description = "Re-runs auto provisioning. Use it after fixing a failure, after an apply that changed the corpus, or after creating the DDMs in NaturalONE."
  value = join(" && ", [
    "ssh ${var.admin_username}@${azurerm_public_ip.lab.fqdn} 'sudo /opt/sifap/fetch-payload.sh",
    "sudo systemctl restart sifap-provisioning'",
  ])
}

output "provisioning_status_query" {
  description = "KQL twin of provisioning_status_command, for when SSH is not available. Same syslog marker the failure alert watches."
  value       = "Syslog | where SyslogMessage has \"SIFAP-PROVISIONING RESULT\" | project TimeGenerated, SyslogMessage | order by TimeGenerated desc"
}

output "payload_storage_account_name" {
  description = "Storage account holding the staged legacy corpus and provisioning scripts. The VM reads it with its managed identity; there is no key, no SAS and no anonymous access. Useful for checking what actually got uploaded: az storage blob list --auth-mode login --account-name <this> -c sifap-payload -o table"
  value       = azurerm_storage_account.payload.name
}

output "payload_file_count" {
  description = "How many files Terraform staged for the VM, split between the frozen legacy corpus and the provisioning scripts. A provisioning count of 0 means infra/adabas-natural-lab/provisioning/ was empty at apply time and nothing will load the legacy - see README.md."
  value = join("", [
    "${length(local.corpus_files)} corpus files, ",
    "${length(local.provisioning_files)} provisioning files",
    length(local.provisioning_files) == 0 ? " (WARNING: no provisioning scripts staged)" : "",
  ])
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
