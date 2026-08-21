from __future__ import annotations

from conftest import PROVISIONING, ROOT


def test_should_alias_only_benefic_view_fields_in_runtime_copies(
    natural_ce_source,
):
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    declaration_count = 0
    reference_count = 0

    for path in sorted(source_dir.glob("*.NS[NP]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        declaration_count += len(
            natural_ce_source.VIEW_DECLARATION.findall(source)
        )
        reference_count += len(
            natural_ce_source.QUALIFIED_REFERENCE.findall(source)
        )
        normalized = natural_ce_source.normalize(source)

        assert not natural_ce_source.VIEW_DECLARATION.search(normalized)
        assert not natural_ce_source.QUALIFIED_REFERENCE.search(normalized)
        assert normalized.count("#UF") == source.count("#UF")

    assert declaration_count == 10
    assert reference_count == 4


def test_should_drop_view_operand_from_adabas_update_statements(
    natural_ce_source,
):
    """UPDATE takes no operand; a name makes Natural CE parse SQL (NAT0679)."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    update_count = 0

    for path in sorted(source_dir.glob("*.NS[NPC]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        update_count += len(natural_ce_source.UPDATE_WITH_VIEW.findall(source))
        normalized = natural_ce_source.normalize(source)

        assert not natural_ce_source.UPDATE_WITH_VIEW.search(normalized)
        assert normalized.count("STORE ") == source.count("STORE ")

    assert update_count == 7


def test_should_preserve_indentation_when_rewriting_update(natural_ce_source):
    source = "  FIND V WITH X = 1\n      UPDATE PAYMENT-V\n  END-FIND\n"

    assert natural_ce_source.normalize(source) == (
        "  FIND V WITH X = 1\n      UPDATE\n  END-FIND\n"
    )


def test_should_rewrite_descending_reads_into_sequence_form(
    natural_ce_source,
):
    """Trailing DESCENDING is parsed as a field name and fails NAT0623."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    read_count = 0

    for path in sorted(source_dir.glob("*.NS[NPC]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        read_count += len(natural_ce_source.READ_DESCENDING.findall(source))
        normalized = natural_ce_source.normalize(source)

        assert not natural_ce_source.READ_DESCENDING.search(normalized)

    assert read_count == 3


def test_should_keep_limit_and_indentation_when_rewriting_descending(
    natural_ce_source,
):
    source = "    READ (1) AUDIT-V BY NUM-AUDIT DESCENDING\n"

    assert natural_ce_source.normalize(source) == (
        "    READ (1) AUDIT-V IN DESCENDING SEQUENCE BY NUM-AUDIT\n"
    )


def test_should_strip_view_argument_from_number_system_variable(
    natural_ce_source,
):
    """*NUMBER takes a statement reference, not a view (NAT0280)."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    number_count = 0

    for path in sorted(source_dir.glob("*.NS[NPC]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        number_count += len(natural_ce_source.NUMBER_WITH_VIEW.findall(source))
        normalized = natural_ce_source.normalize(source)

        assert not natural_ce_source.NUMBER_WITH_VIEW.search(normalized)

    assert number_count == 2
    assert natural_ce_source.normalize("IF *NUMBER(PROGRAM-V) = 0\n") == (
        "IF *NUMBER = 0\n"
    )


def test_should_ship_compatibility_tool_with_provisioning():
    assert (PROVISIONING / "natural_ce_source.py").is_file()
