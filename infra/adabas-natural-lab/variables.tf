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
  description = <<-EOT
    Azure region. The Software AG images are linux/amd64 only, which every Azure region
    provides natively, so the real constraint is vCPU quota for var.vm_size - check it with
    `az vm list-usage --location <region> -o table` BEFORE the first apply.

    The public demo FQDN is derived from this value: <label>.<location>.cloudapp.azure.com.
    Changing the region therefore changes the demo URL and forces a full rebuild.
  EOT
  type        = string
  default     = "eastus2"
}

variable "location_short" {
  description = <<-EOT
    Optional override for the short region code used in resource names (the "-eus2" in
    sifap-lab-rg-eus2). Leave empty to derive it from var.location, so region and name can
    never drift apart the way they did when both were independent defaults.
  EOT
  type        = string
  default     = ""
}

variable "vm_size" {
  description = "VM size. Adabas CE plus Natural CE need roughly 4-6 GB RAM combined, so 2 vCPU / 8 GB is the practical floor."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "source_image_version" {
  description = <<-EOT
    Version of the Ubuntu 22.04 LTS gen2 marketplace image.

    TODO(pin): replace "latest" with an exact version so a rebuild six months from now boots
    the same kernel and the same package set. The exact list is only visible to an
    authenticated caller, so it cannot be resolved offline; run this against your own
    subscription and paste the result:

      az vm image list --publisher Canonical \
        --offer 0001-com-ubuntu-server-jammy --sku 22_04-lts-gen2 \
        --all --query "[-5:].version" -o table

    Example of the shape you are looking for: "22.04.202501150".
  EOT
  type        = string
  default     = "latest"
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
    Source CIDRs allowed to reach SSH, the Natural Development Server, the Adabas ports and
    the HTTPS demo URL. Never widen this to 0.0.0.0/0: Adabas CE offers no channel
    encryption and the NDV has no strong authentication, so an open listener is a direct
    compromise path.

    Deliberately has NO default: a required variable cannot silently fall back to something
    open. Only explicit IPv4 CIDRs are accepted; Azure service tags such as "Internet" or
    "VirtualNetwork" are rejected on purpose so the allow-list stays auditable.

    If you want the demo URL reachable by an audience outside this list, add their ranges
    here. The one setting that bypasses it is var.enable_public_acme, and only for 80/443.
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

# ---------------------------------------------------------------------------
# Public demo endpoint
# ---------------------------------------------------------------------------

variable "enable_public_acme" {
  description = <<-EOT
    Controls how the demo URL gets its TLS certificate, and therefore who can reach 80/443.

    false (default) - ports 80 and 443 are open ONLY to var.allowed_source_cidrs, and Caddy
      signs the certificate with its own local CA ("tls internal"). https://<fqdn> works and
      is genuinely encrypted, but a browser shows a warning until you trust Caddy's root
      certificate. Everything stays behind the allow-list.

    true - ports 80 and 443 are opened to the "Internet" service tag so Let's Encrypt can
      complete the ACME HTTP-01 challenge, and the demo URL gets a publicly trusted
      certificate with no warning.

    THE TRADEOFF IS REAL AND CANNOT BE ENGINEERED AWAY. Let's Encrypt validates from
    arbitrary IP addresses worldwide; an allow-list that excludes them also excludes the
    validation request. A publicly trusted certificate therefore REQUIRES a publicly
    reachable listener on 80/443.

    What is exposed when true: only Caddy, which reverse-proxies the Adabas administration
    console. SSH (22), the Natural Development Server (2700) and ADATCP (60001) stay on the
    allow-list regardless. The console behind Caddy is protected only by the generated admin
    password, so turn this on for the demo window and destroy the lab afterwards.
  EOT
  type        = bool
  default     = false
}

variable "acme_contact_email" {
  description = <<-EOT
    E-mail registered with Let's Encrypt for expiry warnings. Required when
    var.enable_public_acme is true; ignored otherwise. Not a secret - it appears in the
    public ACME account record.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.acme_contact_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[a-zA-Z]{2,}$", var.acme_contact_email))
    error_message = "acme_contact_email must be empty or a valid e-mail address."
  }
}

variable "expose_adabas_admin_port" {
  description = <<-EOT
    Open port 8190 (plaintext HTTP Adabas administration) directly to the allow-list.

    Off by default. The console is served over TLS at the demo URL through the Caddy reverse
    proxy, so the plaintext port only exists as a troubleshooting fallback for when the proxy
    itself is the thing that is broken.
  EOT
  type        = bool
  default     = false
}

variable "dns_label_prefix" {
  description = <<-EOT
    Optional override for the public DNS label. Leave empty to derive it as
    "<project>-<environment>-<random suffix>", which is what keeps the label globally unique
    inside the region without anyone having to invent one.

    Azure rule: 3-63 characters, lowercase letters, digits and hyphens, must start with a
    letter and end with a letter or digit.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.dns_label_prefix == "" || can(regex("^[a-z][a-z0-9-]{1,50}[a-z0-9]$", var.dns_label_prefix))
    error_message = "dns_label_prefix must be empty, or 3-52 characters of lowercase letters, digits and hyphens starting with a letter."
  }
}

# ---------------------------------------------------------------------------
# Storage and workload
# ---------------------------------------------------------------------------

variable "data_disk_size_gb" {
  description = "Size of the managed disk that holds the Adabas database containers."
  type        = number
  default     = 32

  validation {
    condition     = var.data_disk_size_gb >= 16 && var.data_disk_size_gb <= 1024
    error_message = "data_disk_size_gb must be between 16 and 1024."
  }
}

