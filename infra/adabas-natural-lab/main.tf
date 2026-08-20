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
  # A bare "email" with no address is a Caddy syntax error, and acme_contact_email defaults
  # to empty, so the address is emitted only when there is one. Let's Encrypt registers
  # without a contact; the only thing lost is the expiry reminder.
  caddy_global_options = var.enable_public_acme ? (
    var.acme_contact_email != "" ? "email ${var.acme_contact_email}" : "# ACME enabled with no contact address"
  ) : "# ACME disabled: certificates are signed by Caddy's local CA"
  caddy_tls_directive = var.enable_public_acme ? "# tls: automatic Let's Encrypt for ${local.demo_fqdn}" : "tls internal"

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

  # The DDM workstation gets its own subnet rather than sharing the lab's, so the rule that
  # opens the Natural Development Server to it names a network instead of a host address
  # that does not exist until the VM does.
  workstation_subnet_cidr = "10.42.2.0/24"

  # --- the legacy payload ---------------------------------------------------
  # Two things have to reach the VM before the lab is anything more than an empty database:
  # the frozen SIFAP sources, and the scripts that load and compile them.
  #
  # They cannot ride in cloud-init. Azure caps custom_data at 65535 bytes and the corpus
  # alone is 77 KB once base64-encoded (256 KB raw, 57 KB gzipped) - measured, not estimated.
  # deploy-local.sh packages these files with a SHA-256 manifest and uploads the archive over
  # the same allow-listed SSH path used for operations. This also complies with the tenant
  # policy that forces Storage publicNetworkAccess=Disabled.
  corpus_source_dirs = {
    "natural-programs" = "${path.module}/${var.legacy_corpus_path}/natural-programs"
    "adabas-ddms"      = "${path.module}/${var.legacy_corpus_path}/adabas-ddms"
  }

  # Archive path -> local file. The path is also the location under /opt/sifap/payload on the
  # VM, so Terraform outputs and deploy-local.sh share one inventory contract.
  corpus_files = merge([
    for target, dir in local.corpus_source_dirs : {
      for f in fileset(dir, "**") : "corpus/${target}/${f}" => "${dir}/${f}"
    }
  ]...)

  # Owned by sibling work in progress: provisioning/ holds run-all.sh and the 01/02/03 steps
  # that create the Adabas file, import the DDMs and compile the Natural library. fileset()
  # on a directory that does not exist returns an empty set rather than failing, which is
  # what lets this module be applied before those scripts land - the VM then reports
  # "provisioning scripts are missing" instead of silently doing nothing.
  provisioning_dir = "${path.module}/provisioning"

  # Scratch directories are excluded so a developer who ran the scripts locally does not upload
  # their leftovers on the next apply - and so the manifest stays a description of the SOURCE,
  # not of someone's box. work/ is created by lib.sh at runtime for CMPRINT output and ADACMP
  # temporaries; ngd-work/ and ddm-work/ are DDM-forging benches; __pycache__/ is interpreter
  # spill. All of them are reproducible, none of them belong on the VM.
  provisioning_scratch_prefixes = ["work/", "ngd-work/", "ddm-work/", "__pycache__/"]

  provisioning_files = {
    for f in fileset(local.provisioning_dir, "**") :
    "provisioning/${f}" => "${local.provisioning_dir}/${f}"
    if length([for p in local.provisioning_scratch_prefixes : true if startswith(f, p)]) == 0
    && !strcontains(f, "/__pycache__/")
  }

  # --- demo origin authentication -------------------------------------------
  # Two supported shapes, one code path on the VM: Key Vault holds either the generated
  # plaintext password (default - the VM bcrypts it locally at boot) or an operator-supplied
  # bcrypt hash (used as-is). Neither ever reaches cloud-init; the VM only learns WHICH
  # secret to read and how to treat it.
  #
  # nonsensitive() is deliberate and narrow. var.demo_basic_auth_password_hash is sensitive,
  # so anything derived from it inherits that mark - including this boolean, which would then
  # taint the secret NAME and the "which command fetches the password" output and force them
  # to be hidden. What leaks here is only "did the operator supply their own hash?", which is
  # visible from the plan anyway. The hash itself is never unwrapped.
  basic_auth_generate    = nonsensitive(var.demo_basic_auth_password_hash == "")
  basic_auth_secret_name = local.basic_auth_generate ? "demo-basic-auth-password" : "demo-basic-auth-hash"
  basic_auth_secret_kind = local.basic_auth_generate ? "password" : "hash"

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

  # Azure retired default outbound access for new deployments, so subnets are created with it
  # off while the provider still defaults to true. Setting it explicitly keeps plans clean:
  # letting it drift to true force-replaces the subnet and cascades into destroying both VMs.
  # The lab VM keeps outbound through its own public IP, so nothing here depends on it.
  default_outbound_access_enabled = false

  # The Key Vault endpoint lives in this subnet. Disable endpoint policies so the vault's
  # private NIC is governed by Private Link rather than the VM's deny-all NSG.
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_network_security_group" "lab" {
  name                = "${local.name_prefix}-nsg-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "AllowSshFromVirtualNetwork"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
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

  # The NaturalONE workstation reaches the Natural Development Server over the VNet, never
  # over the public IP: its egress address is its own and would not be in
  # allowed_source_cidrs anyway. Without this rule DenyAllOtherInbound below shadows it.
  dynamic "security_rule" {
    for_each = var.enable_ddm_workstation ? [1] : []
    content {
      name                       = "AllowNaturalDevelopmentServerFromWorkstation"
      priority                   = 111
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2700"
      source_address_prefix      = local.workstation_subnet_cidr
      destination_address_prefix = "*"
    }
  }

  # Explicit deny backstop. 4096 is the last usable priority, so it sits after every rule
  # above and before Azure's defaults (AllowVnetInBound 65000, AllowAzureLoadBalancerInBound
  # 65001, DenyAllInBound 65500). It therefore also shadows intra-vnet inbound traffic, which
  # is intended: the only peer that may exist is the optional DDM workstation, and it is
  # allowed explicitly above rather than by a blanket VNet rule.
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
  ip_tags = {
    FirstPartyUsage = "/Unprivileged"
  }
  tags = local.tags
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

