#!/usr/bin/env python3
"""Convert a SIFAP LISTDDM report into Natural DDM source.

The corpus files under 01-archaeology/legacy-sifap/adabas-ddms are LISTDDM
*reports*: a comment banner, then a field table whose header says
"DBID: 057  FNR: 150". Natural rejects one as source with NAT4225, so the
manual NaturalONE step was assumed to be unavoidable.

It is not. Natural CE catalogs a DDM held in a library as SRC/<NAME>.NSD, and
the only thing missing was the source layout it expects: a "DB:/FILE:" header,
"TYPE: ADABAS", and the field table in fixed columns.

The parsing rules mirror emit_fdt_from_ddm() in 01-load-adabas.sh on purpose.
That function built the FDT the database was loaded with, so deriving the DDM
from the same listing with the same rules is what keeps the two consistent.
Hyperdescriptors are the one deliberate omission in both: ADAFDU needs a
compiled hyperexit the lab does not ship, so the field is absent from the FDT
and must be absent here too.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Column layout Natural accepts, verified against the EMPLOYEE DDM shipped with
# natural-ce 9.3.3: T(0) L(2) DB(4-5) NAME(7-38) F(41) LEN(42-46) S(49) D(51).
FIELD_LINE = (
    "{t:1} {lvl:1} {db:<2} {name:<32}  "
    "{fmt:1}{length:>5}  {stor:1} {desc:1} {remark}"
)

HEADER_RULE = "- - -- --------------------------------  - ----  - - " + "-" * 24
HEADER_COLS = "T L DB NAME                              F LENG  S D REMARK"

SECTION_START = re.compile(
    r"--- (IDENTIFICATION|KEYS|EVENT IDENTIFICATION) ---")
SECTION_DERIVED = re.compile(r"--- DERIVED DESCRIPTORS ---")
FIELD_ROW = re.compile(r"^\s*[GMP]?\s*[12]\s+[A-Z][A-Z]\s+")
SUPER_ROW = re.compile(r"^\s*S\s+[A-Z0-9]{2}\s+")
CONT_ROW = re.compile(r"^\s*/\*")
SOURCE_COMPONENT = re.compile(r"[A-Z0-9]{2}(?:\(\d+(?:-\d+)?\))?")


def parse_header(text: str) -> tuple[str, str, str]:
    name = re.search(r"^DDM NAME:\s+(\S+)", text, re.M)
    fnr = re.search(r"^DBID:\s*\d+\s+FNR:\s*(\d+)", text, re.M)
    seq = re.search(r"DEFAULT SEQUENCE:\s*(\S*)", text)
    if not name or not fnr:
        raise SystemExit("listing has no 'DDM NAME:' / 'FNR:' header")
    return name.group(1), fnr.group(1), (seq.group(1) if seq else "")


def split_row(line: str) -> dict[str, str]:
    """Read one field row by value, not by column.

    S (null suppression) and D (descriptor) are optional and either may be
    blank, so consuming them positionally silently drops the descriptor on any
    field that has no suppression flag.
    """
    parts = [p for p in line.split() if p]
    i = 0
    typ = ""
    if parts[i] in ("G", "M", "P", "S"):
        typ = parts[i]
        i += 1
    lvl = "" if typ == "S" else parts[i]
    if typ != "S":
        i += 1
    db, long_name = parts[i], parts[i + 1]
    i += 2

    fmt = length = ""
    if typ not in ("G", "P"):
        fmt, length = parts[i], parts[i + 1]
        i += 2

    stor = desc = ""
    if i < len(parts) and parts[i] in ("N", "F"):
        stor = parts[i]
        i += 1
    if i < len(parts) and parts[i] in ("D", "U", "P", "S", "H"):
        desc = parts[i]
        i += 1

    return {
        "t": typ,
        "lvl": lvl,
        "db": db,
        "name": long_name,
        "fmt": fmt,
        "length": length,
        "stor": stor,
        "desc": desc,
        "remark": " ".join(parts[i:]),
    }


def convert(listing: str, dbid: str) -> str:
    ddm_name, fnr, seq = parse_header(listing)

    out = [
        f"DB: {dbid:<5} FILE: {fnr:<4} - {ddm_name:<30} DEFAULT SEQUENCE: {seq}",
        "TYPE: ADABAS",
        HEADER_COLS,
        HEADER_RULE,
    ]

    section = 0
    pending_hyper = False
    for line in listing.splitlines():
        if SECTION_DERIVED.search(line):
            section = 2
            continue
        if SECTION_START.search(line):
            section = 1
            continue
        if line.startswith("* COLUMN LEGEND"):
            break

        if section == 1 and FIELD_ROW.match(line):
            row = split_row(line)
            # (1:10) and (1:5) are occurrence counts the FDT already carries as
            # PE/MU; in DDM source they belong to the remark, not the length.
            row["remark"] = re.sub(r"\(\d+:\d+\)\s*", "",
                                   row["remark"]).strip()
            out.append(FIELD_LINE.format(**row).rstrip())

        elif section == 2 and SUPER_ROW.match(line):
            row = split_row(line)
            if row["desc"] == "H":
                # Absent from the FDT: ADAFDU cannot build it without a
                # compiled hyperexit, so claiming it here would not match.
                pending_hyper = True
                continue
            pending_hyper = False
            row["t"] = ""
            row["lvl"] = "1"
            out.append(FIELD_LINE.format(**row).rstrip())

        elif section == 2 and CONT_ROW.match(line):
            if pending_hyper:
                pending_hyper = False
                continue
            components = SOURCE_COMPONENT.findall(line)
            out.append("*      -------- SOURCE FIELD(S) -------")
            out.extend(f"*      {component}" for component in components)

    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("listing", type=Path, help="corpus .ddm LISTDDM report")
    ap.add_argument("--dbid", default="12", help="target Adabas DBID")
    ap.add_argument("-o", "--output", type=Path, help="write .NSD here")
    args = ap.parse_args()

    source = convert(args.listing.read_text(
        encoding="utf-8", errors="replace"), args.dbid)
    if args.output:
        args.output.write_text(source, encoding="utf-8")
    else:
        sys.stdout.write(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
