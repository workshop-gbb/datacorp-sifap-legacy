terraform {
  # Pinned to one minor line, not a wide floor. The old ">= 1.5.0, < 2.0.0" let a laptop on
  # 1.14 write state that CI on 1.9 could no longer read: Terraform records the writing
  # version in state and refuses to open state from a newer one. That failure lands
  # mid-apply, against the shared backend, holding a lease.
  #
  # Change this in lockstep with BOTH workflows:
  #   .github/workflows/ci.yml         -> infra job, terraform_version
  #   .github/workflows/deploy-lab.yml -> env.TERRAFORM_VERSION
  required_version = "~> 1.14.0"

  # Local state is the default. Some workshop tenants enforce storage
  # publicNetworkAccess = Disabled at management-group scope, which makes an Azure Blob
  # backend unreachable from facilitator laptops and GitHub-hosted runners even when Entra
  # RBAC is correct. Keep terraform.tfstate local, back it up, and run destroy from the same
  # checked-out working copy.
  #
  # Optional remote backend for tenants that allow reachable state storage:
  #
  # backend "azurerm" {
  #   container_name    = "tfstate"
  #   key               = "adabas-natural-lab.tfstate"
  #   use_azuread_auth  = true
  #   use_oidc          = true
  # }
  #
  # Then initialize with:
  #
  #   terraform init \
  #     -backend-config="resource_group_name=<RG>" \
  #     -backend-config="storage_account_name=<ACCOUNT>"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      # See the teardown section of README.md: the vault carries prevent_destroy, so these
      # two only take effect once that guard has been deliberately lifted.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      # Workspaces are soft-deleted for 14 days by default, which blocks recreating one with
      # the same name. A lab must be re-creatable the same afternoon.
      permanently_delete_on_destroy = true
    }
  }
}
