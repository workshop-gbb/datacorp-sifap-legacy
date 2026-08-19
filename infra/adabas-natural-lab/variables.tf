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

    Pinned for reproducible rebuilds. To bump it, list available East US 2 versions,
    choose an explicit version, and verify it before changing this default:

      az vm image list --publisher Canonical \
        --location eastus2 \
        --offer 0001-com-ubuntu-server-jammy --sku 22_04-lts-gen2 \
        --all --query "[-10:].version" -o table

      az vm image show --location eastus2 --urn \
        Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:<version>
  EOT
  type        = string
  default     = "22.04.202608060"
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
    Caddy image used as the TLS-terminating reverse proxy for the whole demo origin: the
    landing page, /terminal (the legacy green screen), /app (the modern application) and
    /admin (the Adabas console). It also enforces the basic authentication in front of all
    of them. Pinned by digest, same rationale as the other two.

    The same image doubles as the bcrypt hasher at boot (`caddy hash-password`), so the
    credential is hashed by exactly the build that will verify it.
  EOT
  type        = string
  default     = "caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.caddy_image))
    error_message = "caddy_image must be pinned by digest, e.g. caddy:2.10.2-alpine@sha256:<64 hex chars>."
  }
}

variable "ttyd_image" {
  description = <<-EOT
    Web terminal image, pinned by digest. This is what turns the Natural green screen into
    something a browser can open: Natural speaks a character-terminal protocol, and port 2700
    on the Natural container is the Natural Development Server (NDV, for NaturalONE), NOT a
    telnet listener - no browser can attach to either. ttyd serves an xterm.js terminal over
    HTTP/WebSocket and runs one command per connection; here that command opens a Natural
    session inside the natural-ce container.

    Same re-pin command as the other images:
      docker buildx imagetools inspect tsl0922/ttyd:<tag> --format '{{.Manifest.Digest}}'

    Verified: 1.7.7 is the newest tagged release in the upstream repository, the image is
    Alpine-based (busybox + bash + tini, ttyd at /usr/bin/ttyd) and publishes linux/amd64.
  EOT
  type        = string
  default     = "tsl0922/ttyd:1.7.7-alpine@sha256:e17d5420fa78ea6271e32a06eec334adda6f54077e56e3969340fb47e604c24c"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.ttyd_image))
    error_message = "ttyd_image must be pinned by digest, e.g. tsl0922/ttyd:1.7.7-alpine@sha256:<64 hex chars>."
  }
}

variable "docker_cli_image" {
  description = <<-EOT
    Image the Docker CLI binary is copied out of at bootstrap, pinned by digest.

    WHY THIS EXISTS: the ttyd container has to run `docker exec` against natural-ce, and the
    ttyd image ships no Docker client. The host's own client cannot be bind-mounted into it -
    the host is Ubuntu (glibc), the ttyd image is Alpine (musl). The official Docker CLI image
    is Alpine-based, so the binary it carries at /usr/local/bin/docker runs unmodified inside
    the ttyd container. bootstrap.sh copies it out with `docker cp` into /opt/sifap/bin and
    bind-mounts it read-only.

    Only the CLI is used. No daemon, no buildx, no compose plugin.
  EOT
  type        = string
  default     = "docker:29.7.2-cli@sha256:000bb62ff495f986c9f5578eb67cc2cb98b91138eda81d7762d5371eb8a497fe"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.docker_cli_image))
    error_message = "docker_cli_image must be pinned by digest, e.g. docker:29.7.2-cli@sha256:<64 hex chars>."
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
# The legacy payload: corpus + provisioning scripts
#
# Everything in this section answers one question: how do the SIFAP sources and the scripts
# that load them reach a VM that nobody logs into by hand?
# ---------------------------------------------------------------------------

variable "legacy_corpus_path" {
  description = <<-EOT
    Path to the frozen legacy sources, relative to this module directory. Terraform reads
    <path>/natural-programs and <path>/adabas-ddms and stages every file to blob storage,
    from where the VM pulls them at first boot with its managed identity.

    This is a PATH, not a git ref, on purpose. The alternative - cloning a pinned commit on
    the VM - only ships what has already been pushed, so the lab would boot with whatever the
    remote happened to hold rather than the tree this apply is running from. Staging the
    working tree makes "what Terraform saw" and "what the VM got" the same bytes, and the
    per-file SHA-256 manifest proves it.

    A directory that does not exist yields an empty file set rather than an error, so a
    partial checkout fails loudly on the VM (with a clear message) instead of at plan time.
  EOT
  type        = string
  default     = "../../01-archaeology/legacy-sifap"
}