variable "data_disk_snapshot_label" {
  description = <<-EOT
    Take an incremental snapshot of the Adabas data disk and label it with this string.
    Empty (the default) creates no snapshot.

    This is the on-demand backup handle for the lab: set it before a destructive experiment,
    apply, and the snapshot is created and tracked in state.

      terraform apply -var 'data_disk_snapshot_label=before-catall'

    Snapshots survive `terraform destroy` only if you remove them from this configuration
    first; otherwise they are destroyed with everything else. See README.md -> "Snapshot the
    Adabas data disk".
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.data_disk_snapshot_label == "" || can(regex("^[a-z0-9][a-z0-9-]{1,38}$", var.data_disk_snapshot_label))
    error_message = "data_disk_snapshot_label must be empty, or 2-39 lowercase alphanumeric characters and hyphens."
  }
}

variable "adabas_image" {
  description = <<-EOT
    Adabas Community Edition image, pinned by digest so a re-apply cannot silently pull a
    different build behind the same tag. The tag before the @ is documentation only; the
    digest is what Docker resolves.

    To re-pin after a version bump:
      docker buildx imagetools inspect softwareag/adabas-ce:<tag> --format '{{.Manifest.Digest}}'
  EOT
  type        = string
  default     = "softwareag/adabas-ce:7.4.0@sha256:2d1eb6df66b188bbb6e024d24262ea5f03f35d4e9e2500694ca127c7747a3b8b"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.adabas_image))
    error_message = "adabas_image must be pinned by digest, e.g. softwareag/adabas-ce:7.4.0@sha256:<64 hex chars>."
  }
}

variable "natural_image" {
  description = <<-EOT
    Natural Community Edition image, pinned by digest. Same rationale and same re-pin
    command as var.adabas_image.
  EOT
  type        = string
  default     = "softwareag/natural-ce:9.3.3@sha256:b671669f6625b7d23847e46a5e2f50476778bb1b26550d9248bf6ed49e5597d5"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.natural_image))
    error_message = "natural_image must be pinned by digest, e.g. softwareag/natural-ce:9.3.3@sha256:<64 hex chars>."
  }
}

variable "caddy_image" {
  description = <<-EOT
    Caddy image used as the TLS-terminating reverse proxy in front of the Adabas
    administration console. Pinned by digest, same rationale as the other two.
  EOT
  type        = string
  default     = "caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.caddy_image))
    error_message = "caddy_image must be pinned by digest, e.g. caddy:2.10.2-alpine@sha256:<64 hex chars>."
  }
}

variable "adabas_dbid" {
  description = "Adabas database id that Natural maps through dbmapping."
  type        = number
  default     = 12

  validation {
    condition     = var.adabas_dbid >= 1 && var.adabas_dbid <= 65535
    error_message = "adabas_dbid must be between 1 and 65535."
  }
}

# ---------------------------------------------------------------------------
# Cost control
# ---------------------------------------------------------------------------

variable "auto_shutdown_time" {
  description = "Daily auto-shutdown time in HHmm, in auto_shutdown_timezone. Guards against a VM left running after the workshop."
  type        = string
  default     = "2000"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.auto_shutdown_time))
    error_message = "auto_shutdown_time must be HHmm, 24-hour, e.g. 2000."
  }
}

variable "auto_shutdown_timezone" {
  description = "Windows timezone id for the auto-shutdown schedule. Default matches the eastus2 default region."
  type        = string
  default     = "Eastern Standard Time"
}

variable "auto_shutdown_notification_email" {
  description = <<-EOT
    E-mail warned 30 minutes before auto-shutdown, and copied on budget alerts. Empty
    disables the shutdown notification and leaves budget alerts going to subscription Owners
    only.

    STRONGLY RECOMMENDED. Without it, the first signal that a VM shut down mid-demo, or that
    the lab burned through its budget, is the moment someone notices.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.auto_shutdown_notification_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[a-zA-Z]{2,}$", var.auto_shutdown_notification_email))
    error_message = "auto_shutdown_notification_email must be empty or a valid e-mail address."
  }
}

variable "monthly_budget_amount" {
  description = <<-EOT
    Monthly spend cap for the lab resource group, in the billing currency of the
    subscription, used by the consumption budget. Notifications fire at 50% and 80% of
    actual spend and at 100% of forecast spend.

    A budget notifies, it does not stop anything. It exists so a forgotten lab is noticed in
    days rather than at the end of the month.
  EOT
  type        = number
  default     = 100

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be greater than zero."
  }
}

variable "budget_start_date" {
  description = <<-EOT
    First day of the month the budget starts tracking, RFC 3339, e.g. "2026-09-01T00:00:00Z".
    Empty derives the first day of the current month at apply time.

    Azure only accepts the first day of a month, and refuses a start date in the past when
    the budget is created. The budget carries ignore_changes on its time period, so a derived
    date does not produce a diff on every subsequent plan.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.budget_start_date == "" || can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be empty or the first day of a month in RFC 3339, e.g. 2026-09-01T00:00:00Z."
  }
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Retention for the Log Analytics workspace. 30 days is the free-tier floor and plenty for a disposable lab."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "log_daily_quota_gb" {
  description = <<-EOT
    Daily ingestion cap for the Log Analytics workspace, in GB. A cap is a cost control:
    a chatty container cannot turn observability into the largest line on the bill. -1
    removes the cap.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.log_daily_quota_gb == -1 || var.log_daily_quota_gb > 0
    error_message = "log_daily_quota_gb must be -1 (uncapped) or greater than zero."
  }
}
