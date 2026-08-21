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

``*NUMBER(<view>)``
    The system variable takes a statement reference, not a view name, so
    Natural CE reports NAT0280. Both call sites sit *after* ``END-FIND``, where
    bare ``*NUMBER`` has no active statement to resolve against and fails with
    NAT0285, so the originating FIND gets a label and the reference points at
    it.

``READ ... BY <descriptor> DESCENDING``
    Natural expects the direction before the sequence: ``READ view IN
    DESCENDING SEQUENCE BY descriptor``. Trailing ``DESCENDING`` is read as a
    field name and fails with NAT0623.

``C*<periodic group>``
    The count field only exists if the view declares it. Natural CE resolves
    ``C*GRP-DISC`` once ``2 C*GRP-DISC`` sits in the view and reports NAT0047 /
    NAT0285 otherwise, so the declaration is added next to the group.

``/* ... \n ... */``
    ``/*`` comments out the rest of its own line only; it is not a block
    comment. The second line of the one two-line comment in the corpus is
    therefore parsed as source and fails with NAT0243, so it becomes a comment
    line in its own right.

Only staged runtime copies change; the frozen corpus and local ``#UF``
variables stay intact.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

UF_CODE = "UF-CODE"
LABEL_PREFIX = "CENUM"
VIEW_DECLARATION = re.compile(
    r"(?m)^(?P<prefix>\s+[23]\s+)UF(?P<suffix>\s+\(A2\).*)$"
)
QUALIFIED_REFERENCE = re.compile(r"\.UF(?=\s|/|$)")
UPDATE_WITH_VIEW = re.compile(
    r"(?m)^(?P<indent>\s*)UPDATE\s+[A-Z][A-Z0-9]*-V[ \t]*$"
)
NUMBER_WITH_VIEW = re.compile(r"\*NUMBER\(\s*(?P<view>[A-Z][A-Z0-9-]*-V)\s*\)")
FIND_STATEMENT = re.compile(
    r"(?m)^(?P<indent>[ \t]*)FIND\s+(?P<view>[A-Z][A-Z0-9-]*-V)\b"
)
READ_DESCENDING = re.compile(
    r"(?m)^(?P<indent>\s*)READ\s+(?P<limit>\(\d+\)\s+)?"
    r"(?P<view>[A-Z][A-Z0-9-]*)\s+BY\s+(?P<key>[A-Z][A-Z0-9-]*)"
    r"\s+DESCENDING[ \t]*$"
)
COUNT_REFERENCE = re.compile(r"(?<![\w-])C\*(?P<group>[A-Z][A-Z0-9-]*)")


def _rewrite_descending(match: re.Match[str]) -> str:
    limit = match.group("limit") or ""
    return (
        f"{match.group('indent')}READ {limit}{match.group('view')}"
        f" IN DESCENDING SEQUENCE BY {match.group('key')}"
    )


def _originating_find(source: str, view: str, before: int) -> re.Match[str] | None:
    """Return the last FIND on ``view`` that starts before ``before``."""
    found = None
    for match in FIND_STATEMENT.finditer(source, 0, before):
        if match.group("view") == view:
            found = match
    return found


def _label_number_references(source: str) -> str:
    labels: dict[int, tuple[int, str]] = {}
    edits: list[tuple[int, int, str]] = []

    for reference in NUMBER_WITH_VIEW.finditer(source):
        find = _originating_find(source, reference.group("view"), reference.start())
        if find is None:
            continue
        if find.start() not in labels:
            labels[find.start()] = (
                find.start() + len(find.group("indent")),
                f"{LABEL_PREFIX}{len(labels) + 1}",
            )
        _, label = labels[find.start()]
        edits.append((reference.start(), reference.end(), f"*NUMBER({label}.)"))

    edits.extend((at, at, f"{label}. ") for at, label in labels.values())

    for start, end, text in sorted(edits, reverse=True):
        source = f"{source[:start]}{text}{source[end:]}"
    return source


def _close_multiline_comments(source: str) -> str:
    """Comment out the tail of a C-style comment that spans two lines."""
    lines = source.split("\n")
    for index in range(1, len(lines)):
        line = lines[index]
        if "/*" in line or not line.rstrip().endswith("*/"):
            continue
        if "/*" not in lines[index - 1] or not line.startswith((" ", "\t")):
            continue
        lines[index] = f"*{line[1:]}"
    return "\n".join(lines)


def _declare_count_fields(source: str) -> str:
    """Declare the C* count field of every periodic group the source counts."""
    groups = {match.group("group") for match in COUNT_REFERENCE.finditer(source)}
    lines = source.split("\n")

    for group in sorted(groups):
        name = re.escape(group)
        if re.search(rf"(?m)^\s*[123]\s+C\*{name}\b", source):
            continue
        declaration = re.compile(rf"^(?P<indent>\s*)(?P<level>[123])\s+{name}\s*\(\d+:\d+\)\s*$")
        for index, line in enumerate(lines):
            match = declaration.match(line)
            if match is None:
                continue
            lines.insert(index, f"{match['indent']}{match['level']} C*{group}")
            break

    return "\n".join(lines)


def normalize(source: str) -> str:
    source = VIEW_DECLARATION.sub(
        rf"\g<prefix>{UF_CODE}\g<suffix>",
        source,
    )
    source = QUALIFIED_REFERENCE.sub(f".{UF_CODE}", source)
    source = UPDATE_WITH_VIEW.sub(r"\g<indent>UPDATE", source)
    source = _close_multiline_comments(source)
    source = _declare_count_fields(source)
    source = _label_number_references(source)
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
