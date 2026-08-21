#!/usr/bin/env python3
"""Apply runtime-only Natural CE source compatibility aliases.

The frozen SIFAP corpus keeps the Natural 4.2 field name ``UF``. Natural CE
9.3.3 requires DDM long names to contain at least three characters (NAT4219),
so the generated BENEFIC DDM exposes the same physical field BG as
``UF-CODE``. This script changes only staged runtime copies of view
declarations and qualified references; local ``#UF`` variables stay intact.
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


def normalize(source: str) -> str:
    source = VIEW_DECLARATION.sub(
        rf"\g<prefix>{UF_CODE}\g<suffix>",
        source,
    )
    return QUALIFIED_REFERENCE.sub(f".{UF_CODE}", source)


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
