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


def test_should_point_number_references_at_a_labelled_find(
    natural_ce_source,
):
    """After END-FIND, bare *NUMBER has no active statement (NAT0285)."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    number_count = 0

    for path in sorted(source_dir.glob("*.NS[NPC]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        number_count += len(natural_ce_source.NUMBER_WITH_VIEW.findall(source))
        normalized = natural_ce_source.normalize(source)

        assert not natural_ce_source.NUMBER_WITH_VIEW.search(normalized)

    assert number_count == 2


def test_should_label_the_find_that_originates_the_number_reference(
    natural_ce_source,
):
    source = (
        "  FIND PROGRAM-V WITH COD-PROGRAM = #COD\n"
        "    IGNORE\n"
        "  END-FIND\n"
        "  IF *NUMBER(PROGRAM-V) = 0\n"
    )

    assert natural_ce_source.normalize(source) == (
        "  CENUM1. FIND PROGRAM-V WITH COD-PROGRAM = #COD\n"
        "    IGNORE\n"
        "  END-FIND\n"
        "  IF *NUMBER(CENUM1.) = 0\n"
    )


def test_should_leave_bare_number_references_untouched(natural_ce_source):
    """FIND NUMBER and HISTOGRAM loops already resolve bare *NUMBER."""
    source = (
        "  FIND NUMBER PAYMENT-V WITH SUPER-CPF-PERIOD = #KEY\n"
        "  IF *NUMBER > 0\n"
        "    ESCAPE TOP\n"
        "  END-IF\n"
    )

    assert natural_ce_source.normalize(source) == source


def test_should_comment_out_the_tail_of_two_line_comments(natural_ce_source):
    """`/*` only comments its own line, so the tail is parsed (NAT0243)."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    orphans = []

    for path in sorted(source_dir.glob("*.NS[NPCAL]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        normalized = natural_ce_source.normalize(source).splitlines()
        for number, line in enumerate(source.splitlines(), start=1):
            if line.rstrip().endswith("*/") and "/*" not in line:
                orphans.append((path.name, number))
                assert f"*{line[1:]}" in normalized
                assert line not in normalized

    assert orphans == [("CALCDSCT.NSP", 23)]


def test_should_keep_column_alignment_when_commenting_the_tail(
    natural_ce_source,
):
    source = "  1 #X (A3)  /* FIRST\n             SECOND */\n"

    assert natural_ce_source.normalize(source) == (
        "  1 #X (A3)  /* FIRST\n*            SECOND */\n"
    )


def test_should_not_comment_code_that_merely_ends_with_the_marker(
    natural_ce_source,
):
    source = "  1 #X (A3)  /* NOTE\n  MOVE 1 TO #X\n"

    assert natural_ce_source.normalize(source) == source


def test_should_declare_the_count_field_every_c_star_reference_needs(
    natural_ce_source,
):
    """C* resolves only when the view declares the count field (NAT0047)."""
    source_dir = ROOT / "01-archaeology/legacy-sifap/natural-programs"
    counted = []

    for path in sorted(source_dir.glob("*.NS[NPCAL]")):
        source = path.read_text(encoding="utf-8", errors="replace")
        groups = {m.group("group") for m in
                  natural_ce_source.COUNT_REFERENCE.finditer(source)}
        if not groups:
            continue
        counted.append((path.name, sorted(groups)))
        normalized = natural_ce_source.normalize(source)
        for group in groups:
            assert f" C*{group}\n" in normalized

    assert counted == [("CALCDSCT.NSP", ["GRP-DISC"])]


def test_should_declare_the_count_field_beside_its_group(natural_ce_source):
    source = (
        "  1 P-V VIEW OF PAYMENT\n"
        "    2 GRP-DISC            (1:8)\n"
        "      3 AMT-DISC          (P7.2)\n"
        "  FOR #I = 1 TO C*GRP-DISC\n"
    )

    assert natural_ce_source.normalize(source) == (
        "  1 P-V VIEW OF PAYMENT\n"
        "    2 C*GRP-DISC\n"
        "    2 GRP-DISC            (1:8)\n"
        "      3 AMT-DISC          (P7.2)\n"
        "  FOR #I = 1 TO C*GRP-DISC\n"
    )


def test_should_not_declare_a_count_field_twice(natural_ce_source):
    source = (
        "  1 P-V VIEW OF PAYMENT\n"
        "    2 C*GRP-DISC\n"
        "    2 GRP-DISC            (1:8)\n"
        "  FOR #I = 1 TO C*GRP-DISC\n"
    )

    assert natural_ce_source.normalize(source) == source


def test_should_ship_compatibility_tool_with_provisioning():
    assert (PROVISIONING / "natural_ce_source.py").is_file()
