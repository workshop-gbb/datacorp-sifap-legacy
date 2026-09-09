# Public SIFAP legacy landing

This directory is the maintainable source for the public, Brazilian Portuguese
introduction at <https://workshop-gbb.github.io/datacorp-sifap-legacy/>.
It is deliberately separate from the authenticated runtime assets under
`infra/adabas-natural-lab/`.

The static page shares the SIFAP editorial identity and uses a restrained
phosphor-green terminal aesthetic. Its access actions open the visible Azure
viewer entry in the same tab:

<https://sifap-lab-438k30.eastus2.cloudapp.azure.com/login?locale=pt-BR>

The Azure origin creates the opaque, read-only viewer session through an
explicit same-origin form. GitHub Pages does not collect credentials, create
sessions or embed the terminal. Administration remains restricted to operators,
and the public workshop viewer uses only synthetic data.

Do not link an unauthenticated visitor directly to `/terminal/`. The raw ttyd
route needs a valid viewer session. The old Basic Auth gateway returned an empty
HTTP 401 in embedded browsers, which looked like a blank page.

## Local preview

```bash
python3 -m http.server 8080 --bind 127.0.0.1 --directory public-landing
```

The page has no JavaScript, CDN, analytics or frontend package dependencies.
Inter and JetBrains Mono use the unmodified Fontsource 5.3.0 files and included
SIL Open Font License notices.

## Public artifact

Export exactly the approved presentation files to a new or empty directory
outside this private checkout:

```bash
python3 scripts/build-public-landing.py /tmp/sifap-public-landing
```

The exporter copies the HTML, CSS, favicon, two fonts and two license notices,
then adds `.nojekyll`. It rejects missing assets, symlinks, nonempty destinations
and destinations inside this checkout. Do not copy repository history, runtime
status, infrastructure, the Natural corpus or application payloads to Pages.

GitHub Pages publishes the root of the dedicated `gh-pages` artifact branch.
Repository visibility remains private while Pages access is public and HTTPS is
enforced. The source follows the normal reviewed `impl/` to `develop` workflow;
publishing the presentation does not merge `main` or deploy Azure.

## Verification

Run the public-source contracts with the existing lab test environment:

```bash
python3 -m pytest \
  infra/adabas-natural-lab/tests/test_landing_contract.py \
  infra/adabas-natural-lab/tests/test_public_landing_export.py -q
```

Offline link checks do not prove the Natural terminal is operational. Before
release, use an anonymous real browser to verify:

1. The Pages access action stays in the same tab and opens the Azure entry.
2. The visitor explicitly starts the viewer session without a password.
3. `/viewer` embeds a visible xterm and receives real Natural output over its
   WebSocket.
4. Viewer access receives HTTP 403 for `/admin/`.
5. Logout removes the viewer session.

Do not accept a mocked navigation, an HTTP 200 by itself or a bare 401 challenge
as end-to-end terminal evidence.
