from __future__ import annotations

from conftest import DDM_DIR, enabled_descriptor_count


def read_fdt(generated_fdt_dir, name):
    return (generated_fdt_dir / f"{name}.fdt").read_text(encoding="utf-8")


def test_should_emit_expected_descriptor_counts_when_optional_storage_columns_are_blank(generated_fdt_dir):
    expected = {
        "beneficiary": 20,
        "social-program": 5,
        "payment": 17,
        "audit": 13,
    }
    actual = {name: enabled_descriptor_count(read_fdt(generated_fdt_dir, name)) for name in expected}

    assert actual == expected
    assert sum(actual.values()) == 55


def test_should_emit_vendor_descriptor_syntax_and_comment_hyperdescriptor(generated_fdt_dir):
    beneficiary = read_fdt(generated_fdt_dir, "beneficiary")
    payment = read_fdt(generated_fdt_dir, "payment")
    audit = read_fdt(generated_fdt_dir, "audit")

    assert "PN=PHON(AC) ; PHON-NAME" in beneficiary
    assert "SA=AF(1,4) ; YEAR-BIRTH" in beneficiary
    assert "S2=BG(1,2),CE(1,1) ; SUPER-UF-STAT" in beneficiary
    assert "; H1=AF,CJ ; HYPER-BAND-ELIG" in beneficiary
    assert "\nH1=" not in beneficiary
    assert "SA=AE(1,4) ; YEAR-REF" in payment
    assert "S2=CA(1,4),CB(1,15),AB(1,8) ; SUPER-ENTITY-DATE" in audit


def test_should_emit_adabas_fdt_syntax_and_never_parse_adarep_listing(generated_fdt_dir):
    beneficiary = read_fdt(generated_fdt_dir, "beneficiary")
    reference_listing = (DDM_DIR / "FDT-150-BENEFICIARY.txt").read_text(encoding="utf-8", errors="replace")

    assert "1, AA, 11, U, DE,UQ ; NUM-REGISTRATION" in beneficiary
    assert "1, BA ; GRP-ADDRESS" in beneficiary
    assert "1, DA, PE ; GRP-DEPEND" in beneficiary
    assert "1, JA, 1, A, FI ; IND-LEGAL-REPRESENTATIVE" in beneficiary
    assert "1, JB, 11, A, NU,DE ; CPF-REPRESENTATIVE" in beneficiary
    assert "PAGE" not in beneficiary
    assert " JA " not in reference_listing and " JB " not in reference_listing


def test_should_map_ddm_numeric_format_to_adabas_unpacked_and_compute_packed_lengths(generated_fdt_dir):
    beneficiary = read_fdt(generated_fdt_dir, "beneficiary")
    payment = read_fdt(generated_fdt_dir, "payment")

    assert "1, AA, 11, U, DE,UQ ; NUM-REGISTRATION" in beneficiary
    assert "1, BA, 5, P ; AMT-GROSS" in payment
    assert "1, BC, 4, P, NU ; AMT-DISC-TOTAL" in payment
