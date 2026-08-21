from __future__ import annotations

import pytest

from conftest import DDM_DIR


def convert(ddm_source, member):
    listing = (DDM_DIR / f"{member}.ddm").read_text(
        encoding="utf-8",
        errors="replace",
    )
    return ddm_source.convert(listing, "12")


def test_should_emit_target_dbid_and_file_number_for_every_sifap_ddm(
    ddm_source,
):
    expected_files = {
        "BENEFIC": "150",
        "SOCPROG": "151",
        "PAYMENT": "152",
        "AUDIT": "153",
    }

    for member, file_number in expected_files.items():
        source = convert(ddm_source, member)

        assert source.startswith(f"DB: 12    FILE: {file_number}")
        assert f"- {member}" in source.splitlines()[0]
        assert source.splitlines()[1] == "TYPE: ADABAS"


def test_should_emit_groups_periodic_groups_and_multivalue_fields(
    ddm_source,
):
    beneficiary = convert(ddm_source, "BENEFIC")
    social_program = convert(ddm_source, "SOCPROG")
    payment = convert(ddm_source, "PAYMENT")
    audit = convert(ddm_source, "AUDIT")

    assert "G 1 BA GRP-ADDRESS" in beneficiary
    assert "  2 BG UF-CODE" in beneficiary
    assert "P 1 DA GRP-DEPEND" in beneficiary
    assert "M 1 ED NUM-PHONE" in beneficiary
    assert "P 1 DA GRP-CALC-BAND" in social_program
    assert "P 1 FA GRP-REGIONAL-PARAM" in social_program
    assert "M 1 EA TYPE-DISC-APPLIC" in social_program
    assert "P 1 CA GRP-DISC" in payment
    assert "M 1 HC COD-OCCURRENCE" in payment
    assert "G 1 DA GRP-BEFORE" in audit
    assert "M 2 DB FIELD-UPDATED-PREV" in audit
    assert "(1:10)" not in beneficiary
    assert "(1:8)" not in payment


def test_should_place_field_attributes_in_vendor_fixed_columns(ddm_source):
    source = convert(ddm_source, "SOCPROG")
    line = next(
        candidate
        for candidate in source.splitlines()
        if candidate.startswith("M 1 EA")
    )

    assert line[0] == "M"
    assert line[2] == "1"
    assert line[4:6] == "EA"
    assert line[7:39].rstrip() == "TYPE-DISC-APPLIC"
    assert line[41] == "A"
    assert line[42:47].strip() == "3"
    assert line[49] == "N"
    assert line[51] == " "


def test_should_emit_supported_derived_descriptors_and_omit_hyperdescriptor(
    ddm_source,
):
    beneficiary = convert(ddm_source, "BENEFIC")
    payment = convert(ddm_source, "PAYMENT")

    assert "  1 PN PHON-NAME" in beneficiary
    assert "*      -------- SOURCE FIELD(S) -------" in beneficiary
    assert "*      FULL-NAME" in beneficiary
    assert "  1 S2 SUPER-UF-STAT" in beneficiary
    assert "*      UF-CODE(1-2)" in beneficiary
    assert "*      STAT-BENEFICIARY(1-1)" in beneficiary
    assert "  1 S2 SUPER-PROG-PERIOD-STAT" in payment
    assert "*      COD-PROGRAM(1-4)" in payment
    assert "*      YEAR-MONTH-REF(1-6)" in payment
    assert "*      STAT-PAYMENT(1-1)" in payment
    assert "H1" not in beneficiary
    assert "HYPER-BAND-ELIG" not in beneficiary
    assert "\n*      AF\n" not in beneficiary
    assert "\n*      CJ\n" not in beneficiary


def test_should_reject_listing_without_required_identity(ddm_source):
    with pytest.raises(
        SystemExit,
        match="listing has no 'DDM NAME:' / 'FNR:' header",
    ):
        ddm_source.convert("TYPE: ADABAS\n", "12")


def test_should_keep_runtime_alias_consistent_with_natural_sources(
    ddm_source,
    natural_ce_source,
):
    assert ddm_source.LONG_NAME_ALIASES[("BENEFIC", "BG")] == (
        natural_ce_source.UF_CODE
    )
