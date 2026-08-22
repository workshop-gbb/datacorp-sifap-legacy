from __future__ import annotations

import re

from conftest import PROVISIONING

SMOKE_TEST = PROVISIONING / "03-smoke-test.sh"
LIB = PROVISIONING / "lib.sh"
CALL = re.compile(
    r'run_natural_program\s+(?P<label>\w+)\s+(?P<program>[A-Z0-9]+)\s+\\\n'
    r'"(?P<input>[^"]*)"',
    re.MULTILINE,
)


def test_should_not_type_past_the_end_of_an_interactive_program():
    """A key the program never reads lands on the command line (NAT0082)."""
    script = SMOKE_TEST.read_text(encoding="utf-8")
    calls = {m["program"]: m["input"].splitlines() for m in CALL.finditer(script)}

    assert calls["CONSBENF"] == ["C", "${cpf}"]
    assert calls["BATCHPGT"] == ["${SMOKE_PERIOD}"]


def test_should_drive_natural_through_redirected_input():
    """A pty needs PF3 to end CONSBENF and no escape sequence delivers it."""
    body = LIB.read_text(encoding="utf-8").split("natural_run()")[1].split("\n}")[0]

    assert "< '${remote}.input'" in body
    assert ".exp" not in body
    assert "spawn natural" not in body


def test_should_separate_a_run_that_never_ended_from_one_that_chose_its_code():
    """BATCHPGT ends with TERMINATE 12; only GNU timeout reports 124."""
    lib = LIB.read_text(encoding="utf-8")

    assert '"$rc" -eq 124' in lib


def test_should_fail_on_the_error_banner_the_corpus_prints_itself():
    """ON ERROR writes NATURAL ERROR and never a NAT code."""
    lib = LIB.read_text(encoding="utf-8")

    assert "grep -q 'NATURAL ERROR'" in lib


def test_should_answer_every_page_pause_the_session_can_produce():
    """Redirected input has to answer MORE itself; history caps at 12 rows."""
    script = SMOKE_TEST.read_text(encoding="utf-8")

    assert "SMOKE_PAGE_KEYS" in script


def test_should_read_the_smoke_cpf_through_the_ddm_derived_layout():
    """The seed is binary and NUM-REGISTRATION runs into NUM-CPF."""
    script = SMOKE_TEST.read_text(encoding="utf-8")

    assert "--print-field NUM-CPF" in script
    assert "grep -Eo '[0-9]{11}'" not in script
