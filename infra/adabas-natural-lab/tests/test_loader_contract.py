from __future__ import annotations

from conftest import LOAD_SCRIPT, WORK_DIR, run_loader_function


def test_should_emit_adacmp_parameters_only_with_e4_record_structure():
    out = WORK_DIR / "contract.cmp"
    out.parent.mkdir(parents=True, exist_ok=True)
    run_loader_function("emit_cmp", out)
    text = out.read_text(encoding="utf-8")

    assert text == "RECORD_STRUCTURE=E4LENGTH_PREFIX\n"
    for forbidden in ["FORMAT=", "FORMAT_BUFFER", "FB=", "DECOMPRESS"]:
        assert forbidden not in text


def test_should_emit_adafdu_fdu_without_field_table_because_fdufdt_carries_the_fdt():
    out = WORK_DIR / "beneficiary.fdu"
    out.parent.mkdir(parents=True, exist_ok=True)
    run_loader_function("emit_fdu", "150", "beneficiary", out)
    text = out.read_text(encoding="utf-8")

    assert "name=beneficiary" in text
    assert "dssize=20m" in text
    assert "1, AA" not in text
    assert "FDUFDT" not in text


def test_should_lock_loader_command_contract_to_adafdu_adacmp_adamup_path():
    text = LOAD_SCRIPT.read_text(encoding="utf-8")

    assert "export FDUFDT=" in text
    assert "export CMPIN=" in text
    assert 'export MUPDTA=\\"\\$CMPDTA\\"' in text
    assert 'export MUPDVT=\\"\\$CMPDVT\\"' in text
    assert "| adafdu" in text
    assert "| adacmp" in text
    assert "adamup db='$ADABAS_DBID' update='$fnr',add" in text
    assert "delete_file=" not in text
    assert "emit_fdt_from_adarep" not in text
    assert "FDT-150-BENEFICIARY.txt" in text
