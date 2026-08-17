# SIFAP Adabas/Natural provisioning

These scripts are mounted on the VM at `/opt/sifap/provisioning`. The only cloud-init entry point should be:

```bash
sudo /opt/sifap/provisioning/run-all.sh
```

## Scripts

- `run-all.sh` — orchestrates readiness, Adabas load, Natural build, and smoke tests; logs to stdout and `/var/log/sifap-provisioning.log`.
- `01-load-adabas.sh` — creates Adabas files 150–153 and loads `seed/{beneficiary,payment,social-program,audit}.dat` with `seed/layout-*.txt`.
- `02-build-natural.sh` — creates `SYSDDM` DDM sources, copies SIFAP sources into library `SIFAPPRD`, and runs `STOW` in dependency order.
- `03-smoke-test.sh` — runs `CONSBENF` for a seeded CPF and `BATCHPGT` for period `202601` (override with `SIFAP_SMOKE_PERIOD`).
- `lib.sh` — logging, retry, container, and Natural batch helpers.

## Commands and confidence

Confirmed by inspecting the local images (not by a live Azure apply):

- Adabas CE `7.4.0` contains `adafdu`, `adacmp`, `adamup`, `adarep`, `adadbm`, and `adafrm` in PATH.
- The image does **not** expose `adalod`; the script uses the same `adacmp` + `adamup db=<DBID> update=<FNR>,add` pattern used by `/opt/softwareag/Adabas/demodb/LoadDemo.bsh`.
- Natural CE `9.3.3` contains `natural` but not `natbatch`; batch mode syntax is taken from `/opt/softwareag/Natural/samples/sysexbat/natbat.xml`: `natural BATCHMODE CMSYNIN=... CMOBJIN=... CMPRINT=...`.

Best-effort until a real VM apply validates it:

- Generated `.NSD` DDM source from the corpus `LISTDDM` reports.
- Derived FDTs for files 151–153 from DDM listings.
- Exact behavior of `STOW` for DDMs copied into `SYSDDM/SRC`.
- `CONSBENF` batch input sequencing for its alternate no-map screen.

## Compile order

The build follows `01-archaeology/HOW-TO-COMPILE-AND-RUN.md` section 2.4:

1. DDMs in `SYSDDM`: `BENEFICIARY`, `SOCIAL-PROGRAM`, `PAYMENT`, `AUDIT`.
2. Data areas: `PDAVALID`, `PDACALC`, `LDASIFAP`.
3. Copycodes as source: `CCVALCPF`, `CCAUDIT`.
4. Subprograms: `SUBVALCP`, `SUBVALNI`, `VALBENEF`, `VALELEG`, `CALCBENF`.
5. Programs: `CADBENEF`, `CONSBENF`, `BATCHPGT`, `BATCHREL`, `RELPGT`, `CADPROG`, `CADDEPEND`, `VALDOCS`, `CALCCORR`, `CALCDSCT`, `RELAUDIT`, `BATCHCON`.

## Re-run behavior

`run-all.sh` is safe to re-run. The Adabas loader writes markers under the Adabas data volume and skips already-loaded files. It intentionally refuses destructive reloads with `--force`; delete/recreate the lab database manually if a reload is required.

## Smoke assertions

`03-smoke-test.sh` asserts that:

- `CONSBENF` output contains the beneficiary screen/output and the seeded CPF suffix.
- `BATCHPGT` output contains its banner, the period, and a business summary (`PAYMENTS GENERATED`, `NO PAYMENT GENERATED`, or `TOTAL PROCESSED`).

## Required live validation

A real Azure apply is still required to prove: Adabas file definitions, seed layouts, Natural DDM generation, all `STOW` commands, and both smoke-test paths. These scripts are intentionally honest about that gap and fail loudly with the member/output path on Natural errors.
