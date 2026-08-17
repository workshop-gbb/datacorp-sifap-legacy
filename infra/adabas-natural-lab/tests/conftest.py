from __future__ import annotations

import importlib.util
import os
import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[3]
LAB = ROOT / "infra" / "adabas-natural-lab"
PROVISIONING = LAB / "provisioning"
DDM_DIR = ROOT / "01-archaeology" / "legacy-sifap" / "adabas-ddms"
SEED_DIR = PROVISIONING / "seed"
WORK_DIR = LAB / "tests" / ".work"
LOAD_SCRIPT = pathlib.Path(os.environ.get("SIFAP_LOAD_ADABAS_SH", PROVISIONING / "01-load-adabas.sh"))
ENCODER = pathlib.Path(os.environ.get("SIFAP_ADACMP_INPUT_PY", PROVISIONING / "adacmp_input.py"))

FILES = {
    "beneficiary": (150, "BENEFICIARY.ddm", 500, 1739),
    "social-program": (151, "SOCIAL-PROGRAM.ddm", 6, 361),
    "payment": (152, "PAYMENT.ddm", 2000, 855),
    "audit": (153, "AUDIT.ddm", 200, 4995),
}


def load_encoder():
    spec = importlib.util.spec_from_file_location("sifap_adacmp_input", ENCODER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def loader_function_body() -> str:
    text = LOAD_SCRIPT.read_text(encoding="utf-8")
    return text[text.index("packed_len()") : text.index("\nmain()")]


def run_loader_function(function_name: str, *args: pathlib.Path | str) -> subprocess.CompletedProcess[str]:
    script = "set -euo pipefail\n" + loader_function_body() + f'\n{function_name} "$@"\n'
    return subprocess.run(
        ["bash", "-c", script, "bash", *map(str, args)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
    )


@pytest.fixture(scope="session")
def encoder():
    return load_encoder()


@pytest.fixture(scope="session")
def generated_fdt_dir() -> pathlib.Path:
    out = WORK_DIR / "fdt"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True, exist_ok=True)
    for name, (_, ddm, _, _) in FILES.items():
        run_loader_function("emit_fdt_from_ddm", DDM_DIR / ddm, out / f"{name}.fdt")
    return out


def enabled_descriptor_count(fdt_text: str) -> int:
    count = 0
    for line in fdt_text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        if re.match(r"^[12],\s+[A-Z0-9]{2},.*\bDE\b", stripped):
            count += 1
        elif re.match(r"^[A-Z0-9]{2}=", stripped):
            count += 1
    return count
