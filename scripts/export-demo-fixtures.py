"""Export a minimal, deterministic simulation snapshot from the lab seed generator."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "infra/adabas-natural-lab/provisioning/seed/generate_seed.py"


def seed_module():
    spec = importlib.util.spec_from_file_location("public_demo_seed", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("The synthetic lab seed generator is unavailable.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def iso_date(value: int) -> str:
    text = str(value)
    return f"{text[:4]}-{text[4:6]}-{text[6:8]}"


def snapshot() -> dict:
    seed = seed_module()
    beneficiaries = seed.beneficiaries()
    programs = seed.social_programs()
    payments = seed.payments(beneficiaries)
    audits = seed.audits(beneficiaries, payments)
    return {
        "schemaVersion": 1,
        "synthetic": True,
        "snapshotDate": seed.TODAY.isoformat(),
        "generatorSha256": hashlib.sha256(GENERATOR.read_bytes()).hexdigest(),
        "versions": {"natural": "9.3.3", "adabas": "7.4.0", "dbid": 12},
        "periods": [
            f"{period // 100:04d}-{period % 100:02d}"
            for period in sorted(seed.PERIODS, reverse=True)
        ],
        "programs": [{"code": row["COD-PROGRAM"]} for row in programs],
        "beneficiaries": [
            {
                "cpf": row["NUM-CPF"],
                "nis": str(row["NUM-NIS"]).zfill(11),
                "name": row["FULL-NAME"],
                "birthDate": iso_date(row["DT-BIRTH"]),
                "city": row["CITY"],
                "uf": row["UF"],
                "region": row["COD-REGION"],
                "program": row["COD-PROGRAM"],
                "status": row["STAT-BENEFICIARY"],
                "registeredAt": iso_date(row["DT-REGISTRATION"]),
                "dependents": row["QTY-DEPEND"],
                "familyIncomeCents": int(seed.money(row["AMT-FAMILY-INCOME"]) * 100),
            }
            for row in beneficiaries
        ],
        "payments": [
            {
                "id": str(row["NUM-PAYMENT"]),
                "cpf": row["NUM-CPF"],
                "period": f"{row['YEAR-MONTH-REF'] // 100:04d}-{row['YEAR-MONTH-REF'] % 100:02d}",
                "grossCents": int(row["AMT-GROSS"] * 100),
                "discountCents": int(row["AMT-DISC-TOTAL"] * 100),
                "netCents": int(row["AMT-NET"] * 100),
                "status": row["STAT-PAYMENT"],
                "type": row["TYPE-PAYMENT"],
            }
            for row in payments
        ],
        "audits": [
            {
                "id": str(row["NUM-AUDIT"]),
                "date": iso_date(row["DT-EVENT"]),
                "module": row["COD-MODULE"],
                "action": row["COD-ACTION"],
                "entity": row["TYPE-ENTITY"],
            }
            for row in audits
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path,
        default=ROOT / "public-landing/demo/data.json",
    )
    args = parser.parse_args()
    data = snapshot()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print("Exported synthetic simulation: 500 beneficiaries, 6 programs, 2000 payments, 200 audit events.")


if __name__ == "__main__":
    main()
