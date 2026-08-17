locals {
  # Convention from .github/instructions/infrastructure.instructions.md:
  # {project}-{env}-{resource}-{region}
  name_prefix = "${var.project}-${var.environment}"

  # The region suffix is DERIVED, not a second independent variable. The old module carried
  # `location = brazilsouth` and `location_short = brs` as separate defaults, so changing one
  # and forgetting the other produced resources named for a region they were not in.
  # var.location_short still exists as an escape hatch for regions not in this map.
  location_short_map = {
    eastus2        = "eus2"
    eastus         = "eus"
    westus2        = "wus2"
    westus3        = "wus3"
    centralus      = "cus"
    southcentralus = "scus"
    brazilsouth    = "brs"
    northeurope    = "neu"
    westeurope     = "weu"
    uksouth        = "uks"
    swedencentral  = "sec"
  }

  suffix = var.location_short != "" ? var.location_short : lookup(
    local.location_short_map,
    var.location,
    substr(replace(lower(var.location), "/[^a-z0-9]/", ""), 0, 6)
  )

  # One random suffix, three jobs: it makes the Key Vault name globally unique, the public
  # DNS label unique inside the region, and the two traceably part of the same deployment.
  unique_suffix = random_string.unique.result

  # Azure rule for domain_name_label: 3-63 chars, lowercase letters, digits and hyphens,
  # must start with a letter. "sifap-lab-a1b2c3" satisfies all of it.
  dns_label = var.dns_label_prefix != "" ? var.dns_label_prefix : "${local.name_prefix}-${local.unique_suffix}"

  # Azure issues exactly this FQDN for a public IP carrying a DNS label. Computed here rather
  # than read back from the resource so cloud-init can be rendered without a dependency cycle
  # through the VM that consumes it.
  demo_fqdn = "${local.dns_label}.${var.location}.cloudapp.azure.com"

  # --- TLS mode -------------------------------------------------------------
  # Let's Encrypt validates the HTTP-01 challenge from arbitrary addresses worldwide. An
  # NSG allow-list that excludes them also excludes the challenge, so a publicly trusted
  # certificate is only possible with 80/443 reachable from the internet. That is the whole
  # reason enable_public_acme exists as an explicit, default-off opt-in instead of being
  # silently baked in. See var.enable_public_acme and README.md -> "TLS on the demo URL".
  caddy_global_options = var.enable_public_acme ? "email ${var.acme_contact_email}" : "# ACME disabled: certificates are signed by Caddy's local CA"
  caddy_tls_directive  = var.enable_public_acme ? "# tls: automatic Let's Encrypt for ${local.demo_fqdn}" : "tls internal"

  # Docker publishes container ports by punching through the host firewall, so a plain
  # "8190:8190" listens on every interface no matter what ufw thinks. Binding to loopback
  # keeps the console reachable over an SSH tunnel for debugging the proxy, while making it
  # unreachable from the network even if someone later widens the NSG by hand. Caddy is
  # unaffected: it reaches adabas-db over the Docker bridge, not the host binding.
  adabas_admin_bind = var.expose_adabas_admin_port ? "8190:8190" : "127.0.0.1:8190:8190"

  # Only 80/443 ever widen, and only when ACME is explicitly enabled. "Internet" is Azure's
  # service tag for public address space; it is narrower than 0.0.0.0/0, which would also
  # match VNet and Azure-internal sources.
  web_source_prefix   = var.enable_public_acme ? "Internet" : null
  web_source_prefixes = var.enable_public_acme ? null : var.allowed_source_cidrs

  # Azure refuses a budget that starts anywhere but the first of a month, and refuses a start
  # date in the past at creation time. Deriving it keeps the module applying cleanly next
  # quarter; ignore_changes on the budget stops the derived value churning every plan.
  budget_start_date = var.budget_start_date != "" ? var.budget_start_date : formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())

  alert_emails = var.auto_shutdown_notification_email != "" ? [var.auto_shutdown_notification_email] : []

  # Azure Key Vault rejects /31 and /32 masks in ip_rules and wants the bare address instead,
  # which is exactly the form people copy out of `curl ifconfig.me`. Normalise rather than
  # make every operator rediscover it from a 400.
  key_vault_ip_rules = [
    for c in var.key_vault_allowed_ip_rules :
    replace(trimspace(c), "/\\/32$/", "")
  ]

  tags = {
    project     = var.project
    environment = var.environment
    owner       = var.owner
    cost-center = var.cost_center
    workload    = "adabas-natural-community-edition"
    managed-by  = "terraform"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "${local.name_prefix}-rg-${local.suffix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "lab" {
  name                = "${local.name_prefix}-vnet-${local.suffix}"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

# azurerm_subnet carries no tags argument in azurerm 3.x (removed in 2.0), so the
# repo tagging rule is satisfied at the vnet level. Do not add `tags` here: it fails validate.
resource "azurerm_subnet" "lab" {
  name                 = "${local.name_prefix}-snet-runtime"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_network_security_group" "lab" {
  name                = "${local.name_prefix}-nsg-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "AllowSshFromWorkshop"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_source_cidrs
    destination_address_prefix = "*"
  }

  # Natural Development Server: this is the port NaturalONE attaches to. Raw TCP, not HTTP,
  # so it cannot be moved behind the TLS reverse proxy - it stays on the allow-list.
  security_rule {
    name                       = "AllowNaturalDevelopmentServer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2700"
    source_address_prefixes    = var.allowed_source_cidrs
    destination_address_prefix = "*"
  }

  # ADATCP. Only needed when an Adabas client runs outside the VM.
  security_rule {
    name                       = "AllowAdabasAdatcp"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "60001"
    source_address_prefixes    = var.allowed_source_cidrs
    destination_address_prefix = "*"
  }

  # --- the demo URL ---------------------------------------------------------
  # 80 exists for two reasons: Caddy's HTTP -> HTTPS redirect, and the ACME HTTP-01
  # challenge. Both terminate at Caddy; nothing is served in plaintext.
  security_rule {
    name                       = "AllowHttpRedirectAndAcme"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = local.web_source_prefix
    source_address_prefixes    = local.web_source_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpsDemo"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.web_source_prefix
    source_address_prefixes    = local.web_source_prefixes
    destination_address_prefix = "*"
  }

  # Plaintext Adabas REST administration, off by default. The console is reachable over TLS
  # at the demo URL; this direct port is a fallback for when the proxy is the broken part.
  dynamic "security_rule" {
    for_each = var.expose_adabas_admin_port ? [1] : []
    content {
      name                       = "AllowAdabasRestAdmin"
      priority                   = 130
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8190"
      source_address_prefixes    = var.allowed_source_cidrs
      destination_address_prefix = "*"
    }
  }

  # Explicit deny backstop. 4096 is the last usable priority, so it sits after every rule
  # above and before Azure's defaults (AllowVnetInBound 65000, AllowAzureLoadBalancerInBound
  # 65001, DenyAllInBound 65500). It therefore also shadows intra-vnet inbound traffic, which
  # is intended: this lab is a single VM with no peer that needs to reach it.
  security_rule {
    name                       = "DenyAllOtherInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Static + Standard so the address survives a stop/start, and a DNS label so the demo has a
# stable name instead of an IP that participants have to retype. Azure publishes
# <label>.<region>.cloudapp.azure.com for free; the label must be unique within the region,
# which is what local.unique_suffix buys.
resource "azurerm_public_ip" "lab" {
  name                = "${local.name_prefix}-pip-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = local.dns_label
  tags                = local.tags
}

resource "azurerm_network_interface" "lab" {
  name                = "${local.name_prefix}-nic-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}

# Association resources expose no tags argument; the tagged objects are the NIC and the NSG.
resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# The same NSG is bound a second time, at the subnet. Azure evaluates subnet rules before NIC
# rules on the way in, and since both point at one NSG the effective policy is unchanged - so
# this costs nothing and buys two things: anything added to this subnet later is filtered from
# the moment it exists rather than from the moment somebody remembers to attach a NIC rule,
# and a NIC rebuild cannot silently leave the VM unfiltered.
resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# ---------------------------------------------------------------------------
# Observability
#
# Wired in at provisioning time, not deferred: the failure this lab actually suffers is a
# bootstrap that dies silently on a VM nobody is watching. The workspace collects syslog
# through the Azure Monitor agent, the diagnostic settings capture Key Vault and NSG
# activity, and two alerts turn both into something that pages a human.
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${local.name_prefix}-law-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  # Cost guard: observability must not become the biggest line on a lab bill.
  daily_quota_gb = var.log_daily_quota_gb
  tags           = local.tags
}

# Who read which secret, and when. The lab holds exactly one credential, so this is small
# and genuinely readable.
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "${local.name_prefix}-diag-kv"
  target_resource_id         = azurerm_key_vault.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# NSG rule counters answer "is the allow-list actually the thing blocking me?", which is the
# single most common lab support question.
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                       = "${local.name_prefix}-diag-nsg"
  target_resource_id         = azurerm_network_security_group.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# The agent ships nothing on its own; the data collection rule below tells it what to send.
resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.lab.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.29"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

resource "azurerm_monitor_data_collection_rule" "lab" {
  name                = "${local.name_prefix}-dcr-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.lab.id
      name                  = "lab-workspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["lab-workspace"]
  }

  # bootstrap.sh calls `logger -t sifap-bootstrap`, so its success and failure markers land
  # in the user facility and become queryable - which is what the alert below depends on.
  data_sources {
    syslog {
      name           = "lab-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
      log_levels     = ["Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }
}

# Associations are links, not taggable objects; the DCR and the VM both carry local.tags.
resource "azurerm_monitor_data_collection_rule_association" "lab" {
  name                    = "${local.name_prefix}-dcra"
  target_resource_id      = azurerm_linux_virtual_machine.lab.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.lab.id

  depends_on = [azurerm_virtual_machine_extension.monitor_agent]
}

resource "azurerm_monitor_action_group" "lab" {
  name                = "${local.name_prefix}-ag-${local.suffix}"
  resource_group_name = azurerm_resource_group.lab.name
  # Azure caps short_name at 12 characters; it is what appears in the SMS/e-mail subject.
  short_name = substr("${var.project}${var.environment}", 0, 12)
  tags       = local.tags

  # An action group with no receiver is valid and still records the alert in Azure Monitor.
  # Set auto_shutdown_notification_email to actually be told about it.
  dynamic "email_receiver" {
    for_each = local.alert_emails
    content {
      name                    = "lab-owner"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# "Is the VM up?" - Azure's own platform-level heartbeat, which keeps working even when the
# guest OS or the agent is the thing that broke.
resource "azurerm_monitor_metric_alert" "vm_availability" {
  name                = "${local.name_prefix}-alert-vm-availability"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_linux_virtual_machine.lab.id]
  description         = "Lab VM is not available. Expected daily between the auto-shutdown time and the next manual start."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

# "Did first boot actually work?" - the failure mode that produced a half-applied lab in the
# first place. bootstrap.sh emits the marker to syslog; this turns it into an alert instead
# of something discovered by SSHing in an hour later.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "bootstrap_failed" {
  name                = "${local.name_prefix}-alert-bootstrap-failed"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_log_analytics_workspace.lab.id]
  description         = "cloud-init bootstrap reported FAILED on the lab VM. Read /var/log/sifap-bootstrap.log and re-run /opt/sifap/bootstrap.sh."
  severity            = 1
  tags                = local.tags

  evaluation_frequency = "PT10M"
  window_duration      = "PT30M"

  criteria {
    query                   = <<-KQL
      Syslog
      | where SyslogMessage has "SIFAP-BOOTSTRAP RESULT: FAILED"
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.lab.id]
  }
}

# ---------------------------------------------------------------------------
# Secrets
#
# Repository rule: secrets live in Key Vault, never in locals or variables.
# The Adabas administration password is generated here and read back by the VM
# at boot through its managed identity, so it never lands in Terraform inputs.
# ---------------------------------------------------------------------------

resource "random_password" "adabas_admin" {
  length      = 24
  special     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  # Adabas passes this through shell and YAML, so avoid quoting-hostile characters.
  override_special = "-_.~"
}

# Was random_string.kv_suffix. Renamed because it now also seeds the public DNS label; the
# `moved` block keeps any existing state importable without a destroy/create cycle.
resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

moved {
  from = random_string.kv_suffix
  to   = random_string.unique
}

# Key Vault posture - deliberate choices for a DISPOSABLE workshop lab, not a template for prod:
#
#   soft_delete_retention_days = 7   Azure minimum. The vault holds one generated lab password
#                                    with no recovery value; a long window only blocks name reuse.
#   purge_protection_enabled   = false  Purge protection is IRREVERSIBLE once enabled and would
#                                    keep the vault name (and its charges) alive for the full
#                                    retention window after `terraform destroy`. The documented
#                                    teardown for this lab is destroy-and-forget, so it stays off.
#                                    In any non-lab environment this MUST be true.
#   enable_rbac_authorization  = false  Access-policy model keeps the grant to the VM's managed
#                                    identity inside this state, with no dependency on the
#                                    deployer holding "User Access Administrator" to create
#                                    role assignments - a common blocker on workshop tenants.
#
# Network exposure: with var.key_vault_allowed_ip_rules empty (the default) the vault stays on
# its open public endpoint, because three parties need the data plane and only one of them has
# a predictable address - see that variable for the full reasoning. Set it to switch the
# firewall to default-Deny.
#
# ACCEPTED RISK: trivy AVD-AZU-0013 wants default_action = "Deny" on the vault firewall. The
# compensating controls are the access policies below, which grant exactly two principals
# (the deployer and the VM identity) and nothing else, on a vault holding one generated
# password with no value outside this lab. Revisit before reusing this pattern anywhere real.
#trivy:ignore:AVD-AZU-0013
resource "azurerm_key_vault" "lab" {
  name                       = "${var.project}${var.environment}kv${local.unique_suffix}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = false
  tags                       = local.tags

  # Always emitted so the firewall posture is explicit in state rather than implied by
  # absence. With an empty allow-list this behaves exactly like no block at all; populate
  # var.key_vault_allowed_ip_rules to flip it to default-Deny.
  network_acls {
    default_action = length(local.key_vault_ip_rules) > 0 ? "Deny" : "Allow"
    bypass         = "AzureServices"
    ip_rules       = local.key_vault_ip_rules
  }

  lifecycle {
    # The one resource here holding a credential. `terraform destroy` stops at this guard on
    # purpose, so tearing down the lab is a deliberate act rather than a stray command.
    # Lifting it is a documented two-step, see README.md -> "Destroy the environment".
    #
    # The VM, its disks, the public IP and the network are INTENTIONAL EXCEPTIONS: this lab
    # is disposable by design and adding the same guard there would make the documented
    # destroy-and-forget teardown impossible.
    prevent_destroy = true
  }
}

# Access policies carry no tags argument; the vault they attach to is tagged.
# Deployer policy is what lets the secret below be written; the VM policy is Get-only.
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.lab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.lab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.lab.identity[0].principal_id

  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_secret" "adabas_admin_password" {
  name         = "adabas-admin-password"
  value        = random_password.adabas_admin.result
  key_vault_id = azurerm_key_vault.lab.id
  tags         = local.tags

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

resource "azurerm_managed_disk" "adabas_data" {
  name                 = "${local.name_prefix}-disk-adabasdata"
  location             = azurerm_resource_group.lab.location
  resource_group_name  = azurerm_resource_group.lab.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = local.tags
}

# On-demand backup of the Adabas containers. Incremental, so a second snapshot of a mostly
# unchanged disk costs almost nothing. Created only when var.data_disk_snapshot_label is set,
# which makes "snapshot before I try something destructive" a one-flag apply.
resource "azurerm_snapshot" "adabas_data" {
  count = var.data_disk_snapshot_label != "" ? 1 : 0

  name                = "${local.name_prefix}-snap-adabasdata-${var.data_disk_snapshot_label}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  create_option       = "Copy"
  source_uri          = azurerm_managed_disk.adabas_data.id
  incremental_enabled = true
  tags                = local.tags
}

resource "azurerm_linux_virtual_machine" "lab" {
  name                = "${local.name_prefix}-vm-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.lab.id]

  # Password authentication stays off. SSH key only.
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = var.source_image_version
  }

  boot_diagnostics {}

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    adabas_image         = var.adabas_image
    natural_image        = var.natural_image
    caddy_image          = var.caddy_image
    adabas_dbid          = var.adabas_dbid
    key_vault_uri        = azurerm_key_vault.lab.vault_uri
    secret_name          = "adabas-admin-password"
    demo_fqdn            = local.demo_fqdn
    caddy_global_options = local.caddy_global_options
    caddy_tls_directive  = local.caddy_tls_directive
    adabas_admin_bind    = local.adabas_admin_bind
  }))

  lifecycle {
    ignore_changes = [custom_data]
  }
}