# "Did the legacy actually load?" - the second half of the same question. Loading Adabas and
# compiling the Natural library happens in a systemd unit AFTER cloud-init has finished, so a
# green bootstrap says nothing about whether CONSBENF compiles. run-provisioning.sh emits its
# own marker; this turns a failed load into an alert instead of a discovery made live, in
# front of an audience.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "provisioning_failed" {
  name                = "${local.name_prefix}-alert-provisioning-failed"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_log_analytics_workspace.lab.id]
  description         = "SIFAP legacy provisioning (Adabas load + Natural compile) reported FAILED. Read /var/log/sifap-provisioning.log and re-run: sudo systemctl restart sifap-provisioning."
  severity            = 1
  tags                = local.tags

  evaluation_frequency = "PT10M"
  window_duration      = "PT30M"

  criteria {
    query                   = <<-KQL
      Syslog
      | where SyslogMessage has "SIFAP-PROVISIONING RESULT: FAILED"
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
#   enable_rbac_authorization  = false  Access-policy model grants only the VM identity Get/Set
#                                    and avoids role-assignment privileges in workshop tenants.
#
# The corporate management-group policy forces publicNetworkAccess=Disabled. The explicit
# private endpoint and DNS zone below make that policy part of the design instead of allowing
# it to mutate the vault after apply and strand the bootstrap.
resource "azurerm_key_vault" "lab" {
  name                          = "${var.project}${var.environment}kv${local.unique_suffix}"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  enable_rbac_authorization     = false
  public_network_access_enabled = false
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
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

# Access policies carry no tags argument; the vault they attach to is tagged. The VM writes
# generated secrets once through a protected VM Extension, then reads them during bootstrap.
resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.lab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.lab.identity[0].principal_id

  secret_permissions = ["Get", "Set"]
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${local.name_prefix}-link-keyvault"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.lab.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "${local.name_prefix}-pe-keyvault"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.lab.id
  tags                = local.tags

  private_service_connection {
    name                           = "${local.name_prefix}-psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.lab.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "random_password" "demo_basic_auth" {
  count = local.basic_auth_generate ? 1 : 0

  length  = 24
  special = false
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

# Standard_LRS, not Premium_LRS. This tenant rewrites the disk SKU at create time -- the same
# class of platform mutation that adds ipTags to public IPs and strips public NSG rules.
# Declaring Premium here does not produce a Premium disk; it only makes every later plan try to
# force-replace the VMs that use these disks, which destroys the lab. Adopt what Azure applies.
resource "azurerm_managed_disk" "adabas_data" {
  name                          = "${local.name_prefix}-disk-adabasdata"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  storage_account_type          = "Standard_LRS"
  create_option                 = "Empty"
  disk_size_gb                  = var.data_disk_size_gb
  network_access_policy         = "DenyAll"
  public_network_access_enabled = false
  tags                          = local.tags
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

  # The tenant enrolls VMs in Azure Update Manager, so these are the values Azure applies.
  # Leaving them at the provider defaults makes every plan try to revert them, which both
  # produces permanent drift and would switch automatic patching off. Adopt, do not fight.
  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  identity {
    type = "SystemAssigned"
  }

  # See the note on azurerm_managed_disk.adabas_data: the platform applies Standard_LRS.
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
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
    ttyd_image           = var.ttyd_image
    docker_cli_image     = var.docker_cli_image
    adabas_dbid          = var.adabas_dbid
    key_vault_uri        = azurerm_key_vault.lab.vault_uri
    secret_name          = "adabas-admin-password"
    demo_fqdn            = local.demo_fqdn
    caddy_global_options = local.caddy_global_options
    caddy_tls_directive  = local.caddy_tls_directive
    adabas_admin_bind    = local.adabas_admin_bind

    # WHICH secret to read and how to treat it - never the secret itself.
    basic_auth_username    = var.demo_basic_auth_username
    basic_auth_secret_name = local.basic_auth_secret_name
    basic_auth_secret_kind = local.basic_auth_secret_kind

    modern_app_upstream      = var.modern_app_upstream
    terminal_natural_command = var.terminal_natural_command
  }))

  lifecycle {
    ignore_changes = [custom_data]
  }
}