variable "assign_vm_blob_role" {
  description = <<-EOT
    Create the "Storage Blob Data Reader" role assignment that lets the VM's managed identity
    read the staged payload. Leave it true unless the tenant forbids role assignments.

    Writing a role assignment needs Microsoft.Authorization/roleAssignments/write - Owner or
    User Access Administrator - which some workshop subscriptions do not grant. Set this to
    false there, have someone with the rights assign "Storage Blob Data Reader" to the VM
    identity over the payload container out of band, and re-run
    `sudo /opt/sifap/fetch-payload.sh` on the VM.

    With no role at all the VM downloads nothing: the corpus never lands, provisioning never
    runs, and both say so in /var/log/sifap-bootstrap.log. Nothing else breaks.

    Why a role and not a SAS token: a SAS is a bearer credential with an expiry to manage and
    a copy to leak. The managed identity already exists for Key Vault, so this reuses it.
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# The public demo: routes and authentication
# ---------------------------------------------------------------------------

variable "demo_basic_auth_username" {
  description = <<-EOT
    Username for the HTTP basic authentication that guards the demo origin. Not a secret -
    the password is, and it never appears here.

    Everything on the public origin sits behind this except /healthz, which stays open so a
    readiness probe (and the bootstrap script's own check) keeps working without credentials.
  EOT
  type        = string
  default     = "sifap"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]{2,32}$", var.demo_basic_auth_username))
    error_message = "demo_basic_auth_username must be 2-32 characters of letters, digits, dot, underscore or hyphen."
  }
}

variable "demo_basic_auth_password_hash" {
  description = <<-EOT
    OPTIONAL bcrypt hash of the demo password, for teams that already have a credential they
    want to reuse. Leave it empty (the default) and Terraform generates a password, stores it
    in Key Vault, and the VM hashes it locally at boot - no hash and no password ever touches
    this repository, cloud-init or the Terraform inputs.

    Produce one with the same Caddy build that will verify it:
      docker run --rm -i caddy:2.10.2-alpine caddy hash-password <<<'your-password'

    Supply it through the environment, never through a committed file:
      export TF_VAR_demo_basic_auth_password_hash='$2a$14$...'

    A bcrypt hash is not plaintext, but it is still the credential verifier: it goes into Key
    Vault like everything else, and the VM reads it from there with its managed identity. It
    is never rendered into custom_data, where any process on the VM could read it back out of
    the instance metadata service.
  EOT
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.demo_basic_auth_password_hash == "" || can(regex("^\\$2[aby]\\$[0-9]{2}\\$[./A-Za-z0-9]{53}$", var.demo_basic_auth_password_hash))
    error_message = "demo_basic_auth_password_hash must be empty or a bcrypt hash, e.g. $2a$14$<53 chars>. Generate it with: caddy hash-password."
  }
}

variable "modern_app_upstream" {
  description = <<-EOT
    Upstream the /app route proxies to: the modern Java + Next.js application the team builds
    in Stage 3, addressed by its Docker Compose service name and port.

    The route is provisioned NOW, before the application exists, so the URL handed to an
    audience never changes. Until a container answers on this address, https://<fqdn>/app
    returns 502 from Caddy - which is the honest answer, and exactly what the modernisation
    story looks like on day one.
  EOT
  type        = string
  default     = "sifap-app:8080"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?:[0-9]{1,5}$", var.modern_app_upstream))
    error_message = "modern_app_upstream must be host:port, e.g. sifap-app:8080."
  }
}