# Data disk attachment is a link, not a taggable object; the disk itself carries local.tags.
resource "azurerm_virtual_machine_data_disk_attachment" "adabas_data" {
  managed_disk_id    = azurerm_managed_disk.adabas_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.lab.id
  lun                = 0
  caching            = "None"
}

# ---------------------------------------------------------------------------
# Cost control
# ---------------------------------------------------------------------------

# Cost guard: an idle lab VM is the most common way a workshop bill escapes.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "lab" {
  virtual_machine_id    = azurerm_linux_virtual_machine.lab.id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  tags                  = local.tags

  notification_settings {
    enabled         = var.auto_shutdown_notification_email != ""
    email           = var.auto_shutdown_notification_email != "" ? var.auto_shutdown_notification_email : null
    time_in_minutes = 30
  }
}

# The shutdown schedule above hangs off the VM, so a run that dies before the VM exists -
# exactly what happened on the first brazilsouth attempt - leaves NO cost control at all.
# This budget hangs off the resource group instead, so it survives a partial apply.
#
# azurerm_consumption_budget_resource_group exposes no tags argument (it is not a tracked ARM
# resource); the tagged object is the resource group it scopes.
resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "${local.name_prefix}-budget-${local.suffix}"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.monthly_budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = local.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = local.alert_emails
    contact_roles  = ["Owner"]
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = local.alert_emails
    contact_roles  = ["Owner"]
  }

  # Forecast, not actual: at 100% of actual spend the money is already gone.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = local.alert_emails
    contact_roles  = ["Owner"]
  }

  lifecycle {
    # local.budget_start_date is derived from timestamp() when the variable is empty, which
    # would otherwise show a diff on every plan.
    ignore_changes = [time_period]
  }
}
