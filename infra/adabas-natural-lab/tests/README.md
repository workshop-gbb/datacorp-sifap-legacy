# Adabas/Natural lab loader tests

These tests protect the empirically proven Adabas CE load path for SIFAP.

## Tier 1: fast/offline

```bash
python3 -m pytest infra/adabas-natural-lab/tests -m "not live"
```

Covers DDM parsing, FDT emission, descriptor counts, derived descriptor syntax, the `N`→`U` FDT mapping, packed field width arithmetic, fixed-width seed layout, E4 framing, one-byte MU/PE occurrence counts, and occurrence-major periodic group encoding. It also locks the loader contract: `adafdu` gets the FDT through `FDUFDT`, `adacmp` receives parameters only and reads data from `CMPIN`, and the default load path is `adamup db=<DBID> update=<FNR>,add`.

## Tier 2: live Docker-gated

```bash
python3 -m pytest infra/adabas-natural-lab/tests -m live
```

Requires Docker and `softwareag/adabas-ce:7.4.0`. The test starts `sifap-ada-tests` with `--platform linux/amd64 -e ACCEPT_EULA=Y`, runs the real loader, asserts records added for files 150-153 (`500`, `6`, `2000`, `200`), and asserts zero ADACMP incorrect records. If Docker or the image is unavailable, it skips with a clear message.

## Why this exists

A load can appear successful while silently damaging keyed access or shifting packed fields. These tests catch regressions such as positional loss of optional DDM `S`/`D` columns, use of obsolete `FDT-150-BENEFICIARY.txt`, two-byte MU/PE counts, field-major PE encoding, invalid ADACMP keywords, or accidentally returning to an unavailable `adalod`-centric flow.

## Deployed viewer access

The independent HTTP probe checks the existing Azure environment without loading
records, executing business programs, or changing infrastructure:

```bash
bash infra/adabas-natural-lab/verify-viewer-access.sh
```

`SIFAP_LAB_URL` defaults to the documented lab HTTPS origin. TLS verification is
mandatory, and redirects are not followed. This anonymous probe does not receive
or transmit an account credential.

The probe verifies public landing/health, anonymous terminal redirection,
and admin redirection to sign-in. Credentialed ADMIN/VIEWER flows, terminal role
routing and admin denial are covered by the session gateway tests and the modern
repository's live Playwright suite. A network error or unexpected status fails
the probe.

This proves the HTTP viewer boundary, not every Natural business workflow. The
offline `test_viewer_account.py` separately protects the `VIEWBENF;FIN` terminal
pin and the absence of a shell fallback. The modern application lives in the
existing [SIFAP Modern repository](https://github.com/workshop-gbb/datacorp-sifap-modern);
the legacy `/app/` placeholder is not proof that modernization is deployed.