variable "terminal_natural_command" {
  description = <<-EOT
    Command the web terminal runs inside the natural-ce container to open a session. Empty
    (the default) uses the fallback chain in /opt/sifap/terminal-session.sh: the Natural
    binary if it is where the image puts it, otherwise an interactive shell with a banner
    explaining what to run.

    Deliberately overridable and deliberately not guessed at: the exact start-up line for
    Natural CE (parameter module, session parameters, which library to LOGON to) is the
    team's to determine from the image and from provisioning/02-build-natural.sh, not this
    module's to assume. Example of the shape:

      terminal_natural_command = "/opt/softwareag/Natural/bin/natural stack=(LOGON SIFAPPRD)"

    custom_data carries ignore_changes, so changing this after the VM exists does not reach
    it. Edit /opt/sifap/terminal-session.sh on the box and `docker compose restart ttyd`.
  EOT
  type        = string
  default     = ""
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

variable "key_vault_allowed_ip_rules" {
  description = <<-EOT
    Public IP allow-list for the Key Vault firewall, in CIDR or bare-IP form. Empty (the
    default) leaves the vault on its open public endpoint with default_action = "Allow".

    Empty is the default for a reason, not an oversight. Three parties need the data plane:
    the operator's laptop, the lab VM (through its own public IP, which does not exist until
    the VM does), and the CI runner that writes the secret during apply - and GitHub-hosted
    runners have no stable egress IP. A default-Deny firewall with an incomplete list turns
    every apply into a 403.

    Set it once you know all three addresses, or when you run applies from fixed egress. The
    vault is still protected by access policies scoped to exactly two principals, and holds
    one generated lab password. Azure rejects /31 and /32 masks here, so the module strips a
    /32 down to the bare address for you.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# DDM workstation
#
# Natural CE cannot create DDMs: the image ships no SYSDDM objects, no DDM utility and not
# one sample .NGD (verified against softwareag/natural-ce:9.3.3). Software AG's answer is
# NaturalONE, the Eclipse IDE that attaches to the Natural Development Server on port 2700 -
# and it is published for Windows, not for macOS or arm64. This optional Windows VM is that
# missing workstation, inside the VNet, so the one manual step in the whole deployment does
# not depend on what laptop the facilitator happens to own.
#
# It is needed ONCE. After the DDMs exist, 05-backup-restore.sh archives them to the
# sifap-state container and restores them on later boots, so the workstation can be turned
# off with enable_ddm_workstation = false and destroyed.
# ---------------------------------------------------------------------------

variable "enable_ddm_workstation" {
  description = <<-EOT
    Create a Windows VM in the lab VNet for running NaturalONE, the only supported way to
    create the four SIFAP DDMs.

    Off by default: it is a second VM with a Windows licence charge, and it is dead weight
    once the DDMs are archived. Turn it on, create the DDMs, run the finalize phase, then
    turn it off again.

    NaturalONE Community Edition is a free download from the Software AG TECHcommunity and
    requires a forum account, so the installer cannot be staged by Terraform. Download it on
    the workstation itself - see README.md, "Creating the DDMs".
  EOT
  type        = bool
  default     = false
}

variable "ddm_workstation_size" {
  description = "VM size for the NaturalONE workstation. Eclipse wants 8 GB to be comfortable, which is what the default provides."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "ddm_workstation_admin_username" {
  description = "Local administrator for the NaturalONE workstation. Windows reserves 'admin' and 'administrator', so neither is accepted."
  type        = string
  default     = "sifapadmin"

  validation {
    condition     = !contains(["admin", "administrator", "guest", "root"], lower(var.ddm_workstation_admin_username))
    error_message = "ddm_workstation_admin_username must not be a Windows reserved name (admin, administrator, guest, root)."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{1,19}$", var.ddm_workstation_admin_username))
    error_message = "ddm_workstation_admin_username must be 2-20 characters, start with a letter, and contain only letters, digits, hyphen or underscore."
  }
}

variable "ddm_workstation_image_version" {
  description = <<-EOT
    Pinned version of the Windows Server 2022 Gen2 marketplace image, so a rebuild months
    from now boots the same image rather than whatever "latest" resolves to that day.

    Re-pin with:
      az vm image list --publisher MicrosoftWindowsServer --offer WindowsServer \
        --location <region> --all --query "[?sku=='2022-datacenter-g2'].version | [-3:]" -o tsv
  EOT
  type        = string
  default     = "20348.5499.260809"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.ddm_workstation_image_version))
    error_message = "ddm_workstation_image_version must be an exact version such as 20348.5499.260809, never \"latest\"."
  }
}
