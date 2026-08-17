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
