"""Validate the public simulation without contacting or changing Azure."""

import importlib.util
import json
import subprocess
from pathlib import Path

from conftest import ROOT


def test_snapshot_is_reproducible_and_contains_only_synthetic_fields():
    path = ROOT / "scripts/export-demo-fixtures.py"
    spec = importlib.util.spec_from_file_location("demo_export", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    data = module.snapshot()
    published = json.loads((ROOT / "public-landing/demo/data.json").read_text())

    assert data == module.snapshot() == published
    assert data["synthetic"] is True
    assert data["versions"] == {"natural": "9.3.3", "adabas": "7.4.0", "dbid": 12}
    assert len(data["beneficiaries"]) == 500
    assert len(data["programs"]) == 6
    assert len(data["payments"]) == 2000
    assert len(data["audits"]) == 200
    assert data["beneficiaries"][0]["cpf"] == "00097539740"
    assert data["beneficiaries"][0]["nis"] == "81977930374"
    assert len({row["cpf"] for row in data["beneficiaries"]}) == 500
    assert len({row["nis"] for row in data["beneficiaries"]}) == 500
    assert all(set(row) == {
        "cpf", "nis", "name", "birthDate", "city", "uf", "region", "program",
        "status", "registeredAt", "dependents", "familyIncomeCents",
    } for row in data["beneficiaries"])
    assert all(isinstance(row["netCents"], int) for row in data["payments"])
    assert all(set(row) == {"id", "date", "module", "action", "entity"} for row in data["audits"])


def test_simulation_state_machine_and_translation_contracts():
    result = subprocess.run(
        ["node", "--test", str(Path(__file__).with_name("public-demo.test.mjs"))],
        capture_output=True, text=True, check=False, timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
