#!/usr/bin/env python3
"""Build ADACMP input from the human-readable SIFAP seed files.

The seed `.dat` files are deliberately kept as flat, fixed-width, newline
terminated text so they stay diffable and reviewable in the repository. Adabas
ADACMP wants something quite different:

* records framed with a 4-byte little-endian length prefix
  (`RECORD_STRUCTURE=E4LENGTH_PREFIX`, the framing the Software AG demo loader
  uses in `$ADAPROGDIR/demodb/emp.cmpin`);
* multiple-value fields and periodic groups introduced by a 1-byte occurrence
  count, with periodic groups written occurrence-major (occurrence 1 of every
  member field, then occurrence 2, ...) rather than field-major.

Both facts were established empirically against Adabas Community Edition 7.4.0:
a 2-byte count shifts every periodic member one byte to the right and ADACMP
rejects the first periodic field with `%ADACMP-F-ERR2`. With a 1-byte count the
full SIFAP seed compresses with zero incorrect records.

This converter bridges the two. It derives the layout from the DDM, so the DDM
remains the single source of truth.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import struct
import sys

FIELD_RE = re.compile(
    r"^(?P<t>[GMPS]?)\s*(?P<lvl>[12])\s+(?P<db>[A-Z0-9]{2})\s+"
    r"(?P<name>[A-Z0-9][A-Z0-9\-]*)\s+(?P<fmt>[ANPB])\s+(?P<leng>\d+(?:[,.]\d+)?)\s*(?P<rest>.*)$"
)
GROUP_RE = re.compile(
    r"^(?P<t>[GP])\s+(?P<lvl>1)\s+(?P<db>[A-Z0-9]{2})\s+(?P<name>[A-Z0-9][A-Z0-9\-]*)\s*(?P<rest>.*)$"
)
STORAGE = {"N", "F"}
DESCRIPTORS = {"D", "U"}


def width_of(fmt, leng):
    digits = int(re.split(r"[,.]", leng)[0])
    return (digits + 1) // 2 if fmt == "P" else digits


def parse_ddm(text):
    """Return the field list, stopping before the derived-descriptor section."""
    fields = []
    for line in text.splitlines():
        if "DERIVED DESCRIPTORS" in line or "COLUMN LEGEND" in line:
            break
        stripped = line.strip()
        if not stripped or stripped.startswith("*"):
            continue
        gm = GROUP_RE.match(stripped)
        fm = FIELD_RE.match(stripped)
        if fm:
            g = fm.groupdict()
            rest = g["rest"].split()
            if rest and rest[0] in STORAGE:
                rest.pop(0)
            if rest and len(rest[0]) == 1 and rest[0] in DESCRIPTORS:
                rest.pop(0)
            occ = 1
            mo = re.search(r"\((\d+):(\d+)\)", " ".join(rest))
            if g["t"] == "M" and mo:
                occ = int(mo.group(2))
            fields.append(dict(kind="M" if g["t"] == "M" else "F", level=int(g["lvl"]),
                               db=g["db"], name=g["name"], fmt=g["fmt"],
                               width=width_of(g["fmt"], g["leng"]), occurs=occ))
        elif gm:
            g = gm.groupdict()
            mo = re.search(r"\((\d+):(\d+)\)", g["rest"])
            fields.append(dict(kind=g["t"], level=1, db=g["db"], name=g["name"],
                               fmt="", width=0, occurs=int(mo.group(2)) if mo else 1))
    return fields


def build_plan(fields):
    """Flatten the DDM into ordered emit steps plus their seed-file offsets.

    The seed stores each field's occurrences contiguously (field-major), so
    every step records its own base offset and per-occurrence stride.
    """
    plan = []
    offset = 0
    i = 0
    while i < len(fields):
        f = fields[i]
        if f["kind"] == "G":
            i += 1
            continue
        if f["kind"] == "P":
            members = []
            occurs = f["occurs"]
            i += 1
            while i < len(fields) and fields[i]["level"] == 2:
                m = fields[i]
                members.append(dict(db=m["db"], width=m["width"], fmt=m["fmt"], offset=offset))
                offset += m["width"] * occurs
                i += 1
            plan.append(dict(kind="PE", db=f["db"], occurs=occurs, members=members))
            continue
        plan.append(dict(kind="MU" if f["kind"] == "M" else "F", db=f["db"], fmt=f["fmt"],
                         width=f["width"], occurs=f["occurs"], offset=offset))
        offset += f["width"] * f["occurs"]
        i += 1
    return plan, offset


def pe_occurrences(record, plan):
    """Active dependent count, taken from QTY-DEPEND (CK) when present."""
    for e in plan:
        if e["kind"] == "F" and e["db"] == "CK":
            raw = record[e["offset"]:e["offset"] + e["width"]]
            return int(raw) if raw.strip().isdigit() else 0
    return 0


def encode(record, plan, count_struct):
    out = bytearray()
    for e in plan:
        if e["kind"] == "F":
            out += record[e["offset"]:e["offset"] + e["width"]]
        elif e["kind"] == "MU":
            vals = [record[e["offset"] + i * e["width"]:e["offset"] + (i + 1) * e["width"]]
                    for i in range(e["occurs"])]
            used = vals
            out += struct.pack(count_struct, len(used))
            for v in used:
                out += v
        else:
            n = e["occurs"]
            out += struct.pack(count_struct, n)
            for i in range(n):
                for m in e["members"]:
                    base = m["offset"] + i * m["width"]
                    out += record[base:base + m["width"]]
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description="Convert SIFAP seed data to ADACMP input")
    ap.add_argument("--ddm", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--count-format", default="<B",
                    help="struct format for MU/PE occurrence counts (default 1-byte, as ADACMP expects)")
    args = ap.parse_args()

    fields = parse_ddm(pathlib.Path(args.ddm).read_text(encoding="utf-8", errors="replace"))
    plan, width = build_plan(fields)

    data = pathlib.Path(args.seed).read_bytes()
    stride = width + 1 if data[width:width + 1] == b"\n" else width
    if len(data) % stride:
        print("error: %s is %d bytes, not a multiple of %d" % (args.seed, len(data), stride),
              file=sys.stderr)
        return 1

    out = bytearray()
    count = len(data) // stride
    for i in range(count):
        record = data[i * stride:i * stride + width]
        body = encode(record, plan, args.count_format)
        out += struct.pack("<I", len(body)) + body
    pathlib.Path(args.out).write_bytes(bytes(out))
    print("%s: %d records, flat width %d, wrote %d bytes" % (args.seed, count, width, len(out)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