# Terraform cannot reach this tenant's private-only Key Vault data plane. The VM can: its
# managed identity has Get/Set through the access policy above and resolves the vault through
# the private DNS zone. protected_settings encrypts this command to the guest; no credential
# enters custom_data, an ARM property readable by every process on the VM.
resource "azurerm_virtual_machine_extension" "seed_key_vault" {
  name                       = "seed-private-key-vault"
  virtual_machine_id         = azurerm_linux_virtual_machine.lab.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  protected_settings = jsonencode({
    commandToExecute = join(" ", [
      "printf '%s'",
      base64encode(<<-SCRIPT
        #!/usr/bin/env bash
        set -euo pipefail

        mkdir -p /opt/sifap
        for attempt in $(seq 1 120); do
          command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 && break
          echo "waiting for cloud-init packages (attempt $attempt/120)"
          sleep 5
        done
        command -v curl >/dev/null 2>&1 || { echo "curl unavailable" >&2; exit 1; }
        command -v python3 >/dev/null 2>&1 || { echo "python3 unavailable" >&2; exit 1; }

        write_secret() {
          local name="$1" encoded="$2" attempt token body status
          body="$(python3 - "$encoded" <<'PY'
        import base64
        import json
        import sys
        print(json.dumps({"value": base64.b64decode(sys.argv[1]).decode("utf-8")}))
        PY
          )"
          for attempt in $(seq 1 60); do
            token="$(curl -s -H 'Metadata:true' \
              'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' \
              | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token", ""))' 2>/dev/null || true)"
            if [ -n "$token" ]; then
              status="$(curl -sS -o /tmp/sifap-key-vault-response -w '%%{http_code}' \
                -X PUT -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
                --data "$body" "${azurerm_key_vault.lab.vault_uri}secrets/$name?api-version=7.4" || true)"
              if [ "$status" = "200" ]; then
                echo "seeded Key Vault secret: $name"
                return 0
              fi
            fi
            echo "Key Vault not ready for $name (attempt $attempt/60, status=$${status:-none})"
            sleep 5
          done
          cat /tmp/sifap-key-vault-response >&2 2>/dev/null || true
          return 1
        }

        write_secret "adabas-admin-password" "${base64encode(random_password.adabas_admin.result)}"
        write_secret "${local.basic_auth_secret_name}" "${base64encode(local.basic_auth_generate ? random_password.demo_basic_auth[0].result : var.demo_basic_auth_password_hash)}"
        if [ -n "${var.enable_ddm_workstation ? base64encode(random_password.workstation_admin[0].result) : ""}" ]; then
          write_secret "ddm-workstation-password" "${var.enable_ddm_workstation ? base64encode(random_password.workstation_admin[0].result) : ""}"
        fi
        touch /opt/sifap/SECRETS-READY
      SCRIPT
      ),
      "| base64 -d | bash",
    ])
  })

  depends_on = [
    azurerm_key_vault_access_policy.vm,
    azurerm_private_endpoint.key_vault,
    azurerm_private_dns_zone_virtual_network_link.key_vault,
  ]
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

