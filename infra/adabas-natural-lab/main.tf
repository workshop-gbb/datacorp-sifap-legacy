locals {
  # Convention from .github/instructions/infrastructure.instructions.md:
  # {project}-{env}-{resource}-{region}
  name_prefix = "${var.project}-${var.environment}"
  suffix      = var.location_short

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

  # Natural Development Server: this is the port NaturalONE attaches to.
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

  # Adabas REST administration UI.
  security_rule {
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

resource "azurerm_public_ip" "lab" {
  name                = "${local.name_prefix}-pip-${local.suffix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
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

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Key Vault posture — deliberate choices for a DISPOSABLE workshop lab, not a template for prod:
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
#                                    role assignments — a common blocker on workshop tenants.
#
# Network exposure: the vault is left on its public endpoint (no network_acls) because the VM
# reads its secret over the public endpoint via its own egress IP, and the workshop operator
# writes the secret from a laptop. Locking this down properly needs a private endpoint or an
# IP allow-list covering both; see the residual risk noted in the module review before reusing
# this pattern outside a throwaway lab.
resource "azurerm_key_vault" "lab" {
  name                       = "${var.project}${var.environment}kv${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = false
  tags                       = local.tags
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
    version   = "latest"
  }

  boot_diagnostics {}

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    adabas_image  = var.adabas_image
    natural_image = var.natural_image
    adabas_dbid   = var.adabas_dbid
    key_vault_uri = azurerm_key_vault.lab.vault_uri
    secret_name   = "adabas-admin-password"
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
