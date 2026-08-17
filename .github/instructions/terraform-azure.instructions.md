---
description: "Pointer: Azure Terraform guidance for this kit is consolidated into infrastructure.instructions.md (authoritative) and terraform.instructions.md (generic hygiene)."
applyTo: "**/*.tf"
---

# Azure Terraform — Consolidated

Azure Terraform guidance for this workshop lives in two files; this note only points to them so nothing is duplicated or allowed to drift:

- **[`infrastructure.instructions.md`](infrastructure.instructions.md)** — authoritative kit rules: Azure provider `azurerm ~> 3.x` (pinned `required_version`), mandatory `project`/`environment`/`owner` tags, secrets only in `azurerm_key_vault_secret`, one module per Azure service area (networking, compute, database, monitoring), Managed Identity for service-to-service auth, the `terraform fmt` + `terraform validate` gate, and Docker Compose parity.
- **[`terraform.instructions.md`](terraform.instructions.md)** — generic Terraform hygiene: file layout, typed variables and outputs, `locals`, idempotency, `tflint`, `*.tftest.hcl` tests, and remote state.

Prefer the `azurerm` provider; reach for `azapi` only for resources `azurerm` does not yet support, and record the reason in a code comment. Do not introduce Azure Verified Modules, additional providers, or a different naming scheme without an ADR — the kit standard is custom modules and resource names shaped `{project}-{env}-{resource}-{region}` (see `infrastructure.instructions.md`).
