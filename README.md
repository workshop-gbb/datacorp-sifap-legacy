# SIFAP legacy lab — private operations repository

> [!CAUTION]
> **PRIVATE. THIS REPOSITORY OPERATES LIVE INFRASTRUCTURE.** It is the authoritative source for the running Natural/Adabas SIFAP lab and its Azure environment. A change merged here can reach a live VM. Do not make it public, use it as a template, or grant access beyond lab operators.

This repository holds the **legacy system that actually runs**: the frozen Natural/Adabas corpus, the Terraform that builds the Azure lab, the provisioning chain that catalogs the programs and loads the Adabas files, and the payload delivery path. It is deliberately separated from the teaching material so that operations and curriculum can change independently.

| Field | Value |
|---|---|
| **Audience** | Lab operators and facilitators only |
| **Contains** | Legacy corpus, Azure infrastructure, provisioning, payload delivery |
| **Does not contain** | Curriculum, personas, stage guides, decks, facilitator answer key |
| **Deployable from** | `main` only |

---

## What this repository is

- The **single source of truth** for the running lab. The payload installed on the VM is built from this repository and pinned to a commit SHA.
- The **frozen legacy corpus** under `01-archaeology/legacy-sifap/`: Natural members, Adabas DDMs and the FDT listing, preserved byte for byte with their original history.
- The **infrastructure** under `infra/adabas-natural-lab/`: Terraform, provisioning scripts, the offline contract test suite and the operator tooling.

## What this repository is not

- It is **not** a teaching kit. Immersion curriculum, personas and stage agents live in the instructor and team repositories.
- It is **not** where the modernized product is built. That is `datacorp-sifap-modern`.
- It **never** stores Terraform state, `.tfvars`, plans, credentials or `.env` files. A CI job fails the build if any of them are tracked.

---

## Repository layout

```text
01-archaeology/legacy-sifap/    frozen legacy corpus (Natural, DDMs, FDT)
  natural-programs/             24 Natural members
  adabas-ddms/                  4 DDMs + FDT listing
infra/adabas-natural-lab/       Azure lab: Terraform, provisioning, tests, tooling
.github/workflows/ci.yml        contract, hygiene and Terraform gates
.github/workflows/deploy-lab.yml  preflight and ephemeral plan runs
```

---

## The live lab

The lab runs as one shared environment. Nobody redeploys it per team.

| What | Where |
|---|---|
| **Live system** | <https://sifap-lab-438k30.eastus2.cloudapp.azure.com> |
| **Natural session** | `/terminal/` |
| **Adabas administration** | `/admin/` |
| **Health probe** | `/healthz` |
| **Resource group** | `sifap-lab-rg-eus2` |
| **Virtual machine** | `sifap-lab-vm-eus2` |

Credentials are shared out of band by the facilitator and are never committed here.

### Public landing and viewer access

The public origin now presents the retro SIFAP story in EN, ES and PT-BR.
Select **Enter as viewer** to open a read-only session without a shared password.
This is explicitly public access to the synthetic classroom environment; it is
not identity verification or a production financial service.

The actual Natural session remains pinned to `VIEWBENF;FIN`. Guest access never
reaches the operator terminal or Adabas administration. Operator credentials
remain private and the existing credential-based operator paths are preserved.
The [viewer gateway](infra/adabas-natural-lab/provisioning/viewer-access/README.md)
documents session limits, testing, deployment and rollback.

---

## Operating the lab

All operator commands run from `infra/adabas-natural-lab/`.

```bash
./deploy-local.sh package   # build and checksum the payload archive locally
./deploy-local.sh plan      # show the Terraform plan
./deploy-local.sh apply     # apply infrastructure changes
./deploy-local.sh upload    # install a SHA-pinned payload on the VM
./deploy-local.sh status    # report live lab status
./deploy-local.sh destroy   # tear the lab down
```

> [!WARNING]
> Read the `Plan:` line before every apply. For an existing lab it must report `0 to destroy`. This tenant mutates resources at create time, and a plan that destroys the data disk silently discards the loaded Adabas database.

---

## Payload provenance and delivery

The VM never builds the corpus. It downloads a **specific commit** of this repository, verifies a `manifest.sha256`, and swaps the payload atomically, keeping the previous one for rollback.

Because this repository is private, the download must be authenticated:

```bash
export SIFAP_GITHUB_TOKEN="<short-lived installation token>"
./deploy-local.sh upload
```

| Behaviour | Without a token | With `SIFAP_GITHUB_TOKEN` |
|---|---|---|
| Archive source | `codeload.github.com` (public only) | GitHub API tarball, authenticated |
| Installer script | fetched from `raw.githubusercontent.com` | sent from this checkout |
| Token exposure | not applicable | passed as an Azure **protected parameter**, absent from Run Command logs |

Use a short-lived GitHub App installation token with `contents:read`. Do not store a personal access token on the VM or in Key Vault.

---

## State and secrets

| Artifact | Where it lives |
|---|---|
| `terraform.tfstate` and its backup | operator workstation only, backed up out of band |
| `terraform.tfvars` | operator workstation only |
| Lab credentials | shared out of band by the facilitator |
| Generated passwords | Terraform state and Key Vault, never this repository |

The `repo-hygiene` CI job fails the build if state, plans, `.tfvars`, keys or `.env` files are ever tracked, because `.gitignore` does not stop `git add -f`.

---

## Branches

| Branch | Purpose |
|---|---|
| `main` | English operational source. The only branch the lab is deployed from. |
| `develop` | Integration branch, initially identical to `main`. |
| `portugues-br` | Translated documentation only. Runtime, Terraform and corpus stay identical to `main`. |

---

## Related repositories

| Repository | Purpose |
|---|---|
| `workshop-gbb/datacorp-sifap-legacy` | This repository: the running legacy lab |
| `workshop-gbb/datacorp-sifap-instructor-kit-pt-br` | Instructor kit, decks and facilitator answer key |
| `workshop-gbb/datacorp-sifap-team-kit-pt-br` | Public team kit used by participants |
| `workshop-gbb/datacorp-sifap-modern` | The modernized SIFAP product |

The two kits keep a **didactic snapshot** of the Natural and DDM corpus for offline reading. This repository holds the **authoritative runtime copy**.

---

## Validation gates

Every push and pull request runs:

| Gate | What it protects |
|---|---|
| `cloud-init-size` | the VM boots at all, by keeping `custom_data` under the Azure limit |
| `natural-format` | the legacy corpus keeps its original fixed-column formatting |
| `provisioning-contracts` | the offline test suite, shell lint, payload build and scratch-leak checks |
| `repo-hygiene` | no state, plans, credentials or `.env` files are tracked |
| `infra` | `terraform fmt` and `terraform validate` for every module |

Run the same checks locally before pushing:

```bash
cd infra/adabas-natural-lab
terraform fmt -check -recursive
terraform validate
python3 -m pytest tests -m "not live" -q
./deploy-local.sh package
```
