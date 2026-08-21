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


def test_should_ship_compatibility_tool_with_provisioning():
    assert (PROVISIONING / "natural_ce_source.py").is_file()
