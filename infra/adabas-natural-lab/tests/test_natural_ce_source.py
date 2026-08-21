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


def test_should_ship_compatibility_tool_with_provisioning():
    assert (PROVISIONING / "natural_ce_source.py").is_file()
