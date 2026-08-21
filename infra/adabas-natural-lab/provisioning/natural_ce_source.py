#!/usr/bin/env python3
"""Apply runtime-only Natural CE source compatibility aliases.

Two constructs in the frozen SIFAP corpus predate Natural CE 9.3.3:

``UF``
    A Natural 4.2 field name of two characters. Natural CE requires DDM long
    names to hold at least three (NAT4219), so the generated BENEFIC DDM
    exposes the same physical field BG as ``UF-CODE``.

``UPDATE <view>``
    The Adabas UPDATE statement takes no operand: it rewrites the record of
    the enclosing FIND or READ loop. With a name after it Natural CE parses
    the SQL form and fails with NAT0679.

``READ ... BY <descriptor> DESCENDING``
    Natural expects the direction before the sequence: ``READ view IN
    DESCENDING SEQUENCE BY descriptor``. Trailing ``DESCENDING`` is read as a
    field name and fails with NAT0623.

Only staged runtime copies change; the frozen corpus and local ``#UF``
variables stay intact.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

UF_CODE = "UF-CODE"
VIEW_DECLARATION = re.compile(
    r"(?m)^(?P<prefix>\s+[23]\s+)UF(?P<suffix>\s+\(A2\).*)$"
)
QUALIFIED_REFERENCE = re.compile(r"\.UF(?=\s|/|$)")
UPDATE_WITH_VIEW = re.compile(
    r"(?m)^(?P<indent>\s*)UPDATE\s+[A-Z][A-Z0-9]*-V[ \t]*$"
)
READ_DESCENDING = re.compile(
    r"(?m)^(?P<indent>\s*)READ\s+(?P<limit>\(\d+\)\s+)?"
    r"(?P<view>[A-Z][A-Z0-9-]*)\s+BY\s+(?P<key>[A-Z][A-Z0-9-]*)"
    r"\s+DESCENDING[ \t]*$"
)


def _rewrite_descending(match: re.Match[str]) -> str:
    limit = match.group("limit") or ""
    return (
        f"{match.group('indent')}READ {limit}{match.group('view')}"
        f" IN DESCENDING SEQUENCE BY {match.group('key')}"
    )


def normalize(source: str) -> str:
    source = VIEW_DECLARATION.sub(
        rf"\g<prefix>{UF_CODE}\g<suffix>",
        source,
    )
    source = QUALIFIED_REFERENCE.sub(f".{UF_CODE}", source)
    source = UPDATE_WITH_VIEW.sub(r"\g<indent>UPDATE", source)
    return READ_DESCENDING.sub(_rewrite_descending, source)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="+", type=Path)
    args = parser.parse_args()

    for path in args.sources:
        text = path.read_text(encoding="utf-8", errors="replace")
        path.write_text(normalize(text), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
