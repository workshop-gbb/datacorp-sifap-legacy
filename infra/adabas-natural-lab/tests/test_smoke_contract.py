from __future__ import annotations

import re

from conftest import PROVISIONING

SMOKE_TEST = PROVISIONING / "03-smoke-test.sh"
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


def test_should_read_the_smoke_cpf_through_the_ddm_derived_layout():
    """The seed is binary and NUM-REGISTRATION runs into NUM-CPF."""
    script = SMOKE_TEST.read_text(encoding="utf-8")

    assert "--print-field NUM-CPF" in script
    assert "grep -Eo '[0-9]{11}'" not in script
