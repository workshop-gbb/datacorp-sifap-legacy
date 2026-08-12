variable "project" {
  description = "Project slug used in resource names and tags."
  type        = string
  default     = "sifap"

  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.project))
    error_message = "project must be 2-12 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "workshop"], var.environment)
    error_message = "environment must be one of: lab, dev, workshop."
  }
}

variable "owner" {
  description = "Owner tag. Use the GitHub handle or e-mail of whoever is responsible for the lab."
  type        = string
}

variable "cost_center" {
  description = "Cost center tag used for chargeback reporting."
  type        = string
  default     = "workshop-legacy-modernization"
}

variable "location" {
  description = "Azure region. The Software AG images are linux/amd64 only, which every Azure region provides natively."
  type        = string
  default     = "brazilsouth"
}

variable "location_short" {
  description = "Short region code used in resource names."
  type        = string
  default     = "brs"
}

variable "vm_size" {
  description = "VM size. Adabas CE plus Natural CE need roughly 4-6 GB RAM combined, so 2 vCPU / 8 GB is the practical floor."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Administrator user for the lab VM. Password authentication is disabled; SSH key only."
  type        = string
  default     = "sifapadmin"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key authorised to reach the VM."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_source_cidrs" {
  description = <<-EOT
    Source CIDRs allowed to reach SSH, the Natural Development Server and the Adabas ports.
    Never widen this to 0.0.0.0/0: Adabas CE offers no channel encryption and the NDV has no
    strong authentication, so an open listener is a direct compromise path.

    Deliberately has NO default: a required variable cannot silently fall back to something open.
    Only explicit IPv4 CIDRs are accepted; Azure service tags such as "Internet" or "VirtualNetwork"
    are rejected on purpose so the allow-list stays auditable.
  EOT
  type        = list(string)

  # Reject every spelling of "open to the internet", not just the literal 0.0.0.0/0.
  validation {
    condition = length([
      for c in var.allowed_source_cidrs : c
      if contains(["0.0.0.0/0", "*", "::/0", "internet", "any"], lower(trimspace(c)))
    ]) == 0
    error_message = "Open-to-the-internet sources are rejected: 0.0.0.0/0, *, ::/0, Internet, Any. List explicit workshop IPs or CIDRs."
  }

  # Backstop for the rule above: a well-formed IPv4 CIDR no wider than /8. This also catches
  # 0.0.0.0/0 written as 0.0.0.0/1, 10.0.0.0/4 and similar near-open ranges, plus plain typos.
  validation {
    condition = alltrue([
      for c in var.allowed_source_cidrs :
      can(cidrnetmask(trimspace(c))) && can(regex("/(8|9|1[0-9]|2[0-9]|3[0-2])$", trimspace(c)))
    ])
    error_message = "Each entry must be an explicit IPv4 CIDR with prefix /8../32, e.g. 203.0.113.10/32."
  }

  validation {
    condition     = length(var.allowed_source_cidrs) > 0
    error_message = "At least one source CIDR is required."
  }
}

variable "data_disk_size_gb" {
  description = "Size of the managed disk that holds the Adabas database containers."
  type        = number
  default     = 32
}

variable "adabas_image" {
  description = "Adabas Community Edition image reference."
  type        = string
  default     = "softwareag/adabas-ce:7.4.0"
}

variable "natural_image" {
  description = "Natural Community Edition image reference."
  type        = string
  default     = "softwareag/natural-ce:9.3.3"
}

variable "adabas_dbid" {
  description = "Adabas database id that Natural maps through dbmapping."
  type        = number
  default     = 12
}

variable "auto_shutdown_time" {
  description = "Daily auto-shutdown time in HHmm, in auto_shutdown_timezone. Guards against a VM left running after the workshop."
  type        = string
  default     = "2000"
}

variable "auto_shutdown_timezone" {
  description = "Timezone for the auto-shutdown schedule."
  type        = string
  default     = "E. South America Standard Time"
}

variable "auto_shutdown_notification_email" {
  description = "Optional e-mail warned before auto-shutdown. Empty disables the notification."
  type        = string
  default     = ""
}
