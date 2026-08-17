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

  # Remote state. Partial configuration on purpose: the container, blob key and auth mode
  # are stable and committed, while resource_group_name and storage_account_name come from
  # `infra/bootstrap` outputs (the account name carries a random suffix) and are supplied at
  # init time:
  #
  #   terraform init \
  #     -backend-config="resource_group_name=<RG>" \
  #     -backend-config="storage_account_name=<ACCOUNT>"
  #
  # NOTHING SECRET LIVES HERE. There is no access_key and no sas_token, and none can exist:
  # the bootstrap account sets shared_access_key_enabled = false, so the only way in is the
  # caller's own Entra identity - a federated OIDC token in CI, `az login` on a laptop.
  backend "azurerm" {
    container_name = "tfstate"
    key            = "adabas-natural-lab.tfstate"

    # Entra auth for the blob data plane. Mandatory: the account has no shared key.
    use_azuread_auth = true

    # Short-lived federated credential from GitHub Actions. Harmless locally, where the
    # Azure CLI login is used instead.
    use_oidc = true
  }

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