# ---------------------------------------------------------------------------
# DDM workstation (optional)
#
# The one manual step in this deployment is creating four DDMs, and Natural CE cannot do it:
# the image carries no SYSDDM objects, no DDM utility and not a single sample .NGD. Software
# AG's supported answer is NaturalONE, which attaches to the Natural Development Server on
# port 2700 - and ships for Windows, not macOS or arm64.
#
# So the workstation lives here instead of on someone's laptop. It is needed once: after the
# DDMs exist, the FUSER and its DDM archive live on the managed data disk, so this whole
# section can be turned off and destroyed.
# ---------------------------------------------------------------------------

resource "azurerm_subnet" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                 = "${local.name_prefix}-snet-workstation"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [local.workstation_subnet_cidr]

  # Same reason as the runtime subnet. The workstation deliberately has no public IP, so the
  # NAT gateway below is its only outbound path.
  default_outbound_access_enabled = false
}

# Without this the workstation has no route to the internet at all: no public IP, and Azure no
# longer grants default outbound access. Its one job is downloading the NaturalONE installer,
# so that would make it useless. A NAT gateway is outbound-only and opens no inbound path,
# which is why the plan auditor accepts this address but still rejects one on the workstation
# NIC. It is billed per hour, so destroy the workstation once the DDMs exist.
resource "azurerm_public_ip" "workstation_nat" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                = "${local.name_prefix}-pip-natgw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags = {
    FirstPartyUsage = "/Unprivileged"
  }
  tags = local.tags
}

resource "azurerm_nat_gateway" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                = "${local.name_prefix}-natgw-workstation"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.workstation[0].id
  public_ip_address_id = azurerm_public_ip.workstation_nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  subnet_id      = azurerm_subnet.workstation[0].id
  nat_gateway_id = azurerm_nat_gateway.workstation[0].id
}

# A separate NSG, not a rule bolted onto the lab's. The workstation exposes RDP and nothing
# else, and keeping that in its own object means widening RDP can never accidentally widen
# the database host.
resource "azurerm_network_security_group" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                = "${local.name_prefix}-nsg-workstation"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "AllowRdpFromVirtualNetwork"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

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

resource "azurerm_subnet_network_security_group_association" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  subnet_id                 = azurerm_subnet.workstation[0].id
  network_security_group_id = azurerm_network_security_group.workstation[0].id
}

# Developer is the no-cost, shared-pool Bastion SKU for dev/test. It needs no public IP or
# AzureBastionSubnet and reaches both target VMs over their private addresses, which complies
# with the tenant policy that removes public SSH/RDP rules.
resource "azurerm_bastion_host" "developer" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                = "${local.name_prefix}-bas-developer"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.lab.id
  tags                = local.tags
}

resource "azurerm_network_interface" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                = "${local.name_prefix}-nic-workstation"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstation[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  network_interface_id      = azurerm_network_interface.workstation[0].id
  network_security_group_id = azurerm_network_security_group.workstation[0].id
}

# Same discipline as the Adabas password: generated here, stored in Key Vault, never an
# output and never an input. Windows wants 3 of 4 character classes; the special set is
# trimmed to characters that survive being typed into an RDP prompt.
resource "random_password" "workstation_admin" {
  count = var.enable_ddm_workstation ? 1 : 0

  length           = 24
  special          = true
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_.~"
}

resource "azurerm_windows_virtual_machine" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  name                              = "${local.name_prefix}-vm-ddmws"
  location                          = azurerm_resource_group.lab.location
  resource_group_name               = azurerm_resource_group.lab.name
  size                              = var.ddm_workstation_size
  admin_username                    = var.ddm_workstation_admin_username
  admin_password                    = random_password.workstation_admin[0].result
  vm_agent_platform_updates_enabled = true

  # See the note on the Linux VM: Azure Update Manager sets these, so the config adopts them.
  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  tags                                                   = local.tags

  # Windows caps the NetBIOS name at 15 characters and the resource name above is longer,
  # so it must be set explicitly or the apply fails on a name Azure derived for us.
  computer_name = "sifap-ddm-ws"

  network_interface_ids = [azurerm_network_interface.workstation[0].id]

  identity {
    type = "SystemAssigned"
  }

  # See the note on azurerm_managed_disk.adabas_data: the platform applies Standard_LRS.
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = var.ddm_workstation_image_version
  }

  boot_diagnostics {}
}

# The workstation is idle most of its short life, and a forgotten Windows VM bills for the
# licence as well as the compute. It shares the lab's shutdown time.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "workstation" {
  count = var.enable_ddm_workstation ? 1 : 0

  virtual_machine_id    = azurerm_windows_virtual_machine.workstation[0].id
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
