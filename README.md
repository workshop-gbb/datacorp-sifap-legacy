# SIFAP legacy lab — private operations repository

> [!CAUTION]
> **PRIVATE. THIS REPOSITORY OPERATES LIVE INFRASTRUCTURE.** It is the authoritative source for the running Natural/Adabas SIFAP lab and its Azure environment. A change merged here can reach a live VM. Do not make the repository public, use it as a template, or grant source access beyond lab operators. The public GitHub Pages landing is a separate, explicitly allowlisted presentation artifact; it contains no operational source or runtime data.

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
| **Public introduction** | <https://workshop-gbb.github.io/datacorp-sifap-legacy/> |
| **Live system** | <https://sifap-lab-438k30.eastus2.cloudapp.azure.com> |
| **Natural session** | `/terminal/` |
| **Adabas administration** | `/admin/` |
| **Health probe** | `/healthz` |
| **Resource group** | `sifap-lab-rg-eus2` |
| **Virtual machine** | `sifap-lab-vm-eus2` |

Credentials are shared out of band by the facilitator and are never committed here.

### Public landing, authenticated Azure system

The [static landing page](infra/adabas-natural-lab/payload-static/www/index.html)
introduces SIFAP in Brazilian Portuguese before the visitor enters the Natural
terminal. It shares the documentation portal and modern application's editorial
layout, typography and four-color identity, with a dark phosphor-green terminal
treatment. The terminal illustration is not an interactive session.

The landing is **public on GitHub Pages**. **Acessar SIFAP legado** opens the
[Azure session entry](https://sifap-lab-438k30.eastus2.cloudapp.azure.com/login?locale=pt-BR)
in the same tab. On Azure, the visitor explicitly starts a passwordless, read-only
viewer session through the gateway's same-origin form. Session cookies never
travel through Pages. The page does not collect credentials, submit cross-origin
login requests or fetch private runtime status. Administration remains restricted
to operators; the viewer is for the workshop's synthetic data only.

Do not link an unauthenticated visitor directly to `/terminal/`: the raw ttyd
route requires a session, and the previous Basic Auth gateway returned an empty
401 document instead of a visible sign-in page in embedded browsers. GET of the
session entry must show the access screen, not silently create a session. Publish
the handoff only after the approved viewer gateway is live and the real browser
flow reaches a rendered Natural terminal. An HTTP 200, an intercepted navigation,
or a 401 challenge alone is not evidence of a working terminal.

The page uses plain HTML, CSS and local fonts: no JavaScript, CDN, analytics or
frontend dependencies. Relative asset URLs work both under the GitHub Pages
project path and at the root of the existing checksummed `www/` runtime payload.
Keyboard focus, a skip link, small-screen layouts and reduced-motion preferences
are supported.

The local Inter and JetBrains Mono variable fonts match the portal's Fontsource
5.3.0 assets. Their unmodified SIL Open Font License notices are included in
[`www/fonts/`](infra/adabas-natural-lab/payload-static/www/fonts/).

For a **local static preview only**, serve the payload directory:

```bash
python3 -m http.server 8080 --bind 127.0.0.1 \
  --directory infra/adabas-natural-lab/payload-static/www
```

This preview does not start Natural or create sessions. Its access links still
open the real Azure session entry; do not enter credentials in the preview.

#### Publishing only the public presentation

The Pages source is the **`gh-pages` branch, root directory**, not `main`, `docs/`
or the repository root. That dedicated artifact branch has no private source
history. GitHub's built-in Pages build publishes it; no Azure deployment runs.

Export the approved public assets into a new or empty directory outside this
private source checkout:

```bash
python3 scripts/build-public-landing.py /tmp/sifap-public-landing
```

The exporter copies exactly the HTML, CSS, favicon, two fonts and their license
notices, then adds `.nojekyll`. It rejects missing assets, symlinks, nonempty
destinations and destinations inside this checkout. Nothing in the corpus,
Terraform, provisioning, `/app/`, runtime status or credentials is included.
Commit **only this export** to the artifact branch for subsequent publications;
never copy the repository or the complete `www/` payload into Pages.

Keep GitHub Pages access **public** and repository visibility **private**. Review
source changes through the normal `impl/` → `develop` → `main` process. Publishing
the static presentation does not merge `main`, upload a runtime payload, restart
the VM or modify Terraform and `cloud-init.yaml`.

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
